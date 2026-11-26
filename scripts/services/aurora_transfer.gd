extends RefCounted
## Shared order samples and saved rehearsal state for the Aurora migration.

const ROUTE := "aurora"
const SAMPLES := [
	{"seller": "AUR-01", "nexora": "NX-41", "brightloop": "BL-713", "order": "ORD-104", "total": 32000, "refund": 2000},
	{"seller": "AUR-02", "nexora": "NX-52", "brightloop": "BL-805", "order": "ORD-104", "total": 7500, "refund": 0},
]
const INITIAL_ORDERS := ["AUR-01/ORD-104", "AUR-02/ORD-104"]
const BEFORE_SWITCH := "AUR-01/ORD-106"
const AFTER_SWITCH := "AUR-02/ORD-107"


static func moved() -> bool:
	var flags: Dictionary = Game.state["flags"]
	return flags.get("employer", "nexora") == "brightloop"


static func contact() -> String:
	return "raon" if moved() else "mina"


static func partner() -> String:
	return "sophie" if moved() else "raon"


static func new_run() -> Dictionary:
	return {"phase": "snapshot", "source": INITIAL_ORDERS + [BEFORE_SWITCH], "destination": INITIAL_ORDERS.duplicate()}


static func rehearsal() -> Dictionary:
	return Game.state["flags"].get("c06_rehearsal", {})


static func reconcile(first: String, second: String) -> bool:
	if Story.status("c06_03") != "active":
		return false
	if first != SAMPLES[0]["brightloop"] or second != SAMPLES[1]["brightloop"]:
		return false
	Game.emit_event("aurora_matched", {})
	return true


static func operate(action: String) -> bool:
	if Story.status("c06_05") != "active":
		return false
	var run := rehearsal().duplicate(true)
	if run.is_empty():
		run = new_run()
	match run["phase"]:
		"snapshot":
			if action not in ["replay_delta", "use_snapshot"]:
				return false
			if action == "replay_delta":
				run["destination"].append(BEFORE_SWITCH)
			run["phase"] = "switched"
		"switched":
			if action != "take_order":
				return false
			run["destination"].append(AFTER_SWITCH)
			run["phase"] = "rollback"
		"rollback":
			if action not in ["flush_then_restore", "restore"]:
				return false
			if action == "flush_then_restore":
				run["source"].append(AFTER_SWITCH)
			run["missing_at_switch"] = not run["destination"].has(BEFORE_SWITCH)
			run["missing_at_rollback"] = not run["source"].has(AFTER_SWITCH)
			run["phase"] = "verified"
		"verified":
			if action != "retry" or passed(run):
				return false
			run = new_run()
	Game.state["flags"]["c06_rehearsal"] = run
	Game.save_soon()
	if passed(run):
		Game.emit_event("aurora_rehearsed", {})
	return true


static func passed(run: Dictionary) -> bool:
	return run.get("phase") == "verified" and not run["missing_at_switch"] and not run["missing_at_rollback"]
