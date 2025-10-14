if not game:IsLoaded() then
    game.Loaded:Wait()
end

local currentGameId = game.PlaceId
local TARGET_GAME_ID = 18645473062

if currentGameId == TARGET_GAME_ID then
    print('检测到目标游戏，正在执行脚本...')

    -- Wait for player and player GUI to exist
    local player = game:GetService('Players').LocalPlayer
    while not player:FindFirstChild('PlayerGui') do
        task.wait(1)
    end
    local playerGui = player.PlayerGui

    local library = loadstring(
        game:HttpGet(
            'https://raw.githubusercontent.com/supleruckydior/test/refs/heads/main/menu.json',
            true
        )
    )()
    local RespawPoint = loadstring(
        game:HttpGet(
            'https://raw.githubusercontent.com/Tseting-nil/-Cultivation-Simulator-script/refs/heads/main/%E6%89%8B%E6%A9%9F%E7%AB%AFUI/%E9%85%8D%E7%BD%AE%E4%B8%BB%E5%A0%B4%E6%99%AF.lua'
        )
    )()
    loadstring(
        game:HttpGet(
            'https://github.com/supleruckydior/test/raw/refs/heads/main/respawn.json'
        )
    )()
    local JsonHandler = loadstring(
        game:HttpGet(
            'https://raw.githubusercontent.com/Tseting-nil/-Cultivation-Simulator-script/refs/heads/main/JSON%E6%A8%A1%E7%B5%84.lua'
        )
    )()
    local AntiAFK = game:GetService('VirtualUser')
    game.Players.LocalPlayer.Idled:Connect(function()
        AntiAFK:CaptureController()
        AntiAFK:ClickButton2(Vector2.new())
        wait(2)
    end)
local window = library:AddWindow('Cultivation-Simulator  養成模擬器v1.5', {
    main_color = Color3.fromRGB(41, 74, 122),
    min_size = Vector2.new(530, 315),
    can_resize = false,
})

-- 在创建窗口后立即设置低层级
if window then
    -- 获取主GUI对象并设置低ZIndex
    local mainGui = window.gui or window.Instance
    if mainGui then
        mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        -- 遍历所有子元素设置较低的ZIndex
        local function setLowZIndex(obj)
            if obj:IsA("GuiObject") then
                obj.ZIndex = 10  -- 设置较低的层级
            end
            for _, child in pairs(obj:GetChildren()) do
                setLowZIndex(child)
            end
        end
        setLowZIndex(mainGui)
    end
end
    local features1 = window:AddTab('杂项')
    local features4 = window:AddTab('炼丹')
    local ws = game:GetService('Workspace')
    local Players = game.Players
    local localPlayer = game.Players.LocalPlayer
    local playerGui = player.PlayerGui
    local RespawPointnum = RespawPoint:match('%d+')
    print('重生點編號：' .. RespawPointnum)
    local reworld = ws:waitForChild('主場景' .. RespawPointnum)
        :waitForChild('重生点')
    local TPX, TPY, TPZ =
        reworld.Position.X, reworld.Position.Y + 5, reworld.Position.Z
    local Restart = false
    local finishworldnum
    local values = player:WaitForChild('值')
    local privileges = values:WaitForChild('特权')
    local gowordlevels = 74
    local isDetectionEnabled = true
    local timescheck = 0
    local hasPrintedNoPlayer = false
    local showone = false
    local savemodetime = 0
    local savemodetime2 = 0
    local savemodebutton
    local REPLICATED_STORAGE = game:GetService('ReplicatedStorage')
    local ReplicatedStorage = game:GetService('ReplicatedStorage')
    local Players = game:GetService('Players')
    local player = Players.LocalPlayer
    local GUI = player.PlayerGui:WaitForChild('GUI')
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
    -- 持续监控并重置FPS
local function PersistentFPSLock()
    local targetFPS = 10
    
    while true do
        setfpscap(targetFPS)
        wait(0.5)  -- 每0.5秒重置一次
    end
end

spawn(PersistentFPSLock)
print("🔒 持续FPS锁定为10（每0.5秒重置）")
    -- 右上角提示（简单版）
    local function getHerbValue()
        local herbText = '0'
        pcall(function()
            herbText =
                GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159\229\143\179']['\232\141\137\232\141\175']['\229\128\188'].Text
        end)

        local cleanedHerbText =
            tostring(herbText):lower():gsub('%s+', ''):gsub(',', '')
        if cleanedHerbText:find('k') then
            local numStr = cleanedHerbText:gsub('[^%d%.]', '')
            return (tonumber(numStr) or 0) * 1000
        elseif cleanedHerbText:find('m') then
            local numStr = cleanedHerbText:gsub('[^%d%.]', '')
            return (tonumber(numStr) or 0) * 1000000
        else
            return tonumber(cleanedHerbText) or 0
        end
    end

local function showTopRightNotice(text, lifetime)
    local coreGui = game:GetService("CoreGui")
    local imgui = coreGui:FindFirstChild("imgui")
    
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
    
    -- 创建黑幕（在CoreGui中）
    local existingGui = coreGui:FindFirstChild('FarmNoticeGui')
    if existingGui then
        existingGui:Destroy()
    end
    
    local gui = Instance.new('ScreenGui')
    gui.Name = 'FarmNoticeGui'
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.DisplayOrder = 99999
    gui.IgnoreGuiInset = true
    gui.Parent = coreGui

    -- 创建全屏黑幕背景
    local background = Instance.new('Frame')
    background.Name = 'Background'
    background.Size = UDim2.new(1, 0, 1, 0)
    background.Position = UDim2.new(0, 0, 0, 0)
    background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    background.BackgroundTransparency = 0.5
    background.BorderSizePixel = 0
    background.ZIndex = 99999
    background.Parent = gui

    -- 创建中央容器
    local container = Instance.new('Frame')
    container.Name = 'Container'
    container.Size = UDim2.new(0.4, 0, 0.4, 0)
    container.Position = UDim2.new(0.3, 0, 0.3, 0)
    container.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    container.BorderSizePixel = 2
    container.BorderColor3 = Color3.fromRGB(255, 0, 0)
    container.ZIndex = 100000
    container.Parent = gui

    -- 创建标题文字
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

    -- 创建草药数量显示
    local herbLabel = Instance.new('TextLabel')
    herbLabel.Name = 'HerbLabel'
    herbLabel.Size = UDim2.new(1, 0, 0.2, 0)
    herbLabel.Position = UDim2.new(0, 0, 0.4, 0)
    herbLabel.BackgroundTransparency = 1
    herbLabel.TextColor3 = Color3.fromRGB(255, 255, 0) -- 初始黄色
    herbLabel.TextScaled = true
    herbLabel.Font = Enum.Font.SourceSansBold
    herbLabel.ZIndex = 100001
    herbLabel.TextStrokeTransparency = 0.3
    herbLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    herbLabel.Text = "获取中..."
    herbLabel.Parent = container

    -- 数字格式化函数（只保留K）
    local function formatNumber(num)
        if not num then return "N/A" end
        if num >= 1000 then
            return string.format("%.1fK", num / 1000):gsub("%.0K", "K")
        else
            return tostring(math.floor(num))
        end
    end

    -- 安全获取草药数量
    local function safeGetHerbValue()
        local success, result = pcall(function()
            return getHerbValue()
        end)
        return success and result or 0
    end

    -- 标记是否已进入“炼药完成”状态
    local isFinished = false

    -- 更新草药数量
    local function updateHerbCount()
        if isFinished then return end -- 一旦完成，不再变化
        local currentHerbs = safeGetHerbValue()
        
        if currentHerbs < 5000 then
            isFinished = true
            herbLabel.Text = "炼药完成！！！"
            herbLabel.TextColor3 = Color3.fromRGB(0, 255, 0) -- 绿色
        else
            herbLabel.Text = "当前草药: " .. formatNumber(currentHerbs)
            herbLabel.TextColor3 = Color3.fromRGB(255, 255, 0) -- 黄色
        end
    end

    -- 创建更新循环（每秒更新一次）
    local updating = true
    task.spawn(function()
        while updating and gui and gui.Parent do
            updateHerbCount()
            task.wait(1)
        end
    end)

    -- 创建按钮容器
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

    -- 自动关闭（如果有 lifetime）
    if lifetime and lifetime > 0 then
        task.delay(lifetime, removeGUI)
    end

    -- 初次显示立即更新一次
    updateHerbCount()
end


    local donationFinished = false -- 初始为 false
    local herbBuyFinished = false -- 初始为 false
    local herbCollectFinished = false -- 初始为 false
    local farmReady = false -- 初始为 false
local hasShownCompletionNotice = false  -- 添加这个变量来跟踪是否已经显示过通知

local function checkAllTasksFinished()
    if
        donationFinished
        and herbBuyFinished
        and herbCollectFinished
        and farmReady
        and not hasShownCompletionNotice  -- 添加这个检查
    then
        hasShownCompletionNotice = true  -- 标记为已显示
        showTopRightNotice('收菜完成！', 99999)
        print('[系统] 所有任务完成，显示完成通知')
    end
end
    local function setupFeatures1Tab(features1)
        local timeLabel =
            features1:AddLabel('距離下自動獲取還有 0 秒')
        local playerGui = game.Players.LocalPlayer.PlayerGui
        local Online_Gift = playerGui.GUI
            :WaitForChild('二级界面')
            :WaitForChild('节日活动商店')
            :WaitForChild('背景')
            :WaitForChild('右侧界面')
            :WaitForChild('在线奖励')
            :WaitForChild('列表')
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
                    local countdown = button
                        and button:FindFirstChild('倒计时')
                    if countdown then
                        local countdownText = countdown.Text
                        countdownList[rewardName] = countdownText
                        if string.match(countdownText, 'CLAIMED!') then
                        elseif string.match(countdownText, 'DONE') then
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
            return ((minTime < math.huge) and minTime) or nil
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
                timeLabel.Text = string.format(
                    '距離下自動獲取還有 %d 秒',
                    nowminCountdown
                )
            elseif nowminCountdown and (nowminCountdown <= 0) then
                timeLabel.Text = '倒計時結束，準備獲取獎勳'
                for i = 1, 6 do
                    local args = { [1] = i }
                    game:GetService('ReplicatedStorage')
                        :FindFirstChild('\228\186\139\228\187\182')
                        :FindFirstChild('\229\133\172\231\148\168')
                        :FindFirstChild(
                            '\232\138\130\230\151\165\230\180\187\229\138\168'
                        )
                        :FindFirstChild(
                            '\233\162\134\229\143\150\229\165\150\229\138\177'
                        )
                        :FireServer(unpack(args))
                end
            else
                timeLabel.Text = '已全部領取'
                Gife_check = false
            end
        end
        local function Online_Gift_check()
            while Gife_check do
                Online_Gift_start()
                wait(1)
            end
        end
        local function ClaimOnlineRewards()
            Gife_check = true
            spawn(Online_Gift_check)
        end
        -- 创建按钮时引用函数
        features1:AddButton('自動領取在線獎勳', ClaimOnlineRewards)
        -- 启动时自动执行
        task.defer(function()
            ClaimOnlineRewards()
        end)
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
        spawn(function()
            while Gife_check and not hasExecutedToday do
                CheckAllRewardsCompleted()
                wait(60)
            end
        end)
        spawn(function()
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
                wait(60)
            end
        end)
local Autocollmission = features1:AddSwitch(
    '自動任務領取(包括GamePass任務、獎勵)',
    function(bool)
        Autocollmissionbool = bool
        if Autocollmissionbool then
            -- 主任務循環（每60秒執行一次）
            spawn(function()
                while Autocollmissionbool do
                    mainmissionchack()
                    everydaymission()
                    gamepassmission()
                    gamepassgiftget()
                    potionfull()
                    offlinereward()
                    wait(20)
                end
            end)

            -- dailyspin 獨立循環（每500秒執行一次）
            spawn(function()
                while Autocollmissionbool do
                    dailyspin()
                    everydaygem()
                    wait(500)
                end
            end)
        end
    end
)
        Autocollmission:Set(true)
        local invest = features1:AddSwitch('自動執行投資', function(bool)
            investbool = bool
            if investbool then
                spawn(function()
                    while investbool do
                        for i = 1, 3 do
                            local args = { i }
                            game:GetService('ReplicatedStorage')['\228\186\139\228\187\182']['\229\133\172\231\148\168']['\229\149\134\229\186\151']['\233\147\182\232\161\140']['\233\162\134\229\143\150\231\144\134\232\180\162']
                                :FireServer(unpack(args))
                        end
                        wait(5)
                        for i = 1, 3 do
                            local args = { i }
                            game:GetService('ReplicatedStorage')['\228\186\139\228\187\182']['\229\133\172\231\148\168']['\229\149\134\229\186\151']['\233\147\182\232\161\140']['\232\180\173\228\185\176\231\144\134\232\180\162']
                                :FireServer(unpack(args))
                        end
                        wait(600)
                    end
                end)
            end
        end)
        invest:Set(true)
        local function openFarm5()
            pcall(function()
                game:GetService('ReplicatedStorage')['\228\186\139\228\187\182']['\229\134\156\231\148\176']['\229\134\156\231\148\176UI']['\229\177\158\230\128\167\229\140\186\229\159\159']
                    :FireServer(5)
            end)
            task.wait(0.5) -- 给UI一点时间打开
        end

        -- 读取你指定路径上的数字文本
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
            -- 这里按你的描述就是“一个数字”，直接 tonumber
            return tonumber(label.Text) or 0
        end

        -- 等待直到该数字 < 100；若 >=100 就每3秒再查一次
        local function waitFarm5Below100(maxMinutes)
            local deadline = os.clock() + (maxMinutes or 10) * 60 -- 最多等10分钟（可改）
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
                    -- 未小于100，3秒后再查
                    task.wait(3)
                end
            end
            warn('[农田5] 等待超时（超过上限仍 >=100）')
            return false
        end
        local AutoCollectherbs = features1:AddSwitch(
            '自動採草藥',
            function(bool)
                AutoCollectherbsbool = bool
                if AutoCollectherbsbool then
                    spawn(function()
                        while AutoCollectherbsbool do
                            for i = 1, 6 do
                                local args = { [1] = i, [2] = nil }
                                game:GetService('ReplicatedStorage')['\228\186\139\228\187\182']['\229\133\172\231\148\168']['\229\134\156\231\148\176']['\233\135\135\233\155\134']
                                    :FireServer(unpack(args))
                                wait(0.1)
                            end

                            -- 🌿 一轮收集完成
                            herbCollectFinished = true
                            print(
                                '[系统] 草药收集一轮完成，检查农田 5 状态…'
                            )
                            openFarm5()
                            waitFarm5Below100()

                            wait(60) -- 等下一轮
                        end
                    end)
                end
            end
        )

        AutoCollectherbs:Set(true)
        features1:AddLabel(' - - 通行證解鎖')
        local Refining = features1:AddSwitch(
            '解鎖自動煉製',
            function(bool)
                local Refiningbool = bool
                privileges:WaitForChild('超级炼制').Value = false
                privileges:WaitForChild('自动炼制').Value = Refiningbool
            end
        )
        Refining:Set(true)
        local showAll = features1:AddSwitch('顯示所有貨幣', function(bool)
            ShowAllbool = bool
            if ShowAllbool then
                while ShowAllbool do
                    game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159']['\230\180\187\229\138\168\231\137\169\229\147\129'].Visible =
                        true
                    game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159']['\231\159\191\231\159\179'].Visible =
                        false
                    game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159']['\231\172\166\231\159\179\231\178\137\230\156\171'].Visible =
                        true
                    game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159']['\231\173\137\231\186\167'].Visible =
                        true
                    game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159']['\231\180\171\233\146\187'].Visible =
                        true
                    game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159']['\232\141\137\232\141\175'].Visible =
                        false
                    game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159']['\233\135\145\229\184\129'].Visible =
                        true
                    game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159']['\233\146\187\231\159\179'].Visible =
                        true
                    wait(0.3)
                end
            end
        end)
        showAll:Set(false)
        -- 方案一：函数复用模式（推荐）
        local function RemoveRewardUI()
            local rewardUI = playerGui.GUI:WaitForChild('二级界面')

            -- 定义需要删除的子对象名称
            local rewardUINames = {
                '展示奖励界面',
                '离线奖励',
                '版本说明',
                '7日奖励',
            }
            local success = false

            -- 遍历所有需要删除的子对象
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

            -- 返回是否成功删除了至少一个子对象
            return success
        end

        -- 创建按钮并立即执行
        features1:AddButton('刪除顯示獲得的獎勵(所有的)', function()
            RemoveRewardUI()
        end)

        -- 启动时延迟执行
        task.defer(function()
            RemoveRewardUI()
        end)
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
            for i = 1, #gamecode do
                print(gamecode[i])
                local args = { [1] = gamecode[i] }
                game:GetService('ReplicatedStorage')
                    :FindFirstChild('\228\186\139\228\187\182')
                    :FindFirstChild('\229\133\172\231\148\168')
                    :FindFirstChild('\230\191\128\230\180\187\231\160\129')
                    :FindFirstChild(
                        '\231\142\169\229\174\182\229\133\145\230\141\162\230\191\128\230\180\187\231\160\129'
                    )
                    :FireServer(unpack(args))
            end
        end)
    end
    setupFeatures1Tab(features1)
    -- 获取草药数值

-- 创建炼丹控制器
local elixirController = {
    enabled = false
}

-- 炼丹循环函数
local function elixirLoop()
    while elixirController.enabled do
        -- 检查草药数量
        local currentHerbs = getHerbValue()
        if currentHerbs < 5000 then
            print('[系统] 草药数量低于5000，停止自动炼丹')
            elixirController.enabled = false
            AutoelixirSwitch:Set(false) -- 更新开关状态
            break
        end
        
        -- 执行炼丹
        game:GetService('ReplicatedStorage')
            :FindFirstChild('\228\186\139\228\187\182')
            :FindFirstChild('\229\133\172\231\148\168')
            :FindFirstChild('\231\130\188\228\184\185')
            :FindFirstChild('\229\136\182\228\189\156')
            :FireServer()
        wait(0.5)
    end
end

-- 创建开关
local AutoelixirSwitch = features4:AddSwitch('自動煉丹藥', function(bool)
    elixirController.enabled = bool
    if elixirController.enabled then
        task.spawn(elixirLoop)
    end
end)

-- 安全自启动机制
task.defer(function()
    task.wait(3) -- 等待界面初始化
    if not elixirController.enabled then
        AutoelixirSwitch:Set(true)
        print('[系统] 自动炼丹已启动')
    end
end)
    features4:AddButton('传送炼器', function()
        local RespawPointnum = RespawPoint:match('%d+') -- 获取重生点编号
        local player = game.Players.LocalPlayer
        local character = player.Character

        if not character then
            player.CharacterAdded:Wait()
            character = player.Character
        end

        local humanoidRootPart = character:WaitForChild('HumanoidRootPart')
        local forgePath =
            workspace['\228\184\187\229\160\180\230\153\175' .. RespawPointnum]['\229\187\186\233\128\160\231\137\169']['035\231\130\188\229\153\168\229\143\176']

        if forgePath then
            humanoidRootPart.CFrame = forgePath:GetPivot()
        end
    end)

    local playerGui = game.Players.LocalPlayer.PlayerGui
    local Guidename = playerGui.GUI
        :WaitForChild('二级界面')
        :WaitForChild('公会')
        :WaitForChild('背景')
        :WaitForChild('右侧界面')
        :WaitForChild('主页')
        :WaitForChild('介绍')
        :waitForChild('名称')
        :waitForChild('文本')
        :waitForChild('文本').Text
    local Donatetimes = playerGui.GUI
        :WaitForChild('二级界面')
        :WaitForChild('公会')
        :WaitForChild('捐献')
        :WaitForChild('背景')
        :WaitForChild('按钮')
        :WaitForChild('确定按钮')
        :WaitForChild('次数').Text
    local Donatetimesnumber = tonumber(string.match(Donatetimes, '%d+'))
    local Guildname = features4:AddLabel(
        '公會名稱：未獲取點擊更新公會'
            .. ' 剩餘貢獻次數： '
            .. Donatetimesnumber
    )
    features4:AddButton('更新公會', function()
        Donatetimes = playerGui.GUI
            :WaitForChild('二级界面')
            :WaitForChild('公会')
            :WaitForChild('捐献')
            :WaitForChild('背景')
            :WaitForChild('按钮')
            :WaitForChild('确定按钮')
            :WaitForChild('次数').Text
        Donatetimesnumber = tonumber(string.match(Donatetimes, '%d+'))
        local replicatedStorage = game:GetService('ReplicatedStorage')
        local event = replicatedStorage:FindFirstChild('打开公会', true)
        event:Fire('打开公会')
        Guildname.Text = '公會名稱：'
            .. Guidename
            .. ' 剩餘貢獻次數： '
            .. Donatetimesnumber
    end)
    local DonationUI =
        playerGui.GUI:WaitForChild('二级界面'):WaitForChild('公会')
    local DonateButton = DonationUI:WaitForChild('捐献')
        :WaitForChild('背景')
        :WaitForChild('按钮')
        :WaitForChild('确定按钮')
    local DonationEvent = game:GetService('ReplicatedStorage')
        :WaitForChild('\228\186\139\228\187\182')
        :WaitForChild('\229\133\172\231\148\168')
        :WaitForChild('\229\133\172\228\188\154')
        :WaitForChild('\230\141\144\231\140\174')

    -- 创建独立控制模块
    local donationController = {
        enabled = false,
        interval = 0.5,
        maxAttempts = 3,
        currentAttempts = 0,
    }

    local function updateGuildDisplay()
        local counterText = DonateButton:WaitForChild('次数').Text
        local remaining = tonumber(counterText:match('%d+')) or 0
        Guildname.Text = ('公會名稱：%s 剩餘貢獻次數：%d'):format(
            Guidename,
            remaining
        )
        return remaining
    end

    local function executeDonation()
        pcall(function()
            DonationEvent:FireServer()
        end)
    end

    -- 创建带保护机制的捐献循环
    local function donationLoop()
        while donationController.enabled do
            local success, remaining = pcall(updateGuildDisplay)

            if success and remaining > 0 then
                executeDonation()
                donationController.currentAttempts = 0
            else
                donationController.currentAttempts += 1
            end

            if
                donationController.currentAttempts
                >= donationController.maxAttempts
            then
                warn('连续失败次数过多，自动停止')
                donationController.enabled = false
            end

            -- 如果捐献次数为 0，标记完成
            if success and remaining == 0 then
                donationController.enabled = false
                donationFinished = true
                checkAllTasksFinished()
                print('[系统] 公会捐献已完成，准备购买草药')
            end

            task.wait(donationController.interval)
        end
    end

    -- 初始化开关并设置自动启动
    local AutoDonateSwitch = features4:AddSwitch(
        '自動捐献',
        function(isActive)
            donationController.enabled = isActive
            if isActive then
                task.spawn(donationLoop)
            end
        end
    )

    -- 安全自启动机制
    task.defer(function()
        task.wait(3) -- 等待界面初始化
        if not donationController.enabled then
            AutoDonateSwitch:Set(true)
        end
    end)

    local herbController = {
        enabled = false,
        interval = 0.2,
        maxAttempts = 5,
        currentAttempts = 0,
        highCostMode = false,
    }

    -- 字符串处理辅助函数
    local function countSubstring(str, pattern)
        return select(2, str:gsub(pattern, ''))
    end

    -- 安全数值转换器
    local function parseNumber(text)
        local str = tostring(text):lower():gsub('%s+', ''):gsub(',', '')
        local numStr = str:gsub('[^%d%.]', '')

        if countSubstring(numStr, '%.') > 1 then
            warn('[数值异常] 非法格式:', text)
            return 0
        end

        local multiplier = 1
        if str:find('k') then
            multiplier = 1000
        elseif str:find('m') then
            multiplier = 1000000
        end

        return (tonumber(numStr) or 0) * multiplier
    end

    -- 数值获取函数
    local function getDiamond()
        return parseNumber(
            game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159']['\233\146\187\231\159\179']['\230\140\137\233\146\174']['\229\128\188'].Text
        )
    end

    local function getGuildCoin()
        return parseNumber(
            game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154']['\232\131\140\230\153\175']['\229\143\179\228\190\167\231\149\140\233\157\162']['\229\149\134\229\186\151']['\229\133\172\228\188\154\229\184\129']['\230\140\137\233\146\174']['\229\128\188'].Text
        )
    end

    local function getRefreshCost()
        return parseNumber(
            game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154']['\232\131\140\230\153\175']['\229\143\179\228\190\167\231\149\140\233\157\162']['\229\149\134\229\186\151']['\229\136\183\230\150\176']['\230\140\137\233\146\174']['\229\128\188'].Text
        )
    end

    -- 界面控制函数
    local function toggleGuildUI(state)
        pcall(function()
            game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154'].Visible =
                state
        end)
    end
    local price = 400 -- 固定价格

    -- 购买逻辑主循环

    local function herbLoop()
        while herbController.enabled do
            -- 等待捐献完成
            if not donationFinished then
                task.wait(1)
                continue -- 跳过本轮，直到捐献完成
            end

            -- 第一次开始买草药时提示
            if not herbController.started then
                print('[系统] 开始自动购买草药')
                herbController.started = true
            end

            local boughtAny = false
            local money = getDiamond()
            local guilditemlist =
                game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154']['\232\131\140\230\153\175']['\229\143\179\228\190\167\231\149\140\233\157\162']['\229\149\134\229\186\151']['\229\136\151\232\161\168']

            local function tryBuy(slotIndex)
                local item = guilditemlist:GetChildren()[slotIndex]
                if item and item:FindFirstChild('\230\140\137\233\146\174') then
                    local button = item['\230\140\137\233\146\174']
                    if
                        button['\229\186\147\229\173\152'].Text == '1 Left'
                        and button['\229\144\141\231\167\176'].Text
                            == 'Herb'
                    then
                        if money >= price then
                            game:GetService('ReplicatedStorage')['\228\186\139\228\187\182']['\229\133\172\231\148\168']['\229\133\172\228\188\154']['\229\133\145\230\141\162']
                                :FireServer(slotIndex - 2)
                            money = money - price
                            boughtAny = true
                            return true
                        else
                            warn(
                                '[草药购买] 货币不足，跳过槽位 '
                                    .. slotIndex
                            )
                        end
                    end
                end
                return false
            end

            -- 遍历所有槽位
            for i = 1, 18 do
                if not herbController.enabled then
                    break
                end
                tryBuy(i)
            end

            local refreshCost = getRefreshCost()
            local diamond = getDiamond()
            local guildCoin = getGuildCoin()

            -- 高成本模式
            if refreshCost > 7000 then
                if not herbController.highCostMode then
                    print(
                        '[系统] 进入高成本模式，结束草药购买任务'
                    )
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

            -- 正常刷新
            if
                diamond > refreshCost
                and guildCoin >= 400
                and diamond >= 18000
            then
                pcall(function()
                    game:GetService('ReplicatedStorage')['\228\186\139\228\187\182']['\229\174\162\230\136\183\231\171\175']['\229\174\162\230\136\183\231\171\175UI']['\230\137\147\229\188\128\229\133\172\228\188\154']
                        :Fire()
                    task.wait(0.5)
                    game:GetService('ReplicatedStorage')['\228\186\139\228\187\182']['\229\133\172\231\148\168']['\229\133\172\228\188\154']['\229\136\183\230\150\176\229\133\172\228\188\154\229\149\134\229\186\151']
                        :FireServer()
                end)
                task.wait(1.5)
            else
                print(
                    '[草药购买] 刷新条件不满足，结束购买任务'
                )
                if not herbBuyFinished then
                    herbBuyFinished = true
                    checkAllTasksFinished()
                end
                herbController.enabled = false -- 停止循环
                task.wait(30)
            end
        end -- 关闭 while
    end -- 关闭 function

    -- 界面控件
    local Autoguildshop = features4:AddSwitch(
        '自动购买草药',
        function(state)
            herbController.enabled = state
            herbController.highCostMode = false -- 重置状态
            if state then
                task.spawn(herbLoop)
                print('[系统] 自动购买已启动')
            else
                print('[系统] 自动购买已停止')
            end
        end
    )

    -- 安全自启动机制（添加在自动捐献代码下方）
    task.defer(function()
        task.wait(3) -- 等待界面初始化
        if not herbController.enabled then
            Autoguildshop:Set(true)
        end
    end)
features4:AddButton('简易丹药摆放', function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/supleruckydior/test/refs/heads/main/简易自动交易.lua"))()
end)

-- 交易所有人
features4:AddButton('交易所有人', function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/supleruckydior/test/refs/heads/main/自动交易1.json"))()
end)
    -- 共用事件路径
    local REPLICATED_STORAGE = game:GetService('ReplicatedStorage')
    local ReplicatedStorage = game:GetService('ReplicatedStorage')
    local Players = game:GetService('Players')
    local player = Players.LocalPlayer
    local GUI = player.PlayerGui:WaitForChild('GUI')

    -- 全局控制变量
    local Autoelixir = false
    local hasExecutedTrade = false -- 确保自动交易只执行一次


    local function getOREValue()
        local OREText = '0'
        pcall(function()
            OREText =
                game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159\229\143\179']['\231\159\191\231\159\179']['\229\128\188'].Text
        end)

        local cleanedOREText =
            tostring(OREText):lower():gsub('%s+', ''):gsub(',', '')
        if cleanedOREText:find('k') then
            local numStr = cleanedOREText:gsub('[^%d%.]', '')
            return (tonumber(numStr) or 0) * 1000
        elseif cleanedOREText:find('m') then
            local numStr = cleanedOREText:gsub('[^%d%.]', '')
            return (tonumber(numStr) or 0) * 1000000
        else
            return tonumber(cleanedOREText) or 0
        end
    end

    -- 炼丹循环
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
            wait(0.2)
        end
    end

    -- 智能监控
    local herbprint = false
    local lowcontrol = false

    local function smartMonitor()
        while true do
            local currentHerbs = getHerbValue()
            local playerName = game.Players.LocalPlayer.Name

            -- When herbs > 250k, execute trade script (once)
            if currentHerbs > 250000 and not hasExecutedTrade then
                herbprint = true
                lowcontrol = true -- Set lowcontrol flag when reaching high herbs

                
                    hasExecutedTrade = true
                    print(
                        playerName
                            .. ' --- 自动交易脚本激活! ('
                            .. currentHerbs
                            .. '草药)'
                    )

                -- Start elixir loop if not already running
                if not Autoelixir then
                    coroutine.wrap(startElixirLoop)()
                end

            -- When herbs < 1000 AND we previously had high herbs (lowcontrol)
            elseif currentHerbs < 5000 and lowcontrol then
                Autoelixir = false
                hasExecutedTrade = false
                herbprint = false
                lowcontrol = false -- Reset the control flag
                print(
                    playerName
                        .. ' --- 系统重置! (剩余'
                        .. currentHerbs
                        .. '草药)'
                )
            end
            if herbprint and hasExecutedTrade then
                print(playerName .. ' --- ' .. currentHerbs .. '草药')
            end
            -- Regular status print when in high herb mode

            wait(5)
        end
    end

    -- 初始化检查
    local farm5Level = 0
    local elixirLevel = 0

    -- 获取农田5等级
    pcall(function()
        farm5Level = tonumber(
            GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\134\156\231\148\176']['\232\131\140\230\153\175']['\229\177\158\230\128\167\229\140\186\229\159\159']['\229\177\158\230\128\167\229\136\151\232\161\168']['\229\136\151\232\161\168']['\231\173\137\231\186\167']['\229\128\188'].Text:match(
                '%d+'
            )
        ) or 0
    end)
    GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\134\156\231\148\176'].Visible =
        false

    -- 获取炼丹炉等级
    pcall(function()
        local elixirUI = ReplicatedStorage
            :FindFirstChild('\228\186\139\228\187\182', true)
            :FindFirstChild('\229\174\162\230\136\183\231\171\175', true)
        if elixirUI then
            elixirUI['\229\174\162\230\136\183\231\171\175UI']['\230\137\147\229\188\128\231\130\188\228\184\185\231\130\137']:Fire()
            wait(0.5)
            elixirLevel = tonumber(
                GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\231\130\188\228\184\185\231\130\137']['\232\131\140\230\153\175']['\229\177\158\230\128\167\229\140\186\229\159\159']['\229\177\158\230\128\167\229\136\151\232\161\168']['\229\136\151\232\161\168']['\231\173\137\231\186\167']['\229\128\188'].Text:match(
                    '%d+'
                )
            ) or 0
        end
        GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\231\130\188\228\184\185\231\130\137'].Visible =
            false
    end)

    -- 主逻辑
    if farm5Level >= 80 and elixirLevel >= 80 then
        print('===== 系统启动 =====')
        print('农田5等级:', farm5Level)
        print('炼丹炉等级:', elixirLevel)
        print('初始草药量:', getHerbValue())
        print('==================')
        coroutine.wrap(smartMonitor)()
    else
        print('条件不满足：需要农田5和炼丹炉等级≥80')
    end
 
    local Players = game:GetService('Players')
    local ReplicatedStorage = game:GetService('ReplicatedStorage')
    local LocalPlayer = Players.LocalPlayer

    -- Function to safely check and fire
    local function CheckAndFire()
        -- Your original GUI path (fully preserved)
        local gui =
            LocalPlayer.PlayerGui.GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\232\135\170\229\138\168\229\135\186\229\148\174\229\188\185\229\135\186\230\161\134']['\232\131\140\230\153\175']['\230\140\137\233\146\174']['\230\147\141\228\189\156\229\140\186\229\159\159']['\229\130\168\229\173\152']['\229\155\190\230\160\135']['\229\155\190\230\160\135']

        -- Check if exists and is invisible
        if gui and gui.Visible == false then
            -- Your original RemoteEvent path (fully preserved)
            local remote = ReplicatedStorage
                :WaitForChild('\228\186\139\228\187\182')
                :WaitForChild('\229\133\172\231\148\168')
                :WaitForChild('\231\130\188\228\184\185')
                :WaitForChild(
                    '\228\191\174\230\148\185\232\135\170\229\138\168\229\130\168\229\173\152'
                )
            if remote then
                remote:FireServer()
                print('RemoteEvent fired successfully!')
            else
                warn('RemoteEvent not found!')
            end
        end
    end
    -- Run once immediately
    CheckAndFire()

else
    warn('当前游戏不是目标游戏，脚本未运行。')
end
