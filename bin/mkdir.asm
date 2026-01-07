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
temp: .res 2

.code
.include "../kernel.inc"
.include "../kernel_calls.inc"

.macro puts addr
    .local @loop, @loop_skip
    ldx #0
@loop:
    lda addr, x
    beq @loop_skip
    jsr_save putc
    inx
    bne @loop
@loop_skip:
.endmacro

.macro puts_indy addr
    .local @loop, @loop_skip
    ldy #0
@loop:
    lda (addr), y
    beq @loop_skip
    jsr_save putc
    iny
    bne @loop
@loop_skip:
.endmacro

test_process:
    sei
    stx args
    sty args+1
    sta argc
    cli

    lda argc
    beq do_exit_small_arg ; (argc == 0), whart?!?!?
    dec argc
    lda argc
    beq do_exit_small_arg ; argc == 1

    jsr skip_arg

    ldx #0
arg_loop:
    jsr create_dir_arg
    jsr skip_arg
    jsr inc_arg
    inx 
    cpx argc
    bne arg_loop

do_exit:
    cli
    jsr exit

do_exit_small_arg:
    cli
    puts mkdir_not_args
    jsr exit

create_dir_arg:
    stx temp
    ldx args
    ldy args+1
    jsr mkdir
    cmp #0
    beq :+
    puts mkdir_already
    puts_indy args
    puts mkdir_already2
:
    ldx temp
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

mkdir_not_args:
.byte "mkdir: not enough arguments", 0

mkdir_already:
.byte "mkdir: ", 0
mkdir_already2:
.byte " is already a directory", $0a, 0