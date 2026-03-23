extends Node

signal opened
signal closed
signal url_changed(url: String)
signal page_loaded(url: String)
signal error(message: String)
signal message_received(data: Variant)

var _is_open := false
var _poll_timer := 0.0
var _cmd_index := 0

const POLL_INTERVAL := 0.3
const CMD_FILE := "webview_cmd.json"
const EVENTS_FILE := "webview_events.json"
const DEBUG := true


func _get_docs_dir() -> String:
	if OS.get_name() != "iOS":
		return OS.get_user_data_dir()
	var path := OS.get_user_data_dir()
	if path.ends_with("Documents"):
		return path
	# Godot 4.0-4.3: может вернуть Documents напрямую
	# Godot 4.4+: тоже Documents, но на всякий случай фоллбэк
	var base := path
	for i in 10:
		var parent := base.get_base_dir()
		if parent == base or parent == "" or parent == "/":
			break
		base = parent
		if base.ends_with("Documents"):
			return base
	# Крайний фоллбэк — контейнер/Documents
	var container := path
	for i in 10:
		var parent := container.get_base_dir()
		if parent == container or parent == "":
			break
		if container.get_file() == "Library" or container.get_file() == "Documents":
			return parent.path_join("Documents")
		container = parent
	_log("WARN: не удалось найти Documents, использую user_data_dir")
	return path


func open(url: String, opts: Dictionary = {}) -> void:
	if not _is_ios():
		_log("заглушка — не iOS, open(%s) пропущен" % url)
		return
	if _is_open:
		_log("уже открыт, пропуск")
		return
	_cmd_index += 1
	var cmd := {
		"action": "open",
		"url": url,
		"cmd_id": _cmd_index,
		"fullscreen": opts.get("fullscreen", true),
		"close_delay": opts.get("close_delay", 0),
		"auto_dismiss": opts.get("auto_dismiss", 0),
		"show_close_btn": opts.get("show_close_btn", true),
		"show_loading": opts.get("show_loading", true),
		"transparent_bg": opts.get("transparent_bg", false),
		"size_x": opts.get("size", Vector2(0.9, 0.8)).x,
		"size_y": opts.get("size", Vector2(0.9, 0.8)).y,
		"position": opts.get("position", "center"),
		"corner_radius": opts.get("corner_radius", 16),
		"bg_color": _color_to_dict(opts.get("bg_color", Color.BLACK)),
		"overlay_alpha": opts.get("overlay_alpha", 0.5),
		"user_agent": opts.get("user_agent", ""),
		"js_on_load": opts.get("js_on_load", ""),
		"custom_headers": opts.get("custom_headers", {}),
		"bounce": opts.get("bounce", true),
		"zoom": opts.get("zoom", false),
		"media_playback_requires_user_action": opts.get("media_playback_requires_user_action", true),
		"clear_cache": opts.get("clear_cache", false),
	}
	if _write_cmd(cmd):
		_is_open = true
		opened.emit()
		_log("open(%s) -> cmd_id=%d" % [url, _cmd_index])


func close() -> void:
	if not _is_ios() or not _is_open:
		return
	_cmd_index += 1
	_write_cmd({"action": "close", "cmd_id": _cmd_index})
	_is_open = false
	closed.emit()
	_log("close()")


func evaluate_js(code: String) -> void:
	if not _is_ios() or not _is_open:
		return
	_cmd_index += 1
	_write_cmd({"action": "eval_js", "code": code, "cmd_id": _cmd_index})


func load_url(url: String) -> void:
	if not _is_ios() or not _is_open:
		return
	_cmd_index += 1
	_write_cmd({"action": "load_url", "url": url, "cmd_id": _cmd_index})


func go_back() -> void:
	if not _is_ios() or not _is_open:
		return
	_cmd_index += 1
	_write_cmd({"action": "go_back", "cmd_id": _cmd_index})


func go_forward() -> void:
	if not _is_ios() or not _is_open:
		return
	_cmd_index += 1
	_write_cmd({"action": "go_forward", "cmd_id": _cmd_index})


func reload() -> void:
	if not _is_ios() or not _is_open:
		return
	_cmd_index += 1
	_write_cmd({"action": "reload", "cmd_id": _cmd_index})


func is_open() -> bool:
	return _is_open


func _process(delta: float) -> void:
	if not _is_ios():
		return
	_poll_timer += delta
	if _poll_timer < POLL_INTERVAL:
		return
	_poll_timer = 0.0
	_read_events()


func _write_cmd(cmd: Dictionary) -> bool:
	var dir := _get_docs_dir()
	var path := dir.path_join(CMD_FILE)
	var json := JSON.stringify(cmd)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var err := FileAccess.get_open_error()
		push_error("WebView: запись %s не удалась, ошибка %d" % [path, err])
		error.emit("Ошибка записи cmd: %d" % err)
		return false
	file.store_string(json)
	file.flush()
	file.close()
	# Записываем маркер для DispatchSource
	var marker := FileAccess.open(dir.path_join(".webview_signal"), FileAccess.WRITE)
	if marker:
		marker.store_string(str(_cmd_index))
		marker.flush()
		marker.close()
	return true


func _read_events() -> void:
	var path := _get_docs_dir().path_join(EVENTS_FILE)
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	DirAccess.remove_absolute(path)
	if text.is_empty():
		return
	var json := JSON.new()
	if json.parse(text) != OK:
		_log("битый JSON events: %s" % text.left(200))
		return
	# Поддержка массива событий (batch)
	var events: Array
	if json.data is Array:
		events = json.data
	elif json.data is Dictionary:
		events = [json.data]
	else:
		return
	for ev in events:
		if ev is not Dictionary:
			continue
		_process_event(ev)


func _process_event(data: Dictionary) -> void:
	var event: String = data.get("event", "")
	match event:
		"opened":
			_is_open = true
			_log("event: opened")
		"closed":
			_is_open = false
			closed.emit()
			_log("event: closed")
		"loaded":
			var url: String = data.get("url", "")
			page_loaded.emit(url)
			_log("event: loaded %s" % url)
		"url_changed":
			var url: String = data.get("url", "")
			url_changed.emit(url)
		"error":
			var msg: String = data.get("message", "Unknown error")
			error.emit(msg)
			_is_open = false
			_log("event: error — %s" % msg)
		"js_result":
			var result = data.get("result", null)
			message_received.emit(result)
			_log("event: js_result")
		"message":
			var payload = data.get("data", null)
			message_received.emit(payload)
			_log("event: message from JS")
		_:
			_log("event: неизвестный '%s'" % event)


func _color_to_dict(c: Color) -> Dictionary:
	return {"r": c.r, "g": c.g, "b": c.b, "a": c.a}


func _is_ios() -> bool:
	return OS.get_name() == "iOS"


func _log(msg: String) -> void:
	if DEBUG:
		print("[WebView GD] %s" % msg)
