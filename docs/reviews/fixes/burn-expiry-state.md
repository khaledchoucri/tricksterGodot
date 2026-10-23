# Burn state after expiry

The gameplay audit found that burn refreshes retained historical maximum DPS after expiry.
A burn applied at or after the previous deadline now starts with its own DPS and a fresh tick
interval. A gap between burns cannot contribute partial tick progress to the new application.

This intentionally preserves the current refresh policy while a burn is active: stronger DPS
wins, the latest application sets the deadline, and tick progress continues. Redesigning how
simultaneous burn sources stack is a separate balance decision.

Run `godot --headless --fixed-fps 60 --path . res://tests/combat/burn_expiry.tscn`.
These checks also run in the Elements smoke section. They use real hit/status handlers with
inert sprites and a controlled gameplay clock; no map or saved profile is needed.

Validation: 13 focused checks pass; the unchanged production code fails 6 of them.
All 178 scripts compile. The full smoke run retains the unchanged main baseline's 10 failed
assertions and 231 script errors in this environment, where runtime maps and fixtures are
unavailable. A full playable-run validation remains outstanding.
