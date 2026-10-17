# Uploaded original asset inventory

The root-level uploads from `main` at `ca8bd1c` have been organized into the paths already expected by the Godot code, actor resources, pose-guide tools and art importer. This is a relocation of **382 existing tracked files**, preserving all **1,874,652 bytes** exactly. No game code or gameplay resources were edited.

```text
original_assets/
  actors/
    buffalo/                 # manifest, SpriteFrames resource, 17 action sheets
    clione/                  # manifest, SpriteFrames resource, 8 action sheets
    torobbie/                # manifest, SpriteFrames resource, 8 action sheets
  weapons/
    long_sword.png
    long_sword.json           # grip, angle and reach metadata
  pose_guides/
    buffalo/
      run/{e,se,s,sw,w,nw,n,ne}/
      hit/{se,sw,nw,ne}/
      weapon_crit/{se,sw,nw,ne}/
```

The existing `.import` descriptors moved with their images. Their `source_file` entries already identified these destinations. Actor `.tres` references also already pointed here, so no path rewriting was needed. Guide JSON identified the actor/action/direction; the original root `e/`, `se/`, etc. folders are **Buffalo run guides**, not separate actors or map assets.

[uploaded-asset-moves.json](uploaded-asset-moves.json) records every old/new path, byte size and SHA-256 so the reorganization is auditable and reversible. No duplicate file was discarded or overwritten. The old empty upload directories were removed.

## What is available

| Actor | Actions | Directional frame entries | Animations in Godot | Frames with hand sockets |
|---|---:|---:|---:|---:|
| Buffalo | 17 | 410 | 74 | 292 |
| Clione | 8 | 266 | 38 | 0 |
| Torobbie | 8 | 226 | 38 | 0 |

A directional frame entry is one manifest record; it is not a count of unique drawn poses. Repeated holds and reused frames may exist.

- **Buffalo:** attack, attack2, attack_ready, cast, charge, combat_stance, dodge, drill0, faint, guard, hit, idle, jump, run, throw, walk and weapon_crit. Run/walk/idle have eight directions. Most attack/cast actions have the four diagonals. Run has eight frames per direction; weapon_crit has eight per diagonal; hit has three per diagonal. The sheet cell is 113×112 with anchor (56,96).
- **Clione:** attack, dodge, faint, guard, hit, idle, idle_auto and walk. Idle/walk have eight directions; attack has twelve frames per diagonal. The sheet cell is 197×135 with anchor (98,105).
- **Torobbie:** attack, dodge, faint, guard, hit, idle, idle_auto and walk. Walk has eight frames in eight directions. Idle has one frame on cardinal directions and six on diagonals; consumers must not assume every direction has identical clip length. The sheet cell is 61×70 with anchor (30,54).
- **Longsword:** texture plus grip (2,5), angle 0.504861 radians and reach 43.4166 in its existing export metadata.
- **Guides:** 512×512 canvases, declared feet (256,420), with the original pose-to-canvas scale recorded in each available `guide.json`. Run guides contain all 64 frames across eight directions. Hit guides contain all 12 frames across four diagonals. Uploaded weapon_crit frames total 28 because the southwest direction is incomplete.

File types: **180 PNGs, 180 `.import` files, 19 JSON files and 3 `.tres` files**. Of the PNGs, 33 are actor action sheets, 1 is the weapon, and 146 are guide frames/contact sheets/strips.

## Incomplete or absent material

- `pose_guides/buffalo/weapon_crit/sw/` contains `contact.png` and only `frame_00.png` through `frame_03.png`. The other three diagonals contain eight frame PNGs. **Frames 04–07, both four-frame strips, and `guide.json` are missing from the southwest upload.** The corresponding Godot `.import` sidecars are also absent. No replacement files were fabricated.
- No idle pose-guide folder was uploaded. The round 2b test requires `pose_guides/buffalo/idle/se/frame_00.png`; the original Buffalo idle sprite exists and can serve as the input to the existing local guide-export tool.
- No map exports, monster-stat tables, audio exports, skill icons, or additional enemy actors were included in this upload set. Full game/hub startup still depends on other data. Actor resource loading alone does not establish full-game readiness.

The existing guide exporter can regenerate missing guides from the uploaded Buffalo actor source. Review its output locally before adding anything; regenerating already-uploaded actions may overwrite their local guide files.

## Visual inspection notes

Inspected Buffalo's directional idle sheet, the southeast run and sword-attack guide contact sheets, Torobbie's idle sheet and Clione's idle sheet.

- **Buffalo:** the wrapped headcloth/red band is the strongest head landmark. The red upper body and baggy khaki trousers form large readable blocks; the compact proportions carry more charm than a realistic tall fighter. The elevated directional views expose the top of the headwrap and shoulders. These are useful design/camera references for the updated art brief, while the new costume remains a redesign.
- **Torobbie:** a simple round pale body, small appendages and strong face/expression changes carry its identity. Preserve that simplicity when developing the new creature art rather than relying on fine surface texture.
- **Clione:** the star-like antenna tips, wing-like appendages and floating body motion distinguish it from a planted ground creature. Its exported anchor is a positioning reference, not proof that its lowest opaque pixel should be glued to the floor.
- **Sword attacks:** the provided guides show distinct load, strike and recovery poses. New source art should preserve the intended per-frame canvas/ground relationship and validate hand points rather than recenter every silhouette independently.

These are observations from the supplied images and manifests, not newly researched claims about the original game's numerical mechanics.

## Validation

- Verified every moved file against its pre-move SHA-256; no content changes.
- Decoded all 180 PNGs and checked all actor frame rectangles are inside their referenced sheets.
- Checked all 33 texture references in the three SpriteFrames resources resolve at their intended paths.
- Ran Godot's headless editor import, then loaded all three through the actual `ActorSprite.setup` adapter: 74/38/38 animations loaded, with zero asset-load failures. Loaded the longsword texture as well.
- Validation used installed Godot 4.6.3. The project requests 4.7; no interactive/full-game or 4.7 compatibility claim is made.

## Tracking policy and handoff

The files were already committed by the user and remain tracked after relocation. The existing `original_assets/` and `*.import` ignore rules are unchanged: newly created local exports are still ignored. This branch adds no newly derived original-game images. Generated replacement content remains under `art/` on its own content branches.

This branch changes only the uploaded-file locations and this inventory. Hub scenes, runtime scripts, project configuration and the skill-icon branch remain separate. After integrating, avoid uploading actor or direction folders to the repository root again; place existing asset bundles in the structure above.
