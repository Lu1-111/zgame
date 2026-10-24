extends RefCounted
## M1 玩家纯逻辑用例：伤害公式 / 格挡三档结算 / 伤害包。
## 仅引用 CombatMath / DamagePacket——二者刻意无 autoload 依赖，--script 模式可加载。
## （涉及 Player 类与物理帧的验收 1/2/4 由 tests/sim_player.tscn 场景模式模拟覆盖，
##  因为 --script 模式下 autoload 标识符无法解析，不能触碰 Player。）


func run(host) -> bool:
	# ---- 伤害公式（§3.3）----
	host.expect_eq(CombatMath.compute_attack(12, 1, 1.0), 20, "Lv1 奶瓶锤普攻 = (12+8+0)×1.0 = 20")
	host.expect_eq(CombatMath.compute_attack(12, 10, 1.0), 38, "Lv10 奶瓶锤普攻 = (12+8+18) = 38")
	host.expect_eq(CombatMath.compute_attack(10, 1, 1.5), 27, "技能倍率 1.5 生效：(10+8)×1.5 = 27")
	host.expect_eq(CombatMath.compute_attack(8, 15, 1.0), 44, "Lv15 公式值：8+8+2×14 = 44")

	# ---- 格挡三档（§3.1：减伤 60% / 完美反弹 30% / 体力不足破防）----
	var r1 := CombatMath.guard_result(20, 100, false)
	host.expect_eq(int(r1["damage"]), 8, "普通格挡 20 伤害 → 减伤 60% 后扣 8 HP")
	host.expect_eq(int(r1["sta_cost"]), 24, "普通格挡体力消耗 = 20×1.2 = 24")
	host.expect_eq(int(r1["sta_left"]), 76, "格挡后体力 = 76")
	host.expect_eq(bool(r1["break_guard"]), false, "体力充足不破防")

	var r2 := CombatMath.guard_result(20, 100, true)
	host.expect_eq(int(r2["damage"]), 0, "完美格挡 0 伤害")
	host.expect_eq(int(r2["reflect"]), 6, "完美格挡反弹 30% = 6")
	host.expect_eq(int(r2["sta_cost"]), 0, "完美格挡不耗体力")

	var r3 := CombatMath.guard_result(20, 5, false)
	host.expect_eq(int(r3["damage"]), 20, "体力不足 → 破防吃全额")
	host.expect_eq(bool(r3["break_guard"]), true, "破防标记置位")

	var r4 := CombatMath.guard_result(20, 24, false)
	host.expect_eq(bool(r4["break_guard"]), false, "体力恰好够（24≥24）不破防")

	# ---- DamagePacket 默认值 ----
	var pkt := DamagePacket.new(15, DamagePacket.DamageType.MAGIC, 200.0, Vector2(10, 5), &"skill_bubble")
	host.expect_eq(int(pkt.amount), 15, "DamagePacket 基础伤害注入")
	host.expect_eq(int(pkt.type), int(DamagePacket.DamageType.MAGIC), "DamagePacket 类型：法术")
	host.expect_eq(pkt.source_id, StringName("skill_bubble"), "DamagePacket 来源 id")
	var pkt2 := DamagePacket.new()
	host.expect_eq(int(pkt2.type), int(DamagePacket.DamageType.PHYSICAL), "DamagePacket 默认物理")
	return true
