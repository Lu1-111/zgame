@tool
class_name SkeletalWeapon
extends Node2D
## 骨骼测试武器。只绘制武器，人物始终由原素材的 Polygon2D 蒙皮显示。

@export_enum("sword", "rifle", "hammer", "staff") var kind := "sword":
	set(value):
		kind = value
		queue_redraw()

var _motion: Dictionary = {}
var _settings: Dictionary = {}

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_load_settings()
	queue_redraw()

## 从数值表读取样式，切换武器时不替换人物贴图。
func configure(weapon: String, settings: Dictionary = {}) -> void:
	if _motion.is_empty():
		_load_settings()
	if not settings.is_empty():
		_settings = settings
	kind = weapon

## 返回武器本地空间的枪口或施法端点。
func muzzle_local_position() -> Vector2:
	if _settings.is_empty():
		_load_settings()
	var runtime: Dictionary = _settings.get("runtime", {})
	if kind == "rifle":
		return Vector2(float(runtime.get("rifle_barrel", 0)), 0)
	var shapes: Dictionary = _settings.get("weapon_shapes", {})
	if kind == "staff":
		return Vector2(float(shapes.get("staff", {}).get("length", 0)), 0)
	if kind == "hammer":
		return _vec(shapes.get("hammer", {}).get("head_offset", [0, 0]))
	return Vector2(float(_motion.get("sword", {}).get("length", 0)), 0)

func _load_settings() -> void:
	_motion = _read_json("res://data/hero_motion.json")
	_settings = _read_json("res://data/skeleton_test.json")

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _draw() -> void:
	if _settings.is_empty() or _motion.is_empty():
		return
	match kind:
		"rifle": _draw_rifle()
		"hammer": _draw_hammer()
		"staff": _draw_staff()
		_: _draw_sword()

func _draw_sword() -> void:
	var s: Dictionary = _motion.get("sword", {})
	if s.is_empty():
		return
	var blade_length := float(s.length)
	var hilt := float(s.hilt)
	var guard := float(s.guard)
	var point := Vector2(blade_length, 0)
	draw_colored_polygon(PackedVector2Array([Vector2(2, -2), Vector2(5, -2), point, Vector2(5, 2), Vector2(2, 2)]), Color(s.shadow))
	draw_colored_polygon(PackedVector2Array([Vector2(2, 0), Vector2(5, -1), point, Vector2(5, 1)]), Color(s.steel))
	draw_line(Vector2(2, -2), point, Color(s.edge), 1, false)
	draw_line(Vector2(2, 0), Vector2(blade_length - 5, 0), Color(s.steel), 1, false)
	draw_line(Vector2(0, -guard), Vector2(0, guard), Color(s.shadow), 3, false)
	draw_line(Vector2(0, -guard), Vector2(0, guard), Color(s.gold), 1, false)
	draw_line(Vector2(-hilt, 0), Vector2.ZERO, Color(s.grip), 3, false)
	for index in 3:
		var center := Vector2(-3 - index * 2, 0)
		draw_line(center - Vector2.DOWN, center + Vector2.DOWN, Color(s.gold), 1, false)
	draw_rect(Rect2(Vector2(-hilt - 2, -1), Vector2(3, 3)), Color(s.gold))

func _draw_rifle() -> void:
	var r: Dictionary = _motion.get("rifle", {})
	if r.is_empty():
		return
	var barrel := float(_settings.runtime.rifle_barrel)
	draw_colored_polygon(PackedVector2Array([Vector2(-12, -1), Vector2(-8, -2), Vector2(-2, 0), Vector2(8, 0), Vector2(8, 4), Vector2(-3, 3), Vector2(-9, 5), Vector2(-12, 4)]), Color(r.wood))
	draw_line(Vector2(-11, 4), Vector2(-3, 2), Color(r.wood_light), 1, false)
	draw_line(Vector2(-2, -1), Vector2(barrel, -1), Color(r.dark), 4, false)
	draw_line(Vector2(-2, -2), Vector2(barrel, -2), Color(r.steel), 2, false)
	draw_line(Vector2(3, -3), Vector2(barrel, -3), Color(r.highlight), 1, false)
	draw_line(Vector2(6, 2), Vector2(14, 2), Color(r.wood_light), 2, false)
	draw_line(Vector2(-1, -4), Vector2(3, -4), Color(r.highlight), 1, false)
	draw_line(Vector2(barrel - 3, -4), Vector2(barrel - 3, -2), Color(r.dark), 1, false)

func _draw_hammer() -> void:
	var h: Dictionary = _settings.get("weapon_shapes", {}).get("hammer", {})
	if h.is_empty():
		return
	var center := _vec(h.head_offset)
	var size := _vec(h.head_size)
	draw_line(Vector2(-float(h.handle_length), 0), center, Color(h.wood), 3, false)
	draw_rect(Rect2(center - size * 0.5, size), Color(h.cap))
	draw_rect(Rect2(center - size * 0.5 + Vector2.ONE, size - Vector2.ONE * 2), Color(h.cream))
	draw_rect(Rect2(center + Vector2(-size.x * 0.5, -size.y * 0.5), Vector2(size.x, 2)), Color(h.cap))

func _draw_staff() -> void:
	var s: Dictionary = _settings.get("weapon_shapes", {}).get("staff", {})
	if s.is_empty():
		return
	var tip := Vector2(float(s.length), 0)
	var radius := float(s.gem_size) * 0.5
	draw_line(Vector2(-radius, 0), tip, Color(s.wood), 3, false)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(radius, 0), tip + Vector2(0, -radius), tip - Vector2(radius, 0), tip + Vector2(0, radius)]), Color(s.gem))

func _vec(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))
