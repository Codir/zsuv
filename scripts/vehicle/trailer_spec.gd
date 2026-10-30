class_name TrailerSpec
extends RefCounted
## A trailer as data: its wheels and springs, what it weighs empty and loaded, its coupler and
## the hitch it fits, the look its body is built from and the loads it carries. A trailer stands
## on its own wheels (and, unhitched, on a jockey wheel or legs at the front); hitched, its
## coupler rides on the truck's hitch. TrailerSpec.all() lists them (docs/trucks.md).

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
var coupler := Vector3(0.0, 0.0, -2.0)  # where it couples, in its frame (at the front)
var stand := Vector3(0.0, -0.4, -1.6)  # what it rests on at the front when unhitched, in its frame
var hitch_kind := "ball"  # the TruckSpec.hitch_kind it fits
var cargo_mass := {}  # the loads it carries and what each weighs


static func all() -> Array[TrailerSpec]:
	return [trailer(), farm(), semi_trailer()]


static func find(spec_id: String) -> TrailerSpec:
	for s in all():
		if s.id == spec_id:
			return s
	return null


## A one-axle box trailer for the pickup: a double load, the pickup's bed and the trailer.
static func trailer() -> TrailerSpec:
	var s := TrailerSpec.new()
	s.id = "trailer"
	s.title = "Trailer"
	s.price = 800
	s.mass = 400.0
	s.shapes = [{"size": Vector3(1.8, 0.6, 3.0), "pos": Vector3(0.0, 0.3, 0.0)}]
	s.wheels = [
		TruckSpec._wheel(Vector3(-0.95, 0.1, 0.3), 0.4, 0.3, false, false),
		TruckSpec._wheel(Vector3(0.95, 0.1, 0.3), 0.4, 0.3, false, false),
	]
	s.axles = [Vector2i(0, 1)]
	s.coupler = Vector3(0.0, 0.1, -2.6)
	s.stand = Vector3(0.0, -0.45, -2.2)
	s.hitch_kind = "ball"
	s.cargo_mass = {"double": 900.0}
	return s


## The tractor's two-axle farm trailer: a bulk load of grain, peat or hay.
static func farm() -> TrailerSpec:
	var s := TrailerSpec.new()
	s.id = "farm"
	s.title = "Farm trailer"
	s.mass = 1500.0
	s.body = "farm"
	s.shapes = [{"size": Vector3(2.3, 1.0, 4.6), "pos": Vector3(0.0, 0.6, 0.0)}]
	s.wheels = [
		TruckSpec._wheel(Vector3(-1.0, 0.1, -1.2), 0.5, 0.4, false, false),
		TruckSpec._wheel(Vector3(1.0, 0.1, -1.2), 0.5, 0.4, false, false),
		TruckSpec._wheel(Vector3(-1.0, 0.1, 1.2), 0.5, 0.4, false, false),
		TruckSpec._wheel(Vector3(1.0, 0.1, 1.2), 0.5, 0.4, false, false),
	]
	s.axles = [Vector2i(0, 1), Vector2i(2, 3)]
	s.spring_k = 30000.0
	s.damping = 3500.0
	s.coupler = Vector3(0.0, 0.2, -3.6)
	s.stand = Vector3(0.0, -0.5, -3.0)
	s.hitch_kind = "pin"
	s.cargo_mass = {"bulk": 4000.0}
	return s


## The semi truck's flatbed semi-trailer: a long load of logs, pipes or a turbine blade. Its
## front rides on the truck's fifth wheel; unhitched, it stands on its legs.
static func semi_trailer() -> TrailerSpec:
	var s := TrailerSpec.new()
	s.id = "semi_trailer"
	s.title = "Semi-trailer"
	s.mass = 3000.0
	s.body = "semi_trailer"
	s.shapes = [{"size": Vector3(2.4, 0.5, 11.0), "pos": Vector3(0.0, 0.9, 0.0)}]
	s.wheels = [
		TruckSpec._wheel(Vector3(-1.0, 0.3, 3.0), 0.5, 0.4, false, false),
		TruckSpec._wheel(Vector3(1.0, 0.3, 3.0), 0.5, 0.4, false, false),
		TruckSpec._wheel(Vector3(-1.0, 0.3, 4.4), 0.5, 0.4, false, false),
		TruckSpec._wheel(Vector3(1.0, 0.3, 4.4), 0.5, 0.4, false, false),
	]
	s.axles = [Vector2i(0, 1), Vector2i(2, 3)]
	s.spring_k = 60000.0
	s.damping = 6000.0
	s.anti_roll = 30000.0
	s.coupler = Vector3(0.0, 0.6, -4.5)
	s.stand = Vector3(0.0, -0.4, -3.5)
	s.hitch_kind = "fifth"
	s.cargo_mass = {"long": 8000.0}
	return s
