# 通用危险预警红光 v1

简短细红光、中央小亮芒和淡光晕，介于最初大星芒版与极简直线版之间。每帧96×96，中心(48,48)，六帧、30fps、总长0.2秒，nearest、原生像素、硬透明。仅作冲撞预警，不包含伤害判定。

2026-11-02追加：运行时按制作人要求统一放大4倍，仍为0.2秒，配置`danger_warning.scale=4`；源帧保持不变。

生成方式：内置imagegen。原图在`sources/danger_glint.png`，完整提示词见`PROMPTS.md`。`tools/assets/build_danger_warning.py`使用ImageMagick转换；Pillow仅测量与校验。运行资源`DangerWarning_frames.tres`，通用组件`scripts/core/danger_warning.gd`，配置`data/combat_feedback.json`。
