extends SceneTree
## 在真实 forest_02 场景验证出生区域取值、副本隔离与下一次出生才采用新倍率。
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(30,true,false,true).timeout.connect(func() -> void: quit(2))
	var state := root.get_node("GameState")
	var db := root.get_node("DataDB")
	state.reset()
	var forest: Dictionary = db.get_region(&"forest")
	var original: float = float(forest.enemy_multiplier)
	forest.enemy_multiplier = 2.0
	change_scene_to_file("res://scenes/maps/forest_02.tscn")
	for frame in 12:
		await process_frame
	var first: Node = current_scene.get_node("Enemy_f02_upper_w1")
	_check(first.hp == 60 and first.definition.damage == 12,"真实放入森林的怪物按森林倍率2.0出生")
	_check(first.definition.defense == 8 and first.poise.maximum == 100,"防御和韧性不受倍率改变")
	_check(db.get_enemy(&"moss_beetle").base_hp == 30 and not db.get_enemy(&"moss_beetle").has("hp"),"某房间实例不回写全局基础值")
	forest.enemy_multiplier = original
	var second: Node = load("res://scenes/enemies/combat_enemy.tscn").instantiate()
	second.enemy_id = &"moss_beetle"
	second.position = Vector2(800,304)
	current_scene.add_child(second)
	_check(second.hp == 30 and first.hp == 60,"恢复区域1.0仅影响后续出生，现有实例独立")
	print("ENEMY REGION INTEGRATION: %d failures" % failed)
	quit(1 if failed else 0)

func _check(ok: bool, message: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL",message])
	if not ok:
		failed += 1
