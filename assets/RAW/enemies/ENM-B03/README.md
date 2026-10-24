# ENM-B03 敌人细化与类型扩充

本批使用内置 image_gen 制作角色动画原图，作为现有八种程序绘制小怪的补充：精修 ENM-01 苔甲虫；新增 ENM-09 矿灯虫、ENM-10 酸液蛞；补充 ELT-01 苔甲卫、ELT-02 蜂巢守卫、ELT-03 酸液母体。旧版文件均保留。

`v001/` 下按实际素材编号或游戏 slug 分组。每种角色保存两张入选动作表和可能的原始/排布修订候选，以及完整提示词、生成来源和 `batch.json`。A 表包含 idle、move、telegraph、attack；B 表包含 recover、hurt 和连续八帧 death。是否入选以 batch 指向的实际文件为准，RAW 文件存在不表示已经验收。

角色均朝右。主体身份、持握侧、甲壳或软体结构在相邻动作间保持一致。生成器可能输出不同尺寸、非等距排布或上下排基线偏差；处理必须以实际 `sourceRects`、人工语义 `sourceAnchors` 和每张源表固定 `scale` 为准，不能把名义格子数当作完成验收。

排布修订通过图像工具完成；后处理只执行源像素裁取、Nearest 固定倍率缩放、整数平移和透明画布排布。为保留全部 alpha 可统一增加同一敌人的透明画布，不裁掉武器、翅膀、拖尾或低 alpha 边缘，也不按每帧包围框改变体型。

对应六组独立攻击特效及其提示词、来源和配置位于 `assets/RAW/effects/ENM-B03/v001/`。最终统一成品包位于 `assets/PROCESSED/enemies/ENM-B03/v001/`，具体生成与验收进度见主清单及成品 QA。

素材编号与实际游戏敌人映射：

| 素材编号 | 名称 | gameEnemyId |
|---|---|---|
| ENM-01 | 苔甲虫精修 | moss_beetle |
| ENM-09 | 矿灯虫 | lamp_bug |
| ENM-10 | 酸液蛞 | acid_slug |
| ELT-01 | 苔甲卫 | moss_guard |
| ELT-02 | 蜂巢守卫 | hive_guard |
| ELT-03 | 酸液母体 | acid_mother |
