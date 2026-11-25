class_name GatherTool
extends Node2D
## Herramienta de recolección (pico, hoz...). Escena con AnimationPlayer:
##   "use" (en bucle) que llama a tool_hit() en el frame de impacto.
## Como las armas, se anima en el espacio de la herramienta (+X = hacia el recurso).

@export var use_animation: StringName = &"use"
@export var hit_shake := 1.2

var player: Player
var target: Gatherable
var _hands: Array[Node2D] = []

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	_hands = HandUtils.find_hands(self)


func setup(owner_player: Player, gather_target: Gatherable) -> void:
	player = owner_player
	target = gather_target
	apply_appearance(player.character_visual.appearance)
	_begin()


func apply_appearance(appearance: CharacterAppearance) -> void:
	HandUtils.apply_appearance(self, appearance)


## Devuelve true si la herramienta usa la tecla E (p. ej. la caña al picar).
func interact_pressed() -> bool:
	return false


func _begin() -> void:
	animation_player.play(use_animation)


## Frame de impacto (pista de método de la animación).
func tool_hit() -> void:
	if target:
		target.on_tool_hit(player)
	Events.camera_shake_requested.emit(hit_shake, 0.08)


func _process(_delta: float) -> void:
	if player:
		for hand in _hands:
			HandUtils.keep_upright(hand, player.facing)
