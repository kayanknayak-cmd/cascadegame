class_name CasualBot
extends RefCounted
## A stand-in for a casual player: it finishes into a group when it can and
## otherwise plays something legal, without planning ahead. Real people plan
## better but also misread cards, so this is only a yardstick for comparing
## levels with each other. Real playtests set the actual difficulty.

static func pick(b: Board, rng: RandomNumberGenerator) -> Vector3i:
	var moves := b.legal_moves()
	var building: Array = []
	var other: Array = []
	for m in moves:
		if m.x == Board.TO_SLOT and b.slot_group[m.z] != -1:
			building.append(m)
		elif m.x == Board.TO_COLUMN and not b.columns[m.z].is_empty():
			building.append(m)
		else:
			other.append(m)
	if not building.is_empty() and rng.randf() < 0.9:
		return building[rng.randi() % building.size()]
	return other[rng.randi() % other.size()] if not other.is_empty() else moves[0]

## Plays `runs` games with no move limit. Returns how many moves each win
## took; games that got stuck are not in the list.
static func win_lengths(level: Dictionary, runs: int, seed_value: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	for r in runs:
		var b := Board.from_level(level)
		b.move_budget = 400
		while not b.is_won() and not b.is_lost():
			b.apply(pick(b, rng))
		if b.is_won():
			out.append(b.moves_used)
	return out
