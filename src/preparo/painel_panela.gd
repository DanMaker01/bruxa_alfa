# painel_panela.gd
# Coluna "Na panela" da cena de preparo: uma linha por ingrediente com nome,
# % de aproveitamento já garantido, barra, frase do momento e tags de problema.
class_name PainelPanela
extends PanelContainer

var _lista: VBoxContainer
var _linhas: Array = []   # [{"raiz", "nome", "pct", "barra", "fill", "status", "tags", "assinatura_tags", "punindo"}]
var _t: float = 0.0
## true = nunca aparece (o debug do caldeirão tem os cards de itens no lugar).
var oculto: bool = false


func _ready() -> void:
	name = "PainelPanela"
	position = Vector2(486, 190)
	size = Vector2(150, 360)
	custom_minimum_size = Vector2(150, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fundo := StyleBoxFlat.new()
	fundo.bg_color = Color(0.05, 0.05, 0.1, 0.75)
	fundo.set_corner_radius_all(8)
	fundo.set_content_margin_all(6)
	add_theme_stylebox_override("panel", fundo)
	var col := VBoxContainer.new()
	add_child(col)
	var titulo := Label.new()
	titulo.text = "Na panela"
	titulo.add_theme_font_size_override("font_size", 14)
	col.add_child(titulo)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 6)
	scroll.add_child(_lista)
	hide()

## Linhas em punição piscam.
func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var aceso: bool = int(_t * 5.0) % 2 == 0
	for linha in _linhas:
		linha["raiz"].modulate = Color(1, 0.6, 0.6) if linha["punindo"] and aceso else Color.WHITE

func quantidade() -> int:
	return _linhas.size()

func limpar() -> void:
	_linhas.clear()
	if _lista:
		for c in _lista.get_children():
			c.queue_free()
	hide()

func adicionar(nome_exibicao: String) -> void:
	if not oculto:
		show()
	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 1)
	var topo := HBoxContainer.new()
	var nome := Label.new()
	nome.text = nome_exibicao
	nome.add_theme_font_size_override("font_size", 12)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome.clip_text = true
	var pct := Label.new()
	pct.text = "100%"
	pct.add_theme_font_size_override("font_size", 12)
	topo.add_child(nome)
	topo.add_child(pct)
	var barra := ProgressBar.new()
	barra.min_value = 0.0
	barra.max_value = 1.0
	barra.value = 1.0
	barra.show_percentage = false
	barra.custom_minimum_size = Vector2(0, 7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = FeedbackPreparo.COR_OK
	barra.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.25)
	barra.add_theme_stylebox_override("background", bg)
	var status := Label.new()
	status.text = "..."
	status.add_theme_font_size_override("font_size", 10)
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 3)
	tags.add_theme_constant_override("v_separation", 3)
	raiz.add_child(topo)
	raiz.add_child(barra)
	raiz.add_child(status)
	raiz.add_child(tags)
	_lista.add_child(raiz)
	_linhas.append({"raiz": raiz, "nome": nome, "pct": pct, "barra": barra, "fill": fill,
		"status": status, "tags": tags, "assinatura_tags": "", "punindo": false})

## A barra mostra o que JÁ FOI PERDIDO (não volta). O texto mostra o momento.
func atualizar(i: int, est: Dictionary) -> void:
	if i >= _linhas.size():
		return
	var linha: Dictionary = _linhas[i]
	var perda: float = est.get("perda", 1.0)
	linha["barra"].value = perda
	linha["pct"].text = "%d%%" % int(round(perda * 100.0))
	linha["fill"].bg_color = FeedbackPreparo.COR_PUNICAO.lerp(FeedbackPreparo.COR_OK, perda) if perda < 0.99 else FeedbackPreparo.COR_OK
	linha["status"].text = est.get("texto", "")
	var pior := 0
	for k in est.get("niveis", {}):
		pior = maxi(pior, est["niveis"][k])
	linha["punindo"] = pior == 2
	var cor_status: Color = Color(0.8, 0.8, 0.85)
	if pior == 2: cor_status = FeedbackPreparo.COR_PUNICAO
	elif pior == 1: cor_status = FeedbackPreparo.COR_ALERTA
	elif est.get("no_ponto", false): cor_status = FeedbackPreparo.COR_OK
	linha["status"].add_theme_color_override("font_color", cor_status)
	_atualizar_tags(linha, est.get("problemas", []))

## Uma tag por problema do ingrediente. Vermelha = já aconteceu e não volta;
## cinza = ainda dá pra resolver cozinhando mais (cru, pouco tempo).
func _atualizar_tags(linha: Dictionary, problemas: Array) -> void:
	var partes: Array = []
	for t in problemas:
		partes.append("%s:%d:%s" % [t["chave"], int(round(t["perda"] * 100.0)), t["fixo"]])
	var assinatura: String = "|".join(partes)
	if assinatura == linha["assinatura_tags"]:
		return
	linha["assinatura_tags"] = assinatura
	var caixa: HFlowContainer = linha["tags"]
	for c in caixa.get_children():
		c.queue_free()
	for t in problemas:
		caixa.add_child(_criar_tag(t))

func _criar_tag(t: Dictionary) -> Control:
	var tag := PanelContainer.new()
	var estilo := StyleBoxFlat.new()
	estilo.set_corner_radius_all(4)
	estilo.content_margin_left = 4
	estilo.content_margin_right = 4
	estilo.content_margin_top = 1
	estilo.content_margin_bottom = 1
	estilo.bg_color = Color(0.55, 0.12, 0.1, 0.95) if t["fixo"] else Color(0.3, 0.3, 0.38, 0.95)
	tag.add_theme_stylebox_override("panel", estilo)
	var label := Label.new()
	var pct: int = int(round(t["perda"] * 100.0))
	label.text = t["texto"] + (" -%d%%" % pct if pct > 0 and pct < 100 else "")
	label.add_theme_font_size_override("font_size", 9)
	tag.add_child(label)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tag

## Textos das tags da linha i (para testes/debug).
func tags_da_linha(i: int) -> Array:
	var r: Array = []
	if i < _linhas.size():
		for c in _linhas[i]["tags"].get_children():
			if not c.is_queued_for_deletion():
				r.append(c.get_child(0).text)
	return r

func valor_da_barra(i: int) -> float:
	return _linhas[i]["barra"].value if i < _linhas.size() else -1.0
