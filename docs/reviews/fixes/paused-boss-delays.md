# Boss delays during pause

The gameplay audit identified boss callbacks that continued while the gameplay clock was
paused. All seven scene-tree timer sites in Master Mong, Tutankhamen and Tombeth now use
pausable physics timers. Their configured delays, damage, healing and summon counts stay
the same. This complements the separate player-skill pause branch.

Covered routines: Mong's opening summon, Mana Storm and Cure; Tutankhamen's curse and
coffins; Tombeth's Power Blow and Final Blow. Existing node/death guards remain in place.
This change does not redesign encounter cancellation or post-death effect ownership.

Run `godot --headless --fixed-fps 60 --path . res://tests/combat/boss_pause.tscn`.
The same checks run before the map-dependent Boss smoke section. They execute the real
routines, including Mong's ready handler, using inert actors, captured hits/summons, and a
deterministic storm hit. They verify frozen telegraphs, projectiles, HP and attack tokens,
normal results on resume, and a pause partway through Final Blow's windup.

Validation: 16 focused checks pass; the unchanged production code fails 9 of them.
All 178 scripts compile. The full smoke run has the same 10 failed assertions and 231 script
errors as unchanged main in this environment, where runtime maps and fixtures are unavailable.
A full playable-run validation remains outstanding.
