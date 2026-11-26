class_name OptionsMenu
extends CanvasLayer
## Menú de Esc: hora del día y ajustes de luz e imagen para probar el look en directo, y salir al menú.
## Cada fila de la escena es un HSlider con nombre único (%Nombre); aquí solo se conectan a lo que cambian.
## En coop la partida no se pausa. La hora solo la cambia el host (en los clientes se corrige sola).

@export var cycle: DayNightCycle
@export var post_material: ShaderMaterial
@export var pixel_view: PixelView

@onready var panel: Control = $Panel


func _ready() -> void:
	panel.visible = false
	# hora
	_bind(%Hour, func() -> float: return cycle.hour, func(v: float) -> void: cycle.set_hour(v), "%05.2f h")
	%Dawn.pressed.connect(func() -> void: _set_hour(6.5))
	%Noon.pressed.connect(func() -> void: _set_hour(12.0))
	%Dusk.pressed.connect(func() -> void: _set_hour(18.3))
	%Night.pressed.connect(func() -> void: _set_hour(0.0))
	%Paused.button_pressed = cycle.paused
	%Paused.toggled.connect(func(on: bool) -> void: cycle.paused = on)
	_bind(%DayMinutes, func() -> float: return cycle.day_length / 60.0, func(v: float) -> void: cycle.day_length = v * 60.0, "%.0f min")
	# luz
	_bind(%SunStrength, func() -> float: return cycle.sun_strength, func(v: float) -> void: cycle.sun_strength = v)
	_bind(%MoonStrength, func() -> float: return cycle.moon_strength, func(v: float) -> void: cycle.moon_strength = v)
	_bind(%DayAmbient, func() -> float: return cycle.day_ambient_strength, func(v: float) -> void: cycle.day_ambient_strength = v)
	_bind(%NightAmbient, func() -> float: return cycle.night_ambient_strength, func(v: float) -> void: cycle.night_ambient_strength = v)
	_bind(%Torches, func() -> float: return cycle.torch_energy, func(v: float) -> void: cycle.torch_energy = v)
	_bind(%NightBands, func() -> float: return cycle.night_light_bands, func(v: float) -> void: cycle.night_light_bands = v, "%.0f")
	# imagen
	for param: String in ["exposure", "contrast", "saturation", "temperature", "vignette", "shadow_tint_amount"]:
		var slider := get_node("%" + param.to_pascal_case()) as HSlider
		_bind(slider, func() -> float: return post_material.get_shader_parameter(param),
			func(v: float) -> void: post_material.set_shader_parameter(param, v))
	_bind(%PixelSize, func() -> float: return pixel_view.pixel_scale, func(v: float) -> void: pixel_view.pixel_scale = v, "%.1f")
	%Copy.pressed.connect(_copy_settings)
	%Resume.pressed.connect(func() -> void: panel.visible = false)
	%Leave.pressed.connect(func() -> void: Net.leave())
	var host := multiplayer.is_server()
	for node: Control in [%Hour, %Dawn, %Noon, %Dusk, %Night, %Paused, %DayMinutes]:
		node.set("disabled", not host)
		node.set("editable", host)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("leave_game"):
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if panel.visible:
		var hour_slider := %Hour as HSlider
		hour_slider.set_value_no_signal(cycle.hour)
		_show(hour_slider, "%05.2f h")


func _set_hour(value: float) -> void:
	cycle.set_hour(value)
	cycle.paused = true
	%Paused.button_pressed = true


## Conecta un slider: lo pone en el valor actual y al moverlo llama a `setter`. Muestra el valor en su etiqueta.
func _bind(slider: HSlider, getter: Callable, setter: Callable, format: String = "%.2f") -> void:
	slider.set_value_no_signal(getter.call())
	slider.set_meta(&"format", format)
	_show(slider, format)
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		_show(slider, format))


func _show(slider: HSlider, format: String) -> void:
	var label := slider.get_parent().get_node_or_null("Value") as Label
	if label:
		label.text = format % slider.value


## Copia los ajustes como texto para pegárselos a Claude.
func _copy_settings() -> void:
	var lines: PackedStringArray = ["Ajustes de luz GreedIT (hora %.1f)" % cycle.hour]
	for slider in find_children("*", "HSlider", true, false):
		var row := slider.get_parent()
		var label := row.get_node_or_null("Name") as Label
		lines.append("%s: %s" % [label.text if label else String(slider.name), (slider as HSlider).get_meta(&"format", "%.2f") % (slider as HSlider).value])
	lines.append("Bandas de noche, pausa: %s" % ("sí" if cycle.paused else "no"))
	DisplayServer.clipboard_set("\n".join(lines))
	(%Copy as Button).text = "Copiado: pégamelo en el chat"
