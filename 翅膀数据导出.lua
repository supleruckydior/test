-- 翅膀数据导出脚本
-- 功能：读取翅膀装备数据，提取第三个属性的名称和数值，写入TSV文件

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')

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

-- 提取翅膀数据并导出到TSV
local function exportWingsToTSV()
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
    print('开始导出翅膀数据...')
    
    -- 准备TSV数据
    local tsvLines = {}
    -- TSV表头（物品ID是实例ID，不是类别ID）
    table.insert(tsvLines, '物品ID\t第三个属性名称\t第三个属性数值')
    
    local wingCount = 0
    local processedCount = 0
    
    -- 遍历所有物品
    for _, item in pairs(wingsToProcess) do
        processedCount = processedCount + 1
        
        if type(item) == 'table' then
            -- 检查是否是翅膀
            local isWing = item['翅膀ID'] 
                or (type(item.wingId) == 'number' and item.wingId > 0)
                or item.wingId
            
            if isWing then
                -- 获取物品ID（实例ID，不是类别ID）
                -- 优先使用索引/id/ref等唯一标识符，而不是翅膀ID（类别ID）
                local equipId = item['索引'] 
                    or item.Index
                    or item['id']
                    or item.id
                    or item['ref']
                    or item.ref
                    or '未知'
                
                -- 获取第三个属性
                local thirdAttrName = '无'
                local thirdAttrValue = '无'
                
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
                                -- 如果是数字，转换为字符串并保留合理精度
                                if type(value) == 'number' then
                                    thirdAttrValue = tostring(value)
                                else
                                    thirdAttrValue = tostring(value)
                                end
                            else
                                thirdAttrValue = '无'
                            end
                        end
                    end
                end
                
                -- 清理TSV特殊字符（将制表符和换行符替换为空格）
                local cleanEquipId = string.gsub(tostring(equipId), '[\t\n\r]', ' ')
                local cleanAttrName = string.gsub(tostring(thirdAttrName), '[\t\n\r]', ' ')
                local cleanAttrValue = string.gsub(tostring(thirdAttrValue), '[\t\n\r]', ' ')
                
                -- 添加到TSV数据（使用制表符分隔）
                local line = cleanEquipId .. '\t' .. cleanAttrName .. '\t' .. cleanAttrValue
                table.insert(tsvLines, line)
                
                wingCount = wingCount + 1
                
                -- 打印到控制台（显示物品ID和类别ID）
                local wingTypeId = item['翅膀ID'] or item.wingId or '无'
                print(string.format('翅膀 %d: 物品ID=%s (类别ID=%s), 第三个属性=%s, 数值=%s', 
                    wingCount, 
                    tostring(equipId),
                    tostring(wingTypeId),
                    tostring(thirdAttrName),
                    tostring(thirdAttrValue)
                ))
            end
        end
    end
    
    print('=' .. string.rep('=', 60))
    print(string.format('处理完成！共找到 %d 个翅膀，已导出 %d 个', processedCount, wingCount))
    
    if wingCount == 0 then
        print('⚠ 警告：未找到任何翅膀装备')
        return
    end
    
    -- 写入TSV文件
    local tsvContent = table.concat(tsvLines, '\n')
    local fileName = 'wings_export_' .. os.time() .. '.tsv'
    
    -- 尝试使用writefile函数（如果有）
    if writefile then
        writefile(fileName, tsvContent)
        print('✓ TSV文件已保存: ' .. fileName)
    else
        -- 如果没有writefile，尝试其他方法或直接输出
        print('=' .. string.rep('=', 60))
        print('TSV文件内容（请手动保存）:')
        print('=' .. string.rep('=', 60))
        print(tsvContent)
        print('=' .. string.rep('=', 60))
        print('如果需要在文件中保存，请使用支持writefile的执行器')
    end
end

-- 延迟执行导出（等待数据加载）
task.spawn(function()
    task.wait(2) -- 等待2秒确保数据加载完成
    exportWingsToTSV()
end)

print('=' .. string.rep('=', 60))
print('翅膀数据导出脚本已启动')
print('正在等待数据加载...')
print('=' .. string.rep('=', 60))
