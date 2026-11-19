extends CanvasLayer
## 屏幕层原生像素背景，视口扩大时平铺补齐，禁止随地图尺寸缩放。
@export var texture: Texture2D
@export var tint := Color.WHITE

func _ready() -> void:
	get_viewport().size_changed.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if texture==null:return
	var size := get_viewport().get_visible_rect().size
	for y in range(0,ceili(size.y),texture.get_height()):
		for x in range(0,ceili(size.x),texture.get_width()):
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.centered = false
			sprite.position = Vector2(x,y)
			sprite.modulate = tint
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(sprite)
