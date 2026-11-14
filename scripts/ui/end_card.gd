class_name EndCard
extends CanvasLayer
## The end (docs/plan.md §9): the upper village has its fuel and parts, and a card says "The valley
## is open", with what it took: the m3 shifted, the bridges and buildings, the trees felled, the
## fuel burnt and the time played. Esc closes it, and play goes on.

var text := ""  # what the card says, for the tests

var _bg: ColorRect
var _label: Label


func _ready() -> void:
	layer = 4
	visible = false
	_bg = ColorRect.new()
	_bg.color = Color(0.0, 0.0, 0.0, 0.78)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", Psx.font())
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	add_child(_label)


## Shows the card with main's counts (Infra.stats, the earthworks).
func open(main: Node) -> void:
	var infra: Infra = main.infra
	var st: Dictionary = infra.stats
	var shifted := 0.0
	if main.land and main.land.earthworks:
		shifted = main.land.earthworks.shifted
	var played := int(st.get("played", 0.0))
	var lines := PackedStringArray([
		"THE VALLEY IS OPEN",
		"",
		"The upper village has its fuel and parts.",
		"",
		"Earth shifted      %d m3" % roundi(shifted),
		"Road built         %d m" % roundi(float(st.get("road_m", 0.0))),
		"Bridges            %d" % int(st.get("bridges", 0)),
		"Buildings          %d" % int(st.get("buildings", 0)),
		"Trees felled       %d" % int(st.get("trees_felled", 0)),
		"Fuel burnt         %d L" % roundi(float(st.get("fuel_burnt", 0.0))),
		"Time played        %d:%02d" % [played / 3600, (played / 60) % 60],
		"",
		"[Esc] play on",
	])
	text = "\n".join(lines)
	_label.text = text
	visible = true


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()
