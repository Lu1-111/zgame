extends Node2D
## 关卡先核实清场或消耗钥匙，再调用满足条件；锁消失后保留闭箱，玩家仍需交互打开。
signal state_changed(state: StringName)
@export_enum("none","encounter","key") var unlock_condition := "none"
var state: StringName = &"closed"
var _sprite: AnimatedSprite2D

func _ready() -> void:
	z_index = 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/art/cave_v001.json"))
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for key in [&"closed",&"locked",&"open"]:
		frames.add_animation(key)
		frames.add_frame(key,load(str(config.assets["chest_"+str(key)].path)))
	frames.add_animation(&"opening")
	frames.set_animation_loop(&"opening",false)
	frames.set_animation_speed(&"opening",1.0/float(config.chest.frame_seconds))
	for key in [&"closed",&"opening",&"open"]:
		frames.add_frame(&"opening",load(str(config.assets["chest_"+str(key)].path)))
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = frames
	_sprite.centered = false
	var anchor: Array = config.assets.chest_closed.anchor
	_sprite.position = -Vector2(anchor[0],anchor[1])
	add_child(_sprite)
	_sprite.animation_finished.connect(_finish_opening)
	reset_state()

## 恢复初始箱态，仅供房间重置或读取未开启记录。
func reset_state() -> void:
	_set_state(&"closed" if unlock_condition=="none" else &"locked")

## 接收已验证的解锁条件；此接口不暗中生成、删除或消耗背包物品。
func satisfy_condition(condition: String) -> bool:
	if state!=&"locked" or condition!=unlock_condition:
		return false
	_set_state(&"closed")
	return true

## 未上锁才播放开启逐帧；奖励和持久化由房间统一处理。
func try_open() -> bool:
	if state!=&"closed":
		return false
	state = &"opening"
	_sprite.play(&"opening")
	state_changed.emit(state)
	return true

func _set_state(value: StringName) -> void:
	state = value
	_sprite.stop()
	_sprite.animation = value
	_sprite.frame = 0
	state_changed.emit(state)

func _finish_opening() -> void:
	if state==&"opening":
		_set_state(&"open")
