.feature c_comments
.import __ZP_START__, __ZP_LAST__

.define SHOW_DIR 0

.segment "HEADER"
    stx *+14
    sta *+9
    lda #<(__ZP_LAST__ - __ZP_START__)
    jsr set_zpsize
    lda #0
    ldx #0

.zeropage
key_buffer_ind: .res 1
ptr: .res 1
argc: .res 1
args: .res 2
exec_from_file: .res 1
exec_handler: .res 2
done_exec: .res 1

.code
.include "../kernel.inc"
.include "../kernel_calls.inc"

.macro do_fgetc addr
    .local @xl, @yl
    stx @xl+1
    sty @yl+1
    ldx addr
    ldy addr+1
    jsr fgetc
@xl:
    ldx #0
@yl:
    ldy #0
.endmacro

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

.macro puts_ind addr, ind
    .local @loop, @loop_skip
    ldx #3
@loop:
    lda addr, x
    beq @loop_skip
    jsr_save putc
    inx
    bne @loop
@loop_skip:
.endmacro

start:
    stx args
    sty args+1
    sta argc

    lda #0
    sta key_buffer_ind
    sta exec_from_file
    sta exec_handler+0
    sta exec_handler+1

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
    lda #1
    sta exec_from_file

    ldx args
    ldy args+1
    jsr fopen
    stx exec_handler+1
    ldx #0
    stx exec_handler ; just in case

    cmp #0 ; check if invalid file
    beq @skip_arg
    stx exec_handler+1
    stx exec_from_file
@skip_arg:

line_start:
    lda exec_from_file
    bne loop

    .if SHOW_DIR = 1
        jsr get_curdir
        stx ptr
        sty ptr+1
        ldy #0
    @loop_dir:
        lda (ptr), y
        beq :+
        jsr_save putc
        iny
        bne @loop_dir
    :
        lda #' '
        jsr putc
    .endif
    lda #'$'
    jsr putc
    lda #' '
    jsr putc

loop:
    lda exec_from_file
    beq @key_loop

    ldx exec_handler
    ldy exec_handler+1
    jsr iseof
    beq :++
    lda done_exec
    beq :+
    jmp exit
:
    ldy exec_handler+1
    jsr fclose
    lda #1
    sta done_exec
    lda #$0a ; last newline in file
    jmp @skip_caps
:

    do_fgetc exec_handler
    jmp @skip_caps

@key_loop:
    jsr getch_poll
    cmp #0
    beq @key_loop
@skip_key:

    and #$7f

    cmp #'A'
    bcc :+
    cmp #'Z'+1
    bcs :+
    clc
    adc #'a'-'A'
:
@skip_caps:

    cmp #$14
    beq backspace

    cmp #$0a
    beq return

    ldx key_buffer_ind
    sta key_buffer, x
    inc key_buffer_ind

    ldx exec_from_file
    bne loop

    jsr putc
    jmp loop
    
backspace:
    lda key_buffer_ind
    beq loop

    lda #8
    jsr putc

    dec key_buffer_ind
    ldx key_buffer_ind
    lda #0
    sta key_buffer, x
    jmp loop


return:
    lda exec_from_file
    bne :+
    lda #$0a
    jsr putc
:

    ; TODO: add arguments **properly**
    ldy #0
    ldx #0
@read_buffer:
    lda key_buffer, x
    beq @skip_read_buffer
    cmp #$20
    bne :+
    lda #0
    sta key_buffer, x
    iny
:
    inx
    bne @read_buffer
@skip_read_buffer:
    cpx #0
    bne :+
    jmp @skip_to_reset_buffer ; skip exec if input line is **empty**
:

    iny
    sty @argc_cnt+1

    ldx #0
@check_exit:
    lda exit_cmd, x
    eor key_buffer, x
    bne @skip_exit
    inx
    cpx #exit_cmd_end-exit_cmd
    bne @check_exit
    jmp exit
@skip_exit:

    ldx #0
@check_cd:
    lda cd_cmd, x
    eor key_buffer, x
    bne @skip_cd
    inx
    cpx #cd_cmd_end-cd_cmd
    bne @check_cd

    txa
    clc
    adc #<key_buffer
    tax
    lda #>key_buffer
    adc #0
    tay
    jsr chdir
    cmp #0
    beq :+
    jsr print_no_such_file_dir_cd
:
    jmp @skip_to_reset_buffer
@skip_cd:

    ldx key_buffer
    lda valid_chars_path, x
    cmp #' '
    beq @argc_cnt

    tya
    ldx #<bin_path ; hacky, i know
    ldy #>bin_path
    jsr exec   
    cmp #0
    beq @exec_success

@argc_cnt:
    lda #0
    ldx #<key_buffer
    ldy #>key_buffer
    jsr exec
    cmp #0
    bne :++

@exec_success:
    pha
    tya
    tax
:
    jsr check_pid_exist
    cmp #$ff
    beq :-
    pla
:

    cmp #1
    bne :+
    puts file_not_found_err
    puts key_buffer
    lda #$0a
    jsr putc
:
    cmp #2
    bne :+
    puts file_is_dir_err
    puts key_buffer
    puts file_is_dir_err_final
    lda #$0a
    jsr putc
:

@skip_to_reset_buffer:
    lda #0
    ldx #0
:
    sta key_buffer, x
    inx
    bne :-
    sta key_buffer_ind
    jmp line_start

print_no_such_file_dir_cd:
    puts file_not_found_err
    puts_ind key_buffer, 3
    lda #$0a
    jmp putc ; jsr putc
    ; rts

bin_path:
    .byte "/bin/" ; :troll:
key_buffer:
    .res 256, 0

file_not_found_err:
    .byte "sh: no such file or directory: ",0
file_is_dir_err:
    .byte "sh: ",0
file_is_dir_err_final:
    .byte " is a directory",0
cd_cmd:
    .byte "cd",0
cd_cmd_end:

exit_cmd:
    .byte "exit",0
exit_cmd_end:


valid_chars_path:
    .byte "                                             @                   @@@@@@@@@@@@@@@@@@@@@@@@@@@   @ @@@@@@@@@@@@@@@@@@@@@@@@@@@@                                                                                                                                   "

/*
a=new Array(256).fill(0);
for(i=65;i<=90;i++)a[i]=1;
// for [
a[91]=1;
a[123]=1; // {
a[124]=1; // }
a[45]=1; // -
a[95]=1; // _
for(i=97;i<=122;i++)a[i]=1;
a.map(x=>x?"@":" ").join("")
*/
