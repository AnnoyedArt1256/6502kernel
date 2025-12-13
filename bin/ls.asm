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
    jsr initdir

ls_loop:
    ldx #<dirinfo_src_dir
    ldy #>dirinfo_src_dir
    jsr readdir

    lda dirinfo_src_dir+DIRENT_FLAGS
    and #DIRENT_DONE
    bne do_exit

    ldy #0
:
    lda dirinfo_src_dir+128, y
    beq :+
    jsr_save putc
    iny
    cpy #128
    bne :-    
:

    lda #$0a
    jsr putc
    jmp ls_loop
do_exit:
    cli
    jsr exit

.byte $aa

dirinfo_src_dir: 
;        ; len, name, dir_ptr
;    .word 0, 0, 0
    .dword 0 ; dir_ptr
    .byte 0 ; flags
    .res 16-(4+1) ; padded to 16 bytes
    .res 128 ; filename

;dir_test:
;    .byte "/", 0 