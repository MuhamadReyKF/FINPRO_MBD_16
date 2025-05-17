#define __SFR_OFFSET 0x00
#include "avr/io.h"
;------------------------
.global init_serial
.global main
;=======================================================================
main:
    RCALL init_serial        ; Initialize UART for receiving data
    RCALL init_indicators    ; Initialize LED indicators and buzzer
    RCALL SPI_MAX7219_init   ; Initialize MAX7219 display
    ;-------------------------------------------------------------------
loop:
    RCALL receive_data       ; Receive data from master Arduino
    RCALL update_display     ; Update MAX7219 display
    RCALL update_indicators  ; Update LED indicators and buzzer
    RJMP  loop               ; Repeat
;=======================================================================

init_indicators:
    SBI   DDRB, 1           ; Set PB1 as output for buzzer
    SBI   DDRD, 2           ; Set PD2 as output for green LED
    SBI   DDRD, 3           ; Set PD3 as output for yellow LED  
    SBI   DDRD, 4           ; Set PD4 as output for red LED
    CBI   PORTB, 1          ; Initialize buzzer off
    CBI   PORTD, 2          ; Initialize green LED off
    CBI   PORTD, 3          ; Initialize yellow LED off
    CBI   PORTD, 4          ; Initialize red LED off
    RET
;=======================================================================

receive_data:
    ; Receive temperature byte
    ;-----------------------------------------------------------------
wait_temp:
    LDS   R17, UCSR0A
    SBRS  R17, RXC0         ; Wait for data to be received
    RJMP  wait_temp
    ;-----------------------------------------------------------------
    LDS   R24, UDR0         ; Store received temperature in R24
    ;-----------------------------------------------------------------
    
    ; Receive humidity byte
    ;-----------------------------------------------------------------
wait_hum:
    LDS   R17, UCSR0A
    SBRS  R17, RXC0         ; Wait for data to be received
    RJMP  wait_hum
    ;-----------------------------------------------------------------
    LDS   R25, UDR0         ; Store received humidity in R25
    ;-----------------------------------------------------------------
    
    ; Receive air quality byte
    ;-----------------------------------------------------------------
wait_aq:
    LDS   R17, UCSR0A
    SBRS  R17, RXC0         ; Wait for data to be received
    RJMP  wait_aq
    ;-----------------------------------------------------------------
    LDS   R26, UDR0         ; Store received air quality in R26
    ;-----------------------------------------------------------------
    RET
;=======================================================================

update_display:
    ; Convert temperature to decimal and display on MAX7219
    MOV   R28, R24         ; Move temperature to R28
    LDI   R29, 0x07        ; Select digit 6
    LDI   R30, 0x06        ; Select digit 5
    RCALL binary2decimal   ; Convert and display temp
    
    ; Convert humidity to decimal and display on MAX7219
    MOV   R28, R25         ; Move humidity to R28
    LDI   R29, 0x02        ; Select digit 1 
    LDI   R30, 0x01        ; Select digit 0
    RCALL binary2decimal   ; Convert and display humidity
    
    ; Display labels (t, C, h)
    LDI   R17, 0x08        ; Select digit 7
    LDI   R18, 0x0F        ; Data = t
    RCALL send_bytes       ; Send to MAX7219
    
    LDI   R17, 0x05        ; Select digit 4
    LDI   R18, 0x4E        ; Data = C
    RCALL send_bytes       ; Send to MAX7219
    
    LDI   R17, 0x04        ; Select digit 3
    LDI   R18, 0x00        ; Data = space
    RCALL send_bytes       ; Send to MAX7219
    
    LDI   R17, 0x03        ; Select digit 2
    LDI   R18, 0x17        ; Data = h
    RCALL send_bytes       ; Send to MAX7219
    
    RET
;=======================================================================

update_indicators:
    ; Check air quality threshold and update LEDs/buzzer
    CPI   R26, 50          ; Check if air quality < 50 (good)
    BRLO  good_air
    
    CPI   R26, 70          ; Check if air quality < 70 (moderate)
    BRLO  moderate_air
    
    ; Poor air quality
    SBI   PORTD, 4         ; Turn on red LED
    CBI   PORTD, 3         ; Turn off yellow LED
    CBI   PORTD, 2         ; Turn off green LED
    SBI   PORTB, 1         ; Turn on buzzer
    RET
    
moderate_air:
    CBI   PORTD, 4         ; Turn off red LED
    SBI   PORTD, 3         ; Turn on yellow LED
    CBI   PORTD, 2         ; Turn off green LED
    CBI   PORTB, 1         ; Turn off buzzer
    RET
    
good_air:
    CBI   PORTD, 4         ; Turn off red LED
    CBI   PORTD, 3         ; Turn off yellow LED
    SBI   PORTD, 2         ; Turn on green LED
    CBI   PORTB, 1         ; Turn off buzzer
    RET
;=======================================================================

init_serial:
    CLR   R24
    STS   UCSR0A, R24     ; Clear UCSR0A register
    STS   UBRR0H, R24     ; Clear UBRR0H register
    LDI   R24, 103        ; Store in UBRR0L 103
    STS   UBRR0L, R24     ; To set baud rate 9600
    LDI   R24, 1<<RXEN0 | 1<<TXEN0
    STS   UCSR0B, R24     ; Enable RXB & TXB
    LDI   R24, 1<<UCSZ00 | 1<<UCSZ01
    STS   UCSR0C, R24     ; Asynch, no parity, 1 stop, 8 bits
    RET
;=======================================================================
;MAX7219 subroutines
;=======================================================================
SPI_MAX7219_init:
;----------------
.equ  SCK, 5
.equ  MOSI, 3
.equ  SS, 2
;--------------------------------------------------------------
    LDI   R17, (1<<MOSI)|(1<<SCK)|(1<<SS)
    OUT   DDRB, R17       ; Set MOSI, SCK, SS as o/p
    ;--------------------------------------------------------
    LDI   R17, (1<<SPE)|(1<<MSTR)|(1<<SPR0)
    OUT   SPCR, R17       ; Enable SPI as master, fsck=fosc/16
    ;--------------------------------------------------------
    LDI   R17, 0x0A       ; Set segment intensity (0 to 15)
    LDI   R18, 8          ; Intensity level = 8
    RCALL send_bytes      ; Send command & data to MAX7219
    ;--------------------------------------------------------
    LDI   R17, 0x09       ; Set decoding mode command
    LDI   R18, 0b01100011 ; Decoding byte
    RCALL send_bytes      ; Send command & data to MAX7219
    ;--------------------------------------------------------
    LDI   R17, 0x0B       ; Set scan limit command
    LDI   R18, 0x07       ; 8 digits connected to MAX7219
    RCALL send_bytes      ; Send command & data to MAX7219
    ;--------------------------------------------------------
    LDI   R17, 0x0C       ; Set turn ON/OFF command
    LDI   R18, 0x01       ; Turn ON MAX7219
    RCALL send_bytes      ; Send command & data to MAX7219
    ;--------------------------------------------------------
    RET
;=======================================================================
send_bytes:
    CBI   PORTB, SS       ; Enable slave device MAX7219
    OUT   SPDR, R17       ; Transmit command
    ;--------------------------------------------------------
ll2:IN    R19, SPSR
    SBRS  R19, SPIF       ; Wait for byte transmission
    RJMP  ll2             ; To complete
    ;--------------------------------------------------------
    OUT   SPDR, R18       ; Transmit data
    ;--------------------------------------------------------
ll3:IN    R19, SPSR
    SBRS  R19, SPIF       ; Wait for byte transmission
    RJMP  ll3             ; To complete
    ;--------------------------------------------------------
    SBI   PORTB, SS       ; Disable slave device MAX7219
    RET
;=======================================================================
binary2decimal:
;--------------
    CLR   R26             ; Set counter1, initial value 0
    CLR   R27             ; Set counter2, initial value 0
    ;--------------------------------------------------------
l70:CPI   R28, 100        ; Compare R28 with 100
    BRMI  l80             ; Jump when R28 < 100
    INC   R26             ; Increment counter1 by 1
    SUBI  R28, 100        ; R28 = R28 - 100
    RJMP  l70
    ;--------------------------------------------------------
l80:CPI   R28, 10         ; Compare R28 with 10
    BRMI  dsp             ; Jump when R28 < 10
    INC   R27             ; Increment counter2 by 1
    SUBI  R28, 10         ; R28 = R28 - 10
    RJMP  l80
    ;--------------------------------------------------------  
dsp:MOV   R18, R27
    MOV   R17, R29        ; Select digit
    RCALL send_bytes      ; Send command & data to MAX7219
    ;--------------------------------------------------------
    MOV   R18, R28
    MOV   R17, R30        ; Select digit
    RCALL send_bytes      ; Send command & data to MAX7219    
    ;--------------------------------------------------------
    RET