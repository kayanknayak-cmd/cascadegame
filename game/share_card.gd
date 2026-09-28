class_name ShareCard
extends Node2D
## A picture of one finished level, made to be shared: printed paper, the
## game's name, which level (or which day's daily), your stars, the groups
## as coloured squares in the order you burst them, and how many taps.
##
##   info = {badge, stars, taps, order: [group index...]}
##
## render() draws it off-screen and returns the Image (1080 x 1350, the
## portrait size social apps like).

const SIZE := Vector2(1080, 1350)

var info: Dictionary = {}

static func render(host: Node, data: Dictionary) -> Image:
	# With no screen (the headless test run) nothing ever gets drawn, so
	# waiting for a frame would hang: hand back a blank sheet instead.
	if DisplayServer.get_name() == "headless":
		var blank := Image.create(int(SIZE.x), int(SIZE.y), false, Image.FORMAT_RGBA8)
		blank.fill(Style.PAPER)
		return blank
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var card := ShareCard.new()
	card.info = data
	vp.add_child(card)
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img

func _draw() -> void:
	var c := SIZE.x * 0.5
	draw_rect(Rect2(Vector2.ZERO, SIZE), Style.PAPER)
	# A strip of every group colour across the top, like a printed masthead.
	var n := Style.GROUPS.size()
	for i in n:
		draw_rect(Rect2(Vector2(SIZE.x * i / n, 0), Vector2(SIZE.x / n + 1, 26)), Style.GROUPS[i])
	draw_line(Vector2(0, 26), Vector2(SIZE.x, 26), Style.INK, 4.0)
	# The card itself.
	var r := Rect2(Vector2(90, 120), Vector2(SIZE.x - 180, SIZE.y - 250))
	draw_rect(Rect2(r.position + Vector2(16, 16), r.size), Style.INK)
	draw_rect(r, Style.CARD)
	draw_rect(r, Style.INK, false, 5.0)
	Style.hatch(self, Rect2(r.position + Vector2(18, 18), Vector2(r.size.x - 36, 22)), Color(Style.INK, 0.25), 9.0, 2.0)
	Style.text(self, Style.serif(800, 144), "Cascade", Vector2(c, r.position.y + 150), 132, Style.INK)
	# Badge: "Level 42" or "Daily · Sep 25".
	var badge := String(info.get("badge", ""))
	var bw := Style.caps_width(badge, 34, 0.2) + 80.0
	var br := Rect2(Vector2(c - bw * 0.5, r.position.y + 250), Vector2(bw, 76))
	draw_rect(Rect2(br.position + Vector2(7, 7), br.size), Style.INK)
	draw_rect(br, Style.COIN)
	draw_rect(br, Style.INK, false, 4.0)
	Style.caps(self, badge, br.get_center(), 34, Style.INK, 0.2)
	# Stars.
	var got := int(info.get("stars", 0))
	for k in 3:
		var sp := Vector2(c + (k - 1) * 150.0, r.position.y + 470 - (24.0 if k == 1 else 0.0))
		Style.fancy_star(self, sp, 62.0, 1.0 if k < got else 0.0)
	# The groups, as squares, in the order they burst.
	var order: Array = info.get("order", [])
	var per_row := mini(maxi(order.size(), 1), 6)
	var sq := 104.0
	var gap := 22.0
	var rows := ceili(float(order.size()) / per_row)
	var y0 := r.position.y + 620.0
	for i in order.size():
		var row := i / per_row
		var in_row := mini(per_row, order.size() - row * per_row)
		var x0 := c - (in_row * sq + (in_row - 1) * gap) * 0.5
		var p := Vector2(x0 + (i % per_row) * (sq + gap), y0 + row * (sq + gap))
		var g := int(order[i])
		var col := Style.group_color(g)
		draw_rect(Rect2(p + Vector2(7, 7), Vector2(sq, sq)), Style.INK)
		draw_rect(Rect2(p, Vector2(sq, sq)), col)
		draw_rect(Rect2(p, Vector2(sq, sq)), Style.INK, false, 4.0)
		Style.group_symbol(self, g, p + Vector2(sq, sq) * 0.5, 26.0, Style.on_color(col))
	# Taps.
	var ty := y0 + rows * (sq + gap) + 70.0
	Style.text(self, Style.serif(700, 72), "Solved in %d taps" % int(info.get("taps", 0)), Vector2(c, ty), 58, Style.INK)
	Style.caps(self, "Tap. Chain. Burst.", Vector2(c, r.end.y - 60.0), 26, Color(Style.INK, 0.55), 0.3)
