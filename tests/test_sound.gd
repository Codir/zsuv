extends RefCounted
## The truck sounds like it drives: the revs climb with the speed and drop at a shift, the engine
## labours at full throttle going nowhere, the tyres crunch snow and squelch mud only when they
## roll, the engine dies on an empty tank, the winch motor runs only while it reels.


func test_every_sound_streams_on_its_bus(t: TCase) -> void:
	var a: TruckAudio = t.world.vehicle.audio
	t.ok(AudioServer.get_bus_index(&"Engine") > 0, "no Engine bus: default_bus_layout.tres")
	t.ok(AudioServer.get_bus_index(&"Sfx") > 0, "no Sfx bus: default_bus_layout.tres")
	var players := a.find_children("*", "AudioStreamPlayer3D", false, false)
	t.eq(players.size(), 5, "players")
	for p: AudioStreamPlayer3D in players:
		# As browser samples, loops restarted 10-80 ms late (Crashcut 0.3.2).
		t.eq(p.playback_type, AudioServer.PLAYBACK_TYPE_STREAM, "%s playback type" % p.stream.resource_path)
	for p in [a.idle, a.growl]:
		t.eq(p.bus, &"Engine", "engine bus")
	for p in [a.motor, a.snow, a.mud]:
		t.eq(p.bus, &"Sfx", "sfx bus")
	for p in [a.idle, a.growl, a.motor]:
		var s := p.stream as AudioStreamOggVorbis
		t.ok(s != null and s.loop, "%s does not loop" % p.stream.resource_path)
	t.eq((a.idle.stream as AudioStreamOggVorbis).get_length(), (a.growl.stream as AudioStreamOggVorbis).get_length(),
		"the two engine loops are one cut")
	for p in [a.snow, a.mud]:
		var r := p.stream as AudioStreamRandomizer
		for i in r.streams_count:
			t.ok(r.get_stream(i) != null, "hit %d of %d missing" % [i + 1, r.streams_count])
	t.eq((a.snow.stream as AudioStreamRandomizer).streams_count, TruckAudio.SNOW_HITS, "snow hits")
	t.eq((a.mud.stream as AudioStreamRandomizer).streams_count, TruckAudio.MUD_HITS, "mud hits")


func test_revs_climb_with_speed_and_drop_at_a_shift(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var a := v.audio
	var c: Contracts = t.world.contracts
	await t.place(Vector2(c.spawn_pos.x, c.spawn_pos.z), c.spawn_yaw)
	v.fuel = Vehicle.FUEL_CAPACITY
	t.ok(a.idle.playing and a.growl.playing, "the engine is not running")
	t.ok(absf(a.idle.pitch_scale - 1.0) < 0.1, "idles at pitch %.2f" % a.idle.pitch_scale)
	v.drive_along(t.world.roads[0].slice(1))
	var top_gear := 1
	var top_pitch := 0.0
	var drops := PackedStringArray()
	var shift_at := -1
	var pitch_at_shift := 0.0
	for i in 600:
		var g := a.gear
		await t.tree.physics_frame
		top_pitch = maxf(top_pitch, a.idle.pitch_scale)
		if a.gear > g and g >= 1:
			top_gear = maxi(top_gear, a.gear)
			shift_at = i
			pitch_at_shift = a.idle.pitch_scale
		elif shift_at >= 0 and i - shift_at == 30:
			drops.append("%d->%d: %.2f->%.2f" % [a.gear - 1, a.gear, pitch_at_shift, a.idle.pitch_scale])
			t.ok(a.idle.pitch_scale < pitch_at_shift - 0.15, "no drop at the shift " + drops[-1])
			shift_at = -1
	v.autodrive = false
	t.note = "top gear %d, top pitch %.2f; %s" % [top_gear, top_pitch, ", ".join(drops)]
	t.ok(top_gear >= 3, "never above gear %d" % top_gear)
	t.ok(top_pitch > 1.8, "top pitch %.2f" % top_pitch)
	t.eq(a.growl.pitch_scale, a.idle.pitch_scale, "both engine layers at one pitch")


## Held where it stands with the throttle down: in 4x4 every wheel grips, the engine labours at
## low revs; on two wheels the rear ones spin and the revs flare.
func test_labours_at_full_throttle_going_nowhere(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var a := v.audio
	var farm: Vector2 = t.world.locations.farm.pos
	await t.place(farm + Vector2(0.0, -4.0), 0.0)
	v.fuel = Vehicle.FUEL_CAPACITY
	t.ok(a.labour < 0.1, "labours at rest: %.2f" % a.labour)
	v.freeze = true
	v.awd = true
	Input.action_press(&"accelerate")
	await t.ticks(60)
	var awd_rpm := a.rpm
	t.ok(a.labour > 0.85, "4x4, full throttle, standing: labour %.2f" % a.labour)
	t.ok(a.rpm < 1400.0, "4x4, full throttle, standing: %.0f rpm" % a.rpm)
	t.ok(a.growl.volume_db > a.idle.volume_db, "the growl %.1f dB under the idle %.1f dB" % [a.growl.volume_db, a.idle.volume_db])
	v.awd = false
	await t.ticks(60)
	t.note = "4x4 %.0f rpm, rear wheels spinning %.0f rpm" % [awd_rpm, a.rpm]
	t.ok(a.rpm > 1700.0, "rear wheels spinning: %.0f rpm" % a.rpm)
	Input.action_release(&"accelerate")
	await t.ticks(90)
	t.ok(a.labour < 0.1, "labours with the throttle up: %.2f" % a.labour)
	t.ok(a.rpm < 900.0, "back to idle: %.0f rpm" % a.rpm)
	v.freeze = false


func test_tyres_crunch_snow_and_squelch_mud_when_they_roll(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var a := v.audio
	v.fuel = Vehicle.FUEL_CAPACITY
	# Deep snow, standing, then rolling.
	var dir := Vector2(1.0, 0.0)
	var p := _snowfield(t.world.terrain, dir)
	if not t.ok(p != Vector2.INF, "no 30 m of deep snow without mud"):
		return
	await t.place(p, _yaw(dir))
	var snow0 := a.snow_hits
	var mud0 := a.mud_hits
	await t.ticks(120)
	t.eq(a.snow_hits - snow0, 0, "crunches standing in snow")
	v.awd = true
	v.drive_along(PackedVector2Array([p + dir * 30.0]), 6.0)
	snow0 = a.snow_hits
	await t.ticks(180)
	v.autodrive = false
	var snow := a.snow_hits - snow0
	t.ok(snow >= 6, "%d crunches in 3 s through snow" % snow)
	t.eq(a.mud_hits - mud0, 0, "squelches in snow")
	# Through the puddle on the east road.
	var puddle := Vector2(8.0, -96.0)
	var from := Vector2(-14.0, -89.0)
	await t.place(from, _yaw(puddle - from))
	mud0 = a.mud_hits
	v.drive_along(PackedVector2Array([puddle, Vector2(25.0, -89.0)]), 7.0)
	await t.ticks(300)
	v.autodrive = false
	v.awd = false
	var mud := a.mud_hits - mud0
	t.note = "%d crunches in snow, %d squelches through the puddle" % [snow, mud]
	t.ok(mud >= 3, "%d squelches through the puddle" % mud)


func test_the_engine_dies_on_an_empty_tank(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var a := v.audio
	var farm: Vector2 = t.world.locations.farm.pos
	await t.place(farm + Vector2(0.0, -4.0), 0.0)
	v.fuel = 0.0
	await t.ticks(150)
	t.ok(not a.running, "runs on an empty tank")
	t.ok(not a.idle.playing and not a.growl.playing, "still heard on an empty tank")
	v.fuel = Vehicle.FUEL_CAPACITY
	await t.ticks(30)
	t.ok(a.idle.playing and a.growl.playing, "does not start again with fuel")


func test_the_winch_motor_runs_only_while_reeling(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var a := v.audio
	var winch := v.winch
	await t.place(Vector2(-40.0, -60.0), 0.0)
	v.fuel = Vehicle.FUEL_CAPACITY
	if not t.ok(winch.candidate >= 0, "no anchor in range"):
		return
	winch.toggle()
	await t.ticks(30)
	t.ok(not a.motor.playing, "the motor runs hooked on but not reeling")
	winch.auto_reel = true
	var lowest := 2.0
	var quiet := 0
	for i in 120:
		await t.tree.physics_frame
		if i > 10 and not a.motor.playing:
			quiet += 1
		lowest = minf(lowest, a.motor.pitch_scale)
	winch.auto_reel = false
	t.eq(quiet, 0, "ticks the motor was quiet while reeling")
	await t.ticks(30)
	t.note = "motor pitch down to %.2f under the strain" % lowest
	t.ok(lowest < 1.0, "the motor never strains: pitch %.2f" % lowest)
	t.ok(not a.motor.playing, "the motor runs on after reeling")
	winch.toggle()


## Where 30 m along dir are deep snow and no mud, on gentle ground; INF if nowhere.
func _snowfield(terrain: Terrain, dir: Vector2) -> Vector2:
	for z in range(-100, 100, 4):
		for x in range(-100, 100, 4):
			var p := Vector2(x, z)
			var ok := absf(terrain.get_height(p.x + dir.x * 30.0, p.y + dir.y * 30.0) - terrain.get_height(p.x, p.y)) < 2.0
			for k in range(-4, 34, 2):
				var q := p + dir * k
				var s := terrain.sample(Vector3(q.x, 0.0, q.y))
				ok = ok and s.snow > 0.3 and s.mud < 0.05
			if ok:
				return p
	return Vector2.INF


## The yaw that faces the truck along dir on the XZ plane (it looks down -Z).
func _yaw(dir: Vector2) -> float:
	return atan2(-dir.x, -dir.y)
