# gravador_jogadas.gd
# Só em build de debug: grava cada preparo num JSON (user://jogadas/), para a ferramenta de
# balanceamento (ferramentas/balanceamento.py) comparar jogadas reais com o simulador e
# calibrar a "jogadora" simulada.
#   histórico T(t)/F(t) (a cada 0,05 s), entradas dos itens, ações (+Fogo, −Fogo, acender,
#   jogar item), receita memorizada (se houver) e o aproveitamento de cada item.
class_name GravadorJogadas
extends RefCounted

const PASTA := "user://jogadas"

var acoes: Array = []   # [t, "tipo", detalhe]

func limpar() -> void:
	acoes.clear()

func acao(t: float, tipo: String, detalhe: String = "") -> void:
	if OS.is_debug_build():
		acoes.append([snappedf(t, 0.01), tipo, detalhe])

func salvar(historico: Array, ingredientes: Array, t_final: float, resultado: Dictionary, receita: Dictionary) -> void:
	if not OS.is_debug_build():
		return
	DirAccess.make_dir_recursive_absolute(PASTA)
	var hist: Array = []
	for p in historico:
		hist.append([snappedf(float(p["t"]), 0.001), snappedf(float(p["T"]), 0.01), snappedf(float(p.get("F", 0.0)), 0.1), 1 if p.get("fogo", true) else 0])
	var entradas: Array = []
	for ing in ingredientes:
		entradas.append([str(ing.get("nome", "")), snappedf(float(ing.get("t0", 0.0)), 0.001)])
	var aprov: Array = []
	for d in resultado.get("diagnosticos", []):
		aprov.append(snappedf(float(d.get("a", 0.0)), 0.0001))
	var dados := {
		"versao": 1,
		"quando": Time.get_datetime_string_from_system(),
		"receita": {"nome": str(receita.get("nome", "")), "passos": receita.get("passos", [])} if not receita.is_empty() else {},
		"t_final": snappedf(t_final, 0.001),
		"historico": hist,
		"entradas": entradas,
		"acoes": acoes.duplicate(),
		"aproveitamento": aprov,
	}
	var nome := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var f := FileAccess.open("%s/%s.json" % [PASTA, nome], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(dados))
		f.close()
