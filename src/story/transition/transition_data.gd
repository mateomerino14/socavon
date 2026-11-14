class_name TransitionData
extends Resource
## Lo que cuenta un tránsito entre niveles: qué dice Mateo y qué lo acompaña.

## Lo que dice Mateo mientras camina.
@export var line: VoiceLine
## Si el socavón lleva rieles, como los que bajan al nivel 2.
@export var has_rails := false
## Si el Tío aparece en la oscuridad detrás de Mateo.
@export var shows_tio := false
