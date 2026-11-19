class_name QuestPanel
extends RefCounted
## 左侧分类列表、右侧详情，状态变化只重建详情，不打断列表滚动。
var ui: Node
var category := "all"
var selected: StringName = &""
var _details: Control
var _list_buttons: Dictionary = {}

## 打开任务面板并沿用全局模态、暂停和当前界面样式。
func open() -> void:
	ui._open_modal("quests",ui._rect(QuestService.config().ui.panel),"")
	_list_buttons.clear()
	ui._label(ui.modal,"旅途纪事",Vector2(24,16),22,ui._color("bright_gold"))
	ui._button(ui.modal,"关闭",Rect2(540,20,48,24),ui.close_menu)
	var tabs := ["all","main","side","exploration"]
	for index in tabs.size():
		var key: String = tabs[index]
		var button: Button = ui._button(ui.modal,str(QuestService.config().categories[key]),Rect2(20+index*66,62,62,26),func() -> void: category = key; open())
		button.toggle_mode = true
		button.button_pressed = category == key
		button.add_theme_color_override("font_color",ui._color("bright_gold") if category == key else ui._color("muted"))
	RPGSkin.frame(ui.modal,"inset",Rect2(18,94,268,204))
	RPGSkin.frame(ui.modal,"inset",Rect2(300,62,290,236))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(22,100)
	scroll.size = Vector2(260,192)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.modal.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",5)
	scroll.add_child(list)
	var quests := QuestService.list_quests(category)
	var selected_visible := false
	for quest: Dictionary in quests:
		selected_visible = selected_visible or str(quest.id) == str(selected)
	if not selected_visible:
		selected = StringName(quests[0].id) if not quests.is_empty() else &""
	for quest: Dictionary in quests:
		var id := StringName(quest.id)
		var state: Dictionary = ui.get_tree().root.get_node("GameState").quest_state[str(id)]
		var suffix := " · 已领取" if bool(state.claimed) else " · 可领取" if bool(state.completed) else ""
		var button := Button.new()
		button.name = "Quest_"+str(id)
		button.text = "【%s】%s%s" % [QuestService.config().categories[quest.category],quest.name,suffix]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(250,35)
		button.add_theme_font_size_override("font_size",11)
		RPGSkin.dress_button(button)
		button.toggle_mode = true
		button.pressed.connect(func() -> void: selected = id; _show_details())
		list.add_child(button)
		_list_buttons[str(id)] = button
	_details = Control.new()
	_details.position = Vector2(312,72)
	_details.size = Vector2(266,220)
	ui.modal.add_child(_details)
	ui._label(ui.modal,"L / Esc 返回",Vector2(26,304),10,ui._color("muted"))
	_show_details()

func _show_details() -> void:
	for id: String in _list_buttons:
		_list_buttons[id].set_pressed_no_signal(id == str(selected))
	for child in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	var quest := QuestService.definition(selected)
	if quest.is_empty():
		ui._label(_details,"此分类暂无任务",Vector2(12,32),12,ui._color("muted"))
		return
	var scroll := ScrollContainer.new()
	scroll.position = Vector2.ZERO
	scroll.size = Vector2(266,168)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_details.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",8)
	scroll.add_child(column)
	_text(column,str(quest.name),18,ui._color("bright_gold"))
	_text(column,str(quest.description),11,ui._color("text"))
	_text(column,"任务条件",12,ui._color("bright_gold"))
	_text(column,QuestService.objective_text(selected),11,ui._color("text"))
	_text(column,"奖励 · "+QuestService.reward_text(selected),11,ui._color("bright_gold"))
	var state: Node = ui.get_tree().root.get_node("GameState")
	var progress: Dictionary = state.quest_state[str(selected)]
	var track: Button = ui._button(_details,"取消追踪" if state.tracked_quest == selected else "追踪",Rect2(0,178,128,29),func() -> void: QuestService.toggle_tracking(selected); _show_details())
	track.name = "TrackQuest"
	track.disabled = bool(progress.claimed)
	if bool(progress.completed):
		var claim: Button = ui._button(_details,"已领取" if bool(progress.claimed) else "领取奖励",Rect2(138,178,128,29),func() -> void: QuestService.claim(selected); open())
		claim.disabled = bool(progress.claimed)

func _text(parent: Control, text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_font_override("font",RPGSkin.font())
	parent.add_child(label)
