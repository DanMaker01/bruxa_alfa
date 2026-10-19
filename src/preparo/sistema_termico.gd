# =============================================================================
# sistema_termico.gd
# =============================================================================
class_name SistemaTermico
extends RefCounted

# =============================================================================
# CONSTANTES FÍSICAS
# =============================================================================
const T_AMB: float = 20.0
const F_EQ: float = 800.0
const T_EQ: float = 100.0

const K: float = 0.5
const HF: float = 0.01
const C: float = 2.0
const C_F: float = 2.0



# =============================================================================
# CONSTANTES CALCULADAS
# =============================================================================
var h: float
var P_comb: float

# =============================================================================
# CONSTANTES DE AÇÃO
# =============================================================================
const CONST_A: float = 20.0	# pulso de fogo (clique curto no botão F)
const CONST_B: float = 10.0	# queda de T quando um ingrediente entra
## Segurando o botão de fogo (aceso): tira CONST_A de F a cada 0,3 s ("abafar").
## Se F ficar abaixo disto ao abafar, o fogo apaga.
## Obs.: com as constantes atuais, segurando sem parar F se estabiliza perto de ~510
## (o fogo aceso puxa F de volta para F_EQ), então o limite precisa ficar acima disso.
const F_LIMIT_MIN: float = 600.0

# =============================================================================
# PASSO DE INTEGRAÇÃO
# =============================================================================
const DT: float = 0.01

# =============================================================================
# ESTADO
# =============================================================================
var T: float = 20.0
var F: float = 20.0
var t_sim: float = 0.0
var fogo_ligado: bool = false
var t_fogo_ligado: float = -1.0	 # ← NOVO
var dt_step_atual: float = DT

# =============================================================================
# CONSTRUTOR
# =============================================================================
func _init():
	h = K * (F_EQ - T_EQ) / (T_EQ - T_AMB)
	P_comb = K * (F_EQ - T_EQ) + HF * (F_EQ - T_AMB)
	print("[SistemaTermico] h = ", h, " | P_comb = ", P_comb)

# =============================================================================
# INTEGRAÇÃO COM SUB-PASSOS
# =============================================================================
func step(dt_real: float) -> void:
	var sim_time = dt_real * 1.0
	var n_steps = max(1, int(sim_time / DT))
	dt_step_atual = sim_time / n_steps
	
	for i in range(n_steps):
		var dT = (K * (F - T) - h * (T - T_AMB)) / C
		var dF: float
		
		if fogo_ligado:
			dF = (-K * (F - T) - HF * (F - T_AMB) + P_comb) / C_F
		else:
			dF = (-K * (F - T) - HF * (F - T_AMB)) / C_F
		
		T += dT * dt_step_atual
		F += dF * dt_step_atual
		t_sim += dt_step_atual

# =============================================================================
# AÇÕES
# =============================================================================
# Pulso de fogo (clique curto no botão F) → +CONST_A em F
func dar_pulso_fogo() -> void:
	F += CONST_A

# Ingrediente (clique na lista) — por enquanto é o mesmo pulso
# (no futuro, cada ingrediente pode ter efeito próprio)
# Abafar (segurando o botão com o fogo aceso) → −CONST_A em F.
# Devolve true se o fogo ficou fraco demais (F < F_LIMIT_MIN) e apagou.
func abafar_fogo() -> bool:
	if not fogo_ligado:
		return false
	F = maxf(F - CONST_A, T_AMB)
	if F < F_LIMIT_MIN:
		desligar_fogo()
		return true
	return false

func adicionar_ingrediente(_nome: String = "") -> void:
	T -= CONST_B


func ligar_fogo() -> void:
	fogo_ligado = true
	t_fogo_ligado = t_sim		# ← reinicia contagem toda vez

func desligar_fogo() -> void:
	fogo_ligado = false
	# t_fogo_ligado NÃO é resetado aqui
	# (mas como o indicador exige fogo_ligado == true, não conta mesmo assim)

func alternar_fogo() -> void:
	if fogo_ligado:
		desligar_fogo()
	else:
		ligar_fogo()

# =============================================================================
# RESET
# =============================================================================
func reset() -> void:
	T = T_AMB
	F = T_AMB
	t_sim = 0.0
	fogo_ligado = false
	t_fogo_ligado = -1.0		 # ← NOVO
	dt_step_atual = DT
# =============================================================================
# CONSULTAS
# =============================================================================
func esta_em_equilibrio_T() -> bool:
	return abs(T - T_EQ) < 0.5

func esta_em_equilibrio_F() -> bool:
	return abs(F - F_EQ) < 4.0

# =============================================================================
# INTENSIDADE DO FOGO — agora com 4 FASES
# =============================================================================
#  F < 70	   → 0%	(apagado / frio)
#  70 .. 800	→ 0..35% (brasa baixa, avermelhado)
#  800 .. 1600  → 35..90% (chama média, laranja)
#  >= 1600	  → 90..100% + amarelado intenso
# =============================================================================
const FASE_1_MIN: float = 70.0
const FASE_2_MIN: float = 800.0
const FASE_3_MIN: float = 1600.0

func get_intensidade_fogo() -> float:
	if F < FASE_1_MIN:
		return 0.0
	elif F < FASE_2_MIN:
		return 0.35 * (F - FASE_1_MIN) / (FASE_2_MIN - FASE_1_MIN)
	elif F < FASE_3_MIN:
		return 0.35 + 0.55 * (F - FASE_2_MIN) / (FASE_3_MIN - FASE_2_MIN)
	else:
		# 90% .. 100% com saturação
		var t = min(1.0, (F - FASE_3_MIN) / 500.0)
		return 0.90 + 0.10 * t

# =============================================================================
# COR DO FOGO — retorna (cor, alpha)
# =============================================================================
# Vermelho escuro → laranja → amarelo claro
# =============================================================================
func get_cor_fogo() -> Color:
	var i = get_intensidade_fogo()
	
	if i <= 0.0:
		return Color(1.0, 0.4, 0.1, 0.0)
	
	if F < FASE_2_MIN:
		# brasa: vermelho escuro
		var t = i / 0.35	# 0..1
		return Color(
			0.9 + 0.1 * t,	   # R: 0.9 → 1.0
			0.2 + 0.3 * t,	   # G: 0.2 → 0.5
			0.05 + 0.05 * t,	 # B: 0.05 → 0.1
			i
		)
	elif F < FASE_3_MIN:
		# chama: laranja
		var t = (i - 0.35) / 0.55   # 0..1
		return Color(
			1.0,				 # R
			0.5 + 0.3 * t,	   # G: 0.5 → 0.8
			0.1 + 0.1 * t,	   # B: 0.1 → 0.2
			i
		)
	else:
		# intenso: amarelo claro
		var t = (i - 0.90) / 0.10   # 0..1
		return Color(
			1.0,				 # R
			0.8 + 0.2 * t,	   # G: 0.8 → 1.0
			0.2 + 0.4 * t,	   # B: 0.2 → 0.6
			i
		)
