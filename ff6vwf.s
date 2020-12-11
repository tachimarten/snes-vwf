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
VWF_ENCOUNTER_TILE_BASE_ADDR = $b000 + (VWF_TILE_BASE << 4)
; Address in VRAM where characters begin, for BG3 on the menu.
VWF_MENU_TILE_BASE_ADDR = $c000 + (VWF_TILE_BASE << 4)
; Number of text lines we can store in VRAM at one time.
VWF_SLOT_COUNT = 7
; The maximum length of a line of text in 8-pixel tiles.
VWF_MAX_LINE_LENGTH = 10
; The maximum length of a line of text in bytes (2bpp).
VWF_MAX_LINE_BYTE_SIZE = VWF_MAX_LINE_LENGTH * 2 * 8

FF6_SHORT_ITEM_LENGTH = 13

; FF6 globals

ff6_short_item_names    = $d2b300

ff6_encounter_enemy_ids = $7e200d

.segment "XBSSENCOUNTER"

; Stack of DMA structures. They look like:
;
; struct dma {
;     void vram *dest_vram_addr;    // word address
;     void near *src_addr;          // our address
; };
;
; Number of bytes to be transferred is currently always `VWF_MAX_LINE_BYTE_SIZE`.
ff6vwf_text_dma_stack_base: .res 4 * VWF_SLOT_COUNT
; Buffer space for the lines of text, `VWF_MAX_LINE_LENGTH` each to be stored, ready to be uploaded
; to VRAM.
ff6vwf_text_tiles: .res VWF_MAX_LINE_BYTE_SIZE * VWF_SLOT_COUNT
; Current of the stack *in bytes*.
ff6vwf_text_dma_stack_ptr: .res 1
; ID of the current item slot we're drawing.
ff6vwf_current_item_slot: .res 1
; What type of item we're drawing.
ff6vwf_item_type_to_draw: .res 1

FF6VWF_ITEM_TYPE_INVENTORY    = 0
FF6VWF_ITEM_TYPE_ITEM_IN_HAND = 1

; Patches to Final Fantasy 6 functions

; Final Fantasy 6 encounter patches

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

; Part of the FF6 encounter NMI/VBLANK handler. We patch it to upload our text if needed.
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

; Final Fantasy 6 menu patches

.segment "PTEXTMENUINIT"
    jml _ff6vwf_menu_init

.segment "PTEXTMENULOADEQUIPMENTNAME"
ff6_menu_trigger_nmi = $1368

    jsl _ff6vwf_menu_draw_equipment_name
    rts

; Wraps FF6's "force NMI" function in a far call.
_ff6vwf_menu_force_nmi_trampoline:
    phd
    pea $0
    pld
    jsr ff6_menu_trigger_nmi
    pld
    rtl

; The "refresh screen" routine for the FF6 menu NMI/VBLANK handler. We patch it to upload our text
; if needed.
.segment "PTEXTMENURUNDMA"
    jsl _ff6vwf_menu_run_dma_setup
    jsr $d263           ; Refresh Mode 7
    jsr $1463           ; Refresh OAM
    jsr $14d2           ; Refresh CGRAM
    jsr $1488           ; Do VRAM DMA A
    ; We have priority over VRAM DMA B.
    ;
    ; For this to work, we must eagerly trigger NMI every time we render some text.
    jsl _ff6vwf_menu_run_dma
    bcs @we_did_dma

    jsr $14ac           ; Do VRAM DMA B
@we_did_dma:
    rts

; Our own functions, in a separate bank
.segment "TEXT"

; A macro that does any DMA we need to do.
;
; This is a macro because every cycle really counts. We continually run *VERY* close to running out
; of VBLANK time.
.macro _ff6vwf_run_dma dma_channel
    lda STAT78
    lda SLHV
    lda OPVCT
    cmp #250        ; Don't DMA after scanline 250...
    bge @nope
    ; 239 is where VBLANK begins, so anything before that in the low byte means we're at a scanline
    ; >= 256, which isn't enough time for DMA.
    cmp #239
    blt @nope

@do_it:
    ; Any DMA lines to upload?
    tdc                         ; Fast clear top byte of A to 0.
    lda f:ff6vwf_text_dma_stack_ptr
    beq @nope

    ; Pop it off the stack.
    sub #4
    sta f:ff6vwf_text_dma_stack_ptr
    tax
    a16
    lda f:ff6vwf_text_dma_stack_base+0,x  ; dest VRAM address
    sta VMADDL
    lda f:ff6vwf_text_dma_stack_base+2,x  ; source address
    sta A1T0L + $10*dma_channel
    a8

    lda #^ff6vwf_text_tiles
    sta A1B0 + $10*dma_channel
    ldx #VWF_MAX_LINE_BYTE_SIZE
    stx DAS0L + $10*dma_channel    ; Size to transfer.
    lda #1
    sta DMAP0 + $10*dma_channel
    lda #$18
    sta BBAD0 + $10*dma_channel
    lda #(1 << dma_channel)
    sta MDMAEN

    sec
    bra @out

@nope:
    clc

@out:
.endmacro

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
    decl_local string_ptr, 2                ; char near *
    decl_local enemy_index, 1               ; uint8
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
    ; Compute string pointer.
    a16
    asl
    tax
    lda f:ff6vwf_long_enemy_names,x
    sta string_ptr
    a8

    ; Render string.
    ldx enemy_index                     ; text_line_slot
    ldy string_ptr+0
    sty outgoing_args+0                 ; string_ptr+0
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+2                 ; string_ptr+2
    ldy #VWF_ENCOUNTER_TILE_BASE_ADDR
    jsr _ff6vwf_render_string

    ; Draw tiles.
    ldx enemy_index
    ldy #VWF_MAX_LINE_LENGTH
    jsr _ff6vwf_mul8
    txa
    add #VWF_TILE_BASE      ; Compute start tile.
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
    decl_local item_id_ptr, 2               ; uint8 near *
    decl_local dest_tiles_main, 2           ; tiledata near *
    decl_local dest_tiles_extra, 2          ; tiledata near *
    decl_local item_id, 1                   ; uint8
    decl_local string_ptr, 2                ; char near *

ff6_dest_tiles_main    = $7e0053
ff6_dest_tiles_extra   = $7e0051
ff6_display_list_ptr   = $7e004f
ff6_item_in_hand_left  = $7e575a
ff6_item_in_hand_right = $7e5760

    enter __FRAME_SIZE__

    ; Initialize locals.
    sty dest_tilemap_offset
    lda #10
    sta tiles_to_draw
    a16
    lda ff6_display_list_ptr
    sta item_id_ptr
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
    ldx item_id_ptr
    cpx #.loword(ff6_item_in_hand_right)
    beq :+
    lda #5                  ; Use slot 5 for left-hand item.
    bra @write_item_slot
:   lda #6                  ; Use slot 6 for right-hand item.
@write_item_slot:
    sta item_slot

    ; Fetch item ID.
    lda (item_id_ptr)
    sta item_id

    ; Draw item icon.
    tax
    ldy #FF6_SHORT_ITEM_LENGTH
    jsr _ff6vwf_mul8
    lda ff6_short_item_names,x
    tax                     ; tile_to_draw
    ldy dest_tilemap_offset
    jsr _ff6vwf_encounter_draw_item_name_tile
    stx dest_tilemap_offset

    ; Compute string pointer.
    lda item_id
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_item_names,x
    sta string_ptr
    a8

    ; Render string.
    ldx item_slot
    ldy string_ptr
    sty outgoing_args+0
    lda #^ff6vwf_long_item_names
    sta outgoing_args+2
    ldy #VWF_ENCOUNTER_TILE_BASE_ADDR
    jsr _ff6vwf_render_string

    ; Draw tile data.
    ldx item_slot
    ldy #VWF_MAX_LINE_LENGTH
    jsr _ff6vwf_mul8
    txa
    add #VWF_TILE_BASE      ; Compute start tile.
    sta current_tile_index
    ldx dest_tilemap_offset
:   txy                     ; dest_tilemap_offset
    lda current_tile_index
    inc current_tile_index
    tax                     ; tile_to_draw
    jsr _ff6vwf_encounter_draw_item_name_tile
    dec tiles_to_draw
    bne :-

    ; Add a couple of blank tiles on the end.
    lda #2
    sta tiles_to_draw
:   txy                     ; dest_tilemap_offset
    lda current_tile_index
    inc current_tile_index
    ldx #$ff                ; tile_to_draw
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
    ldy #VWF_ENCOUNTER_TILE_BASE_ADDR
    jsr _ff6vwf_schedule_text_dma
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

; Patch to the encounter DMA routine.
.proc _ff6vwf_encounter_run_dma
    ; Code that we overwrote.
    jsl $c2a88f

    ; Run our generic DMA routine.
    pha
    plb
    _ff6vwf_run_dma 7
    tdc
    lda #$7e
    pha
    plb

    ; Tear down.
    jml $c10be1
.endproc

; Menu functions

.proc _ff6vwf_menu_init
    jsl $d4cdf3     ; Reset many vars

    lda #0
    sta f:ff6vwf_text_dma_stack_ptr

    jml $c368fe
.endproc

.proc _ff6vwf_menu_draw_equipment_name
begin_locals
    decl_local outgoing_args, 5
    decl_local item_id, 1
    decl_local string_ptr, 2
    decl_local text_line_slot, 1

ff6_menu_positioned_text_ptr    = $7e9e89
ff6_menu_string_buffer          = $7e9e8b

    tax             ; Put item ID in X

    enter __FRAME_SIZE__

    ; Initialize locals.
    txa
    sta item_id

    ; Draw item icon.
    tax
    ldy #FF6_SHORT_ITEM_LENGTH
    jsr _ff6vwf_mul8
    lda ff6_short_item_names,x
    sta ff6_menu_string_buffer

    ; Compute string pointer.
    lda item_id
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_item_names,x
    sta string_ptr

    ; Compute text line slot.
    ;
    ; Positioned text pointer -- L-Hand: $7a1b, R-Hand: $7a9b, Helmet: $7b1b, Armor: $7b9b.
    ; So extract bits 7 and 8 to get a unique text slot.
    lda f:ff6_menu_positioned_text_ptr
    asl
    xba
    and #$03
    tax                 ; For call below.
    a8
    sta text_line_slot

    ; Render string.
    ldy string_ptr
    sty outgoing_args+0
    lda #^ff6vwf_long_item_names
    sta outgoing_args+2
    ldy #VWF_MENU_TILE_BASE_ADDR
    jsr _ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsl _ff6vwf_menu_force_nmi_trampoline 

    ; Calculate first tile index.
    ldx text_line_slot
    ldy #VWF_MAX_LINE_LENGTH
    jsr _ff6vwf_mul8
    txa
    add #VWF_TILE_BASE

    ; Draw tiles.
    ldx #1
:   sta ff6_menu_string_buffer,x
    inc
    inx
    cpx #VWF_MAX_LINE_LENGTH + 1
    bne :-

    ; Draw blanks.
    lda #$ff
:   sta ff6_menu_string_buffer,x
    inx
    cpx #FF6_SHORT_ITEM_LENGTH
    bne :-

    ; Null terminate.
    lda #0
    sta ff6_menu_string_buffer,x

    leave __FRAME_SIZE__
    rtl
.endproc

.proc _ff6vwf_menu_run_dma_setup
    stz $420c       ; Disable HDMA
    stz $420b       ; Disable DMA...
    lda $35         ; BG1 X-Pos LB
    sta $210d       ; Apply it now
    lda $36         ; BG1 X-Pos HB
    sta $210d       ; Apply it now
    lda $37         ; BG1 Y-Pos LB
    sta $210e       ; Apply it now
    lda $38         ; BG1 Y-Pos HB
    sta $210e       ; Apply it now
    lda $39         ; BG2 X-Pos LB
    sta $210f       ; Apply it now
    lda $3a         ; BG2 X-Pos HB
    sta $210f       ; Apply it now
    lda $3b         ; BG2 Y-Pos LB
    sta $2110       ; Apply it now
    lda $3c         ; BG2 Y-Pos HB
    sta $2110       ; Apply it now
    lda $3d         ; BG3 X-Pos LB
    sta $2111       ; Apply it now
    lda $3e         ; BG3 X-Pos HB
    sta $2111       ; Apply it now
    lda $3f         ; BG3 Y-Pos LB
    sta $2112       ; Apply it now
    lda $40         ; BG3 Y-Pos HB
    sta $2112       ; Apply it now
    rtl
.endproc

.proc _ff6vwf_menu_run_dma
    _ff6vwf_run_dma 0
    rtl
.endproc

.export _ff6vwf_menu_run_dma

; Utility functions specific to VWF

; nearproc void _ff6vwf_render_string(uint8 text_line_slot,
;                                     uint16 tile_base_addr,
;                                     char far *string_ptr)
.proc _ff6vwf_render_string
begin_locals
    decl_local outgoing_args, 7
    decl_local text_line_slot, 1
    decl_local text_line_chardata_ptr, 3
    decl_local tile_base_addr, 2
begin_args_nearcall
    decl_arg string_ptr, 3

    enter __FRAME_SIZE__

    ; Initialize locals.
    txa
    sta text_line_slot
    sty tile_base_addr

    ; Compute dest pointer.
    lda #^ff6vwf_text_tiles
    sta z:text_line_chardata_ptr+2
    ldx text_line_slot
    ldy #VWF_MAX_LINE_BYTE_SIZE
    jsr _ff6vwf_mul8
    a16
    txa
    add #.loword(ff6vwf_text_tiles) ; Dest: ff6vwf_text_tiles[text_line_slot * MLBS]
    sta z:text_line_chardata_ptr
    a8

    ; Render string.
    lda string_ptr+2
    sta outgoing_args+5
    ldy string_ptr+0
    sty outgoing_args+3             ; string_ptr
    lda z:text_line_chardata_ptr+2
    sta outgoing_args+2
    ldy z:text_line_chardata_ptr+0
    sty outgoing_args+0             ; dest_ptr 
    jsl vwf_render_string

    ; X now contains the pointer to the end of the tiles we rendered. Fill in remaining tiles
    ; with blanks.
    stx outgoing_args+0             ; ptr
    lda z:text_line_chardata_ptr+2
    sta outgoing_args+2             ; ptr, bank byte
    a16
    txa
    sub #VWF_MAX_LINE_BYTE_SIZE
    sub z:text_line_chardata_ptr+0
    neg16                           ; -(X - MLBS - item_name_tiles) == MLBS - (X - item_name_tiles)
    tay                             ; count
    a8
    ldx #0                          ; value
    jsr _ff6vwf_memset

    ; Schedule the upload.
    ldx text_line_slot
    ldy tile_base_addr
    jsr _ff6vwf_schedule_text_dma

    leave __FRAME_SIZE__
    rts
.endproc

; nearproc void _ff6vwf_schedule_text_dma(uint8 text_line_index, uint16 tile_base_addr)
.proc _ff6vwf_schedule_text_dma
begin_locals
    decl_local dma_stack_ptr, 3     ; uint16 far *
    decl_local tile_base_addr, 2    ; vram *

    enter __FRAME_SIZE__

    ; Save tile base address.
    sty tile_base_addr

    ; Grab the DMA stack pointer.
    ; FIXME(tachiweasel): This seems racy...
    lda #^ff6vwf_text_dma_stack_base
    sta dma_stack_ptr+2
    lda f:ff6vwf_text_dma_stack_ptr
    a16
    and #$00ff
    add #.loword(ff6vwf_text_dma_stack_base)
    sta dma_stack_ptr

    ; Bump the DMA stack pointer. If it overflows, bail out to avoid crashing the game.
    a8
    lda f:ff6vwf_text_dma_stack_ptr
    add #4
    cmp #VWF_SLOT_COUNT * 4
    bge @out
    sta f:ff6vwf_text_dma_stack_ptr

    ; Push our DMA on the stack. X is the text line index.
    ldy #VWF_MAX_LINE_BYTE_SIZE
    jsr _ff6vwf_mul8
    a16
    txa
    add tile_base_addr              ; VRAM address
    lsr                             ; word address
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

; General functions

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
