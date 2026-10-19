# feedback_preparo.gd
# Avisos do preparo enquanto cozinha: textos flutuantes quando um critério de um
# ingrediente piora (ou chega no ponto), sem repetir o mesmo aviso em sequência,
# e as cores de estado usadas no gráfico/painel.
class_name FeedbackPreparo
extends Node

## Pediu um marcador no gráfico (punição começou, chegou no ponto...).
signal marcador(cor: Color)

const COR_OK = Color(0.35, 0.85, 0.4)
const COR_ALERTA = Color(1.0, 0.8, 0.2)
const COR_PUNICAO = Color(1.0, 0.25, 0.2)
# Cores do estado de um ingrediente (fatias e faixas do gráfico)
const COR_CRU = Color(0.35, 0.5, 0.95)
const COR_PONTO = Color(0.3, 0.9, 0.35)
const COR_PASSANDO = Color(1.0, 0.6, 0.1)
const COR_ESTRAGADO = Color(0.55, 0.08, 0.06)

const MSG_NIVEL := {
	"quente": ["", "quase quente demais", "quente demais!"],
	"frio": ["", "quase frio demais", "frio demais!"],
	"tempo": ["", "quase passando do tempo", "tempo demais!"],
	"ponto": ["", "no ponto, não passe!", "passou do ponto!"],
}
## Mesmo aviso não se repete antes disso (s de simulação).
const INTERVALO_AVISO: float = 2.0

## Onde os textos flutuantes aparecem (a cena).
var alvo: Control
var _niveis_anteriores: Array = []    # por ingrediente: para avisar só quando o nível SOBE
var _ultimo_aviso: Dictionary = {}    # "i:critério" -> t do último aviso


func resetar() -> void:
	_niveis_anteriores.clear()
	_ultimo_aviso.clear()

func novo_ingrediente() -> void:
	_niveis_anteriores.append({})

## Compara com o estado anterior do ingrediente i e avisa o que piorou/melhorou.
func avisar_mudancas(i: int, nome: String, est: Dictionary, t: float) -> void:
	if i >= _niveis_anteriores.size():
		return
	var antes: Dictionary = _niveis_anteriores[i]
	for k in est["niveis"]:
		var nivel: int = est["niveis"][k]
		if nivel > int(antes.get(k, 0)) and _pode_avisar("%d:%s:%d" % [i, k, nivel], t):
			texto_flutuante("%s: %s" % [nome, MSG_NIVEL[k][nivel]], COR_PUNICAO if nivel == 2 else COR_ALERTA)
			if nivel == 2:
				marcador.emit(COR_PUNICAO)
	if est.get("no_ponto", false) and not antes.get("no_ponto", false) and _pode_avisar("%d:no_ponto" % i, t):
		texto_flutuante("%s: no ponto ✓" % nome, COR_OK)
		marcador.emit(COR_OK)
	var novo: Dictionary = est["niveis"].duplicate()
	novo["no_ponto"] = est.get("no_ponto", false)
	_niveis_anteriores[i] = novo

func _pode_avisar(chave: String, t: float) -> bool:
	if t - float(_ultimo_aviso.get(chave, -INF)) < INTERVALO_AVISO:
		return false
	_ultimo_aviso[chave] = t
	return true

func texto_flutuante(texto: String, cor: Color) -> void:
	if not alvo:
		return
	var label := Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", cor)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(320, 30)
	label.position = Vector2(160, 150 + randf_range(-20, 20))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alvo.add_child(label)
	var tw := label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y - 70.0, 1.6)
	tw.tween_property(label, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tw.chain().tween_callback(label.queue_free)


## Cor de um ingrediente num instante (fatia sob T(t) e faixa embaixo do gráfico):
##   cozimento: azul (cru) → verde (no ponto) → laranja → vinho (passou do ponto), pelo a_Q;
##   punições de temperatura e tempo puxam a cor para o vinho, na proporção do que já tiraram.
static func cor_do_estado(est: Dictionary, item: ItemData) -> Color:
	if item == null:
		return Color(0.35, 0.35, 0.35, 0.8)
	var cor: Color
	var a_Q: float = est["a_Q"]
	if item.m > 0.0 and est["Q"] > item.m:
		var queda: float = 1.0 - a_Q
		cor = COR_PONTO.lerp(COR_PASSANDO, clampf(queda * 2.0, 0.0, 1.0)) if queda < 0.5 \
			else COR_PASSANDO.lerp(COR_ESTRAGADO, clampf((queda - 0.5) * 2.0, 0.0, 1.0))
	else:
		cor = COR_CRU.lerp(COR_PONTO, a_Q)
	# tempo mínimo ainda não cumprido: continua puxando para o "cru"
	cor = COR_CRU.lerp(cor, est["a_t_min"])
	# punições irreversíveis (calor, frio, tempo demais)
	var outras: float = est["a_T_max"] * est["a_T_min"] * est["a_t_max"]
	cor = COR_ESTRAGADO.lerp(cor, outras)
	cor.a = 0.8
	return cor
