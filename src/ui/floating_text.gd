class_name FloatingText
extends Node2D
## Texto flotante con icono opcional ("+1 Mineral de cobre"). Asigna `text` e `icon` antes de añadirlo.

var text := ""
var icon: Texture2D

@onready var label: Label = $Holder/Label
@onready var icon_sprite: Sprite2D = $Holder/Icon
@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	label.text = text
	icon_sprite.texture = icon
	icon_sprite.visible = icon != null
	animation_player.animation_finished.connect(func(_n: StringName) -> void: queue_free())
	animation_player.play(&"rise")
