class_name League
extends RefCounted
## The Star League: stars are the XP.
##
##   player level - from total stars (level n -> n+1 needs 3n + 5 more stars)
##   this week    - stars earned since Monday; the board ranks you with your
##                  friends, and the top three get a medal when the week ends
##   all time     - total stars, best chain, longest days-played streak
##
## Friends come from a provider with one job: friends(week, you) -> a list of
## {name, color, week, total, chain, streak}. Game Center isn't added yet, so
## test builds use STAND-IN friends: made-up first names whose stars grow
## through the week at a pace around yours. Release builds show only you
## (and a note about adding friends) until Game Center is connected; a
## released game must never pass made-up people off as real friends.

const MEDAL_COINS := [300, 200, 100]     ## gold, silver, bronze at the end of a week
const MEDAL_COLORS := [Color("f2b705"), Color("b9c0c8"), Color("c98b4f")]
const STAND_IN_NAMES := ["Maya", "Leo", "Nora", "Sam", "Ivy", "Theo", "Ruby", "Ezra"]

## [level, stars into this level, stars this level needs].
static func player_level(total_stars: int) -> Array:
	var lv := 1
	var left := total_stars
	while left >= 3 * lv + 5:
		left -= 3 * lv + 5
		lv += 1
	return [lv, left, 3 * lv + 5]

## True while friends are made-up stand-ins (test builds, no Game Center yet).
static func stand_in() -> bool:
	return OS.is_debug_build()

## How far through its week a moment is: 0 on Monday morning, 1 at the end.
static func week_fraction(week_key: String, now_unix := -1) -> float:
	if now_unix < 0:
		now_unix = int(Time.get_unix_time_from_system()) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var monday := int(Time.get_unix_time_from_datetime_string(week_key.substr(1) + "T00:00:00"))
	return clampf(float(now_unix - monday) / (7.0 * 86400.0), 0.0, 1.0)

## Your friends for a week. `me` = {week, total, chain, streak, best_week};
## `frac` = how far through the week (1.0 = the final standings).
static func friends(week_key: String, me: Dictionary, frac: float) -> Array:
	if not stand_in():
		return []    # Game Center goes here
	var out := []
	# Their pace is set around your usual week, so the race stays close.
	var pace := maxf(float(me.get("best_week", 0)), 40.0)
	for i in STAND_IN_NAMES.size():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(week_key + STAND_IN_NAMES[i])
		var skill := rng.randf_range(0.45, 1.35)
		# Stars arrive in bursts on the days they play, not in a straight line.
		var w := 0.0
		for day in 7:
			var played := rng.randf() < 0.8
			var part := clampf(frac * 7.0 - day, 0.0, 1.0)
			if played:
				w += pace / 7.0 * skill * rng.randf_range(0.6, 1.5) * part
		var total := int(float(me.get("total", 0)) * rng.randf_range(0.5, 1.6)) + rng.randi_range(5, 60)
		out.append({"name": STAND_IN_NAMES[i], "color": Style.group_color(i * 5 + 2), "week": int(w),
			"total": total, "chain": rng.randi_range(7, 22), "streak": rng.randi_range(1, 45), "you": false})
	return out

## Everyone on a board, best first. `key` = "week", "total", "chain" or "streak".
static func board(week_key: String, me: Dictionary, frac: float, key := "week") -> Array:
	var rows := friends(week_key, me, frac)
	rows.append({"name": "You", "color": Style.ACCENT, "week": int(me.get("week", 0)), "total": int(me.get("total", 0)),
		"chain": int(me.get("chain", 0)), "streak": int(me.get("streak", 0)), "you": true})
	rows.sort_custom(func(a, b): return int(a[key]) > int(b[key]) or (int(a[key]) == int(b[key]) and bool(a.you)))
	return rows

## Your place (1 = first) on a finished week.
static func final_rank(week_key: String, me: Dictionary) -> int:
	var rows := board(week_key, me, 1.0)
	for i in rows.size():
		if bool(rows[i].you):
			return i + 1
	return rows.size()
