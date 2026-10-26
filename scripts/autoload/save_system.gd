extends Node
## 篝火存档：每个档位 A/B 轮换、CRC32、原子替换及 .bak 容错。
var restoring := false


## 写入当前旅途；战斗期间禁止自动保存。
func save_game(slot: int = 1) -> Error:
	if GameState.in_combat:
		return ERR_BUSY
	var settings: Dictionary = InventoryService.config().save
	var scene := get_tree().current_scene
	if scene != null and scene.has_node("Player"):
		if not str(scene.scene_file_path).begins_with("res://scenes/rooms/"):
			return ERR_UNAVAILABLE
		var pos: Vector2 = scene.get_node("Player").position
		GameState.saved_position = [pos.x, pos.y]
	var sequence := 0
	for bank in 2:
		for suffix in ["", ".bak"]:
			var old := _read_path(_slot_path(slot, bank) + suffix)
			sequence = maxi(sequence, int(old.get("sequence", 0)))
	sequence += 1
	var target := _slot_path(slot, (sequence - 1) % 2)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(str(settings.directory)))
	var data := GameState.to_save_dict()
	var record := {"version":int(settings.version), "sequence":sequence, "data":data, "crc":_crc(JSON.stringify(data))}
	var encoded := JSON.stringify(record)
	if encoded.to_utf8_buffer().size() > int(settings.max_bytes):
		return ERR_OUT_OF_MEMORY
	if not _read_path(target).is_empty():
		var backup_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(target), ProjectSettings.globalize_path(target + ".bak"))
		if backup_error != OK:
			return backup_error
	var output := FileAccess.open(target + ".tmp", FileAccess.WRITE)
	if output == null:
		return FileAccess.get_open_error()
	output.store_string(encoded)
	output.flush()
	output.close()
	var error := DirAccess.rename_absolute(ProjectSettings.globalize_path(target + ".tmp"), ProjectSettings.globalize_path(target))
	if error != OK and FileAccess.file_exists(target):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(target))
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(target + ".tmp"), ProjectSettings.globalize_path(target))
	if error == OK:
		EventBus.save_completed.emit(slot)
	return error


## 读取最高序号的有效快照；任一主槽损坏时自动回退另一槽或备份。
func load_game(slot: int = 1) -> bool:
	var best := {}
	for bank in 2:
		for suffix in ["", ".bak"]:
			var record := _read_path(_slot_path(slot, bank) + suffix)
			if int(record.get("sequence", 0)) > int(best.get("sequence", 0)):
				best = record
	if best.is_empty():
		return false
	GameState.load_from_dict(best.data)
	InventoryService.ensure_state()
	restoring = true
	return true


## 只有存在通过校验的快照才显示继续按钮。
func has_save(slot: int = 1) -> bool:
	for bank in 2:
		for suffix in ["", ".bak"]:
			if not _read_path(_slot_path(slot, bank) + suffix).is_empty():
				return true
	return false


## 删除指定档位的两个轮换槽、临时文件与备份。
func delete_save(slot: int = 1) -> void:
	for bank in 2:
		for suffix in ["", ".bak", ".tmp"]:
			var path: String = _slot_path(slot, bank) + str(suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _slot_path(slot: int, bank: int = 0) -> String:
	return "%ssave_%d_%s.json" % [InventoryService.config().save.directory, slot, "a" if bank == 0 else "b"]


func _read_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > int(InventoryService.config().save.max_bytes):
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {}
	var record: Dictionary = parser.data
	if not record.get("data") is Dictionary or int(record.get("version", 0)) > int(InventoryService.config().save.version):
		return {}
	if str(record.get("crc", "")) != _crc(JSON.stringify(record.data)):
		return {}
	return record


func _crc(value: String) -> String:
	var crc: int = 0xffffffff
	var normalized := JSON.stringify(JSON.parse_string(value))
	for byte in normalized.to_utf8_buffer():
		crc ^= int(byte)
		for bit in 8:
			crc = (crc >> 1) ^ (0xedb88320 if crc & 1 else 0)
	return "%08x" % (crc ^ 0xffffffff)
