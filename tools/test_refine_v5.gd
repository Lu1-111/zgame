extends SceneTree
## 真实物理验证新版三段剑、步枪、贯穿剑气、按住/提前释放格挡和素材独立性。
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
	actor.set_script(load("res://tools/fixtures/aimed_player.gd"))
	actor.position = Vector2(40,243)
	room.add_child(actor)
	await _frames(8)
	Input.action_press("guard")
	actor.sm.to(&"Guard")
	await _frames(45)
	_expect(actor.is_guarding and actor.sprite.animation == &"guard" and actor.sprite.frame == 2 and not actor.sprite.is_playing(),"持续按住防御停在完整举手帧，不播放放下部分")
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
	var original := Image.load_from_file(ProjectSettings.globalize_path(str(rig.cfg.source)))
	_expect(natural.get_size() == original.get_size() and rig._whole_body.scale == Vector2.ONE,"人物母版和原像素密度保持不变，96画布仅扩展武器留白")
	_expect(rig.cfg.arms.mask.size() == 2 and rig._rear_hand.distance_to(rig._support_hand) > 10,"两段旧手臂被替换，步枪只连接两只握持手")
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
	var enemies: Array = []
	for x in [140,260,380]:
		var enemy: Node2D = load("res://scripts/enemies/combat_enemy.gd").new()
		enemy.enemy_id = &"moss_beetle"
		enemy.target = actor
		enemy.position = Vector2(x,260)
		room.add_child(enemy)
		enemy.set_physics_process(false)
		enemies.append(enemy)
	await _frames(3)
	var hits: Dictionary = {}
	var definition: Dictionary = root.get_node("DataDB").get_skill(&"skill_cleave")
	var wave := SwordWave.new()
	wave.specification = definition.presentation
	wave.direction = Vector2.RIGHT
	wave.packet = DamagePacket.new(8,DamagePacket.DamageType.PHYSICAL,0,actor.position,&"skill_cleave")
	wave.source_actor = actor
	wave.hit_landed.connect(func(target: Node, _amount: int) -> void: hits[target] = int(hits.get(target,0))+1)
	room.add_child(wave)
	wave.global_position = Vector2(70,234)
	await _frames(52)
	_expect(hits.size() == 3 and enemies.all(func(enemy: Node) -> bool: return enemy.hp < 30),"剑气沿路径贯穿三名敌人，远端也有真实伤害")
	_expect(hits.values().all(func(count: int) -> bool: return count == 1),"同一道剑气对每名敌人只结算一次")
	if is_instance_valid(wave):
		wave.queue_free()
	var wall := _floor(Rect2(180,120,20,140))
	var blocked := SwordWave.new()
	blocked.specification = definition.presentation
	blocked.direction = Vector2.RIGHT
	blocked.packet = DamagePacket.new(8,DamagePacket.DamageType.PHYSICAL,0,actor.position,&"skill_cleave")
	blocked.source_actor = actor
	room.add_child(blocked)
	blocked.global_position = Vector2(70,180)
	await _frames(22)
	_expect(not is_instance_valid(blocked),"剑气遇到实心墙后消失，不穿墙伤害")
	wall.queue_free()
	var fx: Dictionary = WeaponRuntime.config().independent_fx
	_expect(fx.sword_down.texture != fx.sword_up.texture and fx.sword_up.texture != fx.sword_cross.texture and fx.sword_down.texture != fx.sword_cross.texture,"纵斩、挑斩、横斩使用三个独立生成的图集")
	_expect(fx.sword_wave.world_size[1] > 2*38 and float(definition.presentation.range) >= 500,"独立剑气贴图与贯穿距离明显大于原近身斩击")
	var angles: Array = rig.cfg.sword.angles
	_expect(float(angles[0][5])-float(angles[0][2]) >= 240 and float(angles[1][2]) > float(angles[1][5]),"纵斩挥到身侧，第二段由下向上挑起")
	_expect(RPGSkin.icon_for_path("res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_potion_small_icon_v001.png").resource_path.ends_with("quiet_v5/potion_small.svg"),"快捷栏和行囊统一使用简洁物品图标")
	_expect(RPGSkin.icon_for_path("res://assets/ui/magic/skill_cleave.svg") is AtlasTexture,"技能图标使用新油画图集")
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
