class_name Solver
extends RefCounted
## Finds a way to win from any position, or proves (within a search limit)
## that there isn't one. Used three ways:
##   - the level builder only keeps levels the solver can win
##   - the tests replay every stored solution to prove every level is winnable
##   - the Hint button asks it for the next good move
##
## It is a best-first search: always look next at the position that seems
## closest to winning, and never look at the same position twice.

var max_expansions := 60000
var weight := 2.0          ## >1 trades a slightly longer answer for speed
var expansions := 0

## Returns the moves that win, or [] if none was found within the limit.
func solve(start: Board) -> Array[Vector3i]:
	expansions = 0
	var root := start.clone()
	root.move_budget = 1 << 20   # the solver ignores the budget; the builder sets it
	root.moves_used = 0
	if root.is_won():
		return []
	var boards: Array[Board] = [root]
	var parent := PackedInt32Array([-1])
	var via: Array[Vector3i] = [Vector3i.ZERO]
	var seen := {root.key(): true}
	var heap := _Heap.new()
	heap.push(_score(root), 0)
	while not heap.is_empty() and expansions < max_expansions:
		var n := heap.pop()
		var b: Board = boards[n]
		boards[n] = null   # expanded: free it, we only need parent links now
		expansions += 1
		for m in _ordered_moves(b):
			var nb := b.clone()
			nb.apply(m)
			var k := nb.key()
			if seen.has(k):
				continue
			seen[k] = true
			boards.append(nb)
			parent.append(n)
			via.append(m)
			var idx := boards.size() - 1
			if nb.is_won():
				return _path(idx, parent, via)
			heap.push(_score(nb), idx)
	return []

func _score(b: Board) -> float:
	return float(b.moves_used) + weight * float(b.estimate())

## Skips moves that can never help, so the search stays small.
func _ordered_moves(b: Board) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for m in b.legal_moves():
		if m.x == Board.TO_COLUMN and m.y != Board.WASTE:
			var col: Array = b.columns[m.y]
			var unit := b.unit_at(m.y)
			# Moving a whole face-up pile into an empty column changes nothing.
			if b.columns[m.z].is_empty() and unit.size() == col.size():
				continue
		out.append(m)
	return out

func _path(idx: int, parent: PackedInt32Array, via: Array[Vector3i]) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	while parent[idx] != -1:
		out.push_front(via[idx])
		idx = parent[idx]
	return out

## Min-heap of (score, node). Ties go to the newest node, which keeps the
## search diving instead of spreading out.
class _Heap:
	var _s := PackedFloat64Array()
	var _n := PackedInt32Array()
	var _seq := 0

	func is_empty() -> bool:
		return _n.is_empty()

	func push(score: float, node: int) -> void:
		_seq += 1
		_s.append(score - float(_seq) * 1e-9)
		_n.append(node)
		var i := _n.size() - 1
		while i > 0:
			var p := (i - 1) >> 1
			if _s[p] <= _s[i]:
				break
			_swap(i, p)
			i = p

	func pop() -> int:
		var top := _n[0]
		var last := _n.size() - 1
		_swap(0, last)
		_s.resize(last)
		_n.resize(last)
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < last and _s[l] < _s[m]:
				m = l
			if r < last and _s[r] < _s[m]:
				m = r
			if m == i:
				break
			_swap(i, m)
			i = m
		return top

	func _swap(a: int, b: int) -> void:
		var ts := _s[a]
		_s[a] = _s[b]
		_s[b] = ts
		var tn := _n[a]
		_n[a] = _n[b]
		_n[b] = tn
