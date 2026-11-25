class_name Gatherable
extends StaticBody2D
## Recurso farmeable infinito (veta de mineral, arbusto de hierbas, zona de pesca...).
## Acércate y pulsa E: el jugador saca la herramienta (`tool_scene`) y cada golpe llama a on_tool_hit().
## Capa de interacción: InteractArea en la capa 8 (interactables).

enum Profession { MINING, HERBALISM, FISHING }

@export var profession: Profession = Profession.MINING
## Texto del cartel: "Minar", "Recolectar", "Pescar"...
@export var action_text := "Minar"
## Herramienta que saca el jugador (escena con GatherTool).
@export var tool_scene: PackedScene
@export_group("Botín")
@export var drop: ItemData
@export var drop_min := 1
@export var drop_max := 1
## Golpes de herramienta para conseguir un botín (la pesca no lo usa).
@export var hits_to_gather := 3
@export var floating_text_scene: PackedScene
@export_group("Reacción")
## Píxeles que tiembla al golpearlo.
@export var shake_pixels := 1.5
@export var focus_brightness := 1.25

var _progress := 0
var _shake := 0.0
var _flash := 0.0

@onready var visual: Node2D = $Visual
@onready var gather_point: Marker2D = $GatherPoint
@onready var chips: CPUParticles2D = $Chips
@onready var _flash_material: ShaderMaterial = ($Visual/Sprite as CanvasItem).material as ShaderMaterial


## Punto al que apunta la herramienta.
func get_gather_point() -> Vector2:
	return gather_point.global_position


## Resaltado cuando el jugador lo tiene al alcance.
func set_focused(focused: bool) -> void:
	visual.modulate = Color(focus_brightness, focus_brightness, focus_brightness) if focused else Color.WHITE


## Un golpe de herramienta (lo llama la animación de la herramienta).
func on_tool_hit(player: Player) -> void:
	_shake = 0.12
	_flash = 1.0
	chips.restart()
	_progress += 1
	if _progress >= hits_to_gather:
		_progress = 0
		give(player)


## Entrega el botín al jugador.
func give(player: Player) -> void:
	var amount := randi_range(drop_min, drop_max)
	player.inventory.add(drop, amount)
	show_text("+%d %s" % [amount, drop.display_name], drop.icon)


func show_text(text: String, icon: Texture2D = null) -> void:
	if floating_text_scene == null:
		return
	var floating := floating_text_scene.instantiate() as FloatingText
	floating.text = text
	floating.icon = icon
	var container := get_tree().get_first_node_in_group(&"world_overlay")
	(container if container else get_parent()).add_child(floating)
	floating.global_position = gather_point.global_position + Vector2(0, -26)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake -= delta
		visual.position = Vector2(randf_range(-1, 1), randf_range(-1, 1)).round() * shake_pixels if _shake > 0.0 else Vector2.ZERO
	if _flash > 0.0:
		_flash = move_toward(_flash, 0.0, delta * 7.0)
		if _flash_material:
			_flash_material.set_shader_parameter("flash_amount", _flash * 0.7)
