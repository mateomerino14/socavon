class_name Tio
extends CharacterBody3D
## El Tío: patrulla, sospecha de ruidos, caza al jugador que ve, lo busca y se calma con ofrendas.

enum State { PATROL, SUSPICION, HUNT, SEARCH, CALM }

const HORIZONTAL_PLANE := Vector3(1.0, 0.0, 1.0)
const ARRIVAL_DISTANCE := 0.7
const CATCH_DISTANCE := 1.1
const TURN_SPEED := 6.0
const LOOK_AROUND_SPEED := 1.2
const SEARCH_RADIUS := 6.0
const RETARGET_DISTANCE := 0.5
## Distancia desde la salida del escondite a la que alcanza a sacar al jugador.
const SPOT_REACH := 1.2

@export_group("Patrulla")
@export var patrol_points: Array[Node3D] = []
@export var patrol_wait_seconds := 1.5

@export_group("Velocidades (m/s)")
@export var patrol_speed := 1.4
@export var investigate_speed := 1.9
@export var hunt_speed := 4.2
@export var acceleration := 12.0

@export_group("Tiempos (s)")
@export var suspicion_look_seconds := 2.5
@export var lose_sight_seconds := 2.0
@export var search_seconds_low_respect := 16.0
@export var search_seconds_high_respect := 8.0
@export var calm_seconds_low_respect := 12.0
@export var calm_seconds_high_respect := 30.0

@export_group("Escondites")
## Probabilidad de revisar un escondite en cada punto de la búsqueda.
@export_range(0.0, 1.0) var spot_check_chance := 0.4
@export var spot_search_radius := 8.0

@export_group("Oído según respeto")
@export var hearing_low_respect := 1.3
@export var hearing_high_respect := 0.8

var state := State.PATROL

var _player: Player
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _spawn_transform := Transform3D.IDENTITY
var _patrol_index := 0
var _state_timer := 0.0
var _unseen_time := 0.0
var _is_waiting := false
var _has_caught := false
var _last_known_position := Vector3.ZERO
var _move_target := Vector3.ZERO
var _move_speed := 0.0
var _known_spot: HidingSpot
var _checking_spot: HidingSpot

@onready var _agent: NavigationAgent3D = $NavigationAgent3D
@onready var _hearing: NoiseHearing = $NoiseHearing
@onready var _sight: PlayerSight = $Eyes
@onready var _stride_audio: StrideAudio = $StrideAudio
@onready var _voice: TioVoice = $Voice


## Busca al jugador, escucha el mundo y empieza a patrullar.
func _ready() -> void:
	_spawn_transform = global_transform
	_player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	_hearing.heard.connect(_on_heard)
	EventBus.offering_made.connect(_on_offering_made)
	EventBus.player_hid.connect(_on_player_hid)
	GameState.respect_changed.connect(_on_respect_changed)
	_on_respect_changed(GameState.respect)
	_enter_state(State.PATROL)


## Actualiza el estado, avanza por el camino, hace sonar sus pasos y revisa si atrapó al jugador.
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	if _has_caught:
		_move_speed = 0.0
	else:
		_update_state(delta)
	_follow_path(delta)
	var previous_position := global_position
	move_and_slide()
	var travelled := (global_position - previous_position) * HORIZONTAL_PLANE
	_stride_audio.register_movement(travelled.length(), travelled.length() / delta)
	_check_catch()


## Vuelve a su lugar inicial y a patrullar; se usa al reaparecer el jugador.
func reset() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_has_caught = false
	_patrol_index = 0
	_enter_state(State.PATROL)


## Deriva a la lógica del estado actual.
func _update_state(delta: float) -> void:
	match state:
		State.PATROL:
			_update_patrol(delta)
		State.SUSPICION:
			_update_suspicion(delta)
		State.HUNT:
			_update_hunt(delta)
		State.SEARCH:
			_update_search(delta)
		State.CALM:
			_update_calm(delta)


## Recorre los puntos de patrulla con una pausa en cada uno.
func _update_patrol(delta: float) -> void:
	if _sees_player():
		_enter_state(State.HUNT)
		return
	if patrol_points.is_empty():
		_move_speed = 0.0
		return
	if _is_waiting:
		_state_timer -= delta
		if _state_timer <= 0.0:
			_is_waiting = false
			_patrol_index = (_patrol_index + 1) % patrol_points.size()
			_go_to(patrol_points[_patrol_index].global_position, patrol_speed)
	elif _has_arrived():
		_is_waiting = true
		_state_timer = patrol_wait_seconds
		_move_speed = 0.0


## Va hacia el ruido, mira alrededor y, si no encuentra nada, vuelve a patrullar.
func _update_suspicion(delta: float) -> void:
	if _sees_player():
		_enter_state(State.HUNT)
		return
	if _has_arrived():
		_move_speed = 0.0
		rotation.y += LOOK_AROUND_SPEED * delta
		_state_timer -= delta
		if _state_timer <= 0.0:
			_enter_state(State.PATROL)


## Persigue al jugador; si lo pierde de vista un tiempo, pasa a buscarlo.
func _update_hunt(delta: float) -> void:
	if _sees_player():
		_unseen_time = 0.0
		_last_known_position = _player.global_position
	elif _known_spot:
		_last_known_position = _known_spot.get_exit_transform().origin
	else:
		_unseen_time += delta
		if _unseen_time >= lose_sight_seconds:
			_enter_state(State.SEARCH)
			return
	_go_to(_last_known_position, hunt_speed)


## Revisa puntos al azar cerca de donde lo perdió hasta que se acaba el tiempo.
func _update_search(delta: float) -> void:
	if _sees_player():
		_enter_state(State.HUNT)
		return
	_state_timer -= delta
	if _state_timer <= 0.0:
		_enter_state(State.PATROL)
	elif _has_arrived():
		_checking_spot = _pick_spot_to_check()
		if _checking_spot:
			_go_to(_checking_spot.get_exit_transform().origin, investigate_speed)
		else:
			_go_to(_random_point_near(_last_known_position), investigate_speed)


## Se retira mientras dura la calma y luego vuelve a patrullar.
func _update_calm(delta: float) -> void:
	_state_timer -= delta
	if _has_arrived():
		_move_speed = 0.0
	if _state_timer <= 0.0:
		_enter_state(State.PATROL)


## Cambia de estado y prepara lo que necesita al empezar.
func _enter_state(new_state: State) -> void:
	state = new_state
	_hearing.enabled = state != State.CALM
	_sight.enabled = state != State.CALM
	_voice.react_to_state(state)
	match state:
		State.PATROL:
			_start_patrol()
		State.SUSPICION:
			_state_timer = suspicion_look_seconds
			_go_to(_last_known_position, investigate_speed)
		State.HUNT:
			_unseen_time = 0.0
		State.SEARCH:
			_state_timer = _respect_lerp(search_seconds_low_respect, search_seconds_high_respect)
			_go_to(_last_known_position, investigate_speed)
		State.CALM:
			_state_timer = _respect_lerp(calm_seconds_low_respect, calm_seconds_high_respect)
			_go_to(_farthest_patrol_point_from_player(), patrol_speed)


## Retoma la patrulla hacia el punto actual y olvida los escondites.
func _start_patrol() -> void:
	_known_spot = null
	_checking_spot = null
	_is_waiting = false
	_move_speed = 0.0
	if not patrol_points.is_empty():
		_go_to(patrol_points[_patrol_index].global_position, patrol_speed)


## Fija el destino y la velocidad; no recalcula el camino por cambios mínimos.
func _go_to(target: Vector3, speed: float) -> void:
	_move_speed = speed
	if target.distance_to(_move_target) > RETARGET_DISTANCE or _agent.is_navigation_finished():
		_move_target = target
		_agent.target_position = target


## Dice si llegó al destino, o al punto más cercano si el destino no tiene camino.
func _has_arrived() -> bool:
	var offset := (_move_target - global_position) * HORIZONTAL_PLANE
	if offset.length() <= ARRIVAL_DISTANCE:
		return true
	return _agent.is_navigation_finished() and not _agent.is_target_reachable()


## Avanza hacia el siguiente punto del camino y gira hacia donde va.
func _follow_path(delta: float) -> void:
	var desired := Vector3.ZERO
	if _move_speed > 0.0 and not _has_arrived():
		var next_point := _agent.get_next_path_position()
		var direction := ((next_point - global_position) * HORIZONTAL_PLANE).normalized()
		desired = direction * _move_speed
		if direction != Vector3.ZERO:
			rotation.y = lerp_angle(
				rotation.y, atan2(-direction.x, -direction.z), TURN_SPEED * delta
			)
	velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)


## Aplica la gravedad mientras está en el aire.
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta


## Avisa una sola vez si alcanzó al jugador; escondido, solo si sabe o revisa ese escondite.
func _check_catch() -> void:
	if _has_caught or state == State.CALM or _player == null:
		return
	if _player.hiding_spot:
		_check_spot_catch(_player.hiding_spot)
		return
	var offset := (_player.global_position - global_position) * HORIZONTAL_PLANE
	if offset.length() <= CATCH_DISTANCE:
		_catch()


## Saca al jugador del escondite si lo vio entrar o lo está revisando y llegó a su salida.
func _check_spot_catch(spot: HidingSpot) -> void:
	if spot != _known_spot and spot != _checking_spot:
		return
	var offset := (spot.get_exit_transform().origin - global_position) * HORIZONTAL_PLANE
	if offset.length() <= SPOT_REACH:
		_catch()


## Marca la captura y la avisa.
func _catch() -> void:
	_has_caught = true
	EventBus.player_caught.emit()


## Elige al azar un escondite cercano a donde lo perdió, o ninguno.
func _pick_spot_to_check() -> HidingSpot:
	if randf() >= spot_check_chance:
		return null
	var nearby: Array[HidingSpot] = []
	for spot: HidingSpot in get_tree().get_nodes_in_group(HidingSpot.GROUP):
		if spot.global_position.distance_to(_last_known_position) <= spot_search_radius:
			nearby.append(spot)
	if nearby.is_empty():
		return null
	return nearby.pick_random()


## Dice si ve al jugador ahora.
func _sees_player() -> bool:
	return _sight.can_see(_player)


## Devuelve un punto caminable al azar cerca del indicado.
func _random_point_near(center: Vector3) -> Vector3:
	var offset := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * SEARCH_RADIUS
	return NavigationServer3D.map_get_closest_point(_agent.get_navigation_map(), center + offset)


## Devuelve el punto de patrulla más lejano al jugador, para retirarse.
func _farthest_patrol_point_from_player() -> Vector3:
	var farthest := global_position
	var best_distance := -1.0
	for point in patrol_points:
		var distance := point.global_position.distance_to(_player.global_position)
		if distance > best_distance:
			best_distance = distance
			farthest = point.global_position
	return farthest


## Interpola entre el valor con respeto bajo y con respeto alto.
func _respect_lerp(low_value: float, high_value: float) -> float:
	return lerpf(low_value, high_value, GameState.get_respect_ratio())


## Reacciona a un ruido según el estado: sospecha, o actualiza dónde buscar.
func _on_heard(origin: Vector3, _strength: float) -> void:
	match state:
		State.PATROL, State.SUSPICION:
			_last_known_position = origin
			_enter_state(State.SUSPICION)
		State.HUNT, State.SEARCH:
			_last_known_position = origin
			_go_to(origin, investigate_speed)


## Si está cazando y lo ve meterse en un escondite, recuerda cuál es.
func _on_player_hid(spot: HidingSpot) -> void:
	if state == State.HUNT and _sees_player():
		_known_spot = spot


## Una ofrenda lo calma, salvo que ya haya atrapado al jugador.
func _on_offering_made(_origin: Vector3, _type: ItemCatalog.Type) -> void:
	if not _has_caught:
		_enter_state(State.CALM)


## Con más respeto oye menos.
func _on_respect_changed(_value: float) -> void:
	_hearing.sensitivity = _respect_lerp(hearing_low_respect, hearing_high_respect)
