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


func _init(p_amount := 0, p_type: int = DamageType.PHYSICAL, p_knockback := 160.0,
		p_from := Vector2.ZERO, p_source: StringName = &"") -> void:
	amount = p_amount
	type = p_type
	knockback = p_knockback
	from_position = p_from
	source_id = p_source
