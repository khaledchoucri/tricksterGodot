# Review log — proposal v0.1

Reviews performed on 15 October 2026. These are document/production-plan reviews, not validation of final art or game behavior.

## Game design / future implementation lead

Reviewed the visual bible and production playbook independently of their authorship. Checked direct fan-remake identity, AI feasibility claims, gameplay coverage, projection/scale arithmetic and review boundaries.

Corrections applied:

- Assigned companion production consistently across minimum slice, CHAR/ANIM prompts and briefs.
- Defined AI-only production: agents may assemble/rig/script/export generated sources; no unpriced human drawing/animation rescue is assumed; unavailable rig/motion tools remain blockers.
- Separated the illustrative 328-frame estimate from the complete P1 manifest, which also needs skill, defeat, drill-abort/discovery, companion and enemy-state coverage.
- Added strafe/backpedal or explicit turning policy when move and aim differ.
- Added world-metric movement normalization to the later technical brief.
- Required canon-versus-modernization records for skills, gear, evade and elite adaptation.

Arithmetic confirmed: 320×0.45=144; 512×0.45=230.4; 41×8=328; 8×12×10×10=9,600. No claim of measured combat timings or camera values was approved.

## Independent pipeline review

Reviewed the content briefs, research ledger and revised playbook for dependency order, unsupported claims and tool feasibility.

Corrections applied:

- Reference clearance is dependency-local; all eight heroes need not be verified before Bunny's pilot.
- Tiny SE/NW motion-route screen precedes broader Gate B qualification and full P1 production.
- Body height now explicitly means foot anchor to anatomical skull crown, excluding ears/headgear/weapon extensions. Canvas safety still includes them.
- Five-head proportion studies remain optional comparisons pending reference/direction approval.

No hard contradiction in the seven-slot allocation or hidden assumption that an image generator automatically supplies rigs/video was found. These results do not qualify an actual animation toolchain.

## Coordinator concept-board review

Exploratory board supports palette, quiet-ground composition and high-level pose language. Rejected for canonical/production reference status: costumes and gear vary, no verified monster identities, generic town architecture, and illustrative rather than calibrated projection. Recorded these limits in the bible/presentation. No image is marked accepted.

## Package checks

Package checks verify local links, source hashes, batch uniqueness/status and offline presentation structure. Results are recorded after final assembly. They do not verify animation, canon, accessibility of the finished game, GPU performance or gameplay feel.

Final checks passed: all local Markdown/HTML links and unique HTML IDs; 61 unique planned batch IDs and matching CSV/JSON counts; 11 retrieved source hashes. Headless Chromium rendered desktop and mobile layouts with the embedded board; all 10 chapter links, scope/owner/search filters, copy handler and print-all visibility passed, with no JavaScript errors or mobile page overflow. The managed browser blocks `file://` navigation, so rendering/interactions were verified from the exact HTML source through `set_content`; direct local-file navigation was not verified in this managed browser. Screenshots were visually inspected. These are package checks only.
