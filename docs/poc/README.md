# Coral Beach run prototype

A playable roguelite run built on the original Trickster maps: Buffalo (Knight line, with a sword from the original equipment sprites) fights through seven rooms cut from the Coral Beach fields, choosing skill cards and stats along the way, then faces the Real Golden Mole in the Dark Cave.

The original Trickster sprites, maps, sounds and data are placeholders for prototyping. They are copyrighted, so they live in the git-ignored `original_assets/` folder and are generated from your own client install.

## Setup

1. Install Python 3.10+ and Godot 4.7.
2. Generate the assets from a Trickster client (about a minute):

   ```
   python -I tools/setup_assets.py "<path to the client's Trickster folder>" ["<client with the full effects>"]
   ```

   This exports the actors, five Coral Beach maps, the monster stats, the sounds and music, and the original skill effects. A later client (the 2019 one) has the complete effects data (`data/effect/cake.xml`, `cream.nri`); give it as the second path.
3. Open the project in Godot and press F5.

## Controls

| Input | Action |
|---|---|
| WASD or arrow keys | Move |
| Mouse | Aim |
| Left click or J | Sword combo |
| Right click or K | Skill slot 1 |
| Q or L | Skill slot 2 |
| E or ; | Skill slot 3 |
| Space or Shift | Dash (invulnerable, passes through enemies, vaults obstacles when there's room to land, cancels attacks) |
| F or Enter | Talk / read (in Megalopolis); advance dialogue |
| 1 / 2 / 3 or click | Choose a card or stat |
| R | Return to Megalopolis after the run ends |

## Megalopolis

The game starts in Megalopolis Square, the city of a world whose servers have just shut down. You're the last player.

- Don Cavalier, Miranda Watty and Star Gazer Stella have conversations that change as you play (`data/megalopolis/story.json`): who they are, the rollback, the first Harkon Shard, the first clear. The statue's copper plate shows the service termination notice.
- Walk into the **Coral Beach Gate** to start a run.
- Every run ends by banking its Time Marks (TM) and Harkon Shards into your profile (`user://profile.json`). Don Cavalier spends them on **restorations**.
- **System restorations.** A new save starts simple: levels, types and Fighter skills. Each of these brings an original Megalopolis NPC back to the square and turns a system on inside runs:

| Restoration | Cost | Brings back | Turns on |
|---|---|---|---|
| Blacksmith Row | 2,500 TM | Blacksmith Marx | Equipment drops, anvils, shops |
| Job Hall | 5,000 TM + 1 shard | | The Knight job change at the trial |
| Compounder's Stall | 7,000 TM + 1 shard | Compounder Paul | Monster materials, Compounders, monster dens |
| Warehouse | 6,000 TM + 2 shards | Keeper Julio | Portable Ports and heirlooms |

- **GM Console** (4,000 TM and 1 shard) brings back **Guide Sabrina** and her **Server Settings**, our Pact of Punishment:
  - The settings, and what each rank does:
    - Server Load: +15% monster HP
    - Packet Loss: +15% monster damage
    - Lag Spike: shorter wind-ups
    - Bot Swarm: +1 monster per wave
    - PK Mode: an elite in every wave
    - Hardcore Server: no healing doors or revives
    - Drops Nerfed: half the material and ore drops
  - Each rank adds Heat, and every point of Heat banks 10% more TM.
  - Clearing at a new best Heat pays a Harkon Shard for each new level.
  - With the city fully restored, the bot clears 8/8 runs at Heat 0, 7/8 at Heat 6 and 2/8 at Heat 12.
- **Card House** (3,000 TM) brings back **Card Hunter Eugene**.
  - Monsters drop their cards: 2% (more with DA), 15% from elites, 50% from bosses. Cards go straight into his album.
  - Completing a set (Shore Critters, Coral Deep, Coral Beach, The Sands, The Dunes, The Pyramid, Desert Beach) gives a **wardrobe** piece.
  - He also sells pieces for TM and shards.
- **Wardrobe.** The persistent slots (ear, tail, head, face, cape, speed) hold original items, each with small stats and one quirk. A few examples:
  - Buffalo's Horn: +10% damage to elites and bosses.
  - Raccoon's Tail: +20% Galder.
  - Black Sunglasses: crits +25%.
  - Omnipotent Umbrella: −25% projectile damage.
  - Eternal Sunshine: four skill card choices.
  - Levitation Charm: dash 25% farther.

  Wear them through Keeper Julio's warehouse menu.
- **Skill Shrine** (5,000 TM + 1 shard) brings back **Master Louis**. Each skill card's level cap can rise from 5 to 8 with banked materials from its signature monster (Shockwave takes Hard Scales, Sonic Slash takes Cooling Fans) plus Galder. The cost grows with each level.
- **Drill Shop** (3,500 TM) brings back **Driller Marky**, who gives you a Basic Drill and sells deeper ones. The drills use the original Item_DrillParam numbers.

| Drill | Digs to | Cost |
|---|---|---|
| Basic | 20 | free |
| Cleaner | 30 | 4,000 TM |
| Tornado | 60 | 9,000 TM + 1 shard |
| Diamond | 90 | 16,000 TM + 3 shards |

  - **Dig Site** doors start a timing-bar minigame. Strike while the marker is in the green (the gold centre digs half again). DA widens the zone.
  - Depth 5+ brings up ore, 15+ the region's materials, 40+ a piece of gear, and 70+ a Harkon Shard.
  - Three misses wake an ambush.
- **Other restorations** are permanent bonuses: Training Hall (+max HP), Mana Fountain (+MP per room), Rollback Cache (survive one fatal blow per run) and Tutor's Desk (start with a second skill).
- **Pace.** In playtests the systems open over the first 3–4 runs.

## A run

Each run replays a career: Buffalo starts as a level-1 **Fighter** with a Rookie Sword and Shockwave, and crosses two regions (16 rooms).

- **Coral Beach.** Seven combat rooms from the Blue Wave, Passionate Sun, Sunny Beach and Hidden Shore maps, then Master Mong in the Dark Cave. He storms where you stand, raises Mana Shield and, on his last life, throws Mana Rings and Cures himself; three Thief Mongs come with him and five more at half HP, and a Thief Mong that hits you steals Galder until you kill it.
- **Desert Beach.** Seven rooms on Delta Island, the Statue of Anubis and Parasol River.
  - Original monsters at levels 18–33: Fanta Slime, Shell Trap, Golden Mole, Sea Scorpion, Pineapple, Fan Lizard, Sand Demon and Cannon Shell.
  - Then **Tutankhamen** at the Pyramid Steps. He slams up close, fans curse bolts at range, drops three sand coffins around you, and calls Basic Mummies at 66% and 33% HP. He can drop the legendary **Golden Sword** (Pharaoh's Gold: hits can scatter Galder).
  - Desert Beach gear is the original level 25–40 items.
  - Level sync allows +6 here.
- Beating Master Mong gives a Harkon Shard and a Portable Port before Desert Beach.
- Rooms 4 and 7 of each region add elite monsters, and elites also drop gear.
- **Room 4 is the Fighter's trial.** Clearing it changes job to **Knight**: you become the Knight, the Knight skill tree joins the card offers, and you pick a Knight skill.
- Clearing a room grants the reward shown on the door you came through: a skill card, a card upgrade, **equipment**, an **anvil**, a **Compounder**, a **shop**, healing, Galder (with Bronze Fragments) or a Harkon Shard.
- Each door also names a monster: the next room is that monster's **den**, and about half of its waves are that monster. That makes the door a choice of which material you farm.
- **Desert Beach's trial (room 12) is the 3rd job change**: **Gladiator**, or **Mercenary** (the hybrid, which learns the Boxer tree instead of new skills; it unlocks after a Gladiator clear).

### Skills (from the original tables)

The Buffalo and Bunny lines have all 43 of Trickster's Power skills, generated by `tools/power_skills.py` from the client tables:

- **Trees.** `Item_SkillCardParam` sets which jobs learn each skill and its prerequisites.
  - Fighter and Schoolgirl share the 1st-job list (11 skills).
  - Boxer has 10 and Knight 11. Champion adds 5 and Gladiator 6.
  - Duelist and Mercenary learn the other 2nd job's tree.
  - Prerequisites cross jobs. For example, Flash Cut needs Dash and Uppercut.
- **Kind.** `SkillParam2.Type` decides what a skill becomes:
  - **Attacks** (25) are skills that go in the three slots and cost MP.
  - **Passives** (3) are talents with their original trigger. Faint and Guard Break ride on Shockwave; Counter Punch rides on Uppercut.
  - **Timed buffs and debuffs** (15) are talents with the original effect. A buff is always on: Pumping Heart and Adrenaline raise AP, Bull's Eye and Eagle Eye raise AC, and Hyper Beat and Aura of Haste raise DX (attack speed). A debuff is applied by your hits for its original duration: Armor Breaker lowers DP, Shockvibe accuracy, Sense Breaker perception and Luck Breaker luck. Guard blocks a set number of physical hits, and each block returns after the original cooldown.
- **Upgrades.** A skill the original calls an "advanced form" of another is offered only while you have that skill, and it replaces it, taking its slot and its level:
  - Lacerator → Tidal Slash or Tempest Strike, and Tempest Strike → Gale Strike.
  - Piercing Wave → Earthquake Blade.
  - Quad Punch → Tetra Punch.
  - Flash Cut → Mega Flash Cut.

  Prerequisites count an upgrade as its base skill. Earthquake Blade still opens Lightning Strike.
- **Numbers.** Every number comes from the skill's `ESAII_`/`ESAction_` tables: damage % (the tooltip's), cooldowns, ranges, target counts, durations, chances and blocks. A card's run levels 1–5 are the original's levels 1, 3, 6, 8 and 11, so a skill maxed in a run is the original's mastered skill. Mastery's 3 extra levels go past the source: each adds 10% of the Lv 5 value (counts such as Arrow Rush's arrows stay at the original's). A mage's left-click spell keeps its Lv 1 cooldown (the original's grows with level, which would make a free basic attack weaker per second). Skills the original caps at Lv 1 (Dash, Faint, Guard Break, Clinch Release) stay at 1.
- **Scaling, where the two games differ:**
  - In Trickster you keep the base skill and learn the advanced one from Lv 1. Here the advanced one replaces the base, so it keeps the base's level; at Lv 1 it would often be weaker than what it replaced.
  - Damage is the original % of a normal hit (29).
  - MP costs are compressed, because MP pools here are about 100, not thousands.
  - Prerequisite levels of 10–11 out of 11 need Lv 3 here, and 7–9 need Lv 2.
  - Chakra Balance heals a share of max HP.
- **My readings, where the source gives no number:**
  - Hyper Beat and Aura of Haste: a DX step (−1 attack delay) is +8% attack speed.
  - Counter Punch triggers 50% of the time.
  - Tetra Punch: each landed blow adds 25%.
  - Uppercut: 1 s in the air.
  - Blazing Strike: more hits with DX.
  - Berserker: its rage is averaged over its cooldown, and the drain is 1 HP and 1 MP per second while monsters are near.
  - Sense Breaker: lower perception makes monster wind-ups longer.
  - Luck Breaker: makes cursed monsters easier to crit.
- **Still missing:**
  - The original effect sprites and sounds of each skill. The effects are drawn and the sounds are reused.
  - Master Louis's materials are the original's monster drops, most of which aren't in the game yet.
  - The job passives (Sword Mastery, Arena Champion...) are this game's invention, flagged for review.

### Characters

- **Buffalo** fights with a sword or hammer. Fighter → Knight → Gladiator or Mercenary.
- All four characters are playable from the start; you choose who logs in at the gate.
- **Bunny**:
  - She punches with the original punch combo and doesn't draw her weapon.
  - Schoolgirl → Boxer (Boxer's Footwork: +15% punch damage) → **Champion** (Champion's Fury: +25% finishers) or **Duelist**. The Duelist is the hybrid: she learns the Knight tree, and gets +10% skill damage and −10% MP cost. It unlocks after a Champion clear.
  - Bunny is data only (`data/classes/bunny.tres` and four jobs), which proves new classes need no new systems.

- **Sheep** and **Dragon**, the Magic line, cast from range:
  - Sheep: Librarian → Bard (`chr011`) → **Soul Master** or **Witch** (hybrid: learns Magician skills). Her basic attack (left click) is **Mana Ring**: three rings burst around the target.
  - Dragon: Shaman → Magician (`chr012`) → **Wizard** (hybrid: learns Bard skills), **Dark Lord** (dark) or **Priest** (light). His basic attack is **Mana Arrow**.
  - The 3rd-job bodies are `chr019` (magic_f) and `chr020` (magic_m), the server's type_2 + 8.
  - Mana Arrow is the single-target basic and Mana Ring the crowd one: at every stage (each with its supplement at the same level) Mana Arrow out-damages Mana Ring on one or two monsters, and Mana Ring wins from three. The source's growth is kept; only Mana Ring's flat power is anchored lower (Lv 1 hits for 155% where Mana Arrow hits for 230%), a reading of mine.
  - Basic spells cost no MP. Each character is offered only their own basic spell and its supplement (Arrow Rush, Mana Ring Booster). Where a prerequisite asks for the other one, your own stands in.
  - **Casting.** Spells take half the original activation time, with movement locked. Mages are never interrupted by hits (Invincible Casting is innate, so its card isn't offered). Only a dash gets you out of a cast, and it refunds the MP. A cast bar shows under the mage.
  - Mages regenerate 2% of max MP a second; Aura of Mana raises the rate.
  - **Seals and Pacts.** Each Seal (Water, Thunder, Fire, Earth, Wind) opens one element and shuts two, so you can hold at most two Seals. Light Pact and Dark Pact exclude each other. Each skill's Job list decides who may learn it: a Priest can't learn dark magic.
  - **Elements.** Elemental spells are resisted like the original's monster resistances. A monster's attacks carry the element it resists most (my reading), which elemental Shields resist.
  - Held back until they have something to act on: Basic Healing and Med. Cure (no player ailments yet) and Withering Disease (monsters don't regenerate). Revival works as an automatic revive on its 300 s cooldown.
  - Mage base stats (HP 115, MP 160, MA 22, Magic/Sense graph) are my design. The original's stats come only from the build graph.
- **Original skill effects.** Trickster draws skill effects with its own particle system. `cake.xml` defines each effect as a set of emitters with rate, lifetime, sizes, colours, alphas, gravity and velocity, drawing textures from `cream.nri`.
  - `tools/export_effects.py` exports them, and `scripts/fx/cake.gd` plays them.
  - Cards name their effects by phase (cast, flight, hit, lasting, end), matched by action name like the sounds or by the older skill numbering. 86 cards have them.
  - Some early spells have no numbered effect, and the client draws them from informally named data. Hellfire uses the `hell fire` effect.
  - **Mana Ring flies as the client does** too (RingCake, same file). Three rings appear beside you over 0.5 s, flat and spinning at 1000°/s, trailing the original `yun gi` mist. When the group fires, each is kicked back and follows its own random cubic curve to the target, 10 px a frame (60 fps assumed). It then homes in like an arrow and bursts with `eft_skl_m_108_eed` and the `snd_skl_m_108` sounds. The curve's constants and random ranges are the client's; how they combine is partly lost in the decompiled float code, so the first control point's spread is taken at a quarter.
  - **Mana Arrow flies as the client does** (`scripts/fx/magic_flight.gd`, read from `Trickster.bin`'s ArrowCake/ArrowBall code with Ghidra through REA). The arrows (Arrow Rush's count) appear one by one beside you over 0.3 s, ±50 around you and 30 up, spinning flat on the ground at 2000°/s and drifting away from the target. At 0.3 s each is kicked back and waits its own random 0–0.9 s, then rushes in, accelerating at 5000/s² and pointing along its flight. It hits within 50 and gives up after 6 s. So Arrow Rush's arrows land one after another. The sprites are the original `magic arrow` (laid flat) and its spreading `magic arrow jan sang` afterimage. The impact is the client's `eft_skl_m_101_eed`, with the `snd_skl_m_101_sps`/`_sed` sounds. Not reproduced: the `mu sok sung jin` emitter the client adds on impact when it loads. A few (Drip Bomb, Electro Attack, Mana Storm) still have drawn effects until their originals are identified.
  - Readings: sizes are percentages of the texture; "ZAlign" lays a particle flat on the ground; the blend modes are approximated with shaders.
  - `tests/cake_gallery.tscn` renders them.
- **A job change is what Trickster gives**: the job's character and its skill tree. (Earlier builds added techniques, bonus type points and a growth shift; they had no source and were removed.)
- **Looks follow the original.** As in Trickster, a job change turns you into another character (CharacterInfo): Fighter → Knight (`chr010`) → the Power 3rd-job body (`chr018`, Gladiator and Mercenary), and Schoolgirl → Boxer (`chr009`) → `chr017` (Champion and Duelist). Hats, shields, masks, head pieces and ears/tails are drawn wherever that character's own pivot file places them; a piece it has no pivots for doesn't show (in Trickster, fashion stops working after a job change), though its stats still count. `tests/look_gallery.tscn` renders every job with gear.

- **The Trickster** is the custom class.
  - It unlocks after a 3rd-job clear with both Buffalo and Bunny.
  - Create it at the gate: pick a kit (sword, hammer or fists), a type graph preset, and **two skill trees** from Knight, Boxer, Gladiator, Mercenary, Champion and Duelist, plus the Bard, Explorer and Entertainer trees, each of which unlocks once you've borrowed that Echo's rune.
  - It always gets the Fighter tree too, and its passive Data Bleed adds a choice to every skill card reward.
  - The Trickster is built at runtime from the profile; no new systems were needed.

### Echoes and runes

- **Echoes.** After your first clear, elite rooms can be haunted by an **Echo**: the ghost of a former player of another class, in that class's original sprite. They are:
  - the **Bard**, who casts from range;
  - the **Explorer**, who lunges;
  - the **Entertainer**, who spins.
- **Sky-blue runes.** Beating an Echo leaves a rune, the original's cross-class rune. It lends one of that class's skills for the run, in a fourth skill slot (**F**), stronger in Desert Beach:
  - Drip Bomb and Electro Attack scale with **MA**;
  - Fan of Knives and Stone Strike scale with **DA**;
  - Galder Barrage spends Galder and scales with **DP**.

  So Magic, Sense and Charm points pay off for Buffalo too.

### Stats and types

- Trickster's 12 stats in 4 types:
  - Power: AP, AC, DX
  - Magic: MP, MA, MD
  - Sense: WT, DA, LK
  - Charm: HP, DP, HV
- Each level-up, after the fight, you put a point into a type, then train one skill you have (Trickster levels skills with the TM points play earns). A mage's basic spell, and once learnable Arrow Rush or Mana Ring Booster, is always among the choices. Buffalo also grows on his own along his type graph (Power first, Charm second).
- 3, 6 and 10 points in a type unlock its traits:

| Type | 3 | 6 | 10 |
|---|---|---|---|
| Power | Staggering Finish | Extra Swing (the combo gains a swing) | Armor Crush |
| Magic | Mana Flow | Dash Casting | Overcast |
| Sense | Treasure Sense (choose 1 of 2 gear drops) | Smith's Eye (+10% refining) | Lucky Strikes |
| Charm | Light Feet (evade) | Perfect Dodge | Second Wind |

- What the stats do:
  - AP scales combo and skill damage, and DX scales attack speed.
  - MA shortens cooldowns and MP is your mana pool.
  - LK gives crits and refining luck. DA gives better gear rolls and more ore.
  - DP and MD reduce damage taken, and HV lets you evade.
  - Low AC against an evasive monster grazes for half damage, never a miss.
- Press **C** (or Tab) for the character sheet: stats, traits, equipment, load and skills.

### Equipment

- **Six slots:** weapon, hat, shield, innerwear and two accessories. Hats and shields are drawn on the character; innerwear dyes the belt.
- **Items:** 30 real Trickster items from Coral Beach's level range (`data/items/`), with their original stats, weights and icons. Deeper rooms drop higher-level items.
- **Drops** roll stats around the base values, and can roll an original prefix: Sharp, Shrewd, Sensible, Solid, Clever, Spell or Lucky. DA raises roll quality.
- **Weapon families** change the combo. Swords use `data/combos/sword.tres`. Hammers (Pretty Red Hammer, Bamboo Stick) use `data/combos/hammer.tres`: slower and heavier, ending in a full-circle ground pound.
- **Weight:** gear weighs what it did in Trickster. Over your load limit (WT / 4) you move slower and dash less often.
- **Anvils** refine the weapon, hat or shield with Bronze Fragments and Galder.
  - The success chance falls from 95% at +1. The chance is shown, and LK raises it.
  - From +5 up, a failure can drop the item a level.
  - Monsters drop fragments (elites always, the boss three), and so do Galder rewards.

### Materials and compounding

- **Signature materials.** Every monster drops its own material (`data/materials/`): 20% per kill, 2 from elites, 3 from the boss, and DA raises the chance.

| Monster | Material | Compounds |
|---|---|---|
| Torobbie | Baby Carrot | HP |
| Tottochi | Acorn Nut | LK |
| Bad Fury | Sharp Leg | AP |
| Little Cora | Twinkle Star | DA |
| Blue Penguin | Cool Ice | Water attack |
| Bustshell | Hard Scales | DP |
| Clione | Cool Spring Water | MD |
| Thief Mong | Yellow Monkey Fur | DX |
| Master Mong | Master Mong's Fur | HV |

- **Compound slots.** Gear has the original item's compound slots. Drops can roll one more slot, and Shrewd items always do.
- **Compounder rooms** put 3–4 of one material into a free slot. The stat rolls in the material's range (the original ranges where the item existed), leaning toward the middle, with DA raising it.
- **Water attack** adds that percent of each hit as water damage, less the monster's water resistance.
- **Shops** sell two pieces of gear, Bronze Fragments, a material bundle and a potion for Galder.

### Warehouse and heirlooms

- **Portable Port.** It appears after the job change and again when you clear the run. There you can send one item home to **Keeper Julio's warehouse** in Megalopolis, with its refines and compounds, and save your progress.
- **Heirlooms.** In the city, Julio lets you pick one stored item to carry into every run.
- **Level sync.** Coral Beach syncs a carried heirloom down. Its refine counts up to +3, and its base stats scale with the room's level (3 + 3 per room), so a Bamboo Sword starts weaker and is at full strength by about room 5.
- **Death is a rollback.** Changes to a stored item since the last Port are undone, and the log says which.
- **Leftovers bank.** With the Warehouse restored, a run's leftover Galder, Bronze Fragments and materials go to the city: all of them on a clear, half after a rollback.
- **City crafting.** In Megalopolis, **Blacksmith Marx** refines stored items with banked Galder (3× an anvil's price) and Bronze, at the anvil's odds. **Compounder Paul** compounds banked materials into stored items' free slots. Heirlooms keep growing between runs.

### Balance

`tests/playtest.tscn` is an autopilot that plays whole runs and reports how far it got, room times, damage taken, gear and leftovers:

```
godot --headless --fixed-fps 60 res://tests/playtest.tscn -- runs=10 build=mixed
```

The `build` option is `power`, `magic`, `sense`, `charm` or `mixed`. Add `city=full` to start with every restoration bought, `heat=N` to play at a Heat, `class=bunny`, `god=1` to measure the whole curve without dying, and `tag=x` to run several bots at once.

The report includes combat feel: hits and seconds to kill normal and elite monsters by depth, and how hard monsters hit as a share of max HP. Damage scales linearly with its stat, as in Trickster (damage = stat x skill %): twice the starting MA is twice the damage. Monsters are as tough and hit as hard as their original level makes them (`Run.mob_hp`, `mob_hit`), the same in every room: deeper rooms bring a region's higher-level monsters, and a growing character outgrows them. Defence (DP against weapons, MD against spells) weighs against the attacker's own AP or MA. Bosses keep their own HP but wear their region's median armour. Region knobs (`hp_scale`, `damage_scale`) set each region's step up. With every restoration bought, a Buffalo bot clears about 2 runs in 3 and a Bunny bot about 1 in 9. The bot is a weak stand-in for a player (it chases badly with short reach), so treat its numbers as a floor.

Also:

- MP refills from combo hits and on entering a room.
- Scenery that hides Buffalo or an enemy fades, and Buffalo shows as an outline while hidden.
- Death is a "rollback": the results screen shows what the run earned, and you return to Megalopolis.

## Project layout

| Path | Contents |
|---|---|
| `scenes/` | Game, player, enemy, boss, door and projectile scenes |
| `scripts/autoload/` | `Run` (run state), `Profile` (saved progress), `Audio`, and `Events` (signal bus) |
| `scripts/data/` | Resource classes: `RegionData`, `RoomData`, `EnemyData`, `CardData`, `ClassData`, `JobData`, `ItemData`; `Stats` (the 12 stats, types and traits) and `GearItem` (a rolled item) |
| `data/coral_beach/` | The Coral Beach region: rooms, enemies and cards as `.tres` files |
| `data/megalopolis/` | The hub: its room, people (`NpcData`), restorations (`RestorationData`) and story |
| `scripts/story/`, `scenes/ui/dialogue_box.tscn` | Conversation selection and the dialogue box |
| `scenes/hub.tscn`, `scripts/hub.gd` | Megalopolis between runs (the main scene) |
| `scenes/tools/` | Art pipeline tools: pose guides, art import, art lab |
| `scripts/player/` | The player: core states and dash, `ComboAttack` (basic attack chain), `SkillCaster` (skill slots) |
| `scripts/skills/` | One script per active skill, extending `Skill` |
| `scenes/hud.tscn`, `scenes/ui/`, `ui/hud_theme.tres` | The HUD, its skill slot and pick option scenes, and its theme |
| `data/combos/` | Basic attack chains as `ComboData` (sword for Buffalo, punch for Bunny later) |
| `scripts/fx/` | Effects: slashes, waves, bolts, the thrown blade, tornado, sparks, health bars, silhouette |
| `scripts/` | Room building, combat, AI, HUD, held weapon and props |
| `tools/` | Converters for Trickster sprites, maps, data and audio |

Actors announce effects (hit-stop, shake, damage numbers, deaths) on `Events`; the game and HUD present them. Rooms own their enemies and pass them their references.

To add a skill, write a script extending `Skill` in `scripts/skills/`, create a `CardData` with `kind` Skill, its MP cost, cooldown and that script as `behavior`, and add it to `region.tres`.

To add a conversation, add an entry to the NPC's list in `data/megalopolis/story.json`. Entries are checked in order and the first whose conditions hold is used; conditions are story flags (`met_cavalier`, `!mir_remember`) and run statistics (`deaths>=1`, `clears>=1`, `shards_found>=1`). `set` lists flags to set afterwards, and `"then": "restore"` opens the restoration menu.

To add a room, create a `RoomData` resource with a map name and a rectangle (`tools/find_rooms.py` suggests open areas) and add it to `region.tres`. To tune a monster, edit its `EnemyData`; the base numbers for each attack pattern are in `Enemy.KINDS`.

## Tests

```
godot --headless --path . res://tests/smoke_test.tscn
```

The test plays through room loading, combat, every skill, the dash vault, scenery fading, pathfinding, card and level-up picks, doors, Clione's projectiles, the boss and its summons, death and banking, then Megalopolis: its people, conversations, flags and restorations. It uses a throwaway profile, never your save. It also checks the skill rules (upgrades replace their base, buffs and debuffs work), and guards progression: damage doubles with doubled MA, monster HP comes from the original level, and a mage is always offered its basic spell's level-ups and Arrow Rush or Mana Ring Booster.

`tests/ui_audit.tscn` (run windowed) fills a profile to its limits and opens every screen: every NPC menu and submenu, every pick list, the character sheet, the HUD and results. It flags anything off screen, options a player can't reach and cut text, and saves a screenshot of each. Use `size=WxH` for other windows and `noscale` for the editor's embedded game view.

## Reference

- `timing-reference.md`: Hades II timing values the combat started from.
- `map-format.md`: the Trickster map file format.
- `actor-art.md`: what actor sprites and weapons need to provide (for the AI art).
- `qa-backlog.md`: known issues to fix.
