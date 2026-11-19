# 洞穴蜘蛛浅条纹 · 原生蒙版 v001

2026-11-18制作人要求：体表增加较浅条纹，符合蜘蛛外观、便于在洞穴中辨认。

方案为三条冷灰人字腹纹、胸甲短纹及少量腿环。使用当前兽类共用16色色板内的`#8794a0`，只改变约6%～8%的原有可见像素，不整只漂白。腹纹按24帧各自的腹部矩形/转角定位，腿环逐帧跟随肢体坐标，爪击举身帧也有独立参数。所有参数见`masks.json`，编译后的原生单帧蒙版见`compiled_masks/`。

内置imagegen生成的`design_reference.png`仅用于选择条纹形态，不直接当成运行图。完整提示词在`design_prompt.json`。最终运行图由ImageMagick在现有Point采样原生帧上绘制整数像素蒙版，完全不重画、不重新采样身体。

## 受保护内容

- 128×96画布、锚点(64,80)、24个原有姿态及其位置全部保持。
- 原alpha逐像素相同；最外一圈身体轮廓RGB也保持原样，只有内层既有中暗色像素可加纹。
- 只用现有共享16色，每张图修改前后的独立RGB色集合完全相同。
- 四动作帧率仍为base_fps×0.75，SpriteFrames与目录JSON不由此脚本修改；新GIF按现有速度重出。

## 执行

```text
python tools/assets/apply_cave_spider_stripes.py --magick work/imagemagick/portable/magick.exe --apply
python tools/assets/apply_cave_spider_stripes.py --magick work/imagemagick/portable/magick.exe --verify-live
```

默认每次先按只读的`data/art/cave_enemy_imagemagick.json`重新从RAW生成未加纹的ImageMagick Point帧到`work/spider_stripes/unstriped/`，再叠纹到`striped/`。不会用已加纹帧作为下一次输入，因此重跑不累积变白。`masks.json`登记了24张未加纹帧的RGBA SHA256；传入已经加纹或几何改变的图片会拒绝处理。

首次`--apply`前的24帧、4个GIF、contact_sheet、SpriteFrames与单怪catalog可恢复副本位于`work/spider_stripes/before_original/`，带.gdignore和逐文件SHA256清单。该副本不被后续重跑覆盖。

## 主转换管线挂接

主转换管线已在`convert_cave_imagemagick.convert_frame()`对蜘蛛完成RAW→Point后、生成该帧最终hash/可见范围元信息之前调用本模块的`apply_one(binary,key,source,destination,stage,rules)`：

```python
from apply_cave_spider_stripes import apply_one, load_rules
rules = load_rules()
# key形如 idle/00；source是刚生成的未加纹Point帧。
stripe_record = apply_one(binary, key, point_frame, point_frame, stage / 'spider_masks', rules)
# 随后再计算最终输出sha256，记录stripe_record，按原流程刷新目录/契约/GIF。
```

函数会先检查输入为登记的未加纹帧，临时输出与原路径分离后再拷回，source/destination可以相同。它不更改通用转换配方、调色板、数据表、动作速度或SpriteFrames。单独CLI也支持`--input-dir <未加纹frames目录> --output-dir <后处理frames目录>`。总包转换器会刷新目录及转换报告中的最终hash，不得沿用改纹前hash。

## 检视文件

单怪目录`assets/PROCESSED/enemies/CAVE-BEASTS/v001/cave_spider/`中：

- `stripes_before_after_24.png`：24帧前后逐对对照。
- `stripes_idle_comparison_4x.png`：同一闲置帧的4倍nearest对照，放大只用于检视。
- `contact_sheet.png`：更新后的原生24帧图集。
- 原4个动作GIF按原0.75倍速度更新；运行仍使用原生PNG。
- `stripe_validation.json`：逐帧改变像素数、占比、alpha、轮廓、色数与RGBA哈希验证。
