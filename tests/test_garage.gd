extends RefCounted
## The garage at the depot (Tab on the board): the pickup and what it sells, cheapest first;
## bought from the wallet, a trailer waits at the depot and a truck is driven from there; the board
## tags a job with the rig it needs, and a trailer's load waits in the trailer until it is brought;
## the rigs bought and the truck picked are saved (docs/trucks.md).


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
