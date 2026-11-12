# Modelo del Tío (Blender por script)

El Tío se genera entero con Python dentro de Blender 5.2, sin esculpir a mano, para que se pueda rehacer y ajustar.

| Paso | Script | Resultado |
|------|--------|-----------|
| 1. Modelar en alta | `build_tio.py` | `tio_high.blend`, unas 170 000 caras |
| 2. Pintar | `materials.py` | `tio_painted.blend`, arcilla roja barnizada, pintura negra, mixtura, ojos de vidrio |
| 3. Hornear | `bake.py` | `tio.gltf` con albedo, rugosidad, emisión y normales horneados |
| 4. Animar | `rig.py` | Esqueleto, pesos y animaciones `idle`, `walk`, `run` y `catch`; reexporta `tio.gltf` |
| Revisar | `preview.py` | Vistas de frente, cara y perfil renderizadas con Cycles |

```bash
blender -b -P build_tio.py -- /ruta/tio_high.blend
blender -b -P materials.py -- /ruta/tio_high.blend /ruta/tio_painted.blend
blender -b -P bake.py -- /ruta/tio_painted.blend /ruta/salida 2048
blender -b -P rig.py -- /ruta/salida/tio_game.blend /ruta/animado
```

Exporta como glTF con texturas separadas (`tio.gltf`, `tio.bin` y los PNG) a `assets/models/tio/`. El modelo mira hacia +Y en Blender, que en Godot queda mirando a −Z (el frente).

## Texturas de la mina

Las texturas son escaneos de [Poly Haven](https://polyhaven.com) (CC0): la pared de cantera de Dimitrios Savva para la roca, el barro con piedras de Rob Tuytel para el suelo, la madera aserrada de Charlotte Baglioni para los callapos y el metal oxidado de Rob Tuytel para los rieles. `tools/download_textures.py` las baja con albedo, normales y ORM, y recolorea el albedo por luminancia con los tonos rojizos del Cerro Rico.

```bash
python3 tools/download_textures.py assets/textures/mine 2k rock ground
python3 tools/download_textures.py assets/textures/mine 1k wood iron
```

La roca y el suelo se combinan en `src/world/materials/mine_rock.gdshader`: proyección triplanar en paredes y techo, y suelo en las caras que miran hacia arriba.

## Objetos de la mina

`props.py` modela el carro minero, el cuadro de callapos, el altar (piedra, aguayo y velas), las ofrendas (coca, botella, cigarros, carburo y piedra) y la veta de plata. Exporta un OBJ por material a `assets/models/props/`, sin UV, porque en Godot usan materiales triplanares (`iron.tres`, `wood.tres`, `carved_stone.tres`, `aguayo.tres`).

```bash
blender -b -P props.py -- assets/models/props
```

## Personajes con MakeHuman

`make_human.py` arma personajes humanos con [MakeHuman](http://www.makehumancommunity.org) (CC0) y los anima con la [Universal Animation Library](https://quaternius.com) de Quaternius (CC0). Cada personaje se describe en un JSON de `characters/`: objetivos del cuerpo, piel, ropa, pelo y animaciones. Con `"extras"` se suma un script que agrega piezas propias colgadas de los huesos, como el casco de minero con su lámpara de carburo (`casco_minero.py`). Con `"first_person"` se exportan además solo los brazos, que son los que Mateo ve en primera persona.

```bash
python3 tools/blender/make_human.py tools/blender/characters/mateo.json <makehuman/data> <assets_del_sistema> <AnimationLibrary_Godot_Standard.gltf> "$PWD/assets/models/mateo"
```

La ruta de salida tiene que ser absoluta: el script guarda un `.blend` antes de exportar y, con una ruta relativa, las texturas teñidas quedan sin datos. Los recursos del sistema son `makehuman_system_assets_cc0.zip` de la página de paquetes de MakeHuman.
