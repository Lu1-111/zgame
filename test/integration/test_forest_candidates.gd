extends "res://test/integration/test_forest_02.gd"
## 使用真实玩家与物理体逐图验收：出生/薄台、能力门、机关、升降篮、清场、接口及存档隔离。
var _session: Script
var gs: Node
var save: Node
var _room: Node2D
var _rules: Dictionary
var _report: Array = []

func _run() -> void:
	_session = load("res://test/scripts/forest_candidates/session.gd")
	gs = root.get_node("GameState")
	save = root.get_node("SaveSystem")
	_rules = _session.rules()
	create_timer(float(_rules.physics_test.timeout_seconds),true,false,true).timeout.connect(func() -> void: quit(2))
	gs.reset()
	gs.coin = 137
	for row: Dictionary in _session.candidates():
		var before := failures
		change_scene_to_file(str(row.scene))
		await _frames(int(_rules.physics_test.settle_frames))
		_room = current_scene
		config = _room.config
		player = _room.player
		_freeze()
		_expect(player.is_on_floor(),str(row.id)+" 出生点有真实地面")
		_expect(player.z_index==20,str(row.id)+" 角色位于装饰前方")
		_expect(save.save_game()==ERR_UNAVAILABLE,str(row.id)+" 禁止写正式存档")
		if str(row.id)=="08A":
			var gate: Node2D = _room._gates.G6
			var lower: float = gate.position.y+(_room.config.gates.filter(func(item: Dictionary) -> bool: return str(item.id)=="G6")[0].rect[3]/2)-float(_rules.gate_margin)
			await _place(Vector2(gate.position.x-64,lower-HALF))
			Input.action_press("move_right")
			await _frames(60)
			_release()
			_expect(player.position.x<gate.position.x,"08A 平行上廊不能绕过未清封印")
		if str(row.id)=="09B":
			await _alternative_route()
		await _mechanisms(str(row.id))
		# 下面只测试地形，不让已验证过的封印或敌人干扰落脚点。
		_room.set_physics_process(false)
		for gate in _room._gates.values():
			gate.set_open(true,false)
		await _frames(2)
		await _platforms(str(row.id))
		await _ability_gap(str(row.id))
		_report.append({"id":row.id,"platforms":config.platforms.size(),"failures":failures-before})
		_release()
	await _review_links()
	change_scene_to_file("res://test/scenes/forest_candidates.tscn")
	await _frames(8)
	_expect(save.save_game()==ERR_UNAVAILABLE,"选图界面也不写试玩存档")
	_session.finish(self)
	await _frames(8)
	_expect(gs.coin==137,"离开试玩恢复原旅途")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://work/qa"))
	var report := FileAccess.open("res://work/qa/forest_candidates.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"maps":_report,"failures":failures},"  "))
	print("FOREST CANDIDATES: 10 scenes, %d failures" % failures)
	quit(1 if failures else 0)

func _freeze() -> void:
	player.set("_invuln",99999.0)
	for enemy in get_nodes_in_group(&"enemies"):
		enemy.set_physics_process(false)
		enemy.collision_layer = 0

func _mechanisms(id: String) -> void:
	match id:
		"05A":
			_room.operate("B")
			_expect(not bool(_room.progress.flags.get("solved",false)),"05A 未排中渠不能先开终闸")
			_room.operate("A")
			await _frames(2)
			_expect(_room._gates.WaterSeal.collision_layer==0,"05A 排水解除中渠实体")
			_room.operate("B")
		"05B":
			var lift: Dictionary = _room._lifts.LeftLift
			await _place(lift.body.position-Vector2(0,HALF))
			_room.operate("lift_left")
			await _wait_lift(lift)
			_expect(absf(player.position.y+HALF-float(lift.definition.stops[1]))<float(_rules.platform_tolerance),"05B 左篮真实载人到中层")
			_room.operate("prepare_right")
			var right: Dictionary = _room._lifts.RightLift
			await _wait_lift(right)
			await _place(right.body.position-Vector2(0,HALF))
			_room.operate("lift_right")
			await _wait_lift(right)
			_expect(absf(player.position.y+HALF-float(right.definition.stops[2]))<float(_rules.platform_tolerance),"05B 右篮真实载人到上层")
		"06A":
			_room.operate("A")
			_expect(not bool(_room.progress.flags.get("solved",false)),"06A 光源开启仍需正确折光")
			for index in int(_rules.mirror_solution):
				_room.operate("B")
		"06B":
			_room.operate("C")
			_expect(not bool(_room.progress.flags.get("C",false)),"06B 上游断开时末端不通风")
			_room.operate("A")
			_room.operate("B")
			_room.operate("C")
		"07A", "07B":
			var point: Vector2 = _room._markers.A.position
			_room.operate("checkpoint",point)
			_room.operate("shortcut",point)
			_expect(not _room.progress.checkpoint.is_empty(),id+" 中段检查点生效")
		_:
			for enemy: Dictionary in config.enemies:
				var actor = _room.get_node_or_null("Enemy_"+str(enemy.spawn_id))
				if actor == null:
					_expect(false,id+" 敌人实体存在 "+str(enemy.spawn_id))
					continue
				var packet := DamagePacket.new(int(actor.definition.hp)*10)
				packet.ignore_defense = true
				actor.receive_hit(packet)
			if id=="08B":
				_room.operate("shortcut")
			await _frames(3)
			_expect(_room.progress.killed.size()==config.enemies.size(),id+" 真正击杀全部怪物")
	await _frames(3)
	for gate: Dictionary in config.gates:
		_expect(_room._gates[gate.id].collision_layer==0,id+" 开放对应封印 "+str(gate.id))
	if not config.chests.is_empty():
		var chest: Dictionary = config.chests[0]
		await _place(Vector2(chest.pos[0],float(chest.pos[1])-HALF))
		_room.interact_nearby()
		_expect(str(chest.id) in _room.progress.opened,id+" 空宝箱可交互")

func _wait_lift(lift: Dictionary) -> void:
	var distance := absf(float(lift.body.position.y)-float(lift.definition.stops[int(lift.target)]))
	await _frames(ceili(distance/float(_rules.lift_speed)*60)+int(_rules.physics_test.settle_frames))

func _platforms(id: String) -> void:
	var bad := 0
	for platform: Dictionary in config.platforms:
		var rect := _rect(platform.rect)
		await _place(Vector2(rect.get_center().x,rect.position.y-HALF))
		if not player.is_on_floor() or absf(player.position.y+HALF-rect.position.y)>float(_rules.platform_tolerance):
			bad += 1
			print("BAD SHELF %s %s: wanted=%s actual=%s" % [id,platform.id,rect,player.position])
	_expect(bad==0,id+" 全部%d个落脚台真实可站立" % config.platforms.size())
	# 每图另做一次相邻台阶的实际单跳，避免只验证静态放置。
	var tested := false
	for source: Dictionary in config.platforms:
		if tested:
			break
		for target: Dictionary in config.platforms:
			var a := _rect(source.rect)
			var b := _rect(target.rect)
			var rise := a.position.y-b.position.y
			if rise<60 or rise>96 or absf(a.get_center().x-b.get_center().x)>128:
				continue
			if await _try_route(a,b,false):
				tested = true
				break
	_expect(tested,id+" 相邻薄台可用普通单跳连接")

func _ability_gap(id: String) -> void:
	var takeoff := _vec(config.ability_test.takeoff)
	var landing := _rect(config.ability_test.landing)
	_room._apply_double_jump(false)
	await _place(takeoff)
	var start := player.position.y
	var peak := start
	Input.action_press("jump")
	for frame in int(_rules.physics_test.jump_frames):
		await physics_frame
		peak = minf(peak,player.position.y)
	_release()
	_expect(peak+HALF>landing.position.y,id+" 普通跳跃无法越过能力口")
	_room._apply_double_jump(true)
	await _place(takeoff)
	Input.action_press("jump")
	await _frames(int(_rules.physics_test.double_press_frame))
	Input.action_release("jump")
	await _frames(1)
	Input.action_press("jump")
	await _frames(int(_rules.physics_test.jump_frames)-int(_rules.physics_test.double_press_frame))
	_release()
	_expect(player.is_on_floor() and absf(player.position.y+HALF-landing.position.y)<=float(_rules.platform_tolerance),id+" 二段跳可落在能力口平台")

func _rect(values: Array) -> Rect2:
	return Rect2(values[0],values[1],values[2],values[3])

func _vec(values: Array) -> Vector2:
	return Vector2(values[0],values[1])

func _alternative_route() -> void:
	var first: Dictionary = config.enemies[2]
	var last: Dictionary = config.enemies[3]
	await _place(Vector2(float(first.pos[0])-40,float(first.pos[1])-HALF))
	Input.action_press("move_right")
	await _frames(150)
	_release()
	_expect(player.position.x>float(last.pos[0])-HALF,"09B 下沟不被哨楼封印横断")
	for definition: Dictionary in config.enemies:
		if int(definition.group)!=2:
			continue
		var actor = _room.get_node("Enemy_"+str(definition.spawn_id))
		var packet := DamagePacket.new(int(actor.definition.hp)*10)
		packet.ignore_defense = true
		actor.receive_hit(packet)
	await _frames(3)
	_expect(bool(_room.progress.flags.get("either_route",false)) and not bool(_room.progress.flags.get("group_1",false)),"09B 只清下沟也能打通出口")

func _review_links() -> void:
	_session.begin(self).maps.erase("08A")
	_session.begin(self).choices["08"] = "08A"
	_session.enter(self,"05A","E1")
	await _frames(12)
	_room = current_scene
	player = _room.player
	_freeze()
	_expect(bool(_room.progress.flags.get("solved",false)) and _room._gates.G.collision_layer==0,"05A 重访保留排水与捷径")
	await _place(_room._markers.E3.position-Vector2(0,HALF))
	_room.interact_nearby()
	await _frames(12)
	_room = current_scene
	player = _room.player
	config = _room.config
	_freeze()
	_expect(_room.candidate_id=="08A","05A E3 实际切换到08A E2")
	_expect(_room._gates.G5.collision_layer==0,"反向入场暂开放入口封印")
	Input.action_press("move_left")
	await _frames(90)
	_release()
	_expect(player.position.x<_room._gates.G5.position.x-float(_rules.body_half),"反向入口可步行进入战场")
	_expect(_room._gates.G5.collision_layer==1 and _room._gates.G5.visible,"进入后封印重新闭合且可见")
	for enemy: Dictionary in config.enemies:
		var actor = _room.get_node_or_null("Enemy_"+str(enemy.spawn_id))
		if actor != null:
			var packet := DamagePacket.new(int(actor.definition.hp)*10)
			packet.ignore_defense = true
			actor.receive_hit(packet)
	await _frames(3)
	await _place(_room._markers.E2.position-Vector2(0,HALF))
	_room.interact_nearby()
	await _frames(12)
	_room = current_scene
	player = _room.player
	_expect(_room.candidate_id=="05A","08A E2 可往返05A E3")
	var event := InputEventKey.new()
	event.keycode = KEY_M
	event.physical_keycode = KEY_M
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	_expect(paused,"M 打开当前实际场景地图并暂停世界")
	var point := player.position
	Input.action_press("move_right")
	await _frames(4)
	_release()
	_expect(player.position.distance_to(point)<0.1,"看图期间玩家停止移动")
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(1)
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	_expect(not paused,"再次M返回实际场景")
