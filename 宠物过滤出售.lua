local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- 资质等级系数表
local AptitudeMultiplier = {
    E = 1.0481135419,
    D = 1.15504566,
    C = 1.2728873575,
    B = 1.4027516668,
    A = 1.5458651759,
    ["A+"] = 1.7035796133,
    S = 1.8773846154,
    X = 2.0689217966,
}

local Base = 0.65

-- 获取中心系数（无随机）
local function get_center_coef(grade)
    return Base * (AptitudeMultiplier[grade] or 1)
end

-- 根据系数判断等级
local function get_grade_from_coef(coef)
    local normalized = coef / Base
    
    if normalized >= AptitudeMultiplier.X then return "X" end
    if normalized >= AptitudeMultiplier.S then return "S" end
    if normalized >= AptitudeMultiplier["A+"] then return "A+" end
    if normalized >= AptitudeMultiplier.A then return "A" end
    if normalized >= AptitudeMultiplier.B then return "B" end
    if normalized >= AptitudeMultiplier.C then return "C" end
    if normalized >= AptitudeMultiplier.D then return "D" end
    return "E"
end

-- 判断是否需要出售（新规则：保留双A或以上或单S或以上，其余出售）
local function should_sell_pet(petData)
    if not petData or not petData["最大资质系数"] then
        return false
    end
    
    local coef1 = petData["最大资质系数"][1] or 0
    local coef2 = petData["最大资质系数"][2] or 0
    
    -- 获取两个系数的等级
    local grade1 = get_grade_from_coef(coef1)
    local grade2 = get_grade_from_coef(coef2)
    
    -- 等级权重（用于比较）
    local gradeWeight = {
        E = 1, D = 2, C = 3, B = 4, A = 5, ["A+"] = 6, S = 7, X = 8
    }
    
    local weight1 = gradeWeight[grade1] or 0
    local weight2 = gradeWeight[grade2] or 0
    
    -- 保留条件：双A或以上，或者任意一个S或以上
    local keep = (weight1 >= 6 and weight2 >= 6) or (weight1 >= 7 or weight2 >= 7)
    
    -- 出售就是保留的反面
    local sell = not keep
    
    print(string.format("宠物 %s: 系数1=%.4f(%s), 系数2=%.4f(%s), 出售=%s", 
        petData["索引"] or "未知", coef1, grade1, coef2, grade2, 
        tostring(sell)))
    
    return sell
end

-- 出售宠物函数
local function sell_pet(petIndex)
    local args = {
        {
            [petIndex] = true
        }
    }
    
    local success, result = pcall(function()
        local remote = ReplicatedStorage:WaitForChild("\228\186\139\228\187\182"):WaitForChild("\229\133\172\231\148\168"):WaitForChild("\229\174\160\231\137\169"):WaitForChild("\229\135\186\229\148\174"):FireServer(unpack(args))
        remote:FireServer(unpack(args))
    end)
    
    if success then
        print("✅ 成功出售宠物:", petIndex)
    else
        print("❌ 出售失败:", petIndex, "错误:", result)
    end
end

-- 监听RemoteEvent
local remoteReceiveData = ReplicatedStorage["\228\186\139\228\187\182"]["\229\133\172\231\148\168"]["\229\174\160\231\137\169"]["\229\144\140\230\173\165"]

remoteReceiveData.OnClientEvent:Connect(function(data)
    print("=== 收到宠物数据更新 ===")
    
    if type(data) == "table" and type(data["背包"]) == "table" then
        local backpack = data["背包"]
        local soldCount = 0
        
        for index, pet in pairs(backpack) do
            if should_sell_pet(pet) then
                local petIndex = pet["索引"]
                if petIndex then
                    print("🚫 符合出售条件:", petIndex)
                    sell_pet(petIndex)
                    soldCount = soldCount + 1
                end
            end
        end
        
        if soldCount > 0 then
            print(string.format("🎯 本次共出售 %d 只宠物", soldCount))
        else
            print("✅ 没有需要出售的宠物")
        end
    end
end)

-- 测试函数
local function test_grade_system()
    print("=== 资质等级系统测试 ===")
    
    local testCases = {
        {coef = 0.6, expected = "E"},
        {coef = 0.75, expected = "D"}, 
        {coef = 0.85, expected = "C"},
        {coef = 0.95, expected = "B"},
        {coef = 1.05, expected = "A"},
        {coef = 1.15, expected = "A+"},
        {coef = 1.25, expected = "S"},
        {coef = 1.35, expected = "X"},
    }
    
    for _, test in ipairs(testCases) do
        local grade = get_grade_from_coef(test.coef)
        print(string.format("系数 %.3f -> 等级 %s (预期: %s)", test.coef, grade, test.expected))
    end
end

-- 初始化
print("🐾 宠物自动出售系统已启动")
print("📋 出售规则: 保留双A或以上或单S或以上，其余出售")
test_grade_system()

-- 手动触发检查（可选）
local function manual_check()
    print("\n🔍 手动触发宠物检查...")
    -- 这里可以模拟接收数据来触发检查
end
