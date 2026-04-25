-- 检测附近可捕捉并捕捉.lua
-- 检测角色附近可捕捉的怪/宠物，并触发 ClientCatchMonsterStart + ClientCatchMonsterComplete。

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local TAG = "[附近捕捉]"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local CFG = {
    RADIUS = 120,
    RUN_FOREVER = true,
    SCAN_SECONDS = 10,
    SCAN_INTERVAL = 0.1,
    START_TO_COMPLETE_DELAY = 0.05,
    AFTER_CATCH_DELAY = 0.05,
    SAME_TARGET_COOLDOWN = 1.5,
}

local lastCatchAtById = {}

local PathTool = _G.PathTool
if not PathTool then
    PathTool = require(
        ReplicatedStorage:WaitForChild("CommonLibrary")
            :WaitForChild("Tool")
            :WaitForChild("PathTool")
    )
    _G.PathTool = PathTool
end

local function log(fmt, ...)
    print(string.format(TAG .. " " .. fmt, ...))
end

local function warnLog(fmt, ...)
    warn(string.format(TAG .. " " .. fmt, ...))
end

local function getCharacterAndRootPart()
    local character = player.Character or player.CharacterAdded:Wait()
    if not character then
        return nil, nil
    end
    local hrp = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
    return character, hrp
end

local function getMonsterManager()
    if PathTool.MgrMonsterClient then
        return PathTool.MgrMonsterClient
    end
    if PathTool.MgrMonster then
        return PathTool.MgrMonster
    end
    for _, value in pairs(PathTool) do
        if type(value) == "table" and value.IterMonster then
            return value
        end
    end
    return nil
end

local function getMonsterId(monster)
    if not monster then
        return nil
    end

    local monsterId = tonumber(monster.MonsterId or monster.monsterId or monster.Id)
    if monsterId then
        return monsterId
    end

    if monster.Model and PathTool.MgrMonsterClient and PathTool.MgrMonsterClient.GetMonsterIdByPart then
        local part = nil
        if monster.Model:IsA("Model") then
            part = monster.Model.PrimaryPart
        elseif monster.Model:IsA("BasePart") then
            part = monster.Model
        end
        if part then
            local ok, value = pcall(function()
                return PathTool.MgrMonsterClient.GetMonsterIdByPart(part)
            end)
            if ok and tonumber(value) then
                return tonumber(value)
            end
        end
    end

    if monster.ServerNode then
        return tonumber(tostring(monster.ServerNode.Name):match("(%d+)$"))
    end
    return nil
end

local function getMonsterInfoById(monsterId)
    local monsterMgr = getMonsterManager()
    monsterId = tonumber(monsterId)
    if not monsterMgr or not monsterId or not monsterMgr.GetMonsterInfo then
        return nil
    end

    local ok, monster = pcall(function()
        return monsterMgr.GetMonsterInfo(monsterId)
    end)
    if ok then
        return monster
    end
    return nil
end

local function getMonsterPosition(monster)
    if not monster then
        return nil
    end
    if monster.CurrentCFrame then
        return monster.CurrentCFrame.Position
    end
    if monster.Position then
        return monster.Position
    end
    if monster.Model and monster.Model:IsA("Model") then
        local ok, pivot = pcall(function()
            return monster.Model:GetPivot()
        end)
        if ok and pivot then
            return pivot.Position
        end
    end
    if monster.Model and monster.Model:IsA("BasePart") then
        return monster.Model.Position
    end
    if monster.ServerNode and monster.ServerNode:IsA("BasePart") then
        return monster.ServerNode.Position
    end
    return nil
end

local function isMonsterAlive(monster)
    if not monster then
        return false
    end
    if monster.IsAlive then
        local ok, result = pcall(function()
            return monster:IsAlive()
        end)
        if ok then
            return result == true
        end
    end
    if monster.isAlive ~= nil then
        return monster.isAlive == true
    end
    if monster.HP ~= nil then
        return tonumber(monster.HP) == nil or tonumber(monster.HP) > 0
    end
    if monster.Health ~= nil then
        return tonumber(monster.Health) == nil or tonumber(monster.Health) > 0
    end
    if monster.ServerNode and monster.ServerNode.Parent == nil then
        return false
    end
    return true
end

local function hasAnyCatchAttribute(serverNode)
    if not serverNode then
        return true
    end

    local ok, attrs = pcall(function()
        return serverNode:GetAttributes()
    end)
    if not ok or type(attrs) ~= "table" then
        return false
    end

    for attrName, attrValue in pairs(attrs) do
        local name = tostring(attrName)
        if attrValue ~= nil and (
            string.find(name, "CatchPlayerId_", 1, true) == 1
            or string.find(name, "CatchTakenPlayerId_", 1, true) == 1
            or name == "CatchPlayerId"
            or name == "CatchTakenPlayerId"
        ) then
            return true
        end
    end
    return false
end

local function isMonsterCatchable(monster)
    if not monster or isMonsterAlive(monster) then
        return false
    end
    if not getMonsterId(monster) then
        return false
    end

    return hasAnyCatchAttribute(monster.ServerNode)
end

local function pushNearbyCatchable(list, seen, monster, originPosition)
    local monsterId = getMonsterId(monster)
    if not monsterId or seen[monsterId] then
        return
    end
    if lastCatchAtById[monsterId] and os.clock() - lastCatchAtById[monsterId] < CFG.SAME_TARGET_COOLDOWN then
        return
    end

    local info = monster
    local position = getMonsterPosition(info)
    if not position then
        info = getMonsterInfoById(monsterId) or monster
        position = getMonsterPosition(info)
    end
    if not position then
        return
    end

    local distance = (originPosition - position).Magnitude
    if distance > CFG.RADIUS then
        return
    end

    seen[monsterId] = true
    table.insert(list, {
        id = monsterId,
        distance = distance,
    })
end

local function collectNearbyCatchableMonsters()
    local monsterMgr = getMonsterManager()
    local _, hrp = getCharacterAndRootPart()
    if not monsterMgr or not hrp then
        return {}
    end

    local list = {}
    local seen = {}

    if monsterMgr.IterSelfCanCatchBattleMonster then
        pcall(function()
            monsterMgr.IterSelfCanCatchBattleMonster(function(monster)
                pushNearbyCatchable(list, seen, monster, hrp.Position)
                return true
            end)
        end)
    end

    if monsterMgr.IterMonster then
        pcall(function()
            monsterMgr.IterMonster(function(monster)
                if isMonsterCatchable(monster) then
                    pushNearbyCatchable(list, seen, monster, hrp.Position)
                end
                return true
            end)
        end)
    end

    table.sort(list, function(a, b)
        return (a.distance or math.huge) < (b.distance or math.huge)
    end)
    return list
end

local function catchMonster(monsterId)
    if not PathTool.MonsterSystem then
        return false, "MonsterSystem_missing"
    end

    log("触发捕捉: MonsterId=%s", tostring(monsterId))

    if PathTool.MonsterSystem.ClientCatchMonsterStart then
        local ok, result = pcall(function()
            return PathTool.MonsterSystem.ClientCatchMonsterStart(monsterId)
        end)
        if not ok or result == false then
            return false, "start_failed:" .. tostring(result)
        end
        task.wait(CFG.START_TO_COMPLETE_DELAY)
    end

    if PathTool.MonsterSystem.ClientCatchMonsterComplete then
        local ok, result = pcall(function()
            return PathTool.MonsterSystem.ClientCatchMonsterComplete(monsterId)
        end)
        if not ok or result == false then
            return false, "complete_failed:" .. tostring(result)
        end
    end

    lastCatchAtById[monsterId] = os.clock()
    return true, "sent"
end

local function run()
    local started = os.clock()
    local sentCount = 0

    while CFG.RUN_FOREVER or os.clock() - started < CFG.SCAN_SECONDS do
        local targets = collectNearbyCatchableMonsters()
        if #targets > 0 then
            log("发现附近可捕捉数量=%d", #targets)
            for _, target in ipairs(targets) do
                log("可捕捉目标: MonsterId=%s 距离=%.1f", tostring(target.id), tonumber(target.distance) or -1)
                local ok, reason = catchMonster(target.id)
                if ok then
                    sentCount += 1
                    log("捕捉请求已发送: MonsterId=%s", tostring(target.id))
                else
                    warnLog("捕捉请求失败: MonsterId=%s 原因=%s", tostring(target.id), tostring(reason))
                end
                task.wait(CFG.AFTER_CATCH_DELAY)
            end
        end
        task.wait(CFG.SCAN_INTERVAL)
    end

    log("扫描结束，捕捉请求发送数量=%d", sentCount)
end

run()
