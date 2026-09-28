# Card Game (working title): Godot project

Picture-card sorting puzzle. The research and reasoning are in `../../new-game-plan/`.
The theme isn't picked yet, so nothing in the code depends on it. Cards show
words for now, and Damien's pictures go in the empty frame under each name.

Logical resolution **720×1280**, portrait, stretches to taller phones.

## How to play (Magnet Cascade, the main game)

Tap a card: every face-up card of its colour jumps into the tray. Each card
that leaves flips the one beneath it; if that card's colour is already in the
tray, it jumps in too, and so on (a chain). When a whole group is in the
tray it bursts. The tray holds three groups plus a red "last chance" slot.
Hidden Magnet and Bomb cards fire when revealed; from level 13, locked cards
open after a number of bursts. Fewer taps = more stars.

Around it: title screen, daily gift (7-day ladder), daily puzzle with a
shareable result, 40 levels with a paged level map, collection album, how to
play page, settings (sound, music, vibration), boosters (undo, peek, hint;
coins buy more), streaks, and a level finale.

The first prototype (drag cards into slots) still lives in `game/game_main.gd`
and `core/board.gd` but no longer opens by default.

## Putting it on an iPhone

The iOS export settings are ready (`export_presets.cfg`) and the iOS template
is installed. Godot's official *simulator* library is Intel-only, so it won't
run in this Mac's iOS 26 simulators; a real iPhone works.

1. Export the Xcode project (from this folder):
   `godot --headless --path . --export-debug "iOS" ../../builds/ios/Cascade.ipa`
2. Open `builds/ios/Cascade.xcodeproj` in Xcode, plug in the iPhone.
3. Cascade target → Signing & Capabilities → tick "Automatically manage
   signing" and pick your Personal Team (free Apple ID). If the bundle ID is
   taken, change it (e.g. add your initials).
4. Choose the iPhone at the top and press Run. The first time, on the phone:
   Settings → General → VPN & Device Management → trust your developer profile.

## Running a playtest

1. Settings (gear) → **Reset all progress** so the tester starts at level 1.
2. Hand over the phone. Say nothing.
3. Afterwards, read the log. It records every level start, tap, hint, undo,
   win, loss and when they left the app, with times:
   - Mac: `~/Library/Application Support/Godot/app_userdata/Card Game (working title)/playtest_log.txt`
   - iPhone: in the app's files (connect to the Mac and use Finder → the phone → Files).
4. Turn it into a report (where they quit, win rates, hints used):
   `godot --headless --path . -s res://tools/playtest_report.gd -- path/to/playtest_log.txt --out report.md`

## Commands (run from this folder)

```bash
godot --headless --path . res://tests/run_tests.tscn
```
Runs every test (about 43,000 checks, 8 minutes), including replaying every level's solution and playing levels 1-100 plus every 4th of 101-200 and the daily through the real screen at 12x speed.

```bash
godot --headless --path . -s res://tools/gen_cascade.gd
```
Rebuilds `data/cascade_levels.json` (levels 1-100 are kept exactly; up to 200 are built, ~50 s). Every level is proven winnable; a fair bot that sees only face-up cards sets each level's difficulty.

```bash
godot --headless --path . -s res://tools/difficulty_report.gd -- --out report.md
```
Plays every level 200 times with the fair bot and flags any level outside its difficulty band or much harder than planned.

Speed test: in a test build (run from Xcode) there's a **Speed test** button in Settings. It plays level 100 by itself and reports frames per second. On a Mac: `godot --always-on-top --path . res://tests/speed_quick.tscn`.

```bash
godot --always-on-top --position 0,0 --path . res://tests/capture_quick.tscn -- 12 locks
```
Screenshots of one level (the window opens in the top-left corner). Extra word to shoot one feature, e.g. `locks`, `rules`, `album`, `peek`, `gift`, `home`, `shop`, `panels`, `motion`, `dailyintro`, `inlevel`, `pregrow` (full list at the top of `tests/capture_quick.gd`).

```bash
godot --headless --path . -s res://tools/gen_levels.gd
```
Rebuilds `data/levels.json` from `data/groups.json`. The solver keeps only winnable layouts.

```bash
godot --headless --path . -s res://tools/difficulty.gd
```
Shows how often a careless player would win each level.

```bash
godot --always-on-top --path . res://tests/capture.tscn
```
Saves screenshots to the Godot user folder, including frames caught mid-animation.
`--always-on-top` matters: macOS slows a hidden window to a crawl.

```bash
godot --path . res://tools/sound_check.tscn
```
Plays every sound once.

## Files

| File | What it does |
|---|---|
| `core/cascade.gd` | Magnet Cascade rules: taps, chains, bursts, magnets, bombs, locks, solver |
| `core/goals.gd` | Bonus goals (First / Last / Chain ×N), read off each level's winning line; +30 coins, never required |
| `core/dress.gd` | Swaps a rare group or an album-set group into a level while playing (pictures only, so levels stay winnable) |
| `core/cascade_gen.gd` | The difficulty ramp (200 levels; 101+ repeat the 41-100 wave) and level builder, obstacles, new specials |
| `game/economy.gd` | Every coin reward and in-level price in one place |
| `core/playtest_report.gd` | Reads playtest logs: where players quit, win rates, help used |
| `game/cascade_main.gd` | The Magnet Cascade screen and every menu |
| `game/home_view.gd` | Home screen: the winding level map, treasure-card gifts, side bubbles, collection shelf, intro |
| `game/shop_panel.gd` | Coin shop: four big booster cards and a swipeable fan of card backs; slides in and out |
| `game/share_card.gd` | The shareable result picture |
| `core/board.gd` | The first prototype's rules |
| `core/solver.gd` | Finds a winning line from any position. Used by the level builder, tests and Hint |
| `core/level_gen.gd` | Difficulty ramp and level building |
| `core/casual_bot.gd` | Plays like a careless player, to set move limits |
| `data/groups.json` | 43 groups of everyday things. Groups in the same `family` never share a level . The `rare` list holds 4 gold rare groups (placeholder themes) |
| `data/album_sets.json` | Limited-time album sets: a new 6-group set every 14 days, 500 coins + gold ribbon for finishing |
| `tools/gen_cascade.gd` | Builds the levels (keeps 1-100 exactly) |
| `tools/difficulty_report.gd` | Checks every level's difficulty against its target |
| `tools/economy_report.gd` | Simulates a player's coins against shop prices |
| `tools/strategy_test.gd` | Compares random / casual / planning / all-seeing bots |
| `tools/playtest_report.gd` | Turns a playtest log into a report |
| `art/cards/`, `art/backs/` | Drop Damien's drawings here (see the README inside) |
| `game/game_main.gd` | The play screen: deal, drag, tap, the reward ladder, win and lose screens |
| `game/card_view.gd` | One card: lift, lean-while-dragging, arc flights, squash, flip, sheen |
| `game/fx.gd` | Sparkles, light rays, shockwave rings, confetti, flying coins, the ribbon banner |
| `game/style.gd` | Editorial Paper look: Fraunces and Inter, paper and ink colours, 12 group colours and shapes |
| `game/pill_button.gd` | Printed buttons that press into their shadow, with count badges |
| `game/background.gdshader` | Paper texture, with a colour wash after big chains |
| `autoload/progress.gd` | Saved progress: levels, stars, coins, daily, gift, album, settings |
| `autoload/audio.gd` | Card and chip recordings, code-made bells, and generative music |
| `fonts/`, `sfx/` | Free assets, licences in `fonts/LICENSES.md` |

## Not built yet

Real ads (the boosters and coins are ready for rewarded video), theme, Damien's art, cloud save, iOS export setup.
