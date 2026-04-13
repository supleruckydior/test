-- Monster Tracker - Web UI (Top Left)
-- 数据来源：https://monster.suplucky.cc/api/monsters
-- 流程：弹窗输入卡密 -> 登录获取 session -> 直接轮询网站怪物数据

if not game:IsLoaded() then
    game.Loaded:Wait()
end

task.wait(6)

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local guiParent = game:GetService("CoreGui")

local player = Players.LocalPlayer
local screenGui = nil
local status = nil
local guideStatusLabel = nil
local fetchAndUpdate = nil

-- 运行限制：仅允许指定账号运行
local ALLOWED_PLAYER_NAMES = {
    savanndavid = true,
    josgwrp = true,
}
local ALLOWED_PLAYER_LIST = "josgwrp / Savanndavid"
local currentPlayerNameKey = player and string.lower(player.Name) or ""
if not player or not ALLOWED_PLAYER_NAMES[currentPlayerNameKey] then
    warn(string.format("[MonsterTrackerWebUI] 未授权账号：%s（仅允许 %s 运行）", player and player.Name or "Unknown", ALLOWED_PLAYER_LIST))
    return
end

local API_BASE = "https://monster.suplucky.cc"
local LOGIN_URL = API_BASE .. "/api/auth/login"
local MONSTERS_URL = API_BASE .. "/api/monsters"
local REFRESH_INTERVAL = 5.0 -- 秒：直接请求网站，降低Cloudflare请求量

local STORAGE_FOLDER = "MonsterTracker"
local USER_KEY = tostring((player and player.UserId) or (player and player.Name) or "Unknown"):gsub("[^%w_%-]", "_")
local CARD_KEY_FILE = STORAGE_FOLDER .. "/card_key_" .. USER_KEY .. ".txt"
local SETTINGS_FILE = STORAGE_FOLDER .. "/settings_" .. USER_KEY .. ".json"
local SESSION_FILE = STORAGE_FOLDER .. "/session_" .. USER_KEY .. ".json"
local BOSS_SERVER_POOL_FILE = STORAGE_FOLDER .. "/boss_servers_" .. USER_KEY .. ".json"

local cardKey = nil
local sessionCookie = nil
local sessionCreatedAt = 0
local loggedIn = false
local lastAuthMessage = ""

local BOSS_FARM = {
    WINDOWS = {
        { startMinute = 0, endMinute = 5 },
        { startMinute = 15, endMinute = 20 },
        { startMinute = 30, endMinute = 35 },
        { startMinute = 45, endMinute = 50 },
    },
    DETECT_SECONDS = 10,
    SERVER_SWITCH_RETRY_INTERVAL = 3,
    enabled = false,
    selectedBossId = 60006,
    statusLabel = nil,
    toggleBtn = nil,
    dropdownBtn = nil,
    dropdownFrame = nil,
    detectStartedAt = nil,
    trackingBoss = false,
    lastSwitchAttempt = 0,
    visitedJobs = {},
    serverPoolWindowKey = nil,
    serverPoolJobIds = {},
}

local AUTO_RIFT = {
    DETECT_RADIUS = 100,
    REACH_RADIUS = 10,
    WALK_TIMEOUT = 60,
    MONSTER_SEARCH_RADIUS = 600,
    MONSTER_REACH_RADIUS = 45,
    CATCH_WAIT_SECONDS = 10,
    CATCH_RESOLVE_TIMEOUT = 5,
    ARENA_TIMEOUT = 360,
    ENTER_TIMEOUT = 20,
    EXIT_TIMEOUT = 12,
    LEAVE_RETRY_INTERVAL = 0.8,
    LEFT_STABLE_SECONDS = 0.6,
    RECOVER_TIMEOUT = 120,
    FAILED_COOLDOWN = 45,
    WAYPOINT_REACH_RADIUS = 7,
    MOVE_REFRESH = 0.12,
    DIRECT_MOVE_DISTANCE = 120,
    DIRECT_MOVE_SECONDS = 1.4,
    DIRECT_FALLBACK_SECONDS = 2.2,
    WAYPOINT_TIMEOUT = 2.4,
    STUCK_CHECK_SECONDS = 0.85,
    STUCK_REPATH_SECONDS = 1.65,
    STUCK_MIN_MOVE = 1.1,
    MAX_REPATH_ATTEMPTS = 5,
    DISTANCE_PROGRESS_STEP = 0.85,
    APPROACH_SAMPLE_MIN_RADIUS = 2.5,
    APPROACH_SAMPLE_MAX_RADIUS = 6.5,
    APPROACH_SAMPLE_RADIUS_FACTOR = 0.75,
    APPROACH_OVERSHOOT_FACTOR = 0.55,
    SIDESTEP_DISTANCE = 3.5,
    SIDESTEP_LIMIT = 2,
    SIDESTEP_SECONDS = 0.22,
    JUMP_COOLDOWN = 0.55,
    JUMP_LOOKAHEAD_DISTANCE = 5.5,
    JUMP_HEIGHT_TRIGGER = 1.15,
}
local autoRiftEnabled = false
local autoRiftToggleBtn = nil
local autoRiftStatusLabel = nil
local autoRiftLastStatus = ""
local autoRiftRunning = false
local autoRiftFailedRifts = {}
local runAutoRiftOnce = nil

local AUTO_ABYSS = {
    DETECT_RADIUS = 160,
    REACH_RADIUS = 10,
    WALK_TIMEOUT = 60,
    ENTER_EXTRA_WAIT = 8,
    EXIT_TIMEOUT = 16,
    LEAVE_RETRY_INTERVAL = 0.8,
    LEFT_STABLE_SECONDS = 0.6,
    FAILED_COOLDOWN = 3,
    TALENT_REACH_RADIUS = 8,
    TALENT_WALK_TIMEOUT = 35,
    TALENT_RETRY_LIMIT = 3,
    TALENT_RECOVER_TIMEOUT = 12,
    MOVE_RETRY_LIMIT = 3,
    DOOR_REACH_RADIUS = 7,
    DOOR_WALK_TIMEOUT = 35,
    DOOR_CONFIRM_TIMEOUT = 6,
    DOOR_PROGRESS_TIMEOUT = 8,
    DOOR_RETRY_LIMIT = 3,
    MONSTER_SEARCH_RADIUS = 700,
    MONSTER_REACH_RADIUS = 45,
    UNKNOWN_TIMEOUT = 120,
    LOOP_DELAY = 0.5,
    enabled = false,
    running = false,
    joinEnabled = false,
    joinRunning = false,
    selectedTmplId = 1001,
    selectedPlayers = 1,
    selectedJoinOwnerUserId = nil,
    selectedJoinOwnerName = "任意房主",
    lastStatus = "",
    lastPrintedStatus = "",
    lastStatusPrintAt = 0,
    STATUS_PRINT_INTERVAL = 1.5,
    failedAt = {},
    toggleBtn = nil,
    statusLabel = nil,
    difficultyBtn = nil,
    difficultyFrame = nil,
    playerBtn = nil,
    playerFrame = nil,
    joinToggleBtn = nil,
    ownerBtn = nil,
    ownerFrame = nil,
    options = {
        { tmplId = 1001, label = "Normal" },
        { tmplId = 1002, label = "Hard" },
    },
    playerCounts = { 1, 2, 3, 4 },
    logEnabled = true,
    lootBtn = nil,
    lootFrame = nil,
    lootSummaryLabel = nil,
    lootListFrame = nil,
    lootRows = {},
    stats = {
        runCount = 0,
        successCount = 0,
        failCount = 0,
        totalDuration = 0,
        lootTotals = {},
    },
}
local runAutoAbyssOnce = nil
local runAutoAbyssJoinOnce = nil
local AbyssFlow = nil

local ACTIVE_ATTACK_RADIUS = 50
local ACTIVE_ATTACK_LOOP_DELAY = 0.12
local activeAttackEnabled = false
local activeAttackToggleBtn = nil
local activeAttackStatusLabel = nil
local activeAttackLastStatus = ""
local activeAttackRunning = false
local activeAttackTargetId = nil
local runActiveAttackOnce = nil

local BOSS_OPTIONS = {
    { id = 20007, label = "图2 Flaragon" },
    { id = 30007, label = "图3 Glazadon" },
    { id = 40006, label = "图4 ShadeKnight" },
    { id = 50006, label = "图5 Gildron" },
    { id = 60006, label = "图6 TideVex" },
    { id = 70006, label = "图7 Frostwyrm" },
    { id = 80005, label = "图8 Dracospike" },
    { id = 90006, label = "图9 Thunderclaw" },
}
pcall(function()
    math.randomseed(os.time() + (tonumber(USER_KEY) or 0))
end)

-- Undine指引相关
local UNDINE_TMPL_ID = 60005 -- Undine的怪物模板ID
local undineGuideEnabled = true -- 是否启用Undine指引（默认开启）
local undineGuideLine = nil -- 指引线条（包含多个part）
local undineGuideLabel = nil -- 距离标签
local DEBUG_UNDINE = false -- 调试模式：打印Undine属性

-- PathTool 依赖（按 捕捉宠物.lua 的方式加载）
local PathTool = rawget(_G, "PathTool")
local MgrPetClient = nil
local LogicNumber = nil
local GamePlayer = nil

local function WaitForPathTool(maxWait)
    maxWait = maxWait or 30
    local waited = 0

    if not PathTool then
        local success = pcall(function()
            PathTool = require(ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("PathTool"))
        end)
        if success and PathTool then
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
            warn("[MonsterTrackerWebUI] PathTool 系统未找到，请确保游戏已加载")
            return false
        end
        local success = pcall(function()
            PathTool = require(ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("PathTool"))
        end)
        if success and PathTool then
            _G.PathTool = PathTool
        end
        if not PathTool and _G.PathTool then
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
            warn("[MonsterTrackerWebUI] MgrPetClient 模块未找到，部分功能可能受影响")
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
        local ok, gamePlayer = pcall(function()
            return PathTool.ClientPlayerManager and PathTool.ClientPlayerManager.GetGamePlayer and PathTool.ClientPlayerManager.GetGamePlayer()
        end)
        if ok and gamePlayer then
            GamePlayer = gamePlayer
            break
        end
        pcall(function()
            GamePlayer = PathTool.GamePlayer and PathTool.GamePlayer.me or nil
        end)
        if GamePlayer then
            break
        end
        task.wait(0.5)
        waited = waited + 0.5
        if waited >= maxWait then
            warn("[MonsterTrackerWebUI] GamePlayer 未就绪，可能影响部分功能")
            break
        end
    end

    print(string.format(
        "[MonsterTrackerWebUI] [WaitForPathTool] PathTool=%s MgrPetClient=%s LogicNumber=%s GamePlayer=%s",
        PathTool and "OK" or "FAIL",
        MgrPetClient and "OK" or "FAIL",
        LogicNumber and "OK" or "FAIL",
        GamePlayer and "OK" or "FAIL"
    ))
    return PathTool ~= nil
end

-- 防重复创建
pcall(function()
    for _, uiName in ipairs({ "MonsterTracker_LocalUI", "MonsterTracker_WebUI" }) do
        local old = guiParent:FindFirstChild(uiName)
        if old then old:Destroy() end
    end
end)

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function maskCardKey(key)
    key = trim(key)
    if #key <= 8 then
        return "****"
    end
    return key:sub(1, 4) .. "****" .. key:sub(-4)
end

local function setStatusText(text, color)
    if status then
        status.Text = text
        if color then
            status.TextColor3 = color
        end
    end
end

local function getRequest()
    return request
        or (syn and syn.request)
        or http_request
        or (http and http.request)
        or (fluxus and fluxus.request)
end

local function httpRequest(options)
    local req = getRequest()
    if not req then
        return nil, "执行器不支持 request/syn.request，无法带 Cookie 访问网站"
    end

    local ok, res = pcall(req, options)
    if not ok then
        return nil, tostring(res)
    end
    if not res then
        return nil, "empty response"
    end

    return res
end

local function responseStatusCode(res)
    local code = tonumber(res and (res.StatusCode or res.status_code or res.Status or res.status)) or 0
    if code == 0 and res and res.Success == true then
        code = 200
    end
    return code
end

local function decodeJson(body)
    if type(body) ~= "string" or body == "" then
        return nil, "empty body"
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    if not ok then
        return nil, tostring(data)
    end
    return data
end

local function headerValue(headers, wantedName)
    if type(headers) ~= "table" then
        return nil
    end

    local wanted = tostring(wantedName):lower()
    for name, value in pairs(headers) do
        if tostring(name):lower() == wanted then
            return value
        end
    end
    return nil
end

local function extractSessionFromCookieValue(value)
    if type(value) == "table" then
        for _, item in pairs(value) do
            local cookie = extractSessionFromCookieValue(item)
            if cookie then
                return cookie
            end
        end
        return nil
    end

    local text = tostring(value or "")
    local token = text:match("session=([^;,%s]+)")
    if token and token ~= "" then
        return "session=" .. token
    end
    return nil
end

local function extractSessionCookie(headers, data)
    local cookie = extractSessionFromCookieValue(headerValue(headers, "set-cookie"))
    if cookie then
        return cookie
    end

    if type(data) == "table" then
        local token = data.session or data.session_id or data.sessionId
        if token and tostring(token) ~= "" then
            return "session=" .. tostring(token)
        end
    end

    return nil
end

local function ensureStorageFolder()
    if type(makefolder) ~= "function" then
        return
    end

    if type(isfolder) == "function" then
        local ok, exists = pcall(isfolder, STORAGE_FOLDER)
        if ok and exists then
            return
        end
    end

    pcall(makefolder, STORAGE_FOLDER)
end

local function readSavedCardKey()
    if type(readfile) ~= "function" then
        return nil
    end

    if type(isfile) == "function" then
        local ok, exists = pcall(isfile, CARD_KEY_FILE)
        if not ok or not exists then
            return nil
        end
    end

    local ok, contents = pcall(readfile, CARD_KEY_FILE)
    if ok and type(contents) == "string" then
        local saved = trim(contents)
        if saved ~= "" then
            return saved
        end
    end
    return nil
end

local function saveCardKey(key)
    key = trim(key)
    if key == "" then
        return false, "卡密为空"
    end
    if type(writefile) ~= "function" then
        return false, "执行器不支持 writefile，无法保存卡密"
    end

    ensureStorageFolder()
    local ok, err = pcall(writefile, CARD_KEY_FILE, key)
    if not ok then
        return false, tostring(err)
    end
    return true
end

local function readSavedSession()
    if type(readfile) ~= "function" then
        return nil
    end

    if type(isfile) == "function" then
        local ok, exists = pcall(isfile, SESSION_FILE)
        if not ok or not exists then
            return nil
        end
    end

    local ok, contents = pcall(readfile, SESSION_FILE)
    if not ok or type(contents) ~= "string" or contents == "" then
        return nil
    end

    local decodedOk, data = pcall(function()
        return HttpService:JSONDecode(contents)
    end)
    if not decodedOk or type(data) ~= "table" then
        return nil
    end

    local cookie = trim(data.sessionCookie or data.cookie or "")
    if cookie == "" then
        return nil
    end

    return {
        sessionCookie = cookie,
        sessionCreatedAt = tonumber(data.sessionCreatedAt) or 0,
        lastAuthMessage = tostring(data.lastAuthMessage or "session缓存"),
    }
end

local function saveSession()
    if type(writefile) ~= "function" or not sessionCookie or sessionCookie == "" then
        return false
    end

    ensureStorageFolder()
    local data = {
        sessionCookie = sessionCookie,
        sessionCreatedAt = sessionCreatedAt,
        lastAuthMessage = lastAuthMessage,
    }
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not ok then
        return false, tostring(encoded)
    end

    local writeOk, err = pcall(writefile, SESSION_FILE, encoded)
    if not writeOk then
        return false, tostring(err)
    end
    return true
end

local function clearSavedSession()
    sessionCookie = nil
    sessionCreatedAt = 0
    loggedIn = false

    if type(delfile) == "function" then
        if type(isfile) == "function" then
            local ok, exists = pcall(isfile, SESSION_FILE)
            if ok and exists then
                pcall(delfile, SESSION_FILE)
            end
        else
            pcall(delfile, SESSION_FILE)
        end
    elseif type(writefile) == "function" then
        pcall(writefile, SESSION_FILE, "")
    end
end

local function readTrackerSettings()
    if type(readfile) ~= "function" then
        return {}
    end

    if type(isfile) == "function" then
        local ok, exists = pcall(isfile, SETTINGS_FILE)
        if not ok or not exists then
            return {}
        end
    end

    local ok, contents = pcall(readfile, SETTINGS_FILE)
    if not ok or type(contents) ~= "string" or contents == "" then
        return {}
    end

    local decodedOk, data = pcall(function()
        return HttpService:JSONDecode(contents)
    end)
    if decodedOk and type(data) == "table" then
        return data
    end
    return {}
end

local function saveTrackerSettings()
    if type(writefile) ~= "function" then
        return false, "执行器不支持 writefile，无法保存设置"
    end

    ensureStorageFolder()
    local data = {
        bossFarmEnabled = bossFarmEnabled == true,
        selectedBossId = selectedBossId,
        autoRiftEnabled = autoRiftEnabled == true,
        autoAbyssEnabled = AUTO_ABYSS.enabled == true,
        selectedAbyssTmplId = AUTO_ABYSS.selectedTmplId,
        selectedAbyssPlayers = AUTO_ABYSS.selectedPlayers,
        activeAttackEnabled = activeAttackEnabled == true,
    }
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not ok then
        return false, tostring(encoded)
    end

    local writeOk, err = pcall(writefile, SETTINGS_FILE, encoded)
    if not writeOk then
        return false, tostring(err)
    end
    return true
end

local trackerSettings = readTrackerSettings()
bossFarmEnabled = trackerSettings.bossFarmEnabled == true
selectedBossId = tonumber(trackerSettings.selectedBossId) or selectedBossId
autoRiftEnabled = trackerSettings.autoRiftEnabled == true
AUTO_ABYSS.enabled = trackerSettings.autoAbyssEnabled == true
AUTO_ABYSS.selectedTmplId = tonumber(trackerSettings.selectedAbyssTmplId) or AUTO_ABYSS.selectedTmplId
AUTO_ABYSS.selectedPlayers = tonumber(trackerSettings.selectedAbyssPlayers) or AUTO_ABYSS.selectedPlayers
activeAttackEnabled = trackerSettings.activeAttackEnabled == true
do
    local isValidBossId = false
    for _, option in ipairs(BOSS_OPTIONS) do
        if option.id == selectedBossId then
            isValidBossId = true
            break
        end
    end
    if not isValidBossId then
        selectedBossId = 60006
    end
    local isValidAbyssTmplId = false
    for _, option in ipairs(AUTO_ABYSS.options) do
        if option.tmplId == AUTO_ABYSS.selectedTmplId then
            isValidAbyssTmplId = true
            break
        end
    end
    if not isValidAbyssTmplId then
        AUTO_ABYSS.selectedTmplId = 1001
    end
    AUTO_ABYSS.selectedPlayers = math.max(1, math.min(4, math.floor(tonumber(AUTO_ABYSS.selectedPlayers) or 1)))
end

local function clampNumber(value, minValue, maxValue)
    if maxValue < minValue then
        return minValue
    end
    return math.max(minValue, math.min(maxValue, value))
end

local function getViewportSize()
    local camera = workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    return Vector2.new(360, 640)
end

local function promptForCardKey(message, defaultKey)
    if not screenGui or not screenGui.Parent then
        return nil, "UI not ready"
    end

    local oldPrompt = screenGui:FindFirstChild("CardKeyPrompt")
    if oldPrompt then
        oldPrompt:Destroy()
    end

    local overlay = Instance.new("Frame")
    overlay.Name = "CardKeyPrompt"
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    overlay.BackgroundTransparency = 0.35
    overlay.BorderSizePixel = 0
    overlay.ZIndex = 40
    overlay.Parent = screenGui

    local viewportSize = getViewportSize()
    local dialogWidth = math.floor(math.min(320, math.max(260, viewportSize.X - 24)))
    local dialogHeight = 178
    local dialogX = math.floor((viewportSize.X - dialogWidth) / 2)
    local dialogY = math.floor((viewportSize.Y - dialogHeight) / 2)

    local dialog = Instance.new("Frame")
    dialog.Size = UDim2.new(0, dialogWidth, 0, dialogHeight)
    dialog.Position = UDim2.new(0, math.max(8, dialogX), 0, math.max(20, dialogY))
    dialog.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
    dialog.BorderSizePixel = 0
    dialog.ZIndex = 41
    dialog.Parent = overlay

    local dialogCorner = Instance.new("UICorner")
    dialogCorner.CornerRadius = UDim.new(0, 8)
    dialogCorner.Parent = dialog

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -24, 0, 24)
    titleLabel.Position = UDim2.new(0, 12, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14
    titleLabel.TextColor3 = Color3.fromRGB(0, 255, 136)
    titleLabel.Text = "Monster Tracker 卡密"
    titleLabel.ZIndex = 42
    titleLabel.Parent = dialog

    local hint = Instance.new("TextLabel")
    hint.Size = UDim2.new(1, -24, 0, 36)
    hint.Position = UDim2.new(0, 12, 0, 38)
    hint.BackgroundTransparency = 1
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 11
    hint.TextWrapped = true
    hint.TextColor3 = Color3.fromRGB(210, 210, 210)
    hint.Text = tostring(message or "请输入卡密，保存后会按当前 Roblox 用户读取。")
    hint.ZIndex = 42
    hint.Parent = dialog

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(1, -24, 0, 34)
    input.Position = UDim2.new(0, 12, 0, 82)
    input.BackgroundColor3 = Color3.fromRGB(35, 35, 46)
    input.BorderSizePixel = 0
    input.ClearTextOnFocus = false
    input.Font = Enum.Font.Gotham
    input.PlaceholderText = "XXXX-XXXX-XXXX-XXXX"
    input.Text = defaultKey or ""
    input.TextColor3 = Color3.fromRGB(255, 255, 255)
    input.PlaceholderColor3 = Color3.fromRGB(130, 130, 140)
    input.TextSize = 13
    input.ZIndex = 42
    input.Parent = dialog

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 6)
    inputCorner.Parent = input

    local note = Instance.new("TextLabel")
    note.Size = UDim2.new(1, -24, 0, 18)
    note.Position = UDim2.new(0, 12, 0, 120)
    note.BackgroundTransparency = 1
    note.TextXAlignment = Enum.TextXAlignment.Left
    note.Font = Enum.Font.Gotham
    note.TextSize = 10
    note.TextColor3 = Color3.fromRGB(170, 170, 180)
    note.Text = "当前用户: " .. tostring(player.Name) .. " / " .. tostring(player.UserId)
    note.ZIndex = 42
    note.Parent = dialog

    local submitBtn = Instance.new("TextButton")
    submitBtn.Size = UDim2.new(0, 120, 0, 28)
    submitBtn.Position = UDim2.new(1, -132, 1, -38)
    submitBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
    submitBtn.BorderSizePixel = 0
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.Text = "保存并登录"
    submitBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
    submitBtn.TextSize = 12
    submitBtn.ZIndex = 42
    submitBtn.Parent = dialog

    local submitCorner = Instance.new("UICorner")
    submitCorner.CornerRadius = UDim.new(0, 6)
    submitCorner.Parent = submitBtn

    local event = Instance.new("BindableEvent")
    local function submit()
        local value = trim(input.Text)
        if value == "" then
            note.Text = "请输入卡密"
            note.TextColor3 = Color3.fromRGB(255, 150, 150)
            return
        end
        event:Fire(value)
    end

    submitBtn.MouseButton1Click:Connect(submit)
    input.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            submit()
        end
    end)

    task.defer(function()
        pcall(function()
            input:CaptureFocus()
        end)
    end)

    local result = event.Event:Wait()
    overlay:Destroy()
    event:Destroy()
    return result
end

local function loginWithCardKey(key)
    key = trim(key)
    if key == "" then
        return false, "卡密为空", "auth"
    end

    local res, reqErr = httpRequest({
        Url = LOGIN_URL,
        Method = "POST",
        Headers = {
            ["Accept"] = "application/json",
            ["Content-Type"] = "application/json",
            ["Cache-Control"] = "no-cache",
            ["Pragma"] = "no-cache",
        },
        Body = HttpService:JSONEncode({ card_key = key })
    })
    if not res then
        return false, reqErr, "network"
    end

    local code = responseStatusCode(res)
    local data = nil
    local decodeErr = nil
    data, decodeErr = decodeJson(res.Body or "")
    if code == 0 and type(data) == "table" and data.success == true then
        code = 200
    end

    if code < 200 or code >= 300 or (type(data) == "table" and data.success == false) then
        local msg = "HTTP " .. tostring(code)
        if type(data) == "table" then
            msg = tostring(data.error or data.message or msg)
            if data.cooldown_remaining then
                msg = msg .. "，冷却 " .. tostring(data.cooldown_remaining) .. " 秒"
            end
        elseif decodeErr then
            msg = msg .. "，" .. tostring(decodeErr)
        end
        local kind = (code == 0 or code >= 500) and "network" or "auth"
        return false, msg, kind
    end

    local cookie = extractSessionCookie(res.Headers, data) or extractSessionFromCookieValue(res.Cookies)
    if not cookie then
        return false, "登录成功但未收到 session Cookie", "auth"
    end

    sessionCookie = cookie
    sessionCreatedAt = os.time()
    loggedIn = true
    lastAuthMessage = ""

    if type(data) == "table" then
        if data.remaining then
            lastAuthMessage = "剩余:" .. tostring(data.remaining)
        elseif data.expires_at then
            lastAuthMessage = "到期:" .. tostring(data.expires_at)
        end
    end

    print("[MonsterTrackerWebUI] 登录成功:", maskCardKey(key), lastAuthMessage)
    local savedSession, saveSessionErr = saveSession()
    if not savedSession and saveSessionErr then
        warn("[MonsterTrackerWebUI] session 未能保存:", saveSessionErr)
    end
    return true, nil, "ok"
end

local function ensureLoggedIn(forceRelogin)
    if not forceRelogin and loggedIn and sessionCookie then
        return true
    end

    if not forceRelogin and (not sessionCookie or sessionCookie == "") then
        local savedSession = readSavedSession()
        if savedSession then
            sessionCookie = savedSession.sessionCookie
            sessionCreatedAt = savedSession.sessionCreatedAt
            lastAuthMessage = savedSession.lastAuthMessage
            loggedIn = true
            print("[MonsterTrackerWebUI] 已读取本地 session:", SESSION_FILE)
            return true
        end
    end

    if not cardKey or cardKey == "" then
        cardKey = readSavedCardKey()
        if cardKey then
            print("[MonsterTrackerWebUI] 已读取本地卡密:", CARD_KEY_FILE, maskCardKey(cardKey))
        end
    end

    while true do
        if not cardKey or cardKey == "" then
            local inputKey = promptForCardKey("请输入网站卡密。保存后会按当前 Roblox 用户单独读取。", "")
            if not inputKey then
                return false, "未输入卡密"
            end
            cardKey = inputKey
        end

        setStatusText("状态：网站登录中...", Color3.fromRGB(255, 220, 120))
        local ok, err, kind = loginWithCardKey(cardKey)
        if ok then
            local saved, saveErr = saveCardKey(cardKey)
            if not saved then
                warn("[MonsterTrackerWebUI] 卡密未能保存:", saveErr)
            end
            return true
        end

        loggedIn = false
        sessionCookie = nil
        clearSavedSession()
        warn("[MonsterTrackerWebUI] 登录失败:", err)

        if kind == "network" then
            return false, err
        end

        local retryKey = promptForCardKey("登录失败：" .. tostring(err) .. "\n请重新输入卡密。", cardKey)
        if not retryKey then
            return false, err
        end
        cardKey = retryKey
        saveCardKey(cardKey)
    end
end

local function fetchRemoteMonsters(retried)
    local authOk, authErr = ensureLoggedIn(false)
    if not authOk then
        return nil, authErr
    end

    local res, reqErr = httpRequest({
        Url = MONSTERS_URL .. "?t=" .. tostring(DateTime.now().UnixTimestampMillis),
        Method = "GET",
        Headers = {
            ["Accept"] = "application/json",
            ["Cookie"] = sessionCookie,
            ["Cache-Control"] = "no-cache",
            ["Pragma"] = "no-cache",
        }
    })
    if not res then
        return nil, reqErr
    end

    local code = responseStatusCode(res)
    if (code == 401 or code == 403) and not retried then
        clearSavedSession()
        local reloginOk, reloginErr = ensureLoggedIn(true)
        if reloginOk then
            return fetchRemoteMonsters(true)
        end
        return nil, reloginErr
    end

    local data, decodeErr = decodeJson(res.Body or "")
    if code == 0 and type(data) == "table" and type(data.monsters) == "table" then
        code = 200
    end
    if code < 200 or code >= 300 then
        if code == 401 or code == 403 then
            clearSavedSession()
        end
        local msg = "HTTP " .. tostring(code)
        if type(data) == "table" then
            msg = tostring(data.error or data.message or msg)
        elseif decodeErr then
            msg = msg .. "，" .. tostring(decodeErr)
        end
        return nil, msg
    end

    if type(data) ~= "table" then
        return nil, "返回不是 JSON object"
    end
    if data.monsters == nil and #data > 0 then
        data = { monsters = data, count = #data }
    end
    if type(data.monsters) ~= "table" then
        return nil, "返回缺少 monsters 数组"
    end

    return data
end

local function safeTeleport(jobId)
    jobId = (jobId or ""):gsub("%s+", "")
    if jobId == "" then return false, "jobId empty" end

    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player)
    end)
    return ok, err
end

local function makeDraggable(targetFrame, handle)
    handle = handle or targetFrame
    handle.Active = true

    local dragging = false
    local dragStart = nil
    local startPosition = nil

    local function isDragInput(input)
        return input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch
    end

    handle.InputBegan:Connect(function(input)
        if not isDragInput(input) then
            return
        end

        dragging = true
        dragStart = input.Position
        startPosition = targetFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End or input.UserInputState == Enum.UserInputState.Cancel then
                dragging = false
            end
        end)
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging or not dragStart or not startPosition then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end

        local delta = input.Position - dragStart
        local viewportSize = getViewportSize()
        local margin = 4
        local maxX = math.max(margin, viewportSize.X - targetFrame.AbsoluteSize.X - margin)
        local maxY = math.max(margin, viewportSize.Y - targetFrame.AbsoluteSize.Y - margin)
        local nextX = clampNumber(startPosition.X.Offset + delta.X, margin, maxX)
        local nextY = clampNumber(startPosition.Y.Offset + delta.Y, margin, maxY)

        targetFrame.Position = UDim2.new(0, nextX, 0, nextY)
    end)
end

local function getBossOptionById(id)
    id = tonumber(id)
    for _, option in ipairs(BOSS_OPTIONS) do
        if option.id == id then
            return option
        end
    end
    return BOSS_OPTIONS[1]
end

local function getSelectedBossText()
    local option = getBossOptionById(selectedBossId)
    return string.format("%s (%s)", option.label, tostring(option.id))
end

local function setBossFarmStatus(text, color)
    if bossFarmStatusLabel then
        bossFarmStatusLabel.Text = text
        if color then
            bossFarmStatusLabel.TextColor3 = color
        end
    end
end

local function updateBossFarmControls()
    if bossFarmToggleBtn then
        bossFarmToggleBtn.Text = "刷Boss: " .. (bossFarmEnabled and "ON" or "OFF")
        bossFarmToggleBtn.BackgroundColor3 = bossFarmEnabled and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(60, 60, 75)
        bossFarmToggleBtn.TextColor3 = bossFarmEnabled and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
    end
    if bossDropdownBtn then
        bossDropdownBtn.Text = getSelectedBossText()
    end
end

local function setAutoRiftStatus(text, color)
    autoRiftLastStatus = text or ""
    local label = autoRiftStatusLabel
    if not label then
        return
    end

    pcall(function()
        if label.Parent then
            label.Text = autoRiftLastStatus
            if color then
                label.TextColor3 = color
            end
        end
    end)
end

local function updateAutoRiftControls()
    local button = autoRiftToggleBtn
    if not button then
        return
    end

    pcall(function()
        if button.Parent then
            button.Text = "刷Rift: " .. (autoRiftEnabled and "ON" or "OFF")
            button.BackgroundColor3 = autoRiftEnabled and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(60, 60, 75)
            button.TextColor3 = autoRiftEnabled and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        end
    end)
end

AUTO_ABYSS.getOptionByTmplId = function(tmplId)
    tmplId = tonumber(tmplId)
    for _, option in ipairs(AUTO_ABYSS.options) do
        if option.tmplId == tmplId then
            return option
        end
    end
    return AUTO_ABYSS.options[1]
end

AUTO_ABYSS.getDifficultyText = function()
    local option = AUTO_ABYSS.getOptionByTmplId(AUTO_ABYSS.selectedTmplId)
    return string.format("难度: %s (%s)", option.label, tostring(option.tmplId))
end

AUTO_ABYSS.getPlayerText = function()
    return string.format("人数: %d", tonumber(AUTO_ABYSS.selectedPlayers) or 1)
end

AUTO_ABYSS.formatOwnerPlayerName = function(targetPlayer)
    if not targetPlayer then
        return nil
    end
    local displayName = tostring(targetPlayer.DisplayName or "")
    local userName = tostring(targetPlayer.Name or "")
    if displayName ~= "" and userName ~= "" and string.lower(displayName) ~= string.lower(userName) then
        return string.format("%s (@%s)", displayName, userName)
    end
    return userName ~= "" and userName or displayName or ("UID " .. tostring(targetPlayer.UserId))
end

AUTO_ABYSS.findPlayerByUserId = function(userId)
    userId = tonumber(userId)
    if not userId then
        return nil
    end
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer.UserId == userId then
            return otherPlayer
        end
    end
    return nil
end

AUTO_ABYSS.getJoinOwnerPlayers = function()
    local otherPlayers = {}
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            table.insert(otherPlayers, otherPlayer)
        end
    end
    table.sort(otherPlayers, function(a, b)
        local aName = string.lower(AUTO_ABYSS.formatOwnerPlayerName(a) or tostring(a.UserId))
        local bName = string.lower(AUTO_ABYSS.formatOwnerPlayerName(b) or tostring(b.UserId))
        if aName == bName then
            return tonumber(a.UserId) < tonumber(b.UserId)
        end
        return aName < bName
    end)
    return otherPlayers
end

AUTO_ABYSS.setSelectedJoinOwner = function(userId, displayName)
    userId = tonumber(userId)
    if not userId or userId <= 0 then
        AUTO_ABYSS.selectedJoinOwnerUserId = nil
        AUTO_ABYSS.selectedJoinOwnerName = "任意房主"
        return
    end
    AUTO_ABYSS.selectedJoinOwnerUserId = userId
    local targetPlayer = AUTO_ABYSS.findPlayerByUserId(userId)
    AUTO_ABYSS.selectedJoinOwnerName = displayName or AUTO_ABYSS.formatOwnerPlayerName(targetPlayer) or ("UID " .. tostring(userId))
end

AUTO_ABYSS.validateSelectedJoinOwner = function()
    if not AUTO_ABYSS.selectedJoinOwnerUserId then
        AUTO_ABYSS.selectedJoinOwnerName = "任意房主"
        return nil
    end
    local targetPlayer = AUTO_ABYSS.findPlayerByUserId(AUTO_ABYSS.selectedJoinOwnerUserId)
    if not targetPlayer then
        AUTO_ABYSS.setSelectedJoinOwner(nil)
        return nil
    end
    AUTO_ABYSS.selectedJoinOwnerName = AUTO_ABYSS.formatOwnerPlayerName(targetPlayer) or AUTO_ABYSS.selectedJoinOwnerName or "任意房主"
    return targetPlayer
end

AUTO_ABYSS.getJoinText = function()
    return "自动入队: " .. (AUTO_ABYSS.joinEnabled and "ON" or "OFF")
end

AUTO_ABYSS.getOwnerText = function()
    AUTO_ABYSS.validateSelectedJoinOwner()
    return "房主: " .. tostring(AUTO_ABYSS.selectedJoinOwnerName or "任意房主")
end

AUTO_ABYSS.refreshOwnerDropdown = function()
    local ownerFrame = AUTO_ABYSS.ownerFrame
    if not ownerFrame then
        return
    end
    AUTO_ABYSS.validateSelectedJoinOwner()
    for _, child in ipairs(ownerFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then
            child:Destroy()
        end
    end

    local options = {
        {
            userId = nil,
            label = "任意房主",
        },
    }
    for _, otherPlayer in ipairs(AUTO_ABYSS.getJoinOwnerPlayers()) do
        table.insert(options, {
            userId = otherPlayer.UserId,
            label = AUTO_ABYSS.formatOwnerPlayerName(otherPlayer) or ("UID " .. tostring(otherPlayer.UserId)),
        })
    end

    for index, option in ipairs(options) do
        local optionBtn = Instance.new("TextButton")
        optionBtn.Size = UDim2.new(1, 0, 0, 22)
        optionBtn.LayoutOrder = index
        local isSelected = (option.userId == nil and AUTO_ABYSS.selectedJoinOwnerUserId == nil) or (tonumber(option.userId) == tonumber(AUTO_ABYSS.selectedJoinOwnerUserId))
        optionBtn.BackgroundColor3 = isSelected and Color3.fromRGB(52, 94, 78) or Color3.fromRGB(45, 45, 58)
        optionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        optionBtn.Font = Enum.Font.Gotham
        optionBtn.TextSize = 11
        optionBtn.TextXAlignment = Enum.TextXAlignment.Left
        optionBtn.TextTruncate = Enum.TextTruncate.AtEnd
        optionBtn.Text = "  " .. tostring(option.label)
        optionBtn.BorderSizePixel = 0
        optionBtn.ZIndex = 23
        optionBtn.Parent = ownerFrame

        local optionCorner = Instance.new("UICorner")
        optionCorner.CornerRadius = UDim.new(0, 5)
        optionCorner.Parent = optionBtn

        optionBtn.MouseButton1Click:Connect(function()
            AUTO_ABYSS.setSelectedJoinOwner(option.userId, option.label)
            ownerFrame.Visible = false
            AUTO_ABYSS.updateControls()
            AUTO_ABYSS.setStatus("自动入队: 已选择 " .. tostring(option.label), Color3.fromRGB(180, 180, 180))
        end)
    end

    local optionCount = math.max(1, #options)
    ownerFrame.CanvasSize = UDim2.new(0, 0, 0, optionCount * 24 + 8)
end

AUTO_ABYSS.isTmplUnlocked = function(tmplId)
    tmplId = tonumber(tmplId)
    if tmplId == 1001 then
        return true
    end
    if not PathTool then
        WaitForPathTool(3)
    end
    local tmpl = PathTool and PathTool.CfgAbyss and PathTool.CfgAbyss.Tmpls and PathTool.CfgAbyss.Tmpls[tmplId]
    if not tmpl then
        return false
    end
    if not tmpl.RequireTmplId then
        return true
    end
    local ok, gamePlayer = pcall(function()
        return PathTool.ClientPlayerManager and PathTool.ClientPlayerManager.GetGamePlayer and PathTool.ClientPlayerManager.GetGamePlayer()
    end)
    if not ok or not gamePlayer or not gamePlayer.abyss or not gamePlayer.abyss.IsAbyssCompleted then
        return false
    end
    local completedOk, completed = pcall(function()
        return gamePlayer.abyss:IsAbyssCompleted(tmpl.RequireTmplId)
    end)
    return completedOk and completed == true
end

AUTO_ABYSS.formatDetail = function(detail)
    if detail == nil then
        return ""
    end
    if type(detail) ~= "table" then
        return tostring(detail)
    end

    local parts = {}
    local count = 0
    for key, value in pairs(detail) do
        count = count + 1
        if count > 10 then
            table.insert(parts, "...")
            break
        end
        table.insert(parts, tostring(key) .. "=" .. tostring(value))
    end
    return table.concat(parts, ", ")
end

AUTO_ABYSS.log = function(action, detail, asWarn)
    if not AUTO_ABYSS.logEnabled then return end
    local text = "[AutoAbyss] " .. tostring(action or "")
    local detailText = AUTO_ABYSS.formatDetail(detail)
    if detailText ~= "" then
        text = text .. " | " .. detailText
    end
    if asWarn then
        warn(text)
    else
        print(text)
    end
end

AUTO_ABYSS.printFailureReason = function(reason, step)
    local parts = { "[AutoAbyss] 失败原因" }
    if step and step ~= "" then
        table.insert(parts, "step=" .. tostring(step))
    end
    table.insert(parts, "reason=" .. tostring(reason or "unknown"))
    warn(table.concat(parts, " | "))
end

AUTO_ABYSS.setStatus = function(text, color)
    AUTO_ABYSS.lastStatus = text or ""
    local now = os.clock()
    if AUTO_ABYSS.lastPrintedStatus ~= AUTO_ABYSS.lastStatus or now - (AUTO_ABYSS.lastStatusPrintAt or 0) >= AUTO_ABYSS.STATUS_PRINT_INTERVAL then
        AUTO_ABYSS.log("状态", AUTO_ABYSS.lastStatus)
        AUTO_ABYSS.lastPrintedStatus = AUTO_ABYSS.lastStatus
        AUTO_ABYSS.lastStatusPrintAt = now
    end

    local label = AUTO_ABYSS.statusLabel
    if not label then
        return
    end

    pcall(function()
        if label.Parent then
            label.Text = AUTO_ABYSS.lastStatus
            if color then
                label.TextColor3 = color
            end
        end
    end)
end

AUTO_ABYSS.updateControls = function()
    pcall(function()
        AUTO_ABYSS.validateSelectedJoinOwner()
        if AUTO_ABYSS.toggleBtn and AUTO_ABYSS.toggleBtn.Parent then
            AUTO_ABYSS.toggleBtn.Text = "自动Abyss: " .. (AUTO_ABYSS.enabled and "ON" or "OFF")
            AUTO_ABYSS.toggleBtn.BackgroundColor3 = AUTO_ABYSS.enabled and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(60, 60, 75)
            AUTO_ABYSS.toggleBtn.TextColor3 = AUTO_ABYSS.enabled and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        end
        if AUTO_ABYSS.difficultyBtn and AUTO_ABYSS.difficultyBtn.Parent then
            AUTO_ABYSS.difficultyBtn.Text = AUTO_ABYSS.getDifficultyText()
        end
        if AUTO_ABYSS.playerBtn and AUTO_ABYSS.playerBtn.Parent then
            AUTO_ABYSS.playerBtn.Text = AUTO_ABYSS.getPlayerText()
        end
        if AUTO_ABYSS.joinToggleBtn and AUTO_ABYSS.joinToggleBtn.Parent then
            AUTO_ABYSS.joinToggleBtn.Text = AUTO_ABYSS.getJoinText()
            AUTO_ABYSS.joinToggleBtn.BackgroundColor3 = AUTO_ABYSS.joinEnabled and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(60, 60, 75)
            AUTO_ABYSS.joinToggleBtn.TextColor3 = AUTO_ABYSS.joinEnabled and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        end
        if AUTO_ABYSS.ownerBtn and AUTO_ABYSS.ownerBtn.Parent then
            AUTO_ABYSS.ownerBtn.Text = AUTO_ABYSS.getOwnerText()
            AUTO_ABYSS.ownerBtn.BackgroundColor3 = AUTO_ABYSS.selectedJoinOwnerUserId and Color3.fromRGB(52, 94, 78) or Color3.fromRGB(45, 45, 58)
        end
    end)
end

AUTO_ABYSS.formatDuration = function(seconds)
    local total = math.max(0, math.floor(tonumber(seconds) or 0))
    local mins = math.floor(total / 60)
    local secs = total % 60
    return string.format("%02d:%02d", mins, secs)
end

AUTO_ABYSS.resolveRewardName = function(reward)
    if type(reward) ~= "table" then
        return "随机奖励"
    end

    local cfgName = nil
    pcall(function()
        if PathTool and PathTool.BakaUtil and PathTool.BakaUtil.GetRewardCfg then
            local cfg = PathTool.BakaUtil.GetRewardCfg(reward)
            if cfg and cfg.Name and cfg.Name ~= "" then
                cfgName = tostring(cfg.Name)
            end
        end
    end)
    if cfgName then
        return cfgName
    end

    if reward.RewardRes == "Value" then
        local valueCfg = PathTool and PathTool.ResourceConfig and PathTool.ResourceConfig.ValueTypes and PathTool.ResourceConfig.ValueTypes[reward.ValueType]
        if valueCfg and valueCfg.Name and valueCfg.Name ~= "" then
            return tostring(valueCfg.Name)
        end
        return tostring(reward.ValueType or "Value")
    end

    if reward.RewardRes == "CommonItem" then
        local itemCfg = PathTool and PathTool.CfgCommonItem and PathTool.CfgCommonItem.Tmpls and PathTool.CfgCommonItem.Tmpls[reward.TmplId]
        if itemCfg and itemCfg.Name and itemCfg.Name ~= "" then
            return tostring(itemCfg.Name)
        end
    elseif reward.RewardRes == "ConstItem" then
        local itemCfg = PathTool and PathTool.CfgConstItem and PathTool.CfgConstItem.Tmpls and PathTool.CfgConstItem.Tmpls[reward.TmplId]
        if itemCfg and itemCfg.Name and itemCfg.Name ~= "" then
            return tostring(itemCfg.Name)
        end
    end

    if reward.Name and reward.Name ~= "" then
        return tostring(reward.Name)
    end
    return tostring(reward.RewardRes or "Reward") .. " " .. tostring(reward.TmplId or "")
end

AUTO_ABYSS.refreshLootPanel = function()
    local summary = AUTO_ABYSS.lootSummaryLabel
    local listFrame = AUTO_ABYSS.lootListFrame
    if summary and summary.Parent then
        local stats = AUTO_ABYSS.stats or {}
        local runCount = tonumber(stats.runCount) or 0
        local successCount = tonumber(stats.successCount) or 0
        local failCount = tonumber(stats.failCount) or 0
        local avgSeconds = runCount > 0 and ((tonumber(stats.totalDuration) or 0) / runCount) or 0
        summary.Text = string.format(
            "平均时长: %s\n成功: %d    失败: %d    总场次: %d",
            AUTO_ABYSS.formatDuration(avgSeconds),
            successCount,
            failCount,
            runCount
        )
    end
    if not (listFrame and listFrame.Parent) then
        return
    end

    for _, row in ipairs(AUTO_ABYSS.lootRows or {}) do
        if row and row.Parent then
            row:Destroy()
        end
    end
    AUTO_ABYSS.lootRows = {}

    local lootTotals = (AUTO_ABYSS.stats and AUTO_ABYSS.stats.lootTotals) or {}
    local entries = {}
    for name, amount in pairs(lootTotals) do
        table.insert(entries, {
            name = tostring(name),
            amount = tonumber(amount) or 0,
        })
    end
    table.sort(entries, function(a, b)
        if a.amount == b.amount then
            return a.name < b.name
        end
        return a.amount > b.amount
    end)

    if #entries == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, -8, 0, 24)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Text = "暂无战利品统计"
        emptyLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.TextSize = 11
        emptyLabel.TextXAlignment = Enum.TextXAlignment.Left
        emptyLabel.Parent = listFrame
        table.insert(AUTO_ABYSS.lootRows, emptyLabel)
    else
        for index, entry in ipairs(entries) do
            local row = Instance.new("TextLabel")
            row.Size = UDim2.new(1, -8, 0, 22)
            row.LayoutOrder = index
            row.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
            row.BorderSizePixel = 0
            row.Text = string.format("  %s x%s", entry.name, tostring(entry.amount))
            row.TextColor3 = Color3.fromRGB(255, 255, 255)
            row.Font = Enum.Font.Gotham
            row.TextSize = 11
            row.TextXAlignment = Enum.TextXAlignment.Left
            row.Parent = listFrame
            local rowCorner = Instance.new("UICorner")
            rowCorner.CornerRadius = UDim.new(0, 5)
            rowCorner.Parent = row
            table.insert(AUTO_ABYSS.lootRows, row)
        end
    end

    local canvasHeight = math.max(30, #AUTO_ABYSS.lootRows * 24 + 8)
    listFrame.CanvasSize = UDim2.new(0, 0, 0, canvasHeight)
end

AUTO_ABYSS.recordLoot = function(reward)
    if type(reward) ~= "table" then
        return
    end
    local rewardName = AUTO_ABYSS.resolveRewardName(reward)
    local amount = tonumber(reward.Count) or 1
    AUTO_ABYSS.recordLootEntry(rewardName, amount)
end

AUTO_ABYSS.recordLootEntry = function(rewardName, amount)
    local stats = AUTO_ABYSS.stats
    if not stats then
        return
    end
    stats.lootTotals = stats.lootTotals or {}
    rewardName = tostring(rewardName or "未知奖励")
    amount = tonumber(amount) or 0
    if amount <= 0 then
        return
    end
    stats.lootTotals[rewardName] = (tonumber(stats.lootTotals[rewardName]) or 0) + amount
    AUTO_ABYSS.refreshLootPanel()
end

AUTO_ABYSS.recordRun = function(success, duration)
    local stats = AUTO_ABYSS.stats
    if not stats then
        return
    end
    stats.runCount = (tonumber(stats.runCount) or 0) + 1
    stats.totalDuration = (tonumber(stats.totalDuration) or 0) + math.max(0, tonumber(duration) or 0)
    if success then
        stats.successCount = (tonumber(stats.successCount) or 0) + 1
    else
        stats.failCount = (tonumber(stats.failCount) or 0) + 1
    end
    AUTO_ABYSS.refreshLootPanel()
end

AUTO_ABYSS.getGamePlayer = function()
    if PathTool and PathTool.ClientPlayerManager and PathTool.ClientPlayerManager.GetGamePlayer then
        local ok, gamePlayer = pcall(function()
            return PathTool.ClientPlayerManager.GetGamePlayer()
        end)
        if ok and gamePlayer then
            return gamePlayer
        end
    end
    if PathTool and PathTool.GamePlayer and PathTool.GamePlayer.me then
        return PathTool.GamePlayer.me
    end
    return nil
end

AUTO_ABYSS.logicNumberToNumber = function(value)
    if type(value) == "number" then
        return value
    end
    if type(value) == "string" then
        return tonumber(value) or 0
    end
    local logicNumber = PathTool and PathTool.LogicNumber
    if logicNumber and logicNumber.ToNumber then
        local ok, numberValue = pcall(function()
            return logicNumber.ToNumber(value)
        end)
        if ok and numberValue ~= nil then
            return tonumber(numberValue) or 0
        end
    end
    local ok, asString = pcall(function()
        return tostring(value)
    end)
    if ok then
        return tonumber(asString) or 0
    end
    return 0
end

AUTO_ABYSS.findItemContainer = function(gamePlayer, candidates)
    if not gamePlayer then
        return nil
    end
    for _, key in ipairs(candidates) do
        local container = nil
        pcall(function()
            container = gamePlayer[key]
        end)
        if container and (container.IterItem or container.GetItemAmount or container.GetItemCount) then
            return container
        end
    end
    return nil
end

AUTO_ABYSS.captureItemCounts = function(container, cfgTable)
    local totals = {}
    if not container then
        return totals
    end
    local iterated = false
    if container.IterItem then
        pcall(function()
            container:IterItem(function(item)
                if not item then
                    return true
                end
                local tmplId = nil
                local count = nil
                pcall(function() tmplId = item:GetTmplId() end)
                pcall(function() count = item:GetCount() end)
                tmplId = tonumber(tmplId)
                count = tonumber(count) or 0
                if tmplId and count > 0 then
                    totals[tmplId] = (totals[tmplId] or 0) + count
                    iterated = true
                end
                return true
            end)
        end)
    end
    if not iterated and container.GetItemAmount and type(cfgTable) == "table" then
        for tmplId, _ in pairs(cfgTable) do
            local amount = nil
            pcall(function()
                amount = container:GetItemAmount(tmplId)
            end)
            amount = tonumber(amount) or 0
            if amount > 0 then
                totals[tonumber(tmplId) or tmplId] = amount
            end
        end
    end
    return totals, iterated
end

AUTO_ABYSS.captureLootSnapshot = function()
    local snapshot = {
        values = {},
        commonItems = {},
        constItems = {},
    }
    local gamePlayer = AUTO_ABYSS.getGamePlayer()
    if not gamePlayer then
        return snapshot
    end

    local valueTypes = PathTool and PathTool.ResourceConfig and PathTool.ResourceConfig.ValueTypes
    if type(valueTypes) == "table" and gamePlayer.GetValue then
        for valueType, _ in pairs(valueTypes) do
            local currentValue = nil
            pcall(function()
                currentValue = gamePlayer:GetValue(valueType)
            end)
            snapshot.values[valueType] = AUTO_ABYSS.logicNumberToNumber(currentValue)
        end
    end

    local commonContainer = AUTO_ABYSS.findItemContainer(gamePlayer, { "commonItem", "commonItems", "item", "items", "bag", "itemBag" })
    local constContainer = AUTO_ABYSS.findItemContainer(gamePlayer, { "constItem", "constItems", "constBag" })
    snapshot.commonItems = AUTO_ABYSS.captureItemCounts(commonContainer, PathTool and PathTool.CfgCommonItem and PathTool.CfgCommonItem.Tmpls)
    snapshot.constItems = AUTO_ABYSS.captureItemCounts(constContainer, PathTool and PathTool.CfgConstItem and PathTool.CfgConstItem.Tmpls)
    return snapshot
end

AUTO_ABYSS.recordSnapshotDelta = function(beforeSnapshot, afterSnapshot)
    if type(beforeSnapshot) ~= "table" or type(afterSnapshot) ~= "table" then
        return
    end

    local valueTypes = PathTool and PathTool.ResourceConfig and PathTool.ResourceConfig.ValueTypes
    for valueType, afterValue in pairs(afterSnapshot.values or {}) do
        local beforeValue = tonumber((beforeSnapshot.values or {})[valueType]) or 0
        local delta = (tonumber(afterValue) or 0) - beforeValue
        if delta > 0 then
            local valueCfg = valueTypes and valueTypes[valueType]
            AUTO_ABYSS.recordLootEntry(valueCfg and valueCfg.Name or tostring(valueType), delta)
        end
    end

    local commonCfgs = PathTool and PathTool.CfgCommonItem and PathTool.CfgCommonItem.Tmpls
    for tmplId, afterCount in pairs(afterSnapshot.commonItems or {}) do
        local beforeCount = tonumber((beforeSnapshot.commonItems or {})[tmplId]) or 0
        local delta = (tonumber(afterCount) or 0) - beforeCount
        if delta > 0 then
            local cfg = commonCfgs and commonCfgs[tmplId]
            AUTO_ABYSS.recordLootEntry(cfg and cfg.Name or ("CommonItem " .. tostring(tmplId)), delta)
        end
    end

    local constCfgs = PathTool and PathTool.CfgConstItem and PathTool.CfgConstItem.Tmpls
    for tmplId, afterCount in pairs(afterSnapshot.constItems or {}) do
        local beforeCount = tonumber((beforeSnapshot.constItems or {})[tmplId]) or 0
        local delta = (tonumber(afterCount) or 0) - beforeCount
        if delta > 0 then
            local cfg = constCfgs and constCfgs[tmplId]
            AUTO_ABYSS.recordLootEntry(cfg and cfg.Name or ("ConstItem " .. tostring(tmplId)), delta)
        end
    end
end

local function setActiveAttackStatus(text, color)
    activeAttackLastStatus = text or ""
    local label = activeAttackStatusLabel
    if not label then
        return
    end

    pcall(function()
        if label.Parent then
            label.Text = activeAttackLastStatus
            if color then
                label.TextColor3 = color
            end
        end
    end)
end

local function updateActiveAttackControls()
    local button = activeAttackToggleBtn
    if not button then
        return
    end

    pcall(function()
        if button.Parent then
            button.Text = "主动打怪: " .. (activeAttackEnabled and "ON" or "OFF")
            button.BackgroundColor3 = activeAttackEnabled and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(60, 60, 75)
            button.TextColor3 = activeAttackEnabled and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
        end
    end)
end

local function getMonsterManager()
    if not PathTool then
        WaitForPathTool(10)
    end
    if not PathTool then
        return nil
    end

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

local function getMonsterTemplateId(monster)
    if not monster then
        return nil
    end
    return tonumber(monster.TmplId or monster.TemplateId or monster.tmplId or monster.templateId or monster.id or monster.monsterId)
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

local function FindMonsterByTmplId(tmplId)
    tmplId = tonumber(tmplId)
    if not tmplId then
        return nil
    end

    local monsterMgr = getMonsterManager()
    if not monsterMgr then
        return nil
    end

    local foundMonster = nil
    local ok, err = pcall(function()
        monsterMgr.IterMonster(function(monster)
            if getMonsterTemplateId(monster) == tmplId and isMonsterAlive(monster) then
                foundMonster = monster
                return false
            end
            return true
        end)
    end)
    if not ok then
        warn("[MonsterTrackerWebUI] FindMonsterByTmplId error:", err)
    end
    return foundMonster
end

local function getBossWindowInfo()
    local now = os.date("*t", os.time())
    local minute = tonumber(now.min) or 0
    local second = tonumber(now.sec) or 0

    for _, window in ipairs(BOSS_FARM_WINDOWS) do
        if minute >= window.startMinute and minute < window.endMinute then
            local remaining = (window.endMinute - minute) * 60 - second
            return true, math.max(0, remaining), window
        end
    end

    local nextStart = nil
    for _, window in ipairs(BOSS_FARM_WINDOWS) do
        if minute < window.startMinute then
            nextStart = window.startMinute
            break
        end
    end
    if not nextStart then
        nextStart = BOSS_FARM_WINDOWS[1].startMinute + 60
    end

    local waitSeconds = (nextStart - minute) * 60 - second
    return false, math.max(0, waitSeconds), nil
end

local function formatClockSeconds(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local minutes = math.floor(seconds / 60)
    local remainSeconds = seconds % 60
    return string.format("%02d:%02d", minutes, remainSeconds)
end

local function getBossWindowKey(window)
    if not window then
        return nil
    end

    local now = os.date("*t", os.time())
    return string.format(
        "%04d%02d%02d-%02d-%02d",
        tonumber(now.year) or 0,
        tonumber(now.month) or 0,
        tonumber(now.day) or 0,
        tonumber(now.hour) or 0,
        tonumber(window.startMinute) or 0
    )
end

local function readBossServerPool(windowKey)
    if type(readfile) ~= "function" then
        return nil, false
    end

    if type(isfile) == "function" then
        local ok, exists = pcall(isfile, BOSS_SERVER_POOL_FILE)
        if not ok or not exists then
            return nil, false
        end
    end

    local ok, contents = pcall(readfile, BOSS_SERVER_POOL_FILE)
    if not ok or type(contents) ~= "string" or contents == "" then
        return nil, false
    end

    local decodedOk, data = pcall(function()
        return HttpService:JSONDecode(contents)
    end)
    if not decodedOk or type(data) ~= "table" then
        return nil, false
    end
    if tostring(data.windowKey or "") ~= tostring(windowKey or "") then
        return nil, false
    end
    if tonumber(data.placeId) ~= game.PlaceId then
        return nil, false
    end

    local jobIds = {}
    if type(data.jobIds) == "table" then
        for _, jobId in ipairs(data.jobIds) do
            jobId = trim(jobId)
            if jobId ~= "" and jobId ~= game.JobId then
                table.insert(jobIds, jobId)
            end
        end
    end

    return jobIds, true
end

local function saveBossServerPool(windowKey, jobIds)
    if type(writefile) ~= "function" then
        return false, "执行器不支持 writefile，无法保存服务器池"
    end

    ensureStorageFolder()
    local data = {
        windowKey = windowKey,
        placeId = game.PlaceId,
        savedAt = os.time(),
        jobIds = jobIds or {},
    }
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not ok then
        return false, tostring(encoded)
    end

    local writeOk, err = pcall(writefile, BOSS_SERVER_POOL_FILE, encoded)
    if not writeOk then
        return false, tostring(err)
    end
    return true
end

local function fetchPublicServerJobIds()
    local url = string.format(
        "https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true",
        game.PlaceId
    )
    local res, reqErr = httpRequest({
        Url = url,
        Method = "GET",
        Headers = {
            ["Accept"] = "application/json",
            ["Cache-Control"] = "no-cache",
            ["Pragma"] = "no-cache",
        }
    })
    if not res then
        return nil, reqErr
    end

    local code = responseStatusCode(res)
    if code ~= 0 and (code < 200 or code >= 300) then
        return nil, "Roblox服务器列表HTTP " .. tostring(code)
    end

    local data, decodeErr = decodeJson(res.Body or "")
    if type(data) ~= "table" or type(data.data) ~= "table" then
        return nil, decodeErr or "公共服务器列表为空"
    end

    local candidates = {}
    local seen = {}
    for _, server in ipairs(data.data) do
        local jobId = trim(server.id or "")
        local playing = tonumber(server.playing or 0) or 0
        local maxPlayers = tonumber(server.maxPlayers or 0) or 0
        local hasRoom = maxPlayers <= 0 or playing < maxPlayers
        if jobId ~= "" and jobId ~= game.JobId and hasRoom and not seen[jobId] then
            seen[jobId] = true
            table.insert(candidates, jobId)
        end
    end

    return candidates, "public-pool"
end

local function ensureBossServerPoolForWindow(windowKey)
    if bossFarmServerPoolWindowKey == windowKey then
        return true, "memory-pool"
    end

    local savedJobIds, hasSavedPool = readBossServerPool(windowKey)
    if hasSavedPool then
        bossFarmServerPoolWindowKey = windowKey
        bossFarmServerPoolJobIds = savedJobIds or {}
        return true, "local-pool"
    end

    setBossFarmStatus("刷Boss: 拉取本窗口服务器池...", Color3.fromRGB(255, 220, 120))
    local fetchedJobIds, fetchErr = fetchPublicServerJobIds()
    if not fetchedJobIds then
        return false, fetchErr or "服务器池拉取失败"
    end

    bossFarmServerPoolWindowKey = windowKey
    bossFarmServerPoolJobIds = fetchedJobIds
    saveBossServerPool(windowKey, bossFarmServerPoolJobIds)
    return true, "fresh-pool"
end

local function takeBossServerJobId(window)
    local windowKey = getBossWindowKey(window)
    if not windowKey then
        return nil, "不在Boss窗口"
    end

    local ok, source = ensureBossServerPoolForWindow(windowKey)
    if not ok then
        return nil, source
    end

    if #bossFarmServerPoolJobIds <= 0 then
        return nil, "本窗口服务器池已空"
    end

    local index = math.random(1, #bossFarmServerPoolJobIds)
    local jobId = table.remove(bossFarmServerPoolJobIds, index)
    saveBossServerPool(windowKey, bossFarmServerPoolJobIds)

    return jobId, string.format("%s 剩余:%d", source or "pool", #bossFarmServerPoolJobIds)
end

local function tryBossServerSwitch(reason)
    local now = os.clock()
    if now - bossFarmLastSwitchAttempt < BOSS_SERVER_SWITCH_RETRY_INTERVAL then
        return false, "等待换服间隔"
    end
    bossFarmLastSwitchAttempt = now

    local inWindow, _, window = getBossWindowInfo()
    if not inWindow then
        return false, "不在Boss窗口"
    end

    local jobId, source = takeBossServerJobId(window)
    if not jobId then
        return false, source or "没有候选服务器"
    end

    bossFarmVisitedJobs[jobId] = true
    setBossFarmStatus("刷Boss: 换服中 " .. tostring(reason or source), Color3.fromRGB(255, 220, 120))
    local ok, err = safeTeleport(jobId)
    if not ok then
        bossFarmVisitedJobs[jobId] = nil
        return false, tostring(err)
    end
    return true
end

do
local function getCharacterAndRootPart()
    local character = player and player.Character
    if not character then
        return nil, nil
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    return character, hrp
end

local function getGamePlayer()
    if not PathTool then
        WaitForPathTool(10)
    end
    if not PathTool or not PathTool.ClientPlayerManager or not PathTool.ClientPlayerManager.GetGamePlayer then
        return nil
    end

    local ok, gamePlayer = pcall(function()
        return PathTool.ClientPlayerManager.GetGamePlayer()
    end)
    if ok then
        return gamePlayer
    end
    return nil
end

local function interruptibleWait(seconds, shouldContinue)
    local deadline = os.clock() + math.max(0, tonumber(seconds) or 0)
    while os.clock() < deadline do
        if shouldContinue and not shouldContinue() then
            return false
        end
        task.wait(math.min(0.25, math.max(0.03, deadline - os.clock())))
    end
    return true
end

local function logicNumberToNumber(value)
    if value == nil then
        return nil
    end
    if type(value) == "number" then
        return value
    end
    if PathTool and PathTool.LogicNumber and PathTool.LogicNumber.ToNumber then
        local ok, numberValue = pcall(function()
            return PathTool.LogicNumber.ToNumber(value)
        end)
        if ok and type(numberValue) == "number" then
            return numberValue
        end
    end
    return tonumber(tostring(value))
end

local function getPetItemVitals(petItem)
    if not petItem then
        return nil
    end

    local state = {
        hp = nil,
        maxHp = nil,
        hpPct = nil,
        dead = false,
    }

    pcall(function()
        if type(petItem.IsDead) == "function" and petItem:IsDead() == true then
            state.dead = true
        end
    end)
    if not state.dead then
        pcall(function()
            if type(petItem.IsAlive) == "function" then
                local alivePet = petItem:IsAlive()
                if alivePet ~= nil then
                    state.dead = not alivePet
                end
            end
        end)
    end

    local itemKey = nil
    if PathTool and PathTool.PetItem and PathTool.PetItem.BuildItemKey then
        pcall(function()
            itemKey = PathTool.PetItem.BuildItemKey(petItem)
        end)
    end
    if itemKey and PathTool and PathTool.MgrPetClient and PathTool.MgrPetClient.GetSelfPetInfo then
        local petObj = PathTool.MgrPetClient.GetSelfPetInfo(itemKey)
        if petObj and petObj.HealthValue then
            pcall(function()
                state.hp = petObj.HealthValue.Value
                state.maxHp = petObj.HealthValue:GetAttribute("MaxHealth")
            end)
        end
    end
    if state.hp == nil or state.maxHp == nil then
        pcall(function()
            if petItem.HealthValue then
                state.hp = petItem.HealthValue.Value
                state.maxHp = petItem.HealthValue:GetAttribute("MaxHealth")
            end
        end)
    end
    if (state.hp == nil or state.maxHp == nil) and petItem.GetHealth and petItem.GetMaxHealth then
        pcall(function()
            state.hp = petItem:GetHealth()
            state.maxHp = petItem:GetMaxHealth()
        end)
    end

    local hpNum = logicNumberToNumber(state.hp)
    local maxHpNum = logicNumberToNumber(state.maxHp)
    if hpNum ~= nil then
        state.hp = hpNum
        if hpNum <= 0 then
            state.dead = true
        end
    end
    if maxHpNum ~= nil then
        state.maxHp = maxHpNum
    end
    if hpNum ~= nil and maxHpNum ~= nil and maxHpNum > 0 then
        state.hpPct = math.max(0, math.min(1, hpNum / maxHpNum))
    end
    return state
end

local function getPreferredEquippedPetContainer(gamePlayer)
    if not gamePlayer or not gamePlayer.pet then
        return nil, "missing_pet"
    end

    local basePet = gamePlayer.pet
    local virtualPet = nil
    pcall(function()
        if type(basePet.GetVirtualPetData) == "function" then
            virtualPet = basePet:GetVirtualPetData()
        end
    end)

    if virtualPet and AbyssFlow and AbyssFlow.isEntered and AbyssFlow.isEntered() then
        return virtualPet, "virtual"
    end
    return basePet, "normal"
end

local function getEquippedPetStatus()
    local summary = {
        total = 0,
        observed = 0,
        deadCount = 0,
        unknownCount = 0,
        minPct = 1.0,
        source = "none",
    }
    local gamePlayer = getGamePlayer()
    if not gamePlayer or not gamePlayer.pet then
        return summary
    end

    local petContainer, source = getPreferredEquippedPetContainer(gamePlayer)
    if not petContainer then
        return summary
    end
    summary.source = source or "unknown"

    local seen = {}
    local function consumePetItem(petItem)
        if not petItem or seen[petItem] then
            return
        end
        seen[petItem] = true
        summary.total = summary.total + 1
        local state = getPetItemVitals(petItem)
        if not state or state.hpPct == nil then
            summary.unknownCount = summary.unknownCount + 1
        else
            summary.observed = summary.observed + 1
            summary.minPct = math.min(summary.minPct, state.hpPct)
        end
        if state and state.dead then
            summary.deadCount = summary.deadCount + 1
        end
    end

    pcall(function()
        if petContainer.IterEquipedItem then
            petContainer:IterEquipedItem(function(petItem)
                consumePetItem(petItem)
                return true
            end)
        end
    end)

    pcall(function()
        if petContainer.GetEquipCapacity and petContainer.GetEquipedItemBySlotIndex then
            local capacity = tonumber(petContainer:GetEquipCapacity()) or 0
            for slot = 1, capacity do
                consumePetItem(petContainer:GetEquipedItemBySlotIndex(slot))
            end
        end
    end)

    if summary.observed <= 0 then
        summary.minPct = 1.0
    end
    return summary
end

local function getEquippedPetsMinHpPercent()
    return getEquippedPetStatus().minPct
end

local function getEquippedDeadPetCount()
    local status = getEquippedPetStatus()
    return status.deadCount, status.total
end

local function isAnyEquippedPetDead()
    local status = getEquippedPetStatus()
    return status.deadCount > 0, status.deadCount, status
end

local function areAllEquippedPetsDead()
    local status = getEquippedPetStatus()
    return status.total > 0 and status.deadCount >= status.total, status.deadCount, status.total, status
end

local function waitUntilPetsRecoveredFully(timeout, shouldContinue, statusFn, statusPrefix)
    timeout = tonumber(timeout) or AUTO_RIFT.RECOVER_TIMEOUT
    statusFn = statusFn or setAutoRiftStatus
    statusPrefix = statusPrefix or "刷Rift"
    local startedAt = os.clock()
    while os.clock() - startedAt < timeout do
        if shouldContinue and not shouldContinue() then
            return false, "stopped"
        end
        local deadAny, deadCount, petStatus = isAnyEquippedPetDead()
        local minHp = petStatus and petStatus.minPct or 1.0
        local observed = petStatus and petStatus.observed or 0
        if not deadAny and observed > 0 and minHp >= 0.99 then
            return true
        end
        local detail = ""
        if deadAny then
            detail = string.format(" 死亡:%d", deadCount or 0)
        elseif observed <= 0 then
            detail = " 读取中"
        end
        statusFn(string.format("%s: 等待回血 %.0f%%%s", statusPrefix, minHp * 100, detail), Color3.fromRGB(255, 220, 120))
        task.wait(1)
    end
    return false, "recover_timeout"
end

local function getNearestRecoverPointPosition()
    local _, hrp = getCharacterAndRootPart()
    if not hrp then
        return nil, nil, nil
    end

    local candidates = {}
    pcall(function()
        local areaRoot = workspace:FindFirstChild("Area")
        if areaRoot then
            for _, areaModel in ipairs(areaRoot:GetChildren()) do
                local serverZone = areaModel:FindFirstChild("ServerZone")
                local recoverRoot = serverZone and serverZone:FindFirstChild("Recover")
                if recoverRoot then
                    for _, inst in ipairs(recoverRoot:GetDescendants()) do
                        if inst:IsA("BasePart") and string.match(inst.Name, "^Rec") then
                            table.insert(candidates, inst)
                        end
                    end
                end
            end
        end
    end)

    if #candidates == 0 and PathTool and PathTool.FindForPath then
        pcall(function()
            local areaRoot = workspace:FindFirstChild("Area")
            if areaRoot then
                for _, areaModel in ipairs(areaRoot:GetChildren()) do
                    local rec1 = PathTool.FindForPath(workspace, string.format("Area.%s.ServerZone.Recover.Rec_1", areaModel.Name))
                    if rec1 and rec1:IsA("BasePart") then
                        table.insert(candidates, rec1)
                    end
                end
            end
        end)
    end

    local bestPos = nil
    local bestDist = math.huge
    local bestName = nil
    for _, part in ipairs(candidates) do
        local dist = (part.Position - hrp.Position).Magnitude
        if dist < bestDist then
            bestDist = dist
            bestPos = part.Position
            bestName = part:GetFullName()
        end
    end
    return bestPos, bestDist, bestName
end

local function walkToPosition(targetPos, stopDistance, timeout, shouldContinue)
    if typeof(targetPos) ~= "Vector3" then
        return false, "bad_target"
    end

    stopDistance = tonumber(stopDistance) or 8
    timeout = tonumber(timeout) or 45
    local startedAt = os.clock()

    local function getMoveParts()
        local character, hrp = getCharacterAndRootPart()
        if not character or not hrp then
            return nil, nil, nil, "character_lost"
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then
            return nil, nil, nil, "humanoid_lost"
        end
        return character, hrp, humanoid, nil
    end

    local function getRemainingTime()
        return timeout - (os.clock() - startedAt)
    end

    local function flattenVector(value)
        return Vector3.new(value.X, 0, value.Z)
    end

    local function positionKey(value)
        return string.format(
            "%d:%d:%d",
            math.floor(value.X * 10 + 0.5),
            math.floor(value.Y * 10 + 0.5),
            math.floor(value.Z * 10 + 0.5)
        )
    end

    local function buildApproachCandidates(fromPos, destinationPos)
        local candidates = {}
        local seen = {}
        local function addCandidate(pos)
            if typeof(pos) ~= "Vector3" then
                return
            end
            local key = positionKey(pos)
            if seen[key] then
                return
            end
            seen[key] = true
            table.insert(candidates, pos)
        end

        addCandidate(destinationPos)
        local flatOffset = flattenVector(destinationPos - fromPos)
        local flatDistance = flatOffset.Magnitude
        if flatDistance > 0.25 then
            local forward = flatOffset.Unit
            local left = Vector3.new(-forward.Z, 0, forward.X)
            local sampleRadius = math.max(
                AUTO_RIFT.APPROACH_SAMPLE_MIN_RADIUS,
                math.min(AUTO_RIFT.APPROACH_SAMPLE_MAX_RADIUS, stopDistance * AUTO_RIFT.APPROACH_SAMPLE_RADIUS_FACTOR)
            )
            sampleRadius = math.min(sampleRadius, math.max(1.75, flatDistance * 0.6))

            addCandidate(destinationPos - forward * sampleRadius * 0.85)
            addCandidate(destinationPos + forward * sampleRadius * AUTO_RIFT.APPROACH_OVERSHOOT_FACTOR)
            addCandidate(destinationPos + left * sampleRadius)
            addCandidate(destinationPos - left * sampleRadius)
            addCandidate(destinationPos - forward * sampleRadius * 0.45 + left * sampleRadius * 0.65)
            addCandidate(destinationPos - forward * sampleRadius * 0.45 - left * sampleRadius * 0.65)
        end
        return candidates
    end

    local function moveToPoint(point, pointRadius, segmentTimeout, jumpIntent)
        pointRadius = tonumber(pointRadius) or AUTO_RIFT.WAYPOINT_REACH_RADIUS
        segmentTimeout = tonumber(segmentTimeout) or AUTO_RIFT.WAYPOINT_TIMEOUT
        local character, hrp, humanoid, err = getMoveParts()
        if err then
            return false, err
        end

        local segmentStartedAt = os.clock()
        local lastProgressPos = hrp.Position
        local lastProgressDistance = (hrp.Position - point).Magnitude
        local lastProgressAt = os.clock()
        local lastJumpAt = 0
        local sidestepCount = 0

        local function requestJump()
            local now = os.clock()
            if now - lastJumpAt < AUTO_RIFT.JUMP_COOLDOWN then
                return
            end
            local floorOk, floorMaterial = pcall(function()
                return humanoid.FloorMaterial
            end)
            if floorOk and floorMaterial == Enum.Material.Air then
                return
            end
            pcall(function()
                humanoid.Jump = true
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end)
            lastJumpAt = now
        end

        local raycastParams = nil
        local raycastCharacter = nil

        local function getJumpRaycastParams(characterValue)
            if raycastParams and raycastCharacter == characterValue then
                return raycastParams
            end
            raycastParams = RaycastParams.new()
            raycastParams.FilterDescendantsInstances = { characterValue }
            raycastParams.IgnoreWater = true
            local filterOk = pcall(function()
                raycastParams.FilterType = Enum.RaycastFilterType.Exclude
            end)
            if not filterOk then
                pcall(function()
                    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                end)
            end
            raycastCharacter = characterValue
            return raycastParams
        end

        local function trySideStep(characterValue, rootPart, humanoidValue, pointValue)
            if sidestepCount >= AUTO_RIFT.SIDESTEP_LIMIT then
                return false
            end
            local offset = pointValue - rootPart.Position
            local flat = flattenVector(offset)
            if flat.Magnitude <= 0.5 then
                return false
            end
            local lateral = Vector3.new(-flat.Z, 0, flat.X)
            if lateral.Magnitude <= 0.05 then
                return false
            end
            local directionSign = (sidestepCount % 2 == 0) and 1 or -1
            local sidePoint = rootPart.Position + lateral.Unit * AUTO_RIFT.SIDESTEP_DISTANCE * directionSign
            humanoidValue:MoveTo(sidePoint)
            task.wait(AUTO_RIFT.SIDESTEP_SECONDS)
            sidestepCount = sidestepCount + 1

            local _, latestRoot = getCharacterAndRootPart()
            if latestRoot then
                lastProgressPos = latestRoot.Position
                lastProgressDistance = (latestRoot.Position - pointValue).Magnitude
            else
                lastProgressPos = rootPart.Position
                lastProgressDistance = (rootPart.Position - pointValue).Magnitude
            end
            lastProgressAt = os.clock()
            return true
        end

        local function shouldJumpAhead(character, rootPart, pointValue)
            local offset = pointValue - rootPart.Position
            local flat = Vector3.new(offset.X, 0, offset.Z)
            local flatDist = flat.Magnitude
            if flatDist <= 0.25 then
                return false
            end
            if jumpIntent and flatDist <= AUTO_RIFT.JUMP_LOOKAHEAD_DISTANCE * 1.8 then
                return true
            end
            if offset.Y >= AUTO_RIFT.JUMP_HEIGHT_TRIGGER and flatDist <= AUTO_RIFT.JUMP_LOOKAHEAD_DISTANCE * 2 then
                return true
            end

            local params = getJumpRaycastParams(character)
            local direction = flat.Unit * math.min(AUTO_RIFT.JUMP_LOOKAHEAD_DISTANCE, flatDist)
            local lowOrigin = rootPart.Position - Vector3.new(0, 1.45, 0)
            local highOrigin = rootPart.Position + Vector3.new(0, 0.85, 0)
            local lowHit = workspace:Raycast(lowOrigin, direction, params)
            if not lowHit then
                return false
            end
            local highHit = workspace:Raycast(highOrigin, direction, params)
            return highHit == nil
        end

        while os.clock() - segmentStartedAt < segmentTimeout do
            if shouldContinue and not shouldContinue() then
                return false, "stopped"
            end
            if getRemainingTime() <= 0 then
                return false, "walk_timeout"
            end

            character, hrp, humanoid, err = getMoveParts()
            if err then
                return false, err
            end

            local currentPos = hrp.Position
            if (currentPos - targetPos).Magnitude <= stopDistance then
                return true, "target"
            end
            local pointDistance = (currentPos - point).Magnitude
            if pointDistance <= pointRadius then
                return true, "point"
            end

            local now = os.clock()
            local movedEnough = (currentPos - lastProgressPos).Magnitude >= AUTO_RIFT.STUCK_MIN_MOVE
            local gotCloserEnough = (lastProgressDistance - pointDistance) >= AUTO_RIFT.DISTANCE_PROGRESS_STEP
            if movedEnough or gotCloserEnough then
                lastProgressPos = currentPos
                lastProgressDistance = pointDistance
                lastProgressAt = now
                sidestepCount = 0
            elseif pointDistance < lastProgressDistance then
                lastProgressDistance = pointDistance
            elseif now - lastProgressAt >= AUTO_RIFT.STUCK_CHECK_SECONDS then
                requestJump()
                if now - lastProgressAt >= AUTO_RIFT.STUCK_REPATH_SECONDS then
                    local sidestepped = trySideStep(character, hrp, humanoid, point)
                    if not sidestepped then
                        return false, "stuck"
                    end
                end
            end

            if character and shouldJumpAhead(character, hrp, point) then
                requestJump()
            end
            humanoid:MoveTo(point)
            task.wait(AUTO_RIFT.MOVE_REFRESH)
        end
        return false, "segment_timeout"
    end

    local function buildWaypoints(fromPos, destinationPos)
        local path = PathfindingService:CreatePath({
            AgentRadius = 1.6,
            AgentHeight = 4.5,
            AgentCanJump = true,
            WaypointSpacing = 8,
        })

        local computed = pcall(function()
            path:ComputeAsync(fromPos, destinationPos)
        end)
        if computed and path.Status == Enum.PathStatus.Success then
            local waypoints = path:GetWaypoints()
            if #waypoints > 0 then
                return waypoints
            end
        end
        return nil
    end

    local _, hrp, _, firstErr = getMoveParts()
    if firstErr then
        return false, firstErr == "character_lost" and "character_not_ready" or "humanoid_missing"
    end
    if (hrp.Position - targetPos).Magnitude <= stopDistance then
        return true
    end

    local repathAttempts = 0
    local lastErr = nil
    while getRemainingTime() > 0 do
        if shouldContinue and not shouldContinue() then
            return false, "stopped"
        end

        _, hrp, _, firstErr = getMoveParts()
        if firstErr then
            return false, firstErr
        end

        if (hrp.Position - targetPos).Magnitude <= stopDistance then
            return true
        end

        local approachCandidates = buildApproachCandidates(hrp.Position, targetPos)
        for candidateIndex, candidatePos in ipairs(approachCandidates) do
            if shouldContinue and not shouldContinue() then
                return false, "stopped"
            end

            local remaining = getRemainingTime()
            local directSeconds = math.min(AUTO_RIFT.DIRECT_MOVE_SECONDS, remaining)
            if (hrp.Position - candidatePos).Magnitude <= AUTO_RIFT.DIRECT_MOVE_DISTANCE or repathAttempts > 0 or candidateIndex > 1 then
                local movedDirect = false
                if directSeconds > 0 then
                    local ok, status = moveToPoint(candidatePos, math.max(stopDistance, AUTO_RIFT.WAYPOINT_REACH_RADIUS), directSeconds)
                    if ok and status == "target" then
                        movedDirect = true
                    elseif ok then
                        local _, directRoot = getCharacterAndRootPart()
                        movedDirect = directRoot and (directRoot.Position - targetPos).Magnitude <= stopDistance or false
                    else
                        lastErr = status or lastErr
                    end
                end
                if movedDirect then
                    return true
                end
                if getRemainingTime() <= 0 then
                    return false, "walk_timeout"
                end
            end

            _, hrp, _, firstErr = getMoveParts()
            if firstErr then
                return false, firstErr
            end

            local waypoints = buildWaypoints(hrp.Position, candidatePos)
            if waypoints then
                local needsRepath = false
                local candidateErr = nil
                for index, waypoint in ipairs(waypoints) do
                    if shouldContinue and not shouldContinue() then
                        return false, "stopped"
                    end

                    local isLastWaypoint = index == #waypoints
                    local pointRadius = isLastWaypoint and math.max(stopDistance, AUTO_RIFT.WAYPOINT_REACH_RADIUS) or AUTO_RIFT.WAYPOINT_REACH_RADIUS
                    local segmentTimeout = math.min(AUTO_RIFT.WAYPOINT_TIMEOUT, getRemainingTime())
                    if segmentTimeout <= 0 then
                        return false, "walk_timeout"
                    end

                    local ok, status = moveToPoint(waypoint.Position, pointRadius, segmentTimeout, waypoint.Action == Enum.PathWaypointAction.Jump)
                    if ok and status == "target" then
                        return true
                    elseif ok and isLastWaypoint then
                        local _, finalRoot = getCharacterAndRootPart()
                        if finalRoot and (finalRoot.Position - targetPos).Magnitude <= stopDistance then
                            return true
                        end
                    elseif not ok then
                        needsRepath = true
                        candidateErr = status
                        break
                    end
                end
                if not needsRepath then
                    local _, finalRoot = getCharacterAndRootPart()
                    if finalRoot and (finalRoot.Position - targetPos).Magnitude <= stopDistance then
                        return true
                    end
                end
                if candidateErr then
                    lastErr = candidateErr
                end
            else
                local fallbackSeconds = math.min(AUTO_RIFT.DIRECT_FALLBACK_SECONDS, getRemainingTime())
                if fallbackSeconds <= 0 then
                    return false, "walk_timeout"
                end
                local ok, status = moveToPoint(candidatePos, math.max(stopDistance, AUTO_RIFT.WAYPOINT_REACH_RADIUS), fallbackSeconds)
                if ok and status == "target" then
                    return true
                elseif ok then
                    local _, fallbackRoot = getCharacterAndRootPart()
                    if fallbackRoot and (fallbackRoot.Position - targetPos).Magnitude <= stopDistance then
                        return true
                    end
                end
                lastErr = status or lastErr
            end

            _, hrp, _, firstErr = getMoveParts()
            if firstErr then
                return false, firstErr
            end
            if (hrp.Position - targetPos).Magnitude <= stopDistance then
                return true
            end
        end

        repathAttempts = repathAttempts + 1
        if repathAttempts >= AUTO_RIFT.MAX_REPATH_ATTEMPTS then
            local fallbackSeconds = math.min(AUTO_RIFT.DIRECT_FALLBACK_SECONDS, getRemainingTime())
            if fallbackSeconds > 0 then
                for _, candidatePos in ipairs(buildApproachCandidates(hrp.Position, targetPos)) do
                    local ok, status = moveToPoint(candidatePos, math.max(stopDistance, AUTO_RIFT.WAYPOINT_REACH_RADIUS), fallbackSeconds)
                    if ok and status == "target" then
                        return true
                    elseif ok then
                        local _, fallbackRoot = getCharacterAndRootPart()
                        if fallbackRoot and (fallbackRoot.Position - targetPos).Magnitude <= stopDistance then
                            return true
                        end
                    end
                    lastErr = status or lastErr
                end
            end
            break
        end
        task.wait(0.05)
    end

    local _, finalRoot = getCharacterAndRootPart()
    if finalRoot and (finalRoot.Position - targetPos).Magnitude <= stopDistance then
        return true
    end
    return false, getRemainingTime() <= 0 and "walk_timeout" or (lastErr or "walk_not_reached")
end

local function recoverPetsByWalking(shouldContinue, statusFn, statusPrefix)
    statusFn = statusFn or setAutoRiftStatus
    statusPrefix = statusPrefix or "刷Rift"
    local recoverPos, recoverDist, recoverName = getNearestRecoverPointPosition()
    if not recoverPos then
        return false, "recover_point_missing"
    end

    statusFn(string.format("%s: 去复活点 %.0f", statusPrefix, tonumber(recoverDist) or 0), Color3.fromRGB(255, 220, 120))
    local walked, walkErr = walkToPosition(recoverPos, AUTO_RIFT.REACH_RADIUS, 60, shouldContinue)
    if not walked then
        return false, walkErr or "recover_walk_failed"
    end

    statusFn(statusPrefix .. ": 已到复活点，等满血", Color3.fromRGB(255, 220, 120))
    local recovered, recoverErr = waitUntilPetsRecoveredFully(AUTO_RIFT.RECOVER_TIMEOUT, shouldContinue, statusFn, statusPrefix)
    if not recovered then
        return false, recoverErr or "recover_timeout"
    end
    return true, recoverName
end

local function getInstancePosition(inst)
    if not inst or not inst.Parent then
        return nil
    end
    if inst:IsA("BasePart") then
        return inst.Position
    end
    if inst:IsA("Model") then
        local ok, pivot = pcall(function()
            return inst:GetPivot()
        end)
        if ok and pivot then
            return pivot.Position
        end
    end

    local marker = inst:FindFirstChild("Model")
    if marker and marker:IsA("Attachment") then
        return marker.WorldPosition
    end
    if marker and marker:IsA("BasePart") then
        return marker.Position
    end

    local ok, cframeValue = pcall(function()
        return inst.CFrame
    end)
    if ok and cframeValue then
        return cframeValue.Position
    end
    return nil
end

local function getServerTick()
    if PathTool and PathTool.ClockSystem and PathTool.ClockSystem.GetTick then
        local ok, tickValue = pcall(function()
            return PathTool.ClockSystem.GetTick()
        end)
        if ok then
            return tonumber(tickValue)
        end
    end
    return nil
end

local function getAttrWithParent(node, attrName)
    if not node then
        return nil
    end

    local value = node:GetAttribute(attrName)
    if value == nil and node.Parent then
        value = node.Parent:GetAttribute(attrName)
    end
    return value
end

local function getFixedRiftEntries()
    local entries = {}
    local dynamicRoot = workspace:FindFirstChild("DynamicDungeon")
    if not dynamicRoot then
        return entries
    end

    table.insert(entries, { folder = dynamicRoot, areaRegion = dynamicRoot })
    return entries
end

local function getRiftShowId(node)
    if not node then
        return nil
    end
    return tonumber(tostring(node.Name):match("^Dungeon_(%d+)$"))
end

local function getRiftKey(showId, startTick)
    return tostring(showId or "?") .. ":" .. tostring(startTick or "?")
end

local function isRiftFailedRecently(showId, startTick)
    local failedAt = autoRiftFailedRifts[getRiftKey(showId, startTick)]
    return failedAt and (os.clock() - failedAt) < AUTO_RIFT.FAILED_COOLDOWN
end

local function markRiftFailed(showId, startTick)
    autoRiftFailedRifts[getRiftKey(showId, startTick)] = os.clock()
end

local function isRiftAlreadyEntered(dynamicKey, groupId, startTick, useDataType)
    local gamePlayer = getGamePlayer()
    if not gamePlayer or not gamePlayer.dungeon then
        return false
    end

    if dynamicKey and startTick and gamePlayer.dungeon.IsDynamicEntered then
        local ok, entered = pcall(function()
            return gamePlayer.dungeon:IsDynamicEntered(dynamicKey, startTick)
        end)
        if ok and entered == true then
            return true
        end
    end

    if groupId and startTick and useDataType and gamePlayer.dungeon.IsEntered then
        local ok, entered = pcall(function()
            return gamePlayer.dungeon:IsEntered(groupId, startTick, useDataType)
        end)
        if ok and entered == true then
            return true
        end
    end

    return false
end

local function getDungeonArenaId(tmplId)
    tmplId = tonumber(tmplId)
    if not tmplId or not PathTool or not PathTool.CfgDungeon or type(PathTool.CfgDungeon.Tmpls) ~= "table" then
        return nil
    end

    local cfg = PathTool.CfgDungeon.Tmpls[tmplId]
    if type(cfg) == "table" then
        return tonumber(cfg.ArenaId)
    end
    return nil
end

local function selectPortalForRiftNode(node, areaRegion, originPos)
    if not node or not areaRegion then
        return nil, nil
    end

    local candidates = {}
    for _, inst in ipairs(node:GetDescendants()) do
        local name = string.lower(inst.Name or "")
        if (inst:IsA("Model") or inst:IsA("BasePart"))
            and inst:IsDescendantOf(areaRegion)
            and string.find(name, "portal", 1, true)
        then
            table.insert(candidates, inst)
        end
    end

    if #candidates == 0 then
        for _, inst in ipairs(areaRegion:GetDescendants()) do
            local name = string.lower(inst.Name or "")
            if (inst:IsA("Model") or inst:IsA("BasePart"))
                and string.find(name, "portal", 1, true)
                and inst.Parent
                and (inst.Parent == node or inst.Parent.Parent == node)
            then
                table.insert(candidates, inst)
            end
        end
    end

    local best = nil
    local bestPos = nil
    local bestDist = math.huge
    for _, candidate in ipairs(candidates) do
        local pos = getInstancePosition(candidate)
        if pos then
            local dist = originPos and (originPos - pos).Magnitude or 0
            if dist < bestDist then
                best = candidate
                bestPos = pos
                bestDist = dist
            end
        end
    end
    return best, bestPos
end

local function getRiftRegionForNode(node)
    local dynamicRoot = workspace:FindFirstChild("DynamicDungeon")
    if dynamicRoot and node and node:IsDescendantOf(dynamicRoot) then
        return dynamicRoot
    end
    return nil
end

local function buildFixedRiftInfo(node, originPos, maxDistance, areaRegion)
    if not node or not node.Parent or tostring(node.Name):find("Dungeon_") ~= 1 then
        return nil
    end

    local dynamicRoot = workspace:FindFirstChild("DynamicDungeon")
    if not dynamicRoot or not node:IsDescendantOf(dynamicRoot) then
        return nil
    end

    local showId = getRiftShowId(node)
    if not showId then
        return nil
    end

    local startTick = getAttrWithParent(node, "DungeonStartTick")
    local dynamicKey = getAttrWithParent(node, "DungeonDynamicKey")
    local groupId = getAttrWithParent(node, "DungeonGroupId")
    local useDataType = getAttrWithParent(node, "DungeonUseDataType")
    local syncKey = getAttrWithParent(node, "DungeonSyncObjectKey")
    local tmplId = getAttrWithParent(node, "DungeonTmplId")
    if not startTick or not dynamicKey or not syncKey then
        return nil
    end

    if isRiftFailedRecently(showId, startTick) then
        return nil
    end
    if isRiftAlreadyEntered(dynamicKey, groupId, startTick, useDataType) then
        return nil
    end

    local endTick = tonumber(getAttrWithParent(node, "DungeonEndTick"))
    local currentTick = getServerTick()
    if endTick and currentTick and currentTick >= endTick then
        return nil
    end

    areaRegion = areaRegion or getRiftRegionForNode(node)
    local portal, portalPos = selectPortalForRiftNode(node, areaRegion, originPos)
    local pos = portalPos or getInstancePosition(node)
    if not pos then
        return nil
    end
    local dist = (originPos - pos).Magnitude
    if maxDistance and dist > maxDistance then
        return nil
    end

    return {
        node = node,
        showId = showId,
        startTick = startTick,
        dynamicKey = dynamicKey,
        groupId = groupId,
        useDataType = useDataType,
        syncKey = syncKey,
        tmplId = tmplId,
        arenaId = getDungeonArenaId(tmplId),
        portal = portal,
        position = pos,
        distance = dist,
    }
end

local function findNearestAvailableFixedRift(maxDistance)
    local _, hrp = getCharacterAndRootPart()
    if not hrp then
        return nil, "character_not_ready"
    end

    local bestInfo = nil
    for _, entry in ipairs(getFixedRiftEntries()) do
        local root = entry.folder
        for _, node in ipairs(root:GetChildren()) do
            local info = buildFixedRiftInfo(node, hrp.Position, maxDistance, entry.areaRegion)
            if info and (not bestInfo or info.distance < bestInfo.distance) then
                bestInfo = info
            end
        end
    end

    if bestInfo then
        return bestInfo
    end
    return nil, "no_fixed_rift"
end

local function refreshFixedRiftInfo(info)
    if not info or not info.node then
        return nil
    end
    local _, hrp = getCharacterAndRootPart()
    if not hrp then
        return nil
    end
    return buildFixedRiftInfo(info.node, hrp.Position, nil, getRiftRegionForNode(info.node))
end

local function createRiftTeam(info)
    if not info or not PathTool or not PathTool.DungeonSystem then
        return false, "DungeonSystem missing"
    end
    if not PathTool.DungeonSystem.ClientCreateTeam then
        return false, "ClientCreateTeam missing"
    end

    local ok, result, extra = pcall(function()
        return PathTool.DungeonSystem.ClientCreateTeam(info.showId, info.startTick)
    end)
    if ok and result ~= false then
        return true
    end
    return false, tostring(extra or result or "create_team_failed")
end

local function startRiftDungeon(info)
    if not info or not PathTool or not PathTool.DungeonSystem then
        return false, "DungeonSystem missing"
    end
    if not PathTool.DungeonSystem.ClientStartDungeon then
        return false, "ClientStartDungeon missing"
    end

    local ok, result, extra = pcall(function()
        return PathTool.DungeonSystem.ClientStartDungeon(info.showId, info.startTick)
    end)
    if ok and result ~= false then
        return true
    end
    return false, tostring(extra or result or "start_dungeon_failed")
end

local function leaveRiftTeam(info)
    if not info or not PathTool or not PathTool.DungeonSystem or not PathTool.DungeonSystem.ClientLeaveTeam then
        return
    end
    pcall(function()
        PathTool.DungeonSystem.ClientLeaveTeam(info.showId, info.startTick)
    end)
end

local function leaveRiftArena()
    if PathTool and PathTool.ArenaSystem and PathTool.ArenaSystem.ClientLeaveArena then
        local ok, result = pcall(function()
            return PathTool.ArenaSystem.ClientLeaveArena()
        end)
        if ok and result ~= false then
            return true
        end
    end
    return false
end

local function getSelfArenaInfo()
    if not PathTool or not PathTool.MgrArenaClient or not PathTool.MgrArenaClient.GetSelfArenaInfo then
        return nil
    end

    local ok, arenaInfo = pcall(function()
        return PathTool.MgrArenaClient.GetSelfArenaInfo()
    end)
    if ok and type(arenaInfo) == "table" then
        return arenaInfo
    end
    return nil
end

local function isRiftArenaEntered(info)
    local arenaInfo = getSelfArenaInfo()
    if not arenaInfo then
        return false
    end

    local arenaId = tonumber(arenaInfo.ArenaId)
    if not arenaId and arenaInfo.SyncValue then
        arenaId = tonumber(arenaInfo.SyncValue.Value)
    end

    if info and info.arenaId and arenaId and arenaId ~= tonumber(info.arenaId) then
        return false
    end

    return arenaInfo.AreaId ~= nil
        and arenaInfo.SyncValue ~= nil
        and (arenaInfo.ArenaTmpl ~= nil or arenaId ~= nil)
end

local function getLocalPlayerAreaId()
    if not PathTool or not PathTool.AreaUtil or not PathTool.AreaUtil.GetLocalPlayerAreaId then
        return nil
    end

    local ok, areaId = pcall(function()
        return PathTool.AreaUtil.GetLocalPlayerAreaId()
    end)
    if ok then
        return areaId
    end
    return nil
end

local function isArenaAreaId(areaId)
    if areaId == nil or not PathTool or not PathTool.CfgGlobal then
        return false
    end

    local okArena, inArena = pcall(function()
        return PathTool.CfgGlobal.AreaIdIsArena(areaId)
    end)
    if okArena and inArena then
        return true
    end

    local okAbyss, inAbyss = pcall(function()
        return PathTool.CfgGlobal.AreaIdIsAbyss(areaId)
    end)
    return okAbyss and inAbyss == true
end

local function isStillInRiftArena(info)
    if isRiftArenaEntered(info) then
        return true
    end

    local arenaInfo = getSelfArenaInfo()
    if arenaInfo and arenaInfo.AreaId ~= nil and arenaInfo.SyncValue ~= nil then
        if not info or not info.arenaId then
            return true
        end

        local arenaId = tonumber(arenaInfo.ArenaId)
        if not arenaId and arenaInfo.SyncValue then
            arenaId = tonumber(arenaInfo.SyncValue.Value)
        end
        if not arenaId or arenaId == tonumber(info.arenaId) then
            return true
        end
    end

    local areaId = getLocalPlayerAreaId()
    return isArenaAreaId(areaId)
end

local function getSelfArenaStatus()
    local arenaInfo = getSelfArenaInfo()
    if not arenaInfo or not arenaInfo.SyncValue then
        return nil
    end

    local ok, statusValue = pcall(function()
        return arenaInfo.SyncValue:GetAttribute("Status")
    end)
    if ok then
        return tonumber(statusValue)
    end
    return nil
end

local function isRiftArenaResultStatus()
    if not PathTool or not PathTool.ArenaSystem then
        return false
    end

    local statusValue = getSelfArenaStatus()
    return statusValue ~= nil and statusValue == tonumber(PathTool.ArenaSystem.DefSta_Result)
end

local function waitForRiftArenaEntered(info, timeout, shouldContinue)
    timeout = tonumber(timeout) or AUTO_RIFT.ENTER_TIMEOUT
    local startedAt = os.clock()
    while os.clock() - startedAt < timeout do
        if shouldContinue and not shouldContinue() then
            return false, "stopped"
        end
        if areAllEquippedPetsDead() then
            return false, "all_pets_dead"
        end
        if isRiftArenaEntered(info) then
            return true
        end
        setAutoRiftStatus("刷Rift: 等待进入场景", Color3.fromRGB(255, 220, 120))
        task.wait(0.25)
    end
    return false, "arena_enter_timeout"
end

local function ensureLeaveRiftArena(info, timeout, shouldContinue)
    timeout = tonumber(timeout) or AUTO_RIFT.EXIT_TIMEOUT
    local startedAt = os.clock()
    local lastLeaveAt = -math.huge
    local leftSince = nil

    while os.clock() - startedAt < timeout do
        if shouldContinue and not shouldContinue() then
            return false, "stopped"
        end

        if not isStillInRiftArena(info) then
            leftSince = leftSince or os.clock()
            if os.clock() - leftSince >= AUTO_RIFT.LEFT_STABLE_SECONDS then
                return true
            end
        else
            leftSince = nil
            if os.clock() - lastLeaveAt >= AUTO_RIFT.LEAVE_RETRY_INTERVAL then
                leaveRiftArena()
                lastLeaveAt = os.clock()
            end
            setAutoRiftStatus("刷Rift: 检测仍在Rift，重试退出", Color3.fromRGB(255, 220, 120))
        end

        task.wait(0.2)
    end

    return false, isStillInRiftArena(info) and "still_in_rift" or "arena_exit_timeout"
end

local function getMonsterIdFromInfo(monster)
    if not monster then
        return nil
    end

    local monsterId = tonumber(monster.MonsterId or monster.monsterId or monster.Id)
    if monsterId then
        return monsterId
    end

    if monster.Model and PathTool and PathTool.MgrMonsterClient and PathTool.MgrMonsterClient.GetMonsterIdByPart then
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
            if ok and type(value) == "number" then
                return value
            end
        end
    end

    if monster.ServerNode then
        return tonumber(tostring(monster.ServerNode.Name):match("(%d+)$"))
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

local function attackRiftMonster(monsterId)
    if type(monsterId) ~= "number" or not PathTool then
        return false
    end

    if PathTool.MonsterSystem and PathTool.MonsterSystem.ClientAttackMonsterOnHasAlivePet then
        local ok, result = pcall(function()
            return PathTool.MonsterSystem.ClientAttackMonsterOnHasAlivePet(monsterId)
        end)
        if ok and result ~= false then
            return true
        end
    end

    if PathTool.MonsterSystem and PathTool.MonsterSystem.ClientAttackMonster then
        local ok, result = pcall(function()
            return PathTool.MonsterSystem.ClientAttackMonster(monsterId)
        end)
        return ok and result ~= false
    end
    return false
end

local function findNearestAliveRiftMonster(originPos, maxDistance)
    local monsterMgr = getMonsterManager()
    if not monsterMgr or not monsterMgr.IterMonster or not originPos then
        return nil
    end

    local nearest = nil
    local nearestDist = math.huge
    pcall(function()
        monsterMgr.IterMonster(function(monster)
            if monster and isMonsterAlive(monster) then
                local monsterId = getMonsterIdFromInfo(monster)
                local pos = getMonsterPosition(monster)
                if monsterId and pos then
                    local dist = (originPos - pos).Magnitude
                    if dist <= maxDistance and dist < nearestDist then
                        nearestDist = dist
                        nearest = {
                            id = monsterId,
                            position = pos,
                            distance = dist,
                        }
                    end
                end
            end
            return true
        end)
    end)
    return nearest
end

local function isMonsterCatchableBySelf(monster)
    if not monster or isMonsterAlive(monster) then
        return false
    end
    local monsterId = getMonsterIdFromInfo(monster)
    if not monsterId then
        return false
    end
    local serverNode = monster.ServerNode
    if not serverNode then
        return true
    end

    local playerId = player and player.UserId
    if playerId and serverNode:GetAttribute("CatchPlayerId_" .. tostring(playerId)) ~= nil then
        return true
    end
    if playerId and serverNode:GetAttribute("CatchTakenPlayerId_" .. tostring(playerId)) ~= nil then
        return true
    end
    if playerId and serverNode:GetAttribute("CatchTakenPlayerId") == playerId then
        return true
    end
    return false
end

local function getMonsterInfoById(monsterId)
    monsterId = tonumber(monsterId)
    if not monsterId then
        return nil
    end

    local monsterMgr = getMonsterManager()
    if monsterMgr and monsterMgr.GetMonsterInfo then
        local ok, monster = pcall(function()
            return monsterMgr.GetMonsterInfo(monsterId)
        end)
        if ok then
            return monster
        end
    end
    return nil
end

local function getAliveMonsterTargetById(monsterId, originPos, maxDistance)
    local monster = getMonsterInfoById(monsterId)
    if not monster or not isMonsterAlive(monster) then
        return nil
    end

    local pos = getMonsterPosition(monster)
    if not originPos or not pos then
        return nil
    end

    local dist = (originPos - pos).Magnitude
    if maxDistance and dist > maxDistance then
        return nil
    end

    return {
        id = tonumber(monsterId),
        position = pos,
        distance = dist,
    }
end

runActiveAttackOnce = function(shouldContinue)
    if not WaitForPathTool(5) then
        setActiveAttackStatus("主动打怪: PathTool超时", Color3.fromRGB(255, 150, 150))
        return false, "pathtool_timeout"
    end

    local _, hrp = getCharacterAndRootPart()
    if not hrp then
        setActiveAttackStatus("主动打怪: 无角色", Color3.fromRGB(180, 180, 180))
        interruptibleWait(0.25, shouldContinue)
        return false, "character_not_ready"
    end

    local target = nil
    if activeAttackTargetId then
        target = getAliveMonsterTargetById(activeAttackTargetId, hrp.Position, ACTIVE_ATTACK_RADIUS)
        if not target then
            activeAttackTargetId = nil
        end
    end

    if not target then
        target = findNearestAliveRiftMonster(hrp.Position, ACTIVE_ATTACK_RADIUS)
        activeAttackTargetId = target and target.id or nil
    end

    if not target then
        setActiveAttackStatus("主动打怪: 50范围无怪", Color3.fromRGB(180, 180, 180))
        interruptibleWait(0.25, shouldContinue)
        return false, "no_monster"
    end

    setActiveAttackStatus(string.format("主动打怪: 攻击 %s %.0f", tostring(target.id), target.distance or 0), Color3.fromRGB(255, 220, 120))
    attackRiftMonster(target.id)
    interruptibleWait(ACTIVE_ATTACK_LOOP_DELAY, shouldContinue)

    local _, refreshedRoot = getCharacterAndRootPart()
    local refreshedTarget = refreshedRoot and getAliveMonsterTargetById(activeAttackTargetId, refreshedRoot.Position, ACTIVE_ATTACK_RADIUS) or nil
    if not refreshedTarget then
        activeAttackTargetId = nil
        local nextTarget = refreshedRoot and findNearestAliveRiftMonster(refreshedRoot.Position, ACTIVE_ATTACK_RADIUS) or nil
        if nextTarget then
            activeAttackTargetId = nextTarget.id
            setActiveAttackStatus("主动打怪: 切换 " .. tostring(nextTarget.id), Color3.fromRGB(0, 255, 136))
            attackRiftMonster(nextTarget.id)
            return true, "target_changed"
        end

        setActiveAttackStatus("主动打怪: 目标死亡，50范围无下个", Color3.fromRGB(0, 255, 136))
        return true, "target_changed"
    end

    return true
end

local function isMonsterCatchResolved(monsterId)
    local monster = getMonsterInfoById(monsterId)
    if not monster then
        return true
    end
    if monster.ServerNode and monster.ServerNode.Parent == nil then
        return true
    end
    if not monster.ServerNode then
        return false
    end

    local playerId = player and player.UserId
    if playerId and monster.ServerNode:GetAttribute("CatchTakenPlayerId") == playerId then
        return true
    end
    if playerId and monster.ServerNode:GetAttribute("CatchTakenPlayerId_" .. tostring(playerId)) ~= nil then
        return true
    end
    return false
end

local function waitForMonsterCatchResolved(monsterId, timeout, shouldContinue)
    timeout = tonumber(timeout) or AUTO_RIFT.CATCH_RESOLVE_TIMEOUT
    local startedAt = os.clock()
    while os.clock() - startedAt < timeout do
        if shouldContinue and not shouldContinue() then
            return false, "stopped"
        end
        if isMonsterCatchResolved(monsterId) then
            return true
        end
        task.wait(0.25)
    end
    return false, "catch_resolve_timeout"
end

local function collectCatchableMonsterIds()
    local monsterMgr = getMonsterManager()
    if not monsterMgr then
        return {}
    end

    local ids = {}
    local seen = {}
    local function pushId(monster)
        local monsterId = getMonsterIdFromInfo(monster)
        if monsterId and not seen[monsterId] then
            seen[monsterId] = true
            table.insert(ids, monsterId)
        end
    end

    if monsterMgr.IterSelfCanCatchBattleMonster then
        pcall(function()
            monsterMgr.IterSelfCanCatchBattleMonster(function(monster)
                pushId(monster)
                return true
            end)
        end)
    end

    if #ids == 0 and monsterMgr.IterMonster then
        pcall(function()
            monsterMgr.IterMonster(function(monster)
                if isMonsterCatchableBySelf(monster) then
                    pushId(monster)
                end
                return true
            end)
        end)
    end

    return ids
end

local function processCatchableRiftMonsters(timeout, shouldContinue)
    if not PathTool or not PathTool.MonsterSystem then
        return false
    end

    local startedAt = os.clock()
    local processedAny = false
    while os.clock() - startedAt < (tonumber(timeout) or AUTO_RIFT.CATCH_WAIT_SECONDS) do
        if shouldContinue and not shouldContinue() then
            return processedAny
        end

        local ids = collectCatchableMonsterIds()
        if #ids > 0 then
            for _, monsterId in ipairs(ids) do
                if shouldContinue and not shouldContinue() then
                    return processedAny
                end
                setAutoRiftStatus("刷Rift: 捕捉 " .. tostring(monsterId), Color3.fromRGB(255, 220, 120))
                if PathTool.MonsterSystem.ClientCatchMonsterStart then
                    pcall(function()
                        PathTool.MonsterSystem.ClientCatchMonsterStart(monsterId)
                    end)
                    interruptibleWait(1.5, shouldContinue)
                end
                if PathTool.MonsterSystem.ClientCatchMonsterComplete then
                    pcall(function()
                        PathTool.MonsterSystem.ClientCatchMonsterComplete(monsterId)
                    end)
                end
                local resolved = waitForMonsterCatchResolved(monsterId, AUTO_RIFT.CATCH_RESOLVE_TIMEOUT, shouldContinue)
                if not resolved then
                    return false
                end
                processedAny = true
                interruptibleWait(0.4, shouldContinue)
            end
            return processedAny
        end
        task.wait(0.5)
    end
    return processedAny
end

local function runRiftArenaBattle(shouldContinue)
    local startedAt = os.clock()
    local shouldKeepFighting = function()
        return shouldContinue() and not areAllEquippedPetsDead()
    end

    while shouldKeepFighting() do
        if os.clock() - startedAt > AUTO_RIFT.ARENA_TIMEOUT then
            return false, "arena_timeout"
        end

        local allDead = areAllEquippedPetsDead()
        if allDead then
            return false, "all_pets_dead"
        end
        if isRiftArenaResultStatus() then
            break
        end

        local _, hrp = getCharacterAndRootPart()
        local origin = hrp and hrp.Position
        local target = origin and findNearestAliveRiftMonster(origin, AUTO_RIFT.MONSTER_SEARCH_RADIUS) or nil
        if target then
            if target.position and target.distance and target.distance > AUTO_RIFT.MONSTER_REACH_RADIUS then
                setAutoRiftStatus("刷Rift: 寻路靠近怪物", Color3.fromRGB(255, 220, 120))
                local walked = walkToPosition(target.position, AUTO_RIFT.MONSTER_REACH_RADIUS, 25, shouldKeepFighting)
                if not walked and areAllEquippedPetsDead() then
                    setAutoRiftStatus("刷Rift: 宠物全死，立即退出", Color3.fromRGB(255, 150, 150))
                    return false, "all_pets_dead"
                end
            end
            setAutoRiftStatus("刷Rift: 战斗 " .. tostring(target.id), Color3.fromRGB(255, 220, 120))
            attackRiftMonster(target.id)
            if not interruptibleWait(0.7, shouldKeepFighting) and areAllEquippedPetsDead() then
                setAutoRiftStatus("刷Rift: 宠物全死，立即退出", Color3.fromRGB(255, 150, 150))
                return false, "all_pets_dead"
            end
        else
            setAutoRiftStatus("刷Rift: 等待怪物/结算状态", Color3.fromRGB(255, 220, 120))
            if not interruptibleWait(0.5, shouldKeepFighting) and areAllEquippedPetsDead() then
                setAutoRiftStatus("刷Rift: 宠物全死，立即退出", Color3.fromRGB(255, 150, 150))
                return false, "all_pets_dead"
            end
        end
    end

    if areAllEquippedPetsDead() then
        setAutoRiftStatus("刷Rift: 宠物全死，立即退出", Color3.fromRGB(255, 150, 150))
        return false, "all_pets_dead"
    end
    if not shouldContinue() then
        return false, "stopped"
    end

    setAutoRiftStatus("刷Rift: 等待捕捉", Color3.fromRGB(255, 220, 120))
    local catchOk = processCatchableRiftMonsters(AUTO_RIFT.CATCH_WAIT_SECONDS, shouldKeepFighting)
    if areAllEquippedPetsDead() then
        setAutoRiftStatus("刷Rift: 宠物全死，立即退出", Color3.fromRGB(255, 150, 150))
        return false, "all_pets_dead"
    end
    if catchOk == false and not shouldContinue() then
        return false, "stopped"
    end
    return true
end

local function recoverAfterRift(shouldContinue)
    local deadAny, deadCount = isAnyEquippedPetDead()
    if deadAny then
        setAutoRiftStatus("刷Rift: 宠物死亡 " .. tostring(deadCount), Color3.fromRGB(255, 220, 120))
        return recoverPetsByWalking(shouldContinue)
    end
    return waitUntilPetsRecoveredFully(AUTO_RIFT.RECOVER_TIMEOUT, shouldContinue)
end

AbyssFlow = {}

function AbyssFlow.serverTime()
    if PathTool and PathTool.Utils and PathTool.Utils.GetServerTime then
        local ok, value = pcall(function()
            return PathTool.Utils.GetServerTime()
        end)
        if ok and tonumber(value) then
            return tonumber(value)
        end
    end
    return getServerTick() or os.time()
end

function AbyssFlow.cframePosition(value)
    if value == nil then
        return nil
    end
    local valueType = typeof(value)
    if valueType == "CFrame" then
        return value.Position
    end
    if valueType == "Vector3" then
        return value
    end
    if type(value) == "table" and value.Position then
        return value.Position
    end
    return nil
end

function AbyssFlow.getSyncKey()
    local ok, syncKey = pcall(function()
        return player:GetAttribute("AbyssSyncKey")
    end)
    if ok then
        return syncKey
    end
    return nil
end

function AbyssFlow.syncValue(key)
    local syncKey = AbyssFlow.getSyncKey()
    if not syncKey or not PathTool or not PathTool.DataSyncUtil or not PathTool.DataSyncUtil.GetValue then
        return nil
    end
    local ok, value = pcall(function()
        return PathTool.DataSyncUtil.GetValue(syncKey, { key })
    end)
    if ok then
        return value
    end
    return nil
end

function AbyssFlow.isAbyssAreaId(areaId)
    if areaId == nil or not PathTool or not PathTool.CfgGlobal or not PathTool.CfgGlobal.AreaIdIsAbyss then
        return false
    end
    local ok, isAbyss = pcall(function()
        return PathTool.CfgGlobal.AreaIdIsAbyss(areaId)
    end)
    return ok and isAbyss == true
end

function AbyssFlow.isEntered()
    if not AbyssFlow.getSyncKey() then
        return false
    end
    local arenaInfo = getSelfArenaInfo()
    if arenaInfo and AbyssFlow.isAbyssAreaId(arenaInfo.AreaId) then
        return true
    end
    return AbyssFlow.isAbyssAreaId(getLocalPlayerAreaId())
end

function AbyssFlow.isStillInAbyss()
    if AbyssFlow.getSyncKey() then
        return true
    end
    local arenaInfo = getSelfArenaInfo()
    if arenaInfo and AbyssFlow.isAbyssAreaId(arenaInfo.AreaId) then
        return true
    end
    return AbyssFlow.isAbyssAreaId(getLocalPlayerAreaId())
end

function AbyssFlow.ensureLeave(timeout, shouldContinue)
    timeout = tonumber(timeout) or AUTO_ABYSS.EXIT_TIMEOUT
    AUTO_ABYSS.log("退出检测开始", { timeout = timeout, syncKey = AbyssFlow.getSyncKey() })
    local startedAt = os.clock()
    local lastLeaveAt = -math.huge
    local leftSince = nil
    while os.clock() - startedAt < timeout do
        if shouldContinue and not shouldContinue() then
            return false, "stopped"
        end
        if not AbyssFlow.isStillInAbyss() and not isStillInRiftArena(nil) then
            leftSince = leftSince or os.clock()
            if os.clock() - leftSince >= AUTO_ABYSS.LEFT_STABLE_SECONDS then
                return true
            end
        else
            leftSince = nil
            if os.clock() - lastLeaveAt >= AUTO_ABYSS.LEAVE_RETRY_INTERVAL then
                local leaveOk = leaveRiftArena()
                lastLeaveAt = os.clock()
                AUTO_ABYSS.log("调用退出地下城", {
                    ok = leaveOk,
                    elapsed = math.floor((os.clock() - startedAt) * 10) / 10,
                    syncKey = AbyssFlow.getSyncKey(),
                    areaId = getLocalPlayerAreaId(),
                }, not leaveOk)
            end
            AUTO_ABYSS.setStatus("自动Abyss: 检测仍在地下城，重试退出", Color3.fromRGB(255, 220, 120))
        end
        task.wait(0.2)
    end
    local reason = AbyssFlow.isStillInAbyss() and "still_in_abyss" or "abyss_exit_timeout"
    AUTO_ABYSS.log("退出失败", { reason = reason, syncKey = AbyssFlow.getSyncKey(), areaId = getLocalPlayerAreaId() }, true)
    return false, reason
end

function AbyssFlow.entryPosition(node)
    local pos = getInstancePosition(node)
    if pos then
        return pos
    end
    if node and node.GetDescendants then
        for _, child in ipairs(node:GetDescendants()) do
            if child:IsA("BasePart") then
                return child.Position
            end
        end
    end
    return nil
end

function AbyssFlow.entryKey(showId)
    return tostring(showId or "unknown")
end

function AbyssFlow.markFailed(showId)
    AUTO_ABYSS.failedAt[AbyssFlow.entryKey(showId)] = os.clock()
    AUTO_ABYSS.log("标记入口冷却", { showId = showId })
end

function AbyssFlow.failedRecently(showId)
    local failedAt = AUTO_ABYSS.failedAt[AbyssFlow.entryKey(showId)]
    return failedAt and os.clock() - failedAt < AUTO_ABYSS.FAILED_COOLDOWN
end

function AbyssFlow.findNearestEntry(maxDistance)
    local _, hrp = getCharacterAndRootPart()
    if not hrp then
        return nil, "character_not_ready"
    end
    local nearest = nil
    local nearestDist = math.huge
    pcall(function()
        for _, inst in ipairs(workspace:GetDescendants()) do
            local showId = tonumber(tostring(inst.Name):match("^Abyss_(%d+)$"))
            if showId and not AbyssFlow.failedRecently(showId) then
                local pos = AbyssFlow.entryPosition(inst)
                if pos then
                    local dist = (hrp.Position - pos).Magnitude
                    if dist <= maxDistance and dist < nearestDist then
                        nearestDist = dist
                        nearest = {
                            node = inst,
                            showId = showId,
                            position = pos,
                            distance = dist,
                        }
                    end
                end
            end
        end
    end)
    if nearest then
        return nearest
    end
    return nil, "no_abyss_entry"
end

function AbyssFlow.parseTeamEntry(node)
    local showId = tonumber(tostring(node and node.Name or ""):match("^Abyss_(%d+)$"))
    if not showId then
        return nil
    end

    local _, hrp = getCharacterAndRootPart()
    local position = AbyssFlow.entryPosition(node)
    local teamInfo = {
        AbyssTmplId = tonumber(node:GetAttribute("AbyssTmplId")) or nil,
        MaxAmount = tonumber(node:GetAttribute("MaxAmount")) or nil,
        CreateTick = tonumber(node:GetAttribute("CreateTick")) or nil,
        LeaderId = nil,
        LeaderLevel = nil,
        MemberIds = {},
    }
    local attributes = {}
    pcall(function()
        attributes = node:GetAttributes()
    end)
    for attrName, attrValue in pairs(attributes or {}) do
        local ownerId = tonumber(tostring(attrName):match("^Owner_(%d+)$"))
        if ownerId then
            teamInfo.LeaderId = ownerId
            teamInfo.LeaderLevel = tonumber(attrValue) or attrValue
        else
            local memberId = tonumber(tostring(attrName):match("^Mem_(%d+)$"))
            if memberId then
                teamInfo.MemberIds[memberId] = tonumber(attrValue) or attrValue
            end
        end
    end

    local amount = teamInfo.LeaderId and 1 or 0
    for _ in pairs(teamInfo.MemberIds) do
        amount = amount + 1
    end
    teamInfo.Amount = amount

    local leaderPlayer = AUTO_ABYSS.findPlayerByUserId(teamInfo.LeaderId)
    return {
        node = node,
        showId = showId,
        position = position,
        distance = (hrp and position) and (hrp.Position - position).Magnitude or math.huge,
        teamInfo = teamInfo,
        leaderPlayer = leaderPlayer,
        leaderName = AUTO_ABYSS.formatOwnerPlayerName(leaderPlayer) or (teamInfo.LeaderId and ("UID " .. tostring(teamInfo.LeaderId)) or "未知房主"),
    }
end

function AbyssFlow.nodeHasPlayer(node, userId)
    userId = tonumber(userId)
    if not node or not userId then
        return false
    end
    return node:GetAttribute("Owner_" .. tostring(userId)) ~= nil or node:GetAttribute("Mem_" .. tostring(userId)) ~= nil
end

function AbyssFlow.findSelfTeamEntry(tmplId)
    local userId = player and player.UserId
    if not userId then
        return nil, nil
    end
    local matchedEntry = nil
    pcall(function()
        for _, inst in ipairs(workspace:GetDescendants()) do
            local entry = AbyssFlow.parseTeamEntry(inst)
            if entry and AbyssFlow.nodeHasPlayer(inst, userId) then
                if not tmplId or tonumber(entry.teamInfo and entry.teamInfo.AbyssTmplId) == tonumber(tmplId) then
                    matchedEntry = entry
                    break
                end
            end
        end
    end)
    return matchedEntry, matchedEntry and matchedEntry.teamInfo or nil
end

function AbyssFlow.findPreferredJoinTeam(ownerUserId, tmplId)
    ownerUserId = tonumber(ownerUserId)
    local bestEntry = nil
    pcall(function()
        for _, inst in ipairs(workspace:GetDescendants()) do
            local entry = AbyssFlow.parseTeamEntry(inst)
            local teamInfo = entry and entry.teamInfo
            if entry and teamInfo and teamInfo.LeaderId then
                local teamTmplId = tonumber(teamInfo.AbyssTmplId)
                local maxAmount = tonumber(teamInfo.MaxAmount) or AbyssFlow.getTmplLimit(teamTmplId)
                local amount = tonumber(teamInfo.Amount) or 0
                local isMatch = (not ownerUserId or tonumber(teamInfo.LeaderId) == ownerUserId)
                    and (not tmplId or teamTmplId == tonumber(tmplId))
                    and amount > 0
                    and (maxAmount <= 0 or amount < maxAmount)
                    and tonumber(teamInfo.LeaderId) ~= tonumber(player and player.UserId)
                if isMatch then
                    if not bestEntry
                        or entry.distance < bestEntry.distance
                        or (entry.distance == bestEntry.distance and (tonumber(teamInfo.CreateTick) or 0) > (tonumber(bestEntry.teamInfo and bestEntry.teamInfo.CreateTick) or 0)) then
                        bestEntry = entry
                    end
                end
            end
        end
    end)
    return bestEntry
end

function AbyssFlow.selfTeamInfo(node)
    local userId = player and player.UserId
    local teamInfo = PathTool and PathTool.AreaAbyssShower and PathTool.AreaAbyssShower._selfTeamInfo
    if type(teamInfo) == "table" and userId then
        if tonumber(teamInfo.LeaderId) == userId then
            return teamInfo
        end
        if type(teamInfo.MemberIds) == "table" then
            for key, memberId in pairs(teamInfo.MemberIds) do
                if tonumber(memberId) == userId or tonumber(key) == userId then
                    return teamInfo
                end
            end
        end
    end
    if node and userId then
        local owner = node:GetAttribute("Owner_" .. tostring(userId))
        local member = node:GetAttribute("Mem_" .. tostring(userId))
        if owner ~= nil or member ~= nil then
            return {
                AbyssTmplId = node:GetAttribute("AbyssTmplId"),
                MaxAmount = node:GetAttribute("MaxAmount"),
                CreateTick = node:GetAttribute("CreateTick"),
                LeaderId = owner ~= nil and userId or nil,
            }
        end
    end
    return nil
end

function AbyssFlow.isSelfInTeam(node, tmplId)
    local teamInfo = AbyssFlow.selfTeamInfo(node)
    if not teamInfo then
        return false, nil
    end
    if tmplId and tonumber(teamInfo.AbyssTmplId) ~= tonumber(tmplId) then
        return false, teamInfo
    end
    return true, teamInfo
end

function AbyssFlow.prepareAndCreateTeam(entry, tmplId, maxPlayers)
    if not entry or not PathTool or not PathTool.AbyssSystem then
        AUTO_ABYSS.log("建队失败", { reason = "AbyssSystem missing" }, true)
        return false, "AbyssSystem missing"
    end
    if not PathTool.AbyssSystem.ClientTeamCreatePrepare or not PathTool.AbyssSystem.ClientCreateTeam then
        AUTO_ABYSS.log("建队失败", { reason = "Abyss team api missing" }, true)
        return false, "Abyss team api missing"
    end
    AUTO_ABYSS.log("建队准备", { showId = entry.showId, tmplId = tmplId, maxPlayers = maxPlayers })
    local prepareOk, prepareResult, prepareErr = pcall(function()
        return PathTool.AbyssSystem.ClientTeamCreatePrepare(entry.showId)
    end)
    if not prepareOk or prepareResult == false then
        AUTO_ABYSS.log("建队准备失败", { ok = prepareOk, result = prepareResult, err = prepareErr }, true)
        return false, tostring(prepareErr or prepareResult or "prepare_failed")
    end
    task.wait(0.35)
    AUTO_ABYSS.log("创建队伍请求", { showId = entry.showId, tmplId = tmplId, maxPlayers = maxPlayers })
    local createOk, createResult, createErr = pcall(function()
        return PathTool.AbyssSystem.ClientCreateTeam(entry.showId, tmplId, maxPlayers)
    end)
    if createOk and createResult ~= false then
        AUTO_ABYSS.log("创建队伍请求成功", { result = createResult })
        return true
    end
    AUTO_ABYSS.log("创建队伍请求失败", { ok = createOk, result = createResult, err = createErr }, true)
    return false, tostring(createErr or createResult or "create_failed")
end

function AbyssFlow.leaveTeam(showId)
    if PathTool and PathTool.AbyssSystem then
        AUTO_ABYSS.log("离队/取消准备", { showId = showId })
        if PathTool.AbyssSystem.ClientLeaveTeam then
            pcall(function()
                PathTool.AbyssSystem.ClientLeaveTeam()
            end)
        end
        if showId and PathTool.AbyssSystem.ClientTeamCreatePrepareCancel then
            pcall(function()
                PathTool.AbyssSystem.ClientTeamCreatePrepareCancel(showId)
            end)
        end
    end
end

function AbyssFlow.confirmTeam(entry, tmplId, timeout)
    AUTO_ABYSS.log("确认队伍开始", { showId = entry and entry.showId, tmplId = tmplId, timeout = timeout })
    local startedAt = os.clock()
    while os.clock() - startedAt < (tonumber(timeout) or 5) do
        local inTeam, teamInfo = AbyssFlow.isSelfInTeam(entry and entry.node, tmplId)
        if inTeam and teamInfo and teamInfo.CreateTick ~= nil then
            AUTO_ABYSS.log("确认队伍成功", {
                tmplId = teamInfo.AbyssTmplId,
                maxAmount = teamInfo.MaxAmount,
                createTick = teamInfo.CreateTick,
                leaderId = teamInfo.LeaderId,
            })
            return true, teamInfo
        end
        task.wait(0.2)
    end
    AUTO_ABYSS.log("确认队伍超时", {
        showId = entry and entry.showId,
        nodeTmpl = entry and entry.node and entry.node:GetAttribute("AbyssTmplId"),
        createTick = entry and entry.node and entry.node:GetAttribute("CreateTick"),
    }, true)
    return false, "team_confirm_timeout"
end

function AbyssFlow.waitAutoStart(entry, teamInfo, shouldContinue)
    local waitTime = 30
    if PathTool and PathTool.CfgAbyss and PathTool.CfgAbyss.TeamConfig and PathTool.CfgAbyss.TeamConfig.WaitTime then
        waitTime = tonumber(PathTool.CfgAbyss.TeamConfig.WaitTime) or waitTime
    end
    local createTick = tonumber(teamInfo and teamInfo.CreateTick) or AbyssFlow.serverTime()
    local deadline = createTick + waitTime + AUTO_ABYSS.ENTER_EXTRA_WAIT
    AUTO_ABYSS.log("等待官方倒计时", { showId = entry and entry.showId, createTick = createTick, waitTime = waitTime, deadline = deadline })
    while shouldContinue() do
        if areAllEquippedPetsDead() then
            AUTO_ABYSS.log("等待倒计时中断", { reason = "all_pets_dead" }, true)
            return false, "all_pets_dead"
        end
        if AbyssFlow.isEntered() then
            AUTO_ABYSS.log("已进入Abyss", { syncKey = AbyssFlow.getSyncKey(), areaId = getLocalPlayerAreaId() })
            return true
        end
        local now = AbyssFlow.serverTime()
        if now > deadline then
            AUTO_ABYSS.log("倒计时结束仍未进入", { now = now, deadline = deadline, syncKey = AbyssFlow.getSyncKey() }, true)
            return false, "auto_start_timeout"
        end
        local inTeam = AbyssFlow.isSelfInTeam(entry and entry.node, AUTO_ABYSS.selectedTmplId)
        if not inTeam and not AbyssFlow.getSyncKey() then
            AUTO_ABYSS.log("等待中队伍丢失", { showId = entry and entry.showId, tmplId = AUTO_ABYSS.selectedTmplId }, true)
            return false, "team_lost"
        end
        AUTO_ABYSS.setStatus(string.format("自动Abyss: 等待倒计时 %.0fs", math.max(0, deadline - now)), Color3.fromRGB(255, 220, 120))
        task.wait(0.4)
    end
    return false, "stopped"
end

function AbyssFlow.playerSelectValue(selects)
    if type(selects) ~= "table" or not player then
        return nil
    end
    return tonumber(selects[tostring(player.UserId)] or selects[player.UserId])
end

function AbyssFlow.isTalentSelected(talentInfo)
    if type(talentInfo) ~= "table" or not player then
        return false
    end
    local selected = talentInfo.PlayerSelect
    return type(selected) == "table" and (selected[tostring(player.UserId)] ~= nil or selected[player.UserId] ~= nil)
end

function AbyssFlow.talentPosition(talentInfo)
    local pos = AbyssFlow.cframePosition(type(talentInfo) == "table" and talentInfo.CFrame or nil)
    if pos then
        return pos
    end
    local root = workspace:FindFirstChild("AbyssClientModel")
    if root then
        for _, inst in ipairs(root:GetDescendants()) do
            if inst.Name == "TalentArea" or inst.Name == "Root" then
                pos = getInstancePosition(inst)
                if pos then
                    return pos
                end
            end
        end
    end
    return nil
end

function AbyssFlow.talentQualityScore(quality)
    if quality == nil then
        return 0
    end
    if type(quality) == "number" then
        return quality * 10
    end
    local text = string.lower(tostring(quality))
    if string.find(text, "red", 1, true) then
        return 70
    end
    if string.find(text, "color", 1, true) then
        return 60
    end
    if string.find(text, "orange", 1, true) then
        return 50
    end
    if string.find(text, "purple", 1, true) then
        return 40
    end
    if string.find(text, "blue", 1, true) then
        return 30
    end
    if string.find(text, "green", 1, true) then
        return 20
    end
    if string.find(text, "white", 1, true) then
        return 10
    end
    return 0
end

function AbyssFlow.talentScore(option)
    if not option or not option.TalentTmpl then
        return 0
    end
    if tonumber(option.TalentId) == 50002 then
        return 1000
    end
    local qualityScore = AbyssFlow.talentQualityScore(option.TalentTmpl.Quality)
    local prop = option.TalentTmpl.PlayerProperty
    local tag = type(prop) == "table" and prop.Tag or nil
    if tag == "PetHealthIncreaseRatio" then
        return 500 + qualityScore + ((tonumber(prop.Value) or 0) * 100)
    elseif tag == "PetCriticalProbIncrease" then
        return 400 + qualityScore + ((tonumber(prop.Value) or 0) * 100)
    elseif tag == "PetDamageIncreaseRatio" then
        return 300 + qualityScore + ((tonumber(prop.Value) or 0) * 100)
    elseif tag == "PetCriticalDamageRatioIncrease" then
        return 200 + qualityScore + ((tonumber(prop.Value) or 0) * 100)
    elseif tag == "PetExtraHealthRatioIncrease" then
        return 100 + qualityScore + ((tonumber(prop.Value) or 0) * 100)
    elseif option.TalentTmpl.PlayerLogicProperty then
        return 90 + qualityScore
    end
    return 0
end

function AbyssFlow.selectableTalents(abyssId, talentInfo)
    if type(talentInfo) ~= "table" or not talentInfo.Seed then
        return nil
    end
    local gamePlayer = getGamePlayer()
    if not gamePlayer or not PathTool or not PathTool.AbyssSystem or not PathTool.AbyssSystem.GenerateSelectableTalents then
        return nil
    end
    local seed = talentInfo.Seed
    local selfUserId = player and player.UserId
    local selfSeedInfo = type(talentInfo.PlayerRandSeed) == "table" and selfUserId and talentInfo.PlayerRandSeed[tostring(selfUserId)] or nil
    if type(selfSeedInfo) == "table" and selfSeedInfo.Seed then
        seed = selfSeedInfo.Seed
    end
    local ok, list = pcall(function()
        return PathTool.AbyssSystem.GenerateSelectableTalents(seed, gamePlayer, abyssId)
    end)
    if ok and type(list) == "table" then
        return list
    end
    return nil
end

function AbyssFlow.bestTalentChoice()
    local abyssId = AbyssFlow.syncValue("AbyssId")
    local talentInfo = AbyssFlow.syncValue("TalentInfo")
    if type(talentInfo) ~= "table" or not talentInfo.Seed or AbyssFlow.isTalentSelected(talentInfo) then
        return nil, "no_talent"
    end
    local pos = AbyssFlow.talentPosition(talentInfo)
    if not pos then
        return nil, "talent_position_missing"
    end
    local list = AbyssFlow.selectableTalents(abyssId, talentInfo)
    if not list or #list == 0 then
        return nil, "talent_list_empty"
    end
    local bestIndex = 1
    local bestScore = -math.huge
    for index, option in ipairs(list) do
        local score = AbyssFlow.talentScore(option)
        if score > bestScore then
            bestIndex = index
            bestScore = score
        end
    end
    return {
        abyssId = abyssId,
        talentInfo = talentInfo,
        position = pos,
        list = list,
        bestIndex = bestIndex,
        best = list[bestIndex],
        bestScore = bestScore,
    }
end

function AbyssFlow.retryMoveToFreshTarget(label, resolver, stopDistance, timeout, shouldContinue, statusBuilder)
    local lastErr = nil
    for attempt = 1, AUTO_ABYSS.MOVE_RETRY_LIMIT do
        if not shouldContinue() then
            return nil, "stopped"
        end
        local target, resolveErr = resolver()
        if not target then
            return nil, resolveErr or (label .. "_target_missing")
        end
        local pos = target.position or target.pos
        if not pos then
            return nil, resolveErr or (label .. "_position_missing")
        end
        local statusText = statusBuilder and statusBuilder(target, attempt) or ("自动Abyss: 移动 " .. tostring(label))
        AUTO_ABYSS.setStatus(statusText, Color3.fromRGB(255, 220, 120))
        local walked, walkErr = walkToPosition(pos, stopDistance, timeout, shouldContinue)
        if walked then
            return target
        end
        lastErr = walkErr or "walk_not_reached"
        AUTO_ABYSS.log("移动失败，刷新目标后重试", {
            label = label,
            attempt = attempt,
            err = lastErr,
        }, true)
        if attempt < AUTO_ABYSS.MOVE_RETRY_LIMIT then
            task.wait(0.2)
        end
    end
    return nil, lastErr or "walk_not_reached"
end

function AbyssFlow.selectTalent(shouldContinue)
    local initialChoice, initialErr = AbyssFlow.bestTalentChoice()
    if not initialChoice then
        if initialErr == "no_talent" then
            AUTO_ABYSS.log("跳过天赋", { reason = initialErr })
            return true, "no_talent"
        end
        AUTO_ABYSS.log("天赋准备失败", { reason = initialErr }, true)
        return false, initialErr
    end
    AUTO_ABYSS.log("天赋选择目标", {
        abyssId = initialChoice.abyssId,
        seed = initialChoice.talentInfo and initialChoice.talentInfo.Seed,
        count = #initialChoice.list,
        bestIndex = initialChoice.bestIndex,
        bestTalent = initialChoice.best and initialChoice.best.TalentId,
        score = initialChoice.bestScore,
    })
    for attempt = 1, AUTO_ABYSS.TALENT_RETRY_LIMIT do
        if not shouldContinue() then
            AUTO_ABYSS.log("天赋选择停止", { reason = "stopped", attempt = attempt }, true)
            return false, "stopped"
        end
        local choice, walkErr = AbyssFlow.retryMoveToFreshTarget(
            "talent",
            AbyssFlow.bestTalentChoice,
            AUTO_ABYSS.TALENT_REACH_RADIUS,
            AUTO_ABYSS.TALENT_WALK_TIMEOUT,
            shouldContinue,
            function(target)
                return "自动Abyss: 前往天赋 " .. tostring(target.best and target.best.TalentId or target.bestIndex)
            end
        )
        if not choice then
            AUTO_ABYSS.log("天赋寻路失败", { attempt = attempt, err = walkErr }, true)
            return false, walkErr or "talent_walk_failed"
        end
        AUTO_ABYSS.setStatus("自动Abyss: 等待进入天赋区域", Color3.fromRGB(255, 220, 120))
        task.wait(0.25)
        AUTO_ABYSS.log("调用选择天赋", { talentId = choice.best and choice.best.TalentId, index = choice.bestIndex, attempt = attempt })
        local ok, result = pcall(function()
            return PathTool.AbyssSystem.ClientSelectTalent(choice.bestIndex)
        end)
        if ok and result ~= false then
            local confirmStarted = os.clock()
            while os.clock() - confirmStarted < 3 do
                if not shouldContinue() then
                    return false, "stopped"
                end
                local latestTalentInfo = AbyssFlow.syncValue("TalentInfo")
                if not latestTalentInfo or AbyssFlow.isTalentSelected(latestTalentInfo) then
                    AUTO_ABYSS.setStatus("自动Abyss: 已选择天赋 " .. tostring(choice.best and choice.best.TalentId or choice.bestIndex), Color3.fromRGB(0, 255, 136))
                    AUTO_ABYSS.log("天赋确认成功", { talentId = choice.best and choice.best.TalentId, index = choice.bestIndex, attempt = attempt })
                    return true
                end
                task.wait(0.2)
            end
        else
            AUTO_ABYSS.log("调用选择天赋失败", { ok = ok, result = result, talentId = choice.best and choice.best.TalentId, index = choice.bestIndex }, true)
        end
        AUTO_ABYSS.log("天赋确认失败", { talentId = choice.best and choice.best.TalentId, index = choice.bestIndex, attempt = attempt }, true)
        AUTO_ABYSS.setStatus(string.format("自动Abyss: 天赋确认失败 %d/%d", attempt, AUTO_ABYSS.TALENT_RETRY_LIMIT), Color3.fromRGB(255, 150, 150))
        task.wait(0.35)
    end
    AUTO_ABYSS.log("天赋选择最终失败", { talentId = initialChoice.best and initialChoice.best.TalentId, index = initialChoice.bestIndex }, true)
    return false, "talent_select_failed"
end

function AbyssFlow.waitBeforeDoorEntry(shouldContinue)
    local startedAt = os.clock()
    while os.clock() - startedAt < AUTO_ABYSS.TALENT_RECOVER_TIMEOUT do
        if not shouldContinue() then
            return false, "stopped"
        end
        local allDead, deadCount, total, petStatus = areAllEquippedPetsDead()
        if allDead then
            AUTO_ABYSS.log("进门前检测到宠物全死", {
                deadCount = deadCount,
                total = total,
            }, true)
            return false, "all_pets_dead"
        end
        local minHp = petStatus and petStatus.minPct or 1.0
        local observed = petStatus and petStatus.observed or 0
        if observed > 0 and minHp >= 0.99 then
            AUTO_ABYSS.log("进门前回血完成", {
                hpPct = math.floor(minHp * 100),
                observed = observed,
            })
            return true
        end
        AUTO_ABYSS.setStatus(string.format("自动Abyss: 进门前等回血 %.0f%%", minHp * 100), Color3.fromRGB(255, 220, 120))
        task.wait(0.5)
    end
    AUTO_ABYSS.log("进门前回血超时，继续流程", { timeout = AUTO_ABYSS.TALENT_RECOVER_TIMEOUT }, true)
    return true, "door_recover_timeout"
end

function AbyssFlow.previewDoorReward(roomTypeCfg, seed)
    if not roomTypeCfg or not roomTypeCfg.ExtraWinReward or not seed then
        return nil
    end
    if not PathTool or not PathTool.RewardSystem or not PathTool.RewardSystem.__DoRewardGroup then
        return nil
    end
    local rewards = {}
    local ok = pcall(function()
        PathTool.RewardSystem.__DoRewardGroup(nil, roomTypeCfg.ExtraWinReward, rewards, Random.new(seed), false, true)
    end)
    if ok and rewards[1] then
        return rewards[1]
    end
    return nil
end

function AbyssFlow.rewardScore(reward)
    if type(reward) ~= "table" then
        return 0
    end
    local res = reward.RewardRes
    local tmplId = tonumber(reward.TmplId)
    local count = tonumber(reward.Count) or 0
    if res == "CommonItem" and tmplId == 18 then
        return 20000
    end
    if res == "Value" and reward.ValueType == "HuoBi_13" then
        if count >= 100 then
            return 500
        elseif count >= 80 then
            return 400
        elseif count >= 50 then
            return 300
        end
    end
    if res == "CommonItem" and tmplId == 21 then
        return 200
    end
    if res == "CommonItem" and tmplId == 22 then
        return 100
    end
    if res == "Value" and reward.ValueType == "HuoBi_1" then
        return 50
    end
    return 0
end

function AbyssFlow.roomPriority(roomType)
    roomType = tonumber(roomType)
    if roomType == 4 then
        return 10000
    end
    if roomType == 3 then
        return 3000
    end
    if roomType == 2 then
        return 2000
    end
    if roomType == 1 then
        return 1000
    end
    return 0
end

function AbyssFlow.bestDoor()
    local doorInfos = AbyssFlow.syncValue("DoorInfos")
    if type(doorInfos) ~= "table" then
        return nil
    end
    local openDoors = {}
    local best = nil
    local bestScore = -math.huge
    local _, hrp = getCharacterAndRootPart()
    local origin = hrp and hrp.Position
    for index, info in ipairs(doorInfos) do
        local pos = AbyssFlow.cframePosition(info.CFrame)
        if info.Opened and pos then
            local roomCfg = PathTool and PathTool.CfgAbyss and PathTool.CfgAbyss.RoomTmpls and PathTool.CfgAbyss.RoomTmpls[info.RoomId]
            local roomTypeCfg = PathTool and PathTool.CfgAbyss and PathTool.CfgAbyss.RoomTypes and roomCfg and PathTool.CfgAbyss.RoomTypes[roomCfg.RoomType]
            local reward = AbyssFlow.previewDoorReward(roomTypeCfg, info.ExtraWinRewardSeed)
            local roomType = roomCfg and roomCfg.RoomType
            local rewardScore = AbyssFlow.rewardScore(reward)
            local priorityScore = AbyssFlow.roomPriority(roomType)
            local distance = origin and (origin - pos).Magnitude or 0
            local score = priorityScore + rewardScore - (distance * 0.01)
            local door = {
                index = index,
                info = info,
                position = pos,
                reward = reward,
                score = score,
                rewardScore = rewardScore,
                roomType = roomType,
                distance = distance,
            }
            table.insert(openDoors, door)
            if score > bestScore then
                bestScore = score
                best = door
            end
        end
    end
    if #openDoors == 0 then
        return nil
    end
    if best then
        return best
    end
    return openDoors[math.random(1, #openDoors)]
end

function AbyssFlow.rewardText(reward)
    if type(reward) ~= "table" then
        return "随机奖励"
    end
    local rewardName = AUTO_ABYSS.resolveRewardName(reward)
    local rewardCount = tonumber(reward.Count) or 1
    if rewardCount > 1 then
        return string.format("%s x%s", rewardName, tostring(rewardCount))
    end
    return rewardName
end

function AbyssFlow.waitAfterDoorSelection(door, selectedStage, shouldContinue)
    local startedAt = os.clock()
    while os.clock() - startedAt < AUTO_ABYSS.DOOR_PROGRESS_TIMEOUT do
        if not shouldContinue() then
            return false, "stopped"
        end
        if not AbyssFlow.isStillInAbyss() then
            AUTO_ABYSS.log("选门后已离开当前场景", {
                doorIndex = door and door.index,
                selectedStage = selectedStage,
            })
            return true
        end

        local currentStage = AbyssFlow.syncValue("Stage")
        if currentStage ~= nil and selectedStage ~= nil and tonumber(currentStage) ~= tonumber(selectedStage) then
            AUTO_ABYSS.log("选门后关卡推进成功", {
                doorIndex = door and door.index,
                fromStage = selectedStage,
                toStage = currentStage,
            })
            return true
        end

        local currentSelect = AbyssFlow.playerSelectValue(AbyssFlow.syncValue("PlayerSelects"))
        if currentSelect == door.index then
            AUTO_ABYSS.setStatus("自动Abyss: 等待进门", Color3.fromRGB(255, 220, 120))
        else
            AUTO_ABYSS.setStatus("自动Abyss: 等待房间推进", Color3.fromRGB(255, 220, 120))
        end
        task.wait(0.25)
    end

    AUTO_ABYSS.log("选门后等待推进超时", {
        doorIndex = door and door.index,
        stage = AbyssFlow.syncValue("Stage"),
        selected = AbyssFlow.playerSelectValue(AbyssFlow.syncValue("PlayerSelects")),
    }, true)
    return false, "door_progress_timeout"
end

function AbyssFlow.selectDoor(shouldContinue)
    local currentSelect = AbyssFlow.playerSelectValue(AbyssFlow.syncValue("PlayerSelects"))
    if currentSelect then
        AUTO_ABYSS.log("跳过选门", { reason = "already_selected", selected = currentSelect })
        return true, "already_selected"
    end
    local selectEndTick = tonumber(AbyssFlow.syncValue("SelectEndTick"))
    if selectEndTick and AbyssFlow.serverTime() > selectEndTick then
        AUTO_ABYSS.log("跳过选门", { reason = "door_select_window_ended", selectEndTick = selectEndTick, now = AbyssFlow.serverTime() }, true)
        return true, "door_select_window_ended"
    end
    local stageBeforeSelect = AbyssFlow.syncValue("Stage")
    for attempt = 1, AUTO_ABYSS.DOOR_RETRY_LIMIT do
        if not shouldContinue() then
            AUTO_ABYSS.log("选门停止", { reason = "stopped", attempt = attempt }, true)
            return false, "stopped"
        end
        local door = AbyssFlow.bestDoor()
        if not door then
            AUTO_ABYSS.log("没有可选门", { attempt = attempt, stage = AbyssFlow.syncValue("Stage"), selectEndTick = AbyssFlow.syncValue("SelectEndTick") })
            return true, "no_open_door"
        end
        AUTO_ABYSS.log("选门目标", {
            attempt = attempt,
            doorIndex = door.index,
            roomId = door.info and door.info.RoomId,
            reward = AbyssFlow.rewardText(door.reward),
            score = door.score,
            selectEndTick = selectEndTick,
        })
        local walkedDoor, walkErr = AbyssFlow.retryMoveToFreshTarget(
            "door",
            AbyssFlow.bestDoor,
            AUTO_ABYSS.DOOR_REACH_RADIUS,
            AUTO_ABYSS.DOOR_WALK_TIMEOUT,
            shouldContinue,
            function(target)
                return "自动Abyss: 走门 " .. tostring(target.index) .. " " .. AbyssFlow.rewardText(target.reward)
            end
        )
        if not walkedDoor then
            AUTO_ABYSS.log("走门寻路失败", { doorIndex = door.index, err = walkErr, attempt = attempt }, true)
            return false, walkErr or "door_walk_failed"
        end
        door = walkedDoor
        local confirmStarted = os.clock()
        while os.clock() - confirmStarted < AUTO_ABYSS.DOOR_CONFIRM_TIMEOUT do
            if not shouldContinue() then
                return false, "stopped"
            end
            local selectedIndex = AbyssFlow.playerSelectValue(AbyssFlow.syncValue("PlayerSelects"))
            if selectedIndex == door.index then
                AUTO_ABYSS.setStatus("自动Abyss: 已确认选门 " .. tostring(door.index), Color3.fromRGB(0, 255, 136))
                AUTO_ABYSS.log("选门确认成功", { doorIndex = door.index, attempt = attempt })
                return AbyssFlow.waitAfterDoorSelection(door, stageBeforeSelect, shouldContinue)
            end
            task.wait(0.2)
        end
        AUTO_ABYSS.log("选门未确认", {
            doorIndex = door.index,
            selected = AbyssFlow.playerSelectValue(AbyssFlow.syncValue("PlayerSelects")),
            attempt = attempt,
        }, true)
        AUTO_ABYSS.setStatus(string.format("自动Abyss: 选门未确认 %d/%d", attempt, AUTO_ABYSS.DOOR_RETRY_LIMIT), Color3.fromRGB(255, 150, 150))
        task.wait(0.35)
    end
    AUTO_ABYSS.log("选门最终失败", { reason = "door_select_failed" }, true)
    return false, "door_select_failed"
end

function AbyssFlow.isFinalStage(abyssId, stage)
    local tmpl = PathTool and PathTool.CfgAbyss and PathTool.CfgAbyss.Tmpls and PathTool.CfgAbyss.Tmpls[tonumber(abyssId)]
    local stages = tmpl and tmpl.Stages
    return type(stages) == "table" and tonumber(stage) and tonumber(stage) >= #stages
end

function AbyssFlow.debugSync(reason)
    AUTO_ABYSS.log("同步快照", {
        reason = reason,
        syncKey = AbyssFlow.getSyncKey(),
        abyssId = AbyssFlow.syncValue("AbyssId"),
        stage = AbyssFlow.syncValue("Stage"),
        selectEndTick = AbyssFlow.syncValue("SelectEndTick"),
    }, true)
    if AUTO_ABYSS.logEnabled then
        warn("[AutoAbyss] DoorInfos=", tostring(AbyssFlow.syncValue("DoorInfos")), "TalentInfo=", tostring(AbyssFlow.syncValue("TalentInfo")), "PlayerSelects=", tostring(AbyssFlow.syncValue("PlayerSelects")))
    end
end

function AbyssFlow.runInside(shouldContinue)
    AUTO_ABYSS.log("进入Abyss内部流程", { syncKey = AbyssFlow.getSyncKey(), areaId = getLocalPlayerAreaId() })
    local lastProgressAt = os.clock()
    local lastStage = nil
    local completedSince = nil
    local keepInside = function()
        return shouldContinue() and not areAllEquippedPetsDead() and AbyssFlow.isStillInAbyss()
    end
    while shouldContinue() do
        if areAllEquippedPetsDead() then
            AUTO_ABYSS.log("内部流程中断", { reason = "all_pets_dead" }, true)
            return false, "all_pets_dead"
        end
        if not AbyssFlow.isStillInAbyss() then
            AUTO_ABYSS.log("内部流程结束", { reason = "not_in_abyss", syncKey = AbyssFlow.getSyncKey(), areaId = getLocalPlayerAreaId() })
            return true
        end

        local abyssId = AbyssFlow.syncValue("AbyssId")
        local stage = AbyssFlow.syncValue("Stage")
        if stage ~= nil and stage ~= lastStage then
            lastStage = stage
            lastProgressAt = os.clock()
            AUTO_ABYSS.log("关卡变化", {
                abyssId = abyssId,
                stage = stage,
                hasDoorInfos = type(AbyssFlow.syncValue("DoorInfos")) == "table",
                hasTalentInfo = type(AbyssFlow.syncValue("TalentInfo")) == "table",
            })
        end

        local talentInfo = AbyssFlow.syncValue("TalentInfo")
        if type(talentInfo) == "table" and talentInfo.Seed and not AbyssFlow.isTalentSelected(talentInfo) then
            local ok, err = AbyssFlow.selectTalent(keepInside)
            if not ok then
                if areAllEquippedPetsDead() then
                    return false, "all_pets_dead"
                end
                AbyssFlow.debugSync(err)
                return false, err
            end
            lastProgressAt = os.clock()
            task.wait(0.4)
        else
            local door = AbyssFlow.bestDoor()
            if door and not AbyssFlow.playerSelectValue(AbyssFlow.syncValue("PlayerSelects")) then
                local recoveredBeforeDoor, recoverErr = AbyssFlow.waitBeforeDoorEntry(keepInside)
                if not recoveredBeforeDoor then
                    if recoverErr == "all_pets_dead" or areAllEquippedPetsDead() then
                        return false, "all_pets_dead"
                    end
                    return false, recoverErr
                end
                local ok, err = AbyssFlow.selectDoor(keepInside)
                if not ok then
                    if areAllEquippedPetsDead() then
                        return false, "all_pets_dead"
                    end
                    AbyssFlow.debugSync(err)
                    return false, err
                end
                lastProgressAt = os.clock()
                task.wait(0.5)
            elseif isRiftArenaResultStatus() and AbyssFlow.isFinalStage(abyssId, stage) then
                completedSince = completedSince or os.clock()
                if os.clock() - completedSince >= 2 then
                    AUTO_ABYSS.log("最终结果确认", { abyssId = abyssId, stage = stage })
                    return true
                end
                task.wait(0.4)
            else
                completedSince = nil
                local _, hrp = getCharacterAndRootPart()
                local origin = hrp and hrp.Position
                local target = origin and findNearestAliveRiftMonster(origin, AUTO_ABYSS.MONSTER_SEARCH_RADIUS) or nil
                if target then
                    if areAllEquippedPetsDead() then
                        AUTO_ABYSS.log("战斗前中断", { reason = "all_pets_dead", monsterId = target.id }, true)
                        return false, "all_pets_dead"
                    end
                    lastProgressAt = os.clock()
                    if target.position and target.distance and target.distance > AUTO_ABYSS.MONSTER_REACH_RADIUS then
                        local walkedTarget, walkErr = AbyssFlow.retryMoveToFreshTarget(
                            "monster",
                            function()
                                local _, latestHrp = getCharacterAndRootPart()
                                local latestOrigin = latestHrp and latestHrp.Position
                                return latestOrigin and findNearestAliveRiftMonster(latestOrigin, AUTO_ABYSS.MONSTER_SEARCH_RADIUS) or nil, "monster_missing"
                            end,
                            AUTO_ABYSS.MONSTER_REACH_RADIUS,
                            25,
                            keepInside,
                            function()
                                return "自动Abyss: 寻路靠近怪物"
                            end
                        )
                        if not walkedTarget and areAllEquippedPetsDead() then
                            AUTO_ABYSS.log("靠近怪物中断", { reason = "all_pets_dead", monsterId = target.id, walkErr = walkErr }, true)
                            return false, "all_pets_dead"
                        elseif not walkedTarget then
                            AUTO_ABYSS.log("靠近怪物失败但继续攻击", { monsterId = target.id, distance = target.distance, walkErr = walkErr }, true)
                        else
                            target = walkedTarget
                        end
                    end
                    AUTO_ABYSS.setStatus("自动Abyss: 战斗 " .. tostring(target.id), Color3.fromRGB(255, 220, 120))
                    local attacked = attackRiftMonster(target.id)
                    if not attacked then
                        AUTO_ABYSS.log("攻击请求失败", { monsterId = target.id }, true)
                    end
                    if areAllEquippedPetsDead() then
                        AUTO_ABYSS.log("战斗后中断", { reason = "all_pets_dead", monsterId = target.id }, true)
                        return false, "all_pets_dead"
                    end
                    local waited = interruptibleWait(0.7, keepInside)
                    if not waited and areAllEquippedPetsDead() then
                        AUTO_ABYSS.log("战斗等待中断", { reason = "all_pets_dead", monsterId = target.id }, true)
                        return false, "all_pets_dead"
                    end
                else
                    AUTO_ABYSS.setStatus("自动Abyss: 等待怪物/门/天赋", Color3.fromRGB(255, 220, 120))
                    if os.clock() - lastProgressAt > AUTO_ABYSS.UNKNOWN_TIMEOUT then
                        AbyssFlow.debugSync("unknown_state_timeout")
                        return false, "unknown_state_timeout"
                    end
                    local waited = interruptibleWait(0.5, keepInside)
                    if not waited and areAllEquippedPetsDead() then
                        AUTO_ABYSS.log("空闲等待中断", { reason = "all_pets_dead" }, true)
                        return false, "all_pets_dead"
                    end
                end
            end
        end
    end
    return false, "stopped"
end

function AbyssFlow.recoverAfterRun(shouldContinue)
    local deadAny, deadCount, petStatus = isAnyEquippedPetDead()
    if deadAny then
        AUTO_ABYSS.log("恢复流程", { mode = "revive", deadCount = deadCount })
        AUTO_ABYSS.setStatus("自动Abyss: 宠物死亡 " .. tostring(deadCount), Color3.fromRGB(255, 220, 120))
        return recoverPetsByWalking(shouldContinue, AUTO_ABYSS.setStatus, "自动Abyss")
    end
    if not petStatus or petStatus.observed <= 0 then
        AUTO_ABYSS.log("恢复流程", { mode = "wait_pet_sync" })
        AUTO_ABYSS.setStatus("自动Abyss: 等待宠物状态同步", Color3.fromRGB(255, 220, 120))
    else
        AUTO_ABYSS.log("恢复流程", { mode = "wait_full_hp", observed = petStatus.observed, minPct = petStatus.minPct })
    end
    return waitUntilPetsRecoveredFully(AUTO_RIFT.RECOVER_TIMEOUT, shouldContinue, AUTO_ABYSS.setStatus, "自动Abyss")
end

function AbyssFlow.getTmplLimit(tmplId)
    local tmpl = PathTool and PathTool.CfgAbyss and PathTool.CfgAbyss.Tmpls and PathTool.CfgAbyss.Tmpls[tonumber(tmplId)]
    return tonumber(tmpl and tmpl.PlayerAmountLimit) or 4
end

runAutoAbyssOnce = function(shouldContinue)
    local runStartedAt = os.clock()
    local runRecorded = false
    local lootSnapshotBefore = nil
    local function finishRun(actualOk, actualReason, statsOk, statsReason)
        if not runRecorded then
            runRecorded = true
            local shouldRecordStats = actualReason ~= "no_abyss_entry" and actualReason ~= "stopped"
            if actualOk ~= true and actualReason ~= "no_abyss_entry" and actualReason ~= "stopped" then
                AUTO_ABYSS.printFailureReason(actualReason, statsReason)
            end
            if shouldRecordStats and lootSnapshotBefore then
                AUTO_ABYSS.recordSnapshotDelta(lootSnapshotBefore, AUTO_ABYSS.captureLootSnapshot())
            end
            local finalStatsOk = statsOk
            if finalStatsOk == nil then
                finalStatsOk = actualOk == true and actualReason ~= "all_pets_dead"
            end
            if shouldRecordStats then
                AUTO_ABYSS.recordRun(finalStatsOk == true, os.clock() - runStartedAt)
            end
        end
        return actualOk, actualReason or statsReason
    end

    AUTO_ABYSS.log("本轮开始", { tmplId = AUTO_ABYSS.selectedTmplId, players = AUTO_ABYSS.selectedPlayers, alreadyInAbyss = AbyssFlow.isEntered() })
    if not WaitForPathTool(10) then
        AUTO_ABYSS.setStatus("自动Abyss: PathTool超时", Color3.fromRGB(255, 150, 150))
        AUTO_ABYSS.log("本轮失败", { reason = "pathtool_timeout" }, true)
        return finishRun(false, "pathtool_timeout")
    end
    if not PathTool.CfgAbyss or not PathTool.AbyssSystem then
        AUTO_ABYSS.setStatus("自动Abyss: Abyss模块缺失", Color3.fromRGB(255, 150, 150))
        AUTO_ABYSS.log("本轮失败", { reason = "abyss_module_missing", hasCfgAbyss = PathTool.CfgAbyss ~= nil, hasAbyssSystem = PathTool.AbyssSystem ~= nil }, true)
        return finishRun(false, "abyss_module_missing")
    end
    lootSnapshotBefore = AUTO_ABYSS.captureLootSnapshot()
    if not AUTO_ABYSS.isTmplUnlocked(AUTO_ABYSS.selectedTmplId) then
        AUTO_ABYSS.selectedTmplId = 1001
        AUTO_ABYSS.updateControls()
        saveTrackerSettings()
        AUTO_ABYSS.setStatus("自动Abyss: Hard未解锁，已切Normal", Color3.fromRGB(255, 220, 120))
    end

    if AbyssFlow.isEntered() then
        AUTO_ABYSS.log("检测到已在Abyss内，接管内部流程", { syncKey = AbyssFlow.getSyncKey(), areaId = getLocalPlayerAreaId() })
        local cleared, battleErr = AbyssFlow.runInside(shouldContinue)
        AUTO_ABYSS.log("内部流程返回", { cleared = cleared, err = battleErr })
        AUTO_ABYSS.setStatus("自动Abyss: 退出地下城", Color3.fromRGB(255, 220, 120))
        local left, leftErr = AbyssFlow.ensureLeave(AUTO_ABYSS.EXIT_TIMEOUT, shouldContinue)
        if not left then
            AUTO_ABYSS.log("本轮失败", { step = "leave_after_takeover", reason = leftErr }, true)
            return finishRun(false, leftErr)
        end
        local recovered, recoverErr = AbyssFlow.recoverAfterRun(shouldContinue)
        if not recovered then
            AUTO_ABYSS.log("本轮失败", { step = "recover_after_takeover", reason = recoverErr }, true)
            return finishRun(false, recoverErr)
        end
        if not cleared and battleErr ~= "all_pets_dead" then
            AUTO_ABYSS.log("本轮失败", { step = "inside_after_takeover", reason = battleErr }, true)
            return finishRun(false, battleErr)
        end
        AUTO_ABYSS.setStatus("自动Abyss: 本轮完成", Color3.fromRGB(0, 255, 136))
        AUTO_ABYSS.log("本轮完成", { mode = "takeover" })
        return finishRun(true, nil, cleared ~= false or battleErr ~= "all_pets_dead")
    end

    if isAnyEquippedPetDead() then
        AUTO_ABYSS.log("入场前检测到宠物死亡，先恢复")
        local recovered, recoverErr = recoverPetsByWalking(shouldContinue, AUTO_ABYSS.setStatus, "自动Abyss")
        if not recovered then
            AUTO_ABYSS.log("本轮失败", { step = "pre_recover", reason = recoverErr }, true)
            return finishRun(false, recoverErr)
        end
    end


    local entry, findErr
    local walkSuccess = false
    local walkErr = nil
    for attempt = 1, 3 do
        entry, findErr = AbyssFlow.findNearestEntry(AUTO_ABYSS.DETECT_RADIUS)
        if not entry then
            AUTO_ABYSS.setStatus("自动Abyss: 附近无Abyss入口", Color3.fromRGB(180, 180, 180))
            AUTO_ABYSS.log("扫描入口失败", { radius = AUTO_ABYSS.DETECT_RADIUS, reason = findErr, attempt = attempt })
            interruptibleWait(1, shouldContinue)
        else
            AUTO_ABYSS.log("找到Abyss入口", { showId = entry.showId, distance = math.floor((entry.distance or 0) * 10) / 10, node = entry.node and entry.node:GetFullName(), attempt = attempt })
            local movedEntry, moveErr = AbyssFlow.retryMoveToFreshTarget(
                "entry",
                function()
                    return AbyssFlow.findNearestEntry(AUTO_ABYSS.DETECT_RADIUS)
                end,
                AUTO_ABYSS.REACH_RADIUS,
                AUTO_ABYSS.WALK_TIMEOUT,
                shouldContinue,
                function(target)
                    return string.format("自动Abyss: 前往入口 %s %.0f (第%d次)", tostring(target.showId), target.distance or 0, attempt)
                end
            )
            walkSuccess = movedEntry ~= nil
            walkErr = moveErr
            if walkSuccess then
                entry = movedEntry
                AUTO_ABYSS.log("入口寻路完成", { showId = entry.showId, attempt = attempt })
                break
            else
                AbyssFlow.markFailed(entry.showId)
                AUTO_ABYSS.log("入口寻路失败", { showId = entry.showId, reason = walkErr, attempt = attempt }, true)
                interruptibleWait(0.8, shouldContinue)
            end
        end
    end
    if not walkSuccess then
        return finishRun(false, walkErr or findErr or "entry_walk_failed")
    end

    task.wait(0.4)
    local maxPlayers = math.min(tonumber(AUTO_ABYSS.selectedPlayers) or 1, AbyssFlow.getTmplLimit(AUTO_ABYSS.selectedTmplId))
    AUTO_ABYSS.setStatus("自动Abyss: 创建房间", Color3.fromRGB(255, 220, 120))
    local created, createErr = AbyssFlow.prepareAndCreateTeam(entry, AUTO_ABYSS.selectedTmplId, maxPlayers)
    if not created then
        AbyssFlow.leaveTeam(entry.showId)
        AbyssFlow.markFailed(entry.showId)
        AUTO_ABYSS.log("本轮失败", { step = "create_team", reason = createErr, showId = entry.showId }, true)
        return finishRun(false, createErr)
    end

    local confirmed, teamInfoOrErr = AbyssFlow.confirmTeam(entry, AUTO_ABYSS.selectedTmplId, 6)
    if not confirmed then
        AbyssFlow.leaveTeam(entry.showId)
        AbyssFlow.markFailed(entry.showId)
        AUTO_ABYSS.log("本轮失败", { step = "confirm_team", reason = teamInfoOrErr, showId = entry.showId }, true)
        return finishRun(false, teamInfoOrErr)
    end

    local entered, enterErr = AbyssFlow.waitAutoStart(entry, teamInfoOrErr, shouldContinue)
    if not entered then
        AbyssFlow.leaveTeam(entry.showId)
        AbyssFlow.markFailed(entry.showId)
        if enterErr == "all_pets_dead" then
            AUTO_ABYSS.log("倒计时期间宠物全死，退出并恢复", { showId = entry.showId }, true)
            local left = AbyssFlow.ensureLeave(4, shouldContinue)
            local recovered = AbyssFlow.recoverAfterRun(shouldContinue)
            return finishRun(left and recovered, "all_pets_dead", false, "all_pets_dead")
        end
        AUTO_ABYSS.log("本轮失败", { step = "wait_auto_start", reason = enterErr, showId = entry.showId }, true)
        return finishRun(false, enterErr)
    end

    local cleared, battleErr = AbyssFlow.runInside(shouldContinue)
    AUTO_ABYSS.log("内部流程返回", { cleared = cleared, err = battleErr })
    AUTO_ABYSS.setStatus("自动Abyss: 退出地下城", Color3.fromRGB(255, 220, 120))
    local left, leftErr = AbyssFlow.ensureLeave(AUTO_ABYSS.EXIT_TIMEOUT, shouldContinue)
    if not left then
        AUTO_ABYSS.log("本轮失败", { step = "leave_after_run", reason = leftErr }, true)
        return finishRun(false, leftErr)
    end
    local recovered, recoverErr = AbyssFlow.recoverAfterRun(shouldContinue)
    if not recovered then
        AUTO_ABYSS.log("本轮失败", { step = "recover_after_run", reason = recoverErr }, true)
        return finishRun(false, recoverErr)
    end
    if not cleared and battleErr ~= "all_pets_dead" then
        AUTO_ABYSS.log("本轮失败", { step = "inside", reason = battleErr }, true)
        return finishRun(false, battleErr)
    end
    AUTO_ABYSS.setStatus("自动Abyss: 本轮完成", Color3.fromRGB(0, 255, 136))
    AUTO_ABYSS.log("本轮完成", { mode = "normal" })
    return finishRun(true, nil, cleared ~= false or battleErr ~= "all_pets_dead")
end

runAutoRiftOnce = function(shouldContinue)
    if not WaitForPathTool(10) then
        setAutoRiftStatus("刷Rift: PathTool超时", Color3.fromRGB(255, 150, 150))
        return false, "pathtool_timeout"
    end

    local deadAny = isAnyEquippedPetDead()
    if deadAny then
        local recovered, recoverErr = recoverPetsByWalking(shouldContinue)
        if not recovered then
            setAutoRiftStatus("刷Rift: 复活失败 " .. tostring(recoverErr), Color3.fromRGB(255, 150, 150))
            return false, recoverErr
        end
    end

    local riftInfo, findErr = findNearestAvailableFixedRift(AUTO_RIFT.DETECT_RADIUS)
    if not riftInfo then
        setAutoRiftStatus("刷Rift: 100范围无可进Rift", Color3.fromRGB(180, 180, 180))
        interruptibleWait(1, shouldContinue)
        return false, findErr
    end

    setAutoRiftStatus(string.format("刷Rift: 前往 %s %.0f", tostring(riftInfo.showId), riftInfo.distance), Color3.fromRGB(255, 220, 120))
    local walked, walkErr = walkToPosition(riftInfo.position, AUTO_RIFT.REACH_RADIUS, AUTO_RIFT.WALK_TIMEOUT, shouldContinue)
    if not walked then
        markRiftFailed(riftInfo.showId, riftInfo.startTick)
        setAutoRiftStatus("刷Rift: 寻路失败 " .. tostring(walkErr), Color3.fromRGB(255, 150, 150))
        return false, walkErr
    end

    interruptibleWait(0.5, shouldContinue)
    riftInfo = refreshFixedRiftInfo(riftInfo)
    if not riftInfo then
        setAutoRiftStatus("刷Rift: Rift已不可进入", Color3.fromRGB(180, 180, 180))
        return false, "rift_not_available"
    end

    setAutoRiftStatus("刷Rift: 创建队伍", Color3.fromRGB(255, 220, 120))
    local created, createErr = createRiftTeam(riftInfo)
    if not created then
        markRiftFailed(riftInfo.showId, riftInfo.startTick)
        setAutoRiftStatus("刷Rift: 建队失败 " .. tostring(createErr), Color3.fromRGB(255, 150, 150))
        return false, createErr
    end

    interruptibleWait(0.8, shouldContinue)
    setAutoRiftStatus("刷Rift: 进入裂缝", Color3.fromRGB(255, 220, 120))
    local started, startErr = startRiftDungeon(riftInfo)
    if not started then
        leaveRiftTeam(riftInfo)
        markRiftFailed(riftInfo.showId, riftInfo.startTick)
        setAutoRiftStatus("刷Rift: 进入失败 " .. tostring(startErr), Color3.fromRGB(255, 150, 150))
        return false, startErr
    end

    local enteredArena, enterErr = waitForRiftArenaEntered(riftInfo, AUTO_RIFT.ENTER_TIMEOUT, shouldContinue)
    if enterErr == "all_pets_dead" or areAllEquippedPetsDead() then
        setAutoRiftStatus("刷Rift: 宠物全死，立即退出", Color3.fromRGB(255, 150, 150))
        local left, leftErr = ensureLeaveRiftArena(riftInfo, AUTO_RIFT.EXIT_TIMEOUT, shouldContinue)
        if not left then
            setAutoRiftStatus("刷Rift: 退出失败 " .. tostring(leftErr), Color3.fromRGB(255, 150, 150))
            return false, leftErr
        end
        local recovered, recoverErr = recoverAfterRift(shouldContinue)
        if recovered then
            setAutoRiftStatus("刷Rift: 已退出，恢复完成", Color3.fromRGB(0, 255, 136))
            return true
        end
        return false, recoverErr or "all_pets_dead"
    end
    if not enteredArena then
        markRiftFailed(riftInfo.showId, riftInfo.startTick)
        ensureLeaveRiftArena(nil, 3, shouldContinue)
        setAutoRiftStatus("刷Rift: 未确认进入场景 " .. tostring(enterErr), Color3.fromRGB(255, 150, 150))
        return false, enterErr
    end

    local cleared, battleErr = runRiftArenaBattle(shouldContinue)
    setAutoRiftStatus("刷Rift: 退出裂缝", Color3.fromRGB(255, 220, 120))
    local left, leftErr = ensureLeaveRiftArena(riftInfo, AUTO_RIFT.EXIT_TIMEOUT, shouldContinue)
    if not left then
        setAutoRiftStatus("刷Rift: 退出失败 " .. tostring(leftErr), Color3.fromRGB(255, 150, 150))
        return false, leftErr
    end

    local recovered, recoverErr = recoverAfterRift(shouldContinue)
    if not recovered then
        setAutoRiftStatus("刷Rift: 恢复未完成 " .. tostring(recoverErr), Color3.fromRGB(255, 150, 150))
        return false, recoverErr
    end

    if not cleared then
        if battleErr == "all_pets_dead" then
            setAutoRiftStatus("刷Rift: 已退出，恢复完成", Color3.fromRGB(0, 255, 136))
            return true
        end
        return false, battleErr
    end
    setAutoRiftStatus("刷Rift: 本轮完成", Color3.fromRGB(0, 255, 136))
    return true
end
end

-- 查找Undine - 使用更可靠的方式
local function FindUndine()
    -- 等待PathTool
    if not PathTool then
        WaitForPathTool(10)
    end
    if not PathTool then
        return nil
    end

    -- 尝试多种方式获取怪物管理器
    local monsterMgr = nil

    -- 方式1: MgrMonsterClient (最常见)
    if PathTool.MgrMonsterClient then
        monsterMgr = PathTool.MgrMonsterClient
    -- 方式2: MgrMonster (备选)
    elseif PathTool.MgrMonster then
        monsterMgr = PathTool.MgrMonster
    -- 方式3: 遍历PathTool的表找IterMonster方法
    else
        for k, v in pairs(PathTool) do
            if type(v) == "table" and v.IterMonster then
                monsterMgr = v
                break
            end
        end
    end

    if not monsterMgr then
        return nil
    end

    local foundUndine = nil
    local success, err = pcall(function()
        monsterMgr.IterMonster(function(m)
            if not m then return true end

            -- 获取模板ID (支持多种属性名)
            local tmplId = m.TmplId or m.TemplateId or m.id or m.monsterId
            if tmplId and tmplId == UNDINE_TMPL_ID then
                -- 检查是否存活
                local isAlive = true
                if m.IsAlive then
                    isAlive = pcall(function() return m:IsAlive() end) and m:IsAlive()
                elseif m.isAlive ~= nil then
                    isAlive = m.isAlive
                elseif m.HP and m.HP > 0 then
                    isAlive = true
                end

                if isAlive then
                    foundUndine = m
                    return false -- 停止遍历
                end
            end
            return true -- 继续遍历
        end)
    end)

    if not success then
        warn("[MonsterTracker] FindUndine error:", err)
    end

    -- 调试输出Undine属性
    if DEBUG_UNDINE and foundUndine then
        print("=== Undine Found ===")
        print("TemplateId:", foundUndine.TmplId or foundUndine.TemplateId or foundUndine.id)
        print("Position:", foundUndine.Position or (foundUndine.CurrentCFrame and foundUndine.CurrentCFrame.Position))
        print("HP:", foundUndine.HP or "unknown")
        print("IsAlive:", foundUndine.IsAlive and pcall(function() return foundUndine:IsAlive() end) or "unknown")
        -- 打印所有属性
        for k, v in pairs(foundUndine) do
            if type(v) ~= "function" then
                print("  ", k, ":", type(v) == "userdata" and "(userdata)" or tostring(v))
            end
        end
    end

    return foundUndine
end

-- 清理指引
local function ClearUndineGuide()
    -- 清理距离标签
    if undineGuideLabel then
        undineGuideLabel:Destroy()
        undineGuideLabel = nil
    end

    -- 清理Beam线条
    if undineGuideLine then
        if undineGuideLine.beam then
            undineGuideLine.beam:Destroy()
        end
        if undineGuideLine.att0 then
            undineGuideLine.att0:Destroy()
        end
        if undineGuideLine.att1 then
            undineGuideLine.att1:Destroy()
        end
        if undineGuideLine.part then
            undineGuideLine.part:Destroy()
        end
        undineGuideLine = nil
    end

    -- 清理残留的多个Part版本（向后兼容）
    pcall(function()
        for i = 1, 20 do
            local part = workspace:FindFirstChild("UndineGuidePart" .. i)
            if part then part:Destroy() end
        end
    end)
end

-- 创建指引线条
local function CreateUndineGuide(undinePosition, playerPosition)
    local camera = workspace.CurrentCamera
    if not camera then return end

    local character = player.Character
    if not character then return end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end

    -- 计算距离
    local direction = (undinePosition - playerPosition)
    local distance = direction.Magnitude

    -- 创建距离标签
    local distanceGui = Instance.new("BillboardGui")
    distanceGui.Name = "UndineGuideDistance"
    distanceGui.Size = UDim2.new(0, 150, 0, 30)
    distanceGui.StudsOffset = Vector3.new(0, 3, 0)
    distanceGui.AlwaysOnTop = true
    distanceGui.Adornee = humanoidRootPart
    distanceGui.Parent = humanoidRootPart

    local distanceLabel = Instance.new("TextLabel")
    distanceLabel.Size = UDim2.new(1, 0, 1, 0)
    distanceLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
    distanceLabel.BackgroundTransparency = 0.5
    distanceLabel.BorderSizePixel = 0
    distanceLabel.Text = string.format("Undine: %.1f studs", distance)
    distanceLabel.TextColor3 = Color3.fromRGB(0, 255, 136)
    distanceLabel.Font = Enum.Font.GothamBold
    distanceLabel.TextSize = 14
    distanceLabel.Parent = distanceGui

    local distanceCorner = Instance.new("UICorner")
    distanceCorner.CornerRadius = UDim.new(0, 6)
    distanceCorner.Parent = distanceLabel

    undineGuideLabel = distanceGui

    -- 创建指引线条（使用Beam）
    local guidePart = Instance.new("Part")
    guidePart.Name = "UndineGuidePart"
    guidePart.Anchored = true
    guidePart.CanCollide = false
    guidePart.Transparency = 1
    guidePart.Size = Vector3.new(1, 1, 1)
    guidePart.Position = undinePosition
    guidePart.Parent = workspace

    -- 创建Attachment（玩家端）
    local attachment0 = Instance.new("Attachment")
    attachment0.Name = "UndineGuideAtt0"
    attachment0.Parent = humanoidRootPart

    -- 创建Attachment（Undine端）
    local attachment1 = Instance.new("Attachment")
    attachment1.Name = "UndineGuideAtt1"
    attachment1.Parent = guidePart

    -- 创建Beam
    local beam = Instance.new("Beam")
    beam.Name = "UndineGuideBeam"
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
    beam.Color = ColorSequence.new(Color3.fromRGB(0, 255, 136))
    beam.Transparency = NumberSequence.new(0.3)
    beam.Width0 = 0.15
    beam.Width1 = 0.15
    beam.FaceCamera = true
    beam.Parent = humanoidRootPart

    undineGuideLine = {beam = beam, part = guidePart, att0 = attachment0, att1 = attachment1}
end

-- 更新Undine指引
local function UpdateUndineGuide()
    if not undineGuideEnabled then
        ClearUndineGuide()
        if guideStatusLabel then
            guideStatusLabel.Text = "状态: 已关闭"
            guideStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        return
    end

    local character = player.Character
    if not character then
        ClearUndineGuide()
        if guideStatusLabel then
            guideStatusLabel.Text = "状态: 无角色"
            guideStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        return
    end

    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        ClearUndineGuide()
        if guideStatusLabel then
            guideStatusLabel.Text = "状态: 无角色"
            guideStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        return
    end

    -- 查找Undine
    local undine = FindUndine()
    if not undine then
        ClearUndineGuide()
        if guideStatusLabel then
            guideStatusLabel.Text = "状态: 未找到Undine"
            guideStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
        end
        return
    end

    -- 尝试获取undine位置
    local undinePosition = nil
    pcall(function()
        -- 尝试多种方式获取位置
        if undine.CurrentCFrame then
            undinePosition = undine.CurrentCFrame.Position
        elseif undine.Position then
            undinePosition = undine.Position
        elseif undine.CFrame then
            undinePosition = undine.CFrame.Position
        elseif undine.root and undine.root.Position then
            undinePosition = undine.root.Position
        end
    end)

    if not undinePosition then
        ClearUndineGuide()
        if guideStatusLabel then
            guideStatusLabel.Text = "状态: 无法获取位置"
            guideStatusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
        end
        return
    end

    local playerPosition = humanoidRootPart.Position
    local distance = (undinePosition - playerPosition).Magnitude

    -- 更新状态标签
    if guideStatusLabel then
        guideStatusLabel.Text = string.format("状态: 已找到 (%.1f studs)", distance)
        guideStatusLabel.TextColor3 = Color3.fromRGB(0, 255, 136)
    end

    -- 如果指引不存在，创建新的
    if not undineGuideLabel or not undineGuideLine then
        pcall(function()
            CreateUndineGuide(undinePosition, playerPosition)
        end)
    else
        -- 更新指引
        pcall(function()
            -- 更新距离标签
            if undineGuideLabel then
                local label = undineGuideLabel:FindFirstChildOfClass("TextLabel")
                if label then
                    label.Text = string.format("Undine: %.1f studs", distance)
                end
            end

            -- 更新Beam线条位置
            if undineGuideLine and undineGuideLine.part then
                undineGuideLine.part.Position = undinePosition
            end
        end)
    end
end

-- UI
screenGui = Instance.new("ScreenGui")
screenGui.Name = "MonsterTracker_WebUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    screenGui.IgnoreGuiInset = false
end)
screenGui.Parent = guiParent

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 360, 0, 360)
frame.Position = UDim2.new(0, 12, 0, 12)
frame.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -140, 0, 24)
title.Position = UDim2.new(0, 8, 0, 6)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(0, 255, 136)
title.Text = "Monster Tracker (Web/API)"
title.TextTruncate = Enum.TextTruncate.AtEnd
title.Parent = frame
makeDraggable(frame, title)

status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -12, 0, 18)
status.Position = UDim2.new(0, 8, 0, 30)
status.BackgroundTransparency = 1
status.TextXAlignment = Enum.TextXAlignment.Left
status.Font = Enum.Font.Gotham
status.TextSize = 12
status.TextColor3 = Color3.fromRGB(180, 180, 180)
status.Text = "状态：初始化..."
status.TextTruncate = Enum.TextTruncate.AtEnd
status.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 44, 0, 22)
closeBtn.Position = UDim2.new(1, -52, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.Text = "X"
closeBtn.BorderSizePixel = 0
closeBtn.Parent = frame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = closeBtn

local isCollapsed = false
local collapseBtn = Instance.new("TextButton")
collapseBtn.Size = UDim2.new(0, 44, 0, 22)
collapseBtn.Position = UDim2.new(1, -100, 0, 6)
collapseBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
collapseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
collapseBtn.Font = Enum.Font.GothamBold
collapseBtn.TextSize = 12
collapseBtn.Text = "-"
collapseBtn.BorderSizePixel = 0
collapseBtn.Parent = frame

local collapseCorner = Instance.new("UICorner")
collapseCorner.CornerRadius = UDim.new(0, 6)
collapseCorner.Parent = collapseBtn

local keyBtn = Instance.new("TextButton")
keyBtn.Size = UDim2.new(0, 58, 0, 22)
keyBtn.Position = UDim2.new(1, -116, 0, 6)
keyBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
keyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
keyBtn.Font = Enum.Font.GothamBold
keyBtn.TextSize = 12
keyBtn.Text = "卡密"
keyBtn.BorderSizePixel = 0
keyBtn.Parent = frame

local keyCorner = Instance.new("UICorner")
keyCorner.CornerRadius = UDim.new(0, 6)
keyCorner.Parent = keyBtn

keyBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        local currentKey = cardKey or readSavedCardKey() or ""
        local newKey = promptForCardKey("请输入新的卡密。保存后只对当前 Roblox 用户生效。", currentKey)
        if not newKey then
            return
        end
        cardKey = newKey
        saveCardKey(cardKey)
        loggedIn = false
        sessionCookie = nil
        sessionCreatedAt = 0
        if fetchAndUpdate then
            fetchAndUpdate()
        end
    end)
end)

-- Undine指引开关按钮
local guideBtn = Instance.new("TextButton")
guideBtn.Size = UDim2.new(0, 100, 0, 24)
guideBtn.Position = UDim2.new(0, 12, 0, 52)
guideBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 136) -- 默认开启，绿色
guideBtn.TextColor3 = Color3.fromRGB(0, 0, 0)
guideBtn.Font = Enum.Font.GothamBold
guideBtn.TextSize = 11
guideBtn.Text = "Undine指引: ON" -- 默认开启
guideBtn.BorderSizePixel = 0
guideBtn.Parent = frame

local guideCorner = Instance.new("UICorner")
guideCorner.CornerRadius = UDim.new(0, 6)
guideCorner.Parent = guideBtn

guideBtn.MouseButton1Click:Connect(function()
    undineGuideEnabled = not undineGuideEnabled
    guideBtn.Text = "Undine指引: " .. (undineGuideEnabled and "ON" or "OFF")
    guideBtn.BackgroundColor3 = undineGuideEnabled and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(60, 60, 75)
    guideBtn.TextColor3 = undineGuideEnabled and Color3.fromRGB(0, 0, 0) or Color3.fromRGB(255, 255, 255)
    if not undineGuideEnabled then
        ClearUndineGuide()
    end
end)

-- Undine状态标签
guideStatusLabel = Instance.new("TextLabel")
guideStatusLabel.Size = UDim2.new(0, 120, 0, 18)
guideStatusLabel.Position = UDim2.new(0, 120, 0, 54)
guideStatusLabel.BackgroundTransparency = 1
guideStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
guideStatusLabel.Font = Enum.Font.Gotham
guideStatusLabel.TextSize = 10
guideStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
guideStatusLabel.Text = "状态: 等待PathTool..."
guideStatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
guideStatusLabel.Parent = frame

bossFarmToggleBtn = Instance.new("TextButton")
bossFarmToggleBtn.Size = UDim2.new(0, 112, 0, 24)
bossFarmToggleBtn.Position = UDim2.new(0, 12, 0, 80)
bossFarmToggleBtn.Font = Enum.Font.GothamBold
bossFarmToggleBtn.TextSize = 11
bossFarmToggleBtn.BorderSizePixel = 0
bossFarmToggleBtn.Parent = frame

local bossToggleCorner = Instance.new("UICorner")
bossToggleCorner.CornerRadius = UDim.new(0, 6)
bossToggleCorner.Parent = bossFarmToggleBtn

bossDropdownBtn = Instance.new("TextButton")
bossDropdownBtn.Size = UDim2.new(1, -24, 0, 24)
bossDropdownBtn.Position = UDim2.new(0, 12, 0, 112)
bossDropdownBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
bossDropdownBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
bossDropdownBtn.Font = Enum.Font.GothamBold
bossDropdownBtn.TextSize = 11
bossDropdownBtn.BorderSizePixel = 0
bossDropdownBtn.Parent = frame

local bossDropdownCorner = Instance.new("UICorner")
bossDropdownCorner.CornerRadius = UDim.new(0, 6)
bossDropdownCorner.Parent = bossDropdownBtn

bossFarmStatusLabel = Instance.new("TextLabel")
bossFarmStatusLabel.Size = UDim2.new(1, -24, 0, 18)
bossFarmStatusLabel.Position = UDim2.new(0, 12, 0, 138)
bossFarmStatusLabel.BackgroundTransparency = 1
bossFarmStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
bossFarmStatusLabel.Font = Enum.Font.Gotham
bossFarmStatusLabel.TextSize = 10
bossFarmStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
bossFarmStatusLabel.Text = "刷Boss: 待机"
bossFarmStatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
bossFarmStatusLabel.Parent = frame

autoRiftToggleBtn = Instance.new("TextButton")
autoRiftToggleBtn.Size = UDim2.new(0, 112, 0, 24)
autoRiftToggleBtn.Position = UDim2.new(0, 12, 0, 158)
autoRiftToggleBtn.Font = Enum.Font.GothamBold
autoRiftToggleBtn.TextSize = 11
autoRiftToggleBtn.BorderSizePixel = 0
autoRiftToggleBtn.Parent = frame

local autoRiftToggleCorner = Instance.new("UICorner")
autoRiftToggleCorner.CornerRadius = UDim.new(0, 6)
autoRiftToggleCorner.Parent = autoRiftToggleBtn

autoRiftStatusLabel = Instance.new("TextLabel")
autoRiftStatusLabel.Size = UDim2.new(1, -148, 0, 18)
autoRiftStatusLabel.Position = UDim2.new(0, 132, 0, 161)
autoRiftStatusLabel.BackgroundTransparency = 1
autoRiftStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
autoRiftStatusLabel.Font = Enum.Font.Gotham
autoRiftStatusLabel.TextSize = 10
autoRiftStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
autoRiftStatusLabel.Text = "刷Rift: 待机"
autoRiftStatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
autoRiftStatusLabel.Parent = frame

activeAttackToggleBtn = Instance.new("TextButton")
activeAttackToggleBtn.Size = UDim2.new(0, 112, 0, 24)
activeAttackToggleBtn.Position = UDim2.new(0, 12, 0, 184)
activeAttackToggleBtn.Font = Enum.Font.GothamBold
activeAttackToggleBtn.TextSize = 11
activeAttackToggleBtn.BorderSizePixel = 0
activeAttackToggleBtn.Parent = frame

local activeAttackToggleCorner = Instance.new("UICorner")
activeAttackToggleCorner.CornerRadius = UDim.new(0, 6)
activeAttackToggleCorner.Parent = activeAttackToggleBtn

activeAttackStatusLabel = Instance.new("TextLabel")
activeAttackStatusLabel.Size = UDim2.new(1, -148, 0, 18)
activeAttackStatusLabel.Position = UDim2.new(0, 132, 0, 187)
activeAttackStatusLabel.BackgroundTransparency = 1
activeAttackStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
activeAttackStatusLabel.Font = Enum.Font.Gotham
activeAttackStatusLabel.TextSize = 10
activeAttackStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
activeAttackStatusLabel.Text = "主动打怪: 待机"
activeAttackStatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
activeAttackStatusLabel.Parent = frame

AUTO_ABYSS.toggleBtn = Instance.new("TextButton")
AUTO_ABYSS.toggleBtn.Size = UDim2.new(0, 112, 0, 24)
AUTO_ABYSS.toggleBtn.Position = UDim2.new(0, 12, 0, 210)
AUTO_ABYSS.toggleBtn.Font = Enum.Font.GothamBold
AUTO_ABYSS.toggleBtn.TextSize = 11
AUTO_ABYSS.toggleBtn.BorderSizePixel = 0
AUTO_ABYSS.toggleBtn.Parent = frame

do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = AUTO_ABYSS.toggleBtn
end

AUTO_ABYSS.statusLabel = Instance.new("TextLabel")
AUTO_ABYSS.statusLabel.Size = UDim2.new(1, -222, 0, 18)
AUTO_ABYSS.statusLabel.Position = UDim2.new(0, 132, 0, 213)
AUTO_ABYSS.statusLabel.BackgroundTransparency = 1
AUTO_ABYSS.statusLabel.TextXAlignment = Enum.TextXAlignment.Left
AUTO_ABYSS.statusLabel.Font = Enum.Font.Gotham
AUTO_ABYSS.statusLabel.TextSize = 10
AUTO_ABYSS.statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
AUTO_ABYSS.statusLabel.Text = "自动Abyss: 待机"
AUTO_ABYSS.statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
AUTO_ABYSS.statusLabel.Parent = frame

AUTO_ABYSS.lootBtn = Instance.new("TextButton")
AUTO_ABYSS.lootBtn.Size = UDim2.new(0, 66, 0, 24)
AUTO_ABYSS.lootBtn.Position = UDim2.new(1, -78, 0, 210)
AUTO_ABYSS.lootBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
AUTO_ABYSS.lootBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AUTO_ABYSS.lootBtn.Font = Enum.Font.GothamBold
AUTO_ABYSS.lootBtn.TextSize = 11
AUTO_ABYSS.lootBtn.Text = "战利品"
AUTO_ABYSS.lootBtn.BorderSizePixel = 0
AUTO_ABYSS.lootBtn.Parent = frame

do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = AUTO_ABYSS.lootBtn
end

AUTO_ABYSS.difficultyBtn = Instance.new("TextButton")
AUTO_ABYSS.difficultyBtn.Size = UDim2.new(0.5, -16, 0, 24)
AUTO_ABYSS.difficultyBtn.Position = UDim2.new(0, 12, 0, 236)
AUTO_ABYSS.difficultyBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
AUTO_ABYSS.difficultyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AUTO_ABYSS.difficultyBtn.Font = Enum.Font.GothamBold
AUTO_ABYSS.difficultyBtn.TextSize = 11
AUTO_ABYSS.difficultyBtn.BorderSizePixel = 0
AUTO_ABYSS.difficultyBtn.Parent = frame

do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = AUTO_ABYSS.difficultyBtn
end

AUTO_ABYSS.playerBtn = Instance.new("TextButton")
AUTO_ABYSS.playerBtn.Size = UDim2.new(0.5, -16, 0, 24)
AUTO_ABYSS.playerBtn.Position = UDim2.new(0.5, 4, 0, 236)
AUTO_ABYSS.playerBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
AUTO_ABYSS.playerBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AUTO_ABYSS.playerBtn.Font = Enum.Font.GothamBold
AUTO_ABYSS.playerBtn.TextSize = 11
AUTO_ABYSS.playerBtn.BorderSizePixel = 0
AUTO_ABYSS.playerBtn.Parent = frame

do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = AUTO_ABYSS.playerBtn
end

AUTO_ABYSS.difficultyFrame = Instance.new("ScrollingFrame")
AUTO_ABYSS.difficultyFrame.Size = UDim2.new(0.5, -16, 0, #AUTO_ABYSS.options * 24 + 8)
AUTO_ABYSS.difficultyFrame.Position = UDim2.new(0, 12, 0, 262)
AUTO_ABYSS.difficultyFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
AUTO_ABYSS.difficultyFrame.BorderSizePixel = 0
AUTO_ABYSS.difficultyFrame.ScrollBarThickness = 4
AUTO_ABYSS.difficultyFrame.CanvasSize = UDim2.new(0, 0, 0, #AUTO_ABYSS.options * 24 + 8)
AUTO_ABYSS.difficultyFrame.ScrollingDirection = Enum.ScrollingDirection.Y
AUTO_ABYSS.difficultyFrame.ClipsDescendants = true
AUTO_ABYSS.difficultyFrame.Active = true
AUTO_ABYSS.difficultyFrame.Visible = false
AUTO_ABYSS.difficultyFrame.ZIndex = 22
AUTO_ABYSS.difficultyFrame.Parent = frame

AUTO_ABYSS.playerFrame = Instance.new("ScrollingFrame")
AUTO_ABYSS.playerFrame.Size = UDim2.new(0.5, -16, 0, #AUTO_ABYSS.playerCounts * 24 + 8)
AUTO_ABYSS.playerFrame.Position = UDim2.new(0.5, 4, 0, 262)
AUTO_ABYSS.playerFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
AUTO_ABYSS.playerFrame.BorderSizePixel = 0
AUTO_ABYSS.playerFrame.ScrollBarThickness = 4
AUTO_ABYSS.playerFrame.CanvasSize = UDim2.new(0, 0, 0, #AUTO_ABYSS.playerCounts * 24 + 8)
AUTO_ABYSS.playerFrame.ScrollingDirection = Enum.ScrollingDirection.Y
AUTO_ABYSS.playerFrame.ClipsDescendants = true
AUTO_ABYSS.playerFrame.Active = true
AUTO_ABYSS.playerFrame.Visible = false
AUTO_ABYSS.playerFrame.ZIndex = 22
AUTO_ABYSS.playerFrame.Parent = frame

for _, dropdownFrame in ipairs({ AUTO_ABYSS.difficultyFrame, AUTO_ABYSS.playerFrame }) do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = dropdownFrame
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 4)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.Parent = dropdownFrame
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = dropdownFrame
end

for index, option in ipairs(AUTO_ABYSS.options) do
    local optionBtn = Instance.new("TextButton")
    optionBtn.Size = UDim2.new(1, 0, 0, 22)
    optionBtn.LayoutOrder = index
    optionBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    optionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    optionBtn.Font = Enum.Font.Gotham
    optionBtn.TextSize = 11
    optionBtn.TextXAlignment = Enum.TextXAlignment.Left
    optionBtn.Text = string.format("  %s (%s)", option.label, tostring(option.tmplId))
    optionBtn.BorderSizePixel = 0
    optionBtn.ZIndex = 23
    optionBtn.Parent = AUTO_ABYSS.difficultyFrame
    local optionCorner = Instance.new("UICorner")
    optionCorner.CornerRadius = UDim.new(0, 5)
    optionCorner.Parent = optionBtn
    optionBtn.MouseButton1Click:Connect(function()
        if not AUTO_ABYSS.isTmplUnlocked(option.tmplId) then
            AUTO_ABYSS.difficultyFrame.Visible = false
            AUTO_ABYSS.setStatus("自动Abyss: Hard需要先通关Normal", Color3.fromRGB(255, 220, 120))
            return
        end
        AUTO_ABYSS.selectedTmplId = option.tmplId
        AUTO_ABYSS.difficultyFrame.Visible = false
        AUTO_ABYSS.updateControls()
        saveTrackerSettings()
        AUTO_ABYSS.setStatus("自动Abyss: 已选择 " .. AUTO_ABYSS.getDifficultyText(), Color3.fromRGB(180, 180, 180))
    end)
end

for index, amount in ipairs(AUTO_ABYSS.playerCounts) do
    local optionBtn = Instance.new("TextButton")
    optionBtn.Size = UDim2.new(1, 0, 0, 22)
    optionBtn.LayoutOrder = index
    optionBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    optionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    optionBtn.Font = Enum.Font.Gotham
    optionBtn.TextSize = 11
    optionBtn.TextXAlignment = Enum.TextXAlignment.Left
    optionBtn.Text = "  " .. tostring(amount) .. " 人"
    optionBtn.BorderSizePixel = 0
    optionBtn.ZIndex = 23
    optionBtn.Parent = AUTO_ABYSS.playerFrame
    local optionCorner = Instance.new("UICorner")
    optionCorner.CornerRadius = UDim.new(0, 5)
    optionCorner.Parent = optionBtn
    optionBtn.MouseButton1Click:Connect(function()
        AUTO_ABYSS.selectedPlayers = amount
        AUTO_ABYSS.playerFrame.Visible = false
        AUTO_ABYSS.updateControls()
        saveTrackerSettings()
        AUTO_ABYSS.setStatus("自动Abyss: 已选择 " .. AUTO_ABYSS.getPlayerText(), Color3.fromRGB(180, 180, 180))
    end)
end

AUTO_ABYSS.lootFrame = Instance.new("Frame")
AUTO_ABYSS.lootFrame.Size = UDim2.new(0, 300, 0, 340)
AUTO_ABYSS.lootFrame.Position = UDim2.new(0, 420, 0, 72)
AUTO_ABYSS.lootFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
AUTO_ABYSS.lootFrame.BorderSizePixel = 0
AUTO_ABYSS.lootFrame.Visible = false
AUTO_ABYSS.lootFrame.ZIndex = 40
AUTO_ABYSS.lootFrame.Parent = screenGui

do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = AUTO_ABYSS.lootFrame
end

do
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(75, 75, 92)
    stroke.Thickness = 1
    stroke.Transparency = 0.25
    stroke.Parent = AUTO_ABYSS.lootFrame
end

local lootTitle = Instance.new("TextLabel")
lootTitle.Size = UDim2.new(1, -20, 0, 24)
lootTitle.Position = UDim2.new(0, 10, 0, 8)
lootTitle.BackgroundTransparency = 1
lootTitle.Text = "Abyss战利品统计"
lootTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
lootTitle.TextXAlignment = Enum.TextXAlignment.Left
lootTitle.Font = Enum.Font.GothamBold
lootTitle.TextSize = 14
lootTitle.ZIndex = 41
lootTitle.Parent = AUTO_ABYSS.lootFrame

AUTO_ABYSS.lootSummaryLabel = Instance.new("TextLabel")
AUTO_ABYSS.lootSummaryLabel.Size = UDim2.new(1, -20, 0, 48)
AUTO_ABYSS.lootSummaryLabel.Position = UDim2.new(0, 10, 0, 38)
AUTO_ABYSS.lootSummaryLabel.BackgroundTransparency = 1
AUTO_ABYSS.lootSummaryLabel.Text = ""
AUTO_ABYSS.lootSummaryLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
AUTO_ABYSS.lootSummaryLabel.TextWrapped = true
AUTO_ABYSS.lootSummaryLabel.TextXAlignment = Enum.TextXAlignment.Left
AUTO_ABYSS.lootSummaryLabel.TextYAlignment = Enum.TextYAlignment.Top
AUTO_ABYSS.lootSummaryLabel.Font = Enum.Font.Gotham
AUTO_ABYSS.lootSummaryLabel.TextSize = 11
AUTO_ABYSS.lootSummaryLabel.ZIndex = 41
AUTO_ABYSS.lootSummaryLabel.Parent = AUTO_ABYSS.lootFrame

AUTO_ABYSS.lootListFrame = Instance.new("ScrollingFrame")
AUTO_ABYSS.lootListFrame.Size = UDim2.new(1, -20, 1, -98)
AUTO_ABYSS.lootListFrame.Position = UDim2.new(0, 10, 0, 86)
AUTO_ABYSS.lootListFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
AUTO_ABYSS.lootListFrame.BorderSizePixel = 0
AUTO_ABYSS.lootListFrame.ScrollBarThickness = 6
AUTO_ABYSS.lootListFrame.CanvasSize = UDim2.new(0, 0, 0, 30)
AUTO_ABYSS.lootListFrame.ScrollingDirection = Enum.ScrollingDirection.Y
AUTO_ABYSS.lootListFrame.ClipsDescendants = true
AUTO_ABYSS.lootListFrame.Active = true
AUTO_ABYSS.lootListFrame.ZIndex = 41
AUTO_ABYSS.lootListFrame.Parent = AUTO_ABYSS.lootFrame

do
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = AUTO_ABYSS.lootListFrame
    local padding = Instance.new("UIPadding")
    padding.PaddingTop = UDim.new(0, 4)
    padding.PaddingBottom = UDim.new(0, 4)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.Parent = AUTO_ABYSS.lootListFrame
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = AUTO_ABYSS.lootListFrame
end

AUTO_ABYSS.refreshLootPanel()

bossDropdownFrame = Instance.new("ScrollingFrame")
bossDropdownFrame.Size = UDim2.new(1, -24, 0, #BOSS_OPTIONS * 24 + 8)
bossDropdownFrame.Position = UDim2.new(0, 12, 0, 138)
bossDropdownFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
bossDropdownFrame.BorderSizePixel = 0
bossDropdownFrame.ScrollBarThickness = 4
bossDropdownFrame.CanvasSize = UDim2.new(0, 0, 0, #BOSS_OPTIONS * 24 + 8)
bossDropdownFrame.ScrollingDirection = Enum.ScrollingDirection.Y
bossDropdownFrame.ClipsDescendants = true
bossDropdownFrame.Active = true
bossDropdownFrame.Visible = false
bossDropdownFrame.ZIndex = 20
bossDropdownFrame.Parent = frame

local bossDropdownFrameCorner = Instance.new("UICorner")
bossDropdownFrameCorner.CornerRadius = UDim.new(0, 6)
bossDropdownFrameCorner.Parent = bossDropdownFrame

local bossDropdownPadding = Instance.new("UIPadding")
bossDropdownPadding.PaddingTop = UDim.new(0, 4)
bossDropdownPadding.PaddingBottom = UDim.new(0, 4)
bossDropdownPadding.PaddingLeft = UDim.new(0, 4)
bossDropdownPadding.PaddingRight = UDim.new(0, 4)
bossDropdownPadding.Parent = bossDropdownFrame

local bossDropdownLayout = Instance.new("UIListLayout")
bossDropdownLayout.Padding = UDim.new(0, 2)
bossDropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
bossDropdownLayout.Parent = bossDropdownFrame

for index, option in ipairs(BOSS_OPTIONS) do
    local optionBtn = Instance.new("TextButton")
    optionBtn.Size = UDim2.new(1, 0, 0, 22)
    optionBtn.LayoutOrder = index
    optionBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 58)
    optionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    optionBtn.Font = Enum.Font.Gotham
    optionBtn.TextSize = 11
    optionBtn.TextXAlignment = Enum.TextXAlignment.Left
    optionBtn.Text = string.format("  %s (%s)", option.label, tostring(option.id))
    optionBtn.BorderSizePixel = 0
    optionBtn.ZIndex = 21
    optionBtn.Parent = bossDropdownFrame

    local optionCorner = Instance.new("UICorner")
    optionCorner.CornerRadius = UDim.new(0, 5)
    optionCorner.Parent = optionBtn

    optionBtn.MouseButton1Click:Connect(function()
        selectedBossId = option.id
        bossFarmTrackingBoss = false
        bossFarmDetectStartedAt = nil
        bossFarmVisitedJobs = {}
        bossDropdownFrame.Visible = false
        updateBossFarmControls()
        saveTrackerSettings()
        setBossFarmStatus("刷Boss: 已选择 " .. getSelectedBossText(), Color3.fromRGB(180, 180, 180))
    end)
end

bossDropdownBtn.MouseButton1Click:Connect(function()
    if isCollapsed then
        bossDropdownFrame.Visible = false
        return
    end
    AUTO_ABYSS.difficultyFrame.Visible = false
    AUTO_ABYSS.playerFrame.Visible = false
    bossDropdownFrame.Visible = not bossDropdownFrame.Visible
end)

bossFarmToggleBtn.MouseButton1Click:Connect(function()
    bossFarmEnabled = not bossFarmEnabled
    bossFarmDetectStartedAt = nil
    bossFarmTrackingBoss = false
    bossFarmLastSwitchAttempt = 0
    bossFarmVisitedJobs = {}
    updateBossFarmControls()
    saveTrackerSettings()
    setBossFarmStatus(bossFarmEnabled and "刷Boss: 已开启" or "刷Boss: 已关闭", bossFarmEnabled and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(180, 180, 180))
end)

autoRiftToggleBtn.MouseButton1Click:Connect(function()
    autoRiftEnabled = not autoRiftEnabled
    updateAutoRiftControls()
    saveTrackerSettings()
    setAutoRiftStatus(autoRiftEnabled and "刷Rift: 已开启" or "刷Rift: 已关闭", autoRiftEnabled and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(180, 180, 180))
end)

activeAttackToggleBtn.MouseButton1Click:Connect(function()
    activeAttackEnabled = not activeAttackEnabled
    activeAttackTargetId = nil
    updateActiveAttackControls()
    saveTrackerSettings()
    setActiveAttackStatus(activeAttackEnabled and "主动打怪: 已开启" or "主动打怪: 已关闭", activeAttackEnabled and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(180, 180, 180))
end)

AUTO_ABYSS.toggleBtn.MouseButton1Click:Connect(function()
    AUTO_ABYSS.enabled = not AUTO_ABYSS.enabled
    AUTO_ABYSS.updateControls()
    saveTrackerSettings()
    AUTO_ABYSS.setStatus(AUTO_ABYSS.enabled and "自动Abyss: 已开启" or "自动Abyss: 已关闭", AUTO_ABYSS.enabled and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(180, 180, 180))
end)

AUTO_ABYSS.lootBtn.MouseButton1Click:Connect(function()
    local willShow = not (AUTO_ABYSS.lootFrame and AUTO_ABYSS.lootFrame.Visible)
    if AUTO_ABYSS.lootFrame then
        AUTO_ABYSS.lootFrame.Visible = willShow
    end
    AUTO_ABYSS.lootBtn.Text = willShow and "隐藏战利品" or "战利品"
    AUTO_ABYSS.refreshLootPanel()
end)

AUTO_ABYSS.difficultyBtn.MouseButton1Click:Connect(function()
    if isCollapsed then
        AUTO_ABYSS.difficultyFrame.Visible = false
        return
    end
    bossDropdownFrame.Visible = false
    AUTO_ABYSS.playerFrame.Visible = false
    AUTO_ABYSS.difficultyFrame.Visible = not AUTO_ABYSS.difficultyFrame.Visible
end)

AUTO_ABYSS.playerBtn.MouseButton1Click:Connect(function()
    if isCollapsed then
        AUTO_ABYSS.playerFrame.Visible = false
        return
    end
    bossDropdownFrame.Visible = false
    AUTO_ABYSS.difficultyFrame.Visible = false
    AUTO_ABYSS.playerFrame.Visible = not AUTO_ABYSS.playerFrame.Visible
end)

updateBossFarmControls()
updateAutoRiftControls()
AUTO_ABYSS.updateControls()
updateActiveAttackControls()

-- 启动时等待PathTool
task.spawn(function()
    local pathToolReady = WaitForPathTool(30)
    if not pathToolReady then
        guideStatusLabel.Text = "错误: PathTool超时"
        guideStatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    else
        guideStatusLabel.Text = "状态: PathTool就绪"
        guideStatusLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
        task.wait(2)
        -- 准备好后再开始正常检测
        guideStatusLabel.Text = "状态: 检测中..."
    end
end)

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -16, 1, -280)
list.Position = UDim2.new(0, 8, 0, 270)
list.BackgroundColor3 = Color3.fromRGB(28, 28, 38)
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.Parent = frame

local listCorner = Instance.new("UICorner")
listCorner.CornerRadius = UDim.new(0, 8)
listCorner.Parent = list

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.PaddingLeft = UDim.new(0, 8)
padding.PaddingRight = UDim.new(0, 8)
padding.Parent = list

local isCompactLayout = false

local function applyResponsiveLayout()
    local viewportSize = getViewportSize()
    local viewportWidth = math.max(260, viewportSize.X)
    local viewportHeight = math.max(260, viewportSize.Y)
    local margin = viewportWidth <= 340 and 8 or 12
    local availableWidth = math.max(240, viewportWidth - margin * 2)
    local availableHeight = math.max(240, viewportHeight - margin * 2)
    local frameWidth = math.floor(math.min(360, availableWidth))
    local expandedHeight = math.floor(math.min(520, availableHeight))
    local frameHeight = isCollapsed and 56 or expandedHeight

    isCompactLayout = frameWidth <= 340 or (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled)
    frame.Size = UDim2.new(0, frameWidth, 0, frameHeight)

    local maxX = math.max(margin, viewportWidth - frameWidth - margin)
    local maxY = math.max(margin, viewportHeight - frameHeight - margin)
    local frameX = clampNumber(frame.Position.X.Offset, margin, maxX)
    local frameY = clampNumber(frame.Position.Y.Offset, margin, maxY)
    frame.Position = UDim2.new(0, frameX, 0, frameY)

    if AUTO_ABYSS.lootFrame then
        local lootWidth = math.min(300, math.max(240, viewportWidth - margin * 2))
        local lootHeight = math.min(340, math.max(220, viewportHeight - margin * 2))
        AUTO_ABYSS.lootFrame.Size = UDim2.new(0, lootWidth, 0, lootHeight)
        local lootX = frameX + frameWidth + 12
        if lootX + lootWidth > viewportWidth - margin then
            lootX = math.max(margin, frameX - lootWidth - 12)
        end
        local lootY = clampNumber(frameY, margin, math.max(margin, viewportHeight - lootHeight - margin))
        AUTO_ABYSS.lootFrame.Position = UDim2.new(0, lootX, 0, lootY)
        if AUTO_ABYSS.lootSummaryLabel then
            AUTO_ABYSS.lootSummaryLabel.Size = UDim2.new(1, -20, 0, 48)
        end
        if AUTO_ABYSS.lootListFrame then
            AUTO_ABYSS.lootListFrame.Size = UDim2.new(1, -20, 1, -98)
        end
    end

    local closeWidth = isCompactLayout and 38 or 44
    local collapseWidth = isCompactLayout and 38 or 44
    local keyWidth = isCompactLayout and 50 or 58
    closeBtn.Size = UDim2.new(0, closeWidth, 0, 22)
    closeBtn.Position = UDim2.new(1, -(closeWidth + 8), 0, 6)
    collapseBtn.Size = UDim2.new(0, collapseWidth, 0, 22)
    collapseBtn.Position = UDim2.new(1, -(closeWidth + collapseWidth + 14), 0, 6)
    keyBtn.Size = UDim2.new(0, keyWidth, 0, 22)
    keyBtn.Position = UDim2.new(1, -(closeWidth + collapseWidth + keyWidth + 20), 0, 6)
    title.Size = UDim2.new(1, -(closeWidth + collapseWidth + keyWidth + 34), 0, 24)
    collapseBtn.Text = isCollapsed and "+" or "-"

    status.Size = UDim2.new(1, -16, 0, 18)
    guideBtn.Size = UDim2.new(0, isCompactLayout and 96 or 100, 0, 24)
    guideStatusLabel.Position = UDim2.new(0, isCompactLayout and 114 or 120, 0, 54)
    guideStatusLabel.Size = UDim2.new(1, -(isCompactLayout and 126 or 132), 0, 18)
    bossFarmToggleBtn.Size = UDim2.new(0, isCompactLayout and 104 or 112, 0, 24)
    autoRiftToggleBtn.Size = UDim2.new(0, isCompactLayout and 104 or 112, 0, 24)
    autoRiftStatusLabel.Position = UDim2.new(0, isCompactLayout and 124 or 132, 0, 161)
    autoRiftStatusLabel.Size = UDim2.new(1, -(isCompactLayout and 136 or 148), 0, 18)
    activeAttackToggleBtn.Size = UDim2.new(0, isCompactLayout and 104 or 112, 0, 24)
    activeAttackStatusLabel.Position = UDim2.new(0, isCompactLayout and 124 or 132, 0, 187)
    activeAttackStatusLabel.Size = UDim2.new(1, -(isCompactLayout and 136 or 148), 0, 18)
    AUTO_ABYSS.toggleBtn.Size = UDim2.new(0, isCompactLayout and 104 or 112, 0, 24)
    AUTO_ABYSS.statusLabel.Position = UDim2.new(0, isCompactLayout and 124 or 132, 0, 213)
    AUTO_ABYSS.statusLabel.Size = UDim2.new(1, -(isCompactLayout and 214 or 222), 0, 18)
    AUTO_ABYSS.lootBtn.Size = UDim2.new(0, isCompactLayout and 82 or 90, 0, 24)
    AUTO_ABYSS.lootBtn.Position = UDim2.new(1, -(isCompactLayout and 94 or 102), 0, 210)
    AUTO_ABYSS.difficultyBtn.Size = UDim2.new(0.5, -16, 0, 24)
    AUTO_ABYSS.difficultyBtn.Position = UDim2.new(0, 12, 0, 236)
    AUTO_ABYSS.playerBtn.Size = UDim2.new(0.5, -16, 0, 24)
    AUTO_ABYSS.playerBtn.Position = UDim2.new(0.5, 4, 0, 236)

    local dropdownFullHeight = #BOSS_OPTIONS * 24 + 8
    local dropdownHeight = math.min(dropdownFullHeight, math.max(96, frameHeight - 146))
    bossDropdownFrame.Size = UDim2.new(1, -24, 0, dropdownHeight)
    bossDropdownFrame.CanvasSize = UDim2.new(0, 0, 0, dropdownFullHeight)
    AUTO_ABYSS.difficultyFrame.Size = UDim2.new(0.5, -16, 0, #AUTO_ABYSS.options * 24 + 8)
    AUTO_ABYSS.difficultyFrame.Position = UDim2.new(0, 12, 0, 262)
    AUTO_ABYSS.difficultyFrame.CanvasSize = UDim2.new(0, 0, 0, #AUTO_ABYSS.options * 24 + 8)
    AUTO_ABYSS.playerFrame.Size = UDim2.new(0.5, -16, 0, #AUTO_ABYSS.playerCounts * 24 + 8)
    AUTO_ABYSS.playerFrame.Position = UDim2.new(0.5, 4, 0, 262)
    AUTO_ABYSS.playerFrame.CanvasSize = UDim2.new(0, 0, 0, #AUTO_ABYSS.playerCounts * 24 + 8)

    list.ScrollBarThickness = isCompactLayout and 4 or 6
    list.Position = UDim2.new(0, 8, 0, 270)
    list.Size = UDim2.new(1, -16, 0, math.max(36, frameHeight - 278))

    guideBtn.Visible = not isCollapsed
    guideStatusLabel.Visible = not isCollapsed
    bossFarmToggleBtn.Visible = not isCollapsed
    bossDropdownBtn.Visible = not isCollapsed
    bossFarmStatusLabel.Visible = not isCollapsed
    autoRiftToggleBtn.Visible = not isCollapsed
    autoRiftStatusLabel.Visible = not isCollapsed
    activeAttackToggleBtn.Visible = not isCollapsed
    activeAttackStatusLabel.Visible = not isCollapsed
    AUTO_ABYSS.toggleBtn.Visible = not isCollapsed
    AUTO_ABYSS.statusLabel.Visible = not isCollapsed
    AUTO_ABYSS.lootBtn.Visible = not isCollapsed
    AUTO_ABYSS.difficultyBtn.Visible = not isCollapsed
    AUTO_ABYSS.playerBtn.Visible = not isCollapsed
    list.Visible = not isCollapsed
    if isCollapsed then
        bossDropdownFrame.Visible = false
        AUTO_ABYSS.difficultyFrame.Visible = false
        AUTO_ABYSS.playerFrame.Visible = false
    end
end

local viewportResizeConnection = nil
local currentCameraConnection = nil
local function bindViewportResize()
    if viewportResizeConnection then
        viewportResizeConnection:Disconnect()
        viewportResizeConnection = nil
    end

    local camera = workspace.CurrentCamera
    if camera then
        viewportResizeConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsiveLayout)
    end
end

collapseBtn.MouseButton1Click:Connect(function()
    isCollapsed = not isCollapsed
    if isCollapsed then
        bossDropdownFrame.Visible = false
        AUTO_ABYSS.difficultyFrame.Visible = false
        AUTO_ABYSS.playerFrame.Visible = false
    end
    applyResponsiveLayout()
end)

applyResponsiveLayout()
bindViewportResize()
currentCameraConnection = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    bindViewportResize()
    applyResponsiveLayout()
end)
task.defer(applyResponsiveLayout)

local alive = true
closeBtn.MouseButton1Click:Connect(function()
    alive = false
    if viewportResizeConnection then
        viewportResizeConnection:Disconnect()
        viewportResizeConnection = nil
    end
    if currentCameraConnection then
        currentCameraConnection:Disconnect()
        currentCameraConnection = nil
    end
    ClearUndineGuide()
    screenGui:Destroy()
end)

local function clearList()
    for _, child in ipairs(list:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
end

local function formatRemaining(expireAt)
    expireAt = tonumber(expireAt)
    if not expireAt then return "?" end
    local now = os.time()
    local remain = math.floor((expireAt/1000) - now)
    if remain < 0 then remain = 0 end
    return tostring(remain)
end

local function render(monsters)
    clearList()

    local nowMs = DateTime.now().UnixTimestampMillis
    local valid = {}
    for _, m in ipairs(monsters or {}) do
        local expireAt = tonumber(m.expireAt)
        if expireAt and nowMs < expireAt then
            m.expireAt = expireAt
            table.insert(valid, m)
        end
    end
    table.sort(valid, function(a,b)
        return (tonumber(a.expireAt) or 0) < (tonumber(b.expireAt) or 0)
    end)

    for _, m in ipairs(valid) do
        local actionWidth = isCompactLayout and 58 or 70
        local actionHeight = isCompactLayout and 36 or 40
        local rowHeight = isCompactLayout and 88 or 84
        local textRightPadding = actionWidth + 20

        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, rowHeight)
        row.BackgroundColor3 = Color3.fromRGB(35, 35, 46)
        row.BorderSizePixel = 0
        row.Parent = list

        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 8)
        rc.Parent = row

        local name = Instance.new("TextLabel")
        name.Size = UDim2.new(1, -textRightPadding, 0, 18)
        name.Position = UDim2.new(0, 10, 0, 8)
        name.BackgroundTransparency = 1
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.Font = Enum.Font.GothamBold
        name.TextSize = 12
        name.TextColor3 = Color3.fromRGB(255, 255, 255)
        name.Text = tostring(m.title or "发现 Undine/鹿")
        name.TextTruncate = Enum.TextTruncate.AtEnd
        name.Parent = row

        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, -textRightPadding, 0, 16)
        sub.Position = UDim2.new(0, 10, 0, 28)
        sub.BackgroundTransparency = 1
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.Font = Enum.Font.Gotham
        sub.TextSize = 11
        sub.TextColor3 = Color3.fromRGB(180, 180, 180)
        local pc = tonumber(m.playerCount or m.player_count or 0) or 0
        local remain = formatRemaining(m.expireAt)
        sub.Text = string.format("人数:%s  剩余:%ss", tostring(pc), remain)
        sub.TextTruncate = Enum.TextTruncate.AtEnd
        sub.Parent = row

        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, -textRightPadding, 0, 16)
        info.Position = UDim2.new(0, 10, 0, 46)
        info.BackgroundTransparency = 1
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.Font = Enum.Font.Gotham
        info.TextSize = 11
        info.TextColor3 = Color3.fromRGB(200, 200, 200)
        
        local clickCount = tonumber(m.clickCount or m.click_count or 0) or 0
        local underAttack = m.underAttack == true or m.under_attack == true

        -- 改进的属性处理：支持多种字段名，严格处理null
        local function getSpecialProp(monster)
            -- 优先使用 special 字段（服务器可能发送 null）
            if monster.special ~= nil and monster.special ~= "null" and monster.special ~= "nil" and monster.special ~= "" then
                return tostring(monster.special)
            end
            -- 检查 Special (PascalCase)
            if monster.Special ~= nil and monster.Special ~= "null" and monster.Special ~= "nil" and monster.Special ~= "" then
                return tostring(monster.Special)
            end
            -- 检查 specialLabel
            if monster.specialLabel ~= nil and monster.specialLabel ~= "null" and monster.specialLabel ~= "nil" and monster.specialLabel ~= "" then
                return tostring(monster.specialLabel)
            end
            -- 检查 attribute
            if monster.attribute ~= nil and monster.attribute ~= "null" and monster.attribute ~= "nil" and monster.attribute ~= "" then
                return tostring(monster.attribute)
            end
            return nil
        end

        local special = getSpecialProp(m)
        if not special then
            special = "未知"
        end

        local attackStatus = underAttack and "⚔ 战斗中" or "✓ 空闲"
        local attackColor = underAttack and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(120, 255, 120)

        info.Text = string.format("点击:%s  %s  属性:%s", tostring(clickCount), attackStatus, tostring(special))
        info.TextColor3 = attackColor
        info.TextTruncate = Enum.TextTruncate.AtEnd
        info.Parent = row

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, actionWidth, 0, actionHeight)
        btn.Position = UDim2.new(1, -(actionWidth + 8), 0, isCompactLayout and 24 or 22)
        btn.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
        btn.TextColor3 = Color3.fromRGB(0, 0, 0)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = isCompactLayout and 11 or 12
        btn.Text = "加入"
        btn.BorderSizePixel = 0
        btn.Parent = row

        local bc = Instance.new("UICorner")
        bc.CornerRadius = UDim.new(0, 8)
        bc.Parent = btn

        btn.MouseButton1Click:Connect(function()
            status.Text = "状态：传送中..."
            local ok, err = safeTeleport(m.jobId or m.job_id)
            if not ok then
                status.Text = "状态：传送失败（看控制台）"
                warn("[MonsterTrackerWebUI] Teleport failed:", err)
            end
        end)
    end

    task.wait()
    list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 16)
end

fetchAndUpdate = function()
    local ok, dataOrErr, fetchErr = pcall(fetchRemoteMonsters)

    if ok and dataOrErr and dataOrErr.monsters then
        local count = tonumber(dataOrErr.count or #dataOrErr.monsters) or 0
        local suffix = lastAuthMessage ~= "" and (" | " .. lastAuthMessage) or ""
        setStatusText(string.format("状态：网站在线 | 条目:%d%s", count, suffix), Color3.fromRGB(180, 180, 180))
        render(dataOrErr.monsters)
    else
        local errText = ok and tostring(fetchErr or dataOrErr or "unknown") or tostring(dataOrErr)
        setStatusText("状态：网站获取失败（看控制台）", Color3.fromRGB(255, 150, 150))
        warn("[MonsterTrackerWebUI] fetch failed:", errText)
    end
end

fetchAndUpdate()

task.spawn(function()
    while alive do
        task.wait(REFRESH_INTERVAL)
        if not alive then break end
        fetchAndUpdate()
    end
end)

task.spawn(function()
    while alive do
        task.wait(1)
        if not alive then break end
        if not bossFarmEnabled then
            bossFarmDetectStartedAt = nil
            bossFarmTrackingBoss = false
        else
            local inWindow, remainOrWait, window = getBossWindowInfo()
            if not inWindow then
                bossFarmDetectStartedAt = nil
                bossFarmTrackingBoss = false
                setBossFarmStatus("刷Boss: 等待窗口 " .. formatClockSeconds(remainOrWait), Color3.fromRGB(180, 180, 180))
            else
                local windowKey = getBossWindowKey(window)
                if windowKey and bossFarmServerPoolWindowKey ~= windowKey then
                    ensureBossServerPoolForWindow(windowKey)
                end

                local boss = FindMonsterByTmplId(selectedBossId)
                if boss then
                    bossFarmTrackingBoss = true
                    bossFarmDetectStartedAt = nil
                    setBossFarmStatus("刷Boss: 发现 " .. getSelectedBossText() .. " | 剩余 " .. formatClockSeconds(remainOrWait), Color3.fromRGB(0, 255, 136))
                elseif bossFarmTrackingBoss then
                    bossFarmTrackingBoss = false
                    bossFarmDetectStartedAt = nil
                    local ok, err = tryBossServerSwitch("Boss消失")
                    if not ok then
                        setBossFarmStatus("刷Boss: Boss消失，换服失败 " .. tostring(err), Color3.fromRGB(255, 150, 150))
                    end
                else
                    if not bossFarmDetectStartedAt then
                        bossFarmDetectStartedAt = os.clock()
                    end

                    local detectedFor = os.clock() - bossFarmDetectStartedAt
                    if detectedFor < BOSS_DETECT_SECONDS then
                        setBossFarmStatus(
                            string.format("刷Boss: 检测中 %.0fs/%ds | 窗口剩余 %s", detectedFor, BOSS_DETECT_SECONDS, formatClockSeconds(remainOrWait)),
                            Color3.fromRGB(255, 220, 120)
                        )
                    else
                        local ok, err = tryBossServerSwitch("未发现Boss")
                        if ok then
                            bossFarmDetectStartedAt = os.clock()
                        else
                            setBossFarmStatus("刷Boss: 未发现，换服失败 " .. tostring(err), Color3.fromRGB(255, 150, 150))
                        end
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while alive do
        task.wait(ACTIVE_ATTACK_LOOP_DELAY)
        if not alive then
            break
        end

        if not activeAttackEnabled then
            activeAttackRunning = false
            activeAttackTargetId = nil
            if activeAttackLastStatus ~= "主动打怪: 待机" then
                setActiveAttackStatus("主动打怪: 待机", Color3.fromRGB(180, 180, 180))
            end
        else
            activeAttackRunning = true
            local shouldContinue = function()
                return alive and activeAttackEnabled
            end
            local callOk, result, reason = pcall(function()
                return runActiveAttackOnce(shouldContinue)
            end)
            activeAttackRunning = false

            if not callOk then
                activeAttackTargetId = nil
                setActiveAttackStatus("主动打怪: 错误 " .. tostring(result), Color3.fromRGB(255, 150, 150))
                task.wait(0.5)
            elseif activeAttackEnabled and result == false and reason and reason ~= "no_monster" and reason ~= "character_not_ready" then
                setActiveAttackStatus("主动打怪: 重试 " .. tostring(reason), Color3.fromRGB(255, 150, 150))
                task.wait(0.25)
            end
        end
    end
end)

task.spawn(function()
    while alive do
        task.wait(AUTO_ABYSS.LOOP_DELAY)
        if not alive then
            break
        end

        if not AUTO_ABYSS.enabled then
            AUTO_ABYSS.running = false
            if AUTO_ABYSS.lastStatus ~= "自动Abyss: 待机" then
                AUTO_ABYSS.setStatus("自动Abyss: 待机", Color3.fromRGB(180, 180, 180))
            end
        else
            AUTO_ABYSS.running = true
            local shouldContinue = function()
                return alive and AUTO_ABYSS.enabled
            end
            local callOk, result, reason = pcall(function()
                return runAutoAbyssOnce(shouldContinue)
            end)
            AUTO_ABYSS.running = false

            if not callOk then
                AUTO_ABYSS.log("运行异常", { err = result }, true)
                AUTO_ABYSS.printFailureReason(result, "pcall")
                AUTO_ABYSS.setStatus("自动Abyss: 错误 " .. tostring(result), Color3.fromRGB(255, 150, 150))
                task.wait(2)
            elseif AUTO_ABYSS.enabled and result == false and reason and reason ~= "no_abyss_entry" then
                AUTO_ABYSS.log("本轮返回失败，等待重试", { reason = reason }, true)
                AUTO_ABYSS.setStatus("自动Abyss: 重试 " .. tostring(reason), Color3.fromRGB(255, 150, 150))
                task.wait(AUTO_ABYSS.FAILED_COOLDOWN)
            end
        end
    end
end)

task.spawn(function()
    while alive do
        task.wait(0.5)
        if not alive then
            break
        end

        if not autoRiftEnabled then
            autoRiftRunning = false
            if autoRiftLastStatus ~= "刷Rift: 待机" then
                setAutoRiftStatus("刷Rift: 待机", Color3.fromRGB(180, 180, 180))
            end
        else
            autoRiftRunning = true
            local shouldContinue = function()
                return alive and autoRiftEnabled
            end
            local callOk, result, reason = pcall(function()
                return runAutoRiftOnce(shouldContinue)
            end)
            autoRiftRunning = false

            if not callOk then
                setAutoRiftStatus("刷Rift: 错误 " .. tostring(result), Color3.fromRGB(255, 150, 150))
                task.wait(2)
            elseif autoRiftEnabled and result == false and reason and reason ~= "no_fixed_rift" then
                setAutoRiftStatus("刷Rift: 重试 " .. tostring(reason), Color3.fromRGB(255, 150, 150))
                task.wait(1)
            end
        end
    end
end)

-- Undine指引更新循环
task.spawn(function()
    local lastCharacter = nil
    while alive do
        task.wait(0.1) -- 更频繁的更新指引
        if not alive then break end
        
        -- 检测角色变化
        local currentCharacter = player.Character
        if currentCharacter ~= lastCharacter then
            if lastCharacter then
                -- 角色变化，清理旧指引
                ClearUndineGuide()
            end
            lastCharacter = currentCharacter
        end
        
        if undineGuideEnabled then
            pcall(function()
                UpdateUndineGuide()
            end)
        end
    end
    -- 清理指引
    ClearUndineGuide()
end)
