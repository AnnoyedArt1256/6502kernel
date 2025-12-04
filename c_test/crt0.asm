.export     _exit, _read, _write, initmainargs
.export     __STARTUP__ : absolute = 1  ; Mark as startup
.import     zerobss, _main, popax
.import     initlib, donelib
.import     __STACKSTART__      ; Linker generated
.feature c_comments
.import __ZP_START__, __ZP_LAST__

.include "zeropage.inc"

.segment "HEADER"
    stx *+14
    sta *+9
    lda #<(__ZP_LAST__ - __ZP_START__)
    jsr set_zpsize
    lda #0
    ldx #0

.code
.include "../kernel.inc"
.include "../kernel_calls.inc"

    lda #<(stack+256)
    ldx #>(stack+256)
    sta c_sp
    stx c_sp+1
    jsr zerobss
    ;jsr initlib
    jsr _main
_exit: 
    pha
    jsr donelib
    pla
    jmp exit

_read:
;    stx @x_load+1
;    sty @y_load+1
;    jsr getch_poll
;@x_load:
;    ldx #0
;@y_load:
;    ldy #0
    rts


_write:
    sta ptr1
    stx ptr1+1

    jsr popax   ; Get buf
    sta ptr2
    stx ptr2+1
    
    lda #0
    sta ptr3
    sta ptr3+1  ; Clear ptr3

    jsr popax   ; Get the handle

    lda ptr1
    ora ptr1+1
    beq @skip_putc_loop

@write_putc_loop:
    ldy #0
    lda (ptr2), y
    inc ptr2
    bne :+
    inc ptr2+1
:
    jsr_save putc

    inc ptr3
    bne :+
    inc ptr3+1
:

    lda ptr1
    bne :+
    dec ptr1+1
:
    dec ptr1
    
    lda ptr1
    ora ptr1+1
    bne @write_putc_loop
@skip_putc_loop:

    rts

; TODO: for now
initmainargs:
    rts

stack:
.res 512,0 