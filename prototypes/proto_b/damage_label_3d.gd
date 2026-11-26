extends Label3D
## PROTOTIPO B: número de daño que sube y se desvanece.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	position.y += 40.0 * delta * maxf(0.0, 1.0 - _t)
	modulate.a = clampf(1.6 - _t * 2.0, 0.0, 1.0)
	if _t > 0.8:
		queue_free()
