-- 一键锁定/解锁背包全部宠物 (带模板筛选功能)
-- API: PetSystem.ClientLockPet(petItemId, isLocked)
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local targetGameId = 98664161516921
if game.PlaceId ~= targetGameId then
    warn(string.format("[一键锁宠] 游戏ID不匹配: %d (需要 %d)", game.PlaceId, targetGameId))
    return
end

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer

-- 加载 PathTool
local PathTool = _G.PathTool
if not PathTool then
    local ok = pcall(function()
        PathTool = require(ReplicatedStorage:WaitForChild("CommonLibrary"):WaitForChild("Tool"):WaitForChild("PathTool"))
        _G.PathTool = PathTool
    end)
    if not ok or not PathTool then
        warn("[一键锁宠] PathTool 加载失败")
        return
    end
end

-- 获取 PetSystem
local PetSystem = PathTool.PetSystem or (PathTool.Require and PathTool.Require("PetSystem"))
if not PetSystem then
    warn("[一键锁宠] PetSystem 加载失败")
    return
end

local GamePlayer
local function GetGamePlayer()
    if GamePlayer then
        return GamePlayer
    end

    local ok, gp = pcall(function()
        return PathTool.ClientPlayerManager:GetGamePlayer()
    end)
    if not ok or not gp then
        ok, gp = pcall(function()
            return PathTool.ClientPlayerManager.GetGamePlayer()
        end)
    end

    if ok and gp then
        GamePlayer = gp
    end

    return GamePlayer
end

local GradeEnumNameMap = {
    Grade_1 = "E",
    Grade_2 = "D",
    Grade_3 = "C",
    Grade_4 = "B",
    Grade_5 = "A",
    Grade_6 = "S",
    Grade_7 = "SS",
}

local ZeroBasedGradeNameMap = {
    [0] = "E",
    [1] = "D",
    [2] = "C",
    [3] = "B",
    [4] = "A",
    [5] = "S",
    [6] = "SS",
}

local OneBasedGradeNameMap = {
    [1] = "E",
    [2] = "D",
    [3] = "C",
    [4] = "B",
    [5] = "A",
    [6] = "S",
    [7] = "SS",
}

local GradeOrderMap = {
    E = 1,
    D = 2,
    C = 3,
    B = 4,
    A = 5,
    S = 6,
    SS = 7,
}

-- SpecialProp: 0=普通, 1=巨大, 2=闪光, 4=血月 (可组合)
local SpecialPropDef = { Tp_Giant = 1, Tp_Shiny = 2, Tp_Bloodlit = 4 }
local SpecialPropName = { [1] = "巨大", [2] = "闪光", [4] = "血月" }

local cachedGradeAliasMap

local function BuildGradeAliasMap()
    local aliases = {}
    local petGrade = PathTool.Constants and PathTool.Constants.PetGrade

    if type(petGrade) == "table" then
        for enumName, gradeName in pairs(GradeEnumNameMap) do
            local enumValue = petGrade[enumName]
            if enumValue ~= nil then
                aliases[tostring(enumValue)] = gradeName
            end
        end
    end

    return aliases
end

local function GetGradeAliasMap()
    if not cachedGradeAliasMap then
        cachedGradeAliasMap = BuildGradeAliasMap()
    end
    return cachedGradeAliasMap
end

local function NormalizeGradeName(value)
    if value == nil then
        return nil
    end

    local valueType = type(value)
    if valueType == "string" then
        local trimmed = value:match("^%s*(.-)%s*$")
        if trimmed == "" then
            return nil
        end

        local upper = string.upper(trimmed)
        if GradeOrderMap[upper] then
            return upper
        end

        local enumIndex = upper:match("^GRADE_(%d+)$")
        if enumIndex then
            local numericIndex = tonumber(enumIndex)
            return OneBasedGradeNameMap[numericIndex] or ZeroBasedGradeNameMap[numericIndex] or upper
        end

        local alias = GetGradeAliasMap()[trimmed]
        if alias then
            return alias
        end

        local numericValue = tonumber(trimmed)
        if numericValue ~= nil then
            return NormalizeGradeName(numericValue)
        end

        return trimmed
    end

    if valueType == "number" then
        local constantsName = PathTool.Constants
            and PathTool.Constants.PetGradeName
            and PathTool.Constants.PetGradeName[value]
        if constantsName ~= nil then
            local normalizedConstantsName = NormalizeGradeName(constantsName)
            if normalizedConstantsName then
                return normalizedConstantsName
            end
        end

        local alias = GetGradeAliasMap()[tostring(value)]
        if alias then
            return alias
        end

        return OneBasedGradeNameMap[value] or ZeroBasedGradeNameMap[value] or tostring(value)
    end

    return tostring(value)
end

local function GetGradeDisplayName(grade)
    return NormalizeGradeName(grade) or "?"
end

local function GetGradeSortOrder(gradeName)
    return GradeOrderMap[gradeName] or 999
end

local function GetSpecialPropDisplayName(specialProp)
    if specialProp == nil or specialProp == 0 then
        return "普通"
    end

    if PathTool.PetSpecialPropUtil and PathTool.PetSpecialPropUtil.SpecialPropertyDesc then
        local desc = PathTool.PetSpecialPropUtil.SpecialPropertyDesc[specialProp]
        if desc and desc.Name then
            return desc.Name
        end
    end

    local parts = {}
    local function hasBit(n, b)
        if bit32 then
            return bit32.band(n, b) > 0
        end
        return math.floor(n / b) % 2 == 1
    end

    for _, val in pairs(SpecialPropDef) do
        if hasBit(specialProp, val) and SpecialPropName[val] then
            table.insert(parts, SpecialPropName[val])
        end
    end

    if #parts > 0 then
        return table.concat(parts, "+")
    end

    return tostring(specialProp)
end

-- 收集所有宠物 (按模板+品阶+特殊属性细分)
local function GetAllPetTemplates()
    local gp = GetGamePlayer()
    if not gp or not gp.pet then
        return {}
    end

    local group = {}

    pcall(function()
        gp.pet:IterItem(function(petItem)
            if not petItem then
                return true
            end

            local tmplId = petItem:GetTmplId()
            local rawGrade = petItem:GetGrade()
            local gradeKey = NormalizeGradeName(rawGrade)
            local specialProp = petItem:GetSpecialProp()
            if specialProp == nil then
                specialProp = 0
            end
            if not tmplId then
                return true
            end

            local key = string.format("%s_%s_%s", tostring(tmplId), tostring(gradeKey or "?"), tostring(specialProp))
            if not group[key] then
                local tmpl = petItem:GetTmpl()
                local name = tmpl and tmpl.Name or ("ID:" .. tostring(tmplId))
                local gradeName = GetGradeDisplayName(rawGrade)
                local spName = GetSpecialPropDisplayName(specialProp)
                group[key] = {
                    tmplId = tmplId,
                    gradeKey = gradeKey,
                    gradeName = gradeName,
                    specialProp = specialProp,
                    specialPropName = spName,
                    name = name,
                    count = 0,
                }
            end
            group[key].count = group[key].count + 1
            return true
        end)
    end)

    local templates = {}
    for _, templateData in pairs(group) do
        table.insert(templates, templateData)
    end

    table.sort(templates, function(a, b)
        if a.name ~= b.name then
            return a.name < b.name
        end
        if (a.gradeName or "?") ~= (b.gradeName or "?") then
            return GetGradeSortOrder(a.gradeName) < GetGradeSortOrder(b.gradeName)
        end
        return (a.specialPropName or "?") < (b.specialPropName or "?")
    end)

    return templates
end

-- 锁定/解锁指定模板（可选品阶、特殊属性）的宠物
local function SetPetLockByTemplate(tmplId, gradeKey, specialProp, lock)
    local gp = GetGamePlayer()
    if not gp or not gp.pet then
        return 0, 0
    end

    local done = 0
    local failed = 0

    pcall(function()
        gp.pet:IterItem(function(petItem)
            if not petItem then
                return true
            end

            if tmplId ~= nil and petItem:GetTmplId() ~= tmplId then
                return true
            end

            if gradeKey ~= nil and NormalizeGradeName(petItem:GetGrade()) ~= gradeKey then
                return true
            end

            if specialProp ~= nil then
                local itemSpecialProp = petItem:GetSpecialProp()
                if (itemSpecialProp or 0) ~= specialProp then
                    return true
                end
            end

            local petItemId = petItem:GetId()
            if not petItemId then
                return true
            end

            if petItem:IsLock() == lock then
                return true
            end

            local ok, result = pcall(function()
                return PetSystem.ClientLockPet(petItemId, lock)
            end)

            if ok and result then
                done = done + 1
                task.wait(0.2)
            else
                failed = failed + 1
            end

            return true
        end)
    end)

    return done, failed
end

local function LockAllPets(lock)
    return SetPetLockByTemplate(nil, nil, nil, lock)
end

-- ===== UI =====
local existingCoreGui = CoreGui:FindFirstChild("PetLockUnlockUI")
if existingCoreGui then
    existingCoreGui:Destroy()
end

local playerGui = player:FindFirstChild("PlayerGui")
if playerGui then
    local existingPlayerGui = playerGui:FindFirstChild("PetLockUnlockUI")
    if existingPlayerGui then
        existingPlayerGui:Destroy()
    end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PetLockUnlockUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 999999
screenGui.IgnoreGuiInset = false

local parentedToCoreGui = pcall(function()
    screenGui.Parent = CoreGui
end)

if not parentedToCoreGui or screenGui.Parent ~= CoreGui then
    screenGui.Parent = player:WaitForChild("PlayerGui")
end

local isTouchDevice = UserInputService.TouchEnabled
local TITLE_BAR_HEIGHT = isTouchDevice and 44 or 34
local TITLE_BUTTON_SIZE = isTouchDevice and 28 or 22
local BUTTON_HEIGHT = isTouchDevice and 40 or 34
local ROW_HEIGHT = isTouchDevice and 44 or 34
local PANEL_PADDING = isTouchDevice and 10 or 8
local CONTENT_GAP = isTouchDevice and 8 or 6

local function GetViewportSize()
    local camera = workspace.CurrentCamera
    if camera and camera.ViewportSize.X > 0 and camera.ViewportSize.Y > 0 then
        return camera.ViewportSize
    end
    return Vector2.new(1280, 720)
end

local function GetExpandedSize()
    local viewportSize = GetViewportSize()
    if isTouchDevice then
        local width = math.clamp(math.floor(viewportSize.X * 0.92), 290, 460)
        local height = math.clamp(math.floor(viewportSize.Y * 0.72), 280, 620)
        return Vector2.new(width, height)
    end

    return Vector2.new(320, 420)
end

local function GetDefaultPosition(size)
    local viewportSize = GetViewportSize()
    if isTouchDevice then
        return Vector2.new(
            math.floor((viewportSize.X - size.X) / 2),
            math.floor((viewportSize.Y - size.Y) / 2)
        )
    end

    return Vector2.new(
        math.max(8, viewportSize.X - size.X - 20),
        20
    )
end

local function ClampFramePosition(position, size)
    local viewportSize = GetViewportSize()
    local margin = 8
    local minX = margin
    local minY = margin
    local maxX = math.max(minX, viewportSize.X - size.X - margin)
    local maxY = math.max(minY, viewportSize.Y - size.Y - margin)

    return Vector2.new(
        math.clamp(math.floor(position.X + 0.5), minX, maxX),
        math.clamp(math.floor(position.Y + 0.5), minY, maxY)
    )
end

local mainFrame = Instance.new("Frame")
mainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = mainFrame

local titleBar = Instance.new("Frame")
titleBar.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleBarCorner = Instance.new("UICorner")
titleBarCorner.CornerRadius = UDim.new(0, 10)
titleBarCorner.Parent = titleBar

local titleBarFill = Instance.new("Frame")
titleBarFill.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
titleBarFill.BorderSizePixel = 0
titleBarFill.Parent = titleBar

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Text = "宠物锁定管理"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = isTouchDevice and 15 or 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local collapseBtn = Instance.new("TextButton")
collapseBtn.BackgroundColor3 = Color3.fromRGB(80, 110, 180)
collapseBtn.Text = "收"
collapseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
collapseBtn.Font = Enum.Font.GothamBold
collapseBtn.TextSize = isTouchDevice and 14 or 12
collapseBtn.Parent = titleBar
Instance.new("UICorner", collapseBtn).CornerRadius = UDim.new(0, 5)

local closeBtn = Instance.new("TextButton")
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = isTouchDevice and 14 or 12
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

local contentFrame = Instance.new("Frame")
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

local allBtnFrame = Instance.new("Frame")
allBtnFrame.BackgroundTransparency = 1
allBtnFrame.Parent = contentFrame

local lockAllBtn = Instance.new("TextButton")
lockAllBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 60)
lockAllBtn.Text = "全部上锁"
lockAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
lockAllBtn.Font = Enum.Font.Gotham
lockAllBtn.TextSize = isTouchDevice and 15 or 14
lockAllBtn.Parent = allBtnFrame
Instance.new("UICorner", lockAllBtn).CornerRadius = UDim.new(0, 6)

local unlockAllBtn = Instance.new("TextButton")
unlockAllBtn.BackgroundColor3 = Color3.fromRGB(120, 60, 60)
unlockAllBtn.Text = "全部解锁"
unlockAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
unlockAllBtn.Font = Enum.Font.Gotham
unlockAllBtn.TextSize = isTouchDevice and 15 or 14
unlockAllBtn.Parent = allBtnFrame
Instance.new("UICorner", unlockAllBtn).CornerRadius = UDim.new(0, 6)

local separator = Instance.new("Frame")
separator.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
separator.BorderSizePixel = 0
separator.Parent = contentFrame

local filterHeader = Instance.new("Frame")
filterHeader.BackgroundTransparency = 1
filterHeader.Parent = contentFrame

local filterTitle = Instance.new("TextLabel")
filterTitle.BackgroundTransparency = 1
filterTitle.Text = "按类型×品阶×特殊操作"
filterTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
filterTitle.Font = Enum.Font.Gotham
filterTitle.TextSize = isTouchDevice and 13 or 12
filterTitle.TextXAlignment = Enum.TextXAlignment.Left
filterTitle.Parent = filterHeader

local refreshBtn = Instance.new("TextButton")
refreshBtn.BackgroundColor3 = Color3.fromRGB(60, 80, 120)
refreshBtn.Text = "刷新"
refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshBtn.Font = Enum.Font.Gotham
refreshBtn.TextSize = isTouchDevice and 13 or 11
refreshBtn.Parent = filterHeader
Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 4)

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = isTouchDevice and 8 or 6
scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
scrollFrame.Parent = contentFrame
Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0, 6)

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 4)
listLayout.Parent = scrollFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingTop = UDim.new(0, 4)
listPadding.PaddingLeft = UDim.new(0, 4)
listPadding.PaddingRight = UDim.new(0, 4)
listPadding.Parent = scrollFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "就绪"
statusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = isTouchDevice and 12 or 11
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Center
statusLabel.Parent = contentFrame

local expandedSize = GetExpandedSize()
local isCollapsed = false
local layoutInitialized = false

local function UpdateScrollCanvas()
    scrollFrame.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 8)
end

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateScrollCanvas)

local function ApplyContentLayout()
    titleBar.Size = UDim2.new(1, 0, 0, TITLE_BAR_HEIGHT)
    titleBarFill.Size = UDim2.new(1, 0, 0, 10)
    titleBarFill.Position = UDim2.new(0, 0, 1, -10)

    closeBtn.Size = UDim2.fromOffset(TITLE_BUTTON_SIZE, TITLE_BUTTON_SIZE)
    closeBtn.Position = UDim2.new(1, -PANEL_PADDING - TITLE_BUTTON_SIZE, 0.5, -math.floor(TITLE_BUTTON_SIZE / 2))

    collapseBtn.Size = UDim2.fromOffset(TITLE_BUTTON_SIZE, TITLE_BUTTON_SIZE)
    collapseBtn.Position = UDim2.new(1, -PANEL_PADDING * 2 - TITLE_BUTTON_SIZE * 2, 0.5, -math.floor(TITLE_BUTTON_SIZE / 2))

    title.Size = UDim2.new(1, -(TITLE_BUTTON_SIZE * 2 + PANEL_PADDING * 4 + 12), 1, 0)
    title.Position = UDim2.fromOffset(PANEL_PADDING, 0)

    contentFrame.Position = UDim2.fromOffset(0, TITLE_BAR_HEIGHT)
    contentFrame.Size = UDim2.new(1, 0, 1, -TITLE_BAR_HEIGHT)
    contentFrame.Visible = not isCollapsed
    if isCollapsed then
        return
    end

    local contentWidth = mainFrame.AbsoluteSize.X
    local contentHeight = mainFrame.AbsoluteSize.Y - TITLE_BAR_HEIGHT
    local innerWidth = math.max(0, contentWidth - PANEL_PADDING * 2)
    local y = PANEL_PADDING

    allBtnFrame.Position = UDim2.fromOffset(PANEL_PADDING, y)
    allBtnFrame.Size = UDim2.new(1, -PANEL_PADDING * 2, 0, BUTTON_HEIGHT)

    local buttonGap = CONTENT_GAP
    local buttonWidth = math.floor((innerWidth - buttonGap) / 2)
    lockAllBtn.Size = UDim2.fromOffset(buttonWidth, BUTTON_HEIGHT)
    lockAllBtn.Position = UDim2.fromOffset(0, 0)
    unlockAllBtn.Size = UDim2.fromOffset(buttonWidth, BUTTON_HEIGHT)
    unlockAllBtn.Position = UDim2.fromOffset(buttonWidth + buttonGap, 0)

    y = y + BUTTON_HEIGHT + CONTENT_GAP

    separator.Position = UDim2.fromOffset(PANEL_PADDING, y)
    separator.Size = UDim2.new(1, -PANEL_PADDING * 2, 0, 1)

    y = y + CONTENT_GAP

    local headerHeight = BUTTON_HEIGHT - 8
    filterHeader.Position = UDim2.fromOffset(PANEL_PADDING, y)
    filterHeader.Size = UDim2.new(1, -PANEL_PADDING * 2, 0, headerHeight)

    local refreshWidth = isTouchDevice and 64 or 54
    refreshBtn.Size = UDim2.fromOffset(refreshWidth, BUTTON_HEIGHT - 12)
    refreshBtn.Position = UDim2.new(1, -refreshWidth, 0.5, -math.floor((BUTTON_HEIGHT - 12) / 2))

    filterTitle.Position = UDim2.fromOffset(0, 0)
    filterTitle.Size = UDim2.new(1, -refreshWidth - CONTENT_GAP, 1, 0)

    y = y + headerHeight + CONTENT_GAP

    local statusHeight = isTouchDevice and 34 or 24
    local scrollHeight = math.max(80, contentHeight - y - statusHeight - PANEL_PADDING - CONTENT_GAP)

    scrollFrame.Position = UDim2.fromOffset(PANEL_PADDING, y)
    scrollFrame.Size = UDim2.new(1, -PANEL_PADDING * 2, 0, scrollHeight)

    y = y + scrollHeight + CONTENT_GAP

    statusLabel.Position = UDim2.fromOffset(PANEL_PADDING, y)
    statusLabel.Size = UDim2.new(1, -PANEL_PADDING * 2, 0, statusHeight)

    UpdateScrollCanvas()
end

local function UpdateMainFrameLayout(preservePosition)
    expandedSize = GetExpandedSize()
    local targetSize = Vector2.new(expandedSize.X, isCollapsed and TITLE_BAR_HEIGHT or expandedSize.Y)

    local position
    if layoutInitialized and preservePosition then
        position = Vector2.new(mainFrame.Position.X.Offset, mainFrame.Position.Y.Offset)
    else
        position = GetDefaultPosition(targetSize)
    end

    position = ClampFramePosition(position, targetSize)

    mainFrame.Size = UDim2.fromOffset(targetSize.X, targetSize.Y)
    mainFrame.Position = UDim2.fromOffset(position.X, position.Y)
    layoutInitialized = true

    ApplyContentLayout()
end

local function SetCollapsed(collapsed)
    if isCollapsed == collapsed then
        return
    end

    isCollapsed = collapsed
    collapseBtn.Text = collapsed and "展" or "收"
    UpdateMainFrameLayout(true)
end

local dragging = false
local dragInput
local dragStart
local startPos

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Vector2.new(mainFrame.Position.X.Offset, mainFrame.Position.Y.Offset)

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        local targetSize = Vector2.new(mainFrame.AbsoluteSize.X, mainFrame.AbsoluteSize.Y)
        local targetPosition = ClampFramePosition(startPos + delta, targetSize)
        mainFrame.Position = UDim2.fromOffset(targetPosition.X, targetPosition.Y)
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    screenGui:Destroy()
end)

collapseBtn.MouseButton1Click:Connect(function()
    SetCollapsed(not isCollapsed)
end)

local function CreateTemplateRow(tmplData, index)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -8, 0, ROW_HEIGHT)
    row.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    row.BorderSizePixel = 0
    row.LayoutOrder = index
    row.Parent = scrollFrame
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 4)

    local gradeName = tmplData.gradeName or "?"
    local specialPropName = tmplData.specialPropName or "?"
    local displayText = string.format("%s [%s|%s] (%d)", tmplData.name, gradeName, specialPropName, tmplData.count)

    local actionButtonWidth = isTouchDevice and 48 or 40
    local actionButtonHeight = ROW_HEIGHT - 12

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -(actionButtonWidth * 2 + 24), 1, 0)
    nameLabel.Position = UDim2.fromOffset(8, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = displayText
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextSize = isTouchDevice and 13 or 11
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = row

    local unlockBtn = Instance.new("TextButton")
    unlockBtn.AnchorPoint = Vector2.new(1, 0.5)
    unlockBtn.Size = UDim2.fromOffset(actionButtonWidth, actionButtonHeight)
    unlockBtn.Position = UDim2.new(1, -8, 0.5, 0)
    unlockBtn.BackgroundColor3 = Color3.fromRGB(100, 60, 60)
    unlockBtn.Text = "解"
    unlockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    unlockBtn.Font = Enum.Font.Gotham
    unlockBtn.TextSize = isTouchDevice and 13 or 11
    unlockBtn.Parent = row
    Instance.new("UICorner", unlockBtn).CornerRadius = UDim.new(0, 4)

    local lockBtn = Instance.new("TextButton")
    lockBtn.AnchorPoint = Vector2.new(1, 0.5)
    lockBtn.Size = UDim2.fromOffset(actionButtonWidth, actionButtonHeight)
    lockBtn.Position = UDim2.new(1, -(actionButtonWidth + 14), 0.5, 0)
    lockBtn.BackgroundColor3 = Color3.fromRGB(60, 100, 60)
    lockBtn.Text = "锁"
    lockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    lockBtn.Font = Enum.Font.Gotham
    lockBtn.TextSize = isTouchDevice and 13 or 11
    lockBtn.Parent = row
    Instance.new("UICorner", lockBtn).CornerRadius = UDim.new(0, 4)

    lockBtn.MouseButton1Click:Connect(function()
        task.spawn(function()
            lockBtn.Text = "..."
            statusLabel.Text = string.format("正在锁定 %s [%s|%s]...", tmplData.name, gradeName, specialPropName)
            local done, failed = SetPetLockByTemplate(tmplData.tmplId, tmplData.gradeKey, tmplData.specialProp, true)
            lockBtn.Text = "锁"
            statusLabel.Text = string.format("锁定 %s [%s|%s]: 成功%d 失败%d", tmplData.name, gradeName, specialPropName, done, failed)
            print(string.format("[一键锁宠] 锁定 %s [%s|%s]: 成功 %d, 失败 %d", tmplData.name, gradeName, specialPropName, done, failed))
        end)
    end)

    unlockBtn.MouseButton1Click:Connect(function()
        task.spawn(function()
            unlockBtn.Text = "..."
            statusLabel.Text = string.format("正在解锁 %s [%s|%s]...", tmplData.name, gradeName, specialPropName)
            local done, failed = SetPetLockByTemplate(tmplData.tmplId, tmplData.gradeKey, tmplData.specialProp, false)
            unlockBtn.Text = "解"
            statusLabel.Text = string.format("解锁 %s [%s|%s]: 成功%d 失败%d", tmplData.name, gradeName, specialPropName, done, failed)
            print(string.format("[一键锁宠] 解锁 %s [%s|%s]: 成功 %d, 失败 %d", tmplData.name, gradeName, specialPropName, done, failed))
        end)
    end)

    return row
end

local function RefreshTemplateList()
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end

    statusLabel.Text = "加载中..."
    task.wait(0.1)

    local templates = GetAllPetTemplates()

    if #templates == 0 then
        statusLabel.Text = "背包中没有宠物"
        UpdateScrollCanvas()
        return
    end

    for index, tmplData in ipairs(templates) do
        CreateTemplateRow(tmplData, index)
    end

    UpdateScrollCanvas()
    statusLabel.Text = string.format("已加载 %d 种 (类型×品阶×特殊)", #templates)
end

lockAllBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        lockAllBtn.Text = "执行中..."
        statusLabel.Text = "正在锁定全部宠物..."
        local done, failed = LockAllPets(true)
        lockAllBtn.Text = "全部上锁"
        statusLabel.Text = string.format("全部上锁: 成功%d 失败%d", done, failed)
        print(string.format("[一键锁宠] 全部上锁: 成功 %d, 失败 %d", done, failed))
    end)
end)

unlockAllBtn.MouseButton1Click:Connect(function()
    task.spawn(function()
        unlockAllBtn.Text = "执行中..."
        statusLabel.Text = "正在解锁全部宠物..."
        local done, failed = LockAllPets(false)
        unlockAllBtn.Text = "全部解锁"
        statusLabel.Text = string.format("全部解锁: 成功%d 失败%d", done, failed)
        print(string.format("[一键锁宠] 全部解锁: 成功 %d, 失败 %d", done, failed))
    end)
end)

refreshBtn.MouseButton1Click:Connect(function()
    task.spawn(RefreshTemplateList)
end)

local viewportConnection
local function BindViewportWatcher()
    if viewportConnection then
        viewportConnection:Disconnect()
        viewportConnection = nil
    end

    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            UpdateMainFrameLayout(true)
        end)
    end
end

BindViewportWatcher()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    BindViewportWatcher()
    task.defer(function()
        UpdateMainFrameLayout(true)
    end)
end)

UpdateMainFrameLayout(false)

task.spawn(function()
    for _ = 1, 60 do
        if GetGamePlayer() then
            print("[一键锁宠] 已加载")
            RefreshTemplateList()
            return
        end
        task.wait(0.5)
    end
    statusLabel.Text = "加载超时，请点击刷新"
end)

print("[一键锁宠] 界面已显示")
