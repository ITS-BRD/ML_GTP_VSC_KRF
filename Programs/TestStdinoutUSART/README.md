# Testprogramm zum Umlenken von stdout und stderr auf den USB-UART

- Das Nucleo-Board des ITS-Boards stellt auf den Entwicklungsrechner, der mit dem ITS-Board verbunden ist, ein USB-UART bereit. Der USB-UART ist mit UART3 des Nucleo-Boards verbunden.

- ITS-BRD-LIB lenkt stdout und strerr auf UART3 um. Somit kann z.B. die Ausgabe von printf über den USR-UART auf dem Entwicklungsrechner gelesen werden.

- Auf dem Entwicklungsrechner muss ein Serial-Terminal mit dem USB-UART verbunden werden. Es müssen folgende Einstellungen gewählt werden:
   - Port : Der USB-UART (oftmals stehen USB und / oder STM32 im Namen)
   - Baudrate : 115200
   - 8 Datenbits
   - 1 Stopbit
   - No Parity 

- Die VSCode Anwendung Serial-Monitor ist ein einfaches Serial-Terminal. Alternativ kann auch xterm oder ein vergleichbares Programm verwendet werden.

- Das Programm unter main.c zeigt die Verwendung von printf im einem Programm des ITS-Boards.
