extends Node
## Global game state: clock (hybrid turn-based), team relationships, chat, issues, stats.
## Everything that happens is broadcast through `event` so the story can react.
## State is saved to the sandbox (user://sandbox/save.json) next to the real Git repos.

signal time_changed(day: int, minutes: int)
signal event(kind: String, data: Dictionary)
signal chat_added(msg: Dictionary)
signal chat_updated
signal toast(app_id: String, title: String, body: String)
signal issues_changed
signal relation_changed(npc: String, key: String, delta: int)
signal day_finished(day: int)
signal state_reset

const DAY_NAMES := ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
const DAY_START := 9 * 60
const SAVE_PATH := "user://sandbox/save.json"

const NPCS := {
	"alex": {"name": "Alex Kim", "role": "Product Manager", "color": "f5a524"},
	"daniel": {"name": "Daniel Park", "role": "Senior Backend Engineer", "color": "4f8cff"},
	"mina": {"name": "Mina Choi", "role": "QA Engineer", "color": "3ddc84"},
	"sophie": {"name": "Sophie Lee", "role": "Junior Frontend Developer", "color": "ff6b8a"},
	"ai": {"name": "AICode", "role": "AI 코딩 에이전트", "color": "c86bfa"},
	"system": {"name": "NEXORA", "role": "시스템", "color": "9aa4b5"},
}
const REL_KEYS := {"tech": "기술 신뢰", "work": "업무 신뢰", "close": "친밀도", "agree": "의견 일치"}
const RANKS := ["Intern", "Junior Developer", "Junior Developer II", "Mid-level Developer"]

var state := {}
var _save_pending := false


func _ready() -> void:
	reset_state()
	Workspace.git_event.connect(func(kind: String, detail: String) -> void:
		emit_event("git_" + kind, {"branch": detail}))
	Workspace.tests_finished.connect(func(r: Dictionary) -> void:
		inc_stat("test_runs")
		advance(5)
		emit_event("tests", {"ok": r.get("ok", false), "passed": r.get("passed", 0), "failed": r.get("failed", 0)}))


func reset_state() -> void:
	state = {
		"day": 1, "minutes": DAY_START, "rank": 1, "day_done": false,
		"rel": {
			"alex": {"tech": 40, "work": 50, "close": 40, "agree": 50},
			"daniel": {"tech": 30, "work": 40, "close": 20, "agree": 50},
			"mina": {"tech": 40, "work": 40, "close": 40, "agree": 50},
			"sophie": {"tech": 40, "work": 40, "close": 50, "agree": 50},
		},
		"rel_today": {},
		"chat": [], "next_msg": 1, "unread": {},
		"issues": [],
		"stats": {}, "stats_today": {},
		"story": {},
		"codehub": {"prs": [], "next_id": 1},
		"monitor": {"status": {"api": "ok", "auth": "ok", "payments": "ok"}, "mode": "normal"},
		"apps_opened": {},
		"flags": {},
	}


# --- Persistence ---------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	var text := FileAccess.get_file_as_string(SAVE_PATH)
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return false
	reset_state()
	for k in data:
		state[k] = data[k]
	# JSON numbers come back as floats.
	state["day"] = int(state["day"])
	state["minutes"] = int(state["minutes"])
	state["rank"] = int(state["rank"])
	time_changed.emit(day(), minutes())
	return true


func save_soon() -> void:
	if _save_pending:
		return
	_save_pending = true
	_save.call_deferred()


func _save() -> void:
	_save_pending = false
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://sandbox")):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state, "\t"))
		f.close()


func new_game() -> void:
	reset_state()
	Workspace.wipe()
	state_reset.emit()


# --- Events & time ----------------------------------------------------------------

func emit_event(kind: String, data := {}) -> void:
	event.emit(kind, data)
	save_soon()


func day() -> int:
	return state["day"]


func minutes() -> int:
	return state["minutes"]


## Advance game time after a meaningful action (see GDD 7.1).
func advance(mins: int) -> void:
	state["minutes"] = minutes() + mins
	time_changed.emit(day(), minutes())
	save_soon()


func set_time(mins: int) -> void:
	if mins > minutes():
		state["minutes"] = mins
		time_changed.emit(day(), minutes())


func clock_text() -> String:
	return "%s %02d:%02d" % [DAY_NAMES[(day() - 1) % 7], floori(minutes() / 60.0), minutes() % 60]


func finish_day() -> void:
	if state["day_done"]:
		return
	state["day_done"] = true
	save_soon()
	day_finished.emit(day())


func next_day() -> void:
	state["day"] = day() + 1
	state["minutes"] = DAY_START
	state["day_done"] = false
	state["rel_today"] = {}
	state["stats_today"] = {}
	time_changed.emit(day(), minutes())
	save_soon()


func rank_name() -> String:
	return RANKS[clampi(state["rank"], 0, RANKS.size() - 1)]


# --- Team ------------------------------------------------------------------------

func rel(npc: String, key: String) -> int:
	return int(state["rel"][npc][key])


## changes: { "tech": +5, "close": -3, ... }
func relate(npc: String, changes: Dictionary) -> void:
	for key in changes:
		var delta := int(changes[key])
		state["rel"][npc][key] = clampi(rel(npc, key) + delta, 0, 100)
		var today: Dictionary = state["rel_today"]
		if not today.has(npc):
			today[npc] = {}
		today[npc][key] = int(today[npc].get(key, 0)) + delta
		relation_changed.emit(npc, key, delta)
	save_soon()


func npc_name(id: String) -> String:
	return NPCS[id]["name"] if NPCS.has(id) else "나"


func npc_color(id: String) -> Color:
	return Color(NPCS[id]["color"]) if NPCS.has(id) else Color("9aa4b5")


# --- Chat ------------------------------------------------------------------------

## Posts a chat message. opts: { channel, choices: [{id, label}], key, silent }
func say(from: String, text: String, opts := {}) -> Dictionary:
	var channel: String = opts.get("channel", "general" if from in ["system"] else "dm:" + from)
	var msg := {
		"id": state["next_msg"], "from": from, "text": text, "time": clock_text().substr(4),
		"channel": channel, "choices": opts.get("choices", []), "key": opts.get("key", ""), "answered": "",
	}
	state["next_msg"] = int(state["next_msg"]) + 1
	state["chat"].append(msg)
	state["unread"][channel] = int(state["unread"].get(channel, 0)) + 1
	chat_added.emit(msg)
	if not opts.get("silent", false):
		toast.emit("chat", npc_name(from), text)
	save_soon()
	return msg


## The player's own message in a channel.
func say_mine(channel: String, text: String) -> void:
	var msg := {"id": state["next_msg"], "from": "me", "text": text, "time": clock_text().substr(4),
		"channel": channel, "choices": [], "key": "", "answered": ""}
	state["next_msg"] = int(state["next_msg"]) + 1
	state["chat"].append(msg)
	chat_added.emit(msg)


## Player picked a reply option for a message.
func answer(msg_id: int, choice_id: String) -> void:
	for m in state["chat"]:
		if int(m["id"]) == msg_id and m["answered"] == "":
			m["answered"] = choice_id
			for c in m["choices"]:
				if c["id"] == choice_id:
					say_mine(m["channel"], c["label"])
			chat_updated.emit()
			advance(5)
			emit_event("choice", {"key": m["key"], "option": choice_id})
			return


func mark_read(channel: String) -> void:
	state["unread"][channel] = 0
	chat_updated.emit()


# --- Issues ----------------------------------------------------------------------

func add_issue(id: String, title: String, kind: String, owner: String, status := "todo", body := "") -> void:
	for i in state["issues"]:
		if i["id"] == id:
			return
	state["issues"].append({"id": id, "title": title, "kind": kind, "owner": owner, "status": status, "body": body})
	issues_changed.emit()
	save_soon()


func set_issue(id: String, status: String) -> void:
	for i in state["issues"]:
		if i["id"] == id:
			i["status"] = status
	issues_changed.emit()
	save_soon()


# --- Stats -----------------------------------------------------------------------

func inc_stat(key: String, by := 1) -> void:
	state["stats"][key] = int(state["stats"].get(key, 0)) + by
	state["stats_today"][key] = int(state["stats_today"].get(key, 0)) + by


func stat(key: String) -> int:
	return int(state["stats"].get(key, 0))


func notify(app_id: String, title: String, body: String) -> void:
	toast.emit(app_id, title, body)
