;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
;*        Título: Máquina preparadora de Cuba Libre (Exercício 1)	     					           *
;* 																									   *
;* 		Disciplina: Microcomputadores				Semestre: 2017.1								   *
;* 		Professor:	Mauro Rodrigues dos Santos														   *                              
;*		                                                         								 	   *
;*      Desenvolvido por:											                                   *
;*   	=> 	Guilherme de Souza Bastos                                                                  *
;*   	=> 	Karl Vandesman de Matos Sousa															   *
;*										   									                           *
;*      VERSÃO: 1.0                            		DATA:22/04/2017                                    *
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
; As máquinas devem ser reabastecidas após a preparação de N Cubas Libres.
                                                                                                                                    
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

	#DEFINE	TFLAG	INTCON,	T0IF		;Flag que sinaliza estouro do Timer
;*************************************************** 
;*       			 VARIÁVEIS                     *                   
;*************************************************** 
;Definição do bloco de variáveis 
	CBLOCK 0x20				;Endereço inicial da memória do usuário						
		AUX_PULSOS			;Variável auxiliar para contagem do número de pulsos para a máquina M2
		N					;Quantidade de bebidas que ainda podem ser feitas
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

	#DEFINE		PARTIDA 	PORTA, RA5  	;Botão de partida (ligamento da máquina e preparação das variáveis)
	#DEFINE 	PREPARAR	PORTB, RB3	 	;Botão para começar preparamento da bebida
	#DEFINE		S			PORTB, RB0		;Sinal enviado por M4 avisando que já escoou 250ml de Coca-Cola
	#DEFINE		OSC			PORTA, RA4		;Oscilador externo (necessidade de delay muito grande)

;*************************************************** 
;*                     SAÍDAS                      *                   
;*************************************************** 
; DEFINIÇÃO DE TODOS OS PINOS QUE SERÃO UTILIZADOS COMO SAÍDA

	#DEFINE 	M1			PORTB, RB4		;Máquina 1 (fornece dose de rum)
	#DEFINE 	M2			PORTB, RB5		;Máquina 2 (fornece um cubo de gelo)
	#DEFINE 	M3			PORTB, RB6		;Máquina 3 (fornece uma fatia de limão)
	#DEFINE 	M4			PORTB, RB7		;Máquina 4 (fornece 250ml de Coca-Cola e envia sinal de saída S=1)
	
	#DEFINE 	PREPARANDO	PORTB, RB1		;Sinaliza que está em andamento a preparação da bebida
	#DEFINE 	FIM			PORTB, RB2		;Sinaliza término do preparo da bebida
		
	#DEFINE 	D1	PORTA, RA0				;4 Segmentos para acionamento do Display de 7 segmentos, que
	#DEFINE 	D2	PORTA, RA1				;já possui decodificador interno
	#DEFINE 	D3	PORTA, RA2			
	#DEFINE 	D4	PORTA, RA3	

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                         VETOR DE RESET                                  *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

	ORG		0x00	    	;Endereço inicial de processamento
	GOTO	INICIO

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                  DEFINIÇÃO DE ROTINAS E SUB-ROTINAS                     *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

;*************************************************** 
;*        ROTINA DE VERIFICAÇÃO DE MATERIAL        *                   
;*************************************************** 
VERIFICAR_MATERIAL
	MOVF	N, W		;Move o valor de N para o acumulador W
	BTFSC	STATUS, Z	;Caso o valor de N seja zero, o sinalizador Z será setado
	GOTO	$-2		
	RETURN				;Retorno da rotina de chamada

;*************************************************** 
;*        ROTINA DE ACIONAMENTO DE MÁQUINAS        *                   
;***************************************************
ACIONA_MAQ
	BSF		M1				;Aciona a Máquina M1
	CALL	DELAY_TA		;Chama delay para manter acionamento de M1
	BCF		M1				;Para o acionamento de M1
	CALL	DELAY_TA 		;Chama delay

	MOVLW	4				;Atribuindo valor 4 para AUX_PULSOS
	MOVWF	AUX_PULSOS		;Para determinar 4 pulsos de acionamento para M2
	BSF		M2				;Aciona a Máquina M2
	CALL	DELAY_TA		;Chama delay para manter acionamento de M2
	BCF		M2				;Para o acionamento de M2
	CALL	DELAY_TA		;Chama delay
	DECFSZ	AUX_PULSOS		;Decrementa AUX_PULSOS e testa se é zero
	GOTO	$-5				;Caso AUX_PULSOS>0, volta 5 instruções onde se 
							;iniciou acionamento de M2

	BSF		M3				;Aciona a Máquina M3	
	CALL	DELAY_TA		;Chama delay para manter acionamento de M3
	BCF		M3				;Para o acionamento de M3
	CALL	DELAY_TA		;Chama o delay

	BSF		M4				;Aciona a Máquina M4
	CALL	DELAY_TA		;Chama delay para manter acionamento de M4
	BTFSS	S				;Testa o sinal S da máquina 4 que sinaliza
	GOTO	$-1				;término do despejo de Coca-Cola
	BCF		M4
	RETURN					;Retorno da rotina de chamada	

;*************************************************** 
;*       	     ROTINA DE DELAY		           *                   
;***************************************************
DELAY_TA					;Rotina de geração de delay a partir do contador Timer0 
    CLRF    TMR0			;Limpa o registro do contador Timer0
 	BCF 	TFLAG			;Limpa o flag de estouro do Timer0
	MOVLW 	TA				;Move o valor do delay (TA)
	MOVWF 	TMR0			;Move o valor de delay de TA para TMR0

	BTFSS 	TFLAG			;A contagem do delay terminou?
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

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                     INÍCIO DO PROGRAMA                                  *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;Configuração de operação do microcontrolador
INICIO
	BANK1					;Altera para o Banco 1 da memória de dados
	MOVLW	B'00110000'		;Configura PORTA como entrada ou saída
	MOVWF	TRISA			;IN: RA4, RA5.	OUT: RA0, RA1, RA2, RA3, RA6 RA7
						
	MOVLW	B'00001001'		;Configura PORTB como entrada ou saída
	MOVWF	TRISB			;IN: RB0, RB3.	OUT: RB1, RB2, RB4, RB5, RB6, RB7							
	
	MOVLW	B'11101000'		;OPTION_REG: RBPU|INTEDG|T0CS|T0SE|PSA|PS2|PS1|PS0
	MOVWF	OPTION_REG 		;habilita pull-ups portb|fonte de clock será RA4/T0CKI|sem prescaler pra TMR0|0|0|0

	MOVLW	B'00001000' 	;Utilizar cristal interno de 4MHz
	MOVWF	PCON

	MOVLW	0				;Desabilitar todas as interrupções
	MOVWF	INTCON			
	
	BANK0					;Altera para o Banco 0 da memória de dados
	
	MOVLW	B'00000111'
	MOVWF	CMCON			;Desabilitar as entradas analógicas e colocar digitais

;************************************************* 
;*          INICIALIZAÇÃO DAS VARIÁVEIS          *                   
;*************************************************
INIC_VAR					;Inicializa as variáveis
	CLRF	PORTA			;Zera PORTA A
	CLRF    PORTB			;Zera PORTA B
	CLRF	AUX_PULSOS		;Zera Variável Auxiliar
	MOVLW	N_INIC			;Valor inicial da quantidade 	
	MOVWF	N				;de bebidas que podem ser preparadas

LIGAR					
	BTFSS	PARTIDA			;Testa o pino PARTIDA
	GOTO	$-1				;Aguarda PARTIDA=1 para entrar na rotina principal

;************************************************* 
;*               ROTINA PRINCIPAL                *                   
;*************************************************
MAIN_LOOP 
	CALL 	DISPLAY			;Aciona o Display com o valor de N
	CALL	VERIFICAR_MATERIAL	;Verifica se há material suficienta para 	
								;preparação da bebida
	BTFSS	PREPARAR		;Se PREPARAR for pressionado, a bebida começa a ser feita (ativo em 1)
	GOTO	$-1				;Aguarda PREPARAR=1 para preparar a bebida
	CALL	DELAY_TA	

	BCF		FIM				;Apaga LED FIM
	BSF		PREPARANDO		;Acende LED PREPARANDO
	DECF	N, 1			;Decrementa valor de N, e o destino é 1 (o próprio registro N) 
	CALL 	DISPLAY			;Aciona o Display com o valor de N
	CALL	DELAY_TA

	CALL	ACIONA_MAQ		;Chama rotina para acionamento das máquinas
	
	BCF		PREPARANDO		;Fim da preparação da bebida, LED PREPARANDO se apaga
	BSF		FIM				;e LED FIM acende
	CALL	DELAY_TA		;Chama Delay

	GOTO	MAIN_LOOP		;Retorna para o começo da rotina MAIN_LOOP

;XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
;X                FIM DO PROGRAMA                X                   
;XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	END