local TARGET_GAME_ID = 98664161516921
if game.PlaceId ~= TARGET_GAME_ID then
    warn(string.format("[自动找怪110005] 游戏ID不匹配: %d (需要 %d)，脚本已禁用", game.PlaceId, TARGET_GAME_ID))
    return
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local TAG = "[自动找怪110005]"
local TARGET_TMPL_ID = 110005

-- 按“自动拾取”脚本的单循环风格：发现目标后忙等待，没发现时空闲等待。
local LOOP_WAIT_IDLE = 1.0
local LOOP_WAIT_BUSY = 0.25
local MODULE_WAIT_TIMEOUT = 20
local NO_MONSTER_SWITCH_DELAY = 10
local ENABLE_SERVER_SWITCH = false

-- 只寻找并打印；如果后续要发现后走近，把这个改 true。
local MOVE_TO_TARGET = false
local ATTACK_ON_FOUND = false
local STOP_DISTANCE = 18
local MOVE_REFRESH = 0.35

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local localPlayer = Players.LocalPlayer
local CONTROL_KEY = "__AUTO_FIND_MONSTER_110005_CONTROL"

local oldControl = rawget(_G, CONTROL_KEY)
if type(oldControl) == "table" then
    oldControl.running = false
end

local Control = {
    running = true,
    serverSwitchEnabled = ENABLE_SERVER_SWITCH,
    switchingServer = false,
    switchingStartedAt = 0,
    lastFoundId = nil,
    lastFoundAt = 0,
}
rawset(_G, CONTROL_KEY, Control)

local ModuleCache = {}
local serverHopPoolJobIds = {}
local serverHopPoolSeen = {}
local lastTeleportFailure = nil

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

_G.AutoFind110005Control = Control
_G.AutoFind110005SetServerSwitch = function(enabled)
    return Control.SetServerSwitch(enabled)
end
_G.AutoFind110005ToggleServerSwitch = function()
    return Control.ToggleServerSwitch()
end
_G.AutoFind110005Stop = function()
    return Control.Stop()
end

local function isExternalServerHopEnabled()
    local globalValue = rawget(_G, "G_serverhop")
    if globalValue == true then
        return true
    end

    local ok, envValue = pcall(function()
        return G_serverhop
    end)
    return ok and envValue == true
end

local function isServerSwitchEnabled()
    return Control.serverSwitchEnabled == true or isExternalServerHopEnabled()
end

local function frameSafeWait(seconds)
    local deadline = tick() + math.max(tonumber(seconds) or 0, 0)
    repeat
        task.wait(0.1)
    until tick() >= deadline or not Control.running
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

local function httpGetJson(url)
    local ok, decoded = pcall(function()
        local body = game:HttpGet(url)
        if body then
            return HttpService:JSONDecode(body)
        end
        return nil
    end)

    if not ok then
        warn(string.format("%s [HTTP] 请求失败: %s | 错误: %s", TAG, tostring(url), tostring(decoded)))
    end
    return ok, decoded
end

local function fetchPublicServerJobIds()
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true",
        game.PlaceId
    )

    print(string.format("%s [G_serverhop] 请求 Roblox 公共服务器列表: limit=100 excludeFullGames=true", TAG))
    local ok, decoded = httpGetJson(url)
    if not ok or type(decoded) ~= "table" or type(decoded.data) ~= "table" then
        return nil, "public_server_fetch_failed"
    end

    local jobIds = {}
    local seen = {}
    for _, server in ipairs(decoded.data) do
        local jobId = tostring(server and server.id or "")
        local playing = tonumber(server and server.playing or 0) or 0
        local maxPlayers = tonumber(server and server.maxPlayers or 0) or 0
        local hasRoom = maxPlayers <= 0 or playing < maxPlayers
        if jobId ~= "" and jobId ~= game.JobId and hasRoom and not seen[jobId] then
            seen[jobId] = true
            table.insert(jobIds, jobId)
        end
    end

    if #jobIds <= 0 then
        return jobIds, "public_pool_empty_or_full"
    end

    print(string.format("%s [G_serverhop] Roblox 返回服务器: %d 个，可用: %d 个", TAG, #decoded.data, #jobIds))
    return jobIds, "public-pool"
end

local function refillServerHopPool()
    local jobIds, err = fetchPublicServerJobIds()
    if type(jobIds) ~= "table" then
        return false, err or "public_pool_failed"
    end

    table.clear(serverHopPoolJobIds)
    for _, jobId in ipairs(jobIds) do
        if not serverHopPoolSeen[jobId] and jobId ~= game.JobId then
            table.insert(serverHopPoolJobIds, jobId)
        end
    end

    if #serverHopPoolJobIds <= 0 then
        table.clear(serverHopPoolSeen)
        for _, jobId in ipairs(jobIds) do
            if jobId ~= game.JobId then
                table.insert(serverHopPoolJobIds, jobId)
            end
        end
    end

    return #serverHopPoolJobIds > 0, string.format("%d (roblox-public)", #serverHopPoolJobIds)
end

local function takeServerHopJobId()
    if #serverHopPoolJobIds <= 0 then
        local ok, info = refillServerHopPool()
        if not ok then
            return nil, info
        end
        print(string.format("%s [G_serverhop] 已抓取服务器池: %s 个", TAG, tostring(info)))
    end

    if #serverHopPoolJobIds <= 0 then
        return nil, "public_pool_empty"
    end

    local index = math.random(1, #serverHopPoolJobIds)
    local jobId = table.remove(serverHopPoolJobIds, index)
    serverHopPoolSeen[jobId] = true
    return jobId, string.format("public-pool 剩余:%d", #serverHopPoolJobIds)
end

local function getTeleportFailureMessage()
    if not lastTeleportFailure then
        return nil
    end
    local age = tick() - (lastTeleportFailure.at or 0)
    if age > 10 then
        return nil
    end
    return string.format("%s / %s", tostring(lastTeleportFailure.result), tostring(lastTeleportFailure.message))
end

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
        if player == localPlayer then
            lastTeleportFailure = {
                at = tick(),
                result = teleportResult,
                message = errorMessage,
            }
            warn(string.format("%s [切服] TeleportInitFailed: %s %s", TAG, tostring(teleportResult), tostring(errorMessage)))
        end
    end)
end)

local function setCharacterAnchored(isAnchored)
    local character = localPlayer and localPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return false
    end
    root.Anchored = isAnchored == true
    return true
end

local function waitForJobIdChange(oldJobId, timeout)
    local deadline = tick() + math.max(tonumber(timeout) or 0, 0)
    repeat
        if game.JobId ~= oldJobId then
            return true
        end
        if getTeleportFailureMessage() then
            return false
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
    lastTeleportFailure = nil
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

    local changed = waitForJobIdChange(oldJobId, 3)
    if not changed then
        local failureMessage = getTeleportFailureMessage()
        if failureMessage then
            warn(string.format("%s [切服] 传送失败回调: %s", TAG, failureMessage))
        else
            warn(string.format("%s [切服] 传送超时，3s 内未切服", TAG))
        end
        setCharacterAnchored(false)
        return false
    end

    return true
end

local function switchServerForNoMonster()
    if Control.switchingServer then
        local switchingAge = tick() - (tonumber(Control.switchingStartedAt) or 0)
        if switchingAge < 5 then
            print(string.format("%s [切服] 已在切服中 %.1fs，跳过重复触发", TAG, switchingAge))
            return
        end

        warn(string.format("%s [切服] 切服状态卡住 %.1fs，强制复位后重试", TAG, switchingAge))
        Control.switchingServer = false
        Control.switchingStartedAt = 0
    end

    if not isServerSwitchEnabled() then
        return
    end

    Control.switchingServer = true
    Control.switchingStartedAt = tick()
    local oldJobId = game.JobId
    print(string.format(
        "%s [切服] 10秒未发现 TmplId=%d，开始切服: oldJob=%s G_serverhop=%s",
        TAG,
        TARGET_TMPL_ID,
        shortJobId(oldJobId),
        isExternalServerHopEnabled() and "开启" or "关闭"
    ))

    local function runSwitchLoop()
        local attempt = 0
        while Control.running and isServerSwitchEnabled() do
            attempt = attempt + 1
            local targetJobId, source = takeServerHopJobId()
            if targetJobId and targetJobId ~= oldJobId then
                print(string.format("%s [切服 第%d次] 获取到服务器: %s (%s)，正在传送", TAG, attempt, shortJobId(targetJobId), tostring(source)))
                if teleportToJob(targetJobId) then
                    return
                end
                warn(string.format("%s [切服 第%d次] 传送失败，3s 后切换下一个 JobId", TAG, attempt))
            else
                warn(string.format("%s [切服 第%d次] 获取服务器失败: %s", TAG, attempt, tostring(source)))
            end

            frameSafeWait(3)
        end

        Control.switchingServer = false
        Control.switchingStartedAt = 0
        setCharacterAnchored(false)
    end

    task.spawn(function()
        local ok, err = xpcall(runSwitchLoop, debug.traceback)
        if not ok then
            warn(string.format("%s [切服] 后台切服任务异常，已复位: %s", TAG, tostring(err)))
            Control.switchingServer = false
            Control.switchingStartedAt = 0
            setCharacterAnchored(false)
        end
    end)
end

local function waitForChildPath(root, path, timeout)
    local current = root
    local deadline = os.clock() + (tonumber(timeout) or 5)
    for _, name in ipairs(path) do
        local remaining = deadline - os.clock()
        if remaining <= 0 then
            return nil
        end
        local ok, child = pcall(function()
            return current:WaitForChild(name, remaining)
        end)
        if not ok or not child then
            return nil
        end
        current = child
    end
    return current
end

local function safeRequirePath(path, cacheName)
    if ModuleCache[cacheName] then
        return ModuleCache[cacheName]
    end

    local pathTool = rawget(_G, "PathTool")
    if pathTool and pathTool[cacheName] then
        ModuleCache[cacheName] = pathTool[cacheName]
        return ModuleCache[cacheName]
    end

    local moduleScript = waitForChildPath(ReplicatedStorage, path, 3)
    if not moduleScript then
        return nil
    end

    local ok, module = pcall(require, moduleScript)
    if ok and module then
        ModuleCache[cacheName] = module
        return module
    end
    return nil
end

local function waitForModules(timeout)
    local deadline = os.clock() + (tonumber(timeout) or MODULE_WAIT_TIMEOUT)
    while Control.running and os.clock() < deadline do
        safeRequirePath({ "ClientLogic", "Monster", "MgrMonsterClient" }, "MgrMonsterClient")
        safeRequirePath({ "CommonLogic", "Monster", "MonsterSystem" }, "MonsterSystem")

        if ModuleCache.MgrMonsterClient and type(ModuleCache.MgrMonsterClient.IterMonster) == "function" then
            return true
        end

        local pathTool = rawget(_G, "PathTool")
        if pathTool and pathTool.MgrMonsterClient and type(pathTool.MgrMonsterClient.IterMonster) == "function" then
            ModuleCache.MgrMonsterClient = pathTool.MgrMonsterClient
            return true
        end

        task.wait(0.5)
    end
    return false
end

local function getMonsterManager()
    if ModuleCache.MgrMonsterClient and type(ModuleCache.MgrMonsterClient.IterMonster) == "function" then
        return ModuleCache.MgrMonsterClient
    end

    local pathTool = rawget(_G, "PathTool")
    if pathTool then
        if pathTool.MgrMonsterClient and type(pathTool.MgrMonsterClient.IterMonster) == "function" then
            ModuleCache.MgrMonsterClient = pathTool.MgrMonsterClient
            return ModuleCache.MgrMonsterClient
        end
        if pathTool.MgrMonster and type(pathTool.MgrMonster.IterMonster) == "function" then
            return pathTool.MgrMonster
        end
    end

    waitForModules(3)
    return ModuleCache.MgrMonsterClient
end

local function getMonsterTemplateId(monster)
    if not monster then
        return nil
    end
    return tonumber(monster.TmplId or monster.TemplateId or monster.tmplId or monster.templateId)
end

local function isMonsterAlive(monster)
    if not monster then
        return false
    end

    if type(monster.IsAlive) == "function" then
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

local function getMonsterPosition(monster)
    if not monster then
        return nil
    end
    if typeof(monster.CurrentCFrame) == "CFrame" then
        return monster.CurrentCFrame.Position
    end
    if typeof(monster.Position) == "Vector3" then
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

local function getMonsterId(monster)
    if not monster then
        return nil
    end

    local directId = tonumber(monster.MonsterId or monster.monsterId or monster.Id or monster.id)
    if directId then
        return directId
    end

    local mgr = getMonsterManager()
    if mgr and type(mgr.GetMonsterIdByPart) == "function" and monster.Model then
        local part = nil
        if monster.Model:IsA("Model") then
            part = monster.Model.PrimaryPart
        elseif monster.Model:IsA("BasePart") then
            part = monster.Model
        end
        if part then
            local ok, id = pcall(function()
                return mgr.GetMonsterIdByPart(part)
            end)
            if ok and tonumber(id) then
                return tonumber(id)
            end
        end
    end

    if monster.ServerNode then
        return tonumber(tostring(monster.ServerNode.Name):match("(%d+)$"))
    end
    return nil
end

local function getCharacterParts()
    local character = localPlayer and localPlayer.Character
    if not character then
        return nil, nil, nil
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not humanoid or humanoid.Health <= 0 then
        return nil, nil, nil
    end
    return character, root, humanoid
end

local function findNearestTarget()
    local mgr = getMonsterManager()
    if not mgr or type(mgr.IterMonster) ~= "function" then
        return nil, "monster_manager_missing"
    end

    local _, root = getCharacterParts()
    local origin = root and root.Position or nil
    local nearest = nil
    local nearestDistance = math.huge
    local seen = 0

    local ok, err = pcall(function()
        mgr.IterMonster(function(monster)
            if getMonsterTemplateId(monster) == TARGET_TMPL_ID and isMonsterAlive(monster) then
                seen = seen + 1
                local pos = getMonsterPosition(monster)
                if pos then
                    local distance = origin and (origin - pos).Magnitude or 0
                    if not nearest or distance < nearestDistance then
                        nearestDistance = distance
                        nearest = {
                            monster = monster,
                            id = getMonsterId(monster),
                            position = pos,
                            distance = distance,
                        }
                    end
                end
            end
            return true
        end)
    end)

    if not ok then
        return nil, tostring(err)
    end
    if not nearest then
        return nil, seen > 0 and "target_has_no_position" or "target_missing"
    end
    return nearest, nil
end

local function attackMonster(monsterId)
    if not ATTACK_ON_FOUND or not monsterId then
        return false
    end

    local monsterSystem = safeRequirePath({ "CommonLogic", "Monster", "MonsterSystem" }, "MonsterSystem")
    if not monsterSystem then
        return false
    end

    if type(monsterSystem.ClientAttackMonsterOnHasAlivePet) == "function" then
        local ok, result = pcall(function()
            return monsterSystem.ClientAttackMonsterOnHasAlivePet(monsterId)
        end)
        if ok and result ~= false then
            return true
        end
    end

    if type(monsterSystem.ClientAttackMonster) == "function" then
        local ok, result = pcall(function()
            return monsterSystem.ClientAttackMonster(monsterId)
        end)
        return ok and result ~= false
    end
    return false
end

local function walkToward(target)
    if not MOVE_TO_TARGET or not target or not target.position then
        return false, "move_disabled"
    end

    local _, root, humanoid = getCharacterParts()
    if not root or not humanoid then
        return false, "character_not_ready"
    end

    local distance = (root.Position - target.position).Magnitude
    if distance <= STOP_DISTANCE then
        return true, "near"
    end

    local direction = target.position - root.Position
    if direction.Magnitude <= 0.1 then
        return true, "same_position"
    end

    local stopPoint = target.position - direction.Unit * STOP_DISTANCE
    local pathOk, path = pcall(function()
        return PathfindingService:CreatePath({
            AgentCanJump = true,
            AgentCanClimb = true,
        })
    end)

    if pathOk and path then
        local computeOk = pcall(function()
            path:ComputeAsync(root.Position, stopPoint)
        end)
        if computeOk and path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            local waypoint = waypoints[2] or waypoints[1]
            if waypoint then
                if waypoint.Action == Enum.PathWaypointAction.Jump then
                    humanoid.Jump = true
                end
                humanoid:MoveTo(waypoint.Position)
                return true, "path"
            end
        end
    end

    humanoid:MoveTo(stopPoint)
    return true, "direct"
end

print(string.format("%s 启动成功，玩家=%s，目标TmplId=%d", TAG, tostring(localPlayer and localPlayer.Name or "Unknown"), TARGET_TMPL_ID))
print(string.format("%s 行为: %s | 攻击: %s | 停止距离=%d", TAG, MOVE_TO_TARGET and "发现后走近" or "只打印", ATTACK_ON_FOUND and "开启" or "关闭", STOP_DISTANCE))
print(string.format("%s 无怪 %ds 切服: %s | G_serverhop=%s", TAG, NO_MONSTER_SWITCH_DELAY, isServerSwitchEnabled() and "开启" or "关闭", isExternalServerHopEnabled() and "开启" or "关闭"))

task.spawn(function()
    if not waitForModules(MODULE_WAIT_TIMEOUT) then
        warn(string.format("%s 模块未就绪：找不到 MgrMonsterClient.IterMonster", TAG))
    end

    local lastMissingLogAt = 0
    local lastFoundOrStartAt = tick()
    while Control.running do
        local foundTarget = false
        local ok, err = pcall(function()
            local target, reason = findNearestTarget()
            if not target then
                if os.clock() - lastMissingLogAt >= 5 then
                    lastMissingLogAt = os.clock()
                    print(string.format("%s 暂未发现活着的 TmplId=%d (%s)", TAG, TARGET_TMPL_ID, tostring(reason)))
                end

                if isServerSwitchEnabled() and not Control.switchingServer then
                    local idleSeconds = tick() - lastFoundOrStartAt
                    if idleSeconds >= NO_MONSTER_SWITCH_DELAY then
                        switchServerForNoMonster()
                    end
                end
                return
            end

            foundTarget = true
            lastFoundOrStartAt = tick()
            Control.lastFoundId = target.id
            Control.lastFoundAt = os.clock()

            print(string.format(
                "%s 发现目标 TmplId=%d MonsterId=%s 距离=%.1f 位置=(%.1f, %.1f, %.1f)",
                TAG,
                TARGET_TMPL_ID,
                tostring(target.id or "unknown"),
                tonumber(target.distance) or 0,
                target.position.X,
                target.position.Y,
                target.position.Z
            ))

            if MOVE_TO_TARGET then
                local moved, moveReason = walkToward(target)
                if moved then
                    print(string.format("%s 移动状态: %s", TAG, tostring(moveReason)))
                else
                    warn(string.format("%s 移动失败: %s", TAG, tostring(moveReason)))
                end
            end

            if ATTACK_ON_FOUND then
                local attacked = attackMonster(target.id)
                print(string.format("%s 攻击调用: %s", TAG, attacked and "成功" or "失败"))
            end
        end)

        if not ok then
            warn(string.format("%s 运行异常: %s", TAG, tostring(err)))
        end

        task.wait(foundTarget and LOOP_WAIT_BUSY or LOOP_WAIT_IDLE)
        if foundTarget then
            task.wait(MOVE_REFRESH)
        end
    end

    print(string.format("%s 已停止；重新执行脚本可再次启动", TAG))
end)
