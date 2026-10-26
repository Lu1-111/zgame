extends SceneTree
## Godot Viewport 鼠标事件验证内建拖拽，只操作 QA 行囊。
var ui: Node
var gs: Node
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	create_timer(15,true).timeout.connect(func() -> void: quit(1))
	gs = root.get_node("GameState")
	ui = root.get_node("GameUI")
	gs.reset()
	change_scene_to_file("res://scenes/rooms/camp_01.tscn")
	await _frames(8)
	var service: GDScript = load("res://scripts/core/inventory_service.gd")
	service.add_item("potion_small",3)
	service.add_item("potion_mana",2)
	ui.open_inventory()
	await _frames(3)
	await _drag(ui._view_slots[0],ui._bag_hotbar[0])
	_check(gs.hotbar[0] is Dictionary and gs.hotbar[0].id == "potion_small" and gs.inventory[0] == null,"真实鼠标拖入快捷栏搬移并腾出原格")
	await _drag(ui._bag_hotbar[0],ui._view_slots[5])
	_check(gs.hotbar[0] == null and gs.inventory[5] is Dictionary and service.count_item("potion_small") == 3,"真实鼠标拖回指定行囊格卸载")
	await _drag(ui._view_slots[5],ui._view_slots[4])
	_check(gs.inventory[5] == null and gs.inventory[4] is Dictionary and gs.inventory[4].id == "potion_small","真实鼠标移动背包格")
	ui.close_menu()
	ui.open_character()
	await _frames(3)
	await _drag(_slot("weapon_inventory",0),_slot("weapon_equipped",0))
	_check(gs.weapon_id == &"sword_01" and gs.owned_weapons[0] == &"hammer_01","真实鼠标拖入人物槽交换武器")
	await _drag(_slot("weapon_equipped",0),_slot("weapon_inventory",5))
	_check(gs.weapon_id == &"" and gs.owned_weapons[5] == &"sword_01","真实鼠标拖回装备格卸下武器")
	ui._character.open("skills")
	await _frames(3)
	await _drag(_slot("active_skill",5),_slot("active_slot",2))
	_check(gs.equipped_skills[2] == &"skill_cleave" and gs.equipped_skills.count(&"skill_cleave") == 1,"真实鼠标主动技能拖拽替换且不重复")
	await _drag(_slot("passive_skill",0),_slot("passive_slot",1))
	_check(gs.equipped_passives[1] == &"passive_01","真实鼠标被动技能拖拽装配")
	print("NATIVE DRAG: %d failures" % failures)
	quit(1 if failures else 0)

func _slot(kind: String, index: int) -> Control:
	for slot in ui._character._slots:
		if slot.kind == kind and slot.index == index:
			return slot
	return null

func _drag(source: Control, target: Control) -> void:
	var start := source.get_global_rect().get_center()
	var end := target.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = start
	root.push_input(motion,true)
	await _frames(1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.button_mask = MOUSE_BUTTON_MASK_LEFT
	click.position = start
	root.push_input(click,true)
	await _frames(2)
	for step in range(1,9):
		motion = InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = start.lerp(end,float(step) / 8)
		motion.relative = (end-start) / 8
		root.push_input(motion,true)
		await _frames(1)
	click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	click.position = end
	root.push_input(click,true)
	await _frames(3)

func _frames(count: int) -> void:
	for frame in count:
		await process_frame

func _check(ok: bool, text: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL",text])
	if not ok:
		failures += 1
