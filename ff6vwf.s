; snes-vwf/ff6vwf.s
;
; Final Fantasy 6 variable-width font patch

.p816
.i16
.a8
.feature c_comments

.include "snes.inc"

.import vwf_render_string: far

; Constants

; Character index where we start the small variable width font.
VWF_TILE_BASE = $10
; Address in VRAM where characters begin, for BG3 during encounters.
VWF_TILE_BASE_ADDR = $b000 + (VWF_TILE_BASE << 4)
; Number of text lines we can store in VRAM at one time.
VWF_SLOT_COUNT = 7

; FF6 globals

ff6_encounter_enemy_ids = $7e200d

.segment "XBSSENCOUNTER"

; Stack of DMA structures. They look like:
;
; struct dma {
;     void vram *dest_vram_addr;    // word address
;     void near *src_addr;          // our address
; };
;
; Number of bytes to be transferred is currently always 160.
ff6vwf_text_dma_stack_base: .res 4 * VWF_SLOT_COUNT
; Buffer space for the lines of text, 16 tiles (256 bytes) each to be stored, ready to be uploaded
; to VRAM.
ff6vwf_text_tiles: .res 256 * VWF_SLOT_COUNT
; Current of the stack *in bytes*.
ff6vwf_text_dma_stack_ptr: .res 1
; ID of the current item slot we're drawing.
ff6vwf_current_item_slot: .res 1
; What type of item we're drawing.
ff6vwf_item_type_to_draw: .res 1

FF6VWF_ITEM_TYPE_INVENTORY    = 0
FF6VWF_ITEM_TYPE_ITEM_IN_HAND = 1

; Patches to Final Fantasy 6 functions

; Encounter setup. We patch it to initialize our DMA stack.
.segment "PTEXTINITENCOUNTER"
    jml _ff6vwf_encounter_init

; FF6 routine that draws an enemy name during encounters. We patch it to support variable-width
; fonts.
.segment "PTEXTDRAWENEMYNAME"
    jsl _ff6vwf_encounter_draw_enemy_name
    rts

; FF6 routine that builds a menu item for an item in inventory. We patch it to record what
; inventory slot number it was so that the VWF rendering routine can figure out what text slot to
; use in order to avoid collisons.
.segment "PTEXTBUILDMENUITEMFORITEM"
    jml _ff6vwf_encounter_build_menu_item_for_item          ; 4 bytes

; FF6 routine that builds a menu item for an equipped item in hand (during encounters). We patch it
; to record that this is an item in hand so that the VWF rendering routine can use the appropriate
; slot.
.segment "PTEXTBUILDMENUITEMFORITEMINHAND"
    jml _ff6vwf_encounter_build_menu_item_for_item_in_hand  ; 4 bytes

; FF6 routine to draw an item name during encounters.
.segment "PTEXTDRAWITEMNAME"
    jsl _ff6vwf_encounter_draw_item_name
    rts

; Part of the FF6 NMI/VBLANK handler. We patch it to upload our text if needed.
.segment "PTEXTENCOUNTERRUNDMA"
    jml _ff6vwf_encounter_run_dma           ; 4 bytes

; FF6 function that restores the normal BG3 font by copying it from the ROM after a dialogue-style
; text box in an encounter has closed. We have to patch it to reupload any enemy names we created
; to VRAM.
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

; farproc void _ff6vwf_encounter_init()
.proc _ff6vwf_encounter_init
    lda #0
    sta ff6vwf_text_dma_stack_ptr
    jsl $c00016 ; original code
    jml $c1102e
.endproc

; farproc void _ff6vwf_encounter_draw_enemy_name(uint16 unused, uint16 tilemap_offset)
;
; Draws an enemy name during an encounter using our small variable-width font.
.proc _ff6vwf_encounter_draw_enemy_name
begin_locals
    decl_local outgoing_args, 6
    decl_local string_ptr, 3                ; char far *
    decl_local enemy_index, 1               ; uint8
    decl_local enemy_name_tiles, 3          ; chardata far *
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local display_list_ptr, 2          ; char near *
    decl_local tiles_to_draw, 1             ; uint8
    decl_local current_tile_index, 1        ; char

ff6_tiles_to_draw     = $7e0010
ff6_display_list_ptr  = $7e0048
ff6_enemy_name_offset = $7e0026
ff6_enemy_name_table  = $cfc050

    enter __FRAME_SIZE__

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
    lda ff6_encounter_enemy_ids,x   ; fetch enemy ID
    cmp #$ffff
    a8
    bne @name_not_empty

    ; Fill with blanks.
    inc tiles_to_draw
    ldx dest_tilemap_offset
:   txy                         ; dest_tilemap_offset
    ldx #$ffff                  ; space
    jsr _ff6vwf_encounter_draw_enemy_name_tile
    dec tiles_to_draw
    bne :-
    stx dest_tilemap_offset
    jmp @return

@name_not_empty:
    ; Put source pointer in Y.
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
    stx outgoing_args+0     ; ptr
    lda enemy_name_tiles+2
    sta outgoing_args+2     ; ptr, bank byte
    a16
    txa
    sub #10*8*2
    sub z:enemy_name_tiles
    neg16                   ; -(X - 10*8*2 - enemy_name_tiles) == 10*8*2 - (X - enemy_name_tiles)
    tay                     ; count
    a8
    ldx #0                  ; value
    jsr _ff6vwf_memset

    ldx enemy_index
    jsr _ff6vwf_encounter_schedule_text_dma

    lda enemy_index
    asli 4
    add #VWF_TILE_BASE      ; Start at tile $10 + $10 * enemy_index.
    sta current_tile_index
    ldx dest_tilemap_offset
:   txy                     ; dest_tilemap_offset
    ldx current_tile_index  ; tile_to_draw
    jsr _ff6vwf_encounter_draw_enemy_name_tile
    inc current_tile_index
    dec tiles_to_draw
    bne :-

    ; Maybe the number of enemies in the J version got replaced with this?
    txy                     ; dest_tilemap_offset
    ldx #$ffff              ; tile_to_draw = space
    jsr _ff6vwf_encounter_draw_enemy_name_tile
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
    leave __FRAME_SIZE__
    ; NB: It is important that the high byte of A be 0 upon return! FF6 will glitch otherwise.
    a16
    lda #0
    a8
    rtl
.endproc

.proc _ff6vwf_encounter_build_menu_item_for_item
    sta f:ff6vwf_current_item_slot
    pha
    lda #FF6VWF_ITEM_TYPE_INVENTORY
    sta f:ff6vwf_item_type_to_draw
    pla

    ; Stuff the original function did
    phy
    a16
    sta $40
    asli 2
    add $40
    tay
    jml $c14c76
.endproc

; Original function: $c14bba.
.proc _ff6vwf_encounter_build_menu_item_for_item_in_hand
.a8
    lda #0 
    sta f:ff6vwf_current_item_slot
    lda #FF6VWF_ITEM_TYPE_ITEM_IN_HAND
    sta f:ff6vwf_item_type_to_draw

    ; Stuff the original function did
    tdc
    tax
:   lda $c14bac,x
    sta $5755,x
    inx 
    cpx #$13
    bne :-
    jml $c14bc9
.endproc

.proc _ff6vwf_encounter_draw_item_name
begin_locals
    decl_local outgoing_args, 7
    decl_local item_name_tiles, 3           ; chardata far *
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local tiles_to_draw, 1             ; uint8
    decl_local current_tile_index, 1        ; char
    decl_local item_slot, 1                 ; uint8
    decl_local item_name_ptr, 2             ; char near *
    decl_local dest_tiles_main, 2           ; tiledata near *
    decl_local dest_tiles_extra, 2          ; tiledata near *
    decl_local item_id, 1                   ; uint8

ff6_short_item_names   = $d2b300
ff6_dest_tiles_main    = $7e0053
ff6_dest_tiles_extra   = $7e0051
ff6_display_list_ptr   = $7e004f
ff6_item_in_hand_left  = $7e575a
ff6_item_in_hand_right = $7e5760

    enter __FRAME_SIZE__

    ; Initialize locals.
    sty dest_tilemap_offset
    lda #12
    sta tiles_to_draw
    a16
    lda ff6_display_list_ptr
    sta item_name_ptr
    lda ff6_dest_tiles_main
    sta dest_tiles_main
    lda ff6_dest_tiles_extra
    sta dest_tiles_extra

    ; Figure out what text slot we're going to use.
    a8
    lda ff6vwf_item_type_to_draw
    cmp #FF6VWF_ITEM_TYPE_ITEM_IN_HAND
    beq @item_in_hand

    ; Item in inventory. Use slot `item_slot % 5`, because the item menu shows 4 items, plus an
    ; extra that partially appears during scrolling.
    lda ff6vwf_current_item_slot
    a16
    and #$00ff
    a8
    tax
    ldy #5
    jsr _ff6vwf_mod16_8
    txa
    bra @write_item_slot

@item_in_hand:
    ; Item in hand:
    ldx item_name_ptr
    cpx #.loword(ff6_item_in_hand_right)
    beq :+
    lda #5                  ; Use slot 5 for left-hand item.
    bra @write_item_slot
:   lda #6                  ; Use slot 6 for right-hand item.
@write_item_slot:
    sta item_slot

    ; Fetch item ID.
    lda (item_name_ptr)
    sta item_id

    ; Draw item icon.
    tax
    ldy #13
    jsr _ff6vwf_mul8
    lda ff6_short_item_names,x
    tax                     ; tile_to_draw
    ldy dest_tilemap_offset
    jsr _ff6vwf_encounter_draw_item_name_tile
    stx dest_tilemap_offset

    ; Put item long name pointer in Y.
    lda item_id
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_item_names,x
    tay
    a8

    ; Compute dest pointer.
    lda #^ff6vwf_text_tiles
    sta z:item_name_tiles+2
    lda item_slot
    a16
    and #$00ff
    xba
    add #.loword(ff6vwf_text_tiles) ; Dest: ff6vwf_text_tiles[item_slot * 256]
    sta z:item_name_tiles
    a8

    ; Render string.
    lda #^ff6vwf_long_item_names
    sta outgoing_args+5
    sty outgoing_args+3     ; string_ptr
    lda #^ff6vwf_text_tiles
    sta outgoing_args+2
    ldy z:item_name_tiles
    sty outgoing_args+0     ; dest_ptr 
    jsl vwf_render_string

    ; X now contains the pointer to the end of the item name tiles we rendered. Fill in remaining
    ; tiles with blanks.
    stx outgoing_args+0     ; ptr
    lda item_name_tiles+2
    sta outgoing_args+2     ; ptr, bank byte
    a16
    txa
    sub #16*8*2
    sub z:item_name_tiles
    neg16                   ; -(X - 16*8*2 - item_name_tiles) == 16*8*2 - (X - item_name_tiles)
    tay                     ; count
    a8
    ldx #0                  ; value
    jsr _ff6vwf_memset

    ldx item_slot
    jsr _ff6vwf_encounter_schedule_text_dma

    lda item_slot
    asli 4
    add #VWF_TILE_BASE      ; Start at tile $10 + $10 * item_slot.
    sta current_tile_index
    ldx dest_tilemap_offset
:   txy                     ; dest_tilemap_offset
    lda current_tile_index
    inc current_tile_index
    tax                     ; tile_to_draw
    jsr _ff6vwf_encounter_draw_item_name_tile
    dec tiles_to_draw
    bne :-
    stx dest_tilemap_offset

    ; Restore stuff to where FF6 expects it.
    a16
    lda dest_tiles_main
    sta ff6_dest_tiles_main
    lda dest_tiles_extra
    sta ff6_dest_tiles_extra
    a8
    ldy dest_tilemap_offset

    leave __FRAME_SIZE__
    rtl
.endproc

; uint16 _ff6vwf_encounter_draw_enemy_name_tile(char tile, uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_enemy_name_tile
begin_locals
    decl_local dest_tilemap_main, 2     ; tiledata near * ($7e004c)
    decl_local dest_tilemap_extra, 2    ; tiledata near * ($7e004a)

ff6_dest_tilemap_main    = $7e004c
ff6_dest_tilemap_extra   = $7e004a
ff6_dest_tile_attributes = $7e004e

    enter __FRAME_SIZE__
    a16
    lda ff6_dest_tilemap_main
    sta dest_tilemap_main
    lda ff6_dest_tilemap_extra
    sta dest_tilemap_extra
    a8

    txa                             ; tile to draw
    sta (dest_tilemap_main),y
    lda #$ff
    sta (dest_tilemap_extra),y
    iny
    lda ff6_dest_tile_attributes
    sta (dest_tilemap_main),y
    sta (dest_tilemap_extra),y
    iny

    tyx
    leave __FRAME_SIZE__
    rts
.endproc

; uint16 _ff6vwf_encounter_draw_item_name_tile(char tile, uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_item_name_tile
begin_locals
    decl_local dest_tilemap_main, 2     ; tiledata near * ($7e0053)
    decl_local dest_tilemap_extra, 2    ; tiledata near * ($7e0051)

ff6_dest_tilemap_main    = $7e0053
ff6_dest_tilemap_extra   = $7e0051
ff6_extra_tile           = $7e0055
ff6_dest_tile_attributes = $7e0056

    enter __FRAME_SIZE__
    a16
    lda ff6_dest_tilemap_main
    sta dest_tilemap_main
    lda ff6_dest_tilemap_extra
    sta dest_tilemap_extra
    a8

    txa                             ; tile_to_draw
    sta (dest_tilemap_main),y
    lda ff6_extra_tile
    sta (dest_tilemap_extra),y
    iny
    lda ff6_dest_tile_attributes
    sta (dest_tilemap_main),y
    sta (dest_tilemap_extra),y
    iny

    tyx
    leave __FRAME_SIZE__
    rts
.endproc

; For debugging
.export _ff6vwf_encounter_draw_enemy_name
.export _ff6vwf_encounter_build_menu_item_for_item
.export _ff6vwf_encounter_draw_item_name

; farproc void _ff6vwf_encounter_restore_small_font()
;
; A patched version of the "restore small font" function that reuploads the BG3 text from the ROM
; after a text box closes during an encounter. We simply set all bits to tell our custom NMI
; routine to start reuploading when it gets a chance.
.proc _ff6vwf_encounter_restore_small_font
begin_locals
    decl_local outgoing_args, 1
    decl_local enemy_index, 1   ; uint8

ff6_dma_size_to_transfer = $10

    ; Do the stuff the original function did.
    ;
    ; Do this before the function prolog because we need the DP to be 0 when calling FF6 functions.
    ldx #$1000
    stx ff6_dma_size_to_transfer
    ldx #$7fc0      ; address of graphics in ROM
    ldy #$5800      ; VRAM address / 2
    lda #$c4        ; bank
    jsl _ff6vwf_encounter_schedule_dma_trampoline

    enter __FRAME_SIZE__

    ; Look at the monster names and schedule each one to be reuploaded if necessary.
    lda #0
    sta enemy_index
@reupload_enemy_name:
    lda enemy_index
    a16
    and #$00ff
    asl
    tax
    lda ff6_encounter_enemy_ids,x
    cmp #$ffff
    a8
    beq :+
    ldx enemy_index
    jsr _ff6vwf_encounter_schedule_text_dma
:   inc enemy_index
    lda enemy_index
    cmp #4
    blt @reupload_enemy_name

    leave __FRAME_SIZE__
    ; NB: This is necessary to avoid a crash!
    a16
    lda #0
    a8
    rtl
.endproc

; nearproc void _ff6vwf_encounter_schedule_text_dma(uint8 text_line_index)
.proc _ff6vwf_encounter_schedule_text_dma
begin_locals
    decl_local dma_stack_ptr, 3     ; uint16 far *

    enter __FRAME_SIZE__

    ; Grab the DMA stack pointer.
    ; FIXME(tachiweasel): This seems racy...
    lda #^ff6vwf_text_dma_stack_base
    sta dma_stack_ptr+2
    lda ff6vwf_text_dma_stack_ptr
    a16
    and #$00ff
    add #.loword(ff6vwf_text_dma_stack_base)
    sta dma_stack_ptr

    ; Bump the DMA stack pointer. If it overflows, bail out to avoid crashing the game.
    a8
    lda ff6vwf_text_dma_stack_ptr
    add #4
    cmp #VWF_SLOT_COUNT * 4
    bge @out
    sta ff6vwf_text_dma_stack_ptr

    ; Push our DMA on the stack.
    a16
    txa                             ; load text line index
    and #$00ff
    xba
    tax                             ; save text_line_index * 256
    lsr                             ; text_line_index * by 128
    add #VWF_TILE_BASE_ADDR/2       ; VRAM address
    sta [dma_stack_ptr]             ; write VRAM address
    inc dma_stack_ptr
    inc dma_stack_ptr
    txa
    add #.loword(ff6vwf_text_tiles) ; src address
    sta [dma_stack_ptr]
    a8

@out:
    leave __FRAME_SIZE__
    rts
.endproc

; Does any DMA we need to do.
;
; This does not use any particular calling convention, because it's really more of a patch to the
; DMA logic than a function.
.proc _ff6vwf_encounter_run_dma
ff6_dma_size_to_transfer = $10

    jsl $c2a88f

    tdc
    pha
    plb

    lda STAT78
    lda SLHV
    lda OPVCT
    cmp #250        ; Don't DMA after scanline 250...
    bge @out
    ; 239 is where VBLANK begins, so anything before that in the low byte means we're at a scanline
    ; >= 256, which isn't enough time for DMA.
    cmp #239
    blt @out

@do_it:
    ; Any DMA lines to upload?
    tdc                         ; Fast clear top byte of A to 0.
    lda f:ff6vwf_text_dma_stack_ptr
    beq @out

    ; Pop it off the stack.
    sub #4
    sta f:ff6vwf_text_dma_stack_ptr
    tax
    a16
    lda f:ff6vwf_text_dma_stack_base+0,x  ; dest VRAM address
    sta VMADDL
    lda f:ff6vwf_text_dma_stack_base+2,x  ; source address
    sta A1T7L
    a8

    lda #^ff6vwf_text_tiles
    sta A1B7
    ldx #10*2*8
    stx DAS7L       ; Size to transfer: 10 tiles' worth.
    lda #1
    sta DMAP7
    lda #$18
    sta BBAD7
    lda #$80
    sta MDMAEN

@out:
    lda #$7e
    pha
    plb
    jml $c10be1

.endproc

; nearproc void _ff6vwf_memset(uint8 value, uint16 count, far void *ptr)
.proc _ff6vwf_memset
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

; nearproc uint16 _ff6vwf_mul8(uint8 a, uint8 b)
.proc _ff6vwf_mul8
    txa
    sta f:WRMPYA
    tya
    sta f:WRMPYB

    ; 8 cycle delay
    nop
    nop
    nop
    a16

    lda f:RDMPYL
    tax
    a8
    rts
.endproc

; nearproc uint16 _ff6vwf_mod16_8(uint16 a, uint8 b)
;
; Computes a % b.
.proc _ff6vwf_mod16_8
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

; For debugging
.export _ff6vwf_encounter_run_dma
.export _ff6vwf_memset

.segment "DATA"

.include "enemy-names.inc"
.include "item-names.inc"
