local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer

-- =========================
-- 配置常量
-- =========================
local CONFIG = {
    MIN_EGG_COUNT = 2,              -- 最小蛋数量（背包+孵化中 >= 此值才继续孵蛋）
    HATCH_TIME = 600,               -- 孵化完成时间（秒）
    SERVER_REFRESH_INTERVAL = 10,   -- 服务器数据刷新间隔（秒）
    MAIN_LOOP_INTERVAL = 1,         -- 主循环检查间隔（秒）
    EGG_PLACE_WAIT_TIME = 2,        -- 放置蛋后等待时间（秒）再检查进度
    DEBUG_MODE = false,             -- 是否开启调试输出
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
    local success, err = pcall(function()
        remotePlaceEgg:FireServer(randomEgg['索引'])
    end)
    
    if success then
        lastPlaceTime = currentTime
        placeEggWaitTime = currentTime + CONFIG.EGG_PLACE_WAIT_TIME  -- 设置等待截止时间
        print('随机放置孵化蛋索引:', randomEgg['索引'], '等待', CONFIG.EGG_PLACE_WAIT_TIME, '秒后检查进度')
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
        return
    end
    
    local success, err = pcall(function()
        remoteHatch:FireServer()
    end)
    
    if success then
        lastHatchTime = currentTime
        print('孵化完成，开蛋！')
        -- 开蛋后短暂延迟，等待服务器更新数据
        wait(0.5)
    else
        warn('开蛋失败:', err)
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
        
        -- 如果刚放置了蛋，在等待期内，跳过进度检查（等待服务器更新数据）
        local isWaitingForUpdate = currentTime < placeEggWaitTime
        if isWaitingForUpdate then
            updateUI()
            return  -- 等待期结束前不检查进度
        end
        
        -- 等待期结束后，检查实际的孵化进度
        local incubatingProgress = getIncubatingProgress()
        local hasIncubatingEgg = incubatingProgress > 0
        local totalEggCount = backpackCount + (hasIncubatingEgg and 1 or 0)
        
        -- 检查是否可以开蛋（孵化进度达到要求）
        if incubatingProgress >= CONFIG.HATCH_TIME then
            hatchEgg()
        -- 检查是否可以孵蛋（总蛋数 >= 最小数量 且 当前没有正在孵化的蛋）
        elseif totalEggCount >= CONFIG.MIN_EGG_COUNT and not hasIncubatingEgg then
            placeRandomEggIfNone()
        end
        
        -- 更新UI
        updateUI()
    end
end)
