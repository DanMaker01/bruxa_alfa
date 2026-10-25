# Muda o estilo da janela de diálogo para as próximas falas (até mudar de novo ou restaurar).
# Ex.: antes de um sonho, fundo tracejado e texto em onda; depois, "restaurar".
# Pensamento da bruxa: itálico + cor apagada + face_pensando + esconder_nome + vinheta.
class_name CmdEstiloDialogo
extends Comando

enum Efeito { NENHUM, ONDA, TREMOR }
enum Fundo { NORMAL, TRACEJADO, NENHUM }
const EFEITOS := ["", "onda", "tremor"]
const FUNDOS := ["normal", "tracejado", "nenhum"]

## Ligado: volta tudo ao padrão (ignora o resto).
@export var restaurar: bool = false
## 0 = tamanho padrão.
@export var tamanho_fonte: int = 0
@export var cor_texto: Color = Color.WHITE
@export var italico: bool = false
@export var efeito: Efeito = Efeito.NENHUM
## 1 = fundo opaco, 0 = invisível.
@export_range(0.0, 1.0, 0.05) var transparencia: float = 1.0
@export var fundo: Fundo = Fundo.NORMAL
@export_group("Pensamento")
## Usa a face <face>_pensando (ex.: bruxa_grande → bruxa_pensando), se existir.
@export var face_pensando: bool = false
@export var esconder_nome: bool = false
## Bordas da tela escurecem.
@export var vinheta: bool = false

func to_dict() -> Dictionary:
	return {"nome": "estilo_dialogo", "args": ["restaurar"] if restaurar else [tamanho_fonte, italico, EFEITOS[efeito], transparencia, FUNDOS[fundo]]}

func executar(interp, ev) -> int:
	var caixa = interp.get_tree().get_first_node_in_group("caixa_dialogo")
	if caixa == null or not caixa.has_method("definir_estilo"):
		interp.falhar(ev, self, "caixa de diálogo não encontrada")
		return AVANCAR
	if restaurar:
		caixa.restaurar_estilo()
	else:
		caixa.definir_estilo({"tamanho_fonte": tamanho_fonte, "cor": cor_texto, "italico": italico,
			"efeito": EFEITOS[efeito], "transparencia": transparencia, "fundo": FUNDOS[fundo],
			"face_pensando": face_pensando, "esconder_nome": esconder_nome, "vinheta": vinheta})
	return AVANCAR
