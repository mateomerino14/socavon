class_name Pickup
extends Node3D
## Objeto en el suelo que el jugador recoge a su bolsa.

const PICK_PROMPT := "Recoger %s"
const FULL_PROMPT := "No cabe más %s"

## Aspecto provisional por tipo hasta tener modelos de Blender: tamaño y color.
const PLACEHOLDER_SIZE := {
	ItemCatalog.Type.CARBIDE: Vector3(0.14, 0.1, 0.14),
	ItemCatalog.Type.COCA: Vector3(0.18, 0.06, 0.12),
	ItemCatalog.Type.ALCOHOL: Vector3(0.07, 0.22, 0.07),
	ItemCatalog.Type.CIGARETTE: Vector3(0.12, 0.03, 0.06),
	ItemCatalog.Type.STONE: Vector3(0.12, 0.09, 0.11),
}
const PLACEHOLDER_COLOR := {
	ItemCatalog.Type.CARBIDE: Color(0.55, 0.57, 0.6),
	ItemCatalog.Type.COCA: Color(0.25, 0.45, 0.18),
	ItemCatalog.Type.ALCOHOL: Color(0.75, 0.82, 0.85),
	ItemCatalog.Type.CIGARETTE: Color(0.9, 0.88, 0.8),
	ItemCatalog.Type.STONE: Color(0.42, 0.38, 0.34),
}

@export var item_type := ItemCatalog.Type.COCA
@export var amount := 1

@onready var _interactable: Interactable = $Interactable
@onready var _mesh: MeshInstance3D = $Mesh


## Conecta la interacción y pone el aspecto provisional.
func _ready() -> void:
	_interactable.set_prompt_builder(_build_prompt)
	_interactable.interacted.connect(_on_interacted)
	_apply_placeholder_look()


## Arma el texto según si cabe en la bolsa.
func _build_prompt(player: Player) -> String:
	var item_name := ItemCatalog.display_name(item_type)
	if player.inventory.can_add(item_type):
		return PICK_PROMPT % item_name
	return FULL_PROMPT % item_name


## Pasa el objeto a la bolsa y desaparece si entró.
func _on_interacted(player: Player) -> void:
	if player.inventory.add(item_type, amount):
		queue_free()


## Da al objeto una caja del tamaño y color de su tipo.
func _apply_placeholder_look() -> void:
	var box := BoxMesh.new()
	box.size = PLACEHOLDER_SIZE.get(item_type, Vector3.ONE * 0.1)
	var material := StandardMaterial3D.new()
	material.albedo_color = PLACEHOLDER_COLOR.get(item_type, Color.WHITE)
	box.material = material
	_mesh.mesh = box
	_mesh.position.y = box.size.y / 2.0
