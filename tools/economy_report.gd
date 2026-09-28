extends SceneTree
## Simulates one casual player through every level and adds up the coins
## they'd earn, source by source, to compare with what the shop costs.
##   godot --headless --path . -s res://tools/economy_report.gd -- [--out report.md] [--per-day 8]
##
## The player is the fair bot (it only sees face-up cards), retrying each
## level until it wins. Coin rules are copied from the game (keep in sync):
## bursts, praise, burst streaks, jackpots, win coins, spare-tap bonus, goals,
## rare groups, album rewards, map gift cards, the daily gift, album sets and
## stamps. Boosters and continues are not bought (this is income only).

const PRAISE := [6, 8, 10, 13, 16]
## The save-data script, for its prices and reward tables (autoloads aren't
## running in a command-line tool).
const P := preload("res://autoload/progress.gd")
const PER_DAY_DEFAULT := 8.0

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := ""
	var per_day := PER_DAY_DEFAULT
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out = args[i + 1]
		if args[i] == "--per-day" and i + 1 < args.size():
			per_day = float(args[i + 1])
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cascade_levels.json"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var src := {"bursts": 0, "praise": 0, "streaks": 0, "jackpots": 0, "wins": 0, "spare": 0, "goals": 0, "rare": 0,
		"album": 0, "gift_cards": 0, "daily_gift": 0, "sets": 0, "stamps": 0}
	var attempts_total := 0
	var stars_total := 0
	var groups_seen := {}
	var rows := []
	var block := {"coins": 0, "attempts": 0}
	var total_coins := 0
	var cards_total := 0
	var three_star := 0
	var checkpoints := {}
	for level in data.levels:
		var idx := int(level.index)
		var par: int = level.solution.size()
		var goal := Goals.for_level(level, idx)
		var won := false
		var attempts := 0
		var level_coins := 0
		while not won:
			attempts += 1
			var b := Cascade.from_level(level)
			var streak := 0
			var jackpots := 0
			var best := 0
			var force := attempts >= 6   # a real player would use hints/boosters by now
			var line: Array = Cascade.quick_solve(b, 12, idx) if force else []
			var step := 0
			while not b.is_won() and not b.is_lost():
				var p: int = int(line[step]) if force and step < line.size() else Cascade.fair_pick(b, rng)
				step += 1
				if p == -1:
					break
				var ev := b.tap(p)
				var moved := Goals.moved(ev)
				best = maxi(best, moved)
				var n_burst := 0
				for e in ev:
					if e.t == "burst":
						src.bursts += Economy.BURST_COINS * (1 + n_burst)
						level_coins += Economy.BURST_COINS * (1 + n_burst)
						cards_total += e.cards.size()
						n_burst += 1
						var gid: String = level.groups[e.group].id
						if not groups_seen.has(gid):
							groups_seen[gid] = true
							if groups_seen.size() % Economy.ALBUM_REWARD_EVERY == 0:
								src.album += Economy.ALBUM_REWARD
								level_coins += Economy.ALBUM_REWARD
				var tier := -1
				for i in PRAISE.size():
					if moved >= PRAISE[i] or n_burst >= i + 2:
						tier = i
				if tier >= 0:
					src.praise += Economy.PRAISE_COINS * (tier + 1)
					level_coins += Economy.PRAISE_COINS * (tier + 1)
				if n_burst > 0:
					streak += 1
					if streak >= 2:
						src.streaks += Economy.STREAK_COINS * streak
						level_coins += Economy.STREAK_COINS * streak
				else:
					streak = 0
				if moved >= 10:
					var pay: int = Economy.JACKPOT_BONUS if jackpots == 0 else Economy.JACKPOT_REPEAT
					jackpots += 1
					src.jackpots += pay
					level_coins += pay
			if b.is_won():
				won = true
				var stars := 3 if b.taps <= par + 1 else (2 if b.taps <= par + 3 else 1)
				var wc := 20 + 10 * stars + (25 if b.taps <= par else 0)
				if level.get("boss", false):
					wc *= 2
				src.wins += wc
				level_coins += wc
				var spare := mini(par + 3 - b.taps, 8)
				if spare > 0:
					src.spare += spare * Economy.SPARE_COINS
					level_coins += spare * Economy.SPARE_COINS
				if not goal.is_empty() and Goals.status(goal, b, best) == "met":
					src.goals += Economy.GOAL_BONUS
					level_coins += Economy.GOAL_BONUS
				stars_total += stars
				three_star += 1 if stars == 3 else 0
		# Rare groups turn up in about 1 level in 8 (from level 6).
		if idx >= Dress.FIRST_LEVEL and rng.randf() < Dress.RARE_CHANCE:
			src.rare += Economy.RARE_BONUS
			level_coins += Economy.RARE_BONUS
		# Map gift cards every 5 levels, if the stars are there.
		if (idx + 1) % P.GIFT_EVERY == 0:
			var k := (idx + 1) / P.GIFT_EVERY
			if stars_total >= P.gift_box_need(k):
				src.gift_cards += P.gift_box_coins(k)
				level_coins += P.gift_box_coins(k)
		attempts_total += attempts
		total_coins += level_coins
		block.coins += level_coins
		block.attempts += attempts
		if (idx + 1) % 10 == 0:
			rows.append([idx + 1, block.attempts, block.coins, total_coins, attempts_total / per_day])
			block = {"coins": 0, "attempts": 0}
		if (idx + 1) in [10, 25, 50, 100, 150, 200]:
			checkpoints[idx + 1] = {"coins": total_coins, "days": attempts_total / per_day}
	# Time-based income over the days all that play takes.
	var days := attempts_total / per_day
	src.daily_gift = int(days / 7.0 * 430.0)
	src.sets = int(days / 14.0) * P.SET_REWARD
	# Stamps reachable in this run.
	var stamp_coins := 0
	var vals := {"cards": cards_total, "tap": 16, "jackpots": src.jackpots / 30, "stars3": three_star,
		"bosses": data.levels.size() / 10, "days": int(days), "rare": 4, "sets": int(days / 14.0)}
	for st in P.STAMPS:
		for tier in 3:
			if int(vals.get(st[0], 0)) >= int(st[2][tier]):
				stamp_coins += P.STAMP_COINS[tier]
	src.stamps = stamp_coins
	var grand := 0
	for k in src:
		grand += int(src[k])
	var md := "# Economy report\n\n"
	md += "One simulated casual player (the fair bot) plays all %d levels, retrying until each is won (after 5 losses it plays like someone using hints). About %d attempts a day.\n\n" % [data.levels.size(), int(per_day)]
	md += "**%d attempts in all, about %d days of play. Total coins earned: %s** (about %d a day, %d per attempt).\n\n" % [attempts_total, int(days), _n(grand), grand / maxf(days, 1.0), grand / maxi(attempts_total, 1)]
	md += "## Where the coins come from\n\n| Source | Coins | Share |\n|---|---|---|\n"
	var keys: Array = src.keys()
	keys.sort_custom(func(a, b): return int(src[a]) > int(src[b]))
	for k in keys:
		md += "| %s | %s | %d%% |\n" % [k.replace("_", " "), _n(int(src[k])), roundi(100.0 * src[k] / maxf(grand, 1))]
	md += "\n## What that buys\n\n"
	var per_day_coins := grand / maxf(days, 1.0)
	md += "| Item | Price | Days of coins |\n|---|---|---|\n"
	for id in P.BOOSTERS:
		md += "| %s booster | %d | %.1f |\n" % [id, P.BOOSTERS[id].price, P.BOOSTERS[id].price / maxf(per_day_coins, 1.0)]
	for bk in P.CARD_BACKS:
		if int(bk[1]) > 0:
			md += "| %s card back | %d | %.1f |\n" % [bk[0], bk[1], bk[1] / maxf(per_day_coins, 1.0)]
	for extra in [["Undo (after the free ones)", Economy.UNDO_COST], ["Peek", Economy.PEEK_COST], ["Hint (after the free ones)", Economy.HINT_COST], ["+1 slot (first)", Economy.CONTINUE_COST]]:
		md += "| %s | %d | %.1f |\n" % [extra[0], extra[1], float(extra[1]) / maxf(per_day_coins, 1.0)]
	md += "\n## By level (in-level play only; daily gift, sets and stamps come on top)\n\n| Levels | Attempts | Coins | Running total | Day |\n|---|---|---|---|---|\n"
	for r in rows:
		md += "| %d-%d | %d | %s | %s | %.0f |\n" % [r[0] - 9, r[0], r[1], _n(r[2]), _n(r[3]), r[4]]
	print(md)
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(md)
		f.close()
	quit(0)

static func _n(v: int) -> String:
	var s := str(absi(v))
	var o := ""
	while s.length() > 3:
		o = "," + s.substr(s.length() - 3) + o
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + o
