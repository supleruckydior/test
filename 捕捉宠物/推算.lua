--!nocheck
-- 挖宝白名单_现场brute.lua
-- 不依赖任何预先推导的 seed 公式. 当场暴搜 rawSeed.
-- 用法:
--   1. 进入挖宝活动后, 手动开 >=3 格 (任意位置, 推荐 size>=2 的大格便宜)
--   2. 跑此脚本, brute rawSeed 1..1e6 × N ∈ {0,10,12,14,16,18,20,22,24}
--   3. 命中后自动 全开 剩余 placement 位置
-- 同时把 (user, refresh, fs, rawSeed) 打印出来, 方便积累样本反推公式

local TARGET_GAME_ID = 98664161516921
local TAG = "[TGBrute]"
if game.PlaceId ~= TARGET_GAME_ID then warn(("%s 游戏ID不匹配"):format(TAG)) return end
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(2)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ACTIVITY_ID = 23
local MIN_SYNCED_FIXED = 3        -- 至少需要这么多 syncedFixed 才允许 brute
local N_RANGE = {0, 10, 12, 14, 16, 18, 20, 22, 24}
local OPEN_DELAY = 0.4
local OPEN_ALL_AFTER_HIT = true

local function log(fmt, ...) print(("%s " .. fmt):format(TAG, ...)) end
local function findPath(root, parts)
    local n = root; for _, name in ipairs(parts) do if not n then return nil end; n = n:FindFirstChild(name) end; return n
end

local RewardSystem = require(findPath(ReplicatedStorage, {"CommonLibrary","Foundation","RewardSystem"}))
local CfgActivity = require(findPath(ReplicatedStorage, {"CommonConfig","Activity","CfgActivity"}))
local Constants = require(findPath(ReplicatedStorage, {"CommonLibrary","Constants"}))
local ClientPlayerManager = require(findPath(ReplicatedStorage, {"CommonLibrary","Player","ClientPlayerManager"}))

local function getGP()
    local s = os.clock()
    while os.clock() - s < 30 do
        local ok, gp = pcall(ClientPlayerManager.GetGamePlayer)
        if ok and gp then return gp end
        task.wait(0.1)
    end
    error("no gp")
end
local function safeCall(gp, m, ...)
    if not gp or not gp.activity then return false end
    local f = gp.activity[m]; if type(f) ~= "function" then return false end
    return pcall(f, gp.activity, ...)
end

local gp = getGP()
safeCall(gp, "TreasureGridGetTreasureMap", ACTIVITY_ID)
task.wait(0.8)

local actCfg = CfgActivity.TmplMap[ACTIVITY_ID]
local eftCfg = actCfg.Effects.TreasureGrid
local Rand, Tmpls = eftCfg.Rand, eftCfg.Tmpls
local ROW_COUNT, COL_COUNT = eftCfg.MapRowCount, eftCfg.MapColCount
local RED = Constants.ItemQuality.Red

local userId = (gp.basicData and gp.basicData.UserId) or game.Players.LocalPlayer.UserId or 0
local _, refreshTick = safeCall(gp, "TreasureGridGetRefreshTick", ACTIVITY_ID)
refreshTick = refreshTick or 0
local _, fs = safeCall(gp, "TreasureGridGetFreshSeed", ACTIVITY_ID)
if type(fs) ~= "number" then fs = nil end

local _, syncedMap = safeCall(gp, "TreasureGridGetTreasureMap", ACTIVITY_ID)
syncedMap = syncedMap or {}
local _, highList = safeCall(gp, "TreasureGridGetHighQualityUnclaimedTreasureTmplIdList", ACTIVITY_ID)
highList = highList or {}

local syncedFixed, syncedFillerSet = {}, {}
for _, t in pairs(syncedMap) do
    if type(t) == "table" and t.TmplId then
        if t.TmplId ~= 1000 then
            local tm = Tmpls[t.TmplId]
            if tm then syncedFixed[t.TmplId] = {row=t.Row, col=t.Col, size=tm.Size} end
        else
            syncedFillerSet[t.Row.."_"..t.Col] = true
        end
    end
end

local expectedReds = {}
for _, t in ipairs(highList) do expectedReds[t] = true end
for tmpl in pairs(Tmpls) do
    if Tmpls[tmpl].Quality == RED then
        local ok, c = safeCall(gp, "TreasureGridIsRewardClaimed", ACTIVITY_ID, tmpl)
        if ok and c then expectedReds[tmpl] = true end
    end
end
local expectedRedCount = 0
for _ in pairs(expectedReds) do expectedRedCount += 1 end

local syncedFixedCount = 0; for _ in pairs(syncedFixed) do syncedFixedCount += 1 end
local syncedFillerCount = 0; for _ in pairs(syncedFillerSet) do syncedFillerCount += 1 end

log("user=%s refresh=%s fs=%s", tostring(userId), tostring(refreshTick), tostring(fs))
log("syncedFixed=%d syncedFiller=%d expectedReds=%d", syncedFixedCount, syncedFillerCount, expectedRedCount)
for tmpl, st in pairs(syncedFixed) do log("  syncedFixed tmpl=%d size=%d (%d,%d)", tmpl, st.size, st.row, st.col) end

if syncedFixedCount < MIN_SYNCED_FIXED then
    log("syncedFixed 不足 %d 个, 无法 brute. 请手动开 %d-5 格再跑.", MIN_SYNCED_FIXED, MIN_SYNCED_FIXED)
    return
end

-- generateUniformChests
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

local function evalSeedN(rawSeed, N)
    local rng = Random.new(rawSeed)
    local rl = {}
    pcall(function() RewardSystem.__DoRewardGroup(nil, Rand, rl, rng, false, true) end)
    local drawnReds, fixedSizeCounts = {}, {}
    for _, r in ipairs(rl) do
        if r.TmplId and r.TmplId ~= 1000 then
            local tm = Tmpls[r.TmplId]
            if tm then
                fixedSizeCounts[tm.Size] = (fixedSizeCounts[tm.Size] or 0) + 1
                if tm.Quality == RED then drawnReds[r.TmplId] = true end
            end
        end
    end
    -- reds 过滤
    local rc = 0
    for t in pairs(drawnReds) do if not expectedReds[t] then return nil end; rc += 1 end
    if rc ~= expectedRedCount then return nil end
    local sc = {}
    for s, c in pairs(fixedSizeCounts) do sc[s] = c end
    sc[1] = (sc[1] or 0) + N
    local pSeed = rng:NextInteger(1, 1000000)
    local placements = gen(sc, Random.new(pSeed))
    if not placements then return nil end
    local placementsBySize = {}
    for _, p in ipairs(placements) do
        placementsBySize[p.size] = placementsBySize[p.size] or {}
        table.insert(placementsBySize[p.size], {r=p.r, c=p.c, taken=false})
    end
    for _, st in pairs(syncedFixed) do
        local ps = placementsBySize[st.size]
        if not ps then return nil end
        local found = false
        for _, p in ipairs(ps) do
            if not p.taken and p.r == st.row and p.c == st.col then
                p.taken = true; found = true; break
            end
        end
        if not found then return nil end
    end
    if syncedFillerCount > 0 then
        local size1Set = {}
        for _, p in ipairs(placementsBySize[1] or {}) do size1Set[p.r.."_"..p.c] = true end
        for cell in pairs(syncedFillerSet) do
            if not size1Set[cell] then return nil end
        end
    end
    return pSeed, placements, rl
end

log("brute rawSeed 1..1e6 × N ∈ {%s} ...", table.concat(N_RANGE, ","))
local startClock = os.clock()
local hits = {}
for rawSeed = 1, 1000000 do
    for _, N in ipairs(N_RANGE) do
        local pSeed, placements, rl = evalSeedN(rawSeed, N)
        if pSeed then
            table.insert(hits, {rawSeed=rawSeed, N=N, pSeed=pSeed, placements=placements, rl=rl})
            log("HIT rawSeed=%d N=%d placementSeed=%d (耗时 %.2fs)", rawSeed, N, pSeed, os.clock()-startClock)
            break
        end
    end
    if #hits >= 1 then break end
    if rawSeed % 20000 == 0 then
        local rate = rawSeed / math.max(os.clock()-startClock, 0.001)
        log("  progress %d rate=%.0f/s ETA=%.0fs", rawSeed, rate, (1000000-rawSeed)/rate)
        task.wait()
    end
end

if #hits == 0 then
    log("===== 0 命中. 算法骨架可能不对, 或 syncedFixed 不足以约束. 请多开几格再跑. =====")
    return
end

local hit = hits[1]
log("")
log("===== 样本记录 (积累用) =====")
log("user=%s refresh=%s fs=%s → rawSeed=%d N=%d placementSeed=%d",
    tostring(userId), tostring(refreshTick), tostring(fs), hit.rawSeed, hit.N, hit.pSeed)
log("")
log("===== 预测 %d 个 placement =====", #hit.placements)
for i, p in ipairs(hit.placements) do
    log("  [%d] size=%d (%d,%d)", i, p.size, p.r, p.c)
end

if not OPEN_ALL_AFTER_HIT then return end

log("")
log("===== 全开剩余 placement =====")
local opened, skipped, failed = 0, 0, 0
local function isAlreadyOpen(r, c)
    for _, t in pairs(syncedMap) do
        if type(t) == "table" and t.Row == r and t.Col == c then return true end
    end
    return false
end

-- refresh syncedMap before opening to avoid duplicate digs
local _, fresh = safeCall(gp, "TreasureGridGetTreasureMap", ACTIVITY_ID)
syncedMap = fresh or syncedMap

for _, p in ipairs(hit.placements) do
    for dr = 0, p.size-1 do for dc = 0, p.size-1 do
        local r, c = p.r+dr, p.c+dc
        if isAlreadyOpen(r, c) then
            skipped += 1
        else
            local ok, ret = safeCall(gp, "TreasureGridOpenTreasure", ACTIVITY_ID, r, c)
            if ok and ret then
                opened += 1; log("  opened (%d,%d)", r, c)
            else
                failed += 1; log("  失败 (%d,%d): %s", r, c, tostring(ret))
            end
            task.wait(OPEN_DELAY)
        end
    end end
end
log("===== 完成. opened=%d skipped=%d failed=%d =====", opened, skipped, failed)
