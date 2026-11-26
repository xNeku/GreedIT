class_name Spell3DData
extends ItemData
## Hechizo 3D (clic de la rueda): gasta maná y hace un gesto (`cast`, un Attack3D con su proyectil).

@export_group("Coste")
@export var mana_cost := 20.0
@export var cooldown := 0.5

@export_group("Daño")
@export var base_damage := 18.0
@export_range(0.0, 1.0) var crit_chance := 0.1
@export var crit_multiplier := 1.8
## Alcance máximo (metros): el proyectil explota en el punto del ratón o al chocar.
@export var max_range := 14.0

@export_group("Lanzamiento")
@export var cast: Attack3D
@export var projectile_speed := 16.0
