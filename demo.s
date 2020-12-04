; snes-vwf/demo.s
;
; Demo/test program for variable-width font engine

.p816
.i16
.a8
.feature c_comments

.include "snes.inc"

.export vwf_tile_image_offset: far  = $7f0004
.export vwf_tile_image_base: far    = $7f0006
.export vwf_tiles_4bpp: far
.export vwf_charmap: far
.import vwf_render_string: far

.segment "HEADER"        ; +$7FE0 in file
    .byte "VWF DEMO    " ; ROM name

.segment "ROMINFO"       ; +$7FD5 in file
    .byte $30            ; LoROM, fast-capable
    .byte 0              ; no battery RAM
    .byte $07            ; 128K ROM
    .byte 0,0,0,0
    .word $AAAA,$5555    ; dummy checksum and complement

.segment "VECTORS"
    .word 0, 0, 0, 0, 0, 0, 0, 0
    .word 0, 0, 0, 0, 0, 0, reset, 0

.segment "TEXT"

reset:
    clc             ; native mode
    xce
    rep #$10        ; X/Y 16-bit
    a8

    ; Clear PPU registers
    ldx #$33
:   stz INIDISP,x
    stz NMITIMEN,x
    dex
    bpl :-

    ; Force blank
    lda #$80
    sta INIDISP

    ; Set colors
    stz CGADD
    stz CGDATA
    stz CGDATA
    lda #%11111000
    sta CGDATA
    lda #0
    sta CGDATA
    lda #$ff
    ldx #253
:   sta CGDATA
    sta CGDATA
    dex
    bne :-

    ; Mode 0
    stz BGMODE
    stz BG1SC
    lda #$03
    sta BG12NBA     ; tileset at $3000
    lda #$01
    sta TM

    ; Upload tile map
    lda #$80
    sta VMAIN
    ldx #32 * 2
    stx VMADDL
    ldx #0
:   stx VMDATAL
    inx
    cpx #256
    bne :-

    ; Render string
    lda #^string
    pha
    ldx #.loword(string)
    phx
    lda #^vwf_tile_image_base
    pha
    ldx #.loword(vwf_tile_image_base)
    phx
    jsl vwf_render_string
    ply
    ply
    ply

    ; Calculate size.
    a16
    txa
    sub #.loword(vwf_tile_image_base)
    tay
    a8

    ; Upload character data
    lda #$80
    sta VMAIN
    ldx #$3000
    stx VMADDL
    lda #$01
    sta DMAP0
    lda #<VMDATAL
    sta BBAD0
    ldx #.loword(vwf_tile_image_base)
    stx A1T0L
    lda #^vwf_tile_image_base
    sta A1B0
    sty DAS0L       ; size to transfer
    lda #$01
    sta MDMAEN

    ; Maximum screen brightness
    lda #$0F
    sta INIDISP

forever:
    wai
    jmp forever

vwf_tiles_4bpp:
    .byte 0

; Character map
vwf_charmap:
.repeat 256, i
    .byte i
.endrepeat

string:
    .asciiz "Hello world!"
