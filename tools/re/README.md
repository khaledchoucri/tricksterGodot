# Reverse-engineering tools

How Last Login reads behaviour out of the original client (`Trickster.bin`, the 2019 client) when the data tables don't hold it: skill motion, effect and sound names, the gun cycle. Paths are in `re_config.py` (override them with environment variables of the same names). Scratch output goes to `work/` (git-ignored).

Needs Ghidra 12.1.x and JDK 21. REA (the `reverse-engineer-anything` MCP server) is optional: its `rea_driver.py` session is handy for one-off lookups, while the batch work goes straight through Ghidra headless.

## Pipeline

1. **Find a class's code.** `python vtables.py out.json '<class regex>'` reads the MSVC RTTI (TypeDescriptor → CompleteObjectLocator → vtable) and lists each class's virtual functions. Functions shared by many classes are engine code; the few that belong to one class are its own. Skill classes are `ESA<ActionName>`, named after the skill's `ESAction_` table.
2. **Decompile.** For call trees from seed functions, use `DumpTree.java`; for a flat list of addresses, use `DumpFunctions.java`. Both run through Ghidra headless: they define functions Ghidra missed (many vtable entries aren't marked), decompile them and write `<addr>.c` files.
   ```
   analyzeHeadless <proj dir> tr -import <Trickster.bin> -scriptPath tools/re \
     -postScript DumpTree.java <seeds.txt> <out dir> <depth> <max callers> -deleteProject
   ```
   A seed line is `0x<addr> <label>`. Callees with more callers than `<max callers>` are skipped as engine helpers.
3. **Read constants.** The decompiler shows globals as `_DAT_00acXXXX`, and `python consts.py 0x<addr>...` prints their float and double values. Where it drops x87 float maths, `python x86dis.py <start> <end>` disassembles with capstone (`pip install capstone`), annotating each constant it reads.
4. **Effects and sounds.** `tools/client_fx.py <work dir>` collects the cake and sound names each skill's class plays into `tools/client_effects.json`, which `tools/skill_trees.py` uses.

## Pitfalls

- **REA can decompile the wrong function.** Given an address that isn't a function Ghidra knows, `procedure_pseudo_code` silently decompiles whatever sits at that *file offset* instead. Check that the function name in the output matches the address asked for, or use the Ghidra scripts above.
- **Obfuscated values.** Some values (the gun table) are stored through byte lookup tables (`DAT_00af8a78[...]`, the client's anti memory-hack). The logic still reads plainly.
- **Server-side formulas.** Damage formulas and what flags such as the gun's "power shot" do are server-side; only the client's half is here.

## Read so far

- **Mana Arrow and Mana Ring flight:** ArrowCake/ArrowBall and RingCake, translated in `scripts/fx/magic_flight.gd`.
- **Skill effects and sounds:** every Power, Magic and rune class's, in `tools/client_effects.json`.
- **Melee hit:** MeleeAttack 0x43f560.
- **The gun:** GunAttack 0x440680 and GunProcessHandler 0x50f760 (see the README's Sense notes).

## The server (GameServer.exe)

Set `TRICKSTER_BIN` to `vm-files/TS_TUpdate/GameServer1/GameServer.exe` and the same tools read the server, where the damage formulas live. The character stat block is a run of dwords from +0x230 in MonsterParamEx2's order: AP, AC, DX, MaxMP, MA, MD, MaxWT, DA, LK, MaxHP (+0x254), DP (+0x258), HV (+0x25c); current HP is +0x1bc.

- **Skill dispatch:** 0x724020 switches on the ESAction id (byte table 0x725504, jump table 0x7252ac, base 0x436); ids in the default case run in their own ESA class. The per-action table rows are built by the factory 0x685240 (Ratio at +4, ApplyRatio at +0, which is the hit chance, not damage).
- **Physical hit** (0x59c000 → 0x59aef0): (attack − 0.75 × target DP) × the PvP factor; a critical uses attack × 1.5 (0x59af40). Each skill computes its own attack:

| Skill | Attack (ESAction handler) |
|---|---|
| Power Blow | AP × (Ratio + Titanium Wrist) (0x727fe0 → 0x6cddc0) |
| Final Blow | (AP + (MaxHP − HP) / 10) × Ratio (0x72a260) |
| Volley Kick, Sharp Scream | (AP + 16 HV) × Ratio × 0.75 (0x72b990, 0x740860) |
| Raging Nail | (AP + 16 HV) × Ratio × 0.5, against DP × DisDefenceRatio % (0x73ea00) |
| 2 Hit Combo | AP × Ratio × (0.2 × Power Blow lv + 1), then (AP + 16 HV) × Ratio × 0.75 × (0.2 × Volley Kick lv + 1) (0x737460) |
| Wild Nail | 16 HV × Ratio (0x735330) |
| Beast Claw | AP × Ratio (0x732fb0) |
| Heavy Hit | (AP + HP / 8) × Ratio (0x73eda0) |
| Siren Song | (HP × 0.1 + DP × 0.5) × Ratio (0x7312b0) |
| Card Strike | (AP + 8 HV) × Ratio × (1 − distance / Radius) (ESACardThrow 0x6c8ff0) |
| One Pair | (AP + 8 HV) × Ratio (0x7308a0) |
| Full House | (AP + 8 HV + 8 LK) × Ratio (ESAFullHouse 0x6dcb30) |
| Card Soldier | (AP + 8 HV) × DamageRatio × (card number / 6 + 0.1) (ESASummonSoldier 0x6fc9c0) |
| Galder Thrower, Barrage, Fist Full | Galder × Ratio, no DP (ESAGellderHit, ESAMultiGellderHit, 0x73dbb0) |
| Furious Galder Throw | a rolled 1/200/…/1000 Galder × Ratio, no DP (0x73df00) |
| Impelling Rage, Power Charging | the magic path 0x59c230: (power × (MA − 49) / 100 − 0.9 MD) |

- **Gun hit** (0x59b310 → 0x59d440): 20 × (AC − 49) + Gun AP + 20 − 30 × HV.
