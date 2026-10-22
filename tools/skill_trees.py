"""Shared engine for generating skill cards from the original skill tables.
Each class line has its own spec file (power_skills.py, magic_skills.py)
that lists its skills and calls build().

Sources, all in original_assets/data/tables:
- Item_SkillCardParam: which jobs learn each skill (Job), and its
  prerequisites (PreSkill_n at PreSkillLv_n).
- SkillParam2: the skill's kind (Type 1 passive, 2 attack, 3 timed effect),
  targeting (SkillOption), whether it is a spell (SpellType), its element,
  its level cap (MaxSKLV) and its description.
- ESAII_<x> and ESAction_<x> (SkillParam2.ESAIITable / ESATable): its
  numbers per level (MpCon, CoolTime, Delay, Range, Comment...).
- SkillSound: sounds by the skill's internal action name.

How the original maps onto this game:
- Levels: a card's levels 1-8 (5 in a run, 3 more from mastery) are the
  original's levels 1, 2, 4, 5, 7, 8, 10 and 11.
- Damage: the attack % the original tooltip shows (Comment) of a normal
  hit, NORMAL_HIT; spells scale it with MA.
- MP: the original cost, compressed (MP pools here are about 100, not
  thousands): 20 * (MpCon / 32) ** 0.4, so Shockwave's 32 stays 20.
- Cast time: for casting lines (Magic), spells (SpellType 1) wait half the
  original Delay before their effect. The Power line acts at once, even its
  few SpellType 1 skills (Earthquake Blade, Dash).
- Cooldowns, durations, chances, target counts and blocks: as the original.
- Prerequisite levels (out of 11) map to 1 (levels 0-6), 2 (7-9) and 3
  (10-11) here. A level-0 prerequisite (a Seal or Pact) just has to be known.
- Kind: Type 2 is an active skill. Type 3 is active when it targets an area
  (SkillOption 4 without 32), otherwise a talent with the original effect
  always on (a debuff rides on your hits). Type 1 is a passive talent.
- Jobs: the Job field lists who may learn a skill. Skills of a 1st job are
  open to every later job; others only to the jobs listed (a Priest can't
  learn dark magic).
- Advanced forms ("an advanced form of X") upgrade X: they're offered only
  while X is known, and replace it.
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TABLES = os.path.join(ROOT, 'original_assets', 'data', 'tables')
# Card levels 1-5 (a run's) are the original's 1, 3, 6, 8 and 11, so a
# skill maxed in a run is the original's mastered skill. Mastery levels 6-8
# go past the source: each adds 10% of the level-5 value (MASTERY_STEP).
LEVELS = [1, 3, 6, 8, 11, 11, 11, 11]
RUN_LEVELS = 5
MASTERY_STEP = 0.1
NORMAL_HIT = 29.0

# SkillParam2.Element -> the game's element names (the monster tables').
ELEMENTS = {'2': 'Elec', '3': 'Fire', '4': 'Earth', '5': 'Wind', '6': 'Water', '7': 'Light', '8': 'Dark'}
# Lower-case names some specs use.
ELEMENT_NAMES = {'fire': 'Fire', 'water': 'Water', 'wind': 'Wind', 'earth': 'Earth', 'lightning': 'Elec',
                 'elec': 'Elec', 'light': 'Light', 'dark': 'Dark'}

# Job names as Item_SkillCardParam writes them -> job ids.
JOB_IDS = {
    'schoolgirl': 'schoolgirl', 'fighter': 'fighter', 'librarian': 'librarian', 'shaman': 'shaman',
    'boxer': 'boxer', 'warrior': 'knight', 'knight': 'knight', 'bard': 'bard', 'magician': 'magician',
    'champion': 'champion', 'duelist': 'duelist', 'mercenary': 'mercenary', 'mercenery': 'mercenary',
    'mercernery': 'mercenary', 'gladiator': 'gladiator', 'soul master': 'soul_master', 'witch': 'witch',
    'wizard': 'wizard', 'dark lord': 'dark_lord', 'priest': 'priest',
    'archeologist': 'archeologist', 'engineer': 'engineer', 'explorer': 'explorer', 'treasure hunter': 'explorer',
    'inventor': 'inventor', 'thief master': 'thief_master', 'theif master': 'thief_master', 'scientist': 'scientist',
    'hunter lord': 'hunter_lord', 'cyber hunter': 'cyber_hunter',
    'model': 'model', 'teacher': 'teacher', 'entertainer': 'entertainer', 'talent': 'entertainer',
    'card master': 'card_master', 'primadonna': 'primadonna', 'gambler': 'gambler', 'diva': 'diva', 'duke': 'duke',
}
FIRST_JOBS = {'schoolgirl', 'fighter', 'librarian', 'shaman', 'archeologist', 'engineer', 'model', 'teacher'}

# Master Louis's material for each card (the original's are monster drops
# from SkillMasterInfo, most of which aren't in the game yet).
MATERIALS = ['sharp_leg', 'eye_drop', 'hard_scales', 'scorpion_sting', 'cooling_fan', 'acorn_nut',
             'cool_ice', 'cool_spring_water', 'duck_mole_paws', 'bronze_scarab', 'nemeth_towel', 'shawabti',
             'cocos_shell', 'sand_glass', 'slime_husk', 'turban_shell', 'twinkle_star', 'ugly_pearl']

# Fallback sounds by element for skills SkillSound has none for (the
# original's generic magic effects).
ELEMENT_SOUNDS = {
    'Fire': {'ht': 'eff_fireball_b.wav'}, 'Water': {'ht': 'eff_icemagic.wav'}, 'Elec': {'ht': 'eff_lightning1.wav'},
    'Wind': {'ht': 'eff_windmagic1.wav'}, 'Earth': {'ht': 'snd_skl_m_006_ebg.wav'}, 'Light': {'ht': 'eff_light.wav'},
    'Dark': {'ht': 'eff_light_explosion.wav'},
}


def load(name):
    with open(os.path.join(TABLES, name + '.json'), encoding='utf-8') as f:
        return json.load(f)


def by_level(table):
    if not table or not os.path.exists(os.path.join(TABLES, table + '.json')):
        return {}
    return {r['Level']: r for r in load(table) if 'Level' in r}


def need(level):
    return 3 if level >= 10 else 2 if level >= 7 else 1


def pct_hit(r):
    """The tooltip's attack % of a normal hit."""
    return r['Comment'] / 100.0 * NORMAL_HIT


def tidy(v):
    """Numbers as a card shows them: whole above 10, one decimal above 1,
    else two (cast times like 0.75 s)."""
    v = float(v)
    return float(round(v)) if abs(v) >= 10 else round(v, 1) if abs(v) >= 1 else round(v, 2)


def fmt(v):
    v = round(float(v), 2)
    return str(int(v)) + '.0' if v == int(v) else str(v)


def tres_value(v):
    if isinstance(v, str):
        return json.dumps(v)
    if isinstance(v, list):
        return '[' + ', '.join(fmt(x) for x in v) + ']'
    return fmt(v)


def job_ids(field):
    """'Warrior, Gladiator, Mercenary, Duelist[TM 101]' -> ['knight', 'gladiator', ...]."""
    out = []
    for part in field.split(','):
        name = re.sub(r'\[.*?\]|:\d+', '', part).strip().lower()
        if name in JOB_IDS and JOB_IDS[name] not in out:
            out.append(JOB_IDS[name])
    return out


def is_active(sk):
    t = sk['Type']
    opts = sk['SkillOption'].split('/')
    return t == '2' or (t == '3' and '4' in opts and '32' not in opts)


_SOUNDS = None
# The effects and sounds each skill's client class plays, read from
# Trickster.bin (see the README's "Reverse engineering"): {card: {"effects":
# {phase: [cake]}, "sounds": {phase: file}}}. They replace the name matching
# below for the phases they cover.
CLIENT_FX = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'client_effects.json'),
                           encoding='utf-8'))
_CAKES = None
EFFECTS = os.path.join(ROOT, 'original_assets', 'effects')
# Phase of a cake name's suffix: "ap" plays on the caster when the skill goes
# off, "fl" on the projectile, "ht" on the target, "ke" while it lasts, "ed"
# when it ends. The older numbered effects use s.. (self), g.. (ground) and
# e.. (enemy) with bg (begin), ps (process) and ed (end).
PHASES = {'apply': 'ap', 'ap': 'ap', 'hit': 'ht', 'ht': 'ht', 'fly': 'fl', 'fl': 'fl', 'keep': 'ke', 'ke': 'ke',
          'ed': 'ed', 'end': 'ed'}


def _cake_names():
    global _CAKES
    if _CAKES is None:
        path = os.path.join(EFFECTS, 'cake_names.json')
        _CAKES = json.load(open(path, encoding='utf-8')) if os.path.exists(path) else []
    return _CAKES


def effects_for(sid, sk):
    """The skill's original particle effects (cake.xml), by phase: matched by
    action name like the sounds (M_223_electric_field_keep is Tesla Field's
    ElectricField), or by the older numbering (eft_skl_m_005_eed is skill
    2005, eft_skl_p_302_sed_0 is 1302)."""
    out = {}
    keys = [re.sub(r'[^a-z]', '', t.split('_', 1)[1].lower()) for t in (sk['ESAIITable'], sk['ESATable']) if t and '_' in t]
    line = 'm' if sid[0] == '2' else 'p' if sid[0] == '1' else ''
    for name in _cake_names():
        m = re.match(r'^[A-Za-z]+_\d+_(.+?)_(apply|hit|fly|keep|ap|ht|fl|ke|ed)\d*$', name, re.I)
        if m and re.sub(r'[^a-z]', '', m.group(1).lower()) in keys:
            out.setdefault(PHASES[m.group(2).lower()], []).append(name)
            continue
        m = re.match(r'^eft_skl_([mp])_?(\d{3})(?:_([a-z]+))?', name, re.I)
        if m and line and m.group(1).lower() == line and m.group(2) == sid[1:]:
            suffix = (m.group(3) or 'sbg').lower()
            phase = 'ed' if suffix.endswith('ed') else 'ht' if suffix[0] == 'e' or suffix == 'mon' else 'ap'
            out.setdefault(phase, []).append(name)
    return out


def sounds_for(sk):
    """The skill's original sounds from SkillSound, matched by its action
    name (ESAII_ElectricField -> M_223_electric_field_apply): {"ap", "ht",
    "fl", "ke"} -> file name."""
    global _SOUNDS
    if _SOUNDS is None:
        _SOUNDS = {}
        for r in load('SkillSound'):
            m = re.match(r'^[A-Za-z]+_\d+_(.+?)_(apply|hit|fly|keep|ap|ht|fl|ke)\d*$', r['Name'], re.I)
            if m:
                key = re.sub(r'[^a-z]', '', m.group(1).lower())
                # The suffix's phase as the cards name it ("hit" is "ht", not "hi").
                phase = PHASES[m.group(2).lower()]
                _SOUNDS.setdefault(key, {}).setdefault(phase, r['FileName'].replace('\\', '/').split('/')[-1])
    for t in (sk['ESAIITable'], sk['ESATable']):
        if t and '_' in t:
            key = re.sub(r'[^a-z]', '', t.split('_', 1)[1].lower())
            if key in _SOUNDS:
                return dict(_SOUNDS[key])
    return {}


def build(spec, out_dir, jobs, starters=None, names_extra=None, casting=False, extra_cards=None):
    """Writes one .tres per card in `spec` into data/skills/<out_dir> and
    fills the jobs' card lists. `jobs`: job id -> skill-id prefixes (or a
    callable taking the skill id). `starters`: job id -> card id. Returns
    {skill id: card id}."""
    skills = {r['ID']: r for r in load('SkillParam2')}
    cards = {r['AffectionSkill']: r for r in load('Item_SkillCardParam')}
    out = os.path.join(ROOT, 'data', 'skills', out_dir)
    os.makedirs(out, exist_ok=True)
    names = {i: s['card'] for i, s in spec.items()}
    names.update(names_extra or {})
    for n, (sid, sp) in enumerate(spec.items()):
        sk, cp = skills[sid], cards[sid]
        rows = by_level(sk['ESAIITable'])
        act = by_level(sk['ESATable'])
        merged = {lv: {**rows.get(lv, {}), **act.get(lv, {})} for lv in range(1, 12)}
        merged = {lv: r for lv, r in merged.items() if r} or {1: {}}

        def row_at(i):
            lv = LEVELS[i]
            below = [k for k in merged if k <= lv]
            return merged[max(below)] if below else merged[min(merged)]

        skill = sp.get('kind', 'skill' if is_active(sk) else 'talent') == 'skill'
        cap = 1 if int(sk['MaxSKLV']) <= 1 else 0
        count = 1 if cap == 1 else len(LEVELS)
        table = {'value': [sp['value'](row_at(i)) for i in range(count)]} if 'value' in sp else {}
        # Counts (Arrow Rush's arrows) stay the original's.
        if 'value' in sp and count > RUN_LEVELS and not all(float(v).is_integer() and v <= 20 for v in table['value']):
            top = table['value'][RUN_LEVELS - 1]
            for i in range(RUN_LEVELS, count):
                table['value'][i] = round(top * (1 + MASTERY_STEP * (i - RUN_LEVELS + 1)), 2)
        if skill:
            table['mp'] = [round(20 * (max(row_at(i).get('MpCon', 32), 1) / 32.0) ** 0.4) for i in range(count)]
            table['cooldown'] = [row_at(i).get('CoolTime', 1.0) or 1.0 for i in range(count)]
            if casting and sk['SpellType'] == '1':
                table['cast'] = [float(row_at(i).get('Delay', 0.0)) * 0.5 for i in range(count)]
        for rname, src in sp.get('rows', {}).items():
            table[rname] = [src(row_at(i)) if callable(src) else row_at(i)[src] for i in range(count)]
        requires = {}
        for k in (1, 2, 3):
            pre, lv = cp[f'PreSkill_{k}'], cp[f'PreSkillLv_{k}']
            if pre != '0' and pre in names:
                requires[names[pre]] = need(lv)
        requires.update(sp.get('requires_extra', {}))  # our own cards (Overcharge)
        listed = job_ids(cp['Job'])
        learners = [] if not listed or all(j in FIRST_JOBS for j in listed) else listed
        element = ELEMENT_NAMES.get(sp.get('element', ''), sp.get('element')) or ELEMENTS.get(sk['Element'], 'none')
        client = CLIENT_FX.get(sp['card'], {})
        sounds = sp.get('sounds') or {**(sounds_for(sk) or ({} if client.get('sounds') else ELEMENT_SOUNDS.get(element, {}) if skill else {})),
                                      **client.get('sounds', {})}
        behavior = sp.get('behavior')
        ext = [('Script', 'res://scripts/data/card_data.gd', '1_s'),
               ('Resource', f'res://data/materials/{MATERIALS[n % len(MATERIALS)]}.tres', 'm_master')]
        if behavior:
            ext.append(('Script', f'res://scripts/skills/{behavior}.gd', '2_b'))
        talent = sp.get('talent')
        if talent:
            ext.append(('Script', f'res://scripts/talents/{talent}.gd', '3_t'))
        lines = [f'[gd_resource type="Resource" script_class="CardData" load_steps={len(ext) + 1} format=3]', '']
        for t, p, i in ext:
            lines.append(f'[ext_resource type="{t}" path="{p}" id="{i}"]')
        display = sp.get('name') or sk['Name']
        lines += ['', '[resource]', 'script = ExtResource("1_s")', f'id = &"{sp["card"]}"',
                  f'display_name = {json.dumps(display)}', f'kind = {1 if skill else 0}', f'skill_id = {sid}',
                  f'text = {json.dumps(sp["text"])}']
        if requires:
            lines.append('requires = {' + ', '.join(f'&"{k}": {v}' for k, v in requires.items()) + '}')
        if sp.get('upgrades'):
            lines.append(f'upgrades = &"{names[sp["upgrades"]]}"')
        if learners:
            lines.append('jobs = Array[StringName]([' + ', '.join(f'&"{j}"' for j in learners) + '])')
        if sp.get('excludes'):
            lines.append('excludes = Array[StringName]([' + ', '.join(f'&"{names.get(e, e)}"' for e in sp['excludes']) + '])')
        if cap:
            lines.append(f'max_level = {cap}')
        table = {k: [tidy(x) for x in v] for k, v in table.items()}
        lines.append('table = {' + ', '.join(f'"{k}": {tres_value(v)}' for k, v in table.items()) + '}')
        if sounds:
            lines.append('sounds = {' + ', '.join(f'"{k}": {json.dumps(v)}' for k, v in sorted(sounds.items())) + '}')
        effects = effects_for(sid, sk)
        if client.get('effects'):
            # The client's own list wins; the skill-number guesses (eft_skl_*)
            # it doesn't confirm are dropped (the numbering isn't the skill id's).
            effects = {ph: [n for n in names if not n.lower().startswith('eft_skl')] for ph, names in effects.items()}
            effects.update({ph: list(names) for ph, names in client['effects'].items()})
            effects = {ph: names for ph, names in effects.items() if names}
        # Informally named effects the spec points at (no skill number in the name).
        for phase, extra in sp.get('effects', {}).items():
            effects[phase] = list(extra) + [n for n in effects.get(phase, []) if n not in extra]
        if effects:
            lines.append('effects = {' + ', '.join(f'"{k}": {json.dumps(v)}' for k, v in sorted(effects.items())) + '}')
        lines.append('master_material = ExtResource("m_master")')
        if element != 'none':
            lines.append(f'element = "{element}"')
        if sp.get('scaling'):
            lines.append(f'scaling = "{sp["scaling"]}"')
        if sp.get('tags'):
            lines.append('tags = Array[StringName]([' + ', '.join(f'&"{t}"' for t in sp['tags']) + '])')
        if sp.get('form'):
            lines.append(f'form = &"{sp["form"]}"')
        if sp.get('form_actor'):
            lines.append(f'form_actor = "{sp["form_actor"]}"')
        for field in ('form_gains', 'form_losses'):
            if sp.get(field):
                lines.append(f'{field} = Array[String]([' + ', '.join(f'"{k}"' for k in sp[field]) + '])')
        if sp.get('inflicts'):
            lines.append(f'inflicts = "{sp["inflicts"]}"')
        if sp.get('mods'):
            # What the card adds to Run.mod(): a Mod key -> 'value' or one of its table rows.
            lines.append('mods = Dictionary[String, String]({' + ', '.join(f'"{k}": "{v}"' for k, v in sp['mods'].items()) + '})')
        if behavior:
            lines.append('behavior = ExtResource("2_b")')
        if talent:
            lines.append('talent = ExtResource("3_t")')
        with open(os.path.join(out, sp['card'] + '.tres'), 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(lines) + '\n')
    # Job card lists, in the order the original unlocks them (TM level).
    for job, picks in jobs.items():
        test = picks if callable(picks) else (lambda i, p=picks: i[:2] in p)
        ids = sorted((i for i in spec if test(i) and not spec[i].get('held')), key=lambda i: (cards[i]['TMLV'], i))
        # Hand-made cards of ours (`extra_cards`: job -> card ids) join the list.
        _fill_job(job, [names[i] for i in ids] + (extra_cards or {}).get(job, []), out_dir, (starters or {}).get(job))
        print(f'{job}: {len(ids)} cards')
    print(f'{len(spec)} cards written to {out}')
    return names


def _fill_job(job, card_ids, out_dir, starter):
    path = os.path.join(ROOT, 'data', 'jobs', job + '.tres')
    with open(path, encoding='utf-8') as f:
        src = f.read()
    src = re.sub(r'\[ext_resource type="Resource" path="res://data/(coral_beach/cards|skills/[a-z]+)/[a-z_]+\.tres" id="c_[a-z_]+"\]\n', '', src)
    new_ext = ''.join(f'[ext_resource type="Resource" path="res://data/skills/{out_dir}/{c}.tres" id="c_{c}"]\n' for c in card_ids)
    src = src.replace('\n[resource]', '\n' + new_ext + '\n[resource]', 1) if new_ext else src
    src = re.sub(r'\n+(\[ext_resource type="Resource" path="res://data/skills)', r'\n\1', src, count=1)
    src = re.sub(r'\n+\[resource\]', '\n\n[resource]', src, count=1)
    card_list = 'cards = Array[ExtResource("2_c")]([' + ', '.join(f'ExtResource("c_{c}")' for c in card_ids) + '])'
    src = re.sub(r'^cards = .*$', card_list, src, flags=re.M)
    if starter:
        if re.search(r'^starter = ', src, flags=re.M):
            src = re.sub(r'^starter = .*$', f'starter = ExtResource("c_{starter}")', src, flags=re.M)
        else:
            src = src.replace('\ncards = ', f'\nstarter = ExtResource("c_{starter}")\ncards = ', 1)
    n_ext = len(re.findall(r'^\[ext_resource', src, flags=re.M))
    src = re.sub(r'load_steps=\d+', f'load_steps={n_ext + 1}', src, count=1)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(src)
