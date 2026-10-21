"""Generate the Power line's skill cards (Buffalo and Bunny) from the
original skill tables. The rules for reading them are in skill_trees.py.

usage: python -I tools/power_skills.py   (from the project root)

Writes data/skills/power/<card>.tres and fills the card lists of the jobs in
data/jobs.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from skill_trees import NORMAL_HIT, build, pct_hit  # noqa: E402

# Jobs and the original tree that fills them (skill id prefix).
JOBS = {
    'fighter': ['10'], 'schoolgirl': ['10'],
    'boxer': ['11'], 'knight': ['12'],
    'champion': ['13'], 'gladiator': ['15'],
    # The hybrids learn the other 2nd job's skills instead of new ones.
    'duelist': ['12'], 'mercenary': ['11'],
}


# id -> card spec. kind: 'skill' or 'talent'. value: the main number from a
# level row. rows: extra numbers by level. text: "{v}" and "{row}" fill in.
SPEC = {
    # ---- 1st job: Fighter and Schoolgirl
    '1001': dict(card='shockwave', kind='skill', behavior='shockwave', value=pct_hit,
                 text='Gather all your strength into one blow that knocks enemies around you down for {v} damage.'),
    '1002': dict(card='pumping_heart', mods={'AP%': 'value'}, value=lambda r: r['Comment'], text='+{v}% AP.'),
    '1003': dict(card='bulls_eye', mods={'AC%': 'value'}, value=lambda r: r['Comment'], text='+{v}% Accuracy (AC): fewer grazes on evasive foes.'),
    '1004': dict(card='burning_rave', kind='skill', behavior='burning_rave', value=pct_hit,
                 text='Two blows fused into one: a heavy strike for {v} damage.'),
    '1005': dict(card='armor_breaker', inflicts='dp', value=lambda r: r['Comment'], rows={'seconds': 'Seconds'},
                 text='Your hits lower an enemy\'s DP by {v}% for {seconds} s.'),
    '1006': dict(card='shockvibe', inflicts='ac', value=lambda r: r['Comment'], rows={'seconds': 'Seconds'},
                 text='Your hits daze an enemy: its accuracy drops {v}% for {seconds} s, so you evade it more.'),
    '1007': dict(card='sense_breaker', inflicts='perception', value=lambda r: r['Comment'], rows={'seconds': 'Seconds'},
                 text='Your hits dull an enemy\'s perception by {v}% for {seconds} s: it is slower to see its attacks through.'),
    '1008': dict(card='upper_smash', kind='skill', behavior='upper_smash', value=lambda r: pct_hit(r) / 2,
                 text='Knock an enemy into the air, then smash it as it falls: two hits of {v} damage.'),
    '1009': dict(card='hyper_beat', mods={'attack_speed%': 'value'}, value=lambda r: -r['DX'] * 8, text='Agility (DX) up: attack {v}% faster.'),
    '1010': dict(card='luck_breaker', inflicts='luck', value=lambda r: r['Comment'], rows={'seconds': 'Seconds'},
                 text='Your hits curse an enemy\'s luck by {v}% for {seconds} s: your critical hits land on it that much more often.'),
    '1011': dict(card='tornado_bomb', kind='skill', behavior='tornado_bomb', value=lambda r: r['Comment'] / 100.0 * NORMAL_HIT / 8,
                 text='A spinning fist sends out a tornado that cuts enemies for {v} damage several times a second.'),
    # ---- Boxer
    '1101': dict(card='guard_break', mods={'shockwave.guard_chance': 'value', 'shockwave.guard_seconds': 'seconds'}, value=lambda r: r['ApplyRatio'] * 100, rows={'seconds': 'Seconds'},
                 text='Shockwave has a {v}% chance to break an enemy\'s guard for {seconds} s: it can\'t evade and has no DP.'),
    '1102': dict(card='boxer_dash', kind='skill', behavior='boxer_dash', value=lambda r: NORMAL_HIT, rows={'range': 'Range'},
                 text='Step in front of the enemy you aim at (up to {range} away) before it can react, striking for {v} damage.'),
    '1103': dict(card='uppercut', kind='skill', behavior='uppercut', value=pct_hit,
                 text='Uppercut an enemy into the air for {v} damage.'),
    '1104': dict(card='quad_punch', kind='skill', behavior='quad_punch', value=lambda r: pct_hit(r) / 4,
                 text='Four blazing blows in a row, {v} damage each.'),
    '1105': dict(card='eagle_eye', mods={'AC%': 'value'}, value=lambda r: r['Comment'], text='+{v}% Accuracy (AC).'),
    '1106': dict(card='counter_punch', mods={'uppercut.counter_chance': 'chance', 'uppercut.counter_damage': 'value'}, value=pct_hit, rows={'chance': lambda r: 50},
                 text='While you Uppercut, a {chance}% chance of a counter blow for {v} more damage.'),
    '1107': dict(card='guard', name='Guard', value=lambda r: r['Count'], rows={'cooldown': 'CoolTime'},
                 text='Block up to {v} physical hits completely (not magic). A spent block returns after {cooldown} s.'),
    '1108': dict(card='tetra_punch', kind='skill', behavior='quad_punch', upgrades='1104', value=lambda r: pct_hit(r),
                 text='Four blows at vital points, {v} damage and stronger with every one that lands.'),
    '1109': dict(card='desperate_rally', value=lambda r: r['Comment'], rows={'hp': 'HPPercent'},
                 text='Below {hp}% HP, +{v}% AP, rising the lower your HP gets.'),
    '1110': dict(card='clinch_release', tags=['cast_staggered'], kind='skill', behavior='clinch_release', value=lambda r: 0,
                 text='Usable while staggered: shake off the hit, its knockback and anything holding you.'),
    # ---- Knight
    '1201': dict(card='faint', mods={'shockwave.stun_chance': 'value', 'shockwave.stun_seconds': 'seconds'}, value=lambda r: r['ApplyRatio'] * 100, rows={'seconds': 'Seconds'},
                 text='Shockwave has a {v}% chance to make an enemy faint for {seconds} s.'),
    '1202': dict(card='lacerator', kind='skill', behavior='lacerator', value=pct_hit,
                 text='A blade aura cuts in front of and behind you for {v} damage.'),
    '1203': dict(card='berserker', mods={'damage%': 'value'}, value=lambda r: (r['ApRatio'] - 1.0) * 100 * min(1.0, r['Seconds'] / r['CoolTime']),
                 text='Rage: +{v}% AP, but you keep losing HP and MP while enemies are near.'),
    '1204': dict(card='piercing_wave', kind='skill', behavior='piercing_wave', value=pct_hit,
                 text='Shoot a wave of energy that pierces every enemy in a line for {v} damage.'),
    '1205': dict(card='blazing_strike', kind='skill', behavior='blazing_strike', value=pct_hit, rows={'targets': 'KillNum', 'range': 'Range'},
                 text='Blazing-fast strikes on the nearest enemies (up to {targets}) for {v} damage each; more hits with more DX.'),
    '1206': dict(card='aura_of_haste', mods={'attack_speed%': 'value'}, value=lambda r: -r['DX'] * 8, text='Agility (DX) up: attack {v}% faster.'),
    '1207': dict(card='tidal_slash', kind='skill', behavior='tidal_slash', value=pct_hit, element='water', upgrades='1202',
                 rows={'range': 'Range', 'targets': 'MonNum'},
                 text='A wide Lacerator that slices the enemies in front and behind (up to {targets}) for {v} water damage.'),
    '1208': dict(card='inferno_blade', name='Inferno Blade', kind='skill', behavior='inferno_blade', value=pct_hit, element='fire', rows={'radius': 'Radius'},
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
    '1301': dict(card='adrenaline', mods={'AP%': 'value'}, value=lambda r: r['Comment'], text='+{v}% AP.'),
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
    '1503': dict(card='suffocate', inflicts='pinned', value=lambda r: r['Second'],
                 text='Your hits pin an enemy down: for {v} s it can\'t hide (burrow or vanish).'),
    '1504': dict(card='gale_strike', kind='skill', behavior='wind_blades', value=pct_hit, element='wind', upgrades='1209',
                 rows={'radius': 'Radius', 'targets': 'KillNum'},
                 text='A gale of wind blades shreds the enemies around you (up to {targets}) for {v} wind damage.'),
    '1505': dict(card='chi_sword', mods={'combo_damage%': 'value', 'combo_reach%': 'reach'}, value=lambda r: r['Comment'], rows={'reach': lambda r: (r['Range'] / 80.0 - 1.0) * 100},
                 text='Your blade swells with chi: basic attacks reach {reach}% further and deal {v}% more damage.'),
    '1506': dict(card='chakra_balance', kind='skill', behavior='chakra_balance', value=lambda r: r['Heal'] / 100.0,
                 rows={'seconds': 'Time', 'interval': 'Interval'},
                 text='Recover {v}% of your HP every {interval} s for {seconds} s, until you take a hit.'),
}


def main():
    build(SPEC, 'power', JOBS, starters={'fighter': 'shockwave', 'schoolgirl': 'shockwave'})


if __name__ == '__main__':
    main()
