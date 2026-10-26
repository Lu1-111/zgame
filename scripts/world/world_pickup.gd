class_name WorldPickup
extends Area2D
## 可拾取物：容量不足时留在场上，接收成功后才消失。
var item_id := "potion_small"
var count := 1
var _collected := false


func _ready() -> void:
	add_to_group(&"world_pickups")
	collision_layer = 64
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = float(InventoryService.config().combat.pick_up_radius) / 2
	shape.shape = circle
	add_child(shape)
	if not DataDB.get_item(StringName(item_id)).is_empty():
		var visual := (load("res://assets/PROCESSED/items/ITM-B01/v001/godot/ItemVisual.tscn") as PackedScene).instantiate()
		add_child(visual)
		visual.set_item(StringName(item_id))
	else:
		var icon := Sprite2D.new()
		icon.texture = load("res://assets/ui/magic/skill_slam.svg")
		icon.scale = Vector2.ONE * 0.6
		add_child(icon)
	z_index = 1
	body_entered.connect(func(body: Node) -> void:
		if body.is_in_group(&"player"):
			collect())


## 返回接收结果；失败不扣数量、不销毁场上物品。
func collect() -> bool:
	if _collected or is_queued_for_deletion():
		return false
	if not InventoryService.add_item(item_id,count):
		GameUI.toast("行囊已满，物品仍留在原地")
		return false
	GameUI.toast("获得 %s ×%d" % [DataDB.get_item(StringName(item_id)).get("name",item_id),count])
	_collected = true
	queue_free()
	return true
