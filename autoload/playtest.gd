extends Node
## Playtest log: one line per notable moment, appended to
## user://playtest_log.txt, so after a tester plays you can see exactly where
## they won, lost, hinted, undid, or stopped. Plain text, nothing sent anywhere.
##   2026-09-24 19:02:11  L3  start
##   2026-09-24 19:02:40  L3  tap 4 moved 6 bursts 1
##   2026-09-24 19:03:05  L3  win taps 5 stars 3 time 54s

var PATH := "user://playtest_log.txt"   ## tests point this elsewhere
var enabled := true
var _level_start_ms := 0

func log_line(level_name: String, what: String) -> void:
	if not enabled:
		return
	var f := FileAccess.open(PATH, FileAccess.READ_WRITE) if FileAccess.file_exists(PATH) else FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	var when := Time.get_datetime_string_from_system(false, true)
	f.store_line("%s  %s  %s" % [when, level_name, what])
	f.close()

func level_started(level_name: String) -> void:
	_level_start_ms = Time.get_ticks_msec()
	log_line(level_name, "start")

func seconds_in_level() -> int:
	return int((Time.get_ticks_msec() - _level_start_ms) / 1000)

func session_break() -> void:
	log_line("--", "---- new session ----")

func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

func line_count() -> int:
	if not FileAccess.file_exists(PATH):
		return 0
	return FileAccess.get_file_as_string(PATH).count("\n")
