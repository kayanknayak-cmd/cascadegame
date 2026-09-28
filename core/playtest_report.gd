class_name PlaytestReport
extends RefCounted
## Reads playtest logs (see autoload/playtest.gd) and works out, per level:
## how often it was started, won and lost, how often a player **quit** there
## (their session ended while that level was unfinished), how long wins took,
## and how much help (hints, undos, boosters) they used.
##
## A "session" runs from one "---- new session ----" line to the next. A
## window losing focus on a computer is logged as "left the app", so that on
## its own is not a quit; only a session ending mid-level is.

## Returns {levels: {name: stats}, sessions: n, furthest: [level numbers]}.
static func analyse(text: String) -> Dictionary:
	var levels := {}
	var sessions := 0
	var furthest: Array = []
	var current := ""          ## level being played, "" once it's won
	var best_in_session := 0
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty():
			continue
		# "2026-09-24 19:02:11  Level 3  start"
		var parts := line.split("  ", false)
		if parts.size() < 3:
			continue
		var name := String(parts[1])
		var what := "  ".join(parts.slice(2))
		if name == "--":
			if sessions > 0:
				_end_session(levels, current)
				furthest.append(best_in_session)
			sessions += 1
			current = ""
			best_in_session = 0
			continue
		if sessions == 0:
			sessions = 1
		var st: Dictionary = levels.get(name, {"starts": 0, "wins": 0, "losses": 0, "quits": 0, "win_secs": [],
			"hints": 0, "undos": 0, "boosters": 0, "taps": 0})
		levels[name] = st
		if what == "start":
			st.starts += 1
			current = name
			if name.begins_with("Level "):
				best_in_session = maxi(best_in_session, int(name.substr(6)))
		elif what.begins_with("WIN"):
			st.wins += 1
			var t := what.find("time ")
			if t != -1:
				st.win_secs.append(int(what.substr(t + 5).to_int()))
			current = ""
		elif what.begins_with("LOSE"):
			st.losses += 1
		elif what.begins_with("tap "):
			st.taps += 1
		elif what == "used hint":
			st.hints += 1
		elif what == "used undo":
			st.undos += 1
		elif what.begins_with("boosters:"):
			st.boosters += 1
	if sessions > 0:
		_end_session(levels, current)
		furthest.append(best_in_session)
	return {"levels": levels, "sessions": sessions, "furthest": furthest}

static func _end_session(levels: Dictionary, current: String) -> void:
	if current != "" and levels.has(current):
		levels[current].quits += 1

## The report as Markdown: a table in level order, with the worst quit spots
## called out at the top.
static func markdown(result: Dictionary) -> String:
	var levels: Dictionary = result.levels
	var names: Array = levels.keys()
	names.sort_custom(func(a, b): return _order(a) < _order(b))
	var out := "# Playtest report\n\n"
	out += "%d sessions. Furthest level reached per session: %s\n\n" % [result.sessions,
		", ".join(result.furthest.map(func(x): return str(x)))]
	var worst: Array = names.filter(func(n): return int(levels[n].quits) > 0)
	worst.sort_custom(func(a, b): return int(levels[a].quits) > int(levels[b].quits))
	if not worst.is_empty():
		out += "**Where players quit most:** %s\n\n" % ", ".join(worst.slice(0, 5).map(
			func(n): return "%s (%d)" % [n, int(levels[n].quits)]))
	out += "| Level | Starts | Wins | Losses | Quits | Win rate | Avg win time | Hints | Undos | Boosters |\n"
	out += "|---|---|---|---|---|---|---|---|---|---|\n"
	for n in names:
		var st: Dictionary = levels[n]
		var tries := int(st.wins) + int(st.losses)
		var rate := "-" if tries == 0 else "%d%%" % roundi(100.0 * st.wins / tries)
		var secs: Array = st.win_secs
		var avg := "-" if secs.is_empty() else "%ds" % roundi(secs.reduce(func(a, b): return a + b, 0) / float(secs.size()))
		out += "| %s | %d | %d | %d | %d | %s | %s | %d | %d | %d |\n" % [n, st.starts, st.wins, st.losses, st.quits, rate, avg,
			st.hints, st.undos, st.boosters]
	return out

static func _order(name: String) -> int:
	if name.begins_with("Level "):
		return int(name.substr(6))
	return 100000
