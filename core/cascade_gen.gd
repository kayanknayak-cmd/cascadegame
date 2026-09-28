class_name CascadeGen
extends RefCounted
## Builds Magnet Cascade levels. A layout is kept only if:
##   - the solver can win it (every level is provably winnable)
##   - a fair casual player (sees only face-up cards) wins about the target share
##   - taps are juicy: on average each tap moves at least MIN_CARDS_PER_TAP cards
## Specials are always hidden (never face-up at the start).

## [groups, piles, hold, magnets, bombs, target win % low, high, locks]
## (locks is optional; locked cards start at level 13. Wild cards appear
## from level 21: one per level.)
const RAMP := [
	[3, 4, 3, 0, 0, 90, 100],
	[4, 4, 3, 0, 0, 85, 100],
	[5, 5, 3, 1, 0, 75, 100],
	[6, 6, 3, 0, 1, 70, 95],
	[7, 7, 3, 1, 1, 65, 95],
	[8, 8, 3, 1, 1, 60, 90],
	[8, 6, 3, 1, 1, 50, 85],
	[9, 8, 3, 1, 1, 50, 80],
	[9, 8, 3, 1, 1, 65, 92],
	[10, 8, 3, 1, 2, 40, 75],
	[10, 8, 3, 2, 1, 35, 70],
	[12, 8, 3, 2, 2, 35, 70],
	# From here the ramp follows a five-level wave: steady, steady, hard,
	# breather, hardest. Candy Crush's rhythm: tension, then relief.
	[9, 8, 3, 2, 2, 55, 85, 1],
	[9, 8, 3, 1, 1, 50, 80, 1],
	[9, 8, 3, 1, 1, 40, 70, 2],
	[9, 8, 3, 2, 1, 65, 92, 1],
	[9, 8, 3, 1, 2, 35, 65, 1],
	[9, 8, 3, 1, 1, 55, 85, 1],
	[10, 8, 3, 2, 1, 50, 80, 1],
	[10, 8, 3, 1, 1, 40, 70, 2],
	[10, 8, 3, 1, 2, 65, 92, 2],
	[10, 8, 3, 2, 1, 35, 65, 2],
	[10, 8, 3, 1, 1, 55, 85, 2],
	[10, 8, 3, 1, 1, 50, 80, 2],
	[11, 8, 3, 2, 2, 40, 70, 3],
	[11, 8, 3, 1, 1, 65, 92, 2],
	[11, 8, 3, 1, 1, 35, 65, 2],
	[11, 8, 3, 2, 1, 55, 85, 2],
	[11, 8, 3, 1, 2, 50, 80, 3],
	[11, 8, 3, 1, 1, 40, 70, 4],
	[12, 8, 3, 2, 1, 65, 92, 3],
	[12, 8, 3, 1, 1, 35, 65, 3],
	[12, 8, 3, 1, 2, 55, 85, 3],
	[12, 8, 3, 2, 1, 50, 80, 3],
	[12, 8, 3, 1, 1, 40, 70, 4],
	[12, 8, 3, 1, 1, 65, 92, 3],
	[12, 8, 3, 2, 2, 35, 65, 4],
	[12, 8, 3, 1, 1, 55, 85, 4],
	[12, 8, 3, 1, 1, 50, 80, 4],
	[12, 8, 3, 2, 1, 40, 70, 4],
	# Levels 41-100: the same wave, with a boss every tenth level.
	[10, 8, 3, 1, 2, 65, 92, 2],
	[10, 8, 3, 1, 1, 35, 65, 2],
	[10, 8, 3, 2, 1, 55, 85, 2],
	[10, 8, 3, 1, 1, 50, 80, 2],
	[10, 8, 3, 1, 2, 40, 70, 2],
	[10, 8, 3, 2, 1, 65, 92, 2],
	[10, 8, 3, 1, 1, 35, 65, 2],
	[10, 8, 3, 1, 1, 55, 85, 2],
	[10, 8, 3, 2, 2, 50, 80, 2],
	[12, 8, 3, 2, 2, 25, 55, 4],   # boss
	[10, 8, 3, 1, 1, 65, 92, 2],
	[10, 8, 3, 2, 1, 35, 65, 2],
	[10, 8, 3, 1, 2, 55, 85, 2],
	[10, 8, 3, 1, 1, 50, 80, 2],
	[10, 8, 3, 2, 1, 40, 70, 2],
	[10, 8, 3, 1, 1, 65, 92, 2],
	[10, 8, 3, 1, 2, 35, 65, 2],
	[10, 8, 3, 2, 1, 55, 85, 2],
	[10, 8, 3, 1, 1, 50, 80, 2],
	[12, 8, 3, 2, 2, 25, 55, 4],   # boss
	[11, 8, 3, 2, 2, 65, 92, 2],
	[11, 8, 3, 1, 1, 35, 65, 2],
	[11, 8, 3, 1, 1, 55, 85, 2],
	[11, 8, 3, 2, 1, 50, 80, 2],
	[11, 8, 3, 1, 2, 40, 70, 2],
	[11, 8, 3, 1, 1, 65, 92, 3],
	[11, 8, 3, 2, 1, 35, 65, 3],
	[11, 8, 3, 1, 1, 55, 85, 3],
	[11, 8, 3, 1, 2, 50, 80, 3],
	[12, 8, 3, 2, 2, 25, 55, 4],   # boss
	[11, 8, 3, 1, 1, 65, 92, 3],
	[11, 8, 3, 1, 1, 35, 65, 3],
	[11, 8, 3, 2, 2, 55, 85, 3],
	[11, 8, 3, 1, 1, 50, 80, 3],
	[11, 8, 3, 1, 1, 40, 70, 3],
	[11, 8, 3, 2, 1, 65, 92, 3],
	[11, 8, 3, 1, 2, 35, 65, 3],
	[11, 8, 3, 1, 1, 55, 85, 3],
	[11, 8, 3, 2, 1, 50, 80, 3],
	[12, 8, 3, 2, 2, 25, 55, 4],   # boss
	[12, 8, 3, 1, 2, 65, 92, 3],
	[12, 8, 3, 2, 1, 35, 65, 3],
	[12, 8, 3, 1, 1, 55, 85, 3],
	[12, 8, 3, 1, 1, 50, 80, 3],
	[12, 8, 3, 2, 2, 40, 70, 3],
	[12, 8, 3, 1, 1, 65, 92, 3],
	[12, 8, 3, 1, 1, 35, 65, 3],
	[12, 8, 3, 2, 1, 55, 85, 3],
	[12, 8, 3, 1, 2, 50, 80, 3],
	[12, 8, 3, 2, 2, 25, 55, 4],   # boss
	[12, 8, 3, 2, 1, 65, 92, 4],
	[12, 8, 3, 1, 1, 35, 65, 4],
	[12, 8, 3, 1, 2, 55, 85, 4],
	[12, 8, 3, 2, 1, 50, 80, 4],
	[12, 8, 3, 1, 1, 40, 70, 4],
	[12, 8, 3, 1, 1, 65, 92, 4],
	[12, 8, 3, 2, 2, 35, 65, 4],
	[12, 8, 3, 1, 1, 55, 85, 4],
	[12, 8, 3, 1, 1, 50, 80, 4],
	[12, 8, 3, 2, 2, 25, 55, 4],   # boss
]

const CARDS_PER_GROUP := 4
const MIN_CARDS_PER_TAP := 3.0
const BOT_RUNS := 120   ## more plays = a truer win rate (levels 1-30 were built with 60)

static var override: Array = []   ## tools can try other settings

## How many levels the game has. Levels past the hand-written RAMP (101+)
## repeat the wave of levels 41-100, a little harder each time round.
const LEVEL_COUNT := 200

static func params(index: int) -> Array:
	if not override.is_empty():
		return override
	if index < RAMP.size():
		return RAMP[index]
	var lap := 1 + (index - RAMP.size()) / 60
	var p: Array = RAMP[40 + (index - RAMP.size()) % 60].duplicate()
	p[5] = maxi(int(p[5]) - 5 * lap, 20)          # target win band slides down
	p[6] = maxi(int(p[6]) - 5 * lap, int(p[5]) + 20)
	return p

static func build(index: int, all_groups: Array, first_seed: int, tries := 400) -> Dictionary:
	var p := params(index)
	for attempt in tries:
		var seed_value := first_seed + attempt * 7919
		var level := deal(index, all_groups, seed_value)
		# The quick checks first (the fair bot), then the slow one (the solver).
		var stats := bot_stats(level, BOT_RUNS, seed_value)
		if stats.win < float(p[5]) / 100.0 or stats.win > float(p[6]) / 100.0:
			continue
		if stats.cards_per_tap < MIN_CARDS_PER_TAP:
			continue
		var sol := quick_solution(level, seed_value)
		if sol.is_empty():
			sol = Cascade.solve(Cascade.from_level(level), SOLVE_NODES)
		if sol.is_empty():
			continue
		if index == 0 and not stats.first_tap_bursts:
			continue   # the very first tap of the game has to go boom
		level.boss = (index + 1) % 10 == 0
		level.solution = sol
		level.seed = seed_value
		level.bot = {"win": snappedf(stats.win, 0.01), "cards_per_tap": snappedf(stats.cards_per_tap, 0.01),
			"big_chain_rate": snappedf(stats.big_rate, 0.01), "taps": snappedf(stats.taps, 0.1)}
		return level
	return {}

static func deal(index: int, all_groups: Array, seed_value: int) -> Dictionary:
	var p := params(index)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n_groups := int(p[0])
	var n_piles := int(p[1])
	var pool := all_groups.duplicate()
	_shuffle(pool, rng)
	var chosen: Array = []
	var families := {}
	for g in pool:
		if chosen.size() == n_groups:
			break
		if families.has(g.family):
			continue
		families[g.family] = true
		var items: Array = g.items.duplicate()
		_shuffle(items, rng)
		chosen.append({"id": g.id, "name": g.name, "cards": items.slice(0, CARDS_PER_GROUP)})
	var normal := n_groups * CARDS_PER_GROUP
	var wilds := 1 if index >= 20 else 0
	var extra := special_counts(index)
	var specials: int = int(p[3]) + int(p[4]) + wilds + int(extra.colors) + int(extra.rows) + int(extra.shuffles)
	var deck: Array = []
	for i in normal:
		deck.append(i)
	_shuffle(deck, rng)
	var piles: Array = []
	for q in n_piles:
		piles.append([])
	for i in deck.size():
		piles[i % n_piles].append(deck[i])
	# Tuck each special somewhere below the top of a pile.
	for s in specials:
		var q := rng.randi_range(0, n_piles - 1)
		var pile: Array = piles[q]
		pile.insert(rng.randi_range(0, maxi(pile.size() - 1, 0)), normal + s)
	# Locks go on normal cards in the top half of piles, counting 1 to 3.
	var locks := {}
	var n_locks: int = int(p[7]) if p.size() > 7 else 0
	# Obstacles take the place of some locks rather than piling on top.
	var obs := obstacle_counts(index)
	n_locks = maxi(n_locks - obs.ice - obs.chains, 0 if n_locks == 0 else 1)
	var tries := 0
	while locks.size() < n_locks and tries < 50:
		tries += 1
		var q := rng.randi_range(0, n_piles - 1)
		var pile: Array = piles[q]
		if pile.size() < 2:
			continue
		var i := rng.randi_range(pile.size() / 2, pile.size() - 1)
		var c: int = pile[i]
		if c >= normal or locks.has(str(c)):
			continue
		locks[str(c)] = rng.randi_range(1, 3)
	var level := {"index": index, "groups": chosen, "piles": piles, "hold": int(p[2]),
		"magnets": int(p[3]), "bombs": int(p[4]), "wilds": wilds, "locks": locks}
	for k in extra:
		if int(extra[k]) > 0:
			level[k] = extra[k]
	_add_obstacles(level, index, normal, rng)
	return level

## The newer special cards: when each arrives (level index), one per level.
const COLOR_FROM := 40     ## level 41
const ROW_FROM := 55       ## level 56
const SHUFFLE_FROM := 70   ## level 71

static func special_counts(index: int) -> Dictionary:
	return {"colors": 1 if index >= COLOR_FROM else 0, "rows": 1 if index >= ROW_FROM else 0,
		"shuffles": 1 if index >= SHUFFLE_FROM else 0}

## When each obstacle arrives (level index) and how many a level gets.
const ICE_FROM := 30       ## level 31
const CHAIN_FROM := 45     ## level 46
const WRAP_FROM := 60      ## level 61

static func obstacle_counts(index: int) -> Dictionary:
	var boss := 1 if (index + 1) % 10 == 0 else 0
	var ice := 0
	if index >= ICE_FROM:
		ice = (1 if index < ICE_FROM + 5 else (2 if index < 60 else 3)) + boss
	var chains := 0
	if index >= CHAIN_FROM:
		chains = (1 if index < 55 else 2) + boss
	var wraps := 0
	if index >= WRAP_FROM:
		wraps = (1 if index < 75 else 2) + boss
	return {"ice": ice, "chains": chains, "wraps": wraps}

## Frozen, chained and wrapped cards, on ordinary cards near the tops of the
## piles (where they matter). Nothing is drawn from rng on earlier levels,
## so levels without obstacles come out exactly as before.
static func _add_obstacles(level: Dictionary, index: int, normal: int, rng: RandomNumberGenerator) -> void:
	var want := obstacle_counts(index)
	if want.ice + want.chains + want.wraps == 0:
		return
	var piles: Array = level.piles
	var taken := {}
	for k in level.locks:
		taken[int(k)] = true
	var ice := {}
	var chains := []
	var wraps := []
	var tries := 0
	while (ice.size() < want.ice or chains.size() < want.chains or wraps.size() < want.wraps) and tries < 400:
		tries += 1
		var q := rng.randi_range(0, piles.size() - 1)
		var pile: Array = piles[q]
		if pile.is_empty():
			continue
		var kind := "ice" if ice.size() < want.ice else ("chain" if chains.size() < want.chains else "wrap")
		# Chains and wraps sit on the top two cards; ice anywhere in the top half.
		var lo: int = maxi(pile.size() - 2, 0) if kind != "ice" else pile.size() / 2
		var i := rng.randi_range(lo, pile.size() - 1)
		var c: int = pile[i]
		if c >= normal or taken.has(c):
			continue
		taken[c] = true
		match kind:
			"ice":
				ice[str(c)] = 1 if index < ICE_FROM + 5 else rng.randi_range(1, 2)
			"chain":
				chains.append(c)
			"wrap":
				wraps.append(c)
	if not ice.is_empty():
		level.ice = ice
	if not chains.is_empty():
		level.chains = chains
	if not wraps.is_empty():
		level.wraps = wraps

const SOLVE_NODES := 60000
const QUICK_RUNS := 24

## A cheap proof that a level can be won: a player who peeks at hidden cards
## and looks one tap ahead plays it a few times; any win is a solution.
## (The full search is only needed when these all fail.)
static func quick_solution(level: Dictionary, seed_value: int) -> Array:
	return Cascade.quick_solve(Cascade.from_level(level), QUICK_RUNS, seed_value + 7)

static func bot_stats(level: Dictionary, runs: int, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 1
	var wins := 0
	var cards := 0
	var taps := 0
	var big := 0
	var first_bursts := false
	for r in runs:
		var b := Cascade.from_level(level)
		var first := true
		while not b.is_won() and not b.is_lost():
			var pick := Cascade.fair_pick(b, rng)
			if pick == -1:
				break
			var ev := b.tap(pick)
			var moved := ev.filter(func(e): return e.t in ["pull", "blast"]).size()
			cards += moved
			taps += 1
			if moved >= 6:
				big += 1
			if first and r == 0:
				first_bursts = ev.any(func(e): return e.t == "burst")
			first = false
		if b.is_won():
			wins += 1
	return {"win": float(wins) / runs, "cards_per_tap": float(cards) / maxi(taps, 1),
		"big_rate": float(big) / maxi(taps, 1), "taps": float(taps) / runs, "first_tap_bursts": first_bursts}

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
