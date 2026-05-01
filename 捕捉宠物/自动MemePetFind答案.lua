local TARGET_GAME_ID = 98664161516921
if game.PlaceId ~= TARGET_GAME_ID then
    warn(string.format("[FindMonster] 游戏ID不匹配: %d (需要 %d)，脚本已禁用", game.PlaceId, TARGET_GAME_ID))
    _G.__FINDMONSTER_DISABLED = true
    return
end
-- 自动识别 Meme Pet Find 正确格子并前往
-- 依据客户端同步数据 UpdateEventMemePetFind.Round 的 CellContents/CorrectVariantId 判断答案。

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")

local LocalPlayer = Players.LocalPlayer
local CommunicationUtil = require(ReplicatedStorage:WaitForChild("CommonLibrary")
    :WaitForChild("Tool")
    :WaitForChild("CommunicationUtil")
    :WaitForChild("CommunicationUtil"))

local AUTO_MEME_FIND = {
    enabled = true,
    moveOffsetY = 4,
    moveTimeout = 6,
    waypointTimeout = 2.5,
    lastRoundKey = "",
}

local function getCharacterParts()
    local character = LocalPlayer and LocalPlayer.Character
    if not character then
        return nil, nil, nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not root then
        return nil, nil, nil
    end

    return character, humanoid, root
end

local function getRuntimeZoneFolder(eventKey)
    local obbyEventFolder = Workspace:FindFirstChild("ObbyEventFolder")
    if not obbyEventFolder or not eventKey or eventKey == "" then
        return nil
    end

    local eventFolder = obbyEventFolder:FindFirstChild(tostring(eventKey))
    return eventFolder and eventFolder:FindFirstChild("MemePetFindRuntimeZones") or nil
end

local function getCorrectCellIds(roundPayload)
    local correct = {}
    local correctVariantId = tostring(roundPayload and roundPayload.CorrectVariantId or "")

    for _, cell in ipairs(roundPayload and roundPayload.CellContents or {}) do
        local cellId = cell and cell.CellId
        if cellId ~= nil then
            local isCorrect = cell.IsCorrect == true
            if not isCorrect and correctVariantId ~= "" then
                isCorrect = tostring(cell.VariantId or "") == correctVariantId
            end
            if isCorrect then
                table.insert(correct, tostring(cellId))
            end
        end
    end

    return correct
end

local function findCellPart(eventKey, cellIds)
    local folder = getRuntimeZoneFolder(eventKey)
    if not folder then
        return nil, "runtime_zone_missing"
    end

    local wanted = {}
    for _, cellId in ipairs(cellIds or {}) do
        wanted[tostring(cellId)] = true
    end

    local _, _, root = getCharacterParts()
    local bestPart = nil
    local bestDistance = math.huge

    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("BasePart") and wanted[tostring(child:GetAttribute("CellId") or "")] then
            local distance = root and (child.Position - root.Position).Magnitude or 0
            if distance < bestDistance then
                bestDistance = distance
                bestPart = child
            end
        end
    end

    return bestPart, bestPart and nil or "correct_cell_part_missing"
end

local function moveToPart(part)
    local _, humanoid, root = getCharacterParts()
    if not humanoid or not root then
        return false, "character_not_ready"
    end

    local target = part.Position + Vector3.new(0, AUTO_MEME_FIND.moveOffsetY, 0)
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        WaypointSpacing = 6,
    })

    local pathOk = pcall(function()
        path:ComputeAsync(root.Position, target)
    end)

    local waypoints = {}
    if pathOk and path.Status == Enum.PathStatus.Success then
        waypoints = path:GetWaypoints()
    else
        waypoints = {
            { Position = target, Action = Enum.PathWaypointAction.Walk },
        }
    end

    for _, waypoint in ipairs(waypoints) do
        if not AUTO_MEME_FIND.enabled then
            return false, "stopped"
        end
        if not part.Parent then
            return false, "target_removed"
        end

        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end

        humanoid:MoveTo(waypoint.Position)
        local reached = false
        local conn = humanoid.MoveToFinished:Connect(function(ok)
            reached = ok == true
        end)
        local startedAt = os.clock()
        while AUTO_MEME_FIND.enabled and not reached and os.clock() - startedAt < AUTO_MEME_FIND.waypointTimeout do
            task.wait(0.05)
        end
        conn:Disconnect()

        if not reached and (root.Position - waypoint.Position).Magnitude > 7 then
            return false, "move_timeout"
        end
    end

    local startedAt = os.clock()
    while AUTO_MEME_FIND.enabled and os.clock() - startedAt < AUTO_MEME_FIND.moveTimeout do
        if not part.Parent then
            return false, "target_removed"
        end
        if (root.Position - target).Magnitude <= math.max(5, part.Size.X * 0.5, part.Size.Z * 0.5) then
            return true
        end
        humanoid:MoveTo(target)
        task.wait(0.1)
    end

    return false, "target_not_reached"
end

local function handleRound(roundPayload)
    if not AUTO_MEME_FIND.enabled or type(roundPayload) ~= "table" then
        return
    end

    local phase = tostring(roundPayload.Phase or "")
    if phase ~= "Reveal" and phase ~= "Running" then
        return
    end

    local eventKey = tostring(roundPayload.EventKey or "")
    local roundKey = eventKey .. ":" .. tostring(roundPayload.RoundIndex or "") .. ":" .. phase
    if roundKey == AUTO_MEME_FIND.lastRoundKey then
        return
    end

    local correctCellIds = getCorrectCellIds(roundPayload)
    if #correctCellIds <= 0 then
        warn("[AutoMemeFind] 未找到正确 CellId", "phase=", phase, "variant=", tostring(roundPayload.CorrectVariantId))
        return
    end

    local part, findErr = findCellPart(eventKey, correctCellIds)
    if not part then
        warn("[AutoMemeFind] 未找到正确格子 Part", findErr, "eventKey=", eventKey, "cellId=", table.concat(correctCellIds, ","))
        return
    end

    AUTO_MEME_FIND.lastRoundKey = roundKey
    print("[AutoMemeFind] 前往正确格子", "phase=", phase, "cellId=", tostring(part:GetAttribute("CellId")), "part=", part:GetFullName())
    local ok, moveErr = moveToPart(part)
    if not ok then
        warn("[AutoMemeFind] 前往失败", moveErr)
    end
end

CommunicationUtil.GetClientProperty("UpdateEventMemePetFind", "Round"):Observe(handleRound)

print("[AutoMemeFind] 已启动：自动识别正确答案并前往")
