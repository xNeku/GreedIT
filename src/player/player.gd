class_name Player
extends CharacterBody2D
## Jugador top-down.
## - Movimiento con inercia (WASD). Mira hacia donde corre; al atacar, se gira hacia el ratón.
## - Salto: hacia donde te mueves (quieto = salto en el sitio), con anticipación (se agacha) y fases
##   de subida / cima / caída que anima CharacterVisual. En el aire pasas por encima de enemigos.
##   Atacar en el aire = ataque aéreo + caída en picado (slam al aterrizar).
## - Dash (Shift). Más adelante lo darán objetos; ahora viene de serie para probar.
## - Hotbar estilo Terraria (1-6 / rueda).
## - Interactuar (E) con recursos cercanos: minería, herboristería y pesca.

signal hotbar_changed(items: Array[ItemData], selected: int)
signal jumped
signal landed(was_plunging: bool)
signal gathering_started(target: Gatherable)
signal gathering_stopped

const GROUND_MASK := 1 | 4 ## world + enemies
const AIR_MASK := 1 ## en el aire solo chocas con el mundo

@export_group("Movimiento")
@export var move_speed := 115.0
@export var acceleration := 1000.0
@export var friction := 1300.0
## Aceleración al cambiar de sentido (giros más secos).
@export var turn_acceleration := 1900.0
## Multiplicador de velocidad mientras atacas.
@export var attack_move_multiplier := 0.35

@export_group("Salto")
## Distancia del salto si te estás moviendo (saltas hacia donde corres).
@export var jump_distance := 105.0
@export var jump_duration := 0.46
@export var jump_height := 26.0
## Segundos agachándose antes de despegar (anticipación).
@export var jump_windup := 0.05
## Velocidad de caída (px/s) al hacer un ataque aéreo.
@export var plunge_fall_speed := 280.0

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
var inventory := Inventory.new()
## Altura actual sobre el suelo (px). 0 = en el suelo.
var z := 0.0
var is_airborne := false
var aim_angle := 0.0
## 1 = mira a la derecha, -1 = a la izquierda.
var facing := 1.0
var is_gathering: bool:
	get:
		return _gather_target != null

var _windup_timer := 0.0
var _pending_jump := Vector2.ZERO
var _jump_elapsed := 0.0
var _jump_total := 0.0
var _jump_peak := 0.0
var _jump_velocity := Vector2.ZERO
var _plunging := false
var _weapon_leap := false
var _last_z := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_direction := Vector2.ZERO
var _appearance_index := 0
var _interactables: Array[Gatherable] = []
var _focused: Gatherable
var _gather_target: Gatherable
var _tool: GatherTool

@onready var visual_root: Node2D = $VisualRoot
@onready var character_visual: CharacterVisual = $VisualRoot/CharacterVisual
@onready var aim_pivot: Node2D = $VisualRoot/AimPivot
@onready var weapon_holder: Node2D = $VisualRoot/AimPivot/WeaponHolder
@onready var shadow: Sprite2D = $Shadow
@onready var fx_player: AnimationPlayer = $FXPlayer
@onready var dust: CPUParticles2D = $GroundFX/Dust
@onready var interact_area: Area2D = $InteractArea
@onready var prompt: InteractPrompt = $Prompt


func _ready() -> void:
	collision_mask = GROUND_MASK
	interact_area.area_entered.connect(_on_interact_area_entered)
	interact_area.area_exited.connect(_on_interact_area_exited)
	if not appearances.is_empty():
		character_visual.appearance = appearances[0]
	select_slot(selected_slot)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack_primary"):
		_stop_gathering()
		_aim_at_target()
		if current_weapon:
			current_weapon.primary_pressed()
	elif event.is_action_released("attack_primary"):
		if current_weapon:
			current_weapon.primary_released()
	elif event.is_action_pressed("attack_secondary"):
		_stop_gathering()
		_aim_at_target()
		if current_weapon:
			current_weapon.secondary_pressed()
	elif event.is_action_released("attack_secondary"):
		if current_weapon:
			current_weapon.secondary_released()
	elif event.is_action_pressed("jump"):
		try_jump()
	elif event.is_action_pressed("dash"):
		try_dash()
	elif event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("hotbar_next"):
		select_slot(wrapi(selected_slot + 1, 0, hotbar.size()))
	elif event.is_action_pressed("hotbar_prev"):
		select_slot(wrapi(selected_slot - 1, 0, hotbar.size()))
	elif event.is_action_pressed("toggle_character"):
		cycle_appearance()
	else:
		for i in hotbar.size():
			var action := "hotbar_%d" % (i + 1)
			if InputMap.has_action(action) and event.is_action_pressed(action):
				select_slot(i)
				break


func _physics_process(delta: float) -> void:
	_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if is_gathering and input_dir != Vector2.ZERO:
		_stop_gathering()

	if _windup_timer > 0.0:
		_windup_timer -= delta
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		if _windup_timer <= 0.0:
			_launch_jump()
	elif _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_direction * dash_speed
	elif is_airborne:
		_update_jump(delta)
	else:
		var speed := move_speed
		if current_weapon and current_weapon.is_busy():
			speed *= attack_move_multiplier
		if is_gathering:
			speed = 0.0
		var target := input_dir * speed
		var rate := acceleration
		if input_dir == Vector2.ZERO:
			rate = friction
		elif velocity.dot(target) < 0.0:
			rate = turn_acceleration
		velocity = velocity.move_toward(target, rate * delta)

	move_and_slide()
	_update_facing_and_aim()
	_update_focus()
	_update_visuals(delta)


func _update_visuals(delta: float) -> void:
	visual_root.position.y = -roundf(z)
	var shadow_scale := lerpf(1.0, 0.55, clampf(z / 40.0, 0.0, 1.0))
	shadow.scale = Vector2(shadow_scale, shadow_scale)
	character_visual.set_moving(velocity.length() > 12.0 and not is_airborne and _windup_timer <= 0.0)
	if is_airborne:
		var vz := (z - _last_z) / maxf(delta, 0.0001)
		if _plunging or vz < -35.0:
			character_visual.set_air_phase(CharacterVisual.AirPhase.FALLING)
		elif vz > 35.0:
			character_visual.set_air_phase(CharacterVisual.AirPhase.RISING)
		else:
			character_visual.set_air_phase(CharacterVisual.AirPhase.PEAK)
	else:
		character_visual.set_air_phase(CharacterVisual.AirPhase.GROUND)
	_last_z = z


# --- Orientación y apuntado -----------------------------------------------

func aim_direction() -> Vector2:
	return Vector2.RIGHT.rotated(aim_angle)


func get_aim_target() -> Vector2:
	if aim_target_override != null:
		return aim_target_override
	return get_global_mouse_position()


func _aim_at_target() -> void:
	aim_angle = (get_aim_target() - aim_pivot.global_position).angle()
	facing = 1.0 if cos(aim_angle) >= 0.0 else -1.0
	_apply_aim()


func _update_facing_and_aim() -> void:
	var aiming := current_weapon != null and current_weapon.visible and current_weapon.wants_aim()
	if is_gathering:
		aim_angle = (_gather_target.get_gather_point() - aim_pivot.global_position).angle()
		facing = 1.0 if cos(aim_angle) >= 0.0 else -1.0
	elif aiming:
		if not current_weapon.locks_aim():
			aim_angle = (get_aim_target() - aim_pivot.global_position).angle()
		facing = 1.0 if cos(aim_angle) >= 0.0 else -1.0
	else:
		# En reposo el arma mira hacia donde mira el personaje, y este hacia donde corre.
		if absf(velocity.x) > 8.0 and not is_airborne:
			facing = signf(velocity.x)
		aim_angle = 0.0 if facing > 0.0 else PI
	_apply_aim()
	aim_pivot.z_index = -1 if (aiming and sin(aim_angle) < -0.35) else 1


func _apply_aim() -> void:
	character_visual.set_facing(facing)
	aim_pivot.rotation = aim_angle
	# Si apuntas a la izquierda, volteamos el arma para que no quede boca abajo.
	aim_pivot.scale.y = -1.0 if cos(aim_angle) < 0.0 else 1.0


# --- Salto ----------------------------------------------------------------

## Salta hacia donde te mueves (con WASD). Quieto: salto en el sitio.
func try_jump() -> void:
	jump(Input.get_vector("move_left", "move_right", "move_up", "move_down"))


func jump(direction: Vector2) -> void:
	if is_airborne or _windup_timer > 0.0 or _dash_timer > 0.0:
		return
	_stop_gathering()
	_pending_jump = direction.normalized() if direction.length() > 0.1 else Vector2.ZERO
	if _pending_jump.x != 0.0:
		facing = signf(_pending_jump.x)
	_windup_timer = jump_windup
	character_visual.play_jump_windup()
	if current_weapon:
		current_weapon.on_jump_started()


func _launch_jump() -> void:
	var moving := _pending_jump != Vector2.ZERO
	var distance := jump_distance if moving else 0.0
	var height := jump_height if moving else jump_height * 0.8
	_start_air(_pending_jump, distance, height, jump_duration, false)
	dust.restart()
	if current_weapon:
		current_weapon.refresh_pose()
	jumped.emit()


## Salto lanzado por un arma (salto con maza, pértiga del bō...). Devuelve si ha despegado.
func weapon_leap(direction: Vector2, distance: float, height: float, duration: float) -> bool:
	if is_airborne:
		return false
	_windup_timer = 0.0
	_dash_timer = 0.0
	_start_air(direction.normalized(), distance, height, duration, true)
	dust.restart()
	return true


func _start_air(direction: Vector2, distance: float, height: float, duration: float, weapon_leap: bool) -> void:
	_jump_total = duration
	_jump_peak = height
	_jump_velocity = direction * distance / duration
	_jump_elapsed = 0.0
	_plunging = false
	_weapon_leap = weapon_leap
	is_airborne = true
	collision_mask = AIR_MASK


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
	var was_leap := _weapon_leap
	z = 0.0
	is_airborne = false
	_plunging = false
	_weapon_leap = false
	collision_mask = GROUND_MASK
	velocity = _jump_velocity * 0.25
	character_visual.play_land(was_plunging or was_leap)
	dust.restart()
	if was_plunging or was_leap:
		fx_player.play(&"slam")
		Events.camera_shake_requested.emit(4.0, 0.2)
	if current_weapon:
		current_weapon.on_landed(was_plunging)
	landed.emit(was_plunging)


# --- Dash -----------------------------------------------------------------

func try_dash() -> void:
	if is_airborne or _dash_cooldown_timer > 0.0 or _windup_timer > 0.0:
		return
	_stop_gathering()
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_direction = input_dir.normalized() if input_dir != Vector2.ZERO else Vector2(facing, 0.0)
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


# --- Interacción y recolección --------------------------------------------

## Tecla E: recolectar lo que tengas cerca (o lo que pida la herramienta, p. ej. tirar de la caña).
func interact() -> void:
	if _tool and _tool.interact_pressed():
		return
	if is_gathering:
		_stop_gathering()
	elif _focused and not is_airborne:
		_start_gathering(_focused)


## Texto del cartel "E" sobre la cabeza. Vacío = ocultar.
func set_prompt(text: String, urgent: bool = false) -> void:
	if text.is_empty():
		prompt.hide_prompt()
	else:
		prompt.show_prompt(text, urgent)


func _on_interact_area_entered(area: Area2D) -> void:
	var gatherable := area.get_parent() as Gatherable
	if gatherable and not _interactables.has(gatherable):
		_interactables.append(gatherable)


func _on_interact_area_exited(area: Area2D) -> void:
	var gatherable := area.get_parent() as Gatherable
	if gatherable:
		_interactables.erase(gatherable)


func _update_focus() -> void:
	var best: Gatherable = null
	if not is_gathering and not is_airborne:
		var best_distance := INF
		for gatherable in _interactables:
			var d := global_position.distance_squared_to(gatherable.global_position)
			if d < best_distance:
				best_distance = d
				best = gatherable
	if best == _focused:
		return
	if _focused:
		_focused.set_focused(false)
	_focused = best
	if _focused:
		_focused.set_focused(true)
		set_prompt(_focused.action_text)
	elif not is_gathering:
		set_prompt("")


func _start_gathering(target: Gatherable) -> void:
	if target.tool_scene == null:
		return
	if current_weapon:
		current_weapon.cancel()
		current_weapon.visible = false
	_gather_target = target
	velocity = Vector2.ZERO
	set_prompt("")
	_tool = target.tool_scene.instantiate() as GatherTool
	weapon_holder.add_child(_tool)
	_tool.setup(self, target)
	gathering_started.emit(target)


func _stop_gathering() -> void:
	if not is_gathering:
		return
	if _tool:
		weapon_holder.remove_child(_tool)
		_tool.queue_free()
		_tool = null
	_gather_target = null
	set_prompt("")
	if current_weapon:
		current_weapon.visible = true
	gathering_stopped.emit()


# --- Hotbar / aspecto -----------------------------------------------------

func select_slot(index: int) -> void:
	if hotbar.is_empty():
		return
	_stop_gathering()
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
	if _tool:
		_tool.apply_appearance(character_visual.appearance)
