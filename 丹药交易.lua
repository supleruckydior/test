local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

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

-- 主框架 - 调整为更紧凑的初始尺寸
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 350, 0, 60) -- 初始高度较小
mainFrame.Position = UDim2.new(0.5, -175, 0.5, -30)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true -- 确保内容不会溢出
mainFrame.Parent = screenGui

-- 标题栏（可拖动和折叠）
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
titleBar.Parent = mainFrame

local title = Instance.new("TextLabel")
title.Text = "丹药交易大师1.0 ▼"
title.Size = UDim2.new(1, -90, 1, 0)
title.Font = Enum.Font.SourceSansBold
title.TextSize = 20
title.TextColor3 = Color3.new(1, 1, 1)
title.BackgroundTransparency = 1
title.Parent = titleBar

-- 折叠/展开按钮
local toggleButton = Instance.new("TextButton")
toggleButton.Text = "☰"
toggleButton.Size = UDim2.new(0, 50, 1, 0)
toggleButton.Position = UDim2.new(0, 0, 0, 0)
toggleButton.Font = Enum.Font.SourceSansBold
toggleButton.TextSize = 20
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 90)
toggleButton.Parent = titleBar

-- 关闭按钮
local closeButton = Instance.new("TextButton")
closeButton.Text = "×"
closeButton.Size = UDim2.new(0, 40, 1, 0)
closeButton.Position = UDim2.new(1, -40, 0, 0)
closeButton.Font = Enum.Font.SourceSansBold
closeButton.TextSize = 24
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.Parent = titleBar

-- 内容区域（可折叠）
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, 0, 0, 500) -- 内容高度
contentFrame.Position = UDim2.new(0, 0, 0, 50)
contentFrame.BackgroundTransparency = 1
contentFrame.Visible = false -- 初始隐藏
contentFrame.Parent = mainFrame

-- 总点数显示
local totalPointsLabel = Instance.new("TextLabel")
totalPointsLabel.Text = "全部丹药总点数: 计算中..."
totalPointsLabel.Size = UDim2.new(0.9, 0, 0, 30)
totalPointsLabel.Position = UDim2.new(0.05, 0, 0, 10)
totalPointsLabel.Font = Enum.Font.SourceSansSemibold
totalPointsLabel.TextSize = 16
totalPointsLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
totalPointsLabel.BackgroundTransparency = 1
totalPointsLabel.TextXAlignment = Enum.TextXAlignment.Left
totalPointsLabel.Parent = contentFrame

-- 创建可折叠的丹药类型区域
local categoryFrames = {}
local categoryButtons = {}
local categoryContents = {}

for i = 1, 5 do
    -- 类别按钮
    local button = Instance.new("TextButton")
    button.Text = elixirTypes[i].."丹药 ▼"
    button.Size = UDim2.new(0.9, 0, 0, 40)
    button.Position = UDim2.new(0.05, 0, 0, 50 + (i-1)*120)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 18
    button.TextColor3 = Color3.new(1, 1, 1)
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    button.Parent = contentFrame
    categoryButtons[i] = button
    
    -- 类别内容区域
    local categoryFrame = Instance.new("Frame")
    categoryFrame.Size = UDim2.new(0.9, 0, 0, 80)
    categoryFrame.Position = UDim2.new(0.05, 0, 0, 90 + (i-1)*120)
    categoryFrame.BackgroundTransparency = 1
    categoryFrame.Visible = false -- 初始隐藏
    categoryFrame.Parent = contentFrame
    categoryContents[i] = categoryFrame
    
    -- 点数显示
    local pointsLabel = Instance.new("TextLabel")
    pointsLabel.Name = "Points_"..i
    pointsLabel.Text = "总点数: 0"
    pointsLabel.Size = UDim2.new(1, 0, 0, 25)
    pointsLabel.Font = Enum.Font.SourceSans
    pointsLabel.TextSize = 16
    pointsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
    pointsLabel.BackgroundTransparency = 1
    pointsLabel.Parent = categoryFrame
    categoryFrames[i] = pointsLabel
    
    -- 输入框
    local textBox = Instance.new("TextBox")
    textBox.Name = "Input_"..i
    textBox.Size = UDim2.new(1, 0, 0, 35)
    textBox.Position = UDim2.new(0, 0, 0, 30)
    textBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    textBox.TextColor3 = Color3.new(1, 1, 1) 
    textBox.PlaceholderText = "输入"..elixirTypes[i].."丹药需求点数"
    textBox.Text = ""
    textBox.Parent = categoryFrame
    
    -- 示例标签
    local exampleLabel = Instance.new("TextLabel")
    exampleLabel.Text = "示例: 输入1000自动计算最优组合"
    exampleLabel.Size = UDim2.new(1, 0, 0, 15)
    exampleLabel.Position = UDim2.new(0, 0, 0, 65)
    exampleLabel.Font = Enum.Font.SourceSans
    exampleLabel.TextSize = 12
    exampleLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    exampleLabel.TextXAlignment = Enum.TextXAlignment.Left
    exampleLabel.BackgroundTransparency = 1
    exampleLabel.Parent = categoryFrame
    
    -- 点击事件
    button.MouseButton1Click:Connect(function()
        categoryFrame.Visible = not categoryFrame.Visible
        button.Text = elixirTypes[i].."丹药 "..(categoryFrame.Visible and "▲" or "▼")
        
        -- 调整主框架大小
        local newHeight = 50 -- 标题栏高度
        for j = 1, 5 do
            if categoryContents[j].Visible then
                newHeight = newHeight + 120 -- 展开的类别高度
            else
                newHeight = newHeight + 40 -- 折叠的按钮高度
            end
        end
        newHeight = newHeight + 80 -- 底部按钮区域
        
        mainFrame.Size = UDim2.new(0, 350, 0, math.min(newHeight, 800)) -- 限制最大高度
    end)
end

-- 按钮区域
local buttonFrame = Instance.new("Frame")
buttonFrame.Size = UDim2.new(0.9, 0, 0, 80)
buttonFrame.Position = UDim2.new(0.05, 0, 0, 50 + 5*120)
buttonFrame.BackgroundTransparency = 1
buttonFrame.Parent = contentFrame

-- 刷新按钮
local refreshButton = Instance.new("TextButton")
refreshButton.Text = "刷新丹药数据"
refreshButton.Size = UDim2.new(0.45, 0, 0, 40)
refreshButton.Position = UDim2.new(0, 0, 0, 0)
refreshButton.Font = Enum.Font.SourceSansBold
refreshButton.TextSize = 16
refreshButton.TextColor3 = Color3.new(1, 1, 1) 
refreshButton.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
refreshButton.Parent = buttonFrame

-- 交易按钮
local tradeButton = Instance.new("TextButton")
tradeButton.Text = "放入交易丹药"
tradeButton.Size = UDim2.new(0.45, 0, 0, 40)
tradeButton.Position = UDim2.new(0.55, 0, 0, 0)
tradeButton.Font = Enum.Font.SourceSansBold
tradeButton.TextSize = 16
tradeButton.TextColor3 = Color3.new(1, 1, 1) 
tradeButton.BackgroundColor3 = Color3.fromRGB(80, 120, 80)
tradeButton.Parent = buttonFrame

-- 状态显示
local statusLabel = Instance.new("TextLabel")
statusLabel.Text = "系统就绪，等待操作..."
statusLabel.Size = UDim2.new(0.9, 0, 0, 60)
statusLabel.Position = UDim2.new(0.05, 0, 0, 50 + 5*120 + 90)
statusLabel.Font = Enum.Font.SourceSans
statusLabel.TextSize = 14
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.TextWrapped = true
statusLabel.BackgroundTransparency = 1
statusLabel.Parent = contentFrame

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

-- 调试用：打印丹药数据
local function debugPrintElixirData()
    if not elixirData then
        print("没有获取到丹药数据")
        return
    end
    
    local backpack = elixirData["\232\131\140\229\140\133"] or {}
    
    -- 打印前10个物品作为示例
    for i = 1, math.min(10, #backpack) do
        local item = backpack[i]
        if item and type(item) == "table" then
            -- 获取字段
            local itemType = item["\231\177\187\229\158\139"] or "未知"
            local quality = item["品质"] or "未知"
            local count = item["\230\149\176\233\135\143"] or "未知"
            local index = item["索引"] or "无索引"
            
            print(string.format("物品%d: 类型=%s, 品质=%s, 数量=%s, 索引=%s", 
                i, itemType, quality, count, index))
        else
            print("物品"..i..": 无效的数据格式")
        end
    end
end

-- 计算丹药点数
local function calculateElixirPoints()
    if not elixirData then
        warn("无法获取丹药数据")
        return {}, 0
    end
    
    debugPrintElixirData()
    
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
    -- Sort by points (highest first)
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
        -- Find best single elixir to cover remaining points
        local bestElixir = nil
        local bestPoints = math.huge
        
        -- Check all elixir types from highest to lowest
        for _, elixir in ipairs(availableElixirs) do
            -- Check if we have any left
            local used = 0
            for _, u in ipairs(usedElixirs) do
                if u.index == elixir.index then used = u.count end
            end
            local remaining = elixir.count - used
            
            if remaining > 0 and elixir.points >= remainingPoints then
                if elixir.points < bestPoints then
                    bestPoints = elixir.points
                    bestElixir = elixir
                    -- Found perfect match, break early
                    if bestPoints == remainingPoints then break end
                end
            end
        end
        
        -- Add the single best elixir
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
    
    -- Calculate final total
    local totalPoints = targetPoints - remainingPoints
    
    -- Verify we didn't add unnecessary elixirs
    if totalPoints > targetPoints then
        -- Find and remove any redundant small elixirs
        for i = #usedElixirs, 1, -1 do
            if totalPoints - usedElixirs[i].points >= targetPoints then
                totalPoints = totalPoints - usedElixirs[i].points
                table.remove(usedElixirs, i)
            end
        end
    end
    
    -- Final debug output
    print("\nOptimized Calculation:")
    local runningTotal = 0
    for i, u in ipairs(usedElixirs) do
        runningTotal = runningTotal + (u.count * u.points)
        print(string.format("%d. %dx Quality %d (%d pts) = %d pts (Subtotal: %d)",
            i, u.count, u.quality, u.points, u.count * u.points, runningTotal))
    end
    print(string.format("Final Total: %d pts (Requested: %d, Difference: %d)",
        runningTotal, targetPoints, runningTotal - targetPoints))
    
    return usedElixirs, runningTotal
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
            -- 安全获取字段
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
        
        -- 添加交易物品
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

-- 关闭按钮功能
closeButton.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)
local isExpanded = false
toggleButton.MouseButton1Click:Connect(function()
    isExpanded = not isExpanded
    contentFrame.Visible = isExpanded
    title.Text = "丹药交易大师 "..(isExpanded and "▲" or "▼")
    
    if isExpanded then
        -- 展开时计算合适的高度
        local newHeight = 50 -- 标题栏高度
        for i = 1, 5 do
            if categoryContents[i].Visible then
                newHeight = newHeight + 120 -- 展开的类别高度
            else
                newHeight = newHeight + 40 -- 折叠的按钮高度
            end
        end
        newHeight = newHeight + 140 -- 底部区域
        
        mainFrame.Size = UDim2.new(0, 350, 0, math.min(newHeight, 800)) -- 限制最大高度
    else
        -- 折叠时只显示标题栏
        mainFrame.Size = UDim2.new(0, 350, 0, 50)
    end
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
wait(0.3)
            local elixirEvent = ReplicatedStorage:FindFirstChild("\228\186\139\228\187\182")
                :FindFirstChild("\229\133\172\231\148\168")
                :FindFirstChild("\231\130\188\228\184\185")
                :FindFirstChild("\229\136\182\228\189\156")
                elixirEvent:FireServer()
