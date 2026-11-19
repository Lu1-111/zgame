class_name StoragePanel
extends RefCounted
## 两侧分类独立，点击整个堆叠直接存取，无限仓库纵向滚动。
var ui: Node
var pages := ["all","all"]
var _content: Control

## 建立左右分类、物品格和容量提示。
func build() -> void:
	refresh()

## 物品变化后保留两侧页签重新绘制。
func refresh() -> void:
	if is_instance_valid(_content):
		_content.get_parent().remove_child(_content)
		_content.queue_free()
	_content = Control.new()
	_content.name = "StorageContent"
	ui.modal.add_child(_content)
	var sets := [StorageService.bag_entries(),StorageService.stored_entries()]
	var categories: Array = ProgressionService.config().storage_categories
	for side in 2:
		var x := 26+side*294
		ui._label(_content,"随身背包" if side == 0 else "仓库 · 无限容量",Vector2(x,53),13,ui._color("bright_gold"))
		for index in categories.size():
			var key := str(categories[index][0])
			var selected_side := side
			var button: Button = ui._button(_content,str(categories[index][1]),Rect2(x+index*53,78,50,24),func() -> void: pages[selected_side] = key; refresh())
			button.name = "Category_%d_%s" % [side,key]
			button.modulate = Color(1.2,1.12,0.8) if pages[side] == key else Color.WHITE
		var entries: Array = []
		for entry: Dictionary in sets[side]:
			if pages[side] == "all" or pages[side] == str(entry.category):
				entries.append(entry)
		var scroll := ScrollContainer.new()
		scroll.name = "StoreScroll%d" % side
		scroll.position = Vector2(x,112)
		scroll.size = Vector2(270,192)
		_content.add_child(scroll)
		var grid := Control.new()
		var count := maxi(16,ceili(float(entries.size()+1)/4)*4)
		grid.custom_minimum_size = Vector2(252,ceilf(float(count)/4)*48)
		scroll.add_child(grid)
		for index in count:
			var slot := MagicSlot.new()
			slot.kind = "warehouse_entry"
			slot.position = Vector2(index%4*64,floorf(float(index)/4)*48)
			slot.size = Vector2(42,42)
			grid.add_child(slot)
			if index >= entries.size():
				continue
			var entry: Dictionary = entries[index]
			var definition: Dictionary = DataDB.get_weapon(StringName(entry.id)) if entry.category == "weapon" else DataDB.get_item(StringName(entry.id))
			slot.item_id = str(entry.id)
			slot.amount = int(entry.count)
			slot.icon = RPGSkin.icon_for_path(str(definition.get("icon",ui.ITEM_ICON % entry.id)))
			slot.tooltip_text = "%s ×%d\n点击%s" % [definition.get("name",entry.id),entry.count,"存入仓库" if side == 0 else "取回背包"]
			slot.activated.connect(func(_kind: String, _index: int) -> void: _transfer(entry))
	ui._label(_content,"点击物品存取整格 · 背包空间不足时保留在仓库",Vector2(26,320),10,ui._color("muted"))

func _transfer(entry: Dictionary) -> void:
	var ok := StorageService.transfer(entry)
	ui.toast("已存取" if ok else "背包已满，物品仍在仓库")
	refresh()
