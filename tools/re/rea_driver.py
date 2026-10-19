"""Keeps one REA MCP session (Ghidra) open on Trickster.bin and serves tool
calls through files: drop <queue>/<name>.json holding {"tool": ..., "args": {...}}
and read <queue>/<name>.out (the tool result's text). <queue>/ready appears once
the binary is analysed; <queue>/stop ends the session.

usage: python rea_driver.py <queue dir>
"""
import os as _os
import sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
import re_config  # noqa: E402
import json
import os
import subprocess
import sys
import time

QUEUE = sys.argv[1]
os.makedirs(QUEUE, exist_ok=True)
env = dict(os.environ)
env['GHIDRA_INSTALL_DIR'] = re_config.GHIDRA_INSTALL_DIR
env['JAVA_HOME'] = re_config.JAVA_HOME
env['REA_GHIDRA_STARTUP_TIMEOUT_MS'] = '3600000'
env['PATH'] = env['JAVA_HOME'] + r'\bin;' + env['PATH']

proc = subprocess.Popen(['cmd.exe', '/d', '/c', 'npx', '-y', 'rea-agents@6.7.0', 'mcp'],
                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, cwd=os.path.expanduser('~'), env=env)
_next = [0]


def rpc(method, params=None, notify=False):
    msg = {'jsonrpc': '2.0', 'method': method}
    if params is not None:
        msg['params'] = params
    if not notify:
        _next[0] += 1
        msg['id'] = _next[0]
    proc.stdin.write((json.dumps(msg) + '\n').encode())
    proc.stdin.flush()
    if notify:
        return None
    while True:
        line = proc.stdout.readline()
        if not line:
            raise RuntimeError('REA exited')
        try:
            reply = json.loads(line)
        except ValueError:
            continue
        if reply.get('id') == msg['id']:
            return reply


def call(tool, args):
    reply = rpc('tools/call', {'name': tool, 'arguments': args})
    if 'error' in reply:
        return json.dumps(reply['error'])
    return '\n'.join(c.get('text', '') for c in reply['result'].get('content', []))


rpc('initialize', {'protocolVersion': '2025-06-18', 'capabilities': {},
                   'clientInfo': {'name': 'scratch-driver', 'version': '1'}})
rpc('notifications/initialized', notify=True)
print(call('open_binary', {'path': re_config.TRICKSTER_BIN,
                           'provider_id': 'ghidra'}), flush=True)
# The first analysed call starts Ghidra's import and analysis.
print(call('search_strings', {'pattern': 'magic arrow'})[:400], flush=True)
open(os.path.join(QUEUE, 'ready'), 'w').close()

while not os.path.exists(os.path.join(QUEUE, 'stop')):
    jobs = sorted(f for f in os.listdir(QUEUE) if f.endswith('.json'))
    for job in jobs:
        path = os.path.join(QUEUE, job)
        try:
            req = json.load(open(path, encoding='utf-8'))
        except ValueError:
            continue  # still being written
        os.remove(path)
        out = call(req['tool'], req.get('args', {}))
        with open(path[:-5] + '.tmp', 'w', encoding='utf-8') as f:
            f.write(out)
        os.replace(path[:-5] + '.tmp', path[:-5] + '.out')
    time.sleep(0.5)
call('close_binary', {})
proc.terminate()
