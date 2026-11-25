@tool
class_name CharacterVisual
extends Node2D
## Cuerpo del personaje por capas + sus animaciones (idle, walk, air, land).
## El AnimationPlayer de la escena es la fuente de verdad: edita ahí las animaciones.

@export var appearance: CharacterAppearance:
	set(value):
		appearance = value
		if is_node_ready():
			_apply_appearance()

var _moving := false
var _airborne := false
var _landing := false

@onready var flip: Node2D = $Flip
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var _leg_l_skin: Sprite2D = $Flip/Body/LegL/Skin
@onready var _leg_l_boot: Sprite2D = $Flip/Body/LegL/Boot
@onready var _leg_r_skin: Sprite2D = $Flip/Body/LegR/Skin
@onready var _leg_r_boot: Sprite2D = $Flip/Body/LegR/Boot
@onready var _torso: Sprite2D = $Flip/Body/Upper/Torso
@onready var _cloth_top: Sprite2D = $Flip/Body/Upper/ClothTop
@onready var _cloth_bottom: Sprite2D = $Flip/Body/Upper/ClothBottom
@onready var _head_skin: Sprite2D = $Flip/Body/Upper/Head/Skin
@onready var _eyes: Sprite2D = $Flip/Body/Upper/Head/Eyes
@onready var _hair: Sprite2D = $Flip/Body/Upper/Head/Hair


func _ready() -> void:
	_apply_appearance()
	if not Engine.is_editor_hint():
		animation_player.animation_finished.connect(_on_animation_finished)
		_refresh_animation()


## 1 = mira a la derecha, -1 = izquierda.
func set_facing(direction: float) -> void:
	if direction != 0.0:
		flip.scale.x = signf(direction)


func set_moving(moving: bool) -> void:
	if moving != _moving:
		_moving = moving
		_refresh_animation()


func set_airborne(airborne: bool) -> void:
	if airborne != _airborne:
		_airborne = airborne
		_refresh_animation()


func play_land() -> void:
	_landing = true
	animation_player.play(&"land")


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"land":
		_landing = false
		_refresh_animation()


func _refresh_animation() -> void:
	if _landing:
		return
	var target := &"idle"
	if _airborne:
		target = &"air"
	elif _moving:
		target = &"walk"
	if animation_player.current_animation != target:
		animation_player.play(target)


func _apply_appearance() -> void:
	if appearance == null:
		return
	_leg_l_skin.texture = appearance.leg_l
	_leg_r_skin.texture = appearance.leg_r
	_leg_l_boot.texture = appearance.boot_l
	_leg_r_boot.texture = appearance.boot_r
	_torso.texture = appearance.torso
	_cloth_top.texture = appearance.cloth_top
	_cloth_bottom.texture = appearance.cloth_bottom
	_head_skin.texture = appearance.head
	_eyes.texture = appearance.eyes
	_hair.texture = appearance.hair
	for sprite: Sprite2D in [_leg_l_skin, _leg_r_skin, _torso, _head_skin]:
		sprite.self_modulate = appearance.skin_tint
	_hair.self_modulate = appearance.hair_tint
