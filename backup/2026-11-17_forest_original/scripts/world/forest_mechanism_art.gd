extends Node2D
## 古根机关的石座、绿晶和封印栅；数值与色板统一来自该地图的美术表。

@export var kind := "switch"
@export var gate_size := Vector2.ZERO
@export var horizontal := false
var activated := false:
	set(value):
		activated = value
		var art := get_node_or_null("RuinSwitchSprite") as Sprite2D
		if art != null and not _style.is_empty():
			art.modulate = Color(_style.activated_tint if activated else _style.switch_tint)
		queue_redraw()
var _style: Dictionary
var _stone: Texture2D


func _ready() -> void:
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/forest_02_art.json"))
	_style = art.mechanism
	_stone = load(art.wall.texture)
	queue_redraw()


func _draw() -> void:
	if _style.is_empty():
		return
	var green := Color(_style.opened if activated else _style.active)
	var metal := Color(_style.metal)
	var width := float(_style.line_width)
	if kind == "switch" and has_node("RuinSwitchSprite"):
		return
	if kind == "switch":
		var size := Vector2(_style.switch_size[0], _style.switch_size[1])
		var base := Rect2(Vector2(-size.x / 2.0, -size.y * 0.56), Vector2(size.x, size.y * 0.56))
		draw_texture_rect_region(_stone, base, Rect2(Vector2.ZERO, size), Color(_style.stone_tint))
		draw_style_box(_stone_frame(), base)
		var center := Vector2(0, -size.y * 0.7)
		var crystal := Vector2(_style.crystal_size[0], _style.crystal_size[1])
		draw_circle(center, crystal.y * 0.7, Color(green, 0.07))
		draw_arc(center, crystal.y * 0.6, 0, TAU, 32, metal, width)
		var points := PackedVector2Array([center + Vector2(0, -crystal.y / 2), center + Vector2(crystal.x / 2, 0), center + Vector2(0, crystal.y / 2), center + Vector2(-crystal.x / 2, 0)])
		draw_colored_polygon(points, green.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([points[0], points[1], points[2], center]), green)
		draw_line(points[0], points[2], green.lightened(0.4), width)
		draw_line(Vector2(-size.x * 0.26, -size.y * 0.27), Vector2(size.x * 0.26, -size.y * 0.27), metal, width)
		draw_line(Vector2(0, -size.y * 0.38), Vector2(0, -size.y * 0.13), green, width)
	elif kind == "chest":
		var purple := Color(_style.sealed_chest)
		var size := Vector2(_style.seal_size[0], _style.seal_size[1])
		var rect := Rect2(-size / 2.0, size)
		draw_rect(rect.grow(width), Color(_style.dark))
		draw_rect(rect, purple.darkened(0.5))
		draw_rect(rect, purple, false, width)
		draw_arc(Vector2(0, -size.y / 2), size.x / 3, PI, TAU, 16, purple, width)
		draw_line(Vector2(0, -width), Vector2(0, size.y / 3), purple.lightened(0.35), width)
	else:
		var length := gate_size.x if horizontal else gate_size.y
		var span := gate_size.y if horizontal else gate_size.x
		var half := Vector2(span, length) / 2.0
		if horizontal:
			draw_set_transform(Vector2.ZERO, PI / 2.0)
		for side in [-1, 1]:
			var rect := Rect2(Vector2(-half.x, side * half.y - float(_style.post_width) / 2), Vector2(span, _style.post_width))
			draw_texture_rect_region(_stone, rect, Rect2(Vector2.ZERO, rect.size), Color(_style.stone_tint))
			draw_style_box(_stone_frame(), rect)
		draw_rect(Rect2(-half, Vector2(span, length)), Color(green, 0.1))
		for x in range(-int(half.x), int(half.x) + 1, int(_style.bar_spacing)):
			draw_line(Vector2(x, -half.y), Vector2(x, half.y), Color(_style.dark), float(_style.bar_width))
			draw_line(Vector2(x, -half.y), Vector2(x, half.y), Color(green, 0.7), width)
		draw_polyline(PackedVector2Array([Vector2(0, -half.y * 0.4), Vector2(half.x * 0.8, 0), Vector2(0, half.y * 0.4), Vector2(-half.x * 0.8, 0), Vector2(0, -half.y * 0.4)]), green, width)


func _stone_frame() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(_style.metal).darkened(0.35)
	style.set_border_width_all(int(_style.line_width))
	style.set_corner_radius_all(int(_style.line_width))
	return style
