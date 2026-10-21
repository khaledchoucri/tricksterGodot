#!/bin/sh
# Runs the smoke test, or some of its sections: tests/run_smoke.sh [section|character ...]
#   tests/run_smoke.sh               everything
#   tests/run_smoke.sh charm ui      the Charm line and the UI audit
#   tests/run_smoke.sh lion          the section that tests Lion (sense)
# Sections: core power magic sense elements charm talents balance ui boss systems lint.
# It runs at a fixed 60 fps: the same game time a player gets, as fast as the CPU allows, and with
# the default seed the results repeat exactly (the full suite takes under a minute).
G="${GODOT:-/c/Users/Khaled/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe}"
cd "$(dirname "$0")/.." || exit 1
sections=""
classes=""
for a in "$@"; do
	case "$a" in
		buffalo|bunny|sheep|dragon|fox|lion|cat|raccoon) classes="$classes,$a" ;;
		*) sections="$sections,$a" ;;
	esac
done
set --
[ -n "$sections" ] && set -- "$@" "only=${sections#,}"
[ -n "$classes" ] && set -- "$@" "class=${classes#,}"
if [ $# -eq 0 ]; then exec "$G" --headless --fixed-fps 60 --path . res://tests/smoke_test.tscn; fi
exec "$G" --headless --fixed-fps 60 --path . res://tests/smoke_test.tscn -- "$@"
