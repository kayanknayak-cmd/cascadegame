extends Node
## All game sound. Two kinds:
##   - Real recordings (Kenney, CC0) for anything physical: cards sliding,
##     landing, flipping, chips clinking. Each call picks a random take and
##     nudges the pitch, so repeated actions never sound robotic.
##   - Bells made in code for anything musical. One bell is rendered once and
##     re-pitched with pitch_scale to play any note. Bells go through a reverb
##     bus so they ring out.
##
## Music rule: every note comes from one pentatonic scale, so any notes that
## overlap still sound good together. A streak raises the key, so the tune
## climbs as the player gets hot.

var enabled := true
var music_enabled := true

const SCALE := [0, 2, 4, 7, 9]             ## major pentatonic
const SR := 32000

var _sfx: Array[AudioStreamPlayer] = []
var _bells: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _next_bell := 0
var _cache := {}
var _bell: AudioStreamWAV
var _soft_bell: AudioStreamWAV
var _thud: AudioStreamWAV
var _last_tick_ms := 0

func _ready() -> void:
	_setup_buses()
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "Sfx"
		add_child(p)
		_sfx.append(p)
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.bus = "Bells"
		add_child(p)
		_bells.append(p)
	_music_setup()
	_bell = _render_bell(523.25, 1.6, 2.4, 3.5, 2.2)
	_soft_bell = _render_bell(523.25, 1.1, 3.5, 2.0, 1.0)
	_thud = _render_thud()

func _setup_buses() -> void:
	if AudioServer.get_bus_index("Sfx") != -1:
		return
	var master := AudioServer.get_bus_index("Master")
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(master, limiter)
	AudioServer.add_bus()
	var sfx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(sfx, "Sfx")
	AudioServer.set_bus_send(sfx, "Master")
	AudioServer.add_bus()
	var bells := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bells, "Bells")
	AudioServer.set_bus_send(bells, "Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.55
	reverb.damping = 0.4
	reverb.wet = 0.22
	reverb.dry = 0.9
	AudioServer.add_bus_effect(bells, reverb)

func _live() -> bool:
	return enabled and not _sfx.is_empty() and DisplayServer.get_name() != "headless"

# ---------------------------------------------------------------- building blocks

func _file(name: String) -> AudioStream:
	if not _cache.has(name):
		_cache[name] = load("res://sfx/%s.ogg" % name)
	return _cache[name]

## Plays one of the named takes at random.
func _take(names: Array, db := 0.0, pitch := 1.0, spread := 0.06, delay := 0.0) -> void:
	if not _live():
		return
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(_take.bind(names, db, pitch, spread, 0.0))
		return
	var p := _sfx[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx.size()
	p.stream = _file(names[randi() % names.size()])
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(1.0 - spread, 1.0 + spread)
	p.play()

## A bell on scale degree `step` (0 = C5, 5 = C6...), shifted by `key` semitones.
func note(step: int, key := 0, db := -8.0, soft := false, delay := 0.0) -> void:
	if not _live():
		return
	if delay > 0.0:
		get_tree().create_timer(delay).timeout.connect(note.bind(step, key, db, soft, 0.0))
		return
	var octave := floori(float(step) / SCALE.size())
	var semis: int = SCALE[posmod(step, SCALE.size())] + 12 * octave + key
	var p := _bells[_next_bell]
	_next_bell = (_next_bell + 1) % _bells.size()
	p.stream = _soft_bell if soft else _bell
	p.volume_db = db
	p.pitch_scale = pow(2.0, float(semis) / 12.0)
	p.play()

## FM bell: a sine wave wobbled by another sine at a non-whole ratio gives the
## metallic shimmer. The wobble fades faster than the tone, so the strike is
## bright and the tail is pure.
func _render_bell(freq: float, dur: float, decay: float, ratio: float, index: float) -> AudioStreamWAV:
	var n := int(SR * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / SR
		var env := exp(-decay * t) * minf(t * 330.0, 1.0)
		var mod := index * exp(-7.0 * t) * sin(TAU * freq * ratio * t)
		var v := sin(TAU * freq * t + mod) * 0.7
		v += sin(TAU * freq * 2.0 * t) * 0.18 * exp(-5.0 * t)
		v += sin(TAU * freq * 1.003 * t) * 0.25        # slight detune = warmth
		data.encode_s16(i * 2, int(clampf(v * env * 0.6, -1.0, 1.0) * 32767.0))
	return _wav(data)

func _render_thud() -> AudioStreamWAV:
	var n := int(SR * 0.25)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / SR
		var f := 140.0 * (1.0 - 0.4 * t)
		var v := sin(TAU * f * t) * exp(-18.0 * t) * minf(t * 400.0, 1.0)
		data.encode_s16(i * 2, int(clampf(v * 0.8, -1.0, 1.0) * 32767.0))
	return _wav(data)

func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = SR
	s.data = data
	return s

func _raw(stream: AudioStream, db: float, pitch := 1.0) -> void:
	if not _live():
		return
	var p := _sfx[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx.size()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()

# ---------------------------------------------------------------- the game's sounds

const SLIDES := ["card-slide-1", "card-slide-2", "card-slide-3", "card-slide-5", "card-slide-6"]
const PLACES := ["card-place-1", "card-place-2", "card-place-3", "card-place-4"]
const SHOVES := ["card-shove-1", "card-shove-2", "card-shove-3", "card-shove-4"]
const CHIPS := ["chip-lay-1", "chip-lay-2", "chip-lay-3"]
const STACKS := ["chips-stack-1", "chips-stack-2", "chips-stack-3", "chips-stack-4", "chips-stack-5", "chips-stack-6"]
const CLICKS := ["ui_click_001", "ui_click_002"]
const GLASS := ["ui_glass_001", "ui_glass_002"]
const HANDLES := ["chips-handle-1", "chips-handle-3", "chips-handle-5", "chips-handle-6"]

func pick() -> void:
	_take(SLIDES, -10.0, 1.15)

func land() -> void:
	_take(PLACES, -4.0, 1.0)

## A card joins a group's slot: the thud of the card plus a bell that climbs
## with each card, so the ear hears the group filling up.
func into_slot(count: int, key: int) -> void:
	_take(PLACES, -3.0, 1.05)
	note(count * 2 - 2, key, -9.0)

func flip() -> void:
	_take(["card-slide-4", "card-slide-8", "card-slide-7"], -12.0, 1.5, 0.05)

func draw_card() -> void:
	_take(SHOVES, -6.0, 1.05)

func recycle() -> void:
	_take(["card-fan-1"], -6.0, 1.1)

func deal_start() -> void:
	_take(["card-fan-2", "card-fan-1", "cards-pack-take-out-1"], -4.0, 1.0, 0.03)

## Rate-limited so a fast deal is a pleasant patter, not a wall of noise.
func deal_tick() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_tick_ms < 45:
		return
	_last_tick_ms = now
	_take(PLACES, -14.0, 1.25, 0.1)

func wrong() -> void:
	_take(["ui_error_004"], -8.0, 0.9, 0.02)
	_raw(_thud, -6.0, randf_range(0.95, 1.05))

## The last card of a group lands: a big hit before the fan-out.
func group_hit(key: int) -> void:
	_take(STACKS, -2.0, 0.9)
	_raw(_thud, -4.0, 0.8)
	note(0, key - 12, -8.0)
	note(4, key - 12, -12.0, true)

## Each fanned card of a finished group rings the next note up.
func fan_note(i: int, key: int) -> void:
	note(i + 2, key, -7.0)
	if i == 3:
		note(9, key, -12.0, true, 0.05)
		note(11, key, -14.0, true, 0.1)

func star_pip(key: int) -> void:
	_take(GLASS, -8.0, 1.2, 0.02)
	note(10, key, -11.0)

func coin(i: int) -> void:
	_take(CHIPS, -12.0, 1.0 + minf(i * 0.025, 0.5), 0.03)

func coins_burst() -> void:
	_take(HANDLES, -6.0, 1.05)

func button() -> void:
	_take(CLICKS, -6.0, 1.0, 0.03)

func hint() -> void:
	_take(["ui_glass_004"], -8.0, 1.0, 0.01)
	note(7, 0, -14.0, true)

func undo() -> void:
	_take(["card-slide-7"], -8.0, 0.85)

func low_moves() -> void:
	_take(["ui_tick_001", "ui_tick_002"], -4.0, 0.9, 0.02)

func bonus_tick(i: int) -> void:
	_take(["ui_pluck_002"], -8.0, 1.0 + minf(i * 0.04, 1.0), 0.0)
	_take(CHIPS, -14.0, 1.2 + minf(i * 0.02, 0.4))

func star(i: int) -> void:
	_take(["chips-collide-1", "chips-collide-2"], -3.0, 1.0)
	_take(["ui_bong_001"], -10.0, 1.0 + i * 0.12, 0.0)
	note(i * 2 + 4, 0, -7.0)
	note(i * 2 + 6, 0, -12.0, true, 0.06)

## Three fanfares, picked at random, so winning never sounds the same twice.
func win() -> void:
	duck(2.5, -14.0)
	_take(["ui_confirmation_002", "ui_confirmation_001"], -8.0, 1.0, 0.0)
	match randi() % 3:
		0:   # straight up the scale
			for i in 6:
				note(i + 2, 0, -8.0, false, i * 0.085)
			note(12, 0, -10.0, true, 0.6)
		1:   # bouncing arpeggio
			for i in 6:
				note([2, 5, 4, 7, 6, 9][i], 0, -8.0, false, i * 0.09)
			note(12, 0, -10.0, true, 0.62)
			note(14, 0, -14.0, true, 0.7)
		_:   # a quick run, a pause, then a high ring
			for i in 4:
				note(i * 2 + 2, 0, -8.0, false, i * 0.07)
			note(10, 0, -8.0, false, 0.42)
			note(12, 0, -9.0, false, 0.52)
			note(15, 0, -13.0, true, 0.64)

## Losing: the music dips, the cards settle with a soft slide, and a gentle
## phrase walks down and slows, ending on a low note. Sad, not scolding.
## Two versions.
func lose() -> void:
	duck(2.8, -16.0)
	_take(["card-slide-7", "card-shove-2"], -8.0, 0.7, 0.03)
	_take(PLACES, -10.0, 0.6, 0.05, 0.18)
	var phrase: Array = [[7, 5, 4, 2, 0], [6, 4, 3, 1, -1]][randi() % 2]
	var t := 0.22
	for i in phrase.size():
		note(phrase[i], -5, -9.0 - i * 0.8, true, t)
		t += 0.16 + i * 0.05
	note(-5, -5, -12.0, true, t + 0.05)
	get_tree().create_timer(t + 0.05).timeout.connect(func(): _raw(_thud, -10.0, 0.5))

func panel_in() -> void:
	_take(["ui_maximize_006", "ui_open_001"], -10.0, 1.0, 0.02)

func streak_up(level: int) -> void:
	_take(["ui_select_006"], -14.0, 1.0 + level * 0.08, 0.0)

# ---------------------------------------------------------------- Magnet Cascade

## The first cards a tap grabs: a whoosh of cards leaving together.
func grab(count: int) -> void:
	_take(SLIDES, -6.0, 1.1)
	if count > 1:
		_take(SHOVES, -10.0, 1.2, 0.05, 0.04)

## Each link of a chain is one note higher, so a long chain is a rising run.
func link(step: int) -> void:
	_take(PLACES, -9.0, 1.1 + minf(step * 0.03, 0.3), 0.04)
	note(step + 1, 0, -8.0)

## A group bursts in the tray. The nth burst of one tap climbs the key.
func burst(n: int) -> void:
	var key := 2 * mini(n, 5)
	_take(["card-fan-1", "card-fan-2"], -12.0, 1.6 + n * 0.1, 0.05, 0.05)   # papery confetti flutter
	_take(STACKS, -2.0, 0.95 + n * 0.05)
	_raw(_thud, -5.0, 0.85)
	# Three chord shapes, all in the scale.
	var chord: Array = [[4, 6, 9], [3, 5, 8], [4, 7, 9]][randi() % 3]
	note(chord[0], key, -7.0)
	note(chord[1], key, -9.0, false, 0.06)
	note(chord[2], key, -10.0, true, 0.12)

func magnet_fire() -> void:
	_take(["ui_glass_004", "ui_glass_002"], -4.0, 0.8, 0.02)
	var up := randi() % 2 == 0
	for i in 5:
		note(i * 2 if up else 8 - i * 2 + 2, 0, -9.0, true, i * 0.04)

## Shuffle card: a real riffle of cards and a quick up-and-down trill.
func shuffle_fire() -> void:
	_take(["card-shuffle"], -4.0, 1.1, 0.04)
	for i in 6:
		note([3, 5, 4, 6, 5, 7][i], 0, -13.0, true, 0.1 + i * 0.05)

func bomb_blast() -> void:
	_raw(_thud, 0.0, 0.6)
	_raw(_thud, -3.0, 0.9)
	_take(["chips-collide-1", "chips-collide-3"], 0.0, 0.7)
	_take(SHOVES, -4.0, 0.8, 0.05, 0.05)

func card_flung() -> void:
	_take(SLIDES, -12.0, 1.4, 0.1)

## Tray is into its danger slot.
func danger() -> void:
	_take(["ui_error_006"], -6.0, 1.0, 0.0)
	_raw(_thud, -4.0, 0.7)

## Big-tap payoff: bigger combos, bigger fanfare.
func combo(level: int) -> void:
	duck(1.2, -8.0)
	_take(["ui_confirmation_004"], -8.0, 1.0 + level * 0.05, 0.0)
	for i in 3 + level:
		note(i * 2 + 2, 0, -9.0, false, i * 0.06)

## A star on the live meter falls away: a small downward sigh, not a scold.
func star_lost() -> void:
	note(4, -12, -12.0, true)
	note(2, -12, -13.0, true, 0.12)

func panel_out() -> void:
	_take(["ui_close_002"], -10.0, 1.0, 0.02)

## A special card turned up: a quick rising trill before it goes off.
func special_reveal() -> void:
	for i in 4:
		note(5 + i, 0, -14.0, true, i * 0.05)

## Danger slot is full: a low double thump, like a heartbeat.
func heartbeat() -> void:
	_raw(_thud, -8.0, 0.55)
	get_tree().create_timer(0.16).timeout.connect(func(): _raw(_thud, -11.0, 0.5))

# ---------------------------------------------------------------- music
## Quiet generative music: a slow I-vi-IV-V progression played on a soft pad,
## with a sparse bell melody picked at random from each chord's notes. It
## never repeats exactly, never clashes (every note belongs to the chord),
## and sits well under the game sounds.

const BPM := 76.0
## Themes: chords (semitones from C5), tempo, and which bell sings the tune.
## One per chapter of ten levels, plus a boss theme (minor, drum, faster) and a
## calm daily theme. Every tune note is a chord tone, so it never clashes.
const THEMES := {
	"ch0": {"chords": [[0, 4, 7], [-3, 0, 4], [-7, -3, 0], [-5, -1, 2]], "bpm": 76.0, "soft": true},      # C Am F G  warm
	"ch1": {"chords": [[-7, -3, 0], [0, 4, 7], [-5, -1, 2], [-3, 0, 4]], "bpm": 80.0, "soft": false},     # F C G Am  bright
	"ch2": {"chords": [[-3, 0, 4], [-7, -3, 0], [0, 4, 7], [-5, -1, 2]], "bpm": 72.0, "soft": true},      # Am F C G  wistful
	"ch3": {"chords": [[0, 4, 7], [-5, -1, 2], [-3, 0, 4], [-7, -3, 0]], "bpm": 82.0, "soft": false},     # C G Am F  hopeful
	"ch4": {"chords": [[-7, -3, 0], [-5, -1, 2], [-8, -5, -1], [-3, 0, 4]], "bpm": 70.0, "soft": true},   # F G Em Am dreamy
	"ch5": {"chords": [[-5, -1, 2], [0, 4, 7], [2, 6, 9], [-5, -1, 2]], "bpm": 88.0, "soft": false},      # G C D G   folk
	"ch6": {"chords": [[2, 5, 9], [-5, -1, 2], [0, 4, 7], [-3, 0, 4]], "bpm": 76.0, "soft": true},        # Dm G C Am gentle
	"ch7": {"chords": [[0, 4, 7], [-7, -3, 0], [-3, 0, 4], [-5, -1, 2]], "bpm": 86.0, "soft": false},     # C F Am G  bold
	"ch8": {"chords": [[-3, 0, 4], [2, 5, 9], [-5, -1, 2], [0, 4, 7]], "bpm": 68.0, "soft": true},        # Am Dm G C lullaby
	"ch9": {"chords": [[-7, -3, 0], [-5, -1, 2], [0, 4, 7], [-3, 0, 4]], "bpm": 84.0, "soft": false},     # F G C Am  grand
	"boss": {"chords": [[-3, 0, 4], [2, 5, 9], [4, 8, 11], [-7, -3, 0]], "bpm": 94.0, "soft": false, "drum": true},  # Am Dm E F
	"daily": {"chords": [[0, 4, 7], [-8, -5, -1], [-7, -3, 0], [0, 4, 7]], "bpm": 64.0, "soft": true},    # C Em F C  morning coffee
	"spooky": {"chords": [[-3, 0, 4], [-7, -3, 0], [2, 5, 9], [4, 8, 11]], "bpm": 70.0, "soft": true, "drum": true},  # October
}
## Kept for older callers: the four original moods.
const MOODS := [
	[[0, 4, 7], [-3, 0, 4], [-7, -3, 0], [-5, -1, 2]],
	[[-7, -3, 0], [0, 4, 7], [-5, -1, 2], [-3, 0, 4]],
	[[-3, 0, 4], [-7, -3, 0], [0, 4, 7], [-5, -1, 2]],
	[[0, 4, 7], [-5, -1, 2], [-3, 0, 4], [-7, -3, 0]],
]
var CHORDS: Array = MOODS[0]
var theme := "ch0"
var _theme_bpm := BPM
var _theme_soft := true
var _theme_drum := false
## How full the music is. In a level it builds as groups burst:
## 0 pad only, 1 + bass, 2 + tune, 3 + a light beat and a little faster.
var layers := 2
var _key_shift := 0          ## semitones up, after a Cascade! (resets each level)
var _music: Array[AudioStreamPlayer] = []
var _next_music := 0
var _pad: AudioStreamWAV
var _bass: AudioStreamWAV
var _tick: AudioStreamWAV
var _music_timer: Timer
var _beat := 0

func _music_setup() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, "Music")
		AudioServer.set_bus_send(i, "Master")
		AudioServer.set_bus_volume_db(i, -6.0)
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.8
		rv.wet = 0.35
		rv.dry = 0.8
		AudioServer.add_bus_effect(i, rv)
	for k in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_music.append(p)
	_pad = _render_pad(261.63, 3.4)
	_bass = _render_bass(130.81, 0.55)
	_tick = _render_tick()
	_music_timer = Timer.new()
	_music_timer.wait_time = 60.0 / BPM
	_music_timer.timeout.connect(_music_beat)
	add_child(_music_timer)

## Soft pad: slow swell, gentle fade, two slightly detuned sines.
func _render_pad(freq: float, dur: float) -> AudioStreamWAV:
	var n := int(SR * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / SR
		var env := minf(t / 0.6, 1.0) * clampf((dur - t) / 1.4, 0.0, 1.0)
		var v := sin(TAU * freq * t) * 0.5 + sin(TAU * freq * 1.004 * t) * 0.35 + sin(TAU * freq * 2.0 * t) * 0.08
		data.encode_s16(i * 2, int(clampf(v * env * 0.5, -1.0, 1.0) * 32767.0))
	return _wav(data)

## A short round bass note: one sine an octave down, quick fade.
func _render_bass(freq: float, dur: float) -> AudioStreamWAV:
	var n := int(SR * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / SR
		var env := minf(t / 0.02, 1.0) * exp(-t * 5.0)
		var v := sin(TAU * freq * t) * 0.8 + sin(TAU * freq * 2.0 * t) * 0.12
		data.encode_s16(i * 2, int(clampf(v * env * 0.6, -1.0, 1.0) * 32767.0))
	return _wav(data)

## A soft brushed tick for the beat (filtered noise, very short).
func _render_tick() -> AudioStreamWAV:
	var n := int(SR * 0.06)
	var data := PackedByteArray()
	data.resize(n * 2)
	var last := 0.0
	for i in n:
		var t := float(i) / SR
		var raw := randf_range(-1.0, 1.0)
		last = lerpf(last, raw, 0.35)
		var v := (raw - last) * exp(-t * 70.0)
		data.encode_s16(i * 2, int(clampf(v * 0.5, -1.0, 1.0) * 32767.0))
	return _wav(data)

## The theme for a level: its chapter's, or the boss theme every tenth level.
## Seasonal: October turns the chapter themes spooky. The music starts thin
## and builds as groups burst (see music_layers).
func music_mood(level_index: int) -> void:
	var key := "ch%d" % (posmod(maxi(level_index, 0) / 10, 10))
	if level_index >= 0 and (level_index + 1) % 10 == 0:
		key = "boss"
	elif level_index >= 0 and int(Time.get_datetime_dict_from_system().month) == 10:
		key = "spooky"
	music_theme(key)
	_key_shift = 0
	layers = 0

func music_theme(key: String) -> void:
	var t: Dictionary = THEMES.get(key, THEMES["ch0"])
	theme = key
	CHORDS = t.chords
	_theme_bpm = float(t.bpm)
	_theme_soft = bool(t.get("soft", true))
	_theme_drum = bool(t.get("drum", false))
	_apply_tempo()

## The music fills out: 0..3 (see `layers`).
func music_layers(n: int) -> void:
	n = clampi(n, 0, 3)
	if n == layers:
		return
	layers = n
	_apply_tempo()

## After a Cascade!: the rest of the level plays a whole step higher.
func key_up() -> void:
	_key_shift = 2

func _apply_tempo() -> void:
	if _music_timer:
		_music_timer.wait_time = 60.0 / (_theme_bpm + (6.0 if layers >= 3 else 0.0))

## Pull the music down under a big moment, then let it back up.
func duck(seconds := 1.5, amount_db := -10.0) -> void:
	var i := AudioServer.get_bus_index("Music")
	if i == -1:
		return
	var t := create_tween()
	t.tween_method(func(v: float): AudioServer.set_bus_volume_db(i, v), -6.0, -6.0 + amount_db, 0.12)
	t.tween_interval(seconds)
	t.tween_method(func(v: float): AudioServer.set_bus_volume_db(i, v), -6.0 + amount_db, -6.0, 0.8)

func music_start() -> void:
	if _music_timer and _music_timer.is_stopped() and music_enabled and _live():
		_beat = 0
		_music_timer.start()

func music_stop() -> void:
	if _music_timer:
		_music_timer.stop()

func _music_beat() -> void:
	if not (music_enabled and _live()):
		return
	var bar := (_beat / 4) % CHORDS.size()
	var pos := _beat % 4
	var chord: Array = CHORDS[bar]
	var k0 := _key_shift
	if pos == 0:
		for k in 2:
			_music_note(_pad, chord[k] - 12 + k0, -20.0)
	# Bass: the chord's root, low, on beats 1 and 3.
	if layers >= 1 and (pos == 0 or pos == 2):
		_music_note(_bass, chord[0] - 12 + k0, -19.0 if pos == 0 else -23.0)
	# A sparse tune: about half the beats, a chord tone an octave up.
	if layers >= 2 and randf() < (0.55 if pos != 0 else 0.3):
		var semis: int = chord[randi() % chord.size()] + (12 if randf() < 0.6 else 0) + k0
		_music_note(_soft_bell if _theme_soft else _bell, semis, (-24.0 if _theme_soft else -27.0) + randf() * 3.0)
	# The beat: a soft thud on 1 (and 3 for the boss), ticks in between.
	if layers >= 3 or (_theme_drum and layers >= 1):
		if pos == 0 or (_theme_drum and pos == 2):
			_music_note(_thud, 0, -20.0)
		else:
			_music_note(_tick, 0, -22.0)
	# December: sleigh-bell shimmer on the off-beats.
	if layers >= 1 and int(Time.get_datetime_dict_from_system().month) == 12 and pos % 2 == 1:
		_music_note(_tick, 24, -26.0)
	_beat += 1

func _music_note(stream: AudioStream, semis: int, db: float) -> void:
	var p := _music[_next_music]
	_next_music = (_next_music + 1) % _music.size()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pow(2.0, float(semis) / 12.0)
	p.play()

func lock_tick() -> void:
	_take(["chip-lay-2"], -10.0, 1.4, 0.03)

## A lock springs open: a metallic click and a bright rising pair.
func unlock() -> void:
	_take(["chips-collide-2"], -4.0, 1.5, 0.02)
	note(7, 0, -8.0)
	note(9, 0, -10.0, false, 0.07)

func page_turn() -> void:
	_take(["card-fan-1", "card-fan-2"], -8.0, 1.25, 0.05)

## Wild card: a quick glissando up the scale.
func wild() -> void:
	for i in 7:
		note(i + 2, 0, -10.0, i % 2 == 1, i * 0.035)
	_take(["ui_glass_004"], -10.0, 1.3, 0.0)

## Rising drumroll of thuds as a jackpot chain slows down.
func jackpot_build() -> void:
	for i in 8:
		get_tree().create_timer(i * 0.07, true, false, true).timeout.connect(func(): _raw(_thud, -10.0 + i, 0.6 + i * 0.05))

## The jackpot lands: a full arpeggio two octaves up, chips pouring.
func jackpot() -> void:
	duck(2.5, -16.0)
	_take(["chips-handle-5"], -2.0, 1.0, 0.02)
	_take(["ui_confirmation_004"], -6.0, 1.1, 0.0)
	for i in 10:
		note(i + 2, 0, -8.0, i % 3 == 2, i * 0.06)
	note(12, 0, -8.0, false, 0.7)
	note(14, 0, -10.0, true, 0.7)

## Undo: a quick descending run, like a tape rewinding.
func rewind() -> void:
	for i in 4:
		note(8 - i * 2, 0, -14.0, true, i * 0.04)

## A card lands in the tray: the thud, plus a soft note that climbs with how
## full its group is (1st card low, 4th card high).
func tray_land(count: int) -> void:
	_take(PLACES, -6.0, 1.0 + count * 0.03)
	note(count * 2 - 1, 0, -15.0, true)

## Gift card: the blade starts moving.
func gift_swipe() -> void:
	_take(["card-slide-3", "card-slide-5"], -10.0, 1.5, 0.05)

## The ribbon is cut: a sharp snip, a papery rip and a bright sparkle.
func gift_cut() -> void:
	_take(["ui_click_002"], -2.0, 1.4, 0.0)
	_take(SHOVES, -3.0, 1.6, 0.05)
	_take(["card-fan-1"], -6.0, 1.8, 0.02)
	for i in 3:
		note(9 + i, 0, -10.0, true, 0.05 + i * 0.05)

## The gift card turns over: a card flip, a thump and a rising chord.
func gift_flip() -> void:
	_take(["card-place-3"], -2.0, 0.9, 0.0)
	_raw(_thud, -4.0, 0.8)
	for i in 5:
		note(i * 2 + 2, 0, -8.0, false, 0.08 + i * 0.07)

## Restoring part of the shop: stars whoosh over, then a sweep and a chime.
## Something bought in the shop: a card fan, chips and a rising run.
func purchase() -> void:
	_take(["card-fan-2"], -6.0, 1.3, 0.05)
	_take(STACKS, -6.0, 1.1)
	for i in 4:
		note(i * 2 + 4, 0, -8.0, false, i * 0.07)
