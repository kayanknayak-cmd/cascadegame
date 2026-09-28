extends SceneTree
## Does thinking pay off? Plays sample levels with four kinds of player and
## compares win rates:
##   random   - taps any pile
##   fair     - the casual bot the levels are tuned with (grabs the biggest
##              visible colour, avoids crowding the tray)
##   peek     - sees the card under each top card and plans with it: counts
##              the chain a tap would set off one card deep, and prefers taps
##              that burst or keep the tray free
##   cheat    - sees every card and looks one tap ahead (the upper limit)
##   godot --headless --path . -s res://tools/strategy_test.gd -- [--runs 60] [--every 5]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := 60
	var every := 5
	for i in args.size():
		if args[i] == "--runs" and i + 1 < args.size():
			runs = int(args[i + 1])
		if args[i] == "--every" and i + 1 < args.size():
			every = int(args[i + 1])
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cascade_levels.json"))
	var kinds := ["random", "fair", "peek", "cheat"]
	var totals := {}
	for k in kinds:
		totals[k] = 0.0
	var n := 0
	var lines := []
	for level in data.levels:
		var idx := int(level.index)
		if idx % every != 0:
			continue
		n += 1
		var row := "level %3d" % (idx + 1)
		for k in kinds:
			var w := win_rate(level, k, runs, idx)
			totals[k] += w
			row += "  %s %3d%%" % [k, roundi(w * 100)]
		lines.append(row)
	for l in lines:
		print(l)
	var summary := "AVERAGE over %d levels:" % n
	for k in kinds:
		summary += "  %s %d%%" % [k, roundi(100.0 * totals[k] / n)]
	print(summary)
	quit(0)

static func win_rate(level: Dictionary, kind: String, runs: int, seed_value: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + kind.hash()
	var wins := 0
	for r in runs:
		var b := Cascade.from_level(level)
		var guard := 0
		while not b.is_won() and not b.is_lost() and guard < 80:
			guard += 1
			var p := pick(b, kind, rng)
			if p == -1:
				break
			b.tap(p)
		if b.is_won():
			wins += 1
	return float(wins) / runs

static func pick(b: Cascade, kind: String, rng: RandomNumberGenerator) -> int:
	match kind:
		"random":
			var ch := b.choices()
			return -1 if ch.is_empty() else ch[rng.randi() % ch.size()]
		"fair":
			return Cascade.fair_pick(b, rng)
		"peek":
			return peek_pick(b, rng)
	return Cascade.smart_pick(b, rng)

## A thinking player who can see one card under each top card.
static func peek_pick(b: Cascade, rng: RandomNumberGenerator) -> int:
	var best := -1
	var best_score := -INF
	for p in b.piles.size():
		var c := b.top(p)
		if c == -1 or b.blocked(c):
			continue
		var score := rng.randf() * 14.0      # a person, not a machine: a little variety
		if b.card_kind[c] != Cascade.Kind.CARD:
			score += 30.0
		elif b.wrapped[c] == 1:
			score += rng.randf() * 10.0 - (40.0 if b.tray.size() >= b.hold else 0.0)
		else:
			var g := b.card_group[c]
			var grabbed := b.grab_preview(p).filter(func(x): return b.wrapped[x] == 0)
			var in_tray: int = b.tray_cards[g].size() if b.tray_cards.has(g) else 0
			# One card deep: what each grab uncovers, and whether it joins in.
			var chain := 0
			var tray_groups := {}
			for tg in b.tray:
				tray_groups[tg] = true
			tray_groups[g] = true
			for x in grabbed:
				for q in b.piles.size():
					var pile: Array = b.piles[q]
					if pile.size() >= 2 and pile[-1] == x:
						var under: int = pile[-2]
						if b.card_kind[under] != Cascade.Kind.CARD:
							chain += 2          # a special goes off
						elif b.wrapped[under] == 0 and not b.blocked(under) and tray_groups.has(b.card_group[under]):
							chain += 1
			var total := grabbed.size() + chain
			var finishes := in_tray + grabbed.size() >= b.need[g]
			score += total * 10.0 + (60.0 if finishes else 0.0)
			if not b.tray_cards.has(g) and b.tray.size() >= b.hold and not finishes:
				score -= 120.0
			elif not b.tray_cards.has(g):
				score -= 8.0 * b.tray.size()        # opening a new colour costs a slot
		if score > best_score:
			best_score = score
			best = p
	return best
