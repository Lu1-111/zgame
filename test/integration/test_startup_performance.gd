extends SceneTree
## 标题页真实渲染与退出回归；由外部看护进程限制运行时长和进程内存。
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("TITLE PID ",OS.get_process_id())
	var original_mode := OS.low_processor_usage_mode
	var started := Time.get_ticks_msec()
	var menu := load("res://scenes/main.tscn").instantiate() as Node2D
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	_expect(OS.low_processor_usage_mode,"标题页开启按需重绘")
	_expect(Engine.max_fps > 0 and Engine.max_fps <= 60,"引擎实际帧率上限不超过 60")
	_expect(menu.get_node("UI/Root/Center").get_child_count() >= 3,"标题与开始按钮加载完成")
	for sample in 6:
		await create_timer(0.5,true,false,true).timeout
		print("TITLE SAMPLE ",JSON.stringify({
			"elapsed_ms":Time.get_ticks_msec()-started,
			"fps":Performance.get_monitor(Performance.TIME_FPS),
			"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,
			"engine_static_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0,
			"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"low_processor_mode":OS.low_processor_usage_mode,
		}))
	current_scene = null
	menu.queue_free()
	await process_frame
	_expect(OS.low_processor_usage_mode == original_mode,"离开标题恢复正常运行模式")
	print("STARTUP PERFORMANCE: %d FAIL" % _failed)
	quit(1 if _failed else 0)


func _expect(condition: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if condition else "FAIL",label])
	if not condition:
		_failed += 1
