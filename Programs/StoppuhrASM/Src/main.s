;******************** (C) COPYRIGHT HAW-Hamburg ********************************
;* File Name          : main.s
;* Author             : Franz Korf	
;* Version            : V1.1
;* Date               : 24.03.2026
;* Description        : Simple Soluation 
;					  : Replace this main with yours.
;
;*******************************************************************************

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

; Konstanten zum Ansteuern des Displays
;--------------------------------------------
G_X_POS				EQU			2						; X Position Begrüßungstext
G_Y_POS				EQU		 	2						; Y Position Begrüßungstext
TFT_TIME_X_POS      EQU         (G_X_POS + 7)  			; X Position Zeitausgabe
TFT_TIME_Y_POS      EQU         (G_Y_POS + 4)           ; Y Position Zeitausgabe
DEFAULT_BRIGHTNESS	EQU         800

    EXTERN initITSboard
    EXTERN GUI_init
	EXTERN initTimer
	EXTERN lcdSetFont
	EXTERN lcdGotoXY      		; TFT goto x y function
	EXTERN lcdPrintS			; TFT output function
	EXTERN lcdPrintC	        ; TFT output function

;****************************************************************************
;   Start DATA Segment
	AREA MyData, DATA, align = 2

;****************************************************************************
; Berechnung der vergangenen Zeit
; 
; Der Timer aktualisiert mit der Frequenz 10^-5 Hz das CNT Register des Timers.
; Durch lesen der Adresse TIMER erhält man den aktuellen Wert dieses Registers.
; Einen Wert dieses Registers nennt man Zeitstempel. 
;
; Die Funktion UpdateUhr speichert den aktuellen Zeitstempel und berechnet die 
; Zeitspanne, die zwischen zwei Aufrufen der Funktion vergangen ist. Dies 
; wird durch Subtraktion des Zeitstempels, der beim letzten Aufruf der Funktion 
; gespeichert wurde, vom aktuellen Zeitstempel berechnet.
; Zur Initialisierung wird UpdateUhr einmalig aufgerufen.
;
; Am Anfang der SuperLoop wird UpdateUhr aufgerufen. So erhält man die 
; Zeitspanne, die seit dem letzten Aufruf der SuperLoop vergangen ist. 

TimeStamp           DCD     0    ; Zeitstempel von UpdateUhr

;****************************************************************************
; Aktualisierung der Display-Ausgabe
;
; Die Zeitspanne, die seit dem Start der Uhr vergangen ist, wird in einem
; Register mit der Genauigkeit des Timers (1 Tick = 10 us) gespeichert. 
;
; Die Zeit auf dem Display wird mit der Genauigkeit von 1/100 s im folgenden 
; Format ausgegeben:
;                       mm:ss.nn
;
; Die auf dem Display dargestellte Zeit steht im Feld ValOnDisplay. Jede Stelle 
; wird separat gespeichert.
;                       Display String 23:15.46
;                       Stelle 0 ------|| || ||---- Stelle 5
;                       Stelle 1 -------| || |----- Stelle 4
;                       Stelle 2 ---------||------- Stelle 3
; 
; Pro Stelle speichert das Feld StrOffset den Offset im String auf dem Display.
;
; Der Registerwert der aktuellen Zeit wird wie folgt in ValOnDisplay gespeichert:
; Pro Stelle speichert das Feld ModVal den Wert 
;             1 + Maximale Zeitspanne in 1/100 s, die bis zu dieser Stelle anzeigbar ist. 
; z.B. Stelle 1 
;      maximale Zeit 9:59.99
;      ModVal[1] = 1 + 9 * 60 * 100 + 59 * 100 + 99 = 60000
; z.B. Stelle 0 
;      maximale Zeit 59:59.99
;      ModVal[1] = 1 + 59 * 60 * 100 + 59 * 100 + 99 + 1 1/100s = 360000
;
; Die Wert von Stelle i ist dann : ((Register mit akt. Zeitspanne) % ModVal[i]) / ModVal[i + 1]

;                          Stelle 0, Stelle 1, Stelle 2, Stelle 3, Stelle 4, Stelle 5, Stelle 6
StrOffset 			DCB       0    ,    1    ,    3    ,    4    ,    6    ,    7
ValOnDisplay 	    DCB       0    ,    0    ,    0    ,    0    ,    0    ,    0  
ModVal	            DCD    360000  ,  60000  ,  6000   ,  1000   ,   100   ,    10   ,    1
	
TFTtext				DCB		"HAW Stoppuhr",0	; Begruessungstext TFT
TFTZeit				DCB		"00:00.00",0		; Uhrzeit, die auf dem TFT Display ausgegegen werden soll

;****************************************************************************
;   Start Text Segment
	AREA |.text|, CODE, READONLY, ALIGN = 3
	EXPORT main [CODE]

;****************************************************************************
; Ansteuerung der GPIOs - LEDs und Taster

LEDson PROC	
        ; Schalte mehrere LEDs an
		; IN	R0	    LEDs die angeschaltet werden sollen
		; Hinweis: Da nur R0 bis R3 verwendet werden, müssen Register nicht gesichert werden
		LDR		R1,=GPIO_D_SET
		STRH	R0,[R1]
		BX		LR
		ENDP

LEDsoff PROC	
        ; Schalte mehrere LEDs aus
		; IN	R0	    LEDs die ausgeschaltet werden sollen
		; Hinweis: Da nur R0 bis R3 verwendet werden, müssen Register nicht gesichert werden
		LDR		R1,=GPIO_D_CLR
		STRH	R0,[R1]
		BX		LR
		ENDP

LeseTaster PROC
        ; Ermittelt ob genau ein Taster gedrückt ist
		; OUT	R0 == TAS5      wenn nur Taster 5 gedrückt ist
		;    	R0 == TAS6      wenn nur Taster 6 gedrückt ist
		;   	R0 == TAS7      wenn nur Taster 7 gedrückt ist
		;   	R0 == 0         wenn kein oder mehrere Taster gedrückt sind
		; Hinweis: Da nur R0 bis R3 verwendet werden, müssen Register nicht gesichert werden
		LDR		R0, =GPIO_F_PIN				; Lese Tasterstatus ein
		LDRB	R0, [R0]
		EOR     R0, #0xFF
		AND		R0, R0,#(TAS5 + TAS6 + TAS7)		
		; aktuelle Wert von R0 : Bit 1 gesetzt: Taster i gedrückt
        ; Wenn genau 1 Taster gedrückt ist, dann ist R0 einen 2-er Potenz.
		; So wird nun getestet, ob genau ein Taster gedrückt ist.
        SUB     R1, R0, #1       
        AND     R1, R0, R1      ; R1 = R0 & (R0 - 1)
        CMP     R1, #0          
		; Wenn R1 == 0, dann ist R0 eine Zweierpotenz und somit genau ein oder kein Taster gedrückt
		MOVNE   R0, #0          ; lösche R0, wenn mehrere Taster gedrückt sind
		BX		LR
		ENDP

;****************************************************************************
; Berechnung der Zeitspanne

UpdateUhr PROC
		; OUT	R0	    Vergangene Zeitspanne seit dem letzten Aufruf von UpdateUhr
		; Hinweis: Da nur R0 bis R3 verwendet werden, müssen Register nicht gesichert werden
		LDR		R0, =TIMER					; R0 = neuer Zeitstempel
		LDR 	R0, [R0]
		LDR		R2, =TimeStamp				; R2 = Adresse alter Zeitstempel
		LDR		R1, [R2]					; R1 = alter Zeitstempel
		STR		R0, [R2]					; Update TimeStamp
		SUB		R0, R1						; R1 = neuer Zeitstempel - alter Zeitstempel
		BX		LR
		ENDP

;****************************************************************************
; Ausgabe der Zeit auf dem Display
 
InitTFT	PROC
		; Initialisierueng des Displays
		PUSH		{R4,LR}					; Sicher Register
		MOV			R0, #G_X_POS			; Positioniere Cursor
		MOV			R1,	#G_Y_POS			
		BL			lcdGotoXY
		LDR 		R0, =TFTtext			; Gebe Begruessung auf dem TFT aus
		BL			lcdPrintS
		MOV			R0, #TFT_TIME_X_POS		; Positioniere Cursor
		MOV			R1,	#TFT_TIME_Y_POS			
		BL			lcdGotoXY
		LDR			R0, =TFTZeit			; Gebe TFTZeit auf dem TFT aus
		BL			lcdPrintS			 
		POP			{R4,PC}					; Restore Register und Ruecksprung
		ENDP

UpdateStelle PROC
		; Aktualisiere eine Stelle der Uhrzeit auf dem Display
		;	IN	R0	zu aktualisierende Stelle (index von StrOffset und ValOnDisplay)
		PUSH		{R4,LR}
		MOV         R4, R0                  ; Stelle, die ausgegeben wird
        ; Positioniere Cursor
	    LDR         R0, =StrOffset
		LDRB        R0, [R0,R4]
		ADD         R0, #TFT_TIME_X_POS
		MOV			R1,	#TFT_TIME_Y_POS
		BL			lcdGotoXY
	    ; Geben Zeichen aus
	    LDR         R0, =ValOnDisplay
		LDRB        R0, [R0,R4]
		ADD			R0, #'0'
		BL			lcdPrintC
		POP			{R4,PC}	
		ENDP

ModuloOp PROC
        ; Unsigned Modulo Operation R0 = R0 % R1
		;	IN	R0, R1
		;   OUT R0
		UDIV		R2, R0, R1
		MUL         R2, R1, R2
        SUB         R0, R2
		BX		    LR
		ENDP

UpdateAndPrintTFTZeit PROC
        ; Diese Funktion aktualisiert ValOnDisplay gemäß in RO übergebenen
		; Zeitspanne in 10µs. Das Display wird aktualisiert.
		;	IN	R0		Aktuelle Zeitspanne in 10µs
		PUSH		{R4,R5,R6,LR}
		MOV			R1,#1000 
		UDIV		R4, R0, R1     ; R4 : Aktuelle Zeitspanne auf 1/100 s gerundet
        MOV			R5, #0	       ; R5 : Laufindex
WhileUpdateLoop					   ; while Schleife, die alle Stellen aktualisiert
		CMP			R5,#6				; while R5 < 6
		BEQ			WhileUpdateLoopEnd
WhileUpdateLoopBody
        ; Berechne Ziffer von Position R5
        ; Ziffer an Position R5 : (R4 % ModVal[R5]) / ModVal[R5 + 1]
        LDR         R6, =ModVal
        MOV         R0, R4
	    LDR         R1, [R6,R5, LSL #2]
	    BL          ModuloOp
	    ADD         R6,#4
	    LDR         R1, [R6,R5, LSL #2]
	    UDIV        R0, R1
        ; R0 enthält die neue Ziffer für Position R5
		LDR         R6, =ValOnDisplay
		LDRB		R1, [R6,R5]   ; R1 enthält alten Wert der Stelle
		CMP			R0, R1
		STRB        R0, [R6,R5]   ; neuen Wert der Stelle gespeichert
		; aktualisiere Stelle auf dem Display von neuer Wert
		MOV 		R0, R5
		BLNE		UpdateStelle
		ADD			R5, #1					; Erhöhe Laufindex
		B           WhileUpdateLoop
WhileUpdateLoopEnd		
		POP			{R4,R5,R6,PC}		; Restore Register und Ruecksprung
		ENDP

;****************************************************************************
; Finite State Machine

; Übergangsmatrix
;                      TAS5          TAS6         TAS7
; INIT_STATE	    INIT_STATE    INIT_STATE   RUNNING_STATE
; HOLD_STATE		INIT_STATE	  HOLD_STATE   RUNNING_STATE
; RUNNING_STATE		INIT_STATE    HOLD_STATE   RUNNING_STATE

FsmTransition		PROC
        ; Implementation der FSM Übergangsfunktion
		;	IN	R0		aktueller Zustand
		;	IN	R1		Belegung der Taster - maximal ein Taster ist gedrückt
		;	OUT	R0		neuer Zustand
ifHoldTaste
		CMP 	R1, #TAS6 
		BNE     endHoldTaste
thenHoldTaste
		; TAS6 gedrückt 
		CMP 	R0, #INIT_STATE
		MOVNE	R0, #HOLD_STATE ; TAS6 gedrückt und nicht im INIT State
endHoldTaste
		CMP 	R1, #TAS5   ; TAS5 gedrückt: Wechsel stets in den Zustand INIT
		MOVEQ	R0, #INIT_STATE
		CMP 	R1, #TAS7   ; TAS7 gedrückt: Wechsel stets in den Zustand RUNNING
		MOVEQ	R0, #RUNNING_STATE
		BX		LR
		ENDP

UpdateLEDs PROC
		; Setze LEDs gemäß aktuellem Zustand der FSM				
		;	IN	R0		Aktueller Zustand der FSM
		PUSH		{R4,LR}		
		MOV			R4, R0
		MOV			R0, #(LED_RUNNING + LED_HOLD)
		CMP			R4, #INIT_STATE           ; INIT STATE
		BLEQ		LEDsoff
		CMP			R4, #HOLD_STATE           ; HOLD STATE
		BLEQ		LEDson
		CMP			R4, #RUNNING_STATE        ; RUNNING STATE
		MOV			R0,#LED_RUNNING
		BLEQ		LEDson
		MOV			R0,#LED_HOLD
		BLEQ		LEDsoff
		POP			{R4,PC}	
		ENDP

main PROC
		; Initialisierung der HW
		BL		initITSboard
		ldr   	R0, =DEFAULT_BRIGHTNESS
		bl   	GUI_init
		bl  	initTimer
		ldr 	R1,=TIM2_PSC   			; Set pre scaler such that 1 timer tick represents 10 us
		mov 	R0,#(90*10-1) 
		strh	R0,[R1]
		ldr 	R1,=TIM2_ERG   			; Restart timer	
		mov		R0,#0x01
		strh	R0,[R1]					; Set UG Bit

		; Initialisierung der Uhr
		MOV 	R0, #24
		BL  	lcdSetFont
		BL 		InitTFT
		BL		UpdateUhr					; Damit TimeStamp einen sinnvollen Wert hat
		MOV 	R4, #0                      ; R4 : aktuelle gestoppte Zeitspanne in 10 µs Auflösung
		MOV 	R5, #INIT_STATE             ; R5 : aktueller Zustand	
superloop 
		; Aktualisierung der akutellen Zeitspanne Zeitspanne
		BL 		UpdateUhr
		ADD		R4, R0
		; lese Eingabe ein
		BL		LeseTaster
		MOV		R1, R0
		; Update Zustand
		MOV		R0,	R5
		BL	FsmTransition
		MOV 	R5, R0
		; INIT State => setze gestoppte Zeitspanne auf 0
		CMP		R5,#INIT_STATE
		MOVEQ	R4,#0
		; update LEDs
		MOV 	R0, R5
		BL 		UpdateLEDs
		; Wenn  im Zustand HOLD: aktualisierte TFT Uhrzeit nicht
		CMP		R5,#HOLD_STATE
		BEQ		superloop
		; Update and print TFTUhr, wenn sie sich geaendert hat
		MOV 	R0, R4
		BL UpdateAndPrintTFTZeit
		BAL		superloop				; End of superloop
		ENDP
	END ; text area
; EOF