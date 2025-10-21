
D_root:
    .byte DIR_FLAG
    .word ED_root-BD_root
    .byte 0
BD_root:
    .word D___bin
    .word D___dir2
    .word D___dir1
    .word F_test___prog
    .word F_fork___bomb
    .word F_flobber_sid
    .word F_sid
    .word F_shape_sid
    .word F_test_sh
    .word F_robocop3___title_sid

ED_root:
        
F_test___prog:
    .byte 0
    .word EF_test___prog-BF_test___prog
    .byte "test-prog", 0
BF_test___prog:
    .incbin "./disk/test-prog"
EF_test___prog:
            
F_fork___bomb:
    .byte 0
    .word EF_fork___bomb-BF_fork___bomb
    .byte "fork-bomb", 0
BF_fork___bomb:
    .incbin "./disk/fork-bomb"
EF_fork___bomb:
            
F_flobber_sid:
    .byte 0
    .word EF_flobber_sid-BF_flobber_sid
    .byte "flobber.sid", 0
BF_flobber_sid:
    .incbin "./disk/flobber.sid"
EF_flobber_sid:
            
F_sid:
    .byte 0
    .word EF_sid-BF_sid
    .byte "sid", 0
BF_sid:
    .incbin "./disk/sid"
EF_sid:
            
F_shape_sid:
    .byte 0
    .word EF_shape_sid-BF_shape_sid
    .byte "shape.sid", 0
BF_shape_sid:
    .incbin "./disk/shape.sid"
EF_shape_sid:
            
F_test_sh:
    .byte 0
    .word EF_test_sh-BF_test_sh
    .byte "test.sh", 0
BF_test_sh:
    .incbin "./disk/test.sh"
EF_test_sh:
            
F_robocop3___title_sid:
    .byte 0
    .word EF_robocop3___title_sid-BF_robocop3___title_sid
    .byte "robocop3-title.sid", 0
BF_robocop3___title_sid:
    .incbin "./disk/robocop3-title.sid"
EF_robocop3___title_sid:
            
D___bin:
    .byte DIR_FLAG
    .word ED___bin-BD___bin
    .byte "bin", 0
BD___bin:
    .word F___bin__cat
    .word F___bin__echo
    .word F___bin__pwd
    .word F___bin__printnl
    .word F___bin__clear
    .word F___bin__sh
    .word F___bin__ls

ED___bin:
        
F___bin__cat:
    .byte 0
    .word EF___bin__cat-BF___bin__cat
    .byte "cat", 0
BF___bin__cat:
    .incbin "./disk/bin/cat"
EF___bin__cat:
            
F___bin__echo:
    .byte 0
    .word EF___bin__echo-BF___bin__echo
    .byte "echo", 0
BF___bin__echo:
    .incbin "./disk/bin/echo"
EF___bin__echo:
            
F___bin__pwd:
    .byte 0
    .word EF___bin__pwd-BF___bin__pwd
    .byte "pwd", 0
BF___bin__pwd:
    .incbin "./disk/bin/pwd"
EF___bin__pwd:
            
F___bin__printnl:
    .byte 0
    .word EF___bin__printnl-BF___bin__printnl
    .byte "printnl", 0
BF___bin__printnl:
    .incbin "./disk/bin/printnl"
EF___bin__printnl:
            
F___bin__clear:
    .byte 0
    .word EF___bin__clear-BF___bin__clear
    .byte "clear", 0
BF___bin__clear:
    .incbin "./disk/bin/clear"
EF___bin__clear:
            
F___bin__sh:
    .byte 0
    .word EF___bin__sh-BF___bin__sh
    .byte "sh", 0
BF___bin__sh:
    .incbin "./disk/bin/sh"
EF___bin__sh:
            
F___bin__ls:
    .byte 0
    .word EF___bin__ls-BF___bin__ls
    .byte "ls", 0
BF___bin__ls:
    .incbin "./disk/bin/ls"
EF___bin__ls:
            
D___dir2:
    .byte DIR_FLAG
    .word ED___dir2-BD___dir2
    .byte "dir2", 0
BD___dir2:
    .word F___dir2__test___another_sh
    .word F___dir2__wao_bin

ED___dir2:
        
F___dir2__test___another_sh:
    .byte 0
    .word EF___dir2__test___another_sh-BF___dir2__test___another_sh
    .byte "test-another.sh", 0
BF___dir2__test___another_sh:
    .incbin "./disk/dir2/test-another.sh"
EF___dir2__test___another_sh:
            
F___dir2__wao_bin:
    .byte 0
    .word EF___dir2__wao_bin-BF___dir2__wao_bin
    .byte "wao.bin", 0
BF___dir2__wao_bin:
    .incbin "./disk/dir2/wao.bin"
EF___dir2__wao_bin:
            
D___dir1:
    .byte DIR_FLAG
    .word ED___dir1-BD___dir1
    .byte "dir1", 0
BD___dir1:
    .word D___dir1__sub___dir
    .word F___dir1__test1_txt
    .word F___dir1__test2_txt

ED___dir1:
        
F___dir1__test1_txt:
    .byte 0
    .word EF___dir1__test1_txt-BF___dir1__test1_txt
    .byte "test1.txt", 0
BF___dir1__test1_txt:
    .incbin "./disk/dir1/test1.txt"
EF___dir1__test1_txt:
            
F___dir1__test2_txt:
    .byte 0
    .word EF___dir1__test2_txt-BF___dir1__test2_txt
    .byte "test2.txt", 0
BF___dir1__test2_txt:
    .incbin "./disk/dir1/test2.txt"
EF___dir1__test2_txt:
            
D___dir1__sub___dir:
    .byte DIR_FLAG
    .word ED___dir1__sub___dir-BD___dir1__sub___dir
    .byte "sub-dir", 0
BD___dir1__sub___dir:
    .word D___dir1__sub___dir__fuck
    .word F___dir1__sub___dir__test3_txt

ED___dir1__sub___dir:
        
F___dir1__sub___dir__test3_txt:
    .byte 0
    .word EF___dir1__sub___dir__test3_txt-BF___dir1__sub___dir__test3_txt
    .byte "test3.txt", 0
BF___dir1__sub___dir__test3_txt:
    .incbin "./disk/dir1/sub-dir/test3.txt"
EF___dir1__sub___dir__test3_txt:
            
D___dir1__sub___dir__fuck:
    .byte DIR_FLAG
    .word ED___dir1__sub___dir__fuck-BD___dir1__sub___dir__fuck
    .byte "fuck", 0
BD___dir1__sub___dir__fuck:
    .word F___dir1__sub___dir__fuck__blehg_bin

ED___dir1__sub___dir__fuck:
        
F___dir1__sub___dir__fuck__blehg_bin:
    .byte 0
    .word EF___dir1__sub___dir__fuck__blehg_bin-BF___dir1__sub___dir__fuck__blehg_bin
    .byte "blehg.bin", 0
BF___dir1__sub___dir__fuck__blehg_bin:
    .incbin "./disk/dir1/sub-dir/fuck/blehg.bin"
EF___dir1__sub___dir__fuck__blehg_bin:
            