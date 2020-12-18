; snes-vwf/ff6/encounter.s
;
; Final Fantasy 6 variable-width font patches specific to encounters

.p816
.i16
.a8
.feature c_comments

.include "ff6.inc"
.include "../snes.inc"

.import std_memset: near
.import std_mod16_8: near
.import std_mul16_8: near
.import std_mul8: near

.import ff6vwf_calculate_first_tile_id_simple: near
.import ff6vwf_get_long_item_name: near
.import ff6vwf_render_string: near
.import ff6vwf_schedule_text_dma: near
.import ff6vwf_long_spell_names: far
.import ff6vwf_long_dance_names: far
.import ff6vwf_long_magitek_names: far
.import ff6vwf_long_enemy_names: far
.import ff6vwf_long_item_names: far

; Constants

; Address in VRAM where characters begin, for BG3 during encounters.
VWF_ENCOUNTER_TILE_BASE_ADDR = $b000

FF6VWF_ITEM_TYPE_INVENTORY      = 0
FF6VWF_ITEM_TYPE_ITEM_IN_HAND   = 1
FF6VWF_ITEM_TYPE_TOOL           = 2

; FF6 globals

ff6_encounter_enemy_ids          = $7e200d
ff6_encounter_display_list_left  = $7e575a
ff6_encounter_display_list_right = $7e5760

.segment "BSS"

; Encounter BSS
.org $7ec800

; Current of the stack *in bytes*.
ff6vwf_encounter_text_dma_stack_size: .res 1
; Stack of DMA structures. They look like:
;
; struct dma {
;     void vram *dest_vram_addr;    // word address
;     void near *src_addr;          // our address
;     uint16 size;                  // number of bytes to be transferred
; };
;
ff6vwf_encounter_text_dma_stack_base: .res FF6VWF_DMA_STRUCT_SIZE * FF6VWF_ENCOUNTER_SLOT_COUNT
; ID of the current item slot we're drawing.
ff6vwf_encounter_current_item_slot: .res 1
; What type of item we're drawing.
ff6vwf_encounter_item_type_to_draw: .res 1
; ID of the current skill (Rage, dance, Magitek) slot we're drawing.
ff6vwf_encounter_current_skill_slot: .res 1
; Buffer space for the lines of text, ready to be uploaded to VRAM.
ff6vwf_encounter_text_tiles: .res VWF_TILE_BYTE_SIZE_4BPP * 128

ff6vwf_encounter_bss_end:
 
.export ff6vwf_encounter_text_dma_stack_base
.export ff6vwf_encounter_text_tiles
.export ff6vwf_encounter_text_dma_stack_size
.export ff6vwf_encounter_bss_end

.reloc 

; Patches to Final Fantasy 6 functions

; Final Fantasy 6 encounter patches

; Encounter setup. We patch it to initialize our DMA stack.
.segment "PTEXTENCOUNTERINIT"
    jml _ff6vwf_encounter_init

; FF6 routine that draws an enemy name during encounters. We patch it to support variable-width
; fonts.
.segment "PTEXTENCOUNTERDRAWENEMYNAME"
    jsl _ff6vwf_encounter_draw_enemy_name
    rts

; FF6 routine that builds a menu item for an item in inventory during encounters. We patch it to
; record what inventory slot number it was so that the VWF rendering routine can figure out what
; text slot to use in order to avoid collisions.
.segment "PTEXTENCOUNTERBUILDMENUITEMFORITEM"
    jml _ff6vwf_encounter_build_menu_item_for_item          ; 4 bytes

; FF6 routine that builds a menu item for an equipped item in hand (during encounters). We patch it
; to record that this is an item in hand so that the VWF rendering routine can use the appropriate
; slot.
.segment "PTEXTENCOUNTERBUILDMENUITEMFORITEMINHAND"
    jml _ff6vwf_encounter_build_menu_item_for_item_in_hand  ; 4 bytes

; FF6 routine that builds a menu item for one of Edgar's tools (during encounters). We patch it
; to record that this is a tool so that the VWF rendering routine can use the appropriate slot.
.segment "PTEXTENCOUNTERBUILDMENUITEMFORTOOLS"
    jml _ff6vwf_encounter_build_menu_item_for_tools

.segment "PTEXTENCOUNTERBUILDMENUITEMFORTHROW"
    jml _ff6vwf_encounter_build_menu_item_for_throw

; FF6 routine to draw an item name during encounters.
.segment "PTEXTENCOUNTERDRAWITEMNAME"
    jsl _ff6vwf_encounter_draw_item_name
    rts

.segment "PTEXTENCOUNTERBUILDMENUITEMFORSPELL"
    jml _ff6vwf_encounter_build_menu_item_for_spell     ; 4 bytes

.segment "PTEXTENCOUNTERBUILDMENUITEMFORRAGE"
    jml _ff6vwf_encounter_build_menu_item_for_rage      ; 4 bytes

.segment "PTEXTENCOUNTERBUILDMENUITEMFORDANCE"
    jml _ff6vwf_encounter_build_menu_item_for_dance     ; 4 bytes

.segment "PTEXTENCOUNTERBUILDMENUITEMFORMAGITEK"
    jml _ff6vwf_encounter_build_menu_item_for_magitek   ; 4 bytes

; FF6 routine to draw the name of a spell during encounters.
.segment "PTEXTENCOUNTERDRAWSPELLNAME"
    jsl _ff6vwf_encounter_draw_spell_name
    rts

; FF6 routine to draw the name of one of Gau's Rages during encounters.
.segment "PTEXTENCOUNTERDRAWRAGENAME"
    jsl _ff6vwf_encounter_draw_rage_name
    rts

.segment "PTEXTENCOUNTERDRAWDANCENAME"
    jsl _ff6vwf_encounter_draw_dance_name
    rts

; FF6 routine to draw the name of a Magitek Armor attack.
.segment "PTEXTENCOUNTERDRAWMAGITEKNAME"
    jsl _ff6vwf_encounter_draw_magitek_name
    rts

; Part of the FF6 encounter NMI/VBLANK handler. We patch it to upload our text if needed.
.segment "PTEXTENCOUNTERRUNDMA"
    jml _ff6vwf_encounter_run_dma           ; 4 bytes

; FF6 function that restores the normal BG3 font by copying it from the ROM after a dialogue-style
; text box in an encounter has closed. We have to patch it to reupload any text we created to VRAM.
.segment "PTEXTENCOUNTERRESTORESMALLFONT"
ff6_encounter_schedule_dma = $198d
    jsl _ff6vwf_encounter_restore_small_font
    rts

; FF6 function that runs whenever the main action window closes during an encounter. We patch it to
; reupload any enemy names, in case their text slots got overwritten by items, Rages, or Dances,
; for example.
.segment "PTEXTENCOUNTERCLOSEMAINMENU"
    jml _ff6vwf_encounter_close_main_menu

; Wraps FF6's "schedule DMA" function in a far call.
_ff6vwf_encounter_schedule_dma_trampoline:
    jsr ff6_encounter_schedule_dma
    rtl

; Our own functions, in a separate bank
.segment "TEXT"

; farproc void _ff6vwf_encounter_init()
.proc _ff6vwf_encounter_init
    lda #0
    sta f:ff6vwf_encounter_text_dma_stack_size
    jsl $c00016         ; original code
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
    ; Fetch string pointer.
    a16
    asl
    tax
    lda f:ff6vwf_long_enemy_names,x
    sta string_ptr
    a8

    ; Calculate first tile index.
    ldx enemy_index
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple
    txa
    sta current_tile_index

    ; Render string.
    ldx current_tile_index              ; first_tile_id
    lda #10
    sta outgoing_args+0                 ; max_tile_count
    lda #0
    sta outgoing_args+1                 ; flags = 2bpp
    ldy string_ptr+0
    sty outgoing_args+2                 ; string_ptr+0
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+4                 ; string_ptr+2
    ldy #VWF_ENCOUNTER_TILE_BASE_ADDR
    jsr ff6vwf_render_string

    ; Draw tiles.
    ldx dest_tilemap_offset
:   txy                                 ; dest_tilemap_offset
    ldx current_tile_index              ; tile_to_draw
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

.proc _ff6vwf_encounter_draw_item_name
begin_locals
    decl_local outgoing_args, 7
    decl_local item_name_tiles, 3           ; chardata far *
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local item_slot, 1                 ; uint8
    decl_local item_id_ptr, 2               ; uint8 near *
    decl_local item_id, 1                   ; uint8
    decl_local string_ptr, 2                ; char near *

ff6_display_list_ptr        = $7e004f
ff6_item_in_hand_left       = $7e575a
ff6_item_in_hand_right      = $7e5760
ff6_tool_display_list_left  = $7e575a
ff6_tool_display_list_right = $7e5760

    enter __FRAME_SIZE__

    ; Initialize locals.
    sty dest_tilemap_offset
    a16
    lda ff6_display_list_ptr        ; 5A, 60, 62, 
    sta item_id_ptr

    ; Figure out what text slot we're going to use.
    a8
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

@write_item_slot:
    sta item_slot

    ; Fetch item ID.
    lda (item_id_ptr)
    sta item_id

    ; Draw item icon.
    tax
    ldy #FF6_SHORT_ITEM_LENGTH
    jsr std_mul8
    lda ff6_short_item_names,x
    tax                             ; tile_to_draw
    ldy dest_tilemap_offset
    jsr _ff6vwf_encounter_draw_tile
    stx dest_tilemap_offset

    ; Compute string pointer.
    ldx item_id
    jsr ff6vwf_get_long_item_name
    stx string_ptr

    ; Compute first tile index.
    ldx item_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple   ; first_tile_id

    ; Render string.
    lda #10
    sta outgoing_args+0             ; max_tile_count
    lda #0
    sta outgoing_args+1             ; 2bpp
    ldy string_ptr
    sty outgoing_args+2             ; string
    lda #^ff6vwf_long_item_names
    sta outgoing_args+4             ; string bank byte
    ldy #VWF_ENCOUNTER_TILE_BASE_ADDR
    jsr ff6vwf_render_string

    ; Draw tile data.
    ldx dest_tilemap_offset     ; dest_tilemap_offset
    ldy item_slot               ; text_line_slot
    lda #2
    sta outgoing_args+0         ; blank_tiles_at_end
    jsr _ff6vwf_encounter_draw_tile_data

    txy ; FF6 expects the dest tilemap offset to go in Y upon exit...
    leave __FRAME_SIZE__
    rtl
.endproc

.proc _ff6vwf_encounter_draw_spell_name
begin_locals
    decl_local outgoing_args, 7
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local text_line_slot, 1            ; uint8
    decl_local spell_id_ptr, 2              ; uint8 near *
    decl_local spell_id, 1                  ; uint8
    decl_local string_ptr, 2                ; char near *

ff6_display_list_ptr         = $7e004f
ff6_spell_display_list_left  = $7e575a
ff6_spell_display_list_right = $7e5760

; This is an immediate byte for a LDA instruction in the middle of a function. Yuck! But that's the
; only way I can think of to safely determine the length of a spell name, whether we're running in
; vanilla or TWUE.
ff6_spell_name_length = $c1601b

    enter __FRAME_SIZE__

    ; Initialize locals.
    sty dest_tilemap_offset
    a16
    lda f:ff6_display_list_ptr
    inc
    sta f:ff6_display_list_ptr
    sta spell_id_ptr
    a8

    ; Figure out what text line slot we're going to use.
    ldx spell_id_ptr
    jsr _ff6vwf_encounter_get_text_line_slot_for_magic_or_rage
    txa
    sta text_line_slot

    ; Fetch spell ID.
    lda (spell_id_ptr)
    sta spell_id

    ; If empty, don't display it.
    lda spell_id
    cmp #$ff
    bne @got_a_spell

    ; Draw blanks if empty.
    ldx dest_tilemap_offset
    lda f:ff6_spell_name_length
    tay
    jsr _ff6vwf_encounter_draw_blank_tile_data
    bra @out

@got_a_spell:
    ; Compute string pointer.
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_spell_names,x
    sta string_ptr
    a8

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple

    ; Render string.
    lda #10
    sta outgoing_args+0
    lda #0
    sta outgoing_args+1             ; 2bpp
    ldy string_ptr
    sty outgoing_args+2             ; string
    lda #^ff6vwf_long_spell_names
    sta outgoing_args+4             ; string bank byte
    ldy #VWF_ENCOUNTER_TILE_BASE_ADDR
    jsr ff6vwf_render_string

    ; Draw spell icon.
    ldx spell_id
    ldy #FF6_SHORT_SPELL_NAME_LENGTH
    jsr std_mul8
    lda ff6_short_spell_names,x
    tax                             ; tile_to_draw
    ldy dest_tilemap_offset
    jsr _ff6vwf_encounter_draw_tile
    stx dest_tilemap_offset

    ; Draw tile data.
    ldx dest_tilemap_offset     ; dest_tilemap_offset
    ldy text_line_slot          ; text_line_slot
    lda #0
    sta outgoing_args+0         ; blank_tiles_at_end
    jsr _ff6vwf_encounter_draw_tile_data

@out:
    txy         ; FF6 expects the dest tilemap offset to go in Y upon exit...
    leave __FRAME_SIZE__
    rtl
.endproc

.proc _ff6vwf_encounter_draw_rage_name
begin_locals
    decl_local outgoing_args, 7
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local text_line_slot, 1            ; uint8
    decl_local enemy_id_ptr, 2              ; uint8 near *
    decl_local enemy_id, 1                  ; uint8
    decl_local string_ptr, 2                ; char near *

ff6_display_list_ptr        = $7e004f
ff6_rage_display_list_left  = $7e575a
ff6_rage_display_list_right = $7e5760

    enter __FRAME_SIZE__

    ; Initialize locals.
    sty dest_tilemap_offset
    a16
    lda f:ff6_display_list_ptr
    inc
    sta f:ff6_display_list_ptr
    sta enemy_id_ptr
    a8

    ; Figure out what text line slot we're going to use.
    ldx enemy_id_ptr
    jsr _ff6vwf_encounter_get_text_line_slot_for_magic_or_rage
    txa
    sta text_line_slot

    ; Fetch enemy ID.
    lda (enemy_id_ptr)
    sta enemy_id

    ; If empty (or Tonberries), don't display it.
    lda enemy_id
    cmp #$ff
    bne @got_a_rage

    ldx dest_tilemap_offset
    ldy #FF6_SHORT_ENEMY_NAME_LENGTH
    jsr _ff6vwf_encounter_draw_blank_tile_data
    bra @out

@got_a_rage:
    ; Compute string pointer.
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_enemy_names,x
    sta string_ptr
    a8

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple   ; first_tile_id

    ; Render string.
    lda #10
    sta outgoing_args+0
    lda #0
    sta outgoing_args+1             ; 2bpp
    ldy string_ptr
    sty outgoing_args+2             ; string
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+4             ; string bank byte
    ldy #VWF_ENCOUNTER_TILE_BASE_ADDR
    jsr ff6vwf_render_string

    ; Draw tile data.
    ldx dest_tilemap_offset     ; dest_tilemap_offset
    ldy text_line_slot          ; text_line_slot
    lda #1
    sta outgoing_args+0         ; blank_tiles_at_end
    jsr _ff6vwf_encounter_draw_tile_data

@out:
    txy ; FF6 expects the dest tilemap offset to go in Y upon exit...
    leave __FRAME_SIZE__
    rtl
.endproc

; farproc inreg(Y) uint16 _ff6vwf_encounter_draw_dance_name(uint8 unused,
;                                                           uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_dance_name
begin_locals
    decl_local outgoing_args, 3

; This is an immediate byte for a LDA instruction in the middle of a function. Yuck! But that's the
; only way I can think of to safely determine the length of a Dance name, whether we're running in
; vanilla or TWUE.
ff6_dance_name_length = $c16611

    enter __FRAME_SIZE__
    tyx
    ldy #.loword(ff6vwf_long_dance_names)
    sty outgoing_args+0
    lda #^ff6vwf_long_dance_names
    sta outgoing_args+2
    lda f:ff6_dance_name_length
    tay                             ; name_length
    jsr _ff6vwf_encounter_draw_dance_or_magitek_name

    leave __FRAME_SIZE__
    txy
    rtl
.endproc

; farproc inreg(Y) uint16 _ff6vwf_encounter_draw_magitek_name(uint8 unused,
;                                                             uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_magitek_name
begin_locals
    decl_local outgoing_args, 3

; This is an immediate byte for a LDA instruction in the middle of a function. Yuck! But that's the
; only way I can think of to safely determine the length of a Magitek attack name, whether we're
; running in vanilla or TWUE.
ff6_magitek_name_length = $c16500

    enter __FRAME_SIZE__

    tyx
    ldy #.loword(ff6vwf_long_magitek_names)
    sty outgoing_args+0
    lda #^ff6vwf_long_magitek_names
    sta outgoing_args+2
    lda f:ff6_magitek_name_length
    tay                             ; name_length
    jsr _ff6vwf_encounter_draw_dance_or_magitek_name

    leave __FRAME_SIZE__
    txy
    rtl
.endproc

; nearproc uint16 _ff6vwf_encounter_draw_dance_or_magitek_name(uint16 dest_tilemap_offset,
;                                                              uint8 name_length,
;                                                              const char far *name_list)
.proc _ff6vwf_encounter_draw_dance_or_magitek_name
begin_locals
    decl_local outgoing_args, 7
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local text_line_slot, 1            ; uint8
    decl_local dance_id_ptr, 2              ; uint8 near *
    decl_local dance_id, 1                  ; uint8
    decl_local string_ptr, 2                ; const char near *
    decl_local name_length, 1               ; uint8
begin_args_nearcall
    decl_arg name_list, 3                   ; const char far *

ff6_display_list_ptr    = $7e004f

    enter __FRAME_SIZE__

    ; Initialize locals.
    stx dest_tilemap_offset
    tya
    sta name_length
    a16
    lda f:ff6_display_list_ptr
    inc
    sta f:ff6_display_list_ptr
    sta dance_id_ptr
    a8

    ; Figure out what text line slot we're going to use.
    ldx dance_id_ptr
    jsr _ff6vwf_encounter_get_text_line_slot_for_dance_or_magitek
    txa
    sta text_line_slot

    ; Fetch dance or Magitek ID.
    lda (dance_id_ptr)
    cmp #8
    bge @no_dance
    sta dance_id

    ; Compute string pointer.
    lda dance_id
    a16
    and #$00ff
    asl
    tay
    lda [name_list],y
    sta string_ptr
    a8

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple   ; first_tile_id

    ; Render string.
    lda #10
    sta outgoing_args+0
    lda #0
    sta outgoing_args+1             ; 2bpp
    ldy string_ptr
    sty outgoing_args+2             ; string
    lda name_list+2
    sta outgoing_args+4             ; string bank byte
    ldy #VWF_ENCOUNTER_TILE_BASE_ADDR
    jsr ff6vwf_render_string

    ; Draw tile data.
    ldx dest_tilemap_offset     ; dest_tilemap_offset
    ldy text_line_slot          ; text_line_slot
    lda name_length
    sub #10 - 1
    sta outgoing_args+0         ; blank_tiles_at_end
    jsr _ff6vwf_encounter_draw_tile_data
    bra @out

@no_dance:
    ldx dest_tilemap_offset     ; dest_tilemap_offset
    ldy name_length
    jsr _ff6vwf_encounter_draw_blank_tile_data

@out:
    leave __FRAME_SIZE__
    rts
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

; uint16 _ff6vwf_encounter_draw_tile(char tile, uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_tile
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
; after a text box closes during an encounter. We simply to tell our custom NMI to reupload all the
; strings.
;
; FIXME(tachiweasel): This may need to upload more...
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
    lda #0
    sta outgoing_args+0     ; use_bpp4
    jsr ff6vwf_schedule_text_dma
:   inc enemy_index
    lda enemy_index
    cmp #4      ; FIXME(tachiweasel): Probably should be *all* the strings...
    blt @reupload_enemy_name

    leave __FRAME_SIZE__
    ; NB: This is necessary to avoid a crash!
    a16
    lda #0
    a8
    rtl
.endproc

.proc _ff6vwf_encounter_close_main_menu
    jsr _ff6vwf_encounter_reupload_all_enemy_names

    ; Stuff the original function did
    inc $10
    tdc
    pea $4671-1
    jml $c150fb
.endproc

.proc _ff6vwf_encounter_reupload_all_enemy_names
begin_locals
    decl_local outgoing_args, 6
    decl_local enemy_slot, 1
    decl_local string_ptr, 2        ; char near *

    enter __FRAME_SIZE__

    lda #0
    sta enemy_slot

@render_next_enemy:
    lda enemy_slot
    a16
    and #$00ff
    asl
    tax
    lda ff6_encounter_enemy_ids,x   ; Fetch enemy ID.
    cmp #$ffff
    a8
    beq @no_enemy

    ; Fetch string pointer.
    a16
    asl
    tax
    lda f:ff6vwf_long_enemy_names,x
    sta string_ptr
    a8

    ; Calculate first tile ID.
    ldx enemy_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple

    ; Render string.
    lda #10
    sta outgoing_args+0
    lda #0
    sta outgoing_args+1                 ; 2bpp
    ldy string_ptr
    sty outgoing_args+2                 ; string_ptr+0
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+4                 ; string_ptr+2
    ldy #VWF_ENCOUNTER_TILE_BASE_ADDR
    jsr ff6vwf_render_string

@no_enemy:
    inc enemy_slot
    lda enemy_slot
    cmp #4
    bne @render_next_enemy

    leave __FRAME_SIZE__
    rts
.endproc

; nearproc uint16 _ff6vwf_encounter_draw_tile_data(uint16 dest_tilemap_offset,
;                                                  uint8 text_line_slot,
;                                                  uint8 blank_tiles_at_end)
.proc _ff6vwf_encounter_draw_tile_data
begin_locals
    decl_local dest_tilemap_offset, 2       ; uint16
    decl_local text_line_slot, 1            ; uint8
    decl_local tiles_to_draw, 1             ; uint8
    decl_local current_tile_index, 1        ; char
begin_args_nearcall
    decl_arg blank_tiles_at_end, 1          ; uint8

    enter __FRAME_SIZE__

    ; Initialize locals.
    stx dest_tilemap_offset
    tya
    sta text_line_slot
    lda #10
    sta tiles_to_draw

    ; Draw tile data.
    ldx text_line_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple
    txa
    sta current_tile_index
    ldx dest_tilemap_offset
:   txy                     ; dest_tilemap_offset
    lda current_tile_index
    inc current_tile_index
    tax                     ; tile_to_draw
    jsr _ff6vwf_encounter_draw_tile
    dec tiles_to_draw
    bne :-

    ; Add blank tiles on the end, if necessary. (X should still contain dest tilemap offset.)
    ldy blank_tiles_at_end
    jsr _ff6vwf_encounter_draw_blank_tile_data

    leave __FRAME_SIZE__
    rts
.endproc

; nearproc uint16 _ff6vwf_encounter_draw_blank_tile_data(uint16 dest_tilemap_offset, uint8 count)
.proc _ff6vwf_encounter_draw_blank_tile_data
begin_locals
    decl_local count, 1     ; uint8

    enter __FRAME_SIZE__

    tya
    sta count

    ; Add blank tiles on the end, if necessary.
    cmp #0
:   beq :+
    txy                     ; dest_tilemap_offset
    ldx #$ff                ; tile_to_draw
    jsr _ff6vwf_encounter_draw_tile
    dec count
    bra :-
:

    leave __FRAME_SIZE__
    rts
.endproc

; Patch to the encounter DMA routine.
.proc _ff6vwf_encounter_run_dma
    ; Code that we overwrote.
    jsl $c2a88f

    ; Run our generic DMA routine.
    pha
    plb
    ff6vwf_run_dma ff6vwf_encounter_text_tiles, ff6vwf_encounter_text_dma_stack_base, ff6vwf_encounter_text_dma_stack_size, 7, 250
    tdc
    lda #$7e
    pha
    plb

    ; Tear down.
    jml $c10be1
.endproc

.export _ff6vwf_encounter_run_dma

.proc _ff6vwf_encounter_build_menu_item_for_spell
    sta f:ff6vwf_encounter_current_skill_slot    ; from $c14db5

    ; Stuff the original function did that we overwrote.
    phy
    asl
    sta $40
    jmp $c14db9
.endproc

.proc _ff6vwf_encounter_build_menu_item_for_rage
    sta f:ff6vwf_encounter_current_skill_slot    ; from $c15945

    ; Stuff the original function did that we overwrote.
    phy
    asl
    tay
    tdc
    jmp $c14ce6
.endproc

.proc _ff6vwf_encounter_build_menu_item_for_dance
    sta f:ff6vwf_encounter_current_skill_slot

    ; Stuff the original function did that we overwrote.
    phy
    asl
    tay
    tdc
    jmp $c14d0c
.endproc

.proc _ff6vwf_encounter_build_menu_item_for_magitek
    sta f:ff6vwf_encounter_current_skill_slot

    ; Stuff the original function did that we overwrote.
    phy
    asl
    tay
    tdc
    jmp $c14d32
.endproc

; nearproc uint8 _ff6vwf_encounter_get_text_line_slot_for_magic_or_rage(near *skill_id_ptr)
;
; Determines the text line slot to use for Magic or Rage.
.proc _ff6vwf_encounter_get_text_line_slot_for_magic_or_rage
begin_locals
    decl_local skill_id_ptr, 2  ; near *

    enter __FRAME_SIZE__

    stx skill_id_ptr

    lda f:ff6vwf_encounter_current_skill_slot
    a16
    and #$00ff
    tax
    a8
    ldy #5
    jsr std_mod16_8     ; current_skill_slot % 5

    asl
    ldx skill_id_ptr
    cpx #.loword(ff6_encounter_display_list_left)
    beq :+

    inc
:   tax         ; (current_skill_slot % 5) * 2, plus one if it's the right column

    leave __FRAME_SIZE__
    rts
.endproc

; nearproc uint8 _ff6vwf_encounter_get_text_line_slot_for_dance_or_magitek(near *skill_id_ptr)
;
; Determines the text line slot to use for Dance or Magitek.
.proc _ff6vwf_encounter_get_text_line_slot_for_dance_or_magitek
    lda f:ff6vwf_encounter_current_skill_slot
    asl
    cpx #.loword(ff6_encounter_display_list_right)
    bne :+
    inc
:   tax         ; skill slot * 2, plus one if right column
    rts
.endproc
