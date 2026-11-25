class_name HotbarSlot
extends TextureRect
## Un hueco de la hotbar.

@export var normal_texture: Texture2D
@export var selected_texture: Texture2D

@onready var icon: TextureRect = $Icon
@onready var number_label: Label = $Number


func set_item(item: ItemData, index: int, selected: bool) -> void:
	icon.texture = item.icon if item else null
	number_label.text = str(index + 1)
	texture = selected_texture if selected else normal_texture
	pivot_offset = size / 2.0
	scale = Vector2.ONE * (1.15 if selected else 1.0)
