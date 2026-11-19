extends Control
## 双击启动器后的选图入口；全部A/B均独立可试玩。
const SESSION := preload("res://test/scripts/forest_candidates/session.gd")

func _ready() -> void:
	set_meta("forest_candidate",true)
	set_meta("disable_save",true)
	SESSION.begin(get_tree())
	var bg := ColorRect.new()
	bg.color = Color(SESSION.rules().palette.ink)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	column.theme = Theme.new()
	column.theme.default_font = RPGSkin.font()
	column.theme.default_font_size = 13
	margin.add_child(column)
	var title := Label.new()
	title.text = "森林备选场景 · 实际试玩"
	title.add_theme_font_size_override("font_size",18)
	column.add_child(title)
	var help := Label.new()
	help.text = "五组各两案。可走、可跳、可战斗与解谜；试玩状态独立，不写入旅途存档。"
	help.add_theme_font_size_override("font_size",10)
	column.add_child(help)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var choices := VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation",6)
	scroll.add_child(choices)
	var rows := SESSION.candidates()
	for index in range(0,rows.size(),2):
		var row := HBoxContainer.new()
		choices.add_child(row)
		for offset in 2:
			var item: Dictionary = rows[index+offset]
			var button := Button.new()
			button.text = "%s  %s\n%s" % [item.id,item.title,item.kind]
			button.add_theme_font_size_override("font_size",11)
			button.custom_minimum_size = Vector2(298,32)
			button.pressed.connect(SESSION.enter.bind(get_tree(),str(item.id)))
			row.add_child(button)
	var back := Button.new()
	back.text = "返回正式标题"
	back.pressed.connect(SESSION.finish.bind(get_tree()))
	column.add_child(back)
