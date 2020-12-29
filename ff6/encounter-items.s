; snes-vwf/ff6/encounter.s
;
; Final Fantasy 6 variable-width font patches specific to items in encounters (Item, Tools, Throw)

.p816
.i16
.a8
.feature c_comments

.include "ff6.inc"
.include "../snes.inc"

.import std_mod16_8: near
.import std_mul8: near

.import ff6vwf_calculate_first_tile_id_simple:      near
.import ff6vwf_encounter_current_item_slot:         far
.import ff6vwf_encounter_draw_enemy_name_string:    near
.import ff6vwf_encounter_draw_standard_string:      near
.import ff6vwf_encounter_draw_tile:                 near
.import ff6vwf_encounter_item_type_to_draw:         far
.import ff6vwf_get_long_item_name:                  near
.import ff6vwf_long_item_names:                     far
.import ff6vwf_long_status_names:                   far
.import ff6vwf_render_string:                       near

; Constants

FF6VWF_ITEM_TYPE_INVENTORY      = 0
FF6VWF_ITEM_TYPE_ITEM_IN_HAND   = 1
FF6VWF_ITEM_TYPE_TOOL           = 2

ITEM_R_HAND_START_TILE = 70
ITEM_L_HAND_START_TILE = 76

; Patches to Final Fantasy 6 functions

; Final Fantasy 6 encounter patches

; FF6 routine that builds a menu item for an item in inventory during encounters. We patch it to
; record what inventory slot number it was so that the VWF rendering routine can figure out what
; text slot to use in order to avoid collisions.
.segment "PTEXTENCOUNTERBUILDMENUITEMFORITEM"
    jml _ff6vwf_encounter_build_menu_item_for_item          ; 4 bytes

; FF6 routine that builds a menu item for an equipped item in hand (during encounters). We patch it
; to record that this is an item in hand so that the VWF rendering routine can use the appropriate
; slot.
.segment "PTEXTENCOUNTERBUILDMENUITEMFORITEMINHAND"     ; $c14bba
    jml _ff6vwf_encounter_build_menu_item_for_item_in_hand  ; 4 bytes

.segment "PTEXTENCOUNTERBUILDITEMSINHANDMENU"           ; $c15648
    jsl _ff6vwf_encounter_build_items_in_hand_menu
    nopx 2

; FF6 routine that builds a menu item for one of Edgar's tools (during encounters). We patch it
; to record that this is a tool so that the VWF rendering routine can use the appropriate slot.
.segment "PTEXTENCOUNTERBUILDMENUITEMFORTOOLS"
    jml _ff6vwf_encounter_build_menu_item_for_tools

.segment "PTEXTENCOUNTERBUILDMENUITEMFORTHROW"
    jml _ff6vwf_encounter_build_menu_item_for_throw

; FF6 routine to draw an item name during encounters.
.segment "PTEXTENCOUNTERDRAWITEMNAME"       ; $c16566
    jsl _ff6vwf_encounter_draw_item_name
    txy     ; Put dest tilemap offset in Y.
    rts

.segment "PTEXTENCOUNTERDRAWITEMTYPE"   ; $c1654b
    nopx 7

.segment "PTEXTENCOUNTERDRAWSTATUSNAME"     ; $c16a19
    jsl _ff6vwf_encounter_draw_status_name
    rts

; Our own functions, in a separate bank
.segment "TEXT"

.proc _ff6vwf_encounter_build_menu_item_for_item
    sta f:ff6vwf_encounter_current_item_slot
    pha
    lda #FF6VWF_ITEM_TYPE_INVENTORY
    sta f:ff6vwf_encounter_item_type_to_draw
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
    sta f:ff6vwf_encounter_current_item_slot
    lda #FF6VWF_ITEM_TYPE_ITEM_IN_HAND
    sta f:ff6vwf_encounter_item_type_to_draw

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

.proc _ff6vwf_encounter_build_items_in_hand_menu
begin_locals
    decl_local outgoing_args, 5

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Render "R-Hand".
    stz outgoing_args+0                             ; 2bpp
    ldy #.loword(ff6vwf_items_in_hand_label_0)
    sty outgoing_args+1                             ; string
    lda #^ff6vwf_items_in_hand_label_0
    sta outgoing_args+3                             ; string bank byte
    ldx #FF6VWF_FIRST_TILE+ITEM_R_HAND_START_TILE   ; first_tile_id
    ldy #6                                          ; max_tile_count
    jsr ff6vwf_render_string

    ; Render "L-Hand".
    stz outgoing_args+0                             ; 2bpp
    ldy #.loword(ff6vwf_items_in_hand_label_1)
    sty outgoing_args+1                             ; string
    lda #^ff6vwf_items_in_hand_label_1
    sta outgoing_args+3                             ; string bank byte
    ldx #FF6VWF_FIRST_TILE+ITEM_L_HAND_START_TILE   ; first_tile_id
    ldy #6                                          ; max_tile_count
    jsr ff6vwf_render_string

    ; Stuff the original function did:
    a16
    lda #$7e40
    sta f:$7e7baa
    a8

    leave __FRAME_SIZE__
    a16
    lda #0                  ; Avoids a crash.
    a8
    rtl
.endproc

; Original function: $c14bf7.
.proc _ff6vwf_encounter_build_menu_item_for_tools
.a8
    sta f:ff6vwf_encounter_current_item_slot
    pha
    lda #FF6VWF_ITEM_TYPE_TOOL
    sta f:ff6vwf_encounter_item_type_to_draw
    pla

    ; Stuff the original function did
    phy
    a16
    asl
    jml $c14bfb
.endproc

; Original function: $c14c27.
.proc _ff6vwf_encounter_build_menu_item_for_throw
.a8
    sta f:ff6vwf_encounter_current_item_slot
    pha
    lda #FF6VWF_ITEM_TYPE_INVENTORY
    sta f:ff6vwf_encounter_item_type_to_draw
    pla

    ; Stuff the original function did
    phy
    a16
    sta f:$7e0040
    jml $c14c2c
.endproc

; farproc uint16 _ff6vwf_encounter_draw_item_name(uint16 unused, uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_item_name
begin_locals
    decl_local outgoing_args, 5
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local item_id_ptr, 2               ; uint8 near *
    decl_local first_tile_id, 1             ; uint8

ff6_display_list_ptr        = $7e004f
ff6_item_in_hand_left       = $7e575a
ff6_item_in_hand_right      = $7e5760
ff6_tool_display_list_left  = $7e575a
ff6_tool_display_list_right = $7e5760

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Initialize locals.
    sty dest_tilemap_offset
    a16
    lda ff6_display_list_ptr
    sta item_id_ptr
    a8

    ; Figure out what text slot we're going to use.
    lda ff6vwf_encounter_item_type_to_draw
    cmp #FF6VWF_ITEM_TYPE_ITEM_IN_HAND
    beq @item_in_hand
    cmp #FF6VWF_ITEM_TYPE_TOOL
    beq @tool

    ; Item in inventory. Use slot `item_slot % 5`, because the item menu shows 4 items, plus an
    ; extra that partially appears during scrolling.
    lda ff6vwf_encounter_current_item_slot
    a16
    and #$00ff
    a8
    tax
    ldy #5
    jsr std_mod16_8
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
    bra @write_item_slot

@tool:
    lda ff6vwf_encounter_current_item_slot
    asl
    ldx item_id_ptr
    cpx #.loword(ff6_tool_display_list_left)
    beq @write_item_slot
    inc                     ; item slot * 2, plus one if this is the right column

    ; Compute first tile index.
@write_item_slot:
    tax
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple   ; first_tile_id
    txa                                         ; first_tile_id
    sta first_tile_id

    ; Draw item icon.
    lda (item_id_ptr)
    tax
    lda f:ff6_short_item_name_length
    tay
    jsr std_mul8
    lda ff6_short_item_names,x
    tax                             ; tile_to_draw
    ldy dest_tilemap_offset
    jsr ff6vwf_encounter_draw_tile
    stx dest_tilemap_offset

    ; Compute string pointer.
    lda (item_id_ptr)
    tax
    jsr ff6vwf_get_long_item_name

    ; Render the string.
    stx outgoing_args+2                 ; string_ptr
    lda #^ff6vwf_long_item_names
    sta outgoing_args+4                 ; string_ptr bank byte
    lda #2
    sta outgoing_args+1                 ; blank_tiles_at_end
    lda f:ff6_short_item_name_length
    sub #3
    sta outgoing_args+0                 ; max_tile_count
    ldx dest_tilemap_offset             ; dest_tilemap_offset
    ldy first_tile_id                   ; first_tile_id
    jsr ff6vwf_encounter_draw_standard_string

    leave __FRAME_SIZE__
    rtl
.endproc

; Draws the name of a status effect when using an item.
.proc _ff6vwf_encounter_draw_status_name
begin_locals
    decl_local outgoing_args, 5
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local status_id, 1                 ; uint8
    decl_local string_ptr, 2                ; char near *
    decl_local first_tile_id, 1             ; uint8

ff6_dest_tilemap_main   = $7e004c
ff6_display_list_ptr    = $7e004f

    tax                             ; Put status ID in X.

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Initialize locals.
    sty dest_tilemap_offset
    txa
    sta status_id

    ; Figure out what text line slot we're going to use.
    ; 5ecd/5ee1 5ef5/5f09 5f1d/5f31  5f45/5f59
    ; $7e004c starts at $5ee1 and increments by 40 each row.
    ; So we want: (slot-$5ee1)/40*10 == (slot-$5ee1)/4
    a16
    lda f:ff6_dest_tilemap_main
    sub #$5ee1
    lsri 2
    a8
    add #FF6VWF_FIRST_TILE
    sta first_tile_id

    ; Compute string pointer.
    lda status_id
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_status_names,x
    sta string_ptr
    a8

    ; Render the string.
    stz outgoing_args+4         ; save_tiles_to_draw
    ldy string_ptr
    sty outgoing_args+1         ; string_ptr
    lda #^ff6vwf_long_status_names
    sta outgoing_args+3         ; string_ptr bank byte
    lda #10
    sta outgoing_args+0         ; max_tile_count
    ldx dest_tilemap_offset     ; dest_tilemap_offset
    ldy first_tile_id           ; first_tile_id
    jsr ff6vwf_encounter_draw_enemy_name_string

@out:
    leave __FRAME_SIZE__
    a16
    lda #0
    ldx #0
    txy         ; FF6 expects the dest tilemap offset to go in Y upon exit...
    a8
    rtl
.endproc

; Constant data

.segment "DATA"

; R-Hand/L-Hand text
ff6vwf_items_in_hand_label_0: .asciiz "Right Hand"
ff6vwf_items_in_hand_label_1: .asciiz "Left Hand"
