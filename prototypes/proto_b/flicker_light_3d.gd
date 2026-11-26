extends OmniLight3D
## PROTOTIPO B: luz de brasero que parpadea.

var _base := 1.0
var _time := 0.0


func _ready() -> void:
	_base = light_energy
	_time = randf() * 10.0


func _process(delta: float) -> void:
	_time += delta * 9.0
	light_energy = _base * (1.0 + (sin(_time) * 0.5 + sin(_time * 2.3) * 0.3) * 0.2)
