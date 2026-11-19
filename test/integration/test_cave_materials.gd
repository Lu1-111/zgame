extends SceneTree
## 实际场景验收：图块碰撞、晶石光源、锁态机、平台站立与石笋接触轮廓。
var checks := 0
var failures := 0
var contacts := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	change_scene_to_file("res://test/scenes/cave_material_preview.tscn")
	await _frames(8)
	var room := current_scene
	var hero := room.get_node("Player") as CharacterBody2D
	hero.set_physics_process(false)
	var save := root.get_node("SaveSystem")
	_expect(save.save_game()==ERR_UNAVAILABLE,"试玩禁止写正式存档")
	var normal := room.get_node("NormalChest")
	var encounter := room.get_node("EncounterChest")
	var keyed := room.get_node("KeyChest")
	_expect(normal.state==&"closed" and encounter.state==&"locked" and keyed.state==&"locked","普通与两类上锁箱初始状态正确")
	_expect(not encounter.try_open() and not keyed.try_open(),"上锁时不能提前开启")
	_expect(not encounter.satisfy_condition("key") and not keyed.satisfy_condition("encounter"),"两种解锁条件不可互代")
	_expect(encounter.satisfy_condition("encounter") and encounter.state==&"closed","清场后去锁并保持闭箱")
	_expect(keyed.satisfy_condition("key") and keyed.state==&"closed","钥匙完成后去锁并保持闭箱")
	_expect(keyed.try_open(),"去锁后可交互打开")
	await create_timer(0.5).timeout
	_expect(keyed.state==&"open" and not keyed.try_open(),"完整开箱逐帧结束且不可重复打开")
	encounter.reset_state()
	var press := InputEventKey.new()
	press.physical_keycode = KEY_1
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	press = InputEventKey.new()
	press.physical_keycode = KEY_1
	Input.parse_input_event(press)
	_expect(encounter.state==&"closed","数字键1真实输入可触发清场去锁")
	hero.position = normal.position-Vector2(0,18)
	press = InputEventKey.new()
	press.physical_keycode = KEY_E
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	press = InputEventKey.new()
	press.physical_keycode = KEY_E
	Input.parse_input_event(press)
	_expect(normal.state==&"opening" or normal.state==&"open","E真实交互可打开最近宝箱")
	var light_count := 0
	var platform_count := 0
	for node in room.get_children():
		if str(node.name).begins_with("crystal_"):
			for child in node.get_children():
				if child is PointLight2D and child.energy>0:
					light_count+=1
		if node is StaticBody2D and node.get_script()!=null and str(node.get_script().resource_path).ends_with("cave_platform.gd"):
			platform_count+=1
			var shape := node.get_child(node.get_child_count()-1) as CollisionShape2D
			_expect(shape.one_way_collision and node.collision_layer==128,"石台具有单向顶部碰撞")
			hero.position = node.position+Vector2(24,-18)
			hero.velocity = Vector2.ZERO
			for frame in 12:
				hero.velocity = Vector2(0,60)
				hero.move_and_slide()
				await physics_frame
			_expect(hero.is_on_floor(),"真实玩家可站立石质平台")
	_expect(light_count==4,"四种晶石均生成有效点光")
	_expect(platform_count==5,"预览中五组平台全部验证")
	var ground := room.get_node("CaveTerrain") as TileMapLayer
	var background := room.get_node("CaveBackground/DeepCavern") as Sprite2D
	_expect(background.scale==Vector2.ONE and background.texture.get_size()==Vector2(640,360),"背景640×360屏幕层原生显示，不按地图拉伸")
	_expect(ground.scale==Vector2.ONE and hero.scale==Vector2.ONE,"地形和主角世界像素保持1:1")
	var wall := (ground.material as ShaderMaterial).get_shader_parameter("rock_field") as Texture2D
	_expect((ground.material as ShaderMaterial).get_shader_parameter("field_size")==wall.get_size(),"岩石场采样尺寸等于文件实际像素数")
	for node in room.get_children():
		if node.get_script()!=null and str(node.get_script().resource_path).begins_with("res://scripts/world/"+"cave_"):
			_expect(node.scale==Vector2.ONE,"洞穴物件均以原生世界尺寸运行")
	_expect(ground.tile_set.get_source(0).get_tiles_count()==80,"完整80变体TileSet")
	for cell: Vector2i in ground.get_used_cells():
		_expect(ground.get_cell_tile_data(cell).get_collision_polygons_count(0)>0,"地形格具有实体alpha碰撞")
	for id in ["rock_01","rock_02","rock_03","rock_04","crystal_01","crystal_02","crystal_03"]:
		var prop := room.get_node(id) as Node2D
		var query := PhysicsRayQueryParameters2D.create(prop.position+Vector2(0,-1),prop.position+Vector2(0,4),1)
		_expect(not room.get_world_2d().direct_space_state.intersect_ray(query).is_empty(),"地面装饰有实体接地点："+id)
	var strip := room.get_node("StalagmiteStrip") as Area2D
	_expect(strip.collision_layer==256 and strip.collision_mask==2,"石笋使用独立危险层且只检玩家")
	strip.hazard_contact.connect(_contact)
	var detector := CharacterBody2D.new()
	detector.collision_layer = 2
	detector.collision_mask = 0
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2.ONE*2
	collision.shape = box
	detector.add_child(collision)
	room.add_child(detector)
	var hit_x := 0.0
	var hit_y := INF
	var image := (strip.get_child(0) as Sprite2D).texture.get_image()
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).a>0.9 and y<hit_y:
				hit_x = x
				hit_y = y
	detector.global_position = strip.global_position+(strip.get_child(0) as Sprite2D).position+Vector2(hit_x,hit_y+2)
	await _frames(5)
	_expect(contacts>0,"石笋尖端真实接触触发")
	contacts=0
	detector.global_position.y-=12
	await _frames(3)
	contacts=0
	await _frames(3)
	_expect(contacts==0,"离开可见尖端不发生扩大的方框误判")
	print("CAVE MATERIALS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _contact(_body: Node2D) -> void:
	contacts+=1

func _expect(condition: bool,description: String) -> void:
	checks+=1
	if not condition:
		failures+=1
		printerr("FAIL: "+description)

func _frames(count: int) -> void:
	for index in count:
		await physics_frame
