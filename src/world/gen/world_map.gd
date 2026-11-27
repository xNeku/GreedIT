class_name WorldMap
extends Resource
## El mapa grande de un mundo ya generado: bioma, barreras, caminos, zonas de dificultad y sitios de cada celda.
## Lo calcula WorldGenerator una vez con la semilla y se guarda; el terreno de cada trozo sale de aquí.
## Coordenadas del mundo en metros con el inicio (la base) en el origen; el norte es -Z.

enum Wall { NONE, BARRIER, PEAK }

@export var seed := 0
@export var n := 256
## Metros por celda.
@export var cell_m := 35.0
## Celda del inicio.
@export var start := Vector2i.ZERO
@export var biome := PackedByteArray()
@export var wall := PackedByteArray()
@export var road := PackedByteArray()
@export var tier := PackedByteArray()
## Metros andando desde el inicio (rodeando lo que haya; -1 = no se llega).
@export var dist := PackedFloat32Array()
## Sitios: {"kind": String, "cell": Vector2i, "n": int}
@export var pois: Array[Dictionary] = []
@export var opened_passes := 0


func index(cell: Vector2i) -> int:
	return cell.y * n + cell.x


## Celda que contiene un punto del mundo.
func cell_at(x: float, z: float) -> Vector2i:
	return Vector2i(clampi(floori(x / cell_m + start.x + 0.5), 0, n - 1), clampi(floori(z / cell_m + start.y + 0.5), 0, n - 1))


## Centro de una celda en el mundo.
func cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - start.x) * cell_m, 0.0, (cell.y - start.y) * cell_m)


## Cuánta montaña hay en un punto (0..1), suave entre celdas.
func mountain_at(x: float, z: float) -> float:
	var fx := x / cell_m + start.x
	var fz := z / cell_m + start.y
	var x0 := clampi(floori(fx), 0, n - 2)
	var z0 := clampi(floori(fz), 0, n - 2)
	var tx := clampf(fx - x0, 0.0, 1.0)
	var tz := clampf(fz - z0, 0.0, 1.0)
	var i := z0 * n + x0
	var a := lerpf(1.0 if wall[i] else 0.0, 1.0 if wall[i + 1] else 0.0, tx)
	var b := lerpf(1.0 if wall[i + n] else 0.0, 1.0 if wall[i + n + 1] else 0.0, tx)
	return lerpf(a, b, tz)


## Las cuatro celdas alrededor de un punto y sus pesos (para mezclar colores entre biomas).
func corners(x: float, z: float) -> Array:
	var fx := x / cell_m + start.x
	var fz := z / cell_m + start.y
	var x0 := clampi(floori(fx), 0, n - 2)
	var z0 := clampi(floori(fz), 0, n - 2)
	var tx := clampf(fx - x0, 0.0, 1.0)
	var tz := clampf(fz - z0, 0.0, 1.0)
	var i := z0 * n + x0
	return [[i, (1.0 - tx) * (1.0 - tz)], [i + 1, tx * (1.0 - tz)], [i + n, (1.0 - tx) * tz], [i + n + 1, tx * tz]]
