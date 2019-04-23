# Microcomputers-Course

Projects developed using PIC microcontrollers in the discipline of microcomputers in 2017.1 at UFPE (Universidade Federal de Pernambuco). Besides the Assembly code developed to run in PIC microcontrollers (PIC16F628A and PIC16F877A), we also used the software Proteus to design the schematics and run the simulations. I will provide in this repo the codes, the Proteus files and the reports about the development.

Obs.: Both projects have 2 versions, and the second one is a similar solution, but implemented with interruptions (as required by the professor).

Group:
- Guilherme de Souza Bastos
- Karl Vandesman de Matos Sousa

## Cubalibre Project
Projeto de um sistema utilizando o PIC16F628A para controle automático de quatro máquinas para fazer uma bebida chamada Cuba Libre, feita com uma dose de rum, quatro cubos de gelo, uma fatia de limão e 250ml de Coca-Cola. As máquinas realizam as seguintes atividades:
                
- A máquina M1 fornece uma dose de rum toda vez que for ativada;                      
- A máquina M2 fornece um cubo de gelo toda vez que for ativada;
- A máquina M3 fornece uma fatia de limão toda vez que for ativada;
- A máquina M4, quando ativada, fornece Coca-Cola e após escoar 250ml gera um sinal de saída S = 1, sinalizando o fim da preparação da bebida.
 
As máquinas são acionadas a partir de um pulso de Ta segundos. 
As máquinas devem ser reabastecidas após a preparação de N Cubas Libres (capacidade de abastecimento) e para isso, é necessário o acionamento informando que a máquina foi reabastecida.

**Solutions implemented on Proteus (versions 1 and 2, from left to right)**

<img src ="Cubalibre Project/Version 1/Cubalibre Project - Proteus Schematic v1.png" width = 400> <img src ="Cubalibre Project/Version 2/Cubalibre Project - Proteus Schematic v2.png" width = 455>

## Disco Project
Este projeto trata do controle de iluminação e temperatura interna de uma discoteca, integrando o salão e o bar, de forma a economizar energia. O sistema será composto de um sensor de temperatura LM35, um conjunto de ventiladores, perando por PWM e quatro ar-condicionados. A luminosidade será controlada com um LDR e quatro luminárias.

	 * * * * * * * * * * * * * * * * * * * * * 
	 * Parâmetros no Controle de Temperatura *
	 * * * * * * * * * * * * * * * * * * * * *
| Faixa de temperatura |  Ventiladores (PWM)  |  Ar 1  |  Ar 2  |  Ar 3  |  Ar 4  |
|:--------------------:|:--------------------:|:------:|:------:|:------:|:------:|
| 		  <=20ºC		     |		    10% Pmax      |  OFF	 |  OFF   |  OFF	 |	OFF   |
| 	>20ºC a <=25ºC		 |		    30% Pmax      |  ON	   |  OFF   |  OFF   |	OFF   |
| 	>25ºC a <=30ºC		 |		    75% Pmax      |  ON	   |	ON    |  OFF	 |	OFF   |
|		>30ºC			         |		    90% Pmax      |	 ON    |	ON	  |	 ON	   |	ON    |                                      
                                                                               
	* * * * * * * * * * * * * * * * * * * * * 
	* Parâmetros no Controle de Luminosidade*
	* * * * * * * * * * * * * * * * * * * * *
| Luz ambiente | Lum 1 | Lum 2 | Lum 3 | Lum 4 |
|:------------:|:-----:|:-----:|:-----:|:-----:|
|	   Claro		 |	OFF	 |	OFF	 |	OFF	 |	OFF  |
|	   Sombra		 |	ON	 |	OFF	 |	ON	 |	OFF  |
|	   Escuro		 |	ON	 |	ON	 |	ON	 |	ON   |

**Solutions implemented on Proteus (versions 1 and 2, from left to right)**
<img src ="Disco Project/Version 1/DiscoProject - Proteus Schematic v1.png" width = 400> <img src ="Disco Project/Version 2/DiscoProject - Proteus Schematic v2.png" width = 400>
