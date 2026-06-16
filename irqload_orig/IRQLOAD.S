;�����������������������������������������������������������������������������ͻ
;�COVERT BITOPS loader, simplified for Rant #6                                 �
;�IRQ-loader based on work by K.M/TABOO & Marko M�kel�                         �
;�(drive code init, main drive code, c64->drive communication by Marko M�kel�) �
;�(drive->c64 communication routine by K.M/TABOO)                              �
;�����������������������������������������������������������������������������ͼ

status          = $90           ;Kernal zeropage variables
messages        = $9d
fa              = $ba

temp1           = $02           ;Temporary zeropage variables
temp2           = $03
stackptrstore   = $04

ciout           = $ffa8         ;Kernal routines
listen          = $ffb1
second          = $ff93
unlsn           = $ffae
acptr           = $ffa5
chkin           = $ffc6
chkout          = $ffc9
chrin           = $ffcf
chrout          = $ffd2
ciout           = $ffa8
close           = $ffc3
open            = $ffc0
setmsg          = $ff90
setnam          = $ffbd
setlfs          = $ffba
clrchn          = $ffcc
getin           = $ffe4
load            = $ffd5
save            = $ffd8

                processor 6502
                org 2304 ; $0900

;�����������������������������������������������������������������������������Ŀ
;�Example main program. Inits the fastloader and loads a file using it. After- �
;�wards the drive can be used normally.                                        �
;�������������������������������������������������������������������������������

start:
    jmp fastload


;�����������������������������������������������������������������������������Ŀ
;�INITFASTLOAD                                                                 �
;�                                                                             �
;�Uploads the fastloader to disk drive memory and starts it.                   �
;�This routine is completely Marko M�kel�'s work.                              �
;�                                                                             �
;�Parameters: -                                                                �
;�Returns: -                                                                   �
;�Modifies: A,X,Y                                                              �
;�������������������������������������������������������������������������������

AMOUNT          = 32                    ;Bytes in one M-W command

initfastload:   lda #<drvprog           ;Initialize selfmodifying code
                sta il_mwbyte+1
                lda #>drvprog
                sta il_mwbyte+2
                lda #<drive
                sta mwcmd+2
                lda #>drive
                sta mwcmd+1
il_mwloop:      jsr il_device           ;Set drive to listen
                ldx #lmwcmd - 1
il_sendmw:      lda mwcmd,x             ;Send M-W command
                jsr ciout
                dex
                bpl il_sendmw
                ldx #0
il_mwbyte:      lda drvprog,x             ;Send AMOUNT bytes of drive
                jsr ciout                 ;code
                inx
                cpx #AMOUNT
                bne il_mwbyte
                jsr unlsn               ;Unlisten starts the command
                lda mwcmd+2
                clc
                adc #AMOUNT
                sta mwcmd+2
                bcc il_nohigh
                inc mwcmd+1
il_nohigh:      lda il_mwbyte+1
                clc                     ;Move pointers
                adc #AMOUNT
                sta il_mwbyte+1
                tax
                bcc il_nohigh2
                inc il_mwbyte+2
il_nohigh2:     lda il_mwbyte+2
                cpx #<drvprogend
                sbc #>drvprogend
                bcc il_mwloop

                jsr il_device           ;Set drive to listen again
                ldx #lmecmd - 1
il_sendme:      lda mecmd,x             ;Send M-E command
                jsr ciout
                dex
                bpl il_sendme
                jmp unlsn               ;Unlisten starts the command

il_device:      lda fa
                jsr listen
                lda #$6f
                jmp second

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

;�����������������������������������������������������������������������������Ŀ
;�DRVPROG - Code executed in the disk drive.                                   �
;�������������������������������������������������������������������������������

RETRIES         = 5             ;Amount of retries when reading a sector
acsbf           = $01           ;Buffer 1 command
trkbf           = $08           ;Buffer 1 track
sctbf           = $09           ;Buffer 1 sector
iddrv0          = $12           ;Disk drive ID
id              = $16           ;Disk ID
datbf           = $14           ;Temp variable
buf             = $0400         ;Sector data buffer

drvprog:                        ;Address in C64's memory
                rorg $0500      ;Address in diskdrive's memory
drive:          cli             ;Enable interrupts while waiting the first byte
                jsr getbyte     ;(to allow motor to stop)
                sta namecmp2+1
                sei             ;Disable while waiting second byte
                jsr getbyte
                sta namecmp1+1
                lda #$08        ;Set CLK=low to tell C64 there's no data to
                sta $1800       ;be read yet
                ldx #18
                ldy #1	        ;Read disk directory
dirloop:        stx trkbf
                sty sctbf
                jsr readsect    ;Read sector
                bcc error       ;If failed, return error code
                ldy #$02
nextfile:       lda buf,y       ;File type must be PRG
                and #$83
                cmp #$82
                bne notfound
                lda buf+3,y     ;Check first letter
namecmp1:       cmp #$00
                bne notfound
                lda buf+4,y     ;Check second letter
namecmp2:       cmp #$00
                beq found
notfound:       tya
                clc
                adc #$20
                tay
                bcc nextfile
                ldy buf+1       ;Go to next directory block, go on until no
                ldx buf	        ;more directory blocks
                bne dirloop
error:          lda #$01        ;Send $01 - error in loading file
loadend:        jsr sendbyte
                lda $1800       ;Set CLK=High
                and #$f7
                sta $1800
                lda #$04
loadend_wait:   bit $1800       ;Wait for CLK=High
                bne loadend_wait
                ldy #$00        ;Set DATA=High
                sty $1800
                jmp drive       ;Go back to wait for the filename

found:          iny
nextsect:       lda buf,y       ;File found, get starting track & sector
                sta trkbf
                beq loadend     ;If at file's end, send byte $00
                lda buf+1,y
                sta sctbf
                jsr readsect    ;Read the data sector
                bcc error
                ldy #$ff        ;Amount of bytes to send - assume $ff
                lda buf
                bne sendblk
                ldy buf+1       ;Possibly less if it's the last block
sendblk:        tya
sendloop:       jsr sendbyte    ;Send the amount of bytes that will be sent
                lda buf,y       ;Send the sector data in reverse order
                dey
                bne sendloop
                beq nextsect

readsect:       ldy #RETRIES    ;Retry counter
retry:          cli             ;Enable interrupts so that command can be
                jsr success     ;executed, turn on led
                lda #$80
                sta acsbf       ;Command:read sector
poll1:          lda acsbf       ;Wait until ready
                bmi poll1
                sei
                cmp #1
                beq success     ;Also sets carry flag to 1
                lda id	        ;Check for disk ID change
                sta iddrv0
                lda id+1
                sta iddrv0+1
                dey             ;Decrease retry counter
                bne retry
failure:        clc
success:        lda $1c00
                eor #$08
                sta $1c00
                rts

sendbyte:       sta datbf       ;Store the byte to a temp variable
                tya             ;Store Y-register contents
                pha
                ldy #$04
                lda $1800
                and #$f7
                sta $1800
                tya
s1:             asl datbf       ;Rotate bit to carry and "invert"
                ldx #$02
                bcc s2
                ldx #$00
s2:             bit $1800
                bne s2
                stx $1800
                asl datbf
                ldx #$02
                bcc s3
                ldx #$00
s3:             bit $1800
                beq s3
                stx $1800
                dey
                bne s1
                txa
                ora #$08
                sta $1800
                pla
                tay
                rts

getbyte:        ldy #8	        ;Counter: receive 8 bits
recvbit:
                lda #$85
                and $1800	;Wait for CLK==low || DATA==low
                bmi gotatn	;Quit if ATN was asserted
                beq recvbit
                lsr		;Read the data bit
                lda #2	        ;Prepare for CLK=high, DATA=low
                bcc rskip
                lda #8	        ;Prepare for CLK=low, DATA=high
rskip:          sta $1800	;Acknowledge the bit received
                ror datbf	;and store it
rwait:          lda $1800	;Wait for CLK==high || DATA==high
                and #5
                eor #5
                beq rwait
                lda #0
                sta $1800	;Set CLK=DATA=high
                dey
                bne recvbit	;Loop until all bits have been received
                lda datbf	;Return the data to A
                rts
gotatn:         pla		;If ATN gets asserted, exit to the operating
                pla		;system. Discard the return address.
                rend
il_ok:          rts

drvprogend:

mwcmd:          dc.b AMOUNT,>drive,<drive,"W-M"
lmwcmd          = . - mwcmd

mecmd:          dc.b >drive,<drive,"E-M"
lmecmd          = . - mecmd

filename:       dc.b 0,0
loadbuffer:     dc.b 254,0