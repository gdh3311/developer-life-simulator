extends Node
## Global game state: language, clock (hybrid turn-based), team relationships, chat, issues,
## money, condition and stats. Everything that happens is broadcast through `event`.
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
signal wallet_changed
signal condition_changed

const DAY_NAMES := ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
const DAY_START := 9 * 60
const SAVE_PATH := "user://sandbox/save.json"
const SETTINGS_PATH := "user://settings.json"
const SaveStore := preload("res://scripts/services/save_store.gd")
const Chapters := preload("res://scripts/story/chapters.gd")

const NPCS := {
	"alex": {"name": "Alex Kim", "role": {"ko": "프로덕트 매니저", "en": "Product Manager"}, "color": "f5a524"},
	"daniel": {"name": "Daniel Park", "role": {"ko": "시니어 백엔드 엔지니어", "en": "Senior Backend Engineer"}, "color": "4f8cff"},
	"mina": {"name": "Mina Choi", "role": {"ko": "QA 엔지니어", "en": "QA Engineer"}, "color": "3ddc84"},
	"sophie": {"name": "Sophie Lee", "role": {"ko": "주니어 프론트엔드 개발자", "en": "Junior Frontend Developer"}, "color": "ff6b8a"},
	"ai": {"name": "AICode", "role": {"ko": "AI 코딩 에이전트", "en": "AI coding agent"}, "color": "c86bfa"},
	"system": {"name": "NEXORA", "role": {"ko": "시스템", "en": "System"}, "color": "9aa4b5"},
	"yuri": {"name": "Yuri Han", "role": {"ko": "고객 성공 매니저", "en": "Customer Success Manager"}, "color": "2dd4bf"},
	"family": {"name": {"ko": "엄마", "en": "Mom"}, "role": {"ko": "가족", "en": "Family"}, "color": "fda4af"},
	"taeseok": {"name": "Taeseok Kang", "role": {"ko": "보안·감사 엔지니어", "en": "Security & Audit Engineer"}, "color": "94a3b8"},
	"hana": {"name": "Hana Yoon", "role": {"ko": "전 결제팀 개발자", "en": "Former Payments Engineer"}, "color": "f0abfc"},
	"recruiter": {"name": "Jamie Seo", "role": {"ko": "테크 리크루터 · Brightloop", "en": "Tech Recruiter · Brightloop"}, "color": "38bdf8"},
}
const REL_KEYS := {"tech": {"ko": "기술 신뢰", "en": "Tech trust"}, "work": {"ko": "업무 신뢰", "en": "Work trust"},
	"close": {"ko": "친밀도", "en": "Closeness"}, "agree": {"ko": "의견 일치", "en": "Alignment"}}
const RANKS := [{"ko": "인턴", "en": "Intern"}, {"ko": "주니어 개발자", "en": "Junior Developer"},
	{"ko": "주니어 개발자 II", "en": "Junior Developer II"}, {"ko": "미드레벨 개발자", "en": "Mid-level Developer"}]
const SALARY := [80000, 120000, 140000, 170000]

var lang := "ko"
var state := {}
var _save_pending := false
var last_load_error := ""
var last_load_recovered := false


func _ready() -> void:
	_load_settings()
	reset_state()
	Workspace.git_event.connect(func(kind: String, detail: String) -> void:
		emit_event("git_" + kind, {"branch": detail}))
	Workspace.tests_finished.connect(func(r: Dictionary) -> void:
		inc_stat("test_runs")
		advance(5)
		emit_event("tests", {"ok": r.get("ok", false), "passed": r.get("passed", 0), "failed": r.get("failed", 0)}))


func reset_state() -> void:
	state = _default_state()


func _default_state() -> Dictionary:
	return {
		"save_version": SaveStore.VERSION,
		"workspace_checkpoint": {},
		"request_lab": {"opened": false, "evidence": false, "plan": [], "runs": [], "latest": {}},
		"day": 1, "minutes": DAY_START, "rank": 0, "day_done": false,
		"player_name": "New Hire", "repo_lang": lang,
		"money": 50000, "condition": 85, "owned": {},
		"salary_days": {},
		"rel": {
			"alex": {"tech": 20, "work": 25, "close": 15, "agree": 35},
			"daniel": {"tech": 10, "work": 15, "close": 5, "agree": 30},
			"mina": {"tech": 20, "work": 20, "close": 15, "agree": 35},
			"sophie": {"tech": 20, "work": 20, "close": 25, "agree": 35},
		},
		"rel_today": {},
		"chat": [], "next_msg": 1, "unread": {},
		"issues": [],
		"stats": {}, "stats_today": {},
		"story": {}, "side": {}, "arcs": {}, "events": {},
		"investigations": {},
		"codehub": {"prs": [], "next_id": 1},
		"monitor": {"status": {"api": "ok", "auth": "ok", "payments": "ok"}, "mode": "normal"},
		"connectly": {"inbox": [], "endorsements": {}},
		"flags": {},
	}


# --- Language -----------------------------------------------------------------------

func _load_settings() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH)) if FileAccess.file_exists(SETTINGS_PATH) else null
	if typeof(data) == TYPE_DICTIONARY:
		lang = String(data.get("lang", "ko"))
		walkby_enabled = bool(data.get("walkby", true))


func has_settings() -> bool:
	return FileAccess.file_exists(SETTINGS_PATH)


func set_language(l: String) -> void:
	lang = l
	_store_settings()


## Accessibility: the "boss walks by while you're slacking" event can be turned off.
var walkby_enabled := true
## Event cards (scripts/story/events.gd). Off inside the isolated QA projects so scripted checks
## stay deterministic; the events suite turns it back on.
var events_enabled := not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-")


func set_walkby(on: bool) -> void:
	walkby_enabled = on
	_store_settings()


func _store_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"lang": lang, "walkby": walkby_enabled}))
	f.close()


## Immediate string in the current language.
func L(ko: String, en: String) -> String:
	return en if lang == "en" else ko


## Bilingual text to store (chat, PR comments, issues...). Rendered later with tx().
func LL(ko: String, en: String) -> Dictionary:
	return {"ko": ko, "en": en}


## Renders stored text (Dictionary {ko,en} or plain String).
func tx(v) -> String:
	if typeof(v) == TYPE_DICTIONARY:
		return String(v.get(lang, v.get("ko", "")))
	return str(v)


func pname() -> String:
	return String(state.get("player_name", "New Hire"))


# --- Persistence ---------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_PATH + ".bak")


func load_game() -> bool:
	var loaded := SaveStore.read(SAVE_PATH, _default_state())
	last_load_error = loaded.get("error", "")
	last_load_recovered = loaded.get("recovered", false)
	if not loaded["ok"]:
		return false
	state = loaded["data"]
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
	if Workspace.is_ready and not Workspace._snap.is_empty():
		state["workspace_checkpoint"] = {"head": Workspace._snap["head"], "branch": Workspace._snap["branch"], "remote_main": Workspace._snap["remote"].get("main", "")}
	if not SaveStore.write(SAVE_PATH, state, _default_state()):
		notify("dashboard", L("저장하지 못했습니다", "Could not save"), L("이전 저장은 유지됩니다. 저장 공간과 파일 권한을 확인해 주세요.", "The previous save is retained. Check free space and file permissions."))


func new_game() -> bool:
	if Workspace.active_jobs > 0 or Workspace._bot_busy or Workspace._ci_busy:
		notify("dashboard", L("작업을 마치는 중입니다", "Work is still finishing"), L("Git 또는 테스트가 끝난 뒤 다시 시작해 주세요.", "Wait for Git or tests to finish, then try again."))
		return false
	reset_state()
	Workspace.wipe()
	state_reset.emit()
	return true


# --- Events & time ----------------------------------------------------------------

func emit_event(kind: String, data := {}) -> void:
	event.emit(kind, data)
	save_soon()


func day() -> int:
	return state["day"]


func minutes() -> int:
	return state["minutes"]


## Advance game time after a meaningful action (GDD 7.1). Work drains condition;
## when exhausted, everything takes longer.
func advance(mins: int) -> void:
	if condition() < 25:
		mins = roundi(mins * 1.5)
	state["minutes"] = minutes() + mins
	change_condition(-mins / 8.0 * (0.7 if state["owned"].has("headphones") else 1.0))
	time_changed.emit(day(), minutes())
	save_soon()


func set_time(mins: int) -> void:
	if mins > minutes():
		state["minutes"] = mins
		time_changed.emit(day(), minutes())


func clock_text() -> String:
	return "%s %02d:%02d" % [DAY_NAMES[Chapters.weekday(day())], floori(minutes() / 60.0), minutes() % 60]


func chapter() -> int:
	return Chapters.for_day(day())


func date_text() -> String:
	return "%s · %s" % [tx(Chapters.DATA[chapter()]["period"]), DAY_NAMES[Chapters.weekday(day())]]


func time_text() -> String:
	return "%02d:%02d" % [floori(minutes() / 60.0), minutes() % 60]


func finish_day() -> void:
	if state["day_done"]:
		return
	state["day_done"] = true
	save_soon()
	day_finished.emit(day())


func next_day() -> void:
	if not state["day_done"]:
		return
	var info: Dictionary = Chapters.DATA[chapter()]
	if day() >= int(info["last_day"]) and not Chapters.DATA.has(chapter() + 1):
		return
	claim_salary()
	state["day"] = day() + 1
	state["minutes"] = DAY_START
	state["day_done"] = false
	state["rel_today"] = {}
	state["stats_today"] = {}
	state["condition"] = 85
	condition_changed.emit()
	time_changed.emit(day(), minutes())
	save_soon()


func claim_salary() -> bool:
	var key := str(day())
	if not state["day_done"] or state["salary_days"].has(key):
		return false
	state["salary_days"][key] = true
	earn(SALARY[clampi(state["rank"], 0, SALARY.size() - 1)])
	return true


func rank_name() -> String:
	return tx(RANKS[clampi(state["rank"], 0, RANKS.size() - 1)])


# --- Condition & money -------------------------------------------------------------

func condition() -> int:
	return int(state["condition"])


func change_condition(delta: float) -> void:
	var before := condition()
	state["condition"] = clampi(roundi(state["condition"] + delta), 0, 100)
	if condition() != before:
		condition_changed.emit()
	if before >= 25 and condition() < 25:
		notify("dashboard", L("컨디션 저하", "Running on empty"), L("너무 지쳤어요. 잠깐 쉬지 않으면 모든 작업이 느려집니다. (포털에서 커피 한잔?)",
			"You're exhausted. Everything takes longer until you take a break. (Coffee from the portal?)"))


func money() -> int:
	return int(state["money"])


func earn(amount: int) -> void:
	state["money"] = money() + amount
	wallet_changed.emit()
	save_soon()


func spend(amount: int) -> bool:
	if money() < amount:
		return false
	state["money"] = money() - amount
	wallet_changed.emit()
	save_soon()
	return true


func won(amount: int) -> String:
	var s := str(absi(amount))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if amount < 0 else "") + s + out + L("원", " KRW")


# --- Team ------------------------------------------------------------------------

## Average of every teammate's trust values (0-100).
func avg_trust() -> float:
	var total := 0
	var count := 0
	for npc in state["rel"]:
		for key in REL_KEYS:
			total += rel(npc, key)
			count += 1
	return float(total) / maxi(count, 1)


func rel(npc: String, key: String) -> int:
	return int(state["rel"][npc][key])


## changes: { "tech": +5, "close": -3, ... }
## Trust is earned slowly (diminishing gains) and lost fast (mistakes hit 1.6x).
func relate(npc: String, changes: Dictionary) -> void:
	for key in changes:
		var delta := int(changes[key])
		var cur := rel(npc, key)
		var eff: int
		if delta > 0:
			eff = maxi(1, roundi(delta * 0.6 * (1.0 - cur / 140.0)))
		else:
			eff = floori(delta * 1.6)
		state["rel"][npc][key] = clampi(cur + eff, 0, 100)
		var today: Dictionary = state["rel_today"]
		if not today.has(npc):
			today[npc] = {}
		today[npc][key] = int(today[npc].get(key, 0)) + eff
		relation_changed.emit(npc, key, eff)
	save_soon()


func rel_label(key: String) -> String:
	return tx(REL_KEYS[key])


func npc_name(id: String) -> String:
	if id == "me":
		return pname()
	return tx(NPCS[id]["name"]) if NPCS.has(id) else pname()


func npc_role(id: String) -> String:
	return tx(NPCS[id]["role"]) if NPCS.has(id) else ""


func npc_color(id: String) -> Color:
	return Color(NPCS[id]["color"]) if NPCS.has(id) else Color("5b8cff")


# --- Chat ------------------------------------------------------------------------

## Posts a chat message. text: String or {ko, en}.
## opts: { channel, choices: [{id, label}], key, silent }
func say(from: String, text, opts := {}) -> Dictionary:
	var channel: String = opts.get("channel", "general" if from in ["system"] else "dm:" + from)
	var msg := {
		"id": state["next_msg"], "from": from, "text": text, "time": time_text(),
		"channel": channel, "choices": opts.get("choices", []), "key": opts.get("key", ""), "answered": "",
	}
	state["next_msg"] = int(state["next_msg"]) + 1
	state["chat"].append(msg)
	state["unread"][channel] = int(state["unread"].get(channel, 0)) + 1
	chat_added.emit(msg)
	if not opts.get("silent", false):
		toast.emit("browser" if channel == "connectly" else "chat", npc_name(from), tx(text))
	save_soon()
	return msg


## The player's own message in a channel.
func say_mine(channel: String, text) -> void:
	var msg := {"id": state["next_msg"], "from": "me", "text": text, "time": time_text(),
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


func pending_choice(key: String) -> bool:
	for m in state["chat"]:
		if m["key"] == key and m["answered"] == "":
			return true
	return false


func mark_read(channel: String) -> void:
	if int(state["unread"].get(channel, 0)) == 0:
		return
	state["unread"][channel] = 0
	chat_updated.emit()


# --- Issues ----------------------------------------------------------------------

func add_issue(id: String, title, kind: String, owner: String, status := "todo") -> void:
	for i in state["issues"]:
		if i["id"] == id:
			return
	state["issues"].append({"id": id, "title": title, "kind": kind, "owner": owner, "status": status})
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
