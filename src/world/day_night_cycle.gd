class_name DayNightCycle
extends Node
## Ciclo de día y noche: el sol sale por el este, cruza el cielo y se pone (las sombras giran y se alargan);
## de noche la luna hace lo mismo con luz fría. Los valores de día y de noche son las recetas del Look Lab.
## De día la luz es suave y de noche por bandas (ajuste global `light_bands` del shader del mundo).
##
## RED: la hora la lleva el host; el nodo `Sync` la reparte cada pocos segundos y cada peer la avanza
## en local entre medias, así el cielo se mueve suave en todos.

## Duración de un día entero (24 h del juego) en segundos reales.
@export var day_length := 480.0
## Hora a la que empieza la partida (0-24).
@export_range(0.0, 24.0) var start_hour := 9.0
@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment

@export_group("Día (Look Lab)")
@export var day_light_energy := 0.55
@export var day_light_color := Color("fff0d1")
@export var day_ambient_energy := 0.45
@export var day_ambient_color := Color("8099c7")
@export var day_sky := Color(0.56, 0.74, 0.9)
## Altura máxima del sol a mediodía (grados).
@export var sun_max_height := 45.0

@export_group("Noche (Look Lab)")
@export var night_light_energy := 0.45
@export var night_light_color := Color("9db4ff")
@export var night_ambient_energy := 0.18
@export var night_ambient_color := Color("334a8a")
@export var night_sky := Color(0.04, 0.07, 0.15)
@export var moon_max_height := 52.0
## Altura mínima de la luna (grados): sale ya alta para que la noche se vea.
@export var moon_min_height := 30.0
## Bandas de luz de noche (0 = suave). De día siempre suave.
@export var night_light_bands := 4.0
## Fuerza de las antorchas (grupo "night_lights") cuando es de noche del todo.
@export var torch_energy := 2.2

@export_group("Recorrido")
## Fracción de luz que queda con el sol o la luna en el horizonte.
@export_range(0.0, 1.0) var min_horizon_light := 0.45
## Dirección (grados) por la que sale el sol; se pone por la contraria.
@export var sunrise_direction := 100.0

## Hora actual (0-24). La sincroniza el nodo Sync.
var hour := 9.0


func _ready() -> void:
	hour = start_hour
	_apply()


func _process(delta: float) -> void:
	hour = fmod(hour + delta * 24.0 / maxf(day_length, 1.0), 24.0)
	_apply()


## 1 = pleno día, 0 = noche cerrada (con amanecer y atardecer suaves).
func daylight() -> float:
	return smoothstep(-0.12, 0.18, sin((hour - 6.0) / 12.0 * PI))


func _apply() -> void:
	var day := daylight()
	var is_day := day >= 0.5
	# el sol de 6 a 18 h y la luna de 18 a 6 h, cada uno con su arco de este a oeste
	var arc := fposmod(hour - 6.0, 12.0) / 12.0
	var lift := sin(arc * PI)
	# el sol sale del horizonte; la luna va siempre alta (si no, de noche apenas alumbra)
	var height := lift * sun_max_height if is_day else lerpf(moon_min_height, moon_max_height, lift)
	var turn := sunrise_direction + arc * 180.0
	if sun:
		sun.rotation_degrees = Vector3(-maxf(height, 4.0), turn, 0.0)
		# baja al acercarse al horizonte, sin apagarse del todo (así el cambio sol/luna no deja un hueco a oscuras)
		var low := lerpf(min_horizon_light, 1.0, clampf(height / 12.0, 0.0, 1.0))
		sun.light_energy = (day_light_energy if is_day else night_light_energy) * low
		sun.light_color = day_light_color if is_day else night_light_color
		# luz de amanecer/atardecer más cálida
		if is_day:
			sun.light_color = sun.light_color.lerp(Color(1.0, 0.7, 0.45), 1.0 - clampf(height / 25.0, 0.0, 1.0))
	if world_environment and world_environment.environment:
		var env := world_environment.environment
		env.ambient_light_energy = lerpf(night_ambient_energy, day_ambient_energy, day)
		env.ambient_light_color = night_ambient_color.lerp(day_ambient_color, day)
		env.background_color = night_sky.lerp(day_sky, day)
	RenderingServer.global_shader_parameter_set(&"light_bands", 0.0 if is_day else night_light_bands)
	for light in get_tree().get_nodes_in_group(&"night_lights"):
		(light as Light3D).light_energy = torch_energy * (1.0 - day)
