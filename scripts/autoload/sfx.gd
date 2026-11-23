extends Node
## Audio director. Everything is synthesized at startup (no audio files), off the main thread.
##
## - Music: generative ambient. Soft pad chords and sparse piano notes are scheduled live,
##   so it never loops audibly. The mood follows the game: focus, incident (tense), calm.
## - Ambience: office room tone plus occasional distant typing and a cup clink.
## - SFX: restrained, OS-like UI sounds; muted piano tones for outcomes.
## Buses: Music (reverb + low-pass for muffling), SFX (light reverb), Ambience.

const RATE := 32000
const PAD_RATE := 11025
const SETTINGS_PATH := "user://audio.json"

## Chords per mood (MIDI). Everything stays diatonic to C major so one piano set covers it.
const CHORDS := {
	"focus": [[53, 57, 60, 64], [57, 60, 64, 67], [50, 57, 60, 64], [48, 55, 59, 64]],
	"calm": [[48, 55, 62, 64], [53, 57, 60, 64]],
	"tense": [[45, 52, 57, 60], [41, 48, 57, 64], [50, 53, 57, 62], [40, 52, 55, 59]],
}
const PIANO_NOTES := [55, 57, 59, 60, 62, 64, 65, 67, 69, 71, 72, 74, 76, 77, 79, 81, 83, 84]

var music_volume := 0.5
var sfx_volume := 0.7
var ambience_volume := 0.55

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _pad_players: Array[AudioStreamPlayer] = []
var _piano_players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer        # first pad voice; tests wait for its stream
var _ambience: AudioStreamPlayer
var _amb_events: AudioStreamPlayer
var _pad_notes := {}
var _piano := {}
var _next := 0
var _pad_next := 0
var _piano_next := 0
var _music_on := false
var _mood := "focus"
var _chord_i := 0
var _chord_timer := 0.0
var _note_timer := 3.0
var _amb_timer := 8.0
var _rng := RandomNumberGenerator.new()
var _sfx_thread := Thread.new()
var _music_thread := Thread.new()


func _ready() -> void:
	set_process(false)
	_rng.randomize()
	_load_settings()
	_setup_buses()
	for i in 12:
		_players.append(_player("SFX"))
	for i in 8:
		_pad_players.append(_player("Music"))
	for i in 5:
		_piano_players.append(_player("Music"))
	_music = _pad_players[0]
	_ambience = _player("Ambience")
	_amb_events = _player("Ambience")
	apply_volumes()
	_sfx_thread.start(_build_sfx)
	while _sfx_thread.is_alive():
		await get_tree().process_frame
	_streams = _sfx_thread.wait_to_finish()
	_connect_game()
	_music_thread.start(_build_music)
	while _music_thread.is_alive():
		await get_tree().process_frame
	var m: Dictionary = _music_thread.wait_to_finish()
	_pad_notes = m["pads"]
	_piano = m["piano"]
	_ambience.stream = m["room"]
	_streams["amb_typing"] = m["typing"]
	_streams["amb_cup"] = m["cup"]
	_music.stream = _pad_notes.values()[0]
	set_process(true)


func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func stop_all() -> void:
	_music_on = false
	for p in _players + _pad_players + _piano_players + [_ambience, _amb_events]:
		if is_instance_valid(p):
			p.stop()
			p.stream = null


func _exit_tree() -> void:
	for t in [_sfx_thread, _music_thread]:
		if t.is_started():
			t.wait_to_finish()
	stop_all()
	_streams.clear()


# --- Music direction ----------------------------------------------------------------

func start_music() -> void:
	_music_on = true
	_chord_timer = 0.0
	if _ambience.stream and not _ambience.playing:
		_ambience.play()


func fade_music(to_db: float, sec := 1.0) -> void:
	var bus := AudioServer.get_bus_index("Music")
	var from := AudioServer.get_bus_volume_db(bus)
	create_tween().tween_method(func(v: float) -> void: AudioServer.set_bus_volume_db(bus, v), from, to_db, sec)


## Muffles the music and room (monitor off at night / clock-out).
func muffle(on: bool) -> void:
	var lp := AudioServer.get_bus_effect(AudioServer.get_bus_index("Music"), 1) as AudioEffectLowPassFilter
	if lp:
		create_tween().tween_method(func(v: float) -> void: lp.cutoff_hz = v, lp.cutoff_hz, 900.0 if on else 12000.0, 1.2)


func _current_mood() -> String:
	if not Game.state.has("monitor"):
		return "focus"
	if Game.state.get("day_done", false):
		return "calm"
	for s in Game.state["monitor"]["status"].values():
		if s != "ok":
			return "tense"
	return "focus"


func _process(delta: float) -> void:
	if not _music_on or _pad_notes.is_empty():
		return
	var mood := _current_mood()
	if mood != _mood:
		_mood = mood
		_chord_i = 0
		_chord_timer = minf(_chord_timer, 1.5)
	_chord_timer -= delta
	if _chord_timer <= 0.0:
		_play_chord()
		_chord_timer = {"focus": 9.5, "calm": 12.0, "tense": 7.5}[_mood]
	_note_timer -= delta
	if _note_timer <= 0.0:
		if _mood != "calm" or _rng.randf() < 0.35:
			_play_phrase()
		_note_timer = _rng.randf_range(2.8, 6.5) if _mood == "focus" else _rng.randf_range(4.0, 8.0)
	_amb_timer -= delta
	if _amb_timer <= 0.0:
		_ambient_event()
		_amb_timer = _rng.randf_range(10.0, 26.0)


func _chord() -> Array:
	var set: Array = CHORDS[_mood]
	return set[_chord_i % set.size()]


func _play_chord() -> void:
	_chord_i += 1
	var level: float = {"focus": -11.0, "calm": -14.0, "tense": -10.0}[_mood]
	for note in _chord():
		var s = _pad_notes.get(note)
		if s == null:
			continue
		var p := _pad_players[_pad_next]
		_pad_next = (_pad_next + 1) % _pad_players.size()
		p.stream = s
		p.volume_db = level + _rng.randf_range(-1.5, 0.5)
		p.pitch_scale = 1.0
		p.play()


func _play_phrase() -> void:
	var chord := _chord()
	var pool: Array = []
	for n in chord:
		for octave in ([12, 24] if _mood == "focus" else [0, 12]):
			if _piano.has(n + octave):
				pool.append(n + octave)
	if _mood == "focus":
		for extra in [74, 79, 81]:  # 9ths and 6ths add air
			pool.append(extra)
	if pool.is_empty():
		return
	var count := _rng.randi_range(1, 3 if _mood == "focus" else 2)
	var start: int = pool[_rng.randi() % pool.size()]
	var delay := 0.0
	for i in count:
		var note: int = start if i == 0 else pool[_rng.randi() % pool.size()]
		_piano_after(note, delay, _rng.randf_range(-17.0, -11.0) if _mood != "tense" else _rng.randf_range(-15.0, -10.0))
		delay += _rng.randf_range(0.28, 0.7)


func _piano_after(note: int, delay: float, db: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	var s = _piano.get(note)
	if s == null:
		return
	var p := _piano_players[_piano_next]
	_piano_next = (_piano_next + 1) % _piano_players.size()
	p.stream = s
	p.volume_db = db
	p.play()


func _ambient_event() -> void:
	if _amb_events.playing:
		return
	if _rng.randf() < 0.82:
		_amb_events.stream = _streams.get("amb_typing")
		_amb_events.volume_db = _rng.randf_range(-12.0, -7.0)
		_amb_events.pitch_scale = _rng.randf_range(0.9, 1.1)
	else:
		_amb_events.stream = _streams.get("amb_cup")
		_amb_events.volume_db = -10.0
		_amb_events.pitch_scale = _rng.randf_range(0.95, 1.05)
	if _amb_events.stream:
		_amb_events.play()


# --- Settings ----------------------------------------------------------------------

func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if typeof(d) == TYPE_DICTIONARY:
			music_volume = float(d.get("music", music_volume))
			sfx_volume = float(d.get("sfx", sfx_volume))
			ambience_volume = float(d.get("ambience", ambience_volume))


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"music": music_volume, "sfx": sfx_volume, "ambience": ambience_volume}))
	f.close()


func _setup_buses() -> void:
	for bus in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var music := AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(music) == 0:
		var rv := AudioEffectReverb.new()
		rv.room_size = 0.85
		rv.damping = 0.55
		rv.spread = 0.9
		rv.dry = 0.75
		rv.wet = 0.42
		rv.predelay_msec = 40
		AudioServer.add_bus_effect(music, rv)
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 12000
		AudioServer.add_bus_effect(music, lp)
	var sfx := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx) == 0:
		var rv2 := AudioEffectReverb.new()
		rv2.room_size = 0.35
		rv2.damping = 0.7
		rv2.dry = 0.95
		rv2.wet = 0.14
		AudioServer.add_bus_effect(sfx, rv2)
	var amb := AudioServer.get_bus_index("Ambience")
	if AudioServer.get_bus_effect_count(amb) == 0:
		var lp2 := AudioEffectLowPassFilter.new()
		lp2.cutoff_hz = 4500
		AudioServer.add_bus_effect(amb, lp2)


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), linear_to_db(maxf(ambience_volume, 0.0001)))


# --- Playback ----------------------------------------------------------------------

func play(id: String, pitch := 1.0, volume_db := 0.0) -> void:
	var s = _streams.get(id)
	if s == null:
		return
	if s is Array:
		s = s[_rng.randi() % s.size()]
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## Keyboard: heavier sound for space/enter/backspace, slight random variation.
func type_key(keycode := 0) -> void:
	if keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_BACKSPACE]:
		play("type_heavy", _rng.randf_range(0.96, 1.04), -4.0)
	else:
		play("type", _rng.randf_range(0.95, 1.06), -5.0)


func footsteps(count := 5, interval := 0.42) -> void:
	for i in count:
		play("step", _rng.randf_range(0.94, 1.04), -22.0 + i * 3.2)
		await get_tree().create_timer(interval * _rng.randf_range(0.93, 1.07)).timeout


# --- Wiring -------------------------------------------------------------------------

func _connect_game() -> void:
	Game.toast.connect(func(app: String, _t: String, _b: String) -> void:
		play("message" if app in ["chat", "browser"] else "notify"))
	Game.relation_changed.connect(func(_n: String, _k: String, d: int) -> void:
		if d <= -4:
			play("down"))
	Game.event.connect(_on_event)
	Game.day_finished.connect(func(_d: int) -> void: play("evening"))


func _on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"ci":
			var pr := CodeHub.get_pr(int(d["pr"]))
			if pr.get("author", "") == "me":
				play("success" if d["ok"] else "fail")
		"pr_merged":
			if CodeHub.get_pr(int(d["pr"])).get("author", "") == "me":
				play("merged")
		"tests":
			play("tests_ok" if d.get("ok", false) else "tests_fail")
		"purchase":
			play("purchase")
		"caught":
			play("busted")
		"git_pushed":
			play("push")
		"git_committed":
			play("commit")


# --- Synthesis (runs on worker threads) ------------------------------------------------

static func _hz(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


static func _wav(samples: PackedFloat32Array, rate := RATE, loop := false) -> AudioStreamWAV:
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var gain := 0.9 / peak if peak > 0.9 else 1.0
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


static func _buf(sec: float, rate := RATE) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(sec * rate))
	return b


## Adds src into dst at an offset (seconds), scaled.
static func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, at: float, gain: float) -> void:
	var o := int(at * RATE)
	var n := mini(src.size(), dst.size() - o)
	for i in n:
		dst[o + i] += src[i] * gain


## A soft felt-piano tone: inharmonic partials with per-partial decay and a muted hammer.
static func _piano_tone(midi: float, dur: float, bright: float, seed: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var f := _hz(midi)
	var b := _buf(dur)
	var partials := 6
	var amps := PackedFloat32Array()
	var incs := PackedFloat32Array()
	var decs := PackedFloat32Array()
	for k in range(1, partials + 1):
		var fk := f * k * sqrt(1.0 + 0.00035 * k * k)
		if fk > RATE * 0.45:
			break
		amps.append(pow(k, -1.6) * (1.0 if k == 1 else bright))
		incs.append(TAU * fk / RATE)
		decs.append(exp(-(0.8 + 0.7 * k + f / 900.0) / RATE))
	var phases := PackedFloat32Array()
	phases.resize(amps.size())
	var env := PackedFloat32Array(amps)
	var lp := 0.0
	var n := b.size()
	for i in n:
		var v := 0.0
		for k in amps.size():
			phases[k] += incs[k]
			v += sin(phases[k]) * env[k]
			env[k] *= decs[k]
		if i < 400:
			lp += 0.08 * (rng.randf_range(-1.0, 1.0) - lp)
			v += lp * 0.25 * (1.0 - i / 400.0)
		var a := minf(1.0, i / 90.0)
		var tail := minf(1.0, (n - i) / 1600.0)
		b[i] = v * a * tail * 0.35
	return b


## FM glass bell (notifications).
static func _bell(freq: float, dur: float, ratio: float, index: float, amp: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var n := b.size()
	for i in n:
		var t := float(i) / RATE
		var e := exp(-t * 4.5)
		var mod := sin(TAU * freq * ratio * t) * index * exp(-t * 9.0)
		b[i] = sin(TAU * freq * t + mod) * e * minf(1.0, i / 60.0) * amp
	return b


## Band-limited noise burst: one-pole low-pass minus a slower one (crude band-pass).
static func _noise(dur: float, lo: float, hi: float, decay: float, amp: float, seed: int, attack := 0.001) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var b := _buf(dur)
	var a_hi := clampf(TAU * hi / RATE, 0.0, 1.0)
	var a_lo := clampf(TAU * lo / RATE, 0.0, 1.0)
	var y1 := 0.0
	var y2 := 0.0
	var atk := maxf(1.0, attack * RATE)
	for i in b.size():
		var x := rng.randf_range(-1.0, 1.0)
		y1 += a_hi * (x - y1)
		y2 += a_lo * (y1 - y2)
		var t := float(i) / RATE
		b[i] = (y1 - y2) * exp(-t * decay) * minf(1.0, i / atk) * amp
	return b


static func _sine_drop(f0: float, f1: float, dur: float, decay: float, amp: float) -> PackedFloat32Array:
	var b := _buf(dur)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := f1 + (f0 - f1) * exp(-t * 30.0)
		ph += TAU * f / RATE
		b[i] = (sin(ph) + 0.12 * sin(ph * 2.0)) * exp(-t * decay) * minf(1.0, i / 40.0) * amp
	return b


## One mechanical key: plastic transient + switch click + low "thock" body.
static func _key(seed: int, body_hz: float, heavy: bool) -> PackedFloat32Array:
	var b := _buf(0.09)
	_mix(b, _noise(0.012, 1800, 7000, 380, 0.55, seed), 0.0, 1.0)
	_mix(b, _noise(0.02, 600, 2600, 160, 0.35, seed + 1), 0.004, 1.0)
	var body := _sine_drop(body_hz * 1.5, body_hz, 0.07, 70 if not heavy else 45, 0.5 if not heavy else 0.75)
	_mix(b, body, 0.002, 1.0)
	if heavy:
		_mix(b, _noise(0.04, 120, 900, 60, 0.4, seed + 2), 0.0, 1.0)
	return b


func _build_sfx() -> Dictionary:
	var s := {}
	var keys: Array = []
	for i in 6:
		keys.append(_wav(_key(100 + i, 160.0 + i * 14.0, false)))
	s["type"] = keys
	s["type_heavy"] = [_wav(_key(200, 120.0, true)), _wav(_key(201, 110.0, true))]
	s["click"] = _wav(_noise(0.02, 1200, 5000, 260, 0.35, 7))
	s["tick"] = _wav(_bell(2093.0, 0.25, 2.0, 0.6, 0.18))
	s["window"] = _wav(_noise(0.16, 400, 3000, 22, 0.16, 9, 0.04))
	s["message"] = _wav(_sine_drop(1046.0, 784.0, 0.22, 16, 0.3))
	var notify := _buf(1.6)
	_mix(notify, _bell(1318.5, 1.4, 3.5, 1.6, 0.22), 0.0, 1.0)
	_mix(notify, _bell(1975.5, 1.2, 3.5, 1.2, 0.14), 0.09, 1.0)
	s["notify"] = _wav(notify)
	var commit := _buf(0.5)
	_mix(commit, _piano_tone(84, 0.5, 0.5, 1), 0.0, 0.7)
	s["commit"] = _wav(commit)
	s["push"] = _wav(_noise(0.45, 300, 2200, 7, 0.22, 11, 0.12))
	var ok := _buf(1.6)
	_mix(ok, _piano_tone(76, 1.5, 0.6, 2), 0.0, 0.8)
	_mix(ok, _piano_tone(83, 1.4, 0.6, 3), 0.11, 0.6)
	s["tests_ok"] = _wav(ok)
	var bad := _buf(1.1)
	_mix(bad, _piano_tone(48, 1.0, 0.15, 4), 0.0, 0.9)
	_mix(bad, _piano_tone(49, 1.0, 0.15, 5), 0.02, 0.6)
	s["tests_fail"] = _wav(bad)
	var success := _buf(2.2)
	_mix(success, _piano_tone(67, 2.0, 0.6, 6), 0.0, 0.7)
	_mix(success, _piano_tone(74, 2.0, 0.6, 7), 0.12, 0.65)
	_mix(success, _piano_tone(79, 1.9, 0.6, 8), 0.24, 0.55)
	s["success"] = _wav(success)
	var fail := _buf(1.8)
	_mix(fail, _piano_tone(40, 1.7, 0.2, 9), 0.0, 1.0)
	_mix(fail, _piano_tone(46, 1.7, 0.2, 10), 0.03, 0.6)
	_mix(fail, _noise(0.2, 40, 300, 18, 0.5, 12), 0.0, 1.0)
	s["fail"] = _wav(fail)
	var merged := _buf(3.2)
	var arp := [60, 64, 67, 71, 76]
	for i in arp.size():
		_mix(merged, _piano_tone(arp[i], 2.8 - i * 0.2, 0.7, 20 + i), i * 0.13, 0.55)
	s["merged"] = _wav(merged)
	var promote := _buf(4.5)
	for i in [48, 55, 64, 71, 74, 79].size():
		var n: int = [48, 55, 64, 71, 74, 79][i]
		_mix(promote, _piano_tone(n, 4.0, 0.7, 30 + i), i * 0.07, 0.5)
	s["promote"] = _wav(promote)
	s["down"] = _wav(_sine_drop(330.0, 220.0, 0.25, 14, 0.25))
	var steps: Array = []
	for i in 3:
		var st := _buf(0.2)
		_mix(st, _noise(0.15, 40, 380, 28, 0.9, 40 + i), 0.0, 1.0)
		_mix(st, _sine_drop(110.0, 70.0, 0.12, 30, 0.6), 0.0, 1.0)
		steps.append(_wav(st))
	s["step"] = steps
	var heart := _buf(0.9)
	_mix(heart, _sine_drop(75.0, 50.0, 0.18, 22, 0.7), 0.0, 1.0)
	_mix(heart, _sine_drop(70.0, 48.0, 0.18, 22, 0.5), 0.26, 1.0)
	s["heart"] = _wav(heart)
	var busted := _buf(3.0)
	_mix(busted, _noise(0.3, 30, 250, 10, 1.0, 50), 0.0, 1.0)
	_mix(busted, _piano_tone(33, 2.8, 0.3, 51), 0.0, 1.0)
	_mix(busted, _piano_tone(34, 2.8, 0.3, 52), 0.01, 0.8)
	_mix(busted, _piano_tone(40, 2.6, 0.3, 53), 0.02, 0.7)
	s["busted"] = _wav(busted)
	s["relief"] = _wav(_noise(0.9, 200, 1400, 3.5, 0.18, 60, 0.25))
	var purchase := _buf(0.8)
	_mix(purchase, _noise(0.01, 2000, 8000, 400, 0.4, 61), 0.0, 1.0)
	_mix(purchase, _noise(0.01, 2000, 8000, 400, 0.35, 62), 0.07, 1.0)
	_mix(purchase, _bell(2637.0, 0.7, 2.0, 0.8, 0.16), 0.12, 1.0)
	s["purchase"] = _wav(purchase)
	var power := _buf(0.7)
	_mix(power, _sine_drop(120.0, 55.0, 0.3, 14, 0.6), 0.0, 1.0)
	_mix(power, _noise(0.5, 2000, 6000, 8, 0.03, 63, 0.05), 0.02, 1.0)
	s["power"] = _wav(power)
	var boot := _buf(4.0)
	for i in [48, 55, 62, 64, 71].size():
		var n2: int = [48, 55, 62, 64, 71][i]
		_mix(boot, _piano_tone(n2, 3.6, 0.5, 70 + i), i * 0.18, 0.45)
	s["boot"] = _wav(boot)
	var evening := _buf(3.6)
	for i in [76, 72, 67, 64].size():
		_mix(evening, _piano_tone([76, 72, 67, 64][i], 2.4, 0.5, 80 + i), i * 0.42, 0.5)
	s["evening"] = _wav(evening)
	var morning := _buf(3.4)
	for i in [67, 71, 74, 79].size():
		_mix(morning, _piano_tone([67, 71, 74, 79][i], 2.2, 0.6, 90 + i), i * 0.32, 0.45)
	s["morning"] = _wav(morning)
	return s


## Pad note: two slightly detuned voices of a warm wavetable, slow attack/release, gentle swell.
static func _pad_note(midi: int, dur: float) -> AudioStreamWAV:
	var table := PackedFloat32Array()
	var size := 2048
	table.resize(size)
	for i in size:
		var v := 0.0
		for k in range(1, 12):
			v += sin(TAU * k * i / size) / k * exp(-k / 3.2)
		table[i] = v
	var b := PackedFloat32Array()
	b.resize(int(dur * PAD_RATE))
	var f := _hz(midi)
	var inc1 := f * size / PAD_RATE * 1.0025
	var inc2 := f * size / PAD_RATE * 0.9975
	var p1 := 0.0
	var p2 := float(size) * 0.37
	var n := b.size()
	var attack := 2.8 * PAD_RATE
	var release := 4.5 * PAD_RATE
	for i in n:
		p1 = fmod(p1 + inc1, size)
		p2 = fmod(p2 + inc2, size)
		var v := table[int(p1)] + table[int(p2)]
		var e := minf(1.0, i / attack) * minf(1.0, (n - i) / release)
		var swell := 0.85 + 0.15 * sin(TAU * 0.11 * i / PAD_RATE + midi)
		b[i] = v * e * e * swell * 0.12
	return _wav(b, PAD_RATE)


func _build_music() -> Dictionary:
	var pads := {}
	for mood in CHORDS:
		for chord in CHORDS[mood]:
			for n in chord:
				if not pads.has(n):
					pads[n] = _pad_note(n, 12.0)
	var piano := {}
	for n in PIANO_NOTES:
		piano[n] = _wav(_piano_tone(n, 3.2, 0.55, n))
	# Room tone: brown-ish noise with a faint mains hum.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var room := PackedFloat32Array()
	room.resize(PAD_RATE * 8)
	var l := 0.0
	for i in room.size():
		l += 0.03 * (rng.randf_range(-1.0, 1.0) - l)
		room[i] = l * 0.9 + sin(TAU * 60.0 * i / PAD_RATE) * 0.006
	for i in 800:
		var k := float(i) / 800.0
		room[i] *= k
		room[room.size() - 1 - i] *= k
	# Distant typing: a colleague somewhere in the office.
	var typing := _buf(3.2)
	var t := 0.1
	var seed := 300
	while t < 2.9:
		_mix(typing, _key(seed, 170.0 + (seed % 5) * 12.0, rng.randf() < 0.12), t, 0.35)
		t += rng.randf_range(0.06, 0.2) if rng.randf() > 0.15 else rng.randf_range(0.3, 0.6)
		seed += 1
	var cup := _buf(1.0)
	_mix(cup, _bell(3520.0, 0.8, 2.76, 1.4, 0.12), 0.0, 1.0)
	_mix(cup, _bell(4186.0, 0.6, 2.76, 1.0, 0.08), 0.05, 1.0)
	return {"pads": pads, "piano": piano, "room": _wav(room, PAD_RATE, true), "typing": _wav(typing), "cup": _wav(cup)}
