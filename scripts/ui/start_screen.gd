class_name StartScreen
extends CanvasLayer
## The valleys: a picture of each and a card of what awaits there (its sky, how hard, its ground,
## where the deliveries go, what it costs), a sky to pick, and the way in. They open in order,
## bought with the money earned. A/D or the arrows pick a valley, W/S its sky, Enter drives or buys.

signal drive(valley: Valley, kind: Weather.Kind)

const BG := Color(0.07, 0.08, 0.11)
const INK := Color(0.95, 0.95, 0.9)
const GOLD := Color(1.0, 0.85, 0.3)
const DIM := Color(0.6, 0.62, 0.66)
const PREVIEW := Vector2(240, 135)

var profile := Profile.new()
var valleys := Valley.all()
var index := 0
var message := ""

var _picture: TextureRect
var _no_picture: Label
var _title: Label
var _sky: Label
var _card: Label
var _action: Label
var _money: Label
var _count: Label
var _busy := false


func _ready() -> void:
	layer = 10
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var head := _label(Vector2(12, 6), Vector2(240, 14), "KHUTIR ROAD", GOLD)
	head.add_theme_font_size_override("font_size", 12)
	_money = _label(Vector2(250, 6), Vector2(218, 14), "", INK, HORIZONTAL_ALIGNMENT_RIGHT)
	var frame := ColorRect.new()
	frame.color = Color(0.2, 0.21, 0.24)
	frame.position = Vector2(10, 26)
	frame.size = PREVIEW + Vector2(4, 4)
	add_child(frame)
	_picture = TextureRect.new()
	_picture.position = Vector2(12, 28)
	_picture.size = PREVIEW
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_picture)
	_no_picture = _label(Vector2(12, 90), Vector2(PREVIEW.x, 14), "no picture yet", DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_title = _label(Vector2(264, 26), Vector2(170, 14), "", GOLD)
	_count = _label(Vector2(430, 26), Vector2(38, 14), "", DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_card = _label(Vector2(264, 42), Vector2(206, 124), "", INK)
	_card.autowrap_mode = TextServer.AUTOWRAP_WORD
	var prev := _label(Vector2(12, 170), Vector2(50, 14), "< A", INK)
	var next := _label(Vector2(202, 170), Vector2(50, 14), "D >", INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(Vector2(62, 170), Vector2(140, 14), "valley", DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_sky = _label(Vector2(12, 190), Vector2(456, 14), "", INK)
	_action = _label(Vector2(12, 214), Vector2(456, 14), "", GOLD)
	var hints := "A/D valley   W/S sky   ENTER drive / buy"
	if not OS.has_feature("web"):
		hints += "   ESC quit"
	_label(Vector2(12, 252), Vector2(456, 14), hints, DIM)
	_clickable(prev, func() -> void: step(-1))
	_clickable(next, func() -> void: step(1))
	_clickable(_sky, func() -> void: step_sky(1))
	_clickable(_action, go)
	for i in valleys.size():
		if valleys[i].id == profile.last:
			index = i
	_refresh()


func valley() -> Valley:
	return valleys[index]


func step(by: int) -> void:
	index = wrapi(index + by, 0, valleys.size())
	message = ""
	_refresh()


func step_sky(by: int) -> void:
	var v := valley()
	profile.set_sky(v.id, wrapi(profile.sky(v.id) + by, 0, Weather.Kind.size()) as Weather.Kind)
	_refresh()


## Enter: drive into the valley if it is owned, buy it if it can be.
func go() -> void:
	if _busy:
		return
	var v := valley()
	if profile.owns(v.id):
		_busy = true
		_action.text = "Loading %s..." % v.title
		# Building a valley takes a moment: show that before it starts.
		await get_tree().process_frame
		await get_tree().process_frame
		drive.emit(v, profile.sky(v.id))
	elif profile.buy(v):
		message = "%s is yours. Drive safe!" % v.title
	else:
		message = "Not yet: " + profile.cannot_buy(v)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).physical_keycode:
		KEY_A, KEY_LEFT:
			step(-1)
		KEY_D, KEY_RIGHT:
			step(1)
		KEY_W, KEY_UP:
			step_sky(-1)
		KEY_S, KEY_DOWN:
			step_sky(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_SPACE:
			go()
		KEY_ESCAPE:
			if not OS.has_feature("web"):
				get_tree().quit()
		_:
			return
	get_viewport().set_input_as_handled()


func _refresh() -> void:
	var v := valley()
	var path := "res://previews/%s.png" % v.id
	_picture.texture = load(path) if ResourceLoader.exists(path) else null
	_no_picture.visible = _picture.texture == null
	_picture.modulate = Color.WHITE if profile.owns(v.id) else Color(0.55, 0.55, 0.6)
	_title.text = v.title.to_upper()
	_count.text = "%d/%d" % [index + 1, valleys.size()]
	_money.text = "$ %d" % profile.money
	var places := PackedStringArray()
	for loc in v.locations.values():
		if loc.has("cargo"):
			places.append(loc.name)
	_card.text = "%s\n%s  %s\n\n%s\n\nDeliveries: %s.\nJobs pay x%.1f." % [
		v.own.name.capitalize(), "*".repeat(v.stars) + "-".repeat(5 - v.stars), ["", "easy", "fair", "hard", "harder", "hardest"][v.stars],
		v.blurb, ", ".join(places), v.pay]
	var kind := profile.sky(v.id)
	_sky.text = "Sky  < %s >   (W/S)" % ("its own: " + v.own.name if kind == Weather.Kind.OWN else Weather.label(kind, v))
	var why := profile.cannot_buy(v)
	if why == "owned":
		_action.text = "[ENTER] Drive"
	elif why == "":
		_action.text = "[ENTER] Buy for $%d" % v.price
	else:
		_action.text = "Locked: $%d. %s" % [v.price, why[0].to_upper() + why.substr(1)]
	if message != "":
		_action.text += "   " + message


func _label(pos: Vector2, size: Vector2, text: String, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = size
	l.text = text
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Psx.font())
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", color)
	add_child(l)
	return l


func _clickable(l: Label, call: Callable) -> void:
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	l.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			call.call())
