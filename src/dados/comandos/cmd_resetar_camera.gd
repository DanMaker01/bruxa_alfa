# Volta a câmera a seguir a bruxa.
class_name CmdResetarCamera
extends Comando

## 0 = instantâneo.
@export var tempo: float = 0.0

func to_dict() -> Dictionary:
	return {"nome": "resetar_camera", "args": [tempo]}

func executar(interp, _ev) -> int:
	var cam = interp.get_camera()
	if cam and cam.has_method("resetar_posicao_camera"):
		cam.resetar_posicao_camera(tempo)
	return AVANCAR
