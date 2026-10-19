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
