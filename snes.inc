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
OPHCT    = $213c    ; Horizontal Scanline Location
OPVCT    = $213d    ; Vertical Scanline Location
SLHV     = $2137    ; Software Latch for H/V Counter
STAT78   = $213f    ; PPU Status Flag and Version

; CPU registers
NMITIMEN = $4200
WRMPYA   = $4202
WRMPYB   = $4203
WRDIVL   = $4204
WRDIVH   = $4205
WRDIVB   = $4206
MDMAEN   = $420b
RDDIVL   = $4214
RDDIVH   = $4215
RDMPYL   = $4216
RDMPYH   = $4217
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

.macro not8
    eor #$ff
.endmacro

.macro not16
    eor #$ffff
.endmacro

.macro neg16
    not16
    inc
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

.macro blt label
    bcc label
.endmacro

.macro bge label
    bcs label
.endmacro

; Creates a C-like function prolog. DP is set to point at the first local variable (so it's
; basically a frame pointer).
;
; The calling convention is that the first two byte- or word-sized parameters go into X and Y
; respectively, and any remaining parameters go on the stack. Far pointer-sized parameters always
; go on the stack. Note that this prolog clobbers A, so we can't use it for passing parameters.
;
; Using a C-like calling convention is a bit weird on the SNES, but in our case it has the
; advantage of giving us a private direct page. This reduces the chance of accidentally stomping on
; something the game was using.
.macro enter frame_size
    phd
.if __FRAME_SIZE__ < 11
.repeat __FRAME_SIZE__ / 2
    phy
.endrepeat
.if (__FRAME_SIZE__ .mod 2) = 1
    pha
.endif
    tsc
.else
    tsc
    a16
    sub #frame_size
    a8
    tcs
.endif
    tcd
.endmacro

; Creates a matching C-like function epilog, restoring the old DP.
;
; Note that this clobbers A and Y, so don't use those registers for passing return values. Use X
; instead.
.macro leave frame_size
.if __FRAME_SIZE__ < 11
.if (__FRAME_SIZE__ .mod 2) = 1
    pla
.endif
.repeat __FRAME_SIZE__ / 2
    ply
.endrepeat
.else
    tsc
    a16
    add #frame_size
    a8
    tcs
.endif
    pld
.endmacro

; A convenience macro to declare direct page locations local to a function.
.macro begin_locals
    __FRAME_BEGIN__ .set 1
    __FRAME_SIZE__ .set 0
.endmacro

; Reserves `size` bytes on a function's direct page and sets `name` equal to the address. The total
; frame size so far can be read in `__FRAME_SIZE__` and passed to `enter` and `leave` macros.
.macro decl_local name, size
    name = __FRAME_BEGIN__ + __FRAME_SIZE__
    __FRAME_SIZE__ .set __FRAME_SIZE__ + size
.endmacro

; A convenience macro to declare direct page locations on the caller's stack frame, for a function
; called with JSR.
.macro begin_args_nearcall
    __ARGS_BEGIN__ .set __FRAME_BEGIN__ + __FRAME_SIZE__ + $04
    __ARGS_SIZE__ .set 0
.endmacro

; A convenience macro to declare direct page locations on the caller's stack frame, for a function
; called with JSL.
.macro begin_args_farcall
    __ARGS_BEGIN__ .set __FRAME_BEGIN__ + __FRAME_SIZE__ + $05
    __ARGS_SIZE__ .set 0
.endmacro

; Declares that the function has an argument with the given `name` and the given `size`. The total
; argument size so far can be read in `__ARGS_SIZE__`.
.macro decl_arg name, size
    name = __ARGS_BEGIN__ + __ARGS_SIZE__
    __ARGS_SIZE__ .set __ARGS_SIZE__ + size
.endmacro

.endif

