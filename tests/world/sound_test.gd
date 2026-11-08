extends TestCase
## Pruebas del sonido: los pasos suenan, el goteo se programa y el ambiente se repite.

const TUNNEL_SCENE := preload("res://src/world/test_tunnel/test_tunnel.tscn")
const SETTLE_FRAMES := 10
const WALK_FRAMES := 60

var _tunnel: Node3D
var _player: Player


## Carga el túnel.
func before_each() -> void:
	_tunnel = TUNNEL_SCENE.instantiate()
	add_to_tree(_tunnel)
	_player = _tunnel.get_node("Player")


## Suelta las teclas y libera el túnel.
func after_each() -> void:
	Input.action_release("move_forward")
	_tunnel.free()


## Caminar hace sonar las pisadas.
func test_walking_plays_footsteps() -> void:
	var audio: AudioStreamPlayer3D = _player.get_node("FootstepComponent/Audio")
	var started := [false]
	audio.finished.connect(func() -> void: started[0] = true)
	await wait_physics_frames(SETTLE_FRAMES)
	Input.action_press("move_forward")
	var heard := false
	for i in WALK_FRAMES:
		await tree.physics_frame
		heard = heard or audio.playing or started[0]
	assert_true(heard, "Las pisadas deben sonar al caminar")


## Cada gotera tiene su próxima gota programada.
func test_drips_are_scheduled() -> void:
	for drip: DripEmitter in _tunnel.get_node("Drips").get_children():
		var timer: Timer = drip.get_node("Timer")
		assert_false(timer.is_stopped(), "La gotera %s debe tener una gota programada" % drip.name)


## El ambiente de la mina se repite sin fin.
func test_ambience_loops() -> void:
	var ambience: AudioStreamPlayer = _tunnel.get_node("Ambience")
	var stream := ambience.stream as AudioStreamWAV
	assert_true(stream.loop_mode != AudioStreamWAV.LOOP_DISABLED, "El ambiente debe repetirse")
	assert_true(ambience.playing, "El ambiente debe sonar al empezar")
