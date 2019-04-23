;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
;*        Título: Máquina preparadora de Cuba Libre (Exercício 1)		     				           *
;* 																									   *
;* 		Disciplina: Microcomputadores				Semestre: 2017.1								   *
;* 		Professor:	Mauro Rodrigues dos Santos														   *                              
;*		                                                         								 	   *
;*      Desenvolvido por:											                                   *
;*   	=> 	Guilherme de Souza Bastos                                                                  *
;*   	=> 	Karl Vandesman de Matos Sousa															   *
;*										   									                           *
;*      VERSÃO: 2.0                            		DATA:08/05/2017                                    *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
;*                                     DESCRIÇÃO DO ARQUIVO                                            *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

; Projeto de um sistema utilizando o PIC16F628A para controle automático de quatro máquinas para fazer
; uma bebida chamada Cuba Libre, feita com uma dose de rum, quatro cubos de gelo, uma fatia de limão e
; 250ml de Coca-Cola. As máquinas realizam as seguintes atividades:
;                 
; 	- A máquina M1 fornece uma dose de rum toda vez que for ativada;                      
;   - A máquina M2 fornece um cubo de gelo toda vez que for ativada;
;	- A máquina M3 fornece uma fatia de limão toda vez que for ativada;
;	- A máquina M4, quando ativada, fornece Coca-Cola e após escoar 250ml gera um sinal de saída S=1,
;	  sinalizando o fim da preparação da bebida.
;
; As máquinas são acionadas a partir de um pulso de Ta segundos. 
; As máquinas devem ser reabastecidas após a preparação de N Cubas Libres (capacidade de abastecimento)
; e para isso, é necessário o acionamento informando que a máquina foi reabastecida.
                                                                                                                                    
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
;*                     ARQUIVOS DE DEFINIÇÕES E CONFIGURAÇÕES                                          *            
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

	#INCLUDE <P16F628A.INC>		;Arquivo padrão da Microchip para o PIC16F628A
	RADIX		DEC				;Define o Decimal como forma padrão ("default" do programa)
								;não sendo necessário expressar o número como .XX

	__CONFIG _BOREN_ON & _CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF & _MCLRE_ON ;Brown-out reset habilitado (proteção contra alimentação fraca)
																				;Proteção de código desabilitado
																				;Power-up Timer Enable hablitado
																				;Watchdog timer desabilitado
																				;Programação de baixa voltagem desabilitado
																				;Masterclear habilitado
	#DEFINE	BANK0	BCF STATUS, RP0	;Definição de comandos para alteração	
	#DEFINE	BANK1	BSF STATUS, RP0	;da página de memória de dados

	#DEFINE ZERO  		STATUS,Z			;Flag Z do registrador STATUS

	#DEFINE	T0_FLAG		INTCON,	T0IF		;Flag que sinaliza estouro do Timer
	#DEFINE	PREP_FLAG	INTCON, INTF		;Flag que sinaliza interrupção externa
	#DEFINE	PORTB_FLAG	INTCON, RBIF		;Flag que sinaliza alteração no pino RB6 ou RB7, 
											;avisando que a máquina M4 finalizou o trabalho

	#DEFINE	HAB_GERAL	INTCON, GIE			;Habilita as interrupções (é necessária ainda a habilitação individual 
											;de cada interrupção)
	#DEFINE HAB_RB		INTCON, RBIE		;Habilita as interrupções por mudança de estado das portas RB<4:7>
	#DEFINE	HAB_TMR0	INTCON, T0IE		;Habilita a interrupção do Timer 0
	#DEFINE	HAB_PREP	INTCON, INTE		;Habilita a interrupção do botão preparar (RB0)

	#DEFINE	DELAY_OK	REG_DELAY, 0		;Determinar esse bit para avisar que houve o tempo de delay


;*************************************************** 
;*       			 VARIÁVEIS                     *                   
;*************************************************** 
;Definição do bloco de variáveis 
	CBLOCK 0x20				;Endereço inicial da memória do usuário						
		AUX_PULSOS			;Variável auxiliar para contagem do número de pulsos para a máquina M2
		N					;Quantidade de bebidas que ainda podem ser feitas
		W_TEMP
		STATUS_TEMP
		REG_DELAY
	ENDC				    ;Fim do bloco de variáveis

;*************************************************** 
;*      		     CONSTANTES                    *                   
;*************************************************** 
;Definição de constantes utilizadas no programa

TA			EQU		246		;Delay de (255-Ta)/10 segundos (Com clock externo de 10Hz)
							;para ativação das máquinas M1, M2, M3 e M4
N_INIC		EQU		15		;Valor inicial da quantidade de Cuba libres que podem ser preparadas
;*************************************************** 
;*      			  ENTRADAS                     *                   
;*************************************************** 
; Definição de todos os pinos que serão utilizados como entrada

	#DEFINE		OSC			PORTA, RA4		;Oscilador externo (necessidade de delay muito grande)
	#DEFINE		PARTIDA 	PORTA, RA5  	;Botão de partida (ligamento da máquina e preparação das variáveis)
	#DEFINE 	PREPARAR	PORTB, RB0	 	;Botão para começar preparamento da bebida (Interrupção externa)
	#DEFINE		CARREGAR	PORTB, RB6		;Botão para o usuário reabastecer os materiais das máquinas (rum, gelo, etc.)
	#DEFINE		S			PORTB, RB7		;Sinal enviado por M4 avisando que já escoou 250ml de Coca-Cola

;*************************************************** 
;*                     SAÍDAS                      *                   
;*************************************************** 
; Definição de todos os pinos que serão utilizados como saída

	#DEFINE 	M1				PORTB, RB1		;Máquina 1 (fornece dose de rum)
	#DEFINE 	M2				PORTB, RB2		;Máquina 2 (fornece um cubo de gelo)
	#DEFINE 	M3				PORTB, RB3		;Máquina 3 (fornece uma fatia de limão)
	#DEFINE 	M4				PORTB, RB4		;Máquina 4 (fornece 250ml de Coca-Cola e envia sinal de saída S=1)
	#DEFINE		LED_CARREGAR	PORTB, RB5		;Sinaliza que não há material para realizaão da cuba libre, e é necessária a recarga	

	#DEFINE 	LED_PREPARANDO	PORTA, RA6		;Sinaliza que está em andamento a preparação da bebida
	#DEFINE 	LED_FIM			PORTA, RA7		;Sinaliza término do preparo da bebida
		
	#DEFINE 	D1				PORTA, RA0		;4 Segmentos para acionamento do Display de 7 segmentos, que
	#DEFINE 	D2				PORTA, RA1		;já possui decodificador interno
	#DEFINE 	D3				PORTA, RA2		; 
	#DEFINE 	D4				PORTA, RA3	

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                         VETOR DE RESET                                  *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

	ORG		0x00	    	;Endereço inicial de processamento
	GOTO	INICIO

;***************************************************
;*				INÍCIO DA INTERRUPÇÃO		       *
;***************************************************
	ORG		0x04		;Endereço inicial da interrupção
SALVA_CONTEXTO
	BCF		HAB_GERAL	;Desabilita interrupções gerais
	MOVWF	W_TEMP		;Copia W para a variável temporária W_TEMP
	SWAPF	STATUS,W	;Realiza a operação de SWAP em Status e armazena em W,
						;essa operação é feita para não afetar os flags da variável STATUS
	MOVWF	STATUS_TEMP	;Copia o registro W (STATUS "invertido" pelo SWAP) em STATUS_TEMP
	
;***************************************************
;*	   ROTINA DE ATENDIMENTO DAS INTERRUPÇÕES	   *
;***************************************************
VERIFICA_FLAGS				;Verificação dos Flags que podem ter gerado interrupção
	BTFSC	T0_FLAG			;Testa se ocorreu interrupção do TMR0
	GOTO 	TRATA_TMR0		;Se sim, trata essa interrupção
	BTFSC	PORTB_FLAG		;Testa a flag das interrupções geradas por PORTB (S e Carregar)
	GOTO	TRATA_PORTB		;Se sim, trata essa interrupção
	BTFSC	PREP_FLAG		;Testa se ocorreu interrupção por RB0 (Preparar) 
	GOTO	TRATA_PREPARAR	;Se sim, trata essa interrupção

	GOTO	SAI_INT			;Caso nenhum flag esteja ativado, sai da interrupção

TRATA_TMR0
	BCF		T0_FLAG		;Limpa o flag de estouro do Timer0	
	BCF		HAB_TMR0	;Desabilita a interrupção do Timer0
	MOVLW 	TA			;Move o valor do delay (TA)
	MOVWF 	TMR0		;Move o valor de delay de TA para TMR0
	BSF		DELAY_OK	;Avisa que o tempo de delay já passou		
	GOTO	SAI_INT		;Sai interrupção

TRATA_PREPARAR
	BCF		PREP_FLAG	;Limpa a flag de preparação
	BCF		HAB_PREP	;Desabilita a interrupção do Preparar
						;Agora é necessário verificar se há material para realização da Cuba Libre
	MOVF	N, W		;Move o valor de N para o acumulador W
	BTFSC	ZERO		;Caso o valor de N seja zero, o sinalizador Z estará setado
	GOTO	SAI_INT		;É sinalizado que não há materiais, e sai da interrupção

	BCF		LED_FIM			;Apaga o LED fim 
	BSF		LED_PREPARANDO	;Acende o LED preparando, avisando que a bebida está sendo feita
	
	GOTO	SAI_INT		;Depois de tratada, sai da interrupção

TRATA_PORTB			;Existem 2 pinos de entrada que podem gerar interrupção
					;por mudança de estado em PORTB: RB6 (Carregar) e
					;RB7 (S, que sinaliza termino da Máquina 4)

	BCF		PORTB_FLAG	;Limpa a flag por PORTB. 2 interrupções podem gerar flag dessa interrupção
	BTFSC	CARREGAR	;Testa se a interrupção foi Carregar
	GOTO	TRATA_CARREGAR ;Se sim, trata carregar
	BTFSC	S			;Testa se a interrupção foi S
	GOTO	TRATA_S		;Se sim, trata S
	GOTO	SAI_INT		;Caso não, sai da interrupção

TRATA_S
	BCF		PREP_FLAG
	BTFSS	M4				
	GOTO	SAI_INT	
	BCF		M4

	GOTO	SAI_INT

TRATA_CARREGAR
	MOVLW	N_INIC
	MOVWF	N	
	CALL	DISPLAY
	GOTO	SAI_INT

;****************************************************
;*			     SAÍDA DA INTERRUPÇÃO         		*
;****************************************************
SAI_INT						;Antes de sair da interrupção é necessário retornar o contexto (recuperar os valores dos registros STATUS e W)
	SWAPF	STATUS_TEMP,W
	MOVWF	STATUS			;Move STATUS_TEMP para STATUS
	SWAPF	W_TEMP, F	
	SWAPF	W_TEMP, W
	BSF		HAB_GERAL
	RETFIE	

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                  DEFINIÇÃO DE ROTINAS E SUB-ROTINAS                     *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

;*************************************************** 
;*ROTINA QUE SINALIZA DE ESVAZIAMENTO DAS MÁQUINAS *                   
;*************************************************** 
;Com N=0, é necessário o reabastecimento das máquinas
SINALIZA_CARREGAR
	BCF		LED_PREPARANDO		

	BSF		LED_CARREGAR
	CALL	AGUARDA_TMR0	
	BCF		LED_CARREGAR
	CALL	AGUARDA_TMR0
	BSF		LED_CARREGAR
	CALL	AGUARDA_TMR0
	BCF		LED_CARREGAR
	GOTO	AGUARDA_ACIONAMENTO

;*************************************************** 
;*        ROTINA DE ACIONAMENTO DE MÁQUINAS        *                   
;***************************************************
ACIONA_MAQ


	DECF	N, 1			;Decrementa 1 unidade na quantidade de cuba libres que podem ser feitas
	CALL	DISPLAY			;Apresenta o valor de N no display de 7 seg

	BSF		M1				;Aciona a Máquina M1
	CALL	AGUARDA_TMR0
	BCF		M1				;Para o acionamento de M1
	CALL	AGUARDA_TMR0		;Liga interrupção de TMR0 e espera para formar o pulso de acionamento

	MOVLW	4				;Atribuindo valor 4 para AUX_PULSOS
	MOVWF	AUX_PULSOS		;Para determinar 4 pulsos de acionamento para M2
	BSF		M2				;Aciona a Máquina M2
	CALL	AGUARDA_TMR0		;Liga interrupção de TMR0 e espera para formar o pulso de acionamento
	BCF		M2				;Para o acionamento de M2
	CALL	AGUARDA_TMR0		;Liga interrupção de TMR0 e espera para formar o pulso de acionamento
	DECFSZ	AUX_PULSOS		;Decrementa AUX_PULSOS e testa se é zero
	GOTO	$-5				;Caso AUX_PULSOS>0, volta 5 instruções onde se 
							;iniciou acionamento de M2
	BSF		M3				;Aciona a Máquina M3
	CALL	AGUARDA_TMR0		;Liga interrupção de TMR0 e espera para formar o pulso de acionamento
	BCF		M3				;Para o acionamento de M3
	CALL	AGUARDA_TMR0		;Liga interrupção de TMR0 e espera para formar o pulso de acionamento

	BSF		M4				;Aciona a Máquina M4
	
	RETURN	

;*************************************************** 
;*       	     ROTINA DE DELAY		           *                   
;***************************************************
						;Rotina de geração de delay a partir do contador Timer0 
AGUARDA_TMR0
	BCF		DELAY_OK		;Limpa-se o bit DELAY_OK, que é setado na interrupção de TMR0
	MOVLW	TA				;Valor inicial de TMR0 é atribuído
	MOVWF	TMR0
	BSF		HAB_TMR0		;É habilitado a interrupção de TMR0
DELAY_TA
	BTFSS 	DELAY_OK		;A contagem do delay terminou?
	GOTO 	$-1				;Caso não tenha terminado, volta pra instrução anterior
							;Aguardando até que TFLAG estoure (termine a contagem)
	RETURN					;Retorna o desvio de chamada

;*************************************************** 
;* ROTINA DE ACIONAMENTO DO DISPLAY DE 7 SEGMENTOS *                   
;***************************************************
DISPLAY
	MOVLW	B'11110000'			;Mantém os 4 MSB (pinos diversos) e limpa os LSB
	ANDWF	PORTA, 1			;Operação AND bit a bit entre W e PORTA
								;zera os 4 LSB (display)
	MOVF	N, W				;Move valor de N para o acumulador W
	IORWF	PORTA, 1			;Realiza operação OR entre W e PORTA,
								;e guarda resultado em PORTA, acionando
								;os 4 bits (LSB) do Display e mantendo inalterado
								;os outros 4 bits (MSB) de PORTA

	RETURN						;Retorno da rotina de chamada

;*************************************************** 
;*  DEFINE AS HABILITAÇÕES INICIAIS DE INTERRUPÇÃO *                   
;***************************************************

INICIA_INT
	BSF		HAB_GERAL		;Aqui são habilitadas as interrupções iniciais que serão consideradas,
	BSF		HAB_PREP		;assim, somente a interrupção por TMR0 é desabilitada
	BSF		HAB_RB
	BCF		HAB_TMR0
	RETURN

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                     INÍCIO DO PROGRAMA                                  *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;Configuração de operação do microcontrolador
INICIO
	BANK1					;Altera para o Banco 1 da memória de dados
	MOVLW	B'00110000'		;Configura PORTA como entrada ou saída
	MOVWF	TRISA			;IN: RA4, RA5.	OUT: RA0, RA1, RA2, RA3, RA6 RA7
		
	MOVLW	B'11000001'		;Configura PORTB como entrada ou saída
	MOVWF	TRISB			;IN: RB0, RB6, RB7.	OUT: RB1, RB2, RB3, RB4, RB5							
	
	MOVLW	B'11101000'		;OPTION_REG: RBPU|INTEDG|T0CS|T0SE|PSA|PS2|PS1|PS0
	MOVWF	OPTION_REG 		;habilita pull-ups portb|fonte de clock será RA4/T0CKI|sem prescaler pra TMR0|0|0|0

	MOVLW	B'00001000' 	;Utilizar cristal interno de 4MHz
	MOVWF	PCON

	MOVLW	B'10111000'		;Habilitar os bits de interrupções: geral (GIE), do timer 0 (TMR0),
	MOVWF	INTCON			;externa (INTE), e por mudança na porta B (RBIE).
	
	
	BANK0					;Altera para o Banco 0 da memória de dados

	MOVLW	B'00000111'
	MOVWF	CMCON			;Desativando as entradas analógicas

;************************************************* 
;*          INICIALIZAÇÃO DAS VARIÁVEIS          *                   
;*************************************************
INIC_VAR					;Inicializa as variáveis
	CLRF	PORTA			;Zera PORTA A
	CLRF    PORTB			;Zera PORTA B
	CLRF	AUX_PULSOS		;Zera Variável Auxiliar
	CLRF	W_TEMP			;Zera o W_TEMP
	CLRF	STATUS_TEMP		;Zera o STATUS_TEMP
	MOVLW	N_INIC			;Valor inicial da quantidade 	
	MOVWF	N				;de bebidas que podem ser preparadas
	CLRF	REG_DELAY

LIGAR					
	BTFSS	PARTIDA			;Testa o pino PARTIDA
	GOTO	$-1				;Aguarda PARTIDA=1 para entrar na rotina principal

;************************************************* 
;*               ROTINA PRINCIPAL                *                   
;*************************************************
MAIN_LOOP
	CALL	INICIA_INT
	CALL 	DISPLAY			;Aciona o Display com o valor de N

AGUARDA_ACIONAMENTO
	CALL	INICIA_INT
	SLEEP					;Aguarda interrupção ou Reset
	NOP						;Ao ocorrer interrupção (RB0, RB6 ou RB7), o sistema trata ela e volta pro Main_loop

	MOVF	N, W		;Move o valor de N para o acumulador W
	BTFSC	ZERO		;Caso o valor de N seja zero, o sinalizador Z estará setado
	GOTO	SINALIZA_CARREGAR	;E com N sendo zero, será sinalizado ao usuário que é necessário recarga
	
	BTFSS	PREPARAR			;Caso N>0, é verificado se o MCU saiu do SLEEP pela interrupção do Preparar
	GOTO	AGUARDA_ACIONAMENTO ;Caso outra interrupção tenha feito o MCU sair do sleep, ele volta novamente a rotina e entra em sleep

	CALL	ACIONA_MAQ			;Caso tenha saído da interrupção por preparar e N>0, começa o acionamento das máquinas

	BSF		HAB_RB				;Aqui é habilitado a interrupção por mudança de estado em RB (CARREGAR e S)
AGUARDA_S
	SLEEP					;Aguarda interrupção somente de S (todas as outras estão desabilitadas) 
	NOP
	BTFSS	S				;Quando se sai do sleep, depois do tratamento da interrupção, é verificado se foi pressionado S
	GOTO	AGUARDA_S		
							;Com a interrupção de S e devido tratamento, a bebida foi preparada e o 
							;sistema retorna ao ponto inicial

	BCF		LED_PREPARANDO		;Fim da preparação da bebida, LED PREPARANDO se apaga
	BSF		LED_FIM				;e LED FIM acende
	CALL	AGUARDA_TMR0
	GOTO	MAIN_LOOP		;Retorna para o começo da rotina MAIN_LOOP

;XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
;X                FIM DO PROGRAMA                X                   
;XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	END