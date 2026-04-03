if not game:IsLoaded() then
    game.Loaded:Wait()
end

local TARGET_GAME_ID = 18645473062

if game.PlaceId ~= TARGET_GAME_ID then
    warn('[V2] 当前游戏不匹配，脚本未启动')
    return
end

local Services = {
    Players = game:GetService('Players'),
    ReplicatedStorage = game:GetService('ReplicatedStorage'),
    Workspace = game:GetService('Workspace'),
    HttpService = game:GetService('HttpService'),
    VirtualUser = game:GetService('VirtualUser'),
}

local player = Services.Players.LocalPlayer
while not player:FindFirstChild('PlayerGui') do
    task.wait(1)
end

local playerGui = player.PlayerGui

local Constants = {
    SettingsFile = 'Cultivation_v2_settings.json',
    LegacyWorldSettingsFile = 'WorldSettings.json',
    LegacyDungeonSettingsFile = 'DungeonsMaxLevel.json',
    LegacyLanguageFile = 'Cultivation_languageSet.json',
    DailyOffset = 8 * 3600,
    UILibraryUrl = 'https://raw.githubusercontent.com/supleruckydior/test/refs/heads/main/menu.json',
    RespawnScriptUrl = 'https://raw.githubusercontent.com/Tseting-nil/-Cultivation-Simulator-script/refs/heads/main/%E6%89%8B%E6%A9%9F%E7%AB%AFUI/%E9%85%8D%E7%BD%AE%E4%B8%BB%E5%A0%B4%E6%99%AF.lua',
    TradeScriptUrls = {
        'https://github.com/supleruckydior/test/raw/refs/heads/main/%E8%87%AA%E5%8A%A8%E4%BA%A4%E6%98%931.json',
        'https://github.com/supleruckydior/test/raw/refs/heads/main/%E8%87%AA%E5%8A%A8%E4%BA%A4%E6%98%932.json',
    },
    StatsScriptUrl = 'https://github.com/supleruckydior/test/raw/refs/heads/main/%E9%87%91%E5%B8%81.json',
    GithubUrl = 'https://github.com/Tseting-nil',
    GiftCodes = {
        'ilovethisgame',
        'welcome',
        '30klikes',
        '40klikes',
        'halloween',
        'artistkapouki',
        '45klikes',
        '60klikes',
    },
    Paths = {
        EventsRoot = '\228\186\139\228\187\182',
        Common = '\229\133\172\231\148\168',
        MainGui = '\228\184\187\231\149\140\233\157\162',
        SecondaryGui = '\228\186\140\231\186\167\231\149\140\233\157\162',
        LoadingGui = '\229\138\160\232\189\189\233\161\181\233\157\162',
        Farm = '\229\134\156\231\148\176',
        FarmUi = '\229\134\156\231\148\176UI',
        Elixir = '\231\130\188\228\184\185',
        ElixirGui = '\231\130\188\228\184\185\231\130\137',
        Guild = '\229\133\172\228\188\154',
        Dungeon = '\229\137\175\230\156\172',
        Shop = '\229\149\134\229\186\151',
        Stage = '\229\133\179\229\141\161',
        Activity = '\232\138\130\230\151\165\230\180\187\229\138\168',
        FlyingSword = '\233\163\158\229\137\145',
        Weapon = '\230\179\149\229\174\157',
        Skill = '\230\138\128\232\131\189',
        Rune = '\233\152\181\230\179\149',
        Settings = '\232\174\190\231\189\174',
        Combat = '\230\136\152\230\150\151',
        Forge = '\229\187\186\231\173\145',
        WorldTree = '\228\184\150\231\149\140\230\160\145',
        AttributeArea = '\229\177\158\230\128\167\229\140\186\229\159\159',
        Client = '\229\174\162\230\136\183\231\171\175',
        ClientUi = '\229\174\162\230\136\183\231\171\175UI',
        ClaimReward = '\233\162\134\229\143\150\229\165\150\229\138\177',
        Donate = '\230\141\144\231\140\174',
        Exchange = '\229\133\145\230\141\162',
        RefreshGuildShop = '\229\136\183\230\150\176\229\133\172\228\188\154\229\149\134\229\186\151',
        Collect = '\233\135\135\233\155\134',
        Craft = '\229\136\182\228\189\156',
        Upgrade = '\229\141\135\231\186\167',
        UpgradeAllWeapon = '\229\141\135\231\186\167\229\133\168\233\131\168\230\179\149\229\174\157',
        UpgradeAllSkill = '\229\141\135\231\186\167\229\133\168\233\131\168\230\138\128\232\131\189',
        Unequip = '\229\141\184\228\184\139',
        UnlockBuilding = '\232\167\163\233\148\129\229\187\186\231\173\145',
        OpenGuildFromClient = '\230\137\147\229\188\128\229\133\172\228\188\154',
        OpenElixirFromClient = '\230\137\147\229\188\128\231\130\188\228\184\185\231\130\137',
        Values = '\229\128\188',
        Currency = '\232\180\167\229\184\129',
        Privileges = '\231\137\185\230\157\131',
        MainProgress = '\228\184\187\231\186\191\232\191\155\229\186\166',
        SettingsValue = '\232\174\190\231\189\174',
        AutoBattle = '\232\135\170\229\138\168\230\136\152\230\150\151',
        MainCity = '\228\184\187\229\159\142',
        CurrencyArea = '\232\180\167\229\184\129\229\140\186\229\159\159',
        CurrencyAreaRight = '\232\180\167\229\184\129\229\140\186\229\159\159\229\143\179',
        RespawnPoint = '\233\135\141\231\148\159\231\130\185',
        EnterWorld = '\232\191\155\229\133\165\228\184\150\231\149\140\229\133\179\229\141\161',
        EnterDungeon = '\232\191\155\229\133\165\229\137\175\230\156\172',
        EnterOpenBattle = '\232\191\155\229\133\165\229\188\128\229\144\175\228\184\173\229\133\179\229\141\161',
        UpdateAssistTarget = '\230\155\180\230\150\176\229\141\143\229\138\169\231\155\174\230\160\135',
        ModifyPlayerSettings = '\231\142\169\229\174\182\228\191\174\230\148\185\232\174\190\231\189\174',
        Bank = '\233\147\182\232\161\140',
        ClaimInvestment = '\233\162\134\229\143\150\231\144\134\232\180\162',
        BuyInvestment = '\232\180\173\228\185\176\231\144\134\232\180\162',
        Summon = '\229\143\172\229\148\164',
        Lottery = '\230\138\189\229\165\150',
        Arena = '\231\171\158\230\138\128\229\156\186',
        Buy = '\232\180\173\228\185\176',
        AutoRefineSuper = '\232\182\133\231\186\167\231\130\188\229\136\182',
        AutoRefine = '\232\135\170\229\138\168\231\130\188\229\136\182',
    },
}

local Utils = {}

function Utils.safePcall(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        warn('[V2]', result)
    end
    return ok, result
end

function Utils.parseNumber(text)
    local str = tostring(text):lower():gsub('%s+', ''):gsub(',', '')
    local numStr = str:gsub('[^%d%.]', '')
    if select(2, numStr:gsub('%.', '')) > 1 then
        return 0
    end

    local multiplier = 1
    if str:find('k') then
        multiplier = 1000
    elseif str:find('m') then
        multiplier = 1000000
    end

    return (tonumber(numStr) or 0) * multiplier
end

function Utils.cloneTable(value)
    if type(value) ~= 'table' then
        return value
    end

    local clone = {}
    for key, item in pairs(value) do
        clone[key] = Utils.cloneTable(item)
    end
    return clone
end

function Utils.mergeDefaults(defaults, incoming)
    local merged = Utils.cloneTable(defaults)
    if type(incoming) ~= 'table' then
        return merged
    end

    for key, value in pairs(incoming) do
        if type(merged[key]) == 'table' and type(value) == 'table' then
            merged[key] = Utils.mergeDefaults(merged[key], value)
        elseif merged[key] ~= nil then
            merged[key] = value
        end
    end

    return merged
end

function Utils.deepWait(parent, path, timeout)
    local current = parent
    for _, name in ipairs(path) do
        current = current and current:WaitForChild(name, timeout or 5)
        if not current then
            return nil
        end
    end
    return current
end

function Utils.deepFind(parent, path)
    local current = parent
    for _, name in ipairs(path) do
        current = current and current:FindFirstChild(name)
        if not current then
            return nil
        end
    end
    return current
end

function Utils.getUtc8DateKey(timestamp)
    local utc8 = os.date('!*t', (timestamp or os.time()) + Constants.DailyOffset)
    return string.format('%04d-%02d-%02d', utc8.year, utc8.month, utc8.day)
end

function Utils.showTopRightNotice(text, lifetime)
    local pg = player:WaitForChild('PlayerGui')
    local gui = pg:FindFirstChild('FarmNoticeGui') or Instance.new('ScreenGui')
    gui.Name = 'FarmNoticeGui'
    gui.ResetOnSpawn = false
    gui.Parent = pg

    local label = gui:FindFirstChild('Notice') or Instance.new('TextLabel')
    label.Name = 'Notice'
    label.AnchorPoint = Vector2.new(1, 0)
    label.Position = UDim2.new(1, -20, 0, 20)
    label.Size = UDim2.new(0, 320, 0, 38)
    label.BackgroundTransparency = 0.25
    label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    label.TextColor3 = Color3.fromRGB(255, 90, 90)
    label.TextScaled = true
    label.TextWrapped = true
    label.Font = Enum.Font.SourceSansSemibold
    label.Text = text
    label.Parent = gui

    task.delay(lifetime or 3, function()
        if label then
            label:Destroy()
        end
        if gui and #gui:GetChildren() == 0 then
            gui:Destroy()
        end
    end)
end

function Utils.waitForLoadingGui()
    local maxAttempts = 30
    for _ = 1, maxAttempts do
        local ok, gui = pcall(function()
            return playerGui.GUI[Constants.Paths.SecondaryGui]['\229\138\160\232\189\189\233\161\181\233\157\162']
        end)
        if ok and gui then
            if not gui.Visible then
                return
            end
            while gui.Parent and gui.Visible do
                gui:GetPropertyChangedSignal('Visible'):Wait()
                task.wait(0.1)
            end
            return
        end
        task.wait(0.5)
    end
end

function Utils.tryReadFile(path)
    if type(isfile) ~= 'function' or not isfile(path) then
        return nil
    end

    local ok, content = pcall(readfile, path)
    if not ok then
        return nil
    end

    return content
end

function Utils.tryWriteFile(path, content)
    if type(writefile) ~= 'function' then
        return false
    end

    local ok = pcall(writefile, path, content)
    return ok
end

function Utils.tryDeleteFile(path)
    if type(delfile) ~= 'function' or type(isfile) ~= 'function' then
        return false
    end
    if not isfile(path) then
        return false
    end
    return pcall(delfile, path)
end

function Utils.readJsonFile(path)
    local content = Utils.tryReadFile(path)
    if not content or content == '' then
        return nil
    end

    local ok, data = pcall(
        Services.HttpService.JSONDecode,
        Services.HttpService,
        content
    )

    if not ok or type(data) ~= 'table' then
        return nil
    end

    return data
end

function Utils.writeJsonFile(path, data)
    local ok, payload = pcall(
        Services.HttpService.JSONEncode,
        Services.HttpService,
        data
    )

    if not ok then
        return false
    end

    return Utils.tryWriteFile(path, payload)
end

function Utils.findSceneRoot(sceneNumber)
    local candidates = {
        '主场景' .. tostring(sceneNumber),
        '主場景' .. tostring(sceneNumber),
    }

    for _, candidate in ipairs(candidates) do
        local node = Services.Workspace:FindFirstChild(candidate)
        if node then
            return node
        end
    end

    return nil
end

function Utils.getGlobalFunction(name)
    local env = (type(getgenv) == 'function' and getgenv()) or _G
    if type(env) == 'table' and type(env[name]) == 'function' then
        return env[name]
    end
    if type(_G) == 'table' and type(_G[name]) == 'function' then
        return _G[name]
    end
    return nil
end

function Utils.callGlobalFunction(name)
    local fn = Utils.getGlobalFunction(name)
    if type(fn) ~= 'function' then
        return false, 'missing'
    end

    local ok, result = pcall(fn)
    if not ok then
        warn(('[Legacy:%s] %s'):format(name, tostring(result)))
    end
    return ok, result
end

local Scheduler = {
    jobs = {},
}

function Scheduler:stop(name)
    local job = self.jobs[name]
    if not job then
        return
    end

    job.enabled = false
    if job.thread then
        pcall(task.cancel, job.thread)
    end
    self.jobs[name] = nil
end

function Scheduler:start(name, runner)
    self:stop(name)

    local job = { enabled = true }
    self.jobs[name] = job
    job.thread = task.spawn(function()
        local ok, err = pcall(runner, job)
        if not ok then
            warn(('[Scheduler:%s] %s'):format(name, tostring(err)))
        end
        if self.jobs[name] == job then
            self.jobs[name] = nil
        end
    end)

    return job
end

function Scheduler:ensure(name, runner)
    if self.jobs[name] then
        return self.jobs[name]
    end
    return self:start(name, runner)
end

local SettingsStore = {}

local defaultSettings = {
    autoAntiAfk = true,
    safetyMode = true,
    blackScreen = false,
    autoOnlineRewards = true,
    autoLegacyDaily = true,
    autoInvest = true,
    autoDonate = true,
    autoGuildShop = true,
    autoCollectHerbs = true,
    autoRefinePrivilege = true,
    autoShowAllCurrency = false,
    autoRemoveRewardUi = true,
    autoElixirCraft = false,
    autoLottery = false,
    useDiamondsForLottery = false,
    autoUpgradeFlyingSword = false,
    autoUpgradeWeaponSkill = false,
    autoUpgradeRune = false,
    world = {
        level = 78,
        mode = 'manual',
        autoStart = false,
        autoReenter75 = false,
    },
    dungeon = {
        selected = 'OreDungeon',
        selectedId = 1,
        autoSyncUi = false,
        autoStart = false,
        autoPlusOne = false,
        autoFinishAll = false,
        levels = {
            OreDungeon = 1,
            GemDungeon = 1,
            RuneDungeon = 1,
            RelicDungeon = 1,
            HoverDungeon = 1,
            GoldDungeon = 1,
        },
    },
    batch = {
        selectedFarm = 1,
        farmTarget = 80,
        selectedElixir = 1,
        elixirTarget = 80,
    },
    follow = {
        selectedPlayer = '',
        enabled = false,
    },
    monitor = {
        enabled = false,
        highHerbThreshold = 250000,
        lowHerbThreshold = 5000,
        autoTradeOnHighHerb = true,
        autoElixirOnHighHerb = true,
        webhookEnabled = false,
        webhookUrl = '',
    },
}

function SettingsStore:migrateLegacy(settings)
    local migrated = Utils.cloneTable(settings)

    local worldData = Utils.readJsonFile(Constants.LegacyWorldSettingsFile)
    if type(worldData) == 'table' and type(worldData[player.Name]) == 'table' then
        local playerWorld = worldData[player.Name]
        migrated.world.level = math.max(
            1,
            math.floor(tonumber(playerWorld.worldLevel) or migrated.world.level)
        )
        migrated.world.mode = playerWorld.worldMode == 'auto_highest'
            and 'auto_highest'
            or migrated.world.mode
        migrated.world.autoStart = playerWorld.worldAutoStart == true
            or migrated.world.autoStart
    end

    local dungeonData = Utils.readJsonFile(Constants.LegacyDungeonSettingsFile)
    if type(dungeonData) == 'table' and type(dungeonData[player.Name]) == 'table' then
        local playerDungeon = dungeonData[player.Name]
        local mapping = {
            OreDungeonMaxLevel = 'OreDungeon',
            GemDungeonMaxLevel = 'GemDungeon',
            RuneDungeonMaxLevel = 'RuneDungeon',
            RelicDungeonMaxLevel = 'RelicDungeon',
            HoverDungeonMaxLevel = 'HoverDungeon',
            GoldDungeonMaxLevel = 'GoldDungeon',
        }

        for legacyKey, levelKey in pairs(mapping) do
            local level = tonumber(playerDungeon[legacyKey])
            if level and level > 0 then
                migrated.dungeon.levels[levelKey] = math.floor(level)
            end
        end
    end

    return migrated
end

function SettingsStore:load()
    local loaded = Utils.readJsonFile(Constants.SettingsFile)
    local settings = Utils.mergeDefaults(defaultSettings, loaded)
    return self:migrateLegacy(settings)
end

function SettingsStore:save(settings)
    return Utils.writeJsonFile(Constants.SettingsFile, settings)
end

local State = {
    settings = SettingsStore:load(),
    daily = {
        currentDateKey = Utils.getUtc8DateKey(),
        donationFinished = false,
        herbBuyFinished = false,
        herbCollectFinished = false,
        farmReady = false,
        completionAnnounced = false,
    },
    rewards = {
        countdown = nil,
    },
    safety = {
        nearbyPlayers = 0,
        paused = false,
    },
    world = {
        unlocked = 0,
    },
    dungeon = {
        keyCounts = {},
    },
    lottery = {
        diamonds = 0,
        swordTickets = 0,
        skillTickets = 0,
    },
    monitor = {
        tradeTriggered = false,
        lastHerbValue = 0,
        lastOreValue = 0,
    },
    upgrade = {
        farmCurrentLevel = 0,
        elixirCurrentLevel = 0,
    },
    currency = {
        visibilityCache = {},
    },
    ui = {},
}

local PathRegistry = {}

function PathRegistry:init()
    local paths = Constants.Paths
    local eventsRoot = Services.ReplicatedStorage
        :WaitForChild(paths.EventsRoot)
        :WaitForChild(paths.Common)

    local gui = playerGui:WaitForChild('GUI')

    self.EventsRoot = Services.ReplicatedStorage:WaitForChild(paths.EventsRoot)
    self.Events = {
        Farm = eventsRoot:WaitForChild(paths.Farm),
        Elixir = eventsRoot:WaitForChild(paths.Elixir),
        Guild = eventsRoot:WaitForChild(paths.Guild),
        Dungeon = eventsRoot:WaitForChild(paths.Dungeon),
        Shop = eventsRoot:WaitForChild(paths.Shop),
        Stage = eventsRoot:WaitForChild(paths.Stage),
        Activity = eventsRoot:WaitForChild(paths.Activity),
        FlyingSword = eventsRoot:WaitForChild(paths.FlyingSword),
        Weapon = eventsRoot:WaitForChild(paths.Weapon),
        Skill = eventsRoot:WaitForChild(paths.Skill),
        Rune = eventsRoot:WaitForChild(paths.Rune),
        Settings = eventsRoot:WaitForChild(paths.Settings),
        Combat = eventsRoot:WaitForChild(paths.Combat),
        Forge = eventsRoot:WaitForChild(paths.Forge),
        WorldTree = eventsRoot:WaitForChild(paths.WorldTree),
    }
    self.GUI = {
        Root = gui,
        Main = gui:WaitForChild(paths.MainGui),
        Secondary = gui:WaitForChild(paths.SecondaryGui),
    }
    self.Values = player:WaitForChild(paths.Values)
    self.Currency = self.Values:WaitForChild(paths.Currency)
    self.Privileges = self.Values:WaitForChild(paths.Privileges)
    self.Settings = self.Values:WaitForChild(paths.SettingsValue)
    self.Progress = self.Values:WaitForChild(paths.MainProgress)
    self.Remotes = {
        ClaimOnlineReward = self.Events.Activity:FindFirstChild(paths.ClaimReward),
        GuildDonate = self.Events.Guild:FindFirstChild(paths.Donate),
        GuildExchange = self.Events.Guild:FindFirstChild(paths.Exchange),
        GuildRefresh = self.Events.Guild:FindFirstChild(paths.RefreshGuildShop),
        FarmCollect = self.Events.Farm:FindFirstChild(paths.Collect),
        FarmUpgrade = self.Events.Farm:FindFirstChild(paths.Upgrade),
        ElixirCraft = self.Events.Elixir:FindFirstChild(paths.Craft),
        ElixirUpgrade = self.Events.Elixir:FindFirstChild(paths.Upgrade),
        WorldEnter = self.Events.Stage:FindFirstChild(paths.EnterWorld),
        DungeonEnter = self.Events.Dungeon:FindFirstChild(paths.EnterDungeon),
        AssistTeleport = self.Events.Stage:FindFirstChild(paths.EnterOpenBattle),
        AssistTarget = self.Events.Combat:FindFirstChild(paths.UpdateAssistTarget),
        InvestClaim = self.Events.Shop:FindFirstChild(paths.Bank)
            and self.Events.Shop[paths.Bank]:FindFirstChild(paths.ClaimInvestment)
            or nil,
        InvestBuy = self.Events.Shop:FindFirstChild(paths.Bank)
            and self.Events.Shop[paths.Bank]:FindFirstChild(paths.BuyInvestment)
            or nil,
        Summon = self.Events.Shop:FindFirstChild(paths.Summon)
            and self.Events.Shop[paths.Summon]:FindFirstChild(paths.Lottery)
            or nil,
        WeaponUpgradeAll = self.Events.Weapon:FindFirstChild(paths.UpgradeAllWeapon),
        SkillUpgradeAll = self.Events.Skill:FindFirstChild(paths.UpgradeAllSkill),
        RuneUpgrade = self.Events.Rune:FindFirstChild(paths.Upgrade),
        FlyingSwordUpgrade = self.Events.FlyingSword:FindFirstChild(paths.Upgrade),
        SettingsUpdate = self.Events.Settings:FindFirstChild(paths.ModifyPlayerSettings),
        ActivityBuy = self.Events.Activity:FindFirstChild(paths.Buy),
        ArenaBuy = eventsRoot:FindFirstChild(paths.Arena)
            and eventsRoot[paths.Arena]:FindFirstChild(paths.Buy)
            or nil,
    }
end

local ActionThrottle = {
    lastCall = {},
}

function ActionThrottle:canRun(key, cooldown)
    local now = os.clock()
    local previous = self.lastCall[key]
    if previous and (now - previous) < (cooldown or 0) then
        return false
    end
    self.lastCall[key] = now
    return true
end

function ActionThrottle:fireServer(key, remote, cooldown, ...)
    if not remote or not self:canRun(key, cooldown) then
        return false
    end
    return Utils.safePcall(function(...)
        remote:FireServer(...)
    end, ...)
end

function ActionThrottle:fireBindable(key, event, cooldown, ...)
    if not event or not self:canRun(key, cooldown) then
        return false
    end
    return Utils.safePcall(function(...)
        event:Fire(...)
    end, ...)
end

local function updateSetting(key, value)
    if type(key) == 'table' then
        local cursor = State.settings
        for index = 1, #key - 1 do
            cursor[key[index]] = cursor[key[index]] or {}
            cursor = cursor[key[index]]
        end
        cursor[key[#key]] = value
    else
        State.settings[key] = value
    end
    SettingsStore:save(State.settings)
end

local function checkDailyCompletion()
    if State.daily.completionAnnounced then
        return
    end

    if
        State.daily.donationFinished
        and State.daily.herbBuyFinished
        and State.daily.herbCollectFinished
        and State.daily.farmReady
    then
        State.daily.completionAnnounced = true
        Utils.showTopRightNotice('V2 每日链路已完成', 2)
    end
end

local DailyResetService = {
    listeners = {},
}

function DailyResetService:register(name, callback)
    self.listeners[name] = callback
end

function DailyResetService:notify(previousDateKey, currentDateKey)
    for name, callback in pairs(self.listeners) do
        local ok, err = pcall(callback, previousDateKey, currentDateKey)
        if not ok then
            warn(('[DailyReset:%s] %s'):format(name, tostring(err)))
        end
    end
end

function DailyResetService:start()
    Scheduler:ensure('daily_reset', function(job)
        while job.enabled do
            local dateKey = Utils.getUtc8DateKey()
            if dateKey ~= State.daily.currentDateKey then
                local previous = State.daily.currentDateKey
                State.daily.currentDateKey = dateKey
                State.daily.completionAnnounced = false
                print(('[V2] 检测到每日重置 %s -> %s'):format(previous, dateKey))
                self:notify(previous, dateKey)
            end
            task.wait(15)
        end
    end)
end

function DailyResetService:force()
    State.daily.completionAnnounced = false
    for _, callback in pairs(self.listeners) do
        local ok, err = pcall(callback, State.daily.currentDateKey, State.daily.currentDateKey)
        if not ok then
            warn('[DailyReset:force] ' .. tostring(err))
        end
    end
end

local ExternalAssets = {
    cache = {},
    warned = {},
}

function ExternalAssets:warnOnce(key, message)
    if self.warned[key] then
        return
    end
    self.warned[key] = true
    warn(message)
end

function ExternalAssets:loadModule(url, cacheKey)
    local key = cacheKey or url
    if self.cache[key] ~= nil then
        return self.cache[key]
    end

    local ok, result = pcall(function()
        local chunk = loadstring(game:HttpGet(url, true))
        if type(chunk) ~= 'function' then
            return nil
        end
        return chunk()
    end)

    if not ok then
        self:warnOnce(key, ('[ExternalAssets] 加载失败: %s'):format(tostring(result)))
        self.cache[key] = false
        return nil
    end

    self.cache[key] = result or true
    return result
end

function ExternalAssets:runScript(url, cacheKey)
    local key = cacheKey or url
    local ok, result = pcall(function()
        local chunk = loadstring(game:HttpGet(url, true))
        if type(chunk) ~= 'function' then
            return nil
        end
        return chunk()
    end)

    if not ok then
        self:warnOnce(key, ('[ExternalAssets] 运行失败: %s'):format(tostring(result)))
        return false
    end

    return true
end

local RespawnService = {
    pointName = 'Unknown',
    pointNumber = 1,
    position = nil,
}

function RespawnService:getCharacterRoot()
    local character = player.Character or player.CharacterAdded:Wait()
    return character and character:FindFirstChild('HumanoidRootPart') or nil
end

function RespawnService:refresh(teleportHome)
    local resolved = self.pointName
    local helper = ExternalAssets:loadModule(Constants.RespawnScriptUrl, 'respawn_script')

    if type(helper) == 'string' and helper ~= '' then
        resolved = helper
    elseif type(helper) == 'table' then
        if type(helper.getCurrentRespawn) == 'function' then
            local ok, value = pcall(helper.getCurrentRespawn, helper)
            if ok and type(value) == 'string' and value ~= '' then
                resolved = value
            end
        elseif type(helper[1]) == 'string' and helper[1] ~= '' then
            resolved = helper[1]
        end
    end

    local pointNumber = tonumber(tostring(resolved):match('%d+')) or self.pointNumber or 1
    local sceneRoot = Utils.findSceneRoot(pointNumber)
    local spawnPoint = sceneRoot and sceneRoot:FindFirstChild('重生点')

    if not sceneRoot or not spawnPoint or not spawnPoint:IsA('BasePart') then
        return false
    end

    self.pointName = tostring(resolved)
    self.pointNumber = pointNumber
    self.position = spawnPoint.Position + Vector3.new(0, 5, 0)

    if teleportHome then
        self:teleportHome()
    end

    return true
end

function RespawnService:teleportHome()
    if not self.position then
        self:refresh(false)
    end

    local root = self:getCharacterRoot()
    if root and self.position then
        root.CFrame = CFrame.new(self.position)
        return true
    end

    return false
end

function RespawnService:isAtRespawn(maxDistance)
    local root = self:getCharacterRoot()
    if not root then
        return false
    end

    if not self.position then
        self:refresh(false)
    end

    return self.position ~= nil
        and (root.Position - self.position).Magnitude <= (maxDistance or 5)
end

function RespawnService:teleportForge()
    local sceneRoot = Utils.findSceneRoot(self.pointNumber)
    local buildingFolder = sceneRoot and sceneRoot:FindFirstChild('\229\187\186\233\128\160\231\137\169')
    local forge = buildingFolder and buildingFolder:FindFirstChild('035\231\130\188\229\153\168\229\143\176')
    local root = self:getCharacterRoot()

    if forge and root then
        root.CFrame = forge:GetPivot()
        return true
    end

    return false
end

local SafetyController = {
    radius = Vector3.new(500, 500, 500) / 2,
    overlayGui = nil,
    overlayFrame = nil,
}

function SafetyController:getNearbyPlayers()
    local root = RespawnService:getCharacterRoot()
    if not root then
        return 0
    end

    local count = 0
    local position = root.Position

    for _, otherPlayer in ipairs(Services.Players:GetPlayers()) do
        if otherPlayer ~= player then
            local otherRoot = otherPlayer.Character and otherPlayer.Character:FindFirstChild('HumanoidRootPart')
            if otherRoot then
                local offset = otherRoot.Position - position
                local inRange = math.abs(offset.X) <= self.radius.X
                    and math.abs(offset.Y) <= self.radius.Y
                    and math.abs(offset.Z) <= self.radius.Z
                if inRange then
                    count = count + 1
                end
            end
        end
    end

    return count
end

function SafetyController:start()
    Scheduler:ensure('safety_monitor_v2', function(job)
        while job.enabled do
            if State.settings.safetyMode then
                State.safety.nearbyPlayers = self:getNearbyPlayers()
                State.safety.paused = State.safety.nearbyPlayers > 0
            else
                State.safety.nearbyPlayers = 0
                State.safety.paused = false
            end
            task.wait(0.5)
        end
    end)
end

function SafetyController:isPaused()
    return State.settings.safetyMode and State.safety.paused
end

function SafetyController:ensureOverlay()
    if self.overlayGui and self.overlayGui.Parent then
        return
    end

    self.overlayGui = Instance.new('ScreenGui')
    self.overlayGui.Name = 'CultivationV2BlackScreen'
    self.overlayGui.ResetOnSpawn = false
    self.overlayGui.Parent = playerGui

    self.overlayFrame = Instance.new('Frame')
    self.overlayFrame.Name = 'Overlay'
    self.overlayFrame.Size = UDim2.fromScale(1, 1)
    self.overlayFrame.Position = UDim2.new()
    self.overlayFrame.BackgroundColor3 = Color3.new(0, 0, 0)
    self.overlayFrame.BorderSizePixel = 0
    self.overlayFrame.Visible = false
    self.overlayFrame.Parent = self.overlayGui
end

function SafetyController:setBlackScreen(enabled)
    self:ensureOverlay()
    if self.overlayFrame then
        self.overlayFrame.Visible = enabled == true
    end
end

local UiOpeners = {}

function UiOpeners.fireByName(name, ...)
    local event = Services.ReplicatedStorage:FindFirstChild(name, true)
    if not event or not event:IsA('BindableEvent') then
        return false
    end
    ActionThrottle:fireBindable('open_' .. name, event, 0.2, ...)
    return true
end

function UiOpeners.openGuild()
    UiOpeners.fireByName('打开公会', '打开公会')
end

function UiOpeners.openFarm(index)
    local event = Services.ReplicatedStorage:FindFirstChild('打开农田', true)
    if event and event:IsA('BindableEvent') then
        ActionThrottle:fireBindable('open_farm', event, 0.2, index or 1)
    end
end

function UiOpeners.openDailyTask()
    UiOpeners.fireByName('打开每日任务', '打开每日任务')
end

function UiOpeners.openMail()
    UiOpeners.fireByName('打开邮件', '打开邮件')
end

function UiOpeners.openSpin()
    UiOpeners.fireByName('打开转盘', '打开转盘')
end

function UiOpeners.openRune()
    UiOpeners.fireByName('打开阵法', '打开阵法')
end

function UiOpeners.openWorldTree()
    UiOpeners.fireByName('打开世界树', '打开世界树')
end

function UiOpeners.openForge()
    UiOpeners.fireByName('打开炼器台', '打开炼器台')
end

function UiOpeners.openElixir()
    UiOpeners.fireByName('打开炼丹炉', '打开炼丹炉')
end

local OnlineRewardController = {}

function OnlineRewardController:getRoot()
    return Utils.deepWait(playerGui, {
        'GUI',
        '二级界面',
        '节日活动商店',
        '背景',
        '右侧界面',
        '在线奖励',
        '列表',
    }, 2)
end

function OnlineRewardController:getRewardFrames()
    local root = self:getRoot()
    if not root then
        return {}
    end

    local rewardFrames = {}
    for _, child in ipairs(root:GetChildren()) do
        if child:IsA('Frame') and child:FindFirstChild('按钮') then
            table.insert(rewardFrames, child)
        end
    end

    table.sort(rewardFrames, function(a, b)
        return (a.LayoutOrder or 0) < (b.LayoutOrder or 0)
    end)

    return rewardFrames
end

function OnlineRewardController:getMinCountdown()
    local frames = self:getRewardFrames()
    local minCountdown = math.huge

    for index, frame in ipairs(frames) do
        local button = frame:FindFirstChild('按钮')
        local countdownLabel = button and button:FindFirstChild('倒计时')
        if countdownLabel then
            local text = countdownLabel.Text
            if text == 'DONE' then
                minCountdown = math.min(minCountdown, 0)
            elseif text ~= 'CLAIMED!' then
                local minutes, seconds = text:match('^(%d+):(%d+)$')
                if minutes and seconds then
                    local total = tonumber(minutes) * 60 + tonumber(seconds)
                    minCountdown = math.min(minCountdown, total)
                end
            end
        end
        if index >= 6 then
            break
        end
    end

    if minCountdown == math.huge then
        return nil
    end
    return minCountdown
end

function OnlineRewardController:claimAll()
    for index = 1, 6 do
        ActionThrottle:fireServer(
            'online_reward_' .. tostring(index),
            PathRegistry.Events.Activity:FindFirstChild(Constants.Paths.ClaimReward),
            0.15,
            index
        )
    end
end

function OnlineRewardController:start()
    Scheduler:ensure('online_rewards_v2', function(job)
        while job.enabled and State.settings.autoOnlineRewards do
            local minCountdown = self:getMinCountdown()
            State.rewards.countdown = minCountdown

            if minCountdown ~= nil and minCountdown <= 0 then
                self:claimAll()
                task.wait(2)
            else
                task.wait(1)
            end
        end
    end)
end

function OnlineRewardController:stop()
    Scheduler:stop('online_rewards_v2')
end

local GuildController = {
    retryDelay = 30,
    refreshLimit = 7000,
    herbPrice = 400,
}

function GuildController:getGuildName()
    local label = Utils.deepWait(playerGui, {
        'GUI',
        '二级界面',
        '公会',
        '背景',
        '右侧界面',
        '主页',
        '介绍',
        '名称',
        '文本',
        '文本',
    }, 2)

    if label and label:IsA('TextLabel') and label.Text ~= '' then
        return label.Text
    end

    return '未读取'
end

function GuildController:getDonationRemaining()
    local label = Utils.deepWait(playerGui, {
        'GUI',
        '二级界面',
        '公会',
        '捐献',
        '背景',
        '按钮',
        '确定按钮',
        '次数',
    }, 2)

    if not label or not label:IsA('TextLabel') then
        return nil
    end

    return tonumber(string.match(label.Text, '%d+')) or 0
end

function GuildController:getDiamond()
    return Utils.parseNumber(
        playerGui.GUI[Constants.Paths.MainGui]['\228\184\187\229\159\142']['\232\180\167\229\184\129\229\140\186\229\159\159']['\233\146\187\231\159\179']['\230\140\137\233\146\174']['\229\128\188'].Text
    )
end

function GuildController:getGuildCoin()
    return Utils.parseNumber(
        playerGui.GUI[Constants.Paths.SecondaryGui][Constants.Paths.Guild]['\232\131\140\230\153\175']['\229\143\179\228\190\167\231\149\140\233\157\162']['\229\149\134\229\186\151']['\229\133\172\228\188\154\229\184\129']['\230\140\137\233\146\174']['\229\128\188'].Text
    )
end

function GuildController:getRefreshCost()
    return Utils.parseNumber(
        playerGui.GUI[Constants.Paths.SecondaryGui][Constants.Paths.Guild]['\232\131\140\230\153\175']['\229\143\179\228\190\167\231\149\140\233\157\162']['\229\149\134\229\186\151']['\229\136\183\230\150\176']['\230\140\137\233\146\174']['\229\128\188'].Text
    )
end

function GuildController:setGuildPanelVisible(visible)
    Utils.safePcall(function()
        PathRegistry.GUI.Secondary[Constants.Paths.Guild].Visible = visible
    end)
end

function GuildController:openGuildPanel()
    UiOpeners.openGuild()
    task.wait(0.2)
end

function GuildController:refreshDonationState(timeout)
    self:openGuildPanel()

    local deadline = os.clock() + (timeout or 3)
    local lastRemaining = nil

    while os.clock() < deadline do
        local remaining = self:getDonationRemaining()
        self:updateDisplay()

        if type(remaining) == 'number' then
            lastRemaining = remaining
            if remaining > 0 then
                return remaining
            end
        end

        task.wait(0.25)
    end

    self:updateDisplay()
    return lastRemaining
end

function GuildController:updateDisplay()
    local remaining = self:getDonationRemaining()
    local text = ('公会：%s | 捐献剩余：%s'):format(
        self:getGuildName(),
        tostring(remaining or '读取失败')
    )

    if State.ui.guildInfoLabel then
        State.ui.guildInfoLabel.Text = text
    end

    if State.ui.guildOverviewLabel then
        State.ui.guildOverviewLabel.Text = text
    end
end

function GuildController:startDonation()
    Scheduler:ensure('guild_donation_v2', function(job)
        self:refreshDonationState(3)
        while job.enabled and State.settings.autoDonate do
            self:updateDisplay()
            local remaining = self:getDonationRemaining()
            if type(remaining) == 'number' then
                if remaining > 0 then
                    ActionThrottle:fireServer(
                        'guild_donate',
                        PathRegistry.Events.Guild:FindFirstChild(Constants.Paths.Donate),
                        0.35
                    )
                    task.wait(0.5)
                else
                    local confirmedRemaining = self:refreshDonationState(1.5)
                    if confirmedRemaining == nil then
                        task.wait(0.5)
                    elseif confirmedRemaining > 0 then
                        task.wait(0.2)
                    else
                        State.daily.donationFinished = true
                        checkDailyCompletion()
                        break
                    end
                end
            else
                task.wait(1)
            end
        end
    end)
end

function GuildController:startHerbShop()
    Scheduler:ensure('guild_shop_v2', function(job)
        self:openGuildPanel()

        while job.enabled and State.settings.autoGuildShop do
            if not State.daily.donationFinished then
                task.wait(2)
            else
                local itemList = Utils.deepWait(playerGui, {
                    'GUI',
                    '二级界面',
                    '公会',
                    '背景',
                    '右侧界面',
                    '商店',
                    '列表',
                }, 2)

                if itemList then
                    local diamond = self:getDiamond()

                    for slotIndex = 1, 18 do
                        local item = itemList:GetChildren()[slotIndex]
                        if item and item:FindFirstChild('\230\140\137\233\146\174') then
                            local button = item['\230\140\137\233\146\174']
                            if
                                button['\229\186\147\229\173\152'].Text == '1 Left'
                                and button['\229\144\141\231\167\176'].Text == 'Herb'
                                and diamond >= self.herbPrice
                            then
                                ActionThrottle:fireServer(
                                    'guild_exchange_' .. tostring(slotIndex),
                                    PathRegistry.Events.Guild:FindFirstChild(Constants.Paths.Exchange),
                                    0.15,
                                    slotIndex - 2
                                )
                                diamond = diamond - self.herbPrice
                                task.wait(0.1)
                            end
                        end
                    end
                end

                local refreshCost = self:getRefreshCost()
                local diamond = self:getDiamond()
                local guildCoin = self:getGuildCoin()

                if refreshCost > self.refreshLimit then
                    State.daily.herbBuyFinished = true
                    self:setGuildPanelVisible(false)
                    checkDailyCompletion()
                    break
                end

                if diamond > refreshCost and guildCoin >= 400 and diamond >= 18000 then
                    Utils.safePcall(function()
                        local openGuildEvent = Utils.deepWait(Services.ReplicatedStorage, {
                            Constants.Paths.EventsRoot,
                            Constants.Paths.Client,
                            Constants.Paths.ClientUi,
                            Constants.Paths.OpenGuildFromClient,
                        }, 2)
                        if openGuildEvent then
                            openGuildEvent:Fire()
                        end
                    end)

                    task.wait(0.5)
                    ActionThrottle:fireServer(
                        'guild_refresh_shop',
                        PathRegistry.Events.Guild:FindFirstChild(Constants.Paths.RefreshGuildShop),
                        1
                    )
                    task.wait(1.5)
                else
                    task.wait(self.retryDelay)
                end
            end
        end
    end)
end

function GuildController:stop()
    Scheduler:stop('guild_donation_v2')
    Scheduler:stop('guild_shop_v2')
end

function GuildController:onDailyReset()
    self:stop()
    State.daily.donationFinished = false
    State.daily.herbBuyFinished = false
    task.spawn(function()
        self:refreshDonationState(3)

        if State.settings.autoDonate then
            self:startDonation()
        else
            self:updateDisplay()
        end
        if State.settings.autoGuildShop then
            self:startHerbShop()
        end
    end)
end

local FarmController = {
    collectInterval = 60,
    readyCheckDuration = 45,
}

function FarmController:openFarm5()
    Utils.safePcall(function()
        local farmOpenRemote = Utils.deepWait(Services.ReplicatedStorage, {
            Constants.Paths.EventsRoot,
            Constants.Paths.Farm,
            Constants.Paths.FarmUi,
            Constants.Paths.AttributeArea,
        }, 2)

        if farmOpenRemote then
            farmOpenRemote:FireServer(5)
        end
    end)
end

function FarmController:readFarm5Number()
    local label = Utils.deepWait(playerGui, {
        'GUI',
        Constants.Paths.SecondaryGui,
        Constants.Paths.Farm,
        '\232\131\140\230\153\175',
        Constants.Paths.AttributeArea,
        '\230\148\182\233\155\134\230\140\137\233\146\174',
        '\230\149\176\233\135\143\229\140\186',
        '\230\149\176\233\135\143',
    }, 2)

    if not label or not label:IsA('TextLabel') then
        return nil
    end

    return tonumber(label.Text) or 0
end

function FarmController:checkFarmReady()
    self:openFarm5()

    local deadline = os.clock() + self.readyCheckDuration
    while os.clock() < deadline do
        local current = self:readFarm5Number()
        if current ~= nil then
            if current < 100 then
                State.daily.farmReady = true
                checkDailyCompletion()
                return true
            end
        end
        task.wait(3)
    end

    State.daily.farmReady = false
    return false
end

function FarmController:collectOnce()
    for index = 1, 6 do
        ActionThrottle:fireServer(
            'farm_collect_' .. tostring(index),
            PathRegistry.Events.Farm:FindFirstChild(Constants.Paths.Collect),
            0.08,
            index,
            nil
        )
        task.wait(0.1)
    end
end

function FarmController:start()
    Scheduler:ensure('farm_collect_v2', function(job)
        while job.enabled and State.settings.autoCollectHerbs do
            self:collectOnce()
            State.daily.herbCollectFinished = true
            self:checkFarmReady()
            checkDailyCompletion()
            task.wait(self.collectInterval)
        end
    end)
end

function FarmController:stop()
    Scheduler:stop('farm_collect_v2')
end

function FarmController:onDailyReset()
    State.daily.herbCollectFinished = false
    State.daily.farmReady = false
    if State.settings.autoCollectHerbs then
        self:start()
    end
end

local LegacyDailyController = {
    missingFunctions = {},
    primaryFunctions = {
        'mainmissionchack',
        'everydaymission',
        'gamepassmission',
        'gamepassgiftget',
        'potionfull',
    },
    secondaryFunctions = {
        'dailyspin',
        'offlinereward',
        'everydaygem',
    },
}

function LegacyDailyController:runList(functionNames)
    for _, functionName in ipairs(functionNames) do
        local ok, err = Utils.callGlobalFunction(functionName)
        if ok == false and err == 'missing' then
            self.missingFunctions[functionName] = true
        end
    end
end

function LegacyDailyController:start()
    Scheduler:ensure('legacy_daily_primary_v2', function(job)
        while job.enabled and State.settings.autoLegacyDaily do
            self:runList(self.primaryFunctions)
            task.wait(20)
        end
    end)

    Scheduler:ensure('legacy_daily_secondary_v2', function(job)
        while job.enabled and State.settings.autoLegacyDaily do
            self:runList(self.secondaryFunctions)
            task.wait(500)
        end
    end)
end

function LegacyDailyController:stop()
    Scheduler:stop('legacy_daily_primary_v2')
    Scheduler:stop('legacy_daily_secondary_v2')
end

function LegacyDailyController:getMissingCount()
    local count = 0
    for _ in pairs(self.missingFunctions) do
        count = count + 1
    end
    return count
end

local InvestmentController = {}

function InvestmentController:start()
    Scheduler:ensure('investment_v2', function(job)
        while job.enabled and State.settings.autoInvest do
            for index = 1, 3 do
                ActionThrottle:fireServer(
                    'invest_claim_' .. tostring(index),
                    PathRegistry.Remotes.InvestClaim,
                    0.15,
                    index
                )
            end

            task.wait(5)

            for index = 1, 3 do
                ActionThrottle:fireServer(
                    'invest_buy_' .. tostring(index),
                    PathRegistry.Remotes.InvestBuy,
                    0.15,
                    index
                )
            end

            task.wait(600)
        end
    end)
end

function InvestmentController:stop()
    Scheduler:stop('investment_v2')
end

local MiscController = {}

function MiscController:getCurrencyPanel()
    return Utils.deepWait(PathRegistry.GUI.Root, {
        Constants.Paths.MainGui,
        Constants.Paths.MainCity,
        Constants.Paths.CurrencyArea,
    }, 2)
end

function MiscController:applyShowAllCurrencies()
    local panel = self:getCurrencyPanel()
    if not panel then
        return
    end

    for _, child in ipairs(panel:GetChildren()) do
        if child:IsA('GuiObject') then
            if State.currency.visibilityCache[child] == nil then
                State.currency.visibilityCache[child] = child.Visible
            end
            child.Visible = true
        end
    end
end

function MiscController:restoreCurrencyVisibility()
    for child, originalVisible in pairs(State.currency.visibilityCache) do
        if child and child.Parent and child:IsA('GuiObject') then
            child.Visible = originalVisible
        end
    end
    table.clear(State.currency.visibilityCache)
end

function MiscController:startShowAllCurrencies()
    Scheduler:ensure('show_all_currency_v2', function(job)
        while job.enabled and State.settings.autoShowAllCurrency do
            self:applyShowAllCurrencies()
            task.wait(0.3)
        end
    end)
end

function MiscController:stopShowAllCurrencies()
    Scheduler:stop('show_all_currency_v2')
    self:restoreCurrencyVisibility()
end

function MiscController:removeRewardUi()
    local rewardRoot = PathRegistry.GUI.Secondary
    if not rewardRoot then
        return false
    end

    local removed = false
    for _, name in ipairs({
        '展示奖励界面',
        '离线奖励',
        '版本说明',
        '7日奖励',
    }) do
        local child = rewardRoot:FindFirstChild(name)
        if child then
            child:Destroy()
            removed = true
        end
    end

    return removed
end

function MiscController:redeemGiftCodes()
    local eventsRoot = Services.ReplicatedStorage
        :FindFirstChild(Constants.Paths.EventsRoot, true)
    local redeemRoot = eventsRoot and eventsRoot:FindFirstChild('\230\191\128\230\180\187\231\160\129')
    local redeemRemote = redeemRoot and redeemRoot:FindFirstChild('\231\142\169\229\174\182\229\133\145\230\141\162\230\191\128\230\180\187\231\160\129')

    if not redeemRemote then
        return false
    end

    for _, code in ipairs(Constants.GiftCodes) do
        ActionThrottle:fireServer('gift_code_' .. code, redeemRemote, 0.1, code)
    end

    return true
end

function MiscController:deleteLanguageConfig()
    return Utils.tryDeleteFile(Constants.LegacyLanguageFile)
end

function MiscController:closeSettingsOnce()
    local settingPanel = Utils.deepWait(PathRegistry.GUI.Secondary, {
        Constants.Paths.Settings,
        '背景',
        '设置区域',
        '音乐设置项',
        '开启',
        '前景',
    }, 2)

    if not settingPanel or not settingPanel.Visible or not PathRegistry.Remotes.SettingsUpdate then
        return false
    end

    for _, args in ipairs({
        '音乐',
        '粒子特效',
        '伤害显示',
        '掉落动画',
        '音效',
        '抽奖动画',
        '法宝动画',
        '出售二次确认',
    }) do
        ActionThrottle:fireServer(
            'settings_close_' .. tostring(args),
            PathRegistry.Remotes.SettingsUpdate,
            0.05,
            args
        )
    end

    return true
end

function MiscController:buyMonthlyKeys()
    local remote = PathRegistry.Remotes.ActivityBuy
    if not remote then
        return false
    end

    local function buyItemTarget(itemId, targetCount)
        local remaining = targetCount
        local purchased = false

        while remaining > 0 do
            local ok = ActionThrottle:fireServer(
                string.format('monthly_key_buy_%d_%d', itemId, remaining),
                remote,
                0,
                itemId,
                1
            )

            if not ok then
                break
            end

            purchased = true
            remaining = remaining - 1
            task.wait(0.05)
        end

        return purchased
    end

    local bought = false

    for itemId = 4, 9 do
        bought = buyItemTarget(itemId, 60) or bought
    end

    for itemId = 17, 22 do
        bought = buyItemTarget(itemId, 30) or bought
    end

    return bought
end

function MiscController:buyArenaWater()
    local remote = PathRegistry.Remotes.ArenaBuy
    if not remote then
        return false
    end

    for round = 1, 15 do
        ActionThrottle:fireServer(
            'arena_buy_water_' .. tostring(round),
            remote,
            0,
            4
        )
    end

    return true
end

function MiscController:runTradeScript(index)
    local url = Constants.TradeScriptUrls[index]
    if not url then
        return false
    end

    return ExternalAssets:runScript(url, 'trade_script_' .. tostring(index))
end

function MiscController:runStatsScript()
    return ExternalAssets:runScript(Constants.StatsScriptUrl, 'stats_script')
end

function MiscController:copyGithubLink()
    if type(setclipboard) == 'function' then
        setclipboard(Constants.GithubUrl)
        return true
    end
    return false
end

local WorldController = {
    presets = {
        { label = 'World 01', level = 1 },
        { label = 'World 21', level = 21 },
        { label = 'World 55', level = 55 },
        { label = 'World 64', level = 64 },
        { label = 'World 82', level = 82 },
        { label = 'World 101', level = 101 },
    },
}

function WorldController:getUnlockedLevel()
    local valuesRoot = player:FindFirstChild(Constants.Paths.Values)
        or player:WaitForChild(Constants.Paths.Values, 2)
    local progressRoot = valuesRoot
        and (
            valuesRoot:FindFirstChild(Constants.Paths.MainProgress)
            or valuesRoot:WaitForChild(Constants.Paths.MainProgress, 2)
        )
        or nil
    local worldValue = progressRoot
        and (progressRoot:FindFirstChild('world') or progressRoot:WaitForChild('world', 2))
        or nil

    if valuesRoot then
        PathRegistry.Values = valuesRoot
    end
    if progressRoot then
        PathRegistry.Progress = progressRoot
    end

    local unlocked = worldValue and tonumber(worldValue.Value) or State.world.unlocked or 1
    unlocked = math.max(1, math.floor(tonumber(unlocked) or 1))
    State.world.unlocked = unlocked
    return unlocked
end

function WorldController:getSelectedLevel()
    if State.settings.world.mode == 'auto_highest' then
        return self:getUnlockedLevel()
    end
    return math.max(1, tonumber(State.settings.world.level) or 1)
end

function WorldController:setManualLevel(level)
    updateSetting({ 'world', 'mode' }, 'manual')
    updateSetting({ 'world', 'level' }, math.max(1, math.floor(tonumber(level) or 1)))
end

function WorldController:setAutoHighest()
    updateSetting({ 'world', 'mode' }, 'auto_highest')
    updateSetting({ 'world', 'level' }, self:getUnlockedLevel())
end

function WorldController:getCombatInfoText()
    local label = Utils.deepWait(PathRegistry.GUI.Main, {
        Constants.Paths.Combat,
        '关卡信息',
        '文本',
    }, 2)
    return label and label.Text or ''
end

function WorldController:getBattleProgress()
    local progress = self:getCombatInfoText():match('-(%d+)%/')
    return tonumber(progress)
end

function WorldController:isVictory()
    local label = Utils.deepWait(PathRegistry.GUI.Main, {
        Constants.Paths.Combat,
        '胜利结果',
    }, 2)
    return label and label.Visible and label.Text == 'Victory' or false
end

function WorldController:enterSelectedWorld()
    local level = self:getSelectedLevel()
    return ActionThrottle:fireServer('world_enter_' .. tostring(level), PathRegistry.Remotes.WorldEnter, 0.3, level)
end

function WorldController:toggleAutoBattle()
    local value = PathRegistry.Settings and PathRegistry.Settings:FindFirstChild(Constants.Paths.AutoBattle)
    if value and value:IsA('BoolValue') then
        value.Value = not value.Value
        return value.Value
    end
    return nil
end

function WorldController:startAutoHighestWatcher()
    Scheduler:ensure('world_auto_highest_v2', function(job)
        while job.enabled and State.settings.world.mode == 'auto_highest' do
            local unlocked = self:getUnlockedLevel()
            if State.settings.world.level ~= unlocked then
                updateSetting({ 'world', 'level' }, unlocked)
            end
            task.wait(1)
        end
    end)
end

function WorldController:stopAutoHighestWatcher()
    Scheduler:stop('world_auto_highest_v2')
end

function WorldController:startAutoReenter()
    Scheduler:ensure('world_auto_reenter_v2', function(job)
        while job.enabled and State.settings.world.autoReenter75 do
            if not SafetyController:isPaused() then
                local progress = self:getBattleProgress()
                if progress and progress >= 75 then
                    self:enterSelectedWorld()
                    task.wait(1)
                end
            end
            task.wait(1)
        end
    end)
end

function WorldController:stopAutoReenter()
    Scheduler:stop('world_auto_reenter_v2')
end

function WorldController:startAutoStart()
    Scheduler:ensure('world_auto_start_v2', function(job)
        while job.enabled and State.settings.world.autoStart do
            if SafetyController:isPaused() then
                task.wait(1)
            else
                if self:isVictory() then
                    RespawnService:teleportHome()
                    task.wait(0.5)
                    self:enterSelectedWorld()
                    task.wait(3)
                elseif RespawnService:isAtRespawn(3) then
                    self:enterSelectedWorld()
                    task.wait(2)
                else
                    task.wait(0.3)
                end
            end
        end
    end)
end

function WorldController:stopAutoStart()
    Scheduler:stop('world_auto_start_v2')
end

function WorldController:syncModes()
    if State.settings.world.mode == 'auto_highest' then
        self:startAutoHighestWatcher()
    else
        self:stopAutoHighestWatcher()
    end

    if State.settings.world.autoReenter75 then
        self:startAutoReenter()
    else
        self:stopAutoReenter()
    end

    if State.settings.world.autoStart then
        self:startAutoStart()
    else
        self:stopAutoStart()
    end
end

local DungeonController = {
    dungeonOrder = {
        'OreDungeon',
        'GemDungeon',
        'RuneDungeon',
        'RelicDungeon',
        'HoverDungeon',
        'GoldDungeon',
    },
    configs = {
        OreDungeon = { id = 1, label = 'Ore Dungeon', zh = '矿石地下城', uiName = 'OreDungeon' },
        GemDungeon = { id = 2, label = 'Gem Dungeon', zh = '灵石地下城', uiName = 'GemDungeon' },
        RuneDungeon = { id = 3, label = 'Rune Dungeon', zh = '符石地下城', uiName = 'RuneDungeon' },
        RelicDungeon = { id = 4, label = 'Relic Dungeon', zh = '遗物地下城', uiName = 'RelicDungeon' },
        HoverDungeon = { id = 7, label = 'Hover Dungeon', zh = '悬浮地下城', uiName = 'HoverDungeon' },
        GoldDungeon = { id = 6, label = 'Gold Dungeon', zh = '金币地下城', uiName = 'GoldDungeon' },
    },
}

function DungeonController:getSelectedConfig()
    return self.configs[State.settings.dungeon.selected] or self.configs.OreDungeon
end

function DungeonController:getSelectedLevel()
    local key = self:getSelectedConfig()
    return math.max(1, tonumber(State.settings.dungeon.levels[key.uiName]) or 1)
end

function DungeonController:setSelected(name)
    local config = self.configs[name]
    if not config then
        return
    end

    updateSetting({ 'dungeon', 'selected' }, name)
    updateSetting({ 'dungeon', 'selectedId' }, config.id)
end

function DungeonController:setSelectedLevel(level)
    local config = self:getSelectedConfig()
    local levels = Utils.cloneTable(State.settings.dungeon.levels)
    levels[config.uiName] = math.max(1, math.floor(tonumber(level) or 1))
    updateSetting({ 'dungeon', 'levels' }, levels)
end

function DungeonController:adjustLevel(delta)
    self:setSelectedLevel(self:getSelectedLevel() + delta)
end

function DungeonController:getDungeonListRoot()
    return Utils.deepWait(PathRegistry.GUI.Root, {
        Constants.Paths.SecondaryGui,
        '关卡选择',
        '背景',
        '右侧界面',
        '副本',
        '列表',
    }, 2)
end

function DungeonController:getKeyCount(name)
    local root = self:getDungeonListRoot()
    local slot = root and root:FindFirstChild(name)
    local valueLabel = slot and Utils.deepWait(slot, { '钥匙', '值' }, 1)
    if not valueLabel then
        return 0
    end
    return tonumber((valueLabel.Text or ''):match('^%d+')) or 0
end

function DungeonController:refreshKeyCounts()
    for _, name in ipairs(self.dungeonOrder) do
        State.dungeon.keyCounts[name] = self:getKeyCount(name)
    end
end

function DungeonController:getBestDungeonByKeys()
    self:refreshKeyCounts()

    local bestName = 'OreDungeon'
    local bestCount = -1

    for _, name in ipairs(self.dungeonOrder) do
        local count = tonumber(State.dungeon.keyCounts[name]) or 0
        if count > bestCount then
            bestName = name
            bestCount = count
        end
    end

    return bestName, math.max(bestCount, 0)
end

function DungeonController:enterSelected()
    local config = self:getSelectedConfig()
    local level = self:getSelectedLevel()
    return ActionThrottle:fireServer(
        'dungeon_enter_' .. config.uiName,
        PathRegistry.Remotes.DungeonEnter,
        0.3,
        config.id,
        level
    )
end

function DungeonController:getVictoryLabel()
    return Utils.deepWait(PathRegistry.GUI.Main, {
        Constants.Paths.Combat,
        '胜利结果',
    }, 2)
end

function DungeonController:isVictory()
    local label = self:getVictoryLabel()
    return label and label.Visible and label.Text == 'Victory' or false
end

function DungeonController:clearVictory()
    local label = self:getVictoryLabel()
    if label then
        label.Text = ''
    end
end

function DungeonController:syncLevelFromPopup()
    local popup = Utils.deepWait(PathRegistry.GUI.Root, {
        Constants.Paths.SecondaryGui,
        '关卡选择',
        '副本选择弹出框',
        '背景',
    }, 2)

    if not popup or not popup.Visible then
        return
    end

    local titleLabel = Utils.deepWait(popup, { '标题', '名称' }, 1)
    local difficultyValue = Utils.deepWait(popup, { '难度', '难度等级', '值' }, 1)
    if not titleLabel or not difficultyValue then
        return
    end

    local selectedName
    for name, config in pairs(self.configs) do
        if titleLabel.Text == config.label then
            selectedName = name
            break
        end
    end

    local level = tonumber(difficultyValue.Text)
    if selectedName and level and level > 0 then
        self:setSelected(selectedName)
        self:setSelectedLevel(level)
    end
end

function DungeonController:startSyncUi()
    Scheduler:ensure('dungeon_sync_ui_v2', function(job)
        while job.enabled and State.settings.dungeon.autoSyncUi do
            self:syncLevelFromPopup()
            task.wait(1)
        end
    end)
end

function DungeonController:stopSyncUi()
    Scheduler:stop('dungeon_sync_ui_v2')
end

function DungeonController:startKeyWatcher()
    Scheduler:ensure('dungeon_key_watch_v2', function(job)
        while job.enabled do
            self:refreshKeyCounts()
            task.wait(0.5)
        end
    end)
end

function DungeonController:startAutoStart()
    Scheduler:ensure('dungeon_auto_start_v2', function(job)
        while job.enabled and State.settings.dungeon.autoStart do
            if SafetyController:isPaused() then
                task.wait(1)
            else
                if self:isVictory() then
                    local currentKey = self:getSelectedConfig().uiName
                    local currentCount = tonumber(State.dungeon.keyCounts[currentKey]) or 0

                    if State.settings.dungeon.autoPlusOne then
                        self:adjustLevel(1)
                        task.wait(0.2)
                    end

                    if State.settings.dungeon.autoFinishAll and currentCount <= 0 then
                        local bestName = self:getBestDungeonByKeys()
                        self:setSelected(bestName)
                    end

                    self:clearVictory()
                    RespawnService:teleportHome()
                    task.wait(0.5)
                    self:enterSelected()
                    task.wait(2)
                elseif RespawnService:isAtRespawn(5) then
                    self:enterSelected()
                    task.wait(2)
                else
                    task.wait(0.5)
                end
            end
        end
    end)
end

function DungeonController:stopAutoStart()
    Scheduler:stop('dungeon_auto_start_v2')
end

function DungeonController:syncModes()
    if State.settings.dungeon.autoSyncUi then
        self:startSyncUi()
    else
        self:stopSyncUi()
    end

    if State.settings.dungeon.autoStart then
        self:startAutoStart()
    else
        self:stopAutoStart()
    end
end

local PrivilegeController = {}

function PrivilegeController:apply()
    local privileges = PathRegistry.Privileges
    if not privileges then
        return false
    end

    local superRefine = privileges:FindFirstChild(Constants.Paths.AutoRefineSuper)
    local autoRefine = privileges:FindFirstChild(Constants.Paths.AutoRefine)

    if superRefine and superRefine:IsA('BoolValue') then
        superRefine.Value = false
    end

    if autoRefine and autoRefine:IsA('BoolValue') then
        autoRefine.Value = State.settings.autoRefinePrivilege == true
        return true
    end

    return false
end

local ElixirCraftController = {
    reasons = {},
}

function ElixirCraftController:isActive()
    return next(self.reasons) ~= nil
end

function ElixirCraftController:enable(reason)
    self.reasons[reason or 'default'] = true
    Scheduler:ensure('elixir_craft_v2', function(job)
        while job.enabled and self:isActive() do
            ActionThrottle:fireServer(
                'elixir_craft_v2',
                PathRegistry.Remotes.ElixirCraft,
                0.18
            )
            task.wait(0.2)
        end
    end)
end

function ElixirCraftController:disable(reason)
    self.reasons[reason or 'default'] = nil
    if not self:isActive() then
        Scheduler:stop('elixir_craft_v2')
    end
end

function ElixirCraftController:syncManualSetting()
    if State.settings.autoElixirCraft then
        self:enable('manual')
    else
        self:disable('manual')
    end
end

local LotteryController = {
    speed = 0.7,
}

function LotteryController:getCurrencyNumber(name)
    local valueObject = PathRegistry.Currency and PathRegistry.Currency:FindFirstChild(name)
    local rawValue = valueObject and (valueObject.Value or valueObject.value) or 0
    return tonumber(rawValue) or 0
end

function LotteryController:getPanel(kind)
    return Utils.deepWait(PathRegistry.GUI.Root, {
        Constants.Paths.SecondaryGui,
        '商店',
        '背景',
        '右侧界面',
        '召唤',
        kind,
    }, 2)
end

function LotteryController:readPanel(kind)
    local panel = self:getPanel(kind)
    if not panel then
        return 0, 0
    end

    local levelLabel = Utils.deepWait(panel, { '等级区域', '值' }, 1)
    local progressLabel = Utils.deepWait(panel, { '等级区域', '进度条', '值', '值' }, 1)
    local level = tonumber((levelLabel and levelLabel.Text or ''):match('%d+')) or 0
    local progress = tonumber((progressLabel and progressLabel.Text or ''):match('(%d+)/')) or 0

    return level, progress
end

function LotteryController:refreshState()
    State.lottery.diamonds = self:getCurrencyNumber('钻石')
    State.lottery.swordTickets = self:getCurrencyNumber('法宝抽奖券')
    State.lottery.skillTickets = self:getCurrencyNumber('技能抽奖券')
end

function LotteryController:pull(kind)
    if not PathRegistry.Remotes.Summon then
        return false
    end

    local currentTickets = kind == '法宝'
        and State.lottery.swordTickets
        or State.lottery.skillTickets
    local missingTickets = math.max(0, 8 - (tonumber(currentTickets) or 0))
    local canUseDiamonds = State.settings.useDiamondsForLottery
        and State.lottery.diamonds >= (missingTickets * 50)

    if (tonumber(currentTickets) or 0) < 8 and not canUseDiamonds then
        return false
    end

    return ActionThrottle:fireServer(
        'lottery_pull_' .. tostring(kind),
        PathRegistry.Remotes.Summon,
        0.15,
        kind,
        true
    )
end

function LotteryController:chooseAndPull()
    self:refreshState()

    local skillLevel, skillProgress = self:readPanel('技能')
    local weaponLevel, weaponProgress = self:readPanel('法宝')

    if skillLevel > weaponLevel then
        self:pull('法宝')
    elseif skillLevel < weaponLevel then
        self:pull('技能')
    elseif skillProgress > weaponProgress then
        self:pull('法宝')
    elseif skillProgress < weaponProgress then
        self:pull('技能')
    else
        self:pull('技能')
        task.wait(0.05)
        self:pull('法宝')
    end
end

function LotteryController:start()
    Scheduler:ensure('lottery_v2', function(job)
        while job.enabled and State.settings.autoLottery do
            self:chooseAndPull()
            task.wait(self.speed)
        end
    end)
end

function LotteryController:stop()
    Scheduler:stop('lottery_v2')
end

local UpgradeController = {}

function UpgradeController:startFlyingSword()
    Scheduler:ensure('upgrade_flying_sword_v2', function(job)
        while job.enabled and State.settings.autoUpgradeFlyingSword do
            ActionThrottle:fireServer(
                'upgrade_flying_sword_v2',
                PathRegistry.Remotes.FlyingSwordUpgrade,
                0.18
            )
            task.wait(0.2)
        end
    end)
end

function UpgradeController:stopFlyingSword()
    Scheduler:stop('upgrade_flying_sword_v2')
end

function UpgradeController:startWeaponSkill()
    Scheduler:ensure('upgrade_weapon_skill_v2', function(job)
        while job.enabled and State.settings.autoUpgradeWeaponSkill do
            ActionThrottle:fireServer(
                'upgrade_weapon_all_v2',
                PathRegistry.Remotes.WeaponUpgradeAll,
                1
            )
            ActionThrottle:fireServer(
                'upgrade_skill_all_v2',
                PathRegistry.Remotes.SkillUpgradeAll,
                1
            )
            task.wait(1.5)
        end
    end)
end

function UpgradeController:stopWeaponSkill()
    Scheduler:stop('upgrade_weapon_skill_v2')
end

function UpgradeController:startRune()
    Scheduler:ensure('upgrade_rune_v2', function(job)
        while job.enabled and State.settings.autoUpgradeRune do
            ActionThrottle:fireServer(
                'upgrade_rune_v2',
                PathRegistry.Remotes.RuneUpgrade,
                0.18
            )
            task.wait(0.2)
        end
    end)
end

function UpgradeController:stopRune()
    Scheduler:stop('upgrade_rune_v2')
end

function UpgradeController:syncModes()
    if State.settings.autoUpgradeFlyingSword then
        self:startFlyingSword()
    else
        self:stopFlyingSword()
    end

    if State.settings.autoUpgradeWeaponSkill then
        self:startWeaponSkill()
    else
        self:stopWeaponSkill()
    end

    if State.settings.autoUpgradeRune then
        self:startRune()
    else
        self:stopRune()
    end
end

function UpgradeController:unlockWorldAndBuildings()
    local unlockRemote = PathRegistry.Events.Forge:FindFirstChild(Constants.Paths.UnlockBuilding)
    local buyRemote = PathRegistry.Remotes.ActivityBuy

    if unlockRemote then
        for index = 1, 30 do
            ActionThrottle:fireServer('unlock_building_' .. tostring(index), unlockRemote, 0.01, index)
        end
    end

    if buyRemote then
        for round = 1, 30 do
            ActionThrottle:fireServer(
                'unlock_buy_1_' .. tostring(round),
                buyRemote,
                0,
                1
            )
        end

        for round = 1, 40 do
            ActionThrottle:fireServer(
                'unlock_buy_12_' .. tostring(round),
                buyRemote,
                0,
                12
            )
        end
    end

    return unlockRemote ~= nil or buyRemote ~= nil
end

function UpgradeController:unequipAll()
    local runeRemote = PathRegistry.Events.Rune:FindFirstChild(Constants.Paths.Unequip)
    local worldRemote = PathRegistry.Events.WorldTree:FindFirstChild(Constants.Paths.Unequip)

    for index = 1, 5 do
        ActionThrottle:fireServer('unequip_rune_' .. tostring(index), runeRemote, 0.03, index)
        ActionThrottle:fireServer('unequip_world_' .. tostring(index), worldRemote, 0.03, index)
    end
end

local OverclockController = {}
OverclockController.selectionReadAttempts = 6
OverclockController.selectionReadDelay = 0.05

function OverclockController:openFarm(index)
    UiOpeners.openFarm(index)
    task.wait(0.15)
end

function OverclockController:openElixir()
    UiOpeners.openElixir()
    task.wait(0.15)
end

function OverclockController:readFarmLevel()
    local label = Utils.deepWait(PathRegistry.GUI.Secondary, {
        Constants.Paths.Farm,
        '背景',
        Constants.Paths.AttributeArea,
        '属性列表',
        '列表',
        '等级',
        '值',
    }, 2)
    return tonumber(label and label.Text and label.Text:match('%d+')) or 0
end

function OverclockController:readElixirLevel()
    local label = Utils.deepWait(PathRegistry.GUI.Secondary, {
        Constants.Paths.ElixirGui,
        '背景',
        Constants.Paths.AttributeArea,
        '属性列表',
        '列表',
        '等级',
        '值',
    }, 2)
    return tonumber(label and label.Text and label.Text:match('%d+')) or 0
end

function OverclockController:peekFarmLevel()
    local label = Utils.deepFind(PathRegistry.GUI.Secondary, {
        Constants.Paths.Farm,
        '背景',
        Constants.Paths.AttributeArea,
        '属性列表',
        '列表',
        '等级',
        '值',
    })
    return tonumber(label and label.Text and label.Text:match('%d+'))
end

function OverclockController:peekElixirLevel()
    local label = Utils.deepFind(PathRegistry.GUI.Secondary, {
        Constants.Paths.ElixirGui,
        '背景',
        Constants.Paths.AttributeArea,
        '属性列表',
        '列表',
        '等级',
        '值',
    })
    return tonumber(label and label.Text and label.Text:match('%d+'))
end

function OverclockController:readFarmLevelWithRetries()
    local level = 0
    for attempt = 1, self.selectionReadAttempts do
        level = self:readFarmLevel()
        if attempt < self.selectionReadAttempts then
            task.wait(self.selectionReadDelay)
        end
    end
    return level
end

function OverclockController:readElixirLevelWithRetries()
    local level = 0
    for attempt = 1, self.selectionReadAttempts do
        level = self:readElixirLevel()
        if attempt < self.selectionReadAttempts then
            task.wait(self.selectionReadDelay)
        end
    end
    return level
end

function OverclockController:refreshFarmSelection(index)
    local farmIndex = math.clamp(tonumber(index) or tonumber(State.settings.batch.selectedFarm) or 1, 1, 5)
    updateSetting({ 'batch', 'selectedFarm' }, farmIndex)
    self:openFarm(farmIndex)
    State.upgrade.farmCurrentLevel = self:readFarmLevelWithRetries()
    return State.upgrade.farmCurrentLevel
end

function OverclockController:refreshElixirSelection(index)
    local elixirIndex = math.max(1, tonumber(index) or tonumber(State.settings.batch.selectedElixir) or 1)
    updateSetting({ 'batch', 'selectedElixir' }, elixirIndex)
    self:openElixir()
    State.upgrade.elixirCurrentLevel = self:readElixirLevelWithRetries()
    return State.upgrade.elixirCurrentLevel
end

function OverclockController:runFarmBatch()
    Scheduler:start('farm_overclock_v2', function(job)
        for farmIndex = 1, 5 do
            if not job.enabled then
                break
            end

            self:openFarm(farmIndex)
            local currentLevel = self:readFarmLevel()
            State.upgrade.farmCurrentLevel = currentLevel
            local targetLevel = math.max(0, tonumber(State.settings.batch.farmTarget) or 80)
            local needed = math.max(0, targetLevel - currentLevel)

            for upgradeIndex = 1, needed do
                if not job.enabled then
                    break
                end

                ActionThrottle:fireServer(
                    ('farm_overclock_%d_%d'):format(farmIndex, upgradeIndex),
                    PathRegistry.Remotes.FarmUpgrade,
                    0,
                    farmIndex
                )

                if upgradeIndex % 10 == 0 then
                    task.wait(0.05)
                end
            end

            task.wait(0.05)
            State.upgrade.farmCurrentLevel = self:readFarmLevel()
        end

        self:refreshFarmSelection(State.settings.batch.selectedFarm or 1)
    end)
end

function OverclockController:runElixirBatch()
    Scheduler:start('elixir_overclock_v2', function(job)
        if not job.enabled then
            return
        end

        self:openElixir()
        local currentLevel = self:readElixirLevel()
        State.upgrade.elixirCurrentLevel = currentLevel
        local targetLevel = math.max(0, tonumber(State.settings.batch.elixirTarget) or 80)
        local needed = math.max(0, targetLevel - currentLevel)

        for upgradeIndex = 1, needed do
            if not job.enabled then
                break
            end

            ActionThrottle:fireServer(
                'elixir_overclock_' .. tostring(upgradeIndex),
                PathRegistry.Remotes.ElixirUpgrade,
                0
            )

            if upgradeIndex % 15 == 0 then
                task.wait(0.03)
            end
        end

        task.wait(0.05)
        State.upgrade.elixirCurrentLevel = self:readElixirLevel()
    end)
end

local FollowController = {
    range = 20,
    lostTimeout = 10,
}

function FollowController:getTargetPlayer()
    local name = tostring(State.settings.follow.selectedPlayer or '')
    if name == '' then
        return nil
    end
    return Services.Players:FindFirstChild(name)
end

function FollowController:isInRange(targetPlayer)
    local localRoot = RespawnService:getCharacterRoot()
    local targetRoot = targetPlayer
        and targetPlayer.Character
        and targetPlayer.Character:FindFirstChild('HumanoidRootPart')

    if not localRoot or not targetRoot then
        return false
    end

    return (localRoot.Position - targetRoot.Position).Magnitude <= self.range
end

function FollowController:requestTeleport(targetPlayer)
    return ActionThrottle:fireServer(
        'follow_teleport_' .. tostring(targetPlayer and targetPlayer.Name or 'nil'),
        PathRegistry.Remotes.AssistTeleport,
        1,
        targetPlayer
    )
end

function FollowController:triggerAssist()
    return ActionThrottle:fireServer(
        'follow_assist_v2',
        PathRegistry.Remotes.AssistTarget,
        0.5
    )
end

function FollowController:start()
    Scheduler:ensure('follow_player_v2', function(job)
        local state = 'seeking'
        local lostSince = nil
        local hasTriggeredCurrentLock = false
        local trackedName = nil

        while job.enabled and State.settings.follow.enabled do
            local targetPlayer = self:getTargetPlayer()
            local currentName = targetPlayer and targetPlayer.Name or ''

            if trackedName ~= currentName then
                trackedName = currentName
                state = 'seeking'
                lostSince = nil
                hasTriggeredCurrentLock = false
            end

            if not targetPlayer then
                task.wait(1)
            else
                local inRange = self:isInRange(targetPlayer)

                if state == 'seeking' then
                    if inRange then
                        if not hasTriggeredCurrentLock then
                            self:triggerAssist()
                            hasTriggeredCurrentLock = true
                        end
                        state = 'monitoring'
                        lostSince = nil
                    else
                        hasTriggeredCurrentLock = false
                        self:requestTeleport(targetPlayer)
                    end
                    task.wait(1)
                else
                    if inRange then
                        lostSince = nil
                    else
                        if not lostSince then
                            lostSince = time()
                        elseif time() - lostSince >= self.lostTimeout then
                            state = 'seeking'
                            lostSince = nil
                            hasTriggeredCurrentLock = false
                        end
                    end
                    task.wait(0.5)
                end
            end
        end
    end)
end

function FollowController:stop()
    Scheduler:stop('follow_player_v2')
end

function FollowController:sync()
    if State.settings.follow.enabled and tostring(State.settings.follow.selectedPlayer or '') ~= '' then
        self:start()
    else
        self:stop()
    end
end

local MonitorController = {}

function MonitorController:getCurrencyText(name)
    local label = Utils.deepWait(PathRegistry.GUI.Main, {
        Constants.Paths.MainCity,
        Constants.Paths.CurrencyAreaRight,
        name,
        '值',
    }, 2)
    return label and label.Text or '0'
end

function MonitorController:getHerbValue()
    return Utils.parseNumber(self:getCurrencyText('草药'))
end

function MonitorController:getOreValue()
    return Utils.parseNumber(self:getCurrencyText('矿石'))
end

function MonitorController:sendWebhook()
    local url = tostring(State.settings.monitor.webhookUrl or '')
    if url == '' then
        return false
    end

    local request = syn and syn.request or http and http.request or request
    if type(request) ~= 'function' then
        return false
    end

    local payload = {
        content = ('%s | 草药:%s | 矿石:%s'):format(
            player.Name,
            tostring(self:getHerbValue()),
            tostring(self:getOreValue())
        ),
    }

    local ok, response = pcall(function()
        return request({
            Url = url,
            Method = 'POST',
            Headers = {
                ['Content-Type'] = 'application/json',
            },
            Body = Services.HttpService:JSONEncode(payload),
        })
    end)

    return ok and response ~= nil
end

function MonitorController:start()
    Scheduler:ensure('smart_monitor_v2', function(job)
        while job.enabled and State.settings.monitor.enabled do
            local herbValue = self:getHerbValue()
            local oreValue = self:getOreValue()

            State.monitor.lastHerbValue = herbValue
            State.monitor.lastOreValue = oreValue

            if herbValue >= (tonumber(State.settings.monitor.highHerbThreshold) or 250000) then
                if not State.monitor.tradeTriggered then
                    State.monitor.tradeTriggered = true
                    if State.settings.monitor.autoTradeOnHighHerb then
                        MiscController:runTradeScript(2)
                    end
                    if State.settings.monitor.autoElixirOnHighHerb then
                        ElixirCraftController:enable('monitor')
                    end
                    if State.settings.monitor.webhookEnabled then
                        self:sendWebhook()
                    end
                end
            elseif herbValue <= (tonumber(State.settings.monitor.lowHerbThreshold) or 5000) then
                if State.monitor.tradeTriggered then
                    State.monitor.tradeTriggered = false
                    ElixirCraftController:disable('monitor')
                end
            end

            task.wait(5)
        end
    end)
end

function MonitorController:stop()
    Scheduler:stop('smart_monitor_v2')
    ElixirCraftController:disable('monitor')
end

function MonitorController:sync()
    if State.settings.monitor.enabled then
        self:start()
    else
        self:stop()
    end
end

local UiController = {}

function UiController:safeSet(control, value, name)
    if control and control.Set then
        control:Set(value)
        return
    end
    warn('[V2] 控件无法设置默认值: ' .. tostring(name))
end

function UiController:rebuildPlayerDropdown()
    if not State.ui.followDropdown then
        return
    end

    for _, option in ipairs(State.ui.followDropdownOptions or {}) do
        Utils.safePcall(function()
            option:Remove()
        end)
    end

    State.ui.followDropdownOptions = {}
    for _, otherPlayer in ipairs(Services.Players:GetPlayers()) do
        if otherPlayer ~= player then
            local option = State.ui.followDropdown:Add(otherPlayer.Name)
            if option then
                table.insert(State.ui.followDropdownOptions, option)
            end
        end
    end

    local blankOption = State.ui.followDropdown:Add('')
    if blankOption then
        table.insert(State.ui.followDropdownOptions, blankOption)
    end
end

function UiController:addDropdownSpacer(dropdown)
    if not dropdown or type(dropdown.Add) ~= 'function' then
        return nil
    end
    return dropdown:Add('')
end

function UiController:formatShortLevel(level)
    local number = math.max(0, tonumber(level) or 0)
    if number < 10 then
        return ('0%d'):format(number)
    end
    return tostring(number)
end

function UiController:updateDungeonDropdownTexts()
    if not State.ui.dungeonOptionMap then
        return
    end

    for name, option in pairs(State.ui.dungeonOptionMap) do
        local config = DungeonController.configs[name]
        local keys = tonumber(State.dungeon.keyCounts[name]) or 0
        if option and config then
            option.Text = ('%s  钥匙：%s'):format(
                config.zh,
                self:formatShortLevel(keys)
            )
        end
    end
end

function UiController:updateSummary()
    WorldController:getUnlockedLevel()
    DungeonController:refreshKeyCounts()
    LotteryController:refreshState()

    local farmCurrentLevel = OverclockController:peekFarmLevel()
    local elixirCurrentLevel = OverclockController:peekElixirLevel()
    if farmCurrentLevel then
        State.upgrade.farmCurrentLevel = farmCurrentLevel
    end
    if elixirCurrentLevel then
        State.upgrade.elixirCurrentLevel = elixirCurrentLevel
    end

    if State.ui.summaryLabel then
        State.ui.summaryLabel.Text = (
            'UTC+8: %s | Respawn: %s'
        ):format(
            State.daily.currentDateKey,
            tostring(RespawnService.pointName)
        )
    end

    if State.ui.dailyStatusLabel then
        State.ui.dailyStatusLabel.Text = (
            '在线奖励: %s | 收菜 D%s H%s C%s F%s | 旧每日缺失:%d'
        ):format(
            State.rewards.countdown and tostring(State.rewards.countdown) or '等待刷新',
            State.daily.donationFinished and '1' or '0',
            State.daily.herbBuyFinished and '1' or '0',
            State.daily.herbCollectFinished and '1' or '0',
            State.daily.farmReady and '1' or '0',
            LegacyDailyController:getMissingCount()
        )
    end

    if State.ui.safetyStatusLabel then
        State.ui.safetyStatusLabel.Text = (
            '安全模式: %s | 附近玩家: %d | 暂停: %s'
        ):format(
            State.settings.safetyMode and 'ON' or 'OFF',
            State.safety.nearbyPlayers,
            SafetyController:isPaused() and 'YES' or 'NO'
        )
    end

    if State.ui.worldStatusLabel then
        State.ui.worldStatusLabel.Text = (
            '世界: %s | 选中:%d | 已解锁:%d | 自动开始:%s | 75重进:%s'
        ):format(
            State.settings.world.mode,
            WorldController:getSelectedLevel(),
            State.world.unlocked,
            State.settings.world.autoStart and 'ON' or 'OFF',
            State.settings.world.autoReenter75 and 'ON' or 'OFF'
        )
    end

    if State.ui.worldLevelLabel then
        local selectedLevel = WorldController:getSelectedLevel()
        local unlockedLevel = State.world.unlocked
        if State.settings.world.mode == 'auto_highest' then
            State.ui.worldLevelLabel.Text = (
                '当前选择最高关卡：%s | 当前已解锁最高：%s'
            ):format(
                self:formatShortLevel(selectedLevel),
                self:formatShortLevel(unlockedLevel)
            )
        elseif selectedLevel > unlockedLevel then
            State.ui.worldLevelLabel.Text = (
                '关卡未解锁：%s | 当前已解锁最高：%s'
            ):format(
                self:formatShortLevel(selectedLevel),
                self:formatShortLevel(unlockedLevel)
            )
        else
            State.ui.worldLevelLabel.Text = (
                '当前选择关卡：%s | 当前已解锁最高：%s'
            ):format(
                self:formatShortLevel(selectedLevel),
                self:formatShortLevel(unlockedLevel)
            )
        end
    end

    if State.ui.dungeonStatusLabel then
        local config = DungeonController:getSelectedConfig()
        local keys = tonumber(State.dungeon.keyCounts[config.uiName]) or 0
        State.ui.dungeonStatusLabel.Text = (
            '地下城: %s | 钥匙:%d | 关卡:%d | 自动开始:%s'
        ):format(
            config.zh,
            keys,
            DungeonController:getSelectedLevel(),
            State.settings.dungeon.autoStart and 'ON' or 'OFF'
        )
    end

    if State.ui.dungeonLabel then
        local config = DungeonController:getSelectedConfig()
        local keys = tonumber(State.dungeon.keyCounts[config.uiName]) or 0
        State.ui.dungeonLabel.Text = (
            '当前选择：%s | 钥匙：%s | 关卡选择：%s'
        ):format(
            config.zh,
            self:formatShortLevel(keys),
            self:formatShortLevel(DungeonController:getSelectedLevel())
        )
    end

    if State.ui.worldAutoOption then
        State.ui.worldAutoOption.Text = (
            '自动最高关卡 [%s]'
        ):format(self:formatShortLevel(State.world.unlocked))
    end

    self:updateDungeonDropdownTexts()

    if State.ui.lotteryStatusLabel then
        State.ui.lotteryStatusLabel.Text = (
            '钻石:%d | 法宝券:%d | 技能券:%d | 自动抽:%s | 炼丹:%s'
        ):format(
            State.lottery.diamonds,
            State.lottery.swordTickets,
            State.lottery.skillTickets,
            State.settings.autoLottery and 'ON' or 'OFF',
            ElixirCraftController:isActive() and 'ON' or 'OFF'
        )
    end

    if State.ui.batchStatusLabel then
        State.ui.batchStatusLabel.Text = (
            '农田 当前/目标:%d/%d | 丹炉 当前/目标:%d/%d'
        ):format(
            tonumber(State.upgrade.farmCurrentLevel) or 0,
            tonumber(State.settings.batch.farmTarget) or 0,
            tonumber(State.upgrade.elixirCurrentLevel) or 0,
            tonumber(State.settings.batch.elixirTarget) or 0
        )
    end

    if State.ui.farmUpgradeLabel then
        State.ui.farmUpgradeLabel.Text = (
            '当前选择 农田：%s | 等级：%s | 目标：%s'
        ):format(
            self:formatShortLevel(State.settings.batch.selectedFarm or 1),
            self:formatShortLevel(State.upgrade.farmCurrentLevel or 0),
            self:formatShortLevel(State.settings.batch.farmTarget or 80)
        )
    end

    if State.ui.elixirUpgradeLabel then
        State.ui.elixirUpgradeLabel.Text = (
            '当前选择 丹炉：%s | 等级：%s | 目标：%s | 自动炼丹：%s'
        ):format(
            self:formatShortLevel(State.settings.batch.selectedElixir or 1),
            self:formatShortLevel(State.upgrade.elixirCurrentLevel or 0),
            self:formatShortLevel(State.settings.batch.elixirTarget or 80),
            State.settings.autoElixirCraft and '开启' or '关闭'
        )
    end

    if State.ui.monitorStatusLabel then
        State.ui.monitorStatusLabel.Text = (
            '草药:%d | 矿石:%d | 触发:%s'
        ):format(
            tonumber(State.monitor.lastHerbValue) or 0,
            tonumber(State.monitor.lastOreValue) or 0,
            State.monitor.tradeTriggered and 'YES' or 'NO'
        )
    end

    GuildController:updateDisplay()
end

function UiController:create()
    local library = ExternalAssets:loadModule(Constants.UILibraryUrl, 'ui_library')
    if type(library) ~= 'table' or type(library.AddWindow) ~= 'function' then
        warn('[V2] UI 库加载失败')
        return
    end

    local window = library:AddWindow('Cultivation Simulator V2', {
        main_color = Color3.fromRGB(46, 77, 122),
        min_size = Vector2.new(620, 360),
        can_resize = false,
    })

    local tabs = {
        overview = window:AddTab('总览'),
        daily = window:AddTab('每日'),
        world = window:AddTab('世界'),
        dungeon = window:AddTab('地下城'),
        guild = window:AddTab('公会'),
        lottery = window:AddTab('抽奖/丹药'),
        upgrade = window:AddTab('升级'),
        enhance = window:AddTab('强化'),
        interface = window:AddTab('界面'),
        tools = window:AddTab('工具'),
        follow = window:AddTab('跟随'),
        monitor = window:AddTab('监控'),
    }
    local controls = {}

    State.ui.summaryLabel = tabs.overview:AddLabel('V2 初始化中...')
    State.ui.dailyStatusLabel = tabs.overview:AddLabel('每日状态加载中...')
    State.ui.safetyStatusLabel = tabs.overview:AddLabel('安全状态读取中...')
    State.ui.worldStatusLabel = tabs.overview:AddLabel('世界状态读取中...')
    State.ui.dungeonStatusLabel = tabs.overview:AddLabel('地下城状态读取中...')
    State.ui.guildOverviewLabel = tabs.overview:AddLabel('公会信息读取中...')
    State.ui.lotteryStatusLabel = tabs.overview:AddLabel('抽奖状态读取中...')
    State.ui.batchStatusLabel = tabs.overview:AddLabel('升级状态读取中...')
    State.ui.monitorStatusLabel = tabs.overview:AddLabel('监控状态读取中...')

    controls.rewardsSwitch = tabs.daily:AddSwitch('自动在线奖励', function(value)
        updateSetting('autoOnlineRewards', value)
        if value then
            OnlineRewardController:start()
        else
            OnlineRewardController:stop()
        end
    end)

    controls.legacyDailySwitch = tabs.daily:AddSwitch('自动任务链路', function(value)
        updateSetting('autoLegacyDaily', value)
        if value then
            LegacyDailyController:start()
        else
            LegacyDailyController:stop()
        end
    end)

    controls.investSwitch = tabs.daily:AddSwitch('自动执行投资', function(value)
        updateSetting('autoInvest', value)
        if value then
            InvestmentController:start()
        else
            InvestmentController:stop()
        end
    end)

    controls.collectSwitch = tabs.daily:AddSwitch('自动采草药', function(value)
        updateSetting('autoCollectHerbs', value)
        if value then
            FarmController:start()
        else
            FarmController:stop()
        end
    end)

    controls.privilegeSwitch = tabs.daily:AddSwitch('解锁自动炼制', function(value)
        updateSetting('autoRefinePrivilege', value)
        PrivilegeController:apply()
    end)

    tabs.daily:AddButton('兑换礼品码', function()
        MiscController:redeemGiftCodes()
    end)
    tabs.daily:AddButton('删除奖励界面', function()
        MiscController:removeRewardUi()
    end)

    State.ui.worldLevelLabel = tabs.world:AddLabel('世界关卡准备中...')
    local worldDropdown = tabs.world:AddDropdown('选择世界关卡', function(text)
        if text and text:find('自动最高关卡', 1, true) then
            WorldController:setAutoHighest()
        else
            local level = tonumber((text or ''):match('(%d+)$'))
            if level then
                WorldController:setManualLevel(level)
            end
        end
        WorldController:syncModes()
    end)

    for _, preset in ipairs(WorldController.presets) do
        worldDropdown:Add(('世界关卡 %02d'):format(preset.level))
    end
    State.ui.worldAutoOption = worldDropdown:Add('自动最高关卡')
    self:addDropdownSpacer(worldDropdown)

    tabs.world:AddButton('关卡 +1', function()
        WorldController:setManualLevel(WorldController:getSelectedLevel() + 1)
        WorldController:syncModes()
    end)
    tabs.world:AddButton('关卡 -1', function()
        WorldController:setManualLevel(WorldController:getSelectedLevel() - 1)
        WorldController:syncModes()
    end)
    tabs.world:AddButton('传送世界关卡', function()
        WorldController:enterSelectedWorld()
    end)

    controls.worldAutoStartSwitch = tabs.world:AddSwitch('自动开始世界战斗', function(value)
        updateSetting({ 'world', 'autoStart' }, value)
        WorldController:syncModes()
    end)

    controls.worldReenterSwitch = tabs.world:AddSwitch('进度>75自动重进', function(value)
        updateSetting({ 'world', 'autoReenter75' }, value)
        WorldController:syncModes()
    end)

    tabs.world:AddButton('挂机模式', function()
        WorldController:toggleAutoBattle()
    end)

    State.ui.dungeonLabel = tabs.dungeon:AddLabel('地下城准备中...')
    local dungeonDropdown = tabs.dungeon:AddDropdown('选择地下城', function(text)
        for name, config in pairs(DungeonController.configs) do
            if text and text:find(config.zh, 1, true) then
                DungeonController:setSelected(name)
                break
            end
        end
    end)

    State.ui.dungeonOptionMap = {}
    for _, name in ipairs(DungeonController.dungeonOrder) do
        State.ui.dungeonOptionMap[name] = dungeonDropdown:Add(DungeonController.configs[name].zh)
    end
    self:addDropdownSpacer(dungeonDropdown)

    controls.dungeonSyncSwitch = tabs.dungeon:AddSwitch('同步地下城难度', function(value)
        updateSetting({ 'dungeon', 'autoSyncUi' }, value)
        DungeonController:syncModes()
    end)

    controls.dungeonAutoStartSwitch = tabs.dungeon:AddSwitch('自动开始地下城', function(value)
        updateSetting({ 'dungeon', 'autoStart' }, value)
        DungeonController:syncModes()
    end)

    controls.dungeonPlusOneSwitch = tabs.dungeon:AddSwitch('战斗结束关卡 +1', function(value)
        updateSetting({ 'dungeon', 'autoPlusOne' }, value)
        DungeonController:syncModes()
    end)

    controls.dungeonFinishAllSwitch = tabs.dungeon:AddSwitch('钥匙耗尽自动切换', function(value)
        updateSetting({ 'dungeon', 'autoFinishAll' }, value)
        DungeonController:syncModes()
    end)

    tabs.dungeon:AddTextBox('自订地下城关卡', function(text)
        local level = tonumber((tostring(text or '')):gsub('[^%d]', ''))
        if level then
            DungeonController:setSelectedLevel(level)
        end
    end)
    tabs.dungeon:AddButton('关卡 +1', function()
        DungeonController:adjustLevel(1)
    end)
    tabs.dungeon:AddButton('关卡 -1', function()
        DungeonController:adjustLevel(-1)
    end)
    tabs.dungeon:AddButton('传送地下城', function()
        DungeonController:enterSelected()
    end)

    controls.donateSwitch = tabs.guild:AddSwitch('自动公会捐献', function(value)
        updateSetting('autoDonate', value)
        if value then
            GuildController:startDonation()
        else
            Scheduler:stop('guild_donation_v2')
        end
    end)

    State.ui.guildInfoLabel = tabs.guild:AddLabel('公会信息读取中...')

    controls.guildShopSwitch = tabs.guild:AddSwitch('自动购买草药', function(value)
        updateSetting('autoGuildShop', value)
        if value then
            GuildController:startHerbShop()
        else
            Scheduler:stop('guild_shop_v2')
        end
    end)

    tabs.guild:AddButton('更新公会状态', function()
        GuildController:openGuildPanel()
        GuildController:updateDisplay()
        self:updateSummary()
    end)

    controls.autoLotterySwitch = tabs.lottery:AddSwitch('自动抽法宝/技能', function(value)
        updateSetting('autoLottery', value)
        if value then
            LotteryController:start()
        else
            LotteryController:stop()
        end
    end)

    controls.useDiamondsSwitch = tabs.lottery:AddSwitch('启用钻石抽取', function(value)
        updateSetting('useDiamondsForLottery', value)
    end)

    controls.autoElixirSwitch = tabs.lottery:AddSwitch('自动炼丹药', function(value)
        updateSetting('autoElixirCraft', value)
        ElixirCraftController:syncManualSetting()
    end)
    tabs.lottery:AddButton('自动交易初始化 1', function()
        MiscController:runTradeScript(1)
    end)
    tabs.lottery:AddButton('自动交易初始化 2', function()
        MiscController:runTradeScript(2)
    end)

    controls.flyingSwordSwitch = tabs.enhance:AddSwitch('升级飞剑', function(value)
        updateSetting('autoUpgradeFlyingSword', value)
        UpgradeController:syncModes()
    end)

    controls.weaponSkillSwitch = tabs.enhance:AddSwitch('升级法宝/技能', function(value)
        updateSetting('autoUpgradeWeaponSkill', value)
        UpgradeController:syncModes()
    end)

    controls.runeSwitch = tabs.enhance:AddSwitch('升级符石', function(value)
        updateSetting('autoUpgradeRune', value)
        UpgradeController:syncModes()
    end)

    controls.showAllSwitch = tabs.enhance:AddSwitch('显示所有货币', function(value)
        updateSetting('autoShowAllCurrency', value)
        if value then
            MiscController:startShowAllCurrencies()
        else
            MiscController:stopShowAllCurrencies()
        end
    end)

    tabs.enhance:AddButton('解锁世界与建筑', function()
        UpgradeController:unlockWorldAndBuildings()
    end)
    tabs.enhance:AddButton('解除装备', function()
        UpgradeController:unequipAll()
    end)

    State.ui.farmUpgradeLabel = tabs.upgrade:AddLabel('农田升级准备中...')
    local farmDropdown = tabs.upgrade:AddDropdown('选择农田', function(text)
        local index = tonumber((text or ''):match('(%d+)'))
        if index then
            OverclockController:refreshFarmSelection(index)
            self:updateSummary()
        end
    end)

    for index = 1, 5 do
        farmDropdown:Add('农田' .. tostring(index))
    end
    self:addDropdownSpacer(farmDropdown)

    tabs.upgrade:AddButton('农田目标 +1', function()
        updateSetting({ 'batch', 'farmTarget' }, math.min(200, (tonumber(State.settings.batch.farmTarget) or 80) + 1))
        self:updateSummary()
    end)
    tabs.upgrade:AddButton('农田目标 -1', function()
        updateSetting({ 'batch', 'farmTarget' }, math.max(0, (tonumber(State.settings.batch.farmTarget) or 80) - 1))
        self:updateSummary()
    end)
    tabs.upgrade:AddButton('农田升级', function()
        OverclockController:runFarmBatch()
    end)

    State.ui.elixirUpgradeLabel = tabs.upgrade:AddLabel('炼丹炉升级准备中...')
    local elixirDropdown = tabs.upgrade:AddDropdown('选择丹炉', function(text)
        local index = tonumber((text or ''):match('(%d+)'))
        if index then
            OverclockController:refreshElixirSelection(index)
            self:updateSummary()
        end
    end)
    elixirDropdown:Add('丹炉1')
    self:addDropdownSpacer(elixirDropdown)

    tabs.upgrade:AddButton('传送炼器台', function()
        RespawnService:teleportForge()
    end)
    tabs.upgrade:AddButton('丹炉目标 +1', function()
        updateSetting({ 'batch', 'elixirTarget' }, math.min(1000, (tonumber(State.settings.batch.elixirTarget) or 80) + 1))
        self:updateSummary()
    end)
    tabs.upgrade:AddButton('丹炉目标 -1', function()
        updateSetting({ 'batch', 'elixirTarget' }, math.max(0, (tonumber(State.settings.batch.elixirTarget) or 80) - 1))
        self:updateSummary()
    end)
    tabs.upgrade:AddButton('丹炉升级', function()
        OverclockController:runElixirBatch()
    end)

    controls.safetySwitch = tabs.tools:AddSwitch('安全模式', function(value)
        updateSetting('safetyMode', value)
    end)

    controls.blackScreenSwitch = tabs.tools:AddSwitch('黑幕开/关', function(value)
        updateSetting('blackScreen', value)
        SafetyController:setBlackScreen(value)
    end)

    tabs.tools:AddButton('刷新重生点', function()
        RespawnService:refresh(true)
    end)
    tabs.tools:AddButton('回家', function()
        RespawnService:teleportHome()
    end)
    tabs.tools:AddButton('关闭设置', function()
        MiscController:closeSettingsOnce()
    end)
    tabs.tools:AddButton('每月钥匙购买', function()
        MiscController:buyMonthlyKeys()
    end)
    tabs.tools:AddButton('每星期竞技场水滴购买', function()
        MiscController:buyArenaWater()
    end)
    tabs.tools:AddButton('删除语言配置', function()
        MiscController:deleteLanguageConfig()
    end)
    tabs.tools:AddButton('每秒击杀/金币数', function()
        MiscController:runStatsScript()
    end)
    tabs.tools:AddButton('测试每日重置', function()
        State.rewards.countdown = nil
        DailyResetService:force()
    end)

    tabs.interface:AddButton('开启每日任务', UiOpeners.openDailyTask)
    tabs.interface:AddButton('开启邮件', UiOpeners.openMail)
    tabs.interface:AddButton('开启转盘', UiOpeners.openSpin)
    tabs.interface:AddButton('开启阵法', UiOpeners.openRune)
    tabs.interface:AddButton('开启世界树', UiOpeners.openWorldTree)
    tabs.interface:AddButton('开启炼器台', UiOpeners.openForge)
    tabs.interface:AddButton('开启炼丹炉', UiOpeners.openElixir)
    tabs.interface:AddButton('开启农田', function()
        OverclockController:refreshFarmSelection(State.settings.batch.selectedFarm or 1)
        self:updateSummary()
    end)
    tabs.interface:AddButton('开启公会', function()
        GuildController:openGuildPanel()
    end)

    State.ui.followDropdown = tabs.follow:AddDropdown('选择玩家', function(selected)
        updateSetting({ 'follow', 'selectedPlayer' }, selected)
        FollowController:sync()
    end)
    State.ui.followDropdownOptions = {}
    self:rebuildPlayerDropdown()

    controls.followSwitch = tabs.follow:AddSwitch('传送玩家到副本', function(value)
        updateSetting({ 'follow', 'enabled' }, value)
        FollowController:sync()
    end)
    tabs.follow:AddButton('触发协助事件', function()
        FollowController:triggerAssist()
    end)

    controls.monitorSwitch = tabs.monitor:AddSwitch('智能草药监控', function(value)
        updateSetting({ 'monitor', 'enabled' }, value)
        MonitorController:sync()
    end)
    controls.monitorTradeSwitch = tabs.monitor:AddSwitch('高草药触发交易', function(value)
        updateSetting({ 'monitor', 'autoTradeOnHighHerb' }, value)
    end)
    controls.monitorElixirSwitch = tabs.monitor:AddSwitch('高草药触发炼丹', function(value)
        updateSetting({ 'monitor', 'autoElixirOnHighHerb' }, value)
    end)
    controls.webhookSwitch = tabs.monitor:AddSwitch('启用 Webhook', function(value)
        updateSetting({ 'monitor', 'webhookEnabled' }, value)
    end)
    tabs.monitor:AddTextBox('Webhook URL', function(text)
        updateSetting({ 'monitor', 'webhookUrl' }, tostring(text or ''))
    end)
    tabs.monitor:AddTextBox('高草药阈值', function(text)
        local value = tonumber((tostring(text or '')):gsub('[^%d]', ''))
        if value then
            updateSetting({ 'monitor', 'highHerbThreshold' }, value)
        end
    end)
    tabs.monitor:AddTextBox('低草药阈值', function(text)
        local value = tonumber((tostring(text or '')):gsub('[^%d]', ''))
        if value then
            updateSetting({ 'monitor', 'lowHerbThreshold' }, value)
        end
    end)
    tabs.monitor:AddButton('手动发送 Webhook', function()
        MonitorController:sendWebhook()
    end)

    self:safeSet(controls.rewardsSwitch, State.settings.autoOnlineRewards, 'rewardsSwitch')
    self:safeSet(controls.legacyDailySwitch, State.settings.autoLegacyDaily, 'legacyDailySwitch')
    self:safeSet(controls.investSwitch, State.settings.autoInvest, 'investSwitch')
    self:safeSet(controls.collectSwitch, State.settings.autoCollectHerbs, 'collectSwitch')
    self:safeSet(controls.privilegeSwitch, State.settings.autoRefinePrivilege, 'privilegeSwitch')
    self:safeSet(controls.worldAutoStartSwitch, State.settings.world.autoStart, 'worldAutoStartSwitch')
    self:safeSet(controls.worldReenterSwitch, State.settings.world.autoReenter75, 'worldReenterSwitch')
    self:safeSet(controls.dungeonSyncSwitch, State.settings.dungeon.autoSyncUi, 'dungeonSyncSwitch')
    self:safeSet(controls.dungeonAutoStartSwitch, State.settings.dungeon.autoStart, 'dungeonAutoStartSwitch')
    self:safeSet(controls.dungeonPlusOneSwitch, State.settings.dungeon.autoPlusOne, 'dungeonPlusOneSwitch')
    self:safeSet(controls.dungeonFinishAllSwitch, State.settings.dungeon.autoFinishAll, 'dungeonFinishAllSwitch')
    self:safeSet(controls.donateSwitch, State.settings.autoDonate, 'donateSwitch')
    self:safeSet(controls.guildShopSwitch, State.settings.autoGuildShop, 'guildShopSwitch')
    self:safeSet(controls.autoLotterySwitch, State.settings.autoLottery, 'autoLotterySwitch')
    self:safeSet(controls.useDiamondsSwitch, State.settings.useDiamondsForLottery, 'useDiamondsSwitch')
    self:safeSet(controls.autoElixirSwitch, State.settings.autoElixirCraft, 'autoElixirSwitch')
    self:safeSet(controls.flyingSwordSwitch, State.settings.autoUpgradeFlyingSword, 'flyingSwordSwitch')
    self:safeSet(controls.weaponSkillSwitch, State.settings.autoUpgradeWeaponSkill, 'weaponSkillSwitch')
    self:safeSet(controls.runeSwitch, State.settings.autoUpgradeRune, 'runeSwitch')
    self:safeSet(controls.showAllSwitch, State.settings.autoShowAllCurrency, 'showAllSwitch')
    self:safeSet(controls.safetySwitch, State.settings.safetyMode, 'safetySwitch')
    self:safeSet(controls.blackScreenSwitch, State.settings.blackScreen, 'blackScreenSwitch')
    self:safeSet(controls.followSwitch, State.settings.follow.enabled, 'followSwitch')
    self:safeSet(controls.monitorSwitch, State.settings.monitor.enabled, 'monitorSwitch')
    self:safeSet(controls.monitorTradeSwitch, State.settings.monitor.autoTradeOnHighHerb, 'monitorTradeSwitch')
    self:safeSet(controls.monitorElixirSwitch, State.settings.monitor.autoElixirOnHighHerb, 'monitorElixirSwitch')
    self:safeSet(controls.webhookSwitch, State.settings.monitor.webhookEnabled, 'webhookSwitch')

    Services.Players.PlayerAdded:Connect(function()
        self:rebuildPlayerDropdown()
    end)
    Services.Players.PlayerRemoving:Connect(function()
        self:rebuildPlayerDropdown()
    end)

    Scheduler:ensure('ui_summary_v2', function(job)
        while job.enabled do
            self:updateSummary()
            task.wait(1)
        end
    end)
end

local function enableAntiAfk()
    if not State.settings.autoAntiAfk then
        return
    end

    player.Idled:Connect(function()
        Services.VirtualUser:CaptureController()
        Services.VirtualUser:ClickButton2(Vector2.new())
        task.wait(2)
    end)
end

local function bootstrap()
    Utils.waitForLoadingGui()
    PathRegistry:init()
    RespawnService:refresh(false)
    SafetyController:start()
    SafetyController:setBlackScreen(State.settings.blackScreen)
    enableAntiAfk()
    DungeonController:startKeyWatcher()
    MiscController:closeSettingsOnce()
    PrivilegeController:apply()

    DailyResetService:register('guild_controller_v2', function()
        GuildController:onDailyReset()
    end)
    DailyResetService:register('farm_controller_v2', function()
        FarmController:onDailyReset()
    end)
    DailyResetService:register('rewards_controller_v2', function()
        State.rewards.countdown = nil
        if State.settings.autoOnlineRewards then
            OnlineRewardController:start()
        end
    end)
    DailyResetService:register('monitor_controller_v2', function()
        State.monitor.tradeTriggered = false
        ElixirCraftController:disable('monitor')
    end)

    UiController:create()

    if State.settings.autoOnlineRewards then
        OnlineRewardController:start()
    end
    if State.settings.autoLegacyDaily then
        LegacyDailyController:start()
    end
    if State.settings.autoInvest then
        InvestmentController:start()
    end
    if State.settings.autoDonate then
        GuildController:startDonation()
    end
    if State.settings.autoGuildShop then
        GuildController:startHerbShop()
    end
    if State.settings.autoCollectHerbs then
        FarmController:start()
    end
    if State.settings.autoShowAllCurrency then
        MiscController:startShowAllCurrencies()
    end
    if State.settings.autoRemoveRewardUi then
        MiscController:removeRewardUi()
    end
    if State.settings.autoLottery then
        LotteryController:start()
    end

    WorldController:syncModes()
    DungeonController:syncModes()
    UpgradeController:syncModes()
    ElixirCraftController:syncManualSetting()
    FollowController:sync()
    MonitorController:sync()

    DailyResetService:start()
    UiController:updateSummary()

    print('[V2] main_v2 已启动')
end

bootstrap()
