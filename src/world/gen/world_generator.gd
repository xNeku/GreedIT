class_name WorldGenerator
extends RefCounted
## Genera el mapa grande de un mundo a partir de su semilla y sus reglas (WorldSettings), igual que el World Lab:
##   1. biomas: Voronoi con pesos (cada bioma ocupa lo que pide) y bordes deformados con ruido
##   2. barreras: cordilleras con pasos, borde del mundo y picos sueltos en los biomas rocosos
##   3. todo se puede recorrer: se abren pasos hacia las zonas que hayan quedado encerradas
##   4. distancia andando desde el inicio -> zonas de dificultad (5)
##   5. sitios: bosses escalonados por distancia, campamentos, dungeons al pie de las montañas, minas, cuevas, eventos
##   6. caminos principales de la base a los campamentos y los bosses
## Con la misma semilla sale siempre lo mismo (en todos los peers): por red solo hace falta la semilla.
## Va en GDScript: los bucles sobre todas las celdas están escritos para ir rápido (sin crear listas por celda).

## Súbelo si cambia el algoritmo: los mapas guardados en disco con otra versión se vuelven a generar.
const VERSION := 2
## Lado (en celdas) de las zonas en las que se agrupan los sitios para comprobar distancias rápido.
const BUCKET := 16

var _rng := RandomNumberGenerator.new()
var _s: WorldSettings
var _n := 256
var _biome := PackedByteArray()
var _wall := PackedByteArray()
var _near_wall := PackedByteArray()
var _dist := PackedFloat32Array()
var _max_d := 1.0
var _walkable := PackedInt32Array()
var _pois: Array[Dictionary] = []
var _buckets := {} # Vector2i -> Array[Dictionary]


static func generate(settings: WorldSettings, seed: int) -> WorldMap:
	return WorldGenerator.new()._run(settings, seed)


func _noise(seed: int, frequency: float, octaves: int = 1) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	noise.fractal_octaves = octaves
	return noise


func _run(settings: WorldSettings, seed: int) -> WorldMap:
	_s = settings
	_n = settings.cells
	_rng.seed = seed
	var n := _n
	var total := n * n
	var map := WorldMap.new()
	map.seed = seed
	map.n = n
	map.cell_m = settings.size_km * 1000.0 / n
	var start_pos := _make_biomes(seed)
	_make_barriers(seed)
	var sx := roundi(start_pos.x * (n - 1))
	var sy := roundi(start_pos.y * (n - 1))
	for dy in range(-5, 6):
		for dx in range(-5, 6):
			var x := sx + dx
			var y := sy + dy
			if x > 2 and y > 2 and x < n - 3 and y < n - 3:
				_wall[y * n + x] = WorldMap.Wall.NONE
	var start := sy * n + sx
	map.opened_passes = _connect_all(start)
	_walk_distance(start)
	_mark_near_wall()
	_place_sites(Vector2i(sx, sy))
	var road := _make_roads(Vector2i(sx, sy))
	var tier := PackedByteArray()
	tier.resize(total)
	for i in total:
		if _dist[i] >= 0.0:
			tier[i] = mini(4, floori(_dist[i] / _max_d * 5.0))
			_dist[i] *= map.cell_m
	map.start = Vector2i(sx, sy)
	map.biome = _biome
	map.wall = _wall
	map.road = road
	map.tier = tier
	map.dist = _dist
	map.pois = _pois
	return map


# --- 1. Biomas -----------------------------------------------------------------------------------------------

## Voronoi con pesos y bordes deformados; devuelve dónde se empieza (0..1).
func _make_biomes(seed: int) -> Vector2:
	var n := _n
	var biomes := _s.biomes
	var count := biomes.size()
	var target := PackedFloat32Array()
	var total := 0.0
	for b in biomes:
		target.append(maxf(0.01, b.weight))
		total += maxf(0.01, b.weight)
	for i in count:
		target[i] /= total
	var cx := PackedFloat32Array()
	var cy := PackedFloat32Array()
	var cw := PackedFloat32Array()
	var cb := PackedInt32Array()
	for i in count:
		var zone := _climate_zone(biomes[i].climate)
		for k in maxi(1, roundi(target[i] * 16.0)):
			var best := Vector2.ZERO
			var best_d := -1.0
			for t in 30:
				var p := Vector2(0.05 + _rng.randf() * 0.9, zone.x + _rng.randf() * (zone.y - zone.x))
				var d := INF
				for c in cx.size():
					d = minf(d, p.distance_to(Vector2(cx[c], cy[c])))
				if d > best_d:
					best_d = d
					best = p
			cx.append(best.x)
			cy.append(best.y)
			cw.append(1.0)
			cb.append(i)
	var start_pos := Vector2(0.5, 0.5) if _s.start_in_center else Vector2(0.5 + (_rng.randf() - 0.5) * 0.5, 0.93)
	var start_biome := 0
	for i in count:
		if biomes[i].id == _s.start_biome:
			start_biome = i
	cx.append(start_pos.x)
	cy.append(start_pos.y)
	cw.append(1.3)
	cb.append(start_biome)
	var amp := 0.03 + _s.border_warp * 0.17
	var warp_x := _noise(seed + 7, 4.0, 4)
	var warp_y := _noise(seed + 9, 4.0, 4)
	var centers := cx.size()
	# Pesos ajustados en una rejilla pequeña para que cada bioma ocupe lo que pide.
	var m := 48
	for it in 6:
		var area := PackedFloat32Array()
		area.resize(count)
		for y in m:
			for x in m:
				var px := (x + 0.5) / m
				var py := (y + 0.5) / m
				area[cb[_nearest(px + warp_x.get_noise_2d(px, py) * amp, py + warp_y.get_noise_2d(px + 31.0, py + 17.0) * amp, cx, cy, cw, centers)]] += 1.0
		for c in centers:
			var a := area[cb[c]] / float(m * m)
			cw[c] *= clampf(pow(sqrt(target[cb[c]] / maxf(a, 0.002)), 0.5), 0.6, 1.6)
	_biome.resize(n * n)
	for y in n:
		var py := (y + 0.5) / n
		for x in n:
			var px := (x + 0.5) / n
			_biome[y * n + x] = cb[_nearest(px + warp_x.get_noise_2d(px, py) * amp, py + warp_y.get_noise_2d(px + 31.0, py + 17.0) * amp, cx, cy, cw, centers)]
	return start_pos


func _nearest(qx: float, qy: float, cx: PackedFloat32Array, cy: PackedFloat32Array, cw: PackedFloat32Array, count: int) -> int:
	var best := 0
	var best_d := INF
	for i in count:
		var dx := cx[i] - qx
		var dy := cy[i] - qy
		var d := (dx * dx + dy * dy) / (cw[i] * cw[i])
		if d < best_d:
			best_d = d
			best = i
	return best


func _climate_zone(climate: BiomeData.Climate) -> Vector2:
	if not _s.logical_climate:
		return Vector2(0.05, 0.95)
	match climate:
		BiomeData.Climate.NORTH: return Vector2(0.03, 0.3)
		BiomeData.Climate.SOUTH: return Vector2(0.65, 0.97)
		BiomeData.Climate.MID: return Vector2(0.3, 0.7)
	return Vector2(0.05, 0.95)


# --- 2. Barreras ---------------------------------------------------------------------------------------------

func _make_barriers(seed: int) -> void:
	var n := _n
	_wall.resize(n * n)
	var pass_mask := PackedByteArray()
	pass_mask.resize(n * n)
	var walk_noise := _noise(seed + 55, 1.0)
	var thick_noise := _noise(seed + 77, 1.0)
	var ranges: Array[PackedVector3Array] = []
	for r in _s.ranges:
		var x := n * (0.12 + _rng.randf() * 0.76)
		var y := n * (0.12 + _rng.randf() * 0.76)
		var angle := _rng.randf() * TAU
		var length := n * _s.range_length * (0.7 + _rng.randf() * 0.6)
		var points := PackedVector3Array()
		for i in int(length):
			angle += walk_noise.get_noise_2d(i * 0.05, r * 3.1) * 0.25
			x += cos(angle)
			y += sin(angle)
			if x < 4 or y < 4 or x > n - 5 or y > n - 5:
				break
			var th := _s.range_thickness * (0.55 + 0.9 * (thick_noise.get_noise_2d(i * 0.08, r * 7.7) * 0.5 + 0.5))
			points.append(Vector3(x, y, th))
		ranges.append(points)
	for points in ranges:
		for p in points:
			_stamp(_wall, p.x, p.y, p.z, WorldMap.Wall.BARRIER)
	for points in ranges:
		if points.size() < 12:
			continue
		for k in _s.passes_per_range:
			var t := clampf((k + 1.0) / (_s.passes_per_range + 1.0) + (_rng.randf() - 0.5) * 0.12, 0.05, 0.95)
			var p := points[int(t * (points.size() - 1))]
			_stamp(pass_mask, p.x, p.y, p.z + 2.5, 1)
	var edge_noise := _noise(seed + 3, 0.05, 4)
	var peak_noise := _noise(seed + 21, 0.03, 3)
	var rocky := PackedByteArray()
	for b in _s.biomes:
		rocky.append(1 if b.rocky else 0)
	for y in n:
		for x in n:
			var i := y * n + x
			if mini(mini(x, y), mini(n - 1 - x, n - 1 - y)) < 3.0 + 4.0 * (edge_noise.get_noise_2d(x, y) * 0.5 + 0.5):
				_wall[i] = WorldMap.Wall.BARRIER
			elif pass_mask[i]:
				_wall[i] = WorldMap.Wall.NONE
			elif not _wall[i] and rocky[_biome[i]] and 1.0 - absf(peak_noise.get_noise_2d(x, y)) > 0.93:
				_wall[i] = WorldMap.Wall.PEAK


## Pinta un círculo en un array de celdas (los PackedArray se pasan por referencia).
func _stamp(arr: PackedByteArray, cx: float, cy: float, r: float, value: int) -> void:
	var n := _n
	for y in range(maxi(0, floori(cy - r)), mini(n - 1, ceili(cy + r)) + 1):
		for x in range(maxi(0, floori(cx - r)), mini(n - 1, ceili(cx + r)) + 1):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r:
				arr[y * n + x] = value


# --- 3. Que todo se pueda recorrer ---------------------------------------------------------------------------

## Abre pasos (atravesando la barrera) desde cada zona encerrada grande hasta lo que ya se alcanza; los rincones
## pequeños se rellenan. Devuelve cuántos pasos ha abierto.
func _connect_all(start: int) -> int:
	var n := _n
	var total := n * n
	var opened := 0
	for guard in 30:
		var marks := PackedInt32Array()
		marks.resize(total) # 0 = sin visitar, 1 = alcanzable, >1 = zona encerrada
		_flood(marks, start, 1)
		var big_seed := -1
		var big_size := 0
		var label := 2
		for i in total:
			if _wall[i] or marks[i]:
				continue
			var region := _flood(marks, i, label)
			label += 1
			if region.size() < 40:
				for a in region:
					_wall[a] = WorldMap.Wall.PEAK
				continue
			if region.size() > big_size:
				big_size = region.size()
				big_seed = i
		if big_seed < 0:
			break
		# camino más corto desde esa zona hasta lo alcanzable, atravesando la barrera
		var prev := PackedInt32Array()
		prev.resize(total)
		prev.fill(-2)
		prev[big_seed] = -1
		var queue := PackedInt32Array([big_seed])
		var hit := -1
		var h := 0
		while h < queue.size() and hit < 0:
			var a := queue[h]
			h += 1
			var x := a % n
			for j: int in [a - 1 if x > 0 else -1, a + 1 if x < n - 1 else -1, a - n, a + n]:
				if j < 0 or j >= total or prev[j] != -2:
					continue
				prev[j] = a
				if marks[j] == 1:
					hit = j
					break
				queue.append(j)
		var a := hit
		while a >= 0:
			var x := a % n
			var y := a / n
			for ry in range(-1, 2):
				for rx in range(-1, 2):
					var xx := x + rx
					var yy := y + ry
					if xx > 2 and yy > 2 and xx < n - 3 and yy < n - 3:
						_wall[yy * n + xx] = WorldMap.Wall.NONE
			a = prev[a]
		opened += 1
	return opened


## Rellena `marks` con `mark` desde `start` por lo que no es barrera; devuelve las celdas visitadas.
func _flood(marks: PackedInt32Array, start: int, mark: int) -> PackedInt32Array:
	var n := _n
	var total := n * n
	marks[start] = mark
	var queue := PackedInt32Array([start])
	var h := 0
	while h < queue.size():
		var a := queue[h]
		h += 1
		var x := a % n
		if x > 0 and not marks[a - 1] and not _wall[a - 1]:
			marks[a - 1] = mark
			queue.append(a - 1)
		if x < n - 1 and not marks[a + 1] and not _wall[a + 1]:
			marks[a + 1] = mark
			queue.append(a + 1)
		if a >= n and not marks[a - n] and not _wall[a - n]:
			marks[a - n] = mark
			queue.append(a - n)
		if a < total - n and not marks[a + n] and not _wall[a + n]:
			marks[a + n] = mark
			queue.append(a + n)
	return queue


# --- 4. Distancia andando ------------------------------------------------------------------------------------

## Distancia andando (en celdas) desde el inicio, con diagonales: Dijkstra con cubos (costes 10 y 14), rápido.
func _walk_distance(start: int) -> void:
	var n := _n
	var total := n * n
	var cost := PackedInt32Array()
	cost.resize(total)
	cost.fill(2147483647)
	cost[start] = 0
	var buckets: Array[PackedInt32Array] = []
	for i in 15:
		buckets.append(PackedInt32Array())
	buckets[0].append(start)
	var current := 0
	var pending := 1
	var offsets := PackedInt32Array([-1, 1, -n, n, -n - 1, -n + 1, n - 1, n + 1])
	var dxs := PackedInt32Array([-1, 1, 0, 0, -1, 1, -1, 1])
	var steps := PackedInt32Array([10, 10, 10, 10, 14, 14, 14, 14])
	while pending > 0:
		var slot := current % 15
		var list := buckets[slot]
		buckets[slot] = PackedInt32Array()
		pending -= list.size()
		for a in list:
			if cost[a] != current:
				continue
			var x := a % n
			for k in 8:
				var nx := x + dxs[k]
				if nx < 0 or nx >= n:
					continue
				var j := a + offsets[k]
				if j < 0 or j >= total or _wall[j]:
					continue
				if k >= 4 and (_wall[a + dxs[k]] or _wall[j - dxs[k]]):
					continue # no se corta en diagonal por una esquina de montaña
				var c := current + steps[k]
				if c < cost[j]:
					cost[j] = c
					buckets[c % 15].append(j)
					pending += 1
		current += 1
	_dist.resize(total)
	_max_d = 1.0
	_walkable = PackedInt32Array()
	for i in total:
		if cost[i] < 2147483647:
			_dist[i] = cost[i] / 10.0
			_max_d = maxf(_max_d, _dist[i])
			_walkable.append(i)
		else:
			_dist[i] = -1.0


func _mark_near_wall() -> void:
	var n := _n
	_near_wall.resize(n * n)
	for y in range(2, n - 2):
		for x in range(2, n - 2):
			var i := y * n + x
			if _wall[i]:
				continue
			var found := false
			for ry in range(-2, 3):
				for rx in range(-2, 3):
					if _wall[i + ry * n + rx]:
						found = true
						break
				if found:
					break
			_near_wall[i] = 1 if found else 0


# --- 5. Sitios -----------------------------------------------------------------------------------------------

func _place_sites(base: Vector2i) -> void:
	var n := _n
	var biomes := _s.biomes
	_add_site("base", base.y * n + base.x, 0)
	var used := {}
	for k in _s.bosses:
		var t := 0.6 if _s.bosses == 1 else 0.22 + 0.68 * k / float(_s.bosses - 1)
		var i := _pick_near(t, 0.08, 10.0, "boss", n * 0.16, func(c: int) -> float:
			return 0.0 if used.has(_biome[c]) else 2.0)
		if i >= 0:
			used[_biome[i]] = true
			_add_site("boss", i, k + 1)
	var well := _pick_near(0.55, 0.15, 14.0, "well", 0.0, func(c: int) -> float:
		return (3.0 if biomes[_biome[c]].id in [&"desierto", &"montana"] else 0.0) + (1.0 if _near_wall[c] else 0.0))
	if well >= 0:
		_add_site("well", well, 0)
	var guardian := _pick_near(0.95, 0.12, 14.0, "guardian", 0.0, func(c: int) -> float:
		return 3.0 if biomes[_biome[c]].id == &"montana" else 0.0)
	if guardian >= 0:
		_add_site("guardian", guardian, 0)
	for k in _s.camps:
		var t := 0.5 if _s.camps == 1 else 0.12 + 0.76 * k / float(_s.camps - 1)
		var i := _pick_near(t, 0.1, 10.0, "camp", n * 0.2, Callable())
		if i >= 0:
			_add_site("camp", i, 0)
	_place_many("dungeon", _s.dungeons, 6.0, n * 0.07, func(c: int) -> float:
		return 0.9 if _near_wall[c] else 0.12)
	_place_many("mine", _s.mines, 5.0, n * 0.06, func(c: int) -> float:
		return 0.9 if _near_wall[c] or biomes[_biome[c]].rocky else 0.05)
	_place_many("cave", _s.caves, 5.0, n * 0.06, func(c: int) -> float:
		return 0.8 if biomes[_biome[c]].id in [&"jungla", &"nieve"] else 0.3)
	_place_many("event", _s.events, 3.0, n * 0.035, Callable())


func _add_site(kind: String, i: int, number: int) -> void:
	var cell := Vector2i(i % _n, i / _n)
	var site := {"kind": kind, "cell": cell, "n": number}
	_pois.append(site)
	var key := cell / BUCKET
	if not _buckets.has(key):
		_buckets[key] = []
	(_buckets[key] as Array).append(site)


func _is_free(i: int, min_d: float, kind: String, same_d: float) -> bool:
	var x := i % _n
	var y := i / _n
	var reach := ceili(maxf(min_d, same_d) / BUCKET)
	var key := Vector2i(x, y) / BUCKET
	for by in range(key.y - reach, key.y + reach + 1):
		for bx in range(key.x - reach, key.x + reach + 1):
			var list: Array = _buckets.get(Vector2i(bx, by), [])
			for site: Dictionary in list:
				var c: Vector2i = site.cell
				var d := Vector2(c.x - x, c.y - y).length()
				if d < min_d or (site.kind == kind and d < same_d):
					return false
	return true


func _pick_near(target: float, tolerance: float, min_d: float, kind: String, same_d: float, prefer: Callable) -> int:
	var best := -1
	var best_score := -INF
	for k in 4000:
		var i := _walkable[_rng.randi() % _walkable.size()]
		var e := absf(_dist[i] / _max_d - target)
		if e > tolerance or not _is_free(i, min_d, kind, same_d):
			continue
		var score: float = -e * 10.0 + (prefer.call(i) if prefer.is_valid() else 0.0) + _rng.randf() * 0.3
		if score > best_score:
			best_score = score
			best = i
	return best


func _place_many(kind: String, count: int, min_d: float, same_d: float, prefer: Callable) -> void:
	var placed := 0
	var tries := 0
	while placed < count and tries < 20000:
		tries += 1
		var i := _walkable[_rng.randi() % _walkable.size()]
		if _dist[i] / _max_d < 0.04:
			continue
		if prefer.is_valid() and _rng.randf() > prefer.call(i):
			continue
		if not _is_free(i, min_d, kind, same_d):
			continue
		_add_site(kind, i, 0)
		placed += 1


# --- 6. Caminos ----------------------------------------------------------------------------------------------

func _make_roads(base: Vector2i) -> PackedByteArray:
	var n := _n
	var road := PackedByteArray()
	road.resize(n * n)
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, n, n)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for i in n * n:
		if _wall[i]:
			astar.set_point_solid(Vector2i(i % n, i / n))
		elif _near_wall[i]:
			astar.set_point_weight_scale(Vector2i(i % n, i / n), 1.6)
	var targets := _pois.filter(func(p: Dictionary) -> bool: return p.kind in ["camp", "boss"])
	targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _dist[a.cell.y * n + a.cell.x] < _dist[b.cell.y * n + b.cell.x])
	for site in targets:
		for c in astar.get_id_path(base, site.cell):
			road[c.y * n + c.x] = 1
			astar.set_point_weight_scale(c, 0.35)
	return road
