;******************** (C) COPYRIGHT HAW-Hamburg ********************************
;* File Name          : main.s
;* Author             : Franz Korf  
;* Version            : V1.0
;* Date               : 16.05.2022
;* Modified by        : Thomas Lehmann, 2024-07-12
;* Description        : This is the frame for the last assignment.
;                     : Einfaches Lauflicht.
;
;*******************************************************************************
    EXTERN initITSboard
    EXTERN lcdPrintS            ;Display ausgabe
    EXTERN GUI_init
    EXTERN TP_Init
    EXTERN delay
        
; Define address of selected GPIO and Timer registers
PERIPH_BASE         equ 0x40000000                 ;Peripheral base address
AHB1PERIPH_BASE     equ (PERIPH_BASE + 0x00020000)
APB1PERIPH_BASE     equ PERIPH_BASE

GPIOD_BASE          equ (AHB1PERIPH_BASE + 0x0C00)
GPIOE_BASE          equ (AHB1PERIPH_BASE + 0x1000)
GPIOF_BASE          equ (AHB1PERIPH_BASE + 0x1400)
TIM2_BASE           equ (APB1PERIPH_BASE + 0x0000)

GPIO_F_PIN          equ (GPIOF_BASE + 0x10)

GPIO_D_PIN          equ (GPIOD_BASE + 0x10)
GPIO_D_SET          equ (GPIOD_BASE + 0x18)
GPIO_D_CLR          equ (GPIOD_BASE + 0x1A) 
    
GPIO_E_PIN          equ (GPIOE_BASE + 0x10)
GPIO_E_SET          equ (GPIOE_BASE + 0x18)
GPIO_E_CLR          equ (GPIOE_BASE + 0x1A)     



;********************************************
; Data section, aligned on 4-byte boundery
;********************************************   
    AREA MyData, DATA, align = 2
TestPattern DCW     0x8000, 0x7000, 0x5000

;********************************************
; Code section, aligned on 8-byte boundery
;********************************************
    AREA |.text|, CODE, READONLY, ALIGN = 3

;--------------------------------------------
; main subroutine
;--------------------------------------------

        
; Unterprogramm zum Ansteuern von D23 bis D16 bzw. D15 bis D8
; IN R0  Die unteren 8 Bits von R0 speichern das Muster, mit
;        dem die LEDs beschaltet werden.
; IN R1  Wahl, ob die LEDs D23 bis D16 bzw. D15 bis D8 geschaltet
;        werden.
;        R1 == 0 : D15 bis D8 werden geschaltet
;        R1 != 0 : D23 bis D16 werden geschaltet
;
;	R4	: Aktuelle Belegung der LEDs
;	R5	: GPIO_D_SET bzw. GPIO_E_SET
;	R6	: GPIO_D_CLR bzw. GPIO_E_CLR


SetLEDs	PROC
			PUSH 	{R4-R6,LR}			; Sichere Register
			AND		R4, R0,#0xFF
			; Waehle Port
If_1
			CMP		R1,#0x00
			BNE		Else_1
Then_1
			LDR 	R5, =GPIO_D_SET
			LDR		R6, =GPIO_D_CLR
			B EndIf_1
Else_1
			LDR 	R5, =GPIO_E_SET
			LDR		R6, =GPIO_E_CLR			
EndIf_1
			; Schalte LEDS
			STRH	R4, [R5]
			EOR		R4, R4, #0xFF
			STRH	R4, [R6] 
			POP  	{R4-R6,PC}			; rekonstruiere Register
			ENDP
		
; Unterprogramm Lauftlicht
;
; Einfaches Lauflicht, das ein Bitmuster zyklisch ueber die 
; LEDs D23 bis D8 schiebt. Das LED Muster wird nach rechts 
; geschoben. Die Frequenz betraegt 2 Hz.
;
; IN R0  Die unteren 16 Bits von R0 speichern das Muster, mit
;        dem die LEDs initialisiert werden.
; IN R1	 Anzahl Schritte, die das Lauflicht laufen soll.
;--------------------------------------------		
;
;   R4  : Konstante 0xFFFF 
;	R5	: Aktuelle Belegung des Lauflichts: Bit 7 bis Bit 0 beschreiben D15 bis D8
;	R6	: 
;	R7	: 
;	R8	: Anzahl Druchlaeufe, die noch anstehen

DelayTime	EQU		500

Lauflicht	PROC
			PUSH 	{R4-R8,LR}			; Sichere Register
			LDR		R4,=0xFFFF
			MOV		R8, R1
			AND		R5, R0, R4			; R5 speichert die aktuelle Belegung des Lauftlichts
While_1
			CMP		R8,#0
			BEQ		EndWhile_1
			SUB		R8,#1
; Schleifenrumpf
			; Schalte LEDS
			MOV 	R0, R5
			MOV		R1, #0x00
			BL 		SetLEDs
			LSR		R0, R5, #0x08
			MOV		R1, #0x01
			BL 		SetLEDs
			
			; Shifte R5 um 1 nach Rechts im Kreis
			LSL		R0, R5, #16
			ORR		R5, R5, R0
			LSR		R5,#1
			AND		R5,R4
			; Delay 
			MOV		R0, #DelayTime
			; Da die Funktion Lauflicht nur die callee saved Register verwendet, muss nichts gesichert werden.
			BL		delay
			BAL 	While_1
EndWhile_1
			POP  	{R4-R8,PC}			; rekonstruiere Register
			ENDP

;--------------------------------------------
; main subroutine
;--------------------------------------------
    EXPORT main [CODE]
        
InterTestDelay  EQU     4000
    
main    PROC
        BL initITSboard
        LDR     R7, =TestPattern
        MOV     R8, #0                  ; Laufindex Testpattern
forever 
        CMP     R8, #3
        MOVGE   R8, #0
        
        ; Test Lauflicht
        LDRH    R0, [R7,R8,LSL #1]
        MOV     R1, #20
        BL      Lauflicht
        
        LDR     R0, =InterTestDelay
        BL      delay

        ADD     R8, #1
        BAL     forever     ; nowhere to retun if main ends     
        ENDP
    
        ALIGN
        END
