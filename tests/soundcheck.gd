extends SceneTree
## Records the game's own mix while the truck idles, drives the east road into the puddle, churns
## deep snow, labours held in place, winches and runs out of fuel; saves it as a WAV and prints
## how loud each part was, so the sound can be heard and measured without playing:
##   godot --headless --path . -s res://tests/soundcheck.gd -- --out=<file.wav>   (./godot.sh soundcheck)
## Runs in real time, not at a fixed frame rate: the audio thread mixes on the wall clock.

var out := OS.get_user_data_dir().path_join("soundcheck.wav")
var world
var rec := AudioEffectRecord.new()
var parts: Array[Dictionary] = []  # {name, at (s)}
var t0 := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
	_run.call_deferred()


func _run() -> void:
	world = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.hud.set_help(Hud.Help.OFF)
	await _wait(1.0)
	var v: Vehicle = world.vehicle
	AudioServer.add_bus_effect(0, rec)
	rec.set_recording_active(true)
	t0 = Time.get_ticks_msec()

	_part("idle at the depot")
	await _wait(3.0)
	_part("the east road, 2WD, into the puddle")
	v.drive_along(world.roads[0].slice(1))
	await _wait(18.0)
	_part("deep snow, 4x4")
	_place(Vector2(-52.0, -40.0), -PI * 0.5)
	await _wait(1.0)
	v.awd = true
	v.drive_along(PackedVector2Array([Vector2(-22.0, -40.0)]), 6.0)
	await _wait(6.0)
	_part("held, full throttle, 4x4")
	v.autodrive = false
	v.freeze = true
	Input.action_press(&"accelerate")
	await _wait(3.0)
	_part("held, full throttle, 2WD: the rear wheels spin")
	v.awd = false
	await _wait(2.0)
	_part("throttle up")
	Input.action_release(&"accelerate")
	await _wait(1.5)
	v.freeze = false
	_part("winch")
	_place(Vector2(-40.0, -60.0), 0.0)
	await _wait(1.5)
	v.winch.toggle()
	v.winch.auto_reel = true
	await _wait(4.0)
	v.winch.auto_reel = false
	v.winch.toggle()
	await _wait(1.0)
	_part("empty tank")
	v.fuel = 0.0
	await _wait(3.0)

	rec.set_recording_active(false)
	var wav := rec.get_recording()
	wav.save_to_wav(out)
	_report(wav)
	world.free()
	OS.delay_msec(100)  # the audio thread lets go of what it played, or it leaks at exit
	quit()


func _part(part_name: String) -> void:
	parts.append({"name": part_name, "at": (Time.get_ticks_msec() - t0) / 1000.0})


func _wait(sec: float) -> void:
	var end := Time.get_ticks_msec() + int(sec * 1000.0)
	while Time.get_ticks_msec() < end:
		await physics_frame


func _place(p: Vector2, yaw: float) -> void:
	var v: Vehicle = world.vehicle
	v.autodrive = false
	v.teleport(Vector3(p.x, world.land.home.get_height(p.x, p.y) + 1.2, p.y), yaw)


## Each part's loudness: RMS and peak of the 16-bit stereo recording, in dBFS.
func _report(wav: AudioStreamWAV) -> void:
	var data := wav.data
	var rate := wav.mix_rate
	var frames := data.size() / 4
	print("%s  %.1f s" % [out, float(frames) / rate])
	for i in parts.size():
		var a := int(parts[i].at * rate)
		var b := int(parts[i + 1].at * rate) if i + 1 < parts.size() else frames
		var sum := 0.0
		var peak := 0
		var n := 0
		for f in range(a, b, 2):
			for ch in 2:
				var s := data.decode_s16(f * 4 + ch * 2)
				sum += float(s) * s
				peak = maxi(peak, absi(s))
			n += 2
		print("%5.1f s  RMS %5.1f dB  peak %5.1f dB  %s" % [parts[i].at, linear_to_db(sqrt(sum / maxi(n, 1)) / 32768.0),
			linear_to_db(peak / 32768.0), parts[i].name])
