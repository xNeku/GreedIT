# GreedIT: Documento de diseño (GDD)

> Documento vivo. Lo que está aquí es la intención de diseño, no lo implementado.
> Para lo implementado y lo pendiente, mira `BACKLOG.md`.

## 1. Concepto

**Terraria + Path of Exile**, vista desde arriba, en pixel art (estética entre Terraria y Stoneshard).
Sin historia aparente: farmear, forjarte una build bestia y superar a los bosses que tocan.
Coop de **2 a 4 jugadores**: tus colegas se unen a tu mundo.

Pilares:
1. **Combate hack & slash con armas, no con hechizos.** Clic izquierdo, clic derecho, pulsar o mantener, y salto.
2. **Build = arma + maestría + talentos + forja + brebajes.**
3. **Progresión larga por bosses**: cada boss desbloquea materiales, equipo y eventos.
4. **Profesiones que se fusionan**: minería, pesca, alquimia y cocina alimentan la forja y los brebajes.

## 2. Mundo

- Mapa **continuo** tipo Terraria pero top-down, generado por **semilla**, cargado por chunks.
- No hay base libre: hay **puntos de spawn** (cofre infinito + hamaca entre dos árboles). Las estaciones
  (mesa de trabajo, yunque...) solo se colocan en el área pequeña de esos puntos.
- Tres capas, cada una un mapa continuo propio:
  1. **Overworld**: biomas de nieve, desierto, bosque y montaña, con cuevas y dungeons. Los bosses van
     cambiando qué minerales aparecen y qué eventos ocurren. Tras el último boss se abre un **pozo-portal** al infierno.
  2. **Infierno**: vacío, lleno de bestias, dungeons y bosses. Pura guerra, pocas zonas tranquilas, recursos propios.
  3. **Cielo**: tras el infierno, un evento trae una legión de ángeles; al matarlos aparece un **haz de luz** que te sube.
     Zona limpia y bonita, catedrales como dungeons, ángeles y clérigos como enemigos.

## 3. Combate

### Controles
- Clic izquierdo: **pulsar** = combo; **mantener** = depende del arma (cargar ataque fuerte o ráfaga continua).
- Clic derecho: ataque especial del arma.
- **Salto** (marca de la casa, inspirado en Conquer Online): saltas hacia el cursor en un arco. En el aire pasas por
  encima de enemigos. Atacar en el aire = ataque aéreo + caída en picado con impacto al aterrizar.
- **Dash**: lo darán objetos (de momento viene de serie para probar).
- **Magia**: clic de la rueda lanza el hechizo equipado (de momento, bola de fuego) gastando maná.
  Los hechizos se ampliarán con la rama de Magia de los talentos.
- Aparte de eso no hay habilidades activas: todo sale de las armas y lo que las modifica.

### Armas (diseño del dueño)
Familias: **daga, maza, espada, vara (bō), arco, armas de fuego, puños y escudo**. Cada una tendrá evoluciones y
variantes, y algunas se podrán combinar.
- **Se usan por manos y por clic**:
  - Dos armas distintas (p. ej. daga + escudo): cada clic usa el arma de su mano.
  - Un arma sola o dos del mismo tipo: el clic izquierdo **alterna** los ataques (izquierda/derecha) y el
    **clic derecho es un especial propio** de ese arma.
- **No hacen falta atributos para llevar un arma**: cualquiera lleva lo que le dé la gana.
- **Maestría por arma**: al usarla ganas maestría, que desbloquea cosas dentro de esa arma y te deja escoger en
  **su propia rama**. Ejemplos:
  - Daga: lanzarla, dashear con los golpes, velocidad de ataque, desangrar.
  - Maza: knockups y aturdimientos, cargar golpes de mucho daño.

### Magia (diseño del dueño)
- Independiente de las armas: un **complemento para cualquier arma** (imbuir el arma, atacar...).
- Cuanto más usas un hechizo, más mejoras con él.
- Los hechizos se aprenden con **pergaminos** que sueltan los enemigos. Habrá muchos, con **elementos y
  combinaciones**.
- Solo yendo por la rama de Magia del personaje podrás llevar más de un hechizo a la vez y combinar sus efectos.

## 4. Progresión (diseño del dueño)

El juego gira alrededor de **construir tu personaje**: cualquier rama que cojas tiene que ser viable, o al menos
divertida. **Buscar combos únicos es lo que hará destacar el juego.** 100 niveles: tiene que costar encontrar dos
builds iguales.

- **Personaje**: cuanto más matas, más XP. Cada nivel da **1 punto en la línea de Legado** (tu genética / talentos).
  No hay clases: son **atributos combinatorios**.
- **Árbol de Legado** estilo talentos del WoW: **4 ramas conectadas entre sí** (p. ej. un nodo pide haber avanzado en
  Fuerza y Agilidad). Atributos base, modificadores del gameplay, nuevas posibilidades y combos. No tienes que ir
  por una sola rama: hay que ir variando.
  - **Fuerza**: knockbacks, bufos, romper armaduras, resistencias, tenacidad, provocar.
  - **Agilidad / Destreza**: velocidad de ataque, movimiento, crítico, dual wield, *triple wield* (dejas la magia y
    llevas un arma en la boca).
  - **Vida**: regeneración, más vida, curas, espinas, más aguante (energía).
  - **Magia**: más maná, crítico mágico, velocidad de lanzamiento, probabilidad de multiplicar (que salga más de un
    hechizo), en cadena, tamaño...
- **Maestría de armas** (por arma, ver Combate) y **mejora de hechizos por uso** van aparte del nivel.
- **Escalado por progreso del mundo** (bosses derrotados, capa actual), **no** por el nivel del jugador.
- Largo, pero el bucle de 30 segundos (pegar, lootear, picar) tiene que molar por sí solo.

### Cómo se monta por dentro (notas técnicas)
- **Estadísticas centrales** del jugador (vida, daño, velocidad de ataque, crítico, maná...) con modificadores que se
  suman de todas partes: Legado, maestrías, equipo, hechizos y efectos temporales.
- **Nodos de árbol = recursos editables** (`.tres`): estadísticas, cambios de ataques (p. ej. el clic derecho de la
  daga pasa a lanzarla) y efectos que escuchan eventos (`hit_landed`, al esquivar, al cambiar de arma...).
  Así los combos salen de juntar piezas sueltas, no de programar cada build.
- Golpes con **etiquetas** (`HitData.tags`: fuego, sangrado, aturdir...) para que elementos y efectos combinen.
- En coop cada jugador calcula sus propias estadísticas (manda sobre su personaje); el golpe ya viaja con el daño final.

## 5. Profesiones, forja y brebajes

- Minería, pesca, alquimia y cocina.
- **Forja**: los materiales que usas deciden los **modificadores (afijos)** del arma o armadura.
  El crafteo ES el sistema de afijos.
- **Brebajes**: cada ingrediente tiene propiedades según su bioma (ardiente, vital, volátil, helado...).
  Combinarlas da efectos. Cocina = buffs largos, alquimia = buffs cortos y fuertes.

## 6. Muerte

- Al morir sueltas los **materiales de profesión** en un saco donde caíste. Tienes X minutos para recuperarlo.
- Equipo, XP y maestría no se pierden nunca.
- En coop, un compañero puede recoger tu saco y devolvértelo.

## 7. Personaje y estética

- Personaje por capas (piel, ojos, pelo, ropa, botas, manos flotantes) para personalización y armaduras visibles.
- Manos separadas del cuerpo (estilo "rayman"): las mueve el arma, lo que facilita animar.
- Iluminación 2D con sombras: mazmorras oscuras, antorchas y braseros.

## 8. Técnica

- Godot 4.7, GDScript tipado, renderer Compatibility.
- Multijugador host-cliente (ENet), **hecho desde la base**: cada jugador manda sobre su personaje y el host sobre
  el mundo y los mobs. Ver la sección "Red" de `AGENTS.md`.
- Personajes en 8 direcciones (5 vistas + volteo), estilo Diablo / Path of Exile.
- Todo en escenas y recursos editables. Ver `AGENTS.md`.
