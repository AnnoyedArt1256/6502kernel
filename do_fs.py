import os
from pathlib import Path

def read_file(filename): return list(open(filename,"rb").read())

text = ""

filedir = "./disk"

for root, dirs, files in os.walk(filedir):
    if root == filedir:
        root_contents = ""
        for i in dirs:
            root_contents += f"    .dword D___{i.replace(".","_").replace("-","___")}\n"
            root_contents += f"    .dword (:+)|LINKED_FLAG\n:\n"
        for i in files:
            root_contents += f"    .dword F_{i.replace(".","_").replace("-","___")}\n"
            root_contents += f"    .dword (:+)|LINKED_FLAG\n:\n"
        root_contents += f"    .dword $ffffffff\n"
        text += f"""
D_root:
    .byte DIR_FLAG
    .word ED_root-BD_root
    .byte 0
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
    .byte \"{i}\", 0
B{name}:
    .incbin \"{filename}\"
E{name}:
            """
    
    else:
        root_name = root[len(filedir):]
        contents = ""
        for i in dirs:
            j = "D_"+root_name+"/"+(i.replace(".","_"))
            j = j.replace("/","__").replace("-","___")
            contents += f"    .dword {j}\n"
            contents += f"    .dword (:+)|LINKED_FLAG\n:\n"
        for i in files:
            j = "F_"+root_name+"/"+(i.replace(".","_"))
            j = j.replace("/","__").replace("-","___")
            contents += f"    .dword {j}\n"
            contents += f"    .dword (:+)|LINKED_FLAG\n:\n"
        contents += f"    .dword $ffffffff\n"
        name = "D_"+root_name
        name = name.replace("/","__").replace("-","___")
        text += f"""
{name}:
    .byte DIR_FLAG
    .word E{name}-B{name}
    .byte \"{Path(root_name).stem}\", 0
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
    .byte \"{i}\", 0
B{name}:
    .incbin \"{filename}\"
E{name}:
            """

f = open("files.inc","w")
f.write(text)
f.close()