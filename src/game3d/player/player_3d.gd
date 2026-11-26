class_name Player3D
extends CharacterBody3D
## Jugador del juego 3D (estilo ARPG, cámara en diagonal desde arriba).
##
## RED (mismas reglas que el 2D, ver AGENTS.md): el dueño simula todo; las copias remotas reciben por el nodo
## Sync la posición, el giro (`yaw`), la animación (`net_anim`) y el equipo, y por RPC los disparos.
##
## Controles: WASD mover · clic izq: combo · clic der: especial · Espacio: saltar · Shift: esquivar
## 1-6 / rueda: arma · C: personaje · H: casco · G: capa · V: escudo · B: peto (armadura con esqueleto).

signal weapon_changed(weapon: Weapon3DData)
signal equipment_changed
signal health_changed(health: float, max_health: float)

@export_group("Movimiento")
@export var move_speed := 7.0
@export var acceleration := 70.0
@export var friction := 80.0
## Velocidad de giro del cuerpo hacia donde corre.
@export var turn_speed := 16.0
## Multiplicador de velocidad mientras atacas.
@export var attack_move_multiplier := 0.25

@export_group("Salto y esquiva")
@export var gravity := 32.0
@export var jump_velocity := 10.5
@export var dodge_speed := 17.0
@export var dodge_time := 0.24
@export var dodge_cooldown := 0.45

@export_group("Equipo")
@export var weapons: Array[Weapon3DData] = []
## Casco / capa. Vacío = la ropa de serie del personaje (H y G la quitan y ponen).
@export var head_item: EquipmentData
@export var back_item: EquipmentData
## Escudo para armas de una mano (V lo quita y pone).
@export var shield_item: EquipmentData
## Armadura con esqueleto (B la pone y quita): se deforma con las animaciones.
@export var chest_item: EquipmentData
## Personajes que se alternan con C (escenas con Avatar3D).
@export var avatars: Array[PackedScene] = []

@export_group("Combate")
## Segundos tras un golpe en los que el combo sigue.
@export var combo_window := 0.6
@export var max_health := 100.0
@export var damage_label_scene: PackedScene

# --- Estado sincronizado (nodo Sync) ---
var yaw := 0.0:
	set(value):
		yaw = value
		if is_node_ready() and not is_local():
			avatar_holder.rotation.y = value
## "clip#contador#velocidad": al cambiar, se reproduce en las copias remotas.
var net_anim := "":
	set(value):
		if value == net_anim:
			return
		net_anim = value
		if is_node_ready() and not is_local() and avatar:
			var parts := value.split("#")
			avatar.play(parts[0], float(parts[2]) if parts.size() > 2 else 1.0, true)
var weapon_index := 0:
	set(value):
		weapon_index = value
		if is_node_ready():
			_equip_weapon()
var avatar_index := 0:
	set(value):
		avatar_index = value
		if is_node_ready():
			_load_avatar()
var helmet_on := true:
	set(value):
		helmet_on = value
		if is_node_ready():
			_apply_equipment()
var cape_on := true:
	set(value):
		cape_on = value
		if is_node_ready():
			_apply_equipment()
var shield_on := true:
	set(value):
		shield_on = value
		if is_node_ready():
			_equip_weapon()
var chest_on := false:
	set(value):
		chest_on = value
		if is_node_ready():
			_apply_equipment()
var health := 100.0

var avatar: Avatar3D
var current_weapon: Weapon3DData
## Si no es null, se apunta aquí en vez de al ratón (tests, mando).
var aim_target_override: Variant = null

var _anim_counter := 0
var _attack_clip := ""
var _attack_alt := false
var _attack_time := 0.0
var _attack_length := 0.0
var _shot_done := false
var _combo_step := 0
var _combo_timer := 0.0
var _queued := false
var _dodge_timer := 0.0
var _dodge_cooldown_timer := 0.0
var _dodge_direction := Vector3.ZERO
var _flash := 0.0

@onready var avatar_holder: Node3D = $AvatarHolder
@onready var hitbox: Hitbox3D = $AvatarHolder/Hitbox
@onready var hitbox_shape: CollisionShape3D = $AvatarHolder/Hitbox/Shape
@onready var muzzle: Marker3D = $AvatarHolder/Muzzle
@onready var area_hitbox: Hitbox3D = $AreaHitbox
@onready var hurtbox: Hurtbox3D = $Hurtbox


func is_local() -> bool:
	return is_multiplayer_authority()


func is_attacking() -> bool:
	return _attack_clip != ""


func _ready() -> void:
	health = max_health
	_load_avatar()
	hitbox.hurtbox_entered.connect(_on_hitbox_hit)
	area_hitbox.hurtbox_entered.connect(_on_hitbox_hit)
	hurtbox.hit_received.connect(_on_hit_received)
	avatar_holder.rotation.y = yaw
	if is_local():
		Events.local_player_3d_ready.emit(self)
	else:
		collision_layer = 0
		collision_mask = 0


# --- Input ----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not is_local():
		return
	if event.is_action_pressed("attack_primary"):
		attack(false)
	elif event.is_action_pressed("attack_secondary"):
		attack(true)
	elif event.is_action_pressed("jump"):
		jump()
	elif event.is_action_pressed("dash"):
		dodge()
	elif event.is_action_pressed("hotbar_next"):
		weapon_index = wrapi(weapon_index + 1, 0, weapons.size())
	elif event.is_action_pressed("hotbar_prev"):
		weapon_index = wrapi(weapon_index - 1, 0, weapons.size())
	elif event.is_action_pressed("toggle_character"):
		avatar_index = wrapi(avatar_index + 1, 0, avatars.size())
	elif event.is_action_pressed("toggle_helmet"):
		helmet_on = not helmet_on
	elif event.is_action_pressed("toggle_cape"):
		cape_on = not cape_on
	elif event.is_action_pressed("toggle_shield"):
		shield_on = not shield_on
	elif event.is_action_pressed("toggle_armor"):
		chest_on = not chest_on
	else:
		for i in weapons.size():
			var action := "hotbar_%d" % (i + 1)
			if InputMap.has_action(action) and event.is_action_pressed(action):
				weapon_index = i
				break


# --- Simulación (solo el dueño) -------------------------------------------

func _physics_process(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta * 5.0)
	if not is_local():
		return
	_dodge_cooldown_timer = maxf(0.0, _dodge_cooldown_timer - delta)
	if not is_attacking() and _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo_step = 0

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var wish := Vector3(input.x, 0.0, input.y)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		flat = _dodge_direction * dodge_speed
	else:
		var speed := move_speed * (attack_move_multiplier if is_attacking() else 1.0)
		var rate := acceleration if wish != Vector3.ZERO else friction
		flat = flat.move_toward(wish * speed, rate * delta)
	var vertical := velocity.y - gravity * delta if not is_on_floor() else maxf(velocity.y, -1.0)
	velocity = Vector3(flat.x, vertical, flat.z)
	move_and_slide()

	if not is_attacking() and _dodge_timer <= 0.0 and flat.length() > 0.5:
		yaw = lerp_angle(yaw, atan2(flat.x, flat.z), minf(1.0, turn_speed * delta))
	avatar_holder.rotation.y = yaw

	if is_attacking():
		_update_attack(delta)
	elif _dodge_timer > 0.0:
		pass
	elif not is_on_floor():
		_play("Jump_Idle")
	elif flat.length() > 0.6:
		_play("Running_A", clampf(flat.length() / move_speed, 0.6, 1.2) * 1.1)
	else:
		_play(current_weapon.idle_clip if current_weapon else "Idle")


func jump() -> void:
	if is_on_floor() and not is_attacking():
		velocity.y = jump_velocity
		_play("Jump_Start", 1.4, true)


func dodge() -> void:
	if _dodge_cooldown_timer > 0.0 or not is_on_floor():
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var dir := Vector3(input.x, 0, input.y).normalized()
	if dir == Vector3.ZERO:
		dir = Vector3(sin(yaw), 0, cos(yaw))
	_cancel_attack()
	yaw = atan2(dir.x, dir.z)
	_dodge_direction = dir
	_dodge_timer = dodge_time
	_dodge_cooldown_timer = dodge_cooldown
	_play("Dodge_Forward", 1.6, true)


# --- Ataque ---------------------------------------------------------------

## Clic izquierdo (combo) o derecho (`alt`). Gira hacia el ratón y lanza la animación del arma.
func attack(alt: bool) -> void:
	if current_weapon == null or _dodge_timer > 0.0:
		return
	if is_attacking():
		if not alt:
			_queued = true
		return
	var clip := current_weapon.alt_clip if alt else current_weapon.combo_clips[_combo_step % current_weapon.combo_clips.size()]
	if clip == "":
		return
	if not alt:
		_combo_step = (_combo_step + 1) % current_weapon.combo_clips.size()
	_combo_timer = combo_window
	_face(get_aim_target())
	_attack_clip = clip
	_attack_alt = alt
	_attack_time = 0.0
	_attack_length = avatar.clip_length(clip) / current_weapon.attack_speed
	_shot_done = false
	_queued = false
	hitbox.damage_multiplier = current_weapon.alt_damage_multiplier if alt else 1.0
	area_hitbox.damage_multiplier = current_weapon.alt_damage_multiplier
	_play(clip, current_weapon.attack_speed, true)
	if alt and current_weapon.alt_fx_scene:
		_spawn_fx.rpc(weapon_index)


## Efecto del clic derecho en todos los peers (solo visual).
@rpc("authority", "call_local", "reliable")
func _spawn_fx(index: int) -> void:
	var fx := weapons[index].alt_fx_scene.instantiate() as Node3D
	add_child(fx)


func _update_attack(delta: float) -> void:
	_attack_time += delta
	var t := _attack_time / maxf(_attack_length, 0.01)
	var w := current_weapon
	var area := _attack_alt and w.alt_is_area
	var in_window := t >= w.hit_time and t <= w.hit_time + w.hit_window
	if area:
		in_window = t >= 0.12 and t <= 0.85 # giros y novas golpean durante casi toda la animación
	if w.kind == Weapon3DData.Kind.MELEE or area:
		(area_hitbox if area else hitbox).active = in_window
	elif t >= w.hit_time and not _shot_done:
		_shot_done = true
		_shoot.rpc(muzzle.global_position, yaw, w.alt_projectiles if _attack_alt else 1)
	if t >= 1.0 or (_queued and t >= 0.7):
		var queued := _queued
		_cancel_attack()
		if queued:
			attack(false)


func _cancel_attack() -> void:
	_attack_clip = ""
	_queued = false
	hitbox.active = false
	area_hitbox.active = false


## Crea los proyectiles en todos los peers; solo la copia del dueño hace daño.
@rpc("authority", "call_local", "reliable")
func _shoot(origin: Vector3, shot_yaw: float, count: int) -> void:
	var w := current_weapon
	if w == null or w.projectile_scene == null:
		return
	for i in count:
		var spread := 0.0 if count == 1 else lerpf(-0.35, 0.35, float(i) / float(count - 1))
		var projectile := w.projectile_scene.instantiate() as Projectile3D
		projectile.direction = Vector3(sin(shot_yaw + spread), 0, cos(shot_yaw + spread))
		projectile.speed = w.projectile_speed
		projectile.damage = w.base_damage * (w.alt_damage_multiplier * 0.6 if count > 1 else 1.0)
		projectile.crit_chance = w.crit_chance
		projectile.crit_multiplier = w.crit_multiplier
		projectile.shooter = self
		projectile.visual_only = not is_local()
		get_parent().add_child(projectile)
		projectile.global_position = origin


func _on_hitbox_hit(target: Hurtbox3D, source: Hitbox3D) -> void:
	if not is_local() or current_weapon == null:
		return
	var hit := HitData.roll(current_weapon.base_damage, source.damage_multiplier, current_weapon.crit_chance, current_weapon.crit_multiplier)
	var push := target.global_position - global_position
	hit.knockback = Vector2(push.x, push.z).normalized() * current_weapon.knockback
	hit.source = self
	hit.attack_name = StringName(_attack_clip)
	target.receive_hit(hit)
	Events.hitstop_requested.emit(0.05 if hit.is_crit else 0.03)
	Events.camera_shake_requested.emit(0.25 if hit.is_crit else 0.12, 0.12)


func _face(point: Vector3) -> void:
	var to := point - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		yaw = atan2(to.x, to.z)
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
	return origin + normal * ((global_position.y - origin.y) / normal.y)


# --- Daño recibido --------------------------------------------------------

func _on_hit_received(hit: HitData) -> void:
	if _dodge_timer > 0.0:
		return # esquivando: invulnerable
	health = maxf(0.0, health - hit.amount)
	_flash = 1.0
	velocity += Vector3(hit.knockback.x, 0, hit.knockback.y)
	health_changed.emit(health, max_health)
	_play("Hit_A", 1.5, true)


# --- Animación y equipo ---------------------------------------------------

func _play(clip: String, speed: float = 1.0, restart: bool = false) -> void:
	var current := net_anim.get_slice("#", 0)
	if clip == current and not restart:
		avatar.animation_player.speed_scale = 1.0
		avatar.animation_player.play(clip, avatar.blend_time, speed)
		return
	_anim_counter += 1
	net_anim = "%s#%d#%.2f" % [clip, _anim_counter, speed]
	avatar.play(clip, speed, restart)


func _load_avatar() -> void:
	if avatars.is_empty():
		return
	if avatar:
		avatar_holder.remove_child(avatar)
		avatar.queue_free()
	avatar = avatars[clampi(avatar_index, 0, avatars.size() - 1)].instantiate() as Avatar3D
	avatar_holder.add_child(avatar)
	_apply_equipment()
	_equip_weapon()
	if net_anim != "":
		var parts := net_anim.split("#")
		avatar.play(parts[0], float(parts[2]) if parts.size() > 2 else 1.0)


func _equip_weapon() -> void:
	if avatar == null or weapons.is_empty():
		return
	_cancel_attack()
	current_weapon = weapons[clampi(weapon_index, 0, weapons.size() - 1)]
	avatar.equip(current_weapon)
	avatar.unequip(EquipmentData.Slot.OFF_HAND)
	if current_weapon.offhand_scene:
		var offhand := EquipmentData.new()
		offhand.slot = EquipmentData.Slot.OFF_HAND
		offhand.scene = current_weapon.offhand_scene
		avatar.equip(offhand)
	elif shield_on and shield_item and current_weapon.allows_shield:
		avatar.equip(shield_item)
	var box := hitbox_shape.shape as BoxShape3D
	box.size = Vector3(current_weapon.width, 2.0, current_weapon.reach)
	hitbox_shape.position = Vector3(0, 1.0, current_weapon.reach * 0.5 + 0.3)
	_combo_step = 0
	weapon_changed.emit(current_weapon)
	equipment_changed.emit()


func _apply_equipment() -> void:
	if avatar == null:
		return
	for entry: Array in [[EquipmentData.Slot.HEAD, head_item, helmet_on], [EquipmentData.Slot.BACK, back_item, cape_on],
			[EquipmentData.Slot.CHEST, chest_item, chest_on]]:
		var slot: EquipmentData.Slot = entry[0]
		var item: EquipmentData = entry[1]
		var on: bool = entry[2]
		if item and on:
			avatar.equip(item)
		else:
			avatar.unequip(slot)
		avatar.set_outfit_visible(slot, on)
	equipment_changed.emit()
