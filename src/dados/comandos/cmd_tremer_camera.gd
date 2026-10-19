# Faz a câmera tremer.
class_name CmdTremerCamera
extends Comando

@export var intensidade: float = 10.0
@export var velocidade: float = 0.1
@export var duracao: float = 1.0

func to_dict() -> Dictionary:
	return {"nome": "tremer_camera", "args": [intensidade, velocidade, duracao]}

func executar(interp, _ev) -> int:
	var cam = interp.get_camera()
	if cam and cam.has_method("tremer_camera"):
		cam.tremer_camera(intensidade, velocidade, duracao)
	return AVANCAR
