local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 获取数据同步事件
local dataSyncEvent = ReplicatedStorage
    ["\228\186\139\228\187\182"]          -- 药水
    ["\229\174\162\230\136\183\231\171\175"] -- 同步模块
    ["\229\174\162\230\136\183\231\171\175\233\152\181\230\179\149"] -- 符石同步控制器
    ["\233\152\181\230\179\149\230\149\176\230\141\174\229\143\152\229\140\150"] -- 数据更新事件

-- 当数据更新时执行
dataSyncEvent.Event:Connect(function(data)
    local runesData = data["背包"]
    print("===== 符石属性统计开始 =====")

    for _, rune in ipairs(runesData) do
        local index = rune["索引"]
        local attributes = rune["属性"]

        local attrStats = {}

        -- 统计每种属性的数量和总值
        for _, attr in ipairs(attributes) do
            local name = attr["名称"]
            local value = tonumber(attr["值"]) or 0

            if not attrStats[name] then
                attrStats[name] = {count = 0, totalValue = 0}
            end
            attrStats[name].count += 1
            attrStats[name].totalValue += value
        end

        -- 转成可排序表
        local attrList = {}
        for name, info in pairs(attrStats) do
            table.insert(attrList, {
                name = name,
                count = info.count,
                totalValue = info.totalValue
            })
        end

        -- 按总值降序排序
        table.sort(attrList, function(a, b)
            return a.totalValue > b.totalValue
        end)

        local top1 = attrList[1]
        local top2 = attrList[2]

        -- 防止空值
        local top1Name, top1Count, top1Val = top1 and top1.name or "无", top1 and top1.count or 0, top1 and top1.totalValue or 0
        local top2Name, top2Count, top2Val = top2 and top2.name or "无", top2 and top2.count or 0, top2 and top2.totalValue or 0

        print(string.format(
            "符石索引: %s | 第一: %s(%d)总值%.2f | 第二: %s(%d)总值%.2f",
            tostring(index),
            top1Name, top1Count, top1Val,
            top2Name, top2Count, top2Val
        ))
    end

    print("===== 符石属性统计结束 =====")
end)


