class_name NoteData
extends Resource
## Texto que el jugador encuentra en la mina: notas, cartas, recortes o inscripciones.

## Identificador único, para recordar que ya se leyó.
@export var id := ""
@export var title := ""
## Quién la escribió y cuándo, si se sabe.
@export var signature := ""
@export_multiline var body := ""
