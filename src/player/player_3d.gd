class_name Player3D
extends CharacterBody3D
## Jugador del juego 3D (ARPG con cámara en diagonal o isométrica).
##
## RED (mismas reglas que el 2D, ver AGENTS.md): el dueño simula todo; las copias remotas reciben por el nodo
## Sync la posición, el giro (`yaw`), la animación (`net_anim`), la carga y el equipo, y por RPC los disparos
## (`_fire`) y los efectos (`_spawn_fx`).
##
## Combate (los números en el Weapon3DData de cada arma):
##   clic izq.: combo · mantener: ataque cargado o ráfaga · clic der.: especial · mantener: especial cargado
##   atacar en el aire: ataque aéreo (caída en picado) · clic rueda: bola de fuego (gasta maná)
## Movimiento: WASD (relativo a la cámara) · Espacio: salto hacia donde corres · Shift: esquiva.
## Barra de 8 huecos (1-8 / rueda): el arma del hueco elegido; hueco vacío = puños (`unarmed`).

signal weapon_changed(weapon: Weapon3DData)
signal health_changed(health: float, max_health: float)
signal mana_changed(mana: float, max_mana: float)

@export_group("Movimiento")
@export var move_speed := 7.5
## Aceleración y frenada (más = más directo).
@export var acceleration := 95.0
@export var friction := 120.0
## Velocidad de giro del cuerpo hacia donde corre.
@export var turn_speed := 24.0

@export_group("Salto")
@export var gravity := 36.0
## Gravedad extra al caer (salto menos flotante).
@export var fall_gravity_multiplier := 1.45
@export var jump_velocity := 12.0
## Impulso horizontal del salto hacia donde corres (estilo Conquer).
@export var jump_forward_speed := 10.0
## Control en el aire (0 = ninguno, 1 = como en el suelo).
@export_range(0.0, 1.0) var air_control := 0.25
## Altura a partir de la cual los golpes te pasan por debajo (esquivar saltando).
@export var dodge_height := 0.9
## Segundos de aterrizaje en los que vas más lento.
@export var land_recovery := 0.1
## Velocidad de caída del ataque en picado.
@export var plunge_speed := 30.0

@export_group("Esquiva")
@export var dodge_speed := 19.0
@export var dodge_time := 0.24
@export var dodge_cooldown := 0.4

@export_group("Equipo")
## El personaje (escena con Avatar3D).
@export var avatar_scene: PackedScene
## Barra de objetos: 8 huecos (vacío = sin arma).
@export var hotbar: Array[Weapon3DData] = [null, null, null, null, null, null, null, null]
## Arma cuando el hueco elegido está vacío (los puños).
@export var unarmed: Weapon3DData
## Escudo para armas de una mano que lo admiten (allows_shield).
@export var shield_item: EquipmentData

@export_group("Vida y magia")
@export var max_health := 100.0
## Segundos invulnerable tras recibir un golpe.
@export var hurt_invulnerability := 0.5
## Segundos tumbado antes de reaparecer al morir.
@export var respawn_time := 2.5
@export var spell: Spell3DData
@export var max_mana := 100.0
@export var mana_regen := 12.0

# --- Estado sincronizado (nodo Sync) ---
var yaw := 0.0:
	set(value):
		yaw = value
		if is_node_ready() and not is_local():
			avatar_holder.rotation.y = value
## "clip#contador#velocidad": al cambiar, se reproduce en las copias remotas.
## Mismo clip y contador con otra velocidad = sigue la animación sin reiniciarla (cargas, carrera).
var net_anim := "":
	set(value):
		if value == net_anim:
			return
		var old := net_anim
		net_anim = value
		if is_node_ready() and not is_local() and avatar:
			_apply_net_anim(old, value)
var charging := false:
	set(value):
		charging = value
		if is_node_ready():
			charge_particles.emitting = value
## Hueco elegido de la barra (0..7).
var slot_index := 0:
	set(value):
		slot_index = value
		if is_node_ready():
			_equip_weapon()
var health := 100.0

var mana := 100.0
var _hurt_timer := 0.0
var _dead_timer := 0.0
var _respawn_point := Vector3.ZERO
var avatar: Avatar3D
var current_weapon: Weapon3DData
## Si no es null, se apunta aquí en vez de al ratón (tests, mando).
var aim_target_override: Variant = null
## Si no es null, se usa como dirección de movimiento (tests): Vector2 como el de WASD.
var move_input_override: Variant = null

var _anim_counter := 0
# ataque en curso
var _attack: Attack3D
var _attack_key := ""
var _attack_time := 0.0
var _attack_length := 0.0
var _attack_fired := false
var _attack_bonus := 1.0
var _leaping := false
var _plunging := false
var _queued := false
var _combo_step := 0
var _combo_timer := 0.0
var _lunge := Vector3.ZERO
# botones mantenidos
var _primary_down := false
var _primary_time := 0.0
var _primary_pending := false
var _secondary_down := false
var _secondary_time := 0.0
var _secondary_pending := false
var _charge_key := ""
var _charge_time := 0.0
var _charge_full := false
# otros
var _alt_cooldown := 0.0
var _spell_cooldown := 0.0
var _dodge_timer := 0.0
var _dodge_cooldown_timer := 0.0
var _dodge_direction := Vector3.ZERO
var _air_time := 0.0
var _land_timer := 0.0
var _jump_windup := 0.0
var _jump_direction := Vector3.ZERO

@onready var avatar_holder: Node3D = $AvatarHolder
@onready var hitbox: Hitbox3D = $AvatarHolder/Hitbox
@onready var hitbox_shape: CollisionShape3D = $AvatarHolder/Hitbox/Shape
@onready var muzzle: Marker3D = $AvatarHolder/Muzzle
@onready var area_hitbox: Hitbox3D = $AreaHitbox
@onready var area_shape: CollisionShape3D = $AreaHitbox/Shape
@onready var hurtbox: Hurtbox3D = $Hurtbox
@onready var charge_particles: CPUParticles3D = $AvatarHolder/ChargeParticles
@onready var dust: CPUParticles3D = $Dust


func is_local() -> bool:
	return is_multiplayer_authority()


func is_attacking() -> bool:
	return _attack != null


func is_charging() -> bool:
	return _charge_key != ""


## En el aire por encima de `dodge_height` o esquivando: los golpes no te tocan.
func is_invulnerable() -> bool:
	return is_dead() or _hurt_timer > 0.0 or _dodge_timer > 0.0 or position.y > dodge_height


func is_dead() -> bool:
	return health <= 0.0


func _ready() -> void:
	health = max_health
	mana = max_mana
	_respawn_point = position
	add_to_group(&"players")
	avatar = avatar_scene.instantiate() as Avatar3D
	avatar_holder.add_child(avatar)
	_equip_weapon()
	hitbox.hurtbox_entered.connect(_on_hitbox_hit)
	area_hitbox.hurtbox_entered.connect(_on_hitbox_hit)
	hurtbox.hit_received.connect(_on_hit_received)
	avatar_holder.rotation.y = yaw
	if is_local():
		Events.local_player_ready.emit(self)
	else:
		collision_layer = 0
		collision_mask = 0


# --- Input ----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_local() or is_dead():
		return
	if event.is_action_pressed("attack_primary"):
		primary_down()
	elif event.is_action_released("attack_primary"):
		primary_up()
	elif event.is_action_pressed("attack_secondary"):
		secondary_down()
	elif event.is_action_released("attack_secondary"):
		secondary_up()
	elif event.is_action_pressed("cast_spell"):
		cast_spell()
	elif event.is_action_pressed("jump"):
		jump()
	elif event.is_action_pressed("dash"):
		dodge()
	elif event.is_action_pressed("hotbar_next"):
		slot_index = wrapi(slot_index + 1, 0, hotbar.size())
	elif event.is_action_pressed("hotbar_prev"):
		slot_index = wrapi(slot_index - 1, 0, hotbar.size())
	else:
		for i in hotbar.size():
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				slot_index = i
				break


## Clic izquierdo pulsado. Según el arma: combo al momento (o al soltar si se puede cargar).
func primary_down() -> void:
	_primary_down = true
	_primary_time = 0.0
	if current_weapon == null or _dodge_timer > 0.0:
		return
	if not is_on_floor() and current_weapon.air and not is_attacking():
		_start_attack(current_weapon.air, "air")
		return
	if current_weapon.hold_mode == Weapon3DData.HoldMode.CHARGE and current_weapon.heavy:
		_primary_pending = true # decidimos al soltar o al pasar el umbral
	else:
		_light_attack()


func primary_up() -> void:
	_primary_down = false
	if _charge_key == "heavy":
		_release_charge()
	elif _primary_pending:
		_primary_pending = false
		_light_attack()


func secondary_down() -> void:
	_secondary_down = true
	_secondary_time = 0.0
	if current_weapon == null or current_weapon.alt == null or _dodge_timer > 0.0:
		return
	if current_weapon.alt_hold:
		_secondary_pending = true
	else:
		_alt_attack()


func secondary_up() -> void:
	_secondary_down = false
	if _charge_key == "alt_hold":
		_release_charge()
	elif _secondary_pending:
		_secondary_pending = false
		_alt_attack()


## Clic de la rueda: lanza el hechizo si hay maná.
func cast_spell() -> void:
	if spell == null or spell.cast == null or mana < spell.mana_cost or _spell_cooldown > 0.0 or _dodge_timer > 0.0:
		return
	_cancel_charge()
	_cancel_attack()
	mana -= spell.mana_cost
	mana_changed.emit(mana, max_mana)
	_spell_cooldown = spell.cooldown
	_start_attack(spell.cast, "spell")


# --- Simulación (solo el dueño) -------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_local():
		return
	if is_dead():
		_tick_death(delta)
		return
	_tick_timers(delta)
	_tick_holds(delta)

	var wish := _move_input()
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var on_floor := is_on_floor()
	if _jump_windup > 0.0:
		_jump_windup -= delta
		flat = flat.move_toward(Vector3.ZERO, friction * delta)
		if _jump_windup <= 0.0:
			_launch_jump()
			flat = Vector3(velocity.x, 0.0, velocity.z)
	elif _dodge_timer > 0.0:
		_dodge_timer -= delta
		flat = _dodge_direction * dodge_speed
	elif _leaping:
		pass # el salto de ataque lleva su propia trayectoria
	elif not on_floor:
		flat = flat.move_toward(wish * move_speed, acceleration * air_control * delta)
	else:
		var speed := move_speed
		if is_attacking():
			speed *= _attack.move_multiplier
		elif is_charging():
			speed *= 0.35
		if _land_timer > 0.0:
			speed *= 0.4
		var rate := acceleration if wish != Vector3.ZERO else friction
		flat = flat.move_toward(wish * speed, rate * delta)
	_lunge = _lunge.move_toward(Vector3.ZERO, 60.0 * delta)
	var vertical := velocity.y
	if not on_floor:
		vertical -= gravity * (fall_gravity_multiplier if vertical < 0.0 and not _leaping else 1.0) * delta
	else:
		vertical = maxf(vertical, -1.0)
	velocity = Vector3(flat.x + _lunge.x, vertical, flat.z + _lunge.z)
	move_and_slide()
	_check_landing(on_floor, delta)

	# Giro: hacia donde corre (atacando o cargando, hacia el ratón).
	if is_charging():
		_face(get_aim_target(), delta)
	elif not is_attacking() and _dodge_timer <= 0.0 and flat.length() > 0.5:
		yaw = lerp_angle(yaw, atan2(flat.x, flat.z), minf(1.0, turn_speed * delta))
	avatar_holder.rotation.y = yaw
	_update_animation(flat, delta)


## Tumbado: cae al suelo y reaparece en su punto de salida con la vida llena.
func _tick_death(delta: float) -> void:
	_dead_timer += delta
	velocity = Vector3(0, velocity.y - gravity * delta if not is_on_floor() else 0.0, 0)
	move_and_slide()
	if _dead_timer >= respawn_time:
		_dead_timer = 0.0
		health = max_health
		mana = max_mana
		health_changed.emit(health, max_health)
		global_position = _respawn_point
		velocity = Vector3.ZERO
		reset_physics_interpolation()
		_hurt_timer = 1.0
		_play("Idle", 1.0, true)


func _tick_timers(delta: float) -> void:
	_hurt_timer = maxf(0.0, _hurt_timer - delta)
	_dodge_cooldown_timer = maxf(0.0, _dodge_cooldown_timer - delta)
	_alt_cooldown = maxf(0.0, _alt_cooldown - delta)
	_spell_cooldown = maxf(0.0, _spell_cooldown - delta)
	_land_timer = maxf(0.0, _land_timer - delta)
	if mana < max_mana:
		mana = minf(max_mana, mana + mana_regen * delta)
		mana_changed.emit(mana, max_mana)
	if not is_attacking() and _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo_step = 0


## Mantener clic: pasado el umbral empieza la carga (o la ráfaga).
func _tick_holds(delta: float) -> void:
	if current_weapon == null:
		return
	if _primary_down:
		_primary_time += delta
		if _primary_pending and _primary_time >= current_weapon.hold_threshold and not is_attacking():
			_primary_pending = false
			_start_charge("heavy", current_weapon.heavy)
		elif current_weapon.hold_mode == Weapon3DData.HoldMode.REPEAT and not is_attacking() \
				and _primary_time >= current_weapon.hold_threshold and _dodge_timer <= 0.0:
			_light_attack(current_weapon.repeat_speed_scale)
	if _secondary_down:
		_secondary_time += delta
		if _secondary_pending and _secondary_time >= current_weapon.hold_threshold and not is_attacking() \
				and _alt_cooldown <= 0.0:
			_secondary_pending = false
			_start_charge("alt_hold", current_weapon.alt_hold)
	if is_charging():
		_charge_time += delta
		if not _charge_full and _charge_time >= current_weapon.max_charge_time:
			_charge_full = true
			Events.camera_shake_requested.emit(0.12, 0.1)


func _move_input() -> Vector3:
	var input: Vector2 = move_input_override if move_input_override != null \
			else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input.x, 0.0, input.y)
	var cam := get_viewport().get_camera_3d()
	if cam:
		dir = dir.rotated(Vector3.UP, cam.global_rotation.y) # arriba en pantalla = arriba
	return dir.limit_length(1.0)


# --- Salto, esquiva y aterrizaje ------------------------------------------

## Salto estilo Conquer: se agacha un instante y sale disparado hacia donde corres.
func jump() -> void:
	if not is_on_floor() or is_attacking() or _jump_windup > 0.0 or _dodge_timer > 0.0:
		return
	_cancel_charge()
	_jump_direction = _move_input().normalized()
	_jump_windup = 0.06
	_play("Jump_Start", 2.2, true)


func _launch_jump() -> void:
	velocity.y = jump_velocity
	var forward := _jump_direction * jump_forward_speed
	velocity.x = forward.x if _jump_direction != Vector3.ZERO else velocity.x
	velocity.z = forward.z if _jump_direction != Vector3.ZERO else velocity.z
	if _jump_direction != Vector3.ZERO:
		yaw = atan2(_jump_direction.x, _jump_direction.z)


func dodge() -> void:
	if _dodge_cooldown_timer > 0.0 or not is_on_floor() or _leaping:
		return
	var dir := _move_input().normalized()
	if dir == Vector3.ZERO:
		dir = Vector3(sin(yaw), 0, cos(yaw))
	_cancel_charge()
	_cancel_attack()
	yaw = atan2(dir.x, dir.z)
	_dodge_direction = dir
	_dodge_timer = dodge_time
	_dodge_cooldown_timer = dodge_cooldown
	_play("Dodge_Forward", 1.7, true)


func _check_landing(was_on_floor: bool, delta: float) -> void:
	if not is_on_floor():
		_air_time += delta
		return
	if was_on_floor:
		_air_time = 0.0
		return
	# Acaba de aterrizar.
	var heavy_landing := _air_time > 0.35
	_air_time = 0.0
	if _leaping or _plunging:
		_leaping = false
		_plunging = false
		velocity.x = 0.0
		velocity.z = 0.0
		var land := _attack.land_attack if _attack else null
		if land:
			_start_attack(land, _attack_key + "/land")
		return
	if is_attacking():
		return
	_land_timer = land_recovery if heavy_landing else 0.0
	_play("Jump_Land", 2.0 if heavy_landing else 2.8, true)
	if heavy_landing:
		Events.camera_shake_requested.emit(0.08, 0.08)


# --- Ataques --------------------------------------------------------------

func _light_attack(speed_scale: float = 1.0) -> void:
	if current_weapon == null or current_weapon.combo.is_empty():
		return
	if is_attacking():
		_queued = true
		return
	var step := _combo_step % current_weapon.combo.size()
	_combo_step = (_combo_step + 1) % current_weapon.combo.size()
	_combo_timer = current_weapon.combo_window
	_start_attack(current_weapon.combo[step], "combo%d" % step, 1.0, speed_scale)


func _alt_attack() -> void:
	if is_attacking() or _alt_cooldown > 0.0 or current_weapon.alt == null:
		return
	_alt_cooldown = current_weapon.alt_cooldown
	_start_attack(current_weapon.alt, "alt")


## Empieza a cargar: la animación del ataque va a cámara muy lenta (preparando el golpe).
func _start_charge(key: String, attack: Attack3D) -> void:
	if attack == null:
		return
	_charge_key = key
	_charge_time = 0.0
	_charge_full = false
	charging = true
	_play(attack.clip, 0.12, true)


func _release_charge() -> void:
	var key := _charge_key
	var ratio := clampf(_charge_time / maxf(current_weapon.max_charge_time, 0.01), 0.0, 1.0)
	_cancel_charge()
	var attack := current_weapon.heavy if key == "heavy" else current_weapon.alt_hold
	if key == "alt_hold":
		_alt_cooldown = current_weapon.alt_cooldown
	_start_attack(attack, key, lerpf(1.0, current_weapon.max_charge_multiplier, ratio), 1.0, false)


func _cancel_charge() -> void:
	_charge_key = ""
	_primary_pending = false
	_secondary_pending = false
	charging = false


## Lanza un ataque: gira al ratón, pone la animación, empuja hacia delante o salta.
func _start_attack(attack: Attack3D, key: String, bonus: float = 1.0, speed_scale: float = 1.0, restart: bool = true) -> void:
	if attack == null:
		return
	_attack = attack
	_attack_key = key
	_attack_bonus = bonus
	_attack_time = 0.0
	_attack_fired = false
	_queued = false
	hitbox.active = false
	area_hitbox.active = false
	if not key.ends_with("/land"):
		_face(get_aim_target())
	var forward := Vector3(sin(yaw), 0, cos(yaw))
	var speed := attack.speed * speed_scale
	if attack.leap != Attack3D.Leap.NONE:
		_start_leap(attack)
		if attack.clip != "" and attack.land_attack:
			# que el golpe de la animación coincida con el aterrizaje
			speed = avatar.clip_length(attack.clip) * maxf(attack.hit_time, 0.1) / attack.leap_time
	if attack.plunge and not is_on_floor():
		_plunging = true
		velocity.y = -plunge_speed
	if attack.clip != "":
		_attack_length = avatar.clip_length(attack.clip) / maxf(speed, 0.01)
		_play(attack.clip, speed, restart)
	else:
		_attack_length = 0.3
	if attack.lunge > 0.0 and is_on_floor():
		_lunge = forward * attack.lunge
	if attack.area:
		(area_shape.shape as SphereShape3D).radius = attack.area_radius
	if attack.fx_scene and not attack.fx_on_hit:
		_spawn_fx.rpc(key)


func _start_leap(attack: Attack3D) -> void:
	var aim := get_aim_target() - global_position
	aim.y = 0.0
	var offset: Vector3
	if attack.leap == Attack3D.Leap.TO_TARGET:
		offset = aim.limit_length(attack.leap_distance)
	else:
		offset = -aim.normalized() * attack.leap_distance
	var t := maxf(attack.leap_time, 0.1)
	velocity = Vector3(offset.x / t, 0.5 * gravity * t, offset.z / t)
	_leaping = true


func _update_attack(delta: float) -> void:
	_attack_time += delta
	var t := _attack_time / maxf(_attack_length, 0.01)
	var a := _attack
	var in_window := t >= a.hit_time and t <= a.hit_time + a.hit_window
	var airborne := _leaping or _plunging
	if a.projectiles > 0:
		if t >= a.hit_time and not _attack_fired:
			_attack_fired = true
			var target := get_aim_target()
			_fire.rpc(_attack_key, muzzle.global_position, yaw, _attack_bonus, target)
	elif not airborne:
		(area_hitbox if a.area else hitbox).active = in_window
	if t >= a.hit_time and not _attack_fired and a.projectiles == 0 and not airborne:
		_attack_fired = true
		if a.shake > 0.0:
			Events.camera_shake_requested.emit(a.shake, 0.15)
		if a.fx_scene and a.fx_on_hit:
			_spawn_fx.rpc(_attack_key)
	if airborne:
		return # el ataque sigue hasta aterrizar
	# Cancelar: pasado el golpe, moverse, encadenar o mantener corta la animación.
	var after_hit := t > a.hit_time + a.hit_window
	var moving := _move_input() != Vector3.ZERO
	if t >= 1.0 or (_queued and t >= 0.55) or (after_hit and moving and t >= 0.6):
		var queued := _queued
		_cancel_attack()
		if queued:
			_light_attack()


func _cancel_attack() -> void:
	_attack = null
	_queued = false
	_leaping = false
	_plunging = false
	hitbox.active = false
	area_hitbox.active = false


## Busca el ataque por su clave ("combo0", "heavy", "alt", "alt_hold", "air", "spell", ".../land").
func attack_by_key(key: String) -> Attack3D:
	var parts := key.split("/")
	var attack: Attack3D = null
	var w := current_weapon
	match parts[0]:
		"heavy": attack = w.heavy
		"alt": attack = w.alt
		"alt_hold": attack = w.alt_hold
		"air": attack = w.air
		"spell": attack = spell.cast if spell else null
		_:
			if parts[0].begins_with("combo") and w:
				var i := parts[0].trim_prefix("combo").to_int()
				attack = w.combo[i] if i < w.combo.size() else null
	for i in range(1, parts.size()):
		attack = attack.land_attack if attack else null
	return attack


## Crea los proyectiles en todos los peers; solo la copia del dueño hace daño.
@rpc("authority", "call_local", "reliable")
func _fire(key: String, origin: Vector3, fire_yaw: float, bonus: float, target: Vector3) -> void:
	var attack := attack_by_key(key)
	if attack == null:
		return
	var is_spell := key == "spell"
	var scene := attack.projectile_scene if attack.projectile_scene else current_weapon.projectile_scene
	if scene == null:
		return
	var base := spell.base_damage if is_spell else current_weapon.base_damage
	var count := attack.projectiles
	# Disparando desde el aire, los proyectiles bajan hacia el objetivo (a la altura del pecho).
	var flat_distance := Vector2(target.x - origin.x, target.z - origin.z).length()
	var drop := origin.y - (target.y + 1.0)
	var pitch := atan2(drop, maxf(flat_distance, 2.0)) if drop > 0.8 else 0.0
	for i in count:
		var spread := 0.0 if count == 1 else deg_to_rad(lerpf(-0.5, 0.5, float(i) / float(count - 1)) * attack.spread_degrees)
		var projectile := scene.instantiate() as Projectile3D
		var a := fire_yaw + spread
		projectile.direction = Vector3(sin(a) * cos(pitch), -sin(pitch), cos(a) * cos(pitch))
		projectile.speed = spell.projectile_speed if is_spell else current_weapon.projectile_speed
		projectile.damage = base * attack.damage_multiplier * bonus
		projectile.crit_chance = spell.crit_chance if is_spell else current_weapon.crit_chance
		projectile.crit_multiplier = spell.crit_multiplier if is_spell else current_weapon.crit_multiplier
		projectile.shooter = self
		projectile.visual_only = not is_local()
		if is_spell:
			var flat := Vector2(target.x - origin.x, target.z - origin.z).length()
			projectile.max_distance = clampf(flat, 1.5, spell.max_range)
		projectile.scale = Vector3.ONE * attack.projectile_scale
		get_parent().add_child(projectile)
		projectile.global_position = origin


## Efecto del ataque en todos los peers (solo visual).
@rpc("authority", "call_local", "reliable")
func _spawn_fx(key: String) -> void:
	var attack := attack_by_key(key)
	if attack == null or attack.fx_scene == null:
		return
	var fx := attack.fx_scene.instantiate() as Node3D
	if attack.fx_attached:
		add_child(fx)
	else:
		get_parent().add_child(fx)
		fx.global_position = global_position


func _on_hitbox_hit(target: Hurtbox3D, source: Hitbox3D) -> void:
	if not is_local() or current_weapon == null or _attack == null:
		return
	var w := current_weapon
	var hit := HitData.roll(w.base_damage, _attack.damage_multiplier * _attack_bonus, w.crit_chance, w.crit_multiplier)
	var push := target.global_position - global_position
	hit.knockback = Vector2(push.x, push.z).normalized() * w.knockback * _attack.knockback_multiplier
	hit.source = self
	hit.attack_name = StringName(_attack_key)
	target.receive_hit(hit)
	var strong := hit.is_crit or _attack_bonus > 1.3 or _attack.area
	Events.hitstop_requested.emit(0.06 if strong else 0.035)
	Events.camera_shake_requested.emit(0.25 if strong else 0.12, 0.12)


## Gira hacia un punto (de golpe, o suave si se pasa `delta`).
func _face(point: Vector3, delta: float = -1.0) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		var target_yaw := atan2(to.x, to.z)
		yaw = target_yaw if delta < 0.0 else lerp_angle(yaw, target_yaw, minf(1.0, 20.0 * delta))
		avatar_holder.rotation.y = yaw


## Punto del suelo bajo el ratón (o `aim_target_override`).
func get_aim_target() -> Vector3:
	if aim_target_override != null:
		return aim_target_override
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return global_position + Vector3(sin(yaw), 0, cos(yaw))
	var mouse := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mouse)
	var normal := cam.project_ray_normal(mouse)
	if absf(normal.y) < 0.0001:
		return global_position
	return origin + normal * ((0.0 - origin.y) / normal.y)


# --- Daño recibido --------------------------------------------------------

func _on_hit_received(hit: HitData) -> void:
	if is_invulnerable():
		return
	health = maxf(0.0, health - hit.amount)
	velocity += Vector3(hit.knockback.x, 0, hit.knockback.y)
	health_changed.emit(health, max_health)
	_hurt_timer = hurt_invulnerability
	Events.camera_shake_requested.emit(0.3, 0.15)
	if is_dead():
		_cancel_charge()
		_cancel_attack()
		_dodge_timer = 0.0
		_dead_timer = 0.0
		_play("Death01", 1.0, true)
	elif not is_attacking():
		_play("Hit_A", 1.5, true)


# --- Animación ------------------------------------------------------------

func _update_animation(flat: Vector3, _delta: float) -> void:
	if is_attacking():
		_update_attack(get_physics_process_delta_time())
		return
	if is_charging() or _dodge_timer > 0.0 or _jump_windup > 0.0:
		return
	var current := net_anim.get_slice("#", 0)
	if not is_on_floor():
		if current != "Jump_Start" or velocity.y < 2.0:
			_play("Jump_Idle")
		return
	if current == "Jump_Land" and avatar.is_playing("Jump_Land") and flat.length() < 1.0:
		return
	if current == "Hit_A" and avatar.is_playing("Hit_A"):
		return
	if flat.length() > 0.6:
		# la zancada va a la velocidad real (en pasos de 0.1 para no saturar la red)
		_play("Running_A", snappedf(clampf(flat.length() / move_speed, 0.5, 1.3) * 1.2, 0.1))
	else:
		_play(current_weapon.idle_clip if current_weapon else "Idle")


func _play(clip: String, speed: float = 1.0, restart: bool = false) -> void:
	var parts := net_anim.split("#")
	if parts[0] == clip and not restart:
		if parts.size() > 2 and is_equal_approx(float(parts[2]), speed):
			return
		net_anim = "%s#%s#%.2f" % [clip, parts[1], speed] # misma animación, otra velocidad
		avatar.set_speed(clip, speed)
		return
	_anim_counter += 1
	net_anim = "%s#%d#%.2f" % [clip, _anim_counter, speed]
	avatar.play(clip, speed, restart)
	_on_clip_started(clip)


func _apply_net_anim(old: String, value: String) -> void:
	var parts := value.split("#")
	var old_parts := old.split("#")
	var speed := float(parts[2]) if parts.size() > 2 else 1.0
	if old_parts.size() > 1 and parts.size() > 1 and old_parts[0] == parts[0] and old_parts[1] == parts[1]:
		avatar.set_speed(parts[0], speed)
	else:
		avatar.play(parts[0], speed, true)
		_on_clip_started(parts[0])


## Efectos ligados a una animación (en todos los peers).
func _on_clip_started(clip: String) -> void:
	if clip in ["Jump_Land", "Dodge_Forward", "Jump_Start"]:
		dust.restart()


# --- Equipo ---------------------------------------------------------------

func _equip_weapon() -> void:
	if avatar == null:
		return
	_cancel_charge()
	_cancel_attack()
	var item: Weapon3DData = hotbar[slot_index] if slot_index < hotbar.size() else null
	current_weapon = item if item else unarmed
	avatar.equip(current_weapon)
	avatar.unequip(EquipmentData.Slot.OFF_HAND)
	if current_weapon.offhand_scene:
		var offhand := EquipmentData.new()
		offhand.slot = EquipmentData.Slot.OFF_HAND
		offhand.scene = current_weapon.offhand_scene
		avatar.equip(offhand)
	elif shield_item and current_weapon.allows_shield:
		avatar.equip(shield_item)
	var box := hitbox_shape.shape as BoxShape3D
	box.size = Vector3(current_weapon.width, 2.0, current_weapon.reach)
	hitbox_shape.position = Vector3(0, 1.0, current_weapon.reach * 0.5 + 0.3)
	_combo_step = 0
	weapon_changed.emit(current_weapon)
