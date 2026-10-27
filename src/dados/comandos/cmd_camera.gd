# Câmera: mover para um ponto, voltar a seguir a bruxa ou tremer.
# Junta os antigos mover_camera, resetar_camera e tremer_camera.
class_name CmdCamera
extends Comando

enum Acao { MOVER, VOLTAR, TREMER }
const ACOES := ["mover", "voltar", "tremer"]

@export var acao: Acao = Acao.MOVER:
	set(v):
		acao = v
		notify_property_list_changed()
## Ponto do mapa (acao = MOVER).
@export var posicao: Vector2 = Vector2.ZERO
## Duração do movimento (s). 0 = instantâneo (MOVER e VOLTAR).
@export var tempo: float = 0.0
## TREMER: força (px), intervalo entre sacudidas (s) e duração (s).
@export var intensidade: float = 10.0
@export var velocidade: float = 0.1
@export var duracao: float = 1.0

func to_dict() -> Dictionary:
	var args: Array = [ACOES[acao]]
	match acao:
		Acao.MOVER: args += [posicao.x, posicao.y, tempo]
		Acao.VOLTAR: args += [tempo]
		Acao.TREMER: args += [intensidade, velocidade, duracao]
	return {"nome": "camera", "args": args}

func executar(interp, _ev) -> int:
	var cam = interp.get_camera()
	if cam == null:
		return AVANCAR
	match acao:
		Acao.MOVER:
			if cam.has_method("mover_camera"):
				cam.mover_camera(posicao, tempo)
		Acao.VOLTAR:
			if cam.has_method("resetar_posicao_camera"):
				cam.resetar_posicao_camera(tempo)
		Acao.TREMER:
			if cam.has_method("tremer_camera"):
				cam.tremer_camera(intensidade, velocidade, duracao)
	return AVANCAR

func _validate_property(property: Dictionary) -> void:
	var mostrar := true
	match property.name:
		"posicao": mostrar = acao == Acao.MOVER
		"tempo": mostrar = acao != Acao.TREMER
		"intensidade", "velocidade", "duracao": mostrar = acao == Acao.TREMER
		_: return
	if not mostrar:
		property.usage = PROPERTY_USAGE_STORAGE
