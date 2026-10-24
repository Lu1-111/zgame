extends Node
## SaveSystem —— 存档系统（autoload 单例）
## M0 只交付接口骨架；序列化 / CRC / 双槽轮换在 M2 实装（参考书 §3.9）。
## 铁律：禁止战斗中途自动存档。

const SAVE_DIR := "user://saves/"   ## 存档目录
const SAVE_VERSION := 1             ## 存档格式版本号（版本迁移 M2 起生效）

func save_game(slot: int = 1) -> Error:
	## 将 GameState 序列化写入指定槽位，成功返回 OK。
	## TODO(M2)：GameState.to_save_dict + CRC 校验 + 双槽轮换（.sav / .bak）+ 发 EventBus.save_completed。
	return ERR_UNAVAILABLE

func load_game(slot: int = 1) -> bool:
	## 读取指定槽位并恢复 GameState，成功返回 true。
	## TODO(M2)：读 JSON → CRC 校验失败回退 .bak → GameState.load_from_dict。
	return false

func has_save(slot: int = 1) -> bool:
	## 判断指定槽位是否存在存档文件
	return FileAccess.file_exists(_slot_path(slot))

func delete_save(slot: int = 1) -> void:
	## 删除指定槽位的存档文件（含 .bak 备份）
	for path in [_slot_path(slot), _slot_path(slot) + ".bak"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _slot_path(slot: int) -> String:
	## 槽位号 → 存档文件路径
	return "%ssave_%d.json" % [SAVE_DIR, slot]
