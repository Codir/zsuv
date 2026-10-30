extends RefCounted
## The trailers and the hitch: each trailer stands still on its own, level and on a slope, its
## wheels on the ground; the pickup backs up to its trailer and C hitches it with no jerk; it pulls
## it down the road at 30 km/h without sway, turns at full lock without jackknifing into the truck,
## holds it on a slope; C unhitches it standing; a load adds its weight; the tow (T) takes both to
## the depot, still hitched and upright.


func test_each_trailer_stands_still(t: TCase) -> void:
	var taken: Array[Vector2] = []
	var stood: Array[Trailer] = []
	var where: Array[String] = []
	for spec in TrailerSpec.all():
		var length := absf(spec.coupler.z) * 2.0 + 1.0
		for slope in [false, true]:
			var spot := _spot(t, 6.0 if slope else -2.0, 12.0 if slope else 2.0, length, taken)
			if not t.ok(not spot.is_empty(), "no %s ground for the %s" % ["sloping" if slope else "level", spec.id]):
				continue
			taken.append(spot[0])
			var kind: String = spec.cargo_mass.keys()[0] if slope else ""  # loaded on the slope
			stood.append(_trailer(t, spec, spot[0], spot[1], kind))
			where.append("%s %s" % [spec.id, ("on %.0f deg" % spot[2]) if slope else "level"])
	await t.ticks(90)
	var from: Array[Vector3] = []
	for tr in stood:
		from.append(tr.global_position)
	await t.ticks(90)
	var notes := PackedStringArray()
	for i in stood.size():
		var tr := stood[i]
		var moved := from[i].distance_to(tr.global_position)
		notes.append("%s %.3f m" % [where[i], moved])
		t.ok(moved < 0.02, "%s moved %.3f m in 1.5 s" % [where[i], moved])
		t.ok(tr.stand_contact, "%s: its stand is off the ground" % where[i])
		for a in tr.axles:
			t.ok(tr.wheels[a.x].contact or tr.wheels[a.y].contact, "%s: an axle in the air" % where[i])
		if where[i].ends_with("level"):
			for w in tr.wheels:
				var m := tr.global_transform * w.mount
				t.ok(w.contact, "%s: the wheel at %s off level ground, %.2f m short of it" % [
					where[i], w.mount, m.y - t.world.terrain.get_height(m.x, m.z) - tr.rest_length - w.radius])
	t.note = ", ".join(notes)
	_free(t, stood)


func test_the_pickup_backs_to_its_trailer_and_c_hitches_it(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var c: Contracts = t.world.contracts
	await t.place(Vector2(c.spawn_pos.x, c.spawn_pos.z), c.spawn_yaw)
	# A farm trailer's eye at the pickup's ball: not a hitch it fits.
	var yaw := v.global_rotation.y
	var farm := _behind(t, TrailerSpec.farm(), v.hitch_point(), yaw)
	await t.ticks(3)
	t.ok(v.hitch_candidate() == null, "the pickup would hitch the farm trailer")
	_free(t, [farm])
	# Its own trailer stands behind it, the coupler 1.5 m short of the ball, 0.25 m aside, turned 8 degrees.
	var b := v.global_transform.basis
	var back := Vector3(b.z.x, 0.0, b.z.z).normalized()
	var side := Vector3(b.x.x, 0.0, b.x.z).normalized()
	var tr := _behind(t, TrailerSpec.trailer(), v.hitch_point() + back * 1.5 + side * 0.25, yaw + deg_to_rad(8.0))
	await t.ticks(60)
	t.ok(v.hitch_candidate() == null, "in reach from 1.5 m")
	var ticks := 0
	while v.hitch_candidate() == null and ticks < 300:
		Input.action_press("brake", 0.35 if -v.forward_speed < 0.6 else 0.0)
		await t.tree.physics_frame
		ticks += 1
	Input.action_release("brake")
	await t.ticks(30)
	t.eq(v.hitch_prompt(), "[C] Hitch the trailer", "prompt at the coupler")
	t.ok(v.prompt_with(c.prompt).ends_with("   [C] Hitch the trailer"), "the bottom line: " + v.prompt_with(c.prompt))
	var gap0 := _gap(v, tr)
	await _press(t, &"hitch")
	if not t.ok(v.trailer == tr and tr.truck == v, "C did not hitch it"):
		_free(t, [tr])
		return
	var fastest := 0.0
	var widest := 0.0
	for i in 60:
		await t.tree.physics_frame
		fastest = maxf(fastest, maxf(v.linear_velocity.length(), tr.linear_velocity.length()))
		widest = maxf(widest, _gap(v, tr))
	t.note = "backed %.1f s; coupler %.2f m off, then %.3f m; fastest %.2f m/s in the first second" % [ticks / 60.0, gap0, widest, fastest]
	t.ok(widest < 0.02, "the coupler and the hitch %.3f m apart" % widest)
	t.ok(fastest < 1.0, "a jerk: %.2f m/s" % fastest)
	t.eq(v.hitch_prompt(), "[C] Unhitch", "prompt hitched")
	_free(t, [tr])


func test_pulls_it_down_the_road_at_30(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var tr := await _hitched(t)
	var start := v.global_position
	var track: Array[Vector3] = []
	var most_angle := 0.0
	var least_up := 1.0
	var down := 0
	var all := 0
	var off := 0.0
	var widest := 0.0
	var top := 0.0
	var ticks := 0
	v.drive_along(t.world.roads[0].slice(1), 30.0 / 3.6)
	while start.distance_to(v.global_position) < 60.0 and ticks < 900:
		await t.tree.physics_frame
		ticks += 1
		top = maxf(top, v.forward_speed)
		track.append(v.global_transform * Vector3(0.0, 0.0, v.spec.wheels[2].mount.z))
		if ticks > 120:  # once it is under way
			most_angle = maxf(most_angle, absf(_angle(v, tr)))
		least_up = minf(least_up, tr.global_transform.basis.y.y)
		widest = maxf(widest, _gap(v, tr))
		for w in tr.wheels:
			down += 1 if w.contact else 0
			all += 1
		if ticks % 15 == 0 and track.size() > 240:
			var axle := tr.global_transform * tr._axle()
			var near := INF
			for q in track.slice(0, track.size() - 5):
				near = minf(near, Vector2(q.x - axle.x, q.z - axle.z).length())
			off = maxf(off, near)
	v.autodrive = false
	var dist := start.distance_to(v.global_position)
	t.note = "%.0f m in %.1f s, top %.0f km/h; it swung %.0f deg at most, its axle %.2f m off the truck's track" % [
		dist, ticks / 60.0, top * 3.6, most_angle, off]
	t.ok(dist >= 60.0, "pulled it only %.0f m in 15 s" % dist)
	t.ok(top * 3.6 > 26.0, "top %.0f km/h" % (top * 3.6))
	t.ok(most_angle < 25.0, "it swayed %.0f deg off the truck's line" % most_angle)
	t.ok(off < 1.0, "its wheels %.2f m off the truck's track" % off)
	t.ok(least_up > 0.85, "it nearly flipped: up.y %.2f" % least_up)
	t.ok(down > all * 0.9, "its wheels on the ground %.0f%% of the time" % (down * 100.0 / all))
	t.ok(widest < 0.05, "the hitch opened %.3f m" % widest)
	_free(t, [tr])


func test_brakes_hold_both_on_a_slope(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var tr := await _hitched(t)
	tr.set_load("double")
	var spot := _spot(t, 7.0, 12.0, 10.0, [])
	if not t.ok(not spot.is_empty(), "no slope for the rig"):
		_free(t, [tr])
		return
	var p: Vector2 = spot[0]
	var f := Vector2(-sin(spot[1]), -cos(spot[1]))
	var notes := PackedStringArray()
	for uphill in [true, false]:
		var yaw: float = spot[1] if uphill else spot[1] + PI
		await t.place(p + f * (2.5 if uphill else -2.5), yaw, 100)
		var v0 := v.global_position
		var t0 := tr.global_position
		await t.ticks(180)
		var dv := v0.distance_to(v.global_position)
		var dt := t0.distance_to(tr.global_position)
		var what := "facing %s %.0f deg" % ["up" if uphill else "down", spot[2]]
		notes.append("%s: %.3f m, %.3f m" % [what, dv, dt])
		t.ok(v.trailer == tr, "%s: came unhitched" % what)
		t.ok(dv < 0.1 and dt < 0.1, "%s: the truck slid %.2f m, the trailer %.2f m in 3 s" % [what, dv, dt])
	t.note = "; ".join(notes)
	_free(t, [tr])


func test_full_lock_does_not_jackknife_into_the_truck(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var tr := await _hitched(t)
	var notes := PackedStringArray()
	for ahead in [true, false]:
		var most := 0.0
		var widest := 0.0
		var broke := false
		Input.action_press("steer_left")
		Input.action_press("accelerate" if ahead else "brake", 0.5)
		for i in 270 if ahead else 180:
			await t.tree.physics_frame
			most = maxf(most, absf(_angle(v, tr)))
			widest = maxf(widest, _gap(v, tr))
			broke = broke or not (v.global_position.is_finite() and tr.global_position.is_finite())
		Input.action_release("steer_left")
		Input.action_release("accelerate")
		Input.action_release("brake")
		var what := "ahead" if ahead else "in reverse"
		notes.append("%s %.0f deg" % [what, most])
		t.ok(not broke, "%s: NaN" % what)
		t.ok(most < (60.0 if ahead else 92.0), "%s: it swung %.0f deg" % [what, most])
		t.ok(widest < 0.05, "%s: the hitch opened %.3f m" % [what, widest])
		t.ok(v.global_transform.basis.y.y > 0.9 and tr.global_transform.basis.y.y > 0.9, "%s: tipped over" % what)
		await t.ticks(40)
	t.note = "at full lock, " + ", ".join(notes)
	_free(t, [tr])


func test_c_unhitches_it_standing(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var tr := await _hitched(t)
	await _press(t, &"hitch")
	t.ok(v.trailer == null and tr.truck == null, "C did not unhitch it")
	await t.ticks(60)
	var p := tr.global_position
	await t.ticks(120)
	var moved := p.distance_to(tr.global_position)
	t.note = "moved %.3f m in 2 s" % moved
	t.ok(moved < 0.02, "it moved %.3f m standing" % moved)
	t.ok(tr.stand_contact, "its stand is off the ground")
	t.eq(v.hitch_prompt(), "[C] Hitch the trailer", "prompt beside it")
	# Driven off, the truck and the trailer collide again.
	v.drive_along(PackedVector2Array([Vector2(v.global_position.x, v.global_position.z) - Vector2(sin(v.global_rotation.y), cos(v.global_rotation.y)) * 8.0]), 3.0)
	await t.ticks(150)
	v.autodrive = false
	t.ok(tr.get_collision_exceptions().is_empty(), "still passing through the truck")
	_free(t, [tr])


func test_a_load_adds_its_weight(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var tr := await _hitched(t)
	var before := _weight(v, tr)
	tr.set_load("double")
	await t.ticks(120)
	var added := _weight(v, tr) - before
	t.eq(tr.mass, 1300.0, "mass loaded")
	t.note = "the wheels carry %.0f N more" % added
	t.ok(absf(added - 900.0 * 9.8) < 900.0, "the wheels carry %.0f N more for 900 kg" % added)
	t.ok(tr._loads["double"].visible, "no crates on it")
	tr.set_load("")
	t.eq(tr.mass, 400.0, "mass unloaded")
	_free(t, [tr])


func test_the_tow_takes_both_to_the_depot(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var c: Contracts = t.world.contracts
	var tr := await _hitched(t)
	var farm: Vector2 = t.world.locations.farm.pos
	await t.place(farm + Vector2(0.0, -4.0), 1.0, 60)
	var money := c.money
	c.recover()
	c.money = money
	await t.ticks(180)
	var from := Vector2(v.global_position.x - c.spawn_pos.x, v.global_position.z - c.spawn_pos.z).length()
	var ok_wheels := tr.wheels.all(func(w: Chassis.Wheel) -> bool: return w.contact)
	t.note = "%.1f m from the depot's spot, the trailer %.0f deg off straight behind" % [from, absf(_angle(v, tr))]
	t.ok(from < 2.0, "the truck is %.1f m from the depot's spot" % from)
	t.ok(v.trailer == tr and _gap(v, tr) < 0.05, "the trailer did not come along hitched")
	t.ok(absf(_angle(v, tr)) < 10.0, "the trailer %.0f deg off straight behind" % absf(_angle(v, tr)))
	t.ok(v.global_transform.basis.y.y > 0.95 and tr.global_transform.basis.y.y > 0.95, "not upright")
	t.ok(ok_wheels, "the trailer's wheels off the ground")
	_free(t, [tr])


## The pickup at the depot with its trailer hitched straight behind, settled.
func _hitched(t: TCase) -> Trailer:
	var v: Vehicle = t.world.vehicle
	var c: Contracts = t.world.contracts
	await t.place(Vector2(c.spawn_pos.x, c.spawn_pos.z), c.spawn_yaw)
	v.fuel = v.spec.fuel_capacity
	var tr := _behind(t, TrailerSpec.trailer(), v.hitch_point(), v.global_rotation.y)
	await t.ticks(20)
	v.hitch(tr)
	await t.ticks(40)
	return tr


## A trailer standing with its coupler at (over) at, facing yaw.
func _behind(t: TCase, spec: TrailerSpec, at: Vector3, yaw: float) -> Trailer:
	var o := at - Basis(Vector3.UP, yaw) * spec.coupler
	return _trailer(t, spec, Vector2(o.x, o.z), yaw)


func _trailer(t: TCase, spec: TrailerSpec, at: Vector2, yaw: float, kind := "") -> Trailer:
	var tr := Trailer.new()
	tr.spec = spec
	tr.terrain = t.world.terrain
	t.world.add_child(tr)
	tr.set_load(kind)
	tr.stand_on(at, yaw)
	return tr


func _free(t: TCase, trailers: Array) -> void:
	var v: Vehicle = t.world.vehicle
	v.unhitch()
	v.autodrive = false
	for tr in trailers:
		(tr as Trailer).free()


## C, through the input map as a player presses it.
func _press(t: TCase, action: StringName) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
	await t.ticks(3)


func _gap(v: Vehicle, tr: Trailer) -> float:
	return v.hitch_point().distance_to(tr.coupler_point())


## The trailer's turn from straight behind the truck, degrees.
func _angle(v: Vehicle, tr: Trailer) -> float:
	var a := -v.global_transform.basis.z
	var b := -tr.global_transform.basis.z
	return rad_to_deg(Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z)))


## What the truck's and the trailer's wheels carry.
func _weight(v: Vehicle, tr: Trailer) -> float:
	var sum := 0.0
	for w in v.wheels + tr.wheels:
		sum += w.load
	return sum


## Ground that rises lo..hi degrees over length metres along some yaw and is as near a plane as
## can be found, clear of the places, the trees and rocks, the truck and the spots taken:
## [point, yaw, degrees], or [] none.
func _spot(t: TCase, lo: float, hi: float, length: float, taken: Array[Vector2]) -> Array:
	var terrain: Terrain = t.world.terrain
	var truck := Vector2(t.world.vehicle.global_position.x, t.world.vehicle.global_position.z)
	var best := []
	var best_warp := 0.15
	for x in range(-104, 105, 4):
		for z in range(-104, 105, 4):
			var p := Vector2(x, z)
			if p.distance_to(truck) < 12.0 or taken.any(func(q: Vector2) -> bool: return p.distance_to(q) < length + 4.0):
				continue
			if t.world.locations.values().any(func(l: Dictionary) -> bool: return p.distance_to(l.pos) < l.radius + length * 0.5 + 4.0):
				continue
			var hm := terrain.get_height(p.x, p.y)
			for k in 8:
				var yaw := k * PI / 4.0
				var f := Vector2(-sin(yaw), -cos(yaw))
				var r := Vector2(f.y, -f.x)
				var a := p + f * length * 0.5
				var b := p - f * length * 0.5
				var along := (terrain.get_height(a.x, a.y) - terrain.get_height(b.x, b.y)) / length
				var deg := rad_to_deg(atan(along))
				if deg < lo or deg > hi:
					continue
				var c1 := p + r * 1.3
				var c2 := p - r * 1.3
				var across := (terrain.get_height(c1.x, c1.y) - terrain.get_height(c2.x, c2.y)) / 2.6
				if absf(across) > 0.05:
					continue
				var warp := 0.0
				for j in 5:
					for s in [-1.3, 0.0, 1.3]:
						var along_m := (j / 4.0 - 0.5) * length
						var q: Vector2 = p + f * along_m + r * s
						warp = maxf(warp, absf(terrain.get_height(q.x, q.y) - (hm + along_m * along + s * across)))
				if warp >= best_warp or _near_anchor(t, a, b):
					continue
				best_warp = warp
				best = [p, yaw, deg]
				if warp < 0.04:
					return best
	return best


## Whether a tree or rock stands within 3 m of the line from a to b.
func _near_anchor(t: TCase, a: Vector2, b: Vector2) -> bool:
	for p in t.world.builder.anchor_points:
		var q := Vector2(p.x, p.z)
		if q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)) < 3.0:
			return true
	return false
