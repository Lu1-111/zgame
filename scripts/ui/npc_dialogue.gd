extends CanvasLayer
## 通用 NPC 对话框：显示姓名、正文和进度，不接管输入，由 NPC 推进。

@onready var panel: ColorRect = $Panel
@onready var speaker: Label = $Panel/Speaker
@onready var line: Label = $Panel/Line
@onready var hint: Label = $Panel/Hint


func _ready() -> void:
	add_to_group(&"npc_dialogue")
	panel.visible = false


func show_line(display_name: String, text: String, index: int, total: int) -> void:
	panel.visible = true
	speaker.text = display_name
	line.text = text
	hint.text = "E 继续  %d/%d" % [index, total]


func close_dialogue() -> void:
	panel.visible = false
