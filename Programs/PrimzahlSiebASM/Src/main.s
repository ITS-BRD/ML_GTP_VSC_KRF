;******************** (C) COPYRIGHT HAW-Hamburg ********************************
;* File Name          : main.s
;* Author             : Franz Korf	
;* Date               : 28.04.2017
;* Description        : Musterloesung Sieb Primzahlen Assembler (Aufgabe Woche 
;                       4 bis 6 in GT). Der Assembler Code wurde aus einem in C 
;                       geschriebenen Sieb manuell erzeugt.
;
;*******************************************************************************
	EXTERN initITSboard        	; Initialize ITS board
	EXTERN GUI_init             ; Initialize GUI
	EXTERN lcdPrintS            ; Print string to LCD

;********************************************
; MARCOS according to C preprocessor syntax
;********************************************
MAX             EQU	1000       	; Groesste Zahl des Primzahl Siebs
SIZE_PRIM_FELD  EQU	(MAX/2)    	; Anzahl der Elemente des Felds, das die Primzahlen speichert
NO_PRIM         EQU	0         	; Ist keine Primzahl
PRIM            EQU 1         	; Ist Primzahl bzw. wurde noch nicht ausgesiebt
	
;********************************************
; Data section, aligned on 4-byte boundery
;********************************************
			AREA MyData, DATA, align = 2 
sieb 		FILL	2    , NO_PRIM, 1		; Sieb Feld fuer die Primzahlen. sieb[i] zeigt an, ob i
     		FILL	MAX-1, PRIM,    1		; eine Primpahl ist. Daher sind sieb[0] und sieb[1] 
											; mit NO_PRIM initialisiert.
											; Am Anfang werden alle Zahlen als Primzahlen angesehen 
											; und dann werden die Nicht-Primzahlen ausgesiebt.
				
			ALIGN
primFeld 	FILL	4*SIZE_PRIM_FELD, 0, 4	; Das primFeld besteht aus SIZE_PRIM_FELD Worten, 
											; die mit 0 initialisiert sind. Ein Feldelement ist 
											; 4 Byte groß.
			
myText		DCB		"Schaue primFeld in Memory Browser an.", 0

;********************************************
; Code section, aligned on 8-byte boundery
;********************************************
			AREA |.text|, CODE, READONLY, ALIGN = 3

;--------------------------------------------
; main subroutine
;--------------------------------------------
			EXPORT main [CODE]

main 		PROC
;********************************************
; Setup Hardware
;********************************************	
			BL	initITSboard               	; Initialize ITS Board
			LDR R0,=800                     ; BRIGHTNESS of LCD
			BL  GUI_init                    ; Initialize LCD (without Touch)

;********************************************
; Die Felder sieb und primFeld  wurde schon beim Anlegen initialisiert.
;********************************************

;********************************************
; Code Sequenz zum Sieben
;********************************************
			; Registerbelegung
			MOV		R0,#2			; Laufindex f¸r das Sieb (n)
			MOV 	R1,#NO_PRIM		; Konstante, da keine Konstante im LDR Befehl mˆglich 
			LDR 	R2,=MAX  		; Index des groessten Elements des Siebs , Ìm Register, damit beliebiger Wert moeglich
			;       R3 				; Lokaler Laufindex lauf
			LDR 	R4,=sieb		; Basis Register zum Zugriff auf das Sieb
			;		R6				; Hilfsregister

while_1		; while ((n * n) <= MAX) // (R0 * R0 <= R2)
			MUL 	R6, R0, R0
			CMP 	R6, R2			; Springe bei !(R1 <= R2) aus der Schleife
			BHI 	while_end_1		; !(R6 <= R2) <=> (R6 > R2) <=> (R6 - R2) > 0 <=> (Z == 0) && (C == 1)
while_body_1
if_1		; if (sieb[n] == PRIM) : Ein ausgesiebte Zahl muss nicht betrachtet werden
			LDRB 	R6, [R4,R0]
			CMP 	R6, #NO_PRIM	; Bei sieb[R0] == N0_PRIM springe ans Ende des if Statements
			BEQ 	fi_1
then_1		
			MUL 	R3,R0,R0       	; siebe ab n * n;
while_2		; while (lauf <= MAX)
			CMP 	R3, R2			; Springe bei !(R3 <= R2) aus der Schleife
			BHI 	while_end_2		; !(R3 <= R2) <=> (R3 > R2) <=> (R3 - R2) > 0 <=> (Z == 0) && (C == 1)
while_body_2
			STRB 	R1,[R4,R3]		; siebe R3 raus
			ADD 	R3, R0 			; naechste zu siebende Zahl
			BAL 	while_2
while_end_2
fi_1
			ADD 	R0,#1			; naechste Zahl, die untersucht werden soll
			BAL 	while_1
while_end_1

;********************************************
; Fuelle das primFeld mit den Primzahlen
;********************************************
			; Registerbelegung
			MOV		R0,#0			; Laufindex f¸r das Sieb
									; R1 : tmp Variable
			LDR 	R2,=MAX  		; Index des groessten Elements aus sieb
			LDR 	R4,=sieb		; Basis Register zum Zugriff auf das Sieb
			LDR 	R5,=primFeld	; Naechtes freies Element in primFeld

while_3		; while (R0 <= MAX) wobei MAX in R2 steht
			CMP 	R0,R2			; Springe bei !(R0 <= R2) aus der Schleife
			BHI 	while_end_3		; !(R0 <= MAX) <=> (R0 > MIX) <=> (R0 - MAX) > 0 <=> (Z == 0) && (C == 1)
while_body_3
if_2		; if (sieb[R0] == PRIM) : Primzahl R0 wird in primFeld geschrieben 
			LDRB 	R1,[R4,R0]
			CMP 	R1,#NO_PRIM
			BEQ 	fi_2
then_2		STR 	R0,[R5],#4*1
fi_2
			ADD 	R0,#1
			BAL 	while_3
while_end_3

;********************************************
; Programm fertig
;********************************************
			LDR 	R0,=myText
			BL		 lcdPrintS
		
forever		B		forever			; nowhere to retun if main ends		
		ENDP
		ALIGN
		END
; EOF
