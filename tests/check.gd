extends SceneTree
## Loads every script under res://scripts and res://tests, and compiles every shader, so a parse
## or compile error anywhere is reported (and the exit code is 1).

func _initialize() -> void:
	var errors := ErrorTrap.new()
	OS.add_logger(errors)
	var bad := 0
	for d in ["res://scripts", "res://tests"]:
		bad += _walk(d)
	for f in DirAccess.get_files_at("res://shaders"):
		if f.ends_with(".gdshader"):
			var shader := load("res://shaders/" + f) as Shader
			if shader == null:
				print("FAILED: res://shaders/", f)
				bad += 1
			else:
				shader.get_rid()  # compiles it, even headless
	var logged := errors.take()
	for e in logged:
		print("ERROR: ", e)
	print("check: ", "OK" if bad == 0 and logged.is_empty() else "%d script(s) failed to load, %d error(s)" % [bad, logged.size()])
	quit(1 if bad or not logged.is_empty() else 0)


func _walk(dir: String) -> int:
	var bad := 0
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			var s = load(dir + "/" + f)
			if s == null or not (s as GDScript).can_instantiate():
				print("FAILED: ", dir + "/" + f)
				bad += 1
	for sub in DirAccess.get_directories_at(dir):
		bad += _walk(dir + "/" + sub)
	return bad
