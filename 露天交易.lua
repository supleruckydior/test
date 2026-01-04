local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- 颜色配置
local COLOR_SCHEME = {
    BACKGROUND = Color3.fromRGB(30, 30, 40),
    PANEL = Color3.fromRGB(45, 45, 60),
    ACCENT = Color3.fromRGB(0, 162, 255),
    TEXT_MAIN = Color3.fromRGB(255, 255, 0),
    TEXT_SECONDARY = Color3.fromRGB(255, 0, 0),
    ITEM_CARD = Color3.fromRGB(55, 55, 75),
    HEADER = Color3.fromRGB(70, 70, 90),
    POSITIVE = Color3.fromRGB(100, 255, 150),
    WARNING = Color3.fromRGB(255, 200, 100),
    BUTTON = Color3.fromRGB(0, 120, 215),
    BUTTON_HOVER = Color3.fromRGB(0, 150, 255),
    CLOSE_BUTTON = Color3.fromRGB(255, 80, 80),
    FAVORITE = Color3.fromRGB(255, 215, 0),
    SEARCH_BG = Color3.fromRGB(40, 40, 55)
}

-- 品质ID映射
local QUALITY_TYPES = {
    [10] = "神话",
    [11] = "永恒"
}

-- 全局变量
local allPlayersData = {} -- 存储所有玩家数据
local currentPlayerIndex = 1
local isScanning = false
local scanInterval = 1 -- 扫描间隔(秒)
local viewEvent = ReplicatedStorage:WaitForChild("事件"):WaitForChild("公用"):WaitForChild("露天商店"):WaitForChild("查看")
local favorites = {} -- 收藏列表
local priceAlerts = {} -- 价格提醒列表
local searchText = "" -- 搜索文本
local sortMode = "price_asc" -- 排序模式: price_asc, price_desc, level_asc, level_desc, name_asc
local autoRefreshEnabled = false -- 自动刷新
local autoRefreshInterval = 30 -- 自动刷新间隔(秒)
local lastRefreshTime = 0

-- 1. 创建完整UI
local function CreateCompleteUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ShopFilterPro"
    screenGui.ResetOnSpawn = false
    if syn and syn.protect_gui then
        syn.protect_gui(screenGui)
    end
    screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

    -- 主容器
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0.85, 0, 0.9, 0)
    mainFrame.Position = UDim2.new(0.075, 0, 0.05, 0)
    mainFrame.BackgroundColor3 = COLOR_SCHEME.BACKGROUND
    mainFrame.BorderSizePixel = 2
    mainFrame.BorderColor3 = COLOR_SCHEME.ACCENT
    mainFrame.Parent = screenGui

    -- 标题栏（可拖拽）
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 50)
    titleBar.BackgroundColor3 = COLOR_SCHEME.HEADER
    titleBar.Active = true
    titleBar.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Text = "高级物品过滤器 ▼"
    title.Size = UDim2.new(1, -140, 1, 0)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 24
    title.TextColor3 = COLOR_SCHEME.TEXT_MAIN
    title.BackgroundTransparency = 1
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Position = UDim2.new(0, 15, 0, 0)
    title.Parent = titleBar

    -- 统计信息标签
    local statsLabel = Instance.new("TextLabel")
    statsLabel.Text = "物品: 0 | 卖家: 0"
    statsLabel.Size = UDim2.new(0, 200, 1, 0)
    statsLabel.Position = UDim2.new(1, -280, 0, 0)
    statsLabel.Font = Enum.Font.SourceSans
    statsLabel.TextSize = 14
    statsLabel.TextColor3 = COLOR_SCHEME.TEXT_MAIN
    statsLabel.BackgroundTransparency = 1
    statsLabel.TextXAlignment = Enum.TextXAlignment.Right
    statsLabel.Parent = titleBar

    -- 折叠按钮
    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0, 40, 1, 0)
    toggleButton.Position = UDim2.new(1, -90, 0, 0)
    toggleButton.Text = "≡"
    toggleButton.TextSize = 24
    toggleButton.BackgroundTransparency = 1
    toggleButton.TextColor3 = COLOR_SCHEME.TEXT_MAIN
    toggleButton.Parent = titleBar

    -- 关闭按钮
    local closeButton = Instance.new("TextButton")
    closeButton.Size = UDim2.new(0, 40, 1, 0)
    closeButton.Position = UDim2.new(1, -40, 0, 0)
    closeButton.Text = "×"
    closeButton.TextSize = 28
    closeButton.Font = Enum.Font.SourceSansBold
    closeButton.BackgroundColor3 = COLOR_SCHEME.CLOSE_BUTTON
    closeButton.TextColor3 = Color3.new(1, 1, 1)
    closeButton.Parent = titleBar

    -- 内容区域
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, 0, 1, -50)
    contentFrame.Position = UDim2.new(0, 0, 0, 50)
    contentFrame.BackgroundTransparency = 1
    contentFrame.ClipsDescendants = true
    contentFrame.Name = "contentFrame"
    contentFrame.Parent = mainFrame

    -- 搜索栏
    local searchFrame = Instance.new("Frame")
    searchFrame.Size = UDim2.new(1, -10, 0, 40)
    searchFrame.Position = UDim2.new(0, 5, 0, 5)
    searchFrame.BackgroundColor3 = COLOR_SCHEME.SEARCH_BG
    searchFrame.BorderSizePixel = 1
    searchFrame.BorderColor3 = COLOR_SCHEME.ACCENT
    searchFrame.Parent = contentFrame

    local searchIcon = Instance.new("TextLabel")
    searchIcon.Text = "🔍"
    searchIcon.Size = UDim2.new(0, 30, 1, 0)
    searchIcon.Position = UDim2.new(0, 5, 0, 0)
    searchIcon.TextColor3 = COLOR_SCHEME.TEXT_MAIN
    searchIcon.BackgroundTransparency = 1
    searchIcon.Font = Enum.Font.SourceSans
    searchIcon.TextSize = 20
    searchIcon.Parent = searchFrame

    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -40, 1, 0)
    searchBox.Position = UDim2.new(0, 35, 0, 0)
    searchBox.PlaceholderText = "搜索物品名称、卖家..."
    searchBox.Text = ""
    searchBox.TextColor3 = COLOR_SCHEME.TEXT_MAIN
    searchBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    searchBox.BackgroundTransparency = 1
    searchBox.Font = Enum.Font.SourceSans
    searchBox.TextSize = 18
    searchBox.TextXAlignment = Enum.TextXAlignment.Left
    searchBox.Parent = searchFrame

    -- 左侧过滤面板
    local filterScroll = Instance.new("ScrollingFrame")
    filterScroll.Size = UDim2.new(0.35, -5, 1, -160)
    filterScroll.Position = UDim2.new(0, 5, 0, 50)
    filterScroll.BackgroundColor3 = COLOR_SCHEME.PANEL
    filterScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    filterScroll.ScrollBarThickness = 8
    filterScroll.Parent = contentFrame

    -- 右侧结果面板
    local resultsScroll = Instance.new("ScrollingFrame")
    resultsScroll.Size = UDim2.new(0.65, -10, 1, -160)
    resultsScroll.Position = UDim2.new(0.35, 5, 0, 50)
    resultsScroll.BackgroundColor3 = COLOR_SCHEME.PANEL
    resultsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    resultsScroll.ScrollBarThickness = 8
    resultsScroll.Parent = contentFrame

    -- 排序选择
    local sortFrame = Instance.new("Frame")
    sortFrame.Size = UDim2.new(0.65, -10, 0, 30)
    sortFrame.Position = UDim2.new(0.35, 5, 0, 15)
    sortFrame.BackgroundTransparency = 1
    sortFrame.Parent = contentFrame

    local sortLabel = Instance.new("TextLabel")
    sortLabel.Text = "排序:"
    sortLabel.Size = UDim2.new(0, 50, 1, 0)
    sortLabel.TextColor3 = COLOR_SCHEME.TEXT_MAIN
    sortLabel.BackgroundTransparency = 1
    sortLabel.Font = Enum.Font.SourceSansSemibold
    sortLabel.TextSize = 16
    sortLabel.TextXAlignment = Enum.TextXAlignment.Left
    sortLabel.Parent = sortFrame

    local sortDropdown = Instance.new("TextButton")
    sortDropdown.Text = "价格 ↑"
    sortDropdown.Size = UDim2.new(0, 150, 1, 0)
    sortDropdown.Position = UDim2.new(0, 55, 0, 0)
    sortDropdown.BackgroundColor3 = COLOR_SCHEME.BUTTON
    sortDropdown.TextColor3 = Color3.new(1, 1, 1)
    sortDropdown.Font = Enum.Font.SourceSans
    sortDropdown.TextSize = 16
    sortDropdown.Parent = sortFrame

    -- 底部按钮区域
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(1, -10, 0, 50)
    buttonFrame.Position = UDim2.new(0, 5, 1, -105)
    buttonFrame.BackgroundTransparency = 1
    buttonFrame.Parent = contentFrame

    local filterButton = Instance.new("TextButton")
    filterButton.Text = "应用过滤条件"
    filterButton.Size = UDim2.new(0.33, -5, 1, 0)
    filterButton.Position = UDim2.new(0, 0, 0, 0)
    filterButton.Font = Enum.Font.SourceSansBold
    filterButton.TextSize = 18
    filterButton.TextColor3 = COLOR_SCHEME.TEXT_MAIN
    filterButton.BackgroundColor3 = COLOR_SCHEME.BUTTON
    filterButton.Parent = buttonFrame

    filterButton.MouseEnter:Connect(function()
        filterButton.BackgroundColor3 = COLOR_SCHEME.BUTTON_HOVER
    end)
    filterButton.MouseLeave:Connect(function()
        filterButton.BackgroundColor3 = COLOR_SCHEME.BUTTON
    end)

    local resetButton = Instance.new("TextButton")
    resetButton.Text = "重置条件"
    resetButton.Size = UDim2.new(0.33, -5, 1, 0)
    resetButton.Position = UDim2.new(0.33, 2, 0, 0)
    resetButton.Font = Enum.Font.SourceSansBold
    resetButton.TextSize = 18
    resetButton.TextColor3 = COLOR_SCHEME.TEXT_MAIN
    resetButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    resetButton.Parent = buttonFrame

    local favoriteButton = Instance.new("TextButton")
    favoriteButton.Text = "收藏列表"
    favoriteButton.Size = UDim2.new(0.34, -5, 1, 0)
    favoriteButton.Position = UDim2.new(0.66, 2, 0, 0)
    favoriteButton.Font = Enum.Font.SourceSansBold
    favoriteButton.TextSize = 18
    favoriteButton.TextColor3 = COLOR_SCHEME.TEXT_MAIN
    favoriteButton.BackgroundColor3 = COLOR_SCHEME.FAVORITE
    favoriteButton.Parent = buttonFrame

    -- 扫描控制区域
    local scanFrame = Instance.new("Frame")
    scanFrame.Size = UDim2.new(1, -10, 0, 50)
    scanFrame.Position = UDim2.new(0, 5, 1, -50)
    scanFrame.BackgroundTransparency = 1
    scanFrame.Parent = contentFrame

    local scanButton = Instance.new("TextButton")
    scanButton.Text = "开始扫描所有商店"
    scanButton.Size = UDim2.new(0.33, -5, 1, 0)
    scanButton.Position = UDim2.new(0, 0, 0, 0)
    scanButton.Font = Enum.Font.SourceSansBold
    scanButton.TextSize = 16
    scanButton.TextColor3 = COLOR_SCHEME.TEXT_MAIN
    scanButton.BackgroundColor3 = COLOR_SCHEME.BUTTON
    scanButton.Parent = scanFrame

    local progressLabel = Instance.new("TextLabel")
    progressLabel.Text = "准备扫描"
    progressLabel.Size = UDim2.new(0.33, -5, 1, 0)
    progressLabel.Position = UDim2.new(0.33, 2, 0, 0)
    progressLabel.TextXAlignment = Enum.TextXAlignment.Left
    progressLabel.TextColor3 = COLOR_SCHEME.TEXT_MAIN
    progressLabel.Font = Enum.Font.SourceSans
    progressLabel.TextSize = 16
    progressLabel.BackgroundTransparency = 1
    progressLabel.Parent = scanFrame

    local autoRefreshButton = Instance.new("TextButton")
    autoRefreshButton.Text = "自动刷新: 关闭"
    autoRefreshButton.Size = UDim2.new(0.34, -5, 1, 0)
    autoRefreshButton.Position = UDim2.new(0.66, 2, 0, 0)
    autoRefreshButton.Font = Enum.Font.SourceSansBold
    autoRefreshButton.TextSize = 14
    autoRefreshButton.TextColor3 = COLOR_SCHEME.TEXT_MAIN
    autoRefreshButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    autoRefreshButton.Parent = scanFrame

    -- 鼠标悬停效果
    scanButton.MouseEnter:Connect(function()
        scanButton.BackgroundColor3 = COLOR_SCHEME.BUTTON_HOVER
    end)
    scanButton.MouseLeave:Connect(function()
        scanButton.BackgroundColor3 = COLOR_SCHEME.BUTTON
    end)

    favoriteButton.MouseEnter:Connect(function()
        favoriteButton.BackgroundColor3 = Color3.fromRGB(255, 235, 100)
    end)
    favoriteButton.MouseLeave:Connect(function()
        favoriteButton.BackgroundColor3 = COLOR_SCHEME.FAVORITE
    end)

    -- 添加过滤控件
    local yOffset = 10
    local controls = {}

    local function AddFilterRow(labelText, inputType, defaultValue)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 40)
        frame.Position = UDim2.new(0, 5, 0, yOffset)
        frame.BackgroundTransparency = 1
        frame.Parent = filterScroll

        local label = Instance.new("TextLabel")
        label.Text = labelText
        label.Size = UDim2.new(0.5, 0, 1, 0)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextColor3 = COLOR_SCHEME.TEXT_MAIN
        label.Font = Enum.Font.SourceSansSemibold
        label.TextSize = 18
        label.Parent = frame

        local input
        if inputType == "checkbox" then
            input = Instance.new("TextButton")
            input.Text = defaultValue and "[✓]" or "[ ]"
            input.Size = UDim2.new(0.2, 0, 1, 0)
            input.Position = UDim2.new(0.5, 0, 0, 0)
            input.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
            input.TextColor3 = COLOR_SCHEME.TEXT_MAIN
            input.TextSize = 18
            input.Activated:Connect(function()
                input.Text = input.Text == "[ ]" and "[✓]" or "[ ]"
            end)
        else
            input = Instance.new("TextBox")
            input.Size = UDim2.new(0.5, 0, 1, 0)
            input.Position = UDim2.new(0.5, 0, 0, 0)
            input.Text = tostring(defaultValue or "")
            input.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
            input.TextColor3 = COLOR_SCHEME.TEXT_MAIN
            input.PlaceholderColor3 = COLOR_SCHEME.TEXT_SECONDARY
            input.Font = Enum.Font.SourceSans
            input.TextSize = 18
        end
        input.Parent = frame

        yOffset = yOffset + 45
        return input
    end

    -- 添加过滤条件
    controls.minLevel = AddFilterRow("最低等级:", "text", 1)
    controls.maxLevel = AddFilterRow("最高等级:", "text", 100)
    controls.minPrice = AddFilterRow("最低价格:", "text", "")
    controls.maxPrice = AddFilterRow("最高价格:", "text", "")
    controls.wingAttr = AddFilterRow("翅膀第三属性≥:", "text", 1.0)
    controls.atkSpeed = AddFilterRow("需要攻击速度", "checkbox", false)
    controls.critRate = AddFilterRow("需要暴击概率", "checkbox", false)
    controls.qualityMythic = AddFilterRow("神话品质(10)", "checkbox", false)
    controls.qualityEternal = AddFilterRow("永恒品质(11)", "checkbox", false)
    filterScroll.CanvasSize = UDim2.new(0, 0, 0, yOffset + 10)

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

    -- 折叠功能
    local isExpanded = true
    local function ToggleUI()
        isExpanded = not isExpanded
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad)
        
        if isExpanded then
            title.Text = "高级物品过滤器 ▼"
            TweenService:Create(contentFrame, tweenInfo, {
                Size = UDim2.new(1, 0, 1, -50),
                Position = UDim2.new(0, 0, 0, 50)
            }):Play()
            TweenService:Create(mainFrame, tweenInfo, {
                Size = UDim2.new(0.85, 0, 0.9, 0)
            }):Play()
        else
            title.Text = "高级物品过滤器 ▶"
            TweenService:Create(contentFrame, tweenInfo, {
                Size = UDim2.new(1, 0, 0, 0),
                Position = UDim2.new(0, 0, 0, 50)
            }):Play()
            TweenService:Create(mainFrame, tweenInfo, {
                Size = UDim2.new(0.85, 0, 0, 50)
            }):Play()
        end
    end

    toggleButton.Activated:Connect(ToggleUI)
    closeButton.Activated:Connect(function()
        screenGui:Destroy()
    end)
    
    -- 添加标题点击事件
    local titleButton = Instance.new("TextButton")
    titleButton.Size = title.Size
    titleButton.Position = title.Position
    titleButton.BackgroundTransparency = 1
    titleButton.Text = ""
    titleButton.Parent = titleBar
    titleButton.Activated:Connect(ToggleUI)

    -- 排序下拉菜单
    local sortModes = {
        {text = "价格 ↑", mode = "price_asc"},
        {text = "价格 ↓", mode = "price_desc"},
        {text = "等级 ↑", mode = "level_asc"},
        {text = "等级 ↓", mode = "level_desc"},
        {text = "名称 A-Z", mode = "name_asc"}
    }
    local currentSortIndex = 1

    sortDropdown.Activated:Connect(function()
        currentSortIndex = (currentSortIndex % #sortModes) + 1
        local sortInfo = sortModes[currentSortIndex]
        sortDropdown.Text = sortInfo.text
        sortMode = sortInfo.mode
        -- 重新应用过滤以更新排序
        if ui.filterButton then
            ui.filterButton.Activated:Fire()
        end
    end)

    return {
        screenGui = screenGui,
        controls = controls,
        resultsScroll = resultsScroll,
        filterButton = filterButton,
        resetButton = resetButton,
        scanButton = scanButton,
        progressLabel = progressLabel,
        toggleUI = ToggleUI,
        mainFrame = mainFrame,
        searchBox = searchBox,
        favoriteButton = favoriteButton,
        autoRefreshButton = autoRefreshButton,
        statsLabel = statsLabel,
        sortDropdown = sortDropdown
    }
end

-- 2. 物品过滤逻辑
local function FilterItems(items, filters, searchQuery)
    local filtered = {}
    
    for itemId, itemData in pairs(items) do
        local item = itemData["物品数据"]
        local valid = true
        
        -- 搜索过滤
        if searchQuery and searchQuery ~= "" then
            local searchLower = string.lower(searchQuery)
            local itemIdLower = string.lower(tostring(itemId))
            local sellerName = ""
            if itemData["卖家"] then
                sellerName = string.lower(tostring(itemData["卖家"]))
            end
            if not (string.find(itemIdLower, searchLower) or string.find(sellerName, searchLower)) then
                valid = false
            end
        end
        
        if not valid then
            goto continue
        end
        
        -- 价格过滤
        local price = tonumber(itemData["价格"]) or 0
        if filters.minPrice and filters.minPrice.Text ~= "" then
            local minPrice = tonumber(filters.minPrice.Text) or 0
            if price < minPrice then
                valid = false
            end
        end
        if filters.maxPrice and filters.maxPrice.Text ~= "" then
            local maxPrice = tonumber(filters.maxPrice.Text) or 0
            if price > maxPrice then
                valid = false
            end
        end
        
        -- 翅膀判断（仅检查翅膀ID，不检查类型）
        if item["翅膀ID"] then
            -- 翅膀物品跳过等级检查
            if item["属性"] and #item["属性"] >= 3 then
                local wingAttrValue = filters.wingAttr and filters.wingAttr.Text or ""
                if wingAttrValue ~= "" then
                    local thirdAttr = item["属性"][3]["系数"] or 0
                    local minWingAttr = tonumber(wingAttrValue) or 0
                    if thirdAttr < minWingAttr then
                        valid = false
                    end
                end
            else
                -- 翅膀物品必须有至少3个属性
                valid = false
            end
        else
            -- 非翅膀物品进行等级过滤
            if item["等级"] then
                local level = tonumber(item["等级"]) or 0
                local minLevel = filters.minLevel and filters.minLevel.Text ~= "" and tonumber(filters.minLevel.Text) or nil
                local maxLevel = filters.maxLevel and filters.maxLevel.Text ~= "" and tonumber(filters.maxLevel.Text) or nil
                
                if minLevel and level < minLevel then
                    valid = false
                end
                if maxLevel and level > maxLevel then
                    valid = false
                end
            end
            
            -- 品质过滤（只有选中时才过滤）
            local wantMythic = filters.qualityMythic.Text == "[✓]"
            local wantEternal = filters.qualityEternal.Text == "[✓]"
            if wantMythic or wantEternal then
                local quality = tonumber(item["品质"]) or 0
                if not ((wantMythic and quality == 10) or (wantEternal and quality == 11)) then
                    valid = false
                end
            end
            
            -- 属性检查
            if filters.atkSpeed.Text == "[✓]" or filters.critRate.Text == "[✓]" then
                local hasAtkSpeed = false
                local hasCritRate = false
                
                if item["属性"] then
                    for _, attr in ipairs(item["属性"]) do
                        if attr["名称"] then
                            if string.find(attr["名称"], "攻击速度") then
                                hasAtkSpeed = true
                            elseif string.find(attr["名称"], "暴击概率") or string.find(attr["名称"], "暴击几率") then
                                hasCritRate = true
                            end
                        end
                    end
                end
                
                if (filters.atkSpeed.Text == "[✓]" and not hasAtkSpeed) or 
                   (filters.critRate.Text == "[✓]" and not hasCritRate) then
                    valid = false
                end
            end
        end
        
        if valid then
            filtered[itemId] = itemData
        end
        
        ::continue::
    end

    return filtered
end

-- 排序函数
local function SortItems(itemsArray, sortMode)
    table.sort(itemsArray, function(a, b)
        if sortMode == "price_asc" then
            return a.price < b.price
        elseif sortMode == "price_desc" then
            return a.price > b.price
        elseif sortMode == "level_asc" then
            return (a.level or 0) < (b.level or 0)
        elseif sortMode == "level_desc" then
            return (a.level or 0) > (b.level or 0)
        elseif sortMode == "name_asc" then
            return tostring(a.itemId) < tostring(b.itemId)
        end
        return false
    end)
end

local function OpenPlayerShop(playerName)
    local targetPlayer = Players:FindFirstChild(playerName)
    if targetPlayer then
        viewEvent:FireServer(targetPlayer)
        print("正在打开", playerName, "的商店...")
    else
        warn("玩家不存在或已离线:", playerName)
    end
end

-- 3. 显示结果
local function DisplayResults(scrollFrame, results, statsLabel)
    scrollFrame:ClearAllChildren()
    
    local yOffset = 0
    local totalItems = 0
    local totalSellers = {}
    
    -- 按分类显示结果
    for category, sellers in pairs(results) do
        local categoryLabel = Instance.new("TextLabel")
        categoryLabel.Text = string.format("───── %s ─────", category)
        categoryLabel.Size = UDim2.new(1, -10, 0, 35)
        categoryLabel.Position = UDim2.new(0, 5, 0, yOffset)
        categoryLabel.Font = Enum.Font.SourceSansBold
        categoryLabel.TextColor3 = COLOR_SCHEME.ACCENT
        categoryLabel.TextSize = 18
        categoryLabel.BackgroundTransparency = 1
        categoryLabel.Parent = scrollFrame
        yOffset = yOffset + 40
        
        -- 先收集所有物品以便排序
        local allItems = {}
        for sellerName, items in pairs(sellers) do
            if not totalSellers[sellerName] then
                totalSellers[sellerName] = true
            end
            for itemId, itemData in pairs(items) do
                local item = itemData["物品数据"]
                table.insert(allItems, {
                    sellerName = sellerName,
                    itemId = itemId,
                    itemData = itemData,
                    price = tonumber(itemData["价格"]) or 0,
                    level = tonumber(item["等级"]) or 0
                })
                totalItems = totalItems + 1
            end
        end
        
        -- 按选择的排序模式排序
        SortItems(allItems, sortMode)
        
        -- 显示排序后的物品
        for _, itemInfo in ipairs(allItems) do
            local sellerName = itemInfo.sellerName
            local itemId = itemInfo.itemId
            local itemData = itemInfo.itemData
            local item = itemData["物品数据"]
            local price = itemData["价格"] or "无"
            local favoriteKey = sellerName .. "_" .. itemId
            local isFavorite = favorites[favoriteKey] == true
            
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, -10, 0, 0)
            card.Position = UDim2.new(0, 5, 0, yOffset)
            card.BackgroundColor3 = isFavorite and Color3.fromRGB(65, 65, 90) or COLOR_SCHEME.ITEM_CARD
            card.BorderSizePixel = isFavorite and 2 or 0
            card.BorderColor3 = COLOR_SCHEME.FAVORITE
            card.AutomaticSize = Enum.AutomaticSize.Y
            card.Parent = scrollFrame
            
            -- 顶部标题行
            local header = Instance.new("Frame")
            header.Size = UDim2.new(1, 0, 0, 35)
            header.BackgroundColor3 = COLOR_SCHEME.HEADER
            header.Parent = card
            
            -- 收藏按钮
            local favoriteBtn = Instance.new("TextButton")
            favoriteBtn.Text = isFavorite and "★" or "☆"
            favoriteBtn.Size = UDim2.new(0, 30, 1, 0)
            favoriteBtn.Position = UDim2.new(0, 0, 0, 0)
            favoriteBtn.Font = Enum.Font.SourceSansBold
            favoriteBtn.TextSize = 20
            favoriteBtn.TextColor3 = isFavorite and COLOR_SCHEME.FAVORITE or Color3.fromRGB(150, 150, 150)
            favoriteBtn.BackgroundTransparency = 1
            favoriteBtn.Parent = header
            
            favoriteBtn.Activated:Connect(function()
                favorites[favoriteKey] = not favorites[favoriteKey]
                favoriteBtn.Text = favorites[favoriteKey] and "★" or "☆"
                favoriteBtn.TextColor3 = favorites[favoriteKey] and COLOR_SCHEME.FAVORITE or Color3.fromRGB(150, 150, 150)
                card.BackgroundColor3 = favorites[favoriteKey] and Color3.fromRGB(65, 65, 90) or COLOR_SCHEME.ITEM_CARD
                card.BorderSizePixel = favorites[favoriteKey] and 2 or 0
            end)
            
            -- 物品名称和价格
            local title = Instance.new("TextLabel")
            title.Text = string.format("%s | 价格: %s", itemId, price)
            title.Size = UDim2.new(0.6, -5, 1, 0)
            title.Position = UDim2.new(0, 35, 0, 0)
            title.TextXAlignment = Enum.TextXAlignment.Left
            -- 根据价格高低使用不同颜色
            local priceNum = tonumber(price) or 0
            if priceNum > 10000 then
                title.TextColor3 = Color3.fromRGB(255, 215, 0) -- 金色表示高价
            elseif priceNum > 1000 then
                title.TextColor3 = COLOR_SCHEME.POSITIVE -- 绿色表示中高价
            else
                title.TextColor3 = COLOR_SCHEME.TEXT_MAIN -- 白色表示低价
            end
            title.Font = Enum.Font.SourceSansSemibold
            title.TextSize = 18
            title.Parent = header
            
            -- 前往购买按钮
            local openShopBtn = Instance.new("TextButton")
            openShopBtn.Text = "前往购买"
            openShopBtn.Size = UDim2.new(0.25, -5, 0.8, 0)
            openShopBtn.Position = UDim2.new(0.75, 5, 0.1, 0)
            openShopBtn.Font = Enum.Font.SourceSansBold
            openShopBtn.TextSize = 16
            openShopBtn.TextColor3 = Color3.new(1, 1, 1)
            openShopBtn.BackgroundColor3 = COLOR_SCHEME.BUTTON
            openShopBtn.Parent = header
            
            -- 按钮悬停效果
            openShopBtn.MouseEnter:Connect(function()
                openShopBtn.BackgroundColor3 = COLOR_SCHEME.BUTTON_HOVER
            end)
            openShopBtn.MouseLeave:Connect(function()
                openShopBtn.BackgroundColor3 = COLOR_SCHEME.BUTTON
            end)
            
            -- 点击按钮打开对应商店
            openShopBtn.Activated:Connect(function()
                OpenPlayerShop(sellerName)
            end)
            
            -- 卖家信息行
            local sellerFrame = Instance.new("Frame")
            sellerFrame.Size = UDim2.new(1, 0, 0, 25)
            sellerFrame.Position = UDim2.new(0, 0, 0, 35)
            sellerFrame.BackgroundTransparency = 1
            sellerFrame.Parent = card
            
            local sellerIcon = Instance.new("ImageLabel")
            sellerIcon.Size = UDim2.new(0, 20, 0, 20)
            sellerIcon.Position = UDim2.new(0, 5, 0.5, -10)
            sellerIcon.Image = "rbxassetid://3926305904" -- 人物图标
            sellerIcon.ImageRectOffset = Vector2.new(124, 204)
            sellerIcon.ImageRectSize = Vector2.new(36, 36)
            sellerIcon.BackgroundTransparency = 1
            sellerIcon.Parent = sellerFrame
            
            local sellerLabel = Instance.new("TextLabel")
            sellerLabel.Text = "卖家: "..sellerName
            sellerLabel.Size = UDim2.new(1, -30, 1, 0)
            sellerLabel.Position = UDim2.new(0, 30, 0, 0)
            sellerLabel.TextXAlignment = Enum.TextXAlignment.Left
            sellerLabel.TextColor3 = COLOR_SCHEME.ACCENT
            sellerLabel.Font = Enum.Font.SourceSansSemibold
            sellerLabel.TextSize = 16
            sellerLabel.BackgroundTransparency = 1
            sellerLabel.Parent = sellerFrame
            
            -- 基本信息行
            local infoFrame = Instance.new("Frame")
            infoFrame.Size = UDim2.new(1, 0, 0, 30)
            infoFrame.Position = UDim2.new(0, 0, 0, 60)
            infoFrame.BackgroundTransparency = 1
            infoFrame.Parent = card
            
            local levelLabel = Instance.new("TextLabel")
            levelLabel.Text = string.format("等级: %s", item["等级"] or "无")
            levelLabel.Size = UDim2.new(0.5, -5, 1, 0)
            levelLabel.Position = UDim2.new(0, 5, 0, 0)
            levelLabel.TextXAlignment = Enum.TextXAlignment.Left
            levelLabel.TextColor3 = COLOR_SCHEME.TEXT_MAIN
            levelLabel.Font = Enum.Font.SourceSans
            levelLabel.TextSize = 16
            levelLabel.Parent = infoFrame
            
            -- 品质显示
            local qualityText = item["品质"] or "无"
            if item["品质"] and QUALITY_TYPES[tonumber(item["品质"])] then
                qualityText = string.format("%s(%s)", QUALITY_TYPES[tonumber(item["品质"])], item["品质"])
            end
            
            local qualityLabel = Instance.new("TextLabel")
            qualityLabel.Text = string.format("品质: %s", qualityText)
            qualityLabel.Size = UDim2.new(0.5, -5, 1, 0)
            qualityLabel.Position = UDim2.new(0.5, 5, 0, 0)
            qualityLabel.TextXAlignment = Enum.TextXAlignment.Left
            qualityLabel.TextColor3 = COLOR_SCHEME.TEXT_MAIN
            qualityLabel.Font = Enum.Font.SourceSans
            qualityLabel.TextSize = 16
            qualityLabel.Parent = infoFrame
            
            -- 翅膀ID显示（如果有）
            local attrY = 95
            if item["翅膀ID"] then
                local wingFrame = Instance.new("Frame")
                wingFrame.Size = UDim2.new(1, -10, 0, 25)
                wingFrame.Position = UDim2.new(0, 5, 0, 95)
                wingFrame.BackgroundTransparency = 1
                wingFrame.Parent = card
                
                local wingIcon = Instance.new("ImageLabel")
                wingIcon.Size = UDim2.new(0, 20, 0, 20)
                wingIcon.Position = UDim2.new(0, 0, 0.5, -10)
                wingIcon.Image = "rbxassetid://3926305904" -- 翅膀图标
                wingIcon.ImageRectOffset = Vector2.new(4, 844)
                wingIcon.ImageRectSize = Vector2.new(36, 36)
                wingIcon.BackgroundTransparency = 1
                wingIcon.Parent = wingFrame
                
                local wingLabel = Instance.new("TextLabel")
                wingLabel.Text = string.format("翅膀ID: %s", item["翅膀ID"])
                wingLabel.Size = UDim2.new(1, -25, 1, 0)
                wingLabel.Position = UDim2.new(0, 25, 0, 0)
                wingLabel.TextXAlignment = Enum.TextXAlignment.Left
                wingLabel.TextColor3 = COLOR_SCHEME.ACCENT
                wingLabel.Font = Enum.Font.SourceSansSemibold
                wingLabel.TextSize = 16
                wingLabel.Parent = wingFrame
                
                attrY = 125
            end
            
            -- 属性列表
            if item["属性"] then
                for _, attr in ipairs(item["属性"]) do
                    local attrFrame = Instance.new("Frame")
                    attrFrame.Size = UDim2.new(1, -10, 0, 25)
                    attrFrame.Position = UDim2.new(0, 5, 0, attrY)
                    attrFrame.BackgroundTransparency = 1
                    attrFrame.Parent = card
                    
                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.Text = attr["名称"] or "未知属性"
                    nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
                    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                    nameLabel.TextColor3 = COLOR_SCHEME.TEXT_MAIN
                    nameLabel.Font = Enum.Font.SourceSans
                    nameLabel.TextSize = 16
                    nameLabel.Parent = attrFrame
                    
                    local valueLabel = Instance.new("TextLabel")
                    valueLabel.Text = string.format("系数: %.3f", attr["系数"] or 0)
                    valueLabel.Size = UDim2.new(0.4, 0, 1, 0)
                    valueLabel.Position = UDim2.new(0.6, 0, 0, 0)
                    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
                    valueLabel.TextColor3 = COLOR_SCHEME.TEXT_SECONDARY
                    valueLabel.Font = Enum.Font.SourceSans
                    valueLabel.TextSize = 16
                    valueLabel.Parent = attrFrame
                    
                    attrY = attrY + 30
                end
            end
            
            yOffset = yOffset + attrY + 15
        end
    end
    
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 15)
    
    -- 更新统计信息
    if statsLabel then
        local sellerCount = 0
        for _ in pairs(totalSellers) do
            sellerCount = sellerCount + 1
        end
        statsLabel.Text = string.format("物品: %d | 卖家: %d", totalItems, sellerCount)
    end
end

-- 4. 自动扫描系统
local scanConnection = nil

local function StartAutoScan(ui)
    if isScanning then return end
    
    local allPlayers = Players:GetPlayers()
    if #allPlayers == 0 then
        ui.progressLabel.Text = "没有找到其他玩家"
        return
    end
    
    isScanning = true
    currentPlayerIndex = 1
    allPlayersData = {}
    ui.progressLabel.Text = string.format("扫描中: 1/%d", #allPlayers)
    ui.scanButton.Text = "停止扫描"
    
    -- 断开之前的连接（如果存在）
    if scanConnection then
        scanConnection:Disconnect()
        scanConnection = nil
    end
    
    -- 数据接收处理
    scanConnection = viewEvent.OnClientEvent:Connect(function(player, playerData, shopData)
        if not isScanning then 
            if scanConnection then
                scanConnection:Disconnect()
                scanConnection = nil
            end
            return 
        end
        
        -- 存储数据
        if shopData and type(shopData) == "table" then
            allPlayersData[player.Name] = shopData
            print("已扫描:", player.Name)
        end
        
        -- 继续扫描下一个
        currentPlayerIndex = currentPlayerIndex + 1
        if currentPlayerIndex <= #allPlayers then
            ui.progressLabel.Text = string.format("扫描中: %d/%d", currentPlayerIndex, #allPlayers)
            viewEvent:FireServer(allPlayers[currentPlayerIndex])
            task.wait(scanInterval)
        else
            -- 扫描完成
            isScanning = false
            ui.progressLabel.Text = string.format("扫描完成: %d个商店", #allPlayers)
            ui.scanButton.Text = "开始扫描所有商店"
            
            if scanConnection then
                scanConnection:Disconnect()
                scanConnection = nil
            end
            
            -- 自动应用过滤
            local filteredResults = {}
            for sellerName, shopData in pairs(allPlayersData) do
                if type(shopData) == "table" then
                    for category, items in pairs(shopData) do
                        if type(items) == "table" then
                            if not filteredResults[category] then
                                filteredResults[category] = {}
                            end
                            filteredResults[category][sellerName] = FilterItems(items, ui.controls, searchText)
                        end
                    end
                end
            end
            DisplayResults(ui.resultsScroll, filteredResults, ui.statsLabel)
        end
    end)
    
    -- 开始扫描第一个玩家
    viewEvent:FireServer(allPlayers[1])
end

-- 5. 停止扫描
local function StopAutoScan(ui)
    isScanning = false
    ui.progressLabel.Text = "扫描已停止"
    ui.scanButton.Text = "开始扫描所有商店"
    
    -- 断开扫描连接
    if scanConnection then
        scanConnection:Disconnect()
        scanConnection = nil
    end
end

-- 6. 显示收藏列表
local function ShowFavorites(ui)
    local favoriteResults = {}
    
    for sellerName, shopData in pairs(allPlayersData) do
        if type(shopData) == "table" then
            for category, items in pairs(shopData) do
                if type(items) == "table" then
                    local favoriteItems = {}
                    for itemId, itemData in pairs(items) do
                        local favoriteKey = sellerName .. "_" .. itemId
                        if favorites[favoriteKey] then
                            favoriteItems[itemId] = itemData
                        end
                    end
                    if next(favoriteItems) then
                        if not favoriteResults[category] then
                            favoriteResults[category] = {}
                        end
                        favoriteResults[category][sellerName] = favoriteItems
                    end
                end
            end
        end
    end
    
    DisplayResults(ui.resultsScroll, favoriteResults, ui.statsLabel)
end

-- 7. 初始化系统
local ui = CreateCompleteUI()

-- 数据接收（用于手动查看，仅在非扫描模式下处理）
local manualConnection = viewEvent.OnClientEvent:Connect(function(player, _, shopData)
    if not isScanning then
        if shopData and type(shopData) == "table" then
            allPlayersData[player.Name] = shopData
            print("收到", player.Name, "的商店数据")
        end
    end
end)

-- 搜索框事件
ui.searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    searchText = ui.searchBox.Text
    -- 实时搜索
    if not isScanning then
        ui.filterButton.Activated:Fire()
    end
end)

-- 过滤按钮
ui.filterButton.Activated:Connect(function()
    searchText = ui.searchBox.Text
    local filteredResults = {}
    for sellerName, shopData in pairs(allPlayersData) do
        if type(shopData) == "table" then
            for category, items in pairs(shopData) do
                if type(items) == "table" then
                    if not filteredResults[category] then
                        filteredResults[category] = {}
                    end
                    filteredResults[category][sellerName] = FilterItems(items, ui.controls, searchText)
                end
            end
        end
    end
    DisplayResults(ui.resultsScroll, filteredResults, ui.statsLabel)
    print("过滤完成")
end)

-- 重置按钮
ui.resetButton.Activated:Connect(function()
    ui.controls.minLevel.Text = "1"
    ui.controls.maxLevel.Text = "100"
    ui.controls.minPrice.Text = ""
    ui.controls.maxPrice.Text = ""
    ui.controls.wingAttr.Text = "1.0"
    ui.controls.atkSpeed.Text = "[ ]"
    ui.controls.critRate.Text = "[ ]"
    ui.controls.qualityMythic.Text = "[ ]"
    ui.controls.qualityEternal.Text = "[ ]"
    ui.searchBox.Text = ""
    searchText = ""
    print("已重置过滤条件")
end)

-- 收藏按钮
ui.favoriteButton.Activated:Connect(function()
    ShowFavorites(ui)
    print("显示收藏列表")
end)

-- 扫描按钮
ui.scanButton.Activated:Connect(function()
    if isScanning then
        StopAutoScan(ui)
    else
        StartAutoScan(ui)
    end
end)

-- 自动刷新按钮
ui.autoRefreshButton.Activated:Connect(function()
    autoRefreshEnabled = not autoRefreshEnabled
    ui.autoRefreshButton.Text = string.format("自动刷新: %s", autoRefreshEnabled and "开启" or "关闭")
    ui.autoRefreshButton.BackgroundColor3 = autoRefreshEnabled and COLOR_SCHEME.POSITIVE or Color3.fromRGB(80, 80, 80)
    if autoRefreshEnabled then
        lastRefreshTime = tick()
    end
end)

-- 自动刷新循环
coroutine.wrap(function()
    while ui.screenGui.Parent do
        task.wait(1)
        if autoRefreshEnabled and not isScanning then
            local currentTime = tick()
            if currentTime - lastRefreshTime >= autoRefreshInterval then
                print("自动刷新扫描...")
                StartAutoScan(ui)
                lastRefreshTime = currentTime
            end
        end
    end
end)()

-- 初始请求自己的商店数据
viewEvent:FireServer(Players.LocalPlayer)
print("高级物品过滤系统已启动")
