class_name HealthComponent
extends Node
## 生命组件（参考书 §2.3 ②）：玩家与敌人共用；只管数值与信号，减伤策略由调用方处理。

signal damaged(amount: int)
signal healed(amount: int)
signal died

var max_hp := 100
var hp := 100


## 初始化上限并回满。
func setup(p_max_hp: int) -> void:
	max_hp = p_max_hp
	hp = max_hp


## 扣血（调用方负责先行减免）；返回实际扣减量，死亡时发 died。
func take_damage(amount: int) -> int:
	var real := clampi(amount, 0, hp)
	hp -= real
	if real > 0:
		damaged.emit(real)
	if hp <= 0:
		died.emit()
	return real


## 回血；返回实际回复量（不溢出）。
func heal(amount: int) -> int:
	var real := clampi(amount, 0, max_hp - hp)
	hp += real
	if real > 0:
		healed.emit(real)
	return real
