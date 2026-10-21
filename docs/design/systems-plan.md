# Last Login: game systems plan

## Status (2026-10-21, read from the code)

Built:
- 12 stats in 4 types with traits at their thresholds.
- Eight characters in four lines, each through 1st, 2nd and 3rd jobs (36 jobs): Buffalo and Bunny (Power),
  Sheep and Dragon (Magic), Fox and Lion (Sense, with the gun cycle), Cat and Raccoon (Charm, with Galder skills
  and the beast forms as permanent talents). Hybrid 3rd jobs unlock after a clear.
- 229 skill and talent cards from the original tables. Upgrades replace their base, buffs are talents, and
  supplements change their skill.
- Three regions (Coral Beach, Desert Beach, Caballa Relics), nine rooms and a boss each, elites at the 4th and
  8th rooms, and a job change after the 4th in the first two. A rest stop at the original's gate follows the
  first two bosses (32 rooms): half of max HP and MP back, Keeper Julio and the warehouse swap. 23 monsters with five attack patterns, three bosses
  (the Golden Mole, Tutankhamen, Tombeth).
- Six run-gear slots, refining, compounding with monster materials, monster dens and shops. Gear comes from
  the original item tables in tiers up to level 65 (the Relics get the original's level-50 and level-65 lines,
  written by `tools/gear_items.py` and `tools/gun_items.py`).
- The warehouse and the loadout (worn in every run, designed on the equipment window), Ports and rollback.
- Megalopolis: 11 people, 12 restorations that switch systems on, and the story.
- Server Settings (Heat), monster cards, card sets and the wardrobe, the Skill Master, Echoes and sky-blue
  runes, drilling, and the custom Trickster class.

Still to do:
- A guardian companion (pets).
- Spell cards.
- More regions (Seabed and Swamp come next in the original's field chain).
- Monster tactics: the original's monsters cast skills (Aposis's Mana Arrow, Mimic's charge); ours use attack
  patterns.
- The fashion tab.



Draft 2, 2026-10-17. Draft 1 listed Trickster's systems. This draft decides
what each one is *for* in a Hades-like run, changes what doesn't fit, and cuts
what doesn't earn its place.

## The idea in three lines

1. **A run is your whole MMO career in 40 minutes.** You log in as a level-1
   Buffalo and log out as a 3rd-job hero. Every level-up, job change, lucky drop
   and +5 refine from years of Trickster gets packed into one run.
2. **The city is the server coming back online.** Each NPC you bring back
   switches one Trickster system on inside your runs. The city's progression
   *is* the game getting deeper.
3. **Your warehouse keeps the stories.** Each run you can save one item home.
   Over many runs those items become the gear you've invested in for real,
   which is Trickster's actual endgame.

Everything below serves one of those three.

---

## 1. Stats: choose a type, gear tunes the stat

**Decision:** keep all 12 Trickster stats, but on level-up the player picks one
of the **4 types**, not one of 12 stats.

Why:
- Picking from 12 mid-run is paperwork, and half of them (MD, AC) are dull to
  pick on their own.
- Picking from 4 is a real identity choice. It's also how Trickster itself works:
  the type graph at character creation decides how stats grow.
- The 12 stats still do the detailed work. Gear rolls, compounds and monster
  stats all use them. So gear is where you fine-tune; the type is where you
  choose what you are.

| Type | Raises | What investing in it does to your run |
|---|---|---|
| Power | AP, AC, DX | Hit harder and faster. The straightforward choice. |
| Magic | MP, MA, MD | More mana and stronger skills: a skill-spam run. |
| Sense | WT, DA, LK | **The greed type.** Better drops, crafting odds, dig spots, crits. Weaker now, richer later. |
| Charm | HP, DP, HV | Survive, evade, counter. Opens Charm skills that punish attackers. |

Sense is the important one. A roguelite needs a "spend now to profit later"
choice, and Trickster gave us one with a stat type built around loot, crafting
and drilling.

### Thresholds change how you play

Each type has thresholds at **3, 6 and 10** chosen points (the first slice;
more later). Passing one adds a **trait** that changes play. (An earlier draft
also had type-locked skills, "the original's Sense-only and Charm-only skills";
the original has none: all 282 skill cards are learned by job, and the few for
every character are event fireworks, couple emotes and GM skills.) Built in the
first slice:

| | 3 | 6 | 10 |
|---|---|---|---|
| Power | Staggering Finish: finishers stun | Extra Swing: +1 combo swing | Armor Crush: finishers expose |
| Magic | Mana Flow: +3 MP per hit | Dash Casting | Overcast: pay HP when out of MP |
| Sense | Treasure Sense: choose 1 of 2 gear drops | Smith's Eye: +10 % refining | Lucky Strikes: crits drop ore |
| Charm | Light Feet: +8 % evade | Perfect Dodge: dashing through an attack resets the dash | Second Wind |

Each class grows automatically along its own graph (Buffalo is Power first,
Charm second), so your picks push a build further rather than keeping it alive.

Under the hood: accuracy and evasion never cause a whiff. Low accuracy against
an evasive target gives a **graze** (half damage), and your own evasion is a
chance to auto-evade a hit.

---

## 2. Jobs: the run's arc

**Decision:** every run goes 1st job → 2nd → 3rd. The city decides which branches
you may choose.

```
Lv 1 Fighter ──(region 1 boss)──▶ Knight or Boxer* ──(region 2 boss)──▶ Gladiator or Mercenary*
                                                       * once unlocked in the city
```

- Skill offers come from your current job's real skill tree, with its real
  prerequisites (Hyper Beat needs Bull's Eye 10 and Burning Rave 10; Tidal Slash
  needs Lacerator 10). Taking a skill early opens deeper ones later, so each
  run has a build path, much like Hades's duo boons.
- A job change is a big moment: a new tree, a new passive, maybe a new combo
  finisher, and a choice of branch.
- Hybrid 3rd jobs (Mercenary learns Boxer skills, Duelist learns Knight skills)
  are the most interesting picks, and they lead into the custom class.
- Until we have a second region, the first job change can be a trial room
  halfway through Coral Beach.

### The custom class

At the endgame you get the **Trickster**, the word the original client already
has in its job strings. You set its type graph (the original's character
creation screen), pick a weapon family, and pick two skill trees from any jobs
you've unlocked.

In the fiction, the dying server's class data has started leaking together and
you're the only one who can use it.

---

## 3. Gear: two layers with different speeds

The original has 14 slots that carry stats. They split cleanly by how often they
change, so each gets its own job.

### Run gear: the six core slots, found and crafted during a run

**Weapon, Hat, Shield, Innerwear, Accessory 1, Accessory 2.** These are the slots
that refine and take compound slots in the original. They drop during the run
and are swapped often. This is where loot excitement lives.

- **Weapon family changes your combo.** Sword, hammer, club and knuckles each get
  their own `ComboData`. That's Hades's weapon variety at almost no cost, since
  the separate held-weapon system already swaps sprites.
- **Legend weapons change a skill or the combo** (Blood Sword: the finisher heals).
  Like Hades's Daedalus hammer, but you find them as loot.
- **Sets** reward pieces you find during the run. A heirloom lets you plan a set
  across runs.

### Wardrobe: the eight slow slots, kept between runs

**Ear, Tail, Head, Face, Cape, Speed accessory, Drill, Guardian.** In Trickster
these were collectible extras that came with small stats. In ours they are the
**persistent layer**, chosen in the city before a run:
- Earned from monster card sets, story, recipes and the Job Master. Never random drops.
- Each gives a small stat and one quirk (Cat's Ears: footsteps don't wake sleeping
  monsters; Angel Wing Cape: the first fatal hit each run is survived).
- They replace the four flat restorations and work like Hades's keepsakes,
  except you wear several at once.
- Fashion slots (body, pants, shoes…) come later and are cosmetic only.

### The loadout: the original's equipment window, planned before each run

Decided with the user, 2026-10-21 (progression revised the same day). It replaces heirlooms and level
sync; the build order is at the end.

**The window is the original's** (`data/UI_nori/EquipUI.nri` / `.ucf`): 13 slots around the character
and a 10-slot fashion grid below it.

| Slots | Original item types | Where the items come from |
|---|---|---|
| Weapon (guns included), Shield, Hat, Belt (innerwear), Necklace, Ring | 2, 8, 3, 4, 7 | drops, shops, crafting; kept in the warehouse |
| Ears, Tail, Cape, Sprint | 17, 18, 34, 7/53 | the wardrobe: earned from card sets or bought, owned for good |
| Bracer, Drill, Pet | 7/62, 3/6, 13 | drops and the city (the pet is the guardian companion) |
| Fashion: head, face, hand item, top, coat, hands, socks, shoes, bottom, belt | 24, 25, 23, 19, 21, 26, 27, 5, 20, 22 | the wardrobe's look; no stats, as in the original |

- Reading: the slot next to the drill is the bracer, read from its icon; check it in the client's equip code.
- The same window is the in-run equipment menu: one screen shows everything you wear.

**A run is one chunk of three regions.** Chunk 1 is Coral Beach, Desert Beach and the Caballa Relics. Each
region has ten rooms (nine and its boss), and a **rest stop** follows the first two bosses: 10 + 1 + 10 +
1 + 10 = 32 rooms. Clearing a chunk opens the next (Seabed, Swamp...), which starts at the level the one
before ends at. Monsters keep their original levels, so a chunk's gear is what makes the next one possible.

**The rest stop** (after the 1st and 2nd region bosses; Hades's rest rooms) has no encounter. It has a story
point, a free heal of 50% of max HP and MP, and the warehouse, where you can swap what you carry with what's
stored.

**Progression: the world's item level.** Decided with the user, 2026-10-21. The loadout has no gates (no
MinLevel, no weight, no level sync): you wear what you've kept from room 1, and runs get easier as the
collection grows. The challenge comes from the world rising to meet it.
- **Each region has an item-level band** (`RegionData.gear_levels`, first room to boss: Coral Beach 1-22,
  Desert Beach 25-46, the Relics 49-70).
- **Heat raises every band** (Ours: about 3 item levels per point; Server Settings reach 18 Heat). The
  original's higher ladders fill it: the item tables go past level 120, and the Relics' own drop tables
  (Old Sabre, Dao, Kaldo, Guardian Shield, level 110 and up) become the Relics' rewards at high Heat.
- **Monsters rise with Heat at the same pace** (Server Load and Packet Loss scale their HP and damage
  linearly), tuned so a loadout earned at one Heat faces the next as a climb, not a wall or a walk.
- So your best gear is about what the hardest Heat you've beaten drops. A lower Heat is a stroll (the power
  is felt), the next one is a challenge, and its later regions drop gear above your loadout, so finds
  keep mattering inside a run.

**Three layers of progression:**
1. **A run** (minutes): level 1 to about 54, the job changes, the deck and the run's finds. It resets.
2. **Between runs** (hours): the loadout, the starting skill (Master Louis), refining and compounding
   stored gear in the city, the wardrobe, the warehouse's size, and the lost bag.
3. **The world** (the long arc): Heat raises stakes and rewards within a chunk; chunks add places; the
   city's restorations and people grow around it.

**Weight.** Worn gear no longer counts against an equip load. WT is how much a run carries (decided with
the user, 2026-10-21), as the original's MaxWT: monster materials and Bronze Fragments weigh their original
Weight, and what doesn't fit is left behind.

**What you carry is at stake.** Deviation (user, 2026-10-21): the original's death costs EXP, not items.
- Gear you take in or find, unless it's banked, drops in a **lost bag** in the room where you die.
- A later run that reaches that room picks the bag up. Die before then and it's gone. There is one bag at a
  time: a new death replaces it.
- **Banking:** sending an item home at a Portable Port or a rest stop makes it safe, and you stop wearing
  it for the rest of the run (decided with the user, 2026-10-21), so safety costs power.
- Worn gear no longer rolls back at a death: it goes into the bag with its progress, and a clear brings it
  home with its progress. The bag arms once you step clear of it, so one left at a room's spawn is found
  by walking onto it.
- Wardrobe pieces are never at stake.

**The warehouse is the original's grid** (`WareHouseUI.ucf`): 8 x 3 = 24 items to start. Each upgrade
adds a row of 8, up to 8 x 10 = 80, bought with Harkon Shards (or a boss currency). Storage space is
what forces the choice of what to keep.

**Balance targets** (measured by bots):
- Fresh profile, Heat 0: at most 1-2 items sent home, and the chunk cleared under about 10% of the time.
- A loadout earned at Heat N clears Heat N+1 at a similar, modest rate.
- A lower Heat than your loadout clears quickly.

**Build order:**
1. Ten rooms per region (elites, the trial and the bands follow). Done.
2. Rest stops after the 1st and 2nd bosses: heal, story point, the warehouse. Done.
3. The equipment window with the 13 slots (done), then the new slot types' items.
4. Heat raises the gear bands; the original's higher item ladders fill them. Done.
5. The loadout before a run; worn gear stops counting against the load; heirlooms and level sync removed. Done.
6. The lost bag and banking. Done.
7. Warehouse rows and their price (ours: row 4 costs 1 Harkon Shard, each after it one more). Done.
8. Bots for the three targets, and tuning Heat's monster scaling to them.

---

## 4. Crafting happens in rooms

Trickster's crafting systems become **room rewards** on our doors. That's where a
roguelite's decisions live, and the door choice is already in the game.

| Door | What happens | The decision |
|---|---|---|
| Skill | 1 of 3 skills from your job tree | build path |
| Gear | a run-gear drop | swap, keep or scrap |
| Anvil (Refiner) | refine with ore and Galder, odds shown; successive tries get riskier; a duplicate item can be forged in to raise stats | how far to push your luck |
| Compounder | put a monster material into a compound slot, which rolls its stat | which slot, which material |
| Tempering shrine (rare) | reroll an item's stats from −25 % to +35 % | gamble a good item for a great one |
| Dig site | a timing-bar drilling minigame for ore, materials and the odd ambush | time, and is the drill worth it |
| Shop | Galder for potions, ore and gear | spending now |

**Monster materials make fights matter.** Each monster drops a typical material
with its own compound stat (a Clione drops a water-attack material; the Bear
Fur family gives DP). A door that shows which monsters are in the room becomes
a crafting choice: "I need water attack, so I'll go through the Clione room."

The odds come from the original tables, retuned for a run: +1 to +3 nearly safe,
+4 to +6 a real gamble, +7 and up for heirlooms over many runs. A failure at +5
and above can drop a level, never destroy the item.

---

## 5. The city: each NPC switches a system on

Restorations stop being stat bonuses. Each one brings back an NPC, and that NPC
**turns on one Trickster system inside runs**. Run one is simple: levels, types
and Fighter skills. Depth arrives as you restore the server, which is how
Hades paces its unlocks and how the story already works.

| Restore | Brings back | Turns on in runs |
|---|---|---|
| Blacksmith Row | the Refiner | gear drops, anvil rooms, forging |
| Compounder's Stall | the Compounder | compound slots, monster materials, compound rooms, recipe compounding in the city |
| Job Hall | the Job Master | job change at bosses; branch-unlock quests ("clear Coral Beach as Knight without dashing") |
| Warehouse | the Warehouse Keeper | sending items home, the loadout, appearance transfer |
| Skill Shrine | the Skill Master | mastering a skill with monster materials to start runs with it, one level higher per mastery (permanent hunting goals) |
| Card House | the Card Collector | monster cards, a bestiary, set rewards that grant wardrobe items |
| Drill Shop | the Drill Merchant | dig sites, drill upgrades |
| Guardian Shrine | the Guardian | a persistent companion with runes |
| GM Office | the last GM | Server Settings: optional difficulty ("PK Mode", "Lag Spike", "Hardcore") for better rewards |

Each NPC has a story beat about the shutdown, using the existing `story.json` system.

### Guardian and runes

The guardian is the one companion (pets fold into it). It grows across runs.
Runes found in runs give it attacks: red melee, blue ranged, purple elemental,
yellow marks and counters.

**Echoes** are ghost players: elite fights against the shadow of a former player
of another class, using that class's skills. They drop **sky-blue runes**, the
original's cross-class rune, which let you borrow one of that class's skills
for the run. Echoes preview future classes and make the custom class feel earned.

---

## 6. Cut or deferred, and why

| System | Decision | Why |
|---|---|---|
| Allocating all 12 stats | changed to 4 types | readable choices; the 12 stats still matter through gear |
| Weight as inventory limit | WT = equip load only | inventory juggling mid-combat isn't fun |
| Pets | folded into the guardian | one companion system, not two |
| Fashion slots | later, cosmetic | art cost, no gameplay |
| A separate Mastery XP track | cut | Time Marks + Shards already do the job |
| Spell cards | later, a rare reward | cheap to add, not core |
| Refine odds to +10 at 0.1 % | retuned | MMO grind, not roguelite pacing |

---

## 7. First slice: prove the career run is fun

One region, no new art beyond icons:
1. The 4-type level-up with thresholds, the 12 stats underneath, and the damage pipeline.
2. Fighter → Knight job change at a trial room, with skill prerequisites.
3. Run gear in the six core slots, drops with rolled stats, two weapon families.
4. Anvil rooms with refining.

If a run already feels like a compressed career, the rest (compounding,
warehouse, wardrobe, guardian) builds on a loop that works.

## 8. Questions for you

1. **The two-layer split.** Six run-gear slots found each run, plus eight
   wardrobe slots kept between runs. Does that match how you remember Trickster's gear?
2. **Heirlooms with level sync.** Is one saved item per run, capped by region,
   the right amount of persistent gear?
3. **Systems unlocking through the city.** Is it OK for early runs to be simple,
   with the depth arriving as you restore the server?
