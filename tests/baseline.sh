#!/bin/sh
# Records a behaviour baseline, so a refactor can show it changed nothing (CLAUDE.md, section 5):
#   tests/baseline.sh record <name> [seeds]   smoke results, the progression probe, and seeded bots
#                                             for all eight characters (default 3 runs each, seeds 1..3)
#   tests/baseline.sh compare <a> <b>         diffs two recorded baselines; no output means identical
# Baselines are kept in tests/baselines/<name>/ (not committed: they're per machine).
G="${GODOT:-/c/Users/Khaled/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.." || exit 1
BASE=tests/baselines
BATCH=${BATCH:-4}  # bots at once (BATCH=8 when memory allows)
CLASSES="buffalo:power bunny:power sheep:magic dragon:magic fox:sense lion:sense cat:charm raccoon:charm"

# The lines of a bot log that describe what happened, without wall-clock noise.
bot_summary() {
	grep -E "^run [0-9]+  |^   (cards|loadout|died near|gear):|^clears |^rooms [0-9]|^region |^boss r" "$1"
}

record() {
	name=$1
	seeds=${2:-3}
	out=$BASE/$name
	rm -rf "$out"
	mkdir -p "$out/bots"
	git rev-parse --short HEAD > "$out/commit.txt"
	git status --short -- scripts tests data tools >> "$out/commit.txt"
	"$G" --headless --fixed-fps 60 --path . res://tests/smoke_test.tscn > "$out/smoke.log" 2>&1
	grep -E "^(PASS|FAIL|SKIP|OK|FAILED)" "$out/smoke.log" > "$out/smoke.txt"  # seeded: numbers included
	"$G" --headless --path . res://tests/progression_probe.tscn > "$out/probe.log" 2>&1
	grep -vE "^(Godot Engine|$)" "$out/probe.log" > "$out/probe.txt"
	n=0
	for pair in $CLASSES; do
		cls=${pair%%:*}
		"$G" --headless --fixed-fps 60 --path . res://tests/playtest.tscn -- \
			runs="$seeds" seed=1 class="$cls" build="${pair##*:}" city=full tag="_base_$cls" > "$out/bots/$cls.log" 2>&1 &
		n=$((n + 1))
		[ $((n % BATCH)) -eq 0 ] && wait  # about 300 MB a bot
	done
	wait
	for pair in $CLASSES; do
		cls=${pair%%:*}
		bot_summary "$out/bots/$cls.log" > "$out/bots/$cls.txt"
	done
	echo "recorded $out: $(grep -c ^PASS "$out/smoke.txt") smoke passes, $(grep -c ^FAIL "$out/smoke.txt") failures"
}

compare() {
	diff "$BASE/$1/smoke.txt" "$BASE/$2/smoke.txt"
	diff "$BASE/$1/probe.txt" "$BASE/$2/probe.txt"
	for pair in $CLASSES; do
		cls=${pair%%:*}
		diff "$BASE/$1/bots/$cls.txt" "$BASE/$2/bots/$cls.txt" > /dev/null || {
			echo "== bots: $cls differs"
			diff "$BASE/$1/bots/$cls.txt" "$BASE/$2/bots/$cls.txt"
		}
	done
}

case "$1" in
	record) record "$2" "$3" ;;
	compare) compare "$2" "$3" ;;
	*) sed -n '2,6p' "$0"; exit 2 ;;
esac
