class_name CascadeMain
extends Node2D
## Magnet Cascade: the play screen, in the Editorial Paper style.
##
## One action: tap a card. The rules (Cascade) work out the whole chain at
## once and hand back a list of events; this screen plays them back one beat
## at a time so every link of the chain is seen, heard and felt:
##   grab   - the tapped card and every face-up card of its colour leap into the tray
##   reveal - each card that leaves flips over the one beneath it
##   link   - a flipped card whose colour is already in the tray is hit by a
##            magnet beam and leaps in too, each link a note higher and faster
##   burst  - a full group: freeze-frame, its colour floods the cards, a
##            sunburst, then the cards zip into the progress bar and coins pour out
##   fire   - a revealed Magnet or Bomb goes off, which usually means more links
##
## Learning it: level 1's first tap is guided (only one card can be tapped,
## and the chain plays in slow motion with captions). Chains start slow on the
## early levels and reach full speed by level 5.

const W := 720.0
const CARD := CardView.SIZE
const PILE_STEP := 7.0          ## how far each hidden card peeks out above the one on top
const TRAY_SCALE := 0.8
const TRAY_FAN := 54.0          ## vertical gap between cards stacked in a tray slot

const DAILY_RAMP_INDEX := 10    ## the daily uses this level's difficulty
const BANNER_TIME := 1.0        ## the level-name banner shows alone before the deal
const JACKPOT_CARDS := 10       ## one tap moving this many cards is a Cascade
const PEEK_FROM_LEVEL := 4       ## 0-based: level 5
const PEEK_SECONDS := 3.2
const STREAK_PEEK := 2          ## wins in a row for a free peek at the start
const STREAK_SLOT := 3          ## wins in a row for an extra tray slot

const PRAISE := [
	[6, ["Nice.", "Lovely.", "Neat."]],
	[8, ["Brilliant.", "Splendid.", "Delightful."]],
	[10, ["Superb!", "Marvellous!", "Glorious!"]],
	[13, ["Magnificent!", "Spectacular!", "Sensational!"]],
	[16, ["Unbelievable!", "Legendary!", "Masterpiece!"]],
]
## New things are introduced once ever, with a big example card and three
## words, the first time they appear. level index -> [key, name, words]
const INTROS := {
	2: ["magnet", "Magnet", "Pulls its matches"],
	3: ["bomb", "Bomb", "Clears the tops"],
	4: ["peek", "Peek", "See two cards deep"],
	12: ["lock", "Lock", "Opens after bursts"],
	20: ["wild", "Wild", "Finishes a group"],
	30: ["ice", "Frozen", "Its colour thaws it"],
	45: ["chain", "Chained", "Freed by a neighbour"],
	60: ["wrap", "Wrapped", "A mystery colour"],
	40: ["color", "Colour bomb", "Clears a colour"],
	55: ["row", "Row", "Knocks off a row"],
	70: ["shuffle", "Shuffle", "Brings matches up"],
}

var levels: Array = []
var level_index := 0
var level: Dictionary
var board: Cascade              ## the true state
var _vis: Cascade               ## what the screen shows, which trails the truth during a chain
var views: Array[CardView] = []

var H := 1280.0
var ox := 0.0
var _top := 0.0                 ## iPhone notch: keep the HUD below it
var _bottom := 0.0              ## iPhone home bar: keep buttons above it

var _undo: Array[Cascade] = []
var undos_left := 3
var hints_left := 3
var _seq := 0
var _busy_until := 0.0
var _clock := 0.0
var _pressed_pile := -1
var _preview: Array = []
var _hint_pile := -1
var _leaving: Dictionary = {}   ## cards animating out of the game; layout leaves them alone
var _deck_pos := Vector2.ZERO
var _guided := false            ## level 1's first tap: only the shown card works
var _explain := false           ## caption the chain as it happens

var _coin_shown := 0
var _coin_roll := 0.0            ## what the counter shows: rolls smoothly towards _coin_shown
var _coin_pop := 0.0
var _lit: Array = []            ## groups finished, in order (for the progress bar)
var _seg_pop: Array[float] = []
var _slot_pulse: Array[float] = []
var _punch := 0.0
var _shake := 0.0
var _danger_t := 0.0
var _chain_count := 0
var _chain_pop := 0.0
var _cap_text := ""             ## the one caption line under the progress bar
var _cap_age := 0.0
var _cap_life := 0.0
var _cap_old := ""              ## the previous caption, fading out
var _cap_old_age := 0.0

var _overlay := ""              ## "" | "title" (home map) | "win" | "lose" | "settings" | ...
var _overlay_age := 0.0
var _idle := 0.0                ## seconds since the last touch, for idle hints
var _idle_pulse := 0.0
var _stars_now := 3             ## stars you're on track for (the live meter)
var _star_drop := 0.0
var _best_chain := 0            ## longest chain this level, for the results card
var _frame := 0.0               ## coloured screen frame during big chains
var _frame_color := Style.ACCENT
var _new_best := false
var _daily := false
var _daily_key := ""
var _daily_level: Dictionary = {}
var show_title := true            ## tests turn this off
var time_scale_base := 1.0        ## tests speed the whole game up
var _fresh_unlock := -1           ## a level just unlocked, celebrated on the map
var _bg_mat: ShaderMaterial
var _caption_layer: Node2D      ## captions draw above the cards
var _tint := 0.0
var _flying: Dictionary = {}      ## chained cards in flight -> their colour, for trails
var _perfect := false
var _streak := 0                ## taps in a row that burst at least one group
var _streak_pop := 0.0
var _tag_born: Dictionary = {}  ## group -> clock time its tray tag appeared
var _heartbeat := 0.0
var _level_t := 0.0             ## seconds since the level started, for the intro
var _deal_done := 99.0          ## _level_t when the deal finishes
var _win_stars := 0
var _win_coins := 0
var _win_coins_shown := 0
var _ad_doubled := false         ## this win's coins were doubled by a rewarded ad
var _ad_slot_used := false       ## the lose card's "watch for +1 slot" was used this level
var _stars_shown := 0
var _star_slam: Array[float] = [0.0, 0.0, 0.0]

var fx: Fx
var _ui: CanvasLayer
var _overlay_layer: CanvasLayer
var _overlay_draw: Node2D
var _undo_btn: PillButton
var _hint_btn: PillButton
var _peek_btn: PillButton
var _peeking := 0.0              ## seconds left of a peek
var goal: Dictionary = {}       ## this level's bonus goal (see Goals), or {}
var _goal_state := "open"       ## open / met / failed
var _goal_best := 0             ## most cards moved by one tap so far
var _goal_shown := false        ## the tag has made its entrance
var _goal_fly := 0.0            ## 1 -> 0 while the goal tag flies to its spot
var _goal_pop := 0.0
var _jackpot := false            ## this tap will move JACKPOT_CARDS or more
var _coins_at_start := 0        ## for Lucky coins: what this level has earned
var _spent_in_level := 0
var _continues := 0              ## "+1 slot" bought this level
var _jackpots := 0               ## jackpots so far this level (later ones pay less)
var _queued_pile := -1           ## a tap made during a chain, played when it ends
var _coin_warn := 0.0            ## the coin counter shakes red when you can't afford something
var _overlay_buttons: Array[PillButton] = []
var _fx_layer: CanvasLayer
var _set_ceremony := ""         ## album set just finished, celebrated back on the home screen
var _teaser_card: CardView       ## next level's new card, peeking out of the win card
var _shop: ShopPanel
var _xray := false               ## X-ray booster: see under every top card all level
var _lucky := false              ## Lucky coins booster: double coins on a win
var _pre_index := -1             ## the level the pre-level panel is for
var _pre_sel: Dictionary = {}    ## boosters switched on in the pre-level panel
const PRE_BOOSTERS := ["slot", "xray", "lucky"]
const PRE_FROM := 5              ## level index where the pre-level panel (and boosters) start

# ---------------------------------------------------------------- setup

func _ready() -> void:
	if show_title:
		Playtest.session_break()
	Audio.enabled = Progress.sound
	Audio.music_enabled = Progress.music
	Style.big = Progress.large_text
	Progress.note_day()
	Audio.music_start()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cascade_levels.json"))
	levels = data.levels
	_build_background()
	# Effects (coins, confetti, bursts, words) live on their own top layer so
	# they show over panels and the home map too; the layer copies this
	# node's shake and zoom every frame.
	_fx_layer = CanvasLayer.new()
	_fx_layer.layer = 3
	add_child(_fx_layer)
	fx = Fx.new()
	_fx_layer.add_child(fx)
	_caption_layer = Node2D.new()
	_caption_layer.z_index = 880
	_caption_layer.draw.connect(_draw_caption)
	add_child(_caption_layer)
	_build_ui()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	# Brand-new players go straight into level 1; everyone else starts on the
	# home map (no level is dealt behind it).
	if show_title and not _new_player():
		_overlay = "title"
		_overlay_age = 0.0
		_show_overlay_buttons()
		# The full opening once a day; a quick one otherwise.
		var full := Progress.intro_day != Progress.local_date()
		Progress.intro_day = Progress.local_date()
		Progress.save_game()
		_home.start_intro(full)
		_celebrate_streak(3.0 if full else 1.4)
		_celebrate_league(5.4 if full else 3.8)
		Audio.music_theme("ch%d" % posmod(mini(Progress.cascade_level, levels.size() - 1) / 10, 10))
	else:
		start_level(Progress.cascade_level % levels.size())

func _new_player() -> bool:
	return Progress.cascade_level == 0 and Progress.stars.is_empty()

## Leaving the app saves and quiets the music; coming back picks it up.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			Progress.save_game()
			Playtest.log_line(_level_name(), "left the app after %ds in this level" % Playtest.seconds_in_level())
			Audio.music_stop()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			Audio.music_start()

func _on_resize() -> void:
	var s := get_viewport_rect().size
	H = maxf(s.y, 1180.0)
	ox = maxf((s.x - W) * 0.5, 0.0)
	_top = 0.0
	_bottom = 0.0
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var win := DisplayServer.window_get_size()
		var k := s.y / maxf(win.y, 1.0)
		_top = maxf(0.0, safe.position.y) * k
		_bottom = maxf(0.0, win.y - safe.end.y) * k
	_place_buttons()
	if _home:
		_size_home()
		if _overlay == "title":
			_show_overlay_buttons()
	if board:
		_layout(false)
	queue_redraw()

func start_level(index: int) -> void:
	_daily = false
	Audio.music_mood(index)
	_begin(_dressed_level(index), index)

## The level as it's shown this time: sometimes a rare group, sometimes a
## group from the album's featured set (see Dress). Kept for the session so
## a retry looks the same.
var _dressed: Dictionary = {}

func _dressed_level(index: int) -> Dictionary:
	var key := "%d|%s" % [index, Progress.featured_set().key]
	if not _dressed.has(key):
		_dressed[key] = Dress.dress(levels[index], index, Progress.featured_set().key, Progress.set_missing())
	return _dressed[key]

func _is_rare(g: int) -> bool:
	return g >= 0 and g < level.groups.size() and bool(level.groups[g].get("rare", false))

## Today's puzzle: the same for everyone on the same date, built on the spot
## from the date as the random seed, and proven winnable like every level.
func start_daily() -> void:
	var key := Progress.local_date()
	if _daily_level.is_empty() or _daily_key != key:
		_daily_key = key
		var idx := daily_index(key)
		# Built once per day (it takes a moment), then kept in the save file.
		if Progress.daily_cache.get("key", "") == key + "|%d" % idx:
			_daily_level = Progress.daily_cache.level
		else:
			_daily_level = CascadeGen.build(idx, LevelGen.load_groups(), key.hash() & 0x7fffffff, 120)
			if _daily_level.is_empty():
				_daily_level = levels[DAILY_RAMP_INDEX]
			Progress.daily_cache = {"key": key + "|%d" % idx, "level": _daily_level}
			Progress.save_game()
	_daily = true
	Audio.music_theme("daily")
	Audio.layers = 0
	_begin(_daily_level, -1)

## The daily's difficulty by weekday, like newspaper puzzles: easy Monday,
## hard Sunday, with the newer cards later in the week. Never harder than
## what the player has reached (so nothing turns up they haven't met).
const DAILY_BY_WEEKDAY := [76, 8, 10, 18, 33, 48, 63]   ## Sunday first

func daily_index(date_key: String) -> int:
	var d := Time.get_datetime_dict_from_datetime_string(date_key + "T12:00:00", true)
	var want: int = DAILY_BY_WEEKDAY[int(d.get("weekday", 1))]
	return mini(want, maxi(DAILY_RAMP_INDEX, Progress.cascade_level))

func _begin(lv: Dictionary, index: int) -> void:
	_queued_pile = -1
	_seq += 1
	level_index = index
	level = lv
	Playtest.level_started(_level_name())
	board = Cascade.from_level(level)
	_vis = board.clone()
	_undo.clear()
	_coins_at_start = Progress.coins
	_spent_in_level = 0
	_jackpots = 0
	_continues = 0
	_ad_slot_used = false
	_xray = false
	_lucky = false
	goal = {} if _daily else Goals.for_level(level, index)
	_goal_state = "open"
	_goal_best = 0
	_goal_fly = 0.0
	_goal_pop = 0.0
	_goal_shown = false
	undos_left = 3
	hints_left = 3
	_pressed_pile = -1
	_preview = []
	_hint_pile = -1
	_showme_card = -1
	_showme_pile = -1
	_leaving.clear()
	_overlay = ""
	_lit = []
	_coin_shown = Progress.coins
	_seg_pop.resize(board.group_count())
	_seg_pop.fill(0.0)
	_slot_pulse.resize(board.hold + 1)
	_slot_pulse.fill(0.0)
	_danger_t = 0.0
	Engine.time_scale = time_scale_base
	for v in views:
		v.queue_free()
	views.clear()
	_deck_pos = Vector2(ox + W * 0.5, -160.0)
	for i in board.card_label.size():
		var v := CardView.new()
		v.card = i
		v.label = board.card_label[i]
		v.kind = board.card_kind[i]
		if board.card_kind[i] == Cascade.Kind.CARD:
			v.band = Style.group_color(board.card_group[i])
			v.group = board.card_group[i]
			v.rare = _is_rare(board.card_group[i])
		v.locked = board.lock[i]
		v.iced = board.ice[i]
		v.chained = board.chain[i] > 0
		v.wrapped = board.wrapped[i] == 1
		add_child(v)
		v.snap_to(_deck_pos)
		views.append(v)
	if _caption_layer:
		move_child(_caption_layer, -1)
	_update_peek_bands()
	_guided = index == 0
	_explain = index == 0
	_idle = 0.0
	_level_t = 0.0
	_peeking = 0.0
	_chain_count = 0
	_deal_done = 99.0
	_streak = 0
	_tag_born.clear()
	_stars_now = 3
	_best_chain = 0
	_frame = 0.0
	_show_overlay_buttons()
	_refresh_buttons()
	_start_surprise()
	_pet_start_level()
	_deal_in()
	queue_redraw()

## Level card, then the cards arc up out of the deck round by round, then the
## top of every pile flips in a wave.
func _deal_in() -> void:
	var seq := _seq
	# The level's name first, on its own; once it has gone the cards deal in.
	fx.banner(WEEKDAYS[int(Time.get_datetime_dict_from_datetime_string(_daily_key + "T12:00:00", true).get("weekday", 0))] if _daily else _level_name(),
		"Boss level  ·  double coins" if level.get("boss", false) else ("Daily puzzle" if _daily else ""),
		Vector2(ox + W * 0.5, H * 0.42), BANNER_TIME, {"groups": board.group_count(), "taps": _par() + 1})
	_later(BANNER_TIME - 0.15, seq, Audio.deal_start)
	var order := 0
	var start := BANNER_TIME - 0.1
	var depth_max := 0
	for p in board.piles.size():
		depth_max = maxi(depth_max, board.piles[p].size())
	for layer in depth_max:
		for p in board.piles.size():
			var pile: Array = board.piles[p]
			if layer >= pile.size():
				continue
			var v := views[pile[layer]]
			v.z_index = 10 + layer
			v.on_land = Audio.deal_tick
			v.rest_rotation = PEEK_TILT if layer == pile.size() - 2 else 0.0
			v.move_to(_pile_card_pos(p, layer, pile.size()), 0.34, start + order * 0.03, 90.0)
			order += 1
	var flip_at := start + order * 0.03 + 0.3
	_deal_done = flip_at + 0.2
	for p in board.piles.size():
		if not board.piles[p].is_empty():
			views[board.piles[p][-1]].flip_up(flip_at + p * 0.06)
	var flips_end := flip_at + board.piles.size() * 0.06 + 0.25
	_busy_until = _clock + flips_end
	_later(flips_end, seq, _intro_caption)
	if not goal.is_empty():
		_later(flips_end - 0.4, seq, _show_goal)

func _intro_caption() -> void:
	if _guided:
		return   # the spotlight and finger do the teaching
	var pid := _pet()
	if pid != "" and not Progress.seen.has("pet_first_" + pid) and Pets.line(pid, "first", 0) != "":
		Progress.seen["pet_first_" + pid] = true
		_pet_line = Pets.line(pid, "first", 0)
		_pet_line_age = 0.0
		_pet_line_life = 2.6
		_pet_cool = 3.0
		_pet_bounce = 1.0
	else:
		_pet_say("hello")
	if not _daily:
		_streak_reward()
	if not _daily and INTROS.has(level_index) and not Progress.seen.has(INTROS[level_index][0]):
		_open_intro(INTROS[level_index])
	elif not Progress.seen.has("rare"):
		for g in level.groups.size():
			if _is_rare(g):
				_open_intro(["rare", "Rare cards", "Gold edge, big bonus"])
				break

## Win-streak rewards at the start of a level: a free peek after two wins
## in a row, and an extra tray slot after three.
func _streak_reward() -> void:
	var n := Progress.win_streak
	if n >= STREAK_SLOT:
		board.hold += 1
		_vis.hold += 1
		_slot_pulse.resize(board.hold + 1)
		fx.popup("+1 slot", _slot_pos(board.hold - 1) + Vector2(0, -130), Style.ACCENT, 34, 40.0, 1.4, "plain")
	if n >= STREAK_PEEK:
		_peeking = PEEK_SECONDS + 1.0
		_update_peek_bands()
		_refresh_buttons()
	if n >= STREAK_PEEK:
		fx.popup("Win streak ×%d" % n, Vector2(ox + W * 0.5, 190.0 + _top), Style.ACCENT, 40, 20.0, 1.6, "big")
		Audio.streak_up(mini(n, 5))
		for k in mini(n, 5):
			_later(0.1 + k * 0.08, _seq, func(): fx.burst(Vector2(ox + W * 0.5 + (k - 2) * 60.0, 190.0 + _top), 10, 260.0,
				[Style.ACCENT, Style.COIN], 0.0))

var _lost_streak := 0

## Lose card: watch an ad for one more tray slot (once a level).
func _watch_slot() -> void:
	Ads.show_rewarded(func():
		_ad_slot_used = true
		continue_with_slot(true))

# ---------------------------------------------------------------- surprises
## About one level in five (from level 10, never the daily) has one good
## surprise: it only helps or looks lovely, and never touches the rules, so
## every level stays winnable exactly as the solver proved it.
##   golden  - after the 2nd burst a hidden card turns gold; its group pays a bonus
##   gift    - after the 3rd tap a wrapped gift lands; tap it for coins (not a move)
##   sunset  - the paper warms towards evening as you near the end
##   weather - snow (winter groups) or rain (Rainy Day) drifts behind the cards
var _surprise := ""
var _golden_card := -1
var _golden_group := -1
var _gift_token: Dictionary = {}    ## {pos, coins, taps_left, age, gone}
var _dusk := 0.0
var _weather: Array = []           ## [pos, speed, size] drops or flakes
var _weather_kind := ""

static func surprise_for(level_index: int, group_names: PackedStringArray) -> String:
	if level_index < 9 or posmod(level_index * 7 + 3, 5) != 0:
		return ""
	var kinds := ["golden", "gift", "sunset", "weather"]
	var k: String = kinds[posmod(level_index / 5, kinds.size())]
	if k == "weather" and _weather_for(group_names) == "":
		k = "sunset"
	return k

static func _weather_for(group_names: PackedStringArray) -> String:
	for g in group_names:
		if g in ["Snow Day", "Christmas"]:
			return "snow"
		if g == "Rainy Day":
			return "rain"
	return ""

func _start_surprise() -> void:
	_surprise = "" if _daily else surprise_for(level_index, board.group_names)
	_golden_card = -1
	_golden_group = -1
	_gift_token = {}
	_dusk = 0.0
	_weather.clear()
	_weather_kind = _weather_for(board.group_names) if _surprise == "weather" else ""
	if _bg_mat:
		_bg_mat.set_shader_parameter("dusk", 0.0)
	if _weather_kind != "":
		var rng := RandomNumberGenerator.new()
		rng.seed = level_index
		for i in (46 if _weather_kind == "snow" else 60):
			_weather.append([Vector2(ox + rng.randf() * W, rng.randf() * H), rng.randf_range(0.6, 1.4), rng.randf_range(0.7, 1.3)])

## After each tap: the golden card and the gift arrive on their cue.
func _surprise_after_tap() -> void:
	if _surprise == "golden" and _golden_card == -1 and _lit.size() >= 2:
		_make_golden()
	if _surprise == "gift":
		if _gift_token.is_empty() and board.taps >= 3 and not board.is_won():
			var rng := RandomNumberGenerator.new()
			rng.seed = level_index * 31 + 7
			_gift_token = {"pos": Vector2(ox + W - 78.0, _tray_y() - 318.0), "coins": rng.randi_range(Economy.GIFT_MIN, Economy.GIFT_MAX),
				"taps_left": 3, "age": 0.0, "gone": -1.0}
			Audio.gift_flip()
		elif not _gift_token.is_empty() and float(_gift_token.gone) < 0.0 and float(_gift_token.age) > 0.5:
			_gift_token.taps_left = int(_gift_token.taps_left) - 1
			if int(_gift_token.taps_left) <= 0:
				_gift_token.gone = 0.0      # it floats away

func _make_golden() -> void:
	# A face-down card (not on top) of a group that isn't finished or in the tray.
	var best := -1
	for p in board.piles.size():
		var pile: Array = board.piles[p]
		for i in pile.size() - 1:
			var c: int = pile[i]
			if board.card_kind[c] != Cascade.Kind.CARD or board.wrapped[c] == 1:
				continue
			var g: int = board.card_group[c]
			if g in board.done or board.tray.has(g):
				continue
			best = c
			break
		if best != -1:
			break
	if best == -1:
		_golden_card = -2       # nothing suitable: no golden card this time
		return
	_golden_card = best
	_golden_group = board.card_group[best]
	views[best].golden = true
	views[best].pop(0.15)
	fx.rays(views[best].position, 1.0, 180.0, 12, Style.COIN)
	Audio.star(2)
	_pet_say("golden")

## The gift was tapped: it pops into coins (tapping it is not a move).
func _claim_gift_token() -> void:
	var at: Vector2 = _gift_token.pos
	var c := int(_gift_token.coins)
	_gift_token.gone = 0.0
	_gift_token.claimed = true
	Progress.coins += c
	fx.burst(at, 30, 480.0, [Style.COIN, Style.ACCENT, Style.CARD], 300.0)
	fx.popup("+%d" % c, at + Vector2(0, -40), Style.INK, 30, 30.0, 1.0, "plain")
	Audio.gift_cut()
	_haptic(25)
	_fly_coins(at, c)

# ---------------------------------------------------------------- pets

var _pet_line := ""                ## what the pet is saying right now
var _pet_line_age := 0.0
var _pet_line_life := 0.0
var _pet_cool := 0.0               ## quiet time before the next chatty line
var _pet_charge := 0               ## bursts towards its help this level
var _pet_bounce := 0.0
var _pet_idle_said := false
var _pet_shield_used := false      ## Hedgehog: one saved streak a level
var _safe_until := 0.0             ## Fox: show the safe taps until this time

func _pet() -> String:
	return Progress.active_pet()

## The pet says a short line (1-5 words) in a speech bubble. Chatty moments
## wait for a quiet spell; `force` is for the ones that matter (ready, help,
## win, lose). Never more than one bubble at a time.
func _pet_say(moment: String, force := false) -> void:
	var id := _pet()
	if id == "":
		return
	if not force and (_pet_cool > 0.0 or (_pet_line != "" and _pet_line_age < _pet_line_life)):
		return
	var s := Pets.line(id, moment, randi())
	if s == "":
		return
	_pet_line = s
	_pet_line_age = 0.0
	_pet_line_life = 1.7 + s.length() * 0.035
	_pet_cool = 3.0
	_pet_bounce = 1.0
	Audio.star_pip(randi() % 4)

func _pet_ready() -> bool:
	var id := _pet()
	return id != "" and Pets.is_active(id) and _pet_charge >= Pets.charge_needed(int(Progress.pet_cards.get(id, 0)))

## A group burst: friendship grows, and an active pet's help charges up.
func _pet_burst(cards: int) -> void:
	var id := _pet()
	if id == "":
		return
	Progress.pet_cards[id] = int(Progress.pet_cards.get(id, 0)) + cards
	if not Pets.is_active(id) or _pet_ready():
		return
	_pet_charge += 1
	if _pet_ready():
		_pet_bounce = 1.0
		if not Progress.seen.has("pet_tap_" + id) and Pets.line(id, "tap_me", 0) != "":
			_pet_line = Pets.line(id, "tap_me", 0)
			_pet_line_age = 0.0
			_pet_line_life = 2.6
			_pet_cool = 3.0
		else:
			_pet_say("ready", true)

## Tapping the pet: its help, when it's charged.
func _use_pet() -> void:
	var id := _pet()
	if id == "" or is_busy():
		return
	if not _pet_ready():
		_pet_bounce = 1.0
		_pet_say("idle", true)
		return
	var ok := false
	match String(Pets.get_pet(id).help):
		"hint":
			ok = hint(true)
		"peek":
			ok = peek(true)
		"undo":
			ok = undo(true)
		"safe":
			_safe_until = _clock + 3.0
			ok = true
	if ok:
		Progress.seen["pet_tap_" + id] = true
		_pet_charge = 0
		_pet_say("help", true)
		fx.ring(_pet_rect().get_center(), 90.0, Style.COIN, 0.4)
		Audio.star(1)
		_haptic(20)
		Playtest.log_line(_level_name(), "pet %s helped" % id)

## The pet sits on the tray's top-right corner.
func _pet_rect() -> Rect2:
	var right := minf(_slot_pos(board.hold).x + 78.0, ox + W - 12.0)
	return Rect2(Vector2(right - 70.0, _tray_y() - 290.0 - 30.0), Vector2(58, 58))

func _pet_start_level() -> void:
	_pet_charge = 0
	_pet_line = ""
	_pet_cool = 0.0
	_pet_idle_said = false
	_pet_shield_used = false
	_safe_until = 0.0
	# The Owl joins everyone on level 8.
	if not _daily and level_index >= Pets.FREE_FROM_LEVEL and not Progress.pets.has("owl"):
		Progress.pets["owl"] = true
		if Progress.pet == "":
			Progress.pet = "owl"
		Progress.save_game()

func _pet_process(delta: float) -> void:
	_pet_line_age += delta
	_pet_cool = maxf(_pet_cool - delta, 0.0)
	_pet_bounce = maxf(_pet_bounce - delta * 2.5, 0.0)

func _draw_pet() -> void:
	var id := _pet()
	if id == "" or board == null:
		return
	var r := _pet_rect()
	var t := clampf((_level_t - BANNER_TIME) / 0.4, 0.0, 1.0)
	if t <= 0.0:
		return
	var ready := _pet_ready()
	var s := Style.ease_back(t) * (1.0 + 0.12 * sin(_pet_bounce * PI * 2.0) * _pet_bounce)
	if ready:
		s *= 1.0 + 0.05 * sin(_clock * 6.0)
	draw_set_transform(r.get_center(), sin(_pet_bounce * 12.0) * 0.08 * _pet_bounce, Vector2(s, s))
	var lr := Rect2(-r.size * 0.5, r.size)
	if ready:
		draw_rect(lr.grow(7.0 + 2.0 * sin(_clock * 6.0)), Color(Style.COIN, 0.8), false, 4.0)
	Pets.draw(self, id, lr)
	# Charge pips under an active pet.
	if Pets.is_active(id):
		var need := Pets.charge_needed(int(Progress.pet_cards.get(id, 0)))
		for k in need:
			var pc := Vector2((k - (need - 1) * 0.5) * 14.0, lr.end.y + 12.0)
			draw_circle(pc, 5.0, Style.COIN if k < _pet_charge else Style.PAPER_DEEP)
			draw_arc(pc, 5.0, 0, TAU, 12, Style.INK, 1.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The speech bubble: paper, an ink edge, a tail pointing at the pet.
func _draw_pet_line(cl: CanvasItem) -> void:
	if _pet_line == "" or _pet_line_age >= _pet_line_life or _overlay != "" or _pet() == "":
		return
	var a := minf(clampf(_pet_line_age / 0.15, 0.0, 1.0), clampf((_pet_line_life - _pet_line_age) / 0.25, 0.0, 1.0))
	var pop := Style.ease_back(clampf(_pet_line_age / 0.25, 0.0, 1.0))
	var pr := _pet_rect()
	var f := Style.serif(700, 48)
	var size := 22
	var tw := Style.text_width(f, _pet_line, size) + 30.0
	var anchor := Vector2(pr.position.x - 6.0, pr.position.y + 6.0)
	var br := Rect2(Vector2(anchor.x - tw, anchor.y - 50.0), Vector2(tw, 44.0))
	br.position.x = maxf(br.position.x, ox + 12.0)
	cl.draw_set_transform(anchor, 0.0, Vector2.ONE * (0.6 + 0.4 * pop))
	var lr := Rect2(br.position - anchor, br.size)
	var tail := PackedVector2Array([lr.end + Vector2(-26, -2), lr.end + Vector2(-8, -2), Vector2(4, 0)])
	cl.draw_rect(Rect2(lr.position + Vector2(3, 3), lr.size), Color(Style.INK, a))
	cl.draw_colored_polygon(PackedVector2Array(Array(tail).map(func(v): return v + Vector2(3, 3))), Color(Style.INK, a))
	cl.draw_rect(lr, Color(Style.CARD, a))
	cl.draw_colored_polygon(tail, Color(Style.CARD, a))
	cl.draw_rect(lr, Color(Style.INK, a), false, 2.0)
	cl.draw_polyline(PackedVector2Array([tail[0], tail[2], tail[1]]), Color(Style.INK, a), 2.0, true)
	Style.text(cl, f, _pet_line, lr.get_center() + Vector2(0, -1), size, Color(Style.INK, a))
	cl.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- the Pets page

var _pets_line := ""              ## a pet talking on the Pets page
var _pets_line_id := ""
var _pets_line_t := 0.0
var _pets_shake: Dictionary = {}

func open_pets() -> void:
	if _overlay != "title":
		return
	_overlay = "pets"
	_overlay_age = 0.0
	_pets_line = ""
	Audio.panel_in()
	_show_overlay_buttons()
	var id := Progress.active_pet()
	if id != "":
		_later(0.4, _seq, _pets_say.bind(id, "hello"))

func _close_pets() -> void:
	_overlay = "title"
	_overlay_age = 1.0
	Audio.panel_out()
	_show_overlay_buttons()

func _pets_say(id: String, moment: String) -> void:
	_pets_line = Pets.line(id, moment, randi())
	_pets_line_id = id
	_pets_line_t = _clock
	Audio.star_pip(randi() % 4)

func _pet_tile(i: int) -> Rect2:
	var pr := _overlay_rect()
	var size := Vector2(132, 132)
	var col := i % 3
	var row := i / 3
	var in_row := 3 if row < 2 else Pets.LIST.size() - 6
	var x0 := pr.get_center().x - (in_row * size.x + (in_row - 1) * 36.0) * 0.5
	return Rect2(Vector2(x0 + col * (size.x + 36.0), pr.position.y + 150.0 + row * 196.0), size)

func _pets_click(p: Vector2) -> void:
	for i in Pets.LIST.size():
		if _pet_tile(i).grow(10).has_point(p):
			var pet: Dictionary = Pets.LIST[i]
			var id: String = pet.id
			if Progress.pets.has(id):
				Progress.choose_pet(id)
				Audio.flip()
				_pets_say(id, "hello")
			elif id == "owl":
				# The Owl joins on level 8; before that it waits.
				_pets_shake[id] = 1.0
				Audio.wrong()
			elif Progress.buy_pet(id):
				_coin_shown = Progress.coins
				Audio.purchase()
				_haptic(30)
				fx.burst(_pet_tile(i).get_center(), 40, 520.0, [pet.color, Style.COIN, Style.CARD], 300.0)
				fx.toast("%s joined you!" % pet.name, 0, pet.color, 150.0 + _top)
				_pets_say(id, "hello")
			else:
				_pets_shake[id] = 1.0
				_coin_warn = 1.0
				Audio.wrong()
			return

func _draw_pets(o: Node2D, pr: Rect2) -> void:
	for i in Pets.LIST.size():
		var pet: Dictionary = Pets.LIST[i]
		var id: String = pet.id
		var r := _pet_tile(i)
		var owned: bool = Progress.pets.has(id)
		var sh := float(_pets_shake.get(id, 0.0))
		if sh > 0.0:
			_pets_shake[id] = maxf(sh - get_process_delta_time() * 2.5, 0.0)
			r.position.x += sin(sh * 30.0) * 8.0 * sh
		var active: bool = Progress.active_pet() == id
		if active:
			r.position.y -= 6.0
			o.draw_rect(r.grow(9.0), Color(Style.ACCENT, 0.6 + 0.3 * sin(_clock * 4.0)), false, 4.0)
		Pets.draw(o, id, r, 1.0, owned)
		var y := r.end.y + 24.0
		Style.caps(o, pet.name, Vector2(r.get_center().x, y), 13, Style.INK if owned else Color(Style.INK, 0.6), 0.14)
		if owned:
			var lv := Pets.friendship(int(Progress.pet_cards.get(id, 0)))
			for k in 3:
				Style.fancy_star(o, Vector2(r.get_center().x + (k - 1) * 18.0, y + 22.0), 7.0, 1.0 if k < lv else 0.0)
		elif id == "owl":
			Style.caps(o, "Level 8", Vector2(r.get_center().x, y + 24.0), 12, Color(Style.INK, 0.5), 0.12)
		else:
			Style.price(o, Vector2(r.get_center().x, y + 26.0), int(pet.price), 20, 1.0 if Progress.coins >= int(pet.price) else 0.45)
	# The chosen pet: what it does, and what it just said.
	var id2 := _pets_line_id if _pets_line_id != "" else Progress.active_pet()
	if id2 != "":
		var what := String(Pets.get_pet(id2).what)
		Style.caps(o, what, Vector2(pr.get_center().x, pr.position.y + 768.0), 13, Color(Style.INK, 0.65), 0.12)
	if _pets_line != "" and _clock - _pets_line_t < 2.4:
		var i2 := 0
		for i in Pets.LIST.size():
			if Pets.LIST[i].id == _pets_line_id:
				i2 = i
		var tr := _pet_tile(i2)
		var f := Style.serif(700, 48)
		var tw := Style.text_width(f, _pets_line, 22) + 30.0
		var br := Rect2(Vector2(clampf(tr.get_center().x - tw * 0.5, pr.position.x + 10.0, pr.end.x - tw - 10.0), tr.position.y - 58.0),
			Vector2(tw, 44))
		var pop := Style.ease_back(clampf((_clock - _pets_line_t) / 0.25, 0.0, 1.0))
		var a := clampf((2.4 - (_clock - _pets_line_t)) / 0.3, 0.0, 1.0)
		o.draw_set_transform(_o_base + br.get_center(), 0.0, Vector2.ONE * (0.6 + 0.4 * pop))
		var lr := Rect2(-br.size * 0.5, br.size)
		o.draw_rect(Rect2(lr.position + Vector2(3, 3), lr.size), Color(Style.INK, a))
		o.draw_rect(lr, Color(Style.CARD, a))
		o.draw_rect(lr, Color(Style.INK, a), false, 2.0)
		o.draw_colored_polygon(PackedVector2Array([Vector2(-8, lr.end.y - 1), Vector2(8, lr.end.y - 1), Vector2(0, lr.end.y + 12)]),
			Color(Style.CARD, a))
		Style.text(o, f, _pets_line, Vector2(0, -1), 22, Color(Style.INK, a))
		o.draw_set_transform(_o_base, 0.0, Vector2.ONE)

func _surprise_process(delta: float) -> void:
	if not _gift_token.is_empty():
		_gift_token.age = float(_gift_token.age) + delta
		if float(_gift_token.gone) >= 0.0:
			_gift_token.gone = float(_gift_token.gone) + delta
			if float(_gift_token.gone) > 0.8:
				_gift_token = {}
	if _surprise == "sunset" and board:
		var want := float(_lit.size()) / maxf(board.group_count(), 1)
		_dusk = move_toward(_dusk, want, delta * 0.25)
		if _bg_mat:
			_bg_mat.set_shader_parameter("dusk", _dusk)
	if _weather_kind != "":
		for w in _weather:
			var sp: float = w[1]
			if _weather_kind == "snow":
				w[0] += Vector2(sin(_clock * 0.8 + sp * 9.0) * 14.0, 46.0 * sp) * delta
			else:
				w[0] += Vector2(-90.0, 620.0) * sp * delta
			if w[0].y > H + 20.0:
				w[0] = Vector2(ox + randf() * (W + 120.0), -20.0)

## Weather: drawn by the table itself, so it drifts behind the cards.
func _draw_weather() -> void:
	for w in _weather:
		var p: Vector2 = w[0]
		var k: float = w[2]
		if _weather_kind == "snow":
			# Pale blue flakes with an ink edge, so they show on the paper.
			draw_circle(p, 6.0 * k, Color("dbe9f7"))
			draw_arc(p, 6.0 * k, 0, TAU, 14, Color("6f8fb3", 0.55), 1.5, true)
		else:
			draw_line(p, p + Vector2(-5, 30) * k, Color("6f8fb3", 0.45), 2.0, true)

func _draw_gift_token(cl: CanvasItem) -> void:
	if _gift_token.is_empty() or _overlay != "":
		return
	var t := float(_gift_token.age)
	var gone := float(_gift_token.gone)
	var land := Style.ease_back(clampf(t / 0.45, 0.0, 1.0))
	var p: Vector2 = _gift_token.pos + Vector2(0, -260.0 * (1.0 - land) + sin(t * 4.0) * 4.0)
	var a := 1.0
	var sc := 1.0
	if gone >= 0.0:
		a = 1.0 - clampf(gone / 0.8, 0.0, 1.0)
		if _gift_token.get("claimed", false):
			sc = 1.0 + gone * 1.5
		else:
			p += Vector2(0, -160.0 * gone)
	cl.draw_set_transform(p, sin(t * 2.2) * 0.1, Vector2(sc, sc))
	var r := Rect2(Vector2(-26, -22), Vector2(52, 44))
	cl.draw_rect(Rect2(r.position + Vector2(4, 4), r.size), Color(Style.INK, a))
	cl.draw_rect(r, Color(Style.ACCENT, a))
	cl.draw_rect(Rect2(Vector2(-5, -22), Vector2(10, 44)), Color(Style.COIN, a))
	cl.draw_rect(Rect2(Vector2(-26, -5), Vector2(52, 10)), Color(Style.COIN, a))
	cl.draw_rect(r, Color(Style.INK, a), false, 2.0)
	for sd in [-1.0, 1.0]:
		var loop := PackedVector2Array([Vector2(0, -22), Vector2(sd * 13, -34), Vector2(sd * 15, -24), Vector2(0, -22)])
		cl.draw_colored_polygon(loop, Color(Style.COIN, a))
		cl.draw_polyline(loop, Color(Style.INK, a), 1.5, true)
	# Taps left before it floats away, as small dots.
	if gone < 0.0:
		for i in int(_gift_token.taps_left):
			cl.draw_circle(Vector2(-10 + i * 10, 34), 3.0, Color(Style.INK, 0.5))
	cl.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# ---------------------------------------------------------------- days-played streak

## The streak page: the flame and its number, the last week as little
## squares (played, frozen, missed), freezes you hold, and buttons for a
## freeze, a vacation, or a repair when a streak just broke.
func open_streak() -> void:
	if _overlay != "title":
		return
	_overlay = "streak"
	_overlay_age = 0.0
	Audio.panel_in()
	_show_overlay_buttons()

func _close_streak() -> void:
	_overlay = "title"
	_overlay_age = 1.0
	Audio.panel_out()
	_show_overlay_buttons()

func _streak_buy(kind: String) -> void:
	var cost := 0
	var ok := false
	match kind:
		"freeze":
			cost = Economy.FREEZE_COST
			ok = Progress.buy_freeze()
		"vacation":
			cost = Economy.VACATION_COST
			ok = Progress.buy_vacation()
		"repair":
			cost = Progress.repair_cost()
			ok = Progress.repair_streak()
	if not ok:
		_coin_warn = 1.0
		Audio.wrong()
		return
	_coin_shown = Progress.coins
	Audio.purchase()
	_haptic(20)
	var pr := _overlay_rect()
	fx.popup("-" + Style.commas(cost), Vector2(ox + W - 150.0, 90.0 + _top), Style.ACCENT, 24, 26.0, 1.0, "plain")
	fx.burst(Vector2(pr.get_center().x, pr.position.y + 170.0), 26, 420.0,
		[Color("9cc3e6"), Style.CARD] if kind != "repair" else [Style.ACCENT, Style.COIN], 200.0)
	if kind == "repair":
		fx.toast("Streak repaired", 0, Style.ACCENT, 150.0 + _top)
	_show_overlay_buttons()

func _watch_repair() -> void:
	Ads.show_rewarded(func():
		if Progress.repair_streak(true):
			fx.toast("Streak repaired", 0, Style.ACCENT, 150.0 + _top)
			Audio.purchase()
		_show_overlay_buttons())

## New streak milestones (7, 30, 100 days) since the last look: a toast each.
func _celebrate_streak(delay: float) -> void:
	var news: Array = Progress.streak_news.duplicate()
	Progress.streak_news.clear()
	for k in news.size():
		var m: int = news[k]
		_later(delay + k * 2.4, _seq, func():
			fx.toast("%d-day streak!" % m, int(Economy.STREAK_REWARDS[m]), Style.ACCENT, 150.0 + _top)
			Audio.star(2)
			_later(0.5, _seq, _fly_coins.bind(Vector2(ox + W * 0.5 + 120.0, 150.0 + _top), int(Economy.STREAK_REWARDS[m])))
			if m == 30:
				_later(2.4, _seq, func(): fx.toast("Ember card back", 0, Color("d8341c"), 150.0 + _top)))

func _draw_streak(o: Node2D, pr: Rect2) -> void:
	var cx := pr.get_center().x
	var broken := Progress.can_repair()
	var n := Progress.day_streak()
	var shown := Progress.streak_lost if broken else n
	var pop := Style.ease_back(clampf(_overlay_age / 0.5, 0.0, 1.0))
	o.draw_set_transform(_o_base + Vector2(cx, pr.position.y + 170.0), 0.0, Vector2.ONE * (0.4 + 0.6 * pop))
	Style.flame(o, Vector2.ZERO, 58.0, shown, not broken, _clock)
	o.draw_set_transform(_o_base, 0.0, Vector2.ONE)
	Style.text(o, Style.num(800), str(shown), Vector2(cx, pr.position.y + 262.0), 58, Style.INK if not broken else Color(Style.INK, 0.4))
	var sub := "day streak" if not broken else "streak lost"
	Style.caps(o, sub, Vector2(cx, pr.position.y + 302.0), 14, Style.ACCENT if broken else Color(Style.INK, 0.6), 0.2)
	if Progress.streak_best > 0:
		Style.fancy_star(o, Vector2(pr.end.x - 122.0, pr.position.y + 132.0), 11.0, 1.0)
		Style.caps(o, "Best %d" % Progress.streak_best, Vector2(pr.end.x - 64.0, pr.position.y + 132.0), 12, Color(Style.INK, 0.6), 0.1)
	# The last seven days, today on the right.
	var letters := ["S", "M", "T", "W", "T", "F", "S"]
	var today := Progress.local_date()
	for i in 7:
		var d := Progress.date_add(today, i - 6)
		var c := Vector2(cx + (i - 3) * 66.0, pr.position.y + 366.0)
		var r := Rect2(c - Vector2(26, 26), Vector2(52, 52))
		var wd := int(Time.get_datetime_dict_from_datetime_string(d + "T12:00:00", true).get("weekday", 0))
		Style.caps(o, letters[wd], c + Vector2(0, -42), 12, Color(Style.INK, 0.5 if i < 6 else 1.0), 0.0)
		if Progress.days.has(d):
			o.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Style.INK)
			o.draw_rect(r, Style.CARD)
			o.draw_rect(r, Style.INK, false, 2.0)
			Style.flame(o, c + Vector2(0, 4), 16.0, 7)
		elif Progress.frozen.has(d):
			o.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Style.INK)
			o.draw_rect(r, Color("dbe9f7"))
			o.draw_rect(r, Style.INK, false, 2.0)
			Style.snowflake(o, c, 15.0, Color("4f7fb0"))
		else:
			_dashed_o(o, r, Color(Style.INK, 0.3))
		if i == 6:
			o.draw_rect(r.grow(5), Style.ACCENT, false, 2.5)
	# Freezes held (and a vacation, if one is on).
	var fy := pr.position.y + 452.0
	for k in Economy.FREEZE_MAX:
		var c := Vector2(cx - 90.0 + k * 58.0, fy)
		var r := Rect2(c - Vector2(22, 22), Vector2(44, 44))
		if k < Progress.freezes:
			o.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Style.INK)
			o.draw_rect(r, Color("dbe9f7"))
			o.draw_rect(r, Style.INK, false, 2.0)
			Style.snowflake(o, c, 13.0, Color("4f7fb0"))
		else:
			_dashed_o(o, r, Color(Style.INK, 0.25))
	if Progress.on_vacation():
		var vc := Vector2(cx + 60.0, fy)
		var vr := Rect2(vc + Vector2(-16, -10), Vector2(32, 23))
		o.draw_rect(vr, Style.COIN)
		o.draw_rect(vr, Style.INK, false, 2.5)
		o.draw_rect(Rect2(vc + Vector2(-6, -16), Vector2(12, 6)), Style.INK, false, 2.0)
		var until := Time.get_datetime_dict_from_datetime_string(Progress.vacation_until + "T12:00:00", true)
		Style.caps(o, "to %s %d" % [MONTHS[clampi(int(until.get("month", 1)) - 1, 0, 11)], int(until.get("day", 1))], vc + Vector2(64, 0), 13,
			Style.INK, 0.1)

func _dashed_o(o: Node2D, r: Rect2, col: Color) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for e in 4:
		o.draw_dashed_line(pts[e], pts[e + 1], col, 2.0, 6.0, true)

# ---------------------------------------------------------------- star league

## The Events page has two tabs: this week's event, and the Star League.
var _events_tab := "event"
var _league_board := "week"          ## week / total / chain / streak
const LEAGUE_BOARDS := ["week", "total", "chain", "streak"]

func open_league() -> void:
	if _overlay != "title":
		return
	_events_tab = "league"
	_overlay = "events"
	_overlay_age = 0.0
	Audio.panel_in()
	_show_overlay_buttons()

func _events_tab_rect(k: int) -> Rect2:
	var pr := _overlay_rect()
	return Rect2(Vector2(pr.get_center().x - 150.0 + k * 150.0, pr.position.y + 112.0), Vector2(142, 40))

func _league_chip_rect(k: int) -> Rect2:
	var pr := _overlay_rect()
	return Rect2(Vector2(pr.get_center().x - 250.0 + k * 125.0, pr.position.y + 262.0), Vector2(117, 34))

func _events_click(p: Vector2) -> bool:
	for k in 2:
		if _events_tab_rect(k).grow(6).has_point(p):
			var t: String = ["event", "league"][k]
			if t != _events_tab:
				_events_tab = t
				_slide_page(1 if k == 1 else -1)
				Audio.flip()
				_show_overlay_buttons()
			return true
	if _events_tab == "league":
		for k in LEAGUE_BOARDS.size():
			if _league_chip_rect(k).grow(4).has_point(p):
				if _league_board != LEAGUE_BOARDS[k]:
					_league_board = LEAGUE_BOARDS[k]
					_page_at = _clock
					Audio.flip()
				return true
	return false

func _draw_events_tabs(o: Node2D) -> void:
	for k in 2:
		var r := _events_tab_rect(k)
		var on: bool = ["event", "league"][k] == _events_tab
		if on:
			Style.printed(o, r, Style.INK, 3.0, 2, 3)
		else:
			o.draw_rect(r, Style.INK, false, 2.0)
		Style.caps(o, ["Event", "League"][k], r.get_center(), 13, Style.CARD if on else Style.INK, 0.2)

## Star League: your level, then a board of you and your friends.
func _draw_league(o: Node2D, pr: Rect2) -> void:
	var me := Progress.league_me()
	var cx := pr.get_center().x
	# Player level: a badge and a bar to the next level.
	var lvl: Array = League.player_level(Progress.total_stars())
	var bc := Vector2(pr.position.x + 74.0, pr.position.y + 206.0)
	o.draw_circle(bc + Vector2(3, 3), 26.0, Style.INK)
	o.draw_circle(bc, 26.0, Style.INK)
	o.draw_arc(bc, 26.0, 0, TAU, 32, Style.COIN, 3.0, true)
	Style.text(o, Style.num(800), str(lvl[0]), bc + Vector2(0, -1), 24, Style.COIN)
	var bar := Rect2(Vector2(bc.x + 44.0, bc.y - 2.0), Vector2(pr.size.x - 190.0, 14.0))
	o.draw_rect(Rect2(bar.position + Vector2(2, 2), bar.size), Style.INK)
	o.draw_rect(bar, Style.PAPER_DEEP)
	var fill := bar
	fill.size.x *= float(lvl[1]) / maxf(float(lvl[2]), 1.0)
	o.draw_rect(fill, Style.COIN)
	o.draw_rect(bar, Style.INK, false, 1.5)
	Style.fancy_star(o, Vector2(bar.position.x + 12.0, bar.position.y - 16.0), 9.0, 1.0)
	Style.caps(o, "%d / %d to level %d" % [int(lvl[1]), int(lvl[2]), int(lvl[0]) + 1], Vector2(bar.position.x + 26.0 +
		Style.caps_width("%d / %d to level %d" % [int(lvl[1]), int(lvl[2]), int(lvl[0]) + 1], 12, 0.1) * 0.5, bar.position.y - 16.0), 12,
		Color(Style.INK, 0.6), 0.1)
	# Which board.
	var names := {"week": "This week", "total": "All stars", "chain": "Best tap", "streak": "Streak"}
	for k in LEAGUE_BOARDS.size():
		var r := _league_chip_rect(k)
		var on: bool = LEAGUE_BOARDS[k] == _league_board
		o.draw_rect(r, Style.COIN if on else Style.CARD)
		o.draw_rect(r, Style.INK, false, 2.0 if on else 1.0)
		Style.caps(o, names[LEAGUE_BOARDS[k]], r.get_center(), 11, Style.INK, 0.08)
	var rows := League.board(Progress.league_key, me, League.week_fraction(Progress.league_key), _league_board)
	var y0 := pr.position.y + 330.0
	var k2 := clampf((_clock - _page_at) / 0.6, 0.0, 1.0)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var y := y0 + i * 48.0
		var appear := clampf(k2 * rows.size() - i * 0.5, 0.0, 1.0)
		if appear <= 0.0:
			continue
		var x0 := pr.position.x + 36.0 + 30.0 * (1.0 - appear)
		var rr := Rect2(Vector2(x0 - 8.0, y - 20.0), Vector2(pr.size.x - 56.0, 40.0))
		if bool(row.you):
			o.draw_rect(rr, Color(Style.COIN, 0.35))
			o.draw_rect(rr, Style.INK, false, 1.5)
		# Place: top three in their medal's colour (for the week board).
		if i < 3 and _league_board == "week":
			o.draw_circle(Vector2(x0 + 16.0, y), 14.0, League.MEDAL_COLORS[i])
			o.draw_arc(Vector2(x0 + 16.0, y), 14.0, 0, TAU, 20, Style.INK, 1.5, true)
		Style.text(o, Style.num(800), str(i + 1), Vector2(x0 + 16.0, y - 1.0), 18, Style.INK)
		o.draw_circle(Vector2(x0 + 62.0, y), 15.0, row.color)
		o.draw_arc(Vector2(x0 + 62.0, y), 15.0, 0, TAU, 20, Style.INK, 1.5, true)
		Style.text(o, Style.serif(800, 48), String(row.name).substr(0, 1), Vector2(x0 + 62.0, y - 1.0), 16, Style.on_color(row.color))
		o.draw_string(Style.serif(700, 48), Vector2(x0 + 90.0, y + 8.0), String(row.name), HORIZONTAL_ALIGNMENT_LEFT, -1, Style._grow(22),
			Style.INK)
		var v := int(row[_league_board])
		var vx := rr.end.x - 30.0
		Style.text(o, Style.num(800), Style.commas(v), Vector2(vx - 20.0, y - 1.0), 22, Style.INK)
		match _league_board:
			"week", "total":
				Style.fancy_star(o, Vector2(vx + 10.0, y), 10.0, 1.0)
			"chain":
				_icon_chain(o, Vector2(vx + 10.0, y))
			"streak":
				Style.flame(o, Vector2(vx + 10.0, y + 2.0), 13.0, v)
	var ny := y0 + rows.size() * 48.0 + 8.0
	if not League.stand_in():
		Style.caps(o, "Add friends with Game Center", Vector2(cx, ny + 10.0), 12, Color(Style.INK, 0.5), 0.14)
	elif _league_board == "week":
		# Days left, and your medals so far.
		var dl := HomeView._days_to_monday()
		Style.caps(o, "Medals at the end of the week  ·  %d day%s" % [dl, "" if dl == 1 else "s"], Vector2(cx, ny + 10.0), 12,
			Color(Style.INK, 0.55), 0.1)

## A week just ended with you in the top three: a medal toast and its coins.
func _celebrate_league(delay: float) -> void:
	Progress.roll_league()
	var news: Array = Progress.league_news.duplicate()
	Progress.league_news.clear()
	for k in news.size():
		var rank: int = news[k][0]
		var pay: int = news[k][1]
		_later(delay + k * 2.4, _seq, func():
			fx.toast(["Gold", "Silver", "Bronze"][rank - 1] + " in the league!", pay, League.MEDAL_COLORS[rank - 1], 150.0 + _top)
			Audio.jackpot()
			_later(0.5, _seq, _fly_coins.bind(Vector2(ox + W * 0.5 + 120.0, 150.0 + _top), pay)))

func open_events() -> void:
	_events_tab = "event"
	_overlay = "events"
	_overlay_age = 0.0
	Audio.panel_in()
	_show_overlay_buttons()

func _close_events() -> void:
	_overlay = "title"
	_overlay_age = 1.0
	Audio.panel_out()
	_show_overlay_buttons()

func _claim_week() -> void:
	var c := Progress.claim_week()
	_coin_shown = Progress.coins - c
	_fly_coins(Vector2(ox + W * 0.5, H * 0.4), c)
	Audio.win()
	fx.confetti(get_viewport_rect().size.x, 60)
	_show_overlay_buttons()

## This week's prize track.
func _draw_events(o: Node2D, pr: Rect2) -> void:
	var x0 := pr.position.x + 40.0
	var w := pr.size.x - 80.0
	# Weekly track (below the Event / League tabs).
	var y := pr.position.y + 214.0
	# This week's goal as a picture (cards, stars, big taps or wins), then the
	# days left this week.
	var ic := Vector2(pr.get_center().x - 60.0, y)
	o.draw_set_transform(_o_base + ic * (1.0 - 1.6), 0.0, Vector2(1.6, 1.6))
	match Progress.week_kind():
		"stars":
			for k in 3:
				Style.fancy_star(o, ic + Vector2((k - 1) * 26.0, -4.0 if k == 1 else 0.0), 13.0, 1.0)
		"big":
			_icon_chain(o, ic + Vector2(-8, 0))
			Style.text(o, Style.serif(800, 48), "8+", ic + Vector2(24, 0), 20, Style.INK)
		"wins":
			for k in 2:
				_mini_card(o, ic + Vector2((k - 0.5) * 18.0, 0), Style.CARD, -1, (k - 0.5) * 0.2)
			o.draw_polyline(PackedVector2Array([ic + Vector2(-9, 0), ic + Vector2(-2, 7), ic + Vector2(11, -8)]),
				Style.group_color(2), 5.0, true)
		_:
			for k in 3:
				_mini_card(o, ic + Vector2((k - 1) * 14.0, 0), Style.group_color(k * 3), k * 3, (k - 1) * 0.25)
			for k in 6:
				var a := -PI * 0.5 + (k - 2.5) * 0.35
				o.draw_line(ic + Vector2.from_angle(a) * 36.0, ic + Vector2.from_angle(a) * 46.0, Style.COIN, 3.0)
	o.draw_set_transform(_o_base, 0.0, Vector2.ONE)
	# Days left, with a little clock.
	var dl := HomeView._days_to_monday()
	var cc := Vector2(pr.get_center().x + 50.0, y)
	o.draw_arc(cc, 11.0, 0, TAU, 24, Color(Style.INK, 0.7), 2.5, true)
	o.draw_line(cc, cc + Vector2(0, -7), Color(Style.INK, 0.7), 2.5)
	o.draw_line(cc, cc + Vector2(5, 0), Color(Style.INK, 0.7), 2.5)
	Style.caps(o, "%d day%s" % [dl, "" if dl == 1 else "s"], cc + Vector2(58, 0), 14, Color(Style.INK, 0.7), 0.14)
	var track: Array = Progress.week_track()
	var goal: float = track[-1][0]
	var bar := Rect2(Vector2(x0, y + 62.0), Vector2(w, 16.0))
	o.draw_rect(Rect2(bar.position + Vector2(2, 2), bar.size), Style.INK)
	o.draw_rect(bar, Style.PAPER_DEEP)
	var f := bar
	f.size.x *= clampf(Progress.week_cards / goal, 0.0, 1.0)
	o.draw_rect(f, Style.ACCENT)
	o.draw_rect(bar, Style.INK, false, 1.5)
	for i in track.size():
		var px: float = x0 + w * track[i][0] / goal
		var got: bool = i < Progress.week_claimed
		var reached: bool = Progress.week_cards >= track[i][0]
		Style.coin(o, Vector2(px, y + 70.0), 14.0, 0.35 if got else 1.0)
		Style.caps(o, "%d" % track[i][1], Vector2(px, y + 98.0), 12, Color(Style.INK, 0.4 if got else 1.0), 0.1)
		if reached and not got:
			o.draw_arc(Vector2(px, y + 70.0), 20.0 + 3.0 * sin(_clock * 6.0), 0, TAU, 24, Style.COIN, 3.0, true)
	# Where you are, and the top of the track.
	var now_s := Style.commas(Progress.week_cards)
	var nw := Style.text_width(Style.num(800), now_s, 38)
	var gs := " / " + Style.commas(int(goal))
	var gw := Style.text_width(Style.num(700), gs, 24)
	var x := pr.get_center().x - (nw + gw) * 0.5
	Style.text(o, Style.num(800), now_s, Vector2(x + nw * 0.5, y + 142.0), 38, Style.INK)
	Style.text(o, Style.num(700), gs, Vector2(x + nw + gw * 0.5, y + 146.0), 24, Color(Style.INK, 0.5))

## Lose screen: pay coins for one more tray slot and keep playing. The
## streak you'd lost comes back too.
## Each continue in the same level costs more (60, 120, 180...), so it's a
## lifeline, not an endless cheap retry.
func _continue_cost() -> int:
	return Economy.CONTINUE_COST * (1 + _continues)

func continue_with_slot(free := false) -> void:
	if not free and not _spend(_continue_cost(), Vector2(ox + W * 0.5, H * 0.5)):
		return
	_continues += 1
	board.hold += 1
	board.lost = false
	_vis = board.clone()
	_slot_pulse.resize(board.hold + 1)
	if not _daily:
		Progress.win_streak = _lost_streak
		Progress.save_game()
	_overlay = ""
	_show_overlay_buttons()
	_layout()
	fx.popup("+1 slot", _slot_pos(board.hold - 1) + Vector2(0, -130), Style.ACCENT, 34, 40.0, 1.4, "plain")
	Audio.star(1)
	Playtest.log_line(_level_name(), "continued with +1 slot")

var _intro: Array = []
var _intro_card: CardView

func _open_intro(info: Array) -> void:
	_intro = info
	_overlay = "intro"
	_overlay_age = 0.0
	Audio.panel_in()
	if _intro_card:
		_intro_card.queue_free()
	_intro_card = CardView.new()
	_dress_showcase(_intro_card, info[0])
	_intro_card.face_up = true
	_intro_card.base_scale = 1.7
	_intro_card.scale = Vector2.ONE * 1.7
	_overlay_layer.add_child(_intro_card)
	_intro_card.position = _overlay_rect().position + Vector2(_overlay_rect().size.x * 0.5, 280.0)
	_show_overlay_buttons()

## Sets a card up to show off one kind of thing (for intro cards and the
## How to play pages).
func _dress_showcase(card: CardView, key: String) -> void:
	match key:
		"magnet":
			card.kind = Cascade.Kind.MAGNET
		"bomb":
			card.kind = Cascade.Kind.BOMB
		"wild":
			card.kind = Cascade.Kind.WILD
		"lock":
			card.label = "Teapot"
			card.band = Style.group_color(0)
			card.group = 0
			card.locked = 2
		"peek":
			card.label = "?"
			card.band = Style.INK
		"ice":
			card.label = "Snowman"
			card.band = Style.group_color(1)
			card.group = 1
			card.iced = 2
		"chain":
			card.label = "Anchor"
			card.band = Style.group_color(2)
			card.group = 2
			card.chained = true
		"wrap":
			card.label = "?"
			card.wrapped = true
		"color":
			card.kind = Cascade.Kind.COLOR
		"row":
			card.kind = Cascade.Kind.ROW
		"shuffle":
			card.kind = Cascade.Kind.SHUFFLE
		"rare":
			card.label = "Crown"
			card.band = Style.group_color(3)
			card.group = 3
			card.rare = true

func _close_intro() -> void:
	var key: String = _intro[0]
	Progress.seen[key] = true
	Progress.save_game()
	if _intro_card:
		_intro_card.queue_free()
		_intro_card = null
	_overlay = ""
	Audio.panel_out()
	_show_overlay_buttons()
	_try_show_me()

## Show-me for a new obstacle: after its intro card, a pulsing ring picks out
## the real card on the table and the finger taps what frees it (a card of
## the same colour for ice, a pile next door for a chain, the wrapped card
## itself). Gone on the first tap.
var _showme_card := -1
var _showme_pile := -1

## Checked after the intro card and after every tap: the first time each
## obstacle is on top of a pile (its intro already seen), show it once.
func _try_show_me() -> void:
	if _daily or _showme_card != -1:
		return
	for key in ["ice", "chain", "wrap"]:
		if Progress.seen.has(key) and not Progress.seen.has("showme_" + key) and _show_me(key):
			Progress.seen["showme_" + key] = true
			Progress.save_game()
			return

func _show_me(key: String) -> bool:
	for p in board.piles.size():
		var c := board.top(p)
		if c == -1:
			continue
		var hit := (key == "ice" and board.ice[c] > 0) or (key == "chain" and board.chain[c] > 0) \
			or (key == "wrap" and board.wrapped[c] == 1)
		if not hit:
			continue
		var target := -1
		match key:
			"wrap":
				target = p
			"chain":
				for nb in board.neighbours(p):
					var t := board.top(nb)
					if t != -1 and not board.blocked(t):
						target = nb
						break
			"ice":
				for q in board.piles.size():
					var t := board.top(q)
					if t != -1 and not board.blocked(t) and board.card_kind[t] == Cascade.Kind.CARD \
							and board.card_group[t] == board.card_group[c]:
						target = q
						break
		_showme_card = c
		_showme_pile = target
		return true
	return false

## The top-left label: the level, or today's date on the daily.
func _hud_label() -> String:
	if not _daily:
		return _level_name()
	var d := Time.get_datetime_dict_from_datetime_string(_daily_key + "T12:00:00", true)
	return "%s %d" % [MONTHS[clampi(int(d.get("month", 1)) - 1, 0, 11)], int(d.get("day", 1))]

func _level_name() -> String:
	return "Daily" if _daily else "Level %d" % (level_index + 1)

func _par() -> int:
	return level.solution.size()

## Stars you'd get finishing now: 3 within par+1 taps, 2 within par+3.
func _stars_for(taps: int) -> int:
	return 3 if taps <= _par() + 1 else (2 if taps <= _par() + 3 else 1)

## Chains play slower on the first levels so they can be followed.
func _tempo() -> float:
	if _guided:
		return 2.0
	if level_index < 0:
		return 1.0
	return [1.6, 1.4, 1.25, 1.1][mini(level_index, 3)] if level_index < 4 else 1.0

# ---------------------------------------------------------------- geometry

func _rows() -> int:
	return 1 if board.piles.size() <= 4 else 2

func _pile_pos(p: int) -> Vector2:
	var n := board.piles.size()
	var rows := _rows()
	var per_row := ceili(float(n) / rows)
	var row := p / per_row
	var col := p % per_row
	var in_row := per_row if row < rows - 1 else n - per_row * (rows - 1)
	var gap := 152.0 if per_row <= 4 else 138.0
	var x := ox + W * 0.5 + (col - (in_row - 1) * 0.5) * gap
	# Centre the block of piles between the HUD and the tray, so tall phones
	# don't leave a gap. Never higher than the original spot.
	var block := CARD.y + (rows - 1) * 245.0
	var area_top := 215.0 + _top
	var area_bottom := (H - 320.0 - _bottom) - 290.0 - 30.0
	var first := maxf(area_top + ((area_bottom - area_top) - block) * 0.5 + CARD.y * 0.5,
		(500.0 if rows == 1 else 330.0) + _top * 0.7)
	var y := first + row * 245.0
	return Vector2(x, y)

## Hidden cards peek out above the top card, so you can see how deep a pile is.
## The card under the top sticks out further (PEEK_STEP), nudged right and
## tilted (PEEK_TILT), so it reads as its own card and its colour band can't
## be mistaken for the top card's; the rest peek out PILE_STEP each.
const PEEK_STEP := 32.0
const PEEK_SHIFT := 20.0
const PEEK_TILT := -0.2

func _pile_card_pos(p: int, i: int, n: int) -> Vector2:
	var above := mini(n - 1 - i, 6)
	if above == 1:
		return _pile_pos(p) + Vector2(PEEK_SHIFT, -PEEK_STEP)
	var off := 0.0 if above == 0 else PEEK_STEP + PILE_STEP * (above - 1)
	return _pile_pos(p) + Vector2(0, -off)

## Which face-down cards show their colour: always the one under each top
## card; the one below that too while Peek or X-ray is on.
func _update_peek_bands() -> void:
	if _vis == null:
		return
	var deep := _peeking > 0.0 or _xray
	for v in views:
		v.peek_col = Color(0, 0, 0, 0)
		v.peek_group = -1
		v.peek_mystery = false
	for p in _vis.piles.size():
		var pile: Array = _vis.piles[p]
		for depth in [1, 2]:
			if depth == 2 and not deep:
				break
			if pile.size() <= depth:
				break
			var c: int = pile[pile.size() - 1 - depth]
			var v := views[c]
			if board.card_kind[c] != Cascade.Kind.CARD or board.wrapped[c] == 1:
				v.peek_mystery = true
			else:
				v.peek_col = Style.group_color(board.card_group[c])
				v.peek_group = board.card_group[c]
	for v in views:
		v.queue_redraw()

func _tray_y() -> float:
	var t := clampf((_level_t - BANNER_TIME + 0.05) / 0.5, 0.0, 1.0)
	return H - 320.0 - _bottom + 460.0 * (1.0 - Style.ease_back(t))

## Tray slots, centred; with extra slots (streak, +1 slot, booster) they
## squeeze closer so the tray always fits the screen.
func _slot_pos(j: int) -> Vector2:
	var n := board.hold + 1
	var step := minf(160.0, (W - 60.0 - CARD.x * TRAY_SCALE) / maxf(n - 1, 1))
	return Vector2(ox + W * 0.5 + (j - (n - 1) * 0.5) * step, _tray_y())

func _tray_card_pos(j: int, k: int, n: int) -> Vector2:
	return _slot_pos(j) + Vector2(0, -TRAY_FAN * (n - 1 - k))

## Progress bar: one segment per group, lit in that group's colour.
func _seg_rect(i: int) -> Rect2:
	var n := board.group_count()
	var left := ox + 28.0
	var width := W - 56.0
	var gap := 6.0
	var w := (width - gap * (n - 1)) / n
	return Rect2(Vector2(left + i * (w + gap), 92.0 + _top), Vector2(w, 12.0))

func _pip_pos(i: int) -> Vector2:
	return _seg_rect(i).get_center()

func _coin_hud_pos() -> Vector2:
	return Vector2(ox + W - 210.0, 48.0 + _top)

func _card_rect(center: Vector2, s := 1.0) -> Rect2:
	return Rect2(center - CARD * 0.5 * s, CARD * s)

# ---------------------------------------------------------------- layout

## Puts every card where the shown state says it is.
func _layout(animate := true) -> void:
	var placed := {}
	for p in _vis.piles.size():
		var pile: Array = _vis.piles[p]
		for i in pile.size():
			var v := views[pile[i]]
			placed[v.card] = true
			_place(v, _pile_card_pos(p, i, pile.size()), 10 + i, i == pile.size() - 1, 1.0, animate)
			if i == pile.size() - 2 and not _leaving.has(v.card):
				v.rest_rotation = PEEK_TILT
				if animate:
					create_tween().tween_property(v, "rotation", PEEK_TILT, 0.15)
				else:
					v.rotation = PEEK_TILT
	for j in _vis.tray.size():
		var cards: Array = _vis.tray_cards[_vis.tray[j]]
		for k in cards.size():
			var v := views[cards[k]]
			placed[v.card] = true
			v.rest_rotation = (float((cards[k] * 7919 + 13) % 97) / 96.0 - 0.5) * 0.09
			_place(v, _tray_card_pos(j, k, cards.size()), 400 + k, true, TRAY_SCALE, animate)
	for v in views:
		if not placed.has(v.card) and not _leaving.has(v.card):
			v.visible = false
	_update_peek_bands()
	queue_redraw()

func _place(v: CardView, pos: Vector2, z: int, up: bool, s: float, animate: bool) -> void:
	if _leaving.has(v.card):
		return
	if s >= 1.0:
		v.rest_rotation = 0.0
	v.visible = true
	v.z_index = z
	if not is_equal_approx(v.base_scale, s):
		v.base_scale = s
		if animate:
			create_tween().tween_property(v, "scale", Vector2.ONE * s, 0.2).set_trans(Tween.TRANS_QUAD)
		else:
			v.scale = Vector2.ONE * s
	if up and not v.face_up:
		if animate:
			v.flip_up(0.05)
		else:
			v.set_face(true)
	elif not up and v.face_up:
		v.set_face(false)
	if animate:
		var d := v.position.distance_to(pos)
		v.move_to(pos, clampf(0.12 + d / 2800.0, 0.12, 0.3) * _tempo(), 0.0, clampf(d * 0.15, 0.0, 90.0), s < 1.0 and d > 40.0)
	else:
		v.snap_to(pos)

# ---------------------------------------------------------------- input

func is_busy() -> bool:
	return _clock < _busy_until or _overlay != ""

func _unhandled_input(event: InputEvent) -> void:
	if _exit_t >= 0.0 or _cal_t >= 0.0:
		return
	# Tapping outside a panel closes it (the panel slides away).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var close := _outside_close()
		if close.is_valid() and not _overlay_rect().grow(8).has_point(event.position):
			_leave(close)
			return
	if _overlay == "title" and _home and _turn_t < 0.0:
		_home.handle(event)
		return
	if _overlay == "shop" and _shop:
		_shop.handle(event)
		return
	if _overlay == "prelevel" and event is InputEventMouseButton and event.pressed:
		_pre_click(event.position)
		return
	if _overlay == "settings" and event is InputEventMouseButton and event.pressed:
		_settings_click(event.position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_idle = 0.0
		if _overlay == "win" and event.pressed and _stars_shown < _win_stars:
			_skip_win_count()
			return
		# Tap outside the result card to fold it away and look at the board;
		# tap the tab to bring it back.
		if _overlay == "win" and event.pressed:
			if _can_double() and _double_chip_rect().grow(10).has_point(event.position):
				_watch_double()
				return
			if _win_fold:
				if _win_tab_rect().has_point(event.position):
					_set_win_fold(false)
			elif not _overlay_rect().has_point(event.position):
				_set_win_fold(true)
			return
		if _overlay == "gift":
			_gift_input(event)
			return
		if _overlay == "rules":
			if event.pressed:
				for dir in [-1, 1]:
					if _page_arrow_rect(dir).grow(26).has_point(event.position):
						var np := clampi(_rules_page + dir, 0, _rules_pages() - 1)
						if np != _rules_page:
							_rules_page = np
							_build_rule_cards()
							_slide_page(dir)
							Audio.flip()
			return
		if _overlay == "events":
			if event.pressed:
				_events_click(event.position)
			return
		if _overlay == "pets":
			if event.pressed:
				_pets_click(event.position)
			return
		if _overlay == "album":
			if event.pressed:
				for dir in [-1, 1]:
					if _page_arrow_rect(dir).grow(26).has_point(event.position):
						var pages := _album_pages().size()
						var np := clampi(_album_page + dir, 0, pages - 1)
						if np != _album_page:
							_album_page = np
							_page_at = _clock
							_slide_page(dir)
							Audio.flip()
			return
		var p := to_local(event.position)
		if event.pressed and _overlay == "" and _pet() != "" and _level_t > BANNER_TIME and _pet_rect().grow(10).has_point(p):
			_use_pet()
			return
		if event.pressed and _overlay == "" and not _gift_token.is_empty() and float(_gift_token.gone) < 0.0 \
				and (_gift_token.pos as Vector2).distance_to(p) < 48.0:
			_claim_gift_token()
			return
		if event.pressed and _overlay == "" and _gear_rect().grow(20).has_point(p):
			_spin_gear()
			_later(0.16, _seq, open_settings)
			return
		if event.pressed and _overlay == "" and not _guided:
			if _level_label_rect().grow(14).has_point(p):
				open_map()
				return
		if event.pressed:
			var hit := _pile_at(p)
			if is_busy():
				# A tap during a chain isn't lost: it plays as soon as the chain ends.
				if hit != -1 and _overlay == "":
					_queued_pile = hit
					views[board.piles[hit][-1]].pop(0.06)
					Audio.pick()
				return
			_pressed_pile = hit
			_show_preview(_pressed_pile)
		else:
			var pile := _pressed_pile
			_pressed_pile = -1
			_show_preview(-1)
			# Released on the same pile (with some slack for a wobbly thumb).
			if pile != -1 and _pile_rect(pile).grow(30).has_point(p) and not is_busy():
				tap_pile(pile)
	elif event is InputEventMouseMotion and _overlay == "gift":
		_gift_input(event)
	elif event is InputEventMouseMotion and _pressed_pile != -1:
		# Sliding the finger off the pile cancels the tap, like a real button.
		if not _pile_rect(_pressed_pile).grow(40).has_point(to_local(event.position)):
			_pressed_pile = -1
			_show_preview(-1)

## The whole pile is the tap target: the top card plus the edges of the
## hidden cards peeking out above it, with a generous margin for thumbs.
func _pile_rect(q: int) -> Rect2:
	var n: int = board.piles[q].size()
	var r := _card_rect(_pile_card_pos(q, n - 1, n))
	var above := 0.0 if n <= 1 else PEEK_STEP + 6.0 + PILE_STEP * (mini(n - 1, 6) - 1)
	return Rect2(r.position - Vector2(0, above), r.size + Vector2(0, above)).grow(12)

func _pile_at(p: Vector2) -> int:
	var best := -1
	var best_d := INF
	for q in board.piles.size():
		if board.piles[q].is_empty() or not _pile_rect(q).has_point(p):
			continue
		# Overlapping margins: the nearest pile centre wins.
		var d := p.distance_squared_to(_pile_rect(q).get_center())
		if d < best_d:
			best_d = d
			best = q
	if best == -1:
		return -1
	var tc: int = board.piles[best][-1]
	if board.lock[tc] > 0:
		_locked_nudge(tc)
		return -1
	if _guided and best != int(level.solution[0]):
		views[board.piles[int(level.solution[0])][-1]].pop(0.1)
		return -1
	return best

## A locked card was tapped: it rattles and says what it's waiting for.
func _locked_nudge(c: int) -> void:
	views[c].start_shake()
	Audio.lock_tick()
	var n: int = board.lock[c]
	views[c].pop(0.1)

## While a finger is down on a card, outline everything the tap will grab.
## The cards a tap on p would grab, minus any that would give away a wrapped
## card's colour: tapping a wrapped card only lifts that card, and wrapped
## cards never glow along with a visible colour.
func _in_tray(c: int) -> bool:
	for g in board.tray_cards:
		if board.tray_cards[g].has(c):
			return true
	return false

func _visible_grab(p: int) -> Array:
	var c := board.top(p)
	if c != -1 and board.wrapped[c] == 1:
		return [c]
	return board.grab_preview(p).filter(func(x): return board.wrapped[x] == 0)

func _show_preview(p: int) -> void:
	for c in _preview:
		views[c].set_glow(0.0)
		if views[c].scale.x < views[c].base_scale:
			create_tween().tween_property(views[c], "scale", Vector2.ONE * views[c].base_scale, 0.1)
	_preview = []
	if p == -1:
		queue_redraw()
		return
	_haptic(6)
	_preview = _visible_grab(p)
	for c in _preview:
		views[c].set_glow(1.0)
		views[c].pop(0.05)
	# The card under the finger sinks a little, like a pressed key.
	var top := views[board.piles[p][-1]]
	create_tween().tween_property(top, "scale", Vector2.ONE * 0.95, 0.06)
	Audio.pick()
	queue_redraw()

# ---------------------------------------------------------------- the tap

func tap_pile(p: int) -> void:
	if board.piles[p].is_empty() or _overlay != "":
		return
	_clear_hint()
	if _peeking > 0.0:
		_end_peek()
	fx.fade_popups()
	if not _explain:
		_cap_life = minf(_cap_life, _cap_age + 0.3)
	for v in views:
		v.modulate = Color.WHITE
	_undo.append(board.clone())
	var grabbed := board.grab_preview(p)
	_vis = board.clone()
	var events := board.tap(p)
	Playtest.log_line(_level_name(), "tap %d moved %d bursts %d%s" % [board.taps,
		events.filter(func(e): return e.t in ["pull", "blast"]).size(),
		events.filter(func(e): return e.t == "burst").size(), "  DANGER" if board.in_danger() else ""])
	_jackpot = events.filter(func(e): return e.t in ["pull", "blast"]).size() >= JACKPOT_CARDS
	_goal_best = maxi(_goal_best, Goals.moved(events))
	if Goals.moved(events) >= 8:
		Progress.add_week("big", 1)
	Progress.max_stat("best_tap", Goals.moved(events))
	_seq += 1
	var seq := _seq
	_chain_count = 0
	var end := _schedule(events, grabbed, seq)
	_busy_until = _clock + end + 0.15
	_later(end, seq, _finish_tap.bind(events))
	_refresh_buttons()

## Turns the event list into a timeline. Grabs go almost together; chain
## links speed up as the chain grows; bursts wait for their last card to land.
## Everything stretches by the level's tempo.
func _schedule(events: Array, grabbed: Array, seq: int) -> float:
	var k := _tempo()
	var cursor := 0.0
	var leave := {}
	var initial := 0
	var link := 0
	var bursts := 0
	var last_pull := 0.0
	for e in events:
		match e.t:
			"pull":
				var at: float
				var is_grab: bool = grabbed.has(e.card) and not e.buried
				if is_grab:
					at = initial * 0.06
					initial += 1
					cursor = maxf(cursor, at + 0.26)
				else:
					at = cursor
					cursor += maxf(0.08, 0.2 - link * 0.018)
					link += 1
				leave[e.pile] = at
				last_pull = at
				_later(at * k, seq, _ev_pull.bind(e, is_grab, initial == 1 and is_grab, link))
			"reveal":
				var at: float = leave.get(e.pile, cursor) + 0.1
				_later(at * k, seq, _ev_reveal.bind(e))
				cursor = maxf(cursor, at + 0.14)
			"burst":
				cursor = maxf(cursor, last_pull + 0.3)
				_later(cursor * k, seq, _ev_burst.bind(e, bursts))
				bursts += 1
				cursor += 0.32
			"wild":
				_later(cursor * k, seq, _ev_wild.bind(e))
				cursor += 0.35
			"fire":
				cursor += 0.34
				_later(cursor * k, seq, _ev_fire.bind(e))
				leave[e.pile] = cursor
				cursor += 0.45
			"lock":
				_later(cursor * k, seq, _ev_lock.bind(e))
				cursor += 0.08 if e.left > 0 else 0.3
			"ice":
				_later(cursor * k, seq, _ev_ice.bind(e))
				cursor += 0.08 if e.left > 0 else 0.3
			"unchain":
				_later(cursor * k, seq, _ev_unchain.bind(e))
				cursor += 0.22
			"color":
				_later(cursor * k, seq, _ev_color.bind(e))
				cursor += 0.3
			"shuffle":
				_later(cursor * k, seq, _ev_shuffle.bind(e))
				cursor += 0.4
			"blast":
				_later(cursor * k, seq, _ev_blast.bind(e))
				leave[e.pile] = cursor
				cursor += 0.05
	return (maxf(cursor, last_pull + 0.3) + 0.1) * k

func _ev_pull(e: Dictionary, is_grab: bool, first: bool, link: int) -> void:
	var c: int = e.card
	var pile: Array = _vis.piles[e.pile]
	pile.erase(c)
	if views[c].wrapped:
		# The surprise: the gift paper bursts off as it flies to the tray.
		views[c].wrapped = false
		views[c].flash = 1.0
		views[c].queue_redraw()
		Audio.gift_flip()
		fx.burst(views[c].position, 24, 460.0, [Style.COIN, Style.ACCENT, Style.CARD], 300.0)
	var g: int = e.group
	if not _vis.tray_cards.has(g):
		_vis.tray_cards[g] = []
		_vis.tray.append(g)
		_tag_born[g] = _clock
	_vis.tray_cards[g].append(c)
	var v := views[c]
	v.set_glow(0.0)
	var slot: int = _vis.tray.find(g)
	var col := Style.group_color(g)
	if is_grab:
		if first:
			Audio.grab(1)
			_haptic(10)
			pass
	else:
		# The magnet beam: the tray reaches out and yanks the card in.
		_chain_count += 1
		_chain_pop = 1.0
		_best_chain = maxi(_best_chain, _chain_count + 1)
		if _chain_count >= 3:
			_frame = minf(1.0, 0.4 + _chain_count * 0.1)
			_frame_color = col
			_tint = minf(0.16, 0.04 + _chain_count * 0.02)
			if _bg_mat:
				_bg_mat.set_shader_parameter("tint", col)
		# Why it jumped: its colour is already in the tray. The slot flashes
		# and a thick beam in that colour reaches out and grabs it.
		fx.beam(_slot_pos(slot) + Vector2(0, -50), v.position, col, 0.4, 16.0)
		if slot >= 0 and slot < _slot_pulse.size():
			_slot_pulse[slot] = 1.0
		Audio.link(link)
		_haptic(mini(8 + _chain_count * 2, 22))
		if _jackpot and _chain_count == 4:
			# Something big is happening: slow the rest of the chain down.
			Engine.time_scale = 0.55 * time_scale_base
			Audio.duck(3.0, -12.0)
			Audio.jackpot_build()
		if _chain_count >= 2:
			fx.popup("×%d" % (_chain_count + 1), v.position + Vector2(0, -50), col, 34 + mini(_chain_count, 8) * 3, 50.0, 0.8)
		if e.buried:
			v.flip_up(0.0)
	# Landings late in a long chain throw more sparks.
	var n_sparks := 6 if is_grab else mini(6 + _chain_count * 3, 30)
	fx.burst(v.position, n_sparks, 200.0 + (0.0 if is_grab else minf(_chain_count * 40.0, 400.0)), [col, Style.INK], 0.0)
	if not is_grab:
		_flying[c] = col
	var j := slot
	var count_now: int = _vis.tray_cards[g].size()
	v.on_land = func():
		_flying.erase(c)
		if j < _slot_pulse.size():
			_slot_pulse[j] = 1.0
		# Each card landing in a group rings one step higher than the last.
		Audio.tray_land(count_now)
	_layout()

func _ev_reveal(e: Dictionary) -> void:
	var v := views[e.card]
	v.flip_up(0.0)
	if board.card_kind[e.card] != Cascade.Kind.CARD:
		# Something special is under there: it shakes before it goes off.
		v.set_glow(1.0)
		v.pop(0.25)
		v.start_shake()
		Audio.special_reveal()

func _ev_burst(e: Dictionary, n: int) -> void:
	var g: int = e.group
	Progress.add_week_cards(e.cards.size())
	Progress.add_stat("cards", e.cards.size())
	var col := Style.group_color(g)
	_collect(g)
	var cards: Array = e.cards
	var seg := _lit.size()
	_lit.append(g)
	# The music fills out as the level goes: bass after the first burst, the
	# tune from halfway, the beat for the last group.
	if not cards.is_empty():
		_pet_burst(cards.size())
	if g == _golden_group and _golden_card >= 0:
		# The golden card's group: a gold shower and its bonus.
		var gat := _pip_pos(seg)
		fx.rays(gat, 1.2, 260.0, 16, Style.COIN)
		fx.popup("Golden!  +%d" % Economy.GOLDEN_BONUS, gat + Vector2(0, 60), Style.INK, 30, 30.0, 1.2, "plain")
		Progress.coins += Economy.GOLDEN_BONUS
		_later(0.2, _seq, _fly_coins.bind(gat, Economy.GOLDEN_BONUS))
		_golden_group = -1
	var left := board.group_count() - _lit.size()
	Audio.music_layers(3 if left <= 1 else (2 if _lit.size() * 2 >= board.group_count() else 1))
	if cards.is_empty():
		# Blown away by a bomb: just light its segment.
		if seg < _seg_pop.size():
			_seg_pop[seg] = 1.0
		Audio.star_pip(0)
		fx.burst(_pip_pos(seg), 16, 300.0, [col, Style.INK], 0.0)
		return
	var slot: int = _vis.tray.find(g)
	var at := _slot_pos(maxi(slot, 0)) + Vector2(0, -40)
	if _lit.size() == board.group_count():
		# The burst that finishes the level: a beat of slow motion and a
		# burst of light, like the last move in Candy Crush.
		fx.rays(at, 1.3, 520.0, 20, Style.group_color(g))
		Audio.duck(1.2, -8.0)
		get_tree().create_timer(0.08, true, false, true).timeout.connect(func():
			Engine.time_scale = 0.4 * time_scale_base
			get_tree().create_timer(0.55, true, false, true).timeout.connect(func(): Engine.time_scale = time_scale_base))
	_vis.tray.erase(g)
	_vis.tray_cards.erase(g)
	for c in cards:
		_leaving[c] = true
	Audio.burst(n)
	_haptic(30)
	_hitstop(0.06)
	_punch = 1.0
	_shake = maxf(_shake, 0.5 + 0.12 * n)
	fx.rays(at, 1.0, 360.0 + 40.0 * n, 18, col)
	fx.ring(at, 200.0 + 40.0 * n, col)
	fx.burst(at, 34 + 10 * n, 620.0 + 60.0 * n, [col, Style.INK, Style.COIN, Style.CARD])
	var label_x := clampf(at.x, ox + 190.0, ox + W - 190.0)
	fx.popup(board.group_names[g], Vector2(label_x, at.y - 200.0), col, 46, 50.0, 1.1, "big")
	if _is_rare(g):
		_rare_burst(at)
	for i in cards.size():
		var v := views[cards[i]]
		v.set_gold(1.0)
		v.flash = 0.8
		v.z_index = 850 + i
		var t := create_tween()
		t.tween_property(v, "scale", Vector2.ONE * TRAY_SCALE * 1.15, 0.08)
		t.tween_interval(0.08 + i * 0.04)
		t.set_parallel(true)
		t.tween_property(v, "position", _pip_pos(seg), 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_property(v, "scale", Vector2.ONE * 0.12, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(v, "rotation", (1.0 if i % 2 == 0 else -1.0) * 1.2, 0.38)
		t.set_parallel(false)
		t.tween_callback(func():
			v.visible = false
			if i == cards.size() - 1:
				if seg < _seg_pop.size():
					_seg_pop[seg] = 1.0
				Audio.star_pip(2 * n)
				fx.burst(_pip_pos(seg), 16, 300.0, [col, Style.INK], 0.0)
				var coins := Economy.BURST_COINS * (1 + n)
				Progress.coins += coins
				_fly_coins(_pip_pos(seg), coins))
	_layout()

func _ev_fire(e: Dictionary) -> void:
	var v := views[e.card]
	_vis.piles[e.pile].erase(e.card)
	_leaving[e.card] = true
	var at := v.position
	# Captions stay on screen even when the special sits at an edge.
	# Callouts go in the open space above the tray, clear of the cards.
	var cap := Vector2(ox + W * 0.5, _tray_y() - 225.0)
	_hitstop(0.05)
	_punch = 1.0
	if e.kind == Cascade.Kind.WILD:
		fx.rays(at, 0.8, 300.0, 24, Style.COIN)
	elif e.kind == Cascade.Kind.MAGNET:
		Audio.magnet_fire()
		fx.rays(at, 1.0, 420.0, 20, Style.ACCENT)
		fx.ring(at, 280.0, Style.ACCENT)
		fx.popup("Magnet!", cap + Vector2(0, -130), Style.ACCENT, 58, 40.0, 1.1, "big")
		_shake = maxf(_shake, 0.4)
	elif e.kind == Cascade.Kind.COLOR:
		Audio.bomb_blast()
		Audio.wild()
		fx.rays(at, 1.2, 520.0, 24, Style.COIN)
		fx.burst(at, 80, 1000.0, Style.GROUPS, 300.0)
		fx.popup("Colour bomb!", cap + Vector2(0, -130), Style.INK, 56, 40.0, 1.2, "big")
		fx.confetti(get_viewport_rect().size.x, 60)
		_shake = maxf(_shake, 1.0)
		_haptic(70)
		# A moment of slow motion, like the jackpot, while the colour goes.
		# (Starts just after the freeze-frame above, which resets the speed.)
		Audio.duck(1.4, -10.0)
		get_tree().create_timer(0.08, true, false, true).timeout.connect(func():
			Engine.time_scale = 0.35 * time_scale_base
			get_tree().create_timer(0.7, true, false, true).timeout.connect(func(): Engine.time_scale = time_scale_base))
	elif e.kind == Cascade.Kind.ROW:
		Audio.bomb_blast()
		fx.ring(at, 360.0, Style.ACCENT, 0.5)
		for k in 9:
			fx.burst(Vector2(ox + 40.0 + k * (W - 80.0) / 8.0, at.y), 8, 380.0, [Style.ACCENT, Style.INK], 200.0)
		fx.popup("Row!", cap + Vector2(0, -130), Style.ACCENT, 64, 40.0, 1.1, "big")
		_shake = maxf(_shake, 0.8)
		_haptic(50)
	elif e.kind == Cascade.Kind.SHUFFLE:
		Audio.shuffle_fire()
		fx.ring(at, 300.0, Style.INK, 0.4)
		fx.popup("Shuffle!", cap + Vector2(0, -130), Style.INK, 58, 40.0, 1.1, "big")
		_shake = maxf(_shake, 0.3)
	elif e.kind == Cascade.Kind.BOMB:
		Audio.bomb_blast()
		fx.ring(at, 420.0, Style.ACCENT, 0.55)
		fx.burst(at, 60, 900.0, [Style.ACCENT, Style.INK, Style.COIN], 300.0)
		fx.popup("Boom!", cap + Vector2(0, -130), Style.INK, 64, 40.0, 1.1, "big")
		_shake = maxf(_shake, 1.0)
		_haptic(60)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(v, "scale", Vector2.ONE * 1.6, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(v, "modulate:a", 0.0, 0.3).set_delay(0.12)
	t.set_parallel(false)
	t.tween_callback(func(): v.visible = false)
	_layout()

## The goal tag lands big in the middle of the table, then flies up to its
## place in the top bar.
func _show_goal() -> void:
	_goal_shown = true
	_goal_fly = 1.0
	Audio.panel_in()
	var t := create_tween()
	t.tween_interval(1.1)
	t.tween_property(self, "_goal_fly", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func(): Audio.land())

## After each tap: pays out the moment the goal is met (and it stays met,
## even through an undo), and crosses it out if it can't be met any more.
func _update_goal() -> void:
	if goal.is_empty() or _goal_state == "met":
		return
	var st := Goals.status(goal, board, _goal_best)
	if st == _goal_state:
		return
	_goal_state = st
	_goal_pop = 1.0
	var at := _goal_pos()
	if st == "met":
		Progress.coins += Economy.GOAL_BONUS
		fx.popup("Goal!", at + Vector2(0, 60), Style.COIN, 40, 30.0, 1.2, "big")
		fx.burst(at, 30, 420.0, [Style.COIN, Style.INK, Style.CARD], 0.0)
		Audio.star(2)
		_haptic(30)
		_fly_coins(at, Economy.GOAL_BONUS)
		Playtest.log_line(_level_name(), "goal met (%s)" % goal.kind)
	elif st == "failed":
		Audio.star_lost()
		Playtest.log_line(_level_name(), "goal missed (%s)" % goal.kind)

func _goal_pos() -> Vector2:
	return Vector2(ox + 100.0, 142.0 + _top)     # clear of the progress bar above

## The goal tag: the group's colour and shape (or ×N for a chain) and one
## word. Gold with a tick when met; faded and struck through when missed.
func _draw_goal(o: CanvasItem) -> void:
	if goal.is_empty() or not _goal_shown:
		return
	var home := _goal_pos()
	var mid := Vector2(ox + W * 0.5, H * 0.42)
	var f := _goal_fly
	var at := home.lerp(mid, f)
	var sc := (1.25 + 1.5 * f) * (1.0 + 0.3 * _goal_pop)
	if f > 0.0:
		o.draw_rect(Rect2(Vector2(-4000, -4000), Vector2(8000, 8000)), Color(Style.PAPER, 0.55 * minf(f * 3.0, 1.0)))
	_goal_chip(o, goal, _goal_state, at, sc)

## The goal tag itself, at `at` and size `sc` (also shown on the pre-level panel).
func _goal_chip(o: CanvasItem, g: Dictionary, state: String, at: Vector2, sc: float, base := Vector2.ZERO) -> void:
	o.draw_set_transform(at, 0.0, Vector2(sc, sc))
	var word: String = {"first": "First", "last": "Last", "chain": "Chain"}.get(String(g.kind), "")
	var w := 44.0 + Style.caps_width(word, 11, 0.2) + 16.0
	var r := Rect2(Vector2(-w * 0.5, -16), Vector2(w, 32))
	var met := state == "met"
	var failed := state == "failed"
	var a := 0.4 if failed else 1.0
	o.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(Style.INK, a))
	o.draw_rect(r, Style.COIN if met else Style.CARD)
	o.draw_rect(r, Color(Style.INK, a), false, 2.0)
	var sw := Rect2(r.position + Vector2(4, 4), Vector2(36, 24))
	if String(g.kind) == "chain":
		o.draw_rect(sw, Color(Style.INK, a))
		Style.text(o, Style.serif(800, 48), "×%d" % int(g.n), sw.get_center() + Vector2(0, -1), 16, Color(Style.CARD, a))
	else:
		var col := Style.group_color(int(g.group))
		o.draw_rect(sw, Color(col, a))
		o.draw_rect(sw, Color(Style.INK, a), false, 1.5)
		Style.group_symbol(o, int(g.group), sw.get_center(), 7.0, Color(Style.on_color(col), a))
	Style.caps(o, word, Vector2(sw.end.x + (r.end.x - sw.end.x) * 0.5, 0), 11, Color(Style.INK, a), 0.2)
	if met:
		var c := Vector2(r.end.x - 2, r.position.y + 2)
		o.draw_circle(c + Vector2(2, 2), 11.0, Style.INK)
		o.draw_circle(c, 11.0, Style.CARD)
		o.draw_arc(c, 11.0, 0, TAU, 20, Style.INK, 1.5, true)
		o.draw_polyline(PackedVector2Array([c + Vector2(-5, 0), c + Vector2(-1, 4), c + Vector2(5, -4)]), Style.INK, 2.5, true)
	if failed:
		o.draw_line(Vector2(r.position.x - 4, 0), Vector2(r.end.x + 4, 0), Style.ACCENT, 3.0)
	o.draw_set_transform(base, 0.0, Vector2.ONE)

## A rare group bursting: a shower of gold, a bright run of bells and a
## bonus on top of the usual coins.
func _rare_burst(at: Vector2) -> void:
	var seq := _seq
	Progress.coins += Economy.RARE_BONUS
	fx.rays(at, 1.4, 520.0, 24, Style.COIN)
	fx.burst(at, 70, 900.0, [Style.COIN, Style.CARD, Style.INK], 200.0)
	fx.popup("Rare!", Vector2(ox + W * 0.5, at.y - 290.0), Style.COIN, 60, 40.0, 1.3, "big")
	Audio.jackpot()
	_haptic(50)
	_later(0.7, seq, func(): _fly_coins(at, Economy.RARE_BONUS))

## Album bookkeeping for a burst group: the featured set first (finishing it
## pays out with a banner), then the first time ever it's announced, and every
## few new groups pays out coins.
func _collect(g: int) -> void:
	var gid: String = level.groups[g].get("id", board.group_names[g])
	var seq := _seq
	var in_set: bool = gid in Progress.featured_set().set.groups and not Progress.set_got.has(gid) and not Progress.set_done
	var set_won := Progress.set_burst(gid)
	if in_set:
		var got: int = Progress.featured_set().set.groups.size() - Progress.set_missing().size()
		_later(0.6, seq, func():
			fx.popup("Set %d/%d" % [got, Progress.featured_set().set.groups.size()], Vector2(ox + W * 0.5, 250.0 + _top),
				Style.COIN, 30, 20.0, 1.2, "plain"))
	if set_won > 0:
		# A quick note now; the full ceremony waits for the home screen.
		_set_ceremony = Progress.featured_set().set.name
		_later(1.4, seq, func():
			fx.popup("Set complete!", Vector2(ox + W * 0.5, 250.0 + _top), Style.COIN, 40, 30.0, 1.4, "big")
			Audio.star(2))
	if not Progress.collect(gid):
		return
	_later(0.9, seq, func():
		fx.popup("New!", Vector2(ox + W * 0.5, 200.0 + _top), Style.group_color(g), 30, 20.0, 1.2, "plain")
		Audio.star_pip(4))
	if Progress.album.size() % Economy.ALBUM_REWARD_EVERY == 0:
		Progress.coins += Economy.ALBUM_REWARD
		_later(2.0, seq, func():
			_fly_coins(Vector2(ox + W * 0.5, 190.0 + _top), Economy.ALBUM_REWARD)
			Audio.win())

## The wild card announces which group it will finish; the cards it pulls
## follow as ordinary chain links.
func _ev_wild(e: Dictionary) -> void:
	var g: int = e.group
	if g < 0:
		Audio.card_flung()
		return
	var col := Style.group_color(g)
	var slot: int = _vis.tray.find(g)
	var at := _slot_pos(maxi(slot, 0)) + Vector2(0, -40)
	fx.burst(at, 30, 500.0, Style.GROUPS, 0.0)
	fx.popup("Wild!", Vector2(ox + W * 0.5, _tray_y() - 225.0), col, 58, 40.0, 1.0, "big")
	Audio.wild()

## A burst ticks a lock down; at zero it springs open with a bright chime.
func _ev_lock(e: Dictionary) -> void:
	var v := views[e.card]
	_vis.lock[e.card] = e.left
	v.locked = e.left
	v.queue_redraw()
	if e.left > 0:
		v.pop(0.06)
		Audio.lock_tick()
	else:
		v.unlock_t = 0.0
		v.flash = 0.6
		v.pop(0.14)
		Audio.unlock()
		fx.burst(v.position + Vector2(0, 18), 14, 320.0, [Style.COIN, Style.INK], 0.0)

## Ice cracks when its colour lands in the tray; the last layer shatters.
func _ev_ice(e: Dictionary) -> void:
	var v := views[e.card]
	_vis.ice[e.card] = e.left
	v.iced = e.left
	v.queue_redraw()
	var frost := Color(0.72, 0.88, 0.98)
	if e.left > 0:
		v.pop(0.06)
		Audio.lock_tick()
		fx.burst(v.position, 8, 220.0, [frost, Style.CARD], 0.0)
	else:
		v.flash = 0.8
		v.pop(0.16)
		Audio.unlock()
		_haptic(20)
		fx.burst(v.position, 26, 520.0, [frost, Style.CARD, Color(0.35, 0.62, 0.85)], 300.0)

## A card left the pile next door: the chain snaps and its links fly off.
func _ev_unchain(e: Dictionary) -> void:
	var v := views[e.card]
	_vis.chain[e.card] = 0
	v.chained = false
	v.flash = 0.6
	v.pop(0.14)
	v.queue_redraw()
	Audio.card_flung()
	Audio.unlock()
	_haptic(15)
	fx.burst(v.position, 20, 480.0, [Color("8a9099"), Style.INK], 400.0)

## The colour bomb picks its colour: a flash of that colour across the board.
func _ev_color(e: Dictionary) -> void:
	if e.group < 0:
		return
	var col := Style.group_color(e.group)
	_frame = 1.0
	_frame_color = col
	fx.popup(board.group_names[e.group], Vector2(ox + W * 0.5, _tray_y() - 290.0), col, 46, 40.0, 1.1, "big")

## Shuffle: in each changed pile a card slides out from underneath and lands
## on top, face-up; the old top turns face-down beneath it.
func _ev_shuffle(e: Dictionary) -> void:
	for m in e.moves:
		var q: int = m[0]
		var x: int = m[1]
		var pile: Array = _vis.piles[q]
		if not pile.is_empty() and pile[-1] != x:
			views[pile[-1]].set_face(false)
		pile.erase(x)
		pile.append(x)
		views[x].flip_up(0.05)
		views[x].pop(0.12)
	Audio.grab(2)
	_layout()

func _ev_blast(e: Dictionary) -> void:
	var v := views[e.card]
	_vis.piles[e.pile].erase(e.card)
	_leaving[e.card] = true
	if not v.face_up:
		v.set_face(true)
	Audio.card_flung()
	var dir := Vector2(randf_range(-1.0, 1.0), -1.0).normalized()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(v, "position", v.position + dir * 900.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(v, "rotation", randf_range(-6.0, 6.0), 0.6)
	t.tween_property(v, "modulate:a", 0.0, 0.6)
	t.set_parallel(false)
	t.tween_callback(func(): v.visible = false)
	_layout()

## After the chain: praise it, then check for danger, a loss or a win.
func _finish_tap(events: Array) -> void:
	Engine.time_scale = time_scale_base
	if _jackpot:
		_jackpot = false
		_cascade_moment(events.filter(func(e): return e.t in ["pull", "blast"]).size())
	_vis = board.clone()
	_leaving.clear()
	_flying.clear()
	_layout()
	_update_goal()
	_try_show_me()
	_surprise_after_tap()
	var was_guided := _guided
	_guided = false
	var now := _stars_for(board.taps + (0 if board.is_won() else 1))
	if now < _stars_now and not board.is_won():
		_stars_now = now
		_star_drop = 1.0
		Audio.star_lost()
		if not Progress.seen_star_tip:
			Progress.seen_star_tip = true
			Progress.save_game()
			pass
	_explain = level_index == 0 and board.taps < 2
	var moved := events.filter(func(e): return e.t in ["pull", "blast"]).size()
	var bursts := events.filter(func(e): return e.t == "burst").size()
	var tier := -1
	for i in PRAISE.size():
		if moved >= PRAISE[i][0] or bursts >= i + 2:
			tier = i
	if tier >= 0:
		var words: Array = PRAISE[tier][1]
		var word: String = words[randi() % words.size()]
		fx.popup(word, Vector2(ox + W * 0.5, _tray_y() - 330.0), Style.ACCENT, 72 + tier * 8, 50.0, 1.3, "big")
		var detail := "%d cards in one tap" % moved
		if bursts >= 2:
			detail = ["", "", "Double burst", "Triple burst", "Quadruple burst"][mini(bursts, 4)] + "  ·  " + detail
		fx.popup("×%d" % moved, Vector2(ox + W * 0.5, _tray_y() - 262.0), Style.INK, 40, 40.0, 1.2, "plain")
		Audio.combo(tier)
		_punch = 1.0
		var bonus := Economy.PRAISE_COINS * (tier + 1) * (2 if _pet() == "parrot" else 1)
		if moved >= 8:
			_pet_say("cheer")
		Progress.coins += bonus
		_fly_coins(Vector2(ox + W * 0.5, _tray_y() - 330.0), bonus)
	if bursts > 0:
		_streak += 1
		if _streak >= 2:
			_streak_pop = 1.0
			var bonus := Economy.STREAK_COINS * _streak
			Progress.coins += bonus
			_later(0.35, _seq, func():
				_fly_coins(Vector2(ox + W - 60.0, 128.0 + _top), bonus)
				Audio.streak_up(_streak))
	else:
		_streak = 0
	if board.is_won():
		_finale()
	elif board.is_lost():
		_later(0.4, _seq, _show_lose)
	elif board.in_danger():
		Audio.danger()
		_haptic(50)
		_pet_say("danger", true)
	elif was_guided:
		pass
	_refresh_buttons()

## One caption at a time: a new one replaces the old, which fades out.
## The level is cleared: the progress bar lights up segment by segment on a
## rising scale, a few bursts go off in the groups' colours, then the results.
func _finale() -> void:
	var seq := _seq
	_busy_until = _clock + 99.0
	for i in _lit.size():
		_later(0.25 + i * 0.08, seq, func():
			if i < _seg_pop.size():
				_seg_pop[i] = 1.0
			Audio.note(i + 3, 0, -9.0)
			fx.burst(_pip_pos(i), 8, 240.0, [Style.group_color(_lit[i]), Style.INK], 0.0))
	var t := 0.35 + _lit.size() * 0.08
	for k in 4:
		_later(t + k * 0.22, seq, func():
			var at := Vector2(ox + randf_range(140.0, W - 140.0), randf_range(260.0, 620.0))
			var col := Style.group_color(_lit[randi() % maxi(_lit.size(), 1)] if not _lit.is_empty() else k)
			fx.burst(at, 40, 700.0, [col, Style.INK, Style.COIN, Style.CARD])
			fx.ring(at, 180.0, col)
			Audio.burst(k)
			_punch = 1.0
			_haptic(25))
	var end := t + 4 * 0.22 + 0.5
	end += _spare_bonus(end - 0.3, seq)
	_later(end, seq, _show_win)

## End-of-level bonus (like Candy Crush's Sugar Crush): every tap left under
## the 2-star limit flies out of the star meter and bursts into coins, on a
## rising scale. Returns how long it takes.
func _spare_bonus(at: float, seq: int) -> float:
	var spare := mini(_par() + 3 - board.taps, 8)
	if spare <= 0:
		return 0.0
	var from := Vector2(ox + W - 60.0, 127.0 + _top)
	_later(at, seq, func():
		fx.banner("Bonus!", "%d spare tap%s" % [spare, "" if spare == 1 else "s"], Vector2(ox + W * 0.5, H * 0.3), 0.9 + spare * 0.2)
		Audio.combo(2))
	for k in spare:
		_later(at + 0.35 + k * 0.2, seq, func():
			var to := Vector2(ox + randf_range(120.0, W - 120.0), randf_range(300.0, 700.0) + _top)
			fx.ring(from, 60.0, Style.COIN, 0.3)
			fx.rays(to, 0.6, 220.0, 12, Style.COIN)
			fx.burst(to, 55, 760.0, [Style.COIN, Style.CARD, Style.ACCENT], 300.0)
			_punch = 0.5
			fx.popup("+%d" % Economy.SPARE_COINS, to + Vector2(0, -40), Style.INK, 30, 30.0, 0.8, "plain")
			Audio.note(k + 5, 0, -8.0)
			_haptic(12)
			Progress.coins += Economy.SPARE_COINS
			_fly_coins(to, Economy.SPARE_COINS))
	Playtest.log_line(_level_name(), "spare-tap bonus x%d" % spare)
	return 0.45 + spare * 0.2

## The jackpot: a single tap moved a huge number of cards.
func _cascade_moment(moved: int) -> void:
	var c := Vector2(ox + W * 0.5, H * 0.42)
	fx.rays(c, 1.8, 700.0, 24, Style.COIN)
	fx.ring(c, 420.0, Style.ACCENT, 0.7)
	fx.confetti(get_viewport_rect().size.x, 120)
	# The first jackpot of a level pays in full; later ones pay less, so
	# levels packed with specials don't flood the game with coins.
	var pay := Economy.JACKPOT_BONUS if _jackpots == 0 else Economy.JACKPOT_REPEAT
	Progress.add_stat("jackpots", 1)
	_jackpots += 1
	fx.banner("Cascade!", "%d cards in one tap  ·  +%d coins" % [moved, pay], c, 2.0)
	Audio.key_up()
	_punch = 1.0
	_shake = maxf(_shake, 0.8)
	_haptic(80)
	Audio.jackpot()
	Progress.coins += pay
	for k in 3:
		_later(0.25 + k * 0.18, _seq, func():
			_fly_coins(Vector2(ox + randf_range(120.0, W - 120.0), c.y + randf_range(-80.0, 80.0)), pay / 3))

func _caption(s: String, life := 2.6) -> void:
	if _cap_text != "" and _cap_age < _cap_life:
		_cap_old = _cap_text
		_cap_old_age = 0.0
	_cap_text = s
	_cap_age = 0.0
	_cap_life = life

func _draw_caption() -> void:
	var cl := _caption_layer
	if _guided and _clock > _busy_until and _overlay == "":
		_draw_spotlight(cl)
	if _overlay == "":
		_draw_peek_tags(cl)
		_draw_gift_token(cl)
		_draw_pet_line(cl)
		_draw_streak_chip(cl)
		_draw_goal(cl)
	var y := 172.0 + _top
	if _cap_old != "" and _cap_old_age < 0.2:
		var a := 1.0 - _cap_old_age / 0.2
		Style.text(cl, Style.serif(700, 72), _cap_old, Vector2(ox + W * 0.5, y - 14.0 * (1.0 - a)), 30, Color(Style.INK, a))
	if _cap_text == "" or _cap_age >= _cap_life:
		return
	var a_in := clampf(_cap_age / 0.2, 0.0, 1.0)
	var a_out := clampf((_cap_life - _cap_age) / 0.3, 0.0, 1.0)
	var a := minf(a_in, a_out)
	var fit := 34 if Progress.large_text else 30
	while fit > 18 and Style.text_width(Style.serif(700, 72), _cap_text, fit) > W - 60.0:
		fit -= 1
	var pos := Vector2(ox + W * 0.5, y + 10.0 * (1.0 - a_in))
	# A strip of paper behind the words, so they read over the cards.
	var tw := Style.text_width(Style.serif(700, 72), _cap_text, fit) + 36.0
	cl.draw_rect(Rect2(pos - Vector2(tw * 0.5, fit * 0.8), Vector2(tw, fit * 1.6)), Color(Style.PAPER, 0.92 * a))
	Style.text(cl, Style.serif(700, 72), _cap_text, pos, fit, Color(Style.INK, a))

func _color_word(g: int) -> String:
	return ["Red", "Blue", "Green", "Yellow", "Purple", "Pink", "Turquoise", "Brown", "Olive", "Orange", "Slate", "Sky"][posmod(g, 12)]

# ---------------------------------------------------------------- helpers

func _fly_coins(from: Vector2, total: int) -> void:
	var n := clampi(total / 2, 1, 12)
	var landed := [0]
	fx.coins(from, _coin_hud_pos(), n, func():
		landed[0] += 1
		_coin_shown = Progress.coins if landed[0] >= n else mini(_coin_shown + ceili(float(total) / n), Progress.coins)
		_coin_pop = 1.0
		Audio.coin(landed[0]))

func _later(delay: float, seq: int, f: Callable) -> void:
	if delay <= 0.0:
		if seq == _seq:
			f.call()
		return
	get_tree().create_timer(delay).timeout.connect(func():
		if seq == _seq:
			f.call())

func _hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05 * time_scale_base
	get_tree().create_timer(seconds / maxf(time_scale_base, 1.0), true, false, true).timeout.connect(
		func(): Engine.time_scale = time_scale_base)

## Short buzzes are also soft ones: a card landing is a tick, a jackpot is a thump.
func _haptic(ms: int) -> void:
	if Progress.haptics and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, clampf(0.25 + ms / 80.0, 0.25, 1.0))

## Coins buy more once the free ones run out. Returns false if too poor.
func _spend(cost: int, from: Vector2) -> bool:
	if Progress.coins < cost:
		_coin_warn = 1.0
		Audio.wrong()
		return false
	Progress.coins -= cost
	_spent_in_level += cost
	Progress.save_game()
	_coin_shown = Progress.coins
	_coin_pop = 1.0
	fx.coins(_coin_hud_pos(), from, mini(cost / 10, 6))
	Audio.coins_burst()
	return true

func undo(free := false) -> bool:
	_queued_pile = -1
	if _undo.is_empty() or _overlay == "win":
		return false
	if free:
		undos_left += 1      # the pet's undo doesn't use one of yours
	elif undos_left <= 0:
		if not _spend(Economy.UNDO_COST, _undo_btn.position + _undo_btn.size * 0.5):
			return false
		undos_left += 1
	_seq += 1
	Engine.time_scale = time_scale_base
	board = _undo.pop_back()
	_vis = board.clone()
	undos_left -= 1
	_lit = board.done.duplicate()
	if _goal_state == "failed":
		_goal_state = Goals.status(goal, board, _goal_best)
	_busy_until = 0.0
	_leaving.clear()
	_overlay = ""
	_show_overlay_buttons()
	for v in views:
		v.reset_look()
		v.rotation = 0.0
		v.locked = board.lock[v.card]
		v.iced = board.ice[v.card]
		v.chained = board.chain[v.card] > 0
		v.wrapped = board.wrapped[v.card] == 1 and not _in_tray(v.card)
		v.unlock_t = -1.0
	# Rewind: cards fly back along arcs, with a sweep of dust and a caption.
	_layout()
	for p in board.piles.size():
		if not board.piles[p].is_empty():
			fx.puff(_pile_pos(p) + Vector2(0, CARD.y * 0.5), 90.0)
	Playtest.log_line(_level_name(), "used undo")
	Audio.undo()
	Audio.rewind()
	_refresh_buttons()
	return true

## Peek: for a few seconds a tag under each pile names the card beneath the
## top one, in its group's colour. Costs coins; it's for the tight spots.
func peek(free := false) -> bool:
	if is_busy() or _peeking > 0.0:
		return false
	if not free and not _spend(Economy.PEEK_COST, _peek_btn.position + _peek_btn.size * 0.5):
		return false
	_peeking = PEEK_SECONDS
	_update_peek_bands()
	Audio.page_turn()
	_refresh_buttons()
	return true

func _end_peek() -> void:
	_peeking = 0.0
	_update_peek_bands()
	_refresh_buttons()

## Hint: find a winning line from here (the quick peeking player first, then
## a proper search), point at its first tap. Coins are only taken when a hint
## is actually shown; if there's truly no way forward, Undo bobs instead.
func hint(free := false) -> bool:
	if is_busy():
		return false
	if not free and hints_left <= 0 and Progress.coins < Economy.HINT_COST:
		_coin_warn = 1.0
		Audio.wrong()
		return false
	var sol := Cascade.quick_solve(board, 16, board.taps + 1)
	if sol.is_empty():
		sol = Cascade.solve(board, 20000)
	if sol.is_empty():
		_undo_btn.bob_enabled = true
		get_tree().create_timer(2.5).timeout.connect(func():
			_undo_btn.bob_enabled = false
			_undo_btn.scale = Vector2.ONE)
		Audio.wrong()
		return false
	if free:
		pass                 # the pet's hint doesn't use one of yours
	else:
		if hints_left <= 0:
			if not _spend(Economy.HINT_COST, _hint_btn.position + _hint_btn.size * 0.5):
				return false
			hints_left += 1
		hints_left -= 1
	Playtest.log_line(_level_name(), "used hint")
	Audio.hint()
	_hint_pile = sol[0]
	for c in _visible_grab(_hint_pile):
		views[c].set_glow(1.0)
		views[c].pop(0.1)
		views[c].start_sheen()
	_refresh_buttons()
	return true

func _clear_hint() -> void:
	_showme_card = -1
	_showme_pile = -1
	if _hint_pile == -1:
		return
	_hint_pile = -1
	for v in views:
		if v.glow > 0.0:
			v.set_glow(0.0)

# ---------------------------------------------------------------- winning and losing

func _show_win() -> void:
	if _overlay == "win":
		return
	var seq := _seq
	_win_stars = _stars_for(board.taps)
	Playtest.log_line(_level_name(), "WIN taps %d stars %d time %ds" % [board.taps, _win_stars, Playtest.seconds_in_level()])
	_perfect = board.taps <= _par()
	_new_best = _win_stars > Progress.cascade_stars(level_index)
	_win_coins = 20 + 10 * _win_stars + (25 if _perfect else 0)
	if level.get("boss", false):
		_win_coins *= 2
	if _lucky:
		# Lucky coins doubles everything earned in this level, win included.
		_win_coins = _win_coins * 2 + maxi(Progress.coins - _coins_at_start + _spent_in_level, 0)
	if _pet() == "squirrel":
		_win_coins += _win_coins / 2      # the Squirrel's stash: +50%
	_pet_say("win", true)
	if _daily:
		_new_best = _win_stars > int(Progress.daily.get(_daily_key, 0))
		Progress.finish_daily(_daily_key, _win_stars, _win_coins)
	else:
		var before := Progress.cascade_level
		Progress.win_streak += 1
		Progress.finish_cascade(level_index, _win_stars, _win_coins)
		if Progress.cascade_level > before and Progress.cascade_level < levels.size():
			_fresh_unlock = Progress.cascade_level
	Progress.add_week("stars", _win_stars)
	Progress.add_league_stars(_win_stars)
	Progress.add_week("wins", 1)
	_overlay = "win"
	_overlay_age = 0.0
	_ad_doubled = false
	_check_stamps(2.8)
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
			_shake = maxf(_shake, 0.35))
	var count_start := 0.55 + _win_stars * 0.32 + 0.2
	for k in 18:
		_later(count_start + k * 0.04, seq, func():
			_win_coins_shown = int(round(float(_win_coins) * (k + 1) / 18.0))
			Audio.coin(k))
	_later(count_start + 0.8, seq, func():
		_coin_shown = Progress.coins
		_coin_pop = 1.0)

## Impatient tap on the results card: show everything at once.
## Rewarded ad on the win card: from level 20, once the coins have counted up.
func _can_double() -> bool:
	return Ads.available() and not _ad_doubled and _overlay == "win" and (_daily or level_index >= Economy.AD_FROM_LEVEL) \
		and _win_coins_shown >= _win_coins and _win_coins > 0 and not _win_fold

func _double_chip_rect() -> Rect2:
	var pr := _overlay_rect()
	return Rect2(Vector2(pr.get_center().x + 92.0, pr.position.y + 276.0), Vector2(96, 48))

func _watch_double() -> void:
	Ads.show_rewarded(_ad_double)

## The ad finished: the win's coins double, with a shower.
func _ad_double() -> void:
	if _ad_doubled:
		return
	_ad_doubled = true
	var extra := _win_coins
	Progress.coins += extra
	Progress.save_game()
	_win_coins *= 2
	var tw := create_tween()
	tw.tween_property(self, "_win_coins_shown", _win_coins, 0.6)
	var at := _double_chip_rect().get_center()
	fx.burst(at, 40, 600.0, [Style.COIN, Style.CARD, Style.ACCENT], 300.0)
	fx.rays(at, 1.0, 240.0, 14, Style.COIN)
	Audio.jackpot()
	_haptic(40)
	_fly_coins(at, extra)
	Playtest.log_line(_level_name(), "watched an ad: x2 coins")

func _draw_double_chip(o: Node2D) -> void:
	if not _can_double() and not (_ad_doubled and _overlay == "win"):
		return
	var r := _double_chip_rect()
	var t := clampf((_overlay_age - 2.4) / 0.3, 0.0, 1.0) if not _ad_doubled else 1.0
	if t <= 0.0:
		return
	var bob := sin(_clock * 4.5) * 2.0 if not _ad_doubled else 0.0
	o.draw_set_transform(_o_base + r.get_center() + Vector2(0, bob), -0.05, Vector2.ONE * Style.ease_back(t))
	var rr := Rect2(-r.size * 0.5, r.size)
	if _ad_doubled:
		Style.caps(o, "×2", Vector2.ZERO, 18, Style.ACCENT, 0.1)
	else:
		Style.printed(o, rr, Style.COIN, 4.0, 2, 3)
		var pc := Vector2(-24, 0)
		o.draw_circle(pc, 13.0, Style.INK)
		o.draw_colored_polygon(PackedVector2Array([pc + Vector2(-4, -7), pc + Vector2(7, 0), pc + Vector2(-4, 7)]), Style.COIN)
		Style.text(o, Style.num(800), "×2", Vector2(18, -1), 24, Style.INK)
	o.draw_set_transform(_o_base, 0.0, Vector2.ONE)

func _skip_win_count() -> void:
	_seq += 1
	_stars_shown = _win_stars
	for i in _win_stars:
		_star_slam[i] = 0.4
	_win_coins_shown = _win_coins
	_coin_shown = Progress.coins
	_coin_pop = 1.0
	Audio.star(_win_stars - 1)

func _show_lose() -> void:
	if _overlay != "":
		return
	Playtest.log_line(_level_name(), "LOSE after %d taps, %d of %d groups, time %ds" % [board.taps, board.done.size(),
		board.group_count(), Playtest.seconds_in_level()])
	_overlay = "lose"
	_overlay_age = 0.0
	fx.fade_popups()     # praise words from the last tap mustn't float over the card
	_lost_streak = Progress.win_streak
	if not _daily:
		# A Streak shield (from the shop) keeps a streak of 2+ through one loss.
		if Progress.win_streak >= 2 and _pet() == "hedgehog" and not _pet_shield_used:
			# The Hedgehog curls around your streak (once a level).
			_pet_shield_used = true
			_lost_streak = 0
			fx.popup("Streak saved", Vector2(ox + W * 0.5, 200.0 + _top), Style.ACCENT, 40, 30.0, 1.6, "big")
			Playtest.log_line(_level_name(), "hedgehog kept the streak")
		elif Progress.win_streak >= 2 and Progress.use_booster("shield"):
			_lost_streak = 0
			fx.popup("Streak saved", Vector2(ox + W * 0.5, 200.0 + _top), Style.ACCENT, 40, 30.0, 1.6, "big")
			Playtest.log_line(_level_name(), "streak shield used")
		else:
			Progress.win_streak = 0
		Progress.save_game()
	Audio.lose()
	Audio.panel_in()
	_pet_say("lose", true)
	_show_overlay_buttons()

func _star_pos(i: int) -> Vector2:
	var pr := _overlay_rect()
	return Vector2(pr.get_center().x + (i - 1) * 110.0, pr.position.y + 212.0 - (16.0 if i == 1 else 0.0))

## After a few quiet seconds the most rewarding tap gently calls for attention:
## its cards nudge up and catch the light, every few seconds, until touched.
func _update_idle(delta: float) -> void:
	if _overlay != "" or is_busy() or _guided or board.is_won():
		_idle = 0.0
		return
	_idle += delta
	if _idle >= 12.0 and not _pet_idle_said:
		_pet_idle_said = true
		_pet_say("idle")
	if _idle < 7.0:
		return
	_idle_pulse -= delta
	if _idle_pulse > 0.0:
		return
	_idle_pulse = 3.2
	var best := -1
	var most := 0
	for p in board.choices():
		if board.would_crowd(p):
			continue
		var n := _visible_grab(p).size()
		if n > most:
			most = n
			best = p
	if best == -1:
		return
	for c in _visible_grab(best):
		views[c].pop(0.07)
		views[c].start_sheen()

# ---------------------------------------------------------------- settings and level map

func _gear_rect() -> Rect2:
	return Rect2(Vector2(ox + W - 64.0, 22.0 + _top), Vector2(48, 48))

func _level_label_rect() -> Rect2:
	return Rect2(Vector2(ox + 16.0, 24.0 + _top), Vector2(170, 48))

var _settings_from := ""

func open_settings() -> void:
	# (is_busy() is true whenever a panel is up, so only check it in a level.)
	if _overlay not in ["", "title"] or (_overlay == "" and is_busy()):
		return
	_settings_from = _overlay
	_overlay = "settings"
	_overlay_age = 0.0
	Audio.panel_in()
	_show_overlay_buttons()

## The level label in a level leads back to the map.
func open_map() -> void:
	if _overlay not in ["", "win", "settings"] or is_busy():
		return
	_turn(_go_home)

var _rules_from := ""
var _gift: Dictionary = {}
var _gift_open := 0.0            ## 0..1 how far the gift card has flipped
var _gift_cut := 0.0             ## 0..1 the ribbon falling away after the cut
var _gift_cut_y := 0.0           ## where the cut crossed the card (card space)
var _gift_trail: Array[Vector2] = []
var _gift_taps := 0              ## taps without a swipe; three taps opens it anyway

func _open_gift() -> void:
	if _overlay != "title":
		return
	_gift = Progress.gift_today()
	if _gift.is_empty():
		return
	_overlay = "gift"
	_overlay_age = 0.0
	_gift_open = 0.0
	_gift_cut = 0.0
	_gift_trail.clear()
	_gift_taps = 0
	Audio.panel_in()
	_show_overlay_buttons()

const GIFT_SCALE := 1.6

## The big gift card in screen space (it has landed by the time you can swipe).
func _gift_card_rect() -> Rect2:
	var pr := _overlay_rect()
	var cc := Vector2(pr.get_center().x, pr.position.y + 390.0)
	var half := Vector2(62, 86) * GIFT_SCALE
	return Rect2(cc - half, half * 2.0)

## Swipe across the card to cut the ribbon. A plain tap shows how; the third
## tap opens it anyway, so nobody gets stuck.
func _gift_input(event: InputEvent) -> void:
	if _gift_cut > 0.0 or _overlay_age < 0.45:
		return
	var r := _gift_card_rect()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_gift_trail = [event.position]
		else:
			var was_swipe := _gift_trail.size() > 3
			_gift_trail.clear()
			if not was_swipe and r.grow(20).has_point(event.position):
				_gift_taps += 1
				_overlay_age = maxf(_overlay_age, 1.2)   # show the swipe hint now
				views_nudge_gift()
				if _gift_taps >= 3:
					_cut_gift(0.0)
	elif event is InputEventMouseMotion and not _gift_trail.is_empty():
		_gift_trail.append(event.position)
		if _gift_trail.size() == 4:
			Audio.gift_swipe()
		var min_x := INF
		var max_x := -INF
		var ys := 0.0
		var n := 0
		for pt in _gift_trail:
			if pt.y > r.position.y and pt.y < r.end.y:
				min_x = minf(min_x, pt.x)
				max_x = maxf(max_x, pt.x)
				ys += pt.y
				n += 1
		# Crossed the ribbon and most of the card's width: that's a cut.
		if n > 0 and min_x < r.get_center().x - r.size.x * 0.3 and max_x > r.get_center().x + r.size.x * 0.3:
			_cut_gift((ys / n - r.get_center().y) / GIFT_SCALE)
		_overlay_draw.queue_redraw()

func views_nudge_gift() -> void:
	Audio.lock_tick()
	_shake = maxf(_shake, 0.25)

func _cut_gift(cut_y: float) -> void:
	_gift_cut_y = clampf(cut_y, -70.0, 70.0)
	_gift_cut = 0.001
	Audio.gift_cut()
	_haptic(40)
	var r := _gift_card_rect()
	fx.burst(Vector2(r.get_center().x, r.get_center().y + _gift_cut_y * GIFT_SCALE), 26, 520.0,
		[Style.ACCENT, Style.COIN, Style.INK, Style.CARD], 400.0)
	_later(0.25, _seq, func(): _gift_trail.clear())
	var tw := create_tween()
	tw.tween_property(self, "_gift_cut", 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_claim_gift)

func _claim_gift() -> void:
	if _gift_open > 0.0:
		return
	var coins := Progress.claim_gift()
	_gift_open = 0.001
	var tw := create_tween()
	tw.tween_property(self, "_gift_open", 1.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.gift_flip()
	_later(0.3, _seq, func():
		Audio.win()
		fx.confetti(get_viewport_rect().size.x, 70)
		_fly_coins(Vector2(ox + W * 0.5, H * 0.45), coins))
	_gift_coins = coins
	if Ads.available():
		# Offer "watch for x2" instead of closing by itself.
		_later(0.9, _seq, _show_overlay_buttons)
	else:
		_later(2.4, _seq, _close_gift)
	_show_overlay_buttons()

var _gift_coins := 0
var _gift_doubled := false

func _close_gift() -> void:
	_gift_doubled = false
	_overlay = "title"
	_overlay_age = 1.0
	_show_overlay_buttons()

func _watch_gift_double() -> void:
	Ads.show_rewarded(func():
		_gift_doubled = true
		Progress.coins += _gift_coins
		Progress.save_game()
		fx.confetti(get_viewport_rect().size.x, 60)
		Audio.jackpot()
		_fly_coins(Vector2(ox + W * 0.5, H * 0.45), _gift_coins)
		_show_overlay_buttons()
		_later(1.8, _seq, _close_gift))
var _album_from := ""
var _album_page := 0
const ALBUM_PER_PAGE := 12

var _page_at := 0.0              ## when the current album page appeared (stats roll up, medals shine)

func open_album() -> void:
	_page_at = _clock
	_album_from = _overlay
	_overlay = "album"
	_overlay_age = 0.0
	_album_page = 0
	Audio.panel_in()
	_show_overlay_buttons()

func _close_album() -> void:
	_overlay = _album_from if _album_from == "title" else ""
	_overlay_age = 0.5
	Audio.panel_out()
	_show_overlay_buttons()

## Page 1 is the featured set, then every ordinary group, then the rare ones.
## Each group page lists [group, colour index, rare?].
func _album_pages() -> Array:
	var pages: Array = [{"kind": "set"}]
	var normal := LevelGen.load_groups()
	for start in range(0, normal.size(), ALBUM_PER_PAGE):
		var items := []
		for i in range(start, mini(start + ALBUM_PER_PAGE, normal.size())):
			items.append([normal[i], i, false])
		pages.append({"kind": "groups", "items": items})
	var rare := LevelGen.load_rare()
	var items := []
	for i in rare.size():
		items.append([rare[i], i * 3 + 1, true])
	pages.append({"kind": "rare", "items": items})
	pages.append({"kind": "stamps"})
	pages.append({"kind": "stats"})
	return pages

## Where the i-th tile of the current page goes (3 across).
func _album_tile(i: int) -> Rect2:
	var pr := _overlay_rect()
	var size := Vector2(172, 132)
	var gap := Vector2(14, 14)
	var x0 := pr.get_center().x - (3 * size.x + 2 * gap.x) * 0.5
	return Rect2(Vector2(x0 + (i % 3) * (size.x + gap.x), pr.position.y + 196.0 + (i / 3) * (size.y + gap.y)), size)

## How to play: page 1 is the four basic rules; the next pages show every
## special card, obstacle and booster as a card with a few words. Ones not
## reached yet are face-down with the level they arrive on.
var _rules_page := 0
var _rules_cards: Array[CardView] = []
const RULES_PER_PAGE := 6

func _rule_items() -> Array:
	var keys: Array = INTROS.keys()
	keys.sort()
	var items := []
	for k in keys:
		items.append([INTROS[k][0], int(k), String(INTROS[k][2])])
	items.insert(3, ["rare", 5, "Gold edge, big bonus"])
	return items

func _rules_pages() -> int:
	return 1 + ceili(float(_rule_items().size()) / RULES_PER_PAGE)

func open_rules() -> void:
	_rules_from = _overlay
	_overlay = "rules"
	_overlay_age = 0.0
	_rules_page = 0
	Audio.panel_in()
	_show_overlay_buttons()
	_build_rule_cards()

func _build_rule_cards() -> void:
	for c in _rules_cards:
		c.queue_free()
	_rules_cards.clear()
	if _rules_page == 0:
		return
	var items := _rule_items()
	for i in range((_rules_page - 1) * RULES_PER_PAGE, mini(_rules_page * RULES_PER_PAGE, items.size())):
		var card := CardView.new()
		_dress_showcase(card, items[i][0])
		card.face_up = Progress.cascade_level >= int(items[i][1])
		card.base_scale = 0.9
		card.scale = Vector2.ONE * 0.9
		_overlay_layer.add_child(card)
		_rules_cards.append(card)

func _rule_tile_center(k: int) -> Vector2:
	var pr := _overlay_rect()
	return Vector2(pr.get_center().x + (k % 3 - 1) * 170.0, pr.position.y + 250.0 + (k / 3) * 250.0)

func _close_rules() -> void:
	for c in _rules_cards:
		c.queue_free()
	_rules_cards.clear()
	_overlay = _rules_from if _rules_from in ["title", "settings"] else ""
	_overlay_age = 0.5
	Audio.panel_out()
	_show_overlay_buttons()

func _go_home() -> void:
	Audio.music_theme("ch%d" % posmod(mini(Progress.cascade_level, levels.size() - 1) / 10, 10))
	Audio.music_layers(2)
	_overlay = "title"
	_overlay_age = 1.0
	_show_overlay_buttons()
	if _fresh_unlock >= 0:
		_home.celebrate(_fresh_unlock)
		_fresh_unlock = -1
	else:
		_home.focus(mini(Progress.cascade_level, levels.size() - 1))
	_check_stamps(1.0)
	_celebrate_streak(1.2)
	_celebrate_league(3.6)
	# A new chapter: its number, big, with confetti.
	var lv := Progress.cascade_level
	var wait_more := 0.0
	if lv > 0 and lv % 10 == 0 and lv < levels.size() and not Progress.seen.has("chapter_%d" % (lv / 10)):
		wait_more = 2.6
		Progress.seen["chapter_%d" % (lv / 10)] = true
		_later(1.9, _seq, func():
			fx.banner("Chapter %s" % HomeView._roman(lv / 10 + 1), "Levels %d to %d" % [lv + 1, lv + 10], _home_banner_pos(), 2.2)
			fx.confetti(get_viewport_rect().size.x, 100)
			Audio.win())
	if _set_ceremony != "":
		_later(1.2 + wait_more, _seq, _open_set_ceremony)
	# Three stars on every level of a chapter: a bonus, once per chapter.
	var done := Progress.claim_perfect_chapters()
	for k in done.size():
		var ch: int = done[k]
		_later(0.8 + k * 2.2, _seq, func():
			fx.banner("Chapter %s perfect!" % HomeView._roman(ch + 1), "Every level 3 stars  ·  +%d coins" % Progress.CHAPTER_BONUS,
				_home_banner_pos(), 2.0)
			fx.confetti(get_viewport_rect().size.x, 90)
			Audio.jackpot()
			_fly_coins(Vector2(ox + W * 0.5, H * 0.4), Progress.CHAPTER_BONUS))

## Banners on the map sit high, clear of the level you're heading to.
func _home_banner_pos() -> Vector2:
	return Vector2(ox + W * 0.5, _home.map_top() + 150.0 if _home else H * 0.25)

## The album set was finished: a full-screen moment with a big gold ribbon.
func _open_set_ceremony() -> void:
	if _overlay != "title":
		return
	_overlay = "setdone"
	_overlay_age = 0.0
	Audio.jackpot()
	fx.confetti(get_viewport_rect().size.x, 140)
	_show_overlay_buttons()

func _close_set_ceremony() -> void:
	_set_ceremony = ""
	_overlay = "title"
	_overlay_age = 1.0
	Audio.panel_out()
	_show_overlay_buttons()

func _draw_set_ceremony(o: Node2D, pr: Rect2) -> void:
	var grow := Style.ease_back(clampf(_overlay_age / 0.6, 0.0, 1.0))
	var c := Vector2(pr.get_center().x, pr.position.y + 215.0)
	o.draw_set_transform(c, sin(_clock * 1.5) * 0.05, Vector2.ONE * (0.2 + 1.4 * grow))
	_draw_ribbon(o, Vector2.ZERO, 1.0)
	o.draw_set_transform(_o_base, 0.0, Vector2.ONE)
	Style.text(o, Style.serif(800, 72), _set_ceremony, Vector2(pr.get_center().x, pr.position.y + 395.0), 34, Style.INK)
	Style.coin(o, Vector2(pr.get_center().x - 50.0, pr.position.y + 447.0), 16.0)
	Style.text(o, Style.serif(800, 72), "+%d" % Progress.SET_REWARD, Vector2(pr.get_center().x + 20.0, pr.position.y + 445.0), 32, Style.INK)

## Achievements earned since last time: a stamp slams down with its coins.
func _check_stamps(delay: float) -> void:
	var earned := Progress.check_stamps()
	for k in earned.size():
		var e: Array = earned[k]
		# A small strip slides down from the top (never over a panel's heading),
		# then its coins fly to the counter.
		_later(delay + k * 2.4, _seq, func():
			var col: Color = [Color("c98b4f"), Color("9aa3ad"), Style.COIN][int(e[1])]
			var y := 150.0 + _top
			fx.toast(String(e[0]), int(e[2]), col, y)
			Audio.star(int(e[1]))
			_later(0.5, _seq, func(): _fly_coins(Vector2(ox + W * 0.5 + 120.0, y), int(e[2]))))

func _title_play() -> void:
	# The panel grows out of the Play button.
	_pre_origin = Vector2(ox + W * 0.5, _home.button_row_y() + 42.0) if _home else Vector2(-1, -1)
	open_prelevel(mini(Progress.cascade_level, levels.size() - 1))

# ---------------------------------------------------------------- pre-level

## Before a level: its number, your best stars, and the boosters you can
## switch on (owned ones show how many; others show their price and are
## bought on the spot). Then Play.
func open_prelevel(i: int) -> void:
	if _overlay not in ["title", ""]:
		return
	_pre_index = i
	_pre_sel = {}
	# The first few levels just start: boosters come in at level 6, with one
	# of each free so the player learns them by using them.
	if i < PRE_FROM:
		_pre_play()
		return
	if not Progress.seen.has("boosters"):
		Progress.seen["boosters"] = true
		for id in PRE_BOOSTERS:
			Progress.boosters[id] = Progress.booster_count(id) + 1
		Progress.save_game()
		_later(0.5, _seq, func():
			fx.popup("Free boosters!", _overlay_rect().position + Vector2(_overlay_rect().size.x * 0.5, -90.0), Style.ACCENT, 44,
				30.0, 1.6, "big")
			Audio.purchase())
	_overlay = "prelevel"
	_overlay_age = 0.0
	_pre_pop = {}
	_pre_goal = Goals.for_level(_dressed_level(i), i)
	Audio.panel_in()
	_show_overlay_buttons()

var _pre_origin := Vector2(-1, -1)  ## where the pre-level panel grows from (-1 = drops in)
var _pre_pop: Dictionary = {}     ## booster id -> 1..0: its tile squishing after a tap
var _pre_goal: Dictionary = {}    ## the level's bonus goal, shown on the panel

func _pre_tile(k: int) -> Rect2:
	var pr := _overlay_rect()
	var size := Vector2(136, 136)
	var gap := 20.0
	var x0 := pr.get_center().x - (3.0 * size.x + 2.0 * gap) * 0.5
	return Rect2(Vector2(x0 + k * (size.x + gap), pr.position.y + 216.0), size)

func _pre_pet_rect() -> Rect2:
	var pr := _overlay_rect()
	return Rect2(pr.position + Vector2(26, 34), Vector2(52, 52))

func _pre_click(p: Vector2) -> void:
	if Progress.active_pet() != "" and _pre_pet_rect().grow(8).has_point(p):
		_close_prelevel()
		open_pets()
		return
	for k in PRE_BOOSTERS.size():
		if _pre_tile(k).grow(6).has_point(p):
			var id: String = PRE_BOOSTERS[k]
			_pre_pop[id] = 1.0
			if _pre_sel.has(id):
				_pre_sel.erase(id)
				Audio.flip()
			elif Progress.booster_count(id) > 0:
				_pre_sel[id] = true
				Audio.star_pip(k * 2)
			elif Progress.buy_booster(id):
				_pre_sel[id] = true
				_coin_shown = Progress.coins
				Audio.purchase()
			else:
				_coin_warn = 1.0
				Audio.wrong()
			return

func _pre_play() -> void:
	_pre_origin = Vector2(-1, -1)
	var i := _pre_index
	var sel := _pre_sel.duplicate()
	for id in sel:
		Progress.use_booster(id)
	Playtest.log_line("Level %d" % (i + 1), "boosters: %s" % ", ".join(sel.keys()) if not sel.is_empty() else "no boosters")
	_turn(func():
		_overlay = ""
		_show_overlay_buttons()
		start_level(i)
		_apply_boosters(sel))

func _apply_boosters(sel: Dictionary) -> void:
	if sel.has("slot"):
		board.hold += 1
		_vis.hold += 1
		_slot_pulse.resize(board.hold + 1)
		_slot_pulse.fill(0.0)
	_xray = sel.has("xray")
	_lucky = sel.has("lucky")
	_update_peek_bands()
	_refresh_buttons()

func _close_prelevel() -> void:
	_pre_origin = Vector2(-1, -1)
	_overlay_draw.scale = Vector2.ONE
	_overlay_draw.position = Vector2.ZERO
	fx.fade_popups()
	_overlay = "title"
	_overlay_age = 1.0
	Audio.panel_out()
	_show_overlay_buttons()

func _draw_prelevel(o: Node2D, pr: Rect2) -> void:
	var i := _pre_index
	var best := Progress.cascade_stars(i)
	for k in 3:
		Style.fancy_star(o, Vector2(pr.get_center().x + (k - 1) * 46.0, pr.position.y + 136.0 - (8.0 if k == 1 else 0.0)), 18.0,
			1.0 if k < best else 0.0)
	# The pet coming along, in the corner (tap it to change pets).
	if Progress.active_pet() != "":
		Pets.draw(o, Progress.active_pet(), _pre_pet_rect())
	# One row of small tags: boss / hard, and the bonus goal.
	var tags: Array = []
	var win := float(levels[i].get("bot", {}).get("win", 1.0))
	if levels[i].get("boss", false):
		tags.append(["Boss  ·  ×2 coins", Style.COIN, Style.INK])
	elif win < 0.45:
		tags.append(["Super hard" if win < 0.33 else "Hard", Style.INK if win < 0.33 else Style.ACCENT, Style.COIN if win < 0.33 else Style.CARD])
	var ty := pr.position.y + 180.0
	var widths: Array = []
	var total := 0.0
	for t in tags:
		widths.append(Style.caps_width(t[0], 12, 0.14) + 22.0)
		total += widths[-1] + 12.0
	var goal_w := 0.0
	if not _pre_goal.is_empty():
		goal_w = (44.0 + Style.caps_width({"first": "First", "last": "Last", "chain": "Chain"}.get(String(_pre_goal.kind), ""), 11, 0.2) + 16.0) * 1.1
		total += goal_w + 12.0
	var x := pr.get_center().x - (total - 12.0) * 0.5
	for n2 in tags.size():
		var tr := Rect2(Vector2(x, ty - 13.0), Vector2(widths[n2], 26))
		o.draw_rect(Rect2(tr.position + Vector2(3, 3), tr.size), Style.INK)
		o.draw_rect(tr, tags[n2][1])
		o.draw_rect(tr, Style.INK, false, 2.0)
		Style.caps(o, tags[n2][0], tr.get_center(), 12, tags[n2][2], 0.14)
		x += widths[n2] + 12.0
	if goal_w > 0.0:
		_goal_chip(o, _pre_goal, "open", _o_base + Vector2(x + goal_w * 0.5, ty), 1.1, _o_base)
	for k in PRE_BOOSTERS.size():
		var id: String = PRE_BOOSTERS[k]
		var r := _pre_tile(k)
		var on := _pre_sel.has(id)
		if on:
			r.position.y -= 8.0
		# A tap squishes the tile, then it springs back.
		var pop := float(_pre_pop.get(id, 0.0))
		if pop > 0.0:
			_pre_pop[id] = maxf(pop - get_process_delta_time() * 3.0, 0.0)
			var sq := 1.0 + 0.12 * sin((1.0 - pop) * PI * 2.5) * pop
			r = Rect2(r.get_center() - r.size * 0.5 * Vector2(sq, 2.0 - sq), r.size * Vector2(sq, 2.0 - sq))
		Style.printed(o, r, Style.COIN if on else Style.CARD, 5.0 + (3.0 if on else 0.0), 2, 3)
		o.draw_set_transform(_o_base + r.get_center() + Vector2(0, -12), 0.0, Vector2(1.3, 1.3))
		Style.booster_icon(o, id, Vector2.ZERO, Style.INK)
		o.draw_set_transform(_o_base, 0.0, Vector2.ONE)
		var n := Progress.booster_count(id)
		if on:
			var c := r.position + Vector2(r.size.x - 6.0, 6.0)
			var tk := 1.0 + 0.6 * pop
			o.draw_set_transform(_o_base + c, 0.0, Vector2(tk, tk))
			c = Vector2.ZERO
			o.draw_circle(c + Vector2(2, 2), 15.0, Style.INK)
			o.draw_circle(c, 15.0, Style.CARD)
			o.draw_arc(c, 15.0, 0, TAU, 24, Style.INK, 2.0, true)
			o.draw_polyline(PackedVector2Array([c + Vector2(-7, 0), c + Vector2(-2, 5), c + Vector2(7, -5)]), Style.INK, 3.0, true)
			o.draw_set_transform(_o_base, 0.0, Vector2.ONE)
		elif n > 0:
			var c := r.position + Vector2(r.size.x - 6.0, 6.0)
			o.draw_circle(c + Vector2(2, 2), 15.0, Style.INK)
			o.draw_circle(c, 15.0, Style.ACCENT)
			o.draw_arc(c, 15.0, 0, TAU, 24, Style.INK, 2.0, true)
			Style.text(o, Style.sans(800), str(n), c + Vector2(0, -1), 15, Style.CARD)
		var label: String = ShopPanel.NAMES[id]
		Style.caps(o, label, Vector2(r.get_center().x, r.end.y - 20.0), 12, Style.INK, 0.1)
		if n == 0 and not on:
			Style.price(o, Vector2(r.get_center().x, r.end.y + 24.0), int(Progress.BOOSTERS[id].price), 20)

# ---------------------------------------------------------------- speed test

## Test builds only (Settings > Speed test): plays the busiest level by
## itself at real speed, then scrolls the map, timing every frame. Shows the
## result and writes it to user://speed_test.txt, so it can be run on an
## older phone to see if the game stays smooth.
var _speed: Dictionary = {}      ## {frames: [ms...], draws: max draw calls} while running
var _speed_result: Dictionary = {}

func run_speed_test() -> void:
	_overlay = ""
	_show_overlay_buttons()
	# A test run mustn't touch real progress: save now, play with saving off,
	# then load the real progress back at the end.
	var saved_save := Progress.save_enabled
	Progress.save_game()
	Progress.save_enabled = false
	for info in INTROS.values():
		Progress.seen[info[0]] = true
	Progress.seen["rare"] = true
	Engine.time_scale = 1.0
	start_level(levels.size() - 1)
	_speed = {"frames": [], "draws": 0}
	var idx := level_index
	for p in level.solution:
		while is_busy() and _overlay == "":
			await get_tree().process_frame
		if level_index != idx or _overlay != "":
			break
		tap_pile(int(p))
	var waited := 0.0
	while _overlay != "win" and waited < 8.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await get_tree().create_timer(2.0).timeout
	_go_home()
	for i in 150:
		_home.scroll = clampf(_home.scroll + 14.0 * (1.0 if i < 75 else -1.0), 0.0, _home._max_scroll())
		await get_tree().process_frame
	var frames: Array = _speed.frames
	_speed = {}
	Progress.save_enabled = saved_save
	if saved_save:
		Progress.load_game()
	_coin_shown = Progress.coins
	frames.sort()
	var n := maxi(frames.size(), 1)
	var avg: float = frames.reduce(func(a, b): return a + b, 0.0) / n
	var slow: float = frames[-1] if not frames.is_empty() else 0.0
	var low1: float = frames[mini(int(n * 0.99), n - 1)] if not frames.is_empty() else 0.0
	_speed_result = {"fps": 1000.0 / maxf(avg, 0.01), "low": 1000.0 / maxf(low1, 0.01), "slow": slow, "frames": n,
		"device": OS.get_model_name()}
	var text := "Speed test on %s: %d fps average, 1%% low %d fps, slowest frame %d ms, %d frames" % [_speed_result.device,
		roundi(_speed_result.fps), roundi(_speed_result.low), roundi(slow), n]
	var f := FileAccess.open("user://speed_test.txt", FileAccess.WRITE)
	if f:
		f.store_line(text)
		f.close()
	Playtest.log_line("--", text)
	print(text)
	_overlay = "speed"
	_overlay_age = 0.0
	Audio.panel_in()
	_show_overlay_buttons()

func _speed_verdict() -> Array:
	var low: float = _speed_result.get("low", 0.0)
	if low >= 50.0:
		return ["Smooth", Style.group_color(2)]
	if low >= 30.0:
		return ["OK", Style.COIN]
	return ["Slow", Style.ACCENT]

## Test builds: puts the whole playtest log on the clipboard, so a tester can
## paste it into a message (no add-on needed).
func _copy_playtest_log() -> void:
	var path: String = Playtest.PATH
	var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "(no log yet)"
	DisplayServer.clipboard_set(text)
	fx.popup("Log copied", Vector2(ox + W * 0.5, _overlay_rect().end.y + 30.0), Style.ACCENT, 26, 20.0, 1.4, "plain")
	Audio.star(1)

func _draw_speed(o: Node2D, pr: Rect2) -> void:
	var v := _speed_verdict()
	var c := pr.get_center().x
	Style.text(o, Style.serif(800, 144), String(v[0]), Vector2(c, pr.position.y + 150.0), 56, v[1])
	var rows := [["Average", "%d fps" % roundi(_speed_result.fps)], ["1% low", "%d fps" % roundi(_speed_result.low)],
		["Slowest frame", "%d ms" % roundi(_speed_result.slow)]]
	for i in rows.size():
		var y := pr.position.y + 220.0 + i * 44.0
		Style.caps(o, rows[i][0], Vector2(c - 90.0, y), 12, Color(Style.INK, 0.6), 0.16)
		Style.text(o, Style.serif(700, 72), rows[i][1], Vector2(c + 100.0, y), 26, Style.INK)
	Style.caps(o, String(_speed_result.device), Vector2(c, pr.position.y + 360.0), 10, Color(Style.INK, 0.45), 0.14)

# ---------------------------------------------------------------- coin shop

func open_shop() -> void:
	if _overlay != "title":
		return
	if _shop == null:
		_shop = ShopPanel.new()
		_overlay_layer.add_child(_shop)
		_shop.closed.connect(_close_shop)
		_shop.bought.connect(func(amount: int, at: Vector2):
			fx.popup("-" + Style.commas(amount), Vector2(_shop._counter_pos().x - 56.0, _shop._counter_pos().y), Style.ACCENT, 24, 26.0, 1.0, "plain")
			_coin_shown = Progress.coins)
	_shop.reset()
	fx.fade_popups()
	_overlay = "shop"
	_overlay_age = 0.0
	Audio.panel_in()
	_show_overlay_buttons()

func _close_shop() -> void:
	_overlay = "title"
	_overlay_age = 1.0
	_show_overlay_buttons()

## Page turn: a sheet of paper sweeps across, the change happens while it
## covers the screen, and it sweeps off the other side.
var _turn_layer: CanvasLayer
## Panels leaving: -1 when no panel is closing, else 0..1 through its exit.
var _exit_t := -1.0
var _o_base := Vector2.ZERO      ## the panel's current offset (drop-in, exit, page slide)
var _page_slide := 0.0           ## album / How to play: -1..1, the page sliding in from a side

## Close a panel the nice way: it slides down and fades (~0.2 s), then `f`
## runs (the plain close, which tests call directly). Buttons and taps
## outside the panel come through here.
func _leave(f: Callable) -> void:
	if _exit_t >= 0.0 or _overlay in ["", "title"]:
		return
	_exit_t = 0.0
	Audio.panel_out()
	for b in _overlay_buttons:
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.set_meta("y0", b.position.y)
	var tw := create_tween()
	tw.tween_property(self, "_exit_t", 1.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		_exit_t = -1.0
		_overlay_draw.modulate.a = 1.0
		f.call())

## Tap outside a panel: which close it runs ("" = tapping outside does nothing).
func _outside_close() -> Callable:
	match _overlay:
		"streak":
			return _close_streak
		"pets":
			return _close_pets
		"prelevel":
			return _close_prelevel
		"settings":
			return close_overlay
		"album":
			return _close_album
		"rules":
			return _close_rules
		"events":
			return _close_events
		"share":
			return _close_share
	return Callable()

## Album and How to play: the new page slides in from the side it came from.
func _slide_page(dir: int) -> void:
	_page_slide = float(dir)
	create_tween().tween_property(self, "_page_slide", 0.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

var _turn_node: Node2D
var _turn_t := -1.0

func _turn(f: Callable) -> void:
	if _turn_t >= 0.0:
		return
	if _turn_layer == null:
		_turn_layer = CanvasLayer.new()
		_turn_layer.layer = 5
		add_child(_turn_layer)
		_turn_node = Node2D.new()
		_turn_node.draw.connect(_draw_turn)
		_turn_layer.add_child(_turn_node)
	_turn_t = 0.0
	Audio.page_turn()
	var tw := create_tween()
	tw.tween_method(func(v: float):
		_turn_t = v
		_turn_node.queue_redraw(), 0.0, 0.5, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(f)
	tw.tween_method(func(v: float):
		_turn_t = v
		_turn_node.queue_redraw(), 0.5, 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_turn_t = -1.0
		_turn_node.queue_redraw())

func _draw_turn() -> void:
	if _turn_t < 0.0:
		return
	var size := get_viewport_rect().size
	# Leading edge sweeps right to left across the screen and beyond.
	var lead := size.x * (1.0 - _turn_t * 2.0)
	var left := lead
	var right := size.x + (lead if _turn_t > 0.5 else 0.0)
	if _turn_t > 0.5:
		left = 0.0
		right = size.x * (2.0 - _turn_t * 2.0)
	var r := Rect2(Vector2(left, 0), Vector2(maxf(right - left, 0.0), size.y))
	_turn_node.draw_rect(r, Style.PAPER)
	var edge_x := r.position.x if _turn_t <= 0.5 else r.end.x
	var sh := -14.0 if _turn_t <= 0.5 else 14.0
	_turn_node.draw_rect(Rect2(Vector2(edge_x + minf(sh, 0.0), 0), Vector2(absf(sh), size.y)), Color(Style.INK, 0.18))
	_turn_node.draw_line(Vector2(edge_x, 0), Vector2(edge_x, size.y), Style.INK, 3.0)

## Into the daily puzzle: the calendar bubble grows into a big desk-calendar
## page (today's date, the weekday, and how hard today is as 7 pips), the
## puzzle is dealt behind it, and the page tears off and falls away.
var _cal_layer: CanvasLayer
var _cal_node: Node2D
var _cal_t := -1.0               ## seconds into the calendar moment (-1 = not showing)
var _cal_from := Vector2.ZERO    ## where the bubble was
var _cal_ripped := false
const CAL_GROW := 0.38
const CAL_HOLD := 0.75           ## the page is read here; the tear starts
const CAL_FALL := 0.7

func _open_daily() -> void:
	if _cal_t >= 0.0 or _turn_t >= 0.0:
		return
	if _cal_layer == null:
		_cal_layer = CanvasLayer.new()
		_cal_layer.layer = 5
		add_child(_cal_layer)
		_cal_node = Node2D.new()
		_cal_node.draw.connect(_draw_calendar)
		_cal_layer.add_child(_cal_node)
	_cal_from = Vector2(ox + 68.0, (_home.map_top() if _home else 92.0) + 86.0 + 142.0)
	_cal_t = 0.0
	_cal_ripped = false
	Audio.page_turn()

func _cal_step(delta: float) -> void:
	if _cal_t < 0.0:
		return
	var before := _cal_t
	_cal_t += delta / maxf(Engine.time_scale, 0.001)
	if before < CAL_GROW and _cal_t >= CAL_GROW:
		# Fully covered: the puzzle is dealt behind the page.
		_overlay = ""
		_show_overlay_buttons()
		start_daily()
	if before < CAL_HOLD and _cal_t >= CAL_HOLD:
		_cal_ripped = true
		Audio.gift_cut()
		_haptic(30)
	if _cal_t >= CAL_HOLD + CAL_FALL:
		_cal_t = -1.0
	_cal_node.queue_redraw()

## 1 = easy Monday ... 7 = hard Sunday.
static func weekday_pips(date_key: String) -> int:
	var d := Time.get_datetime_dict_from_datetime_string(date_key + "T12:00:00", true)
	var wd := int(d.get("weekday", 1))
	return 7 if wd == 0 else wd

const WEEKDAYS := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

func _draw_calendar() -> void:
	if _cal_t < 0.0:
		return
	var o := _cal_node
	var size := get_viewport_rect().size
	var full := Rect2(Vector2(ox + 24.0, 70.0 + _top), Vector2(W - 48.0, size.y - 140.0 - _top - _bottom))
	var grow := clampf(_cal_t / CAL_GROW, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - grow, 3.0)
	# The page scales up out of the bubble.
	var small := Rect2(_cal_from - Vector2(34, 32), Vector2(68, 64))
	var r := Rect2(small.position.lerp(full.position, e), small.size.lerp(full.size, e))
	if grow < 1.0:
		o.draw_rect(Rect2(Vector2.ZERO, size), Color(Style.PAPER, e))
	else:
		o.draw_rect(Rect2(Vector2.ZERO, size), Color(Style.PAPER, 1.0 - clampf((_cal_t - CAL_HOLD) / 0.25, 0.0, 1.0)))
	var key := Progress.local_date()
	var d := Time.get_datetime_dict_from_datetime_string(key + "T12:00:00", true)
	var k := r.size.x / full.size.x
	var bind_h := 120.0 * k
	var fall := clampf((_cal_t - CAL_HOLD) / CAL_FALL, 0.0, 1.0)
	# The sheet: after the tear it swings from its top-right corner and drops.
	var sheet := Rect2(r.position + Vector2(0, bind_h), r.size - Vector2(0, bind_h))
	var pivot := Vector2(sheet.end.x, sheet.position.y)
	var drop := Vector2(-40.0 * fall, size.y * 1.1 * fall * fall)
	o.draw_set_transform(pivot + drop, 0.35 * fall * fall + sin(fall * 9.0) * 0.03 * fall, Vector2.ONE)
	var local := Rect2(sheet.position - pivot, sheet.size)
	o.draw_rect(Rect2(local.position + Vector2(8, 8) * k, local.size), Style.INK)
	var edge := PackedVector2Array()
	# A torn top edge once it's ripped; a perforated one before.
	var n := 28
	for i in n + 1:
		var x := local.position.x + local.size.x * i / n
		edge.append(Vector2(x, local.position.y + ((5.0 * k if i % 2 == 0 else -4.0 * k) if _cal_ripped else 0.0)))
	var poly := edge.duplicate()
	poly.append(local.end)
	poly.append(Vector2(local.position.x, local.end.y))
	o.draw_colored_polygon(poly, Style.CARD)
	o.draw_polyline(poly + PackedVector2Array([poly[0]]), Style.INK, 2.5, true)
	if not _cal_ripped:
		o.draw_dashed_line(Vector2(local.position.x + 10.0, local.position.y + 8.0 * k), Vector2(local.end.x - 10.0, local.position.y + 8.0 * k),
			Color(Style.INK, 0.35), 2.0, 8.0 * k, true)
	var cx := local.get_center().x
	# The date block (about 620 tall at full size), centred on the sheet.
	var top_y := local.position.y + maxf(0.0, (local.size.y - 620.0 * k) * 0.42)
	Style.caps(o, MONTHS[clampi(int(d.get("month", 1)) - 1, 0, 11)], Vector2(cx, top_y + 70.0 * k), maxi(int(26 * k), 6), Style.ACCENT, 0.3)
	Style.text(o, Style.num(800), str(int(d.get("day", 1))), Vector2(cx, top_y + 250.0 * k), maxi(int(260 * k), 6), Style.INK, 0, Style.INK, false, 0.0, true)
	Style.text(o, Style.serif(700, 72), WEEKDAYS[int(d.get("weekday", 0))], Vector2(cx, top_y + 440.0 * k), maxi(int(48 * k), 6), Style.INK, 0, Style.INK, false, 0.0, true)
	# How hard today is: 7 pips, easy Monday to hard Sunday.
	var pips := weekday_pips(key)
	for i in 7:
		var pc := Vector2(cx + (i - 3) * 40.0 * k, top_y + 530.0 * k)
		var pts := PackedVector2Array([pc + Vector2(0, -12) * k, pc + Vector2(12, 0) * k, pc + Vector2(0, 12) * k, pc + Vector2(-12, 0) * k])
		o.draw_colored_polygon(pts, Style.ACCENT if i < pips else Color(Style.INK, 0.12))
		o.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(Style.INK, 0.6 if i < pips else 0.25), 1.5, true)
	Style.caps(o, "Daily puzzle", Vector2(cx, top_y + 590.0 * k), maxi(int(15 * k), 6), Color(Style.INK, 0.55), 0.25)
	o.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The binding stays for a moment after the tear, then lifts away.
	var lift := clampf((_cal_t - CAL_HOLD - 0.15) / 0.35, 0.0, 1.0)
	var br := Rect2(r.position - Vector2(0, (bind_h + 200.0) * lift * lift), Vector2(r.size.x, bind_h))
	o.draw_rect(Rect2(br.position + Vector2(8, 8) * k, br.size), Style.INK)
	o.draw_rect(br, Style.ACCENT)
	o.draw_rect(br, Style.INK, false, 2.5)
	for sd in [-1.0, 1.0]:
		var ring := Vector2(br.get_center().x + sd * br.size.x * 0.28, br.position.y + 6.0 * k)
		o.draw_rect(Rect2(ring - Vector2(9, 24) * k, Vector2(18, 48) * k), Style.INK)
		o.draw_rect(Rect2(ring - Vector2(5, 20) * k, Vector2(10, 40) * k), Style.PAPER_DEEP)
	Style.text(o, Style.serif(800, 144), str(int(d.get("year", 2026))), br.get_center() + Vector2(0, 10.0 * k), maxi(int(44 * k), 6), Style.CARD, 0, Style.INK, false, 0.0, true)

## Page arrows on the level map, drawn beside the page title.
func _page_arrow_rect(dir: int) -> Rect2:
	var pr := _overlay_rect()
	var y := pr.position.y + 128.0
	return Rect2(Vector2(pr.get_center().x + dir * 250.0 - 22.0, y - 22.0), Vector2(44, 44))

func close_overlay() -> void:
	_fresh_unlock = -1
	_overlay = "title" if _overlay == "settings" and _settings_from == "title" else ""
	_settings_from = ""
	Audio.panel_out()
	_show_overlay_buttons()

## Settings: five toggles as printed tiles (gold = on, struck through = off).
const SETTINGS := ["sound", "music", "haptics", "large", "calm"]
const SETTING_NAMES := {"sound": "Sound", "music": "Music", "haptics": "Vibrate", "large": "Big text", "calm": "Calm"}

func _setting_on(id: String) -> bool:
	match id:
		"sound":
			return Progress.sound
		"music":
			return Progress.music
		"haptics":
			return Progress.haptics
		"large":
			return Progress.large_text
	return Progress.calm

func _setting_tile(k: int) -> Rect2:
	var pr := _overlay_rect()
	var size := Vector2(140, 126)
	var gap := 20.0
	var row := k / 3
	var in_row := 3 if row == 0 else SETTINGS.size() - 3
	var x0 := pr.get_center().x - (in_row * size.x + (in_row - 1) * gap) * 0.5
	return Rect2(Vector2(x0 + (k % 3) * (size.x + gap), pr.position.y + 130.0 + row * (size.y + gap)), size)

var _toggle_flip: Dictionary = {}  ## setting id -> 0..1 its tile turning over

func _settings_click(p: Vector2) -> void:
	for k in SETTINGS.size():
		if _setting_tile(k).grow(4).has_point(p):
			_toggle_flip[SETTINGS[k]] = 0.0
			match SETTINGS[k]:
				"sound":
					_toggle_sound()
				"music":
					_toggle_music()
				"haptics":
					_toggle_haptics()
				"large":
					_toggle_large()
				"calm":
					_toggle_calm()
			return

func _draw_settings(o: Node2D) -> void:
	for k in SETTINGS.size():
		var id: String = SETTINGS[k]
		var r := _setting_tile(k)
		var on := _setting_on(id)
		# Switching turns the tile over like a card: the old side shows until
		# it's edge-on, then the new side.
		var ft := float(_toggle_flip.get(id, 1.0))
		if ft < 1.0:
			ft = minf(ft + get_process_delta_time() * 3.5, 1.0)
			_toggle_flip[id] = ft
			if ft < 0.5:
				on = not on
			var sx := maxf(absf(cos(ft * PI)), 0.06)
			o.draw_set_transform(_o_base + Vector2(r.get_center().x * (1.0 - sx), 0), 0.0, Vector2(sx, 1.0))
		Style.printed(o, r, Style.COIN if on else Style.PAPER_DEEP, 5.0, 2, 3)
		var c := r.get_center() + Vector2(0, -12)
		var ink := Color(Style.INK, 1.0 if on else 0.45)
		match id:
			"sound":
				o.draw_colored_polygon(PackedVector2Array([c + Vector2(-16, -7), c + Vector2(-7, -7), c + Vector2(4, -16),
					c + Vector2(4, 16), c + Vector2(-7, 7), c + Vector2(-16, 7)]), ink)
				for w in [9.0, 16.0]:
					o.draw_arc(c + Vector2(6, 0), w, -0.8, 0.8, 10, ink, 3.0, true)
			"music":
				o.draw_line(c + Vector2(-6, 10), c + Vector2(-6, -16), ink, 3.5)
				o.draw_line(c + Vector2(12, 6), c + Vector2(12, -20), ink, 3.5)
				o.draw_line(c + Vector2(-6, -16), c + Vector2(12, -20), ink, 5.0)
				o.draw_circle(c + Vector2(-11, 11), 6.0, ink)
				o.draw_circle(c + Vector2(7, 7), 6.0, ink)
			"haptics":
				o.draw_rect(Rect2(c + Vector2(-9, -16), Vector2(18, 32)), ink, false, 3.0)
				for sd in [-1.0, 1.0]:
					o.draw_polyline(PackedVector2Array([c + Vector2(sd * 15, -9), c + Vector2(sd * 19, -4), c + Vector2(sd * 15, 1),
						c + Vector2(sd * 19, 6), c + Vector2(sd * 15, 11)]), ink, 2.5, true)
			"large":
				Style.text(o, Style.serif(800, 72), "Aa", c, 38, ink)
			"calm":
				for w in 3:
					var pts := PackedVector2Array()
					for i in 13:
						pts.append(c + Vector2(-20 + i * 40.0 / 12.0, -10 + w * 10 + sin(i * 0.6) * 3.0))
					o.draw_polyline(pts, ink, 3.0, true)
		if not on:
			o.draw_line(r.position + Vector2(18, r.size.y - 36), r.position + Vector2(r.size.x - 18, 18), Color(Style.ACCENT, 0.8), 3.0)
		Style.caps(o, SETTING_NAMES[id], Vector2(r.get_center().x, r.end.y - 20.0), 12, ink, 0.14)
		o.draw_set_transform(_o_base, 0.0, Vector2.ONE)

func _toggle_sound() -> void:
	Progress.sound = not Progress.sound
	Audio.enabled = Progress.sound
	if Progress.sound:
		Audio.music_start()
	Progress.save_game()
	Audio.button()
	_show_overlay_buttons()

func _toggle_music() -> void:
	Progress.music = not Progress.music
	Audio.music_enabled = Progress.music
	if Progress.music:
		Audio.music_start()
	else:
		Audio.music_stop()
	Progress.save_game()
	Audio.button()
	_show_overlay_buttons()

func _ask_reset() -> void:
	_overlay = "reset"
	_overlay_age = 0.3
	_show_overlay_buttons()

func open_settings_from_reset() -> void:
	_overlay = "settings"
	_overlay_age = 0.3
	_show_overlay_buttons()

## For playtests: a new tester starts from the very first level.
## Settings (sound, text size...) are kept.
func _do_reset() -> void:
	Progress.reset()
	Progress.coins = 0
	Progress.stars = {}
	Progress.save_game()
	Playtest.log_line("--", "---- progress reset (new tester) ----")
	_turn(func():
		_overlay = ""
		_show_overlay_buttons()
		start_level(0))

func _toggle_large() -> void:
	Progress.large_text = not Progress.large_text
	Style.big = Progress.large_text
	for v in views:
		v.queue_redraw()
	Progress.save_game()
	Audio.button()
	_show_overlay_buttons()

func _toggle_calm() -> void:
	Progress.calm = not Progress.calm
	Progress.save_game()
	Audio.button()
	_show_overlay_buttons()

func _toggle_haptics() -> void:
	Progress.haptics = not Progress.haptics
	Progress.save_game()
	_haptic(30)
	_show_overlay_buttons()

func _restart_from_settings() -> void:
	_turn(func():
		_overlay = ""
		_show_overlay_buttons()
		retry())

## After a win: back to the map (the next card turns over), then the
## pre-level panel for the next level.
func next_level() -> void:
	if _daily:
		_go_home()
		return
	var nxt := (level_index + 1) % levels.size()
	_go_home()
	_later(1.3 if _home and _home._flip_t < 1.0 else 0.3, _seq, open_prelevel.bind(nxt))

func retry() -> void:
	if _daily:
		start_daily()
	else:
		start_level(level_index)

## The result as a few lines of text and coloured squares (one per group in
## the order they burst), ready to paste into a message. No spoilers.
func share_text() -> String:
	var squares := {0: "🟥", 1: "🟦", 2: "🟩", 3: "🟨", 4: "🟪", 5: "🟪", 6: "🟦", 7: "🟫", 8: "🟩", 9: "🟧", 10: "⬛", 11: "🟦"}
	var row := ""
	for g in _lit:
		row += squares.get(posmod(g, 12), "⬜")
	var stars := "★".repeat(_win_stars) + "☆".repeat(3 - _win_stars)
	return "Cascade · %s\n%s  %d taps · best chain ×%d\n%s" % [_share_badge(), stars, board.taps, maxi(_best_chain, 1), row]

func _share_badge() -> String:
	if not _daily:
		return "Level %d" % (level_index + 1)
	var d := Time.get_datetime_dict_from_datetime_string(_daily_key, false)
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "Daily · %s %d" % [months[clampi(int(d.get("month", 1)) - 1, 0, 11)], int(d.get("day", 1))]

## Folding the win card away to look at the finished board.
var _win_fold := false
var _fold_t := 0.0               ## 0 = card up, 1 = folded into the tab

func _set_win_fold(on: bool) -> void:
	_win_fold = on
	Audio.panel_out() if on else Audio.panel_in()
	for b in _overlay_buttons:
		b.visible = not on

func _win_tab_rect() -> Rect2:
	return Rect2(Vector2(ox + W * 0.5 - 130.0, H - 96.0 - _bottom), Vector2(260, 72))

func _draw_win_tab(o: Node2D) -> void:
	var r := _win_tab_rect()
	r.position.y += 120.0 * (1.0 - _fold_t)
	Style.printed(o, r, Style.CARD, 5.0, 2, 3)
	o.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 8)), Style.group_color(_lit[-1] if not _lit.is_empty() else 2))
	var c := r.get_center() + Vector2(0, 4)
	for k in 3:
		Style.fancy_star(o, c + Vector2(-70.0 + k * 34.0, 0), 13.0, 1.0 if k < _win_stars else 0.0)
	var ch := c + Vector2(80, 2)
	o.draw_polyline(PackedVector2Array([ch + Vector2(-10, 5), ch + Vector2(0, -5), ch + Vector2(10, 5)]), Style.INK, 3.5, true)

## Share: draws the result card as a picture and shows it on a panel.
var _share_img: Image
var _share_tex: ImageTexture
var _share_note := 0.0           ## > 0 while "Saved" shows under the card

func open_share() -> void:
	if _overlay != "win":
		return
	var info := {"badge": _share_badge(), "stars": _win_stars, "taps": board.taps, "order": _lit.duplicate()}
	_share_img = await ShareCard.render(self, info)
	_share_tex = ImageTexture.create_from_image(_share_img)
	_overlay = "share"
	_overlay_age = 0.0
	_share_note = 0.0
	Audio.panel_in()
	_show_overlay_buttons()

## Saves the picture and copies the text version. On a computer the picture
## opens so you can drag it anywhere; the phone's share menu needs an add-on
## (see new-game-plan/06-ideas-and-problems.md).
func _do_share() -> void:
	var path := "user://cascade_result.png"
	_share_img.save_png(path)
	DisplayServer.clipboard_set(share_text())
	if not OS.has_feature("mobile"):
		OS.shell_open(ProjectSettings.globalize_path(path))
	_share_note = 2.0
	Audio.star(2)
	Playtest.log_line(_level_name(), "shared the result")

func _close_share() -> void:
	_overlay = "win"
	_overlay_age = 1.0
	Audio.panel_out()
	_show_overlay_buttons()

## Kept for older callers: the daily's Share button now opens the card.
func copy_share() -> void:
	open_share()

# ---------------------------------------------------------------- UI

func _build_background() -> void:
	var bg := CanvasLayer.new()
	bg.layer = -1
	add_child(bg)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/background.gdshader")
	rect.material = mat
	_bg_mat = mat
	bg.add_child(rect)

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 1
	add_child(_ui)
	_undo_btn = _button("Undo", undo, false)
	_peek_btn = _button("Peek", peek, false)
	_hint_btn = _button("Hint", hint, true)
	_ui.add_child(_undo_btn)
	_ui.add_child(_peek_btn)
	_ui.add_child(_hint_btn)
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 2
	add_child(_overlay_layer)
	_overlay_draw = Node2D.new()
	_overlay_draw.draw.connect(_draw_overlay)
	_overlay_layer.add_child(_overlay_draw)

func _button(text: String, action: Callable, primary: bool, size := 16) -> PillButton:
	var b := PillButton.new()
	b.text = text
	b.primary = primary
	b.font_size = size
	b.pressed.connect(action)
	return b

func _place_buttons() -> void:
	if _undo_btn == null:
		return
	var y := H - 136.0 - _bottom
	var bw := 168.0
	var shown: Array = [_undo_btn, _hint_btn]
	if _peek_btn.visible:
		shown = [_undo_btn, _peek_btn, _hint_btn]
	for i in shown.size():
		var b: PillButton = shown[i]
		b.position = Vector2(ox + W * 0.5 + (i - (shown.size() - 1) * 0.5) * (bw + 18.0) - bw * 0.5, y)
		b.size = Vector2(bw, 72)
	if not _overlay_buttons.is_empty():
		_show_overlay_buttons()

func _refresh_buttons() -> void:
	_undo_btn.badge = undos_left if undos_left > 0 else -1
	_hint_btn.badge = hints_left if hints_left > 0 else -1
	_undo_btn.icon = "undo"
	_hint_btn.icon = "hint"
	_peek_btn.icon = "peek"
	_undo_btn.price = -1 if undos_left > 0 else Economy.UNDO_COST
	_hint_btn.price = -1 if hints_left > 0 else Economy.HINT_COST
	_peek_btn.price = Economy.PEEK_COST
	_undo_btn.disabled = _undo.is_empty()
	_hint_btn.disabled = false
	_peek_btn.text = "Peek · %d" % Economy.PEEK_COST
	_peek_btn.disabled = _peeking > 0.0 or _xray
	# Boosters unlock gradually: Peek arrives at level 5.
	var want := _daily or level_index >= PEEK_FROM_LEVEL
	if _peek_btn.visible != want:
		_peek_btn.visible = want
		_place_buttons()

func _show_overlay_buttons() -> void:
	if _home:
		_home.visible = _overlay in ["title", "prelevel", "shop", "setdone", "streak", "pets"]
	if _shop:
		_shop.visible = _overlay == "shop"
		if _shop.visible:
			_shop.W = W
			_shop.H = H
			_shop.ox = ox
			_shop.top = _top
			_overlay_layer.move_child(_shop, -1)
	if _intro_card and _overlay != "intro":
		_intro_card.queue_free()
		_intro_card = null
	if _teaser_card and _overlay != "win":
		_teaser_card.queue_free()
		_teaser_card = null
	for b in _overlay_buttons:
		b.queue_free()
	_overlay_buttons.clear()
	_overlay_draw.queue_redraw()
	if _overlay == "":
		return
	if _overlay == "win" and _daily:
		var b := _button("Share result", open_share, true, 18)
		b.bob_enabled = true
		_overlay_buttons.append(b)
		_overlay_buttons.append(_button("Map", _turn.bind(_go_home), false, 16))
	elif _overlay == "prelevel":
		var b := _button("Play", _pre_play, true, 20)
		b.bob_enabled = true
		_overlay_buttons.append(b)
		_overlay_buttons.append(_button("Back", _leave.bind(_close_prelevel), false, 16))
	elif _overlay == "shop":
		pass
	elif _overlay == "setdone":
		var b := _button("Lovely", _leave.bind(_close_set_ceremony), true, 18)
		b.bob_enabled = true
		_overlay_buttons.append(b)
	elif _overlay == "speed":
		_overlay_buttons.append(_button("Back", _go_home, true, 16))
	elif _overlay == "share":
		var b := _button("Save picture" if not OS.has_feature("mobile") else "Share", _do_share, true, 18)
		b.bob_enabled = true
		_overlay_buttons.append(b)
		_overlay_buttons.append(_button("Back", _leave.bind(_close_share), false, 16))
	elif _overlay == "win":
		var gift_ready := not Progress.gift_boxes_ready().is_empty()
		var first_win := level_index == 0 and Progress.cascade_level == 1
		var after := _go_home if gift_ready or first_win else next_level
		var label := "Open your gift" if gift_ready else ("Continue" if first_win else "Next level")
		var b := _button(label, _turn.bind(after), true, 18)
		b.bob_enabled = true
		_overlay_buttons.append(b)
		var m := _button("", _turn.bind(_go_home), false, 16)
		m.icon = "map"
		m.set_meta("half", true)
		_overlay_buttons.append(m)
		var sh := _button("", open_share, false, 16)
		sh.icon = "share"
		sh.set_meta("half", true)
		_overlay_buttons.append(sh)
	elif _overlay == "settings":
		_overlay_buttons.append(_button("How to play", open_rules, false, 16))
		if _settings_from != "title":
			_overlay_buttons.append(_button("Restart level", _restart_from_settings, false, 16))
		_overlay_buttons.append(_button("Reset all progress", _ask_reset, false, 16))
		if OS.is_debug_build():
			# Tester tools share one row.
			var st := _button("Speed test", run_speed_test, false, 13)
			st.set_meta("half", true)
			_overlay_buttons.append(st)
			var cl := _button("Copy log", _copy_playtest_log, false, 13)
			cl.set_meta("half", true)
			_overlay_buttons.append(cl)
		_overlay_buttons.append(_button("Back" if _settings_from == "title" else "Back to game", _leave.bind(close_overlay), false, 16))
	elif _overlay == "reset":
		_overlay_buttons.append(_button("Yes, start fresh", _do_reset, true, 16))
		_overlay_buttons.append(_button("Cancel", open_settings_from_reset, false, 16))
	elif _overlay == "title":
		var nxt := mini(Progress.cascade_level, levels.size() - 1)
		var b := _button("Play  %d" % (nxt + 1), _title_play, true, 20)
		b.bob_enabled = true
		# Boss and hard levels say so on the button too.
		if levels[nxt].get("boss", false):
			b.corner_tag = "Boss"
		else:
			var win := float(levels[nxt].get("bot", {}).get("win", 1.0))
			b.corner_tag = "Super hard" if win < 0.33 else ("Hard" if win < 0.45 else "")
		_overlay_buttons.append(b)
	elif _overlay == "gift":
		if _gift_open >= 1.0 and Ads.available() and not _gift_doubled:
			var gb := _button("", _watch_gift_double, false, 18)
			gb.icon = "double"
			gb.ad = true
			gb.bob_enabled = true
			_overlay_buttons.append(gb)
			_overlay_buttons.append(_button("Collect", _close_gift, false, 16))
	elif _overlay == "intro":
		var b := _button("Got it", _leave.bind(_close_intro), true, 18)
		b.bob_enabled = true
		_overlay_buttons.append(b)
	elif _overlay == "pets":
		_overlay_buttons.append(_button("Back", _leave.bind(_close_pets), false, 16))
	elif _overlay == "streak":
		if Progress.can_repair():
			var rb := _button("", _streak_buy.bind("repair"), true, 16)
			rb.icon = "flame"
			rb.price = Progress.repair_cost()
			if Ads.available() and Progress.streak_lost <= Economy.AD_REPAIR_MAX:
				rb.set_meta("half", true)
				var ar := _button("", _watch_repair, true, 16)
				ar.icon = "flame"
				ar.ad = true
				ar.set_meta("half", true)
				_overlay_buttons.append(ar)
			_overlay_buttons.append(rb)
		var fb := _button("", _streak_buy.bind("freeze"), false, 16)
		fb.icon = "freeze"
		fb.price = Economy.FREEZE_COST
		fb.disabled = Progress.freezes >= Economy.FREEZE_MAX
		fb.set_meta("half", true)
		_overlay_buttons.append(fb)
		var vb := _button("", _streak_buy.bind("vacation"), false, 16)
		vb.icon = "vacation"
		vb.price = Economy.VACATION_COST
		vb.disabled = Progress.on_vacation()
		vb.set_meta("half", true)
		_overlay_buttons.append(vb)
		_overlay_buttons.append(_button("Back", _leave.bind(_close_streak), false, 16))
	elif _overlay == "events":
		if Progress.week_ready() > 0 and _events_tab == "event":
			_overlay_buttons.append(_button("Collect  +%d" % Progress.week_ready(), _claim_week, true, 16))
		_overlay_buttons.append(_button("Back", _leave.bind(_close_events), false, 16))
	elif _overlay == "album":
		_overlay_buttons.append(_button("Back", _leave.bind(_close_album), false, 16))
	elif _overlay == "rules":
		_overlay_buttons.append(_button("Got it", _leave.bind(_close_rules), true, 16))
	else:
		if not _undo.is_empty() and (undos_left > 0 or Progress.coins >= Economy.UNDO_COST):
			var ub := _button("", undo, true, 17)
			ub.icon = "undo"
			ub.price = -1 if undos_left > 0 else Economy.UNDO_COST
			_overlay_buttons.append(ub)
		if Progress.coins >= _continue_cost() and not board.stuck:
			var sb := _button("", continue_with_slot, true, 17)
			sb.icon = "slot"
			sb.price = _continue_cost()
			_overlay_buttons.push_front(sb)
		if Ads.available() and not _ad_slot_used and not board.stuck and (_daily or level_index >= Economy.AD_FROM_LEVEL):
			var ab := _button("", _watch_slot, false, 17)
			ab.icon = "slot"
			ab.ad = true
			_overlay_buttons.push_front(ab)
		_overlay_buttons.append(_button("Try again", func(): _turn(retry), false, 17))
	if _overlay == "title":
		_place_title_buttons()
		return
	var pr := _overlay_rect()
	var rows := _button_rows()
	# Half-width buttons (e.g. Map + Share) pair up on one row.
	var row := 0
	var col := 0
	for i in _overlay_buttons.size():
		var b := _overlay_buttons[i]
		var y := pr.end.y - 36.0 - (rows - row) * 96.0 + 12.0
		if b.has_meta("half"):
			b.size = Vector2(182, 76)
			b.position = Vector2(pr.get_center().x - 190.0 + col * 198.0, y)
			col += 1
			if col == 2 or i + 1 >= _overlay_buttons.size() or not _overlay_buttons[i + 1].has_meta("half"):
				col = 0
				row += 1
		else:
			b.size = Vector2(380, 76)
			b.position = Vector2(pr.get_center().x - 190.0, y)
			row += 1
		b.set_meta("p0", b.position)
		b.set_meta("bob", b.bob_enabled)
		_overlay_layer.add_child(b)

## Home: the map fills the screen; one big Play button under the collection
## shelf (daily gift, daily puzzle and events float at the sides).
func _place_title_buttons() -> void:
	_sync_home()
	var y := _home.button_row_y()
	for b in _overlay_buttons:
		b.size = Vector2(W - 64.0, 84)
		b.position = Vector2(ox + 32.0, y)
		_overlay_layer.add_child(b)

# ---------------------------------------------------------------- home map

var _home: HomeView

func _sync_home() -> void:
	if _home == null:
		_home = HomeView.new()
		_overlay_layer.add_child(_home)
		_home.play.connect(_home_play)
		_home.gift.connect(_open_box)
		_home.album.connect(open_album)
		# The gear turns on the map first, then Settings opens.
		_home.settings.connect(func(): _later(0.16, _seq, open_settings))
		_home.daily_gift.connect(_open_gift)
		_home.daily_puzzle.connect(_open_daily)
		_home.events.connect(open_events)
		_home.shop.connect(open_shop)
		_home.streak.connect(open_streak)
		_home.league.connect(open_league)
		_home.pets.connect(open_pets)
		_home.count = levels.size()
		for i in levels.size():
			if levels[i].get("boss", false):
				_home.bosses[i] = true
			# The toughest levels are marked, so losing one feels fair.
			var win := float(levels[i].get("bot", {}).get("win", 1.0))
			if win < 0.45:
				_home.hard[i] = 2 if win < 0.33 else 1
		_size_home()
		_home.focus(mini(Progress.cascade_level, levels.size() - 1))
	_overlay_layer.move_child(_home, 0)   # under the panels drawn over it (pre-level)
	_home.visible = _overlay in ["title", "prelevel", "shop", "setdone", "streak", "pets"]
	_size_home()
	_home.coins_shown = _coin_shown

func _size_home() -> void:
	_home.W = W
	_home.H = H
	_home.ox = ox
	_home.top = _top
	_home.bottom = _bottom

func _home_play(i: int) -> void:
	_pre_origin = _home.path_pos(i)
	open_prelevel(i)

## A gift box on the map: the lid pops, coins fly up to the counter.
func _open_box(k: int) -> void:
	var coins := Progress.open_gift_box(k)
	if coins <= 0:
		return
	_home.open_box(k)
	Audio.jackpot()
	_haptic(40)
	var at := _home._gift_pos(k)
	fx.burst(at, 40, 520.0, [Style.COIN, Style.ACCENT, Style.CARD], 200.0)
	_later(0.35, _seq, func(): _fly_coins(at, coins))

## Rows of panel buttons: half-width buttons pair up.
func _button_rows() -> int:
	var rows := 0
	var halves := 0
	for b in _overlay_buttons:
		if b.has_meta("half"):
			halves += 1
		else:
			rows += (halves + 1) / 2
			halves = 0
			rows += 1
	return rows + (halves + 1) / 2

func _overlay_rect() -> Rect2:
	var header: float = {"win": 440.0, "rules": 700.0, "album": 780.0, "gift": 600.0, "reset": 200.0, "intro": 560.0, "events": (450.0 if _events_tab == "event" else 800.0), "pets": 800.0, "streak": 510.0, "settings": 446.0, "lose": 290.0, "share": 700.0, "prelevel": 420.0, "speed": 400.0, "setdone": 500.0}.get(_overlay, 200.0)
	var count := maxi(_button_rows(), 1)
	var ph := header + count * 96.0 + 30.0
	return Rect2(Vector2(ox + 70.0, H * 0.5 - ph * 0.5), Vector2(W - 140.0, ph))

# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	_clock += delta
	_cal_step(delta)
	_surprise_process(delta)
	_pet_process(delta)
	for i in _slot_pulse.size():
		_slot_pulse[i] = maxf(_slot_pulse[i] - delta * 3.0, 0.0)
	for i in _seg_pop.size():
		_seg_pop[i] = maxf(_seg_pop[i] - delta * 2.5, 0.0)
	_coin_pop = maxf(_coin_pop - delta * 4.0, 0.0)
	# The counter rolls to its number rather than jumping (fast for big gaps).
	var gap := float(_coin_shown) - _coin_roll
	if absf(gap) < 0.5 or absf(gap) > 5000.0:
		_coin_roll = float(_coin_shown)
	else:
		_coin_roll += gap * (1.0 - exp(-10.0 * delta)) + signf(gap) * minf(absf(gap), 20.0 * delta)
	_chain_pop = maxf(_chain_pop - delta * 4.0, 0.0)
	_cap_age += delta
	_cap_old_age += delta
	_level_t += delta
	_star_drop = maxf(_star_drop - delta * 1.6, 0.0)
	_coin_warn = maxf(_coin_warn - delta * 1.5, 0.0)
	_streak_pop = maxf(_streak_pop - delta * 3.0, 0.0)
	_goal_pop = maxf(_goal_pop - delta * 3.0, 0.0)
	_share_note = maxf(_share_note - delta, 0.0)
	if not _speed.is_empty():
		_speed.frames.append(delta * 1000.0 / maxf(Engine.time_scale, 0.001))
	if _fx_layer:
		_fx_layer.transform = transform
	if _overlay != "win":
		_win_fold = false
	_fold_t = move_toward(_fold_t, 1.0 if _win_fold else 0.0, delta * 4.0)
	if _ui:
		if _overlay == "win":
			_ui.offset = Vector2(0, 260.0 * _fold_t)
		else:
			_ui.offset = Vector2(0, 220.0 * (1.0 - _hud_in())) if board and _overlay == "" else Vector2.ZERO
	if board and board.in_danger() and not is_busy() and _overlay == "":
		_heartbeat -= delta
		if _heartbeat <= 0.0:
			_heartbeat = 0.85
			Audio.heartbeat()
			_slot_pulse[board.hold] = 1.0
			_haptic(15)
	else:
		_heartbeat = 0.0
	_frame = maxf(_frame - delta * (0.6 if is_busy() else 2.0), 0.0)
	_update_idle(delta)
	if _home and _overlay in ["title", "prelevel", "shop", "setdone", "streak", "pets"]:
		_home.coins_shown = roundi(_coin_roll)
	if _shop and _overlay == "shop":
		_shop.coins_shown = roundi(_coin_roll)
	if _queued_pile != -1 and not is_busy():
		var q := _queued_pile
		_queued_pile = -1
		if q < board.piles.size() and not board.piles[q].is_empty() and board.lock[board.piles[q][-1]] == 0:
			tap_pile(q)
	if _peeking > 0.0:
		_peeking -= delta
		if _peeking <= 0.0:
			_end_peek()
	_tint = maxf(_tint - delta * 0.12, 0.0)
	if _bg_mat:
		_bg_mat.set_shader_parameter("tint_amount", _tint)
	for c in _flying:
		if randf() < 0.7:
			fx.trail(views[c].position, _flying[c])
	# In danger with hints left: the hint button breathes, as a nudge.
	if _hint_btn:
		_hint_btn.bob_enabled = board != null and board.in_danger() and not is_busy() and _overlay == ""
		if not _hint_btn.bob_enabled:
			_hint_btn.scale = Vector2.ONE
	_punch = maxf(_punch - delta * 5.0, 0.0)
	_shake = maxf(_shake - delta * 2.8, 0.0)
	var calm := 0.0 if Progress.calm else 1.0
	var zoom := 1.0 + 0.03 * _punch * _punch * calm
	var c := Vector2(ox + W * 0.5, H * 0.45)
	var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 14.0 * _shake * _shake * calm
	scale = Vector2(zoom, zoom)
	position = c - c * zoom + jitter
	if _vis and _vis.tray.size() > board.hold:
		_danger_t += delta
	else:
		_danger_t = 0.0
	queue_redraw()
	if _overlay != "":
		_overlay_age += delta
		for i in 3:
			_star_slam[i] = maxf(_star_slam[i] - delta * 3.5, 0.0)
		_overlay_draw.queue_redraw()

# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if board == null:
		return
	_draw_weather()
	_draw_hud()
	_caption_layer.queue_redraw()
	_draw_piles()
	_draw_tray()
	_draw_pet()
	_draw_frame()
	if _hint_pile != -1 and not is_busy():
		_draw_demo(_hint_pile)
	if _showme_card != -1 and not is_busy() and _overlay == "":
		var r := _card_rect(views[_showme_card].position).grow(10.0 + 4.0 * sin(_clock * 5.0))
		draw_rect(r, Color(Style.ACCENT, 0.6 + 0.4 * sin(_clock * 5.0)), false, 5.0)
		if _showme_pile != -1:
			_draw_demo(_showme_pile)

## The top bar and the booster buttons slide in once the level banner has
## gone (the banner gets the screen to itself first).
func _hud_in() -> float:
	return Style.ease_back(clampf((_level_t - BANNER_TIME + 0.05) / 0.35, 0.0, 1.0))

func _draw_hud() -> void:
	var saved_top := _top
	_top -= 180.0 * (1.0 - _hud_in())
	_draw_hud_inner()
	_top = saved_top

func _draw_hud_inner() -> void:
	# A printed button with a folded-map icon: back to the level map.
	var lr := _level_label_rect()
	Style.printed(self, lr, Style.CARD, 4.0, 2, 3)
	var mc := Vector2(lr.position.x + 30.0, lr.get_center().y)
	var fold := PackedVector2Array([mc + Vector2(-13, -9), mc + Vector2(-4, -12), mc + Vector2(4, -9), mc + Vector2(13, -12),
		mc + Vector2(13, 9), mc + Vector2(4, 12), mc + Vector2(-4, 9), mc + Vector2(-13, 12)])
	draw_colored_polygon(fold, Style.PAPER_DEEP)
	draw_polyline(fold + PackedVector2Array([fold[0]]), Style.INK, 2.0, true)
	draw_line(mc + Vector2(-4, -12), mc + Vector2(-4, 9), Style.INK, 1.5)
	draw_line(mc + Vector2(4, -9), mc + Vector2(4, 12), Style.INK, 1.5)
	draw_circle(mc + Vector2(8, -2), 2.5, Style.ACCENT)
	Style.caps(self, _hud_label(), Vector2(lr.position.x + 98.0, lr.get_center().y), 14, Style.INK, 0.16)
	# Coins.
	var cp := _coin_hud_pos()
	var cs := 1.0 + 0.3 * _coin_pop
	draw_set_transform(cp + Vector2(20, 0), 0.0, Vector2(cs, cs))
	Style.coin(self, Vector2.ZERO, 15.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var size := int(30 * (1.0 + 0.15 * _coin_pop))
	var wob := Vector2(sin(_coin_warn * 40.0) * 8.0 * _coin_warn, 0)
	draw_string(Style.num(700), cp + wob + Vector2(44, size * 0.34), Style.commas(roundi(_coin_roll)), HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Style.INK.lerp(Style.ACCENT, _coin_warn))
	_draw_gear(_gear_rect().get_center())
	# Progress bar.
	for i in board.group_count():
		var r := _seg_rect(i)
		var pop := _seg_pop[i] if i < _seg_pop.size() else 0.0
		r = r.grow_individual(0, 6.0 * pop, 0, 6.0 * pop)
		var appear := clampf((_level_t - BANNER_TIME - 0.1 - i * 0.05) / 0.2, 0.0, 1.0)
		r.size.x *= appear
		if appear <= 0.0:
			continue
		if i < _lit.size():
			var col := Style.group_color(_lit[i])
			draw_rect(Rect2(r.position + Vector2(2, 2), r.size), Style.INK)
			draw_rect(r, col)
			draw_rect(r, Style.INK, false, 1.5)
		elif i == _lit.size() and board.group_count() - _lit.size() == 1 and not board.is_won():
			# One group left: its segment glows, so the finish feels close.
			var gl := 0.5 + 0.5 * sin(_clock * 6.0)
			draw_rect(r.grow(2.0 * gl), Color(Style.COIN, 0.35 + 0.4 * gl))
			draw_rect(r, Color(Style.INK, 0.5), false, 1.5)
		else:
			draw_rect(r, Color(Style.INK, 0.1))
	# Live star meter: which stars you're still on track for.
	var right := ox + W - 30.0

	for k in 3:
		var sp := Vector2(right - 60.0 + k * 24.0, 127.0 + _top)
		var lit := k < _stars_now
		var dropping := k == _stars_now and _star_drop > 0.0
		if dropping:
			var t := 1.0 - _star_drop
			Style.fancy_star(self, sp + Vector2(0, 40.0 * t * t), 10.0 * (1.0 + 0.4 * _star_drop), 1.0 - t, t * 3.0)
			Style.fancy_star(self, sp, 10.0, 0.0)
		else:
			Style.fancy_star(self, sp, 10.0, 1.0 if lit else 0.0)

## Tapping the gear: it presses in and turns an eighth of a turn with a
## springy settle, while Settings opens.
var _gear_t := 1.0

func _spin_gear() -> void:
	_gear_t = 0.0
	create_tween().tween_property(self, "_gear_t", 1.0, 0.45)

static func gear_turn(t: float) -> float:
	return PI / 4.0 * Style.ease_back(clampf(t / 0.8, 0.0, 1.0))

static func gear_press(t: float) -> float:
	return 1.0 - 0.18 * sin(clampf(t / 0.35, 0.0, 1.0) * PI)

func _draw_gear(c: Vector2) -> void:
	var teeth := 8
	var pts := PackedVector2Array()
	var turn := gear_turn(_gear_t)
	var k := gear_press(_gear_t)
	for i in teeth * 2:
		var a := i * PI / teeth + turn
		var r := (15.0 if i % 2 == 0 else 11.5) * k
		pts.append(c + Vector2.from_angle(a - PI / teeth * 0.5) * r)
		pts.append(c + Vector2.from_angle(a + PI / teeth * 0.5) * r)
	draw_colored_polygon(pts, Style.INK)
	draw_circle(c, 5.5 * k, Style.PAPER)

## A thin frame in the chain's colour hugs the screen during big chains.
func _draw_frame() -> void:
	if _frame <= 0.0:
		return
	var sz := get_viewport_rect().size
	var w := 10.0 * _frame
	var col := Color(_frame_color, _frame)
	var r := Rect2(Vector2(-position.x, -position.y) / scale, sz / scale)
	draw_rect(Rect2(r.position, Vector2(r.size.x, w)), col)
	draw_rect(Rect2(Vector2(r.position.x, r.end.y - w), Vector2(r.size.x, w)), col)
	draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)
	draw_rect(Rect2(Vector2(r.end.x - w, r.position.y), Vector2(w, r.size.y)), col)

## Peek / X-ray: a tag under each pile names the card underneath. Drawn on
## the caption layer, so the second row of cards can't cover the first row's.
func _draw_peek_tags(ci: CanvasItem) -> void:
	if board == null or _overlay != "":
		return
	for p in board.piles.size():
		var hidden: int = _vis.piles[p].size() - 1
		if (_peeking > 0.0 or _xray) and hidden > 0:
			var under: int = _vis.piles[p][-2]
			var a := 1.0 if _xray else clampf(minf((PEEK_SECONDS - _peeking) / 0.2, _peeking / 0.3), 0.0, 1.0)
			var at := _pile_pos(p) + Vector2(0, CARD.y * 0.5 + 22.0)
			var hidden_colour := board.wrapped[under] == 1
			var label: String = "?" if hidden_colour else board.card_label[under]
			var col := Style.group_color(board.card_group[under]) if board.card_kind[under] == Cascade.Kind.CARD and not hidden_colour \
				else Style.INK
			ci.draw_set_transform(at, 0.0, Vector2.ONE * (0.8 + 0.2 * a))
			var w := minf(Style.caps_width(label, 12, 0.1) + 16.0, 140.0)
			ci.draw_rect(Rect2(Vector2(-w * 0.5 + 2, -9), Vector2(w, 22)), Color(Style.INK, a))
			ci.draw_rect(Rect2(Vector2(-w * 0.5, -11), Vector2(w, 22)), Color(col, a))
			Style.caps(ci, label, Vector2(0, 0), 12, Color(Style.on_color(col), a), 0.1)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The combo chip: bursting taps in a row. It grows and heats up from red to
## gold as the streak climbs, and shivers when it's hot. Drawn above the
## cards, a little lower than before so flying coins don't hide it.
func _draw_streak_chip(ci: CanvasItem) -> void:
	if board == null or _overlay != "":
		return
	if _streak >= 2:
		var heat := clampf((_streak - 2) / 4.0, 0.0, 1.0)
		var sc := (1.0 + 0.12 * minf(_streak - 2, 5)) * (1.0 + 0.4 * _streak_pop)
		var sp := Vector2(ox + W * 0.5, 146.0 + _top)
		var shiver := sin(_clock * 30.0) * 0.04 * heat
		ci.draw_set_transform(sp, shiver, Vector2(sc, sc))
		var label := "Streak ×%d" % _streak
		var w := Style.caps_width(label, 13, 0.2) + 24.0
		var fill := Style.ACCENT.lerp(Style.COIN, heat)
		ci.draw_rect(Rect2(Vector2(-w * 0.5 + 3, -10), Vector2(w, 24)), Style.INK)
		ci.draw_rect(Rect2(Vector2(-w * 0.5, -13), Vector2(w, 24)), fill)
		Style.caps(ci, label, Vector2(0, -1), 13, Style.on_color(fill), 0.2)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_piles() -> void:
	for p in board.piles.size():
		if _vis.piles[p].is_empty():
			var r := _card_rect(_pile_pos(p))
			_dashed(r, Color(Style.INK, 0.18))
		elif _clock < _safe_until and not board.would_crowd(p) and board.lock[board.piles[p][-1]] == 0:
			# The Fox's help: these taps won't overfill the tray.
			var fa := clampf((_safe_until - _clock) / 0.5, 0.0, 1.0)
			draw_rect(_card_rect(_pile_pos(p)).grow(12), Color(Style.group_color(2), 0.85 * fa), false, 5.0)
		elif _hint_pile == p:
			var a := 0.55 + 0.45 * sin(_clock * 8.0)
			draw_rect(_card_rect(_pile_pos(p)).grow(14), Color(Style.ACCENT, a), false, 4.0)

func _draw_tray() -> void:
	var n := board.hold + 1
	var left := maxf(_slot_pos(0).x - 78.0, ox + 12.0)
	var right := minf(_slot_pos(n - 1).x + 78.0, ox + W - 12.0)
	var top := _tray_y() - 290.0
	var panel := Rect2(Vector2(left, top), Vector2(right - left, 404.0))
	Style.printed(self, panel, Style.PAPER_DEEP, 5.0, 2, 3)
	var danger := _vis.tray.size() > board.hold
	var crowd := _pressed_pile != -1 and board.would_crowd(_pressed_pile)
	var full := _vis.tray.size() >= board.hold
	for j in n:
		var c := _slot_pos(j)
		var r := _card_rect(c, TRAY_SCALE).grow(3.0 + 6.0 * _slot_pulse[j])
		if j == n - 1:
			# The danger slot only shows up when it matters.
			var a := 0.12
			if danger:
				a = 0.75 + 0.25 * sin(_danger_t * 10.0)
			elif crowd:
				a = 0.55 + 0.3 * sin(_clock * 14.0)
			elif full:
				a = 0.4
			if j >= _vis.tray.size():
				Style.hatch(self, r.grow(-3), Color(Style.ACCENT, a * 0.6), 8.0, 2.0)
				draw_rect(r, Color(Style.ACCENT, a), false, 2.5)
				if a > 0.3:
					Style.text(self, Style.serif(800, 72), "!", c, 44, Color(Style.ACCENT, a))
			else:
				draw_rect(r.grow(6), Color(Style.ACCENT, a), false, 4.0)
		elif j >= _vis.tray.size():
			_dashed(r, Color(Style.INK, 0.3))
		if j < _vis.tray.size():
			var g: int = _vis.tray[j]
			var count: int = _vis.tray_cards[g].size()
			var need: int = _vis.need[g]
			var col := Style.group_color(g)
			var born: float = _tag_born.get(g, -10.0)
			var eager := count == need - 1
			_group_tag(board.group_names[g], col, c + Vector2(0, -CARD.y * TRAY_SCALE * 0.5 - TRAY_FAN * (count - 1) - 24.0),
				_clock - born, eager, g)
			for k in need:
				var sq := Rect2(c + Vector2((k - (need - 1) * 0.5) * 20.0 - 6.0, CARD.y * TRAY_SCALE * 0.5 + 16.0), Vector2(12, 12))
				if k < count:
					draw_rect(sq, col)
				draw_rect(sq, Style.INK, false, 1.5)
	if _chain_count >= 2 and is_busy():
		var s := 1.0 + 0.35 * _chain_pop
		draw_set_transform(Vector2(right - 150.0, top + 22.0), 0.0, Vector2(s, s))
		Style.text(self, Style.serif(800, 72), "×%d" % (_chain_count + 1), Vector2.ZERO, 30, Style.ACCENT)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## The tag drops in and types its name out; one card from done, it throbs.
func _group_tag(gname: String, col: Color, at: Vector2, age := 10.0, eager := false, g := -1) -> void:
	# Kept inside the tray panel (its shape disc hangs off the left end).
	var lim_l := maxf(_slot_pos(0).x - 78.0, ox + 12.0)
	var lim_r := minf(_slot_pos(board.hold).x + 78.0, ox + W - 12.0)
	var half := minf(Style.caps_width(gname, 12, 0.12) + 18.0, 150.0) * 0.5
	at.x = clampf(at.x, lim_l + half + 18.0, lim_r - half - 8.0)
	var t := clampf(age / 0.25, 0.0, 1.0)
	var sc := 0.6 + 0.4 * Style.ease_back(t)
	if eager:
		sc *= 1.0 + 0.07 * sin(_clock * 9.0)
	draw_set_transform(at, 0.0, Vector2(sc, sc))
	at = Vector2.ZERO
	var shown := gname.substr(0, int(clampf((age - 0.1) * 40.0, 0.0, gname.length())))
	var size := 12
	while size > 9 and Style.caps_width(gname, size, 0.12) > 136.0:
		size -= 1
	var w := minf(Style.caps_width(gname, size, 0.12) + 18.0, 150.0)
	var r := Rect2(at - Vector2(w * 0.5, 13), Vector2(w, 26))
	draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Style.INK)
	draw_rect(r, col)
	draw_rect(r, Style.INK, false, 2.0)
	# Typed left to right, so letters don't jitter as the name fills in.
	var full_w := Style.caps_width(gname, size, 0.12)
	var part_w := Style.caps_width(shown, size, 0.12) if shown != "" else 0.0
	if shown != "":
		Style.caps(self, shown, r.get_center() + Vector2((part_w - full_w) * 0.5, 0), size, Style.on_color(col), 0.12)
	if g >= 0:
		# The group's shape hangs off the tag's left end, in a little ink disc.
		var disc := r.position + Vector2(-4, r.size.y * 0.5)
		draw_circle(disc + Vector2(2, 2), 11.0, Style.INK)
		draw_circle(disc, 11.0, Style.CARD)
		draw_arc(disc, 11.0, 0, TAU, 20, Style.INK, 2.0, true)
		Style.group_symbol(self, g, disc, 5.0, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _dashed(r: Rect2, col: Color) -> void:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for i in 4:
		draw_dashed_line(pts[i], pts[i + 1], col, 2.0, 8.0, true)

## Level 1's first tap: the table dims except the card to tap, and a
## finger taps it. No words needed.
func _draw_spotlight(cl: Node2D) -> void:
	var p: int = level.solution[0]
	if board.piles[p].is_empty():
		return
	var t := clampf((_clock - _busy_until) / 0.4, 0.0, 1.0)
	# Everything that isn't part of this tap fades back; the cards it will
	# grab (all the same colour) glow together, so the rule is visible.
	var grab := board.grab_preview(p)
	for q in board.piles.size():
		var tc := board.top(q)
		if tc == -1:
			continue
		var v := views[tc]
		v.modulate = Color(1, 1, 1, 1.0 if grab.has(tc) else lerpf(1.0, 0.3, t))
		if grab.has(tc) and v.glow < 0.99:
			v.set_glow(1.0)
	var pulse := 0.5 + 0.5 * sin(_clock * 5.0)
	cl.draw_rect(_pile_rect(p).grow(6), Color(Style.COIN, (0.6 + 0.4 * pulse) * t), false, 4.0)
	var ft := fmod(_clock, 1.4)
	var fp := views[board.piles[p][-1]].position + Vector2(34, 46)
	var press := 1.0 if ft > 0.5 and ft < 0.8 else 0.0
	var a := clampf(minf(ft / 0.2, (1.4 - ft) / 0.3), 0.0, 1.0) * t
	cl.draw_circle(fp, 34.0 + 10.0 * press, Color(Style.INK, 0.12 * a))
	cl.draw_circle(fp + Vector2(3, 3), 18.0 - 4.0 * press, Color(Style.INK, a))
	cl.draw_circle(fp, 18.0 - 4.0 * press, Color(Style.CARD, a))
	cl.draw_arc(fp, 18.0 - 4.0 * press, 0, TAU, 32, Color(Style.INK, a), 2.5, true)

## A ghost finger taps the card to play: on the first tap of the game, and
## whenever a hint is shown.
func _draw_demo(best: int) -> void:
	if board.piles[best].is_empty():
		return
	var t := fmod(_clock, 1.4)
	var p := views[board.piles[best][-1]].position + Vector2(34, 46)
	var press := 1.0 if t > 0.5 and t < 0.8 else 0.0
	var alpha := clampf(minf(t / 0.2, (1.4 - t) / 0.3), 0.0, 1.0)
	draw_circle(p, 34.0 + 10.0 * press, Color(Style.INK, 0.12 * alpha))
	draw_circle(p + Vector2(3, 3), 18.0 - 4.0 * press, Color(Style.INK, alpha))
	draw_circle(p, 18.0 - 4.0 * press, Color(Style.CARD, alpha))
	draw_arc(p, 18.0 - 4.0 * press, 0, TAU, 32, Color(Style.INK, alpha), 2.5, true)

func _draw_overlay() -> void:
	if _overlay == "" or _overlay == "shop":
		return
	if _overlay == "title":
		_draw_title()
		return
	var o := _overlay_draw
	var size := get_viewport_rect().size
	var a := clampf(_overlay_age / 0.25, 0.0, 1.0)
	var fold := _fold_t if _overlay == "win" else 0.0
	# Leaving: the panel drops away solid (fading it would let its shadow
	# show through) while the dim lifts; only the very end fades.
	var ex := maxf(_exit_t, 0.0)
	var drop_out := H * 0.7 * ex * ex
	var tail := clampf((ex - 0.7) / 0.3, 0.0, 1.0)
	_overlay_draw.modulate.a = 1.0
	# A lighter dim than before, so the map or the table still shows behind.
	o.draw_rect(Rect2(-size, size * 3.0), Color(Style.PAPER, 0.62 * a * (1.0 - fold) * (1.0 - ex)))
	var pr := _overlay_rect()
	var drop := 1.0 - Style.ease_back(clampf(_overlay_age / 0.42, 0.0, 1.0))
	# The pre-level panel grows out of the card (or button) you tapped.
	var grow_k := 1.0
	var growing := _overlay == "prelevel" and _pre_origin.x >= 0.0 and _exit_t < 0.0
	if growing:
		drop = 0.0
		grow_k = lerpf(0.12, 1.0, Style.ease_back(clampf(_overlay_age / 0.36, 0.0, 1.0)))
	_overlay_draw.scale = Vector2(grow_k, grow_k)
	_overlay_draw.position = _pre_origin * (1.0 - grow_k) if growing else Vector2.ZERO
	var shift := Vector2(0, -H * 0.5 * drop + H * fold + drop_out)
	_o_base = shift
	o.draw_set_transform(shift, 0.0, Vector2.ONE)
	Style.printed(o, pr, Style.CARD, 9.0, 2, 3)
	var win := _overlay == "win"
	var band := Style.ACCENT
	if win:
		band = Style.group_color(_lit[-1] if not _lit.is_empty() else 2)
	elif _overlay == "settings":
		band = Style.INK
	o.draw_rect(Rect2(pr.position + Vector2(2, 2), Vector2(pr.size.x - 4, 14)), band)
	o.draw_line(Vector2(pr.position.x + 2, pr.position.y + 16), Vector2(pr.end.x - 2, pr.position.y + 16), Style.INK, 2.0)
	var head: String = {"win": ["Solved", "Nice!", "Brilliant!"][clampi(_win_stars - 1, 0, 2)], "lose": "So close", "settings": "Settings", "share": "Share",
		"prelevel": "Level %d" % (_pre_index + 1), "shop": "", "speed": "Speed test", "setdone": "Set complete!",
		"rules": "How to play", "album": "Album", "gift": "Daily gift", "reset": "Start fresh?",
		"intro": ("New: " + _intro[1]) if not _intro.is_empty() else "", "events": "Events", "streak": "Streak", "pets": "Pets"}[_overlay]
	Style.text(o, Style.serif(800, 144), head, Vector2(pr.get_center().x, pr.position.y + 82.0), 58, Style.INK)
	match _overlay:
		"win":
			_draw_win_body(o, pr, shift)
		"lose":
			# The level's groups as segments, the burst ones lit.
			var n := board.group_count()
			var bw := minf(44.0, (pr.size.x - 120.0) / n - 6.0)
			var x0 := pr.get_center().x - (n * (bw + 6.0) - 6.0) * 0.5
			for g in n:
				var sr := Rect2(Vector2(x0 + g * (bw + 6.0), pr.position.y + 124.0), Vector2(bw, 14.0))
				if g < board.done.size():
					o.draw_rect(Rect2(sr.position + Vector2(2, 2), sr.size), Style.INK)
					o.draw_rect(sr, Style.group_color(board.done[g]))
					o.draw_rect(sr, Style.INK, false, 1.5)
				else:
					o.draw_rect(sr, Color(Style.INK, 0.12))
			# How close it was: the group nearest to bursting, and its missing cards.
			var best_g := -1
			var best_left := 99
			for g in board.tray:
				var left: int = board.need[g] - board.tray_cards[g].size()
				if left < best_left:
					best_left = left
					best_g = g
			if best_g != -1:
				var col := Style.group_color(best_g)
				var cy := pr.position.y + 186.0
				var total_w := 60.0 + best_left * 36.0
				var gx := pr.get_center().x - total_w * 0.5
				o.draw_rect(Rect2(Vector2(gx + 3, cy - 19), Vector2(40, 40)), Style.INK)
				o.draw_rect(Rect2(Vector2(gx, cy - 22), Vector2(40, 40)), col)
				o.draw_rect(Rect2(Vector2(gx, cy - 22), Vector2(40, 40)), Style.INK, false, 2.0)
				Style.group_symbol(o, best_g, Vector2(gx + 20, cy - 2), 10.0, Style.on_color(col))
				for k in best_left:
					var r := Rect2(Vector2(gx + 56.0 + k * 36.0, cy - 22), Vector2(28, 40))
					var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
					for e in 4:
						o.draw_dashed_line(pts[e], pts[e + 1], col, 2.0, 5.0, true)
			if _lost_streak >= STREAK_PEEK and not _daily:
				# The streak pips, cracked.
				for k in 3:
					var p := Vector2(pr.get_center().x + (k - 1) * 22.0, pr.position.y + 234.0)
					o.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -8), p + Vector2(6, 0), p + Vector2(0, 8), p + Vector2(-6, 0)]),
						Color(Style.ACCENT, 0.35))
					o.draw_line(p + Vector2(-4, -5), p + Vector2(4, 5), Style.INK, 1.5)
		"settings":
			_draw_settings(o)
		"rules":
			_draw_rules(o, pr)
		"album":
			_draw_album(o, pr)
		"gift":
			_draw_gift(o, pr)
		"events":
			_draw_events_tabs(o)
			_o_base += Vector2(_page_slide * pr.size.x * 0.6, 0)
			o.draw_set_transform(_o_base, 0.0, Vector2.ONE)
			if _events_tab == "league":
				_draw_league(o, pr)
			else:
				_draw_events(o, pr)
		"streak":
			_draw_streak(o, pr)
		"pets":
			_draw_pets(o, pr)
		"prelevel":
			_draw_prelevel(o, pr)
		"speed":
			_draw_speed(o, pr)
		"setdone":
			_draw_set_ceremony(o, pr)
		"share":
			if _share_tex:
				var w := pr.size.x - 140.0
				var h := w * ShareCard.SIZE.y / ShareCard.SIZE.x
				var tr := Rect2(Vector2(pr.get_center().x - w * 0.5, pr.position.y + 118.0), Vector2(w, h))
				o.draw_rect(Rect2(tr.position + Vector2(6, 6), tr.size), Style.INK)
				o.draw_texture_rect(_share_tex, tr, false)
				o.draw_rect(tr, Style.INK, false, 2.0)
				if _share_note > 0.0:
					var msg := "Saved and copied" if not OS.has_feature("mobile") else "Copied. Paste it anywhere"
					Style.caps(o, msg, Vector2(pr.get_center().x, tr.end.y + 26.0), 12, Color(Style.ACCENT, minf(_share_note, 1.0)), 0.2)
		"intro":
			if _intro_card:
				var drop2 := 1.0 - Style.ease_back(clampf(_overlay_age / 0.42, 0.0, 1.0))
				_intro_card.position = pr.position + Vector2(pr.size.x * 0.5, 300.0 - H * 0.5 * drop2) + Vector2(0, H * 0.7 * maxf(_exit_t, 0.0) ** 2)
				_intro_card.rotation = sin(_overlay_age * 2.0) * 0.04
				_intro_card.z_index = 5
			if not _intro.is_empty():
				Style.text(o, Style.serif(600, 72), _intro[2], Vector2(pr.get_center().x, pr.position.y + 505.0), 30, Style.INK)
		"reset":
			Style.caps(o, "Levels, stars, coins and album go back to zero", Vector2(pr.get_center().x, pr.position.y + 126.0),
				12, Color(Style.INK, 0.6), 0.18)
	o.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _overlay == "win" and _fold_t > 0.0:
		_draw_win_tab(o)
	for b in _overlay_buttons:
		b.modulate.a = clampf((_overlay_age - 0.2) / 0.2, 0.0, 1.0) * (1.0 - tail)
		b.visible = not _win_fold
		if _exit_t >= 0.0 and b.has_meta("y0"):
			b.position.y = float(b.get_meta("y0")) + drop_out
		elif growing and b.has_meta("p0"):
			var p0: Vector2 = b.get_meta("p0")
			var c0 := p0 + b.size * 0.5
			b.bob_enabled = grow_k >= 1.0 and bool(b.get_meta("bob"))
			b.scale = Vector2(grow_k, grow_k)
			b.position = _pre_origin + (c0 - _pre_origin) * grow_k - b.size * 0.5
	_overlay_draw.modulate.a = 1.0 - tail

## Home: HomeView draws everything; the Play button pops in on its cue.
func _draw_title() -> void:
	var a := _home.appear("play") if _home else 1.0
	for b in _overlay_buttons:
		b.modulate.a = clampf(a * 3.0, 0.0, 1.0)
		b.bob_enabled = a >= 1.0
		if a < 1.0:
			b.scale = Vector2.ONE * Style.ease_back(a)

const TEASERS := {
	2: "Magnet cards", 3: "Bomb cards", 4: "the Peek booster", 12: "Locked cards", 20: "Wild cards",
	30: "Frozen cards", 45: "Chained cards", 60: "Wrapped cards", 40: "Colour bombs", 55: "Row cards",
	70: "Shuffle cards",
}

func _draw_win_body(o: Node2D, pr: Rect2, shift: Vector2) -> void:
	var nxt := level_index + 1
	if not _daily and INTROS.has(nxt) and _overlay_age > 2.2 and not _win_fold:
		# Coming up next level: the new card itself, peeking out below.
		var ta := clampf((_overlay_age - 2.2) / 0.3, 0.0, 1.0)
		if _teaser_card == null:
			_teaser_card = CardView.new()
			_dress_showcase(_teaser_card, INTROS[nxt][0])
			_teaser_card.face_up = true
			_teaser_card.base_scale = 0.7
			_teaser_card.scale = Vector2.ONE * 0.7
			_teaser_card.rotation = 0.12
			_overlay_layer.add_child(_teaser_card)
		var tc := Vector2(pr.end.x - 40.0, pr.end.y - 10.0)
		_teaser_card.position = tc + Vector2(0, 30.0 * (1.0 - ta))
		_teaser_card.modulate.a = ta
		_teaser_card.z_index = 6
		var tag := Rect2(tc + Vector2(-44, -76), Vector2(60, 20))
		o.draw_rect(Rect2(tag.position + Vector2(2, 2), tag.size), Color(Style.INK, ta))
		o.draw_rect(tag, Color(Style.ACCENT, ta))
		Style.caps(o, "Next", tag.get_center(), 12, Color(Style.CARD, ta), 0.16)
	if _daily and _overlay_age > 1.4:
		_draw_daily_streak(o, pr, shift)
	_draw_double_chip(o)
	for i in 3:
		var s := 1.0 + 1.1 * _star_slam[i] * _star_slam[i]
		o.draw_set_transform(shift + _star_pos(i), 0.0, Vector2(s, s))
		Style.fancy_star(o, Vector2.ZERO, 44.0, 1.0 if i < _stars_shown else 0.0)
	o.draw_set_transform(shift, 0.0, Vector2.ONE)
	if _win_coins_shown > 0:
		var cy := pr.position.y + 300.0
		Style.coin(o, Vector2(pr.get_center().x - 60.0, cy), 18.0)
		o.draw_string(Style.num(700), Vector2(pr.get_center().x - 32.0, cy + 15.0), "+" + Style.commas(_win_coins_shown),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Style.INK)
		# Taps and best chain, as icons and numbers.
		var y := pr.position.y + 374.0
		o.draw_line(Vector2(pr.position.x + 50, y - 36), Vector2(pr.end.x - 50, y - 36), Color(Style.INK, 0.15), 1.0)
		var tx := pr.get_center().x - 90.0
		_icon_tap(o, Vector2(tx - 34.0, y))
		Style.text(o, Style.num(700), "%d" % board.taps, Vector2(tx + 12.0, y), 32, Style.INK)
		var cx := pr.get_center().x + 90.0
		_icon_chain(o, Vector2(cx - 36.0, y))
		Style.text(o, Style.num(700), "×%d" % maxi(_best_chain, 1), Vector2(cx + 14.0, y), 32, Style.INK)
		if _perfect and _overlay_age > 1.9:
			var t2 := clampf((_overlay_age - 1.9) / 0.25, 0.0, 1.0)
			var sc2 := 1.8 - 0.8 * Style.ease_back(t2)
			var c2 := Vector2(pr.position.x + 92.0, pr.position.y + 150.0)
			o.draw_set_transform(shift + c2, 0.2, Vector2(sc2, sc2))
			var r2 := Rect2(Vector2(-62, -22), Vector2(124, 44))
			o.draw_rect(r2, Color(Style.group_color(2), t2), false, 3.0)
			o.draw_rect(r2.grow(-5), Color(Style.group_color(2), t2), false, 1.0)
			Style.caps(o, "Perfect", Vector2.ZERO, 14, Color(Style.group_color(2), t2), 0.2)
			o.draw_set_transform(shift, 0.0, Vector2.ONE)
		if _new_best and _overlay_age > 1.6:
			# A slightly rotated stamp.
			var t := clampf((_overlay_age - 1.6) / 0.25, 0.0, 1.0)
			var sc := 1.8 - 0.8 * Style.ease_back(t)
			var c := Vector2(pr.end.x - 86.0, pr.position.y + 150.0)
			o.draw_set_transform(shift + c, -0.22, Vector2(sc, sc))
			var r := Rect2(Vector2(-66, -22), Vector2(132, 44))
			o.draw_rect(r, Color(Style.ACCENT, t), false, 3.0)
			o.draw_rect(r.grow(-5), Color(Style.ACCENT, t), false, 1.0)
			Style.caps(o, "New best", Vector2.ZERO, 14, Color(Style.ACCENT, t), 0.2)
			o.draw_set_transform(shift, 0.0, Vector2.ONE)

## Daily win: your streak of days, with a flame, popping in as it counts up.
func _draw_daily_streak(o: Node2D, pr: Rect2, shift: Vector2) -> void:
	var n := Progress.daily_streak()
	var t := clampf((_overlay_age - 1.4) / 0.35, 0.0, 1.0)
	var shown := mini(n, maxi(1, roundi(n * clampf((_overlay_age - 1.4) / 0.6, 0.0, 1.0))))
	var c := Vector2(pr.end.x - 64.0, pr.position.y + 58.0)
	o.draw_set_transform(shift + c, -0.08, Vector2.ONE * (1.8 - 0.8 * Style.ease_back(t)))
	var flame := PackedVector2Array()
	for i in 17:
		var a := PI * 0.5 + (i - 8) * PI / 8.0
		flame.append(Vector2(-26, 6) + Vector2(cos(a) * 12.0, sin(a) * 10.0))
	flame.append(Vector2(-26, -24 + sin(_clock * 12.0) * 2.0))
	o.draw_colored_polygon(flame, Color(Style.ACCENT, t))
	o.draw_polyline(flame + PackedVector2Array([flame[0]]), Color(Style.INK, t), 2.0, true)
	o.draw_circle(Vector2(-26, 8), 5.0, Color(Style.COIN, t))
	Style.text(o, Style.num(800), "×%d" % shown, Vector2(10, 0), 32, Color(Style.INK, t))
	o.draw_set_transform(shift, 0.0, Vector2.ONE)

## A fingertip pressing a card (taps).
func _icon_tap(o: Node2D, c: Vector2) -> void:
	o.draw_rect(Rect2(c + Vector2(-11, -14), Vector2(22, 30)), Style.CARD)
	o.draw_rect(Rect2(c + Vector2(-11, -14), Vector2(22, 30)), Style.INK, false, 2.0)
	o.draw_circle(c + Vector2(6, 4), 9.0, Style.ACCENT)
	o.draw_arc(c + Vector2(6, 4), 9.0, 0, TAU, 20, Style.INK, 2.0, true)
	o.draw_arc(c + Vector2(6, 4), 15.0, -0.8, 0.8, 10, Color(Style.INK, 0.5), 1.5, true)

## Two linked rings (best chain).
func _icon_chain(o: Node2D, c: Vector2) -> void:
	o.draw_arc(c + Vector2(-7, 0), 9.0, 0, TAU, 24, Style.INK, 3.5, true)
	o.draw_arc(c + Vector2(7, 0), 9.0, 0, TAU, 24, Style.ACCENT, 3.5, true)

## Four rules, each with a small printed diagram.
func _draw_rules(o: Node2D, pr: Rect2) -> void:
	var pages := _rules_pages()
	for dir in [-1, 1]:
		var enabled: bool = (_rules_page + dir) >= 0 and (_rules_page + dir) < pages
		var c := _page_arrow_rect(dir).get_center()
		var col := Color(Style.INK, 1.0 if enabled else 0.2)
		o.draw_circle(c, 20.0, Style.CARD)
		o.draw_arc(c, 20.0, 0, TAU, 24, col, 2.0, true)
		o.draw_polyline(PackedVector2Array([c + Vector2(-4 * dir, -8), c + Vector2(4 * dir, 0), c + Vector2(-4 * dir, 8)]), col, 3.0, true)
	_page_dots(o, Vector2(pr.get_center().x, pr.position.y + 128.0), _rules_page, pages)
	_o_base += Vector2(_page_slide * pr.size.x * 0.6, 0)
	o.draw_set_transform(_o_base, 0.0, Vector2.ONE)
	if _rules_page > 0:
		_draw_rule_cards(o, pr)
		return
	var rows := [
		"Tap a card. Every face-up card of its colour jumps into the tray.",
		"Each card that leaves flips the one below. If it matches the tray, it jumps in too: a chain.",
		"When all of a group is in the tray, it bursts and frees its spot.",
		"The tray holds three groups. A fourth is your last chance to burst one.",
	]
	var red := Style.group_color(0)
	var blue := Style.group_color(1)
	for i in rows.size():
		var y := pr.position.y + 200.0 + i * 118.0
		var ix := pr.position.x + 90.0
		match i:
			0:
				_mini_card(o, Vector2(ix - 22, y), red, 0, -0.12)
				_mini_card(o, Vector2(ix + 22, y), red, 0, 0.12)
				o.draw_line(Vector2(ix, y + 38), Vector2(ix, y + 52), Style.INK, 3.0)
				o.draw_colored_polygon(PackedVector2Array([Vector2(ix - 7, y + 50), Vector2(ix + 7, y + 50), Vector2(ix, y + 58)]), Style.INK)
			1:
				_mini_card(o, Vector2(ix - 26, y), Style.INK, -1, 0.0, false)
				o.draw_line(Vector2(ix - 6, y), Vector2(ix + 8, y), red, 4.0)
				_mini_card(o, Vector2(ix + 28, y), red, 0, 0.0)
			2:
				for k in 4:
					_mini_card(o, Vector2(ix - 30 + k * 20, y + absf(k - 1.5) * 4.0), blue, 1, (k - 1.5) * 0.12)
				Style.star(o, Vector2(ix + 44, y - 30), 12.0, 5.0, Style.COIN)
			3:
				for k in 4:
					var r := Rect2(Vector2(ix - 58 + k * 30, y - 20), Vector2(24, 34))
					if k < 3:
						o.draw_rect(r, Style.group_color(k * 2))
						o.draw_rect(r, Style.INK, false, 1.5)
					else:
						Style.hatch(o, r, Color(Style.ACCENT, 0.6), 5.0, 1.5)
						o.draw_rect(r, Style.ACCENT, false, 2.0)
		_wrapped(o, rows[i], Vector2(pr.position.x + 170.0, y - 30.0), pr.size.x - 210.0, 22)

## Rule pages 2+: each card in a grid, with its few words (or the level it
## arrives on, if not reached yet).
func _draw_rule_cards(o: Node2D, pr: Rect2) -> void:
	var items := _rule_items()
	var drop := 1.0 - Style.ease_back(clampf(_overlay_age / 0.42, 0.0, 1.0))
	var first := (_rules_page - 1) * RULES_PER_PAGE
	for k in _rules_cards.size():
		var it: Array = items[first + k]
		var c := _rule_tile_center(k)
		var card := _rules_cards[k]
		card.position = c + Vector2(_page_slide * pr.size.x * 0.6, -H * 0.5 * drop + H * 0.7 * maxf(_exit_t, 0.0) ** 2)
		card.z_index = 5
		var unlocked := Progress.cascade_level >= int(it[1])
		var y := c.y + 100.0
		if unlocked:
			var words := String(it[2])
			var fs := 16
			while fs > 11 and Style.text_width(Style.serif(600, 48), words, fs) > 158.0:
				fs -= 1
			Style.text(o, Style.serif(600, 48), words, Vector2(c.x, y), fs, Style.INK)
		else:
			Style.caps(o, "Level %d" % (int(it[1]) + 1), Vector2(c.x, y), 13, Color(Style.INK, 0.5), 0.16)

## Dots for pages: the current one bigger and ink, the rest faint.
func _page_dots(o: Node2D, c: Vector2, page: int, count: int) -> void:
	for i in count:
		var dc := c + Vector2((i - (count - 1) * 0.5) * 16.0, 0)
		o.draw_circle(dc, 4.5 if i == page else 3.0, Style.INK if i == page else Color(Style.INK, 0.25))

func _mini_card(o: Node2D, c: Vector2, col: Color, g: int, rot: float, up := true) -> void:
	o.draw_set_transform(c, rot, Vector2.ONE)
	var r := Rect2(Vector2(-22, -30), Vector2(44, 60))
	o.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Style.INK)
	o.draw_rect(r, Style.CARD if up else Style.INK)
	if up:
		o.draw_rect(Rect2(r.position, Vector2(44, 9)), col)
		if g >= 0:
			Style.group_symbol(o, g, Vector2(0, 8), 8.0, Color(col, 0.5))
	o.draw_rect(r, Style.INK, false, 2.0)
	o.draw_set_transform(_o_base, 0.0, Vector2.ONE)

## Left-aligned serif paragraph, wrapped to a width. Lines are balanced:
## it uses the narrowest width that needs no more lines than the full width,
## so a paragraph never ends on one lonely word.
func _wrapped(o: Node2D, text: String, at: Vector2, width: float, size: int) -> void:
	var f := Style.serif(500, 24)
	var lines := _wrap_lines(f, text, width, size)
	var lo := width * 0.4
	var hi := width
	for i in 12:
		var mid := (lo + hi) * 0.5
		if _wrap_lines(f, text, mid, size).size() <= lines.size():
			hi = mid
		else:
			lo = mid
	lines = _wrap_lines(f, text, hi + 1.0, size)
	var g := Style._grow(size)
	for i in lines.size():
		o.draw_string(f, Vector2(at.x, at.y + g + i * g * 1.3), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, g, Style.INK)

func _wrap_lines(f: Font, text: String, width: float, size: int) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var trial := word if line == "" else line + " " + word
		if Style.text_width(f, trial, size) > width and line != "":
			out.append(line)
			line = word
		else:
			line = trial
	out.append(line)
	return out

## A sticker book of every group. A collected group is a little fan of its
## printed cards with the name underneath and a stamp for how many times it's
## burst; the rest are dashed empty spaces waiting to be filled.
func _draw_album(o: Node2D, pr: Rect2) -> void:
	var pages := _album_pages()
	_album_page = clampi(_album_page, 0, pages.size() - 1)
	var page: Dictionary = pages[_album_page]
	var normal := LevelGen.load_groups()
	var got := 0
	for g in normal:
		got += 1 if Progress.album.has(g.id) else 0
	var fs := Progress.featured_set()
	var set_groups: Array = fs.set.groups
	var total := normal.size()
	var filled := got
	var line := "%d of %d collected" % [got, total]
	var bar_col := Style.COIN
	if page.kind == "set":
		var missing := Progress.set_missing()
		total = set_groups.size()
		filled = total - missing.size()
		line = "%s  ·  %d day%s left" % [fs.set.name, fs.days_left, "" if fs.days_left == 1 else "s"]
		bar_col = Style.ACCENT
	elif page.kind == "stamps":
		total = Progress.STAMPS.size() * 3
		filled = Progress.stamps.size()
		line = "Stamps  ·  %d of %d" % [filled, total]
	elif page.kind == "stats":
		filled = total
		line = "Your stats"
	elif page.kind == "rare":
		var rare := LevelGen.load_rare()
		total = rare.size()
		filled = 0
		for g in rare:
			filled += 1 if Progress.album.has(g.id) else 0
		line = "Rare  ·  %d of %d found" % [filled, total]
	# Progress bar, then one line of caps with the page number.
	var bar := Rect2(Vector2(pr.position.x + 92.0, pr.position.y + 122.0), Vector2(pr.size.x - 184.0, 12.0))
	o.draw_rect(Rect2(bar.position + Vector2(2, 2), bar.size), Style.INK)
	o.draw_rect(bar, Style.PAPER_DEEP)
	var fill := bar
	fill.size.x *= float(filled) / maxf(total, 1)
	o.draw_rect(fill, bar_col)
	o.draw_rect(bar, Style.INK, false, 1.5)
	Style.caps(o, line, Vector2(pr.get_center().x, pr.position.y + 152.0), 12, Color(Style.INK, 0.6), 0.16)
	_page_dots(o, Vector2(pr.get_center().x, pr.position.y + 176.0), _album_page, pages.size())
	for dir in [-1, 1]:
		var enabled: bool = (_album_page + dir) >= 0 and (_album_page + dir) < pages.size()
		var c := _page_arrow_rect(dir).get_center()
		var col := Color(Style.INK, 1.0 if enabled else 0.2)
		o.draw_circle(c, 20.0, Style.CARD)
		o.draw_arc(c, 20.0, 0, TAU, 24, col, 2.0, true)
		o.draw_polyline(PackedVector2Array([c + Vector2(-4 * dir, -8), c + Vector2(4 * dir, 0), c + Vector2(-4 * dir, 8)]), col, 3.0, true)
	_o_base += Vector2(_page_slide * pr.size.x * 0.6, 0)
	o.draw_set_transform(_o_base, 0.0, Vector2.ONE)
	if page.kind == "set":
		_draw_album_set(o, pr, fs, normal)
		return
	if page.kind == "stamps":
		_draw_album_stamps(o, pr)
		return
	if page.kind == "stats":
		_draw_album_stats(o, pr)
		return
	var items: Array = page.items
	for k in items.size():
		var gd: Dictionary = items[k][0]
		_draw_album_tile(o, _album_tile(k), gd, int(items[k][1]), int(Progress.album.get(gd.id, 0)), bool(items[k][2]))

## Stamps: one row per family: its name and progress to the next stamp, then
## bronze, silver and gold medals (filled once earned, dashed with the
## target otherwise).
func _draw_album_stamps(o: Node2D, pr: Rect2) -> void:
	var metals := [Color("c98b4f"), Color("b9c0c8"), Style.COIN]
	for i in Progress.STAMPS.size():
		var st: Array = Progress.STAMPS[i]
		var y := pr.position.y + 206.0 + i * 64.0
		var x := pr.position.x + 40.0
		var v := Progress.stamp_value(st[0])
		o.draw_string(Style.serif(700, 48), Vector2(x, y + 2.0), String(st[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Style.INK)
		var next := -1
		for tier in 3:
			if not Progress.has_stamp(st[0], tier):
				next = int(st[2][tier])
				break
		var prog := "All done" if next == -1 else "%s / %s" % [_short_num(v), _short_num(next)]
		Style.caps(o, prog, Vector2(x + Style.caps_width(prog, 12, 0.12) * 0.5, y + 24.0), 12, Color(Style.INK, 0.55), 0.12)
		for tier in 3:
			var c := Vector2(pr.end.x - 170.0 + tier * 58.0, y + 6.0)
			if Progress.has_stamp(st[0], tier):
				o.draw_circle(c + Vector2(3, 3), 23.0, Style.INK)
				o.draw_circle(c, 23.0, metals[tier])
				o.draw_arc(c, 23.0, 0, TAU, 32, Style.INK, 2.0, true)
				o.draw_arc(c, 17.0, 0, TAU, 32, Color(Style.INK, 0.35), 1.0, true)
				Style.star(o, c, 10.0, 4.5, Style.CARD)
				# A shine sweeps across earned medals as the page opens.
				var sh := (_clock - _page_at - 0.2 - i * 0.06 - tier * 0.05) / 0.35
				if sh > 0.0 and sh < 1.0:
					var sx := c.x - 26.0 + 52.0 * sh
					o.draw_line(Vector2(sx - 6, c.y + 20), Vector2(sx + 6, c.y - 20), Color(1, 1, 1, 0.8 * sin(sh * PI)), 6.0, true)
			else:
				for k in 16:
					var a0 := k * TAU / 16.0
					o.draw_arc(c, 23.0, a0, a0 + TAU / 32.0, 4, Color(Style.INK, 0.3), 1.5, true)
				if int(st[2][tier]) == next and next > 0:
					# The next medal to earn: a ring showing how close you are.
					var f := clampf(float(v) / float(next), 0.0, 1.0)
					if f > 0.0:
						o.draw_arc(c, 23.0, -PI * 0.5, -PI * 0.5 + TAU * f, 32, Style.ACCENT, 3.5, true)
				Style.caps(o, _short_num(int(st[2][tier])), c, 11, Color(Style.INK, 0.5), 0.05)

## Stats: big numbers in two columns.
func _draw_album_stats(o: Node2D, pr: Rect2) -> void:
	var rows := [["Cards burst", Progress.stat("cards")], ["Best tap", Progress.stat("best_tap")],
		["Cascades", Progress.stat("jackpots")], ["3-star levels", Progress.stamp_value("stars3")],
		["Bosses beaten", Progress.stamp_value("bosses")], ["Days played", Progress.days.size()],
		["Rare found", Progress.stamp_value("rare")], ["Sets finished", Progress.stamp_value("sets")]]
	for i in rows.size():
		var c := Vector2(pr.get_center().x + (-1.0 if i % 2 == 0 else 1.0) * 130.0, pr.position.y + 230.0 + (i / 2) * 120.0)
		# The numbers roll up from zero as the page opens.
		var k := clampf((_clock - _page_at - 0.15) / 0.8, 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)
		Style.text(o, Style.num(800), _short_num(roundi(int(rows[i][1]) * k)), c, 48, Style.INK)
		Style.caps(o, String(rows[i][0]), c + Vector2(0, 40.0), 13, Color(Style.INK, 0.55), 0.16)

static func _short_num(n: int) -> String:
	if n >= 10000:
		return "%dk" % (n / 1000)
	if n >= 1000:
		return "%d,%03d" % [n / 1000, n % 1000]
	return str(n)

## The featured set: six tiles that fill in as its groups burst during these
## two weeks, the prize underneath, and a gold ribbon once it's done.
func _draw_album_set(o: Node2D, pr: Rect2, fs: Dictionary, normal: Array) -> void:
	var ids: Array = fs.set.groups
	var missing := Progress.set_missing()
	for k in ids.size():
		var idx := -1
		for i in normal.size():
			if normal[i].id == ids[k]:
				idx = i
		if idx < 0:
			continue
		var r := _album_tile(k)
		_draw_album_tile(o, r, normal[idx], idx, 0 if missing.has(ids[k]) else 1, false, false)
	# The prize (or the ribbon, once won).
	var c := Vector2(pr.get_center().x, _album_tile(5).end.y + 90.0)
	if Progress.set_done:
		_draw_ribbon(o, c, 1.0)
		Style.text(o, Style.serif(700, 48), "Set complete", c + Vector2(0, 96), 26, Style.INK)
	else:
		Style.coin(o, c + Vector2(-64, 0), 24.0)
		Style.text(o, Style.serif(800, 72), "+%d" % Progress.SET_REWARD, c + Vector2(26, -2), 40, Style.INK)
		_draw_ribbon(o, c + Vector2(0, 92), 0.5, 0.35)
	var times := int(Progress.ribbons.get(fs.set.id, 0))
	if times > 1:
		Style.caps(o, "Won %d times" % times, c + Vector2(0, 118), 13, Color(Style.INK, 0.6), 0.16)

## A gold rosette ribbon: a scalloped disc with two tails.
func _draw_ribbon(o: Node2D, c: Vector2, k: float, alpha := 1.0) -> void:
	var gold := Color(Style.COIN, alpha)
	var ink := Color(Style.INK, alpha)
	for side in [-1, 1]:
		var tail := PackedVector2Array([c + Vector2(side * 8, 0) * k, c + Vector2(side * 30, 70) * k,
			c + Vector2(side * 18, 60) * k, c + Vector2(side * 6, 74) * k, c + Vector2(side * -4, 10) * k])
		o.draw_colored_polygon(tail, Color(Style.ACCENT, alpha))
		o.draw_polyline(tail + PackedVector2Array([tail[0]]), ink, 2.0, true)
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(c + Vector2.from_angle(a) * (40.0 if i % 2 == 0 else 34.0) * k)
	o.draw_colored_polygon(pts, gold)
	o.draw_polyline(pts + PackedVector2Array([pts[0]]), ink, 2.0, true)
	o.draw_circle(c, 24.0 * k, Color(Style.CARD, alpha))
	o.draw_arc(c, 24.0 * k, 0, TAU, 32, ink, 2.0, true)
	Style.star(o, c, 15.0 * k, 6.5 * k, gold)

## One sticker: a little fan of the group's printed cards, its name, and a
## stamp for how many times it's burst. Not collected yet: a dashed space.
func _draw_album_tile(o: Node2D, r: Rect2, gd: Dictionary, ci: int, times: int, rare: bool, stamp := true) -> void:
	var col := Style.group_color(ci)
	if times <= 0:
		_album_dashed(o, r.grow(-4))
		if rare:
			Style.star(o, r.get_center() + Vector2(0, -6), 26.0, 11.0, Color(Style.COIN, 0.5))
		elif not stamp:
			# The featured set: the group's colour and shape, still to find.
			Style.group_symbol(o, ci, r.get_center(), 22.0, Color(col, 0.35))
		else:
			Style.text(o, Style.serif(600, 72), "?", r.get_center() + Vector2(0, -6), 44, Color(Style.INK, 0.18))
		return
	if rare:
		o.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Style.INK)
		o.draw_rect(r, Style.COIN)
		o.draw_rect(r, Style.INK, false, 2.0)
	var fc := r.get_center() + Vector2(0, -18)
	for k in 3:
		o.draw_set_transform(fc + Vector2((k - 1) * 16.0, 0), (k - 1) * 0.2, Vector2(0.42, 0.42))
		var cr := Rect2(Vector2(-62, -86), Vector2(124, 172))
		o.draw_rect(Rect2(cr.position + Vector2(5, 5), cr.size), Style.INK)
		o.draw_rect(cr, Style.CARD)
		o.draw_rect(Rect2(cr.position, Vector2(124, 22)), col)
		o.draw_line(Vector2(-62, -64), Vector2(62, -64), Style.INK, 3.0)
		Style.group_symbol(o, ci, Vector2(0, 14), 22.0, Color(col, 0.55))
		if rare:
			o.draw_rect(cr.grow(-6), Style.COIN, false, 8.0)
		o.draw_rect(cr, Style.INK, false, 3.0)
	o.draw_set_transform(_o_base, 0.0, Vector2.ONE)
	var name_size := 20
	while name_size > 12 and Style.text_width(Style.serif(700, 48), gd.name, name_size) > r.size.x - 8:
		name_size -= 1
	Style.text(o, Style.serif(700, 48), gd.name, Vector2(r.get_center().x, r.end.y - 18.0), name_size, Style.INK)
	if not stamp:
		return
	var sc := r.position + Vector2(r.size.x - 22.0, 20.0)
	o.draw_circle(sc + Vector2(2, 2), 16.0, Style.INK)
	o.draw_circle(sc, 16.0, Style.CARD if rare else Style.COIN)
	o.draw_arc(sc, 16.0, 0, TAU, 24, Style.INK, 2.0, true)
	Style.text(o, Style.sans(800), "×%d" % times, sc + Vector2(0, -1), 12, Style.INK)

func _album_dashed(o: Node2D, r: Rect2) -> void:
	var col := Color(Style.INK, 0.22)
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for k in 4:
		o.draw_dashed_line(pts[k], pts[k + 1], col, 2.0, 8.0, true)

## Seven small day cards in a row (today's highlighted), and a big card
## that flips over to show today's coins.
func _draw_gift(o: Node2D, pr: Rect2) -> void:
	if _gift.is_empty():
		return
	var day: int = _gift.day
	# (The day strip below says which day it is; no sentence needed.)
	for i in 7:
		var c := Vector2(pr.get_center().x + (i - 3) * 64.0, pr.position.y + 184.0)
		var r := Rect2(c - Vector2(26, 30), Vector2(52, 60))
		var done := i + 1 < day
		var today := i + 1 == day
		o.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(Style.INK, 0.9 if today else 0.25))
		o.draw_rect(r, Style.COIN if today else (Style.PAPER_DEEP if done else Style.CARD))
		o.draw_rect(r, Style.INK, false, 2.0 if today else 1.0)
		Style.caps(o, "Day %d" % (i + 1), c + Vector2(0, -14), 11, Style.INK, 0.06)
		Style.text(o, Style.serif(700, 48), str(Progress.GIFTS[i]), c + Vector2(0, 10), 18, Color(Style.INK, 0.4 if done else 1.0))
	# The big card.
	var cc := Vector2(pr.get_center().x, pr.position.y + 390.0)
	var sx := absf(cos(_gift_open * PI))
	var showing_face := _gift_open > 0.5
	var k := GIFT_SCALE
	o.draw_set_transform(cc, 0.0, Vector2(maxf(sx, 0.02) * k, k))
	var r := Rect2(Vector2(-62, -86), Vector2(124, 172))
	o.draw_rect(Rect2(r.position + Vector2(5, 5), r.size), Style.INK)
	if showing_face:
		o.draw_rect(r, Style.CARD)
		o.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(120, 16)), Style.COIN)
		o.draw_line(Vector2(-60, -68), Vector2(60, -68), Style.INK, 2.0)
		Style.coin(o, Vector2(0, -10), 26.0)
		Style.text(o, Style.serif(800, 72), "+%d" % int(_gift.coins), Vector2(0, 46), 34, Style.INK)
		o.draw_rect(r, Style.INK, false, 2.0)
	else:
		o.draw_rect(r, Style.INK)
		Style.hatch(o, r.grow(-8), Color(Style.PAPER, 0.22), 7.0, 1.2)
		o.draw_rect(r, Style.INK, false, 2.0)
		_draw_gift_ribbon(o, cc, k)
	o.draw_set_transform(_o_base, 0.0, Vector2.ONE)
	if _gift_cut <= 0.0:
		_draw_gift_hint(o, cc, k)
	# The blade's path while swiping.
	if _gift_trail.size() > 1:
		var pts := PackedVector2Array(_gift_trail)
		o.draw_polyline(pts, Color(Style.INK, 0.25), 14.0, true)
		o.draw_polyline(pts, Style.CARD, 5.0, true)

## The ribbon: a vertical band and a horizontal band with a star knot. After
## the cut, the two halves of the vertical band spring apart and fall, and
## the horizontal band slides off, before the card flips.
func _draw_gift_ribbon(o: Node2D, cc: Vector2, k: float) -> void:
	var c := _gift_cut
	var cy := _gift_cut_y
	var fall := c * c
	o.draw_set_transform(cc + Vector2(-30.0 * fall, -12.0 * c + 52.0 * fall), -0.5 * fall, Vector2(k, k))
	o.draw_rect(Rect2(Vector2(-8, -86), Vector2(16, 86 + cy - 1)), Color(Style.ACCENT, 1.0 - fall))
	o.draw_set_transform(cc + Vector2(30.0 * fall, 300.0 * fall), 0.6 * fall, Vector2(k, k))
	o.draw_rect(Rect2(Vector2(-8, cy + 1), Vector2(16, 86 - cy - 1)), Color(Style.ACCENT, 1.0 - fall))
	o.draw_set_transform(cc + Vector2(420.0 * fall, 40.0 * fall), 0.3 * fall, Vector2(k, k))
	o.draw_rect(Rect2(Vector2(-62, -8), Vector2(124, 16)), Color(Style.ACCENT, 1.0 - fall))
	Style.star(o, Vector2.ZERO, 24.0, 10.0, Color(Style.COIN, 1.0 - fall), fall * 4.0)
	o.draw_set_transform(cc, 0.0, Vector2(k, k))

## Until cut: a dotted cut line and a ghost finger sweeping across the card.
func _draw_gift_hint(o: Node2D, cc: Vector2, k: float) -> void:
	var r := Rect2(cc - Vector2(62, 86) * k, Vector2(124, 172) * k)
	var y := r.get_center().y + 40.0
	o.draw_dashed_line(Vector2(r.position.x - 30, y), Vector2(r.end.x + 30, y), Color(Style.INK, 0.35), 2.0, 10.0, true)
	if _overlay_age < 1.2:
		return
	var t := fmod(_overlay_age - 1.2, 1.8)
	var kk := clampf((t - 0.2) / 0.9, 0.0, 1.0)
	kk = kk * kk * (3.0 - 2.0 * kk)
	var p := Vector2(lerpf(r.position.x - 40.0, r.end.x + 40.0, kk), y + 18.0)
	var a := clampf(minf(t / 0.2, (1.8 - t) / 0.3), 0.0, 1.0)
	o.draw_circle(p + Vector2(3, 3), 18.0, Color(Style.INK, a))
	o.draw_circle(p, 18.0, Color(Style.CARD, a))
	o.draw_arc(p, 18.0, 0, TAU, 32, Color(Style.INK, a), 2.5, true)
