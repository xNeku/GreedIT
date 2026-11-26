extends Node
## Test de humo del mundo 3D.
## - Aparece el jugador con su personaje y la cámara lo sigue.
## - Se mueve con WASD, salta y esquiva.
## - Cada arma (clic izquierdo y derecho) hace daño al muñeco: cuerpo a cuerpo, área, ballesta y bastón.
## - Equipo: escudo con armas de una mano, casco y capa de serie, armadura con esqueleto.
## - Cambio de personaje.
##
## Uso:   godot --headless --path . res://tests/smoke_test_3d.tscn
## Con capturas (necesita render, no --headless):
##        godot --path . res://tests/smoke_test_3d.tscn -- --shots=/ruta/carpeta

var _failures: Array[String] = []
var _shots_dir := ""
var _scene: Game3D
var _player: Player3D
var _dummy: TrainingDummy3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
	_run.call_deferred()


func _run() -> void:
	_scene = (load("res://src/game3d/world/game_3d.tscn") as PackedScene).instantiate() as Game3D
	add_child(_scene)
	await _wait(0.5)
	_player = _scene.players.get_node_or_null("1") as Player3D
	_dummy = _scene.dummies.get_node("Dummy1") as TrainingDummy3D
	if _player == null or _player.avatar == null:
		_fail("no aparece el jugador 3D")
		return _finish()
	print("jugador 3D: %s con %s" % [_player.avatar.name, _player.current_weapon.display_name])
	await _shot("00_overview")

	await _test_movement()
	for i in _player.weapons.size():
		await _test_weapon(i)
	await _test_equipment()
	await _test_avatars()
	_finish()


func _test_movement() -> void:
	var start := _player.global_position
	Input.action_press("move_right")
	await _wait(0.5)
	Input.action_release("move_right")
	await _wait(0.2)
	if _player.global_position.x - start.x < 1.5:
		_fail("el jugador no se mueve a la derecha (%.2f)" % (_player.global_position.x - start.x))
	if absf(_player.yaw - PI / 2.0) > 0.4:
		_fail("el personaje no mira hacia donde corre (yaw %.2f)" % _player.yaw)
	_player.jump()
	await _wait(0.15)
	if _player.global_position.y < 0.5:
		_fail("el salto no eleva al jugador (y = %.2f)" % _player.global_position.y)
	await _wait(1.2)
	if not _player.is_on_floor():
		_fail("el jugador no vuelve al suelo tras saltar")
	var before := _player.global_position
	_player.dodge()
	await _wait(0.35)
	if _player.global_position.distance_to(before) < 2.0:
		_fail("la esquiva no desplaza al jugador")
	print("movimiento, salto y esquiva OK")


func _test_weapon(index: int) -> void:
	_player.weapon_index = index
	var weapon := _player.current_weapon
	var ranged := weapon.kind != Weapon3DData.Kind.MELEE
	var distance := 6.0 if ranged else weapon.reach * 0.5 + 0.7
	for alt: bool in [false, true]:
		var d := 2.0 if alt and weapon.alt_is_area else distance
		_player.global_position = _dummy.global_position + Vector3(0, 0, d)
		_player.velocity = Vector3.ZERO
		_player.aim_target_override = _dummy.global_position
		await _wait(0.15)
		var hits := _dummy.total_hits
		_player.attack(alt)
		await _wait(_player._attack_length * 0.55)
		await _shot("w%d_%s%s" % [index + 1, weapon.id, "_alt" if alt else ""])
		await _wait(_player._attack_length * 0.5 + 0.5)
		var label := "%s (%s)" % [weapon.display_name, "clic derecho" if alt else "clic izquierdo"]
		if _dummy.total_hits <= hits:
			_fail("%s no golpea al muñeco" % label)
		else:
			print("%s: %d golpe(s)" % [label, _dummy.total_hits - hits])
	_player.aim_target_override = null
	if weapon.allows_shield and _player.avatar.equipped(EquipmentData.Slot.OFF_HAND) == null:
		_fail("%s debería llevar escudo" % weapon.display_name)
	if weapon.offhand_scene and _player.avatar.equipped(EquipmentData.Slot.OFF_HAND) == null:
		_fail("%s debería llevar arma en la otra mano" % weapon.display_name)


func _test_equipment() -> void:
	_player.weapon_index = 1 # espada y escudo
	_player.global_position = _dummy.global_position + Vector3(0, 0, 4)
	await _wait(0.2)
	var helmet := _player.avatar.skeleton.find_child("Knight_Helmet", true, false) as Node3D
	if helmet == null or not helmet.visible:
		_fail("el casco de serie no se ve")
	_player.helmet_on = false
	_player.cape_on = false
	_player.shield_on = false
	await _wait(0.1)
	if helmet.visible:
		_fail("H no quita el casco")
	if _player.avatar.equipped(EquipmentData.Slot.OFF_HAND) != null:
		_fail("V no quita el escudo")
	await _shot("80_sin_casco")
	_player.helmet_on = true
	_player.cape_on = true
	_player.shield_on = true
	_player.avatar_index = 2 # maga, con la armadura de caballero encima
	_player.chest_on = true
	await _wait(0.3)
	var armor := _player.avatar.equipped(EquipmentData.Slot.CHEST)
	var body := _player.avatar.skeleton.find_child("Mage_Body", false, false) as Node3D
	var dressed := _player.avatar.skeleton.find_child("Knight_Body", false, false) as MeshInstance3D
	if armor == null or dressed == null:
		_fail("la armadura con esqueleto no se viste")
	elif body.visible:
		_fail("la armadura no oculta el cuerpo de debajo")
	elif dressed.get_node_or_null(dressed.skeleton) != _player.avatar.skeleton:
		_fail("la armadura no usa el esqueleto del personaje")
	else:
		print("armadura con esqueleto OK (Knight_Body sobre la maga)")
	_player.weapon_index = 0
	_player.attack(false)
	await _wait(0.25)
	await _shot("81_maga_con_armadura")
	await _wait(0.6)
	_player.chest_on = false
	await _wait(0.1)
	if not body.visible:
		_fail("al quitar la armadura no vuelve el cuerpo")


func _test_avatars() -> void:
	var names: PackedStringArray = []
	for i in _player.avatars.size():
		_player.avatar_index = i
		await _wait(0.15)
		names.append(_player.avatar.name)
		await _shot("9%d_%s" % [i, _player.avatar.name])
	if names.size() != 4 or Array(names).has(""):
		_fail("no cambian los personajes: %s" % names)
	print("personajes: %s" % ", ".join(names))


func _fail(message: String) -> void:
	_failures.append(message)
	printerr("FALLO: ", message)


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE 3D OK")
	else:
		print("SMOKE 3D FAILED (%d)" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shots_dir.path_join(shot_name + ".png"))
