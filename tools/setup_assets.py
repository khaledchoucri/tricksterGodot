"""Generate the git-ignored original_assets/ folder from a Trickster client.

usage:
  python -I tools/setup_assets.py <path to the client's Trickster folder>

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

# Hand sockets for Buffalo: the character's pivot file and the section for
# the sword weapon type.
BUFFALO_SOCKETS = ('data/character/chr002.pvt', 'weapon001.nri')
# Held weapons: name -> item sprite.
WEAPONS = {'long_sword': 'data/equip/weapon_ex_009.nri'}

# actor name -> (sprite file, actions to export or '' for all, hand sockets or None)
ACTORS = {
    'buffalo': ('data/character/chr002.nri',
                'idle,walk,run,attack,attack2,weapon_crit,hit,faint,dodge,cast,charge,throw,'
                'guard,jump,attack_ready,drill0,combat_stance', BUFFALO_SOCKETS),
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
}
# Dialogue portraits: name -> NPC illustration
PORTRAITS = {'cavalier': 'data/npc/npc001_illu.nri', 'miranda': 'data/npc/npc003_illu.nri',
             'julio': 'data/npc/npc046_illu.nri', 'paul': 'data/npc/npc040_illu.nri', 'marx': 'data/npc/npc119_illu.nri',
             'sabrina': 'data/npc/npc043_illu.nri', 'eugene': 'data/npc/npc153_illu.nri',
             'stella': 'data/npc/npc222_illu.nri'}
MAPS = ['map_fd11d', 'map_fd11e', 'map_fd11f', 'map_fd11g', 'map_dg11b', 'map_sq00', 'mapf01g', 'mapf01f', 'mapf01d']
SOUNDS = [
    'sachr002.wav', 'sachr002_1.wav', 'shchr002.wav', 'weapon001.wav', 'etc_miss.wav',
    'dmg_normal_a.wav', 'dmg_normal_b.wav', 'dmg_normal_c.wav', 'dmg_normal_d.wav',
    'etc_critical.wav', 'eff_energy.wav', 'eff_healing1.wav', 'etc_levelup.wav', 'etc_money.wav',
    'etc_mon_death.wav', 'etc_warp.wav', 'etc_warpzone.wav', 'etc_monq_complete.wav',
    'ui_card.wav', 'ui_btn_ok.wav', 'ui_unique_get.wav', 'guild_battlewin.wav',
    'sgmon103.wav', 'sdmon103.wav', 'samon021.wav', 'bgs_beach.wav', 'bgs_cave01.wav',
    'weapon002.wav', 'weapon003.wav', 'etc_item1.wav', 'ui_refine_proceed.wav', 'ui_refine_success.wav',
    'ui_refine_fail.wav', 'ui_compose_success.wav', 'bgs_blacksmith.wav', 'bgs_sandwind.wav',
    'bgs_pyramid_loop_evening.wav',
]
# From data/sound/skillsound.
SKILL_SOUNDS = [
    'snd_skl_common_ki.wav', 'snd_p_207_ap.wav', 'snd_p_205_ap.wav', 'snd_p_208_ht.wav', 'snd_p_206_ht.wav',
    'snd_p_305_ht.wav', 'snd_p_305_ht2.wav', 'snd_skl_p_008_sbg.wav', 'snd_p_603_ht.wav', 'snd_skl_p_015_ebg1.wav',
]
MUSIC = ['coral_day.mp3', 'Boss_Monster.mp3', 'Megalopolis_Night.mp3', 'crap.mp3']


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


def item_ids():
    """Original item IDs referenced by items, materials and wardrobe pieces."""
    ids = []
    for f in sorted(os.path.join(sub, n) for sub in ('items', 'materials', 'wardrobe')
                    if os.path.isdir(os.path.join(ROOT, 'data', sub))
                    for n in os.listdir(os.path.join(ROOT, 'data', sub))):
        if f.endswith('.tres'):
            m = re.search(r'^item_id = (\d+)', open(os.path.join(ROOT, 'data', f), encoding='utf-8').read(), re.M)
            if m:
                ids.append(m.group(1))
    return ids


def skill_ids():
    """Original skill IDs referenced by the card resources."""
    folder = os.path.join(ROOT, 'data', 'coral_beach', 'cards')
    ids = []
    for f in sorted(os.listdir(folder)):
        if f.endswith('.tres'):
            m = re.search(r'^skill_id = (\d+)', open(os.path.join(folder, f), encoding='utf-8').read(), re.M)
            if m:
                ids.append(m.group(1))
    return ids


def run(*args):
    subprocess.run([sys.executable, '-I', *args], check=True)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    client = sys.argv[1]
    for name, (rel, actions, sockets) in ACTORS.items():
        args = [os.path.join(HERE, 'export_actor.py'), os.path.join(client, rel),
                os.path.join(OUT, 'actors', name), name,
                '--res-prefix', f'res://original_assets/actors/{name}']
        if actions:
            args += ['--actions', actions]
        if sockets:
            pivot_file, section = sockets
            args += ['--pivots', os.path.join(client, pivot_file), '--pivot-section', section]
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
    audio = os.path.join(OUT, 'audio')
    os.makedirs(audio, exist_ok=True)
    for f in SOUNDS:
        shutil.copy2(os.path.join(client, 'data', 'sound', f), audio)
    for f in SKILL_SOUNDS:
        shutil.copy2(os.path.join(client, 'data', 'sound', 'skillsound', f), audio)
    for f in MUSIC:
        shutil.copy2(os.path.join(client, 'data', 'music', f), audio)
    run(os.path.join(HERE, 'convert_audio.py'), *[os.path.join(audio, f) for f in SOUNDS + SKILL_SOUNDS])
    print(f'audio: {len(SOUNDS) + len(SKILL_SOUNDS)} sounds, {len(MUSIC)} music tracks')


if __name__ == '__main__':
    main()
