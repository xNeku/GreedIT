class_name Attack3D
extends Resource
## Un ataque de un arma 3D (o el gesto de un hechizo): qué animación pone, cuándo golpea, cuánto empuja al
## personaje, si salta, si dispara... Va dentro del `.tres` del arma (Weapon3DData) y se edita en el inspector.

enum Leap {
	NONE, ## no salta
	TO_TARGET, ## salta hacia el ratón (salto aplastante)
	BACKWARD, ## salto atrás (alejándose del ratón)
}

@export_group("Animación")
## Animación del modelo. Vacía = sigue la que esté (golpes al aterrizar).
@export var clip := ""
## Velocidad de la animación (las de muestra van tranquilas; >1 = más ARPG).
@export var speed := 1.6
## Momento del golpe (0..1 de la animación) y cuánto dura la ventana de golpe.
@export_range(0.0, 1.0) var hit_time := 0.4
@export_range(0.0, 1.0) var hit_window := 0.18
## Velocidad de movimiento mientras dura (x la normal).
@export var move_multiplier := 0.2

@export_group("Daño")
@export var damage_multiplier := 1.0
@export var knockback_multiplier := 1.0
## Golpea alrededor del personaje (giros, novas, aterrizajes) en vez de delante.
@export var area := false
@export var area_radius := 2.6
## Vibración de cámara al golpear (0 = la de siempre).
@export var shake := 0.0

@export_group("Movimiento")
## Avance hacia delante al empezar (m/s, se frena solo). Da peso a los golpes.
@export var lunge := 0.0
@export var leap: Leap = Leap.NONE
@export var leap_distance := 7.0
## Segundos en el aire del salto.
@export var leap_time := 0.55
## Ataque en el aire: cae en picado.
@export var plunge := false
## Ataque que se hace al aterrizar (tras un salto o una caída en picado).
@export var land_attack: Attack3D

@export_group("Proyectiles")
## Proyectiles que dispara en el momento del golpe (0 = cuerpo a cuerpo).
@export var projectiles := 0
## Abanico total (grados) cuando hay varios.
@export var spread_degrees := 30.0
## Proyectil propio de este ataque (vacío = el del arma).
@export var projectile_scene: PackedScene
## Tamaño del proyectil (ataques cargados).
@export var projectile_scale := 1.0

@export_group("Efecto")
## Efecto visual (onda, remolino, polvo...).
@export var fx_scene: PackedScene
## Sale en el momento del golpe (si no, al empezar).
@export var fx_on_hit := false
## Va pegado al personaje (remolinos) o se queda en el suelo (ondas, aterrizajes).
@export var fx_attached := false
