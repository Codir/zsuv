class_name TruckSpec
extends RefCounted
## A truck as data, as a Valley is a valley: its wheels, springs, engine, fuel, what it weighs
## empty and loaded, where its winch and its hitch are, the look its body is built from, what it
## carries, how far the camera sits behind it and how its engine sounds. TruckSpec.all() lists
## them, the pickup first (docs/trucks.md).

var id := ""
var title := ""
var price := 0  # in the garage; 0: owned from the start

# Body.
var mass := 2000.0  # empty
var center_of_mass := Vector3(0.0, -0.1, 0.0)
var shapes: Array[Dictionary] = []  # collision boxes: {size, pos}
var body := "pickup"  # the look Vehicle builds (Vehicle._build_<body>)

# Wheels: {mount (the top of its travel, in the body's frame), radius, width, steer (turns with
# the wheel), drive2 (driven in 2WD too)}; axles pair them left and right, front to back.
var wheels: Array[Dictionary] = []
var axles: Array[Vector2i] = []
var rest_length := 0.5
var spring_k := 32000.0
var damping := 3800.0
var anti_roll := 16000.0

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

# Loads: what each kind of load weighs on it (a kind it does not list, it does not carry).
var cargo_mass := {}

# Gear.
var winch_mount := Vector3(0.0, 0.25, -2.4)
var hitch := Vector3.ZERO  # where a trailer couples, in the body's frame
var hitch_kind := ""  # "": none; "ball" a towbar; "fifth" a fifth wheel for a semi-trailer
var lights: Array[Vector3] = []  # headlights, in the body's frame

# Camera and sound.
var camera_distance := 10.0
var camera_height := 1.6
var engine_pitch := 1.0  # the recordings' pitch at the same revs


static func all() -> Array[TruckSpec]:
	return [pickup()]


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
	s.cargo_mass = {"plain": 900.0, "timed": 900.0, "fragile": 900.0, "heavy": 1800.0}
	s.hitch = Vector3(0.0, 0.0, 2.35)
	s.hitch_kind = "ball"
	s.lights = [Vector3(-0.6, 0.45, -2.3), Vector3(0.6, 0.45, -2.3)]
	return s


static func _wheel(mount: Vector3, radius: float, width: float, steer: bool, drive2: bool) -> Dictionary:
	return {"mount": mount, "radius": radius, "width": width, "steer": steer, "drive2": drive2}
