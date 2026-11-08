# Socavón

Juego de terror en primera persona ambientado en las minas del Cerro Rico de Potosí. Mateo, un minero de 17 años, queda atrapado en un nivel abandonado y debe sobrevivir al Tío, el señor del subsuelo, que caza por la luz y el sonido.

Primera historia del universo del Manqha Pacha.

## Estado

Prototipo `0.1.0`: el jugador recorre un túnel de prueba con su lámpara de carburo, recoge objetos, deja ofrendas y escapa del Tío.

| Hecho | Pendiente |
|---|---|
| Movimiento en primera persona: caminar, correr y agacharse | Sonido |
| Aliento que se gasta al correr | Modelos de Blender |
| Lámpara de carburo con combustible, tres niveles de llama y parpadeo | Niveles 1 a 5 de la mina |
| Pasos que emiten ruido para la futura IA | |
| Túnel gris de prueba y HUD mínimo | |
| Bolsa de objetos: carburo, coca, alcohol, cigarros y piedras | |
| Altar que recibe ofrendas, sube el respeto del Tío y guarda la partida | |
| Piedras que hacen ruido al caer y se pueden volver a recoger | |
| El Tío: patrulla, sospecha, caza, búsqueda y calma; oye los ruidos y ve según la luz | |
| Muerte: si el Tío te alcanza, fundido a negro y reapareces en el último altar | |
| Presentimiento: a menos de 10 m del Tío la llama tiembla y se encoge | |
| Menú de pausa con sensibilidad del ratón, volumen y agacharse con una pulsación | |

## Requisitos

- [Godot 4.7.2](https://godotengine.org/download) (versión estándar, no la .NET).
- Git.

## Abrir el proyecto

1. Clona el repositorio: `git clone https://github.com/mateomerino14/socavon.git`
2. Abre Godot, pulsa **Importar** y elige el archivo `project.godot`.
3. Pulsa **F5** para jugar el túnel de prueba.

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
| Recoger, ofrendar, usar | E | A / Equis |
| Lanzar una piedra | Clic izquierdo | RT / R2 |
| Pausa y opciones | Esc | Start |

## Estructura

```
src/core/      Bus de eventos, estado de la partida y ajustes
src/items/     Catálogo de objetos, objetos recogibles y zonas interactuables
src/enemies/   El Tío, su oído y su vista
src/player/    Jugador, cámara y componentes (aliento, lámpara, pasos, bolsa, rayo de interacción)
src/world/     Túnel de prueba, altar, reaparición, soportes de madera y materiales
src/ui/        HUD, pantalla de muerte y menú de pausa
tests/         Pruebas automáticas
tools/         Buscador de código sin uso
assets/        Modelos, texturas y audio
```

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

`find_unused.py` busca funciones sin llamadas, señales sin oyentes y constantes o variables sin leer. GitHub Actions corre todas las comprobaciones en cada Pull Request.
