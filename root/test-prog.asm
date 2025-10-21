.feature c_comments
.import __ZP_START__, __ZP_LAST__

.segment "HEADER"
    lda #<(__ZP_LAST__ - __ZP_START__)
    jsr set_zpsize

.zeropage
loop_amt: .res 1
regs: .res 3
;dsfkj: .res 4

.code
.include "../kernel.inc"
.include "../kernel_calls.inc"

test_process:
    lda #4
    sta loop_amt

.repeat 2
    jsr fork
    cmp #0
    beq :+
.endrepeat
:

@start:
    ldx #<test_process_text
    ldy #>test_process_text
    ldx #0
:
    lda test_process_text, x
    beq :+
    sta regs
    stx regs+1
    jsr putc
    lda regs
    ldx regs+1
    inx
    bne :-
:
    jsr get_pid
    ora #$30
    jsr putc
    lda #$0a
    jsr putc

    jsr get_pid
    asl
    asl
    asl
    clc
    adc #144
    ;asl
    ;asl
    ;asl
    tax
:
    ldy #0
:
    nop
    iny
    bne :-
    inx
    bne :--

    dec loop_amt
    lda loop_amt
    beq :+
    jmp @start
:
    jsr exit
    rts

;.segment "RODATA"

test_process_text:
    .byte "printing from process #", 0