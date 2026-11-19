extends SceneTree
## 用已实装的五种怪物自然索敌/追击验证完整预备、攻击与回收帧，不能靠手动强制attack过关。
var failures := 0
var checks := 0
var records: Array = []
var gs: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	gs = root.get_node("GameState")
	var original: Dictionary = gs.to_save_dict()
	for id in ["moss_beetle","milk_moth","milk_slime","vine_flower","moss_guard"]:
		await _check_enemy(id)
	gs.load_from_dict(original)
	var file := FileAccess.open("res://work/qa/enemy_attack_animation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"enemies":records},"  "))
	print("ENEMY ATTACK ANIMATION: %d checks / %d failures / 5 map enemy types" % [checks,failures])
	quit(1 if failures else 0)

func _check_enemy(id: String) -> void:
	gs.reset()
	gs.current_room = &"forest_03"
	gs.hp_max = 9999
	gs.hp = 9999
	var room := Node2D.new()
	room.name = "EnemyAttackAnimationTest"
	room.set_meta("disable_save",true)
	root.add_child(room)
	current_scene = room
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(640,40)
	collision.shape = rectangle
	floor_body.position = Vector2(320,280)
	floor_body.add_child(collision)
	room.add_child(floor_body)
	var hero: CharacterBody2D = load("res://scenes/player/player.tscn").instantiate()
	hero.name = "Player"
	hero.position = Vector2(380,243)
	room.add_child(hero)
	hero.set_physics_process(false)
	var enemy = load("res://scenes/enemies/combat_enemy.tscn").instantiate()
	enemy.enemy_id = StringName(id)
	enemy.target = hero
	enemy.position = Vector2(260,243 if id=="milk_moth" else 260)
	room.add_child(enemy)
	var seen: Dictionary = {}
	var state_order: Array = []
	var first_attack_position := Vector2.ZERO
	for index in 480:
		await physics_frame
		# 玩家物理被冻结用于固定站位，清除随该物理时钟冻结的受击无敌，允许下一招也被验证。
		hero.set("_invuln",0.0)
		var state := str(enemy.state)
		if state_order.is_empty() or state_order.back()!=state:
			state_order.append(state)
		if state in ["telegraph","attack","recover"]:
			var action := str(enemy.visual.action)
			if not seen.has(action): seen[action] = []
			var frame := int(enemy.visual.body.frame)
			if not seen[action].has(frame): seen[action].append(frame)
			if state=="attack" and first_attack_position==Vector2.ZERO:
				first_attack_position = enemy.global_position
		if id=="milk_slime" and seen.has("attack") and seen.attack.size()==4 and seen.has("grab_attack") and seen.grab_attack.size()==8 and seen.has("recover") and seen.recover.size()==4 and seen.has("grab_recover") and seen.grab_recover.size()==4:
			break
		if id!="milk_slime" and seen.has("attack") and seen.attack.size()==4 and seen.has("recover") and seen.recover.size()==4:
			break
	_expect("telegraph" in state_order and "attack" in state_order and "recover" in state_order,id+" naturally enters attack sequence")
	for action in (["grab_ready","grab_attack","grab_recover","telegraph","attack","recover"] if id=="milk_slime" else ["telegraph","attack","recover"]):
		var expected: int = enemy.visual.body.sprite_frames.get_frame_count(StringName(action))
		_expect(seen.has(action) and seen[action].size()==expected,id+" complete animation: "+action)
	_expect(gs.hp<9999,id+" natural attack reaches real player hurtbox")
	_expect(enemy.visual.body.visible and enemy.visual.body.sprite_frames.get_frame_count(&"attack")==4,id+" actual body SpriteFrames loaded, not fallback")
	records.append({"id":id,"state_order":state_order,"frames_seen":seen,"first_attack_position":[first_attack_position.x,first_attack_position.y],"damage_to_player":9999-int(gs.hp)})
	room.queue_free()
	await physics_frame
	await process_frame

func _expect(condition: bool,description: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: "+description)
