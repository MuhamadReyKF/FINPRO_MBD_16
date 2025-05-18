#define __SFR_OFFSET 0
#include <avr/io.h>

; Define constants
.equ GREEN_LED_PIN, 2
.equ YELLOW_LED_PIN, 3
.equ RED_LED_PIN, 4
.equ BUZZER_PIN, 5

.equ I2C_SLAVE_ADDR, 8

; SRAM variables
.section .data
temperature:      .space 2
humidity:         .space 2
airQuality:       .space 2
airQualityStatus: .space 1
independentTest:  .space 1
buffer:           .space 10

; Code section
.section .text

; --- Reset Vector ---
.org 0x0000
rjmp main

; --- TWI (I2C) Interrupt Vector ---
.org 0x0028       ; For ATmega328p, TWI interrupt vector address is 0x28 (decimal 40)
rjmp TWI_vect

; Default interrupt handler (just reti)
.org 0x0040
default_interrupt:
reti

; --- Main program ---
.global main
main:
    ; Initialize stack pointer
    ldi r16, hi8(RAMEND)
    out SPH, r16
    ldi r16, lo8(RAMEND)
    out SPL, r16

    ; Clear independentTest flag
    ldi r16, 0
    sts independentTest, r16

    ; Initialize UART 9600 baud for debug
    rcall uart_init

    ; Initialize I2C slave
    rcall i2c_init

    ; Configure LED and buzzer pins as outputs
    ldi r16, (1<<GREEN_LED_PIN)|(1<<YELLOW_LED_PIN)|(1<<RED_LED_PIN)|(1<<BUZZER_PIN)
    out DDRD, r16

    ; Set all outputs LOW initially
    ldi r16, 0
    out PORTD, r16

    ; Print initialization message
    ldi ZL, lo8(msg_init)
    ldi ZH, hi8(msg_init)
    rcall print_string

    ; Test all LEDs
    rcall testAllLEDs

main_loop:
    ; Check independentTest flag
    lds r16, independentTest
    cpi r16, 0
    breq normal_operation

    ; Run independent LED test if flag set
    rcall runIndependentLEDTest
    rjmp main_loop_end

normal_operation:
    rcall updateIndicators
    rcall printData

main_loop_end:
    ; Delay 1 second
    ldi r16, 10
delay_loop:
    rcall delay_100ms
    dec r16
    brne delay_loop

    rjmp main_loop

; --- UART Initialization ---
uart_init:
    ; 16MHz, 9600 baud UBRR=103
    ldi r16, 0
    sts UBRR0H, r16
    ldi r16, 103
    sts UBRR0L, r16

    ; Enable transmitter
    ldi r16, (1<<TXEN0)
    sts UCSR0B, r16

    ; Frame format 8N1
    ldi r16, (1<<UCSZ01)|(1<<UCSZ00)
    sts UCSR0C, r16
    ret

; --- UART send byte ---
uart_send_byte:
wait_tx:
    lds r17, UCSR0A
    sbrs r17, UDRE0
    rjmp wait_tx
    sts UDR0, r16
    ret

; --- Print zero-terminated string ---
print_string:
    lpm r16, Z+
    cpi r16, 0
    breq print_done
    rcall uart_send_byte
    rjmp print_string
print_done:
    ret

; --- I2C Initialization ---
i2c_init:
    ldi r16, (I2C_SLAVE_ADDR<<1)
    sts TWAR, r16

    ldi r16, (1<<TWEN)|(1<<TWEA)|(1<<TWIE)
    sts TWCR, r16

    sei
    ret

; --- TWI interrupt service routine ---
TWI_vect:
    push r16
    in r16, SREG
    push r16

    push r17
    push r18
    push r19
    push r20
    push ZL
    push ZH

    lds r16, TWSR
    andi r16, 0xF8

    cpi r16, 0x60
    breq twi_slaw_received
    cpi r16, 0x80
    breq twi_data_received

    ; Default: re-enable TWI
    ldi r16, (1<<TWEN)|(1<<TWEA)|(1<<TWIE)
    sts TWCR, r16
    rjmp twi_exit

twi_slaw_received:
    ldi r19, 0
    sts buffer, r19
    ldi r16, (1<<TWEN)|(1<<TWEA)|(1<<TWIE)|(1<<TWINT)
    sts TWCR, r16
    rjmp twi_exit

twi_data_received:
    lds r16, TWDR
    lds r19, buffer
    ldi ZL, lo8(buffer)
    ldi ZH, hi8(buffer)
    add ZL, r19
    adc ZH, r1
    st Z, r16
    inc r19
    sts buffer, r19

    cpi r19, 7
    brne twi_continue_receiving

    rcall process_received_data

twi_continue_receiving:
    ldi r16, (1<<TWEN)|(1<<TWEA)|(1<<TWIE)|(1<<TWINT)
    sts TWCR, r16

twi_exit:
    pop ZH
    pop ZL
    pop r20
    pop r19
    pop r18
    pop r17
    pop r16
    out SREG, r16
    pop r16
    reti

; --- Process received I2C data ---
process_received_data:
    ldi ZL, lo8(buffer)
    ldi ZH, hi8(buffer)

    ld r16, Z+
    ld r17, Z+
    sts temperature, r16
    sts temperature+1, r17

    ld r16, Z+
    ld r17, Z+
    sts humidity, r16
    sts humidity+1, r17

    ld r16, Z+
    ld r17, Z+
    sts airQuality, r16
    sts airQuality+1, r17

    ld r16, Z
    sts airQualityStatus, r16
    ret

; --- Update LED indicators ---
updateIndicators:
    lds r16, airQualityStatus
    in r17, PORTD
    andi r17, ~((1<<GREEN_LED_PIN)|(1<<YELLOW_LED_PIN)|(1<<RED_LED_PIN)|(1<<BUZZER_PIN))

    cpi r16, 0
    brne check_moderate
    ori r17, (1<<GREEN_LED_PIN)
    rjmp set_indicators

check_moderate:
    cpi r16, 1
    brne check_poor
    ori r17, (1<<YELLOW_LED_PIN)
    rjmp set_indicators

check_poor:
    cpi r16, 2
    brne set_indicators
    ori r17, (1<<RED_LED_PIN)|(1<<BUZZER_PIN)

set_indicators:
    out PORTD, r17
    ret

; --- Print received data ---
printData:
    ldi ZL, lo8(msg_data_header)
    ldi ZH, hi8(msg_data_header)
    rcall print_string

    ldi ZL, lo8(msg_temperature)
    ldi ZH, hi8(msg_temperature)
    rcall print_string

    lds r16, temperature
    lds r17, temperature+1
    rcall print_decimal

    ldi ZL, lo8(msg_celsius)
    ldi ZH, hi8(msg_celsius)
    rcall print_string

    ldi ZL, lo8(msg_humidity)
    ldi ZH, hi8(msg_humidity)
    rcall print_string

    lds r16, humidity
    lds r17, humidity+1
    rcall print_decimal

    ldi ZL, lo8(msg_percent)
    ldi ZH, hi8(msg_percent)
    rcall print_string

    ldi ZL, lo8(msg_air_quality)
    ldi ZH, hi8(msg_air_quality)
    rcall print_string

    lds r16, airQuality
    lds r17, airQuality+1
    rcall print_decimal

    ldi ZL, lo8(msg_raw_value)
    ldi ZH, hi8(msg_raw_value)
    rcall print_string

    ldi ZL, lo8(msg_status)
    ldi ZH, hi8(msg_status)
    rcall print_string

    lds r16, airQualityStatus
    cpi r16, 0
    brne check_status_1

    ldi ZL, lo8(msg_status_good)
    ldi ZH, hi8(msg_status_good)
    rcall print_string
    rjmp print_footer

check_status_1:
    cpi r16, 1
    brne check_status_2

    ldi ZL, lo8(msg_status_moderate)
    ldi ZH, hi8(msg_status_moderate)
    rcall print_string
    rjmp print_footer

check_status_2:
    cpi r16, 2
    brne status_unknown

    ldi ZL, lo8(msg_status_poor)
    ldi ZH, hi8(msg_status_poor)
    rcall print_string
    rjmp print_footer

status_unknown:
    ldi ZL, lo8(msg_status_unknown)
    ldi ZH, hi8(msg_status_unknown)
    rcall print_string

    mov r16, r0
    ldi r17, 0
    rcall print_decimal

    ldi ZL, lo8(msg_status_unknown_end)
    ldi ZH, hi8(msg_status_unknown_end)
    rcall print_string

print_footer:
    ldi ZL, lo8(msg_footer)
    ldi ZH, hi8(msg_footer)
    rcall print_string
    ret

; --- Test LEDs ---
testAllLEDs:
    ldi ZL, lo8(msg_test_leds)
    ldi ZH, hi8(msg_test_leds)
    rcall print_string

    in r16, PORTD
    andi r16, ~((1<<YELLOW_LED_PIN)|(1<<RED_LED_PIN)|(1<<BUZZER_PIN))
    ori r16, (1<<GREEN_LED_PIN)
    out PORTD, r16

    ldi ZL, lo8(msg_green_on)
    ldi ZH, hi8(msg_green_on)
    rcall print_string

    ldi r16, 10
    rcall delay_ms_loop

    in r16, PORTD
    andi r16, ~((1<<GREEN_LED_PIN)|(1<<RED_LED_PIN)|(1<<BUZZER_PIN))
    ori r16, (1<<YELLOW_LED_PIN)
    out PORTD, r16

    ldi ZL, lo8(msg_yellow_on)
    ldi ZH, hi8(msg_yellow_on)
    rcall print_string

    ldi r16, 10
    rcall delay_ms_loop

    in r16, PORTD
    andi r16, ~((1<<GREEN_LED_PIN)|(1<<YELLOW_LED_PIN))
    ori r16, (1<<RED_LED_PIN)|(1<<BUZZER_PIN)
    out PORTD, r16

    ldi ZL, lo8(msg_red_buzzer_on)
    ldi ZH, hi8(msg_red_buzzer_on)
    rcall print_string

    ldi r16, 10
    rcall delay_ms_loop

    in r16, PORTD
    andi r16, ~((1<<GREEN_LED_PIN)|(1<<YELLOW_LED_PIN)|(1<<RED_LED_PIN)|(1<<BUZZER_PIN))
    out PORTD, r16

    ldi ZL, lo8(msg_all_off)
    ldi ZH, hi8(msg_all_off)
    rcall print_string

    ldi ZL, lo8(msg_test_complete)
    ldi ZH, hi8(msg_test_complete)
    rcall print_string

    ret

; --- Independent LED test ---
runIndependentLEDTest:
    in r16, PORTD
    andi r16, ~((1<<YELLOW_LED_PIN)|(1<<RED_LED_PIN)|(1<<BUZZER_PIN))
    ori r16, (1<<GREEN_LED_PIN)
    out PORTD, r16

    ldi ZL, lo8(msg_ind_green)
    ldi ZH, hi8(msg_ind_green)
    rcall print_string

    ldi r16, 20
    rcall delay_ms_loop

    in r16, PORTD
    andi r16, ~((1<<GREEN_LED_PIN)|(1<<RED_LED_PIN)|(1<<BUZZER_PIN))
    ori r16, (1<<YELLOW_LED_PIN)
    out PORTD, r16

    ldi ZL, lo8(msg_ind_yellow)
    ldi ZH, hi8(msg_ind_yellow)
    rcall print_string

    ldi r16, 20
    rcall delay_ms_loop

    in r16, PORTD
    andi r16, ~((1<<GREEN_LED_PIN)|(1<<YELLOW_LED_PIN))
    ori r16, (1<<RED_LED_PIN)|(1<<BUZZER_PIN)
    out PORTD, r16

    ldi ZL, lo8(msg_ind_red_buzzer)
    ldi ZH, hi8(msg_ind_red_buzzer)
    rcall print_string

    ldi r16, 20
    rcall delay_ms_loop

    in r16, PORTD
    andi r16, ~((1<<GREEN_LED_PIN)|(1<<YELLOW_LED_PIN)|(1<<RED_LED_PIN)|(1<<BUZZER_PIN))
    out PORTD, r16

    ldi ZL, lo8(msg_ind_all_off)
    ldi ZH, hi8(msg_ind_all_off)
    rcall print_string

    ldi r16, 10
    rcall delay_ms_loop
    ret

; --- Delay loop (r16 * 100ms) ---
delay_ms_loop:
    rcall delay_100ms
    dec r16
    brne delay_ms_loop
    ret

; --- Delay ~100ms ---
delay_100ms:
    ldi r18, 200
outer_loop:
    ldi r19, 250
inner_loop:
    ldi r20, 40
innermost_loop:
    dec r20
    brne innermost_loop
    dec r19
    brne inner_loop
    dec r18
    brne outer_loop
    ret

; --- Print 16-bit decimal (simplified, prints raw bytes) ---
print_decimal:
    mov r16, r0
    rcall uart_send_byte
    mov r16, r1
    rcall uart_send_byte
    ret

; --- Strings in flash ---
.section .rodata

msg_init:
    .ascii "Slave Arduino Initialized\r\nReady to receive data and control indicators\r\n"
    .byte 0

msg_data_header:
    .ascii "\r\n----- Received Data -----\r\n"
    .byte 0

msg_temperature:
    .ascii "Temperature: "
    .byte 0

msg_celsius:
    .ascii " C\r\n"
    .byte 0

msg_humidity:
    .ascii "Humidity: "
    .byte 0

msg_percent:
    .ascii " %\r\n"
    .byte 0

msg_air_quality:
    .ascii "Air Quality (Potentiometer): "
    .byte 0

msg_raw_value:
    .ascii " Raw Value\r\n"
    .byte 0

msg_status:
    .ascii "Air Quality Status: "
    .byte 0

msg_status_good:
    .ascii "GOOD (Green LED ON) - Range 0-340\r\n"
    .byte 0

msg_status_moderate:
    .ascii "MODERATE (Yellow LED ON) - Range 341-682\r\n"
    .byte 0

msg_status_poor:
    .ascii "POOR (Red LED ON, Buzzer ON) - Range 683-1023\r\n"
    .byte 0

msg_status_unknown:
    .ascii "UNKNOWN ("
    .byte 0

msg_status_unknown_end:
    .ascii ")\r\n"
    .byte 0

msg_footer:
    .ascii "------------------------\r\n"
    .byte 0

msg_test_leds:
    .ascii "Testing all LEDs and buzzer...\r\n"
    .byte 0

msg_green_on:
    .ascii "GREEN LED ON\r\n"
    .byte 0

msg_yellow_on:
    .ascii "YELLOW LED ON\r\n"
    .byte 0

msg_red_buzzer_on:
    .ascii "RED LED and BUZZER ON\r\n"
    .byte 0

msg_all_off:
    .ascii "All indicators OFF\r\n"
    .byte 0

msg_test_complete:
    .ascii "LED test completed. Starting normal operation.\r\n"
    .byte 0

msg_ind_green:
    .ascii "IND TEST: GREEN LED ON\r\n"
    .byte 0

msg_ind_yellow:
    .ascii "IND TEST: YELLOW LED ON\r\n"
    .byte 0

msg_ind_red_buzzer:
    .ascii "IND TEST: RED LED and BUZZER ON\r\n"
    .byte 0

msg_ind_all_off:
    .ascii "IND TEST: All OFF\r\n"
    .byte 0
