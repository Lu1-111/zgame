extends SceneTree
## 实际玩家与菜单验收：防御阶段、加点、读档迁移、仓库守恒及数字键道具。
var passed = 0
var failed = 0
var gs: Node
var ui: Node
var actor: Node
var service: GDScript
var progression: GDScript
var rpg: GDScript
var storage: GDScript

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(55,true,false,true).timeout.connect(func() -> void: quit(2))
	service = load("res://scripts/core/inventory_service.gd")
	progression = load("res://scripts/core/progression_service.gd")
	rpg = load("res://scripts/core/rpg_service.gd")
	storage = load("res://scripts/core/storage_service.gd")
	gs = root.get_node("GameState")
	ui = root.get_node("GameUI")
	gs.reset()
	change_scene_to_file("res://scenes/maps/camp_01.tscn")
	await _frames(12)
	actor = current_scene.get_node("Player")
	while ui.player != actor:
		await process_frame
	actor.position = Vector2(110,527)
	await _frames(8)
	await _guards()
	await _progression()
	await _storage()
	await _hotbar_and_facing()
	ui._force_close()
	print("RPG EXPANSION: %d PASS, %d FAIL" % [passed,failed])
	quit(1 if failed else 0)

func _guards() -> void:
	for id: StringName in [&"sword_01",&"bow_01",&"hammer_01",&"milk_staff"]:
		gs.weapon_id = id
		Input.action_press("guard")
		actor.sm.to(&"Guard")
		actor._update_animation()
		var name = StringName("guard_"+actor.weapon_type())
		_expect(actor.sprite.animation == name and actor.sprite.sprite_frames.get_frame_count(name) == 3,"四类武器加载独立格挡素材 "+str(id))
		for seconds in [0.0,0.05,0.15,0.199]:
			gs.hp = 80
			gs.sta = 100
			actor._invuln = 0
			actor.guard_pose_time = seconds
			var damage: int = actor.apply_hit(DamagePacket.new(20,DamagePacket.DamageType.PHYSICAL,0,actor.position+Vector2(20,0)))
			_expect(damage == 0 and gs.hp == 80,"整个举起阶段精准格挡 %.3f %s" % [seconds,id])
		actor.guard_pose_time = actor.guard_raise_duration()
		actor._update_animation()
		_expect(actor.sprite.frame == 2 and not actor.sprite.is_playing(),"就位帧维持且暂停 "+str(id))
		gs.hp = 80
		gs.sta = 100
		actor._invuln = 0
		_expect(actor.apply_hit(DamagePacket.new(20,DamagePacket.DamageType.PHYSICAL,0,actor.position)) == 10,"维持阶段初始减伤50% "+str(id))
		Input.action_release("guard")
		await _frames(1)
		_expect(actor.sm.current_name() == &"GuardRelease" and not actor.is_guarding,"松键立即解除 "+str(id))
		actor._invuln = 0
		_expect(actor.apply_hit(DamagePacket.new(20,DamagePacket.DamageType.PHYSICAL,0,actor.position)) == 20,"解除动作正常受击 "+str(id))
		actor._invuln = 0
		actor.sm.to(&"Idle")
		await _frames(28)

func _progression() -> void:
	gs.reset()
	service.ensure_state()
	gs.exp = 120
	ui._on_exp(120)
	_expect(gs.level == 3 and gs.milk_energy == 2,"跨两级获得两点奶能")
	_expect(gs.hp_max == 88 and gs.mana_max == 66,"等级基础成长保留")
	_expect(not progression.allocate("vitality",true),"普通状态不能直接加点")
	ui._resting = true
	ui._show_talents()
	gs.milk_energy = 5
	await _click(ui.modal.find_child("Allocate_vitality",true,false))
	_expect(int(gs.attribute_points.vitality) == 1 and gs.milk_energy == 4,"真实鼠标点击加点按钮消耗奶能")
	for id in ["endurance","strength","intellect","perception"]:
		_expect(progression.allocate(id,true),"坐火消耗奶能增加 "+id)
	_expect(gs.milk_energy == 0 and not progression.allocate("vitality",true),"奶能耗尽后不可继续加点")
	_expect(gs.hp_max == 98 and gs.sta_max == 110 and gs.mana_max == 76,"生命耐力智力正确增加三项上限")
	_expect(is_equal_approx(float(rpg.stats().sta_regen),33),"耐力恢复速度同比提升10%")
	var weapon: Dictionary = root.get_node("DataDB").get_weapon(gs.weapon_id)
	_expect(rpg.attack_power("physical") == roundi((12.0+float(weapon.attack))*1.05),"力量作用于实际物理攻击")
	_expect(rpg.attack_power("magic") == roundi(12.0*1.05),"智力作用于实际奶术攻击")
	var cd = float(root.get_node("DataDB").get_skill(&"skill_comet_dash").cooldown)
	_expect(is_equal_approx(progression.skill_cooldown(&"skill_comet_dash"),cd*0.975),"感知缩短技能冷却2.5%")
	gs.permanent_bonuses.hp_max = 20
	progression.refresh_limits()
	var split = progression.breakdown()
	_expect(int(split.base.hp_max) == 98 and int(split.bonus.hp_max) == 20 and gs.hp_max == 118,"基础值和道具加成分开显示")
	ui.open_character()
	ui._character.open("attributes")
	_expect(ui.modal.find_children("Allocate_*","Button",true,false).is_empty(),"I键属性页没有加点按钮")
	_expect("98（+20）" in ui.modal.find_child("Stat_hp_max",true,false).text,"人物属性格式为基础值（+加成）")
	var snapshot: Dictionary = gs.to_save_dict()
	gs.reset()
	gs.load_from_dict(snapshot)
	_expect(gs.attribute_points.vitality == 1 and gs.permanent_bonuses.hp_max == 20 and gs.milk_energy == 0,"点数、奶能和永久加成存档往返")
	gs.reset()
	gs.load_from_dict({"level":5,"hp_max":104,"sta_max":100,"mana_max":72})
	_expect(gs.milk_energy == 4 and int(gs.permanent_bonuses.hp_max) == 8,"旧档补发等级奶能并保留旧上限道具")
	ui._force_close()
	# 实际施法的冷却截止时间与属性页缩减一致。
	gs.reset()
	gs.attribute_points.perception = 4
	actor.reset_cooldowns()
	actor._invuln = 0
	actor.sm.to(&"Idle")
	var clock = actor._clock
	var started: bool = actor.cast_ui_skill(&"skill_comet_dash")
	actor.skills.tick(0.1)
	_expect(started and is_equal_approx(float(actor._skill_ready[&"skill_comet_dash"])-clock,cd*0.9),"四级感知真实施法冷却缩短10%")
	actor.cancel_weapon_action()

func _storage() -> void:
	gs.reset()
	service.ensure_state()
	service.add_item("potion_small",3)
	service.add_item("mushroom",8)
	var entries = storage.bag_entries()
	for category in ["item","weapon"]:
		var found = false
		for entry: Dictionary in entries:
			if entry.category == category:
				found = storage.transfer(entry)
				break
		_expect(found,"仓库可存入分类 "+category)
	var stored = storage.stored_entries()
	_expect(stored.size() == 2,"道具和武器均进入仓库")
	for entry: Dictionary in stored:
		var fresh = storage.stored_entries()
		_expect(storage.transfer(fresh[0]),"仓库取回整格 "+str(entry.id))
	_expect(gs.owned_weapons.has(&"sword_01") and service.count_item("potion_small") == 3,"武器和道具往返守恒")
	for index in gs.inventory.size():
		gs.inventory[index] = {"id":"milk_bomb","count":5}
	gs.storage = [{"id":"potion_small","count":3}]
	var before = JSON.stringify(gs.storage)
	_expect(not storage.transfer(storage.stored_entries()[0]) and JSON.stringify(gs.storage) == before,"背包满取出失败且仓库完全不变")
	gs.storage.append({"id":"sword_01","count":1})
	_expect(not storage.transfer(storage.stored_entries()[1]),"道具满包时武器同样不能取回")
	gs.storage.remove_at(1)
	gs.inventory[4] = null
	_expect(storage.transfer(storage.stored_entries()[0]) and gs.inventory[4].id == "potion_small","取回物品进入实际空格")
	# 护甲和饰品沿道具定义分类，未来新增装备无需改仓库代码。
	var db = root.get_node("DataDB")
	for category in ["armor","accessory"]:
		var id = "qa_"+category
		db.items[StringName(id)] = {"id":id,"name":category,"type":category,"stack":1}
		gs.inventory[5] = {"id":id,"count":1}
		var entry = {"id":id,"count":1,"source":"inventory","index":5}
		_expect(storage.category(id) == category and storage.transfer(entry),"护甲饰品分类可存入："+category)
		var stored_item = storage.stored_entries().back()
		_expect(storage.transfer(stored_item) and gs.inventory[5].id == id,"护甲饰品取回守恒："+category)
		gs.inventory[5] = null
		db.items.erase(StringName(id))
	for index in 80:
		gs.storage.append({"id":"potion_sta","count":1})
	ui._resting = true
	ui._show_storage()
	_expect(ui.modal.find_children("Category_*","Button",true,false).size() == 10,"仓库两侧各有全部道具武器护甲饰品五页")
	await _click(ui.modal.find_child("StoreScroll0",true,false).get_child(0).get_child(0))
	_expect(gs.inventory[0] == null,"真实鼠标点击背包物品整格存入仓库")
	await _click(ui.modal.find_child("StoreScroll1",true,false).get_child(0).get_child(0))
	_expect(gs.inventory[0] is Dictionary and gs.inventory[0].id == "potion_sta","真实鼠标点击仓库物品取回背包空格")
	ui.modal.find_child("Category_0_weapon",true,false).pressed.emit()
	_expect(ui._storage_view.pages[0] == "weapon" and ui._storage_view.pages[1] == "all","两侧页签独立切换")
	_expect(ui.modal.find_child("StoreScroll1",true,false).get_child(0).custom_minimum_size.y > 192,"无限仓库可滚动到大量物品")
	ui._force_close()

func _hotbar_and_facing() -> void:
	gs.reset()
	service.ensure_state()
	actor._invuln = 0
	actor.sm.to(&"Idle")
	await _frames(3)
	for index in 5:
		gs.hotbar[index] = {"id":"potion_small","count":2}
		gs.hp = 10
		_key(KEY_1+index,true)
		await _frames(3)
		_key(KEY_1+index,false)
		_expect(gs.hp == 40 and int(gs.hotbar[index].count) == 1,"实际数字键%d使用对应道具一次" % (index+1))
	_expect(ui._experience_bar.size.y <= 6,"经验条保持紧凑高度")
	gs.coin += 17
	await process_frame
	_expect(ui._coin_label.text == "17 奶币" and ui._coin_popup.text == "+17" and ui._coin_popup.visible,"右下金钱变化显示+X")
	gs.coin -= 5
	await process_frame
	_expect(ui._coin_popup.text == "-5","支出显示独立的-X提示")
	actor.set_facing(-1)
	await _frames(2)
	_expect(actor.facing == -1,"鼠标闲置不改变角色朝向")
	Input.action_press("move_right")
	await _frames(3)
	_expect(actor.facing == 1 and actor.velocity.x > 0,"按住右移先转向并持续移动")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _frames(3)
	_expect(actor.facing == -1 and actor.velocity.x < 0,"左移立即转向")
	Input.action_release("move_left")
	Input.action_release("move_left")
	var attack_facing = int(signf(actor.aim_vector().x))
	actor.set_facing(-attack_facing)
	actor.sm.to(&"Attack")
	_expect(actor.facing == attack_facing,"发动攻击时才转向光标所在一侧")
	actor.cancel_weapon_action()
	var left = InputEventKey.new()
	left.physical_keycode = KEY_LEFT
	var right = InputEventKey.new()
	right.physical_keycode = KEY_RIGHT
	_expect(InputMap.event_is_action(left,"move_left") and InputMap.event_is_action(right,"move_right"),"左右方向键映射正确")

func _key(code: int, pressed: bool) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func _frames(count: int) -> void:
	for index in count:
		await physics_frame
	await process_frame

func _expect(condition: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL",label])
	if condition:
		passed += 1
	else:
		failed += 1


func _click(control: Control) -> void:
	await _frames(1)
	var pos = control.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = pos
	root.push_input(motion,true)
	await _frames(1)
	for pressed in [true,false]:
		var click = InputEventMouseButton.new()
		click.position = pos
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click,true)
		await _frames(2)
