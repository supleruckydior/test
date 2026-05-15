local TARGET_GAME_ID = 98664161516921
if game.PlaceId ~= TARGET_GAME_ID then
    warn(string.format("[FindMonster] 游戏ID不匹配: %d (需要 %d)，脚本已禁用", game.PlaceId, TARGET_GAME_ID))
    _G.__FINDMONSTER_DISABLED = true
    return
end
-- hatchtestCURSOR.lua
-- 孵化界面：可选蛋、自动孵化、自动领取、自动跳过

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local TAG = "[HatchUI]"

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer

local ModuleCache = rawget(_G, "PathTool")
local GamePlayer = nil
local LogicNumber = nil
local MgrPetClient = nil
local directRequireModule = nil

local DIRECT_MODULE_PATHS = {
    CfgEgg = { "CommonConfig", "Egg", "CfgEgg" },
    ClientPlayerManager = { "CommonLibrary", "Player", "ClientPlayerManager" },
    EggSystem = { "CommonLogic", "Egg", "EggSystem" },
    EventSystem = { "CommonLibrary", "Base", "EventSystem" },
    ExchangeSystem = { "CommonLibrary", "Foundation", "ExchangeSystem" },
    LogicNumber = { "CommonLogic", "Fight", "Logic", "LogicNumber" },
    MgrPetClient = { "ClientLogic", "Pet", "MgrPetClient" },
    PetSystem = { "CommonLogic", "Pet", "PetSystem" },
    Utils = { "CommonLibrary", "Tool", "Utils" },
    ViewUtil = { "ClientLogic", "View", "ViewUtil" },
}

local PRELOAD_MODULES = {
    "Utils",
    "EventSystem",
    "ViewUtil",
    "ClientPlayerManager",
    "LogicNumber",
    "PetSystem",
    "MgrPetClient",
    "CfgEgg",
    "ExchangeSystem",
    "EggSystem",
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

local function installModuleCacheFallbacks()
    if not ModuleCache then
        return
    end

    if ModuleCache._HatchDirectRequireInstalled ~= true then
        ModuleCache._HatchDirectRequireInstalled = true
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
end

local function ensureModuleCache()
    if ModuleCache then
        installModuleCacheFallbacks()
        return true
    end
    if rawget(_G, "PathTool") then
        ModuleCache = rawget(_G, "PathTool")
        installModuleCacheFallbacks()
        return ModuleCache ~= nil
    end

    ModuleCache = {}
    _G.PathTool = ModuleCache
    installModuleCacheFallbacks()
    return true
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

local function WaitForModules(maxWait)
    maxWait = maxWait or 30
    ensureModuleCache()

    for _, moduleName in ipairs(PRELOAD_MODULES) do
        directRequireModule(moduleName)
    end

    MgrPetClient = MgrPetClient or directRequireModule("MgrPetClient")
    LogicNumber = LogicNumber or directRequireModule("LogicNumber")

    local waited = 0
    while not MgrPetClient do
        task.wait(0.1)
        waited = waited + 0.1
        if waited >= maxWait then
            warn(string.format("%s MgrPetClient 模块未找到，部分功能可能受影响", TAG))
            break
        end
        MgrPetClient = directRequireModule("MgrPetClient")
    end

    waited = 0
    while not GamePlayer do
        local success, result = pcall(function()
            return ModuleCache.ClientPlayerManager and ModuleCache.ClientPlayerManager.GetGamePlayer and ModuleCache.ClientPlayerManager.GetGamePlayer()
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

    print(string.format("%s [WaitForModules] ModuleCache=%s MgrPetClient=%s LogicNumber=%s GamePlayer=%s",
        TAG,
        ModuleCache and "OK" or "FAIL",
        MgrPetClient and "OK" or "FAIL",
        LogicNumber and "OK" or "FAIL",
        GamePlayer and "OK" or "FAIL"
    ))
    return true
end

WaitForModules(30)

local ALLOWED_PLAYER_NAMES = {
    savanndavid = true,
    josgwrp = true,
    wshg1341 = true,
}
local ALLOWED_PLAYER_LIST = "josgwrp / Savanndavid / wshg1341"
local currentPlayerNameKey = localPlayer and string.lower(localPlayer.Name) or ""
if not localPlayer or not ALLOWED_PLAYER_NAMES[currentPlayerNameKey] then
    warn(string.format("[MonsterTrackerWebUI] 未授权账号：%s（仅允许 %s 运行）", localPlayer and localPlayer.Name or "Unknown", ALLOWED_PLAYER_LIST))
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
    titleLabel = nil,
    refreshBtn = nil,
    closeBtn = nil,
    eggsTitle = nil,
    slotsTitle = nil,
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

local function clampNumber(value, minValue, maxValue)
    if maxValue < minValue then
        return minValue
    end
    return math.clamp(value, minValue, maxValue)
end

local function getViewportSize()
    local camera = workspace.CurrentCamera
    if camera and camera.ViewportSize then
        return camera.ViewportSize
    end
    return Vector2.new(1280, 720)
end

local function getUiMetrics()
    local viewport = getViewportSize()
    local mobile = UserInputService.TouchEnabled or viewport.X <= 760 or viewport.Y <= 520
    local margin = mobile and 12 or 0
    local maxWidth = math.max(180, viewport.X - margin * 2)
    local maxHeight = math.max(220, viewport.Y - margin * 2)
    local width = mobile and clampNumber(math.floor(maxWidth), math.min(260, maxWidth), 360) or FRAME_WIDTH
    local expandedHeight = mobile and math.min(maxHeight, 560) or FRAME_EXPANDED_HEIGHT

    return {
        viewport = viewport,
        mobile = mobile,
        margin = margin,
        width = width,
        expandedHeight = mobile and clampNumber(expandedHeight, math.min(260, maxHeight), 560) or expandedHeight,
        collapsedHeight = mobile and 44 or FRAME_COLLAPSED_HEIGHT,
        titleHeight = mobile and 44 or 36,
        buttonHeight = mobile and 34 or 26,
        titleButtonWidth = mobile and 52 or 42,
        outerPadding = mobile and 12 or 10,
        gap = mobile and 8 or 6,
        titleTextSize = mobile and 17 or 16,
        sectionTextSize = mobile and 14 or 13,
        buttonTextSize = mobile and 13 or 11,
        bodyTextSize = mobile and 12 or 10,
        rowTitleTextSize = mobile and 13 or 12,
        eggRowHeight = mobile and 52 or 42,
        slotRowHeight = mobile and 74 or 64,
        scrollBarThickness = mobile and 7 or 5,
    }
end

local function getFrameSize()
    local metrics = getUiMetrics()
    return metrics.width, State.collapsed and metrics.collapsedHeight or metrics.expandedHeight, metrics
end

local function clampFrameToViewport()
    if not Ui.frame then
        return
    end

    local width, height, metrics = getFrameSize()
    local pos = Ui.frame.Position
    local x = metrics.viewport.X * pos.X.Scale + pos.X.Offset
    local y = metrics.viewport.Y * pos.Y.Scale + pos.Y.Offset
    local minX = metrics.margin
    local minY = metrics.margin
    local maxX = math.max(minX, metrics.viewport.X - width - metrics.margin)
    local maxY = math.max(minY, metrics.viewport.Y - height - metrics.margin)
    Ui.frame.Position = UDim2.fromOffset(
        clampNumber(math.floor(x), minX, maxX),
        clampNumber(math.floor(y), minY, maxY)
    )
end

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
    if ModuleCache.ClientPlayerManager and ModuleCache.ClientPlayerManager.GetGamePlayer then
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
    local metrics = getUiMetrics()
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, sizeX or 78, 0, metrics.buttonHeight)
    btn.BackgroundColor3 = color
    btn.BorderSizePixel = 0
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Text = text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = metrics.buttonTextSize
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

local applyResponsiveLayout

local function applyCollapseVisual()
    if Ui.frame then
        local width, height = getFrameSize()
        Ui.frame.Size = UDim2.new(0, width, 0, height)
        clampFrameToViewport()
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
    applyResponsiveLayout()
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

local function setButtonLayout(btn, width, x, y, metrics)
    if not btn then
        return
    end
    btn.Size = UDim2.new(0, width, 0, metrics.buttonHeight)
    btn.Position = UDim2.new(0, x, 0, y)
    btn.TextSize = metrics.buttonTextSize
end

applyResponsiveLayout = function()
    if not Ui.frame then
        return
    end

    local width, height, metrics = getFrameSize()
    local pad = metrics.outerPadding
    local gap = metrics.gap
    State.lastViewportX = math.floor(metrics.viewport.X)
    State.lastViewportY = math.floor(metrics.viewport.Y)

    Ui.frame.Size = UDim2.new(0, width, 0, height)
    clampFrameToViewport()

    if Ui.titleBar then
        Ui.titleBar.Size = UDim2.new(1, 0, 0, metrics.titleHeight)
    end
    if Ui.titleLabel then
        local titleButtonsWidth = metrics.titleButtonWidth * 3 + gap * 4
        Ui.titleLabel.Size = UDim2.new(1, -(titleButtonsWidth + pad), 1, 0)
        Ui.titleLabel.Position = UDim2.new(0, pad, 0, 0)
        Ui.titleLabel.TextSize = metrics.titleTextSize
        Ui.titleLabel.TextTruncate = Enum.TextTruncate.AtEnd
    end

    local titleButtonY = math.floor((metrics.titleHeight - metrics.buttonHeight) / 2)
    local closeX = width - pad - metrics.titleButtonWidth
    local refreshX = closeX - gap - metrics.titleButtonWidth
    local collapseX = refreshX - gap - metrics.titleButtonWidth
    setButtonLayout(Ui.collapseBtn, metrics.titleButtonWidth, collapseX, titleButtonY, metrics)
    setButtonLayout(Ui.refreshBtn, metrics.titleButtonWidth, refreshX, titleButtonY, metrics)
    setButtonLayout(Ui.closeBtn, metrics.titleButtonWidth, closeX, titleButtonY, metrics)

    if State.collapsed then
        return
    end

    local controlsY = metrics.titleHeight + gap
    local controlWidth = math.floor((width - pad * 2 - gap) / 2)
    setButtonLayout(Ui.autoHatchBtn, controlWidth, pad, controlsY, metrics)
    setButtonLayout(Ui.autoSkipBtn, controlWidth, pad + controlWidth + gap, controlsY, metrics)

    local eggsTitleY = controlsY + metrics.buttonHeight + gap
    if Ui.eggsTitle then
        Ui.eggsTitle.Size = UDim2.new(1, -pad * 2, 0, 18)
        Ui.eggsTitle.Position = UDim2.new(0, pad, 0, eggsTitleY)
        Ui.eggsTitle.TextSize = metrics.sectionTextSize
    end

    local statusHeight = metrics.mobile and 26 or 20
    local statusY = height - statusHeight - gap
    if Ui.statusLabel then
        Ui.statusLabel.Size = UDim2.new(1, -pad * 2, 0, statusHeight)
        Ui.statusLabel.Position = UDim2.new(0, pad, 0, statusY)
        Ui.statusLabel.TextSize = metrics.buttonTextSize
        Ui.statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
    end

    local eggsScrollY = eggsTitleY + 20
    local slotsTitleHeight = 18
    local available = math.max(180, statusY - eggsScrollY - slotsTitleHeight - gap * 3)
    local eggsHeight = math.floor(available * (metrics.mobile and 0.44 or 0.46))
    eggsHeight = clampNumber(eggsHeight, metrics.mobile and 100 or 96, math.max(100, available - 96))
    local slotsTitleY = eggsScrollY + eggsHeight + gap
    local slotsScrollY = slotsTitleY + 20
    local slotsHeight = math.max(96, statusY - slotsScrollY - gap)

    if Ui.eggsScroll then
        Ui.eggsScroll.Size = UDim2.new(1, -pad * 2, 0, eggsHeight)
        Ui.eggsScroll.Position = UDim2.new(0, pad, 0, eggsScrollY)
        Ui.eggsScroll.ScrollBarThickness = metrics.scrollBarThickness
    end
    if Ui.slotsTitle then
        Ui.slotsTitle.Size = UDim2.new(1, -pad * 2, 0, slotsTitleHeight)
        Ui.slotsTitle.Position = UDim2.new(0, pad, 0, slotsTitleY)
        Ui.slotsTitle.TextSize = metrics.sectionTextSize
    end
    if Ui.slotsScroll then
        Ui.slotsScroll.Size = UDim2.new(1, -pad * 2, 0, slotsHeight)
        Ui.slotsScroll.Position = UDim2.new(0, pad, 0, slotsScrollY)
        Ui.slotsScroll.ScrollBarThickness = metrics.scrollBarThickness
    end
end

local function getEggList()
    local gp = getGamePlayer()
    local list = {}
    if not (gp and gp.egg and gp.egg.IterEgg and ModuleCache.CfgEgg and ModuleCache.CfgEgg.Tmpls) then
        return list
    end

    pcall(function()
        gp.egg:IterEgg(function(tmplId, amount)
            local cfg = ModuleCache.CfgEgg.Tmpls[tmplId]
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
    if not (gp and gp.egg and ModuleCache.CfgEgg and ModuleCache.CfgEgg.Hatchs) then
        return list
    end

    local now = ModuleCache.Utils.GetServerTime()
    for slotIndex, cfg in pairs(ModuleCache.CfgEgg.Hatchs) do
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

        if eggTmplId and ModuleCache.CfgEgg.Tmpls[eggTmplId] then
            local eggCfg = ModuleCache.CfgEgg.Tmpls[eggTmplId]
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
    local ok, result = doRequest(ModuleCache.EggSystem.ClientHatchStart, slotIndex, eggTmplId)
    if ok and result then
        local eggName = (ModuleCache.CfgEgg and ModuleCache.CfgEgg.Tmpls and ModuleCache.CfgEgg.Tmpls[eggTmplId] and ModuleCache.CfgEgg.Tmpls[eggTmplId].Name) or eggTmplId
        setStatus(string.format("槽位 %d 开始孵化 %s", slotIndex, tostring(eggName)), COLOR_OK)
        return true
    end
    return false
end

local function takeHatched(slotIndex)
    local ok, result = doRequest(ModuleCache.EggSystem.ClientHatchTaken, slotIndex)
    if ok and result then
        setStatus(string.format("槽位 %d 领取成功", slotIndex), COLOR_OK)
        return true
    end
    return false
end

local function skipHatch(slotIndex)
    local ok, result = doRequest(ModuleCache.EggSystem.ClientHatchSkip, slotIndex, true)
    if ok and result then
        setStatus(string.format("槽位 %d 已跳过", slotIndex), COLOR_WARN)
        return true
    end
    return false
end

local function unlockSlot(slotIndex)
    local ok, result = doRequest(ModuleCache.EggSystem.ClientHatchUnlock, slotIndex)
    if ok and result then
        setStatus(string.format("槽位 %d 解锁成功", slotIndex), COLOR_OK)
        return true
    end
    if ModuleCache.ExchangeSystem and ModuleCache.CfgEgg and ModuleCache.CfgEgg.Hatchs and ModuleCache.CfgEgg.Hatchs[slotIndex] then
        local cfg = ModuleCache.CfgEgg.Hatchs[slotIndex]
        if cfg.UnlockProductKey then
            local okBuy, buyResult = pcall(function()
                return ModuleCache.ExchangeSystem.BuyGoods(cfg.UnlockProductKey)
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
    local metrics = getUiMetrics()

    for i, egg in ipairs(eggs) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, -8, 0, metrics.eggRowHeight)
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
        title.TextSize = metrics.rowTitleTextSize
        title.TextTruncate = Enum.TextTruncate.AtEnd
        title.Text = string.format("%s x%s", egg.name, tostring(egg.amount))
        title.Parent = row

        local desc = Instance.new("TextLabel")
        desc.Size = UDim2.new(1, -12, 0, 16)
        desc.Position = UDim2.new(0, 8, 0, metrics.mobile and 26 or 22)
        desc.BackgroundTransparency = 1
        desc.TextXAlignment = Enum.TextXAlignment.Left
        desc.TextColor3 = COLOR_DIM
        desc.Font = Enum.Font.Gotham
        desc.TextSize = metrics.bodyTextSize
        desc.TextTruncate = Enum.TextTruncate.AtEnd
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
    local metrics = getUiMetrics()

    for i, slot in ipairs(slots) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, metrics.slotRowHeight)
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
        title.TextSize = metrics.rowTitleTextSize
        title.Text = string.format("槽位 %d", slot.slotIndex)
        title.Parent = row

        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, -(metrics.mobile and 104 or 100), 0, metrics.slotRowHeight - 30)
        info.Position = UDim2.new(0, 8, 0, 22)
        info.BackgroundTransparency = 1
        info.TextWrapped = true
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.TextYAlignment = Enum.TextYAlignment.Top
        info.TextColor3 = COLOR_DIM
        info.Font = Enum.Font.Gotham
        info.TextSize = metrics.bodyTextSize
        info.Parent = row

        if not slot.unlocked then
            info.Text = "状态: 未解锁"
            makeButton(row, "解锁", COLOR_BTN_SKIP, 60, function()
                if unlockSlot(slot.slotIndex) then
                    task.delay(0.2, refreshUi)
                else
                    setStatus(string.format("槽位 %d 解锁失败", slot.slotIndex), COLOR_ERR)
                end
            end).Position = UDim2.new(1, -(metrics.mobile and 76 or 68), 0.5, -math.floor(metrics.buttonHeight / 2))
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
            end).Position = UDim2.new(1, -(metrics.mobile and 76 or 68), 0.5, -math.floor(metrics.buttonHeight / 2))
        elseif slot.completed then
            info.Text = string.format("状态: 已完成\n鸡蛋: %s", tostring(slot.eggName or slot.eggTmplId))
            makeButton(row, "领取", COLOR_BTN_ON, 60, function()
                if takeHatched(slot.slotIndex) then
                    task.delay(0.2, refreshUi)
                else
                    setStatus(string.format("槽位 %d 领取失败", slot.slotIndex), COLOR_ERR)
                end
            end).Position = UDim2.new(1, -(metrics.mobile and 76 or 68), 0.5, -math.floor(metrics.buttonHeight / 2))
        else
            info.Text = string.format("状态: 孵化中\n%s | 剩余 %s", tostring(slot.eggName or slot.eggTmplId), formatTimeLeft(slot.leftTime))
            makeButton(row, "跳过", COLOR_BTN_SKIP, 60, function()
                if skipHatch(slot.slotIndex) then
                    task.delay(0.2, refreshUi)
                else
                    setStatus(string.format("槽位 %d 跳过失败", slot.slotIndex), COLOR_ERR)
                end
            end).Position = UDim2.new(1, -(metrics.mobile and 76 or 68), 0.5, -math.floor(metrics.buttonHeight / 2))
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
            local eggName = (ModuleCache.CfgEgg and ModuleCache.CfgEgg.Tmpls and ModuleCache.CfgEgg.Tmpls[State.selectedEggTmplId] and ModuleCache.CfgEgg.Tmpls[State.selectedEggTmplId].Name) or State.selectedEggTmplId
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
        clampFrameToViewport()
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
    local width, height, metrics = getFrameSize()

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "HatchTestCursorGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    Ui.screenGui = screenGui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, width, 0, height)
    if type(State.windowPosition) == "table" then
        frame.Position = UDim2.new(
            tonumber(State.windowPosition.xScale) or 0.5,
            tonumber(State.windowPosition.xOffset) or -math.floor(width / 2),
            tonumber(State.windowPosition.yScale) or 0.5,
            tonumber(State.windowPosition.yOffset) or -math.floor(height / 2)
        )
    else
        frame.Position = UDim2.new(0.5, -math.floor(width / 2), 0.5, -math.floor(height / 2))
    end
    frame.BackgroundColor3 = COLOR_BG
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = screenGui
    Ui.frame = frame
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, metrics.titleHeight)
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
    title.TextSize = metrics.titleTextSize
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = titleBar
    Ui.titleLabel = title

    Ui.collapseBtn = makeButton(titleBar, State.collapsed and "展开" or "收起", COLOR_BTN_OFF, 42, function()
        setCollapsed(not State.collapsed)
    end)
    Ui.collapseBtn.Position = UDim2.new(1, -142, 0.5, -13)

    Ui.refreshBtn = makeButton(titleBar, "刷新", COLOR_BTN, 42, function()
        setStatus("已刷新", COLOR_OK)
        refreshUi()
    end)
    Ui.refreshBtn.Position = UDim2.new(1, -96, 0.5, -13)

    Ui.closeBtn = makeButton(titleBar, "关闭", COLOR_ERR, 42, function()
        HatchTest.Destroy()
    end)
    Ui.closeBtn.Position = UDim2.new(1, -50, 0.5, -13)

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
    eggsTitle.TextSize = metrics.sectionTextSize
    eggsTitle.TextXAlignment = Enum.TextXAlignment.Left
    eggsTitle.Parent = frame
    Ui.eggsTitle = eggsTitle
    addCollapsible(eggsTitle)

    local eggsScroll = Instance.new("ScrollingFrame")
    eggsScroll.Size = UDim2.new(1, -20, 0, 128)
    eggsScroll.Position = UDim2.new(0, 10, 0, 96)
    eggsScroll.BackgroundColor3 = COLOR_PANEL
    eggsScroll.BorderSizePixel = 0
    eggsScroll.ScrollBarThickness = metrics.scrollBarThickness
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
    slotsTitle.TextSize = metrics.sectionTextSize
    slotsTitle.TextXAlignment = Enum.TextXAlignment.Left
    slotsTitle.Parent = frame
    Ui.slotsTitle = slotsTitle
    addCollapsible(slotsTitle)

    local slotsScroll = Instance.new("ScrollingFrame")
    slotsScroll.Size = UDim2.new(1, -20, 0, 146)
    slotsScroll.Position = UDim2.new(0, 10, 0, 252)
    slotsScroll.BackgroundColor3 = COLOR_PANEL
    slotsScroll.BorderSizePixel = 0
    slotsScroll.ScrollBarThickness = metrics.scrollBarThickness
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
    status.TextSize = metrics.buttonTextSize
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Parent = frame
    Ui.statusLabel = status
    addCollapsible(status)

    applyResponsiveLayout()
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

    local viewport = getViewportSize()
    if math.floor(viewport.X) ~= State.lastViewportX or math.floor(viewport.Y) ~= State.lastViewportY then
        applyResponsiveLayout()
        refreshUi()
    end

    if tick() - State.lastUiRefresh >= 1.0 then
        refreshUi()
    end

    runAutomationLoop()
end)

if ModuleCache.EventSystem then
    ModuleCache.EventSystem.RegisterListener("EggBagChange", refreshUi)
    ModuleCache.EventSystem.RegisterListener("EggHatchChange", refreshUi)
    table.insert(Conns, {
        Disconnect = function()
            pcall(function()
                ModuleCache.EventSystem.UnRegister("EggBagChange", refreshUi)
            end)
            pcall(function()
                ModuleCache.EventSystem.UnRegister("EggHatchChange", refreshUi)
            end)
        end
    })
end

_G.HatchTest = HatchTest
return HatchTest
