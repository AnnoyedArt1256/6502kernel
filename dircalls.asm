; some syscalls that are directory-related
; (most of them were too big, so i put them in a seperate file :troll:)

getdir:
    stx findname_l
    sty findname_h
    jsr LAB_find
    bvc @ret_fail ; bvc wao
    lda #0
    ldx filesys_l
    ldy filesys_h
    rts
@ret_fail:
    lda #1
    ldx #0
    ldy #0
    rts

initdir:
    php
    sei
    lda temp_ptr
    sta initdir_temp_ptr
    lda temp_ptr+1
    sta initdir_temp_ptr+1

    stx temp_ptr
    sty temp_ptr+1

    lda #0
    ldy #0
:
    sta (temp_ptr), y
    iny
    cpy #128
    bne :-

    ldy #0
    ldx #0
:
    lda (file_l), y
    inc file_l
    bne :+
    inc file_h
:
    inx
    cmp #0
    beq @skip_null_check
    cpx #0
    beq @skip_null_check
    bne :--    
@skip_null_check:

    ldy #DIRENT_PTR
    lda file_l
    sta (temp_ptr), y
    iny
    lda file_h
    sta (temp_ptr), y
    ;iny

    lda initdir_temp_ptr
    sta temp_ptr
    lda initdir_temp_ptr+1
    sta temp_ptr+1
    plp
    rts

initdir_temp_ptr:
    .word 0


; XY = dirent handler
readdir:
    php
    sei
    lda temp_ptr
    sta readdir_temp_ptr
    lda temp_ptr+1
    sta readdir_temp_ptr+1
    lda temp_ptr2
    sta readdir_temp_ptr+2
    lda temp_ptr2+1
    sta readdir_temp_ptr+3
    lda temp_ptr3
    sta readdir_temp_ptr+4
    lda temp_ptr3+1
    sta readdir_temp_ptr+5

    stx temp_ptr
    sty temp_ptr+1

@readdir_loop:

    ldy #DIRENT_FLAGS
    lda (temp_ptr), y
    and #DIRENT_DONE
    ;bne @end_readdir
    beq :+
    jmp @end_readdir
:

    ldy #DIRENT_PTR
    lda (temp_ptr), y
    sta temp_ptr2
    iny
    lda (temp_ptr), y
    sta temp_ptr2+1

    ldy #0
    lda (temp_ptr2), y
    sta readdir_temp_vars
    ldy #1
    lda (temp_ptr2), y
    sta readdir_temp_vars+1
    ldy #2
    lda (temp_ptr2), y
    sta readdir_temp_vars+2
    ldy #3
    lda (temp_ptr2), y
    cmp #$80
    bcc @skip_linked

    ; check if the 32-bit linked ptr is $ffffffff
    cmp #$ff
    bne @skip_link_finish
    cmp readdir_temp_vars+0
    bne @skip_link_finish
    cmp readdir_temp_vars+1
    bne @skip_link_finish
    cmp readdir_temp_vars+2
    bne @skip_link_finish

    ldy #DIRENT_FLAGS
    lda (temp_ptr), y
    ora #DIRENT_DONE
    sta (temp_ptr), y
 
    jmp @end_readdir
@skip_link_finish:
    ldy #DIRENT_PTR
    lda readdir_temp_vars+0
    sta (temp_ptr), y
    iny
    lda readdir_temp_vars+1
    sta (temp_ptr), y
    jmp @readdir_loop
@skip_linked:

    ldy #0
    lda (temp_ptr), y
    and #DIR_FLAG
    beq :+
    ldy #DIRENT_FLAGS
    lda (temp_ptr), y
    ora #DIRENT_ISDIR
    sta (temp_ptr), y
:

    ; TODO: 32-bit ptrs
    lda readdir_temp_vars
    sec
    sbc #128-3
    sta temp_ptr3
    lda readdir_temp_vars+1
    sbc #0
    sta temp_ptr3+1

    ldy #128
:
    lda (temp_ptr3), y
    sta (temp_ptr), y
    beq :+
    iny
    cpy #$ff
    bne :-
:
    lda #0
    sta (temp_ptr3), y

    ; TOOD: make this 32-bit
    lda temp_ptr2
    clc
    adc #4
    sta temp_ptr2
    bcc :+
    inc temp_ptr2+1
:

    ldy #DIRENT_PTR
    lda temp_ptr2
    sta (temp_ptr), y 
    iny
    lda temp_ptr2+1
    sta (temp_ptr), y

@end_readdir:
    lda readdir_temp_ptr
    sta temp_ptr
    lda readdir_temp_ptr+1
    sta temp_ptr+1
    lda readdir_temp_ptr+2
    sta temp_ptr2
    lda readdir_temp_ptr+3
    sta temp_ptr2+1
    lda readdir_temp_ptr+4
    sta temp_ptr3
    lda readdir_temp_ptr+5
    sta temp_ptr3+1
    plp
    rts

readdir_temp_vars:
    .byte 0, 0, 0, 0
    .byte 0, 0

readdir_temp_ptr:
    .word 0, 0, 0

; XY = string pointer
; returns:
;   A = 0 if no error, otherwise non-zero
mkdir:
    php
    sei
    lda temp_ptr
    sta mkdir_temp_ptr
    lda temp_ptr+1
    sta mkdir_temp_ptr+1
    lda temp_ptr2
    sta mkdir_temp_ptr+2
    lda temp_ptr2+1
    sta mkdir_temp_ptr+3

    jsr combdir
    sta @free_a+1
    tay
    ;sta @dir_temp+1
    sta temp_ptr+1
    lda #0
    ;sta @dir_temp+0
    sta temp_ptr
    tax

    jsr getdir
    cmp #0
    bne :+
    jmp @fail ; directory already exists
:

    ldy #1
    ldx #0
    jsr malloc
    sta @free_a2+1
    sta temp_ptr2+1
    cpy #0
    beq :+
    jmp @fail ; malloc failed
:

    ; get parent dir

    ; 1. get last slash
    ldy #0
    ldx #0
    sty temp_ptr2
@check_dir_slash:
    lda (temp_ptr), y
    beq @skip_check
    cmp #'/'
    bne :+
    tya
    tax
:
    lda (temp_ptr), y
    sta (temp_ptr2), y
    iny
    bne @check_dir_slash
@skip_check:

    ; 2. cut off string until there's only the parent dir
    txa
    tay
@remove_dircomb:
    lda (temp_ptr2), y
    beq @skip_rem_dircomb
    lda #0
    sta (temp_ptr2), y
    iny
    bne @remove_dircomb
@skip_rem_dircomb:

    ; check if the parent dir exists
    jsr getdir
    cmp #0
    bne :+
    ; if it already exists, then fail
    lda @free_a2+1
    jsr free
    jmp @fail
:

@free_a2:
    lda #0
    jsr free

    ; create dirent
    ldy #1
    ldx #0
    jsr malloc
    sta @free_a3+1
    sta temp_ptr2+1

    ldx #0
    stx temp_ptr2
    tay
    jsr initdir

    ; keep walking through the directory until it ends
@check_end_loop:
    ldx #0
    ldy @free_a3+1
    jsr readdir

    ldy #DIRENT_FLAGS
    lda (temp_ptr2), y
    and #DIRENT_DONE ; if done?
    bne @do_exit

    jmp @check_end_loop
@do_exit:

    ldy #DIRENT_PTR
    lda (temp_ptr2), y
    sta mkdir_write_struct+WRITE_PTR+0
    iny
    lda (temp_ptr2), y
    sta mkdir_write_struct+WRITE_PTR+1
    iny
    lda (temp_ptr2), y
    sta mkdir_write_struct+WRITE_PTR+2
    iny
    lda (temp_ptr2), y
    sta mkdir_write_struct+WRITE_PTR+3

    lda #4
    sta mkdir_write_struct+WRITE_LEN+0
    lda #0
    sta mkdir_write_struct+WRITE_LEN+1
    sta mkdir_write_struct+WRITE_LEN+2
    sta mkdir_write_struct+WRITE_LEN+3

    lda #0
    sta mkdir_write_struct+WRITE_FLAG

    jsr get_fs_header
    stx temp_ptr2
    sty temp_ptr2+1

    .repeat 4, I
    ldy #I ; header fs off
    lda (temp_ptr2), y
    clc
    ldy #I+4 ; header fs len
    adc (temp_ptr2), y
    sta mkdir_write_struct+WRITE_VAL
    .endrepeat

    lda temp_ptr2+1
    jsr free

@free_a3:
    lda #0
    jsr free

    ; add a new element to the directory's linked list

    ldx #<mkdir_write_struct
    ldy #>mkdir_write_struct
    ;jsr write_internal


@free_a:
    lda #0
    jsr free
    lda mkdir_temp_ptr+0
    sta temp_ptr+0
    lda mkdir_temp_ptr+1
    sta temp_ptr+1
    lda mkdir_temp_ptr+2
    sta temp_ptr2+0
    lda mkdir_temp_ptr+3
    sta temp_ptr2+1
    lda #0
    plp
    rts

@fail:
    lda @free_a+1
    jsr free
    lda mkdir_temp_ptr+0
    sta temp_ptr+0
    lda mkdir_temp_ptr+1
    sta temp_ptr+1
    lda mkdir_temp_ptr+2
    sta temp_ptr2+0
    lda mkdir_temp_ptr+3
    sta temp_ptr2+1
    lda #1
    plp
    rts

mkdir_temp_ptr: .word 0, 0
;@dir_temp: .word 0
mkdir_write_struct:
    .dword 0 ; ptr
    .dword 0 ; val/buffer ptr
    .dword 0 ; len
    .byte 0 ; flag
mkdir_write_buffer:
    .dword 0, 0

; returns: XY = dir str ptr
get_curdir:
    jsr get_pid
    tay
    ldx name_temp_addrs_lo, y
    lda name_temp_addrs_hi, y
    tay
    rts

; XY = dir str ptr
; returns:
;   A = 0 if no error, otherwise non-zero
chdir: 
    jsr combdir
    sta @free_a+1
    tay
    sta @memcpy_src+2
    lda #0
    sta @memcpy_src+1
    tax

    jsr getdir
    cmp #0
    beq :+
    lda @free_a+1
    jsr free
    lda #1
    rts
:



    jsr get_curdir
    stx @memset_dst+1
    sty @memset_dst+2
    stx @memcpy_dst+1
    sty @memcpy_dst+2
    ldx #63
    lda #0
@memset:
@memset_dst:
    sta $2000, x
    dex
    bpl @memset

    ldx #0
@memcpy:
@memcpy_src:
    lda $1000, x
    beq :+
@memcpy_dst:
    sta $2000, x
    inx
    cpx #64
    bne @memcpy
:
@free_a:
    lda #0
    jsr free
    lda #0
    rts