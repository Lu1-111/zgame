class_name CharacterPanel
extends RefCounted
## I 人物面板：装备交换、当前属性与三主动二被动装配。
var ui: Node
var page := "equipment"
var gear_page := "weapon"
var selected_weapon := -1
var selected_skill := &"skill_bubble"
var details: Control
var _slots: Array[MagicSlot] = []


## 打开指定页签，沿用全局模态暂停与主题。
func open(next_page: String = "equipment") -> void:
	if ui.dialogue_active():
		return
	page = next_page
	RPGService.ensure_state()
	ui._open_modal("character",ui._rect(RPGService.config().panel_rect),"res://assets/ui/magic/rpg_panel.svg")
	_slots.clear()
	for index in 3:
		var key: String = ["equipment","attributes","skills"][index]
		var button: Button = ui._button(ui.modal,["装备","属性","技能"][index],Rect2(24+index*174,17,162,30),func() -> void: open(key))
		if page == key:
			button.add_theme_stylebox_override("normal",ui._style(Color("#31514e"),Color("#ead6a0")))
	ui._button(ui.modal,"×",Rect2(574,18,26,28),ui.close_menu)
	match page:
		"equipment": _equipment()
		"attributes": _attributes()
		"skills": _skills()


func _equipment() -> void:
	ui._label(ui.modal,"装备详情",Vector2(24,74),13,ui._color("bright_gold"))
	for index in 3:
		var key: String = ["weapon","armor","accessory"][index]
		ui._button(ui.modal,["武器","护甲","饰品"][index],Rect2(216+index*66,73,60,24),func() -> void: gear_page = key; selected_weapon = -1; open("equipment"))
	details = Control.new()
	details.position = Vector2(22,102)
	details.size = Vector2(174,198)
	ui.modal.add_child(details)
	for index in 16:
		var slot := _slot("weapon_inventory",index,Vector2(216+(index%4)*48,109+floorf(index/4.0)*47),40)
		if gear_page == "weapon":
			var id := GameState.owned_weapons[index] if index < GameState.owned_weapons.size() else &""
			_set_weapon(slot,id)
			slot.selected = selected_weapon == index
		else:
			slot.locked = true
	ui._label(ui.modal,"人物",Vector2(450,75),13,ui._color("bright_gold"))
	var portrait := AnimatedSprite2D.new()
	portrait.sprite_frames = load("res://assets/PROCESSED/characters/CHR-01/v001/godot/CHR-01_sprite_frames.tres")
	portrait.position = Vector2(492,192)
	portrait.scale = Vector2.ONE*1.7
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ui.modal.add_child(portrait)
	portrait.play(&"idle")
	ui._label(ui.modal,"Lv.%d  奶龙" % GameState.level,Vector2(453,257),12,ui._color("bright_gold"))
	var equipped := _slot("weapon_equipped",0,Vector2(564,106),38)
	_set_weapon(equipped,GameState.weapon_id)
	equipped.tooltip_text = "武器 · 拖入替换，拖回格子卸下"
	for index in 3:
		var slot := _slot("equipment_reserved",index,Vector2(564,153+index*47),38)
		slot.locked = true
		slot.key_text = ["甲","饰","饰"][index]
		slot.tooltip_text = "护甲槽尚未开启" if index == 0 else "饰品槽尚未开启"
	ui._label(ui.modal,"拖动武器装备或交换 · 换下的武器回到格子",Vector2(183,318),10,ui._color("muted"))
	_weapon_details()


func _weapon_details() -> void:
	_clear_details()
	if gear_page != "weapon":
		ui._label(details,"此装备槽尚未开启",Vector2(2,28),12,ui._color("muted"))
		return
	var id := GameState.owned_weapons[selected_weapon] if selected_weapon >= 0 and selected_weapon < GameState.owned_weapons.size() else &""
	if selected_weapon == -2:
		id = GameState.weapon_id
	var definition := DataDB.get_weapon(id)
	if definition.is_empty():
		return
	ui._picture(details,str(definition.icon),Rect2(2,2,40,40))
	ui._paragraph(details,str(definition.name),Rect2(48,3,120,42),14,ui._color("bright_gold"))
	var types := {"sword":"剑 · 近战物理","hammer":"锤 · 近战物理","bow":"弓 · 蓄力远程","staff":"杖 · 远程奶术"}
	ui._label(details,str(types.get(str(definition.weapon_type),"武器")),Vector2(2,53),11,ui._color("accent"))
	ui._label(details,"武器攻击力  %d" % int(definition.attack),Vector2(2,79),12)
	ui._paragraph(details,str(definition.desc),Rect2(2,108,169,85),11,ui._color("text"))


func _attributes() -> void:
	var stats := RPGService.stats()
	ui._label(ui.modal,"Lv.%d  奶族先锋" % GameState.level,Vector2(30,78),19,ui._color("bright_gold"))
	var progress := RPGService.experience_progress()
	var bar := ProgressBar.new()
	bar.position = Vector2(222,86)
	bar.size = Vector2(350,16)
	bar.max_value = progress.y
	bar.value = progress.x
	bar.show_percentage = false
	bar.add_theme_font_size_override("font_size",8)
	bar.add_theme_stylebox_override("background",ui._style(ui._color("ink"),ui._color("gold")))
	bar.add_theme_stylebox_override("fill",ui._style(Color("#698eab")))
	ui.modal.add_child(bar)
	ui._label(ui.modal,"本级经验  %d / %d" % [progress.x,progress.y],Vector2(226,120),10,ui._color("muted"))
	var rows := [["生命值","%d / %d" % [GameState.hp,GameState.hp_max]],["体力值","%d / %d" % [GameState.sta,GameState.sta_max]],["奶力值","%d / %d" % [GameState.mana,GameState.mana_max]],["物理攻击力",str(stats.physical_attack)],["奶术攻击力",str(stats.magic_attack)],["防御力","%.0f" % stats.defense],["伤害减免","%.1f %%" % stats.damage_reduction],["吸血","%.1f %%" % stats.life_steal],["生命恢复","%.2f 点/秒" % stats.hp_regen],["奶力回复","%.2f 点/秒" % stats.mana_regen]]
	for index in rows.size():
		var col := int(index/5.0)
		var row := index%5
		var x := 30+int(col)*294
		var y := 145+row*34
		ui._label(ui.modal,str(rows[index][0]),Vector2(x,y),12,ui._color("muted"))
		ui._label(ui.modal,str(rows[index][1]),Vector2(x+139,y),12,ui._color("bright_gold"))
	ui._label(ui.modal,"属性随等级、武器、天赋与已装备被动实时生效",Vector2(174,320),10,ui._color("muted"))


func _skills() -> void:
	ui._label(ui.modal,"主动技能",Vector2(28,74),13,ui._color("bright_gold"))
	ui._label(ui.modal,"被动技能",Vector2(240,74),13,ui._color("bright_gold"))
	for passive in [false,true]:
		var definitions := _skill_list(passive)
		for index in definitions.size():
			var definition: Dictionary = definitions[index]
			var slot := _slot("passive_skill" if passive else "active_skill",index,Vector2((240 if passive else 28)+(index%4)*46,104+floorf(index/4.0)*47),38)
			_set_skill(slot,StringName(definition.id))
			slot.locked = not InventoryService.skill_unlocked(StringName(definition.id))
			slot.selected = str(selected_skill) == str(definition.id)
	ui._label(ui.modal,"已装配主动",Vector2(185,263),11,ui._color("muted"))
	ui._label(ui.modal,"已装配被动",Vector2(387,263),11,ui._color("muted"))
	for index in 3:
		var slot := _slot("active_slot",index,Vector2(186+index*47,284),38)
		_set_skill(slot,InventoryService.equipped_skill(index))
		slot.key_text = str(index+1)
	for index in 2:
		var slot := _slot("passive_slot",index,Vector2(388+index*47,284),38)
		_set_skill(slot,GameState.equipped_passives[index])
		slot.key_text = "被"
	details = Control.new()
	details.position = Vector2(438,75)
	details.size = Vector2(164,181)
	ui.modal.add_child(details)
	ui._label(ui.modal,"拖动已解锁技能至下方槽位 · 滚轮选择主动 · 侧键4施放",Vector2(151,324),9,ui._color("muted"))
	_skill_details()


func _skill_details() -> void:
	_clear_details()
	var definition := DataDB.get_skill(selected_skill)
	if definition.is_empty():
		return
	ui._picture(details,str(definition.icon),Rect2(4,2,34,34))
	ui._label(details,str(definition.name),Vector2(45,4),13,ui._color("bright_gold"))
	var passive := str(definition.category) == "passive"
	ui._label(details,"被动技能" if passive else ("物理技能" if str(definition.damage_type) == "physical" else "奶术技能"),Vector2(4,47),11,ui._color("accent"))
	var line := "尚未解锁" if not InventoryService.skill_unlocked(selected_skill) else "已习得"
	if not passive and not bool(definition.get("placeholder",false)):
		line += "\n体力 %d · 奶力 %d\n冷却 %.1f 秒" % [InventoryService.skill_stamina_cost(selected_skill),InventoryService.skill_mana_cost(selected_skill),float(definition.cooldown)]
	ui._label(details,line,Vector2(4,67),10,ui._color("muted"))
	ui._paragraph(details,str(definition.desc),Rect2(4,119,156,80),11)


func _activate(kind: String, index: int) -> void:
	if kind in ["weapon_inventory","weapon_equipped"]:
		selected_weapon = index if kind == "weapon_inventory" else -2
		for slot in _slots:
			slot.selected = slot.kind == kind and slot.index == index
			slot.queue_redraw()
		_weapon_details()
	elif kind in ["active_skill","passive_skill"]:
		selected_skill = StringName(_skill_list(kind == "passive_skill")[index].id)
		for slot in _slots:
			slot.selected = slot.item_id == str(selected_skill)
			slot.queue_redraw()
		_skill_details()
	elif kind in ["active_slot","passive_slot"]:
		selected_skill = GameState.equipped_passives[index] if kind == "passive_slot" else InventoryService.equipped_skill(index)
		_skill_details()


func _drop(data: Dictionary, kind: String, index: int) -> void:
	var ok := false
	if kind == "weapon_equipped" and data.source == "weapon_inventory":
		ok = RPGService.equip_weapon(int(data.index))
	elif kind == "weapon_inventory" and data.source == "weapon_equipped":
		ok = RPGService.unequip_weapon(index)
	elif kind == "weapon_inventory" and data.source == "weapon_inventory":
		ok = RPGService.move_weapon(int(data.index),index)
	elif kind in ["active_slot","passive_slot"]:
		ok = RPGService.equip_skill(StringName(data.id),index,kind == "passive_slot")
	if ok:
		if kind in ["weapon_equipped","weapon_inventory"]:
			ui.player.cancel_weapon_action()
		open(page)
	else:
		ui.toast("此装备或技能无法放入该槽位")


func _set_weapon(slot: MagicSlot, id: StringName) -> void:
	slot.item_id = str(id)
	var definition := DataDB.get_weapon(id)
	if not definition.is_empty():
		slot.icon = load(definition.icon)
		slot.tooltip_text = str(definition.name)


func _set_skill(slot: MagicSlot, id: StringName) -> void:
	slot.item_id = str(id)
	var definition := DataDB.get_skill(id)
	if not definition.is_empty():
		slot.icon = load(definition.icon)
		slot.tooltip_text = str(definition.name)


func _skill_list(passive: bool) -> Array:
	var result := []
	for definition: Dictionary in DataDB.skills.values():
		if str(definition.get("category","active")) == ("passive" if passive else "active"):
			result.append(definition)
	return result


func _slot(kind: String, index: int, pos: Vector2, size: float) -> MagicSlot:
	var slot := MagicSlot.new()
	slot.kind = kind
	slot.index = index
	slot.position = pos
	slot.size = Vector2.ONE*size
	slot.activated.connect(_activate)
	slot.drop_requested.connect(_drop)
	ui.modal.add_child(slot)
	_slots.append(slot)
	return slot


func _clear_details() -> void:
	for child in details.get_children():
		details.remove_child(child)
		child.queue_free()
