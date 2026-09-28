class_name Goals
extends RefCounted
## Bonus goals: a small extra task on some levels, worth coins. Missing it
## never loses the level.
##
##   first - burst this group before any other
##   last  - burst this group after all the others
##   chain - move at least `n` cards with one tap
##
## Every goal is read off the level's stored winning line, so it's always
## possible, and it's picked from the level number, so it's the same for
## everyone.

const FIRST_LEVEL := 8      ## index of the first level that can have a goal
const CHANCE := 0.4
const MIN_CHAIN := 5

## {kind, group, n} for this level, or {} for no goal.
static func for_level(level: Dictionary, index: int) -> Dictionary:
	if index < FIRST_LEVEL or level.get("boss", false) or not level.has("solution"):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = ("goal|%d" % index).hash()
	if rng.randf() >= CHANCE:
		return {}
	var b := Cascade.from_level(level)
	var best := 0
	for p in level.solution:
		var events := b.tap(int(p))
		best = maxi(best, moved(events))
	if not b.is_won() or b.done.is_empty():
		return {}
	var kinds := ["first", "last"]
	if best >= MIN_CHAIN:
		kinds.append("chain")
	var kind: String = kinds[rng.randi() % kinds.size()]
	match kind:
		"first":
			return {"kind": "first", "group": int(b.done[0]), "n": 0}
		"last":
			return {"kind": "last", "group": int(b.done[-1]), "n": 0}
	# Aim a bit under the best tap in the winning line.
	return {"kind": "chain", "group": -1, "n": maxi(MIN_CHAIN, int(floor(best * 0.75)))}

## Cards a tap moved (the same count the screen praises).
static func moved(events: Array) -> int:
	var n := 0
	for e in events:
		if e.t in ["pull", "blast"]:
			n += 1
	return n

## "open", "met" or "failed", from the board and the biggest tap so far.
static func status(goal: Dictionary, b: Cascade, best_moved: int) -> String:
	if goal.is_empty():
		return "open"
	match String(goal.kind):
		"first":
			if b.done.is_empty():
				return "open"
			return "met" if int(b.done[0]) == int(goal.group) else "failed"
		"last":
			if not b.done.has(int(goal.group)):
				return "open"
			if b.done.size() == b.group_count() and int(b.done[-1]) == int(goal.group):
				return "met"
			return "failed"
		"chain":
			if best_moved >= int(goal.n):
				return "met"
			return "failed" if b.is_won() else "open"
	return "open"
