class_name ReadableNote
extends Node3D
## Nota en el mundo: se lee con la tecla de interactuar y abre el texto en pantalla.

const READ_PROMPT := "Leer: %s"
const REREAD_PROMPT := "Volver a leer: %s"

@export var note: NoteData
## Texto pintado en la roca; si se asigna, muestra el cuerpo de la nota.
@export var wall_text: Label3D

@onready var _interactable: Interactable = $Interactable


## Conecta la interacción y pinta el texto en la roca si corresponde.
func _ready() -> void:
	if wall_text:
		wall_text.text = note.body
	_interactable.set_prompt_builder(_build_prompt)
	_interactable.interacted.connect(_on_interacted)


## Arma el texto según si ya se leyó.
func _build_prompt(_player: Player) -> String:
	if GameState.has_read_note(note.id):
		return REREAD_PROMPT % note.title
	return READ_PROMPT % note.title


## Marca la nota como leída y pide mostrarla.
func _on_interacted(_player: Player) -> void:
	GameState.mark_note_read(note.id)
	EventBus.note_opened.emit(note)
