-- 自动附魔剑雕像（完善版）
-- 基于实际同步数据结构：
-- ReplicatedStorage.事件.公用.剑雕像.同步数据
--
-- 功能：
-- 1) 监听同步数据
-- 2) 在目标组中查找满足最低品质的词条
-- 3) 维护锁定槽位并持续刷新，直到达成目标或触发停止条件

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local unpackFn = table.unpack or unpack

local Config = {
    -- 目标词条（保留名称变量）
    TargetName = "经验获取率",

    -- 品质阈值
    MinQuality = 3,

    -- 目标达成条件
    RequiredMatchCount = 5, -- 目标词条数量达到该值后停止

    -- 刷新控制
    RefreshIntervalSec = 0.12, -- 两次刷新最小间隔
    MaxRefreshRounds = 600, -- 最大刷新次数，防止无限循环
    MaxRefreshFailures = 8, -- 连续刷新失败上限

    -- 代币检查（默认关闭；UI 路径变化较大）
    EnableTokenCheck = false,
    RefreshCost = 100,
    LockCost = 100,
}

local State = {
    running = false,
    stopped = false,
    processing = false,
    pendingData = nil,

    lockedSlots = {}, -- [slotIndexString] = true
    refreshRounds = 0,
    refreshFailures = 0,
    lastRefreshClock = 0,
    warnedTokenPath = false,
}

-- 与老脚本一致的路径（不使用中文明文）
local OLD_SYNC_PARTS = {
    "\228\186\139\228\187\182",
    "\229\133\172\231\148\168",
    "\229\137\145\233\155\149\229\131\143",
    "\229\144\140\230\173\165\230\149\176\230\141\174",
}

local OLD_ENCHANT_PARTS = {
    "\228\186\139\228\187\182",
    "\229\133\172\231\148\168",
    "\229\137\145\233\155\149\229\131\143",
    "\231\165\136\231\165\183",
}

local function log(msg)
    print("[剑雕像自动附魔] " .. msg)
end

local function warnLog(msg)
    warn("[剑雕像自动附魔] " .. msg)
end

local function waitChild(parent, childName, timeoutSec)
    local timeout = timeoutSec or 10
    local obj = parent:FindFirstChild(childName)
    if obj then
        return obj
    end
    obj = parent:WaitForChild(childName, timeout)
    return obj
end

local function resolvePath(root, parts, timeoutSec)
    local node = root
    for _, part in ipairs(parts) do
        node = waitChild(node, part, timeoutSec)
        if not node then
            return nil
        end
    end
    return node
end

local function resolveSyncEvent()
    return resolvePath(ReplicatedStorage, OLD_SYNC_PARTS, 10)
end

local function resolveEnchantEvent()
    return resolvePath(ReplicatedStorage, OLD_ENCHANT_PARTS, 10)
end

local function getTokenCount()
    if not Config.EnableTokenCheck then
        return math.huge
    end

    local ok, result = pcall(function()
        local player = Players.LocalPlayer
        local gui = player:WaitForChild("PlayerGui"):WaitForChild("GUI")
        local secondLevel = gui:WaitForChild("二级界面")

        -- 旧脚本中的常见路径
        local refreshPanel = secondLevel:WaitForChild("刷新器")
        local backpack = refreshPanel:WaitForChild("背景")
        local enchant = backpack:WaitForChild("附魔")
        local life = enchant:WaitForChild("生命之水")
        local button = life:WaitForChild("按钮")
        local text = button:WaitForChild("值")

        return tonumber(text.Text) or 0
    end)

    if ok then
        return result
    end

    if not State.warnedTokenPath then
        warnLog("代币路径读取失败，已禁用代币校验。本轮错误: " .. tostring(result))
        State.warnedTokenPath = true
    end
    Config.EnableTokenCheck = false
    return math.huge
end

local function stopRun(reason)
    State.running = false
    State.stopped = true
    State.processing = false
    State.pendingData = nil
    log("停止: " .. reason)
end

local function getGroupIndex(data)
    local idx = tonumber(data["当前使用组"])
    if idx and idx >= 1 then
        return idx
    end

    -- 兜底：某些数据包可能没有“当前使用组”
    if type(data["组数据"]) == "table" and type(data["组数据"][1]) == "table" then
        return 1
    end

    return 1
end

local function getEntryList(groupItem)
    if type(groupItem) ~= "table" then
        return nil
    end
    if type(groupItem["数据"]) == "table" then
        return groupItem["数据"]
    end
    if #groupItem > 0 then
        return groupItem
    end
    return nil
end

local function isTargetEntry(entry)
    if type(entry) ~= "table" then
        return false, nil, nil
    end
    local name = entry["名称"]
    local quality = tonumber(entry["品质"])
    if name == Config.TargetName and quality and quality >= Config.MinQuality then
        return true, name, quality
    end
    return false, name, quality
end

local function getLockedSlotKeys(lockTable)
    local keys = {}
    for slotKey, locked in pairs(lockTable) do
        if locked then
            keys[#keys + 1] = slotKey
        end
    end
    table.sort(keys, function(a, b)
        return tonumber(a) < tonumber(b)
    end)
    return keys
end

local function analyzeData(data)
    if type(data) ~= "table" then
        return nil, "同步数据不是 table"
    end

    local groups = data["组数据"]
    if type(groups) ~= "table" then
        return nil, "缺少 组数据"
    end

    local groupIndex = getGroupIndex(data)
    local groupItem = groups[groupIndex]
    if type(groupItem) ~= "table" then
        return nil, "目标组不存在: " .. tostring(groupIndex)
    end

    local entries = getEntryList(groupItem)
    if type(entries) ~= "table" then
        return nil, "目标组词条结构异常"
    end

    local matchCount = 0
    local newLockCount = 0

    for slotIndex, entry in ipairs(entries) do
        local matched, name, quality = isTargetEntry(entry)
        if matched then
            matchCount = matchCount + 1
            local slotKey = tostring(slotIndex)
            if not State.lockedSlots[slotKey] then
                State.lockedSlots[slotKey] = true
                newLockCount = newLockCount + 1
                log(string.format("新增锁定: 槽位=%d 名称=%s 品质=%d", slotIndex, tostring(name), quality))
            end
        end
    end

    local lockTable = {}
    for slotKey, locked in pairs(State.lockedSlots) do
        if locked then
            lockTable[slotKey] = true
        end
    end

    return {
        groupIndex = groupIndex,
        totalSlots = #entries,
        matchCount = matchCount,
        newLockCount = newLockCount,
        lockTable = lockTable,
    }
end

local function canAfford(newLockCount)
    local tokens = getTokenCount()
    if tokens == math.huge then
        return true
    end

    local need = Config.RefreshCost + (newLockCount * Config.LockCost)
    if tokens < need then
        log(string.format("代币不足: 当前=%d 需要=%d", tokens, need))
        return false
    end
    return true
end

local function fireRefresh(enchantEvent, lockTable)
    local now = os.clock()
    local waitSec = Config.RefreshIntervalSec - (now - State.lastRefreshClock)
    if waitSec > 0 then
        task.wait(waitSec)
    end

    local slotKeys = getLockedSlotKeys(lockTable or {})
    log("发送刷新请求，锁定槽位: [" .. table.concat(slotKeys, ",") .. "]")

    local ok, err = pcall(function()
        local args = {lockTable or {}}
        enchantEvent:FireServer(unpackFn(args))
    end)
    State.lastRefreshClock = os.clock()

    if not ok then
        State.refreshFailures = State.refreshFailures + 1
        warnLog("刷新失败: " .. tostring(err))
        if State.refreshFailures >= Config.MaxRefreshFailures then
            stopRun("连续刷新失败过多")
        end
        return false
    end

    State.refreshFailures = 0
    State.refreshRounds = State.refreshRounds + 1
    return true
end

local function processData(syncData, enchantEvent)
    local result, err = analyzeData(syncData)
    if not result then
        warnLog("数据解析失败: " .. tostring(err))
        return
    end

    local required = math.min(Config.RequiredMatchCount, result.totalSlots > 0 and result.totalSlots or Config.RequiredMatchCount)
    log(string.format(
        "组=%d 满足=%d/%d 新增锁定=%d 已刷新=%d",
        result.groupIndex,
        result.matchCount,
        required,
        result.newLockCount,
        State.refreshRounds
    ))

    if result.matchCount >= required then
        stopRun("目标达成")
        return
    end

    if State.refreshRounds >= Config.MaxRefreshRounds then
        stopRun("达到最大刷新次数")
        return
    end

    if not canAfford(result.newLockCount) then
        stopRun("代币不足")
        return
    end

    local ok = fireRefresh(enchantEvent, result.lockTable)
    if ok then
        log("已发送刷新请求")
    end
end

local function runQueued(syncData, enchantEvent)
    if State.processing then
        State.pendingData = syncData
        return
    end

    State.processing = true

    local current = syncData
    while current and not State.stopped do
        State.pendingData = nil
        processData(current, enchantEvent)
        current = State.pendingData
    end

    State.processing = false
end

local function main()
    log("初始化中...")
    local syncEvent = resolveSyncEvent()
    if not syncEvent then
        warnLog("未找到同步事件（老脚本路径）")
        return
    end
    local enchantEvent = resolveEnchantEvent()

    if not enchantEvent then
        warnLog("未找到刷新事件（老脚本路径）")
        return
    end

    log("同步路径: " .. syncEvent:GetFullName())
    log("附魔路径: " .. enchantEvent:GetFullName())
    log(string.format("配置: 名称=%s 最低品质=%d (组=自动当前组)", Config.TargetName, Config.MinQuality))

    syncEvent.OnClientEvent:Connect(function(data)
        if State.stopped then
            return
        end
        if type(data) ~= "table" then
            return
        end

        if not State.running then
            State.running = true
            log("收到同步数据，开始自动附魔")
        end

        runQueued(data, enchantEvent)
    end)

    _G.SwordStatueAutoEnchant = {
        Stop = function()
            stopRun("手动停止")
        end,
        Status = function()
            return {
                running = State.running,
                stopped = State.stopped,
                lockedSlots = State.lockedSlots,
                refreshRounds = State.refreshRounds,
                refreshFailures = State.refreshFailures,
            }
        end,
    }

    log("监听已连接，等待同步数据触发")
end

main()
