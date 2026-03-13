;******************** (C) COPYRIGHT HAW-Hamburg ********************************
;* File Name          : main.s
;* Author             : Silke Behn	
;* Version            : V1.0
;* Date               : 01.06.2021
;* Description        : This is the solution with FSM
;					  :
;					  : Replace this main with yours.
;
;*******************************************************************************

; Offene Punkte
; - Textausgabe vereinfachen


; Define address of selected GPIO and Timer registers

PERIPH_BASE     	equ	0x40000000                 ;Peripheral base address
APB2PERIPH_BASE 	equ	(PERIPH_BASE + 0x00010000)
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
TIM2_ERG			equ (TIM2_BASE + 0x14)   ;16 Bit register, Bit 0 : 1 Restart Timer


; Allgemeine Konstante
;********************************************
TRUE				EQU			0x01
FALSE				EQU			0x00

; States der FSM
;--------------------------------------------
INIT_STATE			EQU			0x01
HOLD_STATE			EQU			0x02
RUNNING_STATE		EQU			0x04

; Masken der LEDs
;--------------------------------------------
LED_RUNNING			EQU			(0x01 << 0)
LED_HOLD			EQU			(0x01 << 1)	
	
; Masken der Taster
;--------------------------------------------	
TAS7				EQU			(0x01<<7)
TAS6				EQU			(0x01<<6)
TAS5				EQU			(0x01<<5)
TASTER_MASK			EQU			(TAS7 + (TAS6 + TAS5))	

; Linke obere Ecke der TFT Ausgabe
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
	EXTERN Delay				; Delay (ms) function


;********************************************
; Data section, aligned on 4-byte boundery
;********************************************
	AREA MyData, DATA, align = 2

; Die gestoppte Zeit wird an drei Stellen dargestellt:
; (1) Die gestoppten Zeitspannen, die sich durch den Zugriff auf TIMER
;     ergibt. Sie wird in der Genauigkeit des Timers (1 Tick = 10 us) 
;     gespeichert. 
;     Die aktuelle  Zeitspanne und die Zeitspanne, die TFTZeit entspricht,
;	  werden in Registern in der main Funktion gespeichert.
; (2) Der Str. der Zeit, die auf dem Display ausgegeben werden soll.
;     Der Str. steht im Speicher an der Adresse TFTZeit.
; (3) Die Darstellung von TFTZeit auf dem TFT Display. Die ‹bertragung der Zeit
;     dauert relativ lange. Daher wir der von rechts gesehene groesste
;     Teilstr. von TFTZeit ¸bertragen, der sich geaendert hat.	

; Zu jeder Stelle von TFTZeit -also der Ausgabe - werden folgende Informationen
; gespeichert:
; (1) Die Position im TFTZeit Str., an der dieser Stelle steht. Dies wird den 
;     die Ausgabe eines geaenderten Teilstr. von TFTZeit benoetigt.
; (2) Die 10-Sekunden Stelle und die 10-Minuten Stelle werden zur Baais 6 
;     dargestellt. Die anderen Stellen werden zur Basis 10 dargestellt.
;     Die Basis einer Stelle wird gespeichert.

	ALIGN		  		; StrPos  Basis
Pos100telSec		DCB		7,		10
Pos10telSec			DCB		6,		10
Pos1sec				DCB		4,		10
Pos10Sec			DCB		3,		6
Pos1Min				DCB		1,		10
Pos10Min			DCB		0,		6
	
TFTtext				DCB		"HAW Stoppuhr",0	; Begruessungstext TFT
TFTZeit				DCB		"00:00.00",0		; Uhrzeit, die auf dem TFT Display ausgegegen werden soll

	ALIGN
TimeStamp		   	DCD	    0x00				; Halbwort, dass den letzten Zeitstempel speichert.
DEFAULT_BRIGHTNESS	DCW     800

;********************************************
; Code section, aligned on 8-byte boundery
;********************************************
	AREA |.text|, CODE, READONLY, ALIGN = 3

;--------------------------------------------
; Ansteuerung der LEDs
;--------------------------------------------

; Schalte mehrere LEDs an
;--------------------------------------------
LEDson	PROC	; verwende nur R0 bis R3 und keine weiteren PROC Aufrufe, sichern der Register entfaellt
		;	IN	R0		LEDs die angeschaltet werden sollen
		LDR		R1,=GPIO_D_SET
		STRH	R0,[R1]
		BX		LR
		ENDP

; Schalte mehrere LEDs aus
;--------------------------------------------
LEDsoff	PROC	; verwende nur R0 bis R3 und keine weiteren PROC Aufrufe, sichern der Register entfaellt
		;	IN	R0		LEDs die ausgeschaltet werden soll
		LDR		R1,=GPIO_D_CLR
		STRH	R0,[R1]
		BX		LR
		ENDP

; Update LEDs
;--------------------------------------------
UpdateLEDs	PROC						
		;	IN	R0		Aktuelle Zustand der FSM
		PUSH		{R4,LR}					; Sicher Register
		MOV			R1,#0x0					; R1 speichert die LEDs, die gesetzt werden sollen
		MOV			R4,#0x0					; R4 speichert die LEDs, die geloescht werden sollen
		CMP			R0,#INIT_STATE			; Update LED RUNNING
		ADDNE		R1,#LED_RUNNING
		ADDEQ		R4,#LED_RUNNING
		CMP			R0,#HOLD_STATE			; Update LED HOLD
		ADDEQ		R1,#LED_HOLD		
		ADDNE		R4,#LED_HOLD
		MOV			R0,R1					; Schalte LEDs
		BL			LEDson
		MOV 		R0,R4
		BL			LEDsoff
		POP			{R4,PC}					; Restore Register und Ruecksprung
		ENDP

;--------------------------------------------
; Ansteuerung des TFT Display
;--------------------------------------------

; PrintTFTZeit gibt TFTZeit auf den TFT Display aus.
; Es wird nur der Teilstring aktualisiert, der sich geaendert hat. 
; Der Teilstr. beginnt an der weitesten links stehenden Position
; im TFTZeit, die sich ge‰ndert hat.
;--------------------------------------------
PrintTFTZeit	PROC
		;	IN	R0		Position im TFTUhr Str, ab der ausgegeben werden soll
		PUSH		{R4,LR}					; Sicher Register
		MOV			R4,R0					; R4 = Position im TFTZeit Str, aber der die Ausgabe erfolgt		
		ADD			R0, R4, #G_X_POS + 2	; Positioniere Cursor, X Position
		MOV			R1,	#G_Y_POS + 3
		BL			lcdGotoXY
		LDR			R0, =TFTZeit
		ADD 		R0,R4					; Selektiere Teilstr. im TFTUhr
		BL			lcdPrintS
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
		MOV			R0,#0					; Gebe TFTZeit auf dem TFT aus
		BL			PrintTFTZeit			 
		POP			{R4,PC}
		ENDP

;--------------------------------------------
; Behandlung der TFTUhr Variablen
;--------------------------------------------

; Diese Funktion aktualisiert die Variable TFTZeit und gibt den Teilstr. dieser
; Variablen aus, der sich ge‰ndert hat. TFTZeit wird nur aktualisiert, wenn eine 
; Aenderung vorliegt. Auf dem TFT Display wird nur der geaenderte Teilstr. aktualisiert.
; Dies wird auf Basis der Zeitspannen realisiert. Daher wird die aktuelle Zeitspanne
; und die Zeitspanne, aus der TFTZeit abgeleitet wurde, als Parameter uebergeben.
;--------------------------------------------
UpdateAndPrintTFTZeit	PROC
		;	IN	R0		Aktuelle Zeitspanne
		;	IN 	R1		Zeitspanne, die TFTUhr entspricht		
		PUSH		{R4,R5,R6,R7,R8,LR}		; Sicher Register
		MOV			R4,#1000				; Runde beide Zeitspanne auf 1/100 sec
		UDIV		R0,R0,R4				; R0 = Aktuelle Zeitspanne auf aktuelle Stelle gerundet
		UDIV		R1,R1,R4				; R1 =  Zeitspanne der TFTUhr auf aktuelle Stelle gerundet
		CMP			R0,R1
		BEQ			endUpdateAndPrintTFTZeit; Aktuelle Zeitspanne wird schon auf der TFT Uhr anzeigt
		MOV			R2,#0					; R2 : Laufindex
		LDR			R3,=Pos100telSec		; R3 : Basis Adresse fuer aktuelle Stelle
		MOV			R8,#0					; R8 : linke Position, ab der Ausgabestr. veraendert wurde
		LDR			R7,=TFTZeit				; R7 : Basis Adresse des TFTZeit Strs
forUpdateLoop
		CMP			R2,#6					; for 0 <= R2 < 6
		BEQ			forUpdateEnd
		; Berechne Module der Stellen
		LDRB		R4,[R3,#1]				; R4 : Modulo der aktuellen Stelle
		UDIV		R5,R0,R4
		MUL			R5,R5,R4
		SUB			R5,R0,R5				; R5 : Neuer Wert der Stelle
		UDIV		R0,R0,R4				; R0 Zeitspanne zur Berechnung der naechsten Stelle
		UDIV		R6,R1,R4
		MUL			R6,R6,R4
		SUB			R6,R1,R6				; R6 : TFTUhr Wert der Stelle
		UDIV		R1,R1,R4				; R1 Zeitspanne zur Berechnung der naechsten Stelle
		CMP			R5,R6					; Test, ob der Wert der Stelle sich geaendert hat
		BEQ			ifStelleVeraendertEnd
		; Der Wert der Stelle hat sich geaendert
		LDRB		R8,[R3]					; Position in TFTUhr, die aktualisiert werden muss
		ADD			R5,#"0"					; ASCII Wert der Stelle
		STRB		R5,[R7,R8]				; Update TFTUhr
ifStelleVeraendertEnd		
		ADD			R2,#1
		ADD			R3,#2
		BAL			forUpdateLoop
forUpdateEnd		
		; print FTFUhr auf dem TFT Display
		MOV			R0,R8
		BL 			PrintTFTZeit
endUpdateAndPrintTFTZeit		
		POP			{R4,R5,R6,R7,R8,PC}		; Restore Register und Ruecksprung
		ENDP

;--------------------------------------------
; Behandlung der Uhrzeit
;--------------------------------------------
; Vorgehensweise	Ein 32 Bit Wert speicher die vergangene Zeit seit dem
;                   Start der Uhrzeit in der Genauigkeit 10 µs
;					Die Zeitspanne wird in jedem Durchlauf erhˆht. Ist der 
;					Automat in INIT Zustand, wird sie immer wieder auf 0 gestellt.
					
; Update der Zeitspanne auf Basis des Timers
;--------------------------------------------
UpdateUhr		PROC	; verwende nur R0 bis R3 und keine weiteren PROC Aufrufe, sichern der Register entfaellt
		;	IN	R0		Aktuelle Zeitspanne
		;	OUT	R0		Aktualisierte Zeitspanne
		LDR		R1,=TIMER					; R1 = neuer Zeitstempel
		LDR 	R1,[R1]
		LDR		R2,=TimeStamp				; R2 = Adresse alter Zeitstempel
		LDR		R3,[R2]						; R3 = alter Zeitstempel
		STR		R1,[R2]						; Update TimeStamp
		SUB		R1,R3						; R1 = neuer Zeitstempel - alter Zeitstempel
		ADD		R0,R1						; R0 = aktualisierte Zeitspanne
		BX		LR
		ENDP
			
;--------------------------------------------
; Behandlung der Taster
;--------------------------------------------
; Vorgehensweise	Das untere Byte von GPIOE wird ausgelesen
;					und mit Bitoperationen von den Tastermasken verglichen

; Lese Tasterbelegung aus
;--------------------------------------------
LeseTaster		PROC	; verwende nur R0 bis R3 und keine weiteren PROC Aufrufe, sichern der Register entfaellt
		;	OUT	R0		Aktuelle Zustand der Taster
		;				0 <=> Taster gedrueckt 
		LDR		R1,=GPIO_F_PIN				; Lese Tasterstatus ein
		LDRB	R0,[R1]
		AND		R0, R0,#TASTER_MASK			; Blende nicht relevante Bits aus
		BX		LR
		ENDP

; Test, ob genau ein Taster gedrueckt ist
;--------------------------------------------
TesteTaster		PROC	; verwende nur R0 bis R3 und keine weiteren PROC Aufrufe, sichern der Register entfaellt
		;	IN	R0		Aktuelle Zustand der Taster
		;	IN	R1		Taster, der getestet werden soll
		;	Ausgabe		(Z Flag == 0) <=> Nur Taster R1 ist gedrueckt
		EOR		R1,R0
		CMP		R1,#TASTER_MASK
		BX		LR
		ENDP

;--------------------------------------------
; Implementation der FSM
;--------------------------------------------

FsmTransition		PROC
		;	IN	R0		aktueller Zustand
		;	IN	R1		Belegung der Taster
		;	OUT	R0		neuer Zustand	
		; 	Uebergangsfunktion
		;	Wenn keine Taste gedrueckt ist, 	keine Zustandsaenderung
		;	Wenn mehrere Taster gedrueckt sind, keine Zustandsaenderung
		;	akt. Zustand	Taster gedrueckt	neuer Zustand
		;		*				Tas5				INIT
		;		RUNNING			Tas6				HOLD
		;		INIT			Tas6				INIT
		;		HOLD			Tas6				HOLD
		;		*				Tas7				RUNNING


		PUSH	{R4,R5,R6,LR}			; Sicherer Register	
		MOV		R4,R0					; R4 speichert den aktuellen Zustand
		MOV		R5,R1					; R5 speichert die Belegung der Taster

		; Wenn Tas5 alleine gedrueckt ist, Init Zustand setzen und rausspringen
		MOV 	R0,R1
		MOV 	R1,#TAS5
		BL 		TesteTaster
		MOVEQ	R0, #INIT_STATE
		BEQ		FsmTransitionEnd
		; Wenn Tas7 alleine gedrueckt ist, Running Zustand setzen und rausspringen
		MOV 	R0,R5
		MOV 	R1,#TAS7
		BL 		TesteTaster
		MOVEQ	R0,#RUNNING_STATE
		BEQ		FsmTransitionEnd
		; Wenn Tas6 nicht alleine gedrueckt, rausspringen
		MOV 	R0,R5	
		MOV 	R1,#TAS6
		BL 		TesteTaster
		MOVNE	R0,R4
		BNE		FsmTransitionEnd
		; Taster 6 ist alleine gedrueckt
		; Wenn im Zustand Running, dann in den Zustand Hold wechseln, Sonst im alten Zustand bleiben
		CMP		R4, #RUNNING_STATE
		MOVEQ	R0, #HOLD_STATE
		MOVNE	R0, R4
FsmTransitionEnd
		POP		{R4,R5,R6,PC}				; Restore Register und Ruecksprung
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
		ldr 	R1,=TIM2_ERG   			; Restart timer	
		mov		R0,#0x01
		strh	R0,[R1]					; Set UG Bit
		MOV 	R0, #24
		bl  	lcdSetFont
		bl 		InitTFT
		; BL 		testPSC
		
	    ; Start program
		BL		UpdateUhr					; Damit TimeStamp einen sinnvollen Wert hat
		MOV		R6,		#0					; R6 = Zeitspanne, der der Wert von TFTUhr entspricht
		MOV		R7,		#0					; R7 = neue gestoppte Zeitspanne
		MOV 	R8,		#INIT_STATE			; R8 = aktueller Zustand
		MOV		R9,		#TASTER_MASK		; R9 = Tasterbelegung

		; superLoop gemaess DDC
superloop
		; Aktualisierung der gestoppten Zeitspanne
		MOV 	R0,R7
		BL 		UpdateUhr
		MOV		R7, R0
		
		; lese Eingabe ein
		BL		LeseTaster
		MOV		R9, R0
		
		; Update Zustand
		MOV		R0,	R8
		MOV		R1,	R9
		BL	FsmTransition
		MOV 	R8, R0
		
		; INIT State => setze gestoppte Zeitspanne auf 0
		CMP		R8,#INIT_STATE
		MOVEQ	R7,#0

		; update LEDs
		MOV 	R0, R8
		BL 		UpdateLEDs
		
		; Wenn  im Zustand HOLD: aktualisierte TFT Uhrzeit nicht
		CMP		R8,#HOLD_STATE
		BEQ		superloop
		
		; Update and print TFTUhr, wenn sie sich geaendert hat
		MOV 	R0, R7
		MOV		R1, R6
		BL UpdateAndPrintTFTZeit
		MOV		R6,R7		
		
		BAL		superloop				; End of superloop
		ENDP

testPSC		PROC	; Diese Funktion toggelt D8 (PD0) mit einen
	                ; zeitlichen Abstand von 1000 Ticks
		MOV	R3, #0  ; Toogle Bit
loop
		LDR	R0,=TIMER
		LDR R1,[R0]
intloop
		LDR R2,[R0]
		SUB	R4, R2,R1
		CMP R4, #1000
		BMI	intloop
		; Toogle LED
		LDR		R5,=GPIO_D_CLR
		LDR		R6,=GPIO_D_SET
		CMP R3,#0
		MOVNE	R5, R6
		MOV		R6, #0x1
		STRH	R6,[R5]
		EOR		R3, R3, #0xFFFFFFFF
		B loop
		BX		LR
		ENDP


		ALIGN
		END
