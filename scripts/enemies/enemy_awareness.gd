class_name EnemyAwareness
extends RefCounted
## 限定同层视野并检查遮挡；地面移动按实际脚下碰撞而非单个平台编号判断。


## 判断目标是否在近距离、允许高度和无遮挡视线内。
static func can_sense(body: CharacterBody2D, target: Node2D, center_offset: Vector2, flying: bool, retaining: bool = false) -> bool:
	if not is_instance_valid(target):
		return false
	var cfg: Dictionary = EncounterRules.config().perception
	var start := body.global_position+center_offset
	var end := target.global_position
	var range_limit := float(cfg.lose_range if retaining else cfg.detect_range)
	var vertical := float(cfg.fly_vertical_range if flying else (cfg.ground_lose_vertical_range if retaining else cfg.ground_vertical_range))
	if start.distance_to(end) > range_limit or absf(start.y-end.y) > vertical:
		return false
	var query := PhysicsRayQueryParameters2D.create(start,end,int(cfg.line_of_sight_mask),[body.get_rid()])
	return body.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## 在身体前沿向下探测支撑；相邻实心和空心平台组成同一可通行表面。
static func has_support_ahead(body: CharacterBody2D, direction: float, width: float) -> bool:
	if not body.is_on_floor() or is_zero_approx(direction):
		return true
	var cfg: Dictionary = EncounterRules.config().navigation
	var foot := body.global_position+Vector2(signf(direction)*(width/2+float(cfg.floor_probe_ahead)),0)
	var query := PhysicsRayQueryParameters2D.create(foot+Vector2.UP*float(cfg.floor_probe_above),foot+Vector2.DOWN*float(cfg.floor_probe_below),129,[body.get_rid()])
	return not body.get_world_2d().direct_space_state.intersect_ray(query).is_empty()
