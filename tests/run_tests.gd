extends Node
## Headless tests. Run as a scene so the autoloads exist:
##   godot --headless --path . res://tests/run_tests.tscn

var passed := 0
var failed := 0

func ok(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("  FAIL: ", label)

func _ready() -> void:
	Playtest.enabled = false
	Progress.save_enabled = false
	Progress.reset()
	_test_groups()
	_test_rules()
	_test_runs_and_flips()
	_test_draw_and_recycle()
	_test_budget_and_loss()
	_test_solver()
	_test_levels()
	await _test_screen()
	_test_cascade_rules()
	_test_cascade_specials()
	_test_cascade_locks()
	_test_cascade_wild()
	_test_cascade_obstacles()
	_test_cascade_new_specials()
	_test_reports()
	_test_fixes()
	_test_cascade_levels()
	await _test_cascade_screen()
	await _test_play_every_level()
	await _test_playtest_log()
	_test_meta()
	_test_album_sets()
	_test_dress()
	_test_goals()
	await _test_meeting_ideas()
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

# A tiny hand-made level: 2 groups of 2.
#   group 0 "Sea":   0 Crab, 1 Whale
#   group 1 "Farm":  2 Cow,  3 Pig
func _tiny(columns: Array, stock: Array, slots := 1, budget := 50) -> Board:
	return Board.from_level({"groups": [
		{"name": "Sea", "cards": ["Crab", "Whale"]},
		{"name": "Farm", "cards": ["Cow", "Pig"]}],
		"columns": columns, "stock": stock, "slots": slots, "budget": budget})

func _test_groups() -> void:
	print("groups")
	var groups := LevelGen.load_groups()
	ok(groups.size() >= 40, "at least 40 groups, got %d" % groups.size())
	ok(LevelGen.load_rare().size() >= 4, "at least 4 rare groups")
	var labels := {}
	var ids := {}
	for g in groups + LevelGen.load_rare():
		ok(not ids.has(g.id), "group id %s is unique" % g.id)
		ids[g.id] = true
		ok(String(g.get("family", "")) != "", "%s has a family" % g.id)
		ok(g.items.size() >= LevelGen.CARDS_PER_GROUP + 2, "%s has spare items to vary levels" % g.id)
		for item in g.items:
			var k := String(item).to_lower()
			ok(not labels.has(k), "'%s' appears in only one group (also in %s)" % [item, labels.get(k, "")])
			labels[k] = g.id

func _test_rules() -> void:
	print("rules")
	var b := _tiny([[0], [2]], [], 1)
	ok(b.check(Vector3i(Board.TO_SLOT, 0, 0)) == Board.Check.OK, "empty slot takes any card")
	b.apply(Vector3i(Board.TO_SLOT, 0, 0))
	ok(b.slot_group[0] == 0, "slot is claimed by the card's group")
	ok(b.check(Vector3i(Board.TO_SLOT, 1, 0)) == Board.Check.WRONG_GROUP, "claimed slot refuses another group")
	var before := b.moves_used
	b.spend_mistake()
	ok(b.moves_used == before + 1, "a wrong drop costs a move")
	ok(b.check(Vector3i(Board.TO_COLUMN, 1, 0)) == Board.Check.OK, "card can move into an empty column")
	var b2 := _tiny([[0, 1], [2, 3]], [], 2)
	ok(b2.check(Vector3i(Board.TO_SLOT, 0, 0)) == Board.Check.OK, "top card is playable")
	b2.apply(Vector3i(Board.TO_SLOT, 0, 0))     # Whale into slot 0
	ok(b2.check(Vector3i(Board.TO_SLOT, 1, 1)) == Board.Check.OK, "second group can start in slot 1")
	var b3 := b2.clone()
	b3.apply(Vector3i(Board.TO_SLOT, 1, 1))     # Pig into slot 1
	ok(b3.check(Vector3i(Board.TO_SLOT, 1, 0)) == Board.Check.WRONG_GROUP, "Cow can't join Sea")
	var ev := b3.apply(Vector3i(Board.TO_SLOT, 0, 0))   # Crab completes Sea
	ok(ev.completed_group == 0, "finishing a group reports it")
	ok(b3.slot_group[0] == -1, "finished group frees its slot")
	ok(b2.slot_group[1] == -1, "clone is independent of the original")
	b3.apply(Vector3i(Board.TO_SLOT, 1, 1))
	ok(b3.is_won(), "all groups finished = win")
	var b4 := _tiny([[0], [1]], [], 2)
	b4.apply(Vector3i(Board.TO_SLOT, 0, 0))
	ok(b4.check(Vector3i(Board.TO_SLOT, 1, 1)) == Board.Check.ILLEGAL, "a group can't be in two slots")

func _test_runs_and_flips() -> void:
	print("runs and flips")
	var b := _tiny([[2, 0], [1], [3]], [], 1)
	ok(b.face_down[0] == 1, "all but the top card start face-down")
	var ev := b.apply(Vector3i(Board.TO_COLUMN, 1, 0))   # Whale onto Crab
	ok(b.columns[0].size() == 3, "same group stacks in a pile")
	ok(b.unit_at(0).size() == 2, "the run of same-group cards moves together")
	ok(b.check(Vector3i(Board.TO_COLUMN, 2, 0)) == Board.Check.WRONG_GROUP, "Pig can't go on Whale")
	ev = b.apply(Vector3i(Board.TO_SLOT, 0, 0))
	ok(ev.cards.size() == 2, "the whole run went to the slot")
	ok(ev.completed_group == 0, "a two-card run finished its group")
	ok(ev.flipped_col == 0, "uncovering a face-down card flips it")
	ok(b.face_down[0] == 0, "the Cow is face-up now")

func _test_draw_and_recycle() -> void:
	print("draw and recycle")
	var b := _tiny([[0]], [3, 2, 1], 1)
	b.apply(Vector3i(Board.DRAW, 0, 0))
	ok(b.waste == [1], "draw turns the top stock card over")
	b.apply(Vector3i(Board.DRAW, 0, 0))
	b.apply(Vector3i(Board.DRAW, 0, 0))
	ok(b.stock.is_empty() and b.waste.size() == 3, "stock empties into the waste")
	var ev := b.apply(Vector3i(Board.DRAW, 0, 0))
	ok(ev.recycled and b.stock == [3, 2, 1], "empty stock recycles in the original order")

func _test_budget_and_loss() -> void:
	print("budget")
	var b := _tiny([[0], [1], [2], [3]], [], 2, 2)
	b.apply(Vector3i(Board.TO_SLOT, 0, 0))
	b.apply(Vector3i(Board.TO_SLOT, 1, 0))
	ok(b.moves_left() == 0 and not b.is_won(), "budget used up")
	ok(b.is_lost(), "no moves left and not won = lost")
	ok(b.legal_moves().is_empty(), "nothing is legal with no moves left")

func _test_solver() -> void:
	print("solver")
	var b := _tiny([[2, 0], [3, 1]], [], 1)
	var sol := Solver.new().solve(b)
	ok(not sol.is_empty(), "solver finds a win with only one slot")
	var r := b.clone()
	var legal := true
	for m in sol:
		legal = legal and r.check(m) == Board.Check.OK
		r.apply(m)
	ok(legal and r.is_won(), "the solver's moves are legal and win")

func _test_levels() -> void:
	print("levels")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	var groups := LevelGen.load_groups()
	var family := {}
	for g in groups:
		family[g.id] = g.family
	ok(data.levels.size() == 30, "30 levels")
	for level in data.levels:
		var n := int(level.index) + 1
		var p := LevelGen.params(int(level.index))
		ok(level.groups.size() == int(p[0]), "level %d has %d groups" % [n, p[0]])
		var fams := {}
		for g in level.groups:
			ok(not fams.has(family[g.id]), "level %d: no two groups from family %s" % [n, family[g.id]])
			fams[family[g.id]] = true
		var b := Board.from_level(level)
		var legal := true
		for m in level.solution:
			var mv := Vector3i(int(m[0]), int(m[1]), int(m[2]))
			legal = legal and b.check(mv) == Board.Check.OK
			b.apply(mv)
		ok(legal and b.is_won(), "level %d: stored solution wins" % n)
		ok(b.moves_left() >= LevelGen.MIN_SPARE, "level %d: budget leaves %d+ spare moves" % [n, LevelGen.MIN_SPARE])

func _test_screen() -> void:
	print("screen")
	ok(Style.title(700) != null and Style.body(800) != null, "fonts load")
	var scene: Node2D = load("res://game/game_scene.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	scene.start_level(0)
	ok(scene.views.size() == 8, "level 1 deals 8 cards")
	var b: Board = scene.board
	var top: int = b.columns[0][-1]
	scene.tap(0)
	ok(scene.board.moves_used == 1, "tapping a card moves it")
	ok(scene.board.slot_cards[0].has(top) or scene.board.columns.any(func(c): return c.has(top)),
		"the tapped card went somewhere legal")
	scene.undo()
	ok(scene.board.moves_used == 0, "undo takes the move back")
	ok(scene.undos_left == 2, "undo is counted")
	# Force a wrong drop: claim slot 0 with one group, then drop another group on it.
	scene.try_move(Vector3i(Board.TO_SLOT, 0, 0))
	var g0: int = scene.board.slot_group[0]
	var wrong_src := -2
	for c in scene.board.columns.size():
		var u: Array = scene.board.unit_at(c)
		if not u.is_empty() and scene.board.card_group[u[0]] != g0:
			wrong_src = c
			break
	if wrong_src != -2:
		var used: int = scene.board.moves_used
		ok(not scene.try_move(Vector3i(Board.TO_SLOT, wrong_src, 0)), "wrong group is refused")
		ok(scene.board.moves_used == used + 1, "and costs a move")
	# Play the stored solution from a fresh start and reach the win screen.
	scene.start_level(0)
	for m in scene.level.solution:
		scene.try_move(Vector3i(int(m[0]), int(m[1]), int(m[2])))
	ok(scene.board.is_won(), "the solution wins through the screen too")
	var waited := 0.0
	while scene._overlay != "win" and waited < 15.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	ok(scene._overlay == "win", "win screen shows after the celebration (%.1fs)" % waited)
	ok(scene._pips_lit == scene.board.group_count(), "every group's star lit up")
	ok(Engine.time_scale == 1.0, "no freeze-frame left running")
	ok(Progress.level == 1, "progress moved to level 2")
	ok(Progress.coins > 0, "coins were earned")
	scene.next_level()
	ok(scene.level_index == 1 and scene._overlay == "", "next level starts clean")
	# Two groups finished back to back make a streak.
	scene.start_level(0)
	for m in scene.level.solution:
		scene.try_move(Vector3i(int(m[0]), int(m[1]), int(m[2])))
		await get_tree().process_frame
	waited = 0.0
	while scene._pips_lit < 2 and waited < 6.0:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
	ok(scene._pips_lit == 2, "both stars lit on level 1")
	# Hints come from the solver.
	scene.start_level(1)
	scene.hint()
	ok(scene.hints_left == 2 and not scene._hint.is_empty(), "hint highlights a move")
	scene.queue_free()

# ---------------------------------------------------------------- Magnet Cascade

## groups: 0 = Sea (cards 0-3), 1 = Farm (4-7), 2 = Music (8-11)
func _cascade(piles: Array, hold := 2, magnets := 0, bombs := 0) -> Cascade:
	return Cascade.from_level({"groups": [
		{"name": "Sea", "cards": ["Crab", "Whale", "Octopus", "Starfish"]},
		{"name": "Farm", "cards": ["Cow", "Pig", "Sheep", "Goat"]},
		{"name": "Music", "cards": ["Harp", "Drum", "Flute", "Violin"]}],
		"piles": piles, "hold": hold, "magnets": magnets, "bombs": bombs})

func _test_cascade_rules() -> void:
	print("cascade rules")
	# Tap Crab: Whale is also face-up, so both jump in. Their piles reveal
	# Octopus and Starfish, which match the tray and jump in too: a chain
	# that bursts Sea in one tap.
	var b := _cascade([[2, 0], [3, 1], [4, 5], [6, 7]])
	ok(b.grab_preview(0).size() == 2, "preview shows both face-up Sea cards")
	var ev := b.tap(0)
	var pulls := ev.filter(func(e): return e.t == "pull")
	ok(pulls.size() == 4, "one tap pulled 4 cards (2 grabbed + 2 chained), got %d" % pulls.size())
	ok(ev.any(func(e): return e.t == "burst" and e.group == 0), "the chain burst Sea")
	ok(b.tray.is_empty(), "burst frees the tray")
	ok(b.piles[0].is_empty() and b.piles[1].is_empty(), "both Sea piles emptied")
	ok(not b.is_won(), "Farm is still on the table")
	ev = b.tap(2)
	ok(b.is_won(), "tapping Farm clears the rest")
	# Reveals of other groups don't jump.
	var b2 := _cascade([[4, 0], [5, 1], [2], [3]])
	b2.tap(0)
	ok(b2.done.has(0), "all four face-up Sea cards burst at once")
	ok(b2.top(0) == 4, "Cow was revealed but stayed put")

func _test_cascade_specials() -> void:
	print("cascade specials and danger")
	# Tray holds 1 group + danger slot. Starting a second group = danger;
	# a third = instant loss.
	var d := _cascade([[0], [4], [5, 1], [8]], 1)
	d.tap(0)
	ok(not d.in_danger() and d.tray_cards[0].size() == 2, "Crab and Whale fill one slot")
	d.tap(1)
	ok(d.in_danger() and not d.is_lost(), "a second group goes in the danger slot")
	d.tap(3)
	ok(d.is_lost(), "a third group overflows: lost")
	# In danger, a tap that bursts a group earns another turn even though it
	# also started a new colour: Harp comes in, Starfish chains under it, Sea bursts.
	# Goat and Violin are locked so their colours can't finish early; Space
	# keeps a card free to tap afterwards.
	var s := Cascade.from_level({"groups": [
		{"name": "Sea", "cards": ["Crab", "Whale", "Octopus", "Starfish"]},
		{"name": "Farm", "cards": ["Cow", "Pig", "Sheep", "Goat"]},
		{"name": "Music", "cards": ["Harp", "Drum", "Flute", "Violin"]},
		{"name": "Space", "cards": ["Moon", "Star", "Comet", "Sun"]}],
		"piles": [[0], [1], [2], [3, 8], [4], [5, 6, 7], [9, 10, 11], [12, 13, 14, 15]],
		"hold": 1, "locks": {"7": 3, "11": 3}})
	s.tap(0)
	s.tap(4)
	ok(s.in_danger() and not s.is_lost(), "Cow starts a second group: danger")
	var sev := s.tap(3)
	ok(sev.any(func(e): return e.t == "burst" and e.group == 0), "Starfish chained and Sea burst")
	ok(not s.is_lost() and s.in_danger(), "a burst in danger earns another turn, even with a new colour in")
	# Magnet: card 12. Hidden under Crab; pulls Whale from deep in pile 1.
	var m := _cascade([[12, 0], [1, 4, 5], [2, 6, 7], [3]], 2, 1)
	var ev := m.tap(0)
	ok(ev.any(func(e): return e.t == "fire" and e.kind == Cascade.Kind.MAGNET), "magnet fired when revealed")
	ok(ev.any(func(e): return e.t == "pull" and e.card == 1 and e.buried), "magnet yanked a buried card")
	# Bomb: card 12 again (bombs only). Knocks the top off every other pile.
	var bb := _cascade([[12], [0, 4], [1, 5], [2, 6], [3, 7]], 2, 0, 1)
	ev = bb.tap(0)
	ok(ev.filter(func(e): return e.t == "blast").size() == 4, "bomb blasted 4 piles")
	ok(bb.need[1] == 0 and bb.done.has(1), "a group the bomb destroyed counts as cleared")
	ev = bb.tap(1)
	ok(bb.is_won(), "the Sea cards left behind finish the level")

func _test_cascade_locks() -> void:
	print("cascade locks")
	# Whale (1) is locked for 1 burst, on top of pile 2. Crab+Octopus+Starfish
	# are face-up; Whale can't be grabbed until something bursts.
	var b := Cascade.from_level({"groups": [
		{"name": "Sea", "cards": ["Crab", "Whale", "Octopus", "Starfish"]},
		{"name": "Farm", "cards": ["Cow", "Pig", "Sheep", "Goat"]}],
		"piles": [[0], [2], [1], [4, 5, 6, 7], [3]], "hold": 2, "locks": {"1": 1}})
	ok(b.grab_preview(2).is_empty(), "a locked card can't be tapped")
	ok(not b.grab_preview(0).has(1), "a locked card isn't grabbed with its group")
	var ev := b.tap(3)
	ok(ev.any(func(e): return e.t == "burst" and e.group == 1), "Farm bursts")
	ok(ev.any(func(e): return e.t == "lock" and e.card == 1 and e.left == 0), "the burst opened Whale's lock")
	ev = b.tap(0)
	ok(b.done.has(0) and b.is_won(), "once open, Whale joins its group and the level is won")

func _test_cascade_wild() -> void:
	print("cascade wild")
	# Sea gets 3 of 4 in the tray; Starfish is buried. Tapping Cow reveals a
	# Wild (card 8), which pulls the buried Starfish and bursts Sea.
	var b := Cascade.from_level({"groups": [
		{"name": "Sea", "cards": ["Crab", "Whale", "Octopus", "Starfish"]},
		{"name": "Farm", "cards": ["Cow", "Pig", "Sheep", "Goat"]}],
		"piles": [[5, 0], [1], [2], [6, 7, 3, 8, 4]], "hold": 2, "wilds": 1})
	b.tap(0)
	ok(b.tray_cards.get(0, []).size() == 3, "three Sea cards in the tray")
	var ev := b.tap(3)
	ok(ev.any(func(e): return e.t == "wild" and e.group == 0), "the wild card picked Sea")
	ok(ev.any(func(e): return e.t == "pull" and e.card == 3), "it pulled the Starfish in")
	ok(b.done.has(0), "Sea burst")
	ev = b.tap(0)
	ok(b.is_won(), "the level can still be finished")

func _test_cascade_levels() -> void:
	print("cascade levels")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cascade_levels.json"))
	ok(data.levels.size() == CascadeGen.LEVEL_COUNT, "all %d levels were built" % CascadeGen.LEVEL_COUNT)
	for level in data.levels:
		var n := int(level.index) + 1
		var b := Cascade.from_level(level)
		for p in b.piles.size():
			var t := b.top(p)
			ok(b.card_kind[t] == Cascade.Kind.CARD, "level %d pile %d: no special starts face-up" % [n, p])
		for p in level.solution:
			b.tap(int(p))
			if b.is_lost():
				break
		ok(b.is_won(), "level %d: stored solution wins" % n)
		ok(float(level.bot.cards_per_tap) >= CascadeGen.MIN_CARDS_PER_TAP, "level %d: taps are juicy" % n)

func _test_cascade_screen() -> void:
	print("cascade screen")
	for key in ["magnet", "bomb", "peek", "lock", "wild", "rare", "ice", "chain", "wrap", "color", "row", "shuffle", "showme_ice", "showme_chain", "showme_wrap"]:
		Progress.seen[key] = true
	var scene: Node2D = load("res://game/cascade_scene.tscn").instantiate()
	scene.show_title = false
	add_child(scene)
	await get_tree().process_frame
	scene.start_level(0)
	var sol: Array = scene.level.solution
	for p in sol:
		var waited := 0.0
		while scene.is_busy() and waited < 8.0:
			await get_tree().create_timer(0.1).timeout
			waited += 0.1
		scene.tap_pile(int(p))
	var waited := 0.0
	while scene._overlay != "win" and waited < 10.0:
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	ok(scene._overlay == "win", "level 1 plays through to the win screen")
	ok(scene._lit.size() == scene.board.group_count(), "every progress segment lit")
	ok(Engine.time_scale == 1.0, "no freeze-frame left running")
	scene.next_level()
	ok(scene._overlay == "title", "Next level goes to the map first")
	await get_tree().create_timer(2.8).timeout
	ok(scene._overlay == "" and scene.level_index == 1, "early levels skip the pre-level panel and just start")
	scene.start_level(1)
	await get_tree().create_timer(0.1).timeout
	var before: int = scene.board.taps
	scene._busy_until = 0.0
	scene.tap_pile(int(scene.level.solution[0]))
	scene.undo()
	ok(scene.board.taps == before and scene.undos_left == 2, "undo restores the board")
	scene.hint()
	ok(scene._hint_pile != -1 and scene.hints_left == 2, "hint picks a pile")
	# Daily puzzle: built from today's date, winnable, same twice in a row.
	scene.start_daily()
	ok(scene._daily and scene.level.has("solution"), "daily puzzle builds")
	var first_layout = str(scene.level.piles)
	var d := Cascade.from_level(scene.level)
	for p in scene.level.solution:
		d.tap(int(p))
	ok(d.is_won(), "daily puzzle's solution wins")
	scene._daily_level = {}
	scene.start_daily()
	ok(str(scene.level.piles) == first_layout, "the same date always gives the same daily puzzle")
	scene._lit = [0, 1, 2]
	scene._win_stars = 2
	ok(scene.share_text().contains("Daily") and scene.share_text().contains("🟥🟦🟩"), "share text has the day and squares")
	# Daily gift: once a day, growing with a streak.
	Progress.gift_day = ""
	Progress.gift_run = 0
	var coins_before := Progress.coins
	ok(Progress.claim_gift() == 20 and Progress.coins == coins_before + 20, "first gift is 20 coins")
	ok(Progress.gift_today().is_empty() and Progress.claim_gift() == 0, "only one gift a day")
	Progress.gift_day = Progress.local_date(-1)
	Progress.gift_run = 6
	ok(Progress.claim_gift() == 150, "day 7 of a streak gives 150")
	# Phone controls: a tap during a chain is queued and plays afterwards.
	scene.start_level(2)
	scene._busy_until = 0.0
	var first := int(scene.level.solution[0])
	scene.tap_pile(first)
	ok(scene.is_busy(), "a chain is playing")
	var second := int(scene.level.solution[1])
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = scene._pile_rect(second).get_center()
	scene._unhandled_input(press)
	ok(scene._queued_pile == second, "a tap during a chain is remembered")
	var guard := 0
	while scene.board.taps < 2 and guard < 600:
		await get_tree().process_frame
		guard += 1
	ok(scene.board.taps == 2, "the remembered tap plays when the chain ends")
	# Sliding a finger off a pile cancels the tap.
	guard = 0
	while scene.is_busy() and guard < 600:
		await get_tree().process_frame
		guard += 1
	var p3: int = scene.board.choices()[0]
	press.position = scene._pile_rect(p3).get_center()
	scene._unhandled_input(press)
	var slide := InputEventMouseMotion.new()
	slide.position = press.position + Vector2(0, 400)
	scene._unhandled_input(slide)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = slide.position
	var taps_before: int = scene.board.taps
	scene._unhandled_input(up)
	ok(scene.board.taps == taps_before, "sliding off the card cancels the tap")
	# Gift: a swipe across the card cuts the ribbon.
	Progress.gift_day = ""
	scene._overlay = "title"
	scene._open_gift()
	scene._overlay_age = 1.0
	var r: Rect2 = scene._gift_card_rect()
	press.position = Vector2(r.position.x - 10, r.get_center().y)
	scene._unhandled_input(press)
	for i in 10:
		var mv := InputEventMouseMotion.new()
		mv.position = Vector2(lerpf(r.position.x - 10, r.end.x + 10, (i + 1) / 10.0), r.get_center().y)
		scene._unhandled_input(mv)
	ok(scene._gift_cut > 0.0, "swiping across the gift card cuts it open")
	# Home: the level map, with Play, Daily and Events underneath.
	scene._go_home()
	await get_tree().process_frame
	ok(scene._home != null and scene._home.visible, "home shows the level map")
	ok(scene._overlay_buttons.size() == 1, "home has one Play button (the rest float at the sides)")
	var locked: Vector2 = scene._home.path_pos(Progress.cascade_level + 1)
	scene._home._tap(locked)
	ok(scene._overlay == "title" and scene._turn_t < 0.0, "a face-down level can't be opened")
	scene._overlay = ""
	scene._show_overlay_buttons()
	ok(not scene._home.visible, "the map hides during a level")
	var hv: HomeView = scene._home
	hv.start_intro(true)
	ok(hv.appear("play") == 0.0 and not hv.intro_done(), "the intro starts with the Play button hidden")
	hv.skip_intro()
	ok(hv.intro_done() and hv.appear("play") == 1.0, "tapping skips the intro")
	hv.focus(mini(Progress.cascade_level, 99))
	ok(hv._back_dir() == 0, "no back arrow while your level is on screen")
	hv.scroll = hv._max_scroll()
	ok(hv._back_dir() == 1, "scrolled far up: the back arrow points down to your level")
	ok(hv._bubbles().size() == 5, "five side bubbles: gift, daily, events, shop, pets")
	# Pre-level panel and boosters.
	scene._overlay = "title"
	var booster_count_before := Progress.booster_count("xray")
	scene.open_prelevel(6)
	ok(scene._overlay == "prelevel" and scene._pre_index == 6, "Play opens the pre-level panel")
	ok(Progress.booster_count("xray") == booster_count_before + 1, "reaching the panel the first time gives one of each booster")
	Progress.coins = 1000
	Progress.boosters["slot"] = 0
	scene._pre_click(scene._pre_tile(0).get_center())
	ok(scene._pre_sel.has("slot") and Progress.coins == 1000 - int(Progress.BOOSTERS.slot.price), "a booster you don't own is bought on the spot")
	scene._pre_click(scene._pre_tile(0).get_center())
	ok(not scene._pre_sel.has("slot") and Progress.booster_count("slot") == 1, "tapping again switches it off (you keep it)")
	scene._close_prelevel()
	scene._overlay = ""
	scene.start_level(3)
	var hold_before: int = scene.board.hold
	scene._apply_boosters({"slot": true, "xray": true, "lucky": true})
	ok(scene.board.hold == hold_before + 1 and scene._xray and scene._lucky, "boosters give a slot, X-ray and lucky coins")
	scene.start_level(3)
	ok(not scene._xray and not scene._lucky, "boosters last one level")
	scene._overlay = "title"
	scene.open_shop()
	ok(scene._overlay == "shop" and scene._shop.visible, "the shop opens from home")
	scene._close_shop()
	scene.open_settings()
	var calm_before: bool = Progress.calm
	scene._settings_click(scene._setting_tile(4).get_center())
	ok(scene._overlay == "settings" and Progress.calm != calm_before, "tapping a settings tile toggles it")
	scene._settings_click(scene._setting_tile(4).get_center())
	ok(Progress.calm == calm_before, "and tapping again switches it back")
	scene.close_overlay()
	ok(scene._overlay == "title", "Settings opened from home goes back home")
	scene._close_shop()
	scene._overlay = ""
	scene._show_overlay_buttons()
	# Win streak: 3 wins gives an extra slot at the next start.
	Progress.win_streak = 3
	scene.start_level(6)
	var base_hold: int = scene.board.hold
	scene._streak_reward()
	ok(scene.board.hold == base_hold + 1 and scene._peeking > 0.0, "a 3-win streak starts with a peek and an extra slot")
	# Losing resets the streak; paying to continue brings it back.
	scene._overlay = ""
	scene.board.lost = true
	scene._show_lose()
	ok(Progress.win_streak == 0, "losing resets the win streak")
	Progress.coins = Economy.CONTINUE_COST
	scene.continue_with_slot()
	ok(not scene.board.lost and scene._overlay == "" and Progress.win_streak == 3, "continuing buys a slot and keeps the streak")
	# Peek costs coins and times out.
	scene.start_level(5)
	scene._busy_until = 0.0
	Progress.coins = Economy.PEEK_COST + 40
	scene.peek()
	ok(Progress.coins == 40 and scene._peeking > 0.0, "peek costs its price and starts")
	scene.tap_pile(int(scene.level.solution[0]))
	ok(scene._peeking == 0.0, "tapping ends a peek")
	# Spending coins on a hint once the free ones are gone.
	scene.start_level(3)
	scene.hints_left = 0
	Progress.coins = Economy.HINT_COST + 10
	scene._busy_until = 0.0
	scene.hint()
	ok(Progress.coins == 10 and scene._hint_pile != -1, "a hint can be bought for its price")
	Progress.coins = 10
	scene._hint_pile = -1
	scene.hints_left = 0
	scene.hint()
	ok(Progress.coins == 10 and scene._hint_pile == -1, "not enough coins: no hint, no charge")
	scene.queue_free()

## Plays every level and today's daily through the real screen at 12x speed,
## watching for the win card each time. Catches screen bugs the rule tests
## can't see.
func _test_play_every_level() -> void:
	print("playing every level through the screen")
	var scene: Node2D = load("res://game/cascade_scene.tscn").instantiate()
	scene.show_title = false
	scene.time_scale_base = 12.0
	for key in ["magnet", "bomb", "peek", "lock", "wild", "rare", "ice", "chain", "wrap", "color", "row", "shuffle", "showme_ice", "showme_chain", "showme_wrap"]:
		Progress.seen[key] = true
	add_child(scene)
	await get_tree().process_frame
	var won := 0
	var total: int = scene.levels.size()
	var played := 0
	for i in total + 1:
		# Levels 101+ repeat the same wave: play every 4th through the screen
		# (every level's solution is still checked by the rules tests).
		if i >= 100 and i < total and i % 4 != 0:
			continue
		played += 1
		if i < total:
			scene.start_level(i)
		else:
			scene.start_daily()
		for p in scene.level.solution:
			var guard := 0
			while scene.is_busy() and scene._overlay == "" and guard < 400:
				await get_tree().process_frame
				guard += 1
			scene.tap_pile(int(p))
		var guard2 := 0
		while scene._overlay != "win" and guard2 < 600:
			await get_tree().process_frame
			guard2 += 1
		if scene._overlay == "win":
			won += 1
		else:
			ok(false, "level %d reached the win card (overlay '%s')" % [i + 1, scene._overlay])
	ok(won == played, "%d levels and the daily played to the win card" % (played - 1))
	# The daily's win card: fold it away, bring it back, then share.
	if scene._overlay == "win":
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = true
		tap.position = Vector2(scene.ox + 8.0, 8.0)
		scene._stars_shown = scene._win_stars
		scene._unhandled_input(tap)
		ok(scene._win_fold, "tapping outside the result card folds it away")
		tap.position = scene._win_tab_rect().get_center()
		scene._unhandled_input(tap)
		ok(not scene._win_fold, "tapping the tab brings the card back")
		await scene.open_share()
		ok(scene._overlay == "share" and scene._share_img != null and scene._share_img.get_width() == 1080,
			"Share makes a 1080-wide picture card")
		ok(scene._share_badge().begins_with("Daily ·"), "the daily's card says which day")
		scene._close_share()
		ok(scene._overlay == "win", "back from Share returns to the result")
	ok(Progress.album.size() >= 30, "playing everything filled the album (%d groups)" % Progress.album.size())
	Engine.time_scale = 1.0
	scene.queue_free()

func _test_playtest_log() -> void:
	print("playtest log")
	Playtest.PATH = "user://playtest_log_test.txt"
	Playtest.clear()
	Playtest.enabled = true
	var scene: Node2D = load("res://game/cascade_scene.tscn").instantiate()
	scene.show_title = false
	add_child(scene)
	await get_tree().process_frame
	scene.start_level(1)
	scene._busy_until = 0.0
	scene.tap_pile(int(scene.level.solution[0]))
	var text := FileAccess.get_file_as_string(Playtest.PATH)
	ok(text.contains("Level 2  start") and text.contains("Level 2  tap 1"), "the log records starts and taps")
	Playtest.clear()
	Playtest.enabled = false
	scene.queue_free()

func _test_meta() -> void:
	print("map gift boxes, weekly event")
	Progress.reset()
	ok(not Progress.gift_box_ready(1), "no gift box before you get there")
	Progress.cascade_level = 5
	Progress.stars = {"cascade_0": 3, "cascade_1": 3, "cascade_2": 1}
	ok(not Progress.gift_box_ready(1), "a gift box needs its stars (7 of 10)")
	Progress.stars["cascade_3"] = 3
	var before := Progress.coins
	ok(Progress.gift_box_ready(1) and Progress.gift_boxes_ready() == [1], "10 stars past level 5 opens the first box")
	ok(Progress.open_gift_box(1) == Progress.gift_box_coins(1) and Progress.coins == before + Progress.gift_box_coins(1),
		"the box pays exactly the coins it shows")
	ok(Progress.open_gift_box(1) == 0 and Progress.gift_box_opened(1), "a box opens once")
	ok(Progress.gift_box_coins(2) == 2 * mini(40 + 20, 150), "the box at a chapter's end is double")
	# 3 stars on a whole chapter pays once.
	Progress.reset()
	for i in 10:
		Progress.stars["cascade_%d" % i] = 3
	Progress.stars["cascade_9"] = 2
	ok(Progress.claim_perfect_chapters().is_empty(), "no chapter bonus with one level at 2 stars")
	Progress.stars["cascade_9"] = 3
	var c0 := Progress.coins
	ok(Progress.claim_perfect_chapters() == [0] and Progress.coins == c0 + Progress.CHAPTER_BONUS, "all 3 stars in chapter I pays the bonus")
	ok(Progress.claim_perfect_chapters().is_empty(), "the chapter bonus pays once")
	# Stamps (achievements).
	Progress.reset()
	Progress.add_stat("cards", 600)
	var c1 := Progress.coins
	var got := Progress.check_stamps()
	ok(got.size() == 1 and Progress.has_stamp("cards", 0) and Progress.coins == c1 + Progress.STAMP_COINS[0],
		"bursting 500 cards earns the bronze Card smasher stamp and its coins")
	ok(Progress.check_stamps().is_empty(), "a stamp is only earned once")
	Progress.max_stat("best_tap", 16)
	ok(Progress.check_stamps().size() == 2, "a 16-card tap earns bronze and silver Chain reaction at once")
	# Coin shop.
	Progress.coins = int(Progress.BOOSTERS.xray.price) + 100
	ok(Progress.buy_booster("xray") and Progress.coins == 100, "buying a booster costs its price")
	ok(not Progress.buy_booster("shield") and Progress.booster_count("shield") == 0, "can't buy what you can't afford")
	ok(Progress.use_booster("xray") and not Progress.use_booster("xray"), "a booster is used once")
	ok(Progress.owns_back("ink") and Progress.card_back == "ink", "the ink card back is free and on")
	Progress.coins = Progress.back_price("tartan") - 1
	ok(not Progress.choose_back("tartan") and Progress.card_back == "ink", "a card back you can't afford stays locked")
	Progress.coins = Progress.back_price("tartan")
	ok(Progress.choose_back("tartan") and Progress.card_back == "tartan" and Progress.coins == 0, "buying a card back puts it on")
	ok(Progress.choose_back("ink") and Progress.choose_back("tartan") and Progress.coins == 0, "switching back is free once owned")
	Progress.reset()
	# Weekly event.
	Progress.week_kind_override = "cards"
	Progress.add_week_cards(45)
	ok(Progress.week_ready() == 30, "40 cards reaches the first prize")
	ok(Progress.claim_week() == 30 and Progress.week_ready() == 0, "the prize is collected once")
	Progress.week_kind_override = "stars"
	var wc := Progress.week_cards
	Progress.add_week("cards", 100)
	ok(Progress.week_cards == wc, "in a stars week, bursting cards doesn't count")
	Progress.add_week("stars", 3)
	ok(Progress.week_cards == wc + 3 and Progress.week_track() == Progress.WEEK_TRACKS.stars, "stars count in a stars week, on its own track")
	Progress.week_kind_override = ""
	Progress.reset()

func _test_album_sets() -> void:
	print("album sets")
	var ids := {}
	for g in LevelGen.load_groups():
		ids[g.id] = true
	for st in Progress.album_sets():
		ok(st.groups.size() == 6, "set %s has 6 groups" % st.id)
		for gid in st.groups:
			ok(ids.has(gid), "set %s: group %s exists" % [st.id, gid])
	var fs := Progress.featured_set()
	ok(int(fs.days_left) >= 1 and int(fs.days_left) <= Progress.SET_DAYS, "the featured set has 1-14 days left (%d)" % fs.days_left)
	Progress.reset()
	var coins_before := Progress.coins
	var gids: Array = fs.set.groups
	ok(Progress.set_burst("not_in_set") == 0 and Progress.set_got.is_empty(), "other groups don't count for the set")
	var paid := 0
	for gid in gids:
		paid += Progress.set_burst(gid)
		paid += Progress.set_burst(gid)
	ok(paid == Progress.SET_REWARD and Progress.coins == coins_before + Progress.SET_REWARD, "finishing the set pays 200 once")
	ok(Progress.set_done and int(Progress.ribbons.get(fs.set.id, 0)) == 1, "finishing the set earns its gold ribbon")
	Progress.set_key = "old_0"
	ok(Progress.set_missing().size() == 6 and not Progress.set_done, "a new set starts empty")
	Progress.reset()

func _test_dress() -> void:
	print("rare cards and featured groups")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cascade_levels.json"))
	var fs := Progress.featured_set()
	var rares := 0
	var featured := 0
	for key in ["autumn_0", "winter_2", "garden_7"]:
		for level in data.levels:
			var i := int(level.index)
			var missing: Array = Progress.album_sets()[i % Progress.album_sets().size()].groups
			var d := Dress.dress(level, i, key, missing)
			if i < Dress.FIRST_LEVEL:
				ok(d == level, "level %d is never dressed" % (i + 1))
				continue
			ok(d.piles == level.piles and d.solution == level.solution, "dressing keeps level %d's deal" % (i + 1))
			ok(d.groups.size() == level.groups.size(), "dressing keeps level %d's group count" % (i + 1))
			var fams := {}
			var labels := {}
			for g in d.groups:
				var f := Dress.family_of(g.id)
				ok(not fams.has(f), "dressed level %d: one group per family (%s)" % [i + 1, f])
				fams[f] = true
				for c in g.cards:
					ok(not labels.has(c), "dressed level %d: card %s is unique" % [i + 1, c])
					labels[c] = true
				rares += 1 if g.get("rare", false) else 0
				featured += 1 if g.id in missing else 0
			for gi in d.groups.size():
				ok(d.groups[gi].cards.size() == level.groups[gi].cards.size(), "dressed level %d: group sizes match" % (i + 1))
			var b := Cascade.from_level(d)
			for p in d.solution:
				b.tap(int(p))
			ok(b.is_won(), "dressed level %d still wins" % (i + 1))
	var n: int = (data.levels.size() - Dress.FIRST_LEVEL) * 3
	ok(rares > n / 20 and rares < n / 4, "rare groups turn up now and then (%d in %d levels)" % [rares, n])
	ok(featured > n / 3, "featured groups turn up often (%d in %d levels)" % [featured, n])
	ok(Dress.dress(data.levels[30], 30, fs.key, []) == Dress.dress(data.levels[30], 30, fs.key, []), "dressing is the same every time")

func _test_goals() -> void:
	print("bonus goals")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cascade_levels.json"))
	var count := 0
	var kinds := {}
	for level in data.levels:
		var i := int(level.index)
		var g := Goals.for_level(level, i)
		if i < Goals.FIRST_LEVEL or level.get("boss", false):
			ok(g.is_empty(), "level %d has no goal" % (i + 1))
		if g.is_empty():
			continue
		count += 1
		kinds[g.kind] = true
		var b := Cascade.from_level(level)
		var best := 0
		var seen_states := []
		for p in level.solution:
			best = maxi(best, Goals.moved(b.tap(int(p))))
			seen_states.append(Goals.status(g, b, best))
		ok(Goals.status(g, b, best) == "met", "level %d: the winning line meets its %s goal" % [i + 1, g.kind])
		ok(not seen_states.has("failed"), "level %d: the winning line never fails its goal" % (i + 1))
	var n_levels: int = data.levels.size()
	ok(count >= n_levels / 5 and count <= n_levels / 2, "about 4 in 10 levels have a goal (%d of %d)" % [count, n_levels])
	ok(kinds.size() == 3, "all three goal kinds are used")
	# A missed goal.
	var lv: Dictionary = data.levels[20]
	var b2 := Cascade.from_level(lv)
	b2.tap(int(lv.solution[0]))
	if not b2.done.is_empty():
		var other := (int(b2.done[0]) + 1) % b2.group_count()
		ok(Goals.status({"kind": "first", "group": other, "n": 0}, b2, 0) == "failed", "bursting another group first misses a First goal")
		ok(Goals.status({"kind": "last", "group": int(b2.done[0]), "n": 0}, b2, 0) == "failed", "bursting the Last group early misses it")
	ok(Goals.status({"kind": "chain", "group": -1, "n": 99}, Cascade.from_level(lv), 5) == "open", "a chain goal stays open until the level ends")

func _test_cascade_obstacles() -> void:
	print("frozen, chained and wrapped cards")
	var groups := [{"name": "Sea", "cards": ["Crab", "Whale", "Octopus", "Starfish"]},
		{"name": "Farm", "cards": ["Cow", "Pig", "Sheep", "Goat"]}]
	# Ice: Whale (1) is frozen on top of pile 2. Any Sea card landing cracks it.
	var b := Cascade.from_level({"groups": groups, "piles": [[0], [2], [1], [3], [4, 5, 6, 7]], "hold": 2,
		"ice": {"1": 1}})
	ok(b.grab_preview(2).is_empty(), "a frozen card can't be tapped")
	ok(not b.grab_preview(0).has(1), "a frozen card isn't grabbed with its colour")
	var ev := b.tap(0)
	ok(ev.any(func(e): return e.t == "ice" and e.card == 1 and e.left == 0), "a Sea card landing thaws the frozen Sea card")
	ok(ev.any(func(e): return e.t == "burst" and e.group == 0), "once thawed it jumps in and Sea bursts, all in one tap")
	b.tap(4)
	ok(b.is_won(), "ice level won")
	# Two layers take two landings.
	b = Cascade.from_level({"groups": groups, "piles": [[0], [2], [1], [3], [4, 5, 6, 7]], "hold": 2, "ice": {"1": 2}})
	ev = b.tap(0)
	var cracks := ev.filter(func(e): return e.t == "ice").size()
	ok(cracks == 2 and b.ice[1] == 0, "two layers crack on two landings")
	# Chain: Whale (1) chained on pile 1; piles in one row, so 0 and 2 are its neighbours.
	b = Cascade.from_level({"groups": groups, "piles": [[5, 6, 7, 4], [1], [0], [2, 3]], "hold": 2, "chains": [1]})
	ok(b.neighbours(1) == [0, 2], "in one row, a pile's neighbours are either side")
	ok(b.grab_preview(1).is_empty() and not b.grab_preview(2).has(1), "a chained card can't be tapped or grabbed")
	ev = b.tap(2)
	ok(ev.any(func(e): return e.t == "unchain" and e.card == 1), "a card leaving the pile next door snaps the chain")
	ok(ev.any(func(e): return e.t == "burst" and e.group == 0), "the freed card joins its colour in the same tap")
	b.tap(0)
	ok(b.is_won(), "chain level won")
	var two_rows := Cascade.from_level({"groups": groups, "piles": [[0], [1], [2], [3], [4], [5], [6], [7]], "hold": 2})
	ok(two_rows.neighbours(1) == [0, 2, 5] and two_rows.neighbours(4) == [0, 5], "in two rows, neighbours include above and below")
	# Wrapped: plays like any card; only the colour is hidden.
	b = Cascade.from_level({"groups": groups, "piles": [[0], [2], [1], [3], [4, 5, 6, 7]], "hold": 2, "wraps": [1]})
	ok(b.wrapped[1] == 1 and b.grab_preview(0).has(1), "a wrapped card is still pulled with its colour")
	b.tap(0)
	b.tap(4)
	ok(b.is_won(), "wrapped level won")
	# Nothing left to tap (every top frozen/chained/locked) counts as a loss.
	b = Cascade.from_level({"groups": groups, "piles": [[4], [1]], "hold": 2, "ice": {"1": 1}})
	b.tap(0)
	ok(b.is_lost() and b.stuck, "a board with nothing tappable is lost (stuck)")
	# The generated levels.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cascade_levels.json"))
	var first := {"ice": -1, "chains": -1, "wraps": -1}
	for level in data.levels:
		for k in first:
			if level.has(k) and first[k] == -1:
				first[k] = int(level.index)
	ok(first.ice == CascadeGen.ICE_FROM, "frozen cards first appear on level %d" % (CascadeGen.ICE_FROM + 1))
	ok(first.chains == CascadeGen.CHAIN_FROM, "chained cards first appear on level %d" % (CascadeGen.CHAIN_FROM + 1))
	ok(first.wraps == CascadeGen.WRAP_FROM, "wrapped cards first appear on level %d" % (CascadeGen.WRAP_FROM + 1))

func _test_cascade_new_specials() -> void:
	print("colour bomb, row and shuffle")
	var groups := [{"name": "Sea", "cards": ["Crab", "Whale", "Octopus", "Starfish"]},
		{"name": "Farm", "cards": ["Cow", "Pig", "Sheep", "Goat"]}]
	# Colour bomb (card 8): Sea and Farm tie at 4 free cards; the lower wins.
	var b := Cascade.from_level({"groups": groups, "piles": [[4, 0, 1, 8], [5, 2], [6, 3], [7]], "hold": 2, "colors": 1})
	ok(b.card_kind[8] == Cascade.Kind.COLOR, "colour bombs are dealt")
	var ev := b.tap(0)
	ok(ev.filter(func(e): return e.t == "blast").size() == 4 and b.need[0] == 0, "the colour bomb blasts every Sea card, buried ones too")
	ok(ev.any(func(e): return e.t == "burst" and e.group == 0), "the cleared colour bursts")
	b.tap(0)
	ok(b.is_won(), "colour bomb level won")
	# Row (card 8) on pile 0: 5 piles sit in rows of 3, so piles 0-2 lose two cards each.
	b = Cascade.from_level({"groups": groups, "piles": [[0, 1, 8], [2, 3], [4, 5], [6], [7]], "hold": 2, "rows": 1})
	ev = b.tap(0)
	ok(ev.filter(func(e): return e.t == "blast").size() == 6 and b.piles[3] == [6] and b.piles[4] == [7],
		"a Row knocks two cards off each pile in its row only")
	b.tap(3)
	ok(b.is_won(), "row level won")
	# Shuffle (card 8): with Sea in the tray, buried Sea cards come to the top and chain in.
	b = Cascade.from_level({"groups": groups, "piles": [[0, 8], [4, 1, 5], [6, 2, 7], [3]], "hold": 2, "shuffles": 1})
	b.tap(3)
	ev = b.tap(0)
	var sh: Array = ev.filter(func(e): return e.t == "shuffle")
	ok(sh.size() == 1 and sh[0].moves.size() == 2, "Shuffle brings a Sea card to the top of two piles")
	ok(ev.any(func(e): return e.t == "burst" and e.group == 0), "and the chain pulls them in: Sea bursts")
	b.tap(1)
	ok(b.is_won(), "shuffle level won")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cascade_levels.json"))
	ok(not data.levels[CascadeGen.COLOR_FROM - 1].has("colors") and data.levels[CascadeGen.COLOR_FROM].has("colors"),
		"colour bombs start on level %d" % (CascadeGen.COLOR_FROM + 1))
	ok(data.levels[CascadeGen.SHUFFLE_FROM].has("shuffles"), "shuffles start on level %d" % (CascadeGen.SHUFFLE_FROM + 1))

func _test_fixes() -> void:
	print("hint, big text, daily by weekday")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cascade_levels.json"))
	# The quick solver finds a winning line on every level with obstacles.
	var found := 0
	for i in range(30, 100, 7):
		var line := Cascade.quick_solve(Cascade.from_level(data.levels[i]), 16, 1)
		if not line.is_empty():
			var b := Cascade.from_level(data.levels[i])
			for p in line:
				b.tap(int(p))
			found += 1 if b.is_won() else 0
	ok(found >= 8, "the quick hint solver wins most obstacle levels (%d of 10)" % found)
	Style.big = true
	ok(Style.caps_width("Extra slot", 10) > Style._caps_width_exact("Extra slot", 10), "Big text makes small labels wider")
	Style.big = false
	# Weekday dailies: Monday easy, Sunday hard, capped by progress.
	var scene: Node2D = load("res://game/cascade_scene.tscn").instantiate()
	scene.show_title = false
	add_child(scene)
	Progress.cascade_level = 99
	ok(scene.daily_index("2026-09-28") == 8 and scene.daily_index("2026-09-27") == 76, "Monday's daily is easy, Sunday's hard")
	Progress.cascade_level = 3
	ok(scene.daily_index("2026-09-27") == 10, "a new player's Sunday daily has nothing they haven't met")
	Progress.cascade_level = 0
	scene.queue_free()

func _test_reports() -> void:
	print("playtest and difficulty reports")
	var log := "\n".join([
		"2026-09-25 10:00:00  --  ---- new session ----",
		"2026-09-25 10:00:01  Level 1  start",
		"2026-09-25 10:00:20  Level 1  WIN taps 4 stars 3 time 19s",
		"2026-09-25 10:00:30  Level 2  start",
		"2026-09-25 10:00:40  Level 2  used hint",
		"2026-09-25 10:00:50  Level 2  LOSE after 6 taps, 3 of 5 groups, time 20s",
		"2026-09-25 10:00:55  Level 2  start",
		"2026-09-25 10:00:56  Level 2  left the app after 1s in this level",
		"2026-09-25 11:00:00  --  ---- new session ----",
		"2026-09-25 11:00:01  Level 2  start",
		"2026-09-25 11:00:30  Level 2  WIN taps 5 stars 2 time 29s",
	])
	var r := PlaytestReport.analyse(log)
	ok(r.sessions == 2, "the report counts sessions")
	ok(int(r.levels["Level 2"].quits) == 1 and int(r.levels["Level 1"].quits) == 0, "a session ending mid-level is a quit; a won level isn't")
	ok(int(r.levels["Level 2"].losses) == 1 and int(r.levels["Level 2"].hints) == 1 and int(r.levels["Level 2"].wins) == 1,
		"wins, losses and hints are counted")
	ok(PlaytestReport.markdown(r).contains("| Level 2 | 3 | 1 | 1 | 1 | 50% |"), "the report table adds up")
	# Every level's measured win rate sits in its planned difficulty band.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cascade_levels.json"))
	for level in data.levels:
		var p := CascadeGen.params(int(level.index))
		var w := 100.0 * float(level.bot.win)
		ok(w >= float(p[5]) and w <= float(p[6]), "level %d: bot win %d%% is inside %d-%d%%" % [int(level.index) + 1, w, p[5], p[6]])

## The ideas from the Sept 26 meeting with Damien: music themes and layers,
## surprises, the days-played streak, stand-in ads, the star league, pets.
func _test_meeting_ideas() -> void:
	print("meeting ideas: music, surprises, streak, ads, league, pets")
	# Music: chapter themes, a boss theme every tenth level, layers that build.
	Audio.music_mood(0)
	ok(Audio.theme in ["ch0", "spooky"] and Audio.layers == 0, "level 1 plays chapter 1's theme, starting thin")
	Audio.music_mood(9)
	ok(Audio.theme == "boss", "level 10 plays the boss theme")
	Audio.music_mood(23)
	ok(Audio.theme in ["ch2", "spooky"], "level 24 plays chapter 3's theme")
	Audio.music_layers(3)
	ok(Audio.layers == 3, "the music can build to full")
	Audio.key_up()
	ok(Audio._key_shift == 2, "a Cascade! lifts the key")
	Audio.music_mood(4)
	ok(Audio._key_shift == 0 and Audio.layers == 0, "a new level starts in the home key, thin again")
	Audio.music_theme("daily")
	ok(Audio.theme == "daily" and Audio.CHORDS.size() == 4, "the daily has its own theme")
	# Surprises: about one level in five from level 10, never changing the rules.
	var n_surprise := 0
	for i in 200:
		if CascadeMain.surprise_for(i, PackedStringArray()) != "":
			n_surprise += 1
	ok(n_surprise >= 35 and n_surprise <= 45, "about 1 level in 5 has a surprise (%d of 200)" % n_surprise)
	ok(CascadeMain.surprise_for(3, PackedStringArray()) == "", "no surprises in the first levels")
	ok(CascadeMain.surprise_for(16, PackedStringArray(["Snow Day"])) == "weather", "a winter level's weather surprise is snow")
	for key in ["magnet", "bomb", "peek", "lock", "wild", "rare", "ice", "chain", "wrap", "color", "row", "shuffle", "showme_ice", "showme_chain", "showme_wrap"]:
		Progress.seen[key] = true
	var scene: Node2D = load("res://game/cascade_scene.tscn").instantiate()
	scene.show_title = false
	scene.time_scale_base = 12.0
	add_child(scene)
	await get_tree().process_frame
	# Golden card (level 22): appears after two bursts, its group pays a bonus, the level still wins.
	scene.start_level(21)
	ok(scene._surprise == "golden", "level 22 has the golden-card surprise")
	await _play_solution(scene)
	ok(scene._overlay == "win", "the golden-card level still wins with its solution")
	ok(scene._golden_card != -1, "the golden card appeared")
	# Rewarded ad on the win card (level 22 is past level 20): doubles the win's coins once.
	ok(Ads.available() == OS.is_debug_build(), "stand-in ads only in test builds")
	Ads.instant = true
	var g3 := 0
	while not scene._can_double() and g3 < 900:
		await get_tree().process_frame
		g3 += 1
	ok(scene._can_double(), "the win card offers x2 coins for an ad")
	var before_ad := Progress.coins
	var win_c: int = scene._win_coins
	scene._watch_double()
	ok(Progress.coins == before_ad + win_c and scene._win_coins == win_c * 2, "the ad doubles the win's coins")
	scene._watch_double()
	ok(Progress.coins == before_ad + win_c, "only once")
	Ads.instant = false
	# Mystery gift (level 27): lands after the 3rd tap; tapping it pays coins and isn't a move.
	scene.start_level(26)
	ok(scene._surprise == "gift", "level 27 has the mystery-gift surprise")
	var sol: Array = scene.level.solution
	for k in 3:
		await _wait_idle(scene)
		scene.tap_pile(int(sol[k]))
	await _wait_idle(scene)
	ok(not scene._gift_token.is_empty(), "the gift lands after the third tap")
	var coins_before := Progress.coins
	var taps_before: int = scene.board.taps
	var gift_coins := int(scene._gift_token.coins)
	scene._claim_gift_token()
	ok(Progress.coins == coins_before + gift_coins and scene.board.taps == taps_before, "the gift pays its coins and isn't a move")
	# Pets: the Owl joins on level 8; its help charges with bursts and costs nothing.
	Progress.pets = {}
	Progress.pet = ""
	scene.start_level(7)
	ok(Progress.pets.has("owl") and Progress.pet == "owl", "the Owl joins on level 8")
	scene.start_level(12)
	var psol: Array = scene.level.solution
	var pk := 0
	while not scene._pet_ready() and pk < psol.size() - 1:
		await _wait_idle(scene)
		scene.tap_pile(int(psol[pk]))
		pk += 1
	await _wait_idle(scene)
	ok(scene._pet_ready(), "the Owl's help charges after %d bursts" % Pets.CHARGE)
	var c0 := Progress.coins
	var h0: int = scene.hints_left
	scene._use_pet()
	ok(scene._hint_pile != -1 and Progress.coins == c0 and scene.hints_left == h0, "the Owl's hint is free and doesn't use a hint")
	ok(not scene._pet_ready() and scene._pet_charge == 0, "using the help empties the charge")
	ok(scene._pet_line in Pets.get_pet("owl").lines.help, "the Owl says a help line (\"%s\")" % scene._pet_line)
	# Buying a pet with coins; every pet has lines for the big moments.
	Progress.coins = 5000
	ok(Progress.buy_pet("cat") and Progress.pet == "cat" and Progress.coins == 5000 - 2500, "a pet costs coins and comes along")
	ok(not Progress.buy_pet("parrot"), "can't buy a pet you can't afford")
	var all_talk := true
	for pet in Pets.LIST:
		for m in ["hello", "cheer", "danger", "win", "lose", "idle"]:
			if Pets.line(pet.id, m, 0) == "":
				all_talk = false
	ok(all_talk, "every pet has something to say at every big moment")
	ok(Pets.is_active("owl") and not Pets.is_active("squirrel"), "Owl helps on a tap; Squirrel is always on")
	Progress.pets = {}
	Progress.pet = ""
	scene.queue_free()
	await get_tree().process_frame
	_test_day_streak()
	_test_league()

## Days-played streak: counting, freezes, vacations, repair, milestones.
func _test_day_streak() -> void:
	var keep_days: Dictionary = Progress.days.duplicate()
	var keep_coins := Progress.coins
	var keep_backs: Dictionary = Progress.backs.duplicate()
	Progress.days = {}
	Progress.frozen = {}
	Progress.freezes = 0
	Progress.vacation_until = ""
	Progress.streak_lost = 0
	Progress.streak_lost_on = ""
	Progress.streak_gap = []
	Progress.streak_paid = {}
	Progress.streak_news = []
	Progress.streak_best = 0
	Progress.coins = 10000
	var d0 := "2026-03-01"
	for i in 5:
		Progress.note_day(Progress.date_add(d0, i))
	ok(Progress.day_streak(Progress.date_add(d0, 4)) == 5, "five days in a row make a 5-day streak")
	ok(Progress.day_streak(Progress.date_add(d0, 5)) == 5, "the streak isn't lost before the day is over")
	# A held freeze covers one missed day automatically.
	ok(Progress.buy_freeze() and Progress.freezes == 1 and Progress.coins == 10000 - Economy.FREEZE_COST, "a freeze costs its price")
	Progress.note_day(Progress.date_add(d0, 6))     # day 5 missed
	ok(Progress.freezes == 0 and Progress.day_streak(Progress.date_add(d0, 6)) == 7, "the freeze covered the missed day")
	ok(Progress.streak_news.has(7) and Progress.coins == 10000 - Economy.FREEZE_COST + 500, "a 7-day streak pays 500 once")
	Progress.streak_news.clear()
	# A vacation covers a week away.
	ok(Progress.buy_vacation(Progress.date_add(d0, 6)), "a vacation can be bought")
	Progress.note_day(Progress.date_add(d0, 12))    # days 7-11 away
	ok(Progress.day_streak(Progress.date_add(d0, 12)) == 13 and Progress.streak_lost == 0, "a vacation keeps the streak through a trip")
	# Missing days with nothing to cover them breaks it; it can be repaired for two days.
	Progress.vacation_until = ""
	Progress.note_day(Progress.date_add(d0, 15))    # days 13-14 missed
	ok(Progress.streak_lost == 13 and Progress.day_streak(Progress.date_add(d0, 15)) == 1, "missing days breaks the streak (13 remembered)")
	ok(Progress.repair_cost() == 200 + 10 * 13, "repair costs 200 + 10 a day")
	ok(Progress.can_repair(Progress.date_add(d0, 16)) and not Progress.can_repair(Progress.date_add(d0, 17)), "repair is open for two days")
	var before := Progress.coins
	Progress.streak_lost_on = Progress.local_date()
	ok(Progress.repair_streak() and Progress.coins == before - 330, "repairing takes its price")
	ok(Progress.day_streak(Progress.date_add(d0, 15)) == 16, "a repaired streak carries on (16 days)")
	ok(Progress.owns_back("ember") == false and not Progress.shop_backs().any(func(b): return b[0] == "ember"), "Ember isn't in the shop until earned")
	Progress.days = keep_days
	Progress.frozen = {}
	Progress.freezes = 0
	Progress.streak_lost = 0
	Progress.streak_news = []
	Progress.streak_paid = {}
	Progress.coins = keep_coins
	Progress.backs = keep_backs

## Star league: levels from stars, a board with friends, medals at week end.
func _test_league() -> void:
	ok(League.player_level(0)[0] == 1 and League.player_level(8)[0] == 2 and League.player_level(7)[0] == 1, "level 2 at 8 stars")
	ok(League.player_level(8 + 11)[0] == 3, "level 3 needs 11 more")
	var me := {"week": 30, "total": 120, "chain": 12, "streak": 5, "best_week": 60}
	var a := League.board("W2026-03-02", me, 0.5)
	var b := League.board("W2026-03-02", me, 0.5)
	ok(str(a) == str(b), "the same week gives the same board")
	ok(a.size() == (9 if League.stand_in() else 1), "stand-in friends only in test builds (%d rows)" % a.size())
	ok(a.any(func(r): return r.you), "you are on the board")
	var early := League.board("W2026-03-02", me, 0.1)
	var late := League.board("W2026-03-02", me, 0.9)
	var sum_e := 0
	var sum_l := 0
	for r in early:
		sum_e += 0 if r.you else int(r.week)
	for r in late:
		sum_l += 0 if r.you else int(r.week)
	ok(sum_l > sum_e, "friends' stars grow through the week")
	# A big week ends in first place: a gold medal and its coins.
	var keep_coins := Progress.coins
	Progress.league_key = "W2026-03-02"
	Progress.league_stars = 5000
	Progress.league_medals = {}
	Progress.league_news = []
	Progress.roll_league("W2026-03-09")
	if League.stand_in():
		ok(int(Progress.league_medals.get("1", 0)) == 1 and Progress.coins == keep_coins + League.MEDAL_COINS[0], "first place pays a gold medal")
	ok(Progress.league_key == "W2026-03-09" and Progress.league_stars == 0, "a new week starts at 0 stars")
	Progress.league_news = []
	Progress.coins = keep_coins

func _wait_idle(scene: Node) -> void:
	var guard := 0
	while scene.is_busy() and scene._overlay == "" and guard < 600:
		await get_tree().process_frame
		guard += 1

func _play_solution(scene: Node) -> void:
	for p in scene.level.solution:
		await _wait_idle(scene)
		scene.tap_pile(int(p))
	var guard := 0
	while scene._overlay != "win" and guard < 900:
		await get_tree().process_frame
		guard += 1
