class_name DamagePacket
extends RefCounted
## 统一伤害包（参考书 §3.3 命中流程）：Hitbox/投射物携带 → Hurtbox.receive_hit 结算。
## 结算责任划分：来源方只填"基础值"，减防/抗性/格挡/无敌由受击方的回调负责。

enum DamageType { PHYSICAL, MAGIC }

var amount := 0                    ## 基础伤害（未乘受击方减伤/抗性）
var type: int = DamageType.PHYSICAL
var knockback := 160.0             ## 击退初速（px/s）
var from_position := Vector2.ZERO  ## 攻击来源位置（用于击退方向）
var source_id: StringName = &""    ## 来源标识（武器/技能/敌人 id，供抗性查询）
var ignore_defense := false        ## 拔刀只忽略防御，抗性仍正常计算
var non_interrupting := false      ## 控制语义兼容标记；是否硬直统一服从韧性池。
var skill_proc_handled := false    ## 新技能由每次施放统一结算回奶
var origin_actor: Node = null      ## 原始攻击者，用于镜返精确反弹给来源
var poise_key: StringName = &""    ## 精确到普攻段或技能命中阶段的削韧表键。
var normal_poise := -1.0           ## 普攻按武器类型和倍率冻结；负数仍读取独立技能/旧表。
var weapon_ticket: WeaponAttackTicket = null

## 每个受击目标使用独立包，破防加伤不污染同一攻击的其他目标。
func copy_for_target() -> DamagePacket:
	var result := DamagePacket.new(amount,type,knockback,from_position,source_id)
	result.ignore_defense=ignore_defense
	result.non_interrupting=non_interrupting
	result.skill_proc_handled=skill_proc_handled
	result.origin_actor=origin_actor
	result.poise_key=poise_key
	result.normal_poise=normal_poise
	result.weapon_ticket=weapon_ticket
	return result


func _init(p_amount := 0, p_type: int = DamageType.PHYSICAL, p_knockback := 160.0,
		p_from := Vector2.ZERO, p_source: StringName = &"") -> void:
	amount = p_amount
	type = p_type
	knockback = p_knockback
	from_position = p_from
	source_id = p_source
