extends Talent
## Desperate Rally (1109): below its HP line, your damage rises by its value, more the lower
## your HP goes (up to double that at 0).


func adjust(what: StringName, amount: float) -> float:
	if what != &"damage":
		return amount
	var line := row("hp") / 100.0
	var frac := Run.hp / float(maxi(Run.max_hp, 1))
	if line > 0.0 and frac < line:
		amount *= 1.0 + value() / 100.0 * (1.0 + (line - frac) / line)
	return amount
