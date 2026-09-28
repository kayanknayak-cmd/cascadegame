extends Node
## Rewarded ads: "watch an ad for a reward", always the player's choice.
##
## There is no real ad add-on yet (it needs the Apple account and an ad
## network add-on). Until then this shows a STAND-IN: a 3-second card that
## says an ad would play here, then gives the reward. It only appears in test
## builds, so a fake ad can never reach the App Store. When the real add-on is
## installed, only show_rewarded() and available() change; every button that
## offers a reward keeps working.
##
## Rules (see new-game-plan/05-handoff.md): rewarded ads are optional; after-win
## ads (not built yet) skip once when the player just watched a rewarded one.

signal finished(rewarded: bool)

const STAND_IN_SECONDS := 3.0

var instant := false               ## tests: reward straight away, no card
var skip_next_interstitial := false
var _layer: CanvasLayer
var _node: Control
var _t := -1.0
var _on_done: Callable

## True when a rewarded ad can be offered.
func available() -> bool:
	return OS.is_debug_build()      # the stand-in; the real add-on: its "ad loaded" check

## Plays an ad; `on_done` runs only if it was watched to the end.
func show_rewarded(on_done: Callable) -> void:
	if not available():
		return
	skip_next_interstitial = true
	if instant:
		on_done.call()
		finished.emit(true)
		return
	_on_done = on_done
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 20
		add_child(_layer)
		_node = Control.new()
		_node.set_anchors_preset(Control.PRESET_FULL_RECT)
		_node.mouse_filter = Control.MOUSE_FILTER_STOP     # nothing behind can be tapped
		_node.draw.connect(_draw_card)
		_layer.add_child(_node)
	_node.visible = true
	_t = 0.0
	Audio.duck(STAND_IN_SECONDS + 0.5, -18.0)

func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta / maxf(Engine.time_scale, 0.001)
	_node.queue_redraw()
	if _t >= STAND_IN_SECONDS:
		_t = -1.0
		_node.visible = false
		Audio.purchase()
		if _on_done.is_valid():
			_on_done.call()
		finished.emit(true)

## The stand-in: an ink screen, "Ad" and a countdown ring.
func _draw_card() -> void:
	var size := _node.get_viewport_rect().size
	var fade := clampf(_t / 0.2, 0.0, 1.0) * clampf((STAND_IN_SECONDS - _t) / 0.2, 0.0, 1.0)
	_node.draw_rect(Rect2(Vector2.ZERO, size), Color(Style.INK, 0.96 * fade))
	var c := size * 0.5
	Style.text(_node, Style.serif(800, 144), "Ad", c + Vector2(0, -70), 96, Color(Style.PAPER, fade))
	Style.caps(_node, "A real ad plays here", c + Vector2(0, 10), 15, Color(Style.PAPER, 0.7 * fade), 0.2)
	Style.caps(_node, "Test build", c + Vector2(0, 40), 12, Color(Style.COIN, 0.8 * fade), 0.2)
	var left := STAND_IN_SECONDS - _t
	var rc := c + Vector2(0, 130)
	_node.draw_arc(rc, 34.0, 0, TAU, 48, Color(Style.PAPER, 0.2 * fade), 6.0, true)
	_node.draw_arc(rc, 34.0, -PI * 0.5, -PI * 0.5 + TAU * (left / STAND_IN_SECONDS), 48, Color(Style.COIN, fade), 6.0, true)
	Style.text(_node, Style.num(800), str(ceili(left)), rc, 32, Color(Style.PAPER, fade))
