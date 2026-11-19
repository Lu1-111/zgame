"""固定数字ID、完整参数文档与安全回填；数值仍以各JSON为运行源。"""
from pathlib import Path
import copy
import hashlib
import json
import math
import re

ROOT=Path(__file__).resolve().parents[2]
REGISTRY='data/enemy_registry.json'
DOCS={'small':'小怪记录.md','elite':'精英怪记录.md','boss':'Boss记录.md'}
LABELS={'small':'小怪','elite':'精英怪','boss':'Boss'}
ALIASES={'shadow_wraith':'shadow_wisp','lamp_beetle':'lamp_bug','claffert':'corrumpt','BOSS-CLAFFERT':'corrumpt'}
BASE={'base_hp':'基础生命','base_damage':'基础攻击','defense':'防御','poise':'韧性','resist.physical':'物理抗性（%）','resist.magic':'奶术抗性（%）','tier':'设计等级','exp':'击杀经验','coin_drop':'奶币数量范围'}
MOVE={'damage_multiplier':'伤害倍率','telegraph_duration':'准备秒数','attack_duration':'动作秒数','recover_duration':'收招秒数','cooldown_seconds':'冷却秒数','attack_hit_start':'有效判定开始秒数','attack_hit_end':'有效判定结束秒数','attack_range':'起手距离px','hitbox_size':'命中框宽高px','hitbox_offset':'命中框偏移px','attack_knockback':'击退速度px/s','poise_damage':'攻击削韧','damage_type':'伤害类型','projectile_id':'弹幕标识','windup_seconds':'准备秒数','active_seconds':'攻击有效秒数','recovery_seconds':'收招秒数'}
PLACEHOLDERS={key:None for key in ['damage_multiplier','damage_type','windup_seconds','active_seconds','recovery_seconds','cooldown_seconds','attack_hit_start','attack_hit_end','attack_range','hitbox_size','hitbox_offset','attack_knockback','poise_damage','projectile_id']}
MOVE_NAMES={'attack':'攻击','planned_split':'分裂（待实装）','planned_summon':'召唤（待实装）','planned_spray':'喷射（待实装）','planned_shield':'防御（待实装）','planned_acid_trail':'酸液痕迹（待实装）','planned_glow':'发光（待实装）','slash_down':'向下挥砍','slash_up':'向上挥砍','thrust':'刺击','shoot':'拉弓射击','charge':'撞击','defend':'缩壳防御','claw':'爪击','web':'吐丝','prepare':'发光准备','blade':'前爪岩刃','slam':'跃起下砸','tail':'尾部晶石发射'}
MOVE_NAMES.update({'grab':'捕食','bite':'啃咬','ram':'撞击','shell_defense':'缩壳防御','claw_attack':'爪击','web_spit':'吐丝','charge_ready':'发光攻击准备','elbow_blade':'前爪岩刃','leap_slam':'跃起下砸','tail_crystal_shot':'尾部晶石发射'})


class Store:
    def __init__(self):self.files={};self.dirty=set()
    def read(self,name):
        if name not in self.files:self.files[name]=json.loads((ROOT/name).read_text(encoding='utf8'))
        return self.files[name]
    def at(self,file,path):
        value=self.read(file)
        for key in path:value=value[key]
        return value
    def set(self,file,path,value):
        node=self.read(file)
        for i,key in enumerate(path[:-1]):
            if isinstance(node,dict) and key not in node:node[key]=[] if isinstance(path[i+1],int) else {}
            node=node[key]
        node[path[-1]]=value;self.dirty.add(file)
    def fingerprint(self):return hashlib.sha256(json.dumps(self.files,ensure_ascii=False,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    def write(self):
        for name in self.dirty:(ROOT/name).write_text(json.dumps(self.files[name],ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        self.dirty.clear()


def canonical(name):return ALIASES.get(name,name)


def flatten(value,prefix=''):
    if isinstance(value,dict):
        for key,item in value.items():yield from flatten(item,(prefix+'.' if prefix else '')+str(key))
    else:yield prefix,value


def get(value,parts,default=None):
    for key in parts:
        if not isinstance(value,dict) or key not in value:return default
        value=value[key]
    return value


def source_row(store,entry,index):
    source=entry.get('source')
    if not source:return entry['draft'],REGISTRY,['entries',index,'draft']
    value=store.read(source['file']);path=[]
    if source.get('collection'):
        path=[source['collection'],next(i for i,r in enumerate(value[source['collection']]) if r['id']==source['id'])]
        value=store.at(source['file'],path)
    return value,source['file'],path


def art_inventory(store):
    result={}
    for path in sorted((ROOT/'assets/PROCESSED/enemies').glob('ENM-*/v*/manifest.json')):
        relative=path.relative_to(ROOT).as_posix();data=store.read(relative)
        for name,a in data.get('animations',{}).items():
            slug='milk_slime_child' if name.startswith('child_') else canonical(data['slug'])
            name=name.removeprefix('child_')
            group=result.setdefault(slug,{'sources':[],'versions':[],'current':{}})
            if relative not in group['sources']:group['sources'].append(relative)
            n=a.get('frame_count',len(a.get('frames',[])));fps=a.get('fps')
            row={'name':name,'frames':n,'fps':fps,'seconds':n/fps if fps else None,'canvas':data.get('canvas'),'anchor':data.get('root'),'loop':a.get('loop'),'source':relative}
            group['versions'].append(row);group['current'][name]=row
    for batch in ['ENM-B03','ENM-B04','ENM-SLIME-GRAB']:
        relative=f'assets/PROCESSED/enemies/{batch}/v001/catalog.json'
        for a in store.read(relative)['effects']:
            slug=canonical(a.get('gameEnemyId',''))
            if not slug:continue
            group=result.setdefault(slug,{'sources':[],'versions':[],'current':{}})
            if relative not in group['sources']:group['sources'].append(relative)
            n=a.get('frame_count',a.get('frameCount',len(a.get('frames',[]))));fps=a.get('fps')
            row={'name':a['name'],'frames':n,'fps':fps,'seconds':n/fps if fps else None,'canvas':a.get('target'),'anchor':a.get('anchor'),'loop':a.get('loop'),'source':relative,'kind':a.get('kind','body')}
            group['versions'].append(row)
            if row['kind']=='body':group['current'][row['name']]=row
    return result


def discover(store):
    identities={e['id']:e['name'] for e in store.read('data/enemies.json')['enemies']}
    for p in sorted((ROOT/'data/bosses').glob('*.json')):
        e=store.read(p.relative_to(ROOT).as_posix());identities[e['id']]=e['name']
    for p in sorted((ROOT/'assets/PROCESSED/enemies').glob('ENM-*/v*/manifest.json')):
        e=store.read(p.relative_to(ROOT).as_posix());identities.setdefault(canonical(e['slug']),e['name'])
    for e in store.read('data/enemy_designs/cave_v001.json')['enemies']:identities[e['id']]=e['name']
    identities.setdefault('milk_slime_child','小奶滴（史莱姆分裂体）')
    for slug in art_inventory(store):identities.setdefault(slug,slug)
    return identities


def register_new(store,slug,category,name=None):
    """显式追加固定编号；已有身份拒绝重编号，分类不参与编号计算。"""
    registry=store.read(REGISTRY)
    if not re.fullmatch(r'[a-z][a-z0-9_]*',slug):raise ValueError('Runtime ID must use lowercase letters, digits and underscores')
    if category not in DOCS:raise ValueError('Choose small / elite / boss')
    if any(slug in [e['runtime_id'],*e['aliases']] for e in registry['entries']):raise ValueError('Identity already has a fixed numeric ID: '+slug)
    number=int(registry['next_numeric_id'])
    if number>9999:raise ValueError('Four-digit ID space exhausted; explicit schema migration required')
    source=None;ready=False
    for file,collection in [('data/enemies.json','enemies'),('data/enemy_designs/cave_v001.json','enemies')]:
        if any(e['id']==slug for e in store.read(file)[collection]):source={'file':file,'collection':collection,'id':slug};ready=file=='data/enemies.json';break
    for path in sorted((ROOT/'data/bosses').glob('*.json')):
        relative=path.relative_to(ROOT).as_posix()
        if store.read(relative)['id']==slug:source={'file':relative};ready=True;break
    draft={key:None for key in ['base_hp','base_damage','defense','poise','tier','exp','coin_drop']}
    draft.update({'resist':{'physical':None,'magic':None},'ai':{key:None for key in ['type','patrol_speed','chase_speed','attack_range','telegraph_time']}});draft['ai']['features']=[]
    row={'numeric_id':f'{number:04d}','runtime_id':slug,'name':name or discover(store).get(slug,slug),'category':category,'aliases':[],'variant_of':None,'source':source,'draft':draft,'moves':{},'loot':{'item_drops':None,'drop_rolls':None},'notes':'','combat_ready':ready}
    registry['entries'].append(row);registry['next_numeric_id']=f'{number+1:04d}';store.dirty.add(REGISTRY)
    return row


def placements(store):
    result={}
    def add(slug,kind,room):result.setdefault(canonical(slug),{}).setdefault(kind,set()).add(room)
    for room in store.read('data/world/regions.json')['rooms']:
        for spawn in room.get('enemies',[]):add(spawn.get('enemy_id',spawn.get('id')),'世界规划',room['id'])
    for folder,kind in [('data/maps','正式场景'),('test/data/forest_candidates','备选试玩')]:
        for path in sorted((ROOT/folder).glob('*.json')):
            data=store.read(path.relative_to(ROOT).as_posix())
            if not isinstance(data,dict) or 'enemies' not in data:continue
            if kind=='正式场景' and not (ROOT/'scenes/maps'/(data.get('id',path.stem)+'.tscn')).exists():continue
            for spawn in data['enemies']:add(spawn.get('enemy_id',spawn.get('id')),kind,path.stem if kind=='备选试玩' else data.get('id',path.stem))
    return result


def seed_moves(store):
    cave={e['id']:e for e in store.read('data/enemy_designs/cave_v001.json')['enemies']}
    changed=False
    for entry in store.read(REGISTRY)['entries']:
        if entry['combat_ready']:
            source,_,_=source_row(store,entry,store.read(REGISTRY)['entries'].index(entry))
            for feature in source.get('ai',{}).get('features',[]):
                if feature not in ['split','summon','spray','shield','acid_trail','glow']:continue
                name='planned_'+feature
                if name not in entry['moves']:
                    entry['moves'][name]={**copy.deepcopy(PLACEHOLDERS),'count':None,'lifetime_seconds':None,'probability':None}
                    changed=True
            continue
        names=[a['id'] for a in cave[entry['runtime_id']]['actions'] if a['id'] not in ['idle','move']] if entry['runtime_id'] in cave else ['attack']
        for name in names:
            if name not in entry['moves']:entry['moves'][name]=copy.deepcopy(PLACEHOLDERS);changed=True
    if changed:store.dirty.add(REGISTRY)


def build_snapshot(store=None):
    store=store or Store();registry=store.read(REGISTRY);art=art_inventory(store);where=placements(store)
    cave_file='data/enemy_designs/cave_v001.json';designs=store.read(cave_file);cave={e['id']:e for e in designs['enemies']}
    combat=store.read('data/enemy_combat_b04.json');legacy=store.read('data/enemy_combat.json')
    encounter=store.read('data/encounter_rules.json');poise=store.read('data/poise.json');rules=store.read('data/boss_rules.json');store.read('data/enemy_scaling.json')
    records=[]
    for index,entry in enumerate(registry['entries']):
        slug=entry['runtime_id'];base,file,path=source_row(store,entry,index);sections={};parameters=[];notes=[]
        def add(section,key,label,value,file=None,path=None,note='',kind=None):
            p={'key':key,'label':label,'value':copy.deepcopy(value),'binding':[file,path] if file else None,'note':note,'kind':kind or ('bool' if isinstance(value,bool) else 'number' if isinstance(value,(float,int)) or value is None else 'list' if isinstance(value,list) else 'object' if isinstance(value,dict) else 'text')}
            sections.setdefault(section,[]).append(p);parameters.append(p)
        for key,label in BASE.items():
            if slug=='corrumpt' and key=='base_hp':
                add('基础属性与掉落','base.base_hp','各阶段基础生命',[p['base_hp'] for p in base['phases']],note='只读汇总；分别填写阶段属性表。')
                continue
            tokens=key.split('.');sentinel=object();value=get(base,tokens,sentinel)
            target_file,target_path=file,path+tokens
            if value is sentinel:value=get(entry['draft'],tokens);target_file=REGISTRY;target_path=['entries',index,'draft']+tokens
            note=''
            if slug=='corrumpt' and key in ['exp','coin_drop']:value=base['unconfirmed'][key];target_path=path+['unconfirmed',key];note='未定；演练运行占位为0，不发最终奖励。' if value is None else '制作人已填写；同步到运行奖励。'
            add('基础属性与掉落','base.'+key,label,value,target_file,target_path,note,'list' if key=='coin_drop' else 'number')
        add('基础属性与掉落','loot.item_drops','物品掉落表',entry['loot']['item_drops'],REGISTRY,['entries',index,'loot','item_drops'],'待填列表：item_id、数量范围、概率、条件。当前通用击杀只给经验/奶币，物品抽取尚未接入。','list')
        add('基础属性与掉落','loot.drop_rolls','物品抽取次数',entry['loot']['drop_rolls'],REGISTRY,['entries',index,'loot','drop_rolls'])
        if entry['combat_ready'] and slug!='corrumpt':
            tuning={k:copy.deepcopy(v) for k,v in combat.items() if k not in ['per_enemy','catalog_paths','arena','enemy_order','aliases','default_enemy','spawn_position']}
            tuning.update(combat.get('per_enemy',{}).get(slug,{}));tuning['detect_range']=encounter['perception']['detect_range'];tuning['lose_range']=encounter['perception']['lose_range']
            variants=tuning.get('attack_variants',[{'id':'attack'}])
            for ai,variant in enumerate(variants):
                name=variant['id'];merged={**tuning,**variant};prefix=['per_enemy',slug]+(['attack_variants',ai] if 'attack_variants' in tuning else [])
                ready=max(tuning['minimum_telegraph'],merged.get('telegraph_duration',base['ai']['telegraph_time']))
                for key in ['damage_multiplier','attack_duration','recover_duration','attack_hit_start','attack_hit_end','attack_range','hitbox_size','hitbox_offset','attack_knockback']:
                    value=merged.get(key,base['ai']['attack_range'] if key=='attack_range' else None)
                    add('招式：'+name,f'moves.{name}.{key}',MOVE.get(key,key),value,'data/enemy_combat_b04.json',prefix+[key],'当前有效值；改此格创建本怪覆盖。')
                add('招式：'+name,f'moves.{name}.telegraph_duration','实际准备秒数',ready,'data/enemy_combat_b04.json',prefix+['telegraph_duration'],'实际取准备值和最短预警的较大值。')
                add('招式：'+name,f'moves.{name}.cycle_seconds','准备+动作+收招秒数',ready+merged['attack_duration']+merged['recover_duration'],note='只读；不含独立idle间隔。')
                add('招式：'+name,f'moves.{name}.damage_type','伤害类型','physical',note='当前通用运行逻辑为物理攻击。')
                add('招式：'+name,f'moves.{name}.poise_damage','攻击削韧',get(entry['moves'],[name,'poise_damage']),REGISTRY,['entries',index,'moves',name,'poise_damage'],'待设定；不得擅填。')
            for key,value in flatten(tuning):
                if key.startswith('attack_variants'):continue
                if '.' in key and not key.startswith('animation_map.'):continue
                if key in ['detect_range','lose_range']:f,p,n='data/encounter_rules.json',['perception',key],'共用感知；改动影响其他普通敌人。'
                else:f,p,n='data/enemy_combat_b04.json',['per_enemy',slug]+key.split('.'),'本怪覆盖；未覆盖项继承公共值。'
                add('运动、碰撞与投射物','combat.'+key,key,value,f,p,n)
            for key,value in flatten(base['ai']):add('AI与声明机制','ai.'+key,key,value,file,path+['ai']+key.split('.'))
            mode='冲撞' if any(x in base['ai']['features'] for x in ['charge','dive']) else '直线投射物' if base['ai']['attack_range']>=tuning['ranged_threshold'] else '近战命中框'
            notes.append('当前实际攻击类型：'+mode+'；伤害按各招式倍率结算。features中的分裂/召唤/喷射等声明不等于通用控制器已实装这些招式。')
            old_config=store.read('data/enemy_presentation.json')
            for key,value in flatten(old_config.get('per_enemy',{}).get(slug,{})):add('旧演练覆盖（只读）','legacy.'+key,key,value,note='旧GameEnemy读取enemy_presentation；正式自然地图读取B04。')
            for name,move in entry['moves'].items():
                if not name.startswith('planned_'):continue
                for key,value in flatten(move):add('未实装声明招式：'+name,f'moves.{name}.{key}',MOVE.get(key,key),value,REGISTRY,['entries',index,'moves',name]+key.split('.'),'源features声明，尚无独立战斗实装；预留填写。',kind='text' if key in ['damage_type','projectile_id'] else 'list' if key in ['hitbox_size','hitbox_offset'] else 'number')
        elif slug=='corrumpt':
            for key,value in flatten(base['art']):add('首领美术与原生规格（只读）','art.'+key,key,value,note='美术参数需按像素契约制作、转换与检视，不通过数值文档修改。')
            for pi,phase in enumerate(base['phases']):
                for key,value in flatten(phase):add('首领分阶段属性',f'phases.{pi}.{key}',phase['name']+' / '+key,value,file,path+['phases',pi]+key.split('.'))
            for source_key,title in [('combat','一阶段招式与战斗'),('phase2_combat','二阶段招式与战斗'),('sequence','转场与虚空湮灭'),('skill_selection','选招规则'),('arena','场地'),('health_bar','血条'),('ui','界面')]:
                for key,value in flatten(base[source_key]):add(title,source_key+'.'+key,key,value,file,path+[source_key]+key.split('.'))
            for key,value in flatten(rules):add('Boss共用规则','boss_rules.'+key,key,value,'data/boss_rules.json',key.split('.'),'所有Boss共用。')
            for key,value in flatten(store.read('data/combat_feedback.json')['danger_warning']):add('危险红光共用参数','danger_warning.'+key,key,value,note='共用美术预警；时长参与招式总时序，需连同动作检视后修改。')
            notes+=base.get('provisional_parameters',[])
            for key in ['combat_enabled','defense','base_damage','poise']:
                add('首领全局参数','boss.'+key,key,base[key],file,[key],note='poise为兜底；各阶段覆盖值见分阶段表。' if key=='poise' else '')
        else:
            for name,move in entry['moves'].items():
                for key,value in flatten(move):add('招式：'+name,f'moves.{name}.{key}',MOVE.get(key,key),value,REGISTRY,['entries',index,'moves',name]+key.split('.'),kind='text' if key in ['damage_type','projectile_id'] else 'list' if key in ['hitbox_size','hitbox_offset'] else 'number')
            for key,value in flatten(entry['draft']['ai']):add('待实装AI','ai.'+key,key,value,REGISTRY,['entries',index,'draft','ai']+key.split('.'),kind='text' if key=='type' else 'list' if key=='features' else 'number')
            notes.append('仅有美术/设计，尚未接入战斗。预览时长不是战斗有效判定或冷却；未设定参数使用占位，不能按0生成可战斗实例。')
        if slug!='corrumpt':
            for key,value in flatten(encounter):add('共用感知、接触与反馈','encounter.'+key,key,value,'data/encounter_rules.json',key.split('.'),'共用，改动影响其他普通敌人。')
            for key in ['enemy_max','direct_stun_on_attack','unfilled_policy']:add('共用韧性规则','poise_rules.'+key,key,poise[key],'data/poise.json',[key])
        for key,value in flatten(poise['feedback']):add('共用削韧受击反馈','poise_feedback.'+key,key,value,'data/poise.json',['feedback']+key.split('.'),'所有敌怪共用。玩家各攻击削韧另见削韧值填写表.md。')
        animations=list(art.get(slug,{}).get('current',{}).values())
        if slug in cave:
            e=cave[slug];animations=[{'name':a['id'],'frames':len(a['frames']),'fps':a['fps'],'seconds':a['duration_seconds'],'canvas':e['canvas'],'anchor':e['anchor'],'loop':a['loop'],'source':cave_file} for a in e['actions']]
            owners={'bone_arrow':'bone_dragon_bow','web_thread':'cave_spider','sharp_crystal':'cavern_hunter','ground_shockwave':'cavern_hunter'}
            for ei,effect in enumerate(designs['effects']):
                if owners.get(effect['id'])!=slug:continue
                for key in ['damage','speed','lifetime']:add('弹幕/效果：'+effect['name'],f'effects.{effect["id"]}.{key}',key,effect.get(key),cave_file,['effects',ei,key])
                for a in effect['actions']:animations.append({'name':effect['id']+'/'+a['id'],'frames':len(a['frames']),'fps':a['fps'],'seconds':a['duration_seconds'],'canvas':effect['canvas'],'anchor':effect['anchor'],'loop':a['loop'],'source':cave_file})
        records.append({'entry':entry,'parameters':parameters,'sections':sections,'animations':animations,'versions':art.get(slug,{}).get('versions',[]),'placements':where.get(slug,{}),'notes':notes})
        if slug=='corrumpt':
            for resource in sorted((ROOT/'assets/PROCESSED/enemies/BOSS-CLAFFERT').glob('**/*.tres')):
                content=resource.read_text(encoding='utf8');prior=content.index('animations =') if 'animations =' in content else len(content)
                for match in re.finditer(r'"name":\s*&"([^\"]+)"\s*,\s*"speed":\s*([\d.]+)',content):
                    chunk=content[prior:match.start()];n=chunk.count('"duration"');fps=float(match.group(2));prior=match.end()
                    records[-1]['animations'].append({'name':match.group(1),'frames':n,'fps':fps,'seconds':n/fps,'canvas':'按首领档案','anchor':'按首领档案','loop':'"loop": true' in chunk or '"loop":true' in chunk,'source':resource.relative_to(ROOT).as_posix()})
    globals=[]
    policy=store.read('data/enemy_scaling.json')
    for tier,value in policy['tier_multipliers'].items():globals.append({'key':'scaling.tier.'+tier,'label':'区域等级'+tier+'倍率','value':value,'binding':['data/enemy_scaling.json',['tier_multipliers',tier]],'note':'等级成长尚未另行指定，初始均1.0。','kind':'number'})
    for ri,region in enumerate(store.read('data/world/regions.json')['regions']):
        for key in ['tier','enemy_multiplier']:globals.append({'key':f'region.{region["id"]}.{key}','label':region['name']+('等级' if key=='tier' else '区域修正倍率'),'value':region[key],'binding':['data/world/regions.json',['regions',ri,key]],'note':'三份文档共用同一配置，改一份即可。','kind':'integer' if key=='tier' else 'number'})
    return {'store':store,'registry':registry,'records':records,'globals':globals,'fingerprint':store.fingerprint()}


def display(value):
    if value is None:return '待填写'
    if isinstance(value,bool):return 'true' if value else 'false'
    if isinstance(value,(list,dict)):return json.dumps(value,ensure_ascii=False,separators=(',',':')).replace('|','&#124;')
    return str(value).replace('|','&#124;').replace('\n','<br>')


def render_document(snapshot,category):
    rows=[r for r in snapshot['records'] if r['entry']['category']==category]
    lines=[f'# {LABELS[category]}记录','',f'<!-- enemy-source-sha256: {snapshot["fingerprint"]} -->','数字ID全局固定不复用；运行标识与素材ENM编号另列。只改参数表的“设定值”列，未设定保留“待填写”。填写后执行 `python tools/data/sync_enemy_registry.py --import-docs` 校验并回填JSON；类型错误、共享值冲突或原数据已变化会拒绝写入。','',
    '生命/攻击等base_属性在出生时乘“区域等级倍率×区域修正”；目前等级0/1/2均1.0，未擅自加成长。防御、韧性、抗性、时序和掉落不隐式增长。素材FPS/时长为预览数据，不冒充已实装战斗时间。','',f'本册{len(rows)}种。','','| 数字ID | 名称 | 运行标识 | 状态 |','|---|---|---|---|']
    for r in rows:
        e=r['entry'];lines.append(f'| {e["numeric_id"]} | {e["name"]} | `{e["runtime_id"]}` | '+('已注册战斗' if e['combat_ready'] else '未实装／待设定')+' |')
    lines+=['','## 区域等级与倍率（共用，可填写）','','| 字段 | 项目 | 设定值 | 说明 |','|---|---|---|---|']
    for p in snapshot['globals']:lines.append(f'| `{p["key"]}` | {p["label"]} | {display(p["value"])} | {p["note"]} |')
    for r in rows:
        e=r['entry'];lines+=['',f'## {e["numeric_id"]} {e["name"]}','',f'运行标识：`{e["runtime_id"]}`；别名：'+('、'.join(e['aliases']) or '无')+'。']
        if e.get('variant_of'):lines.append('派生自'+e['variant_of']+'；独立编号，未擅自继承数值。')
        if e.get('notes'):lines.append(e['notes'])
        for kind,names in r['placements'].items():lines.append(kind+'：'+'、'.join(sorted(names))+'。')
        if not r['placements']:lines.append('暂无地图放置记录。')
        lines+=r['notes']
        for title,parameters in r['sections'].items():
            readable=title
            for prefix in ['招式：','未实装声明招式：']:
                if title.startswith(prefix):readable=prefix+MOVE_NAMES.get(title.removeprefix(prefix),title.removeprefix(prefix))
            lines+=['','### '+readable,'','| 字段 | 项目 | 设定值 | 说明 |','|---|---|---|---|']
            for p in parameters:lines.append(f'| `{p["key"]}` | {p["label"]} | {display(p["value"])} | {p["note"]}'+('；只读' if not p['binding'] else '')+' |')
        for title,animations in [('动作素材与原生规格（只读）',r['animations']),('全部保留素材版本（只读）',r['versions'])]:
            if not animations:continue
            lines+=['','### '+title,'','| 动作 | 帧数 | fps | 单轮秒数 | 循环 | 画布 / 锚点 | 来源 |','|---|---:|---:|---:|---|---|---|']
            for a in animations:lines.append(f'| {a["name"]} | {a["frames"]} | {display(a["fps"])} | {display(round(a["seconds"],6) if a["seconds"] is not None else None)} | {display(a["loop"])} | {a["canvas"]} / {a["anchor"]} | `{a["source"]}` |')
    return '\n'.join(lines)+'\n'


def render_index(snapshot):
    lines=['# 敌怪记录总索引','','原总表已分成三份可填写记录；数字ID固定不复用。','']
    for c,name in DOCS.items():lines.append(f'- [{LABELS[c]}记录]({name})：'+str(sum(r['entry']['category']==c for r in snapshot['records']))+'种。')
    lines+=['','同步：`python tools/data/sync_enemy_registry.py`；检查：`--check`；填写后回填：`--import-docs`。新增用 `--register-new 运行标识 --category small或elite或boss --name 名称` 追加编号，禁止按排序重排已有编号。','','| 数字ID | 名称 | 运行标识 | 类别 |','|---|---|---|---|']
    for r in snapshot['records']:
        e=r['entry'];lines.append(f'| {e["numeric_id"]} | {e["name"]} | `{e["runtime_id"]}` | {LABELS[e["category"]]} |')
    lines+=['','## 区域等级倍率','','| 区域 | 等级 | 等级倍率 | 区域修正 | 最终倍率 |','|---|---:|---:|---:|---:|']
    scaling=snapshot['store'].read('data/enemy_scaling.json')
    for region in snapshot['store'].read('data/world/regions.json')['regions']:
        tier=scaling['tier_multipliers'][str(region['tier'])];factor=region['enemy_multiplier'];lines.append(f'| {region["name"]} | {region["tier"]} | {tier} | {factor} | {tier*factor} |')
    lines+=['','范围包括正式敌怪、未摆放战斗原型、美术储备及独立史莱姆分裂体；同一Boss的阶段、发光形态和素材版本不重复编号。']
    return '\n'.join(lines)+'\n'


def validate_snapshot(snapshot):
    entries=snapshot['registry']['entries'];ids=[e['numeric_id'] for e in entries];slugs=[e['runtime_id'] for e in entries];errors=[]
    if len(set(ids))!=len(ids) or any(not re.fullmatch(r'\d{4}',v) for v in ids):errors.append('IDs must be unique four-digit strings')
    if len(set(slugs))!=len(slugs):errors.append('Duplicate identities')
    alias_owner={}
    for e in entries:
        for key in [e['runtime_id'],e['numeric_id'],*e['aliases']]:
            if key in alias_owner and alias_owner[key]!=e['runtime_id']:errors.append('Ambiguous enemy alias: '+key)
            alias_owner[key]=e['runtime_id']
    if any(v=='0000' for v in ids) or int(snapshot['registry']['next_numeric_id'])<=max(map(int,ids)):errors.append('next_numeric_id must be greater than every allocated ID')
    missing=set(discover(snapshot['store']))-set(slugs)
    if missing:errors.append('Unregistered identities: '+', '.join(sorted(missing)))
    for r in snapshot['records']:
        if r['entry']['category'] not in DOCS:errors.append('Unknown category')
        keys=[p['key'] for p in r['parameters']]
        if len(keys)!=len(set(keys)):errors.append('Duplicate parameter keys: '+r['entry']['runtime_id'])
        if r['entry']['combat_ready'] and r['entry']['runtime_id']!='corrumpt':
            p={item['key']:item['value'] for item in r['parameters']}
            for key in ['base.base_hp','base.base_damage','base.defense','base.poise','base.resist.physical','base.resist.magic']:
                if type(p[key]) not in [int,float] or not math.isfinite(p[key]) or p[key]<0:errors.append('Missing/invalid live stat: '+r['entry']['runtime_id']+'/'+key)
            for name in [section.removeprefix('招式：') for section in r['sections'] if section.startswith('招式：')]:
                prefix='moves.'+name+'.'
                if not 0<=p[prefix+'attack_hit_start']<=p[prefix+'attack_hit_end']<=p[prefix+'attack_duration']:errors.append('Invalid attack window: '+r['entry']['runtime_id']+'/'+name)
    lookup={canonical(e['runtime_id']):e for e in entries}
    lookup.update({e['numeric_id']:e for e in entries})
    for relative in ['data/world/regions.json']+[p.relative_to(ROOT).as_posix() for folder in ['data/maps','test/data/forest_candidates'] for p in (ROOT/folder).glob('*.json')]:
        data=snapshot['store'].read(relative)
        rows=data.get('rooms',[data])
        for room in rows:
            for spawn in room.get('enemies',[]):
                key=canonical(spawn.get('enemy_id',spawn.get('id')))
                if key not in lookup or not lookup[key]['combat_ready']:errors.append('Unready/unregistered map enemy: '+relative+' / '+str(key))
    scaling=snapshot['store'].read('data/enemy_scaling.json')
    for region in snapshot['store'].read('data/world/regions.json')['regions']:
        value=scaling['tier_multipliers'].get(str(region['tier']))
        if type(value) not in [int,float] or value<=0:errors.append('Undefined/nonpositive region tier multiplier: '+region['id'])
    return errors


def import_documents(snapshot,directory=None):
    """先校验三份全部改动，再写内存；不覆盖源数据的新变化，不接受矛盾共享值。"""
    expected={(r['entry']['numeric_id'],p['key']):p for r in snapshot['records'] for p in r['parameters']}
    expected.update({('global',p['key']):p for p in snapshot['globals']});seen=set();proposals={};changes=[]
    directory=directory or ROOT/'docs/gameplay'
    for name in DOCS.values():
        text=(directory/name).read_text(encoding='utf8');identity='global'
        if f'<!-- enemy-source-sha256: {snapshot["fingerprint"]} -->' not in text:raise ValueError(name+': source data changed; regenerate/review first')
        for line in text.splitlines():
            match=re.match(r'## (\d{4}) ',line)
            if match:identity=match.group(1)
            if not line.startswith('| `') or identity is None:continue
            cells=[c.strip() for c in line.strip('|').split('|')];key=cells[0].strip('`');token=(identity,key)
            if token not in expected:
                if key.startswith(('scaling.','region.')):token=('global',key)
                if token not in expected:continue
            seen.add(token);p=expected[token];raw=cells[2].replace('&#124;','|')
            if raw==display(p['value']):continue
            if not p['binding']:raise ValueError(f'{identity}/{key}: read-only')
            if raw in ['待填写','待定','null','—','']:
                if p['value'] is not None:raise ValueError('Existing values cannot be erased into placeholders: '+key)
                value=None
            elif p['kind']=='text':value=raw
            else:
                try:value=json.loads(raw,parse_constant=lambda constant: (_ for _ in ()).throw(ValueError('Finite JSON values required')))
                except json.JSONDecodeError as error:raise ValueError(f'{identity}/{key}: invalid numeric/JSON value') from error
            if value is not None:
                if p['kind']=='number' and (type(value) not in [int,float] or value<0):raise ValueError('Non-negative number required: '+key)
                if p['kind']=='list' and not isinstance(value,list):raise ValueError('JSON list required: '+key)
                if p['kind']=='bool' and type(value) is not bool:raise ValueError('true/false required: '+key)
                if p['kind']=='integer' and (type(value) is not int or value<0):raise ValueError('Non-negative integer required: '+key)
                if key in ['base.resist.physical','base.resist.magic'] and value>100:raise ValueError('Resistance must be 0..100')
                if key=='base.base_hp' and value<=0:raise ValueError('Base HP must be positive')
                if key=='base.coin_drop' and (len(value)!=2 or any(type(v) not in [int,float] or v<0 for v in value) or value[0]>value[1]):raise ValueError('Coin drop requires [minimum,maximum]')
            file,path=p['binding'];binding=(file,json.dumps(path,ensure_ascii=False))
            if binding in proposals and proposals[binding]!=value:raise ValueError('Conflicting shared values: '+file)
            proposals[binding]=value;changes.append((file,path,value))
    if set(expected)-seen:raise ValueError('Parameter rows removed; fill values without removing rows')
    originals=copy.deepcopy(snapshot['store'].files);dirty=set(snapshot['store'].dirty)
    try:
        for file,path,value in changes:
            snapshot['store'].set(file,path,value)
            if file=='data/bosses/claffert.json' and path in [['unconfirmed','exp'],['unconfirmed','coin_drop']]:snapshot['store'].set(file,[path[-1]],value)
        errors=validate_snapshot(build_snapshot(snapshot['store']))
        if errors:raise ValueError('; '.join(errors))
    except Exception:
        snapshot['store'].files=originals;snapshot['store'].dirty=dirty
        raise
    return len(changes)
