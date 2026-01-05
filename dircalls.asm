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

    ; skip 48-char name
    ;lda file_l
    ;clc
    ;adc #48
    ;sta file_l
    ;bcc :+
    ;inc file_h
;: 
;@skip_null_check:

    ldy #DIRENT_PTR
    lda filesys_l
    sta (temp_ptr), y
    iny
    lda filesys_h
    sta (temp_ptr), y
    ;iny

    ldy #DIRENT_CLUSTER
    lda file_cluster
    sta (temp_ptr), y
    iny
    lda file_cluster+1
    sta (temp_ptr), y
    
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

    ldx #<temp_ptr2
    jsr read_internal
    inc temp_ptr2
    bne :+
    inc temp_ptr2+1
:
    sta readdir_temp_vars
    sta temp_ptr3
    ldx #<temp_ptr2
    jsr read_internal
    inc temp_ptr2
    bne :+
    inc temp_ptr2+1
:
    sta readdir_temp_vars+1
    sta temp_ptr3+1
    ldx #<temp_ptr2
    jsr read_internal
    inc temp_ptr2
    bne :+
    inc temp_ptr2+1
:
    sta readdir_temp_vars+2
    ldx #<temp_ptr2
    jsr read_internal
    inc temp_ptr2
    bne :+
    inc temp_ptr2+1
:
    cmp #$ff
    bne @skip_end

    ; check if the 32-bit linked ptr is $ffffffff
    ;cmp #$ff
    ;bne @skip_link_finish
    ;cmp readdir_temp_vars+0
    ;bne @skip_link_finish
    ;cmp readdir_temp_vars+1
    ;bne @skip_link_finish
    ;cmp readdir_temp_vars+2
    ;bne @skip_link_finish

    ldy #DIRENT_FLAGS
    lda (temp_ptr), y
    ora #DIRENT_DONE
    sta (temp_ptr), y
 
    jmp @end_readdir
@skip_end:

    lda temp_ptr2
    and #$3f
    bne :+
    jmp @next_clusters
@end_next_clusters:
:
    
    ldx #<temp_ptr3
    jsr read_internal
    and #DIR_FLAG
    beq :+
    ldy #DIRENT_FLAGS
    lda (temp_ptr), y
    ora #DIRENT_ISDIR
    sta (temp_ptr), y
:

    ; TODO: 32-bit ptrs
    lda temp_ptr3
    clc
    adc #3
    sta temp_ptr3
    bcc :+
    inc temp_ptr3+1
:

    ldy #128
@name_loop:
    ldx #<temp_ptr3
    jsr read_internal
    inc temp_ptr3
    bne :+
    inc temp_ptr3+1
:
    sta (temp_ptr), y
    beq @skip_name_loop
    iny
    cpy #128+48
    bne @name_loop
@skip_name_loop:
    lda #0
    sta (temp_ptr), y

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

@next_clusters:
    ; ABCDEFGHIJKLMNOP
    ; GHIJKLMNOP000000
    ldy #DIRENT_CLUSTER
    lda (temp_ptr), y
    iny
    clc
    adc #8>>1
    sta filesys_l
    lda (temp_ptr), y
    adc #0
    sta filesys_h

    asl filesys_l
    rol filesys_h

    ldx #<filesys_l
    jsr read_internal
    ldy #DIRENT_CLUSTER
    sta (temp_ptr), y

    inc filesys_l

    ldx #<filesys_l
    jsr read_internal
    ldy #DIRENT_CLUSTER+1
    sta (temp_ptr), y
    sta filesys_h
    dey
    lda (temp_ptr), y
    sta filesys_l

    ; thanks llvm-mos :szok:
    lsr filesys_h
    ror filesys_l
    lda #0
    ror
    lsr filesys_h
    ror filesys_l
    ror
    clc
    adc fs_start_off
    ldy #DIRENT_PTR
    sta (temp_ptr), y
    lda filesys_l
    adc fs_start_off+1
    iny
    sta (temp_ptr), y
    jmp @end_next_clusters

readdir_temp_vars:
    .byte 0, 0, 0, 0
    .byte 0, 0

readdir_temp_ptr:
    .word 0, 0, 0

; this is the magnum opus of shit code
; do not read if you DO NOT want to wish to kill yourself after reading this code
; this code made me rethink my entire life choices
; "why am i doing shit in 6502 asm?"
; "i should have done an OS in risc-v and called it a day"
; "why am i doing THIS BULLSHIT for a school project?"
; "i should have just continued programming in Scratch for fucks sake"
; AGAIN, DO NOT READ THIS CODE UNLESS YOU WANT TO HAVE A BRAIN ANEURYSM

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
    sta mkdir_filename_offset
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
    ldx temp_ptr2
    ldy temp_ptr2+1
    jsr getdir

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
    beq @check_end_loop

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
    sta mkdir_write_header_off+I
    .if I = 0
        clc
    .endif
    ldy #I+4 ; header fs len
    adc (temp_ptr2), y
    sta mkdir_write_struct+WRITE_VAL+I
    sta mkdir_write_addr+I
    .endrepeat

    lda temp_ptr2+1
    jsr free

@free_a3:
    lda #0
    jsr free

    ; add a new element to the directory's linked list

    ldx #<mkdir_write_struct
    ldy #>mkdir_write_struct
    jsr write_internal
    
    ; add the end element value ($ffffffff)

    lda #4
    jsr mkdir_add_addr ; WTF?

    lda mkdir_write_struct+WRITE_PTR+0
    sta mkdir_last_item_off+0
    lda mkdir_write_struct+WRITE_PTR+1
    sta mkdir_last_item_off+1
    lda mkdir_write_struct+WRITE_PTR+2
    sta mkdir_last_item_off+2
    lda mkdir_write_struct+WRITE_PTR+3
    sta mkdir_last_item_off+3

    lda #$ff
    sta mkdir_write_struct+WRITE_VAL+0
    sta mkdir_write_struct+WRITE_VAL+1
    sta mkdir_write_struct+WRITE_VAL+2
    sta mkdir_write_struct+WRITE_VAL+3

    ldx #<mkdir_write_struct
    ldy #>mkdir_write_struct
    jsr write_internal
    
    .repeat 4, I
        lda mkdir_write_addr+I
        sta mkdir_write_struct+WRITE_PTR+I
    .endrepeat

    lda #$40 ; DIR_FLAG
    sta mkdir_write_struct+WRITE_VAL+0
    lda #0
    sta mkdir_write_struct+WRITE_VAL+1
    sta mkdir_write_struct+WRITE_VAL+2

    lda #3
    sta mkdir_write_struct+WRITE_LEN+0

    ldx #<mkdir_write_struct
    ldy #>mkdir_write_struct
    jsr write_internal

    lda #3-1
    jsr mkdir_add_addr

    ldx #0
    ldy mkdir_filename_offset
    iny
@write_name:
    lda (temp_ptr), y
    beq @skip_write_name

    jsr_save write_byte_mkdir

    iny
    inx
    cpx #48
    bne @write_name
@skip_write_name:
    dex
@write_blank:
    lda #0
    jsr_save write_byte_mkdir
    inx
    cpx #48
    bne @write_blank

    jsr write_end_marker ; for the newly created directory
    lda mkdir_write_struct+WRITE_PTR+0
    sta mkdir_off_temp+0
    lda mkdir_write_struct+WRITE_PTR+1
    sta mkdir_off_temp+1
    lda mkdir_write_struct+WRITE_PTR+2
    sta mkdir_off_temp+2
    lda mkdir_write_struct+WRITE_PTR+3
    sta mkdir_off_temp+3
    jsr write_end_marker ; for the parent directory's linked list

    ; update the fs length dword
    lda mkdir_write_struct+WRITE_PTR+0
    sec
    sbc mkdir_write_header_off+0
    sta mkdir_write_struct+WRITE_VAL+0
    lda mkdir_write_struct+WRITE_PTR+1
    sbc mkdir_write_header_off+1
    sta mkdir_write_struct+WRITE_VAL+1
    lda mkdir_write_struct+WRITE_PTR+2
    sbc mkdir_write_header_off+2
    sta mkdir_write_struct+WRITE_VAL+2
    lda mkdir_write_struct+WRITE_PTR+3
    sbc mkdir_write_header_off+3
    sta mkdir_write_struct+WRITE_VAL+3

    ; TODO: make it more portable
    lda #4
    sta mkdir_write_struct+WRITE_LEN+0
    lda #<(FS_header+4)
    sta mkdir_write_struct+WRITE_PTR+0
    lda #>(FS_header+4)
    sta mkdir_write_struct+WRITE_PTR+1
    lda #0
    sta mkdir_write_struct+WRITE_PTR+2
    sta mkdir_write_struct+WRITE_PTR+3

    ldx #<mkdir_write_struct
    ldy #>mkdir_write_struct
    jsr write_internal

    ; finally, write the parent directory's last index (i am so fucking tired)
    lda mkdir_last_item_off+0
    sta mkdir_write_struct+WRITE_PTR+0
    lda mkdir_last_item_off+1
    sta mkdir_write_struct+WRITE_PTR+1
    lda mkdir_last_item_off+2
    sta mkdir_write_struct+WRITE_PTR+2
    lda mkdir_last_item_off+3
    sta mkdir_write_struct+WRITE_PTR+3

    lda mkdir_off_temp+0
    sta mkdir_write_struct+WRITE_VAL+0
    lda mkdir_off_temp+1
    sta mkdir_write_struct+WRITE_VAL+1
    lda mkdir_off_temp+2
    sta mkdir_write_struct+WRITE_VAL+2
    lda mkdir_off_temp+3
    ora #$80
    sta mkdir_write_struct+WRITE_VAL+3

    ldx #<mkdir_write_struct
    ldy #>mkdir_write_struct
    jsr write_internal 

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
mkdir_write_addr: .dword 0
mkdir_write_header_off: .dword 0
mkdir_filename_offset: .byte 0
mkdir_last_item_off: .dword 0
mkdir_off_temp: .dword 0

write_byte_mkdir:
    sta mkdir_write_struct+WRITE_VAL

    inc mkdir_write_struct+WRITE_PTR+0
    bne :+
    inc mkdir_write_struct+WRITE_PTR+1
    bne :+
    inc mkdir_write_struct+WRITE_PTR+2
    bne :+
    inc mkdir_write_struct+WRITE_PTR+3
    bne :+
:

    lda #1
    sta mkdir_write_struct+WRITE_LEN+0

    ldx #<mkdir_write_struct
    ldy #>mkdir_write_struct
    jmp write_internal

mkdir_add_addr:
    clc
    adc mkdir_write_struct+WRITE_PTR+0
    sta mkdir_write_struct+WRITE_PTR+0
    lda mkdir_write_struct+WRITE_PTR+1
    adc #0
    sta mkdir_write_struct+WRITE_PTR+1
    lda mkdir_write_struct+WRITE_PTR+2
    adc #0
    sta mkdir_write_struct+WRITE_PTR+2
    lda mkdir_write_struct+WRITE_PTR+3
    adc #0
    sta mkdir_write_struct+WRITE_PTR+3
    rts

write_end_marker:
    ; write end marker and extra element (for when the directory gets added w/ files)
    lda #$ff
    sta mkdir_write_struct+WRITE_VAL+0
    sta mkdir_write_struct+WRITE_VAL+1
    sta mkdir_write_struct+WRITE_VAL+2
    sta mkdir_write_struct+WRITE_VAL+3
    lda #4
    sta mkdir_write_struct+WRITE_LEN+0
    lda #0
    sta mkdir_write_struct+WRITE_FLAG

    ldx #<mkdir_write_struct
    ldy #>mkdir_write_struct
    jsr write_internal
    
    ; this whole syscall is so unoptimized i fucking hate it
    lda #4
    jsr mkdir_add_addr

    lda #0
    sta mkdir_write_struct+WRITE_VAL+0
    sta mkdir_write_struct+WRITE_VAL+1
    sta mkdir_write_struct+WRITE_VAL+2
    sta mkdir_write_struct+WRITE_VAL+3

    ldx #<mkdir_write_struct
    ldy #>mkdir_write_struct
    jsr write_internal

    lda #4
    jmp mkdir_add_addr

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
    cpx #32
    bne @memcpy
:
@free_a:
    lda #0
    jsr free
    lda #0
    rts    

unlink:
    rts