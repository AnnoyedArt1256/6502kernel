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
ptr: .res 4
argc: .res 1
args: .res 2

.code
.include "../kernel.inc"
.include "../kernel_calls.inc"

test_process:
    sei
    stx args
    sty args+1
    sta argc

    jsr get_curdir
    lda argc
    cmp #2
    bcc @skip_arg

    ldy #0
:
    lda (args), y
    beq :+
    iny
    bne :-
:
    iny
    tya
    clc
    adc args
    sta args
    lda args+1
    adc #0
    sta args+1
    tay
    ldx args
    jsr combdir
    pha
    ldx #0
    tay
    jsr getdir
    pla
    jsr free
    jmp @skip_arg2
@skip_arg:
    jsr getdir
@skip_arg2:

    ;ldx #<dir_test
    ;ldy #>dir_test
    ;jsr getdir
    ldx #<dirinfo_src_dir
    ldy #>dirinfo_src_dir
    jsr dirinfo
    ; TODO: FOR NOW (with our RomFS solution)
ls_loop:
    lda dirinfo_src_dir+0
    ora dirinfo_src_dir+1
    beq do_exit

    lda dirinfo_src_dir+4
    sta ptr
    lda dirinfo_src_dir+5
    sta ptr+1

    ldy #0
    lda (ptr),y ; dir_ptr
    clc
    adc #3
    sta ptr+2 
    ldy #1
    lda (ptr),y ; dir_ptr
    adc #0
    sta ptr+3 

    ldy #0
:
    lda (ptr+2), y
    beq :+
    jsr_save putc
    iny
    jmp :-    
:
    lda #$0a
    jsr putc

    lda dirinfo_src_dir+4 ; dir_ptr
    clc
    adc #2
    sta dirinfo_src_dir+4 ; dir_ptr
    lda dirinfo_src_dir+5 ; dir_ptr+1
    adc #0
    sta dirinfo_src_dir+5 ; dir_ptr+1

    ; dec16 dirinfo_src_dir+0
    lda dirinfo_src_dir+0
    sec
    sbc #2
    sta dirinfo_src_dir+0
    lda dirinfo_src_dir+1
    sbc #0
    sta dirinfo_src_dir+1
    jmp ls_loop
do_exit:
    cli
    jsr exit

.byte $aa

dirinfo_src_dir: 
        ; len, name, dir_ptr
    .word 0, 0, 0

;dir_test:
;    .byte "/", 0 