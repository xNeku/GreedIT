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



## Para mandarlo por red.
func to_dict() -> Dictionary:
	return {
		"amount": amount, "crit": is_crit, "kb": knockback, "name": attack_name, "tags": tags,
		"source": String(source.get_path()) if source and source.is_inside_tree() else "",
	}


static func from_dict(data: Dictionary, context: Node) -> HitData:
	var hit := HitData.new()
	hit.amount = data.get("amount", 0)
	hit.is_crit = data.get("crit", false)
	hit.knockback = data.get("kb", Vector2.ZERO)
	hit.attack_name = data.get("name", &"")
	hit.tags = data.get("tags", PackedStringArray())
	var source_path: String = data.get("source", "")
	if source_path != "":
		hit.source = context.get_node_or_null(NodePath(source_path))
	return hit
