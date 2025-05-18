#define __SFR_OFFSET 0x00
#include "avr/io.h"

; Constants for sensor pins and thresholds
.set MQ2_PIN, 0       ; A0 = ADC0
.set DHT_PIN, 2       ; Digital pin 2
.set DHT_TYPE, 11     ; DHT11 type
.set AQ_GOOD, 341     ; Good air quality threshold (0-341)
.set AQ_MODERATE, 682 ; Moderate threshold (342-682)

; Improved far call macro using indirect jump with Z register
.macro CALL_FAR target
    push r16
    ldi r16, lo8(99f)
    push r16
    ldi r16, hi8(99f)
    push r16
    ldi ZL, lo8(\target)
    ldi ZH, hi8(\target)
    ijmp
99:
    pop r16
.endm

; Variables in data segment
.section .data
temperature:    .space 2
humidity:       .space 2
airQuality:     .space 2
airQualityStatus: .space 1
tempBuffer:     .space 2
humBuffer:      .space 2
rawValue:       .space 2

; UTILITY FUNCTIONS
uart_send:
uart_wait:
    lds r17, UCSR0A
    sbrs r17, UDRE0
    rjmp uart_wait
    sts UDR0, r16
    ret

delay_us:
delay_us_loop:
    nop
    nop
    nop
    dec r24
    brne delay_us_loop
    ret

delay_ms:
    push r18
    push r19
    push r20
    mov r18, r24
    or r18, r25
    breq delay_ms_done

delay_ms_loop:
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
    
    subi r24, 1
    sbci r25, 0
    
    brne delay_ms_loop
    tst r24
    brne delay_ms_loop
    
delay_ms_done:
    pop r20
    pop r19
    pop r18
    ret

.section .text

; Interrupt vector table
.org 0x0000
    jmp main

; Main program
.global main
main:
    ; Stack initialization
    ldi r16, hi8(RAMEND)
    out SPH, r16
    ldi r16, lo8(RAMEND)
    out SPL, r16
    
    ; System initialization
    CALL_FAR init_serial
    CALL_FAR init_i2c
    CALL_FAR init_dht
    
    ; Initial delay
    ldi r24, lo8(2000)
    ldi r25, hi8(2000)
    CALL_FAR delay_ms
    
    ; Print startup message
    ldi ZL, lo8(init_message)
    ldi ZH, hi8(init_message)
    CALL_FAR print_string

; Main program loop
loop:
    CALL_FAR read_dht11
    CALL_FAR read_mq2
    CALL_FAR determine_air_quality
    CALL_FAR send_data_to_slave
    CALL_FAR print_data
    
    ; Wait between readings
    ldi r24, lo8(2000)
    ldi r25, hi8(2000)
    CALL_FAR delay_ms
    
    rjmp loop

; Initialize UART (9600 baud at 16MHz)
init_serial:
    ldi r16, 103
    sts UBRR0H, r1
    sts UBRR0L, r16
    
    ldi r16, (1<<TXEN0)|(1<<RXEN0)
    sts UCSR0B, r16
    
    ldi r16, (1<<UCSZ01)|(1<<UCSZ00)
    sts UCSR0C, r16
    ret

; Initialize I2C as master (100kHz at 16MHz)
init_i2c:
    ldi r16, 72
    sts TWBR, r16
    
    ldi r16, 0
    sts TWSR, r16
    
    ldi r16, (1<<TWEN)
    sts TWCR, r16
    ret

; Initialize DHT11 sensor
init_dht:
    sbi DDRD, DHT_PIN
    sbi PORTD, DHT_PIN
    ret

; Print null-terminated string from flash
print_string:
print_string_loop:
    lpm r16, Z+
    cpi r16, 0
    breq ps_done
    
    push ZL
    push ZH
    CALL_FAR uart_send
    pop ZH
    pop ZL
    rjmp print_string_loop
    
ps_done:
    ret

; Print 16-bit decimal value
print_decimal:
    subi r16, -'0'
    CALL_FAR uart_send
    ret

; Read temperature and humidity from DHT11
read_dht11:
    ; DHT11 start signal
    cbi PORTD, DHT_PIN
    ldi r24, lo8(20)
    ldi r25, hi8(20)
    CALL_FAR delay_ms
    
    sbi PORTD, DHT_PIN
    ldi r24, 40
    CALL_FAR delay_us
    
    cbi DDRD, DHT_PIN
    
    ; Set dummy values for demonstration
    ldi r16, 50             ; Humidity = 50%
    ldi r17, 0
    sts humidity, r16
    sts humidity+1, r17
    
    ldi r16, 25             ; Temperature = 25°C
    ldi r17, 0  
    sts temperature, r16
    sts temperature+1, r17
    
    ret

; Read MQ-2 sensor value
read_mq2:
    ; ADC setup and conversion
    ldi r16, (1<<REFS0)
    sts ADMUX, r16
    
    ldi r16, (1<<ADEN)|(1<<ADSC)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0)
    sts ADCSRA, r16
    
adc_wait:
    lds r16, ADCSRA
    sbrc r16, ADSC
    rjmp adc_wait
    
    ; Read and store ADC value
    lds r16, ADCL
    lds r17, ADCH
    
    sts rawValue, r16
    sts rawValue+1, r17
    
    sts airQuality, r16
    sts airQuality+1, r17
    
    ret

; Determine air quality status based on thresholds
determine_air_quality:
    lds r16, airQuality
    lds r17, airQuality+1
    
    cpi r17, hi8(AQ_GOOD)
    brlo determine_good_air
    brne determine_moderate_check
    
    cpi r16, lo8(AQ_GOOD)
    brlo determine_good_air
    
determine_moderate_check:
    cpi r17, hi8(AQ_MODERATE)
    brlo determine_moderate_air
    brne determine_poor_air
    
    cpi r16, lo8(AQ_MODERATE)
    brlo determine_moderate_air
    
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

; Strings in program memory
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

; Send sensor data to slave Arduino via I2C
send_data_to_slave:
    ldi r24, 50
    CALL_FAR delay_ms
    
    ; Start I2C transmission
    ldi r16, (1<<TWINT)|(1<<TWSTA)|(1<<TWEN)
    sts TWCR, r16
    
wait_start:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_start
    
    ; Send slave address (8) with write bit (0)
    ldi r16, (8<<1)|0
    sts TWDR, r16
    
    ldi r16, (1<<TWINT)|(1<<TWEN)
    sts TWCR, r16
    
wait_addr:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_addr
    
    ; Send temperature data
    lds r16, temperature+1
    sts TWDR, r16
    ldi r16, (1<<TWINT)|(1<<TWEN)
    sts TWCR, r16
    
wait_temp_h:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_temp_h
    
    lds r16, temperature
    sts TWDR, r16
    ldi r16, (1<<TWINT)|(1<<TWEN)
    sts TWCR, r16
    
wait_temp_l:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_temp_l
    
    ; Send humidity data
    lds r16, humidity+1
    sts TWDR, r16
    ldi r16, (1<<TWINT)|(1<<TWEN)
    sts TWCR, r16
    
wait_hum_h:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_hum_h
    
    lds r16, humidity
    sts TWDR, r16
    ldi r16, (1<<TWINT)|(1<<TWEN)
    sts TWCR, r16
    
wait_hum_l:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_hum_l
    
    ; Send air quality data
    lds r16, airQuality+1
    sts TWDR, r16
    ldi r16, (1<<TWINT)|(1<<TWEN)
    sts TWCR, r16
    
wait_aq_h:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_aq_h
    
    lds r16, airQuality
    sts TWDR, r16
    ldi r16, (1<<TWINT)|(1<<TWEN)
    sts TWCR, r16
    
wait_aq_l:
    lds r16, TWCR
    sbrs r16, TWINT
    rjmp wait_aq_l
    
    ; Send air quality status
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
    
    ldi r24, 50
    CALL_FAR delay_ms
    ret

; Print all sensor data to serial
print_data:
    ldi ZL, lo8(data_header)
    ldi ZH, hi8(data_header)
    CALL_FAR print_string
    
    ; Print temperature
    ldi ZL, lo8(temp_str)
    ldi ZH, hi8(temp_str)
    CALL_FAR print_string
    
    lds r16, temperature
    lds r17, temperature+1
    CALL_FAR print_decimal
    
    ldi ZL, lo8(celsius_str)
    ldi ZH, hi8(celsius_str)
    CALL_FAR print_string
    
    ; Print humidity
    ldi ZL, lo8(hum_str)
    ldi ZH, hi8(hum_str)
    CALL_FAR print_string
    
    lds r16, humidity
    lds r17, humidity+1
    CALL_FAR print_decimal
    
    ldi ZL, lo8(percent_str)
    ldi ZH, hi8(percent_str)
    CALL_FAR print_string
    
    ; Print air quality
    ldi ZL, lo8(air_str)
    ldi ZH, hi8(air_str)
    CALL_FAR print_string
    
    lds r16, airQuality
    lds r17, airQuality+1
    CALL_FAR print_decimal
    
    ldi ZL, lo8(raw_str)
    ldi ZH, hi8(raw_str)
    CALL_FAR print_string
    
    ; Print air quality status with appropriate message
    ldi ZL, lo8(status_str)
    ldi ZH, hi8(status_str)
    CALL_FAR print_string
    
    lds r16, airQualityStatus
    cpi r16, 0
    brne check_moderate
    
    ldi ZL, lo8(good_str)
    ldi ZH, hi8(good_str)
    CALL_FAR print_string
    ret
    
check_moderate:
    cpi r16, 1
    brne print_poor
    
    ldi ZL, lo8(moderate_str)
    ldi ZH, hi8(moderate_str)
    CALL_FAR print_string
    ret
    
print_poor:
    ldi ZL, lo8(poor_str)
    ldi ZH, hi8(poor_str)
    CALL_FAR print_string
    ret