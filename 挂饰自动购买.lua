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
    [1] = "普通",
    [2] = "优秀",
    [3] = "精良",
    [4] = "稀有",
    [5] = "完美",
    [6] = "稀少",
    [7] = "史诗",
    [8] = "传奇",
    [9] = "不朽",
    [10] = "神话"
}

-- 价格限制配置（根据品质）
local PRICE_LIMITS = {
    [1] = 10,      -- 普通
    [2] = 20,      -- 优秀
    [3] = 100,     -- 精良
    [4] = 800,     -- 稀有
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

-- 丹药相关配置
local ELIXIR_TYPE_NAMES = {
    [1] = "攻击",
    [2] = "爆伤",
    [3] = "法宝",
    [4] = "血量",
    [5] = "技能"
}

-- 品质点数映射
local QUALITY_POINTS = {
    [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5,
    [6] = 6, [7] = 8, [8] = 10, [9] = 14, [10] = 20,
    [11] = 28
}

-- 丹药数据存储
local elixirData = {}
local elixirStats = {
    typeTotals = {0, 0, 0, 0, 0},  -- 每种类型的总点数
    grandTotal = 0,                -- 全部丹药总点数
    typeCounts = {0, 0, 0, 0, 0}   -- 每种类型的数量
}

-- 丹药消耗追踪
local previousElixirSnapshot = nil  -- 之前的丹药快照
local elixirConsumption = {
    typeTotals = {0, 0, 0, 0, 0},  -- 每种类型消耗的总点数
    grandTotal = 0,                -- 消耗的总点数
    typeCounts = {0, 0, 0, 0, 0},  -- 每种类型消耗的数量
    details = {}                    -- 详细消耗记录（按类型和品质）
}
local lastPrintedConsumption = 0  -- 上次打印的消耗总值，用于避免重复打印

-- 缓存背包数据键名
local BACKPACK_KEY = "\232\131\140\229\140\133"
local COUNT_KEY = "\230\149\176\233\135\143"
local TYPE_KEY = "\231\177\187\229\158\139"
local QUALITY_KEY = "品质"
local INDEX_KEY = "索引"

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

-- 创建丹药快照（用于追踪消耗）- 必须在BuyAccessory之前定义
local function CreateElixirSnapshot()
    local snapshot = {}  -- 按类型和品质分类存储（总是返回一个表，即使是空表）
    
    if not elixirData then
        return snapshot
    end
    
    local backpack = elixirData[BACKPACK_KEY]
    if not backpack or #backpack == 0 then
        return snapshot
    end
    
    -- 遍历背包中的物品
    local item, count, elixirType, quality, index
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
                                index = item[INDEX_KEY]
                                if index then
                                    local key = string.format("%d_%d_%s", elixirType, quality, tostring(index))
                                    snapshot[key] = {
                                        type = elixirType,
                                        quality = quality,
                                        count = count,
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
    
    return snapshot
end

-- 检查是否有新的丹药消耗（用于验证购买是否成功）
local function CheckElixirConsumptionAfterPurchase(previousSnapshot)
    -- 等待一小段时间让数据同步
    task.wait(0.3)
    
    -- 如果数据已更新，创建当前快照并比较
    if elixirData and elixirData[BACKPACK_KEY] then
        local currentSnapshot = CreateElixirSnapshot()
        if previousSnapshot and currentSnapshot and type(previousSnapshot) == "table" then
            -- 比较快照，检查是否有减少（消耗）
            for key, prevItem in pairs(previousSnapshot) do
                if prevItem and type(prevItem) == "table" then
                    local currItem = currentSnapshot[key]
                    local prevCount = prevItem.count or 0
                    local currCount = currItem and currItem.count or 0
                    if prevCount > currCount then
                        -- 检测到消耗，说明购买成功
                        return true, prevCount - currCount
                    end
                end
            end
        end
    end
    
    -- 如果没有快照，回退到检查消耗统计的方法
    local previousConsumptionTotal = elixirConsumption.grandTotal or 0
    task.wait(0.2)  -- 再等待一下
    local currentConsumptionTotal = elixirConsumption.grandTotal or 0
    local hasConsumption = currentConsumptionTotal > previousConsumptionTotal
    
    return hasConsumption, currentConsumptionTotal - previousConsumptionTotal
end

-- 购买挂饰函数（检查丹药消耗来验证购买是否成功）
local function BuyAccessory(playerName, itemId, price, accessoryId, quality)
    -- itemId 应该是UUID格式的字符串，例如 "b75d7cfc-8a21-413f-b66a-42c3c3a0f66a"
    local maxRetries = 3
    local retryCount = 0
    local purchaseSuccess = false
    
    while retryCount < maxRetries and not purchaseSuccess do
        retryCount = retryCount + 1
        
        -- 记录购买前的丹药快照（用于验证购买是否成功）
        local previousSnapshot = CreateElixirSnapshot()
        
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
        
        -- 如果发送请求成功，检查是否有丹药消耗来验证购买是否成功
        if callSuccess and result == true then
            -- 检查是否有新的丹药消耗
            local hasConsumption, consumedCount = CheckElixirConsumptionAfterPurchase(previousSnapshot)
            
            if hasConsumption then
                -- 有消耗，说明购买成功
                purchaseSuccess = true
            else
                -- 没有消耗，可能是商店未开放或其他原因，继续重试
                if retryCount < maxRetries then
                    task.wait(0.1)  -- 等待后重试
                end
            end
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
        
        -- 添加到历史记录（最新的在前面）
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
        
        -- 打印购买成功信息
        print(string.format("✓ 购买成功! 挂饰: %s(%d), 品质: %s(%d), 价格: %d, 卖家: %s", 
            historyEntry.accessoryName, 
            historyEntry.accessoryId, 
            historyEntry.qualityName, 
            historyEntry.quality, 
            historyEntry.price, 
            historyEntry.sellerName))
        
        return true
    else
        -- 购买失败，打印信息
        print(string.format("✗ 购买失败: 挂饰: %s(%d), 品质: %s(%d), 价格: %d, 卖家: %s (未检测到丹药消耗，可能商店未开放)", 
            ACCESSORY_TYPE_NAMES[accessoryId] or tostring(accessoryId),
            accessoryId,
            QUALITY_NAMES[quality] or tostring(quality),
            quality,
            price,
            playerName))
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

-- 计算丹药点数
local function CalculateElixirPoints()
    if not elixirData then
        return {0, 0, 0, 0, 0}, 0, {0, 0, 0, 0, 0}
    end
    
    local backpack = elixirData[BACKPACK_KEY]
    if not backpack or #backpack == 0 then
        return {0, 0, 0, 0, 0}, 0, {0, 0, 0, 0, 0}
    end
    
    local typeTotals = {0, 0, 0, 0, 0}  -- 每种类型的总点数
    local typeCounts = {0, 0, 0, 0, 0}  -- 每种类型的数量
    local grandTotal = 0                -- 全部丹药总点数
    
    -- 遍历背包中的物品
    local item, count, elixirType, quality, points
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
                                points = QUALITY_POINTS[quality]
                                if points then
                                    points = points * count
                                    typeTotals[elixirType] = typeTotals[elixirType] + points
                                    typeCounts[elixirType] = typeCounts[elixirType] + count
                                    grandTotal = grandTotal + points
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return typeTotals, grandTotal, typeCounts
end

-- 计算丹药消耗（累加模式，不清空之前的记录）
local function CalculateElixirConsumption(currentSnapshot)
    if not previousElixirSnapshot or not currentSnapshot then
        return false  -- 返回是否有消耗
    end
    
    -- 计算本次消耗增量（不重置，而是累加）
    local hasConsumption = false
    local deltaTypeTotals = {0, 0, 0, 0, 0}
    local deltaGrandTotal = 0
    local deltaTypeCounts = {0, 0, 0, 0, 0}
    local deltaDetails = {}
    
    -- 比较前后快照，找出减少的丹药
    for key, prevItem in pairs(previousElixirSnapshot) do
        local currItem = currentSnapshot[key]
        local prevCount = prevItem.count or 0
        local currCount = currItem and currItem.count or 0
        
        if prevCount > currCount then
            hasConsumption = true
            local consumed = prevCount - currCount
            local elixirType = prevItem.type
            local quality = prevItem.quality
            local pointsPerItem = QUALITY_POINTS[quality] or 0
            local totalPoints = pointsPerItem * consumed
            
            -- 计算本次增量
            deltaTypeTotals[elixirType] = deltaTypeTotals[elixirType] + totalPoints
            deltaTypeCounts[elixirType] = deltaTypeCounts[elixirType] + consumed
            deltaGrandTotal = deltaGrandTotal + totalPoints
            
            -- 记录详细信息
            if not deltaDetails[elixirType] then
                deltaDetails[elixirType] = {}
            end
            if not deltaDetails[elixirType][quality] then
                deltaDetails[elixirType][quality] = 0
            end
            deltaDetails[elixirType][quality] = deltaDetails[elixirType][quality] + consumed
        end
    end
    
    -- 只有在检测到消耗时才累加到总消耗统计中
    if hasConsumption then
        for i = 1, 5 do
            elixirConsumption.typeTotals[i] = elixirConsumption.typeTotals[i] + deltaTypeTotals[i]
            elixirConsumption.typeCounts[i] = elixirConsumption.typeCounts[i] + deltaTypeCounts[i]
        end
        elixirConsumption.grandTotal = elixirConsumption.grandTotal + deltaGrandTotal
        
        -- 累加详细信息
        for elixirType, qualityData in pairs(deltaDetails) do
            if not elixirConsumption.details[elixirType] then
                elixirConsumption.details[elixirType] = {}
            end
            for quality, count in pairs(qualityData) do
                if not elixirConsumption.details[elixirType][quality] then
                    elixirConsumption.details[elixirType][quality] = 0
                end
                elixirConsumption.details[elixirType][quality] = elixirConsumption.details[elixirType][quality] + count
            end
        end
    end
    
    return hasConsumption
end

-- 初始化/刷新丹药数据
local function RefreshElixirData()
    local elixirModule = ReplicatedStorage:FindFirstChild("\228\186\139\228\187\182")
    if not elixirModule then
        warn("找不到丹药模块")
        return false
    end
    
    local functionModule = elixirModule:FindFirstChild("\229\133\172\231\148\168")
    if not functionModule then
        warn("找不到功能模块")
        return false
    end
    
    local refreshModule = functionModule:FindFirstChild("\231\130\188\228\184\185")
    if not refreshModule then
        warn("找不到刷新模块")
        return false
    end
    
    local elixirEvent = refreshModule:FindFirstChild("\229\136\182\228\189\156")
    if not elixirEvent then
        warn("找不到刷新事件")
        return false
    end
    
    elixirEvent:FireServer()
    return true
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
    mainFrame.Size = UDim2.new(0, 500, 0, 850)  -- 增加高度以容纳丹药统计
    mainFrame.Position = UDim2.new(0.5, -250, 0.5, -425)
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
    historyFrame.Position = UDim2.new(0, 10, 0, 350)
    historyFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    historyFrame.BorderSizePixel = 1
    historyFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    historyFrame.Parent = mainFrame
    
    local historyTitle = Instance.new("TextLabel")
    historyTitle.Text = "最近购买记录:"
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
    
    -- 丹药统计区域
    local elixirFrame = Instance.new("Frame")
    elixirFrame.Size = UDim2.new(1, -20, 0, 180)
    elixirFrame.Position = UDim2.new(0, 10, 0, 560)
    elixirFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
    elixirFrame.BorderSizePixel = 1
    elixirFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
    elixirFrame.Parent = mainFrame
    
    local elixirTitle = Instance.new("TextLabel")
    elixirTitle.Text = "丹药统计:"
    elixirTitle.Size = UDim2.new(1, -10, 0, 25)
    elixirTitle.Position = UDim2.new(0, 5, 0, 5)
    elixirTitle.Font = Enum.Font.SourceSansBold
    elixirTitle.TextSize = 16
    elixirTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    elixirTitle.BackgroundTransparency = 1
    elixirTitle.TextXAlignment = Enum.TextXAlignment.Left
    elixirTitle.Parent = elixirFrame
    
    local elixirScroll = Instance.new("ScrollingFrame")
    elixirScroll.Name = "ElixirScroll"
    elixirScroll.Size = UDim2.new(1, -10, 1, -35)
    elixirScroll.Position = UDim2.new(0, 5, 0, 30)
    elixirScroll.BackgroundTransparency = 1
    elixirScroll.BorderSizePixel = 0
    elixirScroll.ScrollBarThickness = 6
    elixirScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    elixirScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    elixirScroll.Parent = elixirFrame
    
    local elixirText = Instance.new("TextLabel")
    elixirText.Name = "ElixirText"
    elixirText.Text = "点击'初始化丹药'按钮加载数据..."
    elixirText.Size = UDim2.new(1, -10, 0, 0)
    elixirText.Position = UDim2.new(0, 5, 0, 5)
    elixirText.Font = Enum.Font.SourceSans
    elixirText.TextSize = 13
    elixirText.TextColor3 = Color3.fromRGB(200, 200, 200)
    elixirText.BackgroundTransparency = 1
    elixirText.TextXAlignment = Enum.TextXAlignment.Left
    elixirText.TextYAlignment = Enum.TextYAlignment.Top
    elixirText.TextWrapped = true
    elixirText.AutomaticSize = Enum.AutomaticSize.Y
    elixirText.Parent = elixirScroll
    
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
    stopButton.Size = UDim2.new(0.31, 0, 1, 0)
    stopButton.Position = UDim2.new(0.34, 0, 0, 0)
    stopButton.Font = Enum.Font.SourceSansBold
    stopButton.TextSize = 16
    stopButton.TextColor3 = Color3.new(1, 1, 1)
    stopButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    stopButton.Parent = buttonFrame
    
    local elixirButton = Instance.new("TextButton")
    elixirButton.Name = "ElixirButton"
    elixirButton.Text = "初始化丹药"
    elixirButton.Size = UDim2.new(0.31, 0, 1, 0)
    elixirButton.Position = UDim2.new(0.68, 0, 0, 0)
    elixirButton.Font = Enum.Font.SourceSansBold
    elixirButton.TextSize = 14
    elixirButton.TextColor3 = Color3.new(1, 1, 1)
    elixirButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
    elixirButton.Parent = buttonFrame
    
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
    
    -- 初始化丹药按钮事件
    elixirButton.Activated:Connect(function()
        elixirButton.BackgroundColor3 = Color3.fromRGB(60, 90, 150)
        elixirText.Text = "正在初始化丹药数据..."
        task.wait(0.1)
        
        if RefreshElixirData() then
            -- 等待数据更新
            local startTime = tick()
            local timeout = 5
            while not elixirData or not elixirData[BACKPACK_KEY] do
                if tick() - startTime > timeout then
                    elixirText.Text = "错误: 获取丹药数据超时"
                    elixirButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
                    return
                end
                task.wait(0.1)
            end
            
            -- 计算丹药统计
            local typeTotals, grandTotal, typeCounts = CalculateElixirPoints()
            elixirStats.typeTotals = typeTotals
            elixirStats.grandTotal = grandTotal
            elixirStats.typeCounts = typeCounts
            
            -- 创建初始快照（用于后续追踪消耗）
            previousElixirSnapshot = CreateElixirSnapshot()
            
            -- 重置消耗统计
            elixirConsumption.typeTotals = {0, 0, 0, 0, 0}
            elixirConsumption.grandTotal = 0
            elixirConsumption.typeCounts = {0, 0, 0, 0, 0}
            elixirConsumption.details = {}
            lastPrintedConsumption = 0  -- 重置打印记录
            
            elixirText.Text = string.format("丹药数据加载成功！\n总点数: %d", grandTotal)
            elixirButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
            print(string.format("✓ 丹药数据初始化成功，总点数: %d", grandTotal))
        else
            elixirText.Text = "错误: 无法初始化丹药数据"
            elixirButton.BackgroundColor3 = Color3.fromRGB(80, 120, 200)
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
        
        -- 显示历史记录
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
            
            -- 按品质顺序显示（1-10）
            local qualityOrder = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
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
        
        -- 更新丹药统计显示
        local elixirLines = {}
        
        -- 显示当前拥有的丹药
        if elixirStats.grandTotal > 0 then
            table.insert(elixirLines, string.format("【当前拥有】总点数: %d", elixirStats.grandTotal))
            for i = 1, 5 do
                local typeTotal = elixirStats.typeTotals[i] or 0
                local typeCount = elixirStats.typeCounts[i] or 0
                if typeTotal > 0 or typeCount > 0 then
                    table.insert(elixirLines, string.format("  %s: %d点 (%d个)", 
                        ELIXIR_TYPE_NAMES[i] or i, typeTotal, typeCount))
                end
            end
        end
        
        -- 显示消耗的丹药
        if elixirConsumption.grandTotal > 0 then
            table.insert(elixirLines, "")
            table.insert(elixirLines, string.format("【消耗统计】总消耗: %d点", elixirConsumption.grandTotal))
            for i = 1, 5 do
                local consumedPoints = elixirConsumption.typeTotals[i] or 0
                local consumedCount = elixirConsumption.typeCounts[i] or 0
                if consumedPoints > 0 or consumedCount > 0 then
                    local detailText = {}
                    if elixirConsumption.details[i] then
                        for quality, count in pairs(elixirConsumption.details[i]) do
                            if count > 0 then
                                table.insert(detailText, string.format("品质%d×%d", quality, count))
                            end
                        end
                    end
                    local detailStr = #detailText > 0 and (" [" .. table.concat(detailText, ", ") .. "]") or ""
                    table.insert(elixirLines, string.format("  %s: %d点 (%d个)%s", 
                        ELIXIR_TYPE_NAMES[i] or i, consumedPoints, consumedCount, detailStr))
                end
            end
        end
        
        if #elixirLines > 0 then
            elixirText.Text = table.concat(elixirLines, "\n")
        elseif elixirStats.grandTotal == 0 then
            elixirText.Text = "点击'初始化丹药'按钮加载数据..."
        end
        
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
        historyContainer = historyContainer,
        elixirText = elixirText
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

-- 设置丹药数据同步事件监听
local function SetupElixirDataSync()
    local success, elixirSyncEvent = pcall(function()
        return ReplicatedStorage
            :WaitForChild("\228\186\139\228\187\182")          -- 药水
            :WaitForChild("\229\174\162\230\136\183\231\171\175") -- 同步模块
            :WaitForChild("\229\174\162\230\136\183\231\171\175\228\184\185\232\141\175") -- 同步控制器
            :WaitForChild("\228\184\185\232\141\175\230\149\176\230\141\174\229\143\152\229\140\150") -- 数据更新事件
    end)
    
    if success and elixirSyncEvent then
        elixirSyncEvent.Event:Connect(function(data)
            elixirData = data
            
            -- 创建当前快照
            local currentSnapshot = CreateElixirSnapshot()
            
            -- 如果有之前的快照，计算消耗
            if previousElixirSnapshot and currentSnapshot then
                local hasConsumption = CalculateElixirConsumption(currentSnapshot)
                
                -- 如果有新的消耗且与上次打印的不同，才打印本次消耗信息（避免重复打印）
                if hasConsumption and elixirConsumption.grandTotal > lastPrintedConsumption then
                    local deltaTotal = elixirConsumption.grandTotal - lastPrintedConsumption
                    local consumptionInfo = {}
                    for i = 1, 5 do
                        local consumedPoints = elixirConsumption.typeTotals[i] or 0
                        local consumedCount = elixirConsumption.typeCounts[i] or 0
                        if consumedPoints > 0 then
                            table.insert(consumptionInfo, string.format("%s:%d点(%d个)", 
                                ELIXIR_TYPE_NAMES[i] or i, consumedPoints, consumedCount))
                        end
                    end
                    if #consumptionInfo > 0 then
                        print(string.format("⚠ 丹药消耗: 本次消耗 %d点，累计总消耗 %d点 [%s]", 
                            deltaTotal, elixirConsumption.grandTotal, table.concat(consumptionInfo, ", ")))
                        lastPrintedConsumption = elixirConsumption.grandTotal
                    end
                end
            end
            
            -- 更新快照
            previousElixirSnapshot = currentSnapshot
            
            -- 自动计算丹药统计
            local typeTotals, grandTotal, typeCounts = CalculateElixirPoints()
            elixirStats.typeTotals = typeTotals
            elixirStats.grandTotal = grandTotal
            elixirStats.typeCounts = typeCounts
        end)
        print("✓ 丹药数据同步事件已连接")
        return true
    else
        warn("无法连接丹药数据同步事件")
        return false
    end
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

-- 设置丹药数据同步
SetupElixirDataSync()

-- 创建UI
CreateUI()

