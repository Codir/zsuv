class_name TitleScreen
extends CanvasLayer
## The title: ZSUV over a still of the steppe, and two ways in. Continue (only when there is a
## save) goes back to it; New game starts over, and asks first when that would wipe a save.
## W/S or the arrows pick, Enter goes, Esc says no to the question or quits (not in a browser);
## the mouse works too.

signal start(fresh: bool)

const INK := Color(0.95, 0.95, 0.9)
const GOLD := Color(1.0, 0.85, 0.3)
const DIM := Color(0.72, 0.73, 0.76)
const STILL := "res://images/title.png"

var can_continue := false
var index := 0
var asking := false  # "Start over?" is on screen

var _items: Array[Label] = []
var _question: Label
var _answer: Label
var _busy := false


func _ready() -> void:
	layer = 10
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if ResourceLoader.exists(STILL):
		var still := TextureRect.new()
		still.texture = load(STILL)
		still.set_anchors_preset(Control.PRESET_FULL_RECT)
		still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		still.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		still.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(still)
	# A dark band down the left for the words to stand on.
	var band := ColorRect.new()
	band.color = Color(0.05, 0.05, 0.08, 0.72)
	band.position = Vector2(0, 0)
	band.size = Vector2(200, 270)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var title := _label(Vector2(20, 36), Vector2(170, 40), "ZSUV", GOLD)
	title.add_theme_font_size_override("font_size", 34)
	_label(Vector2(20, 80), Vector2(170, 14), "Shift the land.", INK)
	_label(Vector2(20, 94), Vector2(170, 14), "Reopen the valley.", INK)
	for i in 2:
		var item := _label(Vector2(20, 140 + i * 18), Vector2(170, 14), "", INK)
		item.mouse_filter = Control.MOUSE_FILTER_STOP
		item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var at := i
		item.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_click(at))
		_items.append(item)
	_question = _label(Vector2(20, 184), Vector2(176, 28), "", GOLD)
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD
	_answer = _label(Vector2(20, 212), Vector2(176, 14), "", INK)
	var hints := "W/S pick   ENTER go"
	if not OS.has_feature("web"):
		hints += "   ESC quit"
	_label(Vector2(20, 246), Vector2(176, 14), hints, DIM)
	_label(Vector2(204, 252), Vector2(270, 14), "Game Off 2026 · built on Khutir Road", DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	index = 0 if can_continue else 1
	_refresh()


## The lines on offer, top to bottom: "Continue" (when there is a save) and "New game".
func choices() -> PackedStringArray:
	return PackedStringArray(["Continue", "New game"]) if can_continue else PackedStringArray(["", "New game"])


func pick(by: int) -> void:
	if asking or not can_continue:
		return
	index = wrapi(index + by, 0, 2)
	_refresh()


## Enter: the line picked; on the question, yes.
func go() -> void:
	if _busy:
		return
	if asking:
		await _begin(true)
	elif index == 0:
		await _begin(false)
	elif can_continue:
		asking = true
		_refresh()
	else:
		await _begin(true)


## Esc on the question: no.
func cancel() -> void:
	asking = false
	_refresh()


func _begin(fresh: bool) -> void:
	_busy = true
	asking = false
	_refresh()
	_answer.text = "Loading..."
	# Building the world takes a moment: show that before it starts.
	await get_tree().process_frame
	await get_tree().process_frame
	start.emit(fresh)


func _click(at: int) -> void:
	if asking or (at == 0 and not can_continue):
		return
	index = at
	_refresh()
	go()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).physical_keycode:
		KEY_W, KEY_UP:
			pick(-1)
		KEY_S, KEY_DOWN:
			pick(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_E, KEY_SPACE:
			go()
		KEY_ESCAPE:
			if asking:
				cancel()
			elif not OS.has_feature("web"):
				get_tree().quit()
		_:
			return
	get_viewport().set_input_as_handled()


func _refresh() -> void:
	var names := choices()
	for i in _items.size():
		_items[i].visible = names[i] != ""
		var on := i == index and not asking
		_items[i].text = ("> " if on else "  ") + names[i].to_upper()
		_items[i].add_theme_color_override("font_color", GOLD if on else INK)
	_question.text = "Start over? The saved game will be lost." if asking else ""
	_answer.text = "[ENTER] Yes   [ESC] No" if asking else ""


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
