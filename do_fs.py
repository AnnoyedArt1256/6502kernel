import os
from pathlib import Path

def read_file(filename): return list(open(filename,"rb").read())

text = ""

filedir = "./disk"

for root, dirs, files in os.walk(filedir):
    if root == filedir:
        root_contents = ""
        for i in dirs:
            root_contents += f"    write_dword D___{i.replace(".","_").replace("-","___")}-FS_header\n"
        for i in files:
            root_contents += f"    write_dword F_{i.replace(".","_").replace("-","___")}-FS_header\n"
        root_contents += f"    write_dword $ffffffff\n"
        root_contents += f"    pad_end 64\n"
        text += f"""
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
{root_contents}
ED_root:
        """
        for i in files:
            name = f"F_{i.replace(".","_").replace("-","___")}"
            filename = os.path.join(root,i)
            text += f"""
{name}:
    .byte 0
    .word E{name}-B{name}
    .byte \"{i}\"
    .res 48-{len(i)}, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
B{name}:
    CUSTOM_INCBIN \"{filename}\"
E{name}:
            """
    
    else:
        root_name = root[len(filedir):]
        contents = ""
        for i in dirs:
            j = "D_"+root_name+"/"+(i.replace(".","_"))
            j = j.replace("/","__").replace("-","___")
            contents += f"    write_dword {j}-FS_header\n"
        for i in files:
            j = "F_"+root_name+"/"+(i.replace(".","_"))
            j = j.replace("/","__").replace("-","___")
            contents += f"    write_dword {j}-FS_header\n"
        contents += f"    write_dword $ffffffff\n"
        contents += f"    pad_end 64\n"
        name = "D_"+root_name
        name = name.replace("/","__").replace("-","___")
        text += f"""
{name}:
    .byte DIR_FLAG
    .word 0
    .byte \"{Path(root_name).stem}\"
    .res 48-{len(Path(root_name).stem)}, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
B{name}:
{contents}
E{name}:
        """
        for i in files:
            name = "F_"+root_name+"/"+(i.replace(".","_").replace("-","___"))
            name = name.replace("/","__").replace("-","___")
            filename = os.path.join(root,i)
            text += f"""
{name}:
    .byte 0
    .word E{name}-B{name}
    .byte \"{i}\"
    .res 48-{len(i)}, 0
    GET_CUR_CLUSTER_ADD 1
    WRITE_CLUSTER
    .res 64-(1+2+48+2), 0
B{name}:
    CUSTOM_INCBIN \"{filename}\"
E{name}:
            """

text += f"""

FS_end:
    .repeat 512, I
        .ifndef .ident(.sprintf("FS_cluser_%d",I)) 
            .ident(.sprintf("FS_cluser_%d",I)) .set $ffff
        .endif
    .endrepeat
"""

f = open("files.inc","w")
f.write(text)
f.close()