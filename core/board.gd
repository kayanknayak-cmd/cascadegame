class_name Board
extends RefCounted
## The rules of the game, with no drawing and no input. Everything that can
## happen to the cards happens here, so the solver, the tests and the screen
## all agree on what is legal.
##
## Layout of a level:
##   columns - piles of cards. Only the top card of each pile is face-up at
##             first; the rest are face-down and flip over when uncovered.
##   stock   - the draw pile. Tapping it turns one card over onto the waste.
##   waste   - the turned-over cards. Only the top one can be played.
##   slots   - where groups are built. An empty slot takes any card and is
##             then claimed by that card's group. When every card of a group
##             is in its slot, the group completes and the slot is freed.
##
## A move is a Vector3i(kind, src, dst):
##   DRAW          (0, 0, 0)
##   TO_SLOT       (1, src, slot)   src = -1 for the waste, else a column
##   TO_COLUMN     (2, src, column)
## Moving from a column carries the whole run of same-group face-up cards on
## top of it, not just the top card.

enum { DRAW, TO_SLOT, TO_COLUMN }
enum Check { OK, WRONG_GROUP, ILLEGAL }

const WASTE := -1

var card_group := PackedInt32Array()
var card_label := PackedStringArray()
var group_names := PackedStringArray()
var group_size := PackedInt32Array()

var columns: Array = []            ## Array of Array[int], bottom -> top
var face_down := PackedInt32Array() ## per column: how many bottom cards are hidden
var stock: Array = []              ## top = last
var waste: Array = []              ## top = last
var slot_group := PackedInt32Array()  ## -1 = empty
var slot_cards: Array = []         ## Array of Array[int]
var completed: Array = []          ## group ids, in the order they finished
var moves_used := 0
var move_budget := 0

# ---------------------------------------------------------------- building

## level = { groups: [{name, cards: [label...]}], columns: [[card idx...]],
##           stock: [card idx...], slots: int, budget: int }
## Cards are numbered in group order: group 0's cards first, then group 1's...
static func from_level(level: Dictionary) -> Board:
	var b := Board.new()
	for gi in level.groups.size():
		var g: Dictionary = level.groups[gi]
		b.group_names.append(String(g.name))
		b.group_size.append(g.cards.size())
		for label in g.cards:
			b.card_group.append(gi)
			b.card_label.append(String(label))
	for col in level.columns:
		var c: Array = []
		for idx in col:
			c.append(int(idx))
		b.columns.append(c)
		b.face_down.append(maxi(c.size() - 1, 0))
	for idx in level.stock:
		b.stock.append(int(idx))
	for i in int(level.slots):
		b.slot_group.append(-1)
		b.slot_cards.append([])
	b.move_budget = int(level.get("budget", 999))
	return b

func clone() -> Board:
	var b := Board.new()
	b.card_group = card_group
	b.card_label = card_label
	b.group_names = group_names
	b.group_size = group_size
	b.columns = columns.duplicate(true)
	b.face_down = face_down.duplicate()
	b.stock = stock.duplicate()
	b.waste = waste.duplicate()
	b.slot_group = slot_group.duplicate()
	b.slot_cards = slot_cards.duplicate(true)
	b.completed = completed.duplicate()
	b.moves_used = moves_used
	b.move_budget = move_budget
	return b

# ---------------------------------------------------------------- questions

func group_count() -> int:
	return group_names.size()

func moves_left() -> int:
	return move_budget - moves_used

func is_won() -> bool:
	return completed.size() == group_count()

func is_lost() -> bool:
	return not is_won() and (moves_left() <= 0 or legal_moves().is_empty())

func is_face_up(col: int, index: int) -> bool:
	return index >= face_down[col]

## The cards that would travel if you picked up from `src`.
func unit_at(src: int) -> Array:
	if src == WASTE:
		return [] if waste.is_empty() else [waste[-1]]
	var col: Array = columns[src]
	if col.is_empty():
		return []
	var g := card_group[col[-1]]
	var start := col.size() - 1
	while start - 1 >= face_down[src] and card_group[col[start - 1]] == g:
		start -= 1
	return col.slice(start)

func slot_of_group(g: int) -> int:
	for j in slot_group.size():
		if slot_group[j] == g:
			return j
	return -1

func check(m: Vector3i) -> Check:
	if m.x == DRAW:
		return Check.OK if not (stock.is_empty() and waste.is_empty()) else Check.ILLEGAL
	var unit := unit_at(m.y)
	if unit.is_empty():
		return Check.ILLEGAL
	var g := card_group[unit[0]]
	if m.x == TO_SLOT:
		if m.z < 0 or m.z >= slot_group.size():
			return Check.ILLEGAL
		var sg := slot_group[m.z]
		if sg == -1:
			# A group lives in one slot only.
			return Check.OK if slot_of_group(g) == -1 else Check.ILLEGAL
		return Check.OK if sg == g else Check.WRONG_GROUP
	if m.x == TO_COLUMN:
		if m.z < 0 or m.z >= columns.size() or m.z == m.y:
			return Check.ILLEGAL
		var dst: Array = columns[m.z]
		if dst.is_empty():
			return Check.OK
		return Check.OK if card_group[dst[-1]] == g else Check.WRONG_GROUP
	return Check.ILLEGAL

func legal_moves() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if moves_left() <= 0:
		return out
	var sources: Array[int] = [WASTE]
	for c in columns.size():
		sources.append(c)
	for s in sources:
		var unit := unit_at(s)
		if unit.is_empty():
			continue
		for j in slot_group.size():
			var m := Vector3i(TO_SLOT, s, j)
			if check(m) == Check.OK:
				out.append(m)
		for k in columns.size():
			var m := Vector3i(TO_COLUMN, s, k)
			if check(m) == Check.OK:
				out.append(m)
	if check(Vector3i(DRAW, 0, 0)) == Check.OK:
		out.append(Vector3i(DRAW, 0, 0))
	return out

# ---------------------------------------------------------------- doing

## Applies a move that check() said was OK. Returns what happened, for the
## screen to animate: { cards, flipped_col, completed_group, completed_slot,
## recycled }.
func apply(m: Vector3i) -> Dictionary:
	var ev := {"cards": [], "flipped_col": -1, "completed_group": -1,
			"completed_slot": -1, "recycled": false}
	moves_used += 1
	if m.x == DRAW:
		if stock.is_empty():
			waste.reverse()
			stock = waste
			waste = []
			ev.recycled = true
		else:
			var c: int = stock.pop_back()
			waste.append(c)
			ev.cards = [c]
		return ev
	var unit := unit_at(m.y)
	ev.cards = unit
	if m.y == WASTE:
		waste.pop_back()
	else:
		var col: Array = columns[m.y]
		col.resize(col.size() - unit.size())
		if not col.is_empty() and face_down[m.y] >= col.size():
			face_down[m.y] = col.size() - 1
			ev.flipped_col = m.y
	if m.x == TO_SLOT:
		var g := card_group[unit[0]]
		slot_group[m.z] = g
		slot_cards[m.z].append_array(unit)
		if slot_cards[m.z].size() == group_size[g]:
			completed.append(g)
			slot_group[m.z] = -1
			slot_cards[m.z] = []
			ev.completed_group = g
			ev.completed_slot = m.z
	else:
		columns[m.z].append_array(unit)
	return ev

## A wrong-group drop still costs a move. That's what makes guessing matter.
func spend_mistake() -> void:
	moves_used += 1

# ---------------------------------------------------------------- solver support

## Everything that matters for "can this still be won", packed tight so the
## solver can remember millions of positions. moves_used is left out on
## purpose: the same position reached in fewer moves is the same position.
func key() -> String:
	var p := PackedInt32Array()
	for c in columns.size():
		p.append(face_down[c])
		p.append_array(PackedInt32Array(columns[c]))
		p.append(-2)
	p.append_array(PackedInt32Array(stock))
	p.append(-3)
	p.append_array(PackedInt32Array(waste))
	p.append(-4)
	for j in slot_group.size():
		p.append(slot_group[j])
		p.append(slot_cards[j].size())
	p.append(completed.size())
	return p.to_byte_array().hex_encode()

## A rough count of the moves still needed: every separate place holding
## cards of an unfinished group needs at least one move to reach its slot.
func estimate() -> int:
	var places := {}
	for c in columns.size():
		var col: Array = columns[c]
		var last := -1
		for i in col.size():
			var g := card_group[col[i]]
			if g != last or i < face_down[c]:
				places[Vector2i(c, i)] = true
			last = g
	return places.size() + stock.size() + waste.size()
