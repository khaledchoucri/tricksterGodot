"""Write the Caballa Relics tier of run gear as ItemData resources (data/items/).

Each item takes its original numbers from ItemParamEx / ItemParamEx2: level (MinLevel), weight,
compound slots (CompoundSlot) and stat bonuses (APPlus, DPPlus, MaxHPPlus...). The ladder is the
original's ordinary level-50 and level-65 lines (Old / plain / Strong / Edge) and its Caballa set;
event and cash-shop items are left out. Guns have their own generator (gun_items.py).
Ours: which items make the ladder, and the weapon family that picks the combo (blades fight with
the sword combo, maces and rods with the hammer's).

usage: python -I tools/gear_items.py   (from the project root)
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLES = os.path.join(ROOT, 'original_assets', 'data', 'tables')
OUT = os.path.join(ROOT, 'data', 'items')

# Original item IDs: (id, our slot, weapon family). Slots: 0 weapon, 1 hat, 2 shield,
# 3 innerwear, 4 accessory (ItemData.Slot).
LADDER = [
    ('600025', 0, 'sword'), ('600027', 0, 'sword'),      # Sword, Edge Sword (50)
    ('600033', 0, 'sword'), ('600035', 0, 'sword'),      # Epoch Sword, Edge Epoch Sword (65)
    ('601025', 0, 'sword'), ('601035', 0, 'sword'),      # Dagger (50), Edge Dirk (65)
    ('40033', 0, 'hammer'), ('40081', 0, 'hammer'),      # Caballa Mace, Caballa Mace S (50)
    ('40155', 0, 'hammer'),                              # Caballa Club Neo (65)
    ('603025', 0, 'hammer'), ('603035', 0, 'hammer'),    # Bronze Rod (50), Sun Wood Rod (65)
    ('620017', 1, ''), ('620019', 1, ''),                # Steel Helmet, Focus Steel Helmet (50)
    ('630019', 1, ''), ('44031', 1, ''),                 # Wise Wood Gear, Caballa Crest (50)
    ('620026', 1, ''), ('630027', 1, ''), ('44108', 1, ''),  # Strong Basic Cap, Wise Leather Gear, Caballa Crest Neo (65)
    ('640017', 2, ''), ('640019', 2, ''), ('46016', 2, ''),  # Metal, Aegis Metal, Caballa Shield (50)
    ('640025', 2, ''), ('640027', 2, ''), ('46102', 2, ''),  # Thorn, Aegis Thorn, Caballa Shield Neo (65)
    ('5028', 3, ''),                                     # Golden Mole Vest (60; the client has no icons for
                                                         # the level-60/70 Marin Belt and Poppuri Hunting Vest)
    ('7016', 4, ''), ('7019', 4, ''), ('7028', 4, ''),   # Might Ring, Precision Necklace, Wise Ring (50)
    ('7041', 4, ''), ('7044', 4, ''), ('7047', 4, ''),   # Vitality Ring, Guard-well Necklace, Dodge-all Necklace (50)
]
# The original's ordinary lines above level 65 (ItemParamEx2, one every 15 levels), each as its plain
# make and its two-slot make: Katana, Dao, Sabre, Shotel; Flat Sword, Kaldo, Kukri, Main-Gauche; Stone
# Rod, Rune Staff, Battle Rod, Silver Rod; Iron, Brim and Buckler Cap, Nasal Helm; Felt Hood, Beret,
# Hunting Cap, Turban; Square, Guardian, Knight and Crest Shield. They fill the gear bands Heat raises
# (the Caballa Relics' own drop tables list the level-95 to 125 lines). Ours: the levels and makes kept.
HIGH_LEVELS = (80, 95, 110, 125)
# Item id // 1000 -> (our slot, weapon family).
HIGH_LINES = {600: (0, 'sword'), 601: (0, 'sword'), 603: (0, 'hammer'), 620: (1, ''), 630: (1, ''), 640: (2, '')}
# Variant makes outside the ordinary four (Old, plain, Strong/Sharp/Moon, Edge/Sun/Focus/Wise/Aegis).
VARIANTS = ('Requiem', 'Powerful', 'Gloom', 'Shadow', 'Chaos', 'Morph', 'Art ', 'Ult.')


def high_ladder(rows):
    """(id, slot, family) for each ordinary line's plain and two-slot makes at HIGH_LEVELS."""
    out = []
    for fam, (slot, family) in HIGH_LINES.items():
        for lv in HIGH_LEVELS:
            line = sorted((int(i), r) for i, r in rows.items() if int(i) // 1000 == fam and r.get('MinLevel') == lv
                          and not any(v in r['Name'] for v in VARIANTS))
            assert len(line) >= 4, (fam, lv, [r['Name'] for _, r in line])
            out += [(str(line[1][0]), slot, family), (str(line[3][0]), slot, family)]
    return out


# The original's columns -> our stat keys.
STATS = {'APPlus': 'AP', 'DPPlus': 'DP', 'MAPlus': 'MA', 'MDPlus': 'MD', 'ACPlus': 'AC', 'DXPlus': 'DX',
         'DAPlus': 'DA', 'LKPlus': 'LK', 'HVPlus': 'HV', 'MaxHPPlus': 'HP', 'MaxMPPlus': 'MP', 'MaxWTPlus': 'WT'}


def load(name):
    return json.load(open(os.path.join(TABLES, name + '.json'), encoding='utf-8'))


def slug(name):
    return re.sub(r'[^a-z0-9]+', '_', name.lower()).strip('_')


def refine_stat(slot, stats):
    """What refining raises: a weapon's AP (a rod's MA), a hat's or shield's DP; others don't refine."""
    if slot == 0:
        return 'AP' if 'AP' in stats else 'MA'
    return 'DP' if slot in (1, 2) and 'DP' in stats else ''


def main():
    rows = {}
    for t in ['ItemParamEx2', 'ItemParamEx', 'ItemParam2']:
        for r in load(t):
            rows.setdefault(str(r['ID']), r)
    for i, slot, family in LADDER + high_ladder(rows):
        r = rows[i]
        stats = {ours: int(r[col]) for col, ours in STATS.items() if r.get(col)}
        ident = slug(r['Name'])
        # Two original items can share a name (Steel Helmet is level 16 and level 50): never
        # overwrite another item's file; the later one takes its level in its id.
        taken = os.path.join(OUT, ident + '.tres')
        if os.path.exists(taken) and not re.search(rf'^item_id = {i}$', open(taken, encoding='utf-8').read(), re.M):
            ident = f'{ident}_{int(r.get("MinLevel") or 1)}'
        lines = '\n'.join(f'"{k}": {v},' for k, v in stats.items()).rstrip(',')
        text = f'''[gd_resource type="Resource" script_class="ItemData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/item_data.gd" id="1_s"]

[resource]
script = ExtResource("1_s")
id = &"{ident}"
display_name = "{r['Name']}"
item_id = {i}
slot = {slot}
family = "{family}"
level = {int(r.get('MinLevel') or 1)}
weight = {int(r.get('Weight') or 10)}
stats = {{
{lines}
}}
compound_slots = {min(int(r.get('CompoundSlot') or 0), 3)}
refine_stat = "{refine_stat(slot, stats)}"
'''
        path = os.path.join(OUT, ident + '.tres')
        old = open(path, encoding='utf-8').read() if os.path.exists(path) else None
        uid = re.search(r'uid="[^"]+"', old) if old else None
        if uid:
            text = text.replace('format=3]', f'format=3 {uid.group(0)}]', 1)
        open(path, 'w', encoding='utf-8', newline='\n').write(text)
        print(f'{ident}: Lv {r.get("MinLevel")}, slot {slot}, {stats}')


if __name__ == '__main__':
    main()
