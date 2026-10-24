class_name CombatMath
extends RefCounted
## 战斗纯函数集（参考书 §3.3 伤害公式 / §3.1 格挡规则）。
## 刻意不含任何 autoload 引用：--script 测试模式可直接加载（tests/test_player.gd 依赖此约束）。

const GUARD_DAMAGE_REDUCTION := 0.6  ## 防御减伤 60%
const GUARD_REFLECT := 0.3           ## 完美格挡反弹 30%


## 伤害公式：最终伤害 = (武器攻击 + 8 + 2×(等级-1)) × 技能倍率。
static func compute_attack(weapon_attack: int, level: int, mult: float = 1.0) -> int:
	return int(float(weapon_attack + 8 + 2 * (level - 1)) * mult)


## 格挡三档结算：
## - 完美格挡：0 伤害 + 反弹 30% + 不耗体力
## - 普通格挡：扣 amount×1.2 体力、减伤 60%
## - 体力不足：破防，吃全额
## 返回 {damage, sta_cost, sta_left, break_guard, perfect, reflect}。
static func guard_result(amount: int, sta: int, perfect: bool) -> Dictionary:
	if perfect:
		return {"damage": 0, "sta_cost": 0, "sta_left": sta, "break_guard": false,
				"perfect": true, "reflect": int(ceil(amount * GUARD_REFLECT))}
	var cost := int(ceil(amount * 1.2))
	if sta >= cost:
		return {"damage": int(float(amount) * (1.0 - GUARD_DAMAGE_REDUCTION)),
				"sta_cost": cost, "sta_left": sta - cost, "break_guard": false,
				"perfect": false, "reflect": 0}
	return {"damage": amount, "sta_cost": 0, "sta_left": maxi(sta, 0),
			"break_guard": true, "perfect": false, "reflect": 0}
