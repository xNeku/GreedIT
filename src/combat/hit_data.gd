class_name HitData
extends RefCounted
## Información de un golpe. La crea el arma al impactar y viaja hasta el Hurtbox.
## Más adelante los modificadores (talentos, afijos, brebajes) la alterarán vía Events.

var amount: int = 0
var is_crit: bool = false
var knockback: Vector2 = Vector2.ZERO
var source: Node = null
var attack_name: StringName = &""
var tags: PackedStringArray = PackedStringArray()


## Crea un golpe tirando el crítico. `base * multiplier`, ±10% de variación.
static func roll(base: float, multiplier: float, crit_chance: float, crit_multiplier: float) -> HitData:
	var hit := HitData.new()
	hit.is_crit = randf() < crit_chance
	var damage := base * multiplier * randf_range(0.9, 1.1)
	if hit.is_crit:
		damage *= crit_multiplier
	hit.amount = maxi(1, roundi(damage))
	return hit
