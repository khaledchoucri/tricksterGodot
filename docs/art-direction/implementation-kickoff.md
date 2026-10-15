# Copyable technical implementation kickoff

Use this prompt for a later implementation task. It is not authorization to implement during the current art-planning task.

---

You are the game-design and technical implementation lead for a **direct Trickster Online fan remake** with a modern painterly 2D isometric presentation and responsive, readable action inspired by Hades. The user selected a **PC combat slice first, online world later**. Preserve recognizable Trickster characters/locations, drilling/discovery, companion warmth and class identity. Do not replace the project with an unrelated original setting or expand immediately into MMO services.

Read the supplied art-direction package in this order: `README.md`, `visual-bible.md`, `research-and-decisions.md`, `game-design.md`, `production-playbook.md`, `asset-briefs.md`, the asset registry and any later qualification/review reports. The v0.1 package contains a concept board and plans, not production-ready assets. Current hero/place candidates are Bunny, Coral Beach and a Megalopolis social study; canonical detail verification is required. Use accepted assets only; visibly label temporary placeholders. Do not silently treat an attractive generated board as a runtime map, a model sheet or evidence of canon.

Inspect the actual repository, instructions, toolchain and existing work before changing anything. On 15 October 2026 the checkout was `/workspace/tricksterGodot`, empty/unborn, and Godot 4.6.3 was installed; recheck this rather than assuming it remains true. Use the existing checkout in its isolated task environment. Do not create a worktree unless explicitly requested. Preserve unrelated user work. Choose and document a practical Godot renderer after checking available rendering hardware; headless startup does not verify GPU rendering.

Start by auditing the available asset manifests, qualified animation route, reference provenance, camera calibration, source canvases, fixed foot origins, crop offsets, direction IDs, phase markers, filtering/mipmaps, alpha edges and texture-memory estimates. Missing canon evidence blocks final fidelity approval; missing animation capability blocks claims of production readiness. If the art gates have not passed, build a labeled diagnostic/blockout with placeholders and report those dependencies, rather than stopping independent technical preparation or pretending final art is integrated.

Build one compact representative field with:

- Responsive movement; keyboard/mouse and controller mappings; independent aim/facing where justified; explicit strafe/backpedal/turn presentation rather than sliding a forward-running sprite backward.
- Bunny primary action and one canon-reviewed skill adaptation, plus a tunable evade experiment. Maintain a canon-versus-modernization matrix for skill, weapon, evade and elite changes.
- Collision, ground-footprint navigation, feet-based sorting and a tested tall-prop occlusion policy. The provisional 2:1 dimetric ground basis is `(64,32),(-64,32)` with a 128×64 reference diamond. Normalize speed in the chosen simulation/world metric, not arbitrary projected screen length. Calibrate before fixing production exports.
- One close-range and one ranged enemy selected from verified Coral Beach references, and one deliberate elite adaptation. Implement readable notice, pursuit/reposition, windup, attack, recovery, interruption, defeat and return behavior as appropriate. Coordinate attack opportunities to avoid undifferentiated overlapping warnings.
- A drilling sequence with stable tool contact, progress/resistance, interrupt/abort, discovery/retrieve/celebrate and a return to neutral. Preserve its distinct pacing instead of reducing it to a generic loot button.
- A companion with follow, arrival, idle/emote and discovery response, safe offscreen recovery and low visual priority in combat. No pet combat economy required.
- Minimal HUD, skill status, interaction/drill feedback and pickup presentation with live text, scalable typography and controller focus.

Separate authoritative simulation and action data from animation presentation, VFX, input and UI. Emit semantic events (`anticipation`, `contact/active`, `recovery`, `exit`) for visuals; do not let sprite-frame callbacks own damage, invulnerability or network authority. Frame metadata can map visual phases, but simulation timing remains data-driven. Parameterize buffering, cancellations, dash invulnerability, aim assistance, telegraph durations, hit-stop and camera shake. These are prototype hypotheses, not measured Hades values or settled Trickster mechanics. Make reduced-effects/flash/shake settings available in the diagnostic build.

Use stable asset IDs, explicit actor states and local input-command boundaries that can later support networking. Do not implement accounts, servers, persistence, trading, guilds or multiplayer prediction until the offline slice proves its design. Future server authority will require a separate design; asset IDs alone do not make a game network-ready.

Deliver a diagnostic scene with actual-scale views, direction/facing markers, phase transitions, pivot overlays, collision/hit footprints, target-reach comparison, drilling contact and crowded effect overlap. Inspect exploration, normal combat, elite+ranged pressure, action behind tall props, interrupted drilling and companion recovery. Include screenshots/playback from actual rendering; selected stills cannot verify animation or combat feel.

Validation must exercise real state transitions, loading/import, contact timing, collision, interruption/recovery, sorting and input mapping. A zero-test run or an engine version command is insufficient. Run relevant automated state/data checks and headless import/startup, then interactive rendering/playtesting where available. Report limitations if interactive input or GPU capture is unavailable. Measure frame-time and decoded texture memory in the representative scene before claiming performance or selecting a final hardware target.

Return reproducible launch/build instructions, the playable slice or diagnostic project, test results with executed counts where applicable, rendering/playback evidence, performance observations, asset defects by ID and a concise list of design decisions still open. Do not expand to all eight playable characters, a full world, economy or MMO backend before slice acceptance. Do not disguise missing art, source access or tool capability as completed work.
