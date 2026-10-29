#!/bin/sh
# Runs the smoke test, or some of its sections: tests/run_smoke.sh [section|character ...]
#   tests/run_smoke.sh               everything
#   tests/run_smoke.sh charm ui      the Charm line and the UI audit
#   tests/run_smoke.sh lion          the section that tests Lion (sense)
#   tests/run_smoke.sh sense seed=7  another seed (any key=value goes to the test as it is)
# Sections: core power magic sense elements charm talents balance ui rest art boss systems chunks lint.
# It runs at a fixed 60 fps: the same game time a player gets, as fast as the CPU allows, and with
# the default seed the results repeat exactly (the full suite takes under a minute).
G="${GODOT:-/c/Users/Khaled/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.." || exit 1
sections=""
classes=""
extra=""
for a in "$@"; do
	case "$a" in
		*=*) extra="$extra $a" ;;
		buffalo|bunny|sheep|dragon|fox|lion|cat|raccoon) classes="$classes,$a" ;;
		*) sections="$sections,$a" ;;
	esac
done
set -- $extra
[ -n "$sections" ] && set -- "$@" "only=${sections#,}"
[ -n "$classes" ] && set -- "$@" "class=${classes#,}"
# A script that fails to parse leaves the test waiting forever: give up after 3 minutes (the full
# suite takes under one).
log=$(mktemp)
if [ $# -eq 0 ]; then
	{ timeout 180 "$G" --headless --fixed-fps 60 --path . res://tests/smoke_test.tscn 2>&1; echo $? > "$log.code"; } | tee "$log"
else
	{ timeout 180 "$G" --headless --fixed-fps 60 --path . res://tests/smoke_test.tscn -- "$@" 2>&1; echo $? > "$log.code"; } | tee "$log"
fi
code=$(cat "$log.code")
# A check whose line errors never runs, so the test's own count can say OK: any script error fails.
errors=$(grep -c "SCRIPT ERROR" "$log")
rm -f "$log" "$log.code"
if [ "$errors" -gt 0 ]; then
	echo "FAILED: $errors script error(s); a check that errors never runs"
	exit 1
fi
exit "$code"
