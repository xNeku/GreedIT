class_name Enemy
extends CharacterBody2D
## Enemigo básico con IA por estados: deambula -> te ve -> te persigue -> ataca -> se aturde -> muere.
##
## La escena define el aspecto y los ataques:
##   - Visual/Body (cuerpo; Visual se voltea según hacia dónde mira)
##   - Hurtbox (capa enemy_hurtbox) para recibir golpes
##   - AttackPivot (gira hacia el objetivo al empezar a atacar) con AttackHitbox (capa enemy_attacks)
##     y opcionalmente Muzzle (de dónde salen los proyectiles)
##   - HealthBar/Fill (barra de vida, aparece al recibir daño)
##   - AnimationPlayer con: idle, walk, attack (avisa, golpea y se recupera), hurt, die
##     Pistas de método disponibles en "attack": attack_lunge(), fire_projectile(), attack_shake().
## Los números (vida, velocidad, daño, alcance...) son @export: ajústalos en el inspector.

signal died(enemy: Enemy)

enum State { IDLE, WANDER, CHASE, ATTACK, HURT, DEAD }

@export_group("Vida")
@export var max_health := 60.0
## 0 = sale volando con los golpes, 1 = no se mueve.
@export_range(0.0, 1.0) var knockback_resistance := 0.0
## Segundos aturdido al recibir un golpe.
@export var stagger_time := 0.25
## Si es true, no se interrumpe su ataque al recibir golpes.
@export var super_armor := false

@export_group("Movimiento")
@export var move_speed := 70.0
@export var wander_speed := 28.0
@export var wander_radius := 60.0
@export var acceleration := 600.0

@export_group("Percepción")
## Distancia a la que te detecta.
@export var detection_radius := 180.0
## Distancia a la que deja de perseguirte.
@export var lose_radius := 280.0

@export_group("Ataque")
## Distancia a la que empieza a atacar.
@export var attack_range := 30.0
@export var attack_cooldown := 1.0
@export var attack_damage := 8.0
@export_range(0.0, 1.0) var attack_crit_chance := 0.05
## A distancia: si estás más cerca que esto, retrocede (0 = cuerpo a cuerpo).
@export var keep_distance := 0.0
@export var projectile_scene: PackedScene
@export var projectile_speed := 200.0

@export_group("Botín")
@export var drop: ItemData
@export_range(0.0, 1.0) var drop_chance := 0.6
@export var drop_min := 1
@export var drop_max := 1

@export_group("Escenas")
@export var damage_number_scene: PackedScene
@export var floating_text_scene: PackedScene

var health := 0.0
var state := State.IDLE
var target: Player

var _home := Vector2.ZERO
var _wander_target := Vector2.ZERO
var _timer := 0.0
var _attack_cooldown_timer := 0.0
var _flash := 0.0
var _facing := 1.0

@onready var visual: Node2D = $Visual
@onready var body: Node2D = $Visual/Body
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var attack_pivot: Node2D = $AttackPivot
@onready var attack_hitbox: Hitbox = $AttackPivot/AttackHitbox
@onready var health_bar: Node2D = $HealthBar
@onready var health_fill: ColorRect = $HealthBar/Fill
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var death_particles: CPUParticles2D = $DeathParticles
@onready var _flash_material: ShaderMaterial = body.material as ShaderMaterial
@onready var _bar_width := health_fill.size.x


func _ready() -> void:
	health = max_health
	_home = global_position
	hurtbox.hit_received.connect(_on_hit_received)
	attack_hitbox.hurtbox_entered.connect(_on_attack_hurtbox_entered)
	animation_player.animation_finished.connect(_on_animation_finished)
	health_bar.visible = false
	_enter_wander()


func _physics_process(delta: float) -> void:
	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)
	if target == null or not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as Player
	match state:
		State.IDLE, State.WANDER:
			_update_wander(delta)
		State.CHASE:
			_update_chase(delta)
		State.ATTACK, State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
			if state == State.HURT:
				_timer -= delta
				if _timer <= 0.0:
					_set_state(State.CHASE)
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
	move_and_slide()
	_update_visuals(delta)


# --- Estados --------------------------------------------------------------

func _set_state(new_state: State) -> void:
	state = new_state
	if state in [State.IDLE, State.WANDER, State.CHASE]:
		_play_locomotion()


func _enter_wander() -> void:
	_set_state(State.IDLE)
	_timer = randf_range(0.6, 2.0)


func _update_wander(delta: float) -> void:
	if _can_see_target():
		_set_state(State.CHASE)
		return
	_timer -= delta
	if state == State.IDLE:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		if _timer <= 0.0:
			_wander_target = _home + Vector2.from_angle(randf() * TAU) * randf_range(10.0, wander_radius)
			_timer = 3.0
			_set_state(State.WANDER)
	else:
		var to_point := _wander_target - global_position
		if to_point.length() < 6.0 or _timer <= 0.0:
			_enter_wander()
		else:
			velocity = velocity.move_toward(to_point.normalized() * wander_speed, acceleration * delta)
	_play_locomotion()


func _update_chase(delta: float) -> void:
	if not _target_alive():
		_enter_wander()
		return
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if distance > lose_radius:
		_enter_wander()
		return
	var dir := to_target / maxf(distance, 0.001)
	var desired := Vector2.ZERO
	if keep_distance > 0.0 and distance < keep_distance:
		desired = -dir * move_speed # demasiado cerca: retrocede
	elif distance > attack_range * 0.85:
		desired = dir * move_speed
	velocity = velocity.move_toward(desired, acceleration * delta)
	_face(dir.x)
	if distance <= attack_range and _attack_cooldown_timer <= 0.0:
		_start_attack(dir)
	_play_locomotion()


func _start_attack(dir: Vector2) -> void:
	_set_state(State.ATTACK)
	attack_pivot.rotation = dir.angle()
	_face(dir.x)
	animation_player.stop()
	animation_player.play(&"attack")


func _on_animation_finished(anim: StringName) -> void:
	match anim:
		&"attack":
			attack_hitbox.active = false
			_attack_cooldown_timer = attack_cooldown
			if state == State.ATTACK:
				_set_state(State.CHASE)
		&"die":
			queue_free()


# --- Daño recibido --------------------------------------------------------

func _on_hit_received(hit: HitData) -> void:
	if state == State.DEAD:
		return
	health -= hit.amount
	_flash = 1.0
	_spawn_damage_number(hit)
	health_bar.visible = true
	health_fill.size.x = _bar_width * clampf(health / max_health, 0.0, 1.0)
	if hit.source is Player:
		target = hit.source
	velocity = hit.knockback * (1.0 - knockback_resistance) * 1.6
	if health <= 0.0:
		_die()
	elif not (super_armor and state == State.ATTACK):
		attack_hitbox.active = false
		_set_state(State.HURT)
		_timer = stagger_time
		animation_player.stop()
		animation_player.play(&"hurt")
	elif state != State.ATTACK:
		_set_state(State.CHASE)


func _die() -> void:
	_set_state(State.DEAD)
	attack_hitbox.active = false
	health_bar.visible = false
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 1)
	hurtbox.set_deferred("monitorable", false)
	death_particles.restart()
	animation_player.stop()
	animation_player.play(&"die")
	_give_loot()
	died.emit(self)


func _give_loot() -> void:
	if drop == null or not _target_alive() or randf() > drop_chance:
		return
	var amount := randi_range(drop_min, drop_max)
	target.inventory.add(drop, amount)
	if floating_text_scene:
		var text := floating_text_scene.instantiate() as FloatingText
		text.text = "+%d %s" % [amount, drop.display_name]
		text.icon = drop.icon
		_add_to_overlay(text)
		text.global_position = global_position + Vector2(0, -60)


func _spawn_damage_number(hit: HitData) -> void:
	if damage_number_scene == null:
		return
	var number := damage_number_scene.instantiate() as DamageNumber
	number.amount = hit.amount
	number.is_crit = hit.is_crit
	_add_to_overlay(number)
	number.global_position = health_bar.global_position + Vector2(0, -6)


func _add_to_overlay(node: Node2D) -> void:
	var container := get_tree().get_first_node_in_group(&"world_overlay")
	(container if container else get_parent()).add_child(node)


# --- Ataque (pistas de método de la animación "attack") -------------------

func _on_attack_hurtbox_entered(target_hurtbox: Hurtbox, hitbox: Hitbox) -> void:
	var hit := HitData.roll(attack_damage, hitbox.damage_multiplier, attack_crit_chance, 1.5)
	hit.knockback = Vector2.from_angle(attack_pivot.rotation) * hitbox.knockback_force
	hit.source = self
	hit.attack_name = hitbox.attack_name
	hit.tags = hitbox.tags
	target_hurtbox.receive_hit(hit)


## Vibración de cámara (para golpes pesados).
func attack_shake(strength: float) -> void:
	Events.camera_shake_requested.emit(strength, 0.15)


## Embestida hacia donde ataca.
func attack_lunge(speed: float) -> void:
	velocity = Vector2.from_angle(attack_pivot.rotation) * speed


## Dispara `projectile_scene` hacia el objetivo desde AttackPivot/Muzzle.
func fire_projectile() -> void:
	if projectile_scene == null:
		return
	var muzzle := attack_pivot.get_node_or_null("Muzzle") as Node2D
	var origin := muzzle.global_position if muzzle else global_position
	var projectile := projectile_scene.instantiate() as EnemyProjectile
	var aim := (target.global_position + Vector2(0, -20) - origin) if _target_alive() else Vector2.from_angle(attack_pivot.rotation)
	projectile.direction = aim.normalized()
	projectile.speed = projectile_speed
	projectile.damage = attack_damage
	projectile.source = self
	get_parent().add_child(projectile)
	projectile.global_position = origin


# --- Utilidades -----------------------------------------------------------

func _can_see_target() -> bool:
	return _target_alive() and global_position.distance_to(target.global_position) <= detection_radius


func _target_alive() -> bool:
	return target != null and is_instance_valid(target) and not target.is_dead


func _face(dir_x: float) -> void:
	if absf(dir_x) > 0.1:
		_facing = signf(dir_x)
		visual.scale.x = _facing


func _play_locomotion() -> void:
	if state in [State.ATTACK, State.HURT, State.DEAD]:
		return
	var anim := &"walk" if velocity.length() > 8.0 else &"idle"
	if absf(velocity.x) > 4.0:
		_face(velocity.x)
	if animation_player.current_animation != anim:
		animation_player.play(anim)


func _update_visuals(delta: float) -> void:
	if _flash > 0.0:
		_flash = move_toward(_flash, 0.0, delta * 7.0)
		if _flash_material:
			_flash_material.set_shader_parameter("flash_amount", _flash)
