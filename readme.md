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
||	[?] Testar		||
||	[!] Finalizado		||
  ==============================
```

## Terminar logo (0)

```

[.] v3
[] 2ª receita:  - desenvoltura
	balanceat tempo, u,s-,s+, Tmin,Tmax,tmin,tmax, etc de cada item. infusao
[] mapa:
	[] bruxa_out, mais camadas (v3)
	[] ponte, nuvens e parallax (v3)
[.]	Database: Nomear as poções de referência no catálogo (PocaoReferencia: nome, descrição, A). Poção da Calma Profunda. Poção #2. Poções proíbidas. 
		Poção #2 = Poção da Desenvoltura (definir bem antes do Cap. 1; só usada no Cap. X).
		Poções proibidas: as que têm algum autovalor 0 (2^5 − 1 = 31 combinações de traços zerados). Ainda sem nome. (feito: 31 no catálogo como "Poção Proibida (sem O, C...)", nomes provisórios)
		Poção de Pó de Retorno Concentrada no catálogo, com efeito (teleporte para bruxa_in). Pó: diag(0.97,1,1,1,1.03), cozimento leniente (m 3000, T 60–170, t 10–150, folgas 0,4/0,6).
		Nome: poção de um item só agora usa "Poção de [item] [qualidade]" antes de procurar no catálogo (senão um pó mal cozido virava "Concentrada").

[ ] História / missão: (em ordem)
	[ ]	missao1_resultado hoje: 
			1 N −2 e nenhum outro ±2 · 
			2 N −2 mas outro traço ±2 · 
			3 pouco efeito · 
			4 N subiu · 
			5 estereotipada (algum traço extremo). 
			Rascunho das reações feito (castelo_in_auto): uma fala da princesa e do rei para cada resultado 1–5, e o rei e a princesa têm uma fala própria por resultado depois da entrega. Revisar o texto. Essa fala própria é um if nos comandos? vou fazer uma reação para cada um dos resulados.
			1 bom: princesa "já me sinto mais calma"; o rei aceita a contragosto e começa a resmungar; a princesa interrompe, agradece, já pensa no vestido e convida a bruxa para o casamento; o rei aceita (missao01_convite = 1).
			5 estereotipada: a princesa repete "Casamento. Vestido." e o drama cresce; o rei manda prender a bruxa, ela pede desculpas, não adianta; ela foge por outros cômodos do castelo, chega ao véu, pega um pedaço (missao01_veu = 1) e usa um item de volta para casa (não é o véu que teleporta). Os guardas entram e não tem ninguém. Ela aparece em bruxa_in.
				Mapas a criar: castelo_in03 (aberto, vista do pátio superior; o véu fica visível ali e dá para pegar um pedaço).
	[ ]	Roteiro: antes dessa cena, mostrar que a bruxa  tem um item que leva de volta para casa. Senão fica do nada. No contexto inicial da primeira cena ela já vai falar, quando tiver arrumando o inventário. 
		(você: evento de início em bruxa_in, ela olha o inventário e comenta da poção de retorno)
			Decidido: Poção de Pó de Retorno Concentrada. O "Pó de Retorno" (dados/itens/po_retorno.tres) é ingrediente comum, sem efeito; bem cozido vira a poção concentrada, que leva para bruxa_in.
			Só o resultado 5 (fuga) cria problema. Nos outros casos o véu continua lá e você só pega no castelo_in03.
			Depois: com resultado 5, o rei manda prender se ela voltar ao castelo (só fala, ainda não prende de verdade).


```

## Terminar até o Cap. 1 (1)

```

[ ] BETA / DEMO:
[ ]		Caldeirão 100%
[ ]		Diálogos 100%
[ ]		Sprites 100%
[ ]		Audio 100%
[ ]		Menus 100%



[ ] Bugs/Revisão:
[?]		CmdMoverPlayer liberava o evento antes do movimento começar (diálogo aparecia com a bruxa andando). Agora espera começar (até 0,5 s) e depois terminar.
[?]		Camera trava quando chega num canto de tela mas o parallax não deve travar, senão dá uma sensação ruim de impacto quando chega perto de um canto de tela.
			Feito: camera_2d.gd lê limit_left/right e usa borda suave (BORDA_SUAVE 200 px, aproximação exponencial). Vale para todos os mapas.
			CamadaParallax (src/cena/camada_parallax.gd, Parallax2D): textura, fator (0 céu parado, 1 mapa, >1 frente), loop_x, pan (px/s), deslocamento. Ponte: nuvens (Fundo3) conicavertidas. Converter as outras camadas/mapas aos poucos.
[?]		Página com várias condições (todas precisam valer): variável, item, personalidade, posição, direção
[?]		Página reavalia ao ganhar/perder item e ao mudar personalidade
[?]		Notificação de item nunca aparece (NotificacaoItem sem Label em main.tscn)
			Label já existe; agora o painel começa escondido e uma notificação nova não é mais apagada pelo timer da anterior.
[?]		Segurar o botão de poção para sair agora é 0,7 s (TEMPO_LONGO)
[ ]		Tutorial do caldeirão na 1ª vez.
[ ]		Um card depois do outro se ativer os 2. (primeiro inventário depois status). se ativar só um, só aparece ele.
[ ]		Fazer faces tbm terem seu .tres
[?]		Dispersão/aglomeração do Spawn (AreaSpawn: distancia_min removida; "espalhamento" 0 = bem espalhados, 0,5 = aleatório, 1 = bem próximos. Sorteia 12 pontos e escolhe o mais longe/perto dos que já estão no mapa)
[ ]		Variações no flip card. (depois) Sorteadas: normal = 1 flip diagonal; variações no mesmo tempo: 5 flips com velocidade decrescente; flip mudando a dimensão horizontal, com 1 ou 5 flips.


[ ]	Representação de poções visual com matriz/grafo. (feito, versão simples: no pentágono cada ponta sai do traço que mais contribui e gira até a sua; diagonal = só escala com um pulo)
[ ]		Mostrar o pentagrama, cada aresta representa um componente. Pensei em relacionar as arestas com a_ij e criar um feedback útil visualmente.
[ ] 	Na hora da aplicar a poção, inventário, resultado do preparo, sempre mostra o pentagrama e a matriz.
[ ]		O pentagrama deve ter animações a depender da matriz. Por exemplo, matriz diagonal (ou próxima de diagonal a menos de ruído) só escala, então a animação do pentagram é escalar. Matriz que troca dois componentes deve trocar duas pontas do pentagrama suavemente, como uma permutação ou rotação.


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


[?] Intro: (Cap. 1)
[x]		Melhorar texto: reduzir? etc... (5 legendas curtas, CmdLegenda)
[x]		Melhorar representação do texto subindo. (intro_fundo sobe; toque pula a intro: CmdPularComToque)

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
