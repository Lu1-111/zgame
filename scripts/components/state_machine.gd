class_name StateMachine
extends Node
## 通用状态机组件（参考书 §2.3 ②）：状态只改自身速度/计时器，禁止跨状态直改别的组件。
## 状态节点由宿主构造后经 setup() 一次性挂入；切换统一走 to()，便于在切换点做全局规则。

signal state_changed(from_name: StringName, to_name: StringName)

var actor: Node = null
var current: Node = null
var states: Dictionary = {}


## 注册状态列表并进入初始状态；每个状态须有 NAME 常量作为键。
func setup(p_actor: Node, initial_name: StringName, state_list: Array) -> void:
	actor = p_actor
	for s in state_list:
		s.sm = self
		s.p = actor
		s.name = String(s.NAME)
		states[s.NAME] = s
		add_child(s)
	current = states.get(initial_name, null)
	if current != null:
		current.enter({})


## 切换状态；允许同名重入（如 Attack 三段连击复用同一状态节点）。
func to(state_name: StringName, msg: Dictionary = {}) -> void:
	var next: Node = states.get(state_name, null)
	if next == null:
		push_warning("StateMachine：未知状态 %s" % state_name)
		return
	var from_name: StringName = current_name()
	if current != null:
		current.exit()
	current = next
	current.enter(msg)
	state_changed.emit(from_name, state_name)


func tick(delta: float) -> void:
	if current != null:
		current.tick(delta)


func current_name() -> StringName:
	return current.NAME if current != null else &""
