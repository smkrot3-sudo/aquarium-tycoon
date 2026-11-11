extends Node
## A small black box for the game: every engine/script error is appended to user://error_log.txt,
## the player's last actions ("breadcrumbs") are kept in a tiny second file, and a marker file
## says whether the previous run ended abnormally (a crash, as opposed to the app simply being
## put in the background). Settings shows all of it, so a crash report can say what was happening.

const LOG_PATH := "user://error_log.txt"
const CRUMB_PATH := "user://breadcrumbs.txt"
const MARKER_PATH := "user://session_open"
const MAX_LOG_BYTES := 30000
const MAX_CRUMBS := 30

## True when the previous run did not exit cleanly.
var last_run_crashed: bool = false

var _crumbs: Array = []
var _sink: ErrorSink


## Receives every engine error and warning on whatever thread raised it.
class ErrorSink extends Logger:
	var log_path: String = ""
	var _mutex := Mutex.new()
	var _busy: bool = false
	var _last: String = ""
	var _repeats: int = 0

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		if _busy:
			_mutex.unlock()
			return
		_busy = true
		var kind: String = ["error", "warning", "script error", "shader error"][clampi(error_type, 0, 3)]
		var text := "%s:%d (%s) %s %s" % [file.get_file(), line, function, code, rationale]
		if text == _last:
			_repeats += 1
		else:
			if _repeats > 0:
				_append("   (the same message repeated %d more times)" % _repeats)
			_repeats = 0
			_last = text
			_append("[%s] %s %s" % [Time.get_datetime_string_from_system(), kind, text.strip_edges()])
		_busy = false
		_mutex.unlock()

	func _append(line: String) -> void:
		var file := FileAccess.open(log_path, FileAccess.READ_WRITE)
		if file == null:
			file = FileAccess.open(log_path, FileAccess.WRITE)
		if file == null:
			return
		file.seek_end()
		file.store_line(line)
		file.close()


func _ready() -> void:
	last_run_crashed = FileAccess.file_exists(MARKER_PATH)
	_trim_log()
	if last_run_crashed:
		_append_line("[%s] === the previous run ended abnormally; its last actions were: ===" % Time.get_datetime_string_from_system())
		_append_line(_read(CRUMB_PATH))
	_write_marker()
	_sink = ErrorSink.new()
	_sink.log_path = LOG_PATH
	OS.add_logger(_sink)


func _exit_tree() -> void:
	if _sink != null:
		OS.remove_logger(_sink)
	_clear_marker()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			_clear_marker()
		NOTIFICATION_APPLICATION_RESUMED:
			_write_marker()


## Remember something the player just did; the last few are written out so a crash leaves a trail.
func crumb(text: String) -> void:
	_crumbs.append("%s %s" % [Time.get_time_string_from_system(), text])
	while _crumbs.size() > MAX_CRUMBS:
		_crumbs.pop_front()
	var file := FileAccess.open(CRUMB_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_crumbs))
		file.close()


## The tail of the error log plus the last actions, for showing in Settings.
func report(max_chars: int = 1800) -> String:
	var text := _read(LOG_PATH)
	if text.length() > max_chars:
		text = "…" + text.substr(text.length() - max_chars)
	var actions := _read(CRUMB_PATH)
	return text + ("\n--\n" + actions if actions != "" else "")


func clear() -> void:
	for path in [LOG_PATH, CRUMB_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_crumbs.clear()
	last_run_crashed = false


func has_entries() -> bool:
	return _read(LOG_PATH) != ""


static func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _append_line(line: String) -> void:
	var file := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(line)
	file.close()


func _trim_log() -> void:
	var text := _read(LOG_PATH)
	if text.length() > MAX_LOG_BYTES:
		var file := FileAccess.open(LOG_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(text.substr(text.length() - MAX_LOG_BYTES / 2))
			file.close()


func _write_marker() -> void:
	var file := FileAccess.open(MARKER_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("1")
		file.close()


func _clear_marker() -> void:
	if FileAccess.file_exists(MARKER_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(MARKER_PATH))
