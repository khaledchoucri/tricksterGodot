# Research, assumptions and decisions

Research date: 15 October 2026. This package combines verified Godot documentation, parallel game-design/pipeline analysis, and a clearly labeled visual proposal. Historical/visual research is incomplete because the relevant external sites were blocked. It would be inaccurate to call the current package a source-verified history of Trickster or an analysis of Hades' proprietary art pipeline.

## Evidence classes

- **USER:** explicitly chosen by the user.
- **VERIFIED:** retrieved and inspected in this environment.
- **SYNTHESIS:** prior knowledge or design interpretation, not newly authenticated.
- **PROPOSAL:** a recommended new decision to test.
- **OPEN:** requires evidence, qualification or user/art-director decision before dependent production.

## User decisions

| Decision | Status | Consequence |
|---|---|---|
| Direct Trickster fan remake | USER | Retain canonical identities and names; verify likeness and places before final sheets |
| PC combat slice before online world | USER | Prove one offline loop; preserve data boundaries for later networking without building MMO infrastructure |
| 2D isometric presentation, modern art and Hades-like combat feeling | USER | Evaluate clarity, pose/response and world warmth together |
| Art, animation, effects, look/feel and briefs first | USER | No game code or bulk asset library in this phase |
| AI-generated art with subagent verification/review | USER | Require qualified generation routes and independent acceptance gates |

## Verified engine research

Official Godot documentation source was retrieved over verified HTTPS from the `godotengine/godot-docs` repository, branch `4.6`. Source snapshots are retained under `research/sources/`; `research/source-manifest.json` records URL, local file and SHA-256. A branch can change, so the local snapshot/hash is the evidence anchor. No exact repository commit was recorded. The reader-facing documentation URLs below identify the matching pages; those rendered sites were not fetched successfully.

| Source | Verified finding | Art-production implication |
|---|---|---|
| [2D sprite animation](https://docs.godotengine.org/en/4.6/tutorials/2d/2d_sprite_animation.html) | AnimatedSprite2D supports individual images/sheets; AnimationPlayer can coordinate properties and sprites | Keep frames, timing and auxiliary VFX separable; export stable phase metadata |
| [Using TileMaps](https://docs.godotengine.org/en/4.6/tutorials/2d/using_tilemaps.html) | TileMapLayer supplies layers and Y-sort origin settings | Kit needs anchors and floor/occluder separation; complete scenic paintings are insufficient |
| [Using TileSets](https://docs.godotengine.org/en/4.6/tutorials/2d/using_tilesets.html) | Isometric tile shapes, image origins, collision/navigation/occlusion layers are supported | Generate visual tiles and technical footprint metadata separately |
| [2D lights and shadows](https://docs.godotengine.org/en/4.6/tutorials/2d/2d_lights_and_shadows.html) | CanvasTexture supports diffuse, normal and specular; 2D lights and occluders are available | Painted art can use optional dynamic lighting; normal maps require a sample review |
| [Cutout animation](https://docs.godotengine.org/en/4.6/tutorials/animation/cutout_animation.html) | Documents hierarchical cutout rigs and mixed cutout/cel animation | Layered animation is a candidate route, not proof of generation quality; **source marks this article outdated** |
| [Importing images](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_images.html) | Import settings include compression, mipmaps and alpha-related processing | Freeze an import profile after scaling/edge tests; preserve clean masters |
| [CanvasItem](https://docs.godotengine.org/en/4.6/classes/class_canvasitem.html) | Y-sort is based on node Y; texture filter modes include mipmapped sampling | Place actor origins at ground anchors; test filtering at native and reduced scale |
| [TileMapLayer](https://docs.godotengine.org/en/4.6/classes/class_tilemaplayer.html) | Defines Y-sort origin and occlusion properties | Specify origins per prop/tile; visual bounds are distinct from map coordinates |
| [AnimatedSprite2D](https://docs.godotengine.org/en/4.6/classes/class_animatedsprite2d.html) | Defines animation/frame playback and sprite positioning controls | Import validation must check facing, frame order, offsets and loop behavior |
| [Overview of renderers](https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html) | Godot lists Compatibility as a starting choice for 2D without advanced rendering needs | Prototype a painted baseline first; choose advanced renderer only for demonstrated features |

Current-instance evidence from onboarding: Godot `4.6.3.stable.official.7d41c59c4` ran a temporary headless SceneTree smoke script successfully. The selected checkout is an empty/unborn repository; `ls-remote origin` returned no refs. These facts do not validate graphics rendering, animation, input feel or performance. No production asset has been imported or played in Godot during this art-planning phase.

## Blocked reference research

The following attempts returned proxy tunnel `403 Forbidden`: official Hades game page (`supergiantgames.com/games/hades/`), Hades' Steam page (`store.steampowered.com/app/1145360/Hades/`), Wikipedia's Trickster Online entry and a YouTube reference request. Direct rendered Godot docs were also blocked in the design agent; raw official GitHub documentation worked. No TLS or artifact verification was disabled. A GitHub repository search page was reachable, but it was not treated as historical evidence.

Required next reference work, before model-sheet approval:

1. **Trickster character evidence:** locate legitimate screenshots, official promotional material, manuals or well-attributed archival references for all eight base characters. Record exact source URL/title/date/version/region and what each image establishes. Mark conflicting regional/era references. Do not copy pixels into production art.
2. **Location evidence:** gather Coral Beach and Megalopolis overviews plus landmark/NPC/material close-ups. Verify which locations and enemies actually co-occur. Separate reconstructed map facts from new layout proposals.
3. **Interaction evidence:** inspect drilling, ordinary/rare finds, equipment presentation, skills, companions and social emotes. Record the emotional/mechanical traits to preserve rather than inventing exact original numerical systems.
4. **Hades observation study:** use authorized gameplay footage or a playable copy to annotate movement response, windup/contact/recovery, silhouette against environment, enemy warnings, feedback layers and quiet/active transitions. No footage or timestamps have yet been analyzed. Do not claim measured camera, frame counts or timings from Hades.
5. **Player fidelity review:** a knowledgeable Trickster player reviews the reference pack and labels each proposed deviation deliberate, acceptable or identity-breaking.

Reference access is a gate for fidelity approval, not a reason to stop conceptual planning. If these sites remain inaccessible, a later agent can use user-supplied references or approved network access. Do not label invented character details or generic town designs as verified canon.

## Design synthesis, not external facts

The remembered eight-character/four-family mapping, cheerful world, drilling focus, social warmth and animal-linked identity are SYNTHESIS. Their role here is to organize research and early design. Hades-inspired clarity, short readable action phases, assertive posing and controlled effect density are design interpretations. This package does not claim to reproduce Hades' assets, source code, exact production method, animation timing or camera.

The initial recommendation is a warm painterly palette and low-noise gameplay ground, while retaining verified Trickster identities. The generated board is a PROPOSAL. The proposed camera, dimensions, density budgets, timing ranges and acceptance thresholds are production hypotheses until the pilot confirms them.

## Decisions to resolve through evidence

| ID | Open question | Default proposal | How to close |
|---|---|---|---|
| D01 | Which canonical era/design variant anchors the remake? | Base-character recognizability first; record source variant | Compare reference pack with player review |
| D02 | Which animation route can AI tools actually deliver? | Bake-off controlled sprites vs layered rig vs rendered 3D sprites | Same hero/actions, measured consistency and export quality |
| D03 | Can eight directions meet quality/cost? | Eight reference views; qualify full animation before scaling | Pilot, actual-size playback, production throughput log |
| D04 | Exact camera and actor scale? | 2:1 dimetric grid, 144px body at 1080p | Godot calibration scene and small-screen comparison |
| D05 | Preserve very chibi proportions or use taller action silhouettes? | Optional approximately-five-head comparison, not locked anatomy | Side-by-side canon/modern pose studies at game scale |
| D06 | How much dynamic lighting improves the painted result? | Painted baseline, separate shadows, optional normal-map sample | Same-scene A/B, avoid double light and extra noise |
| D07 | Which exact Coral Beach monsters fill encounter roles? | Two canon-verified candidates plus elite adaptation | Reference check, role silhouette and tell review |
| D08 | What dash/cancel/skill-control rules preserve class identity? | Tunable prototype, no art-baked authority | Later gameplay prototype, input capture and player review |
| D09 | Future equipment/cosmetics asset multiplication? | One fixed outfit in pilot; test attachment feasibility | Weapon/gear swap sample, then full cost model |
| D10 | Public distribution and reference permissions? | Keep provenance and label fan reimagining | Confirm intended use/permissions before publishing public assets |

## Current validation boundary

Verified now: documentation retrieval, source snapshot integrity hashes, planning/package consistency checks, concept-board presence, unchanged empty checkout. Not verified now: canon accuracy, rigging tool availability, temporal coherence, tile seams, production asset import, GPU rendering/performance, combat feel, or online behavior. A later generation/implementation agent must execute the planned gates rather than interpret this document as a pass certificate.
