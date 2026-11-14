class_name EnvironmentQuality
extends WorldEnvironment
## Ambiente que sigue el ajuste de calidad: en baja apaga los efectos de luz y niebla más caros.


## Aplica la calidad guardada y la vuelve a aplicar cuando cambia.
func _ready() -> void:
	Settings.changed.connect(_apply)
	_apply()


## Enciende o apaga los efectos caros según el ajuste.
func _apply() -> void:
	environment.sdfgi_enabled = Settings.high_quality
	environment.ssil_enabled = Settings.high_quality
	environment.volumetric_fog_enabled = Settings.high_quality
