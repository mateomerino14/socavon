# Guion de voces

Todas las líneas habladas del juego. Cada una vive en `src/story/voices/<id>.tres` y se muestra con subtítulo aunque todavía no tenga grabación.

## Cómo grabar

1. Graba cada línea por separado, en un lugar sin eco, a unos 20 cm del micrófono.
2. Guarda el archivo como `<id>.ogg` (por ejemplo `tio_caza_1.ogg`) en `assets/audio/voices/`.
3. En Godot, abre `src/story/voices/<id>.tres` y arrastra el audio al campo **Audio**. Desde ese momento suena con su subtítulo y dura lo que dure la grabación.

Para el Tío sirve una voz grave y lenta; luego se le puede bajar el tono en Audacity (Efecto → Cambiar tono, −3 a −5 semitonos).

## Líneas

| Id | Personaje | Línea | Dónde suena | Cómo decirla |
|---|---|---|---|---|
| `mateo_cruce` | Mateo | ¿Rosendo? ¿Don Faustino? ...Nadie contesta. | Nivel 1, al llegar al cruce | Susurrando, asustado, la voz rebota en la roca |
| `mateo_altar` | Mateo | Un altar del Tío. Rosendo siempre decía que primero se pide permiso. | Nivel 1, al entrar a la cámara del altar | Bajo, con respeto; recordando a Rosendo |
| `mateo_siete` | Mateo | Somos siete... ¿Siete qué? | Nivel 1, frente a la inscripción | Leyendo en voz baja, se le corta la voz |
| `wilmer_llamado` | Wilmer | Mateo... por acá... sigue mi voz... | Nivel 1, ramal oeste, desde detrás de la roca | Lejano y apagado; casi amable, pero algo no suena bien |
| `rosendo_derrumbe` | Rosendo | ¡Mateo! ¡Agárrate, chango, que se viene el techo! | Cinemática de inicio | Gritando por encima del estruendo |
| `faustino_orden` | Don Faustino | Sin ch'alla nomás entramos. El Tío no paga mi sueldo. | Cinemática de inicio | Seco, mandón, con prisa |
| `tio_sospecha_1` | El Tío | Mmm... huelo carburo. | El Tío, al oír un ruido | Grave, lento, olfateando |
| `tio_sospecha_2` | El Tío | ¿Quién anda en mi casa? | El Tío, al oír un ruido | Grave, curioso, como quien no tiene apuro |
| `tio_caza_1` | El Tío | ¡Entraste sin pedirme permiso! | El Tío, al verte | Rugido contenido, ofendido |
| `tio_caza_2` | El Tío | Te veo, wawa. | El Tío, al verte | Ronco, con una risa en la garganta |
| `tio_busqueda_1` | El Tío | No te escondas... la mina es mía. | El Tío, buscándote | Susurro grave, cerca |
| `tio_busqueda_2` | El Tío | Tu lámpara te va a traicionar. | El Tío, buscándote | Burlón, paciente |
| `tio_calma_1` | El Tío | Eso... así se pide. | El Tío, tras una ofrenda | Satisfecho, casi paternal |
