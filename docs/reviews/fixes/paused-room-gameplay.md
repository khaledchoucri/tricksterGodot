# Room gameplay timers respect pause

Against main `0f641ab`. SceneTree.create_timer defaults to processing during
pause. Spawns, wave transitions and queued room rewards could therefore advance
behind menus. Five timers now use `process_always=false, process_in_physics=true`.
Two private Game helpers separate the existing delayed encounter/reward handoffs
from asset-dependent setup, without changing their call order or reward rules.

## Timer inventory

All `create_timer` sites under scripts/, excluding boss scripts and
scripts/skills/skill.gd (separately under review). Locations refer to main's
functions, since helper extraction shifts line numbers.

| Site | Decision and reason |
| --- | --- |
| Room.spawn_with_warning, stagger delay | Change: creates warning/spawn work. |
| Room.spawn_with_warning, 0.6 s warning | Change: spawns monster and decrements pending. |
| Room._on_enemy_died, 1.0 s wave delay | Change: starts next wave or emits cleared. |
| Game._load_room, 0.9 s intro | Change via _start_fight_after_intro: enters FIGHT and starts encounter. |
| Game._on_room_cleared, 0.6 s | Change via _queue_room_rewards: queues rewards, generates offers and consumes reward RNG. |
| Game._refine, 0.5 s | Keep: refine cost/roll/result already applied before timer; delay only reveals result and reopens the existing modal UI. |
| Game._on_player_died, 1.2 s | Keep: banking already finished; connection-loss/result presentation. |
| Game._win, 2.0 s | Keep: outcome already settled; proceeds through result/loot UI flow. Item choice and overflow remain modal UI, not ongoing combat. |
| Game._on_hitstop, duration | Keep: explicitly real-time hit-stop release must restore time scale, including while paused. |
| Hub._welcome, 1.2 s | Keep: welcome/dialogue flow; hub untouched. |
| DrillPanel._strike, 0.6 s | Keep: combat is intentionally paused during this modal minigame. Emits its UI completion; Game explicitly unpauses before _dug applies rewards. Pausing this timer would deadlock completion. |
| MagicFlight._finish, trail_life | Keep: hit callback already fired before waiting; remaining timer only disposes cosmetic trail. |
| tools/art_lab, 0.6 s | Keep: screenshot scheduling only; tool untouched. |

No boss, skill, hub UI, art/tool, generated-data or reward-balance changes.
No new policy for effects surviving death, room replacement or scene teardown.
The existing room-change guard on queued rewards remains. This fix does not
move immediate healing/banking to later in their existing presentation sequence.

## Focused checks

```
godot --headless --fixed-fps 60 --path . res://tests/combat/room_pause.tscn
```

14 checks pass under available Godot 4.6.3 (target 4.7.2), no SCRIPT ERROR. Actual
Room warning and death handlers run with only spawn/next-wave endpoints captured.
Actual Game delayed helpers run on a tree-attached behavior host, bypassing
asset-dependent ready/HUD setup; only encounter/reward endpoints are captured.
Checks cover pause-before-start, a mid-warning pause, remaining time, pending
accounting, once-only completion, wave advancement, encounter and reward queuing.

Restoring only the five original timer argument lists, retaining the helpers,
yields 8 assertion failures and exit 1 without SCRIPT ERROR: paused stagger,
warning, mid-warning, remaining warning time, wave advancement/pacing, encounter
startup and reward generation. Fixed and counterfactual logs were inspected.

The async fixture runs through core only at the end of the full runner, after
all other sections and explicit game disposal. It never advances a later
section's clock or lets the old game share its temporary Run.route. Standalone
runs construct no game. It restores the replaced route, seed/state, tree pause
and engine time scale. Observation timers intentionally process while paused.
Existing shutdown ObjectDB/resource warnings remain.

Full smoke and visuals were not run: original runtime assets are absent. Target
Godot 4.7.2, real encounter/reward UI integration and full-run teardown are unverified.
