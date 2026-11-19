class_name DamageFeedback
extends RefCounted
## 只根据实际损失生命分级；免伤、护盾吸收及过量伤害不计入强度。
static var _config: Dictionary = {}

## 读取共用危险预警与玩家受击表现数据。
static func config() -> Dictionary:
	if _config.is_empty():
		_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_feedback.json"))
	return _config

## 5%生命上限以内为轻受击，超过为重受击，零损失不播放。
static func for_loss(loss: int, maximum: int) -> Dictionary:
	if loss <= 0 or maximum <= 0:
		return {}
	var cfg: Dictionary = config().player_hit
	return cfg.light if float(loss) <= float(maximum)*float(cfg.light_threshold) else cfg.heavy
