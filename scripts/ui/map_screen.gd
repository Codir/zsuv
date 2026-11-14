class_name MapScreen
extends CanvasLayer
## Paper map on M: relief with contour lines, roads, snow/mud, forest,
## delivery points, the current target, the truck and the trail behind it.

const MAP_SIZE := 240.0
const PAPER := Color(0.93, 0.88, 0.76)
const INK := Color(0.22, 0.17, 0.12)
const TRAIL_STEP := 3.0
const TRAIL_MAX := 3000

var land: Land
var terrain: Terrain  # the tile drawn: the home biome's
var vehicle: Vehicle
var contracts: Contracts
var locations: Dictionary

var _canvas: Control
var _tex: ImageTexture
var _origin := Vector2.ZERO
var _trail := PackedVector2Array()


func setup(l: Land, v: Vehicle, c: Contracts, locs: Dictionary, trees: PackedVector2Array) -> void:
	land = l
	terrain = l.home
	vehicle = v
	contracts = c
	locations = locs
	layer = 3
	visible = false
	_tex = ImageTexture.create_from_image(_render_image(trees))
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)


func toggle() -> void:
	visible = not visible


func _process(_delta: float) -> void:
	if vehicle == null:
		return
	var p := Vector2(vehicle.global_position.x, vehicle.global_position.z)
	if _trail.is_empty() or _trail[_trail.size() - 1].distance_to(p) > TRAIL_STEP:
		_trail.append(p)
		if _trail.size() > TRAIL_MAX:
			_trail.remove_at(0)
	if visible:
		_canvas.queue_redraw()


func _to_map(p: Vector2) -> Vector2:
	return _origin + (p + Vector2(Terrain.HALF, Terrain.HALF)) / Terrain.SIZE * MAP_SIZE


func _on_draw() -> void:
	var vp := _canvas.size
	var font := Psx.font()
	_origin = Vector2(16.0, (vp.y - MAP_SIZE) * 0.5)
	_canvas.draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.6))
	_canvas.draw_rect(Rect2(_origin - Vector2(5, 5), Vector2.ONE * (MAP_SIZE + 10.0)), PAPER)
	_canvas.draw_texture_rect(_tex, Rect2(_origin, Vector2.ONE * MAP_SIZE), false)
	_canvas.draw_rect(Rect2(_origin, Vector2.ONE * MAP_SIZE), INK, false, 1.0)

	# The trail driven so far.
	if _trail.size() > 1:
		var pts := PackedVector2Array()
		for p in _trail:
			pts.append(_to_map(p))
		_canvas.draw_polyline(pts, Color(0.95, 0.45, 0.1, 0.85), 1.0)

	# Locations.
	var target := contracts.current_target()
	for loc in locations.values():
		var mp := _to_map(loc.pos)
		var is_target: bool = loc == target
		_canvas.draw_rect(Rect2(mp - Vector2(3, 3), Vector2(6, 6)), Color(0.9, 0.7, 0.1) if is_target else INK)
		var label: String = loc.name
		var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var label_pos := mp + Vector2(6, 4)
		if label_pos.x + label_w > _origin.x + MAP_SIZE:
			label_pos.x = mp.x - 6.0 - label_w  # near the right edge: label goes on the left
		_text(font, label_pos, label, Color(1.0, 0.95, 0.85))

	# A pulsing ring around the target.
	var t := Time.get_ticks_msec() / 1000.0
	_canvas.draw_arc(_to_map(target.pos), 8.0 + sin(t * 5.0) * 2.0, 0.0, TAU, 20, Color(1.0, 0.85, 0.2), 1.5)

	# The truck: an arrow pointing where it is heading.
	var f := -vehicle.global_transform.basis.z
	var d := Vector2(f.x, f.z).normalized()
	var s := Vector2(-d.y, d.x)
	var vp_map := _to_map(Vector2(vehicle.global_position.x, vehicle.global_position.z))
	var arrow := PackedVector2Array([vp_map + d * 7.0, vp_map - d * 4.0 + s * 4.5, vp_map - d * 1.5, vp_map - d * 4.0 - s * 4.5])
	_canvas.draw_colored_polygon(arrow, Color(0.95, 0.25, 0.15))
	_canvas.draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0.1, 0.05, 0.0), 1.0)

	# Right column: title, objective, legend.
	var x := _origin.x + MAP_SIZE + 18.0
	var y := _origin.y + 4.0
	_text(font, Vector2(x, y + 8), terrain.valley.title.to_upper(), Color(1.0, 0.85, 0.3))
	y += 26.0
	for line in _wrap(contracts.objective_text(), 36):
		_text(font, Vector2(x, y), line, Color(1.0, 1.0, 1.0))
		y += 12.0
	y += 12.0
	var v := terrain.valley
	var legend := [
		[Color(0.95, 0.25, 0.15), "your truck"],
		[Color(0.9, 0.7, 0.1), "target"],
		[Color(0.95, 0.45, 0.1), "your trail"],
		[Color(0.38, 0.33, 0.28), "road"],
		[Color(0.42, 0.3, 0.2), "mud"],
	]
	if v.layer != "dust":
		legend.append([v.layer_color, "deep " + v.layer])
	for ft in v.features:
		if ft.get("ice", false):
			legend.append([v.ice_color, "ice"])
	legend.append([Color(0.2, 0.32, 0.22), "trees"])
	for item in legend:
		_canvas.draw_rect(Rect2(Vector2(x, y - 7), Vector2(8, 8)), item[0])
		_text(font, Vector2(x + 13, y), item[1], Color(0.9, 0.9, 0.85))
		y += 13.0
	_text(font, Vector2(x, _origin.y + MAP_SIZE), "[M] close", Color(0.7, 0.7, 0.65))


func _text(font: Font, pos: Vector2, text: String, color: Color) -> void:
	_canvas.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0.0, 0.0, 0.0, 0.9))
	_canvas.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)


func _wrap(text: String, width: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" ", false):
		if line.length() + word.length() + 1 > width and line != "":
			lines.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		lines.append(line)
	return lines


## Draws the map once at startup: shaded relief + contour lines + ground cover.
func _render_image(trees: PackedVector2Array) -> Image:
	var n := Terrain.SIZE
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var h := terrain.heights
	var stride := Terrain.N
	var v := terrain.valley
	for z in n:
		for x in n:
			var i := z * stride + x
			var hz := h[i]
			var nw := h[maxi(z - 1, 0) * stride + maxi(x - 1, 0)]
			var se := h[mini(z + 1, n) * stride + mini(x + 1, n)]
			var shade := clampf(0.85 + (nw - se) * 0.08, 0.55, 1.15)
			var c := terrain.snow_img.get_pixel(x, z)
			var col := Color(0.62, 0.55, 0.45)
			if v.layer != "dust":
				col = col.lerp(v.layer_color, clampf(c.r * 1.6, 0.0, 1.0))
			col = col.lerp(Color(0.42, 0.3, 0.2), c.g)
			col = col.lerp(Color(0.38, 0.33, 0.28), c.b)
			col = col.lerp(v.ice_color, 1.0 - c.a)
			col = Color(col.r * shade, col.g * shade, col.b * shade)
			# A contour line every 3 m.
			var band := floori(hz / 3.0)
			if band != floori(h[i + 1] / 3.0) or band != floori(h[i + stride] / 3.0):
				col = col.lerp(INK, 0.35)
			img.set_pixel(x, z, col * PAPER)
	for p in trees:
		var px := clampi(int(p.x + Terrain.HALF), 0, n - 2)
		var pz := clampi(int(p.y + Terrain.HALF), 0, n - 2)
		img.fill_rect(Rect2i(px, pz, 2, 2), Color(0.2, 0.32, 0.22))
	return img
