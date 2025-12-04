cp test.lib none.lib
ca65 crt0.asm
ar65 a none.lib crt0.o
cc65 -t none -Osir --cpu 6502 main.c
cl65 -l main.lst -C ../program_c.cfg -o main.o65 crt0.asm main.s none.lib
python3 ../o65torel.py main.o65
rm -f ../disk/hello-c
cp main.rel ../disk/hello-c
