class_name QuestService
extends RefCounted
## 任务规则只读数据表；进度、领奖和单任务追踪均进入 GameState 存档。
static var _data: Dictionary = {}

## 读取任务及界面配置，示例内容可直接替换而无需修改面板。
static func config() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/quests.json"))
	return _data

static func _state() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("GameState")

## 查找指定任务，未知编号返回空字典。
static func definition(id: StringName) -> Dictionary:
	for quest: Dictionary in config().quests:
		if str(quest.id) == str(id):
			return quest
	return {}

## 接受任务并初始化独立进度，重复接受不会重置完成或领奖状态。
static func accept(id: StringName) -> bool:
	if definition(id).is_empty():
		return false
	var state := _state()
	if not state.quest_state.has(str(id)):
		state.quest_state[str(id)] = {"completed":false,"claimed":false,"counters":{}}
	return true

## 兼容旧存档并实时同步持久世界条件；完成状态只前进不倒退。
static func refresh() -> void:
	var state := _state()
	for quest: Dictionary in config().quests:
		if bool(quest.get("initial",false)):
			accept(StringName(quest.id))
		if not state.quest_state.has(str(quest.id)):
			continue
		var complete := true
		for condition: Dictionary in quest.conditions:
			complete = complete and condition_progress(StringName(quest.id),condition) >= int(condition.count)
		if complete:
			state.quest_state[str(quest.id)].completed = true
	if not definition(state.tracked_quest).is_empty() and state.quest_state.has(str(state.tracked_quest)) and not bool(state.quest_state[str(state.tracked_quest)].get("claimed",false)):
		return
	state.tracked_quest = &""

## 返回条件进度；房间、篝火、宝箱和机关直接读取真实存档，击杀用计数器。
static func condition_progress(id: StringName, condition: Dictionary) -> int:
	var state := _state()
	var target := StringName(str(condition.id))
	match str(condition.kind):
		"visit_room": return 1 if state.visited_rooms.has(target) else 0
		"campfire": return 1 if state.unlocked_campfires.has(target) else 0
		"chest": return 1 if state.opened_chests.has(target) else 0
		"shortcut": return 1 if state.opened_shortcuts.has(target) else 0
		"kill": return int(state.quest_state.get(str(id),{}).get("counters",{}).get("kill:"+str(target),0))
	return 0

## 击杀事件只推进已接受且未完成的任务，避免读取旧敌人状态推测战果。
static func record_kill(enemy_id: StringName) -> void:
	refresh()
	var state := _state()
	for quest: Dictionary in config().quests:
		var progress: Dictionary = state.quest_state.get(str(quest.id),{})
		if progress.is_empty() or bool(progress.get("completed",false)):
			continue
		for condition: Dictionary in quest.conditions:
			if str(condition.kind) == "kill" and str(condition.id) == str(enemy_id):
				var key := "kill:"+str(enemy_id)
				progress.counters[key] = mini(int(condition.count),int(progress.counters.get(key,0))+1)
	refresh()

## 分类筛选按主线、支线、探索固定顺序，同类保持数据表顺序。
static func list_quests(category: String = "all") -> Array:
	refresh()
	var result: Array = []
	for kind: String in config().category_order:
		if category != "all" and category != kind:
			continue
		for quest: Dictionary in config().quests:
			if str(quest.category) == kind and _state().quest_state.has(str(quest.id)):
				result.append(quest)
	return result

## 切换为唯一追踪任务；再次点击同一个任务即取消追踪。
static func toggle_tracking(id: StringName) -> bool:
	refresh()
	var state := _state()
	if definition(id).is_empty() or not state.quest_state.has(str(id)) or bool(state.quest_state[str(id)].get("claimed",false)):
		return false
	state.tracked_quest = &"" if state.tracked_quest == id else id
	return true

## 查询当前追踪任务；无追踪或旧编号失效时返回空字典。
static func tracked() -> Dictionary:
	return definition(_state().tracked_quest)

## 条件清单供 HUD、任务页与地图共用，避免三处显示不同进度。
static func objective_text(id: StringName) -> String:
	var quest := definition(id)
	var lines := PackedStringArray()
	for condition: Dictionary in quest.get("conditions",[]):
		var amount := mini(int(condition.count),condition_progress(id,condition))
		lines.append("%s  %d / %d" % [condition.text,amount,int(condition.count)])
	return "\n".join(lines)

## 显示任务奖励；当前示例使用奶币和经验值。
static func reward_text(id: StringName) -> String:
	var rewards: Dictionary = definition(id).get("rewards",{})
	return "奶币 %d   ·   经验 %d" % [int(rewards.get("coin",0)),int(rewards.get("exp",0))]

## 奖励只能结算一次，先锁定领奖状态再发事件以防重入。
static func claim(id: StringName) -> bool:
	refresh()
	if definition(id).is_empty():
		return false
	var state := _state()
	var progress: Dictionary = state.quest_state.get(str(id),{})
	if progress.is_empty() or not bool(progress.get("completed",false)) or bool(progress.get("claimed",false)):
		return false
	progress.claimed = true
	var rewards: Dictionary = definition(id).get("rewards",{})
	state.coin += int(rewards.get("coin",0))
	state.exp += int(rewards.get("exp",0))
	if state.tracked_quest == id:
		state.tracked_quest = &""
	var events := (Engine.get_main_loop() as SceneTree).root.get_node("EventBus")
	events.emit_signal("coin_changed",state.coin)
	events.emit_signal("exp_gained",int(rewards.get("exp",0)))
	return true
