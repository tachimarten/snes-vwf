; snes-vwf/ff6vwf.s
;
; Final Fantasy 6 variable-width font patch

.p816
.i16
.a8
.feature c_comments

.include "snes.inc"

.segment "BASETEXT"
.incbin "ff6.smc"

; Patches to Final Fantasy 6 functions

; FF6 routine that draws an enemy name during encounters. We patch it to support variable-width
; fonts.
.segment "PTEXTDRAWENEMYNAME"
    jsl _ff6vwf_encounter_draw_enemy_name
    rts

; FF6 routine that performs large DMA during encounters, part of the NMI/VBLANK handler. We patch
; it to upload our text if needed.
.segment "PTEXTENCOUNTERDMA"
    jml _ff6vwf_encounter_dma    ; 4 bytes

; This FF6 function restores the normal BG3 font by copying it from the ROM after a dialogue-style
; text box in an encounter has closed. We have to patch it to restore any enemy names we created.
.segment "PTEXTRESTORESMALLFONT"
ff6_encounter_schedule_dma = $198d
    jsl _ff6vwf_encounter_restore_small_font
    rts

; Wraps FF6's "schedule DMA" function in a far call.
_ff6vwf_encounter_schedule_dma_trampoline:
    jsr ff6_encounter_schedule_dma
    rtl

; Our own functions, in a separate bank
.segment "TEXT"

; Globals

; Which lines of text need to be uploaded to VRAM. The appropriate bit is set to 1 if the line of
; text needs to be uploaded.
ff6vwf_pending_text_lines = $3f6200
; Space for 4 lines of text, 16 tiles (256 bytes) each to be stored. These are uploaded to VRAM
; if the corresponding bit in `ff6vwf_pending_text_lines` are set.
ff6vwf_text_tiles = $3f6210

.import vwf_render_string: far

; farproc void _ff6vwf_encounter_draw_enemy_name(register Y: uint16 tilemap_offset)
;
; Draws an enemy name during an encounter using our small variable-width font.
.proc _ff6vwf_encounter_draw_enemy_name
outgoing_args = $00         ; 6 bytes
string_ptr = $06            ; far *
enemy_index = $09           ; byte
enemy_name_tiles = $0a      ; chardata far *
dest_tilemap_offset = $0d   ; uint16, on entry to function, this is Y
display_list_ptr = $0f      ; char *, FF6's display list pointer, $7e0048
tiles_to_draw = $11         ; uint8
current_tile_index = $12    ; char
FRAME_SIZE = $13

ff6_enemy_ids         = $7e200d
ff6_enemy_name_offset = $7e0026
ff6_enemy_name_table  = $cfc050
ff6_display_list_ptr  = $7e0048
ff6_tiles_to_draw     = $7e0010

    enter FRAME_SIZE

    ; Initialize locals.
    sty dest_tilemap_offset
    a16
    lda ff6_display_list_ptr
    sta display_list_ptr
    a8
    lda #10
    sta tiles_to_draw

    a16
    inc display_list_ptr        ; Go to the next byte.
    a8
    lda (display_list_ptr)
    sta enemy_index
    a16
    and #$00ff
    asl
    tax
    lda ff6_enemy_ids,x         ; fetch enemy ID
    cmp #$ffff
    a8
    bne @name_not_empty

    ; Fill with blanks.
    inc tiles_to_draw
    ldx dest_tilemap_offset
:   stx outgoing_args+1         ; dest_tilemap_offset
    lda #$ff                    ; space
    sta outgoing_args+0         ; tile_to_draw
    jsr _ff6vwf_encounter_draw_tile
    dec tiles_to_draw
    bne :-
    stx dest_tilemap_offset
    jmp @return

@name_not_empty:
    a16
    asl
    tax
    lda f:ff6vwf_long_enemy_names,x
    tay
    a8

    ; Compute dest pointer.
    lda #^ff6vwf_text_tiles
    sta z:enemy_name_tiles+2
    lda enemy_index
    a16
    and #$00ff
    xba
    add #.loword(ff6vwf_text_tiles) ; Dest: ff6vwf_text_tiles[enemy index * 256]
    sta z:enemy_name_tiles
    a8

    ; Draw the string.
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+5
    sty outgoing_args+3     ; string_ptr
    lda #^ff6vwf_text_tiles
    sta outgoing_args+2
    ldy z:enemy_name_tiles
    sty outgoing_args+0     ; dest_ptr 
    jsl vwf_render_string

    ; X now contains the pointer to the end of the enemy name tiles we rendered. Fill in remaining
    ; tiles with blanks.
    a16
    txa
    sec
    sbc z:enemy_name_tiles                  ; Compute how many bytes were written.
    tay
    lda #0
:   cpy #10*8*2
    bcs :+
    sta [enemy_name_tiles],y
    iny
    iny
    bra :-
:

    ; Set the flag to tell NMI we need to copy a name.
    lda enemy_index
    and #$00ff
    tax
    a8
    lda #1
    cpx #0
:   beq :+
    asl
    dex
    bra :-
:   ora f:ff6vwf_pending_text_lines
    sta f:ff6vwf_pending_text_lines

    lda enemy_index
    asli 4
    add #$40                ; Start at tile $40 + $10 * enemy_index.
    sta current_tile_index
    ldx dest_tilemap_offset
:   stx outgoing_args+1     ; dest_tilemap_offset
    lda current_tile_index
    sta outgoing_args+0     ; tile_to_draw
    jsr _ff6vwf_encounter_draw_tile
    inc current_tile_index
    dec tiles_to_draw
    bne :-

    ; Maybe the number of enemies in the J version got replaced with this?
    stx outgoing_args+1
    lda #$ff                ; space
    sta outgoing_args+0     ; tile_to_draw
    jsr _ff6vwf_encounter_draw_tile
    stx dest_tilemap_offset

@return:
    ; Put locals back where FF6 expects them.
    a16
    lda display_list_ptr
    sta ff6_display_list_ptr
    a8
    lda tiles_to_draw
    sta ff6_tiles_to_draw

    ldy dest_tilemap_offset
    leave FRAME_SIZE
    ; NB: It is important that the high byte of A be 0 upon return! FF6 will glitch otherwise.
    a16
    lda #0
    a8
    rtl
.endproc

; uint16 _ff6vwf_encounter_draw_tile(char tile, uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_tile
dest_tilemap_main   = $00               ; tiledata near *, $00004c
dest_tilemap_extra  = $02               ; tiledata near *, $00004a
FRAME_SIZE          = $04
FIRST_ARG           = FRAME_SIZE + $04
tile_to_draw        = FIRST_ARG
dest_tilemap_offset = FIRST_ARG + $01

ff6_dest_tilemap_main    = $7e004c
ff6_dest_tilemap_extra   = $7e004a
ff6_dest_tile_attributes = $7e004e

    enter FRAME_SIZE
    a16
    lda ff6_dest_tilemap_main
    sta dest_tilemap_main
    lda ff6_dest_tilemap_extra
    sta dest_tilemap_extra
    a8

    ldy dest_tilemap_offset
    lda tile_to_draw
    sta (dest_tilemap_main),y
    lda #$ff
    sta (dest_tilemap_extra),y
    iny
    lda ff6_dest_tile_attributes
    sta (dest_tilemap_main),y
    sta (dest_tilemap_extra),y
    iny

    tyx
    leave FRAME_SIZE
    rts
.endproc

; For debugging
.export _ff6vwf_encounter_draw_enemy_name

; farproc void _ff6vwf_encounter_restore_small_font()
;
; A patched version of the "restore small font" function that reuploads the BG3 text from the ROM
; after a text box closes during an encounter. We simply set all bits to tell our custom NMI
; routine to start reuploading when it gets a chance.
.proc _ff6vwf_encounter_restore_small_font
    ; Do the stuff the original function did.
    ldx #$1000
    stx $10
    ldx #$7fc0      ; address of graphics in ROM
    ldy #$5800      ; VRAM address / 2
    lda #$c4        ; bank
    jsl _ff6vwf_encounter_schedule_dma_trampoline

    ; Now go ahead and set all our text line bits to reupload everything.
    lda #$0f
    sta f:ff6vwf_pending_text_lines

    rtl
.endproc

; A patched version of the "large DMA" encounter routine at $C1196F that adds in any DMA we need to
; do.
;
; This does not use any particular calling convention, because it's really more of a patch to the
; DMA logic than a function.
.proc _ff6vwf_encounter_dma
ff6_dma_size_to_transfer = $36
ff6_large_dma_enabled = $8000

    ; Check to see if FF6 wants to do a large DMA. If it does, yield to it and try again next
    ; frame. We don't want to risk running out of VBLANK time.
    lda ff6_large_dma_enabled   ; Large DMA enabled?
    beq @no_large_dma
    jml $c11974                 ; Yield back to FF6.

@no_large_dma:
    ; Any text lines to upload?
    lda ff6vwf_pending_text_lines
    beq @done

    ; Find the first pending text line.
    sta ff6_dma_size_to_transfer    ; Will be overwritten, so just use it as scratch space
    lda #1
    ldx #0
:   bit ff6_dma_size_to_transfer
    bne @upload_text_line
    asl
    inx
    bra :-

@upload_text_line:
    ; Now X contains the text line index and A its bitmask. First, clear the pending enemy bit.
    eor #$ff
    and ff6_dma_size_to_transfer
    sta ff6vwf_pending_text_lines

    ; Load source and destination into X and Y respectively.
    a16
    txa
    xba
    lsr     ; text line index * 128
    add #$b400/2
    tay
    txa
    xba     ; text line index * 256
    add #.loword(ff6vwf_text_tiles)
    tax

    ; Call FF6's routine (by jumping into the large DMA function; we're in a different bank, so JSL
    ; would crash).
    a8
    lda #10*2*8
    sta ff6_dma_size_to_transfer    ; Size to transfer: 10 tiles' worth
    lda #^ff6vwf_text_tiles
    jml $c11982

@done:
    jml $c11988

.endproc

; For debugging
.export _ff6vwf_encounter_dma

.segment "DATA"

.include "enemy-names.inc"
