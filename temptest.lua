-- =========================
-- 基础服务
-- =========================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

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
    "\228\186\139\228\187\182",
    "\229\133\172\231\148\168",
    "\228\186\164\230\152\147",
    "\230\150\176\229\162\158\228\186\164\230\152\147\231\137\169\229\147\129"
})

-- 蛋数据 Remote
local remoteReceiveEgg = getRemote({
    "\228\186\139\228\187\182",
    "\229\133\172\231\148\168",
    "\229\174\160\231\137\169\232\155\139",
    "\229\144\140\230\173\165"
})

-- 翅膀数据 Remote
local remoteReceiveArmor = getRemote({
    "\228\186\139\228\187\182",
    "\229\133\172\231\148\168",
    "\232\163\133\229\164\135",
    "\229\144\140\230\173\165"
})

-- =========================
-- 数据存储
-- =========================
local elixirData = {}
local eggData   = { ["背包"] = {}, ["孵化中"] = {} }
local armorData = { ["背包"] = {} }

-- =========================
-- 初始化蛋/翅膀数据 (getgc)
-- =========================
do
    local seenTables = {}
    for _, obj in ipairs(getgc(true)) do
        if type(obj) == "table" then
            if rawget(obj, "孵化中") ~= nil then
                -- 蛋表
                local address = tostring(obj)
                if not seenTables[address] then
                    seenTables[address] = true
                    eggData["背包"] = obj["背包"] or {}
                    eggData["孵化中"] = obj["孵化中"] or {}
                end
            elseif rawget(obj, "翅膀") ~= nil or rawget(obj, "装备中") ~= nil then
                -- 翅膀表（可能字段不同，根据游戏情况调整）
                local address = tostring(obj)
                if not seenTables[address] then
                    seenTables[address] = true
                    armorData["背包"] = obj["背包"] or {}
                end
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

remoteReceiveEgg.OnClientEvent:Connect(function(data)
    if type(data) == "table" then
        eggData["背包"] = type(data["背包"]) == "table" and data["背包"] or {}
        eggData["孵化中"] = type(data["孵化中"]) == "table" and data["孵化中"] or {}
    end
end)

remoteReceiveArmor.OnClientEvent:Connect(function(data)
    if type(data) == "table" then
        armorData["背包"] = type(data["背包"]) == "table" and data["背包"] or {}
    end
end)

-- =========================
-- 交易函数
-- =========================
local function tradeElixir(index)
    local ok, err = pcall(function()
        addTradeItemEvent:FireServer("\228\184\185\232\141\175", index, 999999)
    end)
    if ok then print("✅ 成功交易丹药:", index) else warn("❌ 丹药交易失败:", index, err) end
end

local function tradeArmor(index)
    local ok, err = pcall(function()
        addTradeItemEvent:FireServer("\232\163\133\229\164\135", index, 999999)
    end)
    if ok then print("✅ 成功交易翅膀:", index) else warn("❌ 翅膀交易失败:", index, err) end
end

local function tradeEgg(index)
    local ok, err = pcall(function()
        addTradeItemEvent:FireServer("\229\174\160\231\137\169\232\155\139", index)
    end)
    if ok then print("✅ 成功交易蛋:", index) else warn("❌ 蛋交易失败:", index, err) end
end

-- =========================
-- 系统变量
-- =========================
local running   = true
local tradeMode = "both" -- elixir, armor, egg, both

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
            if armorData and armorData["背包"] then
                for _, item in pairs(armorData["背包"]) do
                    local idx = item["索引"] or item.id
                    if idx then tradeArmor(idx) end
                end
            end
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

        wait(1.0)
    end
end)()

print("✅ 自动交易系统已启动（丹药 + 翅膀 + 蛋，全功能，无白名单）")
