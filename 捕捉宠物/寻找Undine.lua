-- Re-entry guard: do not run if already disabled (multi-inject)
if _G.__FINDMONSTER_DISABLED then return end

-- Hard-disable helpers (ABORT_IF_DISABLED used everywhere; DISABLE_SCRIPT_NOW defined after alive/findMonsterEnabled)
local function ABORT_IF_DISABLED()
    return (_G.__FINDMONSTER_DISABLED == true)
end
-- ============================================
-- 寻找 Monster 独立脚本 (自动启动版)
-- 功能：自动寻找 Monster 服务器并发送通知
-- ============================================

-- ========== 游戏ID限制 ==========
local TARGET_GAME_ID = 98664161516921
if game.PlaceId ~= TARGET_GAME_ID then
    warn(string.format("[FindMonster] 游戏ID不匹配: %d (需要 %d)，脚本已禁用", game.PlaceId, TARGET_GAME_ID))
    _G.__FINDMONSTER_DISABLED = true
    return
end

-- Early top-of-file hard exit: wait for LocalPlayer/UserId, then return if blocked (no UI, no spawns, no connections)
do
    local Players = game:GetService("Players")
    if not game:IsLoaded() then game.Loaded:Wait() end
    local lp = nil
    Wait(3)
    local timeoutLp, step, waited = 15, 0.1, 0
    while true do
        lp = Players.LocalPlayer
        if lp then break end
        task.wait(step)
        waited = waited + step
        if waited >= timeoutLp then break end
    end
    if lp then
        waited = 0
        local timeoutUserId = 15  -- Pet Hunters can be slow
        while not (lp.UserId and type(lp.UserId) == "number" and lp.UserId > 0) do
            task.wait(step)
            waited = waited + step
            if waited >= timeoutUserId then break end
        end
        if not (lp.UserId and type(lp.UserId) == "number" and lp.UserId > 0) then
            _G.__FINDMONSTER_DISABLED = true
            return  -- UserId wait timeout, do not run script
        end
        local BLOCKED = { [10373072928] = true, [10424160380] = true }
        if BLOCKED[lp.UserId] then
            _G.__FINDMONSTER_DISABLED = true
            warn(string.format("[FindMonster] 此脚本不适用于当前用户 (UserId=%s)，请使用 捕捉宠物.lua", tostring(lp.UserId)))
            return
        end
    else
        return  -- LocalPlayer wait timeout, do not run script
    end
end

-- 运行限制（仅按 UserId 不允许脚本运行，不踢出服务器）
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- 封禁 UserId（请使用 捕捉宠物.lua）
local BLOCKED_USER_IDS = { [10373072928] = true, [10424160380] = true }

local HttpService = game:GetService("HttpService")

-- ============================================
-- 配置
-- ============================================
local MONSTER_TMPL_ID = 90005
local TIDELAND_AREA_ID = 9
local TIDELAND_FALLBACK_POS = Vector3.new(-5843.58, -120.44, 246.06)
local NEAR_TARGET_DISTANCE = 25  -- 距离目标小于此值视为已在目标位置
local MAX_MONSTER_NOTIFY = 15
local FIND_MONSTER_CONFIG_PATH = nil  -- 延迟初始化

local findMonsterEnabled = true
local findMonsterRunning = false
local alive = true
local findMonsterStats = {
    serversVisited = 0,
    monsterFound = 0
}
local scriptCharacterAddedConn = nil  -- 用于禁用时断开，防止 respawn 绕过

local function DISABLE_SCRIPT_NOW(msg)
    _G.__FINDMONSTER_DISABLED = true
    if msg then warn(msg) end
    pcall(function() alive = false end)
    pcall(function() findMonsterEnabled = false end)
    pcall(function()
        local cg = game:GetService("CoreGui")
        local sg = cg:FindFirstChild("FindMonster_DebugUI")
        if sg then sg:Destroy() end
    end)
    pcall(function()
        if scriptCharacterAddedConn then
            scriptCharacterAddedConn:Disconnect()
            scriptCharacterAddedConn = nil
        end
    end)
end

-- 按 UserId 不允许脚本：仅禁用脚本、设标志，不踢出服务器，返回 true 表示已禁用
local function HardBlockIfUserIsBanned(reason)
    if _G.__FINDMONSTER_DISABLED then return true end
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    local lp = nil
    local timeoutLp = 15
    local step = 0.1
    local waited = 0
    while not lp do
        lp = Players.LocalPlayer
        if lp then break end
        task.wait(step)
        waited = waited + step
        if waited >= timeoutLp then
            DISABLE_SCRIPT_NOW("[FindMonster] LocalPlayer 等待超时，脚本停止")
            return true
        end
    end
    waited = 0
    local timeoutUserId = 15  -- Pet Hunters can be slow
    while not (lp.UserId and type(lp.UserId) == "number" and lp.UserId > 0) do
        task.wait(step)
        waited = waited + step
        if waited >= timeoutUserId then
            DISABLE_SCRIPT_NOW("[FindMonster] UserId 等待超时，脚本停止")
            return true
        end
    end
    if BLOCKED_USER_IDS[lp.UserId] then
        DISABLE_SCRIPT_NOW(string.format("[FindMonster] 此脚本不适用于当前用户 (UserId=%s)，请使用 捕捉宠物.lua | reason=%s", tostring(lp.UserId), tostring(reason)))
        if scriptCharacterAddedConn then
            pcall(function() scriptCharacterAddedConn:Disconnect() end)
            scriptCharacterAddedConn = nil
        end
        return true
    end
    return false
end

-- 脚本最顶部入口：先做运行限制检查再继续
if HardBlockIfUserIsBanned("startup") then return end
player = Players.LocalPlayer
scriptCharacterAddedConn = player.CharacterAdded:Connect(function()
    if ABORT_IF_DISABLED() then return end
    if HardBlockIfUserIsBanned("CharacterAdded") then
        if scriptCharacterAddedConn then
            pcall(function() scriptCharacterAddedConn:Disconnect() end)
            scriptCharacterAddedConn = nil
        end
    end
end)

-- ============================================
-- 用于追踪玩家数量变化
-- ============================================
local lastPlayerCount = 0
local monsterActive = false  -- 标记 Monster 是否存在（与捕捉宠物.lua一致）

-- ============================================
-- Vercel通知（前置定义，供其他函数使用）
-- ============================================
local function GetVercelUrl()
    return "https://monster.suplucky.cc/api/monsters"
end

-- ============================================
-- 通知发送函数
-- ============================================
local function SendDeleteNotification()
    if ABORT_IF_DISABLED() then return end
    monsterActive = false  -- 标记 Monster 不存在
    pcall(function()
        local reqFunc = request or syn and syn.request or http_request
        if not reqFunc then
            warn("[删除通知] 没有可用的HTTP请求函数")
            return
        end
        
        local jobId = game.JobId or "Unknown"
        local vercelUrl = GetVercelUrl()
        
        if vercelUrl and jobId ~= "Unknown" then
            reqFunc({
                Url = vercelUrl .. "?jobId=" .. jobId,
                Method = "DELETE",
                Headers = {["Content-Type"] = "application/json"}
            })
            print("[Vercel] 删除请求已发送，JobId: " .. jobId)
        end
    end)
end

-- 延迟初始化配置路径（等待player加载）
local function InitConfigPath()
    if not FIND_MONSTER_CONFIG_PATH and player then
        FIND_MONSTER_CONFIG_PATH = "PetCatcher_FindMonster_" .. player.Name .. ".json"
    end
    return FIND_MONSTER_CONFIG_PATH
end

-- ============================================
-- PathTool 依赖
-- ============================================
local PathTool = rawget(_G, "PathTool")

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
    AddLog("重新获取所有依赖...")
    
    -- 清空旧的PathTool引用
    PathTool = nil
    _G.PathTool = nil
    
    -- 重新获取player
    player = Players.LocalPlayer
    if not player then
        AddLog("错误: 无法获取player")
        return false
    end
    
    -- 重新获取PathTool
    local pathToolReady = WaitForPathTool(30)
    if not pathToolReady then
        AddLog("错误: PathTool重新加载超时")
        return false
    end
    
    -- 等待游戏完全加载
    local gameLoaded, loadReason = WaitForGameFullyLoaded(60)
    if not gameLoaded then
        AddLog(string.format("游戏重新加载失败: %s", loadReason))
        return false
    end
    
    AddLog("所有依赖重新加载成功")
    return true
end

-- ============================================
-- 简单日志系统（前置）
-- ============================================
local logBuffer = {}
local maxLogs = 50
local uiReady = false
local debugLog = nil

local function AddLog(msg)
    if ABORT_IF_DISABLED() then return end
    local timestamp = os.date("%H:%M:%S")
    local fullMsg = string.format("[%s] %s", timestamp, msg)

    table.insert(logBuffer, fullMsg)
    if #logBuffer > maxLogs then
        table.remove(logBuffer, 1)
    end

    -- 同时输出到控制台
    print(fullMsg)

    -- 如果UI已就绪，更新UI
    if uiReady and debugLog then
        task.spawn(function()
            if ABORT_IF_DISABLED() then return end
            pcall(function()
                -- 清除旧日志（只保留最近的30条）
                for _, child in ipairs(debugLog:GetChildren()) do
                    if child:IsA("TextLabel") then
                        child:Destroy()
                    end
                end

                -- 添加新日志（只显示最近的30条）
                local startIndex = math.max(1, #logBuffer - 29)
                for i = startIndex, #logBuffer do
                    local logMsg = logBuffer[i]
                    local logLabel = Instance.new("TextLabel")
                    logLabel.Size = UDim2.new(1, 0, 0, 16)
                    logLabel.BackgroundTransparency = 1
                    logLabel.TextXAlignment = Enum.TextXAlignment.Left
                    logLabel.Font = Enum.Font.Gotham
                    logLabel.TextSize = 10

                    if logMsg:find("错误") or logMsg:find("失败") then
                        logLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
                    elseif logMsg:find("成功") or logMsg:find("✓") then
                        logLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
                    elseif logMsg:find("发现") then
                        logLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
                    else
                        logLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
                    end

                    logLabel.Text = logMsg
                    logLabel.Parent = debugLog
                end

                -- 强制更新CanvasSize
                local layout = debugLog:FindFirstChildOfClass("UIListLayout")
                if layout then
                    debugLog.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 4)
                end

                -- 等待渲染
                task.wait(0.05)

                -- 滚动到底部
                if debugLog and debugLog.ScrollBarThickness > 0 then
                    debugLog.CanvasPosition = Vector2.new(0, 99999)
                end
            end)
        end)
    end
end

-- ============================================
-- 辅助函数
-- ============================================

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

    local monstersReady = SafeGet(function()
        return game.Workspace:FindFirstChild("ClientMonsters") ~= nil
    end, 30, 0.2)
    if not monstersReady then
        return false, "等待ClientMonsters..."
    end

    local iterReady = SafeGet(function()
        return PathTool.MgrMonsterClient ~= nil and PathTool.MgrMonsterClient.IterMonster ~= nil
    end, 30, 0.2)
    if not iterReady then
        return false, "等待MgrMonsterClient..."
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
            AddLog(string.format("等待: %s (%.1fs)", reason, waited))
            lastReason = reason
        end

        task.wait(0.5)
        waited = waited + 0.5
    end

    return false, "超时"
end

-- ============================================
-- 区块加载检测
-- ============================================

-- 检测玩家是否在地面上（使用射线检测）
local function IsPlayerOnGround()
    pcall(function()
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
    end)
    return false
end

-- 检测区块是否加载完成
local function AreChunksLoaded(timeout)
    timeout = timeout or 10
    local startTime = tick()
    
    while (tick() - startTime) < timeout do
        pcall(function()
            local character = player.Character
            if not character then return false end
            
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if not humanoidRootPart then return false end
            
            local pos = humanoidRootPart.Position
            
            -- 检测周围是否有地形或建筑物
            local searchRadius = 20
            local parts = workspace:GetPartBoundsInBox(
                CFrame.new(pos),
                Vector3.new(searchRadius * 2, searchRadius * 2, searchRadius * 2)
            )
            
            -- 如果找到足够多的部件，认为区块已加载
            if #parts >= 3 then
                return true
            end
            
            -- 检测玩家是否在地面上
            if IsPlayerOnGround() then
                return true
            end
        end)
        
        task.wait(0.5)
    end
    
    return false
end

-- 等待区块加载完成（带超时）
local function WaitForChunksLoaded(maxWait)
    maxWait = maxWait or 15
    local waited = 0
    
    while waited < maxWait do
        if AreChunksLoaded(0) then
            return true
        end
        
        if math.floor(waited) % 2 == 0 then
            AddLog(string.format("等待区块加载... (%.1fs)", waited))
        end
        
        task.wait(0.5)
        waited = waited + 0.5
    end
    
    AddLog("区块加载超时")
    return false
end

-- ============================================
-- 平滑移动（与 monster-tracker-local.lua 一致）
-- ============================================
local FLY_HEIGHT_OFFSET = 40
local FLY_SPEED_H = 40
local FLY_SPEED_V = 30
local ROTATE_DURATION = 0.12

-- 两阶段：先仅旋转 ROTATE_DURATION，再仅位移（duration = max(distance/speed, 0.1)）。方向近零或竖直时保留当前旋转。
local function SmoothMove(startPos, endPos, speed, faceCamera)
    if ABORT_IF_DISABLED() or not alive then return false end
    local character = player and player.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp.Parent then return false end
    local distance = (endPos - startPos).Magnitude
    local moveDuration = math.max(distance / speed, 0.1)
    local direction = distance > 0.0001 and (endPos - startPos).Unit or Vector3.new(1, 0, 0)

    -- Phase 1: 仅旋转（位置固定）
    local rotateEndCFrame
    if direction.Magnitude < 0.01 or math.abs(direction.Y) > 0.95 then
        rotateEndCFrame = CFrame.new(startPos) * (hrp.CFrame - hrp.CFrame.Position)
    else
        rotateEndCFrame = CFrame.lookAt(startPos, startPos + direction)
    end
    local rotateTween = TweenService:Create(hrp, TweenInfo.new(ROTATE_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { CFrame = rotateEndCFrame })
    rotateTween:Play()
    rotateTween.Completed:Wait()
    if ABORT_IF_DISABLED() or not alive then return false end
    hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp.Parent then return false end

    -- Phase 2: 仅位移（保持旋转）
    local cam = workspace.CurrentCamera
    local conn
    if faceCamera and cam then
        conn = RunService.RenderStepped:Connect(function()
            if not hrp or not hrp.Parent then return end
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, endPos)
        end)
    end
    local moveEndCFrame = CFrame.new(endPos) * (hrp.CFrame - hrp.CFrame.Position)
    local moveTween = TweenService:Create(hrp, TweenInfo.new(moveDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { CFrame = moveEndCFrame })
    moveTween:Play()
    moveTween.Completed:Wait()
    if conn then conn:Disconnect() end
    return true
end

-- ============================================
-- 传送函数
-- ============================================
local function TeleportToTideland()
    -- 双重保护：先检查 player 是否有效，如果无效则重新获取
    local protectedCall, pcallErr = pcall(function()
        if not player then 
            -- 重新获取player
            player = Players.LocalPlayer
            if not player then return false end
        end
        -- 尝试访问 player 的 Name 属性来验证
        local _ = player.Name
        return true
    end)
    
    if not protectedCall then
        AddLog("错误: player 无效或已离开，尝试重新获取...")
        player = Players.LocalPlayer
        if not player then
            AddLog("错误: 无法重新获取player")
            return false
        end
    end
    
    -- 等待角色加载（简单可靠的方式，带超时）
    local character
    local charSuccess, charErr = pcall(function()
        if player.Character then
            character = player.Character
        else
            -- 如果角色不存在，使用WaitForChild等待（带超时）
            local charWaitSuccess, charWaitResult = pcall(function()
                return Players.LocalPlayer.CharacterAdded:Wait()
            end)
            if charWaitSuccess and charWaitResult then
                character = charWaitResult
            elseif Players.LocalPlayer.Character then
                character = Players.LocalPlayer.Character
            else
                -- 等待最多10秒
                local waitStart = tick()
                while not character and (tick() - waitStart) < 10 do
                    if Players.LocalPlayer.Character then
                        character = Players.LocalPlayer.Character
                        break
                    end
                    task.wait(0.5)
                end
            end
        end
    end)
    
    if not charSuccess or not character then
        AddLog("错误: 角色加载失败，可能需要重新获取依赖")
        return false
    end
    
    -- 等待 HumanoidRootPart 加载完成（带超时）
    local humanoidRootPart
    local hrpSuccess, hrpErr = pcall(function()
        humanoidRootPart = character:WaitForChild("HumanoidRootPart", 15)
    end)
    
    if not hrpSuccess or not humanoidRootPart then
        AddLog("错误: HumanoidRootPart 加载超时")
        return false
    end

    local isNearTarget = false

    -- 检查是否已在目标位置附近
    local distToTarget = (humanoidRootPart.Position - TIDELAND_FALLBACK_POS).Magnitude
    AddLog(string.format("距离目标: %.1f studs", distToTarget))

    if distToTarget <= NEAR_TARGET_DISTANCE then
        AddLog("已在目标位置")
        return true, true  -- 成功，已在目标位置
    end

    -- 检查Tideland是否解锁
    local isTidelandUnlocked = false
    local unlockCheckSuccess = false

    -- 安全地检查区域解锁状态（如果PathTool无效则重新获取）
    if not PathTool then
        AddLog("PathTool无效，尝试重新获取...")
        local pathToolReady = WaitForPathTool(10)
        if not pathToolReady then
            AddLog("错误: 无法重新获取PathTool")
            return false
        end
    end
    
    local gp = nil
    pcall(function()
        if PathTool and PathTool.ClientPlayerManager then
            gp = PathTool.ClientPlayerManager.GetGamePlayer()
        end
    end)

    if gp and gp.area then
        local areaObj = gp.area
        pcall(function()
            if areaObj.IsAreaUnlocked then
                local result = areaObj:IsAreaUnlocked(TIDELAND_AREA_ID)
                -- 只有明确返回 true 才算解锁
                if result == true then
                    isTidelandUnlocked = true
                    unlockCheckSuccess = true
                    AddLog("区域解锁: 已解锁")
                else
                    AddLog(string.format("区域解锁: 未解锁 (result=%s)", tostring(result)))
                end
            else
                AddLog("区域解锁: IsAreaUnlocked 不存在")
            end
        end)
        if not unlockCheckSuccess then
            AddLog("区域解锁: pcall失败")
        end
    else
        AddLog("区域解锁: gp或area不存在")
    end

    AddLog(string.format("解锁结果: unlockCheckSuccess=%s, isTidelandUnlocked=%s",
        tostring(unlockCheckSuccess), tostring(isTidelandUnlocked)))

    -- 只有明确解锁了才使用区域传送
    local areaTeleportSuccess = false
    if unlockCheckSuccess and isTidelandUnlocked then
        AddLog("使用区域传送...")
        local pcOk, requestOk = pcall(function()
            if not (PathTool and PathTool.AreaSystem and PathTool.AreaSystem.ClientTeleportToAreaRegion) then
                return false
            end
            return PathTool.AreaSystem.ClientTeleportToAreaRegion(TIDELAND_AREA_ID)
        end)
        AddLog(string.format("区域传送请求: pcall=%s, 返回值=%s", tostring(pcOk), tostring(requestOk)))
        if requestOk == false then
            AddLog("区域传送请求被拒绝")
        end
        if pcOk and requestOk == true then
            AddLog(string.format("已发起区域传送请求(area=%d)，等待区域切换...", TIDELAND_AREA_ID))
            local function GetCurrentAreaId()
                if PathTool and PathTool.AreaUtil and PathTool.AreaUtil.GetLocalPlayerAreaId then
                    local ok, id = pcall(function() return PathTool.AreaUtil.GetLocalPlayerAreaId() end)
                    if ok and type(id) == "number" then return id end
                end
                local attr = player:GetAttribute("SpaceAreaId")
                if type(attr) == "number" then return attr end
                return nil
            end
            local deadline = tick() + 10
            local lastAreaId = GetCurrentAreaId()
            while tick() < deadline do
                local currentAreaId = GetCurrentAreaId()
                if currentAreaId == TIDELAND_AREA_ID then
                    AddLog(string.format("区域传送成功: 已进入目标区域(area=%d)", TIDELAND_AREA_ID))
                    areaTeleportSuccess = true
                    break
                end
                if currentAreaId ~= lastAreaId then
                    AddLog(string.format("区域已切换: %s -> %s", tostring(lastAreaId), tostring(currentAreaId)))
                    lastAreaId = currentAreaId
                end
                task.wait(0.2)
            end
            if not areaTeleportSuccess then
                AddLog("区域切换超时，使用fallback传送")
            end
        end
    else
        AddLog("使用直接传送...")
    end

    -- 区域传送成功则不再做距离校验与 fallback
    if areaTeleportSuccess then
        return true
    end

    -- 验证位置，如果不正确则 fallback 平滑移动
    task.wait(0.5)
    
    -- 重新获取character和humanoidRootPart（可能已经变化）
    if not character or not character.Parent then
        character = player.Character
    end
    if character then
        humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    end
    
    if humanoidRootPart then
        local currentDist = (humanoidRootPart.Position - TIDELAND_FALLBACK_POS).Magnitude
        AddLog(string.format("位置验证: %.1f studs", currentDist))

        if currentDist > NEAR_TARGET_DISTANCE then
            AddLog("位置不正确，平滑移动...")
            local targetPos = TIDELAND_FALLBACK_POS
            -- 三段飞行：先升空，再水平移动，再下降（与 monster-tracker 相同速度）
            for phase = 1, 3 do
                if ABORT_IF_DISABLED() or not alive then return false end
                if not character or not character.Parent then character = player.Character end
                if not character then break end
                humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
                if not humanoidRootPart or not humanoidRootPart.Parent then break end
                local startPos = humanoidRootPart.Position
                local ok = false
                if phase == 1 then
                    local endUp = startPos + Vector3.new(0, FLY_HEIGHT_OFFSET, 0)
                    ok = SmoothMove(startPos, endUp, FLY_SPEED_V, false)
                elseif phase == 2 then
                    local endHorizontal = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)
                    ok = SmoothMove(startPos, endHorizontal, FLY_SPEED_H, false)
                else
                    ok = SmoothMove(startPos, targetPos, FLY_SPEED_V, false)
                end
                if not ok then break end
                task.wait(0.2)
            end

            task.wait(0.5)
            
            -- 再次验证humanoidRootPart
            if character and character.Parent then
                humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            end
            
            if humanoidRootPart then
                local newDist = (humanoidRootPart.Position - TIDELAND_FALLBACK_POS).Magnitude
                AddLog(string.format("平滑移动后: %.1f studs", newDist))

                if newDist > NEAR_TARGET_DISTANCE then
                    AddLog(string.format("移动未到位: 距离 %.1f", newDist))
                    return false
                end
            else
                AddLog("错误: 移动后无法获取HumanoidRootPart")
                return false
            end
        end
    else
        AddLog("错误: 无法获取HumanoidRootPart进行位置验证")
        return false
    end

    return true
end

-- ============================================
-- Target/Claim 协议（GET-only，兼容 Roblox game:HttpGet）
-- 任一账号发现 Monster 时上报 jobId；其他账号需比对/claim 后再切换
-- 端点: GET /target, GET /target/report, GET /target/claim, GET /target/release
-- ============================================
local claimedTargetJobId = nil  -- 成功 claim 时设置，用于 release

-- ============================================
-- 服务器切换（使用局域网API，失败后随机传送）
-- ============================================

-- 局域网服务器地址（直接内置）
local LAN_SERVER_URL = "http://192.168.31.247:8765"

local function UrlEncode(str)
    return HttpService:UrlEncode(tostring(str or ""))
end

-- GET 请求并解析 JSON
local function HttpGetJson(pathWithQuery)
    if not LAN_SERVER_URL then return false, nil end
    local ok, decoded = pcall(function()
        local url = pathWithQuery:find("^https?://") and pathWithQuery or (LAN_SERVER_URL .. pathWithQuery)
        local result = game:HttpGet(url)
        if result then
            return HttpService:JSONDecode(result)
        end
        return nil
    end)
    return ok, decoded
end

-- 从局域网获取当前目标状态
local function GetActiveTargetFromLAN()
    if not LAN_SERVER_URL then return nil end
    local success, data = HttpGetJson("/target")
    if success and data and data.success and data.active_target then
        return { active_target = data.active_target, active_claim = data.active_claim }
    end
    return nil
end

-- 上报目标到局域网（GET）
local function ReportTargetToLAN(jobId, metaTable)
    if not LAN_SERVER_URL or not jobId then return end
    pcall(function()
        local metaJson = HttpService:JSONEncode(metaTable or {})
        local url = LAN_SERVER_URL .. "/target/report?job_id=" .. UrlEncode(jobId)
            .. "&reporter=" .. UrlEncode(tostring(player.UserId))
            .. "&meta=" .. UrlEncode(metaJson)
        game:HttpGet(url)
    end)
end

-- 上报并 claim（合并为一次请求，优化速度）
local function ReportAndClaimTargetToLAN(jobId, metaTable)
    if not LAN_SERVER_URL or not jobId then return false, nil end
    local ok, decoded = HttpGetJson("/target/report_and_claim?job_id=" .. UrlEncode(jobId)
        .. "&reporter=" .. UrlEncode(tostring(player.UserId))
        .. "&meta=" .. UrlEncode(HttpService:JSONEncode(metaTable or {})))
    if ok and decoded and decoded.claimed == true then
        return true, nil
    end
    return false, (decoded and decoded.reason) or "request_failed"
end

-- 从局域网 claim 目标（GET，用于 DoServerHop 中 claim 远程目标）
local function ClaimTargetFromLAN(jobId)
    if not LAN_SERVER_URL or not jobId then return false, nil end
    local ok, decoded = HttpGetJson("/target/claim?job_id=" .. UrlEncode(jobId)
        .. "&claimer=" .. UrlEncode(tostring(player.UserId)))
    if ok and decoded and decoded.claimed == true then
        return true, nil
    end
    return false, (decoded and decoded.reason) or "request_failed"
end

-- 释放目标到局域网（GET）
local function ReleaseTargetToLAN(jobId, resolvedBool)
    if not LAN_SERVER_URL or not jobId then return end
    pcall(function()
        local resolved = resolvedBool and "1" or "0"
        local url = LAN_SERVER_URL .. "/target/release?job_id=" .. UrlEncode(jobId)
            .. "&claimer=" .. UrlEncode(tostring(player.UserId))
            .. "&resolved=" .. resolved
        game:HttpGet(url)
    end)
end

-- 从局域网服务器获取服务器
local function GetServerFromLAN()
    if not LAN_SERVER_URL then return nil end

    local success, result = pcall(function()
        return game:HttpGet(LAN_SERVER_URL .. "/server")
    end)

    if success and result then
        local data = HttpService:JSONDecode(result)
        if data and data.success and data.server then
            AddLog(string.format("[LAN] 获取服务器: %s", data.server.id:sub(1, 8) .. "..."))
            return data.server
        elseif data and not data.success then
            AddLog(string.format("[LAN] %s", data.error or "无服务器"))
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

local function DoServerHop(skipTargetCheck)
    if ABORT_IF_DISABLED() then return end
    AddLog("切换服务器...")

    -- 优先检查是否有活跃目标可 claim（skipTargetCheck 为 true 时跳过，避免浪费时间尝试加入他人已 claim 的服务器）
    if not skipTargetCheck and LAN_SERVER_URL then
        local targetInfo = GetActiveTargetFromLAN()
        if targetInfo and targetInfo.active_target then
            local at = targetInfo.active_target
            local ac = targetInfo.active_claim
            if not ac then
                -- 无 claim，尝试 claim
                local claimed, reason = ClaimTargetFromLAN(at.job_id)
                if claimed then
                    claimedTargetJobId = at.job_id
                    AddLog("[TARGET] Claim success, teleporting to target...")
                    pcall(function()
                        local character = player.Character
                        if character then
                            local hrp = character:WaitForChild("HumanoidRootPart", 5)
                            if hrp then hrp.Anchored = true end
                        end
                    end)
                    local teleportOk = pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, at.job_id, player)
                    end)
                    if not teleportOk then
                        AddLog("传送调用失败")
                        claimedTargetJobId = nil
                    end
                    return
                else
                    AddLog("[TARGET] Already claimed: " .. tostring(reason))
                end
            else
                AddLog("[TARGET] Active target claimed; continue searching")
            end
        end
    end

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
                AddLog(string.format("等待%ds... (%d/%d)", retryDelay, retry, maxRetries))
                task.wait(retryDelay)
            end
        end
    end

    -- 如果局域网获取失败，使用Roblox API
    if not selectedServer then
        AddLog("使用Roblox API获取...")
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
                AddLog(string.format("API获取 %d 个服务器", #validServers))
            end
        end
    end

    -- 如果还是没有服务器，使用随机传送
    if not selectedServer then
        AddLog("无服务器，使用随机传送...")
        pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)
        return
    end

    -- 传送到服务器
    local targetJobId = selectedServer.id
    AddLog(string.format("传送: %s", targetJobId:sub(1, 8) .. "..."))

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
        AddLog("传送调用失败")
        return false
    end

    -- 检测传送是否成功（3秒后检查JobId）
    task.wait(3)
    local newJobId = game.JobId

    if newJobId == targetJobId then
        AddLog("传送成功")
        return true
    else
        AddLog(string.format("传送失败，期望: %s，实际: %s", 
            targetJobId:sub(1, 8), 
            newJobId and newJobId:sub(1, 8) or "Unknown"))
        return false
    end
end

-- ============================================
-- 怪物相关函数
-- ============================================
local function GetPlayerCount()
    return #game:GetService("Players"):GetPlayers()
end

local function FindMonsterByTmplId(tmplId)
    if not PathTool or not PathTool.MgrMonsterClient then
        return nil
    end

    local foundMonster = nil
    pcall(function()
        PathTool.MgrMonsterClient.IterMonster(function(mInfo)
            if mInfo and mInfo.TmplId == tmplId then
                local isAlive = true
                if mInfo.IsAlive then
                    isAlive = mInfo:IsAlive()
                end
                if isAlive then
                    foundMonster = mInfo
                    return false
                end
            end
            return true
        end)
    end)

    return foundMonster
end

-- 仅当 SpecialProp 为 number 时返回，否则返回 nil（用于判断是否已复制）
local function GetValidSpecialPropFromServerNode(serverNode)
    if not serverNode or not serverNode.GetAttribute then
        return nil
    end
    local sp = nil
    pcall(function()
        sp = serverNode:GetAttribute("SpecialProp")
    end)
    if type(sp) == "number" then
        return sp
    end
    return nil
end

-- 用与 GetMonsterSpecialLabelByServerNode 相同的位掩码逻辑，将数字转为标签（sp 必须为 number）
local function SpecialPropNumberToLabel(sp)
    if bit32 and bit32.band then
        if bit32.band(sp, 1) > 0 then return "huge" end
        if bit32.band(sp, 4) > 0 then return "bloodlit" end
        if bit32.band(sp, 2) > 0 then return "shiny" end
    end
    return sp ~= 0 and "特殊" or "普通"
end

-- 首次发现时等待 SpecialProp 就绪（最多 maxWait 秒，每 pollInterval 秒轮询），就绪后用相同位逻辑得到标签；超时则退回「普通」
local function WaitForSpecialPropAndGetLabel(serverNode, maxWait, pollInterval)
    maxWait = maxWait or 5
    pollInterval = pollInterval or 0.15
    local deadline = tick() + maxWait
    while tick() < deadline do
        local sp = GetValidSpecialPropFromServerNode(serverNode)
        if type(sp) == "number" then
            return SpecialPropNumberToLabel(sp)
        end
        task.wait(pollInterval)
    end
    return "未知"
end

local function GetMonsterSpecialLabelByServerNode(serverNode)
    if not serverNode or not serverNode.GetAttribute then
        return "未知"
    end

    local sp = GetValidSpecialPropFromServerNode(serverNode)
    if type(sp) ~= "number" then
        return "未知"
    end

    return SpecialPropNumberToLabel(sp)
end

local function GetMonsterHealthInfo(mInfo)
    if not mInfo then
        return { current = nil, max = nil, isUnderAttack = false }
    end

    local current, max = nil, nil

    pcall(function()
        if mInfo.HealthValue then
            if _G.PathTool and _G.PathTool.LogicNumber then
                local fixed = _G.PathTool.LogicNumber.FixLogicNumber(mInfo.HealthValue.Value)
                current = _G.PathTool.LogicNumber.ToNumber(fixed)
            else
                current = tonumber(tostring(mInfo.HealthValue.Value))
            end
        end
    end)

    pcall(function()
        if mInfo.HealthValue and mInfo.HealthValue.GetAttribute then
            local maxAttr = mInfo.HealthValue:GetAttribute("MaxHealth")
            if maxAttr then
                if _G.PathTool and _G.PathTool.LogicNumber then
                    local fixed = _G.PathTool.LogicNumber.FixLogicNumber(maxAttr)
                    max = _G.PathTool.LogicNumber.ToNumber(fixed)
                else
                    max = tonumber(tostring(maxAttr))
                end
            end
        end
    end)

    local isUnderAttack = current and max and current < max
    return { current = current, max = max, isUnderAttack = isUnderAttack }
end

-- ============================================
-- Discord通知
-- ============================================
local function GetDiscordWebhookUrl()
    -- Discord Webhook 地址（如果不需要 Discord 通知，返回 nil）
    return "https://discord.com/api/webhooks/1464767453115711684/3mfyViA-vBDoRfDZ2ovPnxYNkZgV24cRxY5jAYTn-6MgipXygbIXEYgqLKrjuaRG_Wzl"
end


local function SendDiscordNotification(title, message, color, special, hpInfo)
    pcall(function()
        local reqFunc = request or syn and syn.request or http_request
        if not reqFunc then
            warn("[通知] 没有可用的HTTP请求函数")
            return
        end

        local jobId = game.JobId or "Unknown"
        local placeId = game.PlaceId
        local joinLink = string.format("roblox://experiences/start?placeId=%d&gameInstanceId=%s", placeId, jobId)
        local playerCount = GetPlayerCount()

        -- 检查人数是否变化（只在变化时发送到Vercel）
        local playerCountChanged = (playerCount ~= lastPlayerCount)
        if playerCountChanged then
            lastPlayerCount = playerCount
        end

        -- 构建fields表（包含特殊属性）
        local fields = {
            {
                name = "JobId",
                value = "```" .. jobId .. "```",
                inline = false
            },
            {
                name = "桌面加入链接",
                value = "```" .. joinLink .. "```",
                inline = false
            },
            {
                name = "服务器人数",
                value = tostring(playerCount) .. " 人",
                inline = true
            },
            {
                name = "时间",
                value = os.date("%Y-%m-%d %H:%M:%S"),
                inline = true
            }
        }

        -- 如果有特殊属性，添加到fields中
        if special and special ~= "普通" then
            table.insert(fields, {
                name = "属性",
                value = tostring(special),
                inline = true
            })
        end

        -- 如果有战斗状态，添加到fields中
        if hpInfo and hpInfo.isUnderAttack then
            table.insert(fields, {
                name = "状态",
                value = "🔄 战斗中",
                inline = true
            })
        end

        -- Embed显示基本信息
        local embed = {
            title = title,
            description = message,
            color = color or 65280,  -- 默认绿色
            fields = fields,
            footer = {
                text = "Catch a Monster - Monster Hunter"
            }
        }

        local content = string.format(
            "**JobId (点击复制):**\n```%s```\n**桌面加入链接:**\n```%s```",
            jobId,
            joinLink
        )

        local data = {
            content = content,
            embeds = {embed},
            playerCount = playerCount  -- 额外字段给 Vercel 使用
        }

        -- 如果有特殊属性，添加到顶层（Vercel API使用）
        if special then
            data.special = special
        end

        -- 如果有战斗状态，添加到顶层（Vercel API使用）
        if hpInfo then
            data.underAttack = hpInfo.isUnderAttack
        end

        local jsonData = HttpService:JSONEncode(data)

        -- 发送到 Vercel 网页
        local vercelUrl = GetVercelUrl()
        if vercelUrl then
            reqFunc({
                Url = vercelUrl,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = jsonData
            })
            print("[Vercel] 通知已发送, 人数: " .. playerCount .. ", 属性: " .. tostring(special))
        end
        
        -- 发送到 Discord
        local discordUrl = GetDiscordWebhookUrl()
        if discordUrl then
            reqFunc({
                Url = discordUrl,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = jsonData
            })
            print("[Discord] 通知已发送")
        end
    end)
end

-- ============================================
-- 配置保存/加载
-- ============================================
local function SaveFindMonsterConfig()
    if not (writefile and readfile) then return false end

    local config = {
        enabled = findMonsterEnabled,
        stats = findMonsterStats,
        timestamp = os.time()
    }

    pcall(function()
        writefile(InitConfigPath(), HttpService:JSONEncode(config))
        AddLog("配置已保存")
    end)

    return true
end

local function LoadFindMonsterConfig()
    if not (writefile and readfile) then return nil end

    local success, result = pcall(readfile, InitConfigPath())
    if success and result then
        return HttpService:JSONDecode(result)
    end
    return nil
end

-- ============================================
-- UI
-- ============================================
local guiParent = game:GetService("CoreGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "FindMonster_DebugUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = guiParent

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 300, 0, 280)
frame.Position = UDim2.new(0, 12, 0, 12)
frame.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 20)
title.Position = UDim2.new(0, 8, 0, 6)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 12
title.TextColor3 = Color3.fromRGB(200, 180, 255)
title.Text = "寻找 Monster [自动运行]"
title.Parent = frame

debugLog = Instance.new("ScrollingFrame")
debugLog.Size = UDim2.new(1, -16, 1, -70)
debugLog.Position = UDim2.new(0, 8, 0, 28)
debugLog.BackgroundColor3 = Color3.fromRGB(20, 15, 25)
debugLog.BorderSizePixel = 0
debugLog.ScrollBarThickness = 4
debugLog.CanvasSize = UDim2.new(0, 0, 0, 0)
debugLog.Parent = frame

local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 6)
logCorner.Parent = debugLog

local logLayout = Instance.new("UIListLayout")
logLayout.Padding = UDim.new(0, 2)
logLayout.SortOrder = Enum.SortOrder.LayoutOrder
logLayout.Parent = debugLog

local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -16, 0, 16)
statsLabel.Position = UDim2.new(0, 8, 1, -38)
statsLabel.BackgroundTransparency = 1
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextSize = 10
statsLabel.TextColor3 = Color3.fromRGB(150, 150, 180)
statsLabel.Text = "统计: 服务器:0 发现:0"
statsLabel.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -32, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 80)
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.Text = "X"
closeBtn.BorderSizePixel = 0
closeBtn.Parent = frame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

local function UpdateFindMonsterStats()
    if statsLabel then
        statsLabel.Text = string.format("统计: 服务器:%d 发现:%d",
            findMonsterStats.serversVisited, findMonsterStats.monsterFound)
    end
end

alive = true  -- 与顶部声明一致，UI 就绪时保持启用
closeBtn.MouseButton1Click:Connect(function()
    if ABORT_IF_DISABLED() then return end
    if claimedTargetJobId then
        pcall(function() ReleaseTargetToLAN(game.JobId, false) end)
    end
    alive = false
    findMonsterEnabled = false
    screenGui:Destroy()
end)

-- 标记UI已就绪
uiReady = true
AddLog("UI已就绪")

-- ============================================
-- 主循环
-- ============================================
local function FindMonsterLoop()
    if ABORT_IF_DISABLED() then return end
    if findMonsterRunning then return end
    findMonsterRunning = true
    AddLog("开始寻找Monster循环")

    local consecutiveFailures = 0  -- 连续失败次数
    local maxConsecutiveFailures = 3  -- 最大连续失败次数，超过后重新加载依赖

    while findMonsterEnabled and alive do
        if ABORT_IF_DISABLED() then break end
        -- 传送到Tideland
        AddLog("传送到Tideland...")
        local teleportSuccess, isNearTarget = TeleportToTideland()

        if not teleportSuccess then
            consecutiveFailures = consecutiveFailures + 1
            AddLog(string.format("传送失败 (%d/%d)，等待重试...", consecutiveFailures, maxConsecutiveFailures))
            
            -- 如果连续失败次数过多，重新获取所有依赖
            if consecutiveFailures >= maxConsecutiveFailures then
                AddLog("连续失败次数过多，重新获取所有依赖...")
                local reloadSuccess = ReloadAllDependencies()
                if reloadSuccess then
                    consecutiveFailures = 0  -- 重置失败计数
                    AddLog("依赖重新加载成功，继续尝试...")
                else
                    AddLog("依赖重新加载失败，切换服务器...")
                    DoServerHop()
                    task.wait(5)
                    consecutiveFailures = 0  -- 重置失败计数
                    -- 切换服务器后需要重新等待游戏加载
                    local gameLoaded, loadReason = WaitForGameFullyLoaded(120)
                    if not gameLoaded then
                        AddLog(string.format("切换服务器后加载失败: %s", loadReason))
                        task.wait(10)
                    else
                        AddLog("切换服务器后游戏已就绪")
                    end
                end
            else
                task.wait(3)
            end
            
            -- 直接跳到下一次循环，不继续执行后面的逻辑
            if not findMonsterEnabled or not alive then break end
            continue
        end
        
        -- 传送成功，重置失败计数
        consecutiveFailures = 0

        if not findMonsterEnabled or not alive then break end

        -- 如果已经跳过传送（已在目标位置），不需要等待
        if isNearTarget then
            AddLog("已在目标，直接开始检测")
        else
            task.wait(5)
        end

        if not findMonsterEnabled or not alive then break end

        -- 增加服务器访问计数
        findMonsterStats.serversVisited = findMonsterStats.serversVisited + 1
        UpdateFindMonsterStats()
        SaveFindMonsterConfig()

        -- 检测Monster
        AddLog("检测Monster...")
        local monster = nil
        local searchTimeout = 5  -- 5秒检测时间
        local searchStart = tick()

        while (tick() - searchStart) < searchTimeout and findMonsterEnabled and alive do
            monster = FindMonsterByTmplId(MONSTER_TMPL_ID)
            if monster then
                AddLog(string.format("发现Monster! MonsterId=%d", monster.MonsterId))
                break
            end
            task.wait(0.5)
        end

        if not findMonsterEnabled or not alive then break end

        if monster then
            findMonsterStats.monsterFound = findMonsterStats.monsterFound + 1
            UpdateFindMonsterStats()
            SaveFindMonsterConfig()

            -- 获取特殊属性（首次发现时等待 SpecialProp 复制，最多 5 秒，避免误报「普通」）
            local specialLabel = "普通"
            local hpInfo = nil
            if monster and monster.ServerNode then
                specialLabel = WaitForSpecialPropAndGetLabel(monster.ServerNode, 5, 0.15)
                hpInfo = GetMonsterHealthInfo(monster)
                AddLog(string.format("属性: %s", specialLabel))
            end

            -- 上报目标并 claim 当前服务器（合并为一次请求，优化速度）
            if LAN_SERVER_URL then
                local claimed, reason = ReportAndClaimTargetToLAN(game.JobId, {
                    special = specialLabel,
                    foundAt = tick(),
                    monsterId = monster.MonsterId
                })
                if claimed then
                    claimedTargetJobId = game.JobId
                    AddLog("[TARGET] Claimed this server")
                else
                    local r = tostring(reason or "")
                    if r == "already_claimed" then
                        AddLog("[TARGET] Found Monster but already claimed by others; hopping away")
                        DoServerHop(true)
                        return
                    else
                        -- request_failed 或连接错误等：留在当前服继续监控
                        AddLog("[TARGET] Found Monster but claim failed; staying (reason=" .. r .. ")")
                    end
                end
            end

            -- 设置Monster存在标记
            monsterActive = true

            -- 发送通知
            AddLog("发送通知...")
            spawn(function()
                if ABORT_IF_DISABLED() then return end
                SendDiscordNotification(
                    "🎉 发现 Monster!",
                    "在服务器中发现了 Monster，快来捕捉！",
                    65280,
                    specialLabel,
                    hpInfo
                )
            end)

            -- 监控Monster
            AddLog("开始监控Monster...")
            local lastNotificationTime = tick()
            local NOTIFICATION_INTERVAL = 60
            local notificationCount = 1
            local monitorStartTime = tick()
            local lastHpCurrent, lastHpMax, lastUnderAttackState = nil, nil, nil

            pcall(function()
                local hpInfo = GetMonsterHealthInfo(monster)
                lastHpCurrent = hpInfo.current
                lastHpMax = hpInfo.max
                lastUnderAttackState = hpInfo.isUnderAttack
            end)

            while findMonsterEnabled and alive do
                if ABORT_IF_DISABLED() then break end
                local currentMonster = FindMonsterByTmplId(MONSTER_TMPL_ID)
                if not currentMonster then
                    -- Monster消失了
                    AddLog("Monster已消失，准备切换服务器...")
                    if claimedTargetJobId then
                        ReleaseTargetToLAN(game.JobId, true)
                        AddLog("[TARGET] Released/resolved")
                        claimedTargetJobId = nil
                    end
                    spawn(SendDeleteNotification)
                    task.wait(1)
                    DoServerHop()
                    return
                end

                -- 检测状态
                local hpInfo = GetMonsterHealthInfo(currentMonster)
                local currentSpecial = GetMonsterSpecialLabelByServerNode(currentMonster.ServerNode)

                -- 只检测战斗状态变化，不检测血量变化
                local underAttackChanged = (lastUnderAttackState ~= hpInfo.isUnderAttack)

                -- 更新血量值用于显示（但不触发通知）
                lastHpCurrent = hpInfo.current
                lastHpMax = hpInfo.max

                -- 只在战斗状态变化时发送通知
                if underAttackChanged then
                    lastUnderAttackState = hpInfo.isUnderAttack

                    local statusText = hpInfo.isUnderAttack and "战斗中" or "未战斗"
                    AddLog(string.format("状态变化: %s", statusText))

                    spawn(function()
                        if ABORT_IF_DISABLED() then return end
                        SendDiscordNotification(
                            string.format("🔔 第%d次通知", notificationCount),
                            string.format("状态: %s", statusText),
                            65280,
                            currentSpecial,
                            hpInfo
                        )
                    end)
                end

                -- 更新状态
                local hpDisplay = hpInfo.current and hpInfo.max and
                    string.format("%.0f/%.0f", hpInfo.current, hpInfo.max) or "?"
                local statusText = string.format("Monster [%s] HP:%s #%d/%d",
                    currentSpecial, hpDisplay, notificationCount, MAX_MONSTER_NOTIFY)
                if hpInfo.isUnderAttack then
                    statusText = statusText .. " ⚔"
                end
                AddLog("监控: " .. statusText)

                -- 检查是否需要强制换服（15次通知）
                if notificationCount >= MAX_MONSTER_NOTIFY then
                    AddLog(string.format("通知已达 %d 次，强制换服", notificationCount))
                    if claimedTargetJobId then
                        ReleaseTargetToLAN(game.JobId, true)
                        AddLog("[TARGET] Released/resolved")
                        claimedTargetJobId = nil
                    end
                    spawn(SendDeleteNotification)
                    task.wait(0.5)
                    spawn(DoServerHop)
                    return
                end

                -- 定时发送通知
                if tick() - lastNotificationTime >= NOTIFICATION_INTERVAL then
                    notificationCount = notificationCount + 1
                    lastNotificationTime = tick()

                    local totalSeconds = math.floor(tick() - monitorStartTime)
                    local minutes = math.floor(totalSeconds / 60)
                    local seconds = totalSeconds % 60

                    AddLog(string.format("第%d次通知 (%d分%d秒)", notificationCount, minutes, seconds))

                    -- 只获取战斗状态，不获取血量信息
                    local battleStatus = false
                    pcall(function()
                        local hpInfo = GetMonsterHealthInfo(currentMonster)
                        battleStatus = hpInfo and hpInfo.isUnderAttack or false
                    end)

                    -- 只传递战斗状态，不传递血量信息
                    local statusOnlyHpInfo = { isUnderAttack = battleStatus }

                    spawn(function()
                        if ABORT_IF_DISABLED() then return end
                        SendDiscordNotification(
                            string.format("🔔 第%d次通知 - Monster 仍然存在!", notificationCount),
                            string.format("已监控 %d分%d秒", minutes, seconds),
                            65280,
                            currentSpecial,
                            statusOnlyHpInfo
                        )
                    end)
                end

                task.wait(1)
            end
        else
            AddLog("未发现Monster，切换服务器")
            task.wait(1)
            
            -- 多次尝试传送（总共最多10次）
            local maxTotalRetries = 10
            local retryCount = 0
            local allFailed = true
            
            while retryCount < maxTotalRetries and findMonsterEnabled and alive do
                retryCount = retryCount + 1
                AddLog(string.format("切换服务器 (%d/%d)", retryCount, maxTotalRetries))
                
                -- 先尝试局域网/API获取服务器
                local selectedServer = GetServerFromLAN()
                local hopSuccess = false
                
                if selectedServer then
                    hopSuccess = DoServerHop()
                else
                    -- 局域网获取失败，尝试随机传送
                    AddLog("局域网无服务器，尝试随机传送...")
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
                    break
                end
                
                -- 失败后等待，递增延迟
                local waitTime = math.min(5 + retryCount * 2, 30)  -- 从5秒开始，最长30秒
                AddLog(string.format("传送失败，等待%ds后重试...", waitTime))
                task.wait(waitTime)
            end
            
            if allFailed then
                AddLog(string.format("尝试%d次全部失败，休息1分钟后重试...", maxTotalRetries))
                task.wait(60)  -- 休息1分钟
            end
            
            return
        end
    end

    findMonsterRunning = false
    AddLog("循环已结束")
end

-- ============================================
-- 启动流程
-- ============================================
spawn(function()
    if ABORT_IF_DISABLED() then return end
    AddLog("正在加载PathTool...")

    local pathToolReady = WaitForPathTool(30)
    if not pathToolReady then
        AddLog("错误: PathTool加载超时")
        return
    end

    AddLog("PathTool加载成功")
    AddLog("等待游戏完全加载...")

    local gameLoaded, loadReason = WaitForGameFullyLoaded(120)

    if not gameLoaded then
        AddLog(string.format("加载失败: %s", loadReason))
        AddLog("尝试切换服务器...")
        DoServerHop()
        return
    end

    AddLog(string.format("游戏已就绪: %s", loadReason))

    -- 恢复配置
    local savedConfig = LoadFindMonsterConfig()
    if savedConfig and savedConfig.stats then
        findMonsterStats = savedConfig.stats
        UpdateFindMonsterStats()
        AddLog("已恢复配置")
    end

    -- 启动主循环前再次封禁检查与全局禁用守卫
    if ABORT_IF_DISABLED() then return end
    if HardBlockIfUserIsBanned("before_loop") then
        AddLog("当前用户不允许运行此脚本，主循环不启动")
        return
    end

    -- 启动主循环
    task.wait(2)
    if ABORT_IF_DISABLED() then return end
    spawn(FindMonsterLoop)
end)

AddLog("脚本已启动，等待加载...")
