class_name PillButton
extends Control
## A printed button: a flat rectangle with an ink border sitting on a hard ink
## shadow. Pressing pushes it down into its shadow, like a real key.
## primary = ink fill with paper letters; otherwise paper fill with ink letters.
## An optional badge in the corner shows a count (like "3 hints left").

signal pressed

@export var text := ""
@export var primary := false
@export var font_size := 16
var face := Color(0, 0, 0, 0)   ## optional override fill colour
var badge := -1                 ## -1 = no badge
var icon := ""                  ## "undo" | "peek" | "hint": drawn instead of the text
var price := -1                 ## coins, shown beside the icon when it costs something
var corner_tag := ""
var ad := false                 ## a rewarded-ad button: a small play badge in the corner                   ## a small label on the top-left corner ("Boss", "Hard")
var disabled := false:
	set(v):
		disabled = v
		queue_redraw()
var bob_enabled := false        ## gentle breathing, for the button you want pressed

# Unused by this style; kept so older callers still work.
var lip := Color.BLACK
var ink := Color.BLACK

var _down := false
var _press := 0.0
var _bob := 0.0
var _spring := 0.0              ## 1 -> 0 after letting go

const SHADOW := 5.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func _ready() -> void:
	resized.connect(func(): pivot_offset = size * 0.5)
	pivot_offset = size * 0.5

func _process(delta: float) -> void:
	_press = move_toward(_press, 1.0 if _down else 0.0, delta * 18.0)
	var s := 1.0
	if bob_enabled:
		_bob += delta
		s = 1.0 + 0.03 * sin(_bob * 4.5)
	if _spring > 0.0:
		# Let go: a small springy bounce back up.
		_spring = maxf(_spring - delta * 3.0, 0.0)
		s *= 1.0 + 0.07 * sin((1.0 - _spring) * PI * 2.5) * _spring
	if bob_enabled or _spring > 0.0:
		scale = Vector2(s, s)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			Audio.button()
			if Progress.haptics and OS.has_feature("mobile"):
				Input.vibrate_handheld(8, 0.3)
		elif _down:
			_down = false
			_spring = 1.0
			if Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
		accept_event()

func _draw() -> void:
	# Disabled: still a solid printed button (not a see-through grey block),
	# just pale and pressed flat, with faded ink.
	var alpha := 0.3 if disabled else 1.0
	var sink := SHADOW * (0.6 if disabled else _press)
	var body := Rect2(Vector2(sink, sink), size - Vector2(SHADOW, SHADOW))
	draw_style_box(Style.box(Color(Style.INK, 0.25 if disabled else 1.0), 3), Rect2(Vector2(SHADOW, SHADOW), size - Vector2(SHADOW, SHADOW)))
	var fill := face if face.a > 0.0 else (Style.INK if primary else Style.CARD)
	if disabled:
		fill = Style.PAPER_DEEP
	var letters := Style.on_color(fill) if face.a > 0.0 else (Style.CARD if primary and not disabled else Style.INK)
	draw_style_box(Style.box(fill, 3, Color(Style.INK, 0.4 if disabled else 1.0), 2), body)
	if icon != "":
		var ic := Color(letters, alpha)
		var cx := body.get_center() + Vector2(-(18.0 + minf(size.x * 0.12, 26.0)) if price >= 0 else 0.0, 0)
		_draw_icon(icon, cx, ic)
		if price >= 0:
			# The coin and the price as a pair (with commas), right of the icon.
			var pw := 22.0 + 6.0 + Style.text_width(Style.num(800), Style.commas(price), 20)
			Style.price(self, Vector2(cx.x + 24.0 + pw * 0.5, body.get_center().y), price, 20, alpha, letters)
		_draw_badge(alpha)
		_draw_ad(alpha)
		return
	var lines := text.split("\n")
	for i in lines.size():
		var y := body.get_center().y + (i - (lines.size() - 1) * 0.5) * font_size * 1.3
		Style.caps(self, lines[i], Vector2(body.get_center().x, y), font_size, Color(letters, alpha), 0.16)
	_draw_badge(alpha)
	_draw_tag(alpha)
	_draw_ad(alpha)

func _draw_icon(kind: String, c: Vector2, col: Color) -> void:
	match kind:
		"undo":
			draw_arc(c + Vector2(2, 2), 13.0, PI * 1.1, PI * 2.4, 20, col, 4.0, true)
			var tip := c + Vector2(2, 2) + Vector2.from_angle(PI * 1.1) * 13.0
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-8, -2), tip + Vector2(6, -8), tip + Vector2(4, 8)]), col)
		"peek":
			var pts := PackedVector2Array()
			for i in 17:
				var a := PI * i / 16.0
				pts.append(c + Vector2(cos(a) * 20.0, -sin(a) * 11.0))
			for i in 17:
				var a := PI * i / 16.0
				pts.append(c + Vector2(-cos(a) * 20.0, sin(a) * 11.0))
			pts.append(pts[0])
			draw_polyline(pts, col, 3.0, true)
			draw_circle(c, 6.0, col)
		"daily":
			# A tear-off calendar page with today's date block.
			var r := Rect2(c + Vector2(-17, -15), Vector2(34, 32))
			draw_rect(r, col, false, 3.0)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 9)), col)
			for x in [-8.0, 8.0]:
				draw_line(c + Vector2(x, -20), c + Vector2(x, -12), col, 3.0)
			draw_rect(Rect2(c + Vector2(-4, 0), Vector2(9, 9)), col)
		"events":
			# A pennant on a pole.
			draw_line(c + Vector2(-12, -18), c + Vector2(-12, 20), col, 3.5)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-11, -18), c + Vector2(16, -10), c + Vector2(-11, -1)]), col)
			draw_line(c + Vector2(-18, 20), c + Vector2(-6, 20), col, 3.0)
		"double":
			Style.booster_icon(self, "lucky", c, col)
		"freeze":
			Style.snowflake(self, c, 15.0, col if disabled else Color("4f7fb0"))
		"vacation":
			# A suitcase.
			var sr := Rect2(c + Vector2(-16, -9), Vector2(32, 23))
			draw_rect(sr, col, false, 3.0)
			draw_rect(Rect2(c + Vector2(-6, -15), Vector2(12, 6)), col, false, 2.5)
			draw_line(c + Vector2(-16, 1), c + Vector2(16, 1), col, 2.0)
		"flame":
			Style.flame(self, c + Vector2(0, 4), 18.0, 7, not disabled)
		"map":
			# A folded map with a pin.
			var fold := PackedVector2Array([c + Vector2(-17, -12), c + Vector2(-6, -16), c + Vector2(6, -12), c + Vector2(17, -16),
				c + Vector2(17, 12), c + Vector2(6, 16), c + Vector2(-6, 12), c + Vector2(-17, 16)])
			draw_polyline(fold + PackedVector2Array([fold[0]]), col, 3.0, true)
			draw_line(c + Vector2(-6, -16), c + Vector2(-6, 12), col, 2.0)
			draw_line(c + Vector2(6, -12), c + Vector2(6, 16), col, 2.0)
			draw_circle(c + Vector2(11, -3), 3.5, Style.ACCENT)
		"share":
			# A box with an arrow leaving it.
			draw_polyline(PackedVector2Array([c + Vector2(-8, -6), c + Vector2(-14, -6), c + Vector2(-14, 16), c + Vector2(14, 16),
				c + Vector2(14, -6), c + Vector2(8, -6)]), col, 3.0, true)
			draw_line(c + Vector2(0, 6), c + Vector2(0, -18), col, 3.0)
			draw_polyline(PackedVector2Array([c + Vector2(-7, -11), c + Vector2(0, -18), c + Vector2(7, -11)]), col, 3.0, true)
		"slot":
			# One more tray slot: a dashed card with a plus.
			var r := Rect2(c + Vector2(-13, -18), Vector2(26, 36))
			var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
			for k in 4:
				draw_dashed_line(pts[k], pts[k + 1], col, 2.5, 5.0, true)
			draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), col, 3.5)
			draw_line(c + Vector2(0, -7), c + Vector2(0, 7), col, 3.5)
		"hint":
			draw_circle(c + Vector2(0, -4), 11.0, col)
			draw_rect(Rect2(c + Vector2(-6, 6), Vector2(12, 8)), col)
			draw_line(c + Vector2(-5, 17), c + Vector2(5, 17), col, 3.0)
			for k in 3:
				var a := -PI * 0.5 + (k - 1) * 0.7
				draw_line(c + Vector2(0, -4) + Vector2.from_angle(a) * 15.0, c + Vector2(0, -4) + Vector2.from_angle(a) * 20.0, col, 2.5)

## "Watch an ad": a small play button in the top-left corner.
func _draw_ad(alpha: float) -> void:
	if not ad:
		return
	var c := Vector2(10.0, 4.0)
	draw_circle(c + Vector2(2, 2), 14.0, Color(Style.INK, alpha))
	draw_circle(c, 14.0, Color(Style.COIN, alpha))
	draw_arc(c, 14.0, 0, TAU, 24, Color(Style.INK, alpha), 2.0, true)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -7), c + Vector2(7, 0), c + Vector2(-4, 7)]), Color(Style.INK, alpha))

func _draw_tag(alpha: float) -> void:
	if corner_tag == "":
		return
	var boss := corner_tag == "Boss"
	var tw := Style.caps_width(corner_tag, 12, 0.14) + 20.0 + (26.0 if boss else 0.0)
	draw_set_transform(Vector2(18, 0), -0.06, Vector2.ONE)
	var r := Rect2(Vector2(0, -12), Vector2(tw, 24))
	draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(Style.INK, alpha))
	draw_rect(r, Color(Style.COIN if boss else Style.ACCENT, alpha))
	draw_rect(r, Color(Style.INK, alpha), false, 2.0)
	var tx := r.get_center().x + (12.0 if boss else 0.0)
	if boss:
		var b := Vector2(r.position.x + 18.0, 5.0)
		var pts := PackedVector2Array([b + Vector2(-10, 0), b + Vector2(-12, -11), b + Vector2(-5, -6), b + Vector2(0, -13),
			b + Vector2(5, -6), b + Vector2(12, -11), b + Vector2(10, 0)])
		draw_colored_polygon(pts, Color(Style.CARD, alpha))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(Style.INK, alpha), 1.5, true)
	Style.caps(self, corner_tag, Vector2(tx, 0), 12, Color(Style.INK if boss else Style.CARD, alpha), 0.14)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_badge(alpha: float) -> void:
	if badge >= 0:
		var c := Vector2(size.x - SHADOW - 4.0, 2.0)
		draw_circle(c + Vector2(2.5, 2.5), 15.0, Color(Style.INK, alpha))
		draw_circle(c, 15.0, Color(Style.ACCENT if badge > 0 else Style.PAPER_DEEP, alpha))
		draw_arc(c, 15.0, 0, TAU, 28, Color(Style.INK, alpha), 2.0, true)
		Style.text(self, Style.sans(800), str(badge), c + Vector2(0, -1), 16,
			Color(Style.CARD if badge > 0 else Style.INK, alpha))
