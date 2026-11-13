class_name TransitionData
extends Resource
## Lo que cuenta un tránsito entre niveles: a dónde llega Mateo, qué dice y qué lo acompaña.

## Nombre del nivel al que llega, como se muestra al final del tránsito.
@export var title := ""
## Lo que dice Mateo mientras camina.
@export var line: VoiceLine
## Si el socavón lleva rieles, como los que bajan al nivel 2.
@export var has_rails := false
## Si el Tío aparece en la oscuridad detrás de Mateo.
@export var shows_tio := false
