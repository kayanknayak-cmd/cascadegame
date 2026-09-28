extends SceneTree
## Builds data/cascade_levels.json. Every level has been won by the solver.
##   godot --headless --path . -s res://tools/gen_cascade.gd

const BASE_SEED := 20260924

## Levels below this are kept exactly as they are in the file (players
## may already know them); only later levels are rebuilt.
const KEEP_BELOW := 100

func _init() -> void:
	var groups := LevelGen.load_groups()
	var levels: Array = []
	var t0 := Time.get_ticks_msec()
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cascade_levels.json"))
	for i in mini(KEEP_BELOW, old.levels.size()):
		levels.append(old.levels[i])
	for i in range(levels.size(), CascadeGen.LEVEL_COUNT):
		var lt := Time.get_ticks_msec()
		var level := CascadeGen.build(i, groups, BASE_SEED + i * 104729)
		if level.is_empty():
			printerr("level %d: nothing met the targets" % (i + 1))
			quit(1)
			return
		levels.append(level)
		print("level %2d  %2d groups  %d piles  hold %d  bot wins %3d%%  cards/tap %.1f  big chains %2d%%  taps %.1f  (%d ms)" % [
			i + 1, level.groups.size(), level.piles.size(), level.hold, int(level.bot.win * 100),
			level.bot.cards_per_tap, int(level.bot.big_chain_rate * 100), level.bot.taps, Time.get_ticks_msec() - lt])
	var f := FileAccess.open("res://data/cascade_levels.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"levels": levels}, "", false))
	f.close()
	print("wrote %d levels in %.1fs" % [levels.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
