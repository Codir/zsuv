extends SceneTree
## Runs every tests/test_*.gd against one shared world (scenes/main.tscn).
## A test file extends RefCounted and has `func test_xxx(t: TCase)`; a test may await.
##   godot --headless --fixed-fps 60 --path . -s res://tests/run_tests.gd [-- filter]
## `./godot.sh test [filter]` runs only the files or tests whose name contains the filter.
## A script, shader or engine error logged during a test fails that test (an error halts a GDScript
## function without failing anything by itself); one logged while the world is built fails the run.
## A watchdog ends a run that stops making progress.

const WATCHDOG_S := 4000.0  # game time; the whole suite on the joined map takes over 2400 s of it

var _errors := ErrorTrap.new()
var _current := "building the world"


func _initialize() -> void:
	OS.add_logger(_errors)
	create_timer(WATCHDOG_S).timeout.connect(func() -> void:
		print("TIMEOUT after %d s of game time in %s" % [WATCHDOG_S, _current])
		quit(2))
	_run.call_deferred()


func _run() -> void:
	var filt := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filt = args[0]
	var t0 := Time.get_ticks_msec()
	var scene := load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		print("FAIL scenes/main.tscn does not load")
		quit(1)
		return
	var world := scene.instantiate()
	root.add_child(world)
	for i in 30:
		await physics_frame
	var build_errors := _errors.take()
	if not build_errors.is_empty() or world.get("vehicle") == null or world.get("contracts") == null:
		print("FAIL the world does not build")
		for e in build_errors.slice(0, 12):
			print("       ", e)
		quit(1)
		return
	print("world built in %d ms" % (Time.get_ticks_msec() - t0))

	var passed := 0
	var total := 0
	var files := DirAccess.get_files_at("res://tests")
	files.sort()
	for f in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")):
			continue
		var script = load("res://tests/" + f)
		if script == null or not script.can_instantiate():
			if filt == "" or f.contains(filt):
				print("FAIL ", f, ": does not load")
				total += 1
			continue
		var inst = script.new()
		for m in inst.get_method_list():
			var n: String = m.name
			if not n.begins_with("test_"):
				continue
			if filt != "" and not (f.contains(filt) or n.contains(filt)):
				continue
			total += 1
			var t := TCase.new(f.get_basename() + ":" + n, self, world)
			if m.args.size() != 1:
				print("FAIL ", t.name, ": a test takes exactly one argument, the TCase")
				continue
			_current = t.name
			_errors.take()
			var ms := Time.get_ticks_msec()
			await inst.call(n, t)
			ms = Time.get_ticks_msec() - ms
			for e in _errors.take():
				t.fail("error: " + e)
			if t.failures.is_empty():
				passed += 1
				print("ok   ", t.name, "  (", ms, " ms)", ("  " + t.note) if t.note != "" else "")
			else:
				print("FAIL ", t.name, "  (", ms, " ms)")
				for e in t.failures.slice(0, 12):
					print("       ", e)
				if t.failures.size() > 12:
					print("       ... ", t.failures.size() - 12, " more")
	print("%d/%d tests passed" % [passed, total])
	# A sound still playing at exit leaks its stream: the world goes first, and the audio
	# thread, which runs on the wall clock, gets a moment to let go of what it played.
	world.free()
	OS.delay_msec(100)
	quit(0 if passed == total and total > 0 else 1)
