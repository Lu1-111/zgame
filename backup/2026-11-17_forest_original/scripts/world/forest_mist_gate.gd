class_name ForestMistGate
extends StaticBody2D
## 白色动态雾墙；碰撞与原画帧分离，清场后永久解除并淡出。
@export var visual_size := Vector2.ZERO
var _visual: AnimatedSprite2D
var _opened := false

func _ready() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/forest_mist.json"))
	_visual = AnimatedSprite2D.new()
	_visual.name = "WhiteMist"
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frames := SpriteFrames.new()
	frames.set_animation_loop(&"default",true)
	frames.set_animation_speed(&"default",float(cfg.fps))
	var sheet := load(str(cfg.sheet)) as Texture2D
	var cell := Vector2(cfg.cell[0],cfg.cell[1])
	for index in int(cfg.frames):
		var texture := AtlasTexture.new()
		texture.atlas = sheet
		texture.region = Rect2(Vector2(index,0)*cell,cell)
		texture.filter_clip = true
		frames.add_frame(&"default",texture)
	_visual.sprite_frames = frames
	_visual.scale = visual_size/cell
	_visual.modulate = Color(cfg.tint)
	add_child(_visual)
	_visual.play()

## 同一开启状态可重复应用；重进房间时立即隐藏，清场时播放消散。
func set_open(opened: bool, animate: bool = false) -> void:
	if _opened == opened:
		return
	_opened = opened
	set_deferred("collision_layer",0 if opened else 1)
	if not opened:
		show()
		modulate.a = 1
		return
	if not animate or not is_inside_tree():
		hide()
		return
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/forest_mist.json"))
	var tween := create_tween()
	tween.tween_property(self,"modulate:a",0,float(cfg.fade_seconds))
	tween.tween_callback(hide)
