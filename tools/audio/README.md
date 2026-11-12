# Sonidos y música

Los sonidos de la mina salen de grabaciones reales con licencia CC0 (dominio público) de [OpenGameArt](https://opengameart.org). `oga_sources.json` lista cada paquete con su autor y su página; `build_oga_sounds.py` los baja, los recorta, les pone el eco de la galería y escribe los WAV con los nombres que usa el juego:

- Pasos sobre grava, piedra y barro (TinyWorlds), cuatro variantes.
- Pasos en el agua (rubberduck), tres variantes.
- Gotas sacadas de un sótano que gotea (Independent.nu).
- La piedra que golpea la roca (rubberduck).
- El derrumbe (StarNinjas) con el retumbo que lo sigue (Musheran).
- El aire de la galería (JaggedStone), en un bucle de 40 segundos sin costura.

```bash
python3 tools/audio/build_oga_sounds.py <carpeta_de_descarga> assets/audio
```

## Música

`build_music.py` arma tres capas que suenan juntas y que `MusicDirector` cruza según el Tío:

- **Calma**: el ambiente de caverna de Paul Wortmann (CC0), oscurecido.
- **Tensión**: los latidos con piano de congusbongus (CC0).
- **Persecución**: sintetizada en el script: un bombo legüero en seis por ocho, un bordón disonante y un raspado de cuerdas que tiembla.

```bash
python3 tools/audio/build_music.py <carpeta_de_descarga> assets/audio/music
```

Las capas son bucles sin costura; el bucle se activa en su `.import` (`loop=true`).

El rugido sintético del Tío, base del grito de captura, sigue saliendo de `tools/generate_sounds.py`.
