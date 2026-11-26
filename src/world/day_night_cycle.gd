class_name DayNightCycle
extends Node
## Ciclo de día y noche con sol dinámico: el sol sale por el este, cruza el cielo y se pone (las sombras giran y se
## alargan), y de noche la luna hace lo mismo con luz fría. Los colores y fuerzas de cada hora salen de curvas y
## degradados (inspector: `sun_colors`, `sun_energy`, `ambient_colors`, `ambient_energy`, `sky_colors`), con
## amanecer y atardecer cálidos. El menú de Esc cambia los multiplicadores y la hora para probar.
##
## RED: la hora la lleva el host; el nodo `Sync` la reparte cada pocos segundos y cada peer la avanza
## en local entre medias, así el cielo se mueve suave en todos.

## Duración de un día entero (24 h del juego) en segundos reales.
@export var day_length := 480.0
## Hora a la que empieza la partida (0-24).
@export_range(0.0, 24.0) var start_hour := 9.0
## Parar el tiempo (para mirar una hora concreta).
@export var paused := false
@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment

@export_group("Colores y fuerzas por hora (0 = medianoche, 0.5 = mediodía)")
@export var sun_colors: Gradient
@export var sun_energy: Curve
@export var ambient_colors: Gradient
@export var ambient_energy: Curve
@export var sky_colors: Gradient

@export_group("Ajustes (el menú de Esc los cambia)")
## Multiplica la luz del sol (de día) y de la luna (de noche).
@export var sun_strength := 1.0
@export var moon_strength := 1.0
## Multiplica la luz ambiente de día y de noche.
@export var day_ambient_strength := 1.0
@export var night_ambient_strength := 1.0
## Fuerza de las antorchas (grupo "night_lights") con noche cerrada.
@export var torch_energy := 1.2
## Bandas de luz del sol/la luna de noche (0 = suave). De día siempre suave.
@export var night_light_bands := 4.0
## Calibración: la luz de Godot sale el doble de fuerte que la del Look Lab (visor web) con los mismos números.
@export var light_scale := 0.5

@export_group("Recorrido")
## Dirección (grados) por la que sale el sol; se pone por la contraria.
@export var sunrise_direction := 100.0
## Altura máxima del sol a mediodía (grados).
@export var sun_max_height := 45.0
## La luna va siempre algo alta (si no, de noche apenas alumbra).
@export var moon_min_height := 30.0
@export var moon_max_height := 52.0

## Veces por segundo que se recalcula la luz (el sol se mueve muy despacio: no hace falta en cada frame).
@export var updates_per_second := 20.0

## Hora actual (0-24). La sincroniza el nodo Sync.
var hour := 9.0

var _timer := 0.0
var _last_bands := -1.0
var _last_torch := -1.0


func _ready() -> void:
	hour = start_hour
	_apply()


func _process(delta: float) -> void:
	if not paused:
		hour = fmod(hour + delta * 24.0 / maxf(day_length, 1.0), 24.0)
	_timer -= delta
	if _timer <= 0.0:
		_timer = 1.0 / maxf(updates_per_second, 1.0)
		_apply()


## 1 = el sol está arriba, 0 = es de noche (con amanecer y atardecer suaves).
func daylight() -> float:
	return smoothstep(-0.08, 0.15, sin((hour - 6.0) / 12.0 * PI))


func _apply() -> void:
	var t := hour / 24.0
	var day := daylight()
	var is_day := day >= 0.5
	var arc := fposmod(hour - 6.0, 12.0) / 12.0
	var lift := sin(arc * PI)
	var height := lift * sun_max_height if is_day else lerpf(moon_min_height, moon_max_height, lift)
	if sun:
		# nunca rasante del todo: con el sol muy bajo las sombras hacen rayas
		sun.rotation_degrees = Vector3(-maxf(height, 12.0), sunrise_direction + arc * 180.0, 0.0)
		var strength := sun_strength if is_day else moon_strength
		sun.light_energy = (sun_energy.sample(t) if sun_energy else 0.55) * strength * light_scale
		sun.light_color = sun_colors.sample(t) if sun_colors else Color.WHITE
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		var ambient_mult := lerpf(night_ambient_strength, day_ambient_strength, day)
		env.ambient_light_energy = (ambient_energy.sample(t) if ambient_energy else 0.45) * ambient_mult * light_scale
		env.ambient_light_color = ambient_colors.sample(t) if ambient_colors else Color.WHITE
		env.background_color = sky_colors.sample(t) if sky_colors else Color.SKY_BLUE
	var bands := 0.0 if is_day else night_light_bands
	if bands != _last_bands:
		_last_bands = bands
		RenderingServer.global_shader_parameter_set(&"light_bands", bands)
	var torch := snappedf(torch_energy * (1.0 - day), 0.01)
	if torch != _last_torch:
		_last_torch = torch
		for light in get_tree().get_nodes_in_group(&"night_lights"):
			(light as Light3D).light_energy = torch
			(light as Light3D).visible = torch > 0.0 # apagadas no cuestan nada


## Para el menú: pone una hora (solo cuenta en el host; en los clientes la corrige la sincronización).
func set_hour(value: float) -> void:
	hour = fposmod(value, 24.0)
	_apply()
