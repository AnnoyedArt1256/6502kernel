clearscr:
    lda putc_ptr
    cmp putc_out_ptr
    bne clearscr

    lda #$20
    ldx #0
:
    .repeat 4, I
        sta $400+I*250, x
    .endrepeat
    inx 
    cpx #250
    bne :-
    lda #0
    sta putc_x
    sta putc_y
    rts

; A = character
putc:
    ldx putc_ptr
    sta putc_buffer, x
    inc putc_ptr
    rts

; the current backspace implementation is kinda shitty, but mehhh who cares
putc_backspace:
    lda putc_y
    bne :+
    cmp putc_x
    beq @skip
:

    dec putc_x
    lda putc_x
    cmp #$ff
    bne @do_backspace
    lda #39
    sta putc_x
    lda putc_y
    beq @skip
    dec putc_y

@do_backspace:
    ldy putc_y
    lda putc_y_poses, y
    sta @putc_store+1
    lda putc_y_poses+25, y
    sta @putc_store+2
    ldx #$20
    lda tab_petscii2screencode, x
    ldx putc_x
@putc_store:
    sta $400, x
@skip:
    rts

putc_indicator:
    ldy putc_y
    lda putc_y_poses, y
    sta @putc_store+1
    sta @putc_load+1
    lda putc_y_poses+25, y
    sta @putc_store+2
    sta @putc_load+2
    lda tab_petscii2screencode, x
    ldx putc_x
@putc_load:
    lda $400, x
    eor #$80
@putc_store:
    sta $400, x
    rts

; A = character
putc_no_buf:
    ;sta @a_load+1
    ;stx @x_load+1
    ;sty @y_load+1

    tax

    cpx #$0a
    beq @do_newline

    cpx #$08
    beq putc_backspace

    cpx #$20
    bcc @a_load

    ldy putc_y
    lda putc_y_poses, y
    sta @putc_store+1
    lda putc_y_poses+25, y
    sta @putc_store+2
    lda tab_petscii2screencode, x
    ldx putc_x
@putc_store:
    sta $400, x

    inc putc_x
    lda putc_x
    cmp #40
    bne @skip_hwrapping
@do_newline:
    lda #0
    sta putc_x

    inc putc_y
    lda putc_y
    cmp #25
    bne @skip_newline
    dec putc_y

    lda temp_ptr
    sta temp_ptr_temp
    lda temp_ptr+1
    sta temp_ptr_temp+1

    ldy #0
@loop_rows:
    lda putc_y_poses+1, y
    sta @putc_shift1+1
    lda putc_y_poses+25+1, y
    sta @putc_shift1+2
    lda putc_y_poses, y
    sta @putc_shift2+1
    lda putc_y_poses+25, y
    sta @putc_shift2+2
    ldx #39
@loop_cols:
@putc_shift1:
    lda $400, x
@putc_shift2:
    sta $400, x
    dex
    bpl @loop_cols

    iny
    cpy #25-1
    bne @loop_rows

    lda temp_ptr_temp
    sta temp_ptr
    lda temp_ptr_temp+1
    sta temp_ptr+1

    ldx #39
    lda #$20
@loop_cols_empty:
    sta $400+(24*40), x
    dex
    bpl @loop_cols_empty

@skip_newline:

@skip_hwrapping:


@a_load:
;    lda #0
;@x_load:
;    ldx #0
;@y_load:
;    ldy #0
    rts

temp_ptr_temp: .word 0
putc_x: .byte 0
putc_y: .byte 0
putc_y_poses:
    .repeat 25, I
        .lobytes $400+(I*40)
    .endrepeat
    .repeat 25, I
        .hibytes $400+(I*40)
    .endrepeat

align 256

tab_petscii2screencode:
/*                        
                                                                              ; PETSCII RANGE
    .byte $80,$81,$82,$83,$84,$85,$86,$87, $88,$89,$8a,$8b,$8c,$8d,$8e,$8f    ;$00-...
    .byte $90,$91,$92,$93,$94,$95,$96,$97, $98,$99,$9a,$9b,$9c,$9d,$9e,$9f    ;...-$1f
    .byte $20,$21,$22,$23,$24,$25,$26,$27, $28,$29,$2a,$2b,$2c,$2d,$2e,$2f    ;$20-...
    .byte $30,$31,$32,$33,$34,$35,$36,$37, $38,$39,$3a,$3b,$3c,$3d,$3e,$3f    ;...-$3f
    .byte $00,$01,$02,$03,$04,$05,$06,$07, $08,$09,$0a,$0b,$0c,$0d,$0e,$0f    ;$40-...
    .byte $10,$11,$12,$13,$14,$15,$16,$17, $18,$19,$1a,$1b,$1c,$1d,$1e,$1f    ;...-$5f
    .byte $40,$41,$42,$43,$44,$45,$46,$47, $48,$49,$4a,$4b,$4c,$4d,$4e,$4f    ;$60-...
    .byte $50,$51,$52,$53,$54,$55,$56,$57, $58,$59,$5a,$5b,$5c,$5d,$5e,$5f    ;...-$7f
    .byte $c0,$c1,$c2,$c3,$c4,$c5,$c6,$c7, $c8,$c9,$ca,$cb,$cc,$cd,$ce,$cf    ;$80-...
    .byte $d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7, $d8,$d9,$da,$db,$dc,$dd,$de,$df    ;...-$9f
    .byte $60,$61,$62,$63,$64,$65,$66,$67, $68,$69,$6a,$6b,$6c,$6d,$6e,$6f    ;$a0-...
    .byte $70,$71,$72,$73,$74,$75,$76,$77, $78,$79,$7a,$7b,$7c,$7d,$7e,$7f    ;...-$bf
    .byte $00,$01,$02,$03,$04,$05,$06,$07, $08,$09,$0a,$0b,$0c,$0d,$0e,$0f    ;$c0-...
    .byte $10,$11,$12,$13,$14,$15,$16,$17, $18,$19,$1a,$1b,$1c,$1d,$1e,$1f    ;...-$df
    .byte $60,$61,$62,$63,$64,$65,$66,$67, $68,$69,$6a,$6b,$6c,$6d,$6e,$6f    ;$e0-...
    .byte $70,$71,$72,$73,$74,$75,$76,$77, $78,$79,$7a,$7b,$7c,$7d,$7e,$5e    ;...-$ff
*/
                                                                              ; PETSCII RANGE
    .byte $80,$81,$82,$83,$84,$85,$86,$87, $88,$89,$8a,$8b,$8c,$8d,$8e,$8f    ;$00-...
    .byte $90,$91,$92,$93,$94,$95,$96,$97, $98,$99,$9a,$9b,$9c,$9d,$9e,$9f    ;...-$1f
    .byte $20,$21,$22,$23,$24,$25,$26,$27, $28,$29,$2a,$2b,$2c,$2d,$2e,$2f    ;$20-...
    .byte $30,$31,$32,$33,$34,$35,$36,$37, $38,$39,$3a,$3b,$3c,$3d,$3e,$3f    ;...-$3f

    .byte $00,$41,$42,$43,$44,$45,$46,$47, $48,$49,$4a,$4b,$4c,$4d,$4e,$4f    ;$40-...
    .byte $50,$51,$52,$53,$54,$55,$56,$57, $58,$59,$5a,$1b,$1c,$1d,$1e,$1f    ;...-$5f

    .byte $40,$01,$02,$03,$04,$05,$06,$07, $08,$09,$0a,$0b,$0c,$0d,$0e,$0f    ;$60-...
    .byte $10,$11,$12,$13,$14,$15,$16,$17, $18,$19,$1a,$5b,$5c,$5d,$5e,$5f    ;...-$7f


    .byte $c0,$c1,$c2,$c3,$c4,$c5,$c6,$c7, $c8,$c9,$ca,$cb,$cc,$cd,$ce,$cf    ;$80-...
    .byte $d0,$d1,$d2,$d3,$d4,$d5,$d6,$d7, $d8,$d9,$da,$db,$dc,$dd,$de,$df    ;...-$9f
    .byte $60,$61,$62,$63,$64,$65,$66,$67, $68,$69,$6a,$6b,$6c,$6d,$6e,$6f    ;$a0-...
    .byte $70,$71,$72,$73,$74,$75,$76,$77, $78,$79,$7a,$7b,$7c,$7d,$7e,$7f    ;...-$bf
    .byte $00,$01,$02,$03,$04,$05,$06,$07, $08,$09,$0a,$0b,$0c,$0d,$0e,$0f    ;$c0-...
    .byte $10,$11,$12,$13,$14,$15,$16,$17, $18,$19,$1a,$1b,$1c,$1d,$1e,$1f    ;...-$df
    .byte $60,$61,$62,$63,$64,$65,$66,$67, $68,$69,$6a,$6b,$6c,$6d,$6e,$6f    ;$e0-...
    .byte $70,$71,$72,$73,$74,$75,$76,$77, $78,$79,$7a,$7b,$7c,$7d,$7e,$5e    ;...-$ff