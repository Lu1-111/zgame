# CHR-01 完整角色母版剑、弓动作

2026-10-27。制作人要求严格保持既有闲置、锤、杖动作的人物形象和像素密度，不添加背鳍，不采用重新生成的角色。

本目录 64 张 PNG 均为 64×64：三套剑击各八帧，以及五个方向的弓各八帧。角色母版来自 `../v001/frames/` 中既有的完整闲置、锤、杖动作。96×96 正式动作按原脚底锚点裁为 64×64，人物像素按 1:1 保留，未缩放或切割头身。

角色完整母版、原武器遮罩、新武器挂点、动作时序和瞄准姿态见 `data/hero_motion.json`。剑击重组正式预备、挥击、下压、收招姿态；弓根据上、平、下瞄准选用正式抬手或俯身姿势，后手拉弦、弓身与出箭点实时跟随光标。运行时使用 `scripts/player/pixel_hero_rig.gd`，五方向 PNG 为导出的检查帧，实时瞄准支持连续角度。

由 `tools/preview_hero_rig.gd` 通过 Godot 正常渲染导出。重建时使用渲染器，限制帧率并让脚本自行退出，例如 `godot --path . --rendering-method gl_compatibility --max-fps 15 --script res://tools/preview_hero_rig.gd`。不能用 dummy/headless 渲染器导出可视帧。

对照图：`docs/previews/hero_fullframe_v4.png`，顶部为闲置原图，三行剑击和五行方向弓。

未使用有背鳍的 AI 角色稿，也未使用被制作人否决的头、躯干、脚拆分版本。原正式人物文件不修改。
