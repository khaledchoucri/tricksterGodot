"""Generate the Charm line's skill cards (Cat and Raccoon) from the original
skill tables. The rules for reading them are in skill_trees.py; this file
lists each skill: its card id, the behaviour that performs it, its main
number and the extra table rows it needs.

usage: python -I tools/charm_skills.py   (from the project root)

Line-specific readings:
- Scaling is the server's own attack for each skill (GameServer.exe, see
  tools/re/README.md): most Charm attacks add 16 or 8 HV to AP (Volley Kick
  (AP + 16 HV), Card Strike (AP + 8 HV)), Wild Nail is HV alone, Siren Song
  HP and DP, Final Blow the HP you've lost. The expression is the card's
  `scaling`, read by Run.attack_power().
- Galder skills spend the run's Galder at a fifth of the original's price
  (drops here are a run's, not a bank's) and strike through DP as on the
  server; they also scale with HV (the user's choice: the server's Galder x
  Ratio doesn't grow with stats).
- Evolution and Metamorphosis are talents here (the user's choice; the
  original's are timed casts that drain MP and need 60% HP and MP): once
  learned you stay the beast (trs001, trs002) for the run, with the table's
  stat changes and no drain. Only the skills that beast can use work in it
  (Evolution: Beast Claw, Fatal Wound, Raging Nail, Sharp Scream, Beast's
  Instinct; Metamorphosis: Wild Nail, Heavy Hit, Card Soldier), new skills
  are offered only if they do, and the beast skills ask for their form at
  Lv 1 rather than the original's Lv 3, so a fresh beast isn't left with
  no skill. Sharp Scream also asks for Evolution, so it comes after it.
- Beast's Instinct stays a timed cast on top of Evolution (its own MP drain
  while it lasts); when it ends, Evolution doesn't.
- Held back for want of the system they act on: Team Bolster and Bodyguard
  (no party), Aura Shatter (monsters have no buffs), Super Hips (monsters
  don't crit), Warm Up (no job lists it).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from skill_trees import NORMAL_HIT, build, job_ids, load, pct_hit  # noqa: E402


def ratio_pct(r):
    """A skill whose tooltip shows Ratio (Beast Claw's AP x Ratio)."""
    return r['Ratio'] * NORMAL_HIT


SPEC = {
    # ---- Model and Teacher (shared 1st job)
    '4001': dict(card='power_blow', behavior='charm_strike', value=pct_hit, scaling='AP',
                 rows={'range': 'Range', 'ratio': 'Ratio'},
                 text='Gather your strength into a lashing blow at the enemy in front: {v} damage.'),
    '4002': dict(card='galder_thrower', behavior='card_throw', value=pct_hit, scaling='HV',
                 rows={'range': 'Range', 'galder': lambda r: 20},
                 text='Hurl {galder} Galder at the enemy you aim at: {v} damage through any defence.'),
    '4003': dict(card='dodge_master', mods={'HV%': 'value'}, value=lambda r: r['Comment'], text='+{v}% HV.'),
    '4004': dict(card='shield_all', mods={'DP%': 'value'}, value=lambda r: r['Comment'], text='+{v}% DP.'),
    '4005': dict(card='magic_meltdown', inflicts='ma', value=lambda r: r['Comment'], rows={'seconds': 'Seconds'},
                 text='Your hits break a monster\'s magic bead: its magic hits {v}% weaker for {seconds} s.'),
    '4006': dict(card='magic_def_breaker', inflicts='md', value=lambda r: r['Comment'], rows={'seconds': 'Seconds'},
                 text='Your hits strip a monster\'s magic veil: {v}% less MD for {seconds} s.'),
    '4007': dict(card='sturdy_shield', mods={'DP%': 'value'}, value=lambda r: r['Comment'], text='A shield on threads circles you: +{v}% DP.'),
    '4008': dict(card='mana_reflector', mods={'magic_damage_cut%': 'value'}, value=lambda r: r['Ratio'] * 100,
                 text='A barrier turns {v}% of each magic hit back on its caster, and you take that much less.'),
    '4009': dict(card='physical_training', mods={'HP': 'value'}, value=lambda r: r['HP'] / 10.0, text='+{v} max HP.'),
    '4010': dict(card='skunk_pouch', behavior='pouch_throw', kind='skill', value=lambda r: 0,
                 rows={'range': lambda r: r.get('Range', 80) + 40, 'radius': lambda r: 40, 'stun': 'Seconds'},
                 text='Toss a pouch of skunk stink: the enemy faints for {stun} s.'),
    '4011': dict(card='titanium_wrist', mods={'power_blow.ratio': 'value'}, value=lambda r: r['Comment'],
                 text='Power Blow strikes with {v}% more of your AP.'),
    '4012': dict(card='final_blow', behavior='charm_strike', value=pct_hit, scaling='AP+0.1LOST',
                 rows={'range': 'Range'},
                 text='Pay back every blow you\'ve taken: {v} damage, more for each HP you\'ve lost.'),
    # ---- Entertainer (Cat)
    '4101': dict(card='volley_kick', behavior='charm_strike', value=pct_hit, scaling='AP+16HV',
                 rows={'range': 'Range'},
                 text='A flexible upper kick that throws the enemy into the air: {v} damage.'),
    '4102': dict(card='galder_barrage', behavior='galder_barrage', value=pct_hit, scaling='HV',
                 rows={'range': 'Range', 'radius': 'Radius', 'galder': lambda r: 30},
                 text='Throw {galder} Galder in three directions at the cursor: {v} damage through any defence.'),
    '4104': dict(card='siren_song', behavior='charm_burst', value=pct_hit, scaling='0.1HPNOW+0.5DP',
                 rows={'range': 'Range', 'targets': 'MonNum', 'angle': 'Angle'},
                 text='Your voice hits up to {targets} enemies in front for {v} damage, more with HP and DP.'),
    '4105': dict(card='evolution', form_actor='beast_evolution', form_gains=['AP'], form_losses=['DP', 'HV', 'LK'], kind='talent', value=lambda r: (r['ApPRatio'] - 1) * 100,
                 rows={'dx': 'DxPValue', 'loss': lambda r: r['DpMRatio'] * 100},
                 text='Become a beast for the rest of the run: {v}% more AP, faster attacks, {loss}% less DP, HV and LK. '
                      'Only beast skills work in this form (Beast Claw, Fatal Wound, Raging Nail, Sharp Scream, '
                      "Beast's Instinct): your other skills stop working."),
    '4106': dict(card='beast_claw', form='evolution', behavior='charm_strike', value=pct_hit, scaling='AP', rows={'range': 'Range'},
                 requires_extra={'evolution': 1},
                 text='Beast form only: lunge at the enemy you aim at, a devastating claw for {v} damage.'),
    '4107': dict(card='fatal_wound', form='evolution', behavior='charm_strike', kind='skill', value=ratio_pct, scaling='AP',
                 rows={'range': 'Range', 'bleed': 'Comment', 'seconds': 'Seconds'}, requires_extra={'evolution': 1},
                 text='Beast form only: a deep wound for {v} damage that bleeds {bleed}% of it again over {seconds} s.'),
    '4108': dict(card='sumo_suit', mods={'damage_cut%': 'value'}, value=lambda r: r['Comment'], text='All the padding you need: you take {v}% less damage.'),
    '4109': dict(card='fist_full_of_galders', behavior='card_throw', value=pct_hit, scaling='HV',
                 rows={'range': 'Range', 'count': 'Count', 'galder': lambda r: 20},
                 text='Throw {count} fistfuls of {galder} Galder at the enemy you aim at, {v} damage each through any defence.'),
    '4110': dict(card='deadly_funk', behavior='pouch_throw', kind='skill', upgrades='4010', value=lambda r: 0,
                 rows={'range': lambda r: r['Range'] + 60, 'radius': 'Radius', 'stun': 'Seconds'},
                 text='The smelliest gym socks: everything around the cursor faints for {stun} s.'),
    # ---- Card Master (Raccoon)
    '4201': dict(card='card_strike', behavior='card_throw', value=pct_hit, scaling='AP+8HV',
                 rows={'range': 'Range', 'radius': 'Radius'},
                 text='Flick an empty card at the enemy you aim at: {v} damage, splashing those nearby.'),
    '4204': dict(card='one_pair', behavior='card_throw', value=pct_hit, scaling='AP+8HV',
                 rows={'range': 'Range', 'count': lambda r: 2},
                 text='Throw a pair of cards at one enemy, {v} damage in all, from further away than Card Strike.'),
    '4205': dict(card='impelling_rage', behavior='charm_burst', value=pct_hit, scaling='MA',
                 rows={'radius': 'Radius', 'targets': lambda r: 5},
                 text='Force your fighting spirit out: up to {targets} enemies around you are pushed back for {v} damage.'),
    '4206': dict(card='metamorphosis', form_actor='beast_metamorphosis', form_gains=['DP', 'HV'], form_losses=['AP', 'LK'], kind='talent', value=lambda r: (r['DpPRatio'] - 1) * 100,
                 rows={'dx': 'DxMValue', 'loss': lambda r: r['ApMRatio'] * 100},
                 text='Change at a cellular level for the rest of the run: {v}% more DP and HV, {loss}% less AP and LK, '
                      'slower attacks. Only beast skills work in this form (Wild Nail, Heavy Hit, Card Soldier): '
                      'your other skills stop working.'),
    '4207': dict(card='wild_nail', form='metamorphosis', behavior='charm_strike', value=pct_hit, scaling='16HV', rows={'range': 'Range'},
                 requires_extra={'metamorphosis': 1},
                 text='Beast form only: sharp nails for {v} damage, all from your HV.'),
    '4208': dict(card='flux_capacitor', behavior='transform', kind='skill', value=lambda r: r['Comment'],
                 rows={'hp': lambda r: r['HpRatio'] * 100},
                 text='Burn {hp}% of your max HP into MP: {v}% of it comes back as MP.'),
    '4209': dict(card='furious_galder_throw', behavior='card_throw', upgrades='4002', value=lambda r: pct_hit(r) / 1000,
                 scaling='HV', rows={'range': 'Range', 'galder': lambda r: 100},
                 text='Throw a wild handful of Galder (up to 1000, a fifth of it paid): {v} damage per Galder, '
                      'through any defence.'),
    '4210': dict(card='lady_luck', mods={'one_pair.cards_min': 'min', 'one_pair.cards_max': 'value'}, value=lambda r: r['MaxCard'], rows={'min': 'MinCard'},
                 text='One Pair throws {min} to {v} cards, each adding to the damage.'),
    '4211': dict(card='mass_destruction', behavior='charm_burst', value=pct_hit, scaling='AP',
                 rows={'radius': 'Radius', 'targets': 'KillNum', 'hp_left': lambda r: r['HpRemainRatio'] * 100},
                 text='Hug a huge bomb as it goes off: up to {targets} enemies around take {v} damage, and you are left '
                      'with {hp_left}% of your HP. Needs 80% HP.'),
    # ---- Primadonna (Cat)
    '4301': dict(card='entrancing_wink', inflicts='silence', value=lambda r: r['Second'],
                 text='Your hits entrance a monster: it can\'t cast magic for {v} s.'),
    '4302': dict(card='two_hit_combo', behavior='charm_strike', value=pct_hit, scaling='AP+16HV',
                 rows={'range': 'Range'},
                 text='A Power Blow into a Volley Kick, {v} damage in all, more with both skills\' levels.'),
    '4303': dict(card='raging_nail', form='evolution', behavior='charm_strike', value=pct_hit, scaling='AP+16HV',
                 rows={'range': 'Range', 'ignore': lambda r: 100 - r['DisDefenceRatio']},
                 text='Beast form only: a raging claw for {v} damage that ignores {ignore}% of the enemy\'s DP.'),
    '4304': dict(card='sharp_scream', form='beast', behavior='charm_burst', value=pct_hit, scaling='AP+16HV',
                 rows={'range': 'Range', 'radius': 'Radius', 'targets': 'Count'}, requires_extra={'evolution': 1},
                 text='Beast form only: a piercing scream hits up to {targets} enemies near you for {v} damage.'),
    '4305': dict(card='beasts_instinct', form='evolution', tags=['instinct'], behavior='transform', kind='skill', value=lambda r: (r['AP_Ratio'] - 1) * 100,
                 rows={'seconds': 'Seconds', 'dx': 'DX_Ratio', 'loss': lambda r: r['DP_Ratio'] * 100},
                 text='In Evolution: unleash the beast for {seconds} s, {v}% more AP and faster attacks, but no skills '
                      'and a steady MP drain.'),
    # ---- Gambler (Raccoon)
    '4501': dict(card='full_house', behavior='charm_burst', value=pct_hit, scaling='AP+8HV+8LK',
                 rows={'radius': 'Radius', 'targets': lambda r: 5},
                 text='Deal the cards around you: up to {targets} enemies take {v} damage, more with LK. '
                      'A bad hand turns some back on you.'),
    '4502': dict(card='power_charging', behavior='charm_burst', value=pct_hit, scaling='MA',
                 rows={'radius': 'Radius', 'targets': lambda r: 5, 'stun': lambda r: 2},
                 text='A burst of energy pushes enemies around you back for {v} damage and roots them for {stun} s.'),
    '4503': dict(card='heavy_hit', form='beast', behavior='charm_strike', value=pct_hit, scaling='AP+0.125HPNOW',
                 rows={'range': 'Range'},
                 text='Beast form only: a massive blow for {v} damage, more with your HP, that sends the enemy flying.'),
    '4504': dict(card='card_soldier', form='beast', behavior='charm_burst', value=lambda r: r['DamageRatio'] * NORMAL_HIT,
                 scaling='AP+8HV', rows={'range': 'Range', 'min': 'MinCard', 'max': 'MaxCard'},
                 requires_extra={'metamorphosis': 1},
                 text='Beast form only: summon a card soldier numbered {min} to {max} at the cursor; it strikes for '
                      '{v} damage, more the higher its number.'),
    '4505': dict(card='four_of_a_kind', behavior='charm_burst', value=lambda r: pct_hit(r) / 4, scaling='AP',
                 rows={'radius': 'Radius', 'targets': 'KillNum'},
                 text='Four cards for four enemies: {v} damage each, but only with at least four enemies around you.'),
}

# Who learns what: a 2nd job's cards (41 Entertainer, 42 Card Master) go to
# the hybrid of the other line only where the Job field lists it (Evolution
# is the Entertainer's alone).
_cards = {r['AffectionSkill']: r for r in load('Item_SkillCardParam')}


def _learns(job, prefix):
    return lambda i: i[:2] == prefix and job in job_ids(_cards[i]['Job'])


JOBS = {
    'model': ['40'], 'teacher': ['40'],
    'entertainer': ['41'], 'card_master': ['42'],
    'primadonna': ['43'], 'gambler': ['45'],
    'diva': _learns('diva', '42'), 'duke': _learns('duke', '41'),
}


def main():
    build(SPEC, 'charm', JOBS, starters={'model': 'power_blow', 'teacher': 'power_blow'})


if __name__ == '__main__':
    main()
