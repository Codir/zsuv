class_name Valley
extends RefCounted
## One valley: its places and roads, the shape of its ground, what lies on it (snow or dust, mud,
## ice), its trees, colours and price. Valley.all() lists the five in the order they open, easiest
## first, with more places to deliver to as they go (docs/valleys.md); every one is 256 m square.

const DITCH_LENGTH := 10.0
const DITCH_WIDTH := 2.4  # from its middle to where it meets the ground

var id := ""
var title := ""
var blurb := ""  # one line for the start screen's card
var price := 0
var stars := 1  # how hard, 1..5
var season := "winter"  # winter | spring | summer | autumn: snow or rain, the trees
var pay := 1.0  # jobs here pay this many times the khutir valley's
var own: Weather  # its own sky; the start screen can switch it (Weather.Kind)

# Ground: noise relief, then features: {type: hill | ridge | lake | gully | ditch, ...}.
var seed := 1337
var relief := 16.0
var detail := 2.5
var rim := 30.0  # how high the land climbs at the map's edge
var features: Array[Dictionary] = []

# Places: key -> {name, pos, radius, kind (what the world builder puts there), cargo, reward;
# offroad: no road goes there}.
var locations := {}
var roads: Array[PackedVector2Array] = []
var road_smooth := 0.0  # metres a road's profile is averaged over (0: it keeps to the ground)
var road_grade := 0.0  # the steepest a smoothed road may climb, as a fraction (0: any)
var ramp_max := INF  # the longest ramp off a place: on a mountain, a high place drags the land
var spawn := Vector2.ZERO
var spawn_yaw := 0.0

# The soft layer the wheels pack into ruts: snow, or the dust of a dry dirt road.
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
var mud_below := INF  # mud only below this height (the wet lows)
var ditches: Array[Dictionary] = []  # {pos: the road beside it, at: its middle, dir}: a car can be stuck there

# Looks.
var earth := Color(0.2, 0.15, 0.11)
var gravel := Color(0.36, 0.34, 0.31)
var layer_color := Color(0.86, 0.9, 0.98)
var layer_packed := Color(0.56, 0.6, 0.7)
var mud_color := Color(0.3, 0.22, 0.14)
var mud_packed := Color(0.17, 0.12, 0.08)
var ice_color := Color(0.62, 0.74, 0.82)
var trees := "pine_snow"  # pine_snow | pine | spruce_snow | poplar | broadleaf | pine_birch
var tree_count := 500
var rock_count := 60
var poles := true  # orange snow poles along the roads


static func all() -> Array[Valley]:
	return [khutir(), steppe(), zakarpattia(), polissia(), carpathians()]


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
		"depot": {"name": "Depot", "pos": Vector2(-95, -95), "radius": 14.0, "kind": "depot", "out": Vector2(35, -7)},
		"farm": {"name": "Khutir", "pos": Vector2(-72, 92), "radius": 10.0, "kind": "khutir",
			"cargo": "groceries", "reward": 250},
		"lumber": {"name": "Sawmill", "pos": Vector2(75, 88), "radius": 10.0, "kind": "sawmill",
			"cargo": "spare parts", "reward": 300},
		"tower": {"name": "Radio Tower", "pos": Vector2(25, 35), "radius": 8.0, "kind": "radio_tower",
			"cargo": "drone batteries", "reward": 500, "offroad": true},
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
	return v._with_ditches()


## A sunny autumn in the Slobozhanshchyna steppe: long dry dirt roads, gullies, a hill of turbines.
static func steppe() -> Valley:
	var v := Valley.new()
	v.id = "steppe"
	v.title = "The Steppe"
	v.blurb = "Sunny autumn. Long dry dirt roads, gullies, mud at their bottoms."
	v.price = 1500
	v.stars = 1
	v.season = "autumn"
	v.pay = 1.2
	v.own = _sky("sunny autumn", Color(0.6, 0.74, 0.93), Color(0.84, 0.8, 0.7), 0.004,
		Color(0.78, 0.74, 0.66), 0.75, Color(1.0, 0.86, 0.62), 1.2, Vector3(-28.0, 60.0, 0.0))
	v.seed = 2024
	v.relief = 8.0
	v.detail = 1.5
	v.rim = 10.0
	v.features = [
		{"type": "gully", "points": PackedVector2Array([Vector2(-130, -20), Vector2(-62, 38), Vector2(-40, 62), Vector2(-12, 130)]),
			"width": 30.0, "depth": 6.0},
		{"type": "gully", "points": PackedVector2Array([Vector2(8, -130), Vector2(28, -12), Vector2(18, 40), Vector2(-14, 130)]),
			"width": 24.0, "depth": 5.0},
		{"type": "hill", "pos": Vector2(62, 55), "radius": 48.0, "height": 10.0},
	]
	v.locations = {
		"depot": {"name": "Motor Yard", "pos": Vector2(-90, -85), "radius": 14.0, "kind": "yard"},
		"elevator": {"name": "Elevator", "pos": Vector2(72, -78), "radius": 12.0, "kind": "elevator",
			"cargo": "conveyor belts", "reward": 300},
		"sheepfold": {"name": "Sheepfold", "pos": Vector2(-42, 60), "radius": 10.0, "kind": "sheepfold",
			"cargo": "sheep feed", "reward": 250},
		"wind": {"name": "Wind Farm", "pos": Vector2(60, 55), "radius": 10.0, "kind": "wind_farm",
			"cargo": "turbine parts", "reward": 350},
		"kurgan": {"name": "Kurgan Dig", "pos": Vector2(-72, 92), "radius": 10.0, "kind": "kurgan_dig",
			"cargo": "the archaeologists' tents", "reward": 350},
	}
	v.roads = [
		PackedVector2Array([Vector2(-90, -85), Vector2(-40, -92), Vector2(20, -88), Vector2(72, -78)]),
		PackedVector2Array([Vector2(-90, -85), Vector2(-96, -30), Vector2(-72, 20), Vector2(-42, 60)]),
		PackedVector2Array([Vector2(20, -88), Vector2(36, -30), Vector2(44, 15), Vector2(60, 55)]),
		_bends(PackedVector2Array([Vector2(-42, 60), Vector2(-52, 84), Vector2(-72, 92)]), 9.0),
	]
	v.road_smooth = 14.0
	v.road_grade = 0.22
	v.ramp_max = 36.0
	v.puddles = [{"pos": Vector2(-56, 34), "radius": 7.0}, {"pos": Vector2(28, -22), "radius": 6.0}]
	v.layer = "dust"
	v.layer_base = 0.16
	v.layer_noise = 0.14
	v.layer_min = 0.05
	v.layer_on_road = 0.5
	v.layer_grip = 0.85
	v.layer_rolling = 0.25
	v.mud_from = 0.45
	v.earth = Color(0.42, 0.34, 0.2)
	v.gravel = Color(0.52, 0.45, 0.34)
	v.layer_color = Color(0.74, 0.64, 0.38)
	v.layer_packed = Color(0.5, 0.42, 0.28)
	v.trees = "poplar"
	v.tree_count = 110
	v.rock_count = 25
	v.poles = false
	return v._near_depot()._with_ditches()


## A sunny spring in Zakarpattia after the rain: vineyards, a castle on its hill, snow on the peaks.
static func zakarpattia() -> Valley:
	var v := Valley.new()
	v.id = "zakarpattia"
	v.title = "Zakarpattia"
	v.blurb = "Spring sun after rain. Meltwater mud in the lows, snow on the peaks."
	v.price = 2500
	v.stars = 2
	v.season = "spring"
	v.pay = 1.4
	v.own = _sky("spring sun", Color(0.55, 0.72, 0.95), Color(0.76, 0.83, 0.9), 0.005,
		Color(0.7, 0.76, 0.72), 0.72, Color(1.0, 0.96, 0.88), 1.1, Vector3(-45.0, 30.0, 0.0))
	v.seed = 3031
	v.relief = 12.0
	v.features = [
		{"type": "ridge", "from": Vector2(-140, -104), "to": Vector2(140, -96), "width": 62.0, "height": 22.0},
		{"type": "hill", "pos": Vector2(76, 70), "radius": 46.0, "height": 9.0},
	]
	v.locations = {
		"depot": {"name": "Station", "pos": Vector2(-80, 86), "radius": 14.0, "kind": "station"},
		"winery": {"name": "Winery", "pos": Vector2(10, 38), "radius": 10.0, "kind": "winery",
			"cargo": "empty barrels", "reward": 300},
		"castle": {"name": "Castle", "pos": Vector2(76, 70), "radius": 10.0, "kind": "castle",
			"cargo": "festival stage lights", "reward": 400},
		"church": {"name": "Wooden Church", "pos": Vector2(-30, -72), "radius": 10.0, "kind": "wooden_church",
			"cargo": "roof shingles", "reward": 350},
		"spring": {"name": "Mineral Spring", "pos": Vector2(66, -34), "radius": 10.0, "kind": "pump_room",
			"cargo": "bottle crates", "reward": 350},
	}
	v.roads = [
		PackedVector2Array([Vector2(-80, 86), Vector2(-42, 80), Vector2(-12, 60), Vector2(10, 38)]),
		_bends(PackedVector2Array([Vector2(10, 38), Vector2(40, 44), Vector2(48, 66), Vector2(62, 80), Vector2(76, 70)]), 9.0),
		_bends(PackedVector2Array([Vector2(10, 38), Vector2(-4, 10), Vector2(-28, -14), Vector2(-8, -38), Vector2(-40, -52), Vector2(-30, -72)]), 9.0),
		_bends(PackedVector2Array([Vector2(10, 38), Vector2(40, 22), Vector2(58, -8), Vector2(66, -34)]), 9.0),
	]
	v.road_smooth = 20.0
	v.road_grade = 0.2
	v.ramp_max = 36.0
	v.puddles = [{"pos": Vector2(-26, 72), "radius": 6.0}, {"pos": Vector2(28, 44), "radius": 5.0}, {"pos": Vector2(-18, 0), "radius": 6.0}]
	v.layer_base = 0.7
	v.layer_noise = 0.4
	v.layer_min = 0.3
	v.layer_on_road = 0.15
	v.layer_from = 14.0
	v.mud_from = 0.2
	v.mud_below = 2.0
	v.earth = Color(0.24, 0.34, 0.15)
	v.gravel = Color(0.45, 0.43, 0.4)
	v.mud_color = Color(0.32, 0.24, 0.15)
	v.trees = "broadleaf"
	v.tree_count = 320
	v.rock_count = 50
	v.poles = false
	return v._near_depot()._with_ditches()


## A spring thaw in Polissia on a grey foggy morning: bogs, mud, and the road across a frozen lake.
static func polissia() -> Valley:
	var v := Valley.new()
	v.id = "polissia"
	v.title = "Polissia"
	v.blurb = "A grey morning in the thaw. Fog, bog, mud, and ice on the lake."
	v.price = 4000
	v.stars = 3
	v.season = "spring"
	v.pay = 1.7
	v.own = _sky("thaw, fog", Color(0.62, 0.64, 0.66), Color(0.67, 0.69, 0.71), 0.03,
		Color(0.6, 0.62, 0.66), 0.7, Color(0.86, 0.86, 0.86), 0.35, Vector3(-15.0, 70.0, 0.0))
	v.seed = 4047
	v.relief = 6.0
	v.features = [
		{"type": "lake", "pos": Vector2(10, -12), "radius": 34.0, "depth": 2.5, "ice": true, "shore": 26.0},
		{"type": "hill", "pos": Vector2(66, 82), "radius": 36.0, "height": 9.0},
	]
	v.locations = {
		"depot": {"name": "Old Farm", "pos": Vector2(-85, -80), "radius": 14.0, "kind": "yard"},
		"fish": {"name": "Fish Farm", "pos": Vector2(62, -22), "radius": 10.0, "kind": "fish_farm",
			"cargo": "fish feed", "reward": 300},
		"peat": {"name": "Peat Works", "pos": Vector2(-40, 72), "radius": 10.0, "kind": "peat_works",
			"cargo": "excavator parts", "reward": 350},
		"village": {"name": "Village", "pos": Vector2(66, 82), "radius": 12.0, "kind": "village_church",
			"cargo": "bread and post", "reward": 300},
		"apiary": {"name": "Apiary", "pos": Vector2(-8, 46), "radius": 9.0, "kind": "apiary",
			"cargo": "empty frames", "reward": 300},
		"forestry": {"name": "Forestry", "pos": Vector2(4, -78), "radius": 10.0, "kind": "forestry",
			"cargo": "saplings", "reward": 300},
	}
	v.roads = [
		PackedVector2Array([Vector2(-85, -80), Vector2(-60, -40), Vector2(-34, -14), Vector2(15, -12), Vector2(46, -18), Vector2(62, -22)]),
		PackedVector2Array([Vector2(-85, -80), Vector2(-92, -20), Vector2(-76, 25), Vector2(-56, 50), Vector2(-40, 72)]),
		PackedVector2Array([Vector2(62, -22), Vector2(78, 14), Vector2(72, 50), Vector2(66, 82)]),
		PackedVector2Array([Vector2(-76, 25), Vector2(-42, 36), Vector2(-8, 46)]),
		PackedVector2Array([Vector2(-85, -80), Vector2(-52, -88), Vector2(-22, -84), Vector2(4, -78)]),
	]
	v.puddles = [{"pos": Vector2(-44, 54), "radius": 16.0}, {"pos": Vector2(-72, 40), "radius": 11.0},
		{"pos": Vector2(-90, 0), "radius": 7.0}, {"pos": Vector2(76, 30), "radius": 7.0}]
	v.layer_base = 0.15
	v.layer_noise = 0.45
	v.layer_min = 0.0
	v.layer_on_road = 0.02
	v.mud_from = 0.12
	v.earth = Color(0.25, 0.23, 0.15)
	v.gravel = Color(0.4, 0.38, 0.34)
	v.layer_color = Color(0.78, 0.8, 0.82)
	v.layer_packed = Color(0.5, 0.5, 0.5)
	v.mud_color = Color(0.25, 0.2, 0.13)
	v.ice_color = Color(0.6, 0.7, 0.76)
	v.trees = "pine_birch"
	v.tree_count = 420
	v.rock_count = 20
	v.poles = false
	return v._near_depot()._with_ditches()


## A Carpathian pass at night in a blizzard: switchbacks through deep snow up to a ridge.
static func carpathians() -> Valley:
	var v := Valley.new()
	v.id = "carpathians"
	v.title = "The Carpathian Pass"
	v.blurb = "Night, a blizzard. Switchbacks through deep snow up to the ridge."
	v.price = 6000
	v.stars = 5
	v.season = "winter"
	v.pay = 2.4
	v.own = _sky("night blizzard", Color(0.05, 0.06, 0.09), Color(0.12, 0.13, 0.17), 0.055,
		Color(0.3, 0.34, 0.45), 0.35, Color(0.6, 0.68, 0.9), 0.1, Vector3(-40.0, 120.0, 0.0))
	v.own.fall = "snow"
	v.own.fall_amount = 2500
	v.own.wind = 2.5
	v.own.night = true
	v.seed = 6067
	v.relief = 10.0
	v.features = [
		{"type": "ridge", "from": Vector2(-140, -62), "to": Vector2(140, -72), "width": 72.0, "height": 22.0},
	]
	v.locations = {
		"depot": {"name": "Village", "pos": Vector2(-80, 90), "radius": 14.0, "kind": "yard"},
		"koliba": {"name": "Koliba", "pos": Vector2(-62, -10), "radius": 10.0, "kind": "koliba",
			"cargo": "salt and supplies", "reward": 350},
		"weather": {"name": "Weather Station", "pos": Vector2(46, -64), "radius": 8.0, "kind": "weather_station",
			"cargo": "instrument batteries", "reward": 500},
		"rescue": {"name": "Mountain Rescue", "pos": Vector2(70, 20), "radius": 10.0, "kind": "rescue_base",
			"cargo": "ropes and stretchers", "reward": 400},
		"logging": {"name": "Logging Camp", "pos": Vector2(-18, 22), "radius": 10.0, "kind": "sawmill",
			"cargo": "chainsaw chains", "reward": 350},
		"village": {"name": "Mountain Village", "pos": Vector2(-12, -28), "radius": 10.0, "kind": "wooden_church",
			"cargo": "flour and candles", "reward": 450},
	}
	v.roads = [
		_bends(PackedVector2Array([Vector2(-80, 90), Vector2(-40, 86), Vector2(-8, 70), Vector2(22, 60), Vector2(50, 46), Vector2(70, 20)]), 10.0),
		_bends(PackedVector2Array([Vector2(-80, 90), Vector2(-92, 64), Vector2(-64, 48), Vector2(-90, 28), Vector2(-66, 10), Vector2(-62, -10)]), 8.0),
		# Legs that climb across the slope, and each hairpin a U of 12 m at their ends: a V is
		# tighter than the truck turns.
		_bends(PackedVector2Array([Vector2(70, 20), Vector2(88, 2), Vector2(88, -10), Vector2(54, -22), Vector2(54, -34),
			Vector2(86, -44), Vector2(86, -54), Vector2(52, -60), Vector2(46, -64)]), 6.0),
		_bends(PackedVector2Array([Vector2(-62, -10), Vector2(-40, 6), Vector2(-18, 22)]), 9.0),
		_bends(PackedVector2Array([Vector2(-18, 22), Vector2(8, 16), Vector2(8, 2), Vector2(-22, -6), Vector2(-22, -20),
			Vector2(-12, -28)]), 7.0),  # U turns too
	]
	v.road_smooth = 24.0
	v.road_grade = 0.2
	v.ramp_max = 36.0
	v.layer_base = 0.75
	v.layer_noise = 0.5
	v.layer_min = 0.4
	v.layer_on_road = 0.15
	v.mud_from = 9.0
	v.trees = "spruce_snow"
	v.tree_count = 450
	v.rock_count = 80
	return v._near_depot()._with_ditches()


## A ditch beside the middle of each road, on alternate sides, where a stuck car can wait: dug
## as a ditch feature 7 m off the road's centre line, its floor 1.4 m below the road beside it (a
## trench cut into a slope above the road, banked up on one below), all of it clear of the road,
## its other legs, the other roads and the places.
func _with_ditches() -> Valley:
	for r in roads.size():
		var road := roads[r]
		var total := 0.0
		for i in road.size() - 1:
			total += road[i].distance_to(road[i + 1])
		for try in [0.5, 0.4, 0.6, 0.3, 0.7]:
			var done := false
			for side in [1.0 if r % 2 == 0 else -1.0, -1.0 if r % 2 == 0 else 1.0]:
				var along: float = total * try
				var i := 0
				while i < road.size() - 2 and along > road[i].distance_to(road[i + 1]):
					along -= road[i].distance_to(road[i + 1])
					i += 1
				var dir := (road[i + 1] - road[i]).normalized()
				var p: Vector2 = road[i] + dir * along
				var at: Vector2 = p + Vector2(-dir.y, dir.x) * side * 7.0
				if _ditch_clear(at, dir, r, total * try):
					ditches.append({"pos": p, "at": at, "dir": dir})
					features.append({"type": "ditch", "pos": at, "dir": dir, "road": r, "length": DITCH_LENGTH,
						"width": DITCH_WIDTH, "depth": 1.4})
					done = true
					break
			if done:
				break
	return self


## Whether a ditch along dir at at, beside road own s metres along it, keeps off the roads (its own
## road's edge too, on a bend, and further off its other legs) and the places.
func _ditch_clear(at: Vector2, dir: Vector2, own: int, s: float) -> bool:
	if absf(at.x) > 96.0 or absf(at.y) > 96.0:
		return false
	for loc in locations.values():
		if at.distance_to(loc.pos) < float(loc.radius) + 14.0:
			return false
	for k in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		var q: Vector2 = at + dir * DITCH_LENGTH * 0.5 * k
		for r in roads.size():
			var road := roads[r]
			var along := 0.0
			for i in road.size() - 1:
				var c := Geometry2D.get_closest_point_to_segment(q, road[i], road[i + 1])
				var beside := r == own and absf(along + road[i].distance_to(c) - s) < 20.0
				if q.distance_to(c) < (Terrain.ROAD_HALF_WIDTH + DITCH_WIDTH - 0.1 if beside else 11.0):
					return false
				along += road[i].distance_to(road[i + 1])
	return true


## The truck starts beside the depot, facing the first road out.
func _near_depot() -> Valley:
	var d: Vector2 = locations.depot.pos
	var dir := (roads[0][1] - d).normalized()
	spawn = d + dir * 7.0
	spawn_yaw = atan2(-dir.x, -dir.y)
	return self


static func _sky(sky_name: String, sky: Color, fog: Color, fog_density: float, ambient: Color, ambient_energy: float,
		sun: Color, sun_energy: float, sun_angle: Vector3) -> Weather:
	var w := Weather.new()
	w.name = sky_name
	w.sky = sky
	w.fog = fog
	w.fog_density = fog_density
	w.ambient = ambient
	w.ambient_energy = ambient_energy
	w.sun = sun
	w.sun_energy = sun_energy
	w.sun_angle = sun_angle
	w.fall = "none"
	w.fall_amount = 0
	return w


## A road through points with every corner rounded into an arc of about radius metres, so a
## hairpin is a curve the truck can follow, not a point it overshoots.
static func _bends(points: PackedVector2Array, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array([points[0]])
	for i in range(1, points.size() - 1):
		var b := points[i]
		var u := (points[i - 1] - b).normalized()
		var w := (points[i + 1] - b).normalized()
		var half := u.angle_to(w) * 0.5
		if absf(half) > PI * 0.47:  # nearly straight on
			out.append(b)
			continue
		var d := minf(radius / tan(absf(half)), 0.45 * minf(b.distance_to(points[i - 1]), b.distance_to(points[i + 1])))
		var r := d * tan(absf(half))
		var o := b + (u + w).normalized() * sqrt(d * d + r * r)
		var a1 := (b + u * d - o).angle()
		var a2 := (b + w * d - o).angle()
		var sweep := wrapf(a2 - a1, -PI, PI)
		var n := maxi(2, ceili(absf(sweep) / 0.35))
		for k in n + 1:
			out.append(o + Vector2.from_angle(a1 + sweep * k / n) * r)
	out.append(points[points.size() - 1])
	return out
