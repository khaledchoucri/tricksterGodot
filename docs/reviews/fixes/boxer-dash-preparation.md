# Boxer Dash activation settings

The gameplay audit found that Boxer Dash calculated travel duration after the caster had
already started its animation and allocated invulnerability using the default 0.3 seconds.
Short dashes received excess protection; long dashes could outlast their protection.

Skill now exposes a no-op prepare() hook. SkillCaster calls it once at activation, after any
cast time and before reading animation/protection settings or calling start(). Boxer Dash
uses prepare() for target selection, travel duration and cancel timing; start() retains its
sound and ring effect. Damage, movement speed, range, costs and cooldowns are unchanged.
This branch migrates Boxer Dash only; other behaviors that finalize settings in start()
remain separate follow-up work.

Run `godot --headless --fixed-fps 60 --path . res://tests/combat/skill_preparation.tscn`.
The same checks run at the start of the Power smoke section using the real caster, a captured
animation, and inert actors. They cover 40- and 480-pixel targets, final animation/protection
and cancel timing, payment, cast delay, lifecycle order, cancellation and insufficient MP.
Fixture run state is restored synchronously before the section continues.

Validation: 19 focused checks pass; unchanged production code fails 5 of them.
All 178 scripts compile. The full smoke run retains unchanged main's 10 failed assertions
and 231 script errors in this environment, where required runtime maps and fixtures are
unavailable. A full playable-run validation remains outstanding.
