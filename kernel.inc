page_end_tbl = $fd00
page_alloc_tbl = $fe00
call_page = $ff00

DIRENT_PTR = 0
DIRENT_FLAGS = 4
DIRENT_NAME = 16
DIRENT_LEN = 16+128

DIRENT_ISDIR = 1<<0
DIRENT_DONE = 1<<1

WRITE_PTR = 0
WRITE_VAL = 4
WRITE_BUFFER = WRITE_VAL
WRITE_LEN = 8
WRITE_FLAG = 12

WRITE_INBUFFER = 1<<0

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