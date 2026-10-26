class_name QuietFrame
extends Control
## 轻薄半透明面板；细线与留白取代厚金属装饰。
var kind := "panel"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var c: Dictionary = RPGSkin.config().colors
	var edge := Color(c.edge)
	if kind == "hud":
		var h: Dictionary = RPGSkin.config().hud
		var p: Array = h.portrait
		var center := Vector2(p[0]+p[2]/2.0,p[1]+p[3]/2.0)-position
		draw_circle(center,19,Color(c.back))
		draw_arc(center,19,-PI,PI,64,edge,0.6,true)
		for index in 3:
			var y := float(h.bars[1])+index*float(h.gap)-position.y
			draw_rect(Rect2(Vector2(h.bars[0]-position.x-2,y-2),Vector2(h.bars[2]+4,h.bars[3]+4)),Color(c.back))
			draw_line(Vector2(h.bars[0]-position.x-2,y-2),Vector2(h.bars[0]-position.x+h.bars[2]+2,y-2),edge,0.5)
		return
	var fill := Color(c.back)
	if kind == "dialogue":
		fill.a = 0.83
	elif kind == "tooltip":
		fill.a = 0.9
	draw_rect(Rect2(Vector2.ZERO,size),fill)
	if kind == "track":
		draw_rect(Rect2(Vector2.ZERO,size),edge,false,0.5)
		return
	draw_line(Vector2(0,0),Vector2(size.x,0),edge,0.6,true)
	draw_line(Vector2(0,size.y),size,edge,0.6,true)
	if kind in ["panel","secondary"]:
		draw_line(Vector2(12,54),Vector2(size.x-12,54),Color(c.rule),0.5,true)
