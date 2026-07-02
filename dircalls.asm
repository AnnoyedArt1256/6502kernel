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
    lda filesys_cluster
    sta (temp_ptr), y
    iny
    lda filesys_cluster+1
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

.if 0
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
.else
    ldx #<temp_ptr2
    jsr read_internal
    inc temp_ptr2
    bne :+
    inc temp_ptr2+1
:
    sta temp_ptr3
    ldx #<temp_ptr2
    jsr read_internal
    inc temp_ptr2
    bne :+
    inc temp_ptr2+1
:
    sta temp_ptr3+1

    inc temp_ptr2
    bne :+
    inc temp_ptr2+1
:
    ldx #<temp_ptr2
    jsr read_internal
    inc temp_ptr2
    bne :+
    inc temp_ptr2+1
:
.endif

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
    
    ldx #<temp_ptr3
    jsr read_internal
    and #DIR_FLAG
    beq :+
    ldy #DIRENT_FLAGS
    lda (temp_ptr), y
    ora #DIRENT_ISDIR
    sta (temp_ptr), y
:

    ldy #128
@name_loop:
    ldx #<temp_ptr2
    jsr read_internal
    inc temp_ptr2
    bne :+
    inc temp_ptr2+1
:
    sta (temp_ptr), y
    cmp #0
    beq @skip_name_loop
    iny
    cpy #128+48
    bne @name_loop
@skip_name_loop:
    lda #0
    sta (temp_ptr), y

    lda temp_ptr2
    and #$ff^$3f
    sta temp_ptr2

    ;lda temp_ptr2
    ;and #$3f
    ;bne :+
    jmp @next_clusters
@end_next_clusters:
;:

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
    sta temp_ptr2
    lda filesys_l
    adc fs_start_off+1
    iny
    sta (temp_ptr), y
    sta temp_ptr2+1
    jmp @end_next_clusters

.if 0
readdir_temp_vars:
    .byte 0, 0, 0, 0
    .byte 0, 0
.endif

readdir_temp_ptr:
    .word 0, 0, 0

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