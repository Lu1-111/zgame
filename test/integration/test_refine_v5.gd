extends SceneTree
## 真实物理验证新版三段剑、步枪、十二技能素材、按住/提前释放格挡和素材独立性。
var passed := 0
var failed := 0
var actor: Node
var gs: Node

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(60,true,false,true).timeout.connect(func() -> void: quit(2))
	gs = root.get_node("GameState")
	gs.reset()
	var room := Node2D.new()
	root.add_child(room)
	current_scene = room
	_floor(Rect2(-100,260,1000,40))
	actor = load("res://scenes/player/player.tscn").instantiate()
	actor.set_script(load("res://test/fixtures/aimed_player.gd"))
	actor.position = Vector2(40,243)
	room.add_child(actor)
	await _frames(8)
	Input.action_press("guard")
	actor.sm.to(&"Guard")
	await _frames(45)
	_expect(actor.is_guarding and actor.sprite.animation == StringName("guard_"+actor.weapon_type()) and actor.sprite.frame == 2 and not actor.sprite.is_playing(),"持续按住防御停在完整举手帧，不播放放下部分")
	Input.action_release("guard")
	await _frames(1)
	_expect(actor.sm.current_name() == &"GuardRelease" and not actor.is_guarding and actor.sprite.frame < 2,"松键当帧停止防御并开始放下，不继续保持举手")
	await _frames(15)
	_expect(actor.sm.current_name() == &"Idle","停止防御动画完成后回到闲置")
	for early in [1,6]:
		Input.action_press("guard")
		actor.sm.to(&"Guard")
		await _frames(early)
		Input.action_release("guard")
		await _frames(1)
		_expect(actor.sm.current_name() == &"GuardRelease" and not actor.is_guarding,"举手第%d物理帧松键也立即开始停止动作" % early)
		await _frames(15)
	gs.weapon_id = &"bow_01"
	actor.aim_point = actor.position+Vector2(150,-80)
	actor.sm.to(&"Attack")
	await _frames(4)
	_expect(actor.weapon_type() == "rifle" and actor._pixel_rig.kind == "rifle" and actor._pixel_rig.visible,"旧弓武器存档自动使用双手步枪模组")
	var rig: Node = actor._pixel_rig
	var natural: Image = rig.source.get_image()
	var original := Image.load_from_file(ProjectSettings.globalize_path(str(rig.source.resource_path)))
	_expect(natural.get_size() == original.get_size() and rig._whole_body.scale == Vector2.ONE,"人物母版和原像素密度保持不变，96画布仅扩展武器留白")
	_expect(int(rig.cfg.native_motion.version) >= 6 and rig._native_hands.texture == rig.source and not rig.has_method("_arm"),"保留正式人物的手臂和掌形，不绘制额外程序手臂")
	var first: Vector2 = rig.muzzle_global_position()
	var target_direction: Vector2 = (actor.aim_point-first).normalized()
	_expect(rig.firing_direction_global().dot(target_direction) > 0.999,"枪管、枪口弹道与光标一致，补偿人物中心和枪口偏移")
	actor.aim_point = actor.position+Vector2(150,80)
	await _frames(1)
	_expect(rig.muzzle_global_position().y > first.y and rig._local_aim.y > 0,"光标由上向下移动时枪口与双手连续俯仰")
	actor.cancel_weapon_action()
	for child in room.get_children():
		if child is ProjectileBubble or child is AttackEffect:
			child.queue_free()
	var library: GDScript = load("res://scripts/core/skill_library.gd")
	var definition: Dictionary = root.get_node("DataDB").get_skill(&"skill_nb_quickdraw")
	_expect(definition.weapon_requirement == "sword" and library.canonical(&"skill_cleave") == &"skill_nb_quickdraw","旧剑气迁移为剑专用拔刀")
	_expect(library.animation("SKL-N01_counter_slash").frames.size() == 4 and library.animation("SKL-N01_slash_fx").frames.size() == 4,"拔刀接入完整反击动作和独立斩光")
	var fx: Dictionary = WeaponRuntime.config().independent_fx
	_expect(fx.sword_down.texture != fx.sword_up.texture and fx.sword_up.texture != fx.sword_thrust.texture and fx.sword_down.texture != fx.sword_thrust.texture,"下劈、上挑、突刺保留独立剑光图集")
	_expect(library.presentation().beam_components.size() == 6,"奶光炮接入六个同源炮口、中段和头端组件")
	var frames: Dictionary = rig._frame_data
	var down: Dictionary = frames.poses.sword_1_07
	var up: Dictionary = frames.poses.sword_2_07
	_expect(float(down.hand[1]) > 40 and float(up.hand[1]) < float(down.hand[1]) and float(up.angle_degrees) < 0,"纵斩至身侧，再从身侧挑斩至肩侧")
	_expect(RPGSkin.icon_for_path("res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_potion_small_icon_v001.png").resource_path.ends_with("quiet_v5/potion_small.svg"),"快捷栏和行囊统一使用简洁物品图标")
	_expect(RPGSkin.icon_for_path(str(definition.icon)).resource_path == str(definition.icon),"技能图标使用合作者上传的正式像素素材")
	print("REFINE V5: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)

func _floor(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.position = rect.position+rect.size/2
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	current_scene.add_child(body)
	return body

func _frames(count: int) -> void:
	for frame in count:
		await physics_frame

func _expect(condition: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL",label])
	if condition:
		passed += 1
	else:
		failed += 1
