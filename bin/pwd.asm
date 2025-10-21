.feature c_comments
.import __ZP_START__, __ZP_LAST__

.segment "HEADER"
    stx *+14
    sta *+9
    lda #<(__ZP_LAST__ - __ZP_START__)
    jsr set_zpsize
    lda #0
    ldx #0

.zeropage
ptr: .res 2

.code
.include "../kernel.inc"
.include "../kernel_calls.inc"

; :omaigaad:
start:
    jsr get_curdir
    stx ptr
    sty ptr+1
    ldy #0
@loop:
    lda (ptr), y
    beq @loop_skip
    jsr_save putc
    iny
    bne @loop
@loop_skip:
    lda #$0a
    jsr putc
    jmp exit