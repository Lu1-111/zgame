# ENM-01 苔甲虫：RAW v002

生成日期：2026-10-24。类型：昆虫型。生成方式：`work/enm_pipeline/generate_raw.py` 确定性原生像素关键姿态绘制，无自动补间。

- 画布 64×64，右向，真 Alpha，Nearest；固定 root `(32, 58)`（`ground`）。
- 基础动作：idle 6 / move 8 / telegraph 4 / attack 6 / recover 3 / hurt 3 / death 8，共 38 帧。
- 本敌人动作组 7 套，总帧图 38 张（含专属动作/子体，如适用）。
- `frames/` 为逐帧源图；`sheets/` 为单行动作表；`.layout.json` 记录帧序、fps 与 root。
- 精细动作使用局部关节、武器角度、步态、压缩、扑跳或碎裂姿态；不按整帧 bbox 缩放或居中。

v001 仅作历史保留；当前入选版本为 v002。PROCESSED 只做校验、复制、规则排布与打包。
