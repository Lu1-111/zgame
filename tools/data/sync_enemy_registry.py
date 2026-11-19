"""同步三份敌怪记录；--import-docs将填写值校验回填，--check检查漏同步。"""
from pathlib import Path
import argparse
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
from enemy_registry_model import ROOT,DOCS,Store,seed_moves,build_snapshot,render_document,render_index,validate_snapshot,import_documents,register_new
OUTPUT=ROOT/'docs/gameplay/怪物数值记录表.md'

def build_registry():
    return render_index(build_snapshot())

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    parser.add_argument('--import-docs',action='store_true')
    parser.add_argument('--register-new',metavar='RUNTIME_ID')
    parser.add_argument('--category',choices=DOCS)
    parser.add_argument('--name')
    args=parser.parse_args();store=Store()
    if sum([args.check,args.import_docs,bool(args.register_new)])>1:parser.error('Choose one operation')
    if args.register_new:
        if not args.category:parser.error('--register-new requires --category')
        row=register_new(store,args.register_new,args.category,args.name)
        print('ALLOCATED: '+row['numeric_id']+' / '+row['runtime_id'])
    if not args.check and not args.import_docs:seed_moves(store)
    snapshot=build_snapshot(store);errors=validate_snapshot(snapshot)
    if errors:raise ValueError('; '.join(errors))
    if args.import_docs:
        count=import_documents(snapshot);store.write();snapshot=build_snapshot()
        print(f'ENEMY DOCUMENT IMPORT: {count} edited rows')
    elif not args.check:store.write()
    outputs={OUTPUT:render_index(snapshot)}
    outputs.update({ROOT/'docs/gameplay'/name:render_document(snapshot,category) for category,name in DOCS.items()})
    if args.check:
        stale=[p.name for p,t in outputs.items() if not p.exists() or p.read_text(encoding='utf8')!=t]
        print('ENEMY REGISTRY: '+('SYNCED' if not stale else 'OUT OF DATE: '+', '.join(stale)))
        return int(bool(stale))
    for p,t in outputs.items():p.write_text(t,encoding='utf8')
    print(f'ENEMY REGISTRY: {len(snapshot["records"])} identities / 3 documents / {sum(len(r["parameters"]) for r in snapshot["records"])} parameter rows')
    return 0

if __name__=='__main__':raise SystemExit(main())
