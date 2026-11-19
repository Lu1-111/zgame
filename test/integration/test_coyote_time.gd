extends SceneTree
## 使用真实角色、实体地面与空心平台验收离台宽限、消耗边界及落地状态衔接。
var passed := 0
var failed := 0
var player: Node
var room: Node2D
var gs: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Engine.max_physics_steps_per_frame = 1
	create_timer(60,true,false,true).timeout.connect(func() -> void:quit(2))
	gs = root.get_node("GameState")
	gs.reset()
	room = Node2D.new()
	room.name = "CoyoteTestRoom"
	root.add_child(room)
	current_scene = room
	_floor(Rect2(0,200,200,20),false)
	_floor(Rect2(400,200,200,4),true)
	_floor(Rect2(-200,600,1400,40),false)
	await _spawn(Vector2(150,183))
	_check(player.is_on_floor(),"前置：正式角色站在实体平台上")
	await _walk_off()
	_check(player._coyote > 0,"走离实体平台立即获得短暂起跳宽限")
	await _steps(3)
	await _jump()
	_check(player.velocity.y < -500 and player.sm.current_name() == &"Jump","离台约50ms后按跳仍能以正常跳速起跳（vy=%.2f, state=%s）" % [player.velocity.y,player.sm.current_name()])
	_check(player._coyote == 0 and player._air_jumps_left == 0,"宽限起跳立即消费机会，无二段跳能力也能使用")
	await _spawn(Vector2(150,183))
	await _walk_off()
	await _steps(9)
	await _jump()
	_check(player._coyote == 0 and player.velocity.y > 0,"离台超过100ms后不能继续使用地面跳")
	await _spawn(Vector2(800,80))
	await _jump()
	_check(player._coyote == 0 and player.velocity.y > 0,"出生在空中且未接地时不凭空获得宽限")
	await _spawn(Vector2(150,183))
	_check(player.try_ground_jump(),"正常地面起跳成功")
	_check(not player.try_ground_jump(),"同一物理帧不能重复利用尚未刷新的接地标记起跳")
	await _steps(1)
	_check(player._coyote == 0,"主动起跳后不重新发放土狼时间")
	await _spawn(Vector2(150,183),true)
	await _walk_off()
	await _steps(2)
	await _jump()
	_check(player.velocity.y < -500 and player._air_jumps_left == 1 and not player._used_double,"土狼时间内优先用普通跳，保留已解锁的空中二段跳")
	Input.action_release(&"jump")
	await _steps(1)
	await _jump()
	_check(player._air_jumps_left == 0 and player._used_double,"宽限起跳后仍可正常使用一次二段跳")
	_check(not player.try_ground_jump() and not player.try_air_jump(),"两次机会用完后不可再额外起跳")
	await _spawn(Vector2(150,183),true)
	await _walk_off()
	await _steps(9)
	await _jump()
	_check(player._used_double and player._air_jumps_left == 0,"宽限过期后跳跃仍按原规则消费二段跳")
	await _spawn(Vector2(550,183))
	await _walk_off()
	await _steps(2)
	await _jump()
	_check(player.velocity.y < -500,"走离空心平台同样支持土狼时间")
	await _spawn(Vector2(500,183))
	Input.action_press(&"move_down")
	await _steps(3)
	_check(not player.is_on_floor() and player._drop_through > 0,"按下方向键正常穿过空心平台")
	await _jump()
	_check(player._coyote == 0 and player.velocity.y > 0,"主动下穿不会被土狼时间免费弹回上方")
	await _spawn(Vector2(150,183))
	await _jump()
	Input.action_release(&"jump")
	await _steps(1)
	player.sm.to(&"Attack",{"combo":1})
	for index in 90:
		await _steps(1)
		if player.is_on_floor():break
	_check(player.is_on_floor() and player.sm.current_name() == &"Attack","前置：角色在攻击动作期间实际落地")
	_check(not player._jumped,"攻击中落地也会重置本轮跳跃标记")
	for index in 60:
		if player.sm.current_name() == &"Idle":break
		await _steps(1)
	await _walk_off()
	await _steps(2)
	await _jump()
	_check(player.velocity.y < -500,"攻击落地后再次走离平台仍能使用土狼跳")
	await _spawn(Vector2(100,140))
	for index in 60:
		if player.position.y >= 176 and player.velocity.y > 0:break
		await _steps(1)
	Input.action_press(&"jump")
	for index in 12:
		await _steps(1)
		if player.velocity.y < -500:break
	_check(player.velocity.y < -500,"落地前按跳的原有输入缓冲仍然有效（vy=%.2f, state=%s, floor=%s）" % [player.velocity.y,player.sm.current_name(),player.is_on_floor()])
	await _spawn(Vector2(150,183))
	await _walk_off()
	player.checkpoint_position = Vector2(800,80)
	player.respawn()
	await _steps(1)
	await _jump()
	_check(player._coyote == 0 and player.velocity.y > 0,"重生到空中落点不继承上一位置的土狼时间")
	_release()
	print("COYOTE TIME: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)

func _spawn(point: Vector2, double_jump: bool = false) -> void:
	_release()
	if is_instance_valid(player):
		player.queue_free()
		await _steps(1)
	gs.abilities.clear()
	if double_jump:gs.abilities.append(&"double_jump")
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	player.name = "Player"
	player.position = point
	room.add_child(player)
	await _steps(4)
	root.get_node("GameUI")._bind_scene(room)
	await _steps(2) # 等待场景绑定后的输入保护结束，避免把菜单屏蔽误当成跳跃边界。

func _walk_off() -> void:
	Input.action_press(&"move_right")
	for index in 90:
		await _steps(1)
		if not player.is_on_floor():
			Input.action_release(&"move_right")
			return
	_check(false,"前置失败：未在限时内走离平台")
	Input.action_release(&"move_right")

func _jump() -> void:
	Input.action_press(&"jump")
	await _steps(1)

func _floor(rect: Rect2, oneway: bool) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 128 if oneway else 1
	body.position = rect.position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.position = rect.size/2
	collision.one_way_collision = oneway
	body.add_child(collision)
	room.add_child(body)

func _release() -> void:
	for action in [&"jump",&"move_left",&"move_right",&"move_down"]:
		Input.action_release(action)

func _steps(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame

func _check(value: bool, message: String) -> void:
	if value:passed += 1
	else:failed += 1
	print("%s: %s" % ["PASS" if value else "FAIL",message])
