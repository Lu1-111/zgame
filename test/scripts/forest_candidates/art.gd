extends Node2D
## 机关与落脚点使用原生世界像素绘制；不增加高分辨率装饰，不覆盖角色。
const SESSION := preload("res://test/scripts/forest_candidates/session.gd")
@export var kind := "switch"
@export var caption := ""
@export var extent := Vector2.ZERO
@export var caption_position := Vector2.ZERO
var activated := false
var value := 0
var _time := 0.0

func _ready() -> void:
	z_index = 1
	if not caption.is_empty():
		var label := Label.new()
		label.text = caption
		label.position = Vector2(SESSION.rules().drawing.label_offset[0],SESSION.rules().drawing.label_offset[1])
		if not caption_position.is_zero_approx():
			label.position = caption_position
		label.size.x = absf(float(SESSION.rules().drawing.label_offset[0]))*2
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font",RPGSkin.font())
		label.add_theme_font_size_override("font_size",int(SESSION.rules().drawing.label_font))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)

func _process(delta: float) -> void:
	if kind in ["fire","fan"]:
		_time += delta
		queue_redraw()

func _draw() -> void:
	var colors: Dictionary = SESSION.rules().palette
	var green := Color(colors.active if activated else colors.moss)
	var dark := Color(colors.ink)
	var gold := Color(colors.gold)
	var pixel := float(SESSION.rules().drawing.pixel)
	match kind:
		"switch", "mirror":
			draw_rect(Rect2(-12,-8,24,8),Color(colors.stone))
			draw_rect(Rect2(-4,-30,8,24),dark)
			draw_line(Vector2.ZERO+Vector2(0,-12),Vector2(-8 if not activated else 8,-28),gold,pixel*2)
			draw_rect(Rect2(-6,-38,12,8),green)
			if kind == "mirror":
				draw_line(Vector2(-12,-42),Vector2(12,-42+value*8),green,pixel)
		"chest":
			draw_rect(Rect2(-12,-16,24,16),Color(colors.wood) if not activated else Color(colors.stone))
			draw_rect(Rect2(-12,-16,24,4),gold)
			draw_rect(Rect2(-2,-12,4,6),dark)
			if activated:
				draw_rect(Rect2(-12,-24,24,4),gold)
		"fire":
			draw_rect(Rect2(-14,-4,28,4),Color(colors.wood))
			var flicker := int(_time*8)%2*2
			draw_polygon(PackedVector2Array([Vector2(-10,-4),Vector2(-4,-20-flicker),Vector2(0,-13),Vector2(5,-28+flicker),Vector2(11,-4)]),PackedColorArray([gold]))
			draw_rect(Rect2(-3,-13,6,9),green)
		"portal":
			draw_rect(Rect2(-18,-68,6,68),Color(colors.stone))
			draw_rect(Rect2(12,-68,6,68),Color(colors.stone))
			draw_rect(Rect2(-18,-72,36,6),Color(colors.stone))
			draw_line(Vector2(-8,-32),Vector2(8,-32),green,pixel)
			draw_line(Vector2(0,-40),Vector2(8,-32),green,pixel)
			draw_line(Vector2(0,-24),Vector2(8,-32),green,pixel)
		"lift":
			draw_rect(Rect2(-extent.x/2,0,extent.x,extent.y),Color(colors.wood))
			draw_rect(Rect2(-extent.x/2,0,extent.x,pixel),gold)
			draw_line(Vector2(-extent.x/2,0),Vector2(-extent.x/2,-18),gold,pixel)
			draw_line(Vector2(extent.x/2,0),Vector2(extent.x/2,-18),gold,pixel)
		"water":
			draw_rect(Rect2(Vector2.ZERO,extent),Color(colors.water))
			for x in range(0,int(extent.x),int(pixel*8)):
				draw_line(Vector2(x,0),Vector2(x+pixel*4,0),green,pixel)
		"fan":
			var angle := _time if activated else 0.0
			for index in 4:
				var end := Vector2(14,0).rotated(angle+index*PI/2)
				draw_line(Vector2(0,-18),Vector2(0,-18)+end,green,pixel*2)
		"grass":
			for x in range(-12,13,6):
				draw_rect(Rect2(x,-6-abs(x)%4,pixel,6+abs(x)%4),green)
		"ability":
			var purple := Color(colors.locked)
			for y in [-12,-24]:
				draw_line(Vector2(-7,y),Vector2(0,y-7),purple,pixel)
				draw_line(Vector2(0,y-7),Vector2(7,y),purple,pixel)
