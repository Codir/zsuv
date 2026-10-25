class_name ErrorTrap
extends Logger
## Collects every error the engine logs, from any thread: script errors (which halt a function
## without failing anything by themselves), shader compile errors and engine errors.
## Register it with OS.add_logger(); warnings are ignored.

var _lock := Mutex.new()
var _lines := PackedStringArray()


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type == ERROR_TYPE_WARNING:
		return
	_lock.lock()
	_lines.append("%s  (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
	_lock.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass


## The errors logged since the last call.
func take() -> PackedStringArray:
	_lock.lock()
	var out := _lines
	_lines = PackedStringArray()
	_lock.unlock()
	return out
