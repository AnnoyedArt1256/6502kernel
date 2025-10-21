def read_file(filename): return list(open(filename,"rb").read())
"""

files = [ "/",
    ("test", read_file("test_prog.rel")),
    [ "dir1",
      ["sub_dir", 
        ["fuck", 
           ("blehg.bin", "empty.bin")
        ], 
        ("test3.txt", "empty.bin")
      ],
      ("test1.txt", "empty.bin"),
      ("test2.txt", "empty.bin"),
    ],
    [ "dir2",
      ("wao.bin", "empty.bin"),
    ]
]

def traverse(l,x=[]):
    if not l: return
    for i in l[1:]:
        print("dir: " if type(i) == list else "file:", x+[l[0]]+[i[0]])
        if type(i) == list:
            traverse(i,x+[l[0]])

traverse(files)
"""

import os
from pathlib import Path

text = ""

filedir = "./disk"

for root, dirs, files in os.walk(filedir):
    if root == filedir:
        root_contents = ""
        for i in dirs:
            root_contents += f"    .word D___{i.replace(".","_").replace("-","___")}\n"
        for i in files:
            root_contents += f"    .word F_{i.replace(".","_").replace("-","___")}\n"

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
            contents += f"    .word {j}\n"
        for i in files:
            j = "F_"+root_name+"/"+(i.replace(".","_"))
            j = j.replace("/","__").replace("-","___")
            contents += f"    .word {j}\n"
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