"""usage: python rq.py <tool> '<json args>' [max chars] — one REA call through the driver queue."""
import os as _os
import sys as _sys
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
import re_config  # noqa: E402
import json, os, sys, time, uuid
Q = os.path.join(re_config.WORK, 'reaq')
name = uuid.uuid4().hex[:8]
tmp = os.path.join(Q, name + '.part')
with open(tmp, 'w', encoding='utf-8') as f:
    json.dump({'tool': sys.argv[1], 'args': json.loads(sys.argv[2]) if len(sys.argv) > 2 else {}}, f)
os.replace(tmp, os.path.join(Q, name + '.json'))
out = os.path.join(Q, name + '.out')
while not os.path.exists(out):
    time.sleep(0.3)
text = open(out, encoding='utf-8').read()
os.remove(out)
limit = int(sys.argv[3]) if len(sys.argv) > 3 else 20000
try:
    d = json.loads(text)
    body = d.get('raw_result', d.get('normalized_result', d)) if isinstance(d, dict) else d
    text = body if isinstance(body, str) else json.dumps(body, indent=1)
except ValueError:
    pass
print(text[:limit])
