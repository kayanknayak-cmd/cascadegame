extends Node
## What the player has done: current level, coins, best stars per level.
## Saved to user://progress.json after every change.

const PATH := "user://progress.json"
## Bump when the save layout changes; load_game() can then upgrade old saves.
const SAVE_VERSION := 3

var level := 0          ## 0-based index of the level to play next (sorting game)
var cascade_level := 0  ## same, for Magnet Cascade
var coins := 0
var stars: Dictionary = {}   ## "level index" -> best stars (1-3)
var daily: Dictionary = {}   ## "YYYY-MM-DD" -> best stars on that day's puzzle
var sound := true
var music := true
var seen_star_tip := false
var seen: Dictionary = {}    ## one-time introductions already shown
var win_streak := 0              ## levels won in a row (a loss resets it)
var week_key := ""               ## which week the weekly event counts for
var week_cards := 0              ## this week's event count (cards, stars, big taps or wins; see week_kind)
var week_claimed := 0            ## prize-track rewards already collected
var large_text := false
var calm := false            ## no screen shake or zoom punches
var album: Dictionary = {}   ## group id -> times burst
var set_key := ""            ## which 2-week album set the progress below is for
var set_got: Dictionary = {} ## featured-set group id -> true (burst during this set)
var set_done := false        ## this set's reward has been paid
var ribbons: Dictionary = {} ## album set id -> times completed (gold ribbon)
var boxes: Dictionary = {}   ## gift boxes on the map already opened: "k" -> true
var intro_day := ""          ## last date the full opening intro played
var boosters: Dictionary = {}  ## booster id -> how many you own
var backs: Dictionary = {}     ## card backs bought: id -> true
var card_back := "ink"         ## the card back in use
var daily_cache: Dictionary = {} ## {key: "date|difficulty", level} so today's daily is built once
var chapters_perfect: Dictionary = {} ## chapter index -> true once its 3-star bonus is paid
var stats: Dictionary = {}     ## lifetime counters: cards, best_tap, jackpots
var days: Dictionary = {}      ## local dates the game was played on
var stamps: Dictionary = {}    ## achievements earned: "family:tier" -> true
var gift_day := ""           ## date of the last daily gift claimed
var gift_run := 0            ## gifts claimed on consecutive days
var haptics := true
var save_enabled := true
## Days-played streak (like Duolingo): play anything once a day. `days` holds
## the days played; these cover the gaps and the extras.
var freezes := 0                 ## streak freezes held (used automatically on a missed day)
var frozen: Dictionary = {}      ## dates covered by a freeze or a vacation
var vacation_until := ""         ## days up to and including this date are covered
var streak_best := 0
var streak_lost := 0             ## a streak that just broke (can be repaired for 2 days)
var streak_lost_on := ""         ## the day it was found broken
var streak_gap: Array = []       ## the missed days a repair would cover
var streak_paid: Dictionary = {} ## milestone days already rewarded ("7", "30", "100")
var streak_news: Array = []      ## milestones reached this launch, for the home screen to celebrate
## Star League (see game/league.gd): stars earned this week, and medals.
var league_key := ""             ## the week league_stars counts for
var league_stars := 0
var league_best := 0             ## most stars in one week
var league_medals: Dictionary = {}  ## "1" gold / "2" silver / "3" bronze -> how many
var league_news: Array = []      ## [rank, coins] from a week that just ended, to celebrate
## Pets (see game/pets.gd): which you have, which is with you, and how many
## cards you've burst together (friendship).
var pets: Dictionary = {}
var pet := ""
var pet_cards: Dictionary = {}

func _ready() -> void:
	load_game()

func reset() -> void:
	level = 0
	cascade_level = 0
	daily = {}
	album = {}
	set_key = ""
	set_got = {}
	set_done = false
	ribbons = {}
	boxes = {}
	boosters = {}
	backs = {}
	card_back = "ink"
	daily_cache = {}
	chapters_perfect = {}
	stats = {}
	days = {}
	stamps = {}
	gift_day = ""
	gift_run = 0
	seen_star_tip = false
	seen = {}
	win_streak = 0
	week_key = ""
	week_cards = 0
	week_claimed = 0
	coins = 0
	stars = {}
	freezes = 0
	frozen = {}
	vacation_until = ""
	streak_best = 0
	streak_lost = 0
	streak_lost_on = ""
	streak_gap = []
	streak_paid = {}
	streak_news = []
	league_key = ""
	league_stars = 0
	league_best = 0
	league_medals = {}
	league_news = []
	pets = {}
	pet = ""
	pet_cards = {}

func finish_level(index: int, earned_stars: int, earned_coins: int) -> void:
	var k := str(index)
	stars[k] = maxi(int(stars.get(k, 0)), earned_stars)
	coins += earned_coins
	level = maxi(level, index + 1)
	save_game()

func finish_cascade(index: int, earned_stars: int, earned_coins: int) -> void:
	var k := "cascade_%d" % index
	stars[k] = maxi(int(stars.get(k, 0)), earned_stars)
	coins += earned_coins
	cascade_level = maxi(cascade_level, index + 1)
	save_game()

func save_game() -> void:
	if not save_enabled:
		return
	var tmp := PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"level": level, "cascade_level": cascade_level, "coins": coins, "stars": stars,
		"sound": sound, "music": music, "haptics": haptics, "daily": daily,
		"seen_star_tip": seen_star_tip, "album": album,
		"gift_day": gift_day, "gift_run": gift_run, "large_text": large_text, "calm": calm, "seen": seen,
		"win_streak": win_streak,
		"week_key": week_key, "week_cards": week_cards, "week_claimed": week_claimed,
		"set_key": set_key, "set_got": set_got, "set_done": set_done, "ribbons": ribbons, "boxes": boxes, "intro_day": intro_day,
		"boosters": boosters, "backs": backs, "card_back": card_back,
		"daily_cache": daily_cache, "chapters_perfect": chapters_perfect,
		"stats": stats, "days": days, "stamps": stamps,
		"freezes": freezes, "frozen": frozen, "vacation_until": vacation_until, "streak_best": streak_best,
		"streak_lost": streak_lost, "streak_lost_on": streak_lost_on, "streak_gap": streak_gap, "streak_paid": streak_paid,
		"league_key": league_key, "league_stars": league_stars, "league_best": league_best, "league_medals": league_medals,
		"pets": pets, "pet": pet, "pet_cards": pet_cards,
		"version": SAVE_VERSION}))
	f.close()
	# Keep the previous good save as a backup before replacing it.
	if FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(PATH), ProjectSettings.globalize_path(PATH + ".bak"))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(PATH))

func load_game() -> void:
	var data = _read_save(PATH)
	if typeof(data) != TYPE_DICTIONARY:
		# Damaged or missing: fall back to the backup copy.
		data = _read_save(PATH + ".bak")
	if typeof(data) != TYPE_DICTIONARY:
		return
	level = int(data.get("level", 0))
	cascade_level = int(data.get("cascade_level", 0))
	coins = int(data.get("coins", 0))
	stars = data.get("stars", {})
	sound = bool(data.get("sound", true))
	daily = data.get("daily", {})
	seen_star_tip = bool(data.get("seen_star_tip", false))
	seen = data.get("seen", {})
	win_streak = int(data.get("win_streak", 0))
	week_key = String(data.get("week_key", ""))
	week_cards = int(data.get("week_cards", 0))
	week_claimed = int(data.get("week_claimed", 0))
	album = data.get("album", {})
	set_key = String(data.get("set_key", ""))
	set_got = data.get("set_got", {})
	set_done = bool(data.get("set_done", false))
	ribbons = data.get("ribbons", {})
	boxes = data.get("boxes", {})
	intro_day = String(data.get("intro_day", ""))
	boosters = data.get("boosters", {})
	backs = data.get("backs", {})
	card_back = String(data.get("card_back", "ink"))
	daily_cache = data.get("daily_cache", {})
	chapters_perfect = data.get("chapters_perfect", {})
	stats = data.get("stats", {})
	days = data.get("days", {})
	stamps = data.get("stamps", {})
	gift_day = String(data.get("gift_day", ""))
	large_text = bool(data.get("large_text", false))
	calm = bool(data.get("calm", false))
	gift_run = int(data.get("gift_run", 0))
	music = bool(data.get("music", true))
	haptics = bool(data.get("haptics", true))
	# Version 3 (Sept 27): the days-played streak. Older saves start with none.
	freezes = int(data.get("freezes", 0))
	frozen = data.get("frozen", {})
	vacation_until = String(data.get("vacation_until", ""))
	streak_best = int(data.get("streak_best", 0))
	streak_lost = int(data.get("streak_lost", 0))
	streak_lost_on = String(data.get("streak_lost_on", ""))
	streak_gap = data.get("streak_gap", [])
	streak_paid = data.get("streak_paid", {})
	league_key = String(data.get("league_key", ""))
	league_stars = int(data.get("league_stars", 0))
	league_best = int(data.get("league_best", 0))
	league_medals = data.get("league_medals", {})
	pets = data.get("pets", {})
	pet = String(data.get("pet", ""))
	pet_cards = data.get("pet_cards", {})

func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func finish_daily(key: String, earned_stars: int, earned_coins: int) -> void:
	daily[key] = maxi(int(daily.get(key, 0)), earned_stars)
	coins += earned_coins
	save_game()

## Days in a row with the daily puzzle solved, counting back from today
## (or from yesterday, if today's isn't done yet, so the streak isn't "lost"
## before the day is over).
func daily_streak() -> int:
	var off := 0 if daily.has(local_date()) else -1
	var n := 0
	while daily.has(local_date(off)):
		n += 1
		off -= 1
	return n

## Records a burst in the album. Returns true the first time a group is collected.
func collect(group_id: String) -> bool:
	var first := not album.has(group_id)
	album[group_id] = int(album.get(group_id, 0)) + 1
	return first

const GIFTS := [20, 30, 40, 50, 60, 80, 150]

## The player's local calendar date, `offset` days from today. (Unix time is
## UTC, so the local time-zone bias is added before turning it into a date;
## otherwise "yesterday" is wrong every evening.)
static func local_date(offset := 0) -> String:
	var bias_s: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) + bias_s + offset * 86400)

## Today's gift if it hasn't been claimed: {day (1-7), coins}, else {}.
func gift_today() -> Dictionary:
	var today := local_date()
	if gift_day == today:
		return {}
	var yesterday := local_date(-1)
	var run := gift_run + 1 if gift_day == yesterday else 1
	var day := ((run - 1) % GIFTS.size()) + 1
	return {"day": day, "coins": GIFTS[day - 1], "run": run}

func claim_gift() -> int:
	var g := gift_today()
	if g.is_empty():
		return 0
	gift_day = local_date()
	gift_run = g.run
	coins += g.coins
	save_game()
	return g.coins

func cascade_stars(index: int) -> int:
	return int(stars.get("cascade_%d" % index, 0))

## Every star earned on any level (best result per level counts).
func total_stars() -> int:
	var n := 0
	for k in stars:
		if String(k).begins_with("cascade_"):
			n += int(stars[k])
	return n

# ---------------------------------------------------------------- weekly event

## Prize track: [cards needed, coins]
const WEEK_TRACK := [[40, 30], [100, 50], [180, 80], [280, 120], [400, 200]]

## The weekly event changes each week, in turn: burst cards, earn stars,
## make big taps (8+ cards), win levels. Each has its own prize track.
const WEEK_KINDS := ["cards", "stars", "big", "wins"]
const WEEK_TRACKS := {
	"cards": WEEK_TRACK,
	"stars": [[6, 30], [15, 50], [26, 80], [40, 120], [60, 200]],
	"big": [[3, 30], [8, 50], [14, 80], [22, 120], [32, 200]],
	"wins": [[3, 30], [7, 50], [12, 80], [18, 120], [26, 200]],
}
var week_kind_override := ""   ## tests only

func week_kind() -> String:
	if week_kind_override != "":
		return week_kind_override
	var weeks := int(floor(_local_days() / 7.0))
	return WEEK_KINDS[posmod(weeks, WEEK_KINDS.size())]

func week_track() -> Array:
	return WEEK_TRACKS[week_kind()]

## Counts toward the weekly event, if this week is about `kind`.
func add_week(kind: String, n: int) -> void:
	_roll_week()
	if kind == week_kind():
		week_cards += n

## "2026-W39": the week (Monday start) in local time.
static func week_id() -> String:
	var d := Time.get_date_dict_from_unix_time(int(Time.get_unix_time_from_system()) +
		int(Time.get_time_zone_from_system().get("bias", 0)) * 60)
	var day := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day})
	var monday: int = day - ((int(d.weekday) + 6) % 7) * 86400
	return "W" + Time.get_date_string_from_unix_time(monday)

func _roll_week() -> void:
	var w := week_id()
	if week_key != w:
		week_key = w
		week_cards = 0
		week_claimed = 0

func add_week_cards(n: int) -> void:
	add_week("cards", n)

## Rewards reached but not yet collected, as a total of coins.
func week_ready() -> int:
	_roll_week()
	var total := 0
	var track := week_track()
	for i in range(week_claimed, track.size()):
		if week_cards >= track[i][0]:
			total += track[i][1]
	return total

func claim_week() -> int:
	var coins_won := week_ready()
	var track := week_track()
	while week_claimed < track.size() and week_cards >= track[week_claimed][0]:
		week_claimed += 1
	coins += coins_won
	save_game()
	return coins_won

# ---------------------------------------------------------------- album sets

const SET_DAYS := 14
const SET_REWARD := 500
## Sets start on Mondays: day 0 is Monday 5 January 2026.
const SET_EPOCH := "2026-01-05"

static var _sets: Array = []

static func album_sets() -> Array:
	if _sets.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/album_sets.json"))
		_sets = data.sets
	return _sets

## Whole local days since SET_EPOCH (can be fractional: `now` is in days).
static func _local_days() -> float:
	var bias_s: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var epoch := Time.get_unix_time_from_datetime_string(SET_EPOCH)
	return (Time.get_unix_time_from_system() + bias_s - epoch) / 86400.0

## The featured set right now: {set, key, days_left (whole days, at least 1)}.
static func featured_set() -> Dictionary:
	var days := _local_days()
	var period := int(floor(days / SET_DAYS))
	var sets := album_sets()
	var s: Dictionary = sets[posmod(period, sets.size())]
	var left := int(ceil((period + 1) * SET_DAYS - days))
	return {"set": s, "key": "%s_%d" % [s.id, period], "days_left": maxi(left, 1)}

func _roll_set() -> void:
	var key: String = featured_set().key
	if set_key != key:
		set_key = key
		set_got = {}
		set_done = false

## Featured groups not burst yet this time round.
func set_missing() -> Array:
	_roll_set()
	var out := []
	for gid in featured_set().set.groups:
		if not set_got.has(gid):
			out.append(gid)
	return out

## Records a burst for the featured set. Returns the coins won if this burst
## completed the set (the reward is paid here), otherwise 0.
func set_burst(group_id: String) -> int:
	_roll_set()
	var fs := featured_set()
	if set_done or not group_id in fs.set.groups:
		return 0
	set_got[group_id] = true
	if not set_missing().is_empty():
		return 0
	set_done = true
	ribbons[fs.set.id] = int(ribbons.get(fs.set.id, 0)) + 1
	coins += SET_REWARD
	return SET_REWARD

# ---------------------------------------------------------------- map gift boxes

## A gift box sits on the map after every GIFT_EVERY levels. Box k (after
## level k * GIFT_EVERY) needs two stars a level on average, and shows its
## coins up front: no surprises, no chance.
const GIFT_EVERY := 5

static func gift_box_need(k: int) -> int:
	return k * GIFT_EVERY * 2

static func gift_box_coins(k: int) -> int:
	var c := mini(40 + 10 * k, 150)
	return c * 2 if k % 2 == 0 else c    # the box at each chapter's end is double

func gift_box_opened(k: int) -> bool:
	return boxes.has(str(k))

func gift_box_ready(k: int) -> bool:
	return not gift_box_opened(k) and cascade_level >= k * GIFT_EVERY and total_stars() >= gift_box_need(k)

## Boxes you could open right now.
func gift_boxes_ready() -> Array:
	var out := []
	for k in range(1, CascadeGen.LEVEL_COUNT / GIFT_EVERY + 1):
		if gift_box_ready(k):
			out.append(k)
	return out

func open_gift_box(k: int) -> int:
	if not gift_box_ready(k):
		return 0
	boxes[str(k)] = true
	var c := gift_box_coins(k)
	coins += c
	save_game()
	return c

# ---------------------------------------------------------------- coin shop

## Boosters, bought with coins. Every one only ever makes a level easier or
## pays more, so no booster can turn a winnable level into a lost one.
##   slot   - one extra tray slot for the level
##   xray   - see the card under every pile's top card, all level long
##   lucky  - double coins for winning the level
##   shield - kept until you lose: your win streak survives that loss
const BOOSTERS := {
	"slot": {"price": 360}, "xray": {"price": 280}, "lucky": {"price": 200}, "shield": {"price": 480},
}

## Card backs: looks only. [id, price] - the first is free.
const CARD_BACKS := [["ink", 0], ["tartan", 2000], ["lacquer", 3000], ["navy", 4000], ["botanical", 5500], ["gilt", 8000]]

func booster_count(id: String) -> int:
	return int(boosters.get(id, 0))

func buy_booster(id: String) -> bool:
	var price: int = BOOSTERS[id].price
	if coins < price:
		return false
	coins -= price
	boosters[id] = booster_count(id) + 1
	save_game()
	return true

func use_booster(id: String) -> bool:
	if booster_count(id) <= 0:
		return false
	boosters[id] = booster_count(id) - 1
	save_game()
	return true

static func back_price(id: String) -> int:
	for b in CARD_BACKS:
		if b[0] == id:
			return int(b[1])
	return 0

## Backs you earn instead of buying (not sold in the shop).
const EARNED_BACKS := {"ember": "A 30-day streak"}

func owns_back(id: String) -> bool:
	if EARNED_BACKS.has(id):
		return backs.has(id)
	return back_price(id) == 0 or backs.has(id)

## The backs shown in the shop's fan: every one for sale, plus earned ones you have.
func shop_backs() -> Array:
	var list: Array = CARD_BACKS.duplicate()
	for id in EARNED_BACKS:
		if backs.has(id):
			list.append([id, 0])
	return list

## Buys the back if needed (and affordable), then puts it on.
func choose_back(id: String) -> bool:
	if not owns_back(id):
		var price := back_price(id)
		if coins < price:
			return false
		coins -= price
		backs[id] = true
	card_back = id
	save_game()
	return true

# ---------------------------------------------------------------- chapter bonus

## 3 stars on all ten levels of a chapter pays a bonus, once.
const CHAPTER_BONUS := 300

func chapter_all_three(ch: int) -> bool:
	for i in range(ch * 10, ch * 10 + 10):
		if cascade_stars(i) < 3:
			return false
	return true

## Chapters just made perfect: pays each one's bonus and returns their indices.
func claim_perfect_chapters() -> Array:
	var out := []
	for ch in range(0, CascadeGen.LEVEL_COUNT / 10):
		if not chapters_perfect.has(str(ch)) and chapter_all_three(ch):
			chapters_perfect[str(ch)] = true
			coins += CHAPTER_BONUS
			out.append(ch)
	if not out.is_empty():
		save_game()
	return out

# ---------------------------------------------------------------- stats and stamps

## Achievements ("stamps"): each family has bronze, silver and gold targets,
## and each stamp pays coins once when it's earned.
const STAMPS := [
	["cards", "Card smasher", [500, 2000, 10000]],
	["tap", "Chain reaction", [10, 15, 20]],
	["jackpots", "Jackpot", [1, 10, 50]],
	["stars3", "Star collector", [10, 50, 150]],
	["bosses", "Boss beater", [3, 10, 20]],
	["days", "Regular", [3, 7, 30]],
	["rare", "Treasure hunter", [1, 2, 4]],
	["sets", "Set collector", [1, 3, 10]],
]
const STAMP_COINS := [50, 100, 200]

func stat(key: String) -> int:
	return int(stats.get(key, 0))

func add_stat(key: String, n: int) -> void:
	stats[key] = stat(key) + n

func max_stat(key: String, v: int) -> void:
	stats[key] = maxi(stat(key), v)

## Remembers that the game was played today (for the "Regular" stamp and
## the days-played streak). The first time each day it also looks back at
## any days missed since last time: a vacation or held freezes cover them
## (automatically); otherwise the streak is broken and can be repaired for
## two days. `today` is for tests.
func note_day(today := "") -> void:
	if today == "":
		today = local_date()
	if days.has(today):
		return
	var last := ""
	for back in range(1, 400):
		var d := date_add(today, -back)
		if days.has(d) or frozen.has(d):
			last = d
			break
	if last != "":
		var before := day_streak(last)
		var missed: Array = []
		var d := date_add(last, 1)
		while d != today:
			missed.append(d)
			d = date_add(d, 1)
		var broken: Array = []
		for m in missed:
			if broken.is_empty() and vacation_until != "" and m <= vacation_until:
				frozen[m] = true
			elif broken.is_empty() and freezes > 0:
				freezes -= 1
				frozen[m] = true
			else:
				broken.append(m)
		if not broken.is_empty() and before >= 2:
			streak_lost = before
			streak_lost_on = today
			streak_gap = broken
	days[today] = true
	var now := day_streak(today)
	streak_best = maxi(streak_best, now)
	for m in Economy.STREAK_REWARDS:
		if now >= int(m) and not streak_paid.has(str(m)):
			streak_paid[str(m)] = true
			coins += int(Economy.STREAK_REWARDS[m])
			streak_news.append(int(m))
			if int(m) == 30:
				backs["ember"] = true
	save_game()

## Days in a row played (or covered by a freeze), counting back from `today`
## (or from yesterday, if today isn't played yet, so it isn't "lost" early).
func day_streak(today := "") -> int:
	if today == "":
		today = local_date()
	var d := today if (days.has(today) or frozen.has(today)) else date_add(today, -1)
	var n := 0
	while days.has(d) or frozen.has(d):
		n += 1
		d = date_add(d, -1)
	return n

## The date `n` days from `date` ("YYYY-MM-DD"), using noon to dodge
## daylight-saving edges.
static func date_add(date: String, n: int) -> String:
	var t := int(Time.get_unix_time_from_datetime_string(date + "T12:00:00"))
	return Time.get_date_string_from_unix_time(t + n * 86400)

# ---------------------------------------------------------------- star league

## You, as the league sees you.
func league_me() -> Dictionary:
	roll_league()
	return {"week": league_stars, "total": total_stars(), "chain": stat("best_tap"),
		"streak": maxi(streak_best, day_streak()), "best_week": league_best}

func add_league_stars(n: int) -> void:
	roll_league()
	league_stars += n
	league_best = maxi(league_best, league_stars)

## A new week: last week's final place pays a medal (top 3, with friends).
## `now_week` is for tests.
func roll_league(now_week := "") -> void:
	if now_week == "":
		now_week = week_id()
	if league_key == now_week:
		return
	if league_key != "" and league_stars > 0:
		var me := {"week": league_stars, "total": total_stars(), "chain": stat("best_tap"),
			"streak": maxi(streak_best, day_streak()), "best_week": league_best}
		if not League.friends(league_key, me, 1.0).is_empty():
			var rank := League.final_rank(league_key, me)
			if rank <= 3:
				league_medals[str(rank)] = int(league_medals.get(str(rank), 0)) + 1
				var pay: int = League.MEDAL_COINS[rank - 1]
				coins += pay
				league_news.append([rank, pay])
	league_key = now_week
	league_stars = 0
	save_game()

# ---------------------------------------------------------------- pets

## Buys a pet with coins (never real money) and brings it along.
func buy_pet(id: String) -> bool:
	var p := Pets.get_pet(id)
	if p.is_empty() or pets.has(id) or coins < int(p.price):
		return false
	coins -= int(p.price)
	pets[id] = true
	pet = id
	save_game()
	return true

func choose_pet(id: String) -> bool:
	if not pets.has(id):
		return false
	pet = id
	save_game()
	return true

## The pet with you (and that you own), or "".
func active_pet() -> String:
	return pet if pets.has(pet) else ""

func buy_freeze() -> bool:
	if freezes >= Economy.FREEZE_MAX or coins < Economy.FREEZE_COST:
		return false
	coins -= Economy.FREEZE_COST
	freezes += 1
	save_game()
	return true

## Pauses the streak for the next VACATION_DAYS days (bought before a trip).
func buy_vacation(today := "") -> bool:
	if today == "":
		today = local_date()
	if coins < Economy.VACATION_COST or on_vacation(today):
		return false
	coins -= Economy.VACATION_COST
	vacation_until = date_add(today, Economy.VACATION_DAYS)
	save_game()
	return true

func on_vacation(today := "") -> bool:
	if today == "":
		today = local_date()
	return vacation_until != "" and today <= vacation_until

## A broken streak can be brought back for two days.
func can_repair(today := "") -> bool:
	if today == "":
		today = local_date()
	return streak_lost > 0 and streak_lost_on != "" and today <= date_add(streak_lost_on, 1)

func repair_cost() -> int:
	return mini(Economy.REPAIR_BASE + Economy.REPAIR_PER_DAY * streak_lost, Economy.REPAIR_MAX)

## Pays (unless `free`, e.g. after an ad) and fills the missed days back in.
func repair_streak(free := false) -> bool:
	if not can_repair():
		return false
	if not free:
		if coins < repair_cost():
			return false
		coins -= repair_cost()
	for d in streak_gap:
		frozen[d] = true
	streak_lost = 0
	streak_lost_on = ""
	streak_gap = []
	streak_best = maxi(streak_best, day_streak())
	save_game()
	return true

## How far along a stamp family is.
func stamp_value(family: String) -> int:
	match family:
		"cards":
			return stat("cards")
		"tap":
			return stat("best_tap")
		"jackpots":
			return stat("jackpots")
		"stars3":
			var n := 0
			for k in stars:
				if String(k).begins_with("cascade_") and int(stars[k]) >= 3:
					n += 1
			return n
		"bosses":
			var n := 0
			for k in stars:
				if String(k).begins_with("cascade_") and (int(String(k).substr(8)) + 1) % 10 == 0:
					n += 1
			return n
		"days":
			return days.size()
		"rare":
			var n := 0
			for g in LevelGen.load_rare():
				n += 1 if album.has(g.id) else 0
			return n
		"sets":
			var n := 0
			for k in ribbons:
				n += int(ribbons[k])
			return n
	return 0

func has_stamp(family: String, tier: int) -> bool:
	return stamps.has("%s:%d" % [family, tier])

## Newly earned stamps: pays each one and returns [[name, tier, coins]...].
func check_stamps() -> Array:
	var out := []
	for st in STAMPS:
		var v := stamp_value(st[0])
		for tier in 3:
			if not has_stamp(st[0], tier) and v >= int(st[2][tier]):
				stamps["%s:%d" % [st[0], tier]] = true
				coins += STAMP_COINS[tier]
				out.append([st[1], tier, STAMP_COINS[tier]])
	if not out.is_empty():
		save_game()
	return out
