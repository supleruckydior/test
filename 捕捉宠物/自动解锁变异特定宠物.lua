local TAG = "[自动解锁变异特定宠]"
local TARGET_PLACE_ID = 98664161516921

-- 跟 monster-tracker-local 的自动合成目标保持一致。
local TARGET_TMPL_IDS = {
    [2] = true,
    [3] = true,
    [4] = true,
    [5] = true,
    [6] = true,
    [7] = true,
}

-- 自动合成相关目标等级：E/D/C/B/A。
local TARGET_GRADES = {
    [1] = "E",
    [2] = "D",
    [3] = "C",
    [4] = "B",
    [5] = "A",
}

local AUTO_REPEAT = true
local LOOP_INTERVAL_SECONDS = 8
local REQUEST_DELAY_SECONDS = 0.18
local SKIP_PROTECTED_PETS = true

if not game:IsLoaded() then
    game.Loaded:Wait()
end

if game.PlaceId ~= TARGET_PLACE_ID then
    warn(string.format("%s 游戏ID不匹配: %d (需要 %d)", TAG, game.PlaceId, TARGET_PLACE_ID))
    return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModuleCache = nil
local PetSystem = nil
local GamePlayer = nil
local waitForModulesReady = nil

do
    local missingWarned = {}
    local directRequireModule = nil
    local modulePaths = {
        AnalyticManager = { "CommonLibrary", "Tool", "AnalyticManager" },
        BakaTipSystem = { "CommonLogic", "BakaUtils", "BakaTipSystem" },
        CfgCommonItem = { "CommonConfig", "Common", "CfgCommonItem" },
        CfgPet = { "CommonConfig", "Pet", "CfgPet" },
        CfgPetExpItem = { "CommonConfig", "Pet", "CfgPetExpItem" },
        CfgPetGear = { "CommonConfig", "Pet", "CfgPetGear" },
        CfgPetVault = { "CommonConfig", "Pet", "CfgPetVault" },
        ClientMsgUtil = { "CommonLibrary", "Tool", "ClientMsgUtil" },
        ClientPlayerManager = { "CommonLibrary", "Player", "ClientPlayerManager" },
        Constants = { "CommonLibrary", "Constants" },
        DataPullManager = { "CommonLibrary", "Tool", "DataPullManager" },
        EventSystem = { "CommonLibrary", "Base", "EventSystem" },
        ExchangeSystem = { "CommonLibrary", "Foundation", "ExchangeSystem" },
        FloatRewardListView = { "ClientLogic", "Common", "FloatRewardListView" },
        GamePlayer = { "CommonLogic", "Player", "GamePlayer" },
        GamesIdConfig = { "CommonConfig", "GamesIdConfig" },
        ListenUtil = { "CommonLibrary", "Tool", "ListenUtil" },
        LocalizeKey = { "CommonLibrary", "Tool", "LocalizeKey" },
        Localizer = { "CommonLibrary", "Tool", "Localizer" },
        MgrListener = { "CommonLibrary", "Base", "MgrListener" },
        PetData = { "CommonLogic", "Pet", "PetData" },
        PetGearItem = { "CommonLogic", "Pet", "PetGearItem" },
        PetSpecialPropUtil = { "CommonLogic", "Pet", "PetSpecialPropUtil" },
        PetSystem = { "CommonLogic", "Pet", "PetSystem" },
        RedDotUtil = { "ClientLogic", "View", "RedDotUtil" },
        RemoteManager = { "CommonLibrary", "Tool", "RemoteManager" },
        RewardSystem = { "CommonLibrary", "Foundation", "RewardSystem" },
        Timer = { "CommonLibrary", "Tool", "Timer" },
        Utils = { "CommonLibrary", "Tool", "Utils" },
        ViewUtil = { "ClientLogic", "View", "ViewUtil" },
    }

    local function findPath(parts, timeout)
        local node = ReplicatedStorage
        for _, name in ipairs(parts or {}) do
            node = node:FindFirstChild(name)
            if not node and timeout and timeout > 0 then
                node = node:WaitForChild(name, timeout)
            end
            if not node then
                return nil
            end
        end
        return node
    end

    local function findModuleScript(moduleName)
        local directPath = modulePaths[moduleName]
        local moduleScript = directPath and findPath(directPath, 0) or nil
        if moduleScript and moduleScript:IsA("ModuleScript") then
            return moduleScript
        end

        moduleScript = ReplicatedStorage:FindFirstChild(moduleName, true)
        if moduleScript and moduleScript:IsA("ModuleScript") then
            return moduleScript
        end
        return nil
    end

    local function buildModuleCache()
        if ModuleCache then
            return
        end

        ModuleCache = {}
        local existing = rawget(_G, "PathTool")
        if type(existing) == "table" then
            pcall(function()
                for key, value in pairs(existing) do
                    rawset(ModuleCache, key, value)
                end
            end)
        end

        if rawget(ModuleCache, "IsClient") == nil then
            rawset(ModuleCache, "IsClient", true)
        end
        if rawget(ModuleCache, "IsServer") == nil then
            rawset(ModuleCache, "IsServer", false)
        end

        _G.PathTool = ModuleCache
    end

    local function installCompat()
        buildModuleCache()
        ModuleCache.Require = function(moduleNameOrScript)
            local isModuleScript = false
            pcall(function()
                isModuleScript = typeof(moduleNameOrScript) == "Instance" and moduleNameOrScript:IsA("ModuleScript")
            end)

            if isModuleScript then
                local ok, result = pcall(require, moduleNameOrScript)
                if ok and result then
                    rawset(ModuleCache, moduleNameOrScript.Name, result)
                    return result
                end
                error(TAG .. " CompatRequire " .. tostring(moduleNameOrScript) .. " err:" .. tostring(result))
            end

            local moduleName = tostring(moduleNameOrScript or "")
            if moduleName == "" then
                error(TAG .. " CompatRequire moduleName empty")
            end

            local cached = rawget(ModuleCache, moduleName)
            if cached then
                return cached
            end
            if type(directRequireModule) == "function" then
                local result = directRequireModule(moduleName)
                if result then
                    return result
                end
            end
            error(TAG .. " CompatRequire " .. moduleName .. " failed")
        end

        if type(rawget(ModuleCache, "FindForPath")) ~= "function" then
            ModuleCache.FindForPath = function(root, path)
                local node = root
                for part in tostring(path or ""):gmatch("[^%.]+") do
                    if not node then
                        return nil
                    end
                    node = node:FindFirstChild(part)
                end
                return node
            end
        end
    end

    directRequireModule = function(moduleName)
        installCompat()

        local cached = rawget(ModuleCache, moduleName)
        if cached then
            return cached
        end

        local moduleScript = findModuleScript(moduleName)
        if not moduleScript then
            if not missingWarned[moduleName] then
                missingWarned[moduleName] = true
                warn(TAG .. " 模块路径未找到: " .. tostring(moduleName))
            end
            return nil
        end

        local ok, result = pcall(require, moduleScript)
        if ok and result then
            rawset(ModuleCache, moduleName, result)
            return result
        end

        warn(TAG .. " 直接加载模块失败: " .. tostring(moduleName) .. " err:" .. tostring(result))
        return nil
    end

    local function preloadModules()
        installCompat()
        for _, moduleName in ipairs({
            "Utils",
            "LocalizeKey",
            "GamesIdConfig",
            "RemoteManager",
            "Timer",
            "GamePlayer",
            "ClientPlayerManager",
            "ClientMsgUtil",
            "ListenUtil",
            "DataPullManager",
            "Constants",
            "CfgPet",
            "CfgPetExpItem",
            "CfgCommonItem",
            "CfgPetVault",
            "CfgPetGear",
            "ExchangeSystem",
            "EventSystem",
            "MgrListener",
            "PetData",
            "PetGearItem",
            "RewardSystem",
            "RedDotUtil",
            "FloatRewardListView",
            "BakaTipSystem",
            "PetSpecialPropUtil",
            "ViewUtil",
            "PetSystem",
        }) do
            directRequireModule(moduleName)
        end
    end

    waitForModulesReady = function(maxWait)
        local startedAt = os.clock()
        while os.clock() - startedAt < (tonumber(maxWait) or 30) do
            preloadModules()
            if ModuleCache and rawget(ModuleCache, "PetSystem") and rawget(ModuleCache, "ClientPlayerManager") then
                PetSystem = rawget(ModuleCache, "PetSystem")
                return true
            end
            task.wait(0.2)
        end
        warn(TAG .. " 模块加载失败")
        return false
    end
end

local function getPetSystem()
    if PetSystem then
        return PetSystem
    end
    if not ModuleCache then
        waitForModulesReady(5)
    end
    PetSystem = ModuleCache and rawget(ModuleCache, "PetSystem") or nil
    return PetSystem
end

local function getGamePlayer()
    if GamePlayer then
        return GamePlayer
    end
    if not ModuleCache then
        waitForModulesReady(5)
    end
    if not ModuleCache then
        return nil
    end

    local ok, gp = pcall(function()
        return ModuleCache.ClientPlayerManager:GetGamePlayer()
    end)
    if not ok or not gp then
        ok, gp = pcall(function()
            return ModuleCache.ClientPlayerManager.GetGamePlayer()
        end)
    end
    if ok and gp then
        GamePlayer = gp
        return gp
    end

    pcall(function()
        GamePlayer = ModuleCache.GamePlayer and ModuleCache.GamePlayer.me or nil
    end)
    return GamePlayer
end

local function waitForGamePlayer(maxWait)
    local startedAt = os.clock()
    while os.clock() - startedAt < (tonumber(maxWait) or 30) do
        local gp = getGamePlayer()
        if gp and gp.pet then
            return gp
        end
        task.wait(0.2)
    end
    warn(TAG .. " GamePlayer 或宠物背包未加载")
    return nil
end

local function safeItemCall(item, methodName)
    if not item or type(item[methodName]) ~= "function" then
        return nil
    end
    local ok, result = pcall(function()
        return item[methodName](item)
    end)
    if ok then
        return result
    end
    return nil
end

local function getPetId(item)
    return safeItemCall(item, "GetId")
end

local function getSpecialProp(item)
    local value = safeItemCall(item, "GetSpecialProp")
    if value ~= nil then
        return tonumber(value) or 0
    end

    local saveData = safeItemCall(item, "GetSaveData")
    if type(saveData) ~= "table" then
        saveData = item and item.saveData
    end
    if type(saveData) == "table" then
        return tonumber(saveData.P or saveData.SpecialProp or saveData.SpecialProperty or saveData.Mutation) or 0
    end
    return 0
end

local function isRidePet(gp, item)
    local rideItem = nil
    pcall(function()
        if gp and gp.pet and type(gp.pet.GetRideItem) == "function" then
            rideItem = gp.pet:GetRideItem()
        end
    end)
    if rideItem == item then
        return true
    end
    local rideId = getPetId(rideItem)
    local itemId = getPetId(item)
    return rideId ~= nil and itemId ~= nil and tostring(rideId) == tostring(itemId)
end

local function isProtectedPet(gp, item)
    if safeItemCall(item, "IsInVault") == true then
        return true, "vault"
    end
    if safeItemCall(item, "GetEquipedIndex") ~= nil then
        return true, "equipped"
    end
    if safeItemCall(item, "IsInTeam") == true then
        return true, "team"
    end
    if safeItemCall(item, "IsVirtualSelected") == true then
        return true, "virtual"
    end
    if isRidePet(gp, item) then
        return true, "ride"
    end
    return false, nil
end

local function isTargetMutationPet(item)
    local tmplId = tonumber(safeItemCall(item, "GetTmplId"))
    local grade = tonumber(safeItemCall(item, "GetGrade"))
    if not TARGET_TMPL_IDS[tmplId] or not TARGET_GRADES[grade] then
        return false
    end
    return getSpecialProp(item) ~= 0
end

local function iterPetItems(petData, callback)
    local iterOk = false
    if type(petData.IterBagItem) == "function" then
        local ok = pcall(function()
            petData:IterBagItem(function(item)
                callback(item)
                return true
            end)
        end)
        iterOk = ok
    end
    if not iterOk and type(petData.IterItem) == "function" then
        local ok = pcall(function()
            petData:IterItem(function(item)
                callback(item)
                return true
            end)
        end)
        iterOk = ok
    end
    if not iterOk and type(petData._itemMap) == "table" then
        for _, item in pairs(petData._itemMap) do
            callback(item)
        end
    end
end

local function doClientRequest(func, ...)
    if type(func) ~= "function" then
        return false, "func_missing"
    end
    local args = { ... }
    local results = { pcall(function()
        local unpackArgs = table.unpack or unpack
        if ModuleCache and ModuleCache.ViewUtil and type(ModuleCache.ViewUtil.DoRequest) == "function" then
            return ModuleCache.ViewUtil.DoRequest(func, unpackArgs(args))
        end
        return func(unpackArgs(args))
    end) }
    local ok = table.remove(results, 1)
    if not ok then
        return false, tostring(results[1])
    end
    if results[1] == false then
        return false, tostring(results[2] or "request_failed")
    end
    return true, results[1]
end

local function unlockPet(item)
    local itemId = getPetId(item)
    if not itemId then
        return false, "missing_id"
    end
    if safeItemCall(item, "IsLock") ~= true then
        return true, "already_unlocked"
    end

    local system = getPetSystem()
    if not system or type(system.ClientLockPet) ~= "function" then
        return false, "PetSystem.ClientLockPet_missing"
    end

    local ok, err = doClientRequest(system.ClientLockPet, itemId, false)
    if ok then
        task.wait(REQUEST_DELAY_SECONDS)
        return true, "unlocked"
    end
    return false, err
end

local function collectTargets(gp)
    local targets = {}
    local stats = {
        matched = 0,
        unlockedAlready = 0,
        protected = 0,
        locked = 0,
    }

    iterPetItems(gp.pet, function(item)
        if isTargetMutationPet(item) then
            stats.matched = stats.matched + 1
            local protected = false
            if SKIP_PROTECTED_PETS then
                protected = isProtectedPet(gp, item)
            end
            if protected then
                stats.protected = stats.protected + 1
            elseif safeItemCall(item, "IsLock") == true then
                stats.locked = stats.locked + 1
                table.insert(targets, item)
            else
                stats.unlockedAlready = stats.unlockedAlready + 1
            end
        end
    end)

    return targets, stats
end

local function runOnce()
    local gp = getGamePlayer()
    if not gp or not gp.pet then
        return false, "GamePlayer 未就绪"
    end

    local targets, stats = collectTargets(gp)
    if #targets <= 0 then
        print(string.format(
            "%s 本轮无需要解锁: 匹配变异%d，已解锁%d，受保护跳过%d",
            TAG,
            stats.matched,
            stats.unlockedAlready,
            stats.protected
        ))
        return true
    end

    local unlocked = 0
    local failed = 0
    for _, item in ipairs(targets) do
        local tmplId = tonumber(safeItemCall(item, "GetTmplId")) or 0
        local grade = tonumber(safeItemCall(item, "GetGrade")) or 0
        local itemId = getPetId(item)
        local ok, err = unlockPet(item)
        if ok then
            unlocked = unlocked + 1
            print(string.format(
                "%s 解锁成功 id=%s tmpl=%d grade=%s special=%s",
                TAG,
                tostring(itemId),
                tmplId,
                tostring(TARGET_GRADES[grade] or grade),
                tostring(getSpecialProp(item))
            ))
        else
            failed = failed + 1
            warn(string.format("%s 解锁失败 id=%s err=%s", TAG, tostring(itemId), tostring(err)))
        end
    end

    print(string.format(
        "%s 本轮完成: 匹配变异%d，锁定待解%d，解锁成功%d，失败%d，已解锁%d，受保护跳过%d",
        TAG,
        stats.matched,
        stats.locked,
        unlocked,
        failed,
        stats.unlockedAlready,
        stats.protected
    ))
    return true
end

if not waitForModulesReady(30) then
    return
end
if not getPetSystem() then
    warn(TAG .. " PetSystem 加载失败")
    return
end
if not waitForGamePlayer(30) then
    return
end

print(TAG .. " 已启动，目标: 变异 E/D/C/B/A TmplId=2,3,4,5,6,7")

if AUTO_REPEAT then
    while true do
        local ok, runOk, runErr = pcall(runOnce)
        if not ok then
            warn(string.format("%s 执行异常: %s", TAG, tostring(runOk)))
        elseif runOk ~= true then
            warn(string.format("%s 执行失败: %s", TAG, tostring(runErr or runOk)))
        end
        task.wait(LOOP_INTERVAL_SECONDS)
    end
else
    runOnce()
end
