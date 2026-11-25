extends Node
## Test de humo del sandbox.
## - Cada arma contra un muñeco: pulsar, mantener, clic derecho, mantener clic derecho (si tiene)
##   y salto + ataque aéreo. Todo debe hacer daño.
## - El salto va hacia donde te mueves.
## - Minería, herboristería y pesca dan materiales.
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
	_player = _scene.get_node("World/Player")
	_dummy = _scene.get_node("World/TrainingDummy1")
	await _shot("00_overview")

	for i in _player.hotbar.size():
		await _test_weapon(i)

	await _test_jump_direction()
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


## Coloca al jugador a la izquierda del muñeco, apuntándole.
func _reset_player() -> void:
	_player.global_position = _dummy.global_position + Vector2(-38, 0)
	_player.velocity = Vector2.ZERO
	_player.aim_target_override = _dummy.hurtbox.global_position


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shots_dir.path_join(shot_name + ".png"))
