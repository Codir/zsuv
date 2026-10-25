class_name Psx
extends RefCounted
## Helpers for PSX materials, simple meshes and the pixel font.

const LIT_SHADER := preload("res://shaders/psx_lit.gdshader")
const FONT := preload("res://fonts/Inconsolata-Variable.ttf")

static var _materials := {}
static var _font: FontFile


static func mat(color: Color, emission := 0.0, noise := 0.1) -> ShaderMaterial:
	var key := "%s_%s_%s" % [color.to_html(), emission, noise]
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = LIT_SHADER
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("emission_strength", emission)
	m.set_shader_parameter("noise_amount", noise)
	_materials[key] = m
	return m


static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return mesh(parent, bm, pos, color, emission)


static func mesh(parent: Node3D, m: Mesh, pos: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat(color, emission)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func cylinder(top: float, bottom: float, height: float, segments := 8) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	return cm


## Inconsolata, bundled (fonts/OFL.txt): the Web build has no system fonts, and Linux and
## macOS have no Consolas, so every build draws the same crisp, unsmoothed pixels.
static func font() -> FontFile:
	if _font == null:
		_font = FONT
		_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_font.hinting = TextServer.HINTING_NORMAL
		_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return _font
