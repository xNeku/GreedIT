@tool
class_name CharacterVisual
extends Node2D
## Cuerpo del personaje por capas + sus animaciones.
## El AnimationPlayer de la escena es la fuente de verdad: edita ahí las animaciones.
## Vistas: FRONT (de frente), SIDE (3/4 de lado: ojos y pelo girados + zancada), BACK (de espalda).
##   idle (respira y parpadea), walk (frente/espalda) y walk_side (zancada lateral), ambas llaman a step()
##   jump_windup (agacharse), rise / peak / fall (fases del salto), land, land_heavy

signal footstep

enum AirPhase { GROUND, RISING, PEAK, FALLING }
enum View { FRONT, SIDE, BACK }

@export var appearance: CharacterAppearance:
	set(value):
		appearance = value
		if is_node_ready():
			_apply_appearance()

@export_group("Vista de lado")
## Píxeles que se desplazan los ojos hacia donde mira (simula girar la cabeza).
@export var side_eye_shift := 2
## Píxeles que se desplaza el pelo hacia atrás.
@export var side_hair_shift := -1

var view := View.FRONT
var _moving := false
var _air_phase := AirPhase.GROUND
## Animación de una sola vez que tiene prioridad (agacharse, aterrizar).
var _one_shot: StringName = &""

@onready var flip: Node2D = $Flip
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var foot_dust: CPUParticles2D = $FootDust
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


func set_view(new_view: View) -> void:
	if new_view == view:
		return
	view = new_view
	_apply_appearance()
	_refresh_animation()


func set_moving(moving: bool) -> void:
	if moving != _moving:
		_moving = moving
		_refresh_animation()


func set_air_phase(phase: AirPhase) -> void:
	if phase != _air_phase:
		_air_phase = phase
		_refresh_animation()


func play_jump_windup() -> void:
	_play_one_shot(&"jump_windup")


func play_land(heavy: bool = false) -> void:
	_play_one_shot(&"land_heavy" if heavy else &"land")


## Llamado por la animación "walk" en cada pisada.
func step() -> void:
	foot_dust.restart()
	footstep.emit()


func _play_one_shot(anim: StringName) -> void:
	_one_shot = anim
	animation_player.stop()
	animation_player.play(anim)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == _one_shot:
		_one_shot = &""
		_refresh_animation()


func _refresh_animation() -> void:
	if _one_shot != &"":
		return
	var target := &"idle"
	match _air_phase:
		AirPhase.RISING:
			target = &"rise"
		AirPhase.PEAK:
			target = &"peak"
		AirPhase.FALLING:
			target = &"fall"
		_:
			if _moving:
				target = &"walk_side" if view == View.SIDE else &"walk"
	if animation_player.current_animation != target:
		animation_player.play(target)


func _apply_appearance() -> void:
	if appearance == null:
		return
	var back := view == View.BACK
	_leg_l_skin.texture = appearance.leg_l
	_leg_r_skin.texture = appearance.leg_r
	_leg_l_boot.texture = appearance.boot_l
	_leg_r_boot.texture = appearance.boot_r
	_torso.texture = appearance.torso_back if back and appearance.torso_back else appearance.torso
	_cloth_top.texture = appearance.cloth_top
	_cloth_bottom.texture = appearance.cloth_bottom
	_head_skin.texture = appearance.head_back if back and appearance.head_back else appearance.head
	_eyes.texture = appearance.eyes
	_eyes.visible = not back
	_hair.texture = appearance.hair_back if back and appearance.hair_back else appearance.hair
	var side := view == View.SIDE
	_eyes.position.x = side_eye_shift if side else 0
	_hair.position.x = side_hair_shift if side else 0
	for sprite: Sprite2D in [_leg_l_skin, _leg_r_skin, _torso, _head_skin]:
		sprite.self_modulate = appearance.skin_tint
	_hair.self_modulate = appearance.hair_tint
