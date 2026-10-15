# Combat timing reference

Values read from Hades II's shipped data files (`Content/Game/Weapons/PlayerWeapons.sjson`, `Content/Game/Units/PlayerUnits.sjson`, `Content/Scripts/EnemyData_*.lua`) on 16 Oct 2026. They are reference measurements for tuning, not copied code. Frame counts assume 60 frames per second.

## Player

| Value | Hades II | PoC starting value |
|---|---|---|
| Move speed | 540 units/s | 175 px/s |
| Dash duration | 0.20 s (`BlinkDuration`) | 0.20 s |
| Dash distance | 320 units (`WeaponRange`), about 0.6 s of running | 115 px, about 0.65 s of running |
| Dash invulnerability | 16 frames, about 0.27 s | 0.27 s |
| Dash recharge | 0.74 s clip regen | 0.42 s cooldown after the dash ends |
| First swing wind-up | 0.06 s (`ChargeTime`) | hit lands from 0.09 s |
| Attack lockout | 6 frames, about 0.10 s | dash-cancel from 0.08 s |
| Cancelable lock | 8 frames, about 0.13 s | next combo hit from 0.14 s |
| Movement locked | 11 frames, about 0.18 s | movement free from 0.24 s |

## Enemies

| Value | Hades II | PoC |
|---|---|---|
| Wind-up (`PreAttackDuration`), 87 entries | median 0.75 s; middle half 0.2–1.15 s; max 4 s | Torobbie 0.6 s, Tottochi 0.75 s, Bustshell 0.9 s, Golden Mole burrow 1.45 s |
| Recovery (`PostAttackDuration`), 86 entries | median 1.0 s | 0.55–0.9 s |

## Not found in the data

Hit-stop and screen shake values weren't found as plain fields. The PoC uses 45–80 ms hit-stop and small camera shakes; tune these by feel.
