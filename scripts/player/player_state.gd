class_name PlayerState
extends Node
## 玩家状态基类：由 StateMachine 驱动（参考书 §3.1）。
## 约定：状态只允许改 p.velocity 与自身计时器，跨状态规则统一走 p.try_actions()。
## p / sm 由 StateMachine.setup 注入；故意不标类型以避免 player↔states 循环引用。

var sm: StateMachine
var p: Node


func enter(_msg: Dictionary) -> void:
	pass


func exit() -> void:
	pass


## 物理帧驱动（玩家在 move_and_slide() 之前调用）。
func tick(_delta: float) -> void:
	pass
