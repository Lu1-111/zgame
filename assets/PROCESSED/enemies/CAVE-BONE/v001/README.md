# 骨龙三型原生逐帧素材

按当前主角的圆头、短肢、宽腹比例进行骨架化；三型使用同一骨龙身份与共享16色色板，刀、矛、弓是武器变体。朝向全右，运行时可水平翻转；不修改主角母版。

| ID | 原生画布 | 足底锚点 | 动作 |
|---|---|---|---|
| bone_dragon_blade | 96×96 | (40,80) | idle、move、slash_down、slash_up、thrust，各6帧 |
| bone_dragon_spear | 128×96 | (40,80) | idle、move、thrust，各6帧 |
| bone_dragon_bow | 96×96 | (40,80) | idle、move、shoot，各6帧 |
| bone_arrow | 48×16 | (24,8) | fly，4帧；箭体约32×8px |

身体原生可见高度约42px。整个角色动作表按闲置的公共身体比例统一一次转换；武器举高或刺出不会按整帧包围盒重新缩放身体。idle高低姿态约39～46px，属于源动作的全身起伏。手脚和躯干在动作中逐帧改变，未使用静帧旋转/平移代替攻击。

- 66张身体帧和4张箭矢帧；硬边alpha0/255，最多16色，无mipmap，节点scale应为(1,1)。
- `catalog.json`登记动作、帧路径、FPS、循环、画布、锚点与SpriteFrames路径。每个变体`godot/*.tres`可直接加载。
- `contact_sheet.png`提供全动作总览；每动作GIF及各型`all_actions.gif`只供预览，不作为运行资源。
- 基础生命、基础攻击、韧性和抗性全部null，未擅定平衡值；本批仅准备美术，未加入正式世界刷怪。
- 母版与完整内置image_gen提示词：`assets/RAW/enemies/CAVE-BONE/v001/`。
- 当前修订为imagemagick_v002：`python tools/assets/convert_cave_imagemagick.py --magick <magick可执行文件> --apply`。实际从RAW一次Point采样、共享16色、无抖动；透明蒙版独立保存恢复。全部源格、目标尺寸和固定偏移在data/art/cave_enemy_imagemagick.json。旧面积采样构建器已禁止覆盖当前结果。
- 通用门禁：`python tools/qa/validate_pixel_assets.py --manifest assets/PROCESSED/enemies/CAVE-BONE/v001/pixel_manifest.json`。已通过70帧，0失败；`pixel_spec_runtime.json`登记每帧最终画布，`pixel_qa.json`保存本批检查结果。箭矢先采样32×8再原样补透明边至48×16，记录分别保留sampled_canvas_pixels和canvas_pixels，不发生第二次缩放。

所有动作与箭矢速度改为原始fps的0.75倍，时长为原4/3；SpriteFrames、目录和GIF同步，重建从base_fps计算，不累计减速。转换前完整副本在backup/2026-11-17_cave_before_imagemagick。

弓型shoot帧序为持箭准备、搭箭、拉弦、满弓、释放、收弓；箭矢弹幕独立。关卡与战斗接入方负责在释放时创建箭矢，不在美术组件中擅自定义速度、伤害或射程。
