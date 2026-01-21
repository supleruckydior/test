-- 自动兑换代码脚本
-- 兑换 RIFT 和 VOLTGATOR

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

