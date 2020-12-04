; snes-vwf/vwf.s
;
; Variable-width font engine for the SNES.
;
; Only supports small one-tile-high fonts, but could be extended to support more.

.p816
.i16
.a8
.feature c_comments

.include "snes.inc"

.export vwf_render_string: far

.segment "TEXT"

; farproc chardata near *vwf_render_string(chardata far *dest_ptr, const char far *string_ptr)
;
; Renders a null-terminated ASCII string to the tiles at `dest_ptr`. Returns the address of the end
; tile (the tile one past the end of the last one we rendered to).
.proc vwf_render_string
outgoing_args       = $00   ; 7 bytes
tile_sub_x          = $07   ; uint8
current_glyph       = $08   ; uint8
glyph_image_ptr     = $09   ; const chardata far *
shadow_buffer       = $0c   ; uint8; stores last column to be carried over into shadow of next tile
glyph_canvas        = $0d   ; chardata[16]
FRAME_SIZE          = $1d
FIRST_ARG           = FRAME_SIZE + $05
dest_ptr            = FIRST_ARG + $00   ; chardata far *
string_ptr          = FIRST_ARG + $03   ; const char far *

    enter FRAME_SIZE

    ; Init local variables.
    lda #^glyph_images
    sta glyph_image_ptr+2  ; bank byte
    lda #0
    sta tile_sub_x
    sta shadow_buffer

    ; Clear out our tiles.
    a16
    lda #0
    ldx #0
:   sta glyph_canvas,x
    inx
    inx
    cpx #16
    bne :-
    a8

@render_glyph:
    ; Load next character, done if we reached null.
    lda [string_ptr]
    a16
    inc string_ptr
    and #$00ff
    a8
    beq @finished

    ; Translate character ID to glyph ID and save it.
    sub #32
    sta current_glyph

    ; Calculate glyph image pointer.
    a16
    asli 3
    add #.loword(glyph_images)
    sta glyph_image_ptr

    ; Draw rows.
    ldy #0
@draw_glyph_row:
    ; Load glyph row.
    lda tile_sub_x
    and #$00ff
    tax                     ; X = tile sub X
    lda [glyph_image_ptr],y
    and #$00ff
    xba                     ; Move glyph row to high byte.

    ; Shift glyph row over.
    cpx #0
@shift_glyph:
    beq :+
    lsr
    dex
    bra @shift_glyph
:

    ; Write glyph row.
    tyx
    a8
    ora z:glyph_canvas+8,x  ; Little-endian, so low byte is 2nd glyph tile.
    sta z:glyph_canvas+8,x
    xba
    ora z:glyph_canvas,x
    sta z:glyph_canvas,x
    a16
    iny
    cpy #8
    bne @draw_glyph_row

    ; Fetch glyph width.
    lda current_glyph
    and #$00ff
    tax
    a8
    lda f:glyph_widths,x

    ; Advance tile sub-X.
    add tile_sub_x
    sta tile_sub_x

    ; Flush tile if necessary.
    sub #8
    bcc :+
    sta tile_sub_x
    a16
    tdc
    add #shadow_buffer
    sta outgoing_args+5         ; uint8_t near *shadow_buffer
    tdc
    add #glyph_canvas
    sta outgoing_args+3         ; chardata near *src
    lda dest_ptr
    sta outgoing_args+0         ; chardata far *dest
    a8
    lda dest_ptr+2
    sta outgoing_args+2
    jsr _vwf_flush_tile_image
    stx dest_ptr
:

    ; Next glyph.
    jmp @render_glyph

@finished:
    ; Flush last tile if necessary.
    lda tile_sub_x
    beq :+
    a16
    tdc
    add #shadow_buffer
    sta outgoing_args+5         ; uint8_t near *shadow_buffer
    tdc
    add #glyph_canvas
    sta outgoing_args+3         ; chardata near *src
    lda dest_ptr
    sta outgoing_args+0         ; chardata far *dest
    a8
    lda dest_ptr+2
    sta outgoing_args+2
    jsr _vwf_flush_tile_image
    stx dest_ptr
:

    ; Return new pointer in X.
    ldx dest_ptr

    leave FRAME_SIZE
    rtl
.endproc

; near *_vwf_flush_tile_image(tiledata far *dest_ptr,
;                             tiledata near *src_ptr,
;                             uint8 near *shadow_buffer_ptr)
;
; Returns the new destination pointer.
.proc _vwf_flush_tile_image
last_row_image      = $00
last_col_image      = $01
FRAME_SIZE          = $02
FIRST_ARG           = FRAME_SIZE + $04
dest_ptr            = FIRST_ARG + $00
src_ptr             = FIRST_ARG + $03
shadow_buffer_ptr   = FIRST_ARG + $05

    enter FRAME_SIZE

    ; Initialize last row and column image.
    lda (shadow_buffer_ptr)
    sta last_col_image
    lda #0
    sta last_row_image

    ; Enter main loop.
    ldx #8
    ldy #8

    ; Bitplane 0 includes shadow from previous row.
@flush_row:
    lda (src_ptr)
    ora last_row_image
    sta [dest_ptr]
    a16
    inc z:dest_ptr
    a8

    ; Bitplane 1 has no shadow.
    lda (src_ptr)
    sta [dest_ptr]

    ; Generate shadow for next row.
    lsr                 ; Put last bit in carry
    rol last_col_image  ; Move to next line, saving our bit in carry
    lda (src_ptr)       ; Reload
    ror                 ; Shift right, taking bit from previous column
    sta last_row_image  ; Store in new row

    ; Move to next pointer.
    a16
    inc z:dest_ptr
    a8

    lda (src_ptr),y
    sta (src_ptr)       ; Move back.

    lda #0
    sta (src_ptr),y     ; Clear out.
    a16
    inc z:src_ptr
    a8
    dex
    bne @flush_row

    ; Save last column in shadow buffer.
    lda last_col_image
    sta (shadow_buffer_ptr)

    ; Return the new dest pointer in X.
    ldx z:dest_ptr

    leave FRAME_SIZE
    rts

.endproc

; for debugging
.export _vwf_flush_tile_image

.include "font.inc"
