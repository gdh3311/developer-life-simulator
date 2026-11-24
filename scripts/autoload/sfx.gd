extends Node
## Mixes the office score, room tone and interaction sounds on separate volume buses.

const SETTINGS_PATH := "user://audio.json"
const SILENT_DB := -80.0
const SCORE := {
	"focus": "res://audio/focus.ogg",
	"incident": "res://audio/incident.ogg",
	"calm": "res://audio/calm.ogg",
}
const ROOM := "res://audio/office.ogg"
const CLIPS := {
	"type": [
		"res://audio/key_1.wav", "res://audio/key_2.wav", "res://audio/key_3.wav",
		"res://audio/key_4.wav", "res://audio/key_5.wav", "res://audio/key_6.wav",
	],
	"type_heavy": ["res://audio/key_7.wav", "res://audio/key_8.wav"],
	"step": ["res://audio/step_1.wav", "res://audio/step_2.wav", "res://audio/step_3.wav"],
	"tick": "res://audio/tick.wav",
	"click": "res://audio/click.wav",
	"window": "res://audio/window.wav",
	"send": "res://audio/send.wav",
	"commit": "res://audio/commit.wav",
	"push": "res://audio/push.wav",
	"power": "res://audio/power.wav",
	"relief": "res://audio/relief.wav",
	"message": "res://audio/message.wav",
	"notify": "res://audio/notify.wav",
	"tests_ok": "res://audio/tests_ok.wav",
	"tests_fail": "res://audio/tests_fail.wav",
	"success": "res://audio/success.wav",
	"fail": "res://audio/fail.wav",
	"merged": "res://audio/merged.wav",
	"promote": "res://audio/promote.wav",
	"purchase": "res://audio/purchase.wav",
	"boot": "res://audio/boot.wav",
	"morning": "res://audio/morning.wav",
	"evening": "res://audio/evening.wav",
	"busted": "res://audio/busted.wav",
	"heart": "res://audio/heart.wav",
}
const FEATURED := ["tests_ok", "tests_fail", "success", "fail", "merged", "promote", "busted"]

var music_volume := 0.5
var sfx_volume := 0.7
var ambience_volume := 0.55

var _clips := {}
var _players: Array[AudioStreamPlayer] = []
var _score_players: Dictionary[String, AudioStreamPlayer] = {}
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _featured: AudioStreamPlayer
var _last_featured := -4000
var _last_toast := -4000
var _next := 0
var _music_on := false
var _mood := ""
var _score_fade: Tween
var _room_fade: Tween
var _music_filter: AudioEffectLowPassFilter
var _ambience_filter: AudioEffectLowPassFilter
var _rng := RandomNumberGenerator.new()
var _steps_generation := 0


func _ready() -> void:
	set_process(false)
	_rng.randomize()
	_load_settings()
	_setup_buses()
	for i in 10:
		_players.append(_player("SFX"))
	_featured = _player("SFX")
	for id in CLIPS:
		var entry = CLIPS[id]
		if entry is Array:
			_clips[id] = entry.map(func(path: String) -> AudioStream: return load(path))
		else:
			_clips[id] = load(entry)
	for mood in SCORE:
		var player := _player("Music")
		player.stream = _loop(load(SCORE[mood]))
		player.volume_db = SILENT_DB
		_score_players[mood] = player
	_music = _score_players["focus"]
	_ambience = _player("Ambience")
	_ambience.stream = _loop(load(ROOM))
	apply_volumes()

	Game.toast.connect(_on_toast)
	Game.event.connect(_on_event)
	Game.day_finished.connect(func(_day: int) -> void: play("evening"))
	get_tree().node_added.connect(_attach_button_sound)


func _attach_button_sound(node: Node) -> void:
	if node is BaseButton:
		var click := play.bind("click")
		if not node.button_down.is_connected(click):
			node.button_down.connect(click)


func _player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


func _loop(source: AudioStreamOggVorbis) -> AudioStreamOggVorbis:
	var stream := source.duplicate() as AudioStreamOggVorbis
	stream.loop = true
	return stream


func start_music() -> void:
	if _music_on:
		return
	_music_on = true
	_mood = ""
	# All arrangements share the loop length, so transitions enter on the same harmony.
	for player in _score_players.values():
		player.volume_db = SILENT_DB
		player.play()
	_ambience.play()
	_change_score(_current_mood(), 1.6)
	set_process(true)


func stop_all() -> void:
	_music_on = false
	_steps_generation += 1
	set_process(false)
	if _score_fade:
		_score_fade.kill()
	if _room_fade:
		_room_fade.kill()
	for player in _players:
		player.stop()
	for player in _score_players.values():
		player.stop()
	_featured.stop()
	_ambience.stop()


func _exit_tree() -> void:
	stop_all()
	for player in _players:
		player.stream = null
	for player in _score_players.values():
		player.stream = null
	_featured.stream = null
	_ambience.stream = null
	_clips.clear()


func _process(_delta: float) -> void:
	var mood := _current_mood()
	if mood != _mood:
		_change_score(mood, 3.0)


func _current_mood() -> String:
	if Game.state.get("day_done", false):
		return "calm"
	if Game.state.get("monitor", {}).get("status", {}).values().has("down"):
		return "incident"
	return "focus"


func _change_score(mood: String, duration: float) -> void:
	_mood = mood
	if _score_fade:
		_score_fade.kill()
	_score_fade = create_tween().set_parallel()
	for arrangement in _score_players:
		var player := _score_players[arrangement]
		var target := 1.0 if arrangement == mood else 0.0
		_score_fade.tween_method(_set_score_gain.bind(player), db_to_linear(player.volume_db), target, duration).set_trans(Tween.TRANS_SINE)


func _set_score_gain(gain: float, player: AudioStreamPlayer) -> void:
	player.volume_db = linear_to_db(maxf(gain, db_to_linear(SILENT_DB)))


## The closed monitor softens the score and the desk ambience during the night transition.
func muffle(on: bool) -> void:
	if _room_fade:
		_room_fade.kill()
	_room_fade = create_tween().set_parallel()
	_room_fade.tween_property(_music_filter, "cutoff_hz", 900.0 if on else 15000.0, 1.2)
	_room_fade.tween_property(_ambience_filter, "cutoff_hz", 560.0 if on else 8000.0, 1.2)
	_room_fade.tween_property(_ambience, "volume_db", -6.0 if on else 0.0, 1.2)


func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if data is Dictionary:
			music_volume = _saved_level(data.get("music"), music_volume)
			sfx_volume = _saved_level(data.get("sfx"), sfx_volume)
			ambience_volume = _saved_level(data.get("ambience"), ambience_volume)


func _saved_level(value, fallback: float) -> float:
	if value is float or value is int:
		return clampf(value, 0.0, 1.0)
	return fallback


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"music": music_volume, "sfx": sfx_volume, "ambience": ambience_volume}))
		file.close()


func _setup_buses() -> void:
	for bus in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_music_filter = _low_pass("Music", 15000.0)
	_ambience_filter = _low_pass("Ambience", 8000.0)


func _low_pass(bus: String, frequency: float) -> AudioEffectLowPassFilter:
	var filter := AudioEffectLowPassFilter.new()
	filter.cutoff_hz = frequency
	AudioServer.add_bus_effect(AudioServer.get_bus_index(bus), filter)
	return filter


func apply_volumes() -> void:
	for pair in [["Music", music_volume], ["SFX", sfx_volume], ["Ambience", ambience_volume]]:
		var bus := AudioServer.get_bus_index(pair[0])
		var gain: float = pair[1]
		AudioServer.set_bus_mute(bus, gain <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(gain, db_to_linear(SILENT_DB))))


func play(id: String, pitch := 1.0, volume_db := 0.0) -> void:
	var clip = _clips.get(id)
	if clip == null:
		return
	var player: AudioStreamPlayer
	if id in FEATURED:
		player = _featured
		_last_featured = Time.get_ticks_msec()
	else:
		player = _players[_next]
		_next = (_next + 1) % _players.size()
	player.stream = clip[_rng.randi_range(0, clip.size() - 1)] if clip is Array else clip
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


func type_key(keycode: int) -> void:
	var heavy := keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_BACKSPACE]
	play("type_heavy" if heavy else "type", _rng.randf_range(0.97, 1.03))


func footsteps(count := 5, interval := 0.42) -> void:
	_steps_generation += 1
	var generation := _steps_generation
	for i in count:
		if generation != _steps_generation:
			return
		var position := float(i) / maxf(count - 1, 1)
		var proximity := sin(position * PI * 0.85)
		play("step", _rng.randf_range(0.97, 1.03), lerpf(-16.0, -1.0, proximity))
		await get_tree().create_timer(interval * _rng.randf_range(0.94, 1.06)).timeout


func _on_toast(app: String, _title: String, _body: String) -> void:
	# Outcome events can arrive in the same frame as their generic notification.
	_play_toast.call_deferred(app)


func _play_toast(app: String) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_featured < 1100 or now - _last_toast < 1000:
		return
	_last_toast = now
	play("message" if app in ["chat", "browser"] else "notify")


func _on_event(kind: String, detail: Dictionary) -> void:
	match kind:
		"ci":
			var pr := CodeHub.get_pr(int(detail["pr"]))
			if pr.get("author", "") == "me":
				play("success" if detail["ok"] else "fail")
		"pr_merged":
			if CodeHub.get_pr(int(detail["pr"])).get("author", "") == "me":
				play("merged")
		"tests":
			play("tests_ok" if detail.get("ok", false) else "tests_fail")
		"purchase":
			play("purchase")
		"caught":
			play("busted")
		"git_pushed":
			play("push")
		"git_committed":
			play("commit")
