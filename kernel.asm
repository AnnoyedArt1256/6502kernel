.feature c_comments

.repeat 256, I
    .charmap I, I
.endrepeat

.include "kernel.inc"

.zeropage
.org $e0
tick: .res 3
temp_ptr: .res 2
temp_ptr2: .res 2
temp_ptr3: .res 2
io_buffer_ptr: .res 2
filesys_l: .res 1
filesys_h: .res 1

lensys_l: .res 1
lensys_h: .res 1

file_l: .res 1
file_h: .res 1

length_l: .res 1
length_h: .res 1

fileflags: .res 1

findname_l: .res 1
findname_h: .res 1

lastkey: .res 1
actkey: .res 1
mask: .res 1

matrixlo: .res 1
matrixhi: .res 1

.code
.org $80d

.macro align n
    .if (* .mod n) <> 0
        .res n-(* .mod n), $ff
    .endif
.endmacro

jmp kernel_start

.res $6000-*, 0

kernel_start:

main:
    sei
    lda #$35
    sta $01

    lda #127
    sta $dc0d

    and $d011
    sta $d011

    lda $dc0d
    lda $dd0d

    lda #<irq
    sta $fffe
    lda #>irq
    sta $ffff

    lda #<nmi
    sta $fffa
    lda #>nmi
    sta $fffb

    lda #$17
    sta $d018

    lda #$40
    sta $d012

    lda #<(985248/150)
    sta $dc04
    lda #>(985248/150)
    sta $dc05

    lda $dc0d
    and #$81
    sta $dc0d

    lda #$40
    sta $dc0c

    lda #$81
    sta $dc0d

    lda #0
    sta $d01a

    jsr clearscr

    lda #0
    sta tick
    sta tick+1
    sta tick+2

    jsr init_calls
    jsr init_page_alloc
    jsr init_keys

    ldx #<tty_process
    ldy #>tty_process
    jsr add_process

    ldx #<test_o65_str
    ldy #>test_o65_str
    jsr fopen
    txa
    tay
    ldx #0
    jsr load_exec

    cli

    ;jsr hello

    jmp *

.include "relocate.asm"

.include "fgetc_temp.asm"

dad:
    jmp dad

; X = process addr lo
; Y = process addr hi
.proc add_process
    lda temp_ptr
    sta temp_ptr_temp
    lda temp_ptr+1
    sta temp_ptr_temp+1

    stx temp_ptr
    sty temp_ptr+1

    jsr get_free_process
    cmp #$ff
    beq @skip_add_process

    tax
    sta processes_a, x
    lda #$ff
    sta processes_exist, x
    lda #0
    sta processes_x, x
    sta processes_y, x
    sta processes_f, x
    txa
    asl
    asl
    asl
    asl
    clc
    adc #16-1
    sta processes_sp, x

    lda #0
    sta processes_memstart_TEXT, x
    sta processes_memend_TEXT, x
    sta processes_memstart_DATA, x
    sta processes_memend_DATA, x
    sta processes_fork, x

    txa
    asl
    tax
    lda temp_ptr
    sta processes_pc, x
    lda temp_ptr+1
    sta processes_pc+1, x

@skip_add_process:
    lda temp_ptr_temp
    sta temp_ptr
    lda temp_ptr_temp+1
    sta temp_ptr+1
    rts

get_free_process:
    ldx #0
:
    lda processes_exist, x
    beq :+
    inx
    cpx #16
    bne :-
    lda #$ff
    rts
:
    txa
    rts
.endproc

putnl:
    lda #$0a
    jmp putc

hello:
    ldx #0
:
    lda hello_text, x
    beq :+
    jsr_save putc
    inx
    bne :-
:
    rts

hello_text:
    .byte "Hello, World!", 10, 0

zp_temp_inds_lo:
    .repeat 16, I
        .lobytes zp_temp+(64*I)
    .endrepeat
zp_temp_inds_hi:
    .repeat 16, I
        .hibytes zp_temp+(64*I)
    .endrepeat

irq:
    sta @a_load2+1
    stx @x_load2+1
    sty @y_load2+1

    inc $d020

    ;jsr getch_frame

    ldx process_ind
    cpx #$ff
    bne :+
    pla
    pla
    pla
    jmp @get_process
:

    lda zp_temp_inds_lo, x
    sta @store_zp_temp+1
    lda zp_temp_inds_hi, x
    sta @store_zp_temp+2

    ldy processes_zplen, x
    beq :+
    dey
    ;ldy #63
@store_zp_loop:
    lda $10, y
@store_zp_temp:
    sta zp_temp, y
    dey
    bpl @store_zp_loop
:

@a_load2:
    lda #0
    sta processes_a, x
@x_load2:
    lda #0
    sta processes_x, x
@y_load2:
    lda #0
    sta processes_y, x

    txa
    asl
    tay

    pla
    sta processes_f, x
    pla
    sta processes_pc, y
    pla
    sta processes_pc+1, y

    tsx
    txa
    ldx process_ind
    sta processes_sp, x

@get_process:
    inc process_ind
    lda process_ind
    cmp #16
    bcc :+
    lda #0
    sta process_ind
:
    tay
    lda processes_exist, y
    beq @get_process

    tya
    asl
    sta @jmp_tbl+1
    
    lda processes_a, y
    sta @a_load+1
    lda processes_x, y
    sta @x_load+1
    lda processes_y, y
    sta @y_load+1

    lda zp_temp_inds_lo, y
    sta @store_zp_loop2+1
    lda zp_temp_inds_hi, y
    sta @store_zp_loop2+2

    ldx processes_zplen, y
    beq :+
    dex
    ;ldy #63
@store_zp_loop2:
    lda zp_temp, x
    sta $10, x
    dex
    bpl @store_zp_loop2
:

    inc tick
    lda tick
    cmp #3
    bne :+
    lda #0
    sta tick
    inc tick+1
    bcc :+
    inc tick+2
:

    ;asl $d019
    bit $dc0d
    dec $d020

    ldx processes_sp, y
    txs

    lda processes_f, y
    and #$ff^(1<<2)
    pha
@a_load:
    lda #0
@x_load:
    ldx #0
@y_load:
    ldy #0
    plp
@jmp_tbl:
    jmp (processes)

process_ind:
    .byte $ff ; a la round robin :meatjob:

align 256

putc_buffer:
    .res 256, $ff
getch_buffer:
    .res 256, $ff

putc_ptr: .byte 0
putc_out_ptr: .byte 0

getch_ptr: .byte 0
getch_out_ptr: .byte 0

tty_keyp = $10
tty_lastkey = $11
tty_tick = $12

tty_process:
    lda #3
    jsr set_zpsize

    jsr gettick
    sta tty_tick

    lda #0
    sta putc_ptr
    sta putc_out_ptr
    sta getch_ptr
    sta getch_out_ptr
    sta tty_keyp
    sta tty_lastkey
@loop:
    cli

    ldx putc_ptr
    cpx putc_out_ptr
    beq @getch
@loop2:
    sei
    jsr putc_indicator

    ldx putc_out_ptr
    lda putc_buffer, x
    inx
    stx putc_out_ptr

    jsr_save putc_no_buf
    jsr_save putc_indicator

    cpx putc_ptr
    beq @loop
    jmp @loop2
    rts
@getch:
;getch_frame:
    jsr getch_internal
    cmp #0
    beq :++
    cmp tty_lastkey
    bne :+
    ldx tty_keyp
    cpx #1
    beq @ret
:
    ldx getch_ptr
    sta getch_buffer, x
    sta tty_lastkey
    inc getch_ptr
    lda #1
    sta tty_keyp
    jmp @ret
:
    lda #0
    sta tty_keyp
    sta tty_lastkey
@ret:
    jmp @loop ;rts

.include "putc.inc"

.include "keyboard.inc"

get_pid:
    lda process_ind
    cmp #$ff
    bne :+
    ; buggy hackjob
    lda #0
:
    rts

set_zpsize:
    cmp #64
    bcs :+
    ldx process_ind
    sta processes_zplen, x
:
    rts

exit:
    ; kill thread
    jsr get_pid
    pha
    tax
    lda #0
    sta processes_exist, x

    lda processes_fork, x
    beq :+
    pla
    php ; welp
    sei
    jsr irq
:

    ; free text area
    lda processes_memstart_TEXT, x
    ora processes_memend_TEXT, x
    beq :+
    ldy processes_memend_TEXT, x
    lda processes_memstart_TEXT, x
    tax
    jsr free_page_alloc
:
    pla

    ; free data area
    lda processes_memstart_DATA, x
    ora processes_memend_DATA, x
    beq :+
    ldy processes_memend_DATA, x
    lda processes_memstart_DATA, x
    tax
    jsr free_page_alloc
:

    ; switch to next process

    ; brk ; FINALLY, A USE FOR BRK!!!!!
    php ; welp
    sei
    jsr irq

; exec:
; A = argc
; returns: 
;   A = 0 if valid, otherwise error code
;   Y = new PID for exec program
exec:
    sei
    sta @argc_cnt+1
    stx @argc_cntx+1
    sty @argc_cnty+1
    jsr fopen

    cmp #0
    beq :+
@fail_ret:
    ; return with error 1
    cli
    rts
:

    txa
    tay
    ldx #0
    jsr load_exec
    cpx #0
    bne @fail_ret

@argc_cnt:
    lda #0
    sta processes_a, y
@argc_cntx:
    lda #0
    sta processes_x, y
@argc_cnty:
    lda #0
    sta processes_y, y

    ; allocated PID in Y
    lda name_temp_addrs_lo, y
    sta @memcpy_dst+1
    lda name_temp_addrs_hi, y
    sta @memcpy_dst+2

    jsr get_pid
    tax
    lda name_temp_addrs_lo, x
    sta @memcpy_src+1
    lda name_temp_addrs_hi, x
    sta @memcpy_src+2

    ldx #63
@memcpy:
@memcpy_src:
    lda $1000, x
@memcpy_dst:
    sta $2000, x
    dex
    bpl @memcpy

@end_exec:
    lda #0
    cli
    rts

check_pid_exist:
    lda processes_exist, x
    rts

align 256

processes:
processes_pc:
    .res 16*2, 0
processes_exist:
    .res 16, 0
processes_a:
    .res 16, 0
processes_x:
    .res 16, 0
processes_y:
    .res 16, 0
processes_f:
    .res 16, 0
processes_sp:
    .res 16, 0
processes_zplen:
    .res 16, 64
processes_memstart_TEXT:
    .res 16, 0
processes_memend_TEXT:
    .res 16, 0
processes_memstart_DATA:
    .res 16, 0
processes_memend_DATA:
    .res 16, 0
processes_fork:
    .res 16, 0

init_calls:
    lda #$60
    ldx #0
:
    sta call_page, x
    inx
    cpx #$f8
    bne :-

    ldx #0
    ldy #0
:
    lda #$4c
    sta call_page, y
    iny
    lda all_calls, x
    sta call_page, y
    iny
    inx
    lda all_calls, x
    sta call_page, y
    iny
    inx
    cpx #all_calls_end-all_calls
    bne :-
    rts

getdir:
    stx findname_l
    sty findname_h
    jsr LAB_find
    bvc @ret_fail ; bvc wao
    lda #0
    ldx filesys_l
    ldy filesys_h
    rts
@ret_fail:
    lda #1
    ldx #0
    ldy #0
    rts

dirinfo:
    php
    sei
    lda temp_ptr
    sta dirinfo_temp_ptr
    lda temp_ptr+1
    sta dirinfo_temp_ptr+1

    stx temp_ptr
    sty temp_ptr+1

    ldy #0
    lda lensys_l
    sta (temp_ptr), y
    iny
    lda lensys_h
    sta (temp_ptr), y
    iny

    lda file_l
    sta (temp_ptr), y
    iny
    lda file_h
    sta (temp_ptr), y
    iny

    lda filesys_l
    sta (temp_ptr), y
    iny
    lda filesys_h
    sta (temp_ptr), y
    iny

    lda dirinfo_temp_ptr
    sta temp_ptr
    lda dirinfo_temp_ptr+1
    sta temp_ptr+1
    plp
    rts

dirinfo_temp_ptr:
    .word 0

; returns: XY = dir str ptr
get_curdir:
    jsr get_pid
    tay
    ldx name_temp_addrs_lo, y
    lda name_temp_addrs_hi, y
    tay
    rts

; XY = dir str ptr
; returns:
;   A = 0 if no error, otherwise non-zero
chdir: 
    jsr combdir
    sta @free_a+1
    tay
    sta @memcpy_src+2
    lda #0
    sta @memcpy_src+1
    tax

    jsr getdir
    cmp #0
    beq :+
    lda @free_a+1
    jsr free
    lda #1
    rts
:



    jsr get_curdir
    stx @memset_dst+1
    sty @memset_dst+2
    stx @memcpy_dst+1
    sty @memcpy_dst+2
    ldx #63
    lda #0
@memset:
@memset_dst:
    sta $2000, x
    dex
    bpl @memset

    ldx #0
@memcpy:
@memcpy_src:
    lda $1000, x
    beq :+
@memcpy_dst:
    sta $2000, x
    inx
    cpx #64
    bne @memcpy
:
@free_a:
    lda #0
    jsr free
    lda #0
    rts

; A = LSB 8-bits
; XY = 16-bit 50hz timer
gettick:
    lda tick+1
    ldx tick+1
    ldy tick+2
    rts

.proc fork
    pla
    sta @pc_lo+1
    pla
    sta @pc_hi+1
    pha
    lda @pc_lo+1
    pha

    php
    sei
    jsr get_free_process
    cmp #$ff
    bne :+
    plp
    lda #0
    rts
:

    tax

    inc @pc_lo+1
    bne :+
    inc @pc_hi+1
:

    jsr get_pid
    tay
    
    lda #$ff
    sta processes_a, x
    lda #$ff
    sta processes_exist, x

    lda processes_x, y
    sta processes_x, x
    lda processes_y, y
    sta processes_y, x
    lda processes_f, y
    sta processes_f, x
    lda processes_zplen, y
    sta processes_zplen, x

    txa
    asl
    asl
    asl
    asl
    clc
    adc #16-1
    sta processes_sp, x

    lda processes_memstart_TEXT, y
    sta processes_memstart_TEXT, x
    lda processes_memend_TEXT, y
    sta processes_memend_TEXT, x
    lda processes_memstart_DATA, y
    sta processes_memstart_DATA, x
    lda processes_memend_DATA, y
    sta processes_memend_DATA, x
    lda #1
    sta processes_fork, x

    txa
    asl
    tax
    tya
    asl
    tay
@pc_lo:
    lda #0
    sta processes_pc, x
@pc_hi:
    lda #0
    sta processes_pc+1, x

    txa
    lsr
    tax
    tya
    lsr
    tay

    lda zp_temp_inds_lo, y
    sta @store_zp_temp2+1
    lda zp_temp_inds_hi, y
    sta @store_zp_temp2+2

    tya
    pha
    lda processes_zplen, y
    beq :+
    tay
    dey
    ;ldy #63
@store_zp_loop2:
    lda $10, y
@store_zp_temp2:
    sta zp_temp, y
    dey
    bpl @store_zp_loop2
:
    pla
    tay

    lda processes_zplen, y
    beq :+
    pha
    lda zp_temp_inds_lo, x
    sta @store_zp_temp+1
    lda zp_temp_inds_hi, x
    sta @store_zp_temp+2
    lda zp_temp_inds_lo, y
    sta @store_zp_loop+1
    lda zp_temp_inds_hi, y
    sta @store_zp_loop+2
    pla
    tay
    dey
    ;ldy #63
@store_zp_loop:
    lda zp_temp, y
@store_zp_temp:
    sta zp_temp, y
    dey
    bpl @store_zp_loop
:

    lda #0
    plp
    rts
get_free_process:
    ldx #0
:
    lda processes_exist, x
    beq :+
    inx
    cpx #16
    bne :-
    lda #$ff
    rts
:
    txa
    rts
.endproc


.include "nmi.asm"

all_calls:
    .word putc
    .word get_pid
    .word set_zpsize
    .word exit
    .word malloc
    .word free
    .word fopen
    .word fclose
    .word fgetc
    .word exec
    .word getdir
    .word dirinfo
    .word getch
    .word getch_poll
    .word get_curdir
    .word combdir
    .word check_pid_exist
    .word chdir
    .word ftell
    .word iseof
    .word gettick
    .word fork
    .word clearscr
    .word setnmi
    .word clearnmi
    .word malloc_range
    .word exit_nmi
all_calls_end:

name_temp_addrs_lo:
    .repeat 16, I
        .lobytes name_temp+(64*I)
    .endrepeat
name_temp_addrs_hi:
    .repeat 16, I
        .hibytes name_temp+(64*I)
    .endrepeat

.include "page_alloc.asm"

test_o65_str:
    .byte "/bin/sh", 0

align 256
zp_temp: .res 64*16, 0
name_temp: 
    .repeat 16
        .byte "/"
        .res 64-1, 0
    .endrepeat


align 256
DIR_FLAG = $40
romfs_image:
.include "files.inc"

align 256
kernel_end:
