;SLAVE.S

#define __SFR_OFFSET 0x00
#include "avr/io.h"
;------------------------
.global init_serial
.global print_data
.global main
;=======================================================================
; Constants for air quality thresholds
.equ GREEN_THRESHOLD, 30   ; Good air quality threshold
.equ YELLOW_THRESHOLD, 60  ; Medium air quality threshold
.equ RED_THRESHOLD, 90     ; Above this is poor air quality (RED)

; Pin definitions
.equ GREEN_LED, 2   ; PB2 for green LED
.equ YELLOW_LED, 3  ; PB3 for yellow LED
.equ RED_LED, 4     ; PB4 for red LED
.equ BUZZER, 1      ; PB1 for buzzer
;=======================================================================
main:
    RCALL init_io        ; Initialize I/O pins
    RCALL init_serial    ; Initialize UART for receiving data
    ;-------------------------------------------------------------------
loop:
    RCALL receive_data   ; Receive data from master Arduino
    RCALL update_leds    ; Update LED indicators based on air quality
    RCALL print_data     ; Print data to serial monitor
    RCALL delay_sec      ; Short delay
    RJMP loop            ; Loop forever
;=======================================================================

init_io:
    ; Set LED pins and buzzer as outputs
    SBI   DDRB, GREEN_LED
    SBI   DDRB, YELLOW_LED
    SBI   DDRB, RED_LED
    SBI   DDRB, BUZZER
    
    ; Initially turn off all LEDs and buzzer
    CBI   PORTB, GREEN_LED
    CBI   PORTB, YELLOW_LED
    CBI   PORTB, RED_LED
    CBI   PORTB, BUZZER
    
    RET
;=======================================================================

; Data storage
.lcomm humidity, 1       ; Store humidity value
.lcomm temperature, 1    ; Store temperature value
.lcomm air_quality, 1    ; Store air quality value

receive_data:
    ; Wait for start marker '<'
    RCALL receive_until_start
    
    ; Receive humidity
    RCALL receive_byte
    STS   humidity, R24
    
    ; Receive temperature
    RCALL receive_byte
    STS   temperature, R24
    
    ; Receive air quality
    RCALL receive_byte
    STS   air_quality, R24
    
    ; Wait for end marker '>'
    RCALL receive_until_end
    
    RET
;=======================================================================

receive_until_start:
    ; Wait for '<' character
start_wait:
    RCALL receive_byte   ; Get a byte
    CPI   R24, '<'       ; Is it the start marker?
    BRNE  start_wait     ; If not, keep waiting
    RET
;=======================================================================

receive_until_end:
    ; Wait for '>' character
end_wait:
    RCALL receive_byte   ; Get a byte
    CPI   R24, '>'       ; Is it the end marker?
    BRNE  end_wait       ; If not, keep waiting
    RET
;=======================================================================

receive_byte:
    ; Wait for incoming data
rx_wait:
    LDS   R16, UCSR0A
    SBRS  R16, RXC0      ; Skip if data received
    RJMP  rx_wait
    
    ; Get received byte
    LDS   R24, UDR0
    RET
;=======================================================================

update_leds:
    ; Get air quality value
    LDS   R16, air_quality
    
    ; Turn off all LEDs initially
    CBI   PORTB, GREEN_LED
    CBI   PORTB, YELLOW_LED
    CBI   PORTB, RED_LED
    CBI   PORTB, BUZZER
    
    ; Check thresholds and set appropriate LED
    CPI   R16, GREEN_THRESHOLD
    BRSH  check_yellow   ; If ≥ GREEN_THRESHOLD, check for yellow
    
    ; Air quality is good (green)
    SBI   PORTB, GREEN_LED
    RET
    
check_yellow:
    CPI   R16, YELLOW_THRESHOLD
    BRSH  set_red        ; If ≥ YELLOW_THRESHOLD, set red
    
    ; Air quality is medium (yellow)
    SBI   PORTB, YELLOW_LED
    RET
    
set_red:
    ; Air quality is poor (red + buzzer)
    SBI   PORTB, RED_LED
    SBI   PORTB, BUZZER  ; Turn on buzzer for poor air quality
    RET
;=======================================================================

; Serial printing routines
print_data:
    ; Print header
    LDI   R24, 'T'
    RCALL print_char
    LDI   R24, ':'
    RCALL print_char
    LDI   R24, ' '
    RCALL print_char
    
    ; Print temperature
    LDS   R24, temperature
    RCALL print_decimal
    
    ; Print degree C
    LDI   R24, 'C'
    RCALL print_char
    LDI   R24, ' '
    RCALL print_char
    
    ; Print humidity section
    LDI   R24, 'H'
    RCALL print_char
    LDI   R24, ':'
    RCALL print_char
    LDI   R24, ' '
    RCALL print_char
    
    ; Print humidity
    LDS   R24, humidity
    RCALL print_decimal
    
    ; Print percent
    LDI   R24, '%'
    RCALL print_char
    LDI   R24, ' '
    RCALL print_char
    
    ; Print air quality section
    LDI   R24, 'A'
    RCALL print_char
    LDI   R24, 'Q'
    RCALL print_char
    LDI   R24, ':'
    RCALL print_char
    LDI   R24, ' '
    RCALL print_char
    
    ; Print air quality value
    LDS   R24, air_quality
    RCALL print_decimal
    
    ; Print air quality category
    LDS   R16, air_quality
    
    LDI   R24, ' '
    RCALL print_char
    LDI   R24, '('
    RCALL print_char
    
    CPI   R16, GREEN_THRESHOLD
    BRSH  print_check_yellow
    
    ; Print "Good"
    LDI   R24, 'G'
    RCALL print_char
    LDI   R24, 'o'
    RCALL print_char
    LDI   R24, 'o'
    RCALL print_char
    LDI   R24, 'd'
    RCALL print_char
    RJMP  print_category_end
    
print_check_yellow:
    CPI   R16, YELLOW_THRESHOLD
    BRSH  print_poor
    
    ; Print "Medium"
    LDI   R24, 'M'
    RCALL print_char
    LDI   R24, 'e'
    RCALL print_char
    LDI   R24, 'd'
    RCALL print_char
    LDI   R24, 'i'
    RCALL print_char
    LDI   R24, 'u'
    RCALL print_char
    LDI   R24, 'm'
    RCALL print_char
    RJMP  print_category_end
    
print_poor:
    ; Print "Poor"
    LDI   R24, 'P'
    RCALL print_char
    LDI   R24, 'o'
    RCALL print_char
    LDI   R24, 'o'
    RCALL print_char
    LDI   R24, 'r'
    RCALL print_char
    
print_category_end:
    LDI   R24, ')'
    RCALL print_char
    
    ; Print newline
    LDI   R24, 0x0D  ; CR
    RCALL print_char
    LDI   R24, 0x0A  ; LF
    RCALL print_char
    
    RET
;=======================================================================

print_char:
    ; Wait until UART data register is empty
print_wait:
    LDS   R17, UCSR0A
    SBRS  R17, UDRE0
    RJMP  print_wait
    
    ; Send character
    STS   UDR0, R24
    RET
;=======================================================================

print_decimal:
    ; R24 contains the value to print
    MOV   R16, R24       ; Copy value
    CLR   R17            ; Hundreds digit
    CLR   R18            ; Tens digit
    
hundreds_loop:
    CPI   R16, 100
    BRLO  tens_loop      ; If < 100, move to tens
    SUBI  R16, 100
    INC   R17
    RJMP  hundreds_loop
    
tens_loop:
    CPI   R16, 10
    BRLO  print_digits   ; If < 10, ready to print
    SUBI  R16, 10
    INC   R18
    RJMP  tens_loop
    
print_digits:
    ; R17 = hundreds, R18 = tens, R16 = ones
    
    ; Only print hundreds if non-zero
    CPI   R17, 0
    BREQ  skip_hundreds
    
    ; Print hundreds digit
    MOV   R24, R17
    SUBI  R24, -48       ; Convert to ASCII
    RCALL print_char
    
skip_hundreds:
    ; Only print tens if hundreds or tens is non-zero
    CPI   R17, 0
    BRNE  print_tens     ; If hundreds non-zero, print tens
    CPI   R18, 0
    BREQ  skip_tens      ; If both hundreds and tens are zero, skip tens
    
print_tens:
    ; Print tens digit
    MOV   R24, R18
    SUBI  R24, -48       ; Convert to ASCII
    RCALL print_char
    
skip_tens:
    ; Always print ones digit
    MOV   R24, R16
    SUBI  R24, -48       ; Convert to ASCII
    RCALL print_char
    
    RET
;=======================================================================

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

delay_sec:                ;1s delay
    LDI   R20, 255
l14: LDI   R21, 255
l15: LDI   R22, 80
l16: DEC   R22
    BRNE  l16
    DEC   R21
    BRNE  l15
    DEC   R20
    BRNE  l14
    RET
;----------------------------------------------------------------------