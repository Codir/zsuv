class_name StartScreen
extends CanvasLayer
## The valleys: a picture of each and a card of what awaits there, in icons (its season and sky,
## how hard, the depot and the places to deliver to; the mouse over one names it) and a line of
## words, a sky to pick, and the way in. They open in order, bought with the money earned. A/D or
## the arrows pick a valley, W/S its sky, Enter drives or buys.

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
var _sky_icons: Control
var _sky_end: Label
var _card: Label
var _weather: Control
var _peaks: Control
var _places: Control
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
	var head := _label(Vector2(12, 6), Vector2(240, 14), "ZSUV", GOLD)
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
	_weather = _row(Vector2(264, 44))
	_peaks = _row(Vector2(264, 62))
	_card = _label(Vector2(264, 80), Vector2(206, 56), "", INK)
	_card.autowrap_mode = TextServer.AUTOWRAP_WORD
	_places = _row(Vector2(264, 126))
	var prev := _label(Vector2(12, 170), Vector2(50, 14), "< A", INK)
	var next := _label(Vector2(202, 170), Vector2(50, 14), "D >", INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(Vector2(62, 170), Vector2(140, 14), "valley", DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_sky = _label(Vector2(12, 190), Vector2(40, 14), "Sky  <", INK)
	_sky_icons = _row(Vector2(52, 191))
	_sky_end = _label(Vector2(100, 190), Vector2(300, 14), "", INK)
	_action = _label(Vector2(12, 214), Vector2(456, 14), "", GOLD)
	var hints := "A/D valley   W/S sky   ENTER drive / buy"
	if not OS.has_feature("web"):
		hints += "   ESC quit"
	_label(Vector2(12, 252), Vector2(456, 14), hints, DIM)
	_clickable(prev, func() -> void: step(-1))
	_clickable(next, func() -> void: step(1))
	_clickable(_sky, func() -> void: step_sky(-1))
	_clickable(_sky_end, func() -> void: step_sky(1))
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
	_card.text = v.blurb
	_icons(_weather, Icons.sky(v.own, v.season, true), [v.season, v.own.name])
	var peaks: Array[Texture2D] = []
	var hard: String = ["", "easy", "fair", "hard", "harder", "hardest"][v.stars]
	for i in 5:
		peaks.append(Icons.peak(i < v.stars))
	_icons(_peaks, peaks, ["difficulty: " + hard])
	var places: Array[Texture2D] = []
	var names: Array[String] = []
	for loc in v.locations.values():
		places.append(Icons.place(loc.kind))
		names.append(loc.name if loc.has("cargo") else "%s: the depot" % loc.name)
	_icons(_places, places, names)
	var kind := profile.sky(v.id)
	var w := Weather.make(kind, v)
	var sky_name := ("its own: " + v.own.name) if kind == Weather.Kind.OWN else Weather.label(kind, v)
	_icons(_sky_icons, Icons.sky(w, v.season), [sky_name])
	_sky_end.position.x = _sky_icons.position.x + _sky_icons.get_child_count() * 16.0 + 2.0
	_sky_end.text = ">   (W/S)"
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


## A row of icons under pos.
func _row(pos: Vector2) -> Control:
	var row := Control.new()
	row.position = pos
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var t := Theme.new()
	t.default_font = Psx.font()
	t.default_font_size = 10
	row.theme = t
	add_child(row)
	return row


## Fills row with textures 16 px apart; each names itself in tips (the last tip for the rest)
## when the mouse is over it.
func _icons(row: Control, textures: Array[Texture2D], tips: Array) -> void:
	for c in row.get_children():
		c.free()
	for i in textures.size():
		var r := TextureRect.new()
		r.texture = textures[i]
		r.position = Vector2(i * 16.0, 0.0)
		r.size = Vector2(Icons.SIZE, Icons.SIZE)
		r.tooltip_text = tips[mini(i, tips.size() - 1)]
		r.mouse_filter = Control.MOUSE_FILTER_STOP
		row.add_child(r)


func _clickable(l: Label, call: Callable) -> void:
	l.mouse_filter = Control.MOUSE_FILTER_STOP
	l.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	l.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			call.call())
