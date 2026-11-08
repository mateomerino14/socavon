class_name PlayerSight
extends Node3D
## Vista del Tío: ve al jugador dentro del cono, sin roca en medio y a una distancia según su luz.

const WORLD_MASK := 1

@export_range(10.0, 180.0) var field_of_view_degrees := 110.0
## Distancia a la que ve al jugador con la lámpara apagada.
@export var dark_range := 3.0
## Distancia a la que lo ve con la llama al máximo.
@export var lit_range := 22.0
## A esta distancia lo nota siempre, aunque esté a oscuras y fuera del cono.
@export var touch_range := 1.4
## Escondido con la lámpara encendida, la luz lo delata hasta esta distancia.
@export var hidden_lit_range := 4.0

var enabled := true

var _player_light := 1.0


## Se suscribe a la luz del jugador.
func _ready() -> void:
	EventBus.player_light_changed.connect(_on_player_light_changed)


## Dice si ve al jugador en este momento.
func can_see(player: Player) -> bool:
	if not enabled or player == null:
		return false
	var target := player.get_eye_position()
	var distance := global_position.distance_to(target)
	if player.is_hidden:
		return _sees_hidden(target, distance)
	if distance <= touch_range:
		return true
	if distance > get_view_range():
		return false
	if not _is_inside_cone(target):
		return false
	return _has_clear_line(target)


## Escondido solo lo delata su lámpara encendida, de cerca, en el cono y sin roca en medio.
func _sees_hidden(target: Vector3, distance: float) -> bool:
	if _player_light <= 0.0 or distance > hidden_lit_range:
		return false
	return _is_inside_cone(target) and _has_clear_line(target)


## Devuelve la distancia a la que ve según la luz actual del jugador.
func get_view_range() -> float:
	return lerpf(dark_range, lit_range, _player_light)


## Dice si el punto cae dentro del cono de visión.
func _is_inside_cone(target: Vector3) -> bool:
	var to_target := (target - global_position).normalized()
	var forward := -global_basis.z
	return forward.angle_to(to_target) <= deg_to_rad(field_of_view_degrees) / 2.0


## Dice si no hay roca entre los ojos y el punto.
func _has_clear_line(target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position, target, WORLD_MASK)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Guarda cuánta luz lleva el jugador.
func _on_player_light_changed(intensity: float) -> void:
	_player_light = intensity
