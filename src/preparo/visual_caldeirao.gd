# visual_caldeirao.gd
# Tudo que é "aparência" do caldeirão e do fogo na cena de preparo:
#   cor do caldeirão pela temperatura, cor/visibilidade do fogo, partículas (bolhas e
#   brilhos), sprite forte ao atiçar, animação de ligar/desligar, tremor leve na
#   fervura (100 °C) e avermelhado acima disso, e respingo quando um item cai dentro.
# Não decide nada do jogo: a cena chama os métodos com o estado atual.
class_name VisualCaldeirao
extends Node

# ---- partículas ----
## T (°C) em que as partículas chegam ao máximo.
const T_PARTICULAS_MAX: float = 200.0
# ---- fogo ----
const ANIM_FOGO_ALTO := &"fogo_alto"
const TEMPO_FOGO_ALTO: float = 0.3
const COR_FOGO_LIGA = Color(1.0, 0.55, 0.15)
const COR_FOGO_DESLIGA = Color(0.6, 0.65, 0.75)
const FOGO_ALFA_MIN = 0.4
## Tamanho do fogo pelo F(t): F = T_AMB -> FOGO_ESCALA_MIN, F = F_EQ -> 1 (tamanho do .tscn),
## acima disso continua crescendo até FOGO_ESCALA_MAX. A base do fogo fica parada.
const FOGO_ESCALA_MIN: float = 0.5
const FOGO_ESCALA_MAX: float = 1.20
const FOGO_SUAVIZACAO: float = 5.0   # quão rápido o tamanho acompanha o F
## Oscilação da chama (sempre, por cima do tamanho do F): estica/achata e balança.
const OSC_ALTURA: float = 0.07       # ±7% na altura
const OSC_LARGURA: float = 0.04      # ±4% na largura
const OSC_BALANCO: float = 0.06      # balanço lateral (cisalhamento, rad)
## Rapidez da oscilação (o ruído é aleatório, não periódico; maior = mais nervosa).
const OSC_VELOCIDADE: float = 1.0


# ---- faíscas (acender o fogo) ----
## Intervalo entre faíscas enquanto segura para acender: começa espaçado e vai acelerando.
const FAISCA_INTERVALO_INICIO: float = 0.22
const FAISCA_INTERVALO_FIM: float = 0.05
const COR_FAISCA := Color(1.0, 0.92, 0.6)
const COR_FAISCA_FIM := Color(1.0, 0.45, 0.1, 0.0)
# ---- tremor e vermelho (pela temperatura T do caldo) ----
## Começa a tremer em T_TREMOR_INICIO e chega no tremor leve em T_FERVURA (100 °C).
const T_TREMOR_INICIO: float = 95.0
const T_FERVURA: float = 100.0
## Acima da fervura ele fica avermelhado até o máximo em T_VERMELHO_MAX.
const T_VERMELHO_MAX: float = 165.0
const TREMOR_LEVE_PX: float = 1.5      # amplitude em 100 °C
const TREMOR_MAX_PX: float = 3.5       # amplitude em T_VERMELHO_MAX
const VERMELHO_MAX: float = 0.85       # 0..1: quanto puxa para COR_VERMELHO no máximo
const COR_VERMELHO := Color(1.0, 0.22, 0.15)
## Vermelho de baixo para cima: acima de T_VERMELHO_INICIO o vermelho sobe do fundo e chega ao topo em T_VERMELHO_TOPO.
const T_VERMELHO_TOPO: float = 200.0   # vermelho chega ao topo, no máximo
const T_VERMELHO_INICIO: float = 90.0
const SHADER_RADIAL := """
shader_type canvas_item;
uniform float progresso : hint_range(0.0, 1.0) = 0.0;   // 0 = nada, 1 = vermelho até o topo
uniform float forca : hint_range(0.0, 1.0) = 0.85;
uniform vec4 cor_quente : source_color = vec4(1.0, 0.22, 0.15, 1.0);
uniform float suavidade = 0.3;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float frente = 1.0 - progresso;   // UV.y: 0 no topo, 1 no fundo; a frente sobe do fundo
	// aparece já no começo (some nos primeiros 10%) e fica mais forte até o máximo no topo
	float m = smoothstep(frente - suavidade, frente, UV.y) * smoothstep(0.0, 0.1, progresso) * (0.4 + 0.6 * progresso) * forca;
	c.rgb = mix(c.rgb, c.rgb * cor_quente.rgb * 1.3, m);
	COLOR = c;
}
"""
var _mat_radial: ShaderMaterial
# ---- caldo turvo (visão geral do aproveitamento) ----
## Quanto pior o aproveitamento médio, mais turvo: caldeirão mais escuro, bolhas maiores,
## mais lentas e escuras, quase sem estrelas. Bom aproveitamento: calmo e brilhante.
const TURVO_ESCURECE: float = 0.35      # escurecimento máximo do caldeirão
const TURVO_BOLHA_ESCALA: float = 1.8   # bolhas até 80% maiores
const TURVO_BOLHA_LENTA: float = 0.45   # bolhas até 55% mais lentas
const TURVO_ESTRELAS_MIN: float = 0.15  # estrelas que sobram no pior caso (15%)
const LIMPO_BRILHO: float = 0.12        # brilho extra quando está tudo bem
# ---- boca (destino dos itens lançados), relativa ao sprite do caldeirão ----
const BOCA_OFFSET := Vector2(0, 0)

var caldeirao: AnimatedSprite2D
var fogo: AnimatedSprite2D
var bolhas: GPUParticles2D
var brilhos: GPUParticles2D

var _mat_bolhas: ParticleProcessMaterial
var _mat_brilhos: ParticleProcessMaterial
var _caldeirao_pos_base := Vector2.ZERO
var _caldeirao_escala_base := Vector2.ONE
var _fogo_escala_base := Vector2.ONE
var _fogo_pos_base := Vector2.ZERO
var _fogo_escala_F: float = FOGO_ESCALA_MIN   # parte do tamanho que vem do F (suavizada)
var _fogo_pulso := Vector2.ONE                # parte que vem das animações (atiçar, ligar...)
var _tempo_fogo_alto: float = 0.0
var _intensidade_tremor: float = 0.0   # 0..1, suavizada
var _t: float = 0.0
var _ruido := FastNoiseLite.new()   # oscilação aleatória e suave da chama

var _faisca_timer: float = 0.0
var _fogo_aceso: bool = false
var _turvo: float = 0.0                # 0 = limpo, 1 = turvo (suavizado)
var _bolha_escala_base := Vector2.ONE  # scale_min/max originais do material das bolhas
# ---- vapor (acima de 100 °C) ----
## O vapor começa na fervura e fica no máximo em T_VAPOR_MAX.
const T_VAPOR_MAX: float = 160.0
const COR_VAPOR := Color(0.92, 0.92, 1.0, 0.35)
var _vapor: CPUParticles2D
## Fumaça contínua quando o fogo está quase apagando (F perto de F_LIMIT_MIN).
var _fumaca_fraca: CPUParticles2D
## Quanto acima de F_LIMIT_MIN já conta como "quase apagando".
const MARGEM_APAGAR: float = 80.0


func configurar(p_caldeirao: AnimatedSprite2D, p_fogo: AnimatedSprite2D, p_bolhas: GPUParticles2D, p_brilhos: GPUParticles2D) -> void:
	caldeirao = p_caldeirao
	fogo = p_fogo
	bolhas = p_bolhas
	brilhos = p_brilhos
	if caldeirao:
		_caldeirao_pos_base = caldeirao.position
		_caldeirao_escala_base = caldeirao.scale
		var sh := Shader.new()
		sh.code = SHADER_RADIAL
		_mat_radial = ShaderMaterial.new()
		_mat_radial.shader = sh
		_mat_radial.set_shader_parameter("cor_quente", COR_VERMELHO)
		_mat_radial.set_shader_parameter("forca", VERMELHO_MAX)
		caldeirao.material = _mat_radial
	if fogo:
		_fogo_escala_base = fogo.scale
		_fogo_pos_base = fogo.position
	# Cada sistema ganha a própria cópia do material (no .tscn os dois compartilham um só).
	if bolhas and bolhas.process_material:
		_mat_bolhas = bolhas.process_material.duplicate()
		bolhas.process_material = _mat_bolhas
		_bolha_escala_base = Vector2(_mat_bolhas.scale_min, _mat_bolhas.scale_max)
	if brilhos and brilhos.process_material:
		_mat_brilhos = brilhos.process_material.duplicate()
		brilhos.process_material = _mat_brilhos
	_criar_vapor()
	resetar()

func resetar() -> void:
	_intensidade_tremor = 0.0
	_turvo = 0.0
	_tempo_fogo_alto = 0.0
	_fogo_escala_F = FOGO_ESCALA_MIN
	_fogo_pulso = Vector2.ONE
	_fogo_aceso = false
	_aplicar_escala_fogo()
	if caldeirao:
		caldeirao.position = _caldeirao_pos_base
		caldeirao.modulate = Color.WHITE
	_aplicar_particulas(0.0)

## Ponto onde os itens lançados caem.
func boca() -> Vector2:
	if caldeirao:
		return caldeirao.global_position + BOCA_OFFSET * _caldeirao_escala_base.y * 0.5
	return Vector2(320, 230)

# =============================================================================
# A CADA FRAME
# =============================================================================
## perda_media: 0 = nada perdido, 1 = tudo perdido (média dos ingredientes).
func atualizar(sistema: SistemaTermico, delta: float, perda_media: float, _punindo_agora: bool = false) -> void:
	_t += delta
	# caldeirão: cor normal até 90 °C; acima disso o vermelho sobe do fundo e chega ao topo (máximo) em 200 °C
	if caldeirao:
		caldeirao.self_modulate = Color.WHITE
		if _mat_radial:
			var p := clampf((sistema.T - T_VERMELHO_INICIO) / (T_VERMELHO_TOPO - T_VERMELHO_INICIO), 0.0, 1.0)
			_mat_radial.set_shader_parameter("progresso", p)
	# fogo: cor/intensidade pela temperatura do fogo
	if fogo:
		var cor = sistema.get_cor_fogo()
		if sistema.fogo_ligado:
			cor.a=maxf(cor.a,FOGO_ALFA_MIN)
		_fogo_aceso = sistema.fogo_ligado
		fogo.self_modulate = cor
		fogo.visible = sistema.fogo_ligado or cor.a > 0.05
		_fogo_escala_F = lerpf(_fogo_escala_F, escala_por_F(sistema.F), clampf(delta * FOGO_SUAVIZACAO, 0.0, 1.0))
		_aplicar_escala_fogo()
	_atualizar_particulas(sistema.T)
	_atualizar_vapor(sistema.T)
	_atualizar_fumaca_fraca(sistema)
	_aplicar_turvo(delta, perda_media)
	# volta do sprite forte
	if _tempo_fogo_alto > 0.0:
		_tempo_fogo_alto -= delta
		if _tempo_fogo_alto <= 0.0 and fogo and fogo.sprite_frames and fogo.sprite_frames.has_animation(&"default"):
			fogo.play(&"default")
	_tremer(delta, sistema.T)

# =============================================================================
# PARTÍCULAS
# =============================================================================
## Bolhas: mais e mais rápidas conforme T. Brilhos: sobem mais alto, abrem mais e giram mais.
## A velocidade é a INICIAL (sorteada quando a partícula nasce, conforme o T daquela hora):
## as que já estão na tela não aceleram nem freiam quando T muda (speed_scale fica fixo).
func _atualizar_particulas(T: float) -> void:
	_aplicar_particulas(clampf((T - SistemaTermico.T_AMB) / (T_PARTICULAS_MAX - SistemaTermico.T_AMB), 0.0, 1.0))

func _aplicar_particulas(tn: float) -> void:
	if bolhas:
		bolhas.amount_ratio = lerpf(0.03, 1.0, tn)
		bolhas.speed_scale = 1.0
	if _mat_bolhas:
		_mat_bolhas.initial_velocity_min = lerpf(3.0, 45.0, sqrt(tn))
		_mat_bolhas.initial_velocity_max = lerpf(8.0, 220.0, tn)
	if brilhos:
		brilhos.amount_ratio = lerpf(0.01, 1.0, tn * tn)
		brilhos.speed_scale = 1.0
	if _mat_brilhos:
		_mat_brilhos.initial_velocity_min = lerpf(5.0, 150.0, tn)
		_mat_brilhos.initial_velocity_max = lerpf(15.0, 260.0, tn)   # chegam mais longe
		_mat_brilhos.spread = lerpf(20.0, 50.0, tn)                     # abrem mais
		var a= 10
		_mat_brilhos.angular_velocity_min = lerpf(-90.0, -360.0*a, tn)    # giram mais
		_mat_brilhos.angular_velocity_max = lerpf(90.0, 360.0*a, tn)

# =============================================================================
# CALDO TURVO / LIMPO (visão geral do aproveitamento)
# =============================================================================
func _aplicar_turvo(delta: float, perda_media: float) -> void:
	_turvo = lerpf(_turvo, clampf(perda_media * 1.5, 0.0, 1.0), clampf(delta * 2.0, 0.0, 1.0))
	var limpo: float = 1.0 - _turvo
	if caldeirao:
		var cor: Color = caldeirao.self_modulate.darkened(TURVO_ESCURECE * _turvo)
		caldeirao.self_modulate = cor.lightened(LIMPO_BRILHO * limpo * limpo)
	if bolhas:
		bolhas.modulate = Color.WHITE.darkened(0.55 * _turvo)
	if brilhos:
		brilhos.amount_ratio *= lerpf(1.0, TURVO_ESTRELAS_MIN, _turvo)
	if _mat_bolhas:
		var esc: float = lerpf(1.0, TURVO_BOLHA_ESCALA, _turvo)
		if absf(_mat_bolhas.scale_max - _bolha_escala_base.y * esc) > 0.01:
			_mat_bolhas.scale_min = _bolha_escala_base.x * esc
			_mat_bolhas.scale_max = _bolha_escala_base.y * esc
		var lenta: float = lerpf(1.0, TURVO_BOLHA_LENTA, _turvo)
		_mat_bolhas.initial_velocity_min *= lenta
		_mat_bolhas.initial_velocity_max *= lenta

# =============================================================================
# TREMOR (pela temperatura: leve na fervura, um pouco mais forte acima)
# Problemas na poção NÃO fazem o caldeirão tremer (isso fica com os ícones/painel).
# =============================================================================
## 0 até 100 °C, 1 em T_VERMELHO_MAX.
static func _fator_vermelho(T: float) -> float:
	return clampf((T - T_FERVURA) / (T_VERMELHO_MAX - T_FERVURA), 0.0, 1.0)

## Amplitude alvo (px): 0 até T_TREMOR_INICIO, sobe suave até TREMOR_LEVE_PX em 100 °C
## e daí até TREMOR_MAX_PX em T_VERMELHO_MAX.
static func amplitude_tremor(T: float) -> float:
	if T < T_TREMOR_INICIO:
		return 0.0
	var leve: float = smoothstep(T_TREMOR_INICIO, T_FERVURA, T) * TREMOR_LEVE_PX
	return lerpf(leve, TREMOR_MAX_PX, _fator_vermelho(T))

func _tremer(delta: float, T: float) -> void:
	if not caldeirao:
		return
	# _intensidade_tremor guarda a amplitude suavizada (px)
	_intensidade_tremor = lerpf(_intensidade_tremor, amplitude_tremor(T), clampf(delta * 4.0, 0.0, 1.0))
	var amp: float = _intensidade_tremor
	if amp > 0.05:
		caldeirao.position = _caldeirao_pos_base + Vector2(randf_range(-amp, amp), randf_range(-amp, amp) * 0.6)
	else:
		caldeirao.position = _caldeirao_pos_base
	caldeirao.modulate = Color.WHITE

## 0..1 (proporção do tremor máximo).
func intensidade_tremor() -> float:
	return _intensidade_tremor / TREMOR_MAX_PX

# =============================================================================
# FOGO
# =============================================================================
## Escala do fogo para um valor de F (sem a suavização).
static func escala_por_F(F: float) -> float:
	var fator: float = (F - SistemaTermico.T_AMB) / (SistemaTermico.F_EQ - SistemaTermico.T_AMB)
	return clampf(lerpf(FOGO_ESCALA_MIN, 1.0, fator), FOGO_ESCALA_MIN, FOGO_ESCALA_MAX)

## escala final = base do .tscn × F × pulso; reposiciona para a base (embaixo) não sair do lugar.
func _aplicar_escala_fogo() -> void:
	if not fogo:
		return
	var escala: Vector2 = _fogo_escala_base * _fogo_escala_F * _fogo_pulso
	# chama viva: estica/achata e balança (menos quando é só brasa)
	var viva: float = 1.0 if _fogo_aceso else 0.4
	# ruído suave (não repete): cada eixo lê um "trilho" diferente do mesmo ruído
	var tt: float = _t * OSC_VELOCIDADE
	escala.y *= 1.0 + OSC_ALTURA * viva * _osc(tt * 1.6, 0.0)
	escala.x *= 1.0 + OSC_LARGURA * viva * _osc(tt * 1.2, 100.0)
	var cisalha: float = OSC_BALANCO * viva * _osc(tt * 0.9, 200.0)
	fogo.scale = escala
	fogo.skew = cisalha
	# mantém a base (embaixo, no centro) no mesmo lugar, mesmo inclinada
	var meia_altura: float = _altura_frame_fogo() * 0.5
	var base_agora: Vector2 = Transform2D(0.0, escala, cisalha, Vector2.ZERO).basis_xform(Vector2(0, meia_altura))
	var base_original: Vector2 = Vector2(0, meia_altura * _fogo_escala_base.y)
	fogo.position = _fogo_pos_base + base_original - base_agora


## Ruído entre -1 e 1: mistura uma onda lenta com tremidas rápidas, sem período.
func _osc(x: float, trilho: float) -> float:
	if _ruido.seed == 0:
		_ruido.seed = randi()
		_ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_ruido.frequency = 1.0
	var lento: float = _ruido.get_noise_2d(x, trilho)
	var rapido: float = _ruido.get_noise_2d(x * 3.1, trilho + 50.0)
	return clampf((lento * 0.7 + rapido * 0.3) * 1.6, -1.0, 1.0)

func _altura_frame_fogo() -> float:
	if not fogo.sprite_frames or not fogo.centered:
		return 0.0
	var tex: Texture2D = fogo.sprite_frames.get_frame_texture(fogo.animation, fogo.frame)
	return float(tex.get_height()) if tex else 0.0

func _pulsar_fogo(de: Vector2, tempo: float, trans := Tween.TRANS_QUAD) -> void:
	_fogo_pulso = de
	fogo.create_tween().tween_property(self, "_fogo_pulso", Vector2.ONE, tempo) \
		.set_trans(trans).set_ease(Tween.EASE_OUT)

## Atiçar: o fogo troca para o sprite forte (fogo_for) por alguns instantes e dá um pulo.
func aticar() -> void:
	if not fogo:
		return
	if fogo.sprite_frames and fogo.sprite_frames.has_animation(ANIM_FOGO_ALTO):
		fogo.play(ANIM_FOGO_ALTO)
		_tempo_fogo_alto = TEMPO_FOGO_ALTO
	_pulsar_fogo(Vector2(1.15, 1.35), TEMPO_FOGO_ALTO)
	_labaredas()

## Enquanto segura o botão de fogo: ele vai "esquentando" (laranja se vai acender,
## cinza se vai abafar) e treme cada vez mais, até disparar.
func carregando_fogo(botao: Control, progresso: float, fogo_ligado: bool) -> void:
	if not botao:
		return
	var alvo: Color = COR_FOGO_DESLIGA if fogo_ligado else COR_FOGO_LIGA
	botao.modulate = Color.WHITE.lerp(alvo, progresso)
	botao.rotation = randf_range(-1.0, 1.0) * deg_to_rad(4.0) * progresso
	# tentando acender: faíscas na lenha, cada vez mais frequentes e fortes
	if not fogo_ligado:
		_faisca_timer -= get_process_delta_time()
		if _faisca_timer <= 0.0:
			_faisca_timer = lerpf(FAISCA_INTERVALO_INICIO, FAISCA_INTERVALO_FIM, progresso) * randf_range(0.7, 1.3)
			_faiscas(randi_range(1, 5 + int(6.0 * progresso)), lerpf(1.2, 1.8, progresso), 0.0)

## Disparou: pop do botão e o fogo nasce (ligou) ou achata (desligou). Devolve a cor do aviso.
func liga_desliga(botao: Control, ligou: bool) -> Color:
	var cor: Color = COR_FOGO_LIGA if ligou else COR_FOGO_DESLIGA
	if botao:
		botao.rotation = 0.0
		botao.pivot_offset = botao.size * 0.5
		botao.scale = Vector2(1.3, 1.3)
		botao.modulate = cor * 1.4
		var tw := botao.create_tween().set_parallel(true)
		tw.tween_property(botao, "scale", Vector2(0.88, 0.88), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(botao, "modulate", cor, 0.25)
	_faisca_timer = 0.0
	if fogo:
		if ligou:
			# faísca de sucesso: estouro grande + clarão, e o fogo nasce de baixo
			_faiscas(64, 2.6, 1.0)
			get_tree().create_timer(0.12).timeout.connect(func(): _faiscas(32, 1.9, 1.0))
			fogo.visible = true
			_pulsar_fogo(Vector2(0.25, 0.1), 0.6, Tween.TRANS_BACK)
			var cor_original: Color = fogo.modulate
			fogo.modulate = Color(2.2, 1.8, 1.2)
			fogo.create_tween().tween_property(fogo, "modulate", cor_original, 0.5)
		else:
			var tw_apaga := fogo.create_tween()   # passos em sequência: achata e volta
			tw_apaga.tween_property(self, "_fogo_pulso", Vector2(1.1, 0.5), 0.15)
			tw_apaga.tween_property(self, "_fogo_pulso", Vector2.ONE, 0.35)
	return cor

## Vapor saindo da boca do caldeirão: nada até 100 °C, cada vez mais denso e rápido acima.
func _criar_vapor() -> void:
	if not caldeirao or not caldeirao.get_parent():
		return
	_vapor = CPUParticles2D.new()
	_vapor.name = "Vapor"
	_vapor.amount = 40
	_vapor.lifetime = 1.8
	_vapor.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_vapor.emission_rect_extents = Vector2(60, 4)
	_vapor.direction = Vector2.UP
	_vapor.spread = 18.0
	_vapor.gravity = Vector2(0, -25)
	_vapor.initial_velocity_min = 25.0
	_vapor.initial_velocity_max = 60.0
	_vapor.damping_min = 5.0
	_vapor.damping_max = 15.0
	_vapor.scale_amount_min = 8.0
	_vapor.scale_amount_max = 16.0
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.4))
	curva.add_point(Vector2(1, 1.8))
	_vapor.scale_amount_curve = curva
	var rampa := Gradient.new()
	rampa.set_color(0, Color(COR_VAPOR, 0.0))
	rampa.set_color(1, Color(COR_VAPOR, 0.0))
	rampa.add_point(0.25, COR_VAPOR)
	_vapor.color_ramp = rampa
	_vapor.z_index = caldeirao.z_index + 2
	_vapor.emitting = false
	caldeirao.get_parent().add_child(_vapor)
	_vapor.global_position = boca()

func _atualizar_vapor(T: float) -> void:
	if not _vapor:
		return
	var v: float = clampf((T - 100.0) / (T_VAPOR_MAX - 100.0), 0.0, 1.0)
	_vapor.emitting = v > 0.01
	_vapor.modulate.a = lerpf(0.25, 1.0, v)   # CPUParticles2D não tem amount_ratio: mais denso = mais opaco
	_vapor.speed_scale = lerpf(0.7, 1.6, v)
	_vapor.global_position = boca()

## Abafando (segurando o botão com o fogo aceso): o fogo achata um pouco a cada passo.
func abafar(botao: Control) -> void:
	_baforada()
	if botao:
		botao.pivot_offset = botao.size * 0.5
		botao.scale = Vector2(0.8, 0.8)
		botao.create_tween().tween_property(botao, "scale", Vector2(0.88, 0.88), 0.15)
	if fogo:
		_pulsar_fogo(Vector2(1.08, 0.7), 0.25)

## O fogo ficou fraco demais e apagou: achata, solta uma nuvem de fumaça e o botão fica cinza.
func apagou(botao: Control) -> Color:
	var cor := liga_desliga(botao, false)
	_fumaca_apagar()
	return cor

## true quando o fogo está aceso mas quase apagando.
static func quase_apagando(sistema: SistemaTermico) -> bool:
	return sistema.fogo_ligado and sistema.F < SistemaTermico.F_LIMIT_MIN + MARGEM_APAGAR

func _atualizar_fumaca_fraca(sistema: SistemaTermico) -> void:
	if not fogo or not fogo.get_parent():
		return
	if _fumaca_fraca == null:
		var p := CPUParticles2D.new()
		p.amount = 14
		p.lifetime = 1.6
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2(22, 3)
		p.direction = Vector2.UP
		p.spread = 20.0
		p.initial_velocity_min = 20.0
		p.initial_velocity_max = 45.0
		p.gravity = Vector2(0, -15)
		p.scale_amount_min = 5.0
		p.scale_amount_max = 10.0
		var rampa := Gradient.new()
		rampa.set_color(0, Color(0.4, 0.4, 0.4, 0.6))
		rampa.set_color(1, Color(0.25, 0.25, 0.25, 0.0))
		p.color_ramp = rampa
		p.z_index = fogo.z_index + 1
		p.emitting = false
		fogo.get_parent().add_child(p)
		_fumaca_fraca = p
	_fumaca_fraca.position = _base_fogo()
	var perto := quase_apagando(sistema)
	if _fumaca_fraca.emitting != perto:
		_fumaca_fraca.emitting = perto
	if perto:   # mais perto de apagar = mais densa
		var v := 1.0 - (sistema.F - SistemaTermico.F_LIMIT_MIN) / MARGEM_APAGAR
		_fumaca_fraca.modulate.a = lerpf(0.4, 1.0, clampf(v, 0.0, 1.0))

## Labaredas: faíscas/chamas subindo quando abana (atiça) o fogo.
## Abanar seguido aumenta as labaredas (combo dentro de LABAREDA_JANELA segundos).
const LABAREDA_JANELA: float = 0.9
var _labareda_combo: int = 0
var _labareda_ultima: float = -10.0

func _labaredas() -> void:
	if not fogo or not fogo.get_parent():
		return
	var agora := Time.get_ticks_msec() / 1000.0
	_labareda_combo = _labareda_combo + 1 if agora - _labareda_ultima < LABAREDA_JANELA else 1
	_labareda_ultima = agora
	var forca: float = clampf(float(_labareda_combo) / 4.0, 0.25, 1.0)
	_brasas(forca)
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = int(10 + 14 * forca)
	p.lifetime = 0.6
	p.position = _base_fogo() + Vector2(0, PARTICULAS_DESCER)
	p.z_index = fogo.z_index + 1
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(24, 4)
	p.direction = Vector2.UP
	p.spread = 22.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 170.0
	p.gravity = Vector2(0, -60)
	p.damping_min = 30.0
	p.damping_max = 60.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	var curva := Curve.new()
	curva.add_point(Vector2(0, 1.0))
	curva.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = curva
	var rampa := Gradient.new()
	rampa = _rampa_fogo(0.4, 0.9)
	p.color_ramp = rampa
	fogo.get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)

## Faíscas laranja subindo ao abanar: pequenas, sobem alto balançando e somem no ar.
func _brasas(forca: float) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.55
	p.amount = int(8 + 22 * forca)
	p.lifetime = lerpf(1.0, 1.7, forca)
	p.randomness = 0.5
	p.position = _base_fogo() + Vector2(0, PARTICULAS_DESCER - 10.0)
	p.z_index = fogo.z_index + 2
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(26, 6)
	p.direction = Vector2.UP
	p.spread = 28.0
	p.initial_velocity_min = 60.0 + 40.0 * forca
	p.initial_velocity_max = 130.0 + 70.0 * forca
	p.gravity = Vector2(0, -35)
	p.damping_min = 10.0
	p.damping_max = 25.0
	p.tangential_accel_min = -45.0   # balanço de lado, como brasa no ar quente
	p.tangential_accel_max = 45.0
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.2
	var curva := Curve.new()
	curva.add_point(Vector2(0, 1.0))
	curva.add_point(Vector2(0.7, 0.8))
	curva.add_point(Vector2(1, 0.0))
	p.scale_amount_curve = curva
	var rampa := Gradient.new()
	rampa = _rampa_fogo(0.25)
	p.color_ramp = rampa
	fogo.get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.4).timeout.connect(p.queue_free)

## Baforada pequena de fumaça a cada passo de abafar.
func _baforada() -> void:
	if not fogo or not fogo.get_parent():
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 8
	p.lifetime = 0.8
	p.position = _base_fogo()
	p.z_index = fogo.z_index + 1
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(20, 3)
	p.direction = Vector2.UP
	p.spread = 35.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2(0, -20)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 8.0
	var rampa := Gradient.new()
	rampa.set_color(0, Color(0.5, 0.5, 0.5, 0.55))
	rampa.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	p.color_ramp = rampa
	fogo.get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)

## Nuvem de fumaça cinza subindo da lenha.
func _fumaca_apagar() -> void:
	if not fogo or not fogo.get_parent():
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.7
	p.amount = 26
	p.lifetime = 1.4
	p.position = _base_fogo()
	p.z_index = fogo.z_index + 1
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(26, 4)
	p.direction = Vector2.UP
	p.spread = 25.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 80.0
	p.gravity = Vector2(0, -30)
	p.damping_min = 10.0
	p.damping_max = 25.0
	p.scale_amount_min = 6.0
	p.scale_amount_max = 12.0
	var curva := Curve.new()
	curva.add_point(Vector2(0, 0.5))
	curva.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curva
	var rampa := Gradient.new()
	rampa.set_color(0, Color(0.45, 0.45, 0.45, 0.7))
	rampa.set_color(1, Color(0.25, 0.25, 0.25, 0.0))
	p.color_ramp = rampa
	fogo.get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.3).timeout.connect(p.queue_free)

# =============================================================================
# FAÍSCAS
# =============================================================================
## Toque no botão com o fogo apagado: uma faísca na hora. Se continuar segurando,
## carregando_fogo() segue faiscando (a próxima vem depois do intervalo inicial).
func faisca_inicial() -> void:
	_faiscas(randi_range(6, 9), 1.5, 0.0)
	_faisca_timer = FAISCA_INTERVALO_INICIO

## Partículas do fogo (faíscas, labaredas, brasas) saem um pouco abaixo da base.
const PARTICULAS_DESCER: float = 16.0

## Cor do fogo agora (a mesma do sprite); apagado = laranja padrão.
func _cor_fogo() -> Color:
	var c: Color = fogo.self_modulate if fogo else COR_FOGO_LIGA
	if c.a < 0.1:
		c = COR_FOGO_LIGA
	c.a = 1.0
	return c

## Rampa: clara no começo, a cor do fogo no meio, some no fim.
func _rampa_fogo(meio: float = 0.3, alfa_meio: float = 1.0) -> Gradient:
	var c := _cor_fogo()
	var g := Gradient.new()
	g.set_color(0, c.lerp(Color.WHITE, 0.55))
	g.set_color(1, Color(c.darkened(0.35), 0.0))
	g.add_point(meio, Color(c, alfa_meio))
	return g

## Base do fogo (onde fica a lenha), no espaço do pai do sprite do fogo.
func _base_fogo() -> Vector2:
	if not fogo:
		return Vector2.ZERO
	return Vector2(fogo.position.x, fogo.position.y + _altura_frame_fogo() * 0.5 * fogo.scale.y * 0.8)

## Um estouro de faíscas. forca escala velocidade/tamanho; sucesso (0..1) deixa mais
## espalhado, mais alto e mais duradouro.
func _faiscas(qtd: int, forca: float, sucesso: float) -> void:
	if not fogo or not fogo.get_parent():
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = maxi(qtd, 1)
	p.lifetime = lerpf(0.3, 0.9, sucesso) * randf_range(0.8, 1.2)
	p.position = _base_fogo() + Vector2(randf_range(-18.0, 18.0) * (1.0 - sucesso), PARTICULAS_DESCER)
	p.z_index = fogo.z_index + 1
	p.direction = Vector2.UP
	p.spread = lerpf(55.0, 85.0, sucesso)
	p.initial_velocity_min = 70.0 * forca
	p.initial_velocity_max = 110.0 * forca
	p.gravity = Vector2(0, -220)
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.scale_amount_min = 2.0 * forca
	p.scale_amount_max = 4.0 * forca
	var rampa := Gradient.new()
	rampa = _rampa_fogo(0.35)
	if sucesso > 0.0:
		rampa.set_color(0, Color.WHITE)
	p.color_ramp = rampa
	fogo.get_parent().add_child(p)
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)

# =============================================================================
# RESPINGO (item caiu no caldeirão)
# =============================================================================
## Gotas na boca do caldeirão + o caldeirão "engole" o item (achata e volta).
func respingo(onde: Node) -> void:
	var gotas := CPUParticles2D.new()
	gotas.one_shot = true
	gotas.explosiveness = 1.0
	gotas.amount = 14
	gotas.lifetime = 0.6
	gotas.direction = Vector2.UP
	gotas.spread = 55.0
	gotas.initial_velocity_min = 90.0
	gotas.initial_velocity_max = 190.0
	gotas.gravity = Vector2(0, 520)
	gotas.scale_amount_min = 3.0
	gotas.scale_amount_max = 6.0
	gotas.color = Color(0.75, 0.9, 1.0, 0.9)
	gotas.z_index = 40
	onde.add_child(gotas)
	gotas.global_position = boca()
	gotas.emitting = true
	onde.get_tree().create_timer(gotas.lifetime + 0.2, true, false, true).timeout.connect(gotas.queue_free)
	if caldeirao:
		caldeirao.scale = _caldeirao_escala_base * Vector2(1.08, 0.92)
		caldeirao.create_tween().tween_property(caldeirao, "scale", _caldeirao_escala_base, 0.35) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
