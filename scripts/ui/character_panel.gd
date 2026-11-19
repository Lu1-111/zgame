class_name CharacterPanel
extends RefCounted
## I 人物面板：装备交换、当前属性与三主动二被动装配。
var ui: Node
var page := "equipment"
var gear_page := "weapon"
var selected_weapon := -1
var selected_accessory := &""
var selected_skill := &"skill_comet_dash"
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
			button.modulate = Color(1.16,1.09,0.88)
	ui._button(ui.modal,"×",Rect2(574,18,26,28),ui.close_menu)
	match page:
		"equipment": _equipment()
		"attributes": _attributes()
		"skills": _skills()


func _equipment() -> void:
	RPGSkin.frame(ui.modal,"inset",Rect2(18,100,182,207))
	RPGSkin.frame(ui.modal,"inset",Rect2(438,100,164,207))
	ui._label(ui.modal,"装备详情",Vector2(24,74),13,ui._color("bright_gold"))
	for index in 3:
		var key: String = ["weapon","armor","accessory"][index]
		ui._button(ui.modal,["武器","护甲","饰品"][index],Rect2(216+index*66,73,60,24),func() -> void: gear_page = key; selected_weapon = -1; open("equipment"))
	details = Control.new()
	details.position = Vector2(22,102)
	details.size = Vector2(174,198)
	ui.modal.add_child(details)
	var accessories := gear_page == "accessory"
	if gear_page in ["weapon", "accessory"]:
		var owned := GameState.owned_accessories if accessories else GameState.owned_weapons
		var count := maxi(20, owned.size())
		var scroll := ScrollContainer.new()
		scroll.position = Vector2(211, 104)
		scroll.size = Vector2(217, 202)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		ui.modal.add_child(scroll)
		var grid := Control.new()
		grid.custom_minimum_size = Vector2(204, ceili(count / 5.0) * 47)
		scroll.add_child(grid)
		for index in count:
			var id := owned[index] if index < owned.size() else &""
			var slot := _slot("accessory_inventory" if accessories else "weapon_inventory", index, Vector2((index%5)*41,floorf(index/5.0)*47), 38, grid)
			if accessories:
				_set_accessory(slot, id)
			else:
				_set_weapon(slot, id)
				slot.selected = selected_weapon == index
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
		var slot := _slot("equipment_reserved" if index == 0 else "accessory_equipped", index - 1, Vector2(564,153+index*47),38)
		slot.key_text = ["甲","饰","饰"][index]
		if index == 0:
			slot.locked = true
			slot.tooltip_text = "护甲槽尚未开启"
		else:
			_set_accessory(slot, GameState.equipped_accessories[index - 1])
	ui._label(ui.modal,"拖动武器或饰品装备 · 换下的装备回到列表",Vector2(183,318),10,ui._color("muted"))
	_weapon_details()


func _weapon_details() -> void:
	_clear_details()
	if gear_page == "armor":
		ui._label(details,"此装备槽尚未开启",Vector2(2,28),12,ui._color("muted"))
		return
	var id := GameState.owned_weapons[selected_weapon] if selected_weapon >= 0 and selected_weapon < GameState.owned_weapons.size() else &""
	if selected_weapon == -2:
		id = GameState.weapon_id
	var definition := DataDB.get_accessory(selected_accessory) if gear_page == "accessory" else DataDB.get_weapon(id)
	if definition.is_empty():
		return
	var scroll := ScrollContainer.new()
	scroll.size=details.size
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	details.add_child(scroll)
	var content := VBoxContainer.new()
	content.custom_minimum_size.x=152
	scroll.add_child(content)
	var icon := TextureRect.new()
	icon.texture=load(str(definition.icon))
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size=Vector2(40,36)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	content.add_child(icon)
	_detail_line(content,str(definition.name),14,ui._color("bright_gold"))
	if gear_page == "accessory":
		_detail_line(content, str(definition.effect_description), 11, ui._color("accent"))
		_detail_line(content, str(definition.desc), 11, ui._color("text"))
		return
	_detail_line(content,"攻击力 %d\n削韧倍率 ×%.2f\n攻速倍率 ×%.2f" % [int(definition.attack),float(definition.get("poise_multiplier",1)),float(definition.get("attack_speed_multiplier",1))],11,ui._color("accent"))
	if definition.weapon_type == "rifle":
		_detail_line(content, "射击间隔 %.3f 秒\n每发耗弹 %s%%" % [WeaponAttributes.duration(definition), definition.get("ammo_cost_pct", 0)], 11, ui._color("accent"))
	_detail_line(content,str(definition.desc),11,ui._color("text"))
	if str(definition.get("special_description","无"))!="无":_detail_line(content,str(definition.special_description),10,ui._color("bright_gold"))
	for effect: Dictionary in definition.get("special_effects",[]):
		if not bool(effect.get("implemented",false)):
			var label := str(effect.get("name",{"bleeding":"流血","poison":"中毒"}.get(str(effect.get("id","")),"效果")))
			_detail_line(content,label+"（预留，尚未生效）",10,ui._color("muted"))

func _detail_line(parent: Control,text: String,font_size: int,color: Color) -> void:
	var label := Label.new()
	label.text=text
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x=148
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	parent.add_child(label)


func _attributes() -> void:
	var view := AttributePanel.new()
	view.ui = ui
	view.build(false)


func _skills() -> void:
	RPGSkin.frame(ui.modal,"inset",Rect2(432,70,174,244))
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
	ui._label(ui.modal,"已装配被动",Vector2(340,263),11,ui._color("muted"))
	for index in 3:
		var slot := _slot("active_slot",index,Vector2(186+index*47,284),38)
		_set_skill(slot,InventoryService.equipped_skill(index))
		slot.key_text = str(index+1)
	for index in 2:
		var slot := _slot("passive_slot",index,Vector2(340+index*47,284),38)
		_set_skill(slot,GameState.equipped_passives[index])
		slot.key_text = "被"
	details = Control.new()
	details.position = Vector2(438,75)
	details.size = Vector2(164,235)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.modal.add_child(details)
	ui._label(ui.modal,"拖动已解锁技能至下方槽位 · 滚轮选择主动 · 侧键4施放",Vector2(151,324),9,ui._color("muted"))
	_skill_details()


func _skill_details() -> void:
	_clear_details()
	var definition := DataDB.get_skill(selected_skill)
	if definition.is_empty():
		return
	ui._picture(details,str(definition.icon),Rect2(4,2,34,34))
	ui._paragraph(details,str(definition.name),Rect2(45,2,116,42),12)
	var passive := str(definition.category) == "passive"
	ui._label(details,"被动技能" if passive else ("物理技能" if str(definition.damage_type) == "physical" else "奶术技能"),Vector2(4,47),11,ui._color("accent"))
	var line := "尚未解锁" if not InventoryService.skill_unlocked(selected_skill) else "已习得"
	if not passive and not bool(definition.get("placeholder",false)):
		line += "\n体力 %d · 奶力 %d\n冷却 %.1f 秒" % [InventoryService.skill_stamina_cost(selected_skill),InventoryService.skill_mana_cost(selected_skill),ProgressionService.skill_cooldown(selected_skill)]
		if definition.get("weapon_requirement") != null:
			line += "\n仅限%s" % ("剑" if str(definition.weapon_requirement) == "sword" else "锤")
	ui._label(details,line,Vector2(4,67),10,ui._color("muted"))
	ui._paragraph(details,str(definition.desc),Rect2(4,133,156,104),10)


func _activate(kind: String, index: int) -> void:
	if kind in ["accessory_inventory", "accessory_equipped"]:
		var owned := GameState.owned_accessories if kind == "accessory_inventory" else GameState.equipped_accessories
		selected_accessory = owned[index] if index < owned.size() else &""
		if gear_page != "accessory":
			gear_page = "accessory"
			open(page)
			return
		for slot in _slots:
			slot.selected = slot.kind == kind and slot.index == index
			slot.queue_redraw()
		_weapon_details()
	elif kind in ["weapon_inventory","weapon_equipped"]:
		selected_weapon = index if kind == "weapon_inventory" else -2
		if gear_page != "weapon":
			gear_page = "weapon"
			open(page)
			return
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
	elif kind == "accessory_equipped" and data.source == "accessory_inventory":
		ok = AccessoryRules.swap(int(data.index), index)
	elif kind == "accessory_inventory" and data.source == "accessory_equipped" and (index >= GameState.owned_accessories.size() or GameState.owned_accessories[index] == &""):
		ok = AccessoryRules.swap(index, int(data.index))
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
		slot.icon = RPGSkin.icon_for_path(str(definition.icon))
		slot.tooltip_text = str(definition.name)
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _set_accessory(slot: MagicSlot, id: StringName) -> void:
	slot.item_id = str(id)
	var definition := DataDB.get_accessory(id)
	if not definition.is_empty():
		slot.icon = RPGSkin.icon_for_path(str(definition.icon))
		slot.tooltip_text = str(definition.name)
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _set_skill(slot: MagicSlot, id: StringName) -> void:
	slot.item_id = str(id)
	var definition := DataDB.get_skill(id)
	if not definition.is_empty():
		slot.icon = RPGSkin.icon_for_path(str(definition.icon))
		slot.tooltip_text = str(definition.name)
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _skill_list(passive: bool) -> Array:
	var result := []
	for definition: Dictionary in DataDB.skills.values():
		if str(definition.get("category","active")) == ("passive" if passive else "active"):
			result.append(definition)
	return result


func _slot(kind: String, index: int, pos: Vector2, size: float, parent: Control = null) -> MagicSlot:
	var slot := MagicSlot.new()
	slot.kind = kind
	slot.index = index
	slot.position = pos
	slot.size = Vector2.ONE*size
	slot.activated.connect(_activate)
	slot.drop_requested.connect(_drop)
	if parent == null:
		parent = ui.modal
	parent.add_child(slot)
	_slots.append(slot)
	return slot


func _clear_details() -> void:
	for child in details.get_children():
		details.remove_child(child)
		child.queue_free()
