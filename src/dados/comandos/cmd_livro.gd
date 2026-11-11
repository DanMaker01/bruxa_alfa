# Abre o livro de receitas (CenaLivro); o evento espera o livro fechar.
class_name CmdLivro
extends Comando

const CENA := "res://scenes/cena_livro.tscn"
## Camada do livro (acima do mundo; o HUD fica livre embaixo, fora da área do livro).
const CAMADA: int = 5

func to_dict() -> Dictionary:
	return {"nome": "abrir_livro", "args": []}

func executar(interp, ev) -> int:
	var cena: PackedScene = load(CENA)
	if cena == null:
		interp.falhar(ev, self, "cena do livro não encontrada")
		return AVANCAR
	var camada := CanvasLayer.new()
	camada.layer = CAMADA
	camada.process_mode = Node.PROCESS_MODE_ALWAYS
	interp.get_tree().root.add_child(camada)
	var livro = cena.instantiate()
	livro.process_mode = Node.PROCESS_MODE_ALWAYS
	camada.add_child(livro)
	ev.pause("livro")
	livro.fechou.connect(_ao_fechar.bind(ev, camada))
	return MANTER

func _ao_fechar(ev, camada: CanvasLayer) -> void:
	if is_instance_valid(camada):
		camada.queue_free()
	if not ev.finished and ev.pause_reason == "livro":
		ev.resume_and_advance()
