extends SceneTree
## How hard is each level? Plays every level many times with a "casual"
## player who makes sensible-looking but random choices, and reports how often
## they win within the move budget.
##   godot --headless --path . -s res://tools/difficulty.gd

const RUNS := 200

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 777   # different from the builder, so this is a fresh check
	for level in data.levels:
		var wins := 0
		var stuck := 0
		for r in RUNS:
			var b := Board.from_level(level)
			while not b.is_won() and not b.is_lost():
				b.apply(CasualBot.pick(b, rng))
			if b.is_won():
				wins += 1
			elif b.moves_left() > 0:
				stuck += 1
		print("level %2d  target %3d%%  casual win rate %3d%%   (stuck %d%%)  budget %d" % [
			int(level.index) + 1, int(LevelGen.params(int(level.index))[4]),
			wins * 100 / RUNS, stuck * 100 / RUNS, int(level.budget)])
	quit(0)
