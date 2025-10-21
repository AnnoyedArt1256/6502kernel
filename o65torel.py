import sys
from pathlib import Path

def convint(x):
    v = 0
    for i in range(len(x)):
        v |= x[i]<<(i<<3)
    return v

if len(sys.argv) < 2:
    print("not enough arguments supplied")
else:
    o = open(Path(sys.argv[1]).stem+".rel","wb")
    f = open(sys.argv[1],"rb")
    
    marker = list(f.read(2))
    magic  = list(f.read(3))
    ver    = list(f.read(1))
    
    mode   = convint(list(f.read(2)))

    tbase  = convint(list(f.read(2)))
    tlen   = convint(list(f.read(2)))
    dbase  = convint(list(f.read(2)))
    dlen   = convint(list(f.read(2)))
    bbase  = convint(list(f.read(2)))
    blen   = convint(list(f.read(2)))
    zbase  = convint(list(f.read(2)))
    zlen   = convint(list(f.read(2)))
    stack  = convint(list(f.read(2)))

    if (mode & (1<<11)) > 0:
        dbase = tbase + tlen
        bbase = dbase + dlen

    olen = list(f.read(1))[0]
    while olen != 0:
        otype = list(f.read(1))[0]
        # olen and otype are included in olen :sob:
        opt_bytes = f.read(olen-2)
        print("header options:",otype,opt_bytes)
        olen = list(f.read(1))[0]

    print(tbase, tlen, dbase, dlen, zbase, zlen)
    text = list(f.read(tlen))
    #print(text)
    data = list(f.read(dlen))
    #print(data)

    undef_lbl_cnt = convint(list(f.read(2)))
    for i in range(undef_lbl_cnt):
        # skip c-strs
        str_byte = list(f.read(1))[0]
        while str_byte != 0:
            str_byte = list(f.read(1))[0]

    all_offs = []
    for d in range(2):
        cur_offs = []
        offs = -1
        while True:
            C = list(f.read(1))[0]
            if C == 0:
                break

            while C == 0xFF:
                offs += 0xfe
                C = list(f.read(1))[0]

            reloc_offs = offs + C
            offs += C

            C = list(f.read(1))[0]
            reloc_type = C & 0xe0
            reloc_segid = C & 7

            sym_idx = 0
            if reloc_segid == 0: # UNDEFINED seg id
                sym_idx = convint(list(f.read(2)))

            reloc_val = 0
            if reloc_type == 0x40: # HIGH
                if (mode & (1<<14)) == 0: # byte or page aligned
                    reloc_val = list(f.read(1))[0]
                    print(reloc_val)
                else: 
                    reloc_val = 0
            elif reloc_type == 0xA0: # segment
                reloc_val = convint(list(f.read(2)))

            if reloc_type != 0xA0:
                cur_offs.append([offs,reloc_type,reloc_segid,reloc_val])
        all_offs.append(cur_offs)

    print(f.read())

    out_data = []
    d_offs = [tbase,dbase]
    d_lens = [tlen,dlen]
    d_dats = [text,data]
    # first output the program data
    for d in range(2):
        cur_off = d_offs[d]
        cur_len = d_lens[d]
        data_bytes = d_dats[d]
        out_data.extend([cur_off&0xff,cur_off>>8&0xff])
        out_data.extend([cur_len&0xff,cur_len>>8&0xff])
        out_data.extend(data_bytes)

    # then the relocation tables...
    for d in range(2):
        for offs in all_offs[d]:
            off, reloc_type, reloc_segid, reloc_val = offs
            off_arr = []
            off_arr.extend([off&0xff, off>>8&0xff])
            off_arr.append(reloc_type)
            off_arr.append(reloc_segid)
            off_arr.append(reloc_val)
            out_data.extend(off_arr)
            print(offs,d)
        out_data.extend([0xff, 0xff])

    o.write(bytearray(out_data))
    o.close()
