# Jogo da Bruxa

<table>
<tr><td>Engine</td><td>Godot 4</td></tr>
<tr><td>Plataforma</td><td>Android</td></tr>
<tr><td>Resolução</td><td>640 × 960 px</td></tr>
<tr><td>Gênero</td><td>Point & Click</td></tr>
<tr><td>Estilo</td><td>2D Side-scroller</td></tr>
<tr><td>Gameplay</td><td>Exploração + Crafting</td></tr>
<tr><td>Idioma</td><td>Português</td></tr>
</table>

```
Floresta    -   BruxaOut    -   BruxaIn
Bosque
Bosque
CidadeA     -   in01    -   in02    -   in03
EstradaA
Ponte
Castelo     -   in
EstradaB
```

![1788646480585](image/readme/1788646480585.png)![1788646486876](image/readme/1788646486876.png)

## Coisas a fazer

```
  ==============================
||		LEGENDA:	||
||	[ ] A fazer		||
||	[.] Em progresso	||
||	[?] Conferir		||
||	[!] Finalizado		||
  ==============================
```

## Terminar logo (0)

```

[.] v3
[.] Sprite placeholder de:
[.]		Guarda1, foto
[.]		Guarda2, foto
[?]	balancear itens e preparo. 4 primeiros ingredientes oficiais: erva, cogumelo, flor-de-farra, musgo-do-recato. Baú dá 15 de cada.
		Erva + cogumelo (1ª receita): erva m5200 s2000/3000 Tmin50 k.3 Tmax135 k.15 (queima ~140+) t25–90 h.4; cogumelo m1200 s600/900 Tmin100 k.15 Tmax160 k.15 t5–25 h.4/.5. Fogo: K 0.3, CONST_A 30.
		Receita ideal (~60 s): acende → erva com água morna (~8 s) → cozinha até ~40 s → ~1 clique/s até chama BRANCA (~120 °C) → cogumelo (~48–50 s) → frita ~10 s → termina. Perfeito → Poção da Calma Profunda (só N cai, 0,93).
		2ª receita (E): Flor-de-farra (E +20%, mas C −5%, A −6% e N +5% de E) em INFUSÃO 75–95 °C (ferver estraga), m2400 (~30 s a 85 °C), t 20–70 s.
		  Musgo-do-recato (compensa C, A e N) entra POR ÚLTIMO: sem cozimento, t 2–12 s. → Poção da Desenvoltura: só E +20%.
[ ]	Renomear direito. 
		  Ícones item_a (flor) / item_b (musgo). Coleta: castelo_out — flor 2 áreas (1 cada, cooldown 50 s), musgo 2 (cooldown 15 s); musgo 1 à direita do guarda da ponte e 1 à esquerda do guarda da estradaB (15 s). Ajustar posições/altura no editor.


[.] Caldeirão/Preparo:
[?]		Abafar usa CONST_C = 20 por passo de 0,3 s (CONST_A só para o clique). Calibrar CONST_C.
[.]		Quase apagando (F < F_LIMIT_MIN + 80): fumaça contínua saindo da lenha e a bruxa avisa ("O fogo tá morrendo!").Quando o fogo inicia dá aviso de perto do F_LIMIT_MIN, mas quando acaba de iniciar não faz sentido avisar isso.

[ ] Cena de poção preparada:
[.]		Layout: Definir localização das janelas e informações. Tentar fazer em 2 colunas, a poção, pentagram e matriz de um lado, do outro lado a lista de ingredientes.
[?]			revisar como mostrar os valores fora das diagonais.  (toque na célula da grade: balão "C → N −3%")
[.]			Anotar o tempo e temperatura no momento que cada item entrou nos itens. quero não só número, mas uma representação visual útil.
[?]			Gostei do grafico. Mas a receita começa quando o primeiro ingrediente entra. (gráfico vai da entrada do 1º ingrediente ao fim; tempos contados a partir dela)
[!]			Uma curva só T(t), grande: ela se desenha e fica em foco (o resto apagadinho); depois a área (∫T dt) de cada ingrediente sai de trás dela, um por um, e desce até a linha dele.
[.]		Nomear as poções de referência no catálogo (PocaoReferencia: nome, descrição, A)
[?]			As poções nomeadas não devem ficar salvas no user, e sim salvas no GameTemp, valem só para aquela secção. (GameTemp.pocoes_nomeadas)


[ ] História / missão: (em ordem)
[!]		Camponês bate na porta (TOC! TOC! TOC!), opção Deixar entrar / Ignorar. Ele pede ajuda para a irmã que vai casar → Poção da Calma Profunda. Guardas ainda não deixam passar.
[.]			Corrigir fala: "E uma folha que posso , onde as árvores acabam." (bruxa_in_auto / bruxa_in_passagem). ("depoisé" já corrigido)
[]		AreaSpawn (src/cena/area_spawn.gd): no máximo N cópias de um EventoData numa faixa; posições e cooldowns salvos no GameTemp (voltar ao mapa = mesmas posições); coletou 1 (self A = 1) → após o cooldown (s) renasce num ponto qualquer da faixa (de preferência longe de onde foi coletado), com efeito de brilho. 
[.]			A bruxa diz quais & qtos itens tem que pegar e libera controle na primeira missão.
[.]			Guardas (clique): "Trouxe a poção?" Sim + missao01_pocao_feita = 1 → missao01_passou_guarda = 1 → os dois guardas deixam passar e mudam a fala. Trouxe a poção é muito direto, quero mais diálogo.
[?]			finalização, entrega poção e resultados possíveis.
					castelo_in: Rei, Princesa (sprites provisórios: animacoes/rei.tres e princesa.tres) e CenaRei (automático).
					1ª vez que entra (castelo_conversou = 0): cena automática (castelo_in_auto), a bruxa anda até x 700 (o diálogo só começa quando ela chega), diálogo; poção vai funcionar? sim / talvez / não (desculpa).
					Todos os caminhos terminam no label "end": castelo_conversou = 1 e destrava a bruxa. Página 2 do castelo_in_auto (castelo_conversou == 1, vazia) impede o loop.
					Pausas curtas (CmdEsperar 0,3–1 s) depois do movimento, entre blocos de diálogo e depois do efeito da poção.
					Depois: anda livre no castelo; clicar no rei ou na princesa → o rei fala e volta a tentativa.
					Sim/talvez → aplicar na princesa? aceitar → abre o inventário, toca no item → "Aplicar poção" (CmdAplicarPocao: personalidade = A · p, item sai, efeito mágico). "Desistir" ou recusar → pode voltar depois.
					Princesa (dados/personalidades/princesa.tres): O5 C5 E4 A6 N8.
					missao1_resultado: 0 não entregou · 1 bom (N < 4 e outros traços mudaram ≤ 2) · 2 calma, mas mudou outros traços > 2 · 3 pouco efeito (4 ≤ N ≤ 8) · 4 piorou (N > 8).
					CmdMedirMudanca guarda em missao01_desvio a maior mudança em O, C, E, A.
[ ]				Balancear depois: Calma Profunda (talvez ~4 cogumelos + 4 ervas) para baixar bem o N numa poção só; rever o critério N < 4 (8 → 4 é muito).
[ ]				Reações diferentes da princesa/rei para cada resultado (hoje só "Eu... me sinto diferente." e "Veremos no casamento.").
[ ]				Ajustar no editor: posição do Rei, Princesa e o X onde a bruxa para (Rei x 848, Princesa x 1008, bruxa para em x 700). Sprites finais do rei e da princesa.
```

## Terminar até o Cap. 1 (1)

```

[ ] Bugs/Revisão:
[?]		CmdMoverPlayer liberava o evento antes do movimento começar (diálogo aparecia com a bruxa andando). Agora espera começar (até 0,5 s) e depois terminar.
[?]		Camera trava quando chega num canto de tela mas o parallax não deve travar, senão dá uma sensação ruim de impacto quando chega perto de um canto de tela.
			Feito: camera_2d.gd lê limit_left/right e usa borda suave (BORDA_SUAVE 200 px, aproximação exponencial). Vale para todos os mapas.
			CamadaParallax (src/cena/camada_parallax.gd, Parallax2D): textura, fator (0 céu parado, 1 mapa, >1 frente), loop_x, pan (px/s), deslocamento. Ponte: nuvens (Fundo3) convertidas. Converter as outras camadas/mapas aos poucos.
[?]		Página com várias condições (todas precisam valer): variável, item, personalidade, posição, direção
[?]		Página reavalia ao ganhar/perder item e ao mudar personalidade
[?]		Notificação de item nunca aparece (NotificacaoItem sem Label em main.tscn)
			Label já existe; agora o painel começa escondido e uma notificação nova não é mais apagada pelo timer da anterior.
[?]		Segurar o botão de poção para sair agora é 0,7 s (TEMPO_LONGO)
[ ]		Tutorial do caldeirão na 1ª vez.
[ ]		Um card depois do outro se ativer os 2. (primeiro inventário depois status). se ativar só um, só aparece ele.
[ ]		Fazer faces tbm terem seu .tres

[ ]	Escrita/Estilo:
[ ]		Diálogos devem condizer com a época
[ ]		Cada personagem tem seu linguajar próprio e manias.

[ ]	Cena Livro de Receitas: (DEPOIS DO CAP. 1)
[ ]		Ao criar uma poção nova a bruxa tem opção de anotar a receita no livro. Caso escolha anotar: Abre a cena do livro de receitas já anotando.
[ ]		Iniciar o livro de receitas, cena com janela que inicia após uma nova receita. A cena de livro abre e é escrita uma nova receita.
[ ]		Pensar no Layout
[ ]		Uma receita por página, 2 páginas por folha, mostra o livro aberto e tem opção de controlar com clique ou arrastando, é redundante para melhor UX.
[ ]		Ao clicar numa página mostra seus ingredientes e tempo relacionado com seu gráfico, seu resultado.
[ ]		Fazer tudo bem animado e temático de bruxaria.


[.] Itens:
[?]		Matriz A aceita poucas casas decimais no Inspector, ainda está arredondando para 2 casas. quero no mínimo 5. Por enquanto tenho que editar diretamente o .tras
				Passo do Inspector agora é 0.00001 (item_data.gd). Conferir no editor.


[ ] Intro: (Cap. 1)
[ ]		Melhorar texto: reduzir? etc...
[ ]		Melhorar representação do texto subindo.

[.] Interprete:
[?]	    comando if para verificar, além de variaveis; itens ou personalidade (GameTemp)
				Feito: Condicao.tipo = variável, item, personalidade, posição X/Y da bruxa, direção da bruxa (vale p/ if, while e páginas)
[?]     comando mudar direção player (CmdDirecaoPlayer: esq, dir, inverter, para evento)
[?]	    comando mover player (CmdMoverPlayer: para X, para evento, deslocar; esperar; direção final)
[?]     comando deixar evento passavel ou ativar/desativar colisão do player (CmdEventoPassavel)
[?]			colisão do player: CmdPlayerPassavel
[?]     comando mudar direção evento (CmdDirecaoEvento: centro, esq, dir, inverter, para o player; diferente de trocar animação)



[ ]	Caldeirão:
[x]		Ajustes mínimos: cor, shake, efeitos, aparar para a versão final. (vapor acima de 100 °C, baforada de fumaça ao abafar)
[?]		Labaredas (faíscas laranja subindo) ao abanar o fogo.
[ ]		Tutorial(leve) na primeira vez. (DEPOIS DO CAP. 1)

[ ] Mapa:
[?]	Só 1 cogumelo no bosque a cada 10seg. na estradaA tem 5 cogumelos com delay de 2seg.
[?]     Spawn de itens: existem as áreas de spawn, que invocam um tipo de evento, limitados por qtd de invocações no mapa.  
[.]         Remover todos eventos placeholders de item dos mapas
				Removidos os 6 cogumelos de teste (teste_magia) de bruxa_out e castelo_out. Fica só o da história (estradaA). teste_magia.tres sem uso.
[?]         Adicionar o floresta_erva oficial (AreaErva na floresta)
[?]         Adicionar o bosque_cogumelo oficial (AreaCogumelo no bosque, x≈1000–1700, y=580: ajustar no editor)
[.]     Resolver problema de área de colisão, verificar cada evento, posição, etc.
[?]		Quando chego perto de uma borda o paralax age parando bruscamente, quero que ele não fique limitado à tela, talvez tenho que mudar o tamanho dos cenários? (câmera com borda suave; CamadaParallax na ponte)
[.]		Padronizar parallaxes em cada mapa: ...,Fundo2,Fundo,Meio,Frente,Frente2... (meio é onde ficam os eventos também)
[?]		Testar loop de bgm, loop de bgs. (floresta.mp3 já está com loop=true no import)
[?]		cada mapa tocando BGM da fase em loop. (verificar mapa_base)
			Feito: mapa_base tem bgm/bgm_volume no Inspector. Mesmo bgm = continua; outro = troca; vazio = para. Só a floresta tem bgm (floresta.mp3).
[ ]		SE nos teleport (depois: som de passos na transição)
[?]		Tela preta das passagens mais curta: "esperar" depois do teleporte baixado de 0.4 para 0.2
[ ]	Verificar todos os parallaxes (valores, direção, bordas).

[.]	HUD/inventário:
		Feito (1ª versão): src/ui/carta.gd + hud.tscn refeito. Duas cartas: CartaInventario (Verso/Inventario/Dialogo) e CartaStatus (Verso/Status/Opcoes).
		Toque no verso abre; 4 s sem tocar na carta (nem popup do item aberto) desvira. Independentes. Fechada ocupa o mesmo espaço.
		Diálogo/opções: DialogBox e OptionBox vão para dentro das cartas (face de prioridade); a carta vira sozinha e volta para onde estava.
		mostrar_hud/sumir_hud: ativa/desativa as cartas (inativas somem, mas aparecem no diálogo).
		Virada na diagonal (angulo_diagonal 45°), sem pulinho. Conteúdo vai para um Node2D "Giro" no _ready: use carta.face("Nome").
		Margem só no conteúdo (MARGEM_CONTEUDO = 20, hud.gd); botões de opção ocupam a carta toda e são pretos.
		Foto e nome do falante ficam fora da carta (CanvasLayer): não giram, fade só quando mudam.
		Ajustar: tempo_aberta, tempo_virar, angulo_diagonal (Inspector da carta).
		Verso provisório: pentagrama desenhado (src/ui/pentagrama_verso.gd, gira devagar; cor/espessura/raio/giro no Inspector). Trocar pela arte quando existir.
[?]     Separar o Inventário do HUD. O HUD deve fazer o esquema de carta que vira ao clicar em um de seus componentes (inventário ou status), pensar como vai ser a dinâmica da carta girando, ativação, desativação, etc. Um clique em cima para mostrar, e se ficar alguns segundos sem interação ele desvira.
[?]		Animar o inventário e o status como um card que gira/abre ou algo assim. 
[?]		Fazer uma animação de carta virando para os diálogos, opções, inventário e status. 
[?]		Diminuir o botão de avançar diálogo em todas as laterais, pouca coisa.
[?]		Mostrar o pentagrama por cima dos Cards, talvez é problema de zindex.
[?]		No diálogo a tela deve escurecer um pouco mais.
[?]		No avançar diálogo o cursor triangular deve ficar com movimento y=sin((2pi/L)*x)



[ ]	Arte Visual
[?]     como fazer imagem ficar fazendo pan infinito? usar nas núvens
			Feito: src/cena/nuvens_movendo.gd num TextureRect em modo Tile (velocidade px/s). Aplicado nas nuvens da ponte (Fundo3).
[ ]     Fazer sprite:
[ ]         mapa floresta de 6000px (talvez diminua), com paralax, provisório.
[ ]         inventário e status de costas (card que gira)


[ ] Audio:
[ ]     Fazer músicas: 
[ ]         intro, 
[ ]         casa bruxa, 
[?]         floresta, 
[ ]         estradas, 
[ ]			ponte (ouvir ost: ragnarok, pokemon, nobuo uematsu)
[ ]         castelo, 
[ ]         ...
[ ]	Fazer sons:
[ ]		Teleport entre mapas
[ ]		Flip card
[ ]		Efeitos (...)

[ ]	Animações:
[ ]


[ ] Estilo:
[ ] 	organizar o layout e textura dialogo/opções
[ ]		Ajuste estético, borda, cor, fonte, etc.
[ ]		Criação de estilos padronizados para cada coisa. (?) tipo estilo texto, estilo menu, ...?
[ ]


[ ]	Estudar se vale:
[ ]		- Definir posição dos eventos no mapa, tudo por código


[ ]	Status: ()
[?]		popup do nome da característica quando hover ou click. ou algo legal. (status.gd: toque no ícone → balão com nome e valor por 1,5 s)
[?]		Animação de aparição. (como se virasse uma carta, etc)  (o status já vira como carta)


[ ]	Menu Principal e Pausa (DEPOIS DO CAP. 1)
[ ]	Save/Load (DEPOIS: muita coisa ainda pode mudar)
[ ]		Game_Temp deve ter save e load de arquivo_unico de titulo "save"+time_stamp
[ ]		GameTemp, posição player, mapa
[?]	Animações do player e eventos melhor organizada e testes.

[ ]	Core:
[ ]		Modularizar evento_base (ainda precisa?)
[ ]   Melhorias estruturais no sistema.
```

## Terminar até o Cap. 2 (2)

```
[ ] Sistema de clima
[ ]	Sistema de mercado/valor dinâmico
[ ]	Sistema de fama
[ ]	Sistema de compra/venda
```
