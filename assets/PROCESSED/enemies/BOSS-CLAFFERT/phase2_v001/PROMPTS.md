# corrumpt 二阶段素材制作记录

顺序：先完成原有外形与八帧闲置的标准化及导入验证，再绘制下列攻击素材。使用内置imagegen，透明背景。参考图为本目录masters/phase_2_idle.png（已标准化母版），不是历史高分辨率原图。

## 刀瓣延长与切换

Create a production pixel-art animation atlas based STRICTLY on the attached approved boss sprite. This is the FINAL character identity reference, a frontal floating purple flower with a black circular abyss center and THREE concentric layers of sharp purple petals. Preserve its violet/black/pale pink palette, thin dark pixel outlines, small dark forked veins, symmetry, front-on camera, and individual layered petal arrangement. No roots, stalk, vines, base, hands, scenery, glow cloud or perspective tilt. Generate EIGHT transition poses in 4 columns by2 rows of equal square cells, logical cell128x128. Each flower center fixed exactly at the center of its cell. In frame1 identical ordinary flower form. Over frames2-8 the SAME petals extend radially outward and narrow into unmistakably long sharp blade-shaped petals, becoming a circular multi-bladed cutting flower. No extra petals or body additions. Flower diameter grows gradually from84 native pixels to120 native pixels, always fitting the128x128 cell with padding; central abyss and inner rim must NEVER change diameter, shape or position. Outer three layers elongate smoothly; same rootless flower body across every frame. Final silhouette should look like long razor-edged metallic-organic purple blades, pointed knife tips and dark veins, not soft round petals. Fine hand-pixel texture at the SAME native pixel density as the reference, no thick macro pixel blocks, blur, painterly gradients or antialias haze. Transparent background, no text, numbers or grid lines, every sprite complete, no overlap.

原始输出：exec-f7de2311-90c2-48fb-ba76-7cfa739a8beb.png，已复制到sources/blade_extend.png。

## 破空气流

Create one small production sprite sheet of FOUR sequential frames of a simple air-cutting slipstream for a fast charging purple blade-flower boss in a dark fantasy pixel RPG. Horizontal4x1 grid, each logical frame96x24 native pixels, complete with transparent margins. Draw only two or three thin sharp pale lavender/gray wisps sweeping LEFT from a pointed open leading edge on the RIGHT, tiny broken violet flecks, strong readable direction rightward, restrained and clean. No character, flower, weapon, scenery, circles, text, grid, glow fog or blurred gradients. Fine1px dark violet outlines and sparse white/lavender highlight pixels, matching a32-color purple pixel RPG palette. Four frames: opening thin crescent lines, strongest stretched air streaks, broken streaks, dissipating flecks. Genuine transparent background. This is a subtle airy motion cue behind a dashing entity, NOT a giant magical slash or explosion.

原始输出：exec-d0fd2a0b-e980-476f-ba3d-2bbf079df2ce.png，已复制到sources/airflow.png。

## 转换与装配

ImageMagick按固定花心装配128×128画布，1:1原生像素、共用一阶段32色色板、硬透明、nearest。八帧闲置先校正花心偏移，再固定最内侧6px深色核心；保留原三层刀瓣与无根正面造型。新刀瓣按花心最远半径定尺寸，不按逐帧包围盒分别放大；旋转帧以(64,64)离线整数像素采样烘焙，不使用骨骼或运行时身体旋转。收瓣逆序复用完整延长帧。全部旋转帧检查刀尖不接触画布边界，避免裁切。完整参数在data/bosses/claffert.json的art.phase2中。

