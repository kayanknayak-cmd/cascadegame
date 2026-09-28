class_name Pets
extends RefCounted
## Pets: a companion that sits by the tray, cheers, talks in short lines and
## helps. A SKELETON for now: each pet is a coloured printed square with its
## initial until Damien draws it (a drawing at art/pets/<id>.png replaces the
## square, like the card art). Balance is a first guess.
##
## Coins only: a pet is never sold for real money (looks might be, later).
##
##   active pets  - their help charges up as you burst groups (CHARGE bursts);
##                  tap the pet when it's ready. Free, and it doesn't cost a
##                  booster: Owl = a hint, Cat = a peek, Dog = an undo,
##                  Fox = shows the taps that won't overfill the tray.
##   passive pets - always on: Squirrel +50% coins on a win, Hedgehog keeps
##                  your win streak through one loss a level, Parrot doubles
##                  the praise coins on big taps.
##   friendship   - cards burst with a pet raise it to level 2 and 3 (its help
##                  charges one burst sooner at level 3). Playing is the only way.

const FREE_FROM_LEVEL := 7          ## 0-based: the Owl joins you on level 8
const CHARGE := 3                   ## bursts to charge an active pet's help
const FRIENDSHIP := [0, 1000, 5000] ## cards burst together for levels 1, 2, 3

const LIST := [
	{"id": "owl", "name": "Owl", "color": Color("8a6d4b"), "price": 0, "help": "hint",
		"what": "Points at a good tap",
		"lines": {
			"hello": ["Hoo. Let's think.", "Ready when you are.", "Patience wins."],
			"ready": ["Hoo! Ready.", "Ask me.", "I see a way."],
			"help": ["That one.", "Trust me: here.", "Hoo, look."],
			"cheer": ["Most wise!", "Hoo hoo!", "Well planned."],
			"danger": ["Careful now.", "Hmm. Tight.", "Think first."],
			"win": ["As expected.", "Wisely done.", "Hoo-ray."],
			"lose": ["We learn.", "Again, wiser.", "Next time."],
			"idle": ["Hoo?", "Take your time.", "Still here."],
			"golden": ["Ooh, shiny.", "Gold! Hoo!", "Look there."],
			"first": ["Hoo! I'll help."],
			"tap_me": ["Tap me!"],
		}},
	{"id": "cat", "name": "Cat", "color": Color("e08a3c"), "price": 2500, "help": "peek",
		"what": "Peeks under the cards",
		"lines": {
			"hello": ["…hi.", "Fine. Let's go.", "I'll watch."],
			"ready": ["I could peek.", "Tap me. Or don't.", "Ready, I guess."],
			"help": ["Peek. You're welcome.", "Saw it. Meh.", "There. Happy?"],
			"cheer": ["…okay, nice.", "Not bad.", "Purr. Fine."],
			"danger": ["Uh oh.", "Hiss.", "Watch it."],
			"win": ["Obviously.", "I knew.", "Naptime."],
			"lose": ["Whatever.", "Didn't care.", "…again?"],
			"idle": ["*yawn*", "Zzz.", "Still going?"],
			"golden": ["Shiny. Mine.", "Gold? Want.", "Ooh."],
		}},
	{"id": "dog", "name": "Dog", "color": Color("b7793f"), "price": 3000, "help": "undo",
		"what": "Fetches your last tap back",
		"lines": {
			"hello": ["Let's play!", "Hi hi hi!", "Best day!"],
			"ready": ["Fetch? Fetch!", "I'm ready!", "Throw it!"],
			"help": ["Got it back!", "Fetched!", "Here you go!"],
			"cheer": ["WOW!", "Again! Again!", "Good job!"],
			"danger": ["Uh oh!", "Eek!", "Hold on!"],
			"win": ["We won!!", "Best friend!", "Yay yay!"],
			"lose": ["It's okay!", "Again?", "Still love you!"],
			"idle": ["Play?", "Ball?", "*wag wag*"],
			"golden": ["Shiny!!", "Treasure!", "Ooh ooh!"],
		}},
	{"id": "fox", "name": "Fox", "color": Color("d0562b"), "price": 3500, "help": "safe",
		"what": "Shows the safe taps",
		"lines": {
			"hello": ["Let's be clever.", "I've a plan.", "Watch this."],
			"ready": ["Psst. Ready.", "Want a trick?", "Tap me."],
			"help": ["These are safe.", "Not those.", "Sneaky, eh?"],
			"cheer": ["Clever you!", "Sly move.", "Ha! Nice."],
			"danger": ["Tricky spot.", "Careful…", "Hmm."],
			"win": ["Outfoxed it.", "Too easy.", "Ha!"],
			"lose": ["Next time.", "A setback.", "Hmph."],
			"idle": ["Scheming…", "Hmm?", "Your move."],
			"golden": ["Gold, eh?", "Ooh, loot.", "Mine now."],
		}},
	{"id": "squirrel", "name": "Squirrel", "color": Color("9c5a2e"), "price": 4000, "help": "coins",
		"what": "+50% coins when you win",
		"lines": {
			"hello": ["Coins? Coins!", "Let's gather.", "Busy busy!"],
			"cheer": ["Stash it!", "More coins!", "Yes yes!"],
			"danger": ["Eep!", "Hide!", "Uh oh!"],
			"win": ["Stash time!", "Coins galore!", "Mine mine!"],
			"lose": ["Saved some.", "Eep.", "Next!"],
			"idle": ["Nibble…", "Counting…", "Hmm?"],
			"golden": ["GOLD!", "Shiny nut!", "Stash it!"],
		}},
	{"id": "hedgehog", "name": "Hedgehog", "color": Color("7d6a5a"), "price": 4500, "help": "shield",
		"what": "Keeps your streak once",
		"lines": {
			"hello": ["Oh! Hi.", "I'll keep you safe.", "Hello…"],
			"cheer": ["Oh wow!", "Brave!", "Yay…!"],
			"danger": ["Eek…", "Curl up!", "Scary…"],
			"win": ["We did it…", "Phew!", "Yay!"],
			"lose": ["I've got you.", "Streak's safe.", "It's okay."],
			"idle": ["…", "Snuffle.", "Hi?"],
			"golden": ["Pretty…", "Oh!", "Shiny…"],
		}},
	{"id": "parrot", "name": "Parrot", "color": Color("2e9e5b"), "price": 6000, "help": "praise",
		"what": "Doubles praise coins",
		"lines": {
			"hello": ["SQUAWK! Hi!", "Let's party!", "Hello hello!"],
			"cheer": ["AMAZING!", "Squawk! Wow!", "Pretty bird!"],
			"danger": ["Mayday!", "Squawk?!", "Yikes!"],
			"win": ["Party time!", "Bravo! Bravo!", "SQUAWK!"],
			"lose": ["Awk. Again!", "Oops! Oops!", "Try again!"],
			"idle": ["Hello?", "Squawk?", "Pretty bird."],
			"golden": ["Shiny! Shiny!", "Gold! Awk!", "Treasure!"],
		}},
]

static func get_pet(id: String) -> Dictionary:
	for p in LIST:
		if p.id == id:
			return p
	return {}

## Active pets have a help you tap; passive ones are always on.
static func is_active(id: String) -> bool:
	return String(get_pet(id).get("help", "")) in ["hint", "peek", "undo", "safe"]

static func friendship(cards: int) -> int:
	var lv := 1
	for i in FRIENDSHIP.size():
		if cards >= int(FRIENDSHIP[i]):
			lv = i + 1
	return lv

static func charge_needed(cards: int) -> int:
	return CHARGE - (1 if friendship(cards) >= 3 else 0)

## A line for a moment, or "" if the pet has nothing to say then.
static func line(id: String, moment: String, rng_val: int) -> String:
	var lines: Dictionary = get_pet(id).get("lines", {})
	var list: Array = lines.get(moment, [])
	if list.is_empty():
		return ""
	return String(list[posmod(rng_val, list.size())])

## The pet's picture: Damien's drawing if there is one, else a coloured
## printed square with its initial. `r` is the square; `a` fades it.
static func draw(ci: CanvasItem, id: String, r: Rect2, a := 1.0, owned := true) -> void:
	var p := get_pet(id)
	if p.is_empty():
		return
	# Not yet yours: its colour, faded into the paper.
	var col: Color = p.color if owned else Style.PAPER_DEEP.lerp(p.color, 0.35)
	ci.draw_rect(Rect2(r.position + Vector2(4, 4), r.size), Color(Style.INK, 0.9 * a))
	var art := Style.art("res://art/pets/%s.png" % id)
	if art and owned:
		ci.draw_rect(r, Color(Style.CARD, a))
		ci.draw_texture_rect(art, r.grow(-4), false, Color(1, 1, 1, a))
	else:
		ci.draw_rect(r, Color(col, a))
		ci.draw_rect(r.grow(-5), Color(Style.CARD, 0.25 * a), false, 2.0)
		var ink := Style.on_color(col) if owned else Color(Style.CARD, 0.9)
		Style.text(ci, Style.serif(800, 144), String(p.name).substr(0, 1), r.get_center() + Vector2(0, -r.size.y * 0.06),
			int(r.size.y * 0.52), Color(ink, a), 0, Style.INK, false, 0.0, true)
	ci.draw_rect(r, Color(Style.INK, a), false, 2.5)
