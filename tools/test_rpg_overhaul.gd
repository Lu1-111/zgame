extends SceneTree
## 新规格的实机验收：物品与装备守恒、资源消耗、动作锁定、技能输入、对话和像素身份。
var gs: Node
var ui: Node
var actor: Node
var service: GDScript
var rpg: GDScript
var passed := 0
var failed := 0
var projectiles := {}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	create_timer(120,true,false,true).timeout.connect(func() -> void: quit(2))
	gs = root.get_node("GameState")
	ui = root.get_node("GameUI")
	service = load("res://scripts/core/inventory_service.gd")
	rpg = load("res://scripts/core/rpg_service.gd")
	service.config().save.directory = "user://qa_rpg_overhaul/"
	gs.reset()
	change_scene_to_file("res://scenes/rooms/camp_01.tscn")
	await _frames(12)
	actor = current_scene.get_node("Player")
	current_scene.child_entered_tree.connect(_on_spawn)
	var art: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/camp_01_art.json"))
	var camp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/camp_01.json"))
	var all_grounded := true
	for entry: Dictionary in art.decorations:
		all_grounded = _touches_ground(current_scene.get_node("ForestDetailProps/"+str(entry.id)),float(entry.contact_y)) and all_grounded
	for entry: Dictionary in camp.props:
		all_grounded = _touches_ground(current_scene.get_node(str(entry.id)),float(art.ground_contacts[entry.asset])) and all_grounded
	_expect(all_grounded,"全部营地道具按可见像素底部贴地，透明留白不造成悬空")
	service.ensure_state()
	_expect(gs.equipped_skills.size() == 3 and gs.equipped_passives.size() == 2,"三个主动槽、两个被动槽")
	service.add_item("potion_small",3)
	service.add_item("potion_mana",2)
	_expect(service.register_hotbar("potion_small",0,0) and gs.inventory[0] == null and gs.hotbar[0].count == 3,"快捷栏搬移真实堆叠并腾出背包格")
	_expect(service.count_item("potion_small") == 3,"统计包含独立快捷栏且不复制物品")
	_expect(service.register_hotbar("potion_mana",0,1) and gs.hotbar[0].id == "potion_mana" and gs.inventory[1].id == "potion_small","替换快捷物品将原堆叠退回来源格")
	gs.mana = 1
	_expect(service.use_hotbar(0,actor) and gs.mana == 21 and gs.hotbar[0].count == 1,"数字快捷使用直接扣除快捷栏堆叠")
	_expect(service.unregister_hotbar(0,4) and gs.hotbar[0] == null and gs.inventory[4].count == 1,"卸载物品实际回到指定背包格")
	service.register_hotbar("potion_small",0,1)
	for index in gs.inventory.size():
		gs.inventory[index] = {"id":"milk_bomb","count":5}
	var before := JSON.stringify(gs.hotbar)
	_expect(not service.unregister_hotbar(0) and JSON.stringify(gs.hotbar) == before,"背包已满时卸载原子失败，不销毁快捷物品")
	gs.reset()
	service.ensure_state()
	var all_before := _weapons()
	_expect(rpg.equip_weapon(0) and gs.weapon_id == &"sword_01" and not gs.owned_weapons.has(&"sword_01") and gs.owned_weapons[0] == &"hammer_01","拖入武器槽交换装备，新武器离开物品格")
	_expect(_weapons() == all_before,"武器交换前后持有集合守恒")
	_expect(rpg.unequip_weapon(8) and gs.weapon_id == &"" and gs.owned_weapons[8] == &"sword_01","武器可拖回空物品格卸下")
	_expect(rpg.equip_weapon(8) and gs.weapon_id == &"sword_01","卸下的同一把武器可重新装备")
	var old: Dictionary = gs.to_save_dict()
	old.erase("equipment_revision")
	old.owned_weapons = ["hammer_01"]
	old.weapon_id = "hammer_01"
	old.inventory = [{"id":"potion_small","count":3}]
	old.hotbar = ["potion_small","","","",""]
	old.equipped_skills = ["skill_bubble","skill_shield","skill_heal","skill_slam"]
	gs.load_from_dict(old)
	service.ensure_state()
	_expect(gs.inventory[0] == null and gs.hotbar[0].count == 3 and service.count_item("potion_small") == 3,"旧存档快捷引用迁移成真实物品，不增不减")
	_expect(not gs.owned_weapons.has(gs.weapon_id) and gs.equipped_skills.size() == 3,"旧档装备列表与四技能槽自动迁移")
	gs.reset()
	service.ensure_state()
	_key(KEY_I,true)
	await _frames(2)
	_key(KEY_I,false)
	_expect(ui.mode == "character" and paused and ui._character._slots.size() == 20,"I 呼出人物装备页：物品格、人物与四个装备槽")
	ui._character.open("attributes")
	_expect(ui.mode == "character" and paused,"属性页在同一人物面板内")
	ui._character.open("skills")
	var active_count := 0
	var passive_count := 0
	for slot in ui._character._slots:
		active_count += int(slot.kind == "active_skill")
		passive_count += int(slot.kind == "passive_skill")
	_expect(active_count == 12 and passive_count == 8,"技能页含十二主动与八被动图标")
	_expect(not rpg.equip_skill(&"active_future_01",0),"锁定的技能可查看但不能装备")
	_expect(rpg.equip_skill(&"skill_cleave",2) and gs.equipped_skills[2] == &"skill_cleave" and gs.equipped_skills.count(&"skill_cleave") == 1,"主动技能装配不重复占用槽位")
	_expect(rpg.equip_skill(&"passive_01",0,true) and is_equal_approx(float(rpg.stats().hp_regen),0.25),"被动装入对应槽位后属性真实生效")
	ui.close_menu()
	await _frames(6)
	gs.hp = 40
	await _frames(250)
	_expect(gs.hp >= 41,"已装配生命恢复被动按游戏时间回复生命")
	gs.reset()
	service.ensure_state()
	actor.reset_cooldowns()
	gs.sta = 10
	gs.mana = 60
	_expect(not actor.try_skill(&"skill_cleave") and gs.sta == 10 and gs.mana == 60,"体力不足时物理技能不施放也不扣资源")
	gs.sta = 40
	gs.mana = 0
	_expect(actor.try_skill(&"skill_cleave") and gs.sta == 22 and gs.mana == 0,"物理技能只消耗体力")
	actor.reset_cooldowns()
	gs.sta = 2
	gs.mana = 60
	_expect(not actor.try_skill(&"skill_bubble") and gs.mana == 60,"奶术缺少体力时也不能施放")
	gs.sta = 20
	_expect(actor.try_skill(&"skill_bubble") and gs.sta == 17 and gs.mana == 52,"奶术同时扣除奶力和少量体力")
	actor.reset_cooldowns()
	actor.fire_skill(&"skill_cleave")
	var directed: Node2D = actor.get_child(actor.get_child_count()-1)
	_expect(directed.has_method("orient_to_aim") and absf(angle_difference(directed.rotation,actor.aim_vector().angle())) < 0.001,"定向物理技能视觉与判定同时朝向鼠标")
	directed.queue_free()
	gs.sta = 100
	gs.mana = 60
	gs.equipped_skills.assign([&"skill_bubble",&"skill_cleave",&""])
	gs.selected_skill = 0
	_mouse(MOUSE_BUTTON_WHEEL_DOWN,true)
	await _frames(2)
	_expect(gs.selected_skill == 1,"滚轮切换选中的主动技能")
	_mouse(MOUSE_BUTTON_XBUTTON1,true)
	await _frames(3)
	_mouse(MOUSE_BUTTON_XBUTTON1,false)
	_expect(actor.skill_cooldown(&"skill_cleave") > 0 and actor._current_skill == &"skill_cleave","鼠标侧键4施放选中技能")
	await _frames(45)
	gs.weapon_id = &"hammer_01"
	actor.cancel_weapon_action()
	actor.position = Vector2(520,527)
	actor.velocity = Vector2(180,0)
	Input.action_press("move_right")
	actor.sm.to(&"Attack",{"combo":1})
	var attack_x: float = actor.position.x
	await _frames(20)
	_expect(absf(actor.position.x-attack_x) < 0.01 and actor.sm.current_name() == &"Attack","攻击时按住移动键仍无水平位移")
	Input.action_release("move_right")
	for combo in [1,2,3]:
		actor.cancel_weapon_action()
		actor.sm.to(&"Attack",{"combo":combo})
		await _frames(18)
		var effects := []
		for child in actor.get_children():
			if child.has_method("align_weapon_visual"):
				effects.append(child)
		_expect(effects.size() == 1,"奶瓶锤第 %d 段有独立攻击特效" % combo)
		if combo == 3 and not effects.is_empty():
			var effect: Node2D = effects[0]
			var visual: AnimatedSprite2D = effect._effect_player.get_node("VisualRoot/AnimatedSprite2D")
			var bottom := -10000.0
			for index in visual.sprite_frames.get_frame_count(&"hammer_slam_3"):
				var rect := visual.sprite_frames.get_frame_texture(&"hammer_slam_3",index).get_image().get_used_rect()
				bottom = maxf(bottom,visual.global_position.y+visual.offset.y+rect.end.y)
			_expect(absf(bottom-(actor.global_position.y+17)) < 0.1,"砸地特效可见下端与实际脚底平齐")
	actor.cancel_weapon_action()
	gs.weapon_id = &"bow_01"
	var arrows_before := int(projectiles.get("bow_01",0))
	Input.action_press("attack")
	actor.sm.to(&"Attack")
	await _frames(40)
	_expect(int(projectiles.get("bow_01",0)) == arrows_before and actor.attack_charge > 0.5,"弓按住时拉弓蓄力，不提前射箭")
	Input.action_release("attack")
	await _frames(3)
	_expect(int(projectiles.get("bow_01",0)) == arrows_before+1,"弓松开后只射出一箭")
	await _frames(25)
	gs.weapon_id = &"milk_staff"
	actor.cancel_weapon_action()
	var bolts_before := int(projectiles.get("milk_staff",0))
	actor.sm.to(&"Attack")
	await _frames(18)
	_expect(int(projectiles.get("milk_staff",0)) == bolts_before+1,"奶杖使用独立远程奶术普攻模组")
	actor.cancel_weapon_action()
	_test_pixels()
	actor.position = Vector2(426,527)
	actor.velocity = Vector2.ZERO
	await _frames(12)
	current_scene.get_node("MilkRabbit").interact()
	var dialogue := current_scene.get_node("NPCDialogue")
	_expect(dialogue.is_open() and paused and dialogue.portrait.texture != null,"对话下方居中、显示头像并独占世界交互")
	var line_before: int = current_scene.get_node("MilkRabbit")._line_index
	_key(KEY_I,true)
	await _frames(2)
	_key(KEY_I,false)
	_expect(ui.mode == "" and dialogue.is_open() and current_scene.get_node("MilkRabbit")._line_index == line_before+1,"对话时 I 只进入下一句，不打开人物面板")
	_mouse(MOUSE_BUTTON_LEFT,true)
	await _frames(2)
	_mouse(MOUSE_BUTTON_LEFT,false)
	_expect(dialogue.is_open() and actor.sm.current_name() != &"Attack","任意鼠标按下推进对话，不穿透为攻击")
	_key(KEY_TAB,true)
	await _frames(3)
	_key(KEY_TAB,false)
	_expect(not dialogue.is_open() and not paused and ui.mode == "","最后一句按键结束对话，不打开背包")
	actor.position = Vector2(340,527)
	actor.velocity = Vector2.ZERO
	actor.set_facing(-1)
	actor.sprite.flip_h = true
	await _frames(8)
	var fire := current_scene.get_node("Campfire") as Node2D
	var ui_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui_skin.json"))
	var anchor := fire.get_canvas_transform()*(fire.global_position+Vector2(0,float(ui_cfg.interaction.offset_y)))
	_expect(ui._interaction_plaque.visible and "坐火休息" in ui._interaction_hint.text and (ui._interaction_plaque.position+ui._interaction_plaque.size/2).distance_to(anchor) < 1,"金属文本框中的 E 提示随待交互篝火定位到上方")
	_expect(ui.begin_rest() and actor.facing == 1 and not actor.sprite.flip_h,"从另一朝向坐火后人物真正面向篝火")
	ui.close_menu()
	await _frames(40)
	ui._show_pause()
	_expect(ui.modal.position.x+ui.modal.size.x <= 320 and float(ui.root_control.get_node("Dim").color.a) > 0.5,"Esc 选项位于左半侧，游戏画面仅变暗")
	ui.close_menu()
	service.add_item("potion_small",3)
	service.register_hotbar("potion_small",0)
	var saves := root.get_node("SaveSystem")
	_expect(saves.save_game(91) == OK and saves.load_game(91) and gs.hotbar[0].count == 3 and gs.equipped_skills.size() == 3 and gs.equipped_passives.size() == 2,"新装备、独立快捷栏与技能槽存档往返")
	saves.restoring = false
	saves.delete_save(91)
	print("RPG OVERHAUL: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)


func _test_pixels() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_presentation.json"))
	var valid := true
	var count := 0
	for definition: Dictionary in cfg.animations.values():
		valid = valid and float(definition.scale) == 1.0
		for path: String in definition.frame_paths:
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			valid = valid and image.get_size() == Vector2i(64,64)
			count += 1
	var rig: Node2D = actor._pixel_rig
	var base := Image.load_from_file(ProjectSettings.globalize_path(rig.source.resource_path))
	valid = valid and rig._whole_body.texture == rig.source and rig._whole_body.scale == Vector2.ONE and rig._source_rect.size == Vector2(64,64)
	var native: Image = rig.source.get_image()
	for y in base.get_height():
		for x in base.get_width():
			if base.get_pixel(x,y).a > 0.5:
				valid = valid and native.get_pixel(x,y) == base.get_pixel(x,y)
	_expect(valid and count == 32,"三十二帧当前动作保持64画布，完整人物母版的非透明RGBA与正式源图一致")


func _on_spawn(child: Node) -> void:
	if child.get_script() != null and str(child.get_script().resource_path).ends_with("projectile_bubble.gd") and child.packet != null:
		var id := str(child.packet.source_id)
		projectiles[id] = int(projectiles.get(id,0))+1


func _touches_ground(prop: Sprite2D, contact: float) -> bool:
	var point := prop.to_global(Vector2(0,prop.offset.y+contact-prop.texture.get_height()/2.0))
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point+Vector2.DOWN*2
	query.collision_mask = 1 | 128
	var touches: bool = not current_scene.get_world_2d().direct_space_state.intersect_point(query).is_empty()
	if not touches:
		print("GROUND QA: %s visible_contact=%s root=%s offset=%s scale=%s" % [prop.name,point,prop.global_position,prop.offset,prop.scale])
	return touches


func _weapons() -> Array:
	var result: Array = gs.owned_weapons.duplicate()
	result.append(gs.weapon_id)
	result = result.filter(func(id: Variant) -> bool: return str(id) != "")
	result.sort()
	return result


func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _mouse(button: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _expect(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL",label])
	if ok:
		passed += 1
	else:
		failed += 1
