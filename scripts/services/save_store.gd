extends RefCounted
## Versioned state files. A validated previous save survives an interrupted replacement.

const VERSION := 1


static func _read_one(path: String, defaults: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "missing"}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {"ok": false, "error": "invalid_json"}
	var raw = parser.data
	if typeof(raw) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_json"}
	var version = raw.get("save_version", 0)
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or version < 0 or version != floor(version):
		return {"ok": false, "error": "invalid_version"}
	if version > VERSION:
		return {"ok": false, "error": "newer_version"}
	if not raw.has("day") or not raw.has("story"):
		return {"ok": false, "error": "invalid_state"}
	for key in defaults:
		if raw.has(key) and typeof(defaults[key]) in [TYPE_DICTIONARY, TYPE_ARRAY, TYPE_STRING, TYPE_BOOL] and typeof(raw[key]) != typeof(defaults[key]):
			return {"ok": false, "error": "invalid_" + key}
	for key in ["day", "minutes", "rank", "money", "condition"]:
		if raw.has(key):
			var value = raw[key]
			if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value != floor(value):
				return {"ok": false, "error": "invalid_" + key}
	if raw["day"] < 1 or raw.get("minutes", 0) < 0 or int(raw.get("rank", 0)) not in [0, 1, 2, 3] or raw.get("condition", 85) < 0 or raw.get("condition", 85) > 100:
		return {"ok": false, "error": "out_of_range"}
	for id in raw["story"]:
		var mission = raw["story"][id]
		if typeof(mission) != TYPE_DICTIONARY or mission.get("status", "") not in ["locked", "active", "done", "skipped"] or typeof(mission.get("obj", {})) != TYPE_DICTIONARY or typeof(mission.get("data", {})) != TYPE_DICTIONARY:
			return {"ok": false, "error": "invalid_mission"}
	for key in ["chat", "issues"]:
		for entry in raw.get(key, []):
			if typeof(entry) != TYPE_DICTIONARY:
				return {"ok": false, "error": "invalid_" + key}
	var data := _merge_defaults(defaults, raw)
	if typeof(data["codehub"]["prs"]) != TYPE_ARRAY:
		return {"ok": false, "error": "invalid_prs"}
	if not _valid_lab(data["request_lab"]):
		return {"ok": false, "error": "invalid_request_lab"}
	data["save_version"] = VERSION
	for key in ["day", "minutes", "rank", "money", "condition"]:
		data[key] = int(data[key])
	return {"ok": true, "data": data, "source": path, "error": ""}


static func _valid_lab(lab: Dictionary) -> bool:
	if typeof(lab.get("opened")) != TYPE_BOOL or typeof(lab.get("evidence")) != TYPE_BOOL or typeof(lab.get("plan")) != TYPE_ARRAY or typeof(lab.get("runs")) != TYPE_ARRAY or typeof(lab.get("latest")) != TYPE_DICTIONARY:
		return false
	for field in lab["plan"]:
		if typeof(field) != TYPE_STRING:
			return false
	for run in lab["runs"]:
		if not _valid_probe(run):
			return false
	return lab["latest"].is_empty() or _valid_probe(lab["latest"])


static func _valid_probe(run) -> bool:
	if typeof(run) != TYPE_DICTIONARY or typeof(run.get("config")) != TYPE_DICTIONARY or typeof(run.get("responses")) != TYPE_ARRAY:
		return false
	for key in ["code_hash", "time"]:
		if typeof(run.get(key)) != TYPE_STRING:
			return false
	for key in ["attempts", "created"]:
		var value = run.get(key)
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)) or value < 0 or value != floor(value):
			return false
	var config: Dictionary = run["config"]
	if config.get("network", "") not in ["fast", "slow"] or typeof(config.get("retry")) != TYPE_BOOL or config.get("keys", "") not in ["same", "new"] or typeof(config.get("clicks")) not in [TYPE_INT, TYPE_FLOAT] or int(config.get("clicks", 0)) not in [1, 2] or config["clicks"] != floor(config["clicks"]) or config.get("version", "") not in ["current", "reported"] or config.get("timing", "sequential") not in ["sequential", "concurrent"]:
		return false
	for response in run["responses"]:
		if typeof(response) != TYPE_DICTIONARY or typeof(response.get("virtualMs")) not in [TYPE_INT, TYPE_FLOAT] or typeof(response.get("key")) != TYPE_STRING or typeof(response.get("orderId")) != TYPE_STRING:
			return false
	return true


static func _merge_defaults(defaults: Dictionary, raw: Dictionary) -> Dictionary:
	var result := defaults.duplicate(true)
	for key in raw:
		if result.has(key) and typeof(result[key]) == TYPE_DICTIONARY and typeof(raw[key]) == TYPE_DICTIONARY:
			result[key] = _merge_defaults(result[key], raw[key])
		else:
			result[key] = raw[key]
	return result


static func read(path: String, defaults: Dictionary) -> Dictionary:
	var primary := _read_one(path, defaults)
	if primary["ok"] or primary["error"] == "newer_version":
		return primary
	var backup := _read_one(path + ".bak", defaults)
	if backup["ok"]:
		backup["recovered"] = true
		return backup
	return {"ok": false, "error": primary["error"], "backup_error": backup["error"]}


static func write(path: String, state: Dictionary, defaults: Dictionary) -> bool:
	var temporary := path + ".tmp"
	var candidate := state.duplicate(true)
	candidate["save_version"] = VERSION
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(candidate, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or not _read_one(temporary, defaults)["ok"]:
		return false
	if FileAccess.file_exists(path):
		var previous := _read_one(path, defaults)
		if previous["error"] == "newer_version":
			return false
		# Do not replace a valid backup with a corrupt primary after recovery.
		var retained := path + (".bak" if previous["ok"] else ".corrupt")
		if FileAccess.file_exists(retained) and DirAccess.remove_absolute(retained) != OK:
			return false
		if DirAccess.rename_absolute(path, retained) != OK:
			return false
	if DirAccess.rename_absolute(temporary, path) != OK:
		return false  # read() can still recover the retained backup after an interruption.
	return true
