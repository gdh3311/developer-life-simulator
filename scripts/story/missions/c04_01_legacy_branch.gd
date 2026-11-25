extends "res://scripts/story/mission.gd"
## C04 M01 — the branch you can't delete. Write characterization tests that pin today's refund
## behavior; the game proves them by deleting the "unused" legacy branch in a copy (mutation check).

const TEST_PATH := "tests/refund_characterization.test.ts"
var _checking := false


func _init() -> void:
	id = "c04_01"
	chapter = 4
	day = 11
	issue = "NXR-051"
	title = t("지울 수 없는 조건문", "The branch you can't delete")
	objectives = [
		{"id": "sync", "text": t("main 최신화로 환불 모듈 받기", "Update main to get the refund module")},
		{"id": "pinned", "text": t("특성 테스트로 legacy 동작 고정 (분기를 지우면 실패해야 함)", "Pin legacy behavior with characterization tests (deleting the branch must fail them)")},
		{"id": "plan", "text": t("legacy 분기를 어떻게 할지 정하기", "Decide what happens to the legacy branch")},
		{"id": "pr", "text": t("테스트 PR 만들기", "Open the test PR")},
		{"id": "merged", "text": t("병합", "Merge")},
	]
	hints = [
		t("Wiki '환불 계산'과 src/refunds/refund.ts를 보세요. 특성 테스트는 옳고 그름이 아니라 지금 하는 일을 고정해요.", "Read the Wiki page 'Refund calculation' and src/refunds/refund.ts. Characterization tests pin what the code does now, not what's right."),
		t("legacy: true인 주문에서 일반 반올림과 결과가 달라지는 금액을 고르세요. 예: 12345원의 절반.", "Pick a legacy: true amount where rounding down to 10 won differs from normal rounding, e.g. half of 12,345."),
	]


func begin() -> void:
	Game.set_time(9 * 60)
	Game.add_issue(issue, title, "chore", Game.L("나", "me"), "progress")
	say("system", t("일곱 번째 달 · 월요일", "Month seven · Monday"), {"channel": "general", "silent": true})
	if not data().get("_prepared", false):
		await Workspace.bot_commit("daniel", "main", {
			"src/refunds/refund.ts": Workspace.content("c04/refund.ts"),
		}, "feat(refunds): partial refunds for the launch contract (from payments-service, 2023)")
		if not is_current():
			return
		await Workspace.bot_commit("mina", "main", {
			TEST_PATH: Workspace.content("c04/refund_characterization.test.ts"),
		}, "test(refunds): start characterization tests")
		if not is_current():
			return
		data()["_prepared"] = true
	say("alex", t("신규 고객 온보딩 중인데, 환불 금액이 계약서랑 다르다는 문의가 왔어요. 환불 모듈을 payments-service에서 옮겨 왔으니 이번엔 우리가 봐야 해요.",
		"We're onboarding a new customer and they say refund amounts don't match their contract. We moved the refund module over from payments-service, so it's ours now."))
	say("mina", t("refund.ts에 legacy 분기가 있는데 아무도 안 쓰는 것 같아요. 지우면 깔끔할 것 같은데... 그 전에 지금 동작부터 테스트로 고정해 줄래요? 시작 파일은 올려 뒀어요.",
		"refund.ts has a legacy branch nobody seems to use. Deleting it would be cleaner... but could you pin down today's behavior with tests first? I pushed a starter file."))


func hidden_tests() -> Dictionary:
	return load_tests("c04_01")


## Daniel approves only a PR that carries the characterization tests, after they were proven
## against the deleted branch and the branch has a plan.
func review(p: Dictionary) -> void:
	var touches := await diff_touches_tests(p)
	if not is_current():
		return
	var missing: Array = []
	if not is_done("pinned"):
		missing.append(t("legacy 동작을 고정하는 특성 테스트", "characterization tests that pin the legacy behavior"))
	if not is_done("plan"):
		missing.append(t("legacy 분기 처리 방침", "a plan for the legacy branch"))
	if not touches:
		missing.append(t("PR에 테스트 파일 변경", "test changes in this PR"))
	if not missing.is_empty():
		CodeHub.review(p["id"], "daniel", "changes", {
			"ko": "아직 병합할 수 없어요. 필요한 것: " + ", ".join(missing.map(func(m: Dictionary) -> String: return m["ko"])) + ".",
			"en": "Not ready to merge. Still needed: " + ", ".join(missing.map(func(m: Dictionary) -> String: return m["en"])) + "."})
		return
	CodeHub.review(p["id"], "daniel", "approved", t("legacy 분기를 지우면 실패하는 테스트, 처리 방침까지 있네요. 승인합니다.", "Tests that fail when legacy is deleted, plus a plan. Approved."))


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"tests":
			if d.get("ok", false) and not is_done("pinned") and FileAccess.file_exists(Workspace.resolve(TEST_PATH)):
				_mutation_check()
		"choice":
			if d.get("key", "") != "c04_legacy_plan":
				return
			Game.state["flags"]["c04_legacy_plan"] = d["option"]
			match d["option"]:
				"retire":
					Game.relate("daniel", {"agree": 2})
					say("daniel", t("좋아요. 첫 계약이 끝나는 날짜를 폐기 계획에 적어 두죠. 그때 이 테스트가 근거가 될 거예요.", "Good. Let's put the launch contract's end date in the retirement plan. These tests will be the evidence then."))
				"delete":
					Game.relate("mina", {"agree": -1})
					say("mina", t("음, 그러면 첫 계약 판매자 12곳 환불이 바로 달라져요. 지우는 건 계약이 끝난 뒤로 미뤄요.", "Hm, that would change refunds for the 12 launch-contract sellers right away. Let's delete it after the contract ends."))
					Game.state["flags"]["c04_legacy_plan"] = "retire"
				"keep":
					say("daniel", t("그대로 두면 다음 사람도 같은 질문을 하겠죠. 적어도 왜 남겨 두는지는 주석과 Wiki에 남겨요.", "If we just leave it, the next person will ask the same question. At least write down why it stays."))
			complete("plan")
		"pr_merged":
			if int(d["pr"]) == int(data().get("pr", 0)):
				if not (is_done("pinned") and is_done("plan")):
					# Merged by someone else without the evidence: the task stays open.
					st()["obj"]["merged"] = false
					st()["obj"]["pr"] = false
					data()["pr"] = 0
					story.objectives_changed.emit()
					say("mina", t("PR은 병합됐지만 legacy 동작을 고정하는 테스트가 아직 없어요. 새 브랜치에서 테스트부터 올려 주세요.", "That PR merged, but there are still no tests pinning the legacy behavior. Open a new branch with the tests first."))
					return
				if once("_merge_reward"):
					Game.relate("mina", {"tech": 3, "close": 2})
				await wait(1.2)
				if not is_current():
					return
				say("mina", t("이제 누가 legacy를 지우려 하면 테스트가 먼저 말해 주겠네요.", "Now if anyone tries to delete legacy, the tests will speak up first."))
				finish()


## Copy the player's test file with the original module, then with the legacy branch deleted:
## it must pass the first and fail the second.
func _mutation_check() -> void:
	if _checking:
		return
	_checking = true
	var original := await _run_against(Workspace.read_file("src/refunds/refund.ts"))
	var mutant := await _run_against(Workspace.content("c04/refund_mutant.ts"))
	_checking = false
	if not is_current():
		return
	data()["mutation"] = {"original": original, "mutant": mutant}
	if original and not mutant:
		complete("pinned")
		Game.emit_event("mutation_killed", {"mission": id})
		say("mina", t("오, legacy 분기를 지운 복사본에서 테스트가 실패하네요. 그 분기, 누군가 쓰고 있었던 거예요. 그럼 이 분기를 어떻게 할까요?",
			"Oh, the tests fail on a copy with the legacy branch deleted. So someone was using it. What should we do with the branch?"))
		choice("mina", t("legacy 분기는 어떻게 할까요?", "What do we do with the legacy branch?"), "c04_legacy_plan", [
			["retire", t("계약 만료일에 맞춘 폐기 계획을 세우고 그때까지 유지해요.", "Keep it, with a retirement plan tied to the contract's end.")],
			["delete", t("테스트가 있으니 지금 지워도 될 것 같아요.", "We have tests now, so we can delete it.")],
			["keep", t("건드리지 말고 그냥 둬요.", "Leave it alone.")]])
	elif not original:
		say("mina", t("원래 코드에서 테스트가 실패해요. 특성 테스트는 지금 동작을 그대로 적어야 해요.", "The tests fail on the current code. Characterization tests should describe today's behavior as is."))
	elif once("_mutant_hint"):
		say("mina", t("legacy 분기를 지운 복사본에서도 테스트가 다 통과해요. 그러면 지워도 아무도 모르게 돼요. legacy: true인 주문 예시가 필요해요.",
			"The tests still pass on a copy with the legacy branch deleted, so nobody would notice the deletion. You need a legacy: true example."))


func _run_against(source: String) -> bool:
	var dir := ProjectSettings.globalize_path("user://sandbox/mutation/%s" % id)
	for sub in ["src/refunds", "tests"]:
		DirAccess.make_dir_recursive_absolute(dir.path_join(sub))
	for f in DirAccess.get_files_at(dir.path_join("tests")):
		DirAccess.remove_absolute(dir.path_join("tests").path_join(f))
	var src := FileAccess.open(dir.path_join("src/refunds/refund.ts"), FileAccess.WRITE)
	src.store_string(source)
	src.close()
	var test := FileAccess.open(dir.path_join(TEST_PATH), FileAccess.WRITE)
	test.store_string(Workspace.read_file(TEST_PATH))
	test.close()
	var r: Dictionary = await Workspace.run_tests(dir, false)
	return r.get("ok", false)
