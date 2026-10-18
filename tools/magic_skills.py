"""Generate the Magic line's skill cards (Sheep and Dragon) from the original
skill tables. The rules for reading them are in skill_trees.py; this file
lists each skill: its card id, the behavior that performs it, its main
number and the extra table rows it needs.

usage: python -I tools/magic_skills.py   (from the project root)

Line-specific readings:
- Mana Ring, Mana Storm and Mana Ring Booster have a flat power in the
  original ("most effective in the level range of 20~50"), the rest an
  attack %. Flat power is divided by FLAT_POWER so that Mana Ring Lv 1 hits
  each target as hard as Mana Arrow Lv 1.
- Bottle of Mana's extra MP is compressed like MP costs.
- Invincible Casting is innate for mages here, and Basic Healing, Med. Cure
  and Withering Disease have nothing to act on yet (no player ailments, no
  monster regeneration): they're generated but held back from the trees.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from skill_trees import NORMAL_HIT, build, pct_hit  # noqa: E402

FLAT_POWER = 400.0 / 230.0


def flat(r):
    return r['Comment'] / FLAT_POWER / 100.0 * NORMAL_HIT


def mp_like(x):
    return 20 * (max(x, 1) / 32.0) ** 0.4


SEALS = {  # seal -> the two it shuts out (the descriptions)
    '2102': ['2106', '2108'],  # Water: fire, earth
    '2104': ['2110', '2108'],  # Thunder: wind, earth
    '2106': ['2102', '2110'],  # Fire: water, wind
    '2108': ['2104', '2102'],  # Earth: thunder, water
    '2110': ['2104', '2106'],  # Wind: thunder, fire
    '2202': ['2204'], '2204': ['2202'],  # the Pacts
}


def seal(card, name, element):
    return dict(card=card, name=name, value=lambda r: 0, kind='talent',
                text=f'A pact with {element}: its magic can be learned. Two other elements are closed to you for good.')


def shield(card, element):
    return dict(card=card, value=lambda r: r['Value'],
                text=f'{element} resistance +{{v}}%: {element.lower()} monsters hurt you less.')


def blessing(card, spirit, element, shield_id):
    return dict(card=card, upgrades=shield_id, value=pct_hit, scaling='MA',
                text=f'{spirit} guards your {element} Shield: a monster that hits you takes {{v}} {element.lower()} damage back. Keeps the Shield\'s resistance.')


def domain(card, debuffed):
    return dict(card=card, behavior='spell_field', value=lambda r: 0,
                rows={'range': 'Range', 'radius': 'Radius', 'seconds': 'Seconds', 'resist': 'Comment'},
                text=f'Mark the ground for {{seconds}} s: monsters in it lose {{resist}}% {debuffed} resistance.')


SPEC = {
    # ---- 1st job: Librarian (Sheep) and Shaman (Dragon)
    # Mana Arrow's arrow and Mana Ring's ring are original sprites the client
    # draws itself (magic_bolt.gd, mana_ring.gd); their hits are the informally
    # named "magic impect" cake.
    '2001': dict(card='mana_arrow', behavior='magic_bolt', value=pct_hit, scaling='MA', rows={'range': 'Range'},
                 effects={'ht': ['magic impect']},
                 text='A mana arrow at the enemy you aim at for {v} damage. Dragon\'s basic attack.'),
    '2002': dict(card='invincible_casting', value=lambda r: 0, held=True,
                 text='Hits can\'t interrupt your casting (innate for mages).'),
    '2003': dict(card='aura_of_mana', value=lambda r: r['Comment'], text='MP regeneration +{v}%.'),
    '2004': dict(card='bottle_of_mana', value=lambda r: mp_like(r['MP']), text='+{v} max MP.'),
    '2005': dict(card='cure', behavior='spell_heal', value=lambda r: r['Comment'], scaling='MA',
                 text='Recover {v}% of your max HP.'),
    '2006': dict(card='mist_of_mana', value=lambda r: r['Comment'], text='+{v}% MA.'),
    '2007': dict(card='arrow_rush', value=lambda r: r['Count'], rows={'ratio': lambda r: r['Ratio'] * 100},
                 text='Mana Arrow looses {v} arrows at once; each extra one hits for {ratio}%.'),
    '2008': dict(card='mana_ring', behavior='mana_ring', value=flat, scaling='MA', rows={'range': 'Range', 'radius': 'Radius'},
                 effects={'ht': ['magic impect']},
                 text='Three mana rings fly to the enemy you aim at and burst around it: {v} damage to everything caught. Sheep\'s basic attack.'),
    '2009': dict(card='mana_storm', behavior='spell_burst', value=flat, scaling='MA', rows={'range': 'Range', 'radius': 'Radius'},
                 text='A mana storm gathers on the enemies around the cursor for {v} damage.'),
    '2010': dict(card='mana_web', behavior='spell_debuff', value=lambda r: r['Comment'] * 8, scaling='MA',
                 rows={'range': 'Range', 'seconds': 'Seconds', 'radius': lambda r: 50}, kind='skill',
                 text='Cover the enemies at the cursor in a mana web: {v}% slower for {seconds} s.'),
    '2011': dict(card='rust', behavior='spell_debuff', value=lambda r: r['Comment'], scaling='MA',
                 rows={'range': 'Range', 'seconds': 'Seconds', 'radius': lambda r: 50}, kind='skill',
                 text='A rusting fog on the enemies at the cursor: they deal {v}% less damage for {seconds} s.'),
    '2012': dict(card='mana_ring_booster', value=flat, text='Mana Ring hits {v} harder.'),
    '2013': dict(card='mana_shield', value=lambda r: r['Comment'], text='+{v}% MD.'),
    # ---- Bard (Sheep)
    '2101': dict(card='bolster_ballad', value=lambda r: r['Comment'], text='Spells cost {v}% less MP.'),
    '2102': seal('seal_of_water', 'Seal of Water', 'water'),
    '2103': dict(card='drip_bomb', behavior='spell_burst', value=pct_hit, scaling='MA', rows={'range': 'Range', 'radius': lambda r: 70},
                 text='A cannonball of water bursts on the enemies at the cursor for {v} damage.'),
    '2104': seal('seal_of_thunder', 'Seal of Thunder', 'thunder'),
    '2105': dict(card='electro_attack', behavior='spell_chain', value=pct_hit, scaling='MA',
                 rows={'range': 'Range', 'targets': 'KillNum', 'radius': 'Radius'},
                 text='A bolt strikes the enemy you aim at and sparks on to others (up to {targets}) for {v} damage.'),
    '2106': seal('seal_of_fire', 'Seal of Fire', 'fire'),
    '2107': dict(card='whirlwind_blaze', behavior='spell_burst', value=pct_hit, scaling='MA', rows={'range': 'Range', 'radius': lambda r: 60},
                 text='Flames whirl around the enemy at the cursor for {v} damage.'),
    '2108': seal('seal_of_earth', 'Seal of Earth', 'earth'),
    '2109': dict(card='cleaving_terra', name='Cleaving Terra', behavior='spell_fissure', value=pct_hit, scaling='MA',
                 rows={'range': 'Range', 'radius': 'Radius'},
                 text='A fissure runs along the ground toward the cursor, hitting everything on it for {v} damage.'),
    '2110': seal('seal_of_wind', 'Seal of Wind', 'wind'),
    '2111': dict(card='wind_blade', behavior='spell_nova', value=pct_hit, scaling='MA', rows={'radius': 'Radius', 'targets': 'KillNum'},
                 text='Vacuum winds cut the enemies nearest you (up to {targets}) for {v} damage.'),
    '2112': dict(card='water_web', value=lambda r: r['Comment'] / 100 * 8, rows={'seconds': 'Seconds'},
                 text='Drip Bomb leaves its targets {v}% slower for {seconds} s.'),
    '2113': dict(card='electroshock', value=lambda r: r['Seconds'],
                 text='Electro Attack immobilizes what it strikes for {v} s.'),
    '2114': dict(card='incinerate', behavior='spell_burst', value=pct_hit, scaling='MA', rows={'range': 'Range', 'radius': 'Radius'},
                 text='A fiery explosion at the cursor burns everything around it for {v} damage.'),
    '2115': dict(card='summon_boulder', behavior='spell_burst', value=pct_hit, scaling='MA',
                 rows={'range': 'Range', 'radius': 'Radius', 'targets': lambda r: 3},
                 text='A giant boulder crashes down at the cursor on up to {targets} enemies for {v} damage.'),
    '2116': dict(card='whirlwind', behavior='spell_field', value=pct_hit, scaling='MA',
                 rows={'range': 'Range', 'radius': 'Radius', 'seconds': 'Seconds', 'targets': 'KillNum', 'still': lambda r: 1},
                 text='Tornados rage at the cursor for {seconds} s, cutting up to {targets} enemies for {v} damage at a time. They fade if you move.'),
    '2117': shield('water_shield', 'Water'),
    '2118': shield('thunder_shield', 'Elec'),
    '2119': shield('fire_shield', 'Fire'),
    '2120': shield('earth_shield', 'Earth'),
    '2121': shield('wind_shield', 'Wind'),
    '2122': dict(card='shard_of_the_glacier', name='Shard of the Glacier', behavior='spell_burst', value=pct_hit, scaling='MA',
                 rows={'range': 'Range', 'radius': lambda r: 50, 'chance': lambda r: r['Ratio'] * 100, 'freeze': 'Seconds'},
                 text='Ice shards fall at the cursor for {v} damage, with a {chance}% chance to freeze for {freeze} s.'),
    '2123': dict(card='tesla_field', name='Tesla Field', behavior='spell_field', value=pct_hit, scaling='MA',
                 rows={'range': 'Range', 'radius': 'Radius', 'seconds': 'Seconds', 'targets': lambda r: 5},
                 text='The ground at the cursor turns into an electric field for {seconds} s: up to {targets} enemies in it take {v} damage at a time.'),
    '2124': dict(card='phoenix_rising', name='Phoenix Rising', behavior='spell_field', value=pct_hit, scaling='MA',
                 rows={'range': 'Range', 'radius': 'Radius', 'seconds': 'Seconds', 'targets': lambda r: 3},
                 text='Fire flowers blossom around the enemy at the cursor for {seconds} s, burning up to {targets} enemies for {v} at a time.'),
    '2125': dict(card='botulism_cloud', name='Botulism Cloud', behavior='spell_debuff', value=lambda r: 100, scaling='MA',
                 rows={'range': 'Range', 'seconds': 'Seconds', 'radius': lambda r: 60},
                 text='Deadly spores at the cursor: the enemies there take twice as long to attack for {seconds} s.'),
    '2126': dict(card='razor_gale', name='Razor Gale', behavior='magic_bolt', value=pct_hit, scaling='MA', rows={'range': 'Range'},
                 text='A boomerang of wind at the enemy you aim at for {v} damage.'),
    '2127': dict(card='icey_shackles', behavior='spell_debuff', value=pct_hit, scaling='MA',
                 rows={'range': 'Range', 'seconds': 'Seconds', 'radius': lambda r: 40}, kind='skill',
                 text='Shackles of ice hold the enemy at the cursor for {seconds} s after {v} damage; while held it can\'t move, act or be hurt.'),
    '2128': dict(card='thunderbolt', behavior='spell_sky', value=lambda r: r['M_AP'] / 100.0 * NORMAL_HIT, scaling='MA',
                 rows={'range': 'Range', 'count': 'MaxCount'},
                 text='A gigantic bolt strikes the enemy you aim at {count} times for {v} damage each.'),
    '2129': dict(card='scorching_earth', behavior='spell_field', value=pct_hit, scaling='MA',
                 rows={'range': 'Range', 'radius': 'Radius', 'seconds': 'Seconds', 'targets': 'KillNum'},
                 text='The ground at the cursor burns for {seconds} s: up to {targets} enemies in it take {v} damage at a time.'),
    '2130': dict(card='deadly_fen', behavior='spell_field', value=pct_hit, scaling='MA',
                 rows={'range': 'Range', 'radius': 'Radius', 'seconds': 'Seconds', 'targets': 'KillNum', 'slow': 'SpeedDown'},
                 text='A swamp at the cursor for {seconds} s: up to {targets} enemies in it take {v} damage at a time and move {slow}% slower.'),
    '2131': dict(card='tornado_blast', behavior='spell_burst', value=pct_hit, scaling='MA',
                 rows={'range': 'Range', 'radius': 'Radius', 'targets': 'KillNum'},
                 text='A tornado focused on the cursor hits up to {targets} enemies for {v} damage.'),
    '2132': dict(card='elemental_boost', value=lambda r: r['Comment'], text='Fire, water, wind, thunder and earth damage +{v}%.'),
    # ---- Magician (Dragon)
    '2201': dict(card='hinder_snare', behavior='spell_debuff', value=lambda r: 0, scaling='MA',
                 rows={'radius': 'Radius', 'seconds': 'Seconds', 'still': lambda r: 1, 'self': lambda r: 1}, kind='skill',
                 text='Enemies around you are held in place for {seconds} s, until you move or are hit.'),
    '2202': seal('dark_pact', 'Dark Pact', 'darkness'),
    '2203': dict(card='hellfire', behavior='spell_burst', value=pct_hit, scaling='MA', rows={'range': 'Range', 'radius': lambda r: 55},
                 effects={'ht': ['hell fire']},
                 text='A blazing inferno of dark flames at the cursor for {v} damage.'),
    '2204': seal('light_pact', 'Light Pact', 'light'),
    '2205': dict(card='arrow_of_light', behavior='spell_sky', value=pct_hit, scaling='MA', rows={'range': 'Range', 'count': lambda r: 1},
                 text='A pillar of light rains down on the enemy you aim at for {v} damage.'),
    '2206': dict(card='wicked_flame', value=lambda r: r['Comment'], rows={'seconds': 'Seconds'},
                 text='Hellfire keeps burning its targets for {seconds} s: {v}% of its damage each second.'),
    '2207': dict(card='catastrophe_heal', behavior='spell_heal', value=lambda r: r['Comment'], scaling='MA',
                 rows={'luck': lambda r: 1},
                 text='In a pinch, recover {v}% of your max HP, more with luck.'),
    '2208': dict(card='dark_lance', behavior='magic_bolt', value=pct_hit, scaling='MA', rows={'range': 'Range'},
                 text='A dark lance strikes the enemy you aim at for {v} damage.'),
    '2209': dict(card='light_wave', behavior='spell_fissure', value=pct_hit, scaling='MA',
                 rows={'range': 'Range', 'radius': 'Radius', 'angle': 'Angle'},
                 text='A wave of light sweeps out toward the cursor, hitting everything in it for {v} damage.'),
    '2210': dict(card='gravity_crush', behavior='spell_nova', value=pct_hit, scaling='MA', rows={'radius': 'Radius', 'targets': 'KillNum'},
                 text='Gravity crushes the enemies around you (up to {targets}) for {v} damage.'),
    '2211': dict(card='basic_healing', behavior='spell_heal', value=lambda r: 0, held=True,
                 text='Cures ailments from 1st-job magic.'),
    '2212': dict(card='dark_barrier', value=lambda r: r['Value'], rows={'reflect': lambda r: r['ReflexRatio'] * 100},
                 text='Dark resistance +{v}%, and {reflect}% of the physical damage you take is turned back on the attacker.'),
    '2213': dict(card='light_shield', value=lambda r: r['Value'], rows={'guard': 'Comment'},
                 text='Light resistance +{v}%, DP and MD +{guard}%.'),
    '2214': dict(card='radiant_strike', behavior='spell_nova', value=pct_hit, scaling='MA', rows={'radius': 'Radius', 'targets': lambda r: 99},
                 text='Light floods the ground around you: every enemy in it takes {v} damage.'),
    '2215': dict(card='dark_distractor', name='Dark Distractor', behavior='spell_debuff', value=lambda r: r['DownValue'], scaling='MA',
                 rows={'range': 'Range', 'seconds': 'Seconds', 'radius': lambda r: 50},
                 text='An invisible distractor pesters the enemies at the cursor: {v}% slower for {seconds} s.'),
    '2216': dict(card='hearts_grace', name="Heart's Grace", behavior='spell_heal', value=lambda r: r['Comment'], scaling='MA',
                 text='A strong light heals you for {v}% of your max HP.'),
    '2217': dict(card='withering_disease', value=lambda r: r['Seconds'], held=True,
                 text='Gravity Crush stops its targets regenerating for {v} s.'),
    '2218': dict(card='shield_of_heaven', value=lambda r: r['Ratio'] * 100, rows={'recover': 'RecoverySec', 'cooldown': 'CoolTime'},
                 text='A holy barrier absorbs damage up to {v}% of your MA. Broken, it returns {cooldown} s later.'),
    '2219': dict(card='blood_testament', value=lambda r: r['Comment'], rows={'hp': lambda r: r['HPRatio']},
                 text='+{v}% MA, but every spell costs {hp}% of your max HP.'),
    '2220': dict(card='oath_of_light', value=lambda r: r['Comment'], text='Recover {v}% of your max HP every 10 s.'),
    '2221': dict(card='revival', value=lambda r: r['fHPRestoreRatio'] * 100, kind='talent', rows={'cooldown': 'CoolTime'},
                 text='If you fall, light revives you with {v}% HP (once every {cooldown} s).'),
    # ---- Soul Master (Sheep)
    '2301': dict(card='aqua_bomb', behavior='spell_burst', value=pct_hit, scaling='MA', rows={'range': 'Range', 'radius': lambda r: 70},
                 text='The air\'s moisture crashes down on the enemies at the cursor for {v} damage.'),
    '2302': dict(card='staff_of_thunder', behavior='spell_nova', value=pct_hit, scaling='MA', rows={'radius': 'Radius', 'targets': lambda r: 99},
                 text='Thunder from the sky strikes every enemy around you for {v} damage.'),
    '2303': dict(card='dragon_storm', behavior='spell_burst', value=pct_hit, scaling='MA', rows={'range': 'Range', 'radius': lambda r: 80},
                 text='A dragon of flame rises at the cursor for {v} damage.'),
    '2304': dict(card='earthquake', behavior='spell_burst', value=pct_hit, scaling='MA', rows={'range': 'Range', 'radius': 'Radius'},
                 text='The ground at the cursor shakes violently: {v} damage to everything on it.'),
    '2305': dict(card='raging_storm', behavior='spell_nova', value=pct_hit, scaling='MA', rows={'radius': 'Radius', 'targets': lambda r: 99},
                 text='Unstable winds tear at everything around you for {v} damage.'),
    '2306': blessing('undines_blessing', 'Undine', 'Water', '2117'),
    '2307': blessing('raions_blessing', 'Raion', 'Elec', '2118'),
    '2308': blessing('salamanders_blessing', 'Salamander', 'Fire', '2119'),
    '2309': blessing('gnomes_blessing', 'Gnome', 'Earth', '2120'),
    '2310': blessing('sylphs_blessing', 'Sylph', 'Wind', '2121'),
    '2311': domain('undines_garden', 'thunder'),
    '2312': domain('raions_space', 'fire'),
    '2313': domain('salamanders_territory', 'earth'),
    '2314': domain('gnomes_domain', 'wind'),
    '2315': domain('sylphs_playground', 'water'),
    '2316': dict(card='dimensional_rift', behavior='spell_debuff', value=lambda r: r['Comment'] / 100.0 * NORMAL_HIT, scaling='MA',
                 rows={'range': 'Range', 'radius': 'Radius', 'seconds': 'Seconds', 'targets': 'KillNum'}, kind='skill',
                 text='A rip into another dimension swallows up to {targets} enemies at the cursor for {seconds} s, then spits them out for {v} damage.'),
    # ---- Priest (Dragon)
    '2501': dict(card='med_cure', behavior='spell_heal', value=lambda r: 0, held=True, text='Cures beginner and medium ailments.'),
    '2502': dict(card='searing_light', behavior='spell_burst', value=pct_hit, scaling='MA', rows={'range': 'Range', 'radius': 'Radius'},
                 text='Arrows of light shower down at the cursor: {v} damage to everything under them.'),
    '2503': dict(card='celestial_strike', behavior='spell_burst', value=pct_hit, scaling='MA', rows={'range': 'Range', 'radius': 'Radius'},
                 text='A column of light rises at the cursor and strikes the monsters around it for {v} damage.'),
    '2504': dict(card='sacred_oath', value=lambda r: r['Comment'], text='Your faith adds {v}% of your max HP to every Oath of Light recovery.'),
    '2505': dict(card='refreshing_dew', value=lambda r: r['Comment'], text='Skill cooldowns {v}% shorter.'),
    # ---- Dark Lord (Dragon)
    '2701': dict(card='scythe', behavior='spell_sky', value=pct_hit, scaling='MA', rows={'range': 'Range', 'count': lambda r: 1},
                 text='The Grim Reaper swings at the enemy you aim at for {v} damage.'),
    '2702': dict(card='fear', value=lambda r: r['Second'], rows={'chance': lambda r: r['ApplyRatio'] * 100},
                 text='Scythe has a {chance}% chance to terrify: the enemy can\'t attack for {v} s.'),
    '2703': dict(card='staff_of_agony', behavior='spell_sky', value=pct_hit, scaling='MA', rows={'range': 'Range', 'count': lambda r: 1},
                 text='A staff of agony drops from the sky on the enemy you aim at for {v} damage.'),
    '2704': dict(card='dark_commando', value=lambda r: r['M_AP'] / 1000.0 * NORMAL_HIT, scaling='MA',
                 text='A dark being follows you: after each dark spell hits, it strikes the same enemy for {v} damage.'),
    '2705': dict(card='ghostly_whisper', behavior='spell_whisper', value=pct_hit, scaling='MA',
                 rows={'radius': 'Radius', 'seconds': 'Seconds', 'targets': 'KillNum'},
                 text='The enemies nearest you (up to {targets}) are haunted for {seconds} s, taking {v} damage each second. Moving or casting ends it.'),
    '2706': dict(card='dark_assimilation', value=lambda r: r['Comment'], text='Dark damage +{v}%.'),
}
for sid, others in SEALS.items():
    SPEC[sid]['excludes'] = others

JOBS = {
    'librarian': ['20'], 'shaman': ['20'],
    'bard': ['21'], 'magician': ['22'],
    'soul_master': ['23'], 'priest': ['25'], 'dark_lord': ['27'],
    # The hybrids learn the other 2nd job's skills instead of new ones.
    'witch': ['22'], 'wizard': ['21'],
}


def main():
    build(SPEC, 'magic', JOBS, starters={'librarian': 'mana_ring', 'shaman': 'mana_arrow'}, casting=True)


if __name__ == '__main__':
    main()
