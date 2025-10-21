cl65 -d -vm -l main.lst -g -t none -C ../program_c.cfg -o main.o65 -Osir utils.asm main.c
python3 ../o65torel.py main.o65
rm -f ../disk/hello
cp main.rel ../disk/hello
