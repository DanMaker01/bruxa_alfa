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

[ ] Arte Visual 100% 	(arquivos .png estão na pasta /assets/)

	[ ] Faces	(422x908 hoje, porém a parte de baixo fica escondida atrás da caixa de diálogo. pode mudar para 420x740 ou outro tamanho)
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

	[ ] Sprites		(tamanhos variados) (a âncora do sprite é o CENTRO-INFERIOR) (pode mudar as larg/alt se quiser)
		[ ] Bruxa
			[ ] parada		(80x252)
			[ ] andando		(126x252)
			[ ] correndo	(126x252)
		[ ] Rei				(105x200)
		[ ] Princesa		(105x200)
		[ ] Guarda1			(105x200)
			[ ] parado
			[ ] andando
		[ ] Guarda2			(105x200)
			[ ] parado
			[ ] andando
		[ ] NPC1 - Criança	(105x145)
			[ ] parado
			[ ] andando
		[ ] NPC2 - Criança	(105x145)
			[ ] parado
			[ ] andando
		[ ] NPC3 - Adulto	(105x200)
			[ ] parado
		[ ] Mercador pai	(105x200)
			[ ] parado
		[ ] Mercador filho	(105x200)
			[ ] parado
		[ ] Padre			(105x200)
			[ ] parado
		[ ] Portas
			[ ] porta padrão (90x180)
			[ ] porta bruxa
			[ ] portão castelo
		[ ] Objetos
			[ ] Livro de Receitas (69x69)
			[ ] ...

	[ ] Cenários		(largura variada, altura: 640px)
		[ ] floresta		(6000x640)
		[ ] bruxa_in		(1280x640)
		[ ] bruxa_out1		(1280x640)
		[ ] bruxa_out2		(1280x640)
		[ ] bruxa_out3		(1280x640)
		[ ] bosque			(2000x640)
		[ ] cidade			(4000x640)
		[ ] cidade_in01		(1280x640)
		[ ] cidade_in02		(1280x640)
		[ ] cidade_in03		(2000x640)
		[ ] estrada_a		(2000x640)
		[ ] ponte			(2000x640)
		[ ] castelo			(3000x640)
		[ ] castelo_in01	(2500x640)
		[ ] castelo_in02	(1280x640)
		[ ] castelo_in03	(1280x640)
		[ ] estrada_b		(2000x640)
		[ ] Fundo menu inicial (640x960) (ou uma img em loop)

[ ]	Audio 100%
	[ ] BGM:
		[ ] intro 			(xxxHolic opening)
		[ ] floresta		(remix da que já tem)
		[ ] bruxa_out
			[ ] bruxa_out1	(só BGS de natureza)
			[ ] bruxa_out2	(só BGS de natureza) (variação)
			[ ] bruxa_out3	(só BGS de natureza) (variação2)
		[ ] bruxa_in 		(sem bgm, talvez bgs)
		[ ] bosque			(mágico, bem curto)
		[ ] cidade, _in01, _in02 (+ harpa, - volume, +palmas)
		[ ] cidade_in03
		[ ] estrada_a
		[ ] ponte
		[ ] castelo
		[ ] castelo_in01, castelo_in02
		[ ] castelo_in03
		[ ] estrada_b
		[ ] menu inicial
		[ ] ???
	[ ] BGS:
		[ ] sapos (bruxa_out1)
		[ ] tremor
		[ ] passaros
		[ ] som floresta
		[ ] vento
		[ ] água correndo
		[ ] (metal?)
	[ ] SE:
		[ ] magia01
		[ ] magia02 
		[ ] magia03
		[ ] pancada01
		[ ] pancada02
		[ ] corte
		[ ] vidro01
		[ ] vidro02

[ ] ícone
	[ ] descer um pouquinho 

[ ] Caldeirão 100%
	[.] Catálogo e poções
		[?] Catálogo de poções (dados/pocoes): (Nomeação de poções)
			qualquer poção com a matriz perto de alguma do catálogo recebe o nome dela e,
			pra ativar seu EFEITO (caso o tenha) é necessário fazer uma poção com qualidade >= 95% 
			QUESTÃO: 4 mal cozidos = 3 bem cozidos?
			RESPOSTA: não é problema 4 mal cozidos equivaler a uma poção com 3 bem cozidos as vezes.
						o problema é isso escalar para 8 muito mal cozidos equivaler a 3 bem cozidos. Esse caso deve ser testado.
			[!] Tolerância por poção (PocaoReferencia.distancia_max; 0 = a do catálogo, 0,05). 
				Retorno: 0,02 → 2 ou 4 pós bem cozidos não viram mais Poção do Retorno nem ganham o efeito 
			[?] Testado (multiplicando as quantidades e achando o aproveitamento que mais aproxima): 
				Desenvoltura e Retorno escalam sem limite (×2,67 a 0,36-0,38 e ×4 a 0,24-0,25 ainda ganham o nome; 8 pós a 0,38 ≈ 3 pós bons). 
				Retorno não ganha o efeito (exige 0,95). 
				Calma passa no ×2 (a 0,52), nos outros só não passa por arredondamento. Calma e Desenvoltura não têm mínimo: o efeito é a própria matriz. Opções pensadas: corte por ingrediente (abaixo de ~0,4 não conta), dose quadrática (a²), impureza (1 − a vira ruído), mínimo só no nome. A decidir.
			[?] PROBLEMA a tratar: quantidades diferentes podem chegar na mesma matriz (ex.: 4 mal cozidos ≈ 3 bem cozidos). 
				Hoje só o aproveitamento mínimo segura. Já é o suficiente, mas tem algo mais geral?
				[?] Decidido: aceito como dose (cada ingrediente vale ~k·a; mal cozido = dose menor). O aproveitamento mínimo do efeito continua segurando.
					QUESTÃO: para matrizes não comutativas isso de ~k*a cai por terra.
					preciso testar com matrizes com pequenos números fora das diagonais também, para ver o cenário amplo.
			
[ ] Livro de Receitas:
	[?] Ao criar uma poção desconhecida ele pede para dar o nome. O nome vai para a receita e para a poção criada, e fica armazenada, se o jogador criar outra semelhante o nome já virá automaticamente.
		[?] Já funciona: sai como "Poção desconhecida" e o nome é dado no livro (ao passar o rascunho a limpo); 
		vai para a receita, o item e o catálogo do jogador (salvo), e as próximas parecidas já vêm com o nome.
		TESTAR: fazer uma poção desconhecida e:
			[ ] dar nome
			[ ] não dar nome
			[ ] dar nome só depois
			[ ] tentar editar poção depois
	[ ] Receitas:
		[?] Nome: poção de um item só agora usa "Poção de [item] [qualidade]" antes de procurar no catálogo (senão um pó mal cozido virava "Concentrada").
		[ ] Balanceamento de Receitas:
			[.] Criar mais receitas:
				Receita que é muito rápida , 
				receita que é muito demorada. 
				Receita muito quente, com fogo negro. 
				Receita muito fria, quase desligando. 
			[ ] Perguntas: 
				[ ] Dois pontos de cozimento diferentes para o mesmo item podem gerar poções diferentes? 
				[ ] Faz sentido uma receita que leva o mesmo ingrediente 2x em tempos diferentes? I_tempo, I_Temper, Q, como conseguir aprovetar duas vezes um mesmo tipo de item numa mesma receita?
				[ ] E se eu dobrar a poção? Testar com as não comutativas: Fazer receita dobrada tem efeito de potencializar (escalar) a matriz resultante. por exemplo se fizer uma poção da calma profunda dobrada, 
				[ ] dificuldade, medir peso de cada erro: tempo, temp, cozimento, 
				[ ] explorar os TIPOS de matrizes. explorar o que é posível nesse sistema térmico
					[?] Diagonalizáveis com autovalores positivos: multiplicar sucessivamente só escala, cada uma no seu eixo (autovetores).
						M^t = P·D^t·P⁻¹ existe para qualquer t ≥ 0, então dá para "dobrar" (M²), meia dose (M^0,5) etc.
						Diagonal é o caso em que os eixos são os próprios traços; duas diagonais comutam (a ordem não importa).
					[?] Não diagonais (exemplo com 2 traços):
						Permutação (troca E↔N): M² = I, dobrar anula.
						Rotação de θ: M² gira 2θ, dobrar gira mais (não fortalece).
						Cisalhamento (um traço soma no outro, [[1,0],[c,1]]): M^n soma n·c, cresce em linha reta.
						Projeção (zera um traço): M² = M, dobrar não muda nada.
						Mistura de poções: A·B ≠ B·A, a ordem muda o resultado.
						Cada família de poção tem a sua "lei da dose" (pode virar mecânica).
					[ ] Problema do zero: traço zerado não muda com diagonal (0·λ = 0). Ideias:
						Cisalhamento pequeno nos ingredientes: ~1% fora da diagonal, talvez aleatório (normal em [−0,01; 0,01]).
						Matriz 6×6 homogênea [A b; 0 1]: p' = A·p + b (empurrão fixo), sem sair do sistema de matrizes.
					    Evitar o zero: garantir um |valor| mínimo (os personagens já usam ±0,5 a ±1,5 no lugar de 0).
					    A pensar: qual é o mais geral e o mais legal de jogar.
					[?] Teste no balanceamento.py (botão "Cisalhamento ±1%"; o jogo não muda): ruído fixo por item, normal σ 0,005 cortado em ±0,01.
					    Com o catálogo puro as 3 receitas deixam de ganhar o nome (o ruído soma: Calma chega a 10% fora da diagonal).
					    Com o catálogo seguindo o ruído (poção ideal = receita perfeita com ruído) tudo passa de novo, e as poções continuam distintas.
					    Zero: personalidade (5,5,5,5,0) depois de uma receita: N vira −0,05 (Calma), −0,07 (Desenvoltura), +0,18 (Retorno). Funciona, mas fraco.
					    A compensação (muitos mal cozidos = poucos bons) continua igual com o ruído.
					    Níveis testados (N de 0 depois de uma poção, outros traços 5): ±1% −0,05 a +0,18; ±2% −0,14 a +0,35; ±4% −0,34 a +0,68 (Calma com 39% fora da diagonal). Padrão no balanceamento: ±1%.
					[ ] 6×6 homogênea (pensando em manter 6×6 na operação e mostrar só 5×5; ainda não aplicar):
						p = (O, C, E, A, N, 1), M = [A b; 0 1], p' = A·p + b (b = empurrão fixo).
						Ganha: resolve o zero (b soma sempre), poções de "puxar para um alvo", continua tudo matriz (composição, ordem, potência).
						Muda: dose dobrada vira "escala e desloca" (M² soma b + A·b); diagonais com b deixam de comutar; cada poção tem ponto fixo p* = (I − A)⁻¹·b.
						Ingredientes: I + a·(M − I) vale igual, mal cozido também encolhe o empurrão.
						Código: 5×5 → 6×6 em ItemData.A, .tres, calculadora, catálogo, balanceamento, pentagrama (compatível: b vazio = 0).
						Puxar para o alvo: p' = p + t·(alvo − p) = (1 − t)·p + t·alvo → M = [(1 − t)·I  t·alvo; 0 1]. t
						 = intensidade (0 a 100%), pode ser um t por traço (t = 0 não puxa).
					        n doses: p_n = alvo + (1 − t)ⁿ·(p − alvo): chega perto, nunca passa. Ponto fixo = o alvo. Resolve o zero. Mal cozido = t·a.
						Transformação projetiva (última linha da 6×6 diferente de (0 … 0 1)): p' = (A·p + b) / (cᵀ·p + d).
							A divisão cria saturação: o traço sobe e "freia" perto de um limite. Jeito de modelar a borda sem o corte em ±10
							(a borda também é parte do problema a modelar).
							RESPONDER: como modelo matematicamente a borda? quando acontece de ser projetivo tenho que ficar ajustando o vetor para sempre a ultima coordnada ser 1?
							[?] Botão para testar (debug, aba Poções, "Borda da personalidade"): corte / projetiva / tanh (CmdAplicarPocao.calcular).
								Projetiva e tanh fazem a conta num valor interno u e voltam para −10..10 (projetiva: p = u/(1+|u|/10); tanh: p = 10·tanh(u/10)).
								Ex.: E = 5 com ×1,4 três vezes: corte 7 → 9,8 → 10; projetiva 5,8 → 6,6 → 7,3; tanh 6,5 → 7,9 → 9,1. A identidade não muda nada nos três.
							[?] Teste: poção que troca O e C (permutação) com 2 ingredientes: 1 "espelho" (C → −C) e depois 6 "giros" de 15° no plano O-C.
								Precisa de um ingrediente drástico (o espelho): ingredientes perto da identidade nunca invertem (o determinante não troca de sinal).
								Ordem importa: giros antes do espelho dão outra matriz (troca com sinal: O → −C, C → −O).
								Compensação quebra em parte: 8 giros a 0,75 acertam o ângulo, mas encolhem (0,95); 24 a 0,25 encolhem para 0,86. Espelho mal cozido (a 0,5) zera o C.
								Dobrar a poção (P²) volta ao original.
								Outros jeitos (3 ingredientes, testados, os dois dão a troca exata):
									Espelho girado: 3 giros de −15°, 1 espelho, 3 giros de +15° (espelhar na diagonal O = C).
										Ordem trocada (começar pelo +15°) dá a troca com sinal. Mal cozido: os giros encolhem (4 a 0,75: dist. 0,07).
									Três cisalhamentos: "soma C em O" (O + C), "C vira O − C" (o drástico, inverte), "tira C de O" (O − C).
										O 1º e o 3º podem vir em pedaços (ex.: 4 de 25%); entre si só somam, então a compensação é exata (6 a 0,67 ou 8 a 0,5: dist. 0,000).
										O do meio é o ponto sensível (a 0,9 já erra 0,2).
									Sempre precisa de um ingrediente drástico (que inverte). O jeito escolhido muda a dificuldade da receita, mesmo com o mesmo resultado.
					[ ] Mostrar o efeito da poção no pentagrama e nos traços (a parte 5×5 e o empurrão como seta/alvo): a pensar.
		[.] Ver tipos de poções e dar nomes: 
			Database (nomes das proibidas ficam para o Cap. 2): 
				Nomear as poções de referência no catálogo (PocaoReferencia: nome, descrição, A). 
				Poção da Calma Profunda. Poção #2. Poções proíbidas. 
				Poção #2 = Poção da Desenvoltura (definir bem antes do Cap. 1; só usada no Cap. X).
				Poções proibidas: as que têm algum autovalor 0 (2^5 − 1 = 31 combinações de traços zerados). Ainda sem nome. (feito: 31 no catálogo como "Poção Proibida (sem O, C...)", nomes provisórios)


[ ] Diálogos 100%
	[ ] Estilo visual: organizar o layout e textura dialogo/opções - borda, cor, fonte, etc.


[ ] História/Roteiro
	[ ] Revisar diálogos dos eventos/cenas:
		[.] Cap. 1 (-N)
			[?] intro-Campones
			[?] Guardas
			[ ] Bosque NPC
			[?] Cidade
				[ ] Casa 1, não tem nada. 
			[?] Castelo
				[ ] Casamento
				[ ] Fuga
					[ ] Com Retorno
					[ ] Sem Retorno
				[ ] Esperar
					[ ] Abriu porta -> Fuga
					>>> Enrolar -> dia nunca passa
				 
		[ ] Cap. 2
			>>> Usar traços na história: 
				O,(conservador com pouca abertura)
				C (consequencialidade, prudencia, preguiçoso),
				A (amabilidade, aumentar ou diminuir?)
			[ ] Qual traço? 
			[ ] Qual quest?
	[ ] Usar permutação de traços em alguma quest, receita, mas que seja visto esse efeito.
	[ ] Poções proibidas numa quest


[ ] Quests (tirar?)
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
		[ ] (ainda não tem nada fixo, mas pode ser um ser mágico que vive no bosque)

	[.] Mercador
		[ ] Inventário de cada, personalidade de cada?
		[ ] Comprar e Vender? 
			[?] 2 inventários e você pode trocar/negociar?
				[!] Feito (1ª versão, para testar): MenuLoja (src/ui/menu_loja.gd) + comando CmdLoja. 
				Dois inventários e uma mesa: tocar no item leva 1 para a mesa, tocar na mesa devolve. 
				Ouro é campo separado (−10 −1 +1 +10). 
				Valor para o mercador = valor_base · qtd_base / (qtd_base + qtd que ele tem) (ItemData, grupo Comércio; padrão 10 e 5). 
				Ele aceita se receber ≥ (1 + margem) · o que dá (margem por loja no comando). 
				Estoque e ouro dele ficam salvos (variável loja_<id>). 
				layout: Balança (a mesa pende para o lado que vale mais, valor real sem a margem) 
				negociação: Pechincha (se faltar, ele pede mais ouro; 3 recusas e desiste por hoje). 
				

[ ] Personagens
	[ ] Fazer uma ficha de personagem, script de programa/ferramenta pra editar o database no geral?
		[?] Feito: ferramenta central (ferramentas/central/central.py ou abrir_central.bat): uma janela com abas
		Personalidades (tabela OCEAN, "no banco", nova, prévia de poção/item com doses), Itens (campos + matriz A),
		Catálogo (poções + matriz A), Eventos (o editor de eventos) e Balanceamento. Cada aba carrega só quando abre;
		salvar grava só o que mudou. As ferramentas antigas continuam funcionando sozinhas. Ver ferramentas/central/README.md.
		[?] Reformulada: Personalidades com a lista "depois da poção" ao lado (▲/▼ e cores), Itens com "Novo item", Catálogo com proibidas no fim,
		efeito na personalidade e comandos do efeito, Eventos e Balanceamento próprios (usam o motor das ferramentas antigas, sem matplotlib).
		Organização: nucleo/ (peças comuns) + abas/ (uma por arquivo). Pode apagar ferramentas/central/abas/balanceamento_aba.py (não é mais usado).
		Personalidades definidas: camponês C −3; rei O −6, C −4, A 2; bruxa 6, −1, −1, 1, 3.
		[?] Ajustes: Personalidades com os 5 traços antes juntos e depois os 5 modificados (sem Σ|Δ|); Balanceamento com chama e item escolhidos em lista (a chama com a cor dela), jogadora perfeita / calibrada / ruim, aba Chamas e aba "Chama × tempo" (segundos de um ingrediente × cor da chama antes dele, poção e só aquele ingrediente); Itens com a curva de aproveitamento por cor da chama.
		Jogadora ruim (reação 0,5 s, chama ±12%, folga 5 °C, tempo ±6 s e 2 s atrasada): calma_profunda dá 0% (não segura a chama, estoura 600 s), desenvoltura 94%, retorno 93%. REVISAR se é ruim demais.
		[?] Novas abas na central: Receitas, Falas, Flags, Onde é usado, Mapas, Mercadores, Chamas, Calibração, Verificação e Projeto (git só leitura). Falas/Flags/Onde é usado/Mapas/Verificação só leem e o duplo clique abre o evento na aba Eventos. Ver ferramentas/central/README.md.
		A Verificação achou: pegou_maca usada sem estar em dados/variaveis; missao01_convite ninguém testa; reputacao ninguém usa; cidadeA_in01_maca, cidadeA_in03_vazia, pensamento_inicio e pensamento_fim não estão em mapa nenhum e ninguém chama. REVISAR.
	[?] Criar personalidades big five pra cada personagem
		[?] Feito (só as novas, escala + = 4, ++ = 7, − = −4, sem sinal = 0): dados/personalidades/ 
		mercador (A+), padre (O− C++ A+), 
		morador = NPC adulto (O−), 
		menina = NPC criança 1 (O++), 
		menino = NPC criança 2 (O++ A+). 
		Registradas em dados/banco.tres. 
		Onde era 0 ficou um valor aleatório em [−1,5; −0,5] ∪ [0,5; 1,5]. 
		As antigas não mudaram; camponês, guarda_ponte e guarda_estradaB agora também estão registradas no banco.
		REVISAR: ver se as personalidades estão ok e remover tópico.
	[ ] Cada personagem tem seu linguajar próprio e manias.
		[ ] Bruxa
		[ ] Campones N+ C-
		[ ] Guarda1 C- A+
		[ ] Guarda2 C+
		[ ] bosque_npc
		[ ] Cidade
			[ ] NPC Adulto O- 
			[ ] NPC Criança 1 O++ 
			[ ] NPC Criança 2 O++ A+
			[ ] Casa 1
				[ ] NPC 
			[ ] Casa 2
				[ ] Mercador Pai A+
				[ ] Mercador Filho E--
			[ ] Igreja
				[ ] Padre O- C++ A+
		[ ] Castelo
			[ ] Rei O- C- A+
			[ ] Princesa N++ A+ O+

[ ] Documentação e Organização
	[ ] organização da pasta Graphics(está sendo chamada de assets neste projeto) estilo rpgmaker:
		Animations (efeitos especiais, magias, etc)
		Characters (assets/eventos)
		Icons assets/icones
		Panoramas (imagens para cenário) ?
		Pictures (sprites para controlar na tela) ?
		Transitions ?
		Windowskins (janelas, etc) assets/ui
	[ ] Debug e ferramentas
	

[ ] Aplicar poção:
	[.] A ação da poção deve mostrar a personalidade mudando.
		Ideia: um pequeno menu com a face da pessoa e a personalidade dela mudando; a personalidade fica na carta Status. Layout ainda a definir.
		[?] Feito (1ª versão): MenuAplicarPocao (src/ui/menu_aplicar_pocao.gd). Abre junto com o inventário no "Aplicar poção": nome e face do alvo (dados/falantes/<personalidade>.tres, ou o campo "personagem" do comando) e o pentagrama O C E A N com a personalidade dele (só a forma, −10 a 10). Tocar numa poção mostra a prévia tracejada; aplicar anima a forma (setinhas ↑↓ removidas; as pontas que mudaram ainda pulsam); depois fecha. Fica sobre a carta Status, com a face e o nome numa carta logo acima (os outros jeitos e a tecla M saíram).
		[?] Escala da mudança: agora o pentagrama usa o valor real (−10 a 10) na prévia e ao aplicar, sem raiz. Mudanças pequenas ficam quase imperceptíveis. Contorno cinza = como estava.
	[ ] Representação de poções visual com matriz/grafo. (feito, versão simples: no pentágono cada ponta sai do traço que mais contribui e gira até a sua; diagonal = só escala com um pulo)
		[ ] (Cap. 2) Mostrar o pentagrama, cada aresta representa um componente. Pensei em relacionar as arestas com a_ij e criar um feedback útil visualmente.
		[ ] (Cap. 2) O pentagrama deve ter animações a depender da matriz. Por exemplo, matriz diagonal (ou próxima de diagonal a menos de ruído) só escala, então a animação do pentagram é escalar. Matriz que troca dois componentes deve trocar duas pontas do pentagrama suavemente, como uma permutação ou rotação.

```

## Possíveis expansões (futuras)

```
[ ] Sistema de clima
[ ]	Sistema de fama
[ ]	Sistema de compra/venda
[ ]	Sistema de mercado/valor dinâmico

```
