extends RoomDoor
## 巨木通道：沿用房间路由，捷径由另一侧开关解锁，状态随 GameState 存档。

@export var shortcut_id: StringName = &""
var _arrival_grace := 0.0


func _ready() -> void:
	super._ready()
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/forest_01.json"))
	_arrival_grace = float(config.interaction.door_arrival_grace)


func _physics_process(delta: float) -> void:
	var was_protected := _arrival_grace > 0.0
	_arrival_grace = maxf(0.0, _arrival_grace - delta)
	# 玩家入场后立刻折返时，保护结束后重新检查仍在门内的角色。
	var leaving_input := Input.get_axis(&"move_left", &"move_right") * arrive_offset.x < 0.0
	if was_protected and _arrival_grace <= 0.0 and leaving_input:
		for body in get_overlapping_bodies():
			_on_body_entered(body)


func _on_body_entered(body: Node) -> void:
	if _arrival_grace > 0.0 or SceneRouter.is_transitioning():
		return
	if shortcut_id != &"" and not GameState.opened_shortcuts.has(shortcut_id):
		return
	super._on_body_entered(body)
