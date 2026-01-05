f_start: .res 1
f_length: .res 2
f_name: .res 1
fs_start_off: .res 4

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
    lda #4
    sta file_l
    lda #0
    sta file_h
    ldx #<file_l
    jsr read_internal
    pha
    inc file_l
    ldx #<file_l
    jsr read_internal
    sta file_h
    sta fs_start_off+1
    pla
    sta file_l
    sta fs_start_off+0

	lda file_l
    clc
    adc #64
	sta filesys_l
	lda file_h
    adc #0
	sta filesys_h

    inc file_l
    bne :+
    inc file_h
:
    ; +1
    ldx #<file_l
	jsr read_internal			; get root file payload length low byte
	STA	lensys_l			; save payload length low byte
    inc file_l
    bne :+
    inc file_h
:
    ; +2
    ldx #<file_l
	jsr read_internal			; get root file payload length high byte
	STA	lensys_h			; save payload length high byte

    lda #1
    sta filesys_cluster
    sta file_cluster
    lda #0
    sta filesys_cluster+1
    sta file_cluster+1

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
    ; check for cluster boundary
    and #$3f
    bne :+
    ; ABCDEFGHIJKLMNOP
    ; GHIJKLMNOP000000
    lda filesys_cluster
    clc
    adc #8>>1
    sta filesys_l
    lda filesys_cluster+1
    adc #0
    sta filesys_h

    asl filesys_l
    rol filesys_h

    ldx #<filesys_l
    jsr read_internal
    sta filesys_cluster

    inc filesys_l

    ldx #<filesys_l
    jsr read_internal
    sta filesys_cluster+1
    sta filesys_h
    lda filesys_cluster
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
    sta filesys_l
    lda filesys_h
    adc fs_start_off+1
    sta filesys_h
:

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

    ldx #<filesys_l
    jsr read_internal
	STA	file_l			; save this file pointer low byte
    inc filesys_l
    bne :+
    inc filesys_h
: 
    ldx #<filesys_l
    jsr read_internal
	STA	file_h			; save this file pointer high byte

    lda filesys_l
    clc
    adc #2
    sta filesys_l
    bcc :+
    inc filesys_h
: 
    ldx #<filesys_l
    jsr read_internal
    tax

    lda filesys_l
    sec
    sbc #3
    sta filesys_l
    bcs :+
    inc filesys_h
: 

	cpx #$FF
	bne LAB_skip_end
	jmp LAB_exit_n_found
LAB_skip_end:
    ldx #<file_l
    jsr read_internal
	STA	fileflags			; save the file's flag byte
    inc file_l
    bne :+
    inc file_h
:
    ldx #<file_l
    jsr read_internal
	STA	length_l			; save this file's payload length low byte
    inc file_l
    bne :+
    inc file_h
:
    ldx #<file_l
    jsr read_internal
	STA	length_h			; save this file's payload length high byte

	CLC					; clear carry for add
	LDA	file_l			; get this file pointer low byte
	ADC	#(f_name-f_start)-2		; add offset to the file name
	STA	file_l			; save this file pointer low byte
	BCC	nf_inc_h			; branch if no rollover

	INC	file_h			; else increment this file pointer high byte
nf_inc_h:
    ldy #$ff

; compare this file's name, pointed to by file, with the find file
; name pointed to by findname. exits with Y indexed to the next byte
; in the name if the whole name matched.

LAB_comparename:
    iny
    ldx #<file_l
    jsr read_internal
    inc file_l
    bne :+
    inc file_h
:
    cmp #0
	BEQ	LAB_cnameexit		; exit if end of name (match)

	EOR	(findname_l),Y		; compare with next byte of name to find
	BEQ	LAB_comparename		; loop if character match

	;BNE	LAB_nextfile		; branch if not this file
    BEQ :+
    jmp LAB_nextfile
:

LAB_cnameexit:
	LDA	(findname_l),Y		; get next byte of name to find
	BEQ	LAB_end_find		; branch if end of name to find

	CMP	#'/'				; compare with separator
	;BNE	LAB_nextfile		; branch if not end of name to find
    BEQ :+
    jmp LAB_nextfile
:

LAB_end_find:
	PHA					; save next byte of name to find

						; name matched so update lensys
	LDA	length_l			; get length low byte
	STA	lensys_l			; save length low byte
	LDA	length_h			; get length high byte
	STA	lensys_h			; save length high byte

						; name matched so update filesys
	LDA file_l			
    and #$ff^$3f
    ora #1+2+48
	STA	file_l			; save as file system pointer low byte
    ldx #<file_l ; get cluster number
    jsr read_internal
    sta file_cluster+0
    inc file_l
    ldx #<file_l ; get cluster number
    jsr read_internal
    sta file_cluster+1
    sta file_h
    lda file_cluster+0
    sta file_l

    ; thanks llvm-mos :szok:
    lsr file_h
    ror file_l
    lda #0
    ror
    lsr file_h
    ror file_l
    ror
    sta file_h
    ; now file_l and file_h are swapped
    ; because llvm-mos did a fuck
    clc
    adc fs_start_off
    sta filesys_l
    lda file_l
    adc fs_start_off+1
    sta filesys_h

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
