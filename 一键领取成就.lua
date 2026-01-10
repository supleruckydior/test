-- 组合执行脚本
-- 功能：将1-50和01-15组合，每个组合执行一次FireServer

local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- 配置参数
local PART1_START = 1   -- 第一部分起始值
local PART1_END = 50    -- 第一部分结束值
local PART2_START = 1   -- 第二部分起始值
local PART2_END = 35    -- 第二部分结束值
local DELAY_BETWEEN_CALLS = 0  -- 每次调用之间的延迟（秒）

-- 获取事件
local targetEvent = ReplicatedStorage:WaitForChild("\228\186\139\228\187\182"):WaitForChild("\229\133\172\231\148\168"):WaitForChild("\230\136\144\229\176\177"):WaitForChild("\233\162\134\229\143\150")

-- 执行单个调用
local function executeCall(arg)
    local success, err = pcall(function()
        local args = {arg}
        targetEvent:FireServer(unpack(args))
    end)
    
    if not success then
        warn('执行失败，参数:', arg, '错误:', err)
        return false
    end
    return true
end

-- 格式化第二部分（01-15格式）
local function formatPart2(num)
    if num < 10 then
        return "0" .. tostring(num)
    else
        return tostring(num)
    end
end

-- 主执行函数
local function runCombinations()
    print('=' .. string.rep('=', 60))
    print('开始执行组合调用...')
    print(string.format('第一部分: %d-%d', PART1_START, PART1_END))
    print(string.format('第二部分: %02d-%02d', PART2_START, PART2_END))
    print(string.format('总组合数: %d', (PART1_END - PART1_START + 1) * (PART2_END - PART2_START + 1)))
    print('=' .. string.rep('=', 60))
    
    local totalCount = 0
    local successCount = 0
    local failCount = 0
    
    -- 遍历所有组合
    for part1 = PART1_START, PART1_END do
        for part2 = PART2_START, PART2_END do
            totalCount = totalCount + 1
            
            -- 组合参数（纯数字拼接，例如：2501 = 25 + 01）
            local part2Formatted = formatPart2(part2)
            local combinedArg = tostring(part1) .. part2Formatted
            
            print(string.format('[%d/%d] 执行参数: %s (组合: %d + %s)', 
                totalCount, 
                (PART1_END - PART1_START + 1) * (PART2_END - PART2_START + 1),
                combinedArg,
                part1,
                part2Formatted
            ))
            
            if executeCall(combinedArg) then
                successCount = successCount + 1
            else
                failCount = failCount + 1
            end
            
            -- 延迟
            if totalCount < (PART1_END - PART1_START + 1) * (PART2_END - PART2_START + 1) then
            end
        end
    end
    
    print('=' .. string.rep('=', 60))
    print('执行完成！')
    print(string.format('总计: %d, 成功: %d, 失败: %d', totalCount, successCount, failCount))
    print('=' .. string.rep('=', 60))
end

-- 执行
runCombinations()

