class_name HotbarSlot3D
extends PanelContainer
## Un hueco de la barra de objetos: icono del objeto, número de tecla y marco resaltado si está elegido.

## Estilo normal y elegido del marco.
@export var normal_style: StyleBox
@export var selected_style: StyleBox

@onready var icon: TextureRect = $Icon
@onready var key_label: Label = $Key


func set_item(item: ItemData, selected: bool) -> void:
	icon.texture = item.icon if item else null
	tooltip_text = item.display_name if item else ""
	add_theme_stylebox_override(&"panel", selected_style if selected else normal_style)
