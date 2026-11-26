# Backlog

Leyenda: `[ ]` pendiente · `[~]` en curso (pon tu nombre) · `[x]` hecho

## Hito 0: Sandbox de combate (hecho)

- [x] Proyecto Godot 4.7 pixel-perfect (960x540, nearest, snap a píxel)
- [x] Personaje por capas a partir del arte original (chico y chica), manos separadas
- [x] Movimiento con inercia, dash, salto hacia el cursor (estilo Conquer) con sombra
- [x] Sistema de armas: combo al pulsar, carga o ráfaga al mantener, clic derecho, ataque aéreo + caída en picado
- [x] Puños, espada, daga (lanzable), maza, arco (disparo cargado que perfora, triple, lluvia aérea)
- [x] Hitbox / Hurtbox / HitData + bus `Events` (base para talentos y afijos)
- [x] Muñeco de entrenamiento: tambaleo de muelle, flash, paja, números de daño, DPS
- [x] Hitstop, vibración de cámara, cámara que se adelanta al ratón
- [x] Sandbox con luces, sombras (columnas), braseros con fuego y hotbar 1-5
- [x] Test de humo headless (`tests/smoke_test.tscn`)

## Hito 0.2: Sensación y profesiones (hecho)

- [x] Manos siempre derechas (antes rotaban con el arma) y reposo a los costados como en el dibujo
- [x] El personaje mira hacia donde corre; al atacar se gira al ratón
- [x] Andar más vivo: pisadas con polvo, inclinación, cabeza con retardo, giros más secos
- [x] Salto hacia donde corres, con anticipación (se agacha), piernas encogidas en la cima y aterrizaje con squash
- [x] Armas más curradas: estelas, partículas de carga, estocadas con destello, chispas al golpear, más desplazamiento
- [x] Maza: mantener clic derecho = salto aplastante hacia el cursor
- [x] Arco: clic derecho = salto atrás con triple disparo
- [x] Nueva arma: vara bō (alcance largo, molinillo, remolino, salto con pértiga)
- [x] Recolección infinita con tecla E: minería (pico), herboristería (hoz) y pesca (caña con minijuego)
- [x] Inventario de materiales + panel en el HUD + texto "+1 ..." al recoger

## Hito 0.3: Sprite más vivo y magia (hecho)

- [x] Vistas del personaje: frente, lado (3/4 con ojos y pelo girados) y espalda (pelo, nuca y espalda nuevos)
- [x] Zancada al andar de lado, parpadeo y respiración en reposo
- [x] Maná con regeneración + barra en el HUD
- [x] Bola de fuego con clic de la rueda: gesto de la mano libre, proyectil con luz y estela, explosión en área

## Hito 0.4: Primeros mobs (hecho)

- [x] Goblin (rápido, embiste), esqueleto (guarda distancia y lanza huesos) y zombi (lento, aguanta, aplasta en área)
- [x] IA por estados con aviso antes de atacar, aturdimiento, knockback, barra de vida y muerte
- [x] Botín directo al inventario (oreja de goblin, hueso, carne podrida) y reaparición con `MobSpawner`
- [x] Vida del jugador: hurtbox, invulnerabilidad tras golpe, esquivar saltando o con dash, regeneración, muerte y reaparición

## Hito 0.5: Armas a la espalda y 8 direcciones (hecho)

- [x] Arma guardada a la espalda cuando no se usa; se desenfunda al atacar/lanzar y se guarda sola
- [x] Manos libres con balanceo al andar y brazos arriba al saltar
- [x] 5 vistas (8 direcciones con el volteo): frente, diagonal abajo, lado, diagonal arriba, espalda
- [x] Empuñadura real: mano debajo del mango y dedos encima (de espaldas, al revés)

## Hito 0.6: Coop y base de movimiento (hecho)

- [x] Coop de 2 a 4 jugadores: menú (solo / crear partida / unirse por IP), red ENet
- [x] Todo el juego preparado para red: jugadores, armas, hechizos, mobs, muñecos, botín, recolección
- [x] Test de red automático (host + cliente en dos procesos)
- [x] Sprites en 8 direcciones estilo Diablo/PoE: 3/4 de frente, perfil y 3/4 de espaldas dibujados
- [x] Movimiento más rápido y con respuesta inmediata; carrera con zancada, inclinación y brazos;
      arrancar, frenar y girar con peso

## Decisión: personaje 2D o 3D (hecho → 3D real)

- [x] Prototipo A: personaje 3D (vóxeles generados desde los sprites) horneado a sprites en 8 direcciones
- [x] Prototipo B: el mismo personaje en un mundo 3D real (giro libre, luces y sombras 3D)
- [x] Elegido: **3D en tiempo real** (estilo "HD" con modelos de Blender), para que el arte lo pueda hacer el
      dueño del proyecto en Blender y los equipos/armaduras encajen solos en cualquier animación

## Hito 3D.0: Base del juego en 3D (hecho)

- [x] Modelos de muestra CC0 (KayKit Adventurers y Dungeon) en `assets/models/`, hasta tener los propios
- [x] `Avatar3D`: personaje con esqueleto + AnimationPlayer; 4 personajes (caballero, bárbaro, maga, pícara)
- [x] Equipo por ranuras (`EquipmentData`): armas pegadas a los huesos de la mano, casco/capa de serie,
      escudo, y **armadura con esqueleto** que se viste sobre cualquier personaje (`skinned`)
- [x] `Player3D`: movimiento con inercia, giro hacia donde corre, salto, esquiva con invulnerabilidad
- [x] 7 armas (`Weapon3DData`): puños, espada y escudo, mandoble (giro), hacha (remolino), dagas dobles,
      ballesta (abanico de virotes) y bastón (proyectil mágico + nova)
- [x] Hitbox3D / Hurtbox3D / Projectile3D con las mismas reglas de red que el 2D
- [x] Muñeco 3D (tambaleo, destello, paja, números de daño, DPS)
- [x] Mazmorra de prueba con antorchas, sombras, niebla, glow; cámara en diagonal que sigue al jugador
- [x] Coop desde el principio: test de humo 3D y test de red 3D (host + cliente)
- [x] Menú: elegir mundo 3D (nuevo) o 2D pixel art, y personaje

## Hito 3D.0b: Estilo pixel art (hecho)

- [x] Mundo a baja resolución con escalado entero, cámara ortográfica pegada a la rejilla de píxeles
- [x] Luz por bandas (toon), texturas nearest y contorno de 1 px en todos los modelos (script de importación)
- [x] Filtro final: paleta reducida, tramado, tinte de sombras (`pixel_post_material.tres`)
- [x] Cabeza más pequeña en los personajes de muestra (`BoneScaleModifier`)

## Hito 3D.0c: Combate del 2D en 3D, movimiento y cámara (hecho)

- [x] Ataques por datos (`Attack3D`): combo con avance, carga (mantener), ráfaga, clic derecho, mantener clic
      derecho (salto aplastante), ataque aéreo con caída en picado y golpe al aterrizar, salto atrás con abanico
- [x] Bola de fuego con maná (clic de la rueda), explosión en área; barra de maná y chuleta del arma en el HUD
- [x] Movimiento más directo, relativo a la cámara; salto estilo Conquer con agachada, aterrizaje y polvo
- [x] Interpolación de física (adiós a los tirones); menos luces con sombra; sin luz que sigue al jugador
- [x] Cámara isométrica estilo Diablo (Tab para comparar con la diagonal), más lejos y con zoom (+ / -)
- [x] Menos granulado: mundo a 960x540, sin tramado ni paleta reducida

## Hito 3D.0d: Personajes con proporciones de adulto (hecho)

- [x] Packs CC0 de Quaternius: ropa modular (explorador y campesino) + Universal Animation Library
- [x] Retarget al humanoide de Godot: las animaciones de armas de KayKit valen para el esqueleto de Quaternius
- [x] Ropa y capucha como equipo de serie (OUTFIT / HEAD), armas en un agarre colocable a mano (GripR / GripL)
- [x] Sin normal maps ni brillos al importar (luz por bandas limpia) y contorno más fino

## Hito 3D.1: Limpieza (hecho)

- [x] Fuera el sandbox 2D, los prototipos, el horneador de sprites, los personajes cabezones y la mazmorra
      (siguen en el historial de git si hace falta recuperar algo: enemigos 2D, recolección, etc.)
- [x] Un solo personaje (cuerpo base en ropa interior), cámara solo isométrica, menú simplificado
- [x] HUD: orbe de vida estilo Diablo + barra de 8 huecos con iconos (hueco vacío = puños)
- [x] Bō (bastón largo para pegar) en vez del bastón mágico; ataques en el aire sin caída en picado
- [x] Muñecos con saltito al recibir golpes (knockup); muerte y reaparición del jugador
- [x] Rendimiento: hitboxes apagadas cuando no golpean, sin luces con sombra de más, interpolación en el proyecto

## Hito 3D.2: Look y mundo de inicio (hecho)

- [x] Look Lab (artefacto) para elegir luz, sombreado, imagen y color de día y de noche
- [x] Look elegido en el juego: luz suave de día, por bandas de noche, sin contorno, filtro de color y viñeta
- [x] Ciclo de día y noche con el sol y la luna moviéndose (sombras que giran), antorchas de noche
- [x] Mundo más amplio con el pack de entorno: bosquecillos, rocas, troncos, montañas en el borde
- [x] Zona de salida con 4 muñecos y 4 antorchas

## Hito 3D.3: Luces, menú y rendimiento (hecho)

- [x] Sol dinámico con colores por hora (amanecer y atardecer cálidos), noche más clara
- [x] Bandas de noche solo en el sol/la luna: antorchas y hechizos con luz suave
- [x] Menú de Esc con hora del día, luces e imagen en directo
- [x] Rendimiento: entidades que duermen, decoración agrupada (MultiMesh), suelo sin sombras, mallas low poly,
      precalentado de shaders, test de rendimiento (`tests/perf_test.tscn`)

## Siguiente

- [ ] Pantalla de créditos en el juego (el pack de entorno es CC BY 4.0: hay que citar a k0rveen)
- [ ] Reloj o indicador de la hora (si el dueño lo quiere)
- [ ] Ajustar a mano el agarre de cada arma (GripR) y animaciones propias
- [ ] Números de daño en el HUD (nítidos) en vez de Label3D pixelado
- [ ] Personaje propio hecho en Blender (mismo esqueleto, ver AGENTS.md)
- [ ] Enemigos 3D (la IA del 2D está en el historial: enemy.gd)
- [ ] Recolección 3D (minería, herboristería, pesca) e inventario
- [ ] Armas a la espalda cuando no se usan
- [ ] Giros de área que golpeen varias veces (ahora una vez por ataque)
- [ ] Estelas de arma y sonidos
- [ ] Mando: apuntado con stick (ya existe `Player3D.aim_target_override`)

## Hito 2: Enemigos y progresión

- [ ] Pathfinding (NavigationAgent3D) cuando haya obstáculos de verdad
- [ ] XP y subida de nivel
- [ ] Primer boss

## Hito 3: Mundo

- [ ] Generación por semilla con `FastNoiseLite` por chunks
- [ ] Bioma bosque + cueva
- [ ] Punto de spawn (cofre infinito, hamaca) y área de estaciones
- [ ] Vetas de distintos minerales por bioma (ahora solo cobre)
- [ ] Profesiones con nivel (más rápido / mejor botín al subir)

## Coop (mejoras)

- [ ] Suavizado de la posición de los jugadores/mobs remotos (interpolación) para conexiones con lag
- [ ] Nombre de jugador y lista de conectados en el HUD
- [ ] Chunks del mundo cargados por jugador (cuando exista el mundo generado)

## Magia (siguiente)

- [ ] Más hechizos (rayo, escarcha, curación...) y un hueco de hechizo seleccionable
- [ ] Estados elementales (quemado, congelado...) a través de `HitData.tags`
- [ ] Rama de Magia del árbol de talentos que modifique los hechizos

## Sistemas de build (diseño pendiente)

- [ ] Maestría por familia de arma (puntos al usarla)
- [ ] Árbol de talentos (Vida / Destreza / Daño / Magia) + talentos clave
- [ ] Peso de armas vs fuerza (penalización suave)
- [ ] Dual wield
- [ ] Agarre a dos manos para armas pesadas (ahora todas van a una mano; la mano libre flota)
- [ ] Forja: materiales → afijos
- [ ] Brebajes: ingredientes con propiedades por bioma

## Arte

- [ ] Paleta de piel/pelo intercambiable por shader (en vez de `self_modulate`)
- [ ] Vistas de espalda y perfil del personaje (ahora solo hay frontal)
- [ ] Sprites de armas definitivos y más armas (hacha, lanza, bastón)
- [ ] Fuente pixel para la UI y los números de daño
- [ ] Tileset de suelo y paredes de mazmorra
