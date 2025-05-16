;MASTER.S

#define __SFR_OFFSET 0x00
#include "avr/io.h"
;------------------------
.global init_ADC
.global init_serial
.global main
;=======================================================================
main:
    RCALL init_ADC         ; Initialize ADC for MQ sensor
    RCALL init_serial      ; Initialize UART for communication
    ;-------------------------------------------------------------------
loop:
    RCALL DHT11_sensor     ; Read temperature and humidity
    RCALL read_MQ_sensor   ; Read air quality from MQ sensor
    RCALL transmit_data    ; Send all data to slave Arduino
    RCALL delay_2s         ; Wait before next reading
    RJMP loop              ; Loop forever
;=======================================================================

DHT11_sensor:
;-----------------------------------------------------------------
    RCALL delay_2s      ;wait 2s for DHT11 to get ready
;-----------------------------------------------------------------
;start_signal
;------------
    SBI   DDRD, 7       ;pin PD7 as o/p
    CBI   PORTD, 7      ;first, send low pulse
    RCALL delay_20ms    ;for 20ms
    SBI   PORTD, 7      ;then send high pulse
;-----------------------------------------------------------------
;response signal
;---------------
    CBI   DDRD, 7       ;pin PD7 as i/p
w1: SBIC  PIND, 7
    RJMP  w1            ;wait for DHT11 low pulse
w2: SBIS  PIND, 7
    RJMP  w2            ;wait for DHT11 high pulse
w3: SBIC  PIND, 7
    RJMP  w3            ;wait for DHT11 low pulse
;-----------------------------------------------------------------
    RCALL DHT11_reading ;read humidity (1st byte of 40-bit data)
    MOV   R25, R24      ;store humidity in R25
    RCALL DHT11_reading ;read humidity decimal (2nd byte)
    RCALL DHT11_reading ;read temp (3rd byte of 40-bit data)
    MOV   R26, R24      ;store temperature in R26
    RCALL DHT11_reading ;read temp decimal (4th byte)
    RCALL DHT11_reading ;read checksum (5th byte)
    
    RET                 ;return to main
;=================================================================
DHT11_reading:
    LDI   R16, 8        ;set counter for receiving 8 bits
    CLR   R24           ;clear data register
    ;-------------------------------------------------------
w4: SBIS  PIND, 7
    RJMP  w4            ;detect data bit (high pulse)
    RCALL delay_timer0  ;wait 50us & then check bit value
    ;-------------------------------------------------------
    SBIS  PIND, 7       ;if received bit=1, skip next inst
    RJMP  skp           ;else, received bit=0, jump to skp
    SEC                 ;set carry flag (C=1)
    ROL   R24           ;shift in 1 into LSB data register
    RJMP  w5            ;jump & wait for low pulse
skp:LSL   R24           ;shift in 0 into LSB data register
    ;-------------------------------------------------------
w5: SBIC  PIND, 7
    RJMP  w5            ;wait for DHT11 low pulse
    ;-------------------------------------------------------
    DEC   R16           ;decrement counter
    BRNE  w4            ;go back & detect next bit
    RET                 ;return to calling subroutine
;=================================================================

read_MQ_sensor:
    ; Start ADC conversion
    LDI   R20, 0xC7       ;set ADSC in ADCSRA to start conversion
    STS   ADCSRA, R20
    ;-------------------------------------------------------------------
wait_ADC:
    LDS   R21, ADCSRA     ;check ADIF flag in ADCSRA
    SBRS  R21, 4          ;skip jump when conversion is done (flag set)
    RJMP  wait_ADC        ;loop until ADIF flag is set
    ;------------------------------------------------------------------
    LDI   R17, 0xD7       ;set ADIF flag again
    STS   ADCSRA, R17     ;so that controller clears ADIF
    ;------------------------------------------------------------------
    LDS   R16, ADCL       ;get low-byte result from ADCL
    LDS   R27, ADCH       ;get high-byte result from ADCH, store in R27
    ;------------------------------------------------------------------
    RET
;=================================================================

transmit_data:
    ; Send start marker
    LDI   R18, '<'        ; Start marker
    RCALL send_byte
    
    ; Send humidity (R25)
    MOV   R18, R25
    RCALL send_byte
    
    ; Send temperature (R26)
    MOV   R18, R26
    RCALL send_byte
    
    ; Send air quality (R27)
    MOV   R18, R27
    RCALL send_byte
    
    ; Send end marker
    LDI   R18, '>'        ; End marker
    RCALL send_byte
    
    RET
;=================================================================

send_byte:
    ; Wait for UART data register to be empty
send_wait:
    LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ; Skip if UART Data Register Empty flag is set
    RJMP  send_wait
    
    ; Send byte
    STS   UDR0, R18
    RET
;=================================================================

init_ADC:
    CBI   DDRC, 0         ;set pin PC0 as i/p for ADC0
    LDI   R20, 0xC0       ;internal 2.56V, right-justified data, ADC0
    STS   ADMUX, R20
    LDI   R20, 0x87       ;enable ADC, ADC prescaler CLK/128
    STS   ADCSRA, R20
    RET
;-----------------------------------------------------------------------
init_serial:
    CLR   R24
    STS   UCSR0A, R24     ;clear UCSR0A register
    STS   UBRR0H, R24     ;clear UBRR0H register
    LDI   R24, 103        ;& store in UBRR0L 103
    STS   UBRR0L, R24     ;to set baud rate 9600
    LDI   R24, 1<<RXEN0 | 1<<TXEN0
    STS   UCSR0B, R24     ;enable RXB & TXB
    LDI   R24, 1<<UCSZ00 | 1<<UCSZ01
    STS   UCSR0C, R24     ;asynch, no parity, 1 stop, 8 bits
    RET
;-----------------------------------------------------------------------
;delay subroutines
;=================================================================
delay_20ms:             ;delay 20ms
    LDI   R21, 255
l3: LDI   R22, 210
l4: LDI   R23, 2
l5: DEC   R23
    BRNE  l5
    DEC   R22
    BRNE  l4
    DEC   R21
    BRNE  l3
    RET
;-----------------------------------------------------------------
delay_2s:               ;delay 2s
    LDI   R21, 255
l6: LDI   R22, 255
l7: LDI   R23, 164
l8: DEC   R23
    BRNE  l8
    DEC   R22
    BRNE  l7
    DEC   R21
    BRNE  l6
    RET
;===============================================================
delay_timer0:             ;50 usec delay via Timer 0
    ;---------------------------------------------------------
    CLR   R20
    OUT   TCNT0, R20      ;initialize timer0 with count=0
    LDI   R20, 100
    OUT   OCR0A, R20      ;OCR0 = 100
    LDI   R20, 0b00001010
    OUT   TCCR0B, R20     ;timer0: CTC mode, prescaler 64
    ;---------------------------------------------------------
l2: IN    R20, TIFR0      ;get TIFR0 byte & check
    SBRS  R20, OCF0A      ;if OCF0=1, skip next instruction
    RJMP  l2              ;else, loop back & check OCF0 flag
    ;---------------------------------------------------------
    CLR   R20
    OUT   TCCR0B, R20     ;stop timer0
    ;---------------------------------------------------------
    LDI   R20, (1<<OCF0A)
    OUT   TIFR0, R20      ;clear OCF0 flag
    RET
;===============================================================