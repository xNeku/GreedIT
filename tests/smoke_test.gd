extends Node
## Test de humo del sandbox.
## - Cada arma contra un muñeco: pulsar, mantener, clic derecho, mantener clic derecho (si tiene)
##   y salto + ataque aéreo. Todo debe hacer daño.
## - El salto va hacia donde te mueves.
## - Minería, herboristería y pesca dan materiales.
## - La bola de fuego (clic de la rueda) gasta maná y hace daño en área.
## - La vista del personaje cambia según hacia dónde se mueve (8 direcciones, 5 vistas).
## - El arma se guarda a la espalda si no la usas y se desenfunda al atacar.
## - Mobs: te atacan (cuerpo a cuerpo y a distancia), mueren, sueltan botín y reaparecen.
## - El jugador muere y reaparece.
##
## Uso:   godot --headless --path . res://tests/smoke_test.tscn
## Con capturas (necesita render, no --headless):
##        godot --path . res://tests/smoke_test.tscn -- --shots=/ruta/carpeta

var _failures: Array[String] = []
var _shots_dir := ""
var _scene: Node
var _player: Player
var _dummy: TrainingDummy


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	_run.call_deferred()


func _run() -> void:
	_scene = (load("res://src/world/sandbox.tscn") as PackedScene).instantiate()
	add_child(_scene)
	await _wait(0.3)
	_player = _scene.get_node("World/Players/1")
	_dummy = _scene.get_node("World/TrainingDummy1")
	await _shot("00_overview")

	for i in _player.hotbar.size():
		await _test_weapon(i)

	await _test_fireball()
	await _test_views()
	await _test_sheathe()
	await _test_jump_direction()
	await _test_mob_attacks("GoblinSpawner", 36.0, "goblin")
	await _test_mob_attacks("SkeletonSpawner", 120.0, "esqueleto")
	await _test_kill_with_sword("GoblinSpawner")
	await _test_kill_with_fireballs("ZombieSpawner")
	await _test_player_death()
	await _test_gathering("World/OreRock1", Vector2(-32, 0), &"copper_ore", "minería")
	await _test_gathering("World/HerbBush1", Vector2(-30, 2), &"sage", "herboristería")
	await _test_fishing()

	# Cambio de personaje (C)
	_player.cycle_appearance()
	await _wait(0.2)
	await _shot("90_female")

	if _failures.is_empty():
		print("SMOKE OK")
	else:
		for f in _failures:
			printerr("FALLO: ", f)
		print("SMOKE FAILED (%d)" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_weapon(index: int) -> void:
	_player.select_slot(index)
	var weapon_name: String = _player.hotbar[index].display_name
	_reset_player()
	await _wait(0.25)
	var w := _player.current_weapon
	var tag := "%d_%s" % [index + 1, w.name.to_lower()]
	await _shot(tag + "_idle")
	var phases := {}

	var before := _dummy._total
	w.primary_pressed()
	await _wait(0.07)
	await _shot(tag + "_tap")
	w.primary_released()
	await _wait(0.7)
	phases["pulsar"] = _dummy._total - before

	_reset_player()
	before = _dummy._total
	w.primary_pressed()
	await _wait(1.3)
	await _shot(tag + "_hold")
	w.primary_released()
	await _wait(0.9)
	phases["mantener"] = _dummy._total - before

	_reset_player()
	before = _dummy._total
	w.secondary_pressed()
	await _wait(0.03)
	w.secondary_released()
	await _wait(0.12)
	await _shot(tag + "_alt")
	await _wait(1.0)
	phases["clic_der"] = _dummy._total - before

	if w.data.alt_hold_enabled:
		_reset_player()
		before = _dummy._total
		w.secondary_pressed()
		await _wait(1.0)
		await _shot(tag + "_alt_hold")
		w.secondary_released()
		await _wait(0.3)
		await _shot(tag + "_alt_leap")
		await _wait(1.2)
		phases["mantener_der"] = _dummy._total - before

	_reset_player()
	before = _dummy._total
	_player.jump(Vector2.ZERO)
	await _wait(0.16)
	w.primary_pressed()
	w.primary_released()
	await _wait(0.06)
	await _shot(tag + "_air")
	await _wait(0.9)
	phases["salto+ataque"] = _dummy._total - before

	print("%-18s %s" % [weapon_name, phases])
	for phase in phases:
		if phases[phase] <= 0:
			_failures.append("%s: '%s' no hizo daño" % [weapon_name, phase])


func _test_fireball() -> void:
	_player.select_slot(1)
	_reset_player()
	_player.global_position = _dummy.global_position + Vector2(-110, 0)
	_player.mana = _player.max_mana
	await _wait(0.3)
	var before := _dummy._total
	var mana_before := _player.mana
	_player.try_cast()
	await _wait(0.08)
	await _shot("69_fireball_cast")
	await _wait(0.16)
	await _shot("70_fireball_flight")
	await _wait(0.2)
	await _shot("71_fireball_hit")
	await _wait(0.6)
	var damage := _dummy._total - before
	print("Bola de fuego: daño %d, maná %d -> %d" % [damage, mana_before, _player.mana])
	if damage <= 0:
		_failures.append("bola de fuego: no hizo daño")
	if _player.mana >= mana_before:
		_failures.append("bola de fuego: no gastó maná")
	# Sin maná no se lanza
	_player.mana = 0.0
	var failed := [false]
	_player.cast_failed.connect(func(_r: String) -> void: failed[0] = true, CONNECT_ONE_SHOT)
	_player.try_cast()
	if not failed[0]:
		_failures.append("bola de fuego: se lanzó sin maná")
	_player.mana = _player.max_mana


func _test_views() -> void:
	_player.aim_target_override = null
	_player.global_position = Vector2(0, 230)
	var V := CharacterVisual.View
	var cases := {Vector2.UP: V.BACK, Vector2(1, -1): V.BACK_SIDE, Vector2.RIGHT: V.SIDE, Vector2(1, 1): V.FRONT_SIDE, Vector2.DOWN: V.FRONT}
	var names := {V.BACK: "back", V.BACK_SIDE: "back_side", V.SIDE: "side", V.FRONT_SIDE: "front_side", V.FRONT: "front"}
	for dir: Vector2 in cases:
		_player.velocity = dir.normalized() * _player.move_speed
		_player._update_facing_and_aim()
		await _wait(0.12)
		if _player.character_visual.view != cases[dir]:
			_failures.append("vista: moviéndose %s debería ser %s" % [dir, names[cases[dir]]])
		await _shot("75_view_%s" % names[cases[dir]])
	_player.velocity = Vector2.ZERO
	_player._update_facing_and_aim()


func _test_sheathe() -> void:
	_player.select_slot(1) # espada
	_player.global_position = Vector2(0, 230)
	_player.aim_target_override = Vector2(60, 200)
	await _wait(0.1)
	if _player.weapon_drawn or not _player.character_visual.back_weapon.visible:
		_failures.append("al cambiar de arma debería ir a la espalda")
	await _shot("77_sheathed")
	_player.draw_weapon()
	_player._aim_at_target()
	_player.current_weapon.primary_pressed()
	_player.current_weapon.primary_released()
	await _wait(0.08)
	if not _player.current_weapon.visible or _player.character_visual.back_weapon.visible:
		_failures.append("al atacar debería desenfundar")
	await _shot("78_drawn_attack")
	await _wait(_player.sheathe_delay + 0.6)
	if _player.weapon_drawn or _player.current_weapon.visible:
		_failures.append("no guarda el arma a la espalda al dejar de atacar")
	else:
		print("Arma: se desenfunda al atacar y vuelve a la espalda sola")
	# de espaldas el arma de la espalda se ve encima
	_player.velocity = Vector2.UP * _player.move_speed
	_player._update_facing_and_aim()
	await _wait(0.1)
	await _shot("79_sheathed_back")
	# todas las armas guardadas, de frente y de espaldas
	for i in _player.hotbar.size():
		_player.select_slot(i)
		for dir: Vector2 in [Vector2.DOWN, Vector2.UP]:
			_player.global_position = Vector2(0, 230)
			_player.velocity = dir * _player.move_speed
			_player._update_facing_and_aim()
			_player.velocity = Vector2.ZERO
			await _wait(0.05)
			await _shot("79_back_%d_%s" % [i + 1, "front" if dir == Vector2.DOWN else "back"])
	_player.select_slot(1)
	_player.velocity = Vector2.ZERO
	_player.aim_target_override = null


func _test_jump_direction() -> void:
	_player.select_slot(0)
	_player.aim_target_override = null
	_player.global_position = Vector2(0, 200)
	_player.velocity = Vector2.ZERO
	await _wait(0.2)
	var start := _player.global_position
	_player.jump(Vector2.RIGHT)
	await _wait(0.22)
	await _shot("80_jump_peak")
	await _wait(0.5)
	var moved := _player.global_position - start
	print("Salto hacia la derecha: se movió ", moved.round())
	if moved.x < 60.0 or absf(moved.y) > 10.0:
		_failures.append("el salto no fue hacia donde te mueves (%s)" % moved)


func _test_gathering(path: String, offset: Vector2, item_id: StringName, label: String) -> void:
	var target := _scene.get_node(path) as Gatherable
	_player.global_position = target.global_position + offset
	_player.velocity = Vector2.ZERO
	await _wait(0.25)
	if _player._focused != target:
		_failures.append("%s: no aparece el cartel de interacción" % label)
		return
	await _shot("85_%s_prompt" % item_id)
	_player.interact()
	await _wait(1.0)
	await _shot("86_%s_gathering" % item_id)
	await _wait(1.6)
	_player.interact() # dejar de recolectar
	var count := _player.inventory.count_by_id(item_id)
	print("%-14s -> %s x%d" % [label, item_id, count])
	if count <= 0:
		_failures.append("%s: no dio materiales" % label)


func _test_fishing() -> void:
	var pond := _scene.get_node("World/Pond") as Gatherable
	_player.global_position = pond.global_position + Vector2(-84, 0)
	_player.velocity = Vector2.ZERO
	await _wait(0.25)
	if _player._focused != pond:
		_failures.append("pesca: no aparece el cartel de interacción")
		return
	_player.interact()
	var rod := _player._tool as FishingRod
	var waited := 0.0
	while rod.state != FishingRod.State.BITE and waited < 6.0:
		await _wait(0.05)
		waited += 0.05
	await _shot("87_fishing_bite")
	_player.interact() # ¡tira!
	await _wait(0.8)
	var count := _player.inventory.count_by_id(&"trout")
	print("%-14s -> trout x%d" % ["pesca", count])
	if count <= 0:
		_failures.append("pesca: no dio peces")
	await _shot("88_inventory")
	_player.global_position += Vector2(-10, 0)
	_player._stop_gathering()


func _first_mob(spawner_name: String) -> Enemy:
	var spawner := _scene.get_node("World/" + spawner_name) as MobSpawner
	for enemy in spawner.alive():
		if is_instance_valid(enemy) and enemy.state != Enemy.State.DEAD:
			return enemy
	return null


func _test_mob_attacks(spawner_name: String, distance: float, label: String) -> void:
	var mob := _first_mob(spawner_name)
	if mob == null:
		_failures.append("%s: no hay mobs" % label)
		return
	_player.health = _player.max_health
	_player.aim_target_override = null
	_player.global_position = mob.global_position + Vector2(-distance, 0)
	_player.velocity = Vector2.ZERO
	var waited := 0.0
	var shot_done := false
	while _player.health >= _player.max_health and waited < 5.0:
		await _wait(0.05)
		waited += 0.05
		if not shot_done and mob.state == Enemy.State.ATTACK:
			await _wait(0.2)
			await _shot("60_%s_attack" % label)
			shot_done = true
	print("%-10s -> te quitó %d de vida en %.1fs" % [label, _player.max_health - _player.health, waited])
	if _player.health >= _player.max_health:
		_failures.append("%s: no ataca al jugador" % label)
	_player.health = _player.max_health
	_player.global_position = Vector2(0, 230)
	await _wait(1.0)


func _test_kill_with_sword(spawner_name: String) -> void:
	_player.select_slot(1)
	var mob := _first_mob(spawner_name)
	var spawner := _scene.get_node("World/" + spawner_name) as MobSpawner
	var count_before := spawner.alive().size()
	var ears_before := _player.inventory.count_by_id(&"goblin_ear")
	var waited := 0.0
	var hit_shot := false
	while is_instance_valid(mob) and mob.state != Enemy.State.DEAD and waited < 8.0:
		_player.health = _player.max_health
		_player.global_position = mob.global_position + Vector2(-30, 0)
		_player.aim_target_override = mob.hurtbox.global_position
		_player.draw_weapon()
		_player._aim_at_target() # lo que hace el input real antes de atacar
		_player.current_weapon.primary_pressed()
		await _wait(0.05)
		_player.current_weapon.primary_released()
		await _wait(0.3)
		waited += 0.35
		if not hit_shot and mob.health < mob.max_health:
			await _shot("61_goblin_hit")
			hit_shot = true
	if is_instance_valid(mob) and mob.state != Enemy.State.DEAD:
		_failures.append("espada: no consigue matar al goblin")
		return
	await _wait(0.2)
	await _shot("62_goblin_dead")
	print("Goblin muerto en %.1fs (orejas: %d -> %d)" % [waited, ears_before, _player.inventory.count_by_id(&"goblin_ear")])
	_player.global_position = Vector2(0, 230)
	_player.aim_target_override = null
	await _wait(5.6)
	if spawner.alive().size() < count_before:
		_failures.append("los goblins no reaparecen")


func _test_kill_with_fireballs(spawner_name: String) -> void:
	var mob := _first_mob(spawner_name)
	var waited := 0.0
	while is_instance_valid(mob) and mob.state != Enemy.State.DEAD and waited < 10.0:
		_player.health = _player.max_health
		_player.mana = _player.max_mana
		_player.global_position = mob.global_position + Vector2(-90, 0)
		_player.aim_target_override = mob.hurtbox.global_position
		_player.try_cast()
		await _wait(0.5)
		waited += 0.5
	if is_instance_valid(mob) and mob.state != Enemy.State.DEAD:
		_failures.append("bola de fuego: no consigue matar al zombi")
	else:
		print("Zombi muerto a bolas de fuego en %.1fs" % waited)
	_player.global_position = Vector2(0, 230)
	_player.aim_target_override = null
	await _wait(0.5)


func _test_player_death() -> void:
	var hit := HitData.new()
	hit.amount = 9999
	_player._invulnerable_timer = 0.0
	_player.hurtbox.receive_hit(hit)
	await _wait(0.3)
	await _shot("95_dead")
	if not _player.is_dead:
		_failures.append("el jugador no muere con 0 de vida")
		return
	await _wait(_player.respawn_delay + 0.3)
	if _player.is_dead or _player.health < _player.max_health:
		_failures.append("el jugador no reaparece")
	else:
		print("Muerte y reaparición OK")


## Coloca al jugador a la izquierda del muñeco, apuntándole.
func _reset_player() -> void:
	_player.global_position = _dummy.global_position + Vector2(-38, 0)
	_player.velocity = Vector2.ZERO
	_player.aim_target_override = _dummy.hurtbox.global_position
	_player.draw_weapon()
	_player._aim_at_target()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shots_dir.path_join(shot_name + ".png"))
