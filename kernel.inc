page_end_tbl = $fd00
page_alloc_tbl = $fe00
call_page = $ff00

.macro jsr_save addr
    .local @al, @xl, @yl
    sta @al+1
    stx @xl+1
    sty @yl+1
    jsr addr
@al:
    lda #0
@xl:
    ldx #0
@yl:
    ldy #0
.endmacro