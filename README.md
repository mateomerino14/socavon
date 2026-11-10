# Socavón

Juego de terror en primera persona ambientado en las minas del Cerro Rico de Potosí. Mateo, un minero de 17 años, queda atrapado en un nivel abandonado y debe sobrevivir al Tío, el señor del subsuelo, que caza por la luz y el sonido.

Primera historia del universo del Manqha Pacha.

## Estado

Prototipo `0.2.0`: los niveles 1, El derrumbe, y 2, Los rieles, se juegan de principio a fin, y el túnel de prueba sirve para ensayar mecánicas con el Tío suelto.

| Hecho | Pendiente |
|---|---|
| Movimiento en primera persona: caminar, correr y agacharse | Grabar las voces del guion |
| Aliento que se gasta al correr | Modelos de Blender |
| Lámpara de carburo con combustible, tres niveles de llama y parpadeo | Niveles 3 a 5 de la mina |
| Pasos que emiten ruido para la futura IA | |
| Túnel gris de prueba y HUD mínimo | |
| Bolsa de objetos: carburo, coca, alcohol, cigarros y piedras | |
| Altar que recibe ofrendas, sube el respeto del Tío y guarda la partida | |
| Piedras que hacen ruido al caer y se pueden volver a recoger | |
| El Tío: patrulla, sospecha, caza, búsqueda y calma; oye los ruidos y ve según la luz | |
| Muerte: si el Tío te alcanza, fundido a negro y reapareces en el último altar | |
| Presentimiento: a menos de 10 m del Tío la llama tiembla y se encoge | |
| Menú de pausa con sensibilidad del ratón, volumen y agacharse con una pulsación | |
| Sonido provisional: pisadas, goteo, golpe de piedra y ambiente de mina | |
| Escuchar: el ambiente baja y los pasos del Tío se oyen más | |
| Asomarse por esquinas sin atravesar la roca | |
| Kit de piezas modulares de 4 m y nivel 1, El derrumbe | |
| Notas que cuentan la historia: hoja de turno, carta de 1974, recorte de 1975 e inscripción en la roca | |
| Escondites con animación: nichos en la roca y carros mineros | |
| Voces con subtítulos: Mateo, Wilmer y el Tío (falta grabarlas, ver [guion](docs/guion_voces.md)) | |
| Cinemática de inicio del derrumbe (se salta con Esc o E) | |
| Nivel 2, Los rieles: rieles, galería inundada, segundo altar y el Tío suelto | |
| Agua hasta el tobillo: caminas más lento y tus pasos chapotean más fuerte | |

## Requisitos

- [Godot 4.7.2](https://godotengine.org/download) (versión estándar, no la .NET).
- Git.

## Abrir el proyecto

1. Clona el repositorio: `git clone https://github.com/mateomerino14/socavon.git`
2. Abre Godot, pulsa **Importar** y elige el archivo `project.godot`.
3. Pulsa **F5** para jugar el nivel 1. Para el túnel de prueba, abre `src/world/test_tunnel/test_tunnel.tscn` y pulsa **F6**.

## Controles

| Acción | Teclado y ratón | Mando |
|---|---|---|
| Moverse | W A S D | Stick izquierdo |
| Mirar | Ratón | Stick derecho |
| Correr | Shift | L3 |
| Agacharse | Ctrl o C | B / Círculo |
| Encender o apagar la lámpara | F | Y / Triángulo |
| Subir o bajar la llama | Rueda del ratón | Cruceta arriba / abajo |
| Recargar la lámpara con carburo | R | X / Cuadrado |
| Recoger, ofrendar, leer, esconderse y salir | E | A / Equis |
| Lanzar una piedra | Clic izquierdo | RT / R2 |
| Escuchar (te quedas quieto) | Mantener clic derecho | LT / L2 |
| Asomarse por esquinas | Q / Z | LB / RB |
| Pausa y opciones | Esc | Start |

## Estructura

```
src/core/      Bus de eventos, estado de la partida y ajustes
src/items/     Catálogo de objetos, objetos recogibles y zonas interactuables
src/enemies/   El Tío, su oído y su vista
src/story/     Notas de la historia y su lectura en el mundo
src/player/    Jugador, cámara y componentes (aliento, lámpara, pasos, bolsa, rayo de interacción)
src/world/     Niveles, piezas modulares, altar, salida, reaparición, soportes y materiales
src/ui/        HUD, pantalla de muerte, menú de pausa y visor de notas
tests/         Pruebas automáticas
tools/         Buscador de código sin uso y generador de sonidos provisionales
assets/        Modelos, texturas y audio
```

### Nivel 1: El derrumbe

Empieza con una cinemática: Don Faustino ordena entrar sin ch'alla, la mina tiembla, Rosendo grita y todo se derrumba. Despiertas entre las piedras y caminas hacia el norte hasta un cruce. El ramal oeste guarda coca, carburo y piedras; el este lleva por un pasillo con soportes hasta la cámara del primer altar, y de ahí a la salida. Por el camino hay cuatro textos que empiezan a contar qué pasó en ese nivel en los años 70. El Tío no puede alcanzarte en este nivel: camina por una galería sellada al este y solo se le oye a través de la roca.

### Nivel 2: Los rieles

Bajas por los rieles por donde sacaban el mineral. En el cruce, el ramal este lleva al segundo altar, con la lista de raya de los siete de 1975. El oeste está inundado: el agua te frena y cada paso chapotea fuerte, y desde el fondo te llama la voz de Wilmer. Allí está su nota, que advierte que esa voz ya no es suya. Al norte, en el buzón donde bajaban los carros, ronda el Tío. Esta vez anda suelto y te puede alcanzar; los carros sirven de escondite. La salida queda pasando el buzón, por donde entra aire de arriba.

### Cómo funciona el Tío

| Estado | Qué hace | Sale cuando |
|---|---|---|
| Patrulla | Recorre sus puntos con una pausa en cada uno | Oye un ruido (sospecha) o ve al jugador (caza) |
| Sospecha | Va al ruido y mira alrededor 2,5 s | Ve al jugador (caza) o no encuentra nada (patrulla) |
| Caza | Persigue al jugador a 4,2 m/s; correr va a 4,6 m/s | Lo pierde de vista 2 s (búsqueda) o lo alcanza |
| Búsqueda | Revisa puntos al azar cerca de donde lo perdió | Lo ve (caza) o se acaba el tiempo (patrulla) |
| Calma | Tras una ofrenda se retira y no oye ni ve | Pasa el tiempo de calma (patrulla) |

- **Oído:** un ruido de volumen 1 se oye a 18 m. Caminar suena 0,35, correr 1, agachado 0,08 y una piedra 0,9.
- **Vista:** cono de 110°. Con la lámpara apagada ve a 3 m; con la llama al máximo, a 22 m. A 1,4 m te nota siempre.
- **Respeto:** con más respeto oye menos, busca menos tiempo y la calma dura más.
- **Escondites:** a oscuras dentro de un nicho o un carro no te ve. Con la lámpara encendida la luz te delata a 4 m. Si te vio entrar, te saca; al buscarte revisa los escondites cercanos (40 % en cada punto).
- **Voz:** al sospechar, cazar, buscar o calmarse dice una frase (con subtítulo), como mucho una cada 6 s.
- **Pasos:** sus pisadas suenan graves y más fuertes cuanto más rápido va; al escuchar se oyen mejor.
- **Presentimiento:** a menos de 10 m la llama de la lámpara tiembla y se encoge; encima de ti casi se apaga.

La arquitectura, los nombres y el flujo de ramas y commits están en [reglas.md](reglas.md).

## Pruebas

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
```

Formato y lint con [gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit):

```bash
pip install "gdtoolkit==4.*"
gdformat --check src tests
gdlint src tests
python3 tools/find_unused.py src tests
```

Los sonidos de `assets/audio/` se generan con `python3 tools/generate_sounds.py` (solo biblioteca estándar, siempre iguales) hasta tener grabaciones reales.

`find_unused.py` busca funciones sin llamadas, señales sin oyentes y constantes o variables sin leer. GitHub Actions corre todas las comprobaciones en cada Pull Request.
