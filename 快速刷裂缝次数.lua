-- 快速刷裂缝次数脚本
-- 用于完成周任务：进入裂缝N次
-- 进入后立即退出，追求最快速度
-- 严格按照捕捉宠物.lua的逻辑
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- 检查游戏ID
local targetGameId = 98664161516921
if game.PlaceId ~= targetGameId then
    error(string.format("[刷裂缝] 游戏ID不匹配！当前: %d, 需要: %d", game.PlaceId, targetGameId))
end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- 等待并加载 PathTool 系统
local PathTool = rawget(_G, "PathTool")

-- 日志系统
local function RiftAddLog(msg)
    local timestamp = os.date("%H:%M:%S")
    print(string.format("[%s] [刷裂缝] %s", timestamp, msg))
end

local function WaitForPathTool(maxWait)
    maxWait = maxWait or 30
    local waited = 0

    while not PathTool do
        task.wait(0.1)
        waited = waited + 0.1

        pcall(function()
            PathTool = require(ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("PathTool"))
            _G.PathTool = PathTool
        end)

        if not PathTool and _G.PathTool then
            PathTool = _G.PathTool
        end

        if waited >= maxWait then
            return false
        end
    end

    return true
end

-- 重新获取所有依赖（失败后使用）
local function ReloadAllDependencies()
    RiftAddLog("重新获取所有依赖...")
    
    -- 清空旧的PathTool引用
    PathTool = nil
    _G.PathTool = nil
    
    -- 重新获取player
    player = Players.LocalPlayer
    if not player then
        RiftAddLog("错误: 无法获取player")
        return false
    end
    
    -- 重新获取PathTool
    local pathToolReady = WaitForPathTool(30)
    if not pathToolReady then
        RiftAddLog("错误: PathTool重新加载超时")
        return false
    end
    
    -- 等待游戏完全加载（包括角色加载）
    local gameLoaded, loadReason = WaitForGameFullyLoaded(60)
    if not gameLoaded then
        RiftAddLog(string.format("游戏重新加载失败: %s", loadReason))
        return false
    end
    
    RiftAddLog("所有依赖重新加载成功")
    return true
end

-- 安全的获取函数：直到成功为止
local function SafeGet(getFn, maxRetries, retryDelay)
    maxRetries = maxRetries or 20
    retryDelay = retryDelay or 0.1

    for i = 1, maxRetries do
        local success, result = pcall(getFn)
        if success and result ~= nil then
            return result, i
        end
        if i < maxRetries then
            task.wait(retryDelay)
        end
    end
    return nil, maxRetries
end

-- 检测游戏是否完全加载
local function IsGameFullyLoaded()
    if not PathTool then
        return false, "等待PathTool..."
    end

    local libReady = SafeGet(function()
        return ReplicatedStorage:FindFirstChild("CommonLibrary") ~= nil
    end, 30, 0.2)
    if not libReady then
        return false, "等待CommonLibrary..."
    end

    local petsReady = SafeGet(function()
        return game.Workspace:FindFirstChild("Pets") ~= nil
    end, 30, 0.2)
    if not petsReady then
        return false, "等待Pets..."
    end

    local characterReady = SafeGet(function()
        return player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") ~= nil
    end, 30, 0.2)
    if not characterReady then
        return false, "等待Character..."
    end

    return true, "就绪"
end

-- 等待游戏完全加载
local function WaitForGameFullyLoaded(maxWait)
    maxWait = maxWait or 120
    local waited = 0
    local lastReason = nil

    while waited < maxWait do
        local loaded, reason = IsGameFullyLoaded()
        if loaded then
            return true, reason
        end

        if math.floor(waited) % 5 == 0 and reason ~= lastReason then
            RiftAddLog(string.format("等待: %s (%.1fs)", reason, waited))
            lastReason = reason
        end

        task.wait(0.5)
        waited = waited + 0.5
    end

    return false, "超时"
end

-- 等待游戏加载完成（兼容旧接口）
local function WaitForGameLoaded()
    RiftAddLog("等待游戏加载...")
    
    local success, reason = WaitForGameFullyLoaded(120)
    if success then
        RiftAddLog(string.format("游戏加载完成: %s", reason))
        return true
    else
        RiftAddLog(string.format("游戏加载失败: %s", reason))
        return false
    end
end

-- 配置
local RIFT_TASK_ID = 203  -- 周任务ID: Challenge Rift
local RIFT_DATA_ID = 6    -- 任务DataId: ArenaEnter
local TARGET_COUNT = 10   -- 默认目标次数（会从游戏读取）
local SERVER_LIST_FILE = "servers.json"
local CONFIG_FILE = nil   -- 稍后初始化

-- 四个地图区域ID和备用坐标（未解锁时使用）
-- 区域名称映射：显示名称 -> workspace.Area中的实际名称
local RIFT_AREAS = {
    {id = 2, name = "Volcano", areaName = "Volcano", fallbackPos = Vector3.new(149.54, -118.26, -1001.12)},
    {id = 3, name = "Frost Isle", areaName = "Ice", fallbackPos = Vector3.new(-2307.201171875, 133.5146026611328, -1305.943115234375)},
    {id = 4, name = "Neverland", areaName = "Neverland", fallbackPos = Vector3.new(2823.03, -124.89, 1640.84)},
    {id = 5, name = "Duneveil Isle", areaName = "Desert", fallbackPos = Vector3.new(731.22, -120.87, -3158.72)}
}

-- 区域名称映射表（用于快速查找）
local AREA_NAME_MAP = {
    ["Volcano"] = "Volcano",
    ["Frost Isle"] = "Ice",
    ["Neverland"] = "Neverland",
    ["Duneveil Isle"] = "Desert"
}

-- 检测玩家当前所在的区域名称
-- 根据用户提供：Volcano->Volcano, Frost Isle->Ice, Neverland->Neverland, Duneveil Isle->Desert
local function GetCurrentAreaName()
    pcall(function()
        local areaFolder = workspace:FindFirstChild("Area")
        if not areaFolder then 
            RiftAddLog("Area文件夹不存在")
            return nil 
        end
        
        local character = player.Character
        if not character then return nil end
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return nil end
        
        local playerPos = humanoidRootPart.Position
        
        -- 区域名称列表（workspace.Area中的实际名称）
        local areaNames = {"Volcano", "Ice", "Neverland", "Desert"}
        
        -- 遍历所有区域，找到玩家所在的区域
        for _, areaName in ipairs(areaNames) do
            local areaChild = areaFolder:FindFirstChild(areaName)
            if areaChild then
                -- 检查区域是否有子区域（Area.*.Area 或 Area.*.ServerZone）
                local areaSubFolder = areaChild:FindFirstChild("Area")
                local serverZoneFolder = areaChild:FindFirstChild("ServerZone")
                
                -- 检查玩家是否在这个区域内（通过检查区域内的Dungeon节点位置）
                local checkZone = areaSubFolder or serverZoneFolder
                if checkZone then
                    local dungeonFolder = checkZone:FindFirstChild("Dungeon")
                    if dungeonFolder then
                        -- 如果区域内有Dungeon节点，检查玩家是否在附近
                        for _, node in ipairs(dungeonFolder:GetChildren()) do
                            if string.sub(node.Name, 1, 8) == "Dungeon_" then
                                local nodePos = node:GetPivot().Position
                                local distance = (playerPos - nodePos).Magnitude
                                -- 如果玩家距离Dungeon节点在合理范围内（500单位内），认为在这个区域
                                if distance < 500 then
                                    RiftAddLog(string.format("检测到玩家在区域: %s (距离裂缝: %.2f)", areaName, distance))
                                    return areaName
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    return nil
end

-- 状态
local isRunning = false
local enteredCount = 0

-- 从游戏读取周任务配置和进度
local function GetRiftTaskInfo()
    local targetCount = 10
    local currentCount = 0
    local isCompleted = false
    
    pcall(function()
        if not PathTool then return end
        
        -- 读取目标次数
        local CfgTask = rawget(PathTool, "CfgTask")
        if CfgTask and CfgTask.Tmpls and CfgTask.Tmpls[RIFT_TASK_ID] then
            targetCount = CfgTask.Tmpls[RIFT_TASK_ID].Count or 10
        end
        
        -- 读取当前进度
        local gp = PathTool.ClientPlayerManager.GetGamePlayer()
        if gp and gp.task then
            currentCount = gp.task:GetDataCount(RIFT_DATA_ID) or 0
            isCompleted = gp.task:IsRewardTaken(RIFT_TASK_ID) or false
        end
    end)
    
    return targetCount, currentCount, isCompleted
end

-- 领取周任务奖励
local function ClaimRiftTaskReward()
    if not PathTool then return false end
    
    local success = false
    pcall(function()
        -- 方法1: 使用 TaskSystem.ClientClaimReward
        local TaskSystem = rawget(PathTool, "TaskSystem")
        if TaskSystem and TaskSystem.ClientClaimReward then
            local result = TaskSystem.ClientClaimReward(RIFT_TASK_ID)
            if result then
                success = true
                print("[刷裂缝] ✓ 通过 TaskSystem 领取奖励成功")
                return
            end
        end
        
        -- 方法2: 使用 DataPullManager 通道
        if PathTool.DataPullManager then
            local channel = PathTool.DataPullManager.GetChannel("TaskClaimRewardChannel")
            if channel then
                local result = channel:DoRequest(RIFT_TASK_ID)
                if result then
                    success = true
                    print("[刷裂缝] ✓ 通过 DataPullManager 领取奖励成功")
                    return
                end
            end
        end
    end)
    
    return success
end

-- 写入 Yummytool 标记文件
local function WriteYummyToolMarker()
    pcall(function()
        if writefile and player and player.Name then
            local filename = tostring(player.Name) .. ".txt"
            writefile(filename, "Yummytool")
            print(string.format("[刷裂缝] ✓ 已写入标记文件: %s (内容: Yummytool)", filename))
        end
    end)
end


-- 保存配置
local function SaveConfig()
    pcall(function()
        if writefile and CONFIG_FILE then
            local config = {
                enteredCount = enteredCount,
                targetCount = TARGET_COUNT
            }
            writefile(CONFIG_FILE, HttpService:JSONEncode(config))
        end
    end)
end

-- 加载配置
local function LoadConfig()
    pcall(function()
        if CONFIG_FILE and isfile and isfile(CONFIG_FILE) then
            local content = readfile(CONFIG_FILE)
            local config = HttpService:JSONDecode(content)
            enteredCount = config.enteredCount or 0
            TARGET_COUNT = config.targetCount or 10
        end
    end)
end

-- 删除配置
local function DeleteConfig()
    pcall(function()
        if CONFIG_FILE and isfile and isfile(CONFIG_FILE) and delfile then
            delfile(CONFIG_FILE)
        end
    end)
end

-- ============================================
-- 服务器切换（使用局域网API，失败后随机传送）
-- ============================================

-- 局域网服务器地址（直接内置）
local LAN_SERVER_URL = "http://192.168.1.178:8765"

-- 从局域网服务器获取服务器
local function GetServerFromLAN()
    if not LAN_SERVER_URL then return nil end

    local success, result = pcall(function()
        return game:HttpGet(LAN_SERVER_URL .. "/server")
    end)

    if success and result then
        local data = HttpService:JSONDecode(result)
        if data and data.success and data.server then
            RiftAddLog(string.format("[LAN] 获取服务器: %s", data.server.id:sub(1, 8) .. "..."))
            return data.server
        elseif data and not data.success then
            RiftAddLog(string.format("[LAN] %s", data.error or "无服务器"))
        end
    end

    return nil
end

-- 备用：从Roblox API获取服务器
local function GetServersFromRobloxAPI()
    local apiUrl = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=50"

    local success, result = pcall(function()
        local reqFunc = request or syn and syn.request or http_request
        if not reqFunc then return nil end

        local resp = reqFunc({
            Url = apiUrl,
            Method = "GET"
        })

        if resp and resp.Body then
            local data = HttpService:JSONDecode(resp.Body)
            if data and data.data and #data.data > 0 then
                local servers = {}
                for _, server in ipairs(data.data) do
                    table.insert(servers, {
                        id = server.id,
                        playing = server.playing
                    })
                end
                return servers
            end
        end
        return nil
    end)

    return result
end

-- Server Hop
local function DoServerHop()
    RiftAddLog("切换服务器...")

    local maxRetries = 5
    local retryDelay = 5

    -- 尝试从局域网获取服务器
    local selectedServer = nil
    local useLAN = false

    if LAN_SERVER_URL then
        for retry = 1, maxRetries do
            selectedServer = GetServerFromLAN()
            if selectedServer then
                useLAN = true
                break
            end
            if retry < maxRetries then
                RiftAddLog(string.format("等待%ds... (%d/%d)", retryDelay, retry, maxRetries))
                task.wait(retryDelay)
            end
        end
    end

    -- 如果局域网获取失败，使用Roblox API
    if not selectedServer then
        RiftAddLog("使用Roblox API获取...")
        local servers = GetServersFromRobloxAPI()

        if servers and #servers > 0 then
            local currentJobId = game.JobId
            local validServers = {}
            for _, server in ipairs(servers) do
                if server.id and server.id ~= currentJobId then
                    table.insert(validServers, server)
                end
            end

            if #validServers > 0 then
                selectedServer = validServers[math.random(1, #validServers)]
                RiftAddLog(string.format("API获取 %d 个服务器", #validServers))
            end
        end
    end

    -- 如果还是没有服务器，使用随机传送
    if not selectedServer then
        RiftAddLog("无服务器，使用随机传送...")
        pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)
        return
    end

    -- 传送到服务器
    local targetJobId = selectedServer.id
    RiftAddLog(string.format("传送: %s", targetJobId:sub(1, 8) .. "..."))

    -- 锚定角色防止崩溃
    pcall(function()
        local character = player.Character
        if character then
            local hrp = character:WaitForChild("HumanoidRootPart", 5)
            if hrp then
                hrp.Anchored = true
            end
        end
    end)

    local teleportOk = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, targetJobId, player)
    end)

    if not teleportOk then
        RiftAddLog("传送调用失败")
        return false
    end

    -- 检测传送是否成功（3秒后检查JobId）
    task.wait(3)
    local newJobId = game.JobId

    if newJobId == targetJobId then
        RiftAddLog("传送成功")
        return true
    else
        RiftAddLog(string.format("传送失败，期望: %s，实际: %s", 
            targetJobId:sub(1, 8), 
            newJobId and newJobId:sub(1, 8) or "Unknown"))
        return false
    end
end

-- ============================================
-- 区块加载检测系统（基于游戏代码优化）
-- 必须在AnchorManager之前定义，因为AnchorManager会使用它
-- ============================================

local ZoneLoadChecker = {}

-- 检测区域文件夹是否存在且有内容（来自 AreaShower.Source.txt）
function ZoneLoadChecker.IsAreaFolderLoaded()
    local success, areaFolder = pcall(function()
        return workspace:WaitForChild("Area", 5)
    end)
    
    if not success or not areaFolder then
        return false, "Area文件夹未找到"
    end
    
    local areaChildren = areaFolder:GetChildren()
    if #areaChildren == 0 then
        return false, "Area文件夹为空"
    end
    
    return true, "Area文件夹已加载"
end

-- 检测玩家下方的地面是否存在（来自 PreloadProxy 逻辑）
function ZoneLoadChecker:CheckGroundBelow()
    local character = player.Character
    if not character then return false, nil end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false, nil end
    
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local rayOrigin = humanoidRootPart.Position
    local rayDirection = Vector3.new(0, -100, 0)
    
    local success, result = pcall(function()
        return workspace:Raycast(rayOrigin, rayDirection, rayParams)
    end)
    
    if success and result then
        return true, result.Position.Y
    else
        return false, nil
    end
end

-- 使用游戏内置的预加载检测（来自 PreloadProxy.Source.txt）
function ZoneLoadChecker:IsContentPreloaded()
    pcall(function()
        if _G.PathTool and _G.PathTool.PreloadProxy and _G.PathTool.PreloadProxy.IsPriorityPreloaded then
            return _G.PathTool.PreloadProxy.IsPriorityPreloaded(0)
        end
    end)
    return false
end

-- 检测是否在漂浮状态
function ZoneLoadChecker:IsFloating()
    local groundLoaded, groundY = self:CheckGroundBelow()
    if not groundLoaded then
        return true, "未检测到地面"
    end
    
    local character = player.Character
    if not character then return true, "角色不存在" end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return true, "HRP不存在" end
    
    local playerY = humanoidRootPart.Position.Y
    local distanceToGround = playerY - groundY
    
    -- 如果距离地面超过20单位，认为在漂浮状态
    if distanceToGround > 20 then
        return true, string.format("漂浮高度: %.2f", distanceToGround)
    else
        return false, string.format("正常落地: %.2f", distanceToGround)
    end
end

-- 等待区域完全加载（动态检测，替代固定等待）
-- @param timeout 超时时间（秒），默认15秒
-- @param checkInterval 检查间隔（秒），默认0.3秒
function ZoneLoadChecker:WaitForAreaLoaded(timeout, checkInterval)
    timeout = timeout or 15
    checkInterval = checkInterval or 0.3
    
    local startTime = tick()
    local lastStatus = ""
    
    while tick() - startTime < timeout do
        -- 检查Area文件夹
        local areaLoaded, areaMsg = self.IsAreaFolderLoaded()
        if areaLoaded then
            -- 检查地面
            local groundLoaded, groundY = self:CheckGroundBelow()
            if groundLoaded then
                local character = player.Character
                if character then
                    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
                    if humanoidRootPart then
                        local playerY = humanoidRootPart.Position.Y
                        local distanceToGround = playerY - groundY
                        
                        -- 如果距离地面在合理范围内（0-15单位），认为已加载完成
                        if distanceToGround >= 0 and distanceToGround <= 15 then
                            return true, "区块加载完成，地面已就绪"
                        else
                            lastStatus = string.format("地面距离: %.2f (等待更近的地面)", distanceToGround)
                        end
                    end
                end
            else
                lastStatus = "地面未检测到 (区域可能还在加载)"
            end
        else
            lastStatus = areaMsg
        end
        
        task.wait(checkInterval)
    end
    
    return false, "加载超时: " .. lastStatus
end

-- 综合传送后处理（确保正确落地）
function ZoneLoadChecker:AfterTeleport()
    RiftAddLog("检测传送后状态...")
    
    -- 等待区域加载（动态检测，替代固定等待）
    RiftAddLog("等待区域加载...")
    local loaded, loadMsg = self:WaitForAreaLoaded(12, 0.3)
    
    if not loaded then
        RiftAddLog("区域加载未完成: " .. loadMsg)
    else
        RiftAddLog("区域加载完成")
    end
    
    -- 检查是否漂浮
    local isFloating, floatMsg = self:IsFloating()
    if isFloating then
        RiftAddLog("检测到漂浮状态: " .. floatMsg)
        RiftAddLog("等待物理引擎稳定...")
        
        -- 等待物理引擎更新几次
        for i = 1, 10 do
            task.wait(0.1)
            isFloating, floatMsg = self:IsFloating()
            if not isFloating then
                RiftAddLog("已落地: " .. floatMsg)
                return true
            end
        end
        
        RiftAddLog("无法落地，但继续执行...")
        return false
    else
        RiftAddLog("状态正常: " .. floatMsg)
        return true
    end
end

-- 预加载检测（在传送前调用）
function ZoneLoadChecker:BeforeTeleport()
    RiftAddLog("传送前预检测...")
    
    -- 确保Area文件夹已存在
    local success, areaFolder = pcall(function()
        return workspace:WaitForChild("Area", 5)
    end)
    
    if not success then
        RiftAddLog("警告: Area文件夹未就绪")
        return false
    end
    
    RiftAddLog("Area文件夹已就绪")
    return true
end

-- 完整安全传送流程（推荐使用）
function ZoneLoadChecker:SafeTeleport(teleportFunction, reason)
    reason = reason or "未命名"
    
    -- 传送前检测
    if not self:BeforeTeleport() then
        RiftAddLog("传送前检测未通过")
    end
    
    -- 执行传送
    RiftAddLog(string.format("执行传送: %s", reason))
    teleportFunction()
    
    -- 传送后处理
    return self:AfterTeleport()
end

-- 导出供全局使用
_G.ZoneLoadChecker = ZoneLoadChecker

-- ============================================
-- 增强锚定系统（防止被拽回）
-- =============================================================
-- 原因：当区块未加载时传送，服务器认为你的位置还在上次确认的地方
-- 当你移动时，服务器检测到位置差异太大，强制将你拽回上次确认的位置
-- 解决方案：传送后立即锚定角色，等待加载完成后再解锁
-- =============================================================

local AnchorManager = {}

-- 锚定角色（防止被拽回）
function AnchorManager:Anchor(enable, reason)
    reason = reason or "未命名"
    local character = player.Character
    if not character then return false end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false end
    
    -- 设置 Anchored 状态
    local success, err = pcall(function()
        humanoidRootPart.Anchored = enable
    end)
    
    if success then
        if enable then
            RiftAddLog(string.format("[锚定] ✓ 已锚定: %s", reason))
        else
            RiftAddLog(string.format("[锚定] ✓ 已解锁: %s", reason))
        end
        return true
    else
        RiftAddLog(string.format("[锚定] ⚠ %s失败: %s", enable and "锚定" or "解锁", err))
        return false
    end
end

-- 锚定并等待区域加载（增强版）
function AnchorManager:AnchorAndWaitForLoad(timeout, reason)
    reason = reason or "加载"
    
    -- 立即锚定，防止被拽回
    self:Anchor(true, reason)
    
    -- 等待区域加载
    local loaded, msg = ZoneLoadChecker:WaitForAreaLoaded(timeout, 0.3)
    
    if not loaded then
        RiftAddLog(string.format("[锚定] 加载超时: %s", msg))
    end
    
    return loaded, msg
end

-- 检测是否需要锚定（检测到悬浮状态时自动锚定）
function AnchorManager:ShouldAnchor()
    local isFloating, msg = ZoneLoadChecker:IsFloating()
    return isFloating, msg
end

-- 安全传送后锚定（增强版TeleportTo配套）
function AnchorManager:SafeTeleportAnchor(teleportFunction, reason, timeout)
    reason = reason or "传送"
    timeout = timeout or 15
    
    -- 传送前锚定
    self:Anchor(true, reason .. "-传送前")
    
    -- 执行传送
    teleportFunction()
    
    -- 传送后等待加载
    local loaded, msg = self:AnchorAndWaitForLoad(timeout, reason .. "-加载中")
    
    -- 解锁并确认
    self:Anchor(false, reason .. "-解锁")
    
    -- 最后检查一次是否还在漂浮
    local isFloating, floatMsg = ZoneLoadChecker:IsFloating()
    if isFloating then
        RiftAddLog(string.format("[锚定] ⚠ 警告: 仍在漂浮 - %s", floatMsg))
        -- 再次锚定并等待
        self:Anchor(true, reason .. "-再次锚定")
        task.wait(2)
        self:Anchor(false, reason .. "-再次解锁")
    end
    
    return loaded, msg
end

-- 导出供全局使用
_G.AnchorManager = AnchorManager

RiftAddLog("增强锚定系统已加载 - 防止被拽回")

-- 检测玩家是否在地面上（使用射线检测，原有函数保留但增强）
local function IsPlayerOnGround()
    local character = player.Character
    if not character then return false end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    
    -- 使用游戏内置的 GroundDetectUtil
    if _G.PathTool and _G.PathTool.GroundDetectUtil then
        return _G.PathTool.GroundDetectUtil.IsOnGround(humanoidRootPart.CFrame.Position)
    end
    
    -- 备用：使用射线检测
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {character}
    
    local rayResult = workspace:Raycast(
        humanoidRootPart.Position,
        Vector3.new(0, -10, 0),
        rayParams
    )
    
    return rayResult ~= nil
end

-- 检测区块是否加载完成（增强版，替代原有函数）
local function AreChunksLoaded(timeout)
    timeout = timeout or 10
    local startTime = tick()
    
    while (tick() - startTime) < timeout do
        -- 使用ZoneLoadChecker检测
        local zoneLoaded, zoneMsg = ZoneLoadChecker.IsAreaFolderLoaded()
        if zoneLoaded then
            local groundLoaded, groundY = ZoneLoadChecker:CheckGroundBelow()
            if groundLoaded then
                local character = player.Character
                if character then
                    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
                    if humanoidRootPart then
                        local distance = humanoidRootPart.Position.Y - groundY
                        if distance >= 0 and distance <= 15 then
                            return true
                        end
                    end
                end
            end
        end
        
        -- 检测周围是否有地形或建筑物
        pcall(function()
            local character = player.Character
            if not character then return false end
            
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if not humanoidRootPart then return false end
            
            local pos = humanoidRootPart.Position
            
            local searchRadius = 20
            local parts = workspace:GetPartBoundsInBox(
                CFrame.new(pos),
                Vector3.new(searchRadius * 2, searchRadius * 2, searchRadius * 2)
            )
            
            -- 如果找到足够多的部件，认为区块已加载
            if #parts >= 3 and IsPlayerOnGround() then
                return true
            end
        end)
        
        task.wait(0.3)
    end
    
    return false
end

-- 等待区块加载完成（增强版，替代原有函数）
local function WaitForChunksLoaded(maxWait)
    maxWait = maxWait or 15
    local waited = 0
    
    -- 使用ZoneLoadChecker的动态检测
    local loaded, msg = ZoneLoadChecker:WaitForAreaLoaded(maxWait, 0.3)
    if loaded then
        return true
    end
    
    RiftAddLog(string.format("等待区块加载... (%.1fs)", waited))
    
    while waited < maxWait do
        if AreChunksLoaded(0) then
            return true
        end
        
        task.wait(0.5)
        waited = waited + 0.5
    end
    
    RiftAddLog("区块加载超时")
    return false
end

-- 等待服务器位置同步（确保服务器已将玩家添加到ZonePlayers列表）
-- 这是进入裂缝的关键：服务器会检查ZonePlayers[p16:GetUserId()]
-- 根据DungeonSystem.Source.txt，服务器会检查v19.ZonePlayers[p16:GetUserId()]
-- Zone系统需要时间检测玩家位置并添加到ZonePlayers列表
local function WaitForServerPositionSync(timeout)
    timeout = timeout or 8
    local startTime = tick()
    
    RiftAddLog("等待服务器位置同步（Zone系统检测）...")
    
    local character = player.Character
    if not character then
        RiftAddLog("角色不存在，无法同步")
        return false
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        RiftAddLog("HumanoidRootPart不存在，无法同步")
        return false
    end
    
    -- 记录初始位置
    local initialPos = humanoidRootPart.Position
    local stableCount = 0  -- 位置稳定的次数
    local requiredStableCount = 3  -- 需要连续稳定3次才认为已同步
    
    while tick() - startTime < timeout do
        -- 通过多次轻微移动触发服务器位置更新和Zone检测
        for i = 1, 3 do
            pcall(function()
                local currentPos = humanoidRootPart.Position
                -- 轻微移动（不同方向）以触发服务器同步
                local offset = Vector3.new(
                    (i % 2 == 0 and 0.02 or -0.02),
                    0.01,
                    (i % 3 == 0 and 0.02 or -0.02)
                )
                humanoidRootPart.CFrame = CFrame.new(currentPos + offset)
                task.wait(0.05)
                humanoidRootPart.CFrame = CFrame.new(currentPos)
            end)
            task.wait(0.1)
        end
        
        -- 等待Zone系统更新（Zone系统需要时间检测玩家位置）
        task.wait(0.8)
        
        -- 检查位置是否稳定（如果位置不再被拽回，说明服务器已同步）
        local currentPos = humanoidRootPart.Position
        local distanceFromInitial = (currentPos - initialPos).Magnitude
        
        -- 如果位置稳定（距离初始位置不远，且没有被拽回）
        -- 增加20范围的容错，避免落地时的小幅移动被误判为被拽回
        if distanceFromInitial < 25 then
            stableCount = stableCount + 1
            RiftAddLog(string.format("位置稳定检测 (%d/%d, 距离=%.2f)", stableCount, requiredStableCount, distanceFromInitial))
            
            if stableCount >= requiredStableCount then
                RiftAddLog("✓ 服务器位置已同步（Zone系统已检测）")
                -- 额外等待确保Zone系统完全更新
                task.wait(1)
                return true
            end
        else
            -- 位置被拽回，重置计数（距离超过25才认为被拽回）
            stableCount = 0
            RiftAddLog(string.format("位置被拽回，距离=%.2f，继续等待...", distanceFromInitial))
            initialPos = currentPos  -- 更新初始位置
        end
    end
    
    RiftAddLog("⚠ 服务器位置同步超时，但继续执行（可能Zone系统未完全检测）")
    -- 即使超时，也额外等待一下
    task.wait(1)
    return false
end

-- 传送到坐标（来自捕捉宠物.lua，带验证和重试，增强版 - 防止被拽回）
local function TeleportTo(position, reason)
    reason = reason or "未命名"
    print(string.format("[刷裂缝][TP] %s -> %s", reason, tostring(position)))
    
    -- 确保player有效
    if not player then
        player = Players.LocalPlayer
        if not player then
            warn("[刷裂缝][TP] 失败：player不存在")
            return false
        end
    end
    
    -- 等待角色加载（如果不存在）
    local character = player.Character
    if not character then
        RiftAddLog("角色不存在，等待加载...")
        local charWaitSuccess, charWaitResult = pcall(function()
            return player.CharacterAdded:Wait()
        end)
        if charWaitSuccess and charWaitResult then
            character = charWaitResult
        elseif player.Character then
            character = player.Character
        else
            -- 等待最多10秒
            local waitStart = tick()
            while not character and (tick() - waitStart) < 10 do
                if player.Character then
                    character = player.Character
                    break
                end
                task.wait(0.5)
            end
        end
    end
    
    if not character then
        warn("[刷裂缝][TP] 失败：角色加载超时")
        return false
    end
    
    -- 等待HumanoidRootPart加载
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        RiftAddLog("HumanoidRootPart不存在，等待加载...")
        local hrpSuccess, hrpResult = pcall(function()
            return character:WaitForChild("HumanoidRootPart", 10)
        end)
        if hrpSuccess and hrpResult then
            humanoidRootPart = hrpResult
        end
    end
    
    if not humanoidRootPart then
        warn("[刷裂缝][TP] 失败：HumanoidRootPart加载超时")
        return false
    end
    
    -- 尝试传送（最多3次）
    for attempt = 1, 3 do
        local success, err = pcall(function()
            humanoidRootPart.CFrame = CFrame.new(position)
        end)
        
        if not success then
            warn(string.format("[刷裂缝][TP] 设置位置失败 (%d/3): %s", attempt, tostring(err)))
            task.wait(0.3)
            continue
        end
        
        -- 等待位置更新
        task.wait(0.3)
        
        -- 验证位置
        local newPosition = humanoidRootPart.Position
        local distance = (newPosition - position).Magnitude
        
        if distance <= 15 then
            print(string.format("[刷裂缝][TP] ✓ 成功: 距离=%.2f", distance))
            
            -- 等待区域加载完成
            RiftAddLog("等待区域加载...")
            ZoneLoadChecker:WaitForAreaLoaded(12, 0.3)
            
            -- 关键：等待服务器同步位置（让服务器将玩家添加到ZonePlayers列表）
            -- 这是进入裂缝的前提条件，服务器会检查ZonePlayers[p16:GetUserId()]
            -- 根据DungeonSystem.Source.txt，服务器会检查v19.ZonePlayers[p16:GetUserId()]
            WaitForServerPositionSync(5)
            
            RiftAddLog("位置同步完成，可以尝试进入裂缝")
            return true
        else
            warn(string.format("[刷裂缝][TP] 验证失败 (%d/3): 距离=%.2f", attempt, distance))
            task.wait(0.3)
        end
    end
    
    warn("[刷裂缝][TP] 传送失败3次")
    return false
end

-- 检查区域是否解锁
local function IsAreaUnlocked(areaId)
    if not PathTool then return false end
    
    local unlocked = false
    pcall(function()
        local gp = PathTool.ClientPlayerManager.GetGamePlayer()
        if gp and gp.area and gp.area.IsAreaUnlocked then
            unlocked = gp.area:IsAreaUnlocked(areaId)
        end
    end)
    return unlocked
end

-- 传送到指定区域
-- 返回: success, usedFallback (是否使用了备用坐标)
local function TeleportToArea(areaInfo)
    if not PathTool then return false, false end
    
    local areaId = areaInfo.id
    local fallbackPos = areaInfo.fallbackPos
    local unlocked = IsAreaUnlocked(areaId)
    
    if unlocked then
        local success = pcall(function()
            if PathTool.AreaSystem and PathTool.AreaSystem.ClientTeleportToAreaRegion then
                PathTool.AreaSystem.ClientTeleportToAreaRegion(areaId)
            end
        end)
        
        if success then
            -- 等待传送完成
            task.wait(1)
            
            -- 关键：传送后检测区域是否解锁（可能传送后解锁了）
            local unlockedAfterTP = IsAreaUnlocked(areaId)
            if unlockedAfterTP then
                RiftAddLog(string.format("%s 传送后已解锁", areaInfo.name))
            else
                RiftAddLog(string.format("%s 传送后仍未解锁，尝试周围传送", areaInfo.name))
                -- 如果仍未解锁，尝试在备用坐标周围传送
                if fallbackPos then
                    local offsets = {
                        Vector3.new(30, 0, 0),   -- 右
                        Vector3.new(-30, 0, 0),  -- 左
                        Vector3.new(0, 0, 30),   -- 前
                        Vector3.new(0, 0, -30),  -- 后
                        Vector3.new(30, 0, 30),  -- 右前
                        Vector3.new(-30, 0, 30), -- 左前
                        Vector3.new(30, 0, -30), -- 右后
                        Vector3.new(-30, 0, -30) -- 左后
                    }
                    
                    for i, offset in ipairs(offsets) do
                        local tryPos = fallbackPos + offset
                        RiftAddLog(string.format("尝试位置 %d/8: %s", i, tostring(tryPos)))
                        TeleportTo(tryPos, areaInfo.name .. "-周围传送" .. i)
                        task.wait(1)
                        
                        -- 检测是否解锁
                        unlockedAfterTP = IsAreaUnlocked(areaId)
                        if unlockedAfterTP then
                            RiftAddLog(string.format("✓ 在位置 %d 解锁了区域", i))
                            break
                        end
                    end
                end
            end
            
            -- 验证位置：检查玩家是否在目标区域
            local character = player.Character
            local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                local playerPos = humanoidRootPart.Position
                local areaFolder = workspace:FindFirstChild("Area")
                local targetAreaName = areaInfo.areaName or areaInfo.name
                
                if areaFolder then
                    local targetArea = areaFolder:FindFirstChild(targetAreaName)
                    if targetArea then
                        -- 检查玩家是否在目标区域内（通过检查区域内的Dungeon节点距离）
                        local areaSubFolder = targetArea:FindFirstChild("Area")
                        local serverZoneFolder = targetArea:FindFirstChild("ServerZone")
                        local checkZone = areaSubFolder or serverZoneFolder
                        
                        if checkZone then
                            local dungeonFolder = checkZone:FindFirstChild("Dungeon")
                            if dungeonFolder then
                                local isInArea = false
                                for _, node in ipairs(dungeonFolder:GetChildren()) do
                                    if string.sub(node.Name, 1, 8) == "Dungeon_" then
                                        local nodePos = node:GetPivot().Position
                                        local distance = (playerPos - nodePos).Magnitude
                                        if distance < 500 then
                                            isInArea = true
                                            print(string.format("[刷裂缝] %s 传送成功，位置已验证（距离裂缝: %.2f）", areaInfo.name, distance))
                                            break
                                        end
                                    end
                                end
                                
                                if not isInArea then
                                    warn(string.format("[刷裂缝] %s 传送后位置验证失败，可能未传送到目标区域", areaInfo.name))
                                    -- 如果验证失败，等待更长时间让区域加载
                                    task.wait(2)
                                end
                            end
                        end
                    end
                end
            end
            
            return success, false  -- 已解锁，不使用备用坐标
        end
        
        return success, false  -- 已解锁，不使用备用坐标
    else
        print(string.format("[刷裂缝] %s 未解锁，使用坐标传送", areaInfo.name))
        if fallbackPos then
            TeleportTo(fallbackPos, areaInfo.name .. "-备用坐标")
            
            -- 传送后检测区域是否解锁
            task.wait(1)
            local unlockedAfterTP = IsAreaUnlocked(areaId)
            if unlockedAfterTP then
                RiftAddLog(string.format("%s 传送后已解锁", areaInfo.name))
            else
                RiftAddLog(string.format("%s 传送后仍未解锁，尝试周围传送", areaInfo.name))
                -- 如果仍未解锁，尝试在备用坐标周围传送
                local offsets = {
                    Vector3.new(30, 0, 0),   -- 右
                    Vector3.new(-30, 0, 0),  -- 左
                    Vector3.new(0, 0, 30),   -- 前
                    Vector3.new(0, 0, -30),  -- 后
                    Vector3.new(30, 0, 30),  -- 右前
                    Vector3.new(-30, 0, 30), -- 左前
                    Vector3.new(30, 0, -30), -- 右后
                    Vector3.new(-30, 0, -30) -- 左后
                }
                
                for i, offset in ipairs(offsets) do
                    local tryPos = fallbackPos + offset
                    RiftAddLog(string.format("尝试位置 %d/8: %s", i, tostring(tryPos)))
                    TeleportTo(tryPos, areaInfo.name .. "-周围传送" .. i)
                    task.wait(1)
                    
                    -- 检测是否解锁
                    unlockedAfterTP = IsAreaUnlocked(areaId)
                    if unlockedAfterTP then
                        RiftAddLog(string.format("✓ 在位置 %d 解锁了区域", i))
                        break
                    end
                end
            end
            
            return true, true  -- 使用了备用坐标
        end
        return false, false
    end
end

-- 地牢通道调用（来自捕捉宠物.lua）
local function DoDungeonRequest(channelName, ...)
    local args = { ... }
    local unpackArgs = table.unpack or unpack
    
    if PathTool and PathTool.DataPullManager then
        local channel = PathTool.DataPullManager.GetChannel(channelName)
        if channel then
            local ok, result = pcall(function()
                return channel:DoRequest(unpackArgs(args))
            end)
            if ok then
                return result ~= false
            end
        end
    end
    
    -- 备用方案
    local DataPullFunc = game:GetService("ReplicatedStorage"):FindFirstChild("DataPullFunc", true)
    if not DataPullFunc then return false end
    
    local callArgs = { channelName, unpackArgs(args) }
    local ok, result = pcall(function()
        return DataPullFunc:InvokeServer(unpackArgs(callArgs))
    end)
    
    if not ok then
        warn("[刷裂缝] 通道请求失败:", channelName, result)
        return false
    end
    return result ~= false
end

-- 创建并启动地牢（来自捕捉宠物.lua TryCreateAndStartDungeon）
local function TryCreateAndStartDungeon(node)
    if not node or not node.Parent then
        warn("[刷裂缝] TryCreateAndStartDungeon: 节点无效或已销毁")
        return false
    end
    
    -- 从节点名称提取 showId (Dungeon_XXXX 中的 XXXX)
    local showId = tonumber(string.sub(node.Name or "", 9))
    local startTick = node:GetAttribute("DungeonStartTick")
    
    -- 如果属性在父节点上，尝试从父节点获取
    if not startTick then
        local parent = node.Parent
        if parent then
            startTick = parent:GetAttribute("DungeonStartTick")
        end
    end
    
    if not showId or not startTick then
        warn(string.format("[刷裂缝] TryCreateAndStartDungeon: 缺少必要参数 showId=%s, startTick=%s", 
            tostring(showId), tostring(startTick)))
        return false
    end
    
    print(string.format("[刷裂缝] 创建地牢队伍: showId=%d, startTick=%s", showId, tostring(startTick)))
    local okCreate = DoDungeonRequest("DungeonCreateTeamChannel", showId, startTick)
    if not okCreate then
        warn("[刷裂缝] 创建地牢队伍失败")
        return false
    end
    print("[刷裂缝] ✓ 地牢队伍创建成功")
    
    -- 创建队伍后增加延迟再开始
    task.wait(1.5)
    
    -- 再次验证节点仍然有效
    if not node or not node.Parent then
        warn("[刷裂缝] TryCreateAndStartDungeon: 节点在等待过程中已销毁")
        return false
    end
    
    -- 重新获取 startTick（可能已变化）
    local latestStartTick = node:GetAttribute("DungeonStartTick")
    if not latestStartTick then
        local parent = node.Parent
        if parent then
            latestStartTick = parent:GetAttribute("DungeonStartTick")
        end
    end
    
    if not latestStartTick then
        warn("[刷裂缝] TryCreateAndStartDungeon: 无法获取最新的 startTick")
        return false
    end
    
    print(string.format("[刷裂缝] 启动地牢: showId=%d, startTick=%s", showId, tostring(latestStartTick)))
    local okStart = DoDungeonRequest("DungeonStartChannel", showId, latestStartTick)
    if okStart then
        print("[刷裂缝] ✓ 地牢启动成功")
    else
        warn("[刷裂缝] 地牢启动失败")
    end
    return okStart
end

-- 检测是否在战斗中（来自捕捉宠物.lua）
local function IsInBattle()
    if not PathTool then return false end
    
    local inBattle = false
    pcall(function()
        local gp = PathTool.ClientPlayerManager.GetGamePlayer()
        if gp then
            local dungeonTick = gp:GetAttribute("DungeonStartTick")
            inBattle = dungeonTick and dungeonTick > 0
        end
    end)
    return inBattle
end

-- 检查静态裂缝是否已被进入（来自捕捉宠物.lua alreadyEnteredDungeon）
local function AlreadyEnteredDungeon(node)
    if not node or not PathTool then return false end
    
    local entered = false
    pcall(function()
        local gp = PathTool.ClientPlayerManager.GetGamePlayer()
        if gp and gp.dungeon then
            local currentDungeonShowId = gp.dungeon:GetAttribute("DungeonShowId") or gp:GetAttribute("DungeonShowId")
            if currentDungeonShowId then
                local showId = tonumber(string.sub(node.Name or "", 9))
                if showId and currentDungeonShowId == showId then
                    entered = true
                end
            end
        end
    end)
    return entered
end

-- 检测静态裂缝节点是否有效（只检测当前所在区域）
-- 修改：只检测玩家当前所在区域的裂缝，避免跨区域检测
local function CheckStaticRiftInCurrentArea()
    local validNodes = {}
    
    pcall(function()
        local areaFolder = workspace:FindFirstChild("Area")
        if not areaFolder then 
            RiftAddLog("Area文件夹不存在")
            return 
        end
        
        -- 获取玩家当前所在的区域名称
        local currentAreaName = GetCurrentAreaName()
        if not currentAreaName then
            RiftAddLog("无法检测当前区域，尝试检测所有区域...")
            -- 如果无法检测，回退到检测所有区域（兼容性）
        end
        
        local character = player.Character
        local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
        local playerPos = humanoidRootPart and humanoidRootPart.Position
        
        for _, areaChild in ipairs(areaFolder:GetChildren()) do
            -- 如果检测到当前区域，只检测当前区域
            if currentAreaName and areaChild.Name ~= currentAreaName then
                -- 跳过其他区域
                continue
            end
            
            -- 如果无法检测当前区域，通过距离判断（玩家在500单位内的区域）
            if not currentAreaName and playerPos then
                local areaSubFolder = areaChild:FindFirstChild("Area")
                local serverZoneFolder = areaChild:FindFirstChild("ServerZone")
                local checkZone = areaSubFolder or serverZoneFolder
                
                if checkZone then
                    local dungeonFolder = checkZone:FindFirstChild("Dungeon")
                    if dungeonFolder then
                        local isNearby = false
                        for _, node in ipairs(dungeonFolder:GetChildren()) do
                            if string.sub(node.Name, 1, 8) == "Dungeon_" then
                                local nodePos = node:GetPivot().Position
                                local distance = (playerPos - nodePos).Magnitude
                                if distance < 500 then
                                    isNearby = true
                                    break
                                end
                            end
                        end
                        if not isNearby then
                            -- 玩家不在这个区域附近，跳过
                            continue
                        end
                    end
                end
            end
            
            RiftAddLog(string.format("检测区域: %s", areaChild.Name))
            
            -- 检查 Area.*.Area.Dungeon 路径
            local areaSubFolder = areaChild:FindFirstChild("Area")
            if areaSubFolder then
                local dungeonFolder = areaSubFolder:FindFirstChild("Dungeon")
                if dungeonFolder then
                    for _, node in ipairs(dungeonFolder:GetChildren()) do
                        -- 检查名称格式是否为 Dungeon_XXXX
                        if string.sub(node.Name, 1, 8) == "Dungeon_" then
                            local pos = node:GetPivot().Position
                            
                            -- 获取属性
                            local tmplId = node:GetAttribute("DungeonTmplId")
                            local startTick = node:GetAttribute("DungeonStartTick")
                            local groupId = node:GetAttribute("DungeonGroupId")
                            
                            -- 如果属性在父节点上，尝试从父节点获取
                            if not startTick then
                                local parent = node.Parent
                                if parent then
                                    startTick = parent:GetAttribute("DungeonStartTick")
                                    if not groupId then
                                        groupId = parent:GetAttribute("DungeonGroupId")
                                    end
                                end
                            end
                            
                            -- 静态裂缝：需要 tmplId, StartTick 和 GroupId
                            if tmplId and startTick and groupId then
                                -- 检查是否已进入
                                local isEntered = AlreadyEnteredDungeon(node)
                                if not isEntered then
                                    print(string.format("[刷裂缝] 在 %s 发现静态裂缝: %s (TmplId=%s, StartTick=%s)", 
                                        areaChild.Name, node.Name, tostring(tmplId), tostring(startTick)))
                                    table.insert(validNodes, {node = node, pos = pos, areaName = areaChild.Name})
                                end
                            end
                        end
                    end
                end
            end
            
            -- 也检查 Area.*.ServerZone.Dungeon 路径
            local serverZoneFolder = areaChild:FindFirstChild("ServerZone")
            if serverZoneFolder then
                local dungeonFolder = serverZoneFolder:FindFirstChild("Dungeon")
                if dungeonFolder then
                    for _, node in ipairs(dungeonFolder:GetChildren()) do
                        if string.sub(node.Name, 1, 8) == "Dungeon_" then
                            local pos = node:GetPivot().Position
                            
                            local tmplId = node:GetAttribute("DungeonTmplId")
                            local startTick = node:GetAttribute("DungeonStartTick")
                            local groupId = node:GetAttribute("DungeonGroupId")
                            
                            if not startTick then
                                local parent = node.Parent
                                if parent then
                                    startTick = parent:GetAttribute("DungeonStartTick")
                                    if not groupId then
                                        groupId = parent:GetAttribute("DungeonGroupId")
                                    end
                                end
                            end
                            
                            if tmplId and startTick and groupId then
                                local isEntered = AlreadyEnteredDungeon(node)
                                if not isEntered then
                                    print(string.format("[刷裂缝] 在 %s 发现静态裂缝(ServerZone): %s (TmplId=%s)", 
                                        areaChild.Name, node.Name, tostring(tmplId)))
                                    table.insert(validNodes, {node = node, pos = pos, areaName = areaChild.Name})
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    -- 返回第一个找到的静态裂缝
    if #validNodes > 0 then
        local first = validNodes[1]
        RiftAddLog(string.format("找到裂缝在区域: %s", first.areaName or "未知"))
        return first.node, first.pos
    end
    
    return nil, nil
end

-- 退出裂缝（使用 ArenaLeaveChannel，来自捕捉宠物.lua）
local function ExitRift()
    if not PathTool then return false end
    
    for attempt = 1, 3 do
        local ok = DoDungeonRequest("ArenaLeaveChannel")
        if ok then
            print("[刷裂缝] 退出成功")
            return true
        end
        task.wait(0.5)
        
        if not IsInBattle() then
            print("[刷裂缝] 已退出裂缝")
            return true
        end
    end
    warn("[刷裂缝] 退出裂缝失败")
    return false
end

-- 创建UI
local function CreateUI()
    local oldGui = player.PlayerGui:FindFirstChild("RiftRushGui")
    if oldGui then oldGui:Destroy() end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RiftRushGui"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player.PlayerGui
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 220, 0, 150)
    mainFrame.Position = UDim2.new(0.5, -110, 0, 10)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 30)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "快速刷裂缝次数"
    title.TextColor3 = Color3.fromRGB(255, 200, 100)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame
    
    local countLabel = Instance.new("TextLabel")
    countLabel.Name = "CountLabel"
    countLabel.Size = UDim2.new(1, 0, 0, 35)
    countLabel.Position = UDim2.new(0, 0, 0, 30)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = string.format("%d / %d", enteredCount, TARGET_COUNT)
    countLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    countLabel.TextSize = 28
    countLabel.Font = Enum.Font.GothamBold
    countLabel.Parent = mainFrame
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -20, 0, 20)
    statusLabel.Position = UDim2.new(0, 10, 0, 65)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "等待开始..."
    statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    statusLabel.TextSize = 12
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.Parent = mainFrame
    
    local startButton = Instance.new("TextButton")
    startButton.Name = "StartButton"
    startButton.Size = UDim2.new(0, 90, 0, 35)
    startButton.Position = UDim2.new(0, 15, 0, 95)
    startButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    startButton.Text = "开始"
    startButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    startButton.TextSize = 14
    startButton.Font = Enum.Font.GothamBold
    startButton.Parent = mainFrame
    
    local btnCorner1 = Instance.new("UICorner")
    btnCorner1.CornerRadius = UDim.new(0, 6)
    btnCorner1.Parent = startButton
    
    local resetButton = Instance.new("TextButton")
    resetButton.Name = "ResetButton"
    resetButton.Size = UDim2.new(0, 90, 0, 35)
    resetButton.Position = UDim2.new(0, 115, 0, 95)
    resetButton.BackgroundColor3 = Color3.fromRGB(150, 80, 50)
    resetButton.Text = "重置"
    resetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    resetButton.TextSize = 14
    resetButton.Font = Enum.Font.GothamBold
    resetButton.Parent = mainFrame
    
    local btnCorner2 = Instance.new("UICorner")
    btnCorner2.CornerRadius = UDim.new(0, 6)
    btnCorner2.Parent = resetButton
    
    local function UpdateUI()
        countLabel.Text = string.format("%d / %d", enteredCount, TARGET_COUNT)
        if enteredCount >= TARGET_COUNT then
            countLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        else
            countLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        end
    end
    
    local function UpdateStatus(text)
        statusLabel.Text = text
    end
    
    -- 主循环
    local function MainLoop()
        if isRunning then return end
        isRunning = true
        
        startButton.Text = "停止"
        startButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        
        UpdateStatus("等待游戏加载...")
        -- 确保PathTool可用
        if not PathTool then
            local pathToolReady = WaitForPathTool(30)
            if not pathToolReady then
                UpdateStatus("PathTool加载失败")
                isRunning = false
                startButton.Text = "开始"
                startButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
                return
            end
        end
        
        -- 确保游戏完全加载
        local gameLoaded, loadReason = IsGameFullyLoaded()
        if not gameLoaded then
            UpdateStatus(string.format("等待: %s...", loadReason))
            local loaded, reason = WaitForGameFullyLoaded(30)
            if not loaded then
                UpdateStatus("游戏加载失败")
                isRunning = false
                startButton.Text = "开始"
                startButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
                return
            end
        end
        
        while isRunning and enteredCount < TARGET_COUNT do
            local foundRift = false
            
            -- 遍历四个地图检测裂缝
            for i, areaInfo in ipairs(RIFT_AREAS) do
                if not isRunning or enteredCount >= TARGET_COUNT or foundRift then break end
                
                -- 传送到目标区域
                UpdateStatus(string.format("传送到 %s...", areaInfo.name))
                print(string.format("[刷裂缝] 传送到 %s (区域ID: %d)", areaInfo.name, areaInfo.id))
                
                local tpSuccess, usedFallback = TeleportToArea(areaInfo)
                
                -- 使用动态检测替代固定等待（基于游戏区块加载系统）
                if usedFallback then
                    -- 如果使用了备用坐标（未解锁），使用动态检测等待地图加载
                    RiftAddLog(string.format("%s 未解锁，使用动态检测加载...", areaInfo.name))
                    UpdateStatus(string.format("等待 %s 加载...", areaInfo.name))
                    
                    -- 使用ZoneLoadChecker动态检测，最长等待20秒
                    local loaded, msg = ZoneLoadChecker:WaitForAreaLoaded(20, 0.3)
                    if loaded then
                        RiftAddLog("区域加载完成")
                    else
                        RiftAddLog("加载超时，继续执行...")
                        -- 超时后再等待2秒确保稳定
                        task.wait(2)
                    end
                else
                    -- 已解锁区域，使用动态检测
                    RiftAddLog("等待区域加载...")
                    ZoneLoadChecker:WaitForAreaLoaded(8, 0.3)
                end
                
                if not isRunning then break end
                
                -- 关键：在搜索裂缝之前，判断所在区域是否解锁
                -- 如果区域没有解锁，进不去裂缝
                local currentUnlocked = IsAreaUnlocked(areaInfo.id)
                if not currentUnlocked then
                    RiftAddLog(string.format("⚠ %s 仍未解锁，无法进入裂缝，跳过", areaInfo.name))
                    print(string.format("[刷裂缝] %s 未解锁，跳过检测裂缝", areaInfo.name))
                    task.wait(0.5)
                    continue  -- 跳过这个区域，继续下一个
                end
                
                RiftAddLog(string.format("✓ %s 已解锁，可以检测裂缝", areaInfo.name))
                
                -- 检测静态裂缝（只检测当前所在区域的裂缝，不跨区域）
                UpdateStatus(string.format("检测 %s...", areaInfo.name))
                RiftAddLog(string.format("检测 %s 的裂缝...", areaInfo.name))
                
                local node, pos = CheckStaticRiftInCurrentArea()
                
                if node and pos then
                    print(string.format("[刷裂缝] 在 %s 发现裂缝，准备进入", areaInfo.name))
                    
                    -- 传送到裂缝位置（使用增强版TeleportTo，包含落地检测）
                    UpdateStatus("传送到裂缝...")
                    TeleportTo(pos + Vector3.new(0, 3, 0), "进入裂缝")
                    
                    -- 关键：再次等待服务器位置同步，确保服务器已将玩家添加到ZonePlayers列表
                    -- 根据DungeonSystem.Source.txt，服务器会检查v19.ZonePlayers[p16:GetUserId()]
                    -- Zone系统需要时间检测玩家位置并添加到ZonePlayers列表
                    UpdateStatus("等待服务器确认位置...")
                    RiftAddLog("等待服务器位置同步（进入裂缝前，关键步骤）...")
                    
                    -- 增加等待时间，确保Zone系统有足够时间检测
                    local syncSuccess = WaitForServerPositionSync(8)  -- 增加到8秒
                    if not syncSuccess then
                        RiftAddLog("⚠ 位置同步可能未完成，但继续尝试进入")
                    end
                    
                    -- 额外等待确保Zone系统完全更新
                    task.wait(2)
                    
                    -- 尝试进入裂缝（重试5次，增加重试次数）
                    local entrySuccess = false
                    local lastError = nil
                    
                    for attempt = 1, 5 do
                        if not isRunning then break end
                        
                        UpdateStatus(string.format("进入裂缝... (%d/5)", attempt))
                        print(string.format("[刷裂缝] 尝试进入裂缝 (%d/5)", attempt))
                        
                        -- 在每次尝试前，再次确保位置稳定
                        if attempt > 1 then
                            RiftAddLog(string.format("重试 %d: 再次确认位置稳定...", attempt))
                            task.wait(1)
                            
                            -- 轻微移动触发更新
                            pcall(function()
                                local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                                if hrp then
                                    local currentPos = hrp.Position
                                    hrp.CFrame = CFrame.new(currentPos + Vector3.new(0, 0.01, 0))
                                    task.wait(0.1)
                                    hrp.CFrame = CFrame.new(currentPos)
                                end
                            end)
                            task.wait(1.5)  -- 等待Zone系统更新
                        end
                        
                        local createSuccess = TryCreateAndStartDungeon(node)
                        if createSuccess then
                            -- 成功进去就算成功
                            print("[刷裂缝] ✓ 进入成功!")
                            entrySuccess = true
                            foundRift = true
                            
                            enteredCount = enteredCount + 1
                            UpdateUI()
                            SaveConfig()
                            print(string.format("[刷裂缝] 成功! (%d/%d)", enteredCount, TARGET_COUNT))
                            UpdateStatus(string.format("成功! (%d/%d)", enteredCount, TARGET_COUNT))
                            
                            -- 关闭地牢队伍界面
                            task.wait(0.5)
                            pcall(function()
                                if PathTool and PathTool.ViewManager then
                                    PathTool.ViewManager.CloseView("DungeonTeamView")
                                end
                            end)
                            
                            -- 立即退出
                            UpdateStatus("退出裂缝...")
                            ExitRift()
                            
                            -- 退出后等待区域重新加载
                            RiftAddLog("等待退出完成...")
                            task.wait(0.5)
                            
                            break
                        else
                            warn(string.format("[刷裂缝] 创建地牢失败 (%d/5)", attempt))
                            if attempt < 5 then
                                task.wait(1)
                                -- 重新传送到裂缝位置
                                RiftAddLog(string.format("重试 %d: 重新传送到裂缝位置", attempt))
                                TeleportTo(pos + Vector3.new(0, 3, 0), "重试进入")
                                
                                -- 再次等待服务器位置同步（重试时更耐心）
                                RiftAddLog(string.format("重试 %d: 等待服务器位置同步...", attempt))
                                WaitForServerPositionSync(6)  -- 重试时等待更长时间
                                task.wait(2)  -- 额外等待
                            end
                        end
                    end
                    
                    if entrySuccess then
                        if enteredCount >= TARGET_COUNT then
                            UpdateStatus("任务完成!")
                            print("[刷裂缝] 任务完成!")
                            break
                        end
                        -- 成功进入并退出，换服务器
                        foundRift = true
                        UpdateStatus("切换服务器...")
                        print("[刷裂缝] 裂缝已完成，切换服务器")
                        break  -- 退出循环，准备换服务器
                    else
                        -- 进入失败，继续检查下一个地图
                        UpdateStatus("进入失败，检查下一个地图...")
                        print(string.format("[刷裂缝] %s 进入裂缝失败5次，检查下一个地图", areaInfo.name))
                        RiftAddLog("可能原因：服务器Zone系统未检测到玩家位置")
                        task.wait(1)
                        -- 继续下一个地区
                    end
                else
                    -- 当前区域没有裂缝，继续下一个地区
                    print(string.format("[刷裂缝] %s 没有裂缝，检查下一个地图", areaInfo.name))
                    RiftAddLog(string.format("%s 没有裂缝", areaInfo.name))
                    task.wait(0.5)
                    -- 继续循环，检查下一个地区
                end
            end
            
            -- 四个地图都检测完，切换服务器（带重试机制）
            if isRunning and enteredCount < TARGET_COUNT then
                if foundRift then
                    UpdateStatus("切换服务器...")
                    print("[刷裂缝] 裂缝已完成，切换服务器")
                else
                    UpdateStatus("未发现裂缝，换服...")
                    print("[刷裂缝] 四个地图都没有裂缝，切换服务器")
                end
                SaveConfig()
                task.wait(1)
                
                -- 多次尝试切换服务器（最多10次）
                local maxTotalRetries = 10
                local retryCount = 0
                local allFailed = true
                
                while retryCount < maxTotalRetries and isRunning do
                    retryCount = retryCount + 1
                    UpdateStatus(string.format("切换服务器 (%d/%d)...", retryCount, maxTotalRetries))
                    RiftAddLog(string.format("切换服务器 (%d/%d)", retryCount, maxTotalRetries))
                    
                    -- 先尝试局域网/API获取服务器
                    local selectedServer = GetServerFromLAN()
                    local hopSuccess = false
                    
                    if selectedServer then
                        hopSuccess = DoServerHop()
                    else
                        -- 局域网获取失败，尝试随机传送
                        RiftAddLog("局域网无服务器，尝试随机传送...")
                        local randomOk = pcall(function()
                            TeleportService:Teleport(game.PlaceId, player)
                        end)
                        if randomOk then
                            hopSuccess = true
                            task.wait(3)  -- 随机传送后等待
                        end
                    end
                    
                    if hopSuccess then
                        allFailed = false
                        RiftAddLog("✓ 服务器切换成功")
                        break
                    end
                    
                    -- 失败后等待，递增延迟
                    local waitTime = math.min(5 + retryCount * 2, 30)  -- 从5秒开始，最长30秒
                    RiftAddLog(string.format("传送失败，等待%ds后重试...", waitTime))
                    UpdateStatus(string.format("切换失败，等待%ds...", waitTime))
                    task.wait(waitTime)
                end
                
                if allFailed then
                    RiftAddLog(string.format("⚠ 尝试%d次全部失败，休息1分钟后重试...", maxTotalRetries))
                    UpdateStatus("切换失败，休息1分钟...")
                    task.wait(60)  -- 休息1分钟
                end
                
                return
            end
        end
        
        isRunning = false
        startButton.Text = "开始"
        startButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        
        if enteredCount >= TARGET_COUNT then
            UpdateStatus("任务完成，领取奖励...")
            DeleteConfig()
            task.wait(1)
            
            -- 自动领取奖励
            local claimSuccess = ClaimRiftTaskReward()
            if claimSuccess then
                UpdateStatus("奖励领取成功!")
                print("[刷裂缝] ✓ 周任务奖励领取成功")
                
                -- 写入 yummytool 标记文件
                task.wait(0.5)
                WriteYummyToolMarker()
            else
                UpdateStatus("奖励领取失败")
                warn("[刷裂缝] ⚠ 周任务奖励领取失败，请手动领取")
            end
        else
            UpdateStatus("已停止")
        end
    end
    
    startButton.MouseButton1Click:Connect(function()
        if isRunning then
            isRunning = false
            startButton.Text = "开始"
            startButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
            UpdateStatus("已停止")
        else
            spawn(MainLoop)
        end
    end)
    
    resetButton.MouseButton1Click:Connect(function()
        enteredCount = 0
        UpdateUI()
        DeleteConfig()
        UpdateStatus("已重置")
    end)
    
    UpdateUI()
    
    -- 界面加载完成，启动FPS Booster
    RiftAddLog("界面加载完成，启动FPS Booster...")
    pcall(function()
        _G.Ignore = {}
        _G.Settings = {
            Players = {
                ["Ignore Me"] = true,
                ["Ignore Others"] = true,
                ["Ignore Tools"] = true
            },
            Meshes = {
                NoMesh = true,
                NoTexture = true,
                Destroy = false
            },
            Images = {
                Invisible = true,
                Destroy = false
            },
            Explosions = {
                Smaller = true,
                Invisible = true, -- Not for PVP games
                Destroy = true -- Not for PVP games
            },
            Particles = {
                Invisible = true,
                Destroy = true
            },
            TextLabels = {
                LowerQuality = true,
                Invisible = true,
                Destroy = false
            },
            MeshParts = {
                LowerQuality = true,
                Invisible = true,
                NoTexture = true,
                NoMesh = true,
                Destroy = false
            },
            Other = {
                ["FPS Cap"] = 10, -- true to uncap
                ["No Camera Effects"] = true,
                ["No Clothes"] = true,
                ["Low Water Graphics"] = true,
                ["No Shadows"] = true,
                ["Low Rendering"] = true,
                ["Low Quality Parts"] = true,
                ["Low Quality Models"] = true,
                ["Reset Materials"] = true,
            }
        }
        loadstring(game:HttpGet("https://raw.githubusercontent.com/CasperFlyModz/discord.gg-rips/main/FPSBooster.lua"))()
        RiftAddLog("FPS Booster已启动")
    end)
    
    -- 自动开始或领取奖励
    if enteredCount < TARGET_COUNT then
        -- 任务未完成，自动开始
        if enteredCount > 0 then
            UpdateStatus("检测到未完成任务，自动继续...")
        else
            UpdateStatus("自动开始...")
        end
        task.wait(2)
        spawn(MainLoop)
    else
        -- 任务已完成，检查是否需要领取奖励
        local _, _, taskCompleted = GetRiftTaskInfo()
        if taskCompleted then
            -- 奖励已领取，直接写入标记文件
            UpdateStatus("奖励已领取!")
            print("[刷裂缝] 任务已完成且奖励已领取")
            WriteYummyToolMarker()
        else
            -- 奖励未领取，自动领取
            UpdateStatus("任务完成，领取奖励...")
            task.wait(1)
            local claimSuccess = ClaimRiftTaskReward()
            if claimSuccess then
                UpdateStatus("奖励领取成功!")
                print("[刷裂缝] ✓ 周任务奖励领取成功")
                task.wait(0.5)
                WriteYummyToolMarker()
            else
                UpdateStatus("领取失败，请手动领取")
                warn("[刷裂缝] ⚠ 周任务奖励领取失败")
            end
        end
    end
    
    return screenGui
end

-- ============================================
-- 启动流程
-- ============================================
spawn(function()
    RiftAddLog("正在加载PathTool...")

    local pathToolReady = WaitForPathTool(30)
    if not pathToolReady then
        RiftAddLog("错误: PathTool加载超时")
        return
    end

    RiftAddLog("PathTool加载成功")
    RiftAddLog("等待游戏完全加载...")

    local gameLoaded, loadReason = WaitForGameFullyLoaded(120)

    if not gameLoaded then
        RiftAddLog(string.format("加载失败: %s", loadReason))
        RiftAddLog("尝试切换服务器...")
        DoServerHop()
        return
    end

    RiftAddLog(string.format("游戏已就绪: %s", loadReason))
    
    -- 确认ZoneLoadChecker已加载
    if _G.ZoneLoadChecker then
        RiftAddLog("区块加载检测系统已就绪")
    else
        RiftAddLog("警告: 区块加载检测系统未加载")
    end

    -- 初始化配置文件名（需要等待 player 准备好）
    if player and player.Name then
        CONFIG_FILE = "RiftRush_" .. player.Name .. ".json"
    else
        CONFIG_FILE = "RiftRush_Unknown.json"
    end
    
    -- 从游戏读取周任务进度
    local taskTarget, taskCurrent, taskCompleted = GetRiftTaskInfo()
    TARGET_COUNT = taskTarget
    enteredCount = taskCurrent
    
    RiftAddLog(string.format("周任务进度: %d/%d (已领取奖励: %s)", 
        enteredCount, TARGET_COUNT, tostring(taskCompleted)))
    
    if taskCompleted then
        RiftAddLog("周任务已完成并领取奖励!")
    end
    
    task.wait(1)
    CreateUI()
end)

RiftAddLog("脚本已启动，等待加载...")
