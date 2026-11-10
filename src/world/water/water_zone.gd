@tool
class_name WaterZone
extends Area3D
## Agua estancada hasta el tobillo: quien la cruza camina lento y chapotea fuerte.

## Altura de la superficie sobre el suelo.
const SURFACE_HEIGHT := 0.22
## Alto de la zona que detecta al jugador.
const DETECTION_HEIGHT := 0.8

## Ancho (X) y largo (Z) del charco en metros.
@export var size := Vector2(3.0, 4.0):
	set(value):
		size = value
		_apply_size()

@onready var _shape: CollisionShape3D = $CollisionShape3D
@onready var _surface: MeshInstance3D = $Surface


## Ajusta el tamaño y, en el juego, escucha a quien entra y sale.
func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## El jugador empieza a vadear.
func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		body.enter_water()


## El jugador sale del agua.
func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		body.leave_water()


## Lleva el tamaño a la forma de detección y a la superficie.
func _apply_size() -> void:
	if not is_node_ready():
		return
	var box := _shape.shape as BoxShape3D
	box.size = Vector3(size.x, DETECTION_HEIGHT, size.y)
	_shape.position.y = DETECTION_HEIGHT / 2.0
	var plane := _surface.mesh as PlaneMesh
	plane.size = size
	_surface.position.y = SURFACE_HEIGHT
