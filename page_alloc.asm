; A = alloc length (in 256-byte pages)
; return:
;   A = page addr (hi-byte)
;   X = error code (0 = no error, 1 = ERROR)
;   Y = original alloc length
page_alloc_find_page:
    sta @cmp_page_add+1
    eor #$ff
    clc
    adc #1
    sta @cmp_x+1

    ldx #2
@loop_over_chunks:
    txa
    clc
@cmp_page_add:
    adc #0
    sta @cmp_page_size+1

    txa
    tay
    lda #0
@page_or:
    ora page_alloc_tbl, y
    iny
@cmp_page_size:
    cpy #0
    bne @page_or

    cmp #0
    beq @ret

    inx
@cmp_x:
    cpx #0
    bne @loop_over_chunks

@ret_fail:
    lda #$ff
    ldx #1
    ldy #0
    rts

@ret:
    txa
    ldx #0
    ldy @cmp_page_add+1
    rts


init_page_alloc:
    ; clear with all 0's
    ldx #0
    lda #0
:
    sta page_alloc_tbl, x
    sta page_end_tbl, x
    inx
    bne :-

    ; set reserved pages (for kernel and I/O)
    ldx #kernel_start>>8
    ldy #((kernel_end>>8)+1)&$ff
    jsr reserve_page_alloc
    ; for the first 512 bytes of memory (zp+stack)
    ldx #0
    ldy #2
    jsr reserve_page_alloc

    ; NOTE: C64-specific
    ; reserve I/O regions and page table/call tables (well no shit)
    ldx #$d0
    ldy #$e0
    jsr reserve_page_alloc
    ldx #page_end_tbl>>8
    ldy #((call_page>>8)+1)&$ff
    jsr reserve_page_alloc
    ; NOTE: also C64-specific
    ; reserve screen RAM and other misc.
    ldx #2
    ldy #8
    jsr reserve_page_alloc
    rts

; X = starting page
; Y = ending page
reserve_page_alloc:
    sty @cmp_end+1
    cpy #0
    beq :+
    cpx @cmp_end+1
    bcc :+
    rts
:
    lda #$ff
:
    sta page_alloc_tbl, x
    inx
@cmp_end:
    cpx #0
    bne :- 
    rts


; X = starting page
; Y = ending page
free_page_alloc:
    sty @cmp_end+1
    cpy #0
    beq :+
    cpx @cmp_end+1
    bcc :+
    rts
:
    lda #0
:
    sta page_alloc_tbl, x
    inx
@cmp_end:
    cpx #0
    bne :- 
    rts


; clears selected pages with all 0's
; X = starting page
; Y = ending page
memset_page:
    sty @cmp_end+1
    cpy #0
    beq :+
    cpx @cmp_end+1
    bcc :+
    rts
:
    stx @sta_ptr+2

    lda #0
:

    ldy #0
@sta_ptr:
    sta $0000, y
    iny
    bne @sta_ptr

    inc @sta_ptr+2
    inx
@cmp_end:
    cpx #0
    bne :- 
    rts

; X = lo size
; Y = hi size
; returns:
;  A, X = hi-byte of allocated memory
;  Y = if 0, no error, if 1, ERROR
malloc:
    cpx #0
    beq :+
    iny
:
    tya
    jsr page_alloc_find_page
    cpx #1
    beq @skip_fail ; has error, skip malloc

    tax
    sty @y_add+1
    clc
@y_add:
    adc #0
    sta page_end_tbl, x
    tay
    jsr_save reserve_page_alloc
    jsr_save memset_page

    txa
    ldy #0
    rts
@skip_fail:
    lda #0
    tax
    ldy #1
    rts

; A = starting page
; Y = amount of pages
malloc_range:
    tax
    sty @y_add+1
    clc
@y_add:
    adc #0
    sta page_end_tbl, x
    tay
    jsr_save reserve_page_alloc
    jsr_save memset_page

    txa
    ldy #0
    rts
@skip_fail:
    lda #0
    tax
    ldy #1
    rts

; A = hi-byte of allocated address (page)
free:
    tax
    lda page_end_tbl, x
    beq @ret_fail
    tay
    lda #0
    sta page_end_tbl, x
    jsr free_page_alloc
    rts
@ret_fail:
    ; TODO: add fault
    rts