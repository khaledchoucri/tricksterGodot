"""Generate the Power line's skill cards (Buffalo and Bunny) from the
original skill tables.

usage: python -I tools/power_skills.py   (from the project root)

Sources, all in original_assets/data/tables:
- Item_SkillCardParam: which jobs learn each skill, and its prerequisites
  (PreSkill_n at PreSkillLv_n).
- SkillParam2: the skill's kind (Type 1 passive, 2 attack, 3 timed buff or
  debuff), its level cap (MaxSKLV) and its description.
- ESAII_<x> and ESAction_<x> (SkillParam2.ESAIITable / ESATable): its
  numbers per level (MpCon, CoolTime, Range, Ratio, Seconds, Comment...).

Writes data/skills/power/<card>.tres and fills the card lists of the jobs in
data/jobs. How the original maps onto this game:
- Levels: a card's levels 1-8 (5 in a run, 3 more from mastery) are the
  original's levels 1, 2, 4, 5, 7, 8, 10 and 11.
- Damage: the attack % the original tooltip shows (Comment) of a normal
  hit, NORMAL_HIT.
- MP: the original cost, compressed (MP pools here are about 100, not
  thousands): 20 * (MpCon / 32) ** 0.4, so Shockwave's 32 stays 20.
- Cooldowns, durations, chances, target counts and blocks: as the original.
- Prerequisite levels (out of 11) map to 1 (levels 1-6), 2 (7-9) and 3
  (10-11) here.
- Timed buffs and debuffs (Type 3) become talents with the original effect:
  a buff is always on (all but Berserker last far longer than their
  cooldown; Berserker's is averaged over its cooldown), and a debuff is
  applied by your hits for its original duration.
- Advanced forms ("an advanced form of X" in the description) upgrade X:
  they're offered only while X is known, and replace it.
"""
import json
import math
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLES = os.path.join(ROOT, 'original_assets', 'data', 'tables')
OUT = os.path.join(ROOT, 'data', 'skills', 'power')
LEVELS = [1, 2, 4, 5, 7, 8, 10, 11]
NORMAL_HIT = 29.0

# Jobs and the original tree that fills them (skill id prefix).
JOBS = {
    'fighter': ['10'], 'schoolgirl': ['10'],
    'boxer': ['11'], 'knight': ['12'],
    'champion': ['13'], 'gladiator': ['15'],
    # The hybrids learn the other 2nd job's skills instead of new ones.
    'duelist': ['12'], 'mercenary': ['11'],
}

# Master Louis's material for each card (the original's are monster drops
# from SkillMasterInfo, most of which aren't in the game yet).
MATERIALS = ['sharp_leg', 'baby_carrot', 'hard_scales', 'scorpion_sting', 'cooling_fan', 'acorn_nut',
             'cool_ice', 'cool_spring_water', 'duck_mole_paws', 'mole_feather', 'nemeth_towel', 'pine_resin',
             'pineapple_mask', 'sand_glass', 'slime_husk', 'turban_shell', 'twinkle_star', 'ugly_pearl']


def pct_hit(r):
    return r['Comment'] / 100.0 * NORMAL_HIT


# id -> card spec. kind: 'skill' or 'talent'. value: the main number from a
# level row. rows: extra numbers by level. text: "{v}" and "{row}" fill in.
SPEC = {
    # ---- 1st job: Fighter and Schoolgirl
    '1001': dict(card='shockwave', kind='skill', behavior='shockwave', value=pct_hit,
                 text='Gather all your strength into one blow that knocks enemies around you down for {v} damage.'),
    '1002': dict(card='pumping_heart', value=lambda r: r['Comment'], text='+{v}% AP.'),
    '1003': dict(card='bulls_eye', value=lambda r: r['Comment'], text='+{v}% Accuracy (AC): fewer grazes on evasive foes.'),
    '1004': dict(card='burning_rave', kind='skill', behavior='burning_rave', value=pct_hit,
                 text='Two blows fused into one: a heavy strike for {v} damage.'),
    '1005': dict(card='armor_breaker', value=lambda r: r['Comment'], rows={'seconds': 'Seconds'},
                 text='Your hits lower an enemy\'s DP by {v}% for {seconds} s.'),
    '1006': dict(card='shockvibe', value=lambda r: r['Comment'], rows={'seconds': 'Seconds'},
                 text='Your hits daze an enemy: its accuracy drops {v}% for {seconds} s, so you evade it more.'),
    '1007': dict(card='sense_breaker', value=lambda r: r['Comment'], rows={'seconds': 'Seconds'},
                 text='Your hits dull an enemy\'s perception by {v}% for {seconds} s: it is slower to see its attacks through.'),
    '1008': dict(card='upper_smash', kind='skill', behavior='upper_smash', value=lambda r: pct_hit(r) / 2,
                 text='Knock an enemy into the air, then smash it as it falls: two hits of {v} damage.'),
    '1009': dict(card='hyper_beat', value=lambda r: -r['DX'] * 8, text='Agility (DX) up: attack {v}% faster.'),
    '1010': dict(card='luck_breaker', value=lambda r: r['Comment'], rows={'seconds': 'Seconds'},
                 text='Your hits curse an enemy\'s luck by {v}% for {seconds} s: your critical hits land on it that much more often.'),
    '1011': dict(card='tornado_bomb', kind='skill', behavior='tornado_bomb', value=lambda r: r['Comment'] / 100.0 * NORMAL_HIT / 8,
                 text='A spinning fist sends out a tornado that cuts enemies for {v} damage several times a second.'),
    # ---- Boxer
    '1101': dict(card='guard_break', value=lambda r: r['ApplyRatio'] * 100, rows={'seconds': 'Seconds'},
                 text='Shockwave has a {v}% chance to break an enemy\'s guard for {seconds} s: it can\'t evade and has no DP.'),
    '1102': dict(card='boxer_dash', kind='skill', behavior='boxer_dash', value=lambda r: NORMAL_HIT, rows={'range': 'Range'},
                 text='Step in front of the enemy you aim at (up to {range} away) before it can react, striking for {v} damage.'),
    '1103': dict(card='uppercut', kind='skill', behavior='uppercut', value=pct_hit,
                 text='Uppercut an enemy into the air for {v} damage.'),
    '1104': dict(card='quad_punch', kind='skill', behavior='quad_punch', value=lambda r: pct_hit(r) / 4,
                 text='Four blazing blows in a row, {v} damage each.'),
    '1105': dict(card='eagle_eye', value=lambda r: r['Comment'], text='+{v}% Accuracy (AC).'),
    '1106': dict(card='counter_punch', value=pct_hit, rows={'chance': lambda r: 50},
                 text='While you Uppercut, a {chance}% chance of a counter blow for {v} more damage.'),
    '1107': dict(card='guard', value=lambda r: r['Count'], rows={'cooldown': 'CoolTime'},
                 text='Block up to {v} physical hits completely (not magic). A spent block returns after {cooldown} s.'),
    '1108': dict(card='tetra_punch', kind='skill', behavior='quad_punch', upgrades='1104', value=lambda r: pct_hit(r),
                 text='Four blows at vital points, {v} damage and stronger with every one that lands.'),
    '1109': dict(card='desperate_rally', value=lambda r: r['Comment'], rows={'hp': 'HPPercent'},
                 text='Below {hp}% HP, +{v}% AP, rising the lower your HP gets.'),
    '1110': dict(card='clinch_release', kind='skill', behavior='clinch_release', value=lambda r: 0,
                 text='Usable while staggered: shake off the hit, its knockback and anything holding you.'),
    # ---- Knight
    '1201': dict(card='faint', value=lambda r: r['ApplyRatio'] * 100, rows={'seconds': 'Seconds'},
                 text='Shockwave has a {v}% chance to make an enemy faint for {seconds} s.'),
    '1202': dict(card='lacerator', kind='skill', behavior='lacerator', value=pct_hit,
                 text='A blade aura cuts in front of and behind you for {v} damage.'),
    '1203': dict(card='berserker', value=lambda r: (r['ApRatio'] - 1.0) * 100 * min(1.0, r['Seconds'] / r['CoolTime']),
                 text='Rage: +{v}% AP, but you keep losing HP and MP while enemies are near.'),
    '1204': dict(card='piercing_wave', kind='skill', behavior='piercing_wave', value=pct_hit,
                 text='Shoot a wave of energy that pierces every enemy in a line for {v} damage.'),
    '1205': dict(card='blazing_strike', kind='skill', behavior='blazing_strike', value=pct_hit, rows={'targets': 'KillNum', 'range': 'Range'},
                 text='Blazing-fast strikes on the nearest enemies (up to {targets}) for {v} damage each; more hits with more DX.'),
    '1206': dict(card='aura_of_haste', value=lambda r: -r['DX'] * 8, text='Agility (DX) up: attack {v}% faster.'),
    '1207': dict(card='tidal_slash', kind='skill', behavior='tidal_slash', value=pct_hit, element='water', upgrades='1202',
                 rows={'range': 'Range', 'targets': 'MonNum'},
                 text='A wide Lacerator that slices the enemies in front and behind (up to {targets}) for {v} water damage.'),
    '1208': dict(card='inferno_blade', kind='skill', behavior='inferno_blade', value=pct_hit, element='fire', rows={'radius': 'Radius'},
                 text='Throw your sword: it spins out and back like a ball of fire, cutting for {v} damage.'),
    '1209': dict(card='tempest_strike', kind='skill', behavior='wind_blades', value=pct_hit, element='wind', upgrades='1202',
                 rows={'radius': 'Radius', 'targets': 'KillNum'},
                 text='Circular blades of wind slash the enemies around you (up to {targets}) for {v} wind damage.'),
    '1210': dict(card='earthquake_blade', kind='skill', behavior='earthquake_blade', value=pct_hit, element='earth', upgrades='1204',
                 rows={'range': 'Range', 'radius': 'Radius', 'targets': 'KillNum'},
                 text='Drive a sword into the ground ahead: its shockwave hits the enemies there (up to {targets}) for {v} earth damage.'),
    '1211': dict(card='lightning_strike', kind='skill', behavior='lightning_strike', value=pct_hit, element='lightning',
                 rows={'targets': 'KillNum', 'stun': 'StunTime', 'chance': lambda r: r['StunRatio'] * 100},
                 text='Lightning strikes the nearest enemies (up to {targets}) for {v} damage, with a {chance}% chance to stun for {stun} s.'),
    # ---- Champion
    '1301': dict(card='adrenaline', value=lambda r: r['Comment'], text='+{v}% AP.'),
    '1302': dict(card='flash_cut', kind='skill', behavior='flash_cut', value=pct_hit, rows={'range': 'Range'},
                 text='Close {range} in a flash and strike for {v} damage.'),
    '1303': dict(card='flaming_fist', kind='skill', behavior='flaming_fist', value=pct_hit, element='fire',
                 text='Fists burning with fighting spirit strike for {v} fire damage.'),
    '1304': dict(card='mega_flash_cut', kind='skill', behavior='flash_cut', value=pct_hit, upgrades='1302', rows={'range': 'Range'},
                 text='A faster Flash Cut over {range}: {v} damage, and the enemy is thrown into the air.'),
    '1305': dict(card='chi_release', kind='skill', behavior='chi_release', value=pct_hit, rows={'radius': 'Radius', 'targets': 'KillNum'},
                 text='Release your chi in one explosion: the enemies around you (up to {targets}) take {v} damage.'),
    # ---- Gladiator
    '1501': dict(card='shadow', kind='skill', behavior='shadow', value=pct_hit, rows={'count': 'Count'},
                 text='Shadows of you ({count}) strike the enemy you aim at from every side, {v} damage each.'),
    '1502': dict(card='sonic_slash', kind='skill', behavior='sonic_slash', value=pct_hit, element='water',
                 rows={'range': 'Range', 'targets': 'MonNum'},
                 text='Rush {range} forward, cutting the enemies on the way (up to {targets}) for {v} water damage.'),
    '1503': dict(card='suffocate', value=lambda r: r['Second'],
                 text='Your hits pin an enemy down: for {v} s it can\'t hide (burrow or vanish).'),
    '1504': dict(card='gale_strike', kind='skill', behavior='wind_blades', value=pct_hit, element='wind', upgrades='1209',
                 rows={'radius': 'Radius', 'targets': 'KillNum'},
                 text='A gale of wind blades shreds the enemies around you (up to {targets}) for {v} wind damage.'),
    '1505': dict(card='chi_sword', value=lambda r: r['Comment'], rows={'reach': lambda r: (r['Range'] / 80.0 - 1.0) * 100},
                 text='Your blade swells with chi: basic attacks reach {reach}% further and deal {v}% more damage.'),
    '1506': dict(card='chakra_balance', kind='skill', behavior='chakra_balance', value=lambda r: r['Heal'] / 100.0,
                 rows={'seconds': 'Time', 'interval': 'Interval'},
                 text='Recover {v}% of your HP every {interval} s for {seconds} s, until you take a hit.'),
}


def load(name):
    with open(os.path.join(TABLES, name + '.json'), encoding='utf-8') as f:
        return json.load(f)


def by_level(table):
    if not table or not os.path.exists(os.path.join(TABLES, table + '.json')):
        return {}
    return {r['Level']: r for r in load(table)}


def need(level):
    return 3 if level >= 10 else 2 if level >= 7 else 1


def tidy(v):
    """Numbers as a card shows them: whole above 10, else one decimal."""
    v = float(v)
    return float(round(v)) if abs(v) >= 10 else round(v, 1)


def fmt(v):
    v = round(float(v), 2)
    return str(int(v)) + '.0' if v == int(v) else str(v)


def tres_value(v):
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        return '[' + ', '.join(fmt(x) for x in v) + ']'
    return fmt(v)


def main():
    skills = {r['ID']: r for r in load('SkillParam2')}
    cards = {r['AffectionSkill']: r for r in load('Item_SkillCardParam')}
    os.makedirs(OUT, exist_ok=True)
    names = {i: s['card'] for i, s in SPEC.items()}
    written = {}
    for n, (sid, spec) in enumerate(SPEC.items()):
        sk, cp = skills[sid], cards[sid]
        rows = {**by_level(sk['ESAIITable']), }
        act = by_level(sk['ESATable'])
        merged = {lv: {**rows.get(lv, {}), **act.get(lv, {})} for lv in range(1, 12)}
        merged = {lv: r for lv, r in merged.items() if r}
        if not merged:
            merged = {1: {}}

        def row_at(i):
            return merged.get(LEVELS[i], merged[max(k for k in merged if k <= LEVELS[i])] if any(k <= LEVELS[i] for k in merged) else merged[min(merged)])

        cap = int(sk['MaxSKLV']) if int(sk['MaxSKLV']) == 1 else 0
        count = 1 if cap == 1 else len(LEVELS)
        table = {'value': [spec['value'](row_at(i)) for i in range(count)]}
        if spec.get('kind') == 'skill':
            table['mp'] = [round(20 * (max(row_at(i).get('MpCon', 32), 1) / 32.0) ** 0.4) for i in range(count)]
            table['cooldown'] = [row_at(i).get('CoolTime', 1.0) or 1.0 for i in range(count)]
        for rname, src in spec.get('rows', {}).items():
            table[rname] = [src(row_at(i)) if callable(src) else row_at(i)[src] for i in range(count)]
        requires = {}
        for k in (1, 2, 3):
            pre, lv = cp[f'PreSkill_{k}'], cp[f'PreSkillLv_{k}']
            if pre != '0' and pre in names:
                requires[names[pre]] = need(lv)
        behavior = spec.get('behavior')
        ext = [('Script', 'res://scripts/data/card_data.gd', '1_s'),
               ('Resource', f'res://data/materials/{MATERIALS[n % len(MATERIALS)]}.tres', 'm_master')]
        if behavior:
            ext.append(('Script', f'res://scripts/skills/{behavior}.gd', '2_b'))
        lines = [f'[gd_resource type="Resource" script_class="CardData" load_steps={len(ext) + 1} format=3]', '']
        for t, p, i in ext:
            lines.append(f'[ext_resource type="{t}" path="{p}" id="{i}"]')
        lines += ['', '[resource]', 'script = ExtResource("1_s")', f'id = &"{spec["card"]}"',
                  f'display_name = {json.dumps(sk["Name"] or {"1107": "Guard", "1208": "Inferno Blade"}[sid])}',
                  f'kind = {1 if spec.get("kind") == "skill" else 0}', f'skill_id = {sid}',
                  f'text = {json.dumps(spec["text"])}']
        if requires:
            lines.append('requires = {' + ', '.join(f'&"{k}": {v}' for k, v in requires.items()) + '}')
        if spec.get('upgrades'):
            lines.append(f'upgrades = &"{names[spec["upgrades"]]}"')
        if cap:
            lines.append(f'max_level = {cap}')
        table = {k: [tidy(x) for x in v] for k, v in table.items()}
        lines.append('table = {' + ', '.join(f'"{k}": {tres_value(v)}' for k, v in table.items()) + '}')
        lines.append('master_material = ExtResource("m_master")')
        if spec.get('element'):
            lines.append(f'element = "{spec["element"]}"')
        if behavior:
            lines.append('behavior = ExtResource("2_b")')
        path = os.path.join(OUT, spec['card'] + '.tres')
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(lines) + '\n')
        written[sid] = spec['card']
    # Job card lists, in the order the original unlocks them (TM level).
    for job, prefixes in JOBS.items():
        ids = sorted((i for i in SPEC if i[:2] in prefixes), key=lambda i: (cards[i]['TMLV'], i))
        path = os.path.join(ROOT, 'data', 'jobs', job + '.tres')
        with open(path, encoding='utf-8') as f:
            src = f.read()
        src = re.sub(r'\[ext_resource type="Resource" path="res://data/(coral_beach/cards|skills/power)/[a-z_]+\.tres" id="c_[a-z_]+"\]\n', '', src)
        new_ext = ''.join(f'[ext_resource type="Resource" path="res://data/skills/power/{names[i]}.tres" id="c_{names[i]}"]\n' for i in ids)
        src = src.replace('\n[resource]', new_ext + '\n[resource]', 1) if new_ext else src
        # keep exactly one blank line before [resource]
        src = re.sub(r'\n+\[resource\]', '\n\n[resource]', src, count=1)
        src = re.sub(r'(\]\n)(\[ext_resource type="Resource" path="res://data/skills)', r'\1\2', src)
        card_list = 'cards = Array[ExtResource("2_c")]([' + ', '.join(f'ExtResource("c_{names[i]}")' for i in ids) + '])'
        src = re.sub(r'^cards = .*$', card_list, src, flags=re.M)
        if job in ('fighter', 'schoolgirl'):
            src = re.sub(r'^starter = .*$', 'starter = ExtResource("c_shockwave")', src, flags=re.M)
        n_ext = len(re.findall(r'^\[ext_resource', src, flags=re.M))
        src = re.sub(r'load_steps=\d+', f'load_steps={n_ext + 1}', src, count=1)
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            f.write(src)
        print(f'{job}: {len(ids)} cards')
    print(f'{len(written)} Power cards written to {OUT}')


if __name__ == '__main__':
    main()
