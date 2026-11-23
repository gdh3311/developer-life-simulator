extends Node
## Runs a deterministic request experiment against the actual player TypeScript module.

signal changed
var busy := false
var _epoch := 0


func _ready() -> void:
	Game.state_reset.connect(func() -> void:
		_epoch += 1
		busy = false
		changed.emit())


func available() -> bool:
	return Game.chapter() == 2


func state() -> Dictionary:
	return Game.state["request_lab"]


func open_ticket() -> void:
	if not available():
		return
	state()["opened"] = true
	Game.emit_event("ticket_opened", {})


func inspect_records() -> void:
	if not available():
		return
	state()["evidence"] = true
	Game.emit_event("ticket_evidence", {"source": "records"})
	changed.emit()


func save_plan(fields: Array) -> bool:
	if not available() or not state()["evidence"] or not "request" in fields or not "retries" in fields:
		return false
	state()["plan"] = fields.duplicate()
	Game.emit_event("reproduction_plan", {"fields": fields.duplicate()})
	changed.emit()
	return true


func _error(ko: String, en: String) -> Dictionary:
	return {"ok": false, "error": Game.L(ko, en)}


func run_probe(options: Dictionary) -> Dictionary:
	if not available() or Game.state["day_done"] or busy:
		return _error("지금은 실험을 시작할 수 없습니다.", "An experiment cannot start right now.")
	if options.get("network", "") not in ["fast", "slow"] or typeof(options.get("retry")) != TYPE_BOOL or options.get("keys", "") not in ["same", "new"] or typeof(options.get("clicks")) not in [TYPE_INT, TYPE_FLOAT] or int(options.get("clicks", 0)) not in [1, 2] or options["clicks"] != floor(options["clicks"]) or options.get("version", "") not in ["reported", "current"] or options.get("timing", "sequential") not in ["sequential", "concurrent"]:
		return _error("실험 조건을 다시 선택해 주세요.", "Please select valid experiment conditions.")
	var config := options.duplicate()
	config["timing"] = String(options.get("timing", "sequential"))
	var module := Workspace.resolve("src/orders/request.ts")
	var directory := Workspace.root.path_join("lab")
	DirAccess.make_dir_recursive_absolute(directory)
	for pair in [["request_probe.mjs", "request_probe.mjs"], ["reported.ts", "request.ts"]]:
		var file := FileAccess.open(directory.path_join(pair[0]), FileAccess.WRITE)
		if file == null:
			return _error("실험 파일을 준비하지 못했습니다.", "Could not prepare the experiment files.")
		file.store_string(Workspace.content("c02/" + pair[1]))
		file.close()
	if config["version"] == "reported":
		module = directory.path_join("reported.ts")
	if module == "" or not FileAccess.file_exists(module):
		return _error("먼저 main을 pull해 request.ts를 받아 주세요.", "Pull main first to get request.ts.")
	var code_hash := FileAccess.get_file_as_string(module).sha256_text()
	var options_path := directory.path_join("options.json")
	var options_file := FileAccess.open(options_path, FileAccess.WRITE)
	if options_file == null:
		return _error("실험 조건을 저장하지 못했습니다.", "Could not save experiment conditions.")
	options_file.store_string(JSON.stringify(config))
	options_file.close()
	var epoch := _epoch
	busy = true
	changed.emit()
	var result := await Workspace.run("node", ["--experimental-strip-types", "--no-warnings", directory.path_join("request_probe.mjs"), module, options_path], 8.0)
	if epoch != _epoch:
		return _error("진행이 바뀌어 이전 실험 결과를 취소했습니다.", "Progress changed; the old experiment was discarded.")
	busy = false
	changed.emit()
	if result["timed_out"]:
		return _error("실험이 끝나지 않아 중단했습니다. 함수의 종료 경로를 확인하세요.", "The experiment timed out. Check how the function finishes.")
	var observation: Dictionary = {}
	for line in String(result["out"]).split("\n"):
		if line.begins_with("CODIEN_PROBE="):
			var parser := JSON.new()
			if parser.parse(line.trim_prefix("CODIEN_PROBE=")) == OK and typeof(parser.data) == TYPE_DICTIONARY:
				observation = parser.data
	if not observation.get("ok", false) or result["code"] != 0:
		return {"ok": false, "error": Workspace.virtualize(String(observation.get("error", result["err"]))) if not observation.is_empty() else Game.L("실험 코드를 실행하지 못했습니다. 문법과 내보낸 createOrder 함수를 확인하세요.", "Could not run the module. Check syntax and the exported createOrder function.")}
	if typeof(observation.get("responses")) != TYPE_ARRAY or typeof(observation.get("created")) not in [TYPE_INT, TYPE_FLOAT] or typeof(observation.get("attempts")) not in [TYPE_INT, TYPE_FLOAT]:
		return _error("주문 결과 형식을 확인할 수 없습니다.", "Could not read the order results.")
	observation["created"] = int(observation["created"])
	observation["attempts"] = int(observation["attempts"])
	observation["config"] = config
	observation["code_hash"] = code_hash
	observation["time"] = Game.time_text()
	if not Game.SaveStore._valid_probe(observation):
		return _error("주문 결과 형식이 올바르지 않습니다. createOrder가 반환하는 주문의 id를 확인하세요.", "Invalid order result. Check the order id returned by createOrder.")
	state()["latest"] = observation
	state()["runs"].append(observation)
	while state()["runs"].size() > 24:
		state()["runs"].pop_front()
	Game.advance(5)
	Game.emit_event("request_experiment", observation)
	changed.emit()
	return observation
