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
    beq do_exit ; (argc == 0), whart?!?!?
    dec argc
    lda argc
    beq do_exit ; argc == 1

    jsr skip_arg

    ldx #0
arg_loop:
    jsr print_arg
skip_print:
    jsr skip_arg
    jsr inc_arg
    inx 
    cpx argc
    bne arg_loop

do_exit:
    cli
    jsr exit

print_arg:
    stx temp
    ldx args
    ldy args+1
    jsr fopen
    cmp #0
    bne @fail

    stx ptr+1
    lda #0
    sta ptr
:
    ldx ptr
    ldy ptr+1
    jsr iseof
    cmp #0
    bne :+
    ldx ptr
    ldy ptr+1
    jsr fgetc
    jsr putc
    jmp :-
:

    ldy ptr+1
    jsr fclose
    ldx temp
    rts
@fail:
    cmp #2
    beq @fail_dir
    puts file_not_found_err
    puts_indy args
    lda #$0a
    jsr putc
    ldx temp
    rts

@fail_dir:
    puts file_is_dir_err
    puts_indy args
    puts file_is_dir_err_final
    lda #$0a
    jsr putc
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

file_not_found_err:
    .byte "cat: no such file or directory: ",0
file_is_dir_err:
    .byte "cat: ",0
file_is_dir_err_final:
    .byte " is a directory",0