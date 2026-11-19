extends SceneTree
## 经过真实玩家状态机核对连续连击换段瞬间的持握姿态。
var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(20,true,false,true).timeout.connect(func() -> void: quit(2))
	var room := Node2D.new()
	root.add_child(room)
	current_scene = room
	var floor_body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(1000,40)
	collider.shape = shape
	floor_body.position = Vector2(0,280)
	floor_body.add_child(collider)
	room.add_child(floor_body)
	var expected := PixelHeroRig.new()
	room.add_child(expected)
	var state := root.get_node("GameState")
	for facing in [1,-1]:
		state.reset()
		state.weapon_id = &"sword_01"
		var actor: Node = load("res://scenes/player/player.tscn").instantiate()
		actor.set_script(load("res://test/fixtures/aimed_player.gd"))
		actor.name = "Player"
		actor.position = Vector2(0,243)
		actor.aim_point = Vector2(facing*1000,230)
		room.add_child(actor)
		for frame in 4:
			await physics_frame
		actor.sm.to(&"Attack",{"combo":1})
		actor._sync_rig_pose()
		var previous_combo := 1
		var seams := 0
		for frame in 150:
			if actor.attack_combo < 3:
				actor.attack_chain = true
			await physics_frame
			if actor.sm.current_name() != &"Attack":
				break
			actor._sync_rig_pose()
			var actual: PixelHeroRig = actor._pixel_rig
			if actor.attack_combo != previous_combo:
				expected.sword_pose = "attack"
				expected.combo = previous_combo
				expected.progress = 1
				expected.facing = facing
				expected.apply_pose()
				var matches := actual._support_hand.distance_to(expected._support_hand) < 0.05 and actual._rear_hand.distance_to(expected._rear_hand) < 0.05
				matches = matches and absf(angle_difference(actual._sword_angle,expected._sword_angle)) < 0.001 and is_equal_approx(actual._depth,expected._depth)
				matches = matches and actual._grip.distance_to(expected._grip) < 0.05
				_expect(matches,"真实连击/朝向%d：第%d→%d段切换瞬间身体、手臂和剑保持原终点" % [facing,previous_combo,actor.attack_combo])
				previous_combo = actor.attack_combo
				seams += 1
		_expect(seams == 2 and actor.attack_combo == 3,"真实连击/朝向%d：完整执行纵斩、挑斩、突刺" % facing)
		actor._update_animation()
		_expect(actor.sm.current_name() == &"Idle" and actor.sprite.visible and not actor._pixel_rig.visible and actor.sprite.animation == &"idle","真实连击/朝向%d：结束后回到原人物闲置动画" % facing)
		actor.queue_free()
		await physics_frame
	print("SWORD CHAIN: %d PASS, %d FAIL" % [_passed,_failed])
	quit(1 if _failed else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL",label])
	if condition:
		_passed += 1
	else:
		_failed += 1
