; snes-vwf/stdsnes.s
;
; A small standard library of sorts for the SNES.

.p816
.i16
.a8
.feature c_comments

.include "snes.inc"

.segment "TEXT"

; nearproc void std_memset(uint8 value, uint16 count, far void *ptr)
.proc std_memset
begin_locals
    decl_local count, 2
begin_args_nearcall
    decl_arg ptr, 3

    enter __FRAME_SIZE__

    sty count
    txa

    ; TODO(tachiweasel): Use the block move instruction.
    ldy #0
    bra :+
@loop:
    sta [ptr],y
    iny
:   cpy count
    bne @loop

    leave __FRAME_SIZE__
    rts
.endproc

.export std_memset

; nearproc uint16 _ff6vwf_mul8(uint8 a, uint8 b)
.proc std_mul8
    txa
    sta f:WRMPYA
    tya
    sta f:WRMPYB

    ; 8 cycle delay
    nopx 3
    a16

    lda f:RDMPYL
    tax
    a8
    rts
.endproc

.export std_mul8

; nearproc uint16 _ff6vwf_mul16_8(uint16 a, uint8 b)
;   hi(BC)
;   A         B
; x           C
; ------------------
;   AC+hi(BC) lo(BC)

; let d = b * lo8(a)
; let e = (b*hi8(a) + hi8(d)) << 8
; lo8(d) + e
.proc std_mul16_8
begin_locals
    decl_local tmp_d, 2

    enter __FRAME_SIZE__

    tya
    sta f:WRMPYA    ; b
    txa
    sta f:WRMPYB    ; multiply by lo8(a)
    nopx 3
    a16             ; 8 cycle delay
    lda f:RDMPYL    ; a = d = b * lo8(a)
    sta tmp_d
    txa             ; A = a
    xba             ; lo8(A) = hi8(a)
    a8
    sta f:WRMPYB    ; multiply by hi8(a)
    nopx 2
    lda tmp_d       ; lo8(d)
    xba             ; 8 cycle delay; hi8(A) = lo8(d)
    lda f:RDMPYL    ; b*hi8(a)
    add tmp_d+1     ; b*hi8(a) + hi8(d)
    xba             ; swap high and low bytes; high is now b*hi8(a) + hi8(d); low is now lo8(d)
    a16
    tax
    a8

    leave __FRAME_SIZE__
    rts
.endproc

.export std_mul16_8

; nearproc uint16 std_mod16_8(uint16 a, uint8 b)
;
; Computes a % b.
.proc std_mod16_8
    txa
    sta f:WRDIVL
    xba
    sta f:WRDIVH
    tya
    sta f:WRDIVB

    ; 16 cycle delay
.repeat 7
    nop
.endrepeat
    a16

    lda f:RDMPYL
    tax
    a8
    rts
.endproc

.export std_mod16_8
