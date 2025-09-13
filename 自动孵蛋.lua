local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local LocalPlayer = Players.LocalPlayer

-- Helper 获取 RemoteEvent
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
-- 递归打印 table（用于 debug）
-- =========================
local function printTable(t, indent, seen)
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
-- UI 创建（手机适配、透明背景）
-- =========================
local ScreenGui = Instance.new('ScreenGui')
ScreenGui.Name = 'AutoHatchUI'
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild('PlayerGui')

local InfoLabel = Instance.new('TextLabel')
InfoLabel.Size = UDim2.new(0.4, 0, 0.15, 0) -- 按比例适配
InfoLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
InfoLabel.BackgroundTransparency = 0.5
InfoLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
InfoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
InfoLabel.TextScaled = true
InfoLabel.TextWrapped = true
InfoLabel.Text = '加载中...'
InfoLabel.BorderSizePixel = 0
InfoLabel.Parent = ScreenGui

local function updateUI()
    local incubatingProgress = 0
    local incubating = latestData['孵化中']
    if incubating and type(incubating) == 'table' then
        incubatingProgress = incubating['孵化进度'] or 0
    end
    InfoLabel.Text = ('背包蛋数量: %d\n孵化中进度: %d秒'):format(
        #latestData['背包'],
        incubatingProgress
    )
end

-- =========================
-- 首次内存读取初始化 UI
-- =========================
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

print('===== 初次背包数据 =====')
printTable(latestData['背包'])
print('===== 初次孵化中数据 =====')
printTable(latestData['孵化中'])

-- =========================
-- RemoteEvent 回调更新 latestData
-- =========================
remoteReceiveData.OnClientEvent:Connect(function(data)
    if type(data) == 'table' then
        latestData['背包'] = type(data['背包']) == 'table' and data['背包'] or {}
        latestData['孵化中'] = type(data['孵化中']) == 'table' and data['孵化中'] or {}

        print('===== RemoteEvent 更新背包 =====')
        printTable(latestData['背包'])
        print('===== RemoteEvent 更新孵化中 =====')
        printTable(latestData['孵化中'])

        updateUI()
    end
end)

-- =========================
-- 随机选择背包蛋孵化（孵化中没有蛋才执行）
-- =========================
local function placeRandomEggIfNone()
    local incubating = latestData['孵化中']
    local hasIncubatingEgg = incubating
        and type(incubating) == 'table'
        and incubating['孵化进度']
        and incubating['孵化进度'] > 0

    if hasIncubatingEgg then
        return
    end

    local backpack = latestData['背包'] or {}
    if #backpack == 0 then
        return
    end

    local randomEgg = backpack[math.random(1, #backpack)]
    remotePlaceEgg:FireServer(randomEgg['索引'])
    print('随机放置孵化蛋索引:', randomEgg['索引'])
end

-- =========================
-- 每 10 秒强制刷新服务器数据
-- =========================
spawn(function()
    while true do
        wait(1)
        if tick() % 10 < 1 then
            local backpack = latestData['背包'] or {}
            if #backpack > 0 then
                local randomEgg = backpack[math.random(1, #backpack)]
                remoteFetchServer:FireServer(randomEgg['索引'])
                print('强制服务器刷新数据，蛋索引:', randomEgg['索引'])
            end
        end
    end
end)

-- =========================
-- 自动孵蛋和开蛋循环
-- =========================
spawn(function()
    while true do
        wait(1)
        local incubating = latestData['孵化中']
        local incubatingProgress = (incubating and incubating['孵化进度']) or 0
        local backpackCount = #latestData['背包']
        local hasIncubatingEgg = incubatingProgress > 0

        -- 背包+孵化中>2，孵化中没有蛋才随机孵化
        if backpackCount + (hasIncubatingEgg and 1 or 0) > 2 and not hasIncubatingEgg then
            placeRandomEggIfNone()
        end

        -- 孵化进度>=600秒开蛋
        if incubatingProgress >= 600 then
            remoteHatch:FireServer()
            print('孵化完成，开蛋！')
        end
    end
end)
