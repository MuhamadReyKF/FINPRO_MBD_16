#define __SFR_OFFSET 0x20
#include "avr/io.h"

.global main
main:
    ; Init UART 9600bps @ 16MHz
    LDI R16, 103
    STS UBRR0L, R16
    LDI R16, (1<<TXEN0)
    STS UCSR0B, R16
    LDI R16, (1<<UCSZ01)|(1<<UCSZ00)
    STS UCSR0C, R16

    ; Init ADC
    LDI R16, (1<<REFS0)       ; AVcc ref
    STS ADMUX, R16
    LDI R16, (1<<ADEN)
    STS ADCSRA, R16

main_loop:
    RCALL delay_2s

    ; Read DHT11
    RCALL DHT11_reading
    MOV R20, R18
    RCALL send_uart

    ; Read MQ sensor (ADC0)
    RCALL read_adc
    MOV R20, R18
    RCALL send_uart

    RJMP main_loop

; Send UART subroutine
send_uart:
    LDS R16, UCSR0A
    SBRS R16, UDRE0
    RJMP send_uart
    STS UDR0, R20
    RET

; Read ADC0 subroutine
read_adc:
    LDS R16, ADCSRA
    ORI R16, (1<<ADSC)
    STS ADCSRA, R16
adc_wait:
    LDS R16, ADCSRA
    SBRC R16, ADSC
    RJMP adc_wait
    LDS R18, ADCH
    RET

; DHT11_reading
DHT11_reading:
    LDI   R17, 8
    CLR   R18
w4:
    IN    R16, PINB
    SBRS  R16, 1
    RJMP  w4
    RCALL delay_timer0
    IN    R16, PINB
    SBRS  R16, 1
    RJMP  skp
    SEC
    ROL   R18
    RJMP  w5
skp:
    LSL   R18
w5:
    IN    R16, PINB
    SBRC  R16, 1
    RJMP  w5
    DEC   R17
    BRNE  w4
    RET

; Delay 2s
delay_2s:
    LDI R21, 255
l6: LDI R22, 255
l7: LDI R23, 164
l8: DEC R23
    BRNE l8
    DEC R22
    BRNE l7
    DEC R21
    BRNE l6
    RET

; Timer delay ~70us
delay_timer0:
    CLR R20
    STS TCNT0, R20
    LDI R20, 100
    STS OCR0A, R20
    LDI R20, 0b00001010
    STS TCCR0B, R20
l2: LDS R20, TIFR0
    SBRS R20, OCF0A
    RJMP l2
    CLR R20
    STS TCCR0B, R20
    LDI R20, (1<<OCF0A)
    STS TIFR0, R20
    RET