.export         _exit, _read, _write, initmainargs
.export         __STARTUP__ : absolute = 1      ; Mark as startup
.import         zerobss, _main
.import         initlib, donelib
.import         __STACKSTART__                  ; Linker generated
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

    lda #<__STACKSTART__
    ldx #>__STACKSTART__
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
    stx @x_load+1
    sty @y_load+1
    jsr getch_poll
@x_load:
    ldx #0
@y_load:
    ldy #0
    rts

_write:
    jsr_save putc
    rts

; TODO: for now
initmainargs:
    rts