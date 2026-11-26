class_name OneShotFX
extends Node3D
## Efecto de usar y tirar: reproduce la animación `play` de su AnimationPlayer y se borra al acabar.
## Todo el efecto (mallas, luces, partículas y su animación) se edita en su escena.

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	animation_player.animation_finished.connect(func(_n: StringName) -> void: queue_free())
	animation_player.play(&"play")
