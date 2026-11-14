extends RefCounted
## Condition and repair (docs/plan.md §8, §12): hard knocks, a flooded engine and rolling over
## cost what §8 says; the engine pulls less as the condition drops, and under 25% the tank leaks;
## at 0% it will not run; a repair at the garage brings it back, a load of parts for each 50%.


## A truck whose pedals and wheel the test holds.
class Held extends Vehicle:
	func _read_input() -> void:
		pass


func test_a_hard_landing_costs_condition_and_a_gentle_drive_none(t: TCase) -> void:
	var vp := _flat(t)
	var v := _held(vp, TruckSpec.pickup(), Vector3.ZERO)
	await t.ticks(150)  # set down and settled: no knock
	t.eq(v.condition, 1.0, "its condition set down")
	v.throttle_input = 1.0
	await t.ticks(300)
	v.throttle_input = 0.0
	v.handbrake = true
	await t.ticks(120)
	t.eq(v.condition, 1.0, "its condition after a drive and a stop on the flat")
	v.handbrake = false
	v.linear_velocity = Vector3(0.0, 9.0, 0.0)  # thrown 4 m up: it lands hard
	await t.ticks(150)
	var lost := 1.0 - v.condition
	t.ok(lost > 0.02 and lost < 0.8, "a 4 m drop cost %.0f%%" % (lost * 100.0))
	t.note = "a 4 m drop cost %.0f%%" % (lost * 100.0)
	vp.free()


func test_rolling_over_costs_ten_percent(t: TCase) -> void:
	var vp := _flat(t)
	var v := _held(vp, TruckSpec.pickup(), Vector3.ZERO)
	await t.ticks(120)
	v.condition = 1.0
	v.global_transform = Transform3D(Basis(Vector3.FORWARD, PI * 0.95), Vector3(0.0, 2.5, 0.0))
	await t.ticks(150)
	t.ok(v.global_transform.basis.y.y < 0.0, "it did not land on its roof")
	t.ok(v.condition <= 0.9 + 0.0001 and v.condition > 0.6, "on its roof: %.0f%%" % (v.condition * 100.0))
	var after := v.condition
	await t.ticks(120)
	t.eq(v.condition, after, "it goes on losing condition lying there")
	vp.free()


func test_the_power_drops_with_condition_and_at_nothing_it_does_not_run(t: TCase) -> void:
	var vp := _flat(t)
	var shares := [1.0, 0.4, 0.2, 0.0]
	var trucks: Array[Held] = []
	for i in shares.size():
		var v := _held(vp, TruckSpec.pickup(), Vector3(i * 30.0, 0.0, 0.0))
		trucks.append(v)
	await t.ticks(120)
	for i in trucks.size():
		trucks[i].condition = shares[i]
		trucks[i].throttle_input = 1.0
	var fuel0 := []
	for v in trucks:
		fuel0.append(v.fuel)
	await t.ticks(90)
	var speeds := []
	for v in trucks:
		speeds.append(v.forward_speed)
	t.ok(speeds[1] < speeds[0] * 0.9 and speeds[1] > speeds[0] * 0.65, "under 50%%, 0.8 times the pull: %.1f vs %.1f m/s" % [speeds[1], speeds[0]])
	t.ok(speeds[2] < speeds[1] * 0.9 and speeds[2] > speeds[0] * 0.45, "under 25%%, 0.6 times: %.1f m/s" % speeds[2])
	t.ok(absf(speeds[3]) < 0.1 and not trucks[3].engine_runs(), "at 0%% it runs: %.1f m/s" % speeds[3])
	for v in trucks:
		v.throttle_input = 0.0
	var idle0 := [trucks[0].fuel, trucks[2].fuel]
	await t.ticks(120)
	var burnt := [idle0[0] - trucks[0].fuel, idle0[1] - trucks[2].fuel]
	t.ok(absf(burnt[1] - burnt[0] - Vehicle.LEAK * 2.0) < 0.02, "under 25%% the tank leaks 0.05 L/s: %.3f L against %.3f idling for 2 s" % [burnt[1], burnt[0]])
	t.note = "after 1.5 s: %.1f, %.1f, %.1f, %.1f m/s at 100, 40, 20, 0%%" % speeds
	vp.free()


func test_repair_at_the_garage_brings_it_back(t: TCase) -> void:
	var v: Vehicle = t.world.vehicle
	var base := Yard.new(1.0)
	v.condition = 0.3
	t.eq(Upgrades.repair_cost(v), 2, "parts to repair 70%")
	t.eq(Upgrades.repair(v, base), "Repaired: 80%", "with one load of parts in the yard")
	t.eq(base.parts, 0.0, "parts left")
	t.eq(Upgrades.repair(v, base), "A repair takes parts: bring them to the yard", "with none")
	var railhead: Site = t.world.infra.railhead  # its parts never run out
	t.eq(Upgrades.repair(v, railhead), "Repaired: 100%", "at the railhead")
	t.eq(v.condition, 1.0, "its condition")
	t.eq(Upgrades.repair(v, railhead), "It needs no repair", "a truck in full repair")


## A base's yard, as a Site gives from its stock.
class Yard extends Node:
	var parts := 0.0

	func _init(n: float) -> void:
		parts = n

	func available(res: String) -> float:
		return parts if res == "parts" else 0.0

	func give(res: String, n: float) -> float:
		var got := minf(n, available(res))
		parts -= got
		return got


func _held(vp: SubViewport, spec: TruckSpec, at: Vector3) -> Held:
	var v := Held.new()
	v.spec = spec
	v.position = at + Vector3(0.0, 1.0, 0.0)
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
