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

## Hito 1: Sensación de combate (siguiente)

- [ ] Ajustar a mano tiempos y poses de cada arma en el editor según feedback de juego
- [ ] Sonidos placeholder (golpe, swing, salto, aterrizaje)
- [ ] Trails de arma (Line2D) y partículas de impacto por tipo de arma
- [ ] Buffer de input más fino y ventana de cancelación configurable por animación
- [ ] Saltar por encima de obstáculos bajos (capa "low_obstacles" que se ignora en el aire)
- [ ] Al morir, soltar el saco de materiales con temporizador (ahora solo reapareces)
- [ ] Mando: apuntado con stick (ya existe `Player.aim_target_override`)
- [ ] Repasar a mano los sprites de perfil y 3/4 (generados a partir del frente y la espalda)
- [ ] Vistas 3/4 y perfil para los mobs
- [ ] Animación de desenfundar/enfundar (ahora es instantáneo)

## Hito 2: Enemigos y progresión

- [ ] Vistas de espalda/lado de los mobs (ahora siempre de frente, volteados)
- [ ] Pathfinding (NavigationAgent2D) cuando haya paredes de verdad
- [ ] XP y subida de nivel
- [ ] Primer boss

## Hito 3: Mundo

- [ ] Generación por semilla con `FastNoiseLite` + `TileMapLayer` por chunks
- [ ] Bioma bosque + cueva
- [ ] Punto de spawn (cofre infinito, hamaca) y área de estaciones
- [ ] Vetas de distintos minerales por bioma (ahora solo cobre)
- [ ] Profesiones con nivel (más rápido / mejor botín al subir)

## Coop (mejoras)

- [ ] Suavizado de la posición de los jugadores/mobs remotos (interpolación) para conexiones con lag
- [ ] Nombre de jugador y lista de conectados en el HUD
- [ ] Pesca: que los demás vean la boya y la captura (ahora solo ven la pose)
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
