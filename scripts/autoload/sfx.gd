extends Node
## Procedural audio: every sound effect and the lo-fi music loop are synthesized at startup,
## so the game ships without audio files. Reacts to game events by itself.

const RATE := 22050
const SETTINGS_PATH := "user://audio.json"

var music_volume := 0.55
var sfx_volume := 0.8
var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _next := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_load_settings()
	_setup_buses()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Music"
	_ambience.volume_db = -14
	add_child(_ambience)
	_build_sfx()
	apply_volumes()
	# The music loop takes a moment to synthesize; do it off the main thread.
	var t := Thread.new()
	t.start(_build_music)
	while t.is_alive():
		await get_tree().process_frame
	var loops: Dictionary = t.wait_to_finish()
	_music.stream = loops["music"]
	_ambience.stream = loops["room"]
	_connect_game()


func start_music() -> void:
	if _music.stream and not _music.playing:
		_music.volume_db = -40
		_music.play()
		create_tween().tween_property(_music, "volume_db", 0.0, 3.0)
	if _ambience.stream and not _ambience.playing:
		_ambience.play()


func fade_music(to_db: float, sec := 1.0) -> void:
	create_tween().tween_property(_music, "volume_db", to_db, sec)


# --- Settings ----------------------------------------------------------------------

func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if typeof(d) == TYPE_DICTIONARY:
			music_volume = float(d.get("music", music_volume))
			sfx_volume = float(d.get("sfx", sfx_volume))


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"music": music_volume, "sfx": sfx_volume}))
	f.close()


func _setup_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var music := AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(music) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 9000
		AudioServer.add_bus_effect(music, lp)


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx_volume, 0.0001)))


## Muffles the music (e.g. while the monitor is off at night).
func muffle(on: bool) -> void:
	var lp := AudioServer.get_bus_effect(AudioServer.get_bus_index("Music"), 0) as AudioEffectLowPassFilter
	if lp:
		create_tween().tween_method(func(v: float) -> void: lp.cutoff_hz = v, lp.cutoff_hz, 700.0 if on else 9000.0, 0.8)


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


func type_key() -> void:
	play("type", _rng.randf_range(0.9, 1.15), -6.0)


func footsteps(count := 5, interval := 0.42) -> void:
	for i in count:
		play("step", _rng.randf_range(0.92, 1.05), -16.0 + i * 3.0)
		await get_tree().create_timer(interval).timeout


# --- Wiring -------------------------------------------------------------------------

func _connect_game() -> void:
	Game.toast.connect(func(app: String, _t: String, _b: String) -> void:
		play("pop" if app in ["chat", "browser"] else "ding", 1.0, -3.0))
	Game.relation_changed.connect(func(_n: String, _k: String, d: int) -> void:
		play("up" if d > 0 else "down", 1.0, -8.0 if d > 0 else -4.0))
	Game.event.connect(_on_event)
	Game.day_finished.connect(func(_d: int) -> void: play("evening"))


func _on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"ci":
			var pr := CodeHub.get_pr(int(d["pr"]))
			if pr.get("author", "") == "me":
				play("success" if d["ok"] else "fail")
		"pr_merged":
			play("fanfare")
		"tests":
			play("tick" if d.get("ok", false) else "buzz", 1.0, -6.0)
		"purchase":
			play("coin")
		"caught":
			play("busted")
		"git_pushed":
			play("whoosh", 1.2, -4.0)
		"git_committed":
			play("tick", 1.3, -8.0)


# --- Synthesis -----------------------------------------------------------------------

static func _note(n: int) -> float:
	return 440.0 * pow(2.0, (n - 69) / 12.0)


## Builds a 16-bit mono stream from float samples in -1..1.
static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


static func _env(t: float, dur: float, attack: float, release: float) -> float:
	if t < attack:
		return t / attack
	if t > dur - release:
		return maxf(0.0, (dur - t) / release)
	return 1.0


## Notes: [[midi, start_sec, length_sec], ...] with a plucked envelope.
func _seq(notes: Array, wave := "tri", gain := 0.35, decay := 6.0) -> AudioStreamWAV:
	var total := 0.0
	for n in notes:
		total = maxf(total, n[1] + n[2])
	var buf := PackedFloat32Array()
	buf.resize(int((total + 0.05) * RATE))
	for n in notes:
		var f := _note(n[0])
		var s0 := int(n[1] * RATE)
		var len_s := int(n[2] * RATE)
		for i in len_s:
			var t := float(i) / RATE
			var ph := fmod(t * f, 1.0)
			var v := 0.0
			match wave:
				"sine":
					v = sin(TAU * ph)
				"square":
					v = 0.5 if ph < 0.5 else -0.5
				_:
					v = 4.0 * absf(ph - 0.5) - 1.0
			var e := exp(-t * decay) * minf(1.0, t * 400.0)
			if s0 + i < buf.size():
				buf[s0 + i] += v * e * gain
	return _wav(buf)


func _sweep(f0: float, f1: float, dur: float, gain := 0.4, wave := "sine") -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	buf.resize(int(dur * RATE))
	var ph := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / dur)
		ph = fmod(ph + f / RATE, 1.0)
		var v := sin(TAU * ph) if wave == "sine" else (0.6 if ph < 0.5 else -0.6)
		buf[i] = v * gain * _env(t, dur, 0.005, dur * 0.6)
	return _wav(buf)


func _noise(dur: float, gain: float, cutoff: float, decay: float, tone := 0.0) -> AudioStreamWAV:
	var buf := PackedFloat32Array()
	buf.resize(int(dur * RATE))
	var lp := 0.0
	var a := clampf(cutoff / RATE * TAU, 0.0, 1.0)
	for i in buf.size():
		var t := float(i) / RATE
		lp += a * (_rng.randf_range(-1.0, 1.0) - lp)
		var v := lp
		if tone > 0.0:
			v = v * 0.5 + sin(TAU * tone * t) * 0.8
		buf[i] = v * gain * exp(-t * decay) * minf(1.0, t * 2000.0)
	return _wav(buf)


func _build_sfx() -> void:
	_rng.seed = 42
	_streams["click"] = _noise(0.03, 0.5, 6000, 120, 1800)
	_streams["type"] = [_noise(0.035, 0.7, 3500, 90), _noise(0.03, 0.6, 5000, 110), _noise(0.04, 0.7, 2500, 80, 420), _noise(0.03, 0.6, 4200, 100, 600)]
	_streams["pop"] = _sweep(520, 880, 0.09, 0.45)
	_streams["ding"] = _seq([[88, 0.0, 0.5], [95, 0.06, 0.6]], "sine", 0.3, 5.0)
	_streams["tick"] = _seq([[84, 0.0, 0.12]], "sine", 0.3, 25.0)
	_streams["buzz"] = _seq([[52, 0.0, 0.18], [51, 0.1, 0.2]], "square", 0.22, 10.0)
	_streams["success"] = _seq([[72, 0.0, 0.3], [76, 0.08, 0.3], [79, 0.16, 0.3], [84, 0.24, 0.6]], "tri", 0.35, 4.5)
	_streams["fail"] = _seq([[55, 0.0, 0.3], [54, 0.14, 0.3], [49, 0.28, 0.55]], "square", 0.2, 5.0)
	_streams["fanfare"] = _seq([[67, 0.0, 0.2], [72, 0.12, 0.2], [76, 0.24, 0.2], [79, 0.36, 0.9], [72, 0.36, 0.9], [76, 0.36, 0.9], [84, 0.5, 0.9]], "tri", 0.26, 2.8)
	_streams["up"] = _sweep(700, 1050, 0.12, 0.25)
	_streams["down"] = _sweep(480, 300, 0.2, 0.3, "square")
	_streams["whoosh"] = _noise(0.28, 0.5, 1800, 9)
	_streams["step"] = _noise(0.12, 0.9, 400, 30, 70)
	_streams["heart"] = _seq([[31, 0.0, 0.15], [31, 0.22, 0.15]], "sine", 0.9, 14.0)
	_streams["busted"] = _seq([[64, 0.0, 0.25], [63, 0.2, 0.25], [62, 0.4, 0.25], [61, 0.6, 0.7]], "square", 0.18, 3.0)
	_streams["relief"] = _sweep(400, 620, 0.5, 0.2)
	_streams["coin"] = _seq([[83, 0.0, 0.1], [88, 0.07, 0.4]], "square", 0.15, 7.0)
	_streams["boot"] = _seq([[48, 0.0, 2.0], [55, 0.05, 2.0], [64, 0.1, 2.0], [67, 0.15, 2.0], [72, 0.2, 2.0]], "sine", 0.18, 1.4)
	_streams["power"] = _noise(0.25, 0.4, 600, 12, 55)
	_streams["window"] = _noise(0.12, 0.25, 2600, 26)
	_streams["evening"] = _seq([[76, 0.0, 0.6], [72, 0.25, 0.6], [67, 0.5, 0.6], [60, 0.75, 1.2]], "sine", 0.25, 2.2)
	_streams["morning"] = _seq([[60, 0.0, 0.5], [64, 0.18, 0.5], [67, 0.36, 0.5], [72, 0.54, 1.0], [76, 0.72, 1.2]], "sine", 0.22, 2.0)
	_streams["promote"] = _seq([[60, 0.0, 0.25], [64, 0.15, 0.25], [67, 0.3, 0.25], [72, 0.45, 0.4], [67, 0.75, 0.2], [72, 0.9, 1.4], [76, 0.9, 1.4], [79, 0.9, 1.4]], "tri", 0.25, 1.8)


## Lo-fi loop: Fmaj7 → Em7 → Dm7 → Cmaj7, soft keys, bass, brushed hats, vinyl crackle.
## Plus a separate room-tone loop (air conditioning hum).
func _build_music() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var bpm := 72.0
	var beat := 60.0 / bpm
	var chords := [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59]]
	var bar := beat * 4.0
	var total := bar * chords.size()
	var n := int(total * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var ci := int(t / bar) % chords.size()
		var tb := fmod(t, bar)
		var chord: Array = chords[ci]
		var v := 0.0
		# keys: chord stabs on beats 1 and 2.5, soft decay
		for hit in [0.0, beat * 1.5, beat * 3.0]:
			var dt: float = tb - hit
			if dt >= 0.0 and dt < beat * 1.6:
				var e := exp(-dt * 1.6) * minf(1.0, dt * 60.0)
				for note in chord:
					var f := _note(note + 12)
					v += (sin(TAU * f * t) + 0.25 * sin(TAU * f * 2.0 * t)) * e * 0.045
		# bass: root on beat 1 and 3
		var bt := fmod(tb, beat * 2.0)
		v += sin(TAU * _note(chord[0] - 12) * t) * exp(-bt * 2.5) * 0.16
		# brushed hats on 8ths, kick-ish thump on 1 and 3
		var ht := fmod(t, beat / 2.0)
		lp += 0.35 * (rng.randf_range(-1.0, 1.0) - lp)
		v += (rng.randf_range(-1.0, 1.0) - lp) * exp(-ht * 60.0) * 0.035
		v += sin(TAU * 55.0 * bt * (1.0 - bt)) * exp(-bt * 18.0) * 0.22
		# vinyl crackle
		if rng.randf() < 0.0006:
			v += rng.randf_range(-0.25, 0.25)
		v += rng.randf_range(-1.0, 1.0) * 0.004
		buf[i] = v * 0.8
	# smooth the loop seam
	for i in 400:
		var k := float(i) / 400.0
		buf[i] *= k
		buf[n - 1 - i] *= k
	var room := PackedFloat32Array()
	room.resize(RATE * 6)
	var l2 := 0.0
	for i in room.size():
		l2 += 0.02 * (rng.randf_range(-1.0, 1.0) - l2)
		room[i] = l2 * 1.4 + sin(TAU * 60.0 * i / RATE) * 0.01
	for i in 600:
		var k := float(i) / 600.0
		room[i] *= k
		room[room.size() - 1 - i] *= k
	return {"music": _wav(buf, true), "room": _wav(room, true)}
