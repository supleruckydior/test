local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

-- 获取数据同步事件
local dataSyncEvent = ReplicatedStorage
    ["\228\186\139\228\187\182"]          -- 药水
    ["\229\174\162\230\136\183\231\171\175"] -- 同步模块
    ["\229\174\162\230\136\183\231\171\175\233\152\181\230\179\149"] -- 符石同步控制器
    ["\233\152\181\230\179\149\230\149\176\230\141\174\229\143\152\229\140\150"] -- 数据更新事件

-- 监听数据更新
dataSyncEvent.Event:Connect(function(data)
    local runesData = data["背包"]
    local runesToSell = {}

    for _, rune in ipairs(runesData) do
        local index = rune["索引"]
        local runeType = tonumber(rune["类型"]) or 0
        local attributes = rune["属性"]

        local goldCount, critCount, expCount = 0, 0, 0
        local attrMap = {}

        -- 统计属性
        for _, attr in ipairs(attributes) do
            local name = attr["名称"]
            attrMap[name] = (attrMap[name] or 0) + 1
            if name == "金币额外获取" then
                goldCount += 1
            elseif name == "暴击概率" then
                critCount += 1
            elseif name == "经验额外获取" then
                expCount += 1
            end
        end

        -- 检查是否有任意属性 ≥ 4
        local hasAnyOver4 = false
        for _, count in pairs(attrMap) do
            if count >= 4 then
                hasAnyOver4 = true
                break
            end
        end

        local shouldSell = false
        local reason = ""

        -- 类型 1 / 4
        if runeType == 1 or runeType == 4 then
            if not (
                goldCount >= 3 or expCount >= 3 or critCount >= 3 or hasAnyOver4
            ) then
                shouldSell = true
                reason = "类型" .. runeType .. "未满足暴击金币经验≥3或任意属性≥4"
            end

        -- 类型 2 / 3 / 5
        elseif runeType == 2 or runeType == 3 or runeType == 5 then
            if not (
                goldCount >= 3 or expCount >= 3 or hasAnyOver4
            ) then
                shouldSell = true
                reason = "类型" .. runeType .. "未满足金币经验≥3或任意属性≥4"
            end
        else
            -- 其他类型，默认出售
            shouldSell = true
            reason = "类型" .. runeType .. "不在保留范围"
        end

        if shouldSell then
            table.insert(runesToSell, {
                index = index,
                type = runeType,
                gold = goldCount,
                exp = expCount,
                crit = critCount,
                reason = reason
            })
        end
    end

    -- 执行出售操作
    for _, rune in ipairs(runesToSell) do
        local args = {[1] = {[rune.index] = true}}
        game:GetService("ReplicatedStorage")
            :FindFirstChild("\228\186\139\228\187\182")
            :FindFirstChild("\229\133\172\231\148\168")
            :FindFirstChild("\233\152\181\230\179\149")
            :FindFirstChild("\229\135\186\229\148\174")
            :FireServer(unpack(args))
    end

    print("出售完成，共处理 " .. #runesToSell .. " 个符石")
end)


print("符石自动出售脚本已加载 - 改进版规则")
