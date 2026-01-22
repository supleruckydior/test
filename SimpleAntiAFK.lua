-- Simple Anti-AFK Script
-- 简化版本，自动启用，无UI

local Players = game:GetService("Players")
local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- 环境检测
local environment = {
    hasVirtualUser = pcall(function() return VirtualUser:CaptureController() end),
    hasCamera = workspace.CurrentCamera ~= nil,
}

local enabled = true  -- 自动启用
local isWindowFocused = true  -- 窗口焦点状态

local function randRange(a, b)
    return a + math.random() * (b - a)
end

-- 相机微动
local function cameraNudge()
    if not environment.hasCamera then return end
    
    pcall(function()
        local camera = workspace.CurrentCamera
        if not camera then return end
        
        local original = camera.CFrame
        local yaw = math.rad(randRange(-1.5, 1.5))
        local pitch = math.rad(randRange(-0.8, 0.8))
        local target = original * CFrame.Angles(pitch, yaw, 0)
        
        pcall(function()
            local tween = TweenService:Create(camera,
                TweenInfo.new(randRange(0.15, 0.3), Enum.EasingStyle.Sine),
                {CFrame = target}
            )
            tween:Play()
            tween.Completed:Wait()
        end)
        
        wait(randRange(0.1, 0.2))
        
        pcall(function()
            TweenService:Create(camera, TweenInfo.new(randRange(0.15, 0.3), Enum.EasingStyle.Sine),
                {CFrame = original}):Play()
        end)
    end)
end

-- 角色移动
local function characterMovement()
    pcall(function()
        local character = player.Character
        if not character then return end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if humanoid and rootPart then
            local moveDirection = math.random(1, 4)
            local directions = {
                Vector3.new(1, 0, 0),
                Vector3.new(-1, 0, 0),
                Vector3.new(0, 0, 1),
                Vector3.new(0, 0, -1)
            }
            
            humanoid:Move(directions[moveDirection], false)
            wait(randRange(0.05, 0.15))
            humanoid:Move(Vector3.new(0, 0, 0), false)
            
            if math.random() < 0.3 then
                pcall(function() humanoid.Jump = true end)
            end
        end
    end)
end

-- 虚拟操作
local function virtualAction()
    if not environment.hasVirtualUser then return end
    
    pcall(function()
        local success = pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
        
        if not success then
            pcall(function()
                VirtualUser:Button2Down(Vector2.new(0, 0), workspace)
                wait(0.05)
                VirtualUser:Button2Up(Vector2.new(0, 0), workspace)
            end)
        end
    end)
end

-- 执行防AFK动作
local function performAction()
    if not enabled then return end
    
    pcall(function()
        local action = math.random(1, 3)
        
        if action == 1 then
            if environment.hasCamera then
                cameraNudge()
            else
                characterMovement()
            end
        elseif action == 2 then
            if environment.hasVirtualUser then
                virtualAction()
            else
                characterMovement()
            end
        else
            characterMovement()
        end
    end)
end

-- 连接 Idled 事件（只在窗口失去焦点时触发）
local function connectIdled()
    pcall(function()
        player.Idled:Connect(function()
            if enabled and not isWindowFocused then
                task.spawn(performAction)
            end
        end)
    end)
end

connectIdled()

player.CharacterAdded:Connect(function()
    wait(1)
    connectIdled()
end)

-- 监听窗口焦点状态
UserInputService.WindowFocusReleased:Connect(function()
    isWindowFocused = false
    print("[Anti-AFK] 窗口失去焦点，开始防挂机")
end)

UserInputService.WindowFocused:Connect(function()
    isWindowFocused = true
    print("[Anti-AFK] 窗口获得焦点，停止防挂机")
end)

-- 主循环：每60秒执行一次（只在窗口失去焦点时）
task.spawn(function()
    while task.wait(60) do
        if enabled and not isWindowFocused then
            performAction()
        end
    end
end)

-- Heartbeat 随机触发（只在窗口失去焦点时）
local lastActionTime = tick()
local nextActionInterval = 60 + randRange(-10, 10)

task.spawn(function()
    RunService.Heartbeat:Connect(function()
        if not enabled or isWindowFocused then return end
        
        local currentTime = tick()
        if currentTime - lastActionTime >= nextActionInterval then
            lastActionTime = currentTime
            nextActionInterval = 60 + randRange(-10, 10)
            task.spawn(performAction)
        end
    end)
end)

print("[Anti-AFK] 已自动启用（仅在窗口失去焦点时激活）")

