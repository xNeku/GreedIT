class_name DecorationData
extends Resource
## Algo que el generador reparte por un bioma (árboles, rocas, hierba...). Se edita en el inspector.

## Modelo (sus mallas se dibujan en MultiMesh: muchas copias, pocas llamadas de dibujo).
@export var scene: PackedScene
## Cuántas por cada 100 m² (antes de quitar las que caen fuera de sus manchas).
@export var per_100m2 := 1.0
## Agrupa en manchas: 0 = repartido por igual, 1 = solo en manchas (bosques, claros).
@export_range(0.0, 1.0, 0.05) var clumping := 0.4
@export var scale_min := 0.8
@export var scale_max := 1.2
## Inclinación al azar (grados), para que no queden todas rectas.
@export var tilt_degrees := 0.0
## Radio (m, a escala 1) que no deja pasar (0 = se atraviesa: hierba, plantas).
@export var block_radius := 0.0
@export var cast_shadow := true
## Solo en las montañas (rocas de las laderas) en vez de en el llano.
@export var on_mountains := false
