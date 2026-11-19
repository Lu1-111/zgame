"""敌怪文档回填安全测试；所有改动仅在内存及临时目录，不改工程数值。"""
from pathlib import Path
import copy
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'tools/data'))
import enemy_registry_model as model


class EnemyRegistryTest(unittest.TestCase):
    def setUp(self):
        self.snapshot=model.build_snapshot()
        self.temp=tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory=Path(self.temp.name)
        for category,name in model.DOCS.items():
            (self.directory/name).write_text(model.render_document(self.snapshot,category),encoding='utf8')

    def edit(self,name,key,value,identity=None):
        path=self.directory/model.DOCS[name];lines=path.read_text(encoding='utf8').splitlines();current=None;done=False
        for i,line in enumerate(lines):
            if line.startswith('## ') and line[3:7].isdigit():current=line[3:7]
            if line.startswith('| `'+key+'` |') and (identity is None or current==identity):
                cells=line.split('|');cells[3]=' '+value+' ';lines[i]='|'.join(cells);done=True;break
        self.assertTrue(done,key);path.write_text('\n'.join(lines)+'\n',encoding='utf8')

    def test_identity_coverage_and_aliases(self):
        self.assertEqual(model.validate_snapshot(self.snapshot),[])
        entries=self.snapshot['registry']['entries']
        self.assertGreaterEqual(len(entries),24)
        self.assertEqual(next(e for e in entries if e['runtime_id']=='cavern_hunter')['category'],'elite')
        self.assertEqual(len(set(e['numeric_id'] for e in entries)),len(entries))
        self.assertEqual(model.import_documents(self.snapshot,self.directory),0)

    def test_fill_draft_and_live_override(self):
        self.edit('small','base.base_hp','82','0021')
        self.edit('small','moves.attack.damage_multiplier','1.25','0001')
        self.assertEqual(model.import_documents(self.snapshot,self.directory),2)
        store=self.snapshot['store']
        self.assertEqual(store.at('data/enemy_combat_b04.json',['per_enemy','moss_beetle','damage_multiplier']),1.25)
        cave=store.read('data/enemy_designs/cave_v001.json')['enemies']
        self.assertEqual(next(e for e in cave if e['id']=='cave_spider')['base_hp'],82)
        self.assertEqual(store.read('data/enemy_combat_b04.json')['damage_multiplier'],1.0)

    def test_shared_global_edited_in_one_document(self):
        self.edit('elite','scaling.tier.2','1.5')
        self.assertEqual(model.import_documents(self.snapshot,self.directory),1)
        self.assertEqual(self.snapshot['store'].at('data/enemy_scaling.json',['tier_multipliers','2']),1.5)

    def test_confirmed_boss_reward_reaches_runtime(self):
        self.edit('boss','base.exp','120','0013')
        self.edit('boss','base.coin_drop','[30,40]','0013')
        self.assertEqual(model.import_documents(self.snapshot,self.directory),2)
        boss=self.snapshot['store'].read('data/bosses/claffert.json')
        self.assertEqual(boss['exp'],120)
        self.assertEqual(boss['coin_drop'],[30,40])
        self.assertEqual(boss['unconfirmed']['exp'],120)

    def test_conflict_rejects_all_edits(self):
        self.edit('small','base.base_hp','82','0021')
        self.edit('small','scaling.tier.2','1.5')
        self.edit('elite','scaling.tier.2','1.6')
        before=copy.deepcopy(self.snapshot['store'].files)
        with self.assertRaisesRegex(ValueError,'Conflicting'):model.import_documents(self.snapshot,self.directory)
        self.assertEqual(self.snapshot['store'].files,before)

    def test_invalid_attack_window_rolls_back(self):
        self.edit('small','moves.attack.attack_hit_end','99','0001')
        before=copy.deepcopy(self.snapshot['store'].files)
        with self.assertRaisesRegex(ValueError,'attack window'):model.import_documents(self.snapshot,self.directory)
        self.assertEqual(self.snapshot['store'].files,before)
        self.assertEqual(self.snapshot['store'].dirty,set())

    def test_readonly_and_stale_sources_rejected(self):
        self.edit('small','moves.attack.cycle_seconds','4','0001')
        with self.assertRaisesRegex(ValueError,'read-only'):model.import_documents(self.snapshot,self.directory)
        path=self.directory/model.DOCS['small']
        path.write_text(path.read_text(encoding='utf8').replace(self.snapshot['fingerprint'],'old'),encoding='utf8')
        with self.assertRaisesRegex(ValueError,'source data changed'):model.import_documents(self.snapshot,self.directory)

    def test_undefined_region_tier_rejected(self):
        self.edit('small','region.cave.tier','3')
        with self.assertRaisesRegex(ValueError,'tier multiplier'):model.import_documents(self.snapshot,self.directory)

    def test_invalid_resistance_and_missing_stat_rejected(self):
        self.edit('small','base.resist.physical','101','0001')
        with self.assertRaisesRegex(ValueError,'Resistance'):model.import_documents(self.snapshot,self.directory)
        self.edit('small','base.resist.physical','0','0001')
        self.edit('small','base.base_hp','待填写','0001')
        with self.assertRaisesRegex(ValueError,'cannot be erased'):model.import_documents(self.snapshot,self.directory)

    def test_append_id_and_duplicate_refused(self):
        store=self.snapshot['store'];old=[(e['numeric_id'],e['runtime_id']) for e in store.read(model.REGISTRY)['entries']]
        next_id=store.read(model.REGISTRY)['next_numeric_id']
        row=model.register_new(store,'test_registry_draft','elite','编号测试占位')
        self.assertEqual(row['numeric_id'],next_id)
        self.assertIsNone(row['draft']['base_hp'])
        self.assertFalse(row['combat_ready'])
        self.assertEqual([(e['numeric_id'],e['runtime_id']) for e in store.read(model.REGISTRY)['entries'][:-1]],old)
        with self.assertRaisesRegex(ValueError,'already'):model.register_new(store,'test_registry_draft','small')


if __name__=='__main__':unittest.main()
