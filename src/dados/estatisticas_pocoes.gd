# estatisticas_pocoes.gd
# Só para debug: guarda o aproveitamento médio de cada poção feita (user://), para ver a
# distribuição (quão difícil é chegar em 95%). O menu de debug mostra (aba Poções).
class_name EstatisticasPocoes
extends RefCounted

const ARQUIVO := "user://estatisticas_pocoes.txt"
## Faixas do histograma (limite de baixo de cada uma).
const FAIXAS := [0.0, 0.70, 0.80, 0.85, 0.90, 0.95]

## Uma linha por poção: aproveitamento;nome;quando
static func registrar(a: float, nome: String) -> void:
	var f := FileAccess.open(ARQUIVO, FileAccess.READ_WRITE) if FileAccess.file_exists(ARQUIVO) else FileAccess.open(ARQUIVO, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("%.4f;%s;%s" % [a, nome.replace(";", ","), Time.get_datetime_string_from_system()])
	f.close()

## [{"a": float, "nome": String, "quando": String}, ...]
static func ler() -> Array:
	var out: Array = []
	if not FileAccess.file_exists(ARQUIVO):
		return out
	var f := FileAccess.open(ARQUIVO, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var l := f.get_line().strip_edges()
		if l == "":
			continue
		var p := l.split(";")
		out.append({"a": float(p[0]), "nome": p[1] if p.size() > 1 else "", "quando": p[2] if p.size() > 2 else ""})
	return out

static func limpar() -> void:
	if FileAccess.file_exists(ARQUIVO):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO))

## Quantas poções em cada faixa de FAIXAS.
static func histograma(lista: Array) -> Array:
	var h: Array = []
	h.resize(FAIXAS.size())
	h.fill(0)
	for e in lista:
		var a: float = float(e["a"])
		for i in range(FAIXAS.size() - 1, -1, -1):
			if a >= float(FAIXAS[i]):
				h[i] += 1
				break
	return h
