-- 自动解锁并出售背包里的普通 D/C/B DustWing / Voltgator
-- 目标: TmplId=1000019(DustWing)、20106(Voltgator), SpecialProp=0/nil(普通), Grade=D/C/B
-- 出售前会跳过装备中、预设队伍中、坐骑、仓库、虚拟选中的宠物，并避免把背包卖空。

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local TAG = "[自动卖目标宠]"
local TARGET_PLACE_ID = 98664161516921
local TARGET_TMPL_IDS = {
    [20119] = "DustWing",
    [20106] = "Voltgator",
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

local PathTool = _G.PathTool
local PetSystem = nil
local GamePlayer = nil

local function loadPathTool()
    if PathTool then
        return PathTool
    end

    local ok, result = pcall(function()
        return require(
            ReplicatedStorage:WaitForChild("CommonLibrary")
                :WaitForChild("Tool")
                :WaitForChild("PathTool")
        )
    end)

    if ok and result then
        PathTool = result
        _G.PathTool = PathTool
        return PathTool
    end

    return nil
end

local function waitForPathTool(maxWait)
    maxWait = maxWait or 30
    local startedAt = os.clock()

    while os.clock() - startedAt < maxWait do
        if loadPathTool() then
            return true
        end
        task.wait(0.2)
    end

    warn(TAG .. " PathTool 加载失败")
    return false
end

local function getPetSystem()
    if PetSystem then
        return PetSystem
    end

    if not PathTool then
        loadPathTool()
    end
    if not PathTool then
        return nil
    end

    PetSystem = PathTool.PetSystem

    if not PetSystem and PathTool.Require then
        pcall(function()
            PetSystem = PathTool.Require("PetSystem")
        end)
    end

    return PetSystem
end

local function getGamePlayer()
    if GamePlayer then
        return GamePlayer
    end

    if not PathTool then
        loadPathTool()
    end
    if not PathTool then
        return nil
    end

    local ok, gp = pcall(function()
        return PathTool.ClientPlayerManager:GetGamePlayer()
    end)

    if not ok or not gp then
        ok, gp = pcall(function()
            return PathTool.ClientPlayerManager.GetGamePlayer()
        end)
    end

    if ok and gp then
        GamePlayer = gp
        return GamePlayer
    end

    pcall(function()
        GamePlayer = PathTool.GamePlayer and PathTool.GamePlayer.me or nil
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
    local petGrade = PathTool
        and PathTool.Constants
        and PathTool.Constants.PetGrade

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

local function isTargetPet(petItem, targetGrades)
    if not petItem then
        return false
    end

    local tmplId = nil
    local grade = nil
    local specialProp = nil

    pcall(function()
        tmplId = petItem:GetTmplId()
    end)
    pcall(function()
        grade = petItem:GetGrade()
    end)
    pcall(function()
        specialProp = petItem:GetSpecialProp()
    end)

    return TARGET_TMPL_IDS[tmplId] ~= nil
        and targetGrades[grade] ~= nil
        and (specialProp == nil or specialProp == 0)
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
        if PathTool and PathTool.ViewUtil and PathTool.ViewUtil.DoRequest then
            return PathTool.ViewUtil.DoRequest(system.ClientSellPet, batch)
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

if not waitForPathTool(30) then
    return
end

if not getPetSystem() then
    warn(TAG .. " PetSystem 加载失败")
    return
end

if not waitForGamePlayer(30) then
    return
end

print(TAG .. " 已启动，目标: 普通 D/C/B DustWing / Voltgator")

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
