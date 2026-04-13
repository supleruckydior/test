-- 自动附魔剑雕像（新机制：单独锁定 + 单独随机）
-- 路径保持为老脚本同款转义字符串

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local unpackFn = table.unpack or unpack

local Config = {
    TargetName = "金币获取率",
    MinQuality = 5,
    RequiredMatchCount = 5,

    ActionIntervalSec = 0.12,
    MaxRandomRounds = 1000,
    MaxFailures = 10,

    -- 货币校验（不足就断开）
    RefreshCost = 100,
    LockCost = 100,
    StopIfTokenReadFailed = true, -- 读不到货币时是否停止
}

local State = {
    running = false,
    stopped = false,
    processing = false,
    pendingData = nil,

    randomRounds = 0,
    failures = 0,
    lastActionClock = 0,
    syncConnection = nil,
}

local OLD_SYNC_PARTS = {
    "\228\186\139\228\187\182",
    "\229\133\172\231\148\168",
    "\229\137\145\233\155\149\229\131\143",
    "\229\144\140\230\173\165\230\149\176\230\141\174",
}

local OLD_RANDOM_PARTS = {
    "\228\186\139\228\187\182",
    "\229\133\172\231\148\168",
    "\229\137\145\233\155\149\229\131\143",
    "\231\165\136\231\165\183",
}

local OLD_LOCK_PARTS = {
    "\228\186\139\228\187\182",
    "\229\133\172\231\148\168",
    "\229\137\145\233\155\149\229\131\143",
    "\233\148\129\229\174\154\229\164\169\232\181\139",
}

local function log(msg)
    print("[剑雕像新机制] " .. msg)
end

local function warnLog(msg)
    warn("[剑雕像新机制] " .. msg)
end

local function waitChild(parent, childName, timeoutSec)
    local obj = parent:FindFirstChild(childName)
    if obj then
        return obj
    end
    return parent:WaitForChild(childName, timeoutSec or 10)
end

local function resolvePath(root, parts, timeoutSec)
    local node = root
    for _, p in ipairs(parts) do
        node = waitChild(node, p, timeoutSec)
        if not node then
            return nil
        end
    end
    return node
end

local function stopRun(reason)
    State.running = false
    State.stopped = true
    State.processing = false
    State.pendingData = nil
    if State.syncConnection then
        State.syncConnection:Disconnect()
        State.syncConnection = nil
    end
    log("停止: " .. reason)
end

local function getTokenCount()
    local ok, result = pcall(function()
        local player = Players.LocalPlayer
        local gui = player:WaitForChild("PlayerGui"):WaitForChild("GUI")
        local secondLevel = gui:WaitForChild("\228\186\140\231\186\167\231\149\140\233\157\162")
        local refreshPanel = secondLevel:WaitForChild("\229\137\145\233\155\149\229\131\143")
        local backpack = refreshPanel:WaitForChild("\232\131\140\230\153\175")
        local enchant = backpack:WaitForChild("\229\189\162\232\177\161")
        local life = enchant:WaitForChild("\231\148\159\229\145\189\228\185\139\230\176\180")
        local button = life:WaitForChild("\230\140\137\233\146\174")
        local text = button:WaitForChild("\229\128\188")
        return tonumber(text.Text) or 0
    end)

    if ok then
        return result, nil
    end
    return nil, tostring(result)
end

local function getEntryList(syncData)
    if type(syncData) ~= "table" then
        return nil, nil, "同步数据不是 table"
    end

    local groups = syncData["组数据"]
    if type(groups) ~= "table" then
        return nil, nil, "缺少组数据"
    end

    local idx = tonumber(syncData["当前使用组"]) or 1
    local group = groups[idx]
    if type(group) ~= "table" then
        return nil, nil, "目标组不存在: " .. tostring(idx)
    end

    local entries = group["数据"]
    if type(entries) ~= "table" then
        entries = group
    end
    if type(entries) ~= "table" then
        return nil, nil, "组词条结构异常"
    end

    return entries, idx, nil
end

local function analyze(syncData)
    local entries, groupIndex, err = getEntryList(syncData)
    if not entries then
        return nil, err
    end

    local matched = 0
    local matchedLocked = 0
    local toLock = {}
    local toUnlock = {}

    for slotIndex, entry in ipairs(entries) do
        if type(entry) == "table" then
            local name = entry["名称"]
            local quality = tonumber(entry["品质"])
            local locked = (entry["锁定"] == true)
            local matchedTarget = (name == Config.TargetName and quality and quality >= Config.MinQuality)

            if matchedTarget then
                matched = matched + 1
                if locked then
                    matchedLocked = matchedLocked + 1
                else
                    toLock[#toLock + 1] = slotIndex
                end
            elseif locked then
                -- 不符合目标但被锁：解锁
                toUnlock[#toUnlock + 1] = slotIndex
            end
        end
    end

    return {
        groupIndex = groupIndex,
        totalSlots = #entries,
        matched = matched,
        matchedLocked = matchedLocked,
        toLock = toLock,
        toUnlock = toUnlock,
    }
end

local function waitActionWindow()
    local pass = os.clock() - State.lastActionClock
    local remain = Config.ActionIntervalSec - pass
    if remain > 0 then
        task.wait(remain)
    end
end

local function fireLock(lockEvent, slotIndex)
    waitActionWindow()

    local ok, err = pcall(function()
        local args = {slotIndex}
        lockEvent:FireServer(unpackFn(args))
    end)
    State.lastActionClock = os.clock()

    if not ok then
        State.failures = State.failures + 1
        warnLog("锁定发送失败: " .. tostring(err))
        return false
    end

    State.failures = 0
    log("已发送锁定请求，槽位=" .. tostring(slotIndex))
    return true
end

local function fireUnlock(lockEvent, slotIndex)
    waitActionWindow()

    local ok, err = pcall(function()
        local args = {slotIndex}
        lockEvent:FireServer(unpackFn(args))
    end)
    State.lastActionClock = os.clock()

    if not ok then
        State.failures = State.failures + 1
        warnLog("解锁发送失败: " .. tostring(err))
        return false
    end

    State.failures = 0
    log("已发送解锁请求，槽位=" .. tostring(slotIndex))
    return true
end

local function fireRandom(randomEvent)
    waitActionWindow()

    local ok, err = pcall(function()
        randomEvent:FireServer()
    end)
    State.lastActionClock = os.clock()

    if not ok then
        State.failures = State.failures + 1
        warnLog("随机发送失败: " .. tostring(err))
        return false
    end

    State.failures = 0
    State.randomRounds = State.randomRounds + 1
    log("已发送随机请求，轮次=" .. tostring(State.randomRounds))
    return true
end

local function processData(syncData, randomEvent, lockEvent)
    local r, err = analyze(syncData)
    if not r then
        warnLog("数据解析失败: " .. tostring(err))
        return
    end

    local required = math.min(Config.RequiredMatchCount, (r.totalSlots > 0 and r.totalSlots or Config.RequiredMatchCount))
    log(string.format(
        "组=%d 满足=%d 锁定满足=%d/%d 待解锁=%d 待锁=%d 随机轮次=%d",
        r.groupIndex,
        r.matched,
        r.matchedLocked,
        required,
        #r.toUnlock,
        #r.toLock,
        State.randomRounds
    ))

    if r.matchedLocked >= required then
        stopRun("目标达成")
        return
    end

    if State.failures >= Config.MaxFailures then
        stopRun("连续失败过多")
        return
    end

    local tokenCount, tokenErr = getTokenCount()
    if tokenCount == nil then
        warnLog("读取货币失败: " .. tostring(tokenErr))
        if Config.StopIfTokenReadFailed then
            stopRun("无法读取货币，已断开")
            return
        end
    end

    if #r.toUnlock > 0 then
        if tokenCount and tokenCount < Config.LockCost then
            stopRun(string.format("货币不足(解锁): 当前=%d 需要=%d", tokenCount, Config.LockCost))
            return
        end
        fireUnlock(lockEvent, r.toUnlock[1])
        return
    end

    if #r.toLock > 0 then
        if tokenCount and tokenCount < Config.LockCost then
            stopRun(string.format("货币不足(锁定): 当前=%d 需要=%d", tokenCount, Config.LockCost))
            return
        end
        fireLock(lockEvent, r.toLock[1])
        return
    end

    if State.randomRounds >= Config.MaxRandomRounds then
        stopRun("达到最大随机次数")
        return
    end

    if tokenCount and tokenCount < Config.RefreshCost then
        stopRun(string.format("货币不足(随机): 当前=%d 需要=%d", tokenCount, Config.RefreshCost))
        return
    end

    fireRandom(randomEvent)
end

local function runQueued(syncData, randomEvent, lockEvent)
    if State.processing then
        State.pendingData = syncData
        return
    end

    State.processing = true

    local current = syncData
    while current and not State.stopped do
        State.pendingData = nil
        processData(current, randomEvent, lockEvent)
        current = State.pendingData
    end

    State.processing = false
end

local function main()
    local syncEvent = resolvePath(ReplicatedStorage, OLD_SYNC_PARTS, 10)
    local randomEvent = resolvePath(ReplicatedStorage, OLD_RANDOM_PARTS, 10)
    local lockEvent = resolvePath(ReplicatedStorage, OLD_LOCK_PARTS, 10)

    if not syncEvent then
        warnLog("未找到同步事件（老路径）")
        return
    end
    if not randomEvent then
        warnLog("未找到随机事件（老路径）")
        return
    end
    if not lockEvent then
        warnLog("未找到锁定事件（老路径）")
        return
    end

    log("同步路径: " .. syncEvent:GetFullName())
    log("随机路径: " .. randomEvent:GetFullName())
    log("锁定路径: " .. lockEvent:GetFullName())
    log(string.format("配置: 名称=%s 最低品质=%d", Config.TargetName, Config.MinQuality))

    State.syncConnection = syncEvent.OnClientEvent:Connect(function(data)
        if State.stopped then
            return
        end
        if type(data) ~= "table" then
            return
        end

        if not State.running then
            State.running = true
            log("收到同步数据，开始运行")
        end

        runQueued(data, randomEvent, lockEvent)
    end)

    _G.SwordStatueAutoEnchantV2 = {
        Stop = function()
            stopRun("手动停止")
        end,
        Status = function()
            return {
                running = State.running,
                stopped = State.stopped,
                randomRounds = State.randomRounds,
                failures = State.failures,
                connected = (State.syncConnection ~= nil),
            }
        end,
    }

    log("监听已连接，等待同步数据")
end

main()
