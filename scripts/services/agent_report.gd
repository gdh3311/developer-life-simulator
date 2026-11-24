extends RefCounted
## Read-only reports built from the player's repository and local test runner.


static func repository() -> String:
	var status := await Workspace._working_git(["status", "--short", "--branch"])
	var log := await Workspace._working_git(["log", "-4", "--oneline", "--decorate"])
	return _output(status) + "\n\n" + Game.L("최근 커밋", "Recent commits") + "\n" + _output(log)


static func inspect(path: String) -> String:
	var resolved := Workspace.resolve(path)
	var file := FileAccess.open(resolved, FileAccess.READ) if resolved != "" else null
	if file == null:
		return Game.L("파일을 읽을 수 없습니다.", "The file could not be read.")
	var lines := file.get_buffer(65536).get_string_from_utf8().split("\n")
	var entries := PackedStringArray()
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line.begins_with("export ") or line.begins_with("import ") or line.begins_with("#") or line.begins_with("test("):
			entries.append("%d  %s" % [i + 1, line.left(175)])
			if entries.size() == 14:
				break
	if entries.is_empty():
		for i in mini(lines.size(), 8):
			entries.append("%d  %s" % [i + 1, lines[i].left(175)])
	var tests := PackedStringArray()
	if not path.begins_with("tests/") and DirAccess.dir_exists_absolute(Workspace.resolve("tests")):
		for test_path in Workspace.list_files("tests"):
			if tests.size() == 8:
				break
			if not String(test_path).ends_with(".test.ts"):
				continue
			var test := FileAccess.open(Workspace.resolve(test_path), FileAccess.READ)
			if test != null and path.get_file() in test.get_buffer(65536).get_string_from_utf8():
				tests.append(test_path)
	var notes := "\n".join(entries)
	if not tests.is_empty():
		notes += "\n\n" + Game.L("이 파일명을 참조하는 테스트", "Tests referencing this filename") + "\n" + "\n".join(tests)
	return notes


static func tests(result: Dictionary) -> String:
	var lines := PackedStringArray([Game.L("통과 %d · 실패 %d", "%d passed · %d failed") % [result["passed"], result["failed"]]])
	for result_entry in result["tests"].slice(0, 24):
		lines.append(("✓  " if result_entry["ok"] else "✗  ") + String(result_entry["name"]))
		for detail in result_entry["detail"].slice(0, 4):
			lines.append("    " + String(detail).left(220))
	if result["tests"].size() > 24:
		lines.append(Game.L("외 %d개 테스트", "%d more tests") % (result["tests"].size() - 24))
	if result["tests"].is_empty() and result.get("output", "") != "":
		lines.append(String(result["output"]).left(2400).strip_edges())
	if result.has("error"):
		lines.append(result["error"])
	return "\n".join(lines)


static func review() -> Dictionary:
	var branch := Workspace.branch
	var head: String = Workspace._snap.get("head", "")
	var base := await Workspace._working_git(["merge-base", "origin/main", "HEAD"])
	if base["code"] != 0:
		return {"error": _output(base)}
	var revision := String(base["out"]).strip_edges()
	var changed := await Workspace._working_git(["diff", "--stat", "--no-ext-diff", revision, "--"])
	var status := await Workspace._working_git(["status", "--short", "--untracked-files=all"])
	var whitespace := await Workspace._working_git(["diff", "--check", "--no-ext-diff", revision, "--"])
	var commits := await Workspace._working_git(["log", "-1", "--format=%s", revision + "..HEAD"])
	if branch != Workspace.branch or head != Workspace._snap.get("head", ""):
		return {"error": Game.L("검토 중 브랜치가 바뀌었습니다. 다시 실행하세요.", "The checkout changed during review. Run it again.")}
	if changed["code"] != 0 or status["code"] != 0 or commits["code"] != 0:
		return {"error": _output(changed if changed["code"] != 0 else (status if status["code"] != 0 else commits))}
	var stat := _output(changed)
	var worktree := _output(status)
	var title := _output(commits)
	var check := _output(whitespace)
	var output := Game.L("비교 기준 · origin/main과의 공통 커밋 %s", "Base · merge base with origin/main %s") % revision.left(8)
	output += "\n\n" + Game.L("추적 파일 변경", "Tracked changes") + "\n" + (stat.left(2400) if stat != "" else Game.L("없음", "None"))
	if worktree != "":
		output += "\n\n" + Game.L("작업 트리에서 발견한 변경", "Working tree changes") + "\n" + worktree.left(1800)
	if check != "":
		output += "\n\n" + Game.L("공백 검사", "Whitespace check") + "\n" + check.left(1200)
	if stat == "" or worktree != "" or title == "" or branch in ["", "main"]:
		output += "\n\n" + Game.L("작업 브랜치의 변경을 모두 커밋하면 커밋 기준 PR 설명을 만들 수 있습니다.",
			"Commit your changes on a working branch to draft a PR description for the committed revision.")
		return {"report": output}
	var body := Game.L("변경 요약\n%s\n\n변경 이유\n[업무 배경과 해결하려는 문제를 작성]\n\n검증\n[실행한 테스트와 결과를 작성]",
		"Changes\n%s\n\nWhy\n[Describe the task and the problem addressed]\n\nVerification\n[Record the tests run and their results]") % stat.left(2400)
	return {"report": output, "draft": title + "\n\n" + body}


static func _output(result: Dictionary) -> String:
	return String(result["out"] + result["err"]).strip_edges()
