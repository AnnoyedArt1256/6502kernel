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
init_tick: .res 1

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

    lda #$0a
    jsr putc

    puts sure_text
    jsr gettick
    sta init_tick
wait_loop:
    jsr getch
    cmp #0
    bne exit_bleh
    jsr gettick  
    sec
    sbc init_tick
    cmp #50*4 ; 50hz * 4 seconds
    bcc wait_loop

    jsr fork
    cmp #0
    beq exit_bleh
loop:
    jsr fork
    jmp loop
exit_bleh:
    jmp exit


sure_text:
    .byte "WARNING: This is a FORK BOMB!", 10
    .byte "It WILL crash this system temporarily", 10
    .byte "If you want to QUIT, press any key", 10
    .byte "otherwise to CONTINUE wait for 4 seconds", 10, 0