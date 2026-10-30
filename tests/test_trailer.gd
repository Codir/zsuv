extends RefCounted
## The trailers and the hitch: each trailer stands still on its own, level and on a slope, its
## wheels on the ground; the pickup backs up to its trailer and C hitches it with no jerk; it pulls
## it down the road at 30 km/h without sway, turns at full lock without jackknifing into the truck,
## holds it on a slope; C unhitches it standing; a load adds its weight; the tow (T) takes both to
## the depot, the trailer to a spot of its own, and brings back a trailer left on its side; R keeps
## the trailer hitched as it is swung when there is no room for it straight behind, lets it go when
## there is room for neither, and sets the truck down clear of it.


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
	await t.place(farm + Vector2(0.0, -4.0), 0.0, 60)
	t.ok(v.trailer == tr, "the trailer did not come along to the farm")
	var money := c.money
	c.recover()
	c.money = money
	await t.ticks(180)
	var from := Vector2(v.global_position.x - c.spawn_pos.x, v.global_position.z - c.spawn_pos.z).length()
	var depot: Vector2 = t.world.locations.depot.pos
	var at := Vector2(tr.global_position.x, tr.global_position.z)
	var ok_wheels := tr.wheels.all(func(w: Chassis.Wheel) -> bool: return w.contact)
	t.note = "the truck %.1f m from the depot's spot, the trailer %.0f m from the depot" % [from, at.distance_to(depot)]
	t.ok(from < 2.0, "the truck is %.1f m from the depot's spot" % from)
	t.ok(v.trailer == null and tr.truck == null, "the trailer is still hitched")
	t.ok(at.distance_to(depot) < 45.0, "the trailer is %.0f m from the depot" % at.distance_to(depot))
	t.ok(t.world.terrain.road_distance(at) > Terrain.ROAD_HALF_WIDTH, "the trailer stands on a road")
	t.ok(v.global_transform.basis.y.y > 0.95 and tr.global_transform.basis.y.y > 0.95, "not upright")
	t.ok(ok_wheels, "the trailer's wheels off the ground")
	_free(t, [tr])


func test_the_tow_brings_back_a_trailer_left_on_its_side(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var c: Contracts = t.world.contracts
	var farm: Vector2 = t.world.locations.farm.pos
	var tr := _trailer(t, TrailerSpec.farm(), farm + Vector2(8.0, 0.0), 0.0, "bulk")
	await t.ticks(2)
	tr.place(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), tr.global_position + Vector3(0.0, 1.0, 0.0)))
	await t.ticks(120)
	t.ok(tr.global_transform.basis.y.y < 0.7, "the farm trailer did not fall on its side")
	c.trailers.append(tr)
	await t.place(farm + Vector2(0.0, -4.0), 0.0, 30)
	var money := c.money
	c.recover()
	c.money = money
	await t.ticks(180)
	var depot: Vector2 = t.world.locations.depot.pos
	var at := Vector2(tr.global_position.x, tr.global_position.z)
	t.note = "the trailer %.0f m from the depot, up %.2f" % [at.distance_to(depot), tr.global_transform.basis.y.y]
	t.ok(at.distance_to(depot) < 45.0, "the trailer is %.0f m from the depot" % at.distance_to(depot))
	t.ok(tr.global_transform.basis.y.y > 0.95, "the trailer is not upright")
	t.eq(tr.load, "bulk", "its load")
	c.trailers.erase(tr)
	_free(t, [tr])


func test_r_keeps_the_trailer_swung_where_there_is_no_room_straight_behind(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var c: Contracts = t.world.contracts
	await t.place(Vector2(c.spawn_pos.x, c.spawn_pos.z), c.spawn_yaw)
	var yaw := v.global_rotation.y
	var tr := _behind(t, TrailerSpec.trailer(), v.hitch_point(), yaw + deg_to_rad(60.0))
	await t.ticks(20)
	v.hitch(tr)
	await t.ticks(20)
	# A post straight behind the hitch, where the trailer is not.
	var post := _wall(t, Vector3(1.0, 3.0, 0.5), Transform3D(v.global_transform.basis, v.hitch_point() + v.global_transform.basis.z * 2.5))
	await t.ticks(2)
	v.reset_upright()
	await t.ticks(60)
	var z := v.global_transform.basis.z
	var tz := tr.global_transform.basis.z
	var swing := rad_to_deg(wrapf(atan2(tz.x, tz.z) - atan2(z.x, z.z), -PI, PI))
	t.note = "swung %.0f deg" % swing
	t.ok(v.trailer == tr, "R let the trailer go")
	t.ok(absf(swing - 60.0) < 20.0, "the trailer is swung %.0f deg, not 60" % swing)
	t.ok(tr.global_transform.basis.y.y > 0.95, "the trailer is not upright")
	post.free()
	_free(t, [tr])


func test_r_lets_the_trailer_go_where_there_is_no_room_behind(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var tr := await _hitched(t)
	# The truck sent 25 m ahead, with a wall where the trailer would go straight behind it there.
	var terrain: Terrain = t.world.terrain
	var yaw := v.global_rotation.y
	var to := v.global_position - v.global_transform.basis.z * 25.0
	to.y = terrain.get_height(to.x, to.z) + 2.0
	var there := Transform3D(Basis(Vector3.UP, yaw), to)
	var wall := _wall(t, Vector3(4.0, 4.0, 1.0), Transform3D(there.basis, there * v.spec.hitch + there.basis.z * 2.0))
	var stood := tr.global_position
	await t.ticks(2)
	v.teleport(to, yaw)
	await t.ticks(60)
	t.ok(v.trailer == null and tr.truck == null, "the trailer was hitched into a wall")
	t.ok(v.global_position.distance_to(to) < 3.0, "the truck is %.1f m from where it was sent" % v.global_position.distance_to(to))
	t.ok(tr.global_position.distance_to(stood) < 1.0, "the trailer moved %.1f m" % tr.global_position.distance_to(stood))
	wall.free()
	_free(t, [tr])


func test_r_sets_the_semi_down_clear_of_the_semi_trailer_it_lets_go(t: TCase) -> void:
	t.world.set_truck(TruckSpec.semi())
	await t.ticks(5)
	var v: Vehicle = t.world.vehicle
	var c: Contracts = t.world.contracts
	var terrain: Terrain = t.world.terrain
	await t.place(Vector2(c.spawn_pos.x, c.spawn_pos.z), c.spawn_yaw)
	var tr := _behind(t, TrailerSpec.semi_trailer(), v.hitch_point(), v.global_rotation.y)
	await t.ticks(20)
	v.hitch(tr)
	await t.ticks(40)
	# Branches over the trailer, too high to touch it, in the way of it 2 m up where R puts it.
	var b := v.global_transform.basis
	var over := v.global_position + b.z * 7.5
	over.y = terrain.get_height(over.x, over.z) + 2.3
	var branches := _wall(t, Vector3(3.0, 1.0, 7.0), Transform3D(b, over))
	var stood := tr.global_position
	var was := v.global_position
	await t.ticks(2)
	t.ok(tr.fits(tr.global_transform, v), "the branches touch the trailer")
	v.reset_upright()
	await t.ticks(120)
	var high := 0.0
	for w in v.wheels:
		if w.contact:
			high = maxf(high, w.point.y - terrain.get_height(w.point.x, w.point.z))
	t.note = "the truck set down %.1f m ahead, its wheels %.2f m off the ground at most" % [(v.global_position - was).dot(-b.z), high]
	t.ok(v.trailer == null and tr.truck == null, "R hitched the trailer into the branches")
	t.ok(v.wheels.all(func(w: Chassis.Wheel) -> bool: return w.contact) and high < 0.3, "the truck stands on the trailer's deck (a wheel %.2f m up)" % high)
	t.ok(v.global_transform.basis.y.y > 0.97, "the truck is tilted")
	t.ok(tr.global_transform.basis.y.y > 0.97 and tr.global_position.distance_to(stood) < 1.0, "the trailer moved or tipped")
	branches.free()
	_free(t, [tr])
	t.world.set_truck(TruckSpec.pickup())
	await t.ticks(5)


func test_r_does_not_set_the_semi_down_in_a_house_ahead(t: TCase) -> void:
	t.world.set_truck(TruckSpec.semi())
	await t.ticks(5)
	var v: Vehicle = t.world.vehicle
	var c: Contracts = t.world.contracts
	var terrain: Terrain = t.world.terrain
	await t.place(Vector2(c.spawn_pos.x, c.spawn_pos.z), c.spawn_yaw)
	var tr := _behind(t, TrailerSpec.semi_trailer(), v.hitch_point(), v.global_rotation.y)
	await t.ticks(20)
	v.hitch(tr)
	await t.ticks(40)
	var b := v.global_transform.basis
	var over := v.global_position + b.z * 7.5
	over.y = terrain.get_height(over.x, over.z) + 2.3
	var branches := _wall(t, Vector3(3.0, 1.0, 7.0), Transform3D(b, over))
	# A house 1 m ahead of the cab's nose.
	var at := v.global_position - b.z * 7.1
	at.y = terrain.get_height(at.x, at.z) + 2.25
	var house := _wall(t, Vector3(6.0, 4.5, 5.0), Transform3D(b, at))
	await t.ticks(2)
	v.reset_upright()
	await t.ticks(120)
	var inside := false
	for cs in v.get_children():
		if cs is CollisionShape3D:
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = cs.shape
			q.transform = cs.global_transform
			inside = inside or _meets(v, q, house)
	t.ok(v.trailer == null, "R hitched the trailer into the branches")
	t.ok(not inside, "the truck is in the house")
	t.ok(v.global_transform.basis.y.y > 0.97 and v.wheels.all(func(w: Chassis.Wheel) -> bool: return w.contact), "the truck is not on its wheels, upright")
	branches.free()
	house.free()
	_free(t, [tr])
	t.world.set_truck(TruckSpec.pickup())
	await t.ticks(5)


## Whether query q, from v's world, meets body.
func _meets(v: Vehicle, q: PhysicsShapeQueryParameters3D, body: CollisionObject3D) -> bool:
	return v.get_world_3d().direct_space_state.intersect_shape(q, 16).any(func(hit: Dictionary) -> bool: return hit.rid == body.get_rid())


func test_c_lets_the_semi_trailer_down_on_its_legs_in_a_dip(t: TCase) -> void:
	# Where the road dips at (77, 68) in the khutir valley, the semi rig set down along it either way,
	# loaded: C leaves the semi-trailer on its legs, and the semi drives out from under it.
	t.world.set_truck(TruckSpec.semi())
	await t.ticks(5)
	var v: Vehicle = t.world.vehicle
	var at := Vector2(77.0, 68.0)
	var along := Vector2.ZERO
	var nearest := INF
	for road: PackedVector2Array in t.world.roads:
		for i in road.size() - 1:
			var p := Geometry2D.get_closest_point_to_segment(at, road[i], road[i + 1])
			if p.distance_to(at) < nearest:
				nearest = p.distance_to(at)
				along = (road[i + 1] - road[i]).normalized()
	var notes := PackedStringArray()
	for way in [1.0, -1.0]:
		var yaw := atan2(-along.x * way, -along.y * way)  # facing along the road
		await t.place(at, yaw, 30)
		var tr := _behind(t, TrailerSpec.semi_trailer(), v.hitch_point(), yaw, "long")
		await t.ticks(20)
		v.hitch(tr)
		await t.ticks(90)
		v.toggle_hitch()
		var from := v.global_position
		Input.action_press("accelerate", 1.0)
		await t.ticks(300)
		Input.action_release("accelerate")
		await t.ticks(60)
		var went := v.global_position.distance_to(from)
		notes.append("%.0f m" % went)
		t.ok(v.trailer == null, "C did not unhitch it")
		t.ok(went > 5.0, "the semi went %.1f m in 5 s out from under its semi-trailer" % went)
		t.ok(tr.stand_contact and tr.global_transform.basis.y.y > 0.95, "the semi-trailer is not on its legs")
		_free(t, [tr])
	t.note = "the semi drove %s out from under it" % " and ".join(notes)
	t.world.set_truck(TruckSpec.pickup())
	await t.ticks(5)


## A box of size standing at xf, in the world.
func _wall(t: TCase, size: Vector3, xf: Transform3D) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	wall.add_child(cs)
	t.world.add_child(wall)
	wall.global_transform = xf
	return wall


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


## A trailer standing with its coupler at (over) at, facing yaw, with a load of kind.
func _behind(t: TCase, spec: TrailerSpec, at: Vector3, yaw: float, kind := "") -> Trailer:
	var o := at - Basis(Vector3.UP, yaw) * spec.coupler
	return _trailer(t, spec, Vector2(o.x, o.z), yaw, kind)


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
