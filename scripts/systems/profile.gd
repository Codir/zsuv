class_name Profile
extends RefCounted
## What a player keeps between drives: the trucks and trailers that are theirs, the truck picked,
## where they were last, and what they built (Infra's sites). Saved to user:// on every change (in a
## browser that is its IndexedDB); a profile with no path is kept in memory only, as the tests and
## the captures use it. There is no money (docs/plan.md §6); §11 is what it becomes.

const PATH := "user://zsuv.cfg"

var path := ""
var last := "steppe"  # the valley the game was in; a new game starts in the steppe
var rigs := PackedStringArray()  # the trucks and trailers that are the player's (TruckSpec, TrailerSpec ids)
var truck := "pickup"  # the truck the garage puts at the railhead
var sites: Array = []  # Site.to_dict() of every building and site, in the valley it was in (Infra)
var stats := {}  # what the end card counts (Infra.stats): buildings, trees_felled, fuel_burnt, played
var earthworks := {}  # Land.save_earthworks(): the ground dug and dumped, with its map_version
var fog := {}  # Fog.to_save(): what has been seen, and found
var scout_track := PackedVector2Array()  # where the scout has been (MapScreen)
var waypoint: Variant = null  # Vector2 set on the paper map, or null
var fleet: Array = []  # every truck out on the map: {id, pos, yaw, fuel, hold, trailer, driven} (Saver)
var trailers: Array = []  # the trailers standing on their own: {id, pos, yaw, hold}
var new_game := false  # not saved: the game was just begun, the railhead's trucks are to be set out


## Whether there is a save at at to continue.
static func exists(at := PATH) -> bool:
	return at != "" and FileAccess.file_exists(at)


static func open(at := PATH) -> Profile:
	var p := Profile.new()
	p.path = at
	var cfg := ConfigFile.new()
	if cfg.load(at) != OK:
		return p
	# A value of the wrong type (a hand edit, another build's file) is left at its default, so a
	# bad file never stops the game.
	p.rigs = _ids(cfg.get_value("progress", "rigs", p.rigs), p.rigs)
	p.truck = _value(cfg, "truck", TYPE_STRING, p.truck)
	if not p.has_rig(p.truck) or TruckSpec.find(p.truck) == null:
		p.truck = "pickup"
	p.last = _value(cfg, "last", TYPE_STRING, p.last)
	if Valley.find(p.last) == null:
		p.last = "steppe"
	p.sites = _dicts(cfg.get_value("build", "sites", []))
	p.fleet = _dicts(cfg.get_value("world", "fleet", []))
	p.trailers = _dicts(cfg.get_value("world", "trailers", []))
	p.stats = _typed(cfg, "world", "stats", TYPE_DICTIONARY, {})
	p.earthworks = _typed(cfg, "world", "earthworks", TYPE_DICTIONARY, {})
	p.fog = _typed(cfg, "world", "fog", TYPE_DICTIONARY, {})
	p.scout_track = _typed(cfg, "world", "scout_track", TYPE_PACKED_VECTOR2_ARRAY, PackedVector2Array())
	var wp: Variant = cfg.get_value("world", "waypoint") if cfg.has_section_key("world", "waypoint") else null
	p.waypoint = wp if typeof(wp) == TYPE_VECTOR2 else null
	return p


## A list of ids as saved, or default when it is not one; no repeats, nothing but strings.
static func _ids(value: Variant, default: PackedStringArray) -> PackedStringArray:
	if typeof(value) not in [TYPE_PACKED_STRING_ARRAY, TYPE_ARRAY]:
		return default
	var out := PackedStringArray()
	for id in value:
		if typeof(id) in [TYPE_STRING, TYPE_STRING_NAME] and not str(id) in out:
			out.append(str(id))
	return out


## The dictionaries in a saved list, or none.
static func _dicts(v: Variant) -> Array:
	if typeof(v) != TYPE_ARRAY:
		return []
	return (v as Array).filter(func(d: Variant) -> bool: return typeof(d) == TYPE_DICTIONARY)


static func _typed(cfg: ConfigFile, section: String, key: String, type: int, default: Variant) -> Variant:
	var value: Variant = cfg.get_value(section, key, default)
	return value if typeof(value) == type else default


static func _value(cfg: ConfigFile, key: String, type: int, default: Variant) -> Variant:
	var value: Variant = cfg.get_value("progress", key, default)
	return value if typeof(value) == type else default


func save() -> void:
	if path == "":
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "last", last)
	cfg.set_value("progress", "rigs", rigs)
	cfg.set_value("progress", "truck", truck)
	cfg.set_value("build", "sites", sites)
	cfg.set_value("world", "fleet", fleet)
	cfg.set_value("world", "trailers", trailers)
	cfg.set_value("world", "stats", stats)
	cfg.set_value("world", "earthworks", earthworks)
	cfg.set_value("world", "fog", fog)
	cfg.set_value("world", "scout_track", scout_track)
	if waypoint != null:
		cfg.set_value("world", "waypoint", waypoint)
	cfg.save(path)


## Whether the truck or trailer id is the player's (the pickup, the scout and the mixer always are).
func has_rig(id: String) -> bool:
	return id in ["pickup", "scout", "mixer"] or id in rigs


## The rigs ids become the player's (a truck found, and the trailer it came with), saved.
func add_rigs(ids: PackedStringArray) -> void:
	for id in ids:
		if not id in rigs:
			rigs.append(id)
	save()
