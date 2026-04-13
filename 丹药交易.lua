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

-- 主框架 - 根据您的要求调整
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0.5, 0, 0, 380) -- 宽度50%，高度380像素
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0) -- 居中
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- 标题栏（可拖动）
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
titleBar.Parent = mainFrame

-- 折叠按钮
local foldButton = Instance.new("TextButton")
foldButton.Text = "▼"
foldButton.Size = UDim2.new(0, 40, 1, 0)
foldButton.Font = Enum.Font.SourceSansBold
foldButton.TextSize = 16
foldButton.TextColor3 = Color3.new(1, 1, 1)
foldButton.BackgroundColor3 = Color3.fromRGB(70, 70, 100)
foldButton.Parent = titleBar
foldButton.Name = "FoldButton"

local title = Instance.new("TextLabel")
title.Text = "丹药交易大师 v1.0"
title.Size = UDim2.new(1, -80, 1, 0)  -- 调整位置
title.Position = UDim2.new(0, 40, 0, 0)  -- 为折叠按钮腾空间
title.Font = Enum.Font.SourceSansBold
title.TextSize = 18
title.TextColor3 = Color3.new(1, 1, 1)
title.BackgroundTransparency = 1
title.Parent = titleBar

-- 关闭按钮
local closeButton = Instance.new("TextButton")
closeButton.Text = "X"
closeButton.Size = UDim2.new(0, 40, 1, 0)
closeButton.Position = UDim2.new(1, -40, 0, 0)
closeButton.Font = Enum.Font.SourceSansBold
closeButton.TextSize = 18
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeButton.Parent = titleBar

-- 总点数显示
local totalPointsLabel = Instance.new("TextLabel")
totalPointsLabel.Text = "全部丹药总点数: 计算中..."
totalPointsLabel.Size = UDim2.new(0.9, 0, 0, 25)
totalPointsLabel.Position = UDim2.new(0.05, 0, 0, 40)
totalPointsLabel.Font = Enum.Font.SourceSansSemibold
totalPointsLabel.TextSize = 16
totalPointsLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
totalPointsLabel.BackgroundTransparency = 1
totalPointsLabel.TextXAlignment = Enum.TextXAlignment.Left
totalPointsLabel.Parent = mainFrame

-- 创建5个输入框和点数显示
local inputFrames = {}
local pointsLabels = {}
for i = 1, 5 do
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0.9, 0, 0, 50)
    frame.Position = UDim2.new(0.05, 0, 0, 65 + (i-1)*55)
    frame.BackgroundTransparency = 1
    frame.Parent = mainFrame
    
    local typeLabel = Instance.new("TextLabel")
    typeLabel.Text = elixirTypes[i].."丹药:"
    typeLabel.Size = UDim2.new(0.3, 0, 0, 20)
    typeLabel.Position = UDim2.new(0, 0, 0, 0)
    typeLabel.Font = Enum.Font.SourceSansSemibold
    typeLabel.TextSize = 14
    typeLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
    typeLabel.TextXAlignment = Enum.TextXAlignment.Left
    typeLabel.BackgroundTransparency = 1
    typeLabel.Parent = frame
    
    local pointsLabel = Instance.new("TextLabel")
    pointsLabel.Name = "Points_"..i
    pointsLabel.Text = "总点数: 0"
    pointsLabel.Size = UDim2.new(0.7, 0, 0, 20)
    pointsLabel.Position = UDim2.new(0.3, 0, 0, 0)
    pointsLabel.Font = Enum.Font.SourceSans
    pointsLabel.TextSize = 12
    pointsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    pointsLabel.TextXAlignment = Enum.TextXAlignment.Left
    pointsLabel.BackgroundTransparency = 1  -- 修复此处，之前是乱码
    pointsLabel.Parent = frame
    pointsLabels[i] = pointsLabel
    
    local textBox = Instance.new("TextBox")
    textBox.Name = "Input_"..i
    textBox.Size = UDim2.new(1, 0, 0, 25)
    textBox.Position = UDim2.new(0, 0, 0, 20)
    textBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    textBox.TextColor3 = Color3.new(1, 1, 1) 
    textBox.PlaceholderText = "输入"..elixirTypes[i].."丹药需求点数"
    textBox.Text = ""
    textBox.TextSize = 14
    textBox.Parent = frame
    
    inputFrames[i] = textBox
    
    local exampleLabel = Instance.new("TextLabel")
    exampleLabel.Text = "示例: 输入1000自动计算最优组合"
    exampleLabel.Size = UDim2.new(1, 0, 0, 15)
    exampleLabel.Position = UDim2.new(0, 0, 0, 45)
    exampleLabel.Font = Enum.Font.SourceSans
    exampleLabel.TextSize = 11
    exampleLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    exampleLabel.TextXAlignment = Enum.TextXAlignment.Left
    exampleLabel.BackgroundTransparency = 1
    exampleLabel.Parent = frame
end

-- 按钮区域
local buttonFrame = Instance.new("Frame")
buttonFrame.Size = UDim2.new(0.9, 0, 0, 60)
buttonFrame.Position = UDim2.new(0.05, 0, 0, 65 + 5*55)
buttonFrame.BackgroundTransparency = 1
buttonFrame.Parent = mainFrame

-- 刷新按钮
local refreshButton = Instance.new("TextButton")
refreshButton.Text = "刷新丹药数据"
refreshButton.Size = UDim2.new(0.45, 0, 0, 30)
refreshButton.Position = UDim2.new(0, 0, 0, 0)
refreshButton.Font = Enum.Font.SourceSansBold
refreshButton.TextSize = 14
refreshButton.TextColor3 = Color3.new(1, 1, 1) 
refreshButton.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
refreshButton.Parent = buttonFrame

-- 交易按钮
local tradeButton = Instance.new("TextButton")
tradeButton.Text = "放入交易丹药"
tradeButton.Size = UDim2.new(0.45, 0, 0, 30)
tradeButton.Position = UDim2.new(0.55, 0, 0, 0)
tradeButton.Font = Enum.Font.SourceSansBold
tradeButton.TextSize = 14
tradeButton.TextColor3 = Color3.new(1, 1, 1) 
tradeButton.BackgroundColor3 = Color3.fromRGB(80, 120, 80)
tradeButton.Parent = buttonFrame

-- 状态显示
local statusLabel = Instance.new("TextLabel")
statusLabel.Text = "系统就绪，等待操作..."
statusLabel.Size = UDim2.new(0.9, 0, 0, 35)
statusLabel.Position = UDim2.new(0.05, 0, 0, 65 + 5*55 + 65)
statusLabel.Font = Enum.Font.SourceSans
statusLabel.TextSize = 12
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.TextWrapped = true
statusLabel.BackgroundTransparency = 1
statusLabel.Parent = mainFrame

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

-- 缓存背包数据键名，避免重复查找
local BACKPACK_KEY = "\232\131\140\229\140\133"
local COUNT_KEY = "\230\149\176\233\135\143"
local TYPE_KEY = "\231\177\187\229\158\139"
local QUALITY_KEY = "品质"
local INDEX_KEY = "索引"

-- 计算丹药点数（优化版：减少表查找和类型转换）
local function calculateElixirPoints()
    if not elixirData then
        warn("无法获取丹药数据")
        return {}, 0
    end
    
    debugPrintElixirData()
    
    local backpack = elixirData[BACKPACK_KEY]
    if not backpack or #backpack == 0 then
        warn("背包中没有物品")
        return {}, 0
    end
    
    local typeTotals = {0, 0, 0, 0, 0}  -- 每种类型的总点数
    local grandTotal = 0                -- 全部丹药总点数
    
    -- 遍历背包中的物品（优化：减少函数调用）
    local item, count, elixirType, quality, points
    for i = 1, #backpack do
        item = backpack[i]
        if item and type(item) == "table" then
            -- 安全获取字段（缓存查找结果）
            count = item[COUNT_KEY]
            if count then
                count = tonumber(count) or 0
                if count > 0 then
                    elixirType = item[TYPE_KEY]
                    if elixirType then
                        elixirType = tonumber(elixirType) or 0
                        if elixirType >= 1 and elixirType <= 5 then
                            quality = item[QUALITY_KEY]
                            if quality then
                                quality = tonumber(quality) or 0
                                points = qualityPoints[quality]
                                if points then
                                    points = points * count
                                    typeTotals[elixirType] = typeTotals[elixirType] + points
                                    grandTotal = grandTotal + points
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return typeTotals, grandTotal
end

-- 智能计算丹药组合算法（优化版：改进动态规划实现，减少内存分配）
local function calculateElixirs(targetPoints, availableElixirs, adjustRange)
    adjustRange = adjustRange or 50 -- 允许的微调范围
    
    if #availableElixirs == 0 then
        return {}, 0
    end

    -- 按点数从大到小排序（优化：使用更高效的比较）
    table.sort(availableElixirs, function(a, b) 
        return a.points > b.points 
    end)

    -- 预分配used表，减少内存分配
    local used = {}
    local elixir, usedItem
    for i = 1, #availableElixirs do
        elixir = availableElixirs[i]
        used[i] = {
            type = elixir.type, 
            quality = elixir.quality, 
            count = 0, 
            points = elixir.points, 
            index = elixir.index
        }
    end

    local currentPoints = 0
    local targetMinusRange = targetPoints - adjustRange

    -- 阶段 1：贪心逼近到目标附近（不超过目标太多）
    for i = 1, #availableElixirs do
        elixir = availableElixirs[i]
        usedItem = used[i]
        local points = elixir.points
        
        -- 计算可以添加的最大数量，不超过目标太多
        if currentPoints < targetPoints then
            local needPoints = targetPoints - currentPoints
            local maxCount = math.ceil(needPoints / points)  -- 向上取整，确保至少达到目标
            local take = math.min(maxCount, elixir.count)
            usedItem.count = take
            currentPoints = currentPoints + points * take
        else
            -- 如果已经达到目标，尝试在允许范围内继续添加
            local maxCount = math.floor((targetMinusRange + adjustRange - currentPoints) / points)
            if maxCount > 0 then
                local take = math.min(maxCount, elixir.count)
                usedItem.count = take
                currentPoints = currentPoints + points * take
            end
        end
    end

    local diff = targetPoints - currentPoints

    -- 阶段 2：如果未达到目标，使用动态规划补充（确保 >= 目标）
    if diff > 0 then
        -- 生成可用于补充的丹药列表（剩余数量）
        local smallElixirs = {}
        local remain
        for i = 1, #availableElixirs do
            remain = availableElixirs[i].count - used[i].count
            if remain > 0 then
                smallElixirs[#smallElixirs + 1] = {
                    index = i, 
                    points = availableElixirs[i].points, 
                    count = remain
                }
            end
        end

        if #smallElixirs > 0 then
            -- 背包搜索范围：需要至少达到 diff，最多不超过 diff + adjustRange
            local minPoints = diff  -- 最小必须达到目标
            local maxPoints = diff + adjustRange  -- 最多不超过目标太多
            
            -- 使用数组代替哈希表，提高访问速度
            local dp = {}
            dp[0] = {}
            local dpKeys = {0}
            local dpKeysCount = 1

            -- 二进制优化背包（优化：减少物品数量）
            for i = 1, #smallElixirs do
                local e = smallElixirs[i]
                local items = {}
                local c = e.count
                local k = 1
                while c > 0 do
                    local take = math.min(k, c)
                    items[#items + 1] = {index = e.index, points = e.points, count = take}
                    c = c - take
                    k = k * 2
                end

                -- 更新DP（优化：使用临时表减少内存分配）
                local newDP = {}
                local newKeys = {}
                local newKeysCount = 0
                
                for j = 1, dpKeysCount do
                    local s = dpKeys[j]
                    local combo = dp[s]
                    if combo then
                        for _, item in ipairs(items) do
                            local newS = s + item.points * item.count
                            -- 只考虑 >= minPoints 且 <= maxPoints 的解
                            if newS >= minPoints and newS <= maxPoints and not dp[newS] then
                                local newCombo = {}
                                for k = 1, #combo do
                                    newCombo[k] = combo[k]
                                end
                                newCombo[#newCombo + 1] = {index = item.index, count = item.count}
                                newDP[newS] = newCombo
                                newKeysCount = newKeysCount + 1
                                newKeys[newKeysCount] = newS
                            end
                        end
                    end
                end
                
                -- 合并新状态
                for j = 1, newKeysCount do
                    local s = newKeys[j]
                    if not dp[s] then
                        dp[s] = newDP[s]
                        dpKeysCount = dpKeysCount + 1
                        dpKeys[dpKeysCount] = s
                    end
                end
            end

            -- 找最接近但 >= diff 的解（确保不小于目标）
            local best = nil
            local bestPoints = math.huge
            for j = 1, dpKeysCount do
                local s = dpKeys[j]
                -- 只考虑 >= diff 的解（即 >= 目标点数）
                if s >= diff and s < bestPoints then
                    bestPoints = s
                    best = dp[s]
                end
            end

            -- 应用补充
            if best then
                for j = 1, #best do
                    local v = best[j]
                    used[v.index].count = used[v.index].count + v.count
                    currentPoints = currentPoints + availableElixirs[v.index].points * v.count
                end
            else
                -- 如果DP找不到解，使用贪心补充到至少达到目标
                for i = 1, #smallElixirs do
                    local e = smallElixirs[i]
                    if currentPoints < targetPoints then
                        local needPoints = targetPoints - currentPoints
                        local needCount = math.ceil(needPoints / e.points)
                        local take = math.min(needCount, e.count)
                        if take > 0 then
                            used[e.index].count = used[e.index].count + take
                            currentPoints = currentPoints + e.points * take
                        end
                    else
                        break
                    end
                end
            end
        end
    end

    print(string.format("[丹药优化] 目标: %d, 实际: %d, 误差: %+d", targetPoints, currentPoints, currentPoints - targetPoints))

    -- 过滤掉 0 数量的（优化：预分配表）
    local finalCombo = {}
    for i = 1, #used do
        local v = used[i]
        if v.count > 0 then
            finalCombo[#finalCombo + 1] = v
        end
    end

    return finalCombo, currentPoints
end


-- 执行交易操作（优化版：减少数据访问和字符串操作）
tradeButton.MouseButton1Click:Connect(function()
    statusLabel.Text = "正在计算最优丹药组合..."
    task.wait(0.1)
    
    -- 获取输入的点数需求（优化：减少循环和函数调用）
    local requirements = {}
    local input, text
    for i = 1, 5 do
        text = inputFrames[i].Text
        if text and text ~= "" then
            input = tonumber(text)
            if input and input > 0 then
                requirements[i] = input
            end
        end
    end
    
    if not next(requirements) then
        statusLabel.Text = "错误: 请输入至少一种丹药的需求点数"
        return
    end
    
    -- 检查是否有丹药数据（优化：使用缓存的键名）
    local backpack = elixirData and elixirData[BACKPACK_KEY]
    if not backpack or #backpack == 0 then
        statusLabel.Text = "错误: 没有获取到丹药数据，请先刷新"
        return
    end
    
    -- 准备可用丹药列表（优化：减少表查找和类型转换）
    local availableElixirs = {}
    local item, count, elixirType, quality, index, points
    for i = 1, #backpack do
        item = backpack[i]
        if item and type(item) == "table" then
            count = item[COUNT_KEY]
            if count then
                count = tonumber(count) or 0
                if count > 0 then
                    elixirType = item[TYPE_KEY]
                    if elixirType then
                        elixirType = tonumber(elixirType) or 0
                        if elixirType >= 1 and elixirType <= 5 then
                            quality = item[QUALITY_KEY]
                            if quality then
                                quality = tonumber(quality) or 0
                                points = qualityPoints[quality]
                                if points then
                                    index = item[INDEX_KEY]
                                    if index and index ~= "" then
                                        availableElixirs[#availableElixirs + 1] = {
                                            type = elixirType,
                                            quality = quality,
                                            count = count,
                                            points = points,
                                            index = index
                                        }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    if #availableElixirs == 0 then
        statusLabel.Text = "错误: 没有可用的丹药"
        return
    end
    
    -- 按类型分类丹药（优化：预分配表）
    local elixirsByType = {}
    local elixir, typeList
    for i = 1, #availableElixirs do
        elixir = availableElixirs[i]
        typeList = elixirsByType[elixir.type]
        if not typeList then
            typeList = {}
            elixirsByType[elixir.type] = typeList
        end
        typeList[#typeList + 1] = elixir
    end
    
    -- 处理每种需求（优化：使用数组代替pairs）
    local tradeResults = {}
    local usedElixirs, totalPoints, result
    for elixirType = 1, 5 do
        if requirements[elixirType] then
            typeList = elixirsByType[elixirType]
            if typeList and #typeList > 0 then
                usedElixirs, totalPoints = calculateElixirs(requirements[elixirType], typeList)
                tradeResults[#tradeResults + 1] = {
                    type = elixirType,
                    target = requirements[elixirType],
                    achieved = totalPoints,
                    elixirs = usedElixirs
                }
            end
        end
    end
    
    if #tradeResults == 0 then
        statusLabel.Text = "没有有效的交易需求"
        return
    end
    
    -- 显示结果并执行交易（优化：使用table.concat代替字符串连接）
    local resultParts = {"【交易方案】"}
    local elixirTypeName
    for i = 1, #tradeResults do
        result = tradeResults[i]
        elixirTypeName = elixirTypes[result.type]
        resultParts[#resultParts + 1] = string.format("%s丹药: 需求%d点 → 实际%d点", 
            elixirTypeName, result.target, result.achieved)
        
        -- 添加交易物品
        for j = 1, #result.elixirs do
            elixir = result.elixirs[j]
            addTradeItemEvent:FireServer("丹药", elixir.index, elixir.count)
            resultParts[#resultParts + 1] = string.format(" - 放入 %d个 %s丹药(品质%d, %d点/个)",
                elixir.count, elixirTypeName, elixir.quality, elixir.points)
        end
    end
    
    resultParts[#resultParts + 1] = "\n交易物品已自动放入！"
    statusLabel.Text = table.concat(resultParts, "\n")
end)

-- 刷新按钮功能（优化版：减少等待时间和UI更新）
refreshButton.MouseButton1Click:Connect(function()
    statusLabel.Text = "正在刷新数据..."
    task.wait(0.05)  -- 减少等待时间
    
    -- 等待数据更新（优化：使用os.clock()代替os.time()，更精确）
    local startTime = os.clock()
    local timeout = 5
    while not elixirData or not elixirData[BACKPACK_KEY] do
        if os.clock() - startTime > timeout then
            statusLabel.Text = "错误: 获取丹药数据超时"
            return
        end
        task.wait(0.05)  -- 减少等待间隔
    end
    
    local typeTotals, grandTotal = calculateElixirPoints()
    totalPointsLabel.Text = "全部丹药总点数: " .. tostring(grandTotal)
    
    -- 批量更新UI（优化：减少字符串格式化调用）
    local total, quality8Count
    for i = 1, 5 do
        total = typeTotals[i]
        quality8Count = math.floor(total / 10)
        pointsLabels[i].Text = string.format("总点数: %d (约%d个品质8)", total, quality8Count)
    end
    
    statusLabel.Text = "数据更新完成 " .. os.date("%H:%M:%S")
end)

-- 关闭按钮功能
closeButton.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

-- 窗口拖动功能（优化版：减少事件连接和计算）
local dragging = false
local dragStart, startPos
local connection

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        
        -- 优化：只连接一次Changed事件
        if connection then
            connection:Disconnect()
        end
        connection = input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if connection then
                    connection:Disconnect()
                    connection = nil
                end
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

-- 折叠功能实现（优化版：缓存子元素，减少GetChildren调用）
local isFolded = false
local originalSize = mainFrame.Size
local foldedSize = UDim2.new(0.5, 0, 0, 40)  -- 折叠后只剩标题栏高度，宽度保持不变
local childrenCache = {}  -- 缓存子元素列表

-- 初始化缓存
do
    local children = mainFrame:GetChildren()
    for i = 1, #children do
        if children[i] ~= titleBar then
            childrenCache[#childrenCache + 1] = children[i]
        end
    end
end

foldButton.MouseButton1Click:Connect(function()
    isFolded = not isFolded
    
    if isFolded then
        -- 折叠UI（只显示标题栏）
        mainFrame.Size = foldedSize
        foldButton.Text = "▲"
        
        -- 隐藏所有内容（使用缓存）
        for i = 1, #childrenCache do
            childrenCache[i].Visible = false
        end
    else
        -- 展开UI
        mainFrame.Size = originalSize
        foldButton.Text = "▼"
        
        -- 显示所有内容（使用缓存）
        for i = 1, #childrenCache do
            childrenCache[i].Visible = true
        end
    end
end)

-- 初始刷新（优化：添加错误处理，使用task.wait）
task.spawn(function()
    refreshButton.MouseButton1Click:Wait()
    task.wait(0.2)  -- 减少等待时间
    
    -- 安全获取事件（优化：添加错误处理）
    local elixirModule = ReplicatedStorage:FindFirstChild("\228\186\139\228\187\182")
    if elixirModule then
        local functionModule = elixirModule:FindFirstChild("\229\133\172\231\148\168")
        if functionModule then
            local refreshModule = functionModule:FindFirstChild("\231\130\188\228\184\185")
            if refreshModule then
                local elixirEvent = refreshModule:FindFirstChild("\229\136\182\228\189\156")
                if elixirEvent then
                    elixirEvent:FireServer()
                end
            end
        end
    end
end)

