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
Wait(6)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local player = Players.LocalPlayer

-- AntiAFK功能 - 从捕捉宠物脚本调取
local antiAFKEnabled = false
wait(10)
-- 如果是指定用户，直接退出
if player and player.UserId == 10373072928 then
    warn("[兑换代码] 当前用户ID被禁用，脚本退出")
    return
end
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

-- 传送到出生点
print("[兑换代码] 正在传送到出生点...")
pcall(function()
    if PathTool and PathTool.DataPullManager then
        local channel = PathTool.DataPullManager.GetChannel("AreaTeleportToSpawnLocationChannel")
        if channel then
            channel:DoRequest()
            print("[兑换代码] ✓ 已传送到出生点")
        end
    end
end)

-- 等待3秒让传送完成
print("[兑换代码] 等待3秒...")
task.wait(3)

-- 每2分钟使用一次道具召唤裂缝（计时器在第一次使用后开始）
local RiftItemId = 11000
local RiftUseInterval = 120 -- 秒
local RiftUseMaxCount = 6
local RiftUseCount = 0
local RiftTimerRunning = false
local RiftNextUseIn = RiftUseInterval

-- UI (适配150x150界面)
local function CreateRiftUseUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "RiftUseTimerUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.Size = UDim2.new(0, 150, 0, 150)
    frame.Position = UDim2.new(0.5, -75, 0.5, -75)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -30, 0, 20)
    title.Position = UDim2.new(0, 15, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "裂缝计时"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Center
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.Parent = frame

    local countLabel = Instance.new("TextLabel")
    countLabel.Name = "CountLabel"
    countLabel.Size = UDim2.new(1, -10, 0, 22)
    countLabel.Position = UDim2.new(0, 5, 0, 30)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = "已释放: 0/6"
    countLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    countLabel.Font = Enum.Font.Gotham
    countLabel.TextSize = 11
    countLabel.TextXAlignment = Enum.TextXAlignment.Center
    countLabel.TextYAlignment = Enum.TextYAlignment.Center
    countLabel.Parent = frame

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Size = UDim2.new(1, -10, 0, 20)
    statusLabel.Position = UDim2.new(0, 5, 0, 58)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "运行中"
    statusLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 10
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.TextYAlignment = Enum.TextYAlignment.Center
    statusLabel.Parent = frame

    local countdownLabel = Instance.new("TextLabel")
    countdownLabel.Name = "CountdownLabel"
    countdownLabel.Size = UDim2.new(1, -10, 0, 20)
    countdownLabel.Position = UDim2.new(0, 5, 0, 84)
    countdownLabel.BackgroundTransparency = 1
    countdownLabel.Text = string.format("下次: %ds", RiftNextUseIn)
    countdownLabel.TextColor3 = Color3.fromRGB(200, 220, 200)
    countdownLabel.Font = Enum.Font.Gotham
    countdownLabel.TextSize = 10
    countdownLabel.TextXAlignment = Enum.TextXAlignment.Center
    countdownLabel.TextYAlignment = Enum.TextYAlignment.Center
    countdownLabel.Parent = frame

    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 20, 0, 20)
    closeButton.Position = UDim2.new(1, -25, 0, 5)
    closeButton.BackgroundColor3 = Color3.fromRGB(80, 40, 40)
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Font = Enum.Font.GothamBold
    closeButton.TextSize = 12
    closeButton.BorderSizePixel = 0
    closeButton.Parent = frame

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeButton

    closeButton.MouseButton1Click:Connect(function()
        RiftTimerRunning = false
        screenGui:Destroy()
        print("[兑换代码] 裂缝计时器已手动关闭")
    end)

    return countLabel, statusLabel, countdownLabel, screenGui
end

local countLabel, statusLabel, countdownLabel = CreateRiftUseUI()
local function UpdateRiftUseUI()
    if countLabel then
        countLabel.Text = string.format("已释放: %d/%d", RiftUseCount, RiftUseMaxCount)
    end
    if statusLabel then
        statusLabel.Text = RiftTimerRunning and "运行中" or "已停止"
    end
    if countdownLabel then
        countdownLabel.Text = string.format("下次: %ds", math.max(0, RiftNextUseIn))
    end
end

local function UseRiftItem()
    local ok, err = pcall(function()
        local RemoteManager = ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("RemoteManager")
        local DataPullFunc = RemoteManager:WaitForChild("Funcs"):WaitForChild("DataPullFunc")
        return DataPullFunc:InvokeServer("CommonItemUseChannel", RiftItemId)
    end)
    if ok then
        RiftUseCount = RiftUseCount + 1
        UpdateRiftUseUI()
        print(string.format("[兑换代码] ✓ 使用裂缝道具成功 (ItemId=%d)", RiftItemId))
    else
        warn(string.format("[兑换代码] ✗ 使用裂缝道具失败: %s", tostring(err)))
    end
end

task.spawn(function()
    task.wait(2)
    RiftTimerRunning = true
    UpdateRiftUseUI()
    UseRiftItem() -- 第一次使用
    while RiftTimerRunning do
        if RiftUseCount >= RiftUseMaxCount then
            RiftTimerRunning = false
            UpdateRiftUseUI()
            print("[兑换代码] 已达到释放次数上限，计时器停止")
            
            -- 达到6次后，等待2秒然后写入 Yummytool
            task.wait(2)
            pcall(function()
                if writefile and player and player.Name then
                    local filename = tostring(player.Name) .. ".txt"
                    writefile(filename, "Yummytool")
                    print(string.format("[兑换代码] ✓ 已写入标记文件: %s (内容: Yummytool)", filename))
                end
            end)
            break
        end
        -- 最后一次（第6次）使用90秒，其他使用120秒
        if RiftUseCount == 5 then
            RiftNextUseIn = 90
        else
            RiftNextUseIn = RiftUseInterval
        end
        while RiftNextUseIn > 0 and RiftTimerRunning do
            task.wait(1)
            RiftNextUseIn = RiftNextUseIn - 1
            UpdateRiftUseUI()
        end
        if not RiftTimerRunning then
            break
        end
        UseRiftItem()
    end
end)

-- 打开物品背包界面
print("[兑换代码] 正在打开物品背包界面...")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

pcall(function()
    -- 方法1: 尝试通过 ViewManager 打开物品背包（优先尝试 ItemBagView）
    local viewNames = {"ItemBagView", "InventoryView", "EquipmentView", "BagView"}
    local opened = false
    local openedViewName = nil
    
    if PathTool and PathTool.ViewManager then
        for _, viewName in ipairs(viewNames) do
            local ok, err = pcall(function()
                PathTool.ViewManager.OpenView(viewName)
            end)
            if ok then
                print(string.format("[兑换代码] ✓ 通过 ViewManager 打开: %s", viewName))
                opened = true
                openedViewName = viewName
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

    -- 等待2秒后尝试关闭背包
    task.wait(2)
    if opened and openedViewName and PathTool and PathTool.ViewManager then
        pcall(function()
            PathTool.ViewManager.CloseView(openedViewName)
            print(string.format("[兑换代码] ✓ 已关闭背包界面: %s", openedViewName))
        end)
    else
        -- 兜底：尝试关闭常见背包界面
        if PathTool and PathTool.ViewManager then
            for _, viewName in ipairs({"ItemBagView", "InventoryView", "EquipmentView", "BagView"}) do
                pcall(function()
                    PathTool.ViewManager.CloseView(viewName)
                end)
            end
            print("[兑换代码] ✓ 已尝试关闭背包界面")
        end
    end
end)

