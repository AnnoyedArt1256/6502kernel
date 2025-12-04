#include <stdio.h>
#include "kernel.h"

int main() {
    write(1,"raw write test\n",15);
    printf("Hello World!\n");
    return 0;
}