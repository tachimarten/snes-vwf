; snes-vwf/snes.inc

.ifndef SNES_INC
.define SNES_INC 1

; PPU registers
INIDISP  = $2100
BGMODE   = $2015
BG1SC    = $2107
BG12NBA  = $210b
CGADD    = $2121
CGDATA   = $2122
VMAIN    = $2115
VMADDL   = $2116
VMADDH   = $2117
VMDATAL  = $2118
VMDATAH  = $2119
TM       = $212c
TS       = $212d

; CPU registers
NMITIMEN = $4200
MDMAEN   = $420b
.repeat 8, i
.ident(.concat("DMAP", .string(i)))     = $4300 | i<<4
.ident(.concat("BBAD", .string(i)))     = $4301 | i<<4
.ident(.concat("A1T", .string(i), "L")) = $4302 | i<<4
.ident(.concat("A1T", .string(i), "H")) = $4303 | i<<4
.ident(.concat("A1B", .string(i)))      = $4304 | i<<4
.ident(.concat("DAS", .string(i), "L")) = $4305 | i<<4
.ident(.concat("DAS", .string(i), "H")) = $4306 | i<<4
.ident(.concat("DASB", .string(i)))     = $4307 | i<<4
.endrepeat

.macro a16
    rep #$20
    .a16
.endmacro

.macro a8
    sep #$20
    .a8
.endmacro

.macro add operand
    clc
    adc operand
.endmacro

.macro sub operand
    sec
    sbc operand
.endmacro

.macro asli count
.repeat count
    asl
.endrepeat
.endmacro

.macro lsri count
.repeat count
    lsr
.endrepeat
.endmacro

; Creates a C-like function prolog. DP is set to point at the first local variable (so it's
; basically a frame pointer).
;
; Note that this clobbers A, so don't use that register for passing parameters. Use the stack or
; X/Y registers instead.
;
; Using a C-like calling convention is a bit weird on the SNES, but in our case it has the
; advantage of giving us a private direct page. This reduces the chance of accidentally stomping on
; something the game was using.
.macro enter frame_size
    a16
    phd
    tsc
    sub #frame_size
    tcs
    inc
    tcd
    a8
.endmacro

; Creates a matching C-like function epilog, restoring the old DP.
;
; Note that this clobbers A, just like the prolog does, so don't use that register for passing
; return values. Use X or Y instead.
.macro leave frame_size
    a16
    tsc
    add #frame_size
    tcs
    pld
    a8
.endmacro

.endif

