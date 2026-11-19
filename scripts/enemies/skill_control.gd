class_name SkillControl
extends Node2D
## 技能控制独立于敌人 AI；定身仅锁移动，眩晕暂停动作，首领不吃强制眩晕。
var root_left := 0.0
var stun_left := 0.0
var slow_left := 0.0
var slow_ratio := 1.0
var _stars: SkillArt

## 为敌人施加一次控制，时长和减速来自技能表。
static func apply(target: Node2D, root_seconds: float, slow_seconds: float, slow_pct: float, stun_seconds: float = 0.0) -> void:
	var control := target.get_node_or_null("SkillControl") as SkillControl
	if control == null:
		control = SkillControl.new()
		control.name = "SkillControl"
		target.add_child(control)
	control.root_left = maxf(control.root_left,root_seconds)
	control.slow_left = maxf(control.slow_left,root_seconds+slow_seconds)
	control.slow_ratio = minf(control.slow_ratio,1.0-slow_pct/100.0)
	control.stun_left = maxf(control.stun_left,stun_seconds)
	if stun_seconds > 0 and not is_instance_valid(control._stars):
		var body_height := float(SkillLibrary.presentation().body_center_offset[1])*2
		control._stars = SkillArt.spawn(control,"SKL-N03_stun_stars",Vector2(0,body_height),stun_seconds,1,true)

## 查询是否被眩晕，敌人每帧在 AI 前检查。
static func stunned(target: Node) -> bool:
	var control := target.get_node_or_null("SkillControl") as SkillControl
	return control != null and control.stun_left > 0

## 定身和减速统一影响巡逻、追击及冲锋位移。
static func movement_ratio(target: Node) -> float:
	var control := target.get_node_or_null("SkillControl") as SkillControl
	if control == null:
		return 1.0
	return 0.0 if control.root_left > 0 else control.slow_ratio if control.slow_left > 0 else 1.0

func _physics_process(delta: float) -> void:
	root_left = maxf(0,root_left-delta)
	stun_left = maxf(0,stun_left-delta)
	slow_left = maxf(0,slow_left-delta)
	if stun_left <= 0 and is_instance_valid(_stars):
		_stars.queue_free()
	if root_left <= 0 and stun_left <= 0 and slow_left <= 0:
		queue_free()
