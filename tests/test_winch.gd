extends RefCounted
## The winch (docs/plan.md §8, §12): it hooks a tree or a rock and pulls the truck towards it;
## aimed (Winch.aim, as the cursor does) it hooks the tree under the ray, not the one it would pick
## itself, beside the truck or behind it; too far, the ground, or ground in between are refused
## with the reason; F twice hooks what it picks itself; hooked to a parked truck it pulls both,
## and the parked one wakes.

const OPEN := Vector2(-60.0, 40.0)  # khutir: open ground off the roads, west of the depot


func test_winch_pulls(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var winch := v.winch
	await t.place(Vector2(-40.0, -60.0), 0.0)
	v.set_cargo(true)
	v.fuel = v.spec.fuel_capacity
	if not t.ok(winch.candidate >= 0, "no anchor in range"):
		return
	t.ok(winch.prompt().begins_with("[F] Winch to anchor"), "prompt: " + winch.prompt())
	var anchor := winch.anchors[winch.candidate]
	var d0 := winch.mount_position().distance_to(anchor)
	winch.toggle()
	t.ok(winch.attached, "attached")
	winch.auto_reel = true
	var max_tension := 0.0
	for i in 240:
		await t.tree.physics_frame
		max_tension = maxf(max_tension, winch.tension)
	winch.auto_reel = false
	var d1 := winch.mount_position().distance_to(anchor)
	t.note = "%.1f m -> %.1f m, peak %.0f kN" % [d0, d1, max_tension / 1000.0]
	t.ok(winch.length < d0 - 2.0, "cable reeled in: %.1f of %.1f m" % [winch.length, d0])
	t.ok(max_tension > 1000.0, "cable never pulled: %.0f N" % max_tension)
	t.ok(d1 < d0 - 1.0, "truck not pulled: %.1f -> %.1f m" % [d0, d1])
	winch.toggle()
	t.ok(not winch.attached, "unhooked")
	v.set_cargo(false)


func test_f_twice_hooks_what_the_winch_picks_itself(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var winch := v.winch
	await t.place(Vector2(-40.0, -60.0), 0.0)
	var picked := winch.candidate
	if not t.ok(picked >= 0, "no anchor in range"):
		return
	winch.press()
	t.ok(winch.aiming and not winch.attached, "F does not start aiming")
	t.ok(winch.prompt().begins_with("Aim with the mouse"), "prompt: " + winch.prompt())
	winch.press()
	t.ok(winch.attached and not winch.aiming, "F again does not hook")
	t.ok(winch.anchor.is_equal_approx(winch.anchors[picked]), "F again hooked another anchor than its own pick")
	winch.press()
	t.ok(not winch.attached, "F does not let go")
	# Esc stops aiming, and does not leave the game.
	winch.press()
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	t.world.get_viewport().push_input(esc)
	await t.tree.process_frame
	t.ok(not winch.aiming and not winch.attached, "Esc does not stop aiming")
	t.ok(is_instance_valid(t.world) and t.world.is_inside_tree(), "Esc while aiming left the game")


func test_aimed_it_hooks_the_tree_under_the_ray_beside_or_behind(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var winch := v.winch
	var notes := PackedStringArray()
	for where in ["beside", "behind"]:
		var done := false
		for tree in _trees(t):
			# The truck 9 m from the tree, the tree off its side or at its back.
			var a: Vector3 = tree.get_meta("anchor")
			var out := Vector2(1.0, 0.0).rotated(float(notes.size() + 1) * 1.3 + a.x)
			var p := Vector2(a.x, a.z) + out * 9.0
			if not _open(t, p):
				continue
			var face := out.rotated(PI * 0.5) if where == "beside" else out  # looking away from the tree
			await t.place(p, atan2(-face.x, -face.y))
			if v.global_transform.basis.y.y < 0.9:
				continue
			var own := winch.candidate_point() if winch.candidate >= 0 else Vector3.INF
			if own.is_equal_approx(a):
				continue  # the winch would pick this one itself
			var r := winch.aim(a + Vector3(0.0, 8.0, 0.0), Vector3.DOWN)
			if not r.ok or not (r.point as Vector3).is_equal_approx(a):
				continue
			var fwd := -v.global_transform.basis.z
			var to := (a - winch.mount_position()).normalized()
			t.ok(r.what == "the tree", "aimed at %s" % r.what)
			t.ok(winch.prompt().begins_with("[Click] Hook the tree") or not winch.aiming, "prompt: " + winch.prompt())
			t.ok(winch.hook_aimed(), "the tree under the ray is not hooked")
			t.ok(winch.attached and winch.anchor.is_equal_approx(a) and winch.anchor_body == null, "hooked the wrong place")
			winch.auto_reel = true
			var d0 := winch.mount_position().distance_to(a)
			await t.ticks(120)
			winch.auto_reel = false
			t.ok(winch.length < d0 - 1.0 and winch.tension > 0.0, "the cable to it does not pull: %.1f of %.1f m" % [winch.length, d0])
			winch.detach()
			notes.append("%s %.0f deg off the nose" % [where, rad_to_deg(acos(clampf(fwd.dot(to), -1.0, 1.0)))])
			done = true
			break
		t.ok(done, "no tree %s the truck to aim at" % where)
	t.note = ", ".join(notes)


func test_too_far_the_ground_and_ground_in_between_are_refused(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var winch := v.winch
	var terrain: Terrain = t.world.land.home  # the home tile sits at the origin
	await t.place(OPEN, 0.0)
	# The ground right ahead.
	var ahead := v.global_transform * Vector3(0.0, 0.0, -6.0)
	var r := winch.aim(ahead + Vector3(0.0, 5.0, 0.0), Vector3.DOWN)
	t.ok(not r.ok and r.reason == Winch.NOTHING, "the ground: %s" % r.reason)
	r = winch.aim(winch.mount_position() + Vector3(0.0, 2.0, 0.0), Vector3.UP)
	t.ok(not r.ok and r.reason == Winch.NOTHING, "the sky: %s" % r.reason)
	t.ok(not winch.hook_aimed() and not winch.attached, "hooked the sky")
	# A tree further than the cable.
	var far: Vector3 = Vector3.INF
	for tree in _trees(t):
		var a: Vector3 = tree.get_meta("anchor")
		var d := winch.mount_position().distance_to(a)
		if d > winch.max_length + 3.0 and d < 60.0:
			far = a
			break
	if t.ok(far != Vector3.INF, "no tree 23-60 m off"):
		r = winch.aim(far + Vector3(0.0, 8.0, 0.0), Vector3.DOWN)
		t.ok(not r.ok and (r.reason as String).begins_with("Too far: ") and (r.reason as String).ends_with("the cable is 20"), "too far: %s" % r.reason)
	# A tree in reach behind a rise: the ground between the winch and it.
	var found := false
	var tries := 0
	for tree in _trees(t):
		var a: Vector3 = tree.get_meta("anchor")
		for k in 8:
			var out := Vector2(1.0, 0.0).rotated(k * TAU / 8.0)
			var p := Vector2(a.x, a.z) + out * 13.0
			var m := Vector3(p.x, terrain.get_height(p.x, p.y) + 0.9, p.y)
			if not _open(t, p) or not winch._ground_between(m, a):
				continue
			tries += 1
			await t.place(p, atan2(out.x, out.y))  # facing the tree
			r = winch.aim(a + Vector3(0.0, 8.0, 0.0), Vector3.DOWN)
			if (r.point as Vector3).is_equal_approx(a) and r.reason == "The ground is in the way":
				found = true
				t.ok(not winch.hook_aimed() and not winch.attached, "hooked through the ground")
			break
		if found or tries >= 8:
			break
	t.ok(found, "no tree behind a rise found in %d tries" % tries)


func test_hooked_to_a_parked_truck_it_pulls_both_and_wakes_it(t: TCase) -> void:
	var w = t.world
	var pickup: Vehicle = w.vehicle
	var winch := pickup.winch
	await t.place(OPEN, 0.0)
	var at := pickup.global_transform * Vector3(0.0, 0.0, -15.0)
	var six: Vehicle = w.park_truck(TruckSpec.scout(), Vector3(at.x, w.land.get_height(at.x, at.z) + 1.5, at.z), 0.0)
	await t.ticks(90)
	six.set_frozen(true)
	var r := winch.aim(six.global_position + Vector3(0.0, 8.0, 0.0), Vector3.DOWN)
	t.ok(r.ok and r.body == six and r.what == "the truck", "aimed at the scout: %s" % r)
	t.ok(winch.hook_aimed() and winch.anchor_body == six, "the scout is not hooked")
	t.ok(not six.freeze and six.hooked_by == winch, "hooked, the scout is still frozen")
	var six_at := six.global_position
	var pickup_at := pickup.global_position
	var d0 := pickup.gap_to(six)
	winch.auto_reel = true
	var peak := 0.0
	for i in 300:
		await t.tree.physics_frame
		peak = maxf(peak, winch.tension)
	winch.auto_reel = false
	var d1 := pickup.gap_to(six)
	t.ok(d1 < d0 - 2.0, "the two not drawn together: %.1f -> %.1f m" % [d0, d1])
	t.ok(six.global_position.distance_to(six_at) > 1.0, "the scout not pulled: %.1f m" % six.global_position.distance_to(six_at))
	t.ok(six.global_position.distance_to(six_at) > pickup.global_position.distance_to(pickup_at), "the pickup came further than the light scout")
	t.ok(peak > 1000.0, "the cable never pulled: %.0f N" % peak)
	t.note = "the gap %.1f -> %.1f m: the scout came %.1f m, the pickup %.1f m, peak %.0f kN" % [d0, d1,
		six.global_position.distance_to(six_at), pickup.global_position.distance_to(pickup_at), peak / 1000.0]
	winch.detach()
	t.ok(six.hooked_by == null, "let go, the scout is still hooked")
	w.fleet.remove(six)
	six.free()


## The trees' trunks still standing, nearest the truck first.
func _trees(t: TCase) -> Array[CollisionShape3D]:
	var p: Vector3 = t.world.vehicle.global_position
	var out: Array[CollisionShape3D] = []
	for pr in t.world.builder.props:
		if pr.kind == "tree" and pr.shape != null and is_instance_valid(pr.shape):
			out.append(pr.shape)
	out.sort_custom(func(a: CollisionShape3D, b: CollisionShape3D) -> bool:
		return a.global_position.distance_squared_to(p) < b.global_position.distance_squared_to(p))
	return out


## Whether a truck can stand at p: on the map, off the roads, on ground no steeper than 1 in 4,
## and no tree or rock within 4 m.
func _open(t: TCase, p: Vector2) -> bool:
	var terrain: Terrain = t.world.land.home  # the home tile sits at the origin
	if maxf(absf(p.x), absf(p.y)) > Terrain.HALF - 12.0 or terrain.road_distance(p) < Terrain.ROAD_HALF_WIDTH + 2.0:
		return false
	var h := terrain.get_height(p.x, p.y)
	for d: Vector2 in [Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3)]:
		if absf(terrain.get_height(p.x + d.x, p.y + d.y) - h) > 0.75:
			return false
	for a in t.world.builder.anchor_points:
		if Vector2(a.x, a.z).distance_to(p) < 4.0:
			return false
	return true
