class_name Economy
extends RefCounted
## Every coin reward and in-level price, in one place. Balanced with
## tools/economy_report.gd (Sept 25, 2026): the drip during play is small,
## the big moments (wins, jackpots, gifts) stay big, and the shop costs a few
## levels (boosters) to a few days (card backs) of play. Shop prices and
## milestone rewards live in autoload/progress.gd.

const BURST_COINS := 2         ## a group bursting pays BURST_COINS * (1 + nth burst of the tap)
const PRAISE_COINS := 2        ## per praise tier on a big tap
const STREAK_COINS := 2        ## per step of a burst streak
const GOAL_BONUS := 50         ## coins for a level's bonus goal
const RARE_BONUS := 100        ## extra coins for bursting a rare group
const ALBUM_REWARD_EVERY := 5    ## every this many new groups: a coin reward
const ALBUM_REWARD := 100
const PEEK_COST := 160
const HINT_COST := 200           ## coins, once the free hints are used
const UNDO_COST := 120
const CONTINUE_COST := 240       ## lose screen: one more tray slot
const JACKPOT_BONUS := 25
const JACKPOT_REPEAT := 10       ## second and later jackpots in the same level
const SPARE_COINS := 5           ## end-of-level bonus: coins per spare tap
## Days-played streak: everything costs coins, prices shown plainly.
const FREEZE_COST := 300         ## covers one missed day, used automatically
const FREEZE_MAX := 2            ## how many freezes you can hold
const VACATION_COST := 1500      ## pauses the streak for the next VACATION_DAYS days
const VACATION_DAYS := 7
const REPAIR_BASE := 200         ## bring a broken streak back (within 2 days):
const REPAIR_PER_DAY := 10       ##   REPAIR_BASE + REPAIR_PER_DAY per streak day...
const REPAIR_MAX := 2000         ##   ...never more than this
const STREAK_REWARDS := {7: 500, 30: 1500, 100: 3000}   ## coins at these streaks (30 also unlocks the Ember back)
const AD_FROM_LEVEL := 19        ## rewarded-ad offers start at level 20 (0-based index)
const AD_REPAIR_MAX := 6         ## an ad can repair a streak of at most this many days
const GOLDEN_BONUS := 40         ## surprise: the golden card's group pays this when it bursts
const GIFT_MIN := 30             ## surprise: the mystery gift holds this many coins...
const GIFT_MAX := 60             ## ...up to this many
