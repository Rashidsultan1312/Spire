extends Node

signal opened
signal closed
signal error(message: String)

var _is_open := false
var _poll_timer := 0.0
var _warned := false

const POLL_INTERVAL := 0.5
const CMD_FILE := "webview_cmd.json"
const EVENTS_FILE := "webview_events.json"


func _get_base_dir() -> String:
	if OS.get_name() == "iOS":
		var path := OS.get_user_data_dir()
		while not path.ends_with("Documents") and path != "/" and path != "":
			path = path.get_base_dir()
		if path == "/" or path == "":
			path = OS.get_user_data_dir()
		return path
	return OS.get_user_data_dir()


func open(url: String, options: Dictionary = {}) -> void:
	if not _is_ios():
		if not _warned:
			_warned = true
			push_warning("WebView: только iOS, на этой платформе — заглушка")
		return

	if _is_open:
		print("WebView: уже открыт, пропускаю")
		return

	print("WebView: открываю %s -> %s" % [url, _get_base_dir()])
	var cmd := {
		"action": "open",
		"url": url,
		"close_delay": options.get("close_delay", 0),
		"auto_dismiss": options.get("auto_dismiss", 0),
		"fullscreen": options.get("fullscreen", true),
		"position": options.get("position", "center"),
		"size_x": options.get("size", Vector2(0.9, 0.7)).x,
		"size_y": options.get("size", Vector2(0.9, 0.7)).y,
		"bg_r": options.get("background_color", Color.BLACK).r,
		"bg_g": options.get("background_color", Color.BLACK).g,
		"bg_b": options.get("background_color", Color.BLACK).b,
		"show_loading": options.get("show_loading", true),
	}
	_write_cmd(cmd)
	_is_open = true
	opened.emit()


func close() -> void:
	if not _is_ios():
		return
	_write_cmd({"action": "close"})
	_is_open = false
	closed.emit()


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


func _write_cmd(cmd: Dictionary) -> void:
	var path := _get_base_dir().path_join(CMD_FILE)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(cmd))
		file.close()
		print("WebView: записано в %s" % path)
	else:
		push_error("WebView: не удалось записать в %s (ошибка %d)" % [path, FileAccess.get_open_error()])


func _read_events() -> void:
	var path := _get_base_dir().path_join(EVENTS_FILE)
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	if text.is_empty():
		DirAccess.remove_absolute(path)
		return

	var json := JSON.new()
	if json.parse(text) != OK:
		DirAccess.remove_absolute(path)
		return
	DirAccess.remove_absolute(path)
	if not json.data is Dictionary:
		return
	var data: Dictionary = json.data
	var event: String = data.get("event", "")
	match event:
		"closed":
			_is_open = false
			closed.emit()
		"error":
			var msg: String = data.get("message", "Unknown error")
			error.emit(msg)
			_is_open = false


func _is_ios() -> bool:
	return OS.get_name() == "iOS"
