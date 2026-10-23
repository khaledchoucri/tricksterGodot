# Rewards from rejected hits

The gameplay audit reproduced frozen targets generating on-hit resources despite taking no
damage. Dead and spawning contacts could also reach the player's critical/legend reward rolls.
Enemy.can_take_hit() now centralizes the existing state/freeze eligibility rule. Incoming enemy
hits, player damage, combo contacts and skill contacts use it before their relevant hit work.

Rejected contacts generate no critical ore, legendary Galder or combo MP, consume no combo/
skill hit allowance, and skip hit-resolution/supplement rolls. Frozen enemies remain targetable;
Hold still allows damage. Thawing during an active combo window permits a genuine hit.
The existing accepted-critical boolean interface remains; a complete structured damage result
and independent boss absorption/retaliation policy are separate work.

Run `godot --headless --fixed-fps 60 --path . res://tests/combat/blocked_hits.tscn`.
These checks also run in the Elements smoke section. They use real player/enemy/combo/skill
handlers with inert actors, isolated run state, a fixed RNG seed and both real reward sources.
Presentation signals are blocked only during the synchronous fixture and restored afterward;
these checks do not test HUD feedback. Accepted-hit controls verify that rewards still occur.

Validation: 23 focused checks pass; unchanged production code fails 15 of them.
All 178 scripts compile. The full smoke run retains unchanged main's 10 failed assertions
and 231 script errors in this environment, where required runtime maps and fixtures are
unavailable. A full playable-run validation remains outstanding.
