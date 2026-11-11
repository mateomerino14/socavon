class_name DreadSense
extends Node3D
## Presentimiento: mide qué tan cerca está el enemigo más próximo, de 0 (lejos) a 1 (encima).

const ENEMY_GROUP := &"enemies"

## Desde esta distancia empieza a notarse el Tío.
@export var presence_radius := 10.0

var dread := 0.0


## Calcula el presentimiento según el enemigo más cercano.
func update_dread() -> float:
	var closest := INF
	for enemy: Node3D in get_tree().get_nodes_in_group(ENEMY_GROUP):
		closest = minf(closest, global_position.distance_to(enemy.global_position))
	dread = 0.0
	if closest < presence_radius:
		dread = 1.0 - closest / presence_radius
	return dread
