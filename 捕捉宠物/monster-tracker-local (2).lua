-- Monster Tracker - Web UI (Top Left)
-- 数据来源：https://monster.suplucky.cc/api/monsters
-- 流程：弹窗输入卡密 -> 登录获取 session -> 直接轮询网站怪物数据

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local guiParent = game:GetService("CoreGui")

local player = Players.LocalPlayer
local screenGui = nil
local status = nil
local guideStatusLabel = nil
local fetchAndUpdate = nil

-- 运行限制：仅允许指定账号运行
local ALLOWED_PLAYER_NAME = "Savanndavid"
if not player or player.Name ~= ALLOWED_PLAYER_NAME then
    warn(string.format("[MonsterTrackerWebUI] 未授权账号：%s（仅允许 %s 运行）", player and player.Name or "Unknown", ALLOWED_PLAYER_NAME))
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

local cardKey = nil
local sessionCookie = nil
local sessionCreatedAt = 0
local loggedIn = false
local lastAuthMessage = ""

local BOSS_FARM_WINDOWS = {
    { startMinute = 0, endMinute = 5 },
    { startMinute = 15, endMinute = 20 },
    { startMinute = 30, endMinute = 35 },
    { startMinute = 45, endMinute = 50 },
}
local BOSS_DETECT_SECONDS = 10
local BOSS_SERVER_SWITCH_RETRY_INTERVAL = 3
local bossFarmEnabled = false
local selectedBossId = 60006
local bossFarmStatusLabel = nil
local bossFarmToggleBtn = nil
local bossDropdownBtn = nil
local bossDropdownFrame = nil
local bossFarmDetectStartedAt = nil
local bossFarmTrackingBoss = false
local bossFarmLastSwitchAttempt = 0
local bossFarmVisitedJobs = {}

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

    return true
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

    local dialog = Instance.new("Frame")
    dialog.Size = UDim2.new(0, 320, 0, 178)
    dialog.Position = UDim2.new(0, 32, 0, 62)
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
        targetFrame.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
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

local function fetchPublicServerJobId()
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

    local data, decodeErr = decodeJson(res.Body or "")
    if type(data) ~= "table" or type(data.data) ~= "table" then
        return nil, decodeErr or "公共服务器列表为空"
    end

    local candidates = {}
    local fallbackCandidates = {}
    for _, server in ipairs(data.data) do
        local jobId = trim(server.id or "")
        local playing = tonumber(server.playing or 0) or 0
        local maxPlayers = tonumber(server.maxPlayers or 0) or 0
        local hasRoom = maxPlayers <= 0 or playing < maxPlayers
        if jobId ~= "" and jobId ~= game.JobId and hasRoom then
            if not bossFarmVisitedJobs[jobId] then
                table.insert(candidates, jobId)
            else
                table.insert(fallbackCandidates, jobId)
            end
        end
    end

    if #candidates > 0 then
        return candidates[math.random(1, #candidates)], "public-random"
    end

    if #fallbackCandidates > 0 then
        bossFarmVisitedJobs = {}
        return fallbackCandidates[math.random(1, #fallbackCandidates)], "public-random-reset"
    end
    return nil, "没有可用公共服务器"
end

local function tryBossServerSwitch(reason)
    local now = os.clock()
    if now - bossFarmLastSwitchAttempt < BOSS_SERVER_SWITCH_RETRY_INTERVAL then
        return false, "等待换服间隔"
    end
    bossFarmLastSwitchAttempt = now

    local jobId, source = fetchPublicServerJobId()
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
bossFarmStatusLabel.Parent = frame

bossDropdownFrame = Instance.new("Frame")
bossDropdownFrame.Size = UDim2.new(1, -24, 0, #BOSS_OPTIONS * 24 + 8)
bossDropdownFrame.Position = UDim2.new(0, 12, 0, 138)
bossDropdownFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
bossDropdownFrame.BorderSizePixel = 0
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

updateBossFarmControls()

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
list.Size = UDim2.new(1, -16, 1, -168)
list.Position = UDim2.new(0, 8, 0, 158)
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

local alive = true
closeBtn.MouseButton1Click:Connect(function()
    alive = false
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
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 84)
        row.BackgroundColor3 = Color3.fromRGB(35, 35, 46)
        row.BorderSizePixel = 0
        row.Parent = list

        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(0, 8)
        rc.Parent = row

        local name = Instance.new("TextLabel")
        name.Size = UDim2.new(1, -90, 0, 18)
        name.Position = UDim2.new(0, 10, 0, 8)
        name.BackgroundTransparency = 1
        name.TextXAlignment = Enum.TextXAlignment.Left
        name.Font = Enum.Font.GothamBold
        name.TextSize = 12
        name.TextColor3 = Color3.fromRGB(255, 255, 255)
        name.Text = tostring(m.title or "发现 Undine/鹿")
        name.Parent = row

        local sub = Instance.new("TextLabel")
        sub.Size = UDim2.new(1, -90, 0, 16)
        sub.Position = UDim2.new(0, 10, 0, 28)
        sub.BackgroundTransparency = 1
        sub.TextXAlignment = Enum.TextXAlignment.Left
        sub.Font = Enum.Font.Gotham
        sub.TextSize = 11
        sub.TextColor3 = Color3.fromRGB(180, 180, 180)
        local pc = tonumber(m.playerCount or m.player_count or 0) or 0
        local remain = formatRemaining(m.expireAt)
        sub.Text = string.format("人数:%s  剩余:%ss", tostring(pc), remain)
        sub.Parent = row

        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(1, -90, 0, 16)
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
        info.Parent = row

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 70, 0, 40)
        btn.Position = UDim2.new(1, -78, 0, 22)
        btn.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
        btn.TextColor3 = Color3.fromRGB(0, 0, 0)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
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
            local inWindow, remainOrWait = getBossWindowInfo()
            if not inWindow then
                bossFarmDetectStartedAt = nil
                bossFarmTrackingBoss = false
                setBossFarmStatus("刷Boss: 等待窗口 " .. formatClockSeconds(remainOrWait), Color3.fromRGB(180, 180, 180))
            else
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
