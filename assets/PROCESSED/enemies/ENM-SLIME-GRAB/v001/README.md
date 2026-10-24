# 史莱姆：触手抓取（v001）

新增16帧连续动作：蓄势→头顶红色感叹号→感叹号消失→触手伸出→闭合抓取→释放收回。

- `grab_ready`：4帧，第一帧蓄势无标记，第2～4帧显示红色感叹号。
- `grab_attack`：8帧，从首帧起不含感叹号；前半伸出、后半闭合并回拉。
- `grab_recover`：4帧，释放并收回触手。
- `tentacle_grab`：完整16帧连播，供展示与复用。上述动作共用16个PNG，不重复生成素材。

打开 `preview.html` 可自动播放、暂停、逐帧、镜像和检查锚点。`contact_sheet.png` 为正常透明合成后的4×4帧序。

## 游戏

主菜单F2进入战斗演练，选择“奶滴史莱姆”，靠近后即可触发。原演练实体和战斗演练实体都已接入；原B04七种动作仍完整保留。

状态映射为 telegraph→grab_ready、attack→grab_attack、recover→grab_recover；预警0.6秒、抓取0.8秒、收回0.4秒。命中只在抓取阶段0.5～0.65秒的闭合帧窗结算一次。所有运行参数在 `data/enemy_presentation.json` 和 `data/enemy_combat_b04.json` 的 `per_enemy.milk_slime` 中。

新动作与旧动作使用相同根 `(96,136)`。新画布为288×176，仅扩展透明范围容纳触手与微弱alpha，身体缩放固定；不按伸手后的整图包围盒自动居中。
`godot/ENM-03_grab.tres` 为四个新动作；`ENM-03_all_actions.tres` 合并原七动作和四个新动作。

## 原稿与来源

使用内置 image_gen，完整原稿、原始参考提示词、实际入选提示词与来源保存在 `assets/RAW/enemies/ENM-SLIME-GRAB/v001/`。
处理只做最近邻缩放、源区块提取和语义根平移。源帧7/8的横向轮廓投影重叠，但实际身体像素不重叠，采用不同Y范围的矩形源区块分别提取，避免截断触手或带入邻帧身体；区块与源锚点均记在manifest/frameDetails中，原始PNG未改写。

验收记录见 `qa/` 和 `qa.json`；可复现工具为 `work/slime_grab/build.py`，源区块校准见 `processing/calibration.json`。
