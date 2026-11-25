class_name InteractPrompt
extends Node2D
## Cartel de "pulsa E" que flota sobre la cabeza del jugador.

@onready var action_label: Label = $Holder/Action
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	visible = false


func show_prompt(text: String, urgent: bool = false) -> void:
	action_label.text = text
	visible = true
	animation_player.play(&"urgent" if urgent else &"bob")


func hide_prompt() -> void:
	visible = false
	animation_player.stop()
