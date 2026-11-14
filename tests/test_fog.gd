extends RefCounted
## The fog over the map (docs/plan.md §3, §12): each truck uncovers its radius, the scout more and
## more again on a hilltop; a thing is found once its middle is uncovered, not before; the fog
## survives a save and a load; the paper map draws what is uncovered and the scout's track.

const OPEN := Vector2(40.0, 60.0)  # open ground in the khutir valley


func test_each_truck_uncovers_its_radius_and_the_scout_more_on_a_hill(t: TCase) -> void:
	var land: Land = t.world.land
	var v: Vehicle = t.world.vehicle
	var fog := Fog.new(land)
	await t.place(OPEN, 0.0, 30)
	var r := fog.radius_of(v)
	t.eq(r, Fog.TRUCK, "the pickup uncovers")
	fog.reveal(OPEN, r)
	t.ok(fog.seen(OPEN + Vector2(Fog.TRUCK - Fog.TEXEL, 0.0)), "the pickup did not uncover %d m off" % int(Fog.TRUCK - Fog.TEXEL))
	t.ok(not fog.seen(OPEN + Vector2(Fog.TRUCK + Fog.TEXEL * 1.5, 0.0)), "the pickup uncovered more than its radius")
	var spec_id := v.spec.id
	v.spec.id = "scout"
	t.eq(fog.radius_of(v), Fog.SCOUT, "the scout uncovers on the flat")
	# A hilltop: 15 m or more over the ground within 60 m.
	var hill := _hilltop(land)
	t.ok(hill != Vector2.INF, "no hilltop on the map")
	await t.place(hill, 0.0, 30)
	t.eq(fog.radius_of(v), Fog.SCOUT_HIGH, "the scout uncovers on the hill at %s" % hill)
	v.spec.id = spec_id
	await t.place(Vector2(t.world.contracts.spawn_pos.x, t.world.contracts.spawn_pos.z), t.world.contracts.spawn_yaw, 30)


func test_a_thing_is_found_once_uncovered_not_before(t: TCase) -> void:
	var land: Land = t.world.land
	var fog := Fog.new(land)
	var got: Array[Dictionary] = []
	fog.found.connect(func(th: Dictionary) -> void: got.append(th))
	var farm: Dictionary = fog.things.filter(func(th: Dictionary) -> bool: return th.id == "khutir:farm")[0]
	fog.reveal(farm.pos + Vector2(80.0, 0.0), 40.0)
	t.ok(not farm.found, "the farm is found 80 m off with 40 m uncovered")
	t.ok(not got.any(func(th: Dictionary) -> bool: return th.id == farm.id), "the farm was told found too soon")
	fog.reveal(farm.pos + Vector2(30.0, 0.0), 40.0)
	t.ok(farm.found, "the farm is not found with it uncovered")
	t.ok(got.any(func(th: Dictionary) -> bool: return th.id == farm.id), "no word that the farm was found")
	# Every barrier and crossing on the route can be found, and every biome.
	var kinds := {}
	for th in fog.things:
		kinds[th.kind] = kinds.get(th.kind, 0) + 1
	t.eq(kinds.get("biome", 0), 5, "biomes to find")
	t.eq(kinds.get("washout", 0), 1, "washouts to find")
	t.eq(kinds.get("slide", 0), 1, "landslides to find")
	t.eq(kinds.get("crossing", 0), 4, "crossings to find: both banks of the river and of the gorge")
	t.ok(t.world.land.fog.is_found("biome:khutir"), "the biome the world starts in is not found")


func test_the_fog_survives_a_save_and_a_load(t: TCase) -> void:
	var land: Land = t.world.land
	var fog := Fog.new(land)
	fog.reveal(OPEN, 60.0)
	fog.reveal(Vector2(-200.0, 10.0), 30.0)
	var saved := fog.to_save()
	var again := Fog.new(land)
	again.load_save(saved)
	for id in fog.masks:
		t.eq(again.masks[id], fog.masks[id], "%s's fog after a load" % id)
	for i in fog.things.size():
		t.eq(again.things[i].found, fog.things[i].found, "%s found after a load" % fog.things[i].id)
	var packed := 0
	for id in saved.masks:
		packed += (saved.masks[id] as PackedByteArray).size()
	t.ok(packed < 5 * Fog.RES * Fog.RES / 4, "the fog saved takes %d bytes" % packed)


func test_the_paper_map_draws_what_is_uncovered_and_the_scouts_track(t: TCase) -> void:
	var world = t.world
	var ms: MapScreen = world.map_screen
	var v: Vehicle = world.vehicle
	var spec_id := v.spec.id
	v.spec.id = "scout"
	await t.place(OPEN, 0.0, 10)
	await t.place(OPEN + Vector2(20.0, 0.0), 0.0, 10)
	v.spec.id = spec_id
	t.ok(ms.scout_track.size() >= 2, "the scout's track is not kept: %d points" % ms.scout_track.size())
	world._toggle_map()
	await t.ticks(3)
	var fog: Image = ms._fog_img
	var at := Vector2i(((OPEN - ms._bounds.position) / Fog.TEXEL).floor())
	t.ok(fog.get_pixel(at.x, at.y).r > 0.5, "the map does not show the ground the truck uncovered")
	var far := Vector2i(((Vector2(110.0, -620.0) - ms._bounds.position) / Fog.TEXEL).floor())  # the foothills' far corner
	t.ok(fog.get_pixel(far.x, far.y).r < 0.5, "the map shows the foothills never driven to")
	ms.zoom()
	await t.ticks(2)
	t.eq(ms._view, ms._bounds, "zoomed out, the map shows")
	world._toggle_map()
	await t.place(Vector2(world.contracts.spawn_pos.x, world.contracts.spawn_pos.z), world.contracts.spawn_yaw, 30)


## A point on the map 16 m or more over the ground all round within 60 m, or INF.
func _hilltop(land: Land) -> Vector2:
	var best := Vector2.INF
	var r := land.bounds()
	for z in range(int(r.position.y) + 40, int(r.end.y) - 40, 8):
		for x in range(int(r.position.x) + 40, int(r.end.x) - 40, 8):
			var p := Vector2(x, z)
			if not land.on_map(p, 70.0) or land.water_level(p, 10.0) > -INF:
				continue
			var h := land.get_height(p.x, p.y)
			var low := INF
			for k in 12:
				var q := p + Vector2.from_angle(k * TAU / 12.0) * Fog.HIGH_REACH
				low = minf(low, land.get_height(q.x, q.y))
			if h - low >= Fog.HIGH + 1.5 and land.road_distance(p) > 6.0:
				return p
	return best
