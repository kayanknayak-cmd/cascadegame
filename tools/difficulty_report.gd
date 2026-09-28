extends SceneTree
## Plays every level many times with the fair bot (it only sees face-up
## cards, like a person) and checks the difficulty curve:
##   - each level's win rate sits inside its target band from the ramp
##   - no sudden cliff: a non-boss level whose win rate drops from the level
##     before by CLIFF points more than the ramp's own wave plans is flagged
##   godot --headless --path . -s res://tools/difficulty_report.gd -- [--out report.md] [--runs 200]

const CLIFF := 20.0   ## points harder than the ramp's planned change

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := ""
	var runs := 200
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
		if args[i] == "--runs" and i + 1 < args.size():
			runs = int(args[i + 1])
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cascade_levels.json"))
	var md := "# Difficulty report\n\nFair bot, %d plays per level. Band = the target win rate from the ramp.\n\n" % runs
	md += "| Level | Win | Band | Taps | Cards/tap | Big chains | New things | Flag |\n|---|---|---|---|---|---|---|---|\n"
	var flags := 0
	var prev := -1.0
	var prev_mid := 0.0
	for level in data.levels:
		var i := int(level.index)
		var p := CascadeGen.params(i)
		var st := CascadeGen.bot_stats(level, runs, int(level.seed) + 99)
		var win := 100.0 * float(st.win)
		var lo := float(p[5])
		var hi := float(p[6])
		var flag := ""
		# A few points of slack: the band was hit with 60 plays, this uses more.
		if win < lo - 10.0 or win > hi + 10.0:
			flag = "outside band"
		elif prev >= 0.0 and not level.get("boss", false) and prev - win > 15.0 \
				and (prev - win) - maxf(prev_mid - (lo + hi) * 0.5, 0.0) > CLIFF:
			# Harder than the planned wave says it should be.
			flag = "cliff (-%d)" % roundi(prev - win)
		if flag != "":
			flags += 1
		var things := []
		for k in ["locks", "ice", "chains", "wraps"]:
			if level.has(k) and not level[k].is_empty():
				things.append("%s %d" % [k, level[k].size()])
		for k in ["colors", "rows", "shuffles"]:
			if int(level.get(k, 0)) > 0:
				things.append(k)
		md += "| %d%s | %d%% | %d-%d%% | %.1f | %.1f | %d%% | %s | %s |\n" % [i + 1, " (boss)" if level.get("boss", false) else "",
			roundi(win), lo, hi, st.taps, st.cards_per_tap, roundi(100.0 * float(st.big_rate)), ", ".join(things), flag]
		prev = win
		prev_mid = (lo + hi) * 0.5
	md += "\n%d level(s) flagged.\n" % flags
	print(md)
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(md)
		f.close()
	quit(0)
