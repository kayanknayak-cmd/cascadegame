extends Node
## Runs the in-game speed test on this computer and quits.
##   godot --always-on-top --path . res://tests/speed_quick.tscn

func _ready() -> void:
	Progress.save_enabled = false
	Playtest.enabled = false
	Audio.enabled = false
	var game: Node2D = load("res://game/cascade_scene.tscn").instantiate()
	game.show_title = false
	add_child(game)
	await get_tree().process_frame
	await game.run_speed_test()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://speed_test.png")
	get_tree().quit()
