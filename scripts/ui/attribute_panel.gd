class_name AttributePanel
extends RefCounted
## 属性页与灵火点数页共用布局；只有灵火点数页有操作按钮。
var ui: Node
var _content: Control
var _editable := false

## 左侧点数、右侧基础属性；人物菜单同时显示各项额外加成。
func build(editable: bool) -> void:
	_editable = editable
	ProgressionService.ensure_state()
	if is_instance_valid(_content):
		_content.get_parent().remove_child(_content)
		_content.queue_free()
	_content = Control.new()
	_content.name = "AttributesContent"
	ui.modal.add_child(_content)
	var layout: Dictionary = ProgressionService.config().panel
	var left := float(layout.left_x)
	var right := float(layout.right_x)
	ui._label(_content,"成长点数",Vector2(left,58),14,ui._color("bright_gold"))
	ui._label(_content,"基础属性" if editable else "当前属性 · 基础值（加成值）",Vector2(right,58),13,ui._color("bright_gold"))
	var specs: Array = ProgressionService.config().attributes
	for index in specs.size():
		var spec: Dictionary = specs[index]
		var y := float(layout.top)+index*float(layout.point_gap)
		var rank := int(GameState.attribute_points.get(spec.id,0))
		ui._label(_content,"%s   %d" % [spec.name,rank],Vector2(left,y),14)
		ui._label(_content,str(spec.description),Vector2(left,y+22),10,ui._color("muted"))
		if editable:
			var id := str(spec.id)
			var button: Button = ui._button(_content,"+",Rect2(left+232,y,28,26),func() -> void: _allocate(id))
			button.name = "Allocate_"+id
			button.disabled = GameState.milk_energy < int(ProgressionService.config().point_cost)
	var values := ProgressionService.breakdown()
	var rows: Array = ProgressionService.config().stat_rows
	for index in rows.size():
		var row: Array = rows[index]
		var text := "%s：%s" % [row[1],_number(float(values.base[row[0]]))]
		if not editable:
			var bonus := float(values.bonus[row[0]])
			text += "（%s%s）" % ["+" if bonus >= 0 else "",_number(bonus)]
		text += str(row[2])
		var line: Label = ui._label(_content,text,Vector2(right,float(layout.top)+index*float(layout.attribute_gap)),12)
		line.name = "Stat_"+str(row[0])
	ui._label(_content,"可用奶能：%d" % GameState.milk_energy,Vector2(left,302),13,ui._color("bright_gold"))
	ui._label(_content,"每次升级获得 1 奶能 · 每提升一级消耗 1 奶能" if editable else "此处仅查看点数 · 请在灵火天赋菜单加点",Vector2(left,325),10,ui._color("muted"))
	ui._label(_content,"Lv.%d" % GameState.level,Vector2(right,308),12,ui._color("accent"))

func _allocate(id: String) -> void:
	if ProgressionService.allocate(id,_editable):
		build(true)
	else:
		ui.toast("奶能不足，或当前未在灵火休息")

func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value,roundf(value)) else ("%.2f" % value).trim_suffix("0").trim_suffix("0")
