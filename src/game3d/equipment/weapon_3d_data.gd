class_name Weapon3DData
extends EquipmentData
## Arma 3D: qué animaciones usa (nombres de las animaciones del modelo), cuándo golpea y cuánto daño hace.

enum Kind { MELEE, RANGED, MAGIC }

@export var kind: Kind = Kind.MELEE
## Arma de la otra mano (dagas dobles...). Se equipa a la vez.
@export var offhand_scene: PackedScene
## Si se puede llevar escudo en la otra mano (armas de una mano sin arma secundaria).
@export var allows_shield := false

@export_group("Animaciones")
## Animación en reposo con esta arma.
@export var idle_clip := "Idle"
## Combo de clic izquierdo (se encadenan pulsando de nuevo).
@export var combo_clips: PackedStringArray = ["1H_Melee_Attack_Slice_Diagonal"]
## Clic derecho.
@export var alt_clip := ""
## Si el clic derecho golpea en área alrededor (giros, novas).
@export var alt_is_area := false
## Efecto que aparece a tus pies al usar el clic derecho (onda de la nova, remolino del giro...).
@export var alt_fx_scene: PackedScene
## Velocidad de las animaciones de ataque (las de KayKit van tranquilas; >1 = más ARPG).
@export var attack_speed := 1.5
## Momento del golpe (0..1 de la animación) y cuánto dura la ventana de golpe.
@export var hit_time := 0.4
@export var hit_window := 0.18

@export_group("Daño")
@export var base_damage := 10.0
@export_range(0.0, 1.0) var crit_chance := 0.1
@export var crit_multiplier := 2.0
## Alcance y anchura de la zona de golpe (unidades).
@export var reach := 1.8
@export var width := 1.8
@export var knockback := 6.0
@export var alt_damage_multiplier := 1.6

@export_group("A distancia / magia")
@export var projectile_scene: PackedScene
@export var projectile_speed := 18.0
## Proyectiles en el clic derecho (abanico).
@export var alt_projectiles := 3
