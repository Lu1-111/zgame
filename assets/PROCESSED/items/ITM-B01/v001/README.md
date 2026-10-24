# ITM-B01 道具组件 v001

本包覆盖当前物品表12项：小型奶瓶、奶力药剂、体力药剂、奶弹、奶菇、蜜蜡、奶晶、生命碎片、体力碎片、奶力碎片、背包扩容卷、地图碎片；另附 OBJ-06 / ABL-01 奶泡跃奖励。奖励不计入12项物品。

直接双击 `preview.html` 可离线预览，无需服务器。目录动画、逐帧检查、暂停、倍速、明暗底、root 标记、拾取淡出和640像素同屏参考均可使用。`contact_sheet.png` 提供图标和世界造型总览。

## 文件与规格

| 文件 | 用途 |
|---|---|
| `frames/<data_id>/` | 每项4帧，32×32 RGBA |
| `icons/` | 每项1张24×24透明图标，适配26/28像素槽位 |
| `sheets/` | 每项128×32横排动画条 |
| `ITM-B01_v001_atlas.png` | 4列×13行、52帧，无trim/rotate |
| `ITM-B01_v001_icons.png` | 13枚图标的横排总图 |
| `manifest.json` | ID、原图及提示词、SHA256、每帧源矩形、平移/尺度、root、播放参数 |
| `qa.json` / `VALIDATION.json` | 像素诊断及实际验收记录 |
| `godot/ItemVisual.tscn` | 可复用世界展示节点 |
| `godot/ItemSpriteFrames.tres` | 13个循环动画，共52帧 |

默认4 FPS、4帧循环；所有帧 root `(16,24)`，世界主体底边对齐该锚点。展示节点在 root 上方2px，额外上下浮动1px；视觉浮动不会移动节点原点。拾取从当下位置连续上移8px并淡出，默认0.35s。所有参数收录于 manifest 和生成的 ItemCatalog，均为可调整的展示建议。

能力奖励以奶滴中心和最低奶泡弧环确定语义root，四帧使用相同的最终平移，避免追逐闪点边缘；其他道具按最大可见主体注册。生命为心形、体力为叶形、奶力为水滴形，同时用轮廓和颜色区分。世界精灵保留外围闪点；UI图标从RAW首帧主体及5%留白直接缩小，舍去远处装饰闪点，避免二次缩放世界帧。

## Godot 4 使用

保持整个包的目录结构，实例化 `godot/ItemVisual.tscn`。节点 ready 后调用：

```gdscript
# 放到游戏已有的掉落物或奖励节点下，位置即拾取物的世界root。
item_visual.position = drop_position
item_visual.set_item(&"hp_fragment")

# 可把同一造型用于TextureRect。
icon.texture = item_visual.get_icon()

# 必须先由游戏自身确认奖励结算，再触发视觉反馈。
item_visual.play_pickup()

# 对象池复用 / 暂停。
item_visual.reset_visual()
item_visual.set_visual_paused(true)
```

`set_item()` 拒绝未知ID且不改变当前展示；有效ID从首帧重播。`play_pickup()` 在淡出中或领取态返回false，避免重复完成通知；完成后隐藏并发出 `pickup_visual_finished(item_id)`。`reset_visual()` 恢复首帧、位置和透明度。暂停冻结动画帧、浮动和拾取时间；`playback_rate=0` 同样冻结。暂停状态下切换物品会保持暂停。

`AnimatedSprite2D` 使用 `centered=false`、`offset=(-16,-24)` 和 Nearest。组件没有碰撞、自动拾取、库存或数值结算；本批未接入主场景。这些图标与显示动画不能代替游戏中使用道具、投掷或爆炸的攻击效果。

Catalog 通过 preload 引用 SpriteFrames、全部帧和图标，导出依赖不依赖运行时读取JSON。`.png.import` 使用Lossless、关闭mipmap和alpha边缘修补。

## 来源与处理

13张原图均通过内置 image_gen 独立生成，完整提示词位于 RAW 对应文件旁。所有 RAW 原始字节不变。

处理流程：按实际627×627格切帧；在共同大画布中作整数配准，消除排版造成的降采样相位差；每项四帧共用同一Nearest尺度；再以整数平移校准主体底部。未逐帧缩放、重绘、补间或阈值修改Alpha。分析时的Alpha128阈值只用于识别主体，输出保留输入的RGBA采样结果。32×32的自然降采样会舍去部分细小闪点。

`processing/build.py`、`processing/preview_template.html` 保存本批构建配方；需要当前项目、RAW和Python环境。构建器拒绝覆盖已有成品目录，修订应切换版本/输出位置。

首版仍有少量像素高光和轮廓变化。目录预览及逐帧记录可供继续精修；主游戏中的实际拾取范围、背包满包行为及手感需在接入时联调。
