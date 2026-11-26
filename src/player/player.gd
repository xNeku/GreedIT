class_name Player
extends CharacterBody2D
## Jugador top-down (estilo Diablo / Path of Exile), preparado para coop.
##
## RED: cada jugador manda sobre su propio personaje (multiplayer authority = su peer id).
##   - En su ordenador se simula todo (input, física, armas, vida, inventario).
##   - En los demás es una COPIA REMOTA: recibe posición/estado por el MultiplayerSynchronizer ("Sync")
##     y los momentos puntuales (saltar, atacar, cambiar de arma...) por la RPC _net_event().
##   - En solo funciona igual (OfflineMultiplayerPeer: somos el peer 1 y mandamos sobre todo).
##
## - Movimiento rápido y con respuesta inmediata (WASD). Mira hacia donde corre; al atacar, al ratón.
## - Salto hacia donde corres, con anticipación. En el aire pasas por encima de enemigos y esquivas golpes.
##   Atacar en el aire = ataque aéreo + caída en picado (slam al aterrizar).
## - Dash (Shift). Hotbar 1-6 / rueda. El arma va a la espalda si no la usas.
## - E: minería, herboristería, pesca. Clic de la rueda: hechizo (bola de fuego).
## - Vida: invulnerable un momento tras un golpe, regenera fuera de combate, al morir reaparece.

signal hotbar_changed(items: Array[ItemData], selected: int)
signal jumped
signal landed(was_plunging: bool)
signal gathering_started(target: Gatherable)
signal gathering_stopped
signal mana_changed(mana: float, max_mana: float)
## Intentaste lanzar sin maná o en enfriamiento.
signal cast_failed(reason: String)
signal spell_cast(spell: SpellData)
signal health_changed(health: float, max_health: float)
signal died
signal respawned

const GROUND_MASK := 1 | 4 ## world + enemies
const AIR_MASK := 1 ## en el aire solo chocas con el mundo

## Eventos que el dueño manda a las copias remotas.
enum NetEvent { JUMP, LAND, DASH, WEAPON, SLOT, GATHER, HURT, DIED, RESPAWN, APPEARANCE }
## Acciones de arma que se replican.
enum WeaponAction { PRIMARY_DOWN, PRIMARY_UP, SECONDARY_DOWN, SECONDARY_UP, CAST }

@export_group("Movimiento")
@export var move_speed := 160.0
@export var acceleration := 2400.0
@export var friction := 2800.0
## Aceleración al cambiar de sentido (giros secos, estilo ARPG).
@export var turn_acceleration := 3600.0
## Multiplicador de velocidad mientras atacas.
@export var attack_move_multiplier := 0.35

@export_group("Salto")
## Distancia del salto si te estás moviendo (saltas hacia donde corres).
@export var jump_distance := 120.0
@export var jump_duration := 0.44
@export var jump_height := 26.0
## Segundos agachándose antes de despegar (anticipación).
@export var jump_windup := 0.05
## Velocidad de caída (px/s) al hacer un ataque aéreo.
@export var plunge_fall_speed := 280.0

@export_group("Dash")
@export var dash_speed := 460.0
@export var dash_time := 0.14
@export var dash_cooldown := 0.6

@export_group("Armas")
## Segundos sin atacar para guardar el arma a la espalda.
@export var sheathe_delay := 2.5

@export_group("Inventario")
@export var hotbar: Array[ItemData] = []
@export var selected_slot := 0

@export_group("Magia")
## Hechizo de la rueda del ratón.
@export var spell: SpellData
@export var max_mana := 100.0
## Maná por segundo.
@export var mana_regen := 12.0

@export_group("Vida")
@export var max_health := 100.0
## Segundos invulnerable (parpadeando) tras recibir un golpe.
@export var invulnerability_time := 0.7
## Vida por segundo fuera de combate.
@export var health_regen := 4.0
## Segundos sin recibir daño para empezar a regenerar.
@export var regen_delay := 4.0
## Por encima de esta altura de salto, los golpes no te alcanzan.
@export var dodge_height := 12.0
@export var respawn_delay := 1.6
@export var damage_number_scene: PackedScene
@export var floating_text_scene: PackedScene

@export_group("Aspecto")
## Pulsa C para ir cambiando entre estos aspectos.
@export var appearances: Array[CharacterAppearance] = []

# --- Estado sincronizado por red (ver nodo Sync) -------------------------
## Altura actual sobre el suelo (px). 0 = en el suelo.
var z := 0.0
var is_airborne := false
var aim_angle := 0.0
## 1 = mira a la derecha, -1 = a la izquierda.
var facing := 1.0
var health := 100.0
var is_dead := false
## Vista del personaje (CharacterVisual.View) para las copias remotas.
var net_view := 0:
	set(value):
		net_view = value
		if is_node_ready() and not is_multiplayer_authority():
			character_visual.set_view(value)
			_update_grip()
## true = arma en la mano; false = guardada a la espalda (manos libres).
var weapon_drawn := false:
	set(value):
		if value == weapon_drawn:
			return
		weapon_drawn = value
		if is_node_ready():
			_refresh_hands()
var appearance_index := 0:
	set(value):
		appearance_index = value
		if is_node_ready():
			_apply_appearance_index()

var current_weapon: Weapon
## Si no es null, se apunta aquí en vez de al ratón (mandos, IA, tests).
var aim_target_override: Variant = null
var inventory := Inventory.new()
var mana := 100.0
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
var _interactables: Array[Gatherable] = []
var _focused: Gatherable
var _gather_target: Gatherable
var _tool: GatherTool
var _spell_cooldown := 0.0
var _last_mana_emitted := -1.0
var _invulnerable_timer := 0.0
var _hurt_flash := 0.0
var _since_damage := 100.0
var _spawn_point := Vector2.ZERO
var _sheathe_timer := 0.0

@onready var visual_root: Node2D = $VisualRoot
@onready var character_visual: CharacterVisual = $VisualRoot/CharacterVisual
@onready var aim_pivot: Node2D = $VisualRoot/AimPivot
@onready var weapon_holder: Node2D = $VisualRoot/AimPivot/WeaponHolder
@onready var shadow: Sprite2D = $Shadow
@onready var fx_player: AnimationPlayer = $FXPlayer
@onready var dust: CPUParticles2D = $GroundFX/Dust
@onready var interact_area: Area2D = $InteractArea
@onready var prompt: InteractPrompt = $Prompt
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	collision_mask = GROUND_MASK
	health = max_health
	mana = max_mana
	_spawn_point = global_position
	_apply_appearance_index()
	hurtbox.hit_received.connect(_on_hit_received)
	if is_local():
		interact_area.area_entered.connect(_on_interact_area_entered)
		interact_area.area_exited.connect(_on_interact_area_exited)
		camera.enabled = true
		camera.make_current()
		Events.local_player_ready.emit(self)
	else:
		# Copia remota: sin cámara, sin interacción, sin chocar con nada (su dueño la mueve).
		camera.enabled = false
		interact_area.monitoring = false
		collision_layer = 0
		collision_mask = 0
	select_slot(selected_slot)


## ¿Es el jugador que controla este ordenador?
func is_local() -> bool:
	return is_multiplayer_authority()


func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or is_dead:
		return
	if event.is_action_pressed("attack_primary"):
		_stop_gathering()
		draw_weapon()
		_aim_at_target()
		weapon_action(WeaponAction.PRIMARY_DOWN)
	elif event.is_action_released("attack_primary"):
		weapon_action(WeaponAction.PRIMARY_UP)
	elif event.is_action_pressed("attack_secondary"):
		_stop_gathering()
		draw_weapon()
		_aim_at_target()
		weapon_action(WeaponAction.SECONDARY_DOWN)
	elif event.is_action_released("attack_secondary"):
		weapon_action(WeaponAction.SECONDARY_UP)
	elif event.is_action_pressed("jump"):
		try_jump()
	elif event.is_action_pressed("dash"):
		try_dash()
	elif event.is_action_pressed("interact"):
		interact()
	elif event.is_action_pressed("cast_spell"):
		try_cast()
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
	if not is_local():
		_update_remote(delta)
		return
	_dash_cooldown_timer = maxf(0.0, _dash_cooldown_timer - delta)
	_update_mana(delta)
	_update_health(delta)
	_update_sheathe(delta)
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		_update_visuals(delta)
		return
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


## Copia remota: solo dibuja lo que le llega por red.
func _update_remote(delta: float) -> void:
	_apply_aim()
	var aiming := current_weapon != null and current_weapon.visible and current_weapon.wants_aim()
	aim_pivot.z_index = -1 if (sin(aim_angle) < -0.35 if aiming else character_visual.is_back_view()) else 1
	_hurt_flash = move_toward(_hurt_flash, 0.0, delta * 5.0)
	visual_root.modulate = Color(1.0, 1.0 - _hurt_flash * 0.65, 1.0 - _hurt_flash * 0.65)
	visual_root.rotation = -PI / 2.0 * facing if is_dead else 0.0
	_update_visuals(delta)


func _update_visuals(delta: float) -> void:
	visual_root.position.y = -roundf(z)
	var shadow_scale := lerpf(1.0, 0.55, clampf(z / 40.0, 0.0, 1.0))
	shadow.scale = Vector2(shadow_scale, shadow_scale)
	var speed := velocity.length()
	character_visual.set_moving(speed > 20.0 and not is_airborne and _windup_timer <= 0.0)
	character_visual.set_speed_ratio(speed / move_speed)
	if is_airborne or z > 0.0:
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


# --- Red -----------------------------------------------------------------

## El dueño avisa a las copias remotas de algo puntual.
func _send(event: NetEvent, a: Variant = null, b: Variant = null) -> void:
	if is_local() and multiplayer.has_multiplayer_peer() and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		_net_event.rpc(event, a, b)


@rpc("authority", "call_remote", "reliable")
func _net_event(event: int, a: Variant = null, b: Variant = null) -> void:
	match event:
		NetEvent.JUMP:
			character_visual.play_jump_windup()
			dust.restart()
			if current_weapon:
				current_weapon.on_jump_started()
		NetEvent.LAND:
			character_visual.play_land(a or b)
			dust.restart()
			if a or b:
				fx_player.play(&"slam")
			if current_weapon:
				current_weapon.on_landed(a)
		NetEvent.DASH:
			dust.restart()
			if current_weapon:
				current_weapon.cancel()
		NetEvent.WEAPON:
			if a != WeaponAction.PRIMARY_UP and a != WeaponAction.SECONDARY_UP:
				weapon_drawn = true
			_apply_weapon_action(a)
		NetEvent.SLOT:
			selected_slot = a
			_equip(hotbar[a] as WeaponData)
		NetEvent.GATHER:
			if a == "":
				_stop_gathering()
			else:
				var target := get_node_or_null(NodePath(a)) as Gatherable
				if target:
					_start_gathering(target)
		NetEvent.HURT:
			_hurt_flash = 1.0
			_spawn_damage_number(a, b)
		NetEvent.DIED:
			character_visual.play_land(true)
		NetEvent.RESPAWN:
			visual_root.rotation = 0.0
		NetEvent.APPEARANCE:
			appearance_index = a


## Botín que nos manda el servidor (p. ej. al matar un mob). Solo actúa en el dueño.
@rpc("any_peer", "call_local", "reliable")
func receive_item(item_path: String, amount: int) -> void:
	if not is_local():
		return
	var item := load(item_path) as ItemData
	if item == null:
		return
	inventory.add(item, amount)
	_show_floating_text("+%d %s" % [amount, item.display_name], item.icon)


# --- Armas ---------------------------------------------------------------

## Ejecuta una acción de arma aquí y la replica a los demás.
func weapon_action(action: WeaponAction) -> void:
	_apply_weapon_action(action)
	_send(NetEvent.WEAPON, action)


func _apply_weapon_action(action: int) -> void:
	if current_weapon == null:
		return
	match action:
		WeaponAction.PRIMARY_DOWN:
			current_weapon.primary_pressed()
		WeaponAction.PRIMARY_UP:
			current_weapon.primary_released()
		WeaponAction.SECONDARY_DOWN:
			current_weapon.secondary_pressed()
		WeaponAction.SECONDARY_UP:
			current_weapon.secondary_released()
		WeaponAction.CAST:
			current_weapon.cast()


# --- Orientación y apuntado -----------------------------------------------

func aim_direction() -> Vector2:
	return Vector2.RIGHT.rotated(aim_angle)


func get_aim_target() -> Vector2:
	if not is_local():
		return aim_pivot.global_position + aim_direction() * 120.0
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
	_update_view(aiming)
	var behind := sin(aim_angle) < -0.35 if aiming else character_visual.is_back_view()
	aim_pivot.z_index = -1 if behind else 1


## Vista del personaje (8 direcciones con el volteo): según hacia dónde apuntas (atacando)
## o hacia dónde te mueves. Quieto conserva la última.
func _update_view(aiming: bool) -> void:
	var dir := Vector2.ZERO
	if aiming or is_gathering:
		dir = Vector2.RIGHT.rotated(aim_angle)
	elif velocity.length() > 12.0:
		dir = velocity.normalized()
	if dir == Vector2.ZERO:
		return
	var angle := rad_to_deg(atan2(dir.y, absf(dir.x))) # -90 arriba ... 90 abajo
	var view := CharacterVisual.View.SIDE
	if angle > 67.5:
		view = CharacterVisual.View.FRONT
	elif angle > 22.5:
		view = CharacterVisual.View.FRONT_SIDE
	elif angle < -67.5:
		view = CharacterVisual.View.BACK
	elif angle < -22.5:
		view = CharacterVisual.View.BACK_SIDE
	if view != character_visual.view:
		character_visual.set_view(view)
		net_view = view
		_update_grip()


func _apply_aim() -> void:
	character_visual.set_facing(facing)
	aim_pivot.rotation = aim_angle
	# Si apuntas a la izquierda, volteamos el arma para que no quede boca abajo.
	aim_pivot.scale.y = -1.0 if cos(aim_angle) < 0.0 else 1.0
	# De perfil el cuerpo es más estrecho: el arma en reposo se pega un poco al cuerpo.
	var resting := current_weapon == null or not current_weapon.wants_aim()
	var tuck := {CharacterVisual.View.SIDE: -7.0, CharacterVisual.View.FRONT_SIDE: -3.0, CharacterVisual.View.BACK_SIDE: -3.0}
	weapon_holder.position.x = tuck.get(character_visual.view, 0.0) if resting else 0.0
	if current_weapon:
		current_weapon.set_off_hand_hidden(resting and character_visual.view == CharacterVisual.View.SIDE)


# --- Salto ----------------------------------------------------------------

## Salta hacia donde te mueves (con WASD). Quieto: salto en el sitio.
func try_jump() -> void:
	jump(Input.get_vector("move_left", "move_right", "move_up", "move_down"))


func jump(direction: Vector2) -> void:
	if is_airborne or _windup_timer > 0.0 or _dash_timer > 0.0 or is_dead:
		return
	_stop_gathering()
	_pending_jump = direction.normalized() if direction.length() > 0.1 else Vector2.ZERO
	if _pending_jump.x != 0.0:
		facing = signf(_pending_jump.x)
	_windup_timer = jump_windup
	character_visual.play_jump_windup()
	if current_weapon:
		current_weapon.on_jump_started()
	_send(NetEvent.JUMP)


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
## En una copia remota no mueve nada (la posición llega por red) pero devuelve true para la animación.
func weapon_leap(direction: Vector2, distance: float, height: float, duration: float) -> bool:
	if not is_local():
		return true
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
	if is_local() and is_airborne:
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
	_send(NetEvent.LAND, was_plunging, was_leap)
	landed.emit(was_plunging)


# --- Dash -----------------------------------------------------------------

func try_dash() -> void:
	if is_airborne or _dash_cooldown_timer > 0.0 or _windup_timer > 0.0 or is_dead:
		return
	_stop_gathering()
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_direction = input_dir.normalized() if input_dir != Vector2.ZERO else Vector2(facing, 0.0)
	_dash_timer = dash_time
	_dash_cooldown_timer = dash_cooldown
	dust.restart()
	if current_weapon:
		current_weapon.cancel()
	_send(NetEvent.DASH)


## Empuje hacia donde apuntas (lo llaman las animaciones de ataque).
func lunge(speed: float) -> void:
	if not is_local() or is_airborne or _dash_timer > 0.0:
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
	if not is_local() or text.is_empty():
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
	_sheathe_weapon()
	_gather_target = target
	velocity = Vector2.ZERO
	set_prompt("")
	_tool = target.tool_scene.instantiate() as GatherTool
	weapon_holder.add_child(_tool)
	_tool.setup(self, target)
	_refresh_hands()
	_update_grip()
	_send(NetEvent.GATHER, String(target.get_path()))
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
	_refresh_hands()
	_send(NetEvent.GATHER, "")
	gathering_stopped.emit()


# --- Vida -----------------------------------------------------------------

## Solo se llama en el dueño (el Hurtbox reenvía los golpes a quien manda sobre este jugador).
func _on_hit_received(hit: HitData) -> void:
	if is_dead or _invulnerable_timer > 0.0 or _dash_timer > 0.0 or z > dodge_height:
		return
	health = maxf(0.0, health - hit.amount)
	_since_damage = 0.0
	_invulnerable_timer = invulnerability_time
	_hurt_flash = 1.0
	health_changed.emit(health, max_health)
	_spawn_damage_number(hit.amount, hit.is_crit)
	_send(NetEvent.HURT, hit.amount, hit.is_crit)
	_stop_gathering()
	if not is_airborne:
		velocity = hit.knockback * 1.3
	Events.camera_shake_requested.emit(4.0, 0.2)
	Events.hitstop_requested.emit(0.05)
	if health <= 0.0:
		_die()


func _spawn_damage_number(amount: int, is_crit: bool) -> void:
	if damage_number_scene == null:
		return
	var number := damage_number_scene.instantiate() as DamageNumber
	number.amount = amount
	number.is_crit = is_crit
	number.color_override = Color(1.0, 0.35, 0.3)
	_add_to_overlay(number)
	number.global_position = global_position + Vector2(0, -78)


func _show_floating_text(text: String, icon: Texture2D) -> void:
	if floating_text_scene == null:
		return
	var floating := floating_text_scene.instantiate() as FloatingText
	floating.text = text
	floating.icon = icon
	_add_to_overlay(floating)
	floating.global_position = global_position + Vector2(0, -70)


func _add_to_overlay(node: Node2D) -> void:
	var container := get_tree().get_first_node_in_group(&"world_overlay")
	(container if container else get_parent()).add_child(node)


func _update_health(delta: float) -> void:
	_invulnerable_timer = maxf(0.0, _invulnerable_timer - delta)
	_hurt_flash = move_toward(_hurt_flash, 0.0, delta * 5.0)
	_since_damage += delta
	if not is_dead and _since_damage > regen_delay and health < max_health:
		health = minf(max_health, health + health_regen * delta)
		health_changed.emit(health, max_health)
	# Rojo al recibir el golpe y parpadeo mientras eres invulnerable.
	var color := Color(1.0, 1.0 - _hurt_flash * 0.65, 1.0 - _hurt_flash * 0.65)
	if _invulnerable_timer > 0.0 and not is_dead:
		color.a = 0.35 if fmod(_invulnerable_timer, 0.12) < 0.06 else 1.0
	visual_root.modulate = color


func _die() -> void:
	is_dead = true
	_stop_gathering()
	if current_weapon:
		current_weapon.cancel()
	set_prompt("")
	character_visual.play_land(true)
	visual_root.rotation = -PI / 2.0 * facing # cae de lado
	_send(NetEvent.DIED)
	died.emit()
	get_tree().create_timer(respawn_delay).timeout.connect(_respawn)


func _respawn() -> void:
	is_dead = false
	visual_root.rotation = 0.0
	global_position = _spawn_point
	velocity = Vector2.ZERO
	health = max_health
	mana = max_mana
	_invulnerable_timer = 2.0
	health_changed.emit(health, max_health)
	_send(NetEvent.RESPAWN)
	respawned.emit()


# --- Magia ----------------------------------------------------------------

## Clic de la rueda: lanza el hechizo hacia el ratón. El arma hace el gesto con la mano libre
## y llama a release_spell() en el momento justo.
func try_cast() -> void:
	if spell == null or is_dead:
		return
	if _spell_cooldown > 0.0:
		cast_failed.emit("Recargando")
		return
	if mana < spell.mana_cost:
		cast_failed.emit("Sin maná")
		return
	_stop_gathering()
	draw_weapon()
	_aim_at_target()
	mana -= spell.mana_cost
	_spell_cooldown = spell.cooldown
	spell_cast.emit(spell)
	if current_weapon and weapon_drawn:
		weapon_action(WeaponAction.CAST)
	else:
		release_spell()


## Crea el proyectil del hechizo en la mano libre (o delante del pecho).
## En las copias remotas también se crea, pero solo visual: el daño lo hace la copia del dueño.
func release_spell() -> void:
	if spell == null or spell.projectile_scene == null:
		return
	var origin := aim_pivot.global_position + aim_direction() * 14.0
	if current_weapon:
		var hand := current_weapon.find_child("HandOff", true, false) as Node2D
		if hand:
			origin = hand.global_position
	var projectile := spell.projectile_scene.instantiate() as Fireball
	var to_target := get_aim_target() - origin
	projectile.direction = to_target.normalized() if to_target.length() > 4.0 else aim_direction()
	projectile.speed = spell.projectile_speed
	projectile.spell = spell
	projectile.caster = self
	get_parent().add_child(projectile)
	projectile.global_position = origin


## 0 = listo, 1 = recién lanzado.
func spell_cooldown_ratio() -> float:
	if spell == null or spell.cooldown <= 0.0:
		return 0.0
	return clampf(_spell_cooldown / spell.cooldown, 0.0, 1.0)


func _update_mana(delta: float) -> void:
	_spell_cooldown = maxf(0.0, _spell_cooldown - delta)
	mana = minf(max_mana, mana + mana_regen * delta)
	if absf(mana - _last_mana_emitted) >= 0.5 or (mana >= max_mana and _last_mana_emitted < max_mana):
		_last_mana_emitted = mana
		mana_changed.emit(mana, max_mana)


# --- Desenfundar / enfundar -----------------------------------------------

## Saca el arma de la espalda a la mano (al atacar o lanzar).
func draw_weapon() -> void:
	_sheathe_timer = sheathe_delay
	if weapon_drawn or current_weapon == null:
		return
	weapon_drawn = true


func _sheathe_weapon() -> void:
	if not weapon_drawn:
		return
	if current_weapon:
		current_weapon.cancel()
	weapon_drawn = false


func _update_sheathe(delta: float) -> void:
	if not weapon_drawn or current_weapon == null:
		return
	if current_weapon.wants_aim() or current_weapon.is_busy() or is_airborne:
		_sheathe_timer = sheathe_delay
		return
	_sheathe_timer -= delta
	if _sheathe_timer <= 0.0:
		_sheathe_weapon()


## Qué se ve: arma en la mano, herramienta, o manos libres + arma a la espalda.
func _refresh_hands() -> void:
	var data := current_weapon.data if current_weapon else null
	if _tool:
		if current_weapon:
			current_weapon.visible = false
		character_visual.set_free_hands_visible(false)
		character_visual.set_back_item(data)
	elif weapon_drawn and current_weapon:
		current_weapon.visible = true
		character_visual.set_free_hands_visible(false)
		character_visual.set_back_item(null)
	else:
		if current_weapon:
			current_weapon.visible = false
		character_visual.set_free_hands_visible(true)
		character_visual.set_back_item(data)


func _update_grip() -> void:
	var back := character_visual.is_back_view()
	if current_weapon:
		HandUtils.set_grip_back_view(current_weapon, back)
	if _tool:
		HandUtils.set_grip_back_view(_tool, back)


# --- Hotbar / aspecto -----------------------------------------------------

func select_slot(index: int) -> void:
	if hotbar.is_empty():
		return
	_stop_gathering()
	selected_slot = clampi(index, 0, hotbar.size() - 1)
	_equip(hotbar[selected_slot] as WeaponData)
	_send(NetEvent.SLOT, selected_slot)
	hotbar_changed.emit(hotbar, selected_slot)


func _equip(data: WeaponData) -> void:
	if current_weapon:
		weapon_holder.remove_child(current_weapon)
		current_weapon.queue_free()
		current_weapon = null
	if data == null or data.weapon_scene == null:
		_refresh_hands()
		return
	current_weapon = data.weapon_scene.instantiate() as Weapon
	current_weapon.data = data
	weapon_holder.add_child(current_weapon)
	current_weapon.setup(self)
	if is_local():
		weapon_drawn = false
	_refresh_hands()
	_update_grip()


func cycle_appearance() -> void:
	if appearances.is_empty():
		return
	appearance_index = wrapi(appearance_index + 1, 0, appearances.size())
	_send(NetEvent.APPEARANCE, appearance_index)


func _apply_appearance_index() -> void:
	if appearances.is_empty():
		return
	character_visual.appearance = appearances[clampi(appearance_index, 0, appearances.size() - 1)]
	if current_weapon:
		current_weapon.apply_appearance(character_visual.appearance)
	if _tool:
		_tool.apply_appearance(character_visual.appearance)
