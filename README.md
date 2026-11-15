# Threat Box - Nameplate Threat Percent

Your threat on every enemy, as a percentage, in a small box on its nameplate. The box is drawn with the same art as the level box, so it looks like part of the default WoW Forever nameplate. Its border changes color with your threat.

Made for World of Warcraft: Forever and the default Blizzard nameplates.

## What it shows

- **Threat percent on each enemy nameplate.** The box appears once you are on an enemy's threat list and goes away when you are not.
- **Until you pull (default).** 100% is the point you take the enemy. The game works this out for where you stand, so it is right in melee range (where it takes 110% of the tank's threat) and from farther away (130%).
- **Raw threat (optional).** The same number as `/console threatShowNumeric 1` shows on the target frame.
- **Border color by threat.** Grey on the list, yellow catching up, orange about to change hands, red on you.
- **Reversed colors for tanks.** Green while the enemy is safely on you, red when you have lost it. Always, or only while your role is tank.

## More at a glance

- **Fill meter.** The box fills from left to right as your threat rises, so you can read it without reading the number.
- **Warning pulse.** The box pulses once you pass a threat you choose (80% by default) and stops when the enemy is on you. For tanks it pulses on every enemy that is not on them.
- **Who has it (optional).** A target box beside it names who the enemy is on, when it is not you: a player in their class color, your pet in blue.
- **Pet threat (optional).** A second box, in blue, with your pet's threat on that enemy.
- **Aggro sound (optional).** A sound when an enemy turns to you in a group, or as a tank when you lose one.
- **Show rules.** Only in a group, only in combat, only on your target and focus, skip trivial enemies.

## Placing the box

Open the options with `/threatbox` (or Esc > Options > AddOns > Threat Box). The page has a nameplate preview:

- **Drag** the threat box to nudge it.
- **Drop it on a highlighted area** to pin it there: below the level box (default), above it, to its right, or left of the health bar.
- **Mouse wheel** over a box to resize it. The threat box, the pet box and the target box each have their own size.
- **Click** the box to see each threat color.

The pet box and the target box sit in a row with the threat box. To put either one somewhere else, drag it onto a highlighted area: it leaves the row and is pinned there on its own, and can then be nudged like the threat box. Drop it back on the threat box to rejoin the row.

Under the preview the settings are in three tabs, one each for the threat box, the pet box and the target box; clicking a box in the preview picks its tab. What they share (when to show, the look) sits below the tabs.

Every setting is also a control under the preview, and "Show a sample on every nameplate" lets you check the result on real nameplates out of combat.

## Looks

Threat Box follows the same window styles as my other addons, with nothing to set up:

- **Automatic (default):** EllesmereUI's look when EllesmereUI is running, otherwise Blizzard's.
- **Blizzard:** the level box art of the default nameplates.
- **Dark:** a flat dark box with a thin edge in the threat color. Needs no other addon.

With EllesmereUI's Nameplates module on, the box follows its nameplates and its level box.

## Slash commands

| Command | What it does |
| --- | --- |
| `/threatbox` | Opens the options |
| `/threatbox below`, `above`, `right`, `left` | Pins the box |
| `/threatbox pull`, `/threatbox raw` | Which number to show |
| `/threatbox colors normal`, `tank`, `reversed` | Border colors |
| `/threatbox size 120` | Threat box size in percent (50 to 200) |
| `/threatbox petsize 120`, `/threatbox whosize 120` | Pet box and target box size |
| `/threatbox nudge 0 -4` | Nudge across and up |
| `/threatbox style auto`, `blizzard`, `dark` | Window style |
| `/threatbox fill`, `pulse`, `sound`, `who`, `pet` | Turns each extra on or off |
| `/threatbox pulseat 80` | The threat the pulse starts at (50 to 100) |
| `/threatbox group`, `combat`, `targetonly`, `trivial` | Show rules, on or off |
| `/threatbox detach pet above`, `/threatbox detach who left` | Puts the pet box or the target box on its own (below, above, right, left) |
| `/threatbox attach pet`, `/threatbox attach who` | Puts it back in the row |
| `/threatbox test` | A sample on every nameplate |
| `/threatbox reset` | Back to defaults |
| `/threatbox debug` | A short report for bug reports |

`/tbox` works too.

## Good to know

- WoW Forever can hide threat numbers from addons during fights. Threat Box never reads them: it hands them to the game, which writes the number and picks the border color. Because of that, while the numbers are hidden the box cannot switch to "how far ahead you are" when the enemy is on you, and it shows 100% instead. The fill, the pulse, the target box and the pet box work the same way. The aggro sound is the exception: it needs to know when an enemy changes hands, so it stays silent whenever the game hides that.
- It works with the default nameplates and with EllesmereUI's. Other nameplate replacements are not supported yet.
- Nothing to set up and nothing else to install.

## License

MIT
