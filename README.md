# Socavón

Juego de terror en primera persona ambientado en las minas del Cerro Rico de Potosí. Mateo, un minero de 17 años, queda atrapado en un nivel abandonado y debe sobrevivir al Tío, el señor del subsuelo, que caza por la luz y el sonido.

Primera historia del universo del Manqha Pacha.

## Estado

Prototipo `0.1.0`: el jugador recorre un túnel de prueba con su lámpara de carburo.

| Hecho | Pendiente |
|---|---|
| Movimiento en primera persona: caminar, correr y agacharse | Altar con ofrendas y guardado |
| Aliento que se gasta al correr | Piedras para distraer |
| Lámpara de carburo con combustible, tres niveles de llama y parpadeo | El Tío y sus estados |
| Pasos que emiten ruido para la futura IA | Muerte y reaparición |
| Túnel gris de prueba y HUD mínimo | Sonido |

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
| Soltar el ratón | Esc (un clic lo vuelve a capturar) | Start |

## Estructura

```
src/core/      Bus de eventos global
src/player/    Jugador, cámara y componentes (aliento, lámpara, pasos)
src/world/     Túnel de prueba, soportes de madera y materiales
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
