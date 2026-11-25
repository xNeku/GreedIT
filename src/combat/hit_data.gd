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
