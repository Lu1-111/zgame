extends CanvasLayer
## 常驻魔幻 HUD、Tab 行囊、灵火休息、天赋和无限仓库；所有模态界面冻结世界。

const ITEM_ICON := "res://assets/PROCESSED/items/ITM-B01/v001/icons/ITEM_%s_icon_v001.png"
var cfg: Dictionary
var root_control: Control
var hud: Control
var modal: Control
var mode := ""
var scene: Node
var player: Player
var _resting := false
var _closing := false
var _bars: Array[ProgressBar] = []
var _bar_labels: Array[Label] = []
var _hud_slots: Array[MagicSlot] = []
var _skill_slots: Array[MagicSlot] = []
var _view_slots: Array[MagicSlot] = []
var _bag_hotbar: Array[MagicSlot] = []
var _details: Control
var _selected_source := "inventory"
var _character: CharacterPanel
var _input_lock_until := -1
var _selected := -1
var _page := "inventory"
var _coin_label: Label
var _toast_label: Label
var _toast_time := 0.0
var _consumed_frame := -100
var _inventory_signature := ""
var _enemy_profiles: Array = []
var _interaction_hint: Label
var _selected_hotbar := -1
var _previous_sta := 100
var _regen_glow := 0.0
var _modal_base := Rect2()
var _damage_overlay: TextureRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	cfg = InventoryService.config()
	get_tree().root.title = str(cfg.window_title)
	root_control = Control.new()
	root_control.name = "GameplayInterface"
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var magic_theme := Theme.new()
	magic_theme.default_font_size = int(cfg.layout.font)
	magic_theme.set_stylebox("panel","TooltipPanel",_style(_color("panel"),_color("gold")))
	root_control.theme = magic_theme
	add_child(root_control)
	var cursor := load("res://assets/ui/magic/cursor_rune.svg") as Texture2D
	var hotspot: Array = RPGService.config().cursor_hotspot
	Input.set_custom_mouse_cursor(cursor,Input.CURSOR_ARROW,Vector2(hotspot[0],hotspot[1]))
	Input.set_custom_mouse_cursor(cursor,Input.CURSOR_POINTING_HAND,Vector2(hotspot[0],hotspot[1]))
	Input.set_custom_mouse_cursor(cursor,Input.CURSOR_DRAG,Vector2(hotspot[0],hotspot[1]))
	_build_hud()
	_toast_label = _label(root_control, "", Vector2(180,83), 12, _color("bright_gold"))
	_toast_label.size.x = 360
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interaction_hint = _label(hud,"",Vector2(240,299),11,_color("bright_gold"))
	_damage_overlay = _picture(root_control,"res://assets/ui/magic/hit_vignette.svg",Rect2(0,0,cfg.layout.screen[0],cfg.layout.screen[1]))
	_damage_overlay.modulate.a = 0
	EventBus.exp_gained.connect(_on_exp)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.player_damaged.connect(func(_amount: int) -> void: _flash_damage())
	get_tree().set_auto_accept_quit(false)
	get_tree().root.close_requested.connect(_save_and_quit)


func _process(delta: float) -> void:
	var current := get_tree().current_scene
	if current != scene:
		_bind_scene(current)
	if not is_instance_valid(player):
		hud.hide()
		return
	hud.visible = mode in ["","rest"]
	_coin_label.visible = not _resting
	var inventory_hint := hud.get_node_or_null("InventoryHint")
	if inventory_hint != null:
		inventory_hint.visible = mode == ""
	_interaction_hint.text = "E  坐火休息" if mode == "" and not dialogue_active() and _nearest_fire() != null else ""
	if mode == "" and not dialogue_active() and GameState.current_room == &"camp_01" and not GameState.opened_chests.has(&"camp_supplies") and player.position.distance_to(Vector2(cfg.camp_supplies.ground[0],cfg.camp_supplies.ground[1])) < float(cfg.rest.range):
		_interaction_hint.text = "E  打开补给箱"
	var view_size := get_viewport().get_visible_rect().size
	if inventory_hint != null:
		inventory_hint.position.y = view_size.y - 23
	_toast_label.position = Vector2((view_size.x-360)/2,8 if mode in ["inventory","storage","talents","pause"] else 83)
	_damage_overlay.size = view_size
	if is_instance_valid(modal):
		modal.position = _modal_base.position + Vector2(0 if mode == "pause" else (view_size.x-float(cfg.layout.screen[0]))/2,(view_size.y-float(cfg.layout.screen[1]))/2)
	for index in _hud_slots.size():
		_hud_slots[index].position.x = view_size.x - 42
		_hud_slots[index].pivot_offset = _hud_slots[index].size / 2
		_hud_slots[index].scale = Vector2.ONE * (1.1 if index == _selected_hotbar else 1.0)
	for index in _skill_slots.size():
		_skill_slots[index].position = Vector2((view_size.x - 112) / 2 + index * 40,view_size.y - 40)
		_skill_slots[index].visible = not _resting and not dialogue_active()
	_toast_time = maxf(0, _toast_time - delta)
	_toast_label.visible = _toast_time > 0
	var resources := ["hp", "sta", "mana"]
	for index in resources.size():
		var current_value := float(GameState.get(resources[index]))
		var maximum := float(GameState.get(resources[index] + "_max"))
		_bars[index].max_value = maximum
		_bars[index].value = lerpf(_bars[index].value, current_value, minf(1, delta / float(cfg.animation.resource_smooth)))
		_bar_labels[index].text = "%s  %d / %d" % [["生命","体力","奶力"][index],int(current_value),int(maximum)]
	_bars[0].modulate.a = 0.65 + 0.35 * absf(sin(Time.get_ticks_msec() / 180.0)) if GameState.hp < GameState.hp_max * float(cfg.animation.low_health) else 1.0
	_regen_glow = maxf(0,_regen_glow-delta)
	if GameState.sta > _previous_sta:
		_regen_glow = float(cfg.animation.resource_smooth)
	_previous_sta = GameState.sta
	_bars[1].modulate = Color(1.2,1.15,1.0) if _regen_glow > 0 else Color.WHITE
	var minimum_cost := InventoryService.skill_mana_cost(InventoryService.equipped_skill(GameState.selected_skill))
	_bars[2].modulate = Color("#7d8191") if GameState.mana < minimum_cost else Color.WHITE
	_coin_label.text = "Lv.%d  ·  %d 奶币" % [GameState.level,GameState.coin]
	for index in _hud_slots.size():
		_update_hotbar(_hud_slots[index],index)
	for index in _skill_slots.size():
		var slot := _skill_slots[index]
		var id := InventoryService.equipped_skill(index)
		var skill := DataDB.get_skill(id)
		if slot.item_id != str(id):
			slot.item_id = str(id)
			slot.icon = load(str(skill.icon)) if not skill.is_empty() else null
		slot.locked = id != &"" and not InventoryService.skill_unlocked(id)
		slot.mana_blocked = GameState.mana < InventoryService.skill_mana_cost(id) or GameState.sta < InventoryService.skill_stamina_cost(id)
		slot.selected = index == GameState.selected_skill
		slot.tooltip_text = "%s\n体力 %d · 奶力 %d · 冷却 %.1fs" % [skill.get("name","空技能槽"),InventoryService.skill_stamina_cost(id),InventoryService.skill_mana_cost(id),float(skill.get("cooldown",0))]
		slot.cooldown = player.skill_cooldown(id)
		slot.cooldown_ratio = clampf(slot.cooldown/maxf(0.001,float(skill.get("cooldown",1))),0,1)
		slot.queue_redraw()
	var skill_hint := hud.get_node_or_null("SkillHint")
	if skill_hint != null:
		skill_hint.position = Vector2((view_size.x-240)/2,view_size.y-58)
		skill_hint.visible = not _resting and not dialogue_active()
	if mode in ["inventory", "storage"]:
		var signature := _current_inventory_signature()
		if signature != _inventory_signature:
			_inventory_signature = signature
			_refresh_inventory_view()
	if not get_tree().paused:
		GameState.in_combat = _has_nearby_enemy()


func _bind_scene(current: Node) -> void:
	_force_close()
	scene = current
	player = null
	if scene == null or not scene.has_node("Player"):
		return
	player = scene.get_node("Player") as Player
	InventoryService.ensure_state()
	if scene.has_node("HotbarLayer"):
		scene.get_node("HotbarLayer").hide()
	if GameState.current_room == &"camp_01" and scene.has_node("ChestA"):
		scene.get_node("ChestA").visible = not GameState.opened_chests.has(&"camp_supplies")
	_enemy_profiles.clear()
	for child in scene.get_children():
		if child is GameEnemy or child is CombatEnemy:
			_enemy_profiles.append({"id":child.enemy_id,"position":child.origin,"combat":child is CombatEnemy,"patrol_bounds":child.patrol_bounds if child is CombatEnemy else Vector2.ZERO,"spawn_id":child.get_meta("spawn_id",""),"platform_id":child.get_meta("platform_id","")})
	if str(scene.scene_file_path).contains("camp_01"):
		GameState.current_room = &"camp_01"
	if GameState.checkpoint_room == GameState.current_room and GameState.checkpoint_position.size() == 2:
		player.checkpoint_position = Vector2(GameState.checkpoint_position[0], GameState.checkpoint_position[1])
	for index in 3:
		_bars[index].value = float(GameState.get(["hp","sta","mana"][index]))


func _build_hud() -> void:
	hud = Control.new()
	hud.name = "HUD"
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(hud)
	_picture(hud, "res://assets/ui/magic/hud_frame.svg", Rect2(2,2,210,64))
	var portrait := _picture(hud, "res://assets/PROCESSED/characters/CHR-01/v001/frames/CHR-01_player_idle_right_v001_f01.png", Rect2(14,11,39,42))
	var face := AtlasTexture.new()
	face.atlas = portrait.texture
	face.region = Rect2(21,13,27,29)
	portrait.texture = face
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var spec: Array = cfg.layout.bars
	for index in 3:
		var bar := ProgressBar.new()
		bar.position = Vector2(spec[0] + 2, spec[1] + index * int(cfg.layout.bar_gap) + 1)
		bar.size = Vector2(int(spec[2]) - index * 11 - 4, int(spec[3]) - 2)
		bar.show_percentage = false
		bar.add_theme_font_size_override("font_size",1)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_theme_stylebox_override("background", _style(_color("ink")))
		bar.add_theme_stylebox_override("fill", _style(_color(["hp","sta","mana"][index])))
		hud.add_child(bar)
		bar.size = Vector2(int(spec[2]) - index * 11 - 4,int(spec[3]) - 2)
		_bars.append(bar)
		var numbers := _label(hud, "", bar.position - Vector2(0,3), 9)
		numbers.size = bar.size
		numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_bar_labels.append(numbers)
	_coin_label = _label(hud, "", Vector2(14,66), 10, _color("bright_gold"))
	var hotbar: Array = cfg.layout.hotbar
	for index in int(cfg.inventory.hotbar_slots):
		var slot := _slot(hud, "hotbar", index, Vector2(hotbar[0], hotbar[1] + index * (hotbar[2] + hotbar[3])), hotbar[2])
		slot.key_text = str(index + 1)
		_hud_slots.append(slot)
	var skills: Array = cfg.layout.skills
	for index in cfg.skills.size():
		var definition: Dictionary = cfg.skills[index]
		var slot := _slot(hud, "skill_hud", index, Vector2(skills[0] + index * (skills[2] + skills[3]),skills[1]), 32)
		slot.key_text = definition.key
		slot.icon = load("res://assets/ui/magic/skill_%s.svg" % definition.icon) if definition.icon != "" else null
		slot.tooltip_text = str(DataDB.get_skill(StringName(definition.id)).get("desc", ""))
		_skill_slots.append(slot)
	var inventory_hint := _label(hud,"Tab  行囊",Vector2(12,337),10,_color("muted"))
	inventory_hint.name = "InventoryHint"
	var skill_hint := _label(hud,"滚轮选择 · 侧键4施放",Vector2(200,302),9,_color("muted"))
	skill_hint.name = "SkillHint"
	skill_hint.size.x = 240
	skill_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _input(event: InputEvent) -> void:
	if not is_instance_valid(player):
		return
	if dialogue_active():
		var dialogue := get_tree().get_first_node_in_group(&"npc_dialogue")
		dialogue.handle_dialogue_input(event)
		get_viewport().set_input_as_handled()
		return
	if _closing:
		return
	if event.is_action_pressed(&"character_panel"):
		if mode == "character":
			close_menu()
		else:
			open_character()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"inventory"):
		if mode == "inventory":
			close_menu()
		else:
			open_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause"):
		if mode != "":
			close_menu()
		else:
			_show_pause()
		get_viewport().set_input_as_handled()
	elif mode == "" and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		GameState.selected_skill = posmod(GameState.selected_skill+(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1),int(RPGService.config().active_slots))
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"interact") and mode == "":
		if _try_interact():
			_consumed_frame = Engine.get_physics_frames()
			player.clear_action_buffers()
			get_viewport().set_input_as_handled()


## 交互优先标记供角色的 E 键技能缓冲检查。
func interaction_consumed() -> bool:
	return mode != "" or Engine.get_physics_frames() - _consumed_frame < 2


func _try_interact() -> bool:
	if _nearest_fire() != null:
		if not begin_rest() and not GameState.in_combat:
			toast("落地并结束当前动作后可休息")
		return true
	if GameState.current_room == &"camp_01" and scene.has_node("ChestA"):
		var chest := scene.get_node("ChestA") as Node2D
		if not GameState.opened_chests.has(&"camp_supplies") and player.position.distance_to(Vector2(cfg.camp_supplies.ground[0],cfg.camp_supplies.ground[1])) <= float(cfg.rest.range):
			var incoming: Array = cfg.camp_supplies.items
			var snapshot := GameState.inventory.duplicate(true)
			for entry: Dictionary in incoming:
				if not InventoryService.add_item(entry.id, entry.count):
					GameState.inventory = snapshot
					toast("行囊已满，补给箱仍保留")
					return true
			GameState.opened_chests.append(&"camp_supplies")
			chest.hide()
			toast("取得灵火补给 · Tab 查看行囊")
			return true
	var nearest_npc: Node2D
	for npc in get_tree().get_nodes_in_group(&"npc"):
		if npc.has_method("can_interact") and npc.can_interact():
			if nearest_npc == null or player.global_position.distance_to(npc.global_position) < player.global_position.distance_to(nearest_npc.global_position):
				nearest_npc = npc
	if nearest_npc != null:
		return nearest_npc.interact()
	for pickup in get_tree().get_nodes_in_group(&"world_pickups"):
		if player.position.distance_to(pickup.position) <= float(cfg.combat.pick_up_radius):
			pickup.collect()
			return true
	if scene.has_method("interact_nearby"):
		return scene.interact_nearby()
	return false


func _nearest_fire() -> Node2D:
	if not is_instance_valid(player):
		return null
	var fire: Dictionary = cfg.campfires.get(String(GameState.current_room), {})
	if fire.is_empty() or not scene.has_node(str(fire.node)):
		return null
	var ground := Vector2(fire.ground[0], fire.ground[1])
	return scene.get_node(str(fire.node)) if player.position.distance_to(ground) <= float(cfg.rest.range) else null


## 在可用篝火旁坐下，绑定检查点并打开完整休息菜单。
func begin_rest() -> bool:
	if _nearest_fire() == null or mode != "" or not player.is_on_floor():
		return false
	if player.sm.current_name() not in [&"Idle",&"Run",&"Land"]:
		return false
	if GameState.in_combat:
		toast("战斗中暂时无法坐火")
		return false
	var fire: Dictionary = cfg.campfires[String(GameState.current_room)]
	var seat := Vector2(fire.ground[0],fire.ground[1]) + Vector2(cfg.rest.seat_offset[0],cfg.rest.seat_offset[1])
	player.position = seat
	player.velocity = Vector2.ZERO
	# 坐火时将角色收进画面中央，避免左侧休息面板挡住营地坐姿。
	player.cam.global_position = seat
	player.cam.force_update_scroll()
	player.clear_action_buffers()
	player.sm.to(&"Idle")
	player.set_facing(1 if float(fire.ground[0]) >= seat.x else -1)
	player.sprite.flip_h = player.facing < 0
	player.sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	player.sprite.play(&"rest_enter")
	if not player.sprite.animation_finished.is_connected(_on_rest_animation_finished):
		player.sprite.animation_finished.connect(_on_rest_animation_finished)
	_resting = true
	GameState.checkpoint_id = StringName(fire.checkpoint)
	GameState.checkpoint_room = GameState.current_room
	GameState.checkpoint_position = [seat.x,seat.y]
	player.checkpoint_position = seat
	_rest_resources()
	_show_rest()
	var error := SaveSystem.save_game()
	toast("灵火已铭记旅途" if error == OK else "存档未完成，请再次休息")
	return true


func _on_rest_animation_finished() -> void:
	if _resting and not _closing and is_instance_valid(player) and player.sprite.animation == &"rest_enter":
		player.sprite.play(&"rest")


func _rest_resources() -> void:
	GameState.hp = GameState.hp_max
	GameState.sta = GameState.sta_max
	GameState.mana = GameState.mana_max
	player.reset_cooldowns()


func _show_rest() -> void:
	_open_modal("rest", Rect2(20,72,240,282), "res://assets/ui/magic/rest_panel.svg")
	_label(modal, cfg.rest.title, Vector2(32,28), 24, _color("bright_gold"))
	_label(modal, cfg.rest.subtitle, Vector2(34,62), 11, _color("muted"))
	for index in cfg.rest.actions.size():
		var action := str(cfg.rest.actions[index])
		_button(modal, action, Rect2(34,106 + index * 35,172,28), func() -> void: _rest_action(action))
	_label(modal, "已设置复活点 · Esc 离开", Vector2(43,254), 10, _color("muted"))


func _rest_action(action: String) -> void:
	match action:
		"休息":
			_rest_resources()
			_respawn_enemies()
			SaveSystem.save_game()
			toast("生命、体力与奶力已恢复 · 旅途已保存")
		"天赋": _show_talents()
		"仓库": _show_storage()
		"离开": close_menu()


func _show_pause() -> void:
	_open_modal("pause",_rect(RPGService.config().pause.rect),"res://assets/ui/magic/pause_options.svg")
	_label(modal,"旅途暂歇",Vector2(32,22),23,_color("bright_gold"))
	_button(modal,"继续旅途",Rect2(28,87,220,32),close_menu)
	_button(modal,"人物面板  I",Rect2(28,130,220,32),open_character)
	_button(modal,"行囊  Tab",Rect2(28,173,220,32),open_inventory)
	var leave := _button(modal,"保存并返回主菜单",Rect2(28,226,220,32),_return_to_title)
	leave.disabled = GameState.in_combat
	leave.tooltip_text = "战斗结束后可保存并返回" if GameState.in_combat else ""


func _return_to_title() -> void:
	if SaveSystem.save_game() != OK:
		toast("未能完成存档，旅途仍保持打开")
		return
	_force_close()
	SceneRouter.change_scene("res://scenes/main.tscn")


func _save_and_quit() -> void:
	if is_instance_valid(player) and not GameState.in_combat:
		SaveSystem.save_game()
	get_tree().quit()


## Tab 打开背包；同一视图支持独立材料页和装备页。
func open_inventory() -> void:
	if not is_instance_valid(player) or dialogue_active():
		return
	InventoryService.ensure_state()
	_selected = -1
	_page = "inventory"
	_selected_source = "inventory"
	_show_inventory()


func _show_inventory() -> void:
	_open_modal("inventory", _rect(cfg.layout.window), "res://assets/ui/magic/inventory_panel.svg")
	_label(modal, "星旅行囊", Vector2(26,23), 21, _color("bright_gold"))
	_label(modal, "%d 格 · %d 奶币" % [InventoryService.capacity(),GameState.coin], Vector2(169,32), 10, _color("muted"))
	_button(modal, "×", Rect2(548,18,20,22), close_menu)
	for index in 2:
		var page: String = ["inventory","materials"][index]
		_button(modal,["行囊","材料"][index],Rect2(26+index*76,56,68,24),func() -> void: _page = page; _selected_source = page; _selected = -1; _refresh_inventory_view())
	_button(modal,"人物 I",Rect2(178,56,68,24),open_character)
	_details = Control.new()
	_details.position = Vector2(310,65)
	_details.size = Vector2(244,182)
	modal.add_child(_details)
	_bag_hotbar.clear()
	for index in 5:
		var slot := _slot(modal,"hotbar",index,Vector2(150 + index * 46,255),40)
		slot.key_text = str(index + 1)
		_bag_hotbar.append(slot)
	_label(modal,"快捷栏独立存放 · 拖回行囊返还 · 拖动格子整理",Vector2(127,295),10,_color("muted"))
	_refresh_inventory_view()


func _refresh_inventory_view() -> void:
	if not is_instance_valid(modal) or mode not in ["inventory","storage"]:
		return
	_inventory_signature = _current_inventory_signature()
	for slot in _view_slots:
		if is_instance_valid(slot):
			slot.get_parent().remove_child(slot)
			slot.queue_free()
	_view_slots.clear()
	if mode == "storage":
		_refresh_storage()
		return
	for child in modal.get_children():
		if child.name == &"EquipmentInfo" or child.name == &"InventoryScroll":
			modal.remove_child(child)
			child.queue_free()
	var array: Array = GameState.materials if _page == "materials" else GameState.inventory
	var scroll := ScrollContainer.new()
	scroll.name = "InventoryScroll"
	scroll.position = Vector2(26,88)
	scroll.size = Vector2(266,158)
	modal.add_child(scroll)
	var grid := Control.new()
	grid.custom_minimum_size = Vector2(250,ceilf(maxf(16,array.size()) / 4) * 40 - 4)
	scroll.add_child(grid)
	var shown := maxi(16, ceili(float(array.size()) / 4) * 4)
	for index in shown:
		var slot := _slot(grid,_page,index,Vector2((index % 4) * 60, floorf(float(index) / 4) * 40),36)
		slot.locked = _page == "inventory" and index >= InventoryService.capacity()
		if index < array.size() and array[index] is Dictionary:
			_set_item(slot,str(array[index].id),int(array[index].count))
		slot.selected = _selected_source == _page and index == _selected
		_view_slots.append(slot)
	for index in _bag_hotbar.size():
		_update_hotbar(_bag_hotbar[index],index)
	_refresh_details()


func _refresh_details() -> void:
	if not is_instance_valid(_details):
		return
	for child in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	var array: Array = GameState.hotbar if _selected_source == "hotbar" else (GameState.materials if _page == "materials" else GameState.inventory)
	if _selected < 0 or _selected >= array.size() or not array[_selected] is Dictionary:
		return
	var entry: Dictionary = array[_selected]
	var definition := DataDB.get_item(StringName(entry.id))
	_picture(_details,ITEM_ICON % entry.id,Rect2(7,14,44,44))
	_label(_details,str(definition.get("name",entry.id)),Vector2(63,14),16,_color("bright_gold"))
	_label(_details,"持有 %d · 堆叠 %d" % [int(entry.count),int(definition.get("stack",1))],Vector2(63,42),10,_color("muted"))
	_paragraph(_details,str(cfg.item_desc.get(str(entry.id),"")),Rect2(7,71,231,65),12)
	var usable: bool = not (definition.get("effect",{}) as Dictionary).is_empty() and _selected_source != "materials"
	var use := _button(_details,"使用",Rect2(7,144,104,28),_use_selected)
	use.disabled = not usable
	_button(_details,"丢弃",Rect2(122,144,104,28),func() -> void: InventoryService.discard_slot(_selected,_selected_source); _refresh_inventory_view())


func _use_selected() -> void:
	var slot := _selected
	var source := _selected_source
	var array: Array = GameState.hotbar if source == "hotbar" else GameState.inventory
	if slot >= 0 and slot < array.size() and array[slot] is Dictionary and str(array[slot].id) == "milk_bomb" and not _resting:
		_force_close()
	var used := InventoryService.use_hotbar(slot,player) if source == "hotbar" else InventoryService.use_slot(slot,player)
	toast("物品已使用" if used else "当前无需使用，物品已保留")
	_refresh_inventory_view()


func _show_storage() -> void:
	_page = "inventory"
	_open_modal("storage",_rect(cfg.layout.window),"res://assets/ui/magic/inventory_panel.svg")
	_label(modal,"灵火仓库",Vector2(26,23),21,_color("bright_gold"))
	_label(modal,"无限存储 · 点击物品存入 / 取回",Vector2(210,33),10,_color("muted"))
	_button(modal,"返回",Rect2(512,23,46,24),_show_rest)
	_label(modal,"随身行囊",Vector2(29,66),12,_color("muted"))
	_label(modal,"仓库",Vector2(311,66),12,_color("muted"))
	_button(modal,"行囊 / 材料",Rect2(108,61,92,24),func() -> void: _page = "materials" if _page == "inventory" else "inventory"; _refresh_inventory_view())
	_refresh_storage()


func _refresh_storage() -> void:
	for child in modal.get_children():
		if str(child.name).begins_with("StoreScroll"):
			modal.remove_child(child)
			child.queue_free()
	var bag: Array = GameState.materials if _page == "materials" else GameState.inventory
	for side in 2:
		var scroll := ScrollContainer.new()
		scroll.name = "StoreScroll%d" % side
		scroll.position = Vector2(26 + side * 283,94)
		scroll.size = Vector2(252,185)
		modal.add_child(scroll)
		var grid := Control.new()
		var entries: Array = bag if side == 0 else GameState.storage
		grid.custom_minimum_size = Vector2(236,ceilf(maxf(16,entries.size()) / 4) * 46 - 6)
		scroll.add_child(grid)
		for index in maxi(16,ceili(float(entries.size()) / 4) * 4):
			var slot := _slot(grid,_page if side == 0 else "storage",index,Vector2(index % 4 * 58,floorf(float(index) / 4) * 46),40)
			if index < entries.size() and entries[index] is Dictionary:
				_set_item(slot,str(entries[index].id),int(entries[index].count))
			_view_slots.append(slot)


func _show_talents() -> void:
	_open_modal("talents",_rect(cfg.layout.window),"res://assets/ui/magic/inventory_panel.svg")
	_label(modal,"星纹天赋",Vector2(26,23),21,_color("bright_gold"))
	_label(modal,"可用 %d 点 · %d 奶币" % [InventoryService.available_points(),GameState.coin],Vector2(201,32),11,_color("muted"))
	_button(modal,"返回",Rect2(512,23,46,24),_show_rest)
	var branches := ["蛮力","奶术","灵巧"]
	for column in branches.size():
		_label(modal,branches[column],Vector2(36 + column * 181,68),15,_color("accent"))
		for definition: Dictionary in DataDB.talents.values():
			if str(definition.branch) != branches[column]:
				continue
			var id := StringName(definition.id)
			var learned := GameState.talents.has(id)
			var prerequisite := StringName(definition.get("requires",""))
			var allowed := prerequisite == &"" or GameState.talents.has(prerequisite)
			var reserved := not bool(definition.effect.get("enabled",true))
			var text := ("◆ " if learned else "◇ ") + str(definition.name)
			text += "  已学" if learned else "  %d币" % int(definition.cost_coin)
			var button := _button(modal,text,Rect2(26 + column * 181,99 + (int(definition.tier)-1) * 37,170,29),func() -> void: InventoryService.buy_talent(id); _show_talents())
			button.tooltip_text = str(definition.desc) + ("\n需要前置：" + str(DataDB.get_talent(prerequisite).get("name","")) if not allowed else "")
			button.disabled = learned or not allowed or reserved or InventoryService.available_points() < int(definition.cost_point) or GameState.coin < int(definition.cost_coin)
	_button(modal,"重置天赋 · %d 奶币" % int(cfg.inventory.reset_cost),Rect2(194,269,200,26),func() -> void:
		if InventoryService.reset_talents():
			_show_talents())


func _slot_activated(kind: String, index: int) -> void:
	if dialogue_active():
		return
	if kind == "skill_hud":
		GameState.selected_skill = index
		return
	if kind == "hotbar":
		if mode == "":
			InventoryService.use_hotbar(index,player)
			select_hotbar(index)
		elif mode == "inventory":
			_selected_source = "hotbar"
			_selected = index
			_refresh_details()
		return
	if mode == "storage":
		var ok := InventoryService.withdraw(index) if kind == "storage" else InventoryService.deposit(index,kind)
		toast("已存取" if ok else "空间不足或当前格为空")
		_refresh_inventory_view()
	else:
		_selected = index
		_selected_source = kind
		for slot in _view_slots:
			slot.selected = slot.index == _selected
			slot.queue_redraw()
		_refresh_details()


func _slot_dropped(data: Dictionary, kind: String, index: int) -> void:
	var ok := false
	if kind == "hotbar" and data.source == "hotbar":
		ok = InventoryService.move_slot(int(data.index),index,"hotbar")
	elif kind == "hotbar" and data.source == "inventory":
		ok = InventoryService.register_hotbar(str(data.id),index,int(data.index))
	elif data.source == "hotbar" and kind == "inventory":
		ok = InventoryService.unregister_hotbar(int(data.index),index)
	elif data.source == kind and kind in ["inventory","materials"]:
		ok = InventoryService.move_slot(int(data.index),index,kind)
	elif mode == "storage" and kind == "storage" and data.source in ["inventory","materials"]:
		ok = InventoryService.deposit(int(data.index),str(data.source))
	elif mode == "storage" and data.source == "storage" and kind in ["inventory","materials"]:
		ok = InventoryService.withdraw(int(data.index))
	if not ok:
		toast("此物品无法放入该位置")
	_refresh_inventory_view()


## 关闭界面；从子菜单返回休息，离火时播放起身动画后恢复世界。
func close_menu() -> void:
	if _resting and mode != "rest":
		_show_rest()
		return
	if _resting and not _closing:
		_closing = true
		if is_instance_valid(modal):
			modal.hide()
		SaveSystem.save_game()
		player.sprite.play(&"rest_exit")
		await get_tree().create_timer(float(cfg.animation.rest_exit_seconds),true).timeout
		if is_instance_valid(player):
			player.sprite.process_mode = Node.PROCESS_MODE_INHERIT
			player.sprite.play(&"idle")
		_force_close()
	else:
		_force_close()


func _force_close() -> void:
	if is_instance_valid(modal):
		modal.get_parent().remove_child(modal)
		modal.queue_free()
	modal = null
	var dim := root_control.get_node_or_null("Dim") if is_instance_valid(root_control) else null
	if dim != null:
		root_control.remove_child(dim)
		dim.queue_free()
	mode = ""
	_input_lock_until = Engine.get_physics_frames()+2
	_resting = false
	_closing = false
	get_tree().paused = false
	if is_instance_valid(player):
		player.clear_action_buffers()
	_view_slots.clear()
	_bag_hotbar.clear()
	_details = null


func _open_modal(next_mode: String, rect: Rect2, art: String) -> void:
	for npc in get_tree().get_nodes_in_group(&"npc"):
		if npc.has_method("close_interaction"):
			npc.close_interaction()
	_modal_base = rect
	if is_instance_valid(modal):
		root_control.remove_child(modal)
		modal.queue_free()
	if root_control.get_node_or_null("Dim") == null:
		var dim := ColorRect.new()
		dim.name = "Dim"
		dim.color = Color(0,0,0,float(RPGService.config().pause.dim_alpha) if next_mode == "pause" else (0.25 if next_mode == "rest" else 0.74))
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root_control.add_child(dim)
	modal = Control.new()
	modal.name = "Modal"
	modal.position = rect.position + (get_viewport().get_visible_rect().size - Vector2(cfg.layout.screen[0],cfg.layout.screen[1])) / 2
	modal.size = rect.size
	root_control.add_child(modal)
	_picture(modal,art,Rect2(Vector2.ZERO,rect.size))
	mode = next_mode
	get_tree().paused = true
	_view_slots.clear()
	_bag_hotbar.clear()
	_selected = -1 if next_mode != "inventory" else _selected
	player.clear_action_buffers()
	root_control.get_node("Dim").color.a = float(RPGService.config().pause.dim_alpha) if next_mode == "pause" else (0.25 if next_mode == "rest" else 0.74)


## 快捷栏的最后使用格保持放大高亮。
func select_hotbar(index: int) -> void:
	_selected_hotbar = index


## 屏幕短提示；不会创建阻塞确认窗口。
func toast(text: String) -> void:
	_toast_label.text = text
	_toast_time = float(cfg.animation.toast_seconds)
	root_control.move_child(_toast_label,-1)


func _has_nearby_enemy() -> bool:
	for child in scene.get_children():
		if (child is GameEnemy or child is CombatEnemy) and child.hp > 0 and child.position.distance_to(player.position) < float(cfg.combat.rest_block_radius):
			return true
	return false


func _respawn_enemies() -> void:
	for child in scene.get_children():
		if child is GameEnemy or child is CombatEnemy:
			child.queue_free()
	for profile: Dictionary in _enemy_profiles:
		if GameState.defeated_bosses.has(StringName(profile.id)):
			continue
		var path := "res://scenes/enemies/combat_enemy.tscn" if profile.combat else "res://scenes/enemies/enemy.tscn"
		var enemy := (load(path) as PackedScene).instantiate()
		enemy.enemy_id = profile.id
		enemy.position = profile.position
		enemy.target = player
		if profile.combat:
			enemy.patrol_bounds = profile.patrol_bounds
		enemy.set_meta("spawn_id",profile.spawn_id)
		enemy.set_meta("platform_id",profile.platform_id)
		enemy.z_index = 20
		scene.add_child(enemy)


func _on_exp(_amount: int) -> void:
	var growth: Dictionary = cfg.growth
	while GameState.level < int(growth.level_cap) and GameState.exp >= int(growth.cumulative_exp[GameState.level]):
		GameState.level += 1
		GameState.hp_max += int(growth.hp_per_level)
		GameState.mana_max += int(growth.mana_per_level)
		EventBus.level_up.emit(GameState.level)
		toast("等级提升 · 获得 1 天赋点")
	if GameState.level == int(growth.level_cap):
		GameState.exp = mini(GameState.exp,int(growth.cumulative_exp[-1]))


func _on_enemy_died(_id: StringName, _pos: Vector2) -> void:
	GameState.hp = mini(GameState.hp_max,GameState.hp + int(InventoryService.talent_effect("kill_heal_hp")))


func _on_boss_defeated(id: StringName) -> void:
	if not GameState.defeated_bosses.has(id):
		GameState.defeated_bosses.append(id)


func _flash_damage() -> void:
	if not is_instance_valid(hud):
		return
	var tween := create_tween()
	hud.modulate = Color(1,0.6,0.6)
	tween.tween_property(hud,"modulate",Color.WHITE,float(cfg.animation.hit_flash))
	_damage_overlay.modulate.a = 1
	var edge_tween := create_tween()
	edge_tween.tween_property(_damage_overlay,"modulate:a",0.0,float(cfg.animation.hit_flash))


func _current_inventory_signature() -> String:
	return JSON.stringify([GameState.inventory,GameState.hotbar,GameState.materials,GameState.storage,GameState.bag_upgrades,GameState.weapon_id,GameState.equipped_skills])


func _set_item(slot: MagicSlot, id: String, count: int) -> void:
	slot.item_id = id
	slot.amount = count
	slot.icon = load(ITEM_ICON % id) if ResourceLoader.exists(ITEM_ICON % id) else null
	slot.tooltip_text = str(DataDB.get_item(StringName(id)).get("name",id))
	slot.queue_redraw()


func _update_hotbar(slot: MagicSlot, index: int) -> void:
	var entry: Variant = GameState.hotbar[index] if index < GameState.hotbar.size() else null
	var id := str(entry.id) if entry is Dictionary else ""
	slot.item_id = id
	slot.amount = int(entry.count) if entry is Dictionary else 0
	slot.icon = load(ITEM_ICON%id) if id != "" and ResourceLoader.exists(ITEM_ICON%id) else null
	slot.tooltip_text = str(DataDB.get_item(StringName(id)).get("name","")) if id != "" else "将行囊物品拖入此格独立存放"
	slot.queue_redraw()


func _slot(parent: Control, kind: String, index: int, pos: Vector2, length: float) -> MagicSlot:
	var slot := MagicSlot.new()
	slot.kind = kind
	slot.index = index
	slot.position = pos
	slot.size = Vector2.ONE * length
	slot.activated.connect(_slot_activated)
	slot.drop_requested.connect(_slot_dropped)
	parent.add_child(slot)
	return slot


func _picture(parent: Control, path: String, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.texture = load(path)
	image.position = rect.position
	image.size = rect.size
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	image.size = rect.size
	return image


func _label(parent: Control, text: String, pos: Vector2, size: int = 12, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _paragraph(parent: Control, text: String, rect: Rect2, font_size: int = 12, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = true
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.text = text
	label.size = rect.size
	return label


func _button(parent: Control, text: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size",12)
	button.add_theme_color_override("font_color",_color("text"))
	button.add_theme_color_override("font_hover_color",_color("bright_gold"))
	button.add_theme_stylebox_override("normal",_style(_color("slot"),_color("gold")))
	button.add_theme_stylebox_override("hover",_style(Color("#214a51"),_color("bright_gold")))
	button.add_theme_stylebox_override("pressed",_style(_color("ink"),_color("accent")))
	button.add_theme_stylebox_override("disabled",_style(_color("ink"),Color("#44514d")))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _style(fill: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _color(key: String) -> Color:
	return Color(cfg.colors[key])


func _rect(array: Array) -> Rect2:
	return Rect2(array[0],array[1],array[2],array[3])


## I 打开人物面板，装备、属性、技能保持独立于行囊。
func open_character() -> void:
	if not is_instance_valid(player) or dialogue_active():
		return
	if _character == null:
		_character = CharacterPanel.new()
		_character.ui = self
	_character.open("equipment")


## 检查对话是否正在独占交互。
func dialogue_active() -> bool:
	var dialogue := get_tree().get_first_node_in_group(&"npc_dialogue")
	return dialogue != null and dialogue.has_method("is_open") and dialogue.is_open()


## 菜单、对话和关闭后的短保护期禁止角色读取玩法输入。
func gameplay_input_blocked() -> bool:
	return mode != "" or dialogue_active() or Engine.get_physics_frames() < _input_lock_until


## 鼠标指向 HUD 时点击交由界面处理，避免同时挥动武器。
func pointer_over_interface() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and is_instance_valid(root_control) and root_control.is_ancestor_of(hovered)


## 对话结束清除本次按键，防止同一次点击变为普攻或再次交互。
func finish_dialogue_input() -> void:
	_input_lock_until = Engine.get_physics_frames()+2
	if is_instance_valid(player):
		player.clear_action_buffers()


func _exit_tree() -> void:
	# Input 的自定义光标缓存晚于渲染器释放，先解除纹理引用。
	Input.set_custom_mouse_cursor(null,Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null,Input.CURSOR_POINTING_HAND)
	Input.set_custom_mouse_cursor(null,Input.CURSOR_DRAG)
