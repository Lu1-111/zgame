# NPC RAW v002

基于 CHR-01 主角的黄身、奶油肚皮、绿色虹膜、深色手脚和圆润轮廓制作的 6 名 NPC 原始形象。

| ID | 角色 | 用途 |
|---|---|---|
| NPC-S01 | 奶兔向导 | 营地引导 |
| NPC-S02 | 奶牛商人 | 交易 |
| NPC-S03 | 奶鼠工匠 | 修理与提示 |
| NPC-S04 | 奶龙学者 | 背景知识提示 |
| NPC-S05 | 奶熊守卫 | 营地安全 |
| NPC-S06 | 奶鸟信使 | 传信 |

- 画布 64×64 RGBA，正面，root `(32,58)`；每个角色 1 张 master、6 帧 idle、8 帧 walk、4 帧 talk。
- `NPC_contact_sheet_v002.png` 为总览，`npc_manifest.json` 为索引，`NPC_qa.json` 记录 6 名 / 108 帧的尺寸、透明、触边、sheet、layout 和 root 校验。
- 生成器：`work/npc_pipeline/generate_raw.py`；合并验收：`work/npc_pipeline/finalize.py`；Godot 打包：`work/npc_pipeline/process.py`。
- PROCESSED 已生成；v001 保留为历史版本，v002 为当前 RAW。
