if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  LootRollFrames.lua
--  A group loot roll window for EllesmereUI. Rolls start, end and their
--  results arrive as events; C_LootHistory, the same source Blizzard's Loot
--  History window reads, says who chose what and what they rolled. The
--  buttons call RollOnLoot, exactly what Blizzard's GroupLootFrame calls.
--
--  The ticker exists only while something is on screen, and the loot history
--  is only read while a roll is being tracked.
-------------------------------------------------------------------------------
local ADDON, ns = ...
local EUI = _G.EllesmereUI
if not (EUI and EUI.RegisterPlugin and EUI.Tick) then return end -- EllesmereUI missing or too old

local pcall, type, tonumber, tostring = pcall, type, tonumber, tostring

-- A secret value (12.x combat and loot data) must not reach our own tables:
-- it cannot be compared, indexed or turned into a string from addon code.
local secretCheck = _G.issecretvalue
local function plain(v)
    if v == nil then return nil end
    if secretCheck and secretCheck(v) then return nil end
    return v
end

-------------------------------------------------------------------------------
--  Settings
-------------------------------------------------------------------------------
local DEFAULTS = {
    enabled      = false,
    hideBlizzard = true,
    sound        = false,
    linger       = 10,
    scale        = 1,
    width        = 300,
    iconSize     = 12,
    lineGap      = 6,
    pad          = 8,
    maxRows      = 4,
    playerStyle  = "chips",
    align        = "left",
    buttonStyle  = "icons",
    buttonBgSpan = "badge",
    buttonBgA    = 0.2,
    buttonHoverA = 0.34,
    lineR = 0.6, lineG = 0.6, lineB = 0.6,
    showRolls    = true,
    chipBgR = 1, chipBgG = 1, chipBgB = 1, chipBgA = 0.05,
    chipBgClass = false,
    chipBorderR = 1, chipBorderG = 1, chipBorderB = 1, chipBorderA = 1,
    chipBorderTexture = "solid", chipBorderSize = 1, chipBorderSizePx = false,
    chipBorderClass = false,
    itemBorderTexture = "solid", itemBorderSize = 1, itemBorderSizePx = false,
    itemBorderR = 0, itemBorderG = 0, itemBorderB = 0, itemBorderA = 1,
    itemBorderQuality = true,
    flashTime = 5, flashSpeed = 9,
    flashR = 1, flashG = 0.25, flashB = 0.25,
    itemIconSize = 22,
    barBgTexture = "none", barHeight = 2,
    -- Appearance, in the same shape as EllesmereUI's other frames.
    bgTexture    = "none",
    bgR = 0.062, bgG = 0.050, bgB = 0.039, bgA = 0.97,
    borderTexture = "solid",
    borderSize = 1, borderSizePx = false,
    borderR = 0, borderG = 0, borderB = 0, borderA = 1,
    borderBehind = false,
    posPoint = "CENTER", posRelPoint = "CENTER", posX = 0, posY = 260,
}
ns.DEFAULTS = DEFAULTS

local db
local function EnsureDB()
    if db then return db end
    if type(LootRollFramesDB) ~= "table" then LootRollFramesDB = {} end
    db = LootRollFramesDB
    -- The *Px keys are false or an exact-size string (EllesmereUI.BorderPxString),
    -- so they are not held to the boolean's type.
    local PX_KEYS = { borderSizePx = true, chipBorderSizePx = true, itemBorderSizePx = true }
    for k, v in pairs(DEFAULTS) do
        if not PX_KEYS[k] and type(db[k]) ~= type(v) then db[k] = v end
    end
    if db.borderSizePx == nil then db.borderSizePx = false end
    if db.chipBorderSizePx == nil then db.chipBorderSizePx = false end
    if db.itemBorderSizePx == nil then db.itemBorderSizePx = false end
    db.linger  = math.max(0, math.min(60, tonumber(db.linger) or DEFAULTS.linger))
    db.scale   = math.max(0.5, math.min(2, tonumber(db.scale) or 1))
    db.width   = math.max(240, math.min(460, tonumber(db.width) or 300))
    db.maxRows = math.max(1, math.min(8, tonumber(db.maxRows) or 4))
    db.iconSize = math.max(10, math.min(18, math.floor((tonumber(db.iconSize) or 12) + 0.5)))
    db.lineGap  = math.max(2, math.min(12, math.floor((tonumber(db.lineGap) or 6) + 0.5)))
    db.pad      = math.max(4, math.min(16, math.floor((tonumber(db.pad) or 8) + 0.5)))
    if db.playerStyle ~= "text" and db.playerStyle ~= "chips" then db.playerStyle = "chips" end
    if db.align ~= "right" then db.align = "left" end
    if db.buttonStyle ~= "labels" then db.buttonStyle = "icons" end
    if db.buttonBgSpan ~= "row" then db.buttonBgSpan = "badge" end
    db.buttonBgA = math.max(0, math.min(1, tonumber(db.buttonBgA) or 0.2))
    db.buttonHoverA = math.max(0, math.min(1, tonumber(db.buttonHoverA) or 0.34))
    db.lineR = math.max(0, math.min(1, tonumber(db.lineR) or 0.6))
    db.lineG = math.max(0, math.min(1, tonumber(db.lineG) or 0.6))
    db.lineB = math.max(0, math.min(1, tonumber(db.lineB) or 0.6))
    db.chipBgA = math.max(0, math.min(1, tonumber(db.chipBgA) or 0.05))
    db.chipBorderA = math.max(0, math.min(1, tonumber(db.chipBorderA) or 0.2))
    db.flashTime = math.max(0, math.min(20, math.floor((tonumber(db.flashTime) or 5) + 0.5)))
    db.flashSpeed = math.max(1, math.min(20, math.floor((tonumber(db.flashSpeed) or 9) + 0.5)))
    db.itemIconSize = math.max(12, math.min(48, math.floor((tonumber(db.itemIconSize) or 22) + 0.5)))
    db.chipBorderSize = math.max(0, math.floor((tonumber(db.chipBorderSize) or 1) + 0.5))
    db.itemBorderSize = math.max(0, math.floor((tonumber(db.itemBorderSize) or 1) + 0.5))
    db.itemBorderA = math.max(0, math.min(1, tonumber(db.itemBorderA) or 1))
    db.barHeight = math.max(1, math.min(10, math.floor((tonumber(db.barHeight) or 2) + 0.5)))
    db.borderSize = math.max(0, tonumber(db.borderSize) or 1)
    db.bgA = math.max(0, math.min(1, tonumber(db.bgA) or 0.97))
    db.borderA = math.max(0, math.min(1, tonumber(db.borderA) or 1))
    return db
end
function ns.Cfg() return EnsureDB() end

function ns.Reset()
    EnsureDB()
    for k, v in pairs(DEFAULTS) do db[k] = v end
    ns.Apply()
end

-------------------------------------------------------------------------------
--  Roll state
-------------------------------------------------------------------------------
local ROLL_PASS, ROLL_NEED, ROLL_GREED = 0, 1, 2
ns.ROLL_PASS, ns.ROLL_NEED, ns.ROLL_GREED = ROLL_PASS, ROLL_NEED, ROLL_GREED

local STATE = (Enum and Enum.EncounterLootDropRollState)
    or { NeedMainSpec = 0, NeedOffSpec = 1, Transmog = 2, Greed = 3, NoRoll = 4, Pass = 5 }

local rolls = {}   -- rollID (or preview key) -> entry
local blockedThisSession = false
local fallbackShown = false

local function HistoryNow()
    if not (C_LootHistory and C_LootHistory.GetLootHistoryTime) then return nil end
    local ok, t = pcall(C_LootHistory.GetLootHistoryTime)
    return ok and tonumber(plain(t)) or nil
end

local function RollTimeLeft(e)
    if e.fake then return math.max(0, (e.deadline - GetTime()) * 1000) end
    if e.finished then return 0 end
    if GetLootRollTimeLeft then
        local ok, left = pcall(GetLootRollTimeLeft, e.id)
        left = ok and tonumber(plain(left)) or nil
        if left then return left end
    end
    return math.max(0, (e.deadline - GetTime()) * 1000)
end
ns.TimeLeft = RollTimeLeft

-- The item's link, name and whether you may need or greed it. A roll's item
-- can still be locked when the roll starts, so this also runs again later.
function ns.ReadRollItem(e)
    if GetLootRollItemLink and not e.link then
        local ok, link = pcall(GetLootRollItemLink, e.id)
        if ok then e.link = plain(link) end
    end
    if GetLootRollItemInfo and not e.texture then
        local ok, texture, name, _, quality, _, canNeed, canGreed = pcall(GetLootRollItemInfo, e.id)
        if ok then
            e.texture = plain(texture) or nil
            e.name = plain(name) or e.name
            e.quality = tonumber(plain(quality)) or e.quality
            if canNeed ~= nil then e.canNeed = plain(canNeed) ~= false end
            if canGreed ~= nil then e.canGreed = plain(canGreed) ~= false end
        end
    end
end

function ns.GetEntry(id) return rolls[id] end

local function FinishRoll(id)
    local e = rolls[id]
    if not e or e.finished then return end
    e.finished = true
    e.finishedAt = GetTime()
    -- The samples are a look, not a live roll: never leave one waiting for a
    -- distribution the game will not send.
    if e.fake then e.resolvedAt = e.finishedAt end
end

-------------------------------------------------------------------------------
--  Loot history (our copy of the game's, refreshed on its own events)
-------------------------------------------------------------------------------
local hist = { list = {}, byKey = {}, dead = 0, built = 0 }

local function DropKey(d)
    local k = plain(d.lootListKey)
    if k == nil then k = plain(d.lootListID) end
    if k == nil then return nil end
    return (d.encID or 0) .. ":" .. tostring(k)
end

local function Compact()
    if hist.dead < 24 then return end
    local list = {}
    for _, d in ipairs(hist.list) do
        if not d.dead then list[#list + 1] = d end
    end
    hist.list, hist.dead = list, 0
end

local function UpsertDrop(d, eid)
    d.encID = eid
    local key = DropKey(d)
    if not key then return false end
    local old = hist.byKey[key]
    if old and old ~= d then
        old.dead = true
        hist.dead = hist.dead + 1
    elseif old == d then
        return true -- same table handed back: nothing changed
    end
    hist.byKey[key] = d
    hist.list[#hist.list + 1] = d
    return true
end

local function ReadEncounter(eid)
    local ok, list = pcall(C_LootHistory.GetSortedDropsForEncounter, eid)
    if not ok or type(list) ~= "table" then return false end
    for _, d in ipairs(list) do
        if plain(d.itemHyperlink) then UpsertDrop(d, eid) end
    end
    Compact()
    return true
end

local function BuildHistory()
    hist.list, hist.byKey, hist.dead = {}, {}, 0
    local ok, encs = pcall(C_LootHistory.GetAllEncounterInfos)
    if not ok or type(encs) ~= "table" then return end
    for _, enc in ipairs(encs) do
        local eid = plain(enc.encounterID)
        if eid ~= nil then ReadEncounter(eid) end
    end
    hist.built = GetTime()
end

local function ReadDrop(eid, key)
    if not (C_LootHistory and C_LootHistory.GetSortedInfoForDrop) then return false end
    local ok, d = pcall(C_LootHistory.GetSortedInfoForDrop, eid, key)
    if not ok or type(d) ~= "table" or not plain(d.itemHyperlink) then return false end
    UpsertDrop(d, eid)
    Compact()
    return true
end

-- Reads the history again, at most once a second. Skipped while nothing is
-- being tracked, so an idle player pays nothing.
function ns.ScanHistory(force)
    if not (C_LootHistory and C_LootHistory.GetAllEncounterInfos and C_LootHistory.GetSortedDropsForEncounter) then return end
    if next(rolls) == nil then
        if #hist.list > 0 then hist.list, hist.byKey, hist.dead, hist.built = {}, {}, 0, 0 end
        return
    end
    local now = GetTime()
    if not force and (now - hist.built) < 1 then return end
    BuildHistory()
end

-------------------------------------------------------------------------------
--  Matching a roll to its history drop
-------------------------------------------------------------------------------
local function Payload(link)
    link = plain(link)
    if type(link) ~= "string" then return nil end
    return link:match("|H(item:[^|]+)|h") or link
end

local function SameItem(a, b)
    local pa, pb = Payload(a), Payload(b)
    return pa ~= nil and pa == pb
end

-- Drop start times and durations are on the loot history's own clock, in the
-- same units as the value it reports for "now".
local function DropFits(e, d)
    local st, dur = tonumber(plain(d.startTime)), tonumber(plain(d.duration))
    local hs = e.histStart
    if not (hs and st and dur) then return true end
    if st > hs + dur / 10 then return false end -- a later copy of the same item
    return st >= hs - dur
end

-- A history drop's recorded choice for you: playerRollState, else your row
-- in its roll list.
local function SelfState(d)
    if not d then return nil end
    local st = plain(d.playerRollState)
    if st == nil then
        local infos = d.rollInfos
        if type(infos) == "table" then
            for _, r in ipairs(infos) do
                if plain(r.isSelf) then st = plain(r.state); break end
            end
        end
    end
    return st
end

local ChoiceOfState, HistoryChoice

-- The newest unclaimed history drop that can belong to this roll.
-- wantChoice narrows it to a copy whose record is the choice you made.
local function CandidateDrop(e, claimed, wantChoice)
    local best, bestKey, bestStart
    for key, d in pairs(hist.byKey) do
        if not claimed[key] and not d.dead and SameItem(d.itemHyperlink, e.link) and DropFits(e, d)
            and (not wantChoice or HistoryChoice(d) == wantChoice) then
            local st = tonumber(plain(d.startTime)) or 0
            if not best or st > bestStart then
                best, bestKey, bestStart = d, key, st
            end
        end
    end
    return best, bestKey
end

local function MatchDrops()
    local claimed, order = {}, {}
    for _, e in pairs(rolls) do order[#order + 1] = e end
    table.sort(order, function(a, b) return (a.startedAt or 0) < (b.startedAt or 0) end)
    for _, e in ipairs(order) do
        if e.fake then
            e.drop = e.fakeDrop
        else
            e.drop = nil
        end
    end
    -- With two copies of one item the game can record your roll on either.
    -- Rolls you clicked bind to the copy carrying that choice first, so the
    -- copy you have not rolled on keeps its buttons.
    for _, e in ipairs(order) do
        if not e.fake and not e.drop and e.link and e.myChoice and next(hist.byKey) ~= nil then
            local best, bestKey = CandidateDrop(e, claimed, e.myChoice)
            if best then claimed[bestKey] = true; e.drop = best end
        end
    end
    for _, e in ipairs(order) do
        if not e.fake and not e.drop and e.link and next(hist.byKey) ~= nil then
            local best, bestKey = CandidateDrop(e, claimed, nil)
            if best then claimed[bestKey] = true; e.drop = best end
        end
    end
end

-------------------------------------------------------------------------------
--  Display model
-------------------------------------------------------------------------------
function ChoiceOfState(st)
    if st == nil or st == STATE.NoRoll then return nil end
    if st == STATE.Pass then return ROLL_PASS end
    if st == STATE.NeedMainSpec or st == STATE.NeedOffSpec then return ROLL_NEED end
    return ROLL_GREED -- Greed, Transmog and any other greed-style roll
end

-- Your choice as the loot history recorded it on one drop (nil = not rolled).
function HistoryChoice(d)
    return ChoiceOfState(SelfState(d))
end

-- A reload loses the local clicks. One copy can take its record back from the
-- history; with two copies, which one is yours is ambiguous, so both keep
-- their buttons.
local function AdoptHistoryChoices()
    local counts = {}
    for _, e in pairs(rolls) do
        local p = e.link and Payload(e.link)
        if p then counts[p] = (counts[p] or 0) + 1 end
    end
    for _, e in pairs(rolls) do
        if not e.myChoice and not e.fake and not e.finished then
            local p = e.link and Payload(e.link)
            if p and counts[p] == 1 then
                local ch = HistoryChoice(e.drop)
                if ch then
                    e.myChoice, e.myChoiceAt = ch, GetTime()
                end
            end
        end
    end
end

local function RollGroups(d)
    local groups = { [ROLL_NEED] = {}, [ROLL_GREED] = {}, [ROLL_PASS] = {} }
    local waiting = {}
    local infos = d.rollInfos
    if type(infos) == "table" then
        for _, r in ipairs(infos) do
            local st = plain(r.state)
            local choice = ChoiceOfState(st)
            if choice then
                groups[choice][#groups[choice] + 1] = r
            else
                waiting[#waiting + 1] = r
            end
        end
    end
    for _, list in pairs(groups) do
        table.sort(list, function(a, b)
            return (tonumber(plain(a.roll)) or 0) > (tonumber(plain(b.roll)) or 0)
        end)
    end
    return groups, waiting
end

local function WinnerOf(d)
    local w = d.winner
    if type(w) ~= "table" then
        local infos = d.rollInfos
        if type(infos) == "table" then
            for _, r in ipairs(infos) do
                if plain(r.isWinner) then w = r; break end
            end
        end
    end
    if type(w) ~= "table" then return nil end
    -- The window reads winner rows with the same fields as rollInfos rows
    -- (ShortName/NameList expect playerName and playerClass).
    return {
        playerName  = plain(w.playerName) or plain(w.name),
        playerClass = plain(w.playerClass) or plain(w.class),
        roll        = tonumber(plain(w.roll)),
        isSelf      = plain(w.isSelf),
    }
end

local function ItemName(e)
    local link = e.link
    if link then
        local n = link:match("%[(.-)%]")
        if n and n ~= "" then return n end
    end
    return plain(e.name) or "Loot roll"
end

local function MyChoice(e)
    -- What you clicked wins over the history: with two copies of an item the
    -- recorded choice can sit on the other copy.
    if e.myChoice then return e.myChoice end
    return HistoryChoice(e.drop)
end

local function Rank(m)
    if m.active and not m.myChoice then return 1 end
    if m.active then return 2 end
    if not m.resolved then return 3 end -- finished, waiting for the award
    return 4
end

local function BuildModel()
    local cfg = EnsureDB()
    local out = {}
    for id, e in pairs(rolls) do
        local left = RollTimeLeft(e)
        local m = {
            id         = id,
            link       = e.link,
            texture    = e.texture,
            quality    = e.quality,
            name       = ItemName(e),
            active     = not e.finished,
            finished   = e.finished,
            secondsLeft = left > 0 and math.ceil(left / 1000) or 0,
            fraction   = (e.duration and e.duration > 0) and math.max(0, math.min(1, left / e.duration)) or nil,
            myChoice   = MyChoice(e),
            canNeed    = e.canNeed ~= false,
            canGreed   = e.canGreed ~= false,
            choiceFade = e.choiceFadeAt,
            startedAt  = e.startedAt or 0,
            resolved   = e.resolvedAt ~= nil,
            fake       = e.fake,
        }
        if e.drop then
            local groups, waiting = RollGroups(e.drop)
            m.groups = groups
            m.waiting = waiting
            m.winner = WinnerOf(e.drop)
            m.allPassed = e.drop.allPassed == true
        end
        out[#out + 1] = m
    end
    table.sort(out, function(a, b)
        local ra, rb = Rank(a), Rank(b)
        if ra ~= rb then return ra < rb end
        return a.startedAt < b.startedAt
    end)
    return out
end

-------------------------------------------------------------------------------
--  Ticker: only while a roll or its results are on screen
-------------------------------------------------------------------------------
local driver = EUI.Tick.NewDriver(CreateFrame("Frame"))
local TICK = ADDON
local tickAcc = 0
local OnTick, ShowNow, eventFrame

local function ReconcileChoices()
    local now = GetTime()
    for _, e in pairs(rolls) do
        if e.myChoice and not e.finished and e.drop and (now - (e.myChoiceAt or 0)) > 8 then
            local st = plain(e.drop.playerRollState)
            if st == nil then
                for _, r in ipairs(e.drop.rollInfos or {}) do
                    if plain(r.isSelf) then st = plain(r.state); break end
                end
            end
            -- The game never recorded it (a bind-on-pickup dialog was cancelled
            -- or the roll was refused): offer the buttons again.
            if st == STATE.NoRoll then
                e.myChoice = nil
                if not e.fake then
                    print("|cffffd100Loot Rolls:|r your roll on " .. ItemName(e) .. " didn't go through. Pick again.")
                end
            end
        end
    end
end

-- The loot history knows who got the item, or that nobody rolled for it.
local function DropDistributed(d)
    if not d then return false end
    if plain(d.winner) ~= nil then return true end
    return plain(d.allPassed) == true
end

-- Stamps the moment the item was distributed, so a finished row stays until
-- then instead of timing out straight after the roll.
local function NoteResolutions()
    local now = GetTime()
    for _, e in pairs(rolls) do
        if not e.resolvedAt and e.drop and DropDistributed(e.drop) then
            e.resolvedAt = now
        end
    end
end

function ns.Refresh(force)
    if not EnsureDB().enabled then
        ShowNow()
        return
    end
    for _, e in pairs(rolls) do
        if not e.fake and (not e.link or not e.texture) then ns.ReadRollItem(e) end
    end
    ns.ScanHistory(force)
    MatchDrops()
    AdoptHistoryChoices()
    ReconcileChoices()
    NoteResolutions()
    ShowNow()
end

ShowNow = function()
    local model = BuildModel()
    if #model == 0 or ns.Window.Dismissed then
        ns.Window.Hide()
        driver.Remove(TICK)
    else
        ns.Window.Show(model)
        driver.Add(TICK, OnTick)
    end
end

-- A roll ends before the game says who got the item. The row waits for that
-- answer (refreshed once a second), then keeps it for the linger time. A
-- history that never answers gives up after a minute.
local WAIT_UNRESOLVED = 60
local lastRescan = 0

local function RemoveNow(e, now)
    if not e.finished then return false end
    local since = e.finishedAt or now
    if e.resolvedAt then
        return now - math.max(since, e.resolvedAt) > (db.linger or 10)
    end
    return now - since > WAIT_UNRESOLVED
end

local function PreviewAdvance(now)
    local changed = false
    for _, e in pairs(rolls) do
        local steps = e.previewSteps
        if e.fake and steps and not e.finished then
            while e.previewIndex < #steps and now >= e.previewAt + steps[e.previewIndex + 1].at do
                e.previewIndex = e.previewIndex + 1
                steps[e.previewIndex].run(e)
                if e.previewResolve then e.previewResolve() end
                changed = true
            end
        end
    end
    return changed
end

OnTick = function(dt)
    tickAcc = tickAcc + dt
    if tickAcc < 0.1 then return end
    tickAcc = 0
    local changed = false
    for id, e in pairs(rolls) do
        if not e.finished and RollTimeLeft(e) <= 0 then
            FinishRoll(id)
            changed = true
        end
    end
    local now = GetTime()
    if PreviewAdvance(now) then changed = true end
    local removed = false
    local waiting = false
    for id, e in pairs(rolls) do
        if RemoveNow(e, now) then
            rolls[id] = nil
            removed = true
        elseif e.finished and not e.resolvedAt then
            waiting = true
        end
    end
    if changed or removed then
        ns.Refresh()
    elseif waiting and now - lastRescan >= 1 then
        lastRescan = now
        ns.Refresh() -- pick up a distribution whose history event we missed
    else
        ns.Window.Timers()
    end
end

-------------------------------------------------------------------------------
--  Rolling
-------------------------------------------------------------------------------
function ns.Roll(id, choice)
    local e = rolls[id]
    if not e or e.finished or (e.myChoice and not e.fake) then return end
    if e.fake then
        e.myChoice, e.myChoiceAt = choice, GetTime()
        e.choiceFadeAt = e.myChoiceAt
        if e.fakeDrop then
            local st = (choice == ROLL_NEED and STATE.NeedMainSpec)
                or (choice == ROLL_GREED and STATE.Greed) or STATE.Pass
            e.fakeDrop.playerRollState = st
            for _, r in ipairs(e.fakeDrop.rollInfos or {}) do
                if r.isSelf then r.state = st; r.previewRoll = 87; r.roll = nil end
            end
            if e.previewResolve then e.previewResolve() end
        end
        ns.Refresh()
        return
    end
    local ok, err = pcall(RollOnLoot, id, choice)
    if not ok then
        ns.FallBack("Couldn't roll from the window (" .. tostring(err) .. ").")
        return
    end
    e.myChoice, e.myChoiceAt = choice, GetTime()
    e.choiceFadeAt = e.myChoiceAt
    ns.Refresh()
end

-------------------------------------------------------------------------------
--  Blizzard's own roll popups
-------------------------------------------------------------------------------
local hider, hiddenFrames = nil, {}

local function BlizzardHidden(hide)
    hide = hide and not blockedThisSession
    if hide and not hider then
        hider = CreateFrame("Frame", nil, UIParent)
        hider:Hide()
    end
    for i = 1, 10 do
        local f = _G["GroupLootFrame" .. i]
        if not f then break end
        local rec = hiddenFrames[f]
        if hide then
            if not rec then
                rec = { parent = f:GetParent(), mouse = (f.IsMouseEnabled and f:IsMouseEnabled()) or true }
                hiddenFrames[f] = rec
                pcall(f.SetParent, f, hider)
                pcall(f.EnableMouse, f, false)
            end
        elseif rec then
            pcall(f.SetParent, f, rec.parent or UIParent)
            pcall(f.EnableMouse, f, rec.mouse ~= false)
            hiddenFrames[f] = nil
        end
    end
end

function ns.FallBack(reason)
    blockedThisSession = true
    BlizzardHidden(false)
    if fallbackShown then return end
    fallbackShown = true
    print("|cffffd100Loot Rolls:|r " .. tostring(reason) .. " Blizzard's roll frames are back for this session.")
end

-------------------------------------------------------------------------------
--  Preview (the settings page's Show Samples button)
-------------------------------------------------------------------------------
-- A preview player keeps the roll number out of the model until every player
-- has picked. The game generates the numbers only after that point, so the
-- samples must wait for it too.
local function PreviewRoll(name, class, roll, state, known)
    local r = { playerName = name, playerClass = class, previewRoll = roll, state = state }
    if known then r.roll = roll end
    return r
end

local function ClearPreview()
    for id, e in pairs(rolls) do
        if e.fake then rolls[id] = nil end
    end
end
ns.ClearPreview = ClearPreview

-- Samples for the settings page: four rolls covering a small group, long
-- realm names, a raid-sized list that reduces to icons, and a distributed item.
function ns.Preview()
    EnsureDB()
    ClearPreview()
    local now = GetTime()
    local me = UnitName and UnitName("player") or "You"
    local myClass = UnitClass and select(2, UnitClass("player")) or nil

    local function Fake(key, link, texture, quality, seconds, infos, extra)
        local drop = { itemHyperlink = link, playerRollState = STATE.NoRoll, rollInfos = infos }
        local e = {
            id = key, fake = true, startedAt = now, deadline = now + seconds,
            duration = seconds * 1000, link = link, texture = texture, quality = quality,
            canNeed = true, canGreed = true, fakeDrop = drop,
        }
        if extra then
            for k, v in pairs(extra) do
                if k == "winner" then drop.winner = v
                elseif k == "allPassed" then drop.allPassed = true
                elseif k == "state" then drop.playerRollState = v
                else e[k] = v end
            end
        end
        rolls[key] = e
        return e
    end

    local function Find(e, name)
        for _, r in ipairs(e.fakeDrop.rollInfos or {}) do
            if r.playerName == name then return r end
        end
    end

    local function Decide(e, name, state, roll)
        local r = Find(e, name)
        if not r then return end
        r.state, r.previewRoll, r.roll = state, roll, nil
    end

    -- Every player has picked, so now the numbers exist.
    local function Resolve(e)
        if e.finished then return end
        local infos = e.fakeDrop and e.fakeDrop.rollInfos
        if not infos then return end
        local selfInfo
        for _, r in ipairs(infos) do
            if r.isSelf then selfInfo = r end
            if not r.isSelf and (r.state == nil or r.state == STATE.NoRoll) then return end
        end
        -- The viewer keeps a live choice. Give it one when the group resolves
        -- so the sample completes, and leave the buttons live so the choice
        -- can change. Rolls exist only after this point.
        if selfInfo and (selfInfo.state == nil or selfInfo.state == STATE.NoRoll) and not e.myChoice then
            selfInfo.state = selfInfo.autoState or STATE.Greed
            e.myChoice = selfInfo.autoChoice or ROLL_GREED
            e.myChoiceAt = GetTime()
            e.choiceFadeAt = e.myChoiceAt
            e.fakeDrop.playerRollState = selfInfo.state
        end
        for _, r in ipairs(infos) do
            if r.roll == nil and r.previewRoll ~= nil
                and r.state ~= nil and r.state ~= STATE.NoRoll then
                r.roll = r.previewRoll
            end
        end
        -- Every player has decided: the roll is over, so the result lingers
        -- and the frame closes when the linger time ends.
        e.finished = true
        e.finishedAt = GetTime()
        e.resolvedAt = e.finishedAt
    end

    local function Schedule(e, steps)
        e.previewAt = GetTime()
        e.previewIndex = 0
        e.previewResolve = function() Resolve(e) end
        e.previewSteps = steps
    end

    -- Small group, short names: two players have picked, three are still
    -- deciding. The numbers appear only when the last player picks.
    local small = Fake("preview:small",
        "|cffff8000|Hitem:19019|h[Thunderfury, Blessed Blade of the Windseeker]|h|r",
        "Interface\\Icons\\INV_Sword_39", 5, 30, {
            PreviewRoll("Thrall", "SHAMAN", 87, STATE.NeedMainSpec),
            PreviewRoll("Jaina", "MAGE", 42, STATE.NoRoll),
            PreviewRoll("Sylvanas", "HUNTER", 96, STATE.Greed),
            PreviewRoll("Cairne", "WARRIOR", 55, STATE.NoRoll),
            { playerName = me, playerClass = myClass, isSelf = true, state = STATE.NoRoll,
              previewRoll = 73, autoState = STATE.NeedMainSpec, autoChoice = ROLL_NEED },
        })
    Schedule(small, {
        { at = 5.0, run = function(e) Decide(e, "Jaina", STATE.NeedMainSpec, 42) end },
        { at = 10.0, run = function(e) Decide(e, "Cairne", STATE.Pass, 55) end },
    })

    -- Long realm names: the second step (first name only) takes over while
    -- the last players pick.
    local long = Fake("preview:long",
        "|cffff8000|Hitem:17182|h[Sulfuras, Hand of Ragnaros]|h|r",
        "Interface\\Icons\\INV_Hammer_Unique_Sulfuras", 5, 30, {
            PreviewRoll("Maximilian-Stormrage", "PALADIN", 88, STATE.NeedMainSpec),
            PreviewRoll("Bartholomew-Khadgar", "MAGE", 64, STATE.NoRoll),
            PreviewRoll("Alexanderthegreat-Proudmoore", "WARRIOR", 41, STATE.NoRoll),
            { playerName = me, playerClass = myClass, isSelf = true, state = STATE.NoRoll,
              previewRoll = 51, autoState = STATE.Greed, autoChoice = ROLL_GREED },
        })
    Schedule(long, {
        { at = 5.0, run = function(e) Decide(e, "Bartholomew-Khadgar", STATE.NeedMainSpec, 64) end },
        { at = 10.0, run = function(e) Decide(e, "Alexanderthegreat-Proudmoore", STATE.Greed, 41) end },
    })

    -- A raid-sized list: a few have picked, the rest decide over the timer.
    -- The Need row fills, then drops to class icons and "+N" once the numbers
    -- arrive.
    local raid = Fake("preview:raid",
        "|cffff8000|Hitem:22630|h[Atiesh, Greatstaff of the Guardian]|h|r",
        "Interface\\Icons\\INV_Staff_Medivh", 5, 30, {
            PreviewRoll("Maximilian-Stormrage", "PALADIN", 99, STATE.NeedMainSpec),
            PreviewRoll("Konstantinos-Area52", "PRIEST", 84, STATE.NeedMainSpec),
            PreviewRoll("Ignatius-Ravencrest", "ROGUE", 79, STATE.NeedMainSpec),
            PreviewRoll("Ophelia-EmeraldDream", "MAGE", 51, STATE.NeedMainSpec),
            PreviewRoll("Leopold-KelThuzad", "ROGUE", 29, STATE.Greed),
            PreviewRoll("Gwendolyn-Azshara", "DRUID", 12, STATE.Pass),
            PreviewRoll("Bartholomew-Khadgar", "MAGE", 91, STATE.NoRoll),
            PreviewRoll("Alexanderthegreat-Proudmoore", "WARRIOR", 88, STATE.NoRoll),
            PreviewRoll("Sebastian-Tichondrius", "WARLOCK", 72, STATE.NoRoll),
            PreviewRoll("Wilhelmina-MoonGuard", "DRUID", 66, STATE.NoRoll),
            PreviewRoll("Cassandra-Silvermoon", "HUNTER", 58, STATE.NoRoll),
            PreviewRoll("Montgomery-Dalaran", "SHAMAN", 47, STATE.NoRoll),
            PreviewRoll("Evangeline-ShatteredHand", "PALADIN", 35, STATE.NoRoll),
            { playerName = me, playerClass = myClass, isSelf = true, state = STATE.NoRoll,
              previewRoll = 61, autoState = STATE.NeedMainSpec, autoChoice = ROLL_NEED },
        })
    Schedule(raid, {
        { at = 4.0, run = function(e)
            Decide(e, "Bartholomew-Khadgar", STATE.NeedMainSpec, 91)
            Decide(e, "Alexanderthegreat-Proudmoore", STATE.NeedMainSpec, 88)
        end },
        { at = 8.0, run = function(e)
            Decide(e, "Sebastian-Tichondrius", STATE.NeedMainSpec, 72)
            Decide(e, "Wilhelmina-MoonGuard", STATE.NeedMainSpec, 66)
        end },
        { at = 12.0, run = function(e)
            Decide(e, "Cassandra-Silvermoon", STATE.NeedMainSpec, 58)
            Decide(e, "Montgomery-Dalaran", STATE.NeedMainSpec, 47)
        end },
        { at = 16.0, run = function(e) Decide(e, "Evangeline-ShatteredHand", STATE.NeedMainSpec, 35) end },
    })

    -- Distributed: winner, and the groups at a mid-size.
    Fake("preview:done",
        "|cffa335ee|Hitem:13335|h[Deathcharger's Reins]|h|r",
        "Interface\\Icons\\Ability_Mount_Undeadhorse", 4, 60, {
            PreviewRoll("Thrall", "SHAMAN", 87, STATE.NeedMainSpec, true),
            PreviewRoll("Jaina", "MAGE", 42, STATE.NeedMainSpec, true),
            PreviewRoll("Sylvanas", "HUNTER", 96, STATE.Greed, true),
            PreviewRoll("Cairne", "WARRIOR", 55, STATE.Greed, true),
            PreviewRoll("Valeera", "ROGUE", 18, STATE.Pass, true),
            { playerName = me, playerClass = myClass, roll = 12, isSelf = true, state = STATE.Greed },
        }, {
            finished = true, finishedAt = now, myChoice = ROLL_GREED,
            state = STATE.Greed,
            winner = { playerName = "Sylvanas", playerClass = "HUNTER", roll = 96 },
        })

    ns.Window.Dismissed = false
    ns.Window.Init()
    MatchDrops()
    NoteResolutions()
    ShowNow()
end

-------------------------------------------------------------------------------
--  Apply / events
-------------------------------------------------------------------------------
local ACTIVE_EVENTS = {
    "PLAYER_ENTERING_WORLD", "START_LOOT_ROLL", "CANCEL_LOOT_ROLL", "CANCEL_ALL_LOOT_ROLLS",
    "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_UPDATE_ENCOUNTER", "LOOT_HISTORY_CLEAR_HISTORY",
    "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
}

local function LoadActiveRolls()
    if not GetActiveLootRollIDs then return end
    local ok, ids = pcall(GetActiveLootRollIDs)
    if not ok or type(ids) ~= "table" then return end
    for _, id in ipairs(ids) do
        id = plain(id)
        if id ~= nil and not rolls[id] then
            local duration
            if C_Loot and C_Loot.GetLootRollDuration then
                local ok2, d = pcall(C_Loot.GetLootRollDuration, id)
                duration = ok2 and tonumber(plain(d)) or nil
            end
            ns.StartRoll(id, duration)
        end
    end
end

function ns.StartRoll(rollID, rollTime)
    local e = {
        id = rollID, startedAt = GetTime(), histStart = HistoryNow(),
        duration = tonumber(plain(rollTime)),
        canNeed = true, canGreed = true,
    }
    ns.ReadRollItem(e)
    if not e.duration and C_Loot and C_Loot.GetLootRollDuration then
        local ok, d = pcall(C_Loot.GetLootRollDuration, rollID)
        if ok then e.duration = tonumber(plain(d)) end
    end
    e.deadline = e.startedAt + (e.duration or 60000) / 1000
    rolls[rollID] = e
    ns.Window.Dismissed = false
    if db.sound and SOUNDKIT and SOUNDKIT.UI_BONUS_LOOT_ROLL_START and PlaySound then
        pcall(PlaySound, SOUNDKIT.UI_BONUS_LOOT_ROLL_START)
    end
    ns.Refresh()
end

-------------------------------------------------------------------------------
--  Unlock mode: the same mover system as the suite's own frames
-------------------------------------------------------------------------------
local unlockRegistered = false

function ns.RegisterUnlock()
    if unlockRegistered then return end
    if not (EUI.RegisterUnlockElements and EUI.MakeUnlockElement) then return end
    unlockRegistered = true

    local function place() ns.Window.Place() end
    local function unlocked()
        return EUI.IsUnlockModeActive and EUI:IsUnlockModeActive()
    end
    local function moved()
        if unlocked() and EUI.RepositionBarToMover then
            pcall(EUI.RepositionBarToMover, ADDON)
        end
    end

    local ok = pcall(function()
        EUI:RegisterUnlockElements({ EUI.MakeUnlockElement({
            key   = ADDON,
            label = "Loot Rolls",
            group = "Loot Rolls",
            order = 740,
            -- One spot for every spec, and no links: the window is only on
            -- screen while a roll is running.
            noSpecLayout = true,
            noAnchorTarget = true,
            noAnchorTo = true,
            noSizeMatchTarget = true,
            getFrame = function() return ns.Window.EnsureAnchor() end,
            getSize = function() return ns.Window.Size() end,
            isHidden = function() return not EnsureDB().enabled end,
            moverTooltip = "Drag to move the loot roll window. Resize its width here; its height follows the rolls shown.",
            setWidth = function(_, w)
                local c = EnsureDB()
                c.width = math.max(240, math.min(460, math.floor((tonumber(w) or 300) + 0.5)))
                ns.Window.SetWidth(c.width)
                ns.Refresh()
                moved()
            end,
            savePos = function(_, point, relPoint, x, y)
                if not point then return end
                local c = EnsureDB()
                c.posPoint, c.posRelPoint = point, relPoint or point
                c.posX, c.posY = x or 0, y or 0
                if not unlocked() then place() end
            end,
            loadPos = function()
                local c = EnsureDB()
                return { point = c.posPoint, relPoint = c.posRelPoint,
                         x = c.posX or 0, y = c.posY or 0 }
            end,
            clearPos = function()
                local c = EnsureDB()
                c.posPoint, c.posRelPoint = DEFAULTS.posPoint, DEFAULTS.posRelPoint
                c.posX, c.posY = DEFAULTS.posX, DEFAULTS.posY
                place()
            end,
            applyPos = place,
            onLiveMove = function() ns.Window.FollowAnchor() end,
        }) }, ADDON)

        if EUI.RegisterUnlockModeListener then
            EUI:RegisterUnlockModeListener(ADDON, function(active)
                if not active then place() end
            end)
        end
    end)
    if not ok then unlockRegistered = false end
end

function ns.Apply()
    local cfg = EnsureDB()
    if cfg.enabled then
        for _, ev in ipairs(ACTIVE_EVENTS) do pcall(eventFrame.RegisterEvent, eventFrame, ev) end
        ns.Window.Init()
        ns.Window.Place()
        BlizzardHidden(cfg.hideBlizzard)
        LoadActiveRolls()
        ns.Refresh(true)
    else
        for _, ev in ipairs(ACTIVE_EVENTS) do pcall(eventFrame.UnregisterEvent, eventFrame, ev) end
        BlizzardHidden(false)
        driver.Remove(TICK)
        ClearPreview()
        wipe(rolls)
        hist.list, hist.byKey, hist.dead, hist.built = {}, {}, 0, 0
        ns.Window.Hide()
    end
end

local function OnEvent(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        eventFrame:UnregisterEvent("ADDON_LOADED")
        EnsureDB()
        ns.RegisterUnlock()
        ns.Apply()
        return
    end

    if not EnsureDB().enabled then return end

    if event == "START_LOOT_ROLL" then
        BlizzardHidden(db.hideBlizzard)
        local rollID = plain(arg1)
        if rollID ~= nil and not rolls[rollID] then
            ns.StartRoll(rollID, arg2)
        end
    elseif event == "CANCEL_LOOT_ROLL" then
        FinishRoll(plain(arg1))
        ns.Refresh()
    elseif event == "CANCEL_ALL_LOOT_ROLLS" then
        for id, e in pairs(rolls) do
            if not e.fake then FinishRoll(id) end
        end
        ns.Refresh()
    elseif event == "LOOT_HISTORY_UPDATE_DROP" then
        local eid, key = plain(arg1), plain(arg2)
        local read = false
        if type(eid) == "number" and key ~= nil then
            read = ReadDrop(eid, key)
        end
        if not read then hist.built = 0 end
        ns.Refresh()
    elseif event == "LOOT_HISTORY_UPDATE_ENCOUNTER" then
        local eid = plain(arg1)
        local read = false
        if type(eid) == "number" and hist.built > 0 then
            read = ReadEncounter(eid)
        end
        if not read then hist.built = 0 end
        ns.Refresh()
    elseif event == "LOOT_HISTORY_CLEAR_HISTORY" then
        hist.list, hist.byKey, hist.dead, hist.built = {}, {}, 0, 0
        ns.Refresh()
    elseif event == "PLAYER_ENTERING_WORLD" then
        BlizzardHidden(db.hideBlizzard)
        LoadActiveRolls()
        ns.Refresh()
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if arg1 == ADDON then
            ns.FallBack("The game blocked " .. tostring(arg2) .. ".")
        end
    end
end

eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("ADDON_LOADED")

-- Blizzard's bind-on-pickup dialog calls ConfirmLootRoll when it is accepted;
-- that is when the roll was really placed.
if hooksecurefunc and ConfirmLootRoll then
    pcall(hooksecurefunc, "ConfirmLootRoll", function(rollID, rollType)
        local e = rolls[plain(rollID) or false]
        local choice = plain(rollType)
        if e and choice then
            e.myChoice, e.myChoiceAt = choice, GetTime()
            ns.Refresh()
        end
    end)
end

-------------------------------------------------------------------------------
--  Slash commands
-------------------------------------------------------------------------------
SLASH_LOOTROLLFRAMES1 = "/lootrolls"
SLASH_LOOTROLLFRAMES2 = "/lrf"
SlashCmdList.LOOTROLLFRAMES = function(msg)
    msg = tostring(msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "on" then
        EnsureDB().enabled = true
        ns.Apply()
    elseif msg == "off" then
        EnsureDB().enabled = false
        ns.Apply()
    elseif msg == "preview" or msg == "test" then
        ns.Preview()
    elseif EUI.OpenPlugin then
        EUI.OpenPlugin(ADDON)
    end
end
