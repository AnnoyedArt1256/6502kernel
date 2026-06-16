; this is from the loader from Rant #6 of covert bitops' "rants/blogs" so to speak
;�����������������������������������������������������������������������������Ŀ
;�FASTLOAD                                                                     �
;�                                                                             �
;�Loads a file with fastloader. INITFASTLOAD must have been called first.      �
;�Any normal KERNAL disk operations will cause the fastloader drive code to    �
;�exit (as ATN line goes low) and after that, INITFASTLOAD has to be called    �
;�again.                                                                       �
;�                                                                             �
;�Parameters: X: First letter of filename, Y: Second letter of filename        �
;�Returns: C=0 OK, C=1 error                                                   �
;�Modifies: A,X,Y                                                              �
;�������������������������������������������������������������������������������

fastload:       stx filename
                sty filename+1
                sta $d07a               ;SCPU to slow mode
                tsx                     ;Store stackpointer, needed when
                stx stackptrstore       ;finishing loading
                ldx #$01                ;Byte counter.
fastload_sendouter:
                ldy #$08                ;Bit counter
fastload_sendinner:
                bit $dd00               ;Wait for CLK & DATA high
                bvc fastload_sendinner
                bpl fastload_sendinner
                lsr filename,x          ;Rotate byte to be sent
                lda $dd00
                and #$ff-$30
                ora #$10
                bcc fastload_zerobit
                eor #$30
fastload_zerobit:
                sta $dd00
                lda #$c0                ;Wait for CLK & DATA low
fastload_sendack:
                bit $dd00
                bne fastload_sendack
                lda $dd00
                and #$ff-$30            ;Set DATA and CLK high
                sta $dd00
                dey
                bne fastload_sendinner
                dex                     ;All bytes sent?
                bpl fastload_sendouter
fastload_delay: dex                     ;Give the drive some time to set CLK
                bne fastload_delay      ;low in preparation to sending bytes

                lda #$00                ;Initialize buffer counter
                sta temp2

                jsr fastload_getbyte    ;Get file start address
                sta fastload_sta+1
                jsr fastload_getbyte
                sta fastload_sta+2

fastload_loop:  jsr fastload_getbyte    ;Then get bytes one by one. Getbyte
fastload_sta:   sta $1000               ;routine exits when all have been
                inc $d020               ;received.
                dec $d020               ;Just some flashing to know we're
                inc fastload_sta+1      ;loading...
                bne fastload_loop
                inc fastload_sta+2
                jmp fastload_loop

fastload_getbyte:
                ldx temp2                ;Bytes still in buffer?
                beq fastload_fillbuffer
                lda loadbuffer-1,x
                dex
                stx temp2
                rts
fastload_fillbuffer:
                jsr fastload_get        ;Get number of bytes to transfer
                cmp #$01                ;$00 indicates successful end of load
                bcc fastload_loadend    ;and $01 an error
                beq fastload_loadend    ;Carry is set already (error sign)
                sbc #$01                ;Carry is 1 here
                sta temp2                ;Store buffer length to bytecounter
                ldx #$00
fastload_gnbloop:
                jsr fastload_get        ;Get the buffer byte by byte
                sta loadbuffer,x
                inx
                cpx temp2
                bcc fastload_gnbloop
                bcs fastload_getbyte
fastload_loadend:
                ldx stackptrstore       ;Restore stackpointer & exit loader
                txs
                sta $d07b               ;SCPU to fast mode
                rts


fastload_get:   bit $dd00               ;Wait until 1541 is ready to send
                bvc fastload_get        ;(CLK=high)
                lda #$0f
                and $dd00
                sta $dd00
                nop
                ldy #$08                ;Bit counter
fastload_bitloop:
                nop
                nop
                lda #$10
                eor $dd00               ;Take databit from serialport and
                sta $dd00               ;store reversed clockbit
                asl
                rol temp1
                lda temp1
                dey
                bne fastload_bitloop    ;All bits done?
                rts
            
temp1: .byte 0
temp2: .byte 0
stackptrstore: .byte 0

filename:       .res 2
loadbuffer:     .res 256