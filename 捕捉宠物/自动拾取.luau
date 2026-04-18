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

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local TAG = "[自动拾取]"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local localPlayer = Players.LocalPlayer

local PathTool = _G.PathTool
local GamePlayer = nil
local LogicNumber = nil
local MgrPetClient = nil

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

local function requirePathModule(moduleName)
    if PathTool and PathTool[moduleName] then
        return PathTool[moduleName]
    end

    if PathTool and PathTool.Require then
        local ok, result = pcall(function()
            return PathTool.Require(moduleName)
        end)
        if ok and result then
            pcall(function()
                PathTool[moduleName] = result
            end)
            return result
        end
    end

    return nil
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

    if PathTool and PathTool.CfgUpdateEventObby then
        cfgUpdateEventObby = PathTool.CfgUpdateEventObby
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
            if PathTool then
                PathTool.CfgUpdateEventObby = result
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

    if PathTool and PathTool.CfgRobberyReward then
        cfgRobberyReward = PathTool.CfgRobberyReward
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
            if PathTool then
                PathTool.CfgRobberyReward = result
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

local function WaitForPathTool(maxWait)
    maxWait = maxWait or 30
    local waited = 0

    if not PathTool then
        local success, result = pcall(function()
            return require(
                ReplicatedStorage:WaitForChild("CommonLibrary")
                    :WaitForChild("Tool")
                    :WaitForChild("PathTool")
            )
        end)
        if success and result then
            PathTool = result
            _G.PathTool = PathTool
        end
    end

    if not PathTool and _G.PathTool then
        PathTool = _G.PathTool
    end

    while not PathTool do
        task.wait(0.1)
        waited = waited + 0.1
        if waited >= maxWait then
            error(string.format("%s PathTool 系统未找到，请确保游戏已加载", TAG))
        end

        local success, result = pcall(function()
            return require(
                ReplicatedStorage:WaitForChild("CommonLibrary")
                    :WaitForChild("Tool")
                    :WaitForChild("PathTool")
            )
        end)
        if success and result then
            PathTool = result
            _G.PathTool = PathTool
        elseif _G.PathTool then
            PathTool = _G.PathTool
        end
    end

    if not MgrPetClient then
        pcall(function()
            if PathTool.Require then
                MgrPetClient = PathTool.Require("MgrPetClient")
            end
        end)
        if not MgrPetClient then
            pcall(function()
                MgrPetClient = require(
                    ReplicatedStorage:WaitForChild("ClientLogic")
                        :WaitForChild("Pet")
                        :WaitForChild("MgrPetClient")
                )
            end)
        end
    end

    if not LogicNumber then
        pcall(function()
            if PathTool.Require then
                LogicNumber = PathTool.Require("LogicNumber")
            end
        end)
    end

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

    requirePathModule("AreaPickUpSystem")
    requirePathModule("PickItemSystem")
    requirePathModule("BoostSystem")
    requirePathModule("DropPickUpRewardUtil")
    requirePathModule("MessageSystem")
    requirePathModule("SpaceRewardSystem")
    getDataPullFunc()
    getCfgUpdateEventObby()
    getCfgRobberyReward()

    print(string.format(
        "%s [WaitForPathTool] PathTool=%s MgrPetClient=%s LogicNumber=%s GamePlayer=%s",
        TAG,
        PathTool and "OK" or "FAIL",
        MgrPetClient and "OK" or "FAIL",
        LogicNumber and "OK" or "FAIL",
        GamePlayer and "OK" or "FAIL"
    ))
end

local function getGamePlayer()
    if GamePlayer then
        return GamePlayer
    end
    if PathTool and PathTool.ClientPlayerManager and PathTool.ClientPlayerManager.GetGamePlayer then
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

local function doRequest(remote, ...)
    local args = { ... }
    return pcall(function()
        if PathTool.ViewUtil and PathTool.ViewUtil.DoRequest then
            return PathTool.ViewUtil.DoRequest(remote, table.unpack(args))
        end
        return remote(table.unpack(args))
    end)
end

local function getServerTime()
    if PathTool and PathTool.Utils and PathTool.Utils.GetServerTime then
        local ok, result = pcall(function()
            return PathTool.Utils.GetServerTime()
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
    local boostCfg = PathTool and PathTool.CfgBoost and PathTool.CfgBoost.BoostList and PathTool.CfgBoost.BoostList[valueType]
    if boostCfg then
        return boostCfg.Name or boostCfg.Title or tostring(valueType)
    end

    local valueCfg = PathTool and PathTool.ResourceConfig and PathTool.ResourceConfig.ValueTypes and PathTool.ResourceConfig.ValueTypes[valueType]
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
        name = getCfgName(PathTool.CfgCommonItem, reward.TmplId) or ("CommonItem#" .. tostring(reward.TmplId))
    elseif rewardRes == "Egg" then
        name = getCfgName(PathTool.CfgEgg, reward.TmplId) or ("Egg#" .. tostring(reward.TmplId))
    elseif rewardRes == "PetExpItem" then
        name = getCfgName(PathTool.CfgPetExpItem, reward.TmplId) or ("PetExpItem#" .. tostring(reward.TmplId))
    elseif rewardRes == "Artifact" then
        name = getCfgName(PathTool.CfgArtifact, reward.TmplId) or ("Artifact#" .. tostring(reward.TmplId))
    elseif rewardRes == "Pet" then
        name = getCfgName(PathTool.CfgPet, reward.TmplId) or ("Pet#" .. tostring(reward.TmplId))
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
    if not (gp and gp.area and PathTool and PathTool.CfgAreaPickUp and PathTool.CfgAreaPickUp.Tmpls) then
        return true
    end

    local cfg = PathTool.CfgAreaPickUp.Tmpls[tmplId]
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
    local pickList = PathTool and PathTool.CfgPickItem and PathTool.CfgPickItem.PickList
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
                local itemCfg = PathTool.CfgPickItem.ItemList and PathTool.CfgPickItem.ItemList[itemId]
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
            local itemCfg = PathTool.CfgPickItem and PathTool.CfgPickItem.ItemList and PathTool.CfgPickItem.ItemList[info.ItemId]
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

local function getRobberyRewardPreview(eventKey, propTmplId)
    local cfg = getCfgRobberyReward()
    local eventCfg = cfg and cfg[tostring(eventKey)]
    if not eventCfg then
        return nil
    end

    local propIndex = tonumber(propTmplId)
    local rewardCfg = propIndex and eventCfg.CountRewards and eventCfg.CountRewards[propIndex]
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
        return false
    end

    local index = node:GetAttribute("Index")
    local eventKey = node:GetAttribute("EventKey")
    local propTmplId = node:GetAttribute("PropTmplId")
    if index == nil then
        return false
    end
    if ROBBERY_ONLY_COUNT_REWARD_INDEX and tonumber(propTmplId) ~= ROBBERY_ONLY_COUNT_REWARD_INDEX then
        return false
    end

    local gp = getGamePlayer()
    if isRobberyLimitReached(gp, eventKey) then
        return false
    end

    local localKey = getRobberyRewardKey(index, eventKey)
    if isCooling(robberyRewardCooldown, localKey, 1.5) then
        return false
    end

    local rewardPreview = getRobberyRewardPreview(eventKey, propTmplId)
    local previewText = rewardPreview and describeRewardList(rewardPreview) or "RobberyReward"
    local payload = {
        Index = index,
        EventKey = eventKey,
        PropTmplId = propTmplId,
    }

    markCooldown(robberyRewardCooldown, localKey)

    local ok, result = false, nil
    local spaceRewardSystem = requirePathModule("SpaceRewardSystem")
    if spaceRewardSystem and spaceRewardSystem.ClientRobberyClaimReward then
        ok, result = doRequest(spaceRewardSystem.ClientRobberyClaimReward, payload)
    end

    if not ok or result == false then
        local remote = getDataPullFunc()
        if remote then
            ok, result = pcall(function()
                return remote:InvokeServer("RobberyClaimRewardChannel", payload)
            end)
        end
    end

    if ok and result then
        local rewardText = previewText
        if type(result) == "table" and result.Reward then
            rewardText = describeRewardList(result.Reward)
        end

        print(string.format(
            "%s [RobberyReward] Index=%s EventKey=%s PropTmplId=%s -> %s",
            TAG,
            tostring(index),
            tostring(eventKey),
            tostring(propTmplId),
            rewardText
        ))
        return true
    end

    return false
end

local function scanRobberyRewards()
    local obbyEventFolder = workspace:FindFirstChild("ObbyEventFolder")
    local robberyFolder = obbyEventFolder and obbyEventFolder:FindFirstChild("Robbery")
    if not robberyFolder then
        return 0
    end

    local claimedCount = 0
    for _, node in ipairs(robberyFolder:GetChildren()) do
        if node:IsA("BasePart") and claimRobberyReward(node) then
            claimedCount = claimedCount + 1
            task.wait(0.05)
        end
    end

    return claimedCount
end

WaitForPathTool(30)

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
