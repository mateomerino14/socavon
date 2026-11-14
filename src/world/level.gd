class_name Level
extends Node3D
## Raíz de cada nivel: arranca o restaura la partida, la guarda en cada punto, anuncia su nombre y
## da el primer objetivo. Si se llega desde un tránsito, el nivel aparece desde el negro.

## Segundos que tarda en aclararse la pantalla al llegar desde un tránsito.
const ARRIVAL_FADE_SECONDS := 1.5
## Capa del negro de llegada, por encima del HUD.
const ARRIVAL_LAYER := 9
## Segundos entre que se ve el nivel y aparece su nombre, y entre el nombre y el objetivo.
const TITLE_DELAY_SECONDS := 1.0
const OBJECTIVE_DELAY_SECONDS := 2.5

## Nombre que se muestra al empezar; vacío si el nivel abre con su propia cinemática.
@export var title := ""
## Lo primero que tiene que hacer el jugador en este nivel.
@export var objective := ""

@onready var _player: Player = $Player


## Sigue la partida que viene del nivel anterior o empieza una nueva, restaura una partida pendiente
## o guarda el inicio, y presenta el nivel.
func _ready() -> void:
	GameState.checkpoint_saved.connect(_on_checkpoint_saved)
	if GameState.is_carrying():
		GameState.start_next_level()
		_fill_bag(GameState.take_carried_bag())
	else:
		GameState.reset()
	var pending := SaveGame.take_pending()
	if pending.is_empty():
		GameState.save_checkpoint(_player.global_transform)
	else:
		_restore(pending)
	if Transition.take_arrival():
		_fade_in_from_black()
	_present.call_deferred(pending.get("objetivo", "") as String)


## Programa el nombre del nivel y luego el objetivo: el guardado o, si no hay, el primero del nivel.
## Los temporizadores se sueltan solos si el nivel se cierra antes.
func _present(saved_objective: String) -> void:
	var first := objective
	if not saved_objective.is_empty():
		first = saved_objective
	get_tree().create_timer(TITLE_DELAY_SECONDS).timeout.connect(_show_title.bind(first))


## Anuncia el nombre y deja programado el objetivo.
func _show_title(first_objective: String) -> void:
	if not title.is_empty():
		EventBus.level_title_requested.emit(title)
	get_tree().create_timer(OBJECTIVE_DELAY_SECONDS).timeout.connect(
		_give_objective.bind(first_objective)
	)


## Da el objetivo, si para entonces no hay otro más nuevo.
func _give_objective(first_objective: String) -> void:
	if not first_objective.is_empty() and GameState.objective.is_empty():
		GameState.set_objective(first_objective)


## Empieza en negro, como terminó el tránsito, y aclara la pantalla.
func _fade_in_from_black() -> void:
	var layer := CanvasLayer.new()
	layer.layer = ARRIVAL_LAYER
	var curtain := ColorRect.new()
	curtain.color = Color.BLACK
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(curtain)
	add_child(layer)
	var tween := create_tween()
	tween.tween_property(curtain, "modulate:a", 0.0, ARRIVAL_FADE_SECONDS)
	tween.tween_callback(layer.queue_free)


## Deja la partida como estaba guardada y al jugador en su último punto.
func _restore(pending: Dictionary) -> void:
	GameState.add_respect(pending["respeto"] - GameState.respect)
	GameState.has_paid = pending["pagado"]
	GameState.read_notes = pending["notas"]
	_fill_bag(pending["bolsa"])
	var checkpoint: Transform3D = pending["punto"]
	_player.respawn_at(checkpoint)
	GameState.save_checkpoint(checkpoint)


## Pone en la bolsa del jugador lo que traía.
func _fill_bag(bag: Dictionary) -> void:
	for type: ItemCatalog.Type in bag:
		_player.inventory.add(type, bag[type])


## Cada punto de guardado también queda en disco.
func _on_checkpoint_saved() -> void:
	SaveGame.save(scene_file_path, _player.inventory)
