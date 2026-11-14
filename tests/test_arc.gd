extends RefCounted
## The whole arc (docs/plan.md §1, §3, §13): a new game played through from the railhead to the
## upper village by test hooks. The trucks are set down where they go instead of driven (test_map
## drives every road and crossing), and the ground is made as the bucket and the tipper would make
## it (test_earthworks digs and spreads for real); every load is hauled through the yards and sites
## with E, every building stands on what was brought to it, the concrete is poured before it sets
## by the road's real length, and the end card counts it all.

const SCENE := preload("res://scenes/main.tscn")
const B := preload("res://tests/test_building.gd")
const MIXER_SPEED := 8.0  # m/s the mixer averages on the roads, loaded (it tops out at about 12)
const OFFROAD := 1.3  # the road is this much longer than the straight line

var world: Node
var infra: Infra
var land: Land
var placed_by_hook := PackedStringArray()


func test_the_whole_arc_from_the_railhead_to_the_upper_village(t: TCase) -> void:
	var shared: Vehicle = t.world.vehicle
	shared.autodrive = true
	var p := Profile.new()
	p.truck = "scout"
	p.new_game = true
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(480, 270)
	world = SCENE.instantiate()
	world.valley = Valley.steppe()
	world.profile = p
	vp.add_child(world)
	t.tree.root.add_child(vp)
	await t.ticks(60)
	infra = world.infra
	land = world.land
	await _arc(t)
	vp.free()
	shared.autodrive = false


func _arc(t: TCase) -> void:
	var c: Contracts = world.contracts
	var pickup: Vehicle = world.fleet.find("pickup")
	var tractor: Vehicle = world.fleet.find("tractor")
	var mixer: Vehicle = world.fleet.find("mixer")
	if not t.ok(pickup and tractor and mixer and pickup.trailer and tractor.trailer, "the railhead's trucks are not set out"):
		return
	# The first minute: the village calls, and the arrow points at it, far off.
	t.ok(c.goal.get("pos") == infra.village.at, "the arrow does not point at the village")
	t.ok(c.objective_text().begins_with("AT THE") or c.objective_text().begins_with("THE UPPER VILLAGE"), "objective: " + c.objective_text())
	t.ok(_said("The upper village calls"), "no radio call from the village")
	var ledger_before := infra.ledger().size()
	# The scout goes ahead: the route's places, crossings and barriers are found.
	for th in land.fog.things:
		land.fog.reveal(th.pos, 60.0)
	t.ok(infra.ledger().size() > ledger_before + 4, "the ledger does not grow with what was found: %s" % [infra.ledger()])
	var road := func(id: String) -> Site:
		for s in infra.sites:
			if s.key == id:
				return s
		return null
	var fill: Site = road.call("fill:steppe" + _feature(land, "steppe", "washout"))
	var river: Site = road.call("bridge:river")
	var bog: Site = road.call("gravel_road:polissia0")
	var slide: Site = road.call("slide:zakarpattia" + _feature(land, "zakarpattia", "slide"))
	var gorge: Site = road.call("bridge:gorge")
	var mill: Site = road.call("ruin:khutir:lumber")
	var peat: Site = road.call("ruin:polissia:peat")
	for s in [fill, river, bog, slide, gorge, mill, peat]:
		if not t.ok(s != null, "a site on the route is missing: %s" % [infra.sites.map(func(x: Site) -> String: return x.key)]):
			return

	# 1. The washout, filled with the tipper (the ground as it would be).
	_ramp(land.spot(fill.key))
	infra.check_roads()
	t.ok(fill.built, "the filled washout is not done: " + fill.line())

	# 2. The river bridge: the railhead's timber on the tractor, its plant's concrete in the mixer.
	for i in 3:
		await _haul(t, tractor, "timber", infra.railhead, river)
	for i in 2:
		await _haul(t, mixer, "concrete", infra.railhead, river)
	t.ok(river.built and land.bridges.has(river.key), "the river bridge does not stand: " + river.line())

	# 3. The forest: the old sawmill back to work with parts, and fuel for it, the quarry and the
	# plant in the pickup's barrels.
	await _haul(t, pickup, "parts", infra.railhead, mill)
	t.ok(mill.built, "the old sawmill does not run: " + mill.line())
	var bank := _deposit("khutir")
	var quarry := _put("quarry", bank)
	await _haul(t, pickup, "parts", infra.railhead, quarry)
	await _haul(t, tractor, "timber", infra.railhead, quarry)
	t.ok(quarry.built, "the quarry does not stand: " + quarry.line())
	t.eq(infra.railhead.available("timber"), 0.0, "the railhead's timber after the bridge and the quarry")
	await _haul(t, pickup, "fuel", infra.railhead, mill)
	await _unload(t, pickup, quarry)
	Loads.clear(pickup)  # the 200 L the two had no room for, left in a barrel at the quarry
	t.ok(mill.fuel > 0.0 and quarry.fuel > 0.0, "no fuel in the sawmill or the quarry")

	# 4. The bog: 7 loads of gravel from the quarry, spread across it.
	var spread := 0
	var bog_spot := land.spot(bog.key)
	var loads := int(bog_spot.needs.get("gravel", 7))
	while spread < loads:
		await _made(t, quarry, "gravel")
		await _haul(t, tractor, "gravel", quarry, null)
		_spread(bog_spot, spread, loads)
		Loads.take(tractor, "gravel", 1.0)
		spread += 1
	infra.check_roads()
	t.ok(bog.built, "the gravel road is not done after %d loads: %s" % [loads, bog.line()])

	# 5. The peat works' tank, and the landslide dug out.
	t.ok(peat.available("fuel") >= 3000.0, "the peat works' tank: " + peat.line())
	_ramp(land.spot(slide.key))
	infra.check_roads()
	t.ok(slide.built, "the landslide is not cleared: " + slide.line())

	# 6. The foothills: a concrete plant by the gorge, from the sawmill's timber and the quarry's
	# gravel, fuelled from the pickup's barrels; its concrete and the sawmill's timber bridge the gorge.
	var plant := _put("plant", Vector2(gorge.ends[0].x, gorge.ends[0].z), 10.0, 160.0)
	await _haul(t, pickup, "parts", infra.railhead, plant)
	await _haul(t, pickup, "parts", infra.railhead, plant)
	for i in 2:
		await _made(t, mill, "timber")
		await _haul(t, tractor, "timber", mill, plant)
	await _made(t, quarry, "gravel")
	await _haul(t, tractor, "gravel", quarry, plant)
	t.ok(plant.built, "the concrete plant does not stand: " + plant.line())
	await _haul(t, pickup, "fuel", peat, plant)
	Loads.clear(pickup)  # what the plant had no room for goes back to the peat works' tank
	for i in 2:
		await _made(t, quarry, "gravel")
		await _haul(t, tractor, "gravel", quarry, plant)
	for i in 3:
		await _made(t, mill, "timber")
		await _haul(t, tractor, "timber", mill, gorge)
	for i in 2:
		await _haul(t, mixer, "concrete", plant, gorge)
	t.ok(gorge.built and land.bridges.has(gorge.key), "the gorge bridge does not stand: " + gorge.line())

	# 7. The upper village: fuel from the peat works and parts from the railhead.
	t.ok(pickup.trailer != null, "the pickup lost its trailer on the way")
	var card: EndCard = world.end_card
	await _haul(t, pickup, "fuel", peat, infra.village)
	await _haul(t, pickup, "parts", infra.railhead, infra.village)
	await _haul(t, pickup, "parts", infra.railhead, infra.village)
	t.ok(infra.village.built, "the village does not have what it asked for: %s" % [infra.village.needs_left()])
	t.ok(card.visible, "no end card")
	var st := infra.stats
	t.eq(int(st.get("bridges", 0)), 2, "bridges on the end card")
	t.eq(int(st.get("buildings", 0)), 3, "buildings on the end card (the old sawmill, the quarry, the plant)")
	t.ok(int(st.get("trees_felled", 0)) >= 5, "trees felled: %d for 5 loads of timber" % int(st.get("trees_felled", 0)))
	t.ok(float(st.get("road_m", 0.0)) > 30.0, "road built: %.0f m" % float(st.get("road_m", 0.0)))
	t.ok(card.text.contains("Bridges            2"), "the card: " + card.text)
	t.note = "placed by hook (no level green ground found): %s; road built %.0f m" % [", ".join(placed_by_hook) if not placed_by_hook.is_empty() else "none", float(st.get("road_m", 0.0))]
	t.note += "; the plant %.0f m from the gorge" % plant.at.distance_to(Vector2(gorge.ends[0].x, gorge.ends[0].z))


## Whether the HUD's message line has said text (it shows one at a time, so the latest few).
func _said(text: String) -> bool:
	for l in world.hud.find_children("*", "Label", true, false):
		if (l as Label).text.contains(text):
			return true
	return false


## The feature index of the first feature of type in biome id, as Land's spot ids number them.
static func _feature(l: Land, id: String, type: String) -> String:
	for tile in l.tiles:
		if tile.valley.id == id:
			for i in tile.valley.features.size():
				if tile.valley.features[i].type == type:
					return str(i)
	return "?"


## The gravel bank in biome id.
func _deposit(id: String) -> Vector2:
	for d in land.deposits():
		if d.biome == id:
			return d.pos
	return infra.deposits[0].pos


## A site of kind placed by the player near at, where it can go (a hook places it right there when
## no green ground is near, as the bucket would level it).
func _put(kind: String, at: Vector2, skip := 0.0, reach := 40.0) -> Site:
	var spot := Vector2.INF
	var pts: Array[Vector2] = []
	var n := int(reach / 2.0)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			pts.append(at + Vector2(i, j) * 2.0)
	pts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(at) < b.distance_squared_to(at))
	for p in pts:
		if p.distance_to(at) >= skip and infra.check(kind, p, 0.0) == "":
			spot = p
			break
	if spot.x < INF:
		return infra.place(kind, spot, 0.0)
	placed_by_hook.append(kind)
	var s := Site.new()
	s.spec = BuildingSpec.find(kind)
	s.at = at + Vector2(skip, 0.0)
	infra._add(s)
	return s


## Where a truck stands to use s: the railhead's middle, a bridge's first bank, else across the
## front of its footprint.
func _at(s: Site) -> Array:
	if s == infra.railhead:
		return [s.at, 0.0]
	if s.spec.id == "bridge":
		var a: Vector3 = s.ends[0]
		var b: Vector3 = s.ends[1]
		var dir := Vector2(b.x - a.x, b.z - a.z).normalized()
		return [Vector2(a.x, a.z) - dir * 3.0, atan2(-dir.x, -dir.y)]
	if s == infra.village or s.key.begins_with("ruin:"):
		return [s.at + Vector2(0.0, -s.spec.size.y * 0.5 - 2.0), 0.0]
	# Just out of its front (a quarry's footprint is its pit), across it, the trailer alongside.
	return [s.at + Vector2(0.0, -s.spec.size.y * 0.5 - 2.5).rotated(-s.yaw), s.yaw + PI * 0.5]


func _stand(t: TCase, v: Vehicle, s: Site) -> void:
	if world.vehicle != v:
		world.fleet.drive_truck(v)
		await t.ticks(2)
	var at: Array = _at(s)
	var p: Vector2 = at[0]
	v.fuel = v.spec.fuel_capacity
	var had := v.trailer
	v.teleport(Vector3(p.x, land.get_height(p.x, p.y) + 1.2, p.y), at[1])
	await t.ticks(30)
	if had and v.trailer == null:  # no room for it where the truck was set down: brought along
		had.place(had.behind(Transform3D(v.global_transform.basis, v.hitch_point())))
		await t.ticks(3)
		v.hitch(had)
		await t.ticks(10)


## A load of res onto v at from (E, then its line in the yard's list), set down at to (null: it
## stays on) and E there. Concrete ages by the road from one to the other.
func _haul(t: TCase, v: Vehicle, res: String, from: Site, to: Site) -> void:
	await _stand(t, v, from)
	infra.yard = []
	infra.interact()
	var i := -1
	for k in infra.yard.size():
		if infra.yard[k].res == res:
			i = k
	if not t.ok(i >= 0, "the %s finds no %s at the %s: %s" % [v.spec.title.to_lower(), res, from.spec.title.to_lower(), from.line()]):
		return
	infra.load_item(i)
	infra.yard = []
	if to == null:
		return
	if res == "concrete":
		var secs := Vector2(from.at - to.at).length() * OFFROAD / MIXER_SPEED
		v.hold.age += secs
		t.ok(v.hold.age < Hold.CONCRETE_SETS, "the concrete sets on the %.0f s from the %s to the %s" % [secs, from.spec.title.to_lower(), to.spec.title.to_lower()])
	await _stand(t, v, to)
	infra.interact()


## E at s with what v carries (an unload, no loading first).
func _unload(t: TCase, v: Vehicle, s: Site) -> void:
	await _stand(t, v, s)
	infra.yard = []
	infra.interact()
	infra.yard = []


## Game time passes until s has a load of res ready (at most 20 minutes).
func _made(t: TCase, s: Site, res: String) -> void:
	var waited := 0.0
	while s.available(res) < 1.0 and waited < 1200.0:
		infra.advance(10.0)
		waited += 10.0
	t.ok(s.available(res) >= 1.0, "the %s makes no %s in 20 minutes: %s" % [s.spec.title.to_lower(), res, s.line()])
	await t.ticks(1)


## The ground along spot as the bucket leaves a filled washout or a dug-out slide: an even ramp
## from one end of its road to the other, the corridor's width.
func _ramp(spot: Dictionary) -> void:
	var path: PackedVector2Array = spot.path
	var a: Vector3 = spot.a
	var b: Vector3 = spot.b
	var ew := land.earthworks
	var half := float(spot.width) * 0.5 + 1.0
	var done := {}
	for i in path.size():
		var k := float(i) / maxf(path.size() - 1, 1)
		var h := lerpf(a.y, b.y, k)
		var p := path[i]
		for dz in range(-ceili(half), ceili(half) + 1):
			for dx in range(-ceili(half), ceili(half) + 1):
				var v := Vector2i(roundi(p.x) + dx, roundi(p.y) + dz)
				if Vector2(v).distance_to(p) <= half and not done.has(v):
					done[v] = true
					ew.set_height(v.x, v.y, h)


## The share k/n..(k+1)/n of the bog road's corridor spread with gravel, as V behind the tipper.
func _spread(spot: Dictionary, k: int, n: int) -> void:
	var path: PackedVector2Array = spot.path
	var from := int(float(k) / n * path.size())
	var to := int(float(k + 1) / n * path.size())
	for i in range(from, mini(to, path.size())):
		land.earthworks.spread_gravel(path[i], float(spot.width) * 0.5)
