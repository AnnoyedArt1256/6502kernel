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
argc: .res 1
args: .res 2
prev_arg: .res 1
no_print_nl: .res 1

.code
.include "../kernel.inc"
.include "../kernel_calls.inc"

test_process:
    sei
    stx args
    sty args+1
    sta argc

    lda argc
    beq do_exit ; (argc == 0), whart?!?!?
    dec argc
    lda argc
    beq do_exit ; argc == 1

    jsr skip_arg

    ldx #0
    stx prev_arg
    stx no_print_nl

    jsr check_arg
    dey
    cmp #0
    bne skip_print
    jmp skip_space

arg_loop:
    jsr check_arg
    cmp #0
    beq skip_check_arg
    dey
    jmp skip_print
skip_check_arg:

    lda prev_arg
    bne skip_space_putc
    lda #' '
    jsr_save putc
skip_space_putc:
    lda #0
    sta prev_arg

skip_space:
    jsr print_arg
skip_print:
    jsr inc_arg
    inx 
    cpx argc
    bne arg_loop
    
    ; print nl
    lda no_print_nl
    bne do_exit

    lda #$0a
    jsr putc

do_exit:
    cli
    jsr exit

print_arg:
    ldy #0
:
    lda (args), y
    beq :+
    jsr_save putc
    iny
    bne :-
:
    rts

skip_arg:
    ldy #0
:
    lda (args), y
    beq :+
    iny
    bne :-
:

inc_arg:
    iny
    tya
    clc
    adc args
    sta args
    lda args+1
    adc #0
    sta args+1
    rts

check_arg:
    ldy #0
:
    lda (args), y
    eor no_nl_arg, y
    bne :+
    iny
    cpy #3
    bne :-
    inc prev_arg
    lda #1
    sta no_print_nl
    rts
:
    lda #0
    rts

no_nl_arg:
    .byte "-n", 0