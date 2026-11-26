@tool
class_name CharacterVisual
extends Node2D
## Cuerpo del personaje por capas + sus animaciones.
## El AnimationPlayer de la escena es la fuente de verdad: edita ahí las animaciones.
##
## Vistas (`View`), que con el volteo izquierda/derecha dan 8 direcciones (estilo Diablo / PoE):
##   FRONT (abajo), FRONT_SIDE (diagonal abajo), SIDE (perfil), BACK_SIDE (diagonal arriba), BACK (arriba).
##   Cada vista tiene su juego de capas en el CharacterAppearance.
## Animaciones: idle (respira y parpadea), run (frente/espalda), run_diag, run_side (todas llaman a step()),
##   run_start / run_stop / turn (arrancar, frenar y girar), jump_windup, rise / peak / fall, land, land_heavy.
## Manos libres: HandLAnchor/HandRAnchor se colocan por código según la vista (`hand_rest_*`) y la animación
##   mueve HandL/HandR dentro de su ancla (balanceo al correr). De perfil la mano lejana va detrás del cuerpo.
## BackWeapon: el arma guardada a la espalda (detrás del cuerpo de frente, encima de la espalda de espaldas).

signal footstep

enum AirPhase { GROUND, RISING, PEAK, FALLING }
enum View { FRONT, FRONT_SIDE, SIDE, BACK_SIDE, BACK }

@export var appearance: CharacterAppearance:
	set(value):
		appearance = value
		if is_node_ready():
			_apply_appearance()

@export_group("Manos en reposo por vista")
## Posición de la mano izquierda/derecha (mirando a la derecha) en cada vista: frente, 3/4, perfil, 3/4 espalda, espalda.
@export var hand_rest_l: Array[Vector2] = [Vector2(-21, -26), Vector2(-17, -26), Vector2(-5, -27), Vector2(-17, -26), Vector2(-21, -26)]
@export var hand_rest_r: Array[Vector2] = [Vector2(21, -26), Vector2(18, -26), Vector2(6, -25), Vector2(18, -26), Vector2(21, -26)]

var view := View.FRONT
var _back_item: WeaponData
## 0..1: velocidad relativa (acelera la animación de correr).
var speed_ratio := 1.0
var _moving := false
var _air_phase := AirPhase.GROUND
## Animación de una sola vez que tiene prioridad (agacharse, aterrizar).
var _one_shot: StringName = &""

@onready var flip: Node2D = $Flip
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var foot_dust: CPUParticles2D = $FootDust
@onready var back_weapon: Sprite2D = $Flip/Body/Upper/BackWeapon
@onready var _hand_l_anchor: Node2D = $Flip/Body/HandLAnchor
@onready var _hand_r_anchor: Node2D = $Flip/Body/HandRAnchor
@onready var _hand_l: Sprite2D = $Flip/Body/HandLAnchor/HandL
@onready var _hand_r: Sprite2D = $Flip/Body/HandRAnchor/HandR
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


## 1 = mira a la derecha, -1 = izquierda. Girar corriendo hace un pequeño "derrape".
func set_facing(direction: float) -> void:
	if direction == 0.0 or signf(direction) == flip.scale.x:
		return
	flip.scale.x = signf(direction)
	if _moving and _air_phase == AirPhase.GROUND and _one_shot == &"":
		_play_one_shot(&"turn")


func set_speed_ratio(ratio: float) -> void:
	speed_ratio = ratio
	if String(animation_player.current_animation).begins_with("run") and _one_shot == &"":
		animation_player.speed_scale = lerpf(0.7, 1.15, clampf(ratio, 0.0, 1.0))
	else:
		animation_player.speed_scale = 1.0


func set_view(new_view: View) -> void:
	if new_view == view:
		return
	view = new_view
	_apply_appearance()
	_refresh_animation()


func is_back_view() -> bool:
	return view == View.BACK or view == View.BACK_SIDE


func set_moving(moving: bool) -> void:
	if moving == _moving:
		return
	_moving = moving
	if _air_phase == AirPhase.GROUND and _one_shot == &"":
		_play_one_shot(&"run_start" if moving else &"run_stop")
		foot_dust.restart()
	else:
		_refresh_animation()


func set_air_phase(phase: AirPhase) -> void:
	if phase != _air_phase:
		_air_phase = phase
		_cancel_soft_one_shot()
		_refresh_animation()


## Manos libres (cuando no hay arma ni herramienta en las manos).
func set_free_hands_visible(value: bool) -> void:
	_hand_l.visible = value
	_hand_r.visible = value


## Arma guardada a la espalda. null o sin `back_texture` = nada.
func set_back_item(data: WeaponData) -> void:
	_back_item = data
	_apply_back_item()


## Coloca el arma de la espalda según la vista. Los datos `back_*` están pensados para la vista de frente;
## de perfil la espalda queda detrás (-X), así que se pega a ella y se pone casi vertical.
func _apply_back_item() -> void:
	var data := _back_item
	if data == null or data.back_texture == null:
		back_weapon.visible = false
		return
	back_weapon.visible = true
	back_weapon.texture = data.back_texture
	back_weapon.offset = data.back_texture_offset
	var pos := data.back_position
	var rot := data.back_rotation_degrees
	if view == View.SIDE:
		pos = Vector2(-absf(pos.x) * 0.4 - 6.0, pos.y)
		var tex_size := data.back_texture.get_size()
		if tex_size.y > tex_size.x:
			rot = 15.0 # textura vertical (arco): casi recta pegada a la espalda
		elif rot >= 0.0:
			rot = 90.0 + (rot - 90.0) * 0.35 # punta hacia abajo
		else:
			rot = -105.0 # cabeza hacia arriba, inclinada hacia atrás para que asome por detrás de la cabeza
	back_weapon.position = pos
	back_weapon.rotation_degrees = rot


func play_jump_windup() -> void:
	_play_one_shot(&"jump_windup")


func play_land(heavy: bool = false) -> void:
	_play_one_shot(&"land_heavy" if heavy else &"land")


## Llamado por las animaciones de andar en cada pisada.
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


## Las one-shot de carrera ceden en cuanto cambia el estado.
func _cancel_soft_one_shot() -> void:
	if _one_shot in [&"run_start", &"run_stop", &"turn"]:
		_one_shot = &""


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
				match view:
					View.SIDE:
						target = &"run_side"
					View.FRONT_SIDE, View.BACK_SIDE:
						target = &"run_diag"
					_:
						target = &"run"
	if animation_player.current_animation != target:
		animation_player.play(target)


func _apply_appearance() -> void:
	if appearance == null:
		return
	var layers := appearance.layers_for(view)
	_leg_l_skin.texture = layers.leg_l
	_leg_r_skin.texture = layers.leg_r
	_leg_l_boot.texture = layers.boot_l
	_leg_r_boot.texture = layers.boot_r
	_torso.texture = layers.torso
	_cloth_top.texture = layers.cloth_top
	_cloth_bottom.texture = layers.cloth_bottom
	_head_skin.texture = layers.head
	_eyes.texture = layers.eyes
	_hair.texture = layers.hair
	_hand_l.texture = appearance.hand_l
	_hand_r.texture = appearance.hand_r
	for sprite: Sprite2D in [_leg_l_skin, _leg_r_skin, _torso, _head_skin, _hand_l, _hand_r]:
		sprite.self_modulate = appearance.skin_tint
	_hair.self_modulate = appearance.hair_tint
	# Manos: posición de reposo por vista. De perfil la lejana va detrás del cuerpo y algo más oscura.
	_hand_l_anchor.position = hand_rest_l[view]
	_hand_r_anchor.position = hand_rest_r[view]
	var profile := view == View.SIDE
	_hand_l_anchor.z_index = -1 if profile else 0
	_hand_l.modulate = Color(0.8, 0.8, 0.8) if profile else Color.WHITE
	# El arma de la espalda: detrás del cuerpo si te vemos de frente, encima si te vemos de espaldas.
	back_weapon.z_index = 0 if is_back_view() else -1
	_apply_back_item()
