# Cave 兽类动作素材

2026-11-17。内置imagegen制作实际形变动作母版，源图及完整提示词归档于`assets/RAW/enemies/CAVE-BEASTS/v001`。本目录仅美术准备，不注册正式AI、不创建关卡，基础生命、攻击、韧性、抗性以及弹幕伤害/速度/寿命均未分配。

| ID | 名称 | 画布 / 锚点 | 动作（每套6帧） |
|---|---|---|---|
| stonehelm_beast | 岩盔兽 | 128×96 / (64,80) | idle、move、ram撞击、shell_defense缩壳 |
| cave_spider | 洞穴蜘蛛 | 128×96 / (64,80) | idle、move、claw_attack爪击、web_spit吐丝 |
| animated_crystal | 活化晶石 | 96×96 / (48,48) | idle、move、charge_ready发光准备 |
| cavern_hunter | 岩穴猎手 | 192×160 / (96,140) | idle、move、elbow_blade岩刃、leap_slam跃起下砸、tail_crystal_shot扬尾发射 |

4类、16套动作、96张本体帧；`effects/`包含丝线弹(web_thread)、尖晶石(sharp_crystal)、下砸震荡波(ground_shockwave)，各6帧，共114帧。三种效果均有独立catalog和SpriteFrames，精确路径列在总`catalog.json`。

所有贴图共用16色、二值alpha、nearest，运行scale=(1,1)。岩盔兽闲置可见高度中位约44px、蜘蛛约48px、晶石聚合体约56px、猎手约70px，以玩家约42px为密度参考。画布留白用于攻击展开和抬尾，不等于本体大小。

当前imagemagick_v002通过ImageMagick从RAW直接Point点采样，无抖动、无面积平均色，透明蒙版独立保存并恢复。配置在data/art/cave_enemy_imagemagick.json，旧面积采样构建器已禁止覆盖。构建器对每个怪物所有帧使用同一源到原生像素比例，仅平移注册脚底/核心锚点；禁止按每帧包围盒分别缩放。跃起下砸帧有明确的纵向移动，身体是生成的独立蹲伏/腾空/着地姿态，不是同一张图平移。转换参数、每帧SHA256、可见范围、6帧动作唯一性和相位标注均保存在每怪catalog及conversion.json。

`sprite_frames.tres`的纹理使用完整固定画布。AnimatedSprite2D若centered=false应放在`-anchor`；若centered=true，应使用`canvas/2-anchor`偏移。不要用包围盒重新缩小本体。浮游晶石锚点为核心中心，其余为地面脚底。左右方向使用运行时flip_h，不重复插值缩放。

每动作有2倍nearest GIF供检查，GIF不可作为运行纹理；原生contact_sheet.png展示完整逐帧画布，overview.png用于查看外形和主要战斗姿态。各动作的FPS是美术预览速度，正式战斗节奏尚未确定，不代表平衡数值。

31套洞穴本体/效果中的本包动作全部按原始fps乘0.75，时长增加为原4/3；SpriteFrames、目录JSON、GIF同步。转换前副本在backup/2026-11-17_cave_before_imagemagick。

建议接入事件标注：吐丝/扬尾发射在第4帧（索引3），下砸接触第5帧（索引4），缩壳保持第4帧，晶石准备保持最后一帧。真实命中和条件由后续AI决定，不用图片播放结束自行结算伤害。

## 重建与验收

```text
python tools/assets/convert_cave_imagemagick.py --magick <magick可执行文件> --apply
python tools/qa/validate_pixel_assets.py --manifest assets/PROCESSED/enemies/CAVE-BEASTS/v001/pixel_manifest.json
```

当前自检：114张图片，0失败；16套本体动作每套6张独立帧，3套效果每套6张独立帧；全图均≤16色、硬alpha、固定原生画布，无边界裁切。Godot导入、资源运行和项目单元测试由根代理集中执行，避免多代理同时打开引擎。
