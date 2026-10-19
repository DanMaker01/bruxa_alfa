"""
Simulador: Fogo + Caldeirão + Ingredientes
Arquivo único, modular. Unidades em °C.

Controles:
  ESPAÇO   -> adicionar ingrediente frio
  F        -> ligar/desligar fogo
  A        -> abanar o fogo (F += dF_abanar instantâneo)
  S        -> esfriar o caldeirão (T -= dT_esfriar instantâneo)
  R        -> resetar
  ← →      -> selecionar parâmetro
  ↑ ↓      -> aumentar/diminuir parâmetro
  ESC      -> sair

Parâmetros livres (ajustáveis em tempo real):
  k          (acoplamento fogo->caldeirão, W/°C)
  hF         (perda fogo->ambiente, W/°C)
  m_ing      (massa do ingrediente, kg)
  T_ing      (temperatura do ingrediente, °C)
  dF_abanar  (salto instantâneo em F ao abanar, °C)
  dT_esfriar (salto instantâneo em T ao esfriar, °C)

Capacidades térmicas (c * m):
  C   = c_caldeirao * m_caldeirao
  C_F = c_fogo * m_fogo

Parâmetros derivados (mantêm T*=100 °C e F*=800 °C):
  h      = k * (F* - T*) / (T* - T_inf) = k * 700 / 80 = 8.75 * k
  P_comb = k*(F* - T*) + hF*(F* - T_inf) = 700*k + 780*hF

Fluxo fogo -> caldeirão:
  P(F, T) = k * (F - T)
"""

import pygame
import sys
from collections import deque


# ============================================================
# 1. PARÂMETROS
# ============================================================
class Parametros:
    # Alvos fixos (em °C)
    T_ALVO = 100.0          # °C
    F_ALVO = 800.0          # °C
    T_INF = 20.0            # °C (ambiente)

    def __init__(self):
        # capacidades térmicas como c*m
        self.c_caldeirao = 3500.0     # J/(kg·°C)
        self.m_caldeirao = 0.2143     # kg  → C ≈ 750 J/°C
        self.c_fogo = 1000.0          # J/(kg·°C)
        self.m_fogo = 0.1             # kg  → C_F = 100 J/°C
        self.c_ing = 3500.0           # J/(kg·°C)

        # parâmetros livres (ajustáveis em tempo real)
        self.valores = {
            "k":          40.0,     # W/°C
            "hF":         20.0,     # W/°C
            "m_ing":      0.2,      # kg
            "T_ing":      20.0,     # °C
            "dF_abanar":  100.0,    # °C (salto em F)
            "dT_esfriar": 30.0,     # °C (salto em T)
        }
        self.passos = {
            "k":          1.0,
            "hF":         1.0,
            "m_ing":      0.1,
            "T_ing":      2.0,
            "dF_abanar":  10.0,
            "dT_esfriar": 5.0,
        }
        self.limites = {
            "k":          (0.1, 200.0),
            "hF":         (0.0, 500.0),
            "m_ing":      (0.0, 500.0),
            "T_ing":      (-50.0, 100.0),
            "dF_abanar":  (0.0, 2000.0),
            "dT_esfriar": (0.0, 500.0),
        }

    def get(self, nome):
        return self.valores[nome]

    def ajustar(self, nome, sinal):
        lo, hi = self.limites[nome]
        v = self.valores[nome] + sinal * self.passos[nome]
        self.valores[nome] = max(lo, min(hi, v))

    def nomes(self):
        return list(self.valores.keys())

    # --- capacidades térmicas ---
    def C(self):
        return self.c_caldeirao * self.m_caldeirao

    def C_F(self):
        return self.c_fogo * self.m_fogo

    # --- parâmetros derivados ---
    def h(self):
        """h para garantir T* = 100 °C."""
        return self.valores["k"] * (self.F_ALVO - self.T_ALVO) / (self.T_ALVO - self.T_INF)

    def P_comb(self):
        """P_comb para garantir F* = 800 °C."""
        k = self.valores["k"]
        hF = self.valores["hF"]
        return k * (self.F_ALVO - self.T_ALVO) + hF * (self.F_ALVO - self.T_INF)

    # --- fluxo fogo -> caldeirão ---
    def p_fluxo(self, F, T):
        return self.valores["k"] * (F - T)


# ============================================================
# 2. MODELO FÍSICO
# ============================================================
class Modelo:
    def __init__(self, params):
        self.p = params
        self.reset()

    def reset(self):
        self.T = self.p.T_INF    # °C
        self.F = self.p.T_INF    # °C
        self.t = 0.0
        self.fogo_ligado = True

    def passo(self, dt):
        p = self.p
        P = p.P_comb() if self.fogo_ligado else 0.0
        h = p.h()
        hF = p.get("hF")
        C = p.C()
        C_F = p.C_F()

        P_flux = p.p_fluxo(self.F, self.T)

        dT = (P_flux - h * (self.T - p.T_INF)) / C
        dF = (P - P_flux - hF * (self.F - p.T_INF)) / C_F

        self.T += dT * dt
        self.F += dF * dt
        self.t += dt

    def adicionar_ingrediente(self):
        """Salto instantâneo em T por mistura térmica (sem mudar C do sistema)."""
        m = self.p.get("m_ing")
        T_ing = self.p.get("T_ing")
        c_ing = self.p.c_ing
        if m <= 0:
            return
        C = self.p.C()
        # energia do ingrediente entra, capacidade total NÃO muda (abstração)
        # ΔT = (c_ing * m * (T_ing - T)) / C
        self.T += (c_ing * m * (T_ing - self.T)) / C

    def abanar_fogo(self):
        """Salto instantâneo em F."""
        dF = self.p.get("dF_abanar")
        if dF <= 0:
            return
        self.F += dF

    def esfriar_caldeirao(self):
        """Salto instantâneo em T (para baixo)."""
        dT = self.p.get("dT_esfriar")
        if dT <= 0:
            return
        self.T -= dT

    def tau(self):
        k = self.p.get("k")
        h = self.p.h()
        hF = self.p.get("hF")
        k_acop = k * hF / (k + hF) if (k + hF) > 0 else 0.0
        return self.p.C() / (k_acop + h + 1e-9)

    def T_equilibrio(self):
        if not self.fogo_ligado:
            return self.p.T_INF
        return self.p.T_ALVO

    def F_equilibrio(self):
        if not self.fogo_ligado:
            return self.p.T_INF
        return self.p.F_ALVO


# ============================================================
# 3. VISUALIZAÇÃO
# ============================================================
class Visual:
    L, A = 1000, 780
    COR_FUNDO = (18, 18, 22)
    COR_FOGO = (255, 120, 40)
    COR_CALDEIRAO = (80, 180, 255)
    COR_TEXTO = (230, 230, 230)
    COR_DESTAQUE = (255, 230, 100)
    COR_DERIVADO = (140, 220, 140)
    COR_GRADE = (50, 50, 60)

    GX, GY, GW, GH = 70, 300, 870, 380
    T_MIN, T_MAX = 0, 2200

    def __init__(self):
        pygame.init()
        self.tela = pygame.display.set_mode((self.L, self.A))
        pygame.display.set_caption("Fogo + Caldeirão (pulsos como saltos)")
        self.relogio = pygame.time.Clock()
        self.f = pygame.font.SysFont("consolas", 15)
        self.fg = pygame.font.SysFont("consolas", 18, bold=True)
        self.hist_T = deque(maxlen=2000)
        self.hist_F = deque(maxlen=2000)
        self.dt_hist = 0.2

    def _y(self, T_C):
        frac = (T_C - self.T_MIN) / (self.T_MAX - self.T_MIN)
        frac = max(0.0, min(1.0, frac))
        return self.GY + self.GH - frac * self.GH

    def _x(self, i, n):
        if n <= 1:
            return self.GX
        return self.GX + int(i / (n - 1) * self.GW)

    def desenhar(self, m, params, sel):
        self.tela.fill(self.COR_FUNDO)
        self._painel_params(params, sel)
        self._grade()
        self._curvas()
        self._rodape(m)
        pygame.display.flip()

    def _grade(self):
        pygame.draw.rect(self.tela, self.COR_GRADE,
                         (self.GX, self.GY, self.GW, self.GH), 2)
        for T_C in range(self.T_MIN, self.T_MAX + 1, 100):
            y = self._y(T_C)
            pygame.draw.line(self.tela, self.COR_GRADE,
                             (self.GX, y), (self.GX + self.GW, y), 1)
            self.tela.blit(self.f.render(f"{T_C}°C", True, self.COR_TEXTO),
                           (self.GX - 55, y - 8))

    def _curvas(self):
        n = len(self.hist_T)
        if n < 2:
            return
        pygame.draw.lines(self.tela, self.COR_CALDEIRAO, False,
                          [(self._x(i, n), self._y(self.hist_T[i])) for i in range(n)], 2)
        pygame.draw.lines(self.tela, self.COR_FOGO, False,
                          [(self._x(i, n), self._y(self.hist_F[i])) for i in range(n)], 2)

    def _painel_params(self, p, sel):
        nomes = p.nomes()
        self.tela.blit(self.fg.render("Parâmetros (← → seleciona, ↑ ↓ ajusta)", True, self.COR_TEXTO), (20, 10))

        for i, nome in enumerate(nomes):
            col = i % 3
            lin = i // 3
            x = 20 + col * 325
            y = 40 + lin * 60
            destaque = (i == sel)
            cor = self.COR_DESTAQUE if destaque else self.COR_TEXTO
            if destaque:
                pygame.draw.rect(self.tela, (40, 40, 55), (x - 5, y - 3, 310, 50), border_radius=6)
            self.tela.blit(self.f.render(nome, True, cor), (x, y))
            self.tela.blit(self.f.render(f"{p.get(nome):.1f}", True, cor), (x, y + 20))

        y_der = 40 + 2 * 60
        self.tela.blit(self.f.render("derivados:", True, self.COR_DERIVADO), (20, y_der))
        self.tela.blit(self.f.render(f"h = {p.h():.2f} W/°C", True, self.COR_DERIVADO), (20 + 325, y_der))
        self.tela.blit(self.f.render(
            f"P_comb = {p.P_comb():.0f} W   |   alvos: T* = {p.T_ALVO:.1f} °C, F* = {p.F_ALVO:.1f} °C",
            True, self.COR_DERIVADO), (20 + 650, y_der))
        self.tela.blit(self.f.render(
            f"C = c·m = {p.C():.0f} J/°C   |   C_F = c_F·m_F = {p.C_F():.0f} J/°C",
            True, self.COR_DERIVADO), (20, y_der + 22))

    def _rodape(self, m):
        linhas = [
            f"t = {m.t:6.1f} s     |   T = {m.T:6.1f} °C   |   F = {m.F:6.1f} °C   |   P = {m.p.p_fluxo(m.F, m.T):7.0f} W",
            f"tau = {m.tau():5.2f} s   |   T* = {m.T_equilibrio():6.1f} °C   |   F* = {m.F_equilibrio():6.1f} °C   |   Fogo: {'ON' if m.fogo_ligado else 'OFF'}",
            "[ESPAÇO] ingrediente   [F] fogo   [A] abanar   [S] esfriar   [R] reset   [ESC] sair",
        ]
        for i, txt in enumerate(linhas):
            self.tela.blit(self.f.render(txt, True, self.COR_TEXTO), (20, 700 + i * 22))

        pygame.draw.line(self.tela, self.COR_FOGO, (700, 250), (730, 250), 3)
        self.tela.blit(self.f.render("Fogo", True, self.COR_TEXTO), (740, 242))
        pygame.draw.line(self.tela, self.COR_CALDEIRAO, (820, 250), (850, 250), 3)
        self.tela.blit(self.f.render("Caldeirão", True, self.COR_TEXTO), (860, 242))


# ============================================================
# 4. LOOP PRINCIPAL
# ============================================================
def main():
    params = Parametros()
    modelo = Modelo(params)
    vis = Visual()

    sel = 0
    dt_fixo = 1.0 / 60.0
    acum_hist = 0.0
    rodando = True

    while rodando:
        dt_real = vis.relogio.tick(60) / 1000.0
        dt_real = min(dt_real, 0.1)

        for ev in pygame.event.get():
            if ev.type == pygame.QUIT:
                rodando = False
            elif ev.type == pygame.KEYDOWN:
                if ev.key == pygame.K_ESCAPE:
                    rodando = False
                elif ev.key == pygame.K_SPACE:
                    modelo.adicionar_ingrediente()
                elif ev.key == pygame.K_f:
                    modelo.fogo_ligado = not modelo.fogo_ligado
                elif ev.key == pygame.K_a:
                    modelo.abanar_fogo()
                elif ev.key == pygame.K_s:
                    modelo.esfriar_caldeirao()
                elif ev.key == pygame.K_r:
                    modelo.reset()
                    vis.hist_T.clear()
                    vis.hist_F.clear()
                elif ev.key == pygame.K_LEFT:
                    sel = (sel - 1) % len(params.nomes())
                elif ev.key == pygame.K_RIGHT:
                    sel = (sel + 1) % len(params.nomes())
                elif ev.key == pygame.K_UP:
                    params.ajustar(params.nomes()[sel], +1)
                elif ev.key == pygame.K_DOWN:
                    params.ajustar(params.nomes()[sel], -1)

        n_sub = max(1, int(dt_real / dt_fixo))
        h = dt_real / n_sub
        for _ in range(n_sub):
            modelo.passo(h)

        acum_hist += dt_real
        if acum_hist >= vis.dt_hist:
            vis.hist_T.append(modelo.T)
            vis.hist_F.append(modelo.F)
            acum_hist = 0.0

        vis.desenhar(modelo, params, sel)

    pygame.quit()
    sys.exit()


if __name__ == "__main__":
    main()