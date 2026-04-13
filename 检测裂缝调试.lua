-- 裂缝检测调试脚本
-- 打印所有地牢节点和裂缝检测信息

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- 加载 PathTool
local PathTool
local function LoadPathTool()
    if _G.PathTool then
        return _G.PathTool
    end
    local ok, mod = pcall(function()
        local inst = ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("PathTool")
        if inst and inst:IsA("ModuleScript") then
            return require(inst)
        end
        return nil
    end)
    if ok and mod then
        _G.PathTool = mod
        return mod
    end
    return nil
end

PathTool = LoadPathTool()
if not PathTool then
    error("[调试] PathTool 未找到")
end

-- 获取 CfgDungeon
local cfg = nil
if PathTool then
    cfg = rawget(PathTool, "CfgDungeon")
    if type(cfg) ~= "table" then
        cfg = nil
    end
end

-- 检测是否为裂缝节点
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
        local val = tostring(v)
        if string.find(string.lower(key), "rift") or string.find(key, "裂缝") then
            return true
        end
        if string.find(string.lower(val), "rift") or string.find(val, "裂缝") then
            return true
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

-- 检查是否已进入
local function alreadyEnteredDungeon(node)
    local gp = PathTool.ClientPlayerManager.GetGamePlayer()
    if not gp or not gp.dungeon or not node then
        return false
    end
    local dynamicKey = node:GetAttribute("DungeonDynamicKey")
    local startTick = node:GetAttribute("DungeonStartTick")
    if dynamicKey and startTick and gp.dungeon.IsDynamicEntered then
        local ok, res = pcall(function()
            return gp.dungeon:IsDynamicEntered(dynamicKey, startTick)
        end)
        return ok and res or false
    end
    -- 对于静态地牢，检查 IsEntered
    local groupId = node:GetAttribute("DungeonGroupId")
    local useMem = node:GetAttribute("DungeonUseMem")
    if groupId and startTick and gp.dungeon.IsEntered then
        local ok, res = pcall(function()
            return gp.dungeon:IsEntered(groupId, startTick, useMem)
        end)
        return ok and res or false
    end
    return false
endwwwwwwwwww

-- 检查能否进入地牢
local function CanEnterDungeon(node)
    if not node then
        return false, "节点不存在"
    end
    
    -- 检查是否已进入
    if alreadyEnteredDungeon(node) then
        return false, "已进入过"
    end
    
    -- 检查 StartTick（地牢是否激活）
    local startTick = node:GetAttribute("DungeonStartTick")
    if not startTick then
        return false, "地牢未激活（无StartTick）"
    end
    
    -- 检查 SyncKey（用于打开UI）
    local syncKey = node:GetAttribute("DungeonSyncObjectKey")
    if not syncKey then
        return false, "缺少SyncKey（无法打开UI）"
    end
    
    -- 检查 TmplId（地牢配置）
    local tmplId = node:GetAttribute("DungeonTmplId")
    if not tmplId then
        return false, "缺少TmplId（无配置）"
    end
    
    -- 对于动态地牢，需要 DynamicKey
    local dynamicKey = node:GetAttribute("DungeonDynamicKey")
    if dynamicKey then
        return true, "可以进入（动态地牢）"
    end
    
    -- 对于静态地牢，需要 GroupId
    local groupId = node:GetAttribute("DungeonGroupId")
    if groupId then
        return true, "可以进入（静态地牢）"
    end
    
    return true, "可以进入（缺少Key但其他条件满足）"
end

-- 搜索所有可能的地牢节点位置
local function FindAllDungeonNodes()
    local nodes = {}
    
    -- 方法1: 在 DynamicDungeon 下查找（动态地牢）
    local root = workspace:FindFirstChild("DynamicDungeon")
    if root then
        for _, node in ipairs(root:GetChildren()) do
            table.insert(nodes, {node = node, source = "DynamicDungeon"})
        end
    end
    
    -- 方法1.5: 在 Area.*.ServerZone.Dungeon 下查找（静态地牢）
    local areaFolder = workspace:FindFirstChild("Area")
    if areaFolder then
        for _, areaChild in ipairs(areaFolder:GetChildren()) do
            local serverZone = areaChild:FindFirstChild("ServerZone")
            if serverZone then
                local dungeonFolder = serverZone:FindFirstChild("Dungeon")
                if dungeonFolder then
                    for _, dungeonNode in ipairs(dungeonFolder:GetChildren()) do
                        -- 检查名称格式是否为 Dungeon_XXXX
                        if string.sub(dungeonNode.Name, 1, 8) == "Dungeon_" then
                            -- 检查是否已经有这个节点（避免重复）
                            local exists = false
                            for _, n in ipairs(nodes) do
                                if n.node == dungeonNode then
                                    exists = true
                                    break
                                end
                            end
                            if not exists then
                                table.insert(nodes, {node = dungeonNode, source = string.format("Area.%s.ServerZone.Dungeon", areaChild.Name)})
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- 方法2: 在 workspace 中搜索所有包含 "Dungeon" 的节点
    for _, obj in ipairs(workspace:GetDescendants()) do
        local name = obj.Name or ""
        if (string.find(string.lower(name), "dungeon") or 
            string.find(name, "地牢") or 
            string.find(string.lower(name), "rift") or 
            string.find(name, "裂缝")) and
            obj:IsA("BasePart") or obj:IsA("Model") then
            -- 检查是否已经有这个节点（避免重复）
            local exists = false
            for _, n in ipairs(nodes) do
                if n.node == obj then
                    exists = true
                    break
                end
            end
            if not exists then
                table.insert(nodes, {node = obj, source = "workspace搜索"})
            end
        end
    end
    
    -- 方法3: 搜索用户当前位置附近的所有节点（1000范围内）
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local playerPos = character.HumanoidRootPart.Position
        for _, obj in ipairs(workspace:GetDescendants()) do
            if (obj:IsA("BasePart") or obj:IsA("Model")) then
                local objPos = obj:IsA("BasePart") and obj.Position or (obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position)
                local dist = (objPos - playerPos).Magnitude
                if dist <= 1000 then
                    -- 检查是否有地牢相关属性
                    local tmplId = obj:GetAttribute("DungeonTmplId")
                    local dynamicKey = obj:GetAttribute("DungeonDynamicKey")
                    local startTick = obj:GetAttribute("DungeonStartTick")
                    if tmplId or dynamicKey or startTick then
                        -- 检查是否已经有这个节点
                        local exists = false
                        for _, n in ipairs(nodes) do
                            if n.node == obj then
                                exists = true
                                break
                            end
                        end
                        if not exists then
                            table.insert(nodes, {node = obj, source = string.format("附近(%d米)", math.floor(dist))})
                        end
                    end
                end
            end
        end
    end
    
    return nodes
end

-- 打印所有地牢节点信息
local function PrintAllDungeonNodes()
    print("\n[调试] ========== 地牢节点检测开始 ==========")
    
    -- 搜索所有可能的地牢节点
    local allFoundNodes = FindAllDungeonNodes()
    print(string.format("[调试] 搜索到 %d 个可能的地牢节点", #allFoundNodes))
    
    local allNodes = {}
    local riftNodes = {}
    local enteredNodes = {}
    
    for _, foundNode in ipairs(allFoundNodes) do
        local node = foundNode.node
        local nodeInfo = {
            node = node,
            name = node.Name,
            source = foundNode.source,
            tmplId = node:GetAttribute("DungeonTmplId"),
            dynamicKey = node:GetAttribute("DungeonDynamicKey"),
            startTick = node:GetAttribute("DungeonStartTick"),
            syncKey = node:GetAttribute("DungeonSyncObjectKey"),
            pos = nil,
            isRift = false,
            entered = false,
            cfgName = nil,
            allAttrs = {}
        }
        
        -- 获取位置
        if node:IsA("BasePart") then
            nodeInfo.pos = node.Position
        elseif node:IsA("Model") then
            if node.PrimaryPart then
                nodeInfo.pos = node.PrimaryPart.Position
            else
                nodeInfo.pos = node:GetPivot().Position
            end
        else
            nodeInfo.pos = node:GetPivot().Position
        end
        
        -- 获取所有属性
        local attrs = node:GetAttributes()
        for k, v in pairs(attrs) do
            table.insert(nodeInfo.allAttrs, {key = tostring(k), value = tostring(v)})
        end
        
        -- 检查配置信息
        if cfg and nodeInfo.tmplId then
            local c = cfg[nodeInfo.tmplId] or cfg[tostring(nodeInfo.tmplId)]
            if c then
                nodeInfo.cfgName = c.Name or c.ShowName or c.Desc or c.DisplayName
            end
        end
        
        -- 检测是否为裂缝
        nodeInfo.isRift = IsRiftNode(node, cfg)
        
        -- 检查是否已进入
        nodeInfo.entered = alreadyEnteredDungeon(node)
        
        -- 检查能否进入
        nodeInfo.canEnter, nodeInfo.enterReason = CanEnterDungeon(node)
        
        table.insert(allNodes, nodeInfo)
        
        if nodeInfo.isRift then
            table.insert(riftNodes, nodeInfo)
        end
        
        if nodeInfo.entered then
            table.insert(enteredNodes, nodeInfo)
        end
    end
    
    -- 打印所有节点
    print("\n[调试] ---------- 所有地牢节点 ----------")
    for i, info in ipairs(allNodes) do
        local status = ""
        if info.isRift then
            status = status .. " [裂缝]"
        end
        if info.entered then
            status = status .. " [已进入]"
        end
        
        print(string.format("[调试] 节点 %d: %s", i, info.name))
        print(string.format("  - 来源: %s", info.source))
        print(string.format("  - 完整路径: %s", info.node:GetFullName()))
        print(string.format("  - 类型: %s", info.node.ClassName))
        print(string.format("  - TmplId: %s", tostring(info.tmplId)))
        print(string.format("  - DynamicKey: %s", tostring(info.dynamicKey)))
        print(string.format("  - GroupId: %s", tostring(info.node:GetAttribute("DungeonGroupId"))))
        print(string.format("  - StartTick: %s", tostring(info.startTick)))
        print(string.format("  - SyncKey: %s", tostring(info.syncKey)))
        if info.pos then
            print(string.format("  - 位置: %.2f, %.2f, %.2f", info.pos.X, info.pos.Y, info.pos.Z))
        end
        if info.cfgName then
            print(string.format("  - 配置名称: %s", tostring(info.cfgName)))
        end
        
        -- 打印所有属性
        if #info.allAttrs > 0 then
            print(string.format("  - 属性 (%d个):", #info.allAttrs))
            for _, attr in ipairs(info.allAttrs) do
                print(string.format("    * %s = %s", attr.key, attr.value))
            end
        else
            print("  - 无属性")
        end
        
        -- 打印能否进入的状态
        if info.canEnter then
            print(string.format("  - ✅ 能否进入: %s", info.enterReason))
        else
            print(string.format("  - ❌ 能否进入: %s", info.enterReason))
        end
        
        print(string.format("  - 状态: %s", status))
        print("")
    end
    
    -- 打印裂缝节点
    print("\n[调试] ---------- 检测到的裂缝节点 ----------")
    if #riftNodes == 0 then
        print("[调试] ❌ 未检测到任何裂缝节点")
        print("[调试] 提示: 如果面前有地牢但未检测到，请检查:")
        print("[调试]   1. 节点是否有 DungeonTmplId 属性")
        print("[调试]   2. 节点名称是否包含 'Dungeon_' 前缀")
        print("[调试]   3. 节点是否在 DynamicDungeon 下")
    else
        print(string.format("[调试] ✓ 检测到 %d 个裂缝节点:", #riftNodes))
        for i, info in ipairs(riftNodes) do
            local enteredText = info.entered and " [已进入]" or " [未进入]"
            print(string.format("[调试] 裂缝 %d: %s%s", i, info.name, enteredText))
            print(string.format("  - 来源: %s", info.source))
            print(string.format("  - 完整路径: %s", info.node:GetFullName()))
            print(string.format("  - TmplId: %s", tostring(info.tmplId)))
            if info.pos then
                print(string.format("  - 位置: %.2f, %.2f, %.2f", info.pos.X, info.pos.Y, info.pos.Z))
            end
            if info.cfgName then
                print(string.format("  - 配置名称: %s", tostring(info.cfgName)))
            end
            -- 打印能否进入的状态
            if info.canEnter then
                print(string.format("  - ✅ 能否进入: %s", info.enterReason))
            else
                print(string.format("  - ❌ 能否进入: %s", info.enterReason))
            end
            print("")
        end
    end
    
    -- 打印已进入的节点
    if #enteredNodes > 0 then
        print("\n[调试] ---------- 已进入的节点 ----------")
        for i, info in ipairs(enteredNodes) do
            print(string.format("[调试] %d. %s (TmplId: %s)", i, info.name, tostring(info.tmplId)))
        end
    end
    
    -- 总结
    print("\n[调试] ========== 检测总结 ==========")
    print(string.format("[调试] 总节点数: %d", #allNodes))
    print(string.format("[调试] 裂缝节点数: %d", #riftNodes))
    print(string.format("[调试] 已进入节点数: %d", #enteredNodes))
    print(string.format("[调试] 可用裂缝数: %d", #riftNodes - #enteredNodes))
    print("[调试] ================================\n")
end

-- 打印用户当前位置附近的所有节点
local function PrintNearbyNodes()
    local character = player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        print("[调试] 角色未就绪，无法检测附近节点")
        return
    end
    
    local playerPos = character.HumanoidRootPart.Position
    print("\n[调试] ========== 当前位置附近的节点 ==========")
    print(string.format("[调试] 玩家位置: %.2f, %.2f, %.2f", playerPos.X, playerPos.Y, playerPos.Z))
    print("[调试] 搜索范围: 100米内")
    
    local nearbyNodes = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") or obj:IsA("Model") then
            local objPos = obj:IsA("BasePart") and obj.Position or (obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position)
            local dist = (objPos - playerPos).Magnitude
            if dist <= 100 then
                -- 检查是否有任何属性
                local attrs = obj:GetAttributes()
                local hasAttrs = false
                for _ in pairs(attrs) do
                    hasAttrs = true
                    break
                end
                
                -- 如果名称包含 Dungeon 或地牢相关，或者有属性，就显示
                local name = obj.Name or ""
                if string.find(string.lower(name), "dungeon") or 
                   string.find(name, "地牢") or 
                   string.find(string.lower(name), "rift") or 
                   string.find(name, "裂缝") or
                   hasAttrs then
                    table.insert(nearbyNodes, {
                        obj = obj,
                        name = name,
                        dist = dist,
                        pos = objPos,
                        attrs = attrs
                    })
                end
            end
        end
    end
    
    -- 按距离排序
    table.sort(nearbyNodes, function(a, b) return a.dist < b.dist end)
    
    if #nearbyNodes == 0 then
        print("[调试] ❌ 附近100米内未找到任何相关节点")
    else
        print(string.format("[调试] ✓ 找到 %d 个附近节点:", #nearbyNodes))
        for i, n in ipairs(nearbyNodes) do
            print(string.format("[调试] 节点 %d: %s (距离: %.2f米)", i, n.name, n.dist))
            print(string.format("  - 完整路径: %s", n.obj:GetFullName()))
            print(string.format("  - 类型: %s", n.obj.ClassName))
            print(string.format("  - 位置: %.2f, %.2f, %.2f", n.pos.X, n.pos.Y, n.pos.Z))
            
            -- 打印所有属性
            local attrCount = 0
            for k, v in pairs(n.attrs) do
                attrCount = attrCount + 1
                print(string.format("  - 属性: %s = %s", tostring(k), tostring(v)))
            end
            if attrCount == 0 then
                print("  - 无属性")
            end
            print("")
        end
    end
    print("[调试] ======================================\n")
end

-- 单次打印
print("[调试] =========================================")
print("[调试] 开始检测地牢节点（单次打印）...")
print("[调试] =========================================")
PrintNearbyNodes()  -- 先打印附近的节点
PrintAllDungeonNodes()
print("[调试] =========================================")
print("[调试] 检测完成！")
print("[调试] =========================================")

