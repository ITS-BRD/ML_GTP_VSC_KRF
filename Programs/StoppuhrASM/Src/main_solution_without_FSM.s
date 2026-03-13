;******************** (C) COPYRIGHT HAW-Hamburg ********************************
;* File Name          : main.s
;* Author             : Franz Korf	
;* Version            : V1.0
;* Date               : 01.06.2021
;* Description        : This is a simple main.
;					  :
;					  : Simple solution without FSM
;
;*******************************************************************************

; Define address of selected GPIO and Timer registers
PERIPH_BASE     	equ	0x40000000                 ;Peripheral base address
AHB1PERIPH_BASE 	equ	(PERIPH_BASE + 0x00020000)
APB1PERIPH_BASE     equ PERIPH_BASE

GPIOD_BASE			equ	(AHB1PERIPH_BASE + 0x0C00)
GPIOF_BASE			equ	(AHB1PERIPH_BASE + 0x1400)
TIM2_BASE           equ (APB1PERIPH_BASE + 0x0000)
	
GPIO_F_PIN        	equ	(GPIOF_BASE + 0x10)

GPIO_D_PIN			equ	(GPIOD_BASE + 0x10)
GPIO_D_SET			equ (GPIOD_BASE + 0x18)
GPIO_D_CLR			equ	(GPIOD_BASE + 0x1A)
	
TIMER				equ (TIM2_BASE + 0x24)   ; CNT : current time stamp (32 bit),  resolution
TIM2_PSC			equ (TIM2_BASE + 0x28)   ; Prescaler  resolution
TIM2_ERG			equ (TIM2_BASE + 0x14)   ; 16 Bit register, Bit 0 : 1 Restart Timer

; States of clock
;--------------------------------------------
INIT_STATE			EQU			0x01
HOLD_STATE			EQU			0x02
RUNNING_STATE		EQU			0x04

; LED masks
;--------------------------------------------
LED_RUNNING			EQU			(0x01 << 0)
LED_HOLD			EQU			(0x01 << 1)	
	
; Button masks
;--------------------------------------------	
TAS7				EQU			(0x01<<7)
TAS6				EQU			(0x01<<6)
TAS5				EQU			(0x01<<5)
TASTER_MASK			EQU			(TAS7 + (TAS6 + TAS5))	

; Upper left corner for display output
;--------------------------------------------
G_X_POS				EQU			2						; Spalte (X) Position
G_Y_POS				EQU		 	2						; Zeile  (Y) Position

    EXTERN initITSboard
    EXTERN GUI_init
	EXTERN TP_Init
	EXTERN initTimer
	EXTERN lcdSetFont
	EXTERN lcdGotoXY      		; TFT goto x y function
	EXTERN lcdPrintS			; TFT output function	
    EXTERN lcdPrintC            ; TFT output one character		
	EXTERN Delay				; Delay (ms) function

;********************************************
; Data section, aligned on 4-byte boundery
;********************************************
	AREA MyData, DATA, align = 2

; Die gestoppten Zeitspannen, die sich durch den Zugriff auf TIMER
; ergibt, wird in einem Register gespeichert. Sie wird in der Genauigkeit 
; des Timers (1 Tick = 10 us) gespeichert.
; Es wird die Zeit von TIMER genommen, die beim Init immer zurueckgesetzt
; wird. Ist o.k., das Overflow erst nach 11 Stunden auftritt.
; Weitere Zeiten werden nicht gespeichert. Auf dem TFT Display wird die 
; Zeit stets erneut ausgegeben, auch wenn Sie sich nicht ver‰ndert hat.

; Auf dem Display wird jede Stelle der Zeitausgabe aktualisiert. Folgende 
; Tabelle zeigt die Position und Wertigkeit der einzelnen Stellen.

	ALIGN		  		; StrPos  Basis   LastValue
Pos100telSec		DCB		7,		10,      0
Pos10telSec			DCB		6,		10,      0
Pos1sec				DCB		4,		10,      0
Pos10Sec			DCB		3,		6,       0 
Pos1Min				DCB		1,		10,      0
Pos10Min			DCB		0,		6,       0		

TFTtext				DCB		"HAW Stoppuhr",0	; Begruessungstext TFT
TFTZeit				DCB		"00:00.00",0		; String f¸r die Zeitausgabe auf dem TFT

	ALIGN
DEFAULT_BRIGHTNESS	DCW     800

;********************************************
; Code section, aligned on 8-byte boundery
;********************************************
	AREA |.text|, CODE, READONLY, ALIGN = 3

; Reset Timer
;--------------------------------------------
SetTimrTo0	PROC ; verwende nur R0 bis R1 und keine weiteren PROC Aufrufe, sichern der Register entfaellt						
		;	Reset Timer
		ldr 	R1,=TIM2_ERG   			; Restart timer	
		mov		R0,#0x01
		strh	R0,[R1]					; Set UG Bit	
		BX		LR
		ENDP

; Update LEDs
;--------------------------------------------
UpdateLEDs	PROC						
		;	IN	R0		Aktuelle Zustand der FSM
		;   INIT_STATE    : both LEDs off
		;   RUNNING_STATE : LED_RUNNING on LED_HOLD off
		;   HOLD_STATE    : both LEDs on
		LDR			R2,=GPIO_D_SET
		LDR			R3,=GPIO_D_CLR
		MOV			R1, #(LED_HOLD + LED_RUNNING)
		CMP			R0,#INIT_STATE
		STRHEQ		R1,[R3]
		CMP			R0,#HOLD_STATE
		STRHEQ		R1,[R2]
		CMP			R0,#RUNNING_STATE
		MOVEQ		R1, #LED_RUNNING
		STRHEQ		R1,[R2]
		MOVEQ		R1, #LED_HOLD
		STRHEQ		R1,[R3]	
		BX			LR
		ENDP

; PrintTFTZeit ‰ndert eine Stelle der Zeitausgabe auf dem TFT.
;--------------------------------------------			
PrintTFTZeit	PROC
		;	IN	R0		Position im TFTUhr Str, ab der ausgegeben werden soll
		;   IN  R1      Wert
		PUSH		{R4,LR}					; Sicher Register
		ADD			R4, R1,#'0'
		ADD			R0, #G_X_POS + 2
		MOV			R1,	#G_Y_POS + 3
		BL			lcdGotoXY
		MOV			R0,R4
		BL			lcdPrintC
		POP			{R4,PC}					; Restore Register und Ruecksprung
		ENDP
			
; Initialisierung des TFT Displays
;--------------------------------------------
InitTFT	PROC    
		PUSH		{R4,LR}					; Sicher Register
		MOV			R0, #G_X_POS			; Positioniere Cursor
		MOV			R1,	#G_Y_POS			
		BL			lcdGotoXY
		LDR 		R0,=TFTtext				; Gebe Begruessung auf dem TFT aus
		BL			lcdPrintS		
		MOV			R0, #G_X_POS + 2	; Positioniere Cursor, X Position
		MOV			R1,	#G_Y_POS + 3
		BL			lcdGotoXY
		LDR			R0, =TFTZeit
		BL			lcdPrintS
		POP			{R4,PC}
		ENDP

;--------------------------------------------
; Behandlung der TFTUhr Variablen
;--------------------------------------------
; Diese Funktion erh‰lt die aktuelle Zeitspanne und aktualisiert die 
; TFT Ausgabe Stelle f¸r Stelle - auch wenn sich nichts ge‰ndert hat.
;--------------------------------------------
UpdateAndPrintTFTZeit	PROC
		;	IN	R0		Aktuelle Zeitspanne
		PUSH		{R4,R5,R6,LR}			; Sicher Register
		MOV			R1,#1000				; Runde Zeitspanne auf 1/100 sec
		UDIV		R4,R0,R1				; R4 = Zeit, die auf TFT dargestellt werden soll
		MOV			R5, #0					; Laufindex
		LDR			R6,=Pos100telSec		
pl_loop	CMP			R5,#6
		BEQ			end_pl_loop
		LDRB		R0, [R6],#1				; Position in Ausgabe Str.
		LDRB		R2, [R6],#1				; Dividend
		UDIV		R3, R4, R2
		MUL			R1, R3, R2
		SUB			R1, R4, R1
		MOV			R4, R3
		ADD			R5,#1
		; Compare with last printed value
		LDRB		R2, [R6]				; Last value
		STRB		R1, [R6],#1
if_3	CMP			R2, R1
		BLNE		PrintTFTZeit
		BAL			pl_loop
end_pl_loop		
		POP			{R4,R5,R6,PC}		; Restore Register und Ruecksprung
		ENDP

;--------------------------------------------
; Implementation of state change (FSM)
;--------------------------------------------
UpdateState		PROC
		;	IN	R0		aktueller Zustand
		;	IN	R1		Belegung der Taster
		;	OUT	R0		neuer Zustand	
		; 	Uebergangsfunktion
		;	Wenn keine Taste gedrueckt ist, 	keine Zustandsaenderung
		;	Wenn mehrere Taster gedrueckt sind, keine Zustandsaenderung
		;	akt. Zustand	Taster gedrueckt	neuer Zustand
		;		    *			Tas5				INIT
		;           *           Tas7                RUNNING
		;		RUNNING			Tas6				HOLD
		;		INIT			Tas6				INIT
		;		HOLD			Tas6				HOLD
ONLY_BUTTON_7_PRESSED		equ			0x60
ONLY_BUTTON_6_PRESSED		equ			0xA0
ONLY_BUTTON_5_PRESSED		equ			0xC0
		CMP		R1,#ONLY_BUTTON_5_PRESSED
		MOVEQ	R0,#INIT_STATE
		CMP		R1,#ONLY_BUTTON_7_PRESSED
		MOVEQ	R0,#RUNNING_STATE		
		CMP		R1,#ONLY_BUTTON_6_PRESSED
		BNE		EndUpdate
		CMP		R0,#INIT_STATE
		MOVNE	R0,#HOLD_STATE
EndUpdate
		BX		LR
		ENDP

;--------------------------------------------
; main subroutine
;--------------------------------------------
	EXPORT main [CODE]
	
main	PROC
		; Initialisierung der HW
		BL		initITSboard
		ldr   	r1, =DEFAULT_BRIGHTNESS
		ldrh 	r0, [r1]
		bl   	GUI_init
		bl  	initTimer
		ldr 	R1,=TIM2_PSC   			; Set pre scaler such that 1 timer tick represents 10 us
		mov 	R0,#(90*10-1) 
		strh	R0,[R1]
		BL SetTimrTo0
		; set Font
		MOV 	R0, #24
		bl  	lcdSetFont
		bl 		InitTFT
		
	    ; Start program
		MOV		R7,		#0					; R7 = neue gestoppte Zeitspanne
		MOV 	R8,		#INIT_STATE			; R8 = aktueller Zustand

		; superLoop gemaess DDC
superloop
		; Aktualisierung der gestoppten Zeitspanne
		LDR		R1,=TIMER					; R1 = neuer Zeitstempel
		LDR 	R7,[R1]
		
		; lese Taster in R1 ein
		LDR		R1,=GPIO_F_PIN				; Lese Tasterstatus ein
		LDRB	R1,[R1]
		AND		R1, R1,#TASTER_MASK			; Blende nicht relevante Bits aus
		
		; Update Zustand
		MOV		R0,	R8
		BL	UpdateState
		MOV 	R8, R0
		
		; INIT State => setze gestoppte Zeitspanne auf 0
if_1	CMP		R8,#INIT_STATE
		MOVEQ	R7,#0
		BLEQ 	SetTimrTo0

		; update LEDs
		MOV 	R0, R8
		BL 		UpdateLEDs
		; Wenn  im Zustand HOLD: aktualisierte TFT Uhrzeit nicht
if_2	CMP		R8,#HOLD_STATE		
		; Update and print TFTUhr, wenn sie sich geaendert hat
		MOVNE 	R0, R7
		BLNE    UpdateAndPrintTFTZeit
		BAL		superloop				; End of superloop
		ENDP

		ALIGN
		END
