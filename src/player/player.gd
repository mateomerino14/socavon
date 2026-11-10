class_name Player
extends CharacterBody3D
## Mateo: lee la entrada, ordena a sus componentes y publica eventos en EventBus.

enum MoveState { IDLE, WALK, SPRINT, CROUCH }

const HORIZONTAL_PLANE := Vector3(1.0, 0.0, 1.0)
const CROUCH_HEIGHT_TOLERANCE := 0.05
## Segundos de llama media que da una carga de carburo.
const CARBIDE_FUEL := 150.0
const REFILLED_NOTICE := "Recargaste la lámpara"
const NO_CARBIDE_NOTICE := "No tienes carburo"
const LAMP_FULL_NOTICE := "La lámpara está llena"
const NO_STONES_NOTICE := "No tienes piedras"
## Grupo declarado en player.tscn; así el Tío lo encuentra aunque esté antes en el árbol.
const GROUP := &"player"
## Distancia que se deja entre la cabeza y la pared al asomarse.
const LEAN_WALL_MARGIN := 0.2
const HIDE_SECONDS := 0.7
const LEAVE_HIDING_PROMPT := "Salir del escondite"

@export_group("Velocidades (m/s)")
@export var walk_speed := 2.4
@export var sprint_speed := 4.6
@export var crouch_speed := 1.2

## Fracción de la velocidad que conserva al caminar por agua.
@export_range(0.1, 1.0) var wading_speed_scale := 0.65

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

var move_state := MoveState.IDLE
## Falso: hay que mantener la tecla. Verdadero: se alterna con cada pulsación. Viene de Settings.
var crouch_toggles := false
## Verdadero solo cuando ya terminó de meterse en el escondite.
var is_hidden := false
## Escondite donde está o al que está entrando; nulo si no se esconde.
var hiding_spot: HidingSpot

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _capsule: CapsuleShape3D
var _is_crouch_requested := false
var _controls_enabled := true
var _hiding_tween: Tween
var _water_contacts := 0

@onready var inventory: InventoryComponent = $InventoryComponent
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var _ceiling_check: ShapeCast3D = $CeilingCheck
@onready var _head: FirstPersonCamera = $Head
@onready var _stamina: StaminaComponent = $StaminaComponent
@onready var _footsteps: FootstepComponent = $FootstepComponent
@onready var _lamp: CarbideLamp = $Head/Camera3D/CarbideLamp
@onready var _interactor: Interactor = $Head/Camera3D/Interactor
@onready var _stone_thrower: StoneThrower = $Head/Camera3D/StoneThrower
@onready var _dread_sense: DreadSense = $DreadSense
@onready var _listen: ListenComponent = $ListenComponent
@onready var _lean_check: RayCast3D = $LeanCheck
@onready var _camera: Camera3D = $Head/Camera3D
@onready var _caught_reaction: CaughtReaction = $CaughtReaction


## Prepara la cápsula, conecta los componentes y pone al jugador de pie.
func _ready() -> void:
	_capsule = _collision.shape as CapsuleShape3D
	_connect_components()
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	_apply_height(stand_height)
	_head.position.y = stand_height - eye_offset


## Atiende las acciones de una sola pulsación: usar, lámpara, lanzar y agacharse alterno.
func _unhandled_input(event: InputEvent) -> void:
	if not _controls_enabled:
		return
	if hiding_spot and event.is_action_pressed("interact"):
		leave_hiding()
	elif event.is_action_pressed("interact"):
		_interactor.try_interact(self)
	elif event.is_action_pressed("lamp_refill"):
		refill_lamp()
	elif event.is_action_pressed("throw") and _can_throw():
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
	if hiding_spot:
		_update_while_hidden(delta)
		return
	var input_dir := Vector2.ZERO
	var is_listening := false
	var lean := 0.0
	if _controls_enabled:
		is_listening = Input.is_action_pressed("listen")
		lean = Input.get_axis("lean_left", "lean_right")
		if not is_listening:
			input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if not crouch_toggles:
			_is_crouch_requested = Input.is_action_pressed("crouch")
	_listen.set_listening(is_listening)
	_listen.update_listening(delta, _camera)
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
	if move_state == MoveState.SPRINT:
		lean = 0.0
	_head.update_lean(delta, lean, _free_space_to_side(lean))
	_interactor.update_focus(self)
	_lamp.set_dread(_dread_sense.update_dread())


## Se mete en el escondite con una animación; queda escondido al terminar.
func hide_in(spot: HidingSpot) -> void:
	if hiding_spot:
		return
	hiding_spot = spot
	EventBus.player_hid.emit(spot)
	velocity = Vector3.ZERO
	_collision.disabled = true
	_is_crouch_requested = true
	_apply_height(crouch_height)
	_head.set_target_height(crouch_height - eye_offset)
	_hiding_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_hiding_tween.tween_property(self, "global_transform", spot.get_hide_transform(), HIDE_SECONDS)
	await _hiding_tween.finished
	is_hidden = true
	EventBus.interaction_prompt_changed.emit(LEAVE_HIDING_PROMPT)


## Sale del escondite con una animación.
func leave_hiding() -> void:
	if not is_hidden:
		return
	is_hidden = false
	EventBus.interaction_prompt_changed.emit("")
	_hiding_tween = create_tween().set_trans(Tween.TRANS_SINE)
	var exit := hiding_spot.get_exit_transform()
	_hiding_tween.tween_property(self, "global_transform", exit, HIDE_SECONDS)
	await _hiding_tween.finished
	_finish_hiding()


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


## Activa o desactiva la entrada del jugador, por ejemplo durante la muerte.
func set_controls_enabled(enabled: bool) -> void:
	_controls_enabled = enabled
	_head.look_enabled = enabled


## Lleva al jugador al punto indicado, de pie, quieto, con aliento lleno y la lámpara encendida.
func respawn_at(spawn: Transform3D) -> void:
	if _hiding_tween:
		_hiding_tween.kill()
	_finish_hiding()
	_caught_reaction.reset()
	global_transform = spawn
	velocity = Vector3.ZERO
	_is_crouch_requested = false
	_apply_height(stand_height)
	_head.reset_look()
	_stamina.refill()
	_lamp.set_lit(true)


## Devuelve la posición de los ojos, que es lo que el Tío intenta ver.
func get_eye_position() -> Vector3:
	return _head.global_position


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
	move_state = new_state


## Entra a una zona de agua; las zonas pueden tocarse, por eso se cuentan.
func enter_water() -> void:
	_water_contacts += 1
	_footsteps.set_wet(is_wading())


## Sale de una zona de agua.
func leave_water() -> void:
	_water_contacts = maxi(_water_contacts - 1, 0)
	_footsteps.set_wet(is_wading())


## Dice si está con los pies en el agua: camina más lento y sus pasos chapotean.
func is_wading() -> bool:
	return _water_contacts > 0


## Devuelve la velocidad máxima del estado actual, más lenta dentro del agua.
func _speed_for_state() -> float:
	var speed := walk_speed
	match move_state:
		MoveState.SPRINT:
			speed = sprint_speed
		MoveState.CROUCH:
			speed = crouch_speed
	if is_wading():
		speed *= wading_speed_scale
	return speed


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


## Escondido solo escucha y siente al Tío; no se mueve ni hace ruido.
func _update_while_hidden(delta: float) -> void:
	_listen.set_listening(_controls_enabled and Input.is_action_pressed("listen"))
	_listen.update_listening(delta, _camera)
	_head.update_bob(delta, 0.0, true)
	_lamp.set_dread(_dread_sense.update_dread())


## Vuelve al estado normal: con colisión y sin escondite.
func _finish_hiding() -> void:
	is_hidden = false
	hiding_spot = null
	_collision.disabled = false
	_is_crouch_requested = false


## Dice si se puede lanzar: con el ratón capturado y fuera de un escondite.
func _can_throw() -> bool:
	return hiding_spot == null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## Devuelve cuánto puede asomarse hacia ese lado antes de tocar la pared.
func _free_space_to_side(direction: float) -> float:
	if direction == 0.0:
		return _head.lean_distance
	_lean_check.position.y = _head.position.y
	_lean_check.target_position = Vector3(
		signf(direction) * (_head.lean_distance + LEAN_WALL_MARGIN), 0, 0
	)
	_lean_check.force_raycast_update()
	if not _lean_check.is_colliding():
		return _head.lean_distance
	var distance := _lean_check.global_position.distance_to(_lean_check.get_collision_point())
	return maxf(distance - LEAN_WALL_MARGIN, 0.0)


## Aplica los ajustes del jugador a la entrada y a la mirada.
func _apply_settings() -> void:
	crouch_toggles = Settings.crouch_toggles
	_head.sensitivity_scale = Settings.mouse_sensitivity


## Publica cuánto delata la lámpara al jugador.
func _on_lamp_state_changed(_is_lit: bool, _level: int) -> void:
	EventBus.player_light_changed.emit(_lamp.get_light_intensity())
