# Agent rules for LootRollFrames

This repository is the source for LootRollFrames, an EllesmereUI plugin. The
main EllesmereUI repository owns the shared conventions. Read these files
first, because they apply to this repository too:

- [EllesmereUI AGENTS.md](https://github.com/EllesmereGaming/EllesmereUI/blob/main/AGENTS.md)
- [EllesmereUI CONTRIBUTING.md](https://github.com/EllesmereGaming/EllesmereUI/blob/main/.github/CONTRIBUTING.md)

This file adds the rules for the addon. If this file and the main files
disagree, the main files win. When a reviewer corrects a mistake, fix the code
and add the rule here.

## What the addon is

LootRollFrames replaces the group loot roll popups with one window. The window
shows the Need, Greed and Pass groups, who picked what, what they rolled and
the remaining time. The plugin loads only when EllesmereUI is present. The
TOC declares `Dependencies: EllesmereUI`. The core registers the plugin with
`EUI.RegisterPlugin`. The settings page is part of the EllesmereUI settings
window. Do not add a standalone options window.

## Repository layout

| File | Contents |
| --- | --- |
| `LootRollFrames.lua` | Core: defaults, SavedVariables, roll model, events, roll actions, history, plugin registration. |
| `LootRollFrames_Window.lua` | Frames, layout, borders, rows, chips, roll buttons, countdown and flash. |
| `LootRollFrames_Settings.lua` | EllesmereUI settings page. |
| `LootRollFrames.toc` | Load order, Interface ids, version, SavedVariables. |

WoW loads a TOC only from a folder with the same name as the TOC. Install the
files in `Interface/AddOns/LootRollFrames/`. The Git repository name is
`LootFrames-Ellesmere` and does not change the folder name.

## Lua and client rules

- Every file compiles under Lua 5.1. A file may have at most 200 locals in
  scope at once and 60 upvalues per function. One overflow stops the whole
  file from loading.
- Line 1 of every Lua file is
  `if EUI_CLIENT_BLOCKED then return end -- pre-12.1 client failsafe (EllesmereUI_ClientGate.lua)`.
- `LootRollFrames.lua` also stops when EUI is missing or too old:
  `if not (EUI and EUI.RegisterPlugin and EUI.Tick) then return end`.
- Lua is ASCII only, saved as UTF-8 without a BOM. Use `--` or a byte escape
  such as `\226\128\148`. Game data and quoted strings from the client are
  not translated or rewritten.
- The TOC `Interface` line lists every client that the plugin supports. Do not
  remove an id without testing that client. Add an id when EllesmereUI adds a
  supported client.
- The TOC `Version` follows semantic versioning. Patch for a fix, minor for a
  feature, major for a redesign. Do not bump the version for a change with no
  user-visible effect.

## Combat and protected frames

- Do not register a raw `PLAYER_REGEN_ENABLED` for deferred work, in any form.
  Use `EllesmereUI.CombatQueue.Defer(key, fn)` and a key that is unique to the
  work. If the deferred work is a plugin API that does not exist yet, add it
  to the main addon, not as a local event.
- Do not write to protected Blizzard frames and do not call protected
  functions from insecure code. Hook with `hooksecurefunc` and keep the work
  cosmetic.
- Do not compare, index or do arithmetic on secret values (12.x combat aura
  and unit data). Pass them straight to the widget API that accepts them.

## Deprecated globals on Forever

- Do not call globals that WoW Forever lacks. The legacy specialization
  functions and the item, socket, coin, PvP, pet, sound and trade fallbacks
  are forbidden. Use the `C_` form that the runtime error names.
- `GetSpecializationInfoByID` has no `C_` form. Test the global and fall
  through to no spec.
- `_G.X` counts as `X`. So does copying `X` into a local, storing it in a
  table, or passing it to `hooksecurefunc`.
- A test of the global, an early exit, an `IS_FOREVER` gate and the `else` of
  a test of the `C_` form are allowed. A guard carried through a variable is
  not seen, so use the `C_` form there.

## EllesmereUI UI conventions

These rules are not optional. They keep this plugin looking and behaving like
the rest of the suite.

### Settings rows

- Build rows with the EllesmereUI widgets: `W:SectionHeader`, `W:DualRow` and
  `W:Spacer`. Every row has two slots. Fill both slots unless the row is the
  last of a section. Use `EUI.BlankRowCfg()` for the empty slot.
- Every control has a tooltip that states what it changes. Every control that
  can be disabled has a `disabled` function and a `disabledTooltip` that names
  the control or mode to enable.
- Every control that changes the window calls `ns.Refresh()`. Controls that
  change frame scale, width or window chrome call `ns.Apply()`.
- Add the unlock-mode jump to the section header with
  `EUI.BuildSectionUnlockJump`.
- Keep the section order stable: behavior, appearance, item row, layout.

### Three-dot menus

Put secondary flags in a three-dot menu to the left of the control that owns
them, with `EUI.BuildInlineCog`. Do not make a standalone toggle row for a
flag that only modifies another control.

- Chip background: Class Colored.
- Chip border: Class Colored, Shift X, Shift Y, Width Offset, Height Offset.
- Item icon border: Use Item Quality, Shift X, Shift Y, Width Offset, Height
  Offset.
- Window border: Show Behind, Shift X, Shift Y, Width Offset, Height Offset.

The roll buttons live in the ROLL BUTTONS section. Button Style chooses icons
or labels. Button Background chooses Badge or Full Row, and the two opacity
sliders set the idle and hover fills. Do not hard-code those values. Badge
colours the open button by choice. Full Row draws a band for each open choice
line. The band starts at the thin line beside the item icon and keeps the
configured line spacing visible between bands. Each choice has its own line
colour. The defaults match the badge colours, and the same colour paints the
thin line and the roll button background. The three pickers live in ROLL
BUTTONS.

The choice highlight marks a roll where the viewer has not picked yet. After a
pick it fades out over a short time, in Badge and Full Row modes. Do not leave
the highlight on after the choice.

The window direction setting mirrors the whole row. Left places the item icon
and roll buttons on the left. Right places them on the right, right-justifies
the text and reverses the player order. Every element must move, not only the
chips.

The cog follows the disabled state of its control. Options that need a
textured border are disabled with the tooltip "This option requires a textured
border."

### Borders

- Draw every border with `EUI.ApplyBorderStyle(frame, size, r, g, b, a, texture, offsetX, offsetY, shiftX, shiftY, ...)`.
  Never hand-roll border textures, strips, sizes or offsets.
- Use the shared border controls for settings:
  `EUI.GetBorderTextureDropdown`, `EUI.GetBorderStyleSelectDefaults`,
  `EUI.GetBorderDefaultSize`, `EUI.BorderPx`, `EUI.BorderPxSliderCfg`
  and `EUI.BorderOffsetCogRows`.
- The size slider uses exact-size mode through `EUI.BorderPxSliderCfg`. Size
  0 hides the border.
- On a border style change, clear the offsets and shifts, seed the border
  colour from `EUI.GetBorderStyleSelectDefaults`, set the default size from
  `EUI.GetBorderDefaultSize`, clear the exact-size flag, then call
  `ns.Refresh()` and `EUI:RefreshPage(true)`.
- A class-coloured or quality-coloured border takes its colour from the player
  class or item quality. The custom colour picker is the fallback when the
  class or quality flag is off.
- The window, chip and item borders must expose the same style, size, colour,
  offset and shift controls as other EllesmereUI frames.

### Textures and colours

- List bar and background textures with `EUI.BuildBarTextureTables` and
  resolve them with `EUI.ResolveTexturePath`. Do not add a custom texture
  catalogue or load external texture files.
- Use `EUI.GetAccentColor` for accent fills. Do not hard-code the suite
  accent.
- Use the class colours from `RAID_CLASS_COLORS` and the quality colours from
  `ITEM_QUALITY_COLORS`. Do not add a second colour table.

### Frames and updates

- Reuse the row, chip and hit-area pools. Do not create frames per update or
  per roll.
- Use the EllesmereUI tick driver for timers. Do not use `OnUpdate` where a
  tick works.
- Do not write to Blizzard's frames. Hide the stock loot roll frames only
  while this window is enabled, and restore them when the addon is disabled
  or the client blocks a roll.
- Refresh through `ns.Refresh` and `ns.Apply`. Do not rebuild the window on
  every event.

## Localization

The interface text is English today. If you use `EllesmereUI.L` or
`EllesmereUI.Lf`, follow the localization rules in the main repository and
update `EllesmereUILocales/_keys.txt` there. Do not add a local locale system
to this repository. Do not translate player names, item names or game data.

## Testing and verification

Run these checks before you commit:

```sh
for f in *.lua; do luac5.1 -p "$f" || exit 1; done
grep -nP "[^\x00-\x7F]" *.lua *.toc
```

`luac5.1` may come from `luac5.1` on `PATH`, from `LUAC=/path/to/luac`, or from
`nix-shell -p lua5_1 --run`. The ASCII check must print nothing.

For a behavior change, load the files in a Lua 5.1 harness that stubs the WoW
and EllesmereUI APIs. Drive the events and assert on the state and the layout.
Check the settings rows, the border calls and the alignment. Delete the
harness before you commit.

Samples must look like live rolls. Sample players start undecided, pick their
choices while their timer runs, and the sample shows roll numbers only after
the last player picks. A sample row must not invent numbers at the moment it
appears. When the sample group resolves, the viewer's choice is assigned
automatically. The roll then concludes and the linger time starts. Do not keep
a concluded sample open, and close the frame when the last sample lingers out.

Show only the numbers that can decide the item. A Need group always shows its
rolls. A Greed group shows its rolls only when no player needs the item. A
Pass group never shows rolls, because a pass cannot win.

The harness does not prove visuals. Open the game and look at the window for
every layout, colour or border change, or state that the visual check is
missing.

If this addon is vendored into the EllesmereUI tree, run the main guardrails:

```sh
python3 .tools/guardrails.py
```

That script needs a Lua 5.1 `luac`. It checks changed and untracked files
against `origin/main` or `upstream/main`.

## Version control

- Make one topic per commit. Use an imperative subject and explain the reason
  in the body.
- Do not commit harnesses, logs, editor folders or generated files.
- Do not rewrite history on a shared branch.
- Update this file when a convention changes.

## Exceptions

Put an exception in a comment on the offending statement. Name the human who
approved it and why. The tag must contain the key, the approver and the
reason:

```lua
local STOPWORDS = { ... } -- guardrails-allow: ascii by Ellesmere: Russian search stopwords
```

Valid keys are `combat-deferral`, `deprecated-global` and `ascii`. For a
stopgap, add an expiry date right after the key:

```lua
local name = GetItemInfo(id) -- guardrails-allow: deprecated-global until 2026-12-31 by Ellesmere: retail-only path
```

A tag fails when it has no approver, no reason, an unknown key or a bad date.
Once an expiry date passes, every guardrails run fails until the tag is removed
or the date moves.
