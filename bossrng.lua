local player = game:GetService("Players").LocalPlayer
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")

-- 静音所有声音
for _, sound in pairs(SoundService:GetDescendants()) do
    if sound:IsA("Sound") then
        pcall(function()
            sound.Volume = 0
            sound.Playing = false
        end)
    end
end

RunService.Heartbeat:Connect(function()
    for _, sound in pairs(SoundService:GetDescendants()) do
        if sound:IsA("Sound") then
            pcall(function()
                sound.Volume = 0
                sound.Playing = false
            end)
        end
    end
end)

print("🔇 ALL SOUNDS PERMANENTLY MUTED!")

-- ========== JSON设置保存功能 ==========
local HttpService = game:GetService("HttpService")
local settingsFileName = "SharkBossSettings.json"

-- 自动获取所有Secret区域
local function getAvailableSecretAreas()
    local areas = {}
    for _, child in ipairs(workspace.AreaModel:GetChildren()) do
        local num = child.Name:match("^Secret1_(%d+)$")
        if num then
            table.insert(areas, {
                fullName = child.Name,
                number = tonumber(num),
                callPath = "AreaModel." .. child.Name .. ".Area.Sky_BossRoom.Room_1"
            })
        end
    end
    table.sort(areas, function(a,b) return a.number < b.number end)
    return areas
end

-- 创建默认设置
local function createDefaultSettings()
    return {
        sharkEnabled = false,
        windowPosition = {x = 0.5, y = 0.5},
        isCollapsed = false,
        autoReconnect = false
    }
end

-- 加载设置
local function loadSettings()
    local success, loadedSettings = pcall(function()
        if not isfolder("SharkBoss") then
            makefolder("SharkBoss")
        end
        
        local filePath = "SharkBoss/"..settingsFileName
        if not isfile(filePath) then
            return createDefaultSettings()
        end
        
        local fileContent = readfile(filePath)
        return HttpService:JSONDecode(fileContent)
    end)
    
    if success and loadedSettings then
        -- 确保所有设置字段都存在
        loadedSettings.sharkEnabled = loadedSettings.sharkEnabled or false
        loadedSettings.windowPosition = loadedSettings.windowPosition or {x = 0.5, y = 0.5}
        loadedSettings.isCollapsed = loadedSettings.isCollapsed or false
        loadedSettings.autoReconnect = loadedSettings.autoReconnect or false
        
        return loadedSettings
    else
        return createDefaultSettings()
    end
end

-- 保存设置
local function saveSettings(settings)
    local success, err = pcall(function()
        if not isfolder("SharkBoss") then
            makefolder("SharkBoss")
        end
        
        local filePath = "SharkBoss/"..settingsFileName
        local json = HttpService:JSONEncode(settings)
        writefile(filePath, json)
    end)
    
    if not success then
        warn("保存设置失败:", err)
    end
end

-- 加载设置
local settings = loadSettings()

-- ========== GUI界面 ==========
local gui = Instance.new("ScreenGui")
gui.Name = "SharkBossMonitor"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- 主框架
local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 350, 0, 400)
frame.Position = UDim2.new(settings.windowPosition.x, -175, settings.windowPosition.y, -200)
frame.BackgroundColor3 = Color3.fromRGB(36, 36, 42)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.Active = true
frame.Selectable = true
frame.Parent = gui

-- 添加圆角
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

-- 添加阴影
local shadow = Instance.new("ImageLabel")
shadow.Name = "Shadow"
shadow.Image = "rbxassetid://1316045217"
shadow.ImageColor3 = Color3.new(0, 0, 0)
shadow.ImageTransparency = 0.8
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(10, 10, 118, 118)
shadow.Size = UDim2.new(1, 20, 1, 20)
shadow.Position = UDim2.new(0, -10, 0, -10)
shadow.BackgroundTransparency = 1
shadow.ZIndex = -1
shadow.Parent = frame

-- 标题栏
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
titleBar.BorderSizePixel = 0
titleBar.Parent = frame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

local title = Instance.new("TextLabel")
title.Text = "鲨鱼BOSS监控系统 v1.0"
title.Size = UDim2.new(0.7, 0, 1, 0)
title.Position = UDim2.new(0.15, 0, 0, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = titleBar

-- 折叠按钮
local toggleButton = Instance.new("TextButton")
toggleButton.Text = settings.isCollapsed and "▲" or "▼"
toggleButton.Size = UDim2.new(0, 30, 0, 30)
toggleButton.Position = UDim2.new(1, -35, 0.5, -15)
toggleButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Font = Enum.Font.Gotham
toggleButton.TextSize = 14
toggleButton.Parent = titleBar

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 6)
toggleCorner.Parent = toggleButton

-- 内容区域
local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -20, 1, -70)
contentFrame.Position = UDim2.new(0, 10, 0, 50)
contentFrame.BackgroundTransparency = 1
contentFrame.ClipsDescendants = true
contentFrame.Visible = not settings.isCollapsed
contentFrame.Parent = frame

-- 区域标签
local areaLabel = Instance.new("TextLabel")
areaLabel.Text = "鲨鱼BOSS区域监控"
areaLabel.Size = UDim2.new(1, 0, 0, 25)
areaLabel.Position = UDim2.new(0, 0, 0, 0)
areaLabel.BackgroundTransparency = 1
areaLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
areaLabel.Font = Enum.Font.Gotham
areaLabel.TextSize = 14
areaLabel.TextXAlignment = Enum.TextXAlignment.Left
areaLabel.Parent = contentFrame

-- 创建漂亮的按钮
local function createButton(text, parent, defaultColor, activeColor)
    local button = Instance.new("TextButton")
    button.Text = text
    button.Size = UDim2.new(1, 0, 0, 36)
    button.BackgroundColor3 = defaultColor
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.Gotham
    button.TextSize = 12
    button.AutoButtonColor = false
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    
    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(80, 80, 80)
    stroke.Thickness = 1
    stroke.Parent = button
    
    button.Parent = parent
    
    -- 悬停效果
    button.MouseEnter:Connect(function()
        local targetColor = button.BackgroundColor3 == activeColor and activeColor or 
                          Color3.fromRGB(
                              math.floor(defaultColor.R * 255 + 20),
                              math.floor(defaultColor.G * 255 + 20),
                              math.floor(defaultColor.B * 255 + 20)
                          )
        game:GetService("TweenService"):Create(
            button,
            TweenInfo.new(0.2),
            {BackgroundColor3 = targetColor}
        ):Play()
    end)
    
    button.MouseLeave:Connect(function()
        local targetColor = button.BackgroundColor3 == activeColor and activeColor or defaultColor
        game:GetService("TweenService"):Create(
            button,
            TweenInfo.new(0.2),
            {BackgroundColor3 = targetColor}
        ):Play()
    end)
    
    return button
end

-- 鲨鱼BOSS按钮
local sharkBtn = createButton(
    settings.sharkEnabled and "鲨鱼BOSS:ON" or "鲨鱼BOSS:OFF",
    contentFrame,
    settings.sharkEnabled and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(80, 40, 40),
    Color3.fromRGB(40, 80, 40)
)
sharkBtn.Position = UDim2.new(0, 0, 0, 30)

sharkBtn.MouseButton1Click:Connect(function()
    settings.sharkEnabled = not settings.sharkEnabled
    sharkBtn.Text = settings.sharkEnabled and "鲨鱼BOSS:ON" or "鲨鱼BOSS:OFF"
    sharkBtn.BackgroundColor3 = settings.sharkEnabled and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(80, 40, 40)
    saveSettings(settings)
end)

-- 自动重连按钮
local autoReconnectBtn = createButton("自动重连 (30分钟): "..(settings.autoReconnect and "ON" or "OFF"), 
                                   contentFrame, 
                                   settings.autoReconnect and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(80, 40, 40),
                                   Color3.fromRGB(40, 80, 40))
autoReconnectBtn.Position = UDim2.new(0, 0, 0, 70)

autoReconnectBtn.MouseButton1Click:Connect(function()
    settings.autoReconnect = not settings.autoReconnect
    autoReconnectBtn.Text = "自动重连 (30分钟): "..(settings.autoReconnect and "ON" or "OFF")
    autoReconnectBtn.BackgroundColor3 = settings.autoReconnect and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(80, 40, 40)
    saveSettings(settings)
    
    if settings.autoReconnect then
        print("自动重连已启用，将在30分钟后执行")
    else
        print("自动重连已禁用")
    end
end)

-- 停止按钮
local stopBtn = createButton("停止所有监控", contentFrame, Color3.fromRGB(180, 50, 50), Color3.fromRGB(150, 30, 30))
stopBtn.Position = UDim2.new(0, 0, 0, 110)

-- 折叠功能
local collapsibleElements = {contentFrame}
local isCollapsed = settings.isCollapsed

local function toggleCollapse()
    isCollapsed = not isCollapsed
    
    if isCollapsed then
        toggleButton.Text = "▲"
        frame.Size = UDim2.new(0, 350, 0, 40)
        for _, element in ipairs(collapsibleElements) do
            element.Visible = false
        end
    else
        toggleButton.Text = "▼"
        frame.Size = UDim2.new(0, 350, 0, 400)
        for _, element in ipairs(collapsibleElements) do
            element.Visible = true
        end
    end
    
    settings.isCollapsed = isCollapsed
    saveSettings(settings)
end

toggleButton.MouseButton1Click:Connect(toggleCollapse)

-- 拖动功能
local UserInputService = game:GetService("UserInputService")
local dragging = false
local dragStart = Vector2.new(0, 0)
local startPos = frame.Position

local function saveWindowPosition()
    settings.windowPosition = {
        x = frame.Position.X.Scale,
        y = frame.Position.Y.Scale
    }
    saveSettings(settings)
end

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
    end
end)

titleBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
        saveWindowPosition()
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

gui.Parent = player:WaitForChild("PlayerGui")

-- ========== 核心功能 ==========
local running = true
local currentFloatTask = nil
local currentCircleTask = nil
local currentCenterPosition = nil
local hasEnteredBattle = false
local targetPosition = Vector3.new(-70, 18, -62)
local lastReconnectCheck = os.time()
local AREA_REFRESH_INTERVAL = 300 -- 5分钟刷新一次区域列表

-- 安全获取对象
local function safeGet(path)
    local current = game
    for _, part in ipairs(path) do
        local success, child = pcall(function() return current[part] end)
        if not success or not child then
            return nil
        end
        current = child
    end
    return current
end

-- 战斗状态检测
local function isWaitClearVisible()
    local waitFrame = safeGet({
        "Players", player.Name, 
        "PlayerGui", "MainGui", 
        "ScreenGui", "ArenaStatusView", 
        "ResultFrame"
    })
    return waitFrame and waitFrame:IsA("Frame") and waitFrame.Visible
end

local function isInBattle()
    local arenaView = safeGet({
        "Players", player.Name,
        "PlayerGui", "MainGui",
        "ScreenGui", "ArenaStatusView"
    })
    return arenaView and arenaView:IsA("Frame")
end

-- 获取视角前方位置
local function getViewForwardCenter()
    local Character = player.Character
    if not Character then return nil end
    
    local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    if not HumanoidRootPart then return nil end

    local camera = workspace.CurrentCamera
    if camera then
        local cameraCF = camera.CFrame
        return Vector3.new(
            cameraCF.Position.X + cameraCF.LookVector.X * 100,
            HumanoidRootPart.Position.Y,
            cameraCF.Position.Z + cameraCF.LookVector.Z * 100
        )
    end
    return HumanoidRootPart.Position
end

-- 圆形移动
local function startCircleMovement()
    if currentCircleTask then
        currentCircleTask:Disconnect()
        currentCircleTask = nil
    end

    local Character = player.Character
    if not Character then return end
    
    local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    if not HumanoidRootPart then return end

    local radius = 50
    local angle = 0
    local speed = 0.013
    
    currentCircleTask = game:GetService("RunService").Heartbeat:Connect(function(dt)
        if not running or not currentCenterPosition or not HumanoidRootPart or not HumanoidRootPart.Parent then
            if currentCircleTask then
                currentCircleTask:Disconnect()
                currentCircleTask = nil
            end
            return
        end

        angle = angle + speed * dt * 60
        local x = currentCenterPosition.X + math.cos(angle) * radius
        local z = currentCenterPosition.Z + math.sin(angle) * radius
        
        HumanoidRootPart.CFrame = CFrame.new(
            Vector3.new(x, HumanoidRootPart.Position.Y, z),
            currentCenterPosition
        )
    end)
end

-- 清理运动效果
local function cleanupMovement()
    if currentFloatTask then
        currentFloatTask:Disconnect()
        currentFloatTask = nil
    end
    if currentCircleTask then
        currentCircleTask:Disconnect()
        currentCircleTask = nil
    end
    
    local Character = player.Character
    if not Character then return end
    
    local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
    local Humanoid = Character:FindFirstChild("Humanoid")
    
    if not HumanoidRootPart or not Humanoid then return end
    
    for _, child in ipairs(HumanoidRootPart:GetChildren()) do
        if child:IsA("BodyPosition") or child:IsA("BodyForce") then
            child:Destroy()
        end
    end
    
    Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end

-- 浮空控制
local function floatAbovePosition()
    cleanupMovement()

    local Character = player.Character or player.CharacterAdded:Wait()
    local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
    local Humanoid = Character:WaitForChild("Humanoid")

    local bodyPos = Instance.new("BodyPosition")
    bodyPos.Position = HumanoidRootPart.Position + Vector3.new(0, 21, 0)
    bodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyPos.D = 1000
    bodyPos.P = 10000
    bodyPos.Parent = HumanoidRootPart

    local bodyForce = Instance.new("BodyForce")
    bodyForce.Force = Vector3.new(0, HumanoidRootPart:GetMass() * workspace.Gravity, 0)
    bodyForce.Parent = HumanoidRootPart

    Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

    task.wait(0.5)
    
    currentCenterPosition = getViewForwardCenter()
    if currentCenterPosition then
        startCircleMovement()
    else
        warn("无法获取中心点位置")
    end

    currentFloatTask = game:GetService("RunService").Heartbeat:Connect(function()
        if not running then
            cleanupMovement()
            return
        end

        if isWaitClearVisible() then
            cleanupMovement()
        end
    end)
    
    return true
end

-- 重新连接服务器
local RECONNECT_INTERVAL = 1800 -- 30分钟(秒)

local function reconnectToServer()
    if not settings.autoReconnect then return end
    
    print("开始执行自动重连流程...")
    running = false  -- Pause monitoring
    
    cleanupMovement()
    wait(1)  -- Ensure cleanup completes
    
    local _place = game.PlaceId
    local _servers = "https://games.roblox.com/v1/games/".._place.."/servers/Public?sortOrder=Asc&limit=10"
    
    -- Freeze character if exists
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        player.Character.HumanoidRootPart.Anchored = true
    end
    
    -- Attempt reconnection
    local success = pcall(function()
        local servers = game:GetService("HttpService"):JSONDecode(game:HttpGet(_servers))
        if servers and #servers.data > 0 then
            local server = servers.data[math.random(1, math.min(#servers.data, 10))]
            game:GetService("TeleportService"):TeleportToPlaceInstance(_place, server.id, player)
        else
            game:GetService("TeleportService"):Teleport(_place, player)
        end
    end)
    
    if not success then
        warn("重连失败，5秒后重试...")
        wait(5)
        running = true  -- Resume operations if failed
    end
end
local PathTool = require(game:GetService("ReplicatedStorage").CommonLibrary.Tool.PathTool)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataPullFunc = ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("RemoteManager"):WaitForChild("Funcs"):WaitForChild("DataPullFunc")

-- Wait for player data to load
local player = Players.LocalPlayer
while not PathTool.ClientPlayerManager.GetGamePlayer() do
    task.wait(1)
end
local gamePlayer = PathTool.ClientPlayerManager.GetGamePlayer()
local function captureLingShou()
    -- 检查是否在灵兽捕捉状态
    local waitFrame = safeGet({
        "Players", player.Name, 
        "PlayerGui", "MainGui", 
        "ScreenGui", "ArenaStatusView", 
        "WaitClearFrame"
    })
    if not (waitFrame and waitFrame:IsA("Frame") and waitFrame.Visible) then
        return false
    end

    print("检测到灵兽触发条件，开始捕捉...")
    cleanupMovement()
    
    -- 获取所有怪物
    local monsters = workspace.Monsters:GetChildren()
    if #monsters == 0 then
        warn("没有找到怪物")
        return false
    end
    
    -- 提取怪物ID并创建怪物映射表
    local monsterMap = {}
    for _, monster in ipairs(monsters) do
        local monsterName = monster.Name
        local number = string.match(monsterName, "%d+")
        if number then
            local monsterId = tonumber(number)
            monsterMap[monsterId] = monster
            print("找到怪物ID:", monsterId)
        end
    end
    
    -- 对每个怪物执行3次灵兽捕捉
    for monsterId, monster in pairs(monsterMap) do
        for i = 1, 3 do
            local args = {
                "LingShouSystemRollChannel",
                monsterId,
                1  -- Single roll
            }
            
            print(string.format("正在对怪物ID %d 执行第%d次灵兽捕捉...", monsterId, i))
            local success, err = pcall(function()
                return DataPullFunc:InvokeServer(unpack(args))
            end)
            
            if success then
                print(string.format("怪物ID %d 第%d次灵兽捕捉成功", monsterId, i))
            else
                warn(string.format("怪物ID %d 第%d次灵兽捕捉失败:", monsterId, i), err)
            end
            
            wait(0.1) -- 短暂等待防止请求过快
        end
        
        -- 强制清理当前怪物
        if monster and monster.Parent then
            print(string.format("正在清理怪物ID %d 的尸体...", monsterId))
            pcall(function()
                -- 先使所有部件不可见且无碰撞
                for _, part in ipairs(monster:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Transparency = 1
                        part.CanCollide = false
                        part.Anchored = true
                    end
                end
                -- 然后销毁怪物实例
                monster:Destroy()
                print(string.format("成功清理怪物ID %d", monsterId))
            end)
        end
    end
    
    -- 额外清理所有残留的死亡怪物
    for _, monster in ipairs(workspace.Monsters:GetChildren()) do
        if monster:GetAttribute("DeathTime") then
            print("发现残留死亡怪物，正在清理...")
            pcall(function()
                for _, part in ipairs(monster:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Transparency = 1
                        part.CanCollide = false
                        part.Anchored = true
                    end
                end
                monster:Destroy()
            end)
        end
    end
    
    return true
end


-- 主循环
local function main()
    while running do
        local currentTime = os.time()
        
        -- 自动重连检查
        if settings.autoReconnect and (currentTime - lastReconnectCheck >= RECONNECT_INTERVAL) then
            reconnectToServer()
            lastReconnectCheck = currentTime
        end
        
        -- 检查鲨鱼BOSS是否启用
        if settings.sharkEnabled and not hasEnteredBattle then
            -- 实时获取所有可用的Secret区域
            local availableSecretAreas = getAvailableSecretAreas()
            
            if #availableSecretAreas > 0 then
                -- 尝试进入第一个可用的鲨鱼区域
                local area = availableSecretAreas[1]  -- 默认选择第一个区域
                print("尝试进入鲨鱼区域:", area.fullName, "路径:", area.callPath)
                
                -- 发送进入请求
                local success, response = pcall(function()
                    return game:GetService("ReplicatedStorage"):WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("RemoteManager"):WaitForChild("Funcs"):WaitForChild("BossRoomEnterFunc"):InvokeServer(area.callPath, 1)
                end)
                
                if success and response then
                    print("进入请求成功，等待战局加载...")
                    hasEnteredBattle = true
                    
                    -- 使用waitUntil方式等待进入战局，25秒超时
                    local enteredBattle = false
                    local startWaitTime = os.time()
                    
                    -- 等待进入战斗状态
                    while not enteredBattle and running do
                        enteredBattle = isInBattle()
                        if os.time() - startWaitTime > 25 then
                            warn("25秒后仍未进入战局，将重试")
                            break
                        end
                        wait(0.5)
                    end
                    
                    if enteredBattle then
                        wait(2)
                        print("成功进入战局，启动浮空系统")
                        local floatSuccess = floatAbovePosition()
                        
                        -- 战斗内循环
                        while running and isInBattle() do
                            -- 自动捕捉灵兽
                            captureLingShou()
                            wait(0.5)
                        end
                        
                        -- 战斗结束处理
                        if player.Character then
                            cleanupMovement()
                            print("战斗结束，正在传送...")
                            wait(1.5)
                            player.Character:WaitForChild("HumanoidRootPart").CFrame = CFrame.new(targetPosition)
                            print("传送完成")
                        end
                    end
                    
                    hasEnteredBattle = false
                else
                    warn("进入鲨鱼区域失败:", success and "服务器返回空响应" or response)
                end
                
                wait(5) -- 每次尝试间隔
            else
                warn("未找到任何Secret区域，等待5秒后重试...")
                wait(5)
            end
        end
        
        wait(1) -- 主循环间隔
    end
end

-- 停止功能
stopBtn.MouseButton1Click:Connect(function()
    running = false
    cleanupMovement()
    gui:Destroy()
end)

-- 启动脚本
local success, err = pcall(main)
if not success then
    warn("脚本错误:", err)
    gui:Destroy()
end
