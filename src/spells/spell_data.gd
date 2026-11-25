class_name SpellData
extends ItemData
## Datos de un hechizo. Se lanza con clic de la rueda del ratón (acción "cast_spell").
## La escena del proyectil (`projectile_scene`) define cómo vuela y explota; aquí van los números.

@export_group("Coste")
@export var mana_cost: float = 20.0
@export var cooldown: float = 0.5

@export_group("Daño")
@export var base_damage: float = 18.0
@export_range(0.0, 1.0) var crit_chance: float = 0.1
@export var crit_multiplier: float = 1.8
@export var knockback: float = 140.0

@export_group("Proyectil")
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 300.0
