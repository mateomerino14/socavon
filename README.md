# Socavón

Juego de terror en primera persona ambientado en las minas del Cerro Rico de Potosí. Mateo, un minero de 17 años, queda atrapado en un nivel abandonado y debe sobrevivir al Tío, el señor del subsuelo, que caza por la luz y el sonido.

Primera historia del universo del Manqha Pacha.

## Estado

Prototipo `0.1.0`: el jugador recorre un túnel de prueba con su lámpara de carburo, recoge objetos y deja ofrendas al Tío.

| Hecho | Pendiente |
|---|---|
| Movimiento en primera persona: caminar, correr y agacharse | Piedras para distraer |
| Aliento que se gasta al correr | El Tío y sus estados |
| Lámpara de carburo con combustible, tres niveles de llama y parpadeo | Muerte y reaparición |
| Pasos que emiten ruido para la futura IA | Sonido |
| Túnel gris de prueba y HUD mínimo | |
| Bolsa de objetos: carburo, coca, alcohol, cigarros y piedras | |
| Altar que recibe ofrendas, sube el respeto del Tío y guarda la partida | |

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
| Soltar el ratón | Esc (un clic lo vuelve a capturar) | Start |

## Estructura

```
src/core/      Bus de eventos y estado de la partida
src/items/     Catálogo de objetos, objetos recogibles y zonas interactuables
src/player/    Jugador, cámara y componentes (aliento, lámpara, pasos, bolsa, rayo de interacción)
src/world/     Túnel de prueba, altar, soportes de madera y materiales
src/ui/        HUD
tests/         Pruebas automáticas
assets/        Modelos, texturas y audio
```

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
```

GitHub Actions corre las tres comprobaciones en cada Pull Request.
