class_name NoteViewer
extends CanvasLayer
## Muestra una nota en pantalla con el juego en pausa; se cierra con interactuar o Escape.

var is_open := false

@onready var _title: Label = %Title
@onready var _signature: Label = %Signature
@onready var _body: Label = %Body


## Escucha las notas abiertas y arranca oculto.
func _ready() -> void:
	EventBus.note_opened.connect(open)
	visible = false


## Cierra la nota antes de que la tecla llegue al menú de pausa o al jugador.
func _input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("interact") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


## Muestra la nota y pausa el juego.
func open(note: NoteData) -> void:
	_title.text = note.title
	_signature.text = note.signature
	_signature.visible = not note.signature.is_empty()
	_body.text = note.body
	is_open = true
	visible = true
	get_tree().paused = true


## Oculta la nota y reanuda el juego.
func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
