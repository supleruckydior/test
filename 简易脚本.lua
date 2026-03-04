-- ============================================
-- 游戏初始化检查（增强版）
-- ============================================
-- 等待游戏完全加载
if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- 收菜/炼丹完成时写入 yummytool 的时机：true=收菜完成时写入，false=炼丹完成时写入
if G_colectherb == nil then
    G_colectherb = true  -- 默认收菜完成时写入，兼容旧用法
end

local currentGameId = game.PlaceId
local TARGET_GAME_ID = 18645473062

if currentGameId ~= TARGET_GAME_ID then
    warn('当前游戏不是目标游戏，脚本未运行。')
    return
end

print('检测到目标游戏，正在执行脚本...')

-- ============================================
-- 服务引用（统一管理，避免重复获取）
-- ============================================
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Players = game:GetService('Players')
local Workspace = game:GetService('Workspace')
local CoreGui = game:GetService('CoreGui')
local VirtualUser = game:GetService('VirtualUser')

-- ============================================
-- 玩家和GUI引用（增强等待机制）
-- ============================================
-- 等待玩家存在
local player = Players.LocalPlayer
if not player then
    player = Players.PlayerAdded:Wait()
end

-- 等待玩家角色加载（如果存在）
if player.Character then
    player.Character:WaitForChild('HumanoidRootPart', 10)
end

-- 等待PlayerGui存在
local maxWaitTime = 300 -- 最多等待30秒
local startTime = os.clock()
while not player:FindFirstChild('PlayerGui') do
    if os.clock() - startTime > maxWaitTime then
        warn('[初始化] 等待PlayerGui超时，继续执行...')
        break
    end
    task.wait(0.5)
end

local playerGui = player.PlayerGui

-- 等待GUI存在，使用超时机制
local GUI
local success, result = pcall(function()
    GUI = playerGui:WaitForChild('GUI', 10)
end)

if not success or not GUI then
    warn('[初始化] 等待GUI超时，尝试重新等待...')
    -- 再次尝试等待
    task.wait(2)
    GUI = playerGui:WaitForChild('GUI', 20)
end

if not GUI then
    error('[初始化错误] 无法找到GUI，脚本无法继续执行')
    return
end

-- ============================================
-- 等待游戏加载动画完成
-- ============================================
local function waitForGameLoadComplete(maxWaitTime)
    maxWaitTime = maxWaitTime or 120 -- 默认最多等待60秒
    
    print('[初始化] 等待游戏加载动画完成...')
    
    -- 第一步：等待加载动画路径出现（因为注入可能比动画加载还早）
    local pathWaitTimeout = 30 -- 等待路径出现的超时时间（15秒）
    local pathWaitStartTime = os.clock()
    local loadingAnimation = nil
    
    print('[初始化] 等待加载动画路径出现...')
    
    -- 循环检查完整路径，不使用 WaitForChild
    while os.clock() - pathWaitStartTime < pathWaitTimeout do
        local success, result = pcall(function()
            -- 直接使用完整路径访问
            return game:GetService("Players").LocalPlayer.PlayerGui.GUI["\228\186\140\231\186\167\231\149\140\233\157\162"]["\229\138\160\232\189\189\233\161\181\233\157\162"]
        end)
        
        if success and result and result.Parent then
            loadingAnimation = result
            -- 检查是否可见，如果可见就跳出循环
            if loadingAnimation.Visible then
                print('[初始化] 检测到加载动画（可见），等待动画完成...')
                break
            end
            -- 如果路径存在但不可见，继续等待直到它变为可见
        end
        
        task.wait(0.3)
    end
    
    -- 如果等待路径超时，可能是已经加载完成（路径被销毁了），直接继续
    if not loadingAnimation then
        print('[初始化] 等待路径超时，可能已加载完成，继续执行...')
        return true
    end
    
    -- 第二步：如果路径存在但不可见，等待它变为可见（动画开始显示）
    if loadingAnimation and not loadingAnimation.Visible then
        print('[初始化] 路径存在但不可见，等待动画开始显示...')
        local visibleWaitStartTime = os.clock()
        local visibleWaitTimeout = 30 -- 等待可见的超时时间（10秒）
        
        while os.clock() - visibleWaitStartTime < visibleWaitTimeout do
            local checkSuccess, checkResult = pcall(function()
                return game:GetService("Players").LocalPlayer.PlayerGui.GUI["\228\186\140\231\186\167\231\149\140\233\157\162"]["\229\138\160\232\189\189\233\161\181\233\157\162"]
            end)
            
            if checkSuccess and checkResult and checkResult.Parent and checkResult.Visible then
                print('[初始化] 加载动画已显示，等待动画完成...')
                loadingAnimation = checkResult
                break
            end
            
            task.wait(0.3)
        end
        
        -- 如果等待可见超时，可能已经加载完成，直接继续
        if not loadingAnimation.Visible then
            print('[初始化] 等待可见超时，可能已加载完成，继续执行...')
            return true
        end
    end
    
    -- 第三步：等待加载动画消失（表示加载完成）
    if loadingAnimation and loadingAnimation.Visible then
        local startTime = os.clock()
        print('[初始化] 等待加载动画消失...')
        
        while os.clock() - startTime < maxWaitTime do
            -- 使用完整路径检查加载动画是否还存在且可见
            local checkSuccess, checkResult = pcall(function()
                return game:GetService("Players").LocalPlayer.PlayerGui.GUI["\228\186\140\231\186\167\231\149\140\233\157\162"]["\229\138\160\232\189\189\233\161\181\233\157\162"]
            end)
            
            -- 如果加载动画不存在或不可见，说明加载完成
            if not checkSuccess or not checkResult or not checkResult.Parent or not checkResult.Visible then
                print('[初始化] 游戏加载完成！')
                return true
            end
            
            task.wait(0.5)
        end
        
        warn('[初始化] 等待游戏加载超时，继续执行...')
    end
    
    return true
end

-- 等待游戏加载完成
waitForGameLoadComplete(120)

-- 额外等待确保GUI完全初始化（避免菜单加载不正确）
print('[初始化] 等待GUI完全初始化...')
task.wait(2)

-- ============================================
-- 等待二级界面出现并更新GUI对象
-- ============================================
print('[初始化] 等待二级界面出现...')
local secondaryUIWaitTimeout = 30
local secondaryUIWaitStartTime = os.clock()
local secondaryUIReady = false

while os.clock() - secondaryUIWaitStartTime < secondaryUIWaitTimeout do
    local success, result = pcall(function()
        local currentGUI = game:GetService("Players").LocalPlayer.PlayerGui.GUI
        return currentGUI:FindFirstChild("\228\186\140\231\186\167\231\149\140\233\157\162")
    end)
    
    if success and result and result.Parent then
        -- 更新全局GUI对象，确保使用正确的GUI
        GUI = game:GetService("Players").LocalPlayer.PlayerGui.GUI
        secondaryUIReady = true
        print('[初始化] 二级界面已出现，GUI对象已更新')
        break
    end
    
    task.wait(0.5)
end

if not secondaryUIReady then
    warn('[初始化] 等待二级界面超时，继续执行...')
    -- 即使超时也更新GUI对象
    GUI = game:GetService("Players").LocalPlayer.PlayerGui.GUI
end

-- ============================================
-- 工具函数
-- ============================================
-- 深度等待子对象
local function deepWait(parent, path, eachTimeout)
    local obj = parent
    for _, name in ipairs(path) do
        obj = obj and obj:WaitForChild(name, eachTimeout or 5)
        if not obj then
            return nil
        end
    end
    return obj
end

-- 统一的数值解析函数（替代重复的解析逻辑）
local function parseNumber(text, default)
    if not text then return default or 0 end
    
    local str = tostring(text):lower():gsub('%s+', ''):gsub(',', '')
    local numStr = str:gsub('[^%d%.]', '')
    
    -- 检查多个小数点
    local dotCount = select(2, numStr:gsub('%.', ''))
    if dotCount > 1 then
        warn('[数值异常] 非法格式:', text)
        return default or 0
    end
    
    local multiplier = 1
    if str:find('k') then
        multiplier = 1000
    elseif str:find('m') then
        multiplier = 1000000
    end
    
    return (tonumber(numStr) or 0) * multiplier
end

-- 数字格式化函数
local function formatNumber(num)
    if not num then return "N/A" end
    if num >= 1000 then
        return string.format("%.1fK", num / 1000):gsub("%.0K", "K")
    else
        return tostring(math.floor(num))
    end
end

-- ============================================
-- 加载外部脚本（带错误处理）
-- ============================================

local library
local success, err = pcall(function()
    library = loadstring(
        game:HttpGet(
            'https://raw.githubusercontent.com/supleruckydior/test/refs/heads/main/menu.json',
            true
        )
    )()
end)
if not success then
    warn('[初始化错误] 加载library失败:', err)
    return
end

local RespawPoint
success, err = pcall(function()
    RespawPoint = loadstring(
        game:HttpGet(
            'https://raw.githubusercontent.com/Tseting-nil/-Cultivation-Simulator-script/refs/heads/main/%E6%89%8B%E6%A9%9F%E7%AB%AFUI/%E9%85%8D%E7%BD%AE%E4%B8%BB%E5%A0%B4%E6%99%AF.lua'
        )
    )()
end)
if not success then
    warn('[初始化错误] 加载RespawPoint失败:', err)
    return
end

success, err = pcall(function()
    loadstring(
        game:HttpGet(
            'https://github.com/supleruckydior/test/raw/refs/heads/main/respawn.json'
        )
    )()
end)
if not success then
    warn('[初始化警告] 加载respawn.json失败:', err)
end

local JsonHandler
success, err = pcall(function()
    JsonHandler = loadstring(
        game:HttpGet(
            'https://raw.githubusercontent.com/Tseting-nil/-Cultivation-Simulator-script/refs/heads/main/JSON%E6%A8%A1%E7%B5%84.lua'
        )
    )()
end)
if not success then
    warn('[初始化警告] 加载JsonHandler失败:', err)
end


-- ============================================
-- Anti-AFK 设置
-- ============================================
local AntiAFK = VirtualUser
player.Idled:Connect(function()
    AntiAFK:CaptureController()
    AntiAFK:ClickButton2(Vector2.new())
    task.wait(2)
end)

-- ============================================
-- 创建主窗口
-- ============================================
local window = library:AddWindow('Cultivation-Simulator  養成模擬器v2.5', {
    main_color = Color3.fromRGB(41, 74, 122),
    min_size = Vector2.new(530, 315),
    can_resize = false,
})

-- 设置窗口低层级
if window then
    local mainGui = window.gui or window.Instance
    if mainGui then
        mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        local function setLowZIndex(obj)
            if obj:IsA("GuiObject") then
                obj.ZIndex = 10
            end
            for _, child in pairs(obj:GetChildren()) do
                setLowZIndex(child)
            end
        end
        setLowZIndex(mainGui)
    end
end

-- ============================================
-- 创建标签页
-- ============================================
local features1 = window:AddTab('杂项')
local features4 = window:AddTab('炼丹')

-- ============================================
-- 游戏数据初始化（带错误处理）
-- ============================================

local RespawPointnum
if RespawPoint then
    RespawPointnum = RespawPoint:match('%d+')
    if RespawPointnum then
        print('重生點編號：' .. RespawPointnum)
    else
        warn('[初始化警告] 无法获取重生点编号')
    end
else
    warn('[初始化警告] RespawPoint未加载')
end

-- 等待关键对象加载
local reworld
local TPX, TPY, TPZ = 0, 0, 0
if RespawPointnum then
    local success, result = pcall(function()
        reworld = Workspace:WaitForChild('主場景' .. RespawPointnum, 10):WaitForChild('重生点', 10)
        TPX, TPY, TPZ = reworld.Position.X, reworld.Position.Y + 5, reworld.Position.Z
    end)
    if not success then
        warn('[初始化警告] 无法找到重生点，使用默认值')
    end
end

local values
local privileges
local success, result = pcall(function()
    values = player:WaitForChild('值', 15)
    privileges = values:WaitForChild('特权', 10)
end)
if not success then
    warn('[初始化警告] 无法加载玩家值和特权，某些功能可能无法使用')
end



-- ============================================
-- 数值获取函数（统一使用 parseNumber）
-- ============================================
local function getHerbValue()
    local herbText = '0'
    pcall(function()
        herbText = game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159\229\143\179']['\232\141\137\232\141\175']['\229\128\188'].Text
    end)
    return parseNumber(herbText, 0)
end

-- 丹药数据同步（用于统计总丹药数量，参考丹药交易脚本）
local elixirData = {}
local ELIXIR_BACKPACK_KEY = '\232\131\140\229\140\133'
local ELIXIR_COUNT_KEY = '\230\149\176\233\135\143'
local ELIXIR_QUALITY_KEY = '品质'
local ELIXIR_INDEX_KEY = '索引'
local ELIXIR_QUALITY_POINTS = {
    [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5,
    [6] = 6, [7] = 8, [8] = 10, [9] = 14, [10] = 20,
    [11] = 28
}

-- 使用与丹药交易相同的直接路径获取同步事件
local elixirSyncEvent
local syncSuccess, syncResult = pcall(function()
    return ReplicatedStorage
        ["\228\186\139\228\187\182"]
        ["\229\174\162\230\136\183\231\171\175"]
        ["\229\174\162\230\136\183\231\171\175\228\184\185\232\141\175"]
        ["\228\184\185\232\141\175\230\149\176\230\141\174\229\143\152\229\140\150"]
end)

local function mergeElixirSyncData(data)
    if type(data) ~= 'table' then
        return false
    end

    local fullBackpack = data[ELIXIR_BACKPACK_KEY]
    if type(fullBackpack) == 'table' then
        elixirData = data
        return true
    end

    local backpack = elixirData[ELIXIR_BACKPACK_KEY]
    if type(backpack) ~= 'table' then
        backpack = {}
        elixirData = {
            [ELIXIR_BACKPACK_KEY] = backpack
        }
    end

    local function upsertItem(item)
        if type(item) ~= 'table' then
            return
        end

        local itemIndex = item[ELIXIR_INDEX_KEY]
        if itemIndex == nil then
            return
        end

        local numericIndex = tonumber(itemIndex)
        if numericIndex then
            backpack[numericIndex] = item
            return
        end

        local normalizedIndex = tostring(itemIndex)
        for slot, existing in pairs(backpack) do
            if type(existing) == 'table' and tostring(existing[ELIXIR_INDEX_KEY]) == normalizedIndex then
                backpack[slot] = item
                return
            end
        end

        backpack[#backpack + 1] = item
    end

    if data[ELIXIR_INDEX_KEY] ~= nil then
        upsertItem(data)
        return true
    end

    local merged = false
    for _, item in pairs(data) do
        if type(item) == 'table' then
            upsertItem(item)
            merged = true
        end
    end

    return merged
end

if syncSuccess and syncResult then
    elixirSyncEvent = syncResult
    elixirSyncEvent.Event:Connect(function(data)
        mergeElixirSyncData(data)
    end)
    print('[丹药同步] 已连接 elixirSyncEvent，实时监听丹药数据')
else
    warn('[丹药同步] 无法获取同步事件，丹药数量显示可能不可用:', syncResult)
end

-- 计算总丹药数量（兼容数组和字典两种背包结构，参考丹药交易）
local function getElixirTotals()
    if type(elixirData) ~= 'table' then
        return nil, nil
    end

    local backpack = elixirData[ELIXIR_BACKPACK_KEY]
    if type(backpack) ~= 'table' then
        return nil, nil
    end

    local totalCount = 0
    local totalPoints = 0

    -- 使用 pairs 同时支持数组和字典结构
    for _, item in pairs(backpack) do
        if type(item) == 'table' then
            local count = parseNumber(item[ELIXIR_COUNT_KEY], 0)
            if count > 0 then
                totalCount = totalCount + count

                local quality = tonumber(item[ELIXIR_QUALITY_KEY]) or 0
                local pointPerItem = ELIXIR_QUALITY_POINTS[quality]
                if pointPerItem then
                    totalPoints = totalPoints + (count * pointPerItem)
                end
            end
        end
    end

    return totalCount, totalPoints
end

local function getOREValue()
    local OREText = '0'
    pcall(function()
        OREText = game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159\229\143\179']['\231\159\191\231\159\179']['\229\128\188'].Text
    end)
    return parseNumber(OREText, 0)
end

local function getDiamond()
    local diamondText = '0'
    pcall(function()
        diamondText = game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159']['\233\146\187\231\159\179']['\230\140\137\233\146\174']['\229\128\188'].Text
    end)
    return parseNumber(diamondText, 0)
end

local function getGuildCoin()
    local guildCoinText = '0'
    pcall(function()
        guildCoinText = game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154']['\232\131\140\230\153\175']['\229\143\179\228\190\167\231\149\140\233\157\162']['\229\149\134\229\186\151']['\229\133\172\228\188\154\229\184\129']['\230\140\137\233\146\174']['\229\128\188'].Text
    end)
    return parseNumber(guildCoinText, 0)
end

local function getRefreshCost()
    local refreshCostText = '0'
    pcall(function()
        refreshCostText = game:GetService('Players').LocalPlayer.PlayerGui.GUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154']['\232\131\140\230\153\175']['\229\143\179\228\190\167\231\149\140\233\157\162']['\229\149\134\229\186\151']['\229\136\183\230\150\176']['\230\140\137\233\146\174']['\229\128\188'].Text
    end)
    return parseNumber(refreshCostText, 0)
end

-- 公会名称缓存（只获取一次，避免反复开关UI）
local guildNameCache = {
    value = '',
    hasFetched = false  -- 标记是否已经获取过
}

-- 获取公会名称的函数（只获取一次，之后使用缓存）
local function getGuildName(forceRefresh)
    -- 如果已经获取过且不强制刷新，直接返回缓存值
    if guildNameCache.hasFetched and not forceRefresh then
        return guildNameCache.value
    end
    
    local guildNameText = ''
    local wasUIOpen = false  -- 记录UI原本是否打开
    
    pcall(function()
        -- 使用完整路径获取GUI
        local currentGUI = game:GetService("Players").LocalPlayer.PlayerGui.GUI
        -- 检查UI是否已经打开
        local guildTab = currentGUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154']
        if guildTab then
            wasUIOpen = guildTab.Visible
        end
        
        -- 如果UI未打开，则打开它来刷新数据
        if not wasUIOpen then
            pcall(function()
                currentGUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154'].Visible = true
            end)
            -- 等待UI打开和数据刷新
            task.wait(0.5)
        end
        
        -- 使用完整路径直接获取公会名称
        local textLabel = currentGUI["\228\186\140\231\186\167\231\149\140\233\157\162"]["\229\133\172\228\188\154"]["\232\131\140\230\153\175"]["\229\143\179\228\190\167\231\149\140\233\157\162"]["\228\184\187\233\161\181"]["\228\187\139\231\187\141"]["\229\144\141\231\167\176"]["\230\150\135\230\156\172"]["\230\150\135\230\156\172"]
        if textLabel then
            guildNameText = textLabel.Text or ''
        end
        
        -- 如果原本UI是关闭的，则关闭它
        if not wasUIOpen then
            pcall(function()
                currentGUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154'].Visible = false
            end)
        end
        
        -- 更新缓存
        guildNameCache.value = guildNameText or ''
        guildNameCache.hasFetched = true
    end)
    return guildNameCache.value
end

-- ============================================
-- 数据保存功能（使用Synapse文件系统，TSV格式适合EmEditor）
-- ============================================
-- 数据保存路径（Synapse工作目录）
local DATA_FILE_PATH = "roblox_account_data.tsv"
local DATA_SAVE_INTERVAL = 3
local DATA_FILE_HEADER = "账号\t草药数量\t矿石数量\t更新时间\t公会名字"
local DATA_MAX_FILE_SIZE = 10 * 1024 * 1024

local saveState = {
    isSaving = false,
    dataLoopStarted = false,
    lastSnapshot = "",
    warnedMissingFileApi = false
}

local function hasLocalFileApi()
    return type(writefile) == "function"
        and type(readfile) == "function"
        and type(isfile) == "function"
end

local function sanitizeTSVField(value)
    local text = tostring(value or "")
    -- 避免把换行或制表符写进 TSV，防止整行错列
    text = text:gsub("[\r\n\t]", " ")
    return text
end

local function toSafeInt(value)
    local num = tonumber(value) or 0
    num = math.floor(num)
    if num < 0 then
        return 0
    end
    return num
end

local function splitTSVLine(line)
    local columns = {}
    local startIndex = 1

    while true do
        local tabIndex = string.find(line, "\t", startIndex, true)
        if not tabIndex then
            columns[#columns + 1] = string.sub(line, startIndex)
            break
        end

        columns[#columns + 1] = string.sub(line, startIndex, tabIndex - 1)
        startIndex = tabIndex + 1
    end

    return columns
end

local function parseTSVContent(content)
    local records = {}
    local parsedRowCount = 0
    local skippedRowCount = 0

    for line in content:gmatch("[^\r\n]+") do
        local columns = splitTSVLine(line)
        local accountName = sanitizeTSVField(columns[1] or "")
        local secondColumn = sanitizeTSVField(columns[2] or "")
        local isHeaderRow = accountName == "账号" and secondColumn == "草药数量"

        if not isHeaderRow then
            if accountName == "" then
                skippedRowCount = skippedRowCount + 1
            else
                records[accountName] = {
                    herbs = toSafeInt(columns[2]),
                    ore = toSafeInt(columns[3]),
                    updated_at = sanitizeTSVField(columns[4] or ""),
                    guild_name = sanitizeTSVField(columns[5] or "")
                }
                parsedRowCount = parsedRowCount + 1
            end
        end
    end

    return records, parsedRowCount, skippedRowCount
end

local function readExistingAccountData()
    if not isfile(DATA_FILE_PATH) then
        return {}, 0, 0, nil
    end

    local readSuccess, readResult = pcall(function()
        return readfile(DATA_FILE_PATH)
    end)

    if not readSuccess then
        return nil, 0, 0, tostring(readResult)
    end

    local content = tostring(readResult or "")
    if content == "" then
        return {}, 0, 0, nil
    end

    if #content > DATA_MAX_FILE_SIZE then
        warn("[数据保存] 警告: 文件体积超过 10MB，读取可能不完整:", #content, "字节")
    end

    local records, parsedRowCount, skippedRowCount = parseTSVContent(content)
    return records, parsedRowCount, skippedRowCount, nil
end

local function buildTSVContent(records)
    local accounts = {}
    for accountName, _ in pairs(records) do
        accounts[#accounts + 1] = accountName
    end
    table.sort(accounts)

    local lines = { DATA_FILE_HEADER }
    for _, accountName in ipairs(accounts) do
        local row = records[accountName]
        lines[#lines + 1] = table.concat({
            sanitizeTSVField(accountName),
            tostring(toSafeInt(row.herbs)),
            tostring(toSafeInt(row.ore)),
            sanitizeTSVField(row.updated_at),
            sanitizeTSVField(row.guild_name)
        }, "\t")
    end

    return table.concat(lines, "\n") .. "\n", #accounts
end

local function saveDataToLocal()
    if saveState.isSaving then
        return
    end

    if not hasLocalFileApi() then
        if not saveState.warnedMissingFileApi then
            warn("[数据保存] 当前执行器不支持 writefile/readfile/isfile，已跳过本地保存")
            saveState.warnedMissingFileApi = true
        end
        return
    end
    saveState.warnedMissingFileApi = false

    saveState.isSaving = true
    local success, err = pcall(function()
        local accountName = sanitizeTSVField(player and player.Name or "")
        if accountName == "" then
            warn("[数据保存] 账号名为空，跳过本次保存")
            return
        end

        local herbValue = toSafeInt(getHerbValue())
        local oreValue = toSafeInt(getOREValue())
        local guildNameValue = sanitizeTSVField(getGuildName())
        local snapshot = table.concat({
            accountName,
            tostring(herbValue),
            tostring(oreValue),
            guildNameValue
        }, "\t")

        -- 本账号关键数据未变化时跳过写盘，减少 I/O 压力
        if snapshot == saveState.lastSnapshot and isfile(DATA_FILE_PATH) then
            return
        end

        local accountData, oldDataCount, skippedRows, readErr = readExistingAccountData()
        if not accountData then
            warn("[数据保存] 读取旧数据失败，取消覆盖写入:", readErr)
            return
        end

        if skippedRows > 0 then
            warn("[数据保存] 读取旧数据时跳过了异常行:", skippedRows)
        end

        accountData[accountName] = {
            herbs = herbValue,
            ore = oreValue,
            updated_at = os.date("%Y-%m-%d %H:%M:%S"),
            guild_name = guildNameValue
        }

        local tsvContent, accountCount = buildTSVContent(accountData)
        if #tsvContent > DATA_MAX_FILE_SIZE then
            warn("[数据保存] 警告: 本次写入内容超过 10MB，可能失败:", #tsvContent, "字节")
        end

        local writeSuccess, writeErr = pcall(function()
            writefile(DATA_FILE_PATH, tsvContent)
        end)
        if not writeSuccess then
            warn("[数据保存] 写入文件失败:", writeErr)
            return
        end

        saveState.lastSnapshot = snapshot
        print(string.format("[数据保存] 已保存到 %s，账号总数: %d（旧数据: %d）", DATA_FILE_PATH, accountCount, oldDataCount))
    end)

    saveState.isSaving = false

    if not success then
        warn("[数据保存] 保存过程中发生错误:", err)
    end
end

-- 数据保存循环（在收菜完成后启动）
local function startDataSaveLoop()
    if saveState.dataLoopStarted then
        return
    end
    saveState.dataLoopStarted = true

    -- 启动时立即保存一次，避免必须等一个周期
    saveDataToLocal()

    task.spawn(function()
        while true do
            task.wait(DATA_SAVE_INTERVAL)
            saveDataToLocal()
        end
    end)
end

-- ============================================
-- 通知系统
-- ============================================
local function showTopRightNotice(text, lifetime)
    local imgui = CoreGui:FindFirstChild("imgui")
    
    -- 保存原始可见状态
    local originalVisibility = {}
    if imgui then
        for _, window in pairs(imgui:GetChildren()) do
            if window:IsA("GuiObject") then
                originalVisibility[window] = window.Visible
                window.Visible = false
            end
        end
    end
    
    -- 清理旧GUI
    local existingGui = CoreGui:FindFirstChild('FarmNoticeGui')
    if existingGui then
        existingGui:Destroy()
    end
    
    -- 创建新GUI
    local gui = Instance.new('ScreenGui')
    gui.Name = 'FarmNoticeGui'
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    gui.DisplayOrder = 99999
    gui.IgnoreGuiInset = true
    gui.Parent = CoreGui

    -- 背景
    local background = Instance.new('Frame')
    background.Name = 'Background'
    background.Size = UDim2.new(1, 0, 1, 0)
    background.Position = UDim2.new(0, 0, 0, 0)
    background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    background.BackgroundTransparency = 0.5
    background.BorderSizePixel = 0
    background.ZIndex = 99999
    background.Parent = gui

    -- 容器
    local container = Instance.new('Frame')
    container.Name = 'Container'
    container.Size = UDim2.new(0.4, 0, 0.4, 0)
    container.Position = UDim2.new(0.3, 0, 0.3, 0)
    container.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    container.BorderSizePixel = 2
    container.BorderColor3 = Color3.fromRGB(255, 0, 0)
    container.ZIndex = 100000
    container.Parent = gui

    -- 标题
    local title = Instance.new('TextLabel')
    title.Name = 'Title'
    title.Size = UDim2.new(1, 0, 0.3, 0)
    title.Position = UDim2.new(0, 0, 0.1, 0)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 0, 0)
    title.TextScaled = true
    title.Text = text or "收菜完成！"
    title.Font = Enum.Font.SourceSansBold
    title.ZIndex = 100001
    title.TextStrokeTransparency = 0.3
    title.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    title.Parent = container

    -- 草药数量显示
    local herbLabel = Instance.new('TextLabel')
    herbLabel.Name = 'HerbLabel'
    herbLabel.Size = UDim2.new(1, 0, 0.18, 0)
    herbLabel.Position = UDim2.new(0, 0, 0.4, 0)
    herbLabel.BackgroundTransparency = 1
    herbLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
    herbLabel.TextScaled = true
    herbLabel.Font = Enum.Font.SourceSansBold
    herbLabel.ZIndex = 100001
    herbLabel.TextStrokeTransparency = 0.3
    herbLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    herbLabel.Text = "获取中..."
    herbLabel.Parent = container

    -- 总丹药数量显示
    local elixirLabel = Instance.new('TextLabel')
    elixirLabel.Name = 'ElixirLabel'
    elixirLabel.Size = UDim2.new(1, 0, 0.18, 0)
    elixirLabel.Position = UDim2.new(0, 0, 0.58, 0)
    elixirLabel.BackgroundTransparency = 1
    elixirLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
    elixirLabel.TextScaled = true
    elixirLabel.Font = Enum.Font.SourceSansBold
    elixirLabel.ZIndex = 100001
    elixirLabel.TextStrokeTransparency = 0.3
    elixirLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    elixirLabel.Text = "总丹药: 获取中..."
    elixirLabel.Parent = container

    -- 更新草药数量
    local isFinished = false
    local function updateHerbCount()
        if isFinished then return end
        local success, currentHerbs = pcall(getHerbValue)
        currentHerbs = success and currentHerbs or 0
        
        if currentHerbs < 5000 then
            isFinished = true
            herbLabel.Text = "炼药完成！！！"
            herbLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
        else
            herbLabel.Text = "当前草药: " .. formatNumber(currentHerbs)
            herbLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        end

        local totalElixirs, totalElixirPoints = getElixirTotals()
        if totalElixirs ~= nil then
            local displayValue = (totalElixirPoints and totalElixirPoints > 0) and totalElixirPoints or totalElixirs
            elixirLabel.Text = "总丹药: " .. formatNumber(displayValue)
            elixirLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
        else
            elixirLabel.Text = "总丹药: 获取中..."
            elixirLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
        end
    end

    -- 更新循环
    local updating = true
    task.spawn(function()
        while updating and gui and gui.Parent do
            updateHerbCount()
            task.wait(1)
        end
    end)

    -- 按钮容器
    local buttonContainer = Instance.new('Frame')
    buttonContainer.Name = 'ButtonContainer'
    buttonContainer.Size = UDim2.new(0.8, 0, 0.18, 0)
    buttonContainer.Position = UDim2.new(0.1, 0, 0.78, 0)
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.ZIndex = 100001
    buttonContainer.Parent = container

    -- 关闭按钮
    local closeButton = Instance.new('TextButton')
    closeButton.Name = 'CloseButton'
    closeButton.Size = UDim2.new(1, 0, 1, 0)
    closeButton.Position = UDim2.new(0, 0, 0, 0)
    closeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    closeButton.BorderSizePixel = 1
    closeButton.BorderColor3 = Color3.fromRGB(100, 100, 100)
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.Text = "关闭"
    closeButton.TextScaled = true
    closeButton.ZIndex = 100002
    closeButton.Parent = buttonContainer

    -- 关闭逻辑
    local function removeGUI()
        updating = false
        if imgui then
            for window, visible in pairs(originalVisibility) do
                if window and window.Parent and window:IsA("GuiObject") then
                    window.Visible = visible
                end
            end
        end
        if gui then
            gui:Destroy()
        end
    end

    closeButton.MouseButton1Click:Connect(removeGUI)

    if lifetime and lifetime > 0 then
        task.delay(lifetime, removeGUI)
    end

    updateHerbCount()
end

-- ============================================
-- 任务完成状态管理
-- ============================================
local donationFinished = false
local herbBuyFinished = false
local herbCollectFinished = false
local farmReady = false
local hasShownCompletionNotice = false
local completionFileWritten = false

local function writeCompletionMarkerOnce()
    if completionFileWritten then
        return
    end
    if not writefile then
        return
    end
    local path = player.Name .. ".txt"
    pcall(function()
        writefile(path, "Yummytool")
        completionFileWritten = true
    end)
end

local function checkAllTasksFinished()
    if donationFinished and herbBuyFinished and herbCollectFinished and farmReady and not hasShownCompletionNotice then
        hasShownCompletionNotice = true
        if G_colectherb then
            writeCompletionMarkerOnce()
        end
        showTopRightNotice('收菜完成！', 99999)
        print('[系统] 所有任务完成，显示完成通知')
        -- 收菜完成后开始每3秒保存数据
        startDataSaveLoop()
    end
end

-- ============================================
-- 杂项标签页设置
-- ============================================
local function setupFeatures1Tab(features1)
    local timeLabel = features1:AddLabel('距離下自動獲取還有 0 秒')
    
    -- 等待GUI元素准备好，使用错误处理
    local Online_Gift = nil
    local success, err = pcall(function()
        local currentGUI = game:GetService("Players").LocalPlayer.PlayerGui.GUI
        Online_Gift = currentGUI["\228\186\140\231\186\167\231\149\140\233\157\162"]["\232\138\130\230\151\165\230\180\187\229\138\168\229\149\134\229\186\151"]["\232\131\140\230\153\175"]["\229\143\179\228\190\167\231\149\140\233\157\162"]["\229\156\168\231\186\191\229\165\150\229\138\177"]["\229\136\151\232\161\168"]
    end)
    
    if not success or not Online_Gift then
        warn('[初始化警告] 无法加载在线奖励GUI元素，在线奖励功能可能无法使用:', err)
        -- 如果加载失败，返回但不影响其他功能
        return
    end
    
    local Gife_check = false
    local countdownList = {}
    local hasExecutedToday = false
    local lastExecutedDay = os.date('%d')

    local function convertToSeconds(timeText)
        local minutes, seconds = string.match(timeText, '(%d+):(%d+)')
        if minutes and seconds then
            return (tonumber(minutes) * 60) + tonumber(seconds)
        end
        return nil
    end

    local function GetOnlineGiftCountdown()
        hasExecutedToday = true
        local minTime = math.huge
        for i = 1, 6 do
            local rewardName = string.format('在线奖励%02d', i)
            local rewardFolder = Online_Gift:FindFirstChild(rewardName)
            if rewardFolder then
                local button = rewardFolder:FindFirstChild('按钮')
                local countdown = button and button:FindFirstChild('倒计时')
                if countdown then
                    local countdownText = countdown.Text
                    countdownList[rewardName] = countdownText
                    if string.match(countdownText, 'DONE') then
                        minTime = math.min(minTime, 0)
                    elseif string.match(countdownText, '%d+:%d+') then
                        local totalSeconds = convertToSeconds(countdownText)
                        if totalSeconds then
                            minTime = math.min(minTime, totalSeconds)
                        end
                    end
                end
            end
        end
        return (minTime < math.huge) and minTime or nil
    end

    local minCountdown = GetOnlineGiftCountdown()
    local nowminCountdown = minCountdown

    local function Online_Gift_start()
        local newMinCountdown = GetOnlineGiftCountdown()
        if newMinCountdown and (newMinCountdown == minCountdown) then
            nowminCountdown = nowminCountdown - 1
        else
            minCountdown = newMinCountdown
            nowminCountdown = minCountdown
        end
        
        if nowminCountdown and (nowminCountdown > 0) then
            timeLabel.Text = string.format('距離下自動獲取還有 %d 秒', nowminCountdown)
        elseif nowminCountdown and (nowminCountdown <= 0) then
            timeLabel.Text = '倒計時結束，準備獲取獎勳'
            local event = ReplicatedStorage
                :FindFirstChild('\228\186\139\228\187\182')
                :FindFirstChild('\229\133\172\231\148\168')
                :FindFirstChild('\232\138\130\230\151\165\230\180\187\229\138\168')
                :FindFirstChild('\233\162\134\229\143\150\229\165\150\229\138\177')
            
            for i = 1, 6 do
                event:FireServer(i)
            end
        else
            timeLabel.Text = '已全部領取'
            Gife_check = false
        end
    end

    local function Online_Gift_check()
        while Gife_check do
            Online_Gift_start()
            task.wait(1)
        end
    end

    local function ClaimOnlineRewards()
        Gife_check = true
        task.spawn(Online_Gift_check)
    end

    features1:AddButton('自動領取在線獎勳', ClaimOnlineRewards)
    task.defer(ClaimOnlineRewards)

    local function CheckAllRewardsCompleted()
        local allCompleted = true
        GetOnlineGiftCountdown()
        for i = 1, 6 do
            local rewardName = string.format('在线奖励%02d', i)
            local status = countdownList[rewardName]
            if not status or not string.match(status, 'DONE') then
                allCompleted = false
                break
            end
        end
        if allCompleted then
            print('所有在線獎勳已完成！')
            Gife_check = false
        end
    end

    task.spawn(function()
        while Gife_check and not hasExecutedToday do
            CheckAllRewardsCompleted()
            task.wait(60)
        end
    end)

    task.spawn(function()
        while true do
            local currentUTCHour = tonumber(os.date('!*t').hour)
            local currentUTCDate = os.date('!*t').day
            local currentLocalHour = currentUTCHour + 8
            if currentLocalHour >= 24 then
                currentLocalHour = currentLocalHour - 24
            end
            local currentLocalDate = currentUTCDate
            if currentLocalHour == 0 then
                if lastExecutedDay ~= currentLocalDate then
                    hasExecutedToday = false
                    print('UTC+8 00:00，自動領取在線獎勳')
                    Gife_check = true
                    lastExecutedDay = currentLocalDate
                end
            end
            task.wait(60)
        end
    end)

    -- 自动任务领取
    local Autocollmission = features1:AddSwitch(
        '自動任務領取(包括GamePass任務、獎勵)',
        function(bool)
            Autocollmissionbool = bool
            if Autocollmissionbool then
                task.spawn(function()
                    while Autocollmissionbool do
                        mainmissionchack()
                        everydaymission()
                        gamepassmission()
                        gamepassgiftget()
                        potionfull()
                        offlinereward()
                        task.wait(20)
                    end
                end)

                task.spawn(function()
                    while Autocollmissionbool do
                        dailyspin()
                        everydaygem()
                        task.wait(500)
                    end
                end)
            end
        end
    )
    Autocollmission:Set(true)

    -- 自动投资
    local invest = features1:AddSwitch('自動執行投資', function(bool)
        investbool = bool
        if investbool then
            task.spawn(function()
                while investbool do
                    local investEvent = ReplicatedStorage['\228\186\139\228\187\182']['\229\133\172\231\148\168']['\229\149\134\229\186\151']['\233\147\182\232\161\140']['\233\162\134\229\143\150\231\144\134\232\180\162']
                    local upgradeEvent = ReplicatedStorage['\228\186\139\228\187\182']['\229\133\172\231\148\168']['\229\149\134\229\186\151']['\233\147\182\232\161\140']['\232\180\173\228\185\176\231\144\134\232\180\162']
                    
                    for i = 1, 3 do
                        investEvent:FireServer(i)
                    end
                    task.wait(5)
                    for i = 1, 3 do
                        upgradeEvent:FireServer(i)
                    end
                    task.wait(600)
                end
            end)
        end
    end)
    invest:Set(true)

    -- 农田5相关函数
    local function openFarm5()
        pcall(function()
            ReplicatedStorage['\228\186\139\228\187\182']['\229\134\156\231\148\176']['\229\134\156\231\148\176UI']['\229\177\158\230\128\167\229\140\186\229\159\159']:FireServer(5)
        end)
        task.wait(0.5)
    end

    local function readFarm5Number()
        local root = player:WaitForChild('PlayerGui'):WaitForChild('GUI')
        local label = deepWait(root, {
            '\228\186\140\231\186\167\231\149\140\233\157\162',
            '\229\134\156\231\148\176',
            '\232\131\140\230\153\175',
            '\229\177\158\230\128\167\229\140\186\229\159\159',
            '\230\148\182\233\155\134\230\140\137\233\146\174',
            '\230\149\176\233\135\143\229\140\186',
            '\230\149\176\233\135\143',
        }, 5)

        if not label or not label:IsA('TextLabel') then
            return nil
        end
        return tonumber(label.Text) or 0
    end

    local function waitFarm5Below100(maxMinutes)
        local deadline = os.clock() + (maxMinutes or 10) * 60
        while os.clock() < deadline do
            local n = readFarm5Number()
            if n == nil then
                warn('[农田5] 读取数字失败，3秒后重试')
                task.wait(3)
            elseif n < 100 then
                farmReady = true
                print('[农田5] 数值 < 100，标记 farmReady = true')
                checkAllTasksFinished()
                return true
            else
                task.wait(3)
            end
        end
        warn('[农田5] 等待超时（超过上限仍 >=100）')
        return false
    end

    -- 自动采集草药
    local AutoCollectherbs = features1:AddSwitch(
        '自動採草藥',
        function(bool)
            AutoCollectherbsbool = bool
            if AutoCollectherbsbool then
                task.spawn(function()
                    while AutoCollectherbsbool do
                        local collectEvent = ReplicatedStorage['\228\186\139\228\187\182']['\229\133\172\231\148\168']['\229\134\156\231\148\176']['\233\135\135\233\155\134']
                        for i = 1, 6 do
                            collectEvent:FireServer(i, nil)
                            task.wait(0.1)
                        end

                        herbCollectFinished = true
                        print('[系统] 草药收集一轮完成，检查农田 5 状态…')
                        openFarm5()
                        waitFarm5Below100()
                        task.wait(60)
                    end
                end)
            end
        end
    )
    AutoCollectherbs:Set(true)

    -- 解锁自动炼制
    features1:AddLabel(' - - 通行證解鎖')
    local Refining = features1:AddSwitch(
        '解鎖自動煉製',
        function(bool)
            local Refiningbool = bool
            if privileges then
                pcall(function()
                    privileges:WaitForChild('超级炼制', 5).Value = false
                    privileges:WaitForChild('自动炼制', 5).Value = Refiningbool
                end)
            else
                warn('[警告] 特权对象未加载，无法设置自动炼制')
            end
        end
    )
    Refining:Set(true)

    -- 显示所有货币
    local showAll = features1:AddSwitch('顯示所有貨幣', function(bool)
        ShowAllbool = bool
        if ShowAllbool then
            task.spawn(function()
                while ShowAllbool do
                    local currencyUI = GUI['\228\184\187\231\149\140\233\157\162']['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159\229\143\179']
                    currencyUI['\230\180\187\229\138\168\231\137\169\229\147\129'].Visible = true
                    currencyUI['\231\159\191\231\159\179'].Visible = false
                    currencyUI['\231\172\166\231\159\179\231\178\137\230\156\171'].Visible = true
                    currencyUI['\231\173\137\231\186\167'].Visible = true
                    currencyUI['\231\180\171\233\146\187'].Visible = true
                    currencyUI['\232\141\137\232\141\175'].Visible = false
                    currencyUI['\233\135\145\229\184\129'].Visible = true
                    currencyUI['\233\146\187\231\159\179'].Visible = true
                    task.wait(0.3)
                end
            end)
        end
    end)
    showAll:Set(false)

    -- 删除奖励UI
    local function RemoveRewardUI()
        local rewardUI = playerGui.GUI:WaitForChild('\228\186\140\231\186\167\231\149\140\233\157\162')
        local rewardUINames = {
            '展示奖励界面',
            '离线奖励',
            '版本说明',
            '7日奖励',
        }
        local success = false

        for _, name in ipairs(rewardUINames) do
            local child = rewardUI:FindFirstChild(name)
            if child then
                child:Destroy()
                print('成功删除: ' .. name)
                success = true
            else
                print('未找到: ' .. name)
            end
        end

        return success
    end

    features1:AddButton('刪除顯示獲得的獎勵(所有的)', RemoveRewardUI)
    task.defer(RemoveRewardUI)

    -- 兑换游戏礼品码
    features1:AddButton('兌換遊戲禮品碼', function()
        local gamecode = {
            'ilovethisgame',
            'welcome',
            '30klikes',
            '40klikes',
            'halloween',
            'artistkapouki',
            '45klikes',
            '60klikes',
        }
        local redeemEvent = ReplicatedStorage
            :FindFirstChild('\228\186\139\228\187\182')
            :FindFirstChild('\229\133\172\231\148\168')
            :FindFirstChild('\231\142\169\229\174\182\231\160\129')
            :FindFirstChild('\231\142\169\229\174\182\229\133\145\230\141\162\231\142\169\229\174\182\231\160\129')
        
        for i = 1, #gamecode do
            print(gamecode[i])
            redeemEvent:FireServer(gamecode[i])
        end
    end)
end

-- 使用错误处理调用setupFeatures1Tab，确保GUI元素已准备好
local success, err = pcall(function()
    setupFeatures1Tab(features1)
end)
if not success then
    warn('[初始化错误] setupFeatures1Tab执行失败:', err)
end

-- ============================================
-- 炼丹标签页设置
-- ============================================
-- 炼丹控制器
local elixirController = {
    enabled = false
}

local function elixirLoop()
    while elixirController.enabled do
        local currentHerbs = getHerbValue()
        if currentHerbs < 5000 then
            if not G_colectherb then
                writeCompletionMarkerOnce()
            end
            print('[系统] 草药数量低于5000，停止自动炼丹')
            elixirController.enabled = false
            AutoelixirSwitch:Set(false)
            break
        end
        
        local elixirEvent = ReplicatedStorage
            :FindFirstChild('\228\186\139\228\187\182')
            :FindFirstChild('\229\133\172\231\148\168')
            :FindFirstChild('\231\130\188\228\184\185')
            :FindFirstChild('\229\136\182\228\189\156')
        
        if elixirEvent then
            elixirEvent:FireServer()
        end
        task.wait(0.5)
    end
end

local AutoelixirSwitch = features4:AddSwitch('自動煉丹藥', function(bool)
    elixirController.enabled = bool
    if elixirController.enabled then
        task.spawn(elixirLoop)
    end
end)

task.defer(function()
    task.wait(3)
    if not elixirController.enabled then
        AutoelixirSwitch:Set(true)
        print('[系统] 自动炼丹已启动')
    end
end)

-- 传送炼器
features4:AddButton('传送炼器', function()
    local RespawPointnum = RespawPoint:match('%d+')
    local character = player.Character

    if not character then
        player.CharacterAdded:Wait()
        character = player.Character
    end

    local humanoidRootPart = character:WaitForChild('HumanoidRootPart')
    local forgePath = Workspace['\228\184\187\229\160\180\230\153\175' .. RespawPointnum]['\229\187\186\233\128\160\231\137\169']['035\231\130\188\229\153\168\229\143\176']

    if forgePath then
        humanoidRootPart.CFrame = forgePath:GetPivot()
    end
end)

-- 公会相关
-- 获取公会名称（使用完整路径，确保使用正确的GUI）
local Guidename = ""
local maxRetries = 5
local retryDelay = 1.5
for attempt = 1, maxRetries do
    local success, result = pcall(function()
        -- 使用完整路径获取，每次都重新获取GUI
        local currentGUI = game:GetService("Players").LocalPlayer.PlayerGui.GUI
        return currentGUI["\228\186\140\231\186\167\231\149\140\233\157\162"]["\229\133\172\228\188\154"]["\232\131\140\230\153\175"]["\229\143\179\228\190\167\231\149\140\233\157\162"]["\228\184\187\233\161\181"]["\228\187\139\231\187\141"]["\229\144\141\231\167\176"]["\230\150\135\230\156\172"]["\230\150\135\230\156\172"].Text
    end)
    if success and result then
        Guidename = result
        -- 更新全局GUI变量
        GUI = game:GetService("Players").LocalPlayer.PlayerGui.GUI
        break
    else
        if attempt < maxRetries then
            task.wait(retryDelay)
        else
            warn('[初始化] 获取公会名称失败，使用默认值')
            Guidename = "未获取"
        end
    end
end

-- 使用完整路径获取，确保使用正确的GUI
local currentGUI = game:GetService("Players").LocalPlayer.PlayerGui.GUI
local Donatetimes = currentGUI
    :WaitForChild('\228\186\140\231\186\167\231\149\140\233\157\162')
    :WaitForChild('\229\133\172\228\188\154')
    :WaitForChild('捐献')
    :WaitForChild('背景')
    :WaitForChild('按钮')
    :WaitForChild('确定按钮')
    :WaitForChild('次数').Text

local Donatetimesnumber = tonumber(string.match(Donatetimes, '%d+'))
local Guildname = features4:AddLabel(
    '公會名稱：未獲取點擊更新公會 剩餘貢獻次數： ' .. Donatetimesnumber
)

features4:AddButton('更新公會', function()
    local currentGUI = game:GetService("Players").LocalPlayer.PlayerGui.GUI
    Donatetimes = currentGUI
        :WaitForChild('\228\186\140\231\186\167\231\149\140\233\157\162')
        :WaitForChild('\229\133\172\228\188\154')
        :WaitForChild('捐献')
        :WaitForChild('背景')
        :WaitForChild('按钮')
        :WaitForChild('确定按钮')
        :WaitForChild('次数').Text
    Donatetimesnumber = tonumber(string.match(Donatetimes, '%d+'))
    local event = ReplicatedStorage:FindFirstChild('打开公会', true)
    if event then
        event:Fire('打开公会')
    end
    Guildname.Text = '公會名稱：' .. Guidename .. ' 剩餘貢獻次數： ' .. Donatetimesnumber
end)

local currentGUI = game:GetService("Players").LocalPlayer.PlayerGui.GUI
local DonationUI = currentGUI:WaitForChild('\228\186\140\231\186\167\231\149\140\233\157\162'):WaitForChild('\229\133\172\228\188\154')
local DonateButton = DonationUI:WaitForChild('捐献')
    :WaitForChild('背景')
    :WaitForChild('按钮')
    :WaitForChild('确定按钮')

local DonationEvent = ReplicatedStorage
    :WaitForChild('\228\186\139\228\187\182')
    :WaitForChild('\229\133\172\231\148\168')
    :WaitForChild('\229\133\172\228\188\154')
    :WaitForChild('\230\141\144\231\140\174')

-- 捐献控制器
local donationController = {
    enabled = false,
    interval = 0.5,
    maxAttempts = 3,
    currentAttempts = 0,
}

local function updateGuildDisplay()
    local counterText = DonateButton:WaitForChild('次数').Text
    local remaining = tonumber(counterText:match('%d+')) or 0
    Guildname.Text = ('公會名稱：%s 剩餘貢獻次數：%d'):format(Guidename, remaining)
    return remaining
end

local function executeDonation()
    pcall(function()
        DonationEvent:FireServer()
    end)
end

local function donationLoop()
    while donationController.enabled do
        local success, remaining = pcall(updateGuildDisplay)

        if success and remaining > 0 then
            executeDonation()
            donationController.currentAttempts = 0
        else
            donationController.currentAttempts += 1
        end

        if donationController.currentAttempts >= donationController.maxAttempts then
            warn('连续失败次数过多，自动停止')
            donationController.enabled = false
        end

        if success and remaining == 0 then
            donationController.enabled = false
            donationFinished = true
            checkAllTasksFinished()
            print('[系统] 公会捐献已完成，准备购买草药')
        end

        task.wait(donationController.interval)
    end
end

local AutoDonateSwitch = features4:AddSwitch('自動捐献', function(isActive)
    donationController.enabled = isActive
    if isActive then
        task.spawn(donationLoop)
    end
end)

task.defer(function()
    task.wait(3)
    if not donationController.enabled then
        AutoDonateSwitch:Set(true)
    end
end)

-- 草药购买控制器
local herbController = {
    enabled = false,
    interval = 0.2,
    maxAttempts = 5,
    currentAttempts = 0,
    highCostMode = false,
}

local function toggleGuildUI(state)
    pcall(function()
        local currentGUI = game:GetService("Players").LocalPlayer.PlayerGui.GUI
        currentGUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154'].Visible = state
    end)
end

local price = 400

local function herbLoop()
    while herbController.enabled do
        if not donationFinished then
            task.wait(1)
        else
            if not herbController.started then
                herbController.started = true
            end

            local money = getDiamond()
            local currentGUI = game:GetService("Players").LocalPlayer.PlayerGui.GUI
            local guilditemlist = currentGUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\133\172\228\188\154']['\232\131\140\230\153\175']['\229\143\179\228\190\167\231\149\140\233\157\162']['\229\149\134\229\186\151']['\229\136\151\232\161\168']


            local function tryBuy(slotIndex)
                local item = guilditemlist:GetChildren()[slotIndex]
                if item and item:FindFirstChild('\230\140\137\233\146\174') then
                    local button = item['\230\140\137\233\146\174']
                    local stockText = button['\229\186\147\229\173\152'].Text
                    local nameText = button['\229\144\141\231\167\176'].Text
                    
                    if stockText == '1 Left' and nameText == 'Herb' then
                        if money >= price then
                            ReplicatedStorage['\228\186\139\228\187\182']['\229\133\172\231\148\168']['\229\133\172\228\188\154']['\229\133\145\230\141\162']:FireServer(slotIndex - 2)
                            money = money - price
                            return true
                        end
                    end
                end
                return false
            end

            for i = 1, 18 do
                if not herbController.enabled then
                    break
                end
                tryBuy(i)
            end

            local refreshCost = getRefreshCost()
            local diamond = getDiamond()
            local guildCoin = getGuildCoin()

            if refreshCost > 7000 then
                if not herbController.highCostMode then
                    print('[系统] 进入高成本模式，结束草药购买任务')
                    herbController.highCostMode = true
                    if not herbBuyFinished then
                        task.wait(5)
                        herbBuyFinished = true
                        checkAllTasksFinished()
                    end
                    herbController.enabled = false
                end
                toggleGuildUI(false)
                task.wait(300)
                break
            else
                herbController.highCostMode = false
            end

            if diamond > refreshCost and guildCoin >= 400 and diamond >= 18000 then
                pcall(function()
                    ReplicatedStorage['\228\186\139\228\187\182']['\229\174\162\230\136\183\231\171\175']['\229\174\162\230\136\183\231\171\175UI']['\230\137\147\229\188\128\229\133\172\228\188\154']:Fire()
                    task.wait(0.5)
                    ReplicatedStorage['\228\186\139\228\187\182']['\229\133\172\231\148\168']['\229\133\172\228\188\154']['\229\136\183\230\150\176\229\133\172\228\188\154\229\149\134\229\186\151']:FireServer()
                end)
                task.wait(1.5)
            else
                if not herbBuyFinished then
                    task.wait(5)
                    herbBuyFinished = true
                    checkAllTasksFinished()
                end
                herbController.enabled = false
                task.wait(30)
            end
        end
    end
end

local Autoguildshop = features4:AddSwitch('自动购买草药', function(state)
    herbController.enabled = state
    herbController.highCostMode = false
    if state then
        task.spawn(herbLoop)
    end
end)

task.defer(function()
    task.wait(3)
    if not herbController.enabled then
        Autoguildshop:Set(true)
    end
end)

-- 简易丹药摆放
features4:AddButton('简易丹药摆放', function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/supleruckydior/test/refs/heads/main/简易自动交易.lua"))()
end)

-- 交易所有人
features4:AddButton('交易所有人', function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/supleruckydior/test/refs/heads/main/自动交易1.json"))()
end)

-- ============================================
-- 智能监控系统
-- ============================================
local Autoelixir = false
local hasExecutedTrade = false

local function startElixirLoop()
    Autoelixir = true
    while Autoelixir do
        pcall(function()
            local elixirEvent = ReplicatedStorage
                :FindFirstChild('\228\186\139\228\187\182')
                :FindFirstChild('\229\133\172\231\148\168')
                :FindFirstChild('\231\130\188\228\184\185')
                :FindFirstChild('\229\136\182\228\189\156')
            if elixirEvent then
                elixirEvent:FireServer()
            end
        end)
        task.wait(0.2)
    end
end

local herbprint = false
local lowcontrol = false

local function smartMonitor()
    while true do
        local currentHerbs = getHerbValue()
        local playerName = player.Name

        if currentHerbs > 250000 and not hasExecutedTrade then
            herbprint = true
            lowcontrol = true
            hasExecutedTrade = true
            print(playerName .. ' --- 自动交易脚本激活! (' .. currentHerbs .. '草药)')

            if not Autoelixir then
                task.spawn(startElixirLoop)
            end
        elseif currentHerbs < 5000 and lowcontrol then
            if not G_colectherb then
                writeCompletionMarkerOnce()
            end
            Autoelixir = false
            hasExecutedTrade = false
            herbprint = false
            lowcontrol = false
            print(playerName .. ' --- 系统重置! (剩余' .. currentHerbs .. '草药)')
        end
        
        if herbprint and hasExecutedTrade then
            print(playerName .. ' --- ' .. currentHerbs .. '草药')
        end

        task.wait(5)
    end
end

-- 初始化检查
local farm5Level = 0
local elixirLevel = 0

pcall(function()
    local currentGUI = game:GetService("Players").LocalPlayer.PlayerGui.GUI
    farm5Level = tonumber(
        currentGUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\134\156\231\148\176']['\232\131\140\230\153\175']['\229\177\158\230\128\167\229\140\186\229\159\159']['\229\177\158\230\128\167\229\136\151\232\161\168']['\229\136\151\232\161\168']['\231\173\137\231\186\167']['\229\128\188'].Text:match('%d+')
    ) or 0
    currentGUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\229\134\156\231\148\176'].Visible = false
end)

pcall(function()
    local elixirUI = ReplicatedStorage:FindFirstChild('\228\186\139\228\187\182', true):FindFirstChild('\229\174\162\230\136\183\231\171\175', true)
    if elixirUI then
        elixirUI['\229\174\162\230\136\183\231\171\175UI']['\230\137\147\229\188\128\231\130\188\228\184\185\231\130\137']:Fire()
        task.wait(0.5)
        local currentGUI = game:GetService("Players").LocalPlayer.PlayerGui.GUI
        elixirLevel = tonumber(
            currentGUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\231\130\188\228\184\185\231\130\137']['\232\131\140\230\153\175']['\229\177\158\230\128\167\229\136\151\232\161\168']['\229\136\151\232\161\168']['\231\173\137\231\186\167']['\229\128\188'].Text:match('%d+')
        ) or 0
        currentGUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\231\130\188\228\184\185\231\130\137'].Visible = false
    end
end)

if farm5Level >= 80 and elixirLevel >= 80 then
    print('===== 系统启动 =====')
    print('农田5等级:', farm5Level)
    print('炼丹炉等级:', elixirLevel)
    print('初始草药量:', getHerbValue())
    print('==================')
    task.spawn(smartMonitor)
else
    print('条件不满足：需要农田5和炼丹炉等级≥80')
end

-- ============================================
-- 自动出售检查
-- ============================================
local function CheckAndFire()
    local currentGUI = game:GetService("Players").LocalPlayer.PlayerGui.GUI
    local gui = currentGUI['\228\186\140\231\186\167\231\149\140\233\157\162']['\232\135\170\229\138\168\229\135\186\229\148\174\229\188\185\229\135\186\230\161\134']['\232\131\140\230\153\175']['\230\140\137\233\146\174']['\230\147\141\228\189\156\229\140\186\229\159\159']['\229\130\168\229\173\152']['\229\155\190\230\160\135']['\229\155\190\230\160\135']
    
    if gui and gui.Visible == false then
        local remote = ReplicatedStorage
            :WaitForChild('\228\186\139\228\187\182')
            :WaitForChild('\229\133\172\231\148\168')
            :WaitForChild('\231\130\188\228\184\185')
            :WaitForChild('\228\191\174\230\148\185\232\135\170\229\138\168\229\130\168\229\173\152')
        
        if remote then
            remote:FireServer()
            print('RemoteEvent fired successfully!')
        else
            warn('RemoteEvent not found!')
        end
    end
end

CheckAndFire()
