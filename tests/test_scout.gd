extends RefCounted
## The scout (docs/plan.md §7): it drives and turns as specified, takes no load and no trailer,
## and its winch pulls it out.


## A truck whose pedals and wheel the test holds.
class Held extends Vehicle:
	func _read_input() -> void:
		pass


func test_it_drives_and_turns_as_specified(t: TCase) -> void:
	var s := TruckSpec.scout()
	t.eq(s.mass, 1200.0, "its mass")
	t.eq(s.wheels.size(), 4, "its wheels")
	t.ok(s.all_wheel and s.low_mult > 1.0, "4x4 and low range")
	for w in s.wheels:
		t.ok(is_equal_approx(w.radius, 0.36), "a wheel of %.2f m" % w.radius)
	t.eq(s.fuel_capacity, 45.0, "its tank")
	t.ok(is_equal_approx(s.burn, 0.5), "its burn: %.2f" % s.burn)
	t.eq(s.winch_length, 20.0, "its cable")
	t.ok(s.reveal >= 90.0 and s.camera_distance < TruckSpec.pickup().camera_distance and s.engine_pitch > 1.2, "it sees far, its camera sits close, its engine sounds small")
	var vp := _flat(t)
	var v := Held.new()
	v.spec = s
	v.position = Vector3(0.0, 1.5, 0.0)
	vp.add_child(v)
	await t.ticks(60)
	var down := v.wheels.filter(func(w: Chassis.Wheel) -> bool: return w.contact).size()
	t.eq(down, 4, "wheels on the ground")
	v.awd = true
	v.throttle_input = 1.0
	var top := 0.0
	for tick in 60 * 15:
		await t.tree.physics_frame
		top = maxf(top, v.forward_speed)
	t.ok(top * 3.6 > 60.0 and top * 3.6 < 70.0, "about 65 km/h flat out: %.0f" % (top * 3.6))
	t.ok(top > TruckSpec.pickup().max_speed_high * 0.74 * 1.2, "it should be well faster than the pickup")
	v.throttle_input = 0.0
	v.handbrake = true
	await t.ticks(180)
	v.handbrake = false
	var speed := 0.0
	var turn := 0.0
	for tick in 60 * 10:
		await t.tree.physics_frame
		v.steer_input = 1.0
		v.throttle_input = clampf((2.5 - v.forward_speed) * 0.5, 0.0, 1.0)
		if tick >= 60 * 5:
			speed += v.forward_speed
			turn += absf(v.angular_velocity.y)
	var radius := speed / maxf(turn, 0.001)
	t.ok(radius > 4.0 and radius < 5.0, "it turns in about 4.5 m: %.1f" % radius)
	t.note = "%.0f km/h flat out, turns in %.1f m" % [top * 3.6, radius]
	vp.free()


func test_it_takes_no_load_and_no_trailer(t: TCase) -> void:
	t.world.set_truck(TruckSpec.scout())
	var v: Vehicle = t.world.vehicle
	t.eq(v.spec.id, "scout", "driving the scout")
	for kind in Hold.RESOURCES:
		t.eq(v.rig_room(kind), 0.0, "room for %s" % kind)
		t.eq(v.rig_put(kind, 1.0), 0.0, "%s put on" % kind)
		t.eq(v.load_refusal(kind), "The scout carries nothing", "what E says at a yard with %s" % kind)
	t.eq(v.mass, 1200.0, "its mass, empty")
	t.ok(v.spec.tows.is_empty() and v.spec.hitch_kind == "", "it has a hitch")
	# A trailer's coupler right at its back: C does nothing.
	var tr := Trailer.new()
	tr.spec = TrailerSpec.trailer()
	tr.terrain = t.world.terrain
	t.world.add_child(tr)
	var back := v.global_transform * Vector3(0.0, 0.0, 2.3)
	tr.place(Transform3D(v.global_transform.basis, back - v.global_transform.basis * tr.spec.coupler))
	await t.ticks(30)
	t.ok(v.hitch_candidate() == null, "a trailer in reach of its back")
	v.toggle_hitch()
	t.ok(v.trailer == null, "it hitched a trailer")
	tr.free()
	t.world.set_truck(TruckSpec.pickup())


func test_its_winch_pulls_it_out(t: TCase) -> void:
	t.world.set_truck(TruckSpec.scout())
	var v: Vehicle = t.world.vehicle
	var winch := v.winch
	await t.place(Vector2(-40.0, -60.0), 0.0)  # nose-first in deep snow on a slope (test_winch)
	v.fuel = v.spec.fuel_capacity
	t.ok(winch.max_length == 20.0, "its cable: %.0f m" % winch.max_length)
	winch.press()
	t.ok(winch.aiming, "F does not aim")
	winch.press()  # F again: what the winch picks itself
	if not t.ok(winch.attached, "F twice hooks nothing"):
		t.world.set_truck(TruckSpec.pickup())
		return
	var anchor := winch.anchor
	var d0 := winch.mount_position().distance_to(anchor)
	winch.auto_reel = true
	await t.ticks(240)
	winch.auto_reel = false
	var d1 := winch.mount_position().distance_to(anchor)
	t.note = "%.1f m -> %.1f m" % [d0, d1]
	t.ok(d1 < d0 - 1.0, "the scout not pulled: %.1f -> %.1f m" % [d0, d1])
	winch.press()
	t.ok(not winch.attached, "F lets go")
	t.world.set_truck(TruckSpec.pickup())


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
