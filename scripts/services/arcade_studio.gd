extends Node
## Product work. Only an approved release is made available in Relay.

signal changed

const Rules := preload("res://scripts/services/arcade_rules.gd")
const ISSUE := "NXR-STUDIO"
const SOURCE := "studio://packet_level.ts"
const TEMPLATES := "res://content/web/arcade/"
const MAX_SOURCE := 16_384

var busy := false
var feedback := ""
var _epoch := 0
var _built := {}
var _built_hash := ""
var _tests: Array[Dictionary] = []


func _ready() -> void:
	Game.state_reset.connect(_reset)


func _reset() -> void:
	_epoch += 1
	busy = false
	feedback = ""
	_built.clear()
	_built_hash = ""
	_tests.clear()
	changed.emit()


func _source_path() -> String:
	return Workspace.root.path_join("studio/packet_level.ts")


func has_source() -> bool:
	return FileAccess.file_exists(_source_path())


func read_source() -> String:
	return FileAccess.get_file_as_string(_source_path()) if has_source() else ""


func _write(path: String, body: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(body)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok


func start_project() -> bool:
	if not has_source():
		var folder := _source_path().get_base_dir()
		if not DirAccess.dir_exists_absolute(folder) and DirAccess.make_dir_recursive_absolute(folder) != OK:
			return false
		var starter := FileAccess.get_file_as_string(TEMPLATES + "packet_level.ts")
		if starter.is_empty() or not _write(_source_path(), starter):
			return false
	Game.add_issue(ISSUE, Game.LL("Packet Run 출구 조건 수정", "Fix the Packet Run exit rule"), "bug", "me", "progress")
	changed.emit()
	return true


func write_source(body: String) -> bool:
	if not has_source() or body.to_utf8_buffer().size() > MAX_SOURCE:
		return false
	if not _write(_source_path(), body):
		return false
	feedback = ""
	changed.emit()
	return true


func is_current_build() -> bool:
	return not _built.is_empty() and has_source() and read_source().sha256_text() == _built_hash


func release() -> Dictionary:
	return _saved_artifact("arcade_release")


func _saved_artifact(key: String) -> Dictionary:
	var value = Game.state["flags"].get(key, {})
	if not value is Dictionary or Rules.unpack(value).is_empty():
		return {}
	return value


func test_results() -> Array[Dictionary]:
	if is_current_build():
		return _tests
	var approved := approval()
	return [] if approved.is_empty() else _run_checks(Rules.unpack(approved))


func run_tests() -> bool:
	if busy or not has_source():
		return false
	var source := read_source()
	_built = {}
	_built_hash = ""
	_tests.clear()
	var result := await _compile(source)
	if result.is_empty():
		return false
	if not result["ok"]:
		return _fail(result["message"])
	if source != read_source():
		return _fail(Game.L("테스트 중 저장된 코드가 바뀌었습니다. 다시 실행하세요.", "Saved code changed during testing. Run the tests again."))
	_built = result["artifact"]
	_built_hash = source.sha256_text()
	_tests = _run_checks(result["board"])
	var passed := _checks_pass()
	feedback = Game.L("자동 테스트를 통과했습니다.", "Automated tests passed.") if passed else Game.L("실패한 테스트가 있습니다. 코드를 수정하고 다시 실행하세요.", "Some tests failed. Update the code and rerun the tests.")
	changed.emit()
	return passed


func _compile(source: String) -> Dictionary:
	if not Workspace.has_node_runtime():
		return _compile_error(Game.L("테스트를 실행하려면 Node.js가 필요합니다.", "Node.js is required to run the tests."))
	var folder := _source_path().get_base_dir()
	var compiler := folder.path_join("build_level.mjs")
	var snapshot := folder.path_join("compile_input.ts")
	var driver := FileAccess.get_file_as_string(TEMPLATES + "build_level.mjs")
	if driver.is_empty() or not _write(compiler, driver) or not _write(snapshot, source):
		return _compile_error(Game.L("빌드 파일을 준비하지 못했습니다.", "Could not prepare the build files."))
	var epoch := _epoch
	busy = true
	feedback = ""
	changed.emit()
	var args := ["--experimental-permission", "--allow-fs-read=" + folder, "--experimental-strip-types", "--no-warnings", compiler]
	var result := await Workspace.run("node", args, 5.0)
	if epoch != _epoch:
		return {}
	busy = false
	if result["timed_out"]:
		return _compile_error(Game.L("빌드가 끝나지 않았어요. 함수에서 무한 반복을 확인하세요.", "The build timed out. Check your functions for an endless loop."))
	if result["code"] != 0:
		var error := Workspace.virtualize(String(result["err"])).strip_edges().left(480).replace("compile_input.ts", "packet_level.ts")
		return _compile_error(Game.L("빌드 오류", "Build error") + "\n" + error)
	var artifact := {}
	for line in String(result["out"]).split("\n"):
		if line.begins_with("CODIEN_ARCADE="):
			var parser := JSON.new()
			if parser.parse(line.trim_prefix("CODIEN_ARCADE=")) == OK and parser.data is Dictionary:
				artifact = parser.data
	var board := Rules.unpack(artifact)
	if board.is_empty():
		return _compile_error(Game.L("맵을 확인하세요. 4–8칸 너비와 높이, 같은 길이의 행, 시작 S와 출구 E 각각 하나, 이동 한도 4–32가 필요합니다.", "Check the map. Use a 4–8 by 4–8 board, equal row widths, one S and one E, and a move limit of 4–32."))
	return {"ok": true, "artifact": artifact, "board": board}


func _compile_error(message: String) -> Dictionary:
	return {"ok": false, "message": message}


func _fail(message: String) -> bool:
	feedback = message
	changed.emit()
	return false


func _run_checks(board: Dictionary) -> Array[Dictionary]:
	var doors: Array = board["exits"]
	var correctly_gated: bool = doors.back() == true and not doors.slice(0, doors.size() - 1).has(true)
	var moves := Rules.shortest_route(board)
	return [
		{"ok": board["packets"].size() >= 2 and board["walls"] > 0, "label": Game.LL("패킷 2개 이상, 벽 1개 이상", "At least two packets and one wall")},
		{"ok": correctly_gated, "label": Game.LL("모든 패킷을 모은 뒤 출구 열기", "Unlock the exit after collecting every packet")},
		{"ok": moves >= 0 and moves <= board["limit"], "label": Game.LL("이동 한도 안에 완주할 수 있는 경로", "A full route within the move budget")},
	]


func _checks_pass() -> bool:
	return is_current_build() and not _tests.is_empty() and _tests.all(func(item: Dictionary) -> bool: return item["ok"])



func approval() -> Dictionary:
	var saved := _saved_artifact("arcade_approval")
	if saved.is_empty() or not has_source() or saved.get("revision", "") != read_source().sha256_text():
		return {}
	return saved


func can_request_review() -> bool:
	return not busy and _checks_pass() and approval().is_empty() and release().get("revision", "") != _built_hash


func request_review() -> bool:
	if not can_request_review():
		return false
	var source := read_source()
	var candidate := _built.duplicate(true)
	var result := await _compile(source)
	if result.is_empty():
		return false
	if not result["ok"]:
		return _fail(result["message"])
	if source != read_source() or result["artifact"] != candidate:
		return _fail(Game.L("검토 빌드가 테스트한 버전과 일치하지 않습니다. 코드를 확인하고 다시 테스트하세요.", "The review build differs from the tested revision. Check the source and run the tests again."))
	candidate["revision"] = source.sha256_text()
	Game.state["flags"]["arcade_approval"] = candidate
	feedback = Game.L("Daniel이 이 버전의 내부 출시를 승인했습니다.", "Daniel approved this revision for internal release.")
	Game.say("daniel", Game.LL("출구 조건과 이동 한도를 확인했어요. 테스트한 코드로 같은 결과물이 만들어지네요. 사내 출시에 승인합니다.", "I checked the exit rule and the move budget. The tested source reproduces the same build. Approved for internal release."))
	Game.save_soon()
	changed.emit()
	return true


func can_release() -> bool:
	var approved := approval()
	return not busy and not approved.is_empty() and release().get("revision", "") != approved.get("revision", "")


func publish() -> bool:
	if not can_release():
		return false
	Game.state["flags"]["arcade_release"] = approval().duplicate(true)
	Game.set_issue(ISSUE, "done")
	Game.emit_event("arcade_submitted", {})
	feedback = Game.L("내부 출시를 완료했습니다.", "Internal release complete.")
	Game.notify("browser", "NEXORA Arcade", Game.L("Packet Run 새 버전이 Arcade에 공개됐어요.", "The new Packet Run release is available in Arcade."))
	changed.emit()
	return true
