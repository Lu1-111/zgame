extends SceneTree
## run_tests.gd —— 自研迷你测试宿主（QA，T-004，参考书 §2.6）
## 运行：godot --headless --path . --script res://tests/run_tests.gd
## 约定：退出码 0 = 全部通过；非 0 = 存在失败。
## 结构：用例为显式 preload 列表的 RefCounted 脚本类，统一签名 func run(ctx) -> bool；
##       ctx 即本宿主，提供 expect_true / expect_eq 断言与 fetch_singleton 单例获取。
## 注意：--script 模式下 autoload 不在 /root 树上，用例必须经 fetch_singleton 兼容
##       「树上单例」与「直接实例化」两条路径（直接实例化不跑 _ready，DataDB 需手动 load_all）。

const CASE_SCRIPTS := [
	preload("res://tests/test_slime_grab.gd"),
	preload("res://tests/test_enemy_combat_b04_assets.gd"),
	preload("res://tests/test_project_config.gd"),
	preload("res://tests/test_world_data.gd"),
	preload("res://tests/test_game_state.gd"),
	preload("res://tests/test_player.gd"),
	preload("res://tests/test_enemy_assets.gd"),
]

var _passed := 0
var _failed := 0
var _created_singletons: Array[Node] = []  ## fetch_singleton 直接实例化的节点，结束时释放防泄漏

func _initialize() -> void:
	print("=== 《奶宝：银河征途》单元测试宿主 run_tests.gd ===")
	for case_script in CASE_SCRIPTS:
		var case_file: String = (case_script as GDScript).resource_path.get_file()
		print("\n---- 用例 %s ----" % case_file)
		var inst: RefCounted = null
		# 防御：用例脚本编译失败时 can_instantiate() 为 false，按用例级失败处理，
		# 绝不能让宿主 _initialize 中断（否则 quit() 不会执行，headless 主循环会挂死）。
		if case_script is GDScript and (case_script as GDScript).can_instantiate():
			inst = (case_script as GDScript).new() as RefCounted
		if inst == null:
			print("  ❌ FAIL: 用例 %s 脚本无法编译/实例化（存在解析错误）" % case_file)
			_failed += 1
			print("<< 用例 %s 失败（1/1 条断言未过）>>" % case_file)
			continue
		var passed_before := _passed
		var failed_before := _failed
		var ret: Variant = null
		ret = inst.run(self)
		var case_failed := _failed - failed_before
		var case_total := (_passed - passed_before) + case_failed
		# run() 返回非 bool 或 false（脚本运行时错误中断函数，返回默认值）均视为用例级失败
		if not (ret is bool):
			case_failed += 1
			case_total += 1
			print("  ❌ FAIL: 用例 %s 运行异常中断（run() 返回 %s 而非 bool，通常存在脚本运行时错误）" % [case_file, _variant_str(ret)])
		elif not (ret as bool):
			case_failed += 1
			case_total += 1
			print("  ❌ FAIL: 用例 %s 运行中断（run() 返回 false，通常存在脚本运行时错误）" % case_file)
		if case_failed == 0:
			print("<< 用例 %s 通过（%d 条断言）>>" % [case_file, case_total])
		else:
			print("<< 用例 %s 失败（%d/%d 条断言未过）>>" % [case_file, case_failed, case_total])
	var total := _passed + _failed
	print("\n=== 汇总：passed=%d / total=%d ===" % [_passed, total])
	# 释放直接实例化的单例节点（不在树上，不会自动回收），避免 ObjectDB 泄漏告警
	for n in _created_singletons:
		if is_instance_valid(n):
			n.free()
	_created_singletons.clear()
	if _failed == 0:
		print("RESULT: ALL PASS")
		quit(0)
	else:
		print("RESULT: FAILED")
		quit(1)

## 断言：条件为真。逐条打印 ✅ PASS / ❌ FAIL + 原因。
func expect_true(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("  ✅ PASS: %s" % msg)
	else:
		_failed += 1
		print("  ❌ FAIL: %s" % msg)

## 断言：actual == expected。失败时附带实际值与期望值。
func expect_eq(actual: Variant, expected: Variant, msg: String) -> void:
	if actual == expected:
		_passed += 1
		print("  ✅ PASS: %s" % msg)
	else:
		_failed += 1
		print("  ❌ FAIL: %s（实际=%s，期望=%s）" % [msg, _variant_str(actual), _variant_str(expected)])

func _variant_str(v: Variant) -> String:
	## 断言消息用的值转字符串；用全局 str()（Godot 4.7 的 String() 构造器不接受 int 等类型）
	if v == null:
		return "<null>"
	return str(v)

## 获取 autoload 单例，兼容两条路径：
## 1) 正常运行时 autoload 已挂在 /root 下，按子节点名直接匹配；
## 2) --script 模式下 autoload 未注册，按脚本路径直接实例化
##    （字段初始化器生效，但 _ready/_process 不跑；DataDB 需手动调 load_all()）。
## 注意：不用 root.get_node("/root/X")——--script 模式下不在活动树内，
## 绝对路径查找会报 "Can't use get_node() with absolute paths" 引擎错误。
func fetch_singleton(singleton_name: String, script_path: String) -> Node:
	for child in root.get_children():
		if child.name == StringName(singleton_name):
			return child
	var inst: Node = (load(script_path) as GDScript).new() as Node
	_created_singletons.append(inst)
	return inst
