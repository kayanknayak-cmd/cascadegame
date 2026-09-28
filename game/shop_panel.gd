class_name ShopPanel
extends Node2D
## The coin shop, full screen. It slides up over the map and back down.
## Every price is shown plainly and every item is exactly what it says.
##
##   boosters   - four big printed cards in a 2×2 grid: a large icon, the
##                name, a few words, how many you own, and a gold price
##                button that presses in (grey when you can't afford it).
##   card backs - a fan you swipe through (or tap a side card to bring it
##                forward). The front card turns over as it arrives; below it,
##                its name and a button to buy it or put it on.
## Buying: coins fly from the counter into the item and a "Bought" stamp
## thumps down on it.

signal closed
signal bought(amount: int, at: Vector2)

const ORDER := ["slot", "xray", "lucky", "shield"]
const NAMES := {"slot": "Extra slot", "xray": "X-ray", "lucky": "Lucky coins", "shield": "Streak shield"}
const WORDS := {"slot": "One more tray slot", "xray": "See two cards deep", "lucky": "Double a level's coins",
	"shield": "Keeps your streak once"}
## (Lucky coins doubles every coin earned in the level, not just the win.)
const BACK_NAMES := {"ink": "Ink", "tartan": "Tartan", "lacquer": "Lacquer", "navy": "Starry", "botanical": "Garden",
	"gilt": "Gilt", "ember": "Ember"}
## Each booster card's colour band.
const BANDS := {"slot": 1, "xray": 6, "lucky": 3, "shield": 0}
const BACK_SIZE := Vector2(104, 140)

var W := 720.0
var H := 1280.0
var ox := 0.0
var top := 0.0
var coins_shown := 0
var _age := 0.0
var _out := -1.0              ## -1 while open; 0..1 while sliding away
var _shake := {}              ## item key -> 0..1 wiggle ("can't afford")
var _flash := {}              ## item key -> 0..1 glow (just bought)
var _stamp := {}              ## item key -> 0..1 the "Bought" stamp thumping down
var _press := ""              ## the button under the finger
var _warn := 0.0              ## the coin counter shakes red
var _coin_flights: Array = [] ## [from, to, age]: coins flying from the counter into an item

## The fan of card backs.
var _sel := 0                 ## the card at the front
var _fan := 0.0               ## where the fan is drawn (glides to _sel)
var _flip := 1.0              ## 0..1 the front card turning over as it arrives
var _drag_x := -1.0           ## finger x at the start of a swipe (-1 = none)
var _drag_dx := 0.0

## Call when the shop opens: it slides in fresh, the fan on the back in use.
func reset() -> void:
	_age = 0.0
	_out = -1.0
	_press = ""
	for i in Progress.shop_backs().size():
		if Progress.shop_backs()[i][0] == Progress.card_back:
			_sel = i
	_fan = float(_sel)
	_flip = 1.0

func _process(delta: float) -> void:
	_age += delta
	for d in [_shake, _flash]:
		for k in d.keys():
			d[k] = maxf(float(d[k]) - delta * 2.5, 0.0)
	for k in _stamp.keys():
		_stamp[k] = maxf(float(_stamp[k]) - delta * 1.6, 0.0)
	_warn = maxf(_warn - delta * 1.5, 0.0)
	if _drag_x < 0.0:
		_fan = lerpf(_fan, float(_sel), 1.0 - exp(-12.0 * delta))
	if _flip < 1.0:
		_flip = minf(_flip + delta * 3.2, 1.0)
	for f in _coin_flights:
		f[2] += delta
	_coin_flights = _coin_flights.filter(func(f): return f[2] < 0.55)
	if _out >= 0.0:
		_out += delta / 0.28
		if _out >= 1.0:
			_out = -1.0
			closed.emit()
	queue_redraw()

# ---------------------------------------------------------------- layout

func _close_rect() -> Rect2:
	return Rect2(Vector2(ox + 22.0, top + 22.0), Vector2(56, 56))

func _counter_pos() -> Vector2:
	return Vector2(ox + W - 150.0, top + 50.0)

func _card_rect(i: int) -> Rect2:
	var size := Vector2((W - 64.0 - 24.0) * 0.5, 280.0)
	return Rect2(Vector2(ox + 32.0 + (i % 2) * (size.x + 24.0), top + 158.0 + (i / 2) * (size.y + 22.0)), size)

func _buy_rect(i: int) -> Rect2:
	var r := _card_rect(i)
	return Rect2(Vector2(r.position.x + 20.0, r.end.y - 72.0), Vector2(r.size.x - 44.0, 54.0))

func _backs_title_y() -> float:
	return _card_rect(3).end.y + 44.0

func _fan_center() -> Vector2:
	# On taller phones the fan moves down into the extra space.
	var y := _backs_title_y()
	return Vector2(ox + W * 0.5, y + maxf(215.0, (H - y) * 0.45))

## Where card back i sits in the fan: [position, turn, size].
func _fan_slot(i: int) -> Array:
	var d := float(i) - _fan
	var ad := absf(d)
	var c := _fan_center() + Vector2(d * 175.0 - signf(d) * maxf(ad - 1.0, 0.0) * 55.0, ad * ad * 12.0)
	return [c, d * 0.12, 1.6 - 0.5 * minf(ad, 1.0) - 0.2 * maxf(ad - 1.0, 0.0)]

func _back_button_rect() -> Rect2:
	var c := _fan_center()
	return Rect2(Vector2(c.x - 130.0, c.y + 158.0), Vector2(260, 60))

## The shop's own offset while sliding in or out.
func _y_shift() -> float:
	if _out >= 0.0:
		return H * _out * _out
	return H * (1.0 - Style.ease_back(clampf(_age / 0.4, 0.0, 1.0)))

# ---------------------------------------------------------------- input

func handle(event: InputEvent) -> void:
	if _out >= 0.0 or _age < 0.2:
		return
	if event is InputEventMouseMotion and _drag_x >= 0.0:
		_drag_dx = event.position.x - _drag_x
		# The fan follows the finger while swiping.
		_fan = clampf(float(_sel) - _drag_dx / 175.0, -0.4, Progress.shop_backs().size() - 0.6)
		if absf(_drag_dx) > 40.0:
			_press = ""
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = event.position
	if event.pressed:
		_press = _hit(p)
		_drag_x = p.x if absf(p.y - _fan_center().y) < 140.0 else -1.0
		_drag_dx = 0.0
		return
	# Let go.
	var was := _press
	_press = ""
	if _drag_x >= 0.0:
		_drag_x = -1.0
		if absf(_drag_dx) > 40.0:
			# A swipe: the fan moves by one or more cards.
			var steps := clampi(-roundi(_drag_dx / 175.0), -3, 3)
			if steps == 0:
				steps = -1 if _drag_dx > 0.0 else 1
			_pick(_sel + steps)
			return
	if was == "" or was != _hit(p):
		return
	if was == "close":
		close()
	elif was.begins_with("buy:"):
		_buy_booster(int(was.substr(4)))
	elif was.begins_with("fan:"):
		if int(was.substr(4)) == _sel:
			_buy_back()
		else:
			_pick(int(was.substr(4)))
	elif was == "back":
		_buy_back()

## What's at p: "close", "buy:<i>", "fan:<i>", "back" or "".
func _hit(p: Vector2) -> String:
	if _close_rect().grow(22).has_point(p):
		return "close"
	for i in ORDER.size():
		if _card_rect(i).grow(6).has_point(p):
			return "buy:%d" % i
	if _back_button_rect().grow(8).has_point(p):
		return "back"
	# Front card first, then the ones beside it.
	var order := range(Progress.shop_backs().size())
	order.sort_custom(func(a, b): return absf(a - _fan) < absf(b - _fan))
	for i in order:
		var s: Array = _fan_slot(i)
		var half := BACK_SIZE * 0.5 * float(s[2])
		if Rect2(s[0] - half, half * 2.0).has_point(p):
			return "fan:%d" % i
	return ""

func close() -> void:
	if _out < 0.0:
		_out = 0.0
		Audio.panel_out()

func _pick(i: int) -> void:
	i = clampi(i, 0, Progress.shop_backs().size() - 1)
	if i == _sel:
		_fan = float(_sel)
		return
	_sel = i
	_flip = 0.0
	Audio.flip()

func _buy_booster(i: int) -> void:
	var id: String = ORDER[i]
	if Progress.buy_booster(id):
		_bought(id, _card_rect(i).get_center(), int(Progress.BOOSTERS[id].price))
	else:
		_poor(id)

func _buy_back() -> void:
	var id: String = Progress.shop_backs()[_sel][0]
	if Progress.card_back == id:
		return
	var had := Progress.owns_back(id)
	if Progress.choose_back(id):
		_flash[id] = 1.0
		_flip = 0.0
		Audio.flip()
		if not had:
			_bought(id, _fan_center(), Progress.back_price(id))
	else:
		_poor(id)

func _bought(id: String, at: Vector2, price: int) -> void:
	_flash[id] = 1.0
	_stamp[id] = 1.0
	Audio.purchase()
	for k in 6:
		_coin_flights.append([_counter_pos(), at + Vector2(randf_range(-40, 40), randf_range(-30, 30)), -k * 0.04])
	bought.emit(price, at)

func _poor(id: String) -> void:
	_shake[id] = 1.0
	_warn = 1.0
	Audio.wrong()

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var ys := _y_shift()
	draw_set_transform(Vector2(0, ys), 0.0, Vector2.ONE)
	draw_rect(Rect2(Vector2(-4000, -40), Vector2(8000, 8000)), Style.PAPER)
	draw_line(Vector2(-4000, -40), Vector2(4000, -40), Style.INK, 3.0)
	# Top: close, title, coins.
	var cr := _close_rect()
	var down := 3.0 if _press == "close" else 0.0
	Style.printed(self, Rect2(cr.position + Vector2(down, down), cr.size), Style.CARD, 4.0 - down, 2, 3)
	var cc := cr.get_center() + Vector2(down, down)
	draw_line(cc + Vector2(-10, -10), cc + Vector2(10, 10), Style.INK, 4.0, true)
	draw_line(cc + Vector2(10, -10), cc + Vector2(-10, 10), Style.INK, 4.0, true)
	Style.text(self, Style.serif(800, 144), "Shop", Vector2(ox + W * 0.5, top + 50.0), 48, Style.INK)
	var wob := Vector2(sin(_warn * 40.0) * 8.0 * _warn, 0)
	Style.coin(self, _counter_pos() + wob, 15.0)
	draw_string(Style.num(700), _counter_pos() + wob + Vector2(23, 11), Style.commas(coins_shown), HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
		Style.INK.lerp(Style.ACCENT, _warn))
	draw_line(Vector2(ox + 32.0, top + 100.0), Vector2(ox + W - 32.0, top + 100.0), Style.INK, 2.0)
	_ribbon("Boosters", top + 130.0)
	for i in ORDER.size():
		_draw_card(i)
	_ribbon("Card backs", _backs_title_y())
	_draw_fan()
	for f in _coin_flights:
		if f[2] < 0.0:
			continue
		var t: float = clampf(f[2] / 0.5, 0.0, 1.0)
		var pos: Vector2 = (f[0] as Vector2).lerp(f[1], t * t) + Vector2(0, -80.0 * sin(t * PI))
		Style.coin(self, pos, 11.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## A section header: small capitals on a printed ink ribbon.
func _ribbon(word: String, y: float) -> void:
	var w := Style.caps_width(word, 13, 0.25) + 44.0
	var r := Rect2(Vector2(ox + W * 0.5 - w * 0.5, y - 15.0), Vector2(w, 30))
	for sd in [-1.0, 1.0]:
		var x: float = r.position.x if sd < 0.0 else r.end.x
		var tail := PackedVector2Array([Vector2(x, y - 9.0), Vector2(x + sd * 22.0, y - 9.0), Vector2(x + sd * 14.0, y + 3.0),
			Vector2(x + sd * 22.0, y + 15.0), Vector2(x, y + 15.0)])
		draw_colored_polygon(tail, Style.INK)
	draw_rect(r, Style.INK)
	Style.caps(self, word, r.get_center(), 13, Style.CARD, 0.25)

func _draw_card(i: int) -> void:
	var id: String = ORDER[i]
	var ys := _y_shift()
	var r := _card_rect(i)
	var sh := float(_shake.get(id, 0.0))
	r.position.x += sin(sh * 30.0) * 8.0 * sh
	Style.printed(self, r, Style.CARD, 5.0, 2, 3)
	var col := Style.group_color(BANDS[id])
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 14)), col)
	draw_line(r.position + Vector2(2, 16), Vector2(r.end.x - 2, r.position.y + 16), Style.INK, 2.0)
	var f := float(_flash.get(id, 0.0))
	if f > 0.0:
		draw_rect(r.grow(-2), Color(Style.COIN, 0.35 * f))
	# The big icon.
	var ic := Vector2(r.get_center().x, r.position.y + 76.0)
	draw_circle(ic + Vector2(4, 4), 44.0, Style.INK)
	draw_circle(ic, 44.0, Style.PAPER_DEEP)
	draw_arc(ic, 44.0, 0, TAU, 40, Style.INK, 2.5, true)
	draw_set_transform(ic + Vector2(0, ys), 0.0, Vector2(1.5, 1.5))
	Style.booster_icon(self, id, Vector2.ZERO, Style.INK)
	draw_set_transform(Vector2(0, ys), 0.0, Vector2.ONE)
	var n := Progress.booster_count(id)
	if n > 0:
		var bc := ic + Vector2(38, -34)
		var pop := 1.0 + 0.5 * float(_stamp.get(id, 0.0))
		draw_circle(bc + Vector2(2, 2), 18.0 * pop, Style.INK)
		draw_circle(bc, 18.0 * pop, Style.ACCENT)
		draw_arc(bc, 18.0 * pop, 0, TAU, 24, Style.INK, 2.0, true)
		Style.text(self, Style.sans(800), "×%d" % n, bc + Vector2(0, -1), int(15 * pop), Style.CARD)
	Style.text(self, Style.serif(700, 48), NAMES[id], Vector2(r.get_center().x, r.position.y + 146.0), 26, Style.INK)
	Style.caps(self, WORDS[id], Vector2(r.get_center().x, r.position.y + 174.0), 12, Color(Style.INK, 0.6), 0.08)
	# Price button: presses into its shadow.
	var price: int = Progress.BOOSTERS[id].price
	var ok := Progress.coins >= price
	var b := _buy_rect(i)
	b.position.x += sin(sh * 30.0) * 8.0 * sh
	var down := 4.0 if _press == "buy:%d" % i else 0.0
	Style.printed(self, Rect2(b.position + Vector2(down, down), b.size), Style.COIN if ok else Style.PAPER_DEEP, 4.0 - down, 2, 3)
	Style.price(self, b.get_center() + Vector2(down, down), price, 26, 1.0 if ok else 0.45)
	_draw_stamp(id, r.get_center() + Vector2(0, -10))

## "Bought": a red rubber stamp that thumps down and fades.
func _draw_stamp(id: String, c: Vector2) -> void:
	var t := float(_stamp.get(id, 0.0))
	if t <= 0.0:
		return
	var ys := _y_shift()
	var land := clampf((1.0 - t) / 0.18, 0.0, 1.0)
	var sc := 2.0 - Style.ease_back(land)
	var a := minf(t * 2.5, 1.0)
	draw_set_transform(c + Vector2(0, ys), -0.18, Vector2(sc, sc))
	var r := Rect2(Vector2(-78, -26), Vector2(156, 52))
	draw_rect(r, Color(Style.CARD, 0.85 * a))
	draw_rect(r, Color(Style.ACCENT, a), false, 4.0)
	draw_rect(r.grow(-6), Color(Style.ACCENT, a), false, 1.5)
	Style.caps(self, "Bought", Vector2.ZERO, 20, Color(Style.ACCENT, a), 0.22)
	draw_set_transform(Vector2(0, ys), 0.0, Vector2.ONE)

func _draw_fan() -> void:
	var ys := _y_shift()
	var n: int = Progress.shop_backs().size()
	var order := range(n)
	# Far cards first, so the front card is drawn on top.
	order.sort_custom(func(a, b): return absf(a - _fan) > absf(b - _fan))
	for i in order:
		var id: String = Progress.shop_backs()[i][0]
		var s: Array = _fan_slot(i)
		var front: bool = i == _sel
		var sx := 1.0
		if front and _flip < 1.0:
			sx = maxf(absf(cos(_flip * PI)), 0.05)
		var sc: float = s[2]
		var sh := float(_shake.get(id, 0.0))
		var pos: Vector2 = s[0] + Vector2(sin(sh * 30.0) * 8.0 * sh, 0)
		draw_set_transform(pos + Vector2(0, ys), s[1], Vector2(sc * sx, sc))
		var r := Rect2(-BACK_SIZE * 0.5, BACK_SIZE)
		if front and Progress.card_back == id:
			draw_rect(r.grow(8.0), Color(Style.ACCENT, 0.55 + 0.35 * sin(_age * 4.0)), false, 4.0)
		draw_rect(Rect2(r.position + Vector2(5, 5), r.size), Style.INK)
		if front and _flip < 0.5:
			draw_rect(r, Style.CARD)       # mid-turn: the plain side
		else:
			Style.card_back(self, r, id)
		draw_rect(r, Style.INK, false, 2.0)
		var f := float(_flash.get(id, 0.0))
		if f > 0.0:
			draw_rect(r, Color(1, 1, 1, 0.5 * f))
		if not front:
			draw_rect(r, Color(Style.PAPER, 0.3 * minf(absf(i - _fan), 1.0)))
	draw_set_transform(Vector2(0, ys), 0.0, Vector2.ONE)
	# Dots: where you are in the fan.
	var fc := _fan_center()
	for i in n:
		var dc := Vector2(fc.x + (i - (n - 1) * 0.5) * 18.0, fc.y + 136.0)
		draw_circle(dc, 4.5 if i == _sel else 3.0, Style.INK if i == _sel else Color(Style.INK, 0.25))
	# The front card's name and its button.
	var sel_id: String = Progress.shop_backs()[_sel][0]
	var price: int = Progress.shop_backs()[_sel][1]
	_draw_stamp(sel_id, fc)
	Style.text(self, Style.serif(700, 48), BACK_NAMES[sel_id], Vector2(fc.x, fc.y - 146.0), 28, Style.INK)
	var b := _back_button_rect()
	var down := 4.0 if _press == "back" else 0.0
	var br := Rect2(b.position + Vector2(down, down), b.size)
	if Progress.card_back == sel_id:
		Style.caps(self, "In use", b.get_center(), 15, Style.ACCENT, 0.22)
	elif Progress.owns_back(sel_id):
		Style.printed(self, br, Style.CARD, 4.0 - down, 2, 3)
		Style.caps(self, "Use", br.get_center(), 16, Style.INK, 0.22)
	else:
		var ok := Progress.coins >= price
		Style.printed(self, br, Style.COIN if ok else Style.PAPER_DEEP, 4.0 - down, 2, 3)
		Style.price(self, br.get_center(), price, 26, 1.0 if ok else 0.45)
