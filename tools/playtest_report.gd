extends SceneTree
## Turns a playtest log into a Markdown report: where players quit, win
## rates, time to win, help used.
##   godot --headless --path . -s res://tools/playtest_report.gd -- [log path] [--out report.md]
## With no log path it reads this computer's user://playtest_log.txt. A
## tester's log from a phone can be copied anywhere and passed in.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var src := "user://playtest_log.txt"
	var out := ""
	var i := 0
	while i < args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
			i += 2
			continue
		src = args[i]
		i += 1
	if not FileAccess.file_exists(src):
		printerr("no log at %s" % src)
		quit(1)
		return
	var md := PlaytestReport.markdown(PlaytestReport.analyse(FileAccess.get_file_as_string(src)))
	print(md)
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(md)
		f.close()
		print("wrote %s" % out)
	quit(0)
