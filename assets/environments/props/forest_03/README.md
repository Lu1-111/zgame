# forest_03 新增装饰素材

2026-11-12使用内置 `image_gen`，新图生成模式，`transparent_background: true`，无参考图片。原始透明PNG直接保存在本目录；游戏内仅按有效像素范围锚定、等比缩放及可选水平翻转。

下表提示词按本次生成要求整理，保留制作规格便于后续衍生。源文件名对应本次会话生成结果，SHA256校验保证原画可追溯。

| 素材 | 外观 | 提示词规格 |
|---|---|---|
| `glow_fungi_v1.png` | 微光菌石 | [glow_fungi_v1.prompt.txt](glow_fungi_v1.prompt.txt) |
| `seedpod_vines_v1.png` | 荚果垂藤 | [seedpod_vines_v1.prompt.txt](seedpod_vines_v1.prompt.txt) |
| `root_arch_v1.png` | 苔根拱 | [root_arch_v1.prompt.txt](root_arch_v1.prompt.txt) |

这些3种新装饰与forest_02的倒木、残碑、菌簇、悬根共同放置32处；配置见 `data/maps/forest_03_art.json`。全部位于装饰层1，角色与敌人层20，装饰无碰撞。

- `glow_fungi_v1.png`：源 `exec-82de43dc-3823-4e9e-9619-233a6e191068.png`，SHA256 `b4fe69af251c0b2d885f27a01b352ca51b89b3fd06f66985d4d4e395cbdcf5a2`。
- `seedpod_vines_v1.png`：源 `exec-88a25444-df05-4931-9375-95d510ed7a57.png`，SHA256 `bf2caf19381ce3bcaa969329559c890f682a56a57c61449dfd8a19ac3279a54a`。
- `root_arch_v1.png`：源 `exec-eec064be-3b76-41d8-b874-03e43f03f183.png`，SHA256 `fabdb0d12410fb5b5a59c047c4e1ccc32bcd987c863aab4ffa5436a89510bacb`。
