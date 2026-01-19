-- 附魔剑雕像自动锁定脚本
-- 功能：监听数据同步，自动锁定满足条件的词条
-- 目标：第一个数组（组数据[1]）
-- 条件：词条名称为"经验获取率"，品质 >= 3

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- 获取数据同步事件
local syncEvent = ReplicatedStorage
    :WaitForChild("\228\186\139\228\187\182")          -- 药水
    :WaitForChild("\229\133\172\231\148\168")          -- 功能
    :WaitForChild("\229\137\145\233\155\149\229\131\143")  -- 刷新器
    :WaitForChild("\229\144\140\230\173\165\230\149\176\230\141\174")  -- 同步数据

-- 获取附魔事件（刷新和锁定都用这个路径）
local enchantEvent = ReplicatedStorage
    :WaitForChild("\228\186\139\228\187\182")          -- 药水
    :WaitForChild("\229\133\172\231\148\168")          -- 功能
    :WaitForChild("\229\137\145\233\155\149\229\131\143")  -- 刷新器
    :WaitForChild("\231\165\136\231\165\183")          -- 附魔

-- 刷新事件使用附魔路径（同一个事件）
local refreshEvent = enchantEvent

-- 配置
local TARGET_GROUP = 1  -- 目标组（第一个数组）
local TARGET_NAME = "金币获取率"  -- 目标词条名称
local MIN_QUALITY = 3  -- 最低品质要求
local REFRESH_COST = 100  -- 刷新消耗
local LOCK_COST = 100  -- 每个锁定消耗
local MAX_ENTRIES = 5  -- 最大词条数量

-- 已锁定的词条索引（避免重复锁定）
local lockedIndices = {}
local isRunning = false  -- 运行状态
local hasStopped = false  -- 是否已停止（停止后不再启动）
local isProcessing = false  -- 是否正在处理数据（防止重复处理）
local pendingData = nil  -- 待处理的数据（如果有新数据在处理中到达）

-- 获取代币数量
local function getTokenCount()
    local success, result = pcall(function()
        local player = Players.LocalPlayer
        local gui = player:WaitForChild("PlayerGui"):WaitForChild("GUI")
        local secondLevel = gui:WaitForChild("\228\186\140\231\186\167\231\149\140\233\157\162")  -- 二级界面
        local refresh = secondLevel:WaitForChild("\229\137\145\233\155\149\229\131\143")  -- 刷新器
        local backpack = refresh:WaitForChild("\232\131\140\230\153\175")  -- 背包
        local enchant = backpack:WaitForChild("\229\189\162\232\177\161")  -- 附魔
        local life = enchant:WaitForChild("\231\148\159\229\145\189\228\185\139\230\176\180")  -- 生命附魔
        local button = life:WaitForChild("\230\140\137\233\146\174")  -- 按钮
        local text = button:WaitForChild("\229\128\188")  -- 值
        
        local textValue = tonumber(text.Text) or 0
        return textValue
    end)
    
    if success then
        return result
    else
        warn("获取代币数量失败: " .. tostring(result))
        return 0
    end
end

-- 检查停止条件
local function shouldStop(satisfiedCount, newLocksCount)
    -- 条件1: 5个词条都满足条件
    if satisfiedCount >= MAX_ENTRIES then
        print("✓ 所有词条都满足条件，停止运行")
        return true, "所有词条满足条件"
    end
    
    -- 条件2: 代币不足
    local currentTokens = getTokenCount()
    local totalCost = REFRESH_COST + (newLocksCount * LOCK_COST)
    
    if currentTokens < totalCost then
        print(string.format("✗ 代币不足，停止运行 (当前: %d, 需要: %d)", currentTokens, totalCost))
        return true, "代币不足"
    end
    
    return false, nil
end

-- 刷新附魔（刷新即锁定：每次刷新都带上当前锁定表）
local function refreshEnchant(lockTable)
    local success, result = pcall(function()
        local args = {lockTable or {}}
        refreshEvent:FireServer(unpack(args))
        return true
    end)
    
    if success then
        print("✓ 已发送刷新请求")
        return true
    else
        warn("✗ 刷新失败: " .. tostring(result))
        return false
    end
end

print("=" .. string.rep("=", 60))
print("✓ 附魔剑雕像自动锁定已启动")
print("目标组: " .. TARGET_GROUP)
print("目标词条: " .. TARGET_NAME)
print("最低品质: " .. MIN_QUALITY)
print("刷新消耗: " .. REFRESH_COST .. " 代币")
print("锁定消耗: " .. LOCK_COST .. " 代币/个")
print("=" .. string.rep("=", 60))

-- 检查并锁定满足条件的词条（只更新锁定表，不单独调用锁定）
local function checkAndLock(data)
    if not data or type(data) ~= "table" then
        return 0, 0, {}  -- 返回满足条件的数量、新增锁定数量、锁定表
    end
    
    local groupData = data["组数据"]
    if not groupData or type(groupData) ~= "table" then
        print("警告: 未找到组数据")
        return 0, 0, {}
    end
    
    local targetGroup = groupData[TARGET_GROUP]
    if not targetGroup or type(targetGroup) ~= "table" then
        print("警告: 未找到目标组 " .. TARGET_GROUP)
        return 0, 0, {}
    end
    
    local satisfiedCount = 0  -- 满足条件的词条数量
    local newLocksCount = 0   -- 新增锁定的数量
    
    -- 检查目标组中的每个词条
    for index, entry in ipairs(targetGroup) do
        if entry and type(entry) == "table" then
            local name = entry["名称"]
            local quality = entry["品质"]
            
            -- 检查是否满足条件
            if name == TARGET_NAME and quality and quality >= MIN_QUALITY then
                satisfiedCount = satisfiedCount + 1
                local indexStr = tostring(index)
                
                -- 如果还没有锁定，则加入锁定表
                if not lockedIndices[indexStr] then
                    lockedIndices[indexStr] = true
                    newLocksCount = newLocksCount + 1
                    
                    print(string.format("✓ 加入锁定词条 #%d: %s (品质: %d)", 
                        index, name, quality))
                else
                    -- 已经锁定过，跳过
                    print(string.format("ℹ 词条 #%d 已锁定，跳过", index))
                end
            end
        end
    end

    -- 构建锁定表（每次刷新都带上所有已锁定的索引）
    local lockTable = {}
    for indexStr, isLocked in pairs(lockedIndices) do
        if isLocked then
            lockTable[indexStr] = true
        end
    end

    return satisfiedCount, newLocksCount, lockTable
end

-- 处理数据并继续运行
local function processDataAndContinue(data)
    if not data or type(data) ~= "table" then
        return
    end
    
    -- 如果正在处理，保存数据等待处理完成后再继续（不忽略）
    if isProcessing then
        pendingData = data
        return
    end
    
    isProcessing = true
    
    -- 处理当前数据
    print("\n[收到数据] 时间: " .. os.date("%H:%M:%S"))
    
    -- 检查并锁定（返回锁定表）
    local satisfiedCount, newLocksCount, lockTable = checkAndLock(data)
    
    print(string.format("[统计] 满足条件: %d/%d, 新增锁定: %d", 
        satisfiedCount, MAX_ENTRIES, newLocksCount))
    
    -- 检查停止条件
    local shouldStopFlag, reason = shouldStop(satisfiedCount, newLocksCount)
    if shouldStopFlag then
        isRunning = false
        hasStopped = true
        isProcessing = false
        pendingData = nil
        print("[停止原因] " .. reason)
        return
    end
    
    -- 如果还有不满足条件的词条，立即刷新
    if satisfiedCount < MAX_ENTRIES then
        local currentTokens = getTokenCount()
        local nextCost = REFRESH_COST
        
        if currentTokens >= nextCost then
            print("[继续] 立即刷新...")
            -- 立即刷新，不等待
            refreshEnchant(lockTable)
            -- 刷新后立即结束处理，等待服务器返回新数据
            -- 新数据到达时会触发事件，重新调用 processDataAndContinue
            isProcessing = false
            -- 检查是否有待处理的数据（在处理期间到达的），立即处理
            if pendingData then
                local nextData = pendingData
                pendingData = nil
                -- 立即处理新数据（不等待）
                processDataAndContinue(nextData)
            end
            return
        else
            print("✗ 代币不足，停止运行")
            isRunning = false
            hasStopped = true
            isProcessing = false
            pendingData = nil
            return
        end
    else
        -- 所有词条都满足条件
        isRunning = false
        hasStopped = true
        isProcessing = false
        pendingData = nil
        return
    end
end

-- 监听数据同步事件
syncEvent.OnClientEvent:Connect(function(data)
    if not data or type(data) ~= "table" then
        return
    end
    
    -- 如果已经停止过，不再处理
    if hasStopped then
        return
    end
    
    -- 如果是第一次收到数据，启动运行
    if not isRunning then
        isRunning = true
        print("\n[启动] 收到数据，开始自动运行")
        
        -- 检查初始代币
        local currentTokens = getTokenCount()
        print(string.format("[检查] 当前代币: %d", currentTokens))
        
        if currentTokens < REFRESH_COST then
            print("✗ 代币不足，无法启动")
            isRunning = false
            hasStopped = true
            return
        end
    end
    
    -- 收到新数据立即处理（无论当前状态如何）
    -- 如果正在处理中，数据会被保存并在处理完成后继续
    processDataAndContinue(data)
end)

print("监听器已连接，等待数据启动...")

