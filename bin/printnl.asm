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

.code
.include "../kernel.inc"
.include "../kernel_calls.inc"

; wow very useful
start:
    lda #$0a
    jsr putc
    jmp exit