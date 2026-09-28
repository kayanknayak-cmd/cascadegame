class_name CardView
extends Node2D
## One card on screen. `position` is the card's centre, so pops, tilts and
## flips all happen around the middle.
##
## Everything a card does is driven by code, with no drawn animation frames:
##   lift    - picked up: it grows a little and its shadow drops away
##   follow  - while dragged it trails the finger on a spring and leans into
##             the direction it's moving, like a real card held by a corner
##   fly     - moves along an arc, tilting mid-air, and squashes on landing
##   flip    - turns over with a lift, and a flash of light as the face appears
##   gold    - "this group is done": the group colour floods the card
##   sheen   - a band of light sweeps across the face
##
## Placeholder face: the group's colour band, the name (the part still
## visible in a pile) and a framed monogram where Damien's picture will go.

const SIZE := Vector2(124, 172)
const NAME_STRIP := 56.0


var card := -1
var label := ""
var kind := 0              ## 0 normal, 1 magnet, 2 bomb (see Cascade.Kind)
var band := Color(0, 0, 0, 0)  ## the group's colour; clear = no band
var group := -1                ## for the group's shape on the band
var rare := false              ## gold-edged rare group (hidden until it flips)
var iced := 0                  ## ice layers (0 = not frozen)
var chained := false
var wrapped := false           ## face hidden under gift paper until pulled
var peek_col := Color(0, 0, 0, 0)  ## face-down but "peeking": its colour band shows on the back
var peek_group := -1
var peek_mystery := false      ## a special or wrapped card underneath: a "?" band
var _twinkle := 0.0
var locked := 0                ## bursts still needed to open (0 = unlocked)
var golden := false            ## the golden-card surprise: a gold edge, its group pays a bonus
var unlock_t := -1.0           ## >= 0 while the padlock is springing off
var base_scale := 1.0      ## resting size; pops and squashes return here
var face_up := false
var rest_rotation := 0.0

var lift := 0.0            ## 0 on the table, 1 in the hand
var glow := 0.0            ## hint glow
var gold := 0.0            ## finished-group glow
var flash := 0.0           ## white flash on reveal
var shake := 0.0
var sheen := -1.0          ## -1 off, 0..1 sweeping

var dragging := false
var drag_target := Vector2.ZERO
var drag_stiffness := 26.0

var on_land: Callable      ## called once when the current flight lands

var _move: Tween
var _flip: Tween
var _fx: Tween

func _process(delta: float) -> void:
	var redraw := false
	if (rare and face_up or golden) and visible:
		_twinkle += delta
		redraw = true
	if dragging:
		var before := position
		position = position.lerp(drag_target, 1.0 - exp(-drag_stiffness * delta))
		var vx := (position.x - before.x) / maxf(delta, 0.001)
		var lean := clampf(vx * 0.00045, -0.28, 0.28)
		rotation = lerpf(rotation, lean, 1.0 - exp(-14.0 * delta))
	if shake > 0.0:
		shake = maxf(shake - delta * 2.6, 0.0)
		redraw = true
	if flash > 0.0:
		flash = maxf(flash - delta * 3.0, 0.0)
		redraw = true
	if unlock_t >= 0.0:
		unlock_t += delta * 2.2
		if unlock_t > 1.0:
			unlock_t = -1.0
		redraw = true
	if sheen >= 0.0:
		sheen += delta * 1.8
		if sheen > 1.0:
			sheen = -1.0
		redraw = true
	if redraw:
		queue_redraw()

# ---------------------------------------------------------------- drawing

## Damien's card drawings: art/cards/<card name>.png (e.g. "Spool of
## Thread.png"), 512 x 512 with a transparent background. Loaded once and
## kept. Works for files Godot has imported (the game on a phone) and for
## files just dropped into the folder while testing on the computer.
static func art_for(name: String) -> Texture2D:
	if name == "" or name == "?":
		return null
	return Style.art("res://art/cards/%s.png" % name)

## Printed card: paper face, ink border, the group's colour as a band across
## the top, the name in serif below it. The shadow is a hard ink offset that
## grows as the card lifts, like a card held above a printed page.
func _draw() -> void:
	var off := Vector2(sin(shake * 38.0) * 11.0 * shake, 0.0)
	var r := Rect2(off - SIZE * 0.5, SIZE)
	var sh := 4.0 + 10.0 * lift
	draw_style_box(Style.box(Color(Style.INK, 0.85 - 0.25 * lift), 4), Rect2(r.position + Vector2(sh, sh), r.size))
	if glow > 0.0 or gold > 0.0:
		var c := band if band.a > 0.0 else Style.ACCENT
		draw_style_box(Style.box(Color(0, 0, 0, 0), 6, Color(c, maxf(glow, gold)), 5), r.grow(7))
	if face_up:
		_draw_face(r)
	else:
		_draw_back(r)
	if golden:
		# A glowing gold edge and a little star that turns.
		var a := 0.75 + 0.25 * sin(_twinkle * 5.0)
		draw_style_box(Style.box(Color(0, 0, 0, 0), 5, Color(Style.COIN, a), 5), r.grow(3))
		Style.star(self, r.position + Vector2(r.size.x - 14, 14), 11.0, 5.0, Style.COIN, _twinkle)
	if flash > 0.0:
		draw_style_box(Style.box(Color(1, 1, 1, flash * 0.5), 4), r)

func _draw_face(r: Rect2) -> void:
	if kind != 0:
		_draw_special(r)
		return
	if wrapped:
		_draw_wrapped(r)
		if chained:
			_draw_chains(r)
		return
	var flood := gold
	var paper := Style.CARD.lerp(band, flood) if band.a > 0.0 else Style.CARD
	draw_style_box(Style.box(paper, 4, Style.INK, 2), r)
	var band_h := 16.0
	if band.a > 0.0:
		var br := Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, band_h))
		var bs := Style.box(band, 3)
		bs.corner_radius_bottom_left = 0
		bs.corner_radius_bottom_right = 0
		draw_style_box(bs, br)
		draw_line(Vector2(r.position.x + 2, br.end.y), Vector2(r.end.x - 2, br.end.y), Style.INK, 2.0)
		if group >= 0:
			var sym := Style.on_color(band)
			Style.group_symbol(self, group, Vector2(br.position.x + 12.0, br.get_center().y), 4.5, sym)
			Style.group_symbol(self, group, Vector2(br.end.x - 12.0, br.get_center().y), 4.5, sym)
	var ink := Style.on_color(band) if flood > 0.5 and band.a > 0.0 else Style.INK
	_draw_name(r, band_h, ink)
	var pic := Rect2(r.position + Vector2(12, NAME_STRIP + 8), Vector2(r.size.x - 24, r.size.y - NAME_STRIP - 20))
	draw_rect(pic, Color(ink, 0.25), false, 1.0)
	var art := CardView.art_for(label)
	if art:
		# Damien's drawing, fitted into the picture frame.
		var k := minf(pic.size.x / art.get_width(), pic.size.y / art.get_height())
		var sz := Vector2(art.get_width(), art.get_height()) * k
		draw_texture_rect(art, Rect2(pic.get_center() - sz * 0.5, sz), false)
	else:
		# Monogram stand-in for the drawing, tinted with the group colour.
		var initial := label.substr(0, 1).to_upper()
		var mono := Color(band if band.a > 0.0 else Style.INK, 0.45)
		if flood > 0.5:
			mono = Color(ink, 0.5)
		if group >= 0:
			# The group's shape, large and faint, behind the initial.
			Style.group_symbol(self, group, pic.get_center(), 26.0, Color(mono, 0.16))
		Style.text(self, Style.serif(400, 144), initial, pic.get_center() + Vector2(0, -2), 50, mono)
	if rare:
		_draw_rare(r)
	if iced > 0:
		_draw_ice(r)
	if chained:
		_draw_chains(r)
	if locked > 0 or unlock_t >= 0.0:
		_draw_lock(r)
	if sheen >= 0.0:
		_draw_sheen(r)

## Ice: a pale blue sheet over the face with frost streaks; the last layer
## shows cracks.
func _draw_ice(r: Rect2) -> void:
	var a := 0.62 if iced >= 2 else 0.42
	draw_style_box(Style.box(Color(0.72, 0.88, 0.98, a), 4, Color(1, 1, 1, 0.9), 3), r.grow(-1))
	for k in 5:
		var x := r.position.x + 14.0 + k * 22.0
		draw_line(Vector2(x, r.position.y + 10), Vector2(x - 26, r.position.y + 50), Color(1, 1, 1, 0.55), 2.0)
	draw_rect(r.grow(-6), Color(0.35, 0.62, 0.85, 0.6), false, 1.5)
	if iced == 1:
		var c := r.get_center() + Vector2(6, 10)
		var crack := PackedVector2Array([c + Vector2(-40, -30), c + Vector2(-14, -8), c + Vector2(-20, 12), c + Vector2(4, 22),
			c + Vector2(0, 50)])
		draw_polyline(crack, Color(0.2, 0.4, 0.6, 0.8), 2.0, true)
		draw_line(c + Vector2(-14, -8), c + Vector2(30, -26), Color(0.2, 0.4, 0.6, 0.8), 1.5)
	# A small snowflake badge in the corner.
	var b := r.position + Vector2(r.size.x - 18, 18)
	draw_circle(b, 12.0, Color(0.35, 0.62, 0.85))
	draw_arc(b, 12.0, 0, TAU, 20, Style.INK, 1.5, true)
	for k in 3:
		var d := Vector2.from_angle(k * PI / 3.0) * 8.0
		draw_line(b - d, b + d, Style.CARD, 2.0)
	if iced >= 2:
		Style.text(self, Style.sans(800), "2", b + Vector2(9, 11), 11, Style.INK)

## Chains: two lines of metal links crossing the card.
func _draw_chains(r: Rect2) -> void:
	var metal := Color("8a9099")
	for d in [[r.position + Vector2(6, 10), r.end - Vector2(6, 10)],
			[Vector2(r.end.x - 6, r.position.y + 10), Vector2(r.position.x + 6, r.end.y - 10)]]:
		var a: Vector2 = d[0]
		var b: Vector2 = d[1]
		var n := 8
		var dir := (b - a).normalized()
		var ang := dir.angle()
		for i in n:
			var c := a.lerp(b, (i + 0.5) / n)
			var along := i % 2 == 0
			var w := 17.0 if along else 13.0
			var h := 8.0 if along else 5.0
			draw_set_transform(c, ang if along else ang, Vector2.ONE)
			var rr := Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h))
			draw_style_box(Style.box(Color(0, 0, 0, 0), 4, Style.INK, 4), rr.grow(1.0))
			draw_style_box(Style.box(Color(0, 0, 0, 0), 4, metal, 2), rr)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Padlock-free clasp in the middle.
	var m := r.get_center()
	draw_circle(m + Vector2(2, 2), 9.0, Style.INK)
	draw_circle(m, 9.0, metal)
	draw_arc(m, 9.0, 0, TAU, 20, Style.INK, 1.5, true)

## Wrapped: gold gift paper hides the whole face (name and colour band too),
## tied with a red ribbon, with a "?" tag.
func _draw_wrapped(r: Rect2) -> void:
	draw_style_box(Style.box(Style.COIN, 4, Style.INK, 2), r)
	var stripe := Color(Style.CARD, 0.35)
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var pts := PackedVector2Array([Vector2(x, r.end.y), Vector2(x + 10, r.end.y), Vector2(x + 10 + r.size.y, r.position.y),
			Vector2(x + r.size.y, r.position.y)])
		var rect := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		for poly in Geometry2D.intersect_polygons(pts, rect):
			draw_colored_polygon(poly, stripe)
		x += 24.0
	var c := r.get_center()
	draw_rect(Rect2(Vector2(c.x - 7, r.position.y + 2), Vector2(14, r.size.y - 4)), Style.ACCENT)
	draw_rect(Rect2(Vector2(r.position.x + 2, c.y - 7), Vector2(r.size.x - 4, 14)), Style.ACCENT)
	for sd in [-1.0, 1.0]:
		var loop := PackedVector2Array([c, c + Vector2(sd * 22, -18), c + Vector2(sd * 26, -2), c])
		draw_colored_polygon(loop, Style.ACCENT)
		draw_polyline(loop, Style.INK, 1.5, true)
	draw_circle(c + Vector2(0, 30), 15.0, Style.CARD)
	draw_arc(c + Vector2(0, 30), 15.0, 0, TAU, 24, Style.INK, 1.5, true)
	Style.text(self, Style.serif(800, 48), "?", c + Vector2(0, 29), 22, Style.INK)
	draw_style_box(Style.box(Color(0, 0, 0, 0), 4, Style.INK, 2), r)

## Rare: a double gold frame, like a gilded picture frame, with little
## four-point glints that twinkle in turn around it.
func _draw_rare(r: Rect2) -> void:
	draw_style_box(Style.box(Color(0, 0, 0, 0), 4, Style.COIN, 5), r.grow(-1))
	draw_rect(r.grow(-8), Style.INK, false, 1.0)
	var spots := [r.position + Vector2(8, 8), Vector2(r.end.x - 8, r.position.y + 8), r.end - Vector2(8, 8),
		Vector2(r.position.x + 8, r.end.y - 8), Vector2(r.end.x - 4, r.get_center().y), Vector2(r.position.x + 4, r.get_center().y + 30)]
	for i in spots.size():
		var k := sin(_twinkle * 3.2 + i * 1.7)
		if k <= 0.2:
			continue
		var size := 5.0 + 9.0 * (k - 0.2)
		var c: Vector2 = spots[i]
		var pts := PackedVector2Array([c + Vector2(0, -size), c + Vector2(size * 0.22, -size * 0.22), c + Vector2(size, 0),
			c + Vector2(size * 0.22, size * 0.22), c + Vector2(0, size), c + Vector2(-size * 0.22, size * 0.22),
			c + Vector2(-size, 0), c + Vector2(-size * 0.22, -size * 0.22)])
		draw_colored_polygon(pts, Color(Style.CARD, k))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(Style.INK, k * 0.8), 1.2, true)

## A padlock with the number of bursts it still needs. On opening, the
## shackle springs up and the lock tumbles away.
func _draw_lock(r: Rect2) -> void:
	var t := unlock_t if unlock_t >= 0.0 else 0.0
	if locked > 0:
		Style.hatch(self, r.grow(-3), Color(Style.INK, 0.12), 7.0, 1.5)
	var c := r.get_center() + Vector2(0, 18) + Vector2(20.0 * t, 90.0 * t * t)
	var a := 1.0 - t
	var shackle := c + Vector2(0, -16 - 14.0 * minf(t * 4.0, 1.0))
	draw_arc(shackle, 13.0, PI, TAU, 16, Color(Style.INK, a), 5.0, true)
	draw_line(shackle + Vector2(-13, 0), shackle + Vector2(-13, 8), Color(Style.INK, a), 5.0)
	draw_line(shackle + Vector2(13, 0), shackle + Vector2(13, 8 if t > 0.0 else 16), Color(Style.INK, a), 5.0)
	var body := Rect2(c + Vector2(-22, -10), Vector2(44, 34))
	draw_rect(Rect2(body.position + Vector2(3, 3), body.size), Color(Style.INK, a))
	draw_rect(body, Color(Style.COIN, a))
	draw_rect(body, Color(Style.INK, a), false, 2.5)
	if locked > 0:
		Style.text(self, Style.serif(800, 72), str(locked), body.get_center() + Vector2(0, -1), 24, Style.INK)

## Magnet: paper card, a bold vermilion horseshoe. Bomb: ink card, paper bomb.
func _draw_special(r: Rect2) -> void:
	if kind == 3:
		_draw_wild(r)
		return
	if kind >= 4:
		_draw_new_special(r)
		return
	var magnet := kind == 1
	var fill := Style.CARD if magnet else Style.INK
	var ink := Style.INK if magnet else Style.CARD
	draw_style_box(Style.box(fill, 4, Style.INK, 2), r)
	Style.hatch(self, r.grow(-6), Color(ink, 0.08), 9.0, 1.5)
	var c := r.get_center() + Vector2(0, 14)
	if magnet:
		draw_arc(c + Vector2(0, -8), 30.0, 0.0, PI, 32, Style.ACCENT, 20.0, true)
		draw_rect(Rect2(c + Vector2(-40, -30), Vector2(20, 22)), Style.ACCENT)
		draw_rect(Rect2(c + Vector2(20, -30), Vector2(20, 22)), Style.ACCENT)
		draw_rect(Rect2(c + Vector2(-40, -44), Vector2(20, 14)), Style.INK)
		draw_rect(Rect2(c + Vector2(20, -44), Vector2(20, 14)), Style.INK)
	else:
		draw_circle(c + Vector2(0, 2), 28.0, Style.CARD)
		draw_circle(c + Vector2(-8, -6), 7.0, Color(Style.INK, 0.2))
		draw_rect(Rect2(c + Vector2(-7, -34), Vector2(14, 10)), Style.CARD)
		draw_line(c + Vector2(0, -34), c + Vector2(12, -48), Style.CARD, 3.0, true)
		Style.star(self, c + Vector2(15, -52), 10.0, 4.0, Style.ACCENT, maxf(sheen, 0.0) * 6.0)
	Style.caps(self, "Magnet" if magnet else "Bomb", Vector2(r.get_center().x, r.position.y + 24.0), 15, ink, 0.2)

## Colour bomb (4), Row (5) and Shuffle (6).
func _draw_new_special(r: Rect2) -> void:
	var c := r.get_center() + Vector2(0, 12)
	var spin := maxf(sheen, 0.0) * 2.0
	match kind:
		4:
			draw_style_box(Style.box(Style.INK, 4, Style.INK, 2), r)
			Style.hatch(self, r.grow(-6), Color(Style.CARD, 0.08), 9.0, 1.5)
			for i in 12:
				var a0 := spin + i * TAU / 12.0
				draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0) * 30.0,
					c + Vector2.from_angle(a0 + TAU / 12.0) * 30.0]), Style.GROUPS[i])
			draw_arc(c, 30.0, 0, TAU, 36, Style.CARD, 2.5, true)
			draw_circle(c + Vector2(-9, -9), 6.0, Color(1, 1, 1, 0.45))
			draw_rect(Rect2(c + Vector2(-6, -40), Vector2(12, 9)), Style.CARD)
			draw_line(c + Vector2(0, -40), c + Vector2(10, -52), Style.CARD, 3.0, true)
			Style.star(self, c + Vector2(13, -55), 9.0, 3.5, Style.COIN, spin * 3.0)
			Style.caps(self, "Colour", Vector2(r.get_center().x, r.position.y + 24.0), 15, Style.CARD, 0.2)
		5:
			draw_style_box(Style.box(Style.CARD, 4, Style.INK, 2), r)
			for k in 3:
				var cr := Rect2(c + Vector2(-44 + k * 30, -12), Vector2(24, 34))
				draw_rect(cr, Style.PAPER_DEEP)
				draw_rect(cr, Style.INK, false, 1.5)
			draw_line(c + Vector2(-50, -24), c + Vector2(50, -24), Style.ACCENT, 7.0)
			for sd in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([c + Vector2(sd * 58, -24), c + Vector2(sd * 44, -34),
					c + Vector2(sd * 44, -14)]), Style.ACCENT)
			Style.caps(self, "Row", Vector2(r.get_center().x, r.position.y + 24.0), 15, Style.INK, 0.2)
		_:
			draw_style_box(Style.box(Style.CARD, 4, Style.INK, 2), r)
			for sd in [-1.0, 1.0]:
				var col := Style.ACCENT if sd > 0 else Style.INK
				var pts := PackedVector2Array()
				for i in 13:
					var t := i / 12.0
					pts.append(c + Vector2(lerpf(-34, 30, t) * sd, -30 + 44 * t + sin(t * PI) * 10.0 * sd))
				draw_polyline(pts, col, 5.0, true)
				var tip := pts[-1]
				var d := (pts[-1] - pts[-3]).normalized()
				var nrm := Vector2(-d.y, d.x)
				draw_colored_polygon(PackedVector2Array([tip + d * 10, tip - d * 4 + nrm * 8, tip - d * 4 - nrm * 8]), col)
			Style.caps(self, "Shuffle", Vector2(r.get_center().x, r.position.y + 24.0), 15, Style.INK, 0.2)

## Wild: paper card with every group colour fanned out as rays from the middle.
func _draw_wild(r: Rect2) -> void:
	draw_style_box(Style.box(Style.CARD, 4, Style.INK, 2), r)
	var c := r.get_center() + Vector2(0, 12)
	var n := 12
	var spin := maxf(sheen, 0.0) * 1.5
	for i in n:
		var a0 := spin + i * TAU / n
		var a1 := a0 + TAU / n
		draw_colored_polygon(PackedVector2Array([c, c + Vector2.from_angle(a0) * 42.0, c + Vector2.from_angle(a1) * 42.0]),
			Style.GROUPS[i])
	draw_arc(c, 42.0, 0, TAU, 40, Style.INK, 2.0, true)
	draw_circle(c, 14.0, Style.CARD)
	draw_arc(c, 14.0, 0, TAU, 24, Style.INK, 2.0, true)
	Style.star(self, c, 9.0, 4.0, Style.INK)
	Style.caps(self, "Wild", Vector2(r.get_center().x, r.position.y + 24.0), 15, Style.INK, 0.2)

func _draw_name(r: Rect2, band_h: float, ink: Color) -> void:
	var f := Style.serif(600, 24)
	var width := SIZE.x - 14.0
	var strip := NAME_STRIP - band_h
	var sizes := [26, 24, 22, 20, 18, 16, 14] if Progress.large_text else [22, 20, 18, 16, 14]
	# In the tray, the next card covers everything under the first line, so
	# names shrink to fit on one line there (two only as a last resort).
	var in_tray := base_scale < 1.0
	if in_tray:
		sizes = [22, 20, 19, 18, 17, 16, 15, 14, 13, 12]
	for size in sizes:
		var lines := _wrap(f, label, width, size)
		if in_tray and lines.size() > 1 and size > 12:
			continue
		if lines.size() <= 2:
			var line_h := float(size) * 0.98
			var mid := r.position.y + band_h + strip * 0.5 + (4.0 if lines.size() == 1 else 2.0)
			for i in lines.size():
				var y := mid + (i - (lines.size() - 1) * 0.5) * line_h
				Style.text(self, f, lines[i], Vector2(r.get_center().x, y), size, ink, 0, Style.INK, false, 0.0, true)
			return

## One line if it fits; otherwise the two-line split whose longer line is
## shortest, so "Spool of / Thread" beats "Spool / of Thread". Returns three
## lines (too many) when nothing fits at this size, so the caller shrinks.
func _wrap(f: Font, s: String, width: float, size: int) -> PackedStringArray:
	if Style.text_width(f, s, size) <= width:
		return PackedStringArray([s])
	var words := s.split(" ")
	var best := PackedStringArray(["", "", ""])
	var best_w := INF
	for cut in range(1, words.size()):
		var a := " ".join(words.slice(0, cut))
		var b := " ".join(words.slice(cut))
		var w := maxf(Style.text_width(f, a, size), Style.text_width(f, b, size))
		if w <= width and w < best_w:
			best_w = w
			best = PackedStringArray([a, b])
	return best

## Ink back with fine paper hatching and a thin inner frame.
func _draw_back(r: Rect2) -> void:
	Style.card_back(self, r, Progress.card_back)
	draw_rect(r, Style.INK, false, 2.0)
	# The card under the top one shows its colour along its top edge, so
	# players can plan chains (specials and wrapped cards stay a mystery).
	if peek_col.a > 0.0 or peek_mystery:
		var band := Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 16))
		if peek_mystery:
			draw_rect(band, Style.INK)
			Style.hatch(self, band, Color(Style.COIN, 0.5), 5.0, 1.2)
			Style.text(self, Style.serif(800, 48), "?", band.get_center() + Vector2(0, -1), 14, Style.COIN)
		else:
			draw_rect(band, peek_col)
			if peek_group >= 0:
				var sym := Style.on_color(peek_col)
				for x in [band.position.x + 12.0, band.get_center().x, band.end.x - 12.0]:
					Style.group_symbol(self, peek_group, Vector2(x, band.get_center().y), 5.0, sym)
		draw_rect(band, Style.INK, false, 1.5)

## A slanted band of light, trimmed to the card's outline.
func _draw_sheen(r: Rect2) -> void:
	var x := lerpf(r.position.x - 90.0, r.end.x + 30.0, sheen)
	var bandpoly := PackedVector2Array([Vector2(x, r.end.y), Vector2(x + 36, r.end.y),
		Vector2(x + 96, r.position.y), Vector2(x + 60, r.position.y)])
	var rect := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	for poly in Geometry2D.intersect_polygons(bandpoly, rect):
		draw_colored_polygon(poly, Color(1, 1, 1, 0.45 * sin(sheen * PI)))

# ---------------------------------------------------------------- motion

func snap_to(target: Vector2) -> void:
	_kill_move()
	position = target
	rotation = rest_rotation

## Fly to `target`. arc > 0 bows the path upward by that many pixels.
func move_to(target: Vector2, duration := 0.2, delay := 0.0, arc := 0.0, squash := true) -> void:
	_kill_move()
	if position.distance_to(target) < 0.5 and delay <= 0.0:
		position = target
		rotation = rest_rotation
		_landed(false)
		return
	var from := position
	var tilt := clampf((target.x - from.x) / 700.0, -0.3, 0.3)
	_move = create_tween()
	if delay > 0.0:
		_move.tween_interval(delay)
	_move.tween_method(func(t: float):
		var e := 1.0 - pow(1.0 - t, 3.0)
		position = from.lerp(target, e) + Vector2(0, -arc * sin(t * PI))
		rotation = lerpf(rotation, rest_rotation + tilt * sin(t * PI), 0.5),
		0.0, 1.0, duration)
	_move.tween_callback(_landed.bind(squash))

func _landed(squash: bool) -> void:
	rotation = rest_rotation
	if squash:
		var t := create_tween()
		t.tween_property(self, "scale", Vector2(1.07, 0.93) * base_scale, 0.05)
		t.tween_property(self, "scale", Vector2.ONE * base_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if on_land.is_valid():
		var cb := on_land
		on_land = Callable()
		cb.call()

func _kill_move() -> void:
	if _move and _move.is_valid():
		_move.kill()

## Pick up: grow, drop the shadow away, and start following the finger.
func grab() -> void:
	_kill_move()
	dragging = true
	drag_target = position
	_tween_fx("lift", 1.0, 0.12)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * 1.08 * base_scale, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func release() -> void:
	dragging = false
	_tween_fx("lift", 0.0, 0.18)
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * base_scale, 0.15)

func _tween_fx(prop: String, value: float, dur: float) -> void:
	if _fx and _fx.is_valid():
		_fx.kill()
	_fx = create_tween()
	_fx.tween_method(func(v: float):
		set(prop, v)
		queue_redraw(), get(prop), value, dur)

func flip_up(delay := 0.0) -> void:
	if face_up and not (_flip and _flip.is_valid()):
		return
	if _flip and _flip.is_valid():
		_flip.kill()
	_flip = create_tween()
	if delay > 0.0:
		_flip.tween_interval(delay)
	_flip.set_parallel(true)
	_flip.tween_property(self, "scale", Vector2(0.0, 1.08 * base_scale), 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_flip.tween_method(func(v: float):
		lift = v
		queue_redraw(), 0.0, 0.6, 0.1)
	_flip.set_parallel(false)
	_flip.tween_callback(func():
		face_up = true
		flash = 1.0
		Audio.flip()
		queue_redraw())
	_flip.set_parallel(true)
	_flip.tween_property(self, "scale", Vector2.ONE * base_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flip.tween_method(func(v: float):
		lift = v
		queue_redraw(), 0.6, 0.0, 0.22)

func set_face(up: bool) -> void:
	if _flip and _flip.is_valid():
		_flip.kill()
	face_up = up
	scale = Vector2.ONE * base_scale
	queue_redraw()

func pop(amount := 0.12) -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * (1.0 + amount) * base_scale, 0.07)
	t.tween_property(self, "scale", Vector2.ONE * base_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_glow(v: float) -> void:
	glow = v
	queue_redraw()

func set_gold(v: float) -> void:
	gold = v
	queue_redraw()

func start_shake() -> void:
	shake = 1.0
	queue_redraw()

func start_sheen() -> void:
	sheen = 0.0

func reset_look() -> void:
	glow = 0.0
	gold = 0.0
	flash = 0.0
	lift = 0.0
	shake = 0.0
	sheen = -1.0
	dragging = false
	scale = Vector2.ONE * base_scale
	modulate = Color.WHITE
	visible = true
	queue_redraw()
