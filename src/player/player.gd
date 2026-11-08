class_name Player
extends CharacterBody3D
## Mateo: lee la entrada, ordena a sus componentes y publica eventos en EventBus.

signal move_state_changed(state: MoveState)

enum MoveState { IDLE, WALK, SPRINT, CROUCH }

const HORIZONTAL_PLANE := Vector3(1.0, 0.0, 1.0)
const CROUCH_HEIGHT_TOLERANCE := 0.05
## Segundos de llama media que da una carga de carburo.
const CARBIDE_FUEL := 150.0
const REFILLED_NOTICE := "Recargaste la lámpara"
const NO_CARBIDE_NOTICE := "No tienes carburo"
const LAMP_FULL_NOTICE := "La lámpara está llena"
const NO_STONES_NOTICE := "No tienes piedras"

@export_group("Velocidades (m/s)")
@export var walk_speed := 2.4
@export var sprint_speed := 4.6
@export var crouch_speed := 1.2

@export_group("Aceleración")
@export var acceleration := 10.0
@export var deceleration := 14.0
@export var air_control := 0.3

@export_group("Agacharse")
@export var stand_height := 1.8
@export var crouch_height := 1.1
## Distancia desde los ojos hasta la coronilla.
@export var eye_offset := 0.15
@export var crouch_transition_speed := 9.0
## Falso: hay que mantener la tecla. Verdadero: se alterna con cada pulsación.
@export var crouch_toggles := false

var move_state := MoveState.IDLE

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _capsule: CapsuleShape3D
var _is_crouch_requested := false

@onready var inventory: InventoryComponent = $InventoryComponent
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _ceiling_check: ShapeCast3D = $CeilingCheck
@onready var _head: FirstPersonCamera = $Head
@onready var _stamina: StaminaComponent = $StaminaComponent
@onready var _footsteps: FootstepComponent = $FootstepComponent
@onready var _lamp: CarbideLamp = $Head/Camera3D/CarbideLamp
@onready var _interactor: Interactor = $Head/Camera3D/Interactor
@onready var _stone_thrower: StoneThrower = $Head/Camera3D/StoneThrower


## Prepara la cápsula, conecta los componentes y pone al jugador de pie.
func _ready() -> void:
	_capsule = _collision.shape as CapsuleShape3D
	_connect_components()
	_apply_height(stand_height)
	_head.position.y = stand_height - eye_offset


## Atiende las acciones de una sola pulsación: usar, lámpara, lanzar y agacharse alterno.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interactor.try_interact(self)
	elif event.is_action_pressed("lamp_refill"):
		refill_lamp()
	elif event.is_action_pressed("throw") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		throw_stone()
	elif event.is_action_pressed("lamp_toggle"):
		_lamp.toggle()
	elif event.is_action_pressed("lamp_increase"):
		_lamp.increase_level()
	elif event.is_action_pressed("lamp_decrease"):
		_lamp.decrease_level()
	elif crouch_toggles and event.is_action_pressed("crouch"):
		_is_crouch_requested = not _is_crouch_requested


## Mueve al jugador y alimenta a la cabeza, la estamina y los pasos.
func _physics_process(delta: float) -> void:
	if not crouch_toggles:
		_is_crouch_requested = Input.is_action_pressed("crouch")

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_update_crouch(delta)
	_update_move_state(input_dir)
	_stamina.set_draining(move_state == MoveState.SPRINT)

	var previous_position := global_position
	_apply_gravity(delta)
	_apply_movement(input_dir, delta)
	move_and_slide()

	var travelled := (global_position - previous_position) * HORIZONTAL_PLANE
	_footsteps.register_movement(travelled.length(), move_state, global_position)
	_head.update_bob(delta, _horizontal_speed() / walk_speed, is_on_floor())
	_interactor.update_focus(self)


## Gasta un carburo de la bolsa para recargar la lámpara.
func refill_lamp() -> void:
	if _lamp.get_fuel_ratio() >= 1.0:
		EventBus.notice_requested.emit(LAMP_FULL_NOTICE)
	elif inventory.remove(ItemCatalog.Type.CARBIDE):
		_lamp.add_fuel(CARBIDE_FUEL)
		_lamp.set_lit(true)
		EventBus.notice_requested.emit(REFILLED_NOTICE)
	else:
		EventBus.notice_requested.emit(NO_CARBIDE_NOTICE)


## Lanza una piedra de la bolsa hacia donde mira.
func throw_stone() -> void:
	if inventory.remove(ItemCatalog.Type.STONE):
		_stone_thrower.throw(get_parent(), velocity)
	else:
		EventBus.notice_requested.emit(NO_STONES_NOTICE)


## Dice si la cápsula está por debajo de la altura de pie.
func is_crouching() -> bool:
	return _capsule.height < stand_height - CROUCH_HEIGHT_TOLERANCE


## Reenvía las señales de los componentes al bus y publica su estado inicial.
func _connect_components() -> void:
	_stamina.changed.connect(EventBus.stamina_changed.emit)
	_lamp.fuel_changed.connect(EventBus.lamp_fuel_changed.emit)
	_lamp.state_changed.connect(_on_lamp_state_changed)
	_interactor.focus_changed.connect(EventBus.interaction_prompt_changed.emit)
	inventory.changed.connect(EventBus.inventory_changed.emit)
	# Los componentes emitieron su estado en su _ready, que corre antes que este.
	EventBus.stamina_changed.emit(_stamina.current, _stamina.max_stamina)
	EventBus.lamp_fuel_changed.emit(_lamp.fuel, _lamp.max_fuel)
	_on_lamp_state_changed(_lamp.is_lit, _lamp.level)


## Elige quieto, caminar, correr o agachado según la entrada y el aliento.
func _update_move_state(input_dir: Vector2) -> void:
	var new_state := MoveState.WALK
	if input_dir == Vector2.ZERO:
		new_state = MoveState.IDLE
	elif _is_crouch_requested or is_crouching():
		new_state = MoveState.CROUCH
	elif Input.is_action_pressed("sprint") and input_dir.y < 0.0 and _stamina.can_sprint():
		new_state = MoveState.SPRINT
	if new_state != move_state:
		move_state = new_state
		move_state_changed.emit(move_state)


## Devuelve la velocidad máxima del estado actual.
func _speed_for_state() -> float:
	match move_state:
		MoveState.SPRINT:
			return sprint_speed
		MoveState.CROUCH:
			return crouch_speed
		_:
			return walk_speed


## Aplica la gravedad mientras está en el aire.
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta


## Acelera hacia la dirección pedida, con menos control en el aire.
func _apply_movement(input_dir: Vector2, delta: float) -> void:
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var target := direction * _speed_for_state()
	var rate := deceleration
	if direction != Vector3.ZERO:
		rate = acceleration
	if not is_on_floor():
		rate *= air_control
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)


## Agacha o levanta al jugador; no se levanta si hay techo encima.
func _update_crouch(delta: float) -> void:
	var target_height := crouch_height
	if not _is_crouch_requested and not _ceiling_check.is_colliding():
		target_height = stand_height
	_apply_height(lerpf(_capsule.height, target_height, crouch_transition_speed * delta))
	_head.set_target_height(target_height - eye_offset)


## Ajusta la cápsula para que sus pies sigan en el suelo.
func _apply_height(height: float) -> void:
	_capsule.height = height
	_collision.position.y = height / 2.0


## Devuelve la rapidez en el plano del suelo.
func _horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Publica el estado de la lámpara y cuánto delata al jugador.
func _on_lamp_state_changed(is_lit: bool, level: int) -> void:
	EventBus.lamp_state_changed.emit(is_lit, level)
	EventBus.player_light_changed.emit(_lamp.get_light_intensity())
