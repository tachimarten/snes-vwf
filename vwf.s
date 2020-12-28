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

.struct renderer
    glyph_canvas        .byte 16    ; chardata[16]
    shadow_buffer       .byte       ; uint8
    bytes_between_tiles .byte       ; uint8
.endstruct

; farproc chardata near *vwf_render_string(uint8 bytes_between_tiles,
;                                          chardata far *dest_ptr,
;                                          const char far *string_ptr)
;
; Renders a null-terminated ASCII string to the tiles at `dest_ptr`. Returns the address of the end
; tile (the tile one past the end of the last one we rendered to).
.proc vwf_render_string
begin_locals
    decl_local outgoing_args, 3
    decl_local tile_sub_x, 1                ; uint8
    decl_local current_glyph, 1             ; uint8
    decl_local glyph_image_ptr, 3           ; const chardata far *
    decl_local renderer, .sizeof(renderer)  ; struct renderer
begin_args_farcall
    decl_arg dest_ptr, 3                ; chardata far *
    decl_arg string_ptr, 3              ; const char far *

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Init local variables.
    lda #^glyph_images
    sta glyph_image_ptr+2  ; bank byte
    lda #0
    sta tile_sub_x

    ; Create renderer.
    stz z:renderer+renderer::shadow_buffer
    txa
    sta z:renderer+renderer::bytes_between_tiles

    ; Clear out our tiles.
    ; TODO(tachiweasel): Use memset.
    a16
    lda #0
    ldx #0
:   sta z:renderer+renderer::glyph_canvas,x
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
    ora z:renderer+renderer::glyph_canvas+8,x  ; Little-endian, so low byte is 2nd glyph tile.
    sta z:renderer+renderer::glyph_canvas+8,x
    xba
    ora z:renderer+renderer::glyph_canvas,x
    sta z:renderer+renderer::glyph_canvas,x
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
    blt :+
    sta tile_sub_x
    a16
    tdc
    add #renderer
    tax                         ; struct renderer near *renderer_ptr
    lda dest_ptr
    sta outgoing_args+0         ; chardata far *dest_ptr
    a8
    lda dest_ptr+2
    sta outgoing_args+2         ; dest bank
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
    add #renderer
    tax                         ; struct renderer near *renderer_ptr
    lda dest_ptr
    sta outgoing_args+0         ; chardata far *dest_ptr
    a8
    lda dest_ptr+2
    sta outgoing_args+2
    jsr _vwf_flush_tile_image
    stx dest_ptr
:

    ; Return new pointer in X.
    ldx dest_ptr

    leave __FRAME_SIZE__
    rtl
.endproc

; chardata near *_vwf_flush_tile_image(struct renderer near *renderer_ptr, chardata far *dest_ptr)
;
; Returns the new destination pointer.
.proc _vwf_flush_tile_image
begin_locals
    decl_local renderer_ptr, 2          ; struct renderer near *
    decl_local src_ptr, 2               ; chardata near *
    decl_local last_row_image, 1        ; chardata
    decl_local last_col_image, 1        ; chardata
begin_args_nearcall
    decl_arg dest_ptr, 3                ; chardata far *

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Save renderer and source pointers.
    stx renderer_ptr
    stx src_ptr

    ; Initialize last row and column image.
    ldy #renderer::shadow_buffer
    lda (renderer_ptr),y
    sta last_col_image
    stz last_row_image

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
    ldy #renderer::shadow_buffer
    sta (renderer_ptr),y

    ; Pad out with zeroes to fill `bytes_between_tiles`.
    ldy #renderer::bytes_between_tiles
    lda (renderer_ptr),y
    a16
    and #$00ff
    tax
    a8
    ldy #0
    lda #0
    cpx #0
:   beq :+
    sta [dest_ptr],y
    iny
    dex
    bra :-
:

    ; Return the new dest pointer in X.
    ldy #renderer::bytes_between_tiles
    lda (renderer_ptr),y
    a16
    and #$00ff
    add dest_ptr
    tax
    a8

    leave __FRAME_SIZE__
    rts

.endproc

.include "font.inc"
