extends Node
## Screenshots of Magnet Cascade, including frames caught mid-chain.
##   godot --always-on-top --path . res://tests/capture_cascade.tscn

const OUT := "user://shots_cascade"
var game: Node2D
var _deadline_ms := 0

func _ready() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_move_to_foreground()
	_deadline_ms = Time.get_ticks_msec() + 240000
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for f in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + "/" + f))
	Progress.save_enabled = false
	Playtest.enabled = false
	for key in ["magnet", "bomb", "peek", "lock", "wild"]:
		Progress.seen[key] = true
	Progress.reset()
	Audio.enabled = false
	game = load("res://game/cascade_scene.tscn").instantiate()
	add_child(game)
	await _wait(1.6)
	await _shot("00_title")
	game._title_play()
	await _wait(0.6)
	await _shot("01_deal")
	await _idle()
	await _wait(0.4)
	await _shot("02_level1_ready")
	# Finger down: the preview lights everything the tap will grab.
	var p0: int = game.level.solution[0]
	game._pressed_pile = p0
	game._show_preview(p0)
	await _wait(0.1)
	await _shot("03_press_preview")
	game._pressed_pile = -1
	game._show_preview(-1)
	game.tap_pile(p0)
	await _wait(0.2)
	await _shot("04_grab")
	await _wait(0.35)
	await _shot("05_chain")
	await _wait(0.4)
	await _shot("06_burst")
	await _play_rest_finale()
	await _wait(1.6)
	await _shot("07_win")
	await _wait(1.4)
	await _shot("08_win_final")
	Progress.cascade_level = 6
	Progress.stars = {"cascade_0": 3, "cascade_1": 2, "cascade_2": 3, "cascade_3": 1, "cascade_4": 2, "cascade_5": 3}
	game.open_map()
	await _wait(0.8)
	await _shot("09_map")
	game._map_page = 1
	await _wait(0.2)
	await _shot("09b_map_page2")
	game.close_overlay()
	game.start_daily()
	await _idle()
	await _shot("09c_daily_start")
	var dsol: Array = game.level.solution
	for dp in dsol:
		await _idle()
		game.tap_pile(int(dp))
	while game._overlay == "" and not _expired():
		await get_tree().process_frame
	await _wait(2.6)
	await _shot("09d_daily_win")

	# A big level, catching frames through each tap.
	for idx in [4, 9]:
		game.start_level(idx)
		await _idle()
		await _shot("1%d_level%d_start" % [idx, idx + 1])
		var n := 0
		for pile in game.level.solution:
			await _idle()
			game.tap_pile(int(pile))
			for k in 4:
				await _wait(0.16)
				await _shot("1%d_tap%02d_f%d" % [idx, n, k])
			n += 1
			if _expired():
				break
		await _wait(1.8)
		await _shot("1%d_end" % idx)

	# Danger and loss: tap the worst choices on a hard level.
	game.start_level(10)
	await _idle()
	var guard := 0
	while game._overlay == "" and guard < 20 and not _expired():
		await _idle()
		var worst := -1
		for p in game.board.choices():
			if game.board.would_crowd(p):
				worst = p
		if worst == -1:
			if game.board.choices().is_empty():
				break
			worst = game.board.choices()[0]
		game.tap_pile(worst)
		await _idle()
		if game.board.in_danger():
			await _wait(0.2)
			await _shot("30_danger")
		guard += 1
	await _wait(1.0)
	await _shot("31_lose")
	game._overlay = ""
	game.start_level(6)
	await _idle()
	game.open_settings()
	await _wait(0.8)
	await _shot("40_settings")
	game.close_overlay()
	game.hint()
	await _wait(0.9)
	await _shot("41_hint_finger")
	# Force a lose screen with one group nearly done.
	var b: Cascade = game.board
	b.tray = [0, 1]
	b.tray_cards = {0: [0, 1, 2], 1: [4]}
	game._show_lose()
	await _wait(1.0)
	await _shot("42_lose_close")
	game.retry()
	await _wait(0.35)
	await _shot("43_intro_tray_slide")
	print("saved shots to ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()

func _play_rest_finale() -> void:
	var sol: Array = game.level.solution
	for i in range(1, sol.size()):
		await _idle()
		game.tap_pile(int(sol[i]))
	# Catch the finale on the way to the results card.
	while not game.board.is_won() and not _expired():
		await get_tree().process_frame
	await _wait(0.9 * 1.6 + 0.5)
	await _shot("06b_finale")
	while game._overlay == "" and not _expired():
		await get_tree().process_frame

func _play_rest() -> void:
	var sol: Array = game.level.solution
	for i in range(1, sol.size()):
		await _idle()
		game.tap_pile(int(sol[i]))
	await _idle()

func _idle() -> void:
	while game.is_busy() and game._overlay == "" and not _expired():
		await get_tree().process_frame

func _expired() -> bool:
	return Time.get_ticks_msec() > _deadline_ms

func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end and not _expired():
		await get_tree().process_frame

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, shot_name])
