class_name Site
extends Node3D
## One building of the player's (docs/plan.md §5): first a site, stakes and a sign, until every
## load it needs is brought; then the building, which holds fuel and loads and makes what it makes
## on its timer, wherever the player is. Infra places it, feeds it and saves it.

signal made(site: Site, res: String)  # a load came off its line

var spec: BuildingSpec
var at := Vector2.ZERO  # its middle, on the map
var yaw := 0.0
var built := false
var delivered := {}  # resource -> loads brought to the site
var stock := {}  # resource -> loads it holds (what it made, what it takes to make with, its yard)
var fuel := 0.0  # litres in its tank
var timer := 0.0  # seconds into the load it is making
var endless := PackedStringArray()  # what never runs out here (the railhead's fuel and parts)
var trees_left := -1  # a sawmill's trees in reach (Infra counts them); -1 not counted
var status := ""  # what it is doing: "making timber", "Full", "No fuel", "Felled out"
var ground: Callable  # (x, z) -> height: where it stands

var _gfx: Node3D


func _ready() -> void:
	_refresh()


## Its footprint's corners on the map, grown by grow metres all round.
func corners(grow := 0.0) -> PackedVector2Array:
	return footprint(spec, at, yaw, grow)


static func footprint(s: BuildingSpec, p: Vector2, turn: float, grow := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	var h := s.size * 0.5 + Vector2(grow, grow)
	for c in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
		out.append(p + c.rotated(-turn))
	return out


## Whether p is on its footprint grown by grow.
func contains(p: Vector2, grow := 0.0) -> bool:
	var local := (p - at).rotated(yaw)
	var h := spec.size * 0.5 + Vector2(grow, grow)
	return absf(local.x) <= h.x and absf(local.y) <= h.y


## What the site still needs: {resource: loads}.
func needs_left() -> Dictionary:
	var out := {}
	for res in spec.needs:
		var n := float(spec.needs[res]) - float(delivered.get(res, 0.0))
		if n > 0.001:
			out[res] = n
	return out


## How much of res it takes now: a site what it still needs; a building fuel into its tank, what
## it makes with, anything into its yard.
func accepts(res: String) -> float:
	if not built:
		return float(needs_left().get(res, 0.0))
	if res in endless:
		return 0.0
	if res == "fuel":
		return maxf(spec.tank - fuel, 0.0)
	if spec.takes.has(res):
		return maxf(float(spec.takes[res]) - float(stock.get(res, 0.0)), 0.0)
	if spec.yard > 0.0:
		return maxf(spec.yard - yard_used(), 0.0)
	return 0.0


## Loads in its yard, of anything but what it takes to make with.
func yard_used() -> float:
	var n := 0.0
	for res in stock:
		if not spec.takes.has(res):
			n += float(stock[res])
	return n


## Takes up to n of res in: what it took. A site whose needs are all in stands.
func deliver(res: String, n: float) -> float:
	var r := minf(accepts(res), n)
	if r <= 0.0:
		return 0.0
	if not built:
		delivered[res] = float(delivered.get(res, 0.0)) + r
		if needs_left().is_empty():
			built = true
			delivered = {}
			_refresh()
	elif res == "fuel":
		fuel += r
	else:
		stock[res] = float(stock.get(res, 0.0)) + r
	return r


## How much of res can be had here (INF where it never runs out). What it takes to make with is
## not given back.
func available(res: String) -> float:
	if not built:
		return 0.0
	if res in endless:
		return INF
	if res == "fuel":
		return fuel
	if spec.takes.has(res):
		return 0.0
	return float(stock.get(res, 0.0))


## Gives up to n of res: what it gave.
func give(res: String, n: float) -> float:
	var r := minf(available(res), n)
	if r <= 0.0 or res in endless:
		return maxf(r, 0.0)
	if res == "fuel":
		fuel -= r
	else:
		stock[res] = float(stock[res]) - r
		if stock[res] <= 0.001:
			stock.erase(res)
	return r


## Whether it makes a load by itself on a timer (a sawmill, a quarry), not on demand (a plant).
func on_timer() -> bool:
	return built and spec.makes != "" and spec.period > 0.0


## dt seconds of game time: a load made when its timer runs out, if it has room, fuel and (a
## sawmill) trees. The fuel goes when a load is started.
func step(dt: float) -> void:
	if not on_timer():
		return
	while dt > 0.0:
		if float(stock.get(spec.makes, 0.0)) >= spec.holds:
			status = "Full"
			timer = 0.0
			return
		if trees_left == 0:
			status = "Felled out"
			timer = 0.0
			return
		if timer <= 0.0:
			if fuel < spec.burns and not "fuel" in endless:
				status = "No fuel"
				return
			fuel -= spec.burns
			timer = 0.0001
		status = "making %s" % spec.makes
		var used := minf(dt, spec.period - timer)
		timer += used
		dt -= used
		if timer >= spec.period - 0.0001:
			timer = 0.0
			stock[spec.makes] = float(stock.get(spec.makes, 0.0)) + 1.0
			made.emit(self, spec.makes)


## Its line in the ledger, and its sign: "Sawmill: timber 2/3, 140 L, 31 trees left".
func line() -> String:
	if not built:
		var needs := PackedStringArray()
		for res in needs_left():
			needs.append(Loads.unit(res, needs_left()[res]))
		return "%s site: needs %s" % [spec.title, ", ".join(needs)]
	var bits := PackedStringArray()
	if spec.makes != "" and spec.holds > 0.0:
		bits.append("%s %d/%d" % [spec.makes, roundi(float(stock.get(spec.makes, 0.0))), roundi(spec.holds)])
	for res in spec.takes:
		bits.append("%s %d/%d" % [res, roundi(float(stock.get(res, 0.0))), int(spec.takes[res])])
	if spec.yard > 0.0:
		for res in stock:
			if not spec.takes.has(res) and not res in endless:
				bits.append(Loads.unit(res, stock[res]))
	for res in endless:
		bits.append("%s without end" % res)
	if spec.tank > 0.0:
		bits.append("%d L" % roundi(fuel))
	if trees_left >= 0:
		bits.append("%d trees left" % trees_left)
	if status != "":
		bits.append(status)
	return "%s: %s" % [spec.title, ", ".join(bits)]


func to_dict() -> Dictionary:
	return {"kind": spec.id, "x": at.x, "z": at.y, "yaw": yaw, "built": built, "delivered": delivered,
		"stock": stock, "fuel": fuel, "timer": timer}


## A site as saved, or null when d is not one.
static func from_dict(d: Dictionary) -> Site:
	var s := BuildingSpec.find(str(d.get("kind", "")))
	if s == null or s.id == "railhead":
		return null
	var site := Site.new()
	site.spec = s
	site.at = Vector2(float(d.get("x", 0.0)), float(d.get("z", 0.0)))
	site.yaw = float(d.get("yaw", 0.0))
	site.built = bool(d.get("built", false))
	site.delivered = _amounts(d.get("delivered", {}))
	site.stock = _amounts(d.get("stock", {}))
	site.fuel = clampf(float(d.get("fuel", 0.0)), 0.0, s.tank)
	site.timer = clampf(float(d.get("timer", 0.0)), 0.0, s.period)
	return site


static func _amounts(v: Variant) -> Dictionary:
	var out := {}
	if typeof(v) != TYPE_DICTIONARY:
		return out
	for k in v:
		if str(k) in Loads.RESOURCES and typeof(v[k]) in [TYPE_INT, TYPE_FLOAT]:
			out[str(k)] = float(v[k])
	return out


func _height(x: float, z: float) -> float:
	return ground.call(x, z) if ground.is_valid() else 0.0


## The stakes and the sign while a site, the building once it stands.
func _refresh() -> void:
	if spec == null or spec.id == "railhead":
		return
	if _gfx:
		_gfx.queue_free()
	_gfx = Node3D.new()
	add_child(_gfx)
	var base := _height(at.x, at.y)
	position = Vector3(at.x, base, at.y)
	rotation.y = yaw
	var h := spec.size * 0.5
	if not built:
		for c in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
			var w := at + (c as Vector2).rotated(-yaw)
			Psx.box(_gfx, Vector3(0.12, 1.2, 0.12), Vector3(c.x, _height(w.x, w.y) - base + 0.5, c.y), Color(0.95, 0.5, 0.1), 0.6)
		var sign_at := Vector3(-h.x + 1.0, _height(at.x, at.y) - base, -h.y)
		Psx.box(_gfx, Vector3(0.1, 1.6, 0.1), sign_at + Vector3(0.0, 0.8, 0.0), Color(0.4, 0.3, 0.2))
		Psx.box(_gfx, Vector3(1.4, 0.8, 0.06), sign_at + Vector3(0.0, 1.7, 0.0), Color(0.9, 0.88, 0.8))
		_label("SITE: %s" % spec.title.to_upper(), sign_at + Vector3(0.0, 2.6, 0.0))
		return
	# The building: a solid house at the back of its footprint, the yard in front left free to drive.
	var house := Vector3(minf(spec.size.x * 0.5, 8.0), 4.0, minf(spec.size.y * 0.35, 5.0))
	var house_at := Vector3(0.0, 0.0, h.y - house.z * 0.5 - 0.5)
	var body := StaticBody3D.new()
	body.position = house_at
	_gfx.add_child(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = house + Vector3(0.0, 2.0, 0.0)
	cs.shape = shape
	cs.position = Vector3(0.0, house.y * 0.5 - 1.0, 0.0)
	body.add_child(cs)
	Psx.box(body, house + Vector3(0.0, 2.0, 0.0), Vector3(0.0, house.y * 0.5 - 1.0, 0.0), spec.color)
	Psx.box(body, Vector3(house.x + 0.4, 0.3, house.z + 0.4), Vector3(0.0, house.y + 0.15, 0.0), spec.color.darkened(0.4))
	match spec.id:
		"fuel_station":
			for x in [-1.5, 1.5]:
				Psx.box(_gfx, Vector3(0.6, 1.5, 0.4), Vector3(x, 0.75, 0.0), Color(0.9, 0.9, 0.85))
			Psx.box(_gfx, Vector3(6.0, 0.3, 4.0), Vector3(0.0, 4.2, 0.0), Color(0.85, 0.35, 0.15))
			for x in [-2.8, 2.8]:
				Psx.box(_gfx, Vector3(0.2, 4.1, 0.2), Vector3(x, 2.05, 0.0), Color(0.8, 0.8, 0.78))
		"sawmill":
			for i in 3:
				var trunk := Psx.mesh(_gfx, Psx.cylinder(0.3, 0.3, 5.0, 6), Vector3(-3.0 + i * 0.7, 0.3, -2.0), Color(0.5, 0.35, 0.2))
				trunk.rotation.z = PI * 0.5
		"plant":
			Psx.mesh(_gfx, Psx.cylinder(1.4, 1.4, 6.0, 8), Vector3(-3.5, 3.0, house_at.z), Color(0.7, 0.7, 0.68))
			Psx.box(_gfx, Vector3(0.6, 0.3, 3.0), Vector3(0.0, 3.0, house_at.z - house.z * 0.5 - 1.5), Color(0.5, 0.5, 0.48))
	_label(spec.title.to_upper(), Vector3(0.0, house.y + 2.0, house_at.z))


func _label(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = Psx.font()
	label.font_size = 48
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.95, 0.8)
	label.outline_size = 8
	label.position = pos
	_gfx.add_child(label)
