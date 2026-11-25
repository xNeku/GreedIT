extends Node
## Test de humo del sandbox de combate.
## Carga la escena, prueba cada arma (pulsar, mantener, clic derecho, salto + ataque aéreo)
## contra un muñeco y comprueba que hace daño.
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
	await _wait(0.2)
	var w := _player.current_weapon
	var phases := {}

	var before := _dummy._total
	w.primary_pressed()
	await _wait(0.05)
	await _shot("%d_%s_tap" % [index + 1, w.name.to_lower()])
	w.primary_released()
	await _wait(0.7)
	phases["pulsar"] = _dummy._total - before

	_reset_player()
	before = _dummy._total
	w.primary_pressed()
	await _wait(1.3)
	await _shot("%d_%s_hold" % [index + 1, w.name.to_lower()])
	w.primary_released()
	await _wait(0.8)
	phases["mantener"] = _dummy._total - before

	_reset_player()
	before = _dummy._total
	w.secondary_pressed()
	await _wait(0.12)
	await _shot("%d_%s_alt" % [index + 1, w.name.to_lower()])
	await _wait(0.8)
	phases["clic_der"] = _dummy._total - before

	_reset_player()
	before = _dummy._total
	_player.try_jump(_player.global_position + Vector2(10, 0))
	await _wait(0.12)
	w.primary_pressed()
	w.primary_released()
	await _wait(0.08)
	await _shot("%d_%s_air" % [index + 1, w.name.to_lower()])
	await _wait(0.9)
	phases["salto+ataque"] = _dummy._total - before

	print("%-18s %s" % [weapon_name, phases])
	for phase in phases:
		if phases[phase] <= 0:
			_failures.append("%s: '%s' no hizo daño" % [weapon_name, phase])


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
