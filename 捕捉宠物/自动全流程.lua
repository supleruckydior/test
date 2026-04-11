-- 自动全流程.lua
-- 完整自动升级流程:
-- 0. 从LAN服务器获取空服并跳转(一人一服)
-- 1. 兑换代码 → 2. 活动兑换(蛋换币+孵化药水+经验果实)
-- 3. 孵化蛋 → 4. 装备最强宠物 → 5. 喂食经验果实
-- 6. 飞到沙丘挂机到35级 → 7. 传送主城 → 8. 进塔推层
-- 9. 宠物死亡退塔 → 10. 领取塔奖励

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local TAG = "[自动全流程]"
task.wait(6)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local localPlayer = Players.LocalPlayer

-- ============================================================
-- Anti-AFK (自动防踢)
-- ============================================================
do
    local VirtualUser = game:GetService("VirtualUser")
    local UserInputService = game:GetService("UserInputService")

    local hasVirtualUser = pcall(function() return VirtualUser:CaptureController() end)
    local lastUserActivity = tick()
    local IDLE_THRESHOLD = 20

    local function randRange(a, b) return a + math.random() * (b - a) end
    local function hasUserActivity() return (tick() - lastUserActivity) < IDLE_THRESHOLD end

    pcall(function()
        UserInputService.InputBegan:Connect(function(input, gp)
            if not gp then lastUserActivity = tick() end
        end)
        UserInputService.InputChanged:Connect(function(input, gp)
            if not gp and input.UserInputType == Enum.UserInputType.MouseMovement then
                lastUserActivity = tick()
            end
        end)
    end)

    local function cameraNudge()
        pcall(function()
            local camera = workspace.CurrentCamera
            if not camera then return end
            local original = camera.CFrame
            local yaw = math.rad(randRange(-1.5, 1.5))
            local pitch = math.rad(randRange(-0.8, 0.8))
            local target = original * CFrame.Angles(pitch, yaw, 0)
            pcall(function()
                local tween = TweenService:Create(camera, TweenInfo.new(randRange(0.15, 0.3), Enum.EasingStyle.Sine), {CFrame = target})
                tween:Play()
                tween.Completed:Wait()
            end)
            task.wait(randRange(0.1, 0.2))
            pcall(function()
                TweenService:Create(camera, TweenInfo.new(randRange(0.15, 0.3), Enum.EasingStyle.Sine), {CFrame = original}):Play()
            end)
        end)
    end

    local function characterMovement()
        pcall(function()
            local character = localPlayer.Character
            if not character then return end
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                local dirs = {Vector3.new(1,0,0), Vector3.new(-1,0,0), Vector3.new(0,0,1), Vector3.new(0,0,-1)}
                humanoid:Move(dirs[math.random(1,4)], false)
                task.wait(randRange(0.05, 0.15))
                humanoid:Move(Vector3.new(0,0,0), false)
                if math.random() < 0.3 then pcall(function() humanoid.Jump = true end) end
            end
        end)
    end

    local function virtualAction()
        if not hasVirtualUser then return end
        pcall(function()
            local ok = pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new(0, 0))
            end)
            if not ok then
                pcall(function()
                    VirtualUser:Button2Down(Vector2.new(0, 0), workspace)
                    task.wait(0.05)
                    VirtualUser:Button2Up(Vector2.new(0, 0), workspace)
                end)
            end
        end)
    end

    local function performAction()
        if hasUserActivity() then return end
        pcall(function()
            local action = math.random(1, 3)
            if action == 1 then
                cameraNudge()
            elseif action == 2 then
                virtualAction()
            else
                characterMovement()
            end
        end)
    end

    pcall(function()
        localPlayer.Idled:Connect(function() task.spawn(performAction) end)
    end)
    pcall(function()
        localPlayer.CharacterAdded:Connect(function()
            task.wait(1)
            localPlayer.Idled:Connect(function() task.spawn(performAction) end)
        end)
    end)

    task.spawn(function()
        while task.wait(60) do
            if not hasUserActivity() then performAction() end
        end
    end)

    task.spawn(function()
        local lastAct = tick()
        local nextInt = 60 + randRange(-10, 10)
        RunService.Heartbeat:Connect(function()
            if hasUserActivity() then lastAct = tick(); return end
            if tick() - lastAct >= nextInt then
                lastAct = tick()
                nextInt = 60 + randRange(-10, 10)
                task.spawn(performAction)
            end
        end)
    end)

    print(string.format("%s [Anti-AFK] 已自动启用", TAG))
end

-- ============================================================
-- FPS Boost (性能优化) - 延迟到step07后调用
-- ============================================================
local _fpsBoostDone = false
local function runFpsBoost()
    if _fpsBoostDone then return end
    _fpsBoostDone = true
    local Lighting = game:GetService("Lighting")
    local MaterialService = game:GetService("MaterialService")

    local FPS_CFG = {
        FPS_CAP                 = 10,
        PROCESS_DELAY           = 0.05,
        BATCH_SIZE              = 2000,
        WATCH_NEW_DESCENDANTS   = false,
        DESTROY_DISABLED        = false,
        DESTROY_LIGHTS          = false,
        DESTROY_SOUNDS          = false,
        DESTROY_WORLD_GUI       = false,
        DESTROY_HIGHLIGHTS      = false,
        DESTROY_ADORNMENTS      = false,
        SIMPLIFY_SKY            = true,
        DISABLE_PROXIMITY       = false,
        RAM_GC_AFTER_PASS       = true,
        RAM_GC_PERIODIC         = true,
        RAM_GC_INTERVAL         = 120,
    }

    local fpsBoostErrorCount = 0

    local function safeCall(tag, fn)
        local ok, result = pcall(fn)
        if not ok then
            fpsBoostErrorCount = fpsBoostErrorCount + 1
        end
        return ok, result
    end

    local FPS_PARTICLE_CLASSES = {
        ParticleEmitter = true, Trail = true, Smoke = true, Fire = true, Sparkles = true,
    }

    local HOT_CLASSES = {
        SpecialMesh = true, Decal = true, Texture = true, ShirtGraphic = true, FaceInstance = true,
        ParticleEmitter = true, Trail = true, Smoke = true, Fire = true, Sparkles = true,
        PostEffect = true, Beam = true, MeshPart = true,
        PointLight = true, SpotLight = true, SurfaceLight = true,
        Highlight = true, SelectionBox = true,
    }

    local function shouldSkip(inst)
        if not inst then return true end
        if inst:IsDescendantOf(Players) then return true end
        if inst:IsDescendantOf(CoreGui) then return true end
        if inst:IsDescendantOf(PlayerGui) then return true end
        return not HOT_CLASSES[inst.ClassName]
    end

    local function optimizeInstance(inst)
        if shouldSkip(inst) then return end
        safeCall("FPS_OPT_" .. inst.ClassName, function()
            local cn = inst.ClassName
            if cn == "SpecialMesh" then inst.TextureId = ""; return end
            if cn == "Decal" or cn == "Texture" then
                inst.Transparency = 1; return
            end
            if cn == "ShirtGraphic" then
                inst.Graphic = ""; return
            end
            if cn == "FaceInstance" then
                inst.Transparency = 1; return
            end
            if FPS_PARTICLE_CLASSES[cn] then
                inst.Enabled = false; return
            end
            if cn == "PostEffect" then
                inst.Enabled = false; return
            end
            if cn == "Beam" then
                if inst.Enabled ~= nil then
                    inst.Enabled = false
                end
                return
            end
            if cn == "PointLight" or cn == "SpotLight" or cn == "SurfaceLight" then
                if inst.Enabled ~= nil then
                    inst.Enabled = false
                end
                return
            end
            if cn == "Highlight" or cn == "SelectionBox" then
                if inst.Enabled ~= nil then
                    inst.Enabled = false
                elseif inst.Visible ~= nil then
                    inst.Visible = false
                end
                return
            end
            if cn == "MeshPart" then
                inst.Reflectance = 0
                safeCall("FPS_MeshPart_RenderFidelity", function() inst.RenderFidelity = Enum.RenderFidelity.Performance end)
                return
            end
        end)
    end

    -- Global settings
    safeCall("FPS_Light_Setting", function()
        Lighting.GlobalShadows = false; Lighting.FogEnd = 9e9; Lighting.ShadowSoftness = 0
    end)
    safeCall("FPS_Terrain_Setting", function()
        local terrain = workspace:FindFirstChildOfClass("Terrain")
        if terrain then terrain.WaterWaveSize = 0; terrain.WaterWaveSpeed = 0; terrain.WaterReflectance = 0; terrain.WaterTransparency = 0 end
    end)
    safeCall("FPS_Sky_Setting", function()
        if FPS_CFG.SIMPLIFY_SKY then
            local sky = Lighting:FindFirstChildOfClass("Sky")
            if sky then sky.SkyboxBk = ""; sky.SkyboxDn = ""; sky.SkyboxFt = ""; sky.SkyboxLf = ""; sky.SkyboxRt = ""; sky.SkyboxUp = ""; sky.StarCount = 0 end
        end
    end)
    safeCall("FPS_Render_Setting", function()
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
        safeCall("FPS_Render_MeshPartDetailLevel", function() settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04 end)
    end)
    safeCall("FPS_Material_Reset", function()
        MaterialService.Use2022Materials = false
    end)
    safeCall("FPS_Cap", function()
        if setfpscap and type(FPS_CFG.FPS_CAP) == "number" and FPS_CFG.FPS_CAP > 0 then
            setfpscap(FPS_CFG.FPS_CAP)
            print(string.format("%s [FPS Boost] FPS cap set: %d", TAG, FPS_CFG.FPS_CAP))
        end
    end)

    -- Scan all descendants
    local descendants = game:GetDescendants()
    local batchSize = FPS_CFG.BATCH_SIZE > 0 and FPS_CFG.BATCH_SIZE or 400
    local descendantCount = #descendants
    for i = 1, descendantCount do
        optimizeInstance(descendants[i])
        if i % batchSize == 0 then task.wait() end
    end
    descendants = nil

    safeCall("FPS_RAM_GC_After", function()
        if FPS_CFG.RAM_GC_AFTER_PASS then collectgarbage("collect") end
    end)

    if FPS_CFG.RAM_GC_PERIODIC and FPS_CFG.RAM_GC_INTERVAL > 0 then
        task.spawn(function()
            while true do
                task.wait(FPS_CFG.RAM_GC_INTERVAL)
                safeCall("FPS_RAM_GC_Periodic", function() collectgarbage("collect") end)
            end
        end)
    end

    if FPS_CFG.WATCH_NEW_DESCENDANTS then
        if _G.__AUTOFLOW_FPS_DESC_CONN then
            pcall(function() _G.__AUTOFLOW_FPS_DESC_CONN:Disconnect() end)
            _G.__AUTOFLOW_FPS_DESC_CONN = nil
        end
        _G.__AUTOFLOW_FPS_DESC_CONN = game.DescendantAdded:Connect(function(inst)
            if HOT_CLASSES[inst.ClassName] then
                task.delay(FPS_CFG.PROCESS_DELAY, function() optimizeInstance(inst) end)
            end
        end)
    end

    print(string.format("%s [FPS Boost] 已完成, scanned=%d errors=%d", TAG, descendantCount, fpsBoostErrorCount))
end

-- ============================================================
-- 初始化 (WaitForPathTool 完整加载检测)
-- ============================================================
local PathTool, MgrPetClient, LogicNumber, GamePlayer

local function WaitForPathTool(maxWait)
    maxWait = maxWait or 30
    local waited = 0

    -- 方式1: 尝试直接 require PathTool
    if not PathTool then
        local success, result = pcall(function()
            return require(ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("PathTool"))
        end)
        if success and result then
            PathTool = result
            _G.PathTool = PathTool
        end
    end

    -- 方式2: 如果方式1失败，尝试使用全局变量
    if not PathTool and _G.PathTool then
        PathTool = _G.PathTool
    end

    -- 等待 PathTool 加载
    while not PathTool do
        task.wait(0.1)
        waited = waited + 0.1
        if waited >= maxWait then
            error(string.format("%s PathTool 系统未找到，请确保游戏已加载", TAG))
        end
        local success, result = pcall(function()
            return require(ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("PathTool"))
        end)
        if success and result then
            PathTool = result
            _G.PathTool = PathTool
        elseif _G.PathTool then
            PathTool = _G.PathTool
        end
    end

    -- 加载 MgrPetClient 模块
    if not MgrPetClient then
        pcall(function()
            if PathTool.Require then
                MgrPetClient = PathTool.Require("MgrPetClient")
            end
        end)
        if not MgrPetClient then
            pcall(function()
                MgrPetClient = require(ReplicatedStorage:WaitForChild("ClientLogic"):WaitForChild("Pet"):WaitForChild("MgrPetClient"))
            end)
        end
    end

    -- 加载 LogicNumber 模块
    if not LogicNumber then
        pcall(function()
            if PathTool.Require then
                LogicNumber = PathTool.Require("LogicNumber")
            end
        end)
    end

    -- 等待 MgrPetClient 加载完成
    waited = 0
    while not MgrPetClient do
        task.wait(0.1)
        waited = waited + 0.1
        if waited >= maxWait then
            warn(string.format("%s MgrPetClient 模块未找到，部分功能可能受影响", TAG))
            break
        end
        pcall(function()
            if PathTool.Require then
                MgrPetClient = PathTool.Require("MgrPetClient")
            end
        end)
        if not MgrPetClient then
            pcall(function()
                MgrPetClient = require(ReplicatedStorage:WaitForChild("ClientLogic"):WaitForChild("Pet"):WaitForChild("MgrPetClient"))
            end)
        end
    end

    -- 等待 GamePlayer
    waited = 0
    while not GamePlayer do
        local success, result = pcall(function()
            return PathTool.ClientPlayerManager.GetGamePlayer()
        end)
        if success and result then
            GamePlayer = result
            break
        end
        task.wait(0.5)
        waited = waited + 0.5
        if waited >= maxWait then
            warn(string.format("%s GamePlayer 未就绪，可能影响部分功能", TAG))
            break
        end
    end

    print(string.format("%s [WaitForPathTool] PathTool=%s MgrPetClient=%s LogicNumber=%s GamePlayer=%s",
        TAG,
        PathTool and "OK" or "FAIL",
        MgrPetClient and "OK" or "FAIL",
        LogicNumber and "OK" or "FAIL",
        GamePlayer and "OK" or "FAIL"
    ))
    return true
end

WaitForPathTool(30)

local ViewUtil = PathTool.ViewUtil
local dataPullFunc = ReplicatedStorage
    :WaitForChild("CommonLibrary")
    :WaitForChild("Tool")
    :WaitForChild("RemoteManager")
    :WaitForChild("Funcs")
    :WaitForChild("DataPullFunc")

local function getGamePlayer()
    -- 优先返回已缓存的 GamePlayer
    if GamePlayer then return GamePlayer end
    if PathTool.ClientPlayerManager and PathTool.ClientPlayerManager.GetGamePlayer then
        local ok, gp = pcall(function()
            return PathTool.ClientPlayerManager.GetGamePlayer()
        end)
        if ok and gp then
            GamePlayer = gp
            return gp
        end
    end
    return nil
end

-- ============================================================
-- 配置
-- ============================================================
local CFG = {
    -- LAN服务器 (一人一服)
    LAN_SERVER_URL = "http://192.168.31.247:8765",
    CLAIM_RETRY_DELAY = 2,
    CLAIM_MAX_ATTEMPTS = 10,

    -- 兑换代码
    CODES = {
        "bladetooth",
        "bunshroom",
        "berrybun",
        "shadecloak",
        "bunleaf",
        "eggbug",
        "doomgator",
        "primothorn",
        "abyssal",
        "frostiel",
        "fordelay",
        "dungeon",
        "dungeon2",
        "dungeon3",
    },

    -- 活动兑换
    ACTIVITY_ID = 15,
    EGG_TO_COIN_TMPL_ID = 19,  -- 蛋换币
    EGG_TO_COIN_COUNT = 2,
    HATCH_POTION_TMPL_ID = 7,  -- 孵化药水
    HATCH_POTION_COUNT = 8,
    EXP_FRUIT_TMPL_ID = 18,    -- 经验果实
    EXP_FRUIT_COUNT = 20,

    -- 孵化
    EGG_TMPL_IDS = { 43, 39 }, -- 复活节蛋 + 新蛋
    HATCH_SLOT = 1,
    MAX_HATCH_ROUNDS = 30,

    -- 喂食
    EXP_ITEM_TMPL_ID = 4,      -- PetExpItem #4 (100000 EXP Fruit)
    FEED_COUNT_PER_PET = 10,

    -- 沙丘挂机
    DUNE_POS = Vector3.new(808.03, -116.32, -3278.74),
    TARGET_LEVEL = 30,

    -- 塔
    MAX_TOWER_LAYERS = 200,

    -- 低帧率兼容 (10 FPS)
    LOW_FPS_MODE = true,
    LOW_FPS_FRAME_TIME = 0.10,
    TWEEN_TIMEOUT_PADDING = 1.2,
    TWEEN_VERIFY_RADIUS = 8,
    FLY_RETRY_COUNT = 2,
    FLY_VERIFY_RADIUS = 60,
    STEP07_SETTLE_WAIT = 5,
    JOB_CHANGE_TIMEOUT = 30,
    HATCH_SLOT_CLEAR_TIMEOUT = 30,
    PET_BAG_VERIFY_TIMEOUT = 30,
    EQUIP_VERIFY_TIMEOUT = 15,
    EQUIP_STABLE_WINDOW = 0.75,
    CODE_REDEEM_INTERVAL = 0.1,
    CODE_SETTLE_WAIT = 1.0,
    ACTIVITY_VERIFY_TIMEOUT = 30,
    FEED_ITEM_WAIT_TIMEOUT = 30,
    FEED_VERIFY_TIMEOUT = 30,
    STEP_LOCK_RETRY_DELAY = 4,
    LV8_REEQUIP_TARGET_COUNT = 3,
    LV8_REEQUIP_TIMEOUT = 30,
    NEARBY_PLAYER_RADIUS = 100,
    NEARBY_PLAYER_SWITCH_DELAY = 60,
    PET_DEAD_RECOVER_TIMEOUT = 90,
    RECOVER_POINT_REACH_RADIUS = 18,
    RETURN_TO_FARM_REACH_RADIUS = 70,
    WALK_WAYPOINT_SPACING = 14,
    WALK_WAYPOINT_REACH_RADIUS = 6,
    WALK_MOVE_REFRESH = 0.12,
}

-- ============================================================
-- 进度保存与恢复 (一号一文件, 防掉线)
-- ============================================================
local function getProgressFile()
    return "autoflow_" .. tostring(localPlayer.UserId) .. ".json"
end

local function saveProgress(stepIndex, extra)
    local ok, err = pcall(function()
        local data = {
            step = stepIndex,
            ts = os.time(),
            userId = localPlayer.UserId,
            extra = extra or {},
        }
        writefile(getProgressFile(), HttpService:JSONEncode(data))
    end)
    if not ok then
        warn(string.format("%s 保存进度失败: %s", TAG, tostring(err)))
    end
end

local function loadProgress()
    local ok, result = pcall(function()
        local path = getProgressFile()
        if not isfile(path) then return nil end
        local raw = readfile(path)
        if not raw or raw == "" then return nil end
        local data = HttpService:JSONDecode(raw)
        if type(data) ~= "table" then return nil end
        if data.step == "done" then return nil end -- 上次已完成
        if type(data.step) ~= "number" then return nil end
        return data
    end)
    if ok then return result end
    return nil
end

local function clearProgress()
    pcall(function()
        writefile(getProgressFile(), HttpService:JSONEncode({
            step = "done",
            ts = os.time(),
            userId = localPlayer.UserId,
        }))
    end)
end

-- ============================================================
-- 通用工具 (低帧率兼容)
-- ============================================================
local function frameSafeWait(seconds)
    local remain = math.max(tonumber(seconds) or 0, 0)
    if remain <= 0 then
        task.wait()
        return
    end
    local step = CFG.LOW_FPS_MODE and CFG.LOW_FPS_FRAME_TIME or 0.05
    while remain > 0 do
        local chunk = math.min(step, remain)
        task.wait(chunk)
        remain = remain - chunk
    end
end

local function getCharacterAndRootPart()
    local character = localPlayer and localPlayer.Character
    if not character or not character.Parent then
        return nil, nil
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp.Parent then
        return character, nil
    end
    return character, hrp
end

local function waitForCharacterReady(timeout)
    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    repeat
        local character, hrp = getCharacterAndRootPart()
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if hrp and humanoid and humanoid.Health > 0 then
            return true, character, hrp
        end
        frameSafeWait(CFG.LOW_FPS_FRAME_TIME)
    until tick() >= deadline
    return false, nil, nil
end

local function waitForInitialGameReady(timeout)
    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    repeat
        local gameLoaded = false
        local playerReady = false
        pcall(function()
            gameLoaded = game:IsLoaded()
        end)
        playerReady = localPlayer ~= nil and localPlayer.Parent ~= nil
        if gameLoaded and playerReady then
            local charReady = waitForCharacterReady(1.5)
            if charReady then
                return true
            end
        end
        frameSafeWait(0.25)
    until tick() >= deadline
    return false
end

local function getDistanceToPosition(targetPos)
    local _, hrp = getCharacterAndRootPart()
    if not hrp then
        return math.huge
    end
    return (hrp.Position - targetPos).Magnitude
end

local function snapCharacterToPosition(targetPos)
    local _, hrp = getCharacterAndRootPart()
    if not hrp then
        return false
    end
    local keepRotation = hrp.CFrame - hrp.CFrame.Position
    local ok = pcall(function()
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        hrp.CFrame = CFrame.new(targetPos) * keepRotation
    end)
    return ok
end

local function waitForTweenWithTimeout(tween, timeout)
    local finished = false
    local conn = tween.Completed:Connect(function()
        finished = true
    end)

    tween:Play()

    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    while not finished and tick() < deadline do
        frameSafeWait(CFG.LOW_FPS_FRAME_TIME)
    end

    if conn then
        conn:Disconnect()
    end

    if not finished then
        pcall(function()
            tween:Cancel()
        end)
    end

    return finished
end

local function setAutoAttackEnabled(enabled)
    if not (PathTool and PathTool.SettingSystem and PathTool.SettingSystem.ClientSetOnOff) then
        return false
    end
    local ok, result = pcall(function()
        return ViewUtil.DoRequest(PathTool.SettingSystem.ClientSetOnOff, "AutoAttack", enabled == true)
    end)
    return ok and result ~= false
end

local function setCharacterAnchored(isAnchored)
    local _, hrp = getCharacterAndRootPart()
    if not hrp then
        return false
    end
    local ok = pcall(function()
        hrp.Anchored = isAnchored == true
    end)
    return ok
end

local function waitForJobIdChange(oldJobId, timeout)
    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    repeat
        if game.JobId ~= oldJobId then
            return true
        end
        frameSafeWait(0.25)
    until tick() >= deadline
    return false
end

local function doGameRequest(requestFn, ...)
    if not requestFn then
        return false, "missing_request"
    end
    local args = table.pack(...)
    local ok, result = pcall(function()
        return ViewUtil.DoRequest(requestFn, table.unpack(args, 1, args.n))
    end)
    if not ok then
        return false, tostring(result)
    end
    if result == false then
        return false, "request_returned_false"
    end
    return true, result
end

local function getCommonItemAmount(itemTmplId)
    local gp = getGamePlayer()
    if not gp or not gp.commonItem or not gp.commonItem.GetItemAmount then
        return 0
    end
    local amount = 0
    pcall(function()
        amount = tonumber(tostring(gp.commonItem:GetItemAmount(itemTmplId))) or 0
    end)
    return amount
end

local function waitForCommonItemAmountAtLeast(itemTmplId, minAmount, timeout)
    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    repeat
        local amount = getCommonItemAmount(itemTmplId)
        if amount >= minAmount then
            return true, amount
        end
        frameSafeWait(0.25)
    until tick() >= deadline
    local amount = getCommonItemAmount(itemTmplId)
    return amount >= minAmount, amount
end

local function waitForCommonItemAmountAtMost(itemTmplId, maxAmount, timeout)
    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    repeat
        local amount = getCommonItemAmount(itemTmplId)
        if amount <= maxAmount then
            return true, amount
        end
        frameSafeWait(0.25)
    until tick() >= deadline
    local amount = getCommonItemAmount(itemTmplId)
    return amount <= maxAmount, amount
end

local function getPetExpItemCount(itemTmplId)
    local gp = getGamePlayer()
    if not gp or not gp.pet or not gp.pet.GetExpItemCount then
        return 0
    end
    local amount = 0
    pcall(function()
        amount = tonumber(tostring(gp.pet:GetExpItemCount(itemTmplId))) or 0
    end)
    return amount
end

local function waitForPetExpItemCountAtLeast(itemTmplId, minAmount, timeout)
    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    repeat
        local amount = getPetExpItemCount(itemTmplId)
        if amount >= minAmount then
            return true, amount
        end
        frameSafeWait(0.25)
    until tick() >= deadline
    local amount = getPetExpItemCount(itemTmplId)
    return amount >= minAmount, amount
end

local function waitForPetExpItemCountAtMost(itemTmplId, maxAmount, timeout)
    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    repeat
        local amount = getPetExpItemCount(itemTmplId)
        if amount <= maxAmount then
            return true, amount
        end
        frameSafeWait(0.25)
    until tick() >= deadline
    local amount = getPetExpItemCount(itemTmplId)
    return amount <= maxAmount, amount
end

local function getPetBagAmount()
    local gp = getGamePlayer()
    if not gp or not gp.pet or not gp.pet.GetBagAmount then
        return 0
    end
    local amount = 0
    pcall(function()
        amount = tonumber(tostring(gp.pet:GetBagAmount())) or 0
    end)
    return amount
end

local function waitForPetBagAmount(minAmount, timeout)
    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    repeat
        local amount = getPetBagAmount()
        if amount >= minAmount then
            return true, amount
        end
        frameSafeWait(0.25)
    until tick() >= deadline
    local amount = getPetBagAmount()
    return amount >= minAmount, amount
end

local function getActivityShopSelledCount(activityId, tmplId)
    local gp = getGamePlayer()
    if not gp or not gp.activity or not gp.activity.ActivityShopGetSelledCount then
        return 0
    end
    local count = 0
    pcall(function()
        count = tonumber(tostring(gp.activity:ActivityShopGetSelledCount(activityId, tmplId))) or 0
    end)
    return count
end

local function waitForActivityShopSelledCount(activityId, tmplId, minAmount, timeout)
    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    repeat
        local count = getActivityShopSelledCount(activityId, tmplId)
        if count >= minAmount then
            return true, count
        end
        frameSafeWait(0.25)
    until tick() >= deadline
    local count = getActivityShopSelledCount(activityId, tmplId)
    return count >= minAmount, count
end

local function getAchieveDataCount(dataId)
    local gp = getGamePlayer()
    if not gp or not gp.achieve or not PathTool.AchieveUtil or not PathTool.AchieveUtil.GetDataCount then
        return 0
    end
    local count = 0
    pcall(function()
        count = tonumber(tostring(PathTool.AchieveUtil.GetDataCount(gp, dataId))) or 0
    end)
    return count
end

local function getAchieveLabel(cfg, fallback)
    if not cfg then
        return fallback
    end
    local fieldNames = { "Name", "Title", "AchieveName", "Desc", "Description" }
    for _, fieldName in ipairs(fieldNames) do
        local value = cfg[fieldName]
        if value ~= nil and tostring(value) ~= "" then
            return tostring(value)
        end
    end
    return fallback
end

local function scanClaimableAchieveRewards()
    local gp = getGamePlayer()
    if not gp or not gp.achieve or not PathTool.CfgAchieve then
        return {}, {}
    end

    local claimableItems = {}
    local groupStats = {}
    local tmpls = PathTool.CfgAchieve.Tmpls or {}

    for tmplId, cfg in pairs(tmpls) do
        local groupId = cfg.GroupId
        local stat = groupStats[groupId]
        if not stat then
            stat = { amount = 0, complete = 0 }
            groupStats[groupId] = stat
        end
        stat.amount = stat.amount + 1

        local taken = false
        pcall(function()
            taken = gp.achieve:IsRewardTaken(tmplId)
        end)

        local count = getAchieveDataCount(cfg.DataId)
        local need = cfg.Count or 0
        local complete = count >= need

        if taken or complete then
            stat.complete = stat.complete + 1
        end

        if (not taken) and complete and (cfg.Reward ~= nil or cfg.PlayerProperty ~= nil) then
            table.insert(claimableItems, {
                tmplId = tmplId,
                groupId = groupId,
                label = getAchieveLabel(cfg, string.format("成就#%s", tostring(tmplId))),
                count = count,
                need = need,
            })
        end
    end

    table.sort(claimableItems, function(a, b)
        if a.groupId ~= b.groupId then
            return a.groupId < b.groupId
        end
        return a.tmplId < b.tmplId
    end)

    local claimableGroups = {}
    local groups = PathTool.CfgAchieve.Groups or {}
    for groupId, cfg in pairs(groups) do
        local stat = groupStats[groupId]
        local amount = stat and stat.amount or 0
        local complete = stat and stat.complete or 0
        local groupTaken = false
        pcall(function()
            groupTaken = gp.achieve:IsGroupRewardTaken(groupId)
        end)

        if (not groupTaken)
            and amount > 0
            and complete >= amount
            and (cfg.Reward ~= nil or cfg.PlayerProperty ~= nil)
        then
            table.insert(claimableGroups, {
                groupId = groupId,
                label = getAchieveLabel(cfg, string.format("成就组#%s", tostring(groupId))),
                amount = amount,
                complete = complete,
            })
        end
    end

    table.sort(claimableGroups, function(a, b)
        return a.groupId < b.groupId
    end)

    return claimableItems, claimableGroups
end

local function claimAchieveRewards()
    if not PathTool.AchieveSystem or not PathTool.AchieveSystem.ClientTakeAchieveReward then
        print(string.format("%s  成就奖励接口不可用，跳过", TAG))
        return true
    end

    local claimableItems, claimableGroups = scanClaimableAchieveRewards()
    print(string.format("%s  成就奖励扫描: 个人=%d, 组=%d", TAG, #claimableItems, #claimableGroups))

    local itemSuccess = 0
    local groupSuccess = 0

    for _, item in ipairs(claimableItems) do
        local ok, result = doGameRequest(
            PathTool.AchieveSystem.ClientTakeAchieveReward,
            item.groupId,
            item.tmplId
        )
        if ok then
            itemSuccess = itemSuccess + 1
            print(string.format("%s  ✓ 领取成就成功: group=%s tmpl=%s %s",
                TAG,
                tostring(item.groupId),
                tostring(item.tmplId),
                tostring(item.label)
            ))
        else
            warn(string.format("%s  ✗ 领取成就失败: group=%s tmpl=%s %s -> %s",
                TAG,
                tostring(item.groupId),
                tostring(item.tmplId),
                tostring(item.label),
                tostring(result)
            ))
        end
        frameSafeWait(0.2)
    end

    for _, group in ipairs(claimableGroups) do
        local ok, result = doGameRequest(
            PathTool.AchieveSystem.ClientTakeAchieveReward,
            group.groupId,
            0
        )
        if ok then
            groupSuccess = groupSuccess + 1
            print(string.format("%s  ✓ 领取成就组奖励成功: group=%s %s",
                TAG,
                tostring(group.groupId),
                tostring(group.label)
            ))
        else
            warn(string.format("%s  ✗ 领取成就组奖励失败: group=%s %s -> %s",
                TAG,
                tostring(group.groupId),
                tostring(group.label),
                tostring(result)
            ))
        end
        frameSafeWait(0.2)
    end

    print(string.format("%s  成就奖励结果: 个人 %d/%d, 组 %d/%d",
        TAG,
        itemSuccess,
        #claimableItems,
        groupSuccess,
        #claimableGroups
    ))
    return true
end

local function getEggAmountByTmplId(eggTmplId)
    local gp = getGamePlayer()
    if not gp or not gp.egg or not gp.egg.GetEggAmount then
        return 0
    end
    local amount = 0
    pcall(function()
        amount = tonumber(tostring(gp.egg:GetEggAmount(eggTmplId))) or 0
    end)
    return amount
end

local function getTotalConfiguredEggAmount()
    local total = 0
    for _, eggTmplId in ipairs(CFG.EGG_TMPL_IDS or {}) do
        total = total + getEggAmountByTmplId(eggTmplId)
    end
    return total
end

local function getHatchSlotEggTmplId(slot)
    local gp = getGamePlayer()
    if not gp or not gp.egg or not gp.egg.GetHatchEggTmplId then
        return 0
    end
    local eggTmplId = 0
    pcall(function()
        eggTmplId = tonumber(tostring(gp.egg:GetHatchEggTmplId(slot))) or 0
    end)
    return eggTmplId
end

local function getHatchSlotStartTick(slot)
    local gp = getGamePlayer()
    if not gp or not gp.egg or not gp.egg.GetHatchEggStartTick then
        return nil
    end
    local startTick = nil
    pcall(function()
        startTick = tonumber(tostring(gp.egg:GetHatchEggStartTick(slot)))
    end)
    return startTick
end

local function getServerTimeNow()
    if PathTool and PathTool.Utils and PathTool.Utils.GetServerTime then
        local ok, value = pcall(function()
            return PathTool.Utils.GetServerTime()
        end)
        if ok then
            return tonumber(tostring(value)) or 0
        end
    end
    return os.time()
end

local function getEggHatchDuration(eggTmplId)
    local hatchTime = nil
    pcall(function()
        if PathTool and PathTool.CfgEgg and PathTool.CfgEgg.Tmpls and PathTool.CfgEgg.Tmpls[eggTmplId] then
            hatchTime = tonumber(tostring(PathTool.CfgEgg.Tmpls[eggTmplId].HatchTime))
        end
    end)
    return hatchTime
end

local function getHatchSlotRemainingTime(slot)
    local eggTmplId = getHatchSlotEggTmplId(slot)
    if not eggTmplId or eggTmplId == 0 then
        return nil, nil, nil
    end
    local startTick = getHatchSlotStartTick(slot)
    local hatchTime = getEggHatchDuration(eggTmplId)
    if not startTick or not hatchTime then
        return nil, eggTmplId, startTick
    end
    local remaining = math.max((startTick + hatchTime) - getServerTimeNow(), 0)
    return remaining, eggTmplId, startTick
end

local function waitForHatchSlotClear(slot, timeout)
    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    repeat
        if getHatchSlotEggTmplId(slot) == 0 then
            return true
        end
        frameSafeWait(0.25)
    until tick() >= deadline
    return getHatchSlotEggTmplId(slot) == 0
end

local function getEquippedPetIds()
    local gp = getGamePlayer()
    if not gp or not gp.pet or not gp.pet.IterEquipedItem then
        return {}
    end

    local pets = {}
    pcall(function()
        gp.pet:IterEquipedItem(function(petItem)
            if petItem and petItem.itemId then
                table.insert(pets, petItem.itemId)
            end
            return true
        end)
    end)
    return pets
end

local function getPetIdListKey(pets)
    local keys = {}
    for _, petId in ipairs(pets or {}) do
        table.insert(keys, tostring(petId))
    end
    table.sort(keys)
    return table.concat(keys, ",")
end

local function waitForEquippedPets(timeout)
    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    repeat
        local pets = getEquippedPetIds()
        if #pets > 0 then
            return true, pets
        end
        frameSafeWait(0.25)
    until tick() >= deadline
    local pets = getEquippedPetIds()
    return #pets > 0, pets
end

local function waitForEquippedPetsStable(timeout, stableWindow)
    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    local stableSince = nil
    local lastKey = nil
    local lastPets = {}
    repeat
        local pets = getEquippedPetIds()
        local key = getPetIdListKey(pets)
        if #pets > 0 then
            if key ~= lastKey then
                lastKey = key
                lastPets = pets
                stableSince = tick()
            elseif stableSince and tick() - stableSince >= stableWindow then
                return true, pets
            end
        else
            lastKey = nil
            stableSince = nil
            lastPets = pets
        end
        frameSafeWait(0.25)
    until tick() >= deadline
    return #lastPets > 0, lastPets
end

local function waitForExactEquippedPetCount(targetCount, timeout)
    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    repeat
        local pets = getEquippedPetIds()
        if #pets == targetCount then
            return true, pets
        end
        frameSafeWait(0.25)
    until tick() >= deadline
    local pets = getEquippedPetIds()
    return #pets == targetCount, pets
end

local function getNearbyPlayerInRadius(radius)
    local _, myHrp = getCharacterAndRootPart()
    if not myHrp then
        return nil, nil
    end
    local closestPlayer = nil
    local closestDist = nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local character = player.Character
            local otherHrp = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if otherHrp and humanoid and humanoid.Health > 0 then
                local dist = (otherHrp.Position - myHrp.Position).Magnitude
                if dist <= radius and (closestDist == nil or dist < closestDist) then
                    closestPlayer = player
                    closestDist = dist
                end
            end
        end
    end
    return closestPlayer, closestDist
end

-- ============================================================
-- LAN服务器工具函数
-- ============================================================
local function urlEncode(value)
    return HttpService:UrlEncode(tostring(value or ""))
end

local function httpGetJson(pathWithQuery)
    if not CFG.LAN_SERVER_URL then
        return false, nil
    end
    local url = pathWithQuery:find("^https?://") and pathWithQuery or (CFG.LAN_SERVER_URL .. pathWithQuery)
    local ok, decoded = pcall(function()
        local body = game:HttpGet(url)
        if body then
            return HttpService:JSONDecode(body)
        end
        return nil
    end)
    if not ok then
        warn(string.format("%s  [HTTP] 请求失败: %s | 错误: %s", TAG, url, tostring(decoded)))
    end
    return ok, decoded
end

local function shortJobId(jobId)
    if type(jobId) ~= "string" then return tostring(jobId) end
    if #jobId <= 8 then return jobId end
    return string.sub(jobId, 1, 8) .. "..."
end

local function getServerFromLAN()
    local ok, decoded = httpGetJson("/server")
    if ok and decoded and decoded.success and decoded.server and decoded.server.id then
        return decoded.server, nil
    end
    local errMsg = (type(decoded) == "table" and decoded.error) or (type(decoded) == "string" and decoded) or "no_valid_server"
    return nil, errMsg
end

local function reportAndClaimToLAN(jobId)
    local path = "/target/report_and_claim?job_id=" .. urlEncode(jobId)
        .. "&reporter=" .. urlEncode(tostring(localPlayer.UserId))
        .. "&mode=" .. urlEncode("auto_full")
        .. "&meta=" .. urlEncode(HttpService:JSONEncode({ mode = "auto_full", at = tick() }))
    local ok, decoded = httpGetJson(path)
    if ok and decoded and decoded.claimed == true then
        return true, nil
    end
    local reason = (type(decoded) == "table" and decoded.reason) or (type(decoded) == "string" and decoded) or "request_failed"
    return false, reason
end

local function releaseToLAN(jobId, resolved)
    local path = "/target/release?job_id=" .. urlEncode(jobId)
        .. "&claimer=" .. urlEncode(tostring(localPlayer.UserId))
        .. "&resolved=" .. urlEncode(resolved and "1" or "0")
        .. "&mode=" .. urlEncode("auto_full")
    local ok, decoded = httpGetJson(path)
    if ok and decoded and decoded.success == true and decoded.released == true then
        return true
    end
    return false
end

-- ============================================================
-- Claim 心跳 (防止 CLAIM_TTL=180s 超时被释放)
-- ============================================================
local HEARTBEAT_INTERVAL = 60 -- 每60秒续期一次 (TTL=180s, 留足余量)
local _heartbeatConn = nil
local _heartbeatActive = false

local function startClaimHeartbeat()
    if not CFG.LAN_SERVER_URL then return end
    _heartbeatActive = true
    local lastBeat = tick()
    _heartbeatConn = RunService.Heartbeat:Connect(function()
        if not _heartbeatActive then return end
        if tick() - lastBeat < HEARTBEAT_INTERVAL then return end
        lastBeat = tick()
        pcall(function()
            local claimed, reason = reportAndClaimToLAN(game.JobId)
            if claimed then
                print(string.format("%s  [心跳] claim续期成功 %s", TAG, shortJobId(game.JobId)))
            else
                warn(string.format("%s  [心跳] claim续期失败: %s", TAG, tostring(reason)))
            end
        end)
    end)
    print(string.format("%s  ✓ 心跳已启动 (每%ds续期)", TAG, HEARTBEAT_INTERVAL))
end

local function stopClaimHeartbeat()
    _heartbeatActive = false
    if _heartbeatConn then
        _heartbeatConn:Disconnect()
        _heartbeatConn = nil
        print(string.format("%s  心跳已停止", TAG))
    end
end

local function teleportToJob(jobId)
    if type(jobId) ~= "string" or jobId == "" then return false end
    print(string.format("%s  传送到服务器: %s", TAG, shortJobId(jobId)))
    local oldJobId = game.JobId
    setCharacterAnchored(true)
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, localPlayer)
    end)
    if not ok then
        warn(string.format("%s  传送失败: %s", TAG, tostring(err)))
        setCharacterAnchored(false)
        return false
    end
    local changed = waitForJobIdChange(oldJobId, CFG.JOB_CHANGE_TIMEOUT)
    if not changed then
        warn(string.format("%s  传送超时，%ds 内未切服", TAG, CFG.JOB_CHANGE_TIMEOUT))
        setCharacterAnchored(false)
        return false
    end
    return true
end

local function ensureCurrentServerClaimedForResume()
    if not CFG.LAN_SERVER_URL then
        return true
    end
    print(string.format("%s  恢复前重新claim当前服务器: %s", TAG, shortJobId(game.JobId)))
    local claimed, reason = reportAndClaimToLAN(game.JobId)
    if not claimed then
        warn(string.format("%s  恢复claim失败: %s", TAG, tostring(reason)))
        return false, tostring(reason or "resume_claim_failed")
    end
    startClaimHeartbeat()
    print(string.format("%s  ✓ 恢复claim成功 %s", TAG, shortJobId(game.JobId)))
    return true
end

local function switchServerForNearbyPlayer()
    if not CFG.LAN_SERVER_URL then
        return false, "lan_not_configured"
    end
    local oldJobId = game.JobId
    stopClaimHeartbeat()
    pcall(function()
        releaseToLAN(oldJobId, false)
    end)

    local attempt = 0
    while true do
        attempt = attempt + 1
        local server, err = getServerFromLAN()
        if server and server.id and server.id ~= oldJobId then
            print(string.format("%s  [避让玩家 第%d次] 获取到空服: %s，正在传送...", TAG, attempt, shortJobId(server.id)))
            local tpOk = teleportToJob(server.id)
            if tpOk then
                return true
            end
            warn(string.format("%s  [避让玩家 第%d次] 传送失败，%ds后重试", TAG, attempt, CFG.CLAIM_RETRY_DELAY))
        else
            warn(string.format("%s  [避让玩家 第%d次] 获取空服失败: %s，%ds后重试", TAG, attempt, tostring(err), CFG.CLAIM_RETRY_DELAY))
        end
        frameSafeWait(CFG.CLAIM_RETRY_DELAY)
    end
end

-- ============================================================
-- 步骤0: 一人一服 (从LAN服务器获取空服并claim)
-- ============================================================
local function step00_claimServer()
    print(string.format("\n%s ========== 步骤0: 一人一服 ==========", TAG))
    if not CFG.LAN_SERVER_URL then
        print(TAG, "  未配置LAN服务器，跳过")
        return true
    end

    print(string.format("%s  LAN服务器地址: %s", TAG, CFG.LAN_SERVER_URL))
    print(string.format("%s  当前JobId: %s, UserId: %s", TAG, shortJobId(game.JobId), tostring(localPlayer.UserId)))

    -- 先测试LAN服务器是否可达
    local testOk, testResult = httpGetJson("/status")
    if testOk and type(testResult) == "table" then
        print(string.format("%s  ✓ LAN服务器连接正常, 服务器池: %s", TAG, tostring(testResult.total or "?")))
    else
        warn(string.format("%s  ✗ LAN服务器不可达! 请确认 %s 是否在运行", TAG, CFG.LAN_SERVER_URL))
        return false, "lan_unreachable"
    end

    -- 先尝试claim当前服务器
    local claimed, reason = reportAndClaimToLAN(game.JobId)
    if claimed then
        print(string.format("%s  ✓ 成功claim当前服务器 %s", TAG, shortJobId(game.JobId)))
        startClaimHeartbeat()
        return true
    end

    print(string.format("%s  当前服务器claim失败: %s，开始获取新服务器...", TAG, tostring(reason)))

    -- 无限重试获取新服务器，直至成功传送
    local attempt = 0
    while true do
        attempt = attempt + 1
        local server, err = getServerFromLAN()
        if server and server.id and server.id ~= game.JobId then
            print(string.format("%s  [第%d次] 获取到空服: %s，正在传送...", TAG, attempt, shortJobId(server.id)))
            local tpOk = teleportToJob(server.id)
            if tpOk then
                return true
            else
                warn(string.format("%s  [第%d次] 传送失败，%ds后重试", TAG, attempt, CFG.CLAIM_RETRY_DELAY))
            end
        else
            warn(string.format("%s  [第%d次] 获取空服失败: %s，%ds后重试", TAG, attempt, tostring(err), CFG.CLAIM_RETRY_DELAY))
        end
        frameSafeWait(CFG.CLAIM_RETRY_DELAY)
    end
end

-- ============================================================
-- 步骤0.5: 扩大自动捕捉范围 + 减少延迟
-- ============================================================
local AUTO_CATCH_RANGE_MULTIPLIER = 10
local PET_MOVE_SPEED_MULTIPLIER = 3
local PET_BACK_TO_PLAYER_SPEED = 200

local function boostPetMoveSpeed()
    if not PathTool.CfgPet or not PathTool.CfgPet.Tmpls then
        warn(string.format("%s  ⚠ CfgPet.Tmpls 未找到", TAG))
        return
    end

    local changedCount = 0
    for _, petCfg in pairs(PathTool.CfgPet.Tmpls) do
        if petCfg and petCfg.MoveConfig and type(petCfg.MoveConfig.MoveSpeed) == "number" then
            if not petCfg.__codexOriginalMoveSpeed then
                petCfg.__codexOriginalMoveSpeed = petCfg.MoveConfig.MoveSpeed
            end
            petCfg.MoveConfig.MoveSpeed = petCfg.__codexOriginalMoveSpeed * PET_MOVE_SPEED_MULTIPLIER
            changedCount = changedCount + 1
        end
    end

    print(string.format("%s  ✓ 宠物追怪速度已提升: x%.1f (影响 %d 个宠物模板)",
        TAG, PET_MOVE_SPEED_MULTIPLIER, changedCount))
end

local function step00b_boostAutoCatch()
    print(string.format("\n%s ========== 步骤0.5: 优化自动捕捉参数 ==========", TAG))

    -- 扩大搜索范围
    if PathTool.CfgAutoAttack then
        local cfg = PathTool.CfgAutoAttack
        if cfg.SearchRange then
            local orig = cfg.SearchRange
            cfg.SearchRange = orig * AUTO_CATCH_RANGE_MULTIPLIER
            print(string.format("%s  ✓ 捕捉范围: %s -> %s (%.0fx)", TAG, tostring(orig), tostring(cfg.SearchRange), AUTO_CATCH_RANGE_MULTIPLIER))
        end
        if cfg.SearchIntervalTime then
            local orig = cfg.SearchIntervalTime
            cfg.SearchIntervalTime = orig * 0.1
            print(string.format("%s  ✓ 搜索间隔: %s -> %s (-90%%)", TAG, tostring(orig), tostring(cfg.SearchIntervalTime)))
        end
        if cfg.DelayAutoCatch then
            local orig = cfg.DelayAutoCatch
            cfg.DelayAutoCatch = orig * 0.1
            print(string.format("%s  ✓ 捕捉延迟: %s -> %s (-90%%)", TAG, tostring(orig), tostring(cfg.DelayAutoCatch)))
        end
        if cfg.DelayAutoPickUp then
            local orig = cfg.DelayAutoPickUp
            cfg.DelayAutoPickUp = orig * 0.1
            print(string.format("%s  ✓ 拾取延迟: %s -> %s (-90%%)", TAG, tostring(orig), tostring(cfg.DelayAutoPickUp)))
        end
        if cfg.FirstSearchDelay then
            local orig = cfg.FirstSearchDelay
            cfg.FirstSearchDelay = orig * 0.1
            print(string.format("%s  ✓ 首次搜索延迟: %s -> %s (-90%%)", TAG, tostring(orig), tostring(cfg.FirstSearchDelay)))
        end
    else
        warn(string.format("%s  ⚠ CfgAutoAttack 未找到", TAG))
    end

    -- 宠物回玉家速度
    if PathTool.CfgPet and PathTool.CfgPet.PetBackToPlayerSpeedUp then
        local orig = PathTool.CfgPet.PetBackToPlayerSpeedUp
        PathTool.CfgPet.PetBackToPlayerSpeedUp = PET_BACK_TO_PLAYER_SPEED
        print(string.format("%s  ✓ 宠物回玉家速度: %s -> %s", TAG, tostring(orig), tostring(PET_BACK_TO_PLAYER_SPEED)))
    else
        warn(string.format("%s  ⚠ CfgPet.PetBackToPlayerSpeedUp 未找到", TAG))
    end

    boostPetMoveSpeed()
    return true
end

-- ============================================================
-- 步骤1: 兑换代码
-- ============================================================
local function step01_redeemCodes()
    print(string.format("\n%s ========== 步骤1: 兑换代码 ==========", TAG))
    local successCount = 0
    local failedCount = 0
    for _, code in ipairs(CFG.CODES) do
        local ok, result = doGameRequest(PathTool.GiftSystem.ClientGetGift, code)
        if ok then
            print(string.format("%s  ✓ %s", TAG, code))
            successCount = successCount + 1
        else
            warn(string.format("%s  ✗ %s: %s", TAG, code, tostring(result)))
            failedCount = failedCount + 1
        end
        frameSafeWait(CFG.CODE_REDEEM_INTERVAL)
    end
    frameSafeWait(CFG.CODE_SETTLE_WAIT)
    print(string.format("%s  兑换码步骤完成: 成功=%d, 失败=%d", TAG, successCount, failedCount))
    return true
end

-- ============================================================
-- 步骤2: 活动兑换
-- ============================================================
local function step02_activityExchange()
    print(string.format("\n%s ========== 步骤2: 活动兑换 ==========", TAG))
    local exchanges = {
        { name = "蛋换币",   tmplId = CFG.EGG_TO_COIN_TMPL_ID,  count = CFG.EGG_TO_COIN_COUNT },
        { name = "孵化药水", tmplId = CFG.HATCH_POTION_TMPL_ID, count = CFG.HATCH_POTION_COUNT },
        { name = "经验果实", tmplId = CFG.EXP_FRUIT_TMPL_ID,    count = CFG.EXP_FRUIT_COUNT },
    }
    for _, ex in ipairs(exchanges) do
        local soldCount = getActivityShopSelledCount(CFG.ACTIVITY_ID, ex.tmplId)
        if soldCount >= ex.count then
            print(string.format("%s  ✓ %s 已满足目标 [%d/%d]", TAG, ex.name, soldCount, ex.count))
        else
            while soldCount < ex.count do
                local targetCount = soldCount + 1
                local ok, result = doGameRequest(
                    PathTool.ActivityShopSystem.ClientBuy,
                    CFG.ACTIVITY_ID, ex.tmplId
                )
                if not ok then
                    warn(string.format("%s  ✗ %s [%d/%d]: %s", TAG, ex.name, targetCount, ex.count, tostring(result)))
                    return false, "activity_exchange_failed"
                end
                local verifyOk, latestCount = waitForActivityShopSelledCount(
                    CFG.ACTIVITY_ID,
                    ex.tmplId,
                    targetCount,
                    CFG.ACTIVITY_VERIFY_TIMEOUT
                )
                if not verifyOk then
                    warn(string.format("%s  ✗ %s 购买后未在 %ss 内落地 [%d/%d]", TAG, ex.name, tostring(CFG.ACTIVITY_VERIFY_TIMEOUT), targetCount, ex.count))
                    return false, "activity_exchange_verify_timeout"
                end
                soldCount = latestCount
                print(string.format("%s  ✓ %s [%d/%d]", TAG, ex.name, soldCount, ex.count))
                frameSafeWait(0.25)
            end
        end
    end
    return true
end

-- ============================================================
-- 步骤3: 孵化蛋
-- ============================================================
local function step03_hatchEggs()
    print(string.format("\n%s ========== 步骤3: 孵化蛋 ==========", TAG))

    -- 等待任意一种蛋存在 (最多300秒)
    local WAIT_TIMEOUT = 300
    local waitStart = tick()
    local totalEggs = 0
    print(string.format("%s  等待蛋出现 (TmplIds=%s)...", TAG, table.concat(CFG.EGG_TMPL_IDS, ",")))
    while tick() - waitStart < WAIT_TIMEOUT do
        totalEggs = 0
        pcall(function()
            local gp = getGamePlayer()
            if gp and gp.egg and gp.egg.GetEggAmount then
                for _, eid in ipairs(CFG.EGG_TMPL_IDS) do
                    totalEggs = totalEggs + (tonumber(tostring(gp.egg:GetEggAmount(eid))) or 0)
                end
            end
        end)
        if totalEggs > 0 then
            print(string.format("%s  ✓ 检测到 %d 个蛋", TAG, totalEggs))
            break
        end
        if math.floor(tick() - waitStart) % 30 == 0 and tick() - waitStart > 1 then
            print(string.format("%s  蛋未出现，已等 %ds/%ds", TAG, math.floor(tick() - waitStart), WAIT_TIMEOUT))
        end
        frameSafeWait(2)
    end
    if totalEggs <= 0 then
        warn(string.format("%s  ✗ 等待蛋超时 (%ds)，跳过孵化", TAG, WAIT_TIMEOUT))
        return false, "egg_wait_timeout"
    end

    local hatchedCount = 0
    local totalRounds = 0
    while true do
        totalRounds = totalRounds + 1
        if totalRounds > CFG.MAX_HATCH_ROUNDS then
            local slotEggTmplId = getHatchSlotEggTmplId(CFG.HATCH_SLOT)
            local totalEggsLeft = getTotalConfiguredEggAmount()
            if (slotEggTmplId and slotEggTmplId ~= 0) or totalEggsLeft > 0 then
                warn(string.format("%s  ✗ 孵化轮次超出上限(%d)，槽位蛋=%s，背包剩余蛋=%d",
                    TAG, CFG.MAX_HATCH_ROUNDS, tostring(slotEggTmplId), totalEggsLeft))
                return false, "hatch_round_limit_exceeded"
            end
            break
        end

        local slotEggTmplId = getHatchSlotEggTmplId(CFG.HATCH_SLOT)
        local petBagBefore = getPetBagAmount()
        local shouldContinueLoop = false

        if slotEggTmplId and slotEggTmplId ~= 0 then
            local remainingTime = getHatchSlotRemainingTime(CFG.HATCH_SLOT)
            if remainingTime ~= nil and remainingTime <= 0 then
                print(string.format("%s  孵化槽[%d] 已完成，直接领取 (TmplId=%d)", TAG, CFG.HATCH_SLOT, slotEggTmplId))
                local claimOk, claimResult = doGameRequest(PathTool.EggSystem.ClientHatchTaken, CFG.HATCH_SLOT)
                if not claimOk then
                    warn(string.format("%s  ✗ 领取已完成孵化失败: %s", TAG, tostring(claimResult)))
                    return false, "hatch_claim_failed"
                end
            else
                print(string.format("%s  孵化槽[%d] 已有蛋(TmplId=%d)，剩余时间=%s，使用孵化药水",
                    TAG, CFG.HATCH_SLOT, slotEggTmplId, remainingTime and string.format("%.1fs", remainingTime) or "未知"))
                local potionOk, potionResult = doGameRequest(PathTool.EggSystem.ClientHatchSkip, CFG.HATCH_SLOT, true)
                if not potionOk then
                    warn(string.format("%s  ✗ 孵化药水失败: %s", TAG, tostring(potionResult)))
                    return false, "hatch_skip_failed"
                end
                frameSafeWait(0.5)
                local afterSkipRemaining = getHatchSlotRemainingTime(CFG.HATCH_SLOT)
                if afterSkipRemaining ~= nil and afterSkipRemaining <= 0 then
                    print(string.format("%s  ✓ 药水后孵化完成，直接领取", TAG))
                    local claimOk, claimResult = doGameRequest(PathTool.EggSystem.ClientHatchTaken, CFG.HATCH_SLOT)
                    if not claimOk then
                        warn(string.format("%s  ✗ 药水后领取失败: %s", TAG, tostring(claimResult)))
                        return false, "hatch_claim_failed"
                    end
                else
                    frameSafeWait(0.5)
                    shouldContinueLoop = true
                end
            end
        else
            local selectedEggTmplId = nil
            local selectedRemaining = 0
            for _, eggTmplId in ipairs(CFG.EGG_TMPL_IDS) do
                local remaining = getEggAmountByTmplId(eggTmplId)
                if remaining > 0 then
                    selectedEggTmplId = eggTmplId
                    selectedRemaining = remaining
                    break
                end
            end

            if not selectedEggTmplId then
                if slotEggTmplId and slotEggTmplId ~= 0 then
                    shouldContinueLoop = true
                end
                break
            end

            print(string.format("%s  蛋TmplId=%d 第%d轮: 剩余=%d", TAG, selectedEggTmplId, totalRounds, selectedRemaining))
            local ok, result = doGameRequest(PathTool.EggSystem.ClientHatchStart, CFG.HATCH_SLOT, selectedEggTmplId)
            if not ok then
                warn(string.format("%s  ✗ 放蛋失败(TmplId=%d): %s", TAG, selectedEggTmplId, tostring(result)))
                return false, "hatch_start_failed"
            end
            print(string.format("%s  ✓ 放蛋成功(TmplId=%d)", TAG, selectedEggTmplId))
            frameSafeWait(0.3)
            shouldContinueLoop = true
        end

        if not shouldContinueLoop then
            if not waitForHatchSlotClear(CFG.HATCH_SLOT, CFG.HATCH_SLOT_CLEAR_TIMEOUT) then
                warn(string.format("%s  ✗ 孵化槽[%d] 未在 %ds 内清空", TAG, CFG.HATCH_SLOT, CFG.HATCH_SLOT_CLEAR_TIMEOUT))
                return false, "hatch_slot_not_cleared"
            end
            local petBagOk, petBagAfter = waitForPetBagAmount(petBagBefore + 1, CFG.PET_BAG_VERIFY_TIMEOUT)
            if not petBagOk then
                warn(string.format("%s  ✗ 宠物背包未在 %ds 内增加，孵化结果可能未落地 (之前=%d, 当前=%d)",
                    TAG, CFG.PET_BAG_VERIFY_TIMEOUT, petBagBefore, petBagAfter))
                return false, "pet_bag_not_updated"
            end
            hatchedCount = hatchedCount + 1
            print(string.format("%s  ✓ 领取孵化宠物成功 (背包 %d -> %d)", TAG, petBagBefore, petBagAfter))
            frameSafeWait(0.3)
        end
        frameSafeWait(0.2)
    end

    if hatchedCount <= 0 then
        return false, "no_eggs_hatched"
    end
    return true
end

-- ============================================================
-- 步骤4: 装备最强宠物
-- ============================================================
local function step04_equipBest()
    print(string.format("\n%s ========== 步骤4: 装备最强宠物 ==========", TAG))
    local beforePets = getEquippedPetIds()
    local ok, result = doGameRequest(PathTool.PetSystem.ClientEquipBest)
    if not ok then
        warn(string.format("%s  ✗ 装备失败: %s", TAG, tostring(result)))
        return false, "equip_best_failed"
    end
    local equippedOk, pets = waitForEquippedPetsStable(CFG.EQUIP_VERIFY_TIMEOUT, CFG.EQUIP_STABLE_WINDOW)
    if not equippedOk then
        warn(string.format("%s  ✗ 装备超时，%ds 内未检测到已装备宠物", TAG, CFG.EQUIP_VERIFY_TIMEOUT))
        return false, "equip_verify_timeout"
    end
    print(string.format("%s  ✓ 装备最强宠物成功 (%d只, 之前=%s, 现在=%s)",
        TAG, #pets, getPetIdListKey(beforePets), getPetIdListKey(pets)))
    return true
end

-- ============================================================
-- 步骤5: 喂食经验果实
-- ============================================================
local function step05_feedPets()
    print(string.format("\n%s ========== 步骤5: 喂食经验果实 ==========", TAG))
    local pets = getEquippedPetIds()
    if #pets == 0 then
        warn(TAG, "  无法获取装备宠物")
        return false, "no_equipped_pets"
    end

    print(string.format("%s  找到 %d 只装备宠物", TAG, #pets))
    local requiredFruit = CFG.FEED_COUNT_PER_PET * #pets
    local fruitOk, currentFruit = waitForPetExpItemCountAtLeast(CFG.EXP_ITEM_TMPL_ID, requiredFruit, CFG.FEED_ITEM_WAIT_TIMEOUT)
    if not fruitOk then
        warn(string.format("%s  ✗ 100000 EXP Fruit 不足，%ds 内仅检测到 %d/%d (PetExpItem=%d)",
            TAG, CFG.FEED_ITEM_WAIT_TIMEOUT, currentFruit, requiredFruit, CFG.EXP_ITEM_TMPL_ID))
        return false, "feed_item_not_ready"
    end
    for i, petItemId in ipairs(pets) do
        local fruitBefore = getPetExpItemCount(CFG.EXP_ITEM_TMPL_ID)
        if fruitBefore < CFG.FEED_COUNT_PER_PET then
            warn(string.format("%s  ✗ 喂食前 100000 EXP Fruit 不足: 当前=%d, 需要=%d", TAG, fruitBefore, CFG.FEED_COUNT_PER_PET))
            return false, "feed_item_insufficient"
        end
        local ok, result = doGameRequest(
            PathTool.PetSystem.ClientFeed,
            tostring(petItemId),
            {},
            { { TmplId = CFG.EXP_ITEM_TMPL_ID, Count = CFG.FEED_COUNT_PER_PET } }
        )
        if not ok then
            warn(string.format("%s  ✗ 宠物 %s 喂食失败: %s", TAG, tostring(petItemId), tostring(result)))
            return false, "pet_feed_failed"
        end
        local fruitAfterTarget = math.max(fruitBefore - CFG.FEED_COUNT_PER_PET, 0)
        local feedVerifyOk, fruitAfter = waitForPetExpItemCountAtMost(CFG.EXP_ITEM_TMPL_ID, fruitAfterTarget, CFG.FEED_VERIFY_TIMEOUT)
        if not feedVerifyOk then
            warn(string.format("%s  ✗ 宠物 %s 喂食后 100000 EXP Fruit 未按预期扣除 (之前=%d, 当前=%d, 目标<=%d)",
                TAG, tostring(petItemId), fruitBefore, fruitAfter, fruitAfterTarget))
            return false, "pet_feed_verify_failed"
        end
        print(string.format("%s  ✓ 宠物 %s 喂食 %d 个 100000 EXP Fruit (剩余=%d, 进度=%d/%d)",
            TAG, tostring(petItemId), CFG.FEED_COUNT_PER_PET, fruitAfter, i, #pets))
        frameSafeWait(0.5)
    end
    return true
end

-- ============================================================
-- 等级获取 (同自动升级12级gpt)
-- ============================================================
local function getPlayerLevel()
    local gp = getGamePlayer()
    if gp and gp.GetLevel then
        local ok, level = pcall(function()
            return gp:GetLevel()
        end)
        if ok and type(level) == "number" then
            return level
        end
    end
    if gp and gp.saveData and type(gp.saveData.level) == "number" then
        return gp.saveData.level
    end
    local attr = (localPlayer and (localPlayer:GetAttribute("Level") or localPlayer:GetAttribute("PlayerLevel"))) or nil
    if type(attr) == "number" then
        return attr
    end
    return 0
end

-- ============================================================
-- 怪物系统工具函数 (同自动升级12级gpt)
-- ============================================================
local function getMonsterIdFromInfo(mInfo)
    if not mInfo then return nil end
    if type(mInfo.MonsterId) == "number" then return mInfo.MonsterId end
    if type(mInfo.MonsterId) == "string" then local n = tonumber(mInfo.MonsterId); if n then return n end end
    if type(mInfo.id) == "number" then return mInfo.id end
    if type(mInfo.id) == "string" then local n = tonumber(mInfo.id); if n then return n end end
    if mInfo.ServerNode and mInfo.ServerNode.GetAttribute then
        local ok, attrId = pcall(function()
            return mInfo.ServerNode:GetAttribute("MonsterId") or mInfo.ServerNode:GetAttribute("Id") or mInfo.ServerNode:GetAttribute("ObjId")
        end)
        if ok then
            if type(attrId) == "number" then return attrId end
            if type(attrId) == "string" then local n = tonumber(attrId); if n then return n end end
        end
    end
    if PathTool.MgrMonsterClient and PathTool.MgrMonsterClient.GetMonsterIdByPart then
        local part = nil
        if mInfo.Model and mInfo.Model.PrimaryPart then part = mInfo.Model.PrimaryPart
        elseif mInfo.Model and mInfo.Model:IsA("BasePart") then part = mInfo.Model end
        if part then
            local ok, value = pcall(function() return PathTool.MgrMonsterClient.GetMonsterIdByPart(part) end)
            if ok and type(value) == "number" then return value end
        end
    end
    return nil
end

local function isMonsterAlive(mInfo)
    if not mInfo then return false end
    if mInfo.IsAlive then
        local ok, alive = pcall(function() return mInfo:IsAlive() end)
        if ok then return alive == true end
    end
    if mInfo.ServerNode then
        local ok, hp = pcall(function() return mInfo.ServerNode:GetAttribute("HP") end)
        if ok and type(hp) == "number" then return hp > 0 end
    end
    return true
end

local function getMonsterPos(mInfo)
    if not mInfo then return nil end
    if mInfo.CurrentCFrame then return mInfo.CurrentCFrame.Position end
    if mInfo.Model and mInfo.Model:IsA("Model") then
        local ok, pivot = pcall(function() return mInfo.Model:GetPivot() end)
        if ok and pivot then return pivot.Position end
    end
    return nil
end

local function attackMonster(monsterId)
    if type(monsterId) ~= "number" then return false end
    local attackFns = {
        { name = "MonsterSystem.ClientAttackMonsterOnHasAlivePet",
          available = function() return PathTool.MonsterSystem and PathTool.MonsterSystem.ClientAttackMonsterOnHasAlivePet end,
          fn = function() return PathTool.MonsterSystem.ClientAttackMonsterOnHasAlivePet(monsterId) end },
        { name = "AttackSystem.ClientAttackMonster",
          available = function() return PathTool.AttackSystem and PathTool.AttackSystem.ClientAttackMonster end,
          fn = function() return PathTool.AttackSystem.ClientAttackMonster(monsterId) end },
        { name = "MgrMonsterClient.ClientAttack",
          available = function() return PathTool.MgrMonsterClient and PathTool.MgrMonsterClient.ClientAttack end,
          fn = function() return PathTool.MgrMonsterClient.ClientAttack(monsterId) end },
    }
    for _, item in ipairs(attackFns) do
        if item.available() then
            local ok, result = pcall(item.fn)
            if ok and result ~= false then return true end
        end
    end
    return false
end

-- 扫描附近怪物，返回最近的活着的怪物ID
local function findNearestAliveMonster(originPos, maxDist)
    if not PathTool.MgrMonsterClient or not PathTool.MgrMonsterClient.IterMonster or not originPos then
        return nil
    end
    local nearestId = nil
    local nearestDist = math.huge
    pcall(function()
        PathTool.MgrMonsterClient.IterMonster(function(mInfo)
            if mInfo and isMonsterAlive(mInfo) then
                local monsterId = getMonsterIdFromInfo(mInfo)
                if monsterId then
                    local pos = getMonsterPos(mInfo)
                    if pos then
                        local dist = (originPos - pos).Magnitude
                        if dist <= maxDist and dist < nearestDist then
                            nearestDist = dist
                            nearestId = monsterId
                        end
                    else
                        -- 没位置但活着，作为备用
                        if not nearestId then
                            nearestId = monsterId
                        end
                    end
                end
            end
            return true
        end)
    end)
    return nearestId
end

local function getMonsterAliveByMonsterId(monsterId)
    if type(monsterId) ~= "number" or not PathTool.MgrMonsterClient then return nil end
    local alive = nil
    pcall(function()
        PathTool.MgrMonsterClient.IterMonster(function(mInfo)
            if mInfo then
                local id = getMonsterIdFromInfo(mInfo)
                if id == monsterId then
                    alive = isMonsterAlive(mInfo)
                    return false
                end
            end
            return true
        end)
    end)
    return alive
end

-- ============================================================
-- 平滑移动（与 寻找Undine.lua 一致）
-- ============================================================
local FLY_HEIGHT_OFFSET = 40
local FLY_SPEED_H = 40
local FLY_SPEED_V = 30
local ROTATE_DURATION = 0.12

-- 两阶段：先仅旋转 ROTATE_DURATION，再仅位移（duration = max(distance/speed, 0.1)）
local function SmoothMove(startPos, endPos, speed, faceCamera)
    local character, hrp = getCharacterAndRootPart()
    if not character or not hrp then return false end
    startPos = hrp.Position
    speed = math.max(tonumber(speed) or 0, 1)
    local distance = (endPos - startPos).Magnitude
    if distance <= CFG.TWEEN_VERIFY_RADIUS then
        return true
    end
    local moveDuration = math.max(distance / speed, CFG.LOW_FPS_MODE and CFG.LOW_FPS_FRAME_TIME or 0.1)
    local tweenTimeout = moveDuration + CFG.TWEEN_TIMEOUT_PADDING
    local direction = distance > 0.0001 and (endPos - startPos).Unit or Vector3.new(1, 0, 0)

    -- Phase 1: 仅旋转（位置固定）
    local rotateEndCFrame
    if direction.Magnitude < 0.01 or math.abs(direction.Y) > 0.95 then
        rotateEndCFrame = CFrame.new(startPos) * (hrp.CFrame - hrp.CFrame.Position)
    else
        rotateEndCFrame = CFrame.lookAt(startPos, startPos + direction)
    end
    local rotateTween = TweenService:Create(hrp, TweenInfo.new(ROTATE_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { CFrame = rotateEndCFrame })
    local rotateOk = waitForTweenWithTimeout(rotateTween, ROTATE_DURATION + CFG.TWEEN_TIMEOUT_PADDING)
    character, hrp = getCharacterAndRootPart()
    if not hrp or not hrp.Parent then return false end
    if not rotateOk then
        pcall(function()
            hrp.CFrame = rotateEndCFrame
        end)
    end

    -- Phase 2: 仅位移（保持旋转）
    local cam = workspace.CurrentCamera
    local conn
    if faceCamera and cam then
        conn = RunService.Heartbeat:Connect(function()
            if not hrp or not hrp.Parent then return end
            cam.CFrame = CFrame.lookAt(cam.CFrame.Position, endPos)
        end)
    end
    local moveEndCFrame = CFrame.new(endPos) * (hrp.CFrame - hrp.CFrame.Position)
    local moveTween = TweenService:Create(hrp, TweenInfo.new(moveDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { CFrame = moveEndCFrame })
    local moveOk = waitForTweenWithTimeout(moveTween, tweenTimeout)
    if conn then conn:Disconnect() end
    character, hrp = getCharacterAndRootPart()
    if not character or not hrp then return false end

    local finalDist = (hrp.Position - endPos).Magnitude
    if finalDist > CFG.TWEEN_VERIFY_RADIUS then
        pcall(function()
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            hrp.CFrame = moveEndCFrame
        end)
        frameSafeWait(CFG.LOW_FPS_FRAME_TIME)
        finalDist = (hrp.Position - endPos).Magnitude
    end

    return moveOk or finalDist <= CFG.TWEEN_VERIFY_RADIUS
end

-- 三段飞行：先升空 → 水平移动 → 下降到目标（与 寻找Undine.lua 一致）
local function FlyToPosition(targetPos)
    local ready = waitForCharacterReady(8)
    if not ready then
        return false
    end

    for attempt = 1, CFG.FLY_RETRY_COUNT do
        local allPhasesOk = true
        for phase = 1, 3 do
            local _, humanoidRootPart = getCharacterAndRootPart()
            if not humanoidRootPart then
                allPhasesOk = false
                break
            end

            local startPos = humanoidRootPart.Position
            local ok = false
            if phase == 1 then
                ok = SmoothMove(startPos, startPos + Vector3.new(0, FLY_HEIGHT_OFFSET, 0), FLY_SPEED_V, false)
            elseif phase == 2 then
                ok = SmoothMove(startPos, Vector3.new(targetPos.X, startPos.Y, targetPos.Z), FLY_SPEED_H, false)
            else
                ok = SmoothMove(startPos, targetPos, FLY_SPEED_V, false)
            end

            if not ok then
                allPhasesOk = false
                break
            end
            frameSafeWait(0.2)
        end

        frameSafeWait(0.4)
        local dist = getDistanceToPosition(targetPos)
        print(string.format("%s  飞行后距离目标: %.1f studs (第%d次)", TAG, dist, attempt))
        if allPhasesOk and dist <= CFG.FLY_VERIFY_RADIUS then
            return true
        end
    end

    for snapAttempt = 1, 3 do
        if snapCharacterToPosition(targetPos) then
            frameSafeWait(0.25)
            local dist = getDistanceToPosition(targetPos)
            print(string.format("%s  飞行纠偏距离: %.1f studs (第%d次)", TAG, dist, snapAttempt))
            if dist <= CFG.FLY_VERIFY_RADIUS then
                return true
            end
        end
    end

    return getDistanceToPosition(targetPos) <= CFG.FLY_VERIFY_RADIUS
end

-- ============================================================
-- 宠物实时血量检测 (从世界宠物获取，非背包)
-- ============================================================
local function getEquippedPetsMinHpPercent()
    local minPct = 1.0 -- 默认满血
    local found = false
    pcall(function()
        local gp = getGamePlayer()
        if not gp or not gp.pet then return end
        local capacity = gp.pet:GetEquipCapacity() or 0
        for slot = 1, capacity do
            local petItem = gp.pet:GetEquipedItemBySlotIndex(slot)
            if petItem then
                local hp = nil
                local maxHp = nil
                local maxHpNum = nil
                local itemKey = PathTool.PetItem and PathTool.PetItem.BuildItemKey and PathTool.PetItem.BuildItemKey(petItem)
                if itemKey and PathTool.MgrPetClient and PathTool.MgrPetClient.GetSelfPetInfo then
                    local petObj = PathTool.MgrPetClient.GetSelfPetInfo(itemKey)
                    if petObj and petObj.HealthValue then
                        local hv = petObj.HealthValue
                        pcall(function()
                            hp = PathTool.LogicNumber.FixLogicNumber(hv.Value)
                            maxHp = PathTool.LogicNumber.FixLogicNumber(hv:GetAttribute("MaxHealth"))
                            maxHpNum = PathTool.LogicNumber.ToNumber(maxHp)
                        end)
                    end
                end
                if (not hp or not maxHp or not maxHpNum or maxHpNum <= 0) and petItem.GetHealth and petItem.GetMaxHealth then
                    pcall(function()
                        hp = PathTool.LogicNumber.FixLogicNumber(petItem:GetHealth())
                        maxHp = PathTool.LogicNumber.FixLogicNumber(petItem:GetMaxHealth())
                        maxHpNum = PathTool.LogicNumber.ToNumber(maxHp)
                    end)
                end
                if hp and maxHp and maxHpNum and maxHpNum > 0 then
                    local pct = PathTool.LogicNumber.ToNumber(PathTool.LogicNumber.Divide(hp, maxHp))
                    if pct < minPct then
                        minPct = pct
                    end
                    found = true
                end
            end
        end
    end)
    if not found then return 1.0 end
    return minPct
end

local function isPetItemDead(petItem)
    if not petItem then
        return false
    end

    local dead = false
    pcall(function()
        if type(petItem.IsDead) == "function" then
            dead = petItem:IsDead() == true
        end
    end)
    if dead then
        return true
    end

    pcall(function()
        if type(petItem.IsAlive) == "function" then
            local alive = petItem:IsAlive()
            if alive ~= nil then
                dead = not alive
            end
        end
    end)
    if dead then
        return true
    end

    pcall(function()
        if petItem.HealthValue then
            local hv = petItem.HealthValue
            if type(hv) == "userdata" and hv.Value then
                if PathTool.LogicNumber and PathTool.LogicNumber.LessThanOrEqualTo then
                    dead = PathTool.LogicNumber.LessThanOrEqualTo(hv.Value, 0)
                else
                    local num = tonumber(tostring(hv.Value))
                    if num and num <= 0 then
                        dead = true
                    end
                end
            end
        end
    end)

    if dead then
        return true
    end

    pcall(function()
        if type(petItem.GetHealth) == "function" then
            local hp = petItem:GetHealth()
            local hpNum = tonumber(tostring(PathTool.LogicNumber and PathTool.LogicNumber.ToNumber and PathTool.LogicNumber.ToNumber(hp) or hp))
            if hpNum and hpNum <= 0 then
                dead = true
            end
        end
    end)

    return dead
end

local function getEquippedDeadPetCount()
    local gp = getGamePlayer()
    if not gp or not gp.pet or not gp.pet.IterEquipedItem then
        return 0, 0
    end

    local total = 0
    local deadCount = 0
    pcall(function()
        gp.pet:IterEquipedItem(function(petItem)
            total = total + 1
            if isPetItemDead(petItem) then
                deadCount = deadCount + 1
            end
            return true
        end)
    end)
    return deadCount, total
end

local function isAnyEquippedPetDead()
    local deadCount = getEquippedDeadPetCount()
    return deadCount > 0, deadCount
end

local function getNearestRecoverPointPosition()
    local _, hrp = getCharacterAndRootPart()
    if not hrp then
        return nil
    end

    local candidates = {}
    pcall(function()
        local areaRoot = workspace:FindFirstChild("Area")
        if areaRoot then
            for _, areaModel in ipairs(areaRoot:GetChildren()) do
                local serverZone = areaModel:FindFirstChild("ServerZone")
                local recoverRoot = serverZone and serverZone:FindFirstChild("Recover")
                if recoverRoot then
                    for _, inst in ipairs(recoverRoot:GetDescendants()) do
                        if inst:IsA("BasePart") and string.match(inst.Name, "^Rec") then
                            table.insert(candidates, inst)
                        end
                    end
                end
            end
        end
    end)

    if #candidates == 0 then
        pcall(function()
            if PathTool and PathTool.FindForPath then
                local areaRoot = workspace:FindFirstChild("Area")
                if areaRoot then
                    for _, areaModel in ipairs(areaRoot:GetChildren()) do
                        local rec1 = PathTool.FindForPath(workspace, string.format("Area.%s.ServerZone.Recover.Rec_1", areaModel.Name))
                        if rec1 and rec1:IsA("BasePart") then
                            table.insert(candidates, rec1)
                        end
                    end
                end
            end
        end)
    end

    local bestPos = nil
    local bestDist = math.huge
    local bestName = nil
    for _, part in ipairs(candidates) do
        local dist = (part.Position - hrp.Position).Magnitude
        if dist < bestDist then
            bestDist = dist
            bestPos = part.Position
            bestName = part:GetFullName()
        end
    end
    return bestPos, bestDist, bestName
end

local function walkToPosition(targetPos, stopDistance, timeout)
    stopDistance = tonumber(stopDistance) or 8
    timeout = tonumber(timeout) or 45

    local character, hrp = getCharacterAndRootPart()
    if not character or not hrp then
        return false, "character_not_ready"
    end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return false, "humanoid_missing"
    end

    if (hrp.Position - targetPos).Magnitude <= stopDistance then
        return true
    end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2.5,
        AgentHeight = 5,
        AgentCanJump = true,
        WaypointSpacing = CFG.WALK_WAYPOINT_SPACING,
    })
    local computed = pcall(function()
        path:ComputeAsync(hrp.Position, targetPos)
    end)

    local waypoints = nil
    if computed and path.Status == Enum.PathStatus.Success then
        waypoints = path:GetWaypoints()
    else
        waypoints = {
            { Position = targetPos, Action = Enum.PathWaypointAction.Walk }
        }
    end

    local startTick = tick()
    for _, waypoint in ipairs(waypoints) do
        character, hrp = getCharacterAndRootPart()
        if not character or not hrp then
            return false, "character_lost"
        end
        humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            return false, "humanoid_lost"
        end

        if (hrp.Position - targetPos).Magnitude <= stopDistance then
            return true
        end

        if waypoint.Action == Enum.PathWaypointAction.Jump then
            pcall(function()
                humanoid.Jump = true
            end)
        end

        local waypointStart = tick()
        while tick() - waypointStart < 8 do
            character, hrp = getCharacterAndRootPart()
            if not hrp then
                return false, "character_lost"
            end
            humanoid = character:FindFirstChildOfClass("Humanoid")
            if not humanoid then
                return false, "humanoid_lost"
            end
            if (hrp.Position - targetPos).Magnitude <= stopDistance then
                return true
            end
            if (hrp.Position - waypoint.Position).Magnitude <= CFG.WALK_WAYPOINT_REACH_RADIUS then
                break
            end
            humanoid:MoveTo(waypoint.Position)
            if tick() - startTick >= timeout then
                return false, "walk_timeout"
            end
            frameSafeWait(CFG.WALK_MOVE_REFRESH)
        end

        character, hrp = getCharacterAndRootPart()
        if hrp and (hrp.Position - targetPos).Magnitude <= stopDistance then
            return true
        end
        if tick() - startTick >= timeout then
            return false, "walk_timeout"
        end
    end

    local finalDist = getDistanceToPosition(targetPos)
    return finalDist <= stopDistance, finalDist <= stopDistance and nil or string.format("walk_not_reached_%.1f", finalDist)
end

local function waitUntilPetsRecoveredFully(timeout)
    timeout = tonumber(timeout) or CFG.PET_DEAD_RECOVER_TIMEOUT
    local startTick = tick()
    local lastLogTick = 0

    while tick() - startTick < timeout do
        local deadAny, deadCount = isAnyEquippedPetDead()
        local minHp = getEquippedPetsMinHpPercent()
        local recoverAttr = localPlayer:GetAttribute("Recover")
        if not deadAny and minHp >= 0.99 then
            return true
        end
        local now = tick()
        if now - lastLogTick >= 5 then
            print(string.format("%s  恢复点回血中... Recover=%s, Dead=%d, HP=%.0f%%",
                TAG, tostring(recoverAttr), tonumber(deadCount) or 0, minHp * 100))
            lastLogTick = now
        end
        frameSafeWait(1)
    end

    return false
end

local function recoverPetsByWalking(returnPos)
    local recoverPos, recoverDist, recoverName = getNearestRecoverPointPosition()
    if not recoverPos then
        return false, "recover_point_missing"
    end

    print(string.format("%s  宠物死亡，前往最近复活点恢复: %s (距离 %.1f studs)",
        TAG, tostring(recoverName), tonumber(recoverDist) or -1))
    local reachOk, reachReason = walkToPosition(recoverPos, CFG.RECOVER_POINT_REACH_RADIUS, 60)
    if not reachOk then
        warn(string.format("%s  ✗ 无法走到复活点: %s", TAG, tostring(reachReason)))
        return false, tostring(reachReason or "recover_walk_failed")
    end

    print(string.format("%s  ✓ 已到达复活点，等待宠物复活并回满血", TAG))
    local recovered = waitUntilPetsRecoveredFully(CFG.PET_DEAD_RECOVER_TIMEOUT)
    if not recovered then
        warn(string.format("%s  ✗ 复活点等待超时，宠物仍未满血", TAG))
        return false, "recover_timeout"
    end

    print(string.format("%s  ✓ 宠物已复活并满血，返回挂机点", TAG))
    local backTarget = returnPos or CFG.DUNE_POS
    local backOk, backReason = walkToPosition(backTarget, CFG.RETURN_TO_FARM_REACH_RADIUS, 90)
    if not backOk then
        warn(string.format("%s  ✗ 返回挂机点失败: %s", TAG, tostring(backReason)))
        return false, tostring(backReason or "return_to_farm_failed")
    end

    print(string.format("%s  ✓ 已返回挂机点附近，继续攻击", TAG))
    return true
end

-- ============================================================
-- 步骤6: 飞到沙丘挂机到目标等级 (攻击怪物+等级检测)
-- ============================================================
local function step06_farmDunes()
    print(string.format("\n%s ========== 步骤6: 沙丘挂机 ==========", TAG))

    -- 如果已经达到目标等级（断线恢复时可能已达标），直接跳过
    local curLevel = getPlayerLevel()
    if type(curLevel) == "number" and curLevel >= CFG.TARGET_LEVEL then
        print(string.format("%s  已达到 %d 级，跳过挂机", TAG, curLevel))
        return true
    end

    -- 飞到沙丘（三段平滑飞行）
    local flyOk = FlyToPosition(CFG.DUNE_POS)
    if flyOk then
        print(string.format("%s  ✓ 已飞到沙丘 %s", TAG, tostring(CFG.DUNE_POS)))
    else
        warn(string.format("%s  飞行未完全到位，尝试直接传送", TAG))
        snapCharacterToPosition(CFG.DUNE_POS)
    end
    frameSafeWait(CFG.LOW_FPS_MODE and 3 or 2)
    setAutoAttackEnabled(true)

    -- 挂机打怪循环
    print(string.format("%s  开始打怪挂机，目标等级 %d", TAG, CFG.TARGET_LEVEL))
    local ATTACK_COOLDOWN = CFG.LOW_FPS_MODE and 0.20 or 0.12
    local SCAN_INTERVAL = CFG.LOW_FPS_MODE and 0.50 or 0.35
    local LOOP_WAIT = CFG.LOW_FPS_MODE and 0.20 or SCAN_INTERVAL
    local FARM_SEARCH_RADIUS = 70
    local MAX_FARM_TIME = 99999
    local HP_PAUSE_THRESHOLD = 0.40   -- 低于40%暂停
    local HP_RESUME_THRESHOLD = 0.99  -- 恢复到99%再继续
    local AUTO_ATTACK_REFRESH_INTERVAL = 12

    local currentTargetId = nil
    local lastAttackTick = 0
    local lastScanTick = 0
    local lastLogTick = 0
    local lastAutoAttackRefresh = 0
    local startTime = tick()
    local isPaused = false
    local lastSavedLevel = 0
    local didReequipAtLv8 = false
    local nearbyPlayerSince = nil
    local lastNearbyPlayerLog = 0
    local recoverReturnPos = CFG.DUNE_POS

    -- 从进度文件恢复8级换装状态
    local savedData = loadProgress()
    if savedData and savedData.extra and savedData.extra.reequipAtLv8 then
        didReequipAtLv8 = true
        print(string.format("%s  (从进度恢复: 8级换装已完成)", TAG))
    end

    while tick() - startTime < MAX_FARM_TIME do
        local now = tick()

        -- 等级检测
        local level = getPlayerLevel()
        if type(level) == "number" and level >= CFG.TARGET_LEVEL then
            print(string.format("%s  ✓ 达到 %d 级!", TAG, level))
            return true
        end

        -- 8级时暂停攻击，重新装备最强宠物
        if type(level) == "number" and level >= 8 and not didReequipAtLv8 then
            didReequipAtLv8 = true
            currentTargetId = nil
            print(string.format("%s  ★ 达到8级，暂停攻击，等待5秒后重新装备最强宠物", TAG))
            frameSafeWait(5)
            local reEquipStart = tick()
            local equippedPets = {}
            while tick() - reEquipStart < CFG.LV8_REEQUIP_TIMEOUT do
                local equipOk, equipResult = doGameRequest(PathTool.PetSystem.ClientEquipBest)
                if not equipOk then
                    warn(string.format("%s  ✗ 8级重装备失败: %s", TAG, tostring(equipResult)))
                end
                local countOk, pets = waitForExactEquippedPetCount(CFG.LV8_REEQUIP_TARGET_COUNT, 2)
                equippedPets = pets or {}
                if countOk then
                    print(string.format("%s  ✓ 8级重装备完成，当前已装备 %d 只宠物", TAG, #equippedPets))
                    break
                end
                warn(string.format("%s  8级重装备后当前仅 %d 只宠物，继续尝试装备", TAG, #equippedPets))
                frameSafeWait(1)
            end
            if #equippedPets ~= CFG.LV8_REEQUIP_TARGET_COUNT then
                warn(string.format("%s  ✗ 8级重装备超时，当前仅装备 %d/%d 只宠物", TAG, #equippedPets, CFG.LV8_REEQUIP_TARGET_COUNT))
                return false, "lv8_reequip_incomplete"
            end
            frameSafeWait(1)
            if setAutoAttackEnabled(true) then
                print(string.format("%s  ✓ 已打开自动攻击", TAG))
                lastAutoAttackRefresh = now
            end
            print(string.format("%s  继续攻击", TAG))
        end

        -- 等级变化时保存进度 (防掉线丢失挂机进度)
        if type(level) == "number" and level > lastSavedLevel then
            lastSavedLevel = level
            saveProgress(7, { level = level, reequipAtLv8 = didReequipAtLv8 }) -- 7=step06的STEPS索引
        end

        local anyPetDead, deadPetCount = isAnyEquippedPetDead()
        if anyPetDead then
            currentTargetId = nil
            isPaused = false
            setAutoAttackEnabled(false)
            print(string.format("%s  ⚠ 检测到 %d 只宠物死亡，停止战斗并前往复活点", TAG, deadPetCount))
            local recoverOk, recoverReason = recoverPetsByWalking(recoverReturnPos)
            if not recoverOk then
                return false, tostring(recoverReason or "recover_failed")
            end
            frameSafeWait(1)
            if setAutoAttackEnabled(true) then
                lastAutoAttackRefresh = tick()
            end
            lastScanTick = 0
            lastAttackTick = 0
            frameSafeWait(0.5)
        end

        -- 检测附近玩家，持续60秒则切服避让
        do
            local nearbyPlayer, nearbyDist = getNearbyPlayerInRadius(CFG.NEARBY_PLAYER_RADIUS)
            if nearbyPlayer then
                if not nearbyPlayerSince then
                    nearbyPlayerSince = now
                    lastNearbyPlayerLog = 0
                    print(string.format("%s  ⚠ 检测到附近玩家 %s (%.1f studs)，开始计时避让",
                        TAG, tostring(nearbyPlayer.Name), tonumber(nearbyDist) or -1))
                end
                local occupiedFor = now - nearbyPlayerSince
                if occupiedFor >= CFG.NEARBY_PLAYER_SWITCH_DELAY then
                    warn(string.format("%s  ⚠ 附近玩家持续 %.0fs 未离开，切换服务器避让", TAG, occupiedFor))
                    local switchOk, switchReason = switchServerForNearbyPlayer()
                    if not switchOk then
                        return false, tostring(switchReason or "nearby_player_switch_failed")
                    end
                    return step06_farmDunes()
                end
                if now - lastNearbyPlayerLog >= 10 then
                    print(string.format("%s  附近玩家 %s 仍在范围内 %.0fs/%.0fs (%.1f studs)",
                        TAG, tostring(nearbyPlayer.Name), occupiedFor, CFG.NEARBY_PLAYER_SWITCH_DELAY, tonumber(nearbyDist) or -1))
                    lastNearbyPlayerLog = now
                end
            else
                if nearbyPlayerSince then
                    print(string.format("%s  ✓ 附近玩家已离开，继续挂机", TAG))
                end
                nearbyPlayerSince = nil
                lastNearbyPlayerLog = 0
            end
        end

        -- 宠物血量检测
        local minHp = getEquippedPetsMinHpPercent()
        if not isPaused and minHp < HP_PAUSE_THRESHOLD then
            isPaused = true
            currentTargetId = nil
            setAutoAttackEnabled(false)
            print(string.format("%s  ⚠ 宠物血量 %.0f%% < 40%%，暂停攻击等待恢复", TAG, minHp * 100))
        elseif isPaused and minHp >= HP_RESUME_THRESHOLD then
            isPaused = false
            if setAutoAttackEnabled(true) then
                lastAutoAttackRefresh = now
            end
            print(string.format("%s  ✓ 宠物血量 %.0f%% >= 99%%，恢复攻击", TAG, minHp * 100))
        end

        if isPaused then
            -- 暂停中，只做等级检测和日志
            if now - lastLogTick >= 10 then
                print(string.format("%s  回血中... HP=%.0f%%, 等级=%s, 已挂机 %ds",
                    TAG, minHp * 100, tostring(level), math.floor(now - startTime)))
                lastLogTick = now
            end
            frameSafeWait(1)
        else
            -- 定期日志
            if now - lastLogTick >= 30 then
                print(string.format("%s  等级=%s, 目标=%d, 当前怪=%s, HP=%.0f%%, 已挂机 %ds",
                    TAG, tostring(level), CFG.TARGET_LEVEL, tostring(currentTargetId),
                    minHp * 100, math.floor(now - startTime)))
                lastLogTick = now
            end

            if now - lastAutoAttackRefresh >= AUTO_ATTACK_REFRESH_INTERVAL then
                if setAutoAttackEnabled(true) then
                    lastAutoAttackRefresh = now
                end
            end

            -- 扫描怪物: 当前目标死了就切换
            if now - lastScanTick >= SCAN_INTERVAL then
                if currentTargetId then
                    local alive = getMonsterAliveByMonsterId(currentTargetId)
                    if alive ~= true then
                        currentTargetId = nil
                    end
                end
                if not currentTargetId then
                    local _, hrpNow = nil, nil
                    pcall(function()
                        local c = localPlayer.Character
                        if c then hrpNow = c:FindFirstChild("HumanoidRootPart") end
                    end)
                    if hrpNow then
                        currentTargetId = findNearestAliveMonster(hrpNow.Position, FARM_SEARCH_RADIUS)
                    end
                end
                lastScanTick = now
            end

            -- 攻击
            if currentTargetId and now - lastAttackTick >= ATTACK_COOLDOWN then
                attackMonster(currentTargetId)
                lastAttackTick = now
            end

            frameSafeWait(LOOP_WAIT)
        end
    end

    warn(string.format("%s  挂机超时 (%ds)，继续下一步", TAG, MAX_FARM_TIME))
    return false, "farm_timeout"
end

-- ============================================================
-- 步骤7: 传送主城
-- ============================================================
local function step07_teleportToCity()
    print(string.format("\n%s ========== 步骤7: 传送主城 ==========", TAG))
    local ok, result = false, "missing_city_teleport"
    if PathTool.SpaceRewardSystem and PathTool.SpaceRewardSystem.ClientTeleport then
        local callOk, callResult = pcall(function()
            return PathTool.SpaceRewardSystem.ClientTeleport("center.map-10000.TCK")
        end)
        ok = callOk and callResult ~= false
        result = callOk and callResult or tostring(callResult)
    elseif PathTool.DataPullManager then
        local channel = PathTool.DataPullManager.GetChannel("ClientTeleportChannel")
        if channel then
            local callOk, callResult = pcall(function()
                return channel:DoRequest("center.map-10000.TCK")
            end)
            ok = callOk and callResult ~= false
            result = callOk and callResult or tostring(callResult)
        end
    end

    if not ok then
        warn(string.format("%s  ✗ 传送失败: %s", TAG, tostring(result)))
        return false, "teleport_city_failed"
    end
    print(string.format("%s  ✓ 传送到 Skyheart Isle", TAG))
    local ready = waitForCharacterReady(CFG.STEP07_SETTLE_WAIT)
    if ready then
        frameSafeWait(CFG.LOW_FPS_MODE and 1 or 0.5)
    else
        frameSafeWait(CFG.STEP07_SETTLE_WAIT)
        ready = waitForCharacterReady(1)
    end
    if not ready then
        warn(string.format("%s  ✗ 传送后角色未在 %ds 内就绪", TAG, CFG.STEP07_SETTLE_WAIT + 1))
        return false, "teleport_city_not_ready"
    end

    -- 到达主城后启用 FPS Boost
    runFpsBoost()
    return true
end

-- ============================================================
-- 背包检测宠物全部死亡
-- ============================================================
local function areAllPetsDeadFromBag()
    local gp = getGamePlayer()
    if not gp or not gp.pet or not gp.pet.IterEquipedItem then
        return false
    end

    local total = 0
    local deadCount = 0
    pcall(function()
        gp.pet:IterEquipedItem(function(petItem)
            total = total + 1
            local dead = false

            pcall(function()
                if type(petItem.IsDead) == "function" then
                    dead = petItem:IsDead() == true
                end
            end)
            if not dead then
                pcall(function()
                    if type(petItem.IsAlive) == "function" then
                        local alive = petItem:IsAlive()
                        if alive ~= nil then dead = not alive end
                    end
                end)
            end
            if not dead then
                pcall(function()
                    if petItem.HealthValue then
                        local hv = petItem.HealthValue
                        if type(hv) == "userdata" and hv.Value then
                            if PathTool.LogicNumber and PathTool.LogicNumber.LessThanOrEqualTo then
                                dead = PathTool.LogicNumber.LessThanOrEqualTo(hv.Value, 0)
                            else
                                local num = tonumber(tostring(hv.Value))
                                if num and num <= 0 then dead = true end
                            end
                        end
                    end
                end)
            end

            if dead then deadCount = deadCount + 1 end
            return true
        end)
    end)

    if total == 0 then return false end
    return deadCount >= total
end

-- ============================================================
-- 步骤8: 进塔推层 (等战斗结束+检测宠物死亡)
-- ============================================================
local function step08_towerRun()
    print(string.format("\n%s ========== 步骤8: 进塔推层 ==========", TAG))

    -- 塔状态常量
    local STA_RESULT = 3
    local RESULT_WIN = 1
    local TOWER_ATTACK_COOLDOWN = CFG.LOW_FPS_MODE and 0.20 or 0.12
    local TOWER_SCAN_INTERVAL = CFG.LOW_FPS_MODE and 0.50 or 0.35
    local TOWER_SEARCH_RADIUS = 90
    local TOWER_AUTO_ATTACK_REFRESH_INTERVAL = 12

    local function getTowerStatus()
        return localPlayer:GetAttribute("TowerStatus"), localPlayer:GetAttribute("TowerResult")
    end

    -- 进入塔
    local ok, result = doGameRequest(PathTool.TowerSystem.ClientTowerEnter)
    if not ok then
        warn(string.format("%s  ✗ 进塔失败: %s", TAG, tostring(result)))
        return false, "tower_enter_failed"
    end
    print(string.format("%s  ✓ 进塔成功", TAG))
    frameSafeWait(2)
    setAutoAttackEnabled(true)

    -- 推层循环
    for layer = 1, CFG.MAX_TOWER_LAYERS do
        print(string.format("%s  --- 第 %d 层战斗中... ---", TAG, layer))

        -- 等待战斗结束，同时检测宠物死亡
        local battleResult = nil
        local petsDied = false
        local layerTimedOut = true
        local startTime = tick()
        local currentTargetId = nil
        local lastAttackTick = 0
        local lastScanTick = 0
        local lastAutoAttackRefresh = 0

        while tick() - startTime < 600 do
            local now = tick()

            -- 检查塔状态
            local status, tResult = getTowerStatus()
            if status == STA_RESULT then
                battleResult = tResult
                layerTimedOut = false
                break
            end

            -- 检查宠物死亡
            if areAllPetsDeadFromBag() then
                petsDied = true
                layerTimedOut = false
                print(string.format("%s  ★ 宠物全部死亡!", TAG))
                break
            end

            if now - lastAutoAttackRefresh >= TOWER_AUTO_ATTACK_REFRESH_INTERVAL then
                if setAutoAttackEnabled(true) then
                    lastAutoAttackRefresh = now
                end
            end

            if now - lastScanTick >= TOWER_SCAN_INTERVAL then
                if currentTargetId then
                    local alive = getMonsterAliveByMonsterId(currentTargetId)
                    if alive ~= true then
                        currentTargetId = nil
                    end
                end
                if not currentTargetId then
                    local _, hrpNow = getCharacterAndRootPart()
                    if hrpNow then
                        currentTargetId = findNearestAliveMonster(hrpNow.Position, TOWER_SEARCH_RADIUS)
                    end
                end
                lastScanTick = now
            end

            if currentTargetId and now - lastAttackTick >= TOWER_ATTACK_COOLDOWN then
                attackMonster(currentTargetId)
                lastAttackTick = now
            end

            frameSafeWait(CFG.LOW_FPS_MODE and 0.25 or 0.2)
        end

        if petsDied then
            print(string.format("%s  宠物死亡，退出塔", TAG))
            return true
        end

        if layerTimedOut then
            warn(string.format("%s  ✗ 第 %d 层等待战斗结果超时", TAG, layer))
            return false, "tower_layer_timeout"
        end

        if battleResult == RESULT_WIN then
            print(string.format("%s  ✓ 第 %d 层胜利，推下一层", TAG, layer))
            frameSafeWait(0.5)
            pcall(function()
                dataPullFunc:InvokeServer("TowerNextLayerChannel")
            end)
            frameSafeWait(1)
        else
            print(string.format("%s  第 %d 层未胜利 (Result=%s)，停止", TAG, layer, tostring(battleResult)))
            return true
        end
    end
    return true
end

-- ============================================================
-- 步骤9: 退出塔
-- ============================================================
local function step09_leaveTower()
    print(string.format("\n%s ========== 步骤9: 退出塔 ==========", TAG))
    local ok, result = doGameRequest(PathTool.TowerSystem.ClientTowerLeave)
    if not ok then
        warn(string.format("%s  ✗ 退出塔失败: %s", TAG, tostring(result)))
        return false, "tower_leave_failed"
    end
    print(string.format("%s  ✓ 退出塔成功", TAG))
    frameSafeWait(2)
    return true
end

-- ============================================================
-- 步骤10: 领取塔奖励
-- ============================================================
local function step10_claimRewards()
    print(string.format("\n%s ========== 步骤10: 领取塔奖励 ==========", TAG))

    -- 每日奖励
    local ok, result = doGameRequest(PathTool.TowerSystem.ClientTakeDailyRewardAll)
    if ok then
        print(string.format("%s  ✓ 每日奖励领取成功", TAG))
    else
        print(string.format("%s  每日奖励: %s", TAG, tostring(result)))
    end
    frameSafeWait(0.5)

    -- 赛季排名奖励
    if PathTool.TowerSystem.ClientTakePrevSeasonRankReward then
        local okR, resultR = doGameRequest(PathTool.TowerSystem.ClientTakePrevSeasonRankReward)
        if okR then
            print(string.format("%s  ✓ 赛季奖励领取成功", TAG))
        else
            print(string.format("%s  赛季奖励: %s", TAG, tostring(resultR)))
        end
    end

    frameSafeWait(0.5)
    claimAchieveRewards()
    return true
end

-- ============================================================
-- 主流程 (带进度保存与断线恢复)
-- ============================================================
local STEPS = {
    { name = "step00_claimServer",      fn = step00_claimServer },
    { name = "step00b_boostAutoCatch",  fn = step00b_boostAutoCatch },
    { name = "step01_redeemCodes",      fn = step01_redeemCodes },
    { name = "step02_activityExchange", fn = step02_activityExchange },
    { name = "step03_hatchEggs",        fn = step03_hatchEggs },
    { name = "step04_equipBest",        fn = step04_equipBest },
    { name = "step05_feedPets",         fn = step05_feedPets },
    { name = "step06_farmDunes",        fn = step06_farmDunes },
    { name = "step07_teleportToCity",   fn = step07_teleportToCity },
    { name = "step08_towerRun",         fn = step08_towerRun },
    { name = "step09_leaveTower",       fn = step09_leaveTower },
    { name = "step10_claimRewards",     fn = step10_claimRewards },
}

local _stepLockName = nil

local function runLockedStep(stepIndex, step)
    if _stepLockName then
        return false, string.format("step_locked_by_%s", tostring(_stepLockName))
    end

    _stepLockName = step.name
    local ok, stepResult, stepReason = pcall(step.fn)
    _stepLockName = nil

    if not ok then
        return false, tostring(stepResult)
    end

    if stepResult == false then
        return false, tostring(stepReason or "step_incomplete")
    end

    saveProgress(stepIndex)
    print(string.format("%s  进度已保存: %d/%d (%s)", TAG, stepIndex, #STEPS, step.name))
    return true
end

local function abortFlow(stepName, reason)
    warn(string.format("%s 步骤锁中止: %s, 原因: %s", TAG, tostring(stepName), tostring(reason)))
    stopClaimHeartbeat()
    pcall(function()
        if CFG.LAN_SERVER_URL then
            local released = releaseToLAN(game.JobId, false)
            if released then
                print(string.format("%s  已释放未完成服务器claim %s", TAG, shortJobId(game.JobId)))
            end
        end
    end)
end

print(string.format("%s ★★★ 自动全流程开始 ★★★", TAG))
local flowStart = tick()
if waitForInitialGameReady(30) then
    print(string.format("%s 启动检测完成，开始启用 FPS Boost", TAG))
else
    warn(string.format("%s 启动等待超时，仍继续尝试启用 FPS Boost", TAG))
end
runFpsBoost()

-- 读取进度
local saved = loadProgress()
local startIdx = 1
if saved and type(saved.step) == "number" and saved.step >= 1 and saved.step < #STEPS then
    startIdx = saved.step + 1 -- 从上次完成的下一步开始
    print(string.format("%s 检测到断线进度: 上次完成第%d步, 从第%d步恢复: %s",
        TAG, saved.step, startIdx, STEPS[startIdx].name))
    local resumeClaimOk, resumeClaimReason = ensureCurrentServerClaimedForResume()
    if not resumeClaimOk then
        warn(string.format("%s  恢复前claim失败，先切换到已claim服务器后再继续当前步骤: %s", TAG, tostring(resumeClaimReason)))
        local rebindOk, rebindReason = step00_claimServer()
        if not rebindOk then
            error(string.format("%s 恢复阶段重新获取claim服务器失败: %s", TAG, tostring(rebindReason)))
        end
        print(string.format("%s  ✓ 已重新绑定claim服务器，继续从第%d步恢复", TAG, startIdx))
    end
else
    print(string.format("%s 全新流程开始 (共%d步)", TAG, #STEPS))
end

-- 循环执行步骤
local allStepsCompleted = true
for i = startIdx, #STEPS do
    local step = STEPS[i]
    local stepOk, stepErr = runLockedStep(i, step)
    if not stepOk then
        allStepsCompleted = false
        abortFlow(step.name, stepErr)
        break
    end
end

if allStepsCompleted then
    -- 全部完成，清除进度
    clearProgress()
    print(string.format("%s 进度文件已标记完成", TAG))

    -- 写入Yummytool标记
    pcall(function()
        if writefile and localPlayer and localPlayer.Name then
            local filename = tostring(localPlayer.Name) .. ".txt"
            writefile(filename, "Yummytool")
            print(string.format("%s ✓ Yummytool标记已写入: %s", TAG, filename))
        else
            warn(string.format("%s ⚠ writefile不可用，跳过标记", TAG))
        end
    end)

    -- 释放服务器claim
    stopClaimHeartbeat()
    pcall(function()
        if CFG.LAN_SERVER_URL then
            releaseToLAN(game.JobId, true)
            print(string.format("%s  ✓ 已释放服务器 %s", TAG, shortJobId(game.JobId)))
        end
    end)
end

local elapsed = math.floor(tick() - flowStart)
if allStepsCompleted then
    print(string.format("\n%s ★★★ 自动全流程完成! 耗时 %d 秒 ★★★", TAG, elapsed))
else
    warn(string.format("\n%s ★★★ 自动全流程已中止，耗时 %d 秒 ★★★", TAG, elapsed))
end
