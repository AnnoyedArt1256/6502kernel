; for implementing an FS on disk/tape/serial/whatever
; i'll have to ditch the ramdisk and read from an external device
; to do that, i'll have to edit these routines:
; - fgetc
; - fopen?
; - get_fs_header
; - write_internal
; - the LAB_xxxxx functions
; in order to read from I/O instead of memory!!!

; XY = returns ptr to fs header
; NOTE: MAKE SURE TO FREE AFTER USING IT!!!!
get_fs_header:
    lda temp_ptr2
    sta @temp_ptr
    lda temp_ptr2+1
    sta @temp_ptr+1

	ldx #0
	ldy #1
	jsr malloc
	sta temp_ptr2+1
	lda #0
	sta temp_ptr2

	; todo: make this more portable
	ldy #7
:
	lda FS_header, y
	sta (temp_ptr2), y
	dey
	bpl :-

	ldx temp_ptr2
	ldy temp_ptr2+1

	lda @temp_ptr
	sta temp_ptr2
	lda @temp_ptr+1
	sta temp_ptr2+1
	lda #0
	rts

@temp_ptr: .word 0

; X = zp ptr
read_internal:
	lda z:$00, x
	clc
	adc #<FS_header
	sta @temp_read+1
	lda z:$01, x
	adc #>FS_header
	sta @temp_read+2
@temp_read:
	lda $1000
	rts

write_internal:
    lda temp_ptr2
    sta @temp_ptr
    lda temp_ptr2+1
    sta @temp_ptr+1
    lda temp_ptr
    sta @temp_ptr+2
    lda temp_ptr+1
    sta @temp_ptr+3

	stx temp_ptr2
	sty temp_ptr2+1
	ldy #0
	lda (temp_ptr2), y
	sta temp_ptr3
	iny
	lda (temp_ptr2), y
	sta temp_ptr3+1

	; TODO: implement buffer flag

	lda temp_ptr3
	sec
	sbc #4
	sta temp_ptr3
	lda temp_ptr3+1
	sbc #0
	sta temp_ptr3+1

	ldy #8
	lda (temp_ptr2), y
	beq @skip_write
	clc
	adc #4
	sta @temp_ptr+4

	ldy #4
@do_write:
	lda (temp_ptr2), y
	sta (temp_ptr3), y
	iny
	cpy @temp_ptr+4
	bne @do_write

@skip_write:


	lda @temp_ptr
	sta temp_ptr2
	lda @temp_ptr+1
	sta temp_ptr2+1
	lda @temp_ptr+2
	sta temp_ptr
	lda @temp_ptr+3
	sta temp_ptr+1
	lda #0
	rts
@temp_ptr: .word 0, 0, 0

; YX = file handler
fgetc:
    lda temp_ptr2
    sta fgetc_temp_ptr
    lda temp_ptr2+1
    sta fgetc_temp_ptr+1
    lda temp_ptr3
    sta fgetc_temp_ptr+2
    lda temp_ptr3+1
    sta fgetc_temp_ptr+3

	lda #0
	sta @final_byte+1

	stx temp_ptr2
	sty temp_ptr2+1

    ldy #0
    lda (temp_ptr2), y
	iny
    ora (temp_ptr2), y
	beq @skip_ret


	; no DEC (indirect),y?
    dey ; ldy #0
    lda (temp_ptr2), y
	sec
	sbc #1
	sta (temp_ptr2), y
	iny
    lda (temp_ptr2), y
	sbc #0
	sta (temp_ptr2), y
	iny

	lda (temp_ptr2), y
	sta temp_ptr3
	clc
	adc #1
	sta (temp_ptr2), y
	iny
	lda (temp_ptr2), y
	sta temp_ptr3+1
	adc #0
	sta (temp_ptr2), y
	
	ldy #6
	lda (temp_ptr2), y
	clc
	adc #1
	sta (temp_ptr2), y
	iny
	lda (temp_ptr2), y
	adc #0
	sta (temp_ptr2), y

	ldx #<temp_ptr3
	jsr read_internal
	sta @final_byte+1

@skip_ret:

    lda fgetc_temp_ptr
    sta temp_ptr2
    lda fgetc_temp_ptr+1
    sta temp_ptr2+1  
    lda fgetc_temp_ptr+2
    sta temp_ptr3
    lda fgetc_temp_ptr+3
    sta temp_ptr3+1

@final_byte:
    lda #0
    rts

; XY = file handler
; returns: XY = file seek_pos
ftell:
    lda temp_ptr2
    sta fgetc_temp_ptr
    lda temp_ptr2+1
    sta fgetc_temp_ptr+1

	stx temp_ptr2
	sty temp_ptr2+1

    ldy #6
    lda (temp_ptr2), y
	tax
	iny
    lda (temp_ptr2), y
	tay

    lda fgetc_temp_ptr
    sta temp_ptr2
    lda fgetc_temp_ptr+1
    sta temp_ptr2+1  
    rts

; XY = file handler
; returns: A = $ff if eof, otherwise 0
iseof:
    lda temp_ptr2
    sta fgetc_temp_ptr
    lda temp_ptr2+1
    sta fgetc_temp_ptr+1

	stx temp_ptr2
	sty temp_ptr2+1

    ldy #0
    lda (temp_ptr2), y
	iny
    ora (temp_ptr2), y
	beq @ret_eof

    lda fgetc_temp_ptr
    sta temp_ptr2
    lda fgetc_temp_ptr+1
    sta temp_ptr2+1 
	lda #0 
    rts

@ret_eof:
    lda fgetc_temp_ptr
    sta temp_ptr2
    lda fgetc_temp_ptr+1
    sta temp_ptr2+1  
	lda #$ff
    rts
	
; combine directory
; XY = directory to add on top of current dir
; returns:
;  A = new diretory hi-addr (MAKE SURE TO USE FREE, SINCE THIS USES MALLOC)
combdir:
    stx findname_l
    sty findname_h

	ldy #0
	lda (findname_l), y
	cmp #'/'
	bne :+
	jmp @skip_to_find ; it's an absolute directory
:

    ldx #0
    ldy #1
    jsr malloc
	sta @dir_base_dst+2
	sta @name_base_dst+2
	sta @dir_base_check+2
	sta @dir_base_check2+2

	jsr get_curdir
	stx @dir_base_copy+1
	sty @dir_base_copy+2

	ldx #0
@dir_base_copy:
	lda $1000, x
	beq :+
@dir_base_dst:
	sta $1000, x
	inx
	bne @dir_base_copy
:

	dex
@dir_base_check:
	lda $1000, x
	inx
	cmp #'/'
	beq :+
	lda #'/'
@dir_base_check2:
	sta $1000, x
	beq :+
	inx
	lda #0
	beq @dir_base_check2	
:

	ldy #0
@name_base_copy:
	lda (findname_l), y
	cmp #'.'
	bne @skip_period
	cpy #0
	beq :+
	dey
	lda (findname_l), y
	iny
	cmp #'/' 
	bne @skip_period_load_dot
:

	iny
	lda (findname_l), y
	dey
	cmp #'.'
	bne :+
	lda @dir_base_dst+2
	jsr combdir_double_dot
	jmp @name_base_copy
:
	dex
	dex
@skip_period_load_dot:
	lda #'.'
@skip_period:

	cmp #0
	beq :+
@name_base_dst:
	sta $1000, x
	iny
	inx
	bne @name_base_copy
:

	jsr_save @check_if_dir
	lda @is_it_dir
	beq @skip_slash_add

	; this shit looks messy i know, but here's what this code does:
	;	1. checks if the last character of the dir string is "/"
	;   2. if it is, skip to the end
	;   3. otherwise, append a "/" character at the end
	;      and add a null-terminator ($00)
	dex
	lda @name_base_dst+2
	sta 2+:+
	sta 2+:++
	sta 2+:+++
:
	lda $1000, x
	cmp #'/'
	beq @skip_slash_add
	inx
	lda #'/'
:
	sta $1000, x
	inx
	lda #0
:
	sta $1000, x
@skip_slash_add:

	lda #0
	sta findname_l
	lda @dir_base_dst+2
	sta findname_h
	rts

@skip_to_find:
    ldx #0
    ldy #1
    jsr malloc
	sta @dir_skip_find_dst+2

	ldy #0
@dir_skip_find_copy:
	lda (findname_l), y
	cmp #'.'
	bne @skip_period2
	iny
	lda (findname_l), y
	dey
	cmp #'.'
	bne :+
	lda @dir_skip_find_dst+2
	jsr combdir_double_dot
	jmp @dir_skip_find_copy
:
	dex
	dex
	lda #'.'
@skip_period2:

	cmp #0
	beq :+
@dir_skip_find_dst:
	sta $1000, y
	iny
	bne @dir_skip_find_copy
:

	lda #0
	sta findname_l
	lda @dir_skip_find_dst+2
	sta findname_h
	rts


@check_if_dir:
	ldx #0
	stx @is_it_dir
	ldy @name_base_dst+2
	jsr LAB_find
	bvc :+ ; fail if it's a DIRECTORY
	inc @is_it_dir
:
	rts
@is_it_dir: .byte 0


combdir_double_dot:
	sty @y_load+1
	sta @dot_addr_smc+2
	sta @dot_addr_smc_zerow+2+2
	ldx #0
@check_str:
	jsr @dot_addr_smc
	beq :+
	inx
	bne @check_str
:

	dex
	jsr @dot_addr_smc
	cmp #'/' ; check for trailing /
	bne :+
	dex
	jsr @dot_addr_smc_zerow
:

@check_slash:
	jsr @dot_addr_smc
	cmp #'/'
	beq :+
	jsr @dot_addr_smc_zerow
	dex
	cpx #0
	bne @check_slash
:

@y_load:
	ldy #0
	iny
	iny
	rts

@dot_addr_smc:
	lda $1000, x
	rts
@dot_addr_smc_zerow: ; writes zero to a byte in the string buffer
	lda #0
	sta $1000, x
	rts

; YX = filename string addr
; returns:
;  A = 0 if valid, 1 if INVALID
;  X = hi-byte addr for the FILE HANDLER
fopen:
	jsr combdir
	sta @hipage+1
	tay
	ldx #0
    jsr LAB_find
	php
@hipage:
	lda #0
	jsr free
	plp
	bcc @ret_fail ; fail if file does not exist
	bvs @ret_fail_dir ; fail if it's a DIRECTORY

    ; .word len
    ; .word ptr
    ; .word start_ptr
    ; .word current_cluster
    ldx #8
    ldy #0
    jsr malloc

    lda temp_ptr
    sta @temp_ptr
    lda temp_ptr+1
    sta @temp_ptr+1

    stx temp_ptr+1
    lda #0
    sta temp_ptr

    ; store file length
    lda lensys_l
    ldy #0
    sta (temp_ptr), y
    lda lensys_h
    ldy #1
    sta (temp_ptr), y

/*
    ldy #0
@str_loop:
    lda (filesys_l), y
    beq @str_loop_end
    iny
    bne @str_loop
    jmp @ret_skip
@str_loop_end:
    iny
    tya
    clc
    adc filesys_l
    sta filesys_l
    lda filesys_h
    adc #0
    sta filesys_h
*/

    ldy #2

    .repeat 2
        lda filesys_l
        sta (temp_ptr), y    
        iny
        lda filesys_h
        sta (temp_ptr), y 
        iny 
    .endrepeat

	lda file_cluster
	sta (temp_ptr), y 
	iny
	lda file_cluster+1
	sta (temp_ptr), y 
	iny

@ret_skip:
    lda @temp_ptr
    sta temp_ptr
    lda @temp_ptr+1
    sta temp_ptr+1
	lda #0
    rts
@ret_fail:
    lda @temp_ptr
    sta temp_ptr
    lda @temp_ptr+1
    sta temp_ptr+1
	lda #1
    rts
@ret_fail_dir:
    lda @temp_ptr
    sta temp_ptr
    lda @temp_ptr+1
    sta temp_ptr+1
	lda #2
    rts
@temp_ptr:
    .word 0

; Y = page (hi-byte) address of file descriptor
fclose:
	tya
	jmp free
	;rts

.include "fs.asm"

fgetc_temp_ptr: .word 0, 0