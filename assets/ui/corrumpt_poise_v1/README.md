# corrumpt 破韧血条覆盖层

参照现有细金属双边、紫色填充血条，用内置imagegen绘制裂纹与修复素材。六张透明PNG画布均350×16：前三张为破裂过程，第3张为持续破韧状态，后三张为恢复过程。覆盖层没有不透明生命填充，生命条仍按实际HP绘制，零血仍归零。

原图`sources/cracks_repair.png`；完整提示词`PROMPTS.md`。`tools/assets/build_corrumpt_poise_ui.py`调用ImageMagick采样、透明阈值化和限色，Pillow只读测量。资源`CorrumptPoise_frames.tres`提供break/broken/recover三个动画，时长和剧烈震动参数均在`data/bosses/claffert.json`的`ui.poise`中。
