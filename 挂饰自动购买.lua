-- 挂饰自动购买脚本
-- 功能：持续扫描市场并自动购买符合条件的挂饰
-- 目标挂饰ID：1015(金币加成), 1011(暴击概率), 1016(经验加成)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- 目标挂饰ID列表
local TARGET_ACCESSORY_IDS = {1015, 1011, 1016}

-- 挂饰类型名称映射
local ACCESSORY_TYPE_NAMES = {
    [1015] = "金币加成",
    [1011] = "暴击概率",
    [1016] = "经验加成"
}

-- 品质名称映射
local QUALITY_NAMES = {
    [5] = "完美",
    [6] = "稀少",
    [7] = "史诗",
    [8] = "传奇",
    [9] = "不朽",
    [10] = "神话"
}

-- 价格限制配置（根据品质）
local PRICE_LIMITS = {
    [5] = 2000,    -- 完美
    [6] = 6000,    -- 稀少
    [7] = 17500,   -- 史诗
    [8] = 45000,   -- 传奇
    [9] = 115000,  -- 不朽
    [10] = 330000  -- 神话
}

-- 购买统计
local purchaseStats = {
    [1015] = 0,  -- 金币加成购买数量
    [1011] = 0,  -- 暴击概率购买数量
    [1016] = 0,  -- 经验加成购买数量
    total = 0    -- 总购买数量
}

-- 系统控制变量
local isRunning = false
local startTime = 0
local scanInterval = 0.1  -- 扫描间隔(秒)
local scanTimeout = 1  -- 扫描超时时间(秒)
local allPlayersData = {}
local currentPlayerIndex = 1
local isScanning = false
local currentScanPlayer = nil  -- 当前扫描的玩家
local scanStartTime = 0  -- 扫描开始时间
local lastReceivedPlayer = nil  -- 上次收到数据的玩家

-- 获取购买事件
local viewEvent = ReplicatedStorage:WaitForChild("事件"):WaitForChild("公用"):WaitForChild("露天商店"):WaitForChild("查看")
local buyItemEvent = ReplicatedStorage:WaitForChild("事件"):WaitForChild("公用"):WaitForChild("露天商店"):WaitForChild("购买物品")

-- 关闭商店界面
local function CloseShopUI()
    local success, result = pcall(function()
        local shopUI = Players.LocalPlayer.PlayerGui:FindFirstChild("GUI")
        if shopUI then
            local secondLevel = shopUI:FindFirstChild("二级界面")
            if secondLevel then
                local shopPanel = secondLevel:FindFirstChild("露天商店")
                if shopPanel then
                    local closeButton = shopPanel:FindFirstChild("关闭")
                    if closeButton and closeButton:IsA("TextButton") then
                        closeButton.Activated:Fire()
                        return true
                    end
                end
            end
        end
        return false
    end)
    return success and result or false
end

-- 检查商店数据是否为空
local function IsShopEmpty(shopData)
    if not shopData or type(shopData) ~= "table" then
        return true
    end
    
    for category, items in pairs(shopData) do
        if type(items) == "table" then
            if #items > 0 then
                return false
            end
            local hasItems = false
            for _ in pairs(items) do
                hasItems = true
                break
            end
            if hasItems then
                return false
            end
        end
    end
    
    return true
end

-- 购买挂饰函数
local function BuyAccessory(playerName, itemId, price, accessoryId, quality)
    local success, err = pcall(function()
        local player = Players:FindFirstChild(playerName)
        if not player then
            return false
        end
        
        -- 构建购买参数（根据提供的购买脚本格式）
        -- 第二个参数是Unicode编码的"挂饰"
        local args = {
            player,
            "\233\133\141\233\165\176",  -- "挂饰"
            {
                ["\228\187\183\230\160\188"] = price,  -- "价格"
                ["\231\137\169\229\147\129\231\180\162\229\188\149"] = tostring(itemId)  -- "物品识别id"
            }
        }
        
        buyItemEvent:FireServer(unpack(args))
        return true
    end)
    
    if success then
        purchaseStats[accessoryId] = (purchaseStats[accessoryId] or 0) + 1
        purchaseStats.total = purchaseStats.total + 1
        print(string.format("✓ 购买成功: %s(ID:%s) 品质:%s 价格:%d", 
            ACCESSORY_TYPE_NAMES[accessoryId] or accessoryId, 
            tostring(itemId), 
            QUALITY_NAMES[quality] or quality,
            price))
        return true
    else
        warn("✗ 购买失败:", err)
        return false
    end
end

-- 检查挂饰是否符合购买条件
local function ShouldBuyAccessory(item, itemId, price, itemData)
    -- 检查是否是目标挂饰ID
    local accessoryId = tonumber(item["id"]) or 0
    if not table.find(TARGET_ACCESSORY_IDS, accessoryId) then
        return false
    end
    
    -- 检查品质和价格限制
    local quality = tonumber(item["品质"]) or 0
    local priceLimit = PRICE_LIMITS[quality]
    
    if not priceLimit then
        return false  -- 品质不在范围内
    end
    
    local itemPrice = tonumber(price) or 0
    if itemPrice > priceLimit then
        return false  -- 价格超过限制
    end
    
    return true, accessoryId, quality
end

-- 扫描并购买符合条件的挂饰
local function ScanAndBuy()
    for sellerName, shopData in pairs(allPlayersData) do
        if type(shopData) == "table" then
            -- 检查配饰分类
            local accessories = shopData["配饰"]
            if type(accessories) == "table" then
                for itemId, itemData in pairs(accessories) do
                    local item = itemData["物品数据"]
                    local price = itemData["价格"]
                    
                    if item and price then
                        local shouldBuy, accessoryId, quality = ShouldBuyAccessory(item, itemId, price, itemData)
                        if shouldBuy then
                            local itemPrice = tonumber(price) or 0
                            BuyAccessory(sellerName, itemId, itemPrice, accessoryId, quality)
                            task.wait(0.2)  -- 购买后短暂延迟
                        end
                    end
                end
            end
        end
    end
end

-- 开始自动扫描和购买
local scanConnection = nil
local allPlayersList = {}
local function StartAutoScan()
    if isScanning then return end
    
    allPlayersList = Players:GetPlayers()
    if #allPlayersList == 0 then
        print("没有找到其他玩家")
        -- 如果还在运行，等待后重试
        if isRunning then
            task.wait(2)
            StartAutoScan()
        end
        return
    end
    
    isScanning = true
    currentPlayerIndex = 1
    allPlayersData = {}
    lastReceivedPlayer = nil
    currentScanPlayer = nil
    scanStartTime = 0
    
    -- 断开之前的连接
    if scanConnection then
        scanConnection:Disconnect()
        scanConnection = nil
    end
    
    -- 超时检测循环
    local timeoutCheck = coroutine.wrap(function()
        while isScanning and isRunning do
            task.wait(1)
            local currentTime = tick()
            
            -- 检查是否超时（当前玩家没有收到数据）
            if currentScanPlayer and scanStartTime > 0 and (currentTime - scanStartTime) > scanTimeout then
                -- 检查是否收到了当前玩家的数据
                if lastReceivedPlayer ~= currentScanPlayer.Name then
                    -- 没有收到当前玩家的数据，直接跳过
                    print(string.format("扫描超时，跳过: %s", currentScanPlayer.Name))
                    CloseShopUI() -- 关闭当前商店
                    task.wait(0.1)
                    currentPlayerIndex = currentPlayerIndex + 1
                    if currentPlayerIndex <= #allPlayersList and isRunning and isScanning then
                        currentScanPlayer = allPlayersList[currentPlayerIndex]
                        lastReceivedPlayer = nil -- 重置接收状态
                        viewEvent:FireServer(currentScanPlayer)
                        scanStartTime = tick()
                    end
                end
            end
        end
    end)
    timeoutCheck()
    
    -- 数据接收处理
    scanConnection = viewEvent.OnClientEvent:Connect(function(player, playerData, shopData)
        if not isScanning or not isRunning then 
            if scanConnection then
                scanConnection:Disconnect()
                scanConnection = nil
            end
            return 
        end
        
        -- 标记已收到该玩家的响应
        lastReceivedPlayer = player.Name
        
        -- 存储数据
        if shopData and type(shopData) == "table" then
            -- 检查商店是否为空
            if IsShopEmpty(shopData) then
                print(string.format("商店为空，跳过: %s", player.Name))
                -- 空商店也标记为已处理，但不保存数据
            else
                allPlayersData[player.Name] = shopData
                print("已扫描:", player.Name)
            end
        else
            -- shopData为空或无效，但已经收到响应，说明商店可能真的为空
            print(string.format("收到空响应，跳过: %s", player.Name))
        end
        
        -- 关闭当前商店界面
        CloseShopUI()
        
        -- 继续扫描下一个
        currentPlayerIndex = currentPlayerIndex + 1
        if currentPlayerIndex <= #allPlayersList and isRunning and isScanning then
            task.wait(scanInterval)
            currentScanPlayer = allPlayersList[currentPlayerIndex]
            lastReceivedPlayer = nil -- 重置接收状态
            viewEvent:FireServer(currentScanPlayer)
            scanStartTime = tick()
        else
            -- 扫描完成，执行购买检查
            isScanning = false
            currentScanPlayer = nil
            if scanConnection then
                scanConnection:Disconnect()
                scanConnection = nil
            end
            
            print("扫描完成，开始检查可购买物品...")
            ScanAndBuy()
            
            -- 清空数据准备下一轮
            allPlayersData = {}
            
            -- 如果还在运行，继续下一轮扫描
            if isRunning then
                task.wait(2)  -- 短暂延迟后开始下一轮
                if isRunning then
                    StartAutoScan()
                end
            end
        end
    end)
    
    -- 开始扫描第一个玩家
    if #allPlayersList > 0 and isRunning then
        currentScanPlayer = allPlayersList[1]
        lastReceivedPlayer = nil
        scanStartTime = tick()
        viewEvent:FireServer(allPlayersList[1])
    end
end

-- 停止扫描
local function StopAutoScan()
    isScanning = false
    currentScanPlayer = nil
    lastReceivedPlayer = nil
    if scanConnection then
        scanConnection:Disconnect()
        scanConnection = nil
    end
end

-- 创建UI界面
local function CreateUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AccessoryAutoBuy"
    screenGui.ResetOnSpawn = false
    if syn and syn.protect_gui then
        syn.protect_gui(screenGui)
    end
    screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- 主容器
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 400, 0, 350)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -175)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    mainFrame.BorderSizePixel = 2
    mainFrame.BorderColor3 = Color3.fromRGB(0, 162, 255)
    mainFrame.Parent = screenGui
    
    -- 标题栏（可拖拽）
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
    titleBar.Active = true
    titleBar.Parent = mainFrame
    
    local title = Instance.new("TextLabel")
    title.Text = "挂饰自动购买系统"
    title.Size = UDim2.new(1, -80, 1, 0)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 20
    title.TextColor3 = Color3.fromRGB(255, 255, 0)
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Position = UDim2.new(0, 10, 0, 0)
    title.Parent = titleBar
    
    -- 关闭按钮
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 40, 1, 0)
    closeButton.Position = UDim2.new(1, -40, 0, 0)
    closeButton.Text = "×"
    closeButton.TextSize = 28
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.Parent = titleBar
    
    -- 运行时间标签
    local runtimeLabel = Instance.new("TextLabel")
    runtimeLabel.Text = "运行时间: 00:00:00"
    runtimeLabel.Size = UDim2.new(1, -20, 0, 30)
    runtimeLabel.Position = UDim2.new(0, 10, 0, 50)
    runtimeLabel.Font = Enum.Font.SourceSansBold
    runtimeLabel.TextSize = 18
    runtimeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    runtimeLabel.BackgroundTransparency = 1
    runtimeLabel.TextXAlignment = Enum.TextXAlignment.Left
    runtimeLabel.Parent = mainFrame
    
    -- 状态标签
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Text = "状态: 已停止"
    statusLabel.Size = UDim2.new(1, -20, 0, 25)
    statusLabel.Position = UDim2.new(0, 10, 0, 85)
    statusLabel.Font = Enum.Font.SourceSans
    statusLabel.TextSize = 16
    statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = mainFrame
    
    -- 购买统计区域
    local statsFrame = Instance.new("Frame")
    statsFrame.Size = UDim2.new(1, -20, 0, 140)
    statsFrame.Position = UDim2.new(0, 10, 0, 120)
    statsFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    statsFrame.BorderSizePixel = 1
    statsFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    statsFrame.Parent = mainFrame
    
    local statsTitle = Instance.new("TextLabel")
    statsTitle.Text = "购买统计:"
    statsTitle.Size = UDim2.new(1, -10, 0, 25)
    statsTitle.Position = UDim2.new(0, 5, 0, 5)
    statsTitle.Font = Enum.Font.SourceSansBold
    statsTitle.TextSize = 16
    statsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    statsTitle.BackgroundTransparency = 1
    statsTitle.TextXAlignment = Enum.TextXAlignment.Left
    statsTitle.Parent = statsFrame
    
    local statsText = Instance.new("TextLabel")
    statsText.Name = "StatsText"
    statsText.Text = "金币加成(1015): 0\n暴击概率(1011): 0\n经验加成(1016): 0\n总计: 0"
    statsText.Size = UDim2.new(1, -10, 1, -35)
    statsText.Position = UDim2.new(0, 5, 0, 30)
    statsText.Font = Enum.Font.SourceSans
    statsText.TextSize = 14
    statsText.TextColor3 = Color3.fromRGB(200, 200, 200)
    statsText.BackgroundTransparency = 1
    statsText.TextXAlignment = Enum.TextXAlignment.Left
    statsText.TextYAlignment = Enum.TextYAlignment.Top
    statsText.TextWrapped = true
    statsText.Parent = statsFrame
    
    -- 控制按钮区域
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(1, -20, 0, 50)
    buttonFrame.Position = UDim2.new(0, 10, 1, -60)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.Parent = mainFrame
    
    local startButton = Instance.new("TextButton")
    startButton.Name = "StartButton"
    startButton.Text = "开始运行"
    startButton.Size = UDim2.new(0.48, 0, 1, 0)
    startButton.Position = UDim2.new(0, 0, 0, 0)
    startButton.Font = Enum.Font.SourceSansBold
    startButton.TextSize = 16
    startButton.TextColor3 = Color3.new(1, 1, 1)
    startButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    startButton.Parent = buttonFrame
    
    local stopButton = Instance.new("TextButton")
    stopButton.Name = "StopButton"
    stopButton.Text = "停止运行"
    stopButton.Size = UDim2.new(0.48, 0, 1, 0)
    stopButton.Position = UDim2.new(0.52, 0, 0, 0)
    stopButton.Font = Enum.Font.SourceSansBold
    stopButton.TextSize = 16
    stopButton.TextColor3 = Color3.new(1, 1, 1)
    stopButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    stopButton.Parent = buttonFrame
    
    -- 窗口拖拽功能
    local dragging = false
    local dragStart = Vector2.new()
    local startPos = UDim2.new()
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- 按钮事件
    startButton.Activated:Connect(function()
        if not isRunning then
            isRunning = true
            startTime = tick()
            startButton.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
            stopButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
            statusLabel.Text = "状态: 运行中"
            statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            StartAutoScan()
        end
    end)
    
    stopButton.Activated:Connect(function()
        if isRunning then
            isRunning = false
            StopAutoScan()
            startButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
            stopButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
            statusLabel.Text = "状态: 已停止"
            statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
        end
    end)
    
    closeButton.Activated:Connect(function()
        isRunning = false
        StopAutoScan()
        screenGui:Destroy()
    end)
    
    -- 更新UI的协程
    local updateConnection
    updateConnection = RunService.Heartbeat:Connect(function()
        -- 更新运行时间
        if isRunning and startTime > 0 then
            local elapsed = tick() - startTime
            local hours = math.floor(elapsed / 3600)
            local minutes = math.floor((elapsed % 3600) / 60)
            local seconds = math.floor(elapsed % 60)
            runtimeLabel.Text = string.format("运行时间: %02d:%02d:%02d", hours, minutes, seconds)
        end
        
        -- 更新统计信息
        statsText.Text = string.format(
            "金币加成(1015): %d\n暴击概率(1011): %d\n经验加成(1016): %d\n总计: %d",
            purchaseStats[1015] or 0,
            purchaseStats[1011] or 0,
            purchaseStats[1016] or 0,
            purchaseStats.total or 0
        )
        
        -- 如果UI被销毁，断开连接
        if not screenGui.Parent then
            updateConnection:Disconnect()
        end
    end)
    
    return {
        screenGui = screenGui,
        runtimeLabel = runtimeLabel,
        statusLabel = statusLabel,
        statsText = statsText
    }
end

-- 初始化
print("=" .. string.rep("=", 60))
print("挂饰自动购买系统已启动")
print("目标挂饰: 1015(金币加成), 1011(暴击概率), 1016(经验加成)")
print("价格限制:")
for quality, limit in pairs(PRICE_LIMITS) do
    print(string.format("  %s(%d): <= %d", QUALITY_NAMES[quality] or quality, quality, limit))
end
print("=" .. string.rep("=", 60))

-- 创建UI
CreateUI()

