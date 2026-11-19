class_name CampfireService
extends RefCounted
## 篝火解锁与旅行落点共用同一配置，不以房间是否到访替代互动记录。

## 返回篝火的显示位置及安全站立落点，不恢复资源或刷新敌人。
static func destination(room_id: StringName) -> Dictionary:
	var config: Dictionary = InventoryService.config()
	var fire: Dictionary = config.campfires.get(str(room_id),{})
	if fire.is_empty():
		return {}
	var offset: Array = config.rest.seat_offset
	return {"room":str(room_id),"checkpoint":str(fire.checkpoint),"ground":fire.ground,"position":[fire.ground[0]+offset[0],fire.ground[1]+offset[1]]}

## 校验存档解锁和房间配置，拒绝伪造或未解锁的旅行目标。
static func is_unlocked(room_id: StringName, checkpoint: StringName) -> bool:
	var fire := destination(room_id)
	return not fire.is_empty() and str(fire.checkpoint) == str(checkpoint) and GameState.unlocked_campfires.has(checkpoint)
