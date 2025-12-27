-- ============================================
-- 游戏初始化检查（增强版）
-- ============================================
-- 等待游戏完全加载
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- 额外等待确保游戏完全初始化
task.wait(1)

local currentGameId = game.PlaceId
local TARGET_GAME_ID = 18645473062

if currentGameId ~= TARGET_GAME_ID then
    warn('当前游戏不是目标游戏，脚本未运行。')
    return
end

print('检测到目标游戏，正在执行脚本...')

-- ============================================
-- 服务引用（统一管理，避免重复获取）
-- ============================================
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local CoreGui = game:GetService('CoreGui')
local VirtualUser = game:GetService('VirtualUser')

-- ============================================
-- 玩家和GUI引用（增强等待机制）
-- ============================================
-- 等待玩家存在
local player = Players.LocalPlayer
if not player then
    player = Players.PlayerAdded:Wait()
end

-- 等待玩家角色加载（如果存在）
if player.Character then
    player.Character:WaitForChild('HumanoidRootPart', 10)
end

-- 等待PlayerGui存在
local maxWaitTime = 300 -- 最多等待30秒
local startTime = os.clock()
while not player:FindFirstChild('PlayerGui') do
    if os.clock() - startTime > maxWaitTime then
        warn('[初始化] 等待PlayerGui超时，继续执行...')
        break
    end
    task.wait(0.5)
end

local playerGui = player.PlayerGui

-- 等待GUI存在，使用超时机制
local GUI
local success, result = pcall(function()
    GUI = playerGui:WaitForChild('GUI', 10)
end)

if not success or not GUI then
    warn('[初始化] 等待GUI超时，尝试重新等待...')
    -- 再次尝试等待
    task.wait(2)
    GUI = playerGui:WaitForChild('GUI', 20)
end

if not GUI then
    error('[初始化错误] 无法找到GUI，脚本无法继续执行')
    return
end


-- ============================================
-- 工具函数
-- ============================================
-- 深度等待子对象
local function deepWait(parent, path, eachTimeout)
    local obj = parent
    for _, name in ipairs(path) do
        obj = obj and obj:WaitForChild(name, eachTimeout or 5)
        if not obj then
            return nil
        end
    end
    return obj
end

-- 统一的数值解析函数（替代重复的解析逻辑）
local function parseNumber(text, default)
    if not text then return default or 0 end
    
    local str = tostring(text):lower():gsub('%s+', ''):gsub(',', '')
    local numStr = str:gsub('[^%d%.]', '')
    
    -- 检查多个小数点
    local dotCount = select(2, numStr:gsub('%.', ''))
    if dotCount > 1 then
        warn('[数值异常] 非法格式:', text)
        return default or 0
    end
    
    local multiplier = 1
    if str:find('k') then
        multiplier = 1000
    elseif str:find('m') then
        multiplier = 1000000
    end
    
    return (tonumber(numStr) or 0) * multiplier
end

-- 数字格式化函数
local function formatNumber(num)
    if not num then return "N/A" end
    if num >= 1000 then
        return string.format("%.1fK", num / 1000):gsub("%.0K", "K")
    else
        return tostring(math.floor(num))
    end
end

-- ============================================
-- 加载外部脚本（带错误处理）
-- ============================================

local library
local success, err = pcall(function()
    library = loadstring(
        game:HttpGet(
            'https://raw.githubusercontent.com/supleruckydior/test/refs/heads/main/menu.json',
            true
        )
    )()
end)
if not success then
    warn('[初始化错误] 加载library失败:', err)
    return
end

local RespawPoint
success, err = pcall(function()
    RespawPoint = loadstring(
        game:HttpGet(
            'https://raw.githubusercontent.com/Tseting-nil/-Cultivation-Simulator-script/refs/heads/main/%E6%89%8B%E6%A9%9F%E7%AB%AFUI/%E9%85%8D%E7%BD%AE%E4%B8%BB%E5%A0%B4%E6%99%AF.lua'
        )
    )()
end)
if not success then
    warn('[初始化错误] 加载RespawPoint失败:', err)
    return
end

success, err = pcall(function()
    loadstring(
        game:HttpGet(
            'https://github.com/supleruckydior/test/raw/refs/heads/main/respawn.json'
        )
    )()
end)
if not success then
    warn('[初始化警告] 加载respawn.json失败:', err)
end

local JsonHandler
success, err = pcall(function()
    JsonHandler = loadstring(
        game:HttpGet(
            'https://raw.githubusercontent.com/Tseting-nil/-Cultivation-Simulator-script/refs/heads/main/JSON%E6%A8%A1%E7%B5%84.lua'
        )
    )()
end)
if not success then
    warn('[初始化警告] 加载JsonHandler失败:', err)
end


-- ============================================
-- Anti-AFK 设置
-- ============================================
local AntiAFK = VirtualUser
player.Idled:Connect(function()
    AntiAFK:CaptureController()
    AntiAFK:ClickButton2(Vector2.new())
    task.wait(2)
end)

-- ============================================
-- 创建主窗口
-- ============================================
local window = library:AddWindow('Cultivation-Simulator  養成模擬器v1.9', {
    main_color = Color3.fromRGB(41, 74, 122),
    min_size = Vector2.new(530, 315),
    can_resize = false,
})

-- 设置窗口低层级
if window then
    local mainGui = window.gui or window.Instance
    if mainGui then
        mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        local function setLowZIndex(obj)
            if obj:IsA("GuiObject") then
                obj.ZIndex = 10
            end
            for _, child in pairs(obj:GetChildren()) do
                setLowZIndex(child)
            end
        end
        setLowZIndex(mainGui)
    end
end

-- ============================================
-- 创建标签页
-- ============================================
local features1 = window:AddTab('杂项')
local features4 = window:AddTab('炼丹')

-- ============================================
-- 游戏数据初始化（带错误处理）
-- ============================================

local RespawPointnum
if RespawPoint then
    RespawPointnum = RespawPoint:match('%d+')
    if RespawPointnum then
        print('重生點編號：' .. RespawPointnum)
    else
        warn('[初始化警告] 无法获取重生点编号')
    end
else
    warn('[初始化警告] RespawPoint未加载')
end

-- 等待关键对象加载
local reworld
local TPX, TPY, TPZ = 0, 0, 0
if RespawPointnum then
    local success, result = pcall(function()
        reworld = Workspace:WaitForChild('主場景' .. RespawPointnum, 10):WaitForChild('重生点', 10)
        TPX, TPY, TPZ = reworld.Position.X, reworld.Position.Y + 5, reworld.Position.Z
    end)
    if not success then
        warn('[初始化警告] 无法找到重生点，使用默认值')
    end
end

local values
local privileges
local success, result = pcall(function()
    values = player:WaitForChild('值', 15)
    privileges = values:WaitForChild('特权', 10)
end)
if not success then
    warn('[初始化警告] 无法加载玩家值和特权，某些功能可能无法使用')
end


-- ============================================
-- FPS 锁定
-- ============================================
local function PersistentFPSLock()
    local targetFPS = 10
    while true do
        setfpscap(targetFPS)
        task.wait(0.5)
    end
end

task.spawn(PersistentFPSLock)
print("🔒 持续FPS锁定为10（每0.5秒重置）")

-- ============================================
-- 数值获取函数（统一使用 parseNumber）
-- ============================================
local function getHerbValue()
    local herbText = '0'
    pcall(function()
        herbText = game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159\229\143\179']['\232\141\137\232\141\175']['\229\128\188'].Text
    end)
    return parseNumber(herbText, 0)
end

local function getOREValue()
    local OREText = '0'
    pcall(function()
        OREText = game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159\229\143\179']['\231\159\191\231\159\179']['\229\128\188'].Text
    end)
    return parseNumber(OREText, 0)
end

local function getDiamond()
    local diamondText = '0'
    pcall(function()
        diamondText = game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159']['\233\146\187\231\159\179']['\230\140\137\233\146\174']['\229\128\188'].Text
    end)
    return parseNumber(diamondText, 0)
end

local function getGuildCoin()
    local guildCoinText = '0'
    pcall(function()
        guildCoinText = game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154']['\232\131\140\230\153\175']['\229\143\179\228\190\167\231\149\140\233\157\162']['\229\149\134\229\186\151']['\229\133\172\228\188\154\229\184\129']['\230\140\137\233\146\174']['\229\128\188'].Text
    end)
    return parseNumber(guildCoinText, 0)
end

local function getRefreshCost()
    local refreshCostText = '0'
    pcall(function()
        refreshCostText = game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154']['\232\131\140\230\153\175']['\229\143\179\228\190\167\231\149\140\233\157\162']['\229\149\134\229\186\151']['\229\136\183\230\150\176']['\230\140\137\233\146\174']['\229\128\188'].Text
    end)
    return parseNumber(refreshCostText, 0)
end

-- ============================================
-- 数据保存功能（使用Synapse文件系统，TSV格式适合EmEditor）
-- ============================================
-- 数据保存路径（Synapse工作目录）
local DATA_FILE_PATH = "roblox_account_data.tsv"  -- TSV格式，EmEditor可以自动识别为表格
local DATA_SAVE_INTERVAL = 3  -- 保存间隔（秒），3秒

-- 保存数据到本地文件（TSV格式，适合EmEditor）
local function saveDataToLocal()
    pcall(function()
        -- 检查Synapse文件函数是否可用
        if not writefile or not readfile then
            return
        end
        
        local accountName = player.Name
        local herbValue = getHerbValue()
        local oreValue = getOREValue()
        local updateTime = os.date('%Y-%m-%d %H:%M:%S')
        
        -- 读取现有数据
        local accountData = {}  -- 使用字典格式，key为账号名
        local fileExists = pcall(function()
            return readfile(DATA_FILE_PATH)
        end)
        
        if fileExists then
            local fileContent = readfile(DATA_FILE_PATH)
            if fileContent and fileContent ~= "" then
                -- 解析TSV文件
                local lines = {}
                for line in fileContent:gmatch("[^\r\n]+") do
                    table.insert(lines, line)
                end
                
                -- 跳过标题行，读取数据
                for i = 2, #lines do
                    local parts = {}
                    for part in lines[i]:gmatch("[^\t]+") do
                        table.insert(parts, part)
                    end
                    if #parts >= 3 then
                        local acc = parts[1]
                        local herbs = tonumber(parts[2]) or 0
                        local ore = tonumber(parts[3]) or 0
                        local time = parts[4] or ""
                        accountData[acc] = {
                            herbs = herbs,
                            ore = ore,
                            updated_at = time
                        }
                    end
                end
            end
        end
        
        -- 更新或添加当前账号数据
        accountData[accountName] = {
            herbs = herbValue,
            ore = oreValue,
            updated_at = updateTime
        }
        
        -- 构建TSV内容
        local tsvContent = "账号\t草药数量\t矿石数量\t更新时间\n"
        
        -- 按账号名排序（可选）
        local sortedAccounts = {}
        for account, _ in pairs(accountData) do
            table.insert(sortedAccounts, account)
        end
        table.sort(sortedAccounts)
        
        -- 写入数据
        for _, account in ipairs(sortedAccounts) do
            local data = accountData[account]
            tsvContent = tsvContent .. string.format("%s\t%d\t%d\t%s\n", 
                account, 
                data.herbs, 
                data.ore, 
                data.updated_at
            )
        end
        
        -- 保存到文件
        writefile(DATA_FILE_PATH, tsvContent)
    end)
end

-- 数据保存循环（在收菜完成后启动）
local dataSaveStarted = false
local function startDataSaveLoop()
    if dataSaveStarted then
        return
    end
    dataSaveStarted = true
    
    task.spawn(function()
        while true do
            saveDataToLocal()
            task.wait(DATA_SAVE_INTERVAL)
        end
    end)
end

-- ============================================
-- 通知系统
-- ============================================
local function showTopRightNotice(text, lifetime)
    local imgui = CoreGui:FindFirstChild("imgui")
    
    -- 保存原始可见状态
    local originalVisibility = {}
    if imgui then
        for _, window in pairs(imgui:GetChildren()) do
            if window:IsA("GuiObject") then
                originalVisibility[window] = window.Visible
                window.Visible = false
            end
        end
    end
    
    -- 清理旧GUI
    local existingGui = CoreGui:FindFirstChild('FarmNoticeGui')
    if existingGui then
        existingGui:Destroy()
    end
    
    -- 创建新GUI
    local gui = Instance.new('ScreenGui')
    gui.Name = 'FarmNoticeGui'
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.DisplayOrder = 99999
    gui.IgnoreGuiInset = true
    gui.Parent = CoreGui

    -- 背景
    local background = Instance.new('Frame')
    background.Name = 'Background'
    background.Size = UDim2.new(1, 0, 1, 0)
    background.Position = UDim2.new(0, 0, 0, 0)
    background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    background.BackgroundTransparency = 0.5
    background.BorderSizePixel = 0
    background.ZIndex = 99999
    background.Parent = gui

    -- 容器
    local container = Instance.new('Frame')
    container.Name = 'Container'
    container.Size = UDim2.new(0.4, 0, 0.4, 0)
    container.Position = UDim2.new(0.3, 0, 0.3, 0)
    container.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    container.BorderSizePixel = 2
    container.BorderColor3 = Color3.fromRGB(255, 0, 0)
    container.ZIndex = 100000
    container.Parent = gui

    -- 标题
    local title = Instance.new('TextLabel')
    title.Name = 'Title'
    title.Size = UDim2.new(1, 0, 0.3, 0)
    title.Position = UDim2.new(0, 0, 0.1, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 0, 0)
    title.TextScaled = true
    title.Text = text or "收菜完成！"
    title.Font = Enum.Font.SourceSansBold
    title.ZIndex = 100001
    title.TextStrokeTransparency = 0.3
    title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    title.Parent = container

    -- 草药数量显示
    local herbLabel = Instance.new('TextLabel')
    herbLabel.Name = 'HerbLabel'
    herbLabel.Size = UDim2.new(1, 0, 0.2, 0)
    herbLabel.Position = UDim2.new(0, 0, 0.4, 0)
    herbLabel.BackgroundTransparency = 1
    herbLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    herbLabel.TextScaled = true
    herbLabel.Font = Enum.Font.SourceSansBold
    herbLabel.ZIndex = 100001
    herbLabel.TextStrokeTransparency = 0.3
    herbLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    herbLabel.Text = "获取中..."
    herbLabel.Parent = container

    -- 更新草药数量
    local isFinished = false
    local function updateHerbCount()
        if isFinished then return end
        local success, currentHerbs = pcall(getHerbValue)
        currentHerbs = success and currentHerbs or 0
        
        if currentHerbs < 5000 then
            isFinished = true
            herbLabel.Text = "炼药完成！！！"
            herbLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        else
            herbLabel.Text = "当前草药: " .. formatNumber(currentHerbs)
            herbLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        end
    end

    -- 更新循环
    local updating = true
    task.spawn(function()
        while updating and gui and gui.Parent do
            updateHerbCount()
            task.wait(1)
        end
    end)

    -- 按钮容器
    local buttonContainer = Instance.new('Frame')
    buttonContainer.Name = 'ButtonContainer'
    buttonContainer.Size = UDim2.new(0.8, 0, 0.2, 0)
    buttonContainer.Position = UDim2.new(0.1, 0, 0.7, 0)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.ZIndex = 100001
    buttonContainer.Parent = container

    -- 关闭按钮
    local closeButton = Instance.new('TextButton')
    closeButton.Name = 'CloseButton'
    closeButton.Size = UDim2.new(1, 0, 1, 0)
    closeButton.Position = UDim2.new(0, 0, 0, 0)
    closeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    closeButton.BorderSizePixel = 1
    closeButton.BorderColor3 = Color3.fromRGB(100, 100, 100)
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Text = "关闭"
    closeButton.TextScaled = true
    closeButton.ZIndex = 100002
    closeButton.Parent = buttonContainer

    -- 关闭逻辑
    local function removeGUI()
        updating = false
        if imgui then
            for window, visible in pairs(originalVisibility) do
                if window and window.Parent and window:IsA("GuiObject") then
                    window.Visible = visible
                end
            end
        end
        if gui then
            gui:Destroy()
        end
    end

    closeButton.MouseButton1Click:Connect(removeGUI)

    if lifetime and lifetime > 0 then
        task.delay(lifetime, removeGUI)
    end

    updateHerbCount()
end

-- ============================================
-- 任务完成状态管理
-- ============================================
local donationFinished = false
local herbBuyFinished = false
local herbCollectFinished = false
local farmReady = false
local hasShownCompletionNotice = false

local function checkAllTasksFinished()
    if donationFinished and herbBuyFinished and herbCollectFinished and farmReady and not hasShownCompletionNotice then
        hasShownCompletionNotice = true
        showTopRightNotice('收菜完成！', 99999)
        print('[系统] 所有任务完成，显示完成通知')
        -- 收菜完成后开始每3秒保存数据
        startDataSaveLoop()
    end
end

-- ============================================
-- 杂项标签页设置
-- ============================================
local function setupFeatures1Tab(features1)
    local timeLabel = features1:AddLabel('距離下自動獲取還有 0 秒')
    local Online_Gift = GUI
        :WaitForChild('\228\186\140\231\186\167\231\149\140\233\157\162')
        :WaitForChild('\232\138\130\230\151\165\230\180\187\229\138\168\229\149\134\229\186\151')
        :WaitForChild('\232\131\140\230\153\175')
        :WaitForChild('\229\143\179\228\190\167\231\149\140\233\157\162')
        :WaitForChild('\229\156\168\231\186\191\229\165\150\229\138\177')
        :WaitForChild('\229\136\151\232\161\168')
    
    local Gife_check = false
    local countdownList = {}
    local hasExecutedToday = false
    local lastExecutedDay = os.date('%d')

    local function convertToSeconds(timeText)
        local minutes, seconds = string.match(timeText, '(%d+):(%d+)')
        if minutes and seconds then
            return (tonumber(minutes) * 60) + tonumber(seconds)
        end
        return nil
    end

    local function GetOnlineGiftCountdown()
        hasExecutedToday = true
        local minTime = math.huge
        for i = 1, 6 do
            local rewardName = string.format('在线奖励%02d', i)
            local rewardFolder = Online_Gift:FindFirstChild(rewardName)
            if rewardFolder then
                local button = rewardFolder:FindFirstChild('按钮')
                local countdown = button and button:FindFirstChild('倒计时')
                if countdown then
                    local countdownText = countdown.Text
                    countdownList[rewardName] = countdownText
                    if string.match(countdownText, 'DONE') then
                        minTime = math.min(minTime, 0)
                    elseif string.match(countdownText, '%d+:%d+') then
                        local totalSeconds = convertToSeconds(countdownText)
                        if totalSeconds then
                            minTime = math.min(minTime, totalSeconds)
                        end
                    end
                end
            end
        end
        return (minTime < math.huge) and minTime or nil
    end

    local minCountdown = GetOnlineGiftCountdown()
    local nowminCountdown = minCountdown

    local function Online_Gift_start()
        local newMinCountdown = GetOnlineGiftCountdown()
        if newMinCountdown and (newMinCountdown == minCountdown) then
            nowminCountdown = nowminCountdown - 1
        else
            minCountdown = newMinCountdown
            nowminCountdown = minCountdown
        end
        
        if nowminCountdown and (nowminCountdown > 0) then
            timeLabel.Text = string.format('距離下自動獲取還有 %d 秒', nowminCountdown)
        elseif nowminCountdown and (nowminCountdown <= 0) then
            timeLabel.Text = '倒計時結束，準備獲取獎勳'
            local event = ReplicatedStorage
                :FindFirstChild('\228\186\139\228\187\182')
                :FindFirstChild('\229\133\172\231\148\168')
                :FindFirstChild('\232\138\130\230\151\165\230\180\187\229\138\168')
                :FindFirstChild('\233\162\134\229\143\150\229\165\150\229\138\177')
            
            for i = 1, 6 do
                event:FireServer(i)
            end
        else
            timeLabel.Text = '已全部領取'
            Gife_check = false
        end
    end

    local function Online_Gift_check()
        while Gife_check do
            Online_Gift_start()
            task.wait(1)
        end
    end

    local function ClaimOnlineRewards()
        Gife_check = true
        task.spawn(Online_Gift_check)
    end

    features1:AddButton('自動領取在線獎勳', ClaimOnlineRewards)
    task.defer(ClaimOnlineRewards)

    local function CheckAllRewardsCompleted()
        local allCompleted = true
        GetOnlineGiftCountdown()
        for i = 1, 6 do
            local rewardName = string.format('在线奖励%02d', i)
            local status = countdownList[rewardName]
            if not status or not string.match(status, 'DONE') then
                allCompleted = false
                break
            end
        end
        if allCompleted then
            print('所有在線獎勳已完成！')
            Gife_check = false
        end
    end

    task.spawn(function()
        while Gife_check and not hasExecutedToday do
            CheckAllRewardsCompleted()
            task.wait(60)
        end
    end)

    task.spawn(function()
        while true do
            local currentUTCHour = tonumber(os.date('!*t').hour)
            local currentUTCDate = os.date('!*t').day
            local currentLocalHour = currentUTCHour + 8
            if currentLocalHour >= 24 then
                currentLocalHour = currentLocalHour - 24
            end
            local currentLocalDate = currentUTCDate
            if currentLocalHour == 0 then
                if lastExecutedDay ~= currentLocalDate then
                    hasExecutedToday = false
                    print('UTC+8 00:00，自動領取在線獎勳')
                    Gife_check = true
                    lastExecutedDay = currentLocalDate
                end
            end
            task.wait(60)
        end
    end)

    -- 自动任务领取
    local Autocollmission = features1:AddSwitch(
        '自動任務領取(包括GamePass任務、獎勵)',
        function(bool)
            Autocollmissionbool = bool
            if Autocollmissionbool then
                task.spawn(function()
                    while Autocollmissionbool do
                        mainmissionchack()
                        everydaymission()
                        gamepassmission()
                        gamepassgiftget()
                        potionfull()
                        offlinereward()
                        task.wait(20)
                    end
                end)

                task.spawn(function()
                    while Autocollmissionbool do
                        dailyspin()
                        everydaygem()
                        task.wait(500)
                    end
                end)
            end
        end
    )
    Autocollmission:Set(true)

    -- 自动投资
    local invest = features1:AddSwitch('自動執行投資', function(bool)
        investbool = bool
        if investbool then
            task.spawn(function()
                while investbool do
                    local investEvent = ReplicatedStorage['\228\186\139\228\187\182']['\229\133\172\231\148\168']['\229\149\134\229\186\151']['\233\147\182\232\161\140']['\233\162\134\229\143\150\231\144\134\232\180\162']
                    local upgradeEvent = ReplicatedStorage['\228\186\139\228\187\182']['\229\133\172\231\148\168']['\229\149\134\229\186\151']['\233\147\182\232\161\140']['\232\180\173\228\185\176\231\144\134\232\180\162']
                    
                    for i = 1, 3 do
                        investEvent:FireServer(i)
                    end
                    task.wait(5)
                    for i = 1, 3 do
                        upgradeEvent:FireServer(i)
                    end
                    task.wait(600)
                end
            end)
        end
    end)
    invest:Set(true)

    -- 农田5相关函数
    local function openFarm5()
        pcall(function()
            ReplicatedStorage['\228\186\139\228\187\182']['\229\134\156\231\148\176']['\229\134\156\231\148\176UI']['\229\177\158\230\128\167\229\140\186\229\159\159']:FireServer(5)
        end)
        task.wait(0.5)
    end

    local function readFarm5Number()
        local root = player:WaitForChild('PlayerGui'):WaitForChild('GUI')
        local label = deepWait(root, {
            '\228\186\140\231\186\167\231\149\140\233\157\162',
            '\229\134\156\231\148\176',
            '\232\131\140\230\153\175',
            '\229\177\158\230\128\167\229\140\186\229\159\159',
            '\230\148\182\233\155\134\230\140\137\233\146\174',
            '\230\149\176\233\135\143\229\140\186',
            '\230\149\176\233\135\143',
        }, 5)

        if not label or not label:IsA('TextLabel') then
            return nil
        end
        return tonumber(label.Text) or 0
    end

    local function waitFarm5Below100(maxMinutes)
        local deadline = os.clock() + (maxMinutes or 10) * 60
        while os.clock() < deadline do
            local n = readFarm5Number()
            if n == nil then
                warn('[农田5] 读取数字失败，3秒后重试')
                task.wait(3)
            elseif n < 100 then
                farmReady = true
                print('[农田5] 数值 < 100，标记 farmReady = true')
                checkAllTasksFinished()
                return true
            else
                task.wait(3)
            end
        end
        warn('[农田5] 等待超时（超过上限仍 >=100）')
        return false
    end

    -- 自动采集草药
    local AutoCollectherbs = features1:AddSwitch(
        '自動採草藥',
        function(bool)
            AutoCollectherbsbool = bool
            if AutoCollectherbsbool then
                task.spawn(function()
                    while AutoCollectherbsbool do
                        local collectEvent = ReplicatedStorage['\228\186\139\228\187\182']['\229\133\172\231\148\168']['\229\134\156\231\148\176']['\233\135\135\233\155\134']
                        for i = 1, 6 do
                            collectEvent:FireServer(i, nil)
                            task.wait(0.1)
                        end

                        herbCollectFinished = true
                        print('[系统] 草药收集一轮完成，检查农田 5 状态…')
                        openFarm5()
                        waitFarm5Below100()
                        task.wait(60)
                    end
                end)
            end
        end
    )
    AutoCollectherbs:Set(true)

    -- 解锁自动炼制
    features1:AddLabel(' - - 通行證解鎖')
    local Refining = features1:AddSwitch(
        '解鎖自動煉製',
        function(bool)
            local Refiningbool = bool
            if privileges then
                pcall(function()
                    privileges:WaitForChild('超级炼制', 5).Value = false
                    privileges:WaitForChild('自动炼制', 5).Value = Refiningbool
                end)
            else
                warn('[警告] 特权对象未加载，无法设置自动炼制')
            end
        end
    )
    Refining:Set(true)

    -- 显示所有货币
    local showAll = features1:AddSwitch('顯示所有貨幣', function(bool)
        ShowAllbool = bool
        if ShowAllbool then
            task.spawn(function()
                while ShowAllbool do
                    local currencyUI = GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159\229\143\179']
                    currencyUI['\230\180\187\229\138\168\231\137\169\229\147\129'].Visible = true
                    currencyUI['\231\159\191\231\159\179'].Visible = false
                    currencyUI['\231\172\166\231\159\179\231\178\137\230\156\171'].Visible = true
                    currencyUI['\231\173\137\231\186\167'].Visible = true
                    currencyUI['\231\180\171\233\146\187'].Visible = true
                    currencyUI['\232\141\137\232\141\175'].Visible = false
                    currencyUI['\233\135\145\229\184\129'].Visible = true
                    currencyUI['\233\146\187\231\159\179'].Visible = true
                    task.wait(0.3)
                end
            end)
        end
    end)
    showAll:Set(false)

    -- 删除奖励UI
    local function RemoveRewardUI()
        local rewardUI = playerGui.GUI:WaitForChild('\228\186\140\231\186\167\231\149\140\233\157\162')
        local rewardUINames = {
            '展示奖励界面',
            '离线奖励',
            '版本说明',
            '7日奖励',
        }
        local success = false

        for _, name in ipairs(rewardUINames) do
            local child = rewardUI:FindFirstChild(name)
            if child then
                child:Destroy()
                print('成功删除: ' .. name)
                success = true
            else
                print('未找到: ' .. name)
            end
        end

        return success
    end

    features1:AddButton('刪除顯示獲得的獎勵(所有的)', RemoveRewardUI)
    task.defer(RemoveRewardUI)

    -- 兑换游戏礼品码
    features1:AddButton('兌換遊戲禮品碼', function()
        local gamecode = {
            'ilovethisgame',
            'welcome',
            '30klikes',
            '40klikes',
            'halloween',
            'artistkapouki',
            '45klikes',
            '60klikes',
        }
        local redeemEvent = ReplicatedStorage
            :FindFirstChild('\228\186\139\228\187\182')
            :FindFirstChild('\229\133\172\231\148\168')
            :FindFirstChild('\231\142\169\229\174\182\231\160\129')
            :FindFirstChild('\231\142\169\229\174\182\229\133\145\230\141\162\231\142\169\229\174\182\231\160\129')
        
        for i = 1, #gamecode do
            print(gamecode[i])
            redeemEvent:FireServer(gamecode[i])
        end
    end)
end

setupFeatures1Tab(features1)

-- ============================================
-- 炼丹标签页设置
-- ============================================
-- 炼丹控制器
local elixirController = {
    enabled = false
}

local function elixirLoop()
    while elixirController.enabled do
        local currentHerbs = getHerbValue()
        if currentHerbs < 5000 then
            print('[系统] 草药数量低于5000，停止自动炼丹')
            elixirController.enabled = false
            AutoelixirSwitch:Set(false)
            break
        end
        
        local elixirEvent = ReplicatedStorage
            :FindFirstChild('\228\186\139\228\187\182')
            :FindFirstChild('\229\133\172\231\148\168')
            :FindFirstChild('\231\130\188\228\184\185')
            :FindFirstChild('\229\136\182\228\189\156')
        
        if elixirEvent then
            elixirEvent:FireServer()
        end
        task.wait(0.5)
    end
end

local AutoelixirSwitch = features4:AddSwitch('自動煉丹藥', function(bool)
    elixirController.enabled = bool
    if elixirController.enabled then
        task.spawn(elixirLoop)
    end
end)

task.defer(function()
    task.wait(3)
    if not elixirController.enabled then
        AutoelixirSwitch:Set(true)
        print('[系统] 自动炼丹已启动')
    end
end)

-- 传送炼器
features4:AddButton('传送炼器', function()
    local RespawPointnum = RespawPoint:match('%d+')
    local character = player.Character

    if not character then
        player.CharacterAdded:Wait()
        character = player.Character
    end

    local humanoidRootPart = character:WaitForChild('HumanoidRootPart')
    local forgePath = Workspace['\228\184\187\229\160\180\230\153\175' .. RespawPointnum]['\229\187\186\233\128\160\231\137\169']['035\231\130\188\229\153\168\229\143\176']

    if forgePath then
        humanoidRootPart.CFrame = forgePath:GetPivot()
    end
end)

-- 公会相关
local Guidename = GUI
    :WaitForChild('\228\186\140\231\186\167\231\149\140\233\157\162')
    :WaitForChild('\229\133\172\228\188\154')
    :WaitForChild('背景')
    :WaitForChild('右侧界面')
    :WaitForChild('主页')
    :WaitForChild('介绍')
    :WaitForChild('名称')
    :WaitForChild('文本')
    :WaitForChild('文本').Text

local Donatetimes = GUI
    :WaitForChild('\228\186\140\231\186\167\231\149\140\233\157\162')
    :WaitForChild('\229\133\172\228\188\154')
    :WaitForChild('捐献')
    :WaitForChild('背景')
    :WaitForChild('按钮')
    :WaitForChild('确定按钮')
    :WaitForChild('次数').Text

local Donatetimesnumber = tonumber(string.match(Donatetimes, '%d+'))
local Guildname = features4:AddLabel(
    '公會名稱：未獲取點擊更新公會 剩餘貢獻次數： ' .. Donatetimesnumber
)

features4:AddButton('更新公會', function()
    Donatetimes = GUI
        :WaitForChild('\228\186\140\231\186\167\231\149\140\233\157\162')
        :WaitForChild('\229\133\172\228\188\154')
        :WaitForChild('捐献')
        :WaitForChild('背景')
        :WaitForChild('按钮')
        :WaitForChild('确定按钮')
        :WaitForChild('次数').Text
    Donatetimesnumber = tonumber(string.match(Donatetimes, '%d+'))
    local event = ReplicatedStorage:FindFirstChild('打开公会', true)
    if event then
        event:Fire('打开公会')
    end
    Guildname.Text = '公會名稱：' .. Guidename .. ' 剩餘貢獻次數： ' .. Donatetimesnumber
end)

local DonationUI = GUI:WaitForChild('\228\186\140\231\186\167\231\149\140\233\157\162'):WaitForChild('\229\133\172\228\188\154')
local DonateButton = DonationUI:WaitForChild('捐献')
    :WaitForChild('背景')
    :WaitForChild('按钮')
    :WaitForChild('确定按钮')

local DonationEvent = ReplicatedStorage
    :WaitForChild('\228\186\139\228\187\182')
    :WaitForChild('\229\133\172\231\148\168')
    :WaitForChild('\229\133\172\228\188\154')
    :WaitForChild('\230\141\144\231\140\174')

-- 捐献控制器
local donationController = {
    enabled = false,
    interval = 0.5,
    maxAttempts = 3,
    currentAttempts = 0,
}

local function updateGuildDisplay()
    local counterText = DonateButton:WaitForChild('次数').Text
    local remaining = tonumber(counterText:match('%d+')) or 0
    Guildname.Text = ('公會名稱：%s 剩餘貢獻次數：%d'):format(Guidename, remaining)
    return remaining
end

local function executeDonation()
    pcall(function()
        DonationEvent:FireServer()
    end)
end

local function donationLoop()
    while donationController.enabled do
        local success, remaining = pcall(updateGuildDisplay)

        if success and remaining > 0 then
            executeDonation()
            donationController.currentAttempts = 0
        else
            donationController.currentAttempts += 1
        end

        if donationController.currentAttempts >= donationController.maxAttempts then
            warn('连续失败次数过多，自动停止')
            donationController.enabled = false
        end

        if success and remaining == 0 then
            donationController.enabled = false
            donationFinished = true
            checkAllTasksFinished()
            print('[系统] 公会捐献已完成，准备购买草药')
        end

        task.wait(donationController.interval)
    end
end

local AutoDonateSwitch = features4:AddSwitch('自動捐献', function(isActive)
    donationController.enabled = isActive
    if isActive then
        task.spawn(donationLoop)
    end
end)

task.defer(function()
    task.wait(3)
    if not donationController.enabled then
        AutoDonateSwitch:Set(true)
    end
end)

-- 草药购买控制器
local herbController = {
    enabled = false,
    interval = 0.2,
    maxAttempts = 5,
    currentAttempts = 0,
    highCostMode = false,
}

local function toggleGuildUI(state)
    pcall(function()
            GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154'].Visible = state
    end)
end

local price = 400

local function herbLoop()
    while herbController.enabled do
        if not donationFinished then
            task.wait(1)
        else
            if not herbController.started then
                herbController.started = true
            end

            local money = getDiamond()
            local guilditemlist = GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154']['\232\131\140\230\153\175']['\229\143\179\228\190\167\231\149\140\233\157\162']['\229\149\134\229\186\151']['\229\136\151\232\161\168']


            local function tryBuy(slotIndex)
                local item = guilditemlist:GetChildren()[slotIndex]
                if item and item:FindFirstChild('\230\140\137\233\146\174') then
                    local button = item['\230\140\137\233\146\174']
                    local stockText = button['\229\186\147\229\173\152'].Text
                    local nameText = button['\229\144\141\231\167\176'].Text
                    
                    if stockText == '1 Left' and nameText == 'Herb' then
                        if money >= price then
                            ReplicatedStorage['\228\186\139\228\187\182']['\229\133\172\231\148\168']['\229\133\172\228\188\154']['\229\133\145\230\141\162']:FireServer(slotIndex - 2)
                            money = money - price
                            return true
                        end
                    end
                end
                return false
            end

            for i = 1, 18 do
                if not herbController.enabled then
                    break
                end
                tryBuy(i)
            end

            local refreshCost = getRefreshCost()
            local diamond = getDiamond()
            local guildCoin = getGuildCoin()

            if refreshCost > 7000 then
                if not herbController.highCostMode then
                    print('[系统] 进入高成本模式，结束草药购买任务')
                    herbController.highCostMode = true
                    if not herbBuyFinished then
                        herbBuyFinished = true
                        checkAllTasksFinished()
                    end
                    herbController.enabled = false
                end
                toggleGuildUI(false)
                task.wait(300)
                break
            else
                herbController.highCostMode = false
            end

            if diamond > refreshCost and guildCoin >= 400 and diamond >= 18000 then
                pcall(function()
                    ReplicatedStorage['\228\186\139\228\187\182']['\229\174\162\230\136\183\231\171\175']['\229\174\162\230\136\183\231\171\175UI']['\230\137\147\229\188\128\229\133\172\228\188\154']:Fire()
                    task.wait(0.5)
                    ReplicatedStorage['\228\186\139\228\187\182']['\229\133\172\231\148\168']['\229\133\172\228\188\154']['\229\136\183\230\150\176\229\133\172\228\188\154\229\149\134\229\186\151']:FireServer()
                end)
                task.wait(1.5)
            else
                if not herbBuyFinished then
                    herbBuyFinished = true
                    checkAllTasksFinished()
                end
                herbController.enabled = false
                task.wait(30)
            end
        end
    end
end

local Autoguildshop = features4:AddSwitch('自动购买草药', function(state)
    herbController.enabled = state
    herbController.highCostMode = false
    if state then
        task.spawn(herbLoop)
    end
end)

task.defer(function()
    task.wait(3)
    if not herbController.enabled then
        Autoguildshop:Set(true)
    end
end)

-- 简易丹药摆放
features4:AddButton('简易丹药摆放', function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/supleruckydior/test/refs/heads/main/简易自动交易.lua"))()
end)

-- 交易所有人
features4:AddButton('交易所有人', function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/supleruckydior/test/refs/heads/main/自动交易1.json"))()
end)

-- ============================================
-- 智能监控系统
-- ============================================
local Autoelixir = false
local hasExecutedTrade = false

local function startElixirLoop()
    Autoelixir = true
    while Autoelixir do
        pcall(function()
            local elixirEvent = ReplicatedStorage
                :FindFirstChild('\228\186\139\228\187\182')
                :FindFirstChild('\229\133\172\231\148\168')
                :FindFirstChild('\231\130\188\228\184\185')
                :FindFirstChild('\229\136\182\228\189\156')
            if elixirEvent then
                elixirEvent:FireServer()
            end
        end)
        task.wait(0.2)
    end
end

local herbprint = false
local lowcontrol = false

local function smartMonitor()
    while true do
        local currentHerbs = getHerbValue()
        local playerName = player.Name

        if currentHerbs > 250000 and not hasExecutedTrade then
            herbprint = true
            lowcontrol = true
            hasExecutedTrade = true
            print(playerName .. ' --- 自动交易脚本激活! (' .. currentHerbs .. '草药)')

            if not Autoelixir then
                task.spawn(startElixirLoop)
            end
        elseif currentHerbs < 5000 and lowcontrol then
            Autoelixir = false
            hasExecutedTrade = false
            herbprint = false
            lowcontrol = false
            print(playerName .. ' --- 系统重置! (剩余' .. currentHerbs .. '草药)')
        end
        
        if herbprint and hasExecutedTrade then
            print(playerName .. ' --- ' .. currentHerbs .. '草药')
        end

        task.wait(5)
    end
end

-- 初始化检查
local farm5Level = 0
local elixirLevel = 0

pcall(function()
    farm5Level = tonumber(
        GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\134\156\231\148\176']['\232\131\140\230\153\175']['\229\177\158\230\128\167\229\140\186\229\159\159']['\229\177\158\230\128\167\229\136\151\232\161\168']['\229\136\151\232\161\168']['\231\173\137\231\186\167']['\229\128\188'].Text:match('%d+')
    ) or 0
end)
GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\134\156\231\148\176'].Visible = false

pcall(function()
    local elixirUI = ReplicatedStorage:FindFirstChild('\228\186\139\228\187\182', true):FindFirstChild('\229\174\162\230\136\183\231\171\175', true)
    if elixirUI then
        elixirUI['\229\174\162\230\136\183\231\171\175UI']['\230\137\147\229\188\128\231\130\188\228\184\185\231\130\137']:Fire()
        task.wait(0.5)
        elixirLevel = tonumber(
            GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\231\130\188\228\184\185\231\130\137']['\232\131\140\230\153\175']['\229\177\158\230\128\167\229\136\151\232\161\168']['\229\136\151\232\161\168']['\231\173\137\231\186\167']['\229\128\188'].Text:match('%d+')
        ) or 0
    end
    GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\231\130\188\228\184\185\231\130\137'].Visible = false
end)

if farm5Level >= 80 and elixirLevel >= 80 then
    print('===== 系统启动 =====')
    print('农田5等级:', farm5Level)
    print('炼丹炉等级:', elixirLevel)
    print('初始草药量:', getHerbValue())
    print('==================')
    task.spawn(smartMonitor)
else
    print('条件不满足：需要农田5和炼丹炉等级≥80')
end

-- ============================================
-- 自动出售检查
-- ============================================
local function CheckAndFire()
    local gui = GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\232\135\170\229\138\168\229\135\186\229\148\174\229\188\185\229\135\186\230\161\134']['\232\131\140\230\153\175']['\230\140\137\233\146\174']['\230\147\141\228\189\156\229\140\186\229\159\159']['\229\130\168\229\173\152']['\229\155\190\230\160\135']['\229\155\190\230\160\135']
    
    if gui and gui.Visible == false then
        local remote = ReplicatedStorage
            :WaitForChild('\228\186\139\228\187\182')
            :WaitForChild('\229\133\172\231\148\168')
            :WaitForChild('\231\130\188\228\184\185')
            :WaitForChild('\228\191\174\230\148\185\232\135\170\229\138\168\229\130\168\229\173\152')
        
        if remote then
            remote:FireServer()
            print('RemoteEvent fired successfully!')
        else
            warn('RemoteEvent not found!')
        end
    end
end

CheckAndFire()
