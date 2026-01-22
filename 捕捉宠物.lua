-- 捕捉宠物脚本 - 自动回血功能
-- 功能：监听装备宠物血量，当2个死亡时自动TP到回血点，等全部回满后TP回去

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

-- 等待并加载 PathTool 系统
local PathTool, MgrPetClient, LogicNumber, GamePlayer

local function WaitForPathTool(maxWait)
    maxWait = maxWait or 30
    local waited = 0
    
    -- 方式1: 尝试直接 require PathTool
    if not PathTool then
        local success, result = pcall(function()
            PathTool = require(ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("PathTool"))
        end)
        if success then
            _G.PathTool = PathTool
        end
    end
    
    -- 方式2: 如果方式1失败，尝试使用全局变量
    if not PathTool and _G.PathTool then
        PathTool = _G.PathTool
    end
    
    -- 等待 PathTool 加载
    while not PathTool do
        wait(0.1)
        waited = waited + 0.1
        if waited >= maxWait then
            error("PathTool 系统未找到，请确保游戏已加载")
        end
        if not PathTool then
            local success, result = pcall(function()
                PathTool = require(ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("PathTool"))
            end)
            if success then
                _G.PathTool = PathTool
            end
        end
    end
    
    -- 加载 MgrPetClient 模块
    if not MgrPetClient then
        local success, result = pcall(function()
            if PathTool.Require then
                MgrPetClient = PathTool.Require("MgrPetClient")
            end
        end)
        
        if not MgrPetClient then
            local success2, result2 = pcall(function()
                MgrPetClient = require(ReplicatedStorage:WaitForChild("ClientLogic"):WaitForChild("Pet"):WaitForChild("MgrPetClient"))
            end)
            if success2 then
                MgrPetClient = result2
            end
        end
    end
    
    -- 加载 LogicNumber 模块
    if not LogicNumber then
        local success, result = pcall(function()
            if PathTool.Require then
                LogicNumber = PathTool.Require("LogicNumber")
            end
        end)
    end
    
    -- 等待 MgrPetClient 加载完成
    waited = 0
    while not MgrPetClient do
        wait(0.1)
        waited = waited + 0.1
        if waited >= maxWait then
            error("MgrPetClient 模块未找到或加载失败")
        end
        if not MgrPetClient then
            local success, result = pcall(function()
                if PathTool.Require then
                    MgrPetClient = PathTool.Require("MgrPetClient")
                end
            end)
            if not MgrPetClient then
                local success2, result2 = pcall(function()
                    MgrPetClient = require(ReplicatedStorage:WaitForChild("ClientLogic"):WaitForChild("Pet"):WaitForChild("MgrPetClient"))
                end)
                if success2 then
                    MgrPetClient = result2
                end
            end
        end
    end
    
    -- 等待 GamePlayer
    waited = 0
    while not GamePlayer do
        local success, result = pcall(function()
            return PathTool.ClientPlayerManager.GetGamePlayer()
        end)
        if success and result then
            GamePlayer = result
            break
        end
        wait(0.5)
        waited = waited + 0.5
        if waited >= maxWait then
            warn("GamePlayer 未就绪，可能影响自动战斗状态检测")
            break
        end
    end
    
    return true
end

-- 扩大自动捕捉范围的倍数（可以根据需要调整）
local AUTO_CATCH_RANGE_MULTIPLIER = 10  -- 默认3倍，可以改成 5、10 等更大的值

-- 扩大自动捕捉范围
local function ExpandAutoCatchRange()
    if PathTool and PathTool.CfgAutoAttack then
        local originalRange = PathTool.CfgAutoAttack.SearchRange
        -- 将范围扩大为原来的指定倍数
        PathTool.CfgAutoAttack.SearchRange = originalRange * AUTO_CATCH_RANGE_MULTIPLIER
        print(string.format("[自动捕捉] ✓ 捕捉范围已扩大: %d -> %d (倍数: %.1fx)", 
            originalRange, PathTool.CfgAutoAttack.SearchRange, AUTO_CATCH_RANGE_MULTIPLIER))
    else
        warn("[自动捕捉] ⚠ 无法找到 CfgAutoAttack，无法扩大捕捉范围")
    end
end

-- 通过装备槽位追踪宠物（槽位索引 -> 宠物ID）
-- 格式: equippedSlots[slotIndex] = {petItemId = "xxx", lastSeenTime = tick()}
local equippedSlots = {}

-- 更新装备槽位信息
local function UpdateEquippedSlots()
    if not MgrPetClient then
        return
    end
    
    -- 记录当前所有有装备的槽位
    local currentSlots = {}
    
    local success, err = pcall(function()
        MgrPetClient.IterPet(function(petInfo)
            if petInfo and petInfo.EquipedIndex ~= nil and petInfo.PetItemId then
                local slotIndex = petInfo.EquipedIndex
                currentSlots[slotIndex] = true
                
                -- 记录或更新该槽位的宠物信息
                if not equippedSlots[slotIndex] then
                    equippedSlots[slotIndex] = {}
                end
                equippedSlots[slotIndex].petItemId = petInfo.PetItemId
                equippedSlots[slotIndex].lastSeenTime = tick()
                equippedSlots[slotIndex].petInfo = petInfo  -- 保存引用以便检查状态
            end
            return true
        end)
    end)
    
    -- 检查是否有槽位被清空（之前有装备，现在没有了）
    for slotIndex, slotData in pairs(equippedSlots) do
        if not currentSlots[slotIndex] and slotData.petInfo then
            -- 槽位被清空，但之前有宠物，标记为死亡移除
            slotData.petInfo = nil
            slotData.removedTime = tick()
            print(string.format("[自动回血] 检测到槽位 %d 的宠物被移除（可能已死亡）", slotIndex))
        end
    end
    
    if not success then
        warn("更新装备槽位时出错: " .. tostring(err))
    end
end

-- 获取装备的宠物信息（包括死亡的）
local function GetEquippedPets()
    local pets = {}
    
    if not MgrPetClient then
        return pets
    end
    
    -- 先更新装备列表
    UpdateEquippedSlots()
    
    -- 遍历所有记录的槽位
    for slotIndex, slotData in pairs(equippedSlots) do
        if slotData.petInfo then
            -- 如果宠物对象还存在，添加到列表
            table.insert(pets, slotData.petInfo)
        else
            -- 如果宠物对象不存在，尝试通过PetItemId查找
            local found = false
            pcall(function()
                MgrPetClient.IterPet(function(petInfo)
                    if petInfo and petInfo.PetItemId == slotData.petItemId then
                        slotData.petInfo = petInfo
                        table.insert(pets, petInfo)
                        found = true
                        return false  -- 找到后停止
                    end
                    return true
                end)
            end)
            
            -- 如果找不到，说明宠物死亡后被移除了，但仍然记录在槽位中
            if not found then
                -- 创建一个虚拟的死亡标记
                table.insert(pets, {
                    PetItemId = slotData.petItemId,
                    EquipedIndex = slotIndex,
                    _isDeadAndRemoved = true
                })
            end
        end
    end
    
    return pets
end

-- 获取装备槽位总数（包括已移除的）
local function GetEquippedSlotCount()
    local count = 0
    for _ in pairs(equippedSlots) do
        count = count + 1
    end
    return count
end

-- 检查宠物是否死亡
local function IsPetDead(petInfo)
    if not petInfo then
        return true
    end
    
    -- 如果标记为已移除，视为死亡
    if petInfo._isDeadAndRemoved then
        return true
    end
    
    local success, result = pcall(function()
        return not petInfo:IsAlive()
    end)
    
    return success and result
end

-- 检查宠物是否满血
local function IsPetFullHealth(petInfo)
    if not petInfo or not petInfo.HealthValue then
        return false
    end
    
    local success, result = pcall(function()
        local currentHealthValue = petInfo.HealthValue.Value
        local maxHealthValue = petInfo.HealthValue:GetAttribute("MaxHealth")
        
        if not maxHealthValue or maxHealthValue == 0 then
            return false
        end
        
        local fixedCurrent = LogicNumber and LogicNumber.FixLogicNumber(currentHealthValue) or currentHealthValue
        local fixedMax = LogicNumber and LogicNumber.FixLogicNumber(maxHealthValue) or maxHealthValue
        
        local current = LogicNumber and LogicNumber.ToNumber(fixedCurrent) or tonumber(tostring(fixedCurrent)) or 0
        local max = LogicNumber and LogicNumber.ToNumber(fixedMax) or tonumber(tostring(fixedMax)) or 0
        
        -- 血量百分比 >= 99.9% 视为满血
        return max > 0 and (current / max) >= 0.999
    end)
    
    return success and result
end

-- 传送函数
local function TeleportTo(position, verifyPosition, reason)
    verifyPosition = verifyPosition ~= false  -- 默认验证位置
    reason = reason or "未命名"
    print(string.format("[TP][%s] 请求传送 -> %s", reason, tostring(position)))
    local character = player.Character
    if not character then
        warn(string.format("[TP][%s] 失败：角色不存在", reason))
        return false
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then
        warn(string.format("[TP][%s] 失败：HumanoidRootPart 不存在", reason))
        return false
    end
    
    local originalPosition = humanoidRootPart.Position
    
    local success, err = pcall(function()
        humanoidRootPart.CFrame = CFrame.new(position)
    end)
    
    if not success then
        warn(string.format("[TP][%s] 设置位置失败: %s", reason, tostring(err)))
        return false
    end
    
    -- 如果需要验证位置，等待一下然后检查
    if verifyPosition then
        task.wait(0.3)  -- 等待位置更新
        
        local newPosition = humanoidRootPart.Position
        local distance = (newPosition - position).Magnitude
        
        -- 如果距离超过10，说明TP可能失败了
        if distance > 10 then
            warn(string.format("[TP][%s] 位置验证失败: 目标=%s, 实际=%s, 距离=%.2f", 
                reason, tostring(position), tostring(newPosition), distance))
            
            -- 尝试再次TP
            pcall(function()
                humanoidRootPart.CFrame = CFrame.new(position)
            end)
            task.wait(0.3)
            
            local retryPosition = humanoidRootPart.Position
            local retryDistance = (retryPosition - position).Magnitude
            
            if retryDistance > 10 then
                warn(string.format("[TP][%s] 重试后仍然失败: 距离=%.2f", reason, retryDistance))
                return false
            else
                print(string.format("[TP][%s] 重试成功: 距离=%.2f", reason, retryDistance))
                return true
            end
        else
            print(string.format("[TP][%s] ✓ TP成功: 距离=%.2f", reason, distance))
            return true
        end
    end
    
    return true
end

-- 获取Recover对象的正确位置
local function GetRecoverObjectPosition(recoverObj)
    if not recoverObj then
        return nil
    end
    
    -- 方法1: 如果是BasePart，直接返回位置
    if recoverObj:IsA("BasePart") then
        return recoverObj.Position
    end
    
    -- 方法2: 如果是Model，查找内部的BasePart
    if recoverObj:IsA("Model") then
        -- 优先查找PrimaryPart
        if recoverObj.PrimaryPart then
            return recoverObj.PrimaryPart.Position
        end
        
        -- 查找所有BasePart，选择最合适的（通常是最大的或者特定名称的）
        local parts = {}
        for _, descendant in ipairs(recoverObj:GetDescendants()) do
            if descendant:IsA("BasePart") and descendant.Name ~= "Handle" then
                table.insert(parts, descendant)
            end
        end
        
        if #parts > 0 then
            -- 优先查找名称包含特定关键词的
            for _, part in ipairs(parts) do
                if string.find(part.Name:lower(), "spawn") or 
                   string.find(part.Name:lower(), "point") or
                   string.find(part.Name:lower(), "center") then
                    return part.Position
                end
            end
            
            -- 如果没找到特殊名称的，选择最大的Part（通常是主要部分）
            local largestPart = parts[1]
            local largestSize = largestPart.Size.X * largestPart.Size.Y * largestPart.Size.Z
            for i = 2, #parts do
                local size = parts[i].Size.X * parts[i].Size.Y * parts[i].Size.Z
                if size > largestSize then
                    largestSize = size
                    largestPart = parts[i]
                end
            end
            return largestPart.Position
        end
        
        -- 方法3: 使用GetPivot
        return recoverObj:GetPivot().Position
    end
    
    return nil
end

-- 获取最近的回血点位置
local function GetRecoverPosition()
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return nil
    end
    
    local playerPosition = character.HumanoidRootPart.Position
    local nearestRecoverObj = nil
    local nearestRecoverPos = nil
    local nearestDistance = math.huge
    
    -- 搜索所有可能的 Recover 位置
    local function SearchRecover(parent, path)
        path = path or ""
        for _, child in ipairs(parent:GetChildren()) do
            local childPath = path .. "." .. child.Name
            
            -- 检查是否是 Recover 相关的对象
            if string.find(child.Name, "Recover") or string.find(child.Name, "Rec_") then
                local recoverPos = GetRecoverObjectPosition(child)
                
                if recoverPos then
                    local distance = (playerPosition - recoverPos).Magnitude
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestRecoverObj = child
                        nearestRecoverPos = recoverPos
                        print(string.format("[自动回血] 找到回血点: %s (距离: %.2f, 位置: %s)", 
                            childPath, distance, tostring(recoverPos)))
                    end
                end
            end
            
            -- 递归搜索子对象
            if #child:GetChildren() > 0 then
                SearchRecover(child, childPath)
            end
        end
    end
    
    -- 从 workspace.Area 开始搜索
    local success, err = pcall(function()
        local area = workspace:FindFirstChild("Area")
        if area then
            SearchRecover(area, "workspace.Area")
        end
    end)
    
    if not success then
        warn("[自动回血] 搜索回血点时出错: " .. tostring(err))
    end
    
    if nearestRecoverPos then
        print(string.format("[自动回血] 找到最近的回血点，距离: %.2f, 最终位置: %s", 
            nearestDistance, tostring(nearestRecoverPos)))
        -- 添加一个小的向上偏移，确保玩家站在正确的位置
        return nearestRecoverPos + Vector3.new(0, 3, 0)
    end
    
    -- 如果没找到，尝试原来的固定路径
    local success2, recoverPart = pcall(function()
        return workspace.Area.center.ServerZone.Recover.Rec_1
    end)
    
    if success2 and recoverPart then
        local pos = GetRecoverObjectPosition(recoverPart)
        if pos then
            print(string.format("[自动回血] 使用固定路径回血点，位置: %s", tostring(pos)))
            return pos + Vector3.new(0, 3, 0)
        end
    end
    
    return nil
end

-- 检查是否在战斗状态
local function IsInBattle()
    if not PathTool then
        return false
    end
    
    local success, result = pcall(function()
        -- 方法1: 检查是否有战斗中的怪物
        if PathTool.MgrMonsterClient and PathTool.MgrMonsterClient.IsSelfBattleMonster then
            local inBattle = PathTool.MgrMonsterClient.IsSelfBattleMonster()
            if inBattle then
                return true
            end
        end
        
        -- 方法2: 检查是否有目标单位
        if PathTool.MgrPetClient and PathTool.MgrPetClient.IsSelfPlayerTargetUnitKeyExist then
            local hasTarget = PathTool.MgrPetClient.IsSelfPlayerTargetUnitKeyExist()
            if hasTarget then
                return true
            end
        end
        
        return false
    end)
    
    return success and result or false
end

-- 获取自动战斗状态（使用 IsOn 方法，与切换脚本一致）
local function GetAutoAttackState()
    if not GamePlayer and PathTool and PathTool.ClientPlayerManager then
        local success, result = pcall(function()
            return PathTool.ClientPlayerManager.GetGamePlayer()
        end)
        if success and result then
            GamePlayer = result
        end
    end
    
    if not GamePlayer or not GamePlayer.setting then
        return false
    end
    
    local success, result = pcall(function()
        return GamePlayer.setting:IsOn("AutoAttack")
    end)
    
    -- 如果检测成功，返回结果；如果失败，返回 false（默认关闭）
    return success and result or false
end

-- 设置自动战斗状态（使用 DataPullManager.DoRequest）
local function SetAutoAttackState(enabled)
    if not GamePlayer and PathTool and PathTool.ClientPlayerManager then
        local success, result = pcall(function()
            return PathTool.ClientPlayerManager.GetGamePlayer()
        end)
        if success and result then
            GamePlayer = result
        end
    end
    
    if not GamePlayer or not GamePlayer.setting then
        warn("[自动回血] GamePlayer 未就绪，无法设置自动战斗")
        return false
    end
    
    if not PathTool or not PathTool.DataPullManager then
        warn("[自动回血] DataPullManager 未找到")
        return false
    end
    
    -- 先检查当前状态
    local currentState = GetAutoAttackState()
    
    -- 如果目标状态和当前状态相同，不需要操作
    if currentState == enabled then
        return true
    end
    
    -- 使用 DataPullManager.DoRequest 方法
    local channel = PathTool.DataPullManager.GetChannel("SettingSetOnOffChannel")
    if not channel then
        warn("[自动回血] SettingSetOnOffChannel 通道未找到")
        return false
    end
    
    local success, result = pcall(function()
        return channel:DoRequest("AutoAttack", enabled)
    end)
    
    if success then
        -- 等待设置生效
        task.wait(0.2)
        
        -- 验证状态
        local newState = GetAutoAttackState()
        if newState == enabled then
            print(string.format("[自动回血] ✓ 自动战斗已%s", enabled and "开启" or "关闭"))
            return true
        else
            warn(string.format("[自动回血] ⚠ 自动战斗设置可能未生效: 目标=%s, 实际=%s", 
                tostring(enabled), tostring(newState)))
            return false
        end
    else
        warn(string.format("[自动回血] ✗ 设置自动战斗状态失败: %s", tostring(result)))
        return false
    end
end

-- 自动合成状态
local autoEvolveEnabled = false
local autoEvolveRunning = false

-- 打开/关闭宠物合成界面
local function OpenPetEvolveView()
    if not PathTool or not PathTool.ViewManager then
        return false
    end
    local ok, err = pcall(function()
        PathTool.ViewManager.OpenView("PetEvolveView")
    end)
    if not ok then
        return false
    end
    return true
end

local function ClosePetEvolveView()
    if not PathTool or not PathTool.ViewManager then
        return false
    end
    local ok, err = pcall(function()
        PathTool.ViewManager.CloseView("PetEvolveView")
    end)
    if not ok then
        return false
    end
    return true
end

local function WaitForViewOpen(viewName, timeout)
    timeout = timeout or 5
    local startTime = tick()
    while tick() - startTime < timeout do
        if PathTool and PathTool.ViewManager and PathTool.ViewManager.IsViewOpen then
            local ok, isOpen = pcall(function()
                return PathTool.ViewManager.IsViewOpen(viewName)
            end)
            if ok and isOpen then
                return true
            end
        end
        task.wait(0.1)
    end
    return false
end

-- 获取所有可合成组合
local function GetEvolveGroups()
    if not GamePlayer or not GamePlayer.pet then
        return {}
    end

    local groups = {}
    local processedPetIds = {}

    local success, err = pcall(function()
        GamePlayer.pet:IterItem(function(petItem)
            if not petItem then
                return true
            end

            local petId = petItem.PetItemId or petItem:GetId()
            if not petId then
                return true
            end

            local petIdKey = tostring(petId)
            if processedPetIds[petIdKey] then
                return true
            end
            processedPetIds[petIdKey] = true

            local config = petItem:GetTmpl()
            if not config then
                return true
            end

            local name = config.Name
            local grade = petItem:GetGrade()
            if not name or not grade then
                return true
            end

            local evolveConfig = config.Evolve and config.Evolve[grade]
            if not evolveConfig then
                return true
            end
            
            -- 如果本次进化需要额外碎片/道具（CommonItem），则跳过该等级的自动合成
            -- CfgPetEvolve 中，当 Cost 里包含 { CostRes = "CommonItem", ... } 时，表示需要碎片
            local needFragment = false
            local costCfg = evolveConfig.Cost
            if type(costCfg) == "table" then
                -- 两种结构：单表 {CostRes=...} 或数组 { {CostRes=...}, {CostRes=...} }
                if costCfg.CostRes == "CommonItem" then
                    needFragment = true
                else
                    for _, c in pairs(costCfg) do
                        if type(c) == "table" and c.CostRes == "CommonItem" then
                            needFragment = true
                            break
                        end
                    end
                end
            end
            if needFragment then
                -- 该进化需要额外碎片，自动合成直接跳过
                --print(string.format("[自动合成] 跳过需要碎片的进化: %s 等级 %d", tostring(name), grade))
                return true
            end
            
            local costTmplAmount = evolveConfig.CostTmplAmount or 0
            if costTmplAmount <= 0 then
                return true
            end

            local key = name .. "_" .. tostring(grade)
            if not groups[key] then
                groups[key] = {
                    name = name,
                    grade = grade,
                    count = costTmplAmount,
                    items = {}
                }
            end

            table.insert(groups[key].items, {
                id = petId,
                equipped = petItem:GetEquipedIndex() ~= nil
            })

            return true
        end)
    end)

    if not success then
        return {}
    end

    local validGroups = {}
    for _, group in pairs(groups) do
        if #group.items >= group.count + 1 then
            table.sort(group.items, function(a, b)
                if not a.equipped and b.equipped then
                    return true
                elseif a.equipped and not b.equipped then
                    return false
                else
                    return tostring(a.id) < tostring(b.id)
                end
            end)

            local unequippedCount = 0
            for _, item in ipairs(group.items) do
                if not item.equipped then
                    unequippedCount = unequippedCount + 1
                end
            end

            if unequippedCount >= group.count then
                table.insert(validGroups, group)
            end
        end
    end

    table.sort(validGroups, function(a, b)
        if a.name == b.name then
            return a.grade < b.grade
        else
            return a.name < b.name
        end
    end)

    return validGroups
end

-- 组装主体/材料 PetItemId
local function BuildEvolveIds(group)
    local needTotal = group.count + 1
    if #group.items < needTotal then
        return nil
    end

    local basePetItemId = nil
    local baseGrade = nil
    local materialIds = {}

    for i = 1, needTotal do
        local item = group.items[i]
        if not item then
            return nil
        end

        local petItem = GamePlayer.pet:GetItem(item.id)
        if not petItem then
            return nil
        end

        local petItemId = petItem.PetItemId or petItem:GetId()
        if not petItemId then
            return nil
        end

        local grade = petItem:GetGrade()
        local isEquipped = petItem:GetEquipedIndex() ~= nil

        if i == 1 then
            basePetItemId = tostring(petItemId)
            baseGrade = grade
        else
            if isEquipped then
                return nil
            end
            if grade ~= baseGrade then
                return nil
            end
            table.insert(materialIds, tostring(petItemId))
        end
    end

    if basePetItemId and #materialIds == group.count then
        return basePetItemId, materialIds
    end

    return nil
end

-- 执行一次合成
local function PerformEvolve(mainPetItemId, materialIds)
    if not PathTool or not PathTool.DataPullManager then
        return false
    end

    local channel = PathTool.DataPullManager.GetChannel("PetEvolveChannel")
    if not channel then
        return false
    end
    
    local ok, result = pcall(function()
        return channel:DoRequest(tostring(mainPetItemId), materialIds)
    end)

    if ok then
        if result == true or (type(result) == "table" and result.Reward) then
            return true
        else
            return false
        end
    end

    return false
end

local function AutoEvolveLoop()
    if autoEvolveRunning then
        return
    end
    autoEvolveRunning = true

    while autoEvolveEnabled do
        -- 只有在非战斗状态下才进行合成
        if IsInBattle() then
            task.wait(1)
        else
            local groups = GetEvolveGroups()
            if #groups == 0 then
                task.wait(1)
            else
                if OpenPetEvolveView() then
                    local viewOpened = WaitForViewOpen("PetEvolveView", 6)
                    if viewOpened then
                        task.wait(0.5)
                    else
                        ClosePetEvolveView()
                        task.wait(1)
                    end
                else
                    task.wait(1)
                end
                
                -- 如果界面未打开，跳过本次循环
                local viewOpen = false
                if PathTool and PathTool.ViewManager and PathTool.ViewManager.IsViewOpen then
                    local ok, isOpen = pcall(function()
                        return PathTool.ViewManager.IsViewOpen("PetEvolveView")
                    end)
                    if ok and isOpen then
                        viewOpen = true
                    end
                end
                
                local performed = false
                if viewOpen then
                    for i, group in ipairs(groups) do
                        local mainPetItemId, materialIds = BuildEvolveIds(group)
                        if mainPetItemId and materialIds then
                            performed = PerformEvolve(mainPetItemId, materialIds)
                            break
                        end
                    end

                    ClosePetEvolveView()
                end

                if performed then
                    task.wait(1)
                else
                    task.wait(0.5)
                end
            end
        end

        task.wait(0.2)
    end

    autoEvolveRunning = false
end

-- 自动回血状态
local autoHealEnabled = false
local autoHealForcedByRift = false
local savedPosition = nil
local isAtRecoverPoint = false
local lastCheckTime = 0
local recoverPointArrivalTime = nil  -- 到达回血点的时间
local MAX_RECOVER_WAIT_TIME = 120  -- 最大等待时间（秒），超过这个时间强制回传
local teleportBackAttempts = 0  -- 回传尝试次数
local autoAttackWasEnabled = false  -- 记录传送前自动战斗的状态
local healSource = nil  -- "auto" | "rift"

-- 自动刷裂缝状态
local autoRiftEnabled = false
local autoRiftRunning = false
local riftNeedRecover = false
local riftWasInBattle = nil
local lastRiftSeenTick = 0
local RIFT_GRACE_TIME = 15  -- 裂缝消失后的容错时间（秒）
local lastRiftEnterTick = 0
local RIFT_ENTER_COOLDOWN = 8  -- 自动进入裂缝的冷却（秒）
local riftEntryPosition = nil  -- 进入裂缝前的入口位置
local farmingPosition = nil  -- 刷怪点位置（记录按钮设置）
local riftState = "idle" -- idle | entering | in_dungeon | recovering
local failedRiftNodes = {}  -- 记录失败的裂缝节点，避免重复尝试
local FAILED_RIFT_COOLDOWN = 60  -- 失败节点的冷却时间（秒）

-- 裂缝统计
local riftStats = {
    total = 0,      -- 总共进入
    success = 0,    -- 成功完成
    failed = 0      -- 失败
}
local riftStatsLabel = nil  -- UI统计标签

local function GetGamePlayer()
    if GamePlayer then
        return GamePlayer
    end
    if PathTool and PathTool.ClientPlayerManager then
        local ok, gp = pcall(function()
            return PathTool.ClientPlayerManager.GetGamePlayer()
        end)
        if ok and gp then
            GamePlayer = gp
            return gp
        end
    end
    return nil
end

local function SetRiftState(state)
    if riftState ~= state then
        print(string.format("[自动刷裂缝] 状态切换: %s -> %s", riftState, state))
        riftState = state
    end
end

-- 地牢通道调用（避免 PathTool.Require）
local function DoDungeonRequest(channelName, ...)
    local args = { ... }
    local unpackArgs = table.unpack or unpack
    if PathTool and PathTool.DataPullManager then
        local channel = PathTool.DataPullManager.GetChannel(channelName)
        if channel then
            local ok, result = pcall(function()
                return channel:DoRequest(unpackArgs(args))
            end)
            if ok then
                return result ~= false
            end
        end
    end
    local ok, result = pcall(function()
        local RemoteManager = ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("RemoteManager")
        local DataPullFunc = RemoteManager:WaitForChild("Funcs"):WaitForChild("DataPullFunc")
        local callArgs = { channelName }
        for _, v in ipairs(args) do
            table.insert(callArgs, v)
        end
        return DataPullFunc:InvokeServer(unpackArgs(callArgs))
    end)
    if not ok then
        warn("[自动刷裂缝] 通道请求失败:", channelName, result)
        return false
    end
    return result ~= false
end

local function LeaveArena()
    local ok = DoDungeonRequest("ArenaLeaveChannel")
    return ok
end

-- 辅助函数：格式化打印值（处理table等复杂类型）
local function formatValue(value)
    if value == nil then
        return "nil"
    elseif type(value) == "table" then
        local result = "{"
        local count = 0
        for k, v in pairs(value) do
            count = count + 1
            if count > 10 then  -- 限制table打印长度
                result = result .. "...(更多)"
                break
            end
            if type(k) == "string" then
                result = result .. string.format('["%s"]=', k)
            else
                result = result .. string.format("[%s]=", tostring(k))
            end
            result = result .. formatValue(v) .. ", "
        end
        result = result:gsub(", $", "") .. "}"
        return result
    elseif type(value) == "string" then
        return string.format('"%s"', value)
    else
        return tostring(value)
    end
end

-- 辅助函数：打印节点的所有属性
local function printNodeAttributes(node, label)
    local attrs = {}
    for _, attrName in ipairs(node:GetAttributes()) do
        local attrValue = node:GetAttribute(attrName)
        attrs[attrName] = attrValue
    end
    
    print(string.format("[%s] 节点属性:", label))
    print(string.format("  节点名称: %s", node.Name))
    print(string.format("  节点路径: %s", node:GetFullName()))
    print(string.format("  节点类型: %s", node.ClassName))
    if next(attrs) then
        print("  属性列表:")
        for attrName, attrValue in pairs(attrs) do
            print(string.format("    %s = %s", attrName, formatValue(attrValue)))
        end
    else
        print("  属性列表: (无)")
    end
    
    -- 检查父节点的属性
    local parent = node.Parent
    if parent then
        local parentAttrs = {}
        for _, attrName in ipairs(parent:GetAttributes()) do
            local attrValue = parent:GetAttribute(attrName)
            parentAttrs[attrName] = attrValue
        end
        if next(parentAttrs) then
            print(string.format("  父节点 (%s) 属性:", parent.Name))
            for attrName, attrValue in pairs(parentAttrs) do
                print(string.format("    %s = %s", attrName, formatValue(attrValue)))
            end
        end
    end
end

local function alreadyEnteredDungeon(node)
    local gp = GetGamePlayer()
    if not gp or not gp.dungeon or not node then
        return false
    end
    local dynamicKey = node:GetAttribute("DungeonDynamicKey")
    local startTick = node:GetAttribute("DungeonStartTick")
    
    -- 如果属性在父节点上，尝试从父节点获取
    if not startTick then
        local parent = node.Parent
        if parent then
            startTick = parent:GetAttribute("DungeonStartTick")
            if not dynamicKey then
                dynamicKey = parent:GetAttribute("DungeonDynamicKey")
            end
        end
    end
    
    -- 动态地牢：使用 IsDynamicEntered 检查
    if dynamicKey and startTick and gp.dungeon.IsDynamicEntered then
        local ok, res = pcall(function()
            return gp.dungeon:IsDynamicEntered(dynamicKey, startTick)
        end)
        if ok and res then
            return true
        end
    end
    
    -- 静态地牢：使用 GroupId、StartTick 和 UseMem 检查
    -- 根据DungeonSystem代码，静态地牢使用 IsEntered(GroupId, StartTick, UseMem)
    -- 注意：同一个静态地牢的StartTick可能会变化，所以每次检查时获取最新的StartTick
    if not dynamicKey then
        local groupId = node:GetAttribute("DungeonGroupId")
        local useMem = node:GetAttribute("DungeonUseMem")
        
        -- 如果属性在父节点上，尝试从父节点获取
        if not groupId or useMem == nil then
            local parent = node.Parent
            if parent then
                if not groupId then
                    groupId = parent:GetAttribute("DungeonGroupId")
                end
                if useMem == nil then
                    useMem = parent:GetAttribute("DungeonUseMem")
                end
            end
        end
        
        -- 静态地牢必须有 GroupId 才能检查
        -- 注意：StartTick可能会变化，所以每次检查时重新获取最新的StartTick
        if groupId then
            -- 打印静态地牢的源数据（打印所有属性，不做任何提取）
            print("\n========== 静态地牢检测 ==========")
            printNodeAttributes(node, "静态地牢节点")
            
            -- 重新获取最新的StartTick（因为同一个地牢的StartTick可能会变化）
            local latestStartTick = node:GetAttribute("DungeonStartTick")
            local latestStartTickSource = "节点本身"
            if not latestStartTick then
                local parent = node.Parent
                if parent then
                    latestStartTick = parent:GetAttribute("DungeonStartTick")
                    latestStartTickSource = "父节点: " .. parent.Name
                end
            end
            
            if latestStartTick and gp.dungeon and gp.dungeon.IsEntered then
                print(string.format("\n调用 gp.dungeon:IsEntered(%s, %s, %s)", 
                    formatValue(groupId), formatValue(latestStartTick), formatValue(useMem or false)))
                local ok, res = pcall(function()
                    -- useMem 可能是 nil，需要处理
                    return gp.dungeon:IsEntered(groupId, latestStartTick, useMem or false)
                end)
                print(string.format("  返回结果: ok=%s, res=%s", tostring(ok), formatValue(res)))
                if ok and res then
                    print("========== 检测结果: 已进入过 ==========\n")
                    return true
                elseif ok then
                    print("========== 检测结果: 未进入 ==========\n")
                    -- 检查成功但返回false，说明未进入
                else
                    print(string.format("========== 检测结果: 错误 ==========\n"))
                    -- 检查出错，静默失败
                end
            else
                print(string.format("\n无法检查: latestStartTick=%s, gp.dungeon=%s, gp.dungeon.IsEntered=%s", 
                    formatValue(latestStartTick), 
                    gp and gp.dungeon and "存在" or "不存在",
                    gp and gp.dungeon and gp.dungeon.IsEntered and "存在" or "不存在"))
                print("==========\n")
            end
        end
    end
    
    return false
end

local function TryOpenDungeonTeamView(node)
    if not PathTool or not PathTool.ViewManager then
        return false
    end
    
    -- 如果节点名称不是 Dungeon_XXXX 格式，向上查找父节点
    local actualNode = node
    if string.sub(node.Name or "", 1, 8) ~= "Dungeon_" then
        -- 向上查找，直到找到 Dungeon_XXXX 节点
        local parent = node.Parent
        while parent do
            if string.sub(parent.Name or "", 1, 8) == "Dungeon_" then
                actualNode = parent
                break
            end
            parent = parent.Parent
        end
    end
    
    local showId = tonumber(string.sub(actualNode.Name or "", 9))
    local startTick = actualNode:GetAttribute("DungeonStartTick")
    local syncKey = actualNode:GetAttribute("DungeonSyncObjectKey")
    
    -- 如果属性仍然为空，尝试从父节点获取（对于静态地牢，属性可能在 Dungeon 文件夹上）
    if not startTick or not syncKey then
        local parent = actualNode.Parent
        if parent then
            if not startTick then
                startTick = parent:GetAttribute("DungeonStartTick")
            end
            if not syncKey then
                syncKey = parent:GetAttribute("DungeonSyncObjectKey")
            end
        end
    end
    
    if not showId or not startTick or not syncKey then
        warn("[自动刷裂缝] TryOpenDungeonTeamView: 缺少必要属性", 
             "节点="..tostring(actualNode:GetFullName()),
             "showId="..tostring(showId), 
             "startTick="..tostring(startTick), 
             "syncKey="..tostring(syncKey))
        return false
    end
    
    -- 检查是否为静态地牢（静态地牢都在 workspace.Area.xxx.Area.Dungeon. 这种路径）
    -- 有Portal说明是开启状态
    local groupId = actualNode:GetAttribute("DungeonGroupId")
    local dynamicKey = actualNode:GetAttribute("DungeonDynamicKey")
    local nodePath = actualNode:GetFullName()
    
    -- 如果节点在DynamicDungeon目录下，不是静态地牢（DynamicDungeon都在DynamicDungeon目录下）
    local isStaticDungeon = false
    if string.find(nodePath, "DynamicDungeon") then
        -- DynamicDungeon：使用原有判断逻辑
        isStaticDungeon = (groupId and not dynamicKey) or false
    else
        -- 静态地牢判断：检查路径是否为 workspace.Area.xxx.Area.Dungeon. 格式
        -- 有Portal说明是开启状态，检查节点下是否有Portal子节点
        local hasPortal = false
        pcall(function()
            for _, child in ipairs(actualNode:GetChildren()) do
                if string.find(child.Name, "Portal") then
                    hasPortal = true
                    break
                end
            end
        end)
        
        -- 静态地牢：路径包含 Area.*.Area.Dungeon（Portal只是辅助判断开启状态，不是必要条件）
        -- 注意：有些裂缝可能没有Portal子节点（如501），但仍然是静态地牢
        local pathMatches = string.find(nodePath, "Area") and string.find(nodePath, "Dungeon") and not string.find(nodePath, "DynamicDungeon")
        isStaticDungeon = pathMatches
    end
    
    local ok = false
    if isStaticDungeon then
        -- 静态地牢：尝试使用 AreaDungeonShower.Create 创建 DungeonShowInfo
        ok = pcall(function()
            local AreaDungeonShower = rawget(PathTool, "AreaDungeonShower")
            if AreaDungeonShower and AreaDungeonShower.Create then
                -- 尝试找到 ZoneKey（应该是 "Dungeon"）
                local zoneKey = "Dungeon"
                -- 尝试找到 ZoneCfg（从 ZoneConfig）
                local zoneCfg = nil
                if PathTool.Require then
                    local ok2, cfg = pcall(function()
                        return PathTool.Require(script:FindFirstChild("ZoneConfig") or script.Parent:FindFirstChild("ZoneConfig"))
                    end)
                    if ok2 and cfg and cfg[zoneKey] then
                        zoneCfg = cfg[zoneKey]
                    end
                end
                
                -- 创建 ZoneNode 信息对象
                local zoneInfo = {
                    ZoneNode = actualNode,
                    ZoneKey = zoneKey,
                    ZoneCfg = zoneCfg
                }
                
                -- 使用 AreaDungeonShower.Create 创建 DungeonShowInfo
                local dungeonShowInfo = AreaDungeonShower.Create(zoneInfo)
                if dungeonShowInfo then
                    -- 确保属性已更新
                    if dungeonShowInfo._onUpdateShow then
                        dungeonShowInfo._onUpdateShow()
                    end
                    task.wait(0.2)  -- 等待属性更新
                    -- 使用创建的 DungeonShowInfo 打开界面
                    PathTool.ViewManager.OpenView("DungeonTeamView", dungeonShowInfo, syncKey)
                    print("[自动刷裂缝] 静态地牢：使用 AreaDungeonShower.Create 打开界面")
                    return true
                else
                    warn("[自动刷裂缝] AreaDungeonShower.Create 返回 nil")
                end
            else
                warn("[自动刷裂缝] AreaDungeonShower 不可用")
            end
            
            -- 如果 AreaDungeonShower 不可用，尝试直接打开（备用方案）
            warn("[自动刷裂缝] 尝试直接打开静态地牢界面（备用方案）")
            PathTool.ViewManager.OpenView("DungeonTeamView", {
                Node = actualNode,
                DungeonShowId = showId,
                _dungeonStartTick = startTick,
                _dungeonTmplId = actualNode:GetAttribute("DungeonTmplId"),
                _dungeonEndTick = actualNode:GetAttribute("DungeonEndTick"),
                _dungeonGroupId = groupId,
                _dungeonUseMem = actualNode:GetAttribute("DungeonUseMem"),
            }, syncKey)
        end)
    else
        -- 动态地牢：使用原来的方式
        ok = pcall(function()
            PathTool.ViewManager.OpenView("DungeonTeamView", {
                Node = actualNode,
                DungeonShowId = showId,
                _dungeonStartTick = startTick,
                _dungeonTmplId = actualNode:GetAttribute("DungeonTmplId"),
                _dungeonEndTick = actualNode:GetAttribute("DungeonEndTick"),
                _dungeonGroupId = groupId,
                _dungeonUseMem = actualNode:GetAttribute("DungeonUseMem"),
                _dungeonDynamicKey = dynamicKey,
            }, syncKey)
        end)
    end
    
    if not ok then
        warn("[自动刷裂缝] TryOpenDungeonTeamView 失败")
    end
    return ok
end

local function TryCreateAndStartDungeon(node)
    local showId = tonumber(string.sub(node.Name or "", 9))
    local startTick = node:GetAttribute("DungeonStartTick")
    if not showId or not startTick then
        return false
    end
    local okCreate = DoDungeonRequest("DungeonCreateTeamChannel", showId, startTick)
    if not okCreate then
        return false
    end
    -- 创建队伍后增加1秒延迟再开始，避免太快导致的问题
    task.wait(1)
    local okStart = DoDungeonRequest("DungeonStartChannel", showId, startTick)
    return okStart
end

-- 判断当前是否存在裂缝（基于动态地牢 + 配置名）
local function IsRiftNode(node, cfg)
    if not node then
        return false
    end
    local name = node.Name or ""
    if string.find(string.lower(name), "rift") or string.find(name, "裂缝") then
        return true
    end
    if string.sub(name, 1, 8) == "Dungeon_" then
        return true
    end
    local attrs = node:GetAttributes()
    for k, v in pairs(attrs) do
        local key = tostring(k)
        if string.find(string.lower(key), "rift") or string.find(key, "裂缝") then
            return true
        end
        if type(v) == "string" then
            if string.find(string.lower(v), "rift") or string.find(v, "裂缝") then
                return true
            end
        end
    end
    local tmplId = node:GetAttribute("DungeonTmplId")
    if tmplId then
        return true
    end
    if cfg and tmplId then
        local c = cfg[tmplId] or cfg[tostring(tmplId)]
        local cfgName = c and (c.Name or c.ShowName or c.Desc)
        if cfgName and (string.find(string.lower(cfgName), "rift") or string.find(tostring(cfgName), "裂缝")) then
            return true
        end
    end
    return false
end

local function IsRiftPresent()
    local cfg = nil
    if PathTool then
        cfg = rawget(PathTool, "CfgDungeon")
        if type(cfg) ~= "table" then
            cfg = nil
        end
    end
    
    -- 方法1: 检查 DynamicDungeon 下的动态地牢
    local root = workspace:FindFirstChild("DynamicDungeon")
    if root then
        for _, node in ipairs(root:GetChildren()) do
            if IsRiftNode(node, cfg) then
                -- 检查地牢是否激活（必须有 StartTick 和 SyncKey）
                local startTick = node:GetAttribute("DungeonStartTick")
                local syncKey = node:GetAttribute("DungeonSyncObjectKey")
                if startTick and syncKey then
                    lastRiftSeenTick = tick()
                    return true
                end
            end
        end
    end
    
    -- 方法2: 检查 Area.*.Area.Dungeon 下的静态地牢（新路径格式）
    local areaFolder = workspace:FindFirstChild("Area")
    if areaFolder then
        for _, areaChild in ipairs(areaFolder:GetChildren()) do
            -- 检查 Area.*.Area.Dungeon 路径
            local areaSubFolder = areaChild:FindFirstChild("Area")
            if areaSubFolder then
                local dungeonFolder = areaSubFolder:FindFirstChild("Dungeon")
                if dungeonFolder then
                    for _, node in ipairs(dungeonFolder:GetChildren()) do
                        -- 检查名称格式是否为 Dungeon_XXXX
                        if string.sub(node.Name, 1, 8) == "Dungeon_" and IsRiftNode(node, cfg) then
                            -- 检查地牢是否激活（必须有 StartTick 和 SyncKey）
                            local startTick = node:GetAttribute("DungeonStartTick")
                            local syncKey = node:GetAttribute("DungeonSyncObjectKey")
                            -- 如果属性在父节点上，尝试从父节点获取
                            if not startTick or not syncKey then
                                local parent = node.Parent
                                if parent then
                                    if not startTick then
                                        startTick = parent:GetAttribute("DungeonStartTick")
                                    end
                                    if not syncKey then
                                        syncKey = parent:GetAttribute("DungeonSyncObjectKey")
                                    end
                                end
                            end
                            if startTick and syncKey then
                                lastRiftSeenTick = tick()
                                return true
                            end
                        end
                    end
                end
            end
            -- 检查 Area.*.ServerZone.Dungeon 路径（旧格式，保持兼容）
            local serverZone = areaChild:FindFirstChild("ServerZone")
            if serverZone then
                local dungeonFolder = serverZone:FindFirstChild("Dungeon")
                if dungeonFolder then
                    for _, node in ipairs(dungeonFolder:GetChildren()) do
                        -- 检查名称格式是否为 Dungeon_XXXX
                        if string.sub(node.Name, 1, 8) == "Dungeon_" and IsRiftNode(node, cfg) then
                            -- 检查地牢是否激活（必须有 StartTick 和 SyncKey）
                            local startTick = node:GetAttribute("DungeonStartTick")
                            local syncKey = node:GetAttribute("DungeonSyncObjectKey")
                            -- 如果属性在父节点上，尝试从父节点获取
                            if not startTick or not syncKey then
                                local parent = node.Parent
                                if parent then
                                    if not startTick then
                                        startTick = parent:GetAttribute("DungeonStartTick")
                                    end
                                    if not syncKey then
                                        syncKey = parent:GetAttribute("DungeonSyncObjectKey")
                                    end
                                end
                            end
                            if startTick and syncKey then
                                lastRiftSeenTick = tick()
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    
    return false
end

local function getRiftNodeAndPos(skipEntered)
    skipEntered = skipEntered ~= false  -- 默认跳过已进入的
    local cfg = nil
    if PathTool then
        cfg = rawget(PathTool, "CfgDungeon")
        if type(cfg) ~= "table" then
            cfg = nil
        end
    end
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    local playerPos = hrp and hrp.Position
    local nearestNode, nearestPos, nearestDist
    local anyNode, anyPos
    
    -- 收集所有未进入的裂缝节点
    local validNodes = {}
    
    -- 方法1: 搜索 DynamicDungeon 下的动态地牢
    local root = workspace:FindFirstChild("DynamicDungeon")
    if root then
        for _, node in ipairs(root:GetChildren()) do
            local pos = node:GetPivot().Position
            if not anyNode then
                anyNode = node
                anyPos = pos
            end
            if IsRiftNode(node, cfg) then
                -- 检查地牢是否激活（必须有 StartTick 和 SyncKey）
                local startTick = node:GetAttribute("DungeonStartTick")
                local syncKey = node:GetAttribute("DungeonSyncObjectKey")
                -- 如果属性在父节点上，尝试从父节点获取
                if not startTick or not syncKey then
                    local parent = node.Parent
                    if parent then
                        if not startTick then
                            startTick = parent:GetAttribute("DungeonStartTick")
                        end
                        if not syncKey then
                            syncKey = parent:GetAttribute("DungeonSyncObjectKey")
                        end
                    end
                end
                -- 只有当地牢激活且有 SyncKey 时才添加
                if startTick and syncKey then
                    -- 检查是否在失败冷却列表中
                    local nodeKey = tostring(node)
                    local failedTime = failedRiftNodes[nodeKey]
                    local isInCooldown = failedTime and (tick() - failedTime) < FAILED_RIFT_COOLDOWN
                    if isInCooldown then
                        -- 跳过冷却中的节点
                    elseif skipEntered and alreadyEnteredDungeon(node) then
                        -- 跳过已进入的
                    else
                        table.insert(validNodes, {node = node, pos = pos})
                    end
                end
            end
        end
    end
    
    -- 方法2: 搜索 Area.*.Area.Dungeon 下的静态地牢（新路径格式）
    local areaFolder = workspace:FindFirstChild("Area")
    if areaFolder then
        for _, areaChild in ipairs(areaFolder:GetChildren()) do
            -- 检查 Area.*.Area.Dungeon 路径
            local areaSubFolder = areaChild:FindFirstChild("Area")
            if areaSubFolder then
                local dungeonFolder = areaSubFolder:FindFirstChild("Dungeon")
                if dungeonFolder then
                    for _, node in ipairs(dungeonFolder:GetChildren()) do
                        -- 检查名称格式是否为 Dungeon_XXXX
                        if string.sub(node.Name, 1, 8) == "Dungeon_" then
                            local pos = node:GetPivot().Position
                            if not anyNode then
                                anyNode = node
                                anyPos = pos
                            end
                            if IsRiftNode(node, cfg) then
                                -- 检查地牢是否激活（必须有 StartTick 和 SyncKey）
                                local startTick = node:GetAttribute("DungeonStartTick")
                                local syncKey = node:GetAttribute("DungeonSyncObjectKey")
                                -- 如果属性在父节点上，尝试从父节点获取
                                if not startTick or not syncKey then
                                    local parent = node.Parent
                                    if parent then
                                        if not startTick then
                                            startTick = parent:GetAttribute("DungeonStartTick")
                                        end
                                        if not syncKey then
                                            syncKey = parent:GetAttribute("DungeonSyncObjectKey")
                                        end
                                    end
                                end
                                -- 只有当地牢激活且有 SyncKey 时才添加
                                if startTick and syncKey then
                                    -- 检查是否在失败冷却列表中
                                    local nodeKey = tostring(node)
                                    local failedTime = failedRiftNodes[nodeKey]
                                    local isInCooldown = failedTime and (tick() - failedTime) < FAILED_RIFT_COOLDOWN
                                    if isInCooldown then
                                        -- 跳过冷却中的节点
                                    elseif skipEntered and alreadyEnteredDungeon(node) then
                                        -- 跳过已进入的
                                    else
                                        table.insert(validNodes, {node = node, pos = pos})
                                    end
                                end
                            end
                        end
                    end
                end
            end
            -- 检查 Area.*.ServerZone.Dungeon 路径（旧格式，保持兼容）
            local serverZone = areaChild:FindFirstChild("ServerZone")
            if serverZone then
                local dungeonFolder = serverZone:FindFirstChild("Dungeon")
                if dungeonFolder then
                    for _, node in ipairs(dungeonFolder:GetChildren()) do
                        -- 检查名称格式是否为 Dungeon_XXXX
                        if string.sub(node.Name, 1, 8) == "Dungeon_" then
                            local pos = node:GetPivot().Position
                            if not anyNode then
                                anyNode = node
                                anyPos = pos
                            end
                            if IsRiftNode(node, cfg) then
                                -- 检查地牢是否激活（必须有 StartTick 和 SyncKey）
                                local startTick = node:GetAttribute("DungeonStartTick")
                                local syncKey = node:GetAttribute("DungeonSyncObjectKey")
                                -- 如果属性在父节点上，尝试从父节点获取
                                if not startTick or not syncKey then
                                    local parent = node.Parent
                                    if parent then
                                        if not startTick then
                                            startTick = parent:GetAttribute("DungeonStartTick")
                                        end
                                        if not syncKey then
                                            syncKey = parent:GetAttribute("DungeonSyncObjectKey")
                                        end
                                    end
                                end
                                -- 只有当地牢激活且有 SyncKey 时才添加
                                if startTick and syncKey then
                                    -- 检查是否在失败冷却列表中
                                    local nodeKey = tostring(node)
                                    local failedTime = failedRiftNodes[nodeKey]
                                    local isInCooldown = failedTime and (tick() - failedTime) < FAILED_RIFT_COOLDOWN
                                    if isInCooldown then
                                        -- 跳过冷却中的节点
                                    elseif skipEntered and alreadyEnteredDungeon(node) then
                                        -- 跳过已进入的
                                    else
                                        table.insert(validNodes, {node = node, pos = pos})
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- 如果没有找到未进入的节点，但skipEntered为true，尝试返回已进入的（作为后备）
    if #validNodes == 0 and skipEntered then
        -- 重新遍历动态地牢，这次包含已进入的
        if root then
            for _, node in ipairs(root:GetChildren()) do
                if IsRiftNode(node, cfg) then
                    -- 检查地牢是否激活（必须有 StartTick 和 SyncKey）
                    local startTick = node:GetAttribute("DungeonStartTick")
                    local syncKey = node:GetAttribute("DungeonSyncObjectKey")
                    if startTick and syncKey then
                        -- 检查是否在失败冷却列表中
                        local nodeKey = tostring(node)
                        local failedTime = failedRiftNodes[nodeKey]
                        local isInCooldown = failedTime and (tick() - failedTime) < FAILED_RIFT_COOLDOWN
                        if not isInCooldown then
                            local pos = node:GetPivot().Position
                            table.insert(validNodes, {node = node, pos = pos})
                        end
                    end
                end
            end
        end
        -- 重新遍历静态地牢，这次包含已进入的
        if areaFolder then
            for _, areaChild in ipairs(areaFolder:GetChildren()) do
                -- 检查 Area.*.Area.Dungeon 路径
                local areaSubFolder = areaChild:FindFirstChild("Area")
                if areaSubFolder then
                    local dungeonFolder = areaSubFolder:FindFirstChild("Dungeon")
                    if dungeonFolder then
                        for _, node in ipairs(dungeonFolder:GetChildren()) do
                            if string.sub(node.Name, 1, 8) == "Dungeon_" and IsRiftNode(node, cfg) then
                                -- 检查地牢是否激活（必须有 StartTick 和 SyncKey）
                                local startTick = node:GetAttribute("DungeonStartTick")
                                local syncKey = node:GetAttribute("DungeonSyncObjectKey")
                                -- 如果属性在父节点上，尝试从父节点获取
                                if not startTick or not syncKey then
                                    local parent = node.Parent
                                    if parent then
                                        if not startTick then
                                            startTick = parent:GetAttribute("DungeonStartTick")
                                        end
                                        if not syncKey then
                                            syncKey = parent:GetAttribute("DungeonSyncObjectKey")
                                        end
                                    end
                                end
                                if startTick and syncKey then
                                    local pos = node:GetPivot().Position
                                    table.insert(validNodes, {node = node, pos = pos})
                                end
                            end
                        end
                    end
                end
                -- 检查 Area.*.ServerZone.Dungeon 路径（旧格式，保持兼容）
                local serverZone = areaChild:FindFirstChild("ServerZone")
                if serverZone then
                    local dungeonFolder = serverZone:FindFirstChild("Dungeon")
                    if dungeonFolder then
                        for _, node in ipairs(dungeonFolder:GetChildren()) do
                            if string.sub(node.Name, 1, 8) == "Dungeon_" and IsRiftNode(node, cfg) then
                                -- 检查地牢是否激活（必须有 StartTick 和 SyncKey）
                                local startTick = node:GetAttribute("DungeonStartTick")
                                local syncKey = node:GetAttribute("DungeonSyncObjectKey")
                                -- 如果属性在父节点上，尝试从父节点获取
                                if not startTick or not syncKey then
                                    local parent = node.Parent
                                    if parent then
                                        if not startTick then
                                            startTick = parent:GetAttribute("DungeonStartTick")
                                        end
                                        if not syncKey then
                                            syncKey = parent:GetAttribute("DungeonSyncObjectKey")
                                        end
                                    end
                                end
                                if startTick and syncKey then
                                    local pos = node:GetPivot().Position
                                    table.insert(validNodes, {node = node, pos = pos})
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- 从有效节点中找到最近的
    for _, data in ipairs(validNodes) do
        local node = data.node
        local pos = data.pos
        if playerPos then
            local dist = (pos - playerPos).Magnitude
            if not nearestDist or dist < nearestDist then
                nearestDist = dist
                nearestNode = node
                nearestPos = pos
            end
        else
            return node, pos
        end
    end
    
    if not nearestNode and anyNode then
        return anyNode, anyPos
    end
    return nearestNode, nearestPos
end

local function GetNearestMonsterInfo(maxDistance)
    if not PathTool or not PathTool.MgrMonsterClient then
        warn("[自动刷裂缝] MgrMonsterClient 未就绪")
        return nil
    end
    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        warn("[自动刷裂缝] 角色未就绪")
        return nil
    end
    local pos = hrp.Position
    local nearest, nearestDist
    local totalMonsters = 0
    
    local success, err = pcall(function()
        PathTool.MgrMonsterClient.IterMonster(function(mInfo)
            totalMonsters = totalMonsters + 1
            if mInfo and mInfo.CurrentCFrame then
                local dist = (mInfo.CurrentCFrame.Position - pos).Magnitude
                if (not maxDistance or dist <= maxDistance) and (not nearestDist or dist < nearestDist) then
                    nearestDist = dist
                    nearest = mInfo
                end
            end
            return true
        end)
    end)
    
    if not success then
        warn("[自动刷裂缝] 遍历怪物失败:", tostring(err))
        return nil
    end
    
    if nearest then
        print(string.format("[自动刷裂缝] 找到最近怪物: ID=%s, 距离=%.2f (总共检测到 %d 个怪物)", 
            tostring(nearest.MonsterId or "unknown"), nearestDist or -1, totalMonsters))
    else
        if totalMonsters > 0 then
            print(string.format("[自动刷裂缝] 检测到 %d 个怪物，但都不在范围内 (maxDistance=%s)", 
                totalMonsters, maxDistance and tostring(maxDistance) or "无限制"))
        else
            print("[自动刷裂缝] 未检测到任何怪物")
        end
    end
    
    return nearest
end

local function GetCatchEndTick()
    if not PathTool or not PathTool.MgrMonsterClient then
        return nil
    end
    local userId = player.UserId
    local endTick = nil
    PathTool.MgrMonsterClient.IterMonster(function(mInfo)
        if mInfo and mInfo.ServerNode then
            local catchEnd = mInfo.ServerNode:GetAttribute("CatchEndTick")
            if catchEnd then
                local key = "CatchPlayerId_" .. tostring(userId)
                local bySelf = mInfo.ServerNode:GetAttribute(key)
                local anySelf = false
                if bySelf then
                    anySelf = true
                else
                    for attrName, _ in mInfo.ServerNode:GetAttributes() do
                        if string.find(attrName, "CatchPlayerId_") == 1 then
                            local idStr = string.sub(attrName, 14)
                            if tonumber(idStr) == userId then
                                anySelf = true
                                break
                            end
                        end
                    end
                end
                if anySelf then
                    endTick = catchEnd
                    return false
                end
            end
        end
        return true
    end)
    return endTick
end

local function AreAllEquippedPetsDeadSimple()
    UpdateEquippedSlots()
    local slotCount = GetEquippedSlotCount()
    if slotCount <= 0 then
        return false
    end
    local deadCount = 0
    for _, slotData in pairs(equippedSlots) do
        if slotData.petInfo then
            if IsPetDead(slotData.petInfo) then
                deadCount = deadCount + 1
            end
        else
            deadCount = deadCount + 1
        end
    end
    return deadCount >= slotCount
end

local function MonitorRiftDungeon(node)
    -- 进入后等待 3 秒，让地牢怪物加载完成
    print("[自动刷裂缝] 等待 3 秒让怪物加载...")
    task.wait(3)

    -- 尝试查找怪物（多次重试，逐步放宽条件）
    local targetMonster = nil
    local teleportedToMonster = false
    
    -- 第一轮：严格距离限制（200）
    print("[自动刷裂缝] 第一轮检测怪物（距离限制 200）...")
    for attempt = 1, 20 do
        targetMonster = GetNearestMonsterInfo(200)
        if targetMonster then
            print(string.format("[自动刷裂缝] 第 %d 次尝试找到怪物", attempt))
            break
        end
        task.wait(0.2)
    end
    
    -- 第二轮：放宽距离限制（500）
    if not targetMonster then
        print("[自动刷裂缝] 第一轮未找到，第二轮检测（距离限制 500）...")
        for attempt = 1, 15 do
            targetMonster = GetNearestMonsterInfo(500)
            if targetMonster then
                print(string.format("[自动刷裂缝] 第 %d 次尝试（放宽限制）找到怪物", attempt))
                break
            end
            task.wait(0.2)
        end
    end
    
    -- 第三轮：无距离限制
    if not targetMonster then
        print("[自动刷裂缝] 第二轮未找到，第三轮检测（无距离限制）...")
        for attempt = 1, 10 do
            targetMonster = GetNearestMonsterInfo(nil)  -- 无距离限制
            if targetMonster then
                print(string.format("[自动刷裂缝] 第 %d 次尝试（无限制）找到怪物", attempt))
                break
            end
            task.wait(0.2)
        end
    end

    if not targetMonster then
        warn("[自动刷裂缝] 所有尝试后仍未找到怪物，直接退出")
        -- 未找到怪物，增加失败计数
        riftStats.failed = riftStats.failed + 1
        UpdateRiftStats()
        LeaveArena()
        -- 设置状态为recovering，触发回血流程
        riftNeedRecover = true
        healSource = "rift"  -- 标记回血来源是裂缝
        SetRiftState("recovering")
        return
    end

    print("[自动刷裂缝] 目标怪物:", targetMonster.MonsterId or "unknown")

    -- 传送到怪物位置
    if targetMonster.CurrentCFrame then
        local pos = targetMonster.CurrentCFrame.Position
        TeleportTo(pos, false, "裂缝-传送到怪物")
        teleportedToMonster = true
        task.wait(0.2)
    end

    -- 主循环：每 0.5 秒检测一次
    local nodeDisappeared = false  -- 标记节点是否已消失
    while autoRiftEnabled and riftState == "in_dungeon" do
        -- 检查节点是否消失（只检查一次）
        if not nodeDisappeared and node and not node.Parent then
            print("[自动刷裂缝] 节点已消失，检查是否有怪物...")
            nodeDisappeared = true
            task.wait(0.5)
            -- 重新检测是否有怪物（放宽限制）
            targetMonster = GetNearestMonsterInfo(500)
            if not targetMonster then
                targetMonster = GetNearestMonsterInfo(nil)  -- 无距离限制
            end
            if targetMonster then
                print("[自动刷裂缝] 节点消失但仍有怪物，继续监控怪物直到死亡")
                -- 不再检查节点，继续监控怪物
            else
                -- 没有怪物，检查是否有正在进行的捕捉
                local catchEnd = GetCatchEndTick()
                if catchEnd then
                    local now = workspace:GetServerTimeNow()
                    local waitLeft = math.max(0, catchEnd - now)
                    print(string.format("[自动刷裂缝] 节点消失，等待捕捉结束 %.1f 秒", waitLeft))
                    task.wait(math.min(waitLeft, 12))
                    exitReason = "success"  -- 节点消失但有捕捉，等待捕捉结束，算成功
                else
                    print("[自动刷裂缝] 节点消失且无怪物、无捕捉，退出")
                    exitReason = "failed"  -- 节点消失且无怪物，算失败
                end
                break
            end
        end

        -- 检查宠物是否全死
        if AreAllEquippedPetsDeadSimple() then
            print("[自动刷裂缝] 装备宠物全死，准备退出")
            exitReason = "failed"  -- 宠物全死，算失败
            break
        end

        -- 重新检测最近怪物（如果之前的目标丢失或无效）
        if not targetMonster then
            print("[自动刷裂缝] 目标丢失，重新检测怪物...")
            targetMonster = GetNearestMonsterInfo(500)  -- 放宽距离限制
            if targetMonster and targetMonster.CurrentCFrame then
                print("[自动刷裂缝] 重新找到怪物，传送到怪物位置")
                TeleportTo(targetMonster.CurrentCFrame.Position, false, "裂缝-重新传送到怪物")
                teleportedToMonster = true
                task.wait(0.2)
            else
                -- 如果放宽限制还找不到，尝试无限制
                targetMonster = GetNearestMonsterInfo(nil)
                if targetMonster and targetMonster.CurrentCFrame then
                    print("[自动刷裂缝] 无距离限制找到怪物，传送到怪物位置")
                    TeleportTo(targetMonster.CurrentCFrame.Position, false, "裂缝-重新传送到怪物")
                    teleportedToMonster = true
                    task.wait(0.2)
                end
            end
        else
            -- 验证目标怪物是否仍然有效
            local isValid = true
            pcall(function()
                if not targetMonster.CurrentCFrame then
                    isValid = false
                end
            end)
            if not isValid then
                print("[自动刷裂缝] 目标怪物无效，清除目标")
                targetMonster = nil
            end
        end

        -- 如果找到了怪物，检查其状态
        if targetMonster then
            local alive = true
            local ok, res = pcall(function()
                return targetMonster:IsAlive()
            end)
            if ok then
                alive = res
            end

            if not alive then
                -- 怪物死亡，检测捕捉状态
                print("[自动刷裂缝] 目标怪物已死亡，检测捕捉状态...")
                local startCheck = tick()
                local catchEnd = nil
                -- 持续 3 秒检测捕捉状态
                while tick() - startCheck < 3 do
                    catchEnd = GetCatchEndTick()
                    if catchEnd then
                        break
                    end
                    task.wait(0.2)
                end

                if catchEnd then
                    local now = workspace:GetServerTimeNow()
                    local waitLeft = math.max(0, catchEnd - now)
                    print(string.format("[自动刷裂缝] 检测到捕捉进行中，等待捕捉结束 %.1f 秒", waitLeft))
                    task.wait(math.min(waitLeft, 12))
                    exitReason = "success"  -- 怪物死亡并等待捕捉结束，算成功
                else
                    print("[自动刷裂缝] 目标死亡且无捕捉，退出")
                    exitReason = "success"  -- 怪物死亡（即使没有捕捉），也算成功完成地牢
                end
                break
            end

            -- 确保传送到怪物位置（如果还没传送过）
            if not teleportedToMonster and targetMonster.CurrentCFrame then
                local pos = targetMonster.CurrentCFrame.Position
                TeleportTo(pos, false, "裂缝-确保传送到怪物")
                teleportedToMonster = true
            end
        else
            -- 没有找到怪物，等待一下再检测
            task.wait(0.5)
        end

        task.wait(0.5)
    end

    -- 执行退出
    print("[自动刷裂缝] 执行退出地牢...")
    for attempt = 1, 3 do
        if LeaveArena() then
            print("[自动刷裂缝] 退出成功")
            break
        else
            warn(string.format("[自动刷裂缝] 退出尝试 %d/3 失败", attempt))
        end
        task.wait(0.3)
    end

    -- 等待直到出现在进入裂缝的位置附近（最多等待 10 秒）
    if riftEntryPosition then
        print(string.format("[自动刷裂缝] 等待回到入口位置附近: %s", tostring(riftEntryPosition)))
        local waitStart = tick()
        local maxWaitTime = 10  -- 最多等待 10 秒
        
        while (tick() - waitStart) < maxWaitTime do
            local character = player.Character
            if character and character:FindFirstChild("HumanoidRootPart") then
                local currentPos = character.HumanoidRootPart.Position
                local distance = (currentPos - riftEntryPosition).Magnitude
                
                if distance <= 50 then  -- 距离入口 50 以内认为已回到
                    print(string.format("[自动刷裂缝] ✓ 已回到入口位置附近 (距离: %.2f)", distance))
                    break
                else
                    -- 每 1 秒打印一次等待状态
                    if math.floor(tick() - waitStart) % 1 == 0 then
                        print(string.format("[自动刷裂缝] 等待回到入口位置... (当前距离: %.2f, 等待: %.1f秒)", 
                            distance, tick() - waitStart))
                    end
                end
            end
            task.wait(0.5)
        end
        
        -- 检查是否成功回到入口
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local currentPos = character.HumanoidRootPart.Position
            local distance = (currentPos - riftEntryPosition).Magnitude
            if distance > 50 then
                warn(string.format("[自动刷裂缝] ⚠ 等待超时，仍在入口外 (距离: %.2f)，继续执行回血", distance))
            end
        end
    else
        warn("[自动刷裂缝] ⚠ 未保存入口位置，直接进入回血流程")
        task.wait(2)  -- 至少等待 2 秒让退出完成
    end

    -- 根据退出原因更新统计
    if exitReason == "success" then
        riftStats.success = riftStats.success + 1
        print(string.format("[自动刷裂缝] 地牢完成（成功）统计更新: 总=%d 成功=%d 失败=%d", 
            riftStats.total, riftStats.success, riftStats.failed))
    elseif exitReason == "failed" then
        riftStats.failed = riftStats.failed + 1
        print(string.format("[自动刷裂缝] 地牢完成（失败）统计更新: 总=%d 成功=%d 失败=%d", 
            riftStats.total, riftStats.success, riftStats.failed))
    else
        -- 如果没有设置退出原因，但怪物已死亡，默认为成功
        -- 如果真的是未知原因，才标记为失败
        if exitReason == nil then
            warn("[自动刷裂缝] 未设置退出原因，默认判断为成功")
            exitReason = "success"
            riftStats.success = riftStats.success + 1
            print(string.format("[自动刷裂缝] 统计更新: 总=%d 成功=%d 失败=%d", 
                riftStats.total, riftStats.success, riftStats.failed))
        else
            riftStats.failed = riftStats.failed + 1
            warn(string.format("[自动刷裂缝] 未知退出原因: %s，统计为失败", tostring(exitReason)))
        end
    end
    
    -- 立即更新UI统计显示
    pcall(function()
        if UpdateRiftStats then
            UpdateRiftStats()
        end
    end)
    
    -- 现在设置回血标志，让回血逻辑处理后续流程
    riftNeedRecover = true
    healSource = "rift"  -- 标记回血来源是裂缝，确保回血后传送到刷怪点
    SetRiftState("recovering")
    print("[自动刷裂缝] 状态切换: in_dungeon -> recovering (等待回血)")
end

local function IsRiftActive()
    if IsRiftPresent() then
        return true
    end
    if lastRiftSeenTick > 0 and (tick() - lastRiftSeenTick) <= RIFT_GRACE_TIME then
        return true
    end
    return false
end

-- AntiAFK状态 - 从GitHub加载
local antiAFKEnabled = false

-- 从GitHub加载并启用AntiAFK
local function LoadAntiAFK()
    if antiAFKEnabled then
        return
    end
    
    local success, err = pcall(function()
        -- GitHub raw 链接
        local antiAFKUrl = "https://raw.githubusercontent.com/supleruckydior/test/refs/heads/main/SimpleAntiAFK.lua"
        local script = game:HttpGetAsync(antiAFKUrl)
        if script then
            loadstring(script)()
            antiAFKEnabled = true
            print("[防挂机] 已从GitHub加载并自动启用")
        else
            warn("[防挂机] 从GitHub加载失败: 脚本为空")
        end
    end)
    
    if not success then
        warn("[防挂机] 从GitHub加载失败:", err)
        -- 如果GitHub加载失败，使用简单的备用方法
        pcall(function()
            local idledConnection = player.Idled:Connect(function()
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end)
            antiAFKEnabled = true
            print("[防挂机] 使用备用方法（VirtualUser）")
        end)
    end
end

-- 启动时自动加载AntiAFK
task.spawn(function()
    task.wait(2)  -- 等待游戏加载完成
    LoadAntiAFK()
end)

-- 自动回血主循环
local function AutoHealLoop()
    while autoHealEnabled do
        wait(0.5) -- 每0.5秒检查一次
        
        if not autoHealEnabled then
            break
        end
        
        -- 刷裂缝优先：只在裂缝流程中时屏蔽普通自动回血
        local riftPriorityActive = autoRiftEnabled and riftState ~= "idle"

        -- 裂缝流程中且不是回血阶段，跳过普通回血逻辑
        if riftPriorityActive and riftState ~= "recovering" and not isAtRecoverPoint then
            task.wait(0.5)
            continue
        end

        -- 启动自动回血时，如果自动攻击是关闭的则先开启（仅在非回血阶段）
        if autoHealEnabled and not isAtRecoverPoint and not riftNeedRecover then
            if not GetAutoAttackState() then
                SetAutoAttackState(true)
            end
        end

        -- 先更新装备列表
        UpdateEquippedSlots()
        local slotCount = GetEquippedSlotCount()
        
        -- 需要至少3个装备的宠物（通过槽位数量判断）
        if slotCount < 3 then
            if isAtRecoverPoint then
                print("[自动回血] 装备宠物数量不足3个，停止回血")
            end
            wait(2)
        else
            -- 统计死亡和满血数量
            local deadCount = 0
            local fullHealthCount = 0
            local aliveCount = 0
            
            -- 遍历所有记录的槽位
            for slotIndex, slotData in pairs(equippedSlots) do
                if slotData.petInfo then
                    -- 宠物对象存在
                    aliveCount = aliveCount + 1
                    if IsPetDead(slotData.petInfo) then
                        deadCount = deadCount + 1
                    elseif IsPetFullHealth(slotData.petInfo) then
                        fullHealthCount = fullHealthCount + 1
                    end
                else
                    -- 宠物对象不存在，说明死亡后被移除了
                    deadCount = deadCount + 1
                end
            end
            
            -- 刷裂缝：检测“战斗结束后回血”
            if autoRiftEnabled and riftState == "recovering" and riftNeedRecover and not isAtRecoverPoint then
                local inBattle = IsInBattle()
                if inBattle then
                    -- 仍在战斗中，等待结束
                else
                    local character = player.Character
                    if character and character:FindFirstChild("HumanoidRootPart") then
                        savedPosition = character.HumanoidRootPart.Position
                        recoverPointArrivalTime = tick()
                        teleportBackAttempts = 0
                        healSource = "rift"

                        -- 关闭自动战斗（仅回血阶段关闭）
                        autoAttackWasEnabled = GetAutoAttackState()
                        if autoAttackWasEnabled then
                            SetAutoAttackState(false)
                            task.wait(0.3)
                        end

                        print("[自动刷裂缝] 战斗结束，传送回血点等待满血...")
                        local recoverPos = GetRecoverPosition()
                        if recoverPos then
                            if TeleportTo(recoverPos, true, "裂缝-去泉水") then
                                isAtRecoverPoint = true
                                riftNeedRecover = false
                                SetRiftState("recovering")
                            else
                                warn("[自动刷裂缝] TP回血点失败")
                                if autoAttackWasEnabled then
                                    SetAutoAttackState(true)
                                    autoAttackWasEnabled = false
                                end
                            end
                        else
                            warn("[自动刷裂缝] 未找到回血点")
                            if autoAttackWasEnabled then
                                SetAutoAttackState(true)
                                autoAttackWasEnabled = false
                            end
                        end
                    end
                end
            end

            -- 如果2个或以上死亡（包括已从装备状态移除的），且不在回血点，则TP到回血点
            if not riftPriorityActive and deadCount >= 2 and not isAtRecoverPoint then
                -- 检查是否在战斗状态
                local inBattle = IsInBattle()
                if inBattle then
                    -- 在战斗状态，等待战斗结束
                    if math.random() < 0.1 then  -- 每5秒打印一次（0.1 * 0.5秒间隔）
                        print("[自动回血] 检测到战斗状态，等待战斗结束后再传送...")
                    end
                else
                    -- 不在战斗状态，可以传送
                    local character = player.Character
                    if character and character:FindFirstChild("HumanoidRootPart") then
                        -- 保存当前位置
                        savedPosition = character.HumanoidRootPart.Position
                        recoverPointArrivalTime = tick()  -- 记录到达时间
                        teleportBackAttempts = 0  -- 重置回传尝试次数
                        healSource = "auto"
                        
                        -- 保存当前自动战斗状态并关闭
                        autoAttackWasEnabled = GetAutoAttackState()
                        print(string.format("[自动回血] 当前自动战斗状态: %s", tostring(autoAttackWasEnabled)))
                        
                        if autoAttackWasEnabled then
                            print("[自动回血] 检测到自动战斗已开启，先关闭自动战斗...")
                            local closeResult = SetAutoAttackState(false)
                            if closeResult then
                                print("[自动回血] ✓ 自动战斗已关闭")
                            else
                                warn("[自动回血] ✗ 关闭自动战斗失败")
                            end
                            task.wait(0.3)  -- 等待设置生效
                        else
                            print("[自动回血] 自动战斗已关闭，无需操作")
                        end
                        
                        print(string.format("[自动回血] 检测到 %d 个宠物死亡，保存位置并TP到回血点", deadCount))
                        
                        -- 获取回血点位置
                        local recoverPos = GetRecoverPosition()
                        if recoverPos then
                            if TeleportTo(recoverPos, true, "自动回血-去泉水") then
                                isAtRecoverPoint = true
                                print("[自动回血] 已TP到回血点，等待宠物回血...")
                            else
                                warn("[自动回血] TP失败")
                                -- TP失败，恢复自动战斗状态
                                if autoAttackWasEnabled then
                                    SetAutoAttackState(true)
                                    autoAttackWasEnabled = false
                                end
                            end
                        else
                            warn("[自动回血] 未找到回血点")
                            -- 未找到回血点，恢复自动战斗状态
                            if autoAttackWasEnabled then
                                SetAutoAttackState(true)
                                autoAttackWasEnabled = false
                            end
                        end
                    end
                end
            end
            
            -- 在回血点的处理逻辑
            if isAtRecoverPoint then
                local currentTime = tick()
                local waitTime = recoverPointArrivalTime and (currentTime - recoverPointArrivalTime) or 0
                
                -- 检查是否超时（超过最大等待时间）
                local isTimeout = waitTime > MAX_RECOVER_WAIT_TIME
                
                -- 检查是否满足回传条件
                -- 条件1：所有宠物都满血且没有死亡的（严格条件）
                local allFullHealth = fullHealthCount >= slotCount and deadCount == 0
                if autoRiftEnabled and healSource == "rift" then
                    -- 刷裂缝：只认 3 个宠物全部满血
                    allFullHealth = fullHealthCount >= 3 and deadCount == 0
                end
                -- 条件2：至少大部分宠物满血且没有死亡的（宽松条件）
                local mostFullHealth = fullHealthCount >= math.max(1, slotCount - 1) and deadCount == 0
                -- 条件3：至少没有死亡的宠物（最宽松条件）
                local noDeadPets = deadCount == 0
                
                -- 决定是否回传
                local shouldTeleportBack = false
                local reason = ""
                
                if allFullHealth then
                    shouldTeleportBack = true
                    reason = "所有宠物已满血"
                elseif mostFullHealth and waitTime > 30 then
                    -- 等待30秒后，如果大部分宠物满血，也回传
                    shouldTeleportBack = true
                    reason = "大部分宠物已满血（等待30秒后）"
                elseif noDeadPets and waitTime > 60 then
                    -- 等待60秒后，如果没有死亡的宠物，也回传
                    shouldTeleportBack = true
                    reason = "没有死亡的宠物（等待60秒后）"
                elseif isTimeout then
                    -- 超时强制回传
                    shouldTeleportBack = true
                    reason = string.format("超时强制回传（已等待 %.1f 秒）", waitTime)
                end
                
                if shouldTeleportBack then
                    -- 裂缝回血：直接传送到刷怪点，不需要传回原位置
                    if autoRiftEnabled and riftState == "recovering" and healSource == "rift" then
                        if farmingPosition then
                            print(string.format("[自动刷裂缝] %s，直接传送到刷怪点（等待时间: %.1f秒）", reason, waitTime))
                            task.wait(0.3)
                            local farmingSuccess = TeleportTo(farmingPosition, true, "裂缝-回刷怪点")
                            if farmingSuccess then
                                print("[自动刷裂缝] ✓ 已传送到刷怪点，准备下一次循环")
                            else
                                warn("[自动刷裂缝] ⚠ 传送到刷怪点失败")
                            end
                            
                            -- 恢复自动战斗状态
                            if autoAttackWasEnabled then
                                task.wait(0.3)
                                SetAutoAttackState(true)
                                autoAttackWasEnabled = false
                            end
                            
                            isAtRecoverPoint = false
                            savedPosition = nil
                            recoverPointArrivalTime = nil
                            teleportBackAttempts = 0
                            riftEntryPosition = nil
                            healSource = nil
                            
                            -- 等待传送完成并稳定
                            task.wait(1.0)
                            
                            -- 再次确认所有宠物都满血（防止在传送过程中血量变化）
                            UpdateEquippedSlots()
                            local slotCount = GetEquippedSlotCount()
                            local verifyDeadCount = 0
                            local verifyFullHealthCount = 0
                            for _, slotData in pairs(equippedSlots) do
                                if slotData.petInfo then
                                    if IsPetDead(slotData.petInfo) then
                                        verifyDeadCount = verifyDeadCount + 1
                                    elseif IsPetFullHealth(slotData.petInfo) then
                                        verifyFullHealthCount = verifyFullHealthCount + 1
                                    end
                                else
                                    verifyDeadCount = verifyDeadCount + 1
                                end
                            end
                            local verifyFullHealth = verifyFullHealthCount >= 3 and verifyDeadCount == 0
                            if verifyFullHealth then
                                print("[自动刷裂缝] ✓ 回血完成，所有宠物已满血，准备下一次循环")
                                riftNeedRecover = false
                                SetRiftState("idle")
                            else
                                warn(string.format("[自动刷裂缝] ⚠ 回血验证失败：满血数=%d，死亡数=%d，继续等待回血", verifyFullHealthCount, verifyDeadCount))
                                -- 回血验证失败，重新设置回血状态
                                riftNeedRecover = true
                                SetRiftState("recovering")
                                -- 重新传送到回血点
                                local recoverPos = GetRecoverPosition()
                                if recoverPos then
                                    TeleportTo(recoverPos, true, "裂缝-回血验证失败-重新回血")
                                    isAtRecoverPoint = true
                                    recoverPointArrivalTime = tick()
                                end
                            end
                        else
                            warn("[自动刷裂缝] ⚠ 未设置刷怪点，请先点击'记录刷怪点'按钮")
                            -- 未设置刷怪点，清除状态避免卡住
                            isAtRecoverPoint = false
                            savedPosition = nil
                            recoverPointArrivalTime = nil
                            teleportBackAttempts = 0
                            riftEntryPosition = nil
                            healSource = nil
                            
                            -- 等待传送完成并稳定
                            task.wait(1.0)
                            
                            -- 再次确认所有宠物都满血（防止在传送过程中血量变化）
                            UpdateEquippedSlots()
                            local slotCount = GetEquippedSlotCount()
                            local verifyDeadCount = 0
                            local verifyFullHealthCount = 0
                            for _, slotData in pairs(equippedSlots) do
                                if slotData.petInfo then
                                    if IsPetDead(slotData.petInfo) then
                                        verifyDeadCount = verifyDeadCount + 1
                                    elseif IsPetFullHealth(slotData.petInfo) then
                                        verifyFullHealthCount = verifyFullHealthCount + 1
                                    end
                                else
                                    verifyDeadCount = verifyDeadCount + 1
                                end
                            end
                            local verifyFullHealth = verifyFullHealthCount >= 3 and verifyDeadCount == 0
                            if verifyFullHealth then
                                print("[自动刷裂缝] ✓ 回血完成，所有宠物已满血，准备下一次循环")
                                riftNeedRecover = false
                                SetRiftState("idle")
                            else
                                warn(string.format("[自动刷裂缝] ⚠ 回血验证失败：满血数=%d，死亡数=%d，继续等待回血", verifyFullHealthCount, verifyDeadCount))
                                -- 回血验证失败，重新设置回血状态
                                riftNeedRecover = true
                                SetRiftState("recovering")
                                -- 重新传送到回血点
                                local recoverPos = GetRecoverPosition()
                                if recoverPos then
                                    TeleportTo(recoverPos, true, "裂缝-回血验证失败-重新回血")
                                    isAtRecoverPoint = true
                                    recoverPointArrivalTime = tick()
                                end
                            end
                        end
                    elseif savedPosition then
                        -- 普通回血：优先使用刷怪点，否则传回原位置
                        local targetPos = farmingPosition or savedPosition
                        local targetName = farmingPosition and "刷怪点" or "原位置"
                        print(string.format("[自动回血] %s，TP到%s（等待时间: %.1f秒）", reason, targetName, waitTime))
                        
                        -- 获取当前回血点位置，用于验证是否还在回血点
                        local recoverPos = GetRecoverPosition()
                        local character = player.Character
                        local currentPos = character and character:FindFirstChild("HumanoidRootPart") and character.HumanoidRootPart.Position
                        
                        if currentPos and recoverPos then
                            local distanceToRecover = (currentPos - recoverPos).Magnitude
                            print(string.format("[自动回血] 当前位置到回血点距离: %.2f", distanceToRecover))
                        end
                        
                        -- 尝试回传（启用位置验证）
                        local success = TeleportTo(targetPos, true, farmingPosition and "回血完成-回刷怪点" or "回血完成-回原位")
                        
                        if success then
                            -- 再次验证位置，确保真的离开了回血点
                            task.wait(0.5)
                            local verifyCharacter = player.Character
                            local verifyPos = verifyCharacter and verifyCharacter:FindFirstChild("HumanoidRootPart") and verifyCharacter.HumanoidRootPart.Position
                            
                            if verifyPos and recoverPos then
                                local finalDistanceToRecover = (verifyPos - recoverPos).Magnitude
                                local distanceToTarget = (verifyPos - targetPos).Magnitude
                                
                                -- 如果还在回血点附近（距离小于20），说明TP失败
                                if finalDistanceToRecover < 20 then
                                    teleportBackAttempts = teleportBackAttempts + 1
                                    warn(string.format("[自动回血] ⚠ TP后仍在回血点附近（距离=%.2f），尝试次数: %d", finalDistanceToRecover, teleportBackAttempts))
                                    
                                    -- 如果多次失败，尝试强制TP
                                    if teleportBackAttempts >= 3 then
                                        warn("[自动回血] ⚠ 多次TP失败，尝试强制TP...")
                                        for i = 1, 3 do
                                            pcall(function()
                                                verifyCharacter.HumanoidRootPart.CFrame = CFrame.new(targetPos)
                                            end)
                                            task.wait(0.2)
                                        end
                                        
                                        task.wait(0.5)
                                        local finalVerifyPos = verifyCharacter.HumanoidRootPart.Position
                                        local finalDistance = (finalVerifyPos - recoverPos).Magnitude
                                        
                                        if finalDistance < 20 then
                                            warn("[自动回血] ⚠ 强制TP后仍在回血点，清除状态")
                                            isAtRecoverPoint = false
                                            savedPosition = nil
                                            recoverPointArrivalTime = nil
                                            teleportBackAttempts = 0
                                        else
                                            print(string.format("[自动回血] ✓ 强制TP成功，距离回血点: %.2f", finalDistance))
                                            isAtRecoverPoint = false
                                            savedPosition = nil
                                            recoverPointArrivalTime = nil
                                            teleportBackAttempts = 0
                                        end
                                    end
                                else
                                    -- TP成功，离开回血点
                                    local distanceToTarget = (verifyPos - targetPos).Magnitude
                                    print(string.format("[自动回血] ✓ 已TP到%s（距离回血点: %.2f, 距离目标位置: %.2f）", 
                                        targetName, finalDistanceToRecover, distanceToTarget))
                                    
                                    -- 恢复自动战斗状态
                                    if autoAttackWasEnabled then
                                        task.wait(0.3)  -- 等待TP稳定
                                        SetAutoAttackState(true)
                                        autoAttackWasEnabled = false
                                    end
                                    
                                    isAtRecoverPoint = false
                                    savedPosition = nil
                                    recoverPointArrivalTime = nil
                                    teleportBackAttempts = 0
                                    
                                    -- 裂缝回血：传送到刷怪点，然后重置状态
                                    if autoRiftEnabled and riftState == "recovering" and healSource == "rift" then
                                        if farmingPosition then
                                            print(string.format("[自动刷裂缝] 回血完成，传送到刷怪点: %s", tostring(farmingPosition)))
                                            task.wait(0.5)  -- 等待回传稳定
                                            local farmingSuccess = TeleportTo(farmingPosition, true, "裂缝-回刷怪点")
                                            if farmingSuccess then
                                                print("[自动刷裂缝] ✓ 已传送到刷怪点，准备下一次循环")
                                            else
                                                warn("[自动刷裂缝] ⚠ 传送到刷怪点失败")
                                            end
                                        else
                                            warn("[自动刷裂缝] ⚠ 未设置刷怪点，请先点击'记录刷怪点'按钮")
                                        end
                                        -- 清除裂缝相关状态，准备下一次循环
                                        riftEntryPosition = nil
                                        riftNeedRecover = false
                                        healSource = nil
                                        task.wait(0.5)
                                        SetRiftState("idle")
                                    else
                                        healSource = nil
                                    end
                                end
                            else
                                -- 无法验证，假设成功
                                print(string.format("[自动回血] ✓ 已TP到%s（无法验证）", targetName))
                                
                                -- 恢复自动战斗状态
                                if autoAttackWasEnabled then
                                    task.wait(0.3)  -- 等待TP稳定
                                    SetAutoAttackState(true)
                                    autoAttackWasEnabled = false
                                end
                                
                                isAtRecoverPoint = false
                                savedPosition = nil
                                recoverPointArrivalTime = nil
                                teleportBackAttempts = 0
                                
                                -- 裂缝回血：传送到刷怪点，然后重置状态
                                if autoRiftEnabled and riftState == "recovering" and healSource == "rift" then
                                    if farmingPosition then
                                        print(string.format("[自动刷裂缝] 回血完成，传送到刷怪点: %s", tostring(farmingPosition)))
                                        task.wait(0.5)  -- 等待回传稳定
                                        local farmingSuccess = TeleportTo(farmingPosition, true, "裂缝-回刷怪点")
                                        if farmingSuccess then
                                            print("[自动刷裂缝] ✓ 已传送到刷怪点，准备下一次循环")
                                        else
                                            warn("[自动刷裂缝] ⚠ 传送到刷怪点失败")
                                        end
                                    else
                                        warn("[自动刷裂缝] ⚠ 未设置刷怪点，请先点击'记录刷怪点'按钮")
                                    end
                                    -- 清除裂缝相关状态，准备下一次循环
                                    riftEntryPosition = nil
                                    riftNeedRecover = false
                                    healSource = nil
                                    task.wait(0.5)
                                    SetRiftState("idle")
                                else
                                    healSource = nil
                                end
                            end
                        else
                            teleportBackAttempts = teleportBackAttempts + 1
                            warn(string.format("[自动回血] TP到%s失败（尝试次数: %d）", targetName, teleportBackAttempts))
                            
                            -- 如果多次失败，清除状态，避免卡住
                            if teleportBackAttempts >= 5 then
                                warn("[自动回血] ⚠ 多次TP失败，清除回血点状态")
                                
                                -- 恢复自动战斗状态
                                if autoAttackWasEnabled then
                                    SetAutoAttackState(true)
                                    autoAttackWasEnabled = false
                                end
                                
                                isAtRecoverPoint = false
                                savedPosition = nil
                                recoverPointArrivalTime = nil
                                teleportBackAttempts = 0
                                
                                -- 裂缝回血：清除裂缝相关状态
                                if autoRiftEnabled and riftState == "recovering" and healSource == "rift" then
                                    riftEntryPosition = nil
                                    riftNeedRecover = false
                                    healSource = nil
                                    SetRiftState("idle")
                                else
                                    healSource = nil
                                end
                            end
                        end
                    else
                        -- 如果没有保存位置，只是离开回血点
                        warn("[自动回血] ⚠ 所有宠物已满血，但未保存原位置，离开回血点")
                        
                        -- 恢复自动战斗状态
                        if autoAttackWasEnabled then
                            SetAutoAttackState(true)
                            autoAttackWasEnabled = false
                        end
                        
                        isAtRecoverPoint = false
                        recoverPointArrivalTime = nil
                        teleportBackAttempts = 0
                        
                        -- 裂缝回血：清除裂缝相关状态
                        if autoRiftEnabled and riftState == "recovering" and healSource == "rift" then
                            riftEntryPosition = nil
                            riftNeedRecover = false
                            healSource = nil
                            SetRiftState("idle")
                        else
                            healSource = nil
                        end
                    end
                else
                    -- 显示等待状态
                    if waitTime > 10 and waitTime % 10 < 0.5 then
                        print(string.format("[自动回血] 等待回血中... (已等待 %.0f秒, 满血: %d/%d, 死亡: %d)", 
                            waitTime, fullHealthCount, slotCount, deadCount))
                    end
                end
            end
        end
    end
end

-- 更新裂缝统计显示函数（全局函数）
local function UpdateRiftStats()
    if riftStatsLabel then
        local successText = string.format("成功:%d", riftStats.success)
        local failedText = string.format("失败:%d", riftStats.failed)
        local totalText = string.format("总:%d", riftStats.total)
        local newText = string.format("裂缝统计: %s %s %s", totalText, successText, failedText)
        riftStatsLabel.Text = newText
        print(string.format("[统计更新] %s", newText))
    else
        warn("[统计更新] riftStatsLabel 未找到，无法更新UI")
    end
end

-- 创建UI
local function CreateUI()
    -- 删除已存在的UI
    local existingUI = player.PlayerGui:FindFirstChild("PetCaptureUI")
    if existingUI then
        existingUI:Destroy()
    end
    
    -- 创建主界面
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "PetCaptureUI"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = player.PlayerGui
    
    -- 主窗口
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 300, 0, 410)
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -205)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- 圆角
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    -- 标题栏
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 35)
    titleBar.Position = UDim2.new(0, 0, 0, 0)
    titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 8)
    titleCorner.Parent = titleBar
    
    -- 标题文字
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -40, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "捕捉宠物 - 自动回血"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 16
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    -- 关闭按钮
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 2)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeButton.Text = "×"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 20
    closeButton.BorderSizePixel = 0
    closeButton.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton
    
    closeButton.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    -- 内容区域
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -20, 1, -55)
    contentFrame.Position = UDim2.new(0, 10, 0, 45)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    
    -- 自动回血开关
    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "ToggleButton"
    toggleButton.Size = UDim2.new(1, 0, 0, 50)
    toggleButton.Position = UDim2.new(0, 0, 0, 0)
    toggleButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
    toggleButton.Text = "自动回血: OFF"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Font = Enum.Font.Gotham
    toggleButton.TextSize = 18
    toggleButton.BorderSizePixel = 0
    toggleButton.Parent = contentFrame
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 6)
    toggleCorner.Parent = toggleButton

    -- 自动刷裂缝开关
    local autoRiftButton = Instance.new("TextButton")
    autoRiftButton.Name = "AutoRiftButton"
    autoRiftButton.Size = UDim2.new(1, 0, 0, 40)
    autoRiftButton.Position = UDim2.new(0, 0, 0, 110)
    autoRiftButton.BackgroundColor3 = Color3.fromRGB(60, 50, 80)
    autoRiftButton.Text = "自动刷裂缝: OFF"
    autoRiftButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoRiftButton.Font = Enum.Font.Gotham
    autoRiftButton.TextSize = 16
    autoRiftButton.BorderSizePixel = 0
    autoRiftButton.Parent = contentFrame

    local autoRiftCorner = Instance.new("UICorner")
    autoRiftCorner.CornerRadius = UDim.new(0, 6)
    autoRiftCorner.Parent = autoRiftButton

    -- 自动合成开关
    local autoEvolveButton = Instance.new("TextButton")
    autoEvolveButton.Name = "AutoEvolveButton"
    autoEvolveButton.Size = UDim2.new(1, 0, 0, 40)
    autoEvolveButton.Position = UDim2.new(0, 0, 0, 160)
    autoEvolveButton.BackgroundColor3 = Color3.fromRGB(80, 60, 20)
    autoEvolveButton.Text = "自动合成: OFF"
    autoEvolveButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoEvolveButton.Font = Enum.Font.Gotham
    autoEvolveButton.TextSize = 16
    autoEvolveButton.BorderSizePixel = 0
    autoEvolveButton.Parent = contentFrame

    local autoEvolveCorner = Instance.new("UICorner")
    autoEvolveCorner.CornerRadius = UDim.new(0, 6)
    autoEvolveCorner.Parent = autoEvolveButton
    
    -- AntiAFK开关
    local antiAFKButton = Instance.new("TextButton")
    antiAFKButton.Name = "AntiAFKButton"
    antiAFKButton.Size = UDim2.new(1, 0, 0, 40)
    antiAFKButton.Position = UDim2.new(0, 0, 0, 210)
    antiAFKButton.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
    antiAFKButton.Text = "防挂机: OFF"
    antiAFKButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    antiAFKButton.Font = Enum.Font.Gotham
    antiAFKButton.TextSize = 16
    antiAFKButton.BorderSizePixel = 0
    antiAFKButton.Parent = contentFrame
    
    local antiAFKCorner = Instance.new("UICorner")
    antiAFKCorner.CornerRadius = UDim.new(0, 6)
    antiAFKCorner.Parent = antiAFKButton
    
    -- AntiAFK按钮点击事件（重新加载）
    antiAFKButton.MouseButton1Click:Connect(function()
        if antiAFKEnabled then
            antiAFKButton.Text = "防挂机: 已启用"
            antiAFKButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
            print("[防挂机] AntiAFK已启用（从GitHub加载）")
        else
            LoadAntiAFK()
            antiAFKButton.Text = antiAFKEnabled and "防挂机: ON" or "防挂机: OFF"
            antiAFKButton.BackgroundColor3 = antiAFKEnabled and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(40, 40, 80)
        end
    end)
    
    -- 初始化按钮状态
    task.spawn(function()
        task.wait(3)
        antiAFKButton.Text = antiAFKEnabled and "防挂机: ON" or "防挂机: OFF"
        antiAFKButton.BackgroundColor3 = antiAFKEnabled and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(40, 40, 80)
    end)

    -- 记录刷怪点按钮
    local recordFarmingButton = Instance.new("TextButton")
    recordFarmingButton.Name = "RecordFarmingButton"
    recordFarmingButton.Size = UDim2.new(1, 0, 0, 40)
    recordFarmingButton.Position = UDim2.new(0, 0, 0, 260)
    recordFarmingButton.BackgroundColor3 = Color3.fromRGB(60, 80, 60)
    recordFarmingButton.Text = "记录刷怪点: 未设置"
    recordFarmingButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    recordFarmingButton.Font = Enum.Font.Gotham
    recordFarmingButton.TextSize = 16
    recordFarmingButton.BorderSizePixel = 0
    recordFarmingButton.Parent = contentFrame

    local recordFarmingCorner = Instance.new("UICorner")
    recordFarmingCorner.CornerRadius = UDim.new(0, 6)
    recordFarmingCorner.Parent = recordFarmingButton

    -- 记录刷怪点按钮点击事件
    recordFarmingButton.MouseButton1Click:Connect(function()
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            farmingPosition = character.HumanoidRootPart.Position
            recordFarmingButton.Text = string.format("记录刷怪点: %.0f,%.0f,%.0f", 
                farmingPosition.X, farmingPosition.Y, farmingPosition.Z)
            recordFarmingButton.BackgroundColor3 = Color3.fromRGB(40, 100, 40)
            print(string.format("[记录刷怪点] 已记录当前位置: %s", tostring(farmingPosition)))
        else
            warn("[记录刷怪点] 角色未就绪")
        end
    end)

    -- 如果已有刷怪点，更新按钮显示
    if farmingPosition then
        recordFarmingButton.Text = string.format("记录刷怪点: %.0f,%.0f,%.0f", 
            farmingPosition.X, farmingPosition.Y, farmingPosition.Z)
        recordFarmingButton.BackgroundColor3 = Color3.fromRGB(40, 100, 40)
    end
    
    -- 传送到刷怪点按钮
    local teleportToFarmingButton = Instance.new("TextButton")
    teleportToFarmingButton.Name = "TeleportToFarmingButton"
    teleportToFarmingButton.Size = UDim2.new(1, 0, 0, 40)
    teleportToFarmingButton.Position = UDim2.new(0, 0, 0, 310)
    teleportToFarmingButton.BackgroundColor3 = Color3.fromRGB(80, 60, 60)
    teleportToFarmingButton.Text = "传送到刷怪点"
    teleportToFarmingButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    teleportToFarmingButton.Font = Enum.Font.Gotham
    teleportToFarmingButton.TextSize = 16
    teleportToFarmingButton.BorderSizePixel = 0
    teleportToFarmingButton.Parent = contentFrame
    
    local teleportToFarmingCorner = Instance.new("UICorner")
    teleportToFarmingCorner.CornerRadius = UDim.new(0, 6)
    teleportToFarmingCorner.Parent = teleportToFarmingButton
    
    -- 传送到刷怪点按钮点击事件
    teleportToFarmingButton.MouseButton1Click:Connect(function()
        if farmingPosition then
            print(string.format("[传送到刷怪点] 开始传送: %s", tostring(farmingPosition)))
            local success = TeleportTo(farmingPosition, true, "手动传送到刷怪点")
            if success then
                print("[传送到刷怪点] ✓ 传送成功")
            else
                warn("[传送到刷怪点] ✗ 传送失败")
            end
        else
            warn("[传送到刷怪点] ⚠ 未设置刷怪点，请先点击'记录刷怪点'按钮")
        end
    end)

    -- 裂缝统计显示标签
    riftStatsLabel = Instance.new("TextLabel")
    riftStatsLabel.Name = "RiftStatsLabel"
    riftStatsLabel.Size = UDim2.new(1, 0, 0, 50)
    riftStatsLabel.Position = UDim2.new(0, 0, 0, 360)
    riftStatsLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    riftStatsLabel.BorderSizePixel = 0
    riftStatsLabel.Text = "裂缝统计: 总:0 成功:0 失败:0"
    riftStatsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    riftStatsLabel.Font = Enum.Font.Gotham
    riftStatsLabel.TextSize = 14
    riftStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
    riftStatsLabel.TextWrapped = true
    riftStatsLabel.Parent = contentFrame

    local riftStatsCorner = Instance.new("UICorner")
    riftStatsCorner.CornerRadius = UDim.new(0, 6)
    riftStatsCorner.Parent = riftStatsLabel

    -- 重新定义UpdateRiftStats函数，确保能访问到riftStatsLabel
    UpdateRiftStats = function()
        if riftStatsLabel then
            local successText = string.format("成功:%d", riftStats.success)
            local failedText = string.format("失败:%d", riftStats.failed)
            local totalText = string.format("总:%d", riftStats.total)
            local newText = string.format("裂缝统计: %s %s %s", totalText, successText, failedText)
            riftStatsLabel.Text = newText
            print(string.format("[统计更新] %s", newText))
        else
            warn("[统计更新] riftStatsLabel 未找到，无法更新UI")
        end
    end

    -- 初始化统计显示
    UpdateRiftStats()

    -- 自动刷裂缝循环
    local function AutoRiftLoop()
        if autoRiftRunning then
            return
        end
        autoRiftRunning = true
        riftWasInBattle = nil
        while autoRiftEnabled do
            if not IsRiftActive() then
                riftWasInBattle = nil
                -- 如果正在回血中，不要清除回血状态
                if riftState ~= "recovering" then
                    riftNeedRecover = false
                end
                -- 如果正在地牢中（MonitorRiftDungeon运行中），不要修改状态
                -- 如果正在回血中，也不要修改状态
                if riftState ~= "idle" and riftState ~= "in_dungeon" and riftState ~= "recovering" and not isAtRecoverPoint then
                    SetRiftState("idle")
                end
                task.wait(0.5)
            else
            -- 发现裂缝时尝试进入
            if riftState == "idle" and not IsInBattle() and not isAtRecoverPoint and not riftNeedRecover then
                if (tick() - lastRiftEnterTick) >= RIFT_ENTER_COOLDOWN then
                    -- 优先获取未进入的裂缝节点（跳过已进入的）
                    local node, pos = getRiftNodeAndPos(true)
                    if not node or not pos then
                        -- 没有找到可用的裂缝节点，等待一段时间
                        task.wait(1)
                        continue
                    end
                    
                    -- 双重检查：确保节点未进入（防止getRiftNodeAndPos的fallback返回已进入的节点）
                    local isEntered = alreadyEnteredDungeon(node)
                    if isEntered then
                        print(string.format("[自动刷裂缝] 节点 %s 已进入过（参数检查），跳过", node.Name))
                        lastRiftEnterTick = tick()
                        task.wait(2)  -- 增加等待时间，避免频繁检查
                        continue
                    end
                    
                    -- 注意：失败冷却检查已在 getRiftNodeAndPos 中处理，这里不需要再次检查
                    
                    -- 找到未进入的裂缝，开始进入流程
                    lastRiftEnterTick = tick()
                    SetRiftState("entering")
                    print(string.format("[自动刷裂缝] 发现裂缝: %s，尝试传送进入", node.Name))
                    TeleportTo(pos + Vector3.new(0, 3, 0), true, "裂缝-进入")
                    task.wait(0.5)  -- 等待传送完成
                    
                    -- 传送到裂缝后记录入口位置（裂缝位置）
                    local character = player.Character
                    if character and character:FindFirstChild("HumanoidRootPart") then
                        riftEntryPosition = character.HumanoidRootPart.Position
                        print(string.format("[自动刷裂缝] 已传送到裂缝，记录入口位置: %s", tostring(riftEntryPosition)))
                    else
                        -- 如果角色未就绪，使用裂缝位置作为入口位置
                        riftEntryPosition = pos
                        print(string.format("[自动刷裂缝] 使用裂缝位置作为入口位置: %s", tostring(riftEntryPosition)))
                    end
                    
                    task.wait(0.3)
                    if TryOpenDungeonTeamView(node) then
                        print("[自动刷裂缝] 已尝试打开裂缝界面")
                    end
                    if TryCreateAndStartDungeon(node) then
                        print("[自动刷裂缝] 已尝试创建并进入裂缝")
                        -- 增加总计数
                        riftStats.total = riftStats.total + 1
                        
                        -- 等待一下确保地牢已进入
                        task.wait(0.5)
                        
                        -- 关闭地牢队伍界面
                        local closeOk, closeErr = pcall(function()
                            if PathTool and PathTool.ViewManager then
                                PathTool.ViewManager.CloseView("DungeonTeamView")
                                print("[自动刷裂缝] 已关闭地牢队伍界面")
                            end
                        end)
                        if not closeOk then
                            warn("[自动刷裂缝] 关闭地牢队伍界面失败: " .. tostring(closeErr))
                        end
                        
                        SetRiftState("in_dungeon")
                        riftWasInBattle = nil
                        
                        -- 进入地下城后，如果自动攻击未开启，则开启
                        task.wait(0.5)  -- 等待地牢完全加载
                        local currentAutoAttack = GetAutoAttackState()
                        if not currentAutoAttack then
                            print("[自动刷裂缝] 检测到自动攻击未开启，正在开启...")
                            local enableResult = SetAutoAttackState(true)
                            if enableResult then
                                print("[自动刷裂缝] ✓ 已开启自动攻击")
                            else
                                warn("[自动刷裂缝] ⚠ 开启自动攻击失败")
                            end
                        else
                            print("[自动刷裂缝] 自动攻击已开启，无需操作")
                        end
                        
                        spawn(function()
                            MonitorRiftDungeon(node)
                        end)
                        -- 更新统计UI
                        pcall(function()
                            if UpdateRiftStats then
                                UpdateRiftStats()
                            end
                        end)
                    else
                        warn("[自动刷裂缝] 创建/进入失败")
                        -- 增加总计数和失败计数
                        riftStats.total = riftStats.total + 1
                        riftStats.failed = riftStats.failed + 1
                        -- 记录失败的节点，避免短时间内重复尝试
                        local nodeKey = tostring(node)
                        failedRiftNodes[nodeKey] = tick()
                        print(string.format("[自动刷裂缝] 节点 %s 进入失败，已加入冷却列表（%d 秒）", node.Name, FAILED_RIFT_COOLDOWN))
                        -- 清理过期的失败记录
                        for key, time in pairs(failedRiftNodes) do
                            if (tick() - time) >= FAILED_RIFT_COOLDOWN then
                                failedRiftNodes[key] = nil
                            end
                        end
                        -- 创建/进入失败时也尝试关闭界面
                        task.wait(0.3)
                        pcall(function()
                            if PathTool and PathTool.ViewManager then
                                PathTool.ViewManager.CloseView("DungeonTeamView")
                                print("[自动刷裂缝] 已关闭地牢队伍界面（失败时）")
                            end
                        end)
                        -- 失败后传送回刷怪点，防止卡死
                        if farmingPosition then
                            print(string.format("[自动刷裂缝] 进入失败，传送回刷怪点: %s", tostring(farmingPosition)))
                            task.wait(0.5)  -- 等待界面关闭
                            local farmingSuccess = TeleportTo(farmingPosition, true, "裂缝失败-回刷怪点")
                            if farmingSuccess then
                                print("[自动刷裂缝] ✓ 已传送回刷怪点")
                            else
                                warn("[自动刷裂缝] ⚠ 传送回刷怪点失败")
                            end
                        else
                            warn("[自动刷裂缝] ⚠ 未设置刷怪点，无法传送回刷怪点")
                        end
                        SetRiftState("idle")
                        -- 更新统计UI
                        pcall(function()
                            if UpdateRiftStats then
                                UpdateRiftStats()
                            end
                        end)
                    end
                end
            end
            -- 战斗结束逻辑由 MonitorRiftDungeon 统一处理
            task.wait(0.5)
            end
        end
        autoRiftRunning = false
    end

    -- 自动刷裂缝按钮点击事件
    autoRiftButton.MouseButton1Click:Connect(function()
        autoRiftEnabled = not autoRiftEnabled
        if autoRiftEnabled then
            autoRiftButton.Text = "自动刷裂缝: ON"
            autoRiftButton.BackgroundColor3 = Color3.fromRGB(80, 70, 120)
            riftNeedRecover = false
            riftWasInBattle = nil
            print("[自动刷裂缝] 已启用")

            -- 刷裂缝优先，确保自动回血循环运行
            if not autoHealEnabled then
                autoHealEnabled = true
                autoHealForcedByRift = true
                toggleButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
                toggleButton.Text = "自动回血: ON"
                print("[自动回血] 已启用（刷裂缝优先）")
                spawn(AutoHealLoop)
            end

            spawn(AutoRiftLoop)
        else
            autoRiftButton.Text = "自动刷裂缝: OFF"
            autoRiftButton.BackgroundColor3 = Color3.fromRGB(60, 50, 80)
            riftNeedRecover = false
            riftWasInBattle = nil
            print("[自动刷裂缝] 已禁用")

            if autoHealForcedByRift then
                autoHealForcedByRift = false
                autoHealEnabled = false
                toggleButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
                toggleButton.Text = "自动回血: OFF"
                print("[自动回血] 已禁用（刷裂缝关闭）")
            end
        end
    end)

    -- 自动合成按钮点击事件
    autoEvolveButton.MouseButton1Click:Connect(function()
        autoEvolveEnabled = not autoEvolveEnabled
        if autoEvolveEnabled then
            autoEvolveButton.Text = "自动合成: ON"
            autoEvolveButton.BackgroundColor3 = Color3.fromRGB(80, 120, 40)
            spawn(AutoEvolveLoop)
        else
            autoEvolveButton.Text = "自动合成: OFF"
            autoEvolveButton.BackgroundColor3 = Color3.fromRGB(80, 60, 20)
        end
    end)
    
    -- 状态显示
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, 0, 0, 40)
    statusLabel.Position = UDim2.new(0, 0, 0, 60)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "状态: 等待中..."
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 14
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.TextWrapped = true
    statusLabel.Parent = contentFrame
    
    -- 宠物状态显示
    local petStatusLabel = Instance.new("TextLabel")
    petStatusLabel.Name = "PetStatusLabel"
    petStatusLabel.Size = UDim2.new(1, 0, 0, 50)
    petStatusLabel.Position = UDim2.new(0, 0, 0, 260)
    petStatusLabel.BackgroundTransparency = 1
    petStatusLabel.Text = "宠物状态: 检测中..."
    petStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    petStatusLabel.Font = Enum.Font.Gotham
    petStatusLabel.TextSize = 12
    petStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    petStatusLabel.TextWrapped = true
    petStatusLabel.Parent = contentFrame
    
    -- 更新状态显示
    local function UpdateStatus()
        if not screenGui.Parent then
            return
        end
        
        -- 更新装备列表
        UpdateEquippedSlots()
        local slotCount = GetEquippedSlotCount()
        
        -- 统计死亡和满血数量
        local deadCount = 0
        local fullHealthCount = 0
        local aliveCount = 0
        
        -- 遍历所有记录的槽位
        for slotIndex, slotData in pairs(equippedSlots) do
            if slotData.petInfo then
                -- 宠物对象存在
                aliveCount = aliveCount + 1
                if IsPetDead(slotData.petInfo) then
                    deadCount = deadCount + 1
                elseif IsPetFullHealth(slotData.petInfo) then
                    fullHealthCount = fullHealthCount + 1
                end
            else
                -- 宠物对象不存在，说明死亡后被移除了
                deadCount = deadCount + 1
            end
        end
        
        -- 更新宠物状态显示（包括死亡的）
        if slotCount >= 3 then
            petStatusLabel.Text = string.format("装备宠物: %d个 | 存活: %d个 | 死亡: %d个 | 满血: %d个", slotCount, aliveCount, deadCount, fullHealthCount)
        else
            petStatusLabel.Text = string.format("装备宠物: %d个 (需要3个)", slotCount)
        end
        
        -- 更新主状态
        if isAtRecoverPoint then
            statusLabel.Text = "状态: 正在回血点等待..."
            statusLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
        elseif autoHealEnabled then
            statusLabel.Text = "状态: 监控中..."
            statusLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
        else
            statusLabel.Text = "状态: 已停止"
            statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        end
    end
    
    -- 状态更新循环
    spawn(function()
        while screenGui.Parent do
            UpdateStatus()
            wait(1)
        end
    end)
    
    -- 切换按钮点击事件
    toggleButton.MouseButton1Click:Connect(function()
        autoHealEnabled = not autoHealEnabled
        
        if autoHealEnabled then
            toggleButton.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
            toggleButton.Text = "自动回血: ON"
            print("[自动回血] 已启用")
            
            -- 重置状态
            isAtRecoverPoint = false
            savedPosition = nil
            
            -- 启动循环
            spawn(AutoHealLoop)
        else
            toggleButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
            toggleButton.Text = "自动回血: OFF"
            print("[自动回血] 已禁用")
            
            -- 如果在回血点，尝试TP回去
            if isAtRecoverPoint and savedPosition then
                print("[自动回血] 手动禁用，TP回原位置")
                TeleportTo(savedPosition, true, "手动关闭回血-回原位")
                isAtRecoverPoint = false
                savedPosition = nil
            end
        end
    end)
    
    -- 拖动功能
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    print("[捕捉宠物] UI已创建")
    return screenGui
end

-- 主执行
spawn(function()
    print("[捕捉宠物] 正在初始化...")
    WaitForPathTool()
    print("[捕捉宠物] 系统已加载")
    
    -- 扩大自动捕捉范围
    ExpandAutoCatchRange()
    
    wait(1)
    CreateUI()
end)

