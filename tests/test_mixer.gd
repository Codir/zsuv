extends RefCounted
## The mixer (docs/plan.md §7, §12): it drives as specified, its concrete sets 5 minutes after it
## goes in and is lost, and poured in time it comes off whole.


## A truck whose pedals and wheel the test holds.
class Held extends Vehicle:
	func _read_input() -> void:
		pass


func test_it_drives_as_specified(t: TCase) -> void:
	var s := TruckSpec.mixer()
	t.eq(s.mass, 9000.0, "its mass, empty")
	t.eq(s.cargo_mass.get("concrete", 0.0), 6000.0, "a load of concrete")
	t.eq(s.wheels.size(), 6, "its wheels")
	t.ok(not s.all_wheel and s.wheels.filter(func(w: Dictionary) -> bool: return w.drive2).size() == 4, "6x4")
	t.eq(s.fuel_capacity, 200.0, "its tank")
	t.ok(s.burn > 1.6, "its burn: %.2f" % s.burn)
	t.eq(s.winch_length, 24.0, "its cable")
	var vp := _flat(t)
	var empty := Held.new()
	empty.spec = s
	empty.position = Vector3(0.0, 1.5, 0.0)
	vp.add_child(empty)
	var full := Held.new()
	full.spec = s
	full.position = Vector3(40.0, 1.5, 0.0)
	vp.add_child(full)
	await t.ticks(10)
	t.eq(full.rig_put("concrete"), 1.0, "a load of concrete in its drum")
	t.eq(full.mass, 15000.0, "its mass, loaded")
	await t.ticks(60)
	for v: Held in [empty, full]:
		var down := v.wheels.filter(func(w: Chassis.Wheel) -> bool: return w.contact).size()
		t.eq(down, 6, "wheels on the ground")
		v.throttle_input = 1.0
	var tops := [0.0, 0.0]
	for tick in 60 * 15:
		await t.tree.physics_frame
		tops[0] = maxf(tops[0], empty.forward_speed)
		tops[1] = maxf(tops[1], full.forward_speed)
	t.ok(tops[0] * 3.6 > 40.0 and tops[0] * 3.6 < 50.0, "about 45 km/h flat out: %.0f" % (tops[0] * 3.6))
	t.ok(tops[1] < tops[0] and tops[1] * 3.6 > 25.0, "loaded, it should be slower but still go: %.0f km/h" % (tops[1] * 3.6))
	# Low range climbs where it must: it pulls harder.
	for v: Held in [empty, full]:
		v.throttle_input = 0.0
		v.handbrake = true
	await t.ticks(240)
	full.handbrake = false
	full.low_range = true
	full.throttle_input = 1.0
	var low := 0.0
	for tick in 60 * 5:
		await t.tree.physics_frame
		low = maxf(low, full.forward_speed)
	t.ok(low > s.max_speed_low * 0.7 and low <= s.max_speed_low, "loaded, %.1f m/s flat out in low range" % low)
	t.note = "%.0f km/h empty, %.0f km/h loaded" % [tops[0] * 3.6, tops[1] * 3.6]
	vp.free()


func test_it_carries_concrete_only(t: TCase) -> void:
	var vp := _flat(t)
	var v := Held.new()
	v.spec = TruckSpec.mixer()
	v.position = Vector3(0.0, 1.5, 0.0)
	vp.add_child(v)
	await t.ticks(2)
	for kind in Hold.RESOURCES:
		if kind != "concrete":
			t.eq(v.rig_put(kind), 0.0, "%s in the drum" % kind)
			t.eq(v.load_refusal(kind), "The mixer carries only concrete", "what E says with %s" % kind)
	t.eq(v.load_refusal("concrete"), "", "it takes concrete")
	t.eq(v.rig_put("concrete", 3.0), 1.0, "one load fits")
	t.eq(v.load_refusal("concrete"), "Full", "a second load")
	t.ok(v.spec.hitch_kind == "" and v.spec.tows.is_empty(), "it tows")
	vp.free()


func test_its_concrete_sets_after_5_minutes_and_is_lost(t: TCase) -> void:
	var vp := _flat(t)
	var v := Held.new()
	v.spec = TruckSpec.mixer()
	v.position = Vector3(0.0, 1.5, 0.0)
	vp.add_child(v)
	var said := []
	v.said.connect(func(text: String) -> void: said.append(text))
	await t.ticks(2)
	v.rig_put("concrete")
	var drum := v._drum.transform
	await t.ticks(60)
	t.ok(not v._drum.transform.is_equal_approx(drum), "the drum does not turn with concrete in it")
	t.ok(v.load_text().begins_with("CONCRETE 4:5"), "the HUD's countdown: %s" % v.load_text())
	# The clock is the game's: wind it on to just before the five minutes.
	v.hold.age = Hold.CONCRETE_SETS - 1.0
	t.eq(v.load_text(), "CONCRETE 0:01", "the countdown at the end")
	await t.ticks(30)
	t.eq(v.rig_holding("concrete"), 1.0, "it set early")
	await t.ticks(45)
	t.eq(v.rig_holding("concrete"), 0.0, "it has not set at 5 minutes")
	t.eq(v.mass, v.spec.mass, "its mass after")
	t.ok(said.has("The concrete set"), "nothing said: %s" % [said])
	drum = v._drum.transform
	await t.ticks(30)
	t.ok(v._drum.transform.is_equal_approx(drum), "the drum turns empty")
	vp.free()


func test_poured_in_time_it_comes_off_whole(t: TCase) -> void:
	var vp := _flat(t)
	var v := Held.new()
	v.spec = TruckSpec.mixer()
	v.position = Vector3(0.0, 1.5, 0.0)
	vp.add_child(v)
	await t.ticks(2)
	v.rig_put("concrete")
	v.hold.age = Hold.CONCRETE_SETS - 10.0
	await t.ticks(60)
	t.eq(v.rig_take("concrete", 1.0), 1.0, "poured at a site 9 s before it sets")
	t.ok(v.hold.is_empty() and v.load_text() == "", "the drum is not empty")
	# A second load starts its own clock.
	v.rig_put("concrete")
	t.ok(v.hold.age < 1.0, "the new load's clock: %.0f s" % v.hold.age)
	vp.free()


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
