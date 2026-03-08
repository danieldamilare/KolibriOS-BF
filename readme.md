# KolibriOS Brainfuck Interpreter

A port of my Linux Brainfuck Interpreter (`bf-x86asm-compiler`) to KolibriOS.

## Program Versions
This repository contains two implementations tailored for different KolibriOS environments:
1. **bf_console_interp.asm**:  Uses the `console.obj` library for the console GUI
2. **bf_shell_interp.asm**:  Uses the `shell.inc` (which uses a shared memory and IPC to communicate with the shell)


## Technical Details
The interpreter uses direct threaded dispatch via a jump table for efficient execution, and includes run-length encoding preprocessing for repeated instructions

## Limitations
The interpreter has  all the limitations in the original project and also the elf-compiler was not ported
Original interpreter repo: [link](https://github.com/danieldamilare/bf-x86asm-compiler/tree/master)



