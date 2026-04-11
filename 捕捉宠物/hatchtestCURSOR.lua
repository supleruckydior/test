-- hatchtestCURSOR.lua
-- 孵化界面：可选蛋、自动孵化、自动领取、自动跳过

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local TAG = "[HatchUI]"
task.wait(6)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer

local PathTool = _G.PathTool
local GamePlayer = nil
local LogicNumber = nil
local MgrPetClient = nil

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
    while not MgrPetClient do
        task.wait(0.1)
        waited = waited + 0.1
        if waited >= maxWait then
            warn(string.format("%s MgrPetClient 模块未找到，部分功能可能受影响", TAG))
            break
        end
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

    print(string.format("%s [WaitForPathTool] PathTool=%s MgrPetClient=%s LogicNumber=%s GamePlayer=%s",
        TAG,
        PathTool and "OK" or "FAIL",
        MgrPetClient and "OK" or "FAIL",
        LogicNumber and "OK" or "FAIL",
        GamePlayer and "OK" or "FAIL"
    ))
    return true
end

WaitForPathTool(30)

if not localPlayer or localPlayer.Name ~= "Savanndavid" then
    warn(string.format("%s 当前用户不允许使用该脚本: %s", TAG, tostring(localPlayer and localPlayer.Name or "Unknown")))
    return
end

local HatchTest = {}
local State = {
    destroyed = false,
    selectedEggTmplId = nil,
    autoHatch = false,
    autoSkip = false,
    lastUiRefresh = 0,
    lastLoopAt = 0,
    windowPosition = nil,
    collapsed = false,
}

local Ui = {
    screenGui = nil,
    frame = nil,
    titleBar = nil,
    collapseBtn = nil,
    eggsScroll = nil,
    slotsScroll = nil,
    statusLabel = nil,
    autoHatchBtn = nil,
    autoSkipBtn = nil,
    collapsibleItems = {},
}

local Conns = {}

local MEMORY_FILE = string.format("hatchtest_memory_%s.json", tostring(localPlayer and localPlayer.UserId or "unknown"))

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

local function loadMemory()
    if not hasFileApi() then
        return
    end

    local readOk, content = pcall(function()
        if safeIsFile(MEMORY_FILE) or type(isfile) ~= "function" then
            return readfile(MEMORY_FILE)
        end
        return nil
    end)
    if not readOk or type(content) ~= "string" or content == "" then
        return
    end

    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(content)
    end)
    if not ok or type(decoded) ~= "table" then
        warn(string.format("%s 记忆读取失败，将使用默认设置", TAG))
        return
    end

    if type(decoded.selectedEggTmplId) == "number" then
        State.selectedEggTmplId = decoded.selectedEggTmplId
    end
    if type(decoded.autoHatch) == "boolean" then
        State.autoHatch = decoded.autoHatch
    end
    if type(decoded.autoSkip) == "boolean" then
        State.autoSkip = decoded.autoSkip
    end
    if type(decoded.windowPosition) == "table" then
        State.windowPosition = decoded.windowPosition
    end
    if type(decoded.collapsed) == "boolean" then
        State.collapsed = decoded.collapsed
    end
end

local function getMemoryPayload()
    local payload = {
        selectedEggTmplId = State.selectedEggTmplId,
        autoHatch = State.autoHatch,
        autoSkip = State.autoSkip,
        windowPosition = State.windowPosition,
        collapsed = State.collapsed,
        updatedAt = os.time(),
    }

    if Ui.frame then
        local pos = Ui.frame.Position
        payload.windowPosition = {
            xScale = pos.X.Scale,
            xOffset = pos.X.Offset,
            yScale = pos.Y.Scale,
            yOffset = pos.Y.Offset,
        }
        State.windowPosition = payload.windowPosition
    end

    return payload
end

local function saveMemory()
    if not hasFileApi() then
        return
    end

    local ok, err = pcall(function()
        writefile(MEMORY_FILE, HttpService:JSONEncode(getMemoryPayload()))
    end)
    if not ok then
        warn(string.format("%s 记忆保存失败: %s", TAG, tostring(err)))
    end
end

loadMemory()

local COLOR_BG = Color3.fromRGB(18, 20, 28)
local COLOR_PANEL = Color3.fromRGB(28, 32, 44)
local COLOR_PANEL_2 = Color3.fromRGB(34, 39, 54)
local COLOR_TEXT = Color3.fromRGB(240, 240, 245)
local COLOR_DIM = Color3.fromRGB(170, 175, 190)
local COLOR_OK = Color3.fromRGB(87, 201, 120)
local COLOR_WARN = Color3.fromRGB(240, 194, 92)
local COLOR_ERR = Color3.fromRGB(228, 96, 96)
local COLOR_BTN = Color3.fromRGB(73, 108, 180)
local COLOR_BTN_ON = Color3.fromRGB(94, 137, 84)
local COLOR_BTN_OFF = Color3.fromRGB(94, 94, 108)
local COLOR_BTN_SKIP = Color3.fromRGB(176, 112, 64)
local COLOR_SELECTED = Color3.fromRGB(59, 86, 132)

local FRAME_WIDTH = 210
local FRAME_EXPANDED_HEIGHT = 430
local FRAME_COLLAPSED_HEIGHT = 36

local function connect(signal, fn)
    local conn = signal:Connect(fn)
    table.insert(Conns, conn)
    return conn
end

local function disconnectAll()
    for _, conn in ipairs(Conns) do
        pcall(function()
            conn:Disconnect()
        end)
    end
    table.clear(Conns)
end

local function getGamePlayer()
    if GamePlayer then
        return GamePlayer
    end
    if PathTool.ClientPlayerManager and PathTool.ClientPlayerManager.GetGamePlayer then
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

local function setStatus(text, color)
    if Ui.statusLabel then
        Ui.statusLabel.Text = tostring(text or "")
        Ui.statusLabel.TextColor3 = color or COLOR_DIM
    end
end

local function formatTimeLeft(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%02d:%02d:%02d", h, m, s)
    end
    return string.format("%02d:%02d", m, s)
end

local function clearScrollingChildren(parent)
    if not parent then
        return
    end
    for _, child in ipairs(parent:GetChildren()) do
        if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
            child:Destroy()
        end
    end
end

local function makeButton(parent, text, color, sizeX, onClick)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, sizeX or 78, 0, 26)
    btn.BackgroundColor3 = color
    btn.BorderSizePixel = 0
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 11
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    if onClick then
        connect(btn.MouseButton1Click, onClick)
    end
    return btn
end

local function addCollapsible(inst)
    table.insert(Ui.collapsibleItems, inst)
    return inst
end

local function applyCollapseVisual()
    if Ui.frame then
        Ui.frame.Size = UDim2.new(0, FRAME_WIDTH, 0, State.collapsed and FRAME_COLLAPSED_HEIGHT or FRAME_EXPANDED_HEIGHT)
    end

    for _, inst in ipairs(Ui.collapsibleItems) do
        if inst and inst.Parent then
            inst.Visible = not State.collapsed
        end
    end

    if Ui.collapseBtn then
        Ui.collapseBtn.Text = State.collapsed and "展开" or "收起"
        Ui.collapseBtn.BackgroundColor3 = State.collapsed and COLOR_BTN_ON or COLOR_BTN_OFF
    end
end

local function setCollapsed(collapsed)
    State.collapsed = collapsed == true
    applyCollapseVisual()
    saveMemory()
end

local function updateToggleVisual()
    if Ui.autoHatchBtn then
        Ui.autoHatchBtn.Text = State.autoHatch and "孵化:开" or "孵化:关"
        Ui.autoHatchBtn.BackgroundColor3 = State.autoHatch and COLOR_BTN_ON or COLOR_BTN_OFF
    end
    if Ui.autoSkipBtn then
        Ui.autoSkipBtn.Text = State.autoSkip and "跳过:开" or "跳过:关"
        Ui.autoSkipBtn.BackgroundColor3 = State.autoSkip and COLOR_BTN_SKIP or COLOR_BTN_OFF
    end
end

local function getEggList()
    local gp = getGamePlayer()
    local list = {}
    if not (gp and gp.egg and gp.egg.IterEgg and PathTool.CfgEgg and PathTool.CfgEgg.Tmpls) then
        return list
    end

    pcall(function()
        gp.egg:IterEgg(function(tmplId, amount)
            local cfg = PathTool.CfgEgg.Tmpls[tmplId]
            if cfg and amount and amount > 0 then
                table.insert(list, {
                    tmplId = tmplId,
                    name = tostring(cfg.Name or ("Egg#" .. tostring(tmplId))),
                    amount = amount,
                    hatchTime = tonumber(cfg.HatchTime) or 0,
                })
            end
            return true
        end)
    end)

    table.sort(list, function(a, b)
        if a.name ~= b.name then
            return a.name < b.name
        end
        return a.tmplId < b.tmplId
    end)
    return list
end

local function getSlotList()
    local gp = getGamePlayer()
    local list = {}
    if not (gp and gp.egg and PathTool.CfgEgg and PathTool.CfgEgg.Hatchs) then
        return list
    end

    local now = PathTool.Utils.GetServerTime()
    for slotIndex, cfg in pairs(PathTool.CfgEgg.Hatchs) do
        local unlocked = false
        local eggTmplId = nil
        local startTick = nil
        local eggName = nil
        local leftTime = nil
        local completed = false

        pcall(function()
            unlocked = gp.egg:IsHatchUnlocked(slotIndex)
            eggTmplId = gp.egg:GetHatchEggTmplId(slotIndex)
            startTick = gp.egg:GetHatchEggStartTick(slotIndex)
        end)

        if eggTmplId and PathTool.CfgEgg.Tmpls[eggTmplId] then
            local eggCfg = PathTool.CfgEgg.Tmpls[eggTmplId]
            eggName = tostring(eggCfg.Name or eggTmplId)
            local finishAt = (tonumber(startTick) or 0) + (tonumber(eggCfg.HatchTime) or 0)
            leftTime = math.max(0, finishAt - now)
            completed = leftTime <= 0
        end

        table.insert(list, {
            slotIndex = slotIndex,
            unlocked = unlocked,
            eggTmplId = eggTmplId,
            eggName = eggName,
            leftTime = leftTime,
            completed = completed,
            unlockProductKey = cfg and cfg.UnlockProductKey,
            unlockCost = cfg and cfg.UnlockCost,
        })
    end

    table.sort(list, function(a, b)
        return a.slotIndex < b.slotIndex
    end)
    return list
end

local refreshUi

local function startHatch(slotIndex, eggTmplId)
    local ok, result = doRequest(PathTool.EggSystem.ClientHatchStart, slotIndex, eggTmplId)
    if ok and result then
        local eggName = (PathTool.CfgEgg and PathTool.CfgEgg.Tmpls and PathTool.CfgEgg.Tmpls[eggTmplId] and PathTool.CfgEgg.Tmpls[eggTmplId].Name) or eggTmplId
        setStatus(string.format("槽位 %d 开始孵化 %s", slotIndex, tostring(eggName)), COLOR_OK)
        return true
    end
    return false
end

local function takeHatched(slotIndex)
    local ok, result = doRequest(PathTool.EggSystem.ClientHatchTaken, slotIndex)
    if ok and result then
        setStatus(string.format("槽位 %d 领取成功", slotIndex), COLOR_OK)
        return true
    end
    return false
end

local function skipHatch(slotIndex)
    local ok, result = doRequest(PathTool.EggSystem.ClientHatchSkip, slotIndex, true)
    if ok and result then
        setStatus(string.format("槽位 %d 已跳过", slotIndex), COLOR_WARN)
        return true
    end
    return false
end

local function unlockSlot(slotIndex)
    local ok, result = doRequest(PathTool.EggSystem.ClientHatchUnlock, slotIndex)
    if ok and result then
        setStatus(string.format("槽位 %d 解锁成功", slotIndex), COLOR_OK)
        return true
    end
    if PathTool.ExchangeSystem and PathTool.CfgEgg and PathTool.CfgEgg.Hatchs and PathTool.CfgEgg.Hatchs[slotIndex] then
        local cfg = PathTool.CfgEgg.Hatchs[slotIndex]
        if cfg.UnlockProductKey then
            local okBuy, buyResult = pcall(function()
                return PathTool.ExchangeSystem.BuyGoods(cfg.UnlockProductKey)
            end)
            if okBuy and buyResult then
                setStatus(string.format("槽位 %d 购买解锁成功", slotIndex), COLOR_OK)
                return true
            end
        end
    end
    return false
end

local function renderEggs()
    clearScrollingChildren(Ui.eggsScroll)
    local eggs = getEggList()

    for i, egg in ipairs(eggs) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -8, 0, 42)
        row.BackgroundColor3 = (State.selectedEggTmplId == egg.tmplId) and COLOR_SELECTED or COLOR_PANEL_2
        row.BorderSizePixel = 0
        row.AutoButtonColor = false
        row.Text = ""
        row.LayoutOrder = i
        row.Parent = Ui.eggsScroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -12, 0, 18)
        title.Position = UDim2.new(0, 8, 0, 4)
        title.BackgroundTransparency = 1
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = COLOR_TEXT
        title.Font = Enum.Font.GothamBold
        title.TextSize = 12
        title.Text = string.format("%s x%s", egg.name, tostring(egg.amount))
        title.Parent = row

        local desc = Instance.new("TextLabel")
        desc.Size = UDim2.new(1, -12, 0, 16)
        desc.Position = UDim2.new(0, 8, 0, 22)
        desc.BackgroundTransparency = 1
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.TextColor3 = COLOR_DIM
        desc.Font = Enum.Font.Gotham
        desc.TextSize = 10
        desc.Text = string.format("ID=%s | 孵化=%s", tostring(egg.tmplId), formatTimeLeft(egg.hatchTime))
        desc.Parent = row

        connect(row.MouseButton1Click, function()
            State.selectedEggTmplId = egg.tmplId
            saveMemory()
            setStatus(string.format("已选中鸡蛋: %s", tostring(egg.name)), COLOR_OK)
            refreshUi()
        end)
    end

    local layout = Ui.eggsScroll:FindFirstChildOfClass("UIListLayout")
    Ui.eggsScroll.CanvasSize = UDim2.new(0, 0, 0, (layout and layout.AbsoluteContentSize.Y or 0) + 8)
end

local function renderSlots()
    clearScrollingChildren(Ui.slotsScroll)
    local slots = getSlotList()

    for i, slot in ipairs(slots) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 64)
        row.BackgroundColor3 = COLOR_PANEL_2
        row.BorderSizePixel = 0
        row.LayoutOrder = i
        row.Parent = Ui.slotsScroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -12, 0, 16)
        title.Position = UDim2.new(0, 8, 0, 4)
        title.BackgroundTransparency = 1
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextColor3 = COLOR_TEXT
        title.Font = Enum.Font.GothamBold
        title.TextSize = 12
        title.Text = string.format("槽位 %d", slot.slotIndex)
        title.Parent = row

        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, -100, 0, 34)
        info.Position = UDim2.new(0, 8, 0, 22)
        info.BackgroundTransparency = 1
        info.TextWrapped = true
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.TextYAlignment = Enum.TextYAlignment.Top
        info.TextColor3 = COLOR_DIM
        info.Font = Enum.Font.Gotham
        info.TextSize = 10
        info.Parent = row

        if not slot.unlocked then
            info.Text = "状态: 未解锁"
            makeButton(row, "解锁", COLOR_BTN_SKIP, 60, function()
                if unlockSlot(slot.slotIndex) then
                    task.delay(0.2, refreshUi)
                else
                    setStatus(string.format("槽位 %d 解锁失败", slot.slotIndex), COLOR_ERR)
                end
            end).Position = UDim2.new(1, -68, 0.5, -13)
        elseif not slot.eggTmplId then
            info.Text = "状态: 空闲"
            makeButton(row, "开始", COLOR_BTN, 60, function()
                if not State.selectedEggTmplId then
                    setStatus("请先在上方选中鸡蛋", COLOR_WARN)
                    return
                end
                if startHatch(slot.slotIndex, State.selectedEggTmplId) then
                    task.delay(0.2, refreshUi)
                else
                    setStatus(string.format("槽位 %d 开始失败", slot.slotIndex), COLOR_ERR)
                end
            end).Position = UDim2.new(1, -68, 0.5, -13)
        elseif slot.completed then
            info.Text = string.format("状态: 已完成\n鸡蛋: %s", tostring(slot.eggName or slot.eggTmplId))
            makeButton(row, "领取", COLOR_BTN_ON, 60, function()
                if takeHatched(slot.slotIndex) then
                    task.delay(0.2, refreshUi)
                else
                    setStatus(string.format("槽位 %d 领取失败", slot.slotIndex), COLOR_ERR)
                end
            end).Position = UDim2.new(1, -68, 0.5, -13)
        else
            info.Text = string.format("状态: 孵化中\n%s | 剩余 %s", tostring(slot.eggName or slot.eggTmplId), formatTimeLeft(slot.leftTime))
            makeButton(row, "跳过", COLOR_BTN_SKIP, 60, function()
                if skipHatch(slot.slotIndex) then
                    task.delay(0.2, refreshUi)
                else
                    setStatus(string.format("槽位 %d 跳过失败", slot.slotIndex), COLOR_ERR)
                end
            end).Position = UDim2.new(1, -68, 0.5, -13)
        end
    end

    local layout = Ui.slotsScroll:FindFirstChildOfClass("UIListLayout")
    Ui.slotsScroll.CanvasSize = UDim2.new(0, 0, 0, (layout and layout.AbsoluteContentSize.Y or 0) + 8)
end

refreshUi = function()
    if State.destroyed then
        return
    end
    renderEggs()
    renderSlots()
    updateToggleVisual()
    State.lastUiRefresh = tick()
end

local function runAutomationLoop()
    if State.destroyed then
        return
    end
    if tick() - State.lastLoopAt < 0.6 then
        return
    end
    State.lastLoopAt = tick()

    local slots = getSlotList()

    for _, slot in ipairs(slots) do
        if slot.completed then
            if takeHatched(slot.slotIndex) then
                task.delay(0.15, refreshUi)
                return
            end
        end
    end

    if State.autoSkip then
        for _, slot in ipairs(slots) do
            if slot.unlocked and slot.eggTmplId and (not slot.completed) then
                if skipHatch(slot.slotIndex) then
                    task.delay(0.15, refreshUi)
                    return
                end
            end
        end
    end

    if State.autoHatch and State.selectedEggTmplId then
        local gp = getGamePlayer()
        local eggAmount = 0
        pcall(function()
            eggAmount = gp.egg:GetEggAmount(State.selectedEggTmplId)
        end)
        if eggAmount <= 0 then
            local eggName = (PathTool.CfgEgg and PathTool.CfgEgg.Tmpls and PathTool.CfgEgg.Tmpls[State.selectedEggTmplId] and PathTool.CfgEgg.Tmpls[State.selectedEggTmplId].Name) or State.selectedEggTmplId
            setStatus(string.format("选中鸡蛋不足: %s", tostring(eggName)), COLOR_WARN)
            return
        end

        for _, slot in ipairs(slots) do
            if slot.unlocked and not slot.eggTmplId then
                if startHatch(slot.slotIndex, State.selectedEggTmplId) then
                    task.delay(0.15, refreshUi)
                    return
                end
            end
        end
    end
end

local function makeDraggable(handle, target)
    local dragging = false
    local dragStart
    local startPos

    local function update(input)
        local delta = input.Position - dragStart
        target.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    connect(handle.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            connect(input.Changed, function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    saveMemory()
                end
            end)
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
end

local function buildUI()
    local playerGui = localPlayer:WaitForChild("PlayerGui")
    local old = playerGui:FindFirstChild("HatchTestCursorGui")
    if old then
        old:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HatchTestCursorGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    Ui.screenGui = screenGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, FRAME_WIDTH, 0, State.collapsed and FRAME_COLLAPSED_HEIGHT or FRAME_EXPANDED_HEIGHT)
    if type(State.windowPosition) == "table" then
        frame.Position = UDim2.new(
            tonumber(State.windowPosition.xScale) or 0.5,
            tonumber(State.windowPosition.xOffset) or -105,
            tonumber(State.windowPosition.yScale) or 0.5,
            tonumber(State.windowPosition.yOffset) or -215
        )
    else
        frame.Position = UDim2.new(0.5, -105, 0.5, -215)
    end
    frame.BackgroundColor3 = COLOR_BG
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = screenGui
    Ui.frame = frame
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 36)
    titleBar.BackgroundColor3 = COLOR_BG
    titleBar.BorderSizePixel = 0
    titleBar.Parent = frame
    Ui.titleBar = titleBar
    makeDraggable(titleBar, frame)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -150, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "孵化界面"
    title.TextColor3 = COLOR_TEXT
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar

    Ui.collapseBtn = makeButton(titleBar, State.collapsed and "展开" or "收起", COLOR_BTN_OFF, 42, function()
        setCollapsed(not State.collapsed)
    end)
    Ui.collapseBtn.Position = UDim2.new(1, -142, 0.5, -13)

    makeButton(titleBar, "刷新", COLOR_BTN, 42, function()
        setStatus("已刷新", COLOR_OK)
        refreshUi()
    end).Position = UDim2.new(1, -96, 0.5, -13)

    makeButton(titleBar, "关闭", COLOR_ERR, 42, function()
        HatchTest.Destroy()
    end).Position = UDim2.new(1, -50, 0.5, -13)

    Ui.autoHatchBtn = addCollapsible(makeButton(frame, "自动孵化", COLOR_BTN_OFF, 90, function()
        State.autoHatch = not State.autoHatch
        updateToggleVisual()
        saveMemory()
        setStatus(State.autoHatch and "自动孵化已开启" or "自动孵化已关闭", COLOR_OK)
    end))
    Ui.autoHatchBtn.Position = UDim2.new(0, 10, 0, 42)

    Ui.autoSkipBtn = addCollapsible(makeButton(frame, "自动跳过", COLOR_BTN_OFF, 90, function()
        State.autoSkip = not State.autoSkip
        updateToggleVisual()
        saveMemory()
        setStatus(State.autoSkip and "自动跳过已开启" or "自动跳过已关闭", COLOR_WARN)
    end))
    Ui.autoSkipBtn.Position = UDim2.new(0, 108, 0, 42)

    local eggsTitle = Instance.new("TextLabel")
    eggsTitle.Size = UDim2.new(1, -20, 0, 16)
    eggsTitle.Position = UDim2.new(0, 10, 0, 76)
    eggsTitle.BackgroundTransparency = 1
    eggsTitle.Text = "鸡蛋背包"
    eggsTitle.TextColor3 = COLOR_TEXT
    eggsTitle.Font = Enum.Font.GothamBold
    eggsTitle.TextSize = 13
    eggsTitle.TextXAlignment = Enum.TextXAlignment.Left
    eggsTitle.Parent = frame
    addCollapsible(eggsTitle)

    local eggsScroll = Instance.new("ScrollingFrame")
    eggsScroll.Size = UDim2.new(1, -20, 0, 128)
    eggsScroll.Position = UDim2.new(0, 10, 0, 96)
    eggsScroll.BackgroundColor3 = COLOR_PANEL
    eggsScroll.BorderSizePixel = 0
    eggsScroll.ScrollBarThickness = 5
    eggsScroll.Parent = frame
    Ui.eggsScroll = eggsScroll
    addCollapsible(eggsScroll)
    Instance.new("UICorner", eggsScroll).CornerRadius = UDim.new(0, 8)

    local eggsLayout = Instance.new("UIListLayout")
    eggsLayout.Padding = UDim.new(0, 6)
    eggsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    eggsLayout.Parent = eggsScroll

    local eggsPadding = Instance.new("UIPadding")
    eggsPadding.PaddingTop = UDim.new(0, 6)
    eggsPadding.PaddingBottom = UDim.new(0, 6)
    eggsPadding.PaddingLeft = UDim.new(0, 6)
    eggsPadding.PaddingRight = UDim.new(0, 6)
    eggsPadding.Parent = eggsScroll

    local slotsTitle = Instance.new("TextLabel")
    slotsTitle.Size = UDim2.new(1, -20, 0, 16)
    slotsTitle.Position = UDim2.new(0, 10, 0, 232)
    slotsTitle.BackgroundTransparency = 1
    slotsTitle.Text = "孵化槽位"
    slotsTitle.TextColor3 = COLOR_TEXT
    slotsTitle.Font = Enum.Font.GothamBold
    slotsTitle.TextSize = 13
    slotsTitle.TextXAlignment = Enum.TextXAlignment.Left
    slotsTitle.Parent = frame
    addCollapsible(slotsTitle)

    local slotsScroll = Instance.new("ScrollingFrame")
    slotsScroll.Size = UDim2.new(1, -20, 0, 146)
    slotsScroll.Position = UDim2.new(0, 10, 0, 252)
    slotsScroll.BackgroundColor3 = COLOR_PANEL
    slotsScroll.BorderSizePixel = 0
    slotsScroll.ScrollBarThickness = 5
    slotsScroll.Parent = frame
    Ui.slotsScroll = slotsScroll
    addCollapsible(slotsScroll)
    Instance.new("UICorner", slotsScroll).CornerRadius = UDim.new(0, 8)

    local slotsLayout = Instance.new("UIListLayout")
    slotsLayout.Padding = UDim.new(0, 6)
    slotsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    slotsLayout.Parent = slotsScroll

    local slotsPadding = Instance.new("UIPadding")
    slotsPadding.PaddingTop = UDim.new(0, 6)
    slotsPadding.PaddingBottom = UDim.new(0, 6)
    slotsPadding.PaddingLeft = UDim.new(0, 6)
    slotsPadding.PaddingRight = UDim.new(0, 6)
    slotsPadding.Parent = slotsScroll

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -20, 0, 20)
    status.Position = UDim2.new(0, 10, 1, -24)
    status.BackgroundTransparency = 1
    status.Text = "就绪"
    status.TextColor3 = COLOR_OK
    status.Font = Enum.Font.Gotham
    status.TextSize = 11
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame
    Ui.statusLabel = status
    addCollapsible(status)

    applyCollapseVisual()
end

function HatchTest.SaveMemory()
    saveMemory()
end

function HatchTest.GetMemoryFile()
    return MEMORY_FILE
end

function HatchTest.SetCollapsed(collapsed)
    setCollapsed(collapsed == true)
end

function HatchTest.ToggleCollapsed()
    setCollapsed(not State.collapsed)
end

function HatchTest.Destroy()
    if State.destroyed then
        return
    end
    saveMemory()
    State.destroyed = true
    disconnectAll()
    if Ui.screenGui then
        Ui.screenGui:Destroy()
    end
    Ui.screenGui = nil
    if rawget(_G, "HatchTest") == HatchTest then
        _G.HatchTest = nil
    end
end

buildUI()
refreshUi()
setStatus("孵化界面已加载", COLOR_OK)

connect(RunService.Heartbeat, function()
    if State.destroyed then
        return
    end

    if tick() - State.lastUiRefresh >= 1.0 then
        refreshUi()
    end

    runAutomationLoop()
end)

if PathTool.EventSystem then
    PathTool.EventSystem.RegisterListener("EggBagChange", refreshUi)
    PathTool.EventSystem.RegisterListener("EggHatchChange", refreshUi)
    table.insert(Conns, {
        Disconnect = function()
            pcall(function()
                PathTool.EventSystem.UnRegister("EggBagChange", refreshUi)
            end)
            pcall(function()
                PathTool.EventSystem.UnRegister("EggHatchChange", refreshUi)
            end)
        end
    })
end

_G.HatchTest = HatchTest
return HatchTest
