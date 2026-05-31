local TARGET_GAME_ID = 98664161516921
local TAG = "[TreasureGridPredict]"

if game.PlaceId ~= TARGET_GAME_ID then
    warn(string.format("%s 游戏ID不匹配: %d (需要 %d)，脚本已禁用", TAG, game.PlaceId, TARGET_GAME_ID))
    return
end

-- 挖宝白名单自动开.lua
-- 目的：复刻 Digging Event / TreasureGrid 的服务端地图生成算法，并自动开白名单奖励。
-- 白名单：tmpl 9 + 全部橙品质 + 全部红品质。
-- 注意：默认会调用 ClientOpenCell 自动开白名单格子，会消耗铲子；不会调用 ClientCustomRefresh。

if not game:IsLoaded() then
    game.Loaded:Wait()
end


local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CFG = {
    ACTIVITY_ID = 23,
    INIT_TIMEOUT = 30,
    REQUEST_SYNC_WAIT = 0.75,
    PRINT_GRID = true,
    PRINT_ALL_TREASURES = true,
    AUTO_OPEN_WHITELIST = true,
    OPEN_INTERVAL = 0.05,
    MAX_TREASURES_TO_OPEN = nil, -- nil=开完全部白名单宝藏；数字=最多开几个白名单宝藏
    STOP_ON_SYNC_MISMATCH = true,
    REWARD_WHITELIST_TMPL_IDS = {
        [9] = true,
        [10] = true,
        [11] = true,
        [12] = true,
        [13] = true,
        [14] = true,
        [15] = true,
        [16] = true,
        [17] = true,
        [18] = true,
        [19] = true,
        [20] = true,
        [21] = true,
        [22] = true,
        [23] = true,
        [24] = true,
    },
}

local MODULE_PATHS = {
    Constants = { "CommonLibrary", "Constants" },
    DataPullManager = { "CommonLibrary", "Tool", "DataPullManager" },
    EventSystem = { "CommonLibrary", "Base", "EventSystem" },
    ExchangeSystem = { "CommonLibrary", "Foundation", "ExchangeSystem" },
    FloatRewardListView = { "ClientLogic", "Common", "FloatRewardListView" },
    ListenUtil = { "CommonLibrary", "Tool", "ListenUtil" },
    LocalizeKey = { "CommonLibrary", "Tool", "LocalizeKey" },
    LogicNumber = { "CommonLogic", "Fight", "Logic", "LogicNumber" },
    MessageSystem = { "CommonLibrary", "Base", "MessageSystem" },
    RedDotUtil = { "ClientLogic", "View", "RedDotUtil" },
    RemoteManager = { "CommonLibrary", "Tool", "RemoteManager" },
    ResourceConfig = { "CommonConfig", "ResourceConfig" },
    RewardModeUtil = { "CommonLibrary", "Foundation", "RewardModeUtil" },
    RewardSystemPlus = { "CommonLogic", "Foundation", "RewardSystemPlus" },
    Utils = { "CommonLibrary", "Tool", "Utils" },
    ActivityBaseAccumulatedTimeData = { "CommonLogic", "Activity", "ActivityBaseAccumulatedTimeData" },
    ActivityBattlePassTaskData = { "CommonLogic", "Activity", "ActivityBattlePassTaskData" },
    ActivityData = { "CommonLogic", "Activity", "ActivityData" },
    ActivityExchangeData = { "CommonLogic", "Activity", "ActivityExchangeData" },
    ActivityOnlineTimeDayData = { "CommonLogic", "Activity", "ActivityOnlineTimeDayData" },
    ActivityPrizePullData = { "CommonLogic", "Activity", "ActivityPrizePullData" },
    ActivityRollRewardData = { "CommonLogic", "Activity", "ActivityRollRewardData" },
    ActivityShopData = { "CommonLogic", "Activity", "ActivityShopData" },
    ActivitySinglePurchaseShopData = { "CommonLogic", "Activity", "ActivitySinglePurchaseShopData" },
    ActivitySummerTaskProData = { "CommonLogic", "Activity", "ActivitySummerTaskProData" },
    ActivitySummonData = { "CommonLogic", "Activity", "ActivitySummonData" },
    ActivityTaskGroupData = { "CommonLogic", "Activity", "ActivityTaskGroupData" },
    ActivityTreasureGridSystem = { "CommonLogic", "Activity", "ActivityTreasureGridSystem" },
    ActivityTreasureGridData = { "CommonLogic", "Activity", "ActivityTreasureGridData" },
    ActivityTreasureHuntData = { "CommonLogic", "Activity", "ActivityTreasureHuntData" },
    ActivityValentinesRoseGiftData = { "CommonLogic", "Activity", "ActivityValentinesRoseGiftData" },
    ClientPlayerManager = { "CommonLibrary", "Player", "ClientPlayerManager" },
    CfgActivity = { "CommonConfig", "Activity", "CfgActivity" },
    CfgActivityBattlePassTask = { "CommonConfig", "Activity", "CfgActivityBattlePassTask" },
    CfgActivityExchange = { "CommonConfig", "Activity", "CfgActivityExchange" },
    CfgActivityGoodsShop = { "CommonConfig", "Activity", "CfgActivityGoodsShop" },
    CfgActivityGoodsShop1 = { "CommonConfig", "Activity", "CfgActivityGoodsShop1" },
    CfgActivityOnlineTimeDay = { "CommonConfig", "Activity", "CfgActivityOnlineTimeDay" },
    CfgActivityOnlineTimeDay1 = { "CommonConfig", "Activity", "CfgActivityOnlineTimeDay1" },
    CfgActivityPrizePull = { "CommonConfig", "Activity", "CfgActivityPrizePull" },
    CfgActivityRollReward = { "CommonConfig", "Activity", "CfgActivityRollReward" },
    CfgActivityShop = { "CommonConfig", "Activity", "CfgActivityShop" },
    CfgActivityShop1 = { "CommonConfig", "Activity", "CfgActivityShop1" },
    CfgActivitySinglePurchaseShop = { "CommonConfig", "Activity", "CfgActivitySinglePurchaseShop" },
    CfgActivitySummerTaskPro = { "CommonConfig", "Activity", "CfgActivitySummerTaskPro" },
    CfgActivitySummerTaskPro1 = { "CommonConfig", "Activity", "CfgActivitySummerTaskPro1" },
    CfgActivitySummon = { "CommonConfig", "Activity", "CfgActivitySummon" },
    CfgActivityTaskGroup = { "CommonConfig", "Activity", "CfgActivityTaskGroup" },
    CfgActivityTeleport = { "CommonConfig", "Activity", "CfgActivityTeleport" },
    CfgActivityTeleport1 = { "CommonConfig", "Activity", "CfgActivityTeleport1" },
    CfgActivityTreasureGrid = { "CommonConfig", "Activity", "CfgActivityTreasureGrid" },
    CfgActivityTreasureHunt = { "CommonConfig", "Activity", "CfgActivityTreasureHunt" },
    CfgActivityValentinesRoseGift = { "CommonConfig", "Activity", "CfgActivityValentinesRoseGift" },
    CfgCommonItem = { "CommonConfig", "Common", "CfgCommonItem" },
    CfgEgg = { "CommonConfig", "Egg", "CfgEgg" },
    CfgPetExpItem = { "CommonConfig", "Pet", "CfgPetExpItem" },
    CfgTreasureBox = { "CommonConfig", "Common", "CfgTreasureBox" },
    RewardSystem = { "CommonLibrary", "Foundation", "RewardSystem" },
    ViewUtil = { "ClientLogic", "View", "ViewUtil" },
}

local PRELOAD_MODULES = {
    "Constants",
    "ResourceConfig",
    "LocalizeKey",
    "EventSystem",
    "MessageSystem",
    "RemoteManager",
    "Utils",
    "LogicNumber",
    "ListenUtil",
    "ExchangeSystem",
    "RewardModeUtil",
    "RewardSystemPlus",
    "DataPullManager",
    "CfgActivityShop",
    "CfgActivityShop1",
    "CfgActivityGoodsShop",
    "CfgActivityGoodsShop1",
    "CfgActivityOnlineTimeDay",
    "CfgActivityOnlineTimeDay1",
    "CfgActivityPrizePull",
    "CfgActivityRollReward",
    "CfgActivitySinglePurchaseShop",
    "CfgActivitySummerTaskPro",
    "CfgActivitySummerTaskPro1",
    "CfgActivitySummon",
    "CfgActivityTaskGroup",
    "CfgActivityTeleport",
    "CfgActivityTeleport1",
    "CfgActivityExchange",
    "CfgActivityTreasureGrid",
    "CfgActivityTreasureHunt",
    "CfgActivityValentinesRoseGift",
    "CfgActivityBattlePassTask",
    "CfgActivity",
    "ActivityBaseAccumulatedTimeData",
    "ActivityShopData",
    "ActivityOnlineTimeDayData",
    "ActivitySummonData",
    "ActivityTreasureHuntData",
    "ActivityTaskGroupData",
    "ActivityBattlePassTaskData",
    "ActivitySummerTaskProData",
    "ActivityValentinesRoseGiftData",
    "ActivityExchangeData",
    "ActivityRollRewardData",
    "ActivitySinglePurchaseShopData",
    "ActivityPrizePullData",
    "ActivityTreasureGridData",
    "ActivityData",
    "FloatRewardListView",
    "RedDotUtil",
    "ActivityTreasureGridSystem",
    "RewardSystem",
    "ViewUtil",
    "ClientPlayerManager",
}

local PathTool = rawget(_G, "PathTool")
local moduleCache = {}
local moduleLoading = {}
local missingModuleWarned = {}
local directRequireInstalled = false

local function log(fmt, ...)
    print(string.format("%s " .. fmt, TAG, ...))
end

local function warnf(fmt, ...)
    warn(string.format("%s " .. fmt, TAG, ...))
end

local function findPath(root, parts)
    local node = root
    for _, name in ipairs(parts) do
        if not node then
            return nil
        end
        node = node:FindFirstChild(name)
    end
    return node
end

local function waitForPathTool(timeout)
    local started = os.clock()
    while os.clock() - started < timeout do
        local globalPathTool = rawget(_G, "PathTool")
        if type(globalPathTool) == "table" then
            PathTool = globalPathTool
            return PathTool
        end

        local node = findPath(ReplicatedStorage, { "CommonLibrary", "Tool", "PathTool" })
        if node and node:IsA("ModuleScript") then
            local ok, result = pcall(require, node)
            if ok and type(result) == "table" then
                PathTool = result
                _G.PathTool = result
                return PathTool
            end
        end

        task.wait(0.1)
    end

    error(string.format("%s PathTool 未找到，请确认游戏已加载完成", TAG))
end

local function getRawPathToolModule(name)
    if type(PathTool) ~= "table" then
        return nil
    end

    local ok, value = pcall(rawget, PathTool, name)
    if ok then
        return value
    end

    return nil
end

local function cacheModule(name, result)
    moduleCache[name] = result
    if type(PathTool) == "table" then
        pcall(rawset, PathTool, name, result)
    end
    return result
end

local function isModuleScript(value)
    local ok, result = pcall(function()
        return typeof(value) == "Instance" and value:IsA("ModuleScript")
    end)
    return ok and result
end

local function findModuleScriptByName(moduleName)
    local found = ReplicatedStorage:FindFirstChild(moduleName, true)
    if found and found:IsA("ModuleScript") then
        return found
    end
    return nil
end

local function directRequireModule(moduleNameOrScript, directPathParts)
    local moduleName = nil
    local moduleScript = nil

    if isModuleScript(moduleNameOrScript) then
        moduleScript = moduleNameOrScript
        moduleName = moduleScript.Name
    else
        moduleName = tostring(moduleNameOrScript or "")
        if moduleName == "" then
            return nil, "module_name_empty"
        end

        local rawModule = getRawPathToolModule(moduleName)
        if rawModule ~= nil then
            return cacheModule(moduleName, rawModule), nil
        end

        if moduleCache[moduleName] ~= nil then
            return moduleCache[moduleName] or nil, "previous_require_failed"
        end

        local path = directPathParts or MODULE_PATHS[moduleName]
        if path then
            moduleScript = findPath(ReplicatedStorage, path)
        end
        moduleScript = moduleScript or findModuleScriptByName(moduleName)
    end

    if not moduleScript then
        if not missingModuleWarned[moduleName] then
            missingModuleWarned[moduleName] = true
            warnf("模块路径不存在，请补充直接路径: %s", tostring(moduleName))
        end
        moduleCache[moduleName] = false
        return nil, "module_not_found"
    end

    if moduleLoading[moduleName] then
        local started = os.clock()
        while moduleLoading[moduleName] and os.clock() - started < 10 do
            task.wait(0.05)
        end

        local loaded = getRawPathToolModule(moduleName) or moduleCache[moduleName]
        if loaded then
            return loaded, nil
        end
        return nil, "module_loading_timeout"
    end

    moduleLoading[moduleName] = true
    local ok, result = pcall(require, moduleScript)
    moduleLoading[moduleName] = nil

    if ok and result ~= nil then
        return cacheModule(moduleName, result), nil
    end

    moduleCache[moduleName] = false
    return nil, tostring(result)
end

local function installDirectRequireFallback()
    if directRequireInstalled then
        return
    end

    local existingPathTool = PathTool
    moduleCache = {}

    if type(existingPathTool) == "table" then
        pcall(function()
            for key, value in pairs(existingPathTool) do
                rawset(moduleCache, key, value)
            end
        end)
    end

    PathTool = moduleCache
    _G.PathTool = moduleCache
    directRequireInstalled = true

    rawset(moduleCache, "_TreasureGridDirectRequireInstalled", true)
    rawset(moduleCache, "Require", function(moduleNameOrScript)
        local result, err = directRequireModule(moduleNameOrScript)
        if result ~= nil then
            return result
        end
        error(string.format("%s direct require %s failed: %s", TAG, tostring(moduleNameOrScript), tostring(err)))
    end)

    if type(rawget(moduleCache, "FindForPath")) ~= "function" then
        rawset(moduleCache, "FindForPath", function(root, path)
            local node = root
            for part in tostring(path or ""):gmatch("[^%.]+") do
                if not node then
                    return nil
                end
                node = node:FindFirstChild(part)
            end
            return node
        end)
    end
end

local function getModule(name)
    local rawModule = getRawPathToolModule(name)
    if rawModule ~= nil then
        return cacheModule(name, rawModule)
    end

    if moduleCache[name] ~= nil then
        return moduleCache[name] or nil
    end

    local result, err = directRequireModule(name)
    if result ~= nil then
        return result
    end

    warnf("require %s 失败: %s", name, tostring(err))
    return nil
end

local function preloadDirectModules()
    for _, name in ipairs(PRELOAD_MODULES) do
        getModule(name)
    end
end

local function waitForGamePlayer(timeout)
    local started = os.clock()
    while os.clock() - started < timeout do
        local clientPlayerManager = getModule("ClientPlayerManager")
        if clientPlayerManager and type(clientPlayerManager.GetGamePlayer) == "function" then
            local ok, gamePlayer = pcall(clientPlayerManager.GetGamePlayer)
            if ok and gamePlayer then
                return gamePlayer
            end
        end

        local rawClientPlayerManager = getRawPathToolModule("ClientPlayerManager")
        if rawClientPlayerManager and type(rawClientPlayerManager.GetGamePlayer) == "function" then
            local ok, gamePlayer = pcall(rawClientPlayerManager.GetGamePlayer)
            if ok and gamePlayer then
                return gamePlayer
            end
        end

        task.wait(0.1)
    end

    error(string.format("%s GamePlayer 未找到，请确认角色数据初始化完成", TAG))
end

local function getServerTime()
    local utils = getModule("Utils") or getRawPathToolModule("Utils")
    if utils and type(utils.GetServerTime) == "function" then
        local ok, value = pcall(utils.GetServerTime)
        if ok and value ~= nil then
            return tonumber(value) or 0
        end
    end

    local ok, value = pcall(function()
        return Workspace:GetServerTimeNow()
    end)
    if ok and value ~= nil then
        return tonumber(value) or 0
    end

    return os.time()
end

local function safeActivityCall(gamePlayer, methodName, ...)
    if not gamePlayer or not gamePlayer.activity then
        return false, "activity_missing"
    end

    local fn = gamePlayer.activity[methodName]
    if type(fn) ~= "function" then
        return false, "method_missing"
    end

    return pcall(fn, gamePlayer.activity, ...)
end

local function getActivityConfig(activityId)
    local activityData = getModule("ActivityData")
    if activityData and type(activityData.GetConfig) == "function" then
        local ok, config = pcall(activityData.GetConfig, activityId)
        if ok and config then
            return config
        end
    end

    local cfgActivity = getModule("CfgActivity")
    if cfgActivity and cfgActivity.TmplMap then
        return cfgActivity.TmplMap[activityId]
    end

    return nil
end

local function ensureActivityTimes(activityConfig)
    if activityConfig.StartTime and activityConfig.EndTime then
        return
    end

    local utils = getModule("Utils") or getRawPathToolModule("Utils")
    if not utils or type(utils.GetServerTimeFromStr) ~= "function" then
        return
    end

    if not activityConfig.StartTime and activityConfig.StartDate then
        local ok, value = pcall(utils.GetServerTimeFromStr, activityConfig.StartDate)
        if ok then
            activityConfig.StartTime = value
        end
    end

    if not activityConfig.EndTime and activityConfig.EndDate then
        local ok, value = pcall(utils.GetServerTimeFromStr, activityConfig.EndDate)
        if ok then
            activityConfig.EndTime = value
        end
    end
end

local function calcRefreshTick(activityConfig, effectConfig, serverTime)
    local sum = serverTime - activityConfig.StartTime
    local refreshTimes = effectConfig.DailyRefreshTime
    local span = effectConfig.DailyRefreshSpan or 86400
    local cycleCount = math.floor(sum / span)

    if cycleCount > 0 then
        sum = sum - cycleCount * span
    end

    local cycleStart = serverTime - sum
    local currentTick = nil
    local nextTick = nil

    for index, refreshTime in ipairs(refreshTimes) do
        if sum < refreshTime then
            break
        end

        local nextRefreshTime = if index < #refreshTimes then refreshTimes[index + 1] else span
        if sum < nextRefreshTime then
            currentTick = cycleStart + refreshTime
            nextTick = cycleStart + nextRefreshTime
            break
        end
    end

    if currentTick == nil then
        currentTick = cycleStart - span + refreshTimes[#refreshTimes]
        nextTick = cycleStart + refreshTimes[1]
    end

    return currentTick, nextTick
end

local function generateUniformChests(colCount, rowCount, sizeCounts, random)
    local occupied = {}
    local densityWeight = {}
    local neighborWeight = {}

    for row = 1, rowCount do
        occupied[row] = {}
        densityWeight[row] = {}
        neighborWeight[row] = {}
        for col = 1, colCount do
            occupied[row][col] = false
            densityWeight[row][col] = 0
            neighborWeight[row][col] = 0
        end
    end

    for size, count in pairs(sizeCounts) do
        if size > 0 and count > 0 then
            local maxStartRow = rowCount - size + 1
            local maxStartCol = colCount - size + 1
            if maxStartRow < 1 or maxStartCol < 1 then
                warnf("宝箱尺寸 %dx%d 超出地图大小", size, size)
                return nil, nil
            end

            for row = 1, rowCount do
                for col = 1, colCount do
                    local minRow = math.max(1, row - size + 1)
                    local maxRow = math.min(row, maxStartRow)
                    local minCol = math.max(1, col - size + 1)
                    local maxCol = math.min(col, maxStartCol)
                    densityWeight[row][col] += math.max(0, maxRow - minRow + 1) * math.max(0, maxCol - minCol + 1) * count
                end
            end
        end
    end

    local sizes = {}
    for size, count in pairs(sizeCounts) do
        for _ = 1, count do
            table.insert(sizes, size)
        end
    end

    table.sort(sizes, function(a, b)
        return b < a
    end)

    local function getMaxInscribedSquare()
        local dp = {}
        local maxSize = 0

        for row = 1, rowCount do
            dp[row] = {}
            for col = 1, colCount do
                if occupied[row][col] then
                    dp[row][col] = 0
                else
                    local value = if row == 1 or col == 1 then 1 else math.min(dp[row - 1][col], dp[row][col - 1], dp[row - 1][col - 1]) + 1
                    dp[row][col] = value
                    if maxSize < value then
                        maxSize = value
                    end
                end
            end
        end

        return maxSize
    end

    local placements = {}

    for index, size in ipairs(sizes) do
        local maxStartCol = colCount - size + 1
        local nextSize = 0

        for nextIndex = index + 1, #sizes do
            nextSize = sizes[nextIndex]
            break
        end

        local candidates = {}

        for row = 1, rowCount - size + 1 do
            for col = 1, maxStartCol do
                local blocked = false
                local weight = 0

                for testRow = row, row + size - 1 do
                    for testCol = col, col + size - 1 do
                        if occupied[testRow][testCol] then
                            blocked = true
                            break
                        end

                        weight += 1 / (densityWeight[testRow][testCol] + neighborWeight[testRow][testCol] + 1)
                    end

                    if blocked then
                        break
                    end
                end

                if not blocked then
                    table.insert(candidates, {
                        r = row,
                        c = col,
                        weight = weight,
                    })
                end
            end
        end

        if #candidates == 0 then
            warnf("地图总空间不足，无法放置 size=%d", size)
            return nil, nil
        end

        local selected = nil
        while #candidates > 0 do
            local weightSum = 0
            for _, candidate in ipairs(candidates) do
                weightSum += candidate.weight
            end

            local roll = random:NextNumber() * weightSum
            local running = 0
            local selectedIndex = 0

            for candidateIndex, candidate in ipairs(candidates) do
                running += candidate.weight
                if roll <= running then
                    selectedIndex = candidateIndex
                    break
                end
            end

            if selectedIndex == 0 then
                selectedIndex = #candidates
            end

            local candidate = candidates[selectedIndex]
            local canUse = true

            if nextSize > 0 then
                for row = candidate.r, candidate.r + size - 1 do
                    for col = candidate.c, candidate.c + size - 1 do
                        occupied[row][col] = true
                    end
                end

                if getMaxInscribedSquare() < nextSize then
                    canUse = false
                end

                for row = candidate.r, candidate.r + size - 1 do
                    for col = candidate.c, candidate.c + size - 1 do
                        occupied[row][col] = false
                    end
                end
            end

            if canUse then
                selected = candidate
                break
            end

            table.remove(candidates, selectedIndex)
        end

        if not selected then
            warnf("候选耗尽，无法放置 size=%d", size)
            return nil, nil
        end

        table.insert(placements, {
            r = selected.r,
            c = selected.c,
            size = size,
        })

        for row = selected.r, selected.r + size - 1 do
            for col = selected.c, selected.c + size - 1 do
                occupied[row][col] = true

                for deltaRow = -1, 1 do
                    for deltaCol = -1, 1 do
                        local nearRow = row + deltaRow
                        local nearCol = col + deltaCol
                        if nearRow >= 1 and nearRow <= rowCount and nearCol >= 1 and nearCol <= colCount then
                            neighborWeight[nearRow][nearCol] += 2
                        end
                    end
                end
            end
        end
    end

    return occupied, placements
end

local function buildTreasureMap(activityId, gamePlayer, activityConfig, effectConfig)
    local customSeed = nil
    local okSeed, seedValue = safeActivityCall(gamePlayer, "TreasureGridGetCustomRefreshSeed", activityId)
    if okSeed then
        customSeed = seedValue
    end

    local refreshTick, nextRefreshTick = calcRefreshTick(activityConfig, effectConfig, getServerTime())
    local userId = Players.LocalPlayer and Players.LocalPlayer.UserId or 0
    if gamePlayer and type(gamePlayer.GetUserId) == "function" then
        local okUserId, result = pcall(gamePlayer.GetUserId, gamePlayer)
        if okUserId and tonumber(result) then
            userId = tonumber(result)
        end
    end

    local rawSeed = customSeed or (refreshTick + userId % 100000)
    local rewardRandom = Random.new(rawSeed % 1000000)
    local rewardList = {}
    local rewardSystem = getModule("RewardSystem")

    if not rewardSystem or type(rewardSystem.__DoRewardGroup) ~= "function" then
        error(string.format("%s RewardSystem.__DoRewardGroup 不可用，无法复刻奖励抽取", TAG))
    end

    local okReward, rewardErr = pcall(function()
        rewardSystem.__DoRewardGroup(nil, effectConfig.Rand, rewardList, rewardRandom, false, true)
    end)
    if not okReward then
        error(string.format("%s 奖励抽取失败: %s", TAG, tostring(rewardErr)))
    end

    local sizeCounts = {}
    local tmplIds = {}
    for _, reward in ipairs(rewardList) do
        local tmplId = reward.TmplId
        if tmplId then
            local template = effectConfig.Tmpls[tmplId]
            if template then
                sizeCounts[template.Size] = (sizeCounts[template.Size] or 0) + 1
                table.insert(tmplIds, tmplId)
            end
        end
    end

    local placementSeed = rewardRandom:NextInteger(1, 1000000)
    local _, placements = generateUniformChests(effectConfig.MapColCount, effectConfig.MapRowCount, sizeCounts, Random.new(placementSeed))
    if not placements then
        return {}, {
            customSeed = customSeed,
            rawSeed = rawSeed,
            rewardSeed = rawSeed % 1000000,
            placementSeed = placementSeed,
            refreshTick = refreshTick,
            nextRefreshTick = nextRefreshTick,
        }
    end

    table.sort(tmplIds, function(a, b)
        return effectConfig.Tmpls[a].Size > effectConfig.Tmpls[b].Size
    end)

    local treasureMap = {}
    for index, placement in ipairs(placements) do
        local tmplId = tmplIds[index]
        if tmplId then
            treasureMap[tmplId] = {
                TmplId = tmplId,
                Config = effectConfig.Tmpls[tmplId],
                Row = placement.r,
                Col = placement.c,
            }
        end
    end

    return treasureMap, {
        customSeed = customSeed,
        rawSeed = rawSeed,
        rewardSeed = rawSeed % 1000000,
        placementSeed = placementSeed,
        refreshTick = refreshTick,
        nextRefreshTick = nextRefreshTick,
    }
end

local function getQualityName(quality)
    local constants = getModule("Constants") or getRawPathToolModule("Constants")
    local itemQuality = constants and constants.ItemQuality
    if type(itemQuality) == "table" then
        for name, value in pairs(itemQuality) do
            if value == quality then
                return tostring(name)
            end
        end
    end

    return tostring(quality)
end

local function getTemplateName(moduleName, tmplId)
    local module = getModule(moduleName)
    local tmpl = module and module.Tmpls and module.Tmpls[tmplId]
    if tmpl and tmpl.Name then
        return tostring(tmpl.Name)
    end

    return nil
end

local function formatReward(reward)
    if type(reward) ~= "table" then
        return tostring(reward)
    end

    local count = reward.Count and (" x" .. tostring(reward.Count)) or ""

    if reward.RewardRes == "CommonItem" then
        return string.format("CommonItem#%s %s%s", tostring(reward.TmplId), getTemplateName("CfgCommonItem", reward.TmplId) or "", count)
    end

    if reward.RewardRes == "PetExpItem" then
        return string.format("PetExpItem#%s %s%s", tostring(reward.TmplId), getTemplateName("CfgPetExpItem", reward.TmplId) or "", count)
    end

    if reward.RewardRes == "Egg" then
        return string.format("Egg#%s %s%s", tostring(reward.TmplId), getTemplateName("CfgEgg", reward.TmplId) or "", count)
    end

    if reward.RewardRes == "TreasureBox" then
        return string.format("TreasureBox#%s %s%s", tostring(reward.TmplId), getTemplateName("CfgTreasureBox", reward.TmplId) or "", count)
    end

    if reward.RewardRes == "Value" then
        return string.format("Value %s%s", tostring(reward.ValueType), count)
    end

    return string.format("%s#%s%s", tostring(reward.RewardRes), tostring(reward.TmplId), count)
end

local function formatCells(row, col, size)
    if size == 1 then
        return string.format("(%d,%d)", row, col)
    end

    local cells = {}
    for r = row, row + size - 1 do
        for c = col, col + size - 1 do
            table.insert(cells, string.format("(%d,%d)", r, c))
        end
    end

    return table.concat(cells, " ")
end

local function isAnyCellOpened(gamePlayer, activityId, treasure)
    local size = treasure.Config.Size
    for row = treasure.Row, treasure.Row + size - 1 do
        for col = treasure.Col, treasure.Col + size - 1 do
            local ok, opened = safeActivityCall(gamePlayer, "TreasureGridIsCellOpened", activityId, row, col)
            if ok and opened then
                return true
            end
        end
    end

    return false
end

local function isRewardClaimed(gamePlayer, activityId, tmplId)
    local ok, claimed = safeActivityCall(gamePlayer, "TreasureGridIsRewardClaimed", activityId, tmplId)
    return ok and claimed == true
end

local function getCurrencyAmount(gamePlayer, valueType)
    if not gamePlayer then
        return nil
    end

    if type(gamePlayer.GetValue) == "function" then
        local ok, value = pcall(gamePlayer.GetValue, gamePlayer, valueType)
        if ok and value ~= nil then
            return tonumber(tostring(value))
        end
    end

    if gamePlayer.saveData and gamePlayer.saveData.values then
        local value = gamePlayer.saveData.values[valueType]
        if value ~= nil then
            return tonumber(tostring(value))
        end
    end

    return nil
end

local function openTreasureCell(activityId, row, col)
    local system = getModule("ActivityTreasureGridSystem")
    if not system or type(system.ClientOpenCell) ~= "function" then
        return false, "ActivityTreasureGridSystem.ClientOpenCell missing"
    end

    local viewUtil = getModule("ViewUtil")
    local ok, result
    if viewUtil and type(viewUtil.DoRequest) == "function" then
        ok, result = pcall(viewUtil.DoRequest, system.ClientOpenCell, activityId, row, col)
    else
        ok, result = pcall(system.ClientOpenCell, activityId, row, col)
    end

    if not ok then
        return false, result
    end

    return result ~= false and result ~= nil, result
end

local function getSyncedRevealedMap(gamePlayer, activityId)
    local ok, treasureMap = safeActivityCall(gamePlayer, "TreasureGridGetTreasureMap", activityId)
    if ok and type(treasureMap) == "table" then
        return treasureMap
    end

    return nil
end

local function compareWithSyncedRevealedMap(predictedMap, syncedMap)
    if type(syncedMap) ~= "table" then
        log("已露出宝藏校验: 暂无客户端同步地图可对比")
        return nil
    end

    local checked = 0
    local mismatch = 0

    for _, syncedTreasure in pairs(syncedMap) do
        if type(syncedTreasure) == "table" and syncedTreasure.TmplId then
            checked += 1
            local predicted = predictedMap[syncedTreasure.TmplId]
            if not predicted or predicted.Row ~= syncedTreasure.Row or predicted.Col ~= syncedTreasure.Col then
                mismatch += 1
                warnf(
                    "已露出宝藏不匹配: tmpl=%s synced=(%s,%s) predicted=(%s,%s)",
                    tostring(syncedTreasure.TmplId),
                    tostring(syncedTreasure.Row),
                    tostring(syncedTreasure.Col),
                    predicted and tostring(predicted.Row) or "nil",
                    predicted and tostring(predicted.Col) or "nil"
                )
            end
        end
    end

    if checked == 0 then
        log("已露出宝藏校验: 当前还没有任何已露出的宝藏")
        return nil
    elseif mismatch == 0 then
        log("已露出宝藏校验: %d 项匹配", checked)
        return true
    else
        warnf("已露出宝藏校验: %d/%d 项不匹配，预测结果需要谨慎使用", mismatch, checked)
        return false
    end
end

local function sortedTreasureList(treasureMap, whitelistSet, highQualitySet)
    local list = {}
    for _, treasure in pairs(treasureMap) do
        table.insert(list, treasure)
    end

    table.sort(list, function(a, b)
        local aWhitelisted = whitelistSet[a.TmplId] == true
        local bWhitelisted = whitelistSet[b.TmplId] == true
        if aWhitelisted ~= bWhitelisted then
            return aWhitelisted
        end

        local aHigh = highQualitySet[a.Config.Quality] == true
        local bHigh = highQualitySet[b.Config.Quality] == true
        if aHigh ~= bHigh then
            return aHigh
        end
        if a.Config.Size ~= b.Config.Size then
            return a.Config.Size > b.Config.Size
        end
        return a.TmplId < b.TmplId
    end)

    return list
end

local function printGrid(treasureList, whitelistSet, highQualitySet, rowCount, colCount)
    local grid = {}
    for row = 1, rowCount do
        grid[row] = {}
        for col = 1, colCount do
            grid[row][col] = "."
        end
    end

    for _, treasure in ipairs(treasureList) do
        local mark = "."
        if whitelistSet[treasure.TmplId] then
            mark = "W"
        elseif highQualitySet[treasure.Config.Quality] then
            mark = "R"
        elseif treasure.Config.Quality then
            local qualityName = getQualityName(treasure.Config.Quality)
            mark = string.sub(qualityName, 1, 1)
        end

        for row = treasure.Row, treasure.Row + treasure.Config.Size - 1 do
            for col = treasure.Col, treasure.Col + treasure.Config.Size - 1 do
                grid[row][col] = mark
            end
        end
    end

    log("地图预览: W=白名单, R=红品质非白名单, .=空格；坐标格式为 row,col")
    for row = 1, rowCount do
        log("%02d: %s", row, table.concat(grid[row], " "))
    end
end

local function autoOpenWhitelistedTreasures(gamePlayer, activityId, effectConfig, treasureList, whitelistSet)
    if not CFG.AUTO_OPEN_WHITELIST then
        log("自动开格: AUTO_OPEN_WHITELIST=false，跳过")
        return
    end

    local cost = effectConfig.OpenCellCost or {}
    local costValueType = cost.ValueType
    local costCount = tonumber(cost.Count) or 1
    local openedCells = 0
    local openedTreasures = 0

    log("===== 自动开白名单奖励 =====")
    for _, treasure in ipairs(treasureList) do
        if not whitelistSet[treasure.TmplId] then
            continue
        end

        if CFG.MAX_TREASURES_TO_OPEN and openedTreasures >= CFG.MAX_TREASURES_TO_OPEN then
            log("达到 MAX_TREASURES_TO_OPEN=%d，停止", CFG.MAX_TREASURES_TO_OPEN)
            break
        end

        if isRewardClaimed(gamePlayer, activityId, treasure.TmplId) then
            log("跳过已领取: tmpl=%s topLeft=(%d,%d)", tostring(treasure.TmplId), treasure.Row, treasure.Col)
            continue
        end

        local treasureOpenedAnyCell = false
        local treasureOpenedNewCell = false
        local stopped = false

        log(
            "准备开: tmpl=%s size=%dx%d topLeft=(%d,%d) reward=%s",
            tostring(treasure.TmplId),
            treasure.Config.Size,
            treasure.Config.Size,
            treasure.Row,
            treasure.Col,
            formatReward(treasure.Config.Reward)
        )

        for row = treasure.Row, treasure.Row + treasure.Config.Size - 1 do
            if stopped then
                break
            end

            for col = treasure.Col, treasure.Col + treasure.Config.Size - 1 do
                local okOpened, alreadyOpened = safeActivityCall(gamePlayer, "TreasureGridIsCellOpened", activityId, row, col)
                if okOpened and alreadyOpened then
                    treasureOpenedAnyCell = true
                    log("  已开，跳过 cell=(%d,%d)", row, col)
                    continue
                end

                if costValueType then
                    local amount = getCurrencyAmount(gamePlayer, costValueType)
                    if amount ~= nil and amount < costCount then
                        warnf("  货币不足，停止: %s=%s, need=%s", tostring(costValueType), tostring(amount), tostring(costCount))
                        stopped = true
                        break
                    end
                end

                local okOpen, result = openTreasureCell(activityId, row, col)
                if okOpen then
                    openedCells += 1
                    treasureOpenedAnyCell = true
                    treasureOpenedNewCell = true
                    log("  opened cell=(%d,%d), result=%s", row, col, tostring(result))
                else
                    warnf("  开格失败 cell=(%d,%d): %s", row, col, tostring(result))
                    stopped = true
                    break
                end

                task.wait(CFG.OPEN_INTERVAL)
            end
        end

        if stopped then
            break
        end

        if treasureOpenedAnyCell and treasureOpenedNewCell then
            openedTreasures += 1
        end
    end

    log("自动开格完成: openedTreasures=%d openedCells=%d", openedTreasures, openedCells)
end

local function requestServerSync(gamePlayer, activityId)
    safeActivityCall(gamePlayer, "TreasureGridGetTreasureMap", activityId)
    task.wait(CFG.REQUEST_SYNC_WAIT)
end

local function main()
    PathTool = waitForPathTool(CFG.INIT_TIMEOUT)
    installDirectRequireFallback()
    preloadDirectModules()

    local gamePlayer = waitForGamePlayer(CFG.INIT_TIMEOUT)
    requestServerSync(gamePlayer, CFG.ACTIVITY_ID)

    local activityConfig = getActivityConfig(CFG.ACTIVITY_ID)
    if not activityConfig then
        error(string.format("%s 找不到活动配置: %s", TAG, tostring(CFG.ACTIVITY_ID)))
    end
    ensureActivityTimes(activityConfig)
    if not activityConfig.StartTime then
        error(string.format("%s 活动 %s 缺少 StartTime，无法计算默认地图种子", TAG, tostring(CFG.ACTIVITY_ID)))
    end

    local effectConfig = activityConfig.Effects and activityConfig.Effects.TreasureGrid
    if not effectConfig then
        error(string.format("%s 活动 %s 没有 TreasureGrid 效果", TAG, tostring(CFG.ACTIVITY_ID)))
    end

    local highQualitySet = {}
    for _, quality in ipairs(effectConfig.HighQuality or {}) do
        highQualitySet[quality] = true
    end
    local whitelistSet = CFG.REWARD_WHITELIST_TMPL_IDS

    local treasureMap, seedInfo = buildTreasureMap(CFG.ACTIVITY_ID, gamePlayer, activityConfig, effectConfig)
    local treasureList = sortedTreasureList(treasureMap, whitelistSet, highQualitySet)
    local syncValidationOk = compareWithSyncedRevealedMap(treasureMap, getSyncedRevealedMap(gamePlayer, CFG.ACTIVITY_ID))

    log("活动: id=%s name=%s", tostring(CFG.ACTIVITY_ID), tostring(activityConfig.Name))
    log("地图: %dx%d, refreshTick=%s, nextRefreshTick=%s", effectConfig.MapRowCount, effectConfig.MapColCount, tostring(seedInfo.refreshTick), tostring(seedInfo.nextRefreshTick))
    log("种子: customSeed=%s rawSeed=%s rewardSeed=%s placementSeed=%s", tostring(seedInfo.customSeed), tostring(seedInfo.rawSeed), tostring(seedInfo.rewardSeed), tostring(seedInfo.placementSeed))

    local whitelistCountPredicted = 0
    log("===== 白名单奖励坐标 =====")
    for _, treasure in ipairs(treasureList) do
        if whitelistSet[treasure.TmplId] then
            whitelistCountPredicted += 1
            local opened = isAnyCellOpened(gamePlayer, CFG.ACTIVITY_ID, treasure)
            local claimed = isRewardClaimed(gamePlayer, CFG.ACTIVITY_ID, treasure.TmplId)
            log(
                "#%d tmpl=%s size=%dx%d topLeft=(%d,%d) cells=%s reward=%s opened=%s claimed=%s",
                whitelistCountPredicted,
                tostring(treasure.TmplId),
                treasure.Config.Size,
                treasure.Config.Size,
                treasure.Row,
                treasure.Col,
                formatCells(treasure.Row, treasure.Col, treasure.Config.Size),
                formatReward(treasure.Config.Reward),
                tostring(opened),
                tostring(claimed)
            )
        end
    end

    if whitelistCountPredicted == 0 then
        log("本轮预测没有白名单奖励。")
    end

    if CFG.PRINT_ALL_TREASURES then
        log("===== 全部宝藏 =====")
        for _, treasure in ipairs(treasureList) do
            local qualityName = getQualityName(treasure.Config.Quality)
            log(
                "tmpl=%s quality=%s size=%dx%d topLeft=(%d,%d) reward=%s",
                tostring(treasure.TmplId),
                qualityName,
                treasure.Config.Size,
                treasure.Config.Size,
                treasure.Row,
                treasure.Col,
                formatReward(treasure.Config.Reward)
            )
        end
    end

    if CFG.PRINT_GRID then
        printGrid(treasureList, whitelistSet, highQualitySet, effectConfig.MapRowCount, effectConfig.MapColCount)
    end

    if CFG.STOP_ON_SYNC_MISMATCH and syncValidationOk == false then
        warnf("自动开格已停止: 已露出宝藏校验不匹配")
        return
    end

    autoOpenWhitelistedTreasures(gamePlayer, CFG.ACTIVITY_ID, effectConfig, treasureList, whitelistSet)
end

local ok, err = pcall(main)
if not ok then
    warnf("执行失败: %s", tostring(err))
end
