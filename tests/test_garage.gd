extends RefCounted
## The garage at the railhead (Tab there): the pickup, then every trailer and truck; it sells
## nothing (docs/plan.md §6), a rig the player has is driven from it and one not found yet is not;
## a trailer that becomes the player's waits at the railhead; the rigs and the truck picked are
## saved; the trailers park by the railhead upright, off the roads and clear of each other, the
## buildings and the spawn, and each rig backs up to its trailer there and hitches it, in every
## valley (docs/trucks.md).

const SCENE := preload("res://scenes/main.tscn")


func test_the_garage_lists_every_rig_and_sells_none(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var ids := PackedStringArray()
	for item in c.garage_items():
		ids.append(item.id)
		t.ok(not item.has("price"), "%s has a price" % item.id)
	t.eq(ids, PackedStringArray(["pickup", "trailer", "six", "tractor", "semi", "scout", "mixer"]), "the garage")
	t.eq(c.garage_items()[3].gives, PackedStringArray(["tractor", "farm"]), "the tractor comes with its trailer")
	t.eq(c.garage_items()[4].gives, PackedStringArray(["semi", "semi_trailer"]), "the semi truck with its semi-trailer")
	c.garage_open = true
	t.ok(c.garage_text().begins_with("GARAGE - DEPOT\n"), "garage: " + c.garage_text())
	t.ok(not c.garage_text().contains("$"), "the garage shows money: " + c.garage_text())
	t.ok(c.garage_text().contains("not found yet"), "garage: " + c.garage_text())
	c.garage_pick(2)  # the 6x6, not the player's
	await t.ticks(3)
	t.eq(t.world.vehicle.spec.id, "pickup", "a truck not found is driven")
	t.ok(not c.profile.has_rig("six"), "the garage gave the 6x6")
	_sell_back(t)


func test_a_trailer_given_waits_at_the_depot(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	c.give_rigs(PackedStringArray(["trailer"]))
	t.ok(c.profile.has_rig("trailer"), "the trailer is not the player's")
	var trailer := c._trailer("trailer")
	if not t.ok(trailer != null, "no trailer at the depot"):
		return
	await t.ticks(2)  # it is set down on the next physics tick
	t.ok(trailer.global_position.distance_to(c.spawn_pos) < 20.0, "the trailer is %.0f m from the depot" % trailer.global_position.distance_to(c.spawn_pos))
	t.ok(c.garage_text().contains("TRAILER") and c.garage_text().contains("at the railhead"), "garage: " + c.garage_text())
	_sell_back(t)


func test_a_truck_of_the_players_is_driven_from_the_depot(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var old: Vehicle = t.world.vehicle
	c.give_rigs(PackedStringArray(["six"]))
	c.garage_pick(2)
	await t.ticks(5)
	var v: Vehicle = t.world.vehicle
	t.ok(v != old and v.spec.id == "six", "the 6x6 is not the truck in play")
	t.eq(c.profile.truck, "six", "the truck picked")
	t.ok(t.world.camera_rig.target == v and t.world.hud.vehicle == v and c.vehicle == v and t.world.infra.vehicle == v,
		"the camera, the HUD, the railhead or the buildings follow the old truck")
	t.ok(not is_instance_valid(old), "the pickup is still about")
	t.ok(v.global_position.distance_to(c.spawn_pos) < 3.0, "the 6x6 is not at the depot")
	c.garage_pick(0)
	await t.ticks(5)
	t.eq(t.world.vehicle.spec.id, "pickup", "back to the pickup")
	_sell_back(t)


func test_trailers_park_off_the_roads_and_off_the_spawn(t: TCase) -> void:
	var c: Contracts = t.world.contracts


	c.give_rigs(PackedStringArray(["trailer"]))
	await t.ticks(5)
	c.give_rigs(PackedStringArray(["tractor", "farm"]))
	c.garage_pick(3)  # the tractor and its farm trailer: driven
	await t.ticks(5)
	c.give_rigs(PackedStringArray(["semi", "semi_trailer"]))
	c.garage_pick(4)  # the semi truck and its semi-trailer: driven
	await t.ticks(60)
	t.eq(c.trailers.size(), 3, "trailers at the depot")
	_parked_well(t, t.world, "khutir")
	# The semi-trailer left over the spawn: driving another truck from the garage moves it off.
	var semi_trailer := c._trailer("semi_trailer")
	semi_trailer.stand_on(Vector2(c.spawn_pos.x, c.spawn_pos.z), t.world.valley.spawn_yaw)
	await t.ticks(30)
	c.garage_pick(0)
	await t.ticks(60)
	var v: Vehicle = t.world.vehicle
	t.ok(v.spec.id == "pickup" and v.global_transform.basis.y.y > 0.95, "the pickup is not upright on the spawn")
	t.ok(Vector2(semi_trailer.global_position.x, semi_trailer.global_position.z).distance_to(Vector2(c.spawn_pos.x, c.spawn_pos.z)) > 6.0, "the semi-trailer still stands on the spawn")
	_parked_well(t, t.world, "khutir, the spawn cleared")
	_sell_back(t)


func test_the_tow_leaves_a_trailer_on_its_spot(t: TCase) -> void:
	# A trailer hitched where it is parked and towed back at once stays on its spot: the truck it
	# is hitched to, about to be towed off, is not in the way.
	var c: Contracts = t.world.contracts
	var v: Vehicle = t.world.vehicle


	c.give_rigs(PackedStringArray(["trailer"]))
	await t.ticks(60)
	var tr := c._trailer("trailer")
	var spot := tr.global_position
	var b := tr.global_transform.basis
	var yaw := atan2(b.z.x, b.z.z)
	var at := tr.coupler_point() - Basis(Vector3.UP, yaw) * v.spec.hitch - Vector3(b.z.x, 0.0, b.z.z).normalized() * 0.3
	await t.place(Vector2(at.x, at.z), yaw, 60)
	v.hitch(tr)
	await t.ticks(30)
	t.ok(v.trailer == tr, "the trailer is not hitched")

	c.recover()

	await t.ticks(120)
	var turned := rad_to_deg(b.z.angle_to(tr.global_transform.basis.z))
	t.note = "%.1f m from its spot, turned %.0f deg" % [tr.global_position.distance_to(spot), turned]
	t.ok(v.trailer == null and tr.global_position.distance_to(spot) < 1.0, "the tow moved the trailer %.1f m off its spot" % tr.global_position.distance_to(spot))
	t.ok(turned < 10.0, "the tow turned the trailer %.0f deg on its spot" % turned)
	_sell_back(t)


func test_the_tow_brings_a_trailer_back_to_its_spot_with_another_in_its_way(t: TCase) -> void:
	# The farm trailer left out in the valley, the pickup's trailer hitched and standing ahead of the
	# farm trailer's coupler: the tow takes both, and each goes back to its own spot.
	var c: Contracts = t.world.contracts


	c.give_rigs(PackedStringArray(["trailer"]))
	await t.ticks(5)
	c.give_rigs(PackedStringArray(["tractor", "farm"]))
	c.garage_pick(3)  # the tractor and its farm trailer
	await t.ticks(5)
	c.garage_pick(0)  # back to the pickup
	await t.ticks(60)
	var v: Vehicle = t.world.vehicle
	var farm := c._trailer("farm")
	var trailer := c._trailer("trailer")
	var farm_spot := farm.global_transform
	var trailer_spot := trailer.global_position
	var farm_pos: Vector2 = t.world.locations.farm.pos
	farm.stand_on(farm_pos + Vector2(10.0, 0.0), 0.0)
	# The pickup facing the way the farm trailer does, its trailer behind it 3 m ahead of the farm trailer's coupler.
	var b := farm_spot.basis
	var ahead := -Vector3(b.z.x, 0.0, b.z.z).normalized()
	var yaw := atan2(b.z.x, b.z.z)
	var hitch := farm_spot * farm.spec.coupler + ahead * (3.0 + absf(trailer.spec.coupler.z) + 1.0)
	await t.place(Vector2(hitch.x, hitch.z) - Vector2((Basis(Vector3.UP, yaw) * v.spec.hitch).x, (Basis(Vector3.UP, yaw) * v.spec.hitch).z), yaw, 60)
	trailer.place(trailer.behind(Transform3D(v.global_transform.basis, v.hitch_point())))
	await t.ticks(20)
	v.hitch(trailer)
	await t.ticks(30)
	t.ok(v.trailer == trailer, "the trailer is not hitched")

	c.recover()

	await t.ticks(120)
	var off := farm.global_position.distance_to(farm_spot.origin)
	t.note = "the farm trailer %.1f m from its spot, the trailer %.1f m" % [off, trailer.global_position.distance_to(trailer_spot)]
	t.ok(off < 1.0 and rad_to_deg(b.z.angle_to(farm.global_transform.basis.z)) < 10.0, "the farm trailer is %.1f m from its spot, or turned" % off)
	t.ok(trailer.global_position.distance_to(trailer_spot) < 1.0, "the trailer is %.1f m from its spot" % trailer.global_position.distance_to(trailer_spot))
	_sell_back(t)


func test_the_tow_sets_the_truck_on_the_spawn_with_a_trailer_left_there(t: TCase) -> void:
	# The semi-trailer left standing across the spawn, the pickup's trailer out in the valley, the
	# semi far off: the tow sets the semi down on the spawn, the semi-trailer off it, and the
	# pickup's trailer back on its own spot.
	var c: Contracts = t.world.contracts


	c.give_rigs(PackedStringArray(["trailer"]))
	await t.ticks(5)
	c.give_rigs(PackedStringArray(["semi", "semi_trailer"]))
	c.garage_pick(4)  # the semi and its semi-trailer: driven
	await t.ticks(60)
	var v: Vehicle = t.world.vehicle
	var trailer := c._trailer("trailer")
	var semi_trailer := c._trailer("semi_trailer")
	var spot := trailer.global_transform
	var farm: Vector2 = t.world.locations.farm.pos
	trailer.stand_on(farm + Vector2(10.0, 0.0), 0.0)
	semi_trailer.stand_on(Vector2(c.spawn_pos.x, c.spawn_pos.z), c.spawn_yaw + PI * 0.5)
	await t.place(farm + Vector2(0.0, -6.0), 0.0, 60)

	c.recover()

	await t.ticks(120)
	var spawn := Vector2(c.spawn_pos.x, c.spawn_pos.z)
	var off := Vector2(v.global_position.x, v.global_position.z).distance_to(spawn)
	t.note = "the semi %.1f m from the spawn, the trailer %.1f m from its spot" % [off, trailer.global_position.distance_to(spot.origin)]
	t.ok(off < 0.5 and v.global_transform.basis.y.y > 0.97, "the semi is %.1f m from the spawn, or tilted" % off)
	t.ok(Vector2(semi_trailer.global_position.x, semi_trailer.global_position.z).distance_to(spawn) > 6.0, "the semi-trailer still stands on the spawn")
	t.ok(trailer.global_position.distance_to(spot.origin) < 1.0 and rad_to_deg(spot.basis.z.angle_to(trailer.global_transform.basis.z)) < 10.0, "the trailer is not back on its spot")
	_sell_back(t)


func test_trailers_park_well_in_every_valley(t: TCase) -> void:
	for valley in Valley.all():
		var profile := Profile.new()
		profile.rigs = PackedStringArray(["trailer", "tractor", "farm", "six", "semi", "semi_trailer"])
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.size = Vector2i(480, 270)
		var world = SCENE.instantiate()
		world.valley = valley
		world.profile = profile
		vp.add_child(world)
		t.tree.root.add_child(vp)
		await t.ticks(90)
		t.eq(world.contracts.trailers.size(), 3, "%s: trailers at the depot" % valley.id)
		_parked_well(t, world, valley.id)
		vp.free()


func test_each_rig_backs_up_to_its_trailer_by_the_depot_in_every_valley(t: TCase) -> void:
	var shared: Vehicle = t.world.vehicle
	shared.autodrive = true  # deaf to the keys pressed for the truck backing up here
	shared.autodrive_path = PackedVector2Array()
	var notes := PackedStringArray()
	for valley in Valley.all():
		var profile := Profile.new()
		profile.rigs = PackedStringArray(["trailer", "tractor", "farm", "six", "semi", "semi_trailer"])
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.size = Vector2i(480, 270)
		var world = SCENE.instantiate()
		world.valley = valley
		world.profile = profile
		vp.add_child(world)
		t.tree.root.add_child(vp)
		await t.ticks(60)
		for tr: Trailer in world.contracts.trailers.duplicate():
			world.set_truck(TruckSpec.find({"trailer": "pickup", "farm": "tractor", "semi_trailer": "semi"}[tr.spec.id]))
			await t.ticks(2)
			var v: Vehicle = world.vehicle
			var b := tr.global_transform.basis
			var yaw := atan2(b.z.x, b.z.z)
			var ahead := -Vector3(b.z.x, 0.0, b.z.z).normalized()
			var at: Vector3 = tr.coupler_point() + ahead * 3.0 - Basis(Vector3.UP, yaw) * v.spec.hitch
			v.teleport(Vector3(at.x, world.land.home.get_height(at.x, at.z) + 1.2, at.z), yaw)
			await t.ticks(90)
			var ticks := 0
			while (v.hitch_candidate() != tr or v.hitch_point().distance_to(tr.coupler_point()) > 0.6) and ticks < 900:
				# As a player backs up: hard on the brake while it rolls ahead, a little reverse, none past
				# 0.6 m/s, steering its back toward the coupler (the wheel turned left takes it left).
				Input.action_press("brake", 1.0 if v.forward_speed > 0.05 else (0.5 if -v.forward_speed < 0.6 else 0.0))
				var d := v.global_transform.basis.inverse() * (tr.coupler_point() - v.hitch_point())
				var wheel := clampf(-atan2(d.x, d.z) * 2.0, -1.0, 1.0)
				Input.action_press("steer_left", maxf(wheel, 0.0))
				Input.action_press("steer_right", maxf(-wheel, 0.0))
				await t.tree.physics_frame
				ticks += 1
			for action in ["brake", "steer_left", "steer_right"]:
				Input.action_release(action)
			await t.ticks(20)
			v.toggle_hitch()
			await t.ticks(5)
			notes.append("%s %s %.1f s" % [valley.id, tr.spec.id, ticks / 60.0])
			t.ok(v.trailer == tr, "%s: the %s did not back up to the %s and hitch it (%.1f m off)" % [valley.id, v.spec.id, tr.spec.id, v.hitch_point().distance_to(tr.coupler_point())])
			v.unhitch()
		vp.free()
	shared.autodrive = false
	t.note = ", ".join(notes)

func test_the_rigs_are_saved(t: TCase) -> void:
	var path := "user://test_garage.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var p := Profile.open(path)
	p.add_rigs(Garage.catalogue()[2].gives)  # the tractor and its farm trailer, found
	p.truck = "tractor"
	p.save()
	var q := Profile.open(path)
	t.ok(q.has_rig("tractor") and q.has_rig("farm") and not q.has_rig("six"), "rigs: %s" % [q.rigs])
	t.eq(q.truck, "tractor", "the truck picked")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('[progress]\nrigs="six"\ntruck="semi"\n')
	f.close()
	var r := Profile.open(path)
	t.eq(r.rigs, PackedStringArray(), "rigs as a string")
	t.eq(r.truck, "pickup", "a truck not the player's")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Every trailer in world parked well: on the map, standing still upright on its wheels, off the
## roads all along it, clear of buildings, trees and the other trailers, off the spot where a truck
## is set down, and with 5 m ahead of its coupler clear for a truck to back up to it.
func _parked_well(t: TCase, world: Node, label: String) -> void:
	var c: Contracts = world.contracts
	var terrain: Terrain = world.land.home
	var turn := Basis(Vector3.UP, c.spawn_yaw)
	var spawn := PackedVector2Array()
	for k in [Vector3(-2.5, 0.0, -6.0), Vector3(2.5, 0.0, -6.0), Vector3(2.5, 0.0, 6.0), Vector3(-2.5, 0.0, 6.0)]:
		var p: Vector3 = c.spawn_pos + turn * k
		spawn.append(Vector2(p.x, p.z))
	var feet: Array[PackedVector2Array] = []
	var lanes: Array[PackedVector2Array] = []
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for tr in c.trailers:
		var box := tr.spec.extent()
		var corners := PackedVector2Array()
		var on_road := 0
		for i in 13:
			for j in 3:
				var p := tr.global_transform * (box.position + Vector3(box.size.x * j * 0.5, 0.0, box.size.z * i / 12.0))
				if terrain.road_distance(Vector2(p.x, p.z)) < Terrain.ROAD_HALF_WIDTH:
					on_road += 1
				if (i == 0 or i == 12) and j != 1:
					corners.append(Vector2(p.x, p.z))
		corners = PackedVector2Array([corners[0], corners[1], corners[3], corners[2]])
		feet.append(corners)
		var lane := PackedVector2Array()
		for k in [Vector3(0.0, 0.0, -5.0), Vector3(box.size.x, 0.0, -5.0), Vector3(box.size.x, 0.0, 0.0), Vector3(0.0, 0.0, 0.0)]:
			var p: Vector3 = tr.global_transform * (box.position + k)
			lane.append(Vector2(p.x, p.z))
		lanes.append(lane)
		var q := PhysicsShapeQueryParameters3D.new()
		var lane_box := BoxShape3D.new()
		lane_box.size = Vector3(box.size.x, 1.5, 5.0)
		q.shape = lane_box
		q.transform = tr.global_transform * Transform3D(Basis.IDENTITY, box.position + Vector3(box.size.x * 0.5, 0.75, -2.5))
		q.exclude = [tr.get_rid(), terrain.body.get_rid(), world.vehicle.get_rid()]
		t.ok(space.intersect_shape(q, 1).is_empty(), "%s: something stands ahead of the %s's coupler" % [label, tr.spec.id])
		var edge := 0.0
		for p in corners:
			edge = maxf(edge, maxf(absf(p.x), absf(p.y)))
		t.ok(edge < Terrain.HALF - 2.0, "%s: the %s is %.0f m out, off the map" % [label, tr.spec.id, edge])
		var standing := tr.wheels.all(func(w: Chassis.Wheel) -> bool: return w.contact)
		t.ok(standing and tr.linear_velocity.length() < 0.3, "%s: the %s is not standing on its wheels (%.1f m/s)" % [label, tr.spec.id, tr.linear_velocity.length()])
		t.eq(on_road, 0, "%s: points of the %s on a road" % [label, tr.spec.id])
		t.ok(tr.global_transform.basis.y.y > 0.95, "%s: the %s tipped (up %.2f)" % [label, tr.spec.id, tr.global_transform.basis.y.y])
		t.ok(tr.fits(tr.global_transform), "%s: the %s stands in a building, a tree or another trailer" % [label, tr.spec.id])
		t.ok(Geometry2D.intersect_polygons(corners, spawn).is_empty(), "%s: the %s stands where a truck is set down" % [label, tr.spec.id])
	for i in feet.size():
		for j in range(i + 1, feet.size()):
			t.ok(Geometry2D.intersect_polygons(feet[i], feet[j]).is_empty(), "%s: the %s and the %s overlap" % [label, c.trailers[i].spec.id, c.trailers[j].spec.id])
	for i in lanes.size():
		for j in feet.size():
			if i != j:
				t.ok(Geometry2D.intersect_polygons(lanes[i], feet[j]).is_empty(), "%s: the %s stands ahead of the %s's coupler" % [label, c.trailers[j].spec.id, c.trailers[i].spec.id])


## Undoes what the garage gave in the shared world: the pickup, no trailers, no rigs.
func _sell_back(t: TCase) -> void:
	var c: Contracts = t.world.contracts

	if t.world.vehicle.spec.id != "pickup":
		t.world.set_truck(TruckSpec.pickup())
	for tr in c.trailers:
		tr.queue_free()
	c.trailers.clear()
	c.profile.rigs = PackedStringArray()
	c.profile.truck = "pickup"
	c.garage_open = false


## The upgrades (docs/plan.md §8): made in a garage from the parts in its yard, fitted, they do
## what §8 says: the snorkel lifts the intake, the chains grip on ice, a 6x6 body changes what it
## carries.
func test_upgrades_are_made_from_parts_and_fitted(t: TCase) -> void:
	var w = t.world
	var v: Vehicle = w.vehicle
	var ids := Upgrades.list(v).map(func(u: Dictionary) -> String: return u.id)
	t.eq(ids, ["snorkel", "chains", "long_winch"], "what fits the pickup")
	var six := await _six(t)
	var six_ids := Upgrades.list(six).map(func(u: Dictionary) -> String: return u.id)
	six.free()
	t.eq(six_ids, ["snorkel", "chains", "long_winch", "body_tank", "body_flatbed", "body_tipper"], "what fits the 6x6")
	t.ok(not Upgrades.fits(TruckSpec.semi(), "snorkel"), "a snorkel fits the semi")
	var yard := _Yard.new()
	t.eq(Upgrades.fit(v, "snorkel", yard), "It takes 1 parts: bring them to the yard", "with no parts in the yard")
	yard.parts = 1.0
	var low := v.intake_point().y - v.global_position.y
	t.ok(Upgrades.fit(v, "snorkel", yard).begins_with("Fitted: snorkel"), "the snorkel is not fitted")
	t.eq(yard.parts, 0.0, "the parts it took")
	t.ok(v.intake_point().y - v.global_position.y > low + 0.6, "the intake is not up on the roof")
	t.ok(v._snorkel_gfx and v._snorkel_gfx.visible, "the snorkel does not show")
	t.eq(Upgrades.fit(v, "snorkel", w.infra.railhead), "Fitted already", "a second snorkel")
	v.upgrades = PackedStringArray()
	v.fit("chains")
	v.upgrades = PackedStringArray()
	v._apply_upgrades()
	t.ok(v.wheels.all(func(wh: Chassis.Wheel) -> bool: return not wh.chains), "the chains stay on")
	yard.free()


func test_the_chains_grip_on_ice(t: TCase) -> void:
	var land: Land = t.world.land
	var lake := Vector2.INF
	for tile in land.tiles:
		if tile.valley.id == "polissia":
			lake = tile.origin + Vector2(10.0, -12.0)  # Polissia's frozen lake
	if not t.ok(lake != Vector2.INF, "no Polissia on the map"):
		return
	t.ok(land.sample(Vector3(lake.x, 0.0, lake.y)).ice > 0.5, "no ice on Polissia's lake")
	var v := Vehicle.new()
	v.spec = TruckSpec.pickup()
	v.land = land
	v.position = Vector3(lake.x, land.get_height(lake.x, lake.y) + 1.5, lake.y)
	t.world.add_child(v)
	v.set_driven(false)
	await t.ticks(90)
	var bare := v.wheels[0].surface.grip
	v.fit("chains")
	await t.ticks(5)
	var chained := v.wheels[0].surface.grip
	t.ok(bare < 0.25, "ice grips a bare tyre: %.2f" % bare)
	t.ok(chained >= 0.39, "ice does not grip a chained tyre: %.2f" % chained)
	t.note = "on ice: %.2f bare, %.2f in chains" % [bare, chained]
	v.free()


func test_a_6x6_body_changes_what_it_carries(t: TCase) -> void:
	var six := await _six(t)
	var yard := _Yard.new()
	yard.parts = 3.0
	t.eq(six.rig_room("fuel"), 2000.0, "litres on its bed as found")
	t.ok(Upgrades.fit(six, "body_tank", yard).begins_with("Fitted: tank body"), "the tank is not fitted")
	t.eq(six.rig_room("fuel"), 2000.0, "litres in its tank body")
	t.eq(six.rig_room("timber"), 0.0, "the tank takes timber")
	t.ok(six._bodies.body_tank.visible and not six._bodies.body_tipper.visible, "the tank does not show")
	six.rig_put("fuel", 500.0)
	t.eq(Upgrades.fit(six, "body_tipper", yard), "Unload it first", "a body changed with fuel in it")
	six.rig_take("fuel")
	t.ok(Upgrades.fit(six, "body_tipper", yard).begins_with("Fitted: tipper body"), "the tipper is not fitted")
	t.ok(not "body_tank" in six.upgrades and "body_tipper" in six.upgrades, "two bodies at once: %s" % six.upgrades)
	t.eq(six.rig_room("gravel"), 1.0, "a load of gravel in the tipper")
	t.eq(six.rig_room("soil"), 10.0, "m3 of soil in the tipper")
	t.ok(Upgrades.fit(six, "body_flatbed", yard).begins_with("Fitted: flatbed body"), "the flatbed is not fitted")
	t.eq(six.rig_room("timber"), 1.0, "timber on the flatbed")
	t.eq(yard.parts, 0.0, "parts left")
	six.free()
	yard.free()


## A 6x6 parked out of the way, not the fleet's.
func _six(t: TCase) -> Vehicle:
	var v := Vehicle.new()
	v.spec = TruckSpec.six()
	v.land = t.world.land
	var farm: Vector2 = t.world.locations.farm.pos + Vector2(12.0, -4.0)
	v.position = Vector3(farm.x, t.world.land.get_height(farm.x, farm.y) + 1.5, farm.y)
	t.world.add_child(v)
	v.set_driven(false)
	await t.ticks(2)
	return v


## A base's yard, as a Site gives from its stock.
class _Yard extends Node:
	var parts := 0.0

	func available(res: String) -> float:
		return parts if res == "parts" else 0.0

	func give(res: String, n: float) -> float:
		var got := minf(n, available(res))
		parts -= got
		return got


## U in the garage turns it to the workshop: its lines fit an upgrade or repair, from the base's
## parts (the railhead's never run out).
func test_the_workshop_in_the_garage(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var v: Vehicle = t.world.vehicle
	await t.place(Vector2(c.spawn_pos.x, c.spawn_pos.z), c.spawn_yaw)
	v.condition = 0.6
	c.garage_open = true
	var u := InputEventKey.new()
	u.physical_keycode = KEY_U
	u.pressed = true
	c._unhandled_input(u)
	t.ok(c.workshop, "U does not turn the garage to the workshop")
	t.ok(c.workshop_base() != null, "no base at the railhead")
	var text := c.garage_text()
	t.ok(text.begins_with("WORKSHOP - PICKUP") and "1  SNORKEL" in text and "4  REPAIR" in text, "the workshop: %s" % text)
	var said := []
	var on_message := func(m: String) -> void: said.append(m)
	c.message.connect(on_message)
	c.garage_pick(0)
	t.ok("snorkel" in v.upgrades, "the snorkel is not fitted: %s" % [said])
	c.garage_pick(3)
	t.eq(v.condition, 1.0, "its condition after the repair")
	c.message.disconnect(on_message)
	c._unhandled_input(u)
	t.ok(not c.workshop, "U does not turn back to the trucks")
	c.garage_open = false
	v.upgrades = PackedStringArray()
	v._apply_upgrades()


func test_the_long_winch_reaches_further_and_pulls_harder(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var length := v.winch.max_length
	t.ok(Upgrades.fit(v, "long_winch", t.world.infra.railhead).begins_with("Fitted: long winch"), "the long winch is not fitted")
	t.eq(v.winch.max_length, length + 10.0, "its cable")
	t.eq(v.winch.pull, 1.3, "its pull")
	v.upgrades = PackedStringArray()
	v._apply_upgrades()
	t.eq(v.winch.max_length, length, "its cable after")
