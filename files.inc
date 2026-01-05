
; filesystem written automatically
; DO NOT MODIFY MANUALLY UNLESS YOU ARE EXPERIENCED!!!

.macro GET_CUR_CLUSTER
    .word (*-FS_begin)>>6
    cur_cluster .set (*-FS_begin)>>6
.endmacro

.macro GET_CUR_CLUSTER_ADD off
    off_cluster .set ((*-FS_begin)>>6)+off
    .word off_cluster
    cur_cluster .set (*-FS_begin)>>6
    .ifndef .ident(.sprintf("FS_cluser_%d",cur_cluster)) 
        .ident(.sprintf("FS_cluser_%d",cur_cluster)) .set off_cluster
    .endif
.endmacro

.macro WRITE_CLUSTER
    .ifndef .ident(.sprintf("FS_cluser_%d",cur_cluster)) 
        .ident(.sprintf("FS_cluser_%d",cur_cluster)) .set $fffe
    .endif
.endmacro

.macro write_dword value
    ; write_dword while writing the FAT over cluster boundaries
    prev_cur_cluster .set (*-FS_begin)>>6
    prev_cur_cluster_lsb .set (*-FS_begin)&$3f
        .dword value
    cur_cluster .set (*-FS_begin)>>6
    .if cur_cluster <> prev_cur_cluster
        .ident(.sprintf("FS_cluser_%d",prev_cur_cluster)) .set cur_cluster
    .endif
.endmacro

.macro CUSTOM_INCBIN str
    ; custom .incbin extension to write clusters over data boundaries
    .local file_beg, file_end
file_beg:
    .incbin str
    pad 64
file_end:
    cluser_fill_cnt .set ((file_end-file_beg)>>6)
    .repeat cluser_fill_cnt, I
        prev_cur_cluster .set ((file_beg-FS_begin)>>6)+I
        .if I = (cluser_fill_cnt-1)
            .ident(.sprintf("FS_cluser_%d",prev_cur_cluster)) .set $fffe
        .else
            .ident(.sprintf("FS_cluser_%d",prev_cur_cluster)) .set prev_cur_cluster+1
        .endif
    .endrepeat
.endmacro

.macro pad v
    .if (* .mod v) <> 0
        .res v-(* .mod v), 0
    .endif
.endmacro

.macro pad_end v
    cur_cluster .set (*-FS_begin)>>6
    .ident(.sprintf("FS_cluser_%d",cur_cluster)) .set $fffe
    pad 64
.endmacro

FS_header:
    .dword FS_end-FS_begin
    .dword FS_begin-FS_header
    .repeat 512, I
        .word .ident(.sprintf("FS_cluser_%d",I))
    .endrepeat
    pad 64 ; pad to 64 bytes

FS_begin:

D_root:
    .byte DIR_FLAG
    .word 0
    .res 48, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BD_root:
    write_dword D___bin-FS_header
    write_dword D___dir2-FS_header
    write_dword D___dir1-FS_header
    write_dword D___test___fat-FS_header
    write_dword F_test___prog-FS_header
    write_dword F_fork___bomb-FS_header
    write_dword F_flobber_sid-FS_header
    write_dword F_sid-FS_header
    write_dword F_shape_sid-FS_header
    write_dword F_test_sh-FS_header
    write_dword F_robocop3___title_sid-FS_header
    write_dword $ffffffff
    pad_end 64

ED_root:
        
F_test___prog:
    .byte 0
    .word EF_test___prog-BF_test___prog
    .byte "test-prog"
    .res 48-9, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF_test___prog:
    CUSTOM_INCBIN "./disk/test-prog"
EF_test___prog:
            
F_fork___bomb:
    .byte 0
    .word EF_fork___bomb-BF_fork___bomb
    .byte "fork-bomb"
    .res 48-9, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF_fork___bomb:
    CUSTOM_INCBIN "./disk/fork-bomb"
EF_fork___bomb:
            
F_flobber_sid:
    .byte 0
    .word EF_flobber_sid-BF_flobber_sid
    .byte "flobber.sid"
    .res 48-11, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF_flobber_sid:
    CUSTOM_INCBIN "./disk/flobber.sid"
EF_flobber_sid:
            
F_sid:
    .byte 0
    .word EF_sid-BF_sid
    .byte "sid"
    .res 48-3, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF_sid:
    CUSTOM_INCBIN "./disk/sid"
EF_sid:
            
F_shape_sid:
    .byte 0
    .word EF_shape_sid-BF_shape_sid
    .byte "shape.sid"
    .res 48-9, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF_shape_sid:
    CUSTOM_INCBIN "./disk/shape.sid"
EF_shape_sid:
            
F_test_sh:
    .byte 0
    .word EF_test_sh-BF_test_sh
    .byte "test.sh"
    .res 48-7, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF_test_sh:
    CUSTOM_INCBIN "./disk/test.sh"
EF_test_sh:
            
F_robocop3___title_sid:
    .byte 0
    .word EF_robocop3___title_sid-BF_robocop3___title_sid
    .byte "robocop3-title.sid"
    .res 48-18, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF_robocop3___title_sid:
    CUSTOM_INCBIN "./disk/robocop3-title.sid"
EF_robocop3___title_sid:
            
D___bin:
    .byte DIR_FLAG
    .word 0
    .byte "bin"
    .res 48-3, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BD___bin:
    write_dword F___bin__cat-FS_header
    write_dword F___bin__echo-FS_header
    write_dword F___bin__pwd-FS_header
    write_dword F___bin__printnl-FS_header
    write_dword F___bin__clear-FS_header
    write_dword F___bin__sh-FS_header
    write_dword F___bin__mkdir-FS_header
    write_dword F___bin__ls-FS_header
    write_dword $ffffffff
    pad_end 64

ED___bin:
        
F___bin__cat:
    .byte 0
    .word EF___bin__cat-BF___bin__cat
    .byte "cat"
    .res 48-3, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF___bin__cat:
    CUSTOM_INCBIN "./disk/bin/cat"
EF___bin__cat:
            
F___bin__echo:
    .byte 0
    .word EF___bin__echo-BF___bin__echo
    .byte "echo"
    .res 48-4, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF___bin__echo:
    CUSTOM_INCBIN "./disk/bin/echo"
EF___bin__echo:
            
F___bin__pwd:
    .byte 0
    .word EF___bin__pwd-BF___bin__pwd
    .byte "pwd"
    .res 48-3, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF___bin__pwd:
    CUSTOM_INCBIN "./disk/bin/pwd"
EF___bin__pwd:
            
F___bin__printnl:
    .byte 0
    .word EF___bin__printnl-BF___bin__printnl
    .byte "printnl"
    .res 48-7, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF___bin__printnl:
    CUSTOM_INCBIN "./disk/bin/printnl"
EF___bin__printnl:
            
F___bin__clear:
    .byte 0
    .word EF___bin__clear-BF___bin__clear
    .byte "clear"
    .res 48-5, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF___bin__clear:
    CUSTOM_INCBIN "./disk/bin/clear"
EF___bin__clear:
            
F___bin__sh:
    .byte 0
    .word EF___bin__sh-BF___bin__sh
    .byte "sh"
    .res 48-2, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF___bin__sh:
    CUSTOM_INCBIN "./disk/bin/sh"
EF___bin__sh:
            
F___bin__mkdir:
    .byte 0
    .word EF___bin__mkdir-BF___bin__mkdir
    .byte "mkdir"
    .res 48-5, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF___bin__mkdir:
    CUSTOM_INCBIN "./disk/bin/mkdir"
EF___bin__mkdir:
            
F___bin__ls:
    .byte 0
    .word EF___bin__ls-BF___bin__ls
    .byte "ls"
    .res 48-2, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF___bin__ls:
    CUSTOM_INCBIN "./disk/bin/ls"
EF___bin__ls:
            
D___dir2:
    .byte DIR_FLAG
    .word 0
    .byte "dir2"
    .res 48-4, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BD___dir2:
    write_dword F___dir2__test___another_sh-FS_header
    write_dword F___dir2__wao_bin-FS_header
    write_dword $ffffffff
    pad_end 64

ED___dir2:
        
F___dir2__test___another_sh:
    .byte 0
    .word EF___dir2__test___another_sh-BF___dir2__test___another_sh
    .byte "test-another.sh"
    .res 48-15, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF___dir2__test___another_sh:
    CUSTOM_INCBIN "./disk/dir2/test-another.sh"
EF___dir2__test___another_sh:
            
F___dir2__wao_bin:
    .byte 0
    .word EF___dir2__wao_bin-BF___dir2__wao_bin
    .byte "wao.bin"
    .res 48-7, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF___dir2__wao_bin:
    CUSTOM_INCBIN "./disk/dir2/wao.bin"
EF___dir2__wao_bin:
            
D___dir1:
    .byte DIR_FLAG
    .word 0
    .byte "dir1"
    .res 48-4, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BD___dir1:
    write_dword D___dir1__sub___dir-FS_header
    write_dword F___dir1__test1_txt-FS_header
    write_dword F___dir1__test2_txt-FS_header
    write_dword $ffffffff
    pad_end 64

ED___dir1:
        
F___dir1__test1_txt:
    .byte 0
    .word EF___dir1__test1_txt-BF___dir1__test1_txt
    .byte "test1.txt"
    .res 48-9, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF___dir1__test1_txt:
    CUSTOM_INCBIN "./disk/dir1/test1.txt"
EF___dir1__test1_txt:
            
F___dir1__test2_txt:
    .byte 0
    .word EF___dir1__test2_txt-BF___dir1__test2_txt
    .byte "test2.txt"
    .res 48-9, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF___dir1__test2_txt:
    CUSTOM_INCBIN "./disk/dir1/test2.txt"
EF___dir1__test2_txt:
            
D___dir1__sub___dir:
    .byte DIR_FLAG
    .word 0
    .byte "sub-dir"
    .res 48-7, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BD___dir1__sub___dir:
    write_dword D___dir1__sub___dir__fuck-FS_header
    write_dword F___dir1__sub___dir__test3_txt-FS_header
    write_dword $ffffffff
    pad_end 64

ED___dir1__sub___dir:
        
F___dir1__sub___dir__test3_txt:
    .byte 0
    .word EF___dir1__sub___dir__test3_txt-BF___dir1__sub___dir__test3_txt
    .byte "test3.txt"
    .res 48-9, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF___dir1__sub___dir__test3_txt:
    CUSTOM_INCBIN "./disk/dir1/sub-dir/test3.txt"
EF___dir1__sub___dir__test3_txt:
            
D___dir1__sub___dir__fuck:
    .byte DIR_FLAG
    .word 0
    .byte "fuck"
    .res 48-4, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BD___dir1__sub___dir__fuck:
    write_dword F___dir1__sub___dir__fuck__blehg_bin-FS_header
    write_dword $ffffffff
    pad_end 64

ED___dir1__sub___dir__fuck:
        
F___dir1__sub___dir__fuck__blehg_bin:
    .byte 0
    .word EF___dir1__sub___dir__fuck__blehg_bin-BF___dir1__sub___dir__fuck__blehg_bin
    .byte "blehg.bin"
    .res 48-9, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BF___dir1__sub___dir__fuck__blehg_bin:
    CUSTOM_INCBIN "./disk/dir1/sub-dir/fuck/blehg.bin"
EF___dir1__sub___dir__fuck__blehg_bin:
            
D___test___fat:
    .byte DIR_FLAG
    .word 0
    .byte "test-fat"
    .res 48-8, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
BD___test___fat:
    write_dword $ffffffff
    pad_end 64

ED___test___fat:
        

FS_end:
    .repeat 512, I
        .ifndef .ident(.sprintf("FS_cluser_%d",I)) 
            .ident(.sprintf("FS_cluser_%d",I)) .set $ffff
        .endif
    .endrepeat
