class_name DamageNumber
extends Node2D
## Número flotante de daño. Asigna `amount` e `is_crit` ANTES de añadirlo al árbol.
## La animación "pop" vive en la escena: retócala desde el editor.

@export var normal_color := Color(1.0, 1.0, 1.0)
@export var crit_color := Color(1.0, 0.78, 0.25)
@export var normal_font_size := 16
@export var crit_font_size := 24
@export var horizontal_jitter := 8.0

var amount: int = 0
var is_crit: bool = false
## Si tiene alfa > 0, se usa este color (p. ej. rojo para el daño que recibe el jugador).
var color_override := Color(0, 0, 0, 0)

@onready var label: Label = $Holder/Label
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	label.text = str(amount) + ("!" if is_crit else "")
	var color := crit_color if is_crit else normal_color
	if color_override.a > 0.0:
		color = color_override
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", crit_font_size if is_crit else normal_font_size)
	position.x += randf_range(-horizontal_jitter, horizontal_jitter)
	animation_player.animation_finished.connect(func(_n: StringName) -> void: queue_free())
	animation_player.play(&"pop")
