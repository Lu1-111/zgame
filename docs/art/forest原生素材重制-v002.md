# forest原生素材重制 v002

2026-11-17。三张正式森林forest_01/02/03与十张备选05A～09B已重建并替换美术。原布局、碰撞、通道、机关、刷怪、奖励配置保持原样，备选仍留在test中供制作人选案。

## 原生规格

| 内容 | 文件像素 | 运行规则 |
|---|---|---|
| 岩石、根系、苔藓连续材质 | 256×256 | 1纹素=1世界单位，硬边着色器按世界整数像素采样 |
| 实心表面 / 树枝平台 | 64×32 / 64×12 | 按片平铺，末段裁切，不拉伸 |
| 四向边缘 | 64×64，各8种 | 从原生材质派生，共32片可复用储备 |
| 装饰 | 32×48、48×32、48×64、96×40、96×64等 | 实际大小及锚点见清单，节点scale均1 |
| 木箱 / 木栅 | 48×32 / 16×64 | 木制外形，与cave金属箱区分 |
| 篝火 | 32×56，5帧 | 原有原生火焰转统一色板，不放大 |
| 雾墙图集 | 256×32，8格 | 每格32×32，按阻挡范围平铺，不非等比缩放 |
| 背景 | 640×360 | 独立屏幕层，视口扩大时平铺补齐 |

共55张运行PNG，整套32色、硬alpha、nearest、无mipmap。数据入口[data/art/forest_v002.json](../../data/art/forest_v002.json)，准确W×H及色板在forest_v002_pixel_spec.json，逐图有效范围与锚点在data/art/pixel_contracts/forest_v002.json。

原始生成图只保存在assets/RAW/environments/forest/v002。真实转换由tools/assets/build_forest_native.py调用专门的pixel_grid.py完成，记录在[audits/forest_pixel_conversion.json](audits/forest_pixel_conversion.json)。使用固定目标整数网格、一次面积采样、32色映射及硬alpha；运行场景不加载RAW。32片储备边缘不冒称每片都已摆进地图。

## 备份与兼容

旧素材、旧三张正式图、旧十张候选图及对应配置/构建器保存在[backup/2026-11-17_forest_original](../../backup/2026-11-17_forest_original)，共114文件，manifest.json记录大小和SHA256，复核全部一致。所有13份布局JSON除背景路径及色调外与备份一致。

旧共享岩壁/平台仍被营地camp_01引用，活动副本为保证营地不丢材质而保留；重建的森林已使用v002。备份带.gdignore，不导入Godot，发布脚本明确排除backup与设计/测试文件。

## 验收与查看

- 像素55图、0失败；13张实际场景1151项、0失败，384个表面均按原生纹理平铺。
- 地图构建全部退出0、无诊断；forest_03物理测试及十候选测试均通过。
- 原有1761项单元、69项数据检查通过；自然敌人攻击33项通过。
- 实际引擎全景和近景在[docs/previews/forest_v002](../previews/forest_v002)，十候选预览也已更新。

检查命令：python tools/qa/validate_pixel_packages.py；Godot脚本test/integration/test_forest_native_art.gd。
