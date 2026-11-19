"""为当前素材构建器写出Godot SpriteFrames资源，不包含历史像素转换流程。"""

def write_frames(path, animations):
    textures = [frame for row in animations.values() for frame in row['frames']]
    text = [f'[gd_resource type="SpriteFrames" load_steps={len(textures)+1} format=3]', '']
    text += [f'[ext_resource type="Texture2D" path="{value}" id="t{i}"]' for i,value in enumerate(textures)]
    text += ['', '[resource]', 'animations = [']
    rows=[];index=0
    for name,row in animations.items():
        entries=[]
        for _ in row['frames']:
            entries.append('{"duration":1.0,"texture":ExtResource("t%d")}' % index)
            index+=1
        rows.append('{"frames":[%s],"loop":%s,"name":&"%s","speed":%s}' %
                    (','.join(entries),str(row['loop']).lower(),name,row['fps']))
    text += [',\n'.join(rows), ']']
    path.write_text('\n'.join(text)+'\n',encoding='utf-8')

