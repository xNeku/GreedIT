class_name HUD
extends CanvasLayer
## HUD del sandbox: hotbar (1-5) y nombre del arma seleccionada.

@export var player: Player

@onready var hotbar: HBoxContainer = $Hotbar
@onready var item_name: Label = $ItemName


func _ready() -> void:
	if player:
		player.hotbar_changed.connect(_on_hotbar_changed)
		_on_hotbar_changed(player.hotbar, player.selected_slot)


func _on_hotbar_changed(items: Array[ItemData], selected: int) -> void:
	var slots := hotbar.get_children()
	for i in slots.size():
		var slot := slots[i] as HotbarSlot
		var item: ItemData = items[i] if i < items.size() else null
		slot.set_item(item, i, i == selected)
	var current: ItemData = items[selected] if selected < items.size() else null
	item_name.text = current.display_name if current else ""
