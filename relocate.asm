
exec_addr: .word $8000
exec_handler: .word 0

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

.macro load_segment seg_off_custom
    lda #0
    sta page_len

    do_fgetc exec_handler
    sta seg_off
    sta seg_off_custom
    do_fgetc exec_handler
    sta seg_off+1
    sta seg_off_custom+1
    cmp #$ff
    bne :+
    cmp seg_off
    bne :+
    jmp @skip_load_exec
:

    do_fgetc exec_handler
    sta seg_len
    do_fgetc exec_handler
    sta seg_len+1
    bne :+
    cmp seg_len
    beq :++
:

    jsr write_prg
    cpx #1
    bne :+
    jmp @skip_load_exec
:
.endmacro

load_exec:
    stx exec_handler
    sty exec_handler+1

    lda temp_ptr
    sta temp_ptr_temp_exec
    lda temp_ptr+1
    sta temp_ptr_temp_exec+1

    lda #0
    sta exec_addr
    sta exec_addr+1

    load_segment seg_off_text
    lda exec_addr+1
    sta start_page_text
    clc
    adc page_len
    sta end_page_text

    load_segment seg_off_data
    lda exec_addr+1
    sta start_page_data
    clc
    adc page_len
    sta end_page_data

    lda #0
    sec
    sbc seg_off_text
    sta seg_diff_text
    lda start_page_text
    sbc seg_off_text+1
    sta seg_diff_text+1

    lda #0
    sec
    sbc seg_off_data
    sta seg_diff_data
    lda start_page_data
    sbc seg_off_data+1
    sta seg_diff_data+1

    lda #0
    sta seg_real_start
    lda start_page_text
    sta seg_real_start+1

    jsr read_reloc
    cpx #1
    beq @skip_load_exec
    
    lda #0
    sta seg_real_start
    lda start_page_data
    sta seg_real_start+1

    jsr read_reloc
    cpx #1
    beq @skip_load_exec

    ldy start_page_data
    ldx #0
    jsr add_process_exec

    tya
    pha
    ldy exec_handler+1
    jsr_save fclose
    pla
    tay

    lda temp_ptr_temp_exec
    sta temp_ptr
    lda temp_ptr_temp_exec+1
    sta temp_ptr+1

    lda start_page_data
    ldx #0
    rts

@skip_load_exec:
    ldy exec_handler+1
    jsr_save fclose

    lda temp_ptr_temp_exec
    sta temp_ptr
    lda temp_ptr_temp_exec+1
    sta temp_ptr+1

    ldx #1
    rts

read_reloc:

@read_loop:
    do_fgetc exec_handler
    sta cur_reloc_table
    do_fgetc exec_handler
    sta cur_reloc_table+1
    cmp #$ff
    bne :+
    cmp cur_reloc_table
    beq @ret
:
    do_fgetc exec_handler
    sta cur_reloc_table+2 ; type-byte
    do_fgetc exec_handler
    sta cur_reloc_table+4 ; seg-id
    do_fgetc exec_handler
    sta cur_reloc_table+3 ; data-val

    lda cur_reloc_table
    clc
    adc seg_real_start
    sta temp_ptr
    lda cur_reloc_table+1
    adc seg_real_start+1
    sta temp_ptr+1

    lda cur_reloc_table+2 ; type-byte
    cmp #$40 ; high-byte
    bne :+
    jsr @high_byte
    jmp @read_loop
:
    cmp #$80 ; 2-byte WORD address
    bne :+
    jsr @word_addr
    jmp @read_loop
:
    cmp #$20 ; low-byte
    bne :+
    jsr @low_byte
    jmp @read_loop
:
    jmp @read_loop

@ret:
    ldx #0
    rts
@ret_fail:
    ldx #1
    rts

@low_byte:
    lda cur_reloc_table+4 ; seg-id
    cmp #2
    bne :+
    ; text segment
    ldy #0
    lda (temp_ptr), y
    clc
    adc seg_diff_text
    sta (temp_ptr), y
    rts
:
    cmp #3
    bne :+
    ; data segment
    ldy #0
    lda (temp_ptr), y
    clc
    adc seg_diff_data
    sta (temp_ptr), y
    rts
:
    rts

@high_byte:
    lda cur_reloc_table+4 ; seg-id
    cmp #2
    bne :+
    ; text segment
    ldy #0
    lda cur_reloc_table+3
    clc
    adc seg_diff_text
    lda (temp_ptr), y
    adc seg_diff_text+1
    sta (temp_ptr), y
    rts
:
    cmp #3
    bne :+
    ; data segment
    ldy #0
    lda cur_reloc_table+3
    clc
    adc seg_diff_data
    lda (temp_ptr), y
    adc seg_diff_data+1
    sta (temp_ptr), y
    rts
:
    rts

@word_addr:
    lda cur_reloc_table+4 ; seg-id
    cmp #2
    bne :+
    ; text segment
    ldy #0
    lda (temp_ptr), y
    clc
    adc seg_diff_text
    sta (temp_ptr), y
    iny
    lda (temp_ptr), y
    adc seg_diff_text+1
    sta (temp_ptr), y
    rts
:
    cmp #3
    bne :+
    ; data segment
    ldy #0
    lda (temp_ptr), y
    clc
    adc seg_diff_data
    sta (temp_ptr), y
    iny
    lda (temp_ptr), y
    adc seg_diff_data+1
    sta (temp_ptr), y
    rts
:
    rts

cur_reloc_table: .res 5, 0
seg_off_text: .word 0
seg_off_data: .word 0
seg_diff_text: .word 0
seg_diff_data: .word 0
seg_real_start: .word 0
start_page_text: .byte 0
end_page_text: .byte 0
start_page_data: .byte 0
end_page_data: .byte 0
upload_ptr_temp: .word 0
temp_ptr_temp_exec: .word 0
seg_off: .word 0
seg_len: .word 0
page_len: .byte 0

write_prg:
    ldx seg_len
    beq :+
    clc
    adc #1
:
    sta page_len
    bne :+
    ldx #0
    rts
:

    jsr page_alloc_find_page
    cpx #1
    beq @skip_ret ; has error, skip file load

    sta exec_addr+1
    sta temp_ptr+1
    sty @y_add+1
    tax
    clc
@y_add:
    adc #0
    tay
    jsr_save reserve_page_alloc
    jsr memset_page
    
    ;lda temp_ptr3+0
    ;sta upload_ptr_temp+0
    ;lda temp_ptr3+1
    ;sta upload_ptr_temp+1

    lda #0
    sta exec_addr+0
    sta temp_ptr

@upload_loop:
    do_fgetc exec_handler
    ldy #0
    sta (temp_ptr), y

    inc temp_ptr
    bne :+
    inc temp_ptr+1
:

    lda seg_len+0
    bne :+
    dec seg_len+1
:
    dec seg_len+0

    lda seg_len+0
    ora seg_len+1
    bne @upload_loop

    ;lda upload_ptr_temp+0
    ;sta temp_ptr3+0
    ;lda upload_ptr_temp+1
    ;sta temp_ptr3+1

    ldx #0
@skip_ret:
    rts

.proc add_process_exec
    lda temp_ptr
    sta temp_ptr_temp
    lda temp_ptr+1
    sta temp_ptr_temp+1

    stx temp_ptr
    sty temp_ptr+1

    jsr get_free_process
    cmp #$ff
    beq @skip_add_process2
    tay
    tax
    sta processes_a, x
    lda #$ff
    sta processes_exist, x
    lda #0
    sta processes_x, x
    sta processes_y, x
    sta processes_f, x
    sta processes_fork, x
    txa
    asl
    asl
    asl
    asl
    clc
    adc #16-1
    sta processes_sp, x

    lda start_page_text
    sta processes_memstart_TEXT, x
    lda end_page_text
    sta processes_memend_TEXT, x
    lda start_page_data
    sta processes_memstart_DATA, x
    lda end_page_data
    sta processes_memend_DATA, x

    txa
    asl
    tax
    lda temp_ptr
    sta processes_pc, x
    lda temp_ptr+1
    sta processes_pc+1, x

@skip_add_process:
    lda temp_ptr_temp
    sta temp_ptr
    lda temp_ptr_temp+1
    sta temp_ptr+1
    rts

@skip_add_process2:
    ldy #0
    lda temp_ptr_temp
    sta temp_ptr
    lda temp_ptr_temp+1
    sta temp_ptr+1
    rts

get_free_process:
    ldx #0
:
    lda processes_exist, x
    beq :+
    inx
    cpx #16
    bne :-
    lda #$ff
    rts
:
    txa
    rts
.endproc

.delmacro do_fgetc