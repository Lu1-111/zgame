# corrumpt 二阶段 · 标准化母版与逐帧招式

先统一外形/闲置，再制作攻击，2026-11-02。

- 标准母版：已确认的正面三层刀刃花瓣、深色花心，无根/茎/底座/藤蔓。
- 原生画布128×128，固定花心(64,64)，scale=1、nearest，与第一阶段和现有怪物同像素密度；共用一阶段32色色板、硬透明。
- 八帧闲置8fps。校正旧帧的花心微漂移，固定内侧深色核心，保留花瓣自然摆动；先导入与验证完成后，才以此PNG母版调用imagegen生成攻击源图。
- 常态约84px高。延长刀瓣逐渐伸展至约120px，所有帧沿同一花心。旋转帧以花心最远半径标定，刀尖不触及画布边界，斜向旋转不会裁切。
- 闲置8帧、延长8帧、收回8帧、旋转8帧、加速4帧、减速5帧、气流4帧，共45个资源帧引用；收回、加速、减速复用完整姿态PNG。共28张唯一PNG，无骨骼或运行时身体旋转。
- 气流96×24、20fps，仅在冲撞段显示，按冲撞方向放在花体后方。

`frames/`为运行帧；`godot/Corrumpt_phase2_frames.tres`为正式资源；`masters/phase_2_idle.png`为后续设计的唯一常态参考；`sources/`和`PROMPTS.md`保留生成来源与完整提示词。重建：`python tools/assets/build_corrumpt_phase2_art.py`，再运行Godot导入。

预览：`docs/previews/corrumpt_phase2_idle_standard.gif`为标准化闲置；`corrumpt_phase2_actions.gif`为实际Godot三次旋刃冲撞；`corrumpt_phase2_dash.png`为冲撞和气流画面。
