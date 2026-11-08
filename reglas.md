# Estándares de desarrollo

Socavón — convenciones de ramas, commits, codificación y arquitectura en Godot.

---

## ESTÁNDARES DE RAMAS

| Rama | Uso |
|---|---|
| `main` | Versión estable, solo con luz verde |
| `develop` | Integración de los módulos terminados |
| `feat/<modulo>` | Desarrollo de un módulo o mecánica, en `snake_case` (ej. `feat/ia_tio`) |
| `fix/<tema>` | Corrección puntual sobre `develop` |
| `style/<tema>` | Cambio visual o de ambientación sin tocar la lógica |
| `refactor/<tema>` | Reestructuración o limpieza sin cambiar el comportamiento |
| `test/<tema>` | Pruebas nuevas o ajustes de pruebas |
| `docs/<tema>` | Documentación (README, reglas, diseño) |

### Flujo

1. Cada módulo se desarrolla en su rama, creada desde `develop`.
2. Al terminarlo se abre un Pull Request hacia `develop`. GitHub Actions debe pasar antes del merge.
3. Cuando `develop` reúne una entrega completa y se aprueba, se abre un Pull Request de `develop` hacia `main`.
4. Después del merge, la rama de trabajo se borra; en el repositorio solo quedan `main` y `develop`.

---

## ESTÁNDARES DE COMMITS

Se usa Conventional Commits, con todos los commits a nombre del autor del repositorio y sin coautores.

### Tipos de commit

| Tipo | Uso |
|---|---|
| `feat` | Nueva mecánica o funcionalidad |
| `fix` | Corrección de errores |
| `style` | Cambios visuales, de luz o de ambientación sin afectar la lógica |
| `refactor` | Reestructuración de código sin modificar el comportamiento |
| `docs` | Documentación |
| `test` | Creación o actualización de pruebas |
| `chore` | Configuración del proyecto, CI y herramientas |

### Formato

```
<tipo>: <Descripción>
```

### Ejemplos válidos

```
feat: Agrega la lámpara de carburo con combustible y niveles de llama
fix: Evita que el jugador se levante bajo un techo bajo
style: Oscurece la niebla del túnel de prueba
test: Prueba que el aliento se recupera tras la pausa
```

### Reglas

- El mensaje comienza con mayúscula después del prefijo.
- Describe la funcionalidad, no los archivos modificados.
- Un commit representa una única funcionalidad, corrección o mejora.
- Evitar mensajes genéricos: `cambios`, `correcciones`, `actualización`, `prueba`.

---

## ESTÁNDARES DE CODIFICACIÓN

### Idioma

- El código se escribe en inglés: clases, variables, funciones, señales, nodos y acciones de entrada.
- Los textos que ve el jugador, los comentarios y la documentación van en español.

### Comentarios

- Cada clase lleva un comentario de documentación (`##`) de una línea bajo `extends` que dice su propósito.
- Cada función lleva un comentario `##` de una línea que describe su propósito.
- Dentro de las funciones solo se dejan avisos importantes, de una línea.
- Las variables exportadas llevan `##` solo cuando su nombre no basta.
- Eliminar el código comentado antes de cada commit.

```gdscript
## Recarga carburo sin pasar del máximo.
func add_fuel(amount: float) -> void:
	fuel = minf(fuel + amount, max_fuel)
	fuel_changed.emit(fuel, max_fuel)
```

### Sintaxis

El formato sigue la guía oficial de GDScript y se valida con gdtoolkit: `gdformat --check src tests` y `gdlint src tests`. Para corregir el formato: `gdformat src tests`. El código sin uso (funciones sin llamadas, señales sin oyentes, constantes o variables sin leer) se busca con `python3 tools/find_unused.py src tests` y no debe quedar ninguno; una señal se declara cuando ya tiene quien la escuche.

**Tipado estático siempre.** Una declaración sin tipo es un error del proyecto (`untyped_declaration`). Se usa `:=` cuando el tipo se deduce.

**No usar el operador ternario (`a if cond else b`) en la lógica**; se prefieren bloques `if`/`else` explícitos o un valor por defecto que se reemplaza.

```gdscript
# Correcto
var rate := deceleration
if direction != Vector3.ZERO:
	rate = acceleration

# Incorrecto
var rate := acceleration if direction != Vector3.ZERO else deceleration
```

**Evitar valores mágicos**; se declaran como `const` con nombre, o como `@export` cuando se ajustan desde el editor.

```gdscript
const MAX_LEVEL := 3
@export var walk_speed := 2.4
```

**Nombres:**

| Elemento | Convención | Ejemplo |
|---|---|---|
| Archivos y carpetas | `snake_case` | `carbide_lamp.gd` |
| Clases (`class_name`) | `PascalCase` | `CarbideLamp` |
| Nodos en escenas | `PascalCase` | `CeilingCheck` |
| Funciones y variables | `snake_case` | `get_fuel_ratio()` |
| Privados | prefijo `_` | `_apply_light()` |
| Constantes y enums | `CONSTANT_CASE` | `MIN_LEVEL` |
| Señales | pasado o cambio | `fuel_changed`, `exhausted` |
| Acciones de entrada | `snake_case` | `lamp_toggle` |

---

## ARQUITECTURA

### Estructura

```
src/
├── core/             Autoloads globales (EventBus, GameState, Settings)
├── items/            Catálogo de objetos, objetos recogibles e Interactable
├── player/           Jugador
│   ├── player.tscn / player.gd      Raíz: lee la entrada y coordina
│   ├── first_person_camera.gd       Mirada y balanceo
│   └── components/                  Piezas independientes (aliento, lámpara, pasos, bolsa, rayo)
├── enemies/          El Tío y amenazas, con sus sentidos en components/
├── world/            Niveles, piezas modulares y materiales
│   ├── level.gd                     Raíz común de todos los niveles
│   ├── pieces/                      Kit modular de la mina
│   ├── materials/                   Roca, madera y ambiente compartido
│   ├── props/
│   └── <nivel>/                     Escena y malla de navegación de cada nivel
└── ui/               HUD y menús
assets/               Modelos (.glb desde Blender), texturas y audio (.ogg)
tests/                Pruebas, en carpetas que reflejan src/
```

Cada escena vive junto a su script con el mismo nombre (`player.tscn` y `player.gd`).

### Responsabilidades

| Capa | Puede | No puede |
|---|---|---|
| Raíz de sistema (`Player`) | Leer la entrada, decidir el estado, llamar a sus componentes, publicar en `EventBus` | Contener la lógica interna de un componente |
| Componente | Resolver una sola cosa y avisar con señales propias | Conocer a otros componentes o leer la entrada |
| `EventBus` | Transportar eventos entre sistemas que no se conocen | Guardar estado |
| `GameState` | Guardar el estado de la partida (respeto, punto de guardado) | Contener reglas de una mecánica |
| `Interactable` | Avisar a su dueño que el jugador lo usó | Decidir qué pasa al usarlo |
| `Settings` | Guardar los ajustes del jugador en `user://ajustes.cfg` y avisar cambios | Aplicarlos: cada sistema los lee al recibir `changed` |
| HUD y audio | Escuchar `EventBus` y presentar | Cambiar el estado del juego |

**Señales hacia arriba, llamadas hacia abajo:** un nodo llama métodos de sus hijos y escucha las señales de ellos; nunca busca a su padre ni a sus hermanos.

**`EventBus` solo para eventos que cruzan sistemas**, como el ruido que oye el Tío o la luz que lo atrae. La comunicación dentro de una escena usa señales locales.

### Física

| Capa | Uso |
|---|---|
| 1 | Mundo (roca, soportes, altares) |
| 2 | Jugador |
| 3 | Interactuables (objetos, altares) |
| 4 | Enemigos (el Tío) |
| 5 | Proyectiles (piedras lanzadas) |

### Notas de la historia

- Cada nota es un recurso `NoteData` en `src/story/notes/<id>.tres`, con `id` único, título, firma y texto.
- En el mundo se usa `readable_note.tscn` (papel en el suelo) o `wall_inscription.tscn` (texto pintado en la roca).
- Los textos son parte de la historia del documento de diseño; uno nuevo se acuerda allí antes de escribirlo.

### Kit modular

- Cuadrícula de 4 m; cada pieza se centra en su celda con el suelo en y = 0.
- Pasillos de 3 m de ancho y 2,6 m de alto. La cámara ocupa 3 × 3 celdas, con puertas en el centro de cada lado.
- Piezas: `tunnel_straight`, `tunnel_corner`, `tunnel_t`, `tunnel_cross`, `tunnel_dead_end`, `chamber` y `tunnel_cap` para tapar una puerta.
- Sin rotar, las aberturas son: recto norte-sur, esquina sur-este, T oeste-este-sur, fin sur.
- Rotaciones en las escenas (la matriz se escribe por filas): 90° = `Transform3D(0, 0, 1, 0, 1, 0, -1, 0, 0, …)` lleva el sur al este; 180° = `Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, -1, …)`; 270° = `Transform3D(0, 0, -1, 0, 1, 0, 1, 0, 0, …)` lleva el sur al oeste.

### Escenas obligatorias de cada nivel

| Nodo | Para qué |
|---|---|
| `Player` | El jugador |
| `Hud` | Barras, avisos y bolsa |
| `RespawnDirector` | Muerte y reaparición en el último guardado |
| `PauseMenu` | Pausa con Escape y ajustes |
| `NoteViewer` | Muestra las notas al leerlas |
| `NavigationRegion3D` | Por dónde camina el Tío |
| Raíz con `level.gd` | Llama a `GameState.reset()` y guarda el inicio como primer punto |
| `WorldEnvironment` | Usa `materials/mine_environment.tres` |
| `LevelExit` | Fin del nivel; carga el siguiente si `next_level_path` tiene valor |

### Navegación

- Cada nivel tiene un `NavigationRegion3D` con su malla horneada en un `.tres` junto a la escena.
- Solo se hornean los nodos del grupo `navigation_source` (roca, soportes, altares); los objetos sueltos no.
- El filtro de horneado se limita a la altura del suelo para que no aparezca navegación sobre el techo de las piezas.
- Al cambiar la geometría de un nivel, se vuelve a hornear: seleccionar `NavigationRegion3D` y pulsar **Bake NavigationMesh**.

### Buses de audio

| Bus | Uso |
|---|---|
| `Master` | Volumen general (ajuste del jugador) |
| `Ambiente` | Fondo de la mina; baja al escuchar |
| `Efectos` | Pisadas, goteo, piedras y el Tío; sube al escuchar |

Todo sonido nuevo se asigna a `Ambiente` o a `Efectos`, nunca directo a `Master`.

### Grupos

| Grupo | Uso |
|---|---|
| `player` | Declarado en `player.tscn`; el Tío encuentra así al jugador |
| `navigation_source` | Geometría que se hornea en la navegación |
| `enemies` | Declarado en cada enemigo; `RespawnDirector` los reinicia al reaparecer el jugador |

---

## PRUEBAS

- Las pruebas viven en `tests/`, con archivos `<nombre>_test.gd` que extienden `TestCase`; cada método `test_` es una prueba.
- Una prueba que cambia `Settings` usa su propio archivo (`config_path`) y lo borra al terminar.
- Se ejecutan sin abrir el editor: `godot --headless --path . --script res://tests/run_tests.gd`.
- Cada componente con lógica tiene pruebas unitarias; los recorridos del jugador se prueban dentro de una escena real.
- En cada Pull Request, GitHub Actions valida el formato, el lint y el código sin uso, importa el proyecto y corre las pruebas.
- Un módulo se considera terminado cuando sus pruebas pasan en GitHub Actions y el README está actualizado.

---

## ASSETS

- Los modelos se exportan desde Blender a `.glb` en `assets/models/`, con escala real en metros.
- El audio se guarda en `.ogg`; los efectos cortos pueden ir en `.wav`.
- Los sonidos provisionales los genera `tools/generate_sounds.py`; al reemplazar uno por una grabación real se mantiene el mismo nombre de archivo.
- Un sonido que debe repetirse sin corte lleva sus puntos de bucle en el WAV o se marca con bucle al importarlo.
- Los archivos fuente `.blend` se guardan fuera del repositorio o, si se suben, en `assets/source/`.

---

## BUENAS PRÁCTICAS GENERALES

- Cada archivo tiene una única responsabilidad principal.
- Los valores de ajuste se exponen con `@export` agrupados con `@export_group`.
- Evitar código duplicado y código sin uso.
- No incluir credenciales en el repositorio.
