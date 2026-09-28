extends Node
## Short screenshot run of one level, for checking a single feature.
##   godot --always-on-top --path . res://tests/capture_quick.tscn -- <level index>

const OUT := "user://shots_quick"

func _ready() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for f in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + "/" + f))
	Progress.save_enabled = false
	Playtest.enabled = false
	Progress.reset()
	for key in ["magnet", "bomb", "peek", "lock", "wild", "rare", "ice", "chain", "wrap", "color", "row", "shuffle"]:
		Progress.seen[key] = true
	Audio.enabled = false
	var idx := 12
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		idx = int(args[0])
	var game: Node2D = load("res://game/cascade_scene.tscn").instantiate()
	game.show_title = false
	add_child(game)
	await get_tree().process_frame
	if args.size() > 1 and args[1] == "rare":
		# Show the level with its first group swapped for a rare one.
		var lv: Dictionary = game.levels[idx].duplicate(true)
		var rng := RandomNumberGenerator.new()
		lv.groups[0] = Dress._as_level_group(LevelGen.load_rare()[0], lv.groups[0].cards.size(), rng, true)
		game._dressed["%d|%s" % [idx, Progress.featured_set().key]] = lv
		Progress.seen["rare"] = true
	game.start_level(idx)
	if idx == 0:
		await _wait(0.8)
		await _shot("00a_banner")
	await _until(func(): return not game.is_busy(), 10.0)
	await _wait(0.5)
	await _shot("00_start")
	if args.size() > 1 and args[1] == "events":
		Progress.week_key = Progress.week_id()
		Progress.week_cards = 130
		game._overlay = "title"
		game.open_events()
		await _wait(0.9)
		await _shot("01_events")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "shop":
		Progress.cascade_level = 13
		Progress.stars = {"cascade_0": 3}
		Progress.coins = 480
		Progress.boosters = {"slot": 2, "lucky": 1}
		Progress.backs = {"tartan": true}
		game._coin_shown = Progress.coins
		game._overlay = "title"
		game._show_overlay_buttons()
		game.open_shop()
		await _wait(0.15)
		await _shot("s0_shop_sliding")
		await _wait(0.65)
		await _shot("s1_shop")
		game._shop._buy_booster(1)
		await _wait(0.12)
		await _shot("s1b_bought")
		game._shop._pick(3)
		await _wait(0.1)
		await _shot("s1c_fan_turning")
		await _wait(0.5)
		await _shot("s1d_fan")
		game._close_shop()
		game.open_prelevel(13)
		await _wait(0.8)
		game._pre_click(game._pre_tile(0).get_center())
		await _wait(0.08)
		await _shot("s2a_prelevel_pick")
		await _wait(0.5)
		await _shot("s2_prelevel")
		game._close_prelevel()
		game.open_prelevel(9)
		await _wait(0.8)
		await _shot("s2b_prelevel_boss")
		game._close_prelevel()
		Progress.card_back = "navy"
		game._overlay = ""
		game._show_overlay_buttons()
		game.start_level(13)
		game._apply_boosters({"xray": true, "slot": true})
		await _until(func(): return not game.is_busy(), 10.0)
		await _wait(0.5)
		await _shot("s3_level_xray_navy")
		for b in ["lacquer", "botanical", "gilt", "tartan"]:
			Progress.card_back = b
			game._overlay = "title"
			game._show_overlay_buttons()
			await _wait(0.3)
			await _shot("s4_map_" + b)
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "dailyintro":
		Progress.cascade_level = 13
		game._overlay = "title"
		game._show_overlay_buttons()
		await _wait(0.5)
		game._open_daily()
		var t0 := Time.get_ticks_msec()
		for t in [0.2, 0.6, 0.9, 1.1, 1.35, 2.2]:
			await _until(func(): return Time.get_ticks_msec() - t0 >= int(t * 1000.0), 6.0)
			await _shot("d_%03d" % int(t * 100))
		for p in game.level.solution:
			await _until(func(): return not game.is_busy(), 10.0)
			game.tap_pile(int(p))
		await _until(func(): return game._overlay == "win", 15.0)
		await _wait(3.0)
		await _shot("d_win")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "inlevel":
		await _shot("l0_banner_icons_after")
		game.start_level(idx)
		await _wait(0.6)
		await _shot("l1_banner_icons")
		await _until(func(): return not game.is_busy(), 10.0)
		await _wait(0.4)
		await _shot("l2_undo_disabled")
		Progress.coins = 500
		game.peek()
		await _wait(0.4)
		await _shot("l3_peek_tags")
		var sol: Array = game.level.solution
		for k in sol.size() - 1:
			await _until(func(): return not game.is_busy(), 10.0)
			game.tap_pile(int(sol[k]))
		await _until(func(): return not game.is_busy(), 10.0)
		await _wait(0.3)
		await _shot("l4_last_group")
		game.tap_pile(int(sol[-1]))
		await _wait(0.9)
		await _shot("l5_final_burst")
		await _until(func(): return game._overlay == "win", 15.0)
		await _wait(3.0)
		await _shot("l6_win_icons")
		game.start_level(idx)
		await _until(func(): return not game.is_busy(), 10.0)
		game.tap_pile(int(sol[0]))
		await _until(func(): return not game.is_busy(), 10.0)
		game._show_lose()
		await _wait(0.9)
		await _shot("l7_lose_icons")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "pregrow":
		Progress.cascade_level = 13
		for i in 13:
			Progress.stars["cascade_%d" % i] = 3
		game._overlay = "title"
		game._show_overlay_buttons()
		await _wait(0.6)
		game._home_play(10)
		for t in [0.06, 0.14, 0.24, 0.6]:
			await _wait(t if t < 0.1 else 0.08)
			await _shot("g_%03d" % int(t * 100))
		game._close_prelevel()
		await _wait(0.3)
		game._title_play()
		await _wait(0.1)
		await _shot("g_play_button")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "pets":
		# The Pets page, buying one, the pet by the tray talking and helping.
		Progress.cascade_level = 20
		Progress.coins = 6000
		Progress.pets = {"owl": true}
		Progress.pet = "owl"
		game._coin_shown = Progress.coins
		game._overlay = "title"
		game._show_overlay_buttons()
		await _wait(0.8)
		await _shot("pt1_home_bubble")
		game.open_pets()
		await _wait(0.9)
		await _shot("pt2_page")
		game._pets_click(game._pet_tile(2).get_center())
		await _wait(0.5)
		await _shot("pt3_bought_dog")
		game._pets_click(game._pet_tile(0).get_center())
		game._close_pets()
		game._overlay = ""
		game._show_overlay_buttons()
		game.start_level(idx)
		await _wait(2.2)
		await _shot("pt4_level_hello")
		var sol: Array = game.level.solution
		var k := 0
		while not game._pet_ready() and k < sol.size() - 1:
			await _until(func(): return not game.is_busy(), 10.0)
			game.tap_pile(int(sol[k]))
			k += 1
		await _until(func(): return not game.is_busy(), 10.0)
		await _wait(0.3)
		await _shot("pt5_ready")
		game._use_pet()
		await _wait(0.5)
		await _shot("pt6_help")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "league":
		Progress.cascade_level = 40
		for i in 40:
			Progress.stars["cascade_%d" % i] = 3 if i % 4 else 2
		Progress.league_key = Progress.week_id()
		Progress.league_stars = 34
		Progress.league_best = 70
		Progress.max_stat("best_tap", 14)
		game._overlay = "title"
		game._show_overlay_buttons()
		await _wait(0.8)
		await _shot("lg1_home_badge")
		game.open_league()
		await _wait(1.4)
		await _shot("lg2_week")
		game._league_board = "streak"
		game._page_at = game._clock
		await _wait(1.0)
		await _shot("lg3_streak")
		game._events_tab = "event"
		game._show_overlay_buttons()
		await _wait(0.6)
		await _shot("lg4_event_tab")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "ad":
		# The win card's x2 chip, the stand-in ad, the doubled coins; the lose card's ad button; the gift's x2.
		for p in game.level.solution:
			await _until(func(): return not game.is_busy(), 10.0)
			game.tap_pile(int(p))
		await _until(func(): return game._overlay == "win", 15.0)
		await _wait(3.4)
		await _shot("ad1_win_chip")
		game._watch_double()
		await _wait(1.2)
		await _shot("ad2_stand_in")
		await _wait(2.6)
		await _shot("ad3_doubled")
		game.start_level(idx)
		await _until(func(): return not game.is_busy(), 10.0)
		game.tap_pile(int(game.level.solution[0]))
		await _until(func(): return not game.is_busy(), 10.0)
		game._show_lose()
		await _wait(0.9)
		await _shot("ad4_lose")
		game._overlay = "title"
		game._show_overlay_buttons()
		Progress.gift_day = Progress.local_date(-1)
		Progress.gift_run = 2
		game._open_gift()
		await _wait(0.6)
		game._cut_gift(0.0)
		await _wait(1.8)
		await _shot("ad5_gift")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "streak":
		Progress.cascade_level = 13
		Progress.coins = 3000
		game._coin_shown = Progress.coins
		var today := Progress.local_date()
		Progress.days = {}
		for i in range(1, 12):
			Progress.days[Progress.date_add(today, -i)] = true
		Progress.days.erase(Progress.date_add(today, -3))
		Progress.frozen = {Progress.date_add(today, -3): true}
		Progress.freezes = 1
		Progress.note_day()
		game._overlay = "title"
		game._show_overlay_buttons()
		game._celebrate_streak(0.3)
		await _wait(1.0)
		await _shot("st1_home_flame")
		game.open_streak()
		await _wait(0.9)
		await _shot("st2_panel")
		game._streak_buy("vacation")
		await _wait(0.5)
		await _shot("st3_vacation")
		game._close_streak()
		# Broken: the flame goes grey and cracked; the panel offers a repair.
		Progress.days = {today: true}
		Progress.frozen = {}
		Progress.vacation_until = ""
		Progress.streak_lost = 23
		Progress.streak_lost_on = today
		game._show_overlay_buttons()
		await _wait(0.4)
		await _shot("st4_home_broken")
		game.open_streak()
		await _wait(0.9)
		await _shot("st5_repair")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "surprise":
		# Golden card, mystery gift, sunset and weather, each mid-level.
		for li in [21, 26, 11, 16]:
			game.start_level(li)
			var sol: Array = game.level.solution
			var upto := mini(sol.size() - 1, 5 if li != 11 else sol.size() - 2)
			for k in upto:
				await _until(func(): return not game.is_busy(), 10.0)
				game.tap_pile(int(sol[k]))
			await _until(func(): return not game.is_busy(), 10.0)
			await _wait(1.2)
			await _shot("sp_%d_%s" % [li + 1, game._surprise])
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "motion":
		# Panels leaving, tap outside, the gear turning, pages sliding, banner subtitles.
		game._spin_gear()
		await _wait(0.1)
		await _shot("m1_gear_turning")
		game.open_settings()
		await _wait(0.6)
		game._leave(game.close_overlay)
		await _wait(0.14)
		await _shot("m2_settings_leaving")
		await _wait(0.4)
		Progress.cascade_level = 13
		game._overlay = "title"
		game._show_overlay_buttons()
		game.open_prelevel(13)
		await _wait(0.8)
		var outside := InputEventMouseButton.new()
		outside.button_index = MOUSE_BUTTON_LEFT
		outside.pressed = true
		outside.position = Vector2(game.ox + 20.0, 60.0)
		game._unhandled_input(outside)
		await _wait(0.1)
		await _shot("m3_prelevel_tap_outside")
		await _wait(0.4)
		await _shot("m4_back_home")
		game.open_album()
		await _wait(0.8)
		game._album_page = 1
		game._slide_page(1)
		await _wait(0.07)
		await _shot("m5_album_sliding")
		await _wait(0.5)
		game._leave(game._close_album)
		await _wait(0.4)
		game._overlay = ""
		game._show_overlay_buttons()
		game._cascade_moment(12)
		await _wait(0.6)
		await _shot("m6_banner_sub")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "panels":
		# Settings, a win card and a lose card.
		game.open_settings()
		Progress.music = false
		game._show_overlay_buttons()
		await _wait(0.8)
		await _shot("p1_settings")
		game.close_overlay()
		for p in game.level.solution:
			await _until(func(): return not game.is_busy(), 10.0)
			game.tap_pile(int(p))
		await _until(func(): return game._overlay == "win", 15.0)
		await _wait(3.0)
		await _shot("p2_win")
		game.start_level(idx)
		await _until(func(): return not game.is_busy(), 10.0)
		game._lost_streak = 3
		game._show_lose()
		game._lost_streak = 3
		await _wait(0.9)
		await _shot("p3_lose")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "bigtext":
		Progress.large_text = true
		Style.big = true
		Progress.cascade_level = 13
		Progress.stars = {"cascade_0": 3}
		game._overlay = "title"
		game._show_overlay_buttons()
		await _wait(0.8)
		await _shot("bt1_home")
		game.open_prelevel(13)
		await _wait(0.8)
		await _shot("bt2_prelevel")
		game._close_prelevel()
		game.open_shop()
		await _wait(0.8)
		await _shot("bt3_shop")
		game._close_shop()
		game.open_settings()
		await _wait(0.8)
		await _shot("bt4_settings")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "bonus":
		for p in game.level.solution:
			await _until(func(): return not game.is_busy(), 10.0)
			game.tap_pile(int(p))
		await _until(func(): return not game._vis.tray.is_empty() or game.board.is_won(), 5.0)
		var t0 := Time.get_ticks_msec()
		for t in [3.4, 4.0, 4.6, 5.2]:
			await _until(func(): return Time.get_ticks_msec() - t0 >= int(t * 1000.0), 8.0)
			await _shot("bonus_%d" % int(t * 10))
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "map2":
		Progress.cascade_level = 44
		for i in 44:
			Progress.stars["cascade_%d" % i] = 3 if i % 3 != 1 else 2
		Progress.boosters = {"shield": 1}
		Progress.win_streak = 2
		game._overlay = "title"
		game._show_overlay_buttons()
		game._home.focus(40)
		await _wait(1.0)
		await _shot("map2_a")
		game._home.focus(46)
		await _wait(0.6)
		await _shot("map2_b")
		# Pressing a bubble and a level card, then stretching past the bottom.
		game._home._press_key = "bubble:daily"
		game._home._down = true
		game._home._press_key = "level:44"
		await _wait(0.1)
		await _shot("map2_c_press")
		game._home._down = false
		game._home._press_key = ""
		game._home.scroll = -120.0
		await _wait(0.05)
		await _shot("map2_d_stretch")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "ceremony":
		Progress.cascade_level = 20
		Progress.stars = {"cascade_0": 3}
		game._overlay = "title"
		game._show_overlay_buttons()
		game._fresh_unlock = 20
		game._set_ceremony = "Cozy Winter"
		game._go_home()
		await _wait(0.9)
		await _shot("c1_pin_hop")
		await _wait(1.3)
		await _shot("c2_chapter")
		await _wait(4.0)
		await _shot("c3_ceremony")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "showme":
		Progress.seen.erase("ice")
		game.start_level(idx)
		await _until(func(): return game._overlay == "intro", 10.0)
		await _wait(0.8)
		await _shot("sm1_intro")
		game._close_intro()
		for p in game.level.solution:
			if game._showme_card != -1:
				break
			await _until(func(): return not game.is_busy(), 10.0)
			game.tap_pile(int(p))
			await _until(func(): return not game.is_busy(), 10.0)
		await _wait(0.6)
		await _shot("sm2_showme")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "homeintro":
		Progress.cascade_level = 13
		for i in 13:
			Progress.stars["cascade_%d" % i] = 3 if i % 3 else 2
		Progress.win_streak = 1
		Progress.coins = 340
		Progress.week_key = Progress.week_id()
		Progress.week_cards = 150
		game._coin_shown = Progress.coins
		game._overlay = "title"
		game._overlay_age = 1.0
		game._show_overlay_buttons()
		game._home.start_intro(true)
		var t0 := Time.get_ticks_msec()
		for t in [0.35, 0.95, 1.5, 2.0, 3.2]:
			await _until(func(): return Time.get_ticks_msec() - t0 >= int(t * 1000.0), 6.0)
			await _shot("i_%03d" % int(t * 100))
		game._home.scroll += 900.0
		await _wait(1.0)
		await _shot("j_back_arrow")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "home":
		# Some progress: 13 levels beaten, a gift box ready, a set half done.
		Progress.cascade_level = 13
		for i in 13:
			Progress.stars["cascade_%d" % i] = [3, 3, 2, 3, 1, 3, 2, 3, 3, 2, 3, 3, 2][i]
		Progress.boxes = {"1": true}
		Progress.win_streak = 2
		Progress.coins = 340
		var fs := Progress.featured_set()
		for k in 3:
			Progress.set_burst(fs.set.groups[k])
		Progress.collect("clockmaker")
		game._coin_shown = Progress.coins
		game._overlay = "title"
		game._overlay_age = 1.0
		game._show_overlay_buttons()
		await _wait(1.2)
		await _shot("01_home")
		game._home.scroll += 700.0
		await _wait(0.4)
		await _shot("02_home_scrolled")
		game._home.focus(9)
		await _wait(0.3)
		game._open_box(2)
		await _wait(0.25)
		await _shot("03_box_opening")
		await _wait(0.35)
		await _shot("03b_box_coins")
		await _wait(1.2)
		# A level just unlocked: the card turns over.
		Progress.stars["cascade_13"] = 3
		Progress.cascade_level = 14
		game._fresh_unlock = 14
		game._go_home()
		await _wait(0.9)
		await _shot("04_unlock_flip")
		await _wait(1.2)
		await _shot("05_unlocked")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "title":
		game._overlay = "title"
		game._overlay_age = 0.0
		game._show_overlay_buttons()
		await _wait(4.0)
		await _shot("01_title")
		Progress.cascade_level = 14
		Progress.stars = {"cascade_0": 3, "cascade_1": 3, "cascade_2": 2, "cascade_3": 3}
		game._go_home()
		await _wait(0.8)
		await _shot("02_map_total")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "share":
		for p in game.level.solution:
			await _until(func(): return not game.is_busy(), 10.0)
			game.tap_pile(int(p))
		await _until(func(): return game._overlay == "win", 15.0)
		await _wait(3.0)
		await _shot("01_win")
		# Fold the result card away to look at the board.
		var outside := InputEventMouseButton.new()
		outside.button_index = MOUSE_BUTTON_LEFT
		outside.pressed = true
		outside.position = Vector2(game.ox + 20.0, 20.0)
		game._unhandled_input(outside)
		await _wait(0.6)
		await _shot("01b_folded")
		game._set_win_fold(false)
		await _wait(0.5)
		game.open_share()
		await _wait(1.0)
		await _shot("02_share_panel")
		game._share_img.save_png(OUT + "/03_share_card.png")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "banner":
		game.start_level(idx)
		var t0 := Time.get_ticks_msec()
		for t in [0.5, 0.95, 1.25, 1.8]:
			await _until(func(): return Time.get_ticks_msec() - t0 >= int(t * 1000.0), 5.0)
			await _shot("b_%d" % int(t * 100))
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "teaser":
		for p in game.level.solution:
			await _until(func(): return not game.is_busy(), 10.0)
			game.tap_pile(int(p))
		await _until(func(): return game._overlay == "win", 15.0)
		await _wait(3.0)
		await _shot("01_teaser")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "intro":
		Progress.seen.clear()
		game._open_intro(game.INTROS[idx])
		await _wait(0.9)
		await _shot("01_intro")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "jackpot":
		game._cascade_moment(12)
		await _wait(0.5)
		await _shot("01_jackpot")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "settings":
		Progress.large_text = true
		game.open_settings()
		await _wait(0.8)
		await _shot("01_settings")
		game.close_overlay()
		await _wait(0.5)
		await _shot("02_large_text")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "wild":
		var v: CardView = game.views[game.board.top(1)]
		v.kind = 3
		v.queue_redraw()
		await _wait(0.2)
		await _shot("01_wild")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "gift":
		Progress.gift_day = Progress.local_date(-1)
		Progress.gift_run = 2
		game._overlay = "title"
		game._open_gift()
		await _wait(0.8)
		await _shot("01_gift")
		await _wait(1.0)
		await _shot("01b_gift_hint")
		# Swipe across the card.
		var r: Rect2 = game._gift_card_rect()
		var y := r.get_center().y + 30.0
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = Vector2(r.position.x - 20, y)
		game._unhandled_input(down)
		for i in 12:
			var mv := InputEventMouseMotion.new()
			mv.position = Vector2(lerpf(r.position.x - 20, r.end.x + 20, (i + 1) / 12.0), y + i * 2.0)
			game._unhandled_input(mv)
			await _wait(0.02)
			if i == 6:
				await _shot("01c_gift_swiping")
		await _wait(0.2)
		await _shot("02_gift_cut")
		await _wait(0.6)
		await _shot("03_gift_open")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "peek":
		Progress.coins = 100
		game.peek()
		await _wait(0.6)
		await _shot("01_peek")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "turn":
		game._turn(func(): game.start_level(idx + 1))
		await _wait(0.2)
		await _shot("01_turn_in")
		await _wait(0.2)
		await _shot("02_turn_out")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "goal":
		# Replays the level: the tag flying in, then after every tap.
		game.start_level(idx)
		await _until(func(): return game._goal_fly > 0.9, 10.0)
		await _wait(0.5)
		await _shot("01_goal_flyin")
		await _until(func(): return game._goal_fly <= 0.0 and not game.is_busy(), 10.0)
		await _wait(0.3)
		await _shot("02_goal_home")
		var k := 0
		for p in game.level.solution:
			await _until(func(): return not game.is_busy(), 10.0)
			game.tap_pile(int(p))
			await _until(func(): return not game.is_busy(), 10.0)
			await _shot("t%02d_%s" % [k, game._goal_state])
			k += 1
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "album":
		for gid in ["tea_time", "bakery", "picnic", "beach", "ocean", "garden", "flowers"]:
			Progress.collect(gid)
		Progress.album["tea_time"] = 6
		Progress.collect("clockmaker")
		var fs := Progress.featured_set()
		for k in 4:
			Progress.set_burst(fs.set.groups[k])
		game.open_album()
		await _wait(0.8)
		await _shot("01_album_set")
		game._album_page = 1
		await _wait(0.3)
		await _shot("02_album_page")
		game._album_page = game._album_pages().size() - 1
		await _wait(0.3)
		await _shot("03_album_rare")
		for k in 6:
			Progress.set_burst(fs.set.groups[k])
		game._album_page = 0
		await _wait(0.3)
		await _shot("04_album_set_done")
		Progress.stats = {"cards": 1340, "best_tap": 17, "jackpots": 4}
		for i in 23:
			Progress.stars["cascade_%d" % i] = 3
		Progress.days = {"a": 1, "b": 1, "c": 1, "d": 1}
		Progress.check_stamps()
		game._album_page = game._album_pages().size() - 2
		await _wait(0.3)
		await _shot("05_album_stamps")
		game._album_page = game._album_pages().size() - 1
		await _wait(0.3)
		await _shot("06_album_stats")
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "rules":
		Progress.cascade_level = 47
		game.open_rules()
		await _wait(0.8)
		await _shot("01_rules")
		for pg in range(1, game._rules_pages()):
			game._rules_page = pg
			game._build_rule_cards()
			await _wait(0.4)
			await _shot("0%d_rules" % (pg + 1))
		get_tree().quit()
		return
	if args.size() > 1 and args[1] == "locks":
		# Put visible locks on two top cards, then catch one springing open.
		var b: Cascade = game.board
		for q in [0, 5]:
			var c: int = b.top(q)
			b.lock[c] = 2 if q == 0 else 1
			game._vis.lock[c] = b.lock[c]
			game.views[c].locked = b.lock[c]
			game.views[c].queue_redraw()
		await _wait(0.2)
		await _shot("01_locks")
		var v: CardView = game.views[b.top(5)]
		game._ev_lock({"card": b.top(5), "pile": 5, "left": 0})
		await _wait(0.12)
		await _shot("02_unlocking")
		get_tree().quit()
		return
	var n := 0
	for p in game.level.solution:
		await _until(func(): return not game.is_busy(), 10.0)
		game.tap_pile(int(p))
		for k in 3:
			await _wait(0.2)
			await _shot("t%02d_%d" % [n, k])
		n += 1
	await _wait(3.0)
	await _shot("zz_end")
	get_tree().quit()

func _until(f: Callable, limit: float) -> void:
	var end := Time.get_ticks_msec() + int(limit * 1000.0)
	while not f.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame

func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await get_tree().process_frame

func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, n])
