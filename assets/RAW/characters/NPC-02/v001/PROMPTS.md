# NPC-02 奶牛商人 v001

使用内置 image_gen，身份参考 NPC-S02 v002；画风参考 CHR-01 v001。正式资产提前准备，不接入灰盒场景。

## Master

ONE full body milk cow merchant in horizontal platformer side view, slightly three-quarter, facing RIGHT. Cute round golden yellow cream cow, cream muzzle, huge green eyes, two short pale horns, broad cow ears, small dark hooves, cream apron with brown cow spots, brown waist belt and small round pouch. Crisp stepped pixel edges, limited golden palette, dark brown thin outline. Friendly calm neutral pose, arms at waist. Genuine transparent alpha, whole body with margin. No shadow, scenery, counters or text. Target 64×64, character height 42 including horns, root (32,58).

## Animation plan

4 actions × 6 frames: idle, talk, trade_offer, trade_confirm. Same right-facing identity, apron spots, horns and silhouette; planted feet, stable character scale and root. Each action starts and ends in compatible neutral pose. Trade uses one small cream potion bottle with a green stopper; no additional objects.

## 本次实际生成

首个独立 master 调用等待约10分钟后终止。改以原始奶牛参考和主角画风直接生成24帧正式sheet，30秒返回。正式master由idle第1帧派生，保持同一身份。

Sheet prompt: Pixel-art production sprite sheet for NPC-02 milk cow merchant,24 full-body animation frames,6 columns4 rows,transparent alpha. All24 SAME cow,side view slight3/4 facing RIGHT. Golden yellow skin,cream muzzle,green eyes,pale short horns,cow ears,brown hooves,cream apron with identical brown spots,brown belt and small coin pouch. Crisp chunky pixels,dark outline,gold shadows. Equal scale,planted soles,full horns and feet with margin. Row1 idle6 gentle breath/blink. Row2 talk6 mouth and small hand gesture. Row3 trade_offer6 neutral,reaching pouch,produce cream bottle green stopper,extend,withdraw,neutral. Row4 trade_confirm6 neutral,extend palm,receive coin,lower hand to pouch,nod,neutral. Compatible neutral start/end. No lines/text/numerals/background/shadows/scenery/counter/sparkles. Target64x64 height42 root(32,58).

正式 NPC-02_master_right_v001.png 是动作 sheet 第1格 idle 首帧的机械裁切（0,0,256,256），不是独立生图。
