class_name Fog
extends RefCounted
## What the player has seen of the map (docs/plan.md §3, "Fog"): a mask per biome, TEXEL m a texel,
## that the truck being driven uncovers around it as it goes, and the things on the map, each
## found once its middle is uncovered. Nothing unfound is shown anywhere.

const TEXEL := 4.0
const RES := 64  # texels a side of a biome
const SCOUT := 90.0  # m the scout uncovers around it
const SCOUT_HIGH := 150.0  # on a hilltop: standing HIGH m or more above the ground within HIGH_REACH
const HIGH := 15.0
const HIGH_REACH := 60.0
const TRUCK := 40.0  # any other truck
const BUILDING := 60.0
const MAST := 250.0

signal found(thing: Dictionary)  # {id, name, kind, pos (world), biome}
signal changed  # some of the mask was uncovered

var land: Land
var masks := {}  # valley id -> PackedByteArray (RES x RES): 0 under fog, 255 seen
var things: Array[Dictionary] = []  # what can be found: {id, name, kind, pos, biome, found}


func _init(l: Land) -> void:
	land = l
	for t in land.tiles:
		var m := PackedByteArray()
		m.resize(RES * RES)
		masks[t.valley.id] = m
		things.append({"id": "biome:" + t.valley.id, "name": t.valley.biome, "kind": "biome", "pos": t.origin, "biome": t.valley.id, "found": false})
		for key in t.valley.locations:
			var loc: Dictionary = t.valley.locations[key]
			things.append({"id": "%s:%s" % [t.valley.id, key], "name": "the " + String(loc.name).to_lower() if not String(loc.name).begins_with("the ") else loc.name,
				"kind": "place", "pos": (loc.pos as Vector2) + t.origin, "biome": t.valley.id, "found": false, "key": key})
		for i in t.valley.features.size():
			var ft: Dictionary = t.valley.features[i]
			if ft.type in ["washout", "slide"]:
				things.append({"id": "%s:%s%d" % [t.valley.id, ft.type, i], "name": "a washed-out road" if ft.type == "washout" else "a landslide over the road",
					"kind": ft.type, "pos": (t.along(int(ft.road), float(ft.s))[0] as Vector2) + t.origin, "biome": t.valley.id, "found": false})
		for i in t.valley.gaps.size():
			var g: Dictionary = t.valley.gaps[i]
			var mid: Vector2 = t.along(int(g.road), (float(g.from) + minf(float(g.to), _length(t, int(g.road)))) * 0.5)[0]
			things.append({"id": "%s:crossing%d" % [t.valley.id, i], "name": "a crossing, its bridge gone", "kind": "crossing",
				"pos": mid + t.origin, "biome": t.valley.id, "found": false})


static func _length(t: Terrain, r: int) -> float:
	var total := 0.0
	for i in t.roads[r].size() - 1:
		total += t.roads[r][i].distance_to(t.roads[r][i + 1])
	return total


## Uncovers the map within radius m of p (world); the things whose middle it uncovers are found.
func reveal(p: Vector2, radius: float) -> void:
	var any := false
	var r2 := radius * radius
	for t in land.tiles:
		var l := p - t.origin
		if absf(l.x) > Terrain.HALF + radius or absf(l.y) > Terrain.HALF + radius:
			continue
		var m: PackedByteArray = masks[t.valley.id]
		var lo := Vector2i(clampi(floori((l.x - radius + Terrain.HALF) / TEXEL), 0, RES - 1), clampi(floori((l.y - radius + Terrain.HALF) / TEXEL), 0, RES - 1))
		var hi := Vector2i(clampi(floori((l.x + radius + Terrain.HALF) / TEXEL), 0, RES - 1), clampi(floori((l.y + radius + Terrain.HALF) / TEXEL), 0, RES - 1))
		for z in range(lo.y, hi.y + 1):
			for x in range(lo.x, hi.x + 1):
				var c := Vector2((x + 0.5) * TEXEL - Terrain.HALF, (z + 0.5) * TEXEL - Terrain.HALF)
				if m[z * RES + x] == 0 and c.distance_squared_to(l) <= r2:
					m[z * RES + x] = 255
					any = true
		masks[t.valley.id] = m
	if any:
		changed.emit()
		for th in things:
			if not th.found and (th.kind == "biome" or seen(th.pos)):
				if th.kind == "biome" and land.valley_at(p).id != th.biome:
					continue
				th.found = true
				found.emit(th)


## Whether p (world) is uncovered.
func seen(p: Vector2) -> bool:
	var t := land.tile_at(p.x, p.y)
	var l := p - t.origin
	if absf(l.x) > Terrain.HALF or absf(l.y) > Terrain.HALF:
		return false
	var x := clampi(floori((l.x + Terrain.HALF) / TEXEL), 0, RES - 1)
	var z := clampi(floori((l.y + Terrain.HALF) / TEXEL), 0, RES - 1)
	return (masks[t.valley.id] as PackedByteArray)[z * RES + x] > 0


## How far the truck v uncovers around it: the scout more, and more again on a hilltop.
func radius_of(v: Vehicle) -> float:
	if v.spec.id != "scout":
		return TRUCK
	var p := v.global_position
	var low := INF
	for k in 12:
		var q := Vector2(p.x, p.z) + Vector2.from_angle(k * TAU / 12.0) * HIGH_REACH
		low = minf(low, land.get_height(q.x, q.y))
	return SCOUT_HIGH if p.y - low >= HIGH else SCOUT


## The share of biome id uncovered, 0..1.
func share(id: String) -> float:
	var n := 0
	for b in masks[id]:
		n += 1 if b > 0 else 0
	return float(n) / (RES * RES)


func is_found(id: String) -> bool:
	for th in things:
		if th.id == id:
			return th.found
	return false


## What the profile keeps: each mask compressed, and the ids of the things found.
func to_save() -> Dictionary:
	var out := {"masks": {}, "found": PackedStringArray()}
	for id in masks:
		out.masks[id] = (masks[id] as PackedByteArray).compress(FileAccess.COMPRESSION_DEFLATE)
	for th in things:
		if th.found:
			out.found.append(th.id)
	return out


## Back to what was saved (to_save()); what does not fit is left under fog.
func load_save(d: Dictionary) -> void:
	var saved: Dictionary = d.get("masks", {})
	for id in masks:
		if saved.has(id):
			var m: PackedByteArray = (saved[id] as PackedByteArray).decompress(RES * RES, FileAccess.COMPRESSION_DEFLATE)
			if m.size() == RES * RES:
				masks[id] = m
	var ids: PackedStringArray = d.get("found", PackedStringArray())
	for th in things:
		th.found = th.id in ids
	changed.emit()
