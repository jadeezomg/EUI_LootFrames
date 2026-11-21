if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)
-------------------------------------------------------------------------------
--  LootRollFrames_Settings.lua
--  The plugin's page in the EllesmereUI options panel. Every row is one of
--  the panel's own widgets, so it reads and behaves like an EUI module.
-------------------------------------------------------------------------------
local ADDON, ns = ...
local EUI = _G.EllesmereUI
if not (EUI and EUI.RegisterPlugin and ns.Cfg) then return end
if EUI.IsPluginRegistered and EUI.IsPluginRegistered(ADDON) then return end

local function BuildPage(pageName, parent, yOffset)
    local W = EUI.Widgets
    local y = yOffset
    local _, h

    local function On()
        return ns.Cfg().enabled
    end

    local function Toggle(key, text, tooltip, disabled, disabledTooltip)
        local t = { type = "toggle", text = text, tooltip = tooltip,
            disabled = disabled, disabledTooltip = disabledTooltip,
            getValue = function() return ns.Cfg()[key] end,
            setValue = function(v) ns.Cfg()[key] = v; ns.Apply() end }
        return t
    end

    local function Slider(key, text, minV, maxV, step, tooltip, disabled, disabledTooltip)
        local s = { type = "slider", text = text, tooltip = tooltip,
            min = minV, max = maxV, step = step,
            disabled = disabled, disabledTooltip = disabledTooltip,
            getValue = function() return ns.Cfg()[key] end,
            setValue = function(v) ns.Cfg()[key] = v; ns.Apply() end }
        return s
    end

    ---------------------------------------------------------------------------
    --  ROLL FRAMES
    ---------------------------------------------------------------------------
    local hdr
    hdr, h = W:SectionHeader(parent, "ROLL FRAMES", y); y = y - h
    if EUI.BuildSectionUnlockJump then
        EUI.BuildSectionUnlockJump(hdr, {
            key = ADDON,
            disabled = function() return not On() end,
            disabledTooltip = "Enable Loot Roll Window",
        })
    end

    _, h = W:DualRow(parent, y,
        { type = "toggle", text = "Enable Loot Roll Window",
          tooltip = "Shows every group loot roll in this window, with Need, Greed and Pass buttons.",
          getValue = On,
          setValue = function(v) ns.Cfg().enabled = v; ns.Apply() end },
        Toggle("hideBlizzard", "Hide Blizzard's Roll Frames",
            "Hides Blizzard's own roll popups while the window is on. They come back for the rest of the session if the game ever blocks a roll made from here.",
            function() return not On() end, "Enable Loot Roll Window")
    ); y = y - h

    local playerStyles = { text = "Text", chips = "Chips" }
    local playerStyleOrder = { "text", "chips" }
    local function chipsOff()
        return not On() or ns.Cfg().playerStyle == "text"
    end
    local function chipsOffTip()
        if not On() then return "Enable Loot Roll Window" end
        return "Player Style: Chips"
    end

    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Player Style", values = playerStyles, order = playerStyleOrder,
          tooltip = "How each player is drawn: one text line or a chip. Long lists drop realms one at a time, shorten long names to two letters, then fall back to class icons with +N; hover shows the full names.",
          disabled = function() return not On() end, disabledTooltip = "Enable Loot Roll Window",
          getValue = function() return ns.Cfg().playerStyle end,
          setValue = function(v) ns.Cfg().playerStyle = v; ns.Refresh() end },
        Toggle("showRolls", "Show Roll Numbers",
            "Shows each player's roll next to their name.",
            function() return not On() end, "Enable Loot Roll Window")
    ); y = y - h

    _, h = W:DualRow(parent, y,
        Toggle("sound", "Roll Start Sound",
            "Plays a sound when a new roll starts.",
            function() return not On() end, "Enable Loot Roll Window"),
        { type = "labeledButton", text = "Preview", buttonText = "Show Samples",
          tooltip = "Shows the window with sample rolls, so the colors, size and position can be checked.",
          onClick = function() ns.Preview() end }
    ); y = y - h

    local function ColorCfg(key, text, tooltip, disabled, disabledTip)
        return { type = "colorpicker", text = text, hasAlpha = true,
            tooltip = tooltip,
            disabled = disabled or chipsOff, disabledTooltip = disabledTip or chipsOffTip,
            getValue = function()
                local c = ns.Cfg()
                return c[key .. "R"], c[key .. "G"], c[key .. "B"], c[key .. "A"] or 1
            end,
            setValue = function(r, g, b, a)
                local c = ns.Cfg()
                c[key .. "R"], c[key .. "G"], c[key .. "B"], c[key .. "A"] = r, g, b, a or 1
                ns.Refresh()
            end }
    end

    local function StyleCfg(text, texKey, sizeKey, pxKey, offsetPrefix, colorPrefix, disabled, disabledTip)
        local styleValues, styleOrder = EUI.GetBorderTextureDropdown()
        return { type = "dropdown", text = text, values = styleValues, order = styleOrder,
            tooltip = "Border style; textured styles offer width and height offsets in the dots menu.",
            disabled = disabled or chipsOff, disabledTooltip = disabledTip or chipsOffTip,
            getValue = function() return ns.Cfg()[texKey] end,
            setValue = function(v)
                local c = ns.Cfg()
                c[texKey] = v
                c[offsetPrefix .. "OffsetX"], c[offsetPrefix .. "OffsetY"] = nil, nil
                c[offsetPrefix .. "ShiftX"], c[offsetPrefix .. "ShiftY"] = nil, nil
                local color = EUI.GetBorderStyleSelectDefaults(v)
                c[colorPrefix .. "R"], c[colorPrefix .. "G"], c[colorPrefix .. "B"] = color.r, color.g, color.b
                local size = EUI.GetBorderDefaultSize and EUI.GetBorderDefaultSize(nil, v)
                if size then c[sizeKey] = size end
                c[pxKey] = false
                ns.Refresh()
                EUI:RefreshPage(true)
            end }
    end

    local function SizeCfg(text, sizeKey, texKey, pxKey, disabled, disabledTip)
        return EUI.BorderPxSliderCfg({
            text = text,
            tooltip = "0 hides this border.",
            disabled = disabled or chipsOff, disabledTooltip = disabledTip or chipsOffTip,
            getStep = function() return ns.Cfg()[sizeKey] or 0 end,
            setStep = function(v) ns.Cfg()[sizeKey] = v end,
            getTex = function() return ns.Cfg()[texKey] or "solid" end,
            getPx = function() return ns.Cfg()[pxKey] end,
            setPx = function(v) ns.Cfg()[pxKey] = v end,
            apply = function() ns.Refresh() end,
        })
    end

    local function BorderCog(region, title, classKey, texKey, sizeKey, pxKey, shiftPrefix, simple, disabled, disabledTip)
        if EUI.IsSearchPrebuild() or not EUI.BuildInlineCog then return end
        if simple then
            EUI.BuildInlineCog(region, {
                title = title,
                disabled = disabled, disabledTooltip = disabledTip,
                rows = {
                    { type = "toggle", label = "Class Colored",
                      get = function() return ns.Cfg()[classKey] == true end,
                      set = function(v) ns.Cfg()[classKey] = v; ns.Refresh() end },
                },
            })
            return
        end
        local function solid()
            local t = ns.Cfg()[texKey]
            return not t or t == "solid" or t == ""
        end
        local tip = function()
            if chipsOff() then return chipsOffTip() end
            return "This option requires a textured border."
        end
        local offsetX, offsetY = EUI.BorderOffsetCogRows({
            getTex = function() return ns.Cfg()[texKey] end,
            getStep = function() return ns.Cfg()[sizeKey] end,
            getPx = function() return ns.Cfg()[pxKey] end,
            getX = function() return ns.Cfg()[shiftPrefix .. "OffsetX"] end,
            setX = function(v) ns.Cfg()[shiftPrefix .. "OffsetX"] = v end,
            getY = function() return ns.Cfg()[shiftPrefix .. "OffsetY"] end,
            setY = function(v) ns.Cfg()[shiftPrefix .. "OffsetY"] = v end,
            apply = function() ns.Refresh() end,
            disabled = solid, disabledTooltip = tip,
        })
        local function Shift(key, label)
            return { type = "slider", label = label, min = -10, max = 10, step = 1,
                disabled = solid, disabledTooltip = tip,
                get = function() return ns.Cfg()[key] or 0 end,
                set = function(v) ns.Cfg()[key] = v; ns.Refresh() end }
        end
        EUI.BuildInlineCog(region, {
            title = title,
            disabled = disabled, disabledTooltip = disabledTip,
            rows = {
                { type = "toggle", label = "Class Colored",
                  get = function() return ns.Cfg()[classKey] == true end,
                  set = function(v) ns.Cfg()[classKey] = v; ns.Refresh() end },
                Shift(shiftPrefix .. "ShiftX", "Shift X"),
                Shift(shiftPrefix .. "ShiftY", "Shift Y"),
                offsetX, offsetY,
            },
        })
    end

    local chipRow
    chipRow, h = W:DualRow(parent, y,
        ColorCfg("chipBg", "Chip Background", "Fill colour of a player chip; the alpha is its opacity."),
        StyleCfg("Chip Border Style", "chipBorderTexture", "chipBorderSize", "chipBorderSizePx", "chipBorder", "chipBorder")
    ); y = y - h
    BorderCog(chipRow._leftRegion, "Chip Background", "chipBgClass", nil, nil, nil, nil, true, chipsOff, chipsOffTip)
    BorderCog(chipRow._rightRegion, "Chip Border", "chipBorderClass",
        "chipBorderTexture", "chipBorderSize", "chipBorderSizePx", "chipBorder", false, chipsOff, chipsOffTip)
    -- The border colour lives on its own row beside the standard size slider.
    _, h = W:DualRow(parent, y,
        ColorCfg("chipBorder", "Chip Border Color", "Border colour of a player chip; the alpha is its opacity."),
        SizeCfg("Chip Border Size", "chipBorderSize", "chipBorderTexture", "chipBorderSizePx")
    ); y = y - h

    _, h = W:Spacer(parent, y, 20); y = y - h

    ---------------------------------------------------------------------------
    --  APPEARANCE (the same border and background settings as EUI's frames)
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "APPEARANCE", y); y = y - h

    _, h = W:DualRow(parent, y,
        Toggle("outerBox", "Outer Box",
            "Draws the window background and border behind all rolls. Turn it off so each roll can stand alone.",
            function() return not On() end, "Enable Loot Roll Window"),
        Toggle("innerBox", "Inner Box",
            "Draws the background and border from this section around each roll. Turn Outer Box off for separate boxes.",
            function() return not On() end, "Enable Loot Roll Window")
    ); y = y - h

    local texs, texNames, texOrder = EUI.BuildBarTextureTables()

    local bgRow
    bgRow, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Background Texture", values = texNames, order = texOrder,
          tooltip = "Texture behind the roll list and inside each Inner Box.",
          disabled = function() return not On() end, disabledTooltip = "Enable Loot Roll Window",
          getValue = function() return ns.Cfg().bgTexture end,
          setValue = function(v) ns.Cfg().bgTexture = v; ns.Refresh() end },
        { type = "slider", text = "Background Opacity", min = 0, max = 1, step = 0.01,
          tooltip = "Opacity of the window and inner box backgrounds.",
          disabled = function() return not On() end, disabledTooltip = "Enable Loot Roll Window",
          getValue = function() return ns.Cfg().bgA end,
          setValue = function(v) ns.Cfg().bgA = v; ns.Refresh() end }
    ); y = y - h
    EUI.BuildInlineSwatches(bgRow._rightRegion, { {
        tooltip = "Background Color",
        getValue = function() local c = ns.Cfg(); return c.bgR, c.bgG, c.bgB, 1 end,
        setValue = function(r, g, b)
            local c = ns.Cfg()
            c.bgR, c.bgG, c.bgB = r, g, b
            ns.Refresh()
        end,
    } }, { disabled = function() return not On() end, disabledTooltip = "Enable Loot Roll Window" })

    local borderValues, borderOrder = EUI.GetBorderTextureDropdown()

    local function BorderOffTextured()
        local tex = ns.Cfg().borderTexture
        if not On() then return "Enable Loot Roll Window" end
        if not tex or tex == "solid" or tex == "" then return "This option requires a textured border." end
    end

    local borderRow
    borderRow, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Border Style", values = borderValues, order = borderOrder,
          tooltip = "Border around the window and each Inner Box.",
          disabled = function() return not On() end, disabledTooltip = "Enable Loot Roll Window",
          getValue = function() return ns.Cfg().borderTexture end,
          setValue = function(v)
              local c = ns.Cfg()
              c.borderTexture = v
              c.borderTextureOffset, c.borderTextureOffsetY = nil, nil
              c.borderTextureShiftX, c.borderTextureShiftY = nil, nil
              local color, behind = EUI.GetBorderStyleSelectDefaults(v)
              c.borderR, c.borderG, c.borderB, c.borderBehind = color.r, color.g, color.b, behind
              local size = EUI.GetBorderDefaultSize and EUI.GetBorderDefaultSize(nil, v)
              if size then c.borderSize = size end
              c.borderSizePx = false
              ns.Refresh()
              EUI:RefreshPage(true) -- the size and offset controls follow the style
          end },
        EUI.BorderPxSliderCfg({
            text = "Border Size",
            tooltip = "0 hides the border.",
            disabled = function() return not On() end,
            disabledTooltip = "Enable Loot Roll Window",
            getStep = function() return ns.Cfg().borderSize or 0 end,
            setStep = function(v) ns.Cfg().borderSize = v end,
            getTex = function() return ns.Cfg().borderTexture or "solid" end,
            getPx = function() return ns.Cfg().borderSizePx end,
            setPx = function(v) ns.Cfg().borderSizePx = v end,
            apply = function() ns.Refresh() end,
        })
    ); y = y - h

    if not EUI.IsSearchPrebuild() then
        local offsetX, offsetY = EUI.BorderOffsetCogRows({
            getTex = function() return ns.Cfg().borderTexture end,
            getStep = function() return ns.Cfg().borderSize end,
            getPx = function() return ns.Cfg().borderSizePx end,
            getX = function() return ns.Cfg().borderTextureOffset end,
            setX = function(v) ns.Cfg().borderTextureOffset = v end,
            getY = function() return ns.Cfg().borderTextureOffsetY end,
            setY = function(v) ns.Cfg().borderTextureOffsetY = v end,
            apply = function() ns.Refresh() end,
        })
        local function Shift(key, label)
            return { type = "slider", label = label, min = -10, max = 10, step = 1,
                get = function() return ns.Cfg()[key] or 0 end,
                set = function(v) ns.Cfg()[key] = v; ns.Refresh() end }
        end
        EUI.BuildInlineCog(borderRow._leftRegion, {
            title = "Border Options",
            disabled = function() return BorderOffTextured() ~= nil end,
            disabledTooltip = BorderOffTextured,
            rows = {
                Shift("borderTextureShiftX", "Shift X"),
                Shift("borderTextureShiftY", "Shift Y"),
                offsetX, offsetY,
                { type = "toggle", label = "Show Behind",
                  get = function() return ns.Cfg().borderBehind == true end,
                  set = function(v) ns.Cfg().borderBehind = v; ns.Refresh() end },
            },
        })
        EUI.BuildInlineSwatches(borderRow._rightRegion, { {
            tooltip = "Border Color",
            hasAlpha = true,
            getValue = function()
                local c = ns.Cfg()
                return c.borderR, c.borderG, c.borderB, c.borderA or 1
            end,
            setValue = function(r, g, b, a)
                local c = ns.Cfg()
                c.borderR, c.borderG, c.borderB, c.borderA = r, g, b, a or 1
                ns.Refresh()
            end,
        } }, {
            disabled = function() return not On() or (ns.Cfg().borderSize or 0) <= 0 end,
            disabledTooltip = function()
                if not On() then return "Enable Loot Roll Window" end
                return "Border Size"
            end,
        })
    end

    _, h = W:Spacer(parent, y, 20); y = y - h

    ---------------------------------------------------------------------------
    --  ROLL BUTTONS
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "ROLL BUTTONS", y); y = y - h

    local function LineCfg(prefix, text, tooltip)
        return { type = "colorpicker", text = text, hasAlpha = false,
            tooltip = tooltip,
            disabled = function() return not On() end, disabledTooltip = "Enable Loot Roll Window",
            getValue = function()
                local c = ns.Cfg()
                return c[prefix .. "R"], c[prefix .. "G"], c[prefix .. "B"], 1
            end,
            setValue = function(r, g, b)
                local c = ns.Cfg()
                c[prefix .. "R"], c[prefix .. "G"], c[prefix .. "B"] = r, g, b
                ns.Refresh()
            end }
    end

    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Button Style", values = { icons = "Icons", labels = "Labels" },
          order = { "icons", "labels" },
          tooltip = "Draw each roll button as its Need, Greed or Pass icon, or as a text label.",
          disabled = function() return not On() end, disabledTooltip = "Enable Loot Roll Window",
          getValue = function() return ns.Cfg().buttonStyle end,
          setValue = function(v) ns.Cfg().buttonStyle = v; ns.Refresh() end },
        Slider("iconSize", "Icon Size", 10, 64, 1,
            "Size of the roll icons, including the class icons in a crowded row.",
            function() return not On() end, "Enable Loot Roll Window")
    ); y = y - h

    local _, btnTexNames, btnTexOrder = EUI.BuildBarTextureTables()
    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Button Background", values = { badge = "Badge", row = "Full Row" },
          order = { "badge", "row" },
          tooltip = "Badge colours the open roll button. Full Row draws a band for each choice line, from the line next to the item icon, with the line spacing left open.",
          disabled = function() return not On() end, disabledTooltip = "Enable Loot Roll Window",
          getValue = function() return ns.Cfg().buttonBgSpan end,
          setValue = function(v) ns.Cfg().buttonBgSpan = v; ns.Refresh() end },
        { type = "dropdown", text = "Button Texture", values = btnTexNames, order = btnTexOrder,
          tooltip = "Texture behind an open roll button. The line colour tints it. None keeps a flat colour.",
          disabled = function() return not On() end, disabledTooltip = "Enable Loot Roll Window",
          getValue = function() return ns.Cfg().buttonBgTexture end,
          setValue = function(v) ns.Cfg().buttonBgTexture = v; ns.Refresh() end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        Slider("buttonBgA", "Background Opacity", 0, 1, 0.01,
            "Opacity of the background behind an open roll button.",
            function() return not On() end, "Enable Loot Roll Window"),
        Slider("buttonHoverA", "Hover Opacity", 0, 1, 0.01,
            "Opacity of the background while the mouse is over a roll button.",
            function() return not On() end, "Enable Loot Roll Window")
    ); y = y - h

    _, h = W:DualRow(parent, y,
        LineCfg("needLine", "Need Line Color",
            "Colour of the Need line and its roll button background. Defaults to the Need badge colour."),
        LineCfg("greedLine", "Greed Line Color",
            "Colour of the Greed line and its roll button background. Defaults to the Greed badge colour.")
    ); y = y - h

    _, h = W:DualRow(parent, y,
        LineCfg("passLine", "Pass Line Color",
            "Colour of the Pass line and its roll button background. Defaults to the Pass badge colour."),
        EUI.BlankRowCfg()
    ); y = y - h

    _, h = W:Spacer(parent, y, 20); y = y - h

    ---------------------------------------------------------------------------
    --  ITEM ROW
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "ITEM ROW", y); y = y - h

    local iconRow
    iconRow, h = W:DualRow(parent, y,
        Slider("itemIconSize", "Item Icon Size", 12, 96, 1,
            "Size of the dropped item's icon.",
            function() return not On() end, "Enable Loot Roll Window"),
        StyleCfg("Item Border Style", "itemBorderTexture", "itemBorderSize", "itemBorderSizePx",
            "itemBorder", "itemBorder", function() return not On() end, "Enable Loot Roll Window")
    ); y = y - h
    if EUI.IsSearchPrebuild() or not EUI.BuildInlineCog then
        -- no cog in the search prebuild
    else
        local function solid()
            local t = ns.Cfg().itemBorderTexture
            return not t or t == "solid" or t == ""
        end
        local tip = function()
            if not On() then return "Enable Loot Roll Window" end
            return "This option requires a textured border."
        end
        local offsetX, offsetY = EUI.BorderOffsetCogRows({
            getTex = function() return ns.Cfg().itemBorderTexture end,
            getStep = function() return ns.Cfg().itemBorderSize end,
            getPx = function() return ns.Cfg().itemBorderSizePx end,
            getX = function() return ns.Cfg().itemBorderOffsetX end,
            setX = function(v) ns.Cfg().itemBorderOffsetX = v end,
            getY = function() return ns.Cfg().itemBorderOffsetY end,
            setY = function(v) ns.Cfg().itemBorderOffsetY = v end,
            apply = function() ns.Refresh() end,
            disabled = solid, disabledTooltip = tip,
        })
        local function Shift(key, label)
            return { type = "slider", label = label, min = -10, max = 10, step = 1,
                disabled = solid, disabledTooltip = tip,
                get = function() return ns.Cfg()[key] or 0 end,
                set = function(v) ns.Cfg()[key] = v; ns.Refresh() end }
        end
        EUI.BuildInlineCog(iconRow._rightRegion, {
            title = "Item Border",
            disabled = function() return not On() end,
            disabledTooltip = "Enable Loot Roll Window",
            rows = {
                { type = "toggle", label = "Use Item Quality",
                  get = function() return ns.Cfg().itemBorderQuality ~= false end,
                  set = function(v) ns.Cfg().itemBorderQuality = v; ns.Refresh() end },
                Shift("itemBorderShiftX", "Shift X"),
                Shift("itemBorderShiftY", "Shift Y"),
                offsetX, offsetY,
            },
        })
    end
    _, h = W:DualRow(parent, y,
        ColorCfg("itemBorder", "Item Border Color", "Border colour when Use Item Quality is off.",
            function() return not On() end, "Enable Loot Roll Window"),
        SizeCfg("Item Border Size", "itemBorderSize", "itemBorderTexture", "itemBorderSizePx",
            function() return not On() end, "Enable Loot Roll Window")
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Bar Texture", values = texNames, order = texOrder,
          tooltip = "Texture behind the countdown fill.",
          disabled = function() return not On() end, disabledTooltip = "Enable Loot Roll Window",
          getValue = function() return ns.Cfg().barBgTexture end,
          setValue = function(v) ns.Cfg().barBgTexture = v; ns.Refresh() end },
        Slider("barHeight", "Bar Height", 1, 30, 1,
            "Thickness of the countdown bar and its background.",
            function() return not On() end, "Enable Loot Roll Window")
    ); y = y - h

    _, h = W:Spacer(parent, y, 20); y = y - h

    ---------------------------------------------------------------------------
    --  FLASH
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "FLASH", y); y = y - h

    _, h = W:DualRow(parent, y,
        Slider("flashTime", "Flash Last", 0, 15, 1,
            "Seconds before a roll ends when its row flashes. 0 turns the flash off.",
            function() return not On() end, "Enable Loot Roll Window"),
        Slider("flashSpeed", "Flash Speed", 1, 20, 1,
            "How fast the flash pulses.",
            function() return not On() end, "Enable Loot Roll Window")
    ); y = y - h

    _, h = W:DualRow(parent, y,
        { type = "colorpicker", text = "Flash Color", hasAlpha = false,
          tooltip = "Colour of the row flash and of the countdown when a roll is about to end.",
          disabled = function() return not On() end, disabledTooltip = "Enable Loot Roll Window",
          getValue = function() local c = ns.Cfg(); return c.flashR, c.flashG, c.flashB, 1 end,
          setValue = function(r, g, b)
              local c = ns.Cfg()
              c.flashR, c.flashG, c.flashB = r, g, b
              ns.Refresh()
          end },
        EUI.BlankRowCfg()
    ); y = y - h

    _, h = W:Spacer(parent, y, 20); y = y - h

    ---------------------------------------------------------------------------
    --  LAYOUT
    ---------------------------------------------------------------------------
    _, h = W:SectionHeader(parent, "LAYOUT", y); y = y - h

    _, h = W:DualRow(parent, y,
        { type = "dropdown", text = "Window Direction", values = { left = "Left", right = "Right" },
          order = { "left", "right" },
          tooltip = "Left keeps the item icon and roll buttons on the left. Right mirrors the whole row: item icon and buttons on the right, players on the left.",
          disabled = function() return not On() end, disabledTooltip = "Enable Loot Roll Window",
          getValue = function() return ns.Cfg().align end,
          setValue = function(v) ns.Cfg().align = v; ns.Refresh() end },
        { type = "slider", text = "Window Scale", min = 50, max = 300, step = 5,
          tooltip = "Size of the window and its text.",
          disabled = function() return not On() end, disabledTooltip = "Enable Loot Roll Window",
          getValue = function() return math.floor((ns.Cfg().scale or 1) * 100 + 0.5) end,
          setValue = function(v) ns.Cfg().scale = v / 100; ns.Apply() end }
    ); y = y - h

    _, h = W:DualRow(parent, y,
        Slider("width", "Width", 240, 800, 10, "Width of the window.",
            function() return not On() end, "Enable Loot Roll Window"),
        Slider("lineGap", "Line Spacing", 2, 30, 1,
            "Space between the Need, Greed, Pass and decision rows. Larger values make every item row taller.",
            function() return not On() end, "Enable Loot Roll Window")
    ); y = y - h

    _, h = W:DualRow(parent, y,
        Slider("pad", "Inner Padding", 4, 32, 1,
            "Space between the window edge and its content, and between the item rows and the window sides.",
            function() return not On() end, "Enable Loot Roll Window"),
        Slider("maxRows", "Max Rolls", 1, 12, 1,
            "How many rolls the window shows at once. Further rolls are counted below them.",
            function() return not On() end, "Enable Loot Roll Window")
    ); y = y - h

    _, h = W:DualRow(parent, y,
        Slider("linger", "Keep Roll Results", 0, 60, 1,
            "Seconds a distributed item stays with its result. A finished roll stays until the game awards the item, even past this time.",
            function() return not On() end, "Enable Loot Roll Window"),
        { type = "labeledButton", text = "Position", buttonText = "Reset",
          tooltip = "Puts the window back in the middle of the screen. Move it with Unlock Mode, or by its header in Show Samples.",
          disabled = function() return not On() end, disabledTooltip = "Enable Loot Roll Window",
          onClick = function() ns.Window.ResetPosition(); ns.Refresh() end }
    ); y = y - h

    return math.abs(y)
end

EUI.RegisterPlugin(ADDON, {
    -- EUI gives every plugin its own sidebar section. There is no shared
    -- "Plugins" group, so the section itself is named Plugins.
    label = "Plugins",
    modules = {
        {
            key = "RollWindow",
            title = "Loot Rolls",
            description = "Need, Greed and Pass on group loot rolls, with who chose what and what they rolled.",
            pages = { "Roll Window" },
            buildPage = BuildPage,
            onReset = function() ns.Reset() end,
        },
    },
})
