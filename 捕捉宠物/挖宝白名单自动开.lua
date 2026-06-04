--!nocheck
-- 挖宝白名单自动开_v2.lua
-- 基于完整破解的算法骨架:
--   FS-set: rawSeed = (fs + 500000) % 1_000_000, sc = fixed only
--   nil-FS: rawSeed = (user + refresh) % 200_000  ← 模数是 2e5! (sample1 验证69761 + sample6 N=0得170831)
--           sc = fixed + N filler (N=18 默认)
-- 算法流程:
--   rng = Random.new(rawSeed)
--   __DoRewardGroup(rng)
--   placementSeed = rng:NextInteger(1, 1e6)
--   placements = generateUniformChests(sc, Random.new(placementSeed))
-- 安全策略:
--   有 syncedMap → 必须验证通过才自动开
--   无 syncedMap (新刷新) → 先开 1 个探针 verify, 验证通过再开剩余白名单
-- 测试通过的样本: fs81191, fs876047 (18/18); fs265754 (17/18); dailyNil + current nil-FS

local TARGET_GAME_ID = 98664161516921
local TAG = "[TGAutoOpen]"
if game.PlaceId ~= TARGET_GAME_ID then warn(("%s 游戏ID不匹配"):format(TAG)) return end
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(3)

----------------------------------------------------------------
-- 配置
----------------------------------------------------------------
local CFG = {
    ACTIVITY_ID = 23,
    AUTO_OPEN = true,                  -- false=只预测不开
    OPEN_INTERVAL = 0.05,
    NIL_FS_FILLER_COUNT = 18,          -- nil-FS 的 N 默认值
    REQUIRE_SYNC_VERIFY = true,         -- true=有 syncedMap 必须验证才开
    USE_PROBE_IF_NO_SYNC = false,       -- (OPEN_ALL_PLACEMENTS 模式下不需要探针)
    PROBE_TMPL = 1,
    -- 全开模式: 忽略白名单/绑定, 按 placement 位置开所有 size>=MIN_SIZE 的位置
    OPEN_ALL_PLACEMENTS = true,         -- true=按 placement 位置全开 (推荐当 binding 不准时)
    OPEN_MIN_SIZE = 1,                  -- 只开 size>=N 的 placement (1=全部, 2=排除 size 1)
    -- 下面 WHITELIST 在 OPEN_ALL_PLACEMENTS=false 时才用
    WHITELIST = {[9]=true,[10]=true,[11]=true,[12]=true,[13]=true,[14]=true,
                 [15]=true,[16]=true,[17]=true,[18]=true,[19]=true,[20]=true,
                 [21]=true,[22]=true,[23]=true,[24]=true},
    EXTRA_TMPLS = {[3]=true,[4]=true,[5]=true,[6]=true},
    OPEN_EXTRA = false,
}

----------------------------------------------------------------
-- 工具
----------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local function log(fmt, ...) print(("%s " .. fmt):format(TAG, ...)) end
local function warnf(fmt, ...) warn(("%s " .. fmt):format(TAG, ...)) end

local function findPath(root, parts)
    local n = root
    for _, name in ipairs(parts) do
        if not n then return nil end
        n = n:FindFirstChild(name)
    end
    return n
end

local RewardSystem = require(findPath(ReplicatedStorage, {"CommonLibrary","Foundation","RewardSystem"}))
local CfgActivity = require(findPath(ReplicatedStorage, {"CommonConfig","Activity","CfgActivity"}))
local ClientPlayerManager = require(findPath(ReplicatedStorage, {"CommonLibrary","Player","ClientPlayerManager"}))
local Utils = require(findPath(ReplicatedStorage, {"CommonLibrary","Tool","Utils"}))
local ActivityTreasureGridSystem = require(findPath(ReplicatedStorage, {"CommonLogic","Activity","ActivityTreasureGridSystem"}))
local ViewUtil = require(findPath(ReplicatedStorage, {"ClientLogic","View","ViewUtil"}))

local function getGP()
    local s = os.clock()
    while os.clock() - s < 30 do
        local ok, gp = pcall(ClientPlayerManager.GetGamePlayer)
        if ok and gp then return gp end
        task.wait(0.1)
    end
    error(TAG .. " GamePlayer 未找到")
end

local function safeCall(gp, m, ...)
    if not gp or not gp.activity then return false end
    local f = gp.activity[m]; if type(f) ~= "function" then return false end
    return pcall(f, gp.activity, ...)
end

local gp = getGP()
safeCall(gp, "TreasureGridGetTreasureMap", CFG.ACTIVITY_ID)
task.wait(0.8)

----------------------------------------------------------------
-- 读取活动状态
----------------------------------------------------------------
local actCfg = CfgActivity.TmplMap[CFG.ACTIVITY_ID]
local eftCfg = actCfg.Effects.TreasureGrid
local Rand = eftCfg.Rand
local Tmpls = eftCfg.Tmpls
local ROW_COUNT, COL_COUNT = eftCfg.MapRowCount, eftCfg.MapColCount

if actCfg.StartTime == nil and actCfg.StartDate then
    actCfg.StartTime = Utils.GetServerTimeFromStr(actCfg.StartDate)
end

local function calcRefreshTick(t)
    local sum = t - actCfg.StartTime
    local rt = eftCfg.DailyRefreshTime; local sp = eftCfg.DailyRefreshSpan or 86400
    local cyc = math.floor(sum / sp)
    if cyc > 0 then sum = sum - cyc * sp end
    local cs = t - sum
    for i, v in ipairs(rt) do
        if sum < v then break end
        local nxt = i < #rt and rt[i+1] or sp
        if sum < nxt then return cs + v end
    end
    return cs - sp + rt[#rt]
end

local serverTime = Workspace:GetServerTimeNow()
local refreshTick = calcRefreshTick(serverTime)
local userId = Players.LocalPlayer.UserId
local fs = nil
local okSeed, sv = safeCall(gp, "TreasureGridGetCustomRefreshSeed", CFG.ACTIVITY_ID)
if okSeed then fs = sv end

local function mod1e6(v) return ((v % 1000000) + 1000000) % 1000000 end
local function mod2e5(v) return ((v % 200000) + 200000) % 200000 end

local rawSeed, formulaName
if fs and fs ~= 0 then
    rawSeed = mod1e6(fs + 500000)
    formulaName = "FS-set: (fs+500000)%1e6"
else
    -- 已确认: rawSeed = (user + refresh) % 200000  ← 模数是 2e5(20万)!
    -- sample1 (11/11验证) =69761, sample6 (N=0多格)=170831, 两点唯一确定 M=200000
    rawSeed = mod2e5(userId + refreshTick)
    formulaName = "nil-FS: (user+refresh)%2e5"
end

log("状态: fs=%s user=%d refresh=%d", tostring(fs), userId, refreshTick)
log("公式: %s → rawSeed=%d", formulaName, rawSeed)

----------------------------------------------------------------
-- 算法核心
----------------------------------------------------------------
local function gen(sizeCounts, random)
    local occupied, dW, nW = {}, {}, {}
    for r=1,ROW_COUNT do occupied[r],dW[r],nW[r]={},{},{}
        for c=1,COL_COUNT do occupied[r][c],dW[r][c],nW[r][c]=false,0,0 end end
    for size,count in pairs(sizeCounts) do if size>0 and count>0 then
        local mSR,mSC=ROW_COUNT-size+1,COL_COUNT-size+1
        if mSR<1 or mSC<1 then return nil end
        for r=1,ROW_COUNT do for c=1,COL_COUNT do
            local minR,maxR=math.max(1,r-size+1),math.min(r,mSR)
            local minC,maxC=math.max(1,c-size+1),math.min(c,mSC)
            dW[r][c]+=math.max(0,maxR-minR+1)*math.max(0,maxC-minC+1)*count
        end end
    end end
    local sizes={}
    for size,count in pairs(sizeCounts) do for _=1,count do table.insert(sizes,size) end end
    table.sort(sizes, function(a,b) return b<a end)
    local function maxSq()
        local dp,mx={},0
        for r=1,ROW_COUNT do dp[r]={}
            for c=1,COL_COUNT do
                if occupied[r][c] then dp[r][c]=0 else
                    local v=(r==1 or c==1) and 1 or math.min(dp[r-1][c],dp[r][c-1],dp[r-1][c-1])+1
                    dp[r][c]=v; if mx<v then mx=v end
                end
            end
        end
        return mx
    end
    local placements={}
    for idx,size in ipairs(sizes) do
        local maxSC=COL_COUNT-size+1; local nextSize=sizes[idx+1] or 0
        local cands={}
        for r=1,ROW_COUNT-size+1 do for c=1,maxSC do
            local blk,w=false,0
            for tr=r,r+size-1 do for tc=c,c+size-1 do
                if occupied[tr][tc] then blk=true;break end
                w+=1/(dW[tr][tc]+nW[tr][tc]+1)
            end; if blk then break end end
            if not blk then table.insert(cands,{r=r,c=c,weight=w}) end
        end end
        if #cands==0 then return nil end
        local sel=nil
        while #cands>0 do
            local ws=0; for _,x in ipairs(cands) do ws+=x.weight end
            local roll=random:NextNumber()*ws; local run,si=0,0
            for ci,x in ipairs(cands) do run+=x.weight; if roll<=run then si=ci;break end end
            if si==0 then si=#cands end
            local c=cands[si]; local can=true
            if nextSize>0 then
                for rr=c.r,c.r+size-1 do for cc=c.c,c.c+size-1 do occupied[rr][cc]=true end end
                if maxSq()<nextSize then can=false end
                for rr=c.r,c.r+size-1 do for cc=c.c,c.c+size-1 do occupied[rr][cc]=false end end
            end
            if can then sel=c; break end
            table.remove(cands,si)
        end
        if not sel then return nil end
        table.insert(placements,{r=sel.r,c=sel.c,size=size})
        for r=sel.r,sel.r+size-1 do for c=sel.c,sel.c+size-1 do
            occupied[r][c]=true
            for dr=-1,1 do for dc=-1,1 do
                local nr,nc=r+dr,c+dc
                if nr>=1 and nr<=ROW_COUNT and nc>=1 and nc<=COL_COUNT then nW[nr][nc]+=2 end
            end end
        end end
    end
    return placements
end

-- 多种排序候选, 自动选 syncedVerify 最高的
local SORT_MODES = {
    {name="size_desc_tmpl_asc", fn=function(a,b)
        if a.size ~= b.size then return a.size > b.size end
        return a.tmpl < b.tmpl
    end},
    {name="size_desc_draw_order", fn=function(a,b)
        if a.size ~= b.size then return a.size > b.size end
        return a.drawIndex < b.drawIndex
    end},
    {name="draw_order", fn=function(a,b)
        return a.drawIndex < b.drawIndex
    end},
    {name="size_desc_tmpl_desc", fn=function(a,b)
        if a.size ~= b.size then return a.size > b.size end
        return a.tmpl > b.tmpl
    end},
}

local function predictWithSort(sortFn, fillerN)
    local rng = Random.new(rawSeed)
    local rl = {}
    pcall(function() RewardSystem.__DoRewardGroup(nil, Rand, rl, rng, false, true) end)
    local fixedRewards = {}
    for di, r in ipairs(rl) do
        if r.TmplId and r.TmplId ~= 1000 then
            local tm = Tmpls[r.TmplId]
            if tm then
                table.insert(fixedRewards, {tmpl=r.TmplId, size=tm.Size, config=tm, drawIndex=di})
            end
        end
    end
    local sc = {}
    for _, r in ipairs(fixedRewards) do sc[r.size] = (sc[r.size] or 0) + 1 end
    if not fs or fs == 0 then
        sc[1] = (sc[1] or 0) + (fillerN or CFG.NIL_FS_FILLER_COUNT)
    end
    local placementSeed = rng:NextInteger(1, 1000000)
    local placements = gen(sc, Random.new(placementSeed))
    if not placements then return nil, placementSeed, nil end
    table.sort(fixedRewards, sortFn)
    local map = {}
    for i, p in ipairs(placements) do
        local fr = fixedRewards[i]
        if fr then
            map[fr.tmpl] = {
                tmpl=fr.tmpl, row=p.r, col=p.c, size=p.size,
                config=fr.config, reward=fr.config.Reward,
            }
        end
    end
    return map, placementSeed, placements
end

-- 试所有 sort modes, 选验证最高的
local function getSync()
    local ok, m = safeCall(gp, "TreasureGridGetTreasureMap", CFG.ACTIVITY_ID)
    return ok and type(m) == "table" and m or {}
end

local function quickValidate(predMap)
    local synced = getSync()
    local hit, checked = 0, 0
    for _, st in pairs(synced) do
        if type(st) == "table" and st.TmplId and st.TmplId ~= 1000 then
            checked += 1
            local p = predMap[st.TmplId]
            if p and p.row == st.Row and p.col == st.Col then hit += 1 end
        end
    end
    return hit, checked
end

local predMap, placementSeed, rawPlacements
local bestSortName, bestN = "default", 0
do
    -- N 恒为 0: filler(1000) 是 post-fill 独立步骤, 不进 placement 计算.
    -- sample6 用正确 rawSeed(170831) 时 N=0 即匹配, 证明固定奖励就该 N=0.
    -- 只 brute sort (影响 tmpl 绑定显示), N 不再暴搜 (避免少格时撞错 N 开空格).
    local nRange = {0}
    local bestHit, bestChecked = -1, 0
    local startC = os.clock()
    local tried = 0
    for _, sm in ipairs(SORT_MODES) do
        for _, n in ipairs(nRange) do
            tried += 1
            local m, ps, pl = predictWithSort(sm.fn, n)
            if m then
                local h, c = quickValidate(m)
                if h > bestHit then
                    bestHit = h; bestChecked = c
                    predMap = m; placementSeed = ps; rawPlacements = pl
                    bestSortName = sm.name; bestN = n
                    log("  new best: sort=%s N=%d verify=%d/%d", sm.name, n, h, c)
                end
                if h == c and c > 0 then break end  -- 完美命中, 不必继续
            end
        end
        -- 如果已经完美命中, 跳出外层
        if bestHit == bestChecked and bestChecked > 0 then break end
    end
    log("选用: sort=%s N=%d best=%d/%d (tried %d combos, %.2fs)",
        bestSortName, bestN, bestHit, bestChecked, tried, os.clock()-startC)
end

-- 用 placement 集合直接做位置级验证 (不依赖 tmpl 绑定, 只看会被开的 size)
local function validateByPlacementSet(placements, minSize)
    if not placements then return 0, 0 end
    minSize = minSize or 1
    local synced = getSync()
    local posBySize = {}
    for _, p in ipairs(placements) do
        if p.size >= minSize then
            posBySize[p.size] = posBySize[p.size] or {}
            posBySize[p.size][("%d_%d"):format(p.r, p.c)] = true
        end
    end
    local hit, checked = 0, 0
    for _, st in pairs(synced) do
        if type(st) == "table" and st.TmplId and st.TmplId ~= 1000 then
            local tm = Tmpls[st.TmplId]
            if tm and tm.Size >= minSize then  -- 只校验会被开的 size
                checked += 1
                local key = ("%d_%d"):format(st.Row, st.Col)
                if posBySize[tm.Size] and posBySize[tm.Size][key] then hit += 1 end
            end
        end
    end
    return hit, checked
end

local placementHit, placementChecked = validateByPlacementSet(rawPlacements,
    CFG.OPEN_ALL_PLACEMENTS and CFG.OPEN_MIN_SIZE or 1)
log("placement 位置集合验证 (size>=%d, 不看 tmpl): %d/%d",
    CFG.OPEN_ALL_PLACEMENTS and CFG.OPEN_MIN_SIZE or 1, placementHit, placementChecked)
if not predMap then warnf("预测失败"); return end
log("placementSeed=%d, 预测 %d 个固定奖励",
    placementSeed, (function() local c=0; for _ in pairs(predMap) do c+=1 end; return c end)())

----------------------------------------------------------------
-- 验证 + 打印
----------------------------------------------------------------
local function getSync()
    local ok, m = safeCall(gp, "TreasureGridGetTreasureMap", CFG.ACTIVITY_ID)
    return ok and type(m) == "table" and m or {}
end

local function validate(predMap)
    local synced = getSync()
    local hit, miss, checked = 0, {}, 0
    for _, st in pairs(synced) do
        if type(st) == "table" and st.TmplId and st.TmplId ~= 1000 then
            checked += 1
            local p = predMap[st.TmplId]
            if p and p.row == st.Row and p.col == st.Col then
                hit += 1
            else
                table.insert(miss, {tmpl=st.TmplId, synced=("%d,%d"):format(st.Row, st.Col),
                                    predicted=p and ("%d,%d"):format(p.row, p.col) or "nil"})
            end
        end
    end
    return hit, checked, miss
end

local hit, checked, miss = validate(predMap)
log("\n========== 验证 ==========")
if checked == 0 then
    log("无已开 fixed 格子, 无法验证 (新刷新状态)")
else
    log("syncedVerify = %d/%d", hit, checked)
    for _, m in ipairs(miss) do
        log("  MISS tmpl=%d synced=(%s) predicted=(%s)", m.tmpl, m.synced, m.predicted)
    end
end

----------------------------------------------------------------
-- 打印预测
----------------------------------------------------------------
local function formatReward(r)
    if type(r) ~= "table" then return tostring(r) end
    local cnt = r.Count and (" x"..r.Count) or ""
    if r.RewardRes == "Value" then return ("Value %s%s"):format(tostring(r.ValueType), cnt) end
    return ("%s#%s%s"):format(tostring(r.RewardRes), tostring(r.TmplId), cnt)
end

log("\n========== 白名单预测 ==========")
local whitelistList = {}
for tmpl, t in pairs(predMap) do
    if CFG.WHITELIST[tmpl] then table.insert(whitelistList, t) end
end
table.sort(whitelistList, function(a, b)
    if a.size ~= b.size then return a.size > b.size end
    return a.tmpl < b.tmpl
end)
for _, t in ipairs(whitelistList) do
    log("tmpl=%-3d size=%dx%d (%d,%d) reward=%s",
        t.tmpl, t.size, t.size, t.row, t.col, formatReward(t.reward))
end

-- 文本地图
log("\n--- 地图 (W=白名单, X=已 synced fixed, F=已 synced filler, .=空) ---")
local synced = getSync()
local syncedFixedSet, syncedFillerSet = {}, {}
for _, st in pairs(synced) do
    if type(st) == "table" and st.TmplId then
        if st.TmplId == 1000 then
            syncedFillerSet[("%d_%d"):format(st.Row, st.Col)] = true
        else
            local tm = Tmpls[st.TmplId]
            if tm then
                for r=st.Row, st.Row+tm.Size-1 do for c=st.Col, st.Col+tm.Size-1 do
                    syncedFixedSet[("%d_%d"):format(r, c)] = true
                end end
            end
        end
    end
end
local grid = {}
for r=1,ROW_COUNT do grid[r]={}; for c=1,COL_COUNT do grid[r][c]="." end end
for _, t in ipairs(whitelistList) do
    for r=t.row, t.row+t.size-1 do for c=t.col, t.col+t.size-1 do
        if grid[r] then grid[r][c] = "W" end
    end end
end
for cell in pairs(syncedFixedSet) do
    local r, c = cell:match("(%d+)_(%d+)")
    if grid[tonumber(r)] then grid[tonumber(r)][tonumber(c)] = "X" end
end
for cell in pairs(syncedFillerSet) do
    local r, c = cell:match("(%d+)_(%d+)")
    if grid[tonumber(r)] then grid[tonumber(r)][tonumber(c)] = "F" end
end
for r=1,ROW_COUNT do log("%02d: %s", r, table.concat(grid[r], " ")) end

----------------------------------------------------------------
-- 安全门 + 自动开
----------------------------------------------------------------
local function isClaimed(tmpl)
    local ok, c = safeCall(gp, "TreasureGridIsRewardClaimed", CFG.ACTIVITY_ID, tmpl)
    return ok and c
end
local function isCellOpened(r, c)
    local ok, opened = safeCall(gp, "TreasureGridIsCellOpened", CFG.ACTIVITY_ID, r, c)
    return ok and opened
end

local function openCell(r, c)
    local ok, result = pcall(ViewUtil.DoRequest, ActivityTreasureGridSystem.ClientOpenCell, CFG.ACTIVITY_ID, r, c)
    return ok and result, result
end

local function openTreasure(t)
    log("开 tmpl=%s size=%dx%d (%d,%d) reward=%s",
        tostring(t.tmpl), t.size, t.size, t.row, t.col, formatReward(t.reward))
    for r=t.row, t.row+t.size-1 do
        for c=t.col, t.col+t.size-1 do
            if isCellOpened(r, c) then
                log("  (%d,%d) 已开, 跳过", r, c)
            else
                local ok, result = openCell(r, c)
                if ok then
                    log("  opened (%d,%d)", r, c)
                else
                    warnf("  开格失败 (%d,%d): %s", r, c, tostring(result))
                    return false
                end
                task.wait(CFG.OPEN_INTERVAL)
            end
        end
    end
    return true
end

if not CFG.AUTO_OPEN then
    log("\nAUTO_OPEN=false, 不自动开. 看上面预测自己开.")
    return
end

log("\n========== 自动开判定 ==========")

-- 安全策略 (OPEN_ALL_PLACEMENTS 模式用 placementHit/placementChecked, 不看 tmpl 绑定)
local useHit, useChecked
if CFG.OPEN_ALL_PLACEMENTS then
    useHit, useChecked = placementHit, placementChecked
    log("(全开模式: 用位置集合验证, hit=%d/%d)", useHit, useChecked)
else
    useHit, useChecked = hit, checked
end

if CFG.REQUIRE_SYNC_VERIFY and useChecked > 0 then
    if useHit ~= useChecked then
        warnf("有 syncedMap 但验证未满分 (%d/%d), 不自动开. 公式可能不适用本张地图.", useHit, useChecked)
        return
    end
    log("验证通过 (%d/%d), 进入自动开格", useHit, useChecked)
elseif useChecked == 0 and CFG.USE_PROBE_IF_NO_SYNC then
    -- 没 sync, 用 1 个探针验证
    local probe = predMap[CFG.PROBE_TMPL]
    if not probe then
        warnf("没 sync 且找不到 tmpl=%d 作探针, 不自动开", CFG.PROBE_TMPL)
        return
    end
    log("无 sync 数据, 先开 probe: tmpl=%d (%d,%d)", probe.tmpl, probe.row, probe.col)
    local ok, result = openCell(probe.row, probe.col)
    if not ok then warnf("探针开格失败: %s", tostring(result)); return end
    task.wait(0.5)
    -- 重新验证
    local hit2, checked2, miss2 = validate(predMap)
    if checked2 == 0 then
        warnf("探针后仍无 sync 数据, 异常, 不继续开")
        return
    end
    if hit2 ~= checked2 then
        warnf("探针验证失败 (%d/%d), 公式不适用本张地图, 停止", hit2, checked2)
        return
    end
    log("探针验证通过 (%d/%d), 继续自动开", hit2, checked2)
end

local opened = 0

if CFG.OPEN_ALL_PLACEMENTS then
    -- 全开模式: 按 placement 位置直接开, 不看 tmpl 绑定
    -- 按 size desc 排, 大的先开
    local sortedPlacements = {}
    for _, p in ipairs(rawPlacements or {}) do
        if p.size >= CFG.OPEN_MIN_SIZE then
            table.insert(sortedPlacements, p)
        end
    end
    table.sort(sortedPlacements, function(a, b) return a.size > b.size end)
    log("全开 %d 个 placement (size >= %d)", #sortedPlacements, CFG.OPEN_MIN_SIZE)
    for _, p in ipairs(sortedPlacements) do
        local t = {tmpl="?", row=p.r, col=p.c, size=p.size,
                   reward={RewardRes="Placement", TmplId="size"..p.size}}
        if openTreasure(t) then opened += 1 else break end
    end
else
    -- 白名单模式
    for _, t in ipairs(whitelistList) do
        if not isClaimed(t.tmpl) then
            if openTreasure(t) then opened += 1 else break end
        else
            log("跳过已领: tmpl=%d", t.tmpl)
        end
    end

    if CFG.OPEN_EXTRA then
        log("\n========== 开 EXTRA tmpls ==========")
        for tmpl, t in pairs(predMap) do
            if CFG.EXTRA_TMPLS[tmpl] and not isClaimed(tmpl) then
                if not openTreasure(t) then break end
                opened += 1
            end
        end
    end
end

log("\n========== 完成. 开了 %d 个 treasure ==========", opened)
