extends Node
## Test de humo del juego.
## - Aparece el jugador (personaje base con cuerpo, ojos, pelo y barba) y la cámara isométrica lo sigue.
## - Se mueve con WASD relativo a la cámara, salta hacia donde corre (esquivando golpes en lo alto) y esquiva.
## - Cada arma de la barra (y los puños del hueco vacío) hace daño al muñeco con todos sus ataques:
##   clic, mantener (carga o ráfaga), clic derecho, mantener clic derecho (salto aplastante) y en el aire.
## - Bola de fuego con maná.
## - El HUD tiene la barra de vida y los 8 huecos, con el elegido resaltado.
##
## Uso:   godot --headless --path . res://tests/smoke_test.tscn
## Con capturas (necesita render, no --headless):
##        godot --path . res://tests/smoke_test.tscn -- --shots=/ruta/carpeta

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
	_scene = (load("res://src/world/game_3d.tscn") as PackedScene).instantiate() as Game3D
	add_child(_scene)
	await _wait(0.5)
	_player = _scene.players.get_node_or_null("1") as Player3D
	_dummy = _scene.dummies.get_node("Dummy1") as TrainingDummy3D
	if _player == null or _player.avatar == null:
		_fail("no aparece el jugador 3D")
		return _finish()
	print("jugador: %s con %s" % [_player.avatar.name, _player.current_weapon.display_name])
	for slot: EquipmentData.Slot in [EquipmentData.Slot.BODY, EquipmentData.Slot.FACE, EquipmentData.Slot.HAIR]:
		if _player.avatar.equipped(slot) == null:
			_fail("el personaje no lleva su %s" % EquipmentData.Slot.keys()[slot])
	await _shot("00_overview")

	await _test_movement()
	for i in _player.hotbar.size():
		await _test_weapon(i)
	await _test_hud()
	await _test_fireball()
	await _test_menu()
	_finish()


func _test_movement() -> void:
	# Con la cámara isométrica (girada 45°), "derecha" en el teclado = derecha en pantalla.
	var cam := _player.get_viewport().get_camera_3d() as FollowCamera3D
	var start := _player.global_position
	_player.move_input_override = Vector2(1, 0)
	await _wait(0.5)
	_player.move_input_override = null
	await _wait(0.2)
	var moved := _player.global_position - start
	var screen_right := Vector3(cam.global_basis.x.x, 0, cam.global_basis.x.z).normalized()
	if moved.length() < 1.5 or moved.normalized().dot(screen_right) < 0.9:
		_fail("el movimiento no va hacia la derecha de la pantalla (%s)" % moved)
	# Salto estilo Conquer: hacia donde corres, con aterrizaje.
	start = _player.global_position
	_player.move_input_override = Vector2(0, -1)
	await _wait(0.1)
	_player.jump()
	await _wait(0.25)
	if _player.global_position.y < 0.8:
		_fail("el salto no eleva al jugador (y = %.2f)" % _player.global_position.y)
	if not _player.is_invulnerable():
		_fail("en lo alto del salto deberías esquivar los golpes")
	_player.move_input_override = null
	await _wait(1.0)
	if not _player.is_on_floor():
		_fail("el jugador no vuelve al suelo tras saltar")
	if (_player.global_position - start).length() < 3.0:
		_fail("el salto no avanza hacia donde corres")
	var before := _player.global_position
	_player.dodge()
	await _wait(0.35)
	if _player.global_position.distance_to(before) < 2.0:
		_fail("la esquiva no desplaza al jugador")
	print("movimiento (relativo a la cámara), salto y esquiva OK")


## Coloca al jugador a `distance` del muñeco, apuntándole.
func _place(distance: float) -> void:
	_player._cancel_attack()
	_player._cancel_charge()
	_player.global_position = _dummy.global_position + Vector3(0, 0, distance)
	_player.velocity = Vector3.ZERO
	_player.aim_target_override = _dummy.global_position
	await _wait(0.2)


func _check(label: String, hits_before: int, at_least: int = 1) -> void:
	var got := _dummy.total_hits - hits_before
	if got < at_least:
		_fail("%s: %d golpe(s), esperaba %d" % [label, got, at_least])
	else:
		print("  %s: %d golpe(s)" % [label, got])


func _test_weapon(index: int) -> void:
	_player.slot_index = index
	var w := _player.current_weapon
	if _player.hotbar[index] == null:
		if w != _player.unarmed:
			_fail("el hueco vacío %d debería ser los puños" % (index + 1))
		if index > 6:
			return # los puños ya se probaron en el primer hueco vacío
	var ranged := w.kind != Weapon3DData.Kind.MELEE
	var near := 6.0 if ranged else w.reach * 0.5 + 0.7
	print("%d %s" % [index + 1, w.display_name])
	# Pulsar = combo
	await _place(near)
	var hits := _dummy.total_hits
	_player.primary_down()
	await _wait(0.05)
	_player.primary_up()
	await _wait(0.4)
	await _shot("w%d_%s_combo" % [index + 1, w.id])
	await _wait(0.6)
	await _check("clic", hits)
	# Mantener = carga o ráfaga
	if w.hold_mode == Weapon3DData.HoldMode.CHARGE and w.heavy:
		await _place(2.0 if w.heavy.area else near)
		hits = _dummy.total_hits
		_player.primary_down()
		await _wait(w.max_charge_time + 0.3)
		if not _player.charging:
			_fail("%s: al mantener no carga" % w.display_name)
		await _shot("w%d_%s_charge" % [index + 1, w.id])
		_player.primary_up()
		await _wait(0.45)
		await _shot("w%d_%s_heavy" % [index + 1, w.id])
		await _wait(1.0)
		await _check("cargado", hits)
	elif w.hold_mode == Weapon3DData.HoldMode.REPEAT:
		await _place(near)
		hits = _dummy.total_hits
		_player.primary_down()
		await _wait(1.6)
		_player.primary_up()
		await _wait(0.6)
		await _check("ráfaga", hits, 2)
	# Clic derecho
	if w.alt:
		var alt_near := 2.0 if w.alt.area else (4.0 if w.alt.leap == Attack3D.Leap.BACKWARD else near)
		await _place(alt_near)
		hits = _dummy.total_hits
		_player.secondary_down()
		await _wait(0.05)
		_player.secondary_up()
		await _wait(0.45)
		await _shot("w%d_%s_alt" % [index + 1, w.id])
		await _wait(1.2)
		await _check("clic derecho", hits)
	# Mantener clic derecho (salto aplastante)
	if w.alt_hold:
		await _place(6.0)
		hits = _dummy.total_hits
		_player.secondary_down()
		await _wait(0.5)
		_player.secondary_up()
		await _wait(0.3)
		await _shot("w%d_%s_leap" % [index + 1, w.id])
		await _wait(1.3)
		await _check("salto aplastante", hits)
		if _player.global_position.distance_to(_dummy.global_position) > 2.5:
			_fail("el salto aplastante no te lleva hacia el ratón")
	# En el aire
	if w.air:
		await _place(1.6 if not ranged else 6.0)
		hits = _dummy.total_hits
		_player.jump()
		await _wait(0.3)
		_player.primary_down()
		await _wait(0.05)
		_player.primary_up()
		await _wait(0.25)
		await _shot("w%d_%s_air" % [index + 1, w.id])
		await _wait(1.2)
		await _check("en el aire", hits)
	_player.aim_target_override = null
	if w.allows_shield and _player.avatar.equipped(EquipmentData.Slot.OFF_HAND) == null:
		_fail("%s debería llevar escudo" % w.display_name)
	if w.offhand_scene and _player.avatar.equipped(EquipmentData.Slot.OFF_HAND) == null:
		_fail("%s debería llevar arma en la otra mano" % w.display_name)


func _test_fireball() -> void:
	_player.slot_index = 0
	await _place(7.0)
	_player.mana = _player.max_mana
	var hits := _dummy.total_hits
	_player.cast_spell()
	if _player.mana > _player.max_mana - _player.spell.mana_cost + 1.0:
		_fail("la bola de fuego no gasta maná")
	await _wait(0.5)
	await _shot("85_fireball")
	await _wait(0.8)
	await _check("bola de fuego", hits)
	_player.mana = 1.0
	var before := _player.mana
	_player.cast_spell()
	if _player.is_attacking():
		_fail("sin maná no debería lanzar")
	_player.mana = maxf(before, _player.mana)
	_player.aim_target_override = null


func _test_hud() -> void:
	var hud := _scene.hud
	if hud.slots.size() != 8:
		_fail("el HUD debería tener 8 huecos (tiene %d)" % hud.slots.size())
		return
	_player.slot_index = 2
	await _wait(0.1)
	if hud.slots[2].get_theme_stylebox(&"panel") != hud.slots[2].selected_style:
		_fail("el hueco elegido no se resalta")
	if hud.slots[0].icon.texture == null:
		_fail("el hueco 1 no tiene icono")
	print("HUD: vida + 8 huecos OK")
	await _shot("90_hud")


func _test_menu() -> void:
	var menu := _scene.get_node("OptionsMenu") as OptionsMenu
	var esc := InputEventAction.new()
	esc.action = &"leave_game"
	esc.pressed = true
	menu._unhandled_input(esc)
	if not menu.panel.visible:
		_fail("Esc no abre el menú de opciones")
	(menu.get_node("%Night") as Button).pressed.emit()
	if absf(menu.cycle.hour) > 0.01 or not menu.cycle.paused:
		_fail("el botón Noche no pone la noche")
	await _wait(0.2)
	await _shot("95_night")
	(menu.get_node("%Noon") as Button).pressed.emit()
	(menu.get_node("%Exposure") as HSlider).value = 1.2
	if not is_equal_approx(float(menu.post_material.get_shader_parameter(&"exposure")), 1.2):
		_fail("el brillo del menú no cambia el filtro")
	(menu.get_node("%Exposure") as HSlider).value = 0.9
	menu._unhandled_input(esc)
	if menu.panel.visible:
		_fail("Esc no cierra el menú")
	menu.cycle.paused = false
	print("menú de Esc OK")


func _fail(message: String) -> void:
	_failures.append(message)
	printerr("FALLO: ", message)


func _finish() -> void:
	if _failures.is_empty():
		print("SMOKE OK")
	else:
		print("SMOKE FAILED (%d)" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(shot_name: String) -> void:
	if _shots_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_shots_dir.path_join(shot_name + ".png"))
