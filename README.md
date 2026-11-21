# EUI_LootFrames

LootRollFrames is a group loot roll window for
[EllesmereUI](https://github.com/EllesmereGaming/EllesmereUI). It replaces the
Blizzard roll popups with one window. The window shows the Need, Greed and
Pass groups, who picked what, the rolls, the winner and the time left.

The plugin registers its page in the EllesmereUI options panel under
Plugins > Loot Rolls.

## Requirements

- World of Warcraft, on a client that the TOC lists.
- EllesmereUI, because this addon is a plugin and depends on it.
- The addon folder must be named `LootRollFrames`. The game matches the folder
  name to `LootRollFrames.toc`. The Git repository is named `EUI_LootFrames`;
  the folder keeps its TOC and saved-variable name.

## Install

1. Download the repository as a ZIP file, or clone it.
2. Copy `LootRollFrames.lua`, `LootRollFrames_Window.lua`,
   `LootRollFrames_Settings.lua` and `LootRollFrames.toc` into
   `World of Warcraft/_retail_/Interface/AddOns/LootRollFrames/`. Other
   clients use their own client folder in place of `_retail_`.
3. Restart the game, or run `/reload`.
4. Open the EllesmereUI options, then open Plugins > Loot Rolls.

There is no slash command. The enable control is the first row of the plugin
page. The footer Reset button restores the defaults.

## Using the window

The window shows one row for each active roll. A row has the item icon, the
item name, the countdown, the Need, Greed and Pass lines, and a decision line.
The Need, Greed and Pass lines are the roll buttons. Click anywhere on a line
to make that choice.

A player who has not picked yet appears in the DECIDING line. The roll numbers
appear only after every player has picked. The decision line then becomes the
winner line with the winner name and roll. The game award replaces the computed
winner when it arrives.

A pass never shows a roll number. Greed shows numbers only when no player needs
the item. A need roll always shows its number.

Crowded player lines keep names as long as possible. The window drops realm
names one at a time, shortens long first names to two letters, and then uses
class icons. Hover a chip to see the full name and roll.

The countdown bar drains with the roll timer. Your choice does not stop the
countdown. The timer continues until the roll ends or the game reports the
award. When a roll concludes, the same bar fills in reverse during the linger
time. Keep Roll Results sets that time.

## Options

The defaults are the values in `DEFAULTS` in `LootRollFrames.lua`. A texture
or border style name comes from the EllesmereUI catalog.

### Roll Frames

| Option | What it does | Default |
| --- | --- | --- |
| Enable Loot Roll Window | Shows the window and turns the roll buttons on. | Off |
| Hide Blizzard's Roll Frames | Hides the Blizzard roll popups while this window is on. Blizzard frames return for the session if the game blocks a roll from this window. | On |
| Player Style | Draws each player as a text list or as chips. | Chips |
| Show Roll Numbers | Shows each player's roll next to the name. | On |
| Roll Start Sound | Plays a sound when a new roll starts. | Off |
| Chip Background | Fill color and opacity of a player chip. The dots menu adds Class Colored. | White, 5% opacity |
| Chip Border Style | Border style for the player chips. | Solid |
| Chip Border Color | Border color and opacity for the player chips. | White |
| Chip Border Size | Border thickness. 0 hides the border. The dots menu adds Class Colored and, for textured borders, Shift X, Shift Y, Width Offset and Height Offset. | 1 |
| Preview, Show Samples | Opens the window with sample rolls. The samples pick their choices during the timer and wait for your choice. | Button |

### Appearance

| Option | What it does | Default |
| --- | --- | --- |
| Outer Box | Draws the window background and border behind all rolls. Turn it off so each roll can stand alone. | On |
| Inner Box | Draws the background and border from this section around each roll. Turn Outer Box off for separate boxes. | Off |
| Outer Padding | Space between the outer box and each roll box. | 0 |
| Inner Padding | Space between each roll box edge and its content. | 0 |
| Background Texture | Texture behind the roll list. | None |
| Background Opacity | Opacity of the window background. | 97% |
| Background Color | Color of the window background. | Dark brown |
| Border Style | Border around the window. | Solid |
| Border Size | Border thickness. 0 hides the border. | 1 |
| Border Color | Border color and opacity. | Black |
| Border Options | Dots menu for Show Behind, Shift X, Shift Y, Width Offset and Height Offset. The offset rows need a textured border. | Behind off |

### Roll Buttons

| Option | What it does | Default |
| --- | --- | --- |
| Button Style | Draws the roll buttons as icons or as text labels. | Icons |
| Icon Size | Size of the roll icons and the class icons in a crowded line. Range 10 to 64. | 12 |
| Button Background | Badge puts the color on the open roll button. Full Row draws a band for each open choice line, from the line next to the item icon. The band uses the line color and keeps the line spacing open. | Badge |
| Button Texture | Texture behind an open roll button, tinted with the line color. None keeps a flat color. | None |
| Background Opacity | Opacity of the background behind an open roll button. | 20% |
| Hover Opacity | Opacity of that background while the mouse is over the button. | 34% |
| Need Line Color | Color of the Need line, the Need button background and the Need Full Row band. | Need green |
| Greed Line Color | Color of the Greed line, the Greed button background and the Greed Full Row band. | Greed yellow |
| Pass Line Color | Color of the Pass line, the Pass button background and the Pass Full Row band. | Pass gray |

The chosen line keeps the mouseover highlight and the other lines fade out
after you pick. When the winner is known, the winner leaves the choice list and
gets the decision line, which leaves more room for the remaining players. Hover
the item icon or the decision line badge to list every player.

### Item Row

| Option | What it does | Default |
| --- | --- | --- |
| Item Icon Size | Size of the item icon. Range 12 to 96. | 22 |
| Item Border Style | Border style around the item icon. | Solid |
| Item Border Color | Border color for the item icon when Use Item Quality is off. | Black |
| Item Border Size | Border thickness. 0 hides the border. | 1 |
| Item Border Options | Dots menu for Use Item Quality, Shift X, Shift Y, Width Offset and Height Offset. Use Item Quality is on by default. | Quality on |
| Bar Texture | Texture behind the countdown and linger bar. | None |
| Bar Height | Thickness of the countdown and linger bar. Range 1 to 30. | 2 |

### Flash

| Option | What it does | Default |
| --- | --- | --- |
| Flash Last | Seconds before the roll ends when the row flashes. 0 turns the flash off. | 5 |
| Flash Speed | Speed of the flash pulse. | 9 |
| Flash Color | Color of the row flash and the countdown near the end. | Red |

### Layout

| Option | What it does | Default |
| --- | --- | --- |
| Window Direction | Left keeps the item icon and roll buttons on the left. Right mirrors the whole row. | Left |
| Window Scale | Size of the window and its text. Range 50% to 300%. | 100% |
| Width | Window width. Range 240 to 800. | 300 |
| Line Spacing | Space between the Need, Greed, Pass and decision lines. Range 2 to 30. | 6 |
| Item Name Size | Font size of the item name. Range 8 to 32. | 13 |
| Row Text Size | Font size of the choice badges and the player names or chips. Range 8 to 24. | 11 |
| Time Size | Font size of the countdown and the result state. Range 8 to 24. | 12 |
| Content Padding | Base space between a row edge and its content. Inner Box padding adds to it. Range 4 to 32. | 8 |
| Max Rolls | Number of rolls shown at once. Extra rolls are counted below the window. Range 1 to 12. | 4 |
| Keep Roll Results | Seconds that a concluded roll stays on screen. A roll that is waiting for the game award stays longer. Range 0 to 60. | 10 |
| Position, Reset | Returns the window to the center of the screen. Move it with Unlock Mode, or by its header in Show Samples. | Center |

## Saved settings

The addon stores its settings in the `LootRollFramesDB` saved variable. The
EllesmereUI profile system does not copy plugin pages, so these values are the
same on every character.

## Development

The repository has these files:

| File | Contents |
| --- | --- |
| `LootRollFrames.lua` | Core, defaults, saved variables, roll model, events, history and plugin registration. |
| `LootRollFrames_Window.lua` | Window, rows, chips, buttons, countdown and linger bar. |
| `LootRollFrames_Settings.lua` | EllesmereUI settings page. |
| `LootRollFrames.toc` | Load order, clients, version and saved variable. |
| `AGENTS.md` | Rules for agents and contributors. |

Read `AGENTS.md` before you change the addon. The main repository has the
[plugin guide](https://github.com/EllesmereGaming/EllesmereUI/blob/main/PLUGINS_API.md)
and the
[contribution rules](https://github.com/EllesmereGaming/EllesmereUI/blob/main/.github/CONTRIBUTING.md).
