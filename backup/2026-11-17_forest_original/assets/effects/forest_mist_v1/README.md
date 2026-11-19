# 森林白雾封印门

2026-11-12使用内置 `image_gen` 新图生成模式，透明背景，无参考图片。生成规格记录见 [提示词](mist_v1.prompt.txt)。

- `source.png`：原始4×2八帧图，源 `exec-a75da338-9fd3-4167-b0bd-6d486aa4a8f1.png`。
- `mist_sheet.png`：由 `tools/maps/process_forest_mist.gd` 机械分格、裁掉各格透明留边、nearest缩放为单帧64×192后横向拼接，未补画。有效雾幕上下沿与地图封印范围贴合。
- 帧数、帧率、淡出时间与色调位于 `data/forest_mist.json`；显示尺寸和实体碰撞分别由地图数据指定。
- 默认8帧、8fps，清场解除碰撞并在0.55秒内淡出；存档已解封时立即隐藏。

原画SHA256：`9f78547bfe10e117f6c21f4d64024bc00fcb552ac800628fa0b684b7d1b6f084`。
