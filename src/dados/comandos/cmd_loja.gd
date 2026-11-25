# cmd_loja.gd
# Abre o menu de troca com um mercador (MenuLoja): o inventário da bruxa, o estoque dele
# e uma mesa no meio. Comprar e vender são a mesma coisa: os itens vão de um lado para o
# outro, mais um ouro na mesa (campo separado, não é item).
# O valor de cada item para o mercador = valor_base · qtd_base / (qtd_base + qtd que ele tem)
# (ItemData, grupo Comércio). Ele aceita se o que recebe valer pelo menos (1 + margem) vezes
# o que dá.
# O estoque e o ouro do mercador ficam guardados no GameTemp (variável "loja_<id_loja>"),
# então o que foi vendido continua vendido na próxima visita.
# A variável recebe o número de trocas feitas (0 = saiu sem trocar; use com if).
class_name CmdLoja
extends Comando

## Identificador da loja (guarda estoque e ouro dele entre as visitas).
@export var id_loja: String = "mercador"
## Face e nome do mercador.
@export var personagem: Personagem
## Estoque inicial: id do item -> quantidade (só na primeira visita).
@export var estoque: Dictionary[String, int] = {}
## Ouro do mercador na primeira visita.
@export var ouro_mercador: int = 100
## Lucro que ele quer: 0.2 = recebe pelo menos 1,2× o que dá.
@export_range(0.0, 2.0, 0.05) var margem: float = 0.2
## Variável que recebe o número de trocas feitas.
@export var variavel: String = "loja_trocas"

const VAR_OURO := "ouro"

func to_dict() -> Dictionary:
	return {"nome": "loja", "args": [id_loja, estoque.size(), margem]}

func executar(interp, ev) -> int:
	var gt = interp.game_temp
	var camada = interp.get_node_or_null("/root/Main/CanvasLayer")
	if gt == null or camada == null or interp.database == null:
		interp.falhar(ev, self, "sem GameTemp/CanvasLayer/database")
		return AVANCAR
	ev.pause("loja")
	_abrir(interp, ev, gt, camada)
	return MANTER

func _abrir(interp, ev, gt, camada) -> void:
	var chave := "loja_" + id_loja
	var estado = gt.get_var(chave) if gt.has_var(chave) else null
	if not (estado is Dictionary) or not estado.has("estoque"):
		estado = {"estoque": estoque.duplicate(), "ouro": ouro_mercador}
	var menu := MenuLoja.new()
	camada.add_child(menu)
	menu.abrir({
		"gt": gt, "db": interp.database, "personagem": personagem,
		"estoque": (estado["estoque"] as Dictionary).duplicate(), "ouro_mercador": int(estado["ouro"]),
		"margem": margem, "var_ouro": VAR_OURO,
	})
	var trocas: int = await menu.fechou
	gt.set_var(chave, {"estoque": menu.estoque, "ouro": menu.ouro_mercador})
	var antigo = gt.get_var(variavel) if gt.has_var(variavel) else null
	gt.set_var(variavel, float(trocas))
	interp.variable_changed.emit(variavel, antigo, float(trocas))
	if not ev.finished and ev.pause_reason == "loja":
		ev.resume_and_advance()
