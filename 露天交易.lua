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

-- 通用品质ID映射（1-13）
local QUALITY_TYPES = {
    [1] = "普通",
    [2] = "良好",
    [3] = "坚固",
    [4] = "稀有",
    [5] = "完美",
    [6] = "稀少",
    [7] = "史诗",
    [8] = "传奇",
    [9] = "不朽",
    [10] = "神话",
    [11] = "永恒",
    [12] = "神器",
    [13] = "太初"
}

-- 生成通用品质下拉框选项
local function GetQualityOptions()
    local options = {{text = "全部", value = "all"}}
    for i = 1, 13 do
        table.insert(options, {
            text = string.format("%d-%s", i, QUALITY_TYPES[i] or tostring(i)),
            value = tostring(i)
        })
    end
    return options
end

-- 符石类别映射
local RUNE_TYPE_NAMES = {
    [1] = "太阳",
    [2] = "木",
    [3] = "水",
    [4] = "火",
    [5] = "土"
}

-- 装备类型映射
local EQUIP_TYPE_NAMES = {
    [1] = "头盔",
    [2] = "项链",
    [3] = "卷轴",
    [4] = "腰带",
    [5] = "裤子",
    [6] = "手套",
    [7] = "护甲",
    [8] = "鞋子",
    [9] = "挂坠",
    [10] = "戒指",
    [11] = "翅膀"
}

-- 挂饰类型映射
local ACCESSORY_TYPE_NAMES = {
    [1001] = "肉(血量加成)",
    [1002] = "攻击力加成",
    [1003] = "攻击速度",
    [1004] = "熊猫(血量恢复)",
    [1005] = "技能伤害",
    [1006] = "法宝伤害",
    [1007] = "反弹伤害概率",
    [1008] = "反弹伤害",
    [1011] = "鱼骨头(暴击概率)",
    [1012] = "鲸鱼(暴击伤害)",
    [1013] = "闪避概率",
    [1014] = "忽视闪避概率",
    [1015] = "金币加成",
    [1016] = "星星(经验加成)",
    [1017] = "矿灯(矿石加成)"
}

-- 从数据文件读取所有符文属性名称（已统计并硬编码）
-- 从ShopData文件夹中读取至少10个文件统计得到的符石属性名称列表
-- 已去重并按字母顺序排序
local function LoadRuneAttributeNames()
    return {
        "Boss减伤",
        "Boss伤害",
        "暴击概率",
        "暴击伤害",
        "反弹概率",
        "反弹伤害",
        "攻击力百分比",
        "攻击速度百分比",
        "技能伤害",
        "金币额外获取",
        "经验额外获取",
        "忽视闪避概率",
        "生命恢复百分比",
        "生命值百分比",
        "闪避概率",
        "法宝伤害"
    }
end

-- 全局变量
local allPlayersData = {} -- 存储所有玩家数据
local currentPlayerIndex = 1
local isScanning = false
local scanInterval = 0 --扫描间隔(秒)（极速优化：不等待）
local viewEvent = ReplicatedStorage:WaitForChild("事件"):WaitForChild("公用"):WaitForChild("露天商店"):WaitForChild("查看")
local buyItemEvent = ReplicatedStorage:WaitForChild("\228\186\139\228\187\182"):WaitForChild("\229\133\172\231\148\168"):WaitForChild("\233\156\178\229\164\169\229\149\134\229\186\151"):WaitForChild("\232\180\173\228\185\176\231\137\169\229\147\129")
-- 已移除收藏列表功能
local priceAlerts = {} -- 价格提醒列表
local searchText = "" -- 搜索文本
local sortMode = "price_asc" -- 排序模式: price_asc, price_desc, level_asc, level_desc, name_asc
local filterWingsOnly = false -- 仅显示翅膀
local filterRunesOnly = false -- 仅显示符石
local currentPage = "全部" -- 当前页面：全部、装备、符石、配饰、宠物、宠物蛋
local scanTimeout = 0.5 -- 扫描超时时间(秒)（极速优化）
local lastDataCount = 0 -- 上次数据数量
local lastDataTime = 0 -- 上次数据更新时间
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

    -- 左侧过滤面板（调整位置，避免被按钮挡住）
    local filterScroll = Instance.new("ScrollingFrame")
    filterScroll.Size = UDim2.new(0.35, -5, 1, -210)
    filterScroll.Position = UDim2.new(0, 5, 0, 100)
    filterScroll.BackgroundColor3 = COLOR_SCHEME.PANEL
    filterScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    filterScroll.ScrollBarThickness = 8
    filterScroll.Parent = contentFrame

    -- 右侧结果面板（调整位置，为页面标签留出空间）
    local resultsScroll = Instance.new("ScrollingFrame")
    resultsScroll.Size = UDim2.new(0.65, -10, 1, -200)
    resultsScroll.Position = UDim2.new(0.35, 5, 0, 100)
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

    -- 底部按钮区域（调整位置，避免与页面标签重叠）
    local buttonFrame = Instance.new("Frame")
    buttonFrame.Size = UDim2.new(1, -10, 0, 50)
    buttonFrame.Position = UDim2.new(0, 5, 0, 45)
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
    resetButton.Size = UDim2.new(0.5, -5, 1, 0)
    resetButton.Position = UDim2.new(0.5, 2, 0, 0)
    resetButton.Font = Enum.Font.SourceSansBold
    resetButton.TextSize = 18
    resetButton.TextColor3 = COLOR_SCHEME.TEXT_MAIN
    resetButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    resetButton.Parent = buttonFrame


    -- 页面标签区域
    local pageFrame = Instance.new("Frame")
    pageFrame.Size = UDim2.new(1, -10, 0, 40)
    pageFrame.Position = UDim2.new(0, 5, 0, 0)
    pageFrame.BackgroundTransparency = 1
    pageFrame.Parent = contentFrame
    
    local pages = {"全部", "装备", "符石", "配饰", "宠物", "宠物蛋"}
    local pageButtons = {}
    for i, pageName in ipairs(pages) do
        local pageBtn = Instance.new("TextButton")
        pageBtn.Text = pageName
        pageBtn.Size = UDim2.new(1 / #pages, -2, 1, 0)
        pageBtn.Position = UDim2.new((i - 1) / #pages, (i - 1) * 2, 0, 0)
        pageBtn.Font = Enum.Font.SourceSansBold
        pageBtn.TextSize = 16
        pageBtn.TextColor3 = COLOR_SCHEME.TEXT_MAIN
        pageBtn.BackgroundColor3 = (pageName == "全部") and COLOR_SCHEME.ACCENT or Color3.fromRGB(80, 80, 80)
        pageBtn.Parent = pageFrame
        pageButtons[pageName] = pageBtn
        
        pageBtn.MouseEnter:Connect(function()
            if currentPage ~= pageName then
                pageBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            end
        end)
        pageBtn.MouseLeave:Connect(function()
            if currentPage ~= pageName then
                pageBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            end
        end)
    end

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
    progressLabel.Size = UDim2.new(0.66, -5, 1, 0)
    progressLabel.Position = UDim2.new(0.33, 2, 0, 0)
    progressLabel.TextXAlignment = Enum.TextXAlignment.Left
    progressLabel.TextColor3 = COLOR_SCHEME.TEXT_MAIN
    progressLabel.Font = Enum.Font.SourceSans
    progressLabel.TextSize = 16
    progressLabel.BackgroundTransparency = 1
    progressLabel.Parent = scanFrame

    -- 鼠标悬停效果
    scanButton.MouseEnter:Connect(function()
        scanButton.BackgroundColor3 = COLOR_SCHEME.BUTTON_HOVER
    end)
    scanButton.MouseLeave:Connect(function()
        scanButton.BackgroundColor3 = COLOR_SCHEME.BUTTON
    end)


    -- 动态过滤界面容器（先创建）
    local filterContainer = Instance.new("Frame")
    filterContainer.Size = UDim2.new(1, 0, 1, 0)
    filterContainer.BackgroundTransparency = 1
    filterContainer.Parent = filterScroll

    -- 添加过滤控件
    local yOffset = 10
    local controls = {}

    local function AddFilterRow(labelText, inputType, defaultValue, container, currentYOffset)
        if not container then
            container = filterContainer
        end
        if not currentYOffset then
            currentYOffset = yOffset
        end
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, -10, 0, 40)
        frame.Position = UDim2.new(0, 5, 0, currentYOffset)
        frame.BackgroundTransparency = 1
        frame.Parent = container

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
        elseif inputType == "dropdown" then
            -- 创建下拉框
            local dropdownButton = Instance.new("TextButton")
            dropdownButton.Size = UDim2.new(0.5, 0, 1, 0)
            dropdownButton.Position = UDim2.new(0.5, 0, 0, 0)
            dropdownButton.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
            dropdownButton.TextColor3 = COLOR_SCHEME.TEXT_MAIN
            dropdownButton.Font = Enum.Font.SourceSans
            dropdownButton.TextSize = 16
            dropdownButton.TextXAlignment = Enum.TextXAlignment.Left
            dropdownButton.TextYAlignment = Enum.TextYAlignment.Center
            dropdownButton.TextWrapped = false
            dropdownButton.AutoButtonColor = false
            dropdownButton.BorderSizePixel = 0
            -- defaultValue 是一个表，包含 default 和 options
            local defaultText = "全部"
            if type(defaultValue) == "table" and defaultValue.default then
                defaultText = defaultValue.default
            elseif type(defaultValue) == "string" then
                defaultText = defaultValue
            end
            dropdownButton.Text = defaultText
            dropdownButton.Parent = frame
            
            -- 添加内边距（使用TextLabel覆盖）
            local textPadding = Instance.new("UIPadding")
            textPadding.PaddingLeft = UDim.new(0, 5)
            textPadding.PaddingRight = UDim.new(0, 5)
            textPadding.Parent = dropdownButton
            
            -- 下拉菜单容器（放在ScreenGui层级以确保ZIndex正确）
            local screenGui = filterScroll:FindFirstAncestorOfClass("ScreenGui")
            local dropdownFrame = Instance.new("Frame")
            dropdownFrame.Size = UDim2.new(0, 0, 0, 0)
            dropdownFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
            dropdownFrame.BorderSizePixel = 1
            dropdownFrame.BorderColor3 = COLOR_SCHEME.ACCENT
            dropdownFrame.Visible = false
            dropdownFrame.ZIndex = 100
            dropdownFrame.Parent = screenGui
            
            local dropdownScroll = Instance.new("ScrollingFrame")
            dropdownScroll.Size = UDim2.new(1, 0, 1, 0)
            dropdownScroll.BackgroundTransparency = 1
            dropdownScroll.BorderSizePixel = 0
            dropdownScroll.ScrollBarThickness = 4
            dropdownScroll.Parent = dropdownFrame
            
            local dropdownLayout = Instance.new("UIListLayout")
            dropdownLayout.SortOrder = Enum.SortOrder.LayoutOrder
            dropdownLayout.Parent = dropdownScroll
            
            -- 存储选项和当前值
            local options = {}
            local currentValue = "all"
            local currentText = "全部"
            
            -- 处理 defaultValue
            if type(defaultValue) == "table" then
                options = defaultValue.options or {}
                local defaultVal = defaultValue.default or "all"
                currentValue = defaultVal
                currentText = "全部"  -- 默认显示文本
                
                -- 查找默认值对应的选项（支持 value 或 text）
                for _, option in ipairs(options) do
                    if option.value == defaultVal then
                        currentValue = option.value
                        currentText = option.text
                        break
                    elseif option.text == defaultVal then
                        currentValue = option.value
                        currentText = option.text
                        break
                    end
                end
            end
            
            dropdownButton.Text = currentText
            
            -- 更新下拉框位置和大小的函数（在 options 定义之后）
            local function updateDropdown()
                local buttonPos = dropdownButton.AbsolutePosition
                local buttonSize = dropdownButton.AbsoluteSize
                local optionHeight = math.min(#options * 30, 150)
                dropdownFrame.Size = UDim2.new(0, buttonSize.X, 0, optionHeight)
                dropdownFrame.Position = UDim2.new(0, buttonPos.X, 0, buttonPos.Y + buttonSize.Y + 2)
            end
            
            -- 创建选项按钮
            local function createOption(text, value)
                local optionButton = Instance.new("TextButton")
                optionButton.Size = UDim2.new(1, 0, 0, 30)
                optionButton.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
                optionButton.TextColor3 = COLOR_SCHEME.TEXT_MAIN
                optionButton.Font = Enum.Font.SourceSans
                optionButton.TextSize = 14
                optionButton.Text = text
                optionButton.TextXAlignment = Enum.TextXAlignment.Left
                optionButton.TextYAlignment = Enum.TextYAlignment.Center
                optionButton.TextWrapped = false
                optionButton.AutoButtonColor = false
                optionButton.BorderSizePixel = 0
                optionButton.ZIndex = 101
                optionButton.Parent = dropdownScroll
                
                -- 添加内边距
                local optionPadding = Instance.new("UIPadding")
                optionPadding.PaddingLeft = UDim.new(0, 5)
                optionPadding.PaddingRight = UDim.new(0, 5)
                optionPadding.Parent = optionButton
                
                optionButton.MouseEnter:Connect(function()
                    optionButton.BackgroundColor3 = Color3.fromRGB(80, 80, 95)
                end)
                optionButton.MouseLeave:Connect(function()
                    optionButton.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
                end)
                
                optionButton.Activated:Connect(function()
                    currentValue = value
                    dropdownButton.Text = text
                    dropdownFrame.Visible = false
                end)
                
                return optionButton
            end
            
            -- 添加选项
            for _, option in ipairs(options) do
                createOption(option.text, option.value)
            end
            
            -- 更新下拉框大小
            dropdownScroll.CanvasSize = UDim2.new(0, 0, 0, #options * 30)
            
            -- 点击按钮切换下拉框
            dropdownButton.Activated:Connect(function()
                updateDropdown()
                dropdownFrame.Visible = not dropdownFrame.Visible
            end)
            
            -- 监听窗口大小变化
            filterScroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                if dropdownFrame.Visible then
                    updateDropdown()
                end
            end)
            
            -- 点击外部关闭下拉框
            UserInputService.InputBegan:Connect(function(input, gameProcessed)
                if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton1 then
                    if dropdownFrame.Visible then
                        local mousePos = UserInputService:GetMouseLocation()
                        local framePos = dropdownFrame.AbsolutePosition
                        local frameSize = dropdownFrame.AbsoluteSize
                        local buttonPos = dropdownButton.AbsolutePosition
                        local buttonSize = dropdownButton.AbsoluteSize
                        
                        -- 检查是否点击在下拉框或按钮外部
                        local inFrame = mousePos.X >= framePos.X and mousePos.X <= framePos.X + frameSize.X and
                                       mousePos.Y >= framePos.Y and mousePos.Y <= framePos.Y + frameSize.Y
                        local inButton = mousePos.X >= buttonPos.X and mousePos.X <= buttonPos.X + buttonSize.X and
                                        mousePos.Y >= buttonPos.Y and mousePos.Y <= buttonPos.Y + buttonSize.Y
                        
                        if not inFrame and not inButton then
                            dropdownFrame.Visible = false
                        end
                    end
                end
            end)
            
            -- 存储获取当前值的方法
            input = {
                Button = dropdownButton,
                Frame = dropdownFrame,
                GetValue = function()
                    return currentValue
                end,
                SetValue = function(value)
                    for _, option in ipairs(options) do
                        if option.value == value then
                            currentValue = value
                            dropdownButton.Text = option.text
                            break
                        end
                    end
                end
            }
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
        
        if type(input) == "table" then
            -- 下拉框已经创建，不需要parent
        else
        input.Parent = frame
        end

        yOffset = yOffset + 45
        return input
    end

    -- 存储各页面的过滤控件
    controls.pageFilters = {}
    
    -- 存储各页面的过滤界面容器
    local pageFilterContainers = {}
    
    -- 创建页面过滤界面容器
    local function CreatePageFilterContainer(pageName)
        if pageFilterContainers[pageName] then
            return pageFilterContainers[pageName]
        end
        
        local container = Instance.new("Frame")
        container.Size = UDim2.new(1, 0, 1, 0)
        container.BackgroundTransparency = 1
        container.Visible = false
        container.Parent = filterContainer
        pageFilterContainers[pageName] = container
        return container
    end
    
    -- 切换显示页面过滤界面
    local function ShowPageFilterContainer(pageName)
        for name, container in pairs(pageFilterContainers) do
            container.Visible = (name == pageName)
        end
        -- 更新滚动区域大小
        if controls.pageFilters[pageName] and pageFilterContainers[pageName] then
            local maxY = 10
            for _, child in ipairs(pageFilterContainers[pageName]:GetChildren()) do
                if child:IsA("Frame") then
                    local childY = child.Position.Y.Offset + child.Size.Y.Offset
                    if childY > maxY then
                        maxY = childY
                    end
                end
            end
            filterScroll.CanvasSize = UDim2.new(0, 0, 0, maxY + 10)
        end
    end
    
    -- 创建装备页面过滤界面
    local function CreateEquipFilters()
        local pageName = "装备"
        local container = CreatePageFilterContainer(pageName)
        
        if not controls.pageFilters[pageName] then
            controls.pageFilters[pageName] = {}
            local pageControls = controls.pageFilters[pageName]
            local localYOffset = 10
            
            pageControls.minLevel = AddFilterRow("最低等级:", "text", "1", container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.maxLevel = AddFilterRow("最高等级:", "text", "100", container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.minPrice = AddFilterRow("最低价格:", "text", "", container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.maxPrice = AddFilterRow("最高价格:", "text", "", container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.filterWings = AddFilterRow("仅显示翅膀", "checkbox", false, container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.atkSpeed = AddFilterRow("需要攻击速度", "checkbox", false, container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.critRate = AddFilterRow("需要暴击概率", "checkbox", false, container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.critDamage = AddFilterRow("需要暴击伤害", "checkbox", false, container, localYOffset)
            localYOffset = localYOffset + 45
            -- 翅膀第三个词条系数过滤
            pageControls.wingThirdAttr = AddFilterRow("翅膀第三个词条系数:", "text", "", container, localYOffset)
            localYOffset = localYOffset + 45
            -- 装备类型过滤
            local equipTypeOptions = {{text = "全部", value = "all"}}
            for i = 1, 11 do
                table.insert(equipTypeOptions, {
                    text = string.format("%d-%s", i, EQUIP_TYPE_NAMES[i] or tostring(i)),
                    value = tostring(i)
                })
            end
            pageControls.equipType = AddFilterRow("装备类型:", "dropdown", {
                default = "all",
                options = equipTypeOptions
            }, container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.quality = AddFilterRow("装备品质:", "dropdown", {
                default = "all",
                options = GetQualityOptions()
            }, container, localYOffset)
            localYOffset = localYOffset + 45
            
            filterScroll.CanvasSize = UDim2.new(0, 0, 0, localYOffset + 10)
        end
        
        ShowPageFilterContainer(pageName)
    end
    
    -- 创建符石页面过滤界面
    local function CreateRuneFilters()
        local pageName = "符石"
        local container = CreatePageFilterContainer(pageName)
        
        if not controls.pageFilters[pageName] then
            controls.pageFilters[pageName] = {}
            local pageControls = controls.pageFilters[pageName]
            local localYOffset = 10
            
            -- 读取符文属性名称
            local runeAttrNames = LoadRuneAttributeNames()
            local runeAttrOptions = {{text = "全部", value = "all"}}
            for _, attrName in ipairs(runeAttrNames) do
                table.insert(runeAttrOptions, {text = attrName, value = attrName})
            end
            
            pageControls.minPrice = AddFilterRow("最低价格:", "text", "", container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.maxPrice = AddFilterRow("最高价格:", "text", "", container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.quality = AddFilterRow("符石品质:", "dropdown", {
                default = "all",
                options = GetQualityOptions()
            }, container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.type = AddFilterRow("符石类型:", "dropdown", {
                default = "all",
                options = {
                    {text = "全部", value = "all"},
                    {text = "1-太阳", value = "1"},
                    {text = "2-木", value = "2"},
                    {text = "3-水", value = "3"},
                    {text = "4-火", value = "4"},
                    {text = "5-土", value = "5"}
                }
            }, container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.attrName = AddFilterRow("符石属性名称:", "dropdown", {
                default = "all",
                options = runeAttrOptions
            }, container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.attrCount = AddFilterRow("该属性条数≥:", "text", "", container, localYOffset)
            localYOffset = localYOffset + 45
            
            filterScroll.CanvasSize = UDim2.new(0, 0, 0, localYOffset + 10)
        end
        
        ShowPageFilterContainer(pageName)
    end
    
    -- 创建挂饰页面过滤界面
    local function CreateAccessoryFilters()
        local pageName = "配饰"
        local container = CreatePageFilterContainer(pageName)
        
        if not controls.pageFilters[pageName] then
            controls.pageFilters[pageName] = {}
            local pageControls = controls.pageFilters[pageName]
            local localYOffset = 10
            
            local accessoryTypeOptions = {{text = "全部", value = "all"}}
            local typeIds = {1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1011, 1012, 1013, 1014, 1015, 1016, 1017}
            for _, typeId in ipairs(typeIds) do
                table.insert(accessoryTypeOptions, {
                    text = string.format("%d-%s", typeId, ACCESSORY_TYPE_NAMES[typeId] or tostring(typeId)),
                    value = tostring(typeId)
                })
            end
            
            local originalYOffset = yOffset
            yOffset = localYOffset
            
            pageControls.minPrice = AddFilterRow("最低价格:", "text", "", container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.maxPrice = AddFilterRow("最高价格:", "text", "", container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.quality = AddFilterRow("挂饰品质:", "dropdown", {
                default = "all",
                options = GetQualityOptions()
            }, container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.type = AddFilterRow("挂饰类型:", "dropdown", {
                default = "all",
                options = accessoryTypeOptions
            }, container, localYOffset)
            localYOffset = localYOffset + 45
            
            filterScroll.CanvasSize = UDim2.new(0, 0, 0, localYOffset + 10)
        end
        
        ShowPageFilterContainer(pageName)
    end
    
    -- 创建宠物页面过滤界面（暂不填充）
    local function CreatePetFilters()
        local pageName = "宠物"
        local container = CreatePageFilterContainer(pageName)
        
        if not controls.pageFilters[pageName] then
            controls.pageFilters[pageName] = {}
        end
        
        ShowPageFilterContainer(pageName)
        filterScroll.CanvasSize = UDim2.new(0, 0, 0, 10)
    end
    
    -- 创建宠物蛋页面过滤界面（暂不填充）
    local function CreatePetEggFilters()
        local pageName = "宠物蛋"
        local container = CreatePageFilterContainer(pageName)
        
        if not controls.pageFilters[pageName] then
            controls.pageFilters[pageName] = {}
        end
        
        ShowPageFilterContainer(pageName)
        filterScroll.CanvasSize = UDim2.new(0, 0, 0, 10)
    end
    
    -- 创建全部页面过滤界面（显示所有通用过滤）
    local function CreateAllFilters()
        local pageName = "全部"
        local container = CreatePageFilterContainer(pageName)
        
        if not controls.pageFilters[pageName] then
            controls.pageFilters[pageName] = {}
            local pageControls = controls.pageFilters[pageName]
            local localYOffset = 10
            
            local originalYOffset = yOffset
            yOffset = localYOffset
            
            pageControls.minPrice = AddFilterRow("最低价格:", "text", "", container, localYOffset)
            localYOffset = localYOffset + 45
            pageControls.maxPrice = AddFilterRow("最高价格:", "text", "", container, localYOffset)
            localYOffset = localYOffset + 45
            
            filterScroll.CanvasSize = UDim2.new(0, 0, 0, localYOffset + 10)
        end
        
        ShowPageFilterContainer(pageName)
    end
    
    -- 页面过滤界面映射（存储到controls中以便外部访问）
    controls.pageFilterCreators = {
        ["全部"] = CreateAllFilters,
        ["装备"] = CreateEquipFilters,
        ["符石"] = CreateRuneFilters,
        ["配饰"] = CreateAccessoryFilters,
        ["宠物"] = CreatePetFilters,
        ["宠物蛋"] = CreatePetEggFilters
    }
    
    -- 初始化显示"全部"页面
    CreateAllFilters()

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
        statsLabel = statsLabel,
        sortDropdown = sortDropdown,
        pageButtons = pageButtons
    }
end

-- 读取ShopData文件夹中的数据
-- 合并相同属性的符石属性（系数相加）
local function MergeRuneAttributes(attributes)
    if not attributes or type(attributes) ~= "table" then
        return {}
    end
    
    local merged = {}
    for _, attr in ipairs(attributes) do
        if attr["名称"] then
            local name = attr["名称"]
            local value = tonumber(attr["系数"]) or 0
            if merged[name] then
                merged[name] = merged[name] + value
            else
                merged[name] = value
            end
        end
    end
    
    -- 转换为数组格式
    local result = {}
    for name, totalValue in pairs(merged) do
        table.insert(result, {
            ["名称"] = name,
            ["系数"] = totalValue
        })
    end
    
    -- 按系数降序排序
    table.sort(result, function(a, b)
        return (a["系数"] or 0) > (b["系数"] or 0)
    end)
    
    return result
end

-- 保存商店数据到文件（用于debug）

-- 获取物品名称
local function GetItemName(item, itemId)
    -- 符石：显示类型
    if item["类型"] and item["属性"] then
        local runeType = tonumber(item["类型"]) or 0
        local typeName = RUNE_TYPE_NAMES[runeType] or tostring(runeType)
        return string.format("符石-%s", typeName)
    end
    
    -- 翅膀：显示翅膀ID
    if item["翅膀ID"] then
        return string.format("翅膀ID:%s", item["翅膀ID"])
    end
    
    -- 配饰：显示ID
    if item["id"] then
        return string.format("配饰ID:%s", item["id"])
    end
    
    -- 宠物：显示ID
    if item["id"] and item["资质"] then
        return string.format("宠物ID:%s", item["id"])
    end
    
    -- 其他名称字段
    if item["名称"] then
        return item["名称"]
    elseif item["名字"] then
        return item["名字"]
    elseif item["name"] then
        return item["name"]
    else
        return tostring(itemId)
    end
end

-- 2. 物品过滤逻辑
local function FilterItems(items, uiControls, searchQuery, category)
    -- 获取当前页面的过滤控件
    local filters = uiControls.pageFilters and uiControls.pageFilters[category] or {}
    local filtered = {}
    
    for itemId, itemData in pairs(items) do
        local item = itemData["物品数据"]
        local valid = true
        
        -- 根据分类应用不同的过滤逻辑
        if category == "装备" then
            -- 装备过滤逻辑
            local filterWings = filters.filterWings and filters.filterWings.Text == "[✓]"
            
            -- 翅膀过滤：如果开启仅显示翅膀，则只显示翅膀；如果关闭，则剔除翅膀
            if filterWings then
                if not item["翅膀ID"] then
                    valid = false
                end
            else
                -- 关闭时剔除翅膀
                if item["翅膀ID"] then
                valid = false
            end
            end
            
            -- 如果仅翅膀过滤不匹配，跳过后续检查
            if valid then
                -- 搜索过滤
                if searchQuery and searchQuery ~= "" then
                    local searchLower = string.lower(searchQuery)
                    local itemIdLower = string.lower(tostring(itemId))
                    local itemName = GetItemName(item, itemId)
                    local itemNameLower = string.lower(tostring(itemName))
                    local sellerName = ""
                    if itemData["卖家"] then
                        sellerName = string.lower(tostring(itemData["卖家"]))
                    end
                    if not (string.find(itemIdLower, searchLower) or 
                            string.find(itemNameLower, searchLower) or 
                            string.find(sellerName, searchLower)) then
                        valid = false
                    end
                end
                
                -- 如果搜索不匹配，跳过后续检查
                if valid then
                    -- 价格过滤
                    local price = tonumber(itemData["价格"]) or 0
                    if filters.minPrice and filters.minPrice.Text ~= "" then
                        local minPrice = tonumber(filters.minPrice.Text) or 0
                        if price < minPrice then
                            valid = false
                        end
                    end
                    if valid and filters.maxPrice and filters.maxPrice.Text ~= "" then
                        local maxPrice = tonumber(filters.maxPrice.Text) or 0
                        if price > maxPrice then
                            valid = false
                        end
                    end
                    
                    -- 等级过滤
                    if valid and item["等级"] then
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
            
            -- 装备类型过滤
            if valid and filters.equipType then
                local equipTypeFilter = filters.equipType.GetValue and filters.equipType.GetValue() or "all"
                if equipTypeFilter ~= "all" then
                    local itemType = tonumber(item["类型"]) or 0
                    local filterType = tonumber(equipTypeFilter)
                    if itemType ~= filterType then
                        valid = false
                    end
                end
            end
            
            -- 品质过滤
            if valid and filters.quality then
                local qualityFilter = filters.quality.GetValue and filters.quality.GetValue() or "all"
                if qualityFilter ~= "all" then
                    local quality = tonumber(item["品质"]) or 0
                    local filterQuality = tonumber(qualityFilter)
                    if quality ~= filterQuality then
                        valid = false
                    end
                end
            end
            
            -- 属性检查
                    if valid then
                        local needAtkSpeed = filters.atkSpeed and filters.atkSpeed.Text == "[✓]"
                        local needCritRate = filters.critRate and filters.critRate.Text == "[✓]"
                        local needCritDamage = filters.critDamage and filters.critDamage.Text == "[✓]"
                        
                        if needAtkSpeed or needCritRate or needCritDamage then
                            local hasAtkSpeed = false
                            local hasCritRate = false
                            local hasCritDamage = false
                
                if item["属性"] then
                    for _, attr in ipairs(item["属性"]) do
                        if attr["名称"] then
                            if string.find(attr["名称"], "攻击速度") then
                                hasAtkSpeed = true
                                        elseif string.find(attr["名称"], "暴击概率") or string.find(attr["名称"], "暴击几率") then
                                hasCritRate = true
                                        elseif string.find(attr["名称"], "暴击伤害") then
                                            hasCritDamage = true
                            end
                        end
                    end
                end
                
                            if (needAtkSpeed and not hasAtkSpeed) or 
                               (needCritRate and not hasCritRate) or 
                               (needCritDamage and not hasCritDamage) then
                    valid = false
                end
                        end
                        
                        -- 翅膀第三个词条系数过滤
                        if valid and item["翅膀ID"] and filters.wingThirdAttr then
                            local minCoefficient = filters.wingThirdAttr.Text ~= "" and tonumber(filters.wingThirdAttr.Text) or nil
                            if minCoefficient then
                                if item["属性"] and #item["属性"] >= 3 then
                                    local thirdAttr = item["属性"][3]
                                    local coefficient = thirdAttr and thirdAttr["系数"] or 0
                                    if coefficient < minCoefficient then
                                        valid = false
                                    end
                                else
                                    -- 如果翅膀没有第三个属性，则不匹配
                                    valid = false
                                end
                            end
                        end
                    end
                end
            end
        elseif category == "符石" then
            -- 符石过滤逻辑
            if not item["类型"] or not item["属性"] then
                valid = false
            else
                -- 搜索过滤
                if searchQuery and searchQuery ~= "" then
                    local searchLower = string.lower(searchQuery)
                    local itemIdLower = string.lower(tostring(itemId))
                    local itemName = GetItemName(item, itemId)
                    local itemNameLower = string.lower(tostring(itemName))
                    local sellerName = ""
                    if itemData["卖家"] then
                        sellerName = string.lower(tostring(itemData["卖家"]))
                    end
                    if not (string.find(itemIdLower, searchLower) or 
                            string.find(itemNameLower, searchLower) or 
                            string.find(sellerName, searchLower)) then
                        valid = false
            end
        end
        
        if valid then
                    -- 价格过滤
                    local price = tonumber(itemData["价格"]) or 0
                    if filters.minPrice and filters.minPrice.Text ~= "" then
                        local minPrice = tonumber(filters.minPrice.Text) or 0
                        if price < minPrice then
                            valid = false
                        end
                    end
                    if valid and filters.maxPrice and filters.maxPrice.Text ~= "" then
                        local maxPrice = tonumber(filters.maxPrice.Text) or 0
                        if price > maxPrice then
                            valid = false
        end
    end

                    -- 符石品质过滤
                    if valid and filters.quality then
                        local qualityFilter = filters.quality.GetValue and filters.quality.GetValue() or "all"
                        if qualityFilter ~= "all" then
                            local quality = tonumber(item["品质"]) or 0
                            local filterQuality = tonumber(qualityFilter)
                            if quality ~= filterQuality then
                                valid = false
                            end
                        end
                    end
                    
                    -- 符石类型过滤
                    if valid and filters.type then
                        local typeFilter = filters.type.GetValue and filters.type.GetValue() or "all"
                        if typeFilter ~= "all" then
                            local itemType = tonumber(item["类型"]) or 0
                            local filterType = tonumber(typeFilter)
                            if itemType ~= filterType then
                                valid = false
                            end
                        end
                    end
                    
                    -- 符石特定属性条数过滤
                    if valid and filters.attrName then
                        local attrNameFilter = filters.attrName.GetValue and filters.attrName.GetValue() or "all"
                        if attrNameFilter ~= "all" then
                            local minCount = tonumber(filters.attrCount and filters.attrCount.Text or "0") or 0
                            -- 如果未输入条数，默认至少需要1条
                            if minCount == 0 then
                                minCount = 1
                            end
                            
                            if item["属性"] then
                                local count = 0
                                for _, attr in ipairs(item["属性"]) do
                                    if attr["名称"] and attr["名称"] == attrNameFilter then
                                        count = count + 1
                                    end
                                end
                                if count < minCount then
                                    valid = false
                                end
                            else
                                -- 如果没有属性数组，且要求至少1条，则过滤掉
                                if minCount > 0 then
                                    valid = false
                                end
                            end
                        end
                    end
                end
            end
        elseif category == "配饰" then
            -- 配饰过滤逻辑
            -- 搜索过滤
            if searchQuery and searchQuery ~= "" then
                local searchLower = string.lower(searchQuery)
                local itemIdLower = string.lower(tostring(itemId))
                local itemName = GetItemName(item, itemId)
                local itemNameLower = string.lower(tostring(itemName))
                local sellerName = ""
                if itemData["卖家"] then
                    sellerName = string.lower(tostring(itemData["卖家"]))
                end
                if not (string.find(itemIdLower, searchLower) or 
                        string.find(itemNameLower, searchLower) or 
                        string.find(sellerName, searchLower)) then
                    valid = false
                end
            end
            
            if valid then
                -- 价格过滤
                local price = tonumber(itemData["价格"]) or 0
                if filters.minPrice and filters.minPrice.Text ~= "" then
                    local minPrice = tonumber(filters.minPrice.Text) or 0
                    if price < minPrice then
                        valid = false
                    end
                end
                if valid and filters.maxPrice and filters.maxPrice.Text ~= "" then
                    local maxPrice = tonumber(filters.maxPrice.Text) or 0
                    if price > maxPrice then
                        valid = false
                    end
                end
                
                -- 配饰品质过滤
                if valid and filters.quality then
                    local qualityFilter = filters.quality.GetValue and filters.quality.GetValue() or "all"
                    if qualityFilter ~= "all" then
                        local quality = tonumber(item["品质"]) or 0
                        local filterQuality = tonumber(qualityFilter)
                        if quality ~= filterQuality then
                            valid = false
                        end
                    end
                end
                
                -- 配饰类型过滤
                if valid and filters.type then
                    local typeFilter = filters.type.GetValue and filters.type.GetValue() or "all"
                    if typeFilter ~= "all" then
                        local itemIdNum = tonumber(item["id"]) or 0
                        local filterType = tonumber(typeFilter)
                        if itemIdNum ~= filterType then
                            valid = false
                        end
                    end
                end
            end
        elseif category == "宠物" or category == "宠物蛋" then
            -- 宠物和宠物蛋：仅搜索和价格过滤
            if searchQuery and searchQuery ~= "" then
                local searchLower = string.lower(searchQuery)
                local itemIdLower = string.lower(tostring(itemId))
                local itemName = GetItemName(item, itemId)
                local itemNameLower = string.lower(tostring(itemName))
                local sellerName = ""
                if itemData["卖家"] then
                    sellerName = string.lower(tostring(itemData["卖家"]))
                end
                if not (string.find(itemIdLower, searchLower) or 
                        string.find(itemNameLower, searchLower) or 
                        string.find(sellerName, searchLower)) then
                    valid = false
                end
            end
            
            if valid then
                local price = tonumber(itemData["价格"]) or 0
                if filters.minPrice and filters.minPrice.Text ~= "" then
                    local minPrice = tonumber(filters.minPrice.Text) or 0
                    if price < minPrice then
                        valid = false
                    end
                end
                if valid and filters.maxPrice and filters.maxPrice.Text ~= "" then
                    local maxPrice = tonumber(filters.maxPrice.Text) or 0
                    if price > maxPrice then
                        valid = false
                    end
                end
            end
        elseif category == "全部" or not category then
            -- 全部页面：仅搜索和价格过滤
            if searchQuery and searchQuery ~= "" then
                local searchLower = string.lower(searchQuery)
                local itemIdLower = string.lower(tostring(itemId))
                local itemName = GetItemName(item, itemId)
                local itemNameLower = string.lower(tostring(itemName))
                local sellerName = ""
                if itemData["卖家"] then
                    sellerName = string.lower(tostring(itemData["卖家"]))
                end
                if not (string.find(itemIdLower, searchLower) or 
                        string.find(itemNameLower, searchLower) or 
                        string.find(sellerName, searchLower)) then
                    valid = false
                end
            end
            
            if valid then
                local price = tonumber(itemData["价格"]) or 0
                local allFilters = uiControls.pageFilters and uiControls.pageFilters["全部"] or {}
                if allFilters.minPrice and allFilters.minPrice.Text ~= "" then
                    local minPrice = tonumber(allFilters.minPrice.Text) or 0
                    if price < minPrice then
                        valid = false
                    end
                end
                if valid and allFilters.maxPrice and allFilters.maxPrice.Text ~= "" then
                    local maxPrice = tonumber(allFilters.maxPrice.Text) or 0
                    if price > maxPrice then
                        valid = false
                    end
                end
            end
        end
        
        if valid then
            filtered[itemId] = itemData
        end
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

-- 购买物品函数
local function BuyItem(sellerName, category, itemId, price, item)
    local success, err = pcall(function()
        -- 获取卖家玩家对象
        local seller = Players:FindFirstChild(sellerName)
        if not seller then
            error("找不到卖家: " .. tostring(sellerName))
        end
        
        -- 获取物品识别ID（UUID）
        local uuid = item["索引"] or item.Index or item.id or tostring(itemId)
        if not uuid then
            error("找不到物品识别ID")
        end
        
        -- 确定物品类型（购买参数的第二参数）
        local itemType = "\233\133\141\233\165\176"  -- 默认是挂饰
        if category == "装备" then
            itemType = "\232\163\133\229\164\135"  -- 装备
        elseif category == "符石" then
            itemType = "\231\172\172\231\155\174"  -- 符石
        elseif category == "配饰" then
            itemType = "\233\133\141\233\165\176"  -- 挂饰
        elseif category == "宠物" then
            itemType = "\229\174\160\231\137\169"  -- 宠物
        elseif category == "宠物蛋" then
            itemType = "\229\174\160\231\137\169\232\154\140"  -- 宠物蛋
        elseif category == "丹药" then
            itemType = "\228\184\185\232\141\175"  -- 丹药
        end
        
        -- 构建购买参数（完全按照挂饰自动购买脚本的格式）
        local args = {
            seller,
            itemType,
            {
                ["\228\187\183\230\160\188"] = tonumber(price) or 0,
                ["\231\137\169\229\147\129\231\180\162\229\188\149"] = tostring(uuid)
            }
        }
        
        -- 发送购买请求
        buyItemEvent:FireServer(unpack(args))
        
        return true
    end)
    
    if success then
        print(string.format("✓ 购买请求已发送: %s 的物品 (ID: %s) 价格: %s", sellerName, tostring(itemId), tostring(price)))
        return true
    else
        warn("✗ 购买失败:", err)
        return false
    end
end

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
    
    -- 检查所有分类是否都为空
    for category, items in pairs(shopData) do
        if type(items) == "table" then
            -- 如果是数组，检查长度
            if #items > 0 then
                return false
            end
            -- 如果是字典，检查是否有任何键
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

-- 3. 显示结果（优化版本：批量渲染）
local function DisplayResults(scrollFrame, results, statsLabel)
    scrollFrame:ClearAllChildren()
    
    local yOffset = 0
    local totalItems = 0
    local totalSellers = {}
    
    -- 先收集所有要显示的物品数据
    local allItemsToRender = {}
    
    -- 按分类收集结果
    for category, sellers in pairs(results) do
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
        
        -- 添加到渲染列表
        table.insert(allItemsToRender, {
            category = category,
            items = allItems
        })
    end
    
    -- 批量渲染：每次渲染一部分，避免卡顿
    local itemsPerFrame = 5 -- 每帧渲染5个物品
    local currentIndex = 1
    local currentCategoryIndex = 1
    local currentItemIndex = 1
    
    local renderConnection
    renderConnection = RunService.Heartbeat:Connect(function()
        local rendered = 0
        
        while rendered < itemsPerFrame and currentCategoryIndex <= #allItemsToRender do
            local categoryData = allItemsToRender[currentCategoryIndex]
            
            -- 如果是新分类，先创建分类标签
            if currentItemIndex == 1 then
                local categoryLabel = Instance.new("TextLabel")
                categoryLabel.Text = string.format("───── %s ─────", categoryData.category)
                categoryLabel.Size = UDim2.new(1, -10, 0, 35)
                categoryLabel.Position = UDim2.new(0, 5, 0, yOffset)
                categoryLabel.Font = Enum.Font.SourceSansBold
                categoryLabel.TextColor3 = COLOR_SCHEME.ACCENT
                categoryLabel.TextSize = 18
                categoryLabel.BackgroundTransparency = 1
                categoryLabel.Parent = scrollFrame
                yOffset = yOffset + 40
            end
            
            -- 渲染当前分类的物品
            while currentItemIndex <= #categoryData.items and rendered < itemsPerFrame do
                local itemInfo = categoryData.items[currentItemIndex]
            local sellerName = itemInfo.sellerName
            local itemId = itemInfo.itemId
            local itemData = itemInfo.itemData
            local item = itemData["物品数据"]
            local price = itemData["价格"] or "无"
            
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, -10, 0, 0)
            card.Position = UDim2.new(0, 5, 0, yOffset)
            card.BackgroundColor3 = COLOR_SCHEME.ITEM_CARD
            card.BorderSizePixel = 0
            card.AutomaticSize = Enum.AutomaticSize.Y
            card.Parent = scrollFrame
            
            -- 顶部标题行
            local header = Instance.new("Frame")
            header.Size = UDim2.new(1, 0, 0, 35)
            header.BackgroundColor3 = COLOR_SCHEME.HEADER
            header.Parent = card
            
            -- 物品名称和价格
            local itemName = GetItemName(item, itemId)
            -- 如果名称已经包含ID信息（如符石类型、翅膀ID等），则不重复显示ID
            local displayName = itemName
            if not string.find(itemName, "类型") and not string.find(itemName, "ID:") and itemName ~= tostring(itemId) then
                displayName = string.format("%s (%s)", itemName, itemId)
            end
            local title = Instance.new("TextLabel")
            title.Text = string.format("%s | 价格: %s", displayName, price)
            title.Size = UDim2.new(0.65, -5, 1, 0)  -- 减小宽度以容纳两个按钮
            title.Position = UDim2.new(0, 5, 0, 0)
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
            
            -- 购买按钮（直接购买）
            local buyBtn = Instance.new("TextButton")
            buyBtn.Text = "购买"
            buyBtn.Size = UDim2.new(0.16, -3, 0.8, 0)
            buyBtn.Position = UDim2.new(0.66, 3, 0.1, 0)
            buyBtn.Font = Enum.Font.SourceSansBold
            buyBtn.TextSize = 14
            buyBtn.TextColor3 = Color3.new(1, 1, 1)
            buyBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)  -- 绿色表示购买
            buyBtn.Parent = header
            
            -- 购买按钮悬停效果
            buyBtn.MouseEnter:Connect(function()
                buyBtn.BackgroundColor3 = Color3.fromRGB(0, 230, 120)
            end)
            buyBtn.MouseLeave:Connect(function()
                buyBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
            end)
            
            -- 点击购买按钮直接购买
            buyBtn.Activated:Connect(function()
                BuyItem(sellerName, categoryData.category, itemId, price, item)
            end)
            
            -- 前往购买按钮（打开商店）
            local openShopBtn = Instance.new("TextButton")
            openShopBtn.Text = "商店"
            openShopBtn.Size = UDim2.new(0.16, -3, 0.8, 0)
            openShopBtn.Position = UDim2.new(0.83, 3, 0.1, 0)
            openShopBtn.Font = Enum.Font.SourceSansBold
            openShopBtn.TextSize = 14
            openShopBtn.TextColor3 = Color3.new(1, 1, 1)
            openShopBtn.BackgroundColor3 = COLOR_SCHEME.BUTTON
            openShopBtn.Parent = header
            
            -- 前往购买按钮悬停效果
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
                local attributes = item["属性"]
                
                -- 如果是符石，合并相同属性
                if item["类型"] then
                    attributes = MergeRuneAttributes(attributes)
                    -- 显示符石类型
                    local typeFrame = Instance.new("Frame")
                    typeFrame.Size = UDim2.new(1, -10, 0, 25)
                    typeFrame.Position = UDim2.new(0, 5, 0, attrY)
                    typeFrame.BackgroundTransparency = 1
                    typeFrame.Parent = card
                    
                    local typeLabel = Instance.new("TextLabel")
                    local runeType = tonumber(item["类型"]) or 0
                    local typeName = RUNE_TYPE_NAMES[runeType] or tostring(runeType)
                    typeLabel.Text = string.format("符石类型: %s (%d)", typeName, runeType)
                    typeLabel.Size = UDim2.new(1, 0, 1, 0)
                    typeLabel.TextXAlignment = Enum.TextXAlignment.Left
                    typeLabel.TextColor3 = COLOR_SCHEME.ACCENT
                    typeLabel.Font = Enum.Font.SourceSansSemibold
                    typeLabel.TextSize = 16
                    typeLabel.BackgroundTransparency = 1
                    typeLabel.Parent = typeFrame
                    
                    attrY = attrY + 30
                end
                
                for _, attr in ipairs(attributes) do
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
            
            -- 配饰属性显示（id和系数）
            if item["id"] and not item["类型"] and not item["属性"] then
                -- 这是配饰，显示配饰类型和系数
                local accessoryId = tonumber(item["id"]) or 0
                local accessoryName = ACCESSORY_TYPE_NAMES[accessoryId] or string.format("未知类型(%d)", accessoryId)
                local coefficient = item["系数"] or 0
                
                local accessoryFrame = Instance.new("Frame")
                accessoryFrame.Size = UDim2.new(1, -10, 0, 25)
                accessoryFrame.Position = UDim2.new(0, 5, 0, attrY)
                accessoryFrame.BackgroundTransparency = 1
                accessoryFrame.Parent = card
                
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Text = string.format("类型: %s (ID:%d)", accessoryName, accessoryId)
                nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.TextColor3 = COLOR_SCHEME.ACCENT
                nameLabel.Font = Enum.Font.SourceSansSemibold
                nameLabel.TextSize = 16
                nameLabel.BackgroundTransparency = 1
                nameLabel.Parent = accessoryFrame
                
                local valueLabel = Instance.new("TextLabel")
                valueLabel.Text = string.format("系数: %.4f", coefficient)
                valueLabel.Size = UDim2.new(0.4, 0, 1, 0)
                valueLabel.Position = UDim2.new(0.6, 0, 0, 0)
                valueLabel.TextXAlignment = Enum.TextXAlignment.Right
                valueLabel.TextColor3 = COLOR_SCHEME.TEXT_SECONDARY
                valueLabel.Font = Enum.Font.SourceSans
                valueLabel.TextSize = 16
                valueLabel.BackgroundTransparency = 1
                valueLabel.Parent = accessoryFrame
                
                attrY = attrY + 30
            end
            
            yOffset = yOffset + attrY + 15
                
                currentItemIndex = currentItemIndex + 1
                rendered = rendered + 1
            end
            
            -- 如果当前分类渲染完成，移动到下一个分类
            if currentItemIndex > #categoryData.items then
                currentCategoryIndex = currentCategoryIndex + 1
                currentItemIndex = 1
        end
    end
    
        -- 更新CanvasSize（每帧更新一次，避免频繁计算）
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset + 15)
        
        -- 更新统计信息（只在最后更新一次）
        if currentCategoryIndex > #allItemsToRender and statsLabel then
            local sellerCount = 0
            for _ in pairs(totalSellers) do
                sellerCount = sellerCount + 1
            end
            statsLabel.Text = string.format("物品: %d | 卖家: %d", totalItems, sellerCount)
        end
        
        -- 如果所有物品都渲染完成，断开连接
        if currentCategoryIndex > #allItemsToRender then
            if renderConnection then
                renderConnection:Disconnect()
            end
        end
    end)
end

-- 4. 自动扫描系统
local scanConnection = nil
local currentScanPlayer = nil
local scanStartTime = 0
local lastReceivedPlayer = nil -- 上次收到数据的玩家

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
    lastDataCount = 0
    lastDataTime = tick()
    lastReceivedPlayer = nil
    ui.progressLabel.Text = string.format("扫描中: 1/%d", #allPlayers)
    ui.scanButton.Text = "停止扫描"
    
    -- 断开之前的连接（如果存在）
    if scanConnection then
        scanConnection:Disconnect()
        scanConnection = nil
    end
    
    -- 超时检测循环（极速优化）
    local timeoutCheck = coroutine.wrap(function()
        while isScanning do
            task.wait(0.1)  -- 减少检测间隔（极速优化：从1秒减少到0.1秒）
            local currentTime = tick()
            local dataCount = 0
            for _ in pairs(allPlayersData) do
                dataCount = dataCount + 1
            end
            
            -- 检查是否超时（当前玩家没有收到数据）
            if currentScanPlayer and (currentTime - scanStartTime) > scanTimeout then
                -- 检查是否收到了当前玩家的数据
                if lastReceivedPlayer ~= currentScanPlayer.Name then
                    -- 没有收到当前玩家的数据，直接跳过（不等待界面，不关闭界面）
                    print("扫描超时，跳过:", currentScanPlayer.Name)
                    ui.progressLabel.Text = string.format("超时跳过: %s", currentScanPlayer.Name)
                    -- 不关闭界面，直接继续下一个（极速优化）
                    currentPlayerIndex = currentPlayerIndex + 1
                    if currentPlayerIndex <= #allPlayers then
                        currentScanPlayer = allPlayers[currentPlayerIndex]
                        lastReceivedPlayer = nil -- 重置接收状态
                        viewEvent:FireServer(currentScanPlayer)
                        scanStartTime = tick()
                    end
                else
                    -- 已收到当前玩家的数据
                    lastDataCount = dataCount
                    lastDataTime = currentTime
                end
            end
        end
    end)
    timeoutCheck()
    
    -- 数据接收处理
    scanConnection = viewEvent.OnClientEvent:Connect(function(player, playerData, shopData)
        if not isScanning then 
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
                lastDataTime = tick()
            else
            allPlayersData[player.Name] = shopData
                lastDataCount = lastDataCount + 1
                lastDataTime = tick()
            print("已扫描:", player.Name)
            end
        else
            -- shopData为空或无效，但已经收到响应，说明商店可能真的为空
            print(string.format("收到空响应，跳过: %s", player.Name))
            lastDataTime = tick()
        end
        
        -- 不关闭界面，收到数据立即继续下一个（极速优化）
        currentPlayerIndex = currentPlayerIndex + 1
        if currentPlayerIndex <= #allPlayers then
            -- 移除等待间隔（极速优化：收到数据立即继续下一个）
            ui.progressLabel.Text = string.format("扫描中: %d/%d", currentPlayerIndex, #allPlayers)
            currentScanPlayer = allPlayers[currentPlayerIndex]
            lastReceivedPlayer = nil -- 重置接收状态
            viewEvent:FireServer(currentScanPlayer)
            scanStartTime = tick()
        else
            -- 扫描完成
            isScanning = false
            currentScanPlayer = nil
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
                            filteredResults[category][sellerName] = FilterItems(items, ui.controls, searchText, category)
                end
            end
                end
            end
            
            -- 应用页面过滤
            local categoryMap = {
                ["全部"] = nil,
                ["装备"] = "装备",
                ["符石"] = "符石",
                ["配饰"] = "配饰",
                ["宠物"] = "宠物",
                ["宠物蛋"] = "宠物蛋"
            }
            local targetCategory = categoryMap[currentPage]
            local pageFilteredResults = {}
            if targetCategory then
                if filteredResults[targetCategory] then
                    pageFilteredResults[targetCategory] = filteredResults[targetCategory]
                end
            else
                pageFilteredResults = filteredResults
            end
            
            DisplayResults(ui.resultsScroll, pageFilteredResults, ui.statsLabel)
        end
    end)
    
    -- 开始扫描第一个玩家
    currentScanPlayer = allPlayers[1]
    lastReceivedPlayer = nil -- 重置接收状态
    scanStartTime = tick()
    viewEvent:FireServer(currentScanPlayer)
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
-- 已移除收藏列表功能

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

-- 页面切换函数
local function SwitchPage(pageName)
    currentPage = pageName
    -- 更新按钮状态
    for name, btn in pairs(ui.pageButtons) do
        if name == pageName then
            btn.BackgroundColor3 = COLOR_SCHEME.ACCENT
        else
            btn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        end
    end
    -- 切换过滤界面
    if ui.controls.pageFilterCreators and ui.controls.pageFilterCreators[pageName] then
        ui.controls.pageFilterCreators[pageName]()
    end
    -- 自动应用过滤
    ui.filterButton.Activated:Fire()
end

-- 页面按钮事件
for pageName, pageBtn in pairs(ui.pageButtons) do
    pageBtn.Activated:Connect(function()
        SwitchPage(pageName)
    end)
end

-- 过滤按钮
ui.filterButton.Activated:Connect(function()
    searchText = ui.searchBox.Text
    local filteredResults = {}
    
    -- 根据当前页面过滤分类
    local categoryMap = {
        ["全部"] = nil,  -- 显示所有分类
        ["装备"] = "装备",
        ["符石"] = "符石",
        ["配饰"] = "配饰",
        ["宠物"] = "宠物",
        ["宠物蛋"] = "宠物蛋"
    }
    local targetCategory = categoryMap[currentPage]
    
    for sellerName, shopData in pairs(allPlayersData) do
        if type(shopData) == "table" then
        for category, items in pairs(shopData) do
                -- 如果指定了页面，只处理对应分类
                if not targetCategory or category == targetCategory then
                    if type(items) == "table" then
            if not filteredResults[category] then
                filteredResults[category] = {}
            end
                        filteredResults[category][sellerName] = FilterItems(items, ui.controls, searchText, category)
        end
    end
            end
        end
    end
    DisplayResults(ui.resultsScroll, filteredResults, ui.statsLabel)
    print("过滤完成")
end)

-- 重置按钮
ui.resetButton.Activated:Connect(function()
    -- 重置当前页面的过滤控件
    local pageFilters = ui.controls.pageFilters and ui.controls.pageFilters[currentPage] or {}
    
    if currentPage == "装备" then
        if pageFilters.minLevel then pageFilters.minLevel.Text = "1" end
        if pageFilters.maxLevel then pageFilters.maxLevel.Text = "100" end
        if pageFilters.minPrice then pageFilters.minPrice.Text = "" end
        if pageFilters.maxPrice then pageFilters.maxPrice.Text = "" end
        if pageFilters.filterWings then pageFilters.filterWings.Text = "[ ]" end
        if pageFilters.atkSpeed then pageFilters.atkSpeed.Text = "[ ]" end
        if pageFilters.critRate then pageFilters.critRate.Text = "[ ]" end
        if pageFilters.critDamage then pageFilters.critDamage.Text = "[ ]" end
        if pageFilters.wingThirdAttr then pageFilters.wingThirdAttr.Text = "" end
        if pageFilters.equipType and pageFilters.equipType.SetValue then
            pageFilters.equipType.SetValue("all")
        end
        if pageFilters.quality and pageFilters.quality.SetValue then
            pageFilters.quality.SetValue("all")
        end
    elseif currentPage == "符石" then
        if pageFilters.minPrice then pageFilters.minPrice.Text = "" end
        if pageFilters.maxPrice then pageFilters.maxPrice.Text = "" end
        if pageFilters.quality and pageFilters.quality.SetValue then
            pageFilters.quality.SetValue("all")
        end
        if pageFilters.type and pageFilters.type.SetValue then
            pageFilters.type.SetValue("all")
        end
        if pageFilters.attrName and pageFilters.attrName.SetValue then
            pageFilters.attrName.SetValue("all")
        end
        if pageFilters.attrCount then pageFilters.attrCount.Text = "" end
    elseif currentPage == "配饰" then
        if pageFilters.minPrice then pageFilters.minPrice.Text = "" end
        if pageFilters.maxPrice then pageFilters.maxPrice.Text = "" end
        if pageFilters.quality and pageFilters.quality.SetValue then
            pageFilters.quality.SetValue("all")
        end
        if pageFilters.type and pageFilters.type.SetValue then
            pageFilters.type.SetValue("all")
        end
    elseif currentPage == "全部" then
        if pageFilters.minPrice then pageFilters.minPrice.Text = "" end
        if pageFilters.maxPrice then pageFilters.maxPrice.Text = "" end
    end
    
    ui.searchBox.Text = ""
    searchText = ""
    print("已重置过滤条件")
    -- 自动应用过滤
    ui.filterButton.Activated:Fire()
end)

-- 收藏按钮
-- 已移除收藏列表功能

-- 扫描按钮
ui.scanButton.Activated:Connect(function()
    if isScanning then
        StopAutoScan(ui)
    else
        StartAutoScan(ui)
    end
end)


-- 初始请求自己的商店数据
viewEvent:FireServer(Players.LocalPlayer)
print("高级物品过滤系统已启动")
