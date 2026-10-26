extends SceneTree
## 验证四个标记点的真实敌人：落脚、巡逻边缘、攻击受击与坐火重生。
var passed := 0
var failed := 0
var config: Dictionary
var gs: Node
var ui: Node
var actor: Node


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(30,true,false,true).timeout.connect(func() -> void: quit(2))
	gs = root.get_node("GameState")
	ui = root.get_node("GameUI")
	var service: GDScript = load("res://scripts/core/inventory_service.gd")
	service.config().save.directory = "user://qa_forest_encounters/"
	config = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/forest_01.json"))
	gs.reset()
	change_scene_to_file("res://scenes/rooms/forest_01.tscn")
	await _frames(12)
	actor = current_scene.get_node("Player")
	_expect(_enemies().size() == 4,"森林恰有四只实际小怪")
	for entry: Dictionary in config.enemies:
		var enemy := current_scene.get_node("Enemy_" + str(entry.spawn_id))
		_expect(enemy.position.distance_to(Vector2(entry.pos[0],entry.pos[1])) < 12,"%s 从叉号位置生成" % entry.spawn_id)
		_expect(enemy.is_on_floor() and absf(enemy.position.y-float(entry.pos[1])) < 2,"%s 在指定平台正常落脚" % entry.spawn_id)
		_expect(enemy.target == actor and enemy.z_index == 20 and enemy.visual.body.visible and not enemy.visual.entries.is_empty(),"%s 具有真实 AI、动画与角色渲染层" % entry.spawn_id)
	await _frames(1200)
	for enemy in _enemies():
		_expect(enemy.is_on_floor() and absf(enemy.position.y-enemy.origin.y) < 2 and enemy.position.x >= enemy.patrol_bounds.x and enemy.position.x <= enemy.patrol_bounds.y,"%s 巡逻二十秒不会自行掉落" % str(enemy.get_meta("spawn_id")))
	var victim := current_scene.get_node("Enemy_middle_left")
	actor.position = victim.position + Vector2(44,-17)
	actor.velocity = Vector2.ZERO
	actor.sm.to(&"Idle")
	gs.hp_max = 500
	gs.hp = 500
	var saw_attack := false
	for frame in 180:
		await physics_frame
		saw_attack = saw_attack or victim.state == &"attack"
	_expect(saw_attack and gs.hp < 500,"靠近后小怪真实预警、攻击并造成伤害")
	var packet_script: GDScript = load("res://scripts/core/damage_packet.gd")
	var hp_before: int = victim.hp
	victim.hurtbox.receive_hit(packet_script.new(8,0,0,actor.position,&"hammer_01"))
	_expect(victim.hp < hp_before,"玩家伤害包经过受击框扣除怪物生命")
	var exp_before: int = gs.exp
	victim.hurtbox.receive_hit(packet_script.new(9999,0,0,actor.position,&"hammer_01"))
	var exp_after: int = gs.exp
	victim.receive_hit(packet_script.new(9999,0,0,actor.position,&"hammer_01"))
	_expect(victim.hp == 0 and exp_after > exp_before and gs.exp == exp_after,"小怪可击杀且经验只结算一次")
	actor.position = Vector2(1060,655)
	actor.velocity = Vector2.ZERO
	actor.sm.to(&"Idle")
	await _frames(45)
	_expect(ui.begin_rest(),"战斗结束后篝火仍可安全休息")
	ui._rest_action("休息")
	await _frames(2)
	_expect(_enemies().size() == 4,"坐火恢复原有四个出生点，不叠加重复怪物")
	for enemy in _enemies():
		_expect(enemy.hp > 0 and enemy.target == actor and enemy.patrol_bounds.x < enemy.patrol_bounds.y and enemy.position == enemy.origin,"%s 坐火后保留出生位置、追击目标和平台边界" % str(enemy.get_meta("spawn_id")))
	ui.close_menu()
	await _frames(40)
	print("FOREST ENCOUNTERS: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)


func _enemies() -> Array:
	var result := []
	for child in current_scene.get_children():
		if child is CharacterBody2D and child.has_meta("spawn_id"):
			result.append(child)
	return result


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _expect(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL",label])
	if ok:
		passed += 1
	else:
		failed += 1
