# Trickster: Sunlit Impact — visual direction v0.1

**A direct Trickster Online fan remake. PC combat slice first; persistent online world later.**

Working art-direction title only. The user selected a direct fan remake, not an original replacement setting. This is a proposed direction and an executable commissioning package, not an approved model sheet or finished asset library. No game implementation is included.

## The creative proposition

**Keep the joy of coming home to Trickster; make every action feel deliberately drawn.**

A bright, welcoming island adventure with animal-associated heroes, expressive monsters, social towns, treasured equipment, companions, and the tactile pleasure of drilling. Present it through confident painterly forms, strong contour design, dramatic but controlled lighting, and sharply readable action poses. Hades informs clarity, momentum and impact. Trickster supplies the people, places, exploration, progression fantasy and emotional center.

Warmth is essential. Combat may be intense without making the world hostile or grim. A player should want to linger in town, inspect a find, recognize a familiar monster and enjoy a companion's reaction. The same visual system must support both an explosive punch and a quiet drilling session.

## What remains recognizable, what changes

| Preserve as a fan remake | Modernize in presentation | Explore in a later prototype |
|---|---|---|
| Bunny/Buffalo, Sheep/Dragon, Fox/Lion, Cat/Raccoon and their family identities | Coherent model sheets, expressive poses, legible silhouettes, material separation | Independent move/aim direction, input buffering and controller targeting |
| Coral Beach and Megalopolis as recognizable places | Deliberate composition, modular painted scenery, contemporary lighting and depth | Camera follow, occlusion fading and restrained zoom behavior |
| Drilling, finds, equipment and companion charm | Tool contact, layered discovery feedback, readable item/skill icons | Interruptible drilling, contextual interaction and discovery assistance |
| Distinct character roles and progression fantasies | Visual grammar for melee, casting, precision and protection | Skill access, dash/cancel rules and encounter coordination |
| Welcoming social spaces and expressive NPCs | Portraits, relaxed idles, emotes, accessible menus | Online crowds and remote-player effect budgets later |

Historical associations above are prior-knowledge synthesis pending reference verification. Canonical costume, map and monster specifics must come from a checked reference pack. Do not reinterpret unverified details as canon. Freshly generated fan interpretations are the planned production source; no original game asset extraction is part of this workflow. Record reference provenance and usage terms before any public distribution.

## Direction comparison

| Option | What it gains | What it risks | Decision |
|---|---|---|---|
| Faithful pixel-art enlargement | Immediate nostalgic recognition | Does little to deliver the requested new rendering and animation language | Retain as a fidelity comparison only |
| Dark, high-contrast mythic action | Strong drama and easy impact contrast | Loses Trickster's friendliness and makes every interaction feel like combat | Reject as the world-wide direction |
| Sunlit ink-and-paint adventure | Preserves charm; broad shapes support modern action and discovery | Needs disciplined value control and a proven animation pipeline | Recommended proposal |

## Five visual pillars

1. **Recognizable at a glance.** Preserve verified silhouette landmarks and character identity before adding detail. A smaller, faithful pose beats an ornate generic fantasy redesign.
2. **Painted masses, selective marks.** Broad warm/cool planes carry the form. Fine texture belongs on focal details and scenic edges, not uniformly across the screen.
3. **Quiet ground, expressive subjects.** Traversable surfaces have restrained contrast. Actor faces, hands, weapons, threats and interactables have clearer edges.
4. **Weight through posing.** Compression, planted contact, extension, recoil and recovery communicate force. Long startup delays and constant screen shake do not supply weight.
5. **Discovery deserves its own spectacle.** Drill resistance, a tiny glint, a recovered object and an expressive celebration are a distinct rhythm from hitting an enemy.

## Palette and material grammar

These hexadecimal values are initial art-direction anchors, not measured colors from either reference game. Validate them on actual assets before freezing the palette.

| Role | Anchor | Use |
|---|---|---|
| Warm ground/light | `#F3DFBC` | Sand, sunlit plaster, calm neutral UI |
| Coral | `#E98070` | Environmental warmth and selected costume accents |
| Sea teal | `#2AADB4` | Coastal water and cool environmental separation |
| Deep ink | `#233B52` | Occlusion, outlines, UI lettering and silhouettes |
| Sun gold | `#D5A64B` | Interaction and rewards, with shape-coded exceptions |
| Skill cyan | `#81D5E8` | Player ability accents, controlled area coverage |
| Hostile vermilion | `#D94C49` | Threat accents, always paired with geometry and motion |
| Friendly green | `#92B69A` | Support and ambient life; never the sole friendly signifier |

Color roles are semantic overlays, not a ban on red costumes or teal monsters. Enemy telegraphs use a clear patterned boundary and progression toward activation; friendly zones use a distinct open/segmented boundary and symbol. Test grayscale and color-vision simulations on final composites. Do not claim palette accessibility from hex values alone.

**Cloth:** large matte planes, broad fold groups, sparse seam detail. **Metal:** one decisive highlight and a restrained reflected cool edge. **Skin:** warm light, cool occlusion, simplified features at gameplay size. **Coral and rock:** chunky facets, weathered edges, clustered rather than evenly distributed detail. **Water:** broad color bands and localized foam loops; no permanently glittering full-screen noise. **Magic:** a visible core, thin readable boundary, short dissipation; preserve the underlying pose.

## Characters and creatures

Retain Trickster's human adventurers with verified animal-associated design elements. Do not turn the roster into unrelated fully anthropomorphic animals or replace recognizable costumes with generic tactical armor. Proposed gameplay proportions are around five head-heights, with hands, face and signature silhouette accents slightly emphasized; compare to canon references before approval.

Bunny is the pilot because close combat exposes the hardest problems: hand consistency, glove silhouettes, foreshortening, attack contact, recoil and target readability. The first kit uses one outfit and one verified weapon interpretation. Signature ears, hairstyle, glove mass, costume blocks and dominant-hand policy become immutable model-sheet landmarks after canon review. The concept board's light hair and new costume details are provisional, not established Bunny canon.

Present all eight characters as **concept-only comparative silhouettes** before scaling production. Preserve the four remembered families: Power (Bunny/Buffalo), Magic (Sheep/Dragon), Sense (Fox/Lion), Charm (Cat/Raccoon). Proposed motion and gear are modernization hypotheses until reviewed; an effect or tool must not quietly rewrite a class identity.

Monsters need charm before aggression. Choose actual Coral Beach enemies from verified references, then map them to readable encounter roles. Until that selection is verified, use IDs `coral_melee_candidate` and `coral_ranged_candidate`; do not present the board's invented sea creatures as original Trickster monsters. An elite must change a silhouette feature and tell, not just tint the sprite.

## Environments: recognizable places, useful kits

**Coral Beach:** preserve verified landmark, shoreline, vegetation, monster and color relationships. Build a compact exploration-to-combat-to-drilling loop rather than reproducing an entire map at once. The proposed composition has a broad sand clearing, a readable route back to safety, a quieter drilling pocket and scenic coral/palm framing. These are layout proposals until compared to map references.

**Megalopolis:** build a social mood vignette first. Verify the original architecture, palette, landmarks, signage and NPC identities before locking the kit. The concept board's cream masonry, awnings and blue ceramics are a proposed treatment, not authenticated geography. Warmth should arise through scale, activity, props and relaxed posture, not a copied generic marketplace.

**Modularity:** separate floor surfaces, transition masks, shoreline, cliff bases, cliff caps, collision boundaries, tall occluders, foreground canopy, landmarks, small scatter and interactables. A complete painted scene cannot substitute for a reusable map kit. Tiles need verified adjacency rules; freestanding props need ground anchors and footprints. Do not generate perspective into a kit that will be repeated on a parallel grid.

**Later regions:** concept matrices only, selected after canon verification. For each, capture climate, architecture, dominant material, creature ecology, town/field relationship, drilling character, day/night variation and contrast strategy. Avoid commissioning every original biome before the first kit passes.

## Camera and scale — proposed calibration contract

Choose a **2:1 dimetric game-art convention**, commonly called isometric in 2D games. Do not claim it is mathematically true isometric. Parallel ground vectors are `(64,32)` and `(-64,32)` at native zoom; one reference diamond is 128 × 64 screen/world pixels. Orthogonal world axes are projected consistently. Actors stay upright in screen space, with the approved elevated view visible on top surfaces. No perspective convergence.

Pilot viewport: 1920 × 1080, with 1280 × 720 readability comparisons. One source actor frame: 512 × 512 RGBA, immutable foot origin `(256,420)`, proposed standing body height 320 source pixels, measured from the ground/foot anchor to the anatomical crown of the skull in the neutral pose, excluding ears, hair/headgear extensions and weapons. Native display scale 0.45 makes that body 144 screen pixels high; the full canvas becomes 230.4 pixels. This is **not** a rule to scale the entire canvas to 144px. Ears and weapon extensions must fit within the safe frame; enlarge the entire actor-family canvas and revise the contract if they do not. Do not resize individual frames to fit.

Eight view IDs are screen-space compass directions `e, se, s, sw, w, nw, n, ne` (screen x right, y down). Screen south faces toward the bottom edge. Simulation move vectors and aim vectors remain continuous; the visual direction map is a separate adapter. Qualify strafe/backpedal or explicit turn handling when aim and travel differ. Future movement normalizes in the chosen world metric, not arbitrary projected screen distance. Ground pivot is at the planted foot midpoint; motion of a jumping body uses an offset above a stable ground anchor.

These targets must be calibrated in a later Godot diagnostic scene. The generated concept board does not pass this projection contract. It is an illustration of mood and composition. If proportions, view elevation or grid are changed at the pilot, update all dependent briefs and version the contract before bulk generation.

## Light, shadows and depth

Start with broad upper-left painted light, restrained cool occlusion and **separate ground/contact shadows**. Avoid strong baked cast shadows that rotate with a sprite. Separate floor, actor, canopy and effects layers. Sort upright subjects from their ground anchors, not their image centers; split tall objects and define occlusion behavior where needed.

Dynamic lighting is optional enhancement, not a dependency for the first painted look. Test one normal-mapped prop against a painted-only version before commissioning normal maps. Image brightness is not physical height: automated normal maps can emboss painted highlights or reverse form. Match normal-map conventions in an engine test. VFX emission should not make ordinary enemies unreadable or flatten the scene.

## Motion and effects language

| Moment | Shape and motion | Restraint |
|---|---|---|
| Bunny movement | Clear weight transfer, readable footfalls, secondary ear/hair follow-through | No costume boiling, hovering feet or stretched rubber limbs |
| Basic punch | Compact load, decisive extension, thin directional arc, brief contact flash, readable recoil | No giant explosion hiding which target was hit |
| Enemy windup | Body tell plus anchored wedge/ring/lane that progresses toward activation | Do not depend on red alone or show a damaging boundary larger than the real threat |
| Evade | Compressed launch, short silhouette trail, grounded landing | Invulnerability is a gameplay decision, not inferred from transparency |
| Drilling | Tool planted, stable shaft contact, rhythmic vibration, localized debris | Do not turn every ordinary find into an ultimate-skill burst |
| Rare discovery | Distinct reveal silhouette, short upward flourish, concise reward focus | Keep loot and companion effects below imminent hostile tells |
| Social emote | Readable head/hand shape and a small optional icon | Do not fill crowded town screens with permanent effects |

Animation is authored around anticipation, contact/active, follow-through, recovery and exit. Frame counts are delivery budgets; phase durations remain tunable. Simulation can run independently of illustrated playback cadence. Smears and held poses are available tools after the ordinary poses read clearly. Attack effects, dust, weapon trails, shadows, ground warnings and hit sparks must be separable.

## UI, icons and illustrated narrative

Modern HUD: compact HP/resource presentation, clear skill slots and cooldown/availability states, a contextual interaction prompt and restrained target feedback. Test keyboard/mouse and controller glyph layouts. Typography is real engine-rendered text, never text painted by an image model. Readability comes before decorative framing.

Inventory, equipment, skills, quests, dialogue, drilling results, map, shop, collection/cards, companion care, settings, accessibility and future social systems need a shared icon and panel grammar. Scope most to concept coverage now. Item icons need recognizable silhouettes at 32/48/64px, consistent lighting and meaningful rarity communicated by border/symbol as well as color. UI symbols need hover, focus, pressed, disabled, selected, error and loading states where applicable.

NPC portraits require expression coverage, consistent costume landmarks and crop-safe framing. Quest key art and loading illustrations may be richer and more cinematic than gameplay assets, but stay within the same world and source registry. Marketing art never substitutes for a sprite or modular environment.

## Presentation board review

`assets/sunlit-impact-concept.png` is one AI-generated exploratory board. It successfully proposes warm/cool separation, a quiet combat clearing, distinct environmental framing and readable action gestures. It does **not** establish canonical costumes/monsters/architecture, a consistent production camera, a stable hero across frames or game-ready animation. Hero details vary between the main scene and the pose panel; some environmental perspective is illustrative; the town is too generic to approve as Megalopolis. The next art-director pass must compare alternatives at identical gameplay scale and correct these issues through referenced edits.

Status: **exploration only; not approved; not an asset reference for batch production**. Approval requires the reference pack, comparative options, pilot and independent reviews described in the production playbook.
