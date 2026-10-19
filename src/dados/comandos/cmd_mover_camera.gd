# Move a câmera para um ponto fixo do mapa.
class_name CmdMoverCamera
extends Comando

@export var posicao: Vector2 = Vector2.ZERO
## 0 = instantâneo.
@export var tempo: float = 0.0

func to_dict() -> Dictionary:
	return {"nome": "mover_camera", "args": [posicao.x, posicao.y, tempo]}

func executar(interp, _ev) -> int:
	var cam = interp.get_camera()
	if cam and cam.has_method("mover_camera"):
		cam.mover_camera(posicao, tempo)
	return AVANCAR
