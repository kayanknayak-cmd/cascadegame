class_name HomeView
extends Node2D
## The home screen: every level on one winding path, printed on paper.
##
##   levels     - small printed cards along the path, level 1 at the bottom.
##                Beaten levels are face-up with their stars stamped below;
##                the next level is lifted and bobbing; the rest are still
##                face-down, like cards waiting to be turned over.
##   bosses     - every tenth card is bigger, with a gold frame and a crown.
##   chapters   - every ten levels the paper changes tone, with a big faint
##                numeral in the margin.
##   gift boxes - beside the path every five levels. Each shows the coins
##                inside and the stars it needs; once you have them it
##                bobs, and a tap opens it.
##   shelf      - along the bottom, the album's featured set filling in and
##                the rare cards found. Tapping it opens the album.
##   bubbles    - round buttons floating at the sides: the daily gift, the
##                daily puzzle and the weekly event, each with a small tag.
##   back arrow - scroll away from your level and a round arrow appears that
##                glides you back (like Duolingo).
##   intro      - on launch the name appears, then everything drops in one
##                at a time (full ~3 s once a day, ~1 s otherwise; tap skips).
##
## Scroll by dragging (or the mouse wheel). The owner places the Play and
## icon buttons over the bottom panel and listens to the signals.

signal play(index: int)
signal gift(k: int)
signal album
signal settings
signal daily_gift
signal daily_puzzle
signal events
signal shop
signal streak
signal league
signal pets

const SPACING := 168.0        ## height between levels on the path
const AMP := 185.0            ## how far the path swings left and right
const CARD := Vector2(92, 122)
const PANEL := 236.0          ## height of the bottom panel (shelf + buttons)
const TOP_BAR := 92.0

var W := 720.0
var H := 1280.0
var ox := 0.0
var top := 0.0                ## safe-area inset at the top
var bottom := 0.0             ## safe-area inset at the bottom
var count := 100
var bosses: Dictionary = {}   ## level index -> true
var hard: Dictionary = {}     ## level index -> 1 "Hard", 2 "Super hard"
var _nudge_level := -1        ## a locked level that was tapped (shakes)
var _nudge_t := 0.0
var coins_shown := 0

var scroll := 0.0
var _vel := 0.0
var _down := false
var _drag_last := 0.0
var _moved := 0.0
var _press_pos := Vector2.ZERO
var _time := 0.0
var _flip_level := -1         ## a card turning face-up (just unlocked)
var _flip_t := 1.0
var _open_k := -1             ## a gift box popping open
var _open_t := 1.0
var _shake_k := -1            ## a box that isn't ready yet, wiggling
var _shake_t := 0.0
var _scroll_to := -1.0        ## smooth scroll target (-1 = none)
var _drag_time := 0
var _pin_from := -1.0         ## the "you are here" pin: level it's hopping from
var _pin_t := 1.0             ## 0..1 through the hop (1 = sitting on your level)
var _bubble_shake := 0.0      ## the gift bubble wiggling "not yet"
var _back_a := 0.0            ## the back-to-your-level arrow fading in/out
var _intro_t := 99.0
var _gear_t := 1.0            ## the gear's press-and-turn after a tap
var _flame_rect := Rect2()    ## where the streak flame was drawn (tap target)
var _star_rect := Rect2()     ## the star total: opens the Star League
var _press_key := ""          ## what's under the finger right now ("bubble:gift", "level:12", "box:3")
var _pop_key := ""            ## what was just let go of (a small springy pop)
var _pop_t := 0.0
const BUBBLE_R := 48.0        ## side bubbles (were 36: too small to see and hit)
const OVERSCROLL := 140.0     ## how far the map stretches past its ends
var _intro_len := 0.0
var _intro_full := false

func _process(delta: float) -> void:
	_time += delta
	if not _down:
		if _scroll_to >= 0.0:
			scroll = lerpf(scroll, _scroll_to, 1.0 - exp(-9.0 * delta))
			if absf(scroll - _scroll_to) < 0.5:
				scroll = _scroll_to
				_scroll_to = -1.0
		elif absf(_vel) > 1.0:
			scroll += _vel * delta
			_vel *= exp(-3.2 * delta)
			# Flung past an end: it runs on a little, then springs back.
			if scroll < 0.0 or scroll > _max_scroll():
				_vel *= exp(-18.0 * delta)
		# Rubber band: past either end, ease back to the edge.
		var edge := clampf(scroll, 0.0, _max_scroll())
		if scroll != edge and absf(_vel) < 60.0:
			_vel = 0.0
			scroll = lerpf(scroll, edge, 1.0 - exp(-12.0 * delta))
			if absf(scroll - edge) < 0.5:
				scroll = edge
		scroll = clampf(scroll, -OVERSCROLL, _max_scroll() + OVERSCROLL)
	if _flip_t < 1.0:
		_flip_t = minf(_flip_t + delta * 1.6, 1.0)
		if _flip_t >= 0.5 and _flip_t - delta * 1.6 < 0.5:
			Audio.flip()
	if _open_t < 1.0:
		_open_t = minf(_open_t + delta * 1.4, 1.0)
	_shake_t = maxf(_shake_t - delta * 2.5, 0.0)
	_bubble_shake = maxf(_bubble_shake - delta * 2.5, 0.0)
	_nudge_t = maxf(_nudge_t - delta * 2.0, 0.0)
	_gear_t = minf(_gear_t + delta / 0.45, 1.0)
	_pop_t = maxf(_pop_t - delta * 3.0, 0.0)
	if _pin_t < 1.0:
		var before := _pin_t
		_pin_t = minf(_pin_t + delta * 1.8, 1.0)
		if before < 1.0 and _pin_t >= 1.0:
			Audio.land()
	var dir := _back_dir()
	_back_a = move_toward(_back_a, 1.0 if dir != 0 else 0.0, delta * 5.0)
	if _intro_t < _intro_len:
		var before := _intro_t
		_intro_t += delta
		_intro_sounds(before, _intro_t)
	queue_redraw()

# ---------------------------------------------------------------- layout

func map_top() -> float:
	return TOP_BAR + top

func panel_top() -> float:
	return H - PANEL - bottom

## Where level 1 sits on screen when scrolled all the way down.
func _base_y() -> float:
	return panel_top() - 120.0

func _path_x(t: float) -> float:
	return ox + W * 0.5 + AMP * (0.82 * sin(t * 0.62) + 0.18 * sin(t * 1.9 + 1.0))

## Screen position of point t on the path (t = level index, fractions between).
func path_pos(t: float) -> Vector2:
	var rise := 300.0 * (1.0 - _ease(appear("map")))
	return Vector2(_path_x(t), _base_y() - t * SPACING + scroll + rise)

func _max_scroll() -> float:
	return maxf(0.0, count * SPACING - (_base_y() - map_top() - 150.0))

## Scroll so level i sits a little below the middle of the map.
func focus(i: int, smooth := false) -> void:
	var target := map_top() + (panel_top() - map_top()) * 0.58
	var s := clampf(target - _base_y() + i * SPACING, 0.0, _max_scroll())
	_vel = 0.0
	if smooth:
		_scroll_to = s
	else:
		scroll = s
		_scroll_to = -1.0

func _gift_pos(k: int) -> Vector2:
	var t := k * Progress.GIFT_EVERY - 0.5
	var p := path_pos(t)
	var side := -1.0 if _path_x(t) > ox + W * 0.5 else 1.0
	p.x = clampf(p.x + side * 190.0, ox + 80.0, ox + W - 80.0)
	return p

func _gear_rect() -> Rect2:
	return Rect2(Vector2(ox + W - 64.0, top + 22.0), Vector2(48, 48))

func shelf_rect() -> Rect2:
	return Rect2(Vector2(ox + 24.0, panel_top() + 16.0), Vector2(W - 48.0, 92.0))

## Where the buttons go: the Play row under the shelf.
func button_row_y() -> float:
	return panel_top() + 128.0

# ---------------------------------------------------------------- moments

## A level was just unlocked: glide to it and turn its card face-up.
func celebrate(i: int) -> void:
	focus(maxi(i - 1, 0))
	focus(i, true)
	_flip_level = i
	_flip_t = -0.6       # a short pause first
	# Your pin hops from the level you just beat to the new one.
	_pin_from = float(maxi(i - 1, 0))
	_pin_t = -0.9

func open_box(k: int) -> void:
	_open_k = k
	_open_t = 0.0

# ---------------------------------------------------------------- intro

## When each part of the home screen arrives: [start, length] in seconds.
const INTRO_FULL := {"word": [0.0, 0.7], "move": [0.7, 0.45], "map": [0.85, 0.6], "top": [0.72, 0.38],
	"bubble0": [1.4, 0.35], "bubble1": [1.55, 0.35], "bubble2": [1.7, 0.35], "bubble3": [1.85, 0.35], "bubble4": [2.0, 0.35], "shelf": [1.9, 0.4], "play": [2.25, 0.45]}
const INTRO_QUICK := {"word": [0.0, 0.0], "move": [0.0, 0.0], "map": [0.0, 0.35], "top": [0.05, 0.3],
	"bubble0": [0.3, 0.3], "bubble1": [0.38, 0.3], "bubble2": [0.46, 0.3], "bubble3": [0.54, 0.3], "bubble4": [0.62, 0.3], "shelf": [0.5, 0.3], "play": [0.65, 0.35]}

func start_intro(full: bool) -> void:
	_intro_full = full
	_intro_len = 2.75 if full else 1.0
	_intro_t = 0.0

func skip_intro() -> void:
	_intro_t = _intro_len

func intro_done() -> bool:
	return _intro_t >= _intro_len

## 0..1: how far along `key` is in the intro (1 once the intro is over).
func appear(key: String) -> float:
	if _intro_t >= _intro_len:
		return 1.0
	var span: Array = (INTRO_FULL if _intro_full else INTRO_QUICK)[key]
	if float(span[1]) <= 0.0:
		return 1.0 if _intro_t >= float(span[0]) else 0.0
	return clampf((_intro_t - float(span[0])) / float(span[1]), 0.0, 1.0)

static func _ease(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)

func _intro_sounds(a: float, b: float) -> void:
	var table: Dictionary = INTRO_FULL if _intro_full else INTRO_QUICK
	for k in 4:
		var at := float(table["bubble%d" % k][0])
		if a < at and b >= at:
			Audio.star_pip(k * 2)
	var play_at := float(table["play"][0])
	if a < play_at and b >= play_at:
		Audio.land()
	if _intro_full and a < 0.05 and b >= 0.05:
		Audio.deal_start()

## The name, big in the middle, underlined by a strip of every group colour;
## then it shrinks up into the top bar.
func _draw_wordmark(screen: Vector2) -> void:
	if not _intro_full or appear("move") >= 1.0:
		return
	var w := _ease(appear("word"))
	var m := _ease(appear("move"))
	var cover := 1.0 - appear("map")
	draw_rect(Rect2(Vector2.ZERO, screen), Color(Style.PAPER, cover))
	var home := Vector2(ox + W * 0.5, top + 46.0)
	var mid := Vector2(ox + W * 0.5, H * 0.42)
	var c := mid.lerp(home, m)
	var size := int(lerpf(110.0, 38.0, m))
	Style.text(self, Style.serif(800, 144), "Cascade", c, size, Color(Style.INK, minf(w * 2.0, 1.0)))
	var n := Style.GROUPS.size()
	var bw := 420.0 * (1.0 - m) * w
	for i in n:
		var x := c.x - bw * 0.5 + bw * i / n
		draw_rect(Rect2(Vector2(x, c.y + size * 0.62), Vector2(bw / n + 0.5, 10.0 * (1.0 - m))), Style.GROUPS[i])

# ---------------------------------------------------------------- bubbles

## The round buttons at the sides: [id, centre].
func _bubbles() -> Array:
	var y := map_top() + 86.0
	return [["gift", Vector2(ox + 68.0, y)], ["daily", Vector2(ox + 68.0, y + 142.0)],
		["events", Vector2(ox + W - 68.0, y)], ["shop", Vector2(ox + W - 68.0, y + 142.0)],
		["pets", Vector2(ox + W - 68.0, y + 284.0)]]

func _bubble_alert(id: String) -> bool:
	match id:
		"gift":
			return not Progress.gift_today().is_empty()
		"daily":
			return not Progress.daily.has(Progress.local_date())
		"events":
			return Progress.week_ready() > 0
	return false

## The small tag under each bubble: what's waiting, or how long until more
## (times get a little clock). No tag when there's nothing to say.
func _bubble_tag(id: String) -> String:
	match id:
		"gift":
			if not Progress.gift_today().is_empty():
				return "Open"
			return "%dh" % _hours_to_midnight()
		"daily":
			if Progress.daily.has(Progress.local_date()):
				var n := Progress.daily_streak()
				return "×%d" % n if n > 1 else "Done"
			return "New"
		"events":
			if Progress.week_ready() > 0:
				return "Collect"
			var d := _days_to_monday()
			return "%d day%s" % [d, "" if d == 1 else "s"]
		"shop":
			return ""
	return ""

## Tags that are a time left get a clock drawn in front.
func _tag_is_time(id: String) -> bool:
	return (id == "gift" and Progress.gift_today().is_empty()) or (id == "events" and Progress.week_ready() <= 0)

static func _hours_to_midnight() -> int:
	var t := Time.get_datetime_dict_from_system()
	return maxi(1, 24 - int(t.hour))

static func _days_to_monday() -> int:
	var wd := int(Time.get_datetime_dict_from_system().weekday)   # 0 = Sunday
	return 1 if wd == 0 else 8 - wd

func _draw_bubbles() -> void:
	var list := _bubbles()
	for n in list.size():
		var id: String = list[n][0]
		var c: Vector2 = list[n][1]
		var a := Style.ease_back(appear("bubble%d" % n)) * _press_scale("bubble:" + id)
		if a <= 0.01:
			continue
		var alert := _bubble_alert(id)
		if alert:
			c.y += sin(_time * 3.5 + n) * 3.0
		var rot := sin(_time * 3.0 + n) * 0.06 if alert else 0.0
		if id == "gift" and _bubble_shake > 0.0:
			rot = sin(_bubble_shake * 30.0) * 0.2 * _bubble_shake
		var k := BUBBLE_R / 36.0          # icons were drawn for the old 36 px bubble
		draw_set_transform(c, rot, Vector2(a, a))
		draw_circle(Vector2(5, 5), BUBBLE_R, Style.INK)
		draw_circle(Vector2.ZERO, BUBBLE_R, Style.COIN if alert and id == "gift" else Style.CARD)
		draw_arc(Vector2.ZERO, BUBBLE_R, 0, TAU, 48, Style.INK, 3.0, true)
		draw_set_transform(c, rot, Vector2(a, a) * k)
		match id:
			"gift":
				_icon_gift(Vector2(0, 2))
			"daily":
				_icon_calendar(Vector2(0, 2))
			"events":
				_icon_flag(Vector2(2, 0))
				_ring_progress()
			"shop":
				_icon_bag(Vector2(0, 2))
			"pets":
				_icon_paw(Vector2(0, 2))
		draw_set_transform(c, rot, Vector2(a, a))
		# Tag (none for the shop: the bag says it).
		var tag := _bubble_tag(id)
		if tag != "":
			var clock := _tag_is_time(id)
			var tw := Style.caps_width(tag, 13, 0.1) + 20.0 + (20.0 if clock else 0.0)
			var tr := Rect2(Vector2(-tw * 0.5, BUBBLE_R - 8.0), Vector2(tw, 26))
			draw_rect(Rect2(tr.position + Vector2(3, 3), tr.size), Style.INK)
			draw_rect(tr, Style.ACCENT if alert else Style.PAPER)
			draw_rect(tr, Style.INK, false, 2.0)
			var ink := Style.CARD if alert else Style.INK
			var tc := tr.get_center() + Vector2(10.0 if clock else 0.0, -1)
			if clock:
				var cc := Vector2(tr.position.x + 17.0, tr.get_center().y)
				draw_arc(cc, 7.0, 0, TAU, 20, ink, 2.0, true)
				draw_line(cc, cc + Vector2(0, -4.5), ink, 2.0)
				draw_line(cc, cc + Vector2(3.5, 0), ink, 2.0)
			Style.caps(self, tag, tc, 13, ink, 0.1)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _icon_gift(c: Vector2) -> void:
	var body := Rect2(c + Vector2(-15, -6), Vector2(30, 20))
	draw_rect(body, Style.CARD)
	draw_rect(Rect2(c + Vector2(-3, -6), Vector2(6, 20)), Style.ACCENT)
	draw_rect(body, Style.INK, false, 2.0)
	var lid := Rect2(c + Vector2(-18, -13), Vector2(36, 8))
	draw_rect(lid, Style.CARD)
	draw_rect(Rect2(c + Vector2(-3, -13), Vector2(6, 8)), Style.ACCENT)
	draw_rect(lid, Style.INK, false, 2.0)
	for sd in [-1.0, 1.0]:
		var loop := PackedVector2Array([c + Vector2(0, -13), c + Vector2(sd * 10, -22), c + Vector2(sd * 11, -14), c + Vector2(0, -13)])
		draw_colored_polygon(loop, Style.ACCENT)
		draw_polyline(loop, Style.INK, 1.5, true)

func _icon_calendar(c: Vector2) -> void:
	var r := Rect2(c + Vector2(-17, -15), Vector2(34, 32))
	draw_rect(r, Style.CARD)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 9)), Style.ACCENT)
	draw_rect(r, Style.INK, false, 2.0)
	for x in [-8.0, 8.0]:
		draw_line(c + Vector2(x, -19), c + Vector2(x, -11), Style.INK, 2.5)
	var day := int(Time.get_datetime_dict_from_system().day)
	Style.text(self, Style.serif(800, 48), str(day), c + Vector2(0, 5), 16, Style.INK)

func _icon_bag(c: Vector2) -> void:
	var body := PackedVector2Array([c + Vector2(-15, -8), c + Vector2(15, -8), c + Vector2(18, 18), c + Vector2(-18, 18)])
	draw_colored_polygon(body, Style.COIN)
	draw_polyline(body + PackedVector2Array([body[0]]), Style.INK, 2.0, true)
	draw_arc(c + Vector2(0, -8), 8.0, PI, TAU, 16, Style.INK, 2.5, true)
	Style.coin(self, c + Vector2(0, 6), 6.0)

## A paw print: one pad and four toes.
func _icon_paw(c: Vector2) -> void:
	draw_circle(c + Vector2(0, 6), 9.0, Style.ACCENT)
	draw_arc(c + Vector2(0, 6), 9.0, 0, TAU, 20, Style.INK, 2.0, true)
	for t in [Vector2(-13, -5), Vector2(-5, -13), Vector2(5, -13), Vector2(13, -5)]:
		draw_circle(c + t, 4.5, Style.ACCENT)
		draw_arc(c + t, 4.5, 0, TAU, 12, Style.INK, 1.5, true)

func _icon_flag(c: Vector2) -> void:
	draw_line(c + Vector2(-10, -17), c + Vector2(-10, 18), Style.INK, 3.0)
	var fl := PackedVector2Array([c + Vector2(-9, -17), c + Vector2(14, -10), c + Vector2(-9, -2)])
	draw_colored_polygon(fl, Style.ACCENT)
	draw_polyline(fl + PackedVector2Array([fl[0]]), Style.INK, 1.5, true)
	draw_line(c + Vector2(-16, 18), c + Vector2(-4, 18), Style.INK, 3.0)

## Around the events bubble: how far along this week's prize track you are.
func _ring_progress() -> void:
	var track: Array = Progress.week_track()
	var goal := float(track[-1][0])
	var f := clampf(Progress.week_cards / goal, 0.0, 1.0)
	if f > 0.0:
		draw_arc(Vector2.ZERO, 36.0 - 1.0, -PI * 0.5, -PI * 0.5 + TAU * f, 40, Style.ACCENT, 5.0, true)

# ---------------------------------------------------------------- back arrow

## -1 when your level is above the view, 1 when below, 0 when you can see it.
func _back_dir() -> int:
	if not intro_done():
		return 0
	var y := path_pos(mini(Progress.cascade_level, count - 1)).y
	if y < map_top() + 10.0:
		return -1
	if y > panel_top() - 10.0:
		return 1
	return 0

func _back_pos() -> Vector2:
	return Vector2(ox + W - 62.0, panel_top() - 62.0)

func _draw_back_arrow() -> void:
	if _back_a <= 0.01:
		return
	var dir := _back_dir()
	var above := path_pos(mini(Progress.cascade_level, count - 1)).y < map_top()
	var c := _back_pos() + Vector2(0, sin(_time * 4.0) * 2.0)
	draw_set_transform(c, 0.0, Vector2.ONE * Style.ease_back(_back_a))
	draw_circle(Vector2(4, 4), 30.0, Style.INK)
	draw_circle(Vector2.ZERO, 30.0, Style.ACCENT)
	draw_arc(Vector2.ZERO, 30.0, 0, TAU, 36, Style.INK, 2.5, true)
	var s := -1.0 if (above if dir == 0 else dir < 0) else 1.0
	var pts := PackedVector2Array([Vector2(-11, -4 * s), Vector2(0, 8 * s), Vector2(11, -4 * s)])
	draw_polyline(pts, Style.CARD, 5.0, true)
	draw_line(Vector2(0, 8 * s), Vector2(0, -12 * s), Style.CARD, 5.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- input

## Scrolling: the map follows your finger exactly, then glides on after a
## flick and eases to a stop. The wheel and trackpad glide to a target too.
func handle(event: InputEvent) -> void:
	if _intro_t < _intro_len:
		if event is InputEventMouseButton and event.pressed:
			skip_intro()
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var step := 110.0 * (1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
			var from := _scroll_to if _scroll_to >= 0.0 else scroll
			_scroll_to = clampf(from + step, 0.0, _max_scroll())
			_vel = 0.0
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_down = true
				_vel = 0.0
				_scroll_to = -1.0
				_moved = 0.0
				_drag_last = event.position.y
				_drag_time = Time.get_ticks_usec()
				_press_pos = event.position
				_press_key = _key_at(event.position)
			elif _down:
				_down = false
				if _press_key != "":
					_pop_key = _press_key
					_pop_t = 1.0
				_press_key = ""
				# Held still before letting go: no fling.
				if (Time.get_ticks_usec() - _drag_time) > 90000:
					_vel = 0.0
				_vel = clampf(_vel, -4500.0, 4500.0)
				if _moved < 14.0:
					_vel = 0.0
					_tap(_press_pos)
	elif event is InputEventMouseMotion and _down:
		var dy: float = event.position.y - _drag_last
		var now := Time.get_ticks_usec()
		var dt := maxf((now - _drag_time) / 1000000.0, 0.004)
		_drag_last = event.position.y
		_drag_time = now
		_moved += absf(dy)
		if _moved >= 14.0:
			_press_key = ""
		# Past an end the map follows less and less (it stretches).
		var past := maxf(-scroll, scroll - _max_scroll())
		var resist := 1.0
		if (scroll <= 0.0 and dy < 0.0) or (scroll >= _max_scroll() and dy > 0.0):
			resist = 0.45 * (1.0 - clampf(past / OVERSCROLL, 0.0, 1.0))
		scroll = clampf(scroll + dy * resist, -OVERSCROLL, _max_scroll() + OVERSCROLL)
		_vel = lerpf(_vel, dy / dt, 0.35)
	elif event is InputEventPanGesture:
		_scroll_to = -1.0
		_vel = 0.0
		scroll = clampf(scroll - event.delta.y * 14.0, 0.0, _max_scroll())

## What a finger at p is on, for the press-in look: "bubble:<id>", "box:<k>",
## "level:<i>", or "".
func _key_at(p: Vector2) -> String:
	if _flame_rect.has_point(p):
		return "flame"
	for b in _bubbles():
		if (b[1] as Vector2).distance_to(p) < BUBBLE_R + 10.0:
			return "bubble:" + String(b[0])
	if p.y < map_top() or p.y > panel_top():
		return ""
	for k in range(1, count / Progress.GIFT_EVERY + 1):
		if _gift_pos(k).distance_to(p) < 60.0:
			return "box:%d" % k
	for i in count:
		var c := path_pos(i)
		if absf(c.y - p.y) < CARD.y * 0.7 and absf(c.x - p.x) < CARD.x * 0.7:
			return "level:%d" % i
	return ""

## Size multiplier for a pressable thing: sinks while pressed, then a
## springy pop after letting go.
func _press_scale(key: String) -> float:
	if key == _press_key and _down:
		return 0.9
	if key == _pop_key and _pop_t > 0.0:
		return 1.0 + 0.1 * sin((1.0 - _pop_t) * PI * 2.0) * _pop_t
	return 1.0

func _tap(p: Vector2) -> void:
	for b in _bubbles():
		if (b[1] as Vector2).distance_to(p) < BUBBLE_R + 10.0:
			Audio.button()
			match String(b[0]):
				"gift":
					if Progress.gift_today().is_empty():
						_bubble_shake = 1.0
						Audio.wrong()
					else:
						daily_gift.emit()
				"daily":
					daily_puzzle.emit()
				"events":
					events.emit()
				"shop":
					shop.emit()
				"pets":
					pets.emit()
			return
	if _back_a > 0.5 and _back_pos().distance_to(p) < 38.0:
		Audio.button()
		focus(mini(Progress.cascade_level, count - 1), true)
		return
	if _flame_rect.has_point(p):
		Audio.button()
		streak.emit()
		return
	if _star_rect.has_point(p):
		Audio.button()
		league.emit()
		return
	if _gear_rect().grow(22).has_point(p):
		_gear_t = 0.0
		settings.emit()
		return
	if Rect2(Vector2(ox + W - 224.0, top + 14.0), Vector2(150, 64)).has_point(p):
		shop.emit()      # tapping your coins opens the shop
		return
	if shelf_rect().has_point(p):
		album.emit()
		return
	if p.y < map_top() or p.y > panel_top():
		return
	for k in range(1, count / Progress.GIFT_EVERY + 1):
		if _gift_pos(k).distance_to(p) < 60.0:
			if Progress.gift_box_ready(k):
				gift.emit(k)
			elif not Progress.gift_box_opened(k):
				_shake_k = k
				_shake_t = 1.0
				Audio.wrong()
			return
	for i in count:
		var c := path_pos(i)
		if absf(c.y - p.y) < CARD.y * 0.7 and absf(c.x - p.x) < CARD.x * 0.7:
			if i <= Progress.cascade_level:
				play.emit(i)
			else:
				# Not yet: the card shakes and the map glides to your level.
				_nudge_level = i
				_nudge_t = 1.0
				Audio.wrong()
				focus(mini(Progress.cascade_level, count - 1), true)
			return

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var screen := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, screen), Style.PAPER)
	var lo := int(floor((_base_y() + scroll - panel_top()) / SPACING)) - 1
	var hi := int(ceil((_base_y() + scroll - map_top() + 80.0) / SPACING)) + 1
	lo = clampi(lo, 0, count - 1)
	hi = clampi(hi, 0, count - 1)
	_draw_chapters(screen, lo, hi)
	_draw_path(lo, hi)
	for k in range(1, count / Progress.GIFT_EVERY + 1):
		var gp := _gift_pos(k)
		if gp.y > map_top() - 80.0 and gp.y < panel_top() + 80.0:
			_draw_gift(gp, k)
	var current := mini(Progress.cascade_level, count - 1)
	for i in range(hi, lo - 1, -1):
		if i != current:
			_draw_level(i, current)
	if current >= lo and current <= hi:
		_draw_level(current, current)
	_draw_more_soon()
	_draw_pin(current)
	_draw_back_arrow()
	_draw_bubbles()
	var top_in := _ease(appear("top"))
	draw_set_transform(Vector2(0, -140.0 * (1.0 - top_in)), 0.0, Vector2.ONE)
	_draw_top_bar(screen)
	var shelf_in := _ease(appear("shelf"))
	draw_set_transform(Vector2(0, (PANEL + bottom + 20.0) * (1.0 - shelf_in)), 0.0, Vector2.ONE)
	_draw_panel(screen)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_wordmark(screen)

## Each chapter of ten levels gets its own tone of paper, a hairline rule
## with a diamond where it starts, and a big faint numeral in the margin.
func _draw_chapters(screen: Vector2, lo: int, hi: int) -> void:
	for ch in range(lo / 10, hi / 10 + 1):
		var y0 := path_pos(ch * 10 - 0.5).y
		var y1 := path_pos(ch * 10 + 9.5).y
		if ch % 2 == 1:
			draw_rect(Rect2(Vector2(0, y1), Vector2(screen.x, y0 - y1)), Color(Style.PAPER_DEEP, 0.55))
		# Faint wallpaper: the shapes of the card groups, scattered.
		var rng := RandomNumberGenerator.new()
		rng.seed = ch * 7717 + 3
		for n in 22:
			var sp := Vector2(ox + rng.randf_range(30.0, W - 30.0), lerpf(y0, y1, rng.randf()))
			var g := rng.randi() % 12
			var size := rng.randf_range(12.0, 30.0)
			# Parallax: the shapes scroll a little slower than the path, and
			# drift gently, so the map feels deep and alive.
			sp.y -= scroll * 0.18 * (size / 30.0)
			sp += Vector2(sin(_time * 0.4 + n * 1.3), cos(_time * 0.3 + n)) * 4.0
			if absf(sp.x - _path_x((y0 - sp.y) / SPACING + ch * 10 - 0.5)) < 120.0:
				continue
			Style.group_symbol(self, g, sp, size, Color(Style.group_color(g), 0.16))
		# Chapter numeral, set in the margin away from the path.
		var t := ch * 10 + 1.5
		var side := -1.0 if _path_x(t) > ox + W * 0.5 else 1.0
		var np := Vector2(ox + W * 0.5 + side * (W * 0.5 - 92.0), path_pos(t).y)
		Style.text(self, Style.serif(800, 144), _roman(ch + 1), np, 110, Color(Style.INK, 0.07))
		if ch > 0:
			var ry := y0
			draw_line(Vector2(ox + 40.0, ry), Vector2(ox + W - 40.0, ry), Color(Style.INK, 0.25), 1.5)
			var c := Vector2(ox + 70.0, ry)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0)]),
				Style.group_color(ch * 3))
			draw_polyline(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0),
				c + Vector2(0, -7)]), Style.INK, 1.5, true)

static func _roman(n: int) -> String:
	var vals := [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
	var s := ""
	for v in vals:
		while n >= int(v[0]):
			s += String(v[1])
			n -= int(v[0])
	return s

## The trail: a soft band of deeper paper, stitched down the middle. The
## part you've walked is stitched in red; the rest in faint ink dots.
func _draw_path(lo: int, hi: int) -> void:
	var done_t := float(mini(Progress.cascade_level, count - 1))
	var t0 := maxf(lo - 1.0, 0.0)
	var t1 := minf(hi + 1.0, float(count))
	var band := PackedVector2Array()
	var t := t0
	while t <= t1 + 0.001:
		band.append(path_pos(t))
		t += 0.08
	if band.size() < 2:
		return
	draw_polyline(band, Style.INK, 42.0, true)
	draw_polyline(band, Style.PAPER_DEEP, 36.0, true)
	draw_polyline(band, Style.CARD, 20.0, true)
	# Stitches, measured along the curve so they stay evenly spaced.
	var dist := 0.0
	for i in band.size() - 1:
		var a := band[i]
		var b := band[i + 1]
		var seg := a.distance_to(b)
		var ta := t0 + i * 0.08
		var walked := ta < done_t
		var period := 28.0
		var on := 16.0 if walked else 4.0
		var d := 0.0
		while d < seg:
			var phase := fmod(dist + d, period)
			if phase < on:
				var ln := minf(on - phase, seg - d)
				var p0 := a.lerp(b, d / seg)
				var p1 := a.lerp(b, minf((d + ln) / seg, 1.0))
				if walked:
					draw_line(p0, p1, Style.ACCENT, 6.0, true)
				else:
					draw_circle(p0, 3.0, Color(Style.INK, 0.3))
				d += ln
			else:
				d += period - phase
		dist += seg

## "You are here": a red map pin above your level. After a win it hops
## along the path to the new level.
func _draw_pin(current: int) -> void:
	var t := float(current)
	var lift := 0.0
	if _pin_t < 1.0 and _pin_from >= 0.0:
		var k := clampf(_pin_t, 0.0, 1.0)
		t = lerpf(_pin_from, float(current), k * k * (3.0 - 2.0 * k))
		lift = sin(k * PI) * 70.0
	# Leaning off the card's top corner, on the side away from the next card,
	# so it never covers it.
	var side := -1.0 if _path_x(t + 1.0) > _path_x(t) else 1.0
	var c := path_pos(t) + Vector2(side * 44.0, -CARD.y * 0.5 * 1.28 - 30.0 - lift + sin(_time * 3.2) * 3.0)
	if c.y < map_top() - 60.0 or c.y > panel_top() + 60.0:
		return
	var pts := PackedVector2Array()
	for i in 21:
		var a := PI * 0.85 + i * (PI * 1.3) / 20.0
		pts.append(c + Vector2.from_angle(a) * 17.0)
	pts.append(c + Vector2(0, 30))
	draw_colored_polygon(PackedVector2Array(Array(pts).map(func(v): return v + Vector2(3, 3))), Style.INK)
	draw_colored_polygon(pts, Style.ACCENT)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Style.INK, 2.0, true)
	draw_circle(c, 7.0, Style.CARD)
	draw_arc(c, 7.0, 0, TAU, 16, Style.INK, 1.5, true)

## After the last level: an empty dashed card where more levels will go.
func _draw_more_soon() -> void:
	var c := path_pos(count)
	if c.y < map_top() - 140.0 or c.y > panel_top() + 140.0:
		return
	var r := Rect2(c - CARD * 0.55, CARD * 1.1)
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	draw_rect(r, Color(Style.CARD, 0.7))
	for e in 4:
		draw_dashed_line(pts[e], pts[e + 1], Style.INK, 2.0, 7.0, true)
	Style.star(self, c + Vector2(0, -14), 16.0 + sin(_time * 3.0) * 2.0, 7.0, Style.COIN, _time * 0.5)
	Style.caps(self, "More", c + Vector2(0, 22), 13, Style.INK, 0.16)
	Style.caps(self, "soon", c + Vector2(0, 42), 13, Style.INK, 0.16)

func _draw_level(i: int, current: int) -> void:
	var c := path_pos(i)
	if c.y < map_top() - 140.0 or c.y > panel_top() + 140.0:
		return
	var boss: bool = bosses.has(i)
	var is_current := i == current and i <= Progress.cascade_level
	var unlocked := i <= Progress.cascade_level
	var rot := (0.07 if i % 2 == 0 else -0.06) * (0.3 if is_current else 1.0)
	if i == _nudge_level and _nudge_t > 0.0:
		rot += sin(_nudge_t * 28.0) * 0.18 * _nudge_t
	var sc := _press_scale("level:%d" % i)
	if boss:
		sc *= 1.2
	if is_current:
		sc *= 1.28 + 0.03 * sin(_time * 3.2)
		c.y -= 10.0 + 4.0 * sin(_time * 3.2)
	var face_up := unlocked
	var sx := 1.0
	if i == _flip_level and _flip_t < 1.0:
		var ft := clampf(_flip_t, 0.0, 1.0)
		face_up = ft >= 0.5
		sx = maxf(absf(cos(ft * PI)), 0.04)
		c.y -= 30.0 * sin(ft * PI)
	var r := Rect2(-CARD * 0.5, CARD)
	var lift := 12.0 if is_current else 5.0
	draw_set_transform(c, rot, Vector2(sc * sx, sc))
	# Hint of the next card: a pulsing red frame, like the in-game hint.
	if is_current:
		var a := 0.45 + 0.4 * sin(_time * 5.0)
		draw_rect(r.grow(9.0), Color(Style.ACCENT, a), false, 4.0)
	draw_style_box(Style.box(Color(Style.INK, 0.9), 4), Rect2(r.position + Vector2(lift, lift) * 0.6, r.size))
	var col := Style.group_color(i / 10 * 3 + 1)
	if face_up:
		draw_style_box(Style.box(Style.CARD, 4, Style.INK, 2), r)
		var br := Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 13))
		var bs := Style.box(col, 3)
		bs.corner_radius_bottom_left = 0
		bs.corner_radius_bottom_right = 0
		draw_style_box(bs, br)
		draw_line(Vector2(r.position.x + 2, br.end.y), Vector2(r.end.x - 2, br.end.y), Style.INK, 2.0)
		Style.group_symbol(self, i / 10 * 3 + 1, Vector2(0, 14), 24.0, Color(col, 0.13))
		Style.text(self, Style.num(800), str(i + 1), Vector2(0, 10), 44 if i < 99 else 36, Style.INK)
		if boss:
			draw_style_box(Style.box(Color(0, 0, 0, 0), 3, Style.COIN, 4), r.grow(-5))
		if is_current:
			_draw_sheen(r)
	else:
		Style.card_back(self, r, Progress.card_back)
		draw_rect(r, Style.INK, false, 2.0)
		if boss:
			draw_rect(r.grow(-5), Style.COIN, false, 3.0)
		var disc := Vector2(0, 2)
		draw_circle(disc, 24.0, Style.INK)
		draw_arc(disc, 24.0, 0, TAU, 28, Color(Style.PAPER, 0.35), 1.2, true)
		Style.text(self, Style.num(700), str(i + 1), disc + Vector2(0, -1), 25 if i < 99 else 20,
			Color(Style.COIN, 0.85) if boss else Color(Style.PAPER, 0.75))
	if face_up and unlocked and not is_current and Progress.cascade_stars(i) >= 3:
		# All three stars: a gold edge, so replays are easy to spot.
		draw_rect(r.grow(-3.0), Style.COIN, false, 4.0)
	if boss:
		_draw_crown(Vector2(0, r.position.y - 4.0), face_up)
	elif hard.has(i):
		var super_hard: bool = int(hard[i]) == 2
		var word := "Super hard" if super_hard else "Hard"
		# On the card's bottom edge, so it never runs into the stars of the
		# level above it on the path.
		var tw := Style.caps_width(word, 11, 0.1) + 12.0
		var tr := Rect2(Vector2(-tw * 0.5, r.end.y - 11.0), Vector2(tw, 18))
		draw_rect(Rect2(tr.position + Vector2(2, 2), tr.size), Style.INK)
		draw_rect(tr, Style.INK if super_hard else Style.ACCENT)
		Style.caps(self, word, tr.get_center() + Vector2(0, -1), 11, Style.COIN if super_hard else Style.CARD, 0.1)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if unlocked and not is_current and (i != _flip_level or _flip_t >= 1.0):
		var got := Progress.cascade_stars(i)
		for k in 3:
			var sp := c + Vector2((k - 1) * 24.0, CARD.y * 0.5 * sc + 18.0 - (6.0 if k == 1 else 0.0))
			Style.fancy_star(self, sp, 11.0, 1.0 if k < got else 0.0)

## Every few seconds a band of light sweeps across your next level's card,
## so the eye goes straight to it.
func _draw_sheen(r: Rect2) -> void:
	var t := fmod(_time, 3.2) / 0.7
	if t >= 1.0:
		return
	var x := lerpf(r.position.x - 60.0, r.end.x + 20.0, t)
	var band := PackedVector2Array([Vector2(x, r.end.y), Vector2(x + 22.0, r.end.y), Vector2(x + 62.0, r.position.y),
		Vector2(x + 40.0, r.position.y)])
	var rect := PackedVector2Array([r.position + Vector2(2, 2), Vector2(r.end.x - 2, r.position.y + 2), r.end - Vector2(2, 2),
		Vector2(r.position.x + 2, r.end.y - 2)])
	for poly in Geometry2D.intersect_polygons(band, rect):
		draw_colored_polygon(poly, Color(1, 1, 1, 0.55 * sin(t * PI)))

func _draw_crown(base: Vector2, lit: bool) -> void:
	var pts := PackedVector2Array([base + Vector2(-20, 0), base + Vector2(-24, -22), base + Vector2(-10, -11),
		base + Vector2(0, -28), base + Vector2(10, -11), base + Vector2(24, -22), base + Vector2(20, 0)])
	draw_colored_polygon(PackedVector2Array(Array(pts).map(func(v): return v + Vector2(3, 3))), Style.INK)
	draw_colored_polygon(pts, Style.COIN if lit else Color(Style.COIN, 0.8))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Style.INK, 2.0, true)
	for x in [-24.0, 0.0, 24.0]:
		var tip := base + Vector2(x, -22.0 if x != 0.0 else -28.0)
		draw_circle(tip, 3.5, Style.CARD)
		draw_arc(tip, 3.5, 0, TAU, 12, Style.INK, 1.5, true)

## A gift on the map is a treasure card (Kayan picked it from four
## designs): face-down with a gold frame, a ribbon and a medallion showing
## the coins inside, and the stars it needs underneath. A ready one bobs
## with a burst of light behind it; opening flips it face-up.
func _draw_gift(c: Vector2, k: int) -> void:
	var opened := Progress.gift_box_opened(k)
	var ready := Progress.gift_box_ready(k)
	var popping := k == _open_k and _open_t < 1.0
	if popping:
		opened = _open_t > 0.3
	var rot := 0.0
	if k == _shake_k and _shake_t > 0.0:
		rot = sin(_shake_t * 30.0) * 0.12 * _shake_t
	_draw_box_at(c, rot, opened, ready and not popping, Progress.gift_box_coins(k), Progress.gift_box_need(k),
		_open_t if popping else 1.0)

func _draw_box_at(c: Vector2, rot: float, opened: bool, ready: bool, coins: int, need: int, pop: float, sc := 1.3) -> void:
	if ready:
		c.y += sin(_time * 4.0) * 4.0
		rot += sin(_time * 2.2) * 0.05
		for n in 12:
			var a := n * TAU / 12.0 + _time * 0.6
			var p0 := c + Vector2.from_angle(a) * 50.0 * sc / 1.3
			var p1 := c + Vector2.from_angle(a + 0.13) * 96.0 * sc / 1.3
			var p2 := c + Vector2.from_angle(a - 0.13) * 96.0 * sc / 1.3
			draw_colored_polygon(PackedVector2Array([p0, p1, p2]), Color(Style.COIN, 0.35))
	var alpha := 0.55 if opened and pop >= 1.0 else 1.0
	# Opening: it lifts, turns over (squeezing to an edge at the halfway
	# point) and settles face-up.
	var k := Vector2.ONE * sc
	if pop < 1.0:
		var f := clampf(pop / 0.6, 0.0, 1.0)
		k = Vector2(maxf(absf(cos(f * PI)), 0.05), 1.0) * sc * (1.0 + 0.3 * sin(f * PI))
		c.y -= 40.0 * sin(f * PI)
	draw_set_transform(c, rot, k)
	_box_card(opened, ready, coins, alpha)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not opened and not ready:
		var tag := c + Vector2(0, 50.0 * sc + 2.0)
		Style.fancy_star(self, tag + Vector2(-16, 0), 9.0, 1.0)
		Style.text(self, Style.serif(800, 48), str(need), tag + Vector2(8, -1), 18, Color(Style.INK, 0.75))
	if pop < 0.6:
		var f := pop / 0.6
		for n in 10:
			var a := n * TAU / 10.0
			draw_line(c + Vector2.from_angle(a) * (30.0 + 60.0 * f), c + Vector2.from_angle(a) * (40.0 + 90.0 * f),
				Color(Style.COIN, 1.0 - f), 4.0, true)

## Face-down: gold frame, ribbon, coin medallion. Face-up: a tick.
func _box_card(opened: bool, ready: bool, coins: int, alpha: float) -> void:
	var r := Rect2(Vector2(-28, -38), Vector2(56, 76))
	var ink := Color(Style.INK, alpha)
	draw_rect(Rect2(r.position + Vector2(4, 4), r.size), ink)
	if opened:
		draw_rect(r, Color(Style.CARD, alpha))
		draw_rect(r.grow(-4), Color(Style.COIN, alpha), false, 2.0)
		draw_rect(r, ink, false, 2.0)
		draw_polyline(PackedVector2Array([Vector2(-10, 0), Vector2(-2, 8), Vector2(12, -8)]), ink, 4.0, true)
		return
	draw_rect(r, Style.INK)
	Style.hatch(self, r.grow(-6), Color(Style.PAPER, 0.16), 6.0, 1.0)
	draw_rect(r.grow(-3), Style.COIN, false, 3.0)
	# Ribbon across the corner.
	var rib := PackedVector2Array([Vector2(-28, -18), Vector2(-8, -38), Vector2(4, -38), Vector2(-28, -6)])
	draw_colored_polygon(rib, Style.ACCENT)
	draw_polyline(rib + PackedVector2Array([rib[0]]), Style.INK, 1.5, true)
	# Gold medallion with the coins.
	draw_circle(Vector2(2, 6), 17.0, Style.INK)
	draw_circle(Vector2(0, 4), 17.0, Style.COIN if ready else Style.PAPER)
	draw_arc(Vector2(0, 4), 17.0, 0, TAU, 28, Style.INK, 1.5, true)
	draw_arc(Vector2(0, 4), 13.0, 0, TAU, 28, Color(Style.INK, 0.4), 1.0, true)
	Style.text(self, Style.serif(800, 48), str(coins), Vector2(0, 3), 14, Style.INK)

## Stars, name and coins, on a strip of paper the map slides under.
func _draw_top_bar(screen: Vector2) -> void:
	var h := map_top()
	draw_rect(Rect2(Vector2(0, 0), Vector2(screen.x, h)), Style.PAPER)
	draw_rect(Rect2(Vector2(0, h), Vector2(screen.x, 5)), Color(Style.INK, 0.08))
	draw_line(Vector2(0, h), Vector2(screen.x, h), Style.INK, 2.0)
	var y := top + 46.0
	Style.fancy_star(self, Vector2(ox + 40.0, y), 17.0, 1.0)
	# Your player level (stars are the XP), as a small badge on the star.
	var lv: int = League.player_level(Progress.total_stars())[0]
	var bc := Vector2(ox + 52.0, y + 14.0)
	draw_circle(bc + Vector2(2, 2), 10.0, Style.INK)
	draw_circle(bc, 10.0, Style.INK)
	Style.text(self, Style.num(800), str(lv), bc + Vector2(0, -1), 12 if lv < 100 else 10, Style.COIN, 0, Style.INK, false, 0.0, true)
	_star_rect = Rect2(Vector2(ox + 14.0, top + 14.0), Vector2(90.0, 64.0))
	draw_string(Style.num(800), Vector2(ox + 64.0, y + 11.0), Style.commas(Progress.total_stars()), HORIZONTAL_ALIGNMENT_LEFT,
		-1, 30, Style.INK)
	# The days-played streak: a flame and the number of days.
	var sw := Style.text_width(Style.num(800), Style.commas(Progress.total_stars()), 30)
	var fx0 := ox + 64.0 + sw + 30.0
	var n := Progress.day_streak()
	var alive := not Progress.can_repair()
	var shown := n if alive else Progress.streak_lost
	var fk := _press_scale("flame")
	draw_set_transform(Vector2(fx0, y + 2.0), 0.0, Vector2(fk, fk))
	Style.flame(self, Vector2.ZERO, 20.0, shown, alive, _time)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(Style.num(800), Vector2(fx0 + 16.0, y + 11.0), str(shown), HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
		Style.INK if alive else Color(Style.INK, 0.45))
	_flame_rect = Rect2(Vector2(fx0 - 26.0, top + 14.0), Vector2(70.0 + Style.text_width(Style.num(800), str(shown), 26), 64.0))
	if not _intro_full or appear("move") >= 1.0:
		Style.text(self, Style.serif(800, 144), "Cascade", Vector2(ox + W * 0.5, y - (6.0 if Progress.win_streak > 0 else 0.0)), 38,
			Style.INK)
	# Win streak: three red pips under the name, filling as you win in a row.
	if Progress.booster_count("shield") > 0:
		# A Streak shield is waiting: a small shield beside the streak pips.
		var sc := Vector2(ox + W * 0.5 + 44.0, y + 24.0)
		var sh := PackedVector2Array([sc + Vector2(0, -8), sc + Vector2(7, -5), sc + Vector2(6, 3), sc + Vector2(0, 8),
			sc + Vector2(-6, 3), sc + Vector2(-7, -5)])
		draw_colored_polygon(sh, Style.CARD)
		draw_polyline(sh + PackedVector2Array([sh[0]]), Style.INK, 1.5, true)
	if Progress.win_streak > 0:
		for k in 3:
			var p := Vector2(ox + W * 0.5 + (k - 1) * 18.0, y + 24.0)
			var pts := PackedVector2Array([p + Vector2(0, -6), p + Vector2(5, 0), p + Vector2(0, 6), p + Vector2(-5, 0)])
			draw_colored_polygon(pts, Style.ACCENT if k < Progress.win_streak else Color(Style.INK, 0.15))
	Style.coin(self, Vector2(ox + W - 196.0, y), 15.0)
	draw_string(Style.num(700), Vector2(ox + W - 173.0, y + 11.0), Style.commas(coins_shown), HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
		Style.INK)
	# A small "+": the coins open the shop.
	var pw := Style.text_width(Style.num(700), Style.commas(coins_shown), 30)
	var pc := Vector2(minf(ox + W - 173.0 + pw + 18.0, ox + W - 88.0), y)
	draw_circle(pc + Vector2(2, 2), 11.0, Style.INK)
	draw_circle(pc, 11.0, Style.group_color(2))
	draw_arc(pc, 11.0, 0, TAU, 20, Style.INK, 2.0, true)
	draw_line(pc + Vector2(-5, 0), pc + Vector2(5, 0), Style.CARD, 3.0)
	draw_line(pc + Vector2(0, -5), pc + Vector2(0, 5), Style.CARD, 3.0)
	_draw_gear(_gear_rect().get_center())

func _draw_gear(c: Vector2) -> void:
	var teeth := 8
	var pts := PackedVector2Array()
	var turn: float = PI / 4.0 * Style.ease_back(clampf(_gear_t / 0.8, 0.0, 1.0))
	var k: float = 1.0 - 0.18 * sin(clampf(_gear_t / 0.35, 0.0, 1.0) * PI)
	for i in teeth * 2:
		var a := i * PI / teeth + turn
		var r := (16.0 if i % 2 == 0 else 12.0) * k
		pts.append(c + Vector2.from_angle(a - PI / teeth * 0.5) * r)
		pts.append(c + Vector2.from_angle(a + PI / teeth * 0.5) * r)
	draw_colored_polygon(pts, Style.INK)
	draw_circle(c, 6.0 * k, Style.PAPER)

## The bottom panel: the collection shelf; the owner adds the buttons below.
func _draw_panel(screen: Vector2) -> void:
	var y := panel_top()
	draw_rect(Rect2(Vector2(0, y - 5), Vector2(screen.x, 5)), Color(Style.INK, 0.08))
	draw_rect(Rect2(Vector2(0, y), Vector2(screen.x, screen.y - y)), Style.PAPER)
	draw_line(Vector2(0, y), Vector2(screen.x, y), Style.INK, 2.0)
	var sr := shelf_rect()
	Style.printed(self, sr, Style.CARD, 5.0, 2, 3)
	# A small tab on the shelf's corner says where it goes.
	var tab := Rect2(Vector2(sr.end.x - 104.0, sr.position.y - 14.0), Vector2(88, 24))
	draw_rect(Rect2(tab.position + Vector2(2, 2), tab.size), Style.INK)
	draw_rect(tab, Style.INK)
	Style.caps(self, "Album  ›", tab.get_center() + Vector2(0, -1), 12, Style.CARD, 0.12)
	var fs := Progress.featured_set()
	var missing := Progress.set_missing()
	var ids: Array = fs.set.groups
	var normal := LevelGen.load_groups()
	var cw := Vector2(44, 60)
	var x0 := sr.position.x + 22.0
	for k in ids.size():
		var ci := 0
		for gi in normal.size():
			if normal[gi].id == ids[k]:
				ci = gi
		var got := not missing.has(ids[k])
		var r := Rect2(Vector2(x0 + k * 54.0, sr.get_center().y - cw.y * 0.5), cw)
		if got:
			var col := Style.group_color(ci)
			draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Style.INK)
			draw_rect(r, Style.CARD)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 9)), col)
			draw_line(r.position + Vector2(0, 9), Vector2(r.end.x, r.position.y + 9), Style.INK, 1.5)
			Style.group_symbol(self, ci, r.get_center() + Vector2(0, 5), 11.0, col)
			draw_rect(r, Style.INK, false, 2.0)
		else:
			var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
			for e in 4:
				draw_dashed_line(pts[e], pts[e + 1], Color(Style.INK, 0.3), 1.5, 5.0, true)
	# Divider, then the set's ribbon with days left, then rare cards found.
	var dx := x0 + ids.size() * 54.0 + 4.0
	draw_line(Vector2(dx, sr.position.y + 16.0), Vector2(dx, sr.end.y - 16.0), Color(Style.INK, 0.2), 1.5)
	var rc := Vector2(dx + 50.0, sr.get_center().y - 10.0)
	_mini_ribbon(rc, Progress.set_done)
	Style.caps(self, "%d day%s" % [fs.days_left, "" if fs.days_left == 1 else "s"], rc + Vector2(0, 38), 13,
		Color(Style.INK, 0.6), 0.1)
	var rare := LevelGen.load_rare()
	var found := 0
	for g in rare:
		found += 1 if Progress.album.has(g.id) else 0
	var gc := Vector2(dx + 128.0, sr.get_center().y - 8.0)
	var gr := Rect2(gc - Vector2(19, 25), Vector2(38, 50))
	draw_rect(Rect2(gr.position + Vector2(3, 3), gr.size), Style.INK)
	draw_rect(gr, Style.COIN if found > 0 else Style.PAPER_DEEP)
	draw_rect(gr.grow(-4), Style.INK, false, 1.0)
	draw_rect(gr, Style.INK, false, 2.0)
	Style.star(self, gc, 10.0, 4.5, Style.CARD if found > 0 else Color(Style.INK, 0.25))
	Style.caps(self, "%d/%d" % [found, rare.size()], gc + Vector2(0, 40), 13, Color(Style.INK, 0.6), 0.1)

func _mini_ribbon(c: Vector2, won: bool) -> void:
	var gold := Style.COIN if won else Style.PAPER_DEEP
	for side in [-1.0, 1.0]:
		var tail := PackedVector2Array([c + Vector2(side * 4, 0), c + Vector2(side * 14, 28), c + Vector2(side * 8, 23),
			c + Vector2(side * 2, 30), c + Vector2(side * -2, 4)])
		draw_colored_polygon(tail, Style.ACCENT if won else Color(Style.INK, 0.2))
	var pts := PackedVector2Array()
	for i in 24:
		pts.append(c + Vector2.from_angle(TAU * i / 24.0) * (18.0 if i % 2 == 0 else 15.0))
	draw_colored_polygon(pts, gold)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Style.INK, 1.5, true)
	draw_circle(c, 9.0, Style.CARD)
	draw_arc(c, 9.0, 0, TAU, 20, Style.INK, 1.2, true)
	var got: int = Progress.featured_set().set.groups.size() - Progress.set_missing().size()
	Style.text(self, Style.serif(800, 48), str(got), c + Vector2(0, -1), 12, Style.INK)
