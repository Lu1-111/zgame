# corrumpt v005 · 特效统一制作提示词

工具：内置 imagegen；两次调用均以 v004/masters/phase_1_idle.png 为唯一材质参考，透明背景。Boss 已确认的两阶段本体帧从 v004 逐字节复制，没有重绘。

## 触手图集（完整调用提示词）

Create ONE production sprite atlas on genuine transparent background for an existing 2D dark fantasy pixel RPG boss. Attached image is the EXACT approved body material reference, 68x84 native pixels: study its thin dark outline, closely spaced fine pixel ridges, layered desaturated purple folds, olive/brown root fibers, black forked veins, small pale pink highlights. DO NOT redraw or include the flower body. Draw ONLY a single organic whip tendril in sixteen poses, all facing right, base at lower left. Critical style requirement: match the body's fine pixel density and rich small-scale texture; NOT huge smooth color bands, NOT vector shapes, NOT thick low-res outlines, NOT cartoon rubber. Use many fine 1-native-pixel longitudinal fibers, irregular dark cracks/veins, small alternating highlights like the reference's petal surfaces. Purple and dark olive on the same continuous surface, avoid a broad solid olive stripe. Tendril cross-section about 10-16 native pixels at base, narrowing to a needle tip, with small sparse sharp thorns. No antialias haze.
Atlas exactly FOUR columns by FOUR rows, all cells equal 320 wide x224 high logical native pixels, total1280x896 aspect ratio10:7. All tendril bases at the same logical (32,192) in each cell; no grid lines, labels, text or contact shadow. Leave 16+ pixels empty around every silhouette. Individual poses:
Row1 cells1-4: short idle curled roots, width26px and height22px, subtly swaying.
Row2: cell1 partially extending width72 height48; cell2 width120 height74; cell3 width210 height120; cell4 fully raised long whip width238 height160, a tall inverted-J curl with tip pointing down, more than twice flower body height.
Row3: six-frame downstroke starts here, four poses with horizontal reach238 each, decreasing tip/arc height146,120,94,64 above base. Keep shaft thickness and fine texture consistent, draw a smoothly bending flexible tendril.
Row4: first two cells finish the downstroke with same reach238 and heights34 and6 above the base, fully flattened along ground in cell2. DO NOT flatten the shaft thickness or the pixels; only curve the pose lower. Last two cells: short root curling into ground, then short root withdrawing upward.
Every sprite must be complete, with no crop at cell edges or overlap into adjacent cells. Fine hand-pixelated surface detail must match the attached boss body's craftsmanship at the SAME native pixel size. Transparent empty spaces, no background.

输出：sources/arm_actions.png；原始文件 exec-5c83ffb2-9fc9-474b-bd60-c99f818c5999.png。

## 六类特效图集（完整调用提示词）

Create ONE transparent sprite atlas for a dark fantasy pixel RPG boss. Attached image is the approved 68x84 pixel purple heart-like flower-bud boss, a material reference ONLY. Match its fine one-pixel dark contour, layered violet folds, black forked veins, olive root fibers and restrained pale-pink highlights. Do not include or change the boss body. Draw six effect families, FOUR frames each, in exactly FOUR columns by SIX equal-height rows. Total atlas aspect 2:1, logical cell256x85, total1024x510. Empty transparent padding around every frame. No labels, text, frame lines, background, blur, soft airbrush, giant flat color bands or low-resolution blocky outline. Fine, carefully placed native pixel edges and tiny 1px material marks matching the reference. Sparse restrained glow only, not noisy bright confetti.
Row1: a horizontal organic sharp needle pointing right, four subtly glinting frames. Logical final footprint20x8 pixels. Purple-black thorn-like projectile, pale sharp tip, clear readable silhouette.
Row2: a poisonous spore seed sphere, four subtly pulsing frames. Logical footprint20x20. Purple folded shell, dark vein divisions, tiny olive sepals, restrained luminous center. Match the bud exactly in material.
Row3: a cluster of ground spikes made of the boss's purple thorny roots, four phases: low emergence / rising / full extension / retreat. Full cluster logical32x40. Sharp tips, fine fiber veins and root folds; same center and ground baseline across four frames.
Row4: FOUR HORIZONTAL SEAMLESS MAGIC ENERGY RIBBON TEXTURES for a gravity circle. Each logical96x12 strip, same left/right height, continuous thin 1px pale lavender central filament plus darker violet broken filaments beside it, repeating delicate dark vein cracks, tiny sparse sparkles. Strips will wrap along a dynamically expanding ring without enlarging the pixels. Draw flat straight ribbons, NOT circular rings, no endcaps. Variation subtle across frames.
Row5: FOUR similar horizontal seamless ribbons for repulsion shockwave, logical96x12 strips; slightly more muted violet/olive-gold root dust accent, sharp fine pixel shock traces and thin pale center, no blur, no thick color stripes.
Row6: a low ground-impact shock burst spreading horizontally, four phases onset / strongest impact / breaking apart / dissipating. Logical footprint236x32. Detailed but restrained purple root fragments, thin arcing shock filaments, very few pale pixels, olive dust; keep clear ground baseline and centered origin across phases. Do not add weapons, creatures or flower bodies.
All six rows must look like extensions of the attached boss at the SAME pixel density, with clearly legible shapes at native display size.

输出：sources/effects.png；原始文件 exec-ec05c86d-45a3-4124-b1eb-177d12b22c28.png。

## 最终高举帧（完整调用提示词）

Draw ONE isolated long flexible root-whip tendril for a 2D dark-fantasy pixel RPG, on transparent background. Attached image is the exact approved purple heart-flower boss: use ONLY as a fine-pixel material reference (purple thin fibers, subtle olive fibers, black veins, pale small highlights). Do NOT draw the flower body. Draw one fully lifted strike-ready tendril, pointing to the RIGHT, base at lower LEFT, in a LOW WIDE ARCH shape. Critical silhouette: the tendril's horizontal reach MUST be substantially wider than its height: 238 native pixels horizontal reach and160 native pixels lift, width:height about1.5:1. It must NOT be an upright vertical stalk or tall narrow J. Rise diagonally from lower-left base, reach the high point around the middle-right, then hook down at the far-right tip, like a wide upside-down fishing hook or a whip held ready to lash the floor. Root attachment around logical(32,192), endpoint around(270,110), uppermost point y32; logical transparent canvas320x224. No ground roots/finger-like root base, just a single connected tendril shaft with a clean left attachment end. Cross-section near base10-16 native pixels narrowing continuously to1px tip, a few small thorns. Use the SAME fine one-pixel dark outline and rich tiny longitudinal violet fiber marks as the reference flower, no broad smooth color bands, no thick low-res dark contour, no antialias blur or glow. All material detail must be fine enough to match the 68x84-pixel body reference. Complete sprite, ample transparent padding, no text or framing.

输出：sources/raised_arm_original.png；原始文件 exec-e381092d-b2bb-40cf-8bd0-7bd071cd90eb.png。经ImageMagick离线旋转-10°对齐后保存为raised_arm.png，再等比采样，最终伸展238px、举高160px。仅替换高举帧；其他触手姿态保留上述图集。

## 装配说明

触手使用记录在 JSON 中的逐格根座、等比采样与固定世界连接点，禁止再分别拉伸长宽。地刺从图集中截取中心尖刺束，地面基线固定。针弹、孢子按主连通轮廓标定，忽略外散粒子造成的包围盒漂移。冲击和环带按目标原生画布烘焙，后续不再放大；圆环以环带纹理在1世界单位的像素网格上采样，扩散只改变半径。全部图像转换由ImageMagick执行，Pillow只读检查alpha和源点。

