-- 捕捉宠物脚本 - 自动回血功能
-- 功能：监听装备宠物血量，当2个死亡时自动TP到回血点，等全部回满后TP回去
-- 捕捉宠物脚本 - 自动回血功能
-- 功能：监听装备宠物血量，当2个死亡时自动TP到回血点，等全部回满后TP回去
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- 检查游戏ID
local targetGameId = 98664161516921
if game.PlaceId ~= targetGameId then
    error(string.format("[兑换代码] 游戏ID不匹配！当前: %d, 需要: %d", game.PlaceId, targetGameId))
end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

-- 运行限制：仅允许 PET_Huntes 运行
local ALLOWED_PLAYER_NAME = "PET_Huntes"
if not player or player.Name ~= ALLOWED_PLAYER_NAME then
    warn(string.format("[捕捉宠物] 未授权账号：%s（仅允许 %s 运行）", player and player.Name or "Unknown", ALLOWED_PLAYER_NAME))
    return
end

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

-- 减少搜索间隔（减少90%）
local function ReduceSearchInterval()
    if PathTool and PathTool.CfgAutoAttack then
        local success, err = pcall(function()
            if PathTool.CfgAutoAttack.SearchIntervalTime then
                local original = PathTool.CfgAutoAttack.SearchIntervalTime
                PathTool.CfgAutoAttack.SearchIntervalTime = original * 0.1  -- 减少90% = 保留10%
                print(string.format("[自动捕捉] ✓ 搜索间隔已减少: %s -> %s (减少90%%)", 
                    tostring(original), tostring(PathTool.CfgAutoAttack.SearchIntervalTime)))
                return true
            end
        end)
        if not success then
            warn("[自动捕捉] ⚠ 修改搜索间隔失败:", err)
        end
    else
        warn("[自动捕捉] ⚠ 无法找到 CfgAutoAttack，无法修改搜索间隔")
    end
end

-- 减少捕捉延迟（减少90%）
local function ReduceCatchDelay()
    if PathTool and PathTool.CfgAutoAttack then
        local success, err = pcall(function()
            if PathTool.CfgAutoAttack.DelayAutoCatch then
                local original = PathTool.CfgAutoAttack.DelayAutoCatch
                PathTool.CfgAutoAttack.DelayAutoCatch = original * 0.1  -- 减少90% = 保留10%
                print(string.format("[自动捕捉] ✓ 捕捉延迟已减少: %s -> %s (减少90%%)", 
                    tostring(original), tostring(PathTool.CfgAutoAttack.DelayAutoCatch)))
                return true
            end
        end)
        if not success then
            warn("[自动捕捉] ⚠ 修改捕捉延迟失败:", err)
        end
    else
        warn("[自动捕捉] ⚠ 无法找到 CfgAutoAttack，无法修改捕捉延迟")
    end
end

-- 减少拾取延迟（减少90%）
local function ReducePickUpDelay()
    if PathTool and PathTool.CfgAutoAttack then
        local success, err = pcall(function()
            if PathTool.CfgAutoAttack.DelayAutoPickUp then
                local original = PathTool.CfgAutoAttack.DelayAutoPickUp
                PathTool.CfgAutoAttack.DelayAutoPickUp = original * 0.1  -- 减少90% = 保留10%
                print(string.format("[自动捕捉] ✓ 拾取延迟已减少: %s -> %s (减少90%%)", 
                    tostring(original), tostring(PathTool.CfgAutoAttack.DelayAutoPickUp)))
                return true
            end
        end)
        if not success then
            warn("[自动捕捉] ⚠ 修改拾取延迟失败:", err)
        end
    else
        warn("[自动捕捉] ⚠ 无法找到 CfgAutoAttack，无法修改拾取延迟")
    end
end

-- 减少首次搜索延迟（减少90%）
local function ReduceFirstSearchDelay()
    if PathTool and PathTool.CfgAutoAttack then
        local success, err = pcall(function()
            if PathTool.CfgAutoAttack.FirstSearchDelay then
                local original = PathTool.CfgAutoAttack.FirstSearchDelay
                PathTool.CfgAutoAttack.FirstSearchDelay = original * 0.1  -- 减少90% = 保留10%
                print(string.format("[自动捕捉] ✓ 首次搜索延迟已减少: %s -> %s (减少90%%)", 
                    tostring(original), tostring(PathTool.CfgAutoAttack.FirstSearchDelay)))
                return true
            end
        end)
        if not success then
            warn("[自动捕捉] ⚠ 修改首次搜索延迟失败:", err)
        end
    else
        warn("[自动捕捉] ⚠ 无法找到 CfgAutoAttack，无法修改首次搜索延迟")
    end
end

-- 增加宠物回到玩家身边的速度（设置为200）
local function IncreasePetBackToPlayerSpeed()
    if PathTool and PathTool.CfgPet then
        local success, err = pcall(function()
            if PathTool.CfgPet.PetBackToPlayerSpeedUp then
                local original = PathTool.CfgPet.PetBackToPlayerSpeedUp
                PathTool.CfgPet.PetBackToPlayerSpeedUp = 200
                print(string.format("[自动捕捉] ✓ 宠物回玩家速度已增加: %s -> %d (%.1fx)", 
                    tostring(original), 200, 200 / (original or 1)))
                return true
            end
        end)
        if not success then
            warn("[自动捕捉] ⚠ 修改宠物回玩家速度失败:", err)
        end
    else
        warn("[自动捕捉] ⚠ 无法找到 CfgPet，无法修改宠物回玩家速度")
    end
end

-- 通过装备槽位追踪宠物（槽位索引 -> 宠物ID）
-- 格式: equippedSlots[slotIndex] = {petItemId = "xxx", lastSeenTime = tick()}
local equippedSlots = {}

-- 更新装备槽位信息（从宠物背包获取）
local function UpdateEquippedSlots()
    if not PathTool or not PathTool.ClientPlayerManager then
        return
    end
    
    local success, err = pcall(function()
        local gp = PathTool.ClientPlayerManager.GetGamePlayer()
        if not gp or not gp.pet then
            return
        end
        
        -- 记录当前所有有装备的槽位
        local currentSlots = {}
        
        -- 从宠物背包中获取所有已装备的宠物
        -- 通过遍历宠物背包，查找 EquipedIndex 不为 nil 的宠物
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
        
        -- 不再在这里检查死亡状态和缓存
        -- 死亡状态应该在需要时实时从 IsPetDead 函数获取
        -- 这样可以确保状态总是最新的
        
        -- 检查是否有槽位被清空（之前有装备，现在没有了）
        -- 收集需要删除的槽位
        local slotsToRemove = {}
        for slotIndex, slotData in pairs(equippedSlots) do
            if not currentSlots[slotIndex] then
                -- 槽位不在当前装备中
                if slotData.petInfo then
                    print(string.format("[自动回血] 检测到槽位 %d 的宠物被移除（可能已死亡）", slotIndex))
                end
                -- 标记为需要删除（不再保留旧槽位数据，避免创建虚拟死亡对象）
                table.insert(slotsToRemove, slotIndex)
            end
        end
        
        -- 删除过期的槽位数据
        for _, slotIndex in ipairs(slotsToRemove) do
            equippedSlots[slotIndex] = nil
        end
    end)
    
    if not success then
        warn("更新装备槽位时出错: " .. tostring(err))
    end
end

-- 获取装备的宠物信息（只返回实际装备的宠物）
local function GetEquippedPets()
    local pets = {}
    
    if not MgrPetClient then
        return pets
    end
    
    -- 先更新装备列表
    UpdateEquippedSlots()
    
    -- 遍历所有记录的槽位，只返回有效的宠物
    for slotIndex, slotData in pairs(equippedSlots) do
        if slotData.petInfo then
            -- 如果宠物对象存在，添加到列表
            table.insert(pets, slotData.petInfo)
        elseif slotData.petItemId then
            -- 如果宠物对象不存在但有 petItemId，尝试重新查找
            pcall(function()
                MgrPetClient.IterPet(function(petInfo)
                    if petInfo and petInfo.PetItemId == slotData.petItemId then
                        slotData.petInfo = petInfo
                        table.insert(pets, petInfo)
                        return false  -- 找到后停止
                    end
                    return true
                end)
            end)
            -- 如果仍然找不到，不创建虚拟对象，槽位会在下次 UpdateEquippedSlots 时被清理
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

-- 检查宠物是否死亡（从宠物背包判断，使用 IsDead() 方法）
local function IsPetDead(petInfo)
    if not petInfo then
        return true
    end
    
    -- 从宠物背包中获取实时死亡状态（使用 IsDead() 方法，与UI显示逻辑一致）
    if petInfo.PetItemId and PathTool and PathTool.ClientPlayerManager then
        local success, result = pcall(function()
            local gp = PathTool.ClientPlayerManager.GetGamePlayer()
            if gp and gp.pet then
                local petItem = gp.pet:GetItem(petInfo.PetItemId)
                if petItem and petItem.IsDead then
                    -- 使用游戏内部的 IsDead() 方法，这与背包UI显示骷髅头的逻辑完全一致
                    return petItem:IsDead()
                end
            end
            return nil
        end)
        
        if success and result ~= nil then
            return result
        end
    end
    
    -- 备用方法：使用 petInfo 的 IsAlive() 方法
    local success, result = pcall(function()
        if petInfo.IsAlive then
            return not petInfo:IsAlive()
        end
        return nil
    end)
    
    if success and result ~= nil then
        return result
    end
    
    -- 最后回退：检查 HealthValue 是否存在
    if petInfo.HealthValue then
        local healthSuccess, healthResult = pcall(function()
            local currentHealth = petInfo.HealthValue.Value
            -- 使用 LogicNumber 比较（如果可用）
            if PathTool and PathTool.LogicNumber then
                return PathTool.LogicNumber.LessThanOrEqualTo(currentHealth, 0)
            end
            -- 简单数值比较
            local num = tonumber(tostring(currentHealth))
            return num and num <= 0
        end)
        if healthSuccess and healthResult ~= nil then
            return healthResult
        end
    end
    
    return false
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

-- ============================================
-- 骑乘与平滑移动（与 monster-tracker-local 一致，无瞬移）
-- ============================================
local function IsMounted()
    local character = player.Character
    if not character then return false end
    local ridePetId = player:GetAttribute("RidePetId")
    if ridePetId == nil then
        return false
    end
    local mountPets = workspace:FindFirstChild("ClientMountPets")
    if mountPets then
        for _, child in ipairs(mountPets:GetChildren()) do
            if child.Name:find("Pet_") and child:IsA("Model") then return true end
        end
    end
    return true
end

local function GetCurrentRidePet()
    if not PathTool then return nil end
    local gp = nil
    pcall(function() gp = PathTool.ClientPlayerManager.GetGamePlayer() end)
    if not gp or not gp.pet then return nil end
    local rideItem = nil
    pcall(function() rideItem = gp.pet:GetRideItem() end)
    if not rideItem then return nil end
    local tmpl, tmplId, petId = nil, nil, nil
    pcall(function() tmpl = rideItem:GetTmpl() end)
    pcall(function() tmplId = rideItem:GetTmplId() end)
    pcall(function() petId = rideItem:GetId() end)
    if not tmpl or not petId then return nil end
    if not tmplId then tmplId = tmpl.Id end
    if not tmplId then return nil end
    return { petId = petId, tmplId = tmplId, name = tmpl.Name or "Unknown" }
end

local function TriggerMount(petInfo)
    local character = player.Character
    if not character then return false end
    if not petInfo then return false end
    local ViewUtil, PetSystem = nil, nil
    pcall(function()
        if PathTool.Require then PathTool.Require("PetSystem") end
        PetSystem = PathTool.PetSystem
        ViewUtil = PathTool.ViewUtil
    end)
    if ViewUtil and PetSystem and PetSystem.ClientSwitchRideStatus then
        local pcOk, reqOk = pcall(function() return ViewUtil.DoRequest(PetSystem.ClientSwitchRideStatus, true) end)
        if pcOk and reqOk then
            local startTime = tick()
            while (tick() - startTime) < 3 do
                if IsMounted() then return true end
                task.wait(0.1)
            end
            return IsMounted()
        end
    end
    character:SetAttribute("UserId", player.UserId)
    task.wait(0.1)
    player:SetAttribute("RideTmplId", petInfo.tmplId)
    task.wait(0.1)
    player:SetAttribute("RidePetId", petInfo.petId)
    local startTime = tick()
    while (tick() - startTime) < 3 do
        if IsMounted() then return true end
        task.wait(0.1)
    end
    return IsMounted()
end

local FLY_HEIGHT_OFFSET = 45
local FLY_SPEED_H = 40
local FLY_SPEED_V = 30
local ROTATE_DURATION = 0.12

local function SmoothMove(startPos, endPos, speed)
    local character = player.Character
    if not character then return false end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp.Parent then return false end
    local distance = (endPos - startPos).Magnitude
    local moveDuration = math.max(distance / speed, 0.1)
    local direction = distance > 0.0001 and (endPos - startPos).Unit or Vector3.new(1, 0, 0)
    local rotateEndCFrame
    if direction.Magnitude < 0.01 or math.abs(direction.Y) > 0.95 then
        rotateEndCFrame = CFrame.new(startPos) * (hrp.CFrame - hrp.CFrame.Position)
    else
        rotateEndCFrame = CFrame.lookAt(startPos, startPos + direction)
    end
    local rotateTween = TweenService:Create(hrp, TweenInfo.new(ROTATE_DURATION, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { CFrame = rotateEndCFrame })
    rotateTween:Play()
    rotateTween.Completed:Wait()
    character = player.Character
    hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp or not hrp.Parent then return false end
    local moveEndCFrame = CFrame.new(endPos) * (hrp.CFrame - hrp.CFrame.Position)
    local moveTween = TweenService:Create(hrp, TweenInfo.new(moveDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out), { CFrame = moveEndCFrame })
    moveTween:Play()
    moveTween.Completed:Wait()
    return true
end

local function MoveToPosition(targetPos, reason)
    reason = reason or "未命名"
    print(string.format("[TweenMove][%s] 目标 -> %s", reason, tostring(targetPos)))
    local character = player.Character
    if not character then
        warn(string.format("[TweenMove][%s] 失败：角色不存在", reason))
        return false
    end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart or not humanoidRootPart.Parent then
        warn(string.format("[TweenMove][%s] 失败：HumanoidRootPart 不存在", reason))
        return false
    end
    local startPos = humanoidRootPart.Position
    local distance = (targetPos - startPos).Magnitude
    if distance >= 80 and not IsMounted() then
        local petInfo = GetCurrentRidePet()
        if petInfo then
            local mountStart = tick()
            TriggerMount(petInfo)
            if (tick() - mountStart) < 3 and not IsMounted() then
                task.wait(math.max(0, 3 - (tick() - mountStart)))
            end
        end
    end
    for phase = 1, 3 do
        character = player.Character
        humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart or not humanoidRootPart.Parent then
            warn(string.format("[TweenMove][%s] 阶段%d 失败：HRP 丢失", reason, phase))
            return false
        end
        startPos = humanoidRootPart.Position
        local ok = false
        if phase == 1 then
            local endUp = startPos + Vector3.new(0, FLY_HEIGHT_OFFSET, 0)
            ok = SmoothMove(startPos, endUp, FLY_SPEED_V)
        elseif phase == 2 then
            local endHorizontal = Vector3.new(targetPos.X, startPos.Y, targetPos.Z)
            ok = SmoothMove(startPos, endHorizontal, FLY_SPEED_H)
        else
            ok = SmoothMove(startPos, targetPos, FLY_SPEED_V)
        end
        if not ok then
            warn(string.format("[TweenMove][%s] 阶段%d 失败", reason, phase))
            return false
        end
        task.wait(0.2)
    end
    character = player.Character
    humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    if humanoidRootPart then
        local remaining = (humanoidRootPart.Position - targetPos).Magnitude
        print(string.format("[TweenMove][%s] ✓ 完成，剩余距离=%.2f", reason, remaining))
    end
    return true
end

-- 传送函数（改为平滑移动，无瞬移）
local function TeleportTo(position, verifyPosition, reason)
    reason = reason or "未命名"
    local maxRetries = 2
    for attempt = 1, maxRetries do
        if MoveToPosition(position, reason) then
            return true
        end
        if attempt < maxRetries then
            warn(string.format("[TweenMove][%s] 第%d次失败，重试...", reason, attempt))
            task.wait(0.5)
        end
    end
    warn(string.format("[TweenMove][%s] %d 次尝试后仍失败", reason, maxRetries))
    return false
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
local skipRedPortal = false  -- 是否跳过红门（Portal3 或 TmplId 53）
local onlyBlueAndPurplePortal = false  -- 是否只刷蓝门、紫门和红门（Portal1、Portal2和Portal3，但排除TmplId 21和22）
local skipTeleportToFarming = false  -- 是否跳过传送到刷怪点（启用后不会传送到刷怪点）
local disableAutoAttackBeforeExit = false  -- 是否在退出裂缝前关闭自动战斗

-- 跨服刷静态裂缝相关变量
local serverHopEnabled = false  -- 是否启用跨服刷静态裂缝
local serverHopRunning = false  -- 是否正在运行跨服循环

-- 猎杀Undine相关变量
local huntUndineEnabled = false  -- 是否启用猎杀Undine
local huntUndineRunning = false  -- 是否正在运行猎杀循环
local undineNotifyCount = 0
local MAX_UNDINE_NOTIFY = 15
local UNDINE_TMPL_ID = 60005     -- Undine的怪物模板ID
local TIDELAND_AREA_ID = 6       -- Tideland区域ID
local TIDELAND_FALLBACK_POS = Vector3.new(-2992.81, -122.84, 2234.28)  -- Tideland未解锁时的传送坐标
local HUNT_UNDINE_CONFIG_PATH = "PetCatcher_HuntUndine_" .. player.Name .. ".json"
local huntUndineStats = {
    serversVisited = 0,   -- 访问的服务器数量
    undineFound = 0,      -- 发现Undine次数
    catchAttempts = 0     -- 捕捉尝试次数
}

-- 寻找Undine相关变量
local findUndineEnabled = false  -- 是否启用寻找Undine
local findUndineRunning = false  -- 是否正在运行寻找循环
local FIND_UNDINE_CONFIG_PATH = "PetCatcher_FindUndine_" .. player.Name .. ".json"
local findUndineStats = {
    serversVisited = 0,   -- 访问的服务器数量
    undineFound = 0       -- 发现Undine次数
}

-- 保存寻找Undine配置
local function SaveFindUndineConfig()
    if not (writefile and readfile) then return false end
    
    local config = {
        enabled = findUndineEnabled,
        stats = findUndineStats,
        timestamp = os.time()
    }
    
    local success, err = pcall(function()
        writefile(FIND_UNDINE_CONFIG_PATH, game:GetService("HttpService"):JSONEncode(config))
    end)
    return success
end

-- 读取寻找Undine配置
local function LoadFindUndineConfig()
    if not (writefile and readfile) then return nil end
    
    local success, result = pcall(function()
        local content = readfile(FIND_UNDINE_CONFIG_PATH)
        return game:GetService("HttpService"):JSONDecode(content)
    end)
    
    if success and result then
        return result
    end
    return nil
end

-- 删除寻找Undine配置
local function DeleteFindUndineConfig()
    if not delfile then return end
    pcall(function()
        delfile(FIND_UNDINE_CONFIG_PATH)
    end)
end

-- 退出游戏模式相关变量（没有Undine就退出游戏，方便手动进私服）
local exitGameMode = false  -- 是否启用退出游戏模式
local EXIT_GAME_CONFIG_PATH = "PetCatcher_ExitGame_" .. player.Name .. ".json"

-- 通知地址配置
local function GetVercelUrl()
    return "https://monster.suplucky.cc/api/monsters"
end

local function GetDiscordWebhookUrl()
    -- Discord Webhook 地址（如果不需要 Discord 通知，返回 nil）
    return "https://discord.com/api/webhooks/1464767453115711684/3mfyViA-vBDoRfDZ2ovPnxYNkZgV24cRxY5jAYTn-6MgipXygbIXEYgqLKrjuaRG_Wzl"
end

-- 获取当前服务器玩家数量
local function GetPlayerCount()
    return #game:GetService("Players"):GetPlayers()
end

-- 用于追踪玩家数量变化
local lastPlayerCount = 0
local undineActive = false  -- 标记 Undine 是否存在

-- [新功能] 解析怪物的 SpecialProp 属性
local function GetMonsterSpecialLabelByServerNode(serverNode)
    if not serverNode or not serverNode.GetAttribute then
        return "普通"
    end

    local sp = nil
    pcall(function()
        sp = serverNode:GetAttribute("SpecialProp")
    end)

    if type(sp) ~= "number" then
        return "普通"
    end

    if bit32 and bit32.band then
        if bit32.band(sp, 1) > 0 then return "huge" end
        if bit32.band(sp, 4) > 0 then return "bloodlit" end
        if bit32.band(sp, 2) > 0 then return "shiny" end
    end

    return sp ~= 0 and "特殊" or "普通"
end

-- [新功能] 获取怪物血量信息（修复版）
local function GetMonsterHealthInfo(mInfo)
    if not mInfo then
        return { current = nil, max = nil, isUnderAttack = false }
    end

    local current = nil
    local max = nil

    -- 读取当前血量：优先使用 HealthValue.Value
    pcall(function()
        if mInfo.HealthValue then
            if _G.PathTool and _G.PathTool.LogicNumber then
                local fixed = _G.PathTool.LogicNumber.FixLogicNumber(mInfo.HealthValue.Value)
                current = _G.PathTool.LogicNumber.ToNumber(fixed)
            else
                current = tonumber(tostring(mInfo.HealthValue.Value))
            end
        end
    end)

    -- 读取最大血量：使用 HealthValue:GetAttribute("MaxHealth")
    pcall(function()
        if mInfo.HealthValue and mInfo.HealthValue.GetAttribute then
            local maxAttr = mInfo.HealthValue:GetAttribute("MaxHealth")
            if maxAttr then
                if _G.PathTool and _G.PathTool.LogicNumber then
                    local fixed = _G.PathTool.LogicNumber.FixLogicNumber(maxAttr)
                    max = _G.PathTool.LogicNumber.ToNumber(fixed)
                else
                    max = tonumber(tostring(maxAttr))
                end
            end
        end
    end)

    local isUnderAttack = false
    if current and max and current < max then
        isUnderAttack = true
    end

    return {
        current = current,
        max = max,
        isUnderAttack = isUnderAttack
    }
end

-- 发送通知（同时发送到 Vercel 和 Discord）
local function SendDiscordNotification(title, message, color, special)
    pcall(function()
        local reqFunc = request or syn and syn.request or http_request
        if not reqFunc then
            warn("[通知] 没有可用的HTTP请求函数")
            return
        end
        
        local jobId = game.JobId or "Unknown"
        local placeId = game.PlaceId
        local joinLink = string.format("roblox://experiences/start?placeId=%d&gameInstanceId=%s", placeId, jobId)
        local playerCount = GetPlayerCount()
        
        -- 更新记录的玩家数量
        lastPlayerCount = playerCount

        -- 构建fields表（包含特殊属性）
        local fields = {
            {
                name = "JobId",
                value = "```" .. jobId .. "```",
                inline = false
            },
            {
                name = "桌面加入链接",
                value = "```" .. joinLink .. "```",
                inline = false
            },
            {
                name = "服务器人数",
                value = tostring(playerCount) .. " 人",
                inline = true
            },
            {
                name = "时间",
                value = os.date("%Y-%m-%d %H:%M:%S"),
                inline = true
            }
        }

        -- 如果有特殊属性，添加到fields中
        if special and special ~= "普通" then
            table.insert(fields, {
                name = "属性",
                value = tostring(special),
                inline = true
            })
        end

        -- Embed显示基本信息
        local embed = {
            title = title,
            description = message,
            color = color or 65280,  -- 默认绿色
            fields = fields,
            footer = {
                text = "Catch a Monster - Undine Hunter"
            }
        }
        
        local content = string.format(
            "**JobId (点击复制):**\n```%s```\n**桌面加入链接:**\n```%s```",
            jobId,
            joinLink
        )
        
        local data = {
            content = content,
            embeds = {embed},
            playerCount = playerCount  -- 额外字段给 Vercel 使用
        }

        -- 如果有特殊属性，添加到顶层（Vercel API使用）
        if special then
            data.special = special
        end

        local jsonData = HttpService:JSONEncode(data)

        -- 发送到 Vercel 网页
        local vercelUrl = GetVercelUrl()
        if vercelUrl then
            reqFunc({
                Url = vercelUrl,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = jsonData
            })
            print("[Vercel] 通知已发送, 人数: " .. playerCount .. ", 属性: " .. tostring(special))
        end
        
        -- 发送到 Discord
        local discordUrl = GetDiscordWebhookUrl()
        if discordUrl then
            reqFunc({
                Url = discordUrl,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = jsonData
            })
            print("[Discord] 通知已发送")
        end
    end)
end

-- 发送删除请求到 Vercel（当 Undine 死亡/消失时调用）
local function SendDeleteNotification()
    undineActive = false  -- 标记 Undine 不存在
    pcall(function()
        local reqFunc = request or syn and syn.request or http_request
        if not reqFunc then
            warn("[删除通知] 没有可用的HTTP请求函数")
            return
        end
        
        local jobId = game.JobId or "Unknown"
        local vercelUrl = GetVercelUrl()
        
        if vercelUrl and jobId ~= "Unknown" then
            reqFunc({
                Url = vercelUrl .. "?jobId=" .. jobId,
                Method = "DELETE",
                Headers = {["Content-Type"] = "application/json"}
            })
            print("[Vercel] 删除请求已发送，JobId: " .. jobId)
        end
    end)
end

-- 仅更新人数到 Vercel（不发送 Discord）
-- [新功能] 状态变化时更新到 Vercel（不刷 Discord）
local function SendMonsterStatusUpdate(underAttack, specialLabel, hpCurrent, hpMax)
    if not undineActive then return end

    pcall(function()
        local reqFunc = request or syn and syn.request or http_request
        if not reqFunc then return end

        local jobId = game.JobId or "Unknown"
        local placeId = game.PlaceId
        local joinLink = string.format("roblox://experiences/start?placeId=%d&gameInstanceId=%s", placeId, jobId)
        local playerCount = GetPlayerCount()

        lastPlayerCount = playerCount

        local fields = {
            { name = "JobId", value = "```" .. jobId .. "```", inline = false },
            { name = "桌面加入链接", value = "```" .. joinLink .. "```", inline = false },
            { name = "服务器人数", value = tostring(playerCount) .. " 人", inline = true },
            { name = "时间", value = os.date("%Y-%m-%d %H:%M:%S"), inline = true }
        }

        if specialLabel and specialLabel ~= "普通" then
            table.insert(fields, { name = "属性", value = tostring(specialLabel), inline = true })
        end

        if underAttack then
            table.insert(fields, { name = "状态", value = "🔄 战斗中", inline = true })
        end

        local vercelUrl = GetVercelUrl()
        if vercelUrl then
            local data = {
                embeds = {{
                    title = "🎉 发现 Undine!",
                    description = "在服务器中发现了 Undine，快来捕捉！",
                    fields = fields
                }},
                playerCount = playerCount,
                special = specialLabel,
                underAttack = underAttack,
                hpCurrent = hpCurrent,
                hpMax = hpMax
            }

            reqFunc({
                Url = vercelUrl,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(data)
            })
        end
    end)
end

-- 仅更新人数到 Vercel（不发送 Discord）
local function SendPlayerCountUpdate()
    if not undineActive then return end
    
    pcall(function()
        local reqFunc = request or syn and syn.request or http_request
        if not reqFunc then return end
        
        local jobId = game.JobId or "Unknown"
        local placeId = game.PlaceId
        local joinLink = string.format("roblox://experiences/start?placeId=%d&gameInstanceId=%s", placeId, jobId)
        local playerCount = GetPlayerCount()
        
        lastPlayerCount = playerCount
        
        local vercelUrl = GetVercelUrl()
        if vercelUrl then
            local data = {
                embeds = {{
                    title = "🎉 发现 Undine!",
                    description = "在服务器中发现了 Undine，快来捕捉！",
                    fields = {
                        { name = "JobId", value = "```" .. jobId .. "```", inline = false },
                        { name = "桌面加入链接", value = "```" .. joinLink .. "```", inline = false },
                        { name = "服务器人数", value = tostring(playerCount) .. " 人", inline = true },
                        { name = "时间", value = os.date("%Y-%m-%d %H:%M:%S"), inline = true }
                    }
                }},
                playerCount = playerCount
            }
            
            reqFunc({
                Url = vercelUrl,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(data)
            })
            print("[Vercel] 人数更新: " .. playerCount .. " 人")
        end
    end)
end

-- 启动玩家数量监听
local function StartPlayerCountMonitor()
    local Players = game:GetService("Players")
    
    Players.PlayerAdded:Connect(function(player)
        if undineActive then
            local newCount = GetPlayerCount()
            if newCount ~= lastPlayerCount then
                print("[人数监听] 玩家加入: " .. player.Name .. ", 当前: " .. newCount)
                spawn(SendPlayerCountUpdate)
            end
        end
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        if undineActive then
            -- 延迟一帧确保玩家已移除
            wait(0.1)
            local newCount = GetPlayerCount()
            if newCount ~= lastPlayerCount then
                print("[人数监听] 玩家离开: " .. player.Name .. ", 当前: " .. newCount)
                spawn(SendPlayerCountUpdate)
            end
        end
    end)
    
    print("[人数监听] 已启动")
end

-- 启动监听
spawn(StartPlayerCountMonitor)

-- 保存退出游戏模式配置
local function SaveExitGameConfig()
    if not (writefile and readfile) then return false end
    
    local config = {
        enabled = exitGameMode,
        timestamp = os.time()
    }
    
    local success = pcall(function()
        writefile(EXIT_GAME_CONFIG_PATH, HttpService:JSONEncode(config))
    end)
    return success
end

-- 读取退出游戏模式配置
local function LoadExitGameConfig()
    if not (writefile and readfile) then return nil end
    
    local success, result = pcall(function()
        local content = readfile(EXIT_GAME_CONFIG_PATH)
        return HttpService:JSONDecode(content)
    end)
    
    if success and result then
        return result
    end
    return nil
end

-- 删除退出游戏模式配置
local function DeleteExitGameConfig()
    if not delfile then return end
    pcall(function()
        delfile(EXIT_GAME_CONFIG_PATH)
    end)
end

-- 保存猎杀Undine配置
local function SaveHuntUndineConfig()
    if not (writefile and readfile) then return false end
    
    local config = {
        enabled = huntUndineEnabled,
        stats = huntUndineStats,
        timestamp = os.time()
    }
    
    local success = pcall(function()
        local json = HttpService:JSONEncode(config)
        writefile(HUNT_UNDINE_CONFIG_PATH, json)
    end)
    
    return success
end

-- 读取猎杀Undine配置
local function LoadHuntUndineConfig()
    if not (writefile and readfile) then return nil end
    
    local fileExists = false
    if isfile then
        pcall(function() fileExists = isfile(HUNT_UNDINE_CONFIG_PATH) end)
    else
        fileExists = true
    end
    
    if not fileExists then return nil end
    
    local success, result = pcall(function()
        local json = readfile(HUNT_UNDINE_CONFIG_PATH)
        return HttpService:JSONDecode(json)
    end)
    
    if success and result and result.stats then
        huntUndineStats = result.stats
    end
    
    return success and result or nil
end

-- 删除猎杀Undine配置
local function DeleteHuntUndineConfig()
    if not (writefile and readfile) then return end
    
    pcall(function()
        if isfile and isfile(HUNT_UNDINE_CONFIG_PATH) then
            delfile(HUNT_UNDINE_CONFIG_PATH)
        end
    end)
end
local serverHopStats = {
    serversVisited = 0,   -- 访问的服务器数量
    riftsFound = 0,       -- 发现的裂缝数量
    riftsCompleted = 0    -- 完成的裂缝数量
}
-- 静态裂缝区域配置（按顺序检查）
local STATIC_RIFT_AREAS = {
    {id = 2, name = "Volcano"},
    {id = 3, name = "Frost Isle"},
    {id = 4, name = "Neverland"},
    {id = 5, name = "Duneveil Isle"},
}

-- 跨服刷裂缝配置文件路径
local SERVER_HOP_CONFIG_PATH = "PetCatcher_ServerHop_" .. player.Name .. ".json"

-- 检查文件系统函数是否可用
local fileSystemAvailable = (writefile ~= nil and readfile ~= nil)

-- 保存跨服刷裂缝配置
local function SaveServerHopConfig()
    if not fileSystemAvailable then return false end
    
    local config = {
        enabled = serverHopEnabled,
        stats = serverHopStats,
        timestamp = os.time()
    }
    
    local success = pcall(function()
        local json = HttpService:JSONEncode(config)
        writefile(SERVER_HOP_CONFIG_PATH, json)
    end)
    
    return success
end

-- 读取跨服刷裂缝配置
local function LoadServerHopConfig()
    if not fileSystemAvailable then return nil end
    
    local fileExists = false
    if isfile then
        pcall(function() fileExists = isfile(SERVER_HOP_CONFIG_PATH) end)
    else
        fileExists = true
    end
    
    if not fileExists then return nil end
    
    local success, result = pcall(function()
        local json = readfile(SERVER_HOP_CONFIG_PATH)
        return HttpService:JSONDecode(json)
    end)
    
    return success and result or nil
end

-- 删除跨服刷裂缝配置
local function DeleteServerHopConfig()
    if not fileSystemAvailable then return end
    
    pcall(function()
        if isfile and isfile(SERVER_HOP_CONFIG_PATH) then
            delfile(SERVER_HOP_CONFIG_PATH)
        end
    end)
end

-- Server Hop 相关
local SERVER_LIST_FILE = "servers.json"  -- Python脚本生成的服务器列表文件
local SERVER_LIST_API = "https://games.roblox.com/v1/games/"
local MAX_PLAYERS_FOR_HOP = 8  -- 服务器最大人数限制（API备用方案使用）

-- ============== 局域网服务器配置 ==============
-- 设置为主机的局域网IP地址，例如 "http://192.168.1.100:8765"
-- 如果不使用局域网模式，设置为 nil
local LAN_SERVER_URL = "http://192.168.31.247:8765"  -- 局域网服务器地址

-- 从局域网服务器获取一个服务器
local function GetServerFromLAN()
    if not LAN_SERVER_URL then return nil end
    
    local success, result = pcall(function()
        local response = game:HttpGet(LAN_SERVER_URL .. "/server")
        return HttpService:JSONDecode(response)
    end)
    
    if success and result and result.success and result.server then
        print(string.format("[LAN] 从局域网获取服务器: %s", result.server.id:sub(1, 8) .. "..."))
        return result.server
    end
    
    if success and result and not result.success then
        print("[LAN] " .. (result.error or "没有可用服务器"))
    end
    
    return nil
end
-- 等待传送是否成功（JobId 是否变化）
local function WaitTeleportResult(oldJobId, timeout)
    timeout = timeout or 15
    local start = tick()

    while tick() - start < timeout do
        if game.JobId ~= oldJobId then
            return true
        end
        task.wait(0.5)
    end

    return false
end

-- 通知局域网服务器移除已用服务器
local function RemoveServerFromLAN(serverId)
    if not LAN_SERVER_URL then return end
    
    pcall(function()
        game:HttpGet(LAN_SERVER_URL .. "/remove?id=" .. serverId)
        print(string.format("[LAN] 已通知移除服务器: %s", serverId:sub(1, 8) .. "..."))
    end)
end

-- 查询局域网服务器状态
local function GetLANStatus()
    if not LAN_SERVER_URL then return nil end
    
    local success, result = pcall(function()
        local response = game:HttpGet(LAN_SERVER_URL .. "/status")
        return HttpService:JSONDecode(response)
    end)
    
    if success and result then
        return result
    end
    return nil
end
-- ============== 局域网服务器配置结束 ==============

-- 从本地文件读取服务器列表
local function GetServersFromFile()
    local success, result = pcall(function()
        if isfile and isfile(SERVER_LIST_FILE) then
            local content = readfile(SERVER_LIST_FILE)
            return HttpService:JSONDecode(content)
        end
        return nil
    end)
    if success and result then
        return result
    end
    return nil
end

-- 保存服务器列表到文件（同步写入）
local function SaveServersToFile(servers)
    if not writefile then return false end
    local success = pcall(function()
        local content = HttpService:JSONEncode(servers)
        writefile(SERVER_LIST_FILE, content)
    end)
    return success
end

-- 从服务器列表中移除指定服务器（传送前必须完成）
local function RemoveServerFromList(serverId)
    local servers = GetServersFromFile()
    if not servers then return end
    
    local newList = {}
    for _, server in ipairs(servers) do
        if server.id ~= serverId then
            table.insert(newList, server)
        end
    end
    
    -- 确保写入成功
    local saved = SaveServersToFile(newList)
    if saved then
        print(string.format("[Server Hop] 已移除服务器，剩余 %d 个", #newList))
    else
        warn("[Server Hop] 移除服务器失败")
    end
    
    -- 等待文件系统同步
    task.wait(0.1)
end

-- 从API获取服务器列表（备用方案）
local function GetServersFromAPI()
    local placeId = game.PlaceId
    local url = SERVER_LIST_API .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
    local success, result = pcall(function()
        local raw = game:HttpGet(url)
        return HttpService:JSONDecode(raw)
    end)
    if success and result and result.data then
        -- 过滤：人数 <= 8 且不是当前服务器
        local validServers = {}
        local currentJobId = game.JobId
        for _, server in ipairs(result.data) do
            if server.playing and server.playing <= MAX_PLAYERS_FOR_HOP and server.id ~= currentJobId then
                table.insert(validServers, {id = server.id})
            end
        end
        return validServers
    end
    return nil
end

-- 退出游戏（用于手动进私服）
local function ExitGame()
    print("[退出游戏] 没有找到Undine，正在退出游戏...")
    
    task.wait(0.5)
    
    -- 方法1: 使用 game:Shutdown() (某些执行器支持)
    pcall(function()
        game:Shutdown()
    end)
    
    -- 方法2: 传送到不存在的游戏ID导致退出
    pcall(function()
        game:GetService("TeleportService"):Teleport(1)
    end)
    
    -- 方法3: 使用 Synapse/Fluxus 的退出函数
    pcall(function()
        if syn and syn.queue_on_teleport then
            -- Synapse
            game:GetService("TeleportService"):Teleport(1)
        elseif fluxus_quit then
            fluxus_quit()
        elseif quit then
            quit()
        end
    end)
end

-- 执行 Server Hop
local function DoServerHop()
    -- 如果启用了退出游戏模式，直接退出游戏
    if exitGameMode then
        ExitGame()
        return
    end
    
    local maxRetries = 10  -- 最多重试10次
    local retryDelay = 10  -- 每次等待10秒
    
    for retry = 1, maxRetries do
        print("[Server Hop] 正在获取服务器...")
        
        local selectedServer = nil
        local fromLAN = false
        local fromFile = false
        
        -- 优先级1: 从局域网服务器获取（如果已配置）
        if LAN_SERVER_URL then
            selectedServer = GetServerFromLAN()
            if selectedServer then
                fromLAN = true
                print(string.format("[Server Hop] 从局域网获取服务器"))
            end
        end
        
        -- 优先级2: 从本地文件读取
        if not selectedServer then
            local servers = GetServersFromFile()
            if servers and #servers > 0 then
                print(string.format("[Server Hop] 从本地文件加载 %d 个服务器", #servers))
                fromFile = true
                
                -- 过滤掉当前服务器
                local currentJobId = game.JobId
                local validServers = {}
                for _, server in ipairs(servers) do
                    if server.id and server.id ~= currentJobId then
                        table.insert(validServers, server)
                    end
                end
                
                if #validServers > 0 then
                    selectedServer = validServers[math.random(1, #validServers)]
                end
            end
        end
        
        -- 优先级3: 从API获取（备用）
        if not selectedServer then
            print("[Server Hop] 尝试从API获取...")
            local servers = GetServersFromAPI()
            if servers and #servers > 0 then
                print(string.format("[Server Hop] 从API获取 %d 个服务器", #servers))
                selectedServer = servers[math.random(1, #servers)]
            end
        end
        
        -- 如果没有可用服务器，等待后重试
        if not selectedServer then
            if retry < maxRetries then
                print(string.format("[Server Hop] 没有可用服务器，等待 %d 秒后重新获取... (%d/%d)", retryDelay, retry, maxRetries))
                task.wait(retryDelay)
            else
                warn("[Server Hop] 多次尝试后仍无可用服务器，使用随机传送")
                pcall(function()
                    TeleportService:Teleport(game.PlaceId, player)
                end)
                return
            end
        else
            -- 有可用服务器
            local playerInfo = selectedServer.playing and string.format(" (人数: %d)", selectedServer.playing) or ""
            print(string.format("[Server Hop] 选择服务器: %s%s (%d/%d)", selectedServer.id, playerInfo, retry, maxRetries))
            
            -- 从对应来源移除该服务器
            if fromLAN then
                RemoveServerFromLAN(selectedServer.id)
            elseif fromFile then
                RemoveServerFromList(selectedServer.id)
            end
            
            -- 锚定角色防止崩溃
            pcall(function()
                local character = player.Character
                if character then
                    local hrp = character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        hrp.Anchored = true
                    end
                end
            end)
            
            -- 传送到选中的服务器
            local currentJobId = game.JobId
            
            local teleportOk = pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, selectedServer.id, player)
            end)
            
            -- 等待 15 秒判断是否真的换服
            local success = WaitTeleportResult(currentJobId, 15)
            
            if not success then
                warn("[Server Hop] 15秒内未切换服务器，JobId不可用，重新获取服务器")
            
                -- 解除锚定，防止卡死
                pcall(function()
                    local character = player.Character
                    if character then
                        local hrp = character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            hrp.Anchored = false
                        end
                    end
                end)
            
                -- 重新来一次（进入下一次 retry 循环）
            else
                -- 成功的话脚本会重载，这里理论上不会再继续
                return
            end

            
            -- 等待检测传送是否成功
            task.wait(3)
            
            -- 检查是否还在当前服务器（传送失败）
            if game.JobId == currentJobId then
                -- 解除锚定
                pcall(function()
                    local character = player.Character
                    if character then
                        local hrp = character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            hrp.Anchored = false
                        end
                    end
                end)
                
                if retry < maxRetries then
                    warn(string.format("[Server Hop] 传送失败，3秒后重试... (%d/%d)", retry, maxRetries))
                    task.wait(3)
                    -- 继续循环，选择下一个服务器
                else
                    warn("[Server Hop] 多次传送失败，使用随机传送")
                    pcall(function()
                        TeleportService:Teleport(game.PlaceId, player)
                    end)
                    return
                end
            else
                -- 传送成功（理论上不会执行到这里，因为脚本会重载）
                return
            end
        end
    end
end

-- 检测游戏是否完全加载完成
local function IsGameFullyLoaded()
    -- 检查 1: PathTool 是否存在
    if not _G.PathTool then
        return false, "PathTool 未加载"
    end
    
    -- 检查 2: ClientPlayerManager 是否可用
    if not _G.PathTool.ClientPlayerManager then
        return false, "ClientPlayerManager 未加载"
    end
    
    -- 检查 3: GamePlayer 是否已初始化
    local gp = nil
    local success = pcall(function()
        gp = _G.PathTool.ClientPlayerManager.GetGamePlayer()
    end)
    if not success or not gp then
        return false, "GamePlayer 未初始化"
    end
    
    -- 检查 4: 玩家角色是否加载
    local character = player.Character
    if not character then
        return false, "角色未加载"
    end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        return false, "HumanoidRootPart 未加载"
    end
    
    -- 检查 5: 宠物系统是否可用
    if not gp.pet then
        return false, "宠物系统未加载"
    end
    
    -- 检查 6: 区域系统是否可用
    if not _G.PathTool.AreaSystem then
        return false, "区域系统未加载"
    end
    
    return true, "游戏加载完成"
end

-- 等待游戏完全加载（带超时）
local function WaitForGameFullyLoaded(maxWait)
    maxWait = maxWait or 60  -- 默认最多等待60秒
    local startTime = tick()
    
    print("[跨服刷裂缝] 等待游戏加载完成...")
    
    while (tick() - startTime) < maxWait do
        local loaded, reason = IsGameFullyLoaded()
        if loaded then
            print("[跨服刷裂缝] 游戏加载完成: " .. reason)
            return true
        end
        
        -- 每5秒打印一次等待状态
        local elapsed = tick() - startTime
        if math.floor(elapsed) % 5 == 0 and elapsed > 0 then
            print(string.format("[跨服刷裂缝] 等待中... (%.0f秒) - %s", elapsed, reason))
        end
        
        task.wait(0.5)
    end
    
    warn("[跨服刷裂缝] 等待超时，游戏可能未完全加载")
    return false
end

-- 裂缝统计
local riftStats = {
    total = 0,      -- 总共进入
    success = 0,    -- 成功完成
    failed = 0      -- 失败
}
local riftStatsLabel = nil  -- UI统计标签
local riftAvailableLabel = nil  -- 可进入裂缝数量标签

-- 区域加载监听（用于检测静态裂缝）
local areaLoadListeners = {}  -- 存储已连接的监听器
local function SetupAreaLoadListener()
    local areaFolder = workspace:FindFirstChild("Area")
    if not areaFolder then
        return
    end
    
    -- 如果已经设置过监听器，不再重复设置
    if areaLoadListeners.connected then
        return
    end
    
    -- 监听新区域加载
    areaFolder.ChildAdded:Connect(function(areaChild)
        print(string.format("[静态裂缝检测] 新区域加载: %s", areaChild.Name))
        -- 延迟一下，等待区域完全加载
        task.wait(1)
        -- 触发一次裂缝检测（如果正在自动刷裂缝）
        if autoRiftEnabled and riftState == "idle" then
            print("[静态裂缝检测] 检测到新区域加载，触发裂缝检测")
        end
    end)
    
    areaLoadListeners.connected = true
    print("[静态裂缝检测] 区域加载监听器已设置")
end

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
    -- 如果启用了退出前关闭自动战斗，先关闭
    if disableAutoAttackBeforeExit then
        local currentState = GetAutoAttackState()
        if currentState then
            print("[退出裂缝] 正在关闭自动战斗...")
            SetAutoAttackState(false)
            task.wait(0.3)  -- 等待状态生效
        end
    end
    
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
    
    -- 静态地牢：使用 GroupId、StartTick 和 UseDataType 检查
    -- 根据 AreaDungeonShower 代码，静态地牢使用 IsEntered(GroupId, StartTick, UseDataType)
    -- 注意：同一个静态地牢的StartTick可能会变化，所以每次检查时获取最新的StartTick
    if not dynamicKey then
        local groupId = node:GetAttribute("DungeonGroupId")
        local useDataType = node:GetAttribute("DungeonUseDataType")
        
        -- 如果属性在父节点上，尝试从父节点获取
        if not groupId or useDataType == nil then
            local parent = node.Parent
            if parent then
                if not groupId then
                    groupId = parent:GetAttribute("DungeonGroupId")
                end
                if useDataType == nil then
                    useDataType = parent:GetAttribute("DungeonUseDataType")
                end
            end
        end
        
        -- 静态地牢必须有 GroupId 才能检查
        -- 注意：StartTick可能会变化，所以每次检查时重新获取最新的StartTick
        if groupId then
            -- 重新获取最新的StartTick（因为同一个地牢的StartTick可能会变化）
            local latestStartTick = node:GetAttribute("DungeonStartTick")
            if not latestStartTick then
                local parent = node.Parent
                if parent then
                    latestStartTick = parent:GetAttribute("DungeonStartTick")
                end
            end
            
            -- 根据 AreaDungeonShower 代码第80行，只有当 useDataType 存在时才检查
            -- if p_u_2._dungeonUseDataType and p_u_1.dungeon:IsEntered(p_u_2._dungeonGroupId, p_u_2._dungeonStartTick, p_u_2._dungeonUseDataType) then
            if useDataType and latestStartTick and gp.dungeon and gp.dungeon.IsEntered then
                local ok, res = pcall(function()
                    return gp.dungeon:IsEntered(groupId, latestStartTick, useDataType)
                end)
                if ok and res then
                    return true
                end
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
                _dungeonUseDataType = actualNode:GetAttribute("DungeonUseDataType"),
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
                _dungeonUseDataType = actualNode:GetAttribute("DungeonUseDataType"),
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
    -- 验证节点仍然有效
    if not node or not node.Parent then
        warn("[自动刷裂缝] TryCreateAndStartDungeon: 节点无效或已销毁")
        return false
    end
    
    local showId = tonumber(string.sub(node.Name or "", 9))
    local startTick = node:GetAttribute("DungeonStartTick")
    
    -- 如果属性在父节点上，尝试从父节点获取
    if not startTick then
        local parent = node.Parent
        if parent then
            startTick = parent:GetAttribute("DungeonStartTick")
        end
    end
    
    if not showId or not startTick then
        warn(string.format("[自动刷裂缝] TryCreateAndStartDungeon: 缺少必要参数 showId=%s, startTick=%s", 
            tostring(showId), tostring(startTick)))
        return false
    end
    
    print(string.format("[自动刷裂缝] 创建地牢队伍: showId=%d, startTick=%s", showId, tostring(startTick)))
    local okCreate = DoDungeonRequest("DungeonCreateTeamChannel", showId, startTick)
    if not okCreate then
        warn("[自动刷裂缝] 创建地牢队伍失败")
        return false
    end
    print("[自动刷裂缝] ✓ 地牢队伍创建成功")
    
    -- 创建队伍后增加延迟再开始，避免太快导致的问题
    -- 根据游戏逻辑，需要等待服务器处理创建请求
    task.wait(1.5)  -- 增加延迟到1.5秒，确保服务器处理完成
    
    -- 再次验证节点仍然有效
    if not node or not node.Parent then
        warn("[自动刷裂缝] TryCreateAndStartDungeon: 节点在等待过程中已销毁")
        return false
    end
    
    -- 重新获取 startTick（可能已变化）
    local latestStartTick = node:GetAttribute("DungeonStartTick")
    if not latestStartTick then
        local parent = node.Parent
        if parent then
            latestStartTick = parent:GetAttribute("DungeonStartTick")
        end
    end
    
    if not latestStartTick then
        warn("[自动刷裂缝] TryCreateAndStartDungeon: 无法获取最新的 startTick")
        return false
    end
    
    print(string.format("[自动刷裂缝] 启动地牢: showId=%d, startTick=%s", showId, tostring(latestStartTick)))
    local okStart = DoDungeonRequest("DungeonStartChannel", showId, latestStartTick)
    if okStart then
        print("[自动刷裂缝] ✓ 地牢启动成功")
    else
        warn("[自动刷裂缝] 地牢启动失败")
    end
    return okStart
end

-- 检查节点是否是红门（Portal3 或 TmplId 53）
local function IsRedPortal(node, cfg)
    if not node then
        return false
    end
    
    -- 检查 TmplId 是否为 53
    local tmplId = node:GetAttribute("DungeonTmplId")
    if tmplId == 53 then
        return true
    end
    
    -- 如果属性在父节点上，尝试从父节点获取
    if not tmplId then
        local parent = node.Parent
        if parent then
            tmplId = parent:GetAttribute("DungeonTmplId")
            if tmplId == 53 then
                return true
            end
        end
    end
    
    -- 检查配置中的 EnterModel 是否为 Portal3
    if cfg and tmplId then
        local dungeonConfig = cfg.Tmpls and (cfg.Tmpls[tmplId] or cfg.Tmpls[tostring(tmplId)])
        if dungeonConfig and dungeonConfig.EnterModel == "Portal3" then
            return true
        end
    end
    
    -- 检查节点或其子节点是否有 Portal3 模型
    local function hasPortal3(instance)
        if instance:IsA("Model") and instance.Name == "Portal3" then
            return true
        end
        for _, child in ipairs(instance:GetChildren()) do
            if hasPortal3(child) then
                return true
            end
        end
        return false
    end
    
    if hasPortal3(node) then
        return true
    end
    
    return false
end

-- 检查节点是否是静态裂缝（Portal4 或 Portal5，新的静态裂缝类型）
local function IsStaticRift(node, cfg)
    if not node then
        return false
    end
    
    local tmplId = node:GetAttribute("DungeonTmplId")
    if not tmplId and node.Parent then
        tmplId = node.Parent:GetAttribute("DungeonTmplId")
    end
    
    -- 检查是否是静态裂缝的 TmplId（10000-10004）
    if tmplId and (tmplId == 10000 or tmplId == 10001 or tmplId == 10002 or tmplId == 10003 or tmplId == 10004) then
        return true
    end
    
    -- 检查配置中的 EnterModel 是否为 Portal4 或 Portal5
    if cfg and tmplId then
        local dungeonConfig = cfg.Tmpls and (cfg.Tmpls[tmplId] or cfg.Tmpls[tostring(tmplId)])
        if dungeonConfig then
            local enterModel = dungeonConfig.EnterModel
            if enterModel == "Portal4" or enterModel == "Portal5" then
                return true
            end
        end
    end
    
    -- 检查节点或其子节点是否有 Portal4 或 Portal5 模型
    local function hasStaticPortal(instance)
        if instance:IsA("Model") and (instance.Name == "Portal4" or instance.Name == "Portal5") then
            return true
        end
        for _, child in ipairs(instance:GetChildren()) do
            if hasStaticPortal(child) then
                return true
            end
        end
        return false
    end
    
    if hasStaticPortal(node) then
        return true
    end
    
    return false
end

-- 检查节点是否是蓝门或紫门（Portal1或Portal2），但排除TmplId 21和22
local function IsBlueOrPurplePortal(node, cfg)
    if not node then
        return false
    end
    
    -- 检查 TmplId
    local tmplId = node:GetAttribute("DungeonTmplId")
    
    -- 如果属性在父节点上，尝试从父节点获取
    if not tmplId then
        local parent = node.Parent
        if parent then
            tmplId = parent:GetAttribute("DungeonTmplId")
        end
    end
    
    -- 排除 TmplId 21 和 22
    if tmplId == 21 or tmplId == 22 then
        return false
    end
    
    -- 检查是否是 Portal1、Portal2 或 Portal3 对应的 ID
    -- Portal1 (蓝门): 21, 31, 41, 51 (排除21，所以是 31, 41, 51)
    -- Portal2 (紫门): 22, 32, 42, 52 (排除22，所以是 32, 42, 52)
    -- Portal3 (红门): 53
    if tmplId == 31 or tmplId == 41 or tmplId == 51 or  -- Portal1 (蓝门)
       tmplId == 32 or tmplId == 42 or tmplId == 52 or  -- Portal2 (紫门)
       tmplId == 53 then  -- Portal3 (红门)
        return true
    end
    
    -- 检查配置中的 EnterModel 和 Difficulty
    if cfg and tmplId then
        local dungeonConfig = cfg.Tmpls and (cfg.Tmpls[tmplId] or cfg.Tmpls[tostring(tmplId)])
        if dungeonConfig then
            local enterModel = dungeonConfig.EnterModel
            local difficulty = dungeonConfig.Difficulty
            -- Portal1、Portal2 或 Portal3，但排除 21 和 22
            if (enterModel == "Portal1" or enterModel == "Portal2" or enterModel == "Portal3") and tmplId ~= 21 and tmplId ~= 22 then
                return true
            end
            -- Difficulty 1、2 或 3，但排除 21 和 22
            if (difficulty == 1 or difficulty == 2 or difficulty == 3) and tmplId ~= 21 and tmplId ~= 22 then
                return true
            end
        end
    end
    
    -- 检查节点或其子节点是否有 Portal1、Portal2、Portal3、Portal4 或 Portal5 模型
    local function hasPortal1Or2Or3Or4Or5(instance)
        if instance:IsA("Model") and (instance.Name == "Portal1" or instance.Name == "Portal2" or instance.Name == "Portal3" or instance.Name == "Portal4" or instance.Name == "Portal5") then
            return true
        end
        for _, child in ipairs(instance:GetChildren()) do
            if hasPortal1Or2Or3Or4Or5(child) then
                return true
            end
        end
        return false
    end
    
    if hasPortal1Or2Or3Or4Or5(node) then
        -- 如果检测到 Portal1、Portal2、Portal3、Portal4 或 Portal5 模型
        if not tmplId then
            -- 如果没有 tmplId，但有 Portal 模型，认为是有效的裂缝
            return true
        elseif tmplId ~= 21 and tmplId ~= 22 then
            -- 如果有 tmplId，确认不是 21 或 22
            return true
        end
    end
    
    return false
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
                            -- 静态地牢：检查地牢是否激活（必须有 StartTick 和 GroupId，不需要 SyncKey）
                            local startTick = node:GetAttribute("DungeonStartTick")
                            local syncKey = node:GetAttribute("DungeonSyncObjectKey")
                            local groupId = node:GetAttribute("DungeonGroupId")
                            -- 如果属性在父节点上，尝试从父节点获取
                            if not startTick then
                                local parent = node.Parent
                                if parent then
                                    startTick = parent:GetAttribute("DungeonStartTick")
                                    if not syncKey then
                                        syncKey = parent:GetAttribute("DungeonSyncObjectKey")
                                    end
                                    if not groupId then
                                        groupId = parent:GetAttribute("DungeonGroupId")
                                    end
                                end
                            end
                            -- 静态地牢：需要 StartTick 和 GroupId（不需要 SyncKey）
                            -- 动态地牢：需要 StartTick 和 SyncKey
                            if startTick and (groupId or syncKey) then
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
                            -- 静态地牢：检查地牢是否激活（必须有 StartTick 和 GroupId，不需要 SyncKey）
                            local startTick = node:GetAttribute("DungeonStartTick")
                            local syncKey = node:GetAttribute("DungeonSyncObjectKey")
                            local groupId = node:GetAttribute("DungeonGroupId")
                            -- 如果属性在父节点上，尝试从父节点获取
                            if not startTick then
                                local parent = node.Parent
                                if parent then
                                    startTick = parent:GetAttribute("DungeonStartTick")
                                    if not syncKey then
                                        syncKey = parent:GetAttribute("DungeonSyncObjectKey")
                                    end
                                    if not groupId then
                                        groupId = parent:GetAttribute("DungeonGroupId")
                                    end
                                end
                            end
                            -- 静态地牢：需要 StartTick 和 GroupId（不需要 SyncKey）
                            -- 动态地牢：需要 StartTick 和 SyncKey
                            if startTick and (groupId or syncKey) then
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
                -- 动态地牢：检查地牢是否激活（必须有 StartTick 和 SyncKey）
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
                -- 只有当地牢激活且有 SyncKey 时才添加（动态地牢必须有 SyncKey）
                if startTick and syncKey then
                    -- 检查是否在失败冷却列表中
                    local nodeKey = tostring(node)
                    local failedTime = failedRiftNodes[nodeKey]
                    local isInCooldown = failedTime and (tick() - failedTime) < FAILED_RIFT_COOLDOWN
                    if isInCooldown then
                        -- 跳过冷却中的节点
                    elseif skipEntered and alreadyEnteredDungeon(node) then
                        -- 跳过已进入的
                    elseif skipRedPortal and IsRedPortal(node, cfg) then
                        -- 跳过红门（如果开关开启）
                    elseif onlyBlueAndPurplePortal and not IsBlueOrPurplePortal(node, cfg) then
                        -- 只刷蓝门、紫门和红门时，跳过非蓝门、紫门和红门（排除21和22）
                    else
                        -- 调试：如果是红门且两个开关都开启，打印调试信息
                        local tmplId = node:GetAttribute("DungeonTmplId") or (node.Parent and node.Parent:GetAttribute("DungeonTmplId"))
                        if tmplId == 53 and onlyBlueAndPurplePortal and not skipRedPortal then
                            print(string.format("[调试] 红门通过过滤: skipRedPortal=%s, onlyBlueAndPurplePortal=%s, IsBlueOrPurplePortal=%s", 
                                tostring(skipRedPortal), tostring(onlyBlueAndPurplePortal), tostring(IsBlueOrPurplePortal(node, cfg))))
                        end
                        table.insert(validNodes, {node = node, pos = pos})
                    end
                end
            end
        end
    end
    
    -- 方法2: 搜索 Area.*.Area.Dungeon 下的静态地牢（新路径格式）
    -- 注意：静态地牢依赖于区域加载，只有玩家附近的区域才会被加载
    -- 游戏使用流式加载（Streaming），只加载玩家一定范围内的区域
    -- 因此，如果玩家不在某个区域附近，该区域的静态裂缝节点不会存在于 workspace 中
    -- 解决方案：
    --   1. 通过监听 workspace.Area.ChildAdded 事件，在新区域加载时检测静态裂缝
    --   2. 如果需要检测未加载区域的静态裂缝，需要先传送到该区域附近触发加载
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
                                -- 静态地牢：检查地牢是否激活（必须有 StartTick 和 GroupId，不需要 SyncKey）
                                local startTick = node:GetAttribute("DungeonStartTick")
                                local syncKey = node:GetAttribute("DungeonSyncObjectKey")
                                local groupId = node:GetAttribute("DungeonGroupId")
                                local useDataType = node:GetAttribute("DungeonUseDataType")
                                -- 如果属性在父节点上，尝试从父节点获取
                                if not startTick then
                                    local parent = node.Parent
                                    if parent then
                                        startTick = parent:GetAttribute("DungeonStartTick")
                                        if not syncKey then
                                            syncKey = parent:GetAttribute("DungeonSyncObjectKey")
                                        end
                                        if not groupId then
                                            groupId = parent:GetAttribute("DungeonGroupId")
                                        end
                                        if useDataType == nil then
                                            useDataType = parent:GetAttribute("DungeonUseDataType")
                                        end
                                    end
                                end
                                -- 静态地牢：需要 StartTick 和 GroupId（不需要 SyncKey）
                                -- 动态地牢：需要 StartTick 和 SyncKey（但静态地牢路径下通常不会有动态地牢）
                                local isActive = false
                                if startTick then
                                    if groupId then
                                        -- 静态地牢（静态裂缝）- 主要情况
                                        isActive = true
                                    elseif syncKey then
                                        -- 动态地牢（在静态地牢路径下，较少见但可能）
                                        isActive = true
                                    end
                                end
                                -- 只有当地牢激活时才添加
                                if isActive then
                                    -- 检查是否在失败冷却列表中
                                    local nodeKey = tostring(node)
                                    local failedTime = failedRiftNodes[nodeKey]
                                    local isInCooldown = failedTime and (tick() - failedTime) < FAILED_RIFT_COOLDOWN
                                    if isInCooldown then
                                        -- 跳过冷却中的节点
                                    elseif skipEntered and alreadyEnteredDungeon(node) then
                                        -- 跳过已进入的
                                    elseif skipRedPortal and IsRedPortal(node, cfg) then
                                        -- 跳过红门（如果开关开启）
                                    elseif onlyBlueAndPurplePortal and not IsBlueOrPurplePortal(node, cfg) then
                                        -- 只刷蓝门、紫门和红门时，跳过非蓝门、紫门和红门（排除21和22）
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
                                -- 静态地牢：检查地牢是否激活（必须有 StartTick 和 GroupId，不需要 SyncKey）
                                local startTick = node:GetAttribute("DungeonStartTick")
                                local syncKey = node:GetAttribute("DungeonSyncObjectKey")
                                local groupId = node:GetAttribute("DungeonGroupId")
                                local useDataType = node:GetAttribute("DungeonUseDataType")
                                -- 如果属性在父节点上，尝试从父节点获取
                                if not startTick then
                                    local parent = node.Parent
                                    if parent then
                                        startTick = parent:GetAttribute("DungeonStartTick")
                                        if not syncKey then
                                            syncKey = parent:GetAttribute("DungeonSyncObjectKey")
                                        end
                                        if not groupId then
                                            groupId = parent:GetAttribute("DungeonGroupId")
                                        end
                                        if useDataType == nil then
                                            useDataType = parent:GetAttribute("DungeonUseDataType")
                                        end
                                    end
                                end
                                -- 静态地牢：需要 StartTick 和 GroupId（不需要 SyncKey）
                                -- 动态地牢：需要 StartTick 和 SyncKey（但静态地牢路径下通常不会有动态地牢）
                                local isActive = false
                                if startTick then
                                    if groupId then
                                        -- 静态地牢（静态裂缝）- 主要情况
                                        isActive = true
                                    elseif syncKey then
                                        -- 动态地牢（在静态地牢路径下，较少见但可能）
                                        isActive = true
                                    end
                                end
                                -- 只有当地牢激活时才添加
                                if isActive then
                                    -- 检查是否在失败冷却列表中
                                    local nodeKey = tostring(node)
                                    local failedTime = failedRiftNodes[nodeKey]
                                    local isInCooldown = failedTime and (tick() - failedTime) < FAILED_RIFT_COOLDOWN
                                    if isInCooldown then
                                        -- 跳过冷却中的节点
                                    elseif skipEntered and alreadyEnteredDungeon(node) then
                                        -- 跳过已进入的
                                    elseif skipRedPortal and IsRedPortal(node, cfg) then
                                        -- 跳过红门（如果开关开启）
                                    elseif onlyBlueAndPurplePortal and not IsBlueOrPurplePortal(node, cfg) then
                                        -- 只刷蓝门、紫门和红门时，跳过非蓝门、紫门和红门（排除21和22）
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
                            if skipRedPortal and IsRedPortal(node, cfg) then
                                -- 跳过红门（如果开关开启）
                            elseif onlyBlueAndPurplePortal and not IsBlueOrPurplePortal(node, cfg) then
                                -- 只刷蓝门和紫门时，跳过非蓝门和紫门（排除21和22）
                            else
                                local pos = node:GetPivot().Position
                                table.insert(validNodes, {node = node, pos = pos})
                            end
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
                                    if skipRedPortal and IsRedPortal(node, cfg) then
                                        -- 跳过红门（如果开关开启）
                                    elseif onlyBlueAndPurplePortal and not IsBlueOrPurplePortal(node, cfg) then
                                        -- 只刷蓝门、紫门和红门时，跳过非蓝门、紫门和红门（排除21和22）
                                    else
                                        local pos = node:GetPivot().Position
                                        table.insert(validNodes, {node = node, pos = pos})
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
                                    if skipRedPortal and IsRedPortal(node, cfg) then
                                        -- 跳过红门（如果开关开启）
                                    elseif onlyBlueAndPurplePortal and not IsBlueOrPurplePortal(node, cfg) then
                                        -- 只刷蓝门、紫门和红门时，跳过非蓝门、紫门和红门（排除21和22）
                                    else
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
        -- 如果开启了跳过红门，且 anyNode 是红门，则不返回
        if skipRedPortal and IsRedPortal(anyNode, cfg) then
            return nil, nil
        end
        -- 如果开启了只刷蓝门、紫门和红门，且 anyNode 不是蓝门、紫门或红门（排除21和22），则不返回
        if onlyBlueAndPurplePortal and not IsBlueOrPurplePortal(anyNode, cfg) then
            return nil, nil
        end
        return anyNode, anyPos
    end
    return nearestNode, nearestPos
end

local function IsActiveDungeonNode(node)
    if not node then
        return false
    end
    local startTick = node:GetAttribute("DungeonStartTick")
    local syncKey = node:GetAttribute("DungeonSyncObjectKey")
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
    return startTick and syncKey
end

local function CountEligibleRifts()
    local cfg = nil
    if PathTool then
        cfg = rawget(PathTool, "CfgDungeon")
        if type(cfg) ~= "table" then
            cfg = nil
        end
    end

    local count = 0
    local function considerNode(node)
        if not IsRiftNode(node, cfg) then
            return
        end
        if not IsActiveDungeonNode(node) then
            return
        end
        if alreadyEnteredDungeon(node) then
            return
        end
        if skipRedPortal and IsRedPortal(node, cfg) then
            return
        end
        if onlyBlueAndPurplePortal and not IsBlueOrPurplePortal(node, cfg) then
            return
        end
        count = count + 1
    end

    local root = workspace:FindFirstChild("DynamicDungeon")
    if root then
        for _, node in ipairs(root:GetChildren()) do
            considerNode(node)
        end
    end

    local areaFolder = workspace:FindFirstChild("Area")
    if areaFolder then
        for _, areaChild in ipairs(areaFolder:GetChildren()) do
            local areaSubFolder = areaChild:FindFirstChild("Area")
            if areaSubFolder then
                local dungeonFolder = areaSubFolder:FindFirstChild("Dungeon")
                if dungeonFolder then
                    for _, node in ipairs(dungeonFolder:GetChildren()) do
                        if string.sub(node.Name, 1, 8) == "Dungeon_" then
                            considerNode(node)
                        end
                    end
                end
            end
            local serverZone = areaChild:FindFirstChild("ServerZone")
            if serverZone then
                local dungeonFolder = serverZone:FindFirstChild("Dungeon")
                if dungeonFolder then
                    for _, node in ipairs(dungeonFolder:GetChildren()) do
                        if string.sub(node.Name, 1, 8) == "Dungeon_" then
                            considerNode(node)
                        end
                    end
                end
            end
        end
    end

    return count
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

-- 检查是否有正在进行的捕捉（通过 CatchPlayerId 属性）
-- 根据游戏代码，当捕捉请求发送成功后，服务器会设置 CatchPlayerId_<userId> 属性
local function IsCatchStarted()
    if not PathTool or not PathTool.MgrMonsterClient then
        return false
    end
    local userId = player.UserId
    local catchStarted = false
    PathTool.MgrMonsterClient.IterMonster(function(mInfo)
        if mInfo and mInfo.ServerNode then
            local key = "CatchPlayerId_" .. tostring(userId)
            local bySelf = mInfo.ServerNode:GetAttribute(key)
            if bySelf then
                catchStarted = true
                return false
            else
                -- 遍历所有属性查找 CatchPlayerId_<userId>
                for attrName, _ in mInfo.ServerNode:GetAttributes() do
                    if string.find(attrName, "CatchPlayerId_") == 1 then
                        local idStr = string.sub(attrName, 14)
                        if tonumber(idStr) == userId then
                            catchStarted = true
                            return false
                        end
                    end
                end
            end
        end
        return true
    end)
    return catchStarted
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
    
    -- 等待宠物完全加载和初始化（修复：进裂缝后立刻判断宠物全死的bug）
    print("[自动刷裂缝] 等待宠物完全加载...")
    local petLoadRetries = 0
    local maxPetLoadRetries = 10
    local petLoadSuccess = false
    while petLoadRetries < maxPetLoadRetries do
        UpdateEquippedSlots()
        local slotCount = GetEquippedSlotCount()
        if slotCount > 0 then
            -- 检查是否有至少一个宠物信息可用
            local hasValidPet = false
            for _, slotData in pairs(equippedSlots) do
                if slotData.petInfo then
                    -- 尝试访问宠物信息，确保它已完全加载
                    local success = pcall(function()
                        if slotData.petInfo.HealthValue then
                            hasValidPet = true
                        end
                    end)
                    if success and hasValidPet then
                        break
                    end
                end
            end
            if hasValidPet then
                petLoadSuccess = true
                print(string.format("[自动刷裂缝] 宠物加载成功（尝试 %d/%d）", petLoadRetries + 1, maxPetLoadRetries))
                break
            end
        end
        petLoadRetries = petLoadRetries + 1
        task.wait(0.5)
    end
    if not petLoadSuccess then
        warn("[自动刷裂缝] 警告：宠物加载可能未完成，但继续执行...")
    end

    local exitReason = nil
    local statsUpdated = false
    local function UpdateStatsOnce()
        if statsUpdated then
            return
        end
        statsUpdated = true
        if exitReason == "success" then
            riftStats.success = riftStats.success + 1
            print(string.format("[自动刷裂缝] 地牢完成（成功）统计更新: 总=%d 成功=%d 失败=%d", 
                riftStats.total, riftStats.success, riftStats.failed))
        elseif exitReason == "failed" then
            riftStats.failed = riftStats.failed + 1
            print(string.format("[自动刷裂缝] 地牢完成（失败）统计更新: 总=%d 成功=%d 失败=%d", 
                riftStats.total, riftStats.success, riftStats.failed))
        else
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
        pcall(function()
            if UpdateRiftStats then
                UpdateRiftStats()
            end
        end)
    end

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
        exitReason = "failed"
        UpdateStatsOnce()
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
                -- 根据游戏代码，只需要检测捕捉请求是否已发送（CatchPlayerId 属性），不需要等待动画完成
                local catchStarted = IsCatchStarted()
                if catchStarted then
                    print("[自动刷裂缝] 节点消失，但捕捉已开始（CatchPlayerId 已设置），等待1秒后退出")
                    task.wait(1)  -- 等待1秒确保捕捉完成
                    exitReason = "success"  -- 节点消失但捕捉已开始，算成功
                else
                    print("[自动刷裂缝] 节点消失且无怪物、无捕捉，退出")
                    exitReason = "failed"  -- 节点消失且无怪物，算失败
                end
                break
            end
        end

        -- 检查宠物是否全死（增加验证，防止误判）
        -- 先更新装备列表，确保信息是最新的
        UpdateEquippedSlots()
        local slotCount = GetEquippedSlotCount()
        if slotCount > 0 then
            local deadCount = 0
            local validPetCount = 0  -- 有效宠物数量（有petInfo的）
            for _, slotData in pairs(equippedSlots) do
                if slotData.petInfo then
                    validPetCount = validPetCount + 1
                    -- 验证宠物信息是否有效（防止在加载过程中误判）
                    local isValid = pcall(function()
                        return slotData.petInfo.HealthValue ~= nil
                    end)
                    if isValid and IsPetDead(slotData.petInfo) then
                        deadCount = deadCount + 1
                    end
                else
                    -- 没有petInfo，可能是加载中或已死亡移除
                    -- 为了安全，不立即判断为死亡，而是等待一段时间
                    deadCount = deadCount + 1
                end
            end
            -- 只有当所有有效宠物都死亡，且至少有一个有效宠物时，才判断为全死
            -- 这样可以避免在宠物加载过程中误判
            if validPetCount > 0 and deadCount >= slotCount then
                -- 再次验证，防止误判（等待一小段时间后再次检查）
                task.wait(0.5)
                UpdateEquippedSlots()
                local verifyDeadCount = 0
                local verifyValidCount = 0
                for _, slotData in pairs(equippedSlots) do
                    if slotData.petInfo then
                        verifyValidCount = verifyValidCount + 1
                        local isValid = pcall(function()
                            return slotData.petInfo.HealthValue ~= nil
                        end)
                        if isValid and IsPetDead(slotData.petInfo) then
                            verifyDeadCount = verifyDeadCount + 1
                        end
                    else
                        verifyDeadCount = verifyDeadCount + 1
                    end
                end
                -- 二次验证也确认全死，才真正判断为全死
                if verifyValidCount > 0 and verifyDeadCount >= slotCount then
                    print("[自动刷裂缝] 装备宠物全死（已验证），准备退出")
                    exitReason = "failed"  -- 宠物全死，算失败
                    -- 立即设置回血标志，确保退出后进入recovering状态
                    riftNeedRecover = true
                    healSource = "rift"
                    print("[自动刷裂缝] 已设置回血标志，退出后将进入recovering状态")
                    break
                else
                    print(string.format("[自动刷裂缝] 宠物状态验证：有效=%d 死亡=%d 总数=%d，继续监控", 
                        verifyValidCount, verifyDeadCount, slotCount))
                end
            end
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
                -- 根据游戏代码，只需要检测捕捉请求是否已发送（CatchPlayerId 属性），不需要等待动画完成
                print("[自动刷裂缝] 目标怪物已死亡，检测捕捉状态...")
                local startCheck = tick()
                local catchStarted = false
                -- 持续 2 秒检测捕捉是否已开始（等待服务器设置 CatchPlayerId 属性）
                while tick() - startCheck < 2 do
                    catchStarted = IsCatchStarted()
                    if catchStarted then
                        print("[自动刷裂缝] 检测到捕捉已开始（CatchPlayerId 已设置），可以退出")
                        break
                    end
                    task.wait(0.2)
                end

                if catchStarted then
                    -- 捕捉请求已发送成功，等待1秒确保捕捉完成
                    print("[自动刷裂缝] 捕捉已开始，等待1秒后退出")
                    task.wait(1)  -- 等待1秒确保捕捉完成
                    exitReason = "success"  -- 怪物死亡并已开始捕捉，算成功
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
        -- 如果自动刷裂缝已关闭，立即退出
        if not autoRiftEnabled then
            print("[自动刷裂缝] 检测到已关闭，停止退出地牢")
            UpdateStatsOnce()
            return
        end
        
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
            -- 如果自动刷裂缝已关闭，立即退出
            if not autoRiftEnabled then
                print("[自动刷裂缝] 检测到已关闭，停止等待回到入口位置")
                UpdateStatsOnce()
                return
            end
            
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
        -- 等待退出完成，但如果已关闭则立即退出
        for i = 1, 4 do  -- 2秒，每次0.5秒
            if not autoRiftEnabled then
                print("[自动刷裂缝] 检测到已关闭，停止等待")
                UpdateStatsOnce()
                return
            end
            task.wait(0.5)
        end
    end

    -- 如果自动刷裂缝已关闭，不再执行后续逻辑
    if not autoRiftEnabled then
        print("[自动刷裂缝] 检测到已关闭，停止执行后续逻辑")
        UpdateStatsOnce()
        return
    end

    UpdateStatsOnce()
    
    -- 退出地牢后，检测宠物血量
    -- 如果所有宠物都满血，就不需要去复活点
    UpdateEquippedSlots()
    local slotCount = GetEquippedSlotCount()
    local fullHealthCount = 0
    local deadCount = 0
    
    for _, slotData in pairs(equippedSlots) do
        if slotData.petInfo then
            if IsPetDead(slotData.petInfo) then
                deadCount = deadCount + 1
            elseif IsPetFullHealth(slotData.petInfo) then
                fullHealthCount = fullHealthCount + 1
            end
        else
            deadCount = deadCount + 1
        end
    end
    
    -- 如果所有宠物都满血（至少3个满血且没有死亡的），不需要去复活点
    local allFullHealth = fullHealthCount >= 3 and deadCount == 0
    if allFullHealth then
        print(string.format("[自动刷裂缝] 退出地牢，检测到所有宠物已满血（满血数=%d，死亡数=%d），跳过回血流程", fullHealthCount, deadCount))
        riftNeedRecover = false
        healSource = nil
        SetRiftState("idle")
        
        -- 如果启用了传送到刷怪点，且未启用跳过传送，则传送到刷怪点
        if not skipTeleportToFarming and farmingPosition then
            print(string.format("[自动刷裂缝] 传送到刷怪点: %s", tostring(farmingPosition)))
            task.wait(0.5)
            local farmingSuccess = TeleportTo(farmingPosition, true, "裂缝-回刷怪点")
            if farmingSuccess then
                print("[自动刷裂缝] ✓ 已传送到刷怪点")
            else
                warn("[自动刷裂缝] ⚠ 传送到刷怪点失败")
            end
        elseif skipTeleportToFarming then
            print("[自动刷裂缝] 已启用跳过传送到刷怪点，不传送")
        elseif not farmingPosition then
            print("[自动刷裂缝] 未设置刷怪点，不传送")
        end
        return
    end
    
    -- 有宠物需要回血，设置回血标志
    print(string.format("[自动刷裂缝] 退出地牢，检测到宠物需要回血（满血数=%d，死亡数=%d），进入回血流程", fullHealthCount, deadCount))
    if not riftNeedRecover then
        riftNeedRecover = true
        healSource = "rift"  -- 标记回血来源是裂缝，确保回血后传送到刷怪点
        print("[自动刷裂缝] 设置回血标志（退出时）")
    else
        -- 如果已经设置，确保 healSource 也是正确的
        if not healSource then
            healSource = "rift"
        end
        print("[自动刷裂缝] 回血标志已存在，保持设置")
    end
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
                                warn("[自动刷裂缝] TweenMove回血点失败")
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
                        
                        print(string.format("[自动回血] 检测到 %d 个宠物死亡，保存位置并TweenMove到回血点", deadCount))
                        
                        -- 获取回血点位置
                        local recoverPos = GetRecoverPosition()
                        if recoverPos then
                            if TeleportTo(recoverPos, true, "自动回血-去泉水") then
                                isAtRecoverPoint = true
                                print("[自动回血] 已TweenMove到回血点，等待宠物回血...")
                            else
                                warn("[自动回血] TweenMove失败")
                                -- TweenMove失败，恢复自动战斗状态
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
                        if not skipTeleportToFarming and farmingPosition then
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
                        elseif skipTeleportToFarming then
                            print("[自动刷裂缝] 已启用跳过传送到刷怪点，不传送")
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
                            riftNeedRecover = false
                            SetRiftState("idle")
                        elseif not farmingPosition then
                            print("[自动刷裂缝] 未设置刷怪点，不传送")
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
                        print(string.format("[自动回血] %s，TweenMove到%s（等待时间: %.1f秒）", reason, targetName, waitTime))
                        
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
                                
                                -- 如果还在回血点附近（距离小于20），说明TweenMove失败
                                if finalDistanceToRecover < 20 then
                                    teleportBackAttempts = teleportBackAttempts + 1
                                    warn(string.format("[自动回血] ⚠ TP后仍在回血点附近（距离=%.2f），尝试次数: %d", finalDistanceToRecover, teleportBackAttempts))
                                    
                                    -- 如果多次失败，再尝试 TweenMove 回位（最多 2 次）
                                    if teleportBackAttempts >= 3 then
                                        warn("[自动回血] ⚠ 多次TweenMove失败，再尝试回位...")
                                        local forceOk = MoveToPosition(targetPos, "自动回血-强制回位")
                                        if not forceOk then
                                            MoveToPosition(targetPos, "自动回血-强制回位-重试")
                                        end
                                        task.wait(0.5)
                                        local verifyChar = player.Character
                                        local finalVerifyPos = verifyChar and verifyChar:FindFirstChild("HumanoidRootPart") and verifyChar.HumanoidRootPart.Position or targetPos
                                        local finalDistance = (finalVerifyPos - recoverPos).Magnitude
                                        if finalDistance < 20 then
                                            warn("[自动回血] ⚠ TweenMove回位后仍在回血点附近，清除状态")
                                            isAtRecoverPoint = false
                                            savedPosition = nil
                                            recoverPointArrivalTime = nil
                                            teleportBackAttempts = 0
                                        else
                                            print(string.format("[自动回血] ✓ TweenMove回位完成，距离目标: %.2f", finalDistance))
                                            isAtRecoverPoint = false
                                            savedPosition = nil
                                            recoverPointArrivalTime = nil
                                            teleportBackAttempts = 0
                                        end
                                    end
                                else
                                    -- TweenMove成功，离开回血点
                                    local distanceToTarget = (verifyPos - targetPos).Magnitude
                                    print(string.format("[自动回血] ✓ 已TweenMove到%s（距离回血点: %.2f, 距离目标位置: %.2f）", 
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
                                        if not skipTeleportToFarming and farmingPosition then
                                            print(string.format("[自动刷裂缝] 回血完成，传送到刷怪点: %s", tostring(farmingPosition)))
                                            task.wait(0.5)  -- 等待回传稳定
                                            local farmingSuccess = TeleportTo(farmingPosition, true, "裂缝-回刷怪点")
                                            if farmingSuccess then
                                                print("[自动刷裂缝] ✓ 已传送到刷怪点，准备下一次循环")
                                            else
                                                warn("[自动刷裂缝] ⚠ 传送到刷怪点失败")
                                            end
                                        elseif skipTeleportToFarming then
                                            print("[自动刷裂缝] 已启用跳过传送到刷怪点，不传送")
                                        elseif not farmingPosition then
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
                                print(string.format("[自动回血] ✓ 已TweenMove到%s（无法验证）", targetName))
                                
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
                                    if not skipTeleportToFarming and farmingPosition then
                                        print(string.format("[自动刷裂缝] 回血完成，传送到刷怪点: %s", tostring(farmingPosition)))
                                        task.wait(0.5)  -- 等待回传稳定
                                        local farmingSuccess = TeleportTo(farmingPosition, true, "裂缝-回刷怪点")
                                        if farmingSuccess then
                                            print("[自动刷裂缝] ✓ 已传送到刷怪点，准备下一次循环")
                                        else
                                            warn("[自动刷裂缝] ⚠ 传送到刷怪点失败")
                                        end
                                    elseif skipTeleportToFarming then
                                        print("[自动刷裂缝] 已启用跳过传送到刷怪点，不传送")
                                    elseif not farmingPosition then
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
                            warn(string.format("[自动回血] TweenMove到%s失败（尝试次数: %d）", targetName, teleportBackAttempts))
                            
                            -- 如果多次失败，清除状态，避免卡住
                            if teleportBackAttempts >= 5 then
                                warn("[自动回血] ⚠ 多次TweenMove失败，清除回血点状态")
                                
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

local function UpdateRiftAvailableCount()
    if riftAvailableLabel then
        local count = CountEligibleRifts()
        local newText = string.format("可进入裂缝: %d", count)
        riftAvailableLabel.Text = newText
    else
        warn("[统计更新] riftAvailableLabel 未找到，无法更新UI")
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
    mainFrame.Size = UDim2.new(0, 300, 0, 500)  -- 缩短高度，使用滚动
    mainFrame.Position = UDim2.new(0.5, -150, 0.5, -250)
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
    
    -- 内容区域（使用滚动框）
    local contentFrame = Instance.new("ScrollingFrame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -20, 1, -55)
    contentFrame.Position = UDim2.new(0, 10, 0, 45)
    contentFrame.BackgroundTransparency = 1
    contentFrame.BorderSizePixel = 0
    contentFrame.ScrollBarThickness = 6
    contentFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    contentFrame.CanvasSize = UDim2.new(0, 0, 0, 1050)  -- 内容总高度
    contentFrame.ScrollingDirection = Enum.ScrollingDirection.Y
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
    
    -- 不进入红门开关
    local skipRedPortalButton = Instance.new("TextButton")
    skipRedPortalButton.Name = "SkipRedPortalButton"
    skipRedPortalButton.Size = UDim2.new(1, 0, 0, 40)
    skipRedPortalButton.Position = UDim2.new(0, 0, 0, 310)
    skipRedPortalButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
    skipRedPortalButton.Text = "不进入红门: OFF"
    skipRedPortalButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    skipRedPortalButton.Font = Enum.Font.Gotham
    skipRedPortalButton.TextSize = 16
    skipRedPortalButton.BorderSizePixel = 0
    skipRedPortalButton.Parent = contentFrame

    local skipRedPortalCorner = Instance.new("UICorner")
    skipRedPortalCorner.CornerRadius = UDim.new(0, 6)
    skipRedPortalCorner.Parent = skipRedPortalButton

    -- 不进入红门按钮点击事件
    skipRedPortalButton.MouseButton1Click:Connect(function()
        skipRedPortal = not skipRedPortal
        skipRedPortalButton.Text = skipRedPortal and "不进入红门: ON" or "不进入红门: OFF"
        skipRedPortalButton.BackgroundColor3 = skipRedPortal and Color3.fromRGB(120, 40, 40) or Color3.fromRGB(80, 40, 40)
        print(string.format("[不进入红门] %s", skipRedPortal and "已开启，将跳过 Portal3 和 TmplId 53 的裂缝" or "已关闭"))
        pcall(function()
            if UpdateRiftAvailableCount then
                UpdateRiftAvailableCount()
            end
        end)
    end)
    
    -- 只刷蓝门、紫门和红门开关（排除21和22）
    local onlyBlueAndPurplePortalButton = Instance.new("TextButton")
    onlyBlueAndPurplePortalButton.Name = "OnlyBlueAndPurplePortalButton"
    onlyBlueAndPurplePortalButton.Size = UDim2.new(1, 0, 0, 40)
    onlyBlueAndPurplePortalButton.Position = UDim2.new(0, 0, 0, 360)
    onlyBlueAndPurplePortalButton.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
    onlyBlueAndPurplePortalButton.Text = "只刷蓝紫红门(排除21,22): OFF"
    onlyBlueAndPurplePortalButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    onlyBlueAndPurplePortalButton.Font = Enum.Font.Gotham
    onlyBlueAndPurplePortalButton.TextSize = 14
    onlyBlueAndPurplePortalButton.BorderSizePixel = 0
    onlyBlueAndPurplePortalButton.Parent = contentFrame

    local onlyBlueAndPurplePortalCorner = Instance.new("UICorner")
    onlyBlueAndPurplePortalCorner.CornerRadius = UDim.new(0, 6)
    onlyBlueAndPurplePortalCorner.Parent = onlyBlueAndPurplePortalButton

    -- 只刷蓝门、紫门和红门按钮点击事件
    onlyBlueAndPurplePortalButton.MouseButton1Click:Connect(function()
        onlyBlueAndPurplePortal = not onlyBlueAndPurplePortal
        onlyBlueAndPurplePortalButton.Text = onlyBlueAndPurplePortal and "只刷蓝紫红门(排除21,22): ON" or "只刷蓝紫红门(排除21,22): OFF"
        onlyBlueAndPurplePortalButton.BackgroundColor3 = onlyBlueAndPurplePortal and Color3.fromRGB(80, 50, 120) or Color3.fromRGB(60, 40, 80)
        print(string.format("[只刷蓝紫红门(排除21,22)] %s", onlyBlueAndPurplePortal and "已开启，将只进入 Portal1、Portal2 和 Portal3 的裂缝（排除 TmplId 21 和 22）。注意：如果'不进入红门'开关开启，将不会进入红门。" or "已关闭"))
        pcall(function()
            if UpdateRiftAvailableCount then
                UpdateRiftAvailableCount()
            end
        end)
    end)
    
    -- 跳过传送到刷怪点按钮
    local skipTeleportToFarmingButton = Instance.new("TextButton")
    skipTeleportToFarmingButton.Name = "SkipTeleportToFarmingButton"
    skipTeleportToFarmingButton.Size = UDim2.new(1, 0, 0, 40)
    skipTeleportToFarmingButton.Position = UDim2.new(0, 0, 0, 410)
    skipTeleportToFarmingButton.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    skipTeleportToFarmingButton.Text = "跳过传送到刷怪点: OFF"
    skipTeleportToFarmingButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    skipTeleportToFarmingButton.Font = Enum.Font.Gotham
    skipTeleportToFarmingButton.TextSize = 16
    skipTeleportToFarmingButton.BorderSizePixel = 0
    skipTeleportToFarmingButton.Parent = contentFrame

    local skipTeleportToFarmingCorner = Instance.new("UICorner")
    skipTeleportToFarmingCorner.CornerRadius = UDim.new(0, 6)
    skipTeleportToFarmingCorner.Parent = skipTeleportToFarmingButton

    -- 跳过传送到刷怪点按钮点击事件
    skipTeleportToFarmingButton.MouseButton1Click:Connect(function()
        skipTeleportToFarming = not skipTeleportToFarming
        skipTeleportToFarmingButton.Text = skipTeleportToFarming and "跳过传送到刷怪点: ON" or "跳过传送到刷怪点: OFF"
        skipTeleportToFarmingButton.BackgroundColor3 = skipTeleportToFarming and Color3.fromRGB(80, 80, 120) or Color3.fromRGB(60, 60, 80)
        print(string.format("[跳过传送到刷怪点] %s", skipTeleportToFarming and "已开启，刷裂缝完成后不会传送到刷怪点" or "已关闭，刷裂缝完成后会传送到刷怪点"))
    end)
    
    -- 退出裂缝前关闭自动战斗按钮
    local disableAutoAttackButton = Instance.new("TextButton")
    disableAutoAttackButton.Name = "DisableAutoAttackBeforeExitButton"
    disableAutoAttackButton.Size = UDim2.new(1, 0, 0, 40)
    disableAutoAttackButton.Position = UDim2.new(0, 0, 0, 460)
    disableAutoAttackButton.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    disableAutoAttackButton.Text = "退出裂缝前关闭自动战斗: OFF"
    disableAutoAttackButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    disableAutoAttackButton.Font = Enum.Font.Gotham
    disableAutoAttackButton.TextSize = 16
    disableAutoAttackButton.BorderSizePixel = 0
    disableAutoAttackButton.Parent = contentFrame

    local disableAutoAttackCorner = Instance.new("UICorner")
    disableAutoAttackCorner.CornerRadius = UDim.new(0, 6)
    disableAutoAttackCorner.Parent = disableAutoAttackButton

    -- 退出裂缝前关闭自动战斗按钮点击事件
    disableAutoAttackButton.MouseButton1Click:Connect(function()
        disableAutoAttackBeforeExit = not disableAutoAttackBeforeExit
        disableAutoAttackButton.Text = disableAutoAttackBeforeExit and "退出裂缝前关闭自动战斗: ON" or "退出裂缝前关闭自动战斗: OFF"
        disableAutoAttackButton.BackgroundColor3 = disableAutoAttackBeforeExit and Color3.fromRGB(80, 80, 120) or Color3.fromRGB(60, 60, 80)
        print(string.format("[退出裂缝前关闭自动战斗] %s", disableAutoAttackBeforeExit and "已开启，退出裂缝前会先关闭自动战斗" or "已关闭"))
    end)
    
    -- 传送到刷怪点按钮
    local teleportToFarmingButton = Instance.new("TextButton")
    teleportToFarmingButton.Name = "TeleportToFarmingButton"
    teleportToFarmingButton.Size = UDim2.new(1, 0, 0, 40)
    teleportToFarmingButton.Position = UDim2.new(0, 0, 0, 510)
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
    riftStatsLabel.Position = UDim2.new(0, 0, 0, 510)
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

    -- 可进入裂缝数量标签
    riftAvailableLabel = Instance.new("TextLabel")
    riftAvailableLabel.Name = "RiftAvailableLabel"
    riftAvailableLabel.Size = UDim2.new(1, 0, 0, 40)
    riftAvailableLabel.Position = UDim2.new(0, 0, 0, 560)
    riftAvailableLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    riftAvailableLabel.BorderSizePixel = 0
    riftAvailableLabel.Text = "可进入裂缝: 0"
    riftAvailableLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    riftAvailableLabel.Font = Enum.Font.Gotham
    riftAvailableLabel.TextSize = 14
    riftAvailableLabel.TextXAlignment = Enum.TextXAlignment.Left
    riftAvailableLabel.TextWrapped = true
    riftAvailableLabel.Parent = contentFrame

    local riftAvailableCorner = Instance.new("UICorner")
    riftAvailableCorner.CornerRadius = UDim.new(0, 6)
    riftAvailableCorner.Parent = riftAvailableLabel

    -- ========== 跨服刷静态裂缝 UI ==========
    -- 跨服刷静态裂缝按钮
    local serverHopButton = Instance.new("TextButton")
    serverHopButton.Name = "ServerHopButton"
    serverHopButton.Size = UDim2.new(1, 0, 0, 40)
    serverHopButton.Position = UDim2.new(0, 0, 0, 610)
    serverHopButton.BackgroundColor3 = Color3.fromRGB(100, 60, 100)
    serverHopButton.Text = "跨服刷静态裂缝: OFF"
    serverHopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    serverHopButton.Font = Enum.Font.GothamBold
    serverHopButton.TextSize = 16
    serverHopButton.BorderSizePixel = 0
    serverHopButton.Parent = contentFrame

    local serverHopCorner = Instance.new("UICorner")
    serverHopCorner.CornerRadius = UDim.new(0, 6)
    serverHopCorner.Parent = serverHopButton

    -- 跨服统计标签
    local serverHopStatsLabel = Instance.new("TextLabel")
    serverHopStatsLabel.Name = "ServerHopStatsLabel"
    serverHopStatsLabel.Size = UDim2.new(1, 0, 0, 40)
    serverHopStatsLabel.Position = UDim2.new(0, 0, 0, 660)
    serverHopStatsLabel.BackgroundColor3 = Color3.fromRGB(50, 40, 50)
    serverHopStatsLabel.BorderSizePixel = 0
    serverHopStatsLabel.Text = "跨服统计: 服务器:0 发现:0 完成:0"
    serverHopStatsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    serverHopStatsLabel.Font = Enum.Font.Gotham
    serverHopStatsLabel.TextSize = 14
    serverHopStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
    serverHopStatsLabel.TextWrapped = true
    serverHopStatsLabel.Parent = contentFrame

    local serverHopStatsCorner = Instance.new("UICorner")
    serverHopStatsCorner.CornerRadius = UDim.new(0, 6)
    serverHopStatsCorner.Parent = serverHopStatsLabel

    -- ========== 猎杀Undine UI ==========
    local huntUndineButton = Instance.new("TextButton")
    huntUndineButton.Name = "HuntUndineButton"
    huntUndineButton.Size = UDim2.new(1, 0, 0, 40)
    huntUndineButton.Position = UDim2.new(0, 0, 0, 710)
    huntUndineButton.BackgroundColor3 = Color3.fromRGB(60, 100, 130)
    huntUndineButton.Text = "猎杀Undine: OFF"
    huntUndineButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    huntUndineButton.Font = Enum.Font.GothamBold
    huntUndineButton.TextSize = 16
    huntUndineButton.BorderSizePixel = 0
    huntUndineButton.Parent = contentFrame

    local huntUndineCorner = Instance.new("UICorner")
    huntUndineCorner.CornerRadius = UDim.new(0, 6)
    huntUndineCorner.Parent = huntUndineButton

    -- 猎杀状态标签
    local huntUndineStatusLabel = Instance.new("TextLabel")
    huntUndineStatusLabel.Name = "HuntUndineStatusLabel"
    huntUndineStatusLabel.Size = UDim2.new(1, 0, 0, 30)
    huntUndineStatusLabel.Position = UDim2.new(0, 0, 0, 760)
    huntUndineStatusLabel.BackgroundColor3 = Color3.fromRGB(40, 60, 80)
    huntUndineStatusLabel.BorderSizePixel = 0
    huntUndineStatusLabel.Text = "状态: 等待启动"
    huntUndineStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    huntUndineStatusLabel.Font = Enum.Font.Gotham
    huntUndineStatusLabel.TextSize = 12
    huntUndineStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    huntUndineStatusLabel.Parent = contentFrame

    local huntUndineStatusCorner = Instance.new("UICorner")
    huntUndineStatusCorner.CornerRadius = UDim.new(0, 6)
    huntUndineStatusCorner.Parent = huntUndineStatusLabel

    -- 猎杀统计标签
    local huntUndineStatsLabel = Instance.new("TextLabel")
    huntUndineStatsLabel.Name = "HuntUndineStatsLabel"
    huntUndineStatsLabel.Size = UDim2.new(1, 0, 0, 25)
    huntUndineStatsLabel.Position = UDim2.new(0, 0, 0, 795)
    huntUndineStatsLabel.BackgroundColor3 = Color3.fromRGB(40, 60, 80)
    huntUndineStatsLabel.BorderSizePixel = 0
    huntUndineStatsLabel.Text = "统计: 服务器:0 发现:0 捕捉:0"
    huntUndineStatsLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    huntUndineStatsLabel.Font = Enum.Font.Gotham
    huntUndineStatsLabel.TextSize = 11
    huntUndineStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
    huntUndineStatsLabel.Parent = contentFrame

    local huntUndineStatsCorner = Instance.new("UICorner")
    huntUndineStatsCorner.CornerRadius = UDim.new(0, 6)
    huntUndineStatsCorner.Parent = huntUndineStatsLabel

    -- ========== 寻找Undine UI ==========
    local findUndineButton = Instance.new("TextButton")
    findUndineButton.Name = "FindUndineButton"
    findUndineButton.Size = UDim2.new(1, 0, 0, 40)
    findUndineButton.Position = UDim2.new(0, 0, 0, 830)
    findUndineButton.BackgroundColor3 = Color3.fromRGB(100, 80, 130)
    findUndineButton.Text = "寻找Undine: OFF"
    findUndineButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    findUndineButton.Font = Enum.Font.GothamBold
    findUndineButton.TextSize = 16
    findUndineButton.BorderSizePixel = 0
    findUndineButton.Parent = contentFrame

    local findUndineCorner = Instance.new("UICorner")
    findUndineCorner.CornerRadius = UDim.new(0, 6)
    findUndineCorner.Parent = findUndineButton

    -- 寻找状态标签
    local findUndineStatusLabel = Instance.new("TextLabel")
    findUndineStatusLabel.Name = "FindUndineStatusLabel"
    findUndineStatusLabel.Size = UDim2.new(1, 0, 0, 30)
    findUndineStatusLabel.Position = UDim2.new(0, 0, 0, 880)
    findUndineStatusLabel.BackgroundColor3 = Color3.fromRGB(60, 50, 80)
    findUndineStatusLabel.BorderSizePixel = 0
    findUndineStatusLabel.Text = "状态: 等待启动"
    findUndineStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    findUndineStatusLabel.Font = Enum.Font.Gotham
    findUndineStatusLabel.TextSize = 12
    findUndineStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    findUndineStatusLabel.Parent = contentFrame

    local findUndineStatusCorner = Instance.new("UICorner")
    findUndineStatusCorner.CornerRadius = UDim.new(0, 6)
    findUndineStatusCorner.Parent = findUndineStatusLabel

    -- 寻找统计标签
    local findUndineStatsLabel = Instance.new("TextLabel")
    findUndineStatsLabel.Name = "FindUndineStatsLabel"
    findUndineStatsLabel.Size = UDim2.new(1, 0, 0, 25)
    findUndineStatsLabel.Position = UDim2.new(0, 0, 0, 915)
    findUndineStatsLabel.BackgroundColor3 = Color3.fromRGB(60, 50, 80)
    findUndineStatsLabel.BorderSizePixel = 0
    findUndineStatsLabel.Text = "统计: 服务器:0 发现:0"
    findUndineStatsLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    findUndineStatsLabel.Font = Enum.Font.Gotham
    findUndineStatsLabel.TextSize = 11
    findUndineStatsLabel.TextXAlignment = Enum.TextXAlignment.Left
    findUndineStatsLabel.Parent = contentFrame

    local findUndineStatsCorner = Instance.new("UICorner")
    findUndineStatsCorner.CornerRadius = UDim.new(0, 6)
    findUndineStatsCorner.Parent = findUndineStatsLabel

    -- ========== 退出游戏模式按钮 ==========
    local exitGameButton = Instance.new("TextButton")
    exitGameButton.Name = "ExitGameButton"
    exitGameButton.Size = UDim2.new(1, 0, 0, 40)
    exitGameButton.Position = UDim2.new(0, 0, 0, 950)
    exitGameButton.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
    exitGameButton.Text = "没有就退出游戏: OFF"
    exitGameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    exitGameButton.Font = Enum.Font.GothamBold
    exitGameButton.TextSize = 14
    exitGameButton.BorderSizePixel = 0
    exitGameButton.Parent = contentFrame

    local exitGameCorner = Instance.new("UICorner")
    exitGameCorner.CornerRadius = UDim.new(0, 6)
    exitGameCorner.Parent = exitGameButton

    -- 退出游戏模式说明标签
    local exitGameInfoLabel = Instance.new("TextLabel")
    exitGameInfoLabel.Name = "ExitGameInfoLabel"
    exitGameInfoLabel.Size = UDim2.new(1, 0, 0, 25)
    exitGameInfoLabel.Position = UDim2.new(0, 0, 0, 1000)
    exitGameInfoLabel.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
    exitGameInfoLabel.BorderSizePixel = 0
    exitGameInfoLabel.Text = "没有Undine就退出游戏(手动进私服)"
    exitGameInfoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    exitGameInfoLabel.Font = Enum.Font.Gotham
    exitGameInfoLabel.TextSize = 11
    exitGameInfoLabel.Parent = contentFrame

    local exitGameInfoCorner = Instance.new("UICorner")
    exitGameInfoCorner.CornerRadius = UDim.new(0, 6)
    exitGameInfoCorner.Parent = exitGameInfoLabel

    -- 更新寻找状态显示
    local function UpdateFindUndineStatus(status)
        if findUndineStatusLabel then
            findUndineStatusLabel.Text = "状态: " .. status
        end
    end

    -- 更新寻找统计显示
    local function UpdateFindUndineStats()
        if findUndineStatsLabel then
            findUndineStatsLabel.Text = string.format("统计: 服务器:%d 发现:%d", 
                findUndineStats.serversVisited, findUndineStats.undineFound)
        end
    end

    -- 显示发现Undine的大通知UI
    -- @param undine Undine怪物对象（用于获取特殊属性）
    local function ShowUndineFoundNotification(undine)
        -- 获取当前服务器JobId
        local jobId = game.JobId or "Unknown"

        -- 标记 Undine 存在（用于人数监听）
        undineActive = true
        lastPlayerCount = GetPlayerCount()

        -- 获取特殊属性
        local specialLabel = "普通"
        if undine and undine.ServerNode then
            specialLabel = GetMonsterSpecialLabelByServerNode(undine.ServerNode)
        end

        -- 发送Discord通知（包含特殊属性）
        spawn(function()
            SendDiscordNotification(
                "🎉 发现 Undine!",
                "在服务器中发现了 Undine，快来捕捉！",
                65280,  -- 绿色
                specialLabel
            )
        end)
        
        -- 创建通知UI
        local notificationGui = Instance.new("ScreenGui")
        notificationGui.Name = "UndineFoundNotification"
        notificationGui.ResetOnSpawn = false
        notificationGui.DisplayOrder = 999
        notificationGui.Parent = player:WaitForChild("PlayerGui")
        
        -- 半透明背景
        local bgFrame = Instance.new("Frame")
        bgFrame.Name = "Background"
        bgFrame.Size = UDim2.new(1, 0, 1, 0)
        bgFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        bgFrame.BackgroundTransparency = 0.5
        bgFrame.BorderSizePixel = 0
        bgFrame.Parent = notificationGui
        
        -- 主面板
        local mainFrame = Instance.new("Frame")
        mainFrame.Name = "MainPanel"
        mainFrame.Size = UDim2.new(0, 400, 0, 300)
        mainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
        mainFrame.BackgroundColor3 = Color3.fromRGB(40, 35, 60)
        mainFrame.BorderSizePixel = 0
        mainFrame.Parent = notificationGui
        
        local mainCorner = Instance.new("UICorner")
        mainCorner.CornerRadius = UDim.new(0, 12)
        mainCorner.Parent = mainFrame
        
        -- 标题
        local titleLabel = Instance.new("TextLabel")
        titleLabel.Name = "Title"
        titleLabel.Size = UDim2.new(1, 0, 0, 60)
        titleLabel.Position = UDim2.new(0, 0, 0, 20)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = "🎉 发现 Undine! 🎉"
        titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 32
        titleLabel.Parent = mainFrame
        
        -- JobId显示
        local jobIdLabel = Instance.new("TextLabel")
        jobIdLabel.Name = "JobIdLabel"
        jobIdLabel.Size = UDim2.new(1, -40, 0, 30)
        jobIdLabel.Position = UDim2.new(0, 20, 0, 100)
        jobIdLabel.BackgroundTransparency = 1
        jobIdLabel.Text = "服务器 JobId:"
        jobIdLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        jobIdLabel.Font = Enum.Font.Gotham
        jobIdLabel.TextSize = 14
        jobIdLabel.TextXAlignment = Enum.TextXAlignment.Left
        jobIdLabel.Parent = mainFrame
        
        -- JobId值
        local jobIdValueLabel = Instance.new("TextLabel")
        jobIdValueLabel.Name = "JobIdValue"
        jobIdValueLabel.Size = UDim2.new(1, -40, 0, 40)
        jobIdValueLabel.Position = UDim2.new(0, 20, 0, 130)
        jobIdValueLabel.BackgroundColor3 = Color3.fromRGB(30, 25, 45)
        jobIdValueLabel.Text = jobId
        jobIdValueLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
        jobIdValueLabel.Font = Enum.Font.Code
        jobIdValueLabel.TextSize = 12
        jobIdValueLabel.TextWrapped = true
        jobIdValueLabel.Parent = mainFrame
        
        local jobIdValueCorner = Instance.new("UICorner")
        jobIdValueCorner.CornerRadius = UDim.new(0, 6)
        jobIdValueCorner.Parent = jobIdValueLabel
        
        -- 复制按钮
        local copyButton = Instance.new("TextButton")
        copyButton.Name = "CopyButton"
        copyButton.Size = UDim2.new(0, 150, 0, 45)
        copyButton.Position = UDim2.new(0.5, -160, 0, 200)
        copyButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
        copyButton.Text = "复制 JobId"
        copyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        copyButton.Font = Enum.Font.GothamBold
        copyButton.TextSize = 16
        copyButton.BorderSizePixel = 0
        copyButton.Parent = mainFrame
        
        local copyCorner = Instance.new("UICorner")
        copyCorner.CornerRadius = UDim.new(0, 8)
        copyCorner.Parent = copyButton
        
        copyButton.MouseButton1Click:Connect(function()
            pcall(function()
                setclipboard(jobId)
                copyButton.Text = "✓ 已复制!"
                copyButton.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
                task.wait(1.5)
                copyButton.Text = "复制 JobId"
                copyButton.BackgroundColor3 = Color3.fromRGB(60, 120, 200)
            end)
        end)
        
        -- 关闭按钮
        local closeButton = Instance.new("TextButton")
        closeButton.Name = "CloseButton"
        closeButton.Size = UDim2.new(0, 150, 0, 45)
        closeButton.Position = UDim2.new(0.5, 10, 0, 200)
        closeButton.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
        closeButton.Text = "关闭"
        closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        closeButton.Font = Enum.Font.GothamBold
        closeButton.TextSize = 16
        closeButton.BorderSizePixel = 0
        closeButton.Parent = mainFrame
        
        local closeCorner = Instance.new("UICorner")
        closeCorner.CornerRadius = UDim.new(0, 8)
        closeCorner.Parent = closeButton
        
        closeButton.MouseButton1Click:Connect(function()
            notificationGui:Destroy()
        end)
        
        -- 提示文字
        local tipLabel = Instance.new("TextLabel")
        tipLabel.Name = "Tip"
        tipLabel.Size = UDim2.new(1, -40, 0, 20)
        tipLabel.Position = UDim2.new(0, 20, 0, 260)
        tipLabel.BackgroundTransparency = 1
        tipLabel.Text = "复制JobId后可在私服中加入此服务器"
        tipLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        tipLabel.Font = Enum.Font.Gotham
        tipLabel.TextSize = 12
        tipLabel.Parent = mainFrame
        
        print("[寻找Undine] 已显示通知UI，JobId: " .. jobId)
    end

    -- 更新猎杀状态显示
    local function UpdateHuntUndineStatus(status)
        if huntUndineStatusLabel then
            huntUndineStatusLabel.Text = "状态: " .. status
        end
    end

    -- 更新猎杀统计显示
    local function UpdateHuntUndineStats()
        if huntUndineStatsLabel then
            huntUndineStatsLabel.Text = string.format("统计: 服务器:%d 发现:%d 捕捉:%d", 
                huntUndineStats.serversVisited, huntUndineStats.undineFound, huntUndineStats.catchAttempts)
        end
    end

    -- 更新跨服统计显示
    local function UpdateServerHopStats()
        if serverHopStatsLabel then
            serverHopStatsLabel.Text = string.format("跨服统计: 服务器:%d 发现:%d 完成:%d", 
                serverHopStats.serversVisited, serverHopStats.riftsFound, serverHopStats.riftsCompleted)
        end
    end

    -- 传送到指定区域
    local function TeleportToArea(areaId, areaName)
        print(string.format("[跨服刷裂缝] 传送到区域: %s (ID=%d)", areaName, areaId))
        local success, err = pcall(function()
            if PathTool and PathTool.AreaSystem and PathTool.AreaSystem.ClientTeleportToAreaRegion then
                PathTool.AreaSystem.ClientTeleportToAreaRegion(areaId)
            end
        end)
        if not success then
            warn("[跨服刷裂缝] 区域传送失败:", err)
            return false
        end
        -- 等待传送完成
        task.wait(3)
        return true
    end

    -- 检测当前区域是否有静态裂缝（未进入的）
    local function CheckStaticRiftInCurrentArea()
        local cfg = nil
        if PathTool then
            cfg = rawget(PathTool, "CfgDungeon")
            if type(cfg) ~= "table" then
                cfg = nil
            end
        end
        
        local validNodes = {}
        
        -- 搜索 Area.*.Area.Dungeon 下的静态地牢
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
                                if IsRiftNode(node, cfg) then
                                    -- 静态地牢：检查地牢是否激活
                                    local startTick = node:GetAttribute("DungeonStartTick")
                                    local groupId = node:GetAttribute("DungeonGroupId")
                                    -- 如果属性在父节点上，尝试从父节点获取
                                    if not startTick then
                                        local parent = node.Parent
                                        if parent then
                                            startTick = parent:GetAttribute("DungeonStartTick")
                                            if not groupId then
                                                groupId = parent:GetAttribute("DungeonGroupId")
                                            end
                                        end
                                    end
                                    -- 静态地牢：需要 StartTick 和 GroupId
                                    if startTick and groupId then
                                        -- 检查是否已进入
                                        local isEntered = alreadyEnteredDungeon(node)
                                        if not isEntered then
                                            print(string.format("[跨服刷裂缝] 发现静态裂缝: %s (StartTick=%s, GroupId=%s)", 
                                                node.Name, tostring(startTick), tostring(groupId)))
                                            table.insert(validNodes, {node = node, pos = pos})
                                        else
                                            print(string.format("[跨服刷裂缝] 静态裂缝已进入过: %s", node.Name))
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
                
                -- 也检查 Area.*.ServerZone.Dungeon 路径
                local serverZoneFolder = areaChild:FindFirstChild("ServerZone")
                if serverZoneFolder then
                    local dungeonFolder = serverZoneFolder:FindFirstChild("Dungeon")
                    if dungeonFolder then
                        for _, node in ipairs(dungeonFolder:GetChildren()) do
                            if string.sub(node.Name, 1, 8) == "Dungeon_" then
                                local pos = node:GetPivot().Position
                                if IsRiftNode(node, cfg) then
                                    local startTick = node:GetAttribute("DungeonStartTick")
                                    local groupId = node:GetAttribute("DungeonGroupId")
                                    if not startTick then
                                        local parent = node.Parent
                                        if parent then
                                            startTick = parent:GetAttribute("DungeonStartTick")
                                            if not groupId then
                                                groupId = parent:GetAttribute("DungeonGroupId")
                                            end
                                        end
                                    end
                                    if startTick and groupId then
                                        local isEntered = alreadyEnteredDungeon(node)
                                        if not isEntered then
                                            print(string.format("[跨服刷裂缝] 发现静态裂缝(ServerZone): %s", node.Name))
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
        
        -- 返回第一个找到的静态裂缝
        if #validNodes > 0 then
            local first = validNodes[1]
            return first.node, first.pos
        end
        
        return nil, nil
    end

    -- 切换服务器
    local function HopToNewServer()
        print("[跨服刷裂缝] 准备切换服务器...")
        serverHopStats.serversVisited = serverHopStats.serversVisited + 1
        UpdateServerHopStats()
        
        -- 保存配置，这样新服务器启动时能自动继续
        SaveServerHopConfig()
        
        -- 等待一下确保配置保存完成
        task.wait(0.5)
        
        -- 使用正确的 server hop 方法
        DoServerHop()
    end

    -- 等待所有宠物满血
    local function WaitForFullHealth()
        print("[跨服刷裂缝] 检查宠物血量...")
        UpdateEquippedSlots()
        
        local maxWait = 60  -- 最多等待60秒
        local startTime = tick()
        
        while (tick() - startTime) < maxWait do
            if not serverHopEnabled then
                return false
            end
            
            UpdateEquippedSlots()
            local slotCount = GetEquippedSlotCount()
            local fullHealthCount = 0
            local deadCount = 0
            
            for _, slotData in pairs(equippedSlots) do
                if slotData.petInfo then
                    if IsPetDead(slotData.petInfo) then
                        deadCount = deadCount + 1
                    elseif IsPetFullHealth(slotData.petInfo) then
                        fullHealthCount = fullHealthCount + 1
                    end
                end
            end
            
            -- 如果所有宠物都满血（至少3个满血且没有死亡的）
            if fullHealthCount >= 3 and deadCount == 0 then
                print(string.format("[跨服刷裂缝] 宠物已满血（满血:%d 死亡:%d）", fullHealthCount, deadCount))
                return true
            end
            
            -- 如果有死亡或受伤的宠物，去回血点
            if deadCount > 0 or fullHealthCount < 3 then
                print(string.format("[跨服刷裂缝] 需要回血（满血:%d 死亡:%d），前往回血点...", fullHealthCount, deadCount))
                local recoverPos = GetRecoverPosition()
                if recoverPos then
                    TeleportTo(recoverPos, true, "跨服-回血")
                    -- 在回血点等待
                    task.wait(5)
                end
            end
            
            task.wait(1)
        end
        
        warn("[跨服刷裂缝] 回血超时，继续执行")
        return true
    end

    -- ========== 猎杀Undine功能 ==========
    
    -- 查找指定TmplId的怪物
    local function FindMonsterByTmplId(tmplId)
        if not PathTool or not PathTool.MgrMonsterClient then
            return nil
        end
        
        local foundMonster = nil
        local success = pcall(function()
            PathTool.MgrMonsterClient.IterMonster(function(mInfo)
                if mInfo and mInfo.TmplId == tmplId then
                    -- 检查怪物是否存活
                    local isAlive = true
                    if mInfo.IsAlive then
                        isAlive = mInfo:IsAlive()
                    end
                    if isAlive then
                        foundMonster = mInfo
                        return false  -- 停止遍历
                    end
                end
                return true  -- 继续遍历
            end)
        end)
        
        return foundMonster
    end
    
    -- 攻击指定怪物
    local function AttackMonster(monsterId)
        if not PathTool or not PathTool.MonsterSystem then
            warn("[猎杀Undine] MonsterSystem 未就绪")
            return false
        end
        
        local success, result = pcall(function()
            return PathTool.MonsterSystem.ClientAttackMonsterOnHasAlivePet(monsterId)
        end)
        
        if success then
            print(string.format("[猎杀Undine] 已提交攻击请求: MonsterId=%d", monsterId))
            return true
        else
            warn("[猎杀Undine] 攻击请求失败:", result)
            return false
        end
    end
    
    -- 猎杀Undine主循环
    local function HuntUndineLoop()
        if huntUndineRunning then
            return
        end
        huntUndineRunning = true
        print("[猎杀Undine] 开始循环")
        
        while huntUndineEnabled do
            UpdateHuntUndineStatus("传送到Tideland...")

            -- 0. 先判断是否已在直传坐标附近（对得上就不传送、不等待）
            local character = player.Character
            local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
            local nearTarget = false
            local distToTarget = nil
            if humanoidRootPart then
                distToTarget = (humanoidRootPart.Position - TIDELAND_FALLBACK_POS).Magnitude
                nearTarget = distToTarget <= 12
            end
            print(string.format("[猎杀Undine] 位置检查: dist=%.2f near=%s", distToTarget or -1, tostring(nearTarget)))

            local teleportSuccess = true
            local didTeleport = false

            if not nearTarget then
                -- 1. 不在目标点附近：检查Tideland是否解锁，然后传送
                local isTidelandUnlocked = false
                pcall(function()
                    local gp = PathTool.ClientPlayerManager.GetGamePlayer()
                    if gp and gp.area and gp.area.IsAreaUnlocked then
                        isTidelandUnlocked = gp.area:IsAreaUnlocked(TIDELAND_AREA_ID)
                    end
                end)

                if isTidelandUnlocked then
                    print("[猎杀Undine] 不在目标点附近，且已解锁 -> 区域传送")
                    teleportSuccess = pcall(function()
                        if PathTool and PathTool.AreaSystem and PathTool.AreaSystem.ClientTeleportToAreaRegion then
                            PathTool.AreaSystem.ClientTeleportToAreaRegion(TIDELAND_AREA_ID)
                        end
                    end)
                    didTeleport = teleportSuccess
                else
                    print("[猎杀Undine] 不在目标点附近，且未解锁 -> 坐标直传")
                    UpdateHuntUndineStatus("未解锁，直接传送...")
                    TeleportTo(TIDELAND_FALLBACK_POS, true, "猎杀Undine-直接传送")
                    teleportSuccess = true
                    didTeleport = true
                end
            else
                print("[猎杀Undine] 已在直传坐标附近，跳过传送")
            end

            if not teleportSuccess then
                warn("[猎杀Undine] 传送失败")
                UpdateHuntUndineStatus("传送失败，等待重试...")
                task.wait(5)
                continue
            end

            -- 只有真的发生传送时才等待
            if didTeleport then
                task.wait(5)
            end

            if not huntUndineEnabled then break end
            
            -- 2. 检测Undine
            UpdateHuntUndineStatus("检测Undine...")
            local undine = nil
            local searchTimeout = 10
            local searchStart = tick()
            
            while (tick() - searchStart) < searchTimeout and huntUndineEnabled do
                undine = FindMonsterByTmplId(UNDINE_TMPL_ID)
                if undine then
                    print(string.format("[猎杀Undine] 发现Undine! MonsterId=%d", undine.MonsterId))
                    break
                end
                task.wait(0.5)
            end
            
            if not huntUndineEnabled then break end
            
            if undine then
                -- 统计：发现Undine
                huntUndineStats.undineFound = huntUndineStats.undineFound + 1
                UpdateHuntUndineStats()
                
                -- 3. 找到Undine，传送到怪物位置
                UpdateHuntUndineStatus("发现Undine，传送中...")
                
                if undine.CurrentCFrame then
                    local monsterPos = undine.CurrentCFrame.Position
                    TeleportTo(monsterPos + Vector3.new(0, 3, 0), false, "猎杀Undine-传送到怪物")
                    task.wait(1)
                end
                
                if not huntUndineEnabled then break end
                
                -- 4. 开启自动攻击
                if not GetAutoAttackState() then
                    print("[猎杀Undine] 开启自动攻击...")
                    SetAutoAttackState(true)
                    task.wait(0.3)
                end
                
                -- 5. 提交攻击请求
                UpdateHuntUndineStatus("攻击Undine...")
                AttackMonster(undine.MonsterId)
                
                -- 6. 等待战斗结束并尝试捕捉
                local battleTimeout = 300  -- 最多等待5分钟
                local battleStart = tick()
                local catchAttempted = false  -- 是否已尝试捕捉
                
                while (tick() - battleStart) < battleTimeout and huntUndineEnabled do
                    -- 重新检测Undine是否还存在
                    local currentUndine = FindMonsterByTmplId(UNDINE_TMPL_ID)
                    
                    if not currentUndine then
                        -- Undine消失了，检查是否已经捕捉
                        print("[猎杀Undine] Undine已消失")
                        -- 发送删除请求到Vercel
                        spawn(function()
                            SendDeleteNotification()
                        end)
                        if catchAttempted then
                            print("[猎杀Undine] 捕捉请求已发送，等待完成...")
                            UpdateHuntUndineStatus("捕捉完成!")
                            task.wait(2)
                        else
                            UpdateHuntUndineStatus("Undine已消失...")
                        end
                        break
                    end
                    
                    -- 检查HP
                    local currentHP = nil
                    pcall(function()
                        if currentUndine.ServerNode then
                            currentHP = currentUndine.ServerNode:GetAttribute("HP")
                        end
                    end)
                    
                    -- 检查是否可以捕捉（CatchEndTick属性存在表示可以捕捉）
                    local canCatch = false
                    local catchEndTick = nil
                    pcall(function()
                        if currentUndine.ServerNode then
                            catchEndTick = currentUndine.ServerNode:GetAttribute("CatchEndTick")
                            if catchEndTick then
                                canCatch = true
                            end
                        end
                    end)
                    
                    -- 如果HP为0或可以捕捉，优先尝试捕捉
                    if (currentHP ~= nil and currentHP <= 0) or canCatch then
                        if not catchAttempted then
                            print("[猎杀Undine] 检测到可以捕捉，尝试捕捉Undine...")
                            UpdateHuntUndineStatus("捕捉中...")
                            
                            -- 传送到怪物位置（确保在捕捉范围内）
                            if currentUndine.CurrentCFrame then
                                TeleportTo(currentUndine.CurrentCFrame.Position + Vector3.new(0, 2, 0), false, "猎杀Undine-捕捉")
                                task.wait(0.3)
                            end
                            
                            -- 调用捕捉
                            local catchSuccess = pcall(function()
                                if PathTool and PathTool.MonsterSystem and PathTool.MonsterSystem.ClientCatchMonsterStart then
                                    PathTool.MonsterSystem.ClientCatchMonsterStart(currentUndine.MonsterId)
                                end
                            end)
                            
                            if catchSuccess then
                                print("[猎杀Undine] 已发送捕捉请求")
                                catchAttempted = true
                                -- 统计：捕捉尝试
                                huntUndineStats.catchAttempts = huntUndineStats.catchAttempts + 1
                                UpdateHuntUndineStats()
                                -- 等待捕捉完成
                                task.wait(1)
                                
                                -- 检查捕捉是否成功（检查 CatchPlayerId 属性）
                                local catchStarted = IsCatchStarted()
                                if catchStarted then
                                    print("[猎杀Undine] 捕捉已确认开始，等待完成...")
                                    UpdateHuntUndineStatus("捕捉成功!")
                                    task.wait(2)
                                    break
                                end
                            else
                                warn("[猎杀Undine] 捕捉请求失败")
                            end
                        else
                            -- 已经尝试过捕捉，等待结果
                            UpdateHuntUndineStatus("等待捕捉完成...")
                            task.wait(0.5)
                        end
                    else
                        -- 还在战斗中
                        -- 更新状态显示
                        local hp = currentHP and tostring(currentHP) or "?"
                        UpdateHuntUndineStatus(string.format("战斗中... HP:%s", hp))
                        
                        -- 如果距离太远，重新传送
                        local character = player.Character
                        local hrp = character and character:FindFirstChild("HumanoidRootPart")
                        if hrp and currentUndine.CurrentCFrame then
                            local dist = (hrp.Position - currentUndine.CurrentCFrame.Position).Magnitude
                            if dist > 50 then
                                print("[猎杀Undine] 距离过远，重新传送")
                                TeleportTo(currentUndine.CurrentCFrame.Position + Vector3.new(0, 3, 0), false, "猎杀Undine-追击")
                                task.wait(0.5)
                                -- 重新提交攻击
                                AttackMonster(currentUndine.MonsterId)
                            end
                        end
                    end
                    
                    task.wait(0.5)
                end
                
                -- 关闭自动攻击
                if GetAutoAttackState() then
                    print("[猎杀Undine] 关闭自动攻击...")
                    SetAutoAttackState(false)
                    task.wait(0.3)
                end
                
            else
                -- 没有找到Undine，切换服务器
                print("[猎杀Undine] 当前服务器未发现Undine，准备切换服务器...")
                UpdateHuntUndineStatus("未发现Undine，切换服务器...")
                
                -- 统计：访问服务器
                huntUndineStats.serversVisited = huntUndineStats.serversVisited + 1
                UpdateHuntUndineStats()
                
                -- 保存配置
                SaveHuntUndineConfig()
                task.wait(0.5)
                
                -- 切换服务器
                DoServerHop()
                return  -- 切换服务器后循环会终止
            end
            
            -- Undine被击杀后，等待一段时间再切换服务器
            task.wait(3)
            
            if huntUndineEnabled then
                print("[猎杀Undine] Undine已处理完毕，准备切换服务器...")
                UpdateHuntUndineStatus("切换服务器...")
                
                -- 统计：访问服务器
                huntUndineStats.serversVisited = huntUndineStats.serversVisited + 1
                UpdateHuntUndineStats()
                
                -- 保存配置
                SaveHuntUndineConfig()
                task.wait(0.5)
                
                -- 切换服务器
                DoServerHop()
                return
            end
        end
        
        huntUndineRunning = false
        UpdateHuntUndineStatus("已停止")
        print("[猎杀Undine] 循环结束")
    end

    -- 寻找Undine主循环（发现后显示通知，持续监控直到消失再切换服务器）
    local function FindUndineLoop()
        if findUndineRunning then
            return
        end
        findUndineRunning = true
        print("[寻找Undine] 开始循环")
        
        while findUndineEnabled do
            UpdateFindUndineStatus("传送到Tideland...")

            -- 0. 先判断是否已在直传坐标附近（对得上就不传送、不等待）
            local character = player.Character
            local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
            local nearTarget = false
            local distToTarget = nil
            if humanoidRootPart then
                distToTarget = (humanoidRootPart.Position - TIDELAND_FALLBACK_POS).Magnitude
                nearTarget = distToTarget <= 12
            end
            print(string.format("[寻找Undine] 位置检查: dist=%.2f near=%s", distToTarget or -1, tostring(nearTarget)))

            local teleportSuccess = true
            local didTeleport = false

            if not nearTarget then
                -- 1. 不在目标点附近：检查Tideland是否解锁，然后传送
                local isTidelandUnlocked = false
                pcall(function()
                    local gp = PathTool.ClientPlayerManager.GetGamePlayer()
                    if gp and gp.area and gp.area.IsAreaUnlocked then
                        isTidelandUnlocked = gp.area:IsAreaUnlocked(TIDELAND_AREA_ID)
                    end
                end)

                if isTidelandUnlocked then
                    print("[寻找Undine] 不在目标点附近，且已解锁 -> 区域传送")
                    teleportSuccess = pcall(function()
                        if PathTool and PathTool.AreaSystem and PathTool.AreaSystem.ClientTeleportToAreaRegion then
                            PathTool.AreaSystem.ClientTeleportToAreaRegion(TIDELAND_AREA_ID)
                        end
                    end)
                    didTeleport = teleportSuccess
                else
                    print("[寻找Undine] 不在目标点附近，且未解锁 -> 坐标直传")
                    UpdateFindUndineStatus("未解锁，直接传送...")
                    TeleportTo(TIDELAND_FALLBACK_POS, true, "寻找Undine-直接传送")
                    teleportSuccess = true
                    didTeleport = true
                end
            else
                print("[寻找Undine] 已在直传坐标附近，跳过传送")
            end

            if not teleportSuccess then
                warn("[寻找Undine] 传送失败")
                UpdateFindUndineStatus("传送失败，等待重试...")
                task.wait(5)
                continue
            end

            -- 只有真的发生传送时才等待
            if didTeleport then
                task.wait(5)
            end

            if not findUndineEnabled then break end
            
            -- 增加服务器访问计数
            findUndineStats.serversVisited = findUndineStats.serversVisited + 1
            UpdateFindUndineStats()
            SaveFindUndineConfig()
            
            -- 2. 检测Undine（与猎杀Undine一致：使用FindMonsterByTmplId，循环搜索10秒）
            UpdateFindUndineStatus("检测Undine...")
            local undine = nil
            local searchTimeout = 10
            local searchStart = tick()
            
            while (tick() - searchStart) < searchTimeout and findUndineEnabled do
                undine = FindMonsterByTmplId(UNDINE_TMPL_ID)
                if undine then
                    print(string.format("[寻找Undine] 发现Undine! MonsterId=%d", undine.MonsterId))
                    break
                end
                task.wait(0.5)
            end
            
            if not findUndineEnabled then break end
            
            if undine then
                local undineMonsterId = undine.MonsterId
                UpdateFindUndineStatus("发现Undine! 监控中...")
                
                -- 增加发现计数
                findUndineStats.undineFound = findUndineStats.undineFound + 1
                UpdateFindUndineStats()
                SaveFindUndineConfig()
                
                -- 显示大通知UI
                ShowUndineFoundNotification(undine)
                
                -- [新功能] 持续监控Undine状态（血量、特殊属性）
                print("[寻找Undine] 开始监控Undine状态...")
                local lastNotificationTime = tick()  -- 记录上次Discord通知时间
                local NOTIFICATION_INTERVAL = 60  -- 每60秒重复通知一次
                local notificationCount = 1  -- 第一次通知已经发送
                local monitorStartTime = tick()  -- 监控开始时间

                -- 初始化状态记录
                local lastHpCurrent, lastHpMax, lastUnderAttackState, lastSpecialLabel = nil, nil, nil, nil
                pcall(function()
                    local initialHpInfo = GetMonsterHealthInfo(undine)
                    local initialSpecial = GetMonsterSpecialLabelByServerNode(undine.ServerNode)
                    lastHpCurrent = initialHpInfo.current
                    lastHpMax = initialHpInfo.max
                    lastUnderAttackState = initialHpInfo.isUnderAttack
                    lastSpecialLabel = initialSpecial
                    print(string.format("[寻找Undine] 初始状态: 属性=%s, 被攻击=%s, HP=%s/%s", 
                        initialSpecial, tostring(initialHpInfo.isUnderAttack),
                        tostring(initialHpInfo.current), tostring(initialHpInfo.max)))
                end)

                while findUndineEnabled do
                    local currentUndine = FindMonsterByTmplId(UNDINE_TMPL_ID)
                    if not currentUndine then
                        -- Undine消失了
                        print("[寻找Undine] Undine已消失，准备切换服务器...")
                        spawn(SendDeleteNotification)
                        UpdateFindUndineStatus("Undine消失，切换服务器...")
                        task.wait(1)
                        DoServerHop()
                        return
                    end

                    -- 1. 循环检测血量和特殊属性
                    local hpInfo = GetMonsterHealthInfo(currentUndine)
                    local currentSpecial = GetMonsterSpecialLabelByServerNode(currentUndine.ServerNode)

                    -- 2. 检查状态是否变化（模式B：HP变化也算；SpecialProp 不参与触发，只作为附带字段保持显示）
                    local hpChanged = (lastHpCurrent ~= hpInfo.current) or (lastHpMax ~= hpInfo.max)
                    local underAttackChanged = (lastUnderAttackState ~= hpInfo.isUnderAttack)
                    local shouldSend = hpChanged or underAttackChanged

                    if shouldSend then
                        print(string.format("[寻找Undine] 状态变化: 属性=%s, 被攻击=%s, HP=%s/%s",
                            currentSpecial, tostring(hpInfo.isUnderAttack), tostring(hpInfo.current), tostring(hpInfo.max)))
                        
                        -- 更新缓存的状态（SpecialProp 仅记录，不参与触发）
                        lastUnderAttackState = hpInfo.isUnderAttack
                        lastSpecialLabel = currentSpecial
                        lastHpCurrent = hpInfo.current
                        lastHpMax = hpInfo.max

                        -- 状态变化时发送更新到Vercel（每次都携带 special，保证网站不会丢失）
                        spawn(function()
                            SendMonsterStatusUpdate(hpInfo.isUnderAttack, currentSpecial, hpInfo.current, hpInfo.max)
                        end)
                    end

                    -- 3. 更新UI状态显示
                    local hpDisplay = "?"
                    if hpInfo.current and hpInfo.max then
                        hpDisplay = string.format("%.0f/%.0f", hpInfo.current, hpInfo.max)
                    elseif hpInfo.current then
                        hpDisplay = tostring(hpInfo.current)
                    end
                    local statusText = string.format("Undine存在 [%s] HP:%s (通知#%d/%d)", 
                        currentSpecial, hpDisplay, notificationCount, MAX_UNDINE_NOTIFY)
                    if hpInfo.isUnderAttack then
                        statusText = statusText .. " [战斗中]"
                    end
                    UpdateFindUndineStatus(statusText)

                    -- 4. 检查是否需要强制换服（15次通知）
                    if notificationCount >= MAX_UNDINE_NOTIFY then
                        warn(string.format("[Undine] 通知已达 %d 次，强制换服", notificationCount))
                        spawn(SendDeleteNotification)
                        task.wait(0.5)
                        spawn(DoServerHop)
                        return
                    end

                    -- 5. 定时发送Discord通知（保持不变）
                    if tick() - lastNotificationTime >= NOTIFICATION_INTERVAL then
                        notificationCount = notificationCount + 1
                        local totalSeconds = math.floor(tick() - monitorStartTime)
                        local minutes = math.floor(totalSeconds / 60)
                        local seconds = totalSeconds % 60
                        print(string.format("[寻找Undine] 发送第 %d 次Discord通知", notificationCount))
                        spawn(function()
                            SendDiscordNotification(
                                string.format("🔔 第%d次通知 - Undine 仍然存在!", notificationCount),
                                string.format("Undine持续存在中 (HP: %s)\n已监控 %d分%d秒\n⚠ 超过 %d 次将自动换服",
                                    hpDisplay, minutes, seconds, MAX_UNDINE_NOTIFY
                                ),
                                65280,
                                currentSpecial  -- 添加特殊属性
                            )
                        end)
                        lastNotificationTime = tick()
                    end
                    
                    task.wait(1)  -- 监控间隔1秒
                end
            else
                print("[寻找Undine] 当前服务器未发现Undine，准备切换服务器...")
                UpdateFindUndineStatus("未发现，切换服务器...")
                
                -- 切换服务器
                task.wait(1)
                DoServerHop()
                return
            end
        end
        
        findUndineRunning = false
        UpdateFindUndineStatus("已停止")
        print("[寻找Undine] 循环结束")
    end

    -- 跨服刷静态裂缝主循环
    local function ServerHopLoop()
        if serverHopRunning then
            return
        end
        serverHopRunning = true
        print("[跨服刷静态裂缝] 开始循环")
        
        while serverHopEnabled do
            -- 遍历所有区域检查静态裂缝
            local foundRift = false
            
            for _, areaInfo in ipairs(STATIC_RIFT_AREAS) do
                if not serverHopEnabled then break end
                
                print(string.format("[跨服刷裂缝] 检查区域: %s", areaInfo.name))
                
                -- 传送到该区域
                TeleportToArea(areaInfo.id, areaInfo.name)
                
                -- 等待区域加载
                task.wait(2)
                
                if not serverHopEnabled then break end
                
                -- 检查是否有静态裂缝
                local node, pos = CheckStaticRiftInCurrentArea()
                
                if node and pos then
                    foundRift = true
                    serverHopStats.riftsFound = serverHopStats.riftsFound + 1
                    UpdateServerHopStats()
                    
                    print(string.format("[跨服刷裂缝] 在 %s 发现裂缝，准备进入", areaInfo.name))
                    
                    -- 传送到裂缝位置
                    TeleportTo(pos + Vector3.new(0, 3, 0), true, "跨服-进入裂缝")
                    task.wait(1)
                    
                    -- 尝试进入裂缝（只创建一次，然后验证）
                    local entrySuccess = false
                    
                    -- 创建并启动地牢
                    local createSuccess = TryCreateAndStartDungeon(node)
                    if createSuccess then
                        print("[跨服刷裂缝] 已尝试创建并进入裂缝，等待验证...")
                        
                        -- 验证地牢是否成功进入（最多等待8秒）
                        local verifyStartTime = tick()
                        local maxVerifyTime = 8
                        
                        while (tick() - verifyStartTime) < maxVerifyTime do
                            if not serverHopEnabled then break end
                            
                            -- 检查是否已进入地牢
                            local inBattle = IsInBattle()
                            local isEnteredNow = alreadyEnteredDungeon(node)
                            
                            if inBattle or isEnteredNow then
                                entrySuccess = true
                                print("[跨服刷裂缝] ✓ 地牢进入验证成功")
                                break
                            end
                            
                            task.wait(0.3)
                        end
                        
                        if not entrySuccess then
                            warn("[跨服刷裂缝] ⚠ 地牢进入验证超时")
                        end
                        
                        -- 关闭地牢队伍界面
                        task.wait(0.3)
                        pcall(function()
                            if PathTool and PathTool.ViewManager then
                                PathTool.ViewManager.CloseView("DungeonTeamView")
                            end
                        end)
                    else
                        warn("[跨服刷裂缝] 创建地牢失败")
                    end
                    
                    if entrySuccess then
                        print("[跨服刷裂缝] 成功进入裂缝，开始战斗监控")
                        
                        -- 进入裂缝后开启自动攻击
                        if not GetAutoAttackState() then
                            print("[跨服刷裂缝] 开启自动攻击...")
                            SetAutoAttackState(true)
                        end
                        
                        -- 等待怪物加载
                        print("[跨服刷裂缝] 等待怪物加载...")
                        task.wait(3)
                        
                        -- 查找目标怪物
                        local targetMonster = nil
                        local monsterSearchTimeout = 10
                        local monsterSearchStart = tick()
                        
                        while (tick() - monsterSearchStart) < monsterSearchTimeout do
                            if not serverHopEnabled then break end
                            targetMonster = GetNearestMonsterInfo()
                            if targetMonster then
                                print("[跨服刷裂缝] 找到目标怪物")
                                break
                            end
                            task.wait(0.5)
                        end
                        
                        if targetMonster then
                            -- 传送到怪物位置
                            if targetMonster.CurrentCFrame then
                                local monsterPos = targetMonster.CurrentCFrame.Position
                                TeleportTo(monsterPos, false, "跨服-传送到怪物")
                                task.wait(0.5)
                            end
                        end
                        
                        -- 主循环：监控战斗状态
                        local battleTimeout = 180  -- 最多等待3分钟
                        local battleStart = tick()
                        local battleCompleted = false
                        
                        while (tick() - battleStart) < battleTimeout and serverHopEnabled do
                            -- 检查是否还在战斗中
                            if not IsInBattle() then
                                print("[跨服刷裂缝] 战斗已结束（不在战斗中）")
                                battleCompleted = true
                                break
                            end
                            
                            -- 更新目标怪物
                            targetMonster = GetNearestMonsterInfo()
                            
                            if targetMonster then
                                -- 检查怪物是否死亡
                                local monsterAlive = true
                                pcall(function()
                                    if targetMonster.IsAlive then
                                        monsterAlive = targetMonster:IsAlive()
                                    elseif targetMonster.ServerNode then
                                        local hp = targetMonster.ServerNode:GetAttribute("HP")
                                        monsterAlive = hp and hp > 0
                                    end
                                end)
                                
                                if not monsterAlive then
                                    print("[跨服刷裂缝] 怪物已死亡")
                                    -- 等待捕捉完成
                                    task.wait(2)
                                    
                                    -- 检查捕捉状态
                                    local catchStarted = IsCatchStarted()
                                    if catchStarted then
                                        print("[跨服刷裂缝] 捕捉已开始，等待1秒后退出")
                                        task.wait(1)
                                    end
                                    battleCompleted = true
                                    break
                                end
                            else
                                -- 没有怪物了，可能已经完成
                                print("[跨服刷裂缝] 未找到怪物，检查战斗状态")
                                task.wait(1)
                                if not IsInBattle() then
                                    print("[跨服刷裂缝] 确认战斗结束")
                                    battleCompleted = true
                                    break
                                end
                            end
                            
                            -- 检查宠物是否全死
                            UpdateEquippedSlots()
                            local slotCount = GetEquippedSlotCount()
                            local deadCount = 0
                            for _, slotData in pairs(equippedSlots) do
                                if slotData.petInfo then
                                    if IsPetDead(slotData.petInfo) then
                                        deadCount = deadCount + 1
                                    end
                                end
                            end
                            if slotCount > 0 and deadCount >= slotCount then
                                print("[跨服刷裂缝] 所有宠物已死亡，退出战斗")
                                battleCompleted = true
                                break
                            end
                            
                            task.wait(0.5)
                        end
                        
                        if not battleCompleted then
                            warn("[跨服刷裂缝] 战斗超时")
                        end
                        
                        -- 退出地牢前关闭自动攻击（防止在外面被怪物拦住）
                        if GetAutoAttackState() then
                            print("[跨服刷裂缝] 关闭自动攻击...")
                            SetAutoAttackState(false)
                            task.wait(0.3)
                        end
                        
                        -- 退出地牢
                        print("[跨服刷裂缝] 退出地牢...")
                        for i = 1, 3 do
                            if LeaveArena() then
                                print("[跨服刷裂缝] 退出成功")
                                break
                            end
                            task.wait(0.5)
                        end
                        task.wait(2)
                        
                        serverHopStats.riftsCompleted = serverHopStats.riftsCompleted + 1
                        UpdateServerHopStats()
                        print("[跨服刷裂缝] 裂缝完成")
                    else
                        warn("[跨服刷裂缝] 进入裂缝失败")
                    end
                    
                    -- 裂缝完成后，检查并等待满血
                    if serverHopEnabled then
                        WaitForFullHealth()
                    end
                    
                    -- 完成后切换服务器
                    if serverHopEnabled then
                        print("[跨服刷裂缝] 准备切换服务器...")
                        task.wait(1)
                        HopToNewServer()
                        return  -- 切换服务器后循环会终止
                    end
                end
            end
            
            -- 如果所有区域都没有找到裂缝，切换服务器
            if not foundRift and serverHopEnabled then
                print("[跨服刷裂缝] 当前服务器未发现可进入的静态裂缝，切换服务器")
                task.wait(1)
                HopToNewServer()
                return  -- 切换服务器后循环会终止
            end
            
            task.wait(1)
        end
        
        serverHopRunning = false
        print("[跨服刷静态裂缝] 循环结束")
    end

    -- 跨服刷静态裂缝按钮点击事件
    serverHopButton.MouseButton1Click:Connect(function()
        serverHopEnabled = not serverHopEnabled
        if serverHopEnabled then
            serverHopButton.Text = "跨服刷静态裂缝: ON"
            serverHopButton.BackgroundColor3 = Color3.fromRGB(150, 80, 150)
            print("[跨服刷静态裂缝] 已启用")
            
            -- 保存配置
            SaveServerHopConfig()
            
            -- 启动循环
            spawn(ServerHopLoop)
        else
            serverHopButton.Text = "跨服刷静态裂缝: OFF"
            serverHopButton.BackgroundColor3 = Color3.fromRGB(100, 60, 100)
            serverHopRunning = false
            print("[跨服刷静态裂缝] 已禁用")
            
            -- 删除配置文件
            DeleteServerHopConfig()
        end
    end)

    -- 猎杀Undine按钮点击事件
    -- 初始化猎杀统计显示
    UpdateHuntUndineStats()
    
    huntUndineButton.MouseButton1Click:Connect(function()
        huntUndineEnabled = not huntUndineEnabled
        if huntUndineEnabled then
            huntUndineButton.Text = "猎杀Undine: ON"
            huntUndineButton.BackgroundColor3 = Color3.fromRGB(80, 130, 160)
            print("[猎杀Undine] 已启用")
            UpdateHuntUndineStatus("启动中...")
            UpdateHuntUndineStats()
            
            -- 保存配置
            SaveHuntUndineConfig()
            
            -- 启动循环
            spawn(HuntUndineLoop)
        else
            huntUndineButton.Text = "猎杀Undine: OFF"
            huntUndineButton.BackgroundColor3 = Color3.fromRGB(60, 100, 130)
            huntUndineRunning = false
            print("[猎杀Undine] 已禁用")
            UpdateHuntUndineStatus("已停止")
            
            -- 删除配置
            DeleteHuntUndineConfig()
        end
    end)
    
    -- 检查是否有保存的猎杀Undine配置（用于服务器切换后自动继续）
    local savedHuntConfig = LoadHuntUndineConfig()
    if savedHuntConfig and savedHuntConfig.enabled then
        print("[猎杀Undine] 检测到保存的配置，准备自动启用")
        
        -- 恢复统计
        if savedHuntConfig.stats then
            huntUndineStats = savedHuntConfig.stats
            UpdateHuntUndineStats()
        end
        
        -- 等待游戏完全加载后再启动
        spawn(function()
            local loaded = WaitForGameFullyLoaded(60)
            
            if not loaded then
                warn("[猎杀Undine] 游戏加载超时，但仍尝试启动")
            end
            
            task.wait(2)
            
            if not huntUndineEnabled then
                huntUndineEnabled = true
                huntUndineButton.Text = "猎杀Undine: ON"
                huntUndineButton.BackgroundColor3 = Color3.fromRGB(80, 130, 160)
                UpdateHuntUndineStatus("自动启动中...")
                UpdateHuntUndineStats()
                print("[猎杀Undine] 自动启用完成，开始循环")
                spawn(HuntUndineLoop)
            end
        end)
    end

    -- 寻找Undine按钮点击事件
    -- 初始化寻找统计显示
    UpdateFindUndineStats()
    
    findUndineButton.MouseButton1Click:Connect(function()
        findUndineEnabled = not findUndineEnabled
        if findUndineEnabled then
            findUndineButton.Text = "寻找Undine: ON"
            findUndineButton.BackgroundColor3 = Color3.fromRGB(130, 100, 160)
            print("[寻找Undine] 已启用")
            UpdateFindUndineStatus("启动中...")
            UpdateFindUndineStats()
            
            -- 保存配置
            SaveFindUndineConfig()
            
            -- 启动循环
            spawn(FindUndineLoop)
        else
            findUndineButton.Text = "寻找Undine: OFF"
            findUndineButton.BackgroundColor3 = Color3.fromRGB(100, 80, 130)
            findUndineRunning = false
            print("[寻找Undine] 已禁用")
            UpdateFindUndineStatus("已停止")
            
            -- 删除配置
            DeleteFindUndineConfig()
        end
    end)
    
    -- 检查是否有保存的寻找Undine配置（用于服务器切换后自动继续）
    local savedFindConfig = LoadFindUndineConfig()
    if savedFindConfig and savedFindConfig.enabled then
        print("[寻找Undine] 检测到保存的配置，准备自动启用")
        
        -- 恢复统计
        if savedFindConfig.stats then
            findUndineStats = savedFindConfig.stats
            UpdateFindUndineStats()
        end
        
        -- 等待游戏完全加载后再启动
        spawn(function()
            local loaded = WaitForGameFullyLoaded(60)
            
            if not loaded then
                warn("[寻找Undine] 游戏加载超时，但仍尝试启动")
            end
            
            task.wait(2)
            
            if not findUndineEnabled then
                findUndineEnabled = true
                findUndineButton.Text = "寻找Undine: ON"
                findUndineButton.BackgroundColor3 = Color3.fromRGB(130, 100, 160)
                UpdateFindUndineStatus("自动启动中...")
                UpdateFindUndineStats()
                print("[寻找Undine] 自动启用完成，开始循环")
                spawn(FindUndineLoop)
            end
        end)
    end

    -- 退出游戏模式按钮点击事件
    exitGameButton.MouseButton1Click:Connect(function()
        exitGameMode = not exitGameMode
        if exitGameMode then
            exitGameButton.Text = "没有就退出游戏: ON"
            exitGameButton.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
            print("[退出游戏模式] 已启用 - 没有Undine将退出游戏")
            
            -- 保存配置
            SaveExitGameConfig()
        else
            exitGameButton.Text = "没有就退出游戏: OFF"
            exitGameButton.BackgroundColor3 = Color3.fromRGB(100, 50, 50)
            print("[退出游戏模式] 已禁用 - 换服将使用正常服务器列表")
            
            -- 删除配置
            DeleteExitGameConfig()
        end
    end)
    
    -- 检查是否有保存的退出游戏模式配置
    local savedExitConfig = LoadExitGameConfig()
    if savedExitConfig and savedExitConfig.enabled then
        print("[退出游戏模式] 检测到保存的配置，恢复退出游戏模式")
        exitGameMode = true
        exitGameButton.Text = "没有就退出游戏: ON"
        exitGameButton.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
    end

    -- 初始化跨服统计
    UpdateServerHopStats()
    
    -- 检查是否有保存的跨服刷裂缝配置（用于服务器切换后自动继续）
    local savedConfig = LoadServerHopConfig()
    if savedConfig and savedConfig.enabled then
        print("[跨服刷静态裂缝] 检测到保存的配置，准备自动启用")
        
        -- 恢复统计
        if savedConfig.stats then
            serverHopStats = savedConfig.stats
            UpdateServerHopStats()
        end
        
        -- 等待游戏完全加载后再启动
        spawn(function()
            -- 等待游戏完全加载（最多等待60秒）
            local loaded = WaitForGameFullyLoaded(60)
            
            if not loaded then
                warn("[跨服刷静态裂缝] 游戏加载超时，但仍尝试启动")
            end
            
            -- 额外等待2秒确保UI等都准备好
            task.wait(2)
            
            if not serverHopEnabled then  -- 防止重复启用
                serverHopEnabled = true
                serverHopButton.Text = "跨服刷静态裂缝: ON"
                serverHopButton.BackgroundColor3 = Color3.fromRGB(150, 80, 150)
                UpdateServerHopStats()
                print("[跨服刷静态裂缝] 自动启用完成，开始循环")
                spawn(ServerHopLoop)
            end
        end)
    end

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
    UpdateRiftAvailableCount()

    -- 自动刷裂缝循环
    local function AutoRiftLoop()
        if autoRiftRunning then
            return
        end
        autoRiftRunning = true
        riftWasInBattle = nil
        while autoRiftEnabled do
            pcall(function()
                if UpdateRiftAvailableCount then
                    UpdateRiftAvailableCount()
                end
            end)
            if not IsRiftActive() then
                riftWasInBattle = nil
                -- 如果正在回血中或正在地牢中，不要清除回血状态
                -- 因为 MonitorRiftDungeon 可能在设置 riftNeedRecover 后还没有设置 riftState
                if riftState ~= "recovering" and riftState ~= "in_dungeon" then
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
                    
                    -- 等待传送稳定
                    task.wait(0.5)
                    
                    -- 再次验证节点仍然有效（防止在传送过程中节点消失或被其他玩家占用）
                    if not node.Parent then
                        warn("[自动刷裂缝] 节点在传送过程中消失，跳过")
                        SetRiftState("idle")
                        task.wait(1)
                        continue
                    end
                    
                    -- 再次检查是否已进入（防止在传送过程中被其他玩家占用）
                    local isEnteredAfterTeleport = alreadyEnteredDungeon(node)
                    if isEnteredAfterTeleport then
                        print(string.format("[自动刷裂缝] 节点 %s 在传送后已进入过，跳过", node.Name))
                        SetRiftState("idle")
                        lastRiftEnterTick = tick()
                        task.wait(2)
                        continue
                    end
                    
                    -- 打开地牢队伍界面
                    task.wait(0.3)
                    local openViewOk = TryOpenDungeonTeamView(node)
                    if openViewOk then
                        print("[自动刷裂缝] 已尝试打开裂缝界面")
                        -- 等待界面打开
                        task.wait(0.5)
                    else
                        warn("[自动刷裂缝] 打开裂缝界面失败，但继续尝试创建地牢")
                    end
                    
                    -- 创建并启动地牢
                    local createStartOk = TryCreateAndStartDungeon(node)
                    if createStartOk then
                        print("[自动刷裂缝] 已尝试创建并进入裂缝")
                        -- 增加总计数
                        riftStats.total = riftStats.total + 1
                        
                        -- 验证地牢是否成功进入（等待并检查）
                        local entryVerified = false
                        local verifyStartTime = tick()
                        local maxVerifyTime = 5  -- 最多等待5秒验证
                        
                        print("[自动刷裂缝] 等待验证地牢进入...")
                        while tick() - verifyStartTime < maxVerifyTime do
                            -- 检查是否已进入地牢（通过 IsInBattle 或检查地牢状态）
                            local inBattle = IsInBattle()
                            -- 也可以检查节点是否标记为已进入
                            local isEnteredNow = alreadyEnteredDungeon(node)
                            
                            if inBattle or isEnteredNow then
                                entryVerified = true
                                print("[自动刷裂缝] ✓ 地牢进入验证成功")
                                break
                            end
                            
                            task.wait(0.3)
                        end
                        
                        if not entryVerified then
                            warn("[自动刷裂缝] ⚠ 地牢进入验证超时，但继续执行（可能已进入但验证失败）")
                        end
                        
                        -- 关闭地牢队伍界面
                        task.wait(0.3)
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
                        -- 失败后传送回刷怪点，防止卡死（除非启用了跳过传送）
                        if not skipTeleportToFarming and farmingPosition then
                            print(string.format("[自动刷裂缝] 进入失败，传送回刷怪点: %s", tostring(farmingPosition)))
                            task.wait(0.5)  -- 等待界面关闭
                            local farmingSuccess = TeleportTo(farmingPosition, true, "裂缝失败-回刷怪点")
                            if farmingSuccess then
                                print("[自动刷裂缝] ✓ 已传送回刷怪点")
                            else
                                warn("[自动刷裂缝] ⚠ 传送回刷怪点失败")
                            end
                        elseif skipTeleportToFarming then
                            print("[自动刷裂缝] 进入失败，已启用跳过传送到刷怪点，不传送")
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
        -- 循环退出时，重置状态和标志
        autoRiftRunning = false
        if riftState ~= "idle" then
            SetRiftState("idle")
            print("[自动刷裂缝] 循环退出，状态已重置为idle")
        end
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
            autoRiftRunning = false  -- 立即重置运行标志
            SetRiftState("idle")  -- 立即重置状态为idle，避免卡死
            print("[自动刷裂缝] 已禁用，状态已重置为idle")

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
    
    -- 宠物状态显示（放在状态标签下方）
    local petStatusLabel = Instance.new("TextLabel")
    petStatusLabel.Name = "PetStatusLabel"
    petStatusLabel.Size = UDim2.new(1, 0, 0, 50)
    petStatusLabel.Position = UDim2.new(0, 0, 0, 100)
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
    
    -- 设置区域加载监听器（用于检测静态裂缝）
    -- 注意：静态裂缝依赖于区域加载，只有玩家附近的区域才会被加载
    -- 通过监听区域加载事件，可以在新区域加载时自动检测静态裂缝
    task.wait(2)  -- 等待一下，确保 workspace.Area 已存在
    SetupAreaLoadListener()
    
    -- 扩大自动捕捉范围
    ExpandAutoCatchRange()
    
    -- 减少90%搜索间隔
    ReduceSearchInterval()
    
    -- 减少90%捕捉延迟
    ReduceCatchDelay()
    
    -- 减少90%拾取延迟
    ReducePickUpDelay()
    
    -- 减少90%首次搜索延迟
    ReduceFirstSearchDelay()
    
    -- 增加宠物回玩家速度（设置为200）
    IncreasePetBackToPlayerSpeed()
    
    wait(1)
    CreateUI()
    
    -- 启动后自动设定一次刷怪点
    task.spawn(function()
        task.wait(2)  -- 等待角色加载
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            farmingPosition = character.HumanoidRootPart.Position
            print(string.format("[自动设定刷怪点] 已自动记录当前位置为刷怪点: %s", tostring(farmingPosition)))
            
            -- 更新UI按钮显示（如果UI已创建）
            task.wait(0.5)  -- 等待UI完全创建
            local screenGui = player.PlayerGui:FindFirstChild("PetCaptureUI")
            if screenGui then
                local mainFrame = screenGui:FindFirstChild("MainFrame")
                if mainFrame then
                    local contentFrame = mainFrame:FindFirstChild("ContentFrame")
                    if contentFrame then
                        local recordFarmingButton = contentFrame:FindFirstChild("RecordFarmingButton")
                        if recordFarmingButton then
                            recordFarmingButton.Text = string.format("记录刷怪点: %.0f,%.0f,%.0f", 
                                farmingPosition.X, farmingPosition.Y, farmingPosition.Z)
                            recordFarmingButton.BackgroundColor3 = Color3.fromRGB(40, 100, 40)
                        end
                    end
                end
            end
        else
            warn("[自动设定刷怪点] ⚠ 角色未就绪，无法自动设定刷怪点")
        end
    end)
end)

