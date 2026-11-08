class_name VoiceLine
extends Resource
## Una línea hablada: quién la dice, su subtítulo y su grabación, si ya existe.

## Identificador único; es también el nombre del archivo de audio en el guion.
@export var id := ""
@export var speaker := ""
@export_multiline var text := ""
## Grabación de la línea; mientras no exista, se muestra solo el subtítulo.
@export var audio: AudioStream
