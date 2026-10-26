# CHR-01 原像素剑/弓动作补充

制作人 2026-10-26 明确要求：以已有基本站立闲置帧为基础，人物本身、画布尺寸和像素密度不变，只调整动作。

唯一人物源：`../v001/frames/CHR-01_player_idle_right_v001_f01.png`。所有帧保持 64×64、锚点 (32,58)、运行时 scale=1；原头部、身体、尾部与脚部在手臂活动区之外的非透明 RGBA 像素逐点保留。手臂和手掌颜色/像素直接复制自该闲置帧，武器为同一像素网格上的独立像素图形。未使用重新生成人物的图像模型。

三段剑击各四帧，单段拉弓至释放八帧。用 Godot 执行 `tools/build_pixel_weapon_actions.gd` 重建；动作姿势及原图路径在 `data/combat_presentation.json` 的 pixel_actions。通过 WeaponRuntime 装入现有角色，不改写原正式素材。

曾生成的不同造型人物稿已经从项目资产与运行时引用中撤下，仅隔离于忽略入库的 work/rpg_overhaul/rejected_generated_characters，正式场景不读取。
