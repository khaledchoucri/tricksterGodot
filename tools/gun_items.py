"""Write the guns the runs can find as ItemData resources (data/items/).

Each gun takes its original numbers: Gun AP (ItemParam's AP column, raised by
refining), weight and level from the item tables, and its cycle from
Item_GunParam2 (GaugeSpeed, PowRange, PowStartPoint, MaxAttackRange). The
ladder follows the original's ordinary guns across the levels a run reaches;
event and cash-shop guns are left out.

usage: python -I tools/gun_items.py   (from the project root)
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLES = os.path.join(ROOT, 'original_assets', 'data', 'tables')
OUT = os.path.join(ROOT, 'data', 'items')

# Original item IDs, by level. Old Ebony Gun is Lion's starting gun.
LADDER = [
    '610000', '610001', '610002', '610003',  # Ebony (5)
    '610104',                                # Sleek Gun (10)
    '3500', '17400',                         # Gun Type 1, Chrome Silver Gun (15)
    '610009', '610010',                      # Wood Gun, Strong Wood Gun (20)
    '3501',                                  # Gun Type 2 (25)
    '3507', '42001',                         # Water Gun, Indiana Rifle (30)
    '610017', '610018', '3502',              # Classic, Strong Classic, Gun Type 3 (35)
    '3511',                                  # Rose Gun (40)
    '610025', '610026', '3503', '3504',      # Antique, Strong Antique, Gun Type 4, Drill Gun (50)
    '610033', '610034', '610035',            # Metal, Strong Metal, Precise Metal Gun (65): the Caballa Relics
    # Strong and Precise makes of the higher lines, for the gear bands Heat raises:
    '610042', '610043',                      # Sten Gun (80)
    '610050', '610051',                      # Titan Gun (95)
    '610058', '610059',                      # Milli-Gun (110)
    '610066', '610067',                      # Blue Seal Gun (125)
]
# Compound slots: one, two on the better make of a line.
TWO_SLOTS = ('Strong ', 'Precise ', 'Drill ', 'Rose ', 'Chrome ')


def load(name):
    return json.load(open(os.path.join(TABLES, name + '.json'), encoding='utf-8'))


def slug(name):
    return re.sub(r'[^a-z0-9]+', '_', name.lower()).strip('_')


def main():
    rows = {}
    for t in ['ItemParam2', 'ItemParamEx', 'ItemParamEx2', 'ItemParamCM2']:
        if os.path.exists(os.path.join(TABLES, t + '.json')):
            for r in load(t):
                rows.setdefault(str(r['ID']), r)
    cycle = {str(r['ID']): r for r in load('Item_GunParam2')}
    for i in LADDER:
        r, g = rows[i], cycle[i]
        name = r['Name'].replace('type', 'Type').replace('Type3', 'Type 3').replace('Type4', 'Type 4')
        name = name.replace('Rose gun', 'Rose Gun')
        ident = slug(name)
        slots = 0 if i == '610000' else 2 if name.startswith(TWO_SLOTS) else 1
        text = f'''[gd_resource type="Resource" script_class="ItemData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/item_data.gd" id="1_s"]

[resource]
script = ExtResource("1_s")
id = &"{ident}"
display_name = "{name}"
item_id = {i}
slot = 0
family = "gun"
level = {int(r.get('MinLevel') or 1)}
weight = {int(r.get('Weight') or 10)}
stats = {{
"AP": {int(r.get('AP') or 0)}
}}
compound_slots = {slots}
refine_stat = "AP"
gun = {{
"speed": {g['GaugeSpeed']},
"power": {g['PowRange']},
"zone": {g['PowStartPoint']},
"range": {g['MaxAttackRange']}
}}
'''
        path = os.path.join(OUT, ident + '.tres')
        old = open(path, encoding='utf-8').read() if os.path.exists(path) else None
        uid = re.search(r'uid="[^"]+"', old) if old else None
        if uid:
            text = text.replace('format=3]', f'format=3 {uid.group(0)}]', 1)
        open(path, 'w', encoding='utf-8', newline='\n').write(text)
        print(f'{ident}: Lv {r.get("MinLevel")}, Gun AP {r.get("AP")}, speed {g["GaugeSpeed"]}, range {g["MaxAttackRange"]}')


if __name__ == '__main__':
    main()
