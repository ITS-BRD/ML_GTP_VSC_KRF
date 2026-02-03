/**
  ******************************************************************************
  * @file    main.c
  * @author  Franz Korf
  * @brief   Small test for redirection of stdout and stderr to USB-UART.
  ******************************************************************************
  */
/* Includes ------------------------------------------------------------------*/

#include "init.h"
#include "LCD_GUI.h"
#include "LCD_Touch.h"
#include "lcd.h"
#include <stdio.h>
#include <stm32f4xx_ll_usart.h>

int main(void) {
	initITSboard(); // ITS-board initialization, including redirection of strerr and stdout
	GUI_init(DEFAULT_BRIGHTNESS);  
	TP_Init(false);

	lcdPrintlnS("Hallo liebes TI-Labor (c-project)");
	HAL_Delay(10000);
	printf("Hallo liebes TI-Labor (c-project)\n");
	int i = 0;
	while(1) {
		printf("i = %d (float) i / 10 = %f\n", i, ((float) i) / 10);
		lcdPrintInt(i);
		lcdPrintlnS("");
		i++;
		HAL_Delay(3000);
	}
}

// EOF
