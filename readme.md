# Jogo da Bruxa

![1793375384971](image/readme/1793375384971.png)

![1793377160839](image/readme/1793377160839.png)

![1793375398241](image/readme/1793375398241.png)

MAPA: https://miro.com/app/board/uXjVHHRQsyM=/

# Coisas a fazer

```
  ==============================
||		LEGENDA:	||
||	[ ] A fazer		||
||	[.] Em progresso	||
||	[?] Testar		||
||	[!] Finalizado		||
  ==============================
```

## Terminar até o Cap. 1 (1)

```

[ ] Sprites 100%
	[ ] Faces
		[ ] Bruxa
			[ ] neutro
			[ ] pensando
		[ ] Rei
			[ ] neutro
			[ ] furioso
		[ ] Princesa
			[ ] neutro
		[ ] Guarda1
		[ ] Guarda2
		[ ] NPC1 - Criança
			[ ] neutro
		[ ] NPC2 - Criança
			[ ] neutro
		[ ] NPC3 - Adulto
			[ ] neutro
		[ ] Goblin
			[ ] neutro
		[ ] Padre
			[ ] neutro
	[ ] Sprites
		[ ] Bruxa
			[ ] parada
			[ ] andando
		[ ] Rei
		[ ] Princesa
		[ ] Guarda1
			[ ] parado
			[ ] andando
		[ ] Guarda2
			[ ] parado
			[ ] andando
		[ ] NPC1 - Criança
			[ ] parado
			[ ] andando
		[ ] NPC2 - Criança
			[ ] parado
			[ ] andando
		[ ] NPC3 - Adulto
			[ ] parado
		[ ] Mercador pai
			[ ] parado
		[ ] Mercador filho
			[ ] parado
		[ ] Padre
			[ ] parado
		[ ] Portas
			[ ] porta padrão
			[ ] porta bruxa
			[ ] portão castelo
		[ ] Objetos
			[ ] Livro de Receitas
			[ ] ...
	[ ] Cenários
		[ ] floresta
		[ ] bruxa_in
		[ ] bruxa_out1
		[ ] bruxa_out2
		[ ] bruxa_out3
		[ ] bosque
		[ ] cidade
		[ ] cidade_in01
		[ ] cidade_in02
		[ ] cidade_in03 (será aumentado)
		[ ] estrada_a
		[ ] ponte
		[ ] castelo
		[ ] castelo_in01 (será aumentado)
		[ ] castelo_in02
		[ ] castelo_in03
		[ ] estrada_b

[ ]	Audio 100%
	[ ] BGM
		[ ] intro (xxxHolic opening)
		[ ] floresta
		[ ] bruxa_out1
		[ ] bruxa_out2
		[ ] bruxa_out3
		[ ] bruxa_in
		[ ] bosque
		[ ] cidade, cidade_in01, cidade_in02
		[ ] cidade_in03
		[ ] estrada_a
		[ ] ponte
		[ ] castelo
		[ ] castelo_in01, castelo_in02
		[ ] castelo_in03
		[ ] estrada_b
	[ ] BGS
		[ ] tremor
		[ ] passaros
		[ ] som floresta
		[ ] vento
	[ ] SE
		[ ] porta01 	(porta batendo normalmente)
		[ ] porta02 	(rangido de porta fechando devagar)
		[ ] passos 		(para transição)
		[ ] pulo 		(velocidade)
		[ ] dash
		[ ] magia01		(genérico)
		[ ] magia02 
		[ ] magia03
		[ ] pancada01
		[ ] pancada02
		[ ] corte
		[ ] vidro01
		[ ] vidro02
		[ ] carta 		(girando)
		[ ] aplausos
		
[ ]	Menus 100%
	[ ] menu inicial
		[ ] start, load, config, sair
	[ ] menu pause
		[ ] continuar, save, load, opções, menu principal
	[ ] cena caldeirão
		[ ] bruxa, caldeirão, botões, inventário
	[ ] cena loja
		[ ] ... (depois)
	[ ] opções (único)
		[ ] audio, video, etc
	[ ] cartas/hud
		[ ] definir pentagrama para o verso das cartas inventário/status 
		[ ] definir audio das interações
		[ ] interação com outros menus


[ ] Caldeirão 100%
	[ ]	Tutorial do caldeirão na 1ª vez. usando poucos ingredientes, mudar intro talvez. tentar integrar naturalmente com o que já tem. 
	[ ] Layout
		[ ] Reformular Layout (pensar em celular). Menus, botões,Bruxa_chibi,caldeirão, texto em cima do caldeirão (passar para falas da bruxa), feedback rápido da bruxa.
	[ ] Feedback bom pra temperatura do caldeirão e itens, tanto frio quanto quente
		[?] Fazer feedback: Caldeirão temperatura abaixo de 100°C até apagar. veja que a questão de apagar é responsabilidade do fogo e não do caldeirão, o caldeirão só mostra a própria temperatura T.
			Feito: abaixo de 100 °C as bolhas e um fiozinho de vapor vão sumindo até 70 °C (visual_caldeirao.gd: T_FRIO_INI/T_FRIO_FIM). O caldo que já ferveu e cai abaixo de 95 °C: a bruxa avisa "Está esfriando..." (uma vez por queda; cena_preparo.gd: T_AVISO_FRIO).
		[.] anéis branco > amarelo > laranja > vermelho > verde no ideal, e volta ao passar.
			(item antigo dos círculos branco > amarelo > laranja > vermelho > verde juntado aqui: feito, paleta "aproxima" na tecla P)
			Modos para testar no preparo (teclado):
				M = régua (punição / proporcional / absoluto), já existia. 
					(pensar em como o ingrediente pode ser perdido, pode ser proporcional de 0% no início de cada anel a 100% quando a punição é 100% em cada anel. ou absoluto com um máximo alto sendo o circulo completo)
				P = cores: FAIXA (padrão: anéis contínuos, cada trecho com a cor do aproveitamento naquele ponto: vermelho > amarelo > verde no ideal > amarelo > vermelho; o anel começa vazio e vai revelando a cor; anel de fora = cozimento, de dentro = tempo) 
					· dourado (antiga) (remover voto:1/2)
					· aproxima (branco > amarelo > laranja > vermelho > VERDE no ideal; passando: vermelho > laranja > amarelo > branco) (ok)
					· semáforo (cinza > amarelo > verde; passando: amarelo > laranja > vermelho > preto) (parece a melhor)
					· cor única (o anel inteiro na cor do estado atual).(é interessante mas o anel tem que ser multicor, para a pessoa aprender) (deletar voto:1/2)
				C = anel já colorido (as bolhinhas apagadas já mostram a cor do trecho, fraquinhas, e a "barra" vai acendendo). (interessante pq mostra as cores, porém já dá uma facilitada, talvez seja bom pra cozinha não ficar tão difícil)
				A vela usa as mesmas cores. Começa em "faixa". Outras ideias de feedback: me diga e eu ponho como mais um modo.
	[?] fazer um indicador linear de cor do caldeirão também ao lado do indicador do fogo, com suas categorias de cores. e no debug pode mostrar as temperaturas numericamente.
		Feito: régua vertical à direita (ferro <100, fundo rubro 100, rubro 160, rubro intenso 200), mesma cor do caldeirão. Com o debug aberto mostra T e F.
		Corrigir: colocar essa escala de cores no menu de debug do caldeirão apenas. A escala de T(t) também deve ficar só no debug, quero ela circular acima do caldeirão, enquanto a de F(t) fica abaixo do fogo, como já está.
		[?] Feito (layout D): sem réguas na tela. Com o debug do caldeirão aberto: arco de T acima do caldeirão (cores do caldeirão), arco de F em volta do fogo (cores da chama, SistemaTermico.CORES_FOGO), régua de cor do caldeirão e selo "estável" (arcos_debug.gd, regua_caldeirao.gd).
	[.] ver se consigo jogar jogar 8 ervas e 4 cogumelos rapidamente e sem erros, medir 10 testes. no meio da receita as vezes esqueço um cogumelo. talvez dar um jeito de agrupar antes ou jogar multiplos, por exemplo segurando o botão do ingrediente ou podendo combinar eles antes. UI:caso segure o botão, ou caso selecione a jogue multiplos joga em quantidade/velocidade maior.
		Feito (jogar_varios.gd): segurar joga um item a cada 0,32 s (velocidade constante, INTERVALO_INI) e a bruxa vai contando no balão quantos entraram ("1!", "2!"...). Toque joga 1. Falta medir os 10 testes.
	[ ] Resultado:
		[?] resultado poção deve ter cartas que se abrem e mostram os resultados. ao sair, todas as cartas fecham.
			Feito: 3 cartas do HUD (Carta.criar: sprite hud_frame2, verso com pentagrama, virada na diagonal), duas em cima (1 nome + matriz, 2 pentágono) e uma embaixo (3 ingredientes com anéis), que aparecem de verso e viram em ordem.
			Para reaproveitar em outras telas: var c := Carta.criar(tamanho, "título do verso"); add_child(c); conteúdo em c.face("Frente"); c.abrir() / c.fechar(). Ao confirmar: 2 e 3 fecham, a matriz vira a poção, a 1 fecha e a poção vai para o inventário.
	[ ] Usar cartas tbm na cena do caldeirão, para botões, etc?


[ ] Livro de Receitas:
	[ ] Receitas:
		[ ] Balanceamento de Receitas:
			[ ] DEPOIS: (Todas) As receitas têm (devem ter) tempo entre [5seg,5min], com o tempo médio 1min.		
			[ ] Se eu colocar muita (QUANTO?) quantidade de um ingrediente, vai fazer uma poção muito forte.
			[ ] Faz sentido uma receita que leva o mesmo ingrediente 2x em tempos diferentes? I_tempo, I_Temper, Q, como conseguir aprovetar duas vezes um mesmo tipo de item numa mesma receita?
			[ ] DEPOIS: Fazer receita dobrada tem efeito de potencializar (escalar) a matriz resultante. por exemplo se fizer uma poção da calma profunda dobrada, 
			[ ] 
		[ ] 1ª receita: calma profunda
			[ ] escrever e padronizar:o padrão é nome, passos (só existe 2 passos: cor de fogo(cor) e colocar ingrediente(qtd,tempo)). pensar tem algo mais que possa ser feito numa receita?
		[ ] 2ª receita: desenvoltura
			Ajustado: musgo t_max 12 → 35 (aguenta os ~30 s finais); flor m 2400 → 5000, s−/s+ 900/1400 → 1900/2900 (Q de 60 s a ~85 °C ≈ 5100). Juntos dão diag(1,1,1.4,1,1) se o musgo entra depois.
			balancear tempo, u,s-,s+, Tmin,Tmax,tmin,tmax, etc de cada item. infusao
		[ ] balancear dificuldade, peso de cada erro: tempo, temp, cozimento, explorar os TIPOS de matrizes. explorar o que é posível nesse sistema térmico
			[?] balancear o resultado da poção de extroversão. pois um cogumelo já está sendo suficiente para o melhor resultado, entender o pq.
			Por quê: o cogumelo multiplica E por 1,16 (+16%) e o critério do filho do mercador aceitava qualquer E que subisse 10% (e aceitava C/A/O mudando até "pouco").
			Ajuste: E precisa subir "muito" (>= +30%; a desenvoltura dá +40%) e O, C, A não podem mudar (menos de 10%); N não pode subir; nenhum traço extremo.
			Com 1 cogumelo agora: "B-bom... dia." / "Melhorou um pouco, mas ainda não dá para deixar a loja com ele."
		
	[?] Interação com resultado do preparo:
		[?] Como será? (substituído pelos rascunhos)
			[ ]	Ao criar uma poção nova a bruxa tem opção de anotar a receita no livro. Caso escolha anotar: Abre a cena do livro de receitas já anotando.
				Edit: pode ter uma animação dela criando a página. porém acho que está um pouco carregado o resultado do preparo, cabe diminuir.
				[?] Feito: no resultado, segurar acelera (3×) e um toque pula direto para o resultado pronto (janela_resultado.gd: TEMPO_TOQUE, VEL_SEGURAR, VEL_PULAR). Na carta de ingredientes os anéis enchem todos juntos.
			[ ]	Iniciar o livro de receitas, cena com janela que inicia após uma nova receita. A cena de livro abre e é escrita uma nova receita.
		[ ] Alternativas?
			[?] manual, só escreve a receita feita quando for abrir o livro, daí aparece a animação dela escrevendo na página.
				Feito: o rascunho continua sendo guardado sozinho, mas ao abrir o livro ele vai até cada página nova (até 3) e escreve o nome, os passos e o resultado linha por linha.
	[] Cena do Livro:
		[?] Mesma receita --> mesma poção. Mesma poção -/-> mesma receita.
			Feito: receita (rascunho ou sem nome) que dá uma poção com nome recebe o nome da poção, inclusive quando a bruxa nomeia a poção no livro. Nome dado pela bruxa não é trocado.
		[?] Cena do livro feita (src/livro/, scenes/cena_livro.tscn; F6 abre sozinha com um livro de teste):
			Livro aberto, 2 páginas (640x640, o HUD fica embaixo), uma receita por página. Setas ‹ › ou arrastar o dedo.
			Receita = nome + passos: "chama <estado>" ou "<ingrediente> ×qtd, N s" (joga e espera N s); "Finalizar" é sempre o último.
			Estados da chama (EstadosChama, pela T do caldo com a chama estável): apagado, transparente 59-80, transparente grande 80-95, normal ~100, laranja ~110, amarelo ~135, branco ~155, púrpura ~170, negro >195. O fogo continua em pulsos.
			Páginas: efetivas (Editar, Memorizar, Apagar), de NPC (Memorizar), rascunhos no fim (Passar a limpo, Apagar; últimos 10, um por preparo). Livro com 12 páginas. Apagar pede confirmação.
			Editor: na própria página (ver abaixo). Só ingredientes que a bruxa já teve (GameTemp.itens_vistos). Mudar os passos apaga o resultado anotado.
			Memorizar: uma receita só, vale para o próximo preparo (vira o guia no canto do preparo). Dados em GameTemp.livro (LivroReceitas). Receitas de NPC vêm de dados/receitas com conhecida = true e passos_livro.
			Integração com o preparo: feita (ver abaixo).
			Evento do livro no bruxa_in (bruxa_in_livro, nó Livro em x 600 y 448, ajuste no mapa): clique abre o livro. Comando novo "Livro" (cmd_livro.gd) abre e espera fechar.
			[?] Preparo reformado para celular (src/preparo/layout_preparo.gd). Só ficou o layout D (os de teste Original, A, B e C e o botão Layout foram removidos do código):
				carrossel de ingredientes embaixo do caldeirão, Abaixar (esquerda) e Abanar (direita) grandes, Acender/Apagar embaixo, Poção no canto superior direito com a receita memorizada abaixo.
				Com o debug do caldeirão aberto: arco de T acima do caldeirão, arco de F em volta do fogo, régua de cor do caldeirão e selo "estável".
				regua_chama.gd não é mais usado (era dos layouts antigos): pode apagar o arquivo.
				EDIT: Receita memorizada (guia_receita.gd): agora no canto superior direito, abaixo da Poção (o botão Layout foi removido; layout fixo no D), marca o passo atual sozinha (chama certa por 1 s; ingrediente: entrou a quantidade e passaram os segundos). Some quando a poção termina.
				Ao terminar a poção (transcritor_receita.gd): o preparo vira passos (chama dominante antes de cada ingrediente, mesmo item em sequência junta, tempos ao segundo). Se bater com uma página (±1 s) soma nela (Feita Nx, melhor resultado); senão vira rascunho.
				Só entram os ingredientes que serviram: os perdidos e os retirados não entram na receita.
		[?] animações de livro abrindo, livro fechando, avançar página, voltar página, avançar até encontrar página, adicionar página, remover página
			Feito: abre/fecha esticando da lombada; virar = a folha fecha na lombada e a outra abre; ir até uma página = folhas rápidas; página nova: a tinta aparece; apagar: a página cai e some.
		[?]	Ao clicar numa página mostra seus ingredientes e tempo relacionado com seu gráfico, seu resultado.
			Feito (detalhe_receita.gd): tocar no papel de uma página já feita abre o melhor preparo: gráfico T(t) com as faixas de cor da chama e a entrada de cada ingrediente, aproveitamento de cada um e a matriz. Só para preparos feitos a partir de agora (guardam a curva).
		[.]	Fazer tudo bem animado e temático de bruxaria. (animações feitas; falta arte temática)
		[.] Database (nomes das proibidas ficam para o Cap. 2): Nomear as poções de referência no catálogo (PocaoReferencia: nome, descrição, A). Poção da Calma Profunda. Poção #2. Poções proíbidas. 
			Poção #2 = Poção da Desenvoltura (definir bem antes do Cap. 1; só usada no Cap. X).
			Poções proibidas: as que têm algum autovalor 0 (2^5 − 1 = 31 combinações de traços zerados). Ainda sem nome. (feito: 31 no catálogo como "Poção Proibida (sem O, C...)", nomes provisórios)
			Poção de Pó de Retorno Concentrada no catálogo, com efeito (teleporte para bruxa_in). Pó: diag(0.97,1,1,1,1.03), cozimento leniente (m 3000, T 60–170, t 10–150, folgas 0,4/0,6).
			Nome: poção de um item só agora usa "Poção de [item] [qualidade]" antes de procurar no catálogo (senão um pó mal cozido virava "Concentrada").
		[?] menu de editar receita será reformulado, o estilo ficou legal. mude para drag and drop. o botão de chama e o de item devem ser mais intuitivos/ux friendly. os passos podem ser editados. verificar semelhança 
			Feito (editor_receita.gd), na própria página: Editar transforma a página (nome vira campo, passos viram cartões, Cancelar/Pronto) e a página ao lado vira a paleta com as chamas (bolinhas coloridas), os ingredientes vistos (ícones), a lixeira. Tocar na paleta adiciona no fim, arrastar coloca onde soltar; arrastar um cartão reordena; arrastar para a lixeira apaga; tocar num cartão abre a edição (ingrediente: quantidade e segundos; chama: troca a cor).
			Números: arrastar para o lado muda; tocar nas setinhas ‹ › soma ou tira 1 (o botão Números e a roda saíram).
			Nome da poção: sem botão "Dar nome à poção". Poção sem nome ganha nome ao passar a limpo (ou Editar): o nome da receita vale para a poção (item, catálogo). A página mostra só "poção sem nome".
			Corrigido: passar a limpo e dar nome deixava "Nunca feita" (a comparação dos passos via int x float como mudança; agora compara tipo, chama, item, qtd e segundos inteiros).
			Semelhança: avisa "Igual à página N" (±1 s) ou "Parecida com a página N" (mesmos ingredientes e chamas, tempos diferentes); deixa salvar.


[ ] História/Roteiro
	[ ]	Diálogos devem condizer com a época
		[ ] Cap. 1 (-N)
			[?] intro-Campones
			[ ] Guardas
			[ ] Bosque NPC
			[ ] Cidade 
			[ ] Castelo
		[ ] Cap. 2 (+E)
	[ ] Usar traços na história: 
		O,(conservador com pouca abertura)
		C (consequencialidade, prudencia, preguiçoso),
		A (amabilidade, aumentar ou diminuir?)
	[ ] Usar permutação de traços
	[ ] Poções proibidas


[ ] Diálogos 100%
	[ ] Intro : melhorar texto (tempo e ritmo).
	[ ] Cap. 1: Revisão de cada evento.
	[ ] Sprites: Balão de expressão por sprite: precisa da arte (1 sprite de balão, se der pra fazer sem deformar as quinas seria ideal)
	[ ] Estilo visual:
		[ ] organizar o layout e textura dialogo/opções
		[ ]	Ajuste estético, borda, cor, fonte, etc.
		[ ]	Criação de estilos padronizados para cada coisa. estilo de texto, estilo de janela, paleta de cores, animação coerente, etc...
		[?] Eventos de diálogo devem verificar se o próximo evento a tomar a frente será diálogo também, exceto depois de comando wait, etc.
			Feito: a carta do diálogo não desvira se vem outro diálogo em seguida (Interpreter.dialogo_a_seguir: fila de diálogos ou próximo comando de um evento rodando, pulando os instantâneos como variável/if/label/item/som). Esperar, mover, fade etc. interrompem. Espera no máximo 1,5 s (carta.gd: ESPERA_MAX_DIALOGO).
			se um evento acabar em mensagem e outro iniciar em mensagem com o mesmo falante, nome, foto etc então o card não deve fechar depois do primeiro evento, pois é uma continudade. exemplos disso acontecem ao chamar eventos por comando, entre outros.


[ ] Quests
	[ ] Quest Zigmund
		[ ] personalidade
		[ ] situação
			[ ] problema
			[ ] objetivo
			[ ] plano
			[!] sumiu na floresta
			[!] pediu para a bruxa ajudar a princesa
			[!] casamento
	[ ] Quest Bosque Goblin
		[ ] ???
	[ ] Cap. 1 Casamento
		[ ] cidadeA_in01 não tem quest?


[ ] Personagens
	[ ] Fazer uma ficha de personagem 
	[ ] Criar personalidades big five
	[ ] Cada personagem tem seu linguajar próprio e manias.
		[ ] Bruxa
		[ ] Campones
		[ ] Guarda1
		[ ] Guarda2
		[ ] bosque_npc
		[ ] Cidade
			[ ] NPC Adulto
			[ ] NPC Criança 1 
			[ ] NPC Criança 2
			[ ] Casa 1
				[ ] NPC 
			[ ] Casa 2
				[ ] Mercador Pai
				[ ] Mercador Filho
			[ ] Igreja
				[ ] Padre


[ ] Core/Eventos:
	[?] Colisão:
		depois de pegar o véu. quando clico no véu acima da porta, a bruxa(centro dela) vai até a posição que eu cliquei e ativa o evento do véu (as vezes ativa até antes). 
		o certo deve ser: quando clicar em eventos, deve ir até encostar no retangulo de colisao(colisão e não interação) e já ativar o evento, não precisa ir até a posição clicada. Quero testar se isso é bom para o game feel.  
		Feito para testar: clicar num evento longe faz a bruxa andar só até encostar na borda da colisão do evento (do lado dela; vale também para passáveis) e já ativa. Para voltar ao jeito antigo: game_manager.gd, CLIQUE_ATE_COLISAO = false.

[ ] Documentação e Organização
	[ ] organização da pasta Graphics(está sendo chamada de assets neste projeto) estilo rpgmaker:
		Animations (efeitos especiais, magias, etc)
		Characters (eventos)
		Icons
		Panoramas (imagens para cenário)
		Pictures (sprites para controlar na tela)
		Transitions
		Windowskins (janelas, etc)
	[.]	Padronizar parallaxes em cada mapa: ...,Fundo2,Fundo,Meio,Frente,Frente2... (meio é onde ficam os eventos também)
	[ ] GDD
		[!] v1
		[!] v2
		[!] v3.3

[ ]	Save/Load
	[ ] Implementar o save/load final, e linkar no menu principal e de pausa.
	[?] Game_Temp deve ter save e load de arquivo_unico de titulo "save"+time_stamp
	[ ] GameTemp, posição player, mapa, etc



[ ] Decisões menores:
	[ ] Quando o HUD abre a primeira vez (bruxa_out1 na intro? bruxa_in antes do diálogo?).
	[.] Guardas da ponte e da estradaB: o Mover da bruxa vinha antes da variável que libera, e a página sólida bloqueava. Agora a variável vem antes: a página muda na hora (passável) e o Mover anda. Regra: a página do evento troca assim que a variável muda, mesmo com os comandos ainda rodando. (mudar para 250px de deslocamento)
	[?] Editor de eventos em Python (_/editor_eventos, abrir com abrir_editor.bat; precisa de PySide6): páginas, condições, comandos, diálogo em texto (Ctrl+T), labels (F12), várias páginas/eventos de uma vez, buscar/substituir, desfazer, backup ao salvar. Ver _/editor_eventos/README.md.
	[.] brilho na porta, da mesma cor do véu, ao trocar o véu.
		Feito: ao clicar no véu adicione um flash da cor do véu no sprite da porta, para que ele pisque da cor.
		Feito: saiu o brilho da porta (o do véu continua); a porta pisca 2 vezes na cor nova. Novo tipo de efeito PISCAR no Mostrar efeito (serve para qualquer evento)
		Correção: tingiu, mas como a cor do objeto não era branca misturou as cores do objeto mais a tintura. quero que leve em consideração isso e pinte da cor que eu pedi. preciso mandar o mesmo sprite com tons de branco para isso?
	[ ]	Representação de poções visual com matriz/grafo. (feito, versão simples: no pentágono cada ponta sai do traço que mais contribui e gira até a sua; diagonal = só escala com um pulo)
	[ ]		(Cap. 2) Mostrar o pentagrama, cada aresta representa um componente. Pensei em relacionar as arestas com a_ij e criar um feedback útil visualmente.
	[ ]		(Cap. 2) O pentagrama deve ter animações a depender da matriz. Por exemplo, matriz diagonal (ou próxima de diagonal a menos de ruído) só escala, então a animação do pentagram é escalar. Matriz que troca dois componentes deve trocar duas pontas do pentagrama suavemente, como uma permutação ou rotação.

[ ] Bugs/Revisão:
	[ ] missao01_convite é gravada e nunca lida: fica para o Cap. 2 (convite do casamento).
	[?]		misc: Variações no flip card. Sorteadas: normal = 1 flip diagonal; variações no mesmo tempo: 5 flips com velocidade decrescente; flip mudando a dimensão horizontal, com 1 ou 5 flips.
		Feito (carta.gd, vale para todas as cartas): eixo diagonal 80% / vertical 20%; voltas: 1, ou 3 bem raro (5%); mesmo tempo total. Desliga com variar_virada = false. 
	[?]		godot: Matriz A aceita poucas casas decimais no Inspector, ainda está arredondando para 2 casas. quero no mínimo 5. Por enquanto tenho que editar diretamente o .tras
					Passo do Inspector agora é 0.00001 (item_data.gd). Conferir no editor.
	[?]		Testar: loop de bgm, loop de bgs. (floresta.mp3 já está com loop=true no import)
	[?]		cada mapa tocando BGM da fase em loop. (verificar mapa_base)
				Feito: mapa_base tem bgm/bgm_volume no Inspector. Mesmo bgm = continua; outro = troca; vazio = para. Só a floresta tem bgm (floresta.mp3).
	[?] Parallax e câmera nas bordas (juntos):
		Como está: câmera presa entre 0 e a borda direita da maior imagem do "Meio" (mapa_base). Parallax simples: cada camada só segue a câmera pelo seu fator (fundo 0.2, meio 1.0, frente 1.1, interiores "Frente+" 0.9). SUAVIZAR = false (câmera sem suavização).
		Decidido: o mais simples. Na borda a câmera para e todas as camadas param junto (PARALLAX_NA_BORDA = false, BRUXA_NO_CENTRO = false, BORDA_SUAVE = 0). Testados e descartados: camadas continuando na borda (tranco), freio suave da câmera (quebra a ilusão), bruxa parando antes da ponta (encurtava os mapas). O código ficou desligado, cada um com sua constante.
		Regra das imagens (para não aparecer cinza): camada sem loop precisa de largura ≥ 640 + fator × (largura do mapa − 640). Ex.: Frente 1.1 em mapa de 6000 px = 6536 px (ou scale x 1.09). Mapas maiores não são necessários.
		Por camada: bosque (Meio chão 1.0, Frente árvores 1.1, scale 1.07); bruxa_out (Fundo 0.2, casa no Meio); castelo_in03 (Fundo 0.2, Frente 1.1, scale 1.051); castelo_out (Fundo 0.2, Frente 1.1); cidadeA, estradaA, estradaB (Fundo 0.2); ponte (Fundo4 céu, Fundo3 nuvens longe pan -6, Fundo2 montanha, Fundo nuvens pan -12, todos 0.2; Meio/Meio2/Meio3 1.0; Frente nuvens 1.1 pan -40).
		[?]	Quando chego perto de uma borda o paralax age parando bruscamente, quero que ele não fique limitado à tela, talvez tenho que mudar o tamanho dos cenários? (câmera com borda suave; CamadaParallax na ponte)


```

## Possíveis expansões (futuras)

```
[ ] Sistema de clima
[ ]	Sistema de fama
[ ]	Sistema de compra/venda
[ ]	Sistema de mercado/valor dinâmico

```
