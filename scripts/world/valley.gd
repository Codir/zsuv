class_name Valley
extends RefCounted
## One valley: its places and roads, the shape of its ground, what lies on it (snow or sand, mud,
## ice), its trees, colours and price. Valley.all() lists the six in the order they open, easiest
## first (docs/valleys.md); every one is 256 m square.

var id := ""
var title := ""
var blurb := ""  # one line for the start screen's card
var price := 0
var stars := 1  # how hard, 1..5
var season := "winter"  # winter | spring | summer | autumn: snow or rain, the trees
var pay := 1.0  # jobs here pay this many times the khutir valley's
var own: Weather  # its own sky; the start screen can switch it (Weather.Kind)

# Ground: noise relief, then features: {type: hill | ridge | lake | gully | ditch | sea, ...}.
var seed := 1337
var relief := 16.0
var detail := 2.5
var features: Array[Dictionary] = []

# Places: key -> {name, pos, radius, kind (what the world builder puts there), cargo, reward}.
var locations := {}
var roads: Array[PackedVector2Array] = []
var spawn := Vector2.ZERO
var spawn_yaw := 0.0

# The soft layer the wheels pack into ruts: snow, or sand.
var layer := "snow"
var layer_base := 0.55
var layer_noise := 0.6
var layer_min := 0.15
var layer_on_road := 0.07  # what is left of it on a road
var layer_from := -INF  # only above this height (snow on the peaks)
var layer_grip := 0.6  # grip in the layer at 40 cm and deeper
var layer_rolling := 0.45  # rolling resistance per metre of it
var mud_from := 0.3  # mud where its noise climbs from this
var puddles: Array[Dictionary] = []  # {pos, radius}: mud pools, bogs
var ice: Array[Dictionary] = []  # {pos, radius}: frozen lakes (a lake feature beneath)

# Looks.
var earth := Color(0.2, 0.15, 0.11)
var gravel := Color(0.36, 0.34, 0.31)
var layer_color := Color(0.86, 0.9, 0.98)
var layer_packed := Color(0.56, 0.6, 0.7)
var mud_color := Color(0.3, 0.22, 0.14)
var mud_packed := Color(0.17, 0.12, 0.08)
var ice_color := Color(0.62, 0.74, 0.82)
var trees := "pine_snow"  # pine_snow | pine | spruce_snow | poplar | broadleaf | none
var tree_count := 500
var rock_count := 60
var poles := true  # orange snow poles along the roads


static func all() -> Array[Valley]:
	return [khutir()]


static func find(valley_id: String) -> Valley:
	for v in all():
		if v.id == valley_id:
			return v
	return null


## The first valley, the game as it was: a winter dusk, snow and mud puddles.
static func khutir() -> Valley:
	var v := Valley.new()
	v.id = "khutir"
	v.title = "The Khutir Valley"
	v.blurb = "Winter dusk. Snow on every road, mud in the hollows."
	v.own = Weather.dusk()
	v.locations = {
		"depot": {"name": "Depot", "pos": Vector2(-95, -95), "radius": 14.0, "kind": "depot"},
		"farm": {"name": "Khutir", "pos": Vector2(-72, 92), "radius": 10.0, "kind": "khutir",
			"cargo": "groceries", "reward": 250},
		"lumber": {"name": "Sawmill", "pos": Vector2(75, 88), "radius": 10.0, "kind": "sawmill",
			"cargo": "spare parts", "reward": 300},
		"tower": {"name": "Radio Tower", "pos": Vector2(25, 35), "radius": 8.0, "kind": "radio_tower",
			"cargo": "drone batteries", "reward": 500},
	}
	v.roads = [
		PackedVector2Array([Vector2(-95, -95), Vector2(-60, -102), Vector2(-25, -85), Vector2(8, -96), Vector2(45, -80),
			Vector2(85, -55), Vector2(96, -15), Vector2(92, 25), Vector2(78, 55), Vector2(75, 88)]),
		PackedVector2Array([Vector2(-95, -95), Vector2(-100, -55), Vector2(-88, -15), Vector2(-98, 25), Vector2(-85, 60), Vector2(-72, 92)]),
	]
	v.puddles = [
		{"pos": Vector2(8, -96), "radius": 7.0},
		{"pos": Vector2(-88, -15), "radius": 6.0},
		{"pos": Vector2(92, 25), "radius": 6.0},
	]
	v.spawn = Vector2(-88.0, -93.0)
	v.spawn_yaw = -PI * 0.5
	return v
