# som_ambiente.gd
# Um som de ambiente (BGS) a mais no mapa: arquivo em res://audio/bgs/ e volume próprio.
class_name SomAmbiente
extends Resource

@export_file("*.mp3") var arquivo: String = ""
@export_range(0.0, 1.0, 0.01) var volume: float = 0.5
