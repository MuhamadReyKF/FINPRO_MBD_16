;===================================================================
; AVR Assembly conversion of Arduino sensor program for ATmega328P
; Uses MQ-2 for air quality and DHT11 for temperature/humidity
;===================================================================

#define __SFR_OFFSET 0x00
#include "avr/io.h"
;-------------------------------------------------------------------

; Constants and definitions
.set MQ2_PIN, 0       ; A0 = ADC0
.set DHT_PIN, 2       ; Digital pin 2
.set DHT_TYPE, 11     ; DHT11 type

; Air quality thresholds
.set AQ_GOOD, 341     ; Good air quality threshold (0-341)
.set AQ_MODERATE, 682 ; Moderate threshold (342-682)

; IMPROVED FAR CALL MACRO - Uses indirect jump with register pair Z
; This avoids branch range limitations
.macro CALL_FAR target
    push r16           ; Save r16 temporarily (will be restored at target function's end)
    ldi r16, lo8(99f)  ; Low byte of return address
    push r16
    ldi r16, hi8(99f)  ; High byte of return address
    push r16
    ldi ZL, lo8(\target) ; Load function address to Z register
    ldi ZH, hi8(\target)
    ijmp                ; Indirect jump via Z register
99:                     ; Return address label
    pop r16             ; Restore r16
.endm

; Variables (allocated in data segment)
.section .data
temperature:    .space 2    ; Temperature (2 bytes)
humidity:       .space 2    ; Humidity (2 bytes)
airQuality:     .space 2    ; Air quality (2 bytes)
airQualityStatus: .space 1  ; Status (1 byte)
tempBuffer:     .space 2    ; Temporary buffer
humBuffer:      .space 2    ; Temporary buffer
rawValue:       .space 2    ; Raw ADC value

;-------------------------------------------------------------------
; UTILITY FUNCTIONS - Moved here to be closer to main code
;-------------------------------------------------------------------

;-------------------------------------------------------------------
; Function: uart_send - Send byte in r16 via UART
;-------------------------------------------------------------------
uart_send:
    ; Wait for UDRE flag (buffer empty)
uart_wait:
    lds r17, UCSR0A
    sbrs r17, UDRE0
    rjmp uart_wait
    
    ; Send data
    sts UDR0, r16
    ret

;-------------------------------------------------------------------
; Function: delay_us - Delay for r24 microseconds
;-------------------------------------------------------------------
delay_us:
    ; Assuming 16 MHz clock, each cycle is 0.0625 µs
    ; So approximately 16 cycles per µs
    
delay_us_loop:
    ; 4 cycles per iteration of this loop (excluding rjmp)
    nop
    nop
    nop
    dec r24
    brne delay_us_loop  ; 2 cycles if taken, 1 if not
    
    ret

;-------------------------------------------------------------------
; Function: delay_ms - Delay for r24:r25 milliseconds
;-------------------------------------------------------------------
delay_ms:
    ; Save registers
    push r18
    push r19
    push r20
    
    ; Check if zero
    mov r18, r24
    or r18, r25
    breq delay_ms_done

delay_ms_loop:
    ; Delay approx 1ms (assuming 16 MHz clock)
    ldi r18, 20
    
delay_ms_loop1:
    ldi r19, 200
    
delay_ms_loop2:
    ldi r20, 3
    
delay_ms_loop3:
    dec r20
    brne delay_ms_loop3
    dec r19
    brne delay_ms_loop2
    dec r18
    brne delay_ms_loop1
    
    ; Decrement counter
    subi r24, 1
    sbci r25, 0
    
    brne delay_ms_loop
    tst r24
    brne delay_ms_loop
    
delay_ms_done:
    ; Restore registers
    pop r20
    pop r19
    pop r18
    ret

;-------------------------------------------------------------------
; Code segment
.section .text

; Interrupt vector table
.org 0x0000
    jmp main             ; Reset vector

; Main program
.global main
main:
    ; Stack initialization
    ldi r16, hi8(RAMEND)
    out SPH, r16
    ldi r16, lo8(RAMEND)
    out SPL, r16
    
    ; Initialize serial (USART)
    CALL_FAR init_serial    ; Use CALL_FAR instead of rcall
    
    ; Initialize I2C (Wire)
    CALL_FAR init_i2c       ; Use CALL_FAR instead of rcall
    
    ; Initialize DHT11
    CALL_FAR init_dht       ; Use CALL_FAR instead of rcall
    
    ; Small delay (2000ms)
    ldi r24, lo8(2000)
    ldi r25, hi8(2000)
    CALL_FAR delay_ms       ; Use CALL_FAR instead of rcall
    
    ; Print initialization message
    ldi ZL, lo8(init_message)
    ldi ZH, hi8(init_message)
    CALL_FAR print_string   ; Use CALL_FAR instead of rcall

; Main loop
loop:
    ; Read DHT11 sensor
    CALL_FAR read_dht11     ; Use CALL_FAR instead of rcall
    
    ; Read MQ-2 sensor
    CALL_FAR read_mq2       ; Use CALL_FAR instead of rcall
    
    ; Determine air quality status
    CALL_FAR determine_air_quality  ; Use CALL_FAR instead of rcall
    
    ; Send data to slave Arduino
    CALL_FAR send_data_to_slave     ; Use CALL_FAR instead of rcall
    
    ; Print data to UART
    CALL_FAR print_data     ; Use CALL_FAR instead of rcall
    
    ; Wait 2000ms before next reading
    ldi r24, lo8(2000)
    ldi r25, hi8(2000)
    CALL_FAR delay_ms       ; Use CALL_FAR instead of rcall
    
    rjmp loop        ; Loop forever

;-------------------------------------------------------------------
; Function: init_serial - Initialize UART
;-------------------------------------------------------------------
init_serial:
    ; Set baud rate to 9600 (assuming 16MHz clock)
    ; UBRR = (F_CPU / (16 * baud)) - 1 = (16000000 / (16 * 9600)) - 1 = 103
    ldi r16, 103
    sts UBRR0H, r1      ; 0
    sts UBRR0L, r16     ; 103
    
    ; Enable transmitter and receiver
    ldi r16, (1<<TXEN0)|(1<<RXEN0)
    sts UCSR0B, r16
    
    ; Set frame format: 8 data, 1 stop bit, no parity
    ldi r16, (1<<UCSZ01)|(1<<UCSZ00)
    sts UCSR0C, r16
    ret

;-------------------------------------------------------------------
; Function: init_i2c - Initialize I2C as master
;-------------------------------------------------------------------
init_i2c:
    ; Set SCL frequency to 100kHz (assuming 16MHz clock)
    ; TWBR = ((F_CPU / SCL) - 16) / 2 = ((16000000/100000) - 16) / 2 = 72
    ldi r16, 72
    sts TWBR, r16
    
    ; No prescaler
    ldi r16, 0
    sts TWSR, r16
    
    ; Enable TWI
    ldi r16, (1<<TWEN)
    sts TWCR, r16
    ret

;-------------------------------------------------------------------
; Function: init_dht - Initialize DHT11 sensor
;-------------------------------------------------------------------
init_dht:
    ; Set DHT pin as output initially
    sbi DDRD, DHT_PIN
    
    ; Set pin high
    sbi PORTD, DHT_PIN
    ret

;-------------------------------------------------------------------
; Function: print_string - Print null-terminated string from flash
;-------------------------------------------------------------------
print_string:
print_string_loop:
    lpm r16, Z+         ; Load character from program memory
    cpi r16, 0          ; Check for null terminator
    breq ps_done        ; If null, we're done
    
    ; Send character via UART
    push ZL             ; Save Z register
    push ZH
    CALL_FAR uart_send  ; Use CALL_FAR instead of rcall
    pop ZH              ; Restore Z register
    pop ZL
    rjmp print_string_loop   ; Continue with next character
    
ps_done:
    ret

;-------------------------------------------------------------------
; Function: print_decimal - Print 16-bit decimal value
;-------------------------------------------------------------------
print_decimal:
    ; r16:r17 contains value to print
    ; Simple implementation: convert to ASCII and print
    ; For numbers > 99, need to divide by 100, 10, etc.
    
    ; For demonstration, just print the low byte as number
    subi r16, -'0'      ; Convert to ASCII
    CALL_FAR uart_send  ; Use CALL_FAR instead of rcall
    ret

;-------------------------------------------------------------------
; Function: read_dht11 - Read temperature and humidity from DHT11
;-------------------------------------------------------------------
read_dht11:
    ; Start signal: pull low for at least 18ms
    cbi PORTD, DHT_PIN      ; Pin low
    ldi r24, lo8(20)
    ldi r25, hi8(20)
    CALL_FAR delay_ms       ; Use CALL_FAR instead of rcall
    
    ; Pull high for 40µs
    sbi PORTD, DHT_PIN      ; Pin high
    ldi r24, 40
    CALL_FAR delay_us       ; Use CALL_FAR instead of rcall
    
    ; Set pin as input to read response
    cbi DDRD, DHT_PIN
    
    ; For demonstration, set dummy values
    ldi r16, 50             ; Humidity = 50%
    ldi r17, 0
    sts humidity, r16
    sts humidity+1, r17
    
    ldi r16, 25             ; Temperature = 25°C
    ldi r17, 0  
    sts temperature, r16
    sts temperature+1, r17
    
    ret

;-------------------------------------------------------------------
; Function: read_mq2 - Read MQ-2 sensor value
;-------------------------------------------------------------------
read_mq2:
    ; Select ADC0 (MQ2_PIN is A0)
    ldi r16, (1<<REFS0)     ; AVCC with external cap at AREF
    sts ADMUX, r16
    
    ; Enable ADC and start conversion
    ldi r16, (1<<ADEN)|(1<<ADSC)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
    sts ADCSRA, r16
    
    ; Wait for conversion to complete
adc_wait:
    lds r16, ADCSRA
    sbrc r16, ADSC          ; Skip if ADSC bit is cleared (conversion done)
    rjmp adc_wait
    
    ; Read ADC value
    lds r16, ADCL
    lds r17, ADCH
    
    ; Store raw value in memory
    sts rawValue, r16
    sts rawValue+1, r17
    
    ; Store as air quality value
    sts airQuality, r16
    sts airQuality+1, r17
    
    ret

;-------------------------------------------------------------------
; Function: determine_air_quality - Determine air quality status
;-------------------------------------------------------------------
determine_air_quality:
    ; Compare with thresholds
    lds r16, airQuality
    lds r17, airQuality+1
    
    ; Check if < AQ_GOOD (341)
    cpi r17, hi8(AQ_GOOD)
    brlo determine_good_air  ; If high byte is lower, it's good
    brne determine_moderate_check  ; If high byte is higher, check moderate
    
    ; High bytes equal, check low byte
    cpi r16, lo8(AQ_GOOD)
    brlo determine_good_air  ; If low byte is lower, it's good
    
determine_moderate_check:
    ; Check if < AQ_MODERATE (682)
    cpi r17, hi8(AQ_MODERATE)
    brlo determine_moderate_air  ; If high byte is lower, it's moderate
    brne determine_poor_air      ; If high byte is higher, it's poor
    
    ; High bytes equal, check low byte
    cpi r16, lo8(AQ_MODERATE)
    brlo determine_moderate_air  ; If low byte is lower, it's moderate
    
determine_poor_air:
    ldi r16, 2              ; Status 2 = Poor
    sts airQualityStatus, r16
    ret

determine_good_air:
    ldi r16, 0              ; Status 0 = Good
    sts airQualityStatus, r16
    ret

determine_moderate_air:
    ldi r16, 1              ; Status 1 = Moderate
    sts airQualityStatus, r16
    ret

;-------------------------------------------------------------------
; Strings stored in program memory
;-------------------------------------------------------------------
init_message:
    .ascii "Master Arduino Initialized\r\n"
    .ascii "Monitoring with DHT11 and MQ-2 Gas Sensor\r\n"
    .byte 0
    
data_header:
    .byte 13, 10
    .ascii "----- Sensor Readings -----\r\n"
    .byte 0
    
temp_str:
    .ascii "Temperature (DHT11): "
    .byte 0
    
celsius_str:
    .ascii " C\r\n"
    .byte 0
    
hum_str:
    .ascii "Humidity (DHT11): "
    .byte 0
    
percent_str:
    .ascii " %\r\n"
    .byte 0
    
air_str:
    .ascii "Air Quality (MQ-2): "
    .byte 0
    
raw_str:
    .ascii " Raw Value\r\n"
    .byte 0
    
status_str:
    .ascii "Air Quality Status: "
    .byte 0
    
good_str:
    .ascii "GOOD (Green) - Range 0-340\r\n"
    .byte 0
    
moderate_str:
    .ascii "MODERATE (Yellow) - Range 341-682\r\n"
    .byte 0
    
poor_str:
    .ascii "POOR (Red) - Range 683-1023\r\n"
    .byte 0

;-------------------------------------------------------------------
; Function: send_data_to_slave - Send sensor data to slave Arduino
;-------------------------------------------------------------------
send_data_to_slave:
    ; Small delay before starting transmission
    ldi r24, 50
    CALL_FAR delay_ms           ; Use CALL_FAR instead of rcall
    
    ; Start I2C transmission
    ldi r16, (1<<TWINT)|(1<<TWSTA)|(1<<TWEN)
    sts TWCR, r16
    
    ; Wait for TWINT flag set
wait_start:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_start
    
    ; Load slave address (8) with write bit (0)
    ldi r16, (8<<1)|0
    sts TWDR, r16
    
    ; Clear TWINT to start transmission
    ldi r16, (1<<TWINT)|(1<<TWEN)
    sts TWCR, r16
    
    ; Wait for TWINT flag set
wait_addr:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_addr
    
    ; Send temperature high byte
    lds r16, temperature+1
    sts TWDR, r16
    ldi r16, (1<<TWINT)|(1<<TWEN)
    sts TWCR, r16
    
wait_temp_h:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_temp_h
    
    ; Send temperature low byte
    lds r16, temperature
    sts TWDR, r16
    ldi r16, (1<<TWINT)|(1<<TWEN)
    sts TWCR, r16
    
wait_temp_l:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_temp_l
    
    ; Send humidity high byte
    lds r16, humidity+1
    sts TWDR, r16
    ldi r16, (1<<TWINT)|(1<<TWEN)
    sts TWCR, r16
    
wait_hum_h:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_hum_h
    
    ; Send humidity low byte
    lds r16, humidity
    sts TWDR, r16
    ldi r16, (1<<TWINT)|(1<<TWEN)
    sts TWCR, r16
    
wait_hum_l:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_hum_l
    
    ; Send air quality high byte
    lds r16, airQuality+1
    sts TWDR, r16
    ldi r16, (1<<TWINT)|(1<<TWEN)
    sts TWCR, r16
    
wait_aq_h:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_aq_h
    
    ; Send air quality low byte
    lds r16, airQuality
    sts TWDR, r16
    ldi r16, (1<<TWINT)|(1<<TWEN)
    sts TWCR, r16
    
wait_aq_l:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_aq_l
    
    ; Send air quality status byte
    lds r16, airQualityStatus
    sts TWDR, r16
    ldi r16, (1<<TWINT)|(1<<TWEN)
    sts TWCR, r16
    
wait_status:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_status
    
    ; Send stop condition
    ldi r16, (1<<TWINT)|(1<<TWEN)|(1<<TWSTO)
    sts TWCR, r16
    
    ; Small delay after transmission
    ldi r24, 50
    CALL_FAR delay_ms           ; Use CALL_FAR instead of rcall
    ret

;-------------------------------------------------------------------
; Function: print_data - Print sensor data to serial
;-------------------------------------------------------------------
print_data:
    ; Print header
    ldi ZL, lo8(data_header)
    ldi ZH, hi8(data_header)
    CALL_FAR print_string      ; Use CALL_FAR instead of rcall
    
    ; Print temperature
    ldi ZL, lo8(temp_str)
    ldi ZH, hi8(temp_str)
    CALL_FAR print_string      ; Use CALL_FAR instead of rcall
    
    lds r16, temperature
    lds r17, temperature+1
    CALL_FAR print_decimal     ; Use CALL_FAR instead of rcall
    
    ldi ZL, lo8(celsius_str)
    ldi ZH, hi8(celsius_str)
    CALL_FAR print_string      ; Use CALL_FAR instead of rcall
    
    ; Print humidity
    ldi ZL, lo8(hum_str)
    ldi ZH, hi8(hum_str)
    CALL_FAR print_string      ; Use CALL_FAR instead of rcall
    
    lds r16, humidity
    lds r17, humidity+1
    CALL_FAR print_decimal     ; Use CALL_FAR instead of rcall
    
    ldi ZL, lo8(percent_str)
    ldi ZH, hi8(percent_str)
    CALL_FAR print_string      ; Use CALL_FAR instead of rcall
    
    ; Print air quality
    ldi ZL, lo8(air_str)
    ldi ZH, hi8(air_str)
    CALL_FAR print_string      ; Use CALL_FAR instead of rcall
    
    lds r16, airQuality
    lds r17, airQuality+1
    CALL_FAR print_decimal     ; Use CALL_FAR instead of rcall
    
    ldi ZL, lo8(raw_str)
    ldi ZH, hi8(raw_str)
    CALL_FAR print_string      ; Use CALL_FAR instead of rcall
    
    ; Print air quality status
    ldi ZL, lo8(status_str)
    ldi ZH, hi8(status_str)
    CALL_FAR print_string      ; Use CALL_FAR instead of rcall
    
    lds r16, airQualityStatus
    cpi r16, 0
    brne check_moderate
    
    ; Print good status
    ldi ZL, lo8(good_str)
    ldi ZH, hi8(good_str)
    CALL_FAR print_string      ; Use CALL_FAR instead of rcall
    ret
    
check_moderate:
    cpi r16, 1
    brne print_poor
    
    ; Print moderate status
    ldi ZL, lo8(moderate_str)
    ldi ZH, hi8(moderate_str)
    CALL_FAR print_string      ; Use CALL_FAR instead of rcall
    ret
    
print_poor:
    ldi ZL, lo8(poor_str)
    ldi ZH, hi8(poor_str)
    CALL_FAR print_string      ; Use CALL_FAR instead of rcall
    ret