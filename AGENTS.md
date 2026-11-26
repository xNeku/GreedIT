# AGENTS.md: reglas del proyecto GreedIT

Este archivo lo leen **todas** las IAs que trabajan en el repo (Claude Code, Codex...) y también las personas.
Si cambias una convención, actualiza este archivo en el mismo commit.

## Contexto

- Motor: **Godot 4.7**, GDScript con tipado estático, renderer *Compatibility* (OpenGL).
- Juego: ARPG coop **3D con cámara isométrica** (estilo Diablo). Diseño en `docs/GDD.md`, tareas en `docs/BACKLOG.md`.
- Idioma: comentarios, docs y textos del juego en **español**. Identificadores de código en **inglés**.

## Norma de arte: las decisiones artísticas las toma el dueño

- **Nunca** decidas tú el aspecto: filtros, shaders, luz, color, estilo del escenario, modelos o UI nueva.
  Enséñale opciones (capturas de ejemplo) y que elija. Lo mismo para generar escenario o arte: **no generes
  nada artístico sin permiso** (gasta tokens y no es lo que quiere).
- Los assets del mundo los elige él (te pide sitios donde buscarlos). Que el personaje de muestra sea low poly
  no obliga a que el resto del juego lo sea.
- Lo técnico (rendimiento, bugs, código, red) sí puedes decidirlo tú.

## Regla de oro: escenas y nodos reales

- Todo lo que se pueda ver o tocar en el editor **es una escena (`.tscn`) o un recurso (`.tres`)**.
  Nada de construir árboles de nodos, animaciones o UI por código en `_ready()`.
- El código **instancia** escenas (`PackedScene.instantiate()`), no las fabrica.
- Las animaciones viven en `AnimationPlayer` dentro de la escena. Los números de balance viven en recursos (`WeaponData`...).
- Objetivo: que el dueño del proyecto pueda abrir cualquier escena en el editor y retocarla sin tocar código.

## Estructura

```
assets/                 arte (solo datos, sin lógica)
  models/               modelos 3D (.glb/.gltf), de muestra y CC0:
    quaternius/         personaje base (Universal Base Characters), ropa modular y Universal Animation Library
    kaykit_adventurers/ armas (weapons/) y animaciones de armas (animations/KayKit_Animations.glb)
    retarget/           mapas de huesos para compartir animaciones entre esqueletos (ver su README)
    pixel_look_import.gd  script de importación de todos los modelos (estilo del juego)
  materials/            contornos (outline_3d*.tres)
  ui/icons/             iconos de objetos (barra de 8 huecos)
src/
  autoload/             Events (bus de señales), GameFeel (hitstop, pantalla completa), Net (solo / host / unirse)
  characters/           Avatar3D, hero/ (el personaje), base/ (materiales y shaders del cuerpo base)
  equipment/            ItemData, EquipmentData, Weapon3DData, Attack3D, Spell3DData; items/ (.tres) y weapons/ (bō)
  combat/               HitData, Hitbox3D, Hurtbox3D, Projectile3D, Explosion3D, DamageLabel3D, OneShotFX,
                        projectiles/, fx/
  player/               Player3D
  enemies/              muñeco de entrenamiento (y los enemigos cuando lleguen)
  world/                Game3D (red + jugadores), game_3d.tscn (el mundo), FollowCamera3D, PixelView + su filtro
  ui/                   menú principal, HUD (orbe de vida + barra de 8 huecos)
tests/                  test de humo y test de red (host + cliente)
docs/                   GDD y backlog
```

Cada cosa vive en una carpeta por funcionalidad, con su escena, su script y sus datos juntos.

## Convenciones de código

- `snake_case` para archivos, variables y funciones. `PascalCase` para nodos y `class_name`.
- Tipado estático siempre (`var x: int`, `-> void`). Usa `class_name` en scripts reutilizables.
- Valores ajustables con `@export` (agrupados con `@export_group`) y un comentario `##` que explique qué hacen.
- Comunicación entre sistemas con **señales**. Lo global va por el autoload `Events`.
- Nada de rutas absolutas de nodos tipo `/root/...`. Usa `@export var x: Node` o `%UniqueName`.

## Red: el juego SIEMPRE es coop

El juego está escrito como multijugador desde la base, aunque juegues solo (en solo se usa un
`OfflineMultiplayerPeer`: eres el peer 1 y mandas sobre todo). **Todo lo nuevo tiene que respetar estas reglas:**

1. **Quién manda (multiplayer authority)**: cada jugador manda sobre su `Player` (authority = su peer id).
   El **host (peer 1)** manda sobre todo lo demás: mobs, muñecos, spawners, mundo.
2. **Solo simula quien manda**: IA, física, vida, cooldowns... dentro de `if is_multiplayer_authority():`
   (en el jugador, `Player.is_local()`). Las copias de los demás solo dibujan.
3. **Daño**: lo calcula quien golpea y lo **aplica quien manda sobre la víctima**. `Hurtbox.receive_hit()` ya
   reenvía el golpe por RPC si hace falta: tú solo llama a `receive_hit()` desde la copia que manda sobre el atacante
   (`Player3D._on_hitbox_hit` y `Explosion3D` ya comprueban que el jugador sea local; los ataques de mobs, que seas el host).
4. **Efectos para todos**: quien aplica el golpe avisa con una RPC `@rpc("authority", "call_local")`
   (p. ej. `TrainingDummy3D._show_hit`) que pinta números, destellos y partículas en todos.
5. **Estado continuo** (posición, vida, animación...) → nodo `Sync` (`MultiplayerSynchronizer`) de la escena.
   **Momentos puntuales** (disparos, efectos) → RPC (`Player3D._fire`, `Player3D._spawn_fx`). La animación del
   jugador viaja como texto en `net_anim` ("clip#contador#velocidad").
6. **Crear cosas en red**: los nodos que deben existir en todos los peers los crea el host y los replica un
   `MultiplayerSpawner` (`PlayerSpawner` en `game_3d.tscn`). Añade la escena a su lista y usa
   `add_child(nodo, true)` para que el nombre sea igual en todos. Proyectiles y efectos rápidos no van por spawner:
   cada peer crea su copia (las de los demás son solo visuales, `visual_only`).
7. **Botín**: el host decide y se lo manda al dueño: `player.receive_item.rpc_id(player.get_multiplayer_authority(), ruta, n)`.
8. Lo local de cada jugador (inventario, maná, recolección, prompts, HUD, cámara) vive en su ordenador.

Flujo: `main_menu` → `Net.play(modo)` → carga `game_3d.tscn` → `Game3D._ready()` llama a `Net.start()` y crea los
jugadores (`_spawn_player` corre en todos los peers y pone el dueño). Un cliente pide su jugador con `_request_spawn`.

## El juego

- **Capas de física**: 1 world, 2 player, 3 enemies, 4 player_attacks, 5 enemy_hurtbox, 6 player_hurtbox,
  7 enemy_attacks, 8 interactables.
- **Estilo pixel art** (el 3D no se ve como 3D realista):
  - El mundo vive dentro de `PixelView/World` (un `SubViewport`) y se pinta a **media resolución** (960x540 en 1080p)
    ampliado sin suavizado, siempre con un número entero de píxeles de pantalla por píxel. `PixelView.pixel_scale`
    decide lo gordo que es el píxel. El HUD va fuera, a resolución normal (el proyecto usa `canvas_items`).
  - Filtro final `pixel_post.gdshader` (saturación, contraste, tinte de sombras; paleta reducida y tramado
    desactivados porque el escenario parecía roto). Se ajusta en `pixel_post_material.tres`.
  - Todos los modelos se importan con `assets/models/pixel_look_import.gd` (luz por bandas, texturas *nearest* y
    contorno oscuro de 1 px con `assets/materials/outline_3d.tres`). **Un modelo nuevo tiene que llevar ese
    "Import Script"** (pestaña Importar del .glb) o se verá realista. Materiales hechos a mano: `diffuse_mode` toon,
    sin especular y `next_pass` = `outline_3d.tres`.
  - Cámara `FollowCamera3D` **ortográfica isométrica** estilo Diablo (giro 45°, 30° desde el suelo = líneas 2:1),
    zoom con + / - (`size` = alto visible en metros). Se pega a la rejilla de píxeles
    (`pixel_snap`) y le pasa a `PixelView` el resto (`snap_offset`) para un scroll suave.
  - **Interpolación de física** activada en el proyecto: lo que se mueve en
    `_physics_process` se dibuja suave aunque la pantalla vaya a 120 Hz. La cámara lee
    `get_global_transform_interpolated()` y tiene la interpolación apagada (se mueve en `_process`).
- **Personaje** = `Avatar3D` (`src/characters/hero/hero.tscn`): la Universal Animation Library de Quaternius
  (`UAL1_Standard.glb`: esqueleto + animaciones; su maniquí va oculto) **retargeteada** al humanoide de Godot
  (`assets/models/retarget/`). Lo que lleva puesto es equipo de serie (`default_items`): `BODY` (cuerpo en ropa
  interior de Universal Base Characters), `FACE` (ojos y cejas), `HAIR` y `BEARD`. Las animaciones de armas vienen de
  KayKit (`KayKit_Animations.glb`, retargeteado igual) vía `extra_animation_sources`; `clip_aliases` cambia la
  carrera/esquiva/golpe por las de Quaternius. Las armas se pegan a `HandR/GripR` y `HandL/GripL` (se colocan a mano
  en el editor). Cuando lleve ropa encima, el cuerpo debe usar `body_male_covered_material.tres` (solo dibuja cuello
  y cabeza) para que no asome por la ropa.
- **Jugador** = `Player3D`: el dueño simula; por `Sync` viajan posición, `yaw`, `net_anim` ("clip#contador#velocidad"),
  `charging`, el hueco elegido (`slot_index`) y la vida. Barra de 8 huecos (`hotbar`, 1-8 / rueda); hueco vacío =
  `unarmed` (puños). Al morir reaparece en su punto de salida; tras un golpe es invulnerable un momento.
- **Movimiento**: WASD relativo a la cámara. Salto estilo Conquer (se agacha y sale hacia donde corres; en lo alto
  esquivas golpes, `dodge_height`), aterrizaje con polvo. Shift = esquiva. Los ataques en el aire se hacen en el
  aire, sin caer en picado.
- **Armas** = `Weapon3DData` (.tres) con sus **ataques** (`Attack3D`, sub-recursos editables en el inspector):
  `combo` (clic), `heavy` (mantener: `hold_mode` CHARGE carga hasta `max_charge_multiplier`; REPEAT = ráfaga del
  combo), `alt` (clic derecho), `alt_hold` (mantener clic derecho) y `air` (atacar en el aire).
  Cada `Attack3D` dice: animación y velocidad, momento del golpe (`hit_time`/`hit_window` en 0..1), daño, área,
  avance (`lunge`), salto (`leap` hacia el ratón o hacia atrás, con `land_attack` al aterrizar), caída en picado
  (`plunge`), proyectiles (cuántos, abanico, escena, tamaño) y efecto (`fx_scene`).
  Para añadir un arma: duplica un `.tres` de `src/equipment/items/`, ponle icono (`assets/ui/icons/`) y métela en un
  hueco de `hotbar` en `player_3d.tscn`. El bō es una escena propia (`src/equipment/weapons/bo_staff.tscn`).
- **Hechizo** (clic de la rueda) = `Spell3DData` (`fireball.tres`): maná, enfriamiento, daño y su `cast` (un Attack3D
  con el proyectil). Los proyectiles con `explosion_scene` explotan (`Explosion3D`: daño en área, solo en el dueño).
- En red, los ataques se identifican por clave (`combo0`, `heavy`, `alt`, `alt_hold`, `air`, `spell`, `.../land`):
  `Player3D._fire` (proyectiles) y `_spawn_fx` (efectos) son RPC; `charging` va por `Sync`.

### Equipo y modelos propios (Blender)

Para que el arte nuevo encaje solo, los modelos se exportan como **glTF (.glb)** con un esqueleto humanoide y,
al importarlo en Godot, se le pone un **Bone Map** (Importar → Skeleton3D → Retarget). Así le valen todas las
animaciones del proyecto (las de Quaternius, las de armas de KayKit y las de Mixamo). Lo más cómodo: modelar
encima del esqueleto de Quaternius (`UAL1_Standard.glb`) y reutilizar `assets/models/retarget/ual_bone_map.tres`.
Huesos que usa el código (`Avatar3D.slot_bones`, nombres del humanoide):

| Ranura | Hueso | Qué va ahí |
|---|---|---|
| MAIN_HAND | `RightHand` (+ `GripR`) | arma principal (el mango en el origen) |
| OFF_HAND | `LeftHand` (+ `GripL`) | escudo, segunda daga, libro |
| HEAD | `Head` | casco, sombrero, capucha |
| BACK / CHEST | `UpperChest` | capa / piezas rígidas del pecho |
| OUTFIT | (con esqueleto) | conjunto de ropa entero de los personajes modulares |
| BODY / FACE / HAIR / BEARD | (con esqueleto) | cuerpo base, ojos y cejas, pelo y barba |

Dos tipos de pieza (`EquipmentData`):

1. **Rígida** (armas, escudos, cascos): un .glb suelto, modelado con el origen donde la agarra la mano. Se pega al hueso.
   Si queda torcida, se corrige con `position_offset` / `rotation_offset_degrees` en su `.tres`, no en código.
2. **Con esqueleto** (`skinned = true`: petos, pantalones, botas, ropa): en Blender se modela **encima del cuerpo base**
   y se pesa (*weight paint*) al **mismo esqueleto**. Se exporta en un .glb. Al equiparla, sus mallas se pasan al
   esqueleto del personaje y se deforman con TODAS sus animaciones. `hides_body_parts` oculta lo que tapa
   (nombres de `Avatar3D.body_parts`) para que no atraviese.

Las animaciones nuevas (de Blender o Mixamo retargeteadas al esqueleto) se añaden al `AnimationPlayer` del personaje
con su nombre y se usan desde los `.tres` de las armas.

## Verificar antes de hacer commit

```bash
godot --headless --path . --import                       # reimporta y muestra errores de scripts/escenas
godot --headless --path . res://tests/smoke_test.tscn     # debe terminar con "SMOKE OK"
```

Si tocas algo de red (o cualquier cosa que se vea en coop), pasa también el test de red (dos copias del juego):

```bash
godot --headless --path . res://tests/net_test.tscn -- --role=host --port=7795 &
godot --headless --path . res://tests/net_test.tscn -- --role=client --port=7795   # "NET CLIENT OK" (y el host "NET HOST OK")
```

Si cambias combate o armas y el test falla, arréglalo o actualiza el test en el mismo commit.

## Git

- Commits pequeños y descriptivos, en español.
- Commitea los `.uid` que genera Godot (van junto a cada script/recurso). No commitees `.godot/`.

## Trabajo entre IAs

- Antes de empezar, lee `docs/BACKLOG.md` y marca en qué estás (`[~]` + tu nombre) para no pisaros.
- Al terminar, márcalo como hecho (`[x]`) y apunta en el backlog lo que hayas dejado pendiente.
