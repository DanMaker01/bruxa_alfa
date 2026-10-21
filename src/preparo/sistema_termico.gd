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

## Troca de calor fogo↔caldo. Menor = o fogo perde calor mais devagar depois de atiçado
## (e também esquenta mais devagar). A relação fogo→temperatura de equilíbrio não muda.
const K: float = 0.3
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
## Pulso de fogo (clique curto no botão F). Com K = 0,3: ~1 clique/s segura T perto de 120 °C.
const CONST_A: float = 30.0
const CONST_B: float = 10.0	# queda de T quando um ingrediente entra
## Segurando o botão de fogo (aceso): tira CONST_C de F a cada 0,3 s ("abafar").
## Se F ficar abaixo disto ao abafar, o fogo apaga.
## Medido (K 0,3): segurando sem parar, F cairia até ~320 (caldo ~50 °C); com o limite
## em 450 o fogo apaga antes disso. Soltando, F volta sozinho para F_EQ (800).
const F_LIMIT_MIN: float = 450.0   # caldo ~64 °C: dá para infusão baixa (flor-de-farra ~75–95 °C)
## Quanto cada passo de abafar (segurando o botão, a cada 0,3 s) tira de F. Menor = controle mais fino.
const CONST_C: float = 20.0

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
# Abafar (segurando o botão com o fogo aceso) → −CONST_C em F.
# Devolve true se o fogo ficou fraco demais (F < F_LIMIT_MIN) e apagou.
func abafar_fogo() -> bool:
	if not fogo_ligado:
		return false
	F = maxf(F - CONST_C, T_AMB)
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
## Cor da chama = termômetro. Cada faixa de F tem uma cor bem distinta, ligada à
## temperatura que o caldo atinge com esse fogo (T de equilíbrio ≈ (F + 175) / 9,75):
##   vermelho escuro  brasa              (caldo frio)
##   laranja          F 800   → caldo ~100 °C (fervura)
##   amarelo          F 900   → ~110 °C
##   branco           F 1000  → ~120 °C (ponto de fritar o cogumelo)
##   branco-azulado   F 1100  → ~130 °C (limite da erva)
##   azul             F 1180+ → ~140 °C (queimando a erva)
## Dentro de cada faixa a cor "segura" no meio e troca rápido perto da próxima,
## para dar para ler a faixa sem números.
const CORES_FOGO := [
	[70.0, Color(0.55, 0.08, 0.04)],
	[600.0, Color(1.0, 0.22, 0.06)],
	[800.0, Color(1.0, 0.55, 0.12)],
	[900.0, Color(1.0, 0.88, 0.2)],
	[1000.0, Color(1.0, 1.0, 0.85)],
	[1100.0, Color(0.72, 0.92, 1.0)],
	[1180.0, Color(0.3, 0.5, 1.0)],
]

func get_cor_fogo() -> Color:
	var i = get_intensidade_fogo()
	if i <= 0.0:
		return Color(1.0, 0.4, 0.1, 0.0)
	var cor: Color = CORES_FOGO[-1][1]
	if F <= CORES_FOGO[0][0]:
		cor = CORES_FOGO[0][1]
	else:
		for k in range(CORES_FOGO.size() - 1):
			var f0: float = CORES_FOGO[k][0]
			var f1: float = CORES_FOGO[k + 1][0]
			if F < f1:
				var t: float = clampf((F - f0) / (f1 - f0), 0.0, 1.0)
				t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)   # smootherstep: faixas mais marcadas
				cor = CORES_FOGO[k][1].lerp(CORES_FOGO[k + 1][1], t)
				break
	cor.a = i
	return cor
