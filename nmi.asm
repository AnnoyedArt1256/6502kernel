; XY = nmi addr
setnmi:
    lda $dd0d
    
    stx nmi_do+1
    sty nmi_do+2

    lda #$c7
    sta $dd04
    lda #$4c
    sta $dd05

    lda #$40
    sta $dd0c

    lda #$01
    sta $dd0d
    sta $dd0e

    lda $dd0d
    and #$81
    sta $dd0d

    lda #$81
    sta $dd0d

    lda #1
    sta nmi_exists
    rts


clearnmi:
    lda $dd0d
    
    ldx #<nmi_stub
    ldy #>nmi_stub
    stx nmi_do+1
    sty nmi_do+2

    lda $dd0d
    and #$81
    sta $dd0d

    lda #$40
    sta $dd0c

    lda #0
    sta nmi_exists
    rts

nmi:
    sta nmi_a_load+1
    stx nmi_x_load+1
    sty nmi_y_load+1


    lda nmi_exists
    beq :+
nmi_do:
    jmp nmi_stub
:

exit_nmi:

nmi_a_load:
    lda #0
nmi_x_load:
    ldx #0
nmi_y_load:
    ldy #0
    jmp $dd0c

nmi_stub:
    jmp exit_nmi

nmi_exists: .byte 0