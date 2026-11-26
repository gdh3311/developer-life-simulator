extends RefCounted
## Teammates' pull requests (roadmap 3.2). A colleague opens a PR whose own tests pass but that
## hides a mistake. The player answers in one of three ways:
##   fix it   — check out the branch, commit, push. Fast. The author learns nothing (`takeover`).
##   comment  — select lines and leave a review. The author fixes it later; if the comment does not
##              point at the mistake, the fix misses too and the hidden checks catch it.
##   pair     — costs an hour of the clock and a short exchange. An explanation teaches (`explained`);
##              handing over the answer fixes it without learning.
## LGTM without spotting the mistake runs the hidden checks, which fail; the reviewer sends it back.
## What the author learned is remembered per lesson. A later PR that `repeats` a learned lesson
## arrives already correct, and merging it as-is records `mentoring_evidence = independent`.
## State: Game.state["npc_prs"] = { prs: {spec: record}, lessons: {author: {lesson: true|false}} }
## Story calls on_event/resume; missions call open(spec, mission) and listen for "npc_pr_resolved".

## Each spec: author, reviewer (a senior who approves and merges), branch, title, body,
## files {repo path: content file}, fixed / wrong (the author's two possible fixes),
## learned (files when the author already knows the lesson), bug (substrings of the faulty lines),
## lesson, repeats (lesson a previous PR taught), pair {ask, options: [{id, label, good}]},
## replies {located, missed, lgtm_clean}. Content lives in content/commerce-api/<lang>/npc/<spec>/,
## hidden checks in content/ci/<lang>/npc_<spec>/.
const SPECS := {
	"jw_shipping": {
		"author": "jiwoo", "reviewer": "daniel", "branch": "jiwoo/shipping-weight", "lesson": "partial_units",
		"title": "feat(shipping): weight-based shipping fee",
		"body": {"ko": "무게별 배송비 계산을 추가했어요! 위키 정책대로 2kg 넘으면 1kg마다 500원이고, 테스트도 두 개 넣었어요. 첫 백엔드 PR이에요 🙏",
			"en": "Adds the weight-based shipping fee! Per the Wiki, 500 won per kg over 2 kg, with two tests. My first backend PR 🙏"},
		"files": {"src/shipping/fee.ts": "fee.ts", "tests/fee.test.ts": "fee.test.ts"},
		"fixed": {"src/shipping/fee.ts": "fee_fixed.ts"},
		"wrong": {"src/shipping/fee.ts": "fee_wrong.ts"},
		"bug": ["Math.round(weightKg"],
		"pair": {
			"ask": {"ko": "페어링 감사해요! 2.3kg 주문으로 같이 계산해 보니 추가 요금이 0이 나와요… 어떻게 고치면 될까요?",
				"en": "Thanks for pairing! Working through a 2.3 kg order together, the extra comes out as 0… how should I fix it?"},
			"options": [
				{"id": "explain", "good": true, "label": {"ko": "정책이 '모자란 무게도 1kg'이니까 반올림이 아니라 올림이에요. 2kg 이하에서 음수가 안 되는지도 같이 테스트해 봐요.",
					"en": "The policy says a partial kg counts as a whole one, so it's rounding up, not rounding. Let's also test that 2 kg or less never goes negative."}},
				{"id": "answer", "good": false, "label": {"ko": "그 줄을 Math.max(0, Math.ceil(weightKg - 2))로 바꾸면 돼요.",
					"en": "Change that line to Math.max(0, Math.ceil(weightKg - 2))."}},
			],
		},
	},
	"jw_boxes": {
		"author": "jiwoo", "reviewer": "daniel", "branch": "jiwoo/box-count", "lesson": "partial_units", "repeats": "partial_units",
		"title": "feat(shipping): box count for packing",
		"body": {"ko": "포장 상자 수 계산이에요. 상자 하나에 6개씩 담아요. 이번엔 혼자 해 봤어요!",
			"en": "Box count for packing, six items per box. I tried this one on my own!"},
		"files": {"src/shipping/boxes.ts": "boxes.ts", "tests/boxes.test.ts": "boxes.test.ts"},
		"learned": {"src/shipping/boxes.ts": "boxes_learned.ts", "tests/boxes.test.ts": "boxes_learned.test.ts"},
		"fixed": {"src/shipping/boxes.ts": "boxes_fixed.ts"},
		"wrong": {"src/shipping/boxes.ts": "boxes_wrong.ts"},
		"bug": ["Math.round(items"],
		"pair": {
			"ask": {"ko": "또 남는 상품이 문제네요… 7개면 상자가 하나로 나와요. 어디서 틀린 걸까요?",
				"en": "Leftover items again… 7 items come out as one box. Where did I go wrong?"},
			"options": [
				{"id": "explain", "good": true, "label": {"ko": "배송비 때랑 같아요. 남는 게 하나라도 있으면 하나 더 필요하니까 올림이에요. 7개, 0개 경계를 테스트에 넣어 봐요.",
					"en": "Same as the shipping fee: any leftover needs one more, so round up. Put 7 and 0 in the tests."}},
				{"id": "answer", "good": false, "label": {"ko": "Math.ceil로 바꾸면 돼요.", "en": "Just use Math.ceil."}},
			],
		},
	},
}

const RELS := {
	"takeover": {"close": 1},
	"comment": {"tech": 4, "agree": 2},
	"pair_good": {"tech": 3, "close": 4},
	"pair_answer": {"close": 2},
	"independent": {"tech": 5, "work": 4},
}


static func t(ko: String, en: String) -> Dictionary:
	return {"ko": ko, "en": en}


func st() -> Dictionary:
	if not Game.state.has("npc_prs") or typeof(Game.state["npc_prs"]) != TYPE_DICTIONARY:
		Game.state["npc_prs"] = {"prs": {}, "lessons": {}}
	return Game.state["npc_prs"]


func record(spec_id: String) -> Dictionary:
	return (st()["prs"] as Dictionary).get(spec_id, {})


func spec(spec_id: String) -> Dictionary:
	return SPECS.get(spec_id, {})


## The spec a PR belongs to, or "".
static func spec_of(pr: Dictionary) -> String:
	return String(pr.get("flags", {}).get("npc_spec", ""))


func knows(author: String, lesson: String) -> bool:
	return bool((st()["lessons"] as Dictionary).get(author, {}).get(lesson, false))


func _teach(author: String, lesson: String, learned: bool) -> void:
	var lessons: Dictionary = st()["lessons"]
	if not lessons.has(author):
		lessons[author] = {}
	# Once learned, a later takeover doesn't erase it.
	lessons[author][lesson] = learned or bool(lessons[author].get(lesson, false))


func _files(spec_id: String, which: Dictionary) -> Dictionary:
	var out := {}
	for path in which:
		out[path] = Workspace.content("npc/%s/%s" % [spec_id, which[path]])
	return out


func _ensure_rel(npc: String) -> void:
	var rel: Dictionary = Game.state["rel"]
	if Game.NPCS.has(npc) and not rel.has(npc):
		rel[npc] = {"tech": 20, "work": 20, "close": 20, "agree": 35}


static func _wait(seconds: float) -> void:
	await (Engine.get_main_loop() as SceneTree).create_timer(seconds).timeout


## Opens the teammate's PR: their commit lands on the branch, then the PR. Returns the PR ({} on failure).
func open(spec_id: String, mission_id := "") -> Dictionary:
	var s := spec(spec_id)
	if s.is_empty():
		return {}
	var existing := record(spec_id)
	if not existing.is_empty():
		return CodeHub.get_pr(int(existing["pr"]))
	var author := String(s["author"])
	_ensure_rel(author)
	var clean: bool = s.has("repeats") and s.has("learned") and knows(author, String(s["repeats"]))
	var files := _files(spec_id, s["learned"] if clean else s["files"])
	if not await Workspace.bot_commit(author, String(s["branch"]), files, String(s["title"])):
		return {}
	var pr: Dictionary = await CodeHub.npc_pr(author, String(s["branch"]), String(s["title"]), s["body"], mission_id, String(s.get("reviewer", "daniel")))
	pr["flags"]["npc_spec"] = spec_id
	(st()["prs"] as Dictionary)[spec_id] = {"pr": int(pr["id"]), "status": "open", "mode": "", "clean": clean,
		"learned": false, "attempts": 0, "missed": 0, "pending_fix": "", "day": Game.day(), "mission": mission_id}
	Game.save_soon()
	return pr


## Hidden checks join CI only once the player has answered (so the PR first looks green).
func hidden_tests(pr: Dictionary) -> Dictionary:
	var id := spec_of(pr)
	if id == "" or not pr["flags"].get("checked", false):
		return {}
	var result := {}
	var dir := Workspace.ci_content_dir("npc_" + id)
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".ts"):
			result[f] = FileAccess.get_file_as_string(dir.path_join(f))
	return result


func _pr_for(spec_id: String) -> Dictionary:
	var r := record(spec_id)
	return {} if r.is_empty() else CodeHub.get_pr(int(r["pr"]))


func _spec_for_pr_id(pr_id: int) -> String:
	for id in st()["prs"]:
		if int(st()["prs"][id]["pr"]) == pr_id:
			return id
	return ""


func _check_now(pr: Dictionary) -> void:
	pr["flags"]["checked"] = true
	CodeHub.run_ci(int(pr["id"]))


## "Fix it myself": posts the commands; pushing to the branch is what counts.
func takeover_hint(pr_id: int) -> void:
	var pr := CodeHub.get_pr(pr_id)
	if pr.is_empty() or spec_of(pr) == "":
		return
	var b := String(pr["branch"])
	CodeHub.comment(pr_id, "system", t("직접 고치려면: git fetch → git switch %s → 고치고 테스트 → commit → git push. push하면 [CI] 추가 검사가 함께 돕니다." % b,
		"To fix it yourself: git fetch → git switch %s → fix and test → commit → git push. Pushing runs the [CI] extra checks too." % b))


## Pairing: an hour together, then one exchange decides whether the author learns.
func pair(pr_id: int) -> bool:
	var spec_id := _spec_for_pr_id(pr_id)
	var pr := CodeHub.get_pr(pr_id)
	if spec_id == "" or pr.is_empty() or pr["state"] != "open" or not pr["flags"].get("needs_my_comment", false):
		return false
	var s := spec(spec_id)
	var r := record(spec_id)
	r["mode"] = "pair"
	pr["flags"]["needs_my_comment"] = false
	pr["flags"]["pairing"] = true
	Game.advance(60)
	CodeHub.comment(pr_id, "system", t("%s 님과 1시간 페어링했습니다." % Game.npc_name(s["author"]), "Paired with %s for an hour." % Game.npc_name(s["author"])))
	CodeHub.comment(pr_id, s["author"], s["pair"]["ask"], {"choices": s["pair"]["options"].map(func(o: Dictionary) -> Dictionary: return {"id": o["id"], "label": o["label"]}),
		"key": "npcpr:" + spec_id})
	Game.emit_event("npc_pr_pairing", {"spec": spec_id, "pr": pr_id})
	return true


func on_event(kind: String, d: Dictionary) -> void:
	match kind:
		"player_review":
			var spec_id := _spec_for_pr_id(int(d.get("pr", 0)))
			if spec_id != "":
				_on_review(spec_id, String(d["verdict"]), d.get("lines", []))
		"choice":
			var key := String(d.get("key", ""))
			if key.begins_with("npcpr:"):
				_on_pair_answer(key.trim_prefix("npcpr:"), String(d["option"]))
		"git_pushed":
			for spec_id in st()["prs"]:
				var pr := _pr_for(spec_id)
				if not pr.is_empty() and pr["state"] == "open" and pr["branch"] == String(d.get("branch", "")):
					_on_takeover(spec_id, pr)
		"ci":
			var spec_id := _spec_for_pr_id(int(d.get("pr", 0)))
			if spec_id != "":
				_on_ci(spec_id, bool(d.get("ok", false)))


func _on_takeover(spec_id: String, pr: Dictionary) -> void:
	var r := record(spec_id)
	if r["status"] == "merged":
		return
	r["mode"] = "takeover"
	r["pending_fix"] = ""
	pr["flags"]["needs_my_comment"] = false
	pr["flags"]["checked"] = true   # CodeHub reruns CI for the push and reads this
	Game.save_soon()


func _located(spec_id: String, lines: Array) -> bool:
	var marks: Array = spec(spec_id).get("bug", [])
	for l in lines:
		for m in marks:
			if String(l.get("text", "")).contains(String(m)):
				return true
	return false


func _on_review(spec_id: String, verdict: String, lines: Array) -> void:
	var s := spec(spec_id)
	var r := record(spec_id)
	var pr := _pr_for(spec_id)
	if r.is_empty() or pr.is_empty() or r["status"] == "merged":
		return
	var author := String(s["author"])
	r["attempts"] = int(r["attempts"]) + 1
	if verdict == "lgtm":
		r["mode"] = "lgtm"
		_check_now(pr)   # clean PRs pass and merge; others fail and come back (_on_ci)
		return
	if r["clean"]:
		# Nothing was wrong: the author asks which line, and the PR stays with the player.
		Game.relate(author, {"agree": -2})
		CodeHub.comment(int(pr["id"]), author, t("어느 부분이 문제일까요? 이번엔 남는 몫도 올림으로 했고, 7개랑 0개도 테스트에 넣었어요.",
			"Which part looks wrong? I rounded leftovers up this time and tested 7 and 0 items."))
		pr["flags"]["needs_my_comment"] = true
		CodeHub.pr_changed.emit(int(pr["id"]))
		return
	r["mode"] = "comment"
	var hit := _located(spec_id, lines)
	r["learned"] = hit
	if hit:
		CodeHub.comment(int(pr["id"]), author, t("아, 그 줄이었군요! 정책을 다시 읽고 고쳐 볼게요. 점심 먹고 올릴게요.",
			"Oh, that line! I'll reread the policy and fix it. I'll push after lunch."))
	else:
		CodeHub.comment(int(pr["id"]), author, t("짚어 주신 곳을 보고 고쳐 볼게요… 점심 먹고 올릴게요.",
			"I'll look at what you pointed out and try a fix… I'll push after lunch."))
	_schedule_fix(spec_id, "fixed" if hit else "wrong")


func _on_pair_answer(spec_id: String, option: String) -> void:
	var s := spec(spec_id)
	var r := record(spec_id)
	if r.is_empty() or r["status"] == "merged":
		return
	var good := false
	for o in s["pair"]["options"]:
		if o["id"] == option:
			good = bool(o.get("good", false))
	r["learned"] = good
	r["mode"] = "pair" if good else "pair_answer"
	var pr := _pr_for(spec_id)
	pr["flags"]["pairing"] = false
	if r["clean"]:
		# The work was already right; pairing just confirmed it.
		r["mode"] = "pair"
		r["learned"] = true
		CodeHub.comment(int(pr["id"]), s["author"], t("같이 보니까 맞게 한 것 같아요! [CI] 검사 돌려 볼게요.", "Looking at it together, I think it's right! Let's run the [CI] checks."))
		_check_now(pr)
		return
	CodeHub.comment(int(pr["id"]), s["author"], t("이제 왜 그런지 알겠어요! 테스트까지 넣어서 바로 올릴게요.", "Now I see why! I'll add tests and push right away.") if good
		else t("네, 그렇게 바꿀게요!", "Okay, I'll change it to that!"))
	_schedule_fix(spec_id, "fixed", 1.5)


## The author pushes a fix after a while. Saved, so a reload mid-wait still delivers it.
func _schedule_fix(spec_id: String, which: String, delay := 4.0) -> void:
	var r := record(spec_id)
	r["pending_fix"] = which
	Game.save_soon()
	await _wait(delay)
	await _deliver_fix(spec_id, int(r["pr"]))


func _deliver_fix(spec_id: String, pr_id: int) -> void:
	var r := record(spec_id)
	if r.is_empty() or int(r["pr"]) != pr_id or String(r["pending_fix"]) == "" or r["status"] == "merged":
		return  # another game was loaded, or the fix already arrived
	var which := String(r["pending_fix"])
	r["pending_fix"] = ""
	var s := spec(spec_id)
	var pr := CodeHub.get_pr(pr_id)
	pr["flags"]["checked"] = true
	var msg := "fix: %s" % ("round partial units up" if which == "fixed" else "address review")
	if not await Workspace.bot_commit(String(s["author"]), String(s["branch"]), _files(spec_id, s[which]), msg):
		return
	await CodeHub.refresh_pr(pr_id, t("%s 님이 리뷰를 반영한 커밋을 push 했습니다." % Game.npc_name(s["author"]),
		"%s pushed a commit addressing the review." % Game.npc_name(s["author"])))


func _on_ci(spec_id: String, ok: bool) -> void:
	var s := spec(spec_id)
	var r := record(spec_id)
	var pr := _pr_for(spec_id)
	if r.is_empty() or pr.is_empty() or not pr["flags"].get("checked", false) or r["status"] == "merged" or String(r["pending_fix"]) != "":
		return
	if ok:
		await _approve_and_merge(spec_id, pr)
		return
	var author := String(s["author"])
	var reviewer := String(s.get("reviewer", "daniel"))
	match String(r["mode"]):
		"takeover":
			CodeHub.comment(int(pr["id"]), "system", t("[CI] 추가 검사가 아직 실패합니다. 고친 뒤 다시 push 하세요.", "The [CI] extra checks still fail. Fix and push again."))
		"lgtm":
			r["missed"] = int(r["missed"]) + 1
			Game.relate(reviewer, {"tech": -2})
			CodeHub.review(int(pr["id"]), reviewer, "changes", t("[CI] 추가 검사에서 걸렸어요. LGTM 전에 실패한 검사와 정책을 같이 봐 주세요.",
				"The [CI] extra checks caught something. Before an LGTM, read the failing check against the policy."))
			pr["flags"]["needs_my_comment"] = true
			CodeHub.pr_changed.emit(int(pr["id"]))
		_:
			CodeHub.comment(int(pr["id"]), author, t("고쳤는데 [CI] 검사가 아직 실패해요… 어디를 다시 봐야 할까요?",
				"I fixed it but the [CI] checks still fail… where should I look again?"))
			pr["flags"]["needs_my_comment"] = true
			CodeHub.pr_changed.emit(int(pr["id"]))


func _approve_and_merge(spec_id: String, pr: Dictionary) -> void:
	var s := spec(spec_id)
	var r := record(spec_id)
	var reviewer := String(s.get("reviewer", "daniel"))
	if pr["flags"].get("_npc_merging", false):
		return
	pr["flags"]["_npc_merging"] = true
	await _wait(1.0)
	if record(spec_id).is_empty() or pr["state"] != "open":
		return
	CodeHub.review(int(pr["id"]), reviewer, "approved", t("[CI] 추가 검사까지 통과했어요. 승인합니다.", "The [CI] extra checks pass too. Approved."))
	pr["flags"]["hold_merge"] = false
	var res: Dictionary = await CodeHub.merge(int(pr["id"]), reviewer)
	pr["flags"]["_npc_merging"] = false
	if not res.get("ok", false):
		return
	_resolve(spec_id)


func _resolve(spec_id: String) -> void:
	var s := spec(spec_id)
	var r := record(spec_id)
	var author := String(s["author"])
	var mode := String(r["mode"])
	var grade := ""
	var rel_key := ""
	if r["clean"] and mode == "lgtm":
		grade = "independent"
		rel_key = "independent"
	elif mode == "takeover":
		grade = "takeover"
		rel_key = "takeover"
	elif mode == "comment":
		grade = "explained" if r["learned"] else "takeover"
		rel_key = "comment" if r["learned"] else ""
	elif mode == "pair":
		grade = "explained"
		rel_key = "pair_good"
	elif mode == "pair_answer":
		grade = "takeover"
		rel_key = "pair_answer"
	r["status"] = "merged"
	r["grade"] = grade
	if s.has("lesson") and not r["clean"]:
		_teach(author, String(s["lesson"]), bool(r["learned"]))
	if rel_key != "":
		Game.relate(author, RELS[rel_key])
	if grade != "" and Story.evidence != null:
		Story.evidence.raise("mentoring_evidence", grade, spec_id)
	Game.save_soon()
	Game.emit_event("npc_pr_resolved", {"spec": spec_id, "pr": int(r["pr"]), "mode": mode, "grade": grade,
		"learned": bool(r["learned"]), "clean": bool(r["clean"]), "mission": String(r.get("mission", ""))})


## After a load: deliver a fix the author still owed, and settle a PR whose CI already passed.
func resume() -> void:
	for spec_id in st()["prs"]:
		var r: Dictionary = st()["prs"][spec_id]
		if r["status"] == "merged":
			continue
		if String(r["pending_fix"]) != "":
			_deliver_fix(spec_id, int(r["pr"]))


## For the Dashboard / tests: what happened with each teammate PR so far.
func summary() -> Array:
	var out: Array = []
	for spec_id in st()["prs"]:
		var r: Dictionary = st()["prs"][spec_id]
		out.append({"spec": spec_id, "status": r["status"], "mode": r["mode"], "grade": r.get("grade", "")})
	return out
