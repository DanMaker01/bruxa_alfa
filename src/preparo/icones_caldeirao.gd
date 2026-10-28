# icones_caldeirao.gd
# Os ingredientes DENTRO do caldeirão: cada um vira um ícone que flutua devagar,
# de forma aleatória, preso numa bola (círculo) na boca do caldeirão.
# O ícone mostra o estado do ingrediente:
#   cru            → pálido/desbotado (vai ganhando cor conforme cozinha)
#   no ponto       → brilho suave pulsando em volta
#   passou do ponto→ escurece (queimado)
#   quente demais  → avermelha        frio demais → azula
#   tempo demais   → murcha (perde a cor)
#   aproveitamento perdido → fica mais transparente (o ícone nunca encolhe)
#   punindo agora  → treme
# E um anel de bolhinhas em volta de cada ícone mostra o cozimento (enche no sentido horário).
# A régua do anel (e da vela) tem 3 modos para testar (IconesCaldeirao.modo; tecla M no preparo troca):
#   PUNICAO      ponto sempre em FRACAO_PONTO; o resto do anel = punição (1 − a), linear na punição.
#   PROPORCIONAL anel fecha em m + 3·s+ (vela: (1 + h_max)·t_max): posição do ponto depende do item.
#   ABSOLUTO     anel fecha sempre em Q_ABSOLUTO (vela: T_ABSOLUTO s): cada item tem posição absoluta
#                e você se guia só pelas cores.
# Em PROPORCIONAL/ABSOLUTO cada bolhinha tem a cor do aproveitamento NAQUELE ponto da régua
# (a curva de verdade: gaussiana suave muda de cor devagar, gaussiana estreita muda rápido).
# Cores: branco (cru) → dourado (ponto, brilhando) → amarelo → laranja → vermelho (50%) → preto (100%).
# Camadas extras (feedback visual dos índices):
#   a_Q    → AFUNDA (sem encolher): cru boia alto balançando, perto do ponto afunda; no ponto solta
#            estrelinhas; passou do ponto sobe fumaça escura.
#   a_Tmin → GELO: cristais em volta e um arrepio lento quando está frio demais.
#   a_Tmax → RACHADURAS: rachaduras finas que crescem com o dano do calor (ficam),
#            brilhando e soltando faíscas enquanto está quente demais.
#   a_tmin/a_tmax → VELA: anel de pavio (por dentro das bolhinhas) que vai queimando com o tempo,
#            com a mesma régua do anel: t_max fica em FRACAO_PONTO; branco tracejado antes do
#            mínimo, dourado na janela certa, e depois do máximo amarelo → laranja → vermelho
#            (50%) → preto. Vela fechada = punição máxima do tempo.
# Escala de cores (anel e vela): branco → DOURADO (ideal) → amarelo → laranja → vermelho → preto.
# Não decide nada do jogo: a cena chama adicionar() e atualizar() com o estado.
class_name IconesCaldeirao
extends Node2D
## Perda (0..1) a partir da qual o ícone chacoalha.
const LIMIAR_TREMER: float = 0.67

# ---- a bola onde os itens flutuam (ajuste aqui quando o sprite arredondado chegar) ----
## Centro da bola, relativo à posição do sprite do caldeirão.
const CENTRO_RELATIVO := Vector2(0, 0)
## Raio da bola (px).
const RAIO: float = 90.0
# ---- ícones ----
const TAMANHO: float = 44.0          # px (lado do ícone inteiro)
const VELOCIDADE: float = 18.0       # px/s do passeio
const GIRO: float = 1.6              # quanto a direção muda por segundo (rad)
const SEPARACAO: float = 0.9         # empurrão entre ícones encostados
const TREMOR_PX: float = 3.0
const SUAVIZACAO: float = 4.0        # rapidez com que cor/tamanho acompanham o estado
# ---- cores ----
const COR_QUENTE := Color(1.0, 0.25, 0.1)
const COR_FRIO := Color(0.35, 0.6, 1.0)
const COR_BRILHO := Color(1.0, 0.85, 0.35)
# ---- anel de cozimento (bolhinhas em volta do ícone) ----
const ANEL_BOLHAS: int = 36
const ANEL_RAIO: float = 38.0         # distância do centro do ícone (px) — por fora da vela
const ANEL_TAM: float = 3.0           # raio de cada bolhinha cheia (px)
const COR_ANEL_COZINHANDO := Color(0.95, 0.95, 0.9)
enum ModoRegua { PUNICAO, PROPORCIONAL, ABSOLUTO }
const NOMES_MODO := ["punição (ponto fixo em 75%)", "proporcional ao item", "absoluto"]
## Modo da régua do anel/vela (para testar; a cena troca com a tecla M).
static var modo: int = ModoRegua.ABSOLUTO
## PUNICAO: parte do anel (e da vela) que vai até o ponto ideal; o resto é a régua da punição.
const FRACAO_PONTO: float = 0.75
## ABSOLUTO: Q que fecha o anel e duração (s) que fecha a vela, iguais para todo ingrediente.
const Q_ABSOLUTO: float = 10000.0
const T_ABSOLUTO: float = 100.0
## PROPORCIONAL: o ponto fica entre estas frações da volta (evita colar no começo/fim).
const PONTO_MIN: float = 0.4
const PONTO_MAX: float = 0.9
# ---- escala de estado: branco → dourado (ideal) → amarelo → laranja → vermelho → preto ----
const ESCALA_CORES := [
	Color(0.95, 0.95, 0.9),   # 0 branco: ainda não chegou
	Color(1.0, 0.78, 0.22),   # 1 dourado: ideal
	Color(1.0, 0.95, 0.35),   # 2 amarelo
	Color(1.0, 0.55, 0.1),    # 3 laranja
	Color(1.0, 0.15, 0.1),    # 4 vermelho: punição de 50%
	Color(0.05, 0.05, 0.05),  # 5 preto: punição máxima
]
# ---- afundar (a_Q) ----
const AFUNDA_PX: float = 10.0          # quanto desce quando cozido (px)
const BOIA_PX: float = 2.5             # balanço de quem ainda está cru (px)
const ESTRELAS_POR_SEG: float = 3.0    # no ponto
const FUMACA_POR_SEG: float = 7.0      # passou do ponto (no máximo)
# ---- gelo (a_Tmin) ----
const CRISTAIS: int = 6
const CRISTAL_TAM: float = 6.0
const ARREPIO_PX: float = 1.5
# ---- rachaduras (a_Tmax) ----
const RACHADURAS: int = 3
const COR_RACHADURA := Color(0.06, 0.05, 0.05, 0.9)
const COR_RACHADURA_QUENTE := Color(1.0, 0.85, 0.55)
# ---- vela (a_tmin / a_tmax) ----
const VELA_RAIO: float = 29.0          # distância do centro do ícone (px) — por dentro das bolhinhas
const VELA_LARGURA: float = 2.0
const COR_VELA := Color(0.95, 0.95, 0.95)          # antes do tempo mínimo

const SHADER := """
shader_type canvas_item;
uniform float saturacao = 1.0;
uniform vec4 tinta : source_color = vec4(1.0);
uniform float tinta_qtd = 0.0;
uniform float escurecer = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(vec3(g), c.rgb, saturacao);
	c.rgb = mix(c.rgb, tinta.rgb * (0.35 + 0.65 * g), tinta_qtd);
	c.rgb *= 1.0 - escurecer;
	COLOR = c * COLOR;
}
"""

var caldeirao: Node2D
var mostrar_area: bool = false:
	set(v):
		mostrar_area = v
		queue_redraw()

var _icones: Array = []   # um Dictionary por ingrediente (mesma ordem da cena)
var _shader: Shader
var _t: float = 0.0
var _frente: Node2D        # camada desenhada POR CIMA dos ícones (gelo, rachaduras, fumaça, estrelas)


func _ready() -> void:
	_shader = Shader.new()
	_shader.code = SHADER
	_frente = Node2D.new()
	_frente.name = "Frente"
	_frente.z_index = 1
	add_child(_frente)
	_frente.draw.connect(_desenhar_frente)

func centro() -> Vector2:
	return (caldeirao.position if caldeirao else Vector2(320, 272)) + CENTRO_RELATIVO

## Um ingrediente caiu no caldeirão. onde_global: ponto onde ele entra (boca).
func adicionar(item: ItemData, nome: String, onde_global: Vector2) -> void:
	var raiz := Node2D.new()
	add_child(raiz)
	raiz.position = _dentro(to_local(onde_global), 0.0)
	# brilho (atrás): mesma imagem, maior, somando luz
	var brilho := Sprite2D.new()
	var mat_add := CanvasItemMaterial.new()
	mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	brilho.material = mat_add
	brilho.modulate = Color(COR_BRILHO, 0.0)
	raiz.add_child(brilho)
	# ícone
	var sprite := Sprite2D.new()
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	sprite.material = mat
	raiz.add_child(sprite)
	var tex: Texture2D = item.icone if item and item.icone else _textura_reserva(nome)
	for s in [sprite, brilho]:
		s.texture = tex
	var escala_base: float = TAMANHO / maxf(tex.get_width(), tex.get_height())
	sprite.scale = Vector2.ONE * escala_base
	brilho.scale = Vector2.ONE * escala_base * 1.3
	if not (item and item.icone):
		var l := Label.new()
		l.text = nome.left(2).to_upper()
		l.add_theme_font_size_override("font_size", 18)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.position = Vector2(-12, -14)
		sprite.add_child(l)
	var ang := randf() * TAU
	if _frente:
		move_child(_frente, -1)   # a camada da frente continua por cima do ícone novo
	_icones.append({
		"item": item, "fase": randf() * TAU,
		"rachaduras": _gerar_rachaduras(), "cristal_giro": randf() * TAU,
		"fumaca": [], "estrelas": [],
		"afundar": 0.0, "afundar_alvo": 0.0, "frio": 0.0, "frio_alvo": 0.0,
		"quente": 0.0, "quente_alvo": 0.0, "rachado": 0.0, "rachado_alvo": 0.0,
		"fumaca_qtd": 0.0, "fumaca_alvo": 0.0,
		"vela": 0.0, "vela_alvo": 0.0, "vela_estado": 0, "tem_vela": false, "vela_umin": 0.0,
		"vela_dano": 0.0, "vela_dano_alvo": 0.0, "perdido": false,
		"timer_fx": 0.0,
		"raiz": raiz, "sprite": sprite, "halo": brilho, "mat": mat,
		"base": escala_base, "dir": ang, "pos": raiz.position,
		# estado visual (suavizado)
		"sat": 0.35, "tinta": Color.WHITE, "tinta_qtd": 0.0, "escuro": 0.0,
		"alfa": 1.0, "tam": 1.0, "brilho": 0.0, "treme": 0.0,
		# alvo (vem do estado ao vivo)
		"alvo": {"sat": 0.35, "tinta": Color.WHITE, "tinta_qtd": 0.0, "escuro": 0.0,
			"alfa": 1.0, "tam": 1.0, "brilho": 0.0, "treme": 0.0},
		# anel de cozimento
		"progresso": 0.0, "progresso_alvo": 0.0, "ponto": false, "queimado": 0.0, "queimado_alvo": 0.0,
	})
	# entra com um "pop"
	raiz.scale = Vector2(0.3, 0.3)
	raiz.create_tween().tween_property(raiz, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Traduz o estado ao vivo (CalculadoraPocao.estado_ao_vivo) em aparência.
func atualizar(i: int, est: Dictionary) -> void:
	if i < 0 or i >= _icones.size() or est.is_empty():
		return
	var a: Dictionary = _icones[i]["alvo"]
	var niveis: Dictionary = est.get("niveis", {})
	var inteiro: float = clampf(float(est.get("perda", 1.0)), 0.0, 1.0)   # 1 = nada perdido
	var progresso: float = clampf(float(est.get("progresso", 0.0)), 0.0, 1.0)
	# cru → cozido: ganha cor
	a["sat"] = lerpf(0.3, 1.0, progresso)
	# tinta: quente > frio
	a["tinta_qtd"] = 0.0
	if niveis.get("quente", 0) > 0:
		a["tinta"] = COR_QUENTE
		a["tinta_qtd"] = 0.65 if niveis["quente"] == 2 else 0.3
	elif niveis.get("frio", 0) > 0:
		a["tinta"] = COR_FRIO
		a["tinta_qtd"] = 0.65 if niveis["frio"] == 2 else 0.3
	# tempo demais: murcha
	if niveis.get("tempo", 0) == 2:
		a["sat"] *= 0.4
	# passou do ponto: escurece conforme o cozimento se perde
	var passou: bool = niveis.get("ponto", 0) > 0
	a["escuro"] = clampf((1.0 - float(est.get("a_Q", 1.0))) * 0.8, 0.0, 0.8) if passou else 0.0
	# aproveitamento perdido: some e encolhe
	a["alfa"] = lerpf(0.3, 1.0, inteiro)
	a["tam"] = 1.0   # o ícone nunca encolhe
	# no ponto e sem problema agora: brilho
	var punindo := false
	for k in niveis:
		if niveis[k] == 2:
			punindo = true
	a["brilho"] = 1.0 if est.get("no_ponto", false) and not punindo and not passou else 0.0
	# só chacoalha quando a punição já é séria: perdeu >= 67% do aproveitamento
	var perdido: float = 1.0 - float(est.get("perda", 1.0))
	a["treme"] = clampf(0.4 + 0.6 * (perdido - LIMIAR_TREMER) / (1.0 - LIMIAR_TREMER), 0.4, 1.0) \
		if punindo and perdido >= LIMIAR_TREMER else 0.0
	# anel: quanto da régua o cozimento (Q) já andou
	var ic: Dictionary = _icones[i]
	var item_ic: ItemData = ic["item"]
	var punicao_q: float = clampf(1.0 - float(est.get("a_Q", 1.0)), 0.0, 1.0)
	if modo != ModoRegua.PUNICAO:
		ic["progresso_alvo"] = clampf(float(est.get("Q", 0.0)) / _q_cheio(item_ic), 0.0, 1.0)
	elif item_ic and item_ic.m > 0.0:
		var Q: float = float(est.get("Q", 0.0))
		if Q < item_ic.m:
			ic["progresso_alvo"] = FRACAO_PONTO * clampf(Q / item_ic.m, 0.0, 1.0)
		else:
			ic["progresso_alvo"] = FRACAO_PONTO + (1.0 - FRACAO_PONTO) * punicao_q
	else:
		ic["progresso_alvo"] = FRACAO_PONTO   # sem exigência de cozimento: já está no ponto
	ic["ponto"] = est.get("no_ponto", false)
	ic["queimado_alvo"] = punicao_q if passou else 0.0
	# ---- camadas extras ----
	ic["afundar_alvo"] = 1.0 if passou else progresso
	ic["fumaca_alvo"] = ic["queimado_alvo"]
	ic["frio_alvo"] = float(niveis.get("frio", 0)) / 2.0
	ic["quente_alvo"] = float(niveis.get("quente", 0)) / 2.0
	# rachaduras: o dano do calor que já aconteceu (não some) + um pouco do "chegando perto"
	var dano_calor: float = clampf((1.0 - float(est.get("a_T_max", 1.0))) * 1.5, 0.0, 1.0)
	ic["rachado_alvo"] = maxf(dano_calor, 0.25 if niveis.get("quente", 0) > 0 else 0.0)
	_atualizar_vela(ic, est)

## Vela: a janela de tempo do ingrediente, na mesma régua do anel (ver modo).
##   PUNICAO: t_max fica em FRACAO_PONTO; o resto da volta é a punição do tempo (1 − a_tmax).
##            Sem t_max: t_min fica em FRACAO_PONTO e a vela para ali.
##   PROPORCIONAL / ABSOLUTO: a vela anda com a duração (dur / _t_cheio).
##   estado 0 = antes do t_min (tracejada), 1 = na janela (dourada), 2 = passou do t_max.
func _atualizar_vela(ic: Dictionary, est: Dictionary) -> void:
	var item: ItemData = ic["item"]
	var tem_max: bool = item != null and item.t_max > 0.0 and item.t_max < 999.0
	ic["tem_vela"] = item != null and (item.t_min > 0.0 or tem_max)
	if not ic["tem_vela"]:
		return
	var dur: float = float(est.get("duracao", 0.0))
	ic["vela_dano_alvo"] = 0.0
	if modo != ModoRegua.PUNICAO:
		ic["vela_alvo"] = clampf(dur / _t_cheio(item), 0.0, 1.0)
	elif tem_max:
		ic["vela_umin"] = FRACAO_PONTO * clampf(item.t_min / item.t_max, 0.0, 1.0) if item.t_min > 0.0 else 0.0
		if dur <= item.t_max:
			ic["vela_alvo"] = FRACAO_PONTO * dur / item.t_max
		else:
			ic["vela_alvo"] = FRACAO_PONTO + (1.0 - FRACAO_PONTO) * clampf(1.0 - float(est.get("a_t_max", 1.0)), 0.0, 1.0)
	else:
		ic["vela_umin"] = FRACAO_PONTO
		ic["vela_alvo"] = FRACAO_PONTO * clampf(dur / item.t_min, 0.0, 1.0)
	if tem_max and dur > item.t_max:
		ic["vela_estado"] = 2
		ic["vela_dano_alvo"] = clampf(1.0 - float(est.get("a_t_max", 1.0)), 0.0, 1.0)
	elif item.t_min > 0.0 and dur < item.t_min:
		ic["vela_estado"] = 0
	else:
		ic["vela_estado"] = 1

## Ingrediente perdido (aproveitamento chegou a zero): afunda, some e sai do caldeirão.
## O espaço dele na lista continua (os índices da cena não mudam), só não aparece mais.
func perder(i: int) -> void:
	if i < 0 or i >= _icones.size() or _icones[i]["perdido"]:
		return
	var ic: Dictionary = _icones[i]
	ic["perdido"] = true
	var raiz: Node2D = ic["raiz"]
	var tw := raiz.create_tween().set_parallel(true)
	tw.tween_property(raiz, "modulate:a", 0.0, 0.6)
	tw.tween_property(raiz, "position:y", raiz.position.y + 25.0, 0.6)
	tw.chain().tween_callback(raiz.hide)

# =============================================================================
# RÉGUAS (modos PROPORCIONAL / ABSOLUTO)
# =============================================================================
## Q que fecha o anel.
static func _q_cheio(item: ItemData) -> float:
	if modo == ModoRegua.PROPORCIONAL and item and item.m > 0.0:
		return clampf(item.m + 3.0 * maxf(item.s_mais, 0.0), item.m / PONTO_MAX, item.m / PONTO_MIN)
	return Q_ABSOLUTO

## Duração (s) que fecha a vela.
static func _t_cheio(item: ItemData) -> float:
	if modo == ModoRegua.PROPORCIONAL and item:
		if item.t_max > 0.0 and item.t_max < 999.0:
			return clampf((1.0 + maxf(item.h_max, 0.0)) * item.t_max, item.t_max / PONTO_MAX, item.t_max / PONTO_MIN)
		if item.t_min > 0.0:
			return item.t_min / FRACAO_PONTO
	return T_ABSOLUTO

## Cor do cozimento num Q qualquer da régua: branco (cru), dourado (a ≥ 0.9, no ponto),
## e depois do ponto a cor da punição (1 − a_Q) que aquele Q dá.
## Cache das cores do anel por item e modo (são sempre as mesmas; antes eram
## recalculadas 36 vezes por ícone a cada frame).
static var _cache_anel: Dictionary = {}
static func cores_anel(item: ItemData) -> Array:
	var chave := str(item.get_instance_id() if item else 0) + ":" + str(modo)
	if not _cache_anel.has(chave):
		var q_cheio: float = _q_cheio(item)
		var lista: Array = []
		for b in ANEL_BOLHAS:
			lista.append(cor_cozimento(item, (float(b) + 0.5) / ANEL_BOLHAS * q_cheio))
		_cache_anel[chave] = lista
	return _cache_anel[chave]

static func cor_cozimento(item: ItemData, Q: float) -> Color:
	if item == null or item.m <= 0.0:
		return cor_escala(1.0)
	var a: float = CalculadoraPocao.a_cozimento(Q, item.m, item.s_menos, item.s_mais)
	if Q < item.m:
		return cor_escala(1.0) if a >= 0.9 else ESCALA_CORES[0]
	return cor_punicao(1.0 - a)

## Cor do tempo numa duração qualquer da régua: branco antes do t_min, dourado na janela,
## depois do t_max a cor da punição (1 − a_tmax) daquela duração.
static func cor_tempo(item: ItemData, t: float) -> Color:
	if item == null:
		return cor_escala(1.0)
	if item.t_min > 0.0 and t < item.t_min:
		return ESCALA_CORES[0]
	if item.t_max > 0.0 and item.t_max < 999.0 and t > item.t_max:
		return cor_punicao(1.0 - CalculadoraPocao.curva_max(t, item.t_max, item.h_max))
	return cor_escala(1.0)

## Cor da punição p (0..1): dourado (0) → amarelo → laranja → vermelho (0.5) → preto (1).
static func cor_punicao(p: float) -> Color:
	p = clampf(p, 0.0, 1.0)
	if p <= 0.5:
		return cor_escala(1.0 + 3.0 * p / 0.5)
	return cor_escala(4.0 + (p - 0.5) / 0.5)

## Cor na escala branco(0) → dourado(1) → amarelo(2) → laranja(3) → vermelho(4) → preto(5).
static func cor_escala(f: float) -> Color:
	f = clampf(f, 0.0, ESCALA_CORES.size() - 1.0)
	var i := mini(int(floor(f)), ESCALA_CORES.size() - 2)
	return (ESCALA_CORES[i] as Color).lerp(ESCALA_CORES[i + 1], f - float(i))

func limpar() -> void:
	for ic in _icones:
		ic["raiz"].queue_free()
	_icones.clear()

func quantidade() -> int:
	return _icones.size()

# =============================================================================
# MOVIMENTO E APARÊNCIA (a cada frame)
# =============================================================================
func _process(delta: float) -> void:
	if _icones.is_empty():
		return
	_t += delta
	var c := centro()
	var raio_util := RAIO - TAMANHO * 0.5
	for i in _icones.size():
		var ic: Dictionary = _icones[i]
		if ic["perdido"]:
			continue
		# passeio: direção muda devagar e aleatoriamente
		ic["dir"] += randf_range(-GIRO, GIRO) * delta
		var vel := Vector2.from_angle(ic["dir"]) * VELOCIDADE
		# afasta dos vizinhos encostados
		for j in _icones.size():
			if j == i or _icones[j]["perdido"]:
				continue
			var d: Vector2 = ic["pos"] - _icones[j]["pos"]
			var dist := d.length()
			if dist > 0.01 and dist < TAMANHO * 0.9:
				vel += d / dist * VELOCIDADE * SEPARACAO * (1.0 - dist / (TAMANHO * 0.9)) * 3.0
		var nova: Vector2 = ic["pos"] + vel * delta
		# bateu na borda da bola: volta para dentro e vira para o centro
		if nova.distance_to(c) > raio_util:
			nova = c + (nova - c).limit_length(raio_util)
			ic["dir"] = (c - nova).angle() + randf_range(-0.8, 0.8)
		ic["pos"] = nova
		_aplicar(ic, delta)
		_efeitos(ic, delta)
	queue_redraw()   # anéis e vela
	if _frente:
		_frente.queue_redraw()

func _aplicar(ic: Dictionary, delta: float) -> void:
	var a: Dictionary = ic["alvo"]
	var k := clampf(delta * SUAVIZACAO, 0.0, 1.0)
	for chave in ["sat", "tinta_qtd", "escuro", "alfa", "tam", "brilho", "treme"]:
		ic[chave] = lerpf(ic[chave], a[chave], k)
	ic["tinta"] = (ic["tinta"] as Color).lerp(a["tinta"], k)
	ic["progresso"] = lerpf(ic["progresso"], ic["progresso_alvo"], k)
	ic["queimado"] = lerpf(ic["queimado"], ic["queimado_alvo"], k)
	for chave in ["afundar", "frio", "quente", "rachado", "vela", "vela_dano"]:
		ic[chave] = lerpf(ic[chave], ic[chave + "_alvo"], k)
	ic["fumaca_qtd"] = lerpf(ic["fumaca_qtd"], ic["fumaca_alvo"], k)
	var mat: ShaderMaterial = ic["mat"]
	mat.set_shader_parameter("saturacao", ic["sat"])
	mat.set_shader_parameter("tinta", ic["tinta"])
	mat.set_shader_parameter("tinta_qtd", ic["tinta_qtd"])
	mat.set_shader_parameter("escurecer", ic["escuro"])
	var sprite: Sprite2D = ic["sprite"]
	sprite.modulate.a = ic["alfa"]
	sprite.scale = Vector2.ONE * ic["base"] * ic["tam"]
	var halo: Sprite2D = ic["halo"]
	halo.scale = sprite.scale * (1.25 + 0.08 * sin(_t * 3.0))
	halo.modulate.a = ic["brilho"] * (0.35 + 0.25 * sin(_t * 3.0)) * ic["alfa"]
	var tremor := Vector2.ZERO
	if ic["treme"] > 0.05:
		tremor = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * TREMOR_PX * ic["treme"]
	# afundar: cru boia alto e balança; cozido desce
	var cru: float = 1.0 - ic["afundar"]
	var boia := Vector2(0.0, ic["afundar"] * AFUNDA_PX + sin(_t * 2.0 + ic["fase"]) * BOIA_PX * cru)
	# arrepio lento de frio
	var arrepio := Vector2(sin(_t * 22.0 + ic["fase"]) * ARREPIO_PX * ic["frio"], 0.0)
	ic["raiz"].position = ic["pos"] + tremor + boia + arrepio

## Estrelinhas (no ponto) e fumaça (passou do ponto): nascem, sobem e somem.
func _efeitos(ic: Dictionary, delta: float) -> void:
	ic["timer_fx"] += delta
	# nascem
	if ic["ponto"] and randf() < ESTRELAS_POR_SEG * delta:
		ic["estrelas"].append({"p": Vector2.from_angle(randf() * TAU) * randf_range(10.0, 26.0), "vida": 0.0, "dur": randf_range(0.5, 0.9)})
	if ic["fumaca_qtd"] > 0.02 and randf() < FUMACA_POR_SEG * ic["fumaca_qtd"] * delta:
		ic["fumaca"].append({"p": Vector2(randf_range(-8.0, 8.0), -6.0), "v": Vector2(randf_range(-6.0, 6.0), randf_range(-28.0, -18.0)),
			"vida": 0.0, "dur": randf_range(0.9, 1.6), "r": randf_range(4.0, 7.0)})
	# envelhecem
	for lista in [ic["estrelas"], ic["fumaca"]]:
		for j in range(lista.size() - 1, -1, -1):
			var f: Dictionary = lista[j]
			f["vida"] += delta
			if f.has("v"):
				f["p"] += f["v"] * delta
			if f["vida"] >= f["dur"]:
				lista.remove_at(j)

## Rachaduras: linhas quebradas saindo de perto do centro, em espaço do ícone (-0.5..0.5).
func _gerar_rachaduras() -> Array:
	var lista: Array = []
	for r in RACHADURAS:
		var ang := randf() * TAU
		var p := Vector2.from_angle(ang + PI) * randf_range(0.0, 0.08)
		var pts: Array = [p]
		for seg in 4:
			ang += randf_range(-0.7, 0.7)
			p += Vector2.from_angle(ang) * randf_range(0.08, 0.13)
			pts.append(p)
		lista.append(pts)
	return lista

## Ponto dentro da bola mais perto de p.
func _dentro(p: Vector2, folga: float) -> Vector2:
	var c := centro()
	return c + (p - c).limit_length(maxf(RAIO - TAMANHO * 0.5 - folga, 0.0))

## Item sem ícone: bolinha colorida (a cor vem do nome) com as iniciais por cima.
func _textura_reserva(nome: String) -> Texture2D:
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cor := Color.from_hsv(float(hash(nome) % 360) / 360.0, 0.5, 0.8)
	var r := n * 0.5 - 1.0
	for x in n:
		for y in n:
			if Vector2(x - n * 0.5, y - n * 0.5).length() <= r:
				img.set_pixel(x, y, cor)
	return ImageTexture.create_from_image(img)

# Área da bola (só com o debug do caldeirão ligado), para ajustar CENTRO_RELATIVO e RAIO.
func _draw() -> void:
	for ic in _icones:
		if ic["perdido"]:
			continue
		_desenhar_anel(ic)
		_desenhar_vela(ic)
	if mostrar_area:
		draw_arc(centro(), RAIO, 0.0, TAU, 64, Color(0.3, 1.0, 0.4, 0.9), 2.0)
		draw_arc(centro(), RAIO - TAMANHO * 0.5, 0.0, TAU, 64, Color(0.3, 1.0, 0.4, 0.4), 1.0)

## Anel de bolhinhas em volta do ícone (sentido horário, começando em cima).
##   PUNICAO: até FRACAO_PONTO brancas cozinhando / douradas (pulsando) no ponto; depois a régua
##            da punição (amarelo → laranja → vermelho em 50% → preto).
##   PROPORCIONAL / ABSOLUTO: cada bolhinha acesa tem a cor do aproveitamento no Q que ela representa.
## As apagadas ficam fraquinhas e brancas (não há marca do ponto).
func _desenhar_anel(ic: Dictionary) -> void:
	var centro_ic: Vector2 = ic["raiz"].position
	var tam: float = ic["tam"] * ic["raiz"].scale.x
	var alfa: float = ic["alfa"]
	var raio: float = ANEL_RAIO * tam
	var cheias: float = ic["progresso"] * ANEL_BOLHAS
	var pulso: float = 0.5 + 0.5 * sin(_t * 4.0)
	var item: ItemData = ic["item"]
	var cores: Array = cores_anel(item) if modo != ModoRegua.PUNICAO else []
	var chegou: bool = ic["ponto"] or ic["progresso"] >= FRACAO_PONTO - 0.01
	for b in ANEL_BOLHAS:
		var ang := -PI * 0.5 + TAU * (float(b) + 0.5) / ANEL_BOLHAS
		var p := centro_ic + Vector2.from_angle(ang) * raio
		var u: float = (float(b) + 0.5) / ANEL_BOLHAS
		# quanto esta bolhinha está acesa (0..1), com transição suave na que está enchendo
		var acesa: float = clampf(cheias - float(b), 0.0, 1.0)
		var cor: Color
		var r: float
		if acesa <= 0.0:
			cor = Color(COR_ANEL_COZINHANDO, 0.16 * alfa)
			r = ANEL_TAM * 0.5
		elif modo != ModoRegua.PUNICAO:
			cor = cores[b]
			var dourada: bool = cor.is_equal_approx(cor_escala(1.0))
			if dourada and ic["ponto"]:
				cor.a = (0.75 + 0.25 * pulso) * alfa   # brilhando: está no ponto agora
				r = ANEL_TAM * (1.0 + 0.15 * pulso)
			else:
				cor.a = lerpf(0.3, 0.95, acesa) * alfa
				r = lerpf(ANEL_TAM * 0.55, ANEL_TAM, acesa)
		elif u <= FRACAO_PONTO:
			if ic["ponto"]:
				cor = cor_escala(1.0)   # dourado brilhando: ponto perfeito
				cor.a = (0.75 + 0.25 * pulso) * alfa
				r = ANEL_TAM * (1.0 + 0.15 * pulso)
			elif chegou:
				cor = Color(cor_escala(1.0), 0.6 * alfa)   # já passou por aqui: dourado apagado
				r = ANEL_TAM * 0.85
			else:
				cor = Color(COR_ANEL_COZINHANDO, lerpf(0.18, 0.9, acesa) * alfa)
				r = lerpf(ANEL_TAM * 0.55, ANEL_TAM, acesa)
		else:
			cor = cor_punicao((u - FRACAO_PONTO) / (1.0 - FRACAO_PONTO))
			cor.a = lerpf(0.3, 0.95, acesa) * alfa
			r = lerpf(ANEL_TAM * 0.6, ANEL_TAM * 1.05, acesa)
		draw_circle(p, r * tam, cor)


## Vela em volta do ícone: o pavio queima no sentido horário a partir de cima.
##   PUNICAO: [0, t_min) tracejada branca · [t_min, FRACAO_PONTO] dourada · depois régua da punição.
##   PROPORCIONAL / ABSOLUTO: cada trecho com a cor do tempo que ele representa (tracejado antes do t_min).
func _desenhar_vela(ic: Dictionary) -> void:
	if not ic["tem_vela"]:
		return
	var centro_ic: Vector2 = ic["raiz"].position
	var tam: float = ic["tam"] * ic["raiz"].scale.x
	var raio: float = VELA_RAIO * tam
	var alfa: float = ic["alfa"]
	var ini: float = -PI * 0.5
	var u: float = clampf(float(ic["vela"]), 0.0, 1.0)
	var fim: float = ini + TAU * u
	var item: ItemData = ic["item"]
	# o que ainda falta queimar: bem fraquinho
	draw_arc(centro_ic, raio, fim, ini + TAU, 48, Color(COR_VELA, 0.12 * alfa), VELA_LARGURA * 0.6)
	if u <= 0.001:
		return
	if modo != ModoRegua.PUNICAO:
		var t_cheio: float = _t_cheio(item)
		var trechos: int = maxi(int(u * 64.0), 1)
		for k in trechos:
			var v0: float = u * float(k) / trechos
			var v1: float = u * float(k + 1) / trechos
			var t_meio: float = (v0 + v1) * 0.5 * t_cheio
			var tracejado: bool = item.t_min > 0.0 and t_meio < item.t_min
			if tracejado:
				v1 = v0 + (v1 - v0) * 0.55
			draw_arc(centro_ic, raio, ini + TAU * v0, ini + TAU * v1, 3, Color(cor_tempo(item, t_meio), (0.75 if tracejado else 0.95) * alfa), VELA_LARGURA)
	else:
		var u_min: float = float(ic["vela_umin"])
		# antes do mínimo: tracejada
		var u_a: float = minf(u, u_min)
		if u_a > 0.0:
			var passos: int = int(u_a * 32.0) + 1
			for k in passos:
				var a0: float = ini + TAU * u_a * float(k) / passos
				var a1: float = a0 + TAU * u_a / passos * 0.55
				draw_arc(centro_ic, raio, a0, a1, 4, Color(COR_VELA, 0.75 * alfa), VELA_LARGURA)
		# janela certa: dourada
		var u_b: float = minf(u, FRACAO_PONTO)
		if u_b > u_min:
			draw_arc(centro_ic, raio, ini + TAU * u_min, ini + TAU * u_b, 32, Color(cor_escala(1.0), 0.95 * alfa), VELA_LARGURA)
		# passou do máximo: cada trecho na cor da punição que ele representa
		if u > FRACAO_PONTO:
			var trechos_p: int = maxi(int((u - FRACAO_PONTO) * 48.0), 1)
			for k in trechos_p:
				var w0: float = lerpf(FRACAO_PONTO, u, float(k) / trechos_p)
				var w1: float = lerpf(FRACAO_PONTO, u, float(k + 1) / trechos_p)
				var cor_t: Color = cor_punicao(((w0 + w1) * 0.5 - FRACAO_PONTO) / (1.0 - FRACAO_PONTO))
				draw_arc(centro_ic, raio, ini + TAU * w0, ini + TAU * w1, 3, Color(cor_t, 0.95 * alfa), VELA_LARGURA)
	# chama na ponta
	var ponta := centro_ic + Vector2.from_angle(fim) * raio
	var pisca: float = 0.75 + 0.25 * sin(_t * 18.0 + ic["fase"])
	var cor_chama := Color(1.0, 0.95, 0.75)
	if ic["vela_estado"] == 2:
		cor_chama = cor_punicao(float(ic["vela_dano"]))
	draw_circle(ponta, 3.2 * pisca, Color(cor_chama, 0.9 * alfa))
	draw_circle(ponta, 1.6, Color(1, 1, 1, alfa))

## Camada da frente: rachaduras, gelo, fumaça e estrelinhas (por cima dos ícones).
func _desenhar_frente() -> void:
	for ic in _icones:
		if ic["perdido"]:
			continue
		var centro_ic: Vector2 = ic["raiz"].position
		var tam: float = ic["tam"] * ic["raiz"].scale.x
		var alfa: float = ic["alfa"]
		var lado: float = TAMANHO * tam
		# rachaduras
		if ic["rachado"] > 0.01:
			var brilha: float = ic["quente"] * (0.6 + 0.4 * sin(_t * 14.0 + ic["fase"]))
			for linha in ic["rachaduras"]:
				var n: int = linha.size()
				var visiveis: float = ic["rachado"] * (n - 1)
				for seg in n - 1:
					var parte: float = clampf(visiveis - float(seg), 0.0, 1.0)
					if parte <= 0.0:
						break
					var p0: Vector2 = centro_ic + (linha[seg] as Vector2) * lado
					var p1: Vector2 = centro_ic + (linha[seg] as Vector2).lerp(linha[seg + 1], parte) * lado
					_frente.draw_line(p0, p1, Color(COR_RACHADURA, COR_RACHADURA.a * alfa), 1.6)
					if brilha > 0.05:
						_frente.draw_line(p0, p1, Color(COR_RACHADURA_QUENTE, brilha * alfa), 0.8)
			# faíscas saindo das rachaduras enquanto está quente demais
			if ic["quente"] > 0.6 and randf() < 0.35:
				var lin: Array = ic["rachaduras"][randi() % ic["rachaduras"].size()]
				var q: Vector2 = centro_ic + (lin[randi() % lin.size()] as Vector2) * lado
				_frente.draw_circle(q + Vector2(randf_range(-3, 3), randf_range(-6, 0)), 1.2, Color(COR_RACHADURA_QUENTE, alfa))
		# gelo: cristais em volta
		if ic["frio"] > 0.02:
			var r_cristal: float = (TAMANHO * 0.62) * tam
			var t_c: float = CRISTAL_TAM * (0.6 + 0.4 * ic["frio"]) * tam
			var cor_gelo := Color(0.92, 0.96, 1.0, 0.85 * ic["frio"] * alfa)
			for k in CRISTAIS:
				var ang: float = ic["cristal_giro"] + TAU * float(k) / CRISTAIS + 0.15 * sin(_t * 0.7 + k)
				var p: Vector2 = centro_ic + Vector2.from_angle(ang) * r_cristal
				for raio_c in 3:
					var d := Vector2.from_angle(ang + PI * float(raio_c) / 3.0) * t_c
					_frente.draw_line(p - d, p + d, cor_gelo, 1.0)
		# fumaça (passou do ponto)
		for f in ic["fumaca"]:
			var vida: float = f["vida"] / f["dur"]
			var r: float = f["r"] * (1.0 + vida * 1.2) * tam
			_frente.draw_circle(centro_ic + f["p"] * tam, r, Color(0.12, 0.12, 0.12, 0.45 * (1.0 - vida) * alfa))
		# estrelinhas (no ponto)
		for e in ic["estrelas"]:
			var vida: float = e["vida"] / e["dur"]
			var brilho_e: float = sin(vida * PI)
			var p: Vector2 = centro_ic + e["p"] * tam + Vector2(0, -vida * 10.0)
			var t_e: float = 4.0 * brilho_e
			var cor_e := Color(1, 1, 0.9, brilho_e * alfa)
			_frente.draw_line(p - Vector2(t_e, 0), p + Vector2(t_e, 0), cor_e, 1.2)
			_frente.draw_line(p - Vector2(0, t_e), p + Vector2(0, t_e), cor_e, 1.2)
