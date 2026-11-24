extends Node
## Studio product #2: Moonlight's pre-order web page. Same pipeline as ArcadeStudio (Packet Run):
## edit TypeScript → Node build evaluates it → automated checks → Daniel's review → release.
## The released page is a live, clickable site in Relay (moonlight.shop). Work files live outside
## the campaign Git checkout, like the Packet Run draft.

signal changed

const ISSUE := "NXR-STUDIO-2"
const SOURCE := "studio://moonlight_page.ts"
const TEMPLATES := "res://content/web/studio/"
const MAX_SOURCE := 16_384
const IMAGES := ["tea", "cup", "cookie", "candle", "jam"]
const THEMES := ["night", "dawn", "paper"]
const UNLOCK_CHAPTER := 3

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


func lang() -> String:
	return String(Game.state.get("repo_lang", Game.lang))


func available() -> bool:
	return Game.chapter() >= UNLOCK_CHAPTER or has_source()


func _source_path() -> String:
	return Workspace.root.path_join("studio/moonlight_page.ts")


func has_source() -> bool:
	return Workspace.root != "" and FileAccess.file_exists(_source_path())


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
	if not available():
		return false
	if not has_source():
		var folder := _source_path().get_base_dir()
		if not DirAccess.dir_exists_absolute(folder) and DirAccess.make_dir_recursive_absolute(folder) != OK:
			return false
		var starter := FileAccess.get_file_as_string(TEMPLATES + "moonlight_page_%s.ts" % lang())
		if starter.is_empty() or not _write(_source_path(), starter):
			return false
	Game.add_issue(ISSUE, Game.LL("달빛상점 예약 판매 페이지 만들기", "Build Moonlight's pre-order page"), "feature", "me", "progress")
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


# --- Artifacts ---------------------------------------------------------------------------

## Validates a build artifact ({page, prices, labels, reserve}); empty means unusable.
static func unpack(build: Dictionary) -> Dictionary:
	var page = build.get("page")
	if not page is Dictionary or not build.get("prices") is Dictionary or not build.get("labels") is Dictionary or not build.get("reserve") is Dictionary:
		return {}
	for key in ["title", "headline", "cta"]:
		if not page.get(key) is String or String(page[key]).strip_edges().is_empty() or String(page[key]).length() > 80:
			return {}
	if not String(page.get("theme", "")) in THEMES or not page.get("products") is Array:
		return {}
	var products: Array = page["products"]
	if products.is_empty() or products.size() > 6:
		return {}
	for p in products:
		if not p is Dictionary or not p.get("name") is String or not String(p.get("image", "")) in IMAGES or not p.get("alt") is String:
			return {}
		for n in ["price", "stock"]:
			if typeof(p.get(n)) not in [TYPE_INT, TYPE_FLOAT] or float(p[n]) < 0 or float(p[n]) != floor(float(p[n])):
				return {}
	return build


static func price_text(build: Dictionary, won: int) -> String:
	return String(build["prices"].get(str(won), str(won)))


static func label_for(build: Dictionary, minutes_left: int) -> String:
	return String(build["labels"].get(str(clampi(minutes_left, -5, 1500)), ""))


static func can_reserve(build: Dictionary, stock: int, minutes_left: int) -> bool:
	var s := 0 if stock <= 0 else (1 if stock < 5 else 5)
	var m := -1 if minutes_left < 0 else (0 if minutes_left == 0 else (1 if minutes_left < 60 else 60))
	return bool(build["reserve"].get("%d:%d" % [s, m], false))


func release() -> Dictionary:
	return _saved("page_release")


func _saved(key: String) -> Dictionary:
	var value = Game.state["flags"].get(key, {})
	if not value is Dictionary or unpack(value).is_empty():
		return {}
	return value


func is_current_build() -> bool:
	return not _built.is_empty() and has_source() and read_source().sha256_text() == _built_hash


func test_results() -> Array[Dictionary]:
	if is_current_build():
		return _tests
	var approved := approval()
	return [] if approved.is_empty() else _run_checks(approved)


# --- Build and checks ------------------------------------------------------------------

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
	_tests = _run_checks(_built)
	var passed := _checks_pass()
	feedback = Game.L("자동 테스트를 통과했습니다.", "Automated tests passed.") if passed else Game.L("실패한 테스트가 있습니다. 코드를 수정하고 다시 실행하세요.", "Some tests failed. Update the code and rerun the tests.")
	changed.emit()
	return passed


func _compile(source: String) -> Dictionary:
	if not Workspace.has_node_runtime():
		return {"ok": false, "message": Game.L("테스트를 실행하려면 Node.js가 필요합니다.", "Node.js is required to run the tests.")}
	var folder := _source_path().get_base_dir().path_join("page_build")
	if not DirAccess.dir_exists_absolute(folder):
		DirAccess.make_dir_recursive_absolute(folder)
	var driver := FileAccess.get_file_as_string(TEMPLATES + "build_page.mjs")
	if driver.is_empty() or not _write(folder.path_join("build_page.mjs"), driver) or not _write(folder.path_join("compile_input.ts"), source):
		return {"ok": false, "message": Game.L("빌드 파일을 준비하지 못했습니다.", "Could not prepare the build files.")}
	var epoch := _epoch
	busy = true
	feedback = ""
	changed.emit()
	var args := ["--experimental-permission", "--allow-fs-read=" + folder, "--experimental-strip-types", "--no-warnings", folder.path_join("build_page.mjs")]
	var result := await Workspace.run("node", args, 5.0)
	if epoch != _epoch:
		return {}
	busy = false
	if result["timed_out"]:
		return {"ok": false, "message": Game.L("빌드가 끝나지 않았어요. 함수에서 무한 반복을 확인하세요.", "The build timed out. Check your functions for an endless loop.")}
	if result["code"] != 0:
		var error := Workspace.virtualize(String(result["err"])).strip_edges().left(480).replace("compile_input.ts", "moonlight_page.ts")
		return {"ok": false, "message": Game.L("빌드 오류", "Build error") + "\n" + error}
	var artifact := {}
	for line in String(result["out"]).split("\n"):
		if line.begins_with("CODIEN_PAGE="):
			var parser := JSON.new()
			if parser.parse(line.trim_prefix("CODIEN_PAGE=")) == OK and parser.data is Dictionary:
				artifact = parser.data
	if unpack(artifact).is_empty():
		return {"ok": false, "message": Game.L("페이지 구조를 확인하세요. 제목·문구·버튼, 테마, 1–6개 상품이 필요합니다.", "Check the page shape: title, headline, button text, a theme and 1–6 products.")}
	return {"ok": true, "artifact": artifact}


func _fail(message: String) -> bool:
	feedback = message
	changed.emit()
	return false


## Expected outputs per language (the page is written in the company repo language).
func _expect() -> Dictionary:
	if lang() == "en":
		return {"prices": {"0": "₩0", "500": "₩500", "12000": "₩12,000", "1234567": "₩1,234,567"},
			"labels": {"-5": "Closed", "0": "Closed", "1": "1 min left", "59": "59 min left", "60": "1 h left", "61": "1 h 1 min left", "125": "2 h 5 min left", "1440": "24 h left"}}
	return {"prices": {"0": "0원", "500": "500원", "12000": "12,000원", "1234567": "1,234,567원"},
		"labels": {"-5": "마감", "0": "마감", "1": "1분 남음", "59": "59분 남음", "60": "1시간 남음", "61": "1시간 1분 남음", "125": "2시간 5분 남음", "1440": "24시간 남음"}}


func _run_checks(build: Dictionary) -> Array[Dictionary]:
	var page: Dictionary = build["page"]
	var products: Array = page["products"]
	var expect := _expect()
	var prices_ok: bool = expect["prices"].keys().all(func(k: String) -> bool: return String(build["prices"].get(k, "")) == expect["prices"][k])
	var labels_ok: bool = expect["labels"].keys().all(func(k: String) -> bool: return String(build["labels"].get(k, "")) == expect["labels"][k])
	var reserve_ok := true
	for stock in [0, 1, 5]:
		for minutes in [-1, 0, 1, 60]:
			if bool(build["reserve"].get("%d:%d" % [stock, minutes], false)) != (stock > 0 and minutes > 0):
				reserve_ok = false
	return [
		{"ok": products.size() >= 3 and products.all(func(p: Dictionary) -> bool: return String(p["alt"]).strip_edges().length() >= 2),
			"label": Game.LL("상품 3개 이상, 모든 이미지에 대체 텍스트", "At least three products, alt text on every image")},
		{"ok": prices_ok, "label": Game.LL("가격에 천 단위 쉼표 (12000 → 12,000원)", "Prices with thousands separators (12000 → ₩12,000)")},
		{"ok": labels_ok, "label": Game.LL("남은 시간 문구 (마감 · N분 · H시간 M분)", "Time-left wording (Closed · N min · H h M min)")},
		{"ok": reserve_ok, "label": Game.LL("품절이거나 마감되면 예약 버튼 비활성", "Pre-order disabled when sold out or closed")},
	]


func _checks_pass() -> bool:
	return is_current_build() and not _tests.is_empty() and _tests.all(func(item: Dictionary) -> bool: return item["ok"])


# --- Review and release ------------------------------------------------------------------

func approval() -> Dictionary:
	var saved := _saved("page_approval")
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
		return _fail(Game.L("검토 빌드가 테스트한 버전과 일치하지 않습니다. 다시 테스트하세요.", "The review build differs from the tested revision. Run the tests again."))
	candidate["revision"] = source.sha256_text()
	Game.state["flags"]["page_approval"] = candidate
	feedback = Game.L("Daniel이 이 버전의 공개를 승인했습니다.", "Daniel approved this revision for release.")
	Game.say("daniel", Game.LL("가격 표시, 남은 시간 문구, 품절·마감 처리까지 확인했어요. 대체 텍스트도 좋네요. 공개 승인합니다.", "Checked prices, time-left wording, and sold-out/closed handling. The alt text is good too. Approved for release."))
	Game.save_soon()
	changed.emit()
	return true


func can_release() -> bool:
	var approved := approval()
	return not busy and not approved.is_empty() and release().get("revision", "") != approved.get("revision", "")


func publish() -> bool:
	if not can_release():
		return false
	var first := release().is_empty()
	Game.state["flags"]["page_release"] = approval().duplicate(true)
	Game.set_issue(ISSUE, "done")
	Game.emit_event("page_released", {})
	feedback = Game.L("페이지를 공개했습니다.", "The page is live.")
	Game.notify("browser", "moonlight.shop", Game.L("달빛상점 예약 페이지가 공개됐어요.", "Moonlight's pre-order page is live."))
	if first:
		Game.say("yuri", Game.LL("윤서진 대표님이 페이지 보시고 '진짜 우리 가게 같다'고 하셨어요. 마감 시간 표시가 제일 마음에 드신대요.",
			"Seojin saw the page and said it 'really feels like our shop'. She loves the deadline display most."))
		Game.relate("alex", {"work": 2})
	Game.save_soon()
	changed.emit()
	return true
