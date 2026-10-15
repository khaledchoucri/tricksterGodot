"""Generate the git-ignored original_assets/ folder from a Trickster client.

usage:
  python -I tools/setup_assets.py <path to the client's Trickster folder>

Example:
  python -I tools/setup_assets.py "C:/Users/me/source/repos/trickster-client/Tricksterclient/Trickster"
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, 'original_assets')

# actor name -> (sprite file, actions to export or '' for all)
ACTORS = {
    'buffalo': ('data/character/chr002.nri',
                'idle,walk,run,attack,attack2,hit,faint,dodge,cast,drill0,combat_stance'),
    'torobbie': ('data/monster/mon249.nri', ''),
    'tottochi': ('data/monster/mon251.nri', ''),
    'bustshell': ('data/monster/mon252.nri', ''),
    'golden_mole': ('data/monster/mon103.nri', ''),
}
MONSTER_IDS = '2183,2185,2186,2037'


def run(*args):
    subprocess.run([sys.executable, '-I', *args], check=True)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    client = sys.argv[1]
    for name, (rel, actions) in ACTORS.items():
        args = [os.path.join(HERE, 'export_actor.py'), os.path.join(client, rel),
                os.path.join(OUT, 'actors', name), name,
                '--res-prefix', f'res://original_assets/actors/{name}']
        if actions:
            args += ['--actions', actions]
        run(*args)
    run(os.path.join(HERE, 'export_data.py'), os.path.join(client, 'libconfig_eng.xml'),
        os.path.join(OUT, 'data'), '--monsters', MONSTER_IDS)


if __name__ == '__main__':
    main()
