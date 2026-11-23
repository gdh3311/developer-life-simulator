extends RefCounted
## Runs one external process off the main thread, with a timeout.
## Usage: var r: Dictionary = await ProcJob.new().run("git", ["status"], 10.0)
## Result: { code: int, out: String, err: String, timed_out: bool }

signal _finished(result: Dictionary)

var _thread := Thread.new()      # drains stdout
var _err_thread := Thread.new()  # drains stderr in parallel (avoids pipe deadlock)
var _pid := -1
var _timed_out := false


func run(path: String, args: PackedStringArray, timeout_sec: float) -> Dictionary:
	var info := OS.execute_with_pipe(path, args)
	if info.is_empty():
		return {"code": -1, "out": "", "err": "실행할 수 없습니다: %s" % path, "timed_out": false}
	_pid = info["pid"]
	_err_thread.start(_read_all.bind(info["stderr"]))
	_thread.start(_drain.bind(info["stdio"]))
	var tree := Engine.get_main_loop() as SceneTree
	tree.create_timer(timeout_sec).timeout.connect(_on_timeout)
	return await _finished


func _on_timeout() -> void:
	if _thread.is_alive() and OS.is_process_running(_pid):
		_timed_out = true
		if OS.get_name() == "Windows":
			# Kill the whole tree: the test runner spawns a child process per test file.
			OS.execute("taskkill", ["/T", "/F", "/PID", str(_pid)])
		OS.kill(_pid)


## Worker thread: read stdout until the process closes it, then wait for exit.
func _drain(stdout: FileAccess) -> void:
	var out := _read_all(stdout)
	for i in 100:
		if not OS.is_process_running(_pid):
			break
		OS.delay_msec(10)
	_finish.call_deferred(out, OS.get_process_exit_code(_pid))


func _finish(out: String, code: int) -> void:
	_thread.wait_to_finish()
	var err: String = _err_thread.wait_to_finish()
	_finished.emit({"code": code, "out": out, "err": err, "timed_out": _timed_out})


static func _read_all(f: FileAccess) -> String:
	var bytes := PackedByteArray()
	# A pipe read may return a partial chunk; only an empty read means EOF.
	while true:
		var chunk := f.get_buffer(4096)
		if chunk.is_empty():
			break
		bytes.append_array(chunk)
	return bytes.get_string_from_utf8()
