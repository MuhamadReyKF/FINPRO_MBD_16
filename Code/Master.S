#define __SFR_OFFSET 0x00
#include "avr/io.h"
;------------------------
.global init_ADC
.global init_serial
.global main
;=======================================================================
main:
    RCALL init_ADC        ; Initialize ADC for MQ sensor
    RCALL init_serial     ; Initialize UART communication
    ;-------------------------------------------------------------------
loop:
    RCALL DHT11_sensor    ; Read temperature and humidity
    RCALL read_MQ_sensor  ; Read air quality sensor
    RCALL send_data       ; Send data to slave Arduino
    RCALL delay_2s        ; Wait before next reading
    RJMP  loop            ; Repeat
;=======================================================================

DHT11_sensor:
;-----------------------------------------------------------------
    RCALL delay_2s        ; Wait 2s for DHT11 to get ready
;-----------------------------------------------------------------
;start_signal
;------------
    SBI   DDRD, 7         ; Pin PD7 as o/p
    CBI   PORTD, 7        ; First, send low pulse
    RCALL delay_20ms      ; For 20ms
    SBI   PORTD, 7        ; Then send high pulse
;-----------------------------------------------------------------
;response signal
;---------------
    CBI   DDRD, 7         ; Pin PD7 as i/p
w1: SBIC  PIND, 7
    RJMP  w1              ; Wait for DHT11 low pulse
w2: SBIS  PIND, 7
    RJMP  w2              ; Wait for DHT11 high pulse
w3: SBIC  PIND, 7
    RJMP  w3              ; Wait for DHT11 low pulse
;-----------------------------------------------------------------
    RCALL DHT11_reading   ; Read humidity (1st byte of 40-bit data)
    MOV   R25, R24        ; Store humidity in R25
    RCALL DHT11_reading   ; Skip checksum byte
    RCALL DHT11_reading   ; Read temp (3rd byte of 40-bit data)
                          ; Temperature now in R24
    RET
;=================================================================
DHT11_reading:
    LDI   R16, 8          ; Set counter for receiving 8 bits
    CLR   R24             ; Clear data register
    ;-------------------------------------------------------
w4: SBIS  PIND, 7
    RJMP  w4              ; Detect data bit (high pulse)
    RCALL delay_timer0    ; Wait 50us & then check bit value
    ;-------------------------------------------------------
    SBIS  PIND, 7         ; If received bit=1, skip next inst
    RJMP  skp             ; Else, received bit=0, jump to skp
    SEC                   ; Set carry flag (C=1)
    ROL   R24             ; Shift in 1 into LSB data register
    RJMP  w5              ; Jump & wait for low pulse
skp:LSL   R24             ; Shift in 0 into LSB data register
    ;-------------------------------------------------------
w5: SBIC  PIND, 7
    RJMP  w5              ; Wait for DHT11 low pulse
    ;-------------------------------------------------------
    DEC   R16             ; Decrement counter
    BRNE  w4              ; Go back & detect next bit
    RET                   ; Return to calling subroutine
;=================================================================
read_MQ_sensor:
    LDI   R20, 0xC7       ; Set ADSC in ADCSRA to start conversion
    STS   ADCSRA, R20
    ;-------------------------------------------------------------------
wait_ADC:
    LDS   R21, ADCSRA     ; Check ADIF flag in ADCSRA
    SBRS  R21, 4          ; Skip jump when conversion is done (flag set)
    RJMP  wait_ADC        ; Loop until ADIF flag is set
    ;------------------------------------------------------------------
    LDI   R17, 0xD7       ; Set ADIF flag again
    STS   ADCSRA, R17     ; So that controller clears ADIF
    ;------------------------------------------------------------------
    LDS   R16, ADCL       ; Get low-byte result from ADCL
    LDS   R26, ADCH       ; Get high-byte result from ADCH, store in R26
    ;------------------------------------------------------------------
    RET
;=================================================================
send_data:
    ; Send temperature
    MOV   R18, R24        ; Move temperature to R18
    ;-----------------------------------------------------------------
send_temp:
    LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ; Test if data buffer ready
    RJMP  send_temp
    ;-----------------------------------------------------------------
    STS   UDR0, R18       ; Send temperature byte
    ;-----------------------------------------------------------------
    
    ; Send humidity
    MOV   R18, R25        ; Move humidity to R18
    ;-----------------------------------------------------------------
send_hum:
    LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ; Test if data buffer ready
    RJMP  send_hum
    ;-----------------------------------------------------------------
    STS   UDR0, R18       ; Send humidity byte
    ;-----------------------------------------------------------------
    
    ; Send air quality (MQ sensor value)
    MOV   R18, R26        ; Move air quality to R18
    ;-----------------------------------------------------------------
send_aq:
    LDS   R17, UCSR0A
    SBRS  R17, UDRE0      ; Test if data buffer ready
    RJMP  send_aq
    ;-----------------------------------------------------------------
    STS   UDR0, R18       ; Send air quality byte
    ;-----------------------------------------------------------------
    RET
;=================================================================
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