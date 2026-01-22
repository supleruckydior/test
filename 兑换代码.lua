-- 自动兑换代码脚本
-- 兑换 RIFT 和 VOLTGATOR

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
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

-- AntiAFK功能 - 从捕捉宠物脚本调取
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
            print("[兑换代码] [防挂机] 已从GitHub加载并自动启用")
        else
            warn("[兑换代码] [防挂机] 从GitHub加载失败: 脚本为空")
        end
    end)
    
    if not success then
        warn("[兑换代码] [防挂机] 从GitHub加载失败:", err)
        -- 如果GitHub加载失败，使用简单的备用方法
        pcall(function()
            local idledConnection = player.Idled:Connect(function()
                pcall(function()
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end)
            antiAFKEnabled = true
            print("[兑换代码] [防挂机] 使用备用方法（VirtualUser）")
        end)
    end
end

-- 启动时自动加载AntiAFK
task.spawn(function()
    task.wait(2)  -- 等待游戏加载完成
    LoadAntiAFK()
end)

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
    error("[兑换代码] PathTool 未找到")
end

-- 加载 GiftSystem（使用用户提供的路径）
print("[兑换代码] 加载 GiftSystem...")
local GiftSystem = nil
local CommonLogic = ReplicatedStorage:WaitForChild("CommonLogic", 10)
if CommonLogic then
    local Setting = CommonLogic:WaitForChild("Setting", 5)
    if Setting then
        local GiftSystemModule = Setting:FindFirstChild("GiftSystem")
        if GiftSystemModule and GiftSystemModule:IsA("ModuleScript") then
            local ok, gs = pcall(function()
                return require(GiftSystemModule)
            end)
            if ok and gs then
                GiftSystem = gs
                print("[兑换代码] GiftSystem 已从 CommonLogic.Setting 加载")
            end
        end
    end
end

-- 如果直接加载失败，尝试从 PathTool 获取
if not GiftSystem then
    print("[兑换代码] 尝试从 PathTool 获取 GiftSystem...")
    for attempt = 1, 20 do
        local ok, gs = pcall(function()
            if _G.PathTool and _G.PathTool.GiftSystem then
                return _G.PathTool.GiftSystem
            end
            if PathTool.GiftSystem then
                return PathTool.GiftSystem
            end
            return nil
        end)
        if ok and gs and gs.ClientGetGift then
            GiftSystem = gs
            print("[兑换代码] GiftSystem 已从 PathTool 加载")
            break
        end
        task.wait(0.5)
    end
end

if not GiftSystem or not GiftSystem.ClientGetGift then
    error("[兑换代码] GiftSystem 无法加载")
end

-- 获取 ViewUtil
local ViewUtil = nil
if _G.PathTool and _G.PathTool.ViewUtil then
    ViewUtil = _G.PathTool.ViewUtil
elseif PathTool.ViewUtil then
    ViewUtil = PathTool.ViewUtil
else
    error("[兑换代码] ViewUtil 未找到")
end

print("[兑换代码] GiftSystem 和 ViewUtil 已就绪")

-- 要兑换的代码列表
local codes = {"RIFT", "VOLTGATOR"}

-- 兑换代码函数
local function RedeemCode(code)
    print(string.format("[兑换代码] 正在兑换: %s", code))
    
    local success, result = pcall(function()
        -- 参考 CodeView 的调用方式：ViewUtil.DoRequest(GiftSystem.ClientGetGift, code)
        return ViewUtil.DoRequest(GiftSystem.ClientGetGift, code)
    end)
    
    if success and result then
        print(string.format("[兑换代码] ✓ 兑换成功: %s", code))
        -- 显示奖励
        pcall(function()
            local FloatRewardListView = _G.PathTool and _G.PathTool.FloatRewardListView or PathTool.FloatRewardListView
            if FloatRewardListView and FloatRewardListView.ShowReward then
                FloatRewardListView.ShowReward(result)
            end
        end)
        return true
    else
        warn(string.format("[兑换代码] ✗ 兑换失败: %s (错误: %s)", code, tostring(result)))
        return false
    end
end

-- 主流程
print("[兑换代码] 开始兑换代码...")
for _, code in ipairs(codes) do
    RedeemCode(code)
    task.wait(1)  -- 每个代码间隔1秒
end

print("[兑换代码] 所有代码兑换完成")

-- 打开物品背包界面
print("[兑换代码] 正在打开物品背包界面...")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

pcall(function()
    -- 方法1: 尝试通过 ViewManager 打开物品背包（优先尝试 ItemBagView）
    local viewNames = {"ItemBagView", "InventoryView", "EquipmentView", "BagView"}
    local opened = false
    
    if PathTool and PathTool.ViewManager then
        for _, viewName in ipairs(viewNames) do
            local ok, err = pcall(function()
                PathTool.ViewManager.OpenView(viewName)
            end)
            if ok then
                print(string.format("[兑换代码] ✓ 通过 ViewManager 打开: %s", viewName))
                opened = true
                break
            end
        end
    end
    
    -- 方法2: 尝试通过 GUI 按钮打开物品背包
    if not opened then
        local gui = PlayerGui:FindFirstChild("GUI")
        if gui then
            -- 尝试查找背包按钮（常见的按钮名称）
            local buttonNames = {"背包", "物品", "装备", "Bag", "Inventory", "Equipment"}
            for _, btnName in ipairs(buttonNames) do
                local button = gui:FindFirstChild(btnName, true)
                if button and (button:IsA("GuiButton") or button:IsA("TextButton") or button:IsA("ImageButton")) then
                    if button.Activate then
                        button:Activate()
                    elseif button.MouseButton1Click then
                        button.MouseButton1Click:Fire()
                    end
                    print(string.format("[兑换代码] ✓ 通过 GUI 按钮打开: %s", btnName))
                    opened = true
                    break
                end
            end
            
            -- 尝试通过二级菜单打开
            if not opened then
                local secondaryMenu = gui:FindFirstChild("二级菜单")
                if secondaryMenu then
                    local bagButton = secondaryMenu:FindFirstChild("背包", true)
                    if bagButton and (bagButton:IsA("GuiButton") or bagButton:IsA("TextButton") or bagButton:IsA("ImageButton")) then
                        if bagButton.Activate then
                            bagButton:Activate()
                        elseif bagButton.MouseButton1Click then
                            bagButton.MouseButton1Click:Fire()
                        end
                        print("[兑换代码] ✓ 通过二级菜单打开背包")
                        opened = true
                    end
                end
            end
        end
    end
    
    if not opened then
        warn("[兑换代码] ✗ 无法找到物品背包界面，请手动打开")
    end
end)

