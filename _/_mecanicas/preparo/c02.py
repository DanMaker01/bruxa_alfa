"""
Simulador: Fogo + Caldeirão + Ingredientes
Arquivo único, modular.

Controles:
  ESPAÇO   -> adicionar ingrediente frio
  F        -> ligar/desligar fogo
  A        -> atiçar o fogo (F += A_atiçar)
  R        -> resetar
  ← →      -> selecionar parâmetro
  ↑ ↓      -> aumentar/diminuir parâmetro
  ESC      -> sair

Parâmetros livres (ajustáveis em tempo real):
  k         (coeficiente linear do fluxo em ΔT pequeno)
  hF        (perda fogo->ambiente)
  dT0       (escala da desaceleração logarítmica)
  m_ing     (massa do ingrediente)
  T_ing     (temperatura do ingrediente)
  A_atiçar  (amplitude do salto ao atiçar)

Parâmetros derivados (mantêm T*=100 °C e F*=800 °C):
  h         = k * dT0 * ln(1 + ΔT*/dT0) / (T* - T_inf)
  P_comb    = h * (T* - T_inf) + hF * (F* - T_inf)

Fluxo fogo -> caldeirão:
  Q(F, T) = k * dT0 * sgn(ΔT) * ln(1 + |ΔT|/dT0),  ΔT = F - T

  - Linear em ΔT pequeno: Q ≈ k·ΔT
  - Estritamente crescente, sem cap
  - Cresce como k·dT0·ln(ΔT/dT0) para ΔT grande
"""

import pygame
import sys
import math
from collections import deque


# ============================================================
# 1. PARÂMETROS
# ============================================================
class Parametros:
    # Alvos fixos
    T_ALVO = 373.15         # K  (100 °C)
    F_ALVO = 1073.15        # K  (800 °C)

    def __init__(self):
        self.valores = {
            "k":        40.0,       # W/K
            "hF":       20.0,       # W/K
            "dT0":      300.0,      # K
            "m_ing":    0.2,        # kg
            "T_ing":    293.0,      # K
            "A_atiçar": 100.0,      # K
        }
        self.passos = {
            "k":        1.0,
            "hF":       1.0,
            "dT0":      10.0,
            "m_ing":    0.1,
            "T_ing":    2.0,
            "A_atiçar": 10.0,
        }
        self.limites = {
            "k":        (0.1, 200.0),
            "hF":       (0.0, 500.0),
            "dT0":      (1.0, 5000.0),
            "m_ing":    (0.0, 500.0),
            "T_ing":    (250.0, 373.0),
            "A_atiçar": (0.0, 2000.0),
        }
        self.C_F = 100.0
        self.T_inf = 293.0
        self.C_INICIAL = 750.0

    def get(self, nome):
        return self.valores[nome]

    def ajustar(self, nome, sinal):
        lo, hi = self.limites[nome]
        v = self.valores[nome] + sinal * self.passos[nome]
        self.valores[nome] = max(lo, min(hi, v))

    def nomes(self):
        return list(self.valores.keys())

    # --- parâmetros derivados ---
    def h(self):
        """h para garantir T* e F* no equilíbrio com fluxo log1p."""
        k = self.valores["k"]
        dT0 = self.valores["dT0"]
        dT_alvo = self.F_ALVO - self.T_ALVO
        Q_estrela = k * dT0 * math.log1p(dT_alvo / dT0)
        return Q_estrela / (self.T_ALVO - self.T_inf)

    def P_comb(self):
        """P_comb para garantir F* no equilíbrio."""
        return self.h() * (self.T_ALVO - self.T_inf) + self.valores["hF"] * (self.F_ALVO - self.T_inf)

    def q_fluxo(self, F, T):
        """Fluxo log1p (estritamente crescente, sem cap)."""
        k = self.valores["k"]
        dT0 = self.valores["dT0"]
        delta = F - T
        return k * dT0 * math.copysign(math.log1p(abs(delta) / dT0), delta)


# ============================================================
# 2. MODELO FÍSICO
# ============================================================
class Modelo:
    def __init__(self, params):
        self.p = params
        self.reset()

    def reset(self):
        self.T = 293.0
        self.F = 293.0
        self.C = self.p.C_INICIAL
        self.t = 0.0
        self.fogo_ligado = True

    def passo(self, dt):
        p = self.p
        P = p.P_comb() if self.fogo_ligado else 0.0
        h = p.h()
        hF = p.get("hF")

        Q = p.q_fluxo(self.F, self.T)

        dT = (Q - h * (self.T - p.T_inf)) / self.C
        dF = (P - Q - hF * (self.F - p.T_inf)) / p.C_F

        self.T += dT * dt
        self.F += dF * dt
        self.t += dt

    def adicionar_ingrediente(self):
        m = self.p.get("m_ing")
        T_ing = self.p.get("T_ing")
        c_ing = 3500.0
        if m <= 0:
            return
        C_novo = self.C + m * c_ing
        self.T = (self.C * self.T + m * c_ing * T_ing) / C_novo
        self.C = C_novo

    def aticar_fogo(self):
        A = self.p.get("A_atiçar")
        if A <= 0:
            return
        self.F += A

    def tau(self):
        """Constante de tempo do modo lento no ponto de operação."""
        # k efetivo (derivada do fluxo em ΔT) no ponto ΔT*
        k = self.p.get("k")
        dT0 = self.p.get("dT0")
        dT_alvo = self.p.F_ALVO - self.p.T_ALVO
        k_ef = k / (1 + dT_alvo / dT0)   # dQ/d(ΔT) = k / (1 + ΔT/dT0)
        h = self.p.h()
        hF = self.p.get("hF")
        k_acop = k_ef * hF / (k_ef + hF) if (k_ef + hF) > 0 else 0.0
        return self.C / (k_acop + h + 1e-9)

    def T_equilibrio(self):
        if not self.fogo_ligado:
            return self.p.T_inf
        return self.p.T_ALVO

    def F_equilibrio(self):
        if not self.fogo_ligado:
            return self.p.T_inf
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
    T_MIN, T_MAX = 0, 1000

    def __init__(self):
        pygame.init()
        self.tela = pygame.display.set_mode((self.L, self.A))
        pygame.display.set_caption("Fogo + Caldeirão (fluxo log)")
        self.relogio = pygame.time.Clock()
        self.f = pygame.font.SysFont("consolas", 15)
        self.fg = pygame.font.SysFont("consolas", 18, bold=True)
        self.hist_T = deque(maxlen=2000)
        self.hist_F = deque(maxlen=2000)
        self.dt_hist = 0.2

    def _y(self, T_K):
        frac = (T_K - 273.15 - self.T_MIN) / (self.T_MAX - self.T_MIN)
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
        for T_C in range(self.T_MIN, self.T_MAX + 1, 50):
            y = self._y(T_C + 273.15)
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
        self.tela.blit(self.f.render(f"h = {p.h():.2f} W/K", True, self.COR_DERIVADO), (20 + 325, y_der))
        self.tela.blit(self.f.render(
            f"P_comb = {p.P_comb():.0f} W   |   alvos: T* = {p.T_ALVO - 273.15:.1f} °C, F* = {p.F_ALVO - 273.15:.1f} °C",
            True, self.COR_DERIVADO), (20, y_der + 22))

    def _rodape(self, m):
        linhas = [
            f"t = {m.t:6.1f} s     |   T = {m.T - 273.15:6.1f} °C   |   F = {m.F - 273.15:6.1f} °C   |   Q = {m.p.q_fluxo(m.F, m.T):7.0f} W",
            f"C = {m.C:7.0f} J/K   |   tau = {m.tau():5.2f} s   |   T* = {m.T_equilibrio() - 273.15:6.1f} °C   |   F* = {m.F_equilibrio() - 273.15:6.1f} °C   |   Fogo: {'ON' if m.fogo_ligado else 'OFF'}",
            "[ESPAÇO] ingrediente   [F] fogo   [A] atiçar   [R] reset   [ESC] sair",
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
                    modelo.aticar_fogo()
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