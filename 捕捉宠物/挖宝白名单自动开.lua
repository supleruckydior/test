--!nocheck
-- test_84_新算法预测试用.lua
-- 基于 H3 突破: rawSeed (?) → __DoRewardGroup → placementSeed → generateUniformChests(sc=fixed)
-- 尝试多种 rawSeed 派生公式, 打印每个的预测, 自动用 syncedMap 验证.
-- 默认不自动开格, 你看哪个公式预测对了再切.

local TARGET_GAME_ID = 98664161516921
local TAG = "[TGNewPredict]"
if game.PlaceId ~= TARGET_GAME_ID then warn(("%s 游戏ID不匹配"):format(TAG)) return end
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(3)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ACTIVITY_ID = 23
local AUTO_OPEN = true  -- true=通过校验后自动开格，会消耗铲子
local OPEN_INTERVAL = 0.25
local AUTO_OPEN_ALL_FIXED_TREASURES = true -- true=开启当前算法预测出的全部非1000固定奖励
local AUTO_OPEN_ALLOW_NO_SYNC_FOR_ALL_FIXED = true -- allFixed 模式下，允许无 syncedMap 时按 fs+500000 坐标池开
local AUTO_OPEN_ALLOW_FREE_BINDINGS = true -- DP 的 free 补位未被 synced 直接验证；true=也开，false=只开 synced
local AUTO_OPEN_HIGH_QUALITY = true -- true=除白名单外，也开配置 HighQuality 里的高品质奖励
local AUTO_OPEN_VALUE_TMPL_IDS = {
    [3] = true,
    [4] = true,
    [5] = true,
    [6] = true,
}

local function log(fmt, ...) print(("%s " .. fmt):format(TAG, ...)) end
local function warnf(fmt, ...) warn(("%s " .. fmt):format(TAG, ...)) end

local function findPath(root, parts)
    local n = root; for _, name in ipairs(parts) do if not n then return nil end; n = n:FindFirstChild(name) end; return n
end

local RewardSystem = require(findPath(ReplicatedStorage, {"CommonLibrary","Foundation","RewardSystem"}))
local CfgActivity = require(findPath(ReplicatedStorage, {"CommonConfig","Activity","CfgActivity"}))
local ClientPlayerManager = require(findPath(ReplicatedStorage, {"CommonLibrary","Player","ClientPlayerManager"}))
local Utils = require(findPath(ReplicatedStorage, {"CommonLibrary","Tool","Utils"}))
local ActivityTreasureGridSystem = require(findPath(ReplicatedStorage, {"CommonLogic","Activity","ActivityTreasureGridSystem"}))
local ViewUtil = require(findPath(ReplicatedStorage, {"ClientLogic","View","ViewUtil"}))

local function getGamePlayer(timeout)
    local started = os.clock()
    while os.clock() - started < (timeout or 30) do
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

local gp = getGamePlayer(30)
safeCall(gp, "TreasureGridGetTreasureMap", ACTIVITY_ID)
task.wait(0.8)

-- 读当前活动配置和状态
local actCfg = CfgActivity.TmplMap[ACTIVITY_ID]
local eftCfg = actCfg.Effects.TreasureGrid
if actCfg.StartTime == nil and actCfg.StartDate then
    actCfg.StartTime = Utils.GetServerTimeFromStr(actCfg.StartDate)
end

local function calcRefreshTick(serverTime)
    local sum = serverTime - actCfg.StartTime
    local rt = eftCfg.DailyRefreshTime; local sp = eftCfg.DailyRefreshSpan or 86400
    local cyc = math.floor(sum / sp)
    if cyc > 0 then sum = sum - cyc * sp end
    local cs = serverTime - sum
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
local okSeed, sv = safeCall(gp, "TreasureGridGetCustomRefreshSeed", ACTIVITY_ID)
if okSeed then fs = sv end

log("当前状态: fs=%s user=%d refresh=%d", tostring(fs), userId, refreshTick)

local function mod1e6(value)
    return ((value % 1000000) + 1000000) % 1000000
end

-- 候选 rawSeed 派生公式
local candidates = {
    {"fs", fs or 0},
    {"fs+500000", (fs or 0) + 500000},
    {"fs+user%1e5", (fs or 0) + userId % 100000},
    {"fs+user%1e6", (fs or 0) + userId % 1000000},
    {"refresh+user%1e5", refreshTick + userId % 100000},
    {"refresh+fs", refreshTick + (fs or 0)},
    {"(fs+500000) mod 1e6", mod1e6((fs or 0) + 500000)},
    {"refresh%1e6 + 500000", refreshTick % 1000000 + 500000},
    {"dailyNil refresh+user+400000 mod 1e6", mod1e6(refreshTick + userId + 400000)},
}

-- 旧版 generateUniformChests
local ROW_COUNT, COL_COUNT = eftCfg.MapRowCount, eftCfg.MapColCount
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

local ORDER_MODES = {
    "size_desc_tmpl_asc",
    "size_desc_draw_order",
    "size_desc_tmpl_desc",
    "size_desc_quality_desc_tmpl",
    "draw_order",
    "tmpl_asc",
}

local PLACEMENT_ORDER_MODES = {
    "generated",
    "size_group_row_col",
    "size_group_col_row",
    "size_group_reverse",
    "size_group_tail_swap",
}

local function sortFixedRewards(fixedRewards, orderMode)
    if orderMode == "size_desc_draw_order" then
        table.sort(fixedRewards, function(a, b)
            if a.size ~= b.size then return a.size > b.size end
            return a.drawIndex < b.drawIndex
        end)
        return
    end

    if orderMode == "size_desc_tmpl_desc" then
        table.sort(fixedRewards, function(a, b)
            if a.size ~= b.size then return a.size > b.size end
            return a.tmpl > b.tmpl
        end)
        return
    end

    if orderMode == "size_desc_quality_desc_tmpl" then
        table.sort(fixedRewards, function(a, b)
            if a.size ~= b.size then return a.size > b.size end
            local aq = a.config.Quality or 0
            local bq = b.config.Quality or 0
            if aq ~= bq then return aq > bq end
            return a.tmpl < b.tmpl
        end)
        return
    end

    if orderMode == "draw_order" then
        table.sort(fixedRewards, function(a, b)
            return a.drawIndex < b.drawIndex
        end)
        return
    end

    if orderMode == "tmpl_asc" then
        table.sort(fixedRewards, function(a, b)
            return a.tmpl < b.tmpl
        end)
        return
    end

    table.sort(fixedRewards, function(a, b)
        if a.size ~= b.size then return a.size > b.size end
        return a.tmpl < b.tmpl
    end)
end

local function clonePlacements(placements)
    local result = {}
    for i, p in ipairs(placements or {}) do
        result[i] = {r=p.r, c=p.c, size=p.size}
    end
    return result
end

local function reorderPlacements(placements, placementOrderMode)
    local result = clonePlacements(placements)
    if placementOrderMode == "generated" then
        return result
    end

    local index = 1
    while index <= #result do
        local size = result[index].size
        local last = index
        while last + 1 <= #result and result[last + 1].size == size do
            last += 1
        end

        local group = {}
        for i = index, last do table.insert(group, result[i]) end

        if placementOrderMode == "size_group_row_col" then
            table.sort(group, function(a, b)
                if a.r ~= b.r then return a.r < b.r end
                return a.c < b.c
            end)
        elseif placementOrderMode == "size_group_col_row" then
            table.sort(group, function(a, b)
                if a.c ~= b.c then return a.c < b.c end
                return a.r < b.r
            end)
        elseif placementOrderMode == "size_group_reverse" then
            local reversed = {}
            for i = #group, 1, -1 do table.insert(reversed, group[i]) end
            group = reversed
        elseif placementOrderMode == "size_group_tail_swap" and #group >= 2 then
            group[#group], group[#group - 1] = group[#group - 1], group[#group]
        end

        for offset, item in ipairs(group) do
            result[index + offset - 1] = item
        end
        index = last + 1
    end

    return result
end

-- 关键的算法 (H3 突破版): 不含 filler 的 sizeCounts + 双 rng
local function predictWithRawSeed(rawSeed, orderMode, placementOrderMode)
    local rng = Random.new(rawSeed)
    local rl = {}
    pcall(function() RewardSystem.__DoRewardGroup(nil, eftCfg.Rand, rl, rng, false, true) end)
    -- 提取非 1000 的 tmpls
    local fixedRewards = {}
    for drawIndex, r in ipairs(rl) do
        if r.TmplId and r.TmplId ~= 1000 then
            local tmpl = eftCfg.Tmpls[r.TmplId]
            if tmpl then
                table.insert(fixedRewards, {tmpl=r.TmplId, size=tmpl.Size, config=tmpl, drawIndex=drawIndex})
            end
        end
    end
    -- sizeCounts fixed only
    local sc = {}
    for _, r in ipairs(fixedRewards) do sc[r.size] = (sc[r.size] or 0) + 1 end
    -- placementSeed
    local placementSeed = rng:NextInteger(1, 1000000)
    local rawPlacements = gen(sc, Random.new(placementSeed))
    local placements = reorderPlacements(rawPlacements, placementOrderMode or "generated")
    -- 一一对应 placements；orderMode 用 syncedMap 验证哪种映射更接近服务端。
    sortFixedRewards(fixedRewards, orderMode or "size_desc_tmpl_asc")
    local map = {}
    for i, p in ipairs(placements or {}) do
        local fr = fixedRewards[i]
        if fr then
            map[fr.tmpl] = {
                tmpl=fr.tmpl,
                row=p.r,
                col=p.c,
                size=p.size,
                reward=fr.config.Reward,
                name=fr.config.Name,
                quality=fr.config.Quality,
                source="candidate",
                placementIndex=i,
                drawIndex=fr.drawIndex,
            }
        end
    end
    return map, placementSeed, fixedRewards, placements, rawPlacements
end

-- 拿 syncedMap 作验证
local function getSyncedMap()
    local ok, m = safeCall(gp, "TreasureGridGetTreasureMap", ACTIVITY_ID)
    return ok and type(m) == "table" and m or {}
end

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t or {}) do table.insert(keys, k) end
    table.sort(keys, function(a, b)
        local na, nb = tonumber(a), tonumber(b)
        if na and nb then return na < nb end
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function getOpenedCells()
    local cells = {}
    for row = 1, ROW_COUNT do
        for col = 1, COL_COUNT do
            local ok, opened = safeCall(gp, "TreasureGridIsCellOpened", ACTIVITY_ID, row, col)
            if ok and opened then
                table.insert(cells, {row=row, col=col, text=("%d_%d"):format(row, col)})
            end
        end
    end
    table.sort(cells, function(a, b)
        if a.row ~= b.row then return a.row < b.row end
        return a.col < b.col
    end)
    return cells
end

local function getSyncedFields(st)
    return st.TmplId or st.tmplId, st.Row or st.row, st.Col or st.col, st.UniqueTmplId or st.uniqueTmplId
end

local function countMapEntries(t)
    local count = 0
    for _ in pairs(t or {}) do count += 1 end
    return count
end

local function buildSyncedKeySet(map)
    local set = {}
    for key in pairs(map or {}) do
        set[key] = true
    end
    return set
end

local syncedMap = getSyncedMap()
local syncedCount = 0
for _ in pairs(syncedMap) do syncedCount = syncedCount + 1 end
log("syncedMap 已有 %d 个条目 (开过的格子)", syncedCount)

local openedCells = getOpenedCells()
local openedTexts = {}
for _, cell in ipairs(openedCells) do table.insert(openedTexts, cell.text) end
log("openedCells 已挖 %d 格: %s", #openedCells, table.concat(openedTexts, ","))

log("===== syncedMap 已同步记录 =====")
for _, key in ipairs(sortedKeys(syncedMap)) do
    local st = syncedMap[key]
    if type(st) == "table" then
        local tmplId, row, col, uniqueTmplId = getSyncedFields(st)
        log("  key=%s unique=%s tmpl=%s row=%s col=%s", tostring(key), tostring(uniqueTmplId), tostring(tmplId), tostring(row), tostring(col))
    end
end

local function scoreVsSynced(predMap)
    if syncedCount == 0 then return nil end
    local checked, hits, details = 0, 0, {}
    for _, k in ipairs(sortedKeys(syncedMap)) do
        local st = syncedMap[k]
        local tmplId, row, col = nil, nil, nil
        if type(st) == "table" then
            tmplId, row, col = getSyncedFields(st)
        end
        if tmplId and tmplId ~= 1000 then
            checked += 1
            local p = predMap[tmplId]
            local ok = p and p.row == row and p.col == col
            if ok then hits += 1 end
            table.insert(details, {
                ok = ok == true,
                key = k,
                tmpl = tmplId,
                row = row,
                col = col,
                predRow = p and p.row or nil,
                predCol = p and p.col or nil,
            })
        end
    end
    return hits, checked, details
end

local function scorePlacementPool(placements)
    if syncedCount == 0 then return nil end
    local checked, hits = 0, 0
    local bySizeCoord = {}
    for _, p in ipairs(placements or {}) do
        bySizeCoord[p.size] = bySizeCoord[p.size] or {}
        bySizeCoord[p.size][("%d_%d"):format(p.r, p.c)] = true
    end

    for _, k in ipairs(sortedKeys(syncedMap)) do
        local st = syncedMap[k]
        local tmplId, row, col = nil, nil, nil
        if type(st) == "table" then
            tmplId, row, col = getSyncedFields(st)
        end
        local cfg = tmplId and tmplId ~= 1000 and eftCfg.Tmpls[tmplId]
        if cfg then
            checked += 1
            local coordSet = bySizeCoord[cfg.Size]
            if coordSet and coordSet[("%d_%d"):format(row, col)] then
                hits += 1
            end
        end
    end

    return hits, checked
end

local function buildKnownBySize()
    local knownBySize = {}
    for _, key in ipairs(sortedKeys(syncedMap)) do
        local st = syncedMap[key]
        local tmplId, row, col = nil, nil, nil
        if type(st) == "table" then
            tmplId, row, col = getSyncedFields(st)
        end
        local cfg = tmplId and tmplId ~= 1000 and eftCfg.Tmpls[tmplId]
        if cfg then
            knownBySize[cfg.Size] = knownBySize[cfg.Size] or {}
            knownBySize[cfg.Size][tmplId] = {row=row, col=col}
        end
    end
    return knownBySize
end

local function solveAssignmentDp(rewards, places, knownForSize)
    table.sort(rewards, function(a, b)
        return (a.drawIndex or 0) < (b.drawIndex or 0)
    end)
    table.sort(places, function(a, b)
        return (a._placementIndex or 0) < (b._placementIndex or 0)
    end)

    local n = #rewards
    if n ~= #places then
        return {}, 0, "count_mismatch"
    end
    if n == 0 then
        return {}, 0, nil
    end
    if n > 20 then
        return {}, 0, "too_many_for_dp"
    end

    local bit = bit32
    if type(bit) ~= "table" then
        return {}, 0, "bit32_missing"
    end

    local function hasBit(mask, index)
        return bit.band(mask, bit.lshift(1, index - 1)) ~= 0
    end
    local function setBit(mask, index)
        return bit.bor(mask, bit.lshift(1, index - 1))
    end

    local dp = {[0] = 0}
    local choices = {}

    for rewardIndex = 1, n do
        local nextDp = {}
        choices[rewardIndex] = {}
        local rewardInfo = rewards[rewardIndex]
        local known = knownForSize and knownForSize[rewardInfo.tmpl]

        for mask, score in pairs(dp) do
            for placeIndex, place in ipairs(places) do
                if not hasBit(mask, placeIndex) then
                    local add = 0
                    if known and known.row == place.r and known.col == place.c then
                        add = 1
                    end
                    local newMask = setBit(mask, placeIndex)
                    local newScore = score + add
                    if nextDp[newMask] == nil or newScore > nextDp[newMask] then
                        nextDp[newMask] = newScore
                        choices[rewardIndex][newMask] = {
                            prevMask = mask,
                            placeIndex = placeIndex,
                        }
                    end
                end
            end
        end

        dp = nextDp
    end

    local fullMask = bit.lshift(1, n) - 1
    local bestScore = dp[fullMask] or 0
    local assignments = {}
    local mask = fullMask
    for rewardIndex = n, 1, -1 do
        local choice = choices[rewardIndex] and choices[rewardIndex][mask]
        if not choice then
            return {}, bestScore, "reconstruct_failed"
        end
        assignments[rewardIndex] = {
            reward = rewards[rewardIndex],
            place = places[choice.placeIndex],
        }
        mask = choice.prevMask
    end

    return assignments, bestScore, nil
end

local function buildBruteforceSyncedFitMap(fixedRewards, placements)
    local rewardGroups, placementGroups = {}, {}
    for _, rewardInfo in ipairs(fixedRewards or {}) do
        rewardGroups[rewardInfo.size] = rewardGroups[rewardInfo.size] or {}
        table.insert(rewardGroups[rewardInfo.size], rewardInfo)
    end
    for placementIndex, p in ipairs(placements or {}) do
        p._placementIndex = placementIndex
        placementGroups[p.size] = placementGroups[p.size] or {}
        table.insert(placementGroups[p.size], p)
    end

    local knownBySize = buildKnownBySize()
    local map, bindings = {}, {}
    local totalBestScore, errors = 0, {}

    for size, rewards in pairs(rewardGroups) do
        local places = placementGroups[size] or {}
        local assignments, bestScore, err = solveAssignmentDp(rewards, places, knownBySize[size])
        totalBestScore += bestScore
        if err then
            table.insert(errors, ("size=%s:%s"):format(tostring(size), tostring(err)))
        end

        for _, assignment in ipairs(assignments) do
            local rewardInfo = assignment.reward
            local p = assignment.place
            local known = knownBySize[size] and knownBySize[size][rewardInfo.tmpl]
            local verified = known and known.row == p.r and known.col == p.c
            map[rewardInfo.tmpl] = {
                tmpl=rewardInfo.tmpl,
                row=p.r,
                col=p.c,
                size=p.size,
                reward=rewardInfo.config.Reward,
                name=rewardInfo.config.Name,
                quality=rewardInfo.config.Quality,
                source=verified and "synced" or "free",
                known=known ~= nil,
                placementIndex=p._placementIndex,
                drawIndex=rewardInfo.drawIndex,
            }
            table.insert(bindings, {
                source=verified and "synced" or "free",
                tmpl=rewardInfo.tmpl,
                drawIndex=rewardInfo.drawIndex,
                row=p.r,
                col=p.c,
                size=p.size,
                placementIndex=p._placementIndex,
                known=known ~= nil,
            })
        end

        if #assignments == 0 and #rewards > 0 then
            for _, rewardInfo in ipairs(rewards) do
                table.insert(bindings, {
                    source="unassigned",
                    tmpl=rewardInfo.tmpl,
                    drawIndex=rewardInfo.drawIndex,
                    row=-1,
                    col=-1,
                    size=size,
                    placementIndex=-1,
                    known=false,
                })
            end
        end
    end

    table.sort(bindings, function(a, b)
        if a.size ~= b.size then return a.size > b.size end
        return (a.placementIndex or 0) < (b.placementIndex or 0)
    end)

    return map, bindings, totalBestScore, table.concat(errors, ",")
end

local function printScoreDetails(result)
    if not result.details then return end
    log("----- syncedVerify 明细: %s rewardOrder=%s placeOrder=%s rawSeed=%d placementSeed=%d hit=%s/%s pool=%s/%s -----",
        result.name,
        tostring(result.orderMode),
        tostring(result.placementOrderMode),
        result.raw,
        result.place,
        tostring(result.hit),
        tostring(result.chk),
        tostring(result.poolHit),
        tostring(result.poolChk))
    for _, d in ipairs(result.details) do
        if d.ok then
            log("  HIT  key=%s tmpl=%s synced=(%s,%s) predicted=(%s,%s)",
                tostring(d.key), tostring(d.tmpl), tostring(d.row), tostring(d.col), tostring(d.predRow), tostring(d.predCol))
        else
            log("  MISS key=%s tmpl=%s synced=(%s,%s) predicted=(%s,%s)",
                tostring(d.key), tostring(d.tmpl), tostring(d.row), tostring(d.col), tostring(d.predRow), tostring(d.predCol))
        end
    end
end

local function formatReward(r)
    if type(r) ~= "table" then return tostring(r) end
    local cnt = r.Count and (" x"..r.Count) or ""
    if r.RewardRes == "Value" then return ("Value %s%s"):format(tostring(r.ValueType), cnt) end
    return ("%s#%s%s"):format(tostring(r.RewardRes), tostring(r.TmplId), cnt)
end

local function isRewardClaimed(tmplId)
    local ok, claimed = safeCall(gp, "TreasureGridIsRewardClaimed", ACTIVITY_ID, tmplId)
    return ok and claimed == true
end

local function isCellOpened(row, col)
    local ok, opened = safeCall(gp, "TreasureGridIsCellOpened", ACTIVITY_ID, row, col)
    return ok and opened == true
end

local function openTreasureCell(row, col)
    if type(ActivityTreasureGridSystem) ~= "table" or type(ActivityTreasureGridSystem.ClientOpenCell) ~= "function" then
        return false, "ActivityTreasureGridSystem.ClientOpenCell missing"
    end

    local ok, result
    if type(ViewUtil) == "table" and type(ViewUtil.DoRequest) == "function" then
        ok, result = pcall(ViewUtil.DoRequest, ActivityTreasureGridSystem.ClientOpenCell, ACTIVITY_ID, row, col)
    else
        ok, result = pcall(ActivityTreasureGridSystem.ClientOpenCell, ACTIVITY_ID, row, col)
    end

    if not ok then
        return false, result
    end
    return result ~= false and result ~= nil, result
end

local function buildActualByCoord(synced)
    local byCoord = {}
    for _, key in ipairs(sortedKeys(synced or {})) do
        local st = synced[key]
        if type(st) == "table" then
            local tmplId, row, col, uniqueTmplId = getSyncedFields(st)
            if tmplId and row and col then
                byCoord[("%s_%s"):format(tostring(row), tostring(col))] = {
                    key=key,
                    tmpl=tmplId,
                    row=row,
                    col=col,
                    unique=uniqueTmplId,
                }
            end
        end
    end
    return byCoord
end

local function printPostOpenValidation(primaryResult, beforeSyncedMap, openedTargets)
    task.wait(0.8)
    local afterSyncedMap = getSyncedMap()
    local beforeKeys = buildSyncedKeySet(beforeSyncedMap)
    local beforeCount = countMapEntries(beforeSyncedMap)
    local afterCount = countMapEntries(afterSyncedMap)
    local actualByCoord = buildActualByCoord(afterSyncedMap)

    log("\n========== 开后 syncedMap 复核: before=%d after=%d delta=%d ==========",
        beforeCount,
        afterCount,
        afterCount - beforeCount)

    local newCount, matchedCount, mismatchCount = 0, 0, 0
    for _, key in ipairs(sortedKeys(afterSyncedMap)) do
        if not beforeKeys[key] then
            local st = afterSyncedMap[key]
            if type(st) == "table" then
                local tmplId, row, col, uniqueTmplId = getSyncedFields(st)
                local predicted = primaryResult.map and primaryResult.map[tmplId]
                local matched = predicted and predicted.row == row and predicted.col == col
                newCount += 1
                if matched then matchedCount += 1 else mismatchCount += 1 end
                log("  NEW key=%s unique=%s tmpl=%s row=%s col=%s predicted=(%s,%s) source=%s %s",
                    tostring(key),
                    tostring(uniqueTmplId),
                    tostring(tmplId),
                    tostring(row),
                    tostring(col),
                    predicted and tostring(predicted.row) or "nil",
                    predicted and tostring(predicted.col) or "nil",
                    predicted and tostring(predicted.source) or "nil",
                    matched and "HIT" or "MISS")
            end
        end
    end

    if newCount == 0 then
        log("  没有新增 syncedMap 条目；可能本次只补开同一大宝藏格子，或客户端同步延迟")
    else
        log("开后复核汇总: new=%d hit=%d miss=%d", newCount, matchedCount, mismatchCount)
    end

    if openedTargets and #openedTargets > 0 then
        log("\n--- 按开格坐标反查实际奖励 ---")
        for _, target in ipairs(openedTargets) do
            local actual = actualByCoord[("%s_%s"):format(tostring(target.row), tostring(target.col))]
            if actual then
                local ok = actual.tmpl == target.tmpl
                log("  openedCoord=(%s,%s) expectedTarget=%s actualTmpl=%s key=%s %s",
                    tostring(target.row),
                    tostring(target.col),
                    tostring(target.tmpl),
                    tostring(actual.tmpl),
                    tostring(actual.key),
                    ok and "HIT" or "SWAP")
            else
                log("  openedCoord=(%s,%s) expectedTarget=%s actualTmpl=nil",
                    tostring(target.row),
                    tostring(target.col),
                    tostring(target.tmpl))
            end
        end
    end
end

local function shouldAutoOpenTreasure(treasure, whitelist, highQualitySet)
    if AUTO_OPEN_ALL_FIXED_TREASURES then
        return true, "allFixed"
    end

    if whitelist[treasure.tmpl] then
        return true, "whitelist"
    end

    if AUTO_OPEN_VALUE_TMPL_IDS[treasure.tmpl] then
        return true, "valueTmpl"
    end

    if AUTO_OPEN_HIGH_QUALITY and highQualitySet and highQualitySet[treasure.quality] then
        return true, "highQuality"
    end

    return false, "skip"
end

local function isPreferredRawSeedResult(result)
    if not result then return false end
    return result.name == "fs+500000"
        or result.name == "(fs+500000) mod 1e6"
        or result.name == "dailyNil refresh+user+400000 mod 1e6"
end

local function autoOpenPredictedWhitelisted(primaryResult, whitelist, highQualitySet)
    if not AUTO_OPEN then
        log("\n自动开格: AUTO_OPEN=false，跳过")
        return
    end

    if not primaryResult or type(primaryResult.map) ~= "table" then
        warnf("\n自动开格停止: 没有可用预测结果")
        return
    end

    local toOpen = {}

    if AUTO_OPEN_ALL_FIXED_TREASURES then
        if not isPreferredRawSeedResult(primaryResult) or primaryResult.orderMode ~= "bruteforce_synced_fit" then
            warnf("\n自动开格停止: allFixed 只允许已验证 rawSeed 分支，当前=%s/%s",
                tostring(primaryResult.name),
                tostring(primaryResult.orderMode))
            return
        end

        for placementIndex, placement in ipairs(primaryResult.rawPlacements or primaryResult.placements or {}) do
            table.insert(toOpen, {
                tmpl=("fixed#%d"):format(placementIndex),
                row=placement.r,
                col=placement.c,
                size=placement.size,
                reward=nil,
                source="placementPool",
                openReason="allFixed",
                placementIndex=placementIndex,
            })
        end
    else
        local hasSyncedCheck = primaryResult.hit and primaryResult.chk and primaryResult.chk > 0
        if not hasSyncedCheck then
            warnf("\n自动开格停止: 没有 syncedMap 校验数据")
            return
        end

        if primaryResult.hit ~= primaryResult.chk then
            warnf("\n自动开格停止: syncedVerify=%s/%s 未满分", tostring(primaryResult.hit), tostring(primaryResult.chk))
            return
        end

        if primaryResult.poolHit and primaryResult.poolChk and primaryResult.poolHit ~= primaryResult.poolChk then
            warnf("\n自动开格停止: placement pool=%s/%s 未满分", tostring(primaryResult.poolHit), tostring(primaryResult.poolChk))
            return
        end

        for _, treasure in pairs(primaryResult.map) do
            local shouldOpen, reason = shouldAutoOpenTreasure(treasure, whitelist, highQualitySet)
            if shouldOpen and not isRewardClaimed(treasure.tmpl) then
                if treasure.source ~= "free" or AUTO_OPEN_ALLOW_FREE_BINDINGS then
                    treasure.openReason = reason
                    table.insert(toOpen, treasure)
                end
            end
        end

        table.sort(toOpen, function(a, b)
            local aVerified = a.source == "synced"
            local bVerified = b.source == "synced"
            if aVerified ~= bVerified then return aVerified end
            local aHigh = a.openReason == "highQuality"
            local bHigh = b.openReason == "highQuality"
            if aHigh ~= bHigh then return aHigh end
            local aValue = a.openReason == "valueTmpl"
            local bValue = b.openReason == "valueTmpl"
            if aValue ~= bValue then return aValue end
            local aWhite = a.openReason == "whitelist"
            local bWhite = b.openReason == "whitelist"
            if aWhite ~= bWhite then return aWhite end
            if a.size ~= b.size then return a.size > b.size end
            return a.tmpl < b.tmpl
        end)
    end

    log("\n========== 自动开目标奖励 (公式=%s order=%s/%s verify=%s/%s pool=%s/%s allFixed=%s highQuality=%s) ==========",
        tostring(primaryResult.name),
        tostring(primaryResult.orderMode),
        tostring(primaryResult.placementOrderMode),
        tostring(primaryResult.hit),
        tostring(primaryResult.chk),
        tostring(primaryResult.poolHit),
        tostring(primaryResult.poolChk),
        tostring(AUTO_OPEN_ALL_FIXED_TREASURES),
        tostring(AUTO_OPEN_HIGH_QUALITY))

    if #toOpen == 0 then
        log("没有需要自动开的目标奖励")
        return
    end

    local beforeSyncedMap = getSyncedMap()
    local openedTreasures, openedCells = 0, 0
    local openedTargets = {}
    for _, treasure in ipairs(toOpen) do
        log("准备开: target=%s reason=%s source=%s size=%dx%d topLeft=(%d,%d) reward=%s",
            tostring(treasure.tmpl),
            tostring(treasure.openReason),
            tostring(treasure.source),
            treasure.size,
            treasure.size,
            treasure.row,
            treasure.col,
            formatReward(treasure.reward))

        local openedNewCell = false
        for row = treasure.row, treasure.row + treasure.size - 1 do
            for col = treasure.col, treasure.col + treasure.size - 1 do
                if isCellOpened(row, col) then
                    log("  已开，跳过 cell=(%d,%d)", row, col)
                    continue
                end

                local okOpen, result = openTreasureCell(row, col)
                if not okOpen then
                    warnf("  开格失败，停止 cell=(%d,%d): %s", row, col, tostring(result))
                    log("自动开格提前结束: openedTreasures=%d openedCells=%d", openedTreasures, openedCells)
                    printPostOpenValidation(primaryResult, beforeSyncedMap, openedTargets)
                    return
                end

                openedCells += 1
                openedNewCell = true
                table.insert(openedTargets, {
                    tmpl=treasure.tmpl,
                    row=row,
                    col=col,
                    source=treasure.source,
                    reason=treasure.openReason,
                })
                log("  opened cell=(%d,%d), result=%s", row, col, tostring(result))
                task.wait(OPEN_INTERVAL)
            end
        end

        if openedNewCell then
            openedTreasures += 1
        end
    end

    log("自动开格完成: openedTreasures=%d openedCells=%d", openedTreasures, openedCells)
    printPostOpenValidation(primaryResult, beforeSyncedMap, openedTargets)
end

-- 主循环: 对每个候选公式试一次
log("\n========== 试 %d 个 rawSeed 候选 ==========", #candidates)
local results = {}
for _, c in ipairs(candidates) do
    local bestForSeed = nil
    for _, orderMode in ipairs(ORDER_MODES) do
        for _, placementOrderMode in ipairs(PLACEMENT_ORDER_MODES) do
            local map, ps, orderedRewards, placements, rawPlacements = predictWithRawSeed(c[2], orderMode, placementOrderMode)
            local n = 0
            for _ in pairs(map) do n = n + 1 end
            local hit, chk, details = scoreVsSynced(map)
            local poolHit, poolChk = scorePlacementPool(rawPlacements)
            local result = {
                name=c[1],
                raw=c[2],
                place=ps,
                orderMode=orderMode,
                placementOrderMode=placementOrderMode,
                map=map,
                n=n,
                hit=hit,
                chk=chk,
                poolHit=poolHit,
                poolChk=poolChk,
                details=details,
                orderedRewards=orderedRewards,
                placements=placements,
                rawPlacements=rawPlacements,
            }
            table.insert(results, result)
            if not bestForSeed
                or (hit or -1) > (bestForSeed.hit or -1)
                or ((hit or -1) == (bestForSeed.hit or -1) and (poolHit or -1) > (bestForSeed.poolHit or -1)) then
                bestForSeed = result
            end
        end
    end

    do
        local _, ps, fixedRewards, placements, rawPlacements = predictWithRawSeed(c[2], "draw_order", "generated")
        local bruteMap, bruteBindings, dpScore, dpError = buildBruteforceSyncedFitMap(fixedRewards, rawPlacements)
        local n = 0
        for _ in pairs(bruteMap) do n = n + 1 end
        local hit, chk, details = scoreVsSynced(bruteMap)
        local poolHit, poolChk = scorePlacementPool(rawPlacements)
        local bruteResult = {
            name=c[1],
            raw=c[2],
            place=ps,
            orderMode="bruteforce_synced_fit",
            placementOrderMode="generated_pool",
            map=bruteMap,
            n=n,
            hit=hit,
            chk=chk,
            poolHit=poolHit,
            poolChk=poolChk,
            details=details,
            orderedRewards=fixedRewards,
            placements=rawPlacements,
            rawPlacements=rawPlacements,
            bruteBindings=bruteBindings,
            dpScore=dpScore,
            dpError=dpError,
        }
        table.insert(results, bruteResult)
        if not bestForSeed
            or (hit or -1) > (bestForSeed.hit or -1)
            or ((hit or -1) == (bestForSeed.hit or -1) and (poolHit or -1) > (bestForSeed.poolHit or -1)) then
            bestForSeed = bruteResult
        end
    end

    if bestForSeed and bestForSeed.hit then
        log("  %s rawSeed=%d → placementSeed=%d  treasures=%d  bestRewardOrder=%s bestPlaceOrder=%s syncedVerify=%d/%d pool=%s/%s%s",
            c[1], c[2], bestForSeed.place, bestForSeed.n, bestForSeed.orderMode, bestForSeed.placementOrderMode,
            bestForSeed.hit, bestForSeed.chk, tostring(bestForSeed.poolHit), tostring(bestForSeed.poolChk),
            bestForSeed.hit == bestForSeed.chk and bestForSeed.chk > 0 and " <<< MATCH" or "")
    elseif bestForSeed then
        log("  %s rawSeed=%d → placementSeed=%d  treasures=%d  bestRewardOrder=%s bestPlaceOrder=%s (无 synced 数据可验证)",
            c[1], c[2], bestForSeed.place, bestForSeed.n, bestForSeed.orderMode, bestForSeed.placementOrderMode)
    end
end

table.sort(results, function(a, b)
    local ah, bh = a.hit or -1, b.hit or -1
    if ah ~= bh then return ah > bh end
    local aph, bph = a.poolHit or -1, b.poolHit or -1
    if aph ~= bph then return aph > bph end
    return (a.chk or 0) > (b.chk or 0)
end)

local function selectPrimaryResult(sortedResults)
    if AUTO_OPEN_ALL_FIXED_TREASURES then
        local fallback = nil
        for _, result in ipairs(sortedResults) do
            local isPreferredSeed = isPreferredRawSeedResult(result)
            local isPreferredMode = result.orderMode == "bruteforce_synced_fit"
                and result.placementOrderMode == "generated_pool"
            if isPreferredSeed and isPreferredMode then
                fallback = fallback or result
                if result.hit and result.chk and result.chk > 0 and result.hit == result.chk then
                    return result, "verified_preferred"
                end
            end
        end
        if fallback then
            return fallback, "preferred_no_sync"
        end
    end

    return sortedResults[1], "best_score"
end

log("\n========== 暴力排序上限 (使用 syncedMap 反推绑定, 非真实算法) ==========")
for _, result in ipairs(results) do
    if result.orderMode == "bruteforce_synced_fit" then
        log("  %s rawSeed=%d placementSeed=%d dpScore=%s bruteFit=%s/%s pool=%s/%s treasures=%d err=%s",
            result.name,
            result.raw,
            result.place,
            tostring(result.dpScore),
            tostring(result.hit),
            tostring(result.chk),
            tostring(result.poolHit),
            tostring(result.poolChk),
            result.n,
            tostring(result.dpError))
    end
end

log("\n========== syncedVerify 明细 (按命中率排序, 含 orderMode) ==========")
local printedDetails = 0
for _, result in ipairs(results) do
    if result.hit and result.chk and result.chk > 0 then
        printScoreDetails(result)
        printedDetails += 1
        if printedDetails >= 12 then break end
    end
end

-- 取主候选详细打印一份地图作参考
local primary, primaryReason = selectPrimaryResult(results)
log("\n========== 详细预测 (公式=%s, order=%s, placementSeed=%d, reason=%s) ==========",
    primary.name, primary.orderMode .. "/" .. tostring(primary.placementOrderMode), primary.place, tostring(primaryReason))
local list = {}
for _, v in pairs(primary.map) do table.insert(list, v) end
table.sort(list, function(a,b)
    if a.size ~= b.size then return a.size > b.size end
    return a.tmpl < b.tmpl
end)
for _, t in ipairs(list) do
    log("tmpl=%-3d %-15s size=%dx%d topLeft=(%d,%d) reward=%s",
        t.tmpl, tostring(t.name), t.size, t.size, t.row, t.col, formatReward(t.reward))
end

if primary.orderMode == "bruteforce_synced_fit" then
    log("\n--- DP穷举最优绑定 (source=synced 为已验证; free 为未约束补位) ---")
    for index, binding in ipairs(primary.bruteBindings or {}) do
        log("#%02d placementIndex=%s source=%s place=(%d,%d) size=%d -> tmpl=%s drawIndex=%s",
            index,
            tostring(binding.placementIndex),
            tostring(binding.source),
            binding.row,
            binding.col,
            binding.size,
            tostring(binding.tmpl),
            tostring(binding.drawIndex))
    end

    log("\n--- DP穷举序列 (按 size 分组; ?=未约束补位) ---")
    local bySize = {}
    for _, binding in ipairs(primary.bruteBindings or {}) do
        bySize[binding.size] = bySize[binding.size] or {}
        table.insert(bySize[binding.size], binding)
    end
    local sizes = {}
    for size in pairs(bySize) do table.insert(sizes, size) end
    table.sort(sizes, function(a, b) return a > b end)
    for _, size in ipairs(sizes) do
        table.sort(bySize[size], function(a, b) return (a.placementIndex or 0) < (b.placementIndex or 0) end)
        local parts = {}
        for _, binding in ipairs(bySize[size]) do
            local marker = binding.source == "synced" and "" or "?"
            table.insert(parts, ("#%s:%s%s(d%s)"):format(tostring(binding.placementIndex), tostring(binding.tmpl), marker, tostring(binding.drawIndex)))
        end
        log("size=%d sequence=%s", size, table.concat(parts, " "))
    end
else
    log("\n--- placement 绑定顺序 (最佳候选) ---")
    for index, rewardInfo in ipairs(primary.orderedRewards or {}) do
        local p = primary.placements and primary.placements[index]
        if p then
            log("#%02d place=(%d,%d) size=%d -> tmpl=%s drawIndex=%s",
                index, p.r, p.c, p.size, tostring(rewardInfo.tmpl), tostring(rewardInfo.drawIndex))
        end
    end
end

-- 文本地图
log("\n--- 预测地图 (W=白名单, R=HighQuality非白名单, V=显式高价值模板, A=全部固定奖励, .=空) ---")
local WHITELIST = {[9]=true,[10]=true,[11]=true,[12]=true,[13]=true,[14]=true,[15]=true,[16]=true,
                   [17]=true,[18]=true,[19]=true,[20]=true,[21]=true,[22]=true,[23]=true,[24]=true}
local HIGH_QUALITY = {}
for _, quality in ipairs(eftCfg.HighQuality or {}) do
    HIGH_QUALITY[quality] = true
end
local grid = {}
for r=1,ROW_COUNT do grid[r]={}; for c=1,COL_COUNT do grid[r][c]="." end end
for _, t in ipairs(list) do
    local m = "."
    if WHITELIST[t.tmpl] then
        m = "W"
    elseif AUTO_OPEN_VALUE_TMPL_IDS[t.tmpl] then
        m = "V"
    elseif HIGH_QUALITY[t.quality] then
        m = "R"
    elseif AUTO_OPEN_ALL_FIXED_TREASURES and t.tmpl then
        m = "A"
    elseif t.tmpl then
        m = "P"
    end
    for r=t.row, t.row+t.size-1 do for c=t.col, t.col+t.size-1 do
        if grid[r] then grid[r][c] = m end
    end end
end
for r=1,ROW_COUNT do log("%02d: %s", r, table.concat(grid[r], " ")) end

autoOpenPredictedWhitelisted(primary, WHITELIST, HIGH_QUALITY)

log("\n========== 用法 ==========")
log("1. 看 '试 %d 个 rawSeed 候选' 那一段, 找出 syncedVerify 命中的公式 (如果开过格子)", #candidates)
log("2. 如果没开过格子, 你可以手动开 1-2 个预测的便宜格子(比如 tmpl=1 那个), 看是否中")
log("3. 当前 AUTO_OPEN=%s; AUTO_OPEN_ALL_FIXED_TREASURES=%s; AUTO_OPEN_ALLOW_NO_SYNC_FOR_ALL_FIXED=%s; AUTO_OPEN_ALLOW_FREE_BINDINGS=%s; AUTO_OPEN_HIGH_QUALITY=%s; valueTmpl=3,4,5,6; dailyNil=refresh+user+400000 mod 1e6",
    tostring(AUTO_OPEN),
    tostring(AUTO_OPEN_ALL_FIXED_TREASURES),
    tostring(AUTO_OPEN_ALLOW_NO_SYNC_FOR_ALL_FIXED),
    tostring(AUTO_OPEN_ALLOW_FREE_BINDINGS),
    tostring(AUTO_OPEN_HIGH_QUALITY))
