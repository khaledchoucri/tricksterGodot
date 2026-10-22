# Gameplay and Godot implementation audit

Reviewed: `c7b27650a182c864aa8c6b2c0ea38d53e86e79a5`, fetched from `main` / `poc/combat-room`. Review date: 22 October 2026. No game code changed.

> **Historical review, not a current bug checklist.** This audit describes the commit above and includes the later hub-review addendum. Subsequent commits changed Chunk 1 job progression and the Coral Beach boss; those changes have not been re-audited here. Source links are pinned to the reviewed commit so the evidence stays inspectable.
>
> **Later user direction supersedes earlier crafting recommendations:** Alchemist Nate handles Mature Compounding of equipment attributes; Compounder Paul handles the new Item Compounding recipe system; Marx should follow verified original refining requirements, including appropriate ore tiers. Recreate the existing original service interfaces in Godot. References below to Paul's old attribute-compounding service describe the reviewed implementation, not the intended assignment going forward.

## Assessment

This is a substantial single-player action RPG prototype with an unusually broad set of interconnected progression systems. The strongest foundation is the separation between resource definitions, reusable skill behaviors, character state, and run subsystems. The weakest foundation is the set of contracts between those systems: what happens when damage kills something, a cast is interrupted, a room changes, equipment moves between storage and the player, or a run ends.

The project has more content breadth than demonstrated mechanical reliability. I would keep the existing foundation, pause expansion of the system count, and spend the next development milestone making a smaller set of complete character builds reliable through an entire expedition. This does not mean abandoning the eight characters. It means using representative builds to prove the shared rules before multiplying balance work.

The present implementation expresses the single-player expedition interpretation much more completely than the eventual MMORPG. Persistent character levels, concurrent players, parties, shared encounters, server authority, and a persistent world are not implemented by the current run/profile architecture. Those are future design and engineering problems, not defects in a single-player slice. The distinction matters when deciding which mechanics should become permanent foundations.

## Evidence and limits

I traced player input and states, basic combos, casting, gun cycles, shared damage formulas, enemy states, boss behaviors, room/wave flow, jobs, cards and talents, gear, refining, compounding, drilling, warehouse ownership, death recovery, hub services, difficulty modifiers, saves, and the automated test harnesses. This is a system audit; it does not certify every numerical row or every possible build permutation.

I ran isolated probes using Godot 4.6.3. The project declares Godot 4.7, so findings about current engine behavior should also be checked on the intended engine. The probes successfully initialized the run data, found 32 planned rooms and 218 registered cards, and found no missing or above-cap prerequisites among registered cards. Resource presence and prerequisite consistency do not prove that every skill is obtainable on every intended job path.

The broad smoke command failed: it reported 8 failed assertions and 230 script errors, primarily cascading from incomplete game initialization in this checkout. I do not interpret that as 230 independent gameplay defects, or as evidence that the eight classes fail in a complete runtime. I also cannot claim a successful full expedition or verified class balance. Focused probes were separated from that failed run.

**Reproduced in isolation:** warehouse index corruption; healing from repeated HP-equipment swaps; timers completing during pause while `Events.time` remains unchanged; array iteration skipping an entry when that entry's predecessor is erased; borrowed-rune level overriding an already owned skill's level.

**Confirmed by source tracing:** the other implementation findings below. Their proposed player-facing scenarios are identified where a complete interactive reproduction remains outstanding. Balance and feel judgments are recommendations, not measured player-study results.

Severity used below: **Critical** threatens persistent ownership; **High** violates combat or run rules; **Medium** weakens consistency, clarity, or extensibility. Design risks are labeled separately.

## 1. Persistent ownership and run outcomes

### 1.1 Critical — warehouse positions are being used as permanent item identities

[Profile.discard_item](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/autoload/profile.gd#L285) removes an array element and repairs `Profile.loadout`. It does not repair the `stored` indices on live `GearItem` instances. [RunCity.save_point](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/autoload/run_city.gd#L257) subsequently uses those stale indices to write equipped items back.

**Reproduction:** store sword A at index 0, hat B at 1, ring C at 2; equip the stored hat; discard A; save the worn gear. B still says `stored = 1`, so it overwrites C, now at index 1. The probe produced `candy_hat` where `might_ring` should have remained. The victory overflow UI can reach this sequence because it allows a shelf to be discarded and then calls `save_point` for the overflow item.

**Fix:** give each rolled item an immutable instance ID. Shelves are ordering, never ownership identity. Equipment and loadouts should reference IDs. Until that change lands, every removal must repair all live references, including pending rewards and overflow lists. Add an integration test that discards a lower shelf while higher shelves are worn and then saves/reloads.

### 1.2 High — equipment swaps grant repeatable healing

[RunGear.equip](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/autoload/run_gear.gd#L48) heals the positive increase in maximum HP. Taking an item off clamps HP to the smaller maximum but otherwise does not undo the granted healing. Putting the same item back on grants the increase again.

**Reproduction:** start at 20 HP, equip a +50 HP hat, take it off, equip it again: HP becomes 120. Warehouse swaps at rest stops make this more than an internal API concern.

**Fix:** define one equipment-health rule and apply it consistently. Preserving the current-health fraction is one option; preserving missing HP needs care because repeated removal/re-equipping can still become exploitable near a clamp. Test repeated cycles at low, partial, and full HP. Level-up healing can remain an explicit separate reward.

### 1.3 High — victory and death are not one mutually exclusive transaction

[Game._win](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/game.gd#L904) sets `WON`, banks rewards immediately, and waits two seconds. It does not stop all combat or protect the player. [Game._on_player_died](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/game.gd#L883) has no terminal-state guard and independently drops the bag and banks a loss. [RunCity.finish](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/autoload/run_city.gd#L317) is not idempotent.

**Reachable risk:** a lingering hostile projectile or delayed attack kills the player after victory has been awarded. Both clear and death can be recorded and currencies banked twice. Conversely, surviving player effects can keep killing after death, after the run's bank operation has already executed.

**Fix:** one `finish_run(outcome)` transition, accepted once per run ID. Freeze or explicitly retire encounter damage sources before rewards settle. Capture a final reward snapshot and commit it once. Decide explicitly whether a simultaneous final kill and player death counts as a win. Test that rule in both callback orders.

### 1.4 High — storage swaps can partially succeed and lose displaced gear

[RunCity.swap_from_shelf](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/autoload/run_city.gd#L119) checks room for the replaced item, equips the new one, then banks the replaced item and any displaced shield. It ignores the return values of those banking operations. A gun can displace both a weapon and a shield; the preflight check does not reserve capacity for the whole operation.

**Fix:** calculate the complete item movement first, validate capacity, then commit all changes or none. Return a structured failure reason. Test a stored gun replacing a stored weapon while an unstored shield is worn and the warehouse is full, plus the case with only one free shelf and two found items to bank.

### 1.5 High — save durability is too weak for permanent item loss

[Profile.save](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/autoload/profile.gd#L135) truncates and rewrites the live JSON file. It has no temporary-file replacement, backup recovery, or schema migration dispatch. A death/clear performs several separate saves while transferring items and banking currencies.

This was acceptable for disposable prototype progress. It is a material weakness once players can lose refined equipment and recover it from a bag. A valid JSON file also is not necessarily a valid profile: item refine bounds, compound arrays, loadout slot compatibility, and difficulty ranks need validation.

**Fix:** a validated, versioned snapshot written to a temporary file, then replaced with a recoverable backup strategy. Item transfers and run completion should each produce one coherent snapshot. Persist run completion IDs to make retries harmless. This is local reliability work; it need not wait for multiplayer.

## 2. Core combat correctness and responsiveness

### 2.1 High — lethal area hits can skip enemies

[ComboAttack._apply](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/player/combo_attack.gd#L76) iterates `room.enemies` and damages each target. Enemy death synchronously emits a signal; [Room._on_enemy_died](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/room.gd#L433) erases it from the same array. `sonic_slash.gd` also damages while directly traversing that array.

The engine probe demonstrated the underlying behavior: iterating `[1, 2, 3]` while erasing each visited entry visits `[1, 3]`, leaving `2`. This makes a lethal cleave less reliable than a nonlethal cleave and biases results by spawn ordering.

**Fix:** resolve a snapshot of eligible targets before applying damage. Use that rule everywhere, rather than selectively adding `.duplicate()` to individual attacks. Test a single attack killing three adjacent enemies in one frame and an attack that kills a summoning boss.

### 2.2 High — delayed combat uses a different pause policy from combat deadlines

[Skill.wait_for](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/skills/skill.gd#L112) calls `create_timer(seconds)` with the default `process_always = true`. Boss routines also use default scene-tree timers. Meanwhile `Events.time` stops when the tree is paused.

The probe confirmed a timer completing during pause with zero gameplay-clock advancement. Ghostly Whisper, multi-shot skills, card hands, and delayed boss attacks can therefore continue callbacks while ordinary actors and debuff expiry are frozen. A long reward decision can change combat outcomes.

**Fix:** gameplay timers must be pausable, normally physics-driven, and use one simulation-time policy. Keep UI timers separate. Test a pending damaging effect before pausing, wait longer than its delay, and assert no damage, resource spending, or status expiry until resume.

### 2.3 High — lingering skills do not establish that their caster is alive

[Skill.alive](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/skills/skill.gd#L105) checks object validity, tree membership, and room validity. A dead player still satisfies all three. Effects can continue hitting, generating loot, and changing progression during the death presentation. Some effects may intentionally survive their caster, but that needs to be a stated rule rather than an incidental result of object lifetime.

**Fix:** attach a run/encounter cancellation token to all delayed work. Separate “may finish after cast cancellation” from “may act after death or encounter completion.” Clear static lingering ownership when its encounter is retired. Test room exit, death, clear, and scene replacement separately.

### 2.4 High — Clinch Release can cancel hurt without a successful cast

[Player._clinch_release](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/player/player.gd#L393) clears knockback and enters `MOVE` before `try_cast` checks cooldown and affordability. If the skill is unavailable, its stagger escape has already happened.

**Fix:** validate and begin the cast before changing state, or have the caster return a prepared cast that can be committed atomically. Verify that zero MP and an active cooldown leave the player in `HURT` with the original knockback.

### 2.5 High — some skill parameters are finalized after the caster has consumed them

[SkillCaster._begin](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/player/skill_caster.gd#L153) sets invulnerability and starts the action before calling `skill.start()`. Several behaviors change their duration or action in `start()`.

For example, Boxer Dash computes duration from travel distance, but invulnerability was allocated using its initial 0.3 seconds. Long travel can outlast that protection. Charm strikes and bursts also change their timing/action after the caster has started them.

**Fix:** split skill preparation from activation: compute target, duration, movement, and flags; validate costs; then activate and apply state. Reserve `start()` for effects whose configuration is already final. Test both minimum and maximum travel distances.

### 2.6 Medium — narrow hit windows can be stepped over

[ComboAttack.update](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/player/combo_attack.gd#L47) only applies a window when the current time lies inside it. It does not test whether the frame crossed the window. Attack speed shortens the effective window; a slow physics frame can miss it entirely. Bunny's second swing has two narrow windows, making this especially relevant to her advertised identity.

**Fix:** test overlap between the previous/current swing-time interval and each hit interval. Each window still needs its own hit set. Validate high attack speed and deliberately large physics steps, rather than only fixed 60 Hz.

### 2.7 Medium — buffered input is a single overwritten command

[Player input handling](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/player/player.gd#L192) stores one action string. A new press replaces the old one. `try_actions` also consumes dash before checking whether it can currently execute. Basic spells support held input; melee basics primarily use discrete buffered presses.

A short input buffer and explicit cancel windows are good foundations. The remaining inconsistency can make simultaneous skill/dash input feel unreliable and makes melee more dependent on repeated clicking.

**Recommendation:** specify command priority, expiry, and whether cooldown-blocked input is retained. Give attack repetition an explicit setting or consistent rule. Keep dash priority deliberate. Test rapid attack→dash, skill→dash, and dash just before cooldown recovery.

### 2.8 Medium — the project needs one spatial rule for movement, range, walls, and hits

[Combat](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/combat.gd#L7) correctly distinguishes a 2:1 projected ground plane for attack shapes. Many movement and travel calculations still normalize screen vectors. At speed 175, vertical movement covers twice the ground-space distance of horizontal movement. Some rushes normalize a projected vector and then apply a ground-space range, also changing effective travel by direction.

Wall rules vary too: basic gun lines stop at obstacles; gun spray directly hits targets in a circle without a line-of-sight check; `MagicOrb` checks room bounds but not blocking terrain. Flash Cut chooses a target without checking line of sight and later damages that target even if body collision prevented reaching it.

**Fix:** document which effects require line of sight, which can cross terrain, and which require contact at impact. Use shared ground-space movement/range helpers. Use swept projectile tests where speed can cross a small target within one tick. Deliberate through-wall spells can remain exceptions, visibly and mechanically specified.

## 3. Damage, statuses, and resource rules

The shared `Player.deal_hit` path, skill-specific scaling expressions, and talent hooks are valuable. They are much easier to audit than eight entirely separate combat implementations. However, defensive behavior, damage-over-time, reflection, self-damage, and ordinary hits still take different routes.

### 3.1 High — a damage call does not report whether damage actually happened

[Player.deal_hit](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/player/player.gd#L437) rolls crit/graze and can award critical ore or legendary Galder before `Enemy.take_hit` accepts the hit. [Enemy.take_hit](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/enemy.gd#L466) can then reject damage because the enemy is frozen. Combo code grants MP after calling the damage method regardless of acceptance. A frozen target is still `is_hittable()`.

**Consequence:** attacks against an invulnerable frozen enemy can generate MP or hit-dependent loot without dealing damage. This also makes hit/crit statistics ambiguous.

**Fix:** damage resolution should return a result: accepted, blocked, grazed, crit, HP damage, absorbed damage, killed. Award on-hit effects from that result according to explicit policy. Do not use a boolean whose only meaning is “critical” as the shared combat outcome.

### 3.2 Medium — debuff strength and duration do not obey their documented stacking rule

[Enemy.apply_debuff](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/enemy.gd#L222) keeps the stronger current value but replaces expiry with the latest duration. A weak short debuff can shorten a strong long one; a weak long debuff can extend the strong value. Burn similarly retains the historical maximum DPS when refreshed, even after the earlier burn expired, unless a different lifecycle resets it.

**Fix:** choose replace, strongest, refresh, or independently stacked behavior per status. Track source and expiry together. Also evaluate hold before ranged retreat: `_state_chase` currently lets a ranged enemy back away before testing whether it is held.

### 3.3 Medium — gun damage bypasses the normal skill multiplier stage

[RunFormulas.skill_mult](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/autoload/run_formulas.gd#L131) returns early for `GUN`, before applying the generic `skill_damage%` modifier. `Shield Breaker` computes its own amount as well. Some current bonus sources are class-specific, so the immediate scope depends on a reachable build, but the shared contract already differs: “skills deal more damage” is not universally true.

**Fix:** calculate base scaling first and apply common modifiers afterward. If gun skills intentionally exclude a modifier, represent that through an explicit tag and accurate wording. Compare equivalent AP/MA/DA/GUN skills under a known +skill-damage source.

### 3.4 Medium — the UI misstates important combat rules

[Stats descriptions](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/data/stats.gd#L23) say MA controls skill cooldowns, while current cooldowns are modified by `cooldown_cut%`; MA primarily increases spell damage. DA's description omits its direct relevance to Fox's attack damage. The skill HUD compares raw MP cost even though the caster uses discounts and Overcast, and its form-lock test does not express every refusal reason.

**Fix:** one read-only cast query should provide real cost, readiness, resource substitution, and block reason to both input handling and the HUD. Explain attributes using their actual effects in this game. Accurate descriptions are part of build balance: players cannot choose rationally using incorrect information.

## 4. Character and job design

The four attribute families are an appropriate organizing structure. The shared first-job trees within the male/female pairs are substantially represented in data; subsequent jobs build on prior job pools. This is a much stronger basis than inventing disconnected mechanics for each character. Class-specific basic attacks and exclusions are adaptations and should be recorded as such, especially where they alter shared first-job access.

| Character | What works | Most important concern | Validation target |
|---|---|---|---|
| Buffalo | Sword sweep, crowd control, combo finishers, and later rushing skills form a coherent melee kit. | Repeated stagger can become the primary defense; lethal cleave iteration currently weakens reliability. | A complete sword build must handle crowds and bosses through timing and positioning, without requiring permanent stagger lock. |
| Bunny | Shorter arcs, faster punches, multiple hit windows, and gap closers give a clear close-range identity. | Narrow windows, contact checks, dash setup, and free Clinch escape disproportionately affect this kit. Single-target identity is hard to evaluate in mostly crowd-based rewards. | Measure boss pressure, time spent chasing, interrupted combos, and earned damage opportunities against Buffalo at equivalent progression. |
| Sheep | Group-focused Mana Ring and elemental branches support area control and planning. | Automatic targeting and broad fields can turn positioning into a secondary concern; healing/regeneration can erase attrition. | Show distinct reasons to choose at least two elemental combinations across mixed encounters, rather than only increasing area damage. |
| Dragon | Mana Arrow and its supplements provide a dependable ranged core, with recognizable light/dark directions. | Guaranteed basic-growth offers may make optimal rewards repetitive. Light sustain and dark offense require evaluation over a full run, not a stationary damage test. | Compare clear time, safety, healing, and resource use for light and dark routes; measure how often a reward is an actual decision. |
| Fox | DA connects throwing damage, exploration, and item quality, giving Sense a coherent identity. | That same stat improves immediate offense and future economy. Mines and targeted effects need consistent terrain and hit rules. | Compare both combat and the persistent value earned per run; verify that prepared traps beat direct throwing in suitable situations. |
| Lion | The loaded/reloading/power-shot cycle is a real mechanical distinction. Starting Quick Reload avoids making basic movement punitive. | AC drives gun damage, so Power investment may outperform Sense offensively. Critical-ore incentives do not naturally serve a basic attack that cannot roll ordinary crits. Gun skills and reload interactions need explicit rules. | Compare Power/Sense/mixed builds, loaded duty cycle, wasted reload time, and actual overcharge value under pressure. |
| Cat | HV contributes to offense and evasion; beast form creates a substantial change in play. | Charm can improve damage, HP, DP, and evasion together. Permanent transformation can invalidate a developed loadout and block future active offers. | Validate both normal and transformed routes, including a player who accepts transformation with three incompatible skills equipped. |
| Raccoon | Cards, Galder spending, defense, and transformation offer distinctive risk/reward themes. | Damage randomness and shared combat/crafting currency can create economic traps. Four of a Kind cannot function against a lone boss without adds. Metamorphosis lowers AP and attack speed while replacing skill access. | Prove a boss-capable card route and a transformed route; show the expected currency cost and useful fallback when an active is unusable. |

### 4.1 Design risk — transformation is a commitment before the supporting kit is guaranteed

The warning text is a positive addition. It does not solve the underlying progression problem: learning Evolution or Metamorphosis permanently changes form, locks incompatible active skills, and then depends on future offers to obtain suitable skills. A bad build can therefore become less functional through a supposedly exciting reward.

**Recommendation:** make the transition package complete. Options include granting a compatible active, converting an occupied slot, or offering the transformation only with a compatible transition choice. Preserve different normal/beast builds; do not make every transformation a mandatory statistical upgrade.

### 4.2 Design risk — skill replacement destroys prerequisites as well as an action slot

[RunDeck.add_card](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/autoload/run_deck.gd#L111) erases the old skill when a slot is replaced. That removes its learned level from prerequisite checking unless an advanced replacement preserves ancestry. Previously acquired investment and future unlock access can disappear together.

Three active slots can create excellent action-game choices. Forgetting a learned prerequisite is a separate progression penalty and needs much stronger justification. Prefer separating learned skills from equipped skills, while still restricting the active loadout. If permanent forgetting remains intended, show the downstream skills it will lock before the replacement is confirmed.

### 4.3 High — borrowing a skill can downgrade the same skill already owned

[RunDeck.card_level](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/autoload/run_deck.gd#L209) returns the rune level first whenever IDs match. A level-1 borrowed Drip Bomb can make an owned level-5 Drip Bomb behave as level 1; the probe reproduced that precedence. Echo skills overlap ordinary class trees, so this is a plausible normal run interaction.

**Fix:** model borrowed and learned slot levels separately, or explicitly use the higher level if both represent one skill. Test normal cast, borrowed cast, offer eligibility, and prerequisites with the same card in both sources.

### 4.4 Design risk — the custom Trickster's freedom exceeds its supporting implementation

[RunCity.build_trickster](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/autoload/run_city.gd#L41) offers graphs including Magic/Sense, but derives its starting base from Buffalo/Bunny, supplies a melee kit and Fighter pool, and has a limited explicit list of selectable trees. It bypasses ordinary job restrictions. A permitted combination is therefore not necessarily a well-supported class.

**Recommendation:** keep this as an experimental endgame feature until ordinary routes are validated. Define compatibility by capabilities—weapon, basic attack, scaling, resource generation, and prerequisite access—then reject or repair combinations lacking a functional loop. The UI should describe the actual supported freedom.

## 5. Run structure, recovery, and economy

### 5.1 Design risk — waiting is an unlimited recovery resource

Mages regenerate a share of maximum MP continuously. Cure converts MP into maximum-HP healing. Oath of Light heals periodically, Guard replenishes blocks, barriers recharge, and Revival returns after its cooldown. These operate outside an active fight while the player can wait safely in cleared rooms.

This is not a claim that regeneration is inherently wrong. The problem is that the route also asks players to value Recovery doors, consumables, revives, and persistent HP upgrades. Their strategic value changes dramatically if a patient build can start every encounter fully restored.

**Recommendation:** explicitly choose the recovery model before tuning enemy damage. Either safe areas normalize recovery for everyone; healing has a genuinely limited expedition resource; or certain recovery requires active combat. Avoid balancing the game around players voluntarily declining free recovery. Measure both an immediate-exit run and a patient recovery run.

### 5.2 Design risk — permanent full-strength equipment changes what a run means

The current full-strength loadout rule is an explicit existing design decision. I am not recommending silently reverting it. It makes gear accumulation meaningful, but a strong late-region item can dominate early rooms in every future run. Heat also raises item-level bands, allowing stronger permanent loot to return to lower difficulty.

**Recommendation:** test fresh, moderately progressed, and well-equipped profiles separately. Decide whether repeated early rooms should become a quick mastery lap, a persistent challenge, or an optional skip. Keep that compatible with the chosen gear rule. A single fresh-profile clear rate cannot establish balance for this progression model.

### 5.3 Design risk — death can create a compound setback

Death loses some resources, can remove worn permanent equipment into a bag, and asks the player to reach the same region/depth without it. A second death with gear can replace the previous bag. [RunCity.split_at_death](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/autoload/run_city.gd#L164) always bags at least one qualifying item, regardless of available carry capacity.

This can be a compelling recovery objective. It can also make the second attempt substantially harder precisely because the first failed. The “at least one” exception means WT does not literally save everything it can carry.

**Recommendation:** communicate the exact rule before departure and death, and test recovery attempts using the weakened loadout. Track repeated deaths, bag abandonment, and time to recover. Decide what prevents a persistent downward spiral. Do not judge the economy solely from successful clears.

### 5.4 Design risk — early progression hides the systems that define the game

The Job Hall requires 5,000 TM and a shard; without it the scheduled trial gives no job change. Other restorations gate refining, compounding, and drilling. This can provide an understandable reopening-city structure, but it also delays access to job identity and signature activities.

**Recommendation:** measure the first three sessions from a truly fresh profile. Count encounters and minutes before the first job change, first meaningful compound, and first dig. Give the player an understandable short-term objective and avoid implying that a trial will advance them when the service is still locked. Whether the price is too high remains unmeasured here.

### 5.5 Design risk — rewards contain many interruptions and limited route agency

Every pending level produces a type choice followed by skill training; a room can also queue a card, elite gear, a job choice, and a Port. The 32-room route fixes the regions and boss order; doors mostly choose a reward and den rather than changing the structure of the expedition.

The resource-defined route and den bias are useful. The next improvement should be meaningful encounter/reward decisions, not simply more room count. Batch compatible level-up decisions, measure menu time, and compare optional danger with reward value. Define a target for actual decision time within the intended roughly 40-minute expedition.

### 5.6 Medium — economy commands rely on UI filtering for correctness

Refine, compound, mastery, and some equipment commands do not independently validate all affordability, capacity, compatibility, or level-cap conditions. `can_*` functions exist, but mutation methods often assume the caller used them. A new NPC, bot, or future network command can bypass that assumption and create negative currency or invalid item state.

**Fix:** commands validate and return a typed result. The UI uses the same query for display but never becomes the authority. This is especially important before parallel development adds more callers. Test rejected operations leave both resources and items unchanged.

## 6. Enemy AI, encounters, and bosses

The basic enemy state machine is appropriately modest for this stage. Telegraphs, recovery, poise, ranged retreat, grid pathing, and attack tokens are meaningful action-combat foundations. The two-shooter limit also addresses a real melee-versus-kiting problem. These are worth preserving.

The current enemy variety is nevertheless narrower in decisions than in data. Most enemies use a small set of tuned attack patterns. More HP, damage, speed, and poise create different difficulty but not necessarily different tactical questions. Add role interactions—an enemy that protects another, an approach that can be baited, a setup that can be interrupted—only after the common interrupt/target/terrain contracts are fixed.

The shared attack-token budget limits who starts an attack; it does not represent all outstanding danger. A projectile survives token release, and Tutankhamen's coffins release the token while several delayed impacts remain pending. Bosses also bypass the ordinary attacker cap. At higher difficulty, “two attackers” does not mean two simultaneous threats.

**Recommendation:** budget persistent hazards as well as active attackers. Define a maximum acceptable overlap and ensure at least one reasonable evasive response for baseline movement. Audit melee reach and escape routes in narrow spaces.

**Golden Mole:** tracking followed by a locked burrow marker gives a readable bait-and-evade sequence. Summon thresholds provide pacing. But its burrow path returns before the base status tick, so damage-over-time pauses underground. Decide explicitly whether that is immunity or an accidental lifecycle exception; apply the chosen policy consistently.

**Tutankhamen:** ranged fans, staggered area attacks, and summons create more varied positioning than the basic enemies. The risk is overlap, timer cancellation, and the disconnect between attack-token release and actual impact. His specials use fixed timing constants, so Heat's shared windup modifier does not uniformly affect them.

**Tombeth:** staged escalation, reflection, shielding, and a dangerous close-range attack create a plausible final examination. Reflection needs a clear mechanical status and a reliable answer for spell-heavy builds. Health-threshold “lives” are escalation thresholds with healing, rather than three guaranteed lives: a sufficiently large lethal hit can bypass later thresholds. Choose whether bypassing phases is earned burst power or unintended behavior. HP-threshold summons in the other bosses similarly depend on `take_hit`; the direct burn tick path can cross thresholds without using those hooks.

**Recommendation across bosses:** phase transitions should subscribe to authoritative HP changes, not one particular damage entry point. Express action preparation, activation, cancellation, recovery, and threat ownership consistently. Boss-specific code remains appropriate; a universal boss framework is unnecessary right now.

## 7. Godot architecture and future implementation

### Keep these decisions

- Typed resource definitions for classes, jobs, attacks, regions, items, and cards.
- Separate reusable `Skill` and `Talent` behaviors instead of a huge player skill switch.
- Run modules for deck, route, purse, gear, formulas, and city interactions.
- Explicit player/enemy states and named cancel/hit windows.
- Seeded run randomness and separate visual randomness as an engineering intent.
- Domain checks and targeted smoke sections already present in the repository.

### Strengthen these boundaries

**Global ownership:** modules are separated by file, but depend heavily on the `Run` singleton and mutate each other's state. They remain hard to exercise independently. In the eventual online game, one global `Run.hp`, one `Profile`, and one event bus cannot represent multiple independent players. Introduce a character/encounter context at the seams gradually; do not rewrite the prototype into an ECS or networking framework.

**Event meaning:** events currently both announce results and trigger authoritative state changes. Immediate Godot signals allow re-entrant mutations during a hit, which is how the enemy-array problem occurs. Separate “resolve action,” “apply state change,” and “present result” enough to make callback ordering safe. Add owner/run IDs before multiple combat contexts exist.

**Game controller:** `game.gd` combines encounter flow, rewards, service menus, banking, death, victory, and feedback in over a thousand lines. Extract terminal run resolution first, then reward/service transactions. Splitting it by arbitrary line counts would not address the actual risk.

**State lifetimes:** HP and some timers live in `Run`; skill cooldowns and gun reload live on a newly spawned player for every room; some talent objects persist while player regeneration does not. Therefore room entry resets cooldowns and reload, but not every defensive deadline. Write down which state is cast-, actor-, room-, run-, and profile-scoped. Test one of each at room transition.

**Data integrity:** the registered-card prerequisite probe passed, which is useful. Expand validation to include behavior inheritance, job-path reachability, symmetric exclusions, upgrade cycles, table/cap consistency, and capability needs. There are 229 skill resource files but 218 registered entries; some omitted resources are intentionally unsupported, and `gun_shot` is used directly as a class basic. Do not equate file count with implemented playable skills.

**Performance:** repeated held-card sorting, talent enumeration, modifier reconstruction, full HUD text building, and occasional full-grid nearest-reachable searches are reasonable at prototype scale but occur in hot paths. Cache derived combat state on explicit changes and update UI on relevant changes. Profile representative crowded encounters before adding pooling or threads. There is no measurement here proving a particular frame-time bottleneck.

## 8. Verification quality

The test suite is more substantial than a simple “scene opens” check, and its wrapper treats script errors as failures. That is good practice. The most important gaps are interaction and failure tests rather than a lack of more one-skill assertions.

[The playtest bot](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/tests/playtest.gd#L249) force-kills enemies after a room timeout and can still report a clear. That is useful for exploring later content but invalidates an unqualified clear-rate claim. It also uses internal enemy state for dodging, teleports to doors/bags, and automatically resolves decisions. Those conveniences should be disclosed in telemetry and kept separate from human-experience claims.

`tests/progression_probe.gd` assumes a synthetic level-to-room relationship and only samples the older two-region progression. It does not demonstrate the actual three-region economy or acquisition curve. `tests/baseline.sh` captures logs but does not robustly propagate every subprocess failure or assert the absence of script errors before declaring a recorded baseline.

**Required next evidence:**

1. Item-ownership invariants across save/reload, death, recovery, discard, overflow, gun/shield displacement, and repeated runs.
2. Terminal outcome tests in both callback orders, including damage after the final kill and kills after player death.
3. Pause/cancel/transition tests for delayed skills, boss attacks, and resource costs.
4. Multi-target lethal-hit and high-speed window-crossing tests.
5. Complete ordinary character routes with fresh, intermediate, and strong persistent profiles; no forced clears counted as wins.
6. Per-run telemetry for real time, combat time, waiting recovery, menu time, accepted damage, interrupted actions, unusable skills, spending, and gear brought home or lost.
7. A short human play session per representative archetype. Bots can identify deadlocks and gross tuning issues, but cannot establish whether targeting, input priority, risk communication, or combat rhythm feels good.

## 9. Megalopolis: hub mechanics, services, and progression

This section extends the initial audit, which gave insufficient attention to the hub beyond equipment ownership. It reviews the hub as a playable preparation and progression loop: arrival, conversations, restoration choices, NPC services, character preparation, and departure. It covers the 11 configured NPCs/objects, 11 restorations, 17 wardrobe pieces, seven collection sets, four drills, mastery, crafting, and difficulty settings at the same reviewed commit.

### 9.1 The hub's overall design

**What works:** restoring the town makes persistent progress tangible by bringing service NPCs back. Services have distinct identities: Cavalier allocates restoration investment; Marx improves gear; Paul compounds materials; Eugene gives hunting goals; Louis changes starting builds; Marky expands drilling rewards; Sabrina changes expedition difficulty; Julio prepares equipment. This is a credible structure for tying repeated combat to a familiar central town.

**What remains weak:** much of the implemented hub is a collection of service menus rather than a complete preparation loop. Character choice comes after preparation, service changes do not consistently update the prepared character, several dependencies remain invisible, and the narrative's progression triggers have not kept up with the game's actual progression. These issues are more consequential than adding another shop or NPC.

Miranda, Stella, and the Copper Plate currently provide narrative interactions; they do not implement a potion shop, exchange, quest chain, or separate progression service. That is a legitimate scope choice. Their dialogue should accurately distinguish existing services, future possibilities, and narrative flavor. A Training Hall purchase likewise grants HP; it is not currently a practice encounter.

### 9.2 High — character selection occurs too late to support preparation

[Hub._choose_character](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/hub.gd#L583) changes `Profile.class_id` and immediately calls `_depart`. There is no normal character-selection step that keeps the player in town to configure that character.

Meanwhile Louis uses `Run.cls.id`, mastery eligibility uses the current class/job, and some equipment choices use the current class's compatibility. The player prepares the character from their last visit, then can choose a different character at departure. They cannot normally switch to a new character, visit that character's mastery options, inspect the resulting build, and then leave.

**Fix:** select the active character while remaining in the hub. Rebuild a preparation preview for that character; then let the player visit services and separately confirm departure. Store per-character preparation preferences where appropriate, even if the actual equipment collection remains account-wide. Show the final character, basic attack, starting skills, drill, difficulty, and equipment compatibility before departure.

**Acceptance:** switch Buffalo → Lion → Sheep without starting an expedition. Each character's mastery list and prepared loadout must describe that character, and switching back must restore its intended preferences.

### 9.3 High — an incompatible shared loadout can disable a character's basic attack

[RunCity.carry_loadout](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/autoload/run_city.gd#L80) checks `can_equip`, whose present rule mainly prevents a shield while carrying a gun. It does not enforce [RunGear.can_use](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/autoload/run_gear.gd#L129), which contains class weapon restrictions.

**Reproduced:** put a stored Wood Sword in the shared weapon loadout, select Lion, start a new run. The equipped weapon is `wood_sword`, `can_use` returns false, and Lion's basic remains `gun_shot`. This displaces his starting gun. His basic cannot operate as intended.

The equipment-slot picker applies compatibility filtering, but Julio's general stored-item action and run initialization do not enforce the same rules. A valid action in one menu therefore does not establish that the resulting loadout is valid for the next character.

**Fix:** one authoritative equipment-compatibility query for every entry point. On character switching, preserve incompatible stored items but use a valid starter or explicitly ask the player to resolve the loadout. Avoid silently accepting a build whose basic attack cannot execute.

### 9.4 High — the hub preview is a separate, stale copy of the preparation state

[Hub._ready](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/hub.gd#L27) calls `Run.new_run()` to create a preview. A real expedition calls it again. This consumes a run initialization, generates random starting state and a route that will be discarded, and couples city UI to the live combat state model.

Service paths then update different parts of that state inconsistently:

- `_choose_piece` changes `Profile.worn` and calls `player.dress`, without invalidating cached stats.
- Album rewards can auto-equip a piece without refreshing either stats or the player.
- City refining and compounding update warehouse serialization, while the equipped preview remains a separate `GearItem` instance.
- Restoration purchases spawn newly unlocked NPCs but do not rebuild current preview bonuses.
- Starting-skill selection updates the profile but does not replace the preview's current skills.

**Reproduced:** equipping Buffalo's Tail leaves preview max HP at 140; invalidating stats changes it to the correct 180. Refining an equipped stored sword produces warehouse refine +1 while the preview's equipped sword remains +0.

Actual departure initializes state again, so these observations do not establish that the subsequent expedition permanently misses those bonuses. They establish that the hub cannot reliably show the build the player is buying and preparing.

**Fix:** derive a preparation snapshot from profile + selected class + explicit loadout. Every successful service transaction invalidates that snapshot once. The real expedition consumes the snapshot and initializes its own transient state. Random starting rewards should either be committed once or clearly presented as unknown until departure.

### 9.5 High — Master Louis hides the selected starting technique

[Hub._mastery_menu](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/hub.gd#L431) filters every entry through `Run.deck.can_start_with`. That function ultimately requires the technique to be learnable as new. On hub initialization, the selected mastered technique has already been added to the preview by `carry_start_skill`, making it no longer learnable as new.

**Reproduced:** Burning Rave is eligible before selection. With mastery 1 and Burning Rave selected, the next `new_run` holds it at level 1 and the mastery menu's eligibility filter returns false. Choosing “Carry nothing” only removes the profile preference; the preview still owns the skill, so the filter remains false until state is rebuilt.

**Effect:** the technique the player is most likely to want to improve disappears from the service intended to improve it. This is a progression-flow defect, not just a missing label.

**Fix:** separate three questions: is this technique eligible for this character's persistent starting selection, can another mastery level be purchased, and is this technique currently carried? Persistent eligibility must not depend on whether the preview already owns the technique. Keep selected and fully mastered entries visible.

**Design assessment:** targeted mastery is a strong bridge from hunting to build planning. Costs of 6/12/18 materials and 500/1,000/1,500 Galder create explicit goals. The service should identify the supplying monsters and region, show progress toward the next purchase, and explain why later-job or prerequisite-dependent techniques cannot be selected. Currently filtering them away hides the goal instead of teaching the restriction.

### 9.6 Cavalier and restoration progression: coherent concept, incomplete dependency model

[The restoration menu](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/hub.gd#L146) offers all restorations using affordability and maximum level. There is no dependency graph, recommended next milestone, or explanation of missing resource-generating systems.

| Restoration | Implemented cost and effect | Audit judgment |
|---|---|---|
| Blacksmith Row | 2,500 TM; Marx, anvils and run shops | Broad utility and a useful early economic unlock. Gear already drops before this purchase; keep explanations consistent. |
| Job Hall | 5,000 TM + 1 shard; enables scheduled job changes | Core class identity is behind a city purchase. Trial and purchase wording should be class-aware; current text specifically promises Knight. |
| Compounder's Stall | 7,000 TM + 1 shard; Paul, normal monster-material drops and compound rewards | Unlocks a resource supply and its sink together. Its relationship with mastery needs explicit explanation. |
| GM Console | 4,000 TM + 1 shard; Sabrina and Heat | Suitable optional progression, but needs a clear expedition-level preview and reward explanation. |
| Card House | 3,000 TM; Eugene and monster-card drops | Establishes persistent hunting goals, but collection starts only after buying the system. A first concrete goal would make the purchase more satisfying. |
| Skill Shrine | 5,000 TM + 1 shard; Louis and starting-technique mastery | Can be purchased before any convenient material source is available. The service then exists without an immediately usable loop. |
| Drill Shop | 3,500 TM; Marky, a Basic Drill and dig rewards | A recognizable signature activity; teach its reward thresholds and the difference between depth and timing difficulty. |
| Training Hall | 3,000/6,000/9,000 TM; +15 HP per rank | A permanent numerical advantage, rather than a new activity. The full +45 HP is substantial against starting HP pools. |
| Mana Fountain | 3,000/6,000 TM; +15 MP per room per rank | Value varies strongly with class, existing regeneration, and recovery policy. |
| Rollback Cache | 8,000 TM + 2 shards; one 30%-HP revive | Potentially highly attractive while learning encounters; evaluate how strongly it dominates early purchase choices. |
| Tutor's Desk | 10,000 TM + 3 shards; a random additional active | Adds starting variety, but competes with deliberate mastery. Its benefit should be visible and its random selection should not misleadingly change between preview and departure. |

**Dependency finding, reproduced:** a fresh profile with 5,000 TM and one shard can buy the Skill Shrine without the Compounder or Drill Shop. An elite kill then supplies no normal monster materials because that drop path is still gated. Run shops can also supply materials once Blacksmith Row is unlocked, so this is not an irreversible deadlock. It is an undisclosed dependency and potentially disappointing purchase.

**Purchase-description defect:** `_restore_menu` uses `describe(current_level)` for existing upgrades while charging the next level's price. At Training Hall rank 1, the next purchase is priced for rank 2 but described with the +15 HP value rather than the resulting +30 HP. Show current → next, the incremental change, and whether it applies to all characters.

[The design document](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/docs/design/systems-plan.md#L164) says wardrobe replaces the four flat restorations, while the implemented hub still contains both. That needs an explicit product decision. Do not remove the bonuses merely to follow an older paragraph; reconcile the intended progression model and update both implementation and documentation accordingly.

### 9.7 Marx and Paul: useful risk-versus-convenience choices, poorly surfaced differences

[Marx's forge](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/hub.gd#L488) and [Paul's compounding](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/hub.gd#L522) give banked materials a purpose and make persistent equipment more than a trophy collection. Having both risky expedition crafting and safe city crafting can create a meaningful decision.

Their actual rules differ:

- City refining charges three times the run-anvil Galder cost.
- Run refining adds LK and relevant modifier bonuses; city refining uses the item's base success chance.
- Run compounding uses DA and compounding bonuses; city compounding uses the default zero-quality roll.

These may be deliberate costs for safety, but the services do not explain the comparison. A player can reasonably expect their investment in luck or detection to help the same crafting operation in town.

**Recommendation:** show final success chance, before/after item stats, consumed materials, and the reasons city outcomes differ. For compounding, show the roll range and that a permanent slot is being consumed. Keep confirmation proportional: the main need is an informed choice, not an extra dialog for every ordinary attempt.

**Implementation:** validate commands internally and update the prepared item immediately. This extends the earlier transaction recommendation; crafting services should not each implement wallet mutations and cache repair differently.

### 9.8 Eugene, monster collections, and wardrobe progression

[The album](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/hub.gd#L359) supports seven sets: three Coral Beach sets and four Desert Beach sets. Set membership overlaps without consuming cards, so one card can advance a local set and a region-wide set. That is a good collection structure. The focused probe confirmed that every listed set monster resolves to a configured enemy.

However:

- Caballa Relics has collectible monster cards but no configured set rewards. The third region's collection loop lacks the payoff supplied in the first two.
- The album shows sets and missing monster names, rather than a complete bestiary with habitats, acquisition guidance, and duplicate counts.
- Duplicate cards accumulate in the profile without an implemented spending or conversion use in this service.
- Ordinary card acquisition is random. There is no visible protection against repeatedly missing the final card in a set.
- Claiming first saves the “claimed” flag, then separately grants the reward. An interrupted save sequence can leave the collection marked claimed without delivering the piece.

**Recommendation:** retain the overlapping sets, give each implemented region a meaningful collection goal, show where missing cards are found, and define duplicates' eventual role. If a major mechanical benefit depends on a rare collection, evaluate a deterministic fallback or bad-luck mitigation. Claim completion and reward ownership must be one transaction.

The wardrobe is a real build system: six slots affect damage, evasion, movement, healing, economy, card choices, and job progression. It should be presented and tested as such. For example, Buffalo's Tail adds 40 HP and clear healing; this is not a negligible persistent advantage against a 140-HP starting character.

Several descriptions need mathematical accuracy. Black Sunglasses add 0.25 to the critical multiplier: 1.75 → 2.0 is approximately 14.3% more critical-hit damage, not a 25% multiplication of that hit. Omnipotent Umbrella modifies magic damage, which also includes some non-projectile attacks; its wording currently promises projectile mitigation. Eternal Sunshine adds one choice, which can yield more than four when another bonus is active.

**Job Cloak interaction:** its bonus is inserted into `pending_levels` at job change. Processing that queue grants a type choice and then skill training. Thus the cloak indirectly grants training as well as its advertised type point. Separate pending type points from pending actual level-ups, or deliberately document and balance both benefits.

### 9.9 Marky and drilling: progression currently means harder timing as well as deeper loot

[Marky's service](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/hub.gd#L401) correctly distinguishes owned versus purchased drills and persists the selected tool. It grants the Basic Drill when first visited; the run also falls back to that drill once the system is restored, so visiting Marky is not required to make basic drilling function.

| Drill | Purchase | Maximum depth | Timing window before DA bonuses |
|---|---|---:|---:|
| Basic | Free after restoration | 20 | 0.233 s |
| Cleaner | 4,000 TM | 30 | 0.111 s |
| Tornado | 9,000 TM + 1 shard | 60 | 0.082 s |
| Diamond | 16,000 TM + 3 shards | 90 | 0.079 s |

The intervals are zone width divided by marker speed, calculated from the configured values; they are not measured human success rates. Higher drills also have different scoop sizes and strike counts.

The shop description shows maximum depth, zone percentage, and strikes, but omits marker speed and scoop size. Cleaner therefore looks like an upgrade without clearly explaining that its base timing opportunity is less than half Basic's. It still cannot reach the gear threshold of 40. Tornado can reach gear; Diamond can reach the shard threshold of 70. These thresholds should be visible before the purchase.

**Recommendation:** describe drills as depth-versus-handling choices, show the reward tiers they unlock, and assess the minigame with players who have different timing ability. DA widens the timing zone; make that relationship explicit. A costly permanent upgrade should not unexpectedly make a signature activity unpleasant or inaccessible.

**Connected reward-flow finding:** `_dug` computes a gear reward, but returns into an ambush before offering that gear when misses reach three. After the ambush, the normal reward queue resumes without retaining the dug gear. Ore/material/shard rewards have already been applied. If noise is meant to add a fight rather than forfeit the find, queue the gear until the ambush is cleared. The current merchant explanation only warns about waking enemies.

### 9.10 Sabrina and difficulty: useful modularity, incomplete reward and restriction contract

[The console](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/hub.gd#L559) offers seven modifiers totaling up to 18 Heat. Each point adds 10% TM, and new best Heat pays an account-wide shard bounty. Higher Heat also raises offered item levels by three per point, but the console does not explain that major persistent reward.

**What works:** independent modifiers let a player choose the kind of pressure they accept instead of only raising all enemy numbers. Naming individual restrictions and showing the resulting Heat is understandable.

**Concerns:**

- “Drops Nerfed” halves ordinary random drop probability, but guaranteed elite/boss ore and material quantities bypass that multiplier. Either narrow the description or make the implementation match the intended restriction.
- Hardcore removes Recovery doors and revives, but does not disable healing spells, passive healing, rest-stop recovery, or every other recovery source. That may be intended; its name should not substitute for a precise rule summary.
- Windup reduction affects common attack patterns but not uniformly the fixed-timer boss specials. Players cannot infer which warnings are shortened.
- Best-Heat bounties are shared across characters. After one character earns them, other characters do not get an equivalent milestone reward. Decide whether this favors account progression appropriately or weakens incentives to learn other classes.
- Heat rewards TM even on death, while increased difficulty can change survival time substantially. Measure progression per minute and successful clear time before assuming every rank is a fair reward tradeoff.
- The controls cycle a setting upward and wrap to zero. Lowering a rank requires cycling through higher ones. A direct +/- control and a final rules summary would make preparation clearer.

This is a balance-review agenda, not evidence that a specific Heat combination is currently an exploit. Use representative profiles and actual complete runs to establish that.

### 9.11 Conversations, milestones, and modal ownership

[Story](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/story/story.gd#L19) uses ordered first-match conditions and persistent flags. It is a reasonable small narrative system. [Talker](https://github.com/khaledchoucri/tricksterGodot/blob/c7b27650a182c864aa8c6b2c0ea38d53e86e79a5/scripts/story/talker.gd#L46) shares conversation behavior between the hub and rest stops, which is good reuse. The current content mostly reacts to met-NPC flags, lifetime deaths, clears, and shards found.

**Confirmed content mismatch:** all eight regular characters are available on a fresh profile. Cavalier's first-clear conversation still describes unlocking a second slot containing Bunny. Another conversation describes the first full clear using the Golden Mole, although the current expedition ends after three regions. Return-to-hub text also says Coral Beach is quiet after the complete expedition. These are misleading progress signals, not merely prose preferences.

Lifetime conditions can also imply current possession: Stella checks `shards_found >= 1`, yet says the player is carrying a shard even if all have been spent. Progression triggers should distinguish discovery, possession, region completion, and entire-expedition completion.

**Modal risk:** `_welcome` waits 1.2 seconds and then starts the intro without checking whether another interaction is already active. A player can open preparation UI during that window. `talk`/`converse` and `DialogueBox.play` do not reject overlapping sessions. A focused UI probe started two conversations on the same box; one advance completed both. This confirms the shared-session behavior, not a full interactive reproduction of the introductory race.

**Fix:** one hub interaction owner, with explicit states such as free movement, conversation, service, character creation, and departure. Automatic dialogue should wait or queue until the hub is free. Suspend character-sheet input while a modal owns interaction. Release ownership on completion, cancellation, or scene exit.

**Service repetition:** every normal service visit first passes through dialogue. Preserve one-time and milestone conversations, but consider offering immediate service access after meeting the NPC, with optional conversation alongside it. The target is less repetitive preparation, not removal of NPC personality.

### 9.12 Character creation and departure need reversible preparation steps

The custom-class wizard has a cancel option for the kit, but its graph and tree stages have no Back/Cancel entry. `DialogueBox` only handles Escape when an explicit cancel choice exists, so the player cannot normally back out from those later stages. They must finish the configuration or close the session.

The wizard also commits the custom specification before departing, and selection immediately starts the expedition. A player cannot inspect the completed class in town, compare alternatives, and then decide whether to leave.

**Fix:** keep a draft configuration through all stages, provide Back and Cancel consistently, validate a functional build, and commit only on confirmation. Return to hub preparation after creation. Departure should be a separate action with a concise final configuration summary.

For ordinary departure, preserve the selected character and its preparation without requiring a fresh character-choice menu on every gate approach. For return, show the useful consequences of the previous expedition: newly available services, claimable sets, affordable mastery, and relevant next goals. These can be contextual prompts rather than a mandatory checklist.

### 9.13 Hub verification and implementation order

The existing UI audit already visits NPC menus and checks screen reachability. That deserves credit. It deliberately avoids purchases/refines and starts with an artificially well-funded, restored profile, so it does not verify service transactions or the new-player dependency sequence. The city bot similarly invokes profile/domain operations directly, bypassing the actual preparation flow.

The new isolated hub probe ran successfully under Godot 4.6.3 with no script errors. It reproduced the mastery filtering problem, stale wardrobe stats, stale refined-equipment preview, incompatible Lion loadout, shared dialogue completion, and Job Cloak's use of the pending-level queue. It also checked fresh character availability, the Skill Shrine dependency condition, drill timing values, and set references. Full hub navigation and complete purchase-through-departure play were not verified in this checkout.

**Recommended order:**

1. Make character switching remain in town and enforce loadout compatibility at every boundary.
2. Replace the fake run used for preparation with a rebuildable preview; repair mastery eligibility independently of current held skills.
3. Make purchases, claims, and crafting authoritative transactions that update the preview immediately.
4. Give hub interactions exclusive ownership and make creation stages cancellable.
5. Reconcile restoration dependencies, narrative milestones, and actual unlocks; accurately describe next-rank benefits and crafting/drilling/difficulty rules.
6. Complete collection goals across the existing regions and validate fresh-profile progression before adding another hub service.

**Acceptance scenarios:** a fresh player opens every initially available interaction; interrupted onboarding cannot open two sessions; each restoration unlocks exactly its documented service and benefit; the player buys mastery and immediately sees it in preparation; selected mastery remains manageable on later visits; crafting changes the displayed item; each wardrobe change changes the correct stats; a set claim survives reload with both flag and reward present; characters can be switched and configured without running an expedition; an incompatible weapon never disables the next character's basic; creation can be cancelled at every stage; departure uses the character and preparation that were shown.


## Recommended implementation order

**First: protect player progress.** Stable item IDs; atomic inventory transfers; robust profile snapshots; one terminal run transaction. Acceptance: items and currency are conserved across every outcome, and repeated callbacks cannot award or remove them twice.

**Second: make combat rules dependable.** Snapshot hit targets; shared pausable timing; encounter cancellation; prepare skills before activation; successful-cast-only Clinch escape; authoritative hit results; crossed-window detection. Acceptance: the same action produces a valid result through lethal hits, pause, interruption, and room changes.

**Third: resolve the gameplay contracts.** Recovery model; learned versus equipped skills; transformation transition package; explicit attribute descriptions; terrain/contact rules; persistent-gear difficulty profiles. Acceptance: each available choice is understandable and supports a viable next encounter.

**Fourth: prove complete character routes.** Initially use Buffalo/Bunny for melee, Sheep/Dragon for spell sustain and targeting, Lion for reload, Fox for DA/economy, and Cat/Raccoon for transformation/card constraints. Validate one ordinary and one alternative route per character before adding more jobs or attribute families.

**Then: deepen encounters and prepare online seams.** Expand tactical enemy interactions and boss overlap budgets; introduce character ownership and authoritative commands at existing boundaries. Defer actual online infrastructure until the local combat contract is stable enough to synchronize.
