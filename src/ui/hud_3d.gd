class_name HUD3D
extends CanvasLayer
## HUD: orbe de vida (abajo a la izquierda, estilo Diablo), la barra de 8 huecos (1-8) y, encima, el hechizo
## elegido (rueda del ratón para cambiarlo).

@onready var health_orb: ColorRect = %HealthOrb
@onready var slots: Array[HotbarSlot3D] = []

var player: Player3D


func _ready() -> void:
	for child in %Hotbar.get_children():
		if child is HotbarSlot3D:
			slots.append(child)


func set_player(new_player: Player3D) -> void:
	player = new_player
	player.weapon_changed.connect(func(_w: Weapon3DData) -> void: _refresh())
	player.health_changed.connect(_set_health)
	player.spell_changed.connect(_set_spell)
	_set_spell(player.spell)
	_set_health(player.health, player.max_health)
	_refresh()


func _refresh() -> void:
	if player == null:
		return
	for i in slots.size():
		var item: Weapon3DData = player.hotbar[i] if i < player.hotbar.size() else null
		slots[i].set_item(item, i == player.slot_index)


func _set_health(value: float, max_value: float) -> void:
	(health_orb.material as ShaderMaterial).set_shader_parameter(&"fill", clampf(value / maxf(max_value, 1.0), 0.0, 1.0))


func _set_spell(spell: Spell3DData) -> void:
	%Spell.text = "Magia (rueda): %s" % spell.display_name if spell else ""
