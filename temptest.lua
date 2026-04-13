local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local UserInputService = game:GetService("UserInputService")

-- 等待界面加载完成
local GUI = PlayerGui:WaitForChild("GUI")
local BaseUI = GUI:WaitForChild("\229\159\186\231\161\128")
local TimeIndicator = BaseUI:WaitForChild("\229\128\146\232\174\161\230\151\182\230\161\134")

-- 获取事件对象
local elixirSyncEvent = ReplicatedStorage
    ["\228\186\139\228\187\182"]
    ["\229\174\162\230\136\183\231\171\175"]
    ["\229\174\162\230\136\183\231\171\175\228\184\185\232\141\175"]
    ["\228\184\185\232\141\175\230\149\176\230\141\174\229\143\152\229\140\150"]

local addTradeItemEvent = ReplicatedStorage
    ["\228\186\139\228\187\182"]
    ["\229\133\172\231\148\168"]
    ["\228\186\164\230\152\147"]
    ["\230\150\176\229\162\158\228\186\164\230\152\147\231\137\169\229\147\129"]

local requestTradeEvent = ReplicatedStorage
    ["\228\186\139\228\187\182"]
    ["\229\133\172\231\148\168"]
    ["\228\186\164\230\152\147"]
    :WaitForChild("\231\148\179\232\175\183\228\186\164\230\152\147")

local confirmTradeEvent = ReplicatedStorage
    ["\228\186\139\228\187\182"]
    ["\229\133\172\231\148\168"]
    ["\228\186\164\230\152\147"]
    :WaitForChild("\233\148\129\229\174\154\228\186\164\230\152\147")

local tradePriceEvent = ReplicatedStorage
    ["\228\186\139\228\187\182"]
    ["\229\133\172\231\148\168"]
    ["\228\186\164\230\152\147"]
    :WaitForChild("\228\186\164\230\152\147\231\190\189\230\160\184")

local elixirData = {}

-- 数据同步处理
elixirSyncEvent.Event:Connect(function(data)
    elixirData = data
end)

-- 获取蛋数据的 RemoteEvents
local remoteFetchServer = ReplicatedStorage
    :WaitForChild("\228\186\139\228\187\182")
    :WaitForChild("\229\133\172\231\148\168")
    :WaitForChild("\229\174\160\231\137\169\232\155\139")
    :WaitForChild("\230\148\182\232\151\143")

local remoteReceiveData = ReplicatedStorage
    :WaitForChild("\228\186\139\228\187\182")
    :WaitForChild("\229\133\172\231\148\168")
    :WaitForChild("\229\174\160\231\137\169\232\155\139")
    :WaitForChild("\229\144\140\230\173\165")

-- 保存蛋数据
local eggData = { ['背包'] = {}, ['孵化中'] = {} }

-- =========================
-- 首次从内存读取蛋数据
-- =========================
local function getEggDataFromMemory()
    local latestTable = nil
    local seenTables = {}
    
    for i, obj in ipairs(getgc(true)) do
        if type(obj) == "table" then
            local address = tostring(obj)
            if not seenTables[address] then
                seenTables[address] = true
                
                -- 检查是否包含蛋数据
                local hasBackpack = rawget(obj, "\232\131\140\229\140\133") or rawget(obj, "背包")
                local hasIncubating = rawget(obj, "\229\173\181\229\140\150\228\184\173") or rawget(obj, "孵化中")
                
                if hasBackpack or hasIncubating then
                    latestTable = obj
                    print("找到蛋数据表")
                    break
                end
            end
        end
    end
    
    if latestTable then
        -- 尝试获取背包数据
        local backpack = rawget(latestTable, "\232\131\140\229\140\133") or rawget(latestTable, "背包")
        if type(backpack) == "table" then
            eggData['背包'] = backpack
            print("从内存获取背包蛋数量:", #backpack)
        end
        
        -- 尝试获取孵化中数据
        local incubating = rawget(latestTable, "\229\173\181\229\140\150\228\184\173") or rawget(latestTable, "孵化中")
        if type(incubating) == "table" then
            eggData['孵化中'] = incubating
            print("从内存获取孵化中数据")
        end
    else
        print("未从内存找到蛋数据")
    end
end

-- 执行首次内存读取
getEggDataFromMemory()

-- 接收蛋数据更新（持续监听）
remoteReceiveData.Event:Connect(function(data)
    if type(data) == "table" then
        -- 更新背包数据
        if type(data["\232\131\140\229\140\133"]) == "table" then
            eggData['背包'] = data["\232\131\140\229\140\133"]
        elseif type(data["背包"]) == "table" then
            eggData['背包'] = data["背包"]
        end
        
        -- 更新孵化中数据
        if type(data["\229\173\181\229\140\150\228\184\173"]) == "table" then
            eggData['孵化中'] = data["\229\173\181\229\140\150\228\184\173"]
        elseif type(data["孵化中"]) == "table" then
            eggData['孵化中'] = data["孵化中"]
        end
        
        print("RemoteEvent 更新蛋数据，背包蛋数量:", #eggData['背包'])
    end
end)

-- 系统控制变量
local running = true
local tradeMode = "both" -- "elixir", "armor", "egg", "both"

-- 创建监控界面
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoTradeMonitor"
if syn and syn.protect_gui then
    syn.protect_gui(screenGui)
end
screenGui.Parent = PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 320, 0, 180)
mainFrame.Position = UDim2.new(0, 10, 1, -190)
mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mainFrame.BorderColor3 = Color3.fromRGB(255, 0, 0)
mainFrame.BorderSizePixel = 2
mainFrame.Parent = screenGui

local titleBar = Instance.new("TextLabel")
titleBar.Size = UDim2.new(1, 0, 0, 20)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.Text = "自动交易系统 V2.0"
titleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
titleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(0.9, 0, 0.5, 0)
infoLabel.Position = UDim2.new(0.05, 0, 0.1, 20)
infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
infoLabel.BackgroundTransparency = 1
infoLabel.Font = Enum.Font.SourceSansBold
infoLabel.TextSize = 16
infoLabel.TextXAlignment = Enum.TextXAlignment.Center
infoLabel.TextYAlignment = Enum.TextYAlignment.Center

local textStroke = Instance.new("UIStroke")
textStroke.Color = Color3.fromRGB(255, 0, 0)
textStroke.Thickness = 0.1
textStroke.Parent = infoLabel
infoLabel.Text = "自动交易启动中...\n模式: 丹药+翅膀+蛋"
infoLabel.Parent = mainFrame

local buttonContainer = Instance.new("Frame")
buttonContainer.Size = UDim2.new(0.9, 0, 0.25, 0)
buttonContainer.Position = UDim2.new(0.05, 0, 0.7, 0)
buttonContainer.BackgroundTransparency = 1
buttonContainer.Parent = mainFrame

local modeButton = Instance.new("TextButton")
modeButton.Size = UDim2.new(0.45, 0, 0.8, 0)
modeButton.Position = UDim2.new(0, 0, 0, 0)
modeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
modeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
modeButton.BorderColor3 = Color3.fromRGB(0, 255, 0)
modeButton.Text = "切换模式"
modeButton.Parent = buttonContainer

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0.45, 0, 0.8, 0)
closeButton.Position = UDim2.new(0.55, 0, 0, 0)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
closeButton.BorderColor3 = Color3.fromRGB(255, 0, 0)
closeButton.Text = "关闭系统"
closeButton.Parent = buttonContainer

-- 窗口拖拽系统
local dragging = false
local dragStart, startPos

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
    end
end)

titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- 模式切换功能
local modeColors = {
    both = Color3.fromRGB(0, 255, 0),
    elixir = Color3.fromRGB(0, 0, 255),
    armor = Color3.fromRGB(255, 255, 0),
    egg = Color3.fromRGB(255, 0, 255)
}

local modeNames = {
    both = "丹药+翅膀+蛋",
    elixir = "仅丹药",
    armor = "仅翅膀", 
    egg = "仅蛋"
}

modeButton.MouseButton1Click:Connect(function()
    local modes = {"both", "elixir", "armor", "egg"}
    local currentIndex = table.find(modes, tradeMode) or 1
    tradeMode = modes[(currentIndex % #modes) + 1]
    
    modeButton.BorderColor3 = modeColors[tradeMode]
    infoLabel.Text = "自动交易运行中...\n模式: " .. modeNames[tradeMode] .. "\n蛋数量: " .. #eggData['背包']
end)

-- 关闭功能
closeButton.MouseButton1Click:Connect(function()
    running = false
    screenGui:Destroy()
end)

-- 翅膀背包数据搜索函数
local function findArmorBackpackData()
    for i, obj in ipairs(getgc(true)) do
        if type(obj) == "table" then
            for k, v in pairs(obj) do
                if type(v) == "table" and (rawget(v, "翅膀ID") or rawget(v, "wingId")) then
                    return v
                end
            end
        end
    end
    return {}
end

local armorBackpackData = findArmorBackpackData()

-- 交易函数
local function tradeItem(category, index)
    local success, err = pcall(function()
        addTradeItemEvent:FireServer(category, index, 999999)
    end)
    
    if success then
        print("成功交易" .. category .. ":", index)
    else
        warn(category .. "交易失败:", index, "错误:", err)
    end
end

-- 等待交易界面可见
local function waitForTradeUI()
    local startTime = tick()
    local maxWaitTime = 10
    
    while tick() - startTime < maxWaitTime and running do
        local success, tradeUI = pcall(function()
            return PlayerGui.GUI["\228\186\140\231\186\167\231\149\140\233\157\162"]["\228\186\164\230\152\147"]["\228\186\164\230\152\147\231\149\140\233\157\162"]
        end)
        
        if success and tradeUI and tradeUI.Visible then
            return true
        end
        wait(0.1)
    end
    return false
end

-- 主交易循环
coroutine.wrap(function()
    while running do
        if TimeIndicator.Visible then
            -- 获取交易邀请信息
            local tradeInviteText = ""
            pcall(function()
                tradeInviteText = PlayerGui.GUI["\229\159\186\231\161\128"]["\229\128\146\232\174\161\230\151\182\230\161\134"]["\232\131\140\230\153\175"]["\229\134\133\229\174\185"].Text
            end)
            
            local invitingPlayer = tradeInviteText:match("(.+) has invited you to trade")
            
            if invitingPlayer then
                -- 触发交易请求
                pcall(function()
                    requestTradeEvent:FireServer()
                end)
                
                wait(1.1)
                
                -- 设置交易价格
                local core = 0
                pcall(function()
                    core = tonumber(PlayerGui.GUI["\228\186\140\231\186\167\231\149\140\233\157\162"]["\228\186\164\230\152\147"]["\228\186\164\230\152\147\231\149\140\233\157\162"]["\230\136\145\231\154\132\232\131\140\229\140\133"]["\232\180\167\229\184\129"]["\231\190\189\230\160\184"]["\229\128\188"].Text) or 0
                end)
                
                pcall(function()
                    tradePriceEvent:FireServer(core)
                end)

                -- 根据模式执行交易
                if tradeMode == "elixir" or tradeMode == "both" then
                    if elixirData and elixirData["背包"] then
                        for slot, item in pairs(elixirData["背包"]) do
                            if type(item) == "table" then
                                local itemIndex = item["索引"] or item.Index or item.id
                                if itemIndex then
                                    tradeItem("\228\184\185\232\141\175", itemIndex)
                                    wait(0.1)
                                end
                            end
                        end
                    end
                end
                
                if tradeMode == "armor" or tradeMode == "both" then
                    if armorBackpackData then
                        for _, item in pairs(armorBackpackData) do
                            if item["翅膀ID"] or (type(item.wingId) == "number" and item.wingId > 0) then
                                local itemIndex = item["索引"] or item.Index or item.id
                                if itemIndex then
                                    tradeItem("\232\163\133\229\164\135", itemIndex)
                                    wait(0.1)
                                end
                            end
                        end
                    end
                end
                
                if tradeMode == "egg" or tradeMode == "both" then
                    if eggData and eggData['背包'] then
                        for _, egg in ipairs(eggData['背包']) do
                            if type(egg) == "table" then
                                local eggIndex = egg["索引"] or egg.Index or egg.id
                                if eggIndex then
                                    tradeItem("\229\174\160", eggIndex)
                                    wait(0.1)
                                end
                            end
                        end
                    end
                end
                
                -- 确认交易
                if waitForTradeUI() then
                    pcall(function()
                        confirmTradeEvent:FireServer(true)
                        print("交易已确认")
                    end)
                end

                wait(1)
            else
                wait(0.5)
            end
        else
            wait(0.1)
        end
    end
end)()

-- 定期刷新蛋数据和UI
coroutine.wrap(function()
    while running do
        wait(3)
        -- 更新UI显示
        infoLabel.Text = "自动交易运行中...\n模式: " .. modeNames[tradeMode] .. "\n蛋数量: " .. #eggData['背包']
        
        -- 尝试刷新蛋数据
        if #eggData['背包'] > 0 then
            pcall(function()
                remoteFetchServer:FireServer(eggData['背包'][1]['索引'])
            end)
        end
    end
end)()

infoLabel.Text = "自动交易已启动！\n模式: 丹药+翅膀+蛋\n蛋数量: " .. #eggData['背包']
print("自动交易系统已启动 - 蛋数量:", #eggData['背包'])
