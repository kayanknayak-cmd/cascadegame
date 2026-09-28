class_name Cascade
extends RefCounted
## The rules of Magnet Cascade. No drawing, no input.
##
##   piles - stacks of cards. Only the top card of each pile is face-up.
##   tap   - tap a pile's top card. Every face-up card of the same group jumps
##           into the tray (the magnet).
##   reveal- a card leaving a pile turns over the one beneath it. If that card's
##           group is already in the tray, it jumps in too, which reveals
##           another card, and so on (the chain).
##   burst - once every card of a group is in the tray, the group bursts and
##           frees its tray slot.
##   tray  - holds `hold` groups, plus one red danger slot. Ending a tap with
##           the danger slot filled gives you one last tap to burst something
##           (a tap that bursts a group earns another turn, even if a new
##           colour also comes in);
##           fail and you lose. Overflowing past the danger slot loses at once.
##           Bursts mid-chain are what save you, which is the point.
##   specials, hidden face-down, fire the moment they're revealed (or tapped):
##     MAGNET - pulls one card of every group in the tray from anywhere, even
##              buried deep in a pile
##     BOMB   - knocks the top card off every other pile
##     WILD   - finishes the tray group closest to bursting: every one of its
##              remaining (unlocked) cards flies in from wherever it is
##              (with an empty tray it just clears itself away)
##     COLOR  - colour bomb: blasts every free card of the colour with the
##              most cards left on the table, buried ones too (no tray slot
##              needed); a colour cleared that way, or completed with what's
##              already in the tray, bursts
##     ROW    - knocks the top two cards off every pile in its row
##     SHUFFLE- stirs the top three cards of every pile: a card of a tray
##              colour (or, with an empty tray, the commonest colour up there)
##              comes to the top, and the chain carries on from there
##   locks - a locked card shows a number. It can't be tapped or pulled.
##           Every burst counts all locks down by one; at zero the card opens,
##           and if its group is already in the tray it jumps straight in.
##   ice   - a frozen card (1-2 layers) can't be tapped or pulled. Every card
##           of its own colour that lands in the tray cracks a layer; thawed
##           on top of its pile, it jumps in if its colour is in the tray.
##   chain - a chained card can't be tapped or pulled until a card leaves a
##           pile right next to it (same row beside it, or straight above or
##           below). Then the chain snaps, and it can join the chain.
##   wrap  - a wrapped card is a mystery: it plays like any other card, but
##           its colour stays hidden until it lands in the tray. (Rules-wise
##           nothing changes; only what the player and the fair bot can see.)
##
## tap() returns every event in the order it happened, so the screen can play
## the chain back one beat at a time.

enum Kind { CARD, MAGNET, BOMB, WILD, COLOR, ROW, SHUFFLE }

var card_group := PackedInt32Array()   ## -1 for specials
var card_kind := PackedInt32Array()
var card_label := PackedStringArray()
var lock := PackedInt32Array()        ## per card: bursts still needed to open (0 = open)
var ice := PackedInt32Array()         ## per card: ice layers left (0 = not frozen)
var chain := PackedInt32Array()       ## per card: 1 while chained
var wrapped := PackedByteArray()      ## per card: 1 = colour hidden until it's pulled
var group_names := PackedStringArray()
var hold := 3
var piles: Array = []           ## Array of Array[int], bottom -> top
var tray: Array = []            ## groups in slot order
var tray_cards: Dictionary = {} ## group -> Array[int]
var need := PackedInt32Array()  ## per group: cards still in play (bombs can destroy some)
var done: Array = []            ## finished groups, in order
var taps := 0
var lost := false
var stuck := false              ## lost because nothing on top can be tapped

# ---------------------------------------------------------------- building

## level = { groups: [{name, cards: [label...]}], piles: [[card idx...]],
##           magnets: n, bombs: n, hold: n }
## Cards are numbered in group order, then the specials.
static func from_level(level: Dictionary) -> Cascade:
	var b := Cascade.new()
	for gi in level.groups.size():
		var g: Dictionary = level.groups[gi]
		b.group_names.append(String(g.name))
		b.need.append(g.cards.size())
		for label in g.cards:
			b.card_group.append(gi)
			b.card_kind.append(Kind.CARD)
			b.card_label.append(String(label))
	for i in int(level.get("magnets", 0)):
		b.card_group.append(-1)
		b.card_kind.append(Kind.MAGNET)
		b.card_label.append("Magnet")
	for i in int(level.get("bombs", 0)):
		b.card_group.append(-1)
		b.card_kind.append(Kind.BOMB)
		b.card_label.append("Bomb")
	for i in int(level.get("wilds", 0)):
		b.card_group.append(-1)
		b.card_kind.append(Kind.WILD)
		b.card_label.append("Wild")
	for spec in [["colors", Kind.COLOR, "Colour bomb"], ["rows", Kind.ROW, "Row"], ["shuffles", Kind.SHUFFLE, "Shuffle"]]:
		for i in int(level.get(spec[0], 0)):
			b.card_group.append(-1)
			b.card_kind.append(spec[1])
			b.card_label.append(spec[2])
	for pile in level.piles:
		var p: Array = []
		for idx in pile:
			p.append(int(idx))
		b.piles.append(p)
	var n := b.card_label.size()
	b.lock.resize(n)
	b.lock.fill(0)
	for key in level.get("locks", {}):
		b.lock[int(key)] = int(level.locks[key])
	b.ice.resize(n)
	b.ice.fill(0)
	for key in level.get("ice", {}):
		b.ice[int(key)] = int(level.ice[key])
	b.chain.resize(n)
	b.chain.fill(0)
	for c in level.get("chains", []):
		b.chain[int(c)] = 1
	b.wrapped.resize(n)
	b.wrapped.fill(0)
	for c in level.get("wraps", []):
		b.wrapped[int(c)] = 1
	b.hold = int(level.get("hold", 3))
	return b

func clone() -> Cascade:
	var b := Cascade.new()
	b.card_group = card_group
	b.card_kind = card_kind
	b.card_label = card_label
	b.lock = lock.duplicate()
	b.ice = ice.duplicate()
	b.chain = chain.duplicate()
	b.wrapped = wrapped
	b.group_names = group_names
	b.hold = hold
	b.piles = piles.duplicate(true)
	b.tray = tray.duplicate()
	b.tray_cards = tray_cards.duplicate(true)
	b.need = need.duplicate()
	b.done = done.duplicate()
	b.taps = taps
	b.lost = lost
	b.stuck = stuck
	return b

# ---------------------------------------------------------------- questions

func group_count() -> int:
	return group_names.size()

func is_won() -> bool:
	return tray.is_empty() and piles.all(func(p): return p.is_empty())

func is_lost() -> bool:
	return lost

func in_danger() -> bool:
	return tray.size() > hold and not lost

func top(p: int) -> int:
	return -1 if piles[p].is_empty() else piles[p][-1]

## Held in place by a lock, ice or a chain.
func blocked(c: int) -> bool:
	return lock[c] > 0 or ice[c] > 0 or chain[c] > 0

## Piles touching pile p on screen: beside it in the same row, or directly
## above or below. (Piles sit in one row of up to 4, or two rows.)
func neighbours(p: int) -> Array:
	var n := piles.size()
	var per_row := n if n <= 4 else ceili(n / 2.0)
	var row := p / per_row
	var col := p % per_row
	var out := []
	for d in [-1, 1]:
		var c2: int = col + d
		if c2 >= 0 and c2 < per_row and row * per_row + c2 < n:
			out.append(row * per_row + c2)
		var r2: int = row + d
		if r2 >= 0 and r2 * per_row + col < n and r2 * per_row < n:
			out.append(r2 * per_row + col)
	return out

## Piles whose top card a tap would act on, one per distinct choice (tapping
## any face-up card of a group does the same thing).
func choices() -> Array[int]:
	var out: Array[int] = []
	var seen := {}
	for p in piles.size():
		var c := top(p)
		if c == -1 or blocked(c):
			continue
		var k := card_group[c] if card_kind[c] == Kind.CARD else -10 - p
		if not seen.has(k):
			seen[k] = true
			out.append(p)
	return out

## Face-up cards a tap on pile p would grab straight away (for the preview).
func grab_preview(p: int) -> Array:
	var c := top(p)
	if c == -1 or blocked(c):
		return []
	if card_kind[c] != Kind.CARD:
		return [c]
	var out: Array = []
	for q in piles.size():
		var t := top(q)
		if t != -1 and not blocked(t) and card_kind[t] == Kind.CARD and card_group[t] == card_group[c]:
			out.append(t)
	return out

## Would starting this group need a tray slot we don't have?
func would_crowd(p: int) -> bool:
	var c := top(p)
	return c != -1 and card_kind[c] == Kind.CARD and not tray_cards.has(card_group[c]) and tray.size() >= hold

# ---------------------------------------------------------------- the chain

var _events: Array = []
var _step := 0
var _queue: Array = []

func tap(p: int) -> Array:
	_events = []
	_step = 0
	var c := top(p)
	if c == -1 or blocked(c):
		return []
	taps += 1
	var was_danger := in_danger()
	_queue = []
	var queue := _queue
	if card_kind[c] != Kind.CARD:
		queue.append(["fire", p])
	else:
		var g := card_group[c]
		for q in piles.size():
			var t := top(q)
			if t != -1 and not blocked(t) and card_kind[t] == Kind.CARD and card_group[t] == g:
				queue.append(["pull", q, g])
	while not queue.is_empty():
		var item: Array = queue.pop_front()
		var q: int = item[1]
		if piles[q].is_empty():
			continue
		var t: int = piles[q][-1]
		match item[0]:
			"pull":
				if blocked(t) or card_kind[t] != Kind.CARD or card_group[t] != item[2]:
					continue
				piles[q].pop_back()
				_add_to_tray(t, q, false)
				_after_leaving(q, queue)
			"reveal":
				if blocked(t):
					continue
				if card_kind[t] != Kind.CARD:
					queue.append(["fire", q])
				elif tray_cards.has(card_group[t]):
					queue.append(["pull", q, card_group[t]])
			"fire":
				if card_kind[t] == Kind.CARD:
					continue
				piles[q].pop_back()
				_events.append({"t": "fire", "card": t, "pile": q, "kind": card_kind[t]})
				match card_kind[t]:
					Kind.MAGNET:
						_magnet(queue)
					Kind.WILD:
						_wild(t, queue)
					Kind.COLOR:
						_color_bomb(t, queue)
					Kind.ROW:
						_row(q, queue)
					Kind.SHUFFLE:
						_shuffle_tops(queue)
					_:
						_bomb(q, queue)
				_after_leaving(q, queue)
		_check_bursts()
	# In danger, a tap that bursts a group earns another turn, even if a new
	# colour also came in; only a tap that bursts nothing (or overflows) loses.
	var burst := _events.any(func(e): return e.t == "burst")
	lost = tray.size() > hold + 1 or (was_danger and tray.size() > hold and not burst)
	# Every top card locked, frozen or chained: nothing left to tap.
	if not lost and not is_won() and choices().is_empty():
		lost = true
		stuck = true
	return _events

func _add_to_tray(c: int, from_pile: int, buried: bool) -> void:
	var g := card_group[c]
	if not tray_cards.has(g):
		tray_cards[g] = []
		tray.append(g)
	tray_cards[g].append(c)
	_events.append({"t": "pull", "card": c, "pile": from_pile, "group": g, "step": _step,
		"slot": tray.find(g), "buried": buried})
	_step += 1
	_crack_ice(g)
	_check_bursts()

## A card of colour g just landed: every frozen card of that colour loses a
## layer of ice. One that thaws on top of its pile gets looked at again.
func _crack_ice(g: int) -> void:
	for q in piles.size():
		var pile: Array = piles[q]
		for i in pile.size():
			var x: int = pile[i]
			if ice[x] > 0 and card_group[x] == g:
				ice[x] -= 1
				_events.append({"t": "ice", "card": x, "pile": q, "left": ice[x]})
				if ice[x] == 0 and i == pile.size() - 1 and not blocked(x):
					_queue.append(["reveal", q])

func _after_leaving(q: int, queue: Array) -> void:
	if not piles[q].is_empty():
		_events.append({"t": "reveal", "pile": q, "card": piles[q][-1]})
		queue.append(["reveal", q])
	# A card leaving snaps the chains on the tops of the piles beside it.
	for nb in neighbours(q):
		var t := top(nb)
		if t != -1 and chain[t] > 0:
			chain[t] = 0
			_events.append({"t": "unchain", "card": t, "pile": nb})
			if not blocked(t):
				queue.append(["reveal", nb])

func _check_bursts() -> void:
	# A group a bomb destroyed completely counts as cleared.
	for g in need.size():
		if need[g] == 0 and not tray_cards.has(g) and not done.has(g):
			_events.append({"t": "burst", "group": g, "cards": [], "slot": -1})
			done.append(g)
	var i := 0
	while i < tray.size():
		var g: int = tray[i]
		if tray_cards[g].size() >= need[g]:
			_events.append({"t": "burst", "group": g, "cards": tray_cards[g].duplicate(), "slot": i})
			done.append(g)
			tray.remove_at(i)
			tray_cards.erase(g)
			_count_locks_down()
		else:
			i += 1

## Every burst ticks every lock still on the table down by one. A card that
## opens on top of its pile gets looked at again, so it can join the chain.
func _count_locks_down() -> void:
	for q in piles.size():
		var pile: Array = piles[q]
		for i in pile.size():
			var c: int = pile[i]
			if lock[c] > 0:
				lock[c] -= 1
				_events.append({"t": "lock", "card": c, "pile": q, "left": lock[c]})
				if lock[c] == 0 and i == pile.size() - 1:
					_queue.append(["reveal", q])

## One card of every tray group, from wherever it's hiding. With an empty
## tray it grabs two cards of whatever group sits nearest the top.
func _magnet(queue: Array) -> void:
	var groups: Array = tray.duplicate()
	if groups.is_empty():
		var best := _shallowest_any()
		if best != -1:
			groups = [best, best]
	for g in groups:
		var found := _shallowest(g)
		if found == Vector2i(-1, -1):
			continue
		var pile: Array = piles[found.x]
		var was_top := found.y == pile.size() - 1
		var c: int = pile[found.y]
		pile.remove_at(found.y)
		_add_to_tray(c, found.x, not was_top)
		if was_top:
			_after_leaving(found.x, queue)

## The wild card finishes the group nearest to done by pulling all its
## remaining unlocked cards from anywhere, buried or not.
func _wild(c: int, queue: Array) -> void:
	var best := -1
	var best_left := 999
	for g in tray:
		var left: int = need[g] - tray_cards[g].size()
		if left < best_left:
			best_left = left
			best = g
	_events.append({"t": "wild", "card": c, "group": best})
	if best == -1:
		return
	for q in piles.size():
		var pile: Array = piles[q]
		var i := pile.size() - 1
		var took_top := false
		while i >= 0:
			var x: int = pile[i]
			if card_kind[x] == Kind.CARD and card_group[x] == best and not blocked(x) and tray_cards.has(best):
				var was_top := i == pile.size() - 1
				pile.remove_at(i)
				_add_to_tray(x, q, not was_top)
				took_top = took_top or was_top
			i -= 1
		if took_top:
			_after_leaving(q, queue)

func _bomb(own: int, queue: Array) -> void:
	for q in piles.size():
		if q == own or piles[q].is_empty():
			continue
		var c: int = piles[q].pop_back()
		_events.append({"t": "blast", "card": c, "pile": q})
		if card_kind[c] == Kind.CARD:
			need[card_group[c]] -= 1
		_after_leaving(q, queue)

## Colour bomb: the colour with the most free cards still in the piles loses
## all of them, top or buried.
func _color_bomb(c: int, queue: Array) -> void:
	var counts := {}
	for pile in piles:
		for x in pile:
			if card_kind[x] == Kind.CARD and not blocked(x) and not done.has(card_group[x]):
				counts[card_group[x]] = int(counts.get(card_group[x], 0)) + 1
	var best := -1
	for g in counts:
		if best == -1 or counts[g] > counts[best] or (counts[g] == counts[best] and g < best):
			best = g
	_events.append({"t": "color", "card": c, "group": best})
	if best == -1:
		return
	for q in piles.size():
		var pile: Array = piles[q]
		var took_top := false
		var i := pile.size() - 1
		while i >= 0:
			var x: int = pile[i]
			if card_kind[x] == Kind.CARD and card_group[x] == best and not blocked(x):
				took_top = took_top or i == pile.size() - 1
				pile.remove_at(i)
				need[best] -= 1
				_events.append({"t": "blast", "card": x, "pile": q})
			i -= 1
		if took_top:
			_after_leaving(q, queue)
	_check_bursts()

## Row: the top two cards of every pile in this pile's row are knocked off.
func _row(own: int, queue: Array) -> void:
	var n := piles.size()
	var per_row := n if n <= 4 else ceili(n / 2.0)
	var row := own / per_row
	for q in range(row * per_row, mini((row + 1) * per_row, n)):
		var knocked := false
		for k in 2:
			if piles[q].is_empty():
				break
			var c: int = piles[q].pop_back()
			knocked = true
			_events.append({"t": "blast", "card": c, "pile": q})
			if card_kind[c] == Kind.CARD:
				need[card_group[c]] -= 1
		if knocked:
			_after_leaving(q, queue)
	_check_bursts()

## Shuffle: in every pile, a free card of a wanted colour among the top three
## is moved to the top (wanted = the tray's colours, or with an empty tray
## the colour most common in those top layers). Then each changed pile is
## looked at again, so the chain can carry on.
func _shuffle_tops(queue: Array) -> void:
	var wanted := {}
	for g in tray:
		wanted[g] = true
	if wanted.is_empty():
		var counts := {}
		for pile in piles:
			for i in range(maxi(pile.size() - 3, 0), pile.size()):
				var x: int = pile[i]
				if card_kind[x] == Kind.CARD and not blocked(x):
					counts[card_group[x]] = int(counts.get(card_group[x], 0)) + 1
		var best := -1
		for g in counts:
			if best == -1 or counts[g] > counts[best] or (counts[g] == counts[best] and g < best):
				best = g
		if best != -1:
			wanted[best] = true
	var moves := []
	for q in piles.size():
		var pile: Array = piles[q]
		if pile.size() < 2:
			continue
		var t: int = pile[-1]
		if card_kind[t] == Kind.CARD and wanted.has(card_group[t]) and not blocked(t):
			continue
		for i in range(pile.size() - 2, maxi(pile.size() - 4, -1), -1):
			var x: int = pile[i]
			if card_kind[x] == Kind.CARD and wanted.has(card_group[x]) and not blocked(x):
				pile.remove_at(i)
				pile.append(x)
				moves.append([q, x])
				break
	_events.append({"t": "shuffle", "moves": moves})
	for m in moves:
		queue.append(["reveal", m[0]])

## (pile, index) of the card of group g closest to the top of any pile.
func _shallowest(g: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_depth := 999
	for q in piles.size():
		var pile: Array = piles[q]
		for i in range(pile.size() - 1, -1, -1):
			var c: int = pile[i]
			if card_kind[c] == Kind.CARD and card_group[c] == g and not blocked(c):
				var depth := pile.size() - 1 - i
				if depth < best_depth:
					best_depth = depth
					best = Vector2i(q, i)
				break
	return best

func _shallowest_any() -> int:
	for depth in 20:
		for q in piles.size():
			var pile: Array = piles[q]
			if pile.size() > depth:
				var c: int = pile[pile.size() - 1 - depth]
				if card_kind[c] == Kind.CARD:
					return card_group[c]
	return -1

# ---------------------------------------------------------------- solving

func key() -> String:
	var p := PackedInt32Array()
	for pile in piles:
		p.append_array(PackedInt32Array(pile))
		p.append(-1)
	for g in tray:
		p.append(g)
		p.append(tray_cards[g].size())
	p.append(-2)
	p.append_array(need)
	p.append_array(lock)
	p.append_array(ice)
	p.append_array(chain)
	return p.to_byte_array().hex_encode()

## A fast way to find a winning line: a player who peeks at hidden cards and
## looks one tap ahead plays from here a few times; the shortest win found is
## returned, or [] if none of the runs won. Much quicker than solve() on busy
## boards, but it can miss a win that exists (then use solve()).
static func quick_solve(start: Cascade, runs := 24, seed_value := 1) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var best: Array = []
	for r in runs:
		var b := start.clone()
		var path: Array = []
		while not b.is_won() and not b.is_lost() and path.size() < 60:
			var p := smart_pick(b, rng)
			if p == -1:
				break
			path.append(p)
			b.tap(p)
		if b.is_won() and (best.is_empty() or path.size() < best.size()):
			best = path
	return best

## A winning sequence of pile taps, or [] if none (within the search limit).
static func solve(start: Cascade, max_nodes := 200000) -> Array:
	var seen := {}
	var path: Array = []
	var counter := [0]
	if _dfs(start, seen, path, counter, max_nodes):
		return path
	return []

static func _dfs(b: Cascade, seen: Dictionary, path: Array, counter: Array, max_nodes: int) -> bool:
	if b.is_won():
		return true
	counter[0] += 1
	if counter[0] > max_nodes:
		return false
	var k := b.key()
	if seen.has(k):
		return false
	seen[k] = true
	# Try the most promising taps first: ones that burst, then ones that grab more.
	var options: Array = []
	for p in b.choices():
		var nb := b.clone()
		var ev := nb.tap(p)
		if nb.is_lost():
			continue
		var bursts := ev.filter(func(e): return e.t == "burst").size()
		options.append([bursts * 100 - nb.tray.size() * 10 + ev.size(), p, nb])
	options.sort_custom(func(a, c): return a[0] > c[0])
	for o in options:
		path.append(o[1])
		if _dfs(o[2], seen, path, counter, max_nodes):
			return true
		path.pop_back()
	return false

## A fair casual player: sees only face-up cards. Avoids starting a group
## when the tray is full, likes grabbing lots of cards, likes specials, and
## is a bit random, like a person.
static func fair_pick(b: Cascade, rng: RandomNumberGenerator) -> int:
	var best := -1
	var best_score := -INF
	# Every pile, not choices(): a wrapped top and a visible card of the same
	# colour look like different choices to a person.
	for p in b.piles.size():
		var c := b.top(p)
		if c == -1 or b.blocked(c):
			continue
		var score := rng.randf() * 12.0
		if b.card_kind[c] != Kind.CARD:
			score += 40.0
		elif b.wrapped[c] == 1:
			# A mystery card: a person guesses, and fears a full tray.
			score += rng.randf() * 20.0
			if b.tray.size() >= b.hold:
				score -= 60.0
		else:
			# Only the cards a person can see count (not wrapped ones).
			score += b.grab_preview(p).filter(func(x): return b.wrapped[x] == 0).size() * 10.0
			if b.would_crowd(p):
				score -= 100.0
		if score > best_score:
			best_score = score
			best = p
	return best

## A player who looks one tap ahead (it peeks at hidden cards, so it's only
## used to steer the solver, never to judge difficulty): avoid losing, prefer bursts, keep the
## tray small, then grab the most. Ties broken at random.
static func smart_pick(b: Cascade, rng: RandomNumberGenerator) -> int:
	var best := -1
	var best_score := -INF
	for p in b.choices():
		var nb := b.clone()
		var ev := nb.tap(p)
		var bursts := ev.filter(func(e): return e.t == "burst").size()
		var score := (-10000.0 if nb.is_lost() else 0.0) + bursts * 100.0 - nb.tray.size() * 10.0 \
			+ ev.size() + rng.randf()
		if score > best_score:
			best_score = score
			best = p
	return best
