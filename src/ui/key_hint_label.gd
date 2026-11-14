class_name KeyHintLabel
extends Label
## Texto con teclas o botones que cambian según se juegue con teclado o con mando. Las acciones van
## entre llaves, como "{map} Cerrar".

@export var template := ""


## Escribe el texto y lo reescribe si cambia el aparato.
func _ready() -> void:
	InputDevice.changed.connect(_write)
	_write()


## Pone las teclas o botones del aparato actual.
func _write() -> void:
	text = InputDevice.fill(template)
