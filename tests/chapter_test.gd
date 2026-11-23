extends Node
## Replay the real chapter through in-game Terminal/IDE and real Git/Node/CodeHub.

const Solutions := preload("res://tests/chapter_solutions.gd")
var _terminal: Control
var _ide: Control
var _ai: Control
var _checks := 0
var _failures := 0
var _profile := "prevent"
var _stage := ""
var _trace: Array = []
var _running := false
var _started := 0


func _ready() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	_checks += 1
	_trace.append({"check": message, "ok": ok, "mission": Story.active.id if Story.active != null else "", "time_ms": Time.get_ticks_msec() - _started})
	if not ok:
		_failures += 1
		push_error(message)


func wait_until(predicate: Callable, label: String, seconds := 40.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var ok := bool(predicate.call())
	check(ok, label)
	if not ok:
		print("REPLAY_STATE: ", JSON.stringify(Game.state["story"]))
	return ok


func active(id: String) -> bool:
	return Story.active != null and Story.active.id == id and Story.status(id) == "active"


func wait_mission(id: String) -> bool:
	print("REPLAY: waiting for ", id)
	return await wait_until(func() -> bool: return active(id), "entered " + id)


func has_message(fragment: String) -> bool:
	return Game.state["chat"].any(func(m: Dictionary) -> bool: return fragment in Game.tx(m["text"]))


func _process(_delta: float) -> void:
	if not _running:
		return
	# Answer exactly the game's offered choices; no mission objectives are set by the replay.
	var answers := {"d1_hello": "warm", "d1_lunch": "join", "d1_connect": "accept", "d2_coffee": "go", "d2_quiz": "right", "d2_sophie": "kind", "d3_checkin": "real", "d3_offer": "interested" if _profile == "recover" else "decline", "d3_alex": "ask", "d3_tests": "fix", "d4_retro": "process", "d4_review": "thanks", "final_offer": "accept"}
	for message in Game.state["chat"].duplicate():
		if message["answered"] == "" and not message["choices"].is_empty() and answers.has(message["key"]):
			Game.answer(int(message["id"]), answers[message["key"]])
			return
	for pr in CodeHub.prs().duplicate():
		for index in pr["timeline"].size():
			var item: Dictionary = pr["timeline"][index]
			if item["answered"] == "" and item["key"] == "d2_review":
				CodeHub.answer(int(pr["id"]), index, "argue")
				return


func command(line: String) -> void:
	print("REPLAY_CMD: ", line)
	await _terminal._execute(_terminal.tokenize(line))


func edit(path: String, content: String) -> void:
	_ide.open_file(path)
	_ide._code.text = content
	_ide.save()
	# IDE refreshes after save; let the snapshot settle before the next Git mutation.
	await get_tree().create_timer(0.1, true, false, true).timeout


func sync_main() -> void:
	await command("git switch main")
	await command("git pull")


func submit(branch: String, title: String) -> Dictionary:
	await command("git add .")
	await command('git commit -m "' + title + '"')
	await command("git push")
	var opened := await CodeHub.open_pr(branch, title, "Observed reproduction, implemented the policy and verified local tests.")
	check(opened.get("ok", false), "opened PR " + branch)
	return opened.get("pr", {})


func merged(pr: Dictionary) -> bool:
	return await wait_until(func() -> bool: return pr.get("state", "") == "merged", "senior merged " + String(pr.get("branch", "missing")))


func next_day() -> void:
	if not await wait_until(func() -> bool: return Game.state["day_done"], "day finished"):
		return
	Game.next_day()
	Story.start_day(Game.day())


func _run() -> void:
	if not String(ProjectSettings.get_setting("application/config/name")).begins_with("codien-gameplay-qa-"):
		push_error("Run through the isolated runner.")
		get_tree().quit(2)
		return
	_started = Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	if "--profile" in args:
		_profile = args[args.find("--profile") + 1]
	if "--stage" in args:
		_stage = args[args.find("--stage") + 1]
	Game.lang = "en" if _profile == "recover" else "ko"
	Game.reset_state()
	Game.state["player_name"] = "Replay Developer"
	if _profile == "resume" and _stage in ["review", "after"]:
		check(Game.load_game(), "loaded the previous process's pending CI checkpoint")
	Engine.time_scale = 8.0
	var prepared := await Workspace.prepare()
	check(prepared.get("ok", false), "created isolated real Git workspace")
	if not prepared.get("ok", false):
		await finish()
		return
	_terminal = preload("res://scripts/desktop/terminal_app.gd").new()
	_ide = preload("res://scripts/desktop/ide_app.gd").new()
	_ai = preload("res://scripts/apps/ai_app.gd").new()
	add_child(_terminal)
	add_child(_ide)
	add_child(_ai)
	_running = true
	if _profile == "resume" and _stage == "review":
		check(Game.state["story"]["d3_06"]["obj"].get("review", false) and not Game.state["story"]["d3_06"]["obj"].get("done", false), "NPC review checkpoint really precedes the senior decision")
		await Story.resume()
		await prepare_shipping()
		return
	if _profile == "resume" and _stage == "after":
		check(Game.state["codehub"]["prs"].any(func(p: Dictionary) -> bool: return p["branch"] == "feature/shipping" and p["ci"]["state"] == "running"), "the saved checkpoint really contains unfinished CI")
		await Story.resume()
		var pending: Dictionary = CodeHub.prs().filter(func(p: Dictionary) -> bool: return p["branch"] == "feature/shipping")[0]
		await finish_shipping(pending)
		return
	Story.start_new()
	if not await wait_mission("d1_01"):
		await finish()
		return
	await wait_until(func() -> bool: return Story.active.is_done("hello"), "answered welcome")
	Game.emit_event("wiki_page", {"page": "workflow"})
	await command("help")
	await command("ls")
	await command("cat README.md")
	await command('git config user.name "Replay Developer"')
	await command('git config user.email "replay@example.invalid"')
	await command("git status")
	await command("git log --oneline")
	if not await wait_mission("d1_02"):
		await finish()
		return
	await command("git switch -c docs/fix-typo")
	var first_pr: Dictionary = {}
	if _profile == "recover":
		await command('git commit --allow-empty -m "docs: incomplete first attempt"')
		await command("git push")
		var incomplete := await CodeHub.open_pr("docs/fix-typo", "docs: incomplete first attempt", "Checking the tutorial review guard.")
		first_pr = incomplete.get("pr", {})
		await wait_until(func() -> bool: return first_pr.get("review", {}).get("state", "") == "changes", "first PR cannot pass without the actual README correction")
		check(active("d1_02") and not Story.active.is_done("edit"), "an unrelated commit does not complete the edit objective")
	await edit("README.md", Workspace.read_file("README.md").replace("Commerse", "Commerce"))
	await command("git diff")
	var pr: Dictionary
	if first_pr.is_empty():
		pr = await submit("docs/fix-typo", "docs: correct the company name")
	else:
		await command("git add .")
		await command('git commit -m "docs: correct the company name"')
		await command("git push")
		pr = first_pr
	if not await merged(pr) or not await wait_mission("d1_03"):
		await finish()
		return
	await sync_main()
	await command("git branch -d docs/fix-typo")
	await command("git branch")
	await next_day()
	if not await wait_mission("d2_04"):
		await finish()
		return
	await wait_until(func() -> bool: return has_message("#001"), "Mina published reproduction tests")
	await sync_main()
	var failing := await Workspace.run_tests()
	check(not failing["ok"] and failing["failed"] > 0, "reproduced first name bug with Node")
	Game.emit_event("wiki_page", {"page": "names"})
	check(Cases.choose("d2_04", "cache"), "recorded an initial wrong hypothesis")
	check(Cases.choose("d2_04", "optional"), "revised hypothesis after evidence")
	if _profile == "recover":
		for i in 3:
			check(Story.next_hint() != "", "received a usable hint")
	await command("git switch -c fix/profile-name")
	await edit("src/users/displayName.ts", Solutions.NAME)
	if _profile != "recover":
		await edit("tests/player_name.test.ts", Solutions.NAME_TEST)
	check((await Workspace.run_tests())["ok"], "fixed name contract locally")
	pr = await submit("fix/profile-name", "fix: handle missing name parts")
	if not await merged(pr) or not await wait_mission("d2_05"):
		await finish()
		return
	await wait_until(func() -> bool: return has_message("#005"), "nickname regression is published")
	await sync_main()
	check(not (await Workspace.run_tests())["ok"], "reproduced actual nickname regression")
	await command("git blame src/users/displayName.ts")
	await command("git switch -c fix/nickname-fallback")
	await edit("src/users/displayName.ts", Solutions.NICKNAME)
	check((await Workspace.run_tests())["ok"], "preserved nickname and original name contracts")
	pr = await submit("fix/nickname-fallback", "fix: preserve original name fallback")
	if not await merged(pr):
		await finish()
		return
	await next_day()
	if not await wait_mission("d3_06"):
		await finish()
		return
	await wait_until(func() -> bool: return int(Story.active.data().get("target", 0)) > 0, "Sophie opened a real coupon PR")
	var target: int = Story.active.data().get("target", 0)
	var coupon_pr := CodeHub.get_pr(target)
	var diff := await Workspace.pr_diff(coupon_pr["branch"])
	Game.emit_event("pr_diff_viewed", {"mission": "d3_06", "text": diff})
	Game.emit_event("wiki_page", {"page": "coupon"})
	Cases.choose("d3_06", "math")
	var lines: Array = []
	if _profile != "recover":
		for line in diff.split("\n"):
			if "total * coupon.value" in line:
				lines.append({"file": "src/orders/coupon.ts", "line": 10, "text": line})
		check(not lines.is_empty(), "selected the actual faulty coupon calculation")
	if _profile == "recover":
		CodeHub.submit_comments(target, "concern", [{"file": "src/orders/coupon.ts", "line": 1, "text": "export type Coupon"}], "Initial suspicion")
		check(coupon_pr["flags"].get("needs_my_comment", false), "an unsupported review comment allows another review")
	CodeHub.submit_comments(target, "lgtm" if _profile == "recover" else "concern", lines, "Compared the math with the policy examples.")
	if _profile == "resume" and _stage == "before":
		check(Story.active.is_done("review") and not Story.active.is_done("done"), "captured the NPC response before completion")
		await checkpoint()
		return
	await prepare_shipping()


func prepare_shipping() -> void:
	if not await wait_mission("d3_07"):
		await finish()
		return
	await wait_until(func() -> bool: return Game.state["issues"].any(func(i: Dictionary) -> bool: return i["id"] == "#004"), "shipping skeleton is published")
	await sync_main()
	await command("git switch -c feature/shipping")
	await edit("src/orders/shipping.ts", Solutions.SHIPPING)
	await edit("src/orders/orders.ts", Solutions.ORDERS_BEFORE_MERGE)
	await edit("tests/orders.test.ts", Workspace.read_file("tests/orders.test.ts").replace(", 2500)", ", 5500)"))
	await edit("tests/shipping.test.ts", Solutions.SHIPPING_TEST)
	check((await Workspace.run_tests())["ok"], "shipping rules pass before the teammate refactor")
	var pr := await submit("feature/shipping", "feat: calculate shipping by order and region")
	if _profile == "resume" and _stage == "review":
		check(pr["ci"]["state"] == "running", "captured CI before it finishes")
		await checkpoint()
		return
	await finish_shipping(pr)


func checkpoint() -> void:
	var snapshot := JSON.stringify(Game.state)
	_running = false
	Story.active = null
	await get_tree().create_timer(0.6, true, false, true).timeout
	# Drain real children before exiting, then restore only the pre-exit state snapshot.
	while Workspace._ci_busy or Workspace._bot_busy or Workspace.active_jobs > 0 or Sfx._music.stream == null:
		await get_tree().process_frame
	Game.state = JSON.parse_string(snapshot)
	Game._save()
	await finish()


func finish_shipping(pr: Dictionary) -> void:
	await wait_until(func() -> bool: return pr.get("mergeable", "") == "conflict", "CodeHub detects a real merge conflict", 12.0 if _stage == "after" else 40.0)
	await command("git pull origin main")
	check("<<<<<<<" in Workspace.read_file("src/orders/orders.ts"), "Git produced conflict markers")
	await edit("src/orders/orders.ts", Solutions.ORDERS_RESOLVED)
	check((await Workspace.run_tests())["ok"], "resolved both subtotal and shipping contracts")
	await command("git add .")
	await command('git commit -m "fix: preserve subtotal during shipping merge"')
	await command("git push")
	if not await merged(pr):
		await finish()
		return
	check(Story.active.data().get("conflict_seen", false), "the story records the real conflict")
	await next_day()
	if not await wait_mission("d4_08"):
		await finish()
		return
	Game.emit_event("app_opened", {"app": "monitor"})
	Game.emit_event("monitor_viewed", {"mode": "auth_down"})
	Game.emit_event("wiki_page", {"page": "auth"})
	await sync_main()
	await command("git switch -c hotfix/login-timeout")
	if _profile == "recover":
		await _ai._on_delegate()
		check(Game.stat("ai_used") == 1, "AI delegation is counted once")
		pr = await submit("hotfix/login-timeout", "fix: try AI timeout draft")
		await wait_until(func() -> bool: return pr["ci"]["state"] == "fail", "hidden CI rejects the flawed AI patch")
		var prior_failures := Game.stat("ci_fail")
		var prior_minutes := Game.minutes()
		await CodeHub.run_ci(int(pr["id"]), true)
		check(Game.stat("ci_fail") == prior_failures and Game.minutes() == prior_minutes, "restoring an already-counted CI result has no extra time or stat cost")
		CodeHub.run_ci(int(pr["id"]))
		CodeHub.run_ci(int(pr["id"]))
		await wait_until(func() -> bool: return Game.stat("ci_fail") == prior_failures + 1 and pr["ci"]["state"] == "fail", "overlapping same-commit CI applies only its latest result")
	await edit("src/auth/login.ts", Solutions.LOGIN)
	await edit("tests/player_login.test.ts", Solutions.LOGIN_TEST)
	check((await Workspace.run_tests())["ok"], "timeout, missing token and provider errors stay distinct")
	if _profile == "recover":
		await command("git add .")
		await command('git commit -m "fix: preserve provider errors"')
		await command("git push")
	else:
		pr = await submit("hotfix/login-timeout", "fix: bound authentication waits")
	if not await merged(pr):
		await finish()
		return
	if _profile == "recover":
		if not await wait_mission("d4_09"):
			await finish()
			return
		await sync_main()
		await command("git switch -c hotfix/coupon-policy")
		await edit("src/orders/coupon.ts", Workspace.content("m05/coupon_fixed.ts"))
		await edit("tests/coupon.test.ts", Workspace.content("m05/coupon_fixed.test.ts"))
		check((await Workspace.run_tests())["ok"], "recovered from the missed coupon review")
		pr = await submit("hotfix/coupon-policy", "fix: correct discount units and bounds")
		if not await merged(pr):
			await finish()
			return
	if not await wait_mission("d4_10"):
		await finish()
		return
	await wait_until(func() -> bool: return Game.state["day_done"], "completed chapter and performance review")
	check(Story.status("d4_09") == ("done" if _profile == "recover" else "skipped"), "coupon incident follows the review decision")
	check(Game.stat("missions") == (10 if _profile == "recover" else 9), "all expected missions completed exactly once")
	check(Game.state["monitor"]["status"]["auth"] == "ok", "authentication is restored")
	check(Game.state["monitor"]["status"]["payments"] == "ok", "payments are healthy")
	if _profile == "recover":
		check(Game.state["flags"].get("ending", "") == "left", "the recruiter branch reaches its ending")
		check(Cases.record("d3_06").get("outcome", "") == "recovered", "case journal connects the recovery")
	Game._save()
	await finish()


func finish() -> void:
	_running = false
	while Workspace._bot_busy or Workspace._ci_busy or Workspace.active_jobs > 0 or Sfx._music.stream == null:
		await get_tree().process_frame
	await get_tree().process_frame
	var output := OS.get_environment("CODIEN_QA_OUTPUT")
	var f := FileAccess.open(output.path_join("chapter_" + _profile + ("_" + _stage if _stage != "" else "") + ".json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"profile": _profile, "checks": _checks, "failures": _failures, "trace": _trace, "story": Game.state["story"], "stats": Game.state["stats"]}, "\t"))
	f.close()
	print("CHAPTER_QA: %d checks, %d failures" % [_checks, _failures])
	print("PROCESS_REPLAY: jobs=", Workspace.active_jobs, " stderr_orphans=", Workspace.ProcJob._orphans.size())
	Sfx.stop_all()
	await get_tree().create_timer(0.1, true, false, true).timeout
	get_tree().quit(0 if _failures == 0 else 1)
