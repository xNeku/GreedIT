class_name HUD3D
extends CanvasLayer
## HUD del mundo 3D: vida, arma equipada, barra de armas (1-7) y ayuda de controles.

@onready var health_bar: ProgressBar = %HealthBar
@onready var mana_bar: ProgressBar = %ManaBar
@onready var moves_label: Label = %MovesLabel
@onready var weapon_label: Label = %WeaponLabel
@onready var hotbar_label: RichTextLabel = %HotbarLabel
@onready var net_label: Label = %NetLabel

var player: Player3D


func set_player(new_player: Player3D) -> void:
	player = new_player
	player.weapon_changed.connect(func(_w: Weapon3DData) -> void: _refresh())
	player.equipment_changed.connect(_refresh)
	player.health_changed.connect(func(value: float, max_value: float) -> void:
		health_bar.max_value = max_value
		health_bar.value = value)
	player.mana_changed.connect(func(value: float, max_value: float) -> void:
		mana_bar.max_value = max_value
		mana_bar.value = value)
	health_bar.max_value = player.max_health
	health_bar.value = player.health
	mana_bar.max_value = player.max_mana
	mana_bar.value = player.mana
	_refresh()


func _process(_delta: float) -> void:
	var peers := multiplayer.get_peers().size() + 1 if Net.is_online() else 1
	net_label.text = "%s · %d jugador%s" % [["Solo", "Host", "Cliente"][Net.mode], peers, "" if peers == 1 else "es"]


func _refresh() -> void:
	if player == null or player.current_weapon == null:
		return
	weapon_label.text = player.current_weapon.display_name
	moves_label.text = player.current_weapon.moves_hint
	var parts: PackedStringArray = []
	for i in player.weapons.size():
		var w := player.weapons[i]
		var text := "%d %s" % [i + 1, w.display_name]
		parts.append("[color=#ffd36b][b]%s[/b][/color]" % text if i == player.weapon_index else "[color=#a9a2b4]%s[/color]" % text)
	hotbar_label.text = "  ".join(parts)
