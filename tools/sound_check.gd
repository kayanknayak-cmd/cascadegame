extends Node
## Plays every game sound once, to catch missing files or bad calls.
##   godot --path . res://tools/sound_check.tscn

func _ready() -> void:
	var calls := [
		func(): Audio.pick(), func(): Audio.land(), func(): Audio.into_slot(2, 0), func(): Audio.flip(),
		func(): Audio.draw_card(), func(): Audio.recycle(), func(): Audio.deal_start(), func(): Audio.deal_tick(),
		func(): Audio.wrong(), func(): Audio.group_hit(2), func(): Audio.fan_note(3, 2), func(): Audio.star_pip(2),
		func(): Audio.coin(3), func(): Audio.coins_burst(), func(): Audio.button(), func(): Audio.hint(),
		func(): Audio.undo(), func(): Audio.low_moves(), func(): Audio.bonus_tick(5), func(): Audio.star(1),
		func(): Audio.win(), func(): Audio.lose(), func(): Audio.panel_in(), func(): Audio.streak_up(2),
		func(): Audio.grab(2), func(): Audio.link(3), func(): Audio.burst(1), func(): Audio.magnet_fire(),
		func(): Audio.bomb_blast(), func(): Audio.card_flung(), func(): Audio.danger(), func(): Audio.combo(2),
		func(): Audio.star_lost(), func(): Audio.panel_out(), func(): Audio.special_reveal(), func(): Audio.heartbeat()]
	Audio.music_start()
	for c in calls:
		c.call()
		await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(4.0).timeout
	print("sound check done: %d sounds" % calls.size())
	get_tree().quit()
