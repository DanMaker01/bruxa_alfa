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

[ ] v3
[ ]		balancear itens e preparo. 4 primeiros ingredientes oficiais. erva, cogu, pena de urubu,olho de salamandra(ou outro) (pena e olho: DEPOIS)
			Erva + cogumelo (1ª receita): erva m5200 s2000/3000 Tmin50 k.3 Tmax135 k.15 (queima ~140+) t25–90 h.4; cogumelo m1200 s600/900 Tmin100 k.15 Tmax160 k.15 t5–25 h.4/.5. Fogo: K 0.3, CONST_A 30.
			Receita ideal (~60 s): acende → erva com água morna (~8 s) → cozinha até ~40 s → ~1 clique/s até chama BRANCA (~120 °C) → cogumelo (~48–50 s) → frita ~10 s → termina. Perfeito → Poção da Calma Profunda (só N cai, 0,93).
[.]		Ao interagir com eventos a bruxa deve virar para ele antes. (evento_base._virar_player_para_mim, clique/toque). E quando não quiser que vire?
[.]		Scroll do inventário é muito pequeno e difícil puxar, eu queria que fosse uma lista e com o touch eu pudesse clicar e arrastar para fazer rolar.
			Feito: ListaRolavel (src/ui/lista_rolavel.gd): arrastar rola com inércia, toque sem arrastar abre o item. Linhas de 56 px, fonte 22.
[ ]			Corrigir: Quando clico num item do inventário nada acontece.
[ ]			Implementar: Inventário deve indicar que dá pra subir ou descer quando houver itens ocultados.


[ ] Caldeirão:
[?]		Se segurar o botão de fogo quero que retire const_A a cada 0.3seg ao invés de desligar o fogo. Como não há como desligar mais o fogo, caso a temperatura do fogo fique abaixo de F_LIMIT_MIN ele faz um efeito e apaga.
			Feito: segurar com o fogo aceso abafa (−CONST_A a cada 0,3 s); F < F_LIMIT_MIN (600, em sistema_termico) → fumaça e apaga. Apagado: segurar 1 s acende.
			Calibrar: CONST_A, F_LIMIT_MIN, de resto ok.
			
[ ] Cena de poção preparada:
[.]		Layout: Definir localização das janelas e informações. 
[ ]			revisar como mostrar os valores fora das diagonais. 
[ ]			Revisar posições das informações.
[ ]			Mostrar qual foi o erro por ingrediente nos ingredientes da receita. 
[ ]			Anotar o tempo e temperatura no momento que cada item entrou nos itens. quero não só número, mas uma representação visual útil.
[.]		Nomear as poções de referência no catálogo (PocaoReferencia: nome, descrição, A)
[ ]			As poções nomeadas não devem ficar salvas no user, e sim salvas no GameTemp, valem só para aquela secção.
[ ]			Iniciar o livro de receitas

[ ] História / missão: (em ordem)
[ ]		Diálogos devem condizer com a época
[ ]		Cada personagem tem seu linguajar próprio e manias.
[?]		Camponês bate na porta (TOC! TOC! TOC!), opção Deixar entrar / Ignorar. Ele pede ajuda para a irmã que vai casar → Poção da Calma Lúcida. Guardas ainda não deixam passar.
[?]			Corrigir fala: "E uma folha que posso , onde as árvores acabam." (bruxa_in_auto / bruxa_in_passagem). ("depoisé" já corrigido)
					A Bruxa diz que o cogumelo cresce "onde a floresta acaba", mas ele está na estradaA.
					Feito: agora "E uma erva que posso pegar no fim da floresta." e "Um cogumelo que cresce na beira da estrada, depois da cidade."
[?]			fazer área de spawn de evento no fim da floresta, outro na estradaA. Fazer farm com qtd na tela. (3 cogu, 3 erva) 
					Hoje: 1 cogumelo (estradaA) + 1 erva (floresta), coleta única por variável. Fazer o spawn de eventos, nas páginas vai ter uma também uma nova condição de self-variable, valores 0 e 1; e no interprete quero um comando de ativar/desativar self-variable de um evento.
					Feito: self-variables A/B/C/D por nó de evento (GameTemp.self_vars). Condição tipo "self" (páginas, if, while). Comando CmdSelfVar (vazio = este evento).
					AreaSpawn (src/cena/area_spawn.gd): no máximo N cópias de um EventoData numa faixa; posições e cooldowns salvos no GameTemp (voltar ao mapa = mesmas posições); coletou 1 (self A = 1) → após o cooldown (s) renasce num ponto qualquer da faixa, com efeito de brilho. estradaA: AreaCogumelo (3x spawn_cogumelo), floresta: AreaErva (3x spawn_erva).
					Ajustar no editor: posição/largura das áreas. estradaA_cogumelo.tres e floresta_erva.tres ficaram sem uso (apagar).
[?]			A bruxa diz quais & qtos itens tem que pegar e libera controle na primeira missão.
[ ]			com ingredientes na mão, interagir com o caldeirão, ela explica como usar a 1ª vez. (DEPOIS DO CAP. 1)
					Evento bruxa_in_caldeirao ainda é só "caldeirão (em construção)".
[?]			após criar, vem cena NPC, basta ir no castelo, guardas deixam passar agora.
					Feito: criar qualquer poção (ControlePreparo) → missao01_pocao_feita = 1 → ponte_guarda e estradaB_guarda ganham página 2 (passável, "Pode passar."). Falta a cena do NPC.
					ponte_guarda e estradaB_guarda só bloqueiam, sem condição.
[ ]			finalização, entrega poção e resultados possíveis.
					castelo_in só tem a passagem.

```

## Terminar até o Cap. 1 (1)

```

[ ] Bugs/Revisão:
[ ]		Camera trava quando chega num canto de tela mas o parallax não deve travar, senão dá uma sensação ruim de impacto quando chega perto de um canto de tela.
[?]		Página com várias condições (todas precisam valer): variável, item, personalidade, posição, direção
[?]		Página reavalia ao ganhar/perder item e ao mudar personalidade
[?]		Notificação de item nunca aparece (NotificacaoItem sem Label em main.tscn)
			Label já existe; agora o painel começa escondido e uma notificação nova não é mais apagada pelo timer da anterior.
[?]		Segurar o botão de poção para sair agora é 0,7 s (TEMPO_LONGO)


[ ]	Cena Livro de Receitas:
[ ]		Layout
[ ]		Uma receita por página, 2 páginas por folha, mostra o livro aberto e tem opção de controlar com clique ou arrastando, é redundante para melhor UX.
[ ]		Ao clicar numa página mostra seus ingredientes e tempo relacionado com seu gráfico, seu resultado.
[ ]		Fazer tudo bem animado e temático de bruxaria.


[.] Itens:
[?]		Matriz A aceita poucas casas decimais no Inspector, ainda está arredondando para 2 casas. quero no mínimo 5. Por enquanto tenho que editar diretamente o .tras
				Passo do Inspector agora é 0.00001 (item_data.gd). Conferir no editor.


[ ] Intro:
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
[ ]		Ajustes mínimos: cor, shake, efeitos, aparar para a versão final.
[ ]		Tutorial(leve) na primeira vez. (DEPOIS DO CAP. 1)

[ ] Mapa:
[?]     Spawn de itens: existem as áreas de spawn, que invocam um tipo de evento, limitados por qtd de invocações no mapa.  
[.]         Remover todos eventos placeholders de item dos mapas
				Removidos os 6 cogumelos de teste (teste_magia) de bruxa_out e castelo_out. Fica só o da história (estradaA). teste_magia.tres sem uso.
[?]         Adicionar o floresta_erva oficial (AreaErva na floresta)
[?]         Adicionar o bosque_cogumelo oficial (AreaCogumelo no bosque, x≈1000–1700, y=580: ajustar no editor)
[.]     Resolver problema de área de colisão, verificar cada evento, posição, etc.
[ ]		Quando chego perto de uma borda o paralax age parando bruscamente, quero que ele não fique limitado à tela, talvez tenho que mudar o tamanho dos cenários?
[.]		Padronizar parallaxes em cada mapa: ...,Fundo2,Fundo,Meio,Frente,Frente2... (meio é onde ficam os eventos também)
[?]		Testar loop de bgm, loop de bgs. (floresta.mp3 já está com loop=true no import)
[?]		cada mapa tocando BGM da fase em loop. (verificar mapa_base)
			Feito: mapa_base tem bgm/bgm_volume no Inspector. Mesmo bgm = continua; outro = troca; vazio = para. Só a floresta tem bgm (floresta.mp3).
[ ]		SE nos teleport (depois: som de passos na transição)
[?]		Tela preta das passagens mais curta: "esperar" depois do teleporte baixado de 0.4 para 0.2


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
[ ]     Separar o Inventário do HUD. O HUD deve fazer o esquema de carta que vira ao clicar em um de seus componentes (inventário ou status), pensar como vai ser a dinâmica da carta girando, ativação, desativação, etc. Um clique em cima para mostrar, e se ficar alguns segundos sem interação ele desvira.
[ ]		Animar o inventário e o status como um card que gira/abre ou algo assim. 
[ ]		Fazer uma animação de carta virando para os diálogos, opções, inventário e status. 



[ ]	Arte Visual
[?]     como fazer imagem ficar fazendo pan infinito? usar nas núvens
			Feito: src/cena/nuvens_movendo.gd num TextureRect em modo Tile (velocidade px/s). Aplicado nas nuvens da ponte (Fundo3).
[ ]     Fazer sprite:
[ ]         mapa floresta de 6000px (talvez diminua), com paralax, provisório.
[ ]         inventário e status de costas (card que gira)


[ ]	Audio:
[ ]     Fazer músicas: 
[ ]         intro, 
[ ]         casa bruxa, 
[?]         floresta, 
[ ]         estradas, 
[ ]			ponte (ouvir ost: ragnarok, pokemon, nobuo uematsu)
[ ]         castelo, 
[ ]         ...

[ ]	Animações:
[ ]		

[ ] Estilo:
[ ] 	organizar o layout e textura dialogo/opções
[ ]		Ajuste estético, borda, cor, fonte, etc.
[ ]		Criação de estilos padronizados para cada coisa. (?) tipo estilo texto, estilo menu, ...?
[ ]


[ ]	Estudar se vale:
[ ]		- Não precisa mais ser CharacterBody2D?. (problema de falta de collision shape foi resolvido para os eventos, agora usa o da página)
[ ]		- Definir posição dos eventos no mapa, tudo por código


[ ]	Status: ()
[?]		popup do nome da característica quando hover ou click. ou algo legal. (status.gd: toque no ícone → balão com nome e valor por 1,5 s)
[ ]		Animação de aparição. (como se virasse uma carta, etc) 


[ ]	Menu Principal e Pausa
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

## Game Design Document

[_gdd/v1.3.11/main.pdf](https://github.com/DanMaker01/bruxa-v-0.1/blob/main/_gdd/v1.3.11/main.pdf)
