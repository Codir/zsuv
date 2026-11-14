class_name Infra
extends Node3D
## The infrastructure the player builds (docs/plan.md §5, §6): P places a building where the
## mouse points, green where it can go and red with the reason where it cannot; placed, it is a site
## until E has brought every load it needs; built, it holds fuel and loads, and makes what it makes
## on its timer wherever the player is. The railhead is the first base: fuel and parts without
## end, a concrete plant with gravel in it, and timber in its yard. Loads come on and off the truck
## with E, through Loads.

signal message(text: String)

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

var vehicle: Vehicle
var terrain: Terrain
var profile := Profile.new()
var camera: Camera3D
var contracts: Contracts  # its garage closes the lists here, and the lists it
var locations := {}  # the valley's places: nothing is built on their flats
var trees := PackedVector2Array()  # the valley's trees
var felled := {}  # tree index -> true: gone to a sawmill
var deposits: Array[Dictionary] = []  # {pos, radius}: gravel a quarry can go on
var sites: Array[Site] = []  # the player's, sites and buildings
var railhead: Site
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


func setup(v: Vehicle, t: Terrain, p: Profile, cam: Camera3D, locs: Dictionary, tree_points: PackedVector2Array) -> void:
	vehicle = v
	terrain = t
	profile = p if p else Profile.new()
	camera = cam
	locations = locs
	trees = tree_points
	if not InputMap.has_action("build"):
		InputMap.add_action("build")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_P
		InputMap.action_add_event("build", ev)
	for loc in locs.values():
		if loc.get("kind", "") == "gravel":
			deposits.append({"pos": loc.pos, "radius": float(loc.get("radius", 10.0))})
	railhead = Site.new()
	railhead.spec = BuildingSpec.railhead()
	railhead.at = locs.depot.pos
	railhead.built = true
	railhead.endless = PackedStringArray(["fuel", "parts"])
	railhead.stock = RAILHEAD_STOCK.duplicate()
	railhead.name = "Railhead"
	add_child(railhead)
	_load_saved()
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
	if s == null or s.id == "railhead":
		return "Nothing to build"
	var corners := Site.footprint(s, at, yaw)
	for c in corners:
		if maxf(absf(c.x), absf(c.y)) > Terrain.HALF - APART:
			return "Off the map"
	var low := INF
	var high := -INF
	var n := Vector2i(ceili(s.size.x / 2.0), ceili(s.size.y / 2.0))
	for i in n.x + 1:
		for j in n.y + 1:
			var local := Vector2(lerpf(-s.size.x * 0.5, s.size.x * 0.5, float(i) / n.x), lerpf(-s.size.y * 0.5, s.size.y * 0.5, float(j) / n.y))
			var p := at + local.rotated(-yaw)
			var h := terrain.get_height(p.x, p.y)
			if (i == 0 or i == n.x) and (j == 0 or j == n.y):  # level: between its corners
				low = minf(low, h)
				high = maxf(high, h)
			if terrain.road_distance(p) < Terrain.ROAD_HALF_WIDTH + 0.5:
				return "On a road: build beside it"
			if _water(p, h):
				return "In water"
			if terrain.sample(Vector3(p.x, h, p.y)).ice > 0.5:
				return "On ice"
	var grown := Site.footprint(s, at, yaw, APART)
	for key in locations:
		var loc: Dictionary = locations[key]
		if _distance_to(corners, loc.pos) < float(loc.radius) + APART:
			return "Too near the %s" % loc.name
	for other in sites:
		if not Geometry2D.intersect_polygons(grown, other.corners()).is_empty():
			return "Too near the %s" % (other.spec.title.to_lower() + ("" if other.built else " site"))
	if high - low > LEVEL:
		return "Not level: %.1f m. Level it with the bucket" % (high - low)
	if s.trees > 0:
		var count := trees_near(at)
		if count < s.trees:
			return "Only %d trees here: a %s needs %d within %d m" % [count, s.title.to_lower(), s.trees, BuildingSpec.TREE_REACH]
	if s.deposit and not deposits.any(func(d: Dictionary) -> bool: return at.distance_to(d.pos) < float(d.radius)):
		return "No gravel here: a quarry goes on a gravel deposit"
	return ""


## Places a site of kind at at, turned yaw, as a left click does: the site, or null (with the
## reason said) where it cannot go.
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
	message.emit("Staked out: a %s. It needs %s" % [site.spec.title.to_lower(), _needs_text(site)])
	_save()
	return site


## Takes a site with nothing brought to it down: true when it did.
func take_down(site: Site) -> bool:
	if site.built or not site.delivered.is_empty():
		return false
	sites.erase(site)
	site.queue_free()
	message.emit("Taken down: the %s site" % site.spec.title.to_lower())
	_save()
	return true


## Trees standing within the sawmill's reach of at.
func trees_near(at: Vector2) -> int:
	var count := 0
	for i in trees.size():
		if not felled.has(i) and trees[i].distance_to(at) <= BuildingSpec.TREE_REACH:
			count += 1
	return count


func _water(p: Vector2, h: float) -> bool:
	if not terrain.has_method("water_level"):
		return false
	var w: Variant = terrain.call("water_level", p)
	return typeof(w) == TYPE_FLOAT and not is_nan(w) and w > h + 0.05


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
	site.ground = func(x: float, z: float) -> float: return terrain.get_height(x, z)
	site.made.connect(_on_made)
	sites.append(site)
	add_child(site)
	if site.spec.trees > 0:
		site.trees_left = trees_near(site.at)


# --- Using: E ----------------------------------------------------------------------------------

## The building or site the truck is at ("" none): the railhead first.
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
		message.emit("Loaded: %s" % Loads.unit(res, got))
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
		if not Loads.carries_any(vehicle):
			message.emit("The %s carries nothing. The %s needs %s" % [vehicle.spec.title.to_lower(), s.spec.title.to_lower(), _needs_text(s)])
		else:
			message.emit("The %s needs %s" % [s.spec.title.to_lower(), _needs_text(s)])
		return
	if s.built:
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


func _on_made(s: Site, res: String) -> void:
	if s.spec.trees > 0:
		_fell(s)
	_save()


## A sawmill fells the standing tree nearest it.
func _fell(s: Site) -> void:
	var best := -1
	for i in trees.size():
		if not felled.has(i) and trees[i].distance_to(s.at) <= BuildingSpec.TREE_REACH \
				and (best < 0 or trees[i].distance_to(s.at) < trees[best].distance_to(s.at)):
			best = i
	if best >= 0:
		felled[best] = true
	for other in sites:
		if other.spec.trees > 0:
			other.trees_left = trees_near(other.at)


func _physics_process(delta: float) -> void:
	advance(delta)
	_save_timer += delta
	if _save_timer >= SAVE_EVERY:
		_save_timer = 0.0
		if sites.any(func(s: Site) -> bool: return s.on_timer()):
			_save()


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
		var hit: Variant = Cursor.ground(r[0], r[1], func(x: float, z: float) -> float: return terrain.get_height(x, z))
		if hit != null:
			var truck := Vector2(vehicle.global_position.x, vehicle.global_position.z)
			var p := Vector2(hit.x, hit.z)
			ghost_at = truck + (p - truck).limit_length(REACH)
	ghost_why = check(picked.id, ghost_at, ghost_yaw)
	(_ghost.mesh as BoxMesh).size = Vector3(picked.size.x, 0.6, picked.size.y)
	_ghost.global_position = Vector3(ghost_at.x, terrain.get_height(ghost_at.x, ghost_at.y) + 0.3, ghost_at.y)
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
		return "Stop at the %s" % (s.spec.title.to_lower() + ("" if s.built else " site"))
	if not s.built:
		var text := "[E] Bring: %s" % _needs_text(s)
		if s.delivered.is_empty():
			text += "   [P] take it down"
		return text
	if s == railhead:
		return "[E] Fuel and loads   [P] Build"
	return "[E] %s" % s.line()


func _unhandled_input(event: InputEvent) -> void:
	if vehicle == null or (contracts and contracts.garage_open):
		return
	if event.is_action_pressed("build"):
		_press_p()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and mode == Mode.NONE:
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

## This valley's buildings and sites, and the railhead's stock, into the profile beside the other
## valleys', and saved.
func _save() -> void:
	var vid := terrain.valley.id
	var out: Array = profile.sites.filter(func(d: Dictionary) -> bool: return d.get("valley", "") != vid)
	var rail := {"kind": "railhead", "valley": vid, "stock": railhead.stock.duplicate()}
	out.append(rail)
	for s in sites:
		var d := s.to_dict()
		d["valley"] = vid
		out.append(d)
	var gone := PackedInt32Array(felled.keys())
	out.append({"kind": "felled", "valley": vid, "trees": gone})
	profile.sites = out
	profile.save()


func _load_saved() -> void:
	var vid := terrain.valley.id
	for d: Dictionary in profile.sites:
		if d.get("valley", "") != vid:
			continue
		match str(d.get("kind", "")):
			"railhead":
				railhead.stock = Site._amounts(d.get("stock", {}))
			"felled":
				var gone: Variant = d.get("trees", [])
				if typeof(gone) in [TYPE_ARRAY, TYPE_PACKED_INT32_ARRAY]:
					for i in gone:
						if typeof(i) == TYPE_INT and i >= 0 and i < trees.size():
							felled[i] = true
			_:
				var s := Site.from_dict(d)
				if s:
					_add(s)
	for s in sites:
		if s.spec.trees > 0:
			s.trees_left = trees_near(s.at)


func _exit_tree() -> void:
	if terrain:
		_save()
