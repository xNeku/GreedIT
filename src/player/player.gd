class_name Player
extends CharacterBody2D
## Jugador top-down.
## - Movimiento con inercia (WASD).
## - Salto estilo Conquer: saltas HACIA EL CURSOR en un arco fijo. En el aire pasas por
##   encima de enemigos. Atacar en el aire = ataque aéreo + caída en picado (slam al aterrizar).
## - Dash (Shift). Más adelante lo darán objetos; ahora viene de serie para probar.
## - Hotbar de 5 huecos (1-5 / rueda) estilo Terraria.

signal hotbar_changed(items: Array[ItemData], selected: int)
signal jumped
signal landed(was_plunging: bool)

const GROUND_MASK := 1 | 4 ## world + enemies
const AIR_MASK := 1 ## en el aire solo chocas con el mundo

@export_group("Movimiento")
@export var move_speed := 120.0
@export var acceleration := 900.0
@export var friction := 1100.0
## Multiplicador de velocidad mientras atacas.
@export var attack_move_multiplier := 0.35

@export_group("Salto")
@export var jump_max_distance := 150.0
@export var jump_min_distance := 24.0
@export var jump_duration := 0.48
@export var jump_height := 30.0
## Velocidad de caída (px/s) al hacer un ataque aéreo.
@export var plunge_fall_speed := 260.0

@export_group("Dash")
@export var dash_speed := 380.0
@export var dash_time := 0.14
@export var dash_cooldown := 0.6

@export_group("Inventario")
@export var hotbar: Array[ItemData] = []
@export var selected_slot := 0

@export_group("Aspecto")
## Pulsa C para ir cambiando entre estos aspectos.
@export var appearances: Array[CharacterAppearance] = []

var current_weapon: Weapon
## Si no es null, se apunta aquí en vez de al ratón (mandos, IA, tests).
var aim_target_override: Variant = null
## Altura actual sobre el suelo (px). 0 = en el suelo.
var z := 0.0
var is_airborne := false
var aim_angle := 0.0

var _jump_elapsed := 0.0
var _jump_total := 0.0
var _jump_peak := 0.0
var _jump_velocity := Vector2.ZERO
var _plunging := false
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_direction := Vector2.ZERO
var _appearance_index := 0

@onready var visual_root: Node2D = $VisualRoot
@onready var character_visual: CharacterVisual = $VisualRoot/CharacterVisual
@onready var aim_pivot: Node2D = $VisualRoot/AimPivot
@onready var weapon_holder: Node2D = $VisualRoot/AimPivot/WeaponHolder
@onready var shadow: Sprite2D = $Shadow
@onready var fx_player: AnimationPlayer = $FXPlayer
@onready var dust: CPUParticles2D = $GroundFX/Dust


func _ready() -> void:
	collision_mask = GROUND_MASK
	if not appearances.is_empty():
		character_visual.appearance = appearances[0]
	select_slot(selected_slot)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack_primary"):
		if current_weapon:
			current_weapon.primary_pressed()
	elif event.is_action_released("attack_primary"):
		if current_weapon:
			current_weapon.primary_released()
	elif event.is_action_pressed("attack_secondary"):
		if current_weapon:
			current_weapon.secondary_pressed()
	elif event.is_action_released("attack_secondary"):
		if current_weapon:
			current_weapon.secondary_released()
	elif event.is_action_pressed("jump"):
		try_jump(get_aim_target())
	elif event.is_action_pressed("dash"):
		try_dash()
	elif event.is_action_pressed("hotbar_next"):
		select_slot(wrapi(selected_slot + 1, 0, hotbar.size()))
	elif event.is_action_pressed("hotbar_prev"):
		select_slot(wrapi(selected_slot - 1, 0, hotbar.size()))
	elif event.is_action_pressed("toggle_character"):
		cycle_appearance()
	else:
		for i in hotbar.size():
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				select_slot(i)
				break


func _physics_process(delta: float) -> void:
	_update_aim()
	_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_direction * dash_speed
	elif is_airborne:
		_update_jump(delta)
	else:
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var speed := move_speed
		if current_weapon and current_weapon.is_busy():
			speed *= attack_move_multiplier
		var rate := acceleration if input_dir != Vector2.ZERO else friction
		velocity = velocity.move_toward(input_dir * speed, rate * delta)

	move_and_slide()

	visual_root.position.y = -roundf(z)
	var shadow_scale := lerpf(1.0, 0.6, clampf(z / 40.0, 0.0, 1.0))
	shadow.scale = Vector2(shadow_scale, shadow_scale)
	character_visual.set_moving(velocity.length() > 12.0)
	character_visual.set_airborne(is_airborne)


# --- Apuntado -------------------------------------------------------------

func aim_direction() -> Vector2:
	return Vector2.RIGHT.rotated(aim_angle)


func get_aim_target() -> Vector2:
	if aim_target_override != null:
		return aim_target_override
	return get_global_mouse_position()


func _update_aim() -> void:
	var mouse := get_aim_target()
	character_visual.set_facing(mouse.x - global_position.x)
	if current_weapon and current_weapon.locks_aim():
		return
	aim_angle = (mouse - aim_pivot.global_position).angle()
	aim_pivot.rotation = aim_angle
	# Si apuntas a la izquierda, volteamos el arma para que no quede boca abajo.
	aim_pivot.scale.y = -1.0 if absf(aim_angle) > PI / 2.0 else 1.0
	# Apuntando hacia arriba, el arma queda detrás del cuerpo.
	aim_pivot.z_index = -1 if sin(aim_angle) < -0.35 else 1


# --- Salto ----------------------------------------------------------------

func try_jump(target: Vector2) -> void:
	if is_airborne or _dash_timer > 0.0:
		return
	var offset := target - global_position
	var distance := clampf(offset.length(), jump_min_distance, jump_max_distance)
	var direction := offset.normalized() if offset.length() > 1.0 else aim_direction()
	var t := distance / jump_max_distance
	_jump_total = jump_duration * lerpf(0.7, 1.0, t)
	_jump_peak = jump_height * lerpf(0.6, 1.0, t)
	_jump_velocity = direction * distance / _jump_total
	_jump_elapsed = 0.0
	_plunging = false
	is_airborne = true
	collision_mask = AIR_MASK
	if current_weapon:
		current_weapon.on_jump_started()
	jumped.emit()


## Llamado por el arma al hacer un ataque aéreo: caes en picado.
func start_plunge() -> void:
	if is_airborne:
		_plunging = true


func _update_jump(delta: float) -> void:
	if _plunging:
		z -= plunge_fall_speed * delta
		velocity = _jump_velocity * 0.35
	else:
		_jump_elapsed += delta
		var t := clampf(_jump_elapsed / _jump_total, 0.0, 1.0)
		z = 4.0 * _jump_peak * t * (1.0 - t)
		velocity = _jump_velocity
		if t >= 1.0:
			z = 0.0
	if z <= 0.0:
		_land()


func _land() -> void:
	var was_plunging := _plunging
	z = 0.0
	is_airborne = false
	_plunging = false
	collision_mask = GROUND_MASK
	velocity = _jump_velocity * 0.25
	character_visual.play_land()
	dust.restart()
	if was_plunging:
		fx_player.play(&"slam")
		Events.camera_shake_requested.emit(4.0, 0.2)
	if current_weapon:
		current_weapon.on_landed(was_plunging)
	landed.emit(was_plunging)


# --- Dash -----------------------------------------------------------------

func try_dash() -> void:
	if is_airborne or _dash_cooldown_timer > 0.0:
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_direction = input_dir.normalized() if input_dir != Vector2.ZERO else aim_direction()
	_dash_timer = dash_time
	_dash_cooldown_timer = dash_cooldown
	dust.restart()
	if current_weapon:
		current_weapon.cancel()


## Empuje hacia donde apuntas (lo llaman las animaciones de ataque).
func lunge(speed: float) -> void:
	if is_airborne or _dash_timer > 0.0:
		return
	velocity = aim_direction() * speed


# --- Hotbar / aspecto -----------------------------------------------------

func select_slot(index: int) -> void:
	if hotbar.is_empty():
		return
	selected_slot = clampi(index, 0, hotbar.size() - 1)
	_equip(hotbar[selected_slot] as WeaponData)
	hotbar_changed.emit(hotbar, selected_slot)


func _equip(data: WeaponData) -> void:
	if current_weapon:
		weapon_holder.remove_child(current_weapon)
		current_weapon.queue_free()
		current_weapon = null
	if data == null or data.weapon_scene == null:
		return
	current_weapon = data.weapon_scene.instantiate() as Weapon
	current_weapon.data = data
	weapon_holder.add_child(current_weapon)
	current_weapon.setup(self)


func cycle_appearance() -> void:
	if appearances.is_empty():
		return
	_appearance_index = wrapi(_appearance_index + 1, 0, appearances.size())
	character_visual.appearance = appearances[_appearance_index]
	if current_weapon:
		current_weapon.apply_appearance(character_visual.appearance)
