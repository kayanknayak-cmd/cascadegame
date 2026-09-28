extends Node2D
## The play screen. Board holds the rules; this file turns them into cards
## you can drag, and makes every good move feel good.
##
## The reward ladder, smallest to biggest:
##   pick up   - card lifts, shadow drops, a soft slide
##   drop      - arc, squash, a thud, a puff of dust
##   into slot - a bell that climbs with each card, a dot fills, the slot pulses
##   3 of 4    - the slot starts glowing: one more!
##   group     - a split-second freeze, screen punch, rays, shockwave; the
##               cards fan out ringing a rising scale, a ribbon names the group,
##               then the cards zip up into a star and coins pour out
##   streak    - groups within a few moves of each other raise the key, the
##               words get bigger and the coins multiply
##   level     - leftover moves cash out into coins one by one, then confetti
##               and stars slam in
## Every step fires on at least three of sight, sound, touch and meaning.

const W := 720.0
const CARD := CardView.SIZE
const SLOT_Y := 322.0
const TABLEAU_TOP := 530.0
const DOWN_STEP := 26.0
const UP_STEP := 60.0
const LOW_MOVES := 5
const STREAK_WINDOW := 4        ## moves allowed between groups to keep a streak
const FAN_Y := 500.0

const STREAK_WORDS := ["Nice!", "Great!", "Wonderful!", "Amazing!", "Spectacular!", "Unstoppable!"]
const TIPS := {
	0: "Drag a card to a slot to start a group",
	1: "Tap the deck to draw a card",
	2: "Same-group cards can stack in the piles",
	6: "A third slot! Choose your groups wisely",
}

var levels: Array = []
var level_index := 0
var level: Dictionary
var board: Board
var views: Array[CardView] = []

var H := 1280.0
var ox := 0.0

var _undo: Array[Board] = []
var undos_left := 3
var hints_left := 3
var streak := -1
var _last_complete_at := -99
var _drag: Dictionary = {}
var _hover := Vector3i(-1, -1, -1)
var _hint: Dictionary = {}
var _celebrating: Array[Tween] = []
var _seq := 0                   ## bumps on undo/restart so stale timers do nothing
var _trailing: Dictionary = {}  ## cards that belong to a celebration, not the board
var _input_locked_until := 0.0
var _clock := 0.0
var _last_input := 0.0
var _next_gleam := 3.0

# Presentation state
var _moves_shown := 0
var _moves_pop := 0.0
var _coin_shown := 0
var _coin_pop := 0.0
var _slot_pulse: Array[float] = []
var _pip_pop: Array[float] = []
var _pips_lit := 0
var _punch := 0.0
var _shake := 0.0
var _tip := ""
var _demo_t := -1.0             ## ghost-finger demo on the first levels

var _overlay := ""              ## "" | "win" | "lose"
var _overlay_age := 0.0
var _win_stars := 0
var _win_coins := 0
var _win_coins_shown := 0
var _stars_shown := 0
var _star_slam: Array[float] = [0.0, 0.0, 0.0]
var _bonus_running := false
var _overlay_sparks: Array[Dictionary] = []

var fx: Fx
var _bg: CanvasLayer
var _ui: CanvasLayer
var _overlay_layer: CanvasLayer
var _overlay_draw: Node2D
var _undo_btn: PillButton
var _hint_btn: PillButton
var _overlay_buttons: Array[PillButton] = []
var _above_cards: Node2D         ## small badges that must sit on top of the deck

# ---------------------------------------------------------------- setup

func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	levels = data.levels
	_build_background()
	fx = Fx.new()
	add_child(fx)
	_above_cards = Node2D.new()
	_above_cards.z_index = 700
	_above_cards.draw.connect(_draw_above_cards)
	add_child(_above_cards)
	_build_ui()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	start_level(Progress.level % levels.size())

func _on_resize() -> void:
	var s := get_viewport_rect().size
	H = maxf(s.y, 1180.0)
	ox = maxf((s.x - W) * 0.5, 0.0)
	_place_buttons()
	if board:
		_layout(false)
	queue_redraw()

func start_level(index: int) -> void:
	_seq += 1
	level_index = index
	level = levels[index]
	board = Board.from_level(level)
	_undo.clear()
	undos_left = 3
	hints_left = 3
	streak = -1
	_last_complete_at = -99
	_drag = {}
	_hover = Vector3i(-1, -1, -1)
	_hint = {}
	_trailing.clear()
	_overlay = ""
	_bonus_running = false
	_stars_shown = 0
	_moves_shown = board.moves_left()
	_coin_shown = Progress.coins
	_pips_lit = 0
	_slot_pulse.resize(board.slot_group.size())
	_slot_pulse.fill(0.0)
	_pip_pop.resize(board.group_count())
	_pip_pop.fill(0.0)
	Engine.time_scale = 1.0
	for t in _celebrating:
		if t.is_valid():
			t.kill()
	_celebrating.clear()
	for v in views:
		v.queue_free()
	views.clear()
	for i in board.card_label.size():
		var v := CardView.new()
		v.card = i
		v.label = board.card_label[i]
		add_child(v)
		v.snap_to(_stock_pos())
		views.append(v)
	move_child(fx, -1)
	_tip = TIPS.get(index, "")
	_demo_t = 0.0 if index <= 1 else -1.0
	_show_overlay_buttons()
	_refresh_buttons()
	_deal_in()
	queue_redraw()

## Level intro, then cards arc out of the deck one by one with a patter of
## ticks, then the top cards flip over in a wave.
func _deal_in() -> void:
	var seq := _seq
	fx.popup("Level %d" % (level_index + 1), Vector2(ox + W * 0.5, H * 0.42), Style.CREAM, 76, 30.0, 1.4, "big")
	fx.popup("%d groups to find" % board.group_count(), Vector2(ox + W * 0.5, H * 0.42 + 70.0), Style.GOLD, 34, 30.0, 1.4)
	Audio.deal_start()
	var order := 0
	var start := 0.35
	for c in board.columns.size():
		var col: Array = board.columns[c]
		for i in col.size():
			var v := views[col[i]]
			v.z_index = 10 + i
			v.rest_rotation = 0.0
			v.on_land = Audio.deal_tick
			v.move_to(_column_card_pos(c, i), 0.32, start + order * 0.045, 70.0)
			order += 1
	_layout_stock_and_waste(false)
	var flip_at := start + order * 0.045 + 0.3
	for c in board.columns.size():
		var col: Array = board.columns[c]
		if col.is_empty():
			continue
		views[col[-1]].flip_up(flip_at + c * 0.07)
	_input_locked_until = _clock + flip_at + 0.25
	_later(flip_at + 0.6, seq, _gleam_playable)

# ---------------------------------------------------------------- geometry

func _slot_pos(j: int) -> Vector2:
	var n := board.slot_group.size()
	return Vector2(ox + W * 0.5 + (j - (n - 1) * 0.5) * (CARD.x + 40.0), SLOT_Y)

func _column_x(c: int) -> float:
	var n := board.columns.size()
	var gap := minf(26.0, (W - 20.0 - n * CARD.x) / maxf(n - 1, 1))
	var total := n * CARD.x + (n - 1) * gap
	return ox + (W - total) * 0.5 + CARD.x * 0.5 + c * (CARD.x + gap)

func _column_card_pos(c: int, i: int) -> Vector2:
	var col: Array = board.columns[c]
	var fd: int = board.face_down[c]
	var downs := mini(fd, col.size())
	var ups := maxi(col.size() - 1 - downs, 0)
	var room := (_stock_pos().y - CARD.y * 0.5 - 36.0) - (TABLEAU_TOP + CARD.y)
	var up_step := UP_STEP
	if ups > 0:
		up_step = clampf((room - downs * DOWN_STEP) / ups, 34.0, UP_STEP)
	var y := TABLEAU_TOP + CARD.y * 0.5
	for k in i:
		y += DOWN_STEP if k < fd else up_step
	return Vector2(_column_x(c), y)

func _stock_pos() -> Vector2:
	return Vector2(ox + 94.0, H - 148.0)

func _waste_pos() -> Vector2:
	return Vector2(ox + 246.0, H - 148.0)

func _card_rect(center: Vector2) -> Rect2:
	return Rect2(center - CARD * 0.5, CARD)

func _moves_pos() -> Vector2:
	return Vector2(ox + W * 0.5, 66.0)

func _coin_hud_pos() -> Vector2:
	return Vector2(ox + W - 150.0, 54.0)

func _pip_pos(i: int) -> Vector2:
	var n := board.group_count()
	return Vector2(ox + W * 0.5 + (i - (n - 1) * 0.5) * 40.0, 150.0)

## A card's resting tilt, the same every time for the same card, so stacks
## in slots look hand-placed instead of machine-stacked.
func _jitter(card: int, amount: float) -> float:
	return (float((card * 7919 + 13) % 97) / 96.0 - 0.5) * 2.0 * amount

# ---------------------------------------------------------------- layout

## Moves every card to where the board says it is.
func _layout(animate := true) -> void:
	var dragged := {}
	if not _drag.is_empty():
		for v in _drag.views:
			dragged[v.card] = true
	for c in board.columns.size():
		var col: Array = board.columns[c]
		for i in col.size():
			_place(views[col[i]], _column_card_pos(c, i), 10 + i, i >= board.face_down[c], 0.0, animate, dragged)
	for j in board.slot_group.size():
		var sc: Array = board.slot_cards[j]
		for i in sc.size():
			var pos := _slot_pos(j) + Vector2(0, -7.0 * (sc.size() - 1 - i))
			_place(views[sc[i]], pos, 300 + i, true, _jitter(sc[i], 0.06), animate, dragged)
	_layout_stock_and_waste(animate, dragged)
	queue_redraw()
	_above_cards.queue_redraw()

func _layout_stock_and_waste(animate: bool, dragged := {}) -> void:
	for i in board.stock.size():
		_place(views[board.stock[i]], _stock_pos() + Vector2(0, -1.4 * i), 100 + i, false, 0.0, animate, dragged)
	var n := board.waste.size()
	for i in n:
		var fan := maxi(i - (n - 3), 0)
		_place(views[board.waste[i]], _waste_pos() + Vector2(fan * 28.0, 0), 150 + i, true,
			_jitter(board.waste[i], 0.04), animate, dragged)

func _place(v: CardView, pos: Vector2, z: int, up: bool, rot: float, animate: bool, dragged: Dictionary) -> void:
	if dragged.has(v.card) or _trailing.has(v.card):
		return
	v.visible = true
	v.z_index = z
	v.rest_rotation = rot
	if v.gold > 0.0:
		v.set_gold(0.0)
	if up and not v.face_up:
		if animate:
			v.flip_up(0.1)
		else:
			v.set_face(true)
	elif not up and v.face_up:
		v.set_face(false)
	if animate:
		var d := v.position.distance_to(pos)
		v.move_to(pos, clampf(0.12 + d / 2600.0, 0.14, 0.34), 0.0, clampf(d * 0.18, 0.0, 110.0), d > 4.0)
	else:
		v.snap_to(pos)

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if _overlay != "" or _clock < _input_locked_until:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_last_input = _clock
		var p := to_local(event.position)
		if event.pressed:
			_press(p)
		else:
			_release(p)
	elif event is InputEventMouseMotion and not _drag.is_empty():
		_drag_to(to_local(event.position))

func _press(p: Vector2) -> void:
	if _card_rect(_stock_pos()).grow(12).has_point(p):
		draw_card()
		return
	var src := _source_at(p)
	if src == -2:
		return
	var unit := board.unit_at(src)
	var vs: Array[CardView] = []
	var offsets: Array[Vector2] = []
	for k in unit.size():
		var v := views[unit[k]]
		vs.append(v)
		offsets.append(v.position - p + Vector2(0, -14))
		v.z_index = 800 + k
		v.drag_stiffness = 30.0 - k * 5.0     # later cards trail behind a little
		v.grab()
	_drag = {"src": src, "views": vs, "offsets": offsets, "start": p, "moved": false}
	_clear_hint()
	Audio.pick()
	_haptic(8)

func _source_at(p: Vector2) -> int:
	if not board.waste.is_empty():
		var top := views[board.waste[-1]]
		if _card_rect(top.position).has_point(p):
			return Board.WASTE
	for c in board.columns.size():
		var unit := board.unit_at(c)
		if unit.is_empty():
			continue
		var first := views[unit[0]].position
		var last := views[unit[-1]].position
		if _card_rect(first).merge(_card_rect(last)).has_point(p):
			return c
	return -2

func _drag_to(p: Vector2) -> void:
	if p.distance_to(_drag.start) > 12.0:
		_drag.moved = true
	for i in _drag.views.size():
		_drag.views[i].drag_target = p + _drag.offsets[i]
	var h := _target_at(p + _drag.offsets[0])
	if h != _hover:
		_hover = h
		queue_redraw()

func _release(p: Vector2) -> void:
	if _drag.is_empty():
		return
	var d := _drag
	for v in d.views:
		v.release()
	_drag = {}
	_hover = Vector3i(-1, -1, -1)
	if not d.moved:
		tap(d.src)
		return
	var target := _target_at(p + d.offsets[0])
	if target.x == -1:
		Audio.undo()
		_layout()
		return
	try_move(Vector3i(target.x, d.src, target.z))

## Where a card whose centre is at `c` would land.
func _target_at(c: Vector2) -> Vector3i:
	for j in board.slot_group.size():
		if _card_rect(_slot_pos(j)).grow(40).has_point(c):
			return Vector3i(Board.TO_SLOT, 0, j)
	if c.y > TABLEAU_TOP - 70.0:
		var best := -1
		var best_d := 1e9
		for k in board.columns.size():
			var dx := absf(c.x - _column_x(k))
			if dx < CARD.x * 0.7 and dx < best_d:
				best = k
				best_d = dx
		if best != -1:
			return Vector3i(Board.TO_COLUMN, 0, best)
	return Vector3i(-1, -1, -1)

# ---------------------------------------------------------------- moves

func draw_card() -> void:
	try_move(Vector3i(Board.DRAW, 0, 0))

## A tap sends the card somewhere sensible: its group's slot, then a pile
## topped by its group, then an empty slot. Nowhere to go = a shake, free.
func tap(src: int) -> void:
	var unit := board.unit_at(src)
	if unit.is_empty():
		return
	var g := board.card_group[unit[0]]
	var options: Array[Vector3i] = []
	var own := board.slot_of_group(g)
	if own != -1:
		options.append(Vector3i(Board.TO_SLOT, src, own))
	for k in board.columns.size():
		var col: Array = board.columns[k]
		if k != src and not col.is_empty() and board.card_group[col[-1]] == g:
			options.append(Vector3i(Board.TO_COLUMN, src, k))
	for j in board.slot_group.size():
		if board.slot_group[j] == -1:
			options.append(Vector3i(Board.TO_SLOT, src, j))
	for m in options:
		if board.check(m) == Board.Check.OK:
			_commit(m)
			return
	for c in unit:
		views[c].start_shake()
	Audio.wrong()
	_layout()

func try_move(m: Vector3i) -> bool:
	if _overlay != "":
		return false
	match board.check(m):
		Board.Check.OK:
			_commit(m)
			return true
		Board.Check.WRONG_GROUP:
			_mistake(m)
		_:
			_layout()
	return false

func _commit(m: Vector3i) -> void:
	_undo.append(board.clone())
	_clear_hint()
	var slot_before := -1
	if m.x == Board.TO_SLOT:
		slot_before = board.slot_cards[m.z].size()
	var ev := board.apply(m)
	_moves_shown = board.moves_left()
	_moves_pop = 1.0
	if board.moves_left() <= LOW_MOVES and board.moves_left() > 0:
		Audio.low_moves()
	var key := _key()
	if m.x == Board.DRAW:
		if ev.recycled:
			Audio.recycle()
		else:
			Audio.draw_card()
		_layout()
	elif ev.completed_group != -1:
		# Fly the cards into the slot first; the celebration starts on landing.
		var g: int = ev.completed_group
		var slot: int = ev.completed_slot
		var seq := _seq
		var done_at := board.moves_used
		var all := _group_cards(g)
		for c in all:
			_trailing[c] = true
		for i in ev.cards.size():
			var v := views[ev.cards[i]]
			v.z_index = 820 + i
			var d := v.position.distance_to(_slot_pos(slot))
			v.move_to(_slot_pos(slot) + Vector2(0, -7.0 * (slot_before + i)), clampf(0.12 + d / 2600.0, 0.14, 0.3),
				0.0, clampf(d * 0.18, 0.0, 110.0))
		views[ev.cards[-1]].on_land = func():
			if seq == _seq:
				_complete_sequence(g, slot, all, done_at)
		_layout()
	else:
		_layout()
		var lead := views[ev.cards[0]]
		if m.x == Board.TO_SLOT:
			var count: int = board.slot_cards[m.z].size()
			var j := m.z
			lead.on_land = func():
				Audio.into_slot(count, key)
				if j < _slot_pulse.size():
					_slot_pulse[j] = 1.0
				fx.puff(_slot_pos(j) + Vector2(0, CARD.y * 0.5))
				_haptic(12)
		else:
			lead.on_land = func():
				Audio.land()
				fx.puff(lead.position + Vector2(0, CARD.y * 0.5))
				_haptic(8)
	_refresh_buttons()
	_check_end()

func _group_cards(g: int) -> Array:
	var out: Array = []
	for i in board.card_group.size():
		if board.card_group[i] == g:
			out.append(i)
	return out

func _mistake(m: Vector3i) -> void:
	board.spend_mistake()
	_moves_shown = board.moves_left()
	_moves_pop = 1.0
	for c in board.unit_at(m.y):
		var v := views[c]
		v.start_shake()
		var t := create_tween()
		t.tween_property(v, "modulate", Color(1, 0.6, 0.55), 0.06)
		t.tween_property(v, "modulate", Color.WHITE, 0.35)
	Audio.wrong()
	_haptic(40)
	_shake = maxf(_shake, 0.5)
	var at := _slot_pos(m.z) if m.x == Board.TO_SLOT else Vector2(_column_x(m.z), TABLEAU_TOP)
	fx.popup("Not this group", at + Vector2(0, -70), Style.WARN, 32, 40.0, 1.1)
	fx.popup("-1 move", _moves_pos() + Vector2(0, 70), Style.WARN, 28, 30.0, 1.0)
	_layout()
	_refresh_buttons()
	_check_end()

func _check_end() -> void:
	if board.is_won():
		# Let the last group's celebration play out first.
		_later(2.6, _seq, _start_win)
	elif board.is_lost():
		_later(0.7, _seq, _show_lose)

func undo() -> void:
	if _undo.is_empty() or undos_left <= 0 or _overlay == "win" or _bonus_running:
		return
	_seq += 1
	Engine.time_scale = 1.0
	for t in _celebrating:
		if t.is_valid():
			t.kill()
	_celebrating.clear()
	_trailing.clear()
	board = _undo.pop_back()
	undos_left -= 1
	_moves_shown = board.moves_left()
	_pips_lit = board.completed.size()
	_overlay = ""
	_show_overlay_buttons()
	_clear_hint()
	for v in views:
		v.reset_look()
		v.rotation = 0.0
	_layout()
	Audio.undo()
	_refresh_buttons()

func hint() -> void:
	if hints_left <= 0 or _overlay != "":
		return
	var solver := Solver.new()
	solver.max_expansions = 6000
	var sol := solver.solve(board)
	if sol.is_empty() or sol.size() > board.moves_left():
		fx.popup("No way to win from here. Try Undo!", Vector2(ox + W * 0.5, H * 0.5), Style.WARN, 32, 30.0, 2.2)
		Audio.wrong()
		return
	hints_left -= 1
	Audio.hint()
	_show_hint(sol[0])
	_refresh_buttons()

func _show_hint(m: Vector3i) -> void:
	_clear_hint()
	_hint = {"move": m}
	if m.x != Board.DRAW:
		for c in board.unit_at(m.y):
			views[c].set_glow(1.0)
			views[c].pop(0.08)
			views[c].start_sheen()
		if m.x == Board.TO_COLUMN and not board.columns[m.z].is_empty():
			views[board.columns[m.z][-1]].set_glow(1.0)
	queue_redraw()

func _clear_hint() -> void:
	if _hint.is_empty():
		return
	_hint = {}
	for v in views:
		if v.glow > 0.0:
			v.set_glow(0.0)
	queue_redraw()

## Current musical key: each streak step moves it up a whole tone.
func _key() -> int:
	return 2 * clampi(streak + 1, 0, 5)

# ---------------------------------------------------------------- group celebration

func _complete_sequence(g: int, slot: int, cards: Array, done_at: int) -> void:
	var seq := _seq
	# Groups finished within a few moves of each other build a streak.
	if done_at - _last_complete_at <= STREAK_WINDOW:
		streak += 1
	else:
		streak = 0
	_last_complete_at = done_at
	var key := _key()
	var at := _slot_pos(slot)

	# The hit: a split-second freeze, then the punch.
	Audio.group_hit(key)
	_haptic(35)
	_hitstop(0.075)
	_punch = 1.0
	_shake = maxf(_shake, 0.7 + 0.1 * mini(streak, 3))
	if slot < _slot_pulse.size():
		_slot_pulse[slot] = 1.0
	fx.ring(at, 260.0)
	fx.rays(at, 1.3)
	fx.burst(at, 34 + 8 * mini(streak, 5), 600.0 + 60.0 * mini(streak, 5), Fx.WARM)

	# Fan out, ringing up the scale.
	var n := cards.size()
	for i in n:
		var v := views[cards[i]]
		v.set_gold(1.0)
		v.z_index = 860 + i
		v.rest_rotation = (i - (n - 1) * 0.5) * 0.09
		var spot := Vector2(ox + W * 0.5 + (i - (n - 1) * 0.5) * 136.0, FAN_Y + absf(i - (n - 1) * 0.5) * 14.0)
		v.on_land = func():
			if seq != _seq:
				return
			Audio.fan_note(i, key)
			v.flash = 1.0
			v.pop(0.12)
			fx.burst(v.position, 10, 280.0, Fx.WARM)
		v.move_to(spot, 0.26, 0.08 + i * 0.07, 60.0)

	if streak >= 1:
		var word: String = STREAK_WORDS[mini(streak - 1, STREAK_WORDS.size() - 1)]
		var st := streak
		_later(0.3, seq, func():
			fx.popup(word, Vector2(ox + W * 0.5, FAN_Y - 150.0), Style.GOLD, 58 + 6 * mini(st, 5), 50.0, 1.4, "big")
			fx.popup("Streak x%d" % (st + 1), Vector2(ox + W * 0.5, FAN_Y - 96.0), Color.WHITE, 30, 40.0, 1.3)
			Audio.streak_up(st))
	var done := board.completed.find(g) + 1
	var gname: String = board.group_names[g]
	_later(0.5, seq, func():
		fx.banner(gname, "%d of %d groups" % [done, board.group_count()], Vector2(ox + W * 0.5, FAN_Y + 150.0), 1.5))

	# Zip up into the star socket, trailing sparkles.
	var pip := done - 1
	for i in n:
		var v := views[cards[i]]
		_later(1.05 + i * 0.07, seq, func():
			var t := create_tween()
			_celebrating.append(t)
			t.set_parallel(true)
			t.tween_property(v, "position", _pip_pos(pip), 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			t.tween_property(v, "scale", Vector2.ONE * 0.16, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_property(v, "rotation", v.rotation + (1.0 if i % 2 == 0 else -1.0) * 1.2, 0.42)
			t.set_parallel(false)
			t.tween_callback(func(): v.visible = false))
	var coins := 5 + 5 * mini(maxi(streak, 0), 5)
	Progress.coins += coins
	_later(1.05 + (n - 1) * 0.07 + 0.42, seq, func():
		_pips_lit = maxi(_pips_lit, pip + 1)
		if pip < _pip_pop.size():
			_pip_pop[pip] = 1.0
		Audio.star_pip(key)
		fx.burst(_pip_pos(pip), 22, 380.0, Fx.WARM)
		fx.ring(_pip_pos(pip), 70.0, Style.GOLD, 0.35)
		Audio.coins_burst()
		_fly_coins(_pip_pos(pip), coins))

func _fly_coins(from: Vector2, total: int) -> void:
	var n := clampi(total, 1, 14)
	var each := float(total) / float(n)
	var landed := [0]
	fx.coins(from, _coin_hud_pos(), n, func():
		landed[0] += 1
		if total > 0:
			_coin_shown = mini(_coin_shown + ceili(each), Progress.coins) if landed[0] < n else Progress.coins
		_coin_pop = 1.0
		Audio.coin(landed[0])
		queue_redraw())

func _later(delay: float, seq: int, f: Callable) -> void:
	get_tree().create_timer(delay).timeout.connect(func():
		if seq == _seq:
			f.call())

## A tiny freeze-frame that makes a big moment land.
func _hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

func _haptic(ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

## Every few seconds a playable card catches the light, inviting a touch.
func _gleam_playable() -> void:
	var tops: Array = []
	for c in board.columns.size():
		var u := board.unit_at(c)
		if not u.is_empty():
			tops.append(u[-1])
	if not board.waste.is_empty():
		tops.append(board.waste[-1])
	if tops.is_empty():
		return
	views[tops[randi() % tops.size()]].start_sheen()

# ---------------------------------------------------------------- winning and losing

func _stars_for_finish() -> int:
	var frac := float(board.moves_left()) / float(maxi(board.move_budget, 1))
	if frac >= 0.25:
		return 3
	if frac >= 0.1:
		return 2
	return 1

## Leftover moves cash out one at a time, each flinging a coin, faster and
## higher as it goes. Then the results card.
func _start_win() -> void:
	if _overlay != "" or _bonus_running:
		return
	var seq := _seq
	_win_stars = _stars_for_finish()
	var left := board.moves_left()
	var bonus := left * 2
	_win_coins = 20 + 10 * _win_stars + bonus
	Progress.finish_level(level_index, _win_stars, _win_coins)
	_bonus_running = true
	if left <= 0:
		_show_win()
		return
	fx.popup("Moves bonus!", Vector2(ox + W * 0.5, H * 0.45), Style.GOLD, 64, 40.0, 1.3, "big")
	var ticks := mini(left, 24)
	var per_tick := float(left) / ticks
	var t := 0.5
	for i in ticks:
		t += lerpf(0.13, 0.05, float(i) / ticks)
		_later(t, seq, func():
			_moves_shown = maxi(0, left - int(round(per_tick * (i + 1))))
			_moves_pop = 1.0
			Audio.bonus_tick(i)
			fx.burst(_moves_pos(), 6, 220.0, Fx.WARM)
			_fly_coins(_moves_pos(), 0))
	_later(t + 0.7, seq, _show_win)

func _show_win() -> void:
	if _overlay == "win":
		return
	var seq := _seq
	_overlay = "win"
	_overlay_age = 0.0
	_bonus_running = false
	_win_coins_shown = 0
	_stars_shown = 0
	_star_slam = [0.0, 0.0, 0.0]
	fx.confetti(get_viewport_rect().size.x)
	Audio.panel_in()
	Audio.win()
	_haptic(60)
	_show_overlay_buttons()
	for i in _win_stars:
		_later(0.55 + i * 0.32, seq, func():
			_stars_shown = i + 1
			_star_slam[i] = 1.0
			Audio.star(i)
			_shake = maxf(_shake, 0.35)
			_haptic(25)
			_overlay_burst(_star_pos(i)))
	var count_start := 0.55 + _win_stars * 0.32 + 0.2
	var steps := 18
	for k in steps:
		_later(count_start + k * 0.04, seq, func():
			_win_coins_shown = int(round(float(_win_coins) * (k + 1) / steps))
			Audio.coin(k))
	_later(count_start + steps * 0.04 + 0.1, seq, func():
		_coin_shown = Progress.coins
		_coin_pop = 1.0)

func _overlay_burst(at: Vector2) -> void:
	for i in 18:
		_overlay_sparks.append({"p": at, "v": Vector2.from_angle(randf() * TAU) * randf_range(120, 420),
			"age": 0.0, "life": randf_range(0.4, 0.7), "s": randf_range(6.0, 12.0)})

func _show_lose() -> void:
	if _overlay != "" or board.is_won():
		return
	_overlay = "lose"
	_overlay_age = 0.0
	Audio.lose()
	Audio.panel_in()
	_show_overlay_buttons()

func _star_pos(i: int) -> Vector2:
	var pr := _overlay_rect()
	return Vector2(pr.get_center().x + (i - 1) * 120.0, pr.position.y + 200.0 - (22.0 if i == 1 else 0.0))

func add_moves(n: int) -> void:
	board.move_budget += n
	_moves_shown = board.moves_left()
	_overlay = ""
	_show_overlay_buttons()
	fx.popup("+%d moves!" % n, _moves_pos() + Vector2(0, 80), Style.GOLD, 44, 40.0, 1.2, "big")
	fx.burst(_moves_pos(), 24, 400.0, Fx.WARM)
	Audio.star(0)
	_refresh_buttons()

func next_level() -> void:
	start_level((level_index + 1) % levels.size())

func retry() -> void:
	start_level(level_index)

# ---------------------------------------------------------------- UI widgets

func _build_background() -> void:
	_bg = CanvasLayer.new()
	_bg.layer = -1
	add_child(_bg)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/background.gdshader")
	rect.material = mat
	_bg.add_child(rect)
	_bg.add_child(_Motes.new())

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 1
	add_child(_ui)
	_undo_btn = _pill("Undo", undo, 30)
	_hint_btn = _pill("Hint", hint, 30)
	_ui.add_child(_undo_btn)
	_ui.add_child(_hint_btn)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 2
	add_child(_overlay_layer)
	_overlay_draw = Node2D.new()
	_overlay_draw.draw.connect(_draw_overlay)
	_overlay_layer.add_child(_overlay_draw)

func _pill(text: String, action: Callable, size := 34, face := Style.CREAM, lip := Color("d9c29a"),
		ink := Style.INK) -> PillButton:
	var b := PillButton.new()
	b.text = text
	b.font_size = size
	b.face = face
	b.lip = lip
	b.ink = ink
	b.pressed.connect(action)
	return b

func _place_buttons() -> void:
	if _undo_btn == null:
		return
	var y := H - 148.0 - 46.0
	_undo_btn.position = Vector2(ox + 398.0, y)
	_undo_btn.size = Vector2(142, 92)
	_hint_btn.position = Vector2(ox + 558.0, y)
	_hint_btn.size = Vector2(142, 92)
	if not _overlay_buttons.is_empty():
		_show_overlay_buttons()

func _refresh_buttons() -> void:
	_undo_btn.badge = undos_left
	_hint_btn.badge = hints_left
	_undo_btn.disabled = undos_left <= 0 or _undo.is_empty()
	_hint_btn.disabled = hints_left <= 0

func _show_overlay_buttons() -> void:
	for b in _overlay_buttons:
		b.queue_free()
	_overlay_buttons.clear()
	_overlay_draw.queue_redraw()
	if _overlay == "":
		return
	var face := Color("8ad46f")
	var lip := Color("58a043")
	if _overlay == "win":
		var b := _pill("Next Level", next_level, 38, face, lip, Color.WHITE)
		b.bob_enabled = true
		_overlay_buttons.append(b)
	else:
		if board.moves_left() <= 0:
			# Later this is a rewarded video. In the prototype it's free.
			_overlay_buttons.append(_pill("+5 Moves", add_moves.bind(5), 36, face, lip, Color.WHITE))
		if undos_left > 0 and not _undo.is_empty():
			_overlay_buttons.append(_pill("Undo", undo, 34))
		_overlay_buttons.append(_pill("Try Again", retry, 34))
	var pr := _overlay_rect()
	for i in _overlay_buttons.size():
		var b := _overlay_buttons[i]
		b.size = Vector2(400, 96)
		b.position = Vector2(pr.get_center().x - 200.0, pr.end.y - 34.0 - (_overlay_buttons.size() - i) * 114.0 + 18.0)
		_overlay_layer.add_child(b)

func _overlay_rect() -> Rect2:
	var header := 420.0 if _overlay == "win" else 190.0
	var count := _overlay_buttons.size()
	if count == 0:
		count = 1 if _overlay == "win" else 2
	var ph := header + count * 114.0 + 30.0
	return Rect2(Vector2(ox + 60.0, H * 0.5 - ph * 0.5), Vector2(W - 120.0, ph))

# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	_clock += delta
	var redraw := false
	for i in _slot_pulse.size():
		if _slot_pulse[i] > 0.0:
			_slot_pulse[i] = maxf(_slot_pulse[i] - delta * 3.0, 0.0)
			redraw = true
	for i in _pip_pop.size():
		if _pip_pop[i] > 0.0:
			_pip_pop[i] = maxf(_pip_pop[i] - delta * 2.5, 0.0)
			redraw = true
	if _moves_pop > 0.0:
		_moves_pop = maxf(_moves_pop - delta * 4.0, 0.0)
		redraw = true
	if _coin_pop > 0.0:
		_coin_pop = maxf(_coin_pop - delta * 4.0, 0.0)
		redraw = true
	# Screen punch and shake, applied to the whole table.
	_punch = maxf(_punch - delta * 5.0, 0.0)
	_shake = maxf(_shake - delta * 2.8, 0.0)
	var zoom := 1.0 + 0.035 * _punch * _punch
	var c := Vector2(ox + W * 0.5, H * 0.45)
	var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0 * _shake * _shake
	scale = Vector2(zoom, zoom)
	position = c - c * zoom + jitter
	for id in _trailing:
		var v := views[id]
		if v.visible and v.scale.x < 0.95:
			fx.trail(v.position)
	if _demo_t >= 0.0 or not _hint.is_empty() or board.moves_left() <= LOW_MOVES or not _drag.is_empty() \
			or _overlay != "" or board.slot_cards.any(func(sc): return sc.size() > 0):
		redraw = true
	if _demo_t >= 0.0:
		_demo_t += delta
		if board.moves_used > 0:
			_demo_t = -1.0
	if _clock > _next_gleam:
		_next_gleam = _clock + randf_range(3.5, 5.5)
		if _overlay == "" and _drag.is_empty() and _clock - _last_input > 2.5 and _clock > _input_locked_until:
			_gleam_playable()
	if redraw:
		queue_redraw()
		_above_cards.queue_redraw()
	if _overlay != "":
		_overlay_age += delta
		for i in 3:
			_star_slam[i] = maxf(_star_slam[i] - delta * 3.5, 0.0)
		for s in _overlay_sparks:
			s.age += delta
			s.p += s.v * delta
			s.v *= pow(0.05, delta)
		_overlay_sparks = _overlay_sparks.filter(func(s): return s.age < s.life)
		_overlay_draw.queue_redraw()

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if board == null:
		return
	_draw_top_bar()
	_draw_slots()
	_draw_columns()
	_draw_bottom()
	if _tip != "" and board.moves_used < 2 and _clock > _input_locked_until - 0.3:
		var bob := sin(_clock * 3.0) * 4.0
		Style.text(self, Style.title(600), _tip, Vector2(ox + W * 0.5, TABLEAU_TOP - 46.0 + bob), 28,
			Style.CREAM, 6)
	if _demo_t >= 0.0 and _clock > _input_locked_until:
		_draw_demo()

func _draw_top_bar() -> void:
	var lp := Rect2(Vector2(ox + 20.0, 30.0), Vector2(150, 50))
	draw_style_box(Style.box(Color(0, 0, 0, 0.22), 25), lp)
	Style.text(self, Style.title(600), "Level %d" % (level_index + 1), lp.get_center(), 28, Style.CREAM, 0)
	var cp := _coin_hud_pos()
	draw_style_box(Style.box(Color(0, 0, 0, 0.22), 25), Rect2(cp + Vector2(-10, -25), Vector2(150, 50)))
	var cs := 1.0 + 0.3 * _coin_pop
	draw_set_transform(cp + Vector2(12, 0), 0.0, Vector2(cs, cs))
	Style.coin(self, Vector2.ZERO, 20.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Style.text(self, Style.title(600), str(_coin_shown), cp + Vector2(78, 0), int(30 * (1.0 + 0.15 * _coin_pop)),
		Style.CREAM, 0)
	# Moves plaque: the most important number on screen.
	var mp := _moves_pos()
	var left := _moves_shown
	var low := left <= LOW_MOVES and _overlay == "" and not _bonus_running
	var pulse := 1.0 + 0.22 * _moves_pop * _moves_pop
	if low:
		pulse += 0.05 * sin(_clock * 12.0)
	var plate := Rect2(Vector2(-78, -50), Vector2(156, 106))
	draw_set_transform(mp, 0.0, Vector2(pulse, pulse))
	draw_style_box(Style.box(Color(0, 0, 0, 0.3), 26), Rect2(plate.position + Vector2(0, 6), plate.size))
	draw_style_box(Style.box(Color("e9967a") if low else Color("d9c29a"), 26), plate)
	draw_style_box(Style.box(Color("ffe2d6") if low else Style.CREAM, 24),
		Rect2(plate.position + Vector2(4, 3), plate.size - Vector2(8, 11)))
	Style.text(self, Style.title(700), str(left), Vector2(0, -10), 58, Color("c0392b") if low else Style.INK, 0)
	Style.text(self, Style.title(500), "moves", Vector2(0, 32), 22, Color(Style.INK, 0.6), 0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in board.group_count():
		var p := _pip_pos(i)
		var s := 1.0 + 0.8 * _pip_pop[i] * _pip_pop[i]
		Style.fancy_star(self, p, 16.0 * s, 1.0 if i < _pips_lit else 0.0)
	# Streak meter: how many moves are left to keep the streak alive.
	if streak >= 1 and _overlay == "" and not _bonus_running and not board.is_won():
		var left_in_window := STREAK_WINDOW - (board.moves_used - _last_complete_at)
		if left_in_window > 0:
			var sp := Vector2(ox + W * 0.5, 188.0)
			var w := 176.0
			draw_style_box(Style.box(Color(0, 0, 0, 0.3), 12), Rect2(sp - Vector2(w * 0.5, 12), Vector2(w, 24)))
			var frac := float(left_in_window) / STREAK_WINDOW
			draw_style_box(Style.box(Color("ff9f43"), 10), Rect2(sp - Vector2(w * 0.5 - 3, 9), Vector2((w - 6) * frac, 18)))
			Style.text(self, Style.title(700), "Streak x%d" % (streak + 1), sp + Vector2(0, 1), 18, Color.WHITE, 4,
				Color("7a3b00"), false)

func _draw_slots() -> void:
	for j in board.slot_group.size():
		var c := _slot_pos(j)
		var g := board.slot_group[j]
		var pulse := _slot_pulse[j] if j < _slot_pulse.size() else 0.0
		var r := _card_rect(c).grow(4.0 + 8.0 * pulse)
		var hovered := _hover.x == Board.TO_SLOT and _hover.z == j
		if g == -1:
			draw_style_box(Style.box(Color(0, 0, 0, 0.16), 16), r)
			_dashed_round_rect(r.grow(-3), Color(1, 1, 1, 0.5 if hovered else 0.25))
			Style.text(self, Style.title(500), "+", c + Vector2(0, -16), 60, Color(1, 1, 1, 0.35), 0)
			Style.text(self, Style.title(500), "new group", c + Vector2(0, 36), 20, Color(1, 1, 1, 0.4), 0)
		else:
			var count: int = board.slot_cards[j].size()
			var size: int = board.group_size[g]
			var eager := count == size - 1
			var glow := 0.5 + 0.5 * sin(_clock * 6.0) if eager else 0.0
			for k in 3:
				var a := (0.35 - k * 0.1) * (1.0 + pulse + glow)
				draw_style_box(Style.box(Color(0, 0, 0, 0), 18 + k * 5, Color(Style.GOLD, a), 5), r.grow(2.0 + k * 6.0))
			draw_style_box(Style.box(Color(Style.GOLD, 0.14), 16, Style.GOLD, 4), r)
			_draw_group_tag(board.group_names[g], c + Vector2(0, -CARD.y * 0.5 - 30.0))
			for k in size:
				var dp := c + Vector2((k - (size - 1) * 0.5) * 22.0, CARD.y * 0.5 + 26.0)
				draw_circle(dp, 8.0, Color(0, 0, 0, 0.3))
				if k < count:
					var pop := 1.0 + (0.6 * pulse if k == count - 1 else 0.0)
					draw_circle(dp, 7.0 * pop, Style.GOLD)
					draw_circle(dp + Vector2(-2, -2), 2.4 * pop, Color(1, 1, 1, 0.7))
			if eager and _overlay == "":
				Style.text(self, Style.title(700), "1 more!", c + Vector2(0, CARD.y * 0.5 + 56.0), 22,
					Color(Style.GOLD, 0.6 + 0.4 * glow), 4)
		if hovered:
			draw_style_box(Style.box(Color(1, 1, 1, 0.08), 18, Color(1, 1, 1, 0.7), 4), r.grow(8))
		if not _hint.is_empty() and _hint.move.x == Board.TO_SLOT and _hint.move.z == j:
			var a := 0.55 + 0.45 * sin(_clock * 8.0)
			draw_style_box(Style.box(Color(0, 0, 0, 0), 20, Color(Style.GOLD, a), 6), r.grow(12))

func _draw_group_tag(gname: String, at: Vector2) -> void:
	var f := Style.title(600)
	var size := 24
	while size > 15 and Style.text_width(f, gname, size) > CARD.x + 40.0:
		size -= 1
	var w := Style.text_width(f, gname, size) + 30.0
	var r := Rect2(at - Vector2(w * 0.5, 18), Vector2(w, 36))
	draw_style_box(Style.box(Color(0, 0, 0, 0.25), 18), Rect2(r.position + Vector2(0, 4), r.size))
	draw_style_box(Style.box(Style.GOLD_DEEP, 18), r)
	draw_style_box(Style.box(Style.GOLD, 16), Rect2(r.position + Vector2(2, 2), r.size - Vector2(4, 7)))
	Style.text(self, f, gname, r.get_center() + Vector2(0, -2), size, Color("5a3a0a"), 0)

func _draw_columns() -> void:
	for k in board.columns.size():
		var hovered := _hover.x == Board.TO_COLUMN and _hover.z == k
		var base := _card_rect(Vector2(_column_x(k), TABLEAU_TOP + CARD.y * 0.5))
		if board.columns[k].is_empty():
			draw_style_box(Style.box(Color(0, 0, 0, 0.12), 14), base)
			_dashed_round_rect(base.grow(-3), Color(1, 1, 1, 0.18))
		if hovered:
			var col: Array = board.columns[k]
			var top := _column_card_pos(k, col.size() - 1) if not col.is_empty() else base.get_center()
			draw_style_box(Style.box(Color(1, 1, 1, 0.08), 18, Color(1, 1, 1, 0.6), 4), _card_rect(top).grow(8))

func _draw_bottom() -> void:
	var sp := _stock_pos()
	var r := _card_rect(sp)
	draw_style_box(Style.box(Color(0, 0, 0, 0.16), 14), r)
	if board.stock.is_empty():
		if not board.waste.is_empty():
			var ac := sp + Vector2(0, -10)
			draw_arc(ac, 26.0, 0.5, TAU - 0.2, 32, Color(1, 1, 1, 0.55), 6.0, true)
			var tip := ac + Vector2.from_angle(0.5) * 26.0
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-13, -2), tip + Vector2(9, -10), tip + Vector2(4, 12)]),
				Color(1, 1, 1, 0.55))
			Style.text(self, Style.title(500), "reuse", sp + Vector2(0, 40), 22, Color(1, 1, 1, 0.55), 0)
	draw_style_box(Style.box(Color(0, 0, 0, 0.12), 14), _card_rect(_waste_pos()))
	if not _hint.is_empty() and _hint.move.x == Board.DRAW:
		var a := 0.55 + 0.45 * sin(_clock * 8.0)
		draw_style_box(Style.box(Color(0, 0, 0, 0), 20, Color(Style.GOLD, a), 6), r.grow(12))

func _draw_above_cards() -> void:
	if board == null or board.stock.is_empty():
		return
	var o := _above_cards
	var bp := _stock_pos() + Vector2(CARD.x * 0.5 - 6, -CARD.y * 0.5 - 6 - 1.4 * board.stock.size())
	o.draw_circle(bp + Vector2(0, 2), 20.0, Color(0, 0, 0, 0.3))
	o.draw_circle(bp, 20.0, Style.CREAM)
	o.draw_arc(bp, 20.0, 0, TAU, 32, Color("d9c29a"), 3.0, true)
	Style.text(o, Style.title(700), str(board.stock.size()), bp, 22, Style.INK, 0)

func _dashed_round_rect(r: Rect2, col: Color) -> void:
	var inset := 14.0
	var edges := [[r.position + Vector2(inset, 0), Vector2(r.end.x - inset, r.position.y)],
		[Vector2(r.end.x, r.position.y + inset), r.end - Vector2(0, inset)],
		[r.end - Vector2(inset, 0), Vector2(r.position.x + inset, r.end.y)],
		[Vector2(r.position.x, r.end.y - inset), r.position + Vector2(0, inset)]]
	for e in edges:
		draw_dashed_line(e[0], e[1], col, 3.0, 10.0, true)
	var corners := [[r.position + Vector2(inset, inset), PI], [Vector2(r.end.x - inset, r.position.y + inset), -PI * 0.5],
		[r.end - Vector2(inset, inset), 0.0], [Vector2(r.position.x + inset, r.end.y - inset), PI * 0.5]]
	for cn in corners:
		draw_arc(cn[0], inset, cn[1], cn[1] + PI * 0.5, 8, col, 3.0, true)

## Level 1: a ghost finger shows the drag. Level 2: it taps the deck.
func _draw_demo() -> void:
	var t := fmod(_demo_t, 2.2)
	var from: Vector2
	var to: Vector2
	if level_index == 0:
		var unit := board.unit_at(0)
		if unit.is_empty():
			return
		from = views[unit[-1]].position
		to = _slot_pos(0)
	else:
		from = _stock_pos()
		to = _stock_pos()
	var k := clampf((t - 0.4) / 1.0, 0.0, 1.0)
	k = k * k * (3.0 - 2.0 * k)
	var p := from.lerp(to, k) + Vector2(24, 34)
	var press := 1.0 if t > 0.3 and t < 1.5 else 0.0
	if level_index == 1:
		press = 1.0 if fmod(t, 1.1) > 0.5 and fmod(t, 1.1) < 0.8 else 0.0
	var alpha := clampf(minf(t / 0.25, (2.2 - t) / 0.3), 0.0, 1.0)
	draw_circle(p, 30.0 + 6.0 * press, Color(1, 1, 1, 0.18 * alpha))
	draw_circle(p, 20.0 - 4.0 * press, Color(1, 1, 1, 0.75 * alpha))
	draw_arc(p, 22.0 - 4.0 * press, 0, TAU, 32, Color(0, 0, 0, 0.25 * alpha), 3.0, true)

func _draw_overlay() -> void:
	if _overlay == "":
		return
	var o := _overlay_draw
	var size := get_viewport_rect().size
	var a := clampf(_overlay_age / 0.25, 0.0, 1.0)
	o.draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.07, 0.08, 0.62 * a))
	var pr := _overlay_rect()
	# Drops in from above with a springy landing.
	var drop := 1.0 - Style.ease_back(clampf(_overlay_age / 0.45, 0.0, 1.0))
	var shift := Vector2(0, -H * 0.5 * drop)
	o.draw_set_transform(shift, 0.0, Vector2.ONE)
	var panel := Style.box(Style.CREAM, 34, Color("e7cf9f"), 6)
	panel.shadow_color = Color(0, 0, 0, 0.4)
	panel.shadow_size = 24
	panel.shadow_offset = Vector2(0, 12)
	o.draw_style_box(panel, pr)
	var head := Rect2(pr.position + Vector2(40, -34), Vector2(pr.size.x - 80, 78))
	var win := _overlay == "win"
	var hc := Color("8ad46f") if win else Color("ef8a6b")
	o.draw_style_box(Style.box(hc.darkened(0.25), 22), Rect2(head.position + Vector2(0, 6), head.size))
	o.draw_style_box(Style.box(hc, 22), head)
	o.draw_style_box(Style.box(Color(1, 1, 1, 0.25), 18), Rect2(head.position + Vector2(8, 6), Vector2(head.size.x - 16, 24)))
	var title := "Level Complete!" if win else ("No moves left" if board.moves_left() > 0 else "Out of moves!")
	Style.text(o, Style.title(700), title, head.get_center(), 44, Color.WHITE, 6, hc.darkened(0.45))
	if win:
		for i in 3:
			var p := _star_pos(i)
			var slam := _star_slam[i]
			var s := 1.0 + 1.2 * slam * slam
			o.draw_set_transform(shift + p, 0.0, Vector2(s, s))
			Style.fancy_star(o, Vector2.ZERO, 54.0, 1.0 if i < _stars_shown else 0.0)
		o.draw_set_transform(shift, 0.0, Vector2.ONE)
		if _win_coins_shown > 0:
			var cy := pr.position.y + 318.0
			Style.coin(o, Vector2(pr.get_center().x - 70.0, cy), 24.0)
			Style.text(o, Style.title(700), "+%d" % _win_coins_shown, Vector2(pr.get_center().x + 20.0, cy), 46,
				Color("b07818"), 0)
		for s2 in _overlay_sparks:
			var k: float = 1.0 - s2.age / s2.life
			Style.star(o, s2.p, s2.s * k, s2.s * 0.4 * k, Color(1, 0.9, 0.5, k), s2.age * 5.0)
	else:
		Style.text(o, Style.title(500), "%d of %d groups finished" % [board.completed.size(), board.group_count()],
			Vector2(pr.get_center().x, pr.position.y + 100.0), 30, Color(Style.INK, 0.75), 0)
		if board.moves_left() <= 0:
			Style.text(o, Style.body(700), "So close! Keep going?", Vector2(pr.get_center().x, pr.position.y + 145.0),
				24, Color(Style.INK, 0.55), 0)
	o.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for b in _overlay_buttons:
		b.modulate.a = clampf((_overlay_age - 0.25) / 0.2, 0.0, 1.0)

# ---------------------------------------------------------------- background motes

## Soft specks of light drifting up the table, so it never looks frozen.
class _Motes extends Node2D:
	var _m: Array[Dictionary] = []

	func _ready() -> void:
		for i in 22:
			_m.append(_spawn(true))

	func _spawn(anywhere: bool) -> Dictionary:
		var s := get_viewport_rect().size
		return {"p": Vector2(randf() * s.x, randf() * s.y if anywhere else s.y + 40.0),
			"v": randf_range(8.0, 22.0), "r": randf_range(10.0, 34.0), "a": randf_range(0.025, 0.06),
			"w": randf() * TAU}

	func _process(delta: float) -> void:
		for i in _m.size():
			var m := _m[i]
			m.p.y -= m.v * delta
			m.w += delta * 0.5
			if m.p.y < -60.0:
				_m[i] = _spawn(false)
		queue_redraw()

	func _draw() -> void:
		for m in _m:
			var p: Vector2 = m.p + Vector2(sin(m.w) * 18.0, 0)
			draw_circle(p, m.r, Color(1, 0.95, 0.8, m.a))
			draw_circle(p, m.r * 0.55, Color(1, 0.95, 0.8, m.a))
