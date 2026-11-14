extends RefCounted
## Water and the engine (docs/plan.md §8, §12), in the river between the steppe and the forest:
## the water drags a truck and slows it, and the current pushes it downstream, more the deeper;
## the intake under water for 1 s floods the engine, and out of the water it runs again with 25%
## less condition; with the snorkel the 6x6 stands in the river's middle and fords it; a truck on
## a bridge stays dry.


## A truck whose pedals and wheel the test holds.
class Held extends Vehicle:
	func _read_input() -> void:
		pass


func test_the_water_drags_and_slows_a_truck(t: TCase) -> void:
	var river := _river(t)
	var six := await _truck(t, TruckSpec.six(), _at(t, river, 0.0, 0.0), river)
	six.fit("snorkel")
	var dry := await _truck(t, TruckSpec.six(), _at(t, river, -(float(river.half) + 14.0), 0.0), river)
	await t.ticks(60)
	t.ok(six.water_depth > 1.0, "the river is only %.2f m deep" % six.water_depth)
	t.eq(dry.water_depth, 0.0, "water on the bank")
	var notes := []
	for v: Vehicle in [six, dry]:
		v.linear_velocity = v.global_transform.basis.z * -5.0  # coasting ahead at 18 km/h
	await t.ticks(6)
	var v0 := [six.linear_velocity.length(), dry.linear_velocity.length()]
	await t.ticks(54)
	var v1 := [six.linear_velocity.length(), dry.linear_velocity.length()]
	t.ok(v1[0] < v1[1] * 0.6, "the water does not slow it: %.1f m/s in the river, %.1f on the bank" % [v1[0], v1[1]])
	t.note = "from %.1f m/s after 1 s: %.1f in the river %.1f m deep, %.1f on the bank" % [v0[0], v1[0], six.water_depth, v1[1]]
	_free([six, dry])


func test_the_current_pushes_a_truck_downstream_more_the_deeper(t: TCase) -> void:
	var river := _river(t)
	var flow3 := Vector3.ZERO
	var drift := []
	var trucks: Array[Vehicle] = []
	for d: float in [0.0, float(river.half) * 0.8]:  # the middle, and the shallows by the bank
		var v := await _truck(t, TruckSpec.pickup(), _at(t, river, d, 0.0 if d == 0.0 else 30.0), river)
		v.fit("snorkel")
		trucks.append(v)
	await t.ticks(30)
	var starts := []
	var free_brakes := Winch.new()  # as if a winch had hold of them: the brakes off
	for v in trucks:
		v.hooked_by = free_brakes
		starts.append(v.global_position)
	await t.ticks(180)
	var p := Vector2(trucks[0].global_position.x, trucks[0].global_position.z)
	var flow := (t.world.land as Land).water_current(p)
	t.ok(flow.length() > 0.5, "no current in the river's middle: %.2f m/s" % flow.length())
	flow3 = Vector3(flow.x, 0.0, flow.y).normalized()
	for i in trucks.size():
		drift.append((trucks[i].global_position - starts[i]).dot(flow3))
	t.ok(drift[0] > 1.0, "the current does not push it downstream: %.2f m in 3 s" % drift[0])
	t.ok(drift[0] > drift[1] + 0.5, "the deep water should push harder: %.2f m in the middle, %.2f in the shallows" % [drift[0], drift[1]])
	t.note = "in 3 s, brakes off: %.1f m downstream in the middle, %.1f in the shallows" % [drift[0], drift[1]]
	free_brakes.free()
	_free(trucks)


func test_the_intake_under_water_floods_the_engine(t: TCase) -> void:
	var river := _river(t)
	var v := await _truck(t, TruckSpec.pickup(), _at(t, river, 0.0, 0.0), river, 30)
	var said := []
	v.said.connect(func(text: String) -> void: said.append(text))
	await t.ticks(30)
	t.ok(v.water_over_intake > 0.0, "the pickup's intake is %.2f m above the river" % -v.water_over_intake)
	t.ok(not v.flooded, "flooded in under a second")
	await t.ticks(60)
	t.ok(v.flooded and not v.engine_runs(), "the intake under water 1.5 s and the engine runs")
	t.ok(said.has("Engine flooded"), "nothing said: %s" % [said])
	v.fuel = v.spec.fuel_capacity
	v.throttle_input = 1.0
	await t.ticks(30)
	t.eq(v.drive, 0.0, "a flooded engine drives")
	v.throttle_input = 0.0
	# Winched or towed out, onto the bank: it runs again, for a quarter of its condition.
	var bank := _at(t, river, -(float(river.half) + 10.0), 0.0)
	v.teleport(Vector3(bank.x, t.world.land.get_height(bank.x, bank.y) + 1.2, bank.y), v.global_rotation.y)
	await t.ticks(60)
	t.ok(not v.flooded and v.engine_runs(), "out of the water, the engine does not run")
	t.ok(absf(v.condition - 0.75) < 0.01, "its condition after: %d%%" % roundi(v.condition * 100.0))
	# With no condition left, only the tow starts it.
	v.condition = 0.1
	var mid := _at(t, river, 0.0, 0.0)
	v.teleport(Vector3(mid.x, t.world.land.get_height(mid.x, mid.y) + 1.2, mid.y), 0.0)
	await t.ticks(120)
	v.teleport(Vector3(bank.x, t.world.land.get_height(bank.x, bank.y) + 1.2, bank.y), 0.0)
	await t.ticks(60)
	t.ok(v.flooded and v.condition == 0.0 and not v.engine_runs(), "a ruined engine runs again out of the water")
	v.towed()
	t.ok(v.engine_runs(), "after the tow it does not run")
	_free([v])


func test_with_the_snorkel_the_6x6_drives_through_deep_water(t: TCase) -> void:
	# The river runs in a deep cut here, with no shallows to ford (stream A's map): the 6x6 drives
	# 25 m up its bed, in water over its own intake, on the snorkel.
	var river := _river(t)
	var from := _at(t, river, 0.0, -10.0)
	var to := _at(t, river, 0.0, 15.0)
	var six := await _truck(t, TruckSpec.six(), from, river, 90, INF, false)  # the autopilot drives it
	var along := to - from  # facing up the bed
	six.teleport(Vector3(from.x, t.world.land.get_height(from.x, from.y) + 1.2, from.y), atan2(-along.x, -along.y))
	await t.ticks(90)
	six.fit("snorkel")
	var over: float = six.intake_point().y - t.world.land.get_height(six.global_position.x, six.global_position.z)
	t.ok(over > 2.0, "its snorkel is not on the roof: %.2f m up" % over)
	six.awd = true
	six.low_range = true
	var secs := 0.0
	var start := Vector2(six.global_position.x, six.global_position.z)
	six.drive_along(PackedVector2Array([to]), 3.0)
	for tick in 60 * 40:
		await t.tree.physics_frame
		if Vector2(six.global_position.x, six.global_position.z).distance_to(to) < 4.0:
			secs = tick / 60.0
			break
	six.autodrive = false
	t.ok(six.water_depth > 1.0, "not in deep water: %.2f m" % six.water_depth)
	t.ok(not six.flooded and six.engine_runs(), "flooded with the snorkel")
	t.ok(secs > 0.0, "the 6x6 does not drive 25 m up the river's bed in 40 s: %.0f m" % (Vector2(six.global_position.x, six.global_position.z) - start).dot((to - start).normalized()))
	t.note = "%.1f m of water, its intake %.1f m up: 25 m in %.0f s" % [six.water_depth, over, secs]
	_free([six])


func test_a_truck_on_a_bridge_stays_dry(t: TCase) -> void:
	var river := _river(t)
	var land: Land = t.world.land
	var mid := _at(t, river, 0.0, 0.0)
	var bank := _at(t, river, -(float(river.half) + 2.0), 0.0)
	var deck_y: float = land.get_height(bank.x, bank.y)
	t.ok(deck_y > float(river.water_level) + 0.5, "the banks stand %.2f m over the water" % (deck_y - float(river.water_level)))
	# A deck across the river at the banks' level, as a bridge is (Infra's is boxes too).
	var deck := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30.0, 0.4, 30.0)
	shape.shape = box
	deck.add_child(shape)
	t.world.add_child(deck)
	deck.global_position = Vector3(mid.x, deck_y - 0.2, mid.y)
	var v := await _truck(t, TruckSpec.pickup(), mid, river, 30, deck_y + 1.0)
	await t.ticks(120)
	t.ok(v.wheels.all(func(w: Chassis.Wheel) -> bool: return w.contact and w.wet == 0.0), "its wheels are in the water or off the deck")
	t.eq(v.water_depth, 0.0, "water under it on the deck")
	t.ok(not v.flooded and v.water_over_intake < 0.0, "flooded on the bridge")
	_free([v])
	deck.free()


## The river between the steppe and the forest: Land's border.
func _river(t: TCase) -> Dictionary:
	for b in (t.world.land as Land).borders:
		if b.kind == "river":
			return b
	t.fail("no river on the map")
	return {}


## The point across the river (d, m from its middle, negative on its west or north side) and along
## it (s, m from its middle).
func _at(_t: TCase, river: Dictionary, d: float, s: float) -> Vector2:
	var a: Terrain = river.a
	if river.side == "east":
		return Vector2(a.origin.x + Terrain.HALF + d, a.origin.y + s)
	return Vector2(a.origin.x + s, a.origin.y + Terrain.HALF + d)


## A truck of spec at p (facing across the river), driven by nothing, settled; up m above the
## ground if given.
func _truck(t: TCase, spec: TruckSpec, p: Vector2, river: Dictionary, settle := 90, at_y := INF, held := true) -> Vehicle:
	var v: Vehicle = Held.new() if held else Vehicle.new()
	v.spec = spec
	v.land = t.world.land
	var y: float = at_y if at_y < INF else t.world.land.get_height(p.x, p.y) + 1.5
	v.position = Vector3(p.x, y, p.y)
	v.rotation.y = -PI * 0.5 if river.side == "east" else PI  # facing across, to the east or the south
	t.world.add_child(v)
	await t.ticks(settle)
	return v


func _free(trucks: Array) -> void:
	for v in trucks:
		if is_instance_valid(v):
			v.free()
