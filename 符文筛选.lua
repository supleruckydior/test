local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 缓存服务路径，避免重复查找
local function getSellEvent()
    local potionModule = ReplicatedStorage:FindFirstChild("\228\186\139\228\187\182")
    if not potionModule then return nil end
    
    local commonModule = potionModule:FindFirstChild("\229\133\172\231\148\168")
    if not commonModule then return nil end
    
    local runeModule = commonModule:FindFirstChild("\233\152\181\230\179\149")
    if not runeModule then return nil end
    
    return runeModule:FindFirstChild("\229\135\186\229\148\174")
end

-- 获取数据同步事件
local dataSyncEvent = ReplicatedStorage
    ["\228\186\139\228\187\182"]          -- 药水
    ["\229\174\162\230\136\183\231\171\175"] -- 同步模块
    ["\229\174\162\230\136\183\231\171\175\233\152\181\230\179\149"] -- 符石同步控制器
    ["\233\152\181\230\179\149\230\149\176\230\141\174\229\143\152\229\140\150"] -- 数据更新事件

-- 缓存出售事件，避免重复查找
local sellEvent = getSellEvent()
if not sellEvent then
    warn("未找到符石出售事件，脚本可能无法正常工作")
end

-- 类型集合定义
local TYPE_14 = {[1] = true, [4] = true}  -- 需要检查暴击的类型
local TYPE_235 = {[2] = true, [3] = true, [5] = true}  -- 不需要检查暴击的类型

-- 判断符石是否需要出售
local function shouldSellRune(runeType, attrMap)
    local goldCount = attrMap["金币额外获取"] or 0
    local expCount = attrMap["经验额外获取"] or 0
    local critCount = attrMap["暴击概率"] or 0
    
    -- 检查是否有任意属性 ≥ 4
    local hasAnyOver4 = false
    for _, count in pairs(attrMap) do
        if count >= 4 then
            hasAnyOver4 = true
            break
        end
    end
    
    -- 类型 1 / 4：需要暴击、金币≥3或经验≥4，或任意属性≥4
    if TYPE_14[runeType] then
        if goldCount >= 3 or expCount >= 4 or critCount >= 3 or hasAnyOver4 then
            return false, nil  -- 保留
        end
        return true, "类型" .. runeType .. "未满足暴击金币≥3或经验≥4或任意属性≥4"
    end
    
    -- 类型 2 / 3 / 5：需要金币≥3或经验≥4，或任意属性≥4
    if TYPE_235[runeType] then
        if goldCount >= 3 or expCount >= 4 or hasAnyOver4 then
            return false, nil  -- 保留
        end
        return true, "类型" .. runeType .. "未满足金币≥3或经验≥4或任意属性≥4"
    end
    
    -- 其他类型，默认出售
    return true, "类型" .. runeType .. "不在保留范围"
end

-- 统计符石属性
local function countAttributes(attributes)
    local attrMap = {}
    for _, attr in ipairs(attributes) do
        local name = attr["名称"]
        attrMap[name] = (attrMap[name] or 0) + 1
    end
    return attrMap
end

-- 监听数据更新
dataSyncEvent.Event:Connect(function(data)
    -- 数据验证
    if not data or not data["背包"] then
        warn("数据格式错误，跳过本次处理")
        return
    end
    
    if not sellEvent then
        sellEvent = getSellEvent()  -- 尝试重新获取
        if not sellEvent then
            warn("符石出售事件未找到，跳过本次处理")
            return
        end
    end
    
    local runesData = data["背包"]
    local runesToSell = {}

    for _, rune in ipairs(runesData) do
        -- 数据验证
        if rune and rune["索引"] and rune["属性"] then
            local index = rune["索引"]
            local runeType = tonumber(rune["类型"]) or 0
            local attributes = rune["属性"]

            -- 统计属性（一次遍历完成）
            local attrMap = countAttributes(attributes)
            
            -- 判断是否需要出售
            local shouldSell, reason = shouldSellRune(runeType, attrMap)
            
            if shouldSell then
                table.insert(runesToSell, {
                    index = index,
                    type = runeType,
                    gold = attrMap["金币额外获取"] or 0,
                    exp = attrMap["经验额外获取"] or 0,
                    crit = attrMap["暴击概率"] or 0,
                    reason = reason
                })
            end
        else
            warn("符石数据格式错误，跳过")
        end
    end

    -- 执行出售操作
    if #runesToSell > 0 then
        local successCount = 0
        for _, rune in ipairs(runesToSell) do
            local success, err = pcall(function()
                sellEvent:FireServer({[rune.index] = true})
            end)
            
            if success then
                successCount = successCount + 1
            else
                warn("出售符石失败 (索引: " .. rune.index .. "): " .. tostring(err))
            end
        end
        
        print("出售完成，共处理 " .. successCount .. "/" .. #runesToSell .. " 个符石")
    else
        print("没有需要出售的符石")
    end
end)


print("符石自动出售脚本已加载 - 改进版规则（已优化）")
