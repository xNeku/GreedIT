class_name InventoryRow
extends HBoxContainer
## Fila del panel de materiales: icono + nombre + cantidad.

@onready var icon: TextureRect = $Icon
@onready var label: Label = $Label


func set_item(item: ItemData, count: int) -> void:
	icon.texture = item.icon
	label.text = "%s  x%d" % [item.display_name, count]
