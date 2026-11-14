extends RefCounted
## The numbers against the map (docs/plan.md §1, §5, §6, §13): the concrete's 5 minutes reach the
## river bridge from the railhead (the gorge is noted), a tank does not
## take a truck to the village and back (so fuel stations go out there) but takes it to the river
## and back, the railhead's timber builds the river bridge, the yards and tanks hold what the
## buildings need, and the sawmill keeps up with the bridges. Each test notes its numbers.

const MIXER_SPEED := 8.0  # m/s, loaded, on the roads
const OFFROAD := 1.3  # a road is this much longer than the straight line between its ends
const ROAD_SPEED := 10.0  # m/s a pickup averages on the dirt roads
const THROTTLE := 0.5  # its average throttle there


## Metres by road from a to b through the points between (straight lines, made longer).
static func _route(pts: Array) -> float:
	var m := 0.0
	for i in pts.size() - 1:
		m += (pts[i] as Vector2).distance_to(pts[i + 1])
	return m * OFFROAD


static func _mid(spot: Dictionary) -> Vector2:
	return spot.pos


func _points(t: TCase) -> Dictionary:
	var land: Land = t.world.land
	var infra: Infra = t.world.infra
	var steppe := land.tiles.filter(func(x: Terrain) -> bool: return x.valley.id == "steppe")[0] as Terrain
	var railhead: Vector2 = (steppe.valley.locations.depot.pos as Vector2) + steppe.origin
	return {"railhead": railhead, "river": _mid(land.spot("bridge:river")), "bog": _mid(land.spot("gravel_road:polissia0")),
		"gorge": _mid(land.spot("bridge:gorge")), "village": infra.village.at}


## How far the concrete goes is the owner's call to tune (Hold.CONCRETE_SETS): on the straight
## roads' length the railhead's reaches the gorge, so only the river is held here, and the gorge
## noted.
func test_the_concrete_reaches_the_river_bridge(t: TCase) -> void:
	var p := _points(t)
	var to_river := _route([p.railhead, p.river]) / MIXER_SPEED
	var to_gorge := _route([p.railhead, p.river, p.bog, p.gorge]) / MIXER_SPEED
	t.note = "railhead -> river %.0f s, -> gorge %.0f s; it sets in %.0f s" % [to_river, to_gorge, Hold.CONCRETE_SETS]
	t.ok(to_river < Hold.CONCRETE_SETS * 0.6, "the railhead's concrete barely reaches the river bridge: %.0f s" % to_river)


func test_a_tank_takes_a_pickup_to_the_river_and_back_but_not_to_the_village(t: TCase) -> void:
	var p := _points(t)
	var spec := TruckSpec.pickup()
	var per_s := Vehicle.BURN_IDLE + THROTTLE * Vehicle.BURN * spec.burn  # Vehicle's burn, at that throttle
	var range_m := spec.fuel_capacity / per_s * ROAD_SPEED
	var river_back := _route([p.railhead, p.river]) * 2.0
	var village_back := _route([p.railhead, p.river, p.bog, p.gorge, p.village]) * 2.0
	t.note = "a tank goes %.0f m; to the river and back %.0f m, to the village and back %.0f m" % [range_m, river_back, village_back]
	t.ok(river_back < range_m * 0.7, "a tank does not take the pickup to the river and back")
	t.ok(village_back > range_m, "a tank takes the pickup to the village and back: no need for fuel out there; " + t.note)


func test_the_railheads_stock_and_the_yards_hold_what_is_needed(t: TCase) -> void:
	var river := BuildingSpec.road_site(t.world.land.spot("bridge:river"))
	t.ok(Infra.RAILHEAD_STOCK.timber >= river.needs.timber, "the railhead's timber does not build the river bridge")
	t.ok(Infra.RAILHEAD_STOCK.gravel >= river.needs.concrete, "the railhead's plant has not the gravel for the river bridge's concrete")
	var village := BuildingSpec.village()
	var pickup := Loads.room(t.world.vehicle, "fuel")
	t.ok(village.needs.fuel <= 800.0, "the village's fuel is more than the pickup and its trailer carry: %d L" % village.needs.fuel)
	for s in BuildingSpec.all():
		var total := 0
		for res in s.needs:
			total += int(s.needs[res])
		t.ok(total <= BuildingSpec.outpost().yard, "an outpost's yard of %d does not hold a %s's needs (%d)" % [BuildingSpec.outpost().yard, s.title, total])
		if s.makes != "" and s.period > 0.0:
			t.ok(s.tank >= s.burns * s.holds, "a %s's tank does not run it till it is full" % s.title)
	t.ok(BuildingSpec.outpost().tank >= Contracts.FETCH * 10, "an outpost's tank fetches fewer than 10 trucks")
	t.note = "the pickup alone carries %.0f L in barrels" % pickup


func test_the_sawmill_keeps_up_with_the_bridges(t: TCase) -> void:
	var mill := BuildingSpec.sawmill()
	var gorge := BuildingSpec.road_site(t.world.land.spot("bridge:gorge"))
	var plant := BuildingSpec.plant()
	var timber := int(gorge.needs.timber) + int(plant.needs.timber)  # the gorge's side of the arc
	var minutes := timber * mill.period / 60.0
	t.note = "timber for the plant and the gorge bridge: %d loads, %.0f min of a sawmill, %d L of fuel" % [timber, minutes, timber * mill.burns]
	t.ok(minutes <= 15.0, "a sawmill takes %.0f min over the gorge's timber" % minutes)
	t.ok(mill.trees <= 12 and timber <= 12, "a sawmill's trees do not last the gorge's timber")
