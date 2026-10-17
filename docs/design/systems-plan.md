# Last Login: game systems plan

## Status (2026-10-17)

Built:
- 12 stats in 4 types with traits.
- Two regions (Coral Beach, Desert Beach) with job changes 1st → 2nd → 3rd. Buffalo becomes a Gladiator or Mercenary; Bunny becomes a Champion or Duelist.
- Six run-gear slots, refining, compounding with monster materials, monster dens and shops.
- The warehouse, heirlooms with level sync, Ports and rollback.
- City restorations that switch systems on.
- Server Settings (Heat).
- Monster cards, card sets and the six-slot wardrobe.
- The Skill Master.
- Echoes and sky-blue runes.
- Drilling.
- The custom Trickster class.

Still to do:
- Type skills, the original stat-locked skills.
- A guardian companion (pets).
- Spell cards.
- More regions.
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
more later). Passing one either adds a **trait** that changes play, or puts
that type's **type skills** into your offers (the original's Sense-only and
Charm-only skills, later). Built in the first slice:

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

### Heirlooms: the long game

When you reach a save point, you may **send one run item home** to the
warehouse, with its refines, compounds and rolls intact. At the start of a run
you may equip one heirloom (more slots unlock later). Your heirloom keeps
improving: refine it further in runs and save again.

That's Trickster's real endgame: a sword you've carried for 20 runs, now +9 with
fire and crit compounds.

**Level sync stops it trivialising the early game.** Refine levels on an heirloom
are capped by region: +3 in Coral Beach, +6 in region 2, full power at the end.
Level-locked dungeons are a familiar MMO rule. Your +9 sword still feels strong
early on, and it comes into its own when it counts.

### Death is a rollback

Death ends the run, as in Hades. What happened since your last **save point**
(a Portable Port at each region's end) rolls back: heirloom upgrades, the item
you meant to send home, and banked materials. Anything you saved before that is
safe. A refine attempt just before a boss is a real gamble, and it's the
server's oldest meme.

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
| Warehouse | the Warehouse Keeper | sending items home, heirlooms, appearance transfer |
| Skill Shrine | the Skill Master | raising skill caps with monster materials (permanent hunting goals) |
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
