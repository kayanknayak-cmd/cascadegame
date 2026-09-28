extends SceneTree
## Builds data/levels.json. Every level in it has been won by the solver.
##   godot --headless --path . -s res://tools/gen_levels.gd

const COUNT := 30
const BASE_SEED := 20260923

func _init() -> void:
	var groups := LevelGen.load_groups()
	var levels: Array = []
	var t0 := Time.get_ticks_msec()
	for i in COUNT:
		var lt := Time.get_ticks_msec()
		var level := LevelGen.build(i, groups, BASE_SEED + i * 104729)
		if level.is_empty():
			printerr("level %d: no winnable layout found" % (i + 1))
			quit(1)
			return
		levels.append(level)
		var cards := 0
		for g in level.groups:
			cards += g.cards.size()
		print("level %2d  %2d cards  %d slots  solution %2d moves  budget %2d  (%d ms)" % [
			i + 1, cards, level.slots, level.solution.size(), level.budget,
			Time.get_ticks_msec() - lt])
	var f := FileAccess.open("res://data/levels.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"levels": levels}, "", false))
	f.close()
	print("wrote %d levels in %.1fs" % [levels.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	quit(0)
