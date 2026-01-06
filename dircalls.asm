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
    sta temp_ptr2
    lda filesys_l
    adc fs_start_off+1
    iny
    sta (temp_ptr), y
    sta temp_ptr2+1
    jmp @end_next_clusters

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
    lda temp_ptr3
    sta mkdir_temp_ptr+4
    lda temp_ptr3+1
    sta mkdir_temp_ptr+5

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

    lda file_cluster
    sta mkdir_cluster_temp2+0
    clc
    adc #8>>1 ; not this shit again
    sta mkdir_parent_cluster
    lda file_cluster+1
    sta mkdir_cluster_temp2+1
    adc #0
    sta mkdir_parent_cluster+1

    asl mkdir_parent_cluster
    rol mkdir_parent_cluster+1

    lda mkdir_parent_cluster
    sta temp_ptr3
    lda mkdir_parent_cluster+1
    sta temp_ptr3+1

    ldx #<temp_ptr3
    jsr read_internal
    sta mkdir_parent_cluster
    inc temp_ptr3
    ldx #<temp_ptr3
    jsr read_internal
    sta mkdir_parent_cluster+1

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

    ; create dir pointers
    jsr mkdir_find_cluster
    lda mkdir_cluster
    sta mkdir_cluster_temp
    lda mkdir_cluster+1
    sta mkdir_cluster_temp+1

    ; write $fffe for END MARKER
    lda mkdir_cluster_next 
    sta temp_ptr2
    lda mkdir_cluster_next+1
    sta temp_ptr2+1

    ldx #<temp_ptr2
    lda #$fe
    jsr write_internal
    inc temp_ptr2
    ldx #<temp_ptr2
    lda #$ff
    jsr write_internal
    
    ; populate dir pointers
    lda mkdir_cluster_addr 
    sta temp_ptr2
    lda mkdir_cluster_addr+1
    sta temp_ptr2+1

    ldy #3
:
    ldx #<temp_ptr2
    lda #$ff
    jsr write_internal
    inc temp_ptr2
    dey
    bpl :-
    ldy #(64-4)-1
:
    ldx #<temp_ptr2
    lda #0
    jsr write_internal
    inc temp_ptr2
    dey
    bpl :-

    ; create dir entry
    jsr mkdir_find_cluster

    ; now populate the dir
    lda mkdir_cluster_addr
    sta temp_ptr2
    sta mkdir_cluster_addr_dir
    lda mkdir_cluster_addr+1
    sta temp_ptr2+1
    sta mkdir_cluster_addr_dir+1
    ldx #<temp_ptr2
    lda #$40
    jsr write_internal
    inc temp_ptr2
    ldx #<temp_ptr2
    lda #0
    jsr write_internal
    inc temp_ptr2
    ldx #<temp_ptr2
    lda #0
    jsr write_internal
    inc temp_ptr2

    ; write dir name
    ldy #1
:
    tya
    clc
    adc mkdir_filename_offset
    tay

    lda (temp_ptr), y
    ldx #<temp_ptr2
    jsr write_internal  

    tya
    sec
    sbc mkdir_filename_offset
    tay

    inc temp_ptr2
    iny 
    cpy #48+1
    bne :-

    ; write dir pointer in FAT
    
    lda mkdir_cluster_next 
    sta temp_ptr2
    lda mkdir_cluster_next+1
    sta temp_ptr2+1

    ldx #<temp_ptr2
    lda mkdir_cluster_temp
    jsr write_internal
    inc temp_ptr2
    ldx #<temp_ptr2
    lda mkdir_cluster_temp+1
    jsr write_internal

    ; more code MORE!!1! :sob:
    lda mkdir_cluster_addr_dir
    ora #48+3
    sta temp_ptr2
    lda mkdir_cluster_addr_dir+1
    sta temp_ptr2+1

    ldx #<temp_ptr2
    lda mkdir_cluster_temp
    jsr write_internal
    inc temp_ptr2
    ldx #<temp_ptr2
    lda mkdir_cluster_temp+1
    jsr write_internal

    ; first the dir pointer
    lda #0
    sta temp_ptr2
    lda @free_a3+1
    sta temp_ptr2+1
    
    ldy #DIRENT_PTR
    lda (temp_ptr2), y
    sta temp_ptr3
    iny
    lda (temp_ptr2), y
    sta temp_ptr3+1

    ldx #<temp_ptr3
    lda mkdir_cluster_addr
    sta mkdir_cluster_addr_dir
    jsr write_internal
    inc temp_ptr3
    ldx #<temp_ptr3
    lda mkdir_cluster_addr+1
    sta mkdir_cluster_addr_dir+1
    jsr write_internal  
    ldx #<temp_ptr3
    inc temp_ptr3
    lda mkdir_cluster_addr+2
    sta mkdir_cluster_addr_dir+2
    jsr write_internal  
    ldx #<temp_ptr3
    inc temp_ptr3
    lda mkdir_cluster_addr+3
    sta mkdir_cluster_addr_dir+3
    jsr write_internal  
    inc temp_ptr3

    ; go to next cluster if needed
    lda temp_ptr3
    and #$3f
    bne :+
    jsr mkdir_find_cluster

    lda mkdir_cluster_temp2
    clc
    adc #8>>1
    sta mkdir_parent_addr
    lda mkdir_cluster_temp2+1
    adc #0
    sta mkdir_parent_addr+1

    asl mkdir_parent_addr
    rol mkdir_parent_addr+1   

    lda mkdir_parent_addr
    sta temp_ptr3
    lda mkdir_parent_addr+1
    sta temp_ptr3+1

    ldx #<temp_ptr3
    lda mkdir_cluster
    jsr write_internal
    inc temp_ptr3
    ldx #<temp_ptr3
    lda mkdir_cluster+1
    jsr write_internal

    lda mkdir_cluster_next
    sta temp_ptr3
    lda mkdir_cluster_next+1
    sta temp_ptr3+1

    ldx #<temp_ptr3
    lda #$fe
    jsr write_internal
    inc temp_ptr3
    ldx #<temp_ptr3
    lda #$ff
    jsr write_internal

    lda @free_a3+1
    sta temp_ptr2+1
    lda #0
    sta temp_ptr2

    ldy #DIRENT_PTR
    lda mkdir_cluster_addr
    sta (temp_ptr2), y
    iny
    lda mkdir_cluster_addr+1
    sta (temp_ptr2), y
:

    ; now add $ffffffff (end marker)
    ldy #DIRENT_FLAGS
    lda (temp_ptr2), y
    and #$ff^DIRENT_DONE
    sta (temp_ptr2), y

    ldx #0
    ldy @free_a3+1
    jsr readdir

    ldy #DIRENT_PTR
    lda (temp_ptr2), y
    sta temp_ptr3
    iny
    lda (temp_ptr2), y
    sta temp_ptr3+1

    .repeat 4
        ldx #<temp_ptr3
        lda #$ff
        jsr write_internal
        inc temp_ptr3
    .endrepeat

    lda temp_ptr2+1
    jsr free

@free_a3:
    lda #0
    jsr free

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
    lda mkdir_temp_ptr+4
    sta temp_ptr3+0
    lda mkdir_temp_ptr+5
    sta temp_ptr3+1
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
    lda mkdir_temp_ptr+4
    sta temp_ptr3+0
    lda mkdir_temp_ptr+5
    sta temp_ptr3+1
    lda #1
    plp
    rts

mkdir_temp_ptr: .word 0, 0
mkdir_filename_offset: .byte 0
mkdir_cluster: .word 0
mkdir_cluster_temp: .word 0
mkdir_cluster_temp2: .word 0
mkdir_cluster_next: .word 0
mkdir_cluster_addr: .dword 0
mkdir_cluster_addr_dir: .dword 0
mkdir_parent_cluster: .word 0
mkdir_parent_addr: .dword 0

mkdir_find_cluster:
    lda temp_ptr
    sta @temp_ptr
    lda temp_ptr+1
    sta @temp_ptr+1

    jsr get_fs_header
    stx temp_ptr2
    sty temp_ptr2+1

    ldy #0 ; cluster amt
    lda (temp_ptr2), y
    sta temp_ptr
    lda (temp_ptr2), y
    sta temp_ptr+1
    
    ; TODO: 32-bit addrs
    lda #8
    sta temp_ptr3
    lda #0
    sta temp_ptr3+1

@check_cluster_loop:
    ldx #<temp_ptr3
    jsr read_internal
    sta mkdir_cluster

    inc temp_ptr3+0
    bne :+
    inc temp_ptr3+1
:

    ldx #<temp_ptr3
    jsr read_internal
    sta mkdir_cluster+1

    inc temp_ptr3+0
    bne :+
    inc temp_ptr3+1
:

    cmp #$ff
    bne :+
    cmp mkdir_cluster
    beq @success
:

    lda temp_ptr
    bne :+
    dec temp_ptr+1
:
    dec temp_ptr

    lda temp_ptr
    ora temp_ptr+1
    bne @check_cluster_loop
    ; FAIL return
    lda #0
    sta mkdir_cluster
    sta mkdir_cluster+1
    lda @temp_ptr
    sta temp_ptr
    lda @temp_ptr+1
    sta temp_ptr+1
    rts

@success:
    lda temp_ptr3
    sec
    sbc #2
    sta mkdir_cluster_next
    lda temp_ptr3+1
    sbc #0
    sta mkdir_cluster_next+1
    
    lsr temp_ptr3+1
    ror temp_ptr3
    lda temp_ptr3
    sec
    sbc #(8>>1)+1
    sta mkdir_cluster
    bcs :+
    dec temp_ptr3+1
:
    lda temp_ptr3+1
    sta mkdir_cluster+1

    ; TODO: 32-bit
    lda mkdir_cluster
    sta mkdir_cluster_addr
    lda mkdir_cluster+1
    sta mkdir_cluster_addr+1

    lsr mkdir_cluster_addr+1
    ror mkdir_cluster_addr
    lda #0
    ror
    lsr mkdir_cluster_addr+1
    ror mkdir_cluster_addr
    ror
    clc
    adc fs_start_off
    tax
    lda mkdir_cluster_addr
    adc fs_start_off+1
    sta mkdir_cluster_addr+1
    stx mkdir_cluster_addr

    lda @temp_ptr
    sta temp_ptr
    lda @temp_ptr+1
    sta temp_ptr+1
    rts

@temp_ptr: .word 0

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