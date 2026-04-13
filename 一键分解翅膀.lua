-- 一键分解翅膀脚本
-- 功能：筛选品质为6、第三个属性数值低于阈值的翅膀并自动分解

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

-- 配置参数
local QUALITY_FILTER = 6  -- 品质限制：只处理品质为6的翅膀
local THRESHOLD = 1.4  -- 阈值：第三个属性数值低于此值的翅膀将被分解（可修改）

-- 获取分解事件
local decomposeEvent = ReplicatedStorage:WaitForChild("\228\186\139\228\187\182"):WaitForChild("\229\133\172\231\148\168"):WaitForChild("\232\163\133\229\164\135"):WaitForChild("\232\189\172\230\141\162\231\191\133\232\134\128")

-- 翅膀背包数据搜索函数
local function findArmorBackpackData()
    local bestMatch = nil
    local maxWings = 0
    
    for i, obj in ipairs(getgc(true)) do
        if type(obj) == 'table' then
            -- 检查是否是背包数据（包含"背包"键）
            local backpack = rawget(obj, '\232\131\140\229\140\133') or rawget(obj, '背包')
            if type(backpack) == 'table' then
                local wingCount = 0
                for _, item in pairs(backpack) do
                    if type(item) == 'table' and (rawget(item, '翅膀ID') or rawget(item, 'wingId')) then
                        wingCount = wingCount + 1
                    end
                end
                if wingCount > maxWings then
                    maxWings = wingCount
                    bestMatch = backpack
                end
            else
                -- 如果没有"背包"键，检查是否直接包含翅膀数据
                local wingCount = 0
                for k, v in pairs(obj) do
                    if type(v) == 'table' and (rawget(v, '翅膀ID') or rawget(v, 'wingId')) then
                        wingCount = wingCount + 1
                    end
                end
                if wingCount > maxWings then
                    maxWings = wingCount
                    bestMatch = obj
                end
            end
        end
    end
    
    return bestMatch or {}
end

-- 获取当前装备数据
local armorData = {}

-- 尝试连接翅膀数据同步事件
local armorSyncEvent = nil
local armorSyncSuccess, armorSyncResult = pcall(function()
    return ReplicatedStorage["\228\186\139\228\187\182"]["\229\174\162\230\136\183\231\171\175"]["\229\174\162\230\136\183\231\171\175\232\163\133\229\164\135"]["\232\163\133\229\164\135\230\149\176\230\141\174\229\143\152\229\140\150"]
end)
if armorSyncSuccess then
    armorSyncEvent = armorSyncResult
    print('✓ 已连接翅膀数据同步事件')
    
    -- 监听数据更新
    armorSyncEvent.Event:Connect(function(data)
        armorData = data
        print('✓ 翅膀数据已同步更新')
    end)
end

-- 获取切换装备组事件（用于触发服务器下发装备数据）
local switchArmorSetEvent = nil
local switchArmorSetSuccess, switchArmorSetResult = pcall(function()
    return ReplicatedStorage["\228\186\139\228\187\182"]["\229\133\172\231\148\168"]["\232\163\133\229\164\135"]["\229\136\135\230\141\162\232\163\133\229\164\135\231\187\132"]
end)
if switchArmorSetSuccess then
    switchArmorSetEvent = switchArmorSetResult
    print('✓ 已找到切换装备组事件')
    
    -- 触发事件以获取数据
    pcall(function()
        switchArmorSetEvent:FireServer(1)
        print('✓ 已触发切换装备组事件，请求翅膀数据')
    end)
end

-- 如果同步事件不存在，从内存读取
if not armorSyncEvent then
    print('⚠ 未找到同步事件，从内存读取翅膀数据...')
    armorData = findArmorBackpackData()
end

-- 等待一下让数据加载
task.wait(1)

-- 再次尝试从内存读取（如果同步事件数据为空）
if not armorData or (type(armorData) == 'table' and next(armorData) == nil) then
    print('⚠ 同步数据为空，从内存重新读取...')
    armorData = findArmorBackpackData()
end

-- 分解翅膀的函数
local function decomposeWing(itemId)
    local success, err = pcall(function()
        local args = {
            tostring(itemId),  -- 物品识别ID（UUID）
            false  -- 是否确认（false表示直接分解）
        }
        decomposeEvent:FireServer(unpack(args))
    end)
    
    if success then
        return true
    else
        warn('分解失败，物品ID:', itemId, '错误:', err)
        return false
    end
end

-- 筛选并分解符合条件的翅膀
local function filterAndDecomposeWings()
    local wingsToProcess = armorData
    
    -- 处理数据结构：如果包含"背包"键，使用背包数据
    if armorData and type(armorData) == 'table' then
        if armorData['\232\131\140\229\140\133'] or armorData['背包'] then
            wingsToProcess = armorData['\232\131\140\229\140\133'] or armorData['背包']
        end
    end
    
    if not wingsToProcess or (type(wingsToProcess) == 'table' and next(wingsToProcess) == nil) then
        print('❌ 错误：未找到翅膀数据')
        return
    end
    
    print('=' .. string.rep('=', 60))
    print('开始筛选翅膀...')
    print(string.format('品质限制：品质 = %d', QUALITY_FILTER))
    print(string.format('属性限制：第三个属性数值 < %s', THRESHOLD))
    print('=' .. string.rep('=', 60))
    
    local totalWings = 0
    local quality6Wings = 0
    local toDecomposeWings = {}
    local processedCount = 0
    
    -- 第一遍：筛选符合条件的翅膀
    for _, item in pairs(wingsToProcess) do
        processedCount = processedCount + 1
        
        if type(item) == 'table' then
            -- 检查是否是翅膀
            local isWing = item['翅膀ID'] 
                or (type(item.wingId) == 'number' and item.wingId > 0)
                or item.wingId
            
            if isWing then
                totalWings = totalWings + 1
                
                -- 检查品质是否为6
                local quality = tonumber(item['品质']) or 0
                if quality == QUALITY_FILTER then
                    quality6Wings = quality6Wings + 1
                    
                    -- 获取物品ID（实例ID，UUID格式）
                    local itemId = item['索引'] 
                        or item.Index
                        or item['id']
                        or item.id
                        or item['ref']
                        or item.ref
                    
                    -- 获取第三个属性数值
                    local thirdAttrValue = nil
                    local thirdAttrName = '无'
                    
                    if item['属性'] and type(item['属性']) == 'table' then
                        if #item['属性'] >= 3 then
                            local thirdAttr = item['属性'][3]
                            if thirdAttr and type(thirdAttr) == 'table' then
                                -- 获取属性名称
                                thirdAttrName = thirdAttr['名称'] 
                                    or thirdAttr.name 
                                    or '未知属性'
                                
                                -- 获取属性数值（系数）
                                local value = thirdAttr['系数'] 
                                    or thirdAttr.coefficient
                                    or thirdAttr['数值']
                                    or thirdAttr.value
                                    or thirdAttr['值']
                                
                                if value ~= nil then
                                    thirdAttrValue = tonumber(value)
                                end
                            end
                        end
                    end
                    
                    -- 判断是否需要分解（品质已通过检查，只需检查属性数值）
                    if itemId and thirdAttrValue ~= nil then
                        if thirdAttrValue < THRESHOLD then
                            local wingTypeId = item['翅膀ID'] or item.wingId or '无'
                            table.insert(toDecomposeWings, {
                                itemId = itemId,
                                wingTypeId = wingTypeId,
                                quality = quality,
                                attrName = thirdAttrName,
                                attrValue = thirdAttrValue
                            })
                        end
                    end
                end
            end
        end
    end
    
    print(string.format('筛选完成！'))
    print(string.format('  总翅膀数: %d', totalWings))
    print(string.format('  品质6的翅膀: %d', quality6Wings))
    print(string.format('  需要分解的翅膀: %d', #toDecomposeWings))
    
    if #toDecomposeWings == 0 then
        print('✓ 没有需要分解的翅膀')
        return
    end
    
    -- 显示待分解列表
    print('=' .. string.rep('=', 60))
    print('待分解翅膀列表：')
    for i, wing in ipairs(toDecomposeWings) do
        print(string.format('  %d. 物品ID=%s (类别ID=%s, 品质=%d), 第三个属性=%s, 数值=%.3f', 
            i, 
            tostring(wing.itemId),
            tostring(wing.wingTypeId),
            wing.quality,
            tostring(wing.attrName),
            wing.attrValue
        ))
    end
    print('=' .. string.rep('=', 60))
    
    -- 第二遍：执行分解操作
    print(string.format('开始分解 %d 个翅膀...', #toDecomposeWings))
    
    local successCount = 0
    local failCount = 0
    
    for i, wing in ipairs(toDecomposeWings) do
        print(string.format('[%d/%d] 正在分解 物品ID=%s (品质=%d, 数值=%.3f)...', 
            i, #toDecomposeWings, tostring(wing.itemId), wing.quality, wing.attrValue))
        
        if decomposeWing(wing.itemId) then
            successCount = successCount + 1
            print('  ✓ 分解成功')
        else
            failCount = failCount + 1
            print('  ✗ 分解失败')
        end
        
        -- 短暂延迟以避免请求过快
        if i < #toDecomposeWings then
            task.wait(0.1)
        end
    end
    
    print('=' .. string.rep('=', 60))
    print(string.format('分解完成！成功: %d, 失败: %d', successCount, failCount))
    print('=' .. string.rep('=', 60))
end

-- 延迟执行（等待数据加载）
task.spawn(function()
    task.wait(2) -- 等待2秒确保数据加载完成
    filterAndDecomposeWings()
end)

print('=' .. string.rep('=', 60))
print('一键分解翅膀脚本已启动')
print(string.format('品质限制：品质 = %d', QUALITY_FILTER))
print(string.format('属性阈值：第三个属性数值 < %s', THRESHOLD))
print('正在等待数据加载...')
print('=' .. string.rep('=', 60))

