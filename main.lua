if not game:IsLoaded() then
    game.Loaded:Wait()
end

local currentGameId = game.PlaceId
local TARGET_GAME_ID = 18645473062
local webhookURL =
    'https://discord.com/api/webhooks/1360322264888905928/qkYNgfUuR2DpE2Ctal9Y7MDQen197Nm8QT3DpPFZ9iCZho99jYpmIPJIHtkdWdHmZKBc'

if currentGameId == TARGET_GAME_ID then
    print('检测到目标游戏，正在执行脚本...')

    -- ====================================================================
    -- 服务缓存 (避免重复调用GetService)
    -- ====================================================================
    local Services = {
        Players = game:GetService('Players'),
        ReplicatedStorage = game:GetService('ReplicatedStorage'),
        Workspace = game:GetService('Workspace'),
        HttpService = game:GetService('HttpService'),
        VirtualUser = game:GetService('VirtualUser'),
    }

    -- Wait for player and player GUI to exist
    local player = Services.Players.LocalPlayer
    while not player:FindFirstChild('PlayerGui') do
        task.wait(1)
    end
    local playerGui = player.PlayerGui

    -- ====================================================================
    -- 通用工具函数模块
    -- ====================================================================
    local Utils = {}

    -- 安全数值解析（支持K/M后缀）
    function Utils.parseNumber(text)
        local str = tostring(text):lower():gsub('%s+', ''):gsub(',', '')
        local numStr = str:gsub('[^%d%.]', '')
        
        -- 检查多个小数点
        if select(2, numStr:gsub('%.', '')) > 1 then
            warn('[Utils] 非法数值格式:', text)
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

    -- 深度等待（链式WaitForChild）
    function Utils.deepWait(parent, path, timeout)
        local obj = parent
        for _, name in ipairs(path) do
            obj = obj and obj:WaitForChild(name, timeout or 5)
            if not obj then
                return nil
            end
        end
        return obj
    end

    -- 安全pcall包装
    function Utils.safePcall(func, ...)
        local success, result = pcall(func, ...)
        if not success then
            warn('[错误]', result)
        end
        return success, result
    end

    -- 创建线程控制器
    function Utils.createThreadController()
        local controller = {
            enabled = false,
            thread = nil,
        }
        
        function controller:start(func)
            self:stop()
            self.enabled = true
            self.thread = task.spawn(function()
                func(self)
            end)
        end
        
        function controller:stop()
            self.enabled = false
            if self.thread then
                task.cancel(self.thread)
                self.thread = nil
            end
        end
        
        return controller
    end

    -- ====================================================================
    -- 常用路径缓存 (避免重复查找)
    -- ====================================================================
    local PathCache = {
        Events = Services.ReplicatedStorage:WaitForChild('\228\186\139\228\187\182'):WaitForChild('\229\133\172\231\148\168'),
    }

    -- 延迟初始化事件缓存（在loadingGui之后调用）
    local function initEventCache()
        local events = PathCache.Events
        PathCache.Farm = events:WaitForChild('\229\134\156\231\148\176')
        PathCache.Elixir = events:WaitForChild('\231\130\188\228\184\185')
        PathCache.Guild = events:WaitForChild('\229\133\172\228\188\154')
        PathCache.Dungeon = events:WaitForChild('\229\137\175\230\156\172')
        PathCache.Shop = events:WaitForChild('\229\149\134\229\186\151')
        PathCache.Stage = events:WaitForChild('\229\133\179\229\141\161')
        PathCache.Activity = events:WaitForChild('\232\138\130\230\151\165\230\180\187\229\138\168')
        PathCache.FlyingSword = events:WaitForChild('\233\163\158\229\137\145')
        PathCache.Weapon = events:WaitForChild('\230\179\149\229\174\157')
        PathCache.Skill = events:WaitForChild('\230\138\128\232\131\189')
        PathCache.Rune = events:WaitForChild('\233\152\181\230\179\149')
        PathCache.Settings = events:WaitForChild('\232\174\190\231\189\174')
        PathCache.Combat = events:WaitForChild('\230\136\152\230\150\151')
        PathCache.Forge = events:WaitForChild('\229\187\186\231\173\145')
        PathCache.WorldCore = events:WaitForChild('\228\184\150\231\149\140\230\160\145')
    end

    -- 延迟初始化GUI路径（在loadingGui之后调用）
    local function initGUICache()
        local GUI = playerGui:WaitForChild('GUI')
        PathCache.GUI = {
            Main = GUI:WaitForChild('\228\184\187\231\149\140\233\157\162'),
            Secondary = GUI:WaitForChild('\228\186\140\231\186\167\231\149\140\233\157\162'),
        }
    end

    -- Function to safely find the loading GUI
    local function findLoadingGui()
        local maxAttempts = 30
        for i = 1, maxAttempts do
            local success, gui = pcall(function()
                return playerGui.GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\138\160\232\189\189\233\161\181\233\157\162']
            end)
            if success and gui then
                return gui
            end
            task.wait(0.5)
        end
        return nil
    end

    -- Main waiting logic
    local loadingGui = findLoadingGui()

    if loadingGui then
        print('找到加载界面，等待加载完成...')

        -- Wait for it to become visible if not already
        if not loadingGui.Visible then
            local visibleChanged = false
            local connection = loadingGui
                :GetPropertyChangedSignal('Visible')
                :Connect(function()
                    visibleChanged = true
                end)

            -- Timeout after 10 seconds if never becomes visible
            local startTime = os.time()
            while not visibleChanged and os.time() - startTime < 10 do
                task.wait(0.1)
            end
            connection:Disconnect()
        end

        -- Now wait for it to become invisible
        if loadingGui.Visible then
            print('等待加载界面消失...')
            while loadingGui.Parent and loadingGui.Visible do
                loadingGui:GetPropertyChangedSignal('Visible'):Wait()
                task.wait(0.1)
            end
        end
    else
        warn('?? 未能找到加载界面，继续执行脚本...')
    end

    print('? 加载完成，继续执行脚本...')
    
    -- 初始化路径缓存
    initEventCache()
    initGUICache()
    print('?? 路径缓存已初始化')
    
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
    -- 防止AFK
    player.Idled:Connect(function()
        Services.VirtualUser:CaptureController()
        Services.VirtualUser:ClickButton2(Vector2.new())
        task.wait(2)
    end)
    local window = library:AddWindow(
        'Cultivation-Simulator  养成模拟器',
        {
            main_color = Color3.fromRGB(41, 74, 122),
            min_size = Vector2.new(530, 315),
            can_resize = false,
        }
    )
    local function safeSetControl(control, value, controlName)
        if control and control.Set then
            control:Set(value)
            return true
        end
        warn('控件无法设置默认值: ' .. tostring(controlName))
        return false
    end
    local features = window:AddTab('自述')
    local features1 = window:AddTab('Main')
    local features2 = window:AddTab('副本')
    local features3 = window:AddTab('地下城')
    local features4 = window:AddTab('抽取')
    local features5 = window:AddTab('杂项')
    local features6 = window:AddTab('开启UI')
    local features7 = window:AddTab('设定')
    local features8 = window:AddTab('农田操作')
    local features9 = window:AddTab('加入副本')
    local ws = game:GetService('Workspace')
    local Players = game.Players
    local localPlayer = game.Players.LocalPlayer
    local playerGui = player.PlayerGui
    local RespawPointnum = RespawPoint:match('%d+')
    print('重生点编号：' .. RespawPointnum)
    local reworld = ws:WaitForChild('主場景' .. RespawPointnum)
        :WaitForChild('重生点')
    local TPX, TPY, TPZ =
        reworld.Position.X, reworld.Position.Y + 5, reworld.Position.Z
    local Restart = false
    local finishworldnum
    local values = player:WaitForChild('值')
    local privileges = values:WaitForChild('特权')
    local DEFAULT_WORLD_LEVEL = 78
    local worldSettingsFilePath = 'WorldSettings.json'
    local function normalizeWorldSettings(settings)
        local normalized = settings or {}
        local worldLevel = math.floor(
            tonumber(normalized.worldLevel) or DEFAULT_WORLD_LEVEL
        )
        if worldLevel < 1 then
            worldLevel = DEFAULT_WORLD_LEVEL
        end
        return {
            worldLevel = worldLevel,
            worldMode = (normalized.worldMode == 'auto_highest')
                and 'auto_highest'
                or 'manual',
            worldAutoStart = normalized.worldAutoStart == true,
        }
    end
    local function loadWorldSettingsData()
        if not isfile(worldSettingsFilePath) then
            return {}
        end
        local success, fileContent = pcall(readfile, worldSettingsFilePath)
        if not success or fileContent == '' then
            return {}
        end
        local decodeSuccess, data =
            pcall(Services.HttpService.JSONDecode, Services.HttpService, fileContent)
        if not decodeSuccess or type(data) ~= 'table' then
            warn('WorldSettings.json 解析失败，已回退为默认配置')
            return {}
        end
        return data
    end
    local function saveWorldSettingsData(data)
        local encodeSuccess, fileContent =
            pcall(Services.HttpService.JSONEncode, Services.HttpService, data)
        if not encodeSuccess then
            warn('WorldSettings.json 编码失败')
            return false
        end
        local writeSuccess, writeError =
            pcall(writefile, worldSettingsFilePath, fileContent)
        if not writeSuccess then
            warn('WorldSettings.json 写入失败: ' .. tostring(writeError))
            return false
        end
        return true
    end
    local function getPlayerWorldSettings()
        local allSettings = loadWorldSettingsData()
        return normalizeWorldSettings(allSettings[player.Name])
    end
    local function updatePlayerWorldSettings(updates)
        local allSettings = loadWorldSettingsData()
        local playerSettings = normalizeWorldSettings(allSettings[player.Name])
        for key, value in pairs(updates) do
            playerSettings[key] = value
        end
        playerSettings = normalizeWorldSettings(playerSettings)
        allSettings[player.Name] = playerSettings
        saveWorldSettingsData(allSettings)
        return playerSettings
    end
    local gowordlevels = getPlayerWorldSettings().worldLevel
    local isDetectionEnabled = true
    local playerInRange = false
    local timescheck = 0
    local hasPrintedNoPlayer = false
    local showone = false
    local savemodetime = 0
    local savemodetime2 = 0
    local savemodebutton

    -- ====================================================================
    -- 右上角提示系统（简单版）
    -- ====================================================================
    local function showTopRightNotice(text, lifetime)
        local pg = player:WaitForChild('PlayerGui')
        local gui = pg:FindFirstChild('FarmNoticeGui')
            or Instance.new('ScreenGui')
        gui.Name = 'FarmNoticeGui'
        gui.ResetOnSpawn = false
        gui.Parent = pg

        local label = gui:FindFirstChild('Notice') or Instance.new('TextLabel')
        label.Name = 'Notice'
        label.AnchorPoint = Vector2.new(1, 0)
        label.Position = UDim2.new(1, -20, 0, 20)
        label.Size = UDim2.new(0, 260, 0, 34)
        label.BackgroundTransparency = 0.3 -- 不透明背景
        label.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- 黑色背景
        label.TextColor3 = Color3.fromRGB(255, 0, 0) -- 红色文字
        label.TextScaled = true
        label.TextWrapped = true
        label.Font = Enum.Font.SourceSansSemibold
        label.Text = text
        label.Parent = gui

        task.delay(lifetime or 3, function()
            if label then
                label:Destroy()
            end
            if gui and #gui:GetChildren() == 0 then
                gui:Destroy()
            end
        end)
    end
    -- ====================================================================
    -- 任务完成状态追踪（用于农田收菜流程）
    -- ====================================================================
    local donationFinished = false        -- 公会捐献是否完成
    local herbBuyFinished = false         -- 草药购买是否完成
    local herbCollectFinished = false     -- 草药收集是否完成
    local farmReady = false              -- 农田5是否准备好
    local function checkAllTasksFinished()
        if
            donationFinished
            and herbBuyFinished
            and herbCollectFinished
            and farmReady
        then
            showTopRightNotice('收菜完成！', 1)
        end
    end
    local function setupFeaturesTab(features)
        local function checkPlayersInRange()
            local character = localPlayer.Character
            if
                not character or not character:FindFirstChild(
                    'HumanoidRootPart'
                )
            then
                return
            end
            local boxPosition = character.HumanoidRootPart.Position
            local boxSize = Vector3.new(500, 500, 500) / 2
            playerInRange = false
            for _, player in pairs(Players:GetPlayers()) do
                if
                    (player ~= localPlayer)
                    and player.Character
                    and player.Character:FindFirstChild('HumanoidRootPart')
                then
                    local playerPosition =
                        player.Character.HumanoidRootPart.Position
                    local inRange = (
                        math.abs(playerPosition.X - boxPosition.X) <= boxSize.X
                    )
                        and (math.abs(playerPosition.Y - boxPosition.Y) <= boxSize.Y)
                        and (
                            math.abs(playerPosition.Z - boxPosition.Z)
                            <= boxSize.Z
                        )
                    if inRange then
                        playerInRange = true
                        break
                    end
                end
            end
            if playerInRange then
                if timescheck == 0 then
                    savemodetime2 = 0
                    savemodetime = 0
                    timescheck = 1
                    hasPrintedNoPlayer = true
                end
            elseif timescheck == 1 then
                timescheck = 0
                savemodetime2 = 0
                hasPrintedNoPlayer = false
            end
            if not playerInRange and not hasPrintedNoPlayer then
                savemodetime = 0
                savemodetime2 = 0
                hasPrintedNoPlayer = true
            end
        end
        local function setupRangeDetection()
            while true do
                if isDetectionEnabled then
                    checkPlayersInRange()
                end
                task.wait(0.1)
            end
        end
        local function toggleDetection()
            isDetectionEnabled = not isDetectionEnabled
            print(
                '检测已' .. ((isDetectionEnabled and '启用') or '关闭')
            )
            if not isDetectionEnabled then
                savemodetime = 0
                savemodetime2 = 0
            end
        end
        local function getGiftCountdown(index)
            local gift = Online_Gift:FindFirstChild('Online_Gift' .. index)
            if not gift then
                return nil
            end
            local countdownText = gift:FindFirstChild('按钮')
                :FindFirstChild('倒计时').Text
            if countdownText == 'CLAIMED!' then
                return 0
            elseif countdownText == 'DONE' then
                local args = { [1] = index }
                PathCache.Activity:FindFirstChild('\233\162\134\229\143\150\229\165\150\229\138\177'):FireServer(unpack(args))
                return 0
            else
                local minutes, seconds = countdownText:match('^(%d+):(%d+)$')
                if minutes and seconds then
                    return (tonumber(minutes) * 60) + tonumber(seconds)
                end
            end
            return nil
        end
        local function checkOnlineGiftcountdown()
            local minCountdown = math.huge
            local Countdown = {}
            for i = 1, 6 do
                local totalSeconds = getGiftCountdown(i)
                if totalSeconds then
                    Countdown[i] = totalSeconds
                    OnlineGift_data[i] = totalSeconds
                    if (totalSeconds < minCountdown) and (totalSeconds > 0) then
                        minCountdown = totalSeconds
                    end
                else
                    Countdown[i] = nil
                end
            end
            if minCountdown ~= math.huge then
                if localCountdownActive then
                    for i = 1, 6 do
                        if Countdown[i] and (Countdown[i] > 0) then
                            Countdown[i] = Countdown[i] - 1
                            local minutes = math.floor(Countdown[i] / 60)
                            local seconds = Countdown[i] % 60
                            local formattedTime =
                                string.format('%02d:%02d', minutes, seconds)
                            Online_Gift:FindFirstChild('Online_Gift' .. i)
                                :FindFirstChild('按钮')
                                :FindFirstChild('倒计时').Text =
                                formattedTime
                        end
                    end
                    minCountdown = minCountdown - 1
                else
                end
            end
        end
        local function chaangeonlinegiftname()
            for i = 1, 6 do
                local giftName = '在线奖励0' .. i
                local gift = Online_Gift:FindFirstChild(giftName)
                if gift then
                    gift.Name = 'Online_Gift' .. tostring(gift.LayoutOrder + 1)
                    print('名称已更改为：' .. gift.Name)
                else
                    allGiftsExist = false
                    break
                end
            end
            if allGiftsExist then
                print('在线奖励--名称--已全部更改')
            else
                print('名称已重复或部分名称不存在')
            end
        end
        local function checkTimeAndRun()
            task.spawn(function()
                while true do
                    local currentTime = os.time()
                    local utcTime = os.date('!*t', currentTime)
                    local utcPlus8Time = os.date('*t', currentTime + (8 * 3600))
                    if (utcPlus8Time.hour == 0) and (utcPlus8Time.min == 0) then
                        print(
                            'UTC+8 时间为 00:00，开始执行更新数据...'
                        )
                        task.spawn(function()
                            allGiftsExist = true
                            chaangeonlinegiftname()
                            task.wait(1)
                            checkOnlineGiftcountdown()
                        end)
                        task.wait(60)
                    end
                    task.wait(1)
                end
            end)
        end
        checkTimeAndRun()
        features4:Show()
        local AddLabelfeatures = features:AddLabel('重生点：重生点')
        AddLabelfeatures.Text = '重生点：'
            .. RespawPoint
            .. ' -- 传送错误请回家后使用底下按钮'
        local function Respawn_Point()
            RespawPoint = loadstring(
                game:HttpGet(
                    'https://raw.githubusercontent.com/Tseting-nil/-Cultivation-Simulator-script/refs/heads/main/%E6%89%8B%E6%A9%9F%E7%AB%AFUI/%E9%85%8D%E7%BD%AE%E4%B8%BB%E5%A0%B4%E6%99%AF.lua'
                )
            )()
            AddLabelfeatures.Text = '重生点：'
                .. RespawPoint
                .. ' -- 传送错误请回家后使用底下按钮'
            print('最近的出生点：' .. RespawPoint)
            RespawPointnum = RespawPoint:match('%d+')
            print('重生点编号：' .. RespawPointnum)
            reworld = workspace
                :WaitForChild('主场景' .. RespawPointnum)
                :WaitForChild('重生点')
            TPX, TPY, TPZ =
                reworld.Position.X, reworld.Position.Y + 5, reworld.Position.Z
            print('传送座标：' .. TPX .. ' ' .. TPY .. ' ' .. TPZ)
            player.Character:WaitForChild('HumanoidRootPart').CFrame =
                CFrame.new(TPX, TPY, TPZ)
        end
        features:AddButton('重生点更改', function()
            Respawn_Point()
        end)
        local function updateButtonText()
            if isDetectionEnabled then
                savemodebutton.Text = ' 状态：已启用安全模式'
            else
                savemodebutton.Text = ' 状态：以关闭安全模式'
            end
        end
        savemodebutton = features:AddButton(
            ' 状态：启用安全模式 ',
            function()
                inRange = false
                playerInRange = false
                timescheck = 0
                hasPrintedNoPlayer = false
                toggleDetection()
                updateButtonText()
            end
        )
        updateButtonText()
        task.spawn(setupRangeDetection)
        local screenGui = Instance.new('ScreenGui')
        screenGui.Parent = game.Players.LocalPlayer:WaitForChild('PlayerGui')
        local blackBlock = Instance.new('Frame')
        blackBlock.Size = UDim2.new(200, 0, 200, 0)
        blackBlock.Position = UDim2.new(0, 0, 0, 0)
        blackBlock.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        blackBlock.Visible = false
        blackBlock.Parent = screenGui
        features:AddButton('黑幕开/关闭', function()
            blackBlock.Visible = not blackBlock.Visible
        end)
    end

    local function setupFeatures1Tab(features1)
        local timeLabel =
            features1:AddLabel('距离下自动获取还有 0 秒')
        local playerGui = game.Players.LocalPlayer.PlayerGui
        local Online_Gift = playerGui.GUI
            :WaitForChild('二级界面')
            :WaitForChild('节日活动商店')
            :WaitForChild('背景')
            :WaitForChild('右侧界面')
            :WaitForChild('在线奖励')
            :WaitForChild('列表')
        local Gife_check = false
        local onlineGiftThread = nil
        local countdownList = {}
        local lastExecutedDay = os.date('!%Y-%m-%d', os.time() + (8 * 3600))

        local function convertToSeconds(timeText)
            local minutes, seconds = string.match(timeText, '(%d+):(%d+)')
            if minutes and seconds then
                return (tonumber(minutes) * 60) + tonumber(seconds)
            end
            return nil
        end
        local function GetOnlineGiftCountdown()
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
            -- 如果倒计时到达或小于等于0，触发领取
            if nowminCountdown and (nowminCountdown <= 0) then
                timeLabel.Text = '倒计时结束，准备获取奖励'
                -- 触发所有可领取的奖励
                for i = 1, 6 do
                    local args = { [1] = i }
                    pcall(function()
                        PathCache.Activity
                            :FindFirstChild('\233\162\134\229\143\150\229\165\150\229\138\177')
                            :FireServer(unpack(args))
                    end)
                end
                -- 等待服务器响应，然后重新获取倒计时
                task.wait(2)
            end
            
            -- 每次循环都重新获取当前倒计时（获取最新状态）
            local newMinCountdown = GetOnlineGiftCountdown()
            
            -- 更新倒计时状态
            if newMinCountdown then
                -- 如果获取到新的倒计时
                if newMinCountdown ~= minCountdown then
                    -- 倒计时已更新（新的奖励或领取后刷新），重置计数器
                    minCountdown = newMinCountdown
                    nowminCountdown = minCountdown
                elseif nowminCountdown and nowminCountdown > 0 then
                    -- 倒计时还在进行中，继续减少
                    nowminCountdown = nowminCountdown - 1
                else
                    -- 倒计时未初始化或已归零，设置为新值
                    nowminCountdown = newMinCountdown
                    minCountdown = newMinCountdown
                end
                
                -- 更新显示
                if nowminCountdown and (nowminCountdown > 0) then
                    timeLabel.Text = string.format(
                        '距离下自动获取还有 %d 秒',
                        nowminCountdown
                    )
                elseif nowminCountdown and (nowminCountdown <= 0) then
                    -- 倒计时已归零，下次循环会触发领取
                    timeLabel.Text = '倒计时即将结束...'
                end
            else
                -- 没有倒计时，说明当前周期全部领取完成，继续等待下一次刷新
                timeLabel.Text = '已全部领取，等待刷新...'
            end
        end
        local function Online_Gift_check()
            while Gife_check do
                Online_Gift_start()
                if nowminCountdown and (nowminCountdown > 0) then
                    task.wait(1)
                else
                    task.wait(5)
                end
            end
            onlineGiftThread = nil
        end
        local function ClaimOnlineRewards()
            if Gife_check and onlineGiftThread then
                return
            end
            Gife_check = true
            onlineGiftThread = task.spawn(Online_Gift_check)
        end
        -- 创建按钮时引用函数
        features1:AddButton('自动领取在线奖励', ClaimOnlineRewards)
        -- 启动时自动执行
        task.defer(function()
            ClaimOnlineRewards()
        end)
        task.spawn(function()
            while true do
                local utcPlus8 = os.date('!*t', os.time() + (8 * 3600))
                local currentLocalHour = utcPlus8.hour
                local currentLocalDate = string.format(
                    '%04d-%02d-%02d',
                    utcPlus8.year,
                    utcPlus8.month,
                    utcPlus8.day
                )
                if
                    currentLocalHour == 0
                    and lastExecutedDay ~= currentLocalDate
                then
                    print('UTC+8 00:00，在线奖励刷新，继续自动领取')
                    lastExecutedDay = currentLocalDate
                    countdownList = {}
                    minCountdown = nil
                    nowminCountdown = 0
                    ClaimOnlineRewards()
                end
                task.wait(60)
            end
        end)
        -- 自动任务领取控制变量（局部变量）
        local Autocollmissionbool = false
        
        local Autocollmission = features1:AddSwitch(
            '自动任务领取(包括GamePass任务、奖励)',
            function(bool)
                Autocollmissionbool = bool
                if Autocollmissionbool then
                    -- 主任务循环（每20秒执行一次）
                    task.spawn(function()
                        while Autocollmissionbool do
                            pcall(function()
                                mainmissionchack()
                                everydaymission()
                                gamepassmission()
                                gamepassgiftget()
                                potionfull()
                            end)
                            task.wait(20)
                        end
                    end)

                    -- dailyspin 独立循环（每500秒执行一次）
                    task.spawn(function()
                        while Autocollmissionbool do
                            pcall(function()
                                dailyspin()
                                offlinereward()
                                everydaygem()
                            end)
                            task.wait(500)
                        end
                    end)
                end
            end
        )

        safeSetControl(Autocollmission, true, 'Autocollmission')
        -- 自动投资控制变量（局部变量）
        local investbool = false
        
        local invest = features1:AddSwitch('自动执行投资', function(bool)
            investbool = bool
            if investbool then
                task.spawn(function()
                    while investbool do
                        pcall(function()
                            -- 领取投资
                            for i = 1, 3 do
                                local args = { i }
                                PathCache.Shop:FindFirstChild('\233\147\182\232\161\140'):FindFirstChild('\233\162\134\229\143\150\231\144\134\232\180\162')
                                    :FireServer(unpack(args))
                            end
                            task.wait(5)
                            -- 升级投资
                            for i = 1, 3 do
                                local args = { i }
                                PathCache.Shop:FindFirstChild('\233\147\182\232\161\140'):FindFirstChild('\232\180\173\228\185\176\231\144\134\232\180\162')
                                    :FireServer(unpack(args))
                            end
                        end)
                        task.wait(600)
                    end
                end)
            end
        end)
        safeSetControl(invest, true, 'invest')
        local function openFarm5()
            pcall(function()
                -- 使用路径缓存优化
                local farmUI = Services.ReplicatedStorage:FindFirstChild('\228\186\139\228\187\182')
                    :FindFirstChild('\229\134\156\231\148\176')
                    :FindFirstChild('\229\134\156\231\148\176UI')
                    :FindFirstChild('\229\177\158\230\128\167\229\140\186\229\159\159')
                if farmUI then
                    farmUI:FireServer(5)
                end
            end)
            task.wait(0.5) -- 给UI一点时间打开
        end

        -- 读取你指定路径上的数字文本
        local function readFarm5Number()
            local root = player:WaitForChild('PlayerGui'):WaitForChild('GUI')

            local label = Utils.deepWait(root, {
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
        -- 自动采草药控制变量（局部变量）
        local AutoCollectherbsbool = false
        
        local AutoCollectherbs = features1:AddSwitch(
            '自动采草药',
            function(bool)
                AutoCollectherbsbool = bool
                if AutoCollectherbsbool then
                    task.spawn(function()
                        while AutoCollectherbsbool do
                            pcall(function()
                                for i = 1, 6 do
                                    local args = { [1] = i, [2] = nil }
                                    PathCache.Farm:FindFirstChild('\233\135\135\233\155\134')
                                        :FireServer(unpack(args))
                                    task.wait(0.1)
                                end

                                -- ?? 一轮收集完成
                                herbCollectFinished = true
                                print(
                                    '[系统] 草药收集一轮完成，检查农田 5 状态…'
                                )
                                openFarm5()
                                waitFarm5Below100()
                            end)

                            task.wait(60) -- 等下一轮
                        end
                    end)
                end
            end
        )

        safeSetControl(AutoCollectherbs, true, 'AutoCollectherbs')
        features1:AddLabel(' - - 通行证解锁')
        local Refining = features1:AddSwitch(
            '解锁自动炼制',
            function(bool)
                local Refiningbool = bool
                privileges:WaitForChild('超级炼制').Value = false
                privileges:WaitForChild('自动炼制').Value = Refiningbool
            end
        )
        safeSetControl(Refining, true, 'Refining')
        local showAll = features1:AddSwitch('显示所有货币', function(bool)
            ShowAllbool = bool
            if ShowAllbool then
                task.spawn(function()
                    while ShowAllbool do
                        pcall(function()
                            local currencyPanel = PathCache.GUI.Main['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159']
                            currencyPanel['\230\180\187\229\138\168\231\137\169\229\147\129'].Visible = true
                            currencyPanel['\231\159\191\231\159\179'].Visible = false
                            currencyPanel['\231\172\166\231\159\179\231\178\137\230\156\171'].Visible = true
                            currencyPanel['\231\173\137\231\186\167'].Visible = true
                            currencyPanel['\231\180\171\233\146\187'].Visible = true
                            currencyPanel['\232\141\137\232\141\175'].Visible = false
                            currencyPanel['\233\135\145\229\184\129'].Visible = true
                            currencyPanel['\233\146\187\231\159\179'].Visible = true
                        end)
                        task.wait(0.3)
                    end
                end)
            end
        end)
        safeSetControl(showAll, false, 'showAll')
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
        features1:AddButton('删除显示获得的奖励(所有的)', function()
            RemoveRewardUI()
        end)

        -- 启动时延迟执行
        task.defer(function()
            RemoveRewardUI()
        end)
        features1:AddButton('兑换游戏礼品码', function()
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
                PathCache.Events
                    :FindFirstChild('\230\191\128\230\180\187\231\160\129')
                    :FindFirstChild(
                        '\231\142\169\229\174\182\229\133\145\230\141\162\230\191\128\230\180\187\231\160\129'
                    )
                    :FireServer(unpack(args))
            end
        end)
    end
    local function setupFeatures2Tab(features2)
        -- 75关自动重试的全局控制变量
        local AutoReenter = false
        local AutoReenterThread = nil
        local Autostartwarld = false
        local AutostartThread = nil
        local savedWorldSettings = getPlayerWorldSettings()
        local worldSelectionMode = savedWorldSettings.worldMode
        local autoHighestWorldThread = nil
        
        local worldnum = player
            :WaitForChild('值')
            :WaitForChild('主线进度')
            :WaitForChild('world').Value
        local newworldnum = worldnum
        local function statisticsupdata()
            worldnum = player
                :WaitForChild('值')
                :WaitForChild('主线进度')
                :WaitForChild('world').Value
        end
        task.spawn(function()
            while true do
                statisticsupdata()
                task.wait(1)
            end
        end)
        local Difficulty_choose =
            features2:AddLabel('  当前选择 关卡： ' .. savedWorldSettings.worldLevel)
        local function saveCurrentWorldSettings(updates)
            savedWorldSettings = updatePlayerWorldSettings(updates)
        end
        local function gowordlevelscheak(gowordlevels)
            if gowordlevels > worldnum then
                if gowordlevels < 10 then
                    Difficulty_choose.Text = '  关卡未解锁 关卡： 0'
                        .. gowordlevels
                else
                    Difficulty_choose.Text = '  关卡未解锁 关卡： '
                        .. gowordlevels
                end
            elseif gowordlevels < 10 then
                Difficulty_choose.Text = '  当前选择 关卡： 0'
                    .. gowordlevels
            else
                    Difficulty_choose.Text = '  当前选择 关卡： '
                        .. gowordlevels
            end
        end
        local function updateAutoHighestWorldLabel()
            if worldnum < 10 then
                Difficulty_choose.Text = '  当前选择最高关卡： 0' .. worldnum
            else
                Difficulty_choose.Text = '  当前选择最高关卡： ' .. worldnum
            end
        end
        local function stopAutoHighestWorldMode(silent)
            local wasAutoHighest = worldSelectionMode == 'auto_highest'
            worldSelectionMode = 'manual'
            if autoHighestWorldThread then
                task.cancel(autoHighestWorldThread)
                autoHighestWorldThread = nil
            end
            if wasAutoHighest and not silent then
                print('自动最高关卡已停止')
            end
        end
        local function setManualWorldLevel(newLevel, labelOverride, silentStop)
            stopAutoHighestWorldMode(silentStop)
            gowordlevels = math.max(1, math.floor(tonumber(newLevel) or DEFAULT_WORLD_LEVEL))
            if labelOverride then
                Difficulty_choose.Text = labelOverride
            else
                gowordlevelscheak(gowordlevels)
            end
            saveCurrentWorldSettings({
                worldLevel = gowordlevels,
                worldMode = 'manual',
            })
        end
        local function startAutoHighestWorldMode()
            if autoHighestWorldThread then
                task.cancel(autoHighestWorldThread)
                autoHighestWorldThread = nil
            end
            worldSelectionMode = 'auto_highest'
            print('当前选择：自动最高关卡')
            gowordlevels = worldnum
            newworldnum = worldnum
            updateAutoHighestWorldLabel()
            saveCurrentWorldSettings({
                worldLevel = gowordlevels,
                worldMode = worldSelectionMode,
            })
            autoHighestWorldThread = task.spawn(function()
                print('自动最高关卡已启动')
                while worldSelectionMode == 'auto_highest' do
                    if newworldnum ~= worldnum then
                        gowordlevels = worldnum
                        newworldnum = worldnum
                        finishworldnum = tonumber(gowordlevels)
                        updateAutoHighestWorldLabel()
                        saveCurrentWorldSettings({
                            worldLevel = gowordlevels,
                            worldMode = worldSelectionMode,
                        })
                        wait(savemodetime2)
                        wait(savemodetime + 1)
                        local args = { [1] = finishworldnum }
                        PathCache.Stage
                            :FindFirstChild(
                                '\232\191\155\229\133\165\228\184\150\231\149\140\229\133\179\229\141\161'
                            )
                            :FireServer(unpack(args))
                    end
                    task.wait(1)
                end
                autoHighestWorldThread = nil
            end)
        end
        local Difficulty_selection = features2:AddDropdown(
            '                关卡难易度选择                ',
            function(text)
                if text == '      世界关卡简单： 01       ' then
                    print('当前选择：简单')
                    setManualWorldLevel(1, '  当前选择： 01')
                elseif text == '      世界关卡普通： 21       ' then
                    print('当前选择：普通')
                    setManualWorldLevel(21)
                elseif text == '      世界关卡困难： 55       ' then
                    print('当前选择：困难')
                    setManualWorldLevel(55)
                elseif text == '      世界关卡专家： 64       ' then
                    print('当前选择：专家')
                    setManualWorldLevel(64)
                elseif text == '      世界关卡大师： 82       ' then
                    print('当前选择：大师')
                    setManualWorldLevel(82)
                elseif text == '      世界关卡      ： 101       ' then
                    print('当前选择：专家')
                    setManualWorldLevel(101)
                elseif text == '      自动最高关卡        ' then
                    startAutoHighestWorldMode()
                end
            end
        )
        local Levels1 =
            Difficulty_selection:Add('      世界关卡简单： 01       ')
        local Levels2 =
            Difficulty_selection:Add('      世界关卡普通： 21       ')
        local Levels3 =
            Difficulty_selection:Add('      世界关卡困难： 55       ')
        local Levels4 =
            Difficulty_selection:Add('      世界关卡专家： 64       ')
        local Levels5 =
            Difficulty_selection:Add('      世界关卡大师： 82       ')
        local Levels99 =
            Difficulty_selection:Add('      自动最高关卡        ')
        local Levels999 = Difficulty_selection:Add('空白')
        features2:AddButton('选择关卡+1', function()
            setManualWorldLevel(gowordlevels + 1)
        end)
        features2:AddButton('选择关卡-1', function()
            setManualWorldLevel(gowordlevels - 1)
        end)
        local combatUI = playerGui.GUI
            :WaitForChild('主界面')
            :WaitForChild('战斗')
            :WaitForChild('关卡信息')
            :WaitForChild('文本')
        local function teleporttworld1()
            local args = { [1] = gowordlevels }
            PathCache.Stage
                :FindFirstChild(
                    '\232\191\155\229\133\165\228\184\150\231\149\140\229\133\179\229\141\161'
                )
                :FireServer(unpack(args))
            print('传送世界关卡：' .. gowordlevels)
        end
        local function teleporttworld2()
            finishworldnum = tonumber(gowordlevels)
            local args = { [1] = finishworldnum }

            -- 使用路径缓存
            local targetEvent = PathCache.Stage
                :FindFirstChild(
                    '\232\191\155\229\133\165\228\184\150\231\149\140\229\133\179\229\141\161'
                )

            if targetEvent then
                pcall(function()
                    targetEvent:FireServer(unpack(args))
                end)
            end
        end

        local function CheckRestart()
            local success, result = pcall(function()
                return playerGui.GUI
                    :WaitForChild('主界面')
                    :WaitForChild('战斗')
                    :WaitForChild('胜利结果').Text
            end)

            return success and result == 'Victory'
        end
        function teleporthome()
            player.Character:WaitForChild('HumanoidRootPart').CFrame =
                CFrame.new(TPX, TPY, TPZ)
        end
        features2:AddButton('传送', function()
            teleporttworld1()
        end)
        features2:AddSwitch('大於75自动重新进入', function(state)
            if state then
                -- 如果已经运行，先停止
                if AutoReenterThread then
                    AutoReenter = false
                    AutoReenterThread = nil
                    task.wait(0.1) -- 等待旧线程停止
                end
                
                AutoReenter = true
                AutoReenterThread = task.spawn(function()
                    while AutoReenter do
                        local text = combatUI.Text
                        local progress = text:match("-(%d+)%/")
                        if progress then
                            local num = tonumber(progress)
                            if num and num >= 75 then
                                teleporttworld1()
                                task.wait(1)
                            end
                        end
                        task.wait(1)
                    end
                    AutoReenterThread = nil -- 线程结束时清空引用
                end)
            else
                -- 关闭时停止循环
                AutoReenter = false
                AutoReenterThread = nil
            end
        end)
        if savedWorldSettings.worldMode == 'auto_highest' then
            startAutoHighestWorldMode()
        else
            gowordlevels = savedWorldSettings.worldLevel
            gowordlevelscheak(gowordlevels)
        end

        local isRestoringWorldAutoStart = true
        local function setWorldAutoStart(enabled, persist)
            if persist == false then
                savedWorldSettings.worldAutoStart = enabled
            else
                saveCurrentWorldSettings({ worldAutoStart = enabled })
            end
            if enabled then
                -- 如果已经运行，先停止
                if AutostartThread then
                    Autostartwarld = false
                    task.cancel(AutostartThread)
                    AutostartThread = nil
                    task.wait(0.1) -- 等待旧线程停止
                end

                Autostartwarld = true
                AutostartThread = task.spawn(function()
                    while Autostartwarld do
                        -- 双重状态检查
                        if not Autostartwarld then
                            break
                        end

                        local isVictory = CheckRestart()

                        if isVictory then
                            local char = player.Character
                            if
                                char
                                and char:FindFirstChild('HumanoidRootPart')
                            then
                                local hrp = char.HumanoidRootPart
                                hrp.CFrame = CFrame.new(TPX, TPY, TPZ)
                                teleporttworld2()

                                -- 分段等待便于中断
                                for i = 1, 10 do
                                    if not Autostartwarld then
                                        break
                                    end
                                    task.wait(0.5)
                                end
                            end
                        else
                            local char = player.Character
                            if
                                char
                                and char:FindFirstChild('HumanoidRootPart')
                            then
                                local hrp = char.HumanoidRootPart
                                if
                                    (hrp.Position - Vector3.new(
                                        TPX,
                                        TPY,
                                        TPZ
                                    )).Magnitude
                                    < 2.5
                                then
                                    teleporttworld2()
                                end
                            end
                        end

                        -- 每次循环前检查
                        if not Autostartwarld then
                            break
                        end
                        task.wait(0.3)
                    end
                    Autostartwarld = false -- 确保状态同步
                    AutostartThread = nil -- 线程结束时清空引用
                end)
            else
                -- 安全关闭线程
                Autostartwarld = false
                if AutostartThread then
                    task.cancel(AutostartThread)
                    AutostartThread = nil
                end
            end
        end
        local Autostart = features2:AddSwitch(
            '战斗结束后自动开始(世界战斗)',
            function(bool)
                if isRestoringWorldAutoStart then
                    return
                end
                setWorldAutoStart(bool)
            end
        )

        safeSetControl(
            Autostart,
            savedWorldSettings.worldAutoStart,
            'Autostart'
        )
        isRestoringWorldAutoStart = false
        setWorldAutoStart(savedWorldSettings.worldAutoStart, false)
        local function toggleAfkMode()
            local AFKmod = player
                :WaitForChild('值')
                :WaitForChild('设置')
                :WaitForChild('自动战斗')
            AFKmod.Value = not AFKmod.Value
        end
        features2:AddButton('挂机模式', function()
            toggleAfkMode()
        end)
        if savedWorldSettings.worldAutoStart then
            toggleAfkMode()
        end
    end
    setupFeaturesTab(features)
    setupFeatures1Tab(features1)
    setupFeatures2Tab(features2)
    local httpService = game:GetService('HttpService')
    local player = game.Players.LocalPlayer
    local filePath = 'DungeonsMaxLevel.json'
    local updDungeonui = false
    local AutoDungeonplus1 = false
    local Notexecuted = true
    local AutoDungeonplusonly = false
    local Autofinishdungeon = false
    local dungeonFunctions = {}
    local function extractLocalPlayerData()
        if not isfile(filePath) then
            error('JSON 文件不存在：' .. filePath)
        end
        local fileContent = readfile(filePath)
        local success, data =
            pcall(httpService.JSONDecode, httpService, fileContent)
        if not success then
            error('无法解析 JSON 文件：' .. filePath)
        end
        local localPlayerName = player.Name
        local localPlayerData = data[localPlayerName]
        if not localPlayerData then
            error(
                'LocalPlayer 的资料不存在於 JSON 文件中：'
                    .. localPlayerName
            )
        end
        return localPlayerData
    end
    local function saveDungeonFunctions(playerData)
        for dungeonName, maxLevel in pairs(playerData) do
            local functionName = dungeonName:gsub('MaxLevel', '')
            dungeonFunctions[functionName] = function()
                return maxLevel
            end
        end
    end
    local function updateDungeonFunctions()
        local playerData = JsonHandler.getPlayerData(filePath, player.Name)
        dungeonFunctions = {}
        saveDungeonFunctions(playerData)
    end
    local function main()
        local success, playerData = pcall(extractLocalPlayerData)
        if success then
            saveDungeonFunctions(playerData)
            print('Dungeon 函数已成功创建')
        else
            warn('提取资料失败：' .. tostring(playerData))
        end
    end
    main()
    task.spawn(function()
        while true do
            if updDungeonui then
                pcall(function()
                    local dungeonChoice = playerGui
                        :WaitForChild('GUI')
                        :WaitForChild('二级界面')
                        :WaitForChild('关卡选择')
                        :WaitForChild('副本选择弹出框')
                        :WaitForChild('背景')
                        :WaitForChild('标题')
                        :WaitForChild('名称').Text
                    local dungeonMaxLevel = tonumber(
                        playerGui
                            :WaitForChild('GUI')
                            :WaitForChild('二级界面')
                            :WaitForChild('关卡选择')
                            :WaitForChild('副本选择弹出框')
                            :WaitForChild('背景')
                            :WaitForChild('难度')
                            :WaitForChild('难度等级')
                            :WaitForChild('值').Text
                    )
                    JsonHandler.updateDungeonMaxLevel(
                        filePath,
                        player.Name,
                        dungeonChoice,
                        dungeonMaxLevel
                    )
                    updateDungeonFunctions()
                end)
            end
            task.wait(1)
        end
    end)
    local playerData = JsonHandler.getPlayerData(filePath, player.Name)
    print('玩家初始资料:')
    for key, value in pairs(playerData) do
        print(key, value)
    end
    local Dungeonslist = playerGui
        :WaitForChild('GUI')
        :WaitForChild('二级界面')
        :WaitForChild('关卡选择')
        :WaitForChild('背景')
        :WaitForChild('右侧界面')
        :WaitForChild('副本')
        :WaitForChild('列表')
    local dropdownchoose = 0
    local dropdownchoose2 = '1'
    local dropdownchoose3 = 0
    local function getDungeonKey(dungeonName)
        local dungeon = Dungeonslist:FindFirstChild(dungeonName)
        if dungeon then
            local keyText =
                dungeon:WaitForChild('钥匙'):WaitForChild('值').Text
            local key = tonumber(string.match(keyText, '^%d+'))
            if key then
                return ((key < 10) and string.format('0%d', key))
                    or tostring(key)
            end
        end
        return nil
    end
    local function checkDungeonkey()
        Ore_Dungeonkey = getDungeonKey('OreDungeon')
        Gem_Dungeonkey = getDungeonKey('GemDungeon')
        Gold_Dungeonkey = getDungeonKey('GoldDungeon')
        Relic_Dungeonkey = getDungeonKey('RelicDungeon')
        Rune_Dungeonkey = getDungeonKey('RuneDungeon')
        Hover_Dungeonkey = getDungeonKey('HoverDungeon')
    end
    checkDungeonkey()
    local chooselevels = features3:AddLabel('请选择地下城...')
    local dropdown1 = features3:AddDropdown('选择地下城', function(text)
        if text == '            矿石地下城            ' then
            dropdownchoose = 1
            dropdownchoose2 = tostring(
                (
                    dungeonFunctions['OreDungeon']
                    and dungeonFunctions['OreDungeon']()
                ) or '0'
            )
            chooselevels.Text = '当前选择：矿石地下城,  钥匙：'
                .. Ore_Dungeonkey
                .. '  ,关卡选择：'
                .. dropdownchoose2
        elseif text == '            灵石地下城            ' then
            dropdownchoose = 2
            dropdownchoose2 = tostring(
                (
                    dungeonFunctions['GemDungeon']
                    and dungeonFunctions['GemDungeon']()
                ) or '0'
            )
            chooselevels.Text = '当前选择：灵石地下城,  钥匙：'
                .. Gem_Dungeonkey
                .. '  ,关卡选择：'
                .. dropdownchoose2
        elseif text == '            符石地下城            ' then
            dropdownchoose = 3
            dropdownchoose2 = tostring(
                (
                    dungeonFunctions['RuneDungeon']
                    and dungeonFunctions['RuneDungeon']()
                ) or '0'
            )
            chooselevels.Text = '当前选择：符石地下城,  钥匙：'
                .. Rune_Dungeonkey
                .. '  ,关卡选择：'
                .. dropdownchoose2
        elseif text == '            遗物地下城            ' then
            dropdownchoose = 4
            dropdownchoose2 = tostring(
                (
                    dungeonFunctions['RelicDungeon']
                    and dungeonFunctions['RelicDungeon']()
                ) or '0'
            )
            chooselevels.Text = '当前选择：遗物地下城,  钥匙：'
                .. Relic_Dungeonkey
                .. '  ,关卡选择：'
                .. dropdownchoose2
        elseif text == '            悬浮地下城            ' then
            dropdownchoose = 7
            dropdownchoose2 = tostring(
                (
                    dungeonFunctions['HoverDungeon']
                    and dungeonFunctions['HoverDungeon']()
                ) or '0'
            )
            chooselevels.Text = '当前选择：悬浮地下城,  钥匙：'
                .. Hover_Dungeonkey
                .. '  ,关卡选择：'
                .. dropdownchoose2
        elseif text == '            金币地下城            ' then
            dropdownchoose = 6
            dropdownchoose2 = tostring(
                (
                    dungeonFunctions['GoldDungeon']
                    and dungeonFunctions['GoldDungeon']()
                ) or '0'
            )
            chooselevels.Text = '当前选择：金币地下城,  钥匙：'
                .. Gold_Dungeonkey
                .. '  ,关卡选择：'
                .. dropdownchoose2
        elseif text == '            活动地下城   未开启         ' then
            dropdownchoose = 5
            dropdownchoose2 = '未开启'
            chooselevels.Text = '当前选择：活动地下城  未开启'
        else
            dropdownchoose = 8
            chooselevels.Text = '此为占位符号无任何效果'
        end
    end)
    local Dungeon1 = dropdown1:Add('            矿石地下城            ')
    local Dungeon2 = dropdown1:Add('            灵石地下城            ')
    local Dungeon3 = dropdown1:Add('            符石地下城            ')
    local Dungeon4 = dropdown1:Add('            遗物地下城            ')
    local Dungeon5 = dropdown1:Add('            悬浮地下城            ')
    local Dungeon6 = dropdown1:Add('            金币地下城            ')
    local Dungeon7 =
        dropdown1:Add('            活动地下城   未开启            ')
    local Dungeon8 = dropdown1:Add(
        '            此为占位符号无任何效果            '
    )
    local function UDPDungeontext()
        if dropdownchoose == 0 then
            chooselevels.Text = '请选择地下城'
        elseif dropdownchoose == 1 then
            dropdownchoose2 = tostring(
                (
                    dungeonFunctions['OreDungeon']
                    and dungeonFunctions['OreDungeon']()
                ) or '0'
            )
            chooselevels.Text = '当前选择：矿石地下城,  钥匙：'
                .. Ore_Dungeonkey
                .. '  ,关卡选择：'
                .. dropdownchoose2
        elseif dropdownchoose == 2 then
            dropdownchoose2 = tostring(
                (
                    dungeonFunctions['GemDungeon']
                    and dungeonFunctions['GemDungeon']()
                ) or '0'
            )
            chooselevels.Text = '当前选择：灵石地下城,  钥匙：'
                .. Gem_Dungeonkey
                .. '  ,关卡选择：'
                .. dropdownchoose2
        elseif dropdownchoose == 3 then
            dropdownchoose2 = tostring(
                (
                    dungeonFunctions['RuneDungeon']
                    and dungeonFunctions['RuneDungeon']()
                ) or '0'
            )
            chooselevels.Text = '当前选择：符石地下城,  钥匙：'
                .. Rune_Dungeonkey
                .. '  ,关卡选择：'
                .. dropdownchoose2
        elseif dropdownchoose == 4 then
            dropdownchoose2 = tostring(
                (
                    dungeonFunctions['RelicDungeon']
                    and dungeonFunctions['RelicDungeon']()
                ) or '0'
            )
            chooselevels.Text = '当前选择：遗物地下城,  钥匙：'
                .. Relic_Dungeonkey
                .. '  ,关卡选择：'
                .. dropdownchoose2
        elseif dropdownchoose == 7 then
            dropdownchoose2 = tostring(
                (
                    dungeonFunctions['HoverDungeon']
                    and dungeonFunctions['HoverDungeon']()
                ) or '0'
            )
            chooselevels.Text = '当前选择：悬浮地下城,  钥匙：'
                .. Hover_Dungeonkey
                .. '  ,关卡选择：'
                .. dropdownchoose2
        elseif dropdownchoose == 6 then
            dropdownchoose2 = tostring(
                (
                    dungeonFunctions['GoldDungeon']
                    and dungeonFunctions['GoldDungeon']()
                ) or '0'
            )
            chooselevels.Text = '当前选择：金币地下城,  钥匙：'
                .. Gold_Dungeonkey
                .. '  ,关卡选择：'
                .. dropdownchoose2
        elseif dropdownchoose == 5 then
            chooselevels.Text = '当前选择：活动地下城  未开启'
        elseif dropdownchoose == 8 then
            chooselevels.Text = '此为占位符号无任何效果'
        end
    end
    local function UDPDungeonchoose()
        checkDungeonkey()
        Dungeon1.Text = '            矿石地下城   钥匙：'
            .. Ore_Dungeonkey
            .. '            '
        Dungeon2.Text = '            灵石地下城   钥匙：'
            .. Gem_Dungeonkey
            .. '            '
        Dungeon3.Text = '            符石地下城   钥匙：'
            .. Rune_Dungeonkey
            .. '            '
        Dungeon4.Text = '            遗物地下城   钥匙：'
            .. Relic_Dungeonkey
            .. '            '
        Dungeon5.Text = '            悬浮地下城   钥匙：'
            .. Hover_Dungeonkey
            .. '            '
        Dungeon6.Text = '            金币地下城   钥匙：'
            .. Gold_Dungeonkey
            .. '            '
        Dungeon7.Text = '            活动地下城   未开启            '
    end
    task.spawn(function()
        while true do
            pcall(function()
                UDPDungeonchoose()
                UDPDungeontext()
            end)
            task.wait(0.5)
        end
    end)
    local updDungeonuiSwitch = features3:AddSwitch(
        '同步地下城进入介面的难度',
        function(bool)
            updDungeonui = bool
        end
    )
    safeSetControl(updDungeonuiSwitch, false, 'updDungeonuiSwitch')
    local function updateDungeonLevel(dungeonName, dataField, newLevel)
        JsonHandler.updatePlayerData(
            filePath,
            player.Name,
            { [dataField] = newLevel }
        )
        updateDungeonFunctions()
        print(
            '更新后的 ' .. dungeonName .. ' 等级:',
            dungeonFunctions[dungeonName]()
        )
    end
    local function adjustDungeonLevel(adjustment)
        local newLevel = dropdownchoose2 + adjustment
        local dungeonMapping = {
            [1] = { name = 'OreDungeon', field = 'OreDungeonMaxLevel' },
            [2] = { name = 'GemDungeon', field = 'GemDungeonMaxLevel' },
            [3] = { name = 'RuneDungeon', field = 'RuneDungeonMaxLevel' },
            [4] = { name = 'RelicDungeon', field = 'RelicDungeonMaxLevel' },
            [7] = { name = 'HoverDungeon', field = 'HoverDungeonMaxLevel' },
            [6] = { name = 'GoldDungeon', field = 'GoldDungeonMaxLevel' },
        }
        local dungeon = dungeonMapping[dropdownchoose]
        if dungeon then
            updateDungeonLevel(dungeon.name, dungeon.field, newLevel)
        else
            print('未选择地下城')
        end
    end
    local function DungeonTP()
        local dropdownTP = tonumber(dropdownchoose2)
        local args = { [1] = dropdownchoose, [2] = dropdownTP }
        PathCache.Dungeon
            :FindFirstChild('\232\191\155\229\133\165\229\137\175\230\156\172')
            :FireServer(unpack(args))
    end
    local dungeonList = {
        'Ore Dungeon',
        'Gem Dungeon',
        'Rune Dungeon',
        'Relic Dungeon',
        'Hover Dungeon',
        'Gold Dungeon',
    }
    local dungeonKeys = {
        ['Ore Dungeon'] = 'OreDungeon',
        ['Gem Dungeon'] = 'GemDungeon',
        ['Rune Dungeon'] = 'RuneDungeon',
        ['Relic Dungeon'] = 'RelicDungeon',
        ['Hover Dungeon'] = 'HoverDungeon',
        ['Gold Dungeon'] = 'GoldDungeon',
    }
    local function getDungeonWithMostKeys()
        local maxKeys = 0
        local bestDungeon = nil
        local bestDropdownIndex = 1
        local dropdownMapping = { 1, 2, 3, 4, 7, 6 }
        for i, name in ipairs(dungeonList) do
            local keyCount = tonumber(getDungeonKey(dungeonKeys[name])) or 0
            if keyCount > maxKeys then
                maxKeys = keyCount
                bestDungeon = name
                bestDropdownIndex = dropdownMapping[i] or 0
            end
        end
        return bestDungeon, bestDropdownIndex
    end
    local function selectDungeonWithMostKeys()
        local bestDungeon, bestDropdownIndex = getDungeonWithMostKeys()
        dropdownchoose = bestDropdownIndex
        local dungeonName = bestDungeon
        local dungeonLevel =
            tostring(dungeonFunctions[dungeonKeys[dungeonName]]() or '0')
        print('已选择最多钥匙的地下城：' .. dungeonName)
        task.wait(0.4)
        DungeonTP()
    end
    local function CheckDungeonVictory()
        local success, result = pcall(function()
            local victoryUI = playerGui.GUI
                :WaitForChild('主界面')
                :WaitForChild('战斗')
                :WaitForChild('胜利结果')
            return victoryUI.Visible and victoryUI.Text == 'Victory'
        end)
        return success and result
    end

    local function ClearVictoryUI()
        pcall(function()
            playerGui.GUI
                :WaitForChild('主界面')
                :WaitForChild('战斗')
                :WaitForChild('胜利结果').Text =
                ''
        end)
    end

    -- 检测是否在复活点
    local function IsAtRespawnPoint()
        local char = player.Character
        if char and char:FindFirstChild('HumanoidRootPart') then
            local hrp = char.HumanoidRootPart
            local distance = (hrp.Position - Vector3.new(TPX, TPY, TPZ)).Magnitude
            return distance < 5 -- 5 格以内算到达复活点
        end
        return false
    end

    local function AutostartDungeonf()
        -- Phase 1: 检查胜利
        local victoryFound = false
        local waitStart = os.time()
        while not victoryFound and (os.time() - waitStart < 30) do
            victoryFound = CheckDungeonVictory()
            if not victoryFound then
                -- 新增：检查是否在复活点
                if IsAtRespawnPoint() then
                    print('检测到回到复活点，自动开始地下城')
                    DungeonTP()
                    return true
                end
                task.wait(0.5)
            end
        end

        -- Phase 2: 胜利逻辑（原有）
        if victoryFound then
            local currentKeys = 0
            local dungeonName = 'Unknown'
            pcall(function()
                local levelText = playerGui.GUI
                    :WaitForChild('主界面')
                    :WaitForChild('战斗')
                    :WaitForChild('关卡信息')
                    :WaitForChild('文本').Text
                dungeonName = string.match(levelText, '^(.-)%s%d') or 'Unknown'
                local keyType = ({
                    ['Ore Dungeon'] = 'OreDungeon',
                    ['Gem Dungeon'] = 'GemDungeon',
                    ['Rune Dungeon'] = 'RuneDungeon',
                    ['Relic Dungeon'] = 'RelicDungeon',
                    ['Hover Dungeon'] = 'HoverDungeon',
                    ['Gold Dungeon'] = 'GoldDungeon',
                })[dungeonName]
                if keyType then
                    currentKeys = tonumber(getDungeonKey(keyType)) or 0
                end
            end)

            if AutoDungeonplus1 then
                adjustDungeonLevel(1)
                task.wait(1)
            end

            ClearVictoryUI()
            wait(savemodetime2)
            teleporthome()
            task.wait(0.5)

            if Autofinishdungeon and currentKeys == 0 then
                print('自动切换到钥匙最多的地下城')
                selectDungeonWithMostKeys()
            else
                DungeonTP()
            end
        end
    end

    local AutostartDungeonSwitch = features3:AddSwitch(
        '战斗结束后自动开始(纯胜利检测)',
        function(bool)
            AutostartDungeon = bool
            if AutostartDungeon then
                task.spawn(function()
                    while AutostartDungeon do
                        local actionTaken = AutostartDungeonf()
                        -- Only wait longer if no action was taken
                        task.wait(actionTaken and 0.1 or 0.5)
                    end
                end)
            end
        end
    )
    safeSetControl(
        AutostartDungeonSwitch,
        false,
        'AutostartDungeonSwitch'
    )

    local AutoDungeonplus1Switch = features3:AddSwitch(
        '战斗结束关卡数自动+1',
        function(bool)
            AutoDungeonplus1 = bool
        end
    )
    safeSetControl(
        AutoDungeonplus1Switch,
        false,
        'AutoDungeonplus1Switch'
    )
    local AutofinishdungeonSwitch = features3:AddSwitch(
        '完成所有地下城(当没有钥匙会自动跳转到最高钥匙的)--测试',
        function(bool)
            Autofinishdungeon = bool
        end
    )
    safeSetControl(
        AutofinishdungeonSwitch,
        false,
        'AutofinishdungeonSwitch'
    )
    features3:AddTextBox('自订输入关卡', function(text)
        local dropdownchoose0 = string.gsub(text, '[^%d]', '')
        local dropdownchoose3 = tonumber(dropdownchoose0)
        if not dropdownchoose3 then
            dropdownchoose3 = 1
        end
        if dropdownchoose == 1 then
            local field = 'OreDungeonMaxLevel'
            JsonHandler.updateField(
                filePath,
                player.Name,
                field,
                dropdownchoose3
            )
            updateDungeonFunctions()
        elseif dropdownchoose == 2 then
            local field = 'GemDungeonMaxLevel'
            JsonHandler.updateField(
                filePath,
                player.Name,
                field,
                dropdownchoose3
            )
            updateDungeonFunctions()
        elseif dropdownchoose == 3 then
            local field = 'RuneDungeonMaxLevel'
            JsonHandler.updateField(
                filePath,
                player.Name,
                field,
                dropdownchoose3
            )
            updateDungeonFunctions()
        elseif dropdownchoose == 4 then
            local field = 'RelicDungeonMaxLevel'
            JsonHandler.updateField(
                filePath,
                player.Name,
                field,
                dropdownchoose3
            )
            updateDungeonFunctions()
        elseif dropdownchoose == 5 then
            local field = 'HoverDungeonMaxLevel'
            JsonHandler.updateField(
                filePath,
                player.Name,
                field,
                dropdownchoose3
            )
            updateDungeonFunctions()
        elseif dropdownchoose == 6 then
            local field = 'GoldDungeonMaxLevel'
            JsonHandler.updateField(
                filePath,
                player.Name,
                field,
                dropdownchoose3
            )
            updateDungeonFunctions()
        else
            print('未选择地下城')
        end
    end)
    features3:AddButton('关卡选择+1', function()
        adjustDungeonLevel(1)
    end)
    features3:AddButton('关卡选择-1', function()
        adjustDungeonLevel(-1)
    end)
    features3:AddButton('传送', function()
        DungeonTP()
    end)
    features4:AddButton('自动交易初始化', function()
        loadstring(
            game:HttpGet(
                'https://github.com/supleruckydior/test/raw/refs/heads/main/%E8%87%AA%E5%8A%A8%E4%BA%A4%E6%98%931.json'
            )
        )()
    end)
    features4:AddButton('自动交易初始化2', function()
        loadstring(
            game:HttpGet(
                'https://github.com/supleruckydior/test/raw/refs/heads/main/%E8%87%AA%E5%8A%A8%E4%BA%A4%E6%98%932.json'
            )
        )()
    end)
    AutoelixirSwitch = features4:AddSwitch('自动炼丹药', function(bool)
        Autoelixir = bool
        if Autoelixir then
            task.spawn(function()
                while Autoelixir do
                    pcall(function()
                        PathCache.Elixir:FindFirstChild('\229\136\182\228\189\156'):FireServer()
                    end)
                    task.wait(0.5)
                end
            end)
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
    local lotteryskill = playerGui.GUI
        :WaitForChild('二级界面')
        :WaitForChild('商店')
        :WaitForChild('背景')
        :WaitForChild('右侧界面')
        :WaitForChild('召唤')
        :WaitForChild('技能')
    local skilllevel =
        lotteryskill:WaitForChild('等级区域'):WaitForChild('值').text
    skilllevel = string.gsub(skilllevel, '%D', '')
    local skilllevel2 = lotteryskill
        :WaitForChild('等级区域')
        :WaitForChild('进度条')
        :WaitForChild('值')
        :WaitForChild('值').text
    skilllevel2 = string.match(skilllevel2, '(%d+)/')
    local lotteryweapon = playerGui.GUI
        :WaitForChild('二级界面')
        :WaitForChild('商店')
        :WaitForChild('背景')
        :WaitForChild('右侧界面')
        :WaitForChild('召唤')
        :WaitForChild('法宝')
    local weaponlevel =
        lotteryweapon:WaitForChild('等级区域'):WaitForChild('值').text
    weaponlevel = string.gsub(weaponlevel, '%D', '')
    local weaponlevel2 = lotteryweapon
        :WaitForChild('等级区域')
        :WaitForChild('进度条')
        :WaitForChild('值')
        :WaitForChild('值').text
    weaponlevel2 = string.match(weaponlevel2, '(%d+)/')
    local currency = player:WaitForChild('值'):WaitForChild('货币')
    local diamonds = currency:WaitForChild('钻石').value
    local sword_tickets = currency:WaitForChild('法宝抽奖券').value
    local skill_tickets = currency:WaitForChild('技能抽奖券').value
    local useDiamonds = false
    local Autolotteryspeed = 0.3
    local canstartticket = true
    local canstartticket2 = true
    local function fetchData()
        skilllevel =
            lotteryskill:WaitForChild('等级区域'):WaitForChild('值').text
        skilllevel2 = lotteryskill
            :WaitForChild('等级区域')
            :WaitForChild('进度条')
            :WaitForChild('值')
            :WaitForChild('值').text
        weaponlevel =
            lotteryweapon:WaitForChild('等级区域'):WaitForChild('值').text
        weaponlevel2 = lotteryweapon
            :WaitForChild('等级区域')
            :WaitForChild('进度条')
            :WaitForChild('值')
            :WaitForChild('值').text
        sword_tickets = currency:WaitForChild('法宝抽奖券').value
        skill_tickets = currency:WaitForChild('技能抽奖券').value
        diamonds = currency:WaitForChild('钻石').value
    end
    local function updData()
        fetchData()
        skilllevel = tonumber(string.match(skilllevel, '%d+'))
        skilllevel2 = tonumber(string.match(skilllevel2, '(%d+)/'))
        weaponlevel = tonumber(string.match(weaponlevel, '%d+'))
        weaponlevel2 = tonumber(string.match(weaponlevel2, '(%d+)/'))
    end
    local function useskill_ticket()
        if canstartticket then
            local args = { [1] = '\230\138\128\232\131\189', [2] = true }
            pcall(function()
                PathCache.Shop
                    :FindFirstChild('\229\143\172\229\148\164')
                    :FindFirstChild('\230\138\189\229\165\150')
                    :FireServer(unpack(args))
            end)
        end
    end
    local function usesword_ticket()
        if canstartticket2 then
            local args = { [1] = '\230\179\149\229\174\157', [2] = true }
            pcall(function()
                PathCache.Shop
                    :FindFirstChild('\229\143\172\229\148\164')
                    :FindFirstChild('\230\138\189\229\165\150')
                    :FireServer(unpack(args))
            end)
        end
    end
    local function Compareskilltickets()
        if skill_tickets < 8 then
            if useDiamonds and (diamonds >= ((8 - skill_tickets) * 50)) then
                local compare = 8 - skill_tickets
                useskill_ticket()
            else
            end
        else
            useskill_ticket()
        end
    end
    local function Compareweapentickets()
        if sword_tickets < 8 then
            if useDiamonds and (diamonds >= ((8 - sword_tickets) * 50)) then
                local compare = 8 - sword_tickets
                usesword_ticket()
            else
            end
        else
            usesword_ticket()
        end
    end
    local function Compareprogress()
        if skilllevel2 > weaponlevel2 then
            Compareweapentickets()
        elseif skilllevel2 < weaponlevel2 then
            Compareskilltickets()
        else
            Compareskilltickets()
            Compareweapentickets()
        end
    end
    local function Comparelevel()
        updData()
        if skilllevel > weaponlevel then
            Compareweapentickets()
        elseif skilllevel < weaponlevel then
            Compareskilltickets()
        else
            Compareprogress()
        end
    end
    features4:AddLabel(
        '??同步抽取，抽奖券不足就会停止，请开启钻石抽取'
    )
    local lotterynum = features4:AddLabel(
        '法宝抽奖券： '
            .. sword_tickets
            .. '    技能抽奖券： '
            .. skill_tickets
    )
    local function updateExtractedValues()
        local sword_ticketslable =
            currency:WaitForChild('法宝抽奖券').value
        local skill_ticketslable =
            currency:WaitForChild('技能抽奖券').value
        lotterynum.Text = '法宝抽奖券： '
            .. sword_ticketslable
            .. '    技能抽奖券： '
            .. skill_ticketslable
    end
    task.spawn(function()
        while true do
            updateExtractedValues()
            task.wait(1)
        end
    end)
    local AutolotterySwitch = features4:AddSwitch(
        '自动抽法宝/技能',
        function(bool)
            Autolottery = bool
            if Autolottery then
                canstartticket = true
                canstartticket2 = true
                while Autolottery do
                    Comparelevel()
                    wait(Autolotteryspeed)
                    task.wait(0.4)
                end
            else
                canstartticket = false
                canstartticket2 = false
            end
        end
    )
    safeSetControl(AutolotterySwitch, false, 'AutolotterySwitch')
    local USEDiamondSwitch = features4:AddSwitch(
        '启用钻石抽取',
        function(bool)
            useDiamonds = bool
        end
    )
    safeSetControl(USEDiamondSwitch, false, 'USEDiamondSwitch')
    -- 定义执行函数
    local function ExecuteSettingsClose()
        local targetGui = PathCache.GUI.Secondary['\232\174\190\231\189\174']['\232\131\140\230\153\175']['\232\174\190\231\189\174\229\140\186\229\159\159']['\233\159\179\228\185\144\232\174\190\231\189\174\233\161\185']['\229\188\128\229\133\179']['\229\137\141\230\153\175']

        if targetGui.Visible then
            local argsList = {
                '\233\159\179\228\185\144',
                '\231\178\146\229\173\144\231\137\185\230\149\136',
                '\228\188\164\229\174\179\230\152\190\231\164\186',
                '\230\142\137\232\144\189\229\138\168\231\148\187',
                '\233\159\179\230\149\136',
                '\230\138\189\229\165\150\229\138\168\231\148\187',
                '\230\179\149\229\174\157\229\138\168\231\148\187',
                '\229\135\186\229\148\174\228\186\140\230\172\161\231\161\174\232\174\164',
            }

            local remotePath = PathCache.Events
                :FindFirstChild('\232\174\190\231\189\174')
                :FindFirstChild(
                    '\231\142\169\229\174\182\228\191\174\230\148\185\232\174\190\231\189\174'
                )

            if remotePath then
                for _, args in ipairs(argsList) do
                    pcall(function()
                        remotePath:FireServer(args)
                    end)
                end
            end
        end
    end

    -- 启动时自动执行一次
    ExecuteSettingsClose()

    -- 添加按钮功能
    features4:AddButton('关闭设置', ExecuteSettingsClose)
    local AutoupdFlyingSwordSwitch = features5:AddSwitch(
        '升级飞剑',
        function(bool)
            AutoupdFlyingSword = bool
            if AutoupdFlyingSword then
                task.spawn(function()
                    while AutoupdFlyingSword do
                        pcall(function()
                            PathCache.FlyingSword:FindFirstChild('\229\141\135\231\186\167'):FireServer()
                        end)
                        task.wait(0.2)
                    end
                end)
            end
        end
    )
    safeSetControl(
        AutoupdFlyingSwordSwitch,
        false,
        'AutoupdFlyingSwordSwitch'
    )
    local AutoupdskillSwordSwitch = features5:AddSwitch(
        '升级法宝/技能',
        function(bool)
            AutoupdskillSword = bool
            if AutoupdskillSword then
                task.spawn(function()
                    while AutoupdskillSword do
                        pcall(function()
                            PathCache.Weapon:FindFirstChild('\229\141\135\231\186\167\229\133\168\233\131\168\230\179\149\229\174\157'):FireServer()
                            PathCache.Skill:FindFirstChild('\229\141\135\231\186\167\229\133\168\233\131\168\230\138\128\232\131\189'):FireServer()
                        end)
                        task.wait(1.5)
                    end
                end)
            end
        end
    )
    safeSetControl(
        AutoupdskillSwordSwitch,
        false,
        'AutoupdskillSwordSwitch'
    )
    local AutoupdRuneSwordSwitch = features5:AddSwitch(
        '升级符石',
        function(bool)
            AutoupdRuneSwordSwitch = bool
            if AutoupdRuneSwordSwitch then
                task.spawn(function()
                    while AutoupdRuneSwordSwitch do
                        pcall(function()
                            PathCache.Rune:FindFirstChild('\229\141\135\231\186\167'):FireServer()
                        end)
                        task.wait(0.2)
                    end
                end)
            end
        end
    )
    safeSetControl(
        AutoupdRuneSwordSwitch,
        false,
        'AutoupdRuneSwordSwitch'
    )
    local Guidename = playerGui.GUI
        :WaitForChild('二级界面')
        :WaitForChild('公会')
        :WaitForChild('背景')
        :WaitForChild('右侧界面')
        :WaitForChild('主页')
        :WaitForChild('介绍')
        :WaitForChild('名称')
        :WaitForChild('文本')
        :WaitForChild('文本').Text
    local Donatetimes = playerGui.GUI
        :WaitForChild('二级界面')
        :WaitForChild('公会')
        :WaitForChild('捐献')
        :WaitForChild('背景')
        :WaitForChild('按钮')
        :WaitForChild('确定按钮')
        :WaitForChild('次数').Text
    local Donatetimesnumber = tonumber(string.match(Donatetimes, '%d+'))
    local Guildname = features5:AddLabel(
        '公会名称：未获取点击更新公会'
            .. ' 剩余贡献次数： '
            .. Donatetimesnumber
    )
    features5:AddButton('更新公会', function()
        Donatetimes = playerGui.GUI
            :WaitForChild('二级界面')
            :WaitForChild('公会')
            :WaitForChild('捐献')
            :WaitForChild('背景')
            :WaitForChild('按钮')
            :WaitForChild('确定按钮')
            :WaitForChild('次数').Text
        Donatetimesnumber = tonumber(string.match(Donatetimes, '%d+'))
        local event = Services.ReplicatedStorage:FindFirstChild('打开公会', true)
        if event then
            event:Fire('打开公会')
        end
        Guildname.Text = '公会名称：'
            .. Guidename
            .. ' 剩余贡献次数： '
            .. Donatetimesnumber
    end)
    local DonationUI =
        playerGui.GUI:WaitForChild('二级界面'):WaitForChild('公会')
    local DonateButton = DonationUI:WaitForChild('捐献')
        :WaitForChild('背景')
        :WaitForChild('按钮')
        :WaitForChild('确定按钮')
    local DonationEvent = PathCache.Guild:WaitForChild('\230\141\144\231\140\174')

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
        Guildname.Text = ('公会名称：%s 剩余贡献次数：%d'):format(
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
    local AutoDonateSwitch = features5:AddSwitch(
        '自动捐献',
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
            safeSetControl(AutoDonateSwitch, true, 'AutoDonateSwitch')
        end
    end)

    local herbController = {
        enabled = false,
        interval = 0.2,
        maxAttempts = 5,
        currentAttempts = 0,
        highCostMode = false,
    }

    -- 数值获取函数（使用Utils.parseNumber）
    local function getDiamond()
        return Utils.parseNumber(
            playerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159']['\233\146\187\231\159\179']['\230\140\137\233\146\174']['\229\128\188'].Text
        )
    end

    local function getGuildCoin()
        return Utils.parseNumber(
            playerGui.GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154']['\232\131\140\230\153\175']['\229\143\179\228\190\167\231\149\140\233\157\162']['\229\149\134\229\186\151']['\229\133\172\228\188\154\229\184\129']['\230\140\137\233\146\174']['\229\128\188'].Text
        )
    end

    local function getRefreshCost()
        return Utils.parseNumber(
            playerGui.GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154']['\232\131\140\230\153\175']['\229\143\179\228\190\167\231\149\140\233\157\162']['\229\149\134\229\186\151']['\229\136\183\230\150\176']['\230\140\137\233\146\174']['\229\128\188'].Text
        )
    end

    -- 界面控制函数
    local function toggleGuildUI(state)
        pcall(function()
            PathCache.GUI.Secondary['\229\133\172\228\188\154'].Visible = state
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
            local guilditemlist = PathCache.GUI.Secondary['\229\133\172\228\188\154']['\232\131\140\230\153\175']['\229\143\179\228\190\167\231\149\140\233\157\162']['\229\149\134\229\186\151']['\229\136\151\232\161\168']

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
                            PathCache.Guild:FindFirstChild('\229\133\145\230\141\162'):FireServer(slotIndex - 2)
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
                    -- 使用路径缓存优化
                    local elixirUI = Services.ReplicatedStorage:FindFirstChild('\228\186\139\228\187\182', true)
                        :FindFirstChild('\229\174\162\230\136\183\231\171\175', true)
                    if elixirUI then
                        elixirUI:FindFirstChild('\229\174\162\230\136\183\231\171\175UI'):FindFirstChild('\230\137\147\229\188\128\229\133\172\228\188\154'):Fire()
                        task.wait(0.5)
                        PathCache.Guild:FindFirstChild('\229\136\183\230\150\176\229\133\172\228\188\154\229\149\134\229\186\151'):FireServer()
                    end
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
    local Autoguildshop = features5:AddSwitch(
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
            safeSetControl(Autoguildshop, true, 'Autoguildshop')
        end
    end)

    features5:AddButton('解锁世界', function()
        pcall(function()
            local forgeEvent = PathCache.Forge:FindFirstChild('\232\167\163\233\148\129\229\187\186\231\173\145')
            for i = 1, 30 do
                forgeEvent:FireServer(i)
            end
            task.wait(1)
            for i = 1, 30 do
                local args = { [1] = 1 }
                PathCache.Activity:FindFirstChild('\232\180\173\228\185\176'):FireServer(unpack(args))
            end
            task.wait(1)
            for i = 1, 40 do
                local args = { [1] = 12 }
                PathCache.Activity:FindFirstChild('\232\180\173\228\185\176'):FireServer(unpack(args))
            end
        end)
    end)

    features5:AddButton('解除装备', function()
        pcall(function()
            for i = 1, 5 do
                PathCache.Rune:FindFirstChild('\229\141\184\228\184\139'):FireServer(i)
                PathCache.WorldCore:FindFirstChild('\229\141\184\228\184\139'):FireServer(i)
            end
        end)
    end)

    -- UI开启功能（使用Services缓存）
    features6:AddButton('开启每日任务', function()
        local event = Services.ReplicatedStorage:FindFirstChild('打开每日任务', true)
        if event and event:IsA('BindableEvent') then
            event:Fire('打开每日任务')
        end
    end)
    features6:AddButton('开启邮件', function()
        local event = Services.ReplicatedStorage:FindFirstChild('打开邮件', true)
        if event and event:IsA('BindableEvent') then
            event:Fire('打开邮件')
        end
    end)
    features6:AddButton('开启转盘', function()
        local event = Services.ReplicatedStorage:FindFirstChild('打开转盘', true)
        if event and event:IsA('BindableEvent') then
            event:Fire('打开转盘')
        end
    end)
    features6:AddButton('开启阵法', function()
        local event = Services.ReplicatedStorage:FindFirstChild('打开阵法', true)
        if event and event:IsA('BindableEvent') then
            event:Fire('打开阵法')
        end
    end)
    features6:AddButton('开启世界树', function()
        local event = Services.ReplicatedStorage:FindFirstChild('打开世界树', true)
        if event and event:IsA('BindableEvent') then
            event:Fire('打开世界树')
        end
    end)
    features6:AddButton('开启练器台', function()
        local event = Services.ReplicatedStorage:FindFirstChild('打开炼器台', true)
        if event and event:IsA('BindableEvent') then
            event:Fire('打开练器台')
        end
    end)
    features6:AddButton('开启炼丹炉', function()
        local event = Services.ReplicatedStorage:FindFirstChild('打开炼丹炉', true)
        if event and event:IsA('BindableEvent') then
            event:Fire('打开炼丹炉')
        end
    end)
    features6:AddButton('每月钥匙购买', function()
        pcall(function()
            local remote = PathCache.Activity:FindFirstChild("\232\180\173\228\185\176")
            if remote then
                for i = 1, 60 do
                    for arg = 4, 9 do
                        remote:FireServer(arg)
                    end
                end
                for i = 1, 30 do
                    for arg = 17, 22 do
                        remote:FireServer(arg)
                    end
                end
            end
        end)
    end)
    features6:AddButton('每星期竞技场水滴购买', function()
        pcall(function()
            for i = 1, 15 do
                local args = {
                    4
                }
                game:GetService("ReplicatedStorage"):WaitForChild("\228\186\139\228\187\182"):WaitForChild("\229\133\172\231\148\168"):WaitForChild("\231\171\158\230\138\128\229\156\186"):WaitForChild("\232\180\173\228\185\176"):FireServer(unpack(args))
            end
        end)
    end)

    features7:AddLabel(' -- 语言配置/language config')
    features7:AddButton('删除语言配置/language config delete', function()
        local HttpService = game:GetService('HttpService')
        function deleteConfigFile()
            if isfile('Cultivation_languageSet.json') then
                delfile('Cultivation_languageSet.json')
                print('配置文件 Cultivation_languageSet.json 已删除。')
            else
                print(
                    '配置文件 Cultivation_languageSet.json 不存在，无法删除。'
                )
            end
        end
        deleteConfigFile()
    end)
    features7:AddLabel(' - - 统计')
    features7:AddButton('每秒击杀/金币数', function()
        loadstring(
            game:HttpGet(
                'https://github.com/supleruckydior/test/raw/refs/heads/main/%E9%87%91%E5%B8%81.json'
            )
        )()
    end)
    features7:AddLabel(' 有任何问题或想法请在Github上留言')
    features7:AddButton('Github连结', function()
        local urlToCopy = 'https://github.com/Tseting-nil'
        if setclipboard then
            setclipboard(urlToCopy)
            showNotification('连结以复制！')
        else
            showNotification('错误！连结为：github.com/Tseting-nil')
        end
    end)

    local UI_LOAD_DELAY = 0.03
    local RETRY_COUNT = 3

    -- 初始化界面
    local Farm_choose = features8:AddLabel('  正在初始化...')
    local currentFarm = 1
    local targetLevel = 80
    local lastFarmLevel = 0

    -- 炼丹炉初始化
    local Elixir_choose = features8:AddLabel('  正在初始化炼丹炉...')
    local currentElixir = 1
    local targetElixirLevel = 80
    local lastElixirLevel = 0

    -- 共用事件路径
    -- 农田和炼丹炉事件（使用路径缓存）
    local FARM_UPGRADE_EVENT = PathCache.Farm:WaitForChild('\229\141\135\231\186\167')
    local ELIXIR_UPGRADE_EVENT = PathCache.Elixir:WaitForChild('\229\141\135\231\186\167')

    -- 等级获取函数
    local function GetLevel(path)
        local finalLevel = 0
        for _ = 1, RETRY_COUNT do
            local success, result = pcall(function()
                return PathCache.GUI.Secondary[path]['\232\131\140\230\153\175']['\229\177\158\230\128\167\229\140\186\229\159\159']['\229\177\158\230\128\167\229\136\151\232\161\168']['\229\136\151\232\161\168']['\231\173\137\231\186\167']['\229\128\188']
            end)
            if success and result then
                finalLevel = tonumber(result.Text:match('%d+')) or 0
                break
            end
            task.wait(UI_LOAD_DELAY)
        end
        return finalLevel
    end

    -- 药田显示更新
    local function UpdateFarmDisplay()
        Farm_choose.Text = string.format(
            '  当前选择 农田：%d  等级：%d  目标：%d',
            currentFarm,
            lastFarmLevel,
            targetLevel
        )
    end

    -- 炼丹炉显示更新
    local function UpdateElixirDisplay()
        Elixir_choose.Text = string.format(
            '  当前选择 丹炉：%d  等级：%d  目标：%d',
            currentElixir,
            lastElixirLevel,
            targetElixirLevel
        )
    end

    -- 药田等级刷新
    local function UpdateFarmLevel()
        task.spawn(function()
            Farm_choose.Text =
                string.format('  农田%d ? 读取中...', currentFarm)
            local newLevel = GetLevel('\229\134\156\231\148\176')
            lastFarmLevel = newLevel

            for i = 1, 5 do
                Farm_choose.Text = string.format(
                    '  农田%d ? 当前等级：%d',
                    currentFarm,
                    math.floor(
                        lastFarmLevel + (newLevel - lastFarmLevel) * (i / 5)
                    )
                )
                task.wait(UI_LOAD_DELAY)
            end
            UpdateFarmDisplay()
        end)
    end

    -- 炼丹炉等级刷新
    local function UpdateElixirLevel()
        task.spawn(function()
            Elixir_choose.Text =
                string.format('  丹炉%d ? 读取中...', currentElixir)
            local newLevel = GetLevel('\231\130\188\228\184\185\231\130\137')
            lastElixirLevel = newLevel

            for i = 1, 5 do
                Elixir_choose.Text = string.format(
                    '  丹炉%d ? 当前等级：%d',
                    currentElixir,
                    math.floor(
                        lastElixirLevel + (newLevel - lastElixirLevel) * (i / 5)
                    )
                )
                task.wait(UI_LOAD_DELAY)
            end
            UpdateElixirDisplay()
        end)
    end

    -- 药田选择系统
    local Farm_selection = features8:AddDropdown('选择农田', function(text)
        currentFarm = tonumber(text:match('%d')) or 1
        pcall(function()
            local openEvent = Services.ReplicatedStorage:FindFirstChild('打开农田', true)
            if openEvent and openEvent:IsA('BindableEvent') then
                openEvent:Fire(currentFarm)
                task.wait(UI_LOAD_DELAY * 2)
            end
        end)
        UpdateFarmLevel()
    end)

    for i = 1, 5 do
        Farm_selection:Add('农田' .. i)
    end

    -- 药田等级控制
    features8:AddButton('▲ 提升农田目标', function()
        targetLevel = math.min(200, targetLevel + 1)
        UpdateFarmDisplay()
    end)

    features8:AddButton('▼ 降低农田目标', function()
        targetLevel = math.max(0, targetLevel - 1)
        UpdateFarmDisplay()
    end)
    local isWorkingFarm = false
    features8:AddButton('? 农田超频 (精准版)', function()
        isWorkingFarm = not isWorkingFarm
        task.spawn(function()
            if isWorkingFarm then
                local originalTarget = targetLevel
                Farm_choose.Text = '  ? 计算强化次数中...'

                pcall(function()
                    for farmIndex = 1, 5 do
                        if not isWorkingFarm then
                            break
                        end

                        -- 切换农田
                        currentFarm = farmIndex
                        local openEvent = Services.ReplicatedStorage:FindFirstChild('打开农田', true)
                        if openEvent and openEvent:IsA('BindableEvent') then
                            openEvent:Fire(farmIndex)
                            task.wait(0.1) -- 确保UI切换
                        end

                        -- 获取当前等级
                        local currentLevel =
                            GetLevel('\229\134\156\231\148\176')
                        if currentLevel >= targetLevel then
                            Farm_choose.Text = string.format(
                                '  ? 农田%d已达标 (%d级)',
                                farmIndex,
                                currentLevel
                            )
                            task.wait(0.05)
                        end

                        -- 计算需要强化的次数
                        local neededUpgrades = targetLevel - currentLevel
                        Farm_choose.Text = string.format(
                            '  ? 农田%d将强化 %d次 (%d→%d)',
                            farmIndex,
                            neededUpgrades,
                            currentLevel,
                            targetLevel
                        )

                        -- 分批发送请求 (每10次一组，组间隔0.05秒)
                        local BATCH_SIZE = 10
                        for i = 1, neededUpgrades do
                            if not isWorkingFarm then
                                break
                            end

                            pcall(
                                FARM_UPGRADE_EVENT.FireServer,
                                FARM_UPGRADE_EVENT,
                                farmIndex
                            )

                            -- 分批处理
                            if i % BATCH_SIZE == 0 then
                                task.wait(0.05)
                                Farm_choose.Text = string.format(
                                    '  ? 农田%d: %d/%d次 (%.1f%%)',
                                    farmIndex,
                                    i,
                                    neededUpgrades,
                                    (i / neededUpgrades) * 100
                                )
                            end
                        end

                        -- 最终确认
                        local finalLevel = GetLevel('\229\134\156\231\148\176')
                        Farm_choose.Text = string.format(
                            '  ? 农田%d完成 %d级 (实际+%d级)',
                            farmIndex,
                            finalLevel,
                            finalLevel - currentLevel
                        )
                        task.wait(0.1)
                    end

                    Farm_choose.Text = '  ? 所有农田强化完毕'
                    currentFarm = 1
                    local openEvent = Services.ReplicatedStorage:FindFirstChild('打开农田', true)
                    if openEvent and openEvent:IsA('BindableEvent') then
                        openEvent:Fire(currentFarm)
                    end
                end)

                isWorkingFarm = false
                UpdateFarmDisplay()
            end
        end)
    end)

    -- 炼丹炉选择系统
    local Elixir_selection = features8:AddDropdown(
        '选择丹炉',
        function(text)
            currentElixir = tonumber(text:match('%d')) or 1
            pcall(function()
                game:GetService('ReplicatedStorage')['\228\186\139\228\187\182']['\229\174\162\230\136\183\231\171\175']['\229\174\162\230\136\183\231\171\175UI']['\230\137\147\229\188\128\231\130\188\228\184\185\231\130\137']
                    :Fire()
                wait(UI_LOAD_DELAY * 2)
            end)
            UpdateElixirLevel()
        end
    )
    Elixir_selection:Add('丹炉1')

    -- 炼丹炉等级控制
    features8:AddButton('▲ 提升丹炉目标', function()
        targetElixirLevel = math.min(1000, targetElixirLevel + 1)
        UpdateElixirDisplay()
    end)

    features8:AddButton('▼ 降低丹炉目标', function()
        targetElixirLevel = math.max(0, targetElixirLevel - 1)
        UpdateElixirDisplay()
    end)

    -- 炼丹炉超频模式
    features8:AddButton('? 丹炉超频 (精准版)', function()
        local isWorkingElixir = not isWorkingElixir
        task.spawn(function()
            if isWorkingElixir then
                Elixir_choose.Text = '  ? 计算丹炉强化次数中...'

                pcall(function()
                    -- 开启丹炉界面
                    game:GetService('ReplicatedStorage')['\228\186\139\228\187\182']['\229\174\162\230\136\183\231\171\175']['\229\174\162\230\136\183\231\171\175UI']['\230\137\147\229\188\128\231\130\188\228\184\185\231\130\137']
                        :Fire()
                    task.wait(0.1) -- 基础UI等待

                    -- 获取当前等级
                    local currentLevel =
                        GetLevel('\231\130\188\228\184\185\231\130\137')
                    if currentLevel >= targetElixirLevel then
                        Elixir_choose.Text = string.format(
                            '  ? 丹炉已达标 (%d级)',
                            currentLevel
                        )
                        isWorkingElixir = false
                        return
                    end

                    -- 计算需要强化的次数
                    local neededUpgrades = targetElixirLevel - currentLevel
                    Elixir_choose.Text = string.format(
                        '  ? 需要强化 %d次 (%d→%d)',
                        neededUpgrades,
                        currentLevel,
                        targetElixirLevel
                    )

                    -- 分批发送请求 (每15次一组，组间隔0.03秒)
                    local BATCH_SIZE = 15
                    for i = 1, neededUpgrades do
                        if not isWorkingElixir then
                            break
                        end

                        pcall(
                            ELIXIR_UPGRADE_EVENT.FireServer,
                            ELIXIR_UPGRADE_EVENT
                        )

                        -- 分批处理与进度更新
                        if i % BATCH_SIZE == 0 then
                            task.wait(0.03)
                            local nowLevel =
                                GetLevel('\231\130\188\228\184\185\231\130\137')
                            Elixir_choose.Text = string.format(
                                '  ? 进度: %d/%d次 (实际:%d级)',
                                i,
                                neededUpgrades,
                                nowLevel
                            )
                        end
                    end

                    -- 最终确认
                    local finalLevel =
                        GetLevel('\231\130\188\228\184\185\231\130\137')
                    Elixir_choose.Text = string.format(
                        '  ? 完成强化 (实际:%d级 提升:%d级)',
                        finalLevel,
                        finalLevel - currentLevel
                    )
                end)

                isWorkingElixir = false
            end
        end)
    end)

    task.defer(function()
        -- 获取当前玩家列表
        local players = game.Players:GetPlayers()
        local playerNames = {}
        for _, player in pairs(players) do
            table.insert(playerNames, player.Name)
        end

        -- 添加下拉控件
        local selectedPlayer = ''
        local dropdown = features9:AddDropdown(
            '选择玩家',
            function(selected)
                selectedPlayer = selected
            end
        )

        -- 手动管理选项列表
        local dropdownOptions = {}

        -- 将玩家名称添加到下拉控件中
        local function UpdateDropdown()
            -- 清空下拉菜单（通过移除每个选项）
            for _, option in pairs(dropdownOptions) do
                option:Remove()
            end
            dropdownOptions = {} -- 重置选项列表

            -- 重新添加玩家名称
            for _, name in pairs(playerNames) do
                local option = dropdown:Add(name)
                table.insert(dropdownOptions, option)
            end

            -- 在菜单最底部添加一个空白选项
            local blankOption = dropdown:Add('') -- 空白选项
            table.insert(dropdownOptions, blankOption)
        end

        -- 初始化下拉菜单
        UpdateDropdown()

        -- 监听玩家加入游戏的事件
        game.Players.PlayerAdded:Connect(function(player)
            table.insert(playerNames, player.Name)
            UpdateDropdown()
        end)

        -- 监听玩家离开游戏的事件
        game.Players.PlayerRemoving:Connect(function(player)
            for i, name in ipairs(playerNames) do
                if name == player.Name then
                    table.remove(playerNames, i)
                    break
                end
            end
            UpdateDropdown()
        end)

        local dungeonTeleportEvent = PathCache.Stage:FindFirstChild(
            '\232\191\155\229\133\165\229\188\128\229\144\175\228\184\173\229\133\179\229\141\161'
        )
        local dungeonTriggerEvent = PathCache.Combat:FindFirstChild(
            '\230\155\180\230\150\176\229\141\143\229\138\169\231\155\174\230\160\135'
        )
        local AUTO_DUNGEON_RANGE = 20
        local AUTO_DUNGEON_RETRY_INTERVAL = 1
        local AUTO_DUNGEON_MONITOR_INTERVAL = 0.5
        local AUTO_DUNGEON_LOST_TIMEOUT = 10
        local autoDungeonFollowEnabled = false
        local autoDungeonFollowThread
        local autoDungeonFollowSwitch

        local function getHumanoidRootPart(targetPlayer)
            local character = targetPlayer and targetPlayer.Character
            if not character then
                return nil
            end
            return character:FindFirstChild('HumanoidRootPart')
        end

        local function isTargetPlayerInRange(targetPlayer)
            local localRoot = getHumanoidRootPart(localPlayer)
            local targetRoot = getHumanoidRootPart(targetPlayer)
            if not localRoot or not targetRoot then
                return false
            end
            return (localRoot.Position - targetRoot.Position).Magnitude
                <= AUTO_DUNGEON_RANGE
        end

        local function requestDungeonTeleport(targetPlayer)
            if not dungeonTeleportEvent then
                warn('副本传送事件不存在')
                return false
            end
            local success, err = pcall(function()
                dungeonTeleportEvent:FireServer(targetPlayer)
            end)
            if not success then
                warn('副本传送失败: ' .. tostring(err))
            end
            return success
        end

        local function triggerDungeonEvent()
            if not dungeonTriggerEvent then
                warn('副本触发事件不存在')
                return false
            end
            local success, err = pcall(function()
                dungeonTriggerEvent:FireServer()
            end)
            if not success then
                warn('副本触发事件失败: ' .. tostring(err))
            end
            return success
        end

        local function stopAutoDungeonFollow()
            autoDungeonFollowEnabled = false
            if autoDungeonFollowThread then
                task.cancel(autoDungeonFollowThread)
                autoDungeonFollowThread = nil
            end
        end

        local function startAutoDungeonFollow()
            stopAutoDungeonFollow()
            autoDungeonFollowEnabled = true
            autoDungeonFollowThread = task.spawn(function()
                local state = 'seeking'
                local lostSince = nil
                local hasTriggeredCurrentLock = false
                local trackedPlayerName = nil

                while autoDungeonFollowEnabled do
                    if trackedPlayerName ~= selectedPlayer then
                        trackedPlayerName = selectedPlayer
                        state = 'seeking'
                        lostSince = nil
                        hasTriggeredCurrentLock = false
                    end

                    local targetPlayer = Services.Players:FindFirstChild(
                        selectedPlayer
                    )

                    if not targetPlayer then
                        state = 'seeking'
                        lostSince = nil
                        hasTriggeredCurrentLock = false
                        task.wait(AUTO_DUNGEON_RETRY_INTERVAL)
                    else
                        local inRange = isTargetPlayerInRange(targetPlayer)

                        if state == 'seeking' then
                            if inRange then
                                if not hasTriggeredCurrentLock then
                                    triggerDungeonEvent()
                                    hasTriggeredCurrentLock = true
                                end
                                state = 'monitoring'
                                lostSince = nil
                            else
                                hasTriggeredCurrentLock = false
                                requestDungeonTeleport(targetPlayer)
                            end
                            task.wait(AUTO_DUNGEON_RETRY_INTERVAL)
                        else
                            if inRange then
                                lostSince = nil
                            else
                                if not lostSince then
                                    lostSince = time()
                                elseif
                                    time() - lostSince
                                    >= AUTO_DUNGEON_LOST_TIMEOUT
                                then
                                    state = 'seeking'
                                    lostSince = nil
                                    hasTriggeredCurrentLock = false
                                end
                            end
                            task.wait(AUTO_DUNGEON_MONITOR_INTERVAL)
                        end
                    end
                end
            end)
        end

        autoDungeonFollowSwitch = features9:AddSwitch(
            '传送玩家到副本',
            function(bool)
                if bool then
                    if selectedPlayer == '' then
                        print('请先选择一个玩家')
                        task.defer(function()
                            if autoDungeonFollowSwitch then
                                safeSetControl(
                                    autoDungeonFollowSwitch,
                                    false,
                                    'autoDungeonFollowSwitch'
                                )
                            end
                        end)
                        return
                    end
                    startAutoDungeonFollow()
                else
                    stopAutoDungeonFollow()
                end
            end
        )
        safeSetControl(
            autoDungeonFollowSwitch,
            false,
            'autoDungeonFollowSwitch'
        )

        -- 添加第二个按钮
        features9:AddButton('触发事件', function()
            pcall(function()
                if dungeonTriggerEvent then
                    dungeonTriggerEvent:FireServer()
                end
            end)
        end)
    end)
    -- 使用已定义的Services和player（避免重复定义）
    local GUI = playerGui:WaitForChild('GUI')

    -- 全局控制变量
    local Autoelixir = false
    local hasExecutedTrade = false -- 确保自动交易只执行一次

    -- 获取草药数值
    -- 获取草药数值（使用Utils.parseNumber）
    local function getHerbValue()
        local herbText = '0'
        pcall(function()
            herbText = GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159\229\143\179']['\232\141\137\232\141\175']['\229\128\188'].Text
        end)
        return Utils.parseNumber(herbText)
    end

    -- 获取矿石数值（使用Utils.parseNumber）
    local function getOREValue()
        local OREText = '0'
        pcall(function()
            OREText = playerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159\229\143\179']['\231\159\191\231\159\179']['\229\128\188'].Text
        end)
        return Utils.parseNumber(OREText)
    end

    -- 炼丹循环
    local function startElixirLoop()
        Autoelixir = true
        while Autoelixir do
            pcall(function()
                PathCache.Elixir:FindFirstChild('\229\136\182\228\189\156'):FireServer()
            end)
            task.wait(0.2)
        end
    end

    -- 智能监控
    local herbprint = false
    local lowcontrol = false

    local function smartMonitor()
        while true do
            local currentHerbs = getHerbValue()
            local playerName = player.Name

            -- When herbs > 250k, execute trade script (once)
            if currentHerbs > 250000 and not hasExecutedTrade then
                herbprint = true
                lowcontrol = true -- Set lowcontrol flag when reaching high herbs

                pcall(function()
                    loadstring(
                        game:HttpGet(
                            'https://raw.githubusercontent.com/supleruckydior/test/refs/heads/main/%E8%87%AA%E5%8A%A8%E4%BA%A4%E6%98%932.json'
                        )
                    )()
                    hasExecutedTrade = true
                    print(
                        playerName
                            .. ' --- 自动交易脚本激活! ('
                            .. currentHerbs
                            .. '草药)'
                    )
                end)
                -- Start elixir loop if not already running
                if not Autoelixir then
                    task.spawn(startElixirLoop)
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

            task.wait(5)
        end
    end

    -- 初始化检查
    local farm5Level = 0
    local elixirLevel = 0

    -- 获取农田5等级
    pcall(function()
        farm5Level = tonumber(
            PathCache.GUI.Secondary['\229\134\156\231\148\176']['\232\131\140\230\153\175']['\229\177\158\230\128\167\229\140\186\229\159\159']['\229\177\158\230\128\167\229\136\151\232\161\168']['\229\136\151\232\161\168']['\231\173\137\231\186\167']['\229\128\188'].Text:match(
                '%d+'
            )
        ) or 0
    end)
    PathCache.GUI.Secondary['\229\134\156\231\148\176'].Visible = false

    -- 获取炼丹炉等级
    pcall(function()
        local elixirUI = Services.ReplicatedStorage
            :FindFirstChild('\228\186\139\228\187\182', true)
            :FindFirstChild('\229\174\162\230\136\183\231\171\175', true)
        if elixirUI then
            elixirUI['\229\174\162\230\136\183\231\171\175UI']['\230\137\147\229\188\128\231\130\188\228\184\185\231\130\137']:Fire()
            task.wait(0.5)
            elixirLevel = tonumber(
                PathCache.GUI.Secondary['\231\130\188\228\184\185\231\130\137']['\232\131\140\230\153\175']['\229\177\158\230\128\167\229\140\186\229\159\159']['\229\177\158\230\128\167\229\136\151\232\161\168']['\229\136\151\232\161\168']['\231\173\137\231\186\167']['\229\128\188'].Text:match(
                    '%d+'
                )
            ) or 0
        end
        PathCache.GUI.Secondary['\231\130\188\228\184\185\231\130\137'].Visible = false
    end)

    -- 主逻辑
    if farm5Level >= 80 and elixirLevel >= 80 then
        print('===== 系统启动 =====')
        print('农田5等级:', farm5Level)
        print('炼丹炉等级:', elixirLevel)
        print('初始草药量:', getHerbValue())
        print('==================')
    else
        print('条件不满足：需要农田5和炼丹炉等级≥80')
    end
    local valueText = PathCache.GUI.Secondary['\228\184\187\232\167\146']['\232\131\140\230\153\175']['\229\143\179\228\190\167\231\149\140\233\157\162']['\232\163\133\229\164\135']['\232\167\146\232\137\178']['\231\190\189\230\160\184']['\230\140\137\233\146\174']['\229\128\188'].text
    local RobloxUsername = player.Name

    -- Synapse HTTP Bypass (works even if HttpService is blocked)
    local Request = syn and syn.request or http and http.request or request

    local success, response = pcall(function()
        return Request({
            Url = webhookURL,
            Method = 'POST',
            Headers = {
                ['Content-Type'] = 'application/json',
            },
            Body = Services.HttpService:JSONEncode({
                content = RobloxUsername
                    .. ' | '
                    .. valueText
                    .. ' 羽核| '
                    .. getHerbValue()
                    .. ' 草药| '
                    .. getOREValue()
                    .. ' 矿石',
            }),
        })
    end)
    -- Function to safely check and fire
    local function CheckAndFire()
        pcall(function()
            local gui = PathCache.GUI.Secondary['\232\135\170\229\138\168\229\135\186\229\148\174\229\188\185\229\135\186\230\161\134']['\232\131\140\230\153\175']['\230\140\137\233\146\174']['\230\147\141\228\189\156\229\140\186\229\159\159']['\229\130\168\229\173\152']['\229\155\190\230\160\135']['\229\155\190\230\160\135']

            -- Check if exists and is invisible
            if gui and gui.Visible == false then
                local remote = PathCache.Elixir:FindFirstChild('\228\191\174\230\148\185\232\135\170\229\138\168\229\130\168\229\173\152')
                if remote then
                    remote:FireServer()
                    print('RemoteEvent fired successfully!')
                end
            end
        end)
    end
    -- Run once immediately
    CheckAndFire()
    -- Print results
    if success and response.Success then
        print('? Successfully sent username to webhook: ' .. RobloxUsername)
    else
        warn(
            '? Failed to send webhook | Error: '
                .. tostring(response.StatusCode or response)
        )
    end
else
    warn('当前游戏不是目标游戏，脚本未运行。')
end
