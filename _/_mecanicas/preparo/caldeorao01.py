"""
Simulador: Fogo + Caldeirão + Ingredientes
Modelo linear acoplado com eventos discretos de adição de ingrediente.

Controles:
  ESPAÇO  -> adicionar ingrediente frio
  F       -> ligar/desligar fogo
  R       -> resetar
  ESC     -> sair
"""

import pygame
import sys
from collections import deque

# ============================================================
# 1. MODELO FÍSICO
# ============================================================
class Modelo:
    """Modelo termodinâmico do fogo + caldeirão.

    Estado: T (caldeirão), F (fogo), C (capacidade térmica total).
    EDOs lineares acopladas + eventos discretos (adição de ingrediente).
    """

    def __init__(self):
        # Parâmetros físicos (ajuste à vontade)
        self.C_F = 5000.0        # J/K  - inércia térmica do fogo
        self.k = 20.0            # W/K  - acoplamento fogo <-> caldeirão
        self.h = 3.0             # W/K  - perda caldeirão -> ambiente
        self.hF = 10.0           # W/K  - perda fogo -> ambiente
        self.T_inf = 293.0       # K    - temperatura ambiente
        self.P_comb = 3000.0     # W    - potência de combustão

        # Parâmetros dos ingredientes
        self.m_ing = 1.0         # kg   - massa por adição
        self.c_ing = 3500.0      # J/kg·K
        self.T_ing = 278.0       # K    - 5 °C

        self.reset()

    def reset(self):
        self.T = 293.0           # K
        self.F = 293.0           # K
        self.C = 2000.0          # J/K (panela + conteúdo inicial)
        self.t = 0.0
        self.fogo_ligado = True

    # ---------- derivadas ----------
    def derivadas(self):
        P = self.P_comb if self.fogo_ligado else 0.0
        dT = (self.k * (self.F - self.T) - self.h * (self.T - self.T_inf)) / self.C
        dF = (P - self.k * (self.F - self.T) - self.hF * (self.F - self.T_inf)) / self.C_F
        return dT, dF

    # ---------- integração (Euler explícito; simples e estável p/ dt pequeno) ----------
    def passo(self, dt):
        dT, dF = self.derivadas()
        self.T += dT * dt
        self.F += dF * dt
        self.t += dt

    # ---------- evento: adicionar ingrediente ----------
    def adicionar_ingrediente(self):
        C_novo = self.C + self.m_ing * self.c_ing
        T_novo = (self.C * self.T + self.m_ing * self.c_ing * self.T_ing) / C_novo
        self.C = C_novo
        self.T = T_novo
        # F não muda instantaneamente

    # ---------- diagnóstico ----------
    def tau(self):
        return self.C / (self.k + self.h)

    def T_equilibrio(self):
        """T* do sistema linear (fogo ligado)."""
        if not self.fogo_ligado:
            return self.T_inf
        num = self.k * self.P_comb + (self.k * self.hF + self.h * (self.k + self.hF)) * self.T_inf
        den = (self.k + self.h) * (self.k + self.hF) - self.k ** 2
        return num / den


# ============================================================
# 2. VISUALIZAÇÃO
# ============================================================
class Visual:
    LARGURA, ALTURA = 1000, 650
    COR_FUNDO = (18, 18, 22)
    COR_FOGO = (255, 120, 40)
    COR_CALDEIRAO = (80, 180, 255)
    COR_TEXTO = (230, 230, 230)
    COR_GRADE = (50, 50, 60)
    COR_BOTAO = (60, 60, 75)
    COR_BOTAO_HOVER = (90, 90, 110)

    # área do gráfico
    GX, GY, GW, GH = 60, 60, 880, 380

    # faixa de temperatura exibida (°C)
    T_MIN, T_MAX = 0, 250

    def __init__(self):
        pygame.init()
        self.tela = pygame.display.set_mode((self.LARGURA, self.ALTURA))
        pygame.display.set_caption("Fogo + Caldeirão + Ingredientes")
        self.relogio = pygame.time.Clock()
        self.fonte = pygame.font.SysFont("consolas", 16)
        self.fonte_g = pygame.font.SysFont("consolas", 20, bold=True)

        # histórico para o gráfico
        self.hist_T = deque(maxlen=2000)
        self.hist_F = deque(maxlen=2000)
        self.dt_hist = 0.25  # s por amostra no gráfico

        # botões
        self.botoes = {
            "add":   pygame.Rect(60,  470, 220, 45),
            "fogo":  pygame.Rect(300, 470, 220, 45),
            "reset": pygame.Rect(540, 470, 220, 45),
        }

    # ---------- conversões ----------
    def temp_para_y(self, T_K):
        T_C = T_K - 273.15
        frac = (T_C - self.T_MIN) / (self.T_MAX - self.T_MIN)
        frac = max(0.0, min(1.0, frac))
        return self.GY + self.GH - frac * self.GH

    def idx_para_x(self, i, n):
        if n <= 1:
            return self.GX
        return self.GX + int(i / (n - 1) * self.GW)

    # ---------- desenho ----------
    def desenhar(self, modelo):
        self.tela.fill(self.COR_FUNDO)
        self._desenhar_grade()
        self._desenhar_curvas()
        self._desenhar_textos(modelo)
        self._desenhar_botoes(modelo)
        pygame.display.flip()

    def _desenhar_grade(self):
        # moldura
        pygame.draw.rect(self.tela, self.COR_GRADE,
                         (self.GX, self.GY, self.GW, self.GH), 2)
        # linhas horizontais a cada 50 °C
        for T_C in range(self.T_MIN, self.T_MAX + 1, 50):
            y = self.temp_para_y(T_C + 273.15)
            pygame.draw.line(self.tela, self.COR_GRADE,
                             (self.GX, y), (self.GX + self.GW, y), 1)
            txt = self.fonte.render(f"{T_C}°C", True, self.COR_TEXTO)
            self.tela.blit(txt, (self.GX - 50, y - 8))

    def _desenhar_curvas(self):
        n = len(self.hist_T)
        if n < 2:
            return
        pts_T = [(self.idx_para_x(i, n), self.temp_para_y(self.hist_T[i]))
                 for i in range(n)]
        pts_F = [(self.idx_para_x(i, n), self.temp_para_y(self.hist_F[i]))
                 for i in range(n)]
        pygame.draw.lines(self.tela, self.COR_CALDEIRAO, False, pts_T, 2)
        pygame.draw.lines(self.tela, self.COR_FOGO, False, pts_F, 2)

    def _desenhar_textos(self, m):
        linhas = [
            f"t = {m.t:6.1f} s",
            f"T caldeirão = {m.T - 273.15:6.1f} °C",
            f"F fogo      = {m.F - 273.15:6.1f} °C",
            f"C total     = {m.C:8.0f} J/K",
            f"tau         = {m.tau():6.1f} s",
            f"T* equilíb. = {m.T_equilibrio() - 273.15:6.1f} °C",
            f"Fogo: {'LIGADO' if m.fogo_ligado else 'DESLIGADO'}",
        ]
        for i, txt in enumerate(linhas):
            s = self.fonte.render(txt, True, self.COR_TEXTO)
            self.tela.blit(s, (60, 20 + i * 22))

        # legenda das cores
        pygame.draw.line(self.tela, self.COR_FOGO, (700, 30), (730, 30), 3)
        self.tela.blit(self.fonte.render("Fogo", True, self.COR_TEXTO), (740, 22))
        pygame.draw.line(self.tela, self.COR_CALDEIRAO, (700, 55), (730, 55), 3)
        self.tela.blit(self.fonte.render("Caldeirão", True, self.COR_TEXTO), (740, 47))

    def _desenhar_botoes(self, m):
        mouse = pygame.mouse.get_pos()
        rotulos = {
            "add":   "Adicionar ingrediente [ESPAÇO]",
            "fogo":  ("Desligar fogo [F]" if m.fogo_ligado else "Ligar fogo [F]"),
            "reset": "Resetar [R]",
        }
        for chave, rect in self.botoes.items():
            hover = rect.collidepoint(mouse)
            cor = self.COR_BOTAO_HOVER if hover else self.COR_BOTAO
            pygame.draw.rect(self.tela, cor, rect, border_radius=8)
            pygame.draw.rect(self.tela, self.COR_GRADE, rect, 2, border_radius=8)
            s = self.fonte.render(rotulos[chave], True, self.COR_TEXTO)
            self.tela.blit(s, s.get_rect(center=rect.center))

    # ---------- detecção de clique ----------
    def clique(self, pos):
        for chave, rect in self.botoes.items():
            if rect.collidepoint(pos):
                return chave
        return None


# ============================================================
# 3. LOOP PRINCIPAL
# ============================================================
def main():
    modelo = Modelo()
    vis = Visual()

    dt = 0.05              # passo de integração (s)
    acumulador_hist = 0.0

    rodando = True
    while rodando:
        # ----- eventos -----
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
                elif ev.key == pygame.K_r:
                    modelo.reset()
                    vis.hist_T.clear()
                    vis.hist_F.clear()
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                chave = vis.clique(ev.pos)
                if chave == "add":
                    modelo.adicionar_ingrediente()
                elif chave == "fogo":
                    modelo.fogo_ligado = not modelo.fogo_ligado
                elif chave == "reset":
                    modelo.reset()
                    vis.hist_T.clear()
                    vis.hist_F.clear()

        # ----- física -----
        modelo.passo(dt)

        # ----- histórico para o gráfico -----
        acumulador_hist += dt
        if acumulador_hist >= vis.dt_hist:
            vis.hist_T.append(modelo.T)
            vis.hist_F.append(modelo.F)
            acumulador_hist = 0.0

        # ----- desenho -----
        vis.desenhar(modelo)
        vis.relogio.tick(60)

    pygame.quit()
    sys.exit()


if __name__ == "__main__":
    main()