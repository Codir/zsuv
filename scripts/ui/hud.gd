class_name Hud
extends CanvasLayer
## Dashboard, current objective, prompts and the controls help.

## What the controls help shows; F1 steps through them in this order.
enum Help { HINT, FULL, OFF }

## The keys a drive needs, in a corner: the full card covered the view (Philip, in the jam).
## E, F and T need no place here: the prompt at the bottom names them when they apply.
const HINT_TEXT := """WASD drive  SPACE handbrake
Q 4x4  X diff  G low  M map
F1 all keys"""

const HELP_TEXT := """W/S   throttle / brake, reverse
A/D   steer       SPACE  handbrake
Q     all-wheel drive 4x4
X     differential lock
G     low range
H     headlights   R  flip upright
E     load, unload, refuel, build;
      step across to a parked truck
P     place a building, wheel - turn
TAB   garage, at the railhead
C     hitch / unhitch a trailer
B/V   tractor: dig / tip the tipper
F     aim the winch, Shift reel
M     map
T     tow to the railhead
RMB   camera, wheel - zoom
F1    hide help  ESC title"""

var vehicle: Vehicle
var contracts: Contracts
var fleet: Fleet  # what E does beside a parked truck (scripts/main.gd sets it)
var infra: Infra  # set after setup: its prompt, its lists

var _status: Label
var _objective: Label
var _prompt: Label
var _message: Label
var _help: Label
var _hint: Label
var _board: Label
var _board_bg: ColorRect
var _message_time := 0.0
var help := Help.HINT


func setup(v: Vehicle, c: Contracts) -> void:
	vehicle = v
	contracts = c
	layer = 2
	var size := get_viewport().get_visible_rect().size
	_status = _make_label(Vector2(6, 4), Vector2(260, 40), HORIZONTAL_ALIGNMENT_LEFT)
	_objective = _make_label(Vector2(0, size.y - 34), Vector2(size.x, 12), HORIZONTAL_ALIGNMENT_CENTER)
	_prompt = _make_label(Vector2(0, size.y - 18), Vector2(size.x, 12), HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_message = _make_label(Vector2(20, 60), Vector2(size.x - 40, 24), HORIZONTAL_ALIGNMENT_CENTER)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # a long one takes two lines
	_board_bg = ColorRect.new()
	_board_bg.color = Color(0.0, 0.0, 0.0, 0.72)
	_board_bg.position = Vector2(20, 78)
	_board_bg.size = Vector2(size.x - 40, 96)
	_board_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_bg.visible = false
	add_child(_board_bg)
	_board = _make_label(Vector2(28, 82), Vector2(size.x - 56, 88), HORIZONTAL_ALIGNMENT_LEFT)
	_board.visible = false
	_message.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	_help = _make_label(Vector2(size.x - 196, 4), Vector2(190, 184), HORIZONTAL_ALIGNMENT_LEFT)
	_help.text = HELP_TEXT
	_hint = _make_label(Vector2(size.x - 146, 4), Vector2(140, 40), HORIZONTAL_ALIGNMENT_LEFT)
	_hint.text = HINT_TEXT
	set_help(help)
	contracts.message.connect(show_message)


## F1: the hint, then the full card, then nothing, then the hint again.
func toggle_help() -> void:
	set_help(((help + 1) % Help.size()) as Help)


func set_help(mode: Help) -> void:
	help = mode
	_hint.visible = mode == Help.HINT
	_help.visible = mode == Help.FULL


func show_message(text: String) -> void:
	_message.text = text
	_message_time = 4.0


func _process(delta: float) -> void:
	if vehicle == null:
		return
	var fuel_bars := roundi(vehicle.fuel / vehicle.spec.fuel_capacity * 10.0)
	_status.text = "%3d km/h  %s  %s  DIFF:%s\nFUEL %s%s %2d L  %d%%\n%s" % [
		roundi(absf(vehicle.forward_speed) * 3.6),
		"LOW " if vehicle.low_range else "HIGH",
		_drive_text(),
		"LOCK" if vehicle.diff_lock else "OPEN",
		"█".repeat(fuel_bars),
		"░".repeat(10 - fuel_bars),
		roundi(vehicle.fuel),
		roundi(vehicle.condition * 100.0),
		Loads.text(vehicle),
	]
	if vehicle.flooded:
		_status.text += "\nENGINE FLOODED"
	elif vehicle.water_depth > 0.05:  # the water against the intake (docs/plan.md §8)
		var intake := vehicle.water_depth - vehicle.water_over_intake if vehicle.water_over_intake > -INF else 0.0
		_status.text += "\nWATER %.1f / %.1f m%s" % [vehicle.water_depth, intake, "  !" if vehicle.water_over_intake > -0.25 else ""]
	if vehicle.load_text() != "":
		_status.text += "\n" + vehicle.load_text()
	if vehicle.winch.attached:
		_status.text += "\nWINCH %4.1f m  pull %2d kN%s" % [
			vehicle.winch.length, roundi(vehicle.winch.tension / 1000.0), "  <<" if vehicle.winch.reeling else ""]
	var loader := vehicle.get_node_or_null("Loader") as Loader
	if loader:  # the tractor's bucket and tipper, and the m³ shifted (docs/plan.md §4, §9)
		_status.text += "\n%s  SHIFTED %d m3" % [loader.status(), roundi(loader.land.earthworks.shifted)]
	_objective.text = contracts.objective_text()
	var board := contracts.garage_text() if contracts.garage_open else (infra.panel if infra else "")
	_board.visible = board != ""
	_board_bg.visible = board != ""
	if _board.visible:
		_board.text = board
	# What E does here: a building or site first, then the garage and tow, then a parked truck.
	var said := infra.prompt if infra and infra.prompt != "" else contracts.prompt
	if said == "" and fleet:
		said = fleet.prompt()
	_prompt.text = vehicle.prompt_with(said)
	_message_time -= delta
	_message.visible = _message_time > 0.0


## The drive in play as its wheels and the driven ones: 4x2, 4x4, 6x4, 6x6.
func _drive_text() -> String:
	var driven := 0
	for w in vehicle.wheels:
		if vehicle.awd or w.drive2:
			driven += 1
	return "%dx%d" % [vehicle.wheels.size(), driven]


func _make_label(pos: Vector2, size: Vector2, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Psx.font())
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color(0.95, 0.95, 0.9))
	l.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	add_child(l)
	return l
