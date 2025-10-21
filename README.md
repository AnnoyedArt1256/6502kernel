# 6502kernel
a simple OS for 6502-based systems (currently C64 only)

## features
- a round-robin task switcher with up to 16 processes (using the C64's timer IRQ)
- a read only file system (for now)
- NMI interrupt support for constant tasks like playing music
- relocatable program support (using custom .rel format)
- many (27!) syscalls (some like unix, others custom)
- a basic shell
- simple TTY driver

## compiling
If you're on a unix-based system, you can just run `compile.sh` and get the final file as `file.prg`. I haven't used windows in 2-3 years so don't expect compiling on windows, sorry :P

## legal
This hobby operating system is distributed under the zlib license shown here:

> Copyright (c) 2025 AnnoyedArt1256
> 
> This software is provided 'as-is', without any express or implied
> warranty. In no event will the authors be held liable for any damages
> arising from the use of this software.
> 
> Permission is granted to anyone to use this software for any purpose,
> including commercial applications, and to alter it and redistribute it
> freely, subject to the following restrictions:
> 
> 1. The origin of this software must not be misrepresented; you must not
>    claim that you wrote the original software. If you use this software
>    in a product, an acknowledgment in the product documentation would be
>    appreciated but is not required.
> 2. Altered source versions must be plainly marked as such, and must not be
>    misrepresented as being the original software.
> 3. This notice may not be removed or altered from any source distribution.