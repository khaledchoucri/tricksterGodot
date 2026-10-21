"""Generate the git-ignored original_assets/ folder from a Trickster client.

usage:
  python -I tools/setup_assets.py <path to the client's Trickster folder> [<client with the full effects>]

The original skill effects (data/effect/cake.xml and cream.nri) come from the
second client when given: later clients have more of them.

Example:
  python -I tools/setup_assets.py "C:/Users/me/source/repos/trickster-client/Tricksterclient/Trickster"
"""
import json
import re
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, 'original_assets')

# Hand sockets: the character's pivot file and the section for the sword
# weapon type.
BUFFALO_SOCKETS = ('data/character/chr002.pvt', 'weapon001.nri')
# Actions the playable characters export (the punchers never draw a weapon).
ARMED_ACTIONS = ('idle,walk,run,attack,attack2,weapon_crit,hit,faint,dodge,cast,charge,throw,'
                 'guard,jump,attack_ready,drill0,combat_stance')
# The Sense characters also hold guns: their gun poses are actions of their own.
GUN_ACTIONS = ARMED_ACTIONS + ',attack_gun,combat_stance_gun'
FIST_ACTIONS = 'idle,walk,run,attack,attack2,weapon_crit,hit,faint,dodge,cast,charge,throw,guard,jump'

# Held weapons: name -> item sprite.
WEAPONS = {'long_sword': 'data/equip/weapon_ex_009.nri'}

# actor name -> (sprite file, actions to export or '' for all, hand sockets or None)
ACTORS = {
    'buffalo': ('data/character/chr002.nri', ARMED_ACTIONS, BUFFALO_SOCKETS),
    'bunny': ('data/character/chr001.nri', FIST_ACTIONS, None),
    # Job changes turn you into another character (CharacterInfo 9, 10, 17,
    # 18): Knight and Boxer at the 2nd job; at the 3rd, one body per type and
    # sex (power_m: Gladiator and Mercenary, power_f: Champion and Duelist).
    'knight': ('data/character/chr010.nri', ARMED_ACTIONS, ('data/character/chr010.pvt', 'weapon001.nri')),
    'power_m': ('data/character/chr018.nri', ARMED_ACTIONS, ('data/character/chr018.pvt', 'weapon001.nri')),
    'boxer': ('data/character/chr009.nri', FIST_ACTIONS, None),
    'power_f': ('data/character/chr017.nri', FIST_ACTIONS, None),
    # The Magic line (CharacterInfo 3, 4, 11, 12, 19, 20): Sheep becomes a
    # Bard, Dragon a Magician, then magic_f and magic_m at the 3rd job.
    'sheep': ('data/character/chr003.nri', ARMED_ACTIONS, ('data/character/chr003.pvt', 'weapon001.nri')),
    'dragon': ('data/character/chr004.nri', ARMED_ACTIONS, ('data/character/chr004.pvt', 'weapon001.nri')),
    'bard': ('data/character/chr011.nri', ARMED_ACTIONS, ('data/character/chr011.pvt', 'weapon001.nri')),
    'magician': ('data/character/chr012.nri', ARMED_ACTIONS, ('data/character/chr012.pvt', 'weapon001.nri')),
    'magic_f': ('data/character/chr019.nri', ARMED_ACTIONS, ('data/character/chr019.pvt', 'weapon001.nri')),
    'magic_m': ('data/character/chr020.nri', ARMED_ACTIONS, ('data/character/chr020.pvt', 'weapon001.nri')),
    # The Sense line (CharacterInfo 5, 6, 13, 14, 21, 22): Fox becomes an
    # Explorer, Lion an Inventor, then sense_f and sense_m at the 3rd job.
    'fox': ('data/character/chr005.nri', GUN_ACTIONS, ('data/character/chr005.pvt', 'weapon001.nri')),
    'lion': ('data/character/chr006.nri', GUN_ACTIONS, ('data/character/chr006.pvt', 'weapon001.nri')),
    'explorer': ('data/character/chr013.nri', GUN_ACTIONS, ('data/character/chr013.pvt', 'weapon001.nri')),
    'inventor': ('data/character/chr014.nri', GUN_ACTIONS, ('data/character/chr014.pvt', 'weapon001.nri')),
    'sense_f': ('data/character/chr021.nri', GUN_ACTIONS, ('data/character/chr021.pvt', 'weapon001.nri')),
    'sense_m': ('data/character/chr022.nri', GUN_ACTIONS, ('data/character/chr022.pvt', 'weapon001.nri')),
    # The Charm line (CharacterInfo 7, 8, 15, 16, 23, 24): Cat becomes an
    # Entertainer, Raccoon a Card Master, then charm_f and charm_m at the 3rd
    # job. Evolution and Metamorphosis turn them into a beast (the client's
    # ESAWildMutation loads trs001, ESAWildChange trs002).
    'cat': ('data/character/chr007.nri', ARMED_ACTIONS, ('data/character/chr007.pvt', 'weapon001.nri')),
    'raccoon': ('data/character/chr008.nri', ARMED_ACTIONS, ('data/character/chr008.pvt', 'weapon001.nri')),
    'entertainer': ('data/character/chr015.nri', ARMED_ACTIONS, ('data/character/chr015.pvt', 'weapon001.nri')),
    'card_master': ('data/character/chr016.nri', ARMED_ACTIONS, ('data/character/chr016.pvt', 'weapon001.nri')),
    'charm_f': ('data/character/chr023.nri', ARMED_ACTIONS, ('data/character/chr023.pvt', 'weapon001.nri')),
    'charm_m': ('data/character/chr024.nri', ARMED_ACTIONS, ('data/character/chr024.pvt', 'weapon001.nri')),
    'beast_evolution': ('data/character/Trs001.nri', FIST_ACTIONS, None),
    'beast_metamorphosis': ('data/character/Trs002.nri', FIST_ACTIONS, None),
    'torobbie': ('data/monster/mon249.nri', '', None),
    'bad_fury': ('data/monster/mon250.nri', '', None),
    'tottochi': ('data/monster/mon251.nri', '', None),
    'bustshell': ('data/monster/mon252.nri', '', None),
    'clione': ('data/monster/mon253.nri', '', None),
    'little_cora': ('data/monster/mon254.nri', '', None),
    'blue_penguin': ('data/monster/mon021.nri', '', None),
    'golden_mole': ('data/monster/mon103.nri', '', None),
    # Desert Beach
    'fanta_slime': ('data/monster/mon116.nri', '', None),
    'shell_trap': ('data/monster/mon117.nri', '', None),
    'field_mole': ('data/monster/mon101.nri', '', None),
    'sea_scorpion': ('data/monster/mon001.nri', '', None),
    'pineapple': ('data/monster/mon119.nri', '', None),
    'fan_lizard': ('data/monster/mon003.nri', '', None),
    'sand_demon': ('data/monster/mon109.nri', '', None),
    'cannon_shell': ('data/monster/mon005.nri', '', None),
    'basic_mummy': ('data/monster/mon153.nri', '', None),
    'tutankhamen': ('data/monster/mon163.nri', '', None),
    # Caballa Relics (Mon_Relics_Play 1-4), Tombeth and his summons (BossMonsterparamEx 2072)
    'mandragora': ('data/monster/mon012.nri', '', None),
    'stone_soldier': ('data/monster/mon013.nri', '', None),
    'mimic': ('data/monster/mon014.nri', '', None),
    'aposis': ('data/monster/mon015.nri', '', None),
    'tombeth': ('data/monster/mon138.nri', '', None),
    'chimu': ('data/monster/mon141.nri', '', None),
    'naranjo': ('data/monster/mon139.nri', '', None),
    # Echoes: other classes' characters
    'echo_bard': ('data/character/chr003.nri', 'idle,walk,run,attack,hit,faint,cast', None),
    'echo_explorer': ('data/character/chr005.nri', 'idle,walk,run,attack,hit,faint,throw', None),
    'echo_entertainer': ('data/character/chr007.nri', 'idle,walk,run,attack,hit,faint', None),
    # Megalopolis people
    'cavalier': ('data/npc/npc001.nri', '', None),
    'miranda': ('data/npc/npc003.nri', '', None),
    'stella': ('data/npc/npc222.nri', '', None),
    'copper_plate': ('data/npc/npc270.nri', '', None),
    'julio': ('data/npc/npc046.nri', '', None),
    'paul': ('data/npc/npc040.nri', '', None),
    'marx': ('data/npc/npc119.nri', '', None),
    'sabrina': ('data/npc/npc043.nri', '', None),
    'eugene': ('data/npc/npc153.nri', '', None),
    'louis': ('data/npc/npc017.nri', '', None),
    'marky': ('data/npc/npc180.nri', '', None),
}
# Dialogue portraits: name -> NPC illustration
PORTRAITS = {'cavalier': 'data/npc/npc001_illu.nri', 'miranda': 'data/npc/npc003_illu.nri',
             'julio': 'data/npc/npc046_illu.nri', 'paul': 'data/npc/npc040_illu.nri', 'marx': 'data/npc/npc119_illu.nri',
             'sabrina': 'data/npc/npc043_illu.nri', 'eugene': 'data/npc/npc153_illu.nri',
             'louis': 'data/npc/npc017_illu.nri', 'marky': 'data/npc/npc180_illu.nri',
             'stella': 'data/npc/npc222_illu.nri'}
MAPS = ['map_fd11d', 'map_fd11e', 'map_fd11f', 'map_fd11g', 'map_dg11b', 'map_sq00', 'mapf01g', 'mapf01f', 'mapf01d',
        'mapf03a', 'mapf03b', 'mapf03c', 'mapf03d', 'map_dg03e']
SOUNDS = [
    # EtcSound's etc_gun_shot, _critical, _hit and _reload (the client's GunAttack and GunProcessHandler).
    'weapon_gun_shot.wav', 'weapon_gun_critical.wav', 'weapon_gun_hit.wav', 'weapon_gun_reload.wav',
    'sachr002.wav', 'sachr002_1.wav', 'shchr002.wav', 'weapon001.wav', 'etc_miss.wav',
    'dmg_normal_a.wav', 'dmg_normal_b.wav', 'dmg_normal_c.wav', 'dmg_normal_d.wav',
    'etc_critical.wav', 'eff_energy.wav', 'eff_healing1.wav', 'etc_levelup.wav', 'etc_money.wav',
    'etc_mon_death.wav', 'etc_warp.wav', 'etc_warpzone.wav', 'etc_monq_complete.wav',
    'ui_card.wav', 'ui_btn_ok.wav', 'ui_unique_get.wav', 'guild_battlewin.wav',
    'sgmon103.wav', 'sdmon103.wav', 'samon021.wav', 'bgs_beach.wav', 'bgs_cave01.wav',
    'weapon002.wav', 'weapon003.wav', 'etc_item1.wav', 'ui_refine_proceed.wav', 'ui_refine_success.wav',
    'ui_refine_fail.wav', 'ui_compose_success.wav', 'bgs_blacksmith.wav', 'bgs_sandwind.wav',
    'bgs_pyramid_loop_evening.wav', 'bgs_forest.wav', 'snd_ui_crazydrill_boom.wav', 'ui_drillboy1.wav', 'ui_drillboy2.wav',
]
# From data/sound/skillsound.
SKILL_SOUNDS = [
    'snd_skl_common_ki.wav', 'snd_p_207_ap.wav', 'snd_p_205_ap.wav', 'snd_p_208_ht.wav', 'snd_p_206_ht.wav',
    'snd_p_305_ht.wav', 'snd_p_305_ht2.wav', 'snd_skl_p_008_sbg.wav', 'snd_p_603_ht.wav', 'snd_skl_p_015_ebg1.wav',
    'skill_throw_hit_dorw.wav',  # EtcSound's throw_hit_drow
]
MUSIC = ['coral_day.mp3', 'Boss_Monster.mp3', 'Megalopolis_Night.mp3', 'crap.mp3', 'jtrick.mp3']


def card_sounds():
    """Original sounds the generated skill cards name (their `sounds` rows)."""
    out = []
    for dirpath, _dirs, files in os.walk(os.path.join(ROOT, 'data', 'skills')):
        for f in sorted(files):
            if f.endswith('.tres'):
                m = re.search(r'^sounds = \{(.*)\}$', open(os.path.join(dirpath, f), encoding='utf-8').read(), re.M)
                for name in re.findall(r'"[a-z]+": "([^"]+)"', m.group(1)) if m else []:
                    if name not in out and name not in SOUNDS + SKILL_SOUNDS:
                        out.append(name)
    return out


def monster_ids():
    """Monster row IDs referenced by the EnemyData resources."""
    ids = []
    for region in sorted(os.listdir(os.path.join(ROOT, 'data'))):
        folder = os.path.join(ROOT, 'data', region, 'enemies')
        if not os.path.isdir(folder):
            continue
        for f in sorted(os.listdir(folder)):
            if f.endswith('.tres'):
                m = re.search(r'^monster_id = "(\d+)"', open(os.path.join(folder, f), encoding='utf-8').read(), re.M)
                if m:
                    ids.append(m.group(1))
    return ids


# Big Needle, Shuriken (Fox); Empty Card and Galders (the Charm line's throws).
THROWN_ITEMS = ['11404', '12015', '20400', '200']


def item_ids():
    """Original item IDs referenced by items, materials, wardrobe pieces and drills."""
    ids = []
    for f in sorted(os.path.join(sub, n) for sub in ('items', 'materials', 'wardrobe', 'drills')
                    if os.path.isdir(os.path.join(ROOT, 'data', sub))
                    for n in os.listdir(os.path.join(ROOT, 'data', sub))):
        if f.endswith('.tres'):
            m = re.search(r'^item_id = (\d+)', open(os.path.join(ROOT, 'data', f), encoding='utf-8').read(), re.M)
            if m:
                ids.append(m.group(1))
    # Thrown weapons Fox's throws show (Big Needle, Shuriken): no item to carry,
    # only their icon in flight.
    return ids + [i for i in THROWN_ITEMS if i not in ids]


def skill_ids():
    """Original skill IDs referenced by the card resources (generated skill
    trees and the Echoes' runes)."""
    ids = []
    for top in ('skills', 'echoes'):
        for dirpath, _dirs, files in os.walk(os.path.join(ROOT, 'data', top)):
            for f in sorted(files):
                if f.endswith('.tres'):
                    m = re.search(r'^skill_id = (\d+)', open(os.path.join(dirpath, f), encoding='utf-8').read(), re.M)
                    if m and m.group(1) not in ids:
                        ids.append(m.group(1))
    return ids


# Playable characters: palette-index sheets (outfits are dyed in game) and
# the pivot file that places worn items (hats, shields, masks) on them.
PLAYERS = {'buffalo': 'data/character/chr002.pvo', 'bunny': 'data/character/chr001.pvo',
           'knight': 'data/character/chr010.pvo', 'power_m': 'data/character/chr018.pvo',
           'boxer': 'data/character/chr009.pvo', 'power_f': 'data/character/chr017.pvo',
           'sheep': 'data/character/chr003.pvo', 'dragon': 'data/character/chr004.pvo',
           'bard': 'data/character/chr011.pvo', 'magician': 'data/character/chr012.pvo',
           'magic_f': 'data/character/chr019.pvo', 'magic_m': 'data/character/chr020.pvo',
           'fox': 'data/character/chr005.pvo', 'lion': 'data/character/chr006.pvo',
           'explorer': 'data/character/chr013.pvo', 'inventor': 'data/character/chr014.pvo',
           'sense_f': 'data/character/chr021.pvo', 'sense_m': 'data/character/chr022.pvo',
           'cat': 'data/character/chr007.pvo', 'raccoon': 'data/character/chr008.pvo',
           'entertainer': 'data/character/chr015.pvo', 'card_master': 'data/character/chr016.pvo',
           'charm_f': 'data/character/chr023.pvo', 'charm_m': 'data/character/chr024.pvo'}


def worn_sprites(client, fallback=None):
    """Sprite files of the hats, shields and wardrobe pieces the game uses.
    Also writes original_assets/equip/items.json: item id -> sprite name.
    A sprite this client lacks (gun002) is taken from `fallback`, the other
    client, when it has it."""
    sys.path.insert(0, HERE)
    from export_items import load_items
    rows = load_items(os.path.join(OUT, 'data', 'tables'))
    files = set()
    by_id = {}
    for sub in ('items', 'wardrobe'):
        folder = os.path.join(ROOT, 'data', sub)
        for f in sorted(os.listdir(folder)):
            if not f.endswith('.tres'):
                continue
            text = open(os.path.join(folder, f), encoding='utf-8').read()
            m = re.search(r'^item_id = (\d+)', text, re.M)
            slot = re.search(r'^slot = (\S+)', text, re.M)
            # Items: slot 1 hat, 2 shield, and guns (drawn as worn equipment,
            # placed by the pivot files). Wardrobe: every slot but speed.
            if not m:
                continue
            gun = re.search(r'^family = "gun"', text, re.M)
            if sub == 'items' and not gun and (not slot or slot.group(1) not in ('1', '2')):
                continue
            if sub == 'wardrobe' and slot and 'speed' in slot.group(1):
                continue
            eq = (rows.get(m.group(1)) or {}).get('EquipFileName') or ''
            if eq:
                parts = eq.replace(chr(92), '/').split('/')
                path = os.path.join(client, *parts)
                if not os.path.exists(path) and fallback and os.path.exists(os.path.join(fallback, *parts)):
                    path = os.path.join(fallback, *parts)
                if not os.path.exists(path):
                    print('  no equip sprite', eq)
                    continue
                files.add(path)
                by_id[m.group(1)] = os.path.splitext(parts[-1])[0].lower()
    os.makedirs(os.path.join(OUT, 'equip'), exist_ok=True)
    with open(os.path.join(OUT, 'equip', 'items.json'), 'w') as f:
        json.dump(by_id, f, indent=1, sort_keys=True)
    return sorted(files)


def run(*args):
    subprocess.run([sys.executable, '-I', *args], check=True)


# Original sprites the client draws without a cake (export_effects.py "tex:"):
# Mana Arrow's arrow and its afterimage, Mana Ring's ring.
SPELL_TEXTURES = ['magic arrow', 'magic arrow jan sang', 'magic ring', 'yun gi']
# Informally named cakes the early spells use (no skill number in the name).
EXTRA_CAKES = ['magic impect', 'magic ting', 'hell fire', 'hit', 'hit star ting',
               # The Sense line's: thrown hits, Rain of Knives, gun hits.
               'hit drow', 'throwing-knife', 'gun_taget',
               # Elemental attack landing (the client's 0x5c69d0, one per element).
               'element_fire', 'element_ice', 'element_wind', 'element_land', 'element_lightning',
               'element_light', 'element_dark']


def card_effects():
    """Original effects (cake names) the generated skill cards name."""
    out = set()
    for dirpath, _dirs, files in os.walk(os.path.join(ROOT, 'data', 'skills')):
        for f in files:
            if f.endswith('.tres'):
                m = re.search(r'^effects = (\{.*\})$', open(os.path.join(dirpath, f), encoding='utf-8').read(), re.M)
                if m:
                    for names in json.loads(m.group(1)).values():
                        out.update(names)
    return sorted(out)


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    client = sys.argv[1]
    effect_client = sys.argv[2] if len(sys.argv) == 3 else client
    for name, (rel, actions, sockets) in ACTORS.items():
        args = [os.path.join(HERE, 'export_actor.py'), os.path.join(client, rel),
                os.path.join(OUT, 'actors', name), name,
                '--res-prefix', f'res://original_assets/actors/{name}']
        if actions:
            args += ['--actions', actions]
        if sockets:
            pivot_file, section = sockets
            args += ['--pivots', os.path.join(client, pivot_file), '--pivot-section', section]
        if name in PLAYERS:
            args += ['--indexed', os.path.join(client, 'data')]
        run(*args)
    for name, rel in PORTRAITS.items():
        run(os.path.join(HERE, 'export_still.py'), os.path.join(client, rel),
            os.path.join(OUT, 'portraits', name + '.png'))
    os.makedirs(os.path.join(OUT, 'weapons'), exist_ok=True)
    for name, rel in WEAPONS.items():
        run(os.path.join(HERE, 'export_weapon.py'), os.path.join(client, rel),
            os.path.join(OUT, 'weapons', name + '.png'))
    for m in MAPS:
        run(os.path.join(HERE, 'export_map.py'), os.path.join(client, 'data', 'map', m),
            os.path.join(OUT, 'maps', m))
    ids = ','.join(monster_ids())
    run(os.path.join(HERE, 'export_data.py'), os.path.join(client, 'libconfig_eng.xml'),
        os.path.join(OUT, 'data'), '--monsters', ids)
    run(os.path.join(HERE, 'export_icons.py'), client, os.path.join(OUT, 'data', 'tables', 'SkillParam2.json'),
        os.path.join(OUT, 'icons'), ','.join(skill_ids()))
    run(os.path.join(HERE, 'export_items.py'), client, os.path.join(OUT, 'data', 'tables'), OUT, ','.join(item_ids()))
    worn = worn_sprites(client, effect_client)
    for name, pvo in PLAYERS.items():
        run(os.path.join(HERE, 'export_equip.py'), client, os.path.join(OUT, 'actors', name), name,
            os.path.join(client, pvo), *worn)
    audio = os.path.join(OUT, 'audio')
    os.makedirs(audio, exist_ok=True)
    for f in SOUNDS:
        shutil.copy2(os.path.join(client, 'data', 'sound', f), audio)
    for f in SKILL_SOUNDS:
        shutil.copy2(os.path.join(client, 'data', 'sound', 'skillsound', f), audio)
    extra = []
    for f in card_sounds():
        # Skill sounds sit in skillsound/, the generic magic effects one level up.
        for folder in (('data', 'sound', 'skillsound'), ('data', 'sound')):
            src = os.path.join(client, *folder, f)
            if os.path.exists(src):
                shutil.copy2(src, audio)
                extra.append(f)
                break
        else:
            print(f'audio: {f} not found in the client')
    effects = os.path.join(effect_client, 'data', 'effect')
    run(os.path.join(HERE, 'export_effects.py'), effects, os.path.join(OUT, 'effects'))
    run(os.path.join(HERE, 'export_effects.py'), effects, os.path.join(OUT, 'effects'),
        *sorted(set(card_effects()) | set(EXTRA_CAKES)), *['tex:' + t for t in SPELL_TEXTURES])
    for f in MUSIC:
        shutil.copy2(os.path.join(client, 'data', 'music', f), audio)
    run(os.path.join(HERE, 'convert_audio.py'), *[os.path.join(audio, f) for f in SOUNDS + SKILL_SOUNDS + extra])
    print(f'audio: {len(SOUNDS) + len(SKILL_SOUNDS) + len(extra)} sounds, {len(MUSIC)} music tracks')


if __name__ == '__main__':
    main()
