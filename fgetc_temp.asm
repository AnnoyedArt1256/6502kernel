; for implementing an FS on disk/tape/serial/whatever
; i'll have to ditch the ramdisk and read from an external device
; to do that, i'll have to edit these routines:
; - fgetc
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

	ldy #0
	lda (temp_ptr3), y
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
    ; .word padding
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

	lda #0
	sta (temp_ptr), y 
	iny
	lda #0
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

f_start: .res 1
f_length: .res 2
f_name: .res 1

; *********************************************************************
; find file, searches the file system for the filename pointed to by
; the find name pointer. returns with Cb = 1 and the pointer to the
; file payload in filesys, if found.
;
; file name to search for should be "/[path[path]][name]" where path is
; the directory name followed by a "/". the path may be many deep and
; both the path and the name may be null. if the name is null then the
; default_file name will be searched for the path given.

LAB_find:
	lda #<(D_root+3)
	sta file_l
	lda #>(D_root+3)
	sta file_h

	LDA	D_root+$01			; get root file payload length low byte
	STA	lensys_l			; save payload length low byte
	LDA	D_root+$02			; get root file payload length high byte
	STA	lensys_h			; save payload length high byte

	LDA	#<BD_root			; get file system root body pointer low byte
	STA	filesys_l			; set file system pointer low byte
	LDA	#>BD_root			; get file system root body pointer high byte
	STA	filesys_h			; set file system pointer high byte
	LDY	#$00				; clear index
	LDA	(findname_l),Y		; get the first byte of the name to find
	CMP	#'/'				; compare with separator
	BNE	LAB_exit_n_found		; exit if not "/" at start

	JSR	LAB_directory		; search the root directory for the file
	BVC	LAB_exit_find		; exit if it's a file

	JSR	LAB_find_default		; if it's a directory go find the default file
LAB_exit_find:
	RTS


; flag file found and exit

LAB_exit_found:
	BIT	fileflags			; test the flags byte, set Vb for a directory
	SEC					; flag found
	RTS


; flag file not found and exit

LAB_exit_n_found:
	CLV					; flag not a directory
	CLC					; flag not found
	RTS


; increment filesys to the next file pointer in the directory

LAB_nextfile:
	CLC					; clear carry for add
	LDA	filesys_l			; get filesys low byte
	ADC	#$04				; increment to next pointer
	STA	filesys_l			; save filesys low byte
	BCC	ni_inc_h			; branch if no rollover

	INC	filesys_h			; else increment filesys high byte
ni_inc_h:

/*
	SEC					; set carry for subtract
	LDA	lensys_l			; get remaining length low byte
	SBC	#$04				; increment to next pointer
	STA	lensys_l			; save remaining length low byte
	BCS	LAB_comparefile		; branch if no rollunder

	DEC	lensys_h			; decerment remaining length high byte
*/

LAB_comparefile:
	;LDA	lensys_l			; get remaining directory length low byte
	;ORA	lensys_h			; OR remaining directory length high byte
	;BEQ	LAB_exit_n_found		; exit if no more directory entries

	LDY	#$00				; clear index
	LDA	(filesys_l),Y		; get file pointer low byte
	STA	file_l			; save this file pointer low byte
	INY					; increment index
	LDA	(filesys_l),Y		; get file pointer high byte
	STA	file_h			; save this file pointer high byte
	LDY #$03
	LDA (filesys_l),Y
	CMP #$80
	BCC LAB_skip_linked

	LDA file_l
	CMP #$ff
	BNE LAB_skip_link_finish
	CMP file_h
	BNE LAB_skip_link_finish
	JMP LAB_exit_n_found
LAB_skip_link_finish:
	LDA file_l
	STA filesys_l
	LDA file_h
	STA filesys_h
	jmp LAB_comparefile
LAB_skip_linked:
	LDY #$00					; clear index
	LDA	(file_l),Y			; get this file's flags
	STA	fileflags			; save the file's flag byte
	INY					; point to payload length low byte
	LDA	(file_l),Y			; get this file's payload length low byte
	STA	length_l			; save this file's payload length low byte
	INY					; point to payload length high byte
	LDA	(file_l),Y			; get this file's payload length high byte
	STA	length_h			; save this file's payload length high byte

	CLC					; clear carry for add
	LDA	file_l			; get this file pointer low byte
	ADC	#f_name-f_start		; add offset to the file name
	STA	file_l			; save this file pointer low byte
	BCC	nf_inc_h			; branch if no rollover

	INC	file_h			; else increment this file pointer high byte
nf_inc_h:
	LDY	#$FF				; set so first increment clears index

; compare this file's name, pointed to by file, with the find file
; name pointed to by findname. exits with Y indexed to the next byte
; in the name if the whole name matched.

LAB_comparename:
	INY					; increment index
	LDA	(file_l),Y			; get next byte of name to test
	BEQ	LAB_cnameexit		; exit if end of name (match)

	EOR	(findname_l),Y		; compare with next byte of name to find
	BEQ	LAB_comparename		; loop if character match

	BNE	LAB_nextfile		; branch if not this file

LAB_cnameexit:
	LDA	(findname_l),Y		; get next byte of name to find
	BEQ	LAB_end_find		; branch if end of name to find

	CMP	#'/'				; compare with separator
	BNE	LAB_nextfile		; branch if not end of name to find

LAB_end_find:
	PHA					; save next byte of name to find

						; name matched so update lensys
	LDA	length_l			; get length low byte
	STA	lensys_l			; save length low byte
	LDA	length_h			; get length high byte
	STA	lensys_h			; save length high byte

						; name matched so update filesys
	clc					; set carry for add +1, past $00
	LDA #64					; copy offset
	ADC	file_l			; add this file pointer low byte
	STA	filesys_l			; save as file system pointer low byte
	LDA	file_h			; get this file pointer high byte
	ADC	#$00				; add in the carry
	STA	filesys_h			; save as file system pointer high byte

	PLA					; restore next byte of name to find
	;BEQ	LAB_exit_found		; branch if end of name to find
	BNE :+
	JMP LAB_exit_found
:

	BIT	fileflags			; else test the flags byte
	; BVC	LAB_exit_n_found		; branch if not a directory
	BVS	:+
	JMP LAB_exit_n_found		; branch if not a directory
:

; searches the directory pointed to by the file system pointer for the
; filename pointed to by the find name pointer. the routine is entered
; with filesys pointing to the first directory byte after the file header
; and lensys holding the remaining directory size

LAB_directory:				; ok so far so update findname
	SEC					; set carry for add +1, past "/" or $00
	TYA					; copy offset
	LDY	#$00				; clear index
	ADC	findname_l			; add offset to findname low byte
	STA	findname_l			; save findname low byte
	TYA					; set $00 for add carry
	ADC	findname_h			; add findname high byte
	STA	findname_h			; save findname high byte

	LDA	(findname_l),Y		; get next byte of name to find
	; BNE	LAB_comparefile		; go compare file if not null filename
	BEQ	:+		; go compare file if not null filename
	JMP LAB_comparefile
:

LAB_find_default:				; else get default file for this directory
	;LDA	#<default_file		; get default filename pointer low byte
	;STA	findname_l			; set pointer of name to find low byte
	;LDA	#>default_file		; get default filename pointer high byte
	;STA	findname_h			; set pointer of name to find high byte
	;BNE	LAB_comparefile		; go compare file (branch always)
	bit dir_bit_wao
	sec
	rts

dir_bit_wao: .byte DIR_FLAG

fgetc_temp_ptr: .word 0, 0