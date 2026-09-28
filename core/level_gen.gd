class_name LevelGen
extends RefCounted
## Builds levels from groups.json and only keeps ones the solver can win.
## The move budget is never less than the solver's winning line plus a few
## spare moves, so every level is provably winnable within its budget.

## Difficulty ramp. One row per level; the last row repeats forever.
## [groups, columns, slots, stock cards, target casual-bot win %]
## The move budget is set so the casual bot wins about the target % of the
## time. Every 5th level is a breather.
const RAMP := [
	[2, 3, 2, 0, 100],
	[3, 3, 2, 2, 98],
	[3, 3, 2, 3, 95],
	[3, 4, 2, 3, 90],
	[4, 4, 2, 4, 92],
	[4, 4, 2, 4, 85],
	[4, 4, 3, 5, 80],
	[5, 4, 3, 5, 75],
	[5, 4, 3, 6, 70],
	[5, 5, 3, 6, 85],
	[5, 5, 3, 6, 68],
	[5, 5, 2, 6, 64],
	[6, 5, 3, 7, 60],
	[6, 5, 3, 7, 56],
	[6, 5, 3, 8, 75],
	[6, 5, 2, 8, 54],
	[6, 5, 3, 8, 50],
	[6, 5, 3, 9, 47],
	[7, 5, 3, 8, 44],
	[7, 5, 3, 9, 65],
	[7, 5, 3, 9, 42],
	[7, 5, 3, 10, 40],
	[7, 5, 2, 9, 38],
	[7, 5, 3, 10, 36],
	[7, 5, 3, 10, 58],
	[8, 5, 3, 10, 35],
	[8, 5, 3, 11, 33],
	[8, 5, 3, 11, 31],
	[8, 5, 3, 12, 30],
	[8, 5, 3, 12, 50],
]

const CARDS_PER_GROUP := 4
const MIN_SPARE := 3        ## budget is always at least solution + this
const BOT_RUNS := 160

static func load_groups() -> Array:
	var f := FileAccess.open("res://data/groups.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	return data.groups

## Rare groups: never dealt by the builders, only swapped in while playing
## (see Dress).
static func load_rare() -> Array:
	var f := FileAccess.open("res://data/groups.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	return data.get("rare", [])

static func params(index: int) -> Array:
	return RAMP[mini(index, RAMP.size() - 1)]

## Tries seeds until the solver wins one. Returns the level with its
## solution attached, or {} if nothing worked (the caller should complain).
static func build(index: int, all_groups: Array, first_seed: int, tries := 40) -> Dictionary:
	var p := params(index)
	var solver := Solver.new()
	for attempt in tries:
		var level := deal(index, all_groups, first_seed + attempt * 7919)
		var board := Board.from_level(level)
		var sol := solver.solve(board)
		if sol.is_empty():
			continue
		var budget := budget_for(level, sol.size(), float(p[4]) / 100.0)
		if budget < 0:
			continue
		level.budget = budget
		level.solution = sol.map(func(m: Vector3i): return [m.x, m.y, m.z])
		level.seed = first_seed + attempt * 7919
		return level
	return {}

## The smallest budget at which the casual bot wins at least `target` of its
## games. -1 if the layout gets the bot stuck too often to ever reach it.
static func budget_for(level: Dictionary, solution_len: int, target: float) -> int:
	var lengths := CasualBot.win_lengths(level, BOT_RUNS, int(level.get("index", 0)) + 99)
	lengths.sort()
	var need := int(ceil(target * BOT_RUNS))
	if lengths.size() < need:
		return -1
	var budget: int = lengths[maxi(need - 1, 0)]
	return maxi(budget, solution_len + MIN_SPARE)

## A random layout for this level's difficulty. Not checked for winnability.
static func deal(index: int, all_groups: Array, seed_value: int) -> Dictionary:
	var p := params(index)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n_groups := int(p[0])
	var n_cols := int(p[1])

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

	var deck: Array = []
	for i in n_groups * CARDS_PER_GROUP:
		deck.append(i)
	_shuffle(deck, rng)
	var stock: Array = deck.slice(0, int(p[3]))
	var rest: Array = deck.slice(int(p[3]))
	var columns: Array = []
	for c in n_cols:
		columns.append([])
	for i in rest.size():
		columns[i % n_cols].append(rest[i])
	return {"index": index, "groups": chosen, "columns": columns, "stock": stock,
			"slots": int(p[2]), "budget": 999}

static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t
