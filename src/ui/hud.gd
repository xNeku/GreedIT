class_name HUD
extends CanvasLayer
## HUD del sandbox: hotbar, arma seleccionada, maná, hechizo de la rueda y panel de materiales.

@export var player: Player
## Escena de cada fila del panel de materiales.
@export var inventory_row_scene: PackedScene

@onready var hotbar: HBoxContainer = $Hotbar
@onready var item_name: Label = $ItemName
@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel
@onready var death_message: Label = $DeathMessage
@onready var mana_bar: ProgressBar = $ManaBar
@onready var mana_label: Label = $ManaLabel
@onready var spell_icon: TextureRect = $SpellSlot/Icon
@onready var spell_cooldown: ColorRect = $SpellSlot/Cooldown
@onready var cast_message: Label = $CastMessage
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var materials: VBoxContainer = $Materials
@onready var materials_list: VBoxContainer = $Materials/List

var _rows: Dictionary[ItemData, InventoryRow] = {}


func _ready() -> void:
	if player:
		player.hotbar_changed.connect(_on_hotbar_changed)
		_on_hotbar_changed(player.hotbar, player.selected_slot)
		player.inventory.changed.connect(_on_inventory_changed)
		player.mana_changed.connect(_on_mana_changed)
		player.health_changed.connect(_on_health_changed)
		player.died.connect(func() -> void: death_message.visible = true)
		player.respawned.connect(func() -> void: death_message.visible = false)
		_on_health_changed(player.health, player.max_health)
		death_message.visible = false
		player.cast_failed.connect(_on_cast_failed)
		_on_mana_changed(player.mana, player.max_mana)
		spell_icon.texture = player.spell.icon if player.spell else null
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


func _process(_delta: float) -> void:
	if player == null:
		return
	var ratio := player.spell_cooldown_ratio()
	spell_cooldown.visible = ratio > 0.0 or (player.spell != null and player.mana < player.spell.mana_cost)
	spell_cooldown.size.y = 20.0 * (ratio if ratio > 0.0 else 1.0)


func _on_health_changed(health: float, max_health: float) -> void:
	health_bar.max_value = max_health
	health_bar.value = health
	health_label.text = "Vida %d" % ceili(health)


func _on_mana_changed(mana: float, max_mana: float) -> void:
	mana_bar.max_value = max_mana
	mana_bar.value = mana
	mana_label.text = "Maná %d" % floori(mana)


func _on_cast_failed(reason: String) -> void:
	cast_message.text = reason
	animation_player.stop()
	animation_player.play(&"flash")
