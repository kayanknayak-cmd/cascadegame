class_name Dress
extends RefCounted
## Changes which pictures a level shows, never how it plays.
##
## Every level is a fixed deal that the solver proved winnable. Swapping one
## group's name and cards for another group's keeps every card in the same
## spot with the same colour, so the level plays exactly the same. That lets
## the game:
##   - sometimes show a rare group (about 1 level in 8, gold edge, bonus),
##   - lean toward the album's featured set, so it can be finished in time.
## Both are picked from the level number and the current set, so they're the
## same for everyone and can't be bought or rerolled.

const RARE_CHANCE := 1.0 / 8.0
const SET_CHANCE := 0.6
const FIRST_LEVEL := 5      ## the first few levels stay exactly as built

static var _family: Dictionary = {}

static func family_of(gid: String) -> String:
	if _family.is_empty():
		for g in LevelGen.load_groups() + LevelGen.load_rare():
			_family[g.id] = g.family
	return String(_family.get(gid, gid))

## Returns a dressed copy of `lv` (or `lv` itself when nothing changes).
## `set_key` names the current album set; `missing` lists its group ids the
## player still needs.
static func dress(lv: Dictionary, index: int, set_key: String, missing: Array) -> Dictionary:
	if index < FIRST_LEVEL:
		return lv
	var rng := RandomNumberGenerator.new()
	rng.seed = ("%d|%s" % [index, set_key]).hash()
	var out := lv.duplicate(true)
	var groups: Array = out.groups
	var touched := {}
	if rng.randf() < RARE_CHANCE:
		var rares := LevelGen.load_rare()
		var r: Dictionary = rares[rng.randi() % rares.size()]
		var slot := _free_slot(groups, r.family, touched, rng)
		if slot >= 0:
			groups[slot] = _as_level_group(r, groups[slot].cards.size(), rng, true)
			touched[slot] = true
	if not missing.is_empty() and rng.randf() < SET_CHANCE:
		var want := missing.duplicate()
		for g in groups:
			want.erase(g.id)
		if not want.is_empty():
			var all := {}
			for g in LevelGen.load_groups():
				all[g.id] = g
			var gid: String = want[rng.randi() % want.size()]
			var slot := _free_slot(groups, family_of(gid), touched, rng, missing)
			if slot >= 0 and all.has(gid):
				groups[slot] = _as_level_group(all[gid], groups[slot].cards.size(), rng, false)
	return out

## A group slot that can take a group of `family` without two groups of one
## family meeting on the table. Skips slots already swapped and groups the
## player is after.
static func _free_slot(groups: Array, family: String, touched: Dictionary, rng: RandomNumberGenerator, keep := []) -> int:
	var start := rng.randi() % groups.size()
	for k in groups.size():
		var i := (start + k) % groups.size()
		if touched.has(i) or keep.has(groups[i].id):
			continue
		var clash := false
		for j in groups.size():
			if j != i and family_of(groups[j].id) == family:
				clash = true
		if not clash:
			return i
	return -1

static func _as_level_group(g: Dictionary, n: int, rng: RandomNumberGenerator, rare: bool) -> Dictionary:
	var items: Array = g.items.duplicate()
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t = items[i]
		items[i] = items[j]
		items[j] = t
	var out := {"id": g.id, "name": g.name, "cards": items.slice(0, n)}
	if rare:
		out.rare = true
	return out
