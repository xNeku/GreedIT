class_name Weapon
extends Node2D
## Base de TODAS las armas.
##
## Una arma es una escena con:
##   - Este script en la raíz (+ un WeaponData con los números).
##   - Un AnimationPlayer llamado "AnimationPlayer" con animaciones de nombres estándar:
##       idle            reposo (en bucle). También sirve de "reset" de poses.
##       light_1..N      combo de clic izquierdo (N = data.combo_length)
##       charge          bucle mientras cargas (solo HoldMode.CHARGE)
##       heavy           ataque al soltar la carga
##       alt             clic derecho
##       air             ataque en el aire (te hace caer en picado)
##       slam            impacto al aterrizar tras "air"
##     Si una animación no existe, esa acción simplemente no hace nada.
##   - Nodos Hitbox (activados desde las animaciones con la propiedad `active`).
##   - Opcional: Marker2D "Muzzle" para proyectiles, Sprite2D "HandMain"/"HandOff".
##
## Desde las animaciones puedes llamar (pista de método): lunge(), spawn_projectile(), shake().

signal attack_started(attack: StringName)
signal hit_landed(hit: HitData, target: Node)

@export var data: WeaponData

var player: Player
var combo_step := 0
## Ataque en curso ("" si ninguno).
var current_attack: StringName = &""
## 0..1, cuánto se cargó el último ataque cargado.
var charge_ratio := 0.0

var _primary_down := false
var _primary_held_time := 0.0
var _queued_primary := false
var _charging := false
var _charge_time := 0.0
var _combo_timer := 0.0
var _alt_cooldown_timer := 0.0
var _air_attacking := false
var _damage_bonus := 1.0
var _hitboxes: Array[Hitbox] = []

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	for node in find_children("*", "Hitbox", true, false):
		var hitbox := node as Hitbox
		_hitboxes.append(hitbox)
		hitbox.hurtbox_entered.connect(_on_hitbox_hurtbox_entered)
	animation_player.animation_finished.connect(_on_animation_finished)
	animation_player.play(&"idle")


func setup(owner_player: Player) -> void:
	player = owner_player
	apply_appearance(player.character_visual.appearance)


## Pone las manos del personaje (piel) en el arma.
func apply_appearance(appearance: CharacterAppearance) -> void:
	if appearance == null:
		return
	var hand_main := find_child("HandMain", true, false) as Sprite2D
	var hand_off := find_child("HandOff", true, false) as Sprite2D
	if hand_main and appearance.hand_r:
		hand_main.texture = appearance.hand_r
		hand_main.self_modulate = appearance.skin_tint
	if hand_off and appearance.hand_l:
		hand_off.texture = appearance.hand_l
		hand_off.self_modulate = appearance.skin_tint


func is_busy() -> bool:
	return current_attack != &""


## Mientras atacas, el arma mantiene la dirección (te comprometes al golpe).
func locks_aim() -> bool:
	return is_busy() and current_attack != &"charge"


# --- Input (lo llama Player) ---------------------------------------------

func primary_pressed() -> void:
	_primary_down = true
	_primary_held_time = 0.0
	if player.is_airborne:
		_try_air_attack()
	elif is_busy():
		_queued_primary = true
	else:
		_do_light()


func primary_released() -> void:
	_primary_down = false
	if _charging:
		_release_charge()


func secondary_pressed() -> void:
	if player.is_airborne:
		_try_air_attack()
		return
	if _alt_cooldown_timer > 0.0 or not animation_player.has_animation(&"alt"):
		return
	if is_busy() and not current_attack.begins_with("light") and current_attack != &"charge":
		return
	_charging = false
	_alt_cooldown_timer = data.alt_cooldown
	_play_attack(&"alt")


func secondary_released() -> void:
	pass


func on_jump_started() -> void:
	# Saltar cancela el ataque en curso: así puedes encadenar golpe -> salto -> golpe aéreo.
	cancel()


func on_landed(was_plunging: bool) -> void:
	if not _air_attacking:
		return
	_air_attacking = false
	if was_plunging and animation_player.has_animation(&"slam"):
		_play_attack(&"slam")
	elif animation_player.current_animation != &"air":
		cancel()
	# Si "air" aún suena (p. ej. el arco disparando), la dejamos terminar.


## Corta lo que esté haciendo el arma (dash, salto, cambio de arma...). Mantiene el combo.
func cancel() -> void:
	_charging = false
	_queued_primary = false
	_air_attacking = false
	current_attack = &""
	_set_hitboxes_active(false)
	animation_player.play(&"idle")


# --- Lógica ---------------------------------------------------------------

func _process(delta: float) -> void:
	_alt_cooldown_timer = maxf(0.0, _alt_cooldown_timer - delta)
	if not is_busy() and _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo_step = 0
	if _primary_down:
		_primary_held_time += delta
		if _charging:
			_charge_time += delta
			charge_ratio = clampf(_charge_time / data.max_charge_time, 0.0, 1.0)
		elif not is_busy() and not player.is_airborne and _primary_held_time >= data.hold_threshold:
			_on_hold()


func _on_hold() -> void:
	match data.hold_mode:
		WeaponData.HoldMode.CHARGE:
			_start_charge()
		WeaponData.HoldMode.REPEAT:
			_do_light(data.repeat_speed_scale)


func _do_light(speed: float = 1.0) -> void:
	combo_step = combo_step % data.combo_length + 1
	var anim := StringName("light_%d" % combo_step)
	if not animation_player.has_animation(anim):
		combo_step = 1
		anim = &"light_1"
	_play_attack(anim, speed)


func _start_charge() -> void:
	if not animation_player.has_animation(&"charge"):
		return
	_charging = true
	_charge_time = 0.0
	charge_ratio = 0.0
	_play_attack(&"charge")


func _release_charge() -> void:
	_charging = false
	_damage_bonus = lerpf(1.0, data.max_charge_multiplier, charge_ratio)
	_play_attack(&"heavy", 1.0, false)


func _try_air_attack() -> void:
	if _air_attacking or not animation_player.has_animation(&"air"):
		return
	_air_attacking = true
	_play_attack(&"air")
	if data.air_attack_plunges:
		player.start_plunge()


func _play_attack(anim: StringName, speed: float = 1.0, reset_bonus: bool = true) -> void:
	if reset_bonus:
		_damage_bonus = 1.0
	_queued_primary = false
	_set_hitboxes_active(false)
	current_attack = anim
	animation_player.stop()
	animation_player.play(anim, -1, speed)
	attack_started.emit(anim)


func _on_animation_finished(anim: StringName) -> void:
	if anim == &"charge" or anim == &"idle":
		return # van en bucle
	if anim == &"air" and _air_attacking:
		return # seguimos en el aire: la pose aguanta hasta aterrizar (-> "slam")
	current_attack = &""
	_set_hitboxes_active(false)
	_combo_timer = data.combo_window
	if _queued_primary:
		_do_light()
	elif _primary_down and anim.begins_with("light"):
		_on_hold()
	if not is_busy():
		animation_player.play(&"idle")


func _set_hitboxes_active(value: bool) -> void:
	for hitbox in _hitboxes:
		hitbox.active = value


# --- Daño -----------------------------------------------------------------

func _on_hitbox_hurtbox_entered(hurtbox: Hurtbox, hitbox: Hitbox) -> void:
	deal_hit(hurtbox, hitbox.damage_multiplier, hitbox.knockback_force, hitbox.attack_name,
			hitbox.tags, hitbox.hitstop, hitbox.shake, player.global_position)


## Calcula y aplica un golpe. Lo usan los Hitbox y los proyectiles.
func deal_hit(hurtbox: Hurtbox, multiplier: float, knockback_force: float, attack_name: StringName,
		tags: PackedStringArray, hitstop: float, shake_strength: float, from_position: Vector2) -> void:
	var hit := HitData.new()
	var crit_chance := data.crit_chance
	if current_attack == &"air" or current_attack == &"slam" or player.is_airborne:
		crit_chance += data.air_crit_bonus
	hit.is_crit = randf() < crit_chance
	var damage := data.base_damage * multiplier * _damage_bonus * randf_range(0.9, 1.1)
	if hit.is_crit:
		damage *= data.crit_multiplier
	hit.amount = maxi(1, roundi(damage))
	hit.knockback = (hurtbox.global_position - from_position).normalized() * knockback_force
	hit.source = player
	hit.attack_name = attack_name
	hit.tags = tags
	hurtbox.receive_hit(hit)
	var target := hurtbox.owner if hurtbox.owner else hurtbox.get_parent()
	hit_landed.emit(hit, target)
	Events.hit_landed.emit(hit, target)
	Events.hitstop_requested.emit(hitstop * (1.5 if hit.is_crit else 1.0))
	Events.camera_shake_requested.emit(shake_strength * (1.5 if hit.is_crit else 1.0), 0.12)


# --- Métodos para pistas de animación -------------------------------------

func lunge(speed: float) -> void:
	if player:
		player.lunge(speed)


func shake(strength: float) -> void:
	Events.camera_shake_requested.emit(strength, 0.15)


## Dispara `count` proyectiles en abanico de `spread_degrees` desde el Marker2D "Muzzle".
## En "heavy" la carga aumenta velocidad y perforación.
func spawn_projectile(multiplier: float = 1.0, count: int = 1, spread_degrees: float = 0.0) -> void:
	if data.projectile_scene == null or player == null:
		return
	var muzzle := find_child("Muzzle", true, false) as Node2D
	var origin := muzzle.global_position if muzzle else global_position
	for i in count:
		var t := 0.0 if count == 1 else float(i) / float(count - 1) - 0.5
		var projectile := data.projectile_scene.instantiate() as Projectile
		projectile.direction = player.aim_direction().rotated(deg_to_rad(spread_degrees) * t)
		projectile.speed = data.projectile_speed
		projectile.weapon = self
		projectile.damage_multiplier = multiplier * _damage_bonus
		if current_attack == &"heavy":
			projectile.speed *= lerpf(1.0, 1.8, charge_ratio)
			projectile.pierce += int(charge_ratio * 3.0)
		player.get_parent().add_child(projectile)
		projectile.global_position = origin
