class_name DamageLabel3D
extends Label3D
## Número de daño 3D que sube y se desvanece. Pon `amount` / `is_crit` antes de añadirlo.

var amount := 0
var is_crit := false
var _t := 0.0


func _ready() -> void:
	text = str(amount) + ("!" if is_crit else "")
	if is_crit:
		modulate = Color(1.0, 0.8, 0.3)
		font_size = int(font_size * 1.4)


func _process(delta: float) -> void:
	_t += delta
	position.y += 1.6 * delta * maxf(0.0, 1.0 - _t * 1.2)
	modulate.a = clampf(1.8 - _t * 2.2, 0.0, 1.0)
	if _t > 0.85:
		queue_free()
