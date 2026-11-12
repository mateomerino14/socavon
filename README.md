# Socavón

Juego de terror en primera persona ambientado en las minas del Cerro Rico de Potosí. Mateo, un minero de 17 años, queda atrapado en un nivel abandonado después de un derrumbe y tiene que salir vivo mientras lo caza el Tío, el señor del subsuelo, que se guía por la luz y el sonido.

Es la primera historia del universo del Manqha Pacha.

Versión `0.4.0`: el juego completo, con menú principal, cinco niveles, dos finales y partida guardada.

## Descargar y jugar

En [Releases](https://github.com/mateomerino14/socavon/releases) está el `.zip` para Windows. Descomprímelo y abre `Socavon.exe`; no hace falta instalar nada. Conviene jugar con audífonos.

## Qué hay en el juego

- **Supervivencia a oscuras:**
  - lámpara de carburo con combustible, tres niveles de llama y parpadeo;
  - aliento que se gasta al correr;
  - agacharse, escuchar quieto y asomarse por las esquinas.
- **El Tío:** patrulla, sospecha, caza, busca y se calma con ofrendas. Oye tus pasos y las piedras que lanzas, ve según tu luz y revisa los escondites. Tiene modelo de arcilla pintada, animaciones y voz.
- **Escondites:** nichos en la roca y carros mineros, con animación al entrar y salir.
- **Altares:** pides permiso o dejas coca, alcohol o cigarros. Suben el respeto del Tío y guardan la partida.
- **Historia:** se cuenta con notas, inscripciones en la roca, voces actuadas con subtítulos y dos cinemáticas, la del derrumbe y la de la bocamina.
- **Dos finales**, según si le pagas al Tío lo que pide.
- **Presentación:**
  - menú principal con la mina de fondo;
  - opciones, pausa y créditos;
  - niebla volumétrica y grano de película;
  - texturas y modelos hechos en Blender.

## Niveles

### Nivel 1: El derrumbe

Empieza con una cinemática: Don Faustino ordena entrar sin ch'alla, la mina tiembla, Rosendo grita y todo se derrumba. Despiertas entre las piedras y caminas hacia el norte hasta un cruce. El ramal oeste guarda coca, carburo y piedras; el este lleva por un pasillo con soportes hasta la cámara del primer altar, y de ahí a la salida. Por el camino hay cuatro textos que empiezan a contar qué pasó en ese nivel en los años 70. El Tío no puede alcanzarte en este nivel: camina por una galería sellada al este y solo se le oye a través de la roca.

### Nivel 2: Los rieles

Bajas por los rieles por donde sacaban el mineral. En el cruce, el ramal este lleva al segundo altar, con la lista de raya de los siete de 1975. El oeste está inundado: el agua te frena y cada paso chapotea fuerte, y desde el fondo te llama la voz de Wilmer. Allí está su nota, que advierte que esa voz ya no es suya. Al norte, en el buzón donde bajaban los carros, ronda el Tío. Esta vez anda suelto y te puede alcanzar; los carros sirven de escondite. La salida queda pasando el buzón, por donde entra aire de arriba.

### Nivel 3: La veta

Desde el cruce hay dos caminos a la cámara de la veta de plata. El oeste es un gateadero tan bajo que hay que pasarlo agachado, pero el Tío no cabe ahí; al salir está el altar. El este es un túnel largo y alto por donde ronda el Tío, y ahí están la coca, el alcohol y el carburo. En la veta, el casco de Justo Condori dice que lo que brilla no es plata. Desde el norte, la voz de Don Faustino pide ayuda.

### Nivel 4: La cuadrilla

Hay dos Tíos: uno en el cruce de los ramales y otro en la cámara del norte. En el ramal oeste está el pañuelo de Rosendo; en el este, la confesión de Don Faustino, que le ofreció al Tío uno de los suyos para salir él. Su voz te llama desde ahí. Rosendo deja la pista del final: "paga tú, con lo que tengas, pero paga. Coca, trago y cigarro".

### Nivel 5: La bocamina

El último altar no acepta ofrendas sueltas: el Tío cobra coca, alcohol y cigarro juntos. Están repartidos en los ramales que él vigila.

- **Con permiso:** si pagas, el Tío te deja ir.
- **Sin permiso:** si corres hacia la luz sin pagar, el Tío sale tras de ti y no se rinde aunque lo pierdas de vista.

Al cruzar la bocamina se muestra tu final, la partida guardada se borra y vuelves al menú.


## Cómo funciona el Tío

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

## Desarrollo

### Requisitos

- [Godot 4.7.2](https://godotengine.org/download) (versión estándar, no la .NET).
- Git.
- Para regenerar arte y sonido: Blender 5.2 (o el módulo `bpy`), Python 3, ffmpeg y `piper-tts`.

### Abrir el proyecto

1. Clona el repositorio: `git clone https://github.com/mateomerino14/socavon.git`
2. Abre Godot, pulsa **Importar** y elige el archivo `project.godot`.
3. Pulsa **F5** para abrir el menú principal. Para ensayar mecánicas, abre `src/world/test_tunnel/test_tunnel.tscn` y pulsa **F6**.

### Estructura

```
src/core/      Autoloads: bus de eventos, estado de la partida, ajustes y partida guardada
src/player/    Jugador, cámara y componentes (aliento, lámpara, pasos, bolsa, escucha, susto)
src/enemies/   El Tío y sus componentes (oído, vista, voz, pasos, animación)
src/items/     Catálogo de objetos, objetos recogibles con su modelo e Interactable
src/story/     Notas, voces, cinemática del derrumbe y el final (altar del pago, persecución, bocamina)
src/world/     Los cinco niveles, piezas modulares, altar, agua, escondites, soportes y materiales
src/ui/        Menú principal, HUD, pausa, opciones, visor de notas, pantalla de muerte y tema visual
tests/         Pruebas automáticas, en carpetas que reflejan src/
tools/         Generadores (Blender, sonidos, voces, malla de navegación) y buscador de código sin uso
assets/        Modelos, texturas, audio y fuentes
docs/          Guion de voces, LEEME del ejecutable y notas de versión
```

La arquitectura, los nombres y el flujo de ramas y commits están en [reglas.md](reglas.md).

### Pruebas y estilo

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/run_tests.gd
pip install "gdtoolkit==4.*"
gdformat --check src tests
gdlint src tests
python3 tools/find_unused.py src tests
```

`find_unused.py` busca funciones sin llamadas, señales sin oyentes y constantes o variables sin leer. GitHub Actions corre todas las comprobaciones en cada Pull Request.

### Herramientas

| Qué | Cómo |
|---|---|
| Tío, objetos, Mateo y el casco de minero | Scripts de Blender en `tools/blender/` (ver su [README](tools/blender/README.md)) |
| Texturas escaneadas de la mina | `python3 tools/download_textures.py assets/textures/mine 2k` |
| Sonidos de la mina y música (ver [tools/audio](tools/audio/README.md)) | `python3 tools/audio/build_oga_sounds.py <descargas> assets/audio` y `build_music.py` |
| Rugido del Tío, base del grito | `python3 tools/generate_sounds.py` |
| Voces actuadas | `python3 tools/generate_voices.py <carpeta de los modelos de Piper>` (ver el [guion](docs/guion_voces.md)) |
| Malla de navegación de un nivel | `godot --headless --path . -s tools/bake_navmesh.gd -- res://src/world/level_0N/level_0N.tscn` |
| Ejecutable de Windows | `godot --headless --export-release "Windows Desktop" build/Socavon.exe` |

Cada vez que `develop` se une a `main`, `.github/workflows/release.yml` exporta el juego para Windows, lo empaqueta con `docs/LEEME.txt` y lo publica en Releases como `v` más la versión de `project.godot`, con las notas de `docs/notas_version.md`.
