# 专用像素网格恢复工具实际试用

2026-11-17。已安装并真实处理项目样例，全部试验产物在work/pixel_tools，不覆盖运行素材、地图或数值。没有启动Godot，没有调用模型或上传素材。

## 工具与来源核对

实际试用[Proper Pixel Art官方仓库](https://github.com/KennethJAllen/proper-pixel-art)，软件版本2.0.0，固定源码commit `4de0dda5ba066491b5b5fac3500365db4dfd665e`，MIT许可。完整许可证保留在`work/pixel_tools/proper-pixel-art/LICENSE`以及`work/pixel_tools/trial/PROPER_PIXEL_ART_LICENSE.txt`。

同时只读克隆核对了[SpriteSheet Cleanup官方仓库](https://github.com/elonen/spritesheet-cleanup)，commit `7a895aead607622592de9362ab5c4e24953b5720`，MIT许可，未安装和运行第二套。两者应称为可评估的开源恢复工具，不把仓库存在或自称Production/Stable当作已通过本项目验收。

先读pyproject.toml、CLI和image/mesh/colors/video源码后才安装。所运行的Proper Pixel Art路径只使用本地Pillow、NumPy、OpenCV、SciPy等计算；未见HTTP、socket、模型权重下载或上传调用。Gradio属于可选web extra，未安装或启动；openai只在仓库的独立scripts依赖组中，未安装或使用。仅安装了核心CLI/API，隔离环境为`work/pixel_tools/venv`，pip缓存也在该目录树内，实际依赖版本保存在`trial/requirements-lock.txt`。

运行时OpenCV和BLAS均限1线程；5次单图恢复分别约0.04～0.12秒，完整试验包含共享网格约数秒，Windows实际Python进程峰值85.7MiB。早期PowerShell统计到venv启动器的4.7MiB不是计算进程，已排除，采用进程内部GetProcessMemoryInfo的PeakWorkingSet值。

## 实际样例和结果

样例A取自`assets/RAW/enemies/CAVE-BONE/v001/blade_source.png`，母版1374×1145、6列5行；按原图格裁切相邻两张闲置帧，每格229×229，裁切过程中没有预先缩小。样例B为新forest岩壁母版1254×1254的左上418×418区域。没有用软件自带示例冒充项目样例。

所有结果均保存真实1×PNG；另有4倍nearest检查图，放大图不作为运行资源。

| 方式 | 帧0输出 | 帧1输出 | 判断 |
|---|---|---|---|
| 两帧各自auto检测 | 87×88 | 77×86 | 同样229×229输入也产生不同网格，不能直接用于动画 |
| 各自固定pixel_width=4 | 67×67 | 63×66 | 固定像素宽度仍不足，Hough网格相位/分割线各自变化 |
| 批次公共网格，pixel_width=4 | 61×66 | 61×66 | 画布与网格一致，但可见高度48/50px偏大于本项目42px目标 |
| 批次公共网格，pixel_width=5 | 49×55 | 49×55 | 可见高度39/42px、25/26种不透明颜色、alpha仅0/255；适合作为本样例的清理候选 |
| forest单图auto | 36×37 | — | 检测源像素宽12，26色；输出过粗，不能直接当本项目64px岩壁格使用 |

结论：软件能实际恢复到一格一像素、去掉大量平滑边缘和颜色噪声，输出不是高清图再套nearest。但auto猜测不等于项目要求的网格，也不保证细小武器、骨骼或裂缝都保留正确。已查看1×与4×结果：源图粗像素边的噪声被消除，公共网格可保持两帧同尺寸；自动模式有几何压缩和细节损失，森林auto尤其过粗。因此建议用“专门网格恢复工具＋批次固定公共网格＋数据硬限制＋人工查看”的流程，不能用“执行过某工具”替代质量验收。

## 可复现的实际命令

以下CLI已真实执行，输出`bone_00_cli_fixed4_1x.png`，不带`--scale-result`，所以文件保存的是真实1×结果：

```powershell
work/pixel_tools/venv/Scripts/ppa.exe work/pixel_tools/trial/bone_idle_00_source.png -o work/pixel_tools/trial/bone_00_cli_fixed4_1x.png -c 32 -w 4 -u 1 -t
```

CLI每帧独立运行仍会漂移。动画应使用软件自带公共网格API（本次已运行）：

```python
from proper_pixel_art.video import compute_video_mesh, FramePipeline
from proper_pixel_art.config import ColorConfig, PaletteConfig

colors = ColorConfig(method="palette", palette=PaletteConfig(num_colors=32))
mesh, factor = compute_video_mesh(frames, upscale_factor=1, pixel_width=5)
pipeline = FramePipeline(
    mesh, factor, frames[0].size, frames,
    transparent_background=True, color_config=colors,
)
results = [pipeline.process(frame) for frame in frames]
```

`frames`必须是按固定图集格裁出的同尺寸原始RGBA帧。对整个动作批次只检测一次网格、只建一次共享调色板，保存mesh坐标与公共源锚点；所有帧用同一pipeline，不能先逐帧裁边后各自auto。

本项目下一步应把该49×55原生结果按同一源根点映射直接补透明边放入登记的96×96画布，而不是把每帧可见高度强行重缩到42px。39/42px是两个姿势自身的可见范围变化，不应据此每帧改变密度。对于forest，应先锁定目标64px地形格与场景1texel/world-unit要求，再选择/校准源网格；36×37的auto结果不可再放大填64格后宣称合格。

## 产物与限制

- `work/pixel_tools/trial/run_trial.py`：完整实际试验，包含单图auto、独立固定宽度与公共网格4/5两档。
- `trial_results.json`：准确像素数、可见范围、颜色数、alpha、网格线坐标、耗时与进程峰值。
- `bone_00_shared5_1x.png`、`bone_01_shared5_1x.png`：推荐对照的真实1×恢复图；不是批准替换的最终素材。
- `bone_00_shared5_4x_check.png`等：检查放大图。
- `pixel_tool_comparison.png`：源图、普通nearest对照、独立auto和公共网格的并排检查。
- `*_steps/mesh.png`等：算法网格中间图，可检查分割线是否穿过造型关键部位。

样例只覆盖两个相邻闲置帧与一块岩壁，不代表整套30帧或全部森林已经通过恢复质量验收。本次只找工具并实测，不修改任何正式素材或数据。

## 已交付的项目封装

已新增`tools/assets/recover_pixel_grid.py`，依赖独立固定于`tools/assets/requirements-pixel-recovery.txt`（`proper-pixel-art==2.0.0`），完整MIT许可及来源固定在`tools/assets/licenses/proper-pixel-art-LICENSE.txt`。脚本不安装依赖、不联网、不上传素材，也不调用Godot。

脚本接受有序、同尺寸原始RGBA帧和严格JSON参数。必须显式给定整数`pixel_width`和`upscale_factor: 1`；色板上限只能1～32，全批次生成一次公共mesh和色板。可设置`expected_native_canvas`，检测结果不符立即失败。未给目标画布时直接输出恢复原生图；补画布时必须显式给`output_offset`或`native_anchor`与`output_anchor`，整批使用相同偏移。原始图坐标到恢复图的根点映射仍须对照保存的mesh人工确定，脚本不猜测源锚点、不按每帧包围盒自动贴底或居中。`transparent_background`沿用上游的公共边缘背景清除选项；已有透明图如不需要额外清除边缘同色像素可设false，原始alpha仍参与单格透明判定。

实际原生试验参数`work/pixel_tools/trial/recover_params.json`：

```json
{"pixel_width":5,"upscale_factor":1,"palette_limit":32,"transparent_background":true,"expected_native_canvas":[49,55]}
```

已真实执行的封装命令：

```powershell
work/pixel_tools/venv/Scripts/python.exe tools/assets/recover_pixel_grid.py --config work/pixel_tools/trial/recover_params.json --output-dir work/pixel_tools/trial/wrapper_native work/pixel_tools/trial/bone_idle_00_source.png work/pixel_tools/trial/bone_idle_01_source.png
```

输出目录必须是新目录，不覆盖原图或已有产物；每帧保存1×PNG并记录文件SHA256、RGBA SHA256、像素画布、有效范围、色数及alpha。`metadata.json`还保存全部输入哈希、固定网格坐标、实际公共色板、公共偏移、软件版本、已审核上游commit和实际安装源码commit。PyPI wheel如不含VCS信息则明确记为null而不虚构安装commit，另以安装模块SHA256记录实际算法来源。运行线程限制为1，单批不超过128帧和1600万源/输出像素。

通过`work/pixel_tools/trial/verify_wrapper.py`在同一隔离venv实际执行11项核查，结果保存在`wrapper_verification.json`：两张恢复PNG与早前shared5输出的**完整PNG文件哈希与RGBA像素哈希都相同**；原生49×55结果按固定偏移(24,36)补入96×96后，所复制区域RGBA逐像素完全相同。越界、upscale=2、33色色板、缺少固定偏移、预期尺寸不符、输入画布不一致六项均返回非零，且没有产生输出目录。没有后续重采样或裁切。这里只证明恢复工具及规格门禁按预期工作，未批准两张试验图进入运行素材。
