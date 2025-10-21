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
argc: .res 1
args: .res 2
regs: .res 3
temp: .res 2
ptr: .res 2
sid_len: .res 2
is_psid: .res 1
load_hibyte: .res 1

jsr_addrs:
    load_addr: .res 2
    init_addr: .res 2
    play_addr: .res 2

startsong: .res 1
songamt: .res 1

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

    jmp start

driver:
    ldx #$1f
:
    lda $e0, x
    sta driver_zp, x
    lda driver_zp+32, x
    sta $e0, x
    dex
    bpl :-

    dec $d020
driver_play:
    jsr $1003
    inc $d020

    ldx #$1f
:
    lda $e0, x
    sta driver_zp+32, x
    lda driver_zp, x
    sta $e0, x
    dex
    bpl :-

    jmp exit_nmi
driver_zp:
    .res 32, 0 
    .res 32, 0

sh_exec:
    .byte "/bin/sh", 0

hexnums:
    .byte "0123456789ABCDEF"

instructions_str:
    .byte 10
    .byte "Keys: Z,X for switching subtunes", 10
    .byte "      S for opening a BG shell  ", 10
    .byte "Press any other key to exit", 10, 10, 0

subtune_str:
    .byte "Playing subtune $", 0

main_loop:
    puts instructions_str
    puts subtune_str
    lda startsong
    and #$0f
    tax
    lda hexnums, x
    jsr putc

    lda startsong
    lsr
    lsr
    lsr
    lsr
    tax
    lda hexnums, x
    jsr putc

    lda #$0a
    jsr putc

    ldx #$1f
:
    lda $e0, x
    sta driver_zp, x
    lda driver_zp+32, x
    sta $e0, x
    dex
    bpl :-

    lda startsong
init_addr_jsr:
    jsr init_addr

    ldx #$1f
:
    lda $e0, x
    sta driver_zp+32, x
    lda driver_zp, x
    sta $e0, x
    dex
    bpl :-

    cli
    ldx #<driver
    ldy #>driver
    jsr setnmi ; already sets nmi at 50hz

    ldx #255
:
    jsr getch
    cmp #0
    beq :+
    dex
    bne :-
:

getch_check_loop:
    jsr getch
    cmp #'X'
    beq next_song
    cmp #'Z'
    beq prev_song
    cmp #'S'
    beq do_sh
    cmp #0
    bne :+
    jmp getch_check_loop
:

main_loop_exit:
    jsr clearnmi
    ; clear sid regs
    ldx #$38 ; 2SID (outerversal moment)
    lda #0
:
    sta $d400, x
    dex
    bpl :-

    lda load_hibyte+0
    jsr free
    jmp exit

next_song:
    inc startsong
    lda startsong
    cmp songamt
    bcc :+
    lda #0
    sta startsong
:
    jmp main_loop

prev_song:
    lda songamt
    cmp #2
    bcc :++
    lda startsong
    beq :+
    lda songamt
    sta startsong
    jmp main_loop
:
    dec startsong
:
    jmp main_loop

do_sh:
    ldx #<sh_exec
    ldy #>sh_exec
    jsr exec   
    cmp #0
    bne getch_check_loop
    tya
    tax
:
    jsr check_pid_exist
    cmp #$ff
    beq :-
    jmp getch_check_loop

start:
    sei
    stx args
    sty args+1
    sta argc
    cli

    lda argc
    beq do_exit_arg ; (argc == 0), whart?!?!?
    dec argc
    lda argc
    beq do_exit_arg ; argc == 1

    jsr skip_arg
    jsr print_arg

    lda play_addr+1
    sta driver_play+1
    lda play_addr+0
    sta driver_play+2

    lda init_addr+1
    sta init_addr_jsr+1
    lda init_addr+0
    sta init_addr_jsr+2

    sei
    jmp main_loop

do_exit_arg:
    puts error_arg
    jmp exit

read_ptr:
    ldx ptr
    ldy ptr+1
    jmp fgetc

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

skip_ptr:
    sta @cmp_ptr+1
    ldx #0
    stx temp
:
    jsr read_ptr
    ldx temp
    inx
    stx temp
@cmp_ptr:
    cpx #6
    bne :-
    rts

read_str:
    ldx #0
    stx temp
:
    jsr read_ptr
    jsr putc
    ldx temp
    inx
    stx temp
    cpx #$20
    bne :-
    lda #$0a
    jsr putc ; newline
    rts


print_arg:
    ldx args
    ldy args+1
    jsr fopen
    cmp #0
    beq :+
    jmp @fail
:

    stx ptr+1
    lda #0
    sta ptr

    .repeat 4, I
    jsr read_ptr
    cmp psid_ident+I
    beq :+
    jmp @fail_rsid
:
    .endrepeat

    lda #6
    jsr skip_ptr

    ldx #0
    stx temp
:
    jsr read_ptr
    ldx temp
    sta jsr_addrs+2, x
    inx
    stx temp
    cpx #4
    bne :-

    ; songamt
    jsr read_ptr
    sta songamt
    jsr read_ptr

    ; startsong
    jsr read_ptr
    sta startsong
    jsr read_ptr

    lda #$7c-$12
    jsr skip_ptr

    jsr read_ptr
    sta load_addr+1
    jsr read_ptr
    sta load_addr+0

    lda #0
    sta sid_len
    sta sid_len+1

:
    ldx ptr
    ldy ptr+1
    jsr iseof
    cmp #0
    bne :++
    jsr read_ptr
    inc sid_len
    bne :+
    inc sid_len+1
:
    jmp :--
:

    lda load_addr+0
    sta load_hibyte
    ldy sid_len+1
    iny
    jsr malloc_range

    ldy ptr+1
    jsr fclose




    ; get data

    ldx args
    ldy args+1
    jsr fopen
    cmp #0
    beq :+
    jmp @fail
:
    stx ptr+1
    lda #0
    sta ptr

    lda #$16
    jsr skip_ptr

    
    ldx #0
    jsr sid_strs_puts
    jsr read_str

    ldx #10
    jsr sid_strs_puts
    jsr read_str

    ldx #20
    jsr sid_strs_puts
    jsr read_str

    ldx #0
    stx temp
:
    jsr read_ptr
    ldx temp
    inx
    stx temp
    cpx #($7c-$76)+2
    bne :-

    ldx load_addr
    ldy load_addr+1
    sty load_addr
    stx load_addr+1

:
    ldx ptr
    ldy ptr+1
    jsr iseof
    cmp #0
    bne :++
    jsr read_ptr
    ldy #0
    sta (load_addr), y
    inc load_addr
    bne :+
    inc load_addr+1
:
    jmp :--
:

    ldy ptr+1
    jsr fclose
    rts
@fail:
    puts file_not_found_err
    puts_indy args
    lda #$0a
    jsr putc
    ldx temp
    rts
@fail_rsid:
    puts error_rsid_unk
    lda #$0a
    jsr putc
    ldx temp
    rts

sid_strs:
    .byte "Title  : ", 0
    .byte "Author : ", 0
    .byte "Release: ", 0

sid_strs_puts:
@loop:
    lda sid_strs, x
    beq @loop_skip
    jsr_save putc
    inx
    bne @loop
@loop_skip:
    rts

error_rsid_unk:
    .byte "ERROR:", 10
    .byte "This SID player only plays "
psid_ident: ; heehee
    .byte "PSID"
    .byte " files", 10, 0

error_arg:
    .byte "sid: not enough arguments", 10, 0

file_not_found_err:
    .byte "sid: no such file or directory: ",0