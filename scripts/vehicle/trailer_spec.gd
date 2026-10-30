class_name TrailerSpec
extends RefCounted
## A trailer as data: its wheels and springs, what it weighs empty and loaded, its coupler and
## the hitch it fits, the look its body is built from and the loads it carries. A trailer stands
## on its own wheels (and, unhitched, on a jockey wheel or legs at the front); hitched, its
## coupler rides on the truck's hitch. TrailerSpec.all() lists them (docs/trucks.md).
##
## Each one stands level with its coupler as high off the ground as the hitch it fits: the
## pickup's ball 0.64 m, a tractor's drawbar pin 0.70 m, a semi truck's fifth wheel 1.20 m. Its
## frame: x across, y up from the floor of its deck, z back; the springs are sized for the load
## each wheel carries, empty and loaded, and the stand for the share of the weight at the front.

var id := ""
var title := ""
var price := 0  # in the garage on its own; 0: it comes with its truck (TruckSpec.comes_with)
var mass := 400.0  # empty
var center_of_mass := Vector3.ZERO
var shapes: Array[Dictionary] = []  # collision boxes: {size, pos}
var body := "trailer"  # the look Trailer builds (Trailer._build_<body>)
var wheels: Array[Dictionary] = []  # as TruckSpec's; none is steered or driven
var axles: Array[Vector2i] = []
var rest_length := 0.4
var spring_k := 12000.0
var damping := 1500.0
var anti_roll := 6000.0
var rim := Color(0.4, 0.4, 0.42)  # the mark on its wheels
var coupler := Vector3(0.0, 0.0, -2.0)  # where it couples, in its frame (at the front)
var stand := Vector3(0.0, -0.4, -1.6)  # the foot of what it rests on at the front unhitched, in its frame
var stand_k := 30000.0  # the stand's spring, N/m, and damper, N/(m/s)
var stand_damping := 1000.0
var hitch_kind := "ball"  # the TruckSpec.hitch_kind it fits
var cargo_mass := {}  # the loads it carries and what each weighs


static func all() -> Array[TrailerSpec]:
	return [trailer(), farm(), semi_trailer()]


static func find(spec_id: String) -> TrailerSpec:
	for s in all():
		if s.id == spec_id:
			return s
	return null


## A one-axle box trailer for the pickup: a double load, the pickup's bed and the trailer. A
## galvanised box 2.25 m long on an A-frame drawbar, a ball coupler on the pickup's towbar, a
## jockey wheel to stand on.
static func trailer() -> TrailerSpec:
	var s := TrailerSpec.new()
	s.id = "trailer"
	s.title = "Trailer"
	s.price = 800
	s.mass = 400.0
	s.center_of_mass = Vector3(0.0, 0.05, -0.22)  # ahead of the axle: it does not sway, nor tip back on a slope
	s.shapes = [{"size": Vector3(1.5, 0.5, 2.25), "pos": Vector3(0.0, 0.2, -0.125)}]
	s.wheels = [
		TruckSpec._wheel(Vector3(-0.9, 0.0, 0.0), 0.3, 0.2, false, false),
		TruckSpec._wheel(Vector3(0.9, 0.0, 0.0), 0.3, 0.2, false, false),
	]
	s.axles = [Vector2i(0, 1)]
	# 1.9 kN on a wheel empty, 6.1 kN loaded: 5 and 17 cm of its 25.
	s.rest_length = 0.25
	s.spring_k = 36000.0
	s.damping = 2400.0
	s.anti_roll = 8000.0
	s.coupler = Vector3(0.0, 0.14, -2.55)
	s.stand = Vector3(0.0, -0.51, -2.15)
	s.stand_k = 30000.0
	s.stand_damping = 1000.0
	s.hitch_kind = "ball"
	s.cargo_mass = {"double": 900.0}
	return s


## The tractor's farm trailer, a 2PTS-4: a blue high-sided tipper on two axles side by side
## (tandem), a drawbar eye for the tractor's pin, a prop to stand on; a bulk load of grain, peat or
## hay.
static func farm() -> TrailerSpec:
	var s := TrailerSpec.new()
	s.id = "farm"
	s.title = "Farm trailer"
	s.mass = 1500.0
	s.body = "farm"
	s.center_of_mass = Vector3(0.0, 0.1, 0.0)  # 0.6 m ahead of the middle of the tandem
	s.shapes = [{"size": Vector3(2.3, 1.2, 4.0), "pos": Vector3(0.0, 0.6, 0.0)}]
	s.wheels = [
		TruckSpec._wheel(Vector3(-0.82, -0.44, 0.0), 0.45, 0.32, false, false),
		TruckSpec._wheel(Vector3(0.82, -0.44, 0.0), 0.45, 0.32, false, false),
		TruckSpec._wheel(Vector3(-0.82, -0.44, 1.2), 0.45, 0.32, false, false),
		TruckSpec._wheel(Vector3(0.82, -0.44, 1.2), 0.45, 0.32, false, false),
	]
	s.axles = [Vector2i(0, 1), Vector2i(2, 3)]
	# 3.1 kN on a wheel empty, 11 kN loaded: 4 and 13 cm of its 30.
	s.rest_length = 0.3
	s.spring_k = 85000.0
	s.damping = 6500.0
	s.anti_roll = 30000.0
	s.rim = Color(0.62, 0.14, 0.1)
	s.coupler = Vector3(0.0, -0.45, -3.5)
	s.stand = Vector3(0.0, -1.17, -3.0)
	s.stand_k = 200000.0
	s.stand_damping = 5000.0
	s.hitch_kind = "pin"
	s.cargo_mass = {"bulk": 4000.0}
	return s


## The semi truck's flatbed semi-trailer, 12 m long: a long load of logs, pipes or a turbine
## blade. Three axles at the back; its front rides on the truck's fifth wheel, its kingpin a metre
## from the front; unhitched, it stands on its landing legs.
static func semi_trailer() -> TrailerSpec:
	var s := TrailerSpec.new()
	s.id = "semi_trailer"
	s.title = "Semi-trailer"
	s.mass = 3000.0
	s.body = "semi_trailer"
	s.center_of_mass = Vector3(0.0, 0.2, 0.0)
	s.shapes = [{"size": Vector3(2.5, 0.25, 12.0), "pos": Vector3(0.0, 0.075, 0.0)}]
	s.wheels = []
	for z in [1.69, 3.0, 4.31]:
		for x in [-0.95, 0.95]:
			s.wheels.append(TruckSpec._wheel(Vector3(x, -0.36, z), 0.5, 0.55, false, false))
	s.axles = [Vector2i(0, 1), Vector2i(2, 3), Vector2i(4, 5)]
	# 3.1 kN on a wheel empty, 11 kN loaded: 6 and 20 cm of its 40, soft enough that the three
	# axles keep to uneven ground; damped hard, or eight tonnes of logs high on the deck rock it.
	s.rest_length = 0.4
	s.spring_k = 55000.0
	s.damping = 9000.0
	s.anti_roll = 60000.0
	s.coupler = Vector3(0.0, 0.0, -5.0)
	s.stand = Vector3(0.0, -1.22, -2.4)
	s.stand_k = 1500000.0
	s.stand_damping = 60000.0
	s.hitch_kind = "fifth"
	s.cargo_mass = {"long": 8000.0}
	return s
