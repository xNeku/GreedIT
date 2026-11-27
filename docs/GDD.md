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

## 2. Mundo (diseño del dueño)

### Tres mundos persistentes
- **Mundo normal, infierno y cielo**: tres mapas grandes, cada uno continuo, generados por **semilla** y
  **persistentes** (creas tu mundo, se guarda y vuelves a él, como Terraria / Valheim).
- Tamaño: cruzar el mundo normal de punta a punta **andando lleva unos 20 minutos** (unos 8 km). Se carga por trozos
  alrededor de cada jugador.
- **Se va a pata.** No hay viaje rápido: más adelante el equipo dará velocidad. La única ayuda: una **piedra que
  suelta el primer boss** que, canalizándola, te devuelve a la base.
- Casi todo el mapa es zona de pelea constante, rollo Diablo 2 / 4. Las **zonas neutrales son muy pocas** y humildes
  (una tienda de campaña y un paisano sentado con el que hablar; ni siquiera un poblado).

### Generación (estilo Diablo 2: estructurada, no "cosas al azar")
1. **Biomas** del mundo normal: bosque y desierto (los más grandes, la base del mapa), jungla, montaña y nieve. Se
   reparten "a lo loco" pero con reglas de tamaño, y los bordes se deforman con ruido.
2. **Montañas** que dividen zonas y obligan a rodear; en ellas hay **puertas a dungeons** y demás.
3. **Sitios** colocados con reglas de distancia: entradas de dungeon, minas, cuevas, portales, campamentos
   neutrales, eventos, élites, guaridas de boss. La dificultad sube al alejarse del inicio.
4. **Detalle**: relieve suave (sin montañitas por todas partes), vegetación por bioma y **estructuras hechas a mano**
   (escenas que diseña el dueño) que el generador coloca. Suelo sencillo pero bonito: buscar recursos de hierba,
   arena, caminos... para Godot.
5. El mismo generador vale para el infierno y el cielo, con sus propios biomas y reglas.
- Técnica: cada jugador genera el mismo mundo a partir de la semilla; por red solo va lo que cambia (bichos, botín,
  cofres, vetas picadas). Prototipo de la forma del mapa en el **World Lab** (artefacto).

### Dungeons, minas y cuevas
- Repartidas por el mapa; hay que **explorar** para encontrarlas. Al entrar hay **pantalla de carga**.
- Plantas autogeneradas con **bastantes pisos y estancias** (salas hechas a mano que el generador encadena).
- Dentro: minar, matar y lootear. Al fondo puede haber un **iniciador de boss**, una **cadena hacia un boss**, un
  **boss**, un **élite** o un **evento de oleadas**.
- **Minería**: vetas que se agotan.
- En la trama principal, las dungeons **se regeneran en cada cambio de dificultad**.

### Trama principal: tres etapas
1. **Pacífica** (comienzo): matas 3-4 bosses principales del mundo normal. Mientras, puedes encontrar la **bajada al
   infierno**: un **pozo de lava escondido** en alguna zona. Para abrirlo hay que superar un reto: matar muchísimos
   bichos que van apareciendo en esa zona. Nada más bajar está casi el primer boss del infierno; **matarlo empieza la
   segunda etapa**.
2. **Infierno**: muchos bosses, exploras los dos mundos. Cada cambio de dificultad saca un par de bosses más en el
   mundo normal, sube la dificultad y cambian los eventos (como en Terraria).
3. **Cielo**: al matar al **boss final del infierno** cambia la dificultad y sale un boss más en el mundo normal, el
   **guardián del cielo**. Al matarlo baja un **haz de luz** del cielo: si te metes, subes. Además, todos los bosses
   del mundo normal que ya existían **vuelven mejorados**.

### Endgame (después del lanzamiento, si el juego triunfa)
- Una **torre por plantas** que se renueva cada semana, la misma para todos los jugadores del mundo, con raids y demás.
- Prioridad ahora: pulir la trama principal.

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
Familias: **daga, maza, espada (y mandoble), hacha, vara (bō), arco, armas de fuego, puños y escudo**. Cada una tendrá evoluciones y
variantes, y algunas se podrán combinar.
- **Se usan por manos y por clic**:
  - Dos armas distintas (p. ej. daga + escudo): cada clic usa el arma de su mano.
  - Un arma sola o dos del mismo tipo: el clic izquierdo **alterna** los ataques (izquierda/derecha) y el
    **clic derecho es un especial propio** de ese arma.
- **No hacen falta atributos para llevar un arma**: cualquiera lleva lo que le dé la gana.
- **Todo empieza a una mano.** Al avanzar se desbloquea llevarla a **dos manos** o llevar **una en cada mano**
  (cada opción cambia el moveset). Algunas armas no lo permiten todo:
  - **Arco**: de una mano al principio; luego dos estilos: **arco gigante** (dos manos) o **arco + daga/hacha**.
  - **Vara**: empieza a una mano y luego se transforma en dos manos (con la vara no llevas nada más).
  - **Maza**: una en cada mano o a dos manos.
  - **Espada**: su evolución es el **mandoble** (espada a dos manos).
  - **Hacha** (familia propia): a dos manos, una en cada mano, o con arco o escudo en la otra.
  - **Escudo**: de una mano (clic = empujar; mantener = posición de defensa) y de dos manos.
- **Maestría por familia**: toda daga suma a "daga". Algunas armas concretas piden una habilidad para cogerlas,
  pero siguen siendo de su familia y dan su maestría.
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
