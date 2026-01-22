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

-- 用户操作检测
local lastUserActivity = tick()  -- 记录最后一次用户操作时间
local IDLE_THRESHOLD = 20  -- 空闲阈值（秒），超过这个时间没有操作才执行anti-afk

local function randRange(a, b)
    return a + math.random() * (b - a)
end

-- 检测用户是否有操作
local function hasUserActivity()
    return (tick() - lastUserActivity) < IDLE_THRESHOLD
end

-- 监听用户输入，更新最后操作时间
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed then
        lastUserActivity = tick()
    end
end)

-- 监听鼠标移动
UserInputService.InputChanged:Connect(function(input, gameProcessed)
    if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseMovement then
        lastUserActivity = tick()
    end
end)
 
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
    
    -- 只有在用户空闲时才执行
    if hasUserActivity() then
        return
    end
    
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

-- 连接 Idled 事件
local function connectIdled()
    pcall(function()
        player.Idled:Connect(function()
            if enabled then
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

-- 主循环：每60秒检查一次，但只在用户空闲时执行
task.spawn(function()
    while task.wait(60) do
        if enabled and not hasUserActivity() then
            performAction()
        end
    end
end)

-- Heartbeat 随机触发（只在用户空闲时）
local lastActionTime = tick()
local nextActionInterval = 60 + randRange(-10, 10)

task.spawn(function()
    RunService.Heartbeat:Connect(function()
        if not enabled then return end
        
        -- 如果用户有操作，重置计时器
        if hasUserActivity() then
            lastActionTime = tick()
            return
        end
        
        local currentTime = tick()
        if currentTime - lastActionTime >= nextActionInterval then
            lastActionTime = currentTime
            nextActionInterval = 60 + randRange(-10, 10)
            task.spawn(performAction)
        end
    end)
end)

print("[Anti-AFK] 已自动启用")

