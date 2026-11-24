extends RefCounted
## Builds reviewable patches for the in-house agent's supported mission tasks.


static func make(task: Dictionary) -> Dictionary:
	var changes := {}
	var substitution: Dictionary = task.get("substitution", {})
	if not substitution.is_empty():
		var path: String = substitution["path"]
		var source := Workspace.read_file(path)
		var original: String = substitution["from"]
		if source.count(original) != 1:
			return {"error": Game.L("초안의 수정 지점을 하나로 특정할 수 없습니다.", "The draft could not identify a single edit location.") + " " + path}
		changes[path] = {"exists": true, "before": source, "after": source.replace(original, substitution["to"])}
	var bases: Dictionary = task.get("bases", {})
	for path in task.get("files", {}):
		var target := Workspace.content(task["files"][path])
		if target.is_empty() or not bases.has(path):
			return {"error": Game.L("이 파일의 초안이나 기준 버전을 읽을 수 없습니다.", "The draft or its base could not be read.") + " " + path}
		var exists: bool = bases[path] != ""
		var source := Workspace.content(bases[path]) if exists else ""
		if exists and source.is_empty():
			return {"error": Game.L("기준 파일을 읽을 수 없습니다.", "The base file could not be read.") + " " + path}
		# The agent reads the file as it is now. Players who wrote their own version of an earlier
		# fix still get a draft (a full rewrite of their file); edits made after the draft is
		# generated are still caught as divergent before it is applied.
		var resolved := Workspace.resolve(path)
		if resolved != "" and FileAccess.file_exists(resolved):
			exists = true
			source = Workspace.read_file(path)
		if source != target:
			changes[path] = {"exists": exists, "before": source, "after": target}
	if changes.is_empty():
		return {"error": Game.L("초안에 반영할 변경이 없습니다.", "There are no changes in the draft.")}
	return {"changes": changes, "patch": patch_for(changes)}


static func replacement(path: String, after: String) -> Dictionary:
	var resolved := Workspace.resolve(path)
	if path == "" or resolved == "" or not FileAccess.file_exists(resolved):
		return {"error": Game.L("먼저 교체할 저장소 파일을 선택하세요.", "Choose the repository file to replace.")}
	var before := Workspace.read_file(path)
	if before == after:
		return {"error": Game.L("붙여넣은 코드가 현재 파일과 같습니다.", "The pasted code matches the current file.")}
	var changes := {path: {"exists": true, "before": before, "after": after}}
	return {"changes": changes, "patch": patch_for(changes)}


static func patch_for(changes: Dictionary) -> String:
	var patch := ""
	for path in changes:
		patch += _file_patch(path, changes[path])
	return patch


static func divergent_files(changes: Dictionary) -> PackedStringArray:
	var divergent := PackedStringArray()
	for path in changes:
		var resolved := Workspace.resolve(path)
		var file: Dictionary = changes[path]
		if resolved == "" or FileAccess.file_exists(resolved) != file["exists"] or Workspace.read_file(path) != file["before"]:
			divergent.append(path)
	return divergent


static func _file_patch(path: String, change: Dictionary) -> String:
	var prior := _lines(change["before"])
	var next := _lines(change["after"])
	var first := 0
	while first < mini(prior.size(), next.size()) and prior[first] == next[first]:
		first += 1
	var end_before := prior.size()
	var end_after := next.size()
	while end_before > first and end_after > first and prior[end_before - 1] == next[end_after - 1]:
		end_before -= 1
		end_after -= 1
	var start := maxi(0, first - 3)
	var end_context := mini(prior.size() - end_before, 3)
	var old_count := end_before + end_context - start
	var new_count := end_after + end_context - start
	var before_path := JSON.stringify("a/" + path)
	var after_path := JSON.stringify("b/" + path)
	var out := "diff --git %s %s\n" % [before_path, after_path]
	if not change["exists"]:
		out += "new file mode 100644\n"
	out += "--- %s\n+++ %s\n" % [before_path if change["exists"] else "/dev/null", after_path]
	out += "@@ -%d,%d +%d,%d @@\n" % [start + (1 if old_count > 0 else 0), old_count, start + (1 if new_count > 0 else 0), new_count]
	for i in range(start, first):
		out += _patch_line(" ", prior[i])
	for i in range(first, end_before):
		out += _patch_line("-", prior[i])
	for i in range(first, end_after):
		out += _patch_line("+", next[i])
	for i in range(end_before, end_before + end_context):
		out += _patch_line(" ", prior[i])
	return out


static func _lines(text: String) -> PackedStringArray:
	var lines := text.split("\n")
	for i in range(lines.size() - 1):
		lines[i] += "\n"
	if lines[-1] == "":
		lines.remove_at(lines.size() - 1)
	return lines


static func _patch_line(prefix: String, line: String) -> String:
	return prefix + line if line.ends_with("\n") else prefix + line + "\n\\ No newline at end of file\n"
