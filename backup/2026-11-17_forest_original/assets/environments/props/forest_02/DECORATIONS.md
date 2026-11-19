# forest_02 装饰素材

2026-10-29 使用内置 **image_gen** 分别绘制，原始透明 PNG 保留；场景中的缩放、朝向、颜色与放置由 `data/maps/forest_02_art.json` 控制。

共同画风：横版古森林、手绘苔岩与盘根、低饱和橄榄棕和青绿色、侧视正交、透明底、无角色与文字。

| 素材 | 用途 | 完整生成提示词 |
|---|---|---|
| `fallen_log_v1.png` | 中空倒木、蕨叶与树生菌 | [提示词](fallen_log_v1.prompt.txt) |
| `broken_waystone_v1.png` | 残破遗迹路碑、花与缠根 | [提示词](broken_waystone_v1.prompt.txt) |
| `forest_fungi_v1.png` | 象牙色及暗青菌簇、苔石与蕨丛 | [提示词](forest_fungi_v1.prompt.txt) |
| `hanging_roots_v1.png` | 洞顶悬根、细藤与苔帘 | [提示词](hanging_roots_v1.prompt.txt) |

当前为 20 处地面装饰和 14 处悬挂装饰。所有节点有效渲染层为 1，位于角色层 20 之下；装饰不增加碰撞或交互。按有效不透明像素范围定位，地面底部略嵌入苔层，悬根顶部嵌入洞顶，避免透明留边导致悬空。
