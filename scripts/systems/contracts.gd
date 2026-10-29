class_name Contracts
extends Node3D
## The jobs. A board at the depot offers three: where to, what kind, what they pay. Taken, the
## cargo goes on and the tank is filled; delivered, it pays the place's reward times the valley's
## pay, by its kind:
##   plain    as it is
##   timed    against the clock from the depot: gold, silver and bronze for an average along the
##            road of 30, 22 and 15 km/h, paying 1.5, 1.25 and 1 times, 0.6 without a medal; the
##            best time of each job is kept
##   fragile  1.3 times what is left of it: every hard knock or landing breaks some, and at
##            nothing left it is gone
##   heavy    1800 kg instead of 900: the truck sits low, drags deeper and drinks more; 1.6 times
##   stuck    no cargo: a car in a ditch by a road, to winch back onto it; STUCK_REWARD

signal message(text: String)

const INTERACT_RADIUS := 12.0
const RECOVER_COST := 100
const KINDS := ["plain", "timed", "fragile", "heavy"]
const PAY := {"plain": 1.0, "timed": 1.0, "fragile": 1.3, "heavy": 1.6, "stuck": 1.0}
const STUCK_REWARD := 300
const MEDALS := ["gold", "silver", "bronze"]
const MEDAL_KMH := [30.0, 22.0, 15.0]
const MEDAL_PAY := [1.5, 1.25, 1.0]
const NO_MEDAL_PAY := 0.6
## A fragile load starts to break at a jolt this hard, m/s2 over 50 ms (driving the roads stays
## under 33; a drop of 1 m lands at 36, 2 m at 49, 3 m at 101, 4 m at 143), losing this much of
## itself per m/s2 above it.
const KNOCK := 38.0
const KNOCK_DAMAGE := 0.006
const JOLT_TICKS := 3
const OFFROAD := 1.3  # an off-road place is this much further than the straight line

var vehicle: Vehicle
var terrain: Terrain
var profile := Profile.new()  # the player's, saved; one kept in memory when there is none
var money: int:
	get:
		return profile.money
	set(value):
		profile.money = value
		profile.save()
var prompt := ""
var spawn_pos := Vector3.ZERO
var spawn_yaw := 0.0

var offers: Array[Dictionary] = []
var job := {}  # the job in hand, an offer taken; empty: none
var board_open := false
var clock := 0.0  # seconds since a timed job was loaded
var integrity := 1.0  # what is left of a fragile load
var rng := RandomNumberGenerator.new()

var _depot: Dictionary
var _places := {}  # key -> location, the places a job goes to
var _routes := {}  # key -> metres by road from the depot
var _arrow: Node3D
var _markers := {}  # key (or "depot") -> marker pole
var _velocities: Array[Vector3] = []  # the last JOLT_TICKS
var _teleports := 0
var _jolt_wait := 0.0
var _car: StuckCar  # the stuck job's car, while there is one
var _pulled := false  # the winch has had hold of it


func setup(v: Vehicle, t: Terrain, locations: Dictionary) -> void:
	vehicle = v
	terrain = t
	_depot = locations.depot
	_markers["depot"] = _make_marker(_depot, Color(1.0, 0.8, 0.2))
	for key in locations:
		var loc: Dictionary = locations[key]
		if loc.has("cargo"):
			_places[key] = loc
			_routes[key] = _route_length(_depot.pos, loc)
			_markers[key] = _make_marker(loc, Color(0.3, 1.0, 0.4))

	_arrow = Node3D.new()
	add_child(_arrow)
	var prism := PrismMesh.new()
	prism.size = Vector3(0.7, 1.1, 0.25)
	var arrow_mesh := Psx.mesh(_arrow, prism, Vector3.ZERO, Color(1.0, 0.85, 0.2), 1.5)
	arrow_mesh.rotation.x = -PI * 0.5
	roll_offers()
	_update_markers()


## Three new jobs on the board, each of its own kind (a stuck car among them where the valley
## has ditches), each place once.
func roll_offers() -> void:
	var keys: Array = _places.keys()
	var kinds: Array = KINDS.duplicate()
	if not terrain.valley.ditches.is_empty():
		kinds.append("stuck")
	_shuffle(keys)
	_shuffle(kinds)
	offers.clear()
	for i in mini(3, keys.size()):
		if kinds[i] == "stuck":
			offers.append(offer_stuck(rng.randi() % terrain.valley.ditches.size()))
		else:
			offers.append(offer(keys[i], kinds[i]))


## A car stuck in the valley's ditch i, to winch out.
func offer_stuck(i: int) -> Dictionary:
	var d: Dictionary = terrain.valley.ditches[i]
	var near := ""
	var best := INF
	for key in _places:
		var dist: float = (_places[key].pos as Vector2).distance_to(d.pos)
		if dist < best:
			best = dist
			near = _places[key].name
	var loc := {"name": "the ditch near %s" % near, "pos": d.pos, "radius": 10.0}
	return {"key": "ditch%d" % i, "kind": "stuck", "loc": loc, "name": loc.name, "cargo": "pull a car out",
		"route": _depot.pos.distance_to(d.pos) * OFFROAD, "reward": _round(STUCK_REWARD * terrain.valley.pay),
		"record": "", "ditch": d}


## A job to place key, of kind.
func offer(key: String, kind: String) -> Dictionary:
	var loc: Dictionary = _places[key]
	var route: float = _routes[key]
	var o := {"key": key, "kind": kind, "loc": loc, "name": loc.name, "cargo": loc.cargo, "route": route,
		"reward": _round(float(loc.reward) * terrain.valley.pay * PAY[kind]),
		"record": "%s:%s:%s" % [terrain.valley.id, key, kind]}
	if kind == "timed":
		var medals := PackedFloat32Array()
		for kmh in MEDAL_KMH:
			medals.append(ceilf(route / (kmh / 3.6)))
		o.medals = medals
	return o


## Takes job o: on with the cargo, a full tank, the clock from zero. A job in hand is dropped.
func take(o: Dictionary) -> void:
	if not job.is_empty():
		message.emit("Dropped: %s for %s" % [job.cargo, job.name])
		_end_job()
	job = o
	board_open = false
	clock = 0.0
	integrity = 1.0
	vehicle.fuel = Vehicle.FUEL_CAPACITY
	_velocities.clear()
	if o.kind == "stuck":
		_spawn_car(o.ditch)
		message.emit("A car slid into %s. Winch it back onto the road" % o.name)
		_update_markers()
		return
	vehicle.set_cargo(true, o.kind)
	var text := "Loaded: %s. Head for %s" % [o.cargo, o.name]
	match o.kind:
		"timed":
			text += ". The clock is running: gold in %s" % clock_text(o.medals[0])
		"fragile":
			text += ". Fragile: go gently"
		"heavy":
			text += ". Heavy: low range on the hills"
	message.emit(text)
	_update_markers()


func current_target() -> Dictionary:
	return job.loc if not job.is_empty() else _depot


func objective_text() -> String:
	if job.is_empty():
		if _near(_depot):
			return "AT THE DEPOT: pick a job on the board"
		return "BACK TO THE DEPOT for a job  %d m" % _distance_to(_depot)
	var where := "%s -> %s  %d m" % [job.cargo, job.name, _distance_to(job.loc)]
	match job.kind:
		"timed":
			var m := _medal(clock)
			var next := (" (%s %s)" % [MEDALS[m], clock_text(job.medals[m])]) if m < MEDALS.size() else " (no medal)"
			return "TIMED %s: %s%s" % [clock_text(clock), where, next]
		"fragile":
			return "FRAGILE %d%%: %s  +$%d" % [roundi(integrity * 100.0), where, _round(job.reward * integrity)]
		"heavy":
			return "HEAVY: %s  +$%d" % [where, job.reward]
		"stuck":
			return "STUCK CAR in %s: winch it onto the road  %d m  +$%d" % [job.name, _distance_to(job.loc), job.reward]
	return "DELIVER: %s  +$%d" % [where, job.reward]


## The board as the HUD shows it (the prompt under it says which keys take a job).
func board_text() -> String:
	var title := "JOB BOARD - %s" % _depot.name.to_upper()
	if not job.is_empty():
		title += "   (a new job drops %s)" % job.cargo
	var lines := PackedStringArray([title, ""])
	for i in offers.size():
		var o := offers[i]
		var extra := ""
		if o.kind == "timed":
			extra = "  gold %s" % clock_text(o.medals[0])
			var best := profile.record(o.record)
			if not best.is_empty():
				extra += "  best %s" % clock_text(best.time)
		lines.append("%d  %-8s %s -> %s  %d m  $%d%s" % [i + 1, o.kind.to_upper(), o.cargo, o.name, o.route, o.reward, extra])
	return "\n".join(lines)


## What the dashboard says of the load.
func cargo_text() -> String:
	if job.is_empty():
		return ""
	match job.kind:
		"fragile":
			return "FRAGILE %d%%" % roundi(integrity * 100.0)
		"heavy":
			return "HEAVY"
		"timed":
			return "CARGO %s" % clock_text(clock)
		"stuck":
			return ""
	return "CARGO"


static func clock_text(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


func _process(_delta: float) -> void:
	if vehicle == null:
		return
	var tpos := _loc_pos(current_target())
	_arrow.global_position = vehicle.global_position + Vector3(0.0, 3.2, 0.0)
	var look := Vector3(tpos.x, _arrow.global_position.y, tpos.z)
	_arrow.visible = _arrow.global_position.distance_to(look) > INTERACT_RADIUS
	if _arrow.visible:
		_arrow.look_at(look, Vector3.UP)

	prompt = ""
	var slow := absf(vehicle.forward_speed) < 2.0
	if board_open and not (_near(_depot) and slow):
		board_open = false
	if board_open:
		prompt = "[1] [2] [3] take a job   [E] close"
	elif not job.is_empty() and job.kind != "stuck" and _near(job.loc):
		prompt = "[E] Unload" if slow else "Stop to unload"
	elif _near(_depot):
		if not slow:
			prompt = "Stop at the depot"
		elif not job.is_empty() and vehicle.fuel < Vehicle.FUEL_CAPACITY - 0.5:
			prompt = "[E] Refuel, job board"
		else:
			prompt = "[E] Job board"
	elif vehicle.fuel <= 0.0:
		prompt = "Out of fuel! [T] Tow to depot (-$%d)" % RECOVER_COST
	# Otherwise, near the stuck car, the winch says what to do.


func _physics_process(delta: float) -> void:
	if vehicle == null or job.is_empty():
		return
	clock += delta
	if job.kind == "stuck" and _car:
		# Paid once the winch has pulled it out, not for a car that rolled out by itself.
		_pulled = _pulled or vehicle.winch.anchor_body == _car
		if _pulled and _car.on_road(terrain):
			var paid: int = job.reward
			money += paid
			if _car.upright():
				message.emit("Back on the road! The driver waves. +$%d" % paid)
			else:
				message.emit("On the road, wheels up. The tow can take it from here. +$%d" % paid)
			_drop()
			return
	if job.kind == "fragile":
		# A jolt: how sharply the truck's velocity changed over 50 ms, landings and knocks alike
		# (one tick alone has spikes in it that no load would feel).
		if vehicle.teleports != _teleports:  # towed or set upright: moved, not knocked
			_teleports = vehicle.teleports
			_velocities.clear()
		_velocities.append(vehicle.linear_velocity)
		if _velocities.size() <= JOLT_TICKS:
			return
		var then: Vector3 = _velocities.pop_front()
		var jolt := (vehicle.linear_velocity - then).length() / (delta * JOLT_TICKS)
		_jolt_wait -= delta
		if jolt > KNOCK and _jolt_wait <= 0.0:
			_jolt_wait = 0.3
			integrity = maxf(integrity - (jolt - KNOCK) * KNOCK_DAMAGE, 0.0)
			if integrity <= 0.0:
				message.emit("The %s broke. Back to the depot for another job" % job.cargo)
				_drop()
			else:
				message.emit("Careful! %s %d%%" % [job.cargo.capitalize(), roundi(integrity * 100.0)])


func _unhandled_input(event: InputEvent) -> void:
	if board_open and event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k < KEY_1 + offers.size():
			take(offers[k - KEY_1])
			get_viewport().set_input_as_handled()
			return
		if k == KEY_ESCAPE:
			board_open = false
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("recover"):
		recover()


func recover() -> void:
	money -= RECOVER_COST
	vehicle.fuel = maxf(vehicle.fuel, Vehicle.FUEL_CAPACITY * 0.5)
	vehicle.teleport(spawn_pos, spawn_yaw)
	message.emit("The tow truck dragged you back to the depot. -$%d" % RECOVER_COST)


func _interact() -> void:
	if absf(vehicle.forward_speed) >= 2.0:
		return
	if not job.is_empty() and job.kind != "stuck" and _near(job.loc):
		_deliver()
	elif _near(_depot):
		if not job.is_empty() and vehicle.fuel < Vehicle.FUEL_CAPACITY - 0.5:
			vehicle.fuel = Vehicle.FUEL_CAPACITY
			message.emit("Tank is full")
		board_open = not board_open


func _deliver() -> void:
	var pay := float(job.reward)
	var text := "Delivered to %s!" % job.name
	match job.kind:
		"timed":
			var m := _medal(clock)
			pay *= MEDAL_PAY[m] if m < MEDALS.size() else NO_MEDAL_PAY
			text += " %s in %s." % [MEDALS[m].capitalize() if m < MEDALS.size() else "No medal", clock_text(clock)]
			var best := profile.record(job.record)
			if best.is_empty() or clock < float(best.time):
				profile.records[job.record] = {"time": clock, "medal": m}
				profile.save()
				text += " A record!" if not best.is_empty() else ""
		"fragile":
			pay *= integrity
			text += " %d%% of it whole." % roundi(integrity * 100.0)
	var paid := _round(pay)
	money += paid
	message.emit("%s +$%d" % [text, paid])
	_drop()


## The job is over, delivered or broken: off with the cargo, new jobs on the board.
func _drop() -> void:
	_end_job()
	roll_offers()
	_update_markers()


## Off with the cargo; a stuck car lets go of the winch and drives off a moment later.
func _end_job() -> void:
	job = {}
	vehicle.set_cargo(false)
	if _car:
		vehicle.winch.forget(_car)
		_car.drive_off(3.0)
		_car = null


## The best medal a time still earns: 0 gold, 1 silver, 2 bronze, 3 none.
func _medal(seconds: float) -> int:
	for i in MEDALS.size():
		if seconds <= job.medals[i]:
			return i
	return MEDALS.size()


func _update_markers() -> void:
	_markers.depot.visible = job.is_empty()
	for key in _places:
		_markers[key].visible = not job.is_empty() and job.key == key


## The stuck job's car, in ditch d.
func _spawn_car(d: Dictionary) -> void:
	_car = StuckCar.new(rng.randi())
	add_child(_car)
	_car.slide_into(d, terrain)
	_pulled = false
	vehicle.winch.bodies.append(_car)


## Metres by road from a to the place loc: the shortest way along the roads (they join where an
## end meets another road's point), or the straight line and some for a place off the roads.
func _route_length(a: Vector2, loc: Dictionary) -> float:
	var pts := PackedVector2Array()
	var edges := {}  # point index -> [[index, metres], ...]
	for road in terrain.roads:
		var prev := -1
		for p in road:
			var i := -1
			for j in pts.size():
				if pts[j].distance_to(p) < 1.0:
					i = j
					break
			if i < 0:
				i = pts.size()
				pts.append(p)
				edges[i] = []
			if prev >= 0:
				var d := pts[prev].distance_to(pts[i])
				edges[prev].append([i, d])
				edges[i].append([prev, d])
			prev = i
	var start := -1
	var goal := -1
	for j in pts.size():
		if pts[j].distance_to(a) < 1.0:
			start = j
		if pts[j].distance_to(loc.pos) < 1.0:
			goal = j
	if start < 0 or goal < 0:
		return a.distance_to(loc.pos) * OFFROAD
	var dist := {start: 0.0}
	var open := [start]
	while not open.is_empty():
		var best := 0
		for k in open.size():
			if dist[open[k]] < dist[open[best]]:
				best = k
		var i: int = open.pop_at(best)
		if i == goal:
			return dist[i]
		for e in edges[i]:
			var nd: float = dist[i] + e[1]
			if not dist.has(e[0]) or nd < dist[e[0]]:
				dist[e[0]] = nd
				open.append(e[0])
	return a.distance_to(loc.pos) * OFFROAD


func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


static func _round(x: float) -> int:
	return roundi(x / 10.0) * 10


func _near(loc: Dictionary) -> bool:
	return _distance_to(loc) < INTERACT_RADIUS


func _distance_to(loc: Dictionary) -> float:
	var p: Vector2 = loc.pos
	return Vector2(vehicle.global_position.x, vehicle.global_position.z).distance_to(p)


func _loc_pos(loc: Dictionary) -> Vector3:
	var p: Vector2 = loc.pos
	return Vector3(p.x, terrain.get_height(p.x, p.y), p.y)


func _make_marker(loc: Dictionary, color: Color) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = _loc_pos(loc)
	Psx.box(root, Vector3(0.25, 9.0, 0.25), Vector3(0.0, 4.5, 0.0), color, 1.2)
	Psx.box(root, Vector3(1.0, 1.0, 1.0), Vector3(0.0, 9.5, 0.0), color, 2.5)
	return root
