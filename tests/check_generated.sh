#!/bin/sh
# Generated data must match its generator (CLAUDE.md, section 1): reruns the skill and item generators
# and fails if data/ changes, i.e. someone hand-edited a generated file or changed a generator
# without regenerating. Needs the original tables (tools/setup_assets.py) and Python.
#   tests/check_generated.sh
cd "$(dirname "$0")/.." || exit 1
if [ -f tests/baselines/RECORDING ]; then
	echo "a baseline is recording; run this afterwards"
	exit 2
fi
if ! git diff --quiet -- data/skills data/jobs data/items 2>/dev/null; then
	echo "data/skills or data/jobs has uncommitted changes; commit or revert them first"
	exit 2
fi
for g in power magic sense charm; do
	python "tools/${g}_skills.py" > /dev/null || { echo "tools/${g}_skills.py failed"; exit 1; }
done
for g in gear_items gun_items; do
	python "tools/${g}.py" > /dev/null || { echo "tools/${g}.py failed"; exit 1; }
done
if git diff --quiet -- data/skills data/jobs data/items 2>/dev/null; then
	echo "OK: generated data matches the generators"
	exit 0
fi
echo "FAILED: the generators write different data:"
git diff --stat -- data/skills data/jobs data/items 2>/dev/null
git checkout -- data/skills data/jobs data/items
exit 1
