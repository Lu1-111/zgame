class_name QuietFrame
extends Control
## 暗金蚀刻边框：切角、双层压边与克制角饰，保持厚重感和清晰内容区。
var kind := "panel"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var c: Dictionary = RPGSkin.config().colors
	var trim: Dictionary = RPGSkin.config().trim
	var edge := Color(c.edge)
	var highlight := Color(trim.highlight)
	if kind == "hud":
		var h: Dictionary = RPGSkin.config().hud
		var p: Array = h.portrait
		var center := Vector2(p[0]+p[2]/2.0,p[1]+p[3]/2.0)-position
		draw_circle(center,21,Color(c.back))
		draw_arc(center,21,-PI,PI,64,edge,1,true)
		draw_arc(center,18,-PI,PI,64,Color(c.rule),0.7,true)
		for angle in [-PI/2,PI/2,PI]:
			_diamond(center+Vector2.from_angle(angle)*21,2,highlight)
		for index in 3:
			var y := float(h.bars[1])+index*float(h.gap)-position.y
			var rect := Rect2(Vector2(h.bars[0]-position.x-3,y-3),Vector2(h.bars[2]+6,h.bars[3]+6))
			draw_colored_polygon(_contour(rect.position,rect.size,2),Color(c.back))
			draw_polyline(_contour(rect.position,rect.size,2),edge,0.7,true)
			draw_line(rect.position+Vector2(5,1),rect.position+Vector2(24,1),highlight,0.6,true)
		return
	var fill := Color(c.back)
	if kind == "dialogue":
		fill.a = 0.88
	elif kind == "tooltip":
		fill.a = 0.96
	elif kind == "inset":
		fill = Color(trim.inset)
	elif kind == "tracker":
		fill.a = 0.72
	elif kind == "title":
		fill.a = 0.64
	var cut := minf(float(trim.cut),minf(size.x,size.y)/4)
	if kind != "outline":
		draw_colored_polygon(_contour(Vector2(2,3),size,cut),Color(trim.shadow))
		draw_colored_polygon(_contour(Vector2.ZERO,size,cut),fill)
		if size.y > 40 and kind != "track":
			draw_colored_polygon(_contour(Vector2.ONE*2,Vector2(size.x-4,minf(48,size.y/3)),cut/2),Color(trim.wash))
	draw_polyline(_contour(Vector2.ONE,size-Vector2.ONE*2,cut),edge,1,true)
	if kind in ["panel","secondary","dialogue","title","outline"]:
		draw_polyline(_contour(Vector2.ONE*4,size-Vector2.ONE*8,maxf(0,cut-2)),Color(c.rule),0.6,true)
	if kind != "track":
		var length := minf(float(trim.corner_length),size.x/6)
		for origin in [Vector2(1,1),Vector2(size.x-1,1),Vector2(1,size.y-1),size-Vector2.ONE]:
			var direction := Vector2(1 if origin.x < size.x/2 else -1,1 if origin.y < size.y/2 else -1)
			draw_line(origin+Vector2(direction.x*cut,0),origin+Vector2(direction.x*(cut+length),0),highlight,1,true)
			draw_line(origin+Vector2(0,direction.y*cut),origin+Vector2(0,direction.y*(cut+length)),highlight,1,true)
	if kind in ["panel","secondary"]:
		draw_line(Vector2(12,54),Vector2(size.x-12,54),Color(c.rule),0.5,true)
		_diamond(Vector2(size.x/2,1),2,highlight)
	elif kind == "tracker":
		draw_line(Vector2(1,12),Vector2(1,size.y-12),highlight,2,true)

func _diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center+Vector2.UP*radius,center+Vector2.RIGHT*radius,center+Vector2.DOWN*radius,center+Vector2.LEFT*radius]),color)

func _contour(origin: Vector2, extent: Vector2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([origin+Vector2(cut,0),origin+Vector2(extent.x-cut,0),origin+Vector2(extent.x,cut),origin+Vector2(extent.x,extent.y-cut),origin+Vector2(extent.x-cut,extent.y),origin+Vector2(cut,extent.y),origin+Vector2(0,extent.y-cut),origin+Vector2(0,cut),origin+Vector2(cut,0)])
