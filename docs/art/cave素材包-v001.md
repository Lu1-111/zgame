# cave 洞穴素材包 v001

2026-11-17制作并按追加要求复核。采用暗灰蓝岩层、碎裂岩面、冷色荧光晶石和干燥象牙色白骨。所有运行贴图已通过pixel_grid工具一次转换到登记的整数像素画布，nearest过滤、二值透明边、统一32色色板；未覆盖forest资源，也未新建正式洞穴关卡。像素规格已写入AGENTS.md基本原则，详见[像素复核](cave像素规格复核-2026-11-17.md)。

## 素材清单

| 类别 | 内容 | 目录（工程根起） |
|---|---|---|
| 基础岩壁 | 连续256×256岩石场，16个64×64填充变体 | assets/environments/terrain/cave/v001 |
| 边缘过渡 | 上下左右各8种；内角、外角各4方向×4种，共64种边角 | 同上tiles |
| 地形图集 | 80块、64px格、alpha轮廓碰撞、Godot TileSet | assets/environments/tilesets/cave/v001 |
| 荧光晶石 | 4种，青色/淡紫，独立PointLight2D与轻微明暗变化 | assets/environments/props/cave/v001/crystal |
| 普通石头 | 4种扁石、块石、立石、双石 | 同上rock |
| 矿石 | 铜脉、铁矿、蓝矿、紫晶矿各1种 | 同上ore |
| 尸骨 | 头骨、肋骨脊柱、散落长骨、半埋骨架各1种 | 同上bones |
| 金属宝箱 | 普通闭合、上锁闭合、半开、全开4态，共用48×40画布 | 同上chests |
| 平台 | 2种48×24石台，顶部较亮、下缘碎裂，可交错拼接 | assets/environments/terrain/cave/v001/platforms |
| 石笋陷阱 | 2种原形及2种镜像，共4种48×40段，可交错成排 | 同上hazards |
| 背景 | 640×360幽暗洞穴，原生屏幕层，禁止按地图尺寸放大 | assets/environments/backgrounds/cave/v001 |

## 使用约定

- 数据索引：`data/art/cave_v001.json`。画布规格：`data/art/cave_v001_pixel_spec.json`；全局基准：`data/art/pixel_standards.json`。运行尺寸、底部锚点、灯光、开箱帧时长及物理层均从清单读取，前景节点scale=(1,1)。
- 普通装饰原点放在脚底中心；摆放时贴合真实地形表面。装饰z=1、角色/敌人z=20、背景z=-30。
- 岩壁推荐给TileMapLayer使用`continuous_rock.gdshader`，通过世界坐标采样连续岩石场，alpha取图块外形。这样边缘可以随机交错，内层不会出现64px方块接缝。基础图块按4×4原顺序也可还原完整岩石场。
- `cave_terrain.tres`包含80块实体轮廓，但不预设47格自动地形规则。参考构建器按上下左右和斜对角邻接选内外角；窄小地形仍应实测碰撞。
- `scripts/world/cave_prop.gd`使用`asset_id`选择装饰，晶石自动附加局部光源。晶石源图不烘焙大光晕，光照由Godot独立叠加。
- `scripts/world/cave_platform.gd`按`segment_count`交错铺排，使用oneway层，表面碰撞支持从下方跳过。
- `scripts/world/cave_spike_strip.gd`按`segment_count`铺排石笋，危险Area沿alpha轮廓，接触发出`hazard_contact(body)`。素材任务不擅定伤害，JSON中的damage保留null，正式房间接入时提供经确认的伤害值。

金属箱使用`scripts/world/cave_chest.gd`。`unlock_condition`可取none/encounter/key，后两者初始带同一把锁；房间完成清怪验证或成功消耗钥匙后调用`satisfy_condition("encounter")`或`satisfy_condition("key")`。满足条件后只去锁、保持闭合；玩家交互`try_open()`才播放三帧开启。解锁前不能开箱，错误条件不能互代。物品消耗、奖励及存档由房间处理，不由美术组件暗中操作。闭箱与锁箱在锁区域以外逐像素相同。

## 实际预览

双击[test/launchers/run_cave_materials.cmd](../../test/launchers/run_cave_materials.cmd)，或在编辑器运行[test/scenes/cave_material_preview.tscn](../../test/scenes/cave_material_preview.tscn)。使用独立本地用户目录，场景禁写正式存档，退出恢复进入前状态。

- A/D移动，Space跳跃（预览给二段跳）。E开箱。
- 1模拟清场完成；2模拟钥匙已成功使用；R重置。测试箱子为空。
- F5切换全景/正常跟随镜头。触碰石笋回入口，预览不扣血。

全景与近景为实际Godot渲染，位于`docs/previews/cave_v001/`；素材总览`cave_asset_board.png`可直接查看分类。

## 制作源与复现

使用内置image_gen生成四张母版：岩壁、16种装饰、宝箱/平台/石笋、背景。完整提示词和源路径保存在`assets/RAW/environments/cave/v001/prompts.json`，PNG母版随工程保留；运行时不读取母版。2026-11-17复核后，改用pixel_grid的单次预乘alpha面积采样直接得到最终像素数，再32色量化/硬alpha，禁止先缩64格再二次任意缩放；接地锚点、锁块同源合成及图集另做登记。逐图转换记录见`docs/art/audits/cave_pixel_conversion.json`。

```text
python tools/assets/build_cave_assets.py
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tools/maps/build_cave_material_preview.gd
python test/integration/validate_cave_assets.py
python tools/qa/validate_pixel_assets.py --manifest data/art/cave_v001.json
godot --headless --path . --fixed-fps 60 --script res://test/integration/test_cave_materials.gd
```

运行贴图与图集约0.5MiB，不计引擎导入缓存。本次只增加cave资源和测试入口，不触发版本发布。

## 验收输出

```text
cave_import_final exit=0 diagnostics=0
CAVE ASSET QA: 107 images ... PASS
CAVE MATERIALS: 139 checks, 0 failures
RESULT: ALL PASS — passed=1761 / total=1761
cave_formal_smoke exit=0 diagnostics=0
PIXEL ASSET QA: 109 images / <=32 colors / native declared sizes / 0 failures
REPOSITORY AUDIT: 1983 static resource references, 16 reserved batches, 0 errors
```

验收包含真实角色站台、地面装饰接地、四个点光、两类解锁互斥、开箱不可重复、数字键1与E实际输入、石笋尖端命中及离开尖端不误判。日志保存在work/qa/cave_*.log与.err。
