class_name Hud
extends CanvasLayer
## Приладова панель, поточне завдання, підказки й довідка по керуванню.

const HELP_TEXT := """W/S   газ / гальмо, задній хід
A/D   кермо       SPACE  ручник
Q     повний привід 4x4
X     блокування диференціала
G     понижена передача
H     фари         R  на колеса
E     завантажити / заправитись
F     лебідка, Shift - намотати
M     мапа
T     евакуація в депо
ПКМ   камера, коліщатко - зум
F1    сховати довідку"""

var vehicle: Vehicle
var contracts: Contracts

var _status: Label
var _objective: Label
var _prompt: Label
var _message: Label
var _help: Label
var _message_time := 0.0


func setup(v: Vehicle, c: Contracts) -> void:
	vehicle = v
	contracts = c
	layer = 2
	var size := get_viewport().get_visible_rect().size
	_status = _make_label(Vector2(6, 4), Vector2(260, 40), HORIZONTAL_ALIGNMENT_LEFT)
	_objective = _make_label(Vector2(0, size.y - 34), Vector2(size.x, 12), HORIZONTAL_ALIGNMENT_CENTER)
	_prompt = _make_label(Vector2(0, size.y - 18), Vector2(size.x, 12), HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_message = _make_label(Vector2(0, 60), Vector2(size.x, 12), HORIZONTAL_ALIGNMENT_CENTER)
	_message.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	_help = _make_label(Vector2(size.x - 196, 4), Vector2(190, 150), HORIZONTAL_ALIGNMENT_LEFT)
	_help.text = HELP_TEXT
	contracts.message.connect(show_message)


func toggle_help() -> void:
	_help.visible = not _help.visible


func show_message(text: String) -> void:
	_message.text = text
	_message_time = 4.0


func _process(delta: float) -> void:
	if vehicle == null:
		return
	var fuel_bars := roundi(vehicle.fuel / Vehicle.FUEL_CAPACITY * 10.0)
	_status.text = "%3d км/год  %s  %s  ДИФ:%s\nПАЛЬНЕ %s%s %2d л\n$ %d%s" % [
		roundi(absf(vehicle.forward_speed) * 3.6),
		"LOW " if vehicle.low_range else "HIGH",
		"4x4" if vehicle.awd else "4x2",
		"LOCK" if vehicle.diff_lock else "OPEN",
		"█".repeat(fuel_bars),
		"░".repeat(10 - fuel_bars),
		roundi(vehicle.fuel),
		contracts.money,
		"   ВАНТАЖ" if vehicle.has_cargo else "",
	]
	if vehicle.winch.attached:
		_status.text += "\nЛЕБІДКА %4.1f м  натяг %2d кН%s" % [
			vehicle.winch.length, roundi(vehicle.winch.tension / 1000.0), "  <<" if vehicle.winch.reeling else ""]
	_objective.text = contracts.objective_text()
	_prompt.text = contracts.prompt if contracts.prompt != "" else vehicle.winch.prompt()
	_message_time -= delta
	_message.visible = _message_time > 0.0


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
