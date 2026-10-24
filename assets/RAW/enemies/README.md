# 八种小怪 RAW v002

当前版本覆盖人形、动物形、昆虫型、魔兽型和植物型，不再以昆虫为主。全批共 65 套动作、356 张 64×64 RGBA 帧图，由 `work/enm_pipeline/generate_raw.py` 以局部关节和独立关键姿态确定性绘制，无自动补间。

| ID | 小怪 | 类型 | 动作数 | 帧数 |
|---|---|---|---:|---:|
| ENM-01 | 苔甲虫 | 昆虫型 | 7 | 38 |
| ENM-02 | 奶罐哥布林 | 人形 | 7 | 38 |
| ENM-03 | 奶滴史莱姆 | 魔兽型 | 15 | 84 |
| ENM-04 | 苔原奶狐 | 动物形 | 7 | 38 |
| ENM-05 | 霜晶冰灵 | 魔兽型 | 7 | 38 |
| ENM-06 | 暗影奶灵 | 魔兽型 | 8 | 44 |
| ENM-07 | 藤鞭花 | 植物型 | 7 | 38 |
| ENM-08 | 蜜蜡蜂 | 昆虫型 | 7 | 38 |

- 基础动作：idle 6 / move 8 / telegraph 4 / attack 6 / recover 3 / hurt 3 / death 8。
- 每种目录：`ENM-XX/v002/`；`frames/` 为逐帧源图，`sheets/` 为单行动作表及 `.layout.json`。
- 地面/固定单位 root `(32,58)`，飞行/漂浮单位 root `(32,32)`；所有动作不按 bbox 重新居中。
- `manifest.json` 记录当前 v002 帧路径、fps、循环、root 和源表 SHA-256；`qa.json` 当前为 356 帧 `passed=true`。
- `contact_sheet_v002.png` 为八类主造型总览。
- v001 原图保留在各自版本目录；`manifest_v001.json`、`qa_v001.json` 仅作历史归档，不是当前入选版本。
