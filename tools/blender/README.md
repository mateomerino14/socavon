# Modelo del Tío (Blender por script)

El Tío se genera entero con Python dentro de Blender 5.2, sin esculpir a mano, para que se pueda rehacer y ajustar.

| Paso | Script | Resultado |
|------|--------|-----------|
| 1. Modelar en alta | `build_tio.py` | `tio_high.blend`, unas 170 000 caras |
| 2. Pintar | `materials.py` | `tio_painted.blend`, arcilla roja barnizada, pintura negra, mixtura, ojos de vidrio |
| 3. Hornear | `bake.py` | `tio.gltf` con albedo, rugosidad, emisión y normales horneados |
| Revisar | `preview.py` | Vistas de frente, cara y perfil renderizadas con Cycles |

```bash
blender -b -P build_tio.py -- /ruta/tio_high.blend
blender -b -P materials.py -- /ruta/tio_high.blend /ruta/tio_painted.blend
blender -b -P bake.py -- /ruta/tio_painted.blend /ruta/salida 2048
```

Exporta como glTF con texturas separadas (`tio.gltf`, `tio.bin` y los PNG) a `assets/models/tio/`. El modelo mira hacia +Y en Blender, que en Godot queda mirando a −Z (el frente).
