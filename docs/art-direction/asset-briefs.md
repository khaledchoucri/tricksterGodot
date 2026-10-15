# Art commissioning briefs and coverage map

Use these content briefs with the role prompts in `production-playbook.md`. Every batch must cite the exact visual-bible, canon-reference and camera-contract versions. Current version: **proposal v0.1; no asset accepted**. Named character/place references are the user's direct-fan-remake direction. Exact likeness and enemy selection remain reference-gated.

## Scope levels

- **P0 / qualification:** minimum evidence needed to establish the direction and a working generation route. Do this before bulk production.
- **P1 / playable art slice:** one complete Bunny/Coral Beach loop, discovery and companion included, with a Megalopolis mood study rather than a playable city.
- **P2 / expansion planning:** comprehensive coverage briefs and concept matrices. Do not commission full production libraries yet.

Counts below are task-planning units (sheets, families, clips, components), not a promise of a fixed number of final PNGs. The catalog CSV enumerates the batch IDs. The accepted production inventory is created only after qualification.

## B00 — canon and reference pack (P0)

**Owner:** reference researcher under art director. **Purpose:** distinguish faithful reinterpretation from accidental replacement.

Produce separate evidence sheets for Bunny, the other seven base characters, Coral Beach, Megalopolis, drilling, class skills, pets and selected monsters. Each source entry records ID, URL/title, author/publisher if known, access date, game era/region if known, usage notes and the precise detail it supports. Preserve conflicting designs as variants; do not average them into an invented canon. Make a `retain / reinterpret / unresolved` matrix for silhouette, color blocks, gear, landmarks and mechanics.

Clear references per dependency: Bunny/Coral Beach/drilling/selected enemies and companion first. The remaining roster and Megalopolis detail can continue independently and must not block unrelated pilot work.

**Acceptance:** a knowledgeable-player fidelity reviewer can trace every asserted canonical detail to a source. Unknown fields remain unknown. Stop fidelity-sensitive final work if the required reference is missing. Generated illustrations are never canon evidence.

## B01 — comparative direction and art lock (P0)

**Owner:** art director + character/environment study workers.

Generate three deliberate treatments of the same approved Bunny stance, the same Coral Beach clearing and the same threat situation: (A) closer to original proportions with painted surfaces; (B) recommended sunlit ink-and-paint with moderately taller action silhouette; (C) more graphic shape simplification and stronger edge control. Use identical crops, camera assumptions and size. Include quiet exploration and one punch-contact moment, plus a small Megalopolis social view. The current board is an exploration in B, not an automatic winner.

Deliver 3 comparable boards, palette/material sheets, silhouette strips at 144px body height and 96px body height, and a decision record explaining identity/readability tradeoffs. Select one coherent treatment; avoid combining mutually inconsistent proportions or lighting from several boards.

**Reject:** direction approved solely from a poster; no actual-size comparison; final canon claim without B00.

## B02 — Bunny model and animation source (P0→P1)

**Owner:** CHAR for design/source; ANIM for motion pipeline. Keep one owner for each shared source model. Body-height measurements run from ground/foot anchor to anatomical skull crown, excluding ears/headgear and weapons; those extensions need extra safe canvas space.

**Design:** recognizable Bunny, one verified costume interpretation and one starting weapon/glove treatment. Deliver front/back/side and eight screen-direction views, five expressions (neutral, alert, effort, delight, disappointment), relaxed/ready silhouettes, hands/weapon attachment close-up, palette/material masks and fixed landmark diagram. Define actual hair/ear/gear shapes from B00 rather than the board's invention.

**P0 motion trial:** idle, locomotion and primary attack in south-east and north-west views first, plus east/west evidence for handedness. Include the complete approach→attack→recovery loop. These views deliberately expose both front/back anatomy and weapon mirroring issues. Qualify the route on this small set before scaling to eight directions.

**P1 action coverage:** idle; locomotion; ready/aim; primary attack (a second combo action only if the prototype needs it); one approved class-skill action; proposed evade; hurt; defeat; interaction; drilling plant/loop/resistance/abort/reveal/retrieve/celebrate. Drilling and defeat must not disappear merely because they are outside the illustrative 328-frame estimate. Resolve action-specific directional requirements explicitly: all directions, rotational VFX, shared clip or restricted interaction facing. No silent reuse.

**Deliver:** raw generation/source artifacts; layered or rigged source if the route produces them; per-frame exports; stable canvas/pivot; phase metadata; attachment transforms where needed; direction map; contact sheet; actual playback; unhidden foot-origin overlays; defect log. Fixed pivot alone does not prove planted feet: compare foot motion to intended travel speed.

**Acceptance:** stable identity in every view and clip; no changing gear, anatomy or camera; primary attack has readable load/contact/recovery; a later timing change does not require repainting all frames. Review target reach and interruption poses with design. The full P1 inventory is calculated only after B03.

## B03 — animation route qualification (P0)

**Owner:** ANIM; independent REVIEW + game design.

Try only toolchains actually available. Compare at most three routes using B02's same small action/view set: referenced frame generation, layered 2D animation, AI-created rigged 3D source rendered into 2D. Do not purchase, download or invent a new capability without checking actual availability and source/tool terms. AI-only means images and source assets are generated; agents may assemble, rig, script, pack, validate and apply controlled edits. No human drawing is assumed as a rescue step. If a route needs unavailable manual cleanup, count that as a production defect.

Record generated candidates, accepted frames, correction rounds, elapsed tool time, agent/review effort, tool cost if exposed, landmark/registration defects and source editability. Test loops, transitions, alpha, rear views, foreshortening and one contact effect. Two targeted correction rounds maximum before method/scope review. This tiny comparison chooses a route; broader Gate B then qualifies direction coverage, dodge/hit/drilling and import before full P1 production. Do not extrapolate concept-image speed to finished-animation throughput.

**Output:** scored comparison and a qualified-route decision, or an explicit capability blocker. Eight-direction references remain the target; a four-direction fallback requires a demonstrated comparison and approval. No bulk animation until this gate passes.

## B04 — Coral Beach modular environment (P0→P1)

**Owner:** ENV. **Purpose:** support exploration, combat and drilling in a recognizable place.

Generate components, not just a flattened background. Proposed kit inventory to refine after canon review: 4 quiet sand surface variants; sand/vegetation and sand/water transitions with required edges/corners; shoreline foam loops; cliff/rock bases and caps; a small palm family with trunk/canopy separation; coral clusters; 6 small scatter props; 2 large occluders; one verified landmark treatment; drilling-surface overlays in idle/active/disturbed/restored states; entrance/return-route markers. Water and shoreline transitions may use masks/meshes instead of tile combinatorics if the technical pilot demonstrates a simpler route.

Every prop declares ground anchor, visual bounds, suggested ground footprint, whether it blocks movement, whether it occludes, and intended layer. Technical integration owns actual collision/navigation resources. Provide a kit map, adjacency contact sheet, repeated-area test and three compositions: calm exploration, ordinary combat, worst-case effect overlap. Proposed slice layout: entry→clearing→drilling pocket→return edge, not a canon-accurate rebuilt map until verified.

**Acceptance:** consistent projection and scale; seam-free approved adjacency; no repeating high-contrast texture distracting from actors; player remains readable behind tall objects; clear traversable boundary; no false path painted into blocked scenery.

## B05 — Megalopolis social identity (P1 concept, P2 runtime)

**Owner:** ENV + CHAR/NPC.

Produce a verified landmark/architecture matrix, one establishing social scene and an annotated modular plan. Explore relaxed adventurer poses, shop/quest discoverability, portrait integration and crowd hierarchy. Use real UI text for signage where text must be legible; decorative sign symbols require source/usage review. Include two lighting moods only after the baseline is stable. No playable hub or full NPC population in P1.

**Acceptance:** a fidelity reviewer recognizes Megalopolis from verified features, not merely a warm generic fantasy market. Compare against the current board and identify what must change.

## B06 — enemy encounter family (P0 candidate→P1)

**Owner:** CHAR + ANIM; design supplies state semantics.

Select two **canon-verified Coral Beach monsters**, then adapt their presentation to one close-range pursuer and one ranged controller if compatible. Until selected, use role IDs, not invented names presented as canon. If the original creature cannot support the proposed role, change the role assignment rather than rewrite its identity silently.

Each enemy needs role silhouette, eight-view reference target, idle/travel/notice/windup/active/recovery/hurt/defeat and interrupted/return behavior as applicable. Exact production direction count follows qualification. Provide one signature tell, an attack footprint reference and a quiet ambient pose. Elite adaptation: new silhouette landmark and stronger/different tell, with documented deliberate departure from the original; no recolor-only elite.

**Acceptance:** players can distinguish roles and attack states at actual size, without color alone. Body tells and ground warnings agree. Death/defeat readability, loot placement and pooled-effects reuse must not leave phantom threats.

## B07 — combat VFX and threat grammar (P0→P1)

**Owner:** VFX, paired with design. **Required families:** basic punch contact/arc, movement dust, proposed evade trail/landing, one Bunny skill across phases, enemy wedge/ring/lane tests, ranged projectile head/trail/impact, hurt feedback, elite warning variant, selected/target cue.

For each, supply semantic event, world or actor attachment, phase, intended visible extent, actual threat footprint reference, layering, duration proposal, intensity tier and reduced-effects variant. Separate core information from optional ornament. A trail does not define hit range; a decorative ring is not automatically a damaging area. Keep warning boundary clear as it progresses toward contact. Resolve threat/friendly/interaction grammar in shape and movement as well as color.

**Review composites:** solo attack, player+two enemies, two simultaneous hostile warnings, player skill over ranged tell, elite plus companion and loot. Test no-color and color-vision previews. Full overlap counts and on-screen effect budgets are measured in the later prototype, not claimed now.

## B08 — drilling, finds and companion (P1)

**Owner:** CHAR/ANIM for actors, VFX for feedback, UI for result communication.

**Drill:** tool design and grip/shaft/ground-contact sheet; plant; loop; resistance; interrupt/abort; success; reveal; retrieve; celebration. Include soil/sand disturbance, debris, ordinary-find glint, rarer-find variant and a concise progress/result UI. Preserve the grounded rhythm. Do not assume the exact original minigame or reward economy without references.

**Companion:** one canon-verified pet candidate with idle/follow/arrive/look-at/affection/discovery-assist/recall concepts; direction count and loops from the qualified route. No combat powers or ownership economy inferred from the animation. Keep following position and sparkles away from player feet and hostile tells. Source reference verifies the pet before final model sheets.

**Finds:** small icon family for ordinary materials, equipment-shaped finds and one special discovery concept. Show common/uncommon/rare feedback tiers with shape/caption differences; use actual canonical terminology only after reference review. Item names and statistics stay live text.

## B09 — UI, inventory and icon system (P0 grammar→P1 minimal HUD)

**Owner:** UI; game design approves information architecture.

P1 components: player HP/resource, primary/skill/evade availability where needed, enemy health/target state, interact prompt, drill progress and result, pickup toast, pause/settings panel, input glyph placement. Specify focus/hover/pressed/disabled/selected states where meaningful. Design at 1080p and 720p with scalable typography and controller focus. Art-generated text is not a deliverable. Use an appropriately licensed real font; record its terms when selected.

P2 concepts: inventory/equipment, skills/progression, quest/dialogue, world/local map, shop, collection/card treatment if retained, companion care, cosmetics, social/party/chat/guild/trade, accessibility, reconnect/loading/error states. Online-related concepts remain future coverage, not a backend requirement. Provide one icon grammar sheet with monochrome silhouettes at 32/48/64px and full-color masters. Avoid separate agents independently inventing icon lighting or rarity semantics.

**Acceptance:** core information reads in dense combat; UI does not hide feet or encounter tells; keyboard/mouse and controller use the same status vocabulary; selected/disabled/error are clear without color alone; dynamic labels and translation have safe layout room.

## B10 — extended world and presentation coverage (P2)

These are planning families, not current production requests:

| Family | Required future brief coverage | Dependency |
|---|---|---|
| Remaining seven heroes | Verified base/progression variants, weapons, action roles, expressions, drilling/social poses, equipment feasibility | Bunny route and canonical variant decision |
| Additional enemies and bosses | Ecology, silhouette/role, phases, break/interruption, arena footprint, telegraph, defeat and rewards | Encounter grammar and VFX budgets |
| Further fields and towns | Canon matrix, materials, ground kit, transitions, landmarks, NPCs, weather, day/night, occlusion | Coral Beach modularity proof |
| NPCs and portraits | Verified identity, world sprite, expressions, dialogue crops, shop/quest affordance | Portrait/model and UI grammar |
| Gear and cosmetics | Equipped silhouette, hand/attachment contracts, directional clipping, item icon, upgrade/rarity cues | Source pipeline and gear-swap pilot |
| Quests and story art | Key art, dialogue expressions, quest-object props, loading illustrations, crop variants | Canon/story scope and composition rules |
| Social animation | Sit, greet, laugh, celebrate, trade/interaction poses; crowd priority | Shared state vocabulary and online budget later |
| Map and travel | Landmarks, map symbols, travel markers, transition/loading effects | Verified world geography and UI system |
| Accessibility variants | Reduced flash/particles/shake, stronger outlines, shape/symbol cues, UI scales | Actual playback evaluation |
| Store/marketing | Key art, capsule/banner crops, title treatment, credits and fan-project labeling | Approved identity and distribution scope |

Audio, music, voice, server architecture and game balancing are outside the art-generation briefs. Effects must leave room for later sound synchronization, but no audio assets are commissioned here.

## Cross-family acceptance packet

Each producer delivers asset manifest + full output list + reference IDs + prompts/edit history + source files/tool metadata where exposed + contact sheet + playback when temporal + actual-size composites + self-check + known defects. Independent reviewer produces evidence-based technical/art results; design owner produces gameplay-readability results; coordinator accepts or returns the batch. A failed prerequisite is visible in the registry and never replaced by a polished screenshot.
