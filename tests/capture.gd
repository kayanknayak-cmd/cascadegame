extends Node
## Plays through the key moments and saves screenshots, including frames
## caught mid-animation, so the look can be checked without playing.
##   godot --path . res://tests/capture.tscn
## Opens a real window. Close the Godot editor first.

const OUT := "user://shots"
var game: Node2D
var _deadline_ms := 0

func _ready() -> void:
	# macOS slows background windows to a crawl; uncap and bring to front.
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_move_to_foreground()
	_deadline_ms = Time.get_ticks_msec() + 300000
	for f in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + "/" + f))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Progress.save_enabled = false
	Playtest.enabled = false
	Progress.reset()
	Audio.enabled = false
	game = load("res://game/game_scene.tscn").instantiate()
	add_child(game)
	await _wait(0.5)
	await _shot("01_intro_and_deal")
	await _wait(1.5)
	await _shot("02_level1_ready")

	# Drag the first card halfway to a slot.
	var src := 0
	var unit: Array = game.board.unit_at(src)
	var from: Vector2 = game.views[unit[-1]].position
	game._press(from)
	for i in 12:
		game._drag_to(from.lerp(game._slot_pos(0) + Vector2(0, 40), i / 12.0))
		await _wait(0.03)
	await _wait(0.1)
	await _shot("03_dragging")
	game._release(game._slot_pos(0))
	await _wait(0.6)

	# Play on to the first finished group and catch the celebration.
	var sol: Array = game.level.solution
	game.start_level(0)
	await _wait(2.0)
	var played := 0
	while played < sol.size() and game.board.completed.is_empty() and not _expired():
		_play(sol[played]); played += 1
		await _wait(0.35)
	await _wait(0.12)
	await _shot("04_group_hit")
	await _wait(0.45)
	await _shot("05_group_fan_banner")
	await _wait(0.75)
	await _shot("06_group_zip")
	while played < sol.size() and not _expired():
		_play(sol[played]); played += 1
		await _wait(0.3)
	await _wait(3.4)
	await _shot("07_moves_bonus")
	await _wait_overlay()
	await _wait(1.2)
	await _shot("08_win_stars")
	await _wait(1.2)
	await _shot("09_win_final")

	# A bigger level mid-game with groups in progress and a streak.
	Progress.coins = 240
	game.start_level(12)
	await _wait(2.6)
	await _shot("10_level13_start")
	sol = game.level.solution
	played = 0
	var shot_streak := false
	while played < sol.size() and not _expired():
		_play(sol[played]); played += 1
		await _wait(0.12)
		if game.streak >= 1 and not shot_streak:
			await _wait(0.4)
			await _shot("11_streak")
			shot_streak = true
		if game.board.completed.size() >= 2 and _slots_in_use() >= 2:
			break
	await _wait(2.0)
	await _shot("12_midgame")
	game.hint()
	await _wait(0.3)
	await _shot("13_hint")

	# Out of moves.
	game.start_level(4)
	await _wait(2.4)
	game.board.move_budget = game.board.moves_used + 1
	game.draw_card()
	await _wait(1.6)
	await _shot("14_out_of_moves")

	print("saved shots to ", ProjectSettings.globalize_path(OUT))
	get_tree().quit()

func _wait_overlay() -> void:
	while game._overlay == "" and not _expired():
		await get_tree().process_frame

func _slots_in_use() -> int:
	var n := 0
	for g in game.board.slot_group:
		if g != -1:
			n += 1
	return n

func _play(m: Array) -> void:
	game.try_move(Vector3i(int(m[0]), int(m[1]), int(m[2])))

func _expired() -> bool:
	return Time.get_ticks_msec() > _deadline_ms

func _wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end and not _expired():
		await get_tree().process_frame

func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [OUT, shot_name])
