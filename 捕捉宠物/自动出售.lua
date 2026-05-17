local TARGET_GAME_ID = 98664161516921
if game.PlaceId ~= TARGET_GAME_ID then
    warn(string.format("[FindMonster] 游戏ID不匹配: %d (需要 %d)，脚本已禁用", game.PlaceId, TARGET_GAME_ID))
    _G.__FINDMONSTER_DISABLED = true
    return
end
-- 自动解锁并出售背包里的普通 D/C/B 目标宠
-- 目标: TmplId=100005, SpecialProp=0/nil(普通), Grade=D/C/B
-- 出售前会跳过装备中、预设队伍中、坐骑、仓库、虚拟选中的宠物，并避免把背包卖空。

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local TAG = "[自动卖目标宠]"
local TARGET_PLACE_ID = 98664161516921
local TARGET_TMPL_IDS = {
    [100005] = "Tmpl100005",
}
local AUTO_REPEAT = true
local LOOP_INTERVAL_SECONDS = 15
local BATCH_SIZE = 30
local REQUEST_DELAY_SECONDS = 0.18

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
                warn(TAG .. " 模块路径未找到，请补充路径: " .. tostring(moduleName))
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
        maxWait = maxWait or 30
        local startedAt = os.clock()

        while os.clock() - startedAt < maxWait do
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
    if not ModuleCache then
        return nil
    end

    PetSystem = rawget(ModuleCache, "PetSystem")

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
        return GamePlayer
    end

    pcall(function()
        GamePlayer = ModuleCache.GamePlayer and ModuleCache.GamePlayer.me or nil
    end)

    return GamePlayer
end

local function waitForGamePlayer(maxWait)
    maxWait = maxWait or 30
    local startedAt = os.clock()

    while os.clock() - startedAt < maxWait do
        local gp = getGamePlayer()
        if gp and gp.pet then
            return gp
        end
        task.wait(0.2)
    end

    warn(TAG .. " GamePlayer 或宠物背包未加载")
    return nil
end

local function buildTargetGrades()
    local petGrade = ModuleCache
        and ModuleCache.Constants
        and ModuleCache.Constants.PetGrade

    return {
        [petGrade and petGrade.Grade_2 or 2] = "D",
        [petGrade and petGrade.Grade_3 or 3] = "C",
        [petGrade and petGrade.Grade_4 or 4] = "B",
    }
end

local function getPetId(petItem)
    local petItemId = nil

    pcall(function()
        petItemId = petItem:GetId()
    end)

    return petItemId
end

local function getBagAmount(petData)
    local amount = 0

    pcall(function()
        amount = petData:GetBagAmount()
    end)

    if amount == nil or amount <= 0 then
        pcall(function()
            amount = petData:GetItemAmount()
        end)
    end

    return tonumber(amount) or 0
end

local function getRawSpecialProp(petItem)
    if not petItem then
        return nil, false
    end

    local ok, value = pcall(function()
        return petItem:GetSpecialProp()
    end)
    if ok then
        return value, true
    end

    ok, value = pcall(function()
        local saveData = petItem.GetSaveData and petItem:GetSaveData() or petItem.saveData
        if type(saveData) == "table" then
            if saveData.P ~= nil then
                return saveData.P
            end
            if saveData.SpecialProp ~= nil then
                return saveData.SpecialProp
            end
            if saveData.SpecialProperty ~= nil then
                return saveData.SpecialProperty
            end
            if saveData.Mutation ~= nil then
                return saveData.Mutation
            end
            return nil
        end
    end)

    return value, ok
end

local function isPlainSpecialProp(petItem)
    local specialProp, readable = getRawSpecialProp(petItem)
    if not readable then
        return false
    end

    local numericProp = tonumber(specialProp)
    return specialProp == nil or numericProp == 0
end

local function isTargetPet(petItem, targetGrades)
    if not petItem then
        return false
    end

    local tmplId = nil
    local grade = nil

    pcall(function()
        tmplId = petItem:GetTmplId()
    end)
    pcall(function()
        grade = petItem:GetGrade()
    end)

    return TARGET_TMPL_IDS[tmplId] ~= nil
        and targetGrades[grade] ~= nil
        and isPlainSpecialProp(petItem)
end

local function isSellProtected(gp, petItem)
    local protected = false

    pcall(function()
        if petItem:IsInVault() then
            protected = true
        end
    end)
    pcall(function()
        if petItem:GetEquipedIndex() then
            protected = true
        end
    end)
    pcall(function()
        if petItem:IsInTeam() then
            protected = true
        end
    end)
    pcall(function()
        if gp.pet:GetRideItem() == petItem then
            protected = true
        end
    end)
    pcall(function()
        if petItem:IsVirtualSelected() then
            protected = true
        end
    end)

    return protected
end

local function unlockPet(petItem)
    local petItemId = getPetId(petItem)
    if not petItemId then
        return false, "missing id"
    end

    local locked = false
    pcall(function()
        locked = petItem:IsLock()
    end)

    if not locked then
        return true, "already unlocked"
    end

    local system = getPetSystem()
    if not system or not system.ClientLockPet then
        return false, "PetSystem.ClientLockPet missing"
    end

    local ok, result = pcall(function()
        return system.ClientLockPet(petItemId, false)
    end)

    if ok and result then
        task.wait(REQUEST_DELAY_SECONDS)
        return true, "unlocked"
    end

    return false, tostring(result)
end

local function sellBatch(batch)
    local system = getPetSystem()
    if not system or not system.ClientSellPet then
        return false, "PetSystem.ClientSellPet missing"
    end

    local ok, result = pcall(function()
        if ModuleCache and ModuleCache.ViewUtil and ModuleCache.ViewUtil.DoRequest then
            return ModuleCache.ViewUtil.DoRequest(system.ClientSellPet, batch)
        end
        return system.ClientSellPet(batch)
    end)

    if ok and result then
        task.wait(REQUEST_DELAY_SECONDS)
        return true
    end

    return false, tostring(result)
end

local function collectTargets(gp, targetGrades)
    local targets = {}
    local matched = 0
    local skippedProtected = 0

    pcall(function()
        gp.pet:IterItem(function(petItem)
            if isTargetPet(petItem, targetGrades) then
                matched = matched + 1

                if isSellProtected(gp, petItem) then
                    skippedProtected = skippedProtected + 1
                    return true
                end

                table.insert(targets, petItem)
            end

            return true
        end)
    end)

    return targets, matched, skippedProtected
end

local function runOnce()
    local gp = getGamePlayer()
    if not gp or not gp.pet then
        return false, "GamePlayer 未就绪"
    end

    local targetGrades = buildTargetGrades()
    local targets, matched, skippedProtected = collectTargets(gp, targetGrades)

    if #targets == 0 then
        print(string.format("%s 没有可出售目标，匹配=%d，受保护跳过=%d", TAG, matched, skippedProtected))
        return true
    end

    local unlocked = 0
    local unlockFailed = 0
    local sellIds = {}

    for _, petItem in ipairs(targets) do
        local ok = unlockPet(petItem)
        if ok then
            unlocked = unlocked + 1

            local petItemId = getPetId(petItem)
            if petItemId then
                table.insert(sellIds, petItemId)
            end
        else
            unlockFailed = unlockFailed + 1
        end
    end

    local bagAmount = getBagAmount(gp.pet)
    if bagAmount > 0 and #sellIds >= bagAmount then
        table.remove(sellIds)
        warn(TAG .. " 为避免把背包宠物卖空，已保留 1 只")
    end

    local sold = 0
    local sellFailed = 0

    for startIndex = 1, #sellIds, BATCH_SIZE do
        local batch = {}
        for index = startIndex, math.min(startIndex + BATCH_SIZE - 1, #sellIds) do
            table.insert(batch, sellIds[index])
        end

        local ok, err = sellBatch(batch)
        if ok then
            sold = sold + #batch
        else
            sellFailed = sellFailed + #batch
            warn(string.format("%s 出售失败: %s", TAG, tostring(err)))
        end
    end

    print(string.format(
        "%s 本轮完成: 匹配%d，可处理%d，解锁成功%d，解锁失败%d，出售成功%d，出售失败%d，受保护跳过%d",
        TAG,
        matched,
        #targets,
        unlocked,
        unlockFailed,
        sold,
        sellFailed,
        skippedProtected
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

print(TAG .. " 已启动，目标: 普通 D/C/B TmplId=100005")

if AUTO_REPEAT then
    while true do
        local ok, err = pcall(runOnce)
        if not ok then
            warn(string.format("%s 执行异常: %s", TAG, tostring(err)))
        end
        task.wait(LOOP_INTERVAL_SECONDS)
    end
else
    runOnce()
end
