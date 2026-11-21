if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  LootRollFrames_Window.lua
--  The window itself: one row per roll, its item, its countdown and its
--  Need / Greed / Pass buttons, plus who chose what and what they rolled.
--  Chest of frames only: every decision comes from LootRollFrames.lua.
-------------------------------------------------------------------------------
local ADDON, ns = ...
local EUI = _G.EllesmereUI
if not (EUI and ns.Cfg) then return end

local pcall, type, tonumber, tostring = pcall, type, tonumber, tostring
local floor, max, min, ceil = math.floor, math.max, math.min, math.ceil

local Win = {}
ns.Window = Win

local PAD, ICON, HEADER_H, BAR_H = 8, 22, 28, 2
local TEXT_W_MIN = 60
local ROLL_PASS, ROLL_NEED, ROLL_GREED = 0, 1, 2
-- Every item row is the same fixed height from the moment it is built: four
-- choice slots (Need, Greed, Pass, and the decided line) are always reserved,
-- so picking an option or new results arriving never resizes the row. The
-- choice rows double as the roll buttons, so no action row is wasted.
-- Padding, icon size and line spacing are settings; the row height follows
-- them, so a row is still fixed for a given configuration.
local LINE_H, LINE_COUNT = 13, 4
-- How long an open-choice highlight takes to fade after the viewer picks.
local CHOICE_FADE = 0.25

local function Metrics()
    local cfg = ns.Cfg()
    local pad = cfg.pad or PAD
    local icon = cfg.iconSize or 12
    local itemIcon = cfg.itemIconSize or ICON
    local lineH = max(LINE_H, icon)
    local gap = cfg.lineGap or 6
    local barH = cfg.barHeight or BAR_H
    local innerPad = (cfg.innerBox and (cfg.innerPad or 0)) or 0
    local top = 6 + 16 + barH + 4 + innerPad
    local rowH = top + LINE_COUNT * lineH + (LINE_COUNT - 1) * gap + 6 + innerPad
    -- A large item icon hangs below the name line, so the row must be at
    -- least as tall as the icon and the inner padding.
    rowH = max(rowH, 6 + innerPad + itemIcon + 6 + innerPad)
    return pad, icon, lineH, gap, barH, top, rowH
end

local win, moreText
local anchor   -- invisible frame the EllesmereUI mover moves (the window follows)
local rows, rowCount = {}, 0
local activeRows = {}   -- rows whose countdown is still running
local builtScale

local function Hex(r, g, b)
    return ("%02x%02x%02x"):format(floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

local function SetFont(fs, size, r, g, b, a)
    if EUI.ApplyModuleFont then
        pcall(EUI.ApplyModuleFont, fs, nil, size, nil)
    else
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
    end
    fs:SetTextColor(r, g, b, a or 1)
    return fs
end

local function QualityColor(q)
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then return c.r, c.g, c.b end
    return 0.8, 0.8, 0.8
end

local secretCheck = _G.issecretvalue
local function Plain(v)
    if v == nil then return nil end
    if secretCheck and secretCheck(v) then return nil end
    return v
end

local function RawName(r)
    return Plain(r and r.playerName) or "?"
end

local function ClassColorName(r, name)
    local class = Plain(r.playerClass)
    if type(class) == "string" then
        local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then
            return ("|cff%s%s|r"):format(Hex(c.r, c.g, c.b), name)
        end
    end
    return name
end

-- The name without its realm: the second step of the chip reduction.
local function PlainName(r)
    local name = RawName(r)
    if Ambiguate then
        local ok, short = pcall(Ambiguate, name, "short")
        if ok and type(short) == "string" then name = short end
    end
    return name
end

local function ShortName(r)
    return ClassColorName(r, PlainName(r))
end

local function NameList(list, showRoll)
    local parts = {}
    for i, r in ipairs(list) do
        if i > 10 then
            parts[#parts + 1] = "+" .. tostring(#list - 10) .. " more"
            break
        end
        local roll = (showRoll ~= false) and tonumber(Plain(r.roll)) or nil
        parts[#parts + 1] = ShortName(r) .. (roll and (" |cffffffff" .. tostring(roll) .. "|r") or "")
    end
    return table.concat(parts, ", ")
end

-- One badge per choice: the label in its colour, an atlas icon for a second
-- cue next to the colour, and the count so a raid-sized list still scans.
local CHOICE = {
    [0] = { label = "PASS",  color = "ffb0b0b0", atlas = "lootroll-icon-pass",
            strip = { 0.69, 0.69, 0.69 } },
    [1] = { label = "NEED",  color = "ff4dff4d", atlas = "lootroll-icon-need",
            strip = { 0.30, 1.00, 0.30 } },
    [2] = { label = "GREED", color = "ffffd100", atlas = "lootroll-icon-greed",
            strip = { 1.00, 0.82, 0.00 } },
}

-- Line and button colours follow the choice by default, and each one is
-- configurable. The summary line keeps its own strip colour.
local function LineColor(choice)
    local c = ns.Cfg()
    if choice == ROLL_NEED then
        return c.needLineR or 0.30, c.needLineG or 1.00, c.needLineB or 0.30
    elseif choice == ROLL_GREED then
        return c.greedLineR or 1.00, c.greedLineG or 0.82, c.greedLineB or 0.00
    elseif choice == ROLL_PASS then
        return c.passLineR or 0.69, c.passLineG or 0.69, c.passLineB or 0.69
    end
end

local atlasCache = {}
local function AtlasTag(name, size)
    local ok = atlasCache[name]
    if ok == nil then
        local info
        if EUI.StockAtlasInfo then
            local p, i = pcall(EUI.StockAtlasInfo, name)
            if p then info = i end
        elseif C_Texture and C_Texture.GetAtlasInfo then
            local p, i = pcall(C_Texture.GetAtlasInfo, name)
            if p then info = i end
        end
        ok = info ~= nil
        atlasCache[name] = ok
    end
    if not ok then return "" end
    return "|A:" .. name .. ":" .. size .. ":" .. size .. "|a "
end

local measure
local function Measurer()
    if measure then return measure end
    if not win then return nil end
    measure = win:CreateFontString(nil, "OVERLAY")
    SetFont(measure, 11, 1, 1, 1)
    measure:SetAlpha(0)
    measure:SetWordWrap(false)
    return measure
end

local function NamePart(r, showRoll)
    local roll = (showRoll ~= false and ns.Cfg().showRolls ~= false)
        and tonumber(Plain(r.roll)) or nil
    return ShortName(r) .. (roll and (" |cffffffff" .. tostring(roll) .. "|r") or "")
end

-- The chip's hover: the full name and roll, whatever the chip is drawing.
local function TooltipPlayer(owner, r, showRoll)
    if not (GameTooltip and r) then return end
    local roll = (showRoll ~= false) and tonumber(Plain(r.roll)) or nil
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ClassColorName(r, RawName(r)), 1, 1, 1, true)
    if roll then GameTooltip:AddLine("Roll " .. roll, 1, 1, 1) end
    GameTooltip:Show()
end

local function TextWidth(s)
    local m = Measurer()
    if not m then return #tostring(s or "") * 6 end
    m:SetText(tostring(s or ""))
    local w = m:GetStringWidth()
    m:SetText("")
    return (type(w) == "number" and w) or #tostring(s or "") * 6
end

-- One fixed line per choice: the names that fit are shown and the rest
-- collapse into "+N". The full list goes in the item tooltip, so a fixed
-- row height never hides who rolled.
local function FitList(prefix, list, width, showRoll)
    local m = Measurer()
    if not m or not width or width <= 0 then return prefix end
    local parts, rest = {}, 0
    for i, r in ipairs(list) do
        parts[#parts + 1] = NamePart(r, showRoll)
        m:SetText(prefix .. table.concat(parts, ", "))
        if m:GetStringWidth() > width then
            parts[#parts] = nil
            rest = #list - i + 1
            break
        end
    end
    m:SetText("")
    local out = prefix
    if #parts > 0 then out = out .. table.concat(parts, ", ") end
    if rest > 0 then
        out = out .. (#parts > 0 and ", " or "") .. "|cff8a8a8a+" .. rest .. "|r"
    end
    return out
end

local PLACEHOLDER = "|cff5a5a5a-|r"

local function BadgeText(label, color, count, atlas, check, size)
    size = size or 12
    local icon = ""
    if check then
        icon = ("|TInterface\\RaidFrame\\ReadyCheck-Ready:%d:%d|t "):format(size, size)
    elseif atlas then
        icon = AtlasTag(atlas, size)
    end
    local s = icon .. (color and ("|c" .. color .. label .. "|r") or label)
    if count ~= nil then
        s = s .. "  |cff8a8a8a" .. count .. "|r"
    end
    return s
end

-- Need / Greed / Pass are the atlas icon and the count only; the text label
-- is the fallback for a client without the atlases.
local function ChoiceBadge(choice, count, size, style)
    local st = CHOICE[choice]
    if style == "labels" then
        return BadgeText(st.label, st.color, count)
    end
    local icon = AtlasTag(st.atlas, size or 12)
    if icon ~= "" then
        return icon .. "|cff8a8a8a" .. count .. "|r"
    end
    return BadgeText(st.label, st.color, count)
end

-- The full choice list in the item tooltip, since a row shows one fixed line.
local function TooltipChoices(m)
    if not m or not m.groups or not GameTooltip then return end
    GameTooltip:AddLine(" ")
    for _, choice in ipairs({ 1, 2, 0 }) do
        local list = m.groups[choice]
        if list and #list > 0 then
            local st = CHOICE[choice]
            local need = m.groups[ROLL_NEED] or {}
            local showRoll = choice ~= ROLL_PASS and (choice ~= ROLL_GREED or #need == 0)
            GameTooltip:AddLine("|c" .. st.color .. st.label .. ":|r " .. NameList(list, showRoll), 1, 1, 1, true)
        end
    end
    if m.winner then
        local roll = m.winner.roll
        GameTooltip:AddLine("|cffffd100WINNER:|r " .. ShortName(m.winner)
            .. (roll and (" |cffffffff" .. tostring(roll) .. "|r") or ""), 1, 1, 1, true)
    elseif m.allPassed then
        GameTooltip:AddLine("|cff999999ALL PASSED|r", 1, 1, 1, true)
    elseif m.waiting and #m.waiting > 0 then
        GameTooltip:AddLine("|cff999999DECIDING:|r " .. NameList(m.waiting, false), 1, 1, 1, true)
    end
end

-------------------------------------------------------------------------------
--  Frame building
-------------------------------------------------------------------------------
--  EllesmereUI's own appearance settings: the background texture catalogue and
--  the live accent, so this window reads like the suite's other frames.
local backgroundTextures
local function BackgroundTextures()
    if backgroundTextures == nil then
        backgroundTextures = (EUI.BuildBarTextureTables and EUI.BuildBarTextureTables()) or false
    end
    return backgroundTextures or nil
end

local function Accent()
    local r, g, b = 0.05, 0.82, 0.62
    if EUI.GetAccentColor then
        local ok, ar, ag, ab = pcall(EUI.GetAccentColor)
        if ok and type(ar) == "number" then r, g, b = ar, ag, ab end
    end
    return r, g, b
end

local function PaintBackground(bg, cfg)
    local key = cfg.bgTexture
    local path
    if key and key ~= "none" and EUI.ResolveTexturePath then
        path = EUI.ResolveTexturePath(BackgroundTextures(), key, nil)
    end
    if path then
        bg:SetTexture(path)
        bg:SetVertexColor(cfg.bgR, cfg.bgG, cfg.bgB, cfg.bgA)
    else
        bg:SetColorTexture(cfg.bgR, cfg.bgG, cfg.bgB, cfg.bgA)
    end
end

local function PaintButtonBg(bg, r, g, b, a)
    local key = ns.Cfg().buttonBgTexture
    local path
    if key and key ~= "none" and EUI.ResolveTexturePath then
        path = EUI.ResolveTexturePath(BackgroundTextures(), key, nil)
    end
    bg._a = a
    if path then
        bg:SetTexture(path)
        bg:SetVertexColor(r, g, b, 1)
    else
        -- Clear a tint left over from a textured style, then paint the colour.
        bg:SetVertexColor(1, 1, 1, 1)
        bg:SetColorTexture(r, g, b, 1)
    end
    -- Texture alpha is applied on the region, not the vertex colour, so the
    -- opacity slider also works for a bar texture.
    bg:SetAlpha(a * (bg._fade or 1))
end

local function ApplyBackground(cfg)
    PaintBackground(win.bg, cfg)
    if cfg.outerBox == false then win.bg:Hide() else win.bg:Show() end
end

-- The border is the suite's own: solid PP borders or a textured style with the
-- same offsets, shifts and exact sizes as any other EUI frame.
local function ApplyBorderFrame(frame, cfg, behind, level)
    local size = tonumber(cfg.borderSize) or 0
    local tex = cfg.borderTexture or "solid"
    local px = (size > 0 and EUI.BorderPx and EUI.BorderPx(cfg.borderSizePx, size, tex)) or nil
    frame:SetFrameLevel(level or (behind and max(0, win:GetFrameLevel() - 1) or win:GetFrameLevel() + 2))
    if EUI.ApplyBorderStyle then
        EUI.ApplyBorderStyle(frame, size, cfg.borderR, cfg.borderG, cfg.borderB, cfg.borderA or 1, tex,
            cfg.borderTextureOffset, cfg.borderTextureOffsetY,
            cfg.borderTextureShiftX, cfg.borderTextureShiftY, nil, nil, nil, px)
    end
end

function Win.ApplyBorder(cfg)
    if not win or not win.border then return end
    ApplyBorderFrame(win.border, cfg, cfg.borderBehind == true)
    if cfg.outerBox == false then win.border:Hide() else win.border:Show() end
end

local function ApplyChrome(cfg)
    local pad = cfg.pad or PAD
    local rtl = cfg.align == "right"
    if win.title then
        win.title:ClearAllPoints()
        win.title:SetPoint(rtl and "RIGHT" or "LEFT", win.header, rtl and "RIGHT" or "LEFT", rtl and -pad or pad, 0)
        win.title:SetJustifyH(rtl and "RIGHT" or "LEFT")
    end
    if win.count then
        win.count:ClearAllPoints()
        win.count:SetPoint(rtl and "LEFT" or "RIGHT", win.header, rtl and "LEFT" or "RIGHT", rtl and 30 or -30, 0)
    end
    if win.close then
        win.close:ClearAllPoints()
        win.close:SetPoint(rtl and "TOPLEFT" or "TOPRIGHT", win, rtl and "TOPLEFT" or "TOPRIGHT", rtl and 4 or -4, -4)
    end
end

local function ApplyAppearance(cfg)
    ApplyBackground(cfg)
    local ar, ag, ab = Accent()
    if win.title then win.title:SetTextColor(ar, ag, ab) end
    ApplyChrome(cfg)
    Win.ApplyBorder(cfg)
end

local function MakeRow()
    local row = CreateFrame("Frame", nil, win)
    row:SetFrameLevel(win:GetFrameLevel() + 1)

    row.innerBg = row:CreateTexture(nil, "BACKGROUND", nil, -2)
    row.innerBg:Hide()
    row.innerBorder = CreateFrame("Frame", nil, row)
    row.innerBorder:Hide()

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 0.035)

    row.hit = CreateFrame("Frame", nil, row)
    row.hit:EnableMouse(true)
    row.hit:SetFrameLevel(row:GetFrameLevel() + 1)
    row.hit:SetScript("OnEnter", function(self)
        if self.link and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(self.link)
            TooltipChoices(row.model)
            GameTooltip:Show()
        end
    end)
    row.hit:SetScript("OnLeave", function(self)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)

    row.icon = row:CreateTexture(nil, "ARTWORK", nil, 1)
    row.icon:SetSize(ICON, ICON)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.iconBorder = CreateFrame("Frame", nil, row)
    row.iconBorder:SetFrameLevel(row:GetFrameLevel() + 1)

    row.name = SetFont(row:CreateFontString(nil, "OVERLAY"), 13, 1, 1, 1)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)
    row.name:SetMaxLines(1)

    row.time = SetFont(row:CreateFontString(nil, "OVERLAY"), 12, 0.85, 0.85, 0.85)
    row.time:SetJustifyH("RIGHT")
    row.time:SetWordWrap(false)
    row.time:SetMaxLines(1)

    row.barBg = row:CreateTexture(nil, "ARTWORK")
    row.barBg:SetColorTexture(1, 1, 1, 0.08)
    row.bar = row:CreateTexture(nil, "ARTWORK")
    row.bar:SetColorTexture(1, 1, 1, 1)

    row.lines = {}
    row.texts = {}
    row.strips = {}
    row.chips = {}
    row.moreHits = {}
    row.badgeBgs = {}
    row.choiceBtns = {}

    row.divider = row:CreateTexture(nil, "BACKGROUND")
    row.divider:SetColorTexture(1, 1, 1, 0.05)

    return row
end

local function CreateSlot(row, n)
    local strip = row:CreateTexture(nil, "ARTWORK")
    strip:SetWidth(2)
    strip:Hide()
    row.strips[n] = strip
    local badge = SetFont(row:CreateFontString(nil, "OVERLAY"), 11, 1, 1, 1)
    badge:SetJustifyH("LEFT")
    badge:SetWordWrap(false)
    badge:SetMaxLines(1)
    badge:SetHeight(LINE_H)
    local text = SetFont(row:CreateFontString(nil, "OVERLAY"), 11, 0.9, 0.9, 0.9)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetMaxLines(1)
    text:SetHeight(LINE_H)
    row.lines[n] = badge
    row.texts[n] = text
    return badge
end

function Win.Init()
    if win then return win end
    local cfg = ns.Cfg()
    local pad, _, _, _, _, _, rowH = Metrics()

    win = CreateFrame("Frame", "LootRollFramesWindow", UIParent)
    win:SetFrameStrata("MEDIUM")
    win:SetClampedToScreen(true)
    win:SetMovable(true)
    win:SetSize(cfg.width or 300, rowH + 10)
    win:SetPoint(cfg.posPoint or "CENTER", UIParent, cfg.posRelPoint or "CENTER", cfg.posX or 0, cfg.posY or 0)
    win:SetScale(cfg.scale or 1)
    builtScale = cfg.scale

    win.bg = win:CreateTexture(nil, "BACKGROUND")
    win.bg:SetAllPoints()

    win.border = CreateFrame("Frame", nil, win)
    win.border:SetAllPoints(win)
    win.border:SetFrameLevel(win:GetFrameLevel() + 2)

    win.header = CreateFrame("Frame", nil, win)
    win.header:SetPoint("TOPLEFT")
    win.header:SetPoint("TOPRIGHT")
    win.header:SetHeight(HEADER_H)
    win.header:SetFrameLevel(win:GetFrameLevel() + 2)
    win.header:EnableMouse(true)
    win.header:RegisterForDrag("LeftButton")
    win.header:SetScript("OnDragStart", function() win:StartMoving() end)
    win.header:SetScript("OnDragStop", function()
        win:StopMovingOrSizing()
        Win.SavePosition()
    end)

    local ar, ag, ab = Accent()
    win.title = SetFont(win.header:CreateFontString(nil, "OVERLAY"), 12, ar, ag, ab)
    win.title:SetPoint("LEFT", win.header, "LEFT", pad, 0)
    win.title:SetText("LOOT ROLLS")

    win.count = SetFont(win.header:CreateFontString(nil, "OVERLAY"), 11, 0.6, 0.6, 0.6)
    win.count:SetPoint("RIGHT", win.header, "RIGHT", -30, 0)

    local close = CreateFrame("Button", nil, win)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -4)
    close:SetFrameLevel(win:GetFrameLevel() + 4)
    local closeText = SetFont(close:CreateFontString(nil, "OVERLAY"), 13, 0.55, 0.55, 0.55)
    closeText:SetPoint("CENTER")
    closeText:SetText("X")
    close:SetScript("OnEnter", function() closeText:SetTextColor(1, 1, 1, 1) end)
    close:SetScript("OnLeave", function() closeText:SetTextColor(0.55, 0.55, 0.55, 1) end)
    close:SetScript("OnClick", function()
        Win.Dismissed = true
        win:Hide()
    end)

    win.close = close
    win.headerLine = win:CreateTexture(nil, "ARTWORK")
    win.headerLine:SetColorTexture(1, 1, 1, 0.06)
    win.headerLine:SetPoint("TOPLEFT", win, "TOPLEFT", 0, -HEADER_H)
    win.headerLine:SetPoint("TOPRIGHT", win, "TOPRIGHT", 0, -HEADER_H)
    win.headerLine:SetHeight(1)

    moreText = SetFont(win:CreateFontString(nil, "OVERLAY"), 11, 0.6, 0.6, 0.6)
    moreText:SetJustifyH("CENTER")
    moreText:Hide()

    return win
end

function Win.SavePosition()
    local point, relativeTo, relPoint, x, y = win:GetPoint(1)
    if type(point) ~= "string" or type(relPoint) ~= "string" then return end
    if relativeTo and relativeTo ~= UIParent then return end
    local cfg = ns.Cfg()
    cfg.posPoint, cfg.posRelPoint = point, relPoint
    cfg.posX, cfg.posY = tonumber(x) or 0, tonumber(y) or 0
    Win.PlaceAnchor()
    if EUI.RepositionBarToMover and EUI.IsUnlockModeActive and EUI:IsUnlockModeActive() then
        pcall(EUI.RepositionBarToMover, ADDON)
    end
end

-- The frame the unlock-mode mover grabs. It is invisible: the drop window
-- follows it, and the mover can place the spot even with no rolls on screen.
function Win.EnsureAnchor()
    if anchor then return anchor end
    -- Shown like the suite's anchor frames: an empty frame has no art or mouse,
    -- but a shown rect is what the movers measure and drag.
    anchor = CreateFrame("Frame", "LootRollFramesAnchor", UIParent)
    anchor:SetFrameStrata("MEDIUM")
    local w, h = Win.Size()
    anchor:SetSize(w, h)
    Win.PlaceAnchor()
    return anchor
end

function Win.PlaceAnchor()
    if not anchor then return end
    local cfg = ns.Cfg()
    anchor:ClearAllPoints()
    anchor:SetPoint(cfg.posPoint or "CENTER", UIParent, cfg.posRelPoint or "CENTER", cfg.posX or 0, cfg.posY or 0)
end

-- The size unlock mode outlines and lays out for this element: the window's
-- width, and its current (or one-row) height.
function Win.Size()
    local cfg = ns.Cfg()
    local _, _, _, _, _, _, rowH = Metrics()
    local h = (win and win:GetHeight()) or (rowH + 10)
    return cfg.width or 300, h
end

-- Unlock mode's resize sets the width even while no rolls are on screen.
function Win.SetWidth(w)
    local cfg = ns.Cfg()
    cfg.width = w
    if win then win:SetWidth(w) end
    if anchor then anchor:SetWidth(w) end
end

-- Place both the mover anchor and the window from the saved position.
function Win.Place()
    Win.PlaceAnchor()
    local cfg = ns.Cfg()
    if win then
        win:ClearAllPoints()
        win:SetPoint(cfg.posPoint or "CENTER", UIParent, cfg.posRelPoint or "CENTER", cfg.posX or 0, cfg.posY or 0)
    end
end

-- Called on every mover-driven placement, so a visible window tracks the drag.
function Win.FollowAnchor()
    if not (anchor and win and win:IsShown()) then return end
    local point, _, relPoint, x, y = anchor:GetPoint(1)
    if not point then return end
    win:ClearAllPoints()
    win:SetPoint(point, UIParent, relPoint or point, x or 0, y or 0)
end

function Win.ResetPosition()
    local cfg = ns.Cfg()
    cfg.posPoint, cfg.posRelPoint = "CENTER", "CENTER"
    cfg.posX, cfg.posY = 0, 260
    Win.Place()
    if EUI.RepositionBarToMover and EUI.IsUnlockModeActive and EUI:IsUnlockModeActive() then
        pcall(EUI.RepositionBarToMover, ADDON)
    end
end

function Win.Hide()
    if win then win:Hide() end
end

-------------------------------------------------------------------------------
--  Row layout
-------------------------------------------------------------------------------
local CHIP_PAD, CHIP_GAP = 5, 4
local MORE_W = 24 -- room kept for the "+N" tag at the right of a crowded row
local CLASS_ICON_TEX = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"

-- A player element: the fill and border follow the chip colour settings, each
-- of which may use the player's class colour.
local function ClassRGB(r)
    local class = Plain(r and r.playerClass)
    local c = type(class) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return c.r, c.g, c.b end
    return 0.75, 0.75, 0.75
end

-- Chip background and border: each is the configured colour, or the player's
-- class colour, sharing the configured alpha.
local function ChipTone(r)
    local cfg = ns.Cfg()
    local cr, cg, cb = ClassRGB(r)
    local br, bg, bb = cfg.chipBgR or 1, cfg.chipBgG or 1, cfg.chipBgB or 1
    if cfg.chipBgClass then br, bg, bb = cr, cg, cb end
    local er, eg, eb = cfg.chipBorderR or 1, cfg.chipBorderG or 1, cfg.chipBorderB or 1
    if cfg.chipBorderClass then er, eg, eb = cr, cg, cb end
    return br, bg, bb, cfg.chipBgA or 0.05, er, eg, eb, cfg.chipBorderA or 0.2
end


local function ClassIconCoords(r)
    local class = Plain(r and r.playerClass)
    return type(class) == "string" and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class] or nil
end

local function GetChip(row, index)
    local c = row.chips[index]
    if c then return c end
    c = CreateFrame("Frame", nil, row)
    c:SetFrameLevel(row:GetFrameLevel() + 1)
    c:EnableMouse(true)
    c.bg = c:CreateTexture(nil, "BACKGROUND")
    c.bg:SetAllPoints()
    c.name = SetFont(c:CreateFontString(nil, "OVERLAY"), 11, 1, 1, 1)
    c.name:SetPoint("CENTER")
    c.name:SetJustifyH("CENTER")
    c.name:SetWordWrap(false)
    c.name:SetMaxLines(1)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetPoint("CENTER")
    c.icon:SetSize(LINE_H - 2, LINE_H - 2)
    c.icon:Hide()
    c:SetScript("OnEnter", function(self) TooltipPlayer(self, self.player, self.showRoll) end)
    c:SetScript("OnLeave", function(self)
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    row.chips[index] = c
    return c
end

local function PlaceChip(row, index, r, text, x, y, w, iconMode, h, showRoll)
    h = h or LINE_H
    local c = GetChip(row, index)
    local br, bg, bb, ba, er, eg, eb, ea = ChipTone(r)
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", row, "TOPLEFT", x, -y)
    c:SetSize(w, h)
    c.bg:SetColorTexture(br, bg, bb, ba)
    -- The chip border is a normal EUI border: same styles, exact sizes,
    -- offsets and shifts as the window's.
    local cfg = ns.Cfg()
    local btex = cfg.chipBorderTexture or "solid"
    local bsize = tonumber(cfg.chipBorderSize) or 0
    local bpx = bsize > 0 and EUI.BorderPx and EUI.BorderPx(cfg.chipBorderSizePx, bsize, btex) or nil
    if EUI.ApplyBorderStyle then
        EUI.ApplyBorderStyle(c, bsize, er, eg, eb, ea, btex,
            cfg.chipBorderOffsetX, cfg.chipBorderOffsetY,
            cfg.chipBorderShiftX, cfg.chipBorderShiftY, nil, nil, nil, bpx)
    end
    c.player = r
    c.showRoll = showRoll
    if iconMode then
        c.name:Hide()
        local coords = ClassIconCoords(r)
        if coords then
            c.icon:SetSize(h - 2, h - 2)
            c.icon:SetTexture(CLASS_ICON_TEX)
            c.icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            c.icon:Show()
        else
            c.icon:Hide()
        end
    else
        c.icon:Hide()
        c.name:SetText(text)
        c.name:SetTextColor(1, 1, 1, 1)
        c.name:Show()
    end
    c:Show()
    return w
end

-------------------------------------------------------------------------------
--  Roll buttons: the choice badge itself is the button. Its icon already says
--  Need / Greed / Pass, so the choice rows double as the roll controls.
-------------------------------------------------------------------------------
local function ChoiceTip(b)
    if not GameTooltip then return end
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    if b.disabledReason then
        GameTooltip:AddLine(CHOICE[b.choice].label .. " unavailable", 1, 1, 1)
        GameTooltip:AddLine(b.disabledReason, 0.8, 0.8, 0.8, true)
    else
        GameTooltip:AddLine("Roll " .. CHOICE[b.choice].label, 1, 1, 1)
    end
    GameTooltip:Show()
end

local function GetBadgeBtn(row, slot)
    local b = row.choiceBtns[slot]
    if b then return b end
    local choice = ({ 1, 2, 0 })[slot]
    b = CreateFrame("Button", nil, row)
    b:SetFrameLevel(row:GetFrameLevel() + 2)
    b.choice = choice
    b.slot = slot
    b:SetScript("OnClick", function(self)
        if self.enabled then ns.Roll(row.rollID, choice) end
    end)
    b:SetScript("OnEnter", function(self)
        local badge = row.lines[self.slot]
        if badge then badge:SetAlpha(1) end
        local cfg = ns.Cfg()
        local bbg = row.badgeBgs[self.slot]
        if bbg and bbg:IsShown() and bbg._r then
            PaintButtonBg(bbg, bbg._r, bbg._g, bbg._b,
                self.enabled and (cfg.buttonHoverA or 0.34) or (cfg.buttonBgA or 0.2))
        end
        ChoiceTip(self)
    end)
    b:SetScript("OnLeave", function(self)
        local badge = row.lines[self.slot]
        if badge then badge:SetAlpha(self.enabled and 0.85 or 0.5) end
        local cfg = ns.Cfg()
        local bbg = row.badgeBgs[self.slot]
        if bbg and bbg:IsShown() and bbg._r then
            PaintButtonBg(bbg, bbg._r, bbg._g, bbg._b, cfg.buttonBgA or 0.2)
        end
        if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    row.choiceBtns[slot] = b
    return b
end

-- Once every player has picked, the highest Need roll wins. Greed decides
-- only when nobody needed. The game's award overrides this when it arrives.
local function WinnerFromRolls(m)
    if m.winner then return m.winner end
    if m.waiting and #m.waiting > 0 then return nil end
    local groups = m.groups or {}
    local list = groups[ROLL_NEED]
    if not list or #list == 0 then list = groups[ROLL_GREED] end
    if not list then return nil end
    local best, bestRoll
    for _, r in ipairs(list) do
        local roll = tonumber(Plain(r.roll))
        if roll and (not bestRoll or roll > bestRoll) then
            best, bestRoll = r, roll
        end
    end
    return best
end

local function LayoutRow(row, m, top)
    local cfg = ns.Cfg()
    local outerPad = (cfg.outerBox ~= false and (cfg.outerPad or 0)) or 0
    local W = win:GetWidth() - 2 * outerPad
    local pad, choiceIcon, lineH, lineGap, barH, linesTop, rowH = Metrics()
    local innerPad = (cfg.innerBox and (cfg.innerPad or 0)) or 0
    -- Inner padding moves the content in from the row box, so the base
    -- content padding grows with it.
    pad = pad + innerPad
    local topPad = 6 + innerPad
    local rtl = cfg.align == "right"
    local itemIcon = cfg.itemIconSize or ICON
    -- Distance from the leading edge (left, or right when mirrored) to the
    -- name column. Everything on the top line mirrors around it.
    local edge = pad + itemIcon + 8
    local iconX = rtl and (W - pad - itemIcon) or pad
    local timeW = 52
    local textW = max(TEXT_W_MIN, W - edge - timeW - pad)

    row.rollID = m.id
    row.hit.link = m.link
    row.hit:ClearAllPoints()
    row.hit:SetPoint("TOPLEFT", row, "TOPLEFT", pad, 0)
    row.hit:SetSize(W - pad * 2, 22)

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", win, "TOPLEFT", outerPad, -top)
    row:SetPoint("TOPRIGHT", win, "TOPRIGHT", -outerPad, -top)

    -- Each roll can carry its own box, drawn with the same background and
    -- border settings as the window.
    local innerBox = cfg.innerBox == true
    if innerBox then
        row.innerBg:ClearAllPoints()
        row.innerBg:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -2)
        row.innerBg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 2)
        PaintBackground(row.innerBg, cfg)
        row.innerBg:Show()
        row.innerBorder:ClearAllPoints()
        row.innerBorder:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -2)
        row.innerBorder:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -2, 2)
        ApplyBorderFrame(row.innerBorder, cfg, false, row:GetFrameLevel() + 3)
        row.innerBorder:Show()
    else
        row.innerBg:Hide()
        row.innerBorder:Hide()
    end
    -- The faint row band belongs to the outer box look. Separate boxes and a
    -- hidden outer box keep the row clear until the flash needs it.
    local flat = innerBox or cfg.outerBox == false
    row.bg:SetColorTexture(1, 1, 1, flat and 0 or 0.035)

    row.icon:ClearAllPoints()
    row.icon:SetPoint("TOPLEFT", row, "TOPLEFT", iconX, -topPad)
    row.icon:SetSize(itemIcon, itemIcon)
    local qr, qg, qb = QualityColor(m.quality)
    row.icon:SetTexture(m.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
    -- The item icon border is the standard EUI border, defaulting to the item's
    -- quality colour.
    local itemTex = cfg.itemBorderTexture or "solid"
    local itemSize = tonumber(cfg.itemBorderSize) or 0
    local itemPx = itemSize > 0 and EUI.BorderPx and EUI.BorderPx(cfg.itemBorderSizePx, itemSize, itemTex) or nil
    local br, bgc, bbc, ba
    if cfg.itemBorderQuality ~= false then
        br, bgc, bbc, ba = qr, qg, qb, 1
    else
        br, bgc, bbc, ba = cfg.itemBorderR or 0, cfg.itemBorderG or 0, cfg.itemBorderB or 0, cfg.itemBorderA or 1
    end
    row.iconBorder:ClearAllPoints()
    row.iconBorder:SetPoint("TOPLEFT", row.icon, "TOPLEFT", 0, 0)
    row.iconBorder:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 0, 0)
    if EUI.ApplyBorderStyle then
        EUI.ApplyBorderStyle(row.iconBorder, itemSize, br, bgc, bbc, ba, itemTex,
            cfg.itemBorderOffsetX, cfg.itemBorderOffsetY,
            cfg.itemBorderShiftX, cfg.itemBorderShiftY, nil, nil, nil, itemPx)
    end

    row.name:ClearAllPoints()
    if rtl then
        row.name:SetPoint("TOPRIGHT", row, "TOPRIGHT", -edge, -topPad)
        row.name:SetJustifyH("RIGHT")
    else
        row.name:SetPoint("TOPLEFT", row, "TOPLEFT", edge, -topPad)
        row.name:SetJustifyH("LEFT")
    end
    row.name:SetWidth(textW)
    row.name:SetText("|cff" .. Hex(qr, qg, qb) .. m.name .. "|r")

    row.time:ClearAllPoints()
    if rtl then
        row.time:SetPoint("TOPLEFT", row, "TOPLEFT", pad, -topPad)
        row.time:SetJustifyH("LEFT")
    else
        row.time:SetPoint("TOPRIGHT", row, "TOPRIGHT", -pad, -topPad)
        row.time:SetJustifyH("RIGHT")
    end
    row.time:SetWidth(timeW)
    if m.active then
        row.time:SetText(tostring(m.secondsLeft) .. "s")
        row.time:SetTextColor(1, 1, 1, 1)
    elseif m.finished then
        row.time:SetText(m.resolved and "|cff808080done|r" or "|cff808080waiting|r")
    else
        row.time:SetText("")
    end

    local y = 6 + 16 + innerPad
    row.barBg:ClearAllPoints()
    if rtl then
        row.barBg:SetPoint("TOPLEFT", row, "TOPLEFT", pad, -y)
        row.barBg:SetPoint("TOPRIGHT", row, "TOPRIGHT", -edge, -y)
    else
        row.barBg:SetPoint("TOPLEFT", row, "TOPLEFT", edge, -y)
        row.barBg:SetPoint("TOPRIGHT", row, "TOPRIGHT", -pad, -y)
    end
    row.barBg:SetHeight(barH)
    -- The roll timer drains. Once the result is lingering, the same bar
    -- fills from the other side to show how long the result stays.
    local linger = m.finished and (m.lingerDuration or 0) > 0
    row.bar:ClearAllPoints()
    if linger then
        if rtl then
            row.bar:SetPoint("TOPLEFT", row.barBg, "TOPLEFT")
        else
            row.bar:SetPoint("TOPRIGHT", row.barBg, "TOPRIGHT")
        end
    elseif rtl then
        row.bar:SetPoint("TOPRIGHT", row.barBg, "TOPRIGHT")
    else
        row.bar:SetPoint("TOPLEFT", row.barBg, "TOPLEFT")
    end
    row.bar:SetHeight(barH)
    local barKey = cfg.barBgTexture
    local barPath = barKey and barKey ~= "none" and EUI.ResolveTexturePath
        and EUI.ResolveTexturePath(BackgroundTextures(), barKey, nil)
    if barPath then
        row.barBg:SetTexture(barPath)
        row.barBg:SetVertexColor(1, 1, 1, 0.35)
    else
        row.barBg:SetColorTexture(1, 1, 1, 0.08)
    end
    local barW = W - edge - pad
    row.barW = barW
    row.bar:SetWidth(max(0.0001, barW * (linger and (m.linger or 0) or (m.fraction or 0))))
    if linger then
        local ar, ag, ab = Accent()
        row.bar:SetColorTexture(ar, ag, ab, 0.55)
    elseif (m.fraction or 1) <= 0.25 and m.active then
        row.bar:SetColorTexture(1, 0.35, 0.35, 1)
    else
        local ar, ag, ab = Accent()
        row.bar:SetColorTexture(ar, ag, ab, 1)
    end

    row.model = m
    local chipStyle = (cfg.playerStyle or "chips") ~= "text"
    local rightAlign = cfg.align == "right"

    local badgeLead = edge + 9
    local chipN = 0
    -- The chip border spills outside the chip frame; leave room for it.
    local chipOver = 2 + min(6, tonumber(cfg.chipBorderSize) or 1)

    local function Utf8Sub(s, n)
        local out, i, count = {}, 1, 0
        while i <= #s and count < n do
            local b = s:byte(i)
            local len = b < 0x80 and 1 or b < 0xE0 and 2 or b < 0xF0 and 3 or 4
            out[#out + 1] = s:sub(i, i + len - 1)
            i = i + len
            count = count + 1
        end
        return table.concat(out)
    end

    local ABBREV = { 10, 7, 5, 3, 2 }

    -- Every player gets a chain of forms, most useful first: full name, name
    -- without realm, shortened names, then the class icon. Rolls stay in
    -- every named form.
    local function BuildChips(players, showRoll)
        local chips = {}
        for i, r in ipairs(players) do
            local suffix = ""
            if showRoll then
                local roll = tonumber(Plain(r.roll))
                if roll then suffix = " |cffffffff" .. roll .. "|r" end
            end
            local short = PlainName(r)
            local stages = {}
            local function add(text, cat, icon)
                local w = icon and (lineH + 2) or (TextWidth(text) + CHIP_PAD * 2)
                local prev = stages[#stages]
                if not prev or w < prev.w then
                    stages[#stages + 1] = { text = text, w = w, cat = cat, icon = icon }
                end
            end
            add(ClassColorName(r, RawName(r)) .. suffix, 1, false)
            add(ClassColorName(r, short) .. suffix, 2, false)
            for _, limit in ipairs(ABBREV) do
                local cut = Utf8Sub(short, limit)
                if cut ~= short then
                    add(ClassColorName(r, cut .. ".") .. suffix, 3, false)
                end
            end
            add(nil, 4, true)
            chips[i] = { r = r, stages = stages, idx = 1, w = stages[1].w }
        end
        return chips
    end

    local function TotalChips(chips)
        local total = 0
        for i, c in ipairs(chips) do
            total = total + c.w + chipOver
            if i > 1 then total = total + CHIP_GAP end
        end
        return total
    end

    -- Cut realms first, one at a time, then abbreviate the longest names,
    -- then turn the rest into class icons. Each step picks the largest saving
    -- in that order, so the most useful information stays longest.
    local function FitChips(chips, areaW)
        while TotalChips(chips) > areaW do
            local lowest
            for _, c in ipairs(chips) do
                local nxt = c.stages[c.idx + 1]
                if nxt and (not lowest or nxt.cat < lowest) then lowest = nxt.cat end
            end
            if not lowest then break end
            local pick, saving
            for _, c in ipairs(chips) do
                local nxt = c.stages[c.idx + 1]
                if nxt and nxt.cat == lowest then
                    local save = c.w - nxt.w
                    if save > 0 and (not saving or save > saving
                        or (save == saving and c.w > pick.w)) then
                        pick, saving = c, save
                    end
                end
            end
            if not pick then break end
            pick.idx = pick.idx + 1
            pick.w = pick.stages[pick.idx].w
        end
    end

    local function MoreHit(n)
        local h = row.moreHits[n]
        if h then return h end
        h = CreateFrame("Frame", nil, row)
        h:EnableMouse(true)
        h:SetFrameLevel(row:GetFrameLevel() + 2)
        h:SetScript("OnEnter", function(self)
            local list = self.players
            if not (list and #list > 0 and GameTooltip) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine("Not shown", 1, 1, 1)
            for _, r in ipairs(list) do
                local roll = (self.showRoll ~= false) and tonumber(Plain(r.roll)) or nil
                GameTooltip:AddLine(ClassColorName(r, RawName(r))
                    .. (roll and (" |cffffffff" .. tostring(roll) .. "|r") or ""), 1, 1, 1, false)
            end
            GameTooltip:Show()
        end)
        h:SetScript("OnLeave", function(self)
            if GameTooltip and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        end)
        row.moreHits[n] = h
        return h
    end

    local function Slot(n, badgeText, strip, players, placeholder, choice, visibleRolls)
        local showRoll = visibleRolls ~= false
        local ly = linesTop + (n - 1) * (lineH + lineGap)
        local badge = row.lines[n] or CreateSlot(row, n)
        local text = row.texts[n]
        local band = row.strips[n]
        -- The badge's own width starts the content, so icon badges leave more
        -- room for chips than the text badge of the decision line.
        local bw = min(160, max(24, TextWidth(badgeText) + 8))
        -- Icon badges scale with Icon Size; reserve their pixels even when
        -- the text measurer does not count the texture escape.
        bw = max(bw, min(160, choiceIcon + 8))
        -- The badge sits just inside the content edge. The player area takes
        -- the remaining width, on the opposite side of the badge.
        local areaX, areaW, btnX, btnW
        if rtl then
            areaX = pad
            areaW = max(24, (W - badgeLead - bw) - pad)
            btnX = W - badgeLead - bw
        else
            areaX = badgeLead + bw
            areaW = max(24, W - areaX - pad)
            btnX = edge
        end
        btnW = 9 + bw
        -- Samples keep their buttons after the automatic pick, so the viewer
        -- can always change the choice. Real rolls hide them once picked.
        local canRoll = choice ~= nil and m.active and (not m.myChoice or m.fake)

        -- The highlight marks a choice the viewer has not made yet. Once a
        -- choice is made it fades out, and the roll buttons can stay.
        local fadeLeft = 1
        if m.myChoice then
            fadeLeft = m.choiceFade and (1 - (GetTime() - m.choiceFade) / CHOICE_FADE) or 0
        end
        local highlight = choice ~= nil and m.active and (not m.myChoice or fadeLeft > 0)
        local lr, lg, lb = LineColor(choice)
        local bbg = row.badgeBgs[n]
        if not bbg then
            bbg = row:CreateTexture(nil, "BACKGROUND")
            row.badgeBgs[n] = bbg
        end
        if highlight then
            bbg:ClearAllPoints()
            if cfg.buttonBgSpan == "row" then
                if rtl then
                    bbg:SetPoint("TOPLEFT", row, "TOPLEFT", pad, -ly)
                    bbg:SetPoint("BOTTOMRIGHT", row, "TOPLEFT", W - edge, -(ly + lineH))
                else
                    bbg:SetPoint("TOPLEFT", row, "TOPLEFT", edge, -ly)
                    bbg:SetPoint("BOTTOMRIGHT", row, "TOPLEFT", W - pad, -(ly + lineH))
                end
                PaintButtonBg(bbg, lr or strip[1], lg or strip[2], lb or strip[3], cfg.buttonBgA or 0.2)
            else
                bbg:SetPoint("TOPLEFT", row, "TOPLEFT", btnX, -ly)
                bbg:SetPoint("BOTTOMRIGHT", row, "TOPLEFT", btnX + btnW, -(ly + lineH))
                PaintButtonBg(bbg, lr or strip[1], lg or strip[2], lb or strip[3], cfg.buttonBgA or 0.2)
            end
            bbg._r, bbg._g, bbg._b = lr or strip[1], lg or strip[2], lb or strip[3]
            bbg._fade = m.myChoice and max(0, fadeLeft) or 1
            bbg:SetAlpha((bbg._a or cfg.buttonBgA or 0.2) * bbg._fade)
            bbg:Show()
        else
            bbg:Hide()
        end

        badge:ClearAllPoints()
        if rtl then
            badge:SetPoint("TOPRIGHT", row, "TOPRIGHT", -badgeLead, -ly)
        else
            badge:SetPoint("TOPLEFT", row, "TOPLEFT", badgeLead, -ly)
        end
        badge:SetWidth(bw)
        badge:SetHeight(lineH)
        badge:SetJustifyH(rtl and "RIGHT" or "LEFT")
        badge:SetText(badgeText)
        badge:Show()

        -- The choice badge is the roll button: same icon, same spot.
        local btn = row.choiceBtns[n]
        if canRoll then
            btn = GetBadgeBtn(row, n)
            local enabled = true
            if choice == ROLL_NEED and m.canNeed == false then enabled = false end
            if choice == ROLL_GREED and m.canGreed == false then enabled = false end
            btn.enabled = enabled
            btn.disabledReason = enabled and nil
                or (choice == ROLL_NEED and "You can't need this item." or "You can't greed this item.")
            btn:ClearAllPoints()
            if cfg.buttonBgSpan == "row" then
                if rtl then
                    btn:SetPoint("TOPLEFT", row, "TOPLEFT", pad, -ly)
                else
                    btn:SetPoint("TOPLEFT", row, "TOPLEFT", edge, -ly)
                end
                btn:SetSize(W - edge - pad, lineH)
            else
                btn:SetPoint("TOPLEFT", row, "TOPLEFT", btnX, -ly)
                btn:SetSize(btnW, lineH)
            end
            badge:SetAlpha(enabled and 0.85 or 0.5)
            btn:Show()
        else
            if btn then btn:Hide() end
            badge:SetAlpha(1)
        end

        band:ClearAllPoints()
        if rtl then
            band:SetPoint("TOPRIGHT", row, "TOPRIGHT", -edge, -(ly + 1))
        else
            band:SetPoint("TOPLEFT", row, "TOPLEFT", edge, -(ly + 1))
        end
        band:SetHeight(lineH - 2)
        band:SetColorTexture(lr or strip[1], lg or strip[2], lb or strip[3], 1)
        band:Show()
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", row, "TOPLEFT", areaX, -ly)
        text:SetWidth(areaW)
        text:SetHeight(lineH)
        text:SetJustifyH(rtl and "RIGHT" or "LEFT")
        local hit = row.moreHits[n]

        local count = players and #players or 0
        if count == 0 then
            text:SetText(placeholder or PLACEHOLDER)
            text:Show()
            if hit then hit:Hide() end
        elseif chipStyle then
            local chips = BuildChips(players, showRoll)
            FitChips(chips, areaW)
            local fitsAll = TotalChips(chips) <= areaW
            local right = areaX + areaW
            local reserve = fitsAll and 0 or (MORE_W + CHIP_GAP)
            local limit = right - reserve
            local leftLimit = areaX + reserve
            local x = areaX
            local rest = 0
            for i, c in ipairs(chips) do
                local w = c.w
                local stage = c.stages[c.idx]
                -- The border sits outside the chip, so its visual width is
                -- the text box plus the overhang and the last chip must stop
                -- short of the +N tag.
                if rightAlign then
                    local chipX = limit - w - chipOver
                    if chipX < leftLimit then
                        rest = #chips - i + 1
                        break
                    end
                    chipN = chipN + 1
                    PlaceChip(row, chipN, c.r, stage.icon and nil or stage.text, chipX, ly, w, stage.icon, lineH, showRoll)
                    limit = chipX - CHIP_GAP
                else
                    if x + w + chipOver > limit then
                        rest = #chips - i + 1
                        break
                    end
                    chipN = chipN + 1
                    PlaceChip(row, chipN, c.r, stage.icon and nil or stage.text, x, ly, w, stage.icon, lineH, showRoll)
                    x = x + w + chipOver + CHIP_GAP
                end
            end
            if rest > 0 then
                hit = MoreHit(n)
                hit.showRoll = showRoll
                hit.players = {}
                for j = #players - rest + 1, #players do hit.players[#hit.players + 1] = players[j] end
                -- Right alignment puts the +N at the left edge, left
                -- alignment after the last chip.
                local tagX = rightAlign and areaX or x
                local room = max(16, (rightAlign and limit or right) - tagX)
                text:ClearAllPoints()
                text:SetPoint("TOPLEFT", row, "TOPLEFT", tagX, -ly)
                text:SetWidth(room)
                text:SetJustifyH("LEFT")
                text:SetText("|cff8a8a8a+" .. rest .. "|r")
                text:Show()
                hit:ClearAllPoints()
                hit:SetPoint("TOPLEFT", row, "TOPLEFT", tagX, -ly)
                hit:SetSize(min(max(14, TextWidth("+" .. rest)), room), lineH)
                hit:Show()
            else
                text:SetText("")
                text:Hide()
                if hit then hit:Hide() end
            end
        else
            text:SetJustifyH(rightAlign and "RIGHT" or "LEFT")
            text:SetText(FitList("", players, areaW, showRoll))
            text:Show()
            if hit then hit:Hide() end
        end
    end

    -- A pass can never win, and greed only matters when no player needs the
    -- item. Hide those numbers so the row shows the rolls that decide it.
    local needGroup = (m.groups and m.groups[ROLL_NEED]) or {}
    local function RollsVisible(choice)
        if choice == ROLL_PASS then return false end
        if choice == ROLL_GREED then return #needGroup == 0 end
        return true
    end
    for slot, choice in ipairs({ 1, 2, 0 }) do
        local list = (m.groups and m.groups[choice]) or {}
        local st = CHOICE[choice]
        Slot(slot, ChoiceBadge(choice, #list, choiceIcon, cfg.buttonStyle), st.strip, list, nil, choice, RollsVisible(choice))
    end
    local winner = WinnerFromRolls(m)
    local groups = m.groups or {}
    local decided = not (m.waiting and #m.waiting > 0)
    local noContest = decided and #(groups[ROLL_NEED] or {}) == 0 and #(groups[ROLL_GREED] or {}) == 0
    local badge, stripPlayer, players
    if winner then
        badge = BadgeText("WINNER", "ffffd100", nil, nil, true, choiceIcon)
        stripPlayer = { 1.00, 0.82, 0.00 }
        players = { winner }
    elseif m.allPassed or noContest then
        badge = BadgeText("ALL PASSED", "ff999999", nil)
        stripPlayer = { 0.55, 0.55, 0.55 }
        players = {}
    elseif m.finished then
        badge = BadgeText("WAITING", "ff8a8a8a", nil)
        stripPlayer = { 0.40, 0.40, 0.40 }
        players = {}
    else
        local wait = m.waiting or {}
        badge = BadgeText("DECIDING", "ff999999", #wait)
        stripPlayer = { 0.45, 0.45, 0.45 }
        players = wait
    end
    Slot(4, badge, stripPlayer, players, nil, nil, true)

    for i = chipN + 1, #row.chips do row.chips[i]:Hide() end

    row:SetHeight(rowH)

    row.divider:ClearAllPoints()
    row.divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", pad, 0)
    row.divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -pad, 0)
    row.divider:SetHeight(1)
    if innerBox then row.divider:Hide() else row.divider:Show() end

    return rowH
end

function Win.Show(model)
    if not win then Win.Init() end
    local cfg = ns.Cfg()
    local pad = (Metrics())
    if cfg.scale ~= builtScale then
        win:SetScale(cfg.scale or 1)
        builtScale = cfg.scale
    end
    win:SetWidth(cfg.width or 300)
    ApplyAppearance(cfg)

    win:Show()

    local limit = cfg.maxRows or 4
    local total = #model
    local shown = min(total, limit)

    -- The title bar exists for the samples only: it is the drag handle for
    -- placing the window. A live roll list has no chrome above the items.
    local headerOn = false
    for i = 1, total do
        if model[i].fake then headerOn = true; break end
    end
    win.header:SetShown(headerOn)
    win.headerLine:SetShown(headerOn)
    win.close:SetShown(headerOn)

    activeRows = {}
    local outerPad = (cfg.outerBox ~= false and (cfg.outerPad or 0)) or 0
    local y = (headerOn and HEADER_H or 4) + outerPad
    for i = 1, shown do
        local m = model[i]
        local row = rows[i]
        if not row then
            row = MakeRow()
            rows[i] = row
            rowCount = i
        end
        row:Show()
        y = y + LayoutRow(row, m, y)
        if m.active then
            activeRows[#activeRows + 1] = { row = row, id = m.id }
        end
    end
    for i = shown + 1, rowCount do rows[i]:Hide() end

    if total > shown then
        moreText:ClearAllPoints()
        moreText:SetPoint("TOPLEFT", win, "TOPLEFT", pad + outerPad, -y)
        moreText:SetPoint("TOPRIGHT", win, "TOPRIGHT", -(pad + outerPad), -y)
        moreText:SetText(("+%d more roll%s"):format(total - shown, total - shown == 1 and "" or "s"))
        moreText:Show()
        y = y + 16
    else
        moreText:Hide()
    end

    win.count:SetText(total == 1 and "1 roll" or (total .. " rolls"))
    win:SetHeight(y + 6 + outerPad)
    if anchor then anchor:SetSize(win:GetWidth(), win:GetHeight()) end
end

function Win.Timers()
    if not win or not win:IsShown() then return end
    local cfg = ns.Cfg()
    local flashTime = cfg.flashTime or 5
    local fr, fg, fb = cfg.flashR or 1, cfg.flashG or 0.25, cfg.flashB or 0.25
    local pulse = 0.5 + 0.5 * math.sin(GetTime() * (cfg.flashSpeed or 9))
    -- Fade the choice highlights after a pick, including in Full Row mode.
    local now = GetTime()
    for _, row in ipairs(rows) do
        local m = row.model
        if m and m.myChoice and m.choiceFade then
            local alpha = 1 - (now - m.choiceFade) / CHOICE_FADE
            if alpha <= 0 then
                m.choiceFade = nil
                for _, bbg in pairs(row.badgeBgs) do
                    bbg._fade = 0
                    if bbg:IsShown() then bbg:Hide() end
                end
            else
                for _, bbg in pairs(row.badgeBgs) do
                    bbg._fade = alpha
                    if bbg:IsShown() then bbg:SetAlpha((bbg._a or 0.2) * alpha) end
                end
            end
        end
    end
    for _, row in ipairs(rows) do
        local m = row.model
        if m and m.finished and (m.lingerDuration or 0) > 0 and m.lingerStart then
            local frac = max(0, min(1, (now - m.lingerStart) / m.lingerDuration))
            row.bar:SetWidth(max(0.0001, (row.barW or 100) * frac))
        end
    end
    for _, rec in ipairs(activeRows) do
        local e = ns.GetEntry(rec.id)
        if e and not e.finished then
            local left = ns.TimeLeft(e)
            local secs = max(0, ceil(left / 1000))
            local frac = (e.duration and e.duration > 0) and max(0, min(1, left / e.duration)) or 0
            rec.row.time:SetText(tostring(secs) .. "s")
            rec.row.bar:SetWidth(max(0.0001, (rec.row.barW or 100) * frac))
            if flashTime > 0 and secs <= flashTime then
                -- Flash the whole item row so a roll about to close is seen.
                rec.row.time:SetTextColor(fr, fg, fb, 1)
                rec.row.bar:SetColorTexture(fr, fg, fb, 1)
                rec.row.bg:SetColorTexture(fr, fg, fb, 0.05 + 0.13 * pulse)
            else
                local ar, ag, ab = Accent()
                rec.row.time:SetTextColor(1, 1, 1, 1)
                rec.row.bar:SetColorTexture(ar, ag, ab, 1)
                rec.row.bg:SetColorTexture(1, 1, 1, (cfg.innerBox or cfg.outerBox == false) and 0 or 0.035)
            end
        end
    end
end
