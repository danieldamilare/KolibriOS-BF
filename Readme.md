# KolibriOS Brainfuck Interpreter

A port of my Linux Brainfuck Interpreter (`bf-x86asm-compiler`) to KolibriOS.

## Program Versions
This repository contains two implementations using different KolibriOS environments:
1. **bf_console_interp.asm**:  Uses the `console.obj` library for the console GUI
2. **bf_shell_interp.asm**:  Uses the `shell.inc` (which uses a shared memory and IPC to communicate with the shell)


## Technical Details
The interpreter uses direct threaded dispatch via a jump table for execution, and includes run-length encoding preprocessing for repeated instructions. On bf_console_interp.asm output is line buffered, to minimize screen redraws on the console. Since console output on KolibriOS seems to triggers immediate rerendering of the whole screen

## Limitations
The interpreter has  all the limitations in the original project and also the elf-compiler was not ported
Original interpreter repo: [link](https://github.com/danieldamilare/bf-x86asm-compiler/tree/master)


## Code Style

Follows KolibriOS coding conventions:
- 8-space indentation for commands
- Labels on separate lines
- Function documentation with inputs/outputs
- UTF-8 encoding without BOM



