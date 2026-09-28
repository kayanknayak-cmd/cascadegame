class_name Style
extends RefCounted
## The look: Editorial Paper. Warm paper, black ink, bold flat colour, and a
## magazine serif. Beauty comes from type and restraint; the rewards come from
## colour flooding in, not from glow.
##   Fraunces - the serif: card names, numbers, big praise words
##   Inter    - the sans: small letter-spaced capital labels (LEVEL 9, TRAY)
## Both are Open Font License (see fonts/LICENSES.md).
##
## Every group in a level gets one colour from GROUPS, so matches read at a
## glance, the way candy colours do.

const PAPER := Color("f6f1e7")
const PAPER_DEEP := Color("ece3d1")
const CARD := Color("fffdf8")
const INK := Color("1c1a17")
const INK_SOFT := Color("1c1a17b3")
const ACCENT := Color("e4502e")
const COIN := Color("f2b705")

## Ordered so the colours most levels use (the first eight) are the most
## different from each other.
const GROUPS := [
	Color("e4502e"), Color("2f6fd6"), Color("1f9d6a"), Color("f2b705"),
	Color("7b4fd6"), Color("d6368f"), Color("16b5c9"), Color("8a5a36"),
	Color("8a9a1b"), Color("f28c28"), Color("5b6b7a"), Color("9fc3ef"),
]

# Old names, kept so the first prototype still runs.
const CREAM := PAPER
const GOLD := COIN
const GOLD_DEEP := Color("c8901e")
const WARN := ACCENT
const SHADOW := INK

static var _fonts: Dictionary = {}

## Each group also has a shape, so colour is never the only clue (for
## colour-blind players, and it just reads faster).
static func group_symbol(ci: CanvasItem, g: int, c: Vector2, r: float, col: Color) -> void:
	match posmod(g, 12):
		0:
			ci.draw_circle(c, r, col)
		1:
			ci.draw_rect(Rect2(c - Vector2(r, r) * 0.85, Vector2(r, r) * 1.7), col)
		2:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.1), c + Vector2(r, r * 0.8), c + Vector2(-r, r * 0.8)]), col)
		3:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 1.2), c + Vector2(r, 0), c + Vector2(0, r * 1.2), c + Vector2(-r, 0)]), col)
		4:
			star(ci, c, r * 1.25, r * 0.55, col)
		5:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, r * 1.1), c + Vector2(r, -r * 0.8), c + Vector2(-r, -r * 0.8)]), col)
		6:
			var hex := PackedVector2Array()
			for i in 6:
				hex.append(c + Vector2.from_angle(i * TAU / 6.0) * r * 1.05)
			ci.draw_colored_polygon(hex, col)
		7:
			ci.draw_rect(Rect2(c - Vector2(r * 1.1, r * 0.35), Vector2(r * 2.2, r * 0.7)), col)
			ci.draw_rect(Rect2(c - Vector2(r * 0.35, r * 1.1), Vector2(r * 0.7, r * 2.2)), col)
		8:
			ci.draw_arc(c, r * 0.8, 0, TAU, 20, col, r * 0.45, true)
		9:
			ci.draw_rect(Rect2(c - Vector2(r * 1.1, r * 0.45), Vector2(r * 2.2, r * 0.9)), col)
		10:
			ci.draw_circle(c + Vector2(-r * 0.55, 0), r * 0.5, col)
			ci.draw_circle(c + Vector2(r * 0.55, 0), r * 0.5, col)
		_:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r), c + Vector2(r, -r), c + Vector2(0, r)]), col)
			ci.draw_rect(Rect2(c + Vector2(-r * 0.2, -r * 0.2), Vector2(r * 0.4, r * 1.2)), col)

static func group_color(g: int) -> Color:
	return GROUPS[posmod(g, GROUPS.size())]

## Ink or paper, whichever reads better on top of colour c.
static func on_color(c: Color) -> Color:
	return INK if c.get_luminance() > 0.55 else CARD

## Fraunces. opsz: small sizes want ~24, display sizes want 72+.
static func serif(weight := 600, opsz := 48) -> Font:
	return _font("res://fonts/Fraunces.ttf", {"wght": weight, "opsz": opsz, "SOFT": 0, "WONK": 0})

## Numbers: the same serif at a sturdier optical size. The display cut's
## hairlines vanish at small sizes and its flat-topped 3 then reads as a 5
## (level 13 looked like 15 on the map).
static func num(weight := 800) -> Font:
	return serif(weight, 36)

static func sans(weight := 700) -> Font:
	return _font("res://fonts/Inter.ttf", {"wght": weight, "opsz": 24})

static func title(weight := 600) -> Font:
	return serif(weight)

static func body(weight := 700) -> Font:
	return sans(weight)

static func _font(path: String, axes: Dictionary) -> Font:
	var k := path + str(axes)
	if not _fonts.has(k):
		var base: FontFile = load(path)
		base.hinting = TextServer.HINTING_LIGHT
		base.oversampling = 2.0
		var v := FontVariation.new()
		v.base_font = base
		var ts := TextServerManager.get_primary_interface()
		var o := {}
		for a in axes:
			o[ts.name_to_tag(a)] = axes[a]
		v.variation_opentype = o
		_fonts[k] = v
	return _fonts[k]

## "Big text" setting: small words everywhere get bigger (headlines are
## already big). Set from Progress.large_text by the game screen.
static var big := false

static func _grow(size: int) -> int:
	if not big:
		return size
	if size <= 16:
		return size + 3
	if size <= 30:
		return int(size * 1.12)
	return size

## Centred text. outline > 0 adds an outline; shadow adds a hard offset
## shadow (the printed, risograph look) in outline_color. fixed = don't apply
## Big text (for text that already picks its own size to fit, like card names).
static func text(ci: CanvasItem, font: Font, s: String, center: Vector2, size: int, color: Color,
		outline := 0, outline_color := INK, shadow := false, shadow_offset := 0.0, fixed := false) -> void:
	if s == "":
		return
	if not fixed:
		size = _grow(size)
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := center + Vector2(-w * 0.5, size * 0.34)
	var oc := outline_color
	oc.a *= color.a
	if shadow or shadow_offset > 0.0:
		var off := shadow_offset if shadow_offset > 0.0 else size * 0.06
		ci.draw_string(font, pos + Vector2(off, off), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, oc)
		if outline > 0:
			ci.draw_string_outline(font, pos + Vector2(off, off), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, oc)
	if outline > 0:
		ci.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, oc)
	ci.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

## Small letter-spaced capitals, the editorial label style.
static func caps(ci: CanvasItem, s: String, center: Vector2, size: int, color: Color, tracking := 0.14,
		weight := 800) -> void:
	var f := sans(weight)
	var up := s.to_upper()
	size = _grow(size)
	var gap := size * tracking
	var x := center.x - _caps_width_exact(s, size, tracking, weight) * 0.5
	for ch in up:
		ci.draw_string(f, Vector2(x, center.y + size * 0.36), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + gap

static func caps_width(s: String, size: int, tracking := 0.14, weight := 800) -> float:
	return _caps_width_exact(s, _grow(size), tracking, weight)

static func _caps_width_exact(s: String, size: int, tracking := 0.14, weight := 800) -> float:
	var f := sans(weight)
	var total := 0.0
	for ch in s.to_upper():
		total += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + size * tracking
	return total - size * tracking

static func text_width(font: Font, s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, _grow(size)).x

static func box(bg: Color, radius := 3, border := Color(0, 0, 0, 0), border_w := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(border_w)
	s.anti_aliasing = true
	return s

## A flat panel with an ink border and a hard offset shadow.
static func printed(ci: CanvasItem, r: Rect2, fill: Color, shadow := 5.0, border := 2, radius := 3) -> void:
	if shadow > 0.0:
		ci.draw_style_box(box(Color(INK, 0.9 * fill.a), radius), Rect2(r.position + Vector2(shadow, shadow), r.size))
	ci.draw_style_box(box(fill, radius, INK, border), r)

## Diagonal hatching clipped to a rectangle.
static func hatch(ci: CanvasItem, r: Rect2, color: Color, spacing := 8.0, width := 1.5) -> void:
	var c := -r.size.y
	while c < r.size.x:
		# The line x = y + c, trimmed to the rectangle (local coordinates).
		var y0 := maxf(0.0, -c)
		var y1 := minf(r.size.y, r.size.x - c)
		if y1 > y0:
			ci.draw_line(r.position + Vector2(y0 + c, y0), r.position + Vector2(y1 + c, y1), color, width, true)
		c += spacing

static func star(ci: CanvasItem, center: Vector2, outer: float, inner: float, color: Color, rot := 0.0) -> void:
	if outer < 0.75 or color.a <= 0.0:
		return   # too small to see, and a zero-size polygon can't be drawn
	ci.draw_colored_polygon(_star_pts(center, outer, inner, rot), color)

static func _star_pts(center: Vector2, outer: float, inner: float, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var r := outer if i % 2 == 0 else inner
		pts.append(center + Vector2.from_angle(rot - PI * 0.5 + i * PI / 5.0) * r)
	return pts

## Printed star: flat colour, ink outline, hard shadow. fill 0 = empty outline.
static func fancy_star(ci: CanvasItem, center: Vector2, r: float, fill := 1.0, rot := 0.0) -> void:
	if r < 1.0:
		return
	var pts := _star_pts(center, r, r * 0.46, rot)
	if fill <= 0.0:
		pts.append(pts[0])
		ci.draw_polyline(pts, Color(INK, 0.25), 2.0, true)
		return
	ci.draw_colored_polygon(_star_pts(center + Vector2(r * 0.1, r * 0.1), r, r * 0.46, rot), Color(INK, fill))
	ci.draw_colored_polygon(pts, Color(COIN, fill))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(INK, fill), maxf(2.0, r * 0.07), true)

static func coin(ci: CanvasItem, center: Vector2, r: float, alpha := 1.0) -> void:
	ci.draw_circle(center + Vector2(r * 0.14, r * 0.14), r, Color(INK, alpha))
	ci.draw_circle(center, r, Color(COIN, alpha))
	ci.draw_arc(center, r, 0.0, TAU, 24, Color(INK, alpha), maxf(1.5, r * 0.12), true)
	ci.draw_arc(center, r * 0.6, 0.0, TAU, 20, Color(INK, 0.35 * alpha), maxf(1.0, r * 0.08), true)

## The streak flame: bigger and hotter as the streak grows (7, 30, 100 days).
## `alive` false = a grey, cracked flame (the streak broke and can be repaired).
static func flame(ci: CanvasItem, c: Vector2, size: float, days_n: int, alive := true, t := 0.0) -> void:
	var heat := 0 if days_n < 7 else (1 if days_n < 30 else (2 if days_n < 100 else 3))
	var outer: Color = [Color("f08a24"), ACCENT, Color("d8341c"), COIN][heat] if alive else Color(INK, 0.25)
	var inner: Color = [COIN, COIN, Color("ffd66b"), CARD][heat] if alive else PAPER_DEEP
	var k := size * (1.0 + 0.1 * heat)
	var wob := sin(t * 9.0) * 0.06 if alive else 0.0
	# A round bottom (right, down and round to the left), then up to a tip.
	var pts := PackedVector2Array()
	for i in 13:
		var a := i * PI / 12.0
		pts.append(c + Vector2(cos(a) * 0.6, 0.12 + sin(a) * 0.5) * k)
	pts.append(c + Vector2(-0.56, -0.12) * k)
	pts.append(c + Vector2(-0.38, -0.5) * k)
	pts.append(c + Vector2(-0.12 + wob, -0.78) * k)
	pts.append(c + Vector2(0.02 + wob, -1.05) * k)
	pts.append(c + Vector2(0.22 + wob, -0.72) * k)
	pts.append(c + Vector2(0.45, -0.42) * k)
	pts.append(c + Vector2(0.58, -0.05) * k)
	ci.draw_colored_polygon(PackedVector2Array(Array(pts).map(func(v): return v + Vector2(2, 2))), Color(INK, 0.9))
	ci.draw_colored_polygon(pts, outer)
	ci.draw_polyline(pts + PackedVector2Array([pts[0]]), INK, maxf(1.5, k * 0.06), true)
	var inner_pts := PackedVector2Array()
	for p in pts:
		inner_pts.append(c + (p - c) * 0.5 + Vector2(0, 0.28 * k))
	ci.draw_colored_polygon(inner_pts, inner)
	if not alive:
		ci.draw_polyline(PackedVector2Array([c + Vector2(-0.1, -0.7) * k, c + Vector2(0.12, -0.25) * k, c + Vector2(-0.08, 0.1) * k,
			c + Vector2(0.1, 0.5) * k]), ACCENT, maxf(2.0, k * 0.07), true)

## A six-armed snowflake (streak freezes).
static func snowflake(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	for i in 6:
		var d := Vector2.from_angle(i * PI / 3.0 - PI * 0.5)
		ci.draw_line(c, c + d * r, col, maxf(2.0, r * 0.16), true)
		var m := c + d * r * 0.6
		ci.draw_line(m, m + d.rotated(0.8) * r * 0.3, col, maxf(1.5, r * 0.12), true)
		ci.draw_line(m, m + d.rotated(-0.8) * r * 0.3, col, maxf(1.5, r * 0.12), true)

## A coin and a price side by side, centred as a pair on `center` (so long
## prices never run into the coin).
static func price(ci: CanvasItem, center: Vector2, amount: int, size: int, alpha := 1.0, ink := INK) -> void:
	var s := commas(amount)
	var r := size * 0.5
	var gap := size * 0.3
	var w := text_width(num(800), s, size)
	var x0 := center.x - (r * 2.0 + gap + w) * 0.5
	coin(ci, Vector2(x0 + r, center.y), r, alpha)
	text(ci, num(800), s, Vector2(x0 + r * 2.0 + gap + w * 0.5, center.y - 1.0), size, Color(ink, alpha))

## 12000 -> "12,000".
static func commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

static func ease_back(t: float) -> float:
	var c := 1.70158
	return 1.0 + (c + 1.0) * pow(t - 1.0, 3.0) + c * pow(t - 1.0, 2.0)

static func ease_elastic(t: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return clampf(t, 0.0, 1.0)
	return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * TAU / 3.0) + 1.0

## Damien's drawings, loaded once and kept: works for files Godot has
## imported (the game on a phone) and for files just dropped into the folder
## while testing on the computer. null if there's no drawing yet.
static var _art_cache: Dictionary = {}

static func art(path: String) -> Texture2D:
	if not _art_cache.has(path):
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path)
		else:
			var disk := ProjectSettings.globalize_path(path)
			if FileAccess.file_exists(disk):
				var img := Image.load_from_file(disk)
				if img:
					tex = ImageTexture.create_from_image(img)
		_art_cache[path] = tex
	return _art_cache[path]

## The back of a face-down card, in the design the player picked in the shop.
## Everything stays inside r. ids: see Progress.CARD_BACKS. A drawing at
## art/backs/<id>.png replaces the printed pattern.
static func card_back(ci: CanvasItem, r: Rect2, id: String) -> void:
	var drawn := art("res://art/backs/%s.png" % id)
	if drawn:
		ci.draw_texture_rect(drawn, r, false)
		return
	match id:
		"tartan":
			ci.draw_rect(r, Color("2d5a3d"))
			for k in range(1, 4):
				var x := r.position.x + r.size.x * k / 4.0
				var y := r.position.y + r.size.y * k / 4.0
				ci.draw_rect(Rect2(Vector2(x - 5, r.position.y), Vector2(10, r.size.y)), Color("b8321f", 0.55))
				ci.draw_rect(Rect2(Vector2(r.position.x, y - 5), Vector2(r.size.x, 10)), Color("b8321f", 0.55))
				ci.draw_line(Vector2(x + 9, r.position.y), Vector2(x + 9, r.end.y), Color(COIN, 0.7), 1.5)
				ci.draw_line(Vector2(r.position.x, y + 9), Vector2(r.end.x, y + 9), Color(COIN, 0.7), 1.5)
			ci.draw_rect(r.grow(-5), Color(CARD, 0.5), false, 1.5)
		"lacquer":
			ci.draw_rect(r, Color("a82a1c"))
			var step := 16.0
			var x0 := r.position.x
			while x0 < r.end.x + r.size.y:
				ci.draw_line(_clip_pt(Vector2(x0, r.position.y), Vector2(x0 - r.size.y, r.end.y), r, true),
					_clip_pt(Vector2(x0, r.position.y), Vector2(x0 - r.size.y, r.end.y), r, false), Color(CARD, 0.18), 1.2)
				ci.draw_line(_clip_pt(Vector2(x0 - r.size.y, r.position.y), Vector2(x0, r.end.y), r, true),
					_clip_pt(Vector2(x0 - r.size.y, r.position.y), Vector2(x0, r.end.y), r, false), Color(CARD, 0.18), 1.2)
				x0 += step
			ci.draw_rect(r.grow(-6), Color(COIN, 0.85), false, 2.0)
			var c := r.get_center()
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14), c + Vector2(10, 0), c + Vector2(0, 14), c + Vector2(-10, 0)]),
				COIN)
		"navy":
			ci.draw_rect(r, Color("1d2b52"))
			var rows := int(r.size.y / 16.0)
			var cols := int(r.size.x / 16.0)
			for j in rows:
				for i in cols:
					if (i + j) % 2 == 0:
						var p := r.position + Vector2(8 + i * r.size.x / cols, 8 + j * r.size.y / rows)
						star(ci, p, 3.2, 1.3, Color(COIN, 0.75))
			ci.draw_rect(r.grow(-5), Color(COIN, 0.8), false, 1.5)
		"botanical":
			ci.draw_rect(r, Color("33503a"))
			var rng := RandomNumberGenerator.new()
			rng.seed = 42
			for n in int(r.size.x * r.size.y / 420.0):
				var p := r.position + Vector2(rng.randf_range(10, r.size.x - 10), rng.randf_range(10, r.size.y - 10))
				var a := rng.randf() * TAU
				var d := Vector2.from_angle(a) * 7.0
				var n2 := Vector2.from_angle(a + PI * 0.5) * 3.0
				ci.draw_colored_polygon(PackedVector2Array([p - d, p + n2, p + d, p - n2]), Color("9cc58a", 0.55))
			ci.draw_rect(r.grow(-5), Color(CARD, 0.55), false, 1.5)
		"ember":
			# Earned with a 30-day streak: rows of little flames on deep red.
			ci.draw_rect(r, Color("7a1f12"))
			var rows := int(r.size.y / 22.0)
			var cols := int(r.size.x / 22.0)
			for j in rows:
				for i in cols:
					var p := r.position + Vector2(11 + i * r.size.x / cols + (6.0 if j % 2 else 0.0), 13 + j * r.size.y / rows)
					var fl := PackedVector2Array([p + Vector2(0, -7), p + Vector2(4, 1), p + Vector2(2, 5), p + Vector2(-2, 5),
						p + Vector2(-4, 1)])
					ci.draw_colored_polygon(fl, Color(COIN, 0.7) if (i + j) % 2 == 0 else Color(ACCENT, 0.8))
			ci.draw_rect(r.grow(-5), Color(COIN, 0.8), false, 1.5)
		"gilt":
			ci.draw_rect(r, INK)
			for k in 3:
				ci.draw_rect(r.grow(-5.0 - k * 6.0), Color(COIN, 0.9 - k * 0.25), false, 1.5)
			var c := r.get_center()
			for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var p: Vector2 = c + Vector2((r.size.x * 0.5 - 12.0) * s.x, (r.size.y * 0.5 - 12.0) * s.y)
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), COIN)
			ci.draw_circle(c, 13.0, COIN)
			ci.draw_arc(c, 17.0, 0, TAU, 32, COIN, 1.5, true)
			star(ci, c, 8.0, 3.5, INK)
		_:
			ci.draw_rect(r, INK)
			hatch(ci, r.grow(-8), Color(PAPER, 0.22), 7.0, 1.2)
			ci.draw_rect(r.grow(-6), Color(PAPER, 0.35), false, 1.0)

## One end of the segment a-b clipped to the rectangle (cheap, for patterns).
static func _clip_pt(a: Vector2, b: Vector2, r: Rect2, first: bool) -> Vector2:
	# intersect keeps the part inside r (clip would keep the part outside).
	var pts := Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]),
		PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
	if pts.is_empty() or pts[0].size() < 2:
		return a if first else a
	return pts[0][0] if first else pts[0][-1]

## Booster icons (shop, pre-level panel): slot, xray, lucky, shield.
static func booster_icon(ci: CanvasItem, id: String, c: Vector2, col: Color) -> void:
	match id:
		"slot":
			var r := Rect2(c + Vector2(-14, -19), Vector2(28, 38))
			var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
			for k in 4:
				ci.draw_dashed_line(pts[k], pts[k + 1], col, 2.5, 5.0, true)
			ci.draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), col, 4.0)
			ci.draw_line(c + Vector2(0, -8), c + Vector2(0, 8), col, 4.0)
		"xray":
			ci.draw_rect(Rect2(c + Vector2(-11, -6), Vector2(22, 28)), Color(col, 0.25))
			ci.draw_rect(Rect2(c + Vector2(-11, -6), Vector2(22, 28)), col, false, 2.0)
			var pts := PackedVector2Array()
			for i in 17:
				var a := PI * i / 16.0
				pts.append(c + Vector2(cos(a) * 18.0, -8.0 - sin(a) * 9.0))
			for i in 17:
				var a := PI * i / 16.0
				pts.append(c + Vector2(-cos(a) * 18.0, -8.0 + sin(a) * 9.0))
			ci.draw_colored_polygon(pts, CARD)
			ci.draw_polyline(pts, col, 2.5, true)
			ci.draw_circle(c + Vector2(0, -8), 5.0, col)
		"lucky":
			coin(ci, c + Vector2(-6, 0), 15.0)
			text(ci, serif(800, 48), "×2", c + Vector2(13, 8), 17, col)
		"shield":
			var sh := PackedVector2Array([c + Vector2(0, -20), c + Vector2(16, -13), c + Vector2(14, 6), c + Vector2(0, 20),
				c + Vector2(-14, 6), c + Vector2(-16, -13)])
			ci.draw_colored_polygon(sh, CARD)
			ci.draw_polyline(sh + PackedVector2Array([sh[0]]), col, 2.5, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(7, 0), c + Vector2(0, 8), c + Vector2(-7, 0)]),
				ACCENT)
