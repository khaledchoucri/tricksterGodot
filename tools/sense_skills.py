"""Generate the Sense line's skill cards (Fox and Lion) from the original
skill tables. The rules for reading them are in skill_trees.py; this file
lists each skill: its card id, the behaviour that performs it, its main
number and the extra table rows it needs.

usage: python -I tools/sense_skills.py   (from the project root)

Line-specific readings:
- Throwing and treasure skills scale with DA ("perceptibility", the Sense
  skill power). Gun skills scale with GUN: AP + DA, so both the gun you find
  (its AP) and Sense points grow them. Bare-handed strikes scale with AP.
- No ammunition: guns need no bullets and throws no thrown items (the user's
  rule). Power Shot and Double Shot need the gun loaded instead.
- Held back for want of the system they act on: Anger Management and Mega
  Crazy Drilling (no Crazy Drill mode), Gas Mask (no Skunk Pouch), Strong
  Mind (no Entrancing Wink), Leg Training (no monster slows you), Stone
  Shower (no job lists it).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from skill_trees import NORMAL_HIT, build, pct_hit  # noqa: E402


def gun_pct(r):
    """A gun skill's Ratio as a % of a gun shot."""
    return round(r['Ratio'] * 100)


SPEC = {
    # ---- Archeologist and Engineer (shared 1st job)
    '3001': dict(card='invincible_drill', value=lambda r: 0,
                 text='Misses at a Dig Site make no noise: nothing below wakes up.'),
    '3002': dict(card='stone_strike', behavior='stone_strike', value=pct_hit, scaling='DA', rows={'range': 'Range'},
                 text='Strike the enemy in front for {v} damage, as hard as stone.'),
    '3003': dict(card='heavy_carrier', mods={'WT': 'value'}, value=lambda r: r['WT'] / 10.0, text='+{v} weight limit.'),
    '3004': dict(card='sticky_foot', inflicts='slow', value=lambda r: r['Comment'], rows={'seconds': 'Seconds'},
                 text='Your hits pour sticky oil: the enemy is {v}% slower for {seconds} s.'),
    '3005': dict(card='armor_destructor', inflicts='dp', value=lambda r: r['Comment'], rows={'seconds': 'Seconds'},
                 text='Your hits break armour: the enemy has {v}% less DP for {seconds} s.'),
    '3006': dict(card='sixth_sense', mods={'DA%': 'value'}, value=lambda r: r['Comment'], text='+{v}% DA.'),
    '3007': dict(card='shuriken_master', tags=['thrown'], behavior='thrown_weapon', value=pct_hit, scaling='DA',
                 rows={'range': 'Range'},
                 text='Throw a hidden weapon at the enemy you aim at for {v} damage. Fox\'s basic attack.'),
    '3008': dict(card='gun_carrier', tags=['carries_guns'], value=lambda r: 0,
                 text='You can carry guns. A loaded gun can\'t share your hands with a shield.'),
    '3009': dict(card='lucky_seven', mods={'LK%': 'value'}, value=lambda r: r['Comment'], text='+{v}% LK.'),
    '3010': dict(card='quick_reload', tags=['grows_gun', 'reload_while_moving'], value=lambda r: 0, text='Your reload keeps filling while you walk or run.'),
    '3011': dict(card='invincible_reload', tags=['grows_gun', 'reload_through_hits'], value=lambda r: 0, text='Being hit no longer resets your reload.'),
    # Gun Booster (PriMarksmanship) adds its AP to the basic shot's Gun AP.
    '3012': dict(card='gun_booster', tags=['grows_gun'], mods={'gun_AP': 'value'}, value=lambda r: r['AP'], text='Your gun shots carry {v} more Gun AP.'),
    '3013': dict(card='basic_detection', value=lambda r: r['Depth'] / 10.0,
                 text='You sense what lies below: digs reach {v} deeper.'),
    '3014': dict(card='compound_master', mods={'compound%': 'value'}, value=lambda r: r['Comment'], text='Compounding succeeds {v}% more often.'),
    '3015': dict(card='stone_shower', value=pct_hit, held=True, text='Throw the rocks on the road.'),
    '3016': dict(card='anger_management', value=lambda r: r['Comment'], held=True,
                 text='Stress builds {v}% faster toward Crazy Drilling.'),
    # ---- Explorer (Fox)
    '3101': dict(card='precise_pitch', mods={'thrown_damage%': 'value'}, value=lambda r: r['Comment'] - 100, text='Thrown weapons hit {v}% harder.'),
    '3102': dict(card='item_detector', value=lambda r: r['DepthRatio'],
                 text='Digs bring up {v}% more.'),
    '3103': dict(card='aura_of_luck', mods={'LK%': 'value'}, value=lambda r: r['Comment'], text='+{v}% LK.'),
    '3104': dict(card='landmine', behavior='mine', value=lambda r: r['TrapAp'] * NORMAL_HIT, scaling='DA', kind='skill',
                 rows={'range': 'Range', 'radius': 'Radius', 'count': lambda r: 1, 'seconds': lambda r: 20},
                 text='Bury a mine at the cursor: it bursts on the first enemy near it for {v} damage.'),
    '3105': dict(card='pouch_of_pain', behavior='pouch_throw', value=lambda r: r['Comment'] / 100.0 * NORMAL_HIT,
                 scaling='DA', rows={'range': 'Range', 'radius': 'Radius'},
                 text='Hurl a heavy pouch at the cursor: {v} damage to everything around it.'),
    '3106': dict(card='sticky_icky', behavior='spell_debuff', value=lambda r: r['Comment'], kind='skill',
                 rows={'range': lambda r: 120, 'radius': 'Radius', 'seconds': 'Seconds'},
                 text='Splash glue around the cursor: monsters there lose {v}% HV, LK and DP for {seconds} s.'),
    '3107': dict(card='gas_mask', value=lambda r: r['Comment'], held=True, text='Resist Skunk Pouch.'),
    '3108': dict(card='lightning_rod', mods={'resist:Elec': 'value'}, value=lambda r: r['Comment'], text='Electric resistance +{v}%.'),
    '3109': dict(card='fan_of_knives', tags=['thrown'], behavior='fan_of_knives', value=pct_hit, scaling='DA',
                 rows={'range': 'Range', 'targets': 'MonNum', 'angle': 'Angle'},
                 text='Throw a fan of knives: {v} damage to up to {targets} enemies in front.'),
    '3110': dict(card='chain_of_knives', tags=['thrown'], behavior='chain_of_knives', value=pct_hit, scaling='DA',
                 rows={'range': lambda r: 200, 'count': 'Count'},
                 text='Throw {count} knives in quick succession at one enemy, {v} damage in all.'),
    '3111': dict(card='mega_crazy_drilling', value=lambda r: r['Comment'], held=True, text='Crazy Drilling lasts longer.'),
    '3112': dict(card='rain_of_knives', tags=['thrown'], behavior='rain_of_knives', value=pct_hit, scaling='DA',
                 rows={'range': 'Range', 'radius': 'Radius', 'count': 'Count', 'knives': 'KnifeCount',
                       'targets': 'KillNum'},
                 text='Throw knives high above: they rain on up to {targets} enemies at the cursor, {v} damage in all.'),
    # ---- Inventor (Lion)
    # The gun skills' Ratio is a multiple of a gun shot (the server's gun
    # formula times it), so they always outhit the basic shot.
    '3201': dict(card='butt_plate', tags=['gun'], behavior='close_strike', value=gun_pct, scaling='GUN', rows={'range': 'Range'},
                 text='Club the enemy in front with your gun\'s butt: {v}% of a gun shot. Needs a gun.'),
    '3202': dict(card='power_shot', tags=['gun'], behavior='gun_skill', value=gun_pct, scaling='GUN', rows={'range': 'Range'},
                 text='Fire a concentrated round: {v}% of a gun shot. It doesn\'t use up your load.'),
    '3203': dict(card='shooting_spree', tags=['gun'], behavior='gun_spray', value=gun_pct, scaling='GUN',
                 rows={'radius': 'Radius', 'targets': 'MonNum'},
                 text='A burst of shots at up to {targets} random enemies around you, {v}% of a gun shot each.'),
    '3204': dict(card='lucky_fist', behavior='close_strike', value=pct_hit, scaling='AP', rows={'range': 'Range'},
                 text='Trust your luck: a punch for {v} damage, more with LK.'),
    '3205': dict(card='keen_sense', tags=['grows_gun'], mods={'power_shot%': 'value'}, value=lambda r: r['Comment'] - 100, text='Overcharged shots deal {v}% more damage.',
                 requires_extra={'overcharge': 1}),
    '3206': dict(card='double_shot', tags=['gun'], behavior='gun_skill', value=lambda r: r['Comment'], scaling='GUN',
                 rows={'range': 'Range', 'count': lambda r: 2},
                 text='Fire twice in a row, {v}% of a gun shot in all; the second can\'t be dodged.'),
    '3207': dict(card='shield_breaker', tags=['gun'], behavior='gun_skill', value=lambda r: r['Comment'], scaling='GUN', kind='skill',
                 rows={'range': 'Range', 'seconds': 'Seconds'},
                 text='A breaching round: the enemy takes {v}% more gun damage for {seconds} s.'),
    '3208': dict(card='leg_training', value=lambda r: r['Comment'], held=True, text='Resist slows.'),
    '3209': dict(card='lock_on', inflicts='hv', value=lambda r: r['Comment'], rows={'seconds': 'Seconds'},
                 text='Your hits mark the enemy: {v}% less HV for {seconds} s.'),
    '3210': dict(card='speedloader', tags=['grows_gun'], mods={'reload_speed%': 'value'}, value=lambda r: 100 - r['Ratio'], text='Your reload fills {v}% faster.'),
    # ---- Thief Master (Fox)
    '3301': dict(card='hide', tags=['stealth'], behavior='hide', value=lambda r: r['Second'], kind='skill',
                 rows={'seconds': 'Second'},
                 text='Vanish for {v} s: monsters lose you. Attacking or a skill ends it.'),
    '3302': dict(card='sudden_attack', tags=['stealth'], behavior='close_strike', value=pct_hit, scaling='DA', rows={'range': 'Range'},
                 text='From hiding, strike the enemy in front for {v} damage. Only while hidden.'),
    '3303': dict(card='strong_mind', value=lambda r: r['Comment'], held=True, text='Resist Entrancing Wink.'),
    '3304': dict(card='explosives_expert', behavior='mine', value=lambda r: r['TrapAp'] * NORMAL_HIT, scaling='DA',
                 kind='skill', rows={'range': 'Range', 'radius': 'Radius', 'count': lambda r: 3, 'seconds': lambda r: 20},
                 text='Scatter {count} small mines around the cursor, {v} damage each.'),
    '3305': dict(card='poison_pouch', mods={'pouch.poison': 'value', 'pouch.poison_seconds': 'seconds'}, value=lambda r: r['Comment'], rows={'seconds': 'Seconds'},
                 text='Pouch of Pain poisons what it hits: {v}% of its damage again over {seconds} s.'),
    '3306': dict(card='poison_assault', tags=['thrown', 'stealth'], behavior='thrown_weapon', value=pct_hit, scaling='DA', kind='skill',
                 rows={'range': 'Range', 'seconds': 'Seconds'},
                 text='From hiding, a poisoned throw for {v} damage that keeps hurting for {seconds} s. Only while hidden.'),
    '3307': dict(card='exploit_weakness', behavior='close_strike', value=pct_hit, scaling='AP', rows={'range': 'Range'},
                 text='Strike through any defence for {v} damage.'),
    # ---- Scientist (Lion)
    '3501': dict(card='berserk', tags=['gun'], behavior='gun_spray', value=gun_pct, scaling='GUN',
                 rows={'radius': 'Radius', 'targets': 'MonNum'},
                 text='Shoot every enemy around you like crazy: up to {targets}, {v}% of a gun shot each.'),
    '3502': dict(card='revealing_eye', mods={'reveal_radius': 'value'}, value=lambda r: r['Radius'],
                 text='Hiding monsters within {v} can\'t escape your sight.'),
    '3503': dict(card='gun_overdrive', tags=['grows_gun'], mods={'gun_AP%': 'value'}, value=lambda r: r['Comment'] - 100, text='Your gun\'s Gun AP is {v}% higher.'),
    '3504': dict(card='sharp_sense', tags=['grows_gun'], upgrades='3205', value=lambda r: r['Comment'] - 100,
                 text='Overcharged shots deal {v}% more damage on top of a mastered Keen Sense.'),
    '3505': dict(card='bunker', behavior='bunker', value=lambda r: r['Comment'], kind='skill',
                 rows={'seconds': 'Seconds'},
                 text='Dig in behind a bunker for {seconds} s: it takes the hits ({v}% of your max HP), and your shots hit harder.'),
    '3506': dict(card='bunker_release', value=lambda r: 10, kind='skill', behavior='bunker',
                 text='Cut your bunker\'s time short by 10 s.'),
}

JOBS = {
    'archeologist': ['30'], 'engineer': ['30'],
    'explorer': ['31'], 'inventor': ['32'],
    'thief_master': ['33'], 'scientist': ['35'],
    # The hybrids learn the other 2nd job's skills instead of new ones.
    'hunter_lord': ['32'], 'cyber_hunter': ['31'],
}


def main():
    # Overcharge is ours (data/skills/sense/overcharge.tres): the gun's power
    # gauge, which the original gives every gun, as a talent.
    build(SPEC, 'sense', JOBS, starters={'archeologist': 'shuriken_master', 'engineer': 'gun_carrier'},
          extra_cards={'archeologist': ['overcharge'], 'engineer': ['overcharge']})


if __name__ == '__main__':
    main()
