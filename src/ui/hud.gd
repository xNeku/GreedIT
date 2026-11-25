class_name HUD
extends CanvasLayer
## HUD del sandbox: hotbar (1-5) y nombre del arma seleccionada.

@export var player: Player
## Escena de cada fila del panel de materiales.
@export var inventory_row_scene: PackedScene

@onready var hotbar: HBoxContainer = $Hotbar
@onready var item_name: Label = $ItemName
@onready var materials: VBoxContainer = $Materials
@onready var materials_list: VBoxContainer = $Materials/List

var _rows: Dictionary[ItemData, InventoryRow] = {}


func _ready() -> void:
	if player:
		player.hotbar_changed.connect(_on_hotbar_changed)
		_on_hotbar_changed(player.hotbar, player.selected_slot)
		player.inventory.changed.connect(_on_inventory_changed)
	materials.visible = false


func _on_hotbar_changed(items: Array[ItemData], selected: int) -> void:
	var slots := hotbar.get_children()
	for i in slots.size():
		var slot := slots[i] as HotbarSlot
		var item: ItemData = items[i] if i < items.size() else null
		slot.set_item(item, i, i == selected)
	var current: ItemData = items[selected] if selected < items.size() else null
	item_name.text = current.display_name if current else ""


func _on_inventory_changed(item: ItemData, count: int) -> void:
	var row: InventoryRow = _rows.get(item)
	if row == null:
		row = inventory_row_scene.instantiate() as InventoryRow
		materials_list.add_child(row)
		_rows[item] = row
	row.set_item(item, count)
	materials.visible = true
