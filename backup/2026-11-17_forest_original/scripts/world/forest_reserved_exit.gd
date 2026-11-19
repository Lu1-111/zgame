extends Area2D
## 下一张地图尚未制作时保留通道标记；完成相邻房间后即可替换为正式门。


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_entered)


func _on_entered(body: Node) -> void:
	if body.is_in_group(&"player"):
		GameUI.toast("前方区域尚未开放")
