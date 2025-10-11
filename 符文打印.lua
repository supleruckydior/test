local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 获取数据同步事件
local dataSyncEvent = ReplicatedStorage
    ["\228\186\139\228\187\182"]          -- 药水
    ["\229\174\162\230\136\183\231\171\175"] -- 同步模块
    ["\229\174\162\230\136\183\231\171\175\233\152\181\230\179\149"] -- 符石同步控制器
    ["\233\152\181\230\179\149\230\149\176\230\141\174\229\143\152\229\140\150"] -- 数据更新事件

-- 当符石数据更新时执行
dataSyncEvent.Event:Connect(function(data)
    local runesData = data["背包"]
    print("===== 符石词条数量统计开始 =====")

    for _, rune in ipairs(runesData) do
        local index = rune["索引"]
        local runeType = tonumber(rune["类型"]) or 0
        local attributes = rune["属性"]

        -- 统计每种属性出现次数
        local attrCount = {}
        for _, attr in ipairs(attributes) do
            local name = attr["名称"]
            attrCount[name] = (attrCount[name] or 0) + 1
        end

        -- 转成可排序表
        local attrList = {}
        for name, count in pairs(attrCount) do
            table.insert(attrList, {name = name, count = count})
        end

        -- 按数量降序排序
        table.sort(attrList, function(a, b)
            return a.count > b.count
        end)

        -- 取前两名
        local top1 = attrList[1]
        local top2 = attrList[2]

        -- 防止空值
        local top1Name, top1Count = top1 and top1.name or "无", top1 and top1.count or 0
        local top2Name, top2Count = top2 and top2.name or "无", top2 and top2.count or 0

        print(string.format(
            "符石索引: %s | 类型: %d | 第一: %s(%d) | 第二: %s(%d)",
            tostring(index),
            runeType,
            top1Name, top1Count,
            top2Name, top2Count
        ))
    end

    print("===== 符石词条数量统计结束 =====")
end)


print("符石词条统计脚本（带类型）已加载 ✅")
