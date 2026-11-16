# Changelog

## 0.1.1

- New: color the number by threat. Grey, yellow, orange or red, the same colors as the border.
- New: color the box's background by threat, in a darker shade so the number stays easy to read.
- Both are off by default and can be used together with the colored border, or instead of it. Find them on the Threat box tab under Threat colors, or type /threatbox text and /threatbox background.
- Both follow the Colors setting, so tanks get them reversed: green while the enemy is safely on you, red when you have lost it.
- Both work while the game hides threat numbers from addons.
- The pet box's background takes the pet's threat color. Its number stays blue so the two boxes are easy to tell apart.
- /threatbox border turns the colored border on or off.
- New: "Show your lead above 100%". While an enemy is on you the box shows how far ahead you are of the next player, as before. Untick it and the box stops at 100%. The game only tells addons the lead for your target and focus, so other enemies on you read 100% either way.
- The nameplate of your target or focus now shows the lead, as the target frame box does.
- The nudge sliders reach further: 150 either way on nameplates, 300 on the target and focus frames.
- New: the threat box on the game's target frame and focus frame. It sits above the portrait, level with the game's own threat number, and has its own copy of the threat box settings: number, % sign, fill, pulse, threat colors, size and nudge. Off by default: tick them on the new Unit frames tab, or type /threatbox targetframe and /threatbox focusframe.

## 0.1.0

First version.

- Your threat on each enemy as a percentage, in a box on its nameplate drawn with the level box's own art.
- The number is how close you are to taking the enemy (100% pulls, from melee range or from farther away), or the raw threat the game's own numeric threat display shows.
- The border takes the threat color: grey, yellow, orange, red. Tanks can reverse it: green while the enemy is safely on them.
- Pin the box below the level box, above it, to its right, or left of the health bar.
- Options page with a nameplate preview: drag the box to nudge it, drop it on a highlighted area to pin it there, mouse wheel to resize, click to see each color.
- Works while the game hides threat numbers from addons: the game writes the number and colors the border itself.
- Follows the window styles of my other addons: Automatic (EllesmereUI's look when it is running), Blizzard, or a built-in Dark. In Dark and EllesmereUI the box is flat with a thin edge in the threat color.
- Follows EllesmereUI's nameplates when its Nameplates module is on.
- Fill meter: the box fills from left to right as your threat rises.
- Warning pulse: the box pulses once you pass a threat you choose (80% by default). For tanks it pulses on every enemy that is not on them.
- Who has it: an optional target box beside it names who the enemy is on when it is not you, in the same level box art.
- Pet threat: an optional second box, in blue, with your pet's threat.
- Show rules: only in a group, only in combat, only on your target and focus, skip trivial enemies.
- Optional sound when an enemy turns to you in a group, or as a tank when you lose one.
- The pet box and the target box sit in a row with the threat box, or each can be detached and pinned on its own: tick "On its own", or drag it onto a highlighted area in the preview. Drop it back on the threat box to rejoin the row.
- Options: a tab each for the threat box, the pet box and the target box, with the shared settings underneath. Clicking a box in the preview picks its tab. The target box has a width setting, and detached boxes have their own nudge sliders.
- Each box has its own size: a Size slider on every tab, or the mouse wheel over that box in the preview.
