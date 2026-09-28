class_name Fx
extends Node2D
## Everything celebratory that sits on top of the cards. Printed-paper style:
## flat confetti shapes in the group colours, sunbursts of alternating wedges,
## ink rings, big serif words with a hard shadow, flat coins. No glows.

const COLORS := [Color("e4502e"), Color("2f6fd6"), Color("1f9d6a"), Color("f2b705"), Color("e5487f"), Color("1c1a17")]
const WARM := [Color("f2b705"), Color("e4502e"), Color("1c1a17"), Color("fffdf8")]

var _sparks: Array[Dictionary] = []
var _confetti: Array[Dictionary] = []
var _popups: Array[Dictionary] = []
var _coins: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _rays: Array[Dictionary] = []
var _banner := {}
var _beams: Array[Dictionary] = []
var _toasts: Array[Dictionary] = []   ## waiting in line; the first one is showing

func _init() -> void:
	z_index = 900

# ---------------------------------------------------------------- spawning

func burst(at: Vector2, count := 26, speed := 520.0, colors := COLORS, gravity := 500.0) -> void:
	for i in count:
		var v := Vector2.from_angle(randf() * TAU) * randf_range(speed * 0.3, speed)
		_sparks.append({"p": at, "v": v, "life": randf_range(0.45, 0.85), "age": 0.0,
			"size": randf_range(5.0, 12.0), "color": colors[randi() % colors.size()],
			"spin": randf_range(-6.0, 6.0), "g": gravity, "kind": randi() % 3})

## Small soft puffs where a card lands, like dust off the table.
func puff(at: Vector2, width := 110.0) -> void:
	for i in 8:
		var side := -1.0 if i % 2 == 0 else 1.0
		_sparks.append({"p": at + Vector2(side * width * 0.5 * randf_range(0.6, 1.0), 0),
			"v": Vector2(side * randf_range(60, 160), randf_range(-60, -10)), "life": 0.35, "age": 0.0,
			"size": randf_range(6.0, 10.0), "color": Color(1, 1, 1, 0.5), "spin": 0.0, "g": 0.0, "kind": 3})

## One glittering dot, for trails behind flying cards.
func trail(at: Vector2, color := Color(0, 0, 0, 0)) -> void:
	var c: Color = color if color.a > 0.0 else WARM[randi() % WARM.size()]
	_sparks.append({"p": at + Vector2(randf_range(-18, 18), randf_range(-18, 18)),
		"v": Vector2(randf_range(-40, 40), randf_range(-40, 40)), "life": 0.45, "age": 0.0,
		"size": randf_range(4.0, 8.0), "color": c, "spin": 3.0, "g": 0.0, "kind": randi() % 3})

## A quick glowing line, e.g. the magnet's pull from the tray to a card.
func beam(from: Vector2, to: Vector2, color := Style.ACCENT, life := 0.3, width := 10.0) -> void:
	_beams.append({"a": from, "b": to, "color": color, "age": 0.0, "life": life, "w": width})

func ring(at: Vector2, radius := 240.0, color := Style.COIN, life := 0.5) -> void:
	_rings.append({"p": at, "r": radius, "color": color, "age": 0.0, "life": life})

## Slowly turning rays of light behind a moment worth celebrating.
func rays(at: Vector2, life := 1.2, radius := 380.0, count := 16, color := Style.COIN) -> void:
	_rays.append({"p": at, "age": 0.0, "life": life, "r": radius, "n": count, "color": color})

func confetti(width: float, count := 110) -> void:
	for i in count:
		_confetti.append({"p": Vector2(randf() * width, randf_range(-400.0, -20.0)),
			"v": Vector2(randf_range(-80.0, 80.0), randf_range(240.0, 520.0)),
			"rot": randf() * TAU, "spin": randf_range(-9.0, 9.0), "flip": randf() * TAU,
			"size": Vector2(randf_range(12.0, 18.0), randf_range(7.0, 11.0)),
			"color": COLORS[randi() % COLORS.size()], "age": 0.0, "life": 4.0})

## style: "plain" | "big" (elastic pop, for streak words)
func popup(text: String, at: Vector2, color := Color.WHITE, size := 44, rise := 90.0, life := 1.1,
		style := "plain") -> void:
	_popups.append({"text": text, "p": at, "color": color, "size": size, "rise": rise,
		"age": 0.0, "life": life, "style": style})

## `icons` (optional): {"groups": n, "taps": n} drawn under the name as a
## little fan of cards with the number of groups and a star with the 3-star taps.
func banner(text: String, sub: String, at: Vector2, life := 1.6, icons := {}) -> void:
	_banner = {"text": text, "sub": sub, "p": at, "age": 0.0, "life": life, "icons": icons}

## Coins leap from `from` and curve into `to`. `on_land` runs per coin.
func coins(from: Vector2, to: Vector2, count: int, on_land := Callable(), spread := 60.0) -> void:
	for i in count:
		var start := from + Vector2(randf_range(-spread, spread), randf_range(-spread * 0.6, spread * 0.6))
		_coins.append({"from": start, "to": to, "age": -i * 0.045, "dur": randf_range(0.5, 0.65),
			"pop": Vector2.from_angle(randf() * TAU) * randf_range(60, 150), "cb": on_land})

## A small printed strip that slides down from the top, holds, and slides
## back up: a medal in `color`, a title, and coins. For achievements, so they
## never land on top of a panel. Several wait in line.
func toast(title: String, coins: int, color: Color, y: float, life := 2.2) -> void:
	_toasts.append({"title": title, "coins": coins, "color": color, "y": y, "age": 0.0, "life": life})

func toasts_waiting() -> int:
	return _toasts.size()

## Hurry any floating words off screen (a new action is starting).
func fade_popups() -> void:
	for p in _popups:
		p.age = maxf(p.age, p.life - 0.2)

func coins_in_flight() -> int:
	return _coins.size()

func busy() -> bool:
	return not (_sparks.is_empty() and _confetti.is_empty() and _popups.is_empty()
		and _coins.is_empty() and _banner.is_empty() and _rings.is_empty() and _rays.is_empty() and _beams.is_empty()
		and _toasts.is_empty())

# ---------------------------------------------------------------- update

func _process(delta: float) -> void:
	if not busy():
		return
	for s in _sparks:
		s.age += delta
		s.v *= pow(0.06, delta)
		s.v.y += s.g * delta
		s.p += s.v * delta
	_sparks = _sparks.filter(func(s): return s.age < s.life)
	for c in _confetti:
		c.age += delta
		c.p += c.v * delta
		c.p.x += sin(c.age * 3.0 + c.rot) * 50.0 * delta
		c.rot += c.spin * delta
		c.flip += delta * 7.0
	_confetti = _confetti.filter(func(c): return c.age < c.life)
	for p in _popups:
		p.age += delta
	_popups = _popups.filter(func(p): return p.age < p.life)
	for r in _rings:
		r.age += delta
	_rings = _rings.filter(func(r): return r.age < r.life)
	for r in _rays:
		r.age += delta
	_rays = _rays.filter(func(r): return r.age < r.life)
	for b in _beams:
		b.age += delta
	_beams = _beams.filter(func(b): return b.age < b.life)
	var landed: Array = []
	for c in _coins:
		c.age += delta
		if c.age >= c.dur:
			landed.append(c.cb)
	_coins = _coins.filter(func(c): return c.age < c.dur)
	for cb in landed:
		if cb.is_valid():
			cb.call()
	if not _banner.is_empty():
		_banner.age += delta
		if _banner.age > _banner.life:
			_banner = {}
	if not _toasts.is_empty():
		_toasts[0].age += delta
		if _toasts[0].age > _toasts[0].life:
			_toasts.pop_front()
	queue_redraw()

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	for r in _rays:
		_draw_rays(r)
	for b in _beams:
		var k: float = 1.0 - b.age / b.life
		var col: Color = b.color
		# The beam shoots out quickly, then fades.
		var reach := minf(b.age / (b.life * 0.35), 1.0)
		var end: Vector2 = b.a.lerp(b.b, reach)
		draw_line(b.a, end, Color(Style.INK, k), b.w * 0.9, true)
		draw_line(b.a, end, Color(col, k), b.w * 0.5, true)
		draw_circle(end, b.w * 0.8, Color(Style.INK, k))
		draw_circle(end, b.w * 0.5, Color(col, k))
	for r in _rings:
		var t: float = r.age / r.life
		var rad: float = r.r * (1.0 - pow(1.0 - t, 3.0))
		var col: Color = r.color
		col.a = 1.0 - t
		draw_arc(r.p, rad, 0.0, TAU, 64, Color(Style.INK, 1.0 - t), 10.0 * (1.0 - t) + 3.0, true)
		draw_arc(r.p, rad, 0.0, TAU, 64, col, 6.0 * (1.0 - t) + 1.0, true)
	for s in _sparks:
		var k: float = 1.0 - s.age / s.life
		var c: Color = s.color
		c.a *= minf(1.0, k * 2.5)
		var z: float = s.size * (0.55 + 0.45 * k)
		if z < 1.0:
			continue
		var rot: float = s.age * s.spin
		match int(s.kind):
			3:
				draw_circle(s.p, s.size * (1.5 - k * 0.5), Color(Style.INK, 0.12 * k))
			2:
				draw_circle(s.p, z * 0.55, c)
			1:
				draw_set_transform(s.p, rot, Vector2.ONE)
				draw_rect(Rect2(-Vector2(z, z) * 0.5, Vector2(z, z)), c)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:
				var tri := PackedVector2Array()
				for i in 3:
					tri.append(s.p + Vector2.from_angle(rot + i * TAU / 3.0) * z * 0.7)
				draw_colored_polygon(tri, c)
	for c in _confetti:
		# Squashing one axis on a sine makes each piece look like it's tumbling.
		draw_set_transform(c.p, c.rot, Vector2(1.0, absf(sin(c.flip)) * 0.8 + 0.2))
		var col: Color = c.color
		col.a = clampf((c.life - c.age) * 2.0, 0.0, 1.0)
		draw_rect(Rect2(-c.size * 0.5, c.size), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for c in _coins:
		if c.age < 0.0:
			continue
		var t: float = clampf(c.age / c.dur, 0.0, 1.0)
		# First a little pop outward, then a swoop into the counter.
		var pop_t := minf(t / 0.25, 1.0)
		var start: Vector2 = c.from + c.pop * (1.0 - pow(1.0 - pop_t, 2.0))
		var e := maxf(0.0, (t - 0.2) / 0.8)
		e = e * e
		var p: Vector2 = start.lerp(c.to, e)
		var r := 13.0 * (1.0 - 0.3 * e)
		draw_set_transform(p, 0.0, Vector2(absf(cos(c.age * 9.0)) * 0.7 + 0.3, 1.0))
		Style.coin(self, Vector2.ZERO, r)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for p in _popups:
		_draw_popup(p)
	if not _banner.is_empty():
		_draw_banner()
	if not _toasts.is_empty():
		_draw_toast(_toasts[0])

## A sunburst: alternating flat wedges that turn slowly, printed-poster style.
func _draw_rays(r: Dictionary) -> void:
	var t: float = r.age / r.life
	var fade := minf(t / 0.12, 1.0) * (1.0 - maxf(0.0, (t - 0.5) / 0.5))
	var n: int = r.n
	var rot: float = r.age * 0.5
	var col: Color = r.get("color", Style.COIN)
	var grow := 0.6 + 0.4 * minf(t / 0.25, 1.0)
	for i in n:
		var a := rot + i * TAU / n
		var w := TAU / n * 0.5
		var pts := PackedVector2Array([r.p, r.p + Vector2.from_angle(a - w * 0.5) * r.r * grow,
			r.p + Vector2.from_angle(a + w * 0.5) * r.r * grow])
		draw_colored_polygon(pts, Color(col, 0.22 * fade))

## Styles: "big" = large serif with a hard ink shadow and an elastic pop;
## "plain" = smaller serif; "caps" = small letter-spaced sans capitals.
func _draw_popup(p: Dictionary) -> void:
	var t: float = p.age / p.life
	var grow := 1.0
	if p.style == "big":
		grow = 0.3 + 0.7 * Style.ease_elastic(minf(t / 0.45, 1.0))
	else:
		grow = 1.0 + 0.3 * maxf(0.0, 1.0 - t * 6.0)
	var col: Color = p.color
	col.a = 1.0 - maxf(0.0, (t - 0.65) / 0.35)
	var pos: Vector2 = p.p + Vector2(0, -p.rise * (1.0 - pow(1.0 - t, 3.0)))
	var size := int(p.size * grow)
	if size < 4:
		return
	var tilt := sin(p.age * 7.0) * 0.04 if p.style == "big" else 0.0
	draw_set_transform(pos, tilt, Vector2.ONE)
	if p.style == "caps":
		Style.caps(self, p.text, Vector2(0, 0), size, col, 0.18)
	elif p.style == "big":
		Style.text(self, Style.serif(800, 144), p.text, Vector2.ZERO, size, col, 0, Style.INK, true, maxf(3.0, size * 0.06))
	else:
		Style.text(self, Style.serif(700, 72), p.text, Vector2.ZERO, size, col, 0, Style.INK, true, maxf(2.0, size * 0.05))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## An ink strip across the screen with the group name in paper serif.
func _draw_banner() -> void:
	var a: float = _banner.age
	var life: float = _banner.life
	var inn := Style.ease_back(clampf(a / 0.28, 0.0, 1.0))
	var out := clampf((a - (life - 0.3)) / 0.3, 0.0, 1.0)
	var alpha := 1.0 - out
	var center: Vector2 = _banner.p
	var width := get_viewport_rect().size.x
	var h := 86.0 * inn
	var r := Rect2(Vector2(0, center.y - h * 0.5), Vector2(width, h))
	draw_rect(Rect2(r.position + Vector2(0, 6), r.size), Color(Style.INK, 0.25 * alpha))
	draw_rect(r, Color(Style.INK, alpha))
	draw_line(Vector2(0, r.position.y + 6), Vector2(width, r.position.y + 6), Color(Style.PAPER, 0.3 * alpha), 1.0)
	draw_line(Vector2(0, r.end.y - 6), Vector2(width, r.end.y - 6), Color(Style.PAPER, 0.3 * alpha), 1.0)
	if inn > 0.6:
		Style.text(self, Style.serif(700, 144), _banner.text, center + Vector2(0, -2), 46, Color(Style.PAPER, alpha))
	var icons: Dictionary = _banner.get("icons", {})
	if not icons.is_empty() and inn > 0.6:
		var iy := r.end.y + (78.0 if _banner.sub != "" else 34.0)
		var plate := Rect2(Vector2(center.x - 120.0, iy - 24.0), Vector2(240, 48))
		draw_rect(Rect2(plate.position + Vector2(3, 3), plate.size), Color(Style.INK, alpha))
		draw_rect(plate, Color(Style.CARD, alpha))
		draw_rect(plate, Color(Style.INK, alpha), false, 2.0)
		# A little fan of cards and the number of groups; a star and the 3-star taps.
		var ic := Vector2(center.x - 78.0, iy)
		for k in 2:
			var cr := Rect2(ic + Vector2(-14 + k * 8, -16 - k * 2), Vector2(22, 30))
			draw_rect(Rect2(cr.position + Vector2(2, 2), cr.size), Color(Style.INK, alpha))
			draw_rect(cr, Color(Style.CARD, alpha))
			draw_rect(Rect2(cr.position, Vector2(22, 7)), Color(Style.group_color(k * 3), alpha))
			draw_rect(cr, Color(Style.INK, alpha), false, 1.5)
		Style.text(self, Style.num(800), str(int(icons.get("groups", 0))), ic + Vector2(40, 0), 28, Color(Style.INK, alpha))
		draw_line(Vector2(center.x, iy - 14.0), Vector2(center.x, iy + 14.0), Color(Style.INK, 0.25 * alpha), 1.5)
		var sc := Vector2(center.x + 42.0, iy)
		Style.fancy_star(self, sc, 15.0, alpha)
		Style.text(self, Style.num(800), str(int(icons.get("taps", 0))), sc + Vector2(38, 0), 28, Color(Style.INK, alpha))
	if _banner.sub != "":
		# The line underneath gets its own paper strip, so it reads over the cards.
		var sw := Style.caps_width(_banner.sub, 15, 0.16) + 40.0
		var sr := Rect2(Vector2(center.x - sw * 0.5, r.end.y + 8.0), Vector2(sw, 34.0 * inn))
		draw_rect(Rect2(sr.position + Vector2(3, 3), sr.size), Color(Style.INK, alpha))
		draw_rect(sr, Color(Style.CARD, alpha))
		draw_rect(sr, Color(Style.INK, alpha), false, 2.0)
		if inn > 0.6:
			Style.caps(self, _banner.sub, sr.get_center(), 15, Color(Style.INK, alpha), 0.16)

## The toast: drops in with a little overshoot, holds, then lifts away.
func _draw_toast(t: Dictionary) -> void:
	var a: float = t.age
	var life: float = t.life
	var inn := Style.ease_back(clampf(a / 0.35, 0.0, 1.0))
	var out := clampf((a - (life - 0.3)) / 0.3, 0.0, 1.0)
	out = out * out
	var title: String = t.title
	var w := maxf(Style.text_width(Style.serif(700, 48), title, 24) + 190.0, 320.0)
	var c := Vector2(get_viewport_rect().size.x * 0.5, float(t.y) - 150.0 * (1.0 - inn) - 150.0 * out)
	var r := Rect2(c - Vector2(w * 0.5, 36), Vector2(w, 72))
	Style.printed(self, r, Style.CARD, 5.0, 2, 3)
	# The medal, with a star, on the left.
	var m := r.position + Vector2(40, 36)
	var col: Color = t.color
	draw_circle(m + Vector2(3, 3), 22.0, Style.INK)
	draw_circle(m, 22.0, col)
	draw_arc(m, 22.0, 0, TAU, 32, Style.INK, 2.0, true)
	draw_arc(m, 16.0, 0, TAU, 32, Color(Style.INK, 0.35), 1.0, true)
	Style.star(self, m, 10.0, 4.5, Style.CARD, sin(a * 3.0) * 0.2)
	draw_string(Style.serif(700, 48), r.position + Vector2(76, 45), title, HORIZONTAL_ALIGNMENT_LEFT, -1, Style._grow(24), Style.INK)
	if int(t.coins) > 0:
		var cx := r.end.x - 70.0
		Style.coin(self, Vector2(cx - 18, c.y), 11.0)
		Style.text(self, Style.serif(800, 48), "+%d" % int(t.coins), Vector2(cx + 16, c.y - 1), 20, Style.INK)
