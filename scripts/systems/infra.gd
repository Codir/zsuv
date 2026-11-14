class_name Infra
extends Node3D
## The infrastructure the player builds (docs/plan.md §5, §6): P places a building where the
## mouse points, green where it can go and red with the reason where it cannot; placed, it is a site
## until E has brought every load it needs; built, it holds fuel and loads, and makes what it makes
## on its timer wherever the player is. The railhead is the first base: fuel and parts without
## end, a concrete plant with gravel in it, and timber in its yard; an outpost built is another.
## The upper village, in the mountains, is the goal: its fuel and parts brought, the game is won.
## Loads come on and off the truck with E, through Loads.

signal message(text: String)
signal changed  # something to save: a site, a load, a building's stock (Saver listens)
signal finished  # the upper village has what it asked for: the end card (main.gd)

enum Mode { NONE, PICK, PLACE }

const REACH := 40.0  # the footprint follows the cursor this far from the truck at most
const APART := 6.0  # from another building, a site or a place
const LEVEL := 0.6  # the most its ground may rise across its footprint, m
const USE := 4.0  # E works this far out of a footprint
const RAILHEAD_RADIUS := 12.0  # E works this far from the railhead's middle
const SLOW := 2.0  # m/s: stopped, for E and P
const TURN := PI / 12.0  # a notch of the mouse wheel
const SAVE_EVERY := 10.0  # s, while something is making
const RAILHEAD_STOCK := {"timber": 4.0, "gravel": 2.0}
const PIT_LOAD := 10.0  # m3 a quarry digs out of its pit for a load of gravel
const PIT_DEEPEST := 4.0  # m under the ground as made: the quarry is dug out
const PIT_MARGIN := 2.0  # m of its footprint's edge left undug
const VILLAGE := ["carpathians", "village"]  # the upper village: its biome and its place
## Gravel a quarry can go on, by biome, in the biome's own metres (docs/plan.md §3): the
## steppe's gullies, the forest's rocky slopes, the foothills' stony slopes.
const DEPOSITS := {
	"steppe": [{"pos": Vector2(-96.0, 9.0), "radius": 18.0}, {"pos": Vector2(24.0, 12.0), "radius": 16.0}],
	"khutir": [{"pos": Vector2(60.0, -40.0), "radius": 18.0}],
	"zakarpattia": [{"pos": Vector2(-40.0, 40.0), "radius": 18.0}],
}

var vehicle: Vehicle
var land: Land
var profile := Profile.new()
var camera: Camera3D
var contracts: Contracts  # its garage closes the lists here
var locations := {}  # every place on the map, world metres: nothing is built on their flats
var trees := PackedVector2Array()  # every tree on the map, world metres
var felled := {}  # tree index -> true: gone (to a sawmill, a site, or the bucket)
var deposits: Array[Dictionary] = []  # {pos, radius}, world: gravel a quarry can go on
var sites: Array[Site] = []  # the player's, sites and buildings, and the upper village
var railhead: Site
var village: Site  # the goal; null on a map without it
var stats := {}  # what the end card counts: buildings, trees_felled, fuel_burnt, played (Profile.stats)
var prompt := ""
var panel := ""  # the list on screen: what P builds, or what can be loaded here
var mode := Mode.NONE
var picked: BuildingSpec  # being placed
var ghost_at := Vector2.ZERO
var ghost_yaw := 0.0
var ghost_why := ""  # why it cannot go where it is ("" it can)
var yard: Array[Dictionary] = []  # what E can load here: [{res, from: Site}]; empty: the list is shut

var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var _save_timer := 0.0
var _felled_seen := 0  # land.earthworks.felled's size when last read
var _tree_at := {}  # Vector2i (a tree's point to 10 cm) -> its index
var _fuel_seen := -1.0  # the driven truck's fuel a tick ago, for the fuel burnt
var _fuel_of: Vehicle


func setup(v: Vehicle, l: Land, p: Profile, cam: Camera3D, locs: Dictionary, tree_points := PackedVector2Array()) -> void:
	vehicle = v
	land = l
	profile = p if p else Profile.new()
	camera = cam
	stats = profile.stats.duplicate()
	trees = land.tree_points if not land.tree_points.is_empty() else tree_points
	for i in trees.size():
		_tree_at[Vector2i((trees[i] * 10.0).round())] = i
	if not InputMap.has_action("build"):
		InputMap.add_action("build")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_P
		InputMap.action_add_event("build", ev)
	locations = {}
	for t in land.tiles:
		for key in t.valley.locations:
			var loc: Dictionary = t.valley.locations[key].duplicate()
			loc.pos = (loc.pos as Vector2) + t.origin
			locations["%s:%s" % [t.valley.id, key]] = loc
			if loc.get("kind", "") == "gravel":
				deposits.append({"pos": loc.pos, "radius": float(loc.get("radius", 10.0))})
		for d in DEPOSITS.get(t.valley.id, []):
			deposits.append({"pos": (d.pos as Vector2) + t.origin, "radius": d.radius})
	railhead = Site.new()
	railhead.spec = BuildingSpec.railhead()
	railhead.at = locs.depot.pos
	railhead.built = true
	railhead.endless = PackedStringArray(["fuel", "parts"])
	railhead.stock = RAILHEAD_STOCK.duplicate()
	railhead.name = "Railhead"
	add_child(railhead)
	var vloc: Variant = locations.get(":".join(VILLAGE))
	if vloc != null:
		village = Site.new()
		village.spec = BuildingSpec.village()
		village.at = vloc.pos
		village.name = "Village"
		_add(village)
	var crossings := land.crossings()
	for i in crossings.size():
		var c: Dictionary = crossings[i]
		var bridge := Site.new()
		bridge.spec = BuildingSpec.bridge(float(c.over))
		bridge.ends = [c.a, c.b] as Array[Vector3]
		bridge.key = "bridge%d" % i
		bridge.at = Vector2((c.a.x + c.b.x) * 0.5, (c.a.z + c.b.z) * 0.5)
		var d := Vector2(c.b.x - c.a.x, c.b.z - c.a.z)
		bridge.yaw = atan2(d.x, d.y)
		bridge.name = "Bridge%d" % i
		_add(bridge)
	_load_saved()
	_sync_felled()
	_ghost = MeshInstance3D.new()
	_ghost.mesh = BoxMesh.new()
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost.material_override = _ghost_mat
	_ghost.visible = false
	add_child(_ghost)


# --- Placing -----------------------------------------------------------------------------------

## Why a building of kind cannot stand at at, turned yaw: "" when it can.
func check(kind: String, at: Vector2, yaw: float) -> String:
	var s := BuildingSpec.find(kind)
	if s == null or s.id in ["railhead", "village"]:
		return "Nothing to build"
	var corners := Site.footprint(s, at, yaw)
	for c in corners:
		if not land.on_map(c, APART):
			return "Off the map"
	var low := INF
	var high := -INF
	var n := Vector2i(ceili(s.size.x / 2.0), ceili(s.size.y / 2.0))
	for i in n.x + 1:
		for j in n.y + 1:
			var local := Vector2(lerpf(-s.size.x * 0.5, s.size.x * 0.5, float(i) / n.x), lerpf(-s.size.y * 0.5, s.size.y * 0.5, float(j) / n.y))
			var p := at + local.rotated(-yaw)
			var h := land.get_height(p.x, p.y)
			if (i == 0 or i == n.x) and (j == 0 or j == n.y):  # level: between its corners
				low = minf(low, h)
				high = maxf(high, h)
			if land.road_distance(p) < Terrain.ROAD_HALF_WIDTH + 0.5:
				return "On a road: build beside it"
			if land.water_level(p) > h + 0.05:
				return "In water"
			if land.sample(Vector3(p.x, h, p.y)).ice > 0.5:
				return "On ice"
	var grown := Site.footprint(s, at, yaw, APART)
	for key in locations:
		var loc: Dictionary = locations[key]
		if _distance_to(corners, loc.pos) < float(loc.radius) + APART:
			return "Too near the %s" % loc.name
	for other in sites:
		if other == village:
			continue
		if not Geometry2D.intersect_polygons(grown, other.corners()).is_empty():
			return "Too near the %s" % (other.spec.title.to_lower() + ("" if other.built else " site"))
	if high - low > LEVEL:
		return "Not level: %.1f m. Level it with the bucket" % (high - low)
	if s.trees > 0:
		var count := trees_near(at)
		if count < s.trees:
			return "Only %d trees here: a %s needs %d within %d m" % [count, s.title.to_lower(), s.trees, BuildingSpec.TREE_REACH]
	if s.deposit and deposit_at(at).is_empty():
		return "No gravel here: a quarry goes on a gravel deposit"
	return ""


## The deposit at at, or empty.
func deposit_at(at: Vector2) -> Dictionary:
	for d in deposits:
		if at.distance_to(d.pos) < float(d.radius):
			return d
	return {}


## Places a site of kind at at, turned yaw, as a left click does: the site, or null (with the
## reason said) where it cannot go. The trees and rocks on its footprint go, and its flat is not
## to be dug.
func place(kind: String, at: Vector2, yaw: float) -> Site:
	var why := check(kind, at, yaw)
	if why != "":
		message.emit(why)
		return null
	var site := Site.new()
	site.spec = BuildingSpec.find(kind)
	site.at = at
	site.yaw = yaw
	_add(site)
	_clear_footprint(site)
	for s in sites:
		if s.spec.trees > 0:
			s.trees_left = trees_near(s.at)
	message.emit("Staked out: a %s. It needs %s" % [site.spec.title.to_lower(), _needs_text(site)])
	_save()
	return site


## Takes a site with nothing brought to it down: true when it did.
func take_down(site: Site) -> bool:
	if site.built or not site.delivered.is_empty() or site == village or site.key != "":
		return false
	sites.erase(site)
	land.earthworks.keep_out = land.earthworks.keep_out.filter(func(k: Dictionary) -> bool: return k.get("site") != site)
	site.queue_free()
	message.emit("Taken down: the %s site" % site.spec.title.to_lower())
	_save()
	return true


## Trees standing within the sawmill's reach of at.
func trees_near(at: Vector2) -> int:
	_sync_felled()
	var count := 0
	for i in trees.size():
		if not felled.has(i) and trees[i].distance_to(at) <= BuildingSpec.TREE_REACH:
			count += 1
	return count


## The trees the bucket or a site took (land.earthworks.felled), counted as felled here.
func _sync_felled() -> void:
	var gone := land.earthworks.felled
	if gone.size() == _felled_seen:
		return
	if gone.size() < _felled_seen:  # the ground was reset (a save laid over the map)
		felled.clear()
		_felled_seen = 0
	for k in range(_felled_seen, gone.size()):
		var i: Variant = _tree_at.get(Vector2i((gone[k] * 10.0).round()))
		if i != null:
			felled[i] = true
	_felled_seen = gone.size()


## How far p is from the polygon (0 inside it).
static func _distance_to(poly: PackedVector2Array, p: Vector2) -> float:
	if Geometry2D.is_point_in_polygon(p, poly):
		return 0.0
	var best := INF
	for i in poly.size():
		var c := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		best = minf(best, c.distance_to(p))
	return best


func _add(site: Site) -> void:
	site.ground = func(x: float, z: float) -> float: return land.get_height(x, z)
	site.made.connect(_on_made)
	sites.append(site)
	add_child(site)
	if site.spec.trees > 0:
		site.trees_left = trees_near(site.at)
	if site != village:
		land.earthworks.keep_out.append({"pos": site.at, "radius": site.spec.size.length() * 0.5,
			"name": "the " + site.spec.title.to_lower(), "site": site})


## The trees and rocks on site's footprint go.
func _clear_footprint(site: Site) -> void:
	var poly := site.corners(1.0)
	for i in trees.size():
		if not felled.has(i) and Geometry2D.is_point_in_polygon(trees[i], poly):
			land.earthworks.fell(trees[i])
	for a in land.anchor_points:
		var p := Vector2(a.x, a.z)
		if Geometry2D.is_point_in_polygon(p, poly):
			land.earthworks.fell(p)
	_sync_felled()


# --- Bases -------------------------------------------------------------------------------------

## The railhead and every outpost built.
func bases() -> Array[Site]:
	var out: Array[Site] = [railhead]
	for s in sites:
		if s.built and s.spec.id == "outpost":
			out.append(s)
	return out


## The base the point p is at, or null.
func base_near(p: Vector2) -> Site:
	if p.distance_to(railhead.at) < RAILHEAD_RADIUS:
		return railhead
	for s in bases():
		if s != railhead and s.contains(p, USE):
			return s
	return null


## The base nearest p.
func nearest_base(p: Vector2) -> Site:
	var best := railhead
	for s in bases():
		if p.distance_to(s.at) < p.distance_to(best.at):
			best = s
	return best


## Where a truck is set down at base b (the tow, the garage): {pos: Vector3, yaw}. The railhead's is
## the spawn.
func base_spawn(b: Site) -> Dictionary:
	if b == railhead or b == null:
		return {"pos": contracts.spawn_pos if contracts else Vector3(railhead.at.x, land.get_height(railhead.at.x, railhead.at.y) + 1.5, railhead.at.y),
			"yaw": contracts.spawn_yaw if contracts else 0.0}
	var p := b.spawn_point()
	return {"pos": Vector3(p.x, land.get_height(p.x, p.y) + 1.5, p.y), "yaw": b.yaw + PI * 0.5}


## Takes up to n of res from base b's yard or tank (the railhead's fuel and parts never run out):
## what it got. The garage's repairs, upgrades and fetches pay this way.
func draw(b: Site, res: String, n: float) -> float:
	var got := b.give(res, n)
	if got > 0.0:
		_save()
	return got


# --- Using: E ----------------------------------------------------------------------------------

## The building or site the truck is at (null none): the railhead first.
func here() -> Site:
	var p := Vector2(vehicle.global_position.x, vehicle.global_position.z)
	if p.distance_to(railhead.at) < RAILHEAD_RADIUS:
		return railhead
	var best: Site = null
	for s in sites:
		if s.contains(p, USE) and (best == null or p.distance_to(s.at) < p.distance_to(best.at)):
			best = s
	return best


## E: at a site, the loads it needs come off; at a building, what it takes comes off, else the
## tank is filled and the list of what can be loaded opens.
func interact() -> void:
	if not yard.is_empty():
		yard = []
		return
	if absf(vehicle.forward_speed) >= SLOW:
		return
	var s := here()
	if s == null:
		return
	if not s.built:
		_bring(s)
		return
	if _unload(s):
		return
	var said := ""
	if s.available("fuel") > 0.0 and vehicle.fuel < vehicle.spec.fuel_capacity - 0.5:
		var got := s.give("fuel", vehicle.spec.fuel_capacity - vehicle.fuel)
		vehicle.fuel += got
		said = "Tank is full" if vehicle.fuel >= vehicle.spec.fuel_capacity - 0.5 else "Took %d L: the tank is dry" % roundi(got)
		_save()
	yard = _loadable(s)
	if said != "":
		message.emit(said)
	elif yard.is_empty():
		if s.spec.tank > 0.0 and s.fuel <= 0.0 and not "fuel" in s.endless:
			message.emit("Dry: bring fuel")
		elif not Loads.carries_any(vehicle):
			message.emit("The %s carries nothing" % vehicle.spec.title.to_lower())
		else:
			message.emit("Nothing here for the %s to take" % vehicle.spec.title.to_lower())


## Loads what the list's item i is onto the truck: a load, or as much fuel as it takes.
func load_item(i: int) -> void:
	if i < 0 or i >= yard.size():
		return
	var item: Dictionary = yard[i]
	var res: String = item.res
	var s: Site = item.from
	var want := Loads.room(vehicle, res)
	if res != "fuel":
		want = minf(want, 1.0)
	var got := 0.0
	if res == "concrete" and s.spec.makes == "concrete":
		if s.spec.burns > 0.0 and s.fuel < s.spec.burns and not "fuel" in s.endless:
			message.emit("The plant has no fuel")
			yard = []
			return
		var gravel := minf(want, float(s.stock.get("gravel", 0.0)))
		got = Loads.put(vehicle, "concrete", gravel)
		s.stock["gravel"] = float(s.stock.get("gravel", 0.0)) - got
		if not "fuel" in s.endless:
			s.fuel -= s.spec.burns
	else:
		got = Loads.put(vehicle, res, minf(want, s.available(res)))
		s.give(res, got)
	if got > 0.0:
		message.emit("Loaded: %s" % Loads.unit(res, got) + (". It sets in 5 minutes" if res == "concrete" else ""))
	yard = _loadable(s)
	_save()


## Brings site s every load on the truck that it needs.
func _bring(s: Site) -> void:
	var brought := PackedStringArray()
	for res in s.needs_left():
		var n := minf(Loads.amount(vehicle, res), float(s.needs_left()[res]))
		if n > 0.0:
			var got := s.deliver(res, Loads.take(vehicle, res, n))
			brought.append(Loads.unit(res, got))
	if brought.is_empty():
		var refusal := ""
		for res in s.needs_left():
			refusal = vehicle.load_refusal(res)
			if refusal == "" or refusal == "Full":
				break
		if refusal != "" and refusal != "Full":
			message.emit("%s. The %s needs %s" % [refusal, s.spec.title.to_lower(), _needs_text(s)])
		else:
			message.emit("The %s needs %s" % [s.spec.title.to_lower(), _needs_text(s)])
		return
	if s.built:
		if s.spec.id == "bridge":
			stats["bridges"] = int(stats.get("bridges", 0)) + 1
			if land.has_method("bridged"):
				land.call("bridged", s.key)
			message.emit("The bridge stands: the road goes across")
		elif s == village:
			message.emit("The upper village has its fuel and parts. The valley is open")
			finished.emit()
		else:
			stats["buildings"] = int(stats.get("buildings", 0)) + 1
			message.emit("The %s stands: %s" % [s.spec.title.to_lower(), s.spec.does()])
	else:
		message.emit("Brought: %s. Still needed: %s" % [", ".join(brought), _needs_text(s)])
	_save()


## Unloads into building s what it takes of what the truck carries: true when anything came off.
func _unload(s: Site) -> bool:
	var put := PackedStringArray()
	for res in Loads.RESOURCES:
		var n := minf(Loads.amount(vehicle, res), s.accepts(res))
		if n > 0.0:
			s.deliver(res, Loads.take(vehicle, res, n))
			put.append(Loads.unit(res, n))
	if put.is_empty():
		return false
	message.emit("Unloaded: %s. %s" % [", ".join(put), s.line()])
	_save()
	return true


## What can be loaded onto the truck at s: what it has that the truck has room for.
func _loadable(s: Site) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for res in Loads.RESOURCES:
		if Loads.room(vehicle, res) <= 0.0:
			continue
		var has := s.available(res) > 0.0
		if res == "concrete" and s.spec.makes == "concrete":
			has = float(s.stock.get("gravel", 0.0)) >= 1.0
		if has:
			out.append({"res": res, "from": s})
	return out


static func _needs_text(s: Site) -> String:
	var bits := PackedStringArray()
	var left := s.needs_left()
	for res in left:
		bits.append(Loads.unit(res, left[res]))
	return ", ".join(bits)


# --- Making ------------------------------------------------------------------------------------

## seconds of game time pass for every building, wherever the truck is.
func advance(seconds: float) -> void:
	for s in sites:
		s.step(seconds)


func _on_made(s: Site, _res: String) -> void:
	if s.spec.trees > 0:
		_fell(s)
	if s.spec.deposit:
		_dig_pit(s)
	_save()


## A sawmill fells the standing tree nearest it: it goes from the world and the map.
func _fell(s: Site) -> void:
	_sync_felled()
	var best := -1
	for i in trees.size():
		if not felled.has(i) and trees[i].distance_to(s.at) <= BuildingSpec.TREE_REACH \
				and (best < 0 or trees[i].distance_to(s.at) < trees[best].distance_to(s.at)):
			best = i
	if best >= 0:
		felled[best] = true
		land.earthworks.fell(trees[best])
		_sync_felled()
		stats["trees_felled"] = int(stats.get("trees_felled", 0)) + 1
	for other in sites:
		if other.spec.trees > 0:
			other.trees_left = trees_near(other.at)


## The vertices of a quarry's pit: its footprint less PIT_MARGIN all round, world metres.
func pit_vertices(s: Site) -> Array[Vector2i]:
	var poly := s.corners(-PIT_MARGIN)
	var out: Array[Vector2i] = []
	var box := Rect2(poly[0], Vector2.ZERO)
	for c in poly:
		box = box.expand(c)
	for z in range(floori(box.position.y), ceili(box.end.y) + 1):
		for x in range(floori(box.position.x), ceili(box.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x, z), poly):
				out.append(Vector2i(x, z))
	return out


## A load of gravel made: its volume comes off the pit, evenly; at PIT_DEEPEST the quarry is dug
## out and stops.
func _dig_pit(s: Site) -> void:
	var ew := land.earthworks
	var verts := pit_vertices(s)
	if verts.is_empty():
		return
	var drop := PIT_LOAD / verts.size()
	var deepest := 0.0
	for v in verts:
		var floor_h := ew.generated(v.x, v.y) - PIT_DEEPEST
		var h := maxf(ew.height(v.x, v.y) - drop, floor_h)
		ew.set_height(v.x, v.y, h)
		deepest = maxf(deepest, ew.generated(v.x, v.y) - h)
	if deepest >= PIT_DEEPEST - drop * 0.5:
		s.halt = "Dug out: %d m deep" % roundi(PIT_DEEPEST)


## The pit's depth: the most the ground in it is below the ground as made.
func pit_depth(s: Site) -> float:
	var deepest := 0.0
	for v in pit_vertices(s):
		deepest = maxf(deepest, land.earthworks.generated(v.x, v.y) - land.earthworks.height(v.x, v.y))
	return deepest


func _physics_process(delta: float) -> void:
	advance(delta)
	stats["played"] = float(stats.get("played", 0.0)) + delta
	if vehicle:
		if vehicle == _fuel_of and vehicle.fuel < _fuel_seen:
			stats["fuel_burnt"] = float(stats.get("fuel_burnt", 0.0)) + (_fuel_seen - vehicle.fuel)
		_fuel_of = vehicle
		_fuel_seen = vehicle.fuel
	_save_timer += delta
	if _save_timer >= SAVE_EVERY:
		_save_timer = 0.0
		if sites.any(func(s: Site) -> bool: return s.on_timer()):
			_save()


# --- The ledger ---------------------------------------------------------------------------------

## A line for every building and site, the railhead first, and the village once found: what it
## holds, needs and does (the paper map's ledger, docs/plan.md §9).
func ledger() -> PackedStringArray:
	var out := PackedStringArray(["Railhead: %s" % railhead.line().trim_prefix("Railhead: ")])
	for s in sites:
		if s == village:
			continue
		if s.spec.id == "bridge" and not s.built and not land.fog.seen(s.at):
			continue  # nothing unfound is shown
		out.append(s.line())
	if village and (village.built or land.fog.is_found(":".join(VILLAGE))):
		out.append("Upper village: " + ("has all it asked for" if village.built else "needs " + _needs_text(village)))
	return out


# --- Keys, the ghost and the prompt -------------------------------------------------------------

func _process(_delta: float) -> void:
	if vehicle == null:
		return
	var stopped := absf(vehicle.forward_speed) < SLOW
	if contracts and contracts.garage_open:
		mode = Mode.NONE
		yard = []
	if not yard.is_empty() and (not stopped or here() != yard[0].from):
		yard = []
	if mode != Mode.NONE and not stopped:
		mode = Mode.NONE
	if mode == Mode.PLACE:
		_follow_cursor()
	_ghost.visible = mode == Mode.PLACE
	panel = _panel_text()
	prompt = _prompt_text(stopped)


## The ghost follows the mouse on the ground, within REACH of the truck.
func _follow_cursor() -> void:
	if camera and camera.is_inside_tree():
		var r := Cursor.ray(camera)
		var hit: Variant = Cursor.ground(r[0], r[1], func(x: float, z: float) -> float: return land.get_height(x, z))
		if hit != null:
			var truck := Vector2(vehicle.global_position.x, vehicle.global_position.z)
			var p := Vector2(hit.x, hit.z)
			ghost_at = truck + (p - truck).limit_length(REACH)
	ghost_why = check(picked.id, ghost_at, ghost_yaw)
	(_ghost.mesh as BoxMesh).size = Vector3(picked.size.x, 0.6, picked.size.y)
	_ghost.global_position = Vector3(ghost_at.x, land.get_height(ghost_at.x, ghost_at.y) + 0.3, ghost_at.y)
	_ghost.rotation = Vector3(0.0, ghost_yaw, 0.0)
	_ghost_mat.albedo_color = Color(0.2, 1.0, 0.3, 0.45) if ghost_why == "" else Color(1.0, 0.2, 0.15, 0.45)


func _panel_text() -> String:
	if mode == Mode.PICK:
		var lines := PackedStringArray(["BUILD", ""])
		var all := BuildingSpec.all()
		for i in all.size():
			var bits := PackedStringArray()
			for res in all[i].needs:
				bits.append(Loads.unit(res, all[i].needs[res]))
			lines.append("%d  %-15s %s" % [i + 1, all[i].title.to_upper(), ", ".join(bits)])
		return "\n".join(lines)
	if not yard.is_empty():
		var s: Site = yard[0].from
		var lines := PackedStringArray([s.line().to_upper(), ""])
		for i in yard.size():
			var res: String = yard[i].res
			var what := res
			if res == "fuel":
				what = "fuel, %d L" % roundi(minf(Loads.room(vehicle, res), s.available(res)))
			elif res == "concrete" and s.spec.makes == "concrete":
				what = "concrete, from gravel %d" % roundi(float(s.stock.get("gravel", 0.0)))
			lines.append("%d  %s" % [i + 1, what])
		return "\n".join(lines)
	return ""


func _prompt_text(stopped: bool) -> String:
	match mode:
		Mode.PICK:
			return "[1]-[%d] pick   [P] close" % BuildingSpec.all().size()
		Mode.PLACE:
			if ghost_why != "":
				return ghost_why
			return "[LMB] Place the %s   [Wheel] turn   [Esc] cancel" % picked.title.to_lower()
	if not yard.is_empty():
		return "[1]-[%d] load   [E] close" % yard.size()
	var s := here()
	if s == null:
		return ""
	if not stopped:
		return "Stop at the %s" % (s.spec.title.to_lower() + ("" if s.built or s == village else " site"))
	if s == village:
		return "The upper village has all it asked for" if s.built else "[E] Bring the village: %s" % _needs_text(s)
	if not s.built:
		var text := "[E] Bring: %s" % _needs_text(s)
		if s.delivered.is_empty():
			text += "   [P] take it down"
		return text
	if s == railhead:
		return "[E] Fuel and loads   [P] Build   [Tab] Garage"
	if s.spec.id == "outpost":
		return "[E] %s   [Tab] Garage" % s.line()
	return "[E] %s" % s.line()


func _unhandled_input(event: InputEvent) -> void:
	if vehicle == null or (contracts and contracts.garage_open):
		return
	if event.is_action_pressed("build"):
		_press_p()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and mode == Mode.NONE and (not yard.is_empty() or here() != null):
		interact()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_ESCAPE and (mode != Mode.NONE or not yard.is_empty()):
			mode = Mode.NONE
			yard = []
			get_viewport().set_input_as_handled()
			return
		if k >= KEY_1 and k <= KEY_9:
			if mode == Mode.PICK and k - KEY_1 < BuildingSpec.all().size():
				picked = BuildingSpec.all()[k - KEY_1]
				mode = Mode.PLACE
				ghost_yaw = vehicle.global_rotation.y
				var ahead := -vehicle.global_transform.basis.z
				ghost_at = Vector2(vehicle.global_position.x, vehicle.global_position.z) + Vector2(ahead.x, ahead.z).normalized() * (picked.size.y * 0.5 + 6.0)
				get_viewport().set_input_as_handled()
			elif not yard.is_empty() and k - KEY_1 < yard.size():
				load_item(k - KEY_1)
				get_viewport().set_input_as_handled()
			return
	if mode == Mode.PLACE and event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				ghost_yaw += TURN
			MOUSE_BUTTON_WHEEL_DOWN:
				ghost_yaw -= TURN
			MOUSE_BUTTON_LEFT:
				if place(picked.id, ghost_at, ghost_yaw):
					mode = Mode.NONE
			_:
				return
		get_viewport().set_input_as_handled()


## P: beside a site with nothing brought, takes it down; else opens the list of what can be
## built, or shuts it.
func _press_p() -> void:
	if mode != Mode.NONE:
		mode = Mode.NONE
		return
	if absf(vehicle.forward_speed) >= SLOW:
		message.emit("Stop to build")
		return
	yard = []
	var s := here()
	if s and not s.built and take_down(s):
		return
	mode = Mode.PICK


# --- Saving ------------------------------------------------------------------------------------

## The buildings and sites, the railhead's and the village's state and the stats, into the
## profile, and saved (Saver adds the rest of the game to it).
func _save() -> void:
	write()
	changed.emit()
	profile.save()


## The buildings and sites, the railhead's and the village's state and the stats, into the
## profile, not yet written out.
func write() -> void:
	var vid := land.home.valley.id
	var out: Array = profile.sites.filter(func(d: Dictionary) -> bool: return d.get("valley", "") != vid)
	out.append({"kind": "railhead", "valley": vid, "stock": railhead.stock.duplicate()})
	for s in sites:
		var d := s.to_dict()
		d["valley"] = vid
		if s.key != "":
			d["key"] = s.key
		out.append(d)
	profile.sites = out
	profile.stats = stats.duplicate()


func _load_saved() -> void:
	var vid := land.home.valley.id
	for d: Dictionary in profile.sites:
		if d.get("valley", "") != vid:
			continue
		match str(d.get("kind", "")):
			"railhead":
				railhead.stock = Site._amounts(d.get("stock", {}))
			"bridge":
				for s in sites:
					if s.key == str(d.get("key", "")) and s.key != "":
						s.built = bool(d.get("built", false))
						s.delivered = Site._amounts(d.get("delivered", {}))
						s._refresh()
			"village":
				if village:
					village.built = bool(d.get("built", false))
					village.delivered = Site._amounts(d.get("delivered", {}))
			_:
				var s := Site.from_dict(d)
				if s:
					_add(s)
	for s in sites:
		if s.spec.trees > 0:
			s.trees_left = trees_near(s.at)
		if s.spec.deposit and pit_depth(s) >= PIT_DEEPEST - 0.05:
			s.halt = "Dug out: %d m deep" % roundi(PIT_DEEPEST)


## After the ground was laid back (Saver): the trees felled, the trees left, the pits dug out.
func refresh() -> void:
	_sync_felled()
	for s in sites:
		if s.spec.trees > 0:
			s.trees_left = trees_near(s.at)
		if s.spec.deposit and pit_depth(s) >= PIT_DEEPEST - 0.05:
			s.halt = "Dug out: %d m deep" % roundi(PIT_DEEPEST)
