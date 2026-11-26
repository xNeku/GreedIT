# AGENTS.md: reglas del proyecto GreedIT

Este archivo lo leen **todas** las IAs que trabajan en el repo (Claude Code, Codex...) y también las personas.
Si cambias una convención, actualiza este archivo en el mismo commit.

## Contexto

- Motor: **Godot 4.7**, GDScript con tipado estático, renderer *Compatibility* (OpenGL).
- Juego: ARPG coop top-down pixel art. Diseño en `docs/GDD.md`, tareas en `docs/BACKLOG.md`.
- Idioma: comentarios, docs y textos del juego en **español**. Identificadores de código en **inglés**.

## Regla de oro: escenas y nodos reales

- Todo lo que se pueda ver o tocar en el editor **es una escena (`.tscn`) o un recurso (`.tres`)**.
  Nada de construir árboles de nodos, animaciones o UI por código en `_ready()`.
- El código **instancia** escenas (`PackedScene.instantiate()`), no las fabrica.
- Las animaciones viven en `AnimationPlayer` dentro de la escena. Los números de balance viven en recursos (`WeaponData`...).
- Objetivo: que el dueño del proyecto pueda abrir cualquier escena en el editor y retocarla sin tocar código.

## Estructura

```
assets/                 arte, luces, audio (solo datos, sin lógica)
  sprites/characters/   capas del personaje: male/, female/ (lienzo común 52x70)
  sprites/weapons|props|fx|ui|world/
  lights/               texturas de luz compartidas
src/
  autoload/             Events (bus de señales), GameFeel (hitstop, pantalla completa), Net (solo / host / unirse)
  combat/               HitData, Hitbox, Hurtbox, DamageNumber, shader de flash
  items/                ItemData, WeaponData (recursos de datos)
  characters/           CharacterVisual (cuerpo por capas), CharacterAppearance + CharacterLayers (.tres), HandUtils
  player/               Player, PlayerCamera
  weapons/              weapon.gd (base), projectile.gd, weapon_trail.gd, una carpeta por arma (.tscn + .tres)
  gathering/            Gatherable (recurso infinito), GatherTool / FishingRod, tools/, resources/
  spells/               SpellData, SpellExplosion, una carpeta por hechizo (fireball/: proyectil, explosión, .tres)
  items/materials/      materiales (.tres de ItemData)
  enemies/              Enemy (IA base), EnemyProjectile, MobSpawner, una carpeta por mob (goblin/, skeleton/, zombie/)
                        y training_dummy/
  world/                Game (arranca la red y crea jugadores), escenas de mundo/niveles y props
  ui/                   menú principal, HUD, hotbar, panel de materiales, cartel "E", textos flotantes
tests/                  test de humo (un jugador) y test de red (host + cliente), en headless
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
   (`Weapon.deal_hit` y `SpellExplosion` ya comprueban que el jugador sea local; los ataques de mobs, que seas el host).
4. **Efectos para todos**: quien aplica el golpe avisa con una RPC `@rpc("authority", "call_local")`
   (p. ej. `Enemy._show_hit`, `TrainingDummy._show_hit`) que pinta números, destellos y partículas en todos.
5. **Estado continuo** (posición, vida, animación...) → nodo `Sync` (`MultiplayerSynchronizer`) de la escena.
   **Momentos puntuales** (saltar, atacar, cambiar de arma...) → RPC. En el jugador: `Player._net_event()` con
   `NetEvent`, y las acciones de arma con `Player.weapon_action()` (la ejecuta aquí y la replica).
6. **Crear cosas en red**: los nodos que deben existir en todos los peers los crea el host y los replica un
   `MultiplayerSpawner` (`PlayerSpawner`, `MobNetSpawner` en `sandbox.tscn`). Añade la escena a su lista y usa
   `add_child(nodo, true)` para que el nombre sea igual en todos. Proyectiles y efectos rápidos no van por spawner:
   cada peer crea su copia (las de los demás son solo visuales, `visual_only`).
7. **Botín**: el host decide y se lo manda al dueño: `player.receive_item.rpc_id(player.get_multiplayer_authority(), ruta, n)`.
8. Lo local de cada jugador (inventario, maná, recolección, prompts, HUD, cámara) vive en su ordenador.

Flujo: `main_menu` → `Net.play(modo)` → carga `sandbox.tscn` → `Game._ready()` llama a `Net.start()` y crea los
jugadores (`_spawn_player` corre en todos los peers y pone el dueño). Un cliente pide su jugador con `_request_spawn`.

## Capas de física (2D)

| # | Nombre | Quién la usa |
|---|---|---|
| 1 | world | paredes, columnas, props sólidos |
| 2 | player | cuerpo del jugador |
| 3 | enemies | cuerpo de enemigos / muñecos |
| 4 | player_attacks | Hitbox y proyectiles del jugador |
| 5 | enemy_hurtbox | Hurtbox de enemigos |
| 6 | player_hurtbox | Hurtbox del jugador |
| 7 | enemy_attacks | Hitbox y proyectiles de los enemigos |
| 8 | interactables | InteractArea de recursos y objetos con los que se usa la E |

Capa de render 2 (`no_shadow`): sprites altos (columnas, braseros) que reciben luz pero no se oscurecen con su propia sombra.

Materiales compartidos en `assets/materials/`: `unshaded.tres` (ignora la oscuridad, para UI en el mundo) y
`unshaded_add.tres` (aditivo y sin sombrear, para estelas, chispas y destellos).

## Cómo funciona el combate

1. `Player` recibe el input y se lo pasa al arma equipada (`primary_pressed`, `secondary_pressed`...).
2. `Weapon` (base) decide qué animación toca: pulsar = combo `light_N`; mantener = `charge`→`heavy` o ráfaga;
   clic derecho = `alt`; mantener clic derecho = `alt_charge`→`alt_heavy` (si `alt_hold_enabled`);
   en el aire = `air` (+ caída en picado) → `slam` al aterrizar; tras `leap_attack()` → `leap_land`.
3. La animación enciende `Hitbox.active` en los frames de golpe y puede llamar a `lunge()`, `shake()`,
   `spawn_projectile()` o `leap_attack()` (salto de ataque: maza, pértiga del bō, salto atrás del arco).
4. `Hitbox` detecta un `Hurtbox` → `Weapon.deal_hit()` crea un `HitData` (daño, crítico, empuje) → `Hurtbox.hit_received`.
5. Cada golpe se emite también por `Events.hit_landed`. Ahí se engancharán talentos, afijos de forja y brebajes.

### Poses y manos

- Las poses se animan en el **espacio del arma**: +X = hacia donde apuntas. El `AimPivot` del jugador rota y se espeja solo.
- **Enfundada / desenfundada**: si no la usas, el arma va **a la espalda** (`CharacterVisual/.../BackWeapon`,
  con los datos `back_*` del `WeaponData`) y se ven las **manos libres** del cuerpo (`HandL`/`HandR`, que se
  balancean al andar). Al atacar o lanzar se desenfunda; tras `Player.sheathe_delay` segundos sin usarla se guarda.
  De frente el arma de la espalda va detrás del cuerpo (solo asoma); de espaldas va encima.
- Desenfundada, en reposo (`idle`) el arma va **a un costado** y mira hacia donde mira el personaje (que mira hacia
  donde corre). Al atacar, el personaje se gira hacia el ratón. Manos en reposo: `HandMain` (18, 2) y `HandOff` (-19, 2).
- **Empuñadura**: dentro de `Rig`, el orden es `HandMain` → sprite del arma → `GripFingers` (dedos que rodean el mango).
  Así el mango tapa el puño y los dedos tapan el mango. De espaldas (`HandUtils.set_grip_back_view`) la mano pasa
  por encima del arma y los dedos se ocultan. Las herramientas siguen el mismo esquema.
- Las manos (`HandMain` / `HandOff`) **nunca rotan**: `HandUtils.keep_upright()` las endereza cada frame.
  Anima solo su posición (y escala si quieres un puñetazo más gordo).
- De momento todas las armas van a **una mano**; la otra flota libre (el arco la usa para tensar la cuerda).
- Extras opcionales en la escena: `Trail` (estela, se enciende con `Trail:emitting`), `ChargeParticles`,
  `SlashFX`, `ThrustFX`, `ImpactFX`. Todos se encienden desde las animaciones.

### Añadir un arma nueva

1. Duplica la carpeta de un arma parecida (p. ej. `src/weapons/sword/`).
2. En la escena: cambia el sprite, coloca las manos (`HandMain` / `HandOff`), ajusta los Hitbox y sus multiplicadores.
3. Edita las animaciones con los nombres estándar (ver cabecera de `weapon.gd`). Las que no existan simplemente no se usan.
4. En el `.tres`: daño, críticos, modo de mantener (CHARGE o REPEAT), apunta `weapon_scene` a tu escena.
5. Añade el `.tres` a la `hotbar` del jugador (inspector de `src/player/player.tscn`).

### Enemigos

- `enemy.gd` es una IA por estados: IDLE/WANDER (deambula cerca de su sitio) → CHASE (te ve a `detection_radius`)
  → ATTACK (animación `attack`) → HURT (aturdido) → DEAD. Todo se ajusta con `@export` en el inspector.
- Escena de un mob: `Visual/Body` (con `LegL`, `LegR`, `Upper` del sprite troceado y el shader de flash en `Body`),
  `Hurtbox` (capa 5), `AttackPivot/AttackHitbox` (capa 7, apunta al jugador al empezar el ataque),
  `AttackPivot/Muzzle` (opcional, proyectiles), `HealthBar/Fill`, `DeathParticles` y `AnimationPlayer`
  con `idle`, `walk`, `attack`, `hurt` y `die`.
- La animación `attack` tiene un **aviso** (el cuerpo se tiñe y se echa atrás) antes del golpe, para poder esquivar.
  Pistas de método: `attack_lunge()`, `fire_projectile()`, `attack_shake()`.
- `MobSpawner` (Marker2D) mantiene N mobs vivos y los reaparece al morir. Al morir sueltan `drop` directo al inventario.
- El jugador esquiva los golpes saltando alto (`dodge_height`) o en dash, y tras un golpe es invulnerable un momento.
- Para un mob nuevo: trocea su sprite en `upper` / `leg_l` / `leg_r` (mismo lienzo, pies abajo en el centro),
  duplica la escena de uno parecido y cambia texturas, números y la animación `attack`.

### Magia

- Clic de la rueda (`cast_spell`) lanza `Player.spell` (un `SpellData`) gastando maná (`max_mana`, `mana_regen`).
- El arma hace el gesto con la mano libre (animación `cast`, con la llama `HandOff/HandFlame`) y llama a `release_spell()`.
  Si el arma no tiene `cast` (o estás en pleno salto de ataque), el hechizo sale directamente.
- Un hechizo = escena de proyectil (p. ej. `fireball.gd`) + escena de explosión (`SpellExplosion`, daño en área
  con una consulta de física) + `.tres` con los números. Los golpes también se emiten por `Events.hit_landed`.

### Recolección (minería, herboristería, pesca)

- Un recurso es una escena con `gatherable.gd` (`src/gathering/resources/`): sprite, `InteractArea` (capa 8),
  `GatherPoint`, partículas `Chips` y los datos (`drop`, `hits_to_gather`, `tool_scene`, `action_text`). Es **infinito**.
- Al acercarte, el jugador muestra el cartel "E + acción". Al pulsar E saca la herramienta (`tool_scene`) y guarda el arma.
- Herramientas (`src/gathering/tools/`): escena con `gather_tool.gd` y animación `use` en bucle que llama a `tool_hit()`.
  La caña usa `fishing_rod.gd` (lanzar, esperar, ¡pica!, pulsar E a tiempo).
- Moverse, atacar, saltar o cambiar de arma deja de recolectar. Lo recogido va a `Player.inventory` y al panel del HUD.

### Personaje por capas

Las capas del personaje comparten un lienzo de **52x70 px** con los pies abajo en el centro:
`leg_l/r`, `boot_l/r`, `torso`, `cloth_bottom`, `cloth_top`, `head`, `eyes`, `hair`. Las manos (`hand_l/r`) van recortadas
porque flotan y las mueve el arma. Un `CharacterAppearance` (.tres) dice qué textura usa cada capa.
Para un pelo, ropa o armadura nueva: pinta sobre el lienzo de 52x70 y asígnala en un `CharacterAppearance`.

Vistas (`CharacterVisual.View`, estilo Diablo / Path of Exile): **FRONT**, **FRONT_SIDE**, **SIDE**, **BACK_SIDE**
y **BACK** (con el volteo, 8 direcciones). Cada vista tiene su juego de capas (`CharacterLayers`) dentro del
`CharacterAppearance`: frente en `male/*.png`, espalda en `male/*_back.png`, y `male/front_side/`, `male/side/`
(perfil) y `male/back_side/` con todas las capas. Si añades pelo, ropa o armadura, píntalo en las 5 vistas.

Animaciones del cuerpo: `idle`, `run` (frente/espalda), `run_diag`, `run_side` (zancada), `run_start`, `run_stop`,
`turn`, `jump_windup`, `rise`, `peak`, `fall`, `land`, `land_heavy`. La velocidad de la carrera se ajusta sola a la del
personaje. Las manos libres cuelgan de `HandLAnchor`/`HandRAnchor` (su posición por vista está en `hand_rest_l/r`);
las animaciones mueven `HandL`/`HandR` dentro de su ancla.

## Pixel art

- Resolución base **960x540**, filtro *nearest*, snap a píxel activado. No escales sprites por valores no enteros.
- Contorno de 1 px oscuro (`#180E10`), luz desde arriba a la izquierda.
- Los sprites que salen del suelo tienen el origen en los pies (offset negativo en Y) para que funcione el *y-sort*.

## Verificar antes de hacer commit

```bash
godot --headless --path . --import                        # reimporta y muestra errores de scripts/escenas
godot --headless --path . res://tests/smoke_test.tscn      # debe terminar con "SMOKE OK"
```

Si tocas algo de red (o cualquier cosa que se vea en coop), pasa también el test de red (dos copias del juego):

```bash
godot --headless --path . res://tests/net_test.tscn -- --role=host --port=7790 &
godot --headless --path . res://tests/net_test.tscn -- --role=client --port=7790   # "NET CLIENT OK" (y el host "NET HOST OK")
```

Si cambias combate o armas y el test falla, arréglalo o actualiza el test en el mismo commit.

## Git

- Commits pequeños y descriptivos, en español.
- Commitea los `.uid` que genera Godot (van junto a cada script/recurso). No commitees `.godot/`.

## Trabajo entre IAs

- Antes de empezar, lee `docs/BACKLOG.md` y marca en qué estás (`[~]` + tu nombre) para no pisaros.
- Al terminar, márcalo como hecho (`[x]`) y apunta en el backlog lo que hayas dejado pendiente.
