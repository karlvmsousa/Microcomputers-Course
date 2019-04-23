;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
;*        Título: Controle de iluminação e temperatura em Discoteca (Trabalho 2)			           *
;* 																									   *
;* 		Disciplina: Microcomputadores				Semestre: 2017.1								   *
;* 		Professor:	Mauro Rodrigues dos Santos														   *                              
;*		                                                         								 	   *
;*      Desenvolvido por:											                                   *
;*   	=> 	Guilherme de Souza Bastos                                                                  *
;*   	=> 	Karl Vandesman de Matos Sousa															   *
;*										   									                           *
;*      VERSÃO: 2.0                            		DATA:02/06/2017                                    *
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
;*                                     DESCRIÇÃO DO ARQUIVO                                            *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

; Este projeto trata do controle de iluminação e temperatura interna de uma discoteca, integrando o salão 
; e o bar, de forma a economizar energia. O sistema será composto de um sensor de temperatura LM35, um  
; conjunto de ventiladores, perando por PWM e quatro ar-condicionados. A luminosidade será controlada com 
; um LDR e quatro conjuntos de luminárias. Há também um sensor de presença, e caso seja detectado que não
; há ninguém no ambiente, todas as saídas são desativadas.
	
;				* * * * * * * * * * * * * * * * * * * * * 
;				* Parâmetros no Controle de Temperatura *
;				* * * * * * * * * * * * * * * * * * * * *
;_Faixa de temperatura__|___ventiladores_(PWM)__|___Ar1_|___Ar2	|___Ar3_|___Ar4___                                           
; 		<=20ºC			|		10% Pmax		|  DESL	|  DESL	|  DESL	|	DESL
; 	>20ºC a <=25ºC		|		30% Pmax		|	LIG	|  DESL |  DESL |	DESL
; 	>25ºC a <=30ºC		|		75% Pmax		| 	LIG	|	LIG |  DESL	|	DESL
;		>30ºC			|		90% Pmax		|	LIG	|	LIG	|	LIG	|	LIG                                           
                                                                               
;			* * * * * * * * * * * * * * * * * * * * * 
;			* Parâmetros no Controle de Luminosidade*
;			* * * * * * * * * * * * * * * * * * * * *
;___Luz ambiente____|___Lum1____|___Lum2____|___Lum3____|___Lum4____
;	   Claro		|	desl	|	desl	|	desl	|	desl
;	   Sombra		|	lig		|	desl	|	lig		|	desl
;	   Escuro		|	lig		|	lig		|	lig		|	lig
                                                          
; Nesta versão 2.0, serão utilizadas interrupções do Timer 0, do Conversor A/D, interrupção externa
; de RB0 (sensor de presença)                                                          
                                                                                                                                  
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
;*                     ARQUIVOS DE DEFINIÇÕES E CONFIGURAÇÕES                                          *            
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 

	#INCLUDE <P16F877A.INC>		;Arquivo padrão da Microchip para o PIC16F877A
	RADIX		DEC				;Define o Decimal como forma padrão ("default" do programa)
								;não sendo necessário expressar o número como .XX

	__CONFIG _BOREN_ON & _CP_OFF & _PWRTE_ON & _WDT_OFF & _LVP_OFF	;Brown-out reset habilitado (proteção contra alimentação fraca)
																	;Proteção de código desabilitado
																	;Power-up Timer Enable hablitado
																	;Watchdog timer desabilitado
																	;Programação de baixa voltagem desabilitado
																
	#DEFINE	BANK0	BCF STATUS, RP0	;Definição de comandos para alteração	
	#DEFINE	BANK1	BSF STATUS, RP0	;da página de memória de dados

	#DEFINE ZERO  		STATUS,Z				;Flag Z do registrador STATUS

	#DEFINE	FLAG_TMR0		INTCON,	T0IF		;Flag que sinaliza estouro do Timer 0
	#DEFINE	FLAG_PRESENCA	INTCON, INTF		;Flag que sinaliza interrupção externa
	#DEFINE FLAG_CONV		PIR1, ADIF			;Flag que sinaliza fim da conversão A/D

	#DEFINE	HAB_GERAL		INTCON, GIE			;Habilita as interrupções (é necessária ainda a habilitação individual 
												;de cada interrupção)
	#DEFINE	HAB_TMR0		INTCON, T0IE		;Habilita a interrupção do Timer 0
	#DEFINE	HAB_PRESENCA	INTCON, INTE		;Habilita a interrupção do botão preparar (RB0)
	#DEFINE	HAB_CONV		PIE1, ADIE			;Habilita a interrupção do conversor A/D

	#DEFINE	DELAY_OK	REG_DELAY, 0			;Determinar esse bit para avisar que houve o tempo de delay

	#DEFINE LIGA_CONV	ADCON0, 2	    ;Bit que controla o início/fim da conversão
	#DEFINE PWM			CCPR1L	        ;Variável comprimento do pulso do PWM
	#DEFINE CARRY		STATUS, C       ;Flag que indica carry out
	#DEFINE	SEL_CANAL	ADCON0, 3		;Os bits 3 a 5 de ADCON0 são responsáveis por seleção 
										;do canal analógico que será convertido no Conversor A/D
										;Como estão sendo usadas apenas 2 portas analógicas, será
										;modificado apenas o bit 3 para seleção do canal
	#DEFINE RESULT_CONV	ADRESL		    ;Variável que guarda parte da conversão (parte baixa, 8 bits)

;*************************************************** 
;*       			 VARIÁVEIS                     *                   
;*************************************************** 
;Definição do bloco de variáveis 
	CBLOCK 0x20				;Endereço inicial da memória do usuário						
		N					;Quantidade de bebidas que ainda podem ser feitas
		W_TEMP				;Variável para salvar contexto de W
		STATUS_TEMP			;Variável para salvar contexto de STATUS
		REG_DELAY			;Variável que será utilizada com a interrupção do timer0
		
		TEMPERATURA_VAR		;Variável para armazenar o resultado da conversão A/D do sensor de temperatura
		LUMINOSIDADE_VAR	;Variável para armazenar o resultado da conversão A/D do sensor de luminosidade

		AUX_TEMP			;Utilizada para o pequeno delay na casa dos microssegundos	
	ENDC				    ;Fim do bloco de variáveis

;*************************************************** 
;*      		     CONSTANTES                    *                   
;*************************************************** 
;Definição de constantes utilizadas no programa
TA			EQU		250		;Delay de (255-Ta)/10 segundos (Com clock externo de 10Hz)
							;Delay=20s, intervalo de medição dos sensores
							
TEMP_20		EQU		41		;Número digital equivalente a 20ºC (1023 -> 5V, 0-> 0V)	
TEMP_25		EQU		52		;Número digital equivalente a 25ºC (1023 -> 5V, 0-> 0V)	
TEMP_30		EQU		62		;Número digital equivalente a 30ºC (1023 -> 5V, 0-> 0V)	

NIVEL_LUZ_1	EQU		45			;Número digital equivalente a 50 Lux
NIVEL_LUZ_2	EQU		156 		;Número digital equivalente a 250 Lux
;*************************************************** 
;*      			  ENTRADAS                     *                   
;*************************************************** 
; Definição de todos os pinos que serão utilizados como entrada
	#DEFINE		LUMINOSIDADE	PORTA, RA0	;Sensor de Luminosidade com LDR (Entrada analógica)
	#DEFINE		TEMPERATURA		PORTA, RA1	;Sensor de temperatura com LM35 (Entrada analógica) 
	#DEFINE		OSC				PORTA, RA4	;Oscilador externo (necessidade de delay muito grande)

	#DEFINE		PRESENCA	 	PORTB, RB0 	;Sensor de presença, usado para economia de energia (desligar os dispositivos 
											;independente das leituras de luminosidade e temperatura)

;*************************************************** 
;*                     SAÍDAS                      *                   
;*************************************************** 
; Definição de todos os pinos que serão utilizados como saída

	#DEFINE 	LIGADO			PORTB, RB1		;Indica se a o MCU está ligado ou não
	
	#DEFINE		VENTILADOR		PORTC, RC2		;Saída PWM para ativamento do conjunto de ventiladores
	
	#DEFINE		AR1		PORTD, RD0		;Ar condicionado 1
	#DEFINE		AR2		PORTD, RD1		;Ar condicionado 2
	#DEFINE		AR3		PORTD, RD2		;Ar condicionado 3
	#DEFINE		AR4		PORTD, RD3		;Ar condicionado 4
	
	#DEFINE		LUM1	PORTD, RD4		;Luminária 1
	#DEFINE		LUM2	PORTD, RD5		;Luminária 2
	#DEFINE		LUM3	PORTD, RD6		;Luminária 3
	#DEFINE		LUM4	PORTD, RD7		;Luminária 4
		
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
	BTFSC	FLAG_PRESENCA	;Testa se ocorreu interrupção externa  por RB0 pelo sensor de presença
	GOTO	TRATA_PRESENCA 	;Se sim, trata essa interrupção
	
	BTFSC	FLAG_TMR0		;Testa se ocorreu interrupção do TMR0
	GOTO 	TRATA_TMR0		;Se sim, trata essa interrupção
	
	BTFSC	FLAG_CONV		;Testa se ocorreu interrupção do conversor A/D
	GOTO	TRATA_CONV		;Se sim, trata essa interrupção

	GOTO	SAI_INT			;Caso nenhum flag esteja ativado, sai da interrupção

TRATA_PRESENCA
	BCF		FLAG_PRESENCA	;Limpa o flag gerado pelo sensor de presença

	GOTO	SAI_INT			;Sai da interrupção
	
TRATA_TMR0
	BCF		FLAG_TMR0	;Limpa o flag de estouro do Timer0	
	BCF		HAB_TMR0	;Desabilita a interrupção do Timer0
	MOVLW 	TA			;Move o valor do delay (TA)
	MOVWF 	TMR0		;Move o valor de delay de TA para TMR0
	BSF		DELAY_OK	;Avisa que o tempo de delay já passou		
	GOTO	SAI_INT		;Sai interrupção

TRATA_CONV
	BCF		FLAG_CONV	;Limpar flag que sinaliza o fim da conversão a/d
	BTFSC	SEL_CANAL	;Verifica em qual canal analógico ele estava	
	GOTO	CONV_TEMPERATURA	;Se SEL_CANAL=1, está sendo convertido o valor de temperatura
	GOTO	CONV_LUMINOSIDADE	;Se SEL_CANAL=0, está sendo convertido o valor de luminosidade
	
CONV_TEMPERATURA
	BANK1					; Move para Bank1 pois será usado o registro ADRESL (RESULT_CONV), 
							; que está no Bank1
							
	MOVF   	RESULT_CONV, W  ; Resultado da conversão em W e,
	MOVWF	TEMPERATURA_VAR	; Transferido p/ variável temperatura
	BANK0
	
	GOTO	SAI_INT			;Sai da interrupção
	
CONV_LUMINOSIDADE
	BANK1					; Move para Bank1 pois será usado o registro ADRESL (RESULT_CONV), 
							; que está no Bank1
							
	MOVF   	RESULT_CONV, W  ; Resultado da conversão em W e,
	MOVWF	LUMINOSIDADE_VAR; Transferido p/ variável temperatura
	BANK0

	GOTO	SAI_INT			;Sai da interrupção
	
;****************************************************
;*			     SAÍDA DA INTERRUPÇÃO         		*
;****************************************************
SAI_INT						;Antes de sair da interrupção é necessário retornar o contexto (recuperar os valores dos registros STATUS e W)
	SWAPF	STATUS_TEMP,W
	MOVWF	STATUS			;Move STATUS_TEMP para STATUS
	SWAPF	W_TEMP, F		;Resgata o valor de W a partir de W_TEMP
	SWAPF	W_TEMP, W		
	BSF		HAB_GERAL		
	RETFIE	

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                  DEFINIÇÃO DE ROTINAS E SUB-ROTINAS                     *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *

;*************************************************** 
;*        ROTINA DE LEITURA DE LUMINOSIDADE        *                   
;***************************************************
LER_LUMINOSIDADE
	BANK0
	BCF		SEL_CANAL		;Seleção do canal de multiplexação do conversor A/D
							;CHS2:CHS0 -> 3 bits responsáveis pela seleção do canal
							;001 -> Entrada analógica 0 (RA0)

	MOVLW	160				;Após mudança de canal, é necessário um tempo para adequação do capacitor
	CALL	DELAY_US		;do conversor AD (40us)

	BSF		LIGA_CONV	   	;Inicia conversão
	
	BTFSC 	LIGA_CONV	    ;Testa fim da conversão
	GOTO	$-1			    ;Se não terminou, volta a testar
	
	BANK0
	
	RETURN	

;*************************************************** 
;*         ROTINA DE LEITURA DE TEMPERATURA        *                   
;***************************************************
LER_TEMPERATURA
	BANK0

	BSF		SEL_CANAL		;Seleção do canal de multiplexação do conversor A/D
							;CHS2:CHS0 -> 3 bits responsáveis pela seleção do canal
							;001 -> Entrada analógica 1 (RA1)

	MOVLW	160				;Após mudança de canal, é necessário um tempo para adequação do capacitor
	CALL	DELAY_US		;do conversor AD (40us)
							
	BSF		LIGA_CONV	   	;Inicia conversão
	
	BTFSC 	LIGA_CONV	    ;Testa fim da conversão
	GOTO	$-1			    ;Se não terminou, volta a testar
	
	BANK0

	RETURN

;*************************************************** 
;*        ROTINA DE CONTROLE DA LUMINOSIDADE       *                   
;***************************************************
CONTROLE_LUMINOSIDADE	
							;Para o controle, é comparado o valor lido no sensor com constantes
	MOVLW	NIVEL_LUZ_1		;Move para o acumulador o primeiro valor de comparação de nível de luz
	
	BANK1
	SUBWF	LUMINOSIDADE_VAR, W	;Compara o valor lido da luminosidade com o primeiro nível de luz
	BTFSS	CARRY				;Verifica-se o carry da subtração
	GOTO	LUM_ESCURO			;Se o valor da luminosidade for menor que o primeiro nível, significa
								;que Luminosidade é menor que 50 Lux, logo ambiente está escuro
								
	MOVLW	NIVEL_LUZ_2			;Para verificar o próximo intervalo de luminosidade, é comparado com 
	SUBWF	LUMINOSIDADE_VAR, W	;o segundo nível de luminosidade (250 Lux)
	BTFSS	CARRY				
	GOTO	LUM_SOMBRA			;Se o valor do sensor for menor que 250 Lux e maior que 50 Lux, o ambiente está em sombra
	GOTO	LUM_CLARO			;Se for maior que 250 Lux, está claro

LUM_CLARO
	BANK0
	BCF		LUM1		;Com o ambiente claro, todas as luzes ficarão apagadas
	BCF		LUM2
	BCF		LUM3
	BCF		LUM4
	
	RETURN

LUM_SOMBRA
	BANK0
	BSF		LUM1		;Com o ambiente em sombra, 2 luminárias serão acesas
	BCF		LUM2
	BSF		LUM3
	BCF		LUM4

	RETURN

LUM_ESCURO
	BANK0	
	BSF		LUM1		;Com o ambiente escuro, todas as luminárias serão ligadas
	BSF		LUM2
	BSF		LUM3
	BSF		LUM4
	
	RETURN

;*************************************************** 
;*        ROTINA DE CONTROLE DA TEMPERATURA        *                   
;***************************************************	
CONTROLE_TEMPERATURA	
	MOVLW	TEMP_20
	BANK1
	SUBWF	TEMPERATURA_VAR, W	;Operação TEMPERATURA-20, resultado armazenado em W
	BTFSS	CARRY				;Verifica o carry, se temperatura<20ºC, utiliza a potência mínima dos ventiladores
	GOTO	POT_MINIMA			;e todos os ares-condicionados ficarão desligados
	
	MOVLW	TEMP_25
	SUBWF	TEMPERATURA_VAR, W	;Operação TEMPERATURA-25, resultado armazenado em W
	BTFSS	CARRY				;Verificado se a temperatura está entre 20ºC e 25ºC ou maior que 25ºC		
	GOTO	POT_BAIXA
	
	MOVLW	TEMP_30
	SUBWF	TEMPERATURA_VAR, W	;Operação TEMPERATURA-30, resultado armazenado em W
	BTFSS	CARRY
	GOTO	POT_ALTA			;Se a temperatura estiver entre 25ºC e 30ºC, aciona potência alta
	GOTO	POT_MAXIMA			;Se a temperatura estiver maior que 30ºC, aciona a potência máxima
	
POT_MINIMA				;Se a temperatura está menor que 20ºC:
;*--- Controle da potência do conjunto de ventiladores ---*
	BANK0
	MOVLW	26					;Potência de 10% no conjunto de ventiladores
	MOVWF	PWM
;*--- Controle dos ares-condicionados ---*
	BCF		AR1					;Todos os ares-condicionados estão desligados
	BCF		AR2					
	BCF		AR3
	BCF		AR4

	RETURN						; os outros 4 bits (MSB) de PORTD

POT_BAIXA				;Se a temperatura está entre 20ºC e 25ºC:
;*--- Controle da potência do conjunto de ventiladores ---*
	BANK0
	MOVLW	77					;Potência de 30% no conjunto de ventiladores
	MOVWF	PWM
;*--- Controle dos ares-condicionados ---*	
	BSF		AR1					;O ar-condicionado 1 será ligado
	BCF		AR2
	BCF		AR3
	BCF		AR4
	
	RETURN
	
POT_ALTA				;Se a temperatura está entre 25ºC e 30ºC:
;*--- Controle da potência do conjunto de ventiladores ---*
	BANK0
	MOVLW	192					;Potência de 75% no conjunto de ventiladores
	MOVWF	PWM
;*--- Controle dos ares-condicionados ---*
	BSF		AR1					;Os ares-condicionado 1 e 2 serão acionados
	BSF		AR2
	BCF		AR3
	BCF		AR4
	RETURN

POT_MAXIMA				;Se a temperatura está maior que 30ºC:
;*--- Controle da potência do conjunto de ventiladores ---*
	BANK0
	MOVLW	230					;Potência de 90% no conjunto de ventiladores
	MOVWF	PWM
;*--- Controle dos ares-condicionados ---*
	BSF		AR1					;Todos os ares-condicionados serão ligados
	BSF		AR2
	BSF		AR3
	BSF		AR4

	RETURN

;*************************************************** 
;*       	     ROTINA DE DELAY (us)	           *                   
;***************************************************

DELAY_US			;Rotina implementada para o tempo de adequação do capacitor 
	BANK0			;na troca de canal 
	MOVWF	AUX_TEMP		;Carrega o valor inicial para AUX_TEMP
	
	DECFSZ	AUX_TEMP, F		;Decrementação da variável para o delay
	GOTO	$-1				;Após chegar em zero, sai da rotina de delay
	
	RETURN


;*************************************************** 
;*       	     ROTINA DE DELAY (ms)	           *                   
;***************************************************

						;Rotina de geração de delay a partir do contador Timer0 que conta os ciclos de um oscilador externo
DELAY_TA
	BANK0
    CLRF    TMR0			;Limpa o registro do contador Timer0
 	BCF 	FLAG_TMR0		;Limpa o flag de estouro do Timer0
 	MOVLW	TA
	MOVWF 	TMR0			;Move o valor do acumulador para TMR0

	BTFSS 	DELAY_OK		;A contagem do delay terminou?
	GOTO 	$-1				;Caso não tenha terminado, volta pra instrução anterior
							;Aguardando até que TFLAG estoure (termine a contagem)
	RETURN					;Retorna o desvio de chamada

;*************************************************** 
;*       	  	 ROTINA DESATIVA TUDO		       *                   
;***************************************************
DESATIVA_TUDO
					;Quando o sensor de presença acusa que não há ninguém,
					;todas as saídas (ventilador, ares-condicionados e luminárias) são desativadas
	CLRF	PORTB
	CLRF	PORTC
	CLRF	PORTD
		
	BCF		LIGADO
		
	MOVLW	0
	MOVWF	PWM
		
	RETURN
	
;************************************************* 
;*          INICIALIZAÇÃO DAS VARIÁVEIS          *                   
;*************************************************
INIC_VAR					;Inicializa as variáveis
	CLRF	PORTA			;Zera PORTA A
	CLRF    PORTB			;Zera PORTA B
	CLRF	PORTC			;Zera PORTA C
	CLRF	PORTD			;Zera PORTA D
	
	CLRF	TEMPERATURA_VAR	;Zera o valor das variáveis 
	CLRF	LUMINOSIDADE_VAR	

	RETURN

;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;*                     INÍCIO DO PROGRAMA                                  *              
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;Configuração de operação do microcontrolador
INICIO
	BANK1					;Altera para o Banco 1 da memória de dados
	MOVLW	B'00011011'		;Configura PORTA como entrada ou saída
	MOVWF	TRISA			;IN: RA0, RA1, RA4.	OUT: RA2, RA3, RA5, RA6, RA7
		
	MOVLW	B'00000001'		;Configura PORTB como entrada ou saída
	MOVWF	TRISB			;IN: RB0.	OUT: RB1, RB2, RB3, RB4, RB5, RB6, RB7							

	MOVLW	B'00000000'		;Configura PORTB como entrada ou saída
	MOVWF	TRISC			;OUT: RC0, RC1, RC2, RC3, RC4, RC5, RC6, RC7	

	MOVLW	B'00000000'
	MOVWF	TRISD			;OUT: RD0, RD1, RD2, RD3, RD4, RD5, RD6, RD7	
	
	MOVLW	B'11101000'		;OPTION_REG: RBPU|INTEDG|T0CS|T0SE|PSA|PS2|PS1|PS0
	MOVWF	OPTION_REG 		;habilita pull-ups portb|fonte de clock será RA4/T0CKI|sem prescaler pra TMR0|0|0|0
	

	MOVLW	B'11110000'		;Habilita a interrupção global, de periféricos, do Timer0, e interrupção externa de RB0
	MOVWF	INTCON

	MOVLW	B'01000000'		;Habilita a interrupção do conversor A/D
	MOVWF	PIE1
	
	MOVLW	B'10000101'		;Seleciona RA0 e RA1 como portas analógicas
	MOVWF	ADCON1			;bit 7 (ADFM): A/D Result format select bit: 1 = Right justified. Six (6) Most Significant bits of ADRESH are read as ‘0’.
							;bit 6 (ADCS2): A/D Conversion Clock Select bit 	
							;Bits 3-0: Configuração das portas como analógico ou digital
							;		   0101 -> AN0 e AN1 definidas como portas analógicas, o restante, digital. AN3-> Vref+
	BANK0					;Altera para o Banco 0 da memória de dados
	
	BSF		T2CON, TMR2ON	;Ativa o TMR2 que é a base de tempo do sinal gerada para o PWM

	MOVLW	B'11000001' 	;Ajuste das configurações do conversor A/D
	MOVWF	ADCON0			;Bits 7-6 -> Seleção do clock RC interno para conversão
							;Bits 5-3 -> Seleção do canal que será usado para conversão A/D
							;Bit 2 -> Status da conversão 
							
	MOVLW	B'00001100'		;Configuração do módulo CCP1
	MOVWF	CCP1CON			;Bit 3-0: CCPxM3:CCPxM0: CCPx Mode Select bits -> 11xx = Modo PWM

	CALL	INIC_VAR		;Coloca os valores iniciais das variáveis

;************************************************* 
;*               ROTINA PRINCIPAL                *                   
;*************************************************
MAIN_LOOP
	BTFSC	PRESENCA			;Testa se o sensor de presença está ativado 
	GOTO	INICIO_CONTROLE		;Se tiver, começa o início da leitura dos sensores e controle

	CALL	DESATIVA_TUDO		;Se não tiver, desativa todas as saídas		
	SLEEP						; O MCU estará em Sleep, até que o sensor de presença
	NOP							; verifique que há alguém no ambiente						
									
INICIO_CONTROLE
	BSF		LIGADO					;Aciona o LED avisando que o sistema está ligado

	CALL	LER_TEMPERATURA			;Faz a leitura do sensor de temperatura
	CALL	CONTROLE_TEMPERATURA	;A partir da leitura, realiza o controle de temperatura
									;Fazendo controle do acionamento do conjunto de ventiladores 
									;e ares-condicionados
									
	CALL	LER_LUMINOSIDADE		;Faz a leitura do sensor de luminosidade
	CALL	CONTROLE_LUMINOSIDADE	;A partir da leitura, realiza o controle de temperatura
									;Fazendo controle do acionamento das luminárias
									
	CALL	DELAY_TA				;Depois de lidos os sensores, espera-se um tempo para a nova medição
									;já que as variáveis mudam lentamente
	GOTO	MAIN_LOOP

;XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
;X                FIM DO PROGRAMA                X                   
;XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
	END