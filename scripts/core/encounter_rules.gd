class_name EncounterRules
extends RefCounted
## 战斗感知、平台移动、接触反弹与受击反馈的统一数据入口。
static var _data: Dictionary = {}


## 从数值表读取敌人行为与反馈参数。
static func config() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/encounter_rules.json"))
	return _data
