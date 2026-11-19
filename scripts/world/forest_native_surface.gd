extends Node2D
## 原生森林平台与木栅，纹理按世界像素逐段平铺，末段裁切、不拉伸。
@export var size := Vector2.ZERO
@export_enum("solid","oneway","gate") var kind := "solid"
var art: Dictionary
var _field: Texture2D
var _top: Texture2D

func _ready() -> void:
	art = JSON.parse_string(FileAccess.get_file_as_string("res://data/art/forest_v002.json"))
	_field = load(str(art.assets.rock_field.path))
	_top = load(str(art.assets["wood_gate" if kind=="gate" else "branch_platform" if kind=="oneway" else "solid_top"].path))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	queue_redraw()

func _draw() -> void:
	if _top==null:return
	if kind=="gate":
		for x in range(0,roundi(size.x),roundi(_top.get_width())):
			for y in range(0,roundi(size.y),_top.get_height()):
				var part:=Vector2(minf(_top.get_width(),size.x-x),minf(_top.get_height(),size.y-y))
				draw_texture_rect_region(_top,Rect2(Vector2(x,y)-size/2.0,part),Rect2(Vector2.ZERO,part))
		return
	if kind=="solid":
		for y in range(0,roundi(size.y),_field.get_height()):
			for x in range(0,roundi(size.x),_field.get_width()):
				var part:=Vector2(minf(_field.get_width(),size.x-x),minf(_field.get_height(),size.y-y))
				draw_texture_rect_region(_field,Rect2(Vector2(x,y),part),Rect2(Vector2.ZERO,part))
	for x in range(0,roundi(size.x),_top.get_width()):
		var part:=Vector2(minf(_top.get_width(),size.x-x),_top.get_height())
		draw_texture_rect_region(_top,Rect2(Vector2(x,0),part),Rect2(Vector2.ZERO,part))
