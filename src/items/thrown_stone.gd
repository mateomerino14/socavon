class_name ThrownStone
extends RigidBody3D
## Piedra lanzada: hace ruido al chocar y vuelve a ser recogible cuando se detiene.

const PICKUP_SCENE := preload("res://src/items/pickup.tscn")
const MIN_IMPACT_SPEED := 1.5
const FIRST_IMPACT_LOUDNESS := 0.9
const BOUNCE_LOUDNESS_RATIO := 0.5
const MAX_NOISY_IMPACTS := 3
const SETTLED_SPEED := 0.08
const SETTLE_SECONDS := 0.6
const RADIUS := 0.06
const LOUDEST_HIT_DB := 0.0
const QUIETEST_HIT_DB := -18.0

var _impacts := 0
var _loudness := FIRST_IMPACT_LOUDNESS
var _speed_before_contact := 0.0
var _settled_time := 0.0

@onready var _hit_audio: AudioStreamPlayer3D = $HitAudio


## Escucha los choques de la piedra.
func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Recuerda la rapidez antes del choque y detecta cuando quedó quieta.
func _physics_process(delta: float) -> void:
	var speed := linear_velocity.length()
	if speed < SETTLED_SPEED:
		_settled_time += delta
	else:
		_settled_time = 0.0
	if _settled_time >= SETTLE_SECONDS:
		_become_pickup()
	_speed_before_contact = speed


## Suena y emite un ruido en cada choque fuerte, cada vez más suave.
func _on_body_entered(_body: Node) -> void:
	if _impacts >= MAX_NOISY_IMPACTS or _speed_before_contact < MIN_IMPACT_SPEED:
		return
	_hit_audio.volume_db = lerpf(QUIETEST_HIT_DB, LOUDEST_HIT_DB, _loudness)
	_hit_audio.play()
	EventBus.noise_emitted.emit(global_position, _loudness)
	_loudness *= BOUNCE_LOUDNESS_RATIO
	_impacts += 1


## Deja en su lugar una piedra que se puede volver a recoger.
func _become_pickup() -> void:
	var pickup: Pickup = PICKUP_SCENE.instantiate()
	pickup.item_type = ItemCatalog.Type.STONE
	get_parent().add_child(pickup)
	pickup.global_position = global_position - Vector3.UP * RADIUS
	queue_free()
