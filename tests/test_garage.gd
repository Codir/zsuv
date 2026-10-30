extends RefCounted
## The garage at the depot (Tab on the board): the pickup and what it sells, cheapest first;
## bought from the wallet, a trailer waits at the depot and a truck is driven from there; the board
## tags a job with the rig it needs, and a trailer's load waits in the trailer until it is brought;
## the rigs bought and the truck picked are saved; the trailers park by the depot upright, off the
## roads and clear of each other, the buildings and the spawn, and each rig backs up to its trailer
## there and hitches it, in every valley (docs/trucks.md).

const SCENE := preload("res://scenes/main.tscn")


func test_the_garage_sells_cheapest_first(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var ids := PackedStringArray()
	var prices: Array[int] = []
	for item in c.garage_items():
		ids.append(item.id)
		prices.append(item.price)
	t.eq(ids, PackedStringArray(["pickup", "trailer", "tractor", "six", "semi"]), "the garage")
	t.eq(prices, [0, 800, 2500, 3500, 5000], "prices")
	t.eq(c.garage_items()[2].gives, PackedStringArray(["tractor", "farm"]), "the tractor comes with its trailer")
	t.eq(c.garage_items()[4].gives, PackedStringArray(["semi", "semi_trailer"]), "the semi truck with its semi-trailer")


func test_a_bought_trailer_waits_at_the_depot_and_carries_a_double_load(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var v: Vehicle = t.world.vehicle
	c.call("_end_job")
	c.money = 500
	c.board_open = true
	c.garage_open = true
	t.ok(c.board_text().begins_with("GARAGE - DEPOT   $500"), "garage: " + c.board_text())
	c.garage_pick(1)
	t.ok(not c.profile.has_rig("trailer"), "bought a trailer for $500")
	t.eq(c.need("double"), "TRAILER", "a double load without the trailer")
	c.money = 1000
	c.garage_pick(1)
	t.ok(c.profile.has_rig("trailer"), "the trailer is not bought for $1000")
	t.eq(c.money, 200, "money left")
	var trailer := c._trailer("trailer")
	if not t.ok(trailer != null, "no trailer at the depot"):
		return
	await t.ticks(2)  # it is set down on the next physics tick
	t.ok(trailer.global_position.distance_to(c.spawn_pos) < 20.0, "the trailer is %.0f m from the depot" % trailer.global_position.distance_to(c.spawn_pos))
	t.ok(c.board_text().contains("TRAILER") and c.board_text().contains("at the depot"), "garage: " + c.board_text())
	t.eq(c.need("double"), "", "a double load with the trailer bought")
	# Taken: crates on the bed and in the trailer; it is unloaded only with the trailer there.
	c.take(c.offer("farm", "double"))
	t.ok(c.job.get("kind", "") == "double" and v.has_cargo and trailer.load == "double", "a double load is not on both")
	t.eq(c.job.reward, 380, "a double load pays 1.5 times $250")
	t.ok(c.objective_text().begins_with("HITCH THE TRAILER"), "objective: " + c.objective_text())
	var farm: Vector2 = t.world.locations.farm.pos
	await t.place(farm + Vector2(0.0, -4.0), 0.0)
	t.ok(c.prompt.begins_with("Bring the trailer"), "prompt: " + c.prompt)
	c.call("_interact")
	t.ok(not c.job.is_empty(), "unloaded without the trailer")
	v.trailer = trailer  # as hitched
	c.money = 0
	c.call("_interact")
	t.ok(c.job.is_empty() and trailer.load == "" and not v.has_cargo, "not unloaded with the trailer")
	t.eq(c.money, 380, "paid")
	v.trailer = null
	_sell_back(t)


func test_a_truck_bought_is_driven_from_the_depot(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var old: Vehicle = t.world.vehicle
	c.call("_end_job")
	c.money = 4000
	t.eq(c.need("heavy"), "6X6", "the board's tag for a heavy load")
	t.ok(c.board_text().contains("[6X6]") or not c.offers.any(func(o: Dictionary) -> bool: return o.kind == "heavy"), "board: " + c.board_text())
	c.garage_pick(3)
	await t.ticks(5)
	var v: Vehicle = t.world.vehicle
	t.ok(v != old and v.spec.id == "six", "the 6x6 is not the truck in play")
	t.eq(c.profile.truck, "six", "the truck picked")
	t.eq(c.money, 500, "money left")
	t.ok(t.world.camera_rig.target == v and t.world.hud.vehicle == v and c.vehicle == v, "the camera, the HUD or the jobs follow the old truck")
	t.ok(not is_instance_valid(old), "the pickup is still about")
	t.ok(v.global_position.distance_to(c.spawn_pos) < 3.0, "the 6x6 is not at the depot")
	t.eq(c.need("heavy"), "", "the 6x6 takes a heavy load")
	t.ok(c.offers.filter(func(o: Dictionary) -> bool: return c.need(o.kind) == "").size() >= 2, "jobs for the 6x6 on the board")
	c.garage_pick(0)
	await t.ticks(5)
	t.eq(t.world.vehicle.spec.id, "pickup", "back to the pickup")
	_sell_back(t)


func test_trailers_park_off_the_roads_and_off_the_spawn(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	c.call("_end_job")
	c.money = 9000
	c.garage_pick(1)  # the trailer
	await t.ticks(5)
	c.garage_pick(2)  # the tractor and its farm trailer: driven
	await t.ticks(5)
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
	c.call("_end_job")
	c.money = 1000
	c.garage_pick(1)  # the trailer
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
	var money := c.money
	c.recover()
	c.money = money
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
	c.call("_end_job")
	c.money = 4000
	c.garage_pick(1)  # the trailer
	await t.ticks(5)
	c.garage_pick(2)  # the tractor and its farm trailer
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
	var money := c.money
	c.recover()
	c.money = money
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
	c.call("_end_job")
	c.money = 6000
	c.garage_pick(1)  # the trailer
	await t.ticks(5)
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
	var money := c.money
	c.recover()
	c.money = money
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
			v.teleport(Vector3(at.x, world.terrain.get_height(at.x, at.z) + 1.2, at.z), yaw)
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


func test_a_job_goes_only_where_its_rig_gets_to(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	var places: Dictionary = c._places
	var farm: Dictionary = places.farm
	farm["no"] = ["long", "bulk"]
	var seen := 0
	for i in 40:
		c.roll_offers()
		for o in c.offers:
			if o.key == "farm":
				seen += 1
				t.ok(not o.kind in ["long", "bulk"], "a %s job to the khutir, where its rig cannot get" % o.kind)
	t.ok(seen > 0, "no job to the khutir in 40 boards")
	farm.erase("no")
	c.roll_offers()


func test_the_rigs_are_saved(t: TCase) -> void:
	var path := "user://test_garage.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var p := Profile.open(path)
	p.money = 3000
	t.ok(p.buy_rig(Garage.catalogue()[1]), "cannot buy the tractor for $3000")
	p.truck = "tractor"
	p.save()
	var q := Profile.open(path)
	t.ok(q.has_rig("tractor") and q.has_rig("farm") and not q.has_rig("six"), "rigs: %s" % [q.rigs])
	t.eq(q.truck, "tractor", "the truck picked")
	t.eq(q.money, 500, "money")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('[progress]\nrigs="six"\ntruck="semi"\n')
	f.close()
	var r := Profile.open(path)
	t.eq(r.rigs, PackedStringArray(), "rigs as a string")
	t.eq(r.truck, "pickup", "a truck not bought")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Every trailer in world parked well: on the map, standing still upright on its wheels, off the
## roads all along it, clear of buildings, trees and the other trailers, off the spot where a truck
## is set down, and with 5 m ahead of its coupler clear for a truck to back up to it.
func _parked_well(t: TCase, world: Node, label: String) -> void:
	var c: Contracts = world.contracts
	var terrain: Terrain = world.terrain
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


## Undoes what the garage sold in the shared world: the pickup, no trailers, no rigs.
func _sell_back(t: TCase) -> void:
	var c: Contracts = t.world.contracts
	c.call("_end_job")
	if t.world.vehicle.spec.id != "pickup":
		t.world.set_truck(TruckSpec.pickup())
	for tr in c.trailers:
		tr.queue_free()
	c.trailers.clear()
	c.profile.rigs = PackedStringArray()
	c.profile.truck = "pickup"
	c.board_open = false
	c.garage_open = false
	c.money = 0
	c.roll_offers()
