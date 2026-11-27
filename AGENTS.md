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
  _inbox/               buzón: zips de packs para probar (van a la rama `inbox`, no a main; ver su README)
  models/               modelos 3D (.glb/.gltf), de muestra y CC0:
    quaternius/         personaje base (Universal Base Characters) y Universal Animation Library: SOLO los archivos
                        que usa el juego (los packs enteros pesan cientos de MB; si hace falta algo más, se copia
                        ese archivo suelto). La ropa modular se quitó hasta que haya diseños propios.
    kaykit_adventurers/ armas (weapons/) y animaciones de armas (animations/KayKit_Animations.glb)
    lowpoly_environment/ pack de entorno del dueño (árboles, rocas, arbustos, plantas, troncos, montañas)
    retarget/           mapas de huesos para compartir animaciones entre esqueletos (ver su README)
    pixel_look_import.gd  script de importación de todos los modelos (estilo del juego)
  materials/            world_lit.gdshader: el material de todo el juego
  vfx/binbun/           efectos de BinbunVFX (CC0, de prueba): fuego, rayo y estados (ver assets/vfx/README.md)
  ui/icons/             iconos de objetos (barra de 8 huecos)
src/
  autoload/             Events (bus de señales), GameFeel (hitstop, pantalla completa), Net (solo / host / unirse)
  characters/           Avatar3D, hero/ (el personaje), base/ (materiales y shaders del cuerpo base)
  equipment/            ItemData, EquipmentData, Weapon3DData, Attack3D, Spell3DData; items/ (.tres) y weapons/ (bō)
  combat/               HitData, Hitbox3D, Hurtbox3D, Projectile3D, Explosion3D, DamageLabel3D, OneShotFX,
                        projectiles/, fx/
  player/               Player3D
  enemies/              muñeco de entrenamiento (y los enemigos cuando lleguen)
  world/                Game3D (red + jugadores), game_3d.tscn (el mundo), DayNightCycle, FollowCamera3D, PixelView + filtro
    gen/                generador de mundo: WorldGenerator (mapa grande), WorldStreamer (trozos), WorldSettings,
                        BiomeData, DecorationData; normal/ = reglas y biomas del mundo normal (.tres)
  ui/                   menú principal, HUD (orbe de vida + barra de 8 huecos), mapa de prueba (M)
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
- **Look** (elegido por el dueño en el Look Lab, https://claude.ai/artifact/72cQRp1pfboZeHSb1yLZGM):
  - El mundo vive dentro de `PixelView/World` (un `SubViewport`) y se pinta a 960x540 en 1080p, ampliado sin
    suavizado (`PixelView.pixel_scale`). El HUD va fuera, a resolución normal (el proyecto usa `canvas_items`).
  - **Un solo material para todo**: `assets/materials/world_lit.gdshader` (color + textura sin suavizar, sin brillos).
    Luz **suave de día y por bandas de noche** según el ajuste global `light_bands` (0 = suave, 4 = cuatro bandas).
    Sin contorno. El script de importación `assets/models/pixel_look_import.gd` pone este material a todos los
    modelos: **un modelo nuevo tiene que llevar ese "Import Script"**. Materiales hechos a mano: ShaderMaterial con
    ese shader (`albedo_color`, `albedo_texture`).
  - Filtro final `pixel_post.gdshader` (brillo, curva de cine ACES, temperatura, contraste, saturación, tinte de
    sombras, viñeta), con las mismas fórmulas que el Look Lab; valores en `pixel_post_material.tres`. El Environment
    va con tonemap lineal. Las bandas de noche solo afectan al sol/la luna (antorchas y hechizos siempre suaves).
  - **Ciclo de día y noche** (`DayNightCycle`, nodo `DayNight` del mundo): el sol sale por el este y se pone por el
    oeste (las sombras giran), de noche la luna con luz fría y las antorchas del grupo `night_lights` encendidas.
    Colores y fuerzas por hora en degradados y curvas del inspector (amanecer/atardecer cálidos). `light_scale`
    calibra la luz de Godot con la del Look Lab. La hora la lleva el host y se sincroniza cada 2 s.
  - **Menú de Esc** (`src/ui/options_menu.tscn`): hora del día (amanecer, mediodía, atardecer, noche, parar el
    tiempo), fuerza de sol/luna/ambiente/antorchas, bandas de noche y filtros de imagen, en directo. "Copiar ajustes"
    copia los valores para pegárselos a Claude.
  - Cámara `FollowCamera3D` **ortográfica isométrica** estilo Diablo (giro 45°, 30° desde el suelo = líneas 2:1),
    zoom con + / - (`size` = alto visible en metros). Se pega a la rejilla de píxeles
    (`pixel_snap`) y le pasa a `PixelView` el resto (`snap_offset`) para un scroll suave.
  - **Interpolación de física** activada en el proyecto: lo que se mueve en
    `_physics_process` se dibuja suave aunque la pantalla vaya a 120 Hz. La cámara lee
    `get_global_transform_interpolated()` y tiene la interpolación apagada (se mueve en `_process`).
- **Mundo generado** (diseño en `docs/GDD.md` §2; forma probada en el World Lab,
  https://claude.ai/artifact/N2H9aTAHKYeqoNqyyE3R6k):
  - `WorldGenerator` saca de la **semilla** el mapa grande (`WorldMap`: celdas de ~35 m con bioma, montaña, camino,
    zona de dificultad y sitios), con las reglas de `WorldSettings` (`src/world/gen/normal/normal_world.tres`). Tarda
    menos de 1 s y se guarda en `user://worlds` (si cambias el algoritmo, sube `WorldGenerator.VERSION`).
  - `WorldStreamer` (nodo `Land` de `game_3d.tscn`) monta el mundo por **trozos de 32 m** alrededor de los jugadores:
    terreno facetado con el color de cada bioma (colores por vértice, `use_vertex_color` en world_lit), montañas con
    laderas que no se pueden subir, colisión `HeightMapShape3D` y la decoración de cada bioma en MultiMesh.
  - Todo lo que se ve se edita en los recursos: `BiomeData` (peso, clima, colores del suelo, decoración) y
    `DecorationData` (modelo, densidad, manchas, escala, si bloquea el paso). La decoración de ahora es de prueba (el
    pack del bosque) hasta que el dueño elija assets para desierto, nieve, jungla y montaña.
  - En red no se manda el mapa: todos los peers lo generan con la misma semilla (`Land.world_seed`).
  - El inicio (la base) está en el origen y llano (`base_radius`). Lo que tapa al jugador (montañas) se recorta
    alrededor de él (`occlusion_cutout` en world_lit; la cámara pone `occlusion_point`).
  - Tecla **M**: mapa de prueba con biomas, montañas, caminos, sitios y jugadores (`src/ui/world_map_view.gd`).
- **Personaje** = `Avatar3D` (`src/characters/hero/hero.tscn`): la Universal Animation Library de Quaternius
  (`UAL1_Standard.glb`: esqueleto + animaciones; su maniquí va oculto) **retargeteada** al humanoide de Godot
  (`assets/models/retarget/`). Lo que lleva puesto es equipo de serie (`default_items`): `BODY` (cuerpo en ropa
  interior de Universal Base Characters), `FACE` (ojos y cejas), `HAIR` y `BEARD`. Las animaciones de armas vienen de
  KayKit (`KayKit_Animations.glb`, retargeteado igual) vía `extra_animation_sources`; `clip_aliases` cambia la
  carrera/esquiva/golpe por las de Quaternius. Las armas se pegan a `HandR/GripR` y `HandL/GripL` (se colocan a mano
  en el editor). Cuando lleve ropa encima, el cuerpo debe usar `body_male_covered_material.tres` (solo dibuja cuello
  y cabeza) para que no asome por la ropa.
- **Jugador** = `Player3D`: el dueño simula; por `Sync` viajan posición, `yaw`, `net_anim` ("clip#contador#velocidad"),
  `charging`, el hueco elegido (`slot_index`) y la vida. Barra de 8 huecos (`hotbar`, teclas 1-8); hueco vacío =
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
- **Hechizos**: `Player3D.spells` (lista de `Spell3DData`); **girar la rueda** cambia de hechizo (`spell_index`, el HUD
  lo enseña encima de la barra) y el **clic de la rueda** lo lanza. Cada `.tres` (`fireball`, `fire_bolt`, `lightning_ball`,
  `lightning_bolt`) dice maná, enfriamiento, daño y su `cast` (un Attack3D con el proyectil). Los proyectiles con
  `explosion_scene` explotan (`Explosion3D`: daño en área, solo en el dueño). Los de prueba usan los efectos de
  BinbunVFX (`assets/vfx/binbun`) metidos dentro de nuestras escenas (`src/combat/projectiles`, `src/combat/fx`).
- **Aura de la esquiva**: `Player3D.dash_fx` (`src/combat/fx/dash_aura.tscn`, un `AuraFX`: efecto encima + tinte del
  cuerpo un rato). Sale en todos los peers por la RPC `_spawn_dash_fx`.
- En red, los ataques se identifican por clave (`combo0`, `heavy`, `alt`, `alt_hold`, `air`, `spell0`..`spellN`, `.../land`):
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

## Rendimiento (el juego tendrá cientos de entidades)

- **Entidades quietas no gastan**: apaga `_physics_process`/`_process` cuando no hacen nada y enciéndelos al
  despertar (ver `TrainingDummy3D._sleep`). Textos y cosas que no cambian a cada frame: refrescar unas pocas veces
  por segundo.
- **Decoración estática** dentro de un nodo con `StaticBatcher` (`Nature`, `Ground`, `Mountains`): al empezar se
  juntan en MultiMesh por zonas (pocas llamadas de dibujo). El suelo no proyecta sombra.
- **Mallas primitivas** (esferas, cápsulas...) siempre con pocos segmentos: las de Godot por defecto tienen miles
  de triángulos.
- Pasadas extra de material (`material_overlay`, `next_pass`) solo mientras hacen falta.
- **Efectos nuevos** (proyectiles, explosiones...): añádelos a `ShaderWarmup` en `game_3d.tscn` para que su shader
  se compile al cargar y no dé un tirón la primera vez.
- Medir: `godot --headless --path . --fixed-fps 60 res://tests/perf_test.tscn -- --entities=300` (tiempo real de
  CPU por frame) y con render (sin `--headless`) para ver llamadas de dibujo y triángulos.

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
