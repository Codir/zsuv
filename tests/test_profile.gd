extends RefCounted
## Saving (docs/plan.md §11, §12): a new game sets out the railhead's trucks; everything §11 lists
## round-trips through the profile on disk (the trucks with their fuel, loads and trailers, the
## buildings and sites, the earthworks, the fog, the scout's track, the waypoint, the stats); and a
## save from another map version drops its earthworks with a message, not an error.

const SCENE := preload("res://scenes/main.tscn")
const PATH := "user://test_profile_world.cfg"


func test_a_new_game_sets_out_the_railheads_trucks(t: TCase) -> void:
	_wipe()
	var p := _new_game()
	var world := await _world(t, p)
	var ids := PackedStringArray()
	for v in world.fleet.trucks:
		ids.append(v.spec.id)
	ids.sort()
	t.eq(ids, PackedStringArray(["mixer", "pickup", "scout", "tractor"]), "the trucks at the railhead")
	t.eq(world.vehicle.spec.id, "scout", "the truck driven")
	var pickup: Vehicle = world.fleet.find("pickup")
	var tractor: Vehicle = world.fleet.find("tractor")
	t.ok(pickup and pickup.trailer and pickup.trailer.spec.id == "trailer", "the pickup's trailer is not hitched")
	t.ok(tractor and tractor.trailer and tractor.trailer.spec.id == "farm", "the tractor's tipper is not hitched")
	var spawn: Vector3 = world.contracts.spawn_pos
	for v in world.fleet.trucks:
		t.ok(v.global_position.distance_to(spawn) < 40.0, "the %s is %.0f m from the railhead" % [v.spec.id, v.global_position.distance_to(spawn)])
		t.ok(v.global_transform.basis.y.y > 0.9, "the %s is not upright" % v.spec.id)
	t.ok(not world.profile.new_game, "the start set out again on the next load")
	_free(world)
	_wipe()


func test_everything_round_trips(t: TCase) -> void:
	_wipe()
	var p := _new_game()
	var world := await _world(t, p)
	var infra: Infra = world.infra
	var land: Land = world.land
	# A site with parts in it, and a fuel station built with fuel in it.
	var B := preload("res://tests/test_building.gd")
	var site := infra.place("fuel_station", B.spot(infra, "fuel_station", Vector2(-40.0, -40.0)), 0.0)
	var station := infra.place("fuel_station", B.spot(infra, "fuel_station", Vector2(40.0, 40.0)), 0.0)
	if not t.ok(site != null and station != null, "nowhere for two fuel stations"):
		_free(world)
		return
	site.deliver("parts", 1.0)
	station.deliver("parts", 1.0)
	station.deliver("concrete", 1.0)
	station.deliver("fuel", 300.0)
	infra.railhead.stock["timber"] = 2.0
	# Earthworks: a heap dumped by the railhead.
	var heap := Vector2(-60.0, -30.0)
	var before := land.get_height(heap.x, heap.y)
	land.earthworks.dump(heap, 3.0)
	var after := land.get_height(heap.x, heap.y)
	t.ok(after > before + 0.05, "the dump did not raise the ground")
	# The fog seen far off, the scout's track, a waypoint.
	var far := Vector2(100.0, 100.0)
	land.fog.reveal(far, 30.0)
	world.map_screen.scout_track = PackedVector2Array([Vector2(1, 2), Vector2(3, 4)])
	world.contracts.toggle_waypoint(Vector2(50.0, -20.0))
	# The trucks: the pickup moved off with fuel in its barrels and its tank half full, the
	# tractor's tipper left standing on its own.
	var pickup: Vehicle = world.fleet.find("pickup")
	var tractor: Vehicle = world.fleet.find("tractor")
	var tipper := tractor.trailer
	tractor.unhitch()
	pickup.fuel = 33.0
	Loads.put(pickup, "fuel", 250.0)
	var moved := Vector2(world.contracts.spawn_pos.x, world.contracts.spawn_pos.z) + Vector2(25.0, 30.0)
	pickup.set_down(Vector3(moved.x, land.get_height(moved.x, moved.y) + 1.2, moved.y), 1.0)
	await t.ticks(90)
	var pickup_at := pickup.global_position
	var tipper_at := tipper.global_position
	infra.stats["fuel_burnt"] = 12.5
	world.saver.save()
	_free(world)

	var q := Profile.open(PATH)
	var again := await _world(t, q)
	var infra2: Infra = again.infra
	var placed := infra2.sites.filter(func(s: Site) -> bool: return s != infra2.village and s.key == "")
	t.eq(placed.size(), 2, "the buildings and sites")
	if placed.size() == 2:
		t.ok(not placed[0].built and placed[0].needs_left() == {"concrete": 1.0}, "the site: %s" % [placed[0].needs_left()])
		t.ok(placed[1].built and placed[1].fuel == 300.0, "the fuel station")
	t.eq(infra2.railhead.stock.get("timber", 0.0), 2.0, "the railhead's timber")
	t.ok(absf(again.land.get_height(heap.x, heap.y) - after) < 0.02, "the heap: %.2f m, saved %.2f, as made %.2f" % [again.land.get_height(heap.x, heap.y), after, before])
	t.ok(again.land.fog.seen(far), "the fog far off is back")
	t.eq(again.map_screen.scout_track.slice(0, 2), PackedVector2Array([Vector2(1, 2), Vector2(3, 4)]), "the scout's track")
	t.eq(again.contracts.target.get("pos"), Vector2(50.0, -20.0), "the waypoint")
	t.ok(float(infra2.stats.get("fuel_burnt", 0.0)) >= 12.5 and float(infra2.stats.get("fuel_burnt", 0.0)) < 13.0, "the stats: %s" % [infra2.stats])
	var pickup2: Vehicle = again.fleet.find("pickup")
	if t.ok(pickup2 != null, "the pickup is not out on the map"):
		t.ok(pickup2.global_position.distance_to(pickup_at) < 1.0, "the pickup is %.1f m from where it was left" % pickup2.global_position.distance_to(pickup_at))
		t.eq(pickup2.fuel, 33.0, "the pickup's tank")
		t.eq(Loads.amount(pickup2, "fuel"), 250.0, "the pickup's barrels")
		t.ok(pickup2.trailer and pickup2.trailer.spec.id == "trailer", "the pickup's trailer is not hitched")
	var tipper2: Trailer = again.contracts._trailer("farm")
	t.ok(tipper2 and tipper2.truck == null and tipper2.global_position.distance_to(tipper_at) < 1.5, "the tipper is not where it was left")
	t.eq(again.vehicle.spec.id, "scout", "the truck driven")
	_free(again)
	_wipe()


func test_a_save_from_another_map_drops_its_earthworks(t: TCase) -> void:
	_wipe()
	var world := await _world(t, _new_game())
	var heap := Vector2(-60.0, -30.0)
	var before: float = world.land.get_height(heap.x, heap.y)
	world.land.earthworks.dump(heap, 3.0)
	world.saver.save()
	_free(world)
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	var ew: Dictionary = cfg.get_value("world", "earthworks", {})
	ew["map_version"] = -7
	cfg.set_value("world", "earthworks", ew)
	cfg.save(PATH)
	var said: Array[String] = []
	var again := await _world(t, Profile.open(PATH))
	for l in again.hud.find_children("*", "Label", true, false):
		said.append((l as Label).text)
	t.ok(said.any(func(s: String) -> bool: return s.begins_with("The map has changed since this save")), "no message about the earthworks")
	t.ok(absf(again.land.get_height(heap.x, heap.y) - before) < 0.02, "the ground is not as made")
	_free(again)
	_wipe()


static func _new_game() -> Profile:
	var p := Profile.new()
	p.path = PATH
	p.truck = "scout"
	p.new_game = true
	return p


## A steppe world on profile p, built and settled (the trucks set out and hitched).
static func _world(t: TCase, p: Profile) -> Node:
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(480, 270)
	var world = SCENE.instantiate()
	world.valley = Valley.steppe()
	world.profile = p
	vp.add_child(world)
	t.tree.root.add_child(vp)
	await t.ticks(60)
	return world


static func _free(world: Node) -> void:
	world.get_parent().free()


static func _wipe() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
