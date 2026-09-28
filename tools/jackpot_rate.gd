extends SceneTree
## How often does a tap move 10+ cards (a Cascade jackpot)? Plays every
## level many times with the fair casual bot.
##   godot --headless --path . -s res://tools/jackpot_rate.gd

func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cascade_levels.json"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var taps := 0
	var jackpots := 0
	var levels_with := 0
	var games := 0
	for level in data.levels:
		for r in 30:
			var b := Cascade.from_level(level)
			var got := false
			while not b.is_won() and not b.is_lost():
				var ev := b.tap(Cascade.fair_pick(b, rng))
				taps += 1
				if ev.filter(func(e): return e.t in ["pull", "blast"]).size() >= 10:
					jackpots += 1
					got = true
			games += 1
			if got:
				levels_with += 1
	print("taps %d  jackpots %d (%.1f%% of taps)  games with a jackpot %.0f%%" % [taps, jackpots,
		100.0 * jackpots / taps, 100.0 * levels_with / games])
	quit()
