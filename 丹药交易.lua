local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

-- 确保玩家已加载
local player = Players.LocalPlayer
repeat task.wait() until player:IsDescendantOf(game)

-- 丹药类型映射
local elixirTypes = {
    [1] = "攻击",
    [2] = "爆伤", 
    [3] = "法宝",
    [4] = "血量",
    [5] = "技能"
}

-- 品质点数映射
local qualityPoints = {
    [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5,
    [6] = 6, [7] = 8, [8] = 10, [9] = 14, [10] = 20,
    [11] = 28
}

-- 创建UI界面
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ElixirTradeMaster"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

-- 检测是否为手机设备
local isMobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

-- 根据设备类型设置UI尺寸
local baseWidth = isMobile and 0.95 or 450
local baseHeight = isMobile and 0.7 or 520
local isPercentageSize = isMobile

-- 主框架
local mainFrame = Instance.new("Frame")
mainFrame.Size = isMobile and UDim2.new(baseWidth, 0, baseHeight, 0) or UDim2.new(0, baseWidth, 0, baseHeight)
mainFrame.Position = isMobile and UDim2.new(0.5, 0, 0.5, 0) or UDim2.new(0.5, -baseWidth/2, 0.5, -baseHeight/2)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- 标题栏（可拖动和折叠）
local titleBarHeight = isMobile and 50 or 40
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, titleBarHeight)
titleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
titleBar.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Text = "丹药交易大师"..(isMobile and "" or " v1.0")
title.Size = UDim2.new(1, -90, 1, 0) -- 为按钮留出空间
title.Font = Enum.Font.SourceSansBold
title.TextSize = isMobile and 22 or 20
title.TextColor3 = Color3.new(1, 1, 1)
title.BackgroundTransparency = 1
title.Parent = titleBar

-- 折叠按钮
local toggleButton = Instance.new("TextButton")
toggleButton.Text = "_"
toggleButton.Size = UDim2.new(0, 40, 1, 0)
toggleButton.Position = UDim2.new(1, -90, 0, 0)
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextSize = isMobile and 22 or 20
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
toggleButton.Parent = titleBar

-- 关闭按钮
local closeButton = Instance.new("TextButton")
closeButton.Text = "X"
closeButton.Size = UDim2.new(0, 40, 1, 0)
closeButton.Position = UDim2.new(1, -40, 0, 0)
closeButton.Font = Enum.Font.SourceSansBold
closeButton.TextSize = isMobile and 22 or 20
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.Parent = titleBar

-- 内容框架（可折叠部分）
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, 0, 1, -titleBarHeight)
contentFrame.Position = UDim2.new(0, 0, 0, titleBarHeight)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- 如果是手机设备，添加滚动功能
if isMobile then
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Size = UDim2.new(1, 0, 1, 0)
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 800) -- 根据内容自动调整
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.Parent = contentFrame
    
    -- 创建容器存放所有内容
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 800) -- 高度会在后面调整
    container.BackgroundTransparency = 1
    container.Parent = scrollFrame
    
    contentFrame = container -- 将内容放入滚动框内
end

-- 总点数显示
local totalPointsLabel = Instance.new("TextLabel")
totalPointsLabel.Text = "全部丹药总点数: 计算中..."
totalPointsLabel.Size = UDim2.new(0.95, 0, 0, isMobile and 40 or 30)
totalPointsLabel.Position = UDim2.new(0.025, 0, 0, 5)
totalPointsLabel.Font = Enum.Font.SourceSansSemibold
totalPointsLabel.TextSize = isMobile and 18 or 16
totalPointsLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
totalPointsLabel.BackgroundTransparency = 1
totalPointsLabel.TextXAlignment = Enum.TextXAlignment.Left
totalPointsLabel.Parent = contentFrame

-- 创建5个输入框和点数显示
local inputFrames = {}
local pointsLabels = {}
for i = 1, 5 do
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.95, 0, 0, isMobile and 90 or 70)
    frame.Position = UDim2.new(0.025, 0, 0, 50 + (i-1)*(isMobile and 95 or 75))
    frame.BackgroundTransparency = 1
    frame.Parent = contentFrame
    
    local typeLabel = Instance.new("TextLabel")
    typeLabel.Text = elixirTypes[i].."丹药:"
    typeLabel.Size = UDim2.new(1, 0, 0, isMobile and 30 or 25)
    typeLabel.Font = Enum.Font.SourceSansSemibold
    typeLabel.TextSize = isMobile and 18 or 16
    typeLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    typeLabel.TextXAlignment = Enum.TextXAlignment.Left
    typeLabel.BackgroundTransparency = 1
    typeLabel.Parent = frame
    
    local pointsLabel = Instance.new("TextLabel")
    pointsLabel.Name = "Points_"..i
    pointsLabel.Text = "总点数: 0"
    pointsLabel.Size = UDim2.new(1, 0, 0, isMobile and 25 or 20)
    pointsLabel.Position = UDim2.new(0, 0, 0, isMobile and 30 or 25)
    pointsLabel.Font = Enum.Font.SourceSans
    pointsLabel.TextSize = isMobile and 16 or 14
    pointsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
    pointsLabel.BackgroundTransparency = 1
    pointsLabel.Parent = frame
    pointsLabels[i] = pointsLabel
    
    local textBox = Instance.new("TextBox")
    textBox.Name = "Input_"..i
    textBox.Size = UDim2.new(1, 0, 0, isMobile and 40 or 30)
    textBox.Position = UDim2.new(0, 0, 0, isMobile and 55 or 45)
    textBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    textBox.TextColor3 = Color3.new(1, 1, 1) 
    textBox.PlaceholderText = "输入"..elixirTypes[i].."丹药需求点数"
    textBox.Text = ""
    textBox.FontSize = isMobile and Enum.FontSize.Size18 or Enum.FontSize.Size14
    textBox.Parent = frame
    
    inputFrames[i] = textBox
    
    -- 手机设备上移除示例文本以节省空间
    if not isMobile then
        local exampleLabel = Instance.new("TextLabel")
        exampleLabel.Text = "示例: 输入1000自动计算最优组合"
        exampleLabel.Size = UDim2.new(1, 0, 0, 15)
        exampleLabel.Position = UDim2.new(0, 0, 0, isMobile and 95 or 75)
        exampleLabel.Font = Enum.Font.SourceSans
        exampleLabel.TextSize = 12
        exampleLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        exampleLabel.TextXAlignment = Enum.TextXAlignment.Left
        exampleLabel.BackgroundTransparency = 1
        exampleLabel.Parent = frame
    end
end

-- 按钮区域
local buttonFrame = Instance.new("Frame")
buttonFrame.Size = UDim2.new(0.95, 0, 0, isMobile and 60 or 80)
buttonFrame.Position = UDim2.new(0.025, 0, 0, 50 + 5*(isMobile and 95 or 75))
buttonFrame.BackgroundTransparency = 1
buttonFrame.Parent = contentFrame

-- 创建适应手机的按钮
local function createButton(text, posX, color)
    local button = Instance.new("TextButton")
    button.Text = text
    button.Size = UDim2.new(0.48, 0, 1, 0)
    button.Position = UDim2.new(posX, 0, 0, 0)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = isMobile and 18 or 16
    button.TextColor3 = Color3.new(1, 1, 1)
    button.BackgroundColor3 = color
    return button
end

-- 刷新按钮
local refreshButton = createButton(isMobile and "刷新" or "刷新丹药数据", 0, Color3.fromRGB(80, 80, 120))
refreshButton.Parent = buttonFrame

-- 交易按钮
local tradeButton = createButton(isMobile and "交易" or "放入交易丹药", 0.52, Color3.fromRGB(80, 120, 80))
tradeButton.Parent = buttonFrame

-- 状态显示
local statusLabel = Instance.new("TextLabel")
statusLabel.Text = "系统就绪，等待操作..."
statusLabel.Size = UDim2.new(0.95, 0, 0, isMobile and 100 or 40)
statusLabel.Position = UDim2.new(0.025, 0, 0, 50 + 5*(isMobile and 95 or 75) + (isMobile and 70 or 90))
statusLabel.Font = Enum.Font.SourceSans
statusLabel.TextSize = isMobile and 16 or 14
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.TextWrapped = true
statusLabel.BackgroundTransparency = 1
statusLabel.Parent = contentFrame

-- 如果是手机设备，调整滚动框内容大小
if isMobile then
    local totalHeight = 50 + 5*95 + 70 + 100 + 20 -- 所有元素高度总和加边距
    contentFrame.Size = UDim2.new(1, 0, 0, totalHeight)
    contentFrame.Parent.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
end


-- 获取远程事件
local elixirSyncEvent = ReplicatedStorage
    ["\228\186\139\228\187\182"]          -- 药水
    ["\229\174\162\230\136\183\231\171\175"] -- 同步模块
    ["\229\174\162\230\136\183\231\171\175\228\184\185\232\141\175"] -- 同步控制器
    ["\228\184\185\232\141\175\230\149\176\230\141\174\229\143\152\229\140\150"] -- 数据更新事件

local addTradeItemEvent = ReplicatedStorage
    ["\228\186\139\228\187\182"]  -- 药水
    ["\229\133\172\231\148\168"]  -- 功能
    ["\228\186\164\230\152\147"]  -- 交易
    ["\230\150\176\229\162\158\228\186\164\230\152\147\231\137\169\229\147\129"] -- 新增交易物品

local confirmTradeEvent = ReplicatedStorage
    ["\228\186\139\228\187\182"]  -- 药水
    ["\229\133\172\231\148\168"]  -- 功能
    ["\228\186\164\230\152\147"]  -- 交易
    :WaitForChild("\233\148\129\229\174\154\228\186\164\230\152\147") -- 确认交易

-- 丹药数据存储
local elixirData = {}

-- 数据同步处理
elixirSyncEvent.Event:Connect(function(data)
    elixirData = data
end)

-- 计算丹药点数
local function calculateElixirPoints()
    if not elixirData then
        warn("无法获取丹药数据")
        return {}, 0
    end
    
    local backpack = elixirData["\232\131\140\229\140\133"] or {}
    if #backpack == 0 then
        warn("背包中没有物品")
        return {}, 0
    end
    
    local typeTotals = {0, 0, 0, 0, 0}  -- 每种类型的总点数
    local grandTotal = 0                -- 全部丹药总点数
    
    -- 遍历背包中的物品
    for _, item in ipairs(backpack) do
        if item and type(item) == "table" then
            -- 安全获取字段
            local count = tonumber(item["\230\149\176\233\135\143"]) or 0
            local elixirType = tonumber(item["\231\177\187\229\158\139"]) or 0
            local quality = tonumber(item["品质"]) or 0
            
            -- 验证数据有效性
            if elixirType >= 1 and elixirType <= 5 
               and qualityPoints[quality] 
               and count > 0 then
                local points = qualityPoints[quality] * count
                typeTotals[elixirType] = (typeTotals[elixirType] or 0) + points
                grandTotal = grandTotal + points
            end
        end
    end
    
    return typeTotals, grandTotal
end

-- 智能计算丹药组合算法
local function calculateElixirs(targetPoints, availableElixirs)
    table.sort(availableElixirs, function(a, b) return a.points > b.points end)
    
    local usedElixirs = {}
    local remainingPoints = targetPoints
    
    -- Phase 1: Use exact multiples
    for _, elixir in ipairs(availableElixirs) do
        if remainingPoints <= 0 then break end
        
        local maxPossible = math.floor(remainingPoints / elixir.points)
        if maxPossible > 0 then
            local take = math.min(maxPossible, elixir.count)
            if take > 0 then
                table.insert(usedElixirs, {
                    type = elixir.type,
                    quality = elixir.quality,
                    count = take,
                    points = elixir.points,
                    index = elixir.index
                })
                remainingPoints = remainingPoints - (take * elixir.points)
            end
        end
    end
    
    -- Phase 2: Add ONE optimal elixir if needed
    if remainingPoints > 0 then
        local bestElixir = nil
        local bestPoints = math.huge
        
        for _, elixir in ipairs(availableElixirs) do
            local used = 0
            for _, u in ipairs(usedElixirs) do
                if u.index == elixir.index then used = u.count end
            end
            local remaining = elixir.count - used
            
            if remaining > 0 and elixir.points >= remainingPoints then
                if elixir.points < bestPoints then
                    bestPoints = elixir.points
                    bestElixir = elixir
                    if bestPoints == remainingPoints then break end
                end
            end
        end
        
        if bestElixir then
            table.insert(usedElixirs, {
                type = bestElixir.type,
                quality = bestElixir.quality,
                count = 1,
                points = bestElixir.points,
                index = bestElixir.index
            })
            remainingPoints = remainingPoints - bestElixir.points
        end
    end
    
    local totalPoints = targetPoints - remainingPoints
    
    if totalPoints > targetPoints then
        for i = #usedElixirs, 1, -1 do
            if totalPoints - usedElixirs[i].points >= targetPoints then
                totalPoints = totalPoints - usedElixirs[i].points
                table.remove(usedElixirs, i)
            end
        end
    end
    
    return usedElixirs, totalPoints
end

-- 执行交易操作
tradeButton.MouseButton1Click:Connect(function()
    statusLabel.Text = "正在计算最优丹药组合..."
    task.wait(0.1)
    
    -- 获取输入的点数需求
    local requirements = {}
    for i = 1, 5 do
        local input = tonumber(inputFrames[i].Text) or 0
        if input > 0 then
            requirements[i] = input
        end
    end
    
    -- 检查是否有丹药数据
    if not elixirData or not elixirData["\232\131\140\229\140\133"] then
        statusLabel.Text = "错误: 没有获取到丹药数据，请先刷新"
        return
    end
    
    -- 准备可用丹药列表
    local availableElixirs = {}
    local backpack = elixirData["\232\131\140\229\140\133"] or {}
    
    for _, item in ipairs(backpack) do
        if item and type(item) == "table" then
            local count = tonumber(item["\230\149\176\233\135\143"]) or 0
            local elixirType = tonumber(item["\231\177\187\229\158\139"]) or 0
            local quality = tonumber(item["品质"]) or 0
            local index = item["索引"] or ""
            
            if elixirType >= 1 and elixirType <= 5 and qualityPoints[quality] and count > 0 and index ~= "" then
                table.insert(availableElixirs, {
                    type = elixirType,
                    quality = quality,
                    count = count,
                    points = qualityPoints[quality],
                    index = index
                })
            end
        end
    end
    
    -- 按类型分类丹药
    local elixirsByType = {}
    for _, elixir in ipairs(availableElixirs) do
        if not elixirsByType[elixir.type] then
            elixirsByType[elixir.type] = {}
        end
        table.insert(elixirsByType[elixir.type], elixir)
    end
    
    -- 处理每种需求
    local tradeResults = {}
    for elixirType, targetPoints in pairs(requirements) do
        if elixirsByType[elixirType] then
            local usedElixirs, totalPoints = calculateElixirs(targetPoints, elixirsByType[elixirType])
            table.insert(tradeResults, {
                type = elixirType,
                target = targetPoints,
                achieved = totalPoints,
                elixirs = usedElixirs
            })
        end
    end
    
    -- 显示结果并执行交易
    local resultText = "【交易方案】\n"
    for _, result in ipairs(tradeResults) do
        resultText = resultText .. string.format("%s丹药: 需求%d点 → 实际%d点\n", 
            elixirTypes[result.type], result.target, result.achieved)
        
        for _, elixir in ipairs(result.elixirs) do
            addTradeItemEvent:FireServer("丹药", elixir.index, elixir.count)
            resultText = resultText .. string.format(" - 放入 %d个 %s丹药(品质%d, %d点/个)\n",
                elixir.count, elixirTypes[elixir.type], elixir.quality, elixir.points)
        end
    end
    
    if #tradeResults == 0 then
        resultText = "没有有效的交易需求"
    else
        resultText = resultText .. "\n交易物品已自动放入！"
    end
    
    statusLabel.Text = resultText
end)

-- 刷新按钮功能
refreshButton.MouseButton1Click:Connect(function()
    statusLabel.Text = "正在刷新数据..."
    task.wait(0.1)
    
    -- 等待数据更新
    local startTime = os.time()
    while not elixirData or not elixirData["\232\131\140\229\140\133"] do
        if os.time() - startTime > 5 then
            statusLabel.Text = "错误: 获取丹药数据超时"
            return
        end
        task.wait(0.1)
    end
    
    local typeTotals, grandTotal = calculateElixirPoints()
    totalPointsLabel.Text = "全部丹药总点数: "..grandTotal
    
    for i = 1, 5 do
        pointsLabels[i].Text = string.format("总点数: %d (约%d个品质8)", 
            typeTotals[i], math.floor(typeTotals[i] / 10))
    end
    
    statusLabel.Text = "数据更新完成 "..os.date("%H:%M:%S")
end)

-- 折叠/展开功能
local isCollapsed = false
local originalSize = mainFrame.Size

local function toggleCollapse()
    isCollapsed = not isCollapsed
    if isCollapsed then
        toggleButton.Text = "+"
        contentFrame.Visible = false
        mainFrame.Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, 40)
    else
        toggleButton.Text = "_"
        contentFrame.Visible = true
        mainFrame.Size = originalSize
    end
end

toggleButton.MouseButton1Click:Connect(toggleCollapse)

-- 关闭按钮功能
closeButton.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- 窗口拖动功能
local dragging = false
local dragStart, startPos

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- 初始刷新
refreshButton.MouseButton1Click:Wait()
