extends SceneTree

var _failures: Array[String] = []
var _loaded: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await _visit("res://test/scenes/assets")
	print("ASSET PREVIEWS: %d loaded, %d failures" % [_loaded, _failures.size()])
	for failure in _failures:
		printerr(failure)
	quit(0 if _failures.is_empty() and _loaded > 0 else 1)

func _visit(directory: String) -> void:
	for filename in DirAccess.get_files_at(directory):
		if not filename.ends_with(".tscn"):
			continue
		var scene_path := directory.path_join(filename)
		var packed := load(scene_path) as PackedScene
		if packed == null:
			_failures.append(scene_path)
			continue
		var instance := packed.instantiate()
		root.add_child(instance)
		await process_frame
		instance.queue_free()
		await process_frame
		_loaded += 1
	for child in DirAccess.get_directories_at(directory):
		await _visit(directory.path_join(child))
