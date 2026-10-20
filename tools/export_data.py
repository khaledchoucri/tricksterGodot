"""Export Trickster client data tables (libconfig_*.xml) to JSON.

Writes one JSON file per table plus `_schema.json`, and a compact
`monsters.json` for the monsters the prototype uses.

usage:
  python -I export_data.py <libconfig_eng.xml> <out_dir> [--monsters 2183,2185,...]

The output belongs in the git-ignored `original_assets/` folder.
"""
import argparse
import json
import os
import re

TABLE_RE = re.compile(r"<TABLE name='([^']+)'[^>]*>(.*?)</TABLE>", re.S)
FIELD_RE = re.compile(r"<FIELDINFO Name='([^']+)'[^>]*DataType='([^']+)'")
ROW_RE = re.compile(r"<ROW>(.*?)</ROW>", re.S)
CELL_RE = re.compile(r"<([A-Za-z0-9_]+)>(.*?)</\1>", re.S)
CDATA_RE = re.compile(r"<!\[CDATA\[(.*?)\]\]>", re.S)


def clean(v):
    m = CDATA_RE.fullmatch(v.strip())
    return (m.group(1) if m else v).strip()


def typed(v, t):
    if t == 'INT':
        try:
            return int(v)
        except ValueError:
            return v
    if t == 'float':
        try:
            return float(v)
        except ValueError:
            return v
    return v


def load_tables(path):
    text = open(path, 'rb').read().replace(b'\x00', b'').decode('utf-8', 'replace')
    tables = {}
    for m in TABLE_RE.finditer(text):
        name, body = m.group(1), m.group(2)
        types = dict(FIELD_RE.findall(body))
        rows = []
        for r in ROW_RE.findall(body):
            rows.append({k: typed(clean(v), types.get(k, '')) for k, v in CELL_RE.findall(r)})
        tables[name] = {'types': types, 'rows': rows}
    return tables


def monster_summary(tables, ids):
    by_id = lambda t, key='ID': {str(r.get(key)): r for r in tables[t]['rows']}
    params = by_id('MonsterParamEx2')
    chars = by_id('CharacterInfo')
    speech_tables = {k: v['rows'] for k, v in tables.items() if k.startswith('MonSpeech_')}
    out = {}
    for mid in ids:
        p, c = params[mid], chars.get(mid, {})
        speech = [r.get('String') or r.get('Speech') or '' for r in speech_tables.get(p.get('Speech', ''), [])]
        out[mid] = {
            'name': p['Name'],
            'sprite': c.get('FileName', ''),
            'level': p['Level'],
            'stats': {k[:-2].upper(): p[k] for k in p if k.endswith('Lv') and k != 'Level'},
            'exp': p['EXP'], 'tm': p['TM'],
            'galder': [p.get('GMin', 0), p.get('GMax', 0)], 'galder_rate': p.get('GelderRate', 0),
            'walk_speed': p['WalkSpeed'], 'run_speed': p['RunSpeed'],
            'idle_stay': [p['MinStay'], p['MaxStay']], 'chase_time': p['ChaseTime'],
            'view_range': p['aiViewRange'], 'aggressive': p.get('aiAttackDispos', 0) == 1,
            'retreat_hp': p.get('aiRetreatHp', 0), 'retreat_area': p.get('aiRetreatArea', 0),
            'attack_range': [c.get('MinAtkRange', 0), c.get('MaxAtkRange', 0)],
            # PhysicalR is the server's attribute 0x14, taken off every physical hit (0x59c4a0).
            'elements': {k[:-1]: p[k] for k in ('FireR', 'WaterR', 'WindR', 'EarthR', 'ElecR', 'LightR', 'DarkR', 'PhysicalR')},
            'tactics': p.get('TacticsTable', ''),
            'boss': p.get('IsBoss', 0),
            'speech': [s for s in speech if s.strip()],
        }
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('xml')
    ap.add_argument('out_dir')
    ap.add_argument('--monsters', default='')
    args = ap.parse_args()
    tables = load_tables(args.xml)
    tdir = os.path.join(args.out_dir, 'tables')
    os.makedirs(tdir, exist_ok=True)
    schema = {}
    for name, t in tables.items():
        schema[name] = {'rows': len(t['rows']), 'fields': t['types']}
        safe = re.sub(r'[^A-Za-z0-9_.-]', '_', name)
        with open(os.path.join(tdir, safe + '.json'), 'w', encoding='utf-8') as f:
            json.dump(t['rows'], f, ensure_ascii=False, indent=1)
    with open(os.path.join(tdir, '_schema.json'), 'w', encoding='utf-8') as f:
        json.dump(schema, f, ensure_ascii=False, indent=1)
    if args.monsters:
        ids = [s.strip() for s in args.monsters.split(',')]
        with open(os.path.join(args.out_dir, 'monsters.json'), 'w', encoding='utf-8') as f:
            json.dump(monster_summary(tables, ids), f, ensure_ascii=False, indent=1)
    print(f'{len(tables)} tables exported')


if __name__ == '__main__':
    main()
