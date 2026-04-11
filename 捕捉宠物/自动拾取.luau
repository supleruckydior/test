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
    ENABLE_SERVER_SWITCH = true,
    NO_PICK_SWITCH_DELAY = 5,
    CLAIM_RETRY_DELAY = 2,
    JOB_CHANGE_TIMEOUT = 5,
}

local areaPickCooldown = {}
local pickItemCooldown = {}
local boostPickCooldown = {}

if _G.AutoPickAllControl and _G.AutoPickAllControl.Stop then
    pcall(function()
        _G.AutoPickAllControl.Stop()
    end)
end

local Control = {
    running = true,
    serverSwitchEnabled = CFG.ENABLE_SERVER_SWITCH,
    switchingServer = false,
}

function Control.Stop()
    if Control.running then
        Control.running = false
        print(string.format("%s 已停止", TAG))
    end
end

function Control.SetServerSwitch(enabled)
    Control.serverSwitchEnabled = enabled == true
    print(string.format("%s 切服开关: %s", TAG, Control.serverSwitchEnabled and "开启" or "关闭"))
end

function Control.ToggleServerSwitch()
    Control.SetServerSwitch(not Control.serverSwitchEnabled)
end

_G.AutoPickAllControl = Control

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

WaitForPathTool(30)


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
            end)

            if not ok then
                warn(string.format("%s 运行异常: %s", TAG, tostring(err)))
            end
        end

        if totalPicked > 0 then
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

    if _G.AutoPickAllControl == Control then
        _G.AutoPickAllControl = nil
    end
end)
