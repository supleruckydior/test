local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer

-- =========================
-- 配置常量
-- =========================
local CONFIG = {
    MIN_EGG_COUNT = 1,              -- 最小蛋数量（背包中有 >= 此值就可以孵蛋，设置为1表示有蛋就孵）
    HATCH_TIME = 600,               -- 孵化完成时间（秒）
    LAST_EGG_HATCH_TIME = 630,      -- 最后一个蛋孵化时间（秒，10分30秒，用于无数据刷新时的强制开蛋）
    SERVER_REFRESH_INTERVAL = 10,   -- 服务器数据刷新间隔（秒）
    MAIN_LOOP_INTERVAL = 1,         -- 主循环检查间隔（秒）
    EGG_PLACE_WAIT_TIME = 2,        -- 放置蛋后等待时间（秒）再检查进度
    DEBUG_MODE = true,              -- 是否开启调试输出（开启以诊断问题）
}

-- =========================
-- Helper 获取 RemoteEvent
-- =========================
local function getRemote(path)
    local current = ReplicatedStorage
    for _, name in ipairs(path) do
        current = current:WaitForChild(name)
    end
    return current
end

-- =========================
-- RemoteEvents
-- =========================
local remoteFetchServer = getRemote({
    '\228\186\139\228\187\182',
    '\229\133\172\231\148\168',
    '\229\174\160\231\137\169\232\155\139',
    '\230\148\182\232\151\143',
})
local remoteHatch = getRemote({
    '\228\186\139\228\187\182',
    '\229\133\172\231\148\168',
    '\229\174\160\231\137\169\232\155\139',
    '\229\188\128\229\144\175',
})
local remotePlaceEgg = getRemote({
    '\228\186\139\228\187\182',
    '\229\133\172\231\148\168',
    '\229\174\160\231\137\169\232\155\139',
    '\229\173\181\229\140\150',
})
local remoteReceiveData = getRemote({
    '\228\186\139\228\187\182',
    '\229\133\172\231\148\168',
    '\229\174\160\231\137\169\232\155\139',
    '\229\144\140\230\173\165',
})

-- =========================
-- 保存最新数据
-- =========================
local latestData = { ['背包'] = {}, ['孵化中'] = {} }

-- =========================
-- 状态管理
-- =========================
local lastHatchTime = 0      -- 上次开蛋时间
local lastPlaceTime = 0      -- 上次放置蛋时间
local lastRefreshTime = 0    -- 上次刷新服务器数据时间
local placeEggWaitTime = 0   -- 放置蛋后的等待截止时间（用于延迟检查进度）
local lastEggPlaceTime = 0   -- 放置最后一个蛋的时间（背包为空时使用计时器开蛋）
local OPERATION_COOLDOWN = 0.5  -- 操作冷却时间（秒）

-- =========================
-- 调试输出函数
-- =========================
local function debugPrint(...)
    if CONFIG.DEBUG_MODE then
        print(...)
    end
end

-- =========================
-- 递归打印 table（用于 debug）
-- =========================
local function printTable(t, indent, seen)
    if not CONFIG.DEBUG_MODE then
        return
    end
    indent = indent or ''
    seen = seen or {}
    if seen[t] then
        print(indent .. tostring(t) .. ' : (已打印过)')
        return
    end
    seen[t] = true
    for k, v in pairs(t) do
        if type(v) == 'table' then
            print(indent .. tostring(k) .. ' : table')
            printTable(v, indent .. '    ', seen)
        else
            print(indent .. tostring(k) .. ' : ' .. tostring(v))
        end
    end
end

-- =========================
-- 安全获取孵化进度
-- =========================
local function getIncubatingProgress()
    local incubating = latestData['孵化中']
    if incubating and type(incubating) == 'table' then
        return incubating['孵化进度'] or 0
    end
    return 0
end

-- =========================
-- 安全获取背包数量
-- =========================
local function getBackpackCount()
    local backpack = latestData['背包']
    return backpack and #backpack or 0
end

-- =========================
-- UI 创建（手机适配、透明背景）
-- =========================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AutoHatchUI'
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild('PlayerGui')

local InfoLabel = Instance.new('TextLabel')
InfoLabel.Size = UDim2.new(0.4, 0, 0.15, 0)
InfoLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
InfoLabel.BackgroundTransparency = 0.5
InfoLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
InfoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
InfoLabel.TextScaled = true
InfoLabel.TextWrapped = true
InfoLabel.Text = '加载中...'
InfoLabel.BorderSizePixel = 0
InfoLabel.Parent = ScreenGui

-- =========================
-- 更新UI显示
-- =========================
local function updateUI()
    local backpackCount = getBackpackCount()
    local incubatingProgress = getIncubatingProgress()
    local totalCount = backpackCount + (incubatingProgress > 0 and 1 or 0)
    local remainingTime = math.max(0, CONFIG.HATCH_TIME - incubatingProgress)
    
    local statusText = '背包蛋数量: %d\n总蛋数量: %d\n'
    if incubatingProgress > 0 then
        statusText = statusText .. '孵化中: %d秒\n剩余: %d秒'
        InfoLabel.Text = statusText:format(backpackCount, totalCount, incubatingProgress, remainingTime)
    else
        statusText = statusText .. '状态: 待孵化'
        InfoLabel.Text = statusText:format(backpackCount, totalCount)
    end
end

-- =========================
-- 首次内存读取初始化数据
-- =========================
local function initializeData()
    local latestTable = nil
    local seenTables = {}
    for i, obj in ipairs(getgc(true)) do
        if type(obj) == 'table' then
            local incubating = rawget(obj, '孵化中')
            if incubating ~= nil then
                local address = tostring(obj)
                if not seenTables[address] then
                    seenTables[address] = true
                    latestTable = obj
                end
            end
        end
    end
    
    latestData['背包'] = latestTable and latestTable['背包'] or {}
    latestData['孵化中'] = latestTable and latestTable['孵化中'] or {}
    updateUI()
    
    debugPrint('===== 初次背包数据 =====')
    printTable(latestData['背包'])
    debugPrint('===== 初次孵化中数据 =====')
    printTable(latestData['孵化中'])
end

initializeData()

-- =========================
-- RemoteEvent 回调更新 latestData
-- =========================
remoteReceiveData.OnClientEvent:Connect(function(data)
    if type(data) == 'table' then
        latestData['背包'] = type(data['背包']) == 'table' and data['背包'] or {}
        latestData['孵化中'] = type(data['孵化中']) == 'table' and data['孵化中'] or {}
        
        debugPrint('===== RemoteEvent 更新背包 =====')
        printTable(latestData['背包'])
        debugPrint('===== RemoteEvent 更新孵化中 =====')
        printTable(latestData['孵化中'])
        
        updateUI()
    end
end)

-- =========================
-- 随机选择背包蛋孵化（孵化中没有蛋才执行）
-- =========================
local function placeRandomEggIfNone()
    -- 检查是否在冷却期
    local currentTime = tick()
    if currentTime - lastPlaceTime < OPERATION_COOLDOWN then
        return
    end
    
    -- 检查是否已有正在孵化的蛋
    if getIncubatingProgress() > 0 then
        return
    end
    
    local backpack = latestData['背包'] or {}
    if #backpack == 0 then
        return
    end
    
    -- 随机选择蛋并放置
    local randomEgg = backpack[math.random(1, #backpack)]
    local isLastEgg = #backpack == 1  -- 判断是否是最后一个蛋
    
    local success, err = pcall(function()
        remotePlaceEgg:FireServer(randomEgg['索引'])
    end)
    
    if success then
        lastPlaceTime = currentTime
        placeEggWaitTime = currentTime + CONFIG.EGG_PLACE_WAIT_TIME  -- 设置等待截止时间
        
        -- 如果是最后一个蛋，记录放置时间，用于后续计时开蛋
        if isLastEgg then
            lastEggPlaceTime = currentTime
            print('随机放置孵化蛋索引:', randomEgg['索引'], '(最后一个蛋) 等待', CONFIG.EGG_PLACE_WAIT_TIME, '秒后检查进度，将在', CONFIG.LAST_EGG_HATCH_TIME, '秒后强制开蛋')
        else
            print('随机放置孵化蛋索引:', randomEgg['索引'], '等待', CONFIG.EGG_PLACE_WAIT_TIME, '秒后检查进度')
        end
    else
        warn('放置蛋失败:', err)
    end
end

-- =========================
-- 开蛋
-- =========================
local function hatchEgg()
    local currentTime = tick()
    if currentTime - lastHatchTime < OPERATION_COOLDOWN then
        print('[开蛋] 冷却中，剩余', OPERATION_COOLDOWN - (currentTime - lastHatchTime), '秒')
        return
    end
    
    local incubatingProgress = getIncubatingProgress()
    print('[开蛋] 尝试开蛋，当前孵化进度:', incubatingProgress, '秒，要求:', CONFIG.HATCH_TIME, '秒')
    
    local success, err = pcall(function()
        remoteHatch:FireServer()
    end)
    
    if success then
        lastHatchTime = currentTime
        print('[开蛋] 成功！孵化完成，开蛋！')
        -- 开蛋后短暂延迟，等待服务器更新数据
        wait(0.5)
    else
        warn('[开蛋] 失败:', err)
    end
end

-- =========================
-- 强制刷新服务器数据
-- =========================
local function refreshServerData()
    local currentTime = tick()
    if currentTime - lastRefreshTime < CONFIG.SERVER_REFRESH_INTERVAL then
        return
    end
    
    local backpack = latestData['背包'] or {}
    if #backpack == 0 then
        return
    end
    
    local randomEgg = backpack[math.random(1, #backpack)]
    local success, err = pcall(function()
        remoteFetchServer:FireServer(randomEgg['索引'])
    end)
    
    if success then
        lastRefreshTime = currentTime
        debugPrint('强制服务器刷新数据，蛋索引:', randomEgg['索引'])
    else
        warn('刷新服务器数据失败:', err)
    end
end

-- =========================
-- 每 N 秒强制刷新服务器数据
-- =========================
spawn(function()
    while true do
        wait(CONFIG.MAIN_LOOP_INTERVAL)
        refreshServerData()
    end
end)

-- =========================
-- 自动孵蛋和开蛋循环
-- =========================
spawn(function()
    while true do
        wait(CONFIG.MAIN_LOOP_INTERVAL)
        
        local currentTime = tick()
        local backpackCount = getBackpackCount()
        local incubatingProgress = getIncubatingProgress()
        local hasIncubatingEgg = incubatingProgress > 0
        local remainingTime = math.max(0, CONFIG.HATCH_TIME - incubatingProgress)
        local totalEggCount = backpackCount + (hasIncubatingEgg and 1 or 0)
        local isLastEggSituation = backpackCount == 0 and hasIncubatingEgg  -- 最后一个蛋的情况：背包为空且有孵化中的蛋
        
        -- 如果刚放置了蛋，在等待期内，跳过放置新蛋的检查（但开蛋检查不受影响）
        local isWaitingForUpdate = currentTime < placeEggWaitTime
        
        -- 调试输出（每10秒输出一次）
        if math.floor(currentTime) % 10 == 0 then
            local timeSinceLastEgg = isLastEggSituation and (currentTime - lastEggPlaceTime) or 0
            print(string.format('[主循环] 背包:%d 进度:%d秒 剩余:%d秒 等待期:%s 有蛋:%s 最后蛋:%s%s', 
                backpackCount, incubatingProgress, remainingTime, 
                tostring(isWaitingForUpdate), tostring(hasIncubatingEgg), tostring(isLastEggSituation),
                isLastEggSituation and string.format(' 已过:%d秒', timeSinceLastEgg) or ''))
        end
        
        -- 优先检查是否可以开蛋（不受等待期影响，因为开蛋是重要操作）
        if incubatingProgress >= CONFIG.HATCH_TIME then
            print('[主循环] 检测到孵化完成，准备开蛋！进度:', incubatingProgress, '>=', CONFIG.HATCH_TIME)
            hatchEgg()
            lastEggPlaceTime = 0  -- 开蛋后重置最后蛋计时
        -- 如果是最后一个蛋的情况，使用计时器判断是否到开蛋时间（10分30秒）
        elseif isLastEggSituation and lastEggPlaceTime > 0 then
            local timeSinceLastEgg = currentTime - lastEggPlaceTime
            if timeSinceLastEgg >= CONFIG.LAST_EGG_HATCH_TIME then
                print('[主循环] 最后一个蛋计时到达，强制开蛋！已过:', timeSinceLastEgg, '秒 >=', CONFIG.LAST_EGG_HATCH_TIME, '秒')
                hatchEgg()
                lastEggPlaceTime = 0  -- 开蛋后重置最后蛋计时
            end
        -- 如果剩余时间<=0但进度还没更新，也尝试开蛋（防止数据延迟）
        elseif hasIncubatingEgg and remainingTime <= 0 and incubatingProgress > 0 then
            print('[主循环] 剩余时间<=0，强制尝试开蛋！进度:', incubatingProgress, '剩余:', remainingTime)
            hatchEgg()
            lastEggPlaceTime = 0  -- 开蛋后重置最后蛋计时
        -- 检查是否可以孵蛋（背包有蛋 >= 最小数量 且 当前没有正在孵化的蛋 且 不在等待更新期）
        -- 注意：这里只检查背包数量，不检查总数量，这样即使只有1个蛋也能孵蛋
        elseif not isWaitingForUpdate and backpackCount >= CONFIG.MIN_EGG_COUNT and not hasIncubatingEgg then
            print('[主循环] 准备孵蛋，背包蛋数:', backpackCount, '总蛋数:', totalEggCount)
            placeRandomEggIfNone()
        end
        
        -- 更新UI
        updateUI()
    end
end)
