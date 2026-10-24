class_name RoomDoor
extends Area2D
## 房间门：玩家进入后切换到目标房间，并从目标房间的同名门内侧出现。
## 元数据约定（房间生成脚本写入）：
##   target_room   目标房间 id（对应 res://scenes/rooms/<id>.tscn）
##   target_door   目标房间里的门节点名（通常是本门的对门）
##   arrive_offset 到达目标门后的落点偏移（相对目标门位置，像素）

signal triggered(target_room: StringName)

@export var target_room: StringName = &""
@export var target_door: StringName = &""
@export var arrive_offset: Vector2 = Vector2(40, -9)

var _locked := false


func _ready() -> void:
	if target_room == &"" and has_meta("target_room"):
		target_room = StringName(get_meta("target_room"))
	if target_door == &"" and has_meta("target_door"):
		target_door = StringName(get_meta("target_door"))
	if has_meta("arrive_offset"):
		arrive_offset = get_meta("arrive_offset")

	collision_layer = 0
	collision_mask = 2          # player_body
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _locked or not body.is_in_group(&"player"):
		return
	_locked = true
	triggered.emit(target_room)
	var ok: bool = SceneRouter.goto_room(target_room, target_door)
	if not ok:
		_locked = false
		push_warning("RoomDoor: 目标房间不存在，保持原地 —— %s" % target_room)
