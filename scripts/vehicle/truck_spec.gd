class_name TruckSpec
extends RefCounted
## A truck as data, as a Valley is a valley: its wheels, springs, engine, fuel, what it weighs
## empty and loaded, where its winch and its hitch are, the look its body is built from, what it
## carries, how far the camera sits behind it and how its engine sounds. TruckSpec.all() lists
## them, the pickup first (docs/trucks.md).

var id := ""
var title := ""
var price := 0  # in the garage; 0: owned from the start
var comes_with := ""  # the TrailerSpec bought with it ("" none)

# Body.
var mass := 2000.0  # empty
var center_of_mass := Vector3(0.0, -0.1, 0.0)
var shapes: Array[Dictionary] = []  # collision boxes: {size, pos}
var body := "pickup"  # the look Vehicle builds (Vehicle._build_<body>)

# Wheels: {mount (the top of its travel, in the body's frame), radius, width, steer (turns with
# the wheel), drive2 (driven in 2WD too); and, for a tyre that is not the pickup's, sink (how much
# of the drag of snow and mud it feels: a big tyre floats), bite (how much of the grip they take it
# wins back: a lugged tread), look ("lugs", "dual")}; axles pair them left and right, front to back.
var wheels: Array[Dictionary] = []
var axles: Array[Vector2i] = []
var all_wheel := true  # every wheel can be driven (4x4, 6x6); false: only the drive2 ones, ever
var rest_length := 0.5
var spring_k := 32000.0
var damping := 3800.0
var anti_roll := 16000.0
var rim_color := Color(0.75, 0.3, 0.1)

# Engine and steering.
var engine_force := 12000.0
var low_mult := 1.8
var max_speed_high := 18.0  # m/s
var max_speed_low := 5.5
var max_speed_reverse := 5.0
var max_steer := 0.6
var steer_speed := 2.2
var fuel_capacity := 80.0  # L
var burn := 1.0  # times the pickup's fuel at the same throttle

# Loads: what each kind of load weighs on its own bed (a kind it does not list, it does not
# carry); a trailer's loads are the trailer's (TrailerSpec.cargo_mass).
## and of Zsuv's resources (Hold.RESOURCES): fuel in litres and soil in m3, so capacity says how
## much of a kind is a full load (1 if it is not listed).
var cargo_mass := {}
var capacity := {}
var tows: Array[String] = []  # the TrailerSpecs it can hitch

# Gear.
var winch_mount := Vector3(0.0, 0.25, -2.4)
var winch_length := 20.0  # m of cable (docs/plan.md §8)
var hitch := Vector3.ZERO  # where a trailer couples, in the body's frame
var hitch_kind := ""  # "": none; "ball" a towbar; "pin" a tractor's drawbar pin; "fifth" a fifth wheel
var lights: Array[Vector3] = []  # headlights, in the body's frame
var intake := Vector3(0.0, 0.25, -1.4)  # the engine's air intake, in the body's frame: water over it floods the engine (§8)
var snorkel := Vector3(0.8, 0.95, -0.9)  # the intake with the snorkel fitted, up by the roof (1.6 m over the ground); ZERO: none fits
var reveal := 40.0  # m of the map it uncovers around it, driven (§3)

# Camera and sound.
var camera_distance := 10.0
var camera_height := 1.6
var engine_pitch := 1.0  # the recordings' pitch at the same revs
var engine_pos := Vector3(0.0, 0.4, -1.7)  # where the engine is heard from, in the body's frame


static func all() -> Array[TruckSpec]:
	return [pickup(), six(), tractor(), semi(), scout(), mixer()]


static func find(spec_id: String) -> TruckSpec:
	for s in all():
		if s.id == spec_id:
			return s
	return null


## The orange pickup every valley starts with: 4x2 or 4x4, low range, a winch at the front.
static func pickup() -> TruckSpec:
	var s := TruckSpec.new()
	s.id = "pickup"
	s.title = "Pickup"
	s.shapes = [
		{"size": Vector3(1.9, 1.0, 4.5), "pos": Vector3(0.0, 0.3, 0.0)},
		{"size": Vector3(1.9, 0.5, 1.4), "pos": Vector3(0.0, 1.03, -0.5)},
	]
	s.wheels = [
		_wheel(Vector3(-0.95, 0.2, -1.55), 0.5, 0.42, true, false),
		_wheel(Vector3(0.95, 0.2, -1.55), 0.5, 0.42, true, false),
		_wheel(Vector3(-0.95, 0.2, 1.45), 0.5, 0.42, false, true),
		_wheel(Vector3(0.95, 0.2, 1.45), 0.5, 0.42, false, true),
	]
	s.axles = [Vector2i(0, 1), Vector2i(2, 3)]
	s.cargo_mass = {"plain": 900.0, "timed": 900.0, "fragile": 900.0, "fuel": 400.0, "parts": 900.0}
	s.capacity = {"fuel": 400.0}  # barrels
	s.hitch = Vector3(0.0, 0.0, 2.35)
	s.hitch_kind = "ball"
	s.tows = ["trailer"]
	s.lights = [Vector3(-0.6, 0.45, -2.3), Vector3(0.6, 0.45, -2.3)]
	return s


## The heavy 6x6, an army truck of the Ural's kind: a long bonnet, three axles on big single
## tyres that float on snow and bite in mud, the rear two driven in 2WD (6x4), all six in 6x6, a
## strong low range, high off the ground, thirsty. The heavy load, six concrete rings, is its alone.
## Its front wheels are under the cab, its origin rides 0.7 m over the ground, its towbar is
## dropped to the pickup's height.
static func six() -> TruckSpec:
	var s := TruckSpec.new()
	s.id = "six"
	s.title = "Heavy 6x6"
	s.price = 3500
	s.mass = 6500.0
	s.center_of_mass = Vector3(0.0, -0.05, 0.2)
	s.body = "six"
	s.shapes = [
		{"size": Vector3(2.3, 0.75, 7.4), "pos": Vector3(0.0, 0.425, -0.02)},  # the frame and the bed's floor
		{"size": Vector3(2.0, 0.65, 1.7), "pos": Vector3(0.0, 1.1, -2.75)},  # the bonnet
		{"size": Vector3(2.3, 1.25, 1.55), "pos": Vector3(0.0, 1.425, -1.2)},  # the cab
		{"size": Vector3(2.45, 0.6, 3.85), "pos": Vector3(0.0, 1.1, 1.775)},  # the bed's sides
	]
	var tyre := {"sink": 0.65, "bite": 0.3, "look": "lugs"}
	for z: float in [-2.0, 0.95, 2.35]:
		for x: float in [-1.0, 1.0]:
			s.wheels.append(_wheel(Vector3(x, 0.275, z), 0.6, 0.45, z < 0.0, z > 0.0).merged(tyre))
	s.axles = [Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5)]
	s.rest_length = 0.55
	s.spring_k = 65000.0
	s.damping = 7500.0
	s.anti_roll = 30000.0
	s.rim_color = Color(0.3, 0.34, 0.2)
	s.engine_force = 36000.0
	s.low_mult = 2.2
	s.max_speed_high = 14.0
	s.max_speed_low = 4.5
	s.max_speed_reverse = 4.0
	s.max_steer = 0.65
	s.steer_speed = 1.8
	s.fuel_capacity = 150.0
	s.burn = 1.8
	s.cargo_mass = {"plain": 900.0, "timed": 900.0, "fragile": 900.0, "heavy": 3500.0, "parts": 900.0, "timber": 3000.0}
	s.tows = ["trailer"]
	s.winch_mount = Vector3(0.0, 0.15, -3.8)
	s.winch_length = 24.0
	s.intake = Vector3(-1.0, 0.8, -1.9)  # 1.5 m over the ground
	s.snorkel = Vector3(-1.1, 1.8, -1.8)  # 2.2 m or more over the ground: it fords the river's shallows
	s.hitch = Vector3(0.0, -0.05, 3.9)
	s.hitch_kind = "ball"
	s.lights = [Vector3(-0.88, 0.85, -3.42), Vector3(0.88, 0.85, -3.42)]
	s.camera_distance = 13.0
	s.camera_height = 2.4
	s.engine_pitch = 0.82
	s.engine_pos = Vector3(0.0, 0.9, -2.8)
	return s


## The farm tractor, of the Belarus kind: small steered wheels at the front, big lugged ones at
## the back that are driven in 2WD, the front axle driven too in 4x4; slow, a very strong low
## range, the best grip in bog and deep snow. It carries nothing itself: its loads go in its farm
## trailer, on the drawbar pin low at its back. Its origin rides 0.95 m over the ground.
static func tractor() -> TruckSpec:
	var s := TruckSpec.new()
	s.id = "tractor"
	s.title = "Tractor"
	s.price = 2500
	s.comes_with = "farm"
	s.mass = 4000.0
	s.center_of_mass = Vector3(0.0, -0.25, 0.02)
	s.body = "tractor"
	s.shapes = [
		{"size": Vector3(0.9, 1.1, 2.4), "pos": Vector3(0.0, 0.2, -1.05)},  # the engine and its bonnet
		{"size": Vector3(1.9, 1.3, 1.6), "pos": Vector3(0.0, 0.35, 0.95)},  # the gearbox, the fenders
		{"size": Vector3(1.4, 0.9, 1.4), "pos": Vector3(0.0, 1.45, 0.85)},  # the cab
	]
	var front := {"sink": 0.85, "bite": 0.15, "look": "lugs"}
	var rear := {"sink": 0.55, "bite": 0.45, "look": "lugs"}
	s.wheels = [
		_wheel(Vector3(-0.78, -0.19, -1.5), 0.48, 0.26, true, false).merged(front),
		_wheel(Vector3(0.78, -0.19, -1.5), 0.48, 0.26, true, false).merged(front),
		_wheel(Vector3(-0.92, 0.03, 0.95), 0.78, 0.42, false, true).merged(rear),
		_wheel(Vector3(0.92, 0.03, 0.95), 0.78, 0.42, false, true).merged(rear),
	]
	s.axles = [Vector2i(0, 1), Vector2i(2, 3)]
	s.rest_length = 0.4
	s.spring_k = 60000.0
	s.damping = 6500.0
	s.anti_roll = 15000.0
	s.rim_color = Color(0.82, 0.82, 0.78)
	s.engine_force = 24000.0
	s.low_mult = 2.4
	s.max_speed_high = 8.3
	s.max_speed_low = 2.5
	s.max_speed_reverse = 3.5
	s.max_steer = 0.55
	s.steer_speed = 2.0
	s.fuel_capacity = 120.0
	s.burn = 1.2
	s.cargo_mass = {}
	s.tows = ["farm"]
	s.winch_mount = Vector3(0.0, -0.25, -2.45)
	s.winch_length = 18.0
	s.intake = Vector3(-0.28, 0.35, -0.3)  # 1.3 m over the ground
	s.snorkel = Vector3(-0.28, 1.15, -0.3)  # 2.1 m
	s.hitch = Vector3(0.0, -0.22, 2.0)  # as high as the farm trailer's drawbar eye stands
	s.hitch_kind = "pin"
	s.lights = [Vector3(-0.25, 0.42, -2.2), Vector3(0.25, 0.42, -2.2)]
	s.camera_distance = 11.0
	s.camera_height = 2.2
	s.engine_pitch = 0.92
	s.engine_pos = Vector3(0.0, 0.3, -1.2)
	return s


## The semi truck, a cab-over tractor unit of the MAZ kind: three axles, the rear two driven
## (6x4) and never the front, road tyres (doubled at the back) that sink in snow and mud, fast on
## a road, a long wheelbase and little lock, so it turns wide. It carries nothing itself: its load
## goes on the semi-trailer, on the fifth wheel over its rear axles, 1.3 m off the ground. Its
## origin rides 0.85 m over the ground.
static func semi() -> TruckSpec:
	var s := TruckSpec.new()
	s.id = "semi"
	s.title = "Semi truck"
	s.price = 5000
	s.comes_with = "semi_trailer"
	s.mass = 7000.0
	s.center_of_mass = Vector3(0.0, -0.1, -0.35)
	s.body = "semi"
	s.shapes = [
		{"size": Vector3(2.3, 0.6, 2.3), "pos": Vector3(0.0, -0.05, -2.45)},  # the frame under the cab
		# Behind the cab, the frame and the tanks stand lower than the fifth wheel: a semi-trailer's
		# deck clears them as the truck backs under it.
		{"size": Vector3(2.3, 0.35, 4.6), "pos": Vector3(0.0, -0.175, 1.0)},
		{"size": Vector3(2.45, 2.4, 2.3), "pos": Vector3(0.0, 1.45, -2.45)},  # the cab
	]
	var road := {"sink": 1.15, "bite": 0.0}
	var dual := {"sink": 1.15, "bite": 0.0, "look": "dual"}
	s.wheels = [
		_wheel(Vector3(-1.03, -0.08, -2.2), 0.54, 0.32, true, false).merged(road),
		_wheel(Vector3(1.03, -0.08, -2.2), 0.54, 0.32, true, false).merged(road),
	]
	for z: float in [1.2, 2.55]:
		for x: float in [-1.0, 1.0]:
			s.wheels.append(_wheel(Vector3(x, 0.02, z), 0.54, 0.3, false, true).merged(dual))
	s.axles = [Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5)]
	s.all_wheel = false
	s.rest_length = 0.45
	s.spring_k = 80000.0
	s.damping = 8000.0
	s.anti_roll = 24000.0
	s.rim_color = Color(0.82, 0.82, 0.8)
	s.engine_force = 50000.0
	s.low_mult = 1.6
	s.max_speed_high = 19.5
	s.max_speed_low = 5.0
	s.max_speed_reverse = 4.0
	s.max_steer = 0.48
	s.steer_speed = 1.6
	s.fuel_capacity = 300.0
	s.burn = 2.2
	s.cargo_mass = {}
	s.tows = ["semi_trailer"]
	s.winch_mount = Vector3(0.0, -0.2, -3.65)
	s.winch_length = 24.0
	s.intake = Vector3(-0.95, 0.35, -1.18)  # 1.2 m over the ground
	s.snorkel = Vector3.ZERO  # none fits the semi
	s.hitch = Vector3(0.0, 0.45, 1.65)
	s.hitch_kind = "fifth"
	s.lights = [Vector3(-0.85, -0.05, -3.65), Vector3(0.85, -0.05, -3.65)]
	s.camera_distance = 15.0
	s.camera_height = 3.0
	s.engine_pitch = 0.8
	s.engine_pos = Vector3(0.0, 0.4, -2.3)
	return s


## The scout (docs/plan.md §7): a short two-door 4x4 of the road service, light and quick, always
## in 4x4, with low range and a winch to get itself out. It carries nothing and tows nothing: its
## job is to find the way and uncover the map. Its origin rides about 0.55 m over the ground.
static func scout() -> TruckSpec:
	var s := TruckSpec.new()
	s.id = "scout"
	s.title = "Scout"
	s.mass = 1200.0
	s.center_of_mass = Vector3(0.0, -0.1, 0.0)
	s.body = "scout"
	s.shapes = [
		{"size": Vector3(1.75, 0.75, 3.9), "pos": Vector3(0.0, 0.225, 0.0)},  # the body
		{"size": Vector3(1.7, 0.75, 2.3), "pos": Vector3(0.0, 0.95, 0.35)},  # the cab and the hard top
	]
	for z: float in [-1.15, 1.15]:
		for x: float in [-0.8, 0.8]:
			s.wheels.append(_wheel(Vector3(x, 0.05, z), 0.36, 0.3, z < 0.0, z > 0.0))
	s.axles = [Vector2i(0, 1), Vector2i(2, 3)]
	s.rest_length = 0.4
	s.spring_k = 20000.0
	s.damping = 2400.0
	s.anti_roll = 10000.0
	s.rim_color = Color(0.95, 0.5, 0.1)
	s.engine_force = 9400.0
	s.low_mult = 1.8
	s.max_speed_high = 24.0
	s.max_speed_low = 6.0
	s.max_speed_reverse = 5.0
	s.max_steer = 0.55
	s.steer_speed = 2.6
	s.fuel_capacity = 45.0
	s.burn = 0.5
	s.cargo_mass = {}
	s.tows = []
	s.winch_mount = Vector3(0.0, 0.0, -2.0)
	s.winch_length = 20.0
	s.intake = Vector3(0.75, 0.25, -1.3)  # 0.8 m over the ground: it floods first
	s.snorkel = Vector3(0.85, 1.05, -0.8)  # 1.6 m
	s.reveal = 90.0
	s.lights = [Vector3(-0.55, 0.4, -1.96), Vector3(0.55, 0.4, -1.96)]
	s.camera_distance = 8.0
	s.camera_height = 1.3
	s.engine_pitch = 1.3
	s.engine_pos = Vector3(0.0, 0.3, -1.4)
	return s


## The concrete mixer (docs/plan.md §7): the semi truck's cab, chassis and wheels (6x4, low
## range) with a drum behind the cab that turns while it carries concrete, and a chute at the
## back. It carries concrete only, one load, which sets 5 minutes after it goes in (Hold).
static func mixer() -> TruckSpec:
	var s := semi()
	s.id = "mixer"
	s.title = "Mixer"
	s.price = 0
	s.comes_with = ""
	s.mass = 9000.0
	s.center_of_mass = Vector3(0.0, 0.0, -0.1)
	s.body = "mixer"
	s.shapes = [
		{"size": Vector3(2.3, 0.6, 2.3), "pos": Vector3(0.0, -0.05, -2.45)},  # the frame under the cab
		{"size": Vector3(2.3, 0.35, 4.6), "pos": Vector3(0.0, -0.175, 1.0)},  # the frame behind it
		{"size": Vector3(2.45, 2.4, 2.3), "pos": Vector3(0.0, 1.45, -2.45)},  # the cab
		{"size": Vector3(2.2, 2.0, 4.3), "pos": Vector3(0.0, 1.1, 0.95)},  # the drum on its frame
	]
	s.spring_k = 120000.0
	s.damping = 11000.0
	s.anti_roll = 36000.0
	s.engine_force = 66000.0
	s.low_mult = 1.8
	s.max_speed_high = 16.0
	s.max_speed_low = 4.5
	s.fuel_capacity = 200.0
	s.burn = 1.6
	s.cargo_mass = {"concrete": 6000.0}
	s.tows = []
	s.hitch = Vector3.ZERO
	s.hitch_kind = ""
	s.winch_length = 24.0
	s.intake = Vector3(-0.95, 0.45, -1.18)  # 1.3 m over the ground
	s.snorkel = Vector3(-1.25, 1.65, -1.6)  # 2.5 m
	s.camera_distance = 14.0
	return s


static func _wheel(mount: Vector3, radius: float, width: float, steer: bool, drive2: bool) -> Dictionary:
	return {"mount": mount, "radius": radius, "width": width, "steer": steer, "drive2": drive2}
