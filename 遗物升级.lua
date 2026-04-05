local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local isCollapsed = false
local isRunning = false

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function getViewportSize()
    local camera = workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end

    return Vector2.new(720, 1280)
end

local function getMetrics()
    local viewport = getViewportSize()
    local isMobile = UserInputService.TouchEnabled

    local metrics = {
        isMobile = isMobile,
        width = 360,
        height = 330,
        headerHeight = 46,
        buttonSize = 32,
        padding = 10,
        labelHeight = 18,
        inputHeight = 36,
        rowHeight = 38,
        titleTextSize = 15,
        labelTextSize = 13,
        inputTextSize = 14,
        statusTextSize = 13,
        corner = 12,
        strokeThickness = 1,
        scrollBarThickness = 4,
    }

    if isMobile then
        metrics.width = math.floor(clamp(viewport.X * 0.68, 250, 320))
        metrics.height = math.floor(clamp(viewport.Y * 0.34, 220, 310))
        metrics.headerHeight = 40
        metrics.buttonSize = 28
        metrics.padding = 8
        metrics.labelHeight = 16
        metrics.inputHeight = 32
        metrics.rowHeight = 34
        metrics.titleTextSize = 13
        metrics.labelTextSize = 11
        metrics.inputTextSize = 12
        metrics.statusTextSize = 11
        metrics.corner = 10
        metrics.scrollBarThickness = 3
    end

    return metrics
end

local M = getMetrics()

local function create(className, props)
    local instance = Instance.new(className)

    for key, value in pairs(props) do
        instance[key] = value
    end

    return instance
end

local gui = create("ScreenGui", {
    Name = "SmallToolPanelGui",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
gui.Parent = playerGui

local main = create("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.58, 0),
    Size = UDim2.new(0, M.width, 0, M.height),
    BackgroundColor3 = Color3.fromRGB(26, 29, 36),
    BorderSizePixel = 0,
    Active = true,
})
main.Parent = gui

create("UICorner", {
    CornerRadius = UDim.new(0, M.corner),
}).Parent = main

create("UIStroke", {
    Color = Color3.fromRGB(78, 86, 104),
    Thickness = M.strokeThickness,
    Transparency = 0.12,
}).Parent = main

local header = create("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, M.headerHeight),
    BackgroundColor3 = Color3.fromRGB(34, 38, 48),
    BorderSizePixel = 0,
    Active = true,
})
header.Parent = main

create("UICorner", {
    CornerRadius = UDim.new(0, M.corner),
}).Parent = header

local title = create("TextLabel", {
    Name = "Title",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 0),
    Size = UDim2.new(1, -(M.buttonSize * 2 + 40), 1, 0),
    Font = Enum.Font.GothamBold,
    Text = "Tool Panel",
    TextColor3 = Color3.fromRGB(245, 247, 250),
    TextSize = M.titleTextSize,
    TextXAlignment = Enum.TextXAlignment.Left,
})
title.Parent = header

local collapseButton = create("TextButton", {
    Name = "CollapseButton",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -(M.buttonSize + 16), 0.5, 0),
    Size = UDim2.new(0, M.buttonSize, 0, M.buttonSize),
    BackgroundColor3 = Color3.fromRGB(73, 134, 255),
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "-",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = M.titleTextSize,
})
collapseButton.Parent = header

create("UICorner", {
    CornerRadius = UDim.new(1, 0),
}).Parent = collapseButton

local closeButton = create("TextButton", {
    Name = "CloseButton",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -8, 0.5, 0),
    Size = UDim2.new(0, M.buttonSize, 0, M.buttonSize),
    BackgroundColor3 = Color3.fromRGB(220, 74, 74),
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "X",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = M.titleTextSize,
})
closeButton.Parent = header

create("UICorner", {
    CornerRadius = UDim.new(1, 0),
}).Parent = closeButton

local body = create("ScrollingFrame", {
    Name = "Body",
    Position = UDim2.new(0, M.padding, 0, M.headerHeight + M.padding),
    Size = UDim2.new(1, -(M.padding * 2), 1, -(M.headerHeight + M.padding * 2)),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = M.scrollBarThickness,
    ScrollingDirection = Enum.ScrollingDirection.Y,
})
body.Parent = main

local bodyLayout = create("UIListLayout", {
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, M.padding),
})
bodyLayout.Parent = body

local function makeLabel(text)
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, M.labelHeight),
        Font = Enum.Font.GothamSemibold,
        Text = text,
        TextColor3 = Color3.fromRGB(220, 224, 230),
        TextSize = M.labelTextSize,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    return label
end

local function makeBox(defaultText)
    local box = create("TextBox", {
        Size = UDim2.new(1, 0, 0, M.inputHeight),
        BackgroundColor3 = Color3.fromRGB(43, 48, 59),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        PlaceholderText = defaultText,
        Text = defaultText,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = M.inputTextSize,
    })

    create("UICorner", {
        CornerRadius = UDim.new(0, 8),
    }).Parent = box

    return box
end

local repeatsLabel = makeLabel("Repeats")
repeatsLabel.Parent = body

local repeatsBox = makeBox("150")
repeatsBox.Parent = body

local arg1Label = makeLabel("Arg1 Range  例如: 1,10")
arg1Label.Parent = body

local arg1Box = makeBox("1,10")
arg1Box.Parent = body

local arg2Label = makeLabel("Arg2 Range  例如: 1,4")
arg2Label.Parent = body

local arg2Box = makeBox("1,4")
arg2Box.Parent = body

local statusLabel = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, M.labelHeight + 4),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Status: Idle",
    TextColor3 = Color3.fromRGB(145, 215, 160),
    TextSize = M.statusTextSize,
    TextXAlignment = Enum.TextXAlignment.Left,
})
statusLabel.Parent = body

local buttonRow = create("Frame", {
    Size = UDim2.new(1, 0, 0, M.rowHeight),
    BackgroundTransparency = 1,
})
buttonRow.Parent = body

local rowLayout = create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 8),
})
rowLayout.Parent = buttonRow

local runButton = create("TextButton", {
    Size = UDim2.new(0.5, -4, 1, 0),
    BackgroundColor3 = Color3.fromRGB(60, 179, 113),
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "Run",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = M.inputTextSize,
})
runButton.Parent = buttonRow

create("UICorner", {
    CornerRadius = UDim.new(0, 8),
}).Parent = runButton

local stopButton = create("TextButton", {
    Size = UDim2.new(0.5, -4, 1, 0),
    BackgroundColor3 = Color3.fromRGB(214, 137, 16),
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "Stop",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = M.inputTextSize,
})
stopButton.Parent = buttonRow

create("UICorner", {
    CornerRadius = UDim.new(0, 8),
}).Parent = stopButton

local function parseRange(text)
    local a, b = string.match(text, "^(%d+)%s*,%s*(%d+)$")
    if not a or not b then
        return nil, nil
    end

    local minValue = tonumber(a)
    local maxValue = tonumber(b)

    if not minValue or not maxValue or minValue > maxValue then
        return nil, nil
    end

    return minValue, maxValue
end

local function setStatus(text, color)
    statusLabel.Text = text
    statusLabel.TextColor3 = color
end

local function runAction(arg1, arg2)
    -- 在这里换成你自己项目里的合法逻辑
    print("Run action:", arg1, arg2)
end

local expandedHeight = M.height

local function updateCollapseState()
    if isCollapsed then
        body.Visible = false
        main.Size = UDim2.new(0, M.width, 0, M.headerHeight)
        collapseButton.Text = "+"
    else
        body.Visible = true
        main.Size = UDim2.new(0, M.width, 0, expandedHeight)
        collapseButton.Text = "-"
    end
end

collapseButton.MouseButton1Click:Connect(function()
    isCollapsed = not isCollapsed
    updateCollapseState()
end)

closeButton.MouseButton1Click:Connect(function()
    gui:Destroy()
end)

stopButton.MouseButton1Click:Connect(function()
    isRunning = false
    setStatus("Status: Stopping...", Color3.fromRGB(255, 210, 120))
end)

runButton.MouseButton1Click:Connect(function()
    if isRunning then
        return
    end

    local repeats = tonumber(repeatsBox.Text)
    local arg1Min, arg1Max = parseRange(arg1Box.Text)
    local arg2Min, arg2Max = parseRange(arg2Box.Text)

    if not repeats or repeats < 1 then
        setStatus("Status: Invalid repeats", Color3.fromRGB(255, 120, 120))
        return
    end

    if not arg1Min or not arg1Max then
        setStatus("Status: Invalid Arg1 range", Color3.fromRGB(255, 120, 120))
        return
    end

    if not arg2Min or not arg2Max then
        setStatus("Status: Invalid Arg2 range", Color3.fromRGB(255, 120, 120))
        return
    end

    isRunning = true
    setStatus("Status: Running...", Color3.fromRGB(120, 220, 140))

    task.spawn(function()
        local total = 0
        local round

        for round = 1, repeats do
            local arg1
            local arg2

            if not isRunning then
                break
            end

            for arg1 = arg1Min, arg1Max do
                if not isRunning then
                    break
                end

                for arg2 = arg2Min, arg2Max do
                    if not isRunning then
                        break
                    end

                    runAction(arg1, arg2)
                    total = total + 1

                    setStatus(
                        "Status: Round " .. round .. "/" .. repeats .. " | Total " .. total,
                        Color3.fromRGB(120, 220, 140)
                    )

                    task.wait()
                end
            end
        end

        if isRunning then
            setStatus("Status: Done | Total " .. total, Color3.fromRGB(145, 215, 160))
        else
            setStatus("Status: Stopped", Color3.fromRGB(255, 210, 120))
        end

        isRunning = false
    end)
end)

do
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil

    local function updateDrag(input)
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            updateDrag(input)
        end
    end)
end

updateCollapseState()
