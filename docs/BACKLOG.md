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

## Hito 1: Sensación de combate (siguiente)

- [ ] Ajustar a mano tiempos y poses de cada arma en el editor según feedback de juego
- [ ] Sonidos placeholder (golpe, swing, salto, aterrizaje)
- [ ] Trails de arma (Line2D) y partículas de impacto por tipo de arma
- [ ] Buffer de input más fino y ventana de cancelación configurable por animación
- [ ] Saltar por encima de obstáculos bajos (capa "low_obstacles" que se ignora en el aire)
- [ ] Hurtbox del jugador + vida + muerte (saco de materiales con temporizador)
- [ ] Mando: apuntado con stick (ya existe `Player.aim_target_override`)
- [ ] Perfil real dibujado a mano (ahora el lado es el frente con ojos y pelo desplazados)

## Hito 2: Primer enemigo de verdad

- [ ] Enemigo básico con IA (perseguir, atacar, retroceder) y vida
- [ ] Knockback real en enemigos (CharacterBody2D)
- [ ] Drop de loot simple
- [ ] XP y subida de nivel

## Hito 3: Mundo

- [ ] Generación por semilla con `FastNoiseLite` + `TileMapLayer` por chunks
- [ ] Bioma bosque + cueva
- [ ] Punto de spawn (cofre infinito, hamaca) y área de estaciones
- [ ] Vetas de distintos minerales por bioma (ahora solo cobre)
- [ ] Profesiones con nivel (más rápido / mejor botín al subir)

## Hito 4: Coop

- [ ] Arquitectura host-cliente (MultiplayerSpawner / MultiplayerSynchronizer)
- [ ] Sincronizar jugador, armas, golpes
- [ ] Chunks cargados por jugador

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
