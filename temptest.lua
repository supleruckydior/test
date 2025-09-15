-- =========================
-- 基础服务
-- =========================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local UserInputService = game:GetService("UserInputService")

-- =========================
-- 工具函数
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
local elixirSyncEvent = getRemote({
    "\228\186\139\228\187\182", -- 药水
    "\229\174\162\230\136\183\231\171\175",
    "\229\174\162\230\136\183\231\171\175\228\184\185\232\141\175",
    "\228\184\185\232\141\175\230\149\176\230\141\174\229\143\152\229\140\150"
})
local addTradeItemEvent = getRemote({
    "\228\186\139\228\187\182", -- 药水
    "\229\133\172\231\148\168", -- 功能
    "\228\186\164\230\152\147", -- 交易
    "\230\150\176\229\162\158\228\186\164\230\152\147\231\137\169\229\147\129" -- 新增交易物品
})
local requestTradeEvent = getRemote({
    "\228\186\139\228\187\182",
    "\229\133\172\231\148\168",
    "\228\186\164\230\152\147",
    "\231\148\179\232\175\183\228\186\164\230\152\147"
})
local confirmTradeEvent = getRemote({
    "\228\186\139\228\187\182",
    "\229\133\172\231\148\168",
    "\228\186\164\230\152\147",
    "\233\148\129\229\174\154\228\186\164\230\152\147"
})

-- 蛋数据 Remote
local remoteReceiveData = getRemote({
    "\228\186\139\228\187\182",
    "\229\133\172\231\148\168",
    "\229\174\160\231\137\169\232\155\139",
    "\229\144\140\230\173\165"
})

-- =========================
-- 数据存储
-- =========================
local elixirData = {}
local eggData = { ["背包"] = {}, ["孵化中"] = {} }

-- =========================
-- 初始化蛋数据 (getgc)
-- =========================
do
    local seenTables = {}
    for _, obj in ipairs(getgc(true)) do
        if type(obj) == "table" and rawget(obj, "孵化中") ~= nil then
            local address = tostring(obj)
            if not seenTables[address] then
                seenTables[address] = true
                eggData["背包"] = obj["背包"] or {}
                eggData["孵化中"] = obj["孵化中"] or {}
            end
        end
    end
end

-- =========================
-- RemoteEvent 同步数据
-- =========================
elixirSyncEvent.Event:Connect(function(data)
    elixirData = data
end)

remoteReceiveData.OnClientEvent:Connect(function(data)
    if type(data) == "table" then
        eggData["背包"] = type(data["背包"]) == "table" and data["背包"] or {}
        eggData["孵化中"] = type(data["孵化中"]) == "table" and data["孵化中"] or {}
    end
end)

-- =========================
-- 交易函数
-- =========================
local function tradeElixir(index)
    local ok, err = pcall(function()
        addTradeItemEvent:FireServer("\228\184\185\232\141\175", index, 999999)
    end)
    if ok then print("成功交易丹药:", index) else warn("丹药交易失败:", index, err) end
end

local function tradeArmor(index)
    local ok, err = pcall(function()
        addTradeItemEvent:FireServer("\232\163\133\229\164\135", index, 999999)
    end)
    if ok then print("成功交易翅膀:", index) else warn("翅膀交易失败:", index, err) end
end

local function tradeEgg(index)
    local ok, err = pcall(function()
        addTradeItemEvent:FireServer("\229\174\160\231\137\169\232\155\139", index)
    end)
    if ok then print("成功交易蛋:", index) else warn("蛋交易失败:", index, err) end
end

-- =========================
-- 系统变量
-- =========================
local running = true
local tradeMode = "both" -- elixir, armor, egg, both

-- =========================
-- UI
-- =========================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AutoTradeMonitor"
screenGui.Parent = PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 320, 0, 150)
mainFrame.Position = UDim2.new(0, 10, 1, -160)
mainFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
mainFrame.BorderColor3 = Color3.fromRGB(255, 0, 0)
mainFrame.BorderSizePixel = 2
mainFrame.Parent = screenGui

local titleBar = Instance.new("TextLabel")
titleBar.Size = UDim2.new(1, 0, 0, 20)
titleBar.Text = "自动交易系统 (丹药+翅膀+蛋)"
titleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
titleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(0.9, 0, 0.5, 0)
infoLabel.Position = UDim2.new(0.05, 0, 0.1, 20)
infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "自动交易启动中...\n模式: 全部"
infoLabel.Parent = mainFrame

local buttonContainer = Instance.new("Frame")
buttonContainer.Size = UDim2.new(0.9, 0, 0.25, 0)
buttonContainer.Position = UDim2.new(0.05, 0, 0.7, 0)
buttonContainer.BackgroundTransparency = 1
buttonContainer.Parent = mainFrame

local modeButton = Instance.new("TextButton")
modeButton.Size = UDim2.new(0.45, 0, 0.8, 0)
modeButton.Text = "切换模式"
modeButton.Parent = buttonContainer

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0.45, 0, 0.8, 0)
closeButton.Position = UDim2.new(0.55, 0, 0, 0)
closeButton.Text = "关闭系统"
closeButton.Parent = buttonContainer

-- 模式切换
modeButton.MouseButton1Click:Connect(function()
    if tradeMode == "both" then
        tradeMode = "elixir"
    elseif tradeMode == "elixir" then
        tradeMode = "armor"
    elseif tradeMode == "armor" then
        tradeMode = "egg"
    else
        tradeMode = "both"
    end
    infoLabel.Text = "自动交易运行中...\n模式: " ..
        (tradeMode == "both" and "全部" or
         tradeMode == "elixir" and "仅丹药" or
         tradeMode == "armor" and "仅翅膀" or
         "仅蛋")
end)

-- 关闭
closeButton.MouseButton1Click:Connect(function()
    running = false
    screenGui:Destroy()
end)

-- =========================
-- 主交易循环
-- =========================
coroutine.wrap(function()
    while running do
        -- 交易丹药
        if tradeMode == "elixir" or tradeMode == "both" then
            if elixirData and elixirData["背包"] then
                for _, item in pairs(elixirData["背包"]) do
                    local idx = item["索引"] or item.id
                    if idx then tradeElixir(idx) end
                end
            end
        end

        -- 交易翅膀
        if tradeMode == "armor" or tradeMode == "both" then
            -- 这里要接上翅膀数据的来源（略）
        end

        -- 交易蛋
        if tradeMode == "egg" or tradeMode == "both" then
            if eggData and eggData["背包"] then
                for _, item in pairs(eggData["背包"]) do
                    local idx = item["索引"] or item.id
                    if idx then tradeEgg(idx) end
                end
            end
        end

        wait(1.0) -- 冷却
    end
end)()

infoLabel.Text = "自动交易已启动！\n模式: 全部 V2.0"
