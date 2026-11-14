extends RefCounted
## The gearbox shifted by hand (docs/plan.md §8, §12): auto reaches today's top speeds in its top
## gear; in manual each gear tops out at its own speed and shifting up goes on; in manual, first
## gear of low range gets through the Polissia bog where auto spins and shifts up; the sound's
## gear is the gearbox's.

const BOG := [Vector2(-2.0, -42.0), Vector2(-28.0, -27.0)]  # Polissia: the mud of the lake's shore (test_trucks)


## A truck whose pedals and wheel the test holds.
class Held extends Vehicle:
	func _read_input() -> void:
		pass


func test_auto_reaches_todays_top_speed_in_its_top_gear(t: TCase) -> void:
	var vp := _flat(t)
	var v := _held(vp, TruckSpec.pickup())
	await t.ticks(60)
	v.throttle_input = 1.0
	var top := 0.0
	var gears := []
	for tick in 60 * 15:
		await t.tree.physics_frame
		top = maxf(top, v.forward_speed)
		if gears.is_empty() or gears[-1] != v.gear:
			gears.append(v.gear)
	t.ok(top > 13.0 and top <= 18.0, "auto flat out: %.1f m/s (13.3 before the gearbox)" % top)
	t.eq(gears, [1, 2, 3, 4], "auto's gears on the way up")
	t.eq(v.gear_text(), "A4", "the HUD's gear")
	t.note = "%.1f m/s, gears %s" % [top, gears]
	vp.free()


func test_in_manual_each_gear_tops_out_at_its_own_speed(t: TCase) -> void:
	var vp := _flat(t)
	var v := _held(vp, TruckSpec.pickup())
	await t.ticks(60)
	v.toggle_manual()
	t.ok(v.manual and v.gear == 1 and v.gear_text() == "M1", "N does not go to manual in first: %s" % v.gear_text())
	v.shift(-1)
	t.eq(v.gear_text(), "N", "a gear down from first")
	v.throttle_input = 1.0
	await t.ticks(60)
	t.ok(absf(v.forward_speed) < 0.2, "in neutral it drives: %.1f m/s" % v.forward_speed)
	v.shift(1)
	await t.ticks(60 * 5)
	var first := v.forward_speed
	t.ok(first <= v.gear_top(1) + 0.1 and first > v.gear_top(1) * 0.7, "first gear tops out at %.1f m/s, its top %.1f" % [first, v.gear_top(1)])
	v.shift(1)
	v.shift(1)
	await t.ticks(60 * 5)
	t.ok(v.forward_speed > v.gear_top(2), "in third, it does not go on past second's top: %.1f m/s" % v.forward_speed)
	t.eq(v.gear_text(), "M3", "the HUD's gear")
	t.ok(v.audio.gear == 3, "the sound is in gear %d" % v.audio.gear)
	t.note = "first tops out at %.1f m/s, third passes %.1f" % [first, v.gear_top(2)]
	vp.free()


func test_the_sounds_gear_is_the_gearboxs(t: TCase) -> void:
	var vp := _flat(t)
	var v := _held(vp, TruckSpec.pickup())
	await t.ticks(60)
	v.throttle_input = 1.0
	var apart := 0
	for tick in 60 * 10:
		await t.tree.physics_frame
		if tick > 2 and v.audio.gear != v.gear:
			apart += 1
	t.ok(apart <= 2, "the sound's gear differed from the gearbox's on %d ticks" % apart)
	vp.free()


func test_first_gear_of_low_range_crawls_through_what_auto_spins_on(t: TCase) -> void:
	var land: Land = t.world.land
	var origin := Vector2.INF
	for tile in land.tiles:
		if tile.valley.id == "polissia":
			origin = tile.origin
	if not t.ok(origin != Vector2.INF, "no Polissia on the map"):
		return
	var a: Vector2 = BOG[0] + origin
	var b: Vector2 = BOG[1] + origin
	var made := {}
	var shifts := {}
	for mode in ["auto", "manual"]:
		var v := Held.new()
		v.spec = TruckSpec.pickup()
		v.land = land
		v.position = Vector3(a.x, land.get_height(a.x, a.y) + 1.5, a.y)
		v.rotation.y = atan2(-(b - a).x, -(b - a).y)
		t.world.add_child(v)
		await t.ticks(90)
		v.low_range = true
		v.awd = false
		if mode == "manual":
			v.toggle_manual()
		v.throttle_input = 1.0
		var top := 1
		for tick in 60 * 12:
			await t.tree.physics_frame
			top = maxi(top, v.gear)
			v.steer_input = clampf(-(Vector2(-v.global_transform.basis.z.x, -v.global_transform.basis.z.z)).angle_to(b - Vector2(v.global_position.x, v.global_position.z)) * 1.6, -1.0, 1.0)
		made[mode] = (Vector2(v.global_position.x, v.global_position.z) - a).dot((b - a).normalized())
		shifts[mode] = top
		v.free()
	t.ok(shifts.auto == 2, "auto did not shift up spinning in the bog: top gear %d" % shifts.auto)
	t.eq(shifts.manual, 1, "manual left first gear")
	t.ok(made.manual > made.auto + 2.0, "first gear of low range should get further than auto: %.1f m against %.1f" % [made.manual, made.auto])
	t.note = "in 12 s, the pickup in 2WD, low range: auto %.1f m (it shifted to L%d), manual L1 %.1f m" % [made.auto, shifts.auto, made.manual]


func _held(vp: SubViewport, spec: TruckSpec) -> Held:
	var v := Held.new()
	v.spec = spec
	v.position = Vector3(0.0, 1.0, 0.0)
	vp.add_child(v)
	return v


## A world of its own with nothing in it but a flat floor 4 km square.
func _flat(t: TCase) -> SubViewport:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(64, 64)
	var floor := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000.0, 1.0, 4000.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.5, 0.0)
	floor.add_child(shape)
	vp.add_child(floor)
	t.tree.root.add_child(vp)
	return vp
