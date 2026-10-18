"""Builds tools/client_effects.json: per card, the original effects (cakes)
and sounds its client class plays, sorted into our phases by the client's
name suffixes. Only names found in the class's own functions or their direct
callees, and not shared with another skill's class (shared helpers carry
other skills' names), are kept. usage: python client_fx.py <REA work folder holding re_plan_full.json and re_out/>"""
import collections
import json
import os
import re
import sys

S = sys.argv[1]  # the REA work folder
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
plan = json.load(open(os.path.join(S, 're_plan_full.json')))
cakes = set(json.load(open(ROOT + '/original_assets/effects/cake_names.json', encoding='utf-8')))
STR = re.compile(r'"((?:[^"\\]|\\.)*)"')
CALL = re.compile(r'\b(?:FUN|thunk_FUN)_00([0-9a-f]{6})\b')


def text(a):
    p = os.path.join(S, 're_out', a + '.c')
    return open(p, encoding='utf-8').read() if os.path.exists(p) else ''


found = {}
for card, p in plan.items():
    fx, snd = set(), set()
    for a in p['own']:
        for c in [a] + ['0x' + x for x in CALL.findall(text(a))]:
            for s in STR.findall(text(c)):
                if s in cakes:
                    fx.add(s)
                elif s.startswith('snd_'):
                    snd.add(s)
    found[card] = (fx, snd)
uses = collections.Counter(x for fx, snd in found.values() for x in fx | snd)

# Phase by the client's suffixes: ap cast/start, fl flight, ht hit, ke lasting, ed end.
SUFFIX = [(r'_(ap\d?|apply\d?|sps|sbg|gps)$', 'ap'), (r'_(fly|fl|spt)$', 'fl'),
          (r'_(hit|ht\d?|ebg\d?|eed|eps|sed)$', 'ht'), (r'_(keep\d?|ke\d?)$', 'ke'), (r'_(ed\d*)$', 'ed')]
# Names without a suffix, by how the client uses them (read from the code).
BY_NAME = {'skill_power attack': 'ht', 'magic impect': 'ht', 'hit drow': 'ht', 'element_ice': 'ht',
           'electric sword': 'ap', 'skill_adre': 'ap', 'skill_adre u ji': 'ke', 'skill_ni ke ma up': 'ap',
           'eft_skl_m_113_1': 'ap', 'eft_skl_m_113_2': 'ke'}
# Shared names that really are the skill's (every elemental Shield applies with
# the Water Shield's effect and sound; the Bard spells end with snd_skl_m_109_sed).
ALLOW_SHARED = {'M_217_water_shield_apply', 'snd_m_217_ap', 'snd_skl_m_109_sed', 'skill_power attack',
                'magic impect', 'P_309_Wind_brandish_ap', 'eft_skl_p_025_sbg', 'snd_p_307_fl',
                'snd_skl_p_109_sbg', 'hit drow',
                # Shared within one skill family: the Breakers, the punch line, the Wind Brandishes.
                'snd_skl_p_006_sbg', 'snd_skl_p_015_ebg1', 'jang bi hit'}


def phase(name):
    if name in BY_NAME:
        return BY_NAME[name]
    for pat, ph in SUFFIX:
        if re.search(pat, name, re.I):
            return ph
    return None


out, skipped = {}, collections.defaultdict(list)
for card, (fx, snd) in found.items():
    eff, sounds = {}, {}
    for name in sorted(fx):
        if uses[name] > 1 and name not in ALLOW_SHARED:
            skipped[card].append(name)
            continue
        ph = phase(name)
        if ph:
            eff.setdefault(ph, []).append(name)
        else:
            skipped[card].append(name)
    for name in sorted(snd):
        if uses[name] > 1 and name not in ALLOW_SHARED:
            skipped[card].append(name)
            continue
        ph = phase(name)
        if ph and ph not in sounds:
            sounds[ph] = name + '.wav'
    if eff or sounds:
        out[card] = {'effects': eff, 'sounds': sounds}
json.dump(out, open(ROOT + '/tools/client_effects.json', 'w'), indent=1, sort_keys=True)
print(len(out), 'cards with client effects/sounds')
for card, names in skipped.items():
    print('skipped', card, names)
