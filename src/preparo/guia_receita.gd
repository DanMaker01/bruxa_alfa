# guia_receita.gd
# Receita memorizada no livro, mostrada inteira num canto do preparo.
# Acompanha sozinho o passo atual:
#   chama X:            cumprido quando a chama fica em X por TEMPO_CHAMA
#   ingrediente ×q, N s: cumprido quando entraram q desse item e passaram N s do PRIMEIRO
#                       (igual ao livro: o tempo do passo conta desde que o 1º entrou)
#   Finalizar:          fica destacado no fim
# Sem receita memorizada, não aparece.
class_name GuiaReceita
extends Control

const LARG: float = 210.0
const ALT_LINHA: float = 19.0
const TEMPO_CHAMA: float = 1.0
const COR_FUNDO := Color(0.96, 0.91, 0.8, 0.92)
const COR_TINTA := Color(0.2, 0.14, 0.1)
const COR_SUAVE := Color(0.5, 0.43, 0.35)
const COR_FEITO := Color(0.25, 0.5, 0.25)
const COR_ATUAL := Color(0.5, 0.18, 0.45)

var cena = null
var pagina: Dictionary = {}
var _i: int = 0                  # passo atual
var _t_passo: float = 0.0        # chama: tempo no estado certo
var _contagem: int = 0           # ingrediente: quantos entraram neste passo
var _t_primeiro: float = -1.0    # ingrediente: t_sim do 1º que entrou neste passo
var _fonte: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonte = get_theme_default_font()

## Pega a memorizada do livro (ou nada). Chamado ao abrir o preparo.
func carregar(livro: Dictionary) -> void:
	pagina = LivroReceitas.pagina_memorizada(livro) if not livro.is_empty() else {}
	reiniciar()

func reiniciar() -> void:
	_i = 0
	_t_passo = 0.0
	_contagem = 0
	_t_primeiro = -1.0
	visible = not pagina.is_empty()
	custom_minimum_size = Vector2(LARG, _altura())
	size = custom_minimum_size

func _altura() -> float:
	if pagina.is_empty():
		return 0.0
	return 34.0 + (pagina["passos"].size() + 1) * ALT_LINHA + 8.0

## A cena avisa a cada ingrediente que cai no caldeirão.
func ingrediente_entrou(id: String) -> void:
	if pagina.is_empty() or _i >= pagina["passos"].size():
		return
	var s: Dictionary = pagina["passos"][_i]
	if s.get("tipo") == "ingrediente" and s.get("item") == id:
		_contagem += 1
		if _t_primeiro < 0.0:
			_t_primeiro = _t_sim()


## Ingrediente retirado do caldeirão (nos primeiros segundos): desconta do passo atual.
func ingrediente_saiu(id: String) -> void:
	if pagina.is_empty() or _i >= pagina["passos"].size():
		return
	var s: Dictionary = pagina["passos"][_i]
	if s.get("tipo") == "ingrediente" and s.get("item") == id and _contagem > 0:
		_contagem -= 1
		if _contagem == 0:
			_t_primeiro = -1.0

func _t_sim() -> float:
	var s = cena.get("sistema") if cena else null
	return float(s.t_sim) if s else 0.0

func _process(delta: float) -> void:
	if pagina.is_empty() or not is_visible_in_tree():
		return
	var passos: Array = pagina["passos"]
	if _i < passos.size():
		var s: Dictionary = passos[_i]
		var sis = cena.get("sistema") if cena else null
		if s.get("tipo") == "chama" and sis:
			if EstadosChama.de_T(sis.T, sis.fogo_ligado) == s.get("estado"):
				_t_passo += delta
				if _t_passo >= TEMPO_CHAMA:
					_avancar()
			else:
				_t_passo = 0.0
		elif s.get("tipo") == "ingrediente":
			if _contagem >= int(s.get("qtd", 1)) and _t_primeiro >= 0.0 \
					and _t_sim() - _t_primeiro >= float(s.get("seg", 0.0)):
				_avancar()
	queue_redraw()

func _avancar() -> void:
	_i += 1
	_t_passo = 0.0
	_contagem = 0
	_t_primeiro = -1.0


func _draw() -> void:
	if pagina.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), COR_FUNDO)
	draw_rect(Rect2(Vector2.ZERO, size), Color(COR_TINTA, 0.4), false, 1.0)
	_txt(Vector2(8, 18), str(pagina["nome"]), 13, COR_TINTA)
	var passos: Array = pagina["passos"]
	var y := 38.0
	for k in passos.size() + 1:
		var feito := k < _i
		var atual := k == _i
		var cor := COR_FEITO if feito else (COR_ATUAL if atual else COR_SUAVE)
		var marca := "✓" if feito else ("▶" if atual else "·")
		var txt := "Finalizar"
		if k < passos.size():
			var s: Dictionary = passos[k]
			txt = LivroReceitas.texto_passo(s, cena.get("database") if cena else null)
			if s.get("tipo") == "chama":
				draw_rect(Rect2(22, y - 10, 9, 9), EstadosChama.cor(s["estado"]))
			if atual and s.get("tipo") == "ingrediente":
				var resta: int = maxi(0, roundi(float(s.get("seg", 0.0)) - (_t_sim() - _t_primeiro))) if _t_primeiro >= 0.0 else roundi(float(s.get("seg", 0.0)))
				if _contagem < int(s.get("qtd", 1)):
					txt += "  (%d/%d · %d s)" % [_contagem, int(s.get("qtd", 1)), resta]
				else:
					txt += "  (%d s)" % resta
		_txt(Vector2(8, y), marca, 12, cor)
		_txt(Vector2(36 if k < passos.size() and passos[k].get("tipo") == "chama" else 22, y), txt, 12, cor)
		y += ALT_LINHA

func _txt(p: Vector2, s: String, tam: int, cor: Color) -> void:
	draw_string(_fonte, p, s, HORIZONTAL_ALIGNMENT_LEFT, LARG - p.x - 6, tam, cor)
