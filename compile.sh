for FILE in ./bin/*.asm; do
    FILENAME=$(basename "$FILE" .asm)
    cd bin
    cl65 -d -vm -l $FILENAME.lst -g -t none -C ../program.cfg -o ./obj/$FILENAME.o65 $FILENAME.asm
    cd obj
    python3 ../../o65torel.py $FILENAME.o65
    rm $FILENAME.o65
    cd .. && cd ..
done

rm -rf ./disk/bin
mkdir ./disk/bin
cp -R ./bin/obj/ ./disk/bin/
cd disk
find . -name '*.rel' -exec sh -c 'mv "$0" "${0%.rel}"' {} \;
cd ..

rm -f ./root/obj/
mkdir ./root/obj
for FILE in ./root/*.asm; do
    FILENAME=$(basename "$FILE" .asm)
    cd root
    cl65 -d -vm -l $FILENAME.lst -g -t none -C ../program.cfg -o ./obj/$FILENAME.o65 $FILENAME.asm
    cd obj
    python3 ../../o65torel.py $FILENAME.o65
    rm $FILENAME.o65
    cd .. && cd ..
done

cp -R ./root/obj/ ./disk/
cd disk
find . -name '*.rel' -exec sh -c 'mv "$0" "${0%.rel}"' {} \;
cd ..

python3 do_fs.py

cl65 -W2-d -vm -l kernel.lst -g -u __EXEHDR__ -t c64 -C ./c64-asm.cfg -Ln kernel.lbl -o file.prg kernel.asm