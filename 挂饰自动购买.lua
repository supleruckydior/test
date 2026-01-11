-- 挂饰自动购买脚本
-- 功能：持续扫描市场并自动购买符合条件的挂饰
-- 目标挂饰ID：1015(金币加成), 1011(暴击概率), 1016(经验加成)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

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
    [5] = 2400,    -- 完美
    [6] = 8000,    -- 稀少
    [7] = 24000,   -- 史诗
    [8] = 72000,   -- 传奇
    [9] = 216000,  -- 不朽
    [10] = 600000  -- 神话
}

-- 购买统计（按挂饰ID和品质分类）
local purchaseStats = {
    [1015] = {},  -- 金币加成购买数量（按品质分类）
    [1011] = {},  -- 暴击概率购买数量（按品质分类）
    [1016] = {},  -- 经验加成购买数量（按品质分类）
    total = 0     -- 总购买数量
}

-- 历史购买记录（最多保存5条）
local purchaseHistory = {}

-- 系统控制变量
local isRunning = false
local startTime = 0
local scanInterval = 0.02  -- 扫描间隔(秒)，扫描完一个玩家后等待时间（极速优化）
local scanTimeout = 0.5  -- 扫描超时时间(秒)（极速优化）
local currentPlayerIndex = 1
local isScanning = false
local currentScanPlayer = nil  -- 当前扫描的玩家
local scanStartTime = 0  -- 扫描开始时间
local lastReceivedPlayer = nil  -- 上次收到数据的玩家

-- 获取购买事件（使用Unicode编码，与用户提供的脚本格式完全一致）
local viewEvent = ReplicatedStorage:WaitForChild("事件"):WaitForChild("公用"):WaitForChild("露天商店"):WaitForChild("查看")
local buyItemEvent = ReplicatedStorage:WaitForChild("\228\186\139\228\187\182"):WaitForChild("\229\133\172\231\148\168"):WaitForChild("\233\156\178\229\164\169\229\149\134\229\186\151"):WaitForChild("\232\180\173\228\185\176\231\137\169\229\147\129")

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

-- 等待商店界面打开
local function WaitForShopUI(maxWait)
    maxWait = maxWait or 1
    local startTime = tick()
    while tick() - startTime < maxWait do
        local shopUI = Players.LocalPlayer.PlayerGui:FindFirstChild("GUI")
        if shopUI then
            local secondLevel = shopUI:FindFirstChild("二级界面")
            if secondLevel then
                local shopPanel = secondLevel:FindFirstChild("露天商店")
                if shopPanel and shopPanel.Visible then
                    return true
                end
            end
        end
        task.wait(0.05)
    end
    return false
end

-- 购买挂饰函数（完全按照用户提供的脚本格式，带3次重试，不等待界面）
local function BuyAccessory(playerName, itemId, price, accessoryId, quality)
    -- itemId 应该是UUID格式的字符串，例如 "b75d7cfc-8a21-413f-b66a-42c3c3a0f66a"
    local maxRetries = 3
    local retryCount = 0
    local purchaseSuccess = false
    
    while retryCount < maxRetries and not purchaseSuccess do
        retryCount = retryCount + 1
        local callSuccess, result = pcall(function()
            -- 按照用户提供的格式获取玩家对象
            local player = game:GetService("Players"):WaitForChild(playerName)
            if not player then
                error("找不到玩家")
            end
            
            -- 不需要等待界面，直接发送购买请求（收到数据即可）
            -- 确保 itemId 是字符串格式（UUID格式）
            local itemIdStr = tostring(itemId)
            
            -- 构建购买参数（完全按照用户提供的脚本格式，不修改转义）
            local args = {
                game:GetService("Players"):WaitForChild(playerName),
                "\233\133\141\233\165\176",
                {
                    ["\228\187\183\230\160\188"] = price,
                    ["\231\137\169\229\147\129\231\180\162\229\188\149"] = itemIdStr
                }
            }
            
            -- 发送购买请求（完全按照用户提供的脚本格式，不等待界面）
            game:GetService("ReplicatedStorage"):WaitForChild("\228\186\139\228\187\182"):WaitForChild("\229\133\172\231\148\168"):WaitForChild("\233\156\178\229\164\169\229\149\134\229\186\151"):WaitForChild("\232\180\173\228\185\176\231\137\169\229\147\129"):FireServer(unpack(args))
            
            return true
        end)
        
        -- 如果 pcall 成功且函数返回 true，则认为购买成功
        if callSuccess and result == true then
            purchaseSuccess = true
        else
            -- 如果购买失败且还有重试机会，等待一小段时间后重试
            if retryCount < maxRetries then
                task.wait(0.05)  -- 减少重试延迟（极速优化）
            end
        end
    end
    
    if purchaseSuccess then
        -- 按挂饰ID和品质分类统计
        if not purchaseStats[accessoryId] then
            purchaseStats[accessoryId] = {}
        end
        purchaseStats[accessoryId][quality] = (purchaseStats[accessoryId][quality] or 0) + 1
        purchaseStats.total = purchaseStats.total + 1
        
        -- 添加到历史记录（最多保存5条，最新的在前面）
        local historyEntry = {
            accessoryName = ACCESSORY_TYPE_NAMES[accessoryId] or tostring(accessoryId),
            accessoryId = accessoryId,
            quality = quality,
            qualityName = QUALITY_NAMES[quality] or tostring(quality),
            price = price,
            sellerName = playerName,  -- 保存卖家名称
            timestamp = tick()
        }
        table.insert(purchaseHistory, 1, historyEntry)
        -- 只保留最近5条记录
        if #purchaseHistory > 5 then
            table.remove(purchaseHistory, 6)
        end
        
        return true
    else
        return false
    end
end

-- 检查挂饰是否符合购买条件
local function ShouldBuyAccessory(item, price, itemData)
    -- 检查是否是目标挂饰ID（从item["id"]中获取）
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

-- 扫描并购买单个玩家商店中符合条件的挂饰
local function ScanAndBuyFromShop(sellerName, shopData)
    if not shopData or type(shopData) ~= "table" then
        return
    end
    
    -- 检查配饰分类
    local accessories = shopData["配饰"]
    if type(accessories) == "table" then
        local foundItems = {}
        -- 先收集所有符合条件的物品
        -- 配饰可能是数组或字典，需要同时支持两种情况
        -- 判断是否为数组：尝试使用ipairs遍历，如果第一个元素有"物品数据"字段，则认为是数组
        local isArray = false
        for i, v in ipairs(accessories) do
            if type(v) == "table" and (v["物品数据"] or v["价格"]) then
                isArray = true
                break
            end
        end
        
        if isArray then
            -- 数组格式：遍历每个元素
            for i, itemData in ipairs(accessories) do
                local item = itemData["物品数据"]
                local price = itemData["价格"]
                
                if item and price then
                    -- 从item["索引"]中获取UUID（物品识别ID）
                    local uuid = item["索引"] or item.Index or item.id
                    if uuid then
                        local shouldBuy, accessoryId, quality = ShouldBuyAccessory(item, price, itemData)
                        if shouldBuy then
                            table.insert(foundItems, {
                                itemId = tostring(uuid),  -- UUID格式的字符串
                                price = tonumber(price) or 0,
                                accessoryId = accessoryId,
                                quality = quality
                            })
                        end
                    end
                end
            end
        else
            -- 字典格式：键是UUID
            for itemId, itemData in pairs(accessories) do
                local item = itemData["物品数据"]
                local price = itemData["价格"]
                
                if item and price then
                    -- 如果键是UUID字符串，直接使用；否则从item["索引"]中获取
                    local uuid = tostring(itemId)
                    if item["索引"] then
                        uuid = tostring(item["索引"])  -- 优先使用物品数据中的索引
                    end
                    
                    local shouldBuy, accessoryId, quality = ShouldBuyAccessory(item, price, itemData)
                    if shouldBuy then
                        table.insert(foundItems, {
                            itemId = uuid,  -- UUID格式的字符串
                            price = tonumber(price) or 0,
                            accessoryId = accessoryId,
                            quality = quality
                        })
                    end
                end
            end
        end
        
        -- 依次购买找到的物品（极速，不等待）
        for _, itemInfo in ipairs(foundItems) do
            BuyAccessory(sellerName, itemInfo.itemId, itemInfo.price, itemInfo.accessoryId, itemInfo.quality)
            -- 移除延迟，直接继续下一个购买
        end
    end
end

-- 开始自动扫描和购买
local scanConnection = nil
local allPlayersList = {}
local scannedPlayersInRound = {}  -- 记录本轮已扫描的玩家（防止重复）
local isWaitingForResponse = false  -- 标记是否正在等待响应，避免超时检测重复处理
local function StartAutoScan()
    if isScanning then return end
    
    -- 获取当前玩家列表，过滤掉自己
    local allPlayers = Players:GetPlayers()
    allPlayersList = {}
    for _, player in ipairs(allPlayers) do
        if player ~= Players.LocalPlayer then
            table.insert(allPlayersList, player)
        end
    end
    
    if #allPlayersList == 0 then
        -- 如果还在运行，等待后重试
        if isRunning then
            task.wait(0.5)  -- 极速优化
            StartAutoScan()
        end
        return
    end
    
    isScanning = true
    currentPlayerIndex = 1
    lastReceivedPlayer = nil
    currentScanPlayer = nil
    scanStartTime = 0
    isWaitingForResponse = false
    scannedPlayersInRound = {}  -- 重置已扫描列表
    
    -- 断开之前的连接
    if scanConnection then
        scanConnection:Disconnect()
        scanConnection = nil
    end
    
    -- 处理下一个玩家扫描的函数（统一管理，避免重复调用）
    local function ProcessNextPlayer()
        if not isRunning or not isScanning then
            return false
        end
        
        -- 跳过已扫描的玩家（防止重复扫描）
        while currentPlayerIndex <= #allPlayersList do
            local nextPlayer = allPlayersList[currentPlayerIndex]
            
            -- 检查是否已经扫描过这个玩家
            if not scannedPlayersInRound[nextPlayer.Name] then
                currentScanPlayer = nextPlayer
                scannedPlayersInRound[nextPlayer.Name] = true  -- 标记为已扫描，防止重复
                lastReceivedPlayer = nil
                scanStartTime = tick()
                isWaitingForResponse = true
                viewEvent:FireServer(currentScanPlayer)
                return true
            else
                -- 如果已经扫描过，跳过并继续下一个
                currentPlayerIndex = currentPlayerIndex + 1
            end
        end
        
        -- 所有玩家都已扫描完成，准备下一轮
        isScanning = false
        currentScanPlayer = nil
        isWaitingForResponse = false
        
        if scanConnection then
            scanConnection:Disconnect()
            scanConnection = nil
        end
        
        -- 如果还在运行，继续下一轮扫描
        if isRunning then
            task.wait(0.3)  -- 短暂延迟后开始下一轮（极速优化）
            if isRunning then
                StartAutoScan()
            end
        end
        return false
    end
    
    -- 处理玩家响应的函数（统一处理，包括超时和正常响应）
    local function HandlePlayerResponse(playerName, shopData, isTimeout)
        if not isRunning or not isScanning then
            return
        end
        
        -- 如果这不是我们正在等待的玩家，忽略（防止处理错误的响应）
        if currentScanPlayer and playerName ~= currentScanPlayer.Name then
            return
        end
        
        -- 如果已经处理过这个玩家（防止重复处理），忽略
        -- 这个检查必须在最开始，避免重复处理导致的索引错乱
        if not isWaitingForResponse then
            return
        end
        
        -- 立即标记为已处理，防止超时检测和正常响应同时处理
        isWaitingForResponse = false
        lastReceivedPlayer = playerName
        
        if isTimeout then
            -- 超时的情况下关闭商店界面
            CloseShopUI()
        else
            -- 处理数据并立即尝试购买（收到数据即可，不等待界面）
            if shopData and type(shopData) == "table" then
                -- 检查商店是否为空
                if not IsShopEmpty(shopData) then
                    -- 直接尝试购买，不需要等待界面打开（收到数据即可）
                    ScanAndBuyFromShop(playerName, shopData)
                    -- 立即关闭商店界面，不等待
                    CloseShopUI()
                else
                    -- 空商店时关闭商店界面
                    CloseShopUI()
                end
            else
                -- shopData为空或无效，关闭商店界面
                CloseShopUI()
            end
        end
        
        -- 继续扫描下一个玩家（统一在这里推进索引，极速不等待）
        currentPlayerIndex = currentPlayerIndex + 1
        -- 移除延迟，直接处理下一个玩家（极速优化）
        ProcessNextPlayer()
    end
    
    -- 超时检测循环
    local timeoutCheck = coroutine.wrap(function()
        while isScanning and isRunning do
            task.wait(0.1)  -- 每0.1秒检查一次（极速优化）
            
            -- 检查是否超时（当前玩家没有收到数据）
            -- 如果 isWaitingForResponse 仍然为 true，说明还在等待响应
            -- 如果超时了，说明没有收到响应
            if isWaitingForResponse and currentScanPlayer and scanStartTime > 0 then
                local currentTime = tick()
                if (currentTime - scanStartTime) > scanTimeout then
                    -- 再次确认：如果 isWaitingForResponse 仍为 true，说明确实没有收到响应
                    -- 同时确认 lastReceivedPlayer 不是当前玩家（双重检查，确保不会误判）
                    if isWaitingForResponse and (not lastReceivedPlayer or lastReceivedPlayer ~= currentScanPlayer.Name) then
                        -- 没有收到当前玩家的数据，超时处理
                        HandlePlayerResponse(currentScanPlayer.Name, nil, true)
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
        
        -- 正常响应处理
        HandlePlayerResponse(player.Name, shopData, false)
    end)
    
    -- 开始扫描第一个玩家
    ProcessNextPlayer()
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
    
    -- 主容器（增大高度以容纳更多统计信息和历史记录）
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 500, 0, 650)  -- 增加高度以容纳卖家信息和按钮
    mainFrame.Position = UDim2.new(0.5, -250, 0.5, -325)
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
    
    -- 购买统计区域（使用滚动框以容纳更多信息）
    local statsFrame = Instance.new("Frame")
    statsFrame.Size = UDim2.new(1, -20, 0, 220)
    statsFrame.Position = UDim2.new(0, 10, 0, 120)
    statsFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    statsFrame.BorderSizePixel = 1
    statsFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    statsFrame.Parent = mainFrame
    
    local statsTitle = Instance.new("TextLabel")
    statsTitle.Text = "购买统计（按品阶分类）:"
    statsTitle.Size = UDim2.new(1, -10, 0, 25)
    statsTitle.Position = UDim2.new(0, 5, 0, 5)
    statsTitle.Font = Enum.Font.SourceSansBold
    statsTitle.TextSize = 16
    statsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    statsTitle.BackgroundTransparency = 1
    statsTitle.TextXAlignment = Enum.TextXAlignment.Left
    statsTitle.Parent = statsFrame
    
    local statsScroll = Instance.new("ScrollingFrame")
    statsScroll.Name = "StatsScroll"
    statsScroll.Size = UDim2.new(1, -10, 1, -35)
    statsScroll.Position = UDim2.new(0, 5, 0, 30)
    statsScroll.BackgroundTransparency = 1
    statsScroll.BorderSizePixel = 0
    statsScroll.ScrollBarThickness = 6
    statsScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    statsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    statsScroll.Parent = statsFrame
    
    local statsText = Instance.new("TextLabel")
    statsText.Name = "StatsText"
    statsText.Text = "加载中..."
    statsText.Size = UDim2.new(1, -10, 0, 0)
    statsText.Position = UDim2.new(0, 5, 0, 5)
    statsText.Font = Enum.Font.SourceSans
    statsText.TextSize = 13
    statsText.TextColor3 = Color3.fromRGB(200, 200, 200)
    statsText.BackgroundTransparency = 1
    statsText.TextXAlignment = Enum.TextXAlignment.Left
    statsText.TextYAlignment = Enum.TextYAlignment.Top
    statsText.TextWrapped = true
    statsText.AutomaticSize = Enum.AutomaticSize.Y
    statsText.Parent = statsScroll
    
    -- 历史购买记录区域（增加高度以容纳更多信息）
    local historyFrame = Instance.new("Frame")
    historyFrame.Size = UDim2.new(1, -20, 0, 200)
    historyFrame.Position = UDim2.new(0, 10, 0, 350)  -- 位置保持，因为主窗口已增加高度
    historyFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    historyFrame.BorderSizePixel = 1
    historyFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    historyFrame.Parent = mainFrame
    
    local historyTitle = Instance.new("TextLabel")
    historyTitle.Text = "最近购买记录 (最多5条):"
    historyTitle.Size = UDim2.new(1, -10, 0, 25)
    historyTitle.Position = UDim2.new(0, 5, 0, 5)
    historyTitle.Font = Enum.Font.SourceSansBold
    historyTitle.TextSize = 16
    historyTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    historyTitle.BackgroundTransparency = 1
    historyTitle.TextXAlignment = Enum.TextXAlignment.Left
    historyTitle.Parent = historyFrame
    
    local historyScroll = Instance.new("ScrollingFrame")
    historyScroll.Name = "HistoryScroll"
    historyScroll.Size = UDim2.new(1, -10, 1, -35)
    historyScroll.Position = UDim2.new(0, 5, 0, 30)
    historyScroll.BackgroundTransparency = 1
    historyScroll.BorderSizePixel = 0
    historyScroll.ScrollBarThickness = 6
    historyScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    historyScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    historyScroll.Parent = historyFrame
    
    local historyContainer = Instance.new("Frame")
    historyContainer.Name = "HistoryContainer"
    historyContainer.Size = UDim2.new(1, 0, 0, 0)
    historyContainer.Position = UDim2.new(0, 0, 0, 0)
    historyContainer.BackgroundTransparency = 1
    historyContainer.AutomaticSize = Enum.AutomaticSize.Y
    historyContainer.Parent = historyScroll
    
    local historyLayout = Instance.new("UIListLayout")
    historyLayout.SortOrder = Enum.SortOrder.LayoutOrder
    historyLayout.Padding = UDim.new(0, 5)
    historyLayout.Parent = historyContainer
    
    historyScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    historyContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        historyScroll.CanvasSize = UDim2.new(0, 0, 0, historyContainer.AbsoluteSize.Y)
    end)
    
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
    
    -- 更新历史记录显示的函数
    local lastHistoryCount = 0
    local function UpdateHistoryDisplay()
        local currentCount = #purchaseHistory
        if currentCount == lastHistoryCount then
            return  -- 历史记录没有变化，不需要更新
        end
        lastHistoryCount = currentCount
        
        -- 清除旧的历史记录项
        for _, child in ipairs(historyContainer:GetChildren()) do
            if child:IsA("Frame") or child:IsA("TextLabel") then
                child:Destroy()
            end
        end
        
        -- 显示历史记录（最多5条）
        if #purchaseHistory > 0 then
            for i, entry in ipairs(purchaseHistory) do
                local historyItem = Instance.new("Frame")
                historyItem.Name = "HistoryItem" .. i
                historyItem.Size = UDim2.new(1, -10, 0, 35)  -- 增加高度以容纳卖家信息
                historyItem.BackgroundColor3 = Color3.fromRGB(55, 55, 75)
                historyItem.BorderSizePixel = 1
                historyItem.BorderColor3 = Color3.fromRGB(80, 80, 80)
                historyItem.LayoutOrder = i
                historyItem.Parent = historyContainer
                
                -- 第一行：物品名称和品质
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Text = string.format("%s(%d)", entry.accessoryName, entry.accessoryId)
                nameLabel.Size = UDim2.new(0.35, 0, 0, 16)
                nameLabel.Position = UDim2.new(0, 5, 0, 2)
                nameLabel.Font = Enum.Font.SourceSans
                nameLabel.TextSize = 12
                nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                nameLabel.BackgroundTransparency = 1
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.TextYAlignment = Enum.TextYAlignment.Top
                nameLabel.TextWrapped = true
                nameLabel.Parent = historyItem
                
                local qualityLabel = Instance.new("TextLabel")
                qualityLabel.Text = entry.qualityName
                qualityLabel.Size = UDim2.new(0.2, 0, 0, 16)
                qualityLabel.Position = UDim2.new(0.35, 0, 0, 2)
                qualityLabel.Font = Enum.Font.SourceSans
                qualityLabel.TextSize = 12
                qualityLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
                qualityLabel.BackgroundTransparency = 1
                qualityLabel.TextXAlignment = Enum.TextXAlignment.Center
                qualityLabel.TextYAlignment = Enum.TextYAlignment.Top
                qualityLabel.Parent = historyItem
                
                local priceLabel = Instance.new("TextLabel")
                priceLabel.Text = string.format("价格: %d", entry.price)
                priceLabel.Size = UDim2.new(0.25, 0, 0, 16)
                priceLabel.Position = UDim2.new(0.55, 0, 0, 2)
                priceLabel.Font = Enum.Font.SourceSans
                priceLabel.TextSize = 12
                priceLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
                priceLabel.BackgroundTransparency = 1
                priceLabel.TextXAlignment = Enum.TextXAlignment.Right
                priceLabel.TextYAlignment = Enum.TextYAlignment.Top
                priceLabel.Parent = historyItem
                
                -- 第二行：卖家名称和打开商店按钮
                local sellerLabel = Instance.new("TextLabel")
                sellerLabel.Text = string.format("卖家: %s", entry.sellerName or "未知")
                sellerLabel.Size = UDim2.new(0.6, -5, 0, 16)
                sellerLabel.Position = UDim2.new(0, 5, 0, 18)
                sellerLabel.Font = Enum.Font.SourceSans
                sellerLabel.TextSize = 11
                sellerLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
                sellerLabel.BackgroundTransparency = 1
                sellerLabel.TextXAlignment = Enum.TextXAlignment.Left
                sellerLabel.TextYAlignment = Enum.TextYAlignment.Top
                sellerLabel.Parent = historyItem
                
                -- 打开商店按钮
                local openShopButton = Instance.new("TextButton")
                openShopButton.Name = "OpenShopButton"
                openShopButton.Text = "查看商店"
                openShopButton.Size = UDim2.new(0.35, -5, 0, 16)
                openShopButton.Position = UDim2.new(0.6, 5, 0, 18)
                openShopButton.Font = Enum.Font.SourceSans
                openShopButton.TextSize = 11
                openShopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                openShopButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
                openShopButton.BorderSizePixel = 0
                openShopButton.Parent = historyItem
                
                -- 按钮悬停效果
                openShopButton.MouseEnter:Connect(function()
                    openShopButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
                end)
                openShopButton.MouseLeave:Connect(function()
                    openShopButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
                end)
                
                -- 按钮点击事件：打开该卖家的商店
                openShopButton.Activated:Connect(function()
                    local sellerName = entry.sellerName
                    if sellerName then
                        local seller = Players:FindFirstChild(sellerName)
                        if seller then
                            -- 发送查看商店请求
                            viewEvent:FireServer(seller)
                        end
                    end
                end)
            end
        else
            -- 如果没有历史记录，显示提示
            local emptyLabel = Instance.new("TextLabel")
            emptyLabel.Text = "暂无购买记录"
            emptyLabel.Size = UDim2.new(1, -10, 0, 30)
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.Font = Enum.Font.SourceSans
            emptyLabel.TextSize = 14
            emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            emptyLabel.TextXAlignment = Enum.TextXAlignment.Center
            emptyLabel.TextYAlignment = Enum.TextYAlignment.Center
            emptyLabel.Parent = historyContainer
        end
    end
    
    -- 初始化历史记录显示
    UpdateHistoryDisplay()
    
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
        
        -- 更新统计信息（按品阶分类显示）
        local function GetQualityStats(accessoryId)
            local stats = purchaseStats[accessoryId] or {}
            local totalCount = 0
            local qualityText = {}
            
            -- 按品质顺序显示（5-10）
            local qualityOrder = {5, 6, 7, 8, 9, 10}
            for _, quality in ipairs(qualityOrder) do
                local count = stats[quality] or 0
                if count > 0 then
                    totalCount = totalCount + count
                    table.insert(qualityText, string.format("  %s: %d", QUALITY_NAMES[quality] or quality, count))
                end
            end
            
            local accessoryName = ACCESSORY_TYPE_NAMES[accessoryId] or tostring(accessoryId)
            if totalCount > 0 then
                return string.format("%s(%d) - 总计: %d\n%s", 
                    accessoryName, 
                    accessoryId, 
                    totalCount,
                    table.concat(qualityText, "\n"))
            else
                return string.format("%s(%d): 0", accessoryName, accessoryId)
            end
        end
        
        local statsLines = {
            GetQualityStats(1015),
            GetQualityStats(1011),
            GetQualityStats(1016),
            "",
            string.format("总计: %d", purchaseStats.total or 0)
        }
        statsText.Text = table.concat(statsLines, "\n")
        
        -- 检查并更新历史记录显示（只在历史记录变化时更新）
        UpdateHistoryDisplay()
        
        -- 如果UI被销毁，断开连接
        if not screenGui.Parent then
            updateConnection:Disconnect()
        end
    end)
    
    return {
        screenGui = screenGui,
        runtimeLabel = runtimeLabel,
        statusLabel = statusLabel,
        statsText = statsText,
        historyContainer = historyContainer
    }
end

-- 防AFK功能
local AntiAFK = game:GetService("VirtualUser")
Players.LocalPlayer.Idled:Connect(function()
    AntiAFK:CaptureController()
    AntiAFK:ClickButton2(Vector2.new())
    task.wait(2)
end)
print("✓ 防AFK功能已启用")

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

