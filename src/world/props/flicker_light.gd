class_name FlickerLight
extends PointLight2D
## Luz que parpadea como una llama.

@export var flicker_amount := 0.18
@export var flicker_speed := 9.0

var _base_energy := 1.0
var _base_scale := 1.0
var _time := 0.0


func _ready() -> void:
	_base_energy = energy
	_base_scale = texture_scale
	_time = randf() * 100.0


func _process(delta: float) -> void:
	_time += delta * flicker_speed
	var n := sin(_time) * 0.5 + sin(_time * 2.3 + 1.7) * 0.3 + sin(_time * 5.1) * 0.2
	energy = _base_energy * (1.0 + n * flicker_amount)
	texture_scale = _base_scale * (1.0 + n * flicker_amount * 0.15)
