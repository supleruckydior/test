local TARGET_GAME_ID = 98664161516921
if game.PlaceId ~= TARGET_GAME_ID then
    warn(string.format("[FindMonster] 游戏ID不匹配: %d (需要 %d)，脚本已禁用", game.PlaceId, TARGET_GAME_ID))
    _G.__FINDMONSTER_DISABLED = true
    return
end
-- 切服总开关：true = 10秒无拾取自动切服；false = 只自动拾取，不切服
local ENABLE_SERVER_SWITCH = false

-- SimplySpy 抓到的 SpaceReward 领取项：{地图/活动ID, 奖励序号}
local SPACE_REWARD_TARGETS = {
    { "4", 7 },
}

-- true = 自动扫描 CfgUpdateEventObby 里所有没领过的 SpaceReward
local CLAIM_ALL_SPACE_REWARDS = true

-- Robbery 只拾取 CfgRobberyReward.CountRewards[2] 的高档刷新物；改成 nil = 全部拾取
local ROBBERY_ONLY_COUNT_REWARD_INDEX = 2
local ROBBERY_FILTER_DEBUG = true
local ROBBERY_FILTER_DEBUG_INTERVAL = 5
local ROBBERY_FILTER_DEBUG_MAX_LINES = 20
local ROBBERY_PICK_UNKNOWN_COUNT_REWARD = false

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local TAG = "[自动拾取]"
task.wait(6)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local localPlayer = Players.LocalPlayer

local ModuleCache = nil
local GamePlayer = nil
local LogicNumber = nil
local MgrPetClient = nil
local directRequireModule = nil
local getModule = nil
local requirePathModule = nil
local WaitForModules = nil

local LOOP_WAIT_IDLE = 1.0
local LOOP_WAIT_BUSY = 0.25
local RETRY_COOLDOWN = 1.0

local CFG = {
    LAN_SERVER_URL = "http://192.168.31.247:8765",
    ENABLE_SERVER_SWITCH = ENABLE_SERVER_SWITCH,
    NO_PICK_SWITCH_DELAY = 10,
    CLAIM_RETRY_DELAY = 2,
    JOB_CHANGE_TIMEOUT = 30,
}

local SWITCH_MEMORY_FILE = string.format("auto_pick_switch_%s.json", tostring(localPlayer and localPlayer.UserId or "unknown"))

local function hasFileApi()
    return type(readfile) == "function" and type(writefile) == "function"
end

local function safeIsFile(path)
    if type(isfile) ~= "function" then
        return false
    end

    local ok, result = pcall(function()
        return isfile(path)
    end)
    return ok and result == true
end

local function loadServerSwitchEnabled()
    if not hasFileApi() then
        return CFG.ENABLE_SERVER_SWITCH
    end

    local ok, content = pcall(function()
        if safeIsFile(SWITCH_MEMORY_FILE) or type(isfile) ~= "function" then
            return readfile(SWITCH_MEMORY_FILE)
        end
        return nil
    end)
    if not ok or type(content) ~= "string" or content == "" then
        return CFG.ENABLE_SERVER_SWITCH
    end

    local decodeOk, decoded = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    if decodeOk and type(decoded) == "table" and type(decoded.serverSwitchEnabled) == "boolean" then
        return decoded.serverSwitchEnabled
    end

    return CFG.ENABLE_SERVER_SWITCH
end

local function saveServerSwitchEnabled(enabled)
    if not hasFileApi() then
        return
    end

    pcall(function()
        writefile(SWITCH_MEMORY_FILE, HttpService:JSONEncode({
            serverSwitchEnabled = enabled == true,
            updatedAt = os.time(),
        }))
    end)
end

local areaPickCooldown = {}
local pickItemCooldown = {}
local boostPickCooldown = {}
local dropPickCooldown = {}
local dropPickPending = {}
local spaceRewardCooldown = {}
local spaceRewardClaimedLocal = {}
local robberyRewardCooldown = {}
local robberyFilterDebugAt = 0

if _G.AutoPickAllControl and _G.AutoPickAllControl.Stop then
    pcall(function()
        _G.AutoPickAllControl.Stop()
    end)
end

local Control = {
    running = true,
    serverSwitchEnabled = CFG.ENABLE_SERVER_SWITCH,
    switchingServer = false,
    lastDropPickSuccessAt = 0,
}

function Control.Stop()
    if Control.running then
        Control.running = false
        print(string.format("%s 已停止", TAG))
    end
end

function Control.SetServerSwitch(enabled)
    Control.serverSwitchEnabled = enabled == true
    saveServerSwitchEnabled(Control.serverSwitchEnabled)
    print(string.format("%s 切服开关: %s", TAG, Control.serverSwitchEnabled and "开启" or "关闭"))
end

function Control.ToggleServerSwitch()
    Control.SetServerSwitch(not Control.serverSwitchEnabled)
end

_G.AutoPickAllControl = Control
_G.AutoPickSetServerSwitch = function(enabled)
    return Control.SetServerSwitch(enabled)
end
_G.AutoPickToggleServerSwitch = function()
    return Control.ToggleServerSwitch()
end
_G.AutoPickStop = function()
    return Control.Stop()
end

local function nowTick()
    return tick()
end

local function markCooldown(pool, key)
    pool[tostring(key)] = nowTick()
end

local function isCooling(pool, key, cd)
    local lastAt = pool[tostring(key)]
    if not lastAt then
        return false
    end
    return (nowTick() - lastAt) < (cd or RETRY_COOLDOWN)
end

do
local DIRECT_MODULE_PATHS = {
    AreaPickUpSystem = { "CommonLogic", "Area", "AreaPickUpSystem" },
    BoostSystem = { "CommonLogic", "Boost", "BoostSystem" },
    CfgAreaPickUp = { "CommonConfig", "Area", "CfgAreaPickUp" },
    CfgBoost = { "CommonConfig", "Boost", "CfgBoost" },
    CfgCommonItem = { "CommonConfig", "Common", "CfgCommonItem" },
    CfgEgg = { "CommonConfig", "Egg", "CfgEgg" },
    CfgPet = { "CommonConfig", "Pet", "CfgPet" },
    CfgPetExpItem = { "CommonConfig", "Pet", "CfgPetExpItem" },
    CfgPickItem = { "CommonConfig", "Shower", "CfgPickItem" },
    CfgRobberyReward = { "CommonConfig", "UpdateEvent", "CfgRobberyReward" },
    CfgUpdateEventObby = { "CommonConfig", "UpdateEvent", "CfgUpdateEventObby" },
    ClientPlayerManager = { "CommonLibrary", "Player", "ClientPlayerManager" },
    DropPickUpRewardUtil = { "CommonLogic", "Effect", "DropPickUpRewardUtil" },
    LogicNumber = { "CommonLogic", "Fight", "Logic", "LogicNumber" },
    MessageSystem = { "CommonLibrary", "Base", "MessageSystem" },
    MgrPetClient = { "ClientLogic", "Pet", "MgrPetClient" },
    PickItemSystem = { "CommonLogic", "Shower", "PickItemSystem" },
    ResourceConfig = { "CommonConfig", "ResourceConfig" },
    SpaceRewardSystem = { "CommonConfig", "SpaceReward", "SpaceRewardSystem" },
    Utils = { "CommonLibrary", "Tool", "Utils" },
    ViewUtil = { "ClientLogic", "View", "ViewUtil" },
}

local PRELOAD_MODULES = {
    "ClientPlayerManager",
    "ViewUtil",
    "Utils",
    "LogicNumber",
    "MgrPetClient",
    "ResourceConfig",
    "CfgAreaPickUp",
    "CfgPickItem",
    "CfgBoost",
    "CfgCommonItem",
    "CfgEgg",
    "CfgPetExpItem",
    "CfgPet",
    "AreaPickUpSystem",
    "PickItemSystem",
    "BoostSystem",
    "DropPickUpRewardUtil",
    "MessageSystem",
    "SpaceRewardSystem",
    "CfgUpdateEventObby",
    "CfgRobberyReward",
}

local function findReplicatedStoragePath(parts)
    if type(parts) ~= "table" then
        return nil
    end

    local node = ReplicatedStorage
    for _, name in ipairs(parts) do
        node = node:FindFirstChild(name)
        if not node then
            return nil
        end
    end
    return node
end

local function findModuleScriptByName(moduleName)
    local found = ReplicatedStorage:FindFirstChild(moduleName, true)
    if found and found:IsA("ModuleScript") then
        return found
    end
    return nil
end

local function buildPlainModuleCache()
    if ModuleCache then
        return
    end

    local existing = rawget(_G, "PathTool")
    ModuleCache = {}

    if type(existing) == "table" then
        pcall(function()
            for key, value in pairs(existing) do
                rawset(ModuleCache, key, value)
            end
        end)
    end

    _G.PathTool = ModuleCache
end

local function installModuleCacheRequire()
    buildPlainModuleCache()
    rawset(ModuleCache, "_AutoPickDirectRequireInstalled", true)
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
            error(string.format("%s CompatRequire %s err:%s", TAG, tostring(moduleNameOrScript), tostring(result)))
        end

        local moduleName = tostring(moduleNameOrScript or "")
        if moduleName == "" then
            error(TAG .. " CompatRequire moduleName empty")
        end

        local cached = rawget(ModuleCache, moduleName)
        if cached then
            return cached
        end

        local result, err = nil, "direct_loader_not_ready"
        if type(directRequireModule) == "function" then
            result, err = directRequireModule(moduleName)
        end
        if result then
            return result
        end

        error(string.format("%s CompatRequire %s err:%s", TAG, moduleName, tostring(err)))
    end
end

local function ensureModuleCache()
    buildPlainModuleCache()
    installModuleCacheRequire()
    return ModuleCache ~= nil
end

directRequireModule = function(moduleName, directPathParts)
    ensureModuleCache()
    if not ModuleCache then
        return nil, "module_cache_missing"
    end

    local cached = rawget(ModuleCache, moduleName)
    if cached then
        return cached
    end

    local moduleScript = nil
    local directPath = directPathParts or DIRECT_MODULE_PATHS[moduleName]
    if directPath then
        moduleScript = findReplicatedStoragePath(directPath)
    end
    moduleScript = moduleScript or findModuleScriptByName(moduleName)

    if not moduleScript then
        return nil, "module_not_found"
    end
    if not moduleScript:IsA("ModuleScript") then
        return nil, "not_modulescript:" .. tostring(moduleScript.ClassName)
    end

    local ok, result = pcall(require, moduleScript)
    if ok and result then
        rawset(ModuleCache, moduleName, result)
        return result
    end

    return nil, tostring(result)
end

getModule = function(moduleName)
    if not ModuleCache then
        ensureModuleCache()
    end

    local cached = ModuleCache and rawget(ModuleCache, moduleName)
    if cached then
        return cached
    end

    local result = directRequireModule(moduleName)
    return result
end

requirePathModule = function(moduleName)
    return getModule(moduleName)
end

WaitForModules = function(maxWait)
    maxWait = maxWait or 30
    ensureModuleCache()

    for _, moduleName in ipairs(PRELOAD_MODULES) do
        directRequireModule(moduleName)
    end

    MgrPetClient = MgrPetClient or getModule("MgrPetClient")
    LogicNumber = LogicNumber or getModule("LogicNumber")

    local waited = 0
    while not GamePlayer do
        local success, result = pcall(function()
            local clientPlayerManager = getModule("ClientPlayerManager")
            return clientPlayerManager and clientPlayerManager.GetGamePlayer and clientPlayerManager.GetGamePlayer()
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

    print(string.format(
        "%s [WaitForModules] ModuleCache=%s MgrPetClient=%s LogicNumber=%s GamePlayer=%s",
        TAG,
        ModuleCache and "OK" or "FAIL",
        MgrPetClient and "OK" or "FAIL",
        LogicNumber and "OK" or "FAIL",
        GamePlayer and "OK" or "FAIL"
    ))
end
end

local dataPullFunc = nil
local function getDataPullFunc()
    if dataPullFunc then
        return dataPullFunc
    end

    local ok, result = pcall(function()
        return ReplicatedStorage
            :WaitForChild("CommonLibrary")
            :WaitForChild("Tool")
            :WaitForChild("RemoteManager")
            :WaitForChild("Funcs")
            :WaitForChild("DataPullFunc")
    end)
    if ok and result then
        dataPullFunc = result
        return dataPullFunc
    end

    return nil
end

local cfgUpdateEventObby = nil
local function getCfgUpdateEventObby()
    if cfgUpdateEventObby then
        return cfgUpdateEventObby
    end

    if ModuleCache and ModuleCache.CfgUpdateEventObby then
        cfgUpdateEventObby = ModuleCache.CfgUpdateEventObby
        return cfgUpdateEventObby
    end

    local ok, result = pcall(function()
        return require(
            ReplicatedStorage
                :WaitForChild("CommonConfig")
                :WaitForChild("UpdateEvent")
                :WaitForChild("CfgUpdateEventObby")
        )
    end)
    if ok and result then
        cfgUpdateEventObby = result
        pcall(function()
            if ModuleCache then
                ModuleCache.CfgUpdateEventObby = result
            end
        end)
        return cfgUpdateEventObby
    end

    return nil
end

local cfgRobberyReward = nil
local function getCfgRobberyReward()
    if cfgRobberyReward then
        return cfgRobberyReward
    end

    if ModuleCache and ModuleCache.CfgRobberyReward then
        cfgRobberyReward = ModuleCache.CfgRobberyReward
        return cfgRobberyReward
    end

    local ok, result = pcall(function()
        return require(
            ReplicatedStorage
                :WaitForChild("CommonConfig")
                :WaitForChild("UpdateEvent")
                :WaitForChild("CfgRobberyReward")
        )
    end)
    if ok and result then
        cfgRobberyReward = result
        pcall(function()
            if ModuleCache then
                ModuleCache.CfgRobberyReward = result
            end
        end)
        return cfgRobberyReward
    end

    return nil
end

local function frameSafeWait(seconds)
    local deadline = tick() + math.max(tonumber(seconds) or 0, 0)
    repeat
        task.wait(0.1)
    until tick() >= deadline or not Control.running
end

local function urlEncode(value)
    return HttpService:UrlEncode(tostring(value or ""))
end

local function httpGetJson(pathWithQuery)
    if not CFG.LAN_SERVER_URL or CFG.LAN_SERVER_URL == "" then
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
        warn(string.format("%s [HTTP] 请求失败: %s | 错误: %s", TAG, url, tostring(decoded)))
    end
    return ok, decoded
end

local function shortJobId(jobId)
    if type(jobId) ~= "string" then
        return tostring(jobId)
    end
    if #jobId <= 8 then
        return jobId
    end
    return string.sub(jobId, 1, 8) .. "..."
end

local function getServerFromLAN()
    local ok, decoded = httpGetJson("/server")
    if ok and decoded and decoded.success and decoded.server and decoded.server.id then
        return decoded.server, nil
    end

    local errMsg = (type(decoded) == "table" and (decoded.error or decoded.reason))
        or (type(decoded) == "string" and decoded)
        or "no_valid_server"
    return nil, errMsg
end

local function releaseToLAN(jobId, resolved)
    if type(jobId) ~= "string" or jobId == "" then
        return false
    end

    local path = "/target/release?job_id=" .. urlEncode(jobId)
        .. "&claimer=" .. urlEncode(tostring(localPlayer and localPlayer.UserId or "0"))
        .. "&resolved=" .. urlEncode(resolved and "1" or "0")
        .. "&mode=" .. urlEncode("auto_pick")

    local ok, decoded = httpGetJson(path)
    return ok and decoded and decoded.success == true and decoded.released == true
end

local function getCharacterAndRootPart()
    local character = localPlayer and localPlayer.Character
    if not character then
        return nil, nil
    end
    return character, character:FindFirstChild("HumanoidRootPart")
end

local function setCharacterAnchored(isAnchored)
    local _, hrp = getCharacterAndRootPart()
    if not hrp then
        return false
    end
    hrp.Anchored = isAnchored == true
    return true
end

local function waitForJobIdChange(oldJobId, timeout)
    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    repeat
        if game.JobId ~= oldJobId then
            return true
        end
        task.wait(0.25)
    until tick() >= deadline or not Control.running
    return false
end

local function teleportToJob(jobId)
    if type(jobId) ~= "string" or jobId == "" then
        return false
    end

    local oldJobId = game.JobId
    print(string.format("%s [切服] 传送到服务器: %s", TAG, shortJobId(jobId)))
    setCharacterAnchored(true)

    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, localPlayer)
    end)

    if not ok then
        warn(string.format("%s [切服] 传送调用失败: %s", TAG, tostring(err)))
        setCharacterAnchored(false)
        return false
    end

    local changed = waitForJobIdChange(oldJobId, CFG.JOB_CHANGE_TIMEOUT)
    if not changed then
        warn(string.format("%s [切服] 传送超时，%ds 内未切服", TAG, CFG.JOB_CHANGE_TIMEOUT))
        setCharacterAnchored(false)
        return false
    end

    return true
end

local function switchServerForNoPick()
    if Control.switchingServer then
        return
    end

    if not Control.serverSwitchEnabled then
        return
    end

    if not CFG.LAN_SERVER_URL or CFG.LAN_SERVER_URL == "" then
        warn(string.format("%s [切服] LAN_SERVER_URL 未配置，跳过切服", TAG))
        return
    end

    Control.switchingServer = true
    local oldJobId = game.JobId

    pcall(function()
        releaseToLAN(oldJobId, false)
    end)

    task.spawn(function()
        local attempt = 0
        while Control.running and Control.serverSwitchEnabled do
            attempt = attempt + 1
            local server, err = getServerFromLAN()

            if server and server.id and server.id ~= oldJobId then
                print(string.format("%s [切服 第%d次] 获取到服务器: %s，正在传送", TAG, attempt, shortJobId(server.id)))
                local tpOk = teleportToJob(server.id)
                if tpOk then
                    return
                end
                warn(string.format("%s [切服 第%d次] 传送失败，重新调取服务器", TAG, attempt))
            else
                warn(string.format("%s [切服 第%d次] 获取服务器失败: %s", TAG, attempt, tostring(err)))
            end

            frameSafeWait(CFG.CLAIM_RETRY_DELAY)
        end

        Control.switchingServer = false
    end)
end

local function WaitForModulesReady(maxWait)
    WaitForModules(maxWait or 30)
    requirePathModule("AreaPickUpSystem")
    requirePathModule("PickItemSystem")
    requirePathModule("BoostSystem")
    requirePathModule("DropPickUpRewardUtil")
    requirePathModule("MessageSystem")
    requirePathModule("SpaceRewardSystem")
    getDataPullFunc()
    getCfgUpdateEventObby()
    getCfgRobberyReward()
end

local function getGamePlayer()
    if GamePlayer then
        return GamePlayer
    end
    if ModuleCache and ModuleCache.ClientPlayerManager and ModuleCache.ClientPlayerManager.GetGamePlayer then
        local ok, gp = pcall(function()
            return ModuleCache.ClientPlayerManager.GetGamePlayer()
        end)
        if ok and gp then
            GamePlayer = gp
            return gp
        end
    end
    return nil
end

local function doRequest(remote, ...)
    local args = { ... }
    return pcall(function()
        if ModuleCache.ViewUtil and ModuleCache.ViewUtil.DoRequest then
            return ModuleCache.ViewUtil.DoRequest(remote, table.unpack(args))
        end
        return remote(table.unpack(args))
    end)
end

local function getServerTime()
    if ModuleCache and ModuleCache.Utils and ModuleCache.Utils.GetServerTime then
        local ok, result = pcall(function()
            return ModuleCache.Utils.GetServerTime()
        end)
        if ok and result then
            return result
        end
    end
    return os.time()
end

local function getCfgName(cfgRoot, tmplId)
    local cfg = cfgRoot and cfgRoot.Tmpls and cfgRoot.Tmpls[tmplId]
    if not cfg then
        return nil
    end
    return cfg.Name or cfg.Title or cfg.Desc
end

local function getValueName(valueType)
    local boostCfg = ModuleCache and ModuleCache.CfgBoost and ModuleCache.CfgBoost.BoostList and ModuleCache.CfgBoost.BoostList[valueType]
    if boostCfg then
        return boostCfg.Name or boostCfg.Title or tostring(valueType)
    end

    local valueCfg = ModuleCache and ModuleCache.ResourceConfig and ModuleCache.ResourceConfig.ValueTypes and ModuleCache.ResourceConfig.ValueTypes[valueType]
    if valueCfg then
        return valueCfg.Name or valueCfg.Title or tostring(valueType)
    end

    return tostring(valueType)
end

local function describeSingleReward(reward)
    if type(reward) ~= "table" then
        return tostring(reward)
    end

    local rewardRes = tostring(reward.RewardRes or "Unknown")
    local count = reward.Count
    if type(count) ~= "number" then
        count = 1
    end

    local name
    if rewardRes == "CommonItem" then
        name = getCfgName(ModuleCache.CfgCommonItem, reward.TmplId) or ("CommonItem#" .. tostring(reward.TmplId))
    elseif rewardRes == "Egg" then
        name = getCfgName(ModuleCache.CfgEgg, reward.TmplId) or ("Egg#" .. tostring(reward.TmplId))
    elseif rewardRes == "PetExpItem" then
        name = getCfgName(ModuleCache.CfgPetExpItem, reward.TmplId) or ("PetExpItem#" .. tostring(reward.TmplId))
    elseif rewardRes == "Artifact" then
        name = getCfgName(ModuleCache.CfgArtifact, reward.TmplId) or ("Artifact#" .. tostring(reward.TmplId))
    elseif rewardRes == "Pet" then
        name = getCfgName(ModuleCache.CfgPet, reward.TmplId) or ("Pet#" .. tostring(reward.TmplId))
    elseif rewardRes == "Value" then
        name = getValueName(reward.ValueType)
    else
        name = reward.Name or reward.Title or rewardRes
        if reward.TmplId ~= nil then
            name = string.format("%s#%s", name, tostring(reward.TmplId))
        end
    end

    return string.format("%s x%s", tostring(name), tostring(count))
end

local function describeRewardList(rewardList)
    if type(rewardList) ~= "table" then
        return tostring(rewardList)
    end

    if rewardList.RewardRes then
        return describeSingleReward(rewardList)
    end

    local parts = {}
    for _, reward in ipairs(rewardList) do
        table.insert(parts, describeSingleReward(reward))
    end

    if #parts == 0 then
        return "(空奖励)"
    end

    return table.concat(parts, " + ")
end

local function decodeRewardJson(json)
    if type(json) ~= "string" or json == "" then
        return nil
    end

    local ok, result = pcall(function()
        return HttpService:JSONDecode(json)
    end)
    if ok then
        return result
    end
    return nil
end

local function canPickAreaTmpl(gp, tmplId)
    if not (gp and gp.area and ModuleCache and ModuleCache.CfgAreaPickUp and ModuleCache.CfgAreaPickUp.Tmpls) then
        return true
    end

    local cfg = ModuleCache.CfgAreaPickUp.Tmpls[tmplId]
    if not cfg or not cfg.PickUpLimit then
        return true
    end

    local ok, count = pcall(function()
        return gp.area:GetAreaPickUpCount(tmplId)
    end)
    if not ok then
        return true
    end
    return count < cfg.PickUpLimit
end

local function scanAreaPickUps()
    local gp = getGamePlayer()
    local areaFolder = workspace:FindFirstChild("AreaPickUp")
    local areaPickUpSystem = requirePathModule("AreaPickUpSystem")
    if not (areaFolder and areaPickUpSystem and areaPickUpSystem.ClientPickUp) then
        return 0
    end

    local pickedCount = 0
    for _, node in ipairs(areaFolder:GetChildren()) do
        local keyId = tonumber(node.Name)
        local tmplId = node:GetAttribute("TmplId")

        if keyId and tmplId ~= nil and not isCooling(areaPickCooldown, keyId) and canPickAreaTmpl(gp, tmplId) then
            local rewardPreview = decodeRewardJson(node:GetAttribute("Reward"))
            local previewText = rewardPreview and describeRewardList(rewardPreview) or ("AreaPickUpTmpl#" .. tostring(tmplId))

            markCooldown(areaPickCooldown, keyId)
            local ok, result = doRequest(areaPickUpSystem.ClientPickUp, keyId)
            if ok and result then
                local rewardText = result.Reward and describeRewardList(result.Reward) or previewText
                print(string.format("%s [AreaPickUp] Key=%d TmplId=%s -> %s", TAG, keyId, tostring(tmplId), rewardText))
                pickedCount = pickedCount + 1
            end
        end
    end

    return pickedCount
end

local function scanPickItems()
    local gp = getGamePlayer()
    local pickList = ModuleCache and ModuleCache.CfgPickItem and ModuleCache.CfgPickItem.PickList
    local pickItemSystem = requirePathModule("PickItemSystem")
    if not (gp and gp.pickItem and pickItemSystem and pickItemSystem.ClientPick and pickList) then
        return 0
    end

    local serverNow = getServerTime()
    local pickedCount = 0

    for pickId, _ in pairs(pickList) do
        if not isCooling(pickItemCooldown, pickId) then
            local readyTick = 0
            local itemId = nil

            pcall(function()
                readyTick = gp.pickItem:GetPickTick(pickId) or 0
                itemId = gp.pickItem:GetPickItem(pickId)
            end)

            if itemId and readyTick <= serverNow then
                local itemCfg = ModuleCache.CfgPickItem.ItemList and ModuleCache.CfgPickItem.ItemList[itemId]
                local previewReward = itemCfg and itemCfg.Reward
                local previewText = previewReward and describeRewardList(previewReward) or ("PickItem#" .. tostring(itemId))

                markCooldown(pickItemCooldown, pickId)
                local ok, result = doRequest(pickItemSystem.ClientPick, pickId)
                if ok and result then
                    local rewardText = result.Reward and describeRewardList(result.Reward) or previewText
                    print(string.format("%s [PickItem] PickId=%s ItemId=%s -> %s", TAG, tostring(pickId), tostring(itemId), rewardText))
                    pickedCount = pickedCount + 1
                end
            end
        end
    end

    return pickedCount
end

local function scanBoostPickUps()
    local gp = getGamePlayer()
    local boostSystem = requirePathModule("BoostSystem")
    if not (gp and gp.boosts and gp.boosts.GetCurrentCanClaimBoosts and boostSystem and boostSystem.ClientPickBoost) then
        return 0
    end

    local ok, boosts = pcall(function()
        return gp.boosts:GetCurrentCanClaimBoosts()
    end)
    if not ok or type(boosts) ~= "table" then
        return 0
    end

    local pickedCount = 0
    for boostKey, info in pairs(boosts) do
        if type(info) == "table" and info.ItemId and info.CanShow ~= 0 and info.Claimed ~= 1 and not isCooling(boostPickCooldown, boostKey) then
            local itemCfg = ModuleCache.CfgPickItem and ModuleCache.CfgPickItem.ItemList and ModuleCache.CfgPickItem.ItemList[info.ItemId]
            local previewReward = itemCfg and itemCfg.Reward
            local previewText = previewReward and describeRewardList(previewReward) or ("BoostItem#" .. tostring(info.ItemId))

            markCooldown(boostPickCooldown, boostKey)
            local reqOk, result = doRequest(boostSystem.ClientPickBoost, info.ItemId, boostKey)
            if reqOk and result then
                local rewardText = result.Reward and describeRewardList(result.Reward) or previewText
                print(string.format("%s [BoostPick] BoostKey=%s ItemId=%s -> %s", TAG, tostring(boostKey), tostring(info.ItemId), rewardText))
                pickedCount = pickedCount + 1
            end
        end
    end

    return pickedCount
end

local function getDropPickId(node)
    if not node then
        return nil
    end

    local split = string.split(tostring(node.Name), "_")
    if #split == 2 and split[1] == "PickUp" then
        return tonumber(split[2])
    end
    return tonumber(node.Name)
end

local function isDropPickOwnedOrPublic(node)
    if not node then
        return false
    end

    local takenPlayerId = node:GetAttribute("TakenPlayerId")
    if takenPlayerId and takenPlayerId ~= 0 then
        return false
    end

    local ownerAttr = "Owner_" .. tostring(localPlayer and localPlayer.UserId or "")
    if node:GetAttribute(ownerAttr) == true then
        return true
    end

    local ownTick = tonumber(node:GetAttribute("OwnTick")) or 0
    if ownTick <= 0 then
        return true
    end

    local serverNow = 0
    pcall(function()
        serverNow = workspace:GetServerTimeNow()
    end)
    return serverNow >= ownTick
end

local function getDropRewardPreviewFromUtil(dropId)
    local dropUtil = requirePathModule("DropPickUpRewardUtil")
    if not (dropUtil and dropUtil.IterPickUpRewardInfo) then
        return nil
    end

    local preview = nil
    pcall(function()
        dropUtil.IterPickUpRewardInfo(function(info)
            if info and info.Id == dropId then
                preview = info.Reward
                return false
            end
            return true
        end)
    end)

    return preview
end

local dropResultListenerRegistered = false
local function ensureDropPickResultListener()
    if dropResultListenerRegistered then
        return
    end

    local messageSystem = requirePathModule("MessageSystem")
    if not (messageSystem and messageSystem.Register) then
        return
    end

    dropResultListenerRegistered = true
    pcall(function()
        messageSystem.Register("DropPickUpRewardTakenResult", function(_, dropId, rewardResult, reason)
            local pendingText = dropPickPending[tostring(dropId)]
            dropPickPending[tostring(dropId)] = nil

            if rewardResult then
                Control.lastDropPickSuccessAt = tick()
                local rewardText = describeRewardList(rewardResult)
                if rewardText == "(空奖励)" and pendingText then
                    rewardText = pendingText
                end
                print(string.format("%s [DropPickUp] Id=%s -> %s", TAG, tostring(dropId), rewardText))
            elseif reason then
                print(string.format("%s [DropPickUp] Id=%s 领取失败: %s", TAG, tostring(dropId), tostring(reason)))
            end
        end)
    end)
end

local function scanDropPickUpRewards()
    local pickUpRewards = workspace:FindFirstChild("PickUpRewards")
    local messageSystem = requirePathModule("MessageSystem")
    if not (pickUpRewards and messageSystem and messageSystem.Send) then
        return 0
    end

    ensureDropPickResultListener()

    local sentCount = 0
    for _, node in ipairs(pickUpRewards:GetChildren()) do
        local dropId = getDropPickId(node)
        if dropId and not isCooling(dropPickCooldown, dropId, 1.5) and isDropPickOwnedOrPublic(node) then
            local rewardPreview = getDropRewardPreviewFromUtil(dropId)
            local previewText = rewardPreview and describeRewardList(rewardPreview) or "DropPickUpReward"

            markCooldown(dropPickCooldown, dropId)
            dropPickPending[tostring(dropId)] = previewText

            local ok = pcall(function()
                messageSystem.Send("DropPickUpRewardTaken", dropId)
            end)
            if ok then
                sentCount = sentCount + 1
            else
                dropPickPending[tostring(dropId)] = nil
            end
        end
    end

    return sentCount
end

local function getSpaceRewardKey(mapId, rewardIndex)
    return tostring(mapId) .. ":" .. tostring(rewardIndex)
end

local function getSpaceRewardClaimMapKey(mapId, rewardIndex)
    local cfg = getCfgUpdateEventObby()
    local obby = cfg and cfg.EventObbys and cfg.EventObbys[tonumber(mapId)]
    if not obby or not obby.EventKey then
        return nil
    end
    return tostring(obby.EventKey) .. tostring(rewardIndex)
end

local function getSpaceRewardConfig(mapId, rewardIndex)
    local cfg = getCfgUpdateEventObby()
    local obby = cfg and cfg.EventObbys and cfg.EventObbys[tonumber(mapId)]
    local rewardCfg = obby and obby.Rewards and obby.Rewards[tonumber(rewardIndex)]
    return obby, rewardCfg
end

local function isSpaceRewardClaimed(gp, mapId, rewardIndex)
    local localKey = getSpaceRewardKey(mapId, rewardIndex)
    if spaceRewardClaimedLocal[localKey] then
        return true
    end

    local claimKey = getSpaceRewardClaimMapKey(mapId, rewardIndex)
    if not (gp and gp.spaceReward and gp.spaceReward.GetRewardClaimed and claimKey) then
        return false
    end

    local ok, claimed = pcall(function()
        return gp.spaceReward:GetRewardClaimed(claimKey)
    end)
    return ok and claimed == true
end

local function claimSpaceReward(mapId, rewardIndex)
    local gp = getGamePlayer()
    local localKey = getSpaceRewardKey(mapId, rewardIndex)
    if isCooling(spaceRewardCooldown, localKey, 3) or isSpaceRewardClaimed(gp, mapId, rewardIndex) then
        return false
    end

    local _, rewardCfg = getSpaceRewardConfig(mapId, rewardIndex)
    if not (rewardCfg and rewardCfg.Reward) then
        return false
    end

    local previewText = describeRewardList(rewardCfg.Reward)
    markCooldown(spaceRewardCooldown, localKey)

    local ok, result = false, nil
    local spaceRewardSystem = requirePathModule("SpaceRewardSystem")
    if spaceRewardSystem and spaceRewardSystem.ClientClaimFinnalReward then
        ok, result = doRequest(spaceRewardSystem.ClientClaimFinnalReward, tostring(mapId), tonumber(rewardIndex))
    end

    if not ok or result == false then
        local remote = getDataPullFunc()
        if remote then
            ok, result = pcall(function()
                return remote:InvokeServer(
                    "SpaceRewardClaimFinnalRewardChannel",
                    tostring(mapId),
                    tonumber(rewardIndex)
                )
            end)
        end
    end

    if ok and result then
        spaceRewardClaimedLocal[localKey] = true
        print(string.format(
            "%s [SpaceReward] MapId=%s RewardIndex=%s -> %s",
            TAG,
            tostring(mapId),
            tostring(rewardIndex),
            previewText
        ))
        return true
    end

    return false
end

local function buildSpaceRewardTargets()
    local targets = {}
    local seen = {}

    local function addTarget(mapId, rewardIndex)
        local key = getSpaceRewardKey(mapId, rewardIndex)
        if not seen[key] then
            seen[key] = true
            table.insert(targets, { mapId = mapId, rewardIndex = rewardIndex })
        end
    end

    for _, target in ipairs(SPACE_REWARD_TARGETS) do
        addTarget(target[1], target[2])
    end

    if CLAIM_ALL_SPACE_REWARDS then
        local cfg = getCfgUpdateEventObby()
        if cfg and cfg.EventObbys then
            for mapId, obby in pairs(cfg.EventObbys) do
                if obby and obby.Rewards then
                    for rewardIndex, rewardCfg in pairs(obby.Rewards) do
                        if rewardCfg and rewardCfg.Reward then
                            addTarget(mapId, rewardIndex)
                        end
                    end
                end
            end
        end
    end

    return targets
end

local function scanSpaceRewards()
    local claimedCount = 0
    for _, target in ipairs(buildSpaceRewardTargets()) do
        if claimSpaceReward(target.mapId, target.rewardIndex) then
            claimedCount = claimedCount + 1
            task.wait(0.15)
        end
    end
    return claimedCount
end

local function getRobberyEventConfig(eventKey)
    local cfg = getCfgRobberyReward()
    if not cfg or eventKey == nil then
        return nil
    end
    return cfg[tostring(eventKey)]
end

local function getRuntimeRobberyPoint(index)
    local mgr = nil
    if type(ModuleCache) == "table" then
        mgr = rawget(ModuleCache, "UpdateEventObbyMgr")
    end
    if not mgr and type(_G) == "table" then
        mgr = rawget(_G, "UpdateEventObbyMgr")
    end

    if not (mgr and mgr.gamesScripts) then
        return nil
    end

    local gameScript = mgr.gamesScripts.UpdateEventRobberyGame
    local info = gameScript and gameScript.RobberyRewardInfo
    local points = info and info.RobberyPoints
    if not points then
        return nil
    end

    return points[index] or points[tonumber(index)] or points[tostring(index)]
end

local function getCountRewardIndexFromRuntimePoint(point)
    if type(point) ~= "table" then
        return nil
    end

    local candidates = {
        point.CountRewardIndex,
        point.CountRewardId,
        point.CountRewardID,
        point.RewardIndex,
        point.RewardTmplId,
        point.PropTmplId,
        point.PropIndex,
        point.IndexInCountRewards,
        point.RoundIndex,
        point.Quality,
    }

    for _, value in ipairs(candidates) do
        local n = tonumber(value)
        if n then
            return n
        end
    end

    return nil
end

local function getRobberyCountRewardInfo(eventKey, propTmplId, vfxId)
    local eventCfg = getRobberyEventConfig(eventKey)
    local propIndex = tonumber(propTmplId)

    if eventCfg and eventCfg.CountRewards then
        if vfxId ~= nil then
            for rewardIndex, rewardCfg in pairs(eventCfg.CountRewards) do
                if rewardCfg and rewardCfg.VFXId ~= nil and tostring(rewardCfg.VFXId) == tostring(vfxId) then
                    return tonumber(rewardIndex) or rewardIndex, rewardCfg, "VFXId"
                end
            end
        end

        if propIndex and eventCfg.CountRewards[propIndex] then
            return propIndex, eventCfg.CountRewards[propIndex], "PropTmplIdFallback"
        end
    end

    local cfg = getCfgRobberyReward()
    if vfxId ~= nil and cfg then
        for _, robberyCfg in pairs(cfg) do
            if robberyCfg and robberyCfg.CountRewards then
                for rewardIndex, rewardCfg in pairs(robberyCfg.CountRewards) do
                    if rewardCfg and rewardCfg.VFXId ~= nil and tostring(rewardCfg.VFXId) == tostring(vfxId) then
                        return tonumber(rewardIndex) or rewardIndex, rewardCfg, "VFXIdAnyEvent"
                    end
                end
            end
        end
    end

    return nil, nil, "Unknown"
end

local function isWantedRobberyCountReward(index, eventKey, propTmplId, vfxId)
    local runtimePoint = getRuntimeRobberyPoint(index)
    local runtimeIndex = getCountRewardIndexFromRuntimePoint(runtimePoint)

    if runtimeIndex then
        local cfg = getRobberyEventConfig(eventKey)
        local rewardCfg = cfg and cfg.CountRewards and cfg.CountRewards[runtimeIndex]
        if not rewardCfg and type(runtimePoint) == "table" and runtimePoint.Reward then
            rewardCfg = {
                Reward = runtimePoint.Reward,
                VFXId = runtimePoint.VFXId,
            }
        end

        if not ROBBERY_ONLY_COUNT_REWARD_INDEX then
            return true, runtimeIndex, rewardCfg, "RuntimePoint"
        end

        return runtimeIndex == ROBBERY_ONLY_COUNT_REWARD_INDEX, runtimeIndex, rewardCfg, "RuntimePoint"
    end

    if not ROBBERY_ONLY_COUNT_REWARD_INDEX then
        local countRewardIndex, rewardCfg, matchSource = getRobberyCountRewardInfo(eventKey, propTmplId, vfxId)
        return true, countRewardIndex, rewardCfg, matchSource
    end

    local countRewardIndex, rewardCfg, matchSource = getRobberyCountRewardInfo(eventKey, propTmplId, vfxId)
    if tonumber(countRewardIndex) == ROBBERY_ONLY_COUNT_REWARD_INDEX then
        return true, countRewardIndex, rewardCfg, matchSource
    end

    if countRewardIndex == nil and ROBBERY_PICK_UNKNOWN_COUNT_REWARD then
        return true, nil, rewardCfg, "UnknownAllowed"
    end

    return false, countRewardIndex, rewardCfg, matchSource
end

local function getRobberyRewardPreview(eventKey, propTmplId, vfxId)
    local _, rewardCfg = getRobberyCountRewardInfo(eventKey, propTmplId, vfxId)
    if rewardCfg and rewardCfg.Reward then
        return rewardCfg.Reward
    end
    return nil
end

local function isRobberyLimitReached(gp, eventKey)
    if eventKey == nil then
        return false
    end

    local cfg = getCfgRobberyReward()
    local eventCfg = cfg and cfg[tostring(eventKey)]
    local limitCount = eventCfg and tonumber(eventCfg.LimitCount)
    if not limitCount then
        return false
    end

    if not (gp and gp.spaceReward and gp.spaceReward.GetRobberyReward) then
        return false
    end

    local ok, count = pcall(function()
        return gp.spaceReward:GetRobberyReward(tostring(eventKey))
    end)
    if not ok then
        return false
    end

    return (tonumber(count) or 0) >= limitCount
end

local function getRobberyRewardKey(index, eventKey)
    return tostring(eventKey or "unknown") .. ":" .. tostring(index)
end

local function claimRobberyReward(node)
    if not node or not node.GetAttribute then
        return false, "bad_node"
    end

    local index = node:GetAttribute("Index")
    local eventKey = node:GetAttribute("EventKey")
    local propTmplId = node:GetAttribute("PropTmplId")
    local vfxId = node:GetAttribute("VFXId")
    if index == nil then
        return false, "no_index"
    end

    local wanted, countRewardIndex, countRewardCfg, matchSource = isWantedRobberyCountReward(index, eventKey, propTmplId, vfxId)
    if not wanted then
        return false, "filtered", countRewardIndex, countRewardCfg, matchSource
    end

    local gp = getGamePlayer()
    if isRobberyLimitReached(gp, eventKey) then
        return false, "limit_reached", countRewardIndex, countRewardCfg, matchSource
    end

    local localKey = getRobberyRewardKey(index, eventKey)
    if isCooling(robberyRewardCooldown, localKey, 1.5) then
        return false, "cooling", countRewardIndex, countRewardCfg, matchSource
    end

    local rewardPreview = countRewardCfg and countRewardCfg.Reward or getRobberyRewardPreview(eventKey, propTmplId, vfxId)
    local previewText = rewardPreview and describeRewardList(rewardPreview) or "RobberyReward"
    local payload = {
        Index = index,
        EventKey = eventKey,
        PropTmplId = propTmplId,
    }

    markCooldown(robberyRewardCooldown, localKey)

    local ok, result = false, nil
    local remote = getDataPullFunc()
    if remote then
        ok, result = pcall(function()
            return remote:InvokeServer("RobberyClaimRewardChannel", payload)
        end)
    end

    if (not ok or result == false) and matchSource ~= "Unknown" and matchSource ~= "UnknownAllowed" then
        local spaceRewardSystem = requirePathModule("SpaceRewardSystem")
        if spaceRewardSystem and spaceRewardSystem.ClientRobberyClaimReward then
            ok, result = doRequest(spaceRewardSystem.ClientRobberyClaimReward, payload)
        end
    end

    if ok and result then
        local rewardText = previewText
        if type(result) == "table" and result.Reward then
            rewardText = describeRewardList(result.Reward)
        end

        print(string.format(
            "%s [RobberyReward] Index=%s EventKey=%s PropTmplId=%s VFXId=%s CountRewards[%s] via %s -> %s",
            TAG,
            tostring(index),
            tostring(eventKey),
            tostring(propTmplId),
            tostring(vfxId),
            tostring(countRewardIndex),
            tostring(matchSource),
            rewardText
        ))
        return true
    end

    return false, "request_failed:" .. tostring(result), countRewardIndex, countRewardCfg, matchSource
end

local function getRobberyDebugLine(node, order, status)
    local index = node:GetAttribute("Index")
    local eventKey = node:GetAttribute("EventKey")
    local propTmplId = node:GetAttribute("PropTmplId")
    local vfxId = node:GetAttribute("VFXId")
    local wanted, countRewardIndex, rewardCfg, matchSource = isWantedRobberyCountReward(index, eventKey, propTmplId, vfxId)
    local runtimePoint = getRuntimeRobberyPoint(index)
    local runtimeEventKey = type(runtimePoint) == "table" and runtimePoint.EventKey or nil
    local runtimeVfxId = type(runtimePoint) == "table" and runtimePoint.VFXId or nil
    local runtimeRewardText = type(runtimePoint) == "table" and runtimePoint.Reward and describeRewardList(runtimePoint.Reward) or "nil"

    return string.format(
        "%s [RobberyDebug:%02d] status=%s Index=%s EventKey=%s PropTmplId=%s VFXId=%s resolved=CountRewards[%s] via %s wanted=%s reward=%s runtimeEventKey=%s runtimeVFXId=%s runtimeReward=%s",
        TAG,
        order,
        tostring(status or "scan"),
        tostring(index),
        tostring(eventKey),
        tostring(propTmplId),
        tostring(vfxId),
        tostring(countRewardIndex),
        tostring(matchSource),
        tostring(wanted),
        rewardCfg and rewardCfg.Reward and describeRewardList(rewardCfg.Reward) or "nil",
        tostring(runtimeEventKey),
        tostring(runtimeVfxId),
        runtimeRewardText
    )
end

local function printRobberyFilterDebug(robberyFolder, stats, statusByNode)
    if not ROBBERY_FILTER_DEBUG then
        return
    end

    if tick() - robberyFilterDebugAt < ROBBERY_FILTER_DEBUG_INTERVAL then
        return
    end
    robberyFilterDebugAt = tick()

    print(string.format(
        "%s [RobberyFilter] seen=%d picked=%d wanted=%d filtered=%d cooling=%d limit=%d failed=%d noIndex=%d only=CountRewards[%s]",
        TAG,
        stats.seen or 0,
        stats.picked or 0,
        stats.wanted or 0,
        stats.filtered or 0,
        stats.cooling or 0,
        stats.limit or 0,
        stats.failed or 0,
        stats.noIndex or 0,
        tostring(ROBBERY_ONLY_COUNT_REWARD_INDEX or "全部")
    ))

    local printed = 0
    for _, node in ipairs(robberyFolder:GetChildren()) do
        if node:IsA("BasePart") and printed < ROBBERY_FILTER_DEBUG_MAX_LINES then
            printed = printed + 1
            print(getRobberyDebugLine(node, printed, statusByNode and statusByNode[node] or "scan"))

            local ok, attrs = pcall(function()
                return node:GetAttributes()
            end)
            if ok and type(attrs) == "table" then
                local attrParts = {}
                for attrName, attrValue in pairs(attrs) do
                    table.insert(attrParts, tostring(attrName) .. "=" .. tostring(attrValue))
                end
                table.sort(attrParts)
                print(string.format("%s [RobberyAttrs:%02d] %s", TAG, printed, table.concat(attrParts, ", ")))
            end
        end
    end

    if (stats.seen or 0) > ROBBERY_FILTER_DEBUG_MAX_LINES then
        print(string.format(
            "%s [RobberyFilter] 只打印前 %d 个刷新物，剩余 %d 个省略",
            TAG,
            ROBBERY_FILTER_DEBUG_MAX_LINES,
            (stats.seen or 0) - ROBBERY_FILTER_DEBUG_MAX_LINES
        ))
    end
end

local function scanRobberyRewards()
    local obbyEventFolder = workspace:FindFirstChild("ObbyEventFolder")
    local robberyFolder = obbyEventFolder and obbyEventFolder:FindFirstChild("Robbery")
    if not robberyFolder then
        return 0
    end

    local claimedCount = 0
    local stats = {
        seen = 0,
        picked = 0,
        wanted = 0,
        filtered = 0,
        cooling = 0,
        limit = 0,
        failed = 0,
        noIndex = 0,
    }
    local statusByNode = {}

    for _, node in ipairs(robberyFolder:GetChildren()) do
        if node:IsA("BasePart") then
            stats.seen = stats.seen + 1

            local ok, reason = claimRobberyReward(node)
            if ok then
                stats.wanted = stats.wanted + 1
                stats.picked = stats.picked + 1
                statusByNode[node] = "picked"
                claimedCount = claimedCount + 1
                task.wait(0.05)
            elseif reason == "filtered" then
                stats.filtered = stats.filtered + 1
                statusByNode[node] = reason
            elseif reason == "cooling" then
                stats.cooling = stats.cooling + 1
                stats.wanted = stats.wanted + 1
                statusByNode[node] = reason
            elseif reason == "limit_reached" then
                stats.limit = stats.limit + 1
                stats.wanted = stats.wanted + 1
                statusByNode[node] = reason
            elseif reason == "no_index" then
                stats.noIndex = stats.noIndex + 1
                statusByNode[node] = reason
            elseif type(reason) == "string" and string.find(reason, "request_failed", 1, true) then
                stats.failed = stats.failed + 1
                stats.wanted = stats.wanted + 1
                statusByNode[node] = reason
            else
                local eventKey = node:GetAttribute("EventKey")
                local propTmplId = node:GetAttribute("PropTmplId")
                local vfxId = node:GetAttribute("VFXId")
                local wanted = isWantedRobberyCountReward(node:GetAttribute("Index"), eventKey, propTmplId, vfxId)
                if wanted then
                    stats.wanted = stats.wanted + 1
                end
                statusByNode[node] = reason or "not_picked"
            end
        end
    end

    if stats.seen > 0 then
        printRobberyFilterDebug(robberyFolder, stats, statusByNode)
    end

    return claimedCount
end

WaitForModulesReady(30)

print(string.format("%s 启动成功，玩家=%s", TAG, tostring(localPlayer and localPlayer.Name or "Unknown")))
print(string.format("%s 开始自动拾取：AreaPickUp / PickItem / Boost / DropPickUp / SpaceReward / RobberyReward", TAG))
print(string.format("%s Robbery过滤: 只拾取 CountRewards[%s]", TAG, tostring(ROBBERY_ONLY_COUNT_REWARD_INDEX or "全部")))
print(string.format(
    "%s 无拾取 %ds 切服: %s | LAN=%s",
    TAG,
    CFG.NO_PICK_SWITCH_DELAY,
    Control.serverSwitchEnabled and "开启" or "关闭",
    tostring(CFG.LAN_SERVER_URL)
))

task.spawn(function()
    local lastPickAt = tick()
    local lastNoPickLogAt = 0

    while Control.running do
        local totalPicked = 0

        if not Control.switchingServer then
            local ok, err = pcall(function()
                totalPicked = totalPicked + scanAreaPickUps()
                totalPicked = totalPicked + scanPickItems()
                totalPicked = totalPicked + scanBoostPickUps()
                totalPicked = totalPicked + scanDropPickUpRewards()
                totalPicked = totalPicked + scanSpaceRewards()
                totalPicked = totalPicked + scanRobberyRewards()
            end)

            if not ok then
                warn(string.format("%s 运行异常: %s", TAG, tostring(err)))
            end
        end

        if totalPicked > 0 or (Control.lastDropPickSuccessAt > lastPickAt) then
            lastPickAt = tick()
        elseif Control.serverSwitchEnabled and not Control.switchingServer then
            local idleSeconds = tick() - lastPickAt
            if idleSeconds >= CFG.NO_PICK_SWITCH_DELAY then
                warn(string.format("%s 已 %.1fs 无拾取物，准备切换服务器", TAG, idleSeconds))
                switchServerForNoPick()
            elseif tick() - lastNoPickLogAt >= 5 then
                lastNoPickLogAt = tick()
                print(string.format(
                    "%s 暂无可拾取物 %.1f/%ds",
                    TAG,
                    idleSeconds,
                    CFG.NO_PICK_SWITCH_DELAY
                ))
            end
        end

        task.wait(totalPicked > 0 and LOOP_WAIT_BUSY or LOOP_WAIT_IDLE)
    end

    print(string.format("%s 控制对象已保留，如需重新启动请重新执行脚本", TAG))
end)
