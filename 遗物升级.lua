local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local isMobile = UserInputService.TouchEnabled
local camera = workspace.CurrentCamera
local viewport = camera and camera.ViewportSize or Vector2.new(720, 1280)

local isSmallMobile = isMobile and viewport.X <= 720
local isShortScreen = isMobile and viewport.Y <= 1280

local isCollapsed = false
local isRunning = false

local panelWidth
local panelHeight
local headerHeight
local windowPos
local bodyTop
local bodyBottom
local boxHeight
local rowHeight
local topButtonSize
local titleMaxSize
local panelCorner
local bodyPadding
local topButtonGap

if isSmallMobile then
    panelWidth = 0.72
    panelHeight = isShortScreen and 0.30 or 0.33
    headerHeight = 40
    windowPos = UDim2.new(0.5, 0, 0.58, 0)
    bodyTop = 48
    bodyBottom = 54
    boxHeight = 34
    rowHeight = 36
    topButtonSize = 30
    titleMaxSize = 16
    panelCorner = 12
    bodyPadding = 8
    topButtonGap = 44
elseif isMobile then
    panelWidth = 0.78
    panelHeight = 0.36
    headerHeight = 42
    windowPos = UDim2.new(0.5, 0, 0.56, 0)
    bodyTop = 50
    bodyBottom = 58
    boxHeight = 36
    rowHeight = 38
    topButtonSize = 32
    titleMaxSize = 17
    panelCorner = 13
    bodyPadding = 10
    topButtonGap = 46
else
    panelWidth = 0.34
    panelHeight = 0.52
    headerHeight = 46
    windowPos = UDim2.new(0.5, 0, 0.55, 0)
    bodyTop = 54
    bodyBottom = 66
    boxHeight = 38
    rowHeight = 42
    topButtonSize = 34
    titleMaxSize = 20
    panelCorner = 14
    bodyPadding = 10
    topButtonGap = 50
end

local function create(className, props, children)
    local instance = Instance.new(className)

    for key, value in pairs(props) do
        instance[key] = value
    end

    if children then
        for _, child in ipairs(children) do
            child.Parent = instance
        end
    end

    return instance
end

local gui = create("ScreenGui", {
    Name = "SmallToolPanelGui",
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, nil)
gui.Parent = playerGui

local main = create("Frame", {
    Name = "Main",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = windowPos,
    Size = UDim2.new(panelWidth, 0, panelHeight, 0),
    BackgroundColor3 = Color3.fromRGB(26, 29, 36),
    BorderSizePixel = 0,
    Active = true,
    Draggable = true,
}, nil)
main.Parent = gui

create("UICorner", {
    CornerRadius = UDim.new(0, panelCorner),
}, nil).Parent = main

create("UIStroke", {
    Color = Color3.fromRGB(78, 86, 104),
    Thickness = 1,
    Transparency = 0.15,
}, nil).Parent = main

local header = create("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, headerHeight),
    BackgroundColor3 = Color3.fromRGB(34, 38, 48),
    BorderSizePixel = 0,
}, nil)
header.Parent = main

create("UICorner", {
    CornerRadius = UDim.new(0, panelCorner),
}, nil).Parent = header

local title = create("TextLabel", {
    Name = "Title",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, 0),
    Size = UDim2.new(1, -(topButtonGap + topButtonSize + 24), 1, 0),
    Font = Enum.Font.GothamBold,
    Text = "Tool Panel",
    TextColor3 = Color3.fromRGB(245, 247, 250),
    TextScaled = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, nil)
title.Parent = header

create("UITextSizeConstraint", {
    MaxTextSize = titleMaxSize,
    MinTextSize = 11,
}, nil).Parent = title

local collapseButton = create("TextButton", {
    Name = "CollapseButton",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -(topButtonGap), 0.5, 0),
    Size = UDim2.new(0, topButtonSize, 0, topButtonSize),
    BackgroundColor3 = Color3.fromRGB(73, 134, 255),
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "-",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextScaled = true,
}, nil)
collapseButton.Parent = header

create("UICorner", {
    CornerRadius = UDim.new(1, 0),
}, nil).Parent = collapseButton

local closeButton = create("TextButton", {
    Name = "CloseButton",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -10, 0.5, 0),
    Size = UDim2.new(0, topButtonSize, 0, topButtonSize),
    BackgroundColor3 = Color3.fromRGB(220, 74, 74),
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "X",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextScaled = true,
}, nil)
closeButton.Parent = header

create("UICorner", {
    CornerRadius = UDim.new(1, 0),
}, nil).Parent = closeButton

local body = create("Frame", {
    Name = "Body",
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 12, 0, bodyTop),
    Size = UDim2.new(1, -24, 1, -bodyBottom),
}, nil)
body.Parent = main

local layout = create("UIListLayout", {
    Padding = UDim.new(0, bodyPadding),
    FillDirection = Enum.FillDirection.Vertical,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
}, nil)
layout.Parent = body

local function makeLabel(text)
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 18),
        Font = Enum.Font.GothamSemibold,
        Text = text,
        TextColor3 = Color3.fromRGB(220, 224, 230),
        TextScaled = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, nil)

    create("UITextSizeConstraint", {
        MaxTextSize = isMobile and 14 or 18,
        MinTextSize = 10,
    }, nil).Parent = label

    return label
end

local function makeBox(defaultText)
    local box = create("TextBox", {
        Size = UDim2.new(1, 0, 0, boxHeight),
        BackgroundColor3 = Color3.fromRGB(43, 48, 59),
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        PlaceholderText = defaultText,
        Text = defaultText,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextScaled = true,
    }, nil)

    create("UICorner", {
        CornerRadius = UDim.new(0, 10),
    }, nil).Parent = box

    create("UITextSizeConstraint", {
        MaxTextSize = isMobile and 15 or 18,
        MinTextSize = 10,
    }, nil).Parent = box

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
    Size = UDim2.new(1, 0, 0, 22),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "Status: Idle",
    TextColor3 = Color3.fromRGB(145, 215, 160),
    TextScaled = true,
    TextXAlignment = Enum.TextXAlignment.Left,
}, nil)
statusLabel.Parent = body

create("UITextSizeConstraint", {
    MaxTextSize = isMobile and 14 or 18,
    MinTextSize = 10,
}, nil).Parent = statusLabel

local buttonRow = create("Frame", {
    Size = UDim2.new(1, 0, 0, rowHeight),
    BackgroundTransparency = 1,
}, nil)
buttonRow.Parent = body

local rowLayout = create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 8),
}, nil)
rowLayout.Parent = buttonRow

local runButton = create("TextButton", {
    Size = UDim2.new(0.5, -4, 1, 0),
    BackgroundColor3 = Color3.fromRGB(60, 179, 113),
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "Run",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextScaled = true,
}, nil)
runButton.Parent = buttonRow

create("UICorner", {
    CornerRadius = UDim.new(0, 10),
}, nil).Parent = runButton

local stopButton = create("TextButton", {
    Size = UDim2.new(0.5, -4, 1, 0),
    BackgroundColor3 = Color3.fromRGB(214, 137, 16),
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "Stop",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextScaled = true,
}, nil)
stopButton.Parent = buttonRow

create("UICorner", {
    CornerRadius = UDim.new(0, 10),
}, nil).Parent = stopButton

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
    -- 把这里替换成你自己项目里的合法逻辑
    print("Run action:", arg1, arg2)
end

local expandedSize = main.Size
local collapsedSize = UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, headerHeight)

local function updateCollapseState()
    body.Visible = not isCollapsed

    if isCollapsed then
        main.Size = collapsedSize
        collapseButton.Text = "+"
    else
        main.Size = expandedSize
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

updateCollapseState()
