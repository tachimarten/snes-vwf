; snes-vwf/ff6/encounter.s
;
; Final Fantasy 6 variable-width font patches specific to encounters

.p816
.i16
.a8
.feature c_comments

.include "ff6.inc"
.include "../snes.inc"

.import std_div16_8: near
.import std_memset: near
.import std_mod16_8: near
.import std_mul16_8: near
.import std_mul8: near

.import ff6vwf_calculate_first_tile_id_simple: near
.import ff6vwf_get_long_item_name: near
.import ff6vwf_render_string: near
.import ff6vwf_schedule_text_dma: near
.import ff6vwf_transcode_string: near
.import ff6vwf_long_command_names: far
.import ff6vwf_long_status_names: far
.import ff6vwf_long_enemy_names: far
.import ff6vwf_long_item_names: far
.import ff6vwf_long_spell_name_0: far   ; FIXME(tachiweasel): Remove

; Constants

FF6VWF_ITEM_TYPE_INVENTORY      = 0
FF6VWF_ITEM_TYPE_ITEM_IN_HAND   = 1
FF6VWF_ITEM_TYPE_TOOL           = 2

COMMAND_FIRST_TILE = 40
COMMAND_TILE_COUNT = 6
COMMAND_SLOT_ROW = 4
COMMAND_SLOT_DEFEND = 5
PARTY_MEMBERS_FIRST_TILE = 82

ITEM_R_HAND_START_TILE = 70
ITEM_L_HAND_START_TILE = 76

; FF6 globals

ff6_tiles_to_draw                = $7e0010
ff6_encounter_enemy_ids          = $7e200d
ff6_encounter_current_menu_state = $7e7bf0

.segment "BSS"

; Encounter BSS
.org $7eed00

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
.export ff6vwf_encounter_current_skill_slot
.export ff6vwf_encounter_bss_end

.reloc 

; Patches to Final Fantasy 6 functions

; Final Fantasy 6 encounter patches

; Encounter setup. We patch it to initialize our DMA stack.
.segment "PTEXTENCOUNTERINIT"
    jml _ff6vwf_encounter_init

.segment "PTEXTENCOUNTERUPLOADBG1CHARDATA"      ; $c140fa
    jsl _ff6vwf_encounter_upload_bg1_char_data

.segment "PTEXTENCOUNTERDRAWCOMMANDNAME"        ; $c169de
    jsl _ff6vwf_encounter_draw_command_name_from_display_list
    rts

.segment "PTEXTENCOUNTERDRAWROWMENUITEM"        ; $c15631
    jsl _ff6vwf_encounter_draw_row_menu_item
    nop

.segment "PTEXTENCOUNTERDRAWDEFENDMENUITEM"     ; $c1563b
    jsl _ff6vwf_encounter_draw_defend_menu_item
    nop

; FF6 routine that draws an enemy name during encounters. We patch it to support variable-width
; fonts.
.segment "PTEXTENCOUNTERDRAWENEMYNAME"          ; $c16993
    jsl _ff6vwf_encounter_draw_enemy_name
    rts

.segment "PTEXTENCOUNTERDRAWPCNAME"             ; $c1682f
    jsl _ff6vwf_encounter_draw_pc_name
    rts

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
.segment "PTEXTENCOUNTERDRAWITEMNAME"
    jsl _ff6vwf_encounter_draw_item_name
    rts

.segment "PTEXTENCOUNTERDRAWITEMTYPE"   ; $c1654b
    nopx 7

.segment "PTEXTENCOUNTERDRAWSTATUSNAME"     ; $c16a19
    jsl _ff6vwf_encounter_draw_status_name
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

; FF6 function that runs whenever a submenu closes and returns to the main menu. We patch it
; reupload any command names.
.segment "PTEXTENCOUNTERCLOSESUBMENU"   ; $c150c2
ff6vwf_encounter_close_submenu_patch:
    jml _ff6vwf_encounter_close_submenu
    stp     ; not reached

.segment "PTEXTENCOUNTERMPNEEDEDTILEMAP"    ; $c14a41
    .byte $ff, $12, $14, $ff
    .byte $ff, 4
    def_static_text_tiles 14, 5, -1

.segment "PTEXTENCOUNTERROWDEFTILEMAP" ; $c2e165
COMMAND_ROW_START_TILE = COMMAND_FIRST_TILE + COMMAND_SLOT_ROW*COMMAND_TILE_COUNT
COMMAND_DEFEND_START_TILE = COMMAND_FIRST_TILE + COMMAND_SLOT_DEFEND*COMMAND_TILE_COUNT
.byte $ff, $ff
    def_static_text_tiles_z COMMAND_ROW_START_TILE, .strlen("Row"), -1
.byte $ff, $ff
    def_static_text_tiles_z COMMAND_DEFEND_START_TILE, .strlen("Def."), -1
.word $0305
    def_static_text_tiles ITEM_R_HAND_START_TILE, .strlen("R-Hand"), -1
.word $0905
    def_static_text_tiles ITEM_L_HAND_START_TILE, .strlen("L-Hand"), -1

; Our own functions, in a separate bank
.segment "TEXT"

; farproc void _ff6vwf_encounter_init()
.proc _ff6vwf_encounter_init
    lda #0
    sta f:ff6vwf_encounter_text_dma_stack_size
    jsl $c00016         ; original code
    jml $c1102e
.endproc

; farproc void _ff6vwf_encounter_upload_bg1_char_data()
.proc _ff6vwf_encounter_upload_bg1_char_data
begin_locals
    decl_local outgoing_args, 4

    enter __FRAME_SIZE__

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    sta outgoing_args+0             ; 4bpp
    ldy #.loword(ff6vwf_mp_needed_string)
    sty outgoing_args+1             ; string
    lda #^ff6vwf_mp_needed_string
    sta outgoing_args+3             ; string bank byte
    ldx #$16                        ; first tile ID
    ldy #6                          ; max tile count
    jsr ff6vwf_render_string

    leave __FRAME_SIZE__
    plx
    pla         ; Remove return address.
    jml $c140fe
.endproc

; farproc inreg(Y) uint16 _ff6vwf_encounter_draw_command_name_from_display_list(
;   uint16 unused,
;   uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_command_name_from_display_list
begin_locals
    decl_local outgoing_args, 2
    decl_local dest_tilemap_offset, 2       ; uint16
    decl_local command_slot, 1              ; uint8
    decl_local tiles_to_draw, 1             ; uint8
    decl_local current_tile_index, 1        ; uint8

display_list_ptr          = $7e0048
first_command_ptr         = $7e56d9     ; address of first command in the display list

    enter __FRAME_SIZE__

    ; Save dest tilemap offset.
    sty dest_tilemap_offset

    ; Calculate text line slot.
    a16
    lda f:display_list_ptr
    sub #.loword(first_command_ptr)
    a8
    lsri 3                  ; 8 bytes between each command
    sta command_slot

    ; Bump display list pointer.
    a16
    lda f:display_list_ptr
    inc
    sta f:display_list_ptr
    a8

    ; Render command.
    ldx command_slot
    jsr _ff6vwf_encounter_fetch_and_render_command_name

    ; Was there a command (as opposed to an empty slot)?
    cpx #0
    bne @got_a_command

    ; Fill with blanks.
    ldy #FF6_SHORT_COMMAND_NAME_LENGTH+1    ; tiles_to_draw
    bra @draw_blanks

@got_a_command:
    ; Calculate first tile index.
    ldx command_slot
    ldy #COMMAND_TILE_COUNT
    jsr ff6vwf_calculate_first_tile_id_simple
    txa
    add #COMMAND_FIRST_TILE
    sta current_tile_index

    ; Draw tiles.
    lda #FF6_SHORT_COMMAND_NAME_LENGTH - 1
    sta tiles_to_draw
    a16
    tdc
    add #tiles_to_draw
    sta outgoing_args+0         ; tiles_to_draw_ptr
    a8
    ldy dest_tilemap_offset     ; dest_tilemap_offset
    ldx current_tile_index      ; current_tile_index
    jsr _ff6vwf_encounter_draw_enemy_name_tiles
    stx dest_tilemap_offset

    ldy #1                      ; Draw one blank tile.

@draw_blanks:
    stz outgoing_args+0                     ; save_tiles_to_draw
    ldx dest_tilemap_offset                 ; dest_tilemap_offset
    jsr _ff6vwf_encounter_draw_blank_enemy_name_tiles

    leave __FRAME_SIZE__
    txy                 ; Put dest_tilemap_offset in Y.
    a16
    lda #0
    a8
    ldx #0
    rtl
.endproc

; farproc void _ff6vwf_encounter_draw_row_menu_item()
.proc _ff6vwf_encounter_draw_row_menu_item
MENU_ITEM_ROW = 20
MENU_STATE_ROW_SUSTAIN = $17

    ldx #MENU_ITEM_ROW
    ldy #COMMAND_SLOT_ROW
    jsr _ff6vwf_encounter_render_command_name

    ; Stuff the original function did:
    lda #MENU_STATE_ROW_SUSTAIN
    sta f:ff6_encounter_current_menu_state

    a16
    lda #0
    a8
    ldx #0
    rtl
.endproc

; farproc void _ff6vwf_encounter_draw_defend_menu_item()
.proc _ff6vwf_encounter_draw_defend_menu_item
MENU_ITEM_DEFEND = 21
MENU_STATE_DEFEND_SUSTAIN = $19

    ldx #MENU_ITEM_DEFEND
    ldy #COMMAND_SLOT_DEFEND
    jsr _ff6vwf_encounter_render_command_name

    ; Stuff the original function did:
    lda #MENU_STATE_DEFEND_SUSTAIN
    sta f:ff6_encounter_current_menu_state

    a16
    lda #0
    a8
    ldx #0
    rtl
.endproc

; nearproc bool _ff6vwf_encounter_fetch_and_render_command_name(uint8 command_slot)
.proc _ff6vwf_encounter_fetch_and_render_command_name
begin_locals
    decl_local command_slot, 1              ; uint8
    decl_local text_line_slot, 1            ; uint8
    decl_local command_id, 1                ; uint8

character_battle_commands = $7e202e

    enter __FRAME_SIZE__

    txa
    sta command_slot

    ; Look up command ID.
    ;
    ; We could use the display list pointer for this if we're drawing the main command list, but
    ; for the sake of unifying this code with the "reupload on submenu close" code, let's look the
    ; command ID up directly.
    lda ff6_encounter_active_character
    and #$03
    tax
    ldy #12
    jsr std_mul8
    txa
    add command_slot
    add command_slot
    add command_slot
    a16
    and #$00ff
    tax
    a8
    lda f:character_battle_commands,x
    sta command_id

    ; If empty, don't display it.
    cmp #$ff
    bne @got_a_command
    ldx #0          ; Return false.
    bra @out

@got_a_command:
    tax
    ldy command_slot
    jsr _ff6vwf_encounter_render_command_name

    ldx #1          ; Return true.

@out:
    leave __FRAME_SIZE__
    rts
.endproc

; nearproc void _ff6vwf_encounter_render_command_name(uint8 command_id, uint8 text_line_slot)
.proc _ff6vwf_encounter_render_command_name
begin_locals
    decl_local outgoing_args, 4
    decl_local text_line_slot, 1    ; uint8
    decl_local command_id, 1        ; uint8
    decl_local string_ptr, 2        ; char near *

    enter __FRAME_SIZE__

    ; Store arguments.
    tya
    sta text_line_slot
    txa
    sta command_id    

    ; Compute string pointer.
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_command_names,x
    sta string_ptr
    a8

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy #COMMAND_TILE_COUNT
    jsr ff6vwf_calculate_first_tile_id_simple   ; first_tile_id
    txa
    add #COMMAND_FIRST_TILE
    tax

    ; Render string.
    stz outgoing_args+0             ; 2bpp
    ldy string_ptr
    sty outgoing_args+1             ; string
    lda #^ff6vwf_long_command_names
    sta outgoing_args+3             ; string bank byte
    ldy #COMMAND_TILE_COUNT
    jsr ff6vwf_render_string

@out:
    leave __FRAME_SIZE__
    rts
.endproc

.export _ff6vwf_encounter_render_command_name

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
    lda #1
    sta outgoing_args+0     ; save_tiles_to_draw
    ldy #11                 ; tiles_to_draw
    ldx dest_tilemap_offset
    jsr _ff6vwf_encounter_draw_blank_enemy_name_tiles
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
    lda #10
    sta outgoing_args+0         ; max_tile_count
    ldx string_ptr+0
    stx outgoing_args+1         ; string_ptr+0
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+3         ; string_ptr+2
    lda #1
    sta outgoing_args+4         ; save_tiles_to_draw
    ldx dest_tilemap_offset     ; dest_tilemap_offset
    ldy current_tile_index      ; current_tile_index
    jsr ff6vwf_encounter_draw_enemy_name_string
    stx dest_tilemap_offset

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

    ldy dest_tilemap_offset
    leave __FRAME_SIZE__
    ; NB: It is important that the high byte of A be 0 upon return! FF6 will glitch otherwise.
    a16
    lda #0
    a8
    rtl
.endproc

; farproc inreg(Y) uint16 _ff6vwf_encounter_draw_pc_name(uint8 unused, uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_pc_name
begin_locals
    decl_local outgoing_args, 6
    decl_local dest_tilemap_offset, 2       ; uint16
    decl_local tiles_to_draw, 1             ; uint8
    decl_local current_tile_index, 1        ; uint8
    decl_local name_buffer, 7               ; char[7]

name_pointer    = $7e0010

    enter __FRAME_SIZE__

    ; Init locals.
    sty dest_tilemap_offset
    lda #0
    sta $7e0014

    ; Look up party member ID.
    a16
    lda f:name_pointer
    sub #$2eae
    asli 3
    xba
    a8
    and #$03                ; (name_pointer - $2eae) / $20
    tax
    ldy #FF6_SHORT_PC_NAME_LENGTH
    jsr ff6vwf_calculate_first_tile_id_simple
    txa
    add #PARTY_MEMBERS_FIRST_TILE
    sta current_tile_index

    ; Copy name buffer.
    a16
    lda f:name_pointer
    inc
    sta outgoing_args+3     ; src_ptr
    tdc
    add #name_buffer
    sta outgoing_args+0     ; dest_ptr
    a8
    stz outgoing_args+2     ; dest_ptr, bank byte
    lda #$7e
    sta outgoing_args+5     ; src_ptr, bank byte
    ldx #FF6_SHORT_PC_NAME_LENGTH
    jsr ff6vwf_transcode_string

    ; Render the string.
    lda #FF6_SHORT_PC_NAME_LENGTH   ; max tile count
    sta outgoing_args+0
    a16
    tdc
    add #name_buffer
    sta outgoing_args+1             ; string_ptr
    a8
    lda #$7e
    sta outgoing_args+3             ; string_ptr, bank byte
    stz outgoing_args+4             ; save_tiles_to_draw
    ldx dest_tilemap_offset         ; dest_tilemap_offset
    ldy current_tile_index          ; first_tile_id
    jsr ff6vwf_encounter_draw_enemy_name_string

@out:
    leave __FRAME_SIZE__
    txy             ; Y = dest tilemap offset
    a16
    lda #0
    ldx #0
    a8
    rtl
.endproc

.export _ff6vwf_encounter_draw_pc_name

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

    enter __FRAME_SIZE__

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

.proc _ff6vwf_encounter_draw_item_name
begin_locals
    decl_local outgoing_args, 7
    decl_local item_name_tiles, 3           ; chardata far *
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local item_slot, 1                 ; uint8
    decl_local item_id_ptr, 2               ; uint8 near *
    decl_local item_id, 1                   ; uint8
    decl_local string_ptr, 2                ; char near *
    decl_local first_tile_id, 1             ; uint8

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
    jsr ff6vwf_encounter_draw_tile
    stx dest_tilemap_offset

    ; Compute string pointer.
    ldx item_id
    jsr ff6vwf_get_long_item_name
    stx string_ptr

    ; Compute first tile index.
    ldx item_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple   ; first_tile_id
    txa                             ; first_tile_id
    sta first_tile_id

    ; Render the string.
    ldy string_ptr
    sty outgoing_args+2                 ; string_ptr
    lda #^ff6vwf_long_item_names
    sta outgoing_args+4                 ; string_ptr bank byte
    lda #2
    sta outgoing_args+1                 ; blank_tiles_at_end
    lda #FF6_SHORT_ITEM_LENGTH
    sta outgoing_args+0                 ; max_tile_count
    ldx dest_tilemap_offset             ; dest_tilemap_offset
    ldy first_tile_id                   ; first_tile_id
    jsr ff6vwf_encounter_draw_standard_string

    leave __FRAME_SIZE__
    txy ; FF6 expects the dest tilemap offset to go in Y upon exit...
    rtl
.endproc

; uint16 _ff6vwf_encounter_draw_enemy_name_tile(char tile, uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_enemy_name_tile
begin_locals
    decl_local dest_tilemap_main, 2     ; tiledata near * ($7e004c)
    decl_local dest_tilemap_extra, 2    ; tiledata near * ($7e004a)

ff6_dest_tilemap_extra   = $7e004a
ff6_dest_tilemap_main    = $7e004c
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

; nearproc uint16 _ff6vwf_encounter_draw_blank_enemy_name_tiles(uint16 dest_tilemap_offset,
;                                                               uint8 tiles_to_draw,
;                                                               bool save_tiles_to_draw)
;
; If `save_tiles_to_draw` is true, saves `tiles_to_draw` in `ff6_tiles_to_draw` before returning.
;
; Returns the dest tilemap offset.
.proc _ff6vwf_encounter_draw_blank_enemy_name_tiles
begin_locals
    decl_local tiles_to_draw, 1         ; uint8
begin_args_nearcall
    decl_arg save_tiles_to_draw, 1      ; bool

    enter __FRAME_SIZE__

    tya
    sta tiles_to_draw

    lda tiles_to_draw
:   beq @loop_done
    txy                         ; dest_tilemap_offset
    ldx #$ffff                  ; space
    jsr _ff6vwf_encounter_draw_enemy_name_tile
    dec tiles_to_draw
    bra :-
@loop_done:

    ; Save `tiles_to_draw` if necessary.
    lda save_tiles_to_draw
    beq @out
    lda tiles_to_draw
    sta f:ff6_tiles_to_draw

@out:
    leave __FRAME_SIZE__
    rts
.endproc

; nearproc uint16 ff6vwf_encounter_draw_enemy_name_string(uint16 dest_tilemap_offset,
;                                                          uint8 first_tile_id,
;                                                          uint8 max_tile_count,
;                                                          const char far *string_ptr,
;                                                          bool save_tiles_to_draw)
;
; If `save_tiles_to_draw` is true, saves `tiles_to_draw` in `ff6_tiles_to_draw` before returning.
;
; Returns the dest tilemap offset.
.proc ff6vwf_encounter_draw_enemy_name_string
begin_locals
    decl_local outgoing_args, 4
    decl_local dest_tilemap_offset, 2   ; uint16
    decl_local current_tile_index, 1    ; uint8
begin_args_nearcall
    decl_arg max_tile_count, 1          ; uint8
    decl_arg string_ptr, 3              ; const char far *
    decl_arg save_tiles_to_draw, 1      ; bool

    enter __FRAME_SIZE__

    ; Save arguments.
    stx dest_tilemap_offset
    tya
    sta current_tile_index

    ; Render string.
    ldx string_ptr+0
    stx outgoing_args+1
    lda string_ptr+2
    sta outgoing_args+3
    stz outgoing_args+0                 ; flags = 2bpp
    ldx current_tile_index              ; first_tile_id
    ldy max_tile_count                  ; max_tile_count
    jsr ff6vwf_render_string

    ; Draw tiles.
    ldy dest_tilemap_offset     ; dest_tilemap_offset
    ldx current_tile_index      ; current_tile_index
    a16
    tdc
    add #max_tile_count
    sta outgoing_args+0         ; tiles_to_draw_ptr
    a8
    jsr _ff6vwf_encounter_draw_enemy_name_tiles     ; returns dest_tilemap_offset in X

    ; Save `tiles_to_draw` if necessary.
    lda save_tiles_to_draw
    beq :+
    lda max_tile_count
    sta f:ff6_tiles_to_draw
:

    leave __FRAME_SIZE__
    rts
.endproc

.export ff6vwf_encounter_draw_enemy_name_string

; nearproc uint16 ff6vwf_encounter_draw_standard_string(uint16 dest_tilemap_offset,
;                                                        uint8 first_tile_id,
;                                                        uint8 max_tile_count,
;                                                        uint8 blank_tiles_at_end,
;                                                        const char far *string_ptr)
;
; Returns the dest tilemap offset.
.proc ff6vwf_encounter_draw_standard_string
begin_locals
    decl_local outgoing_args, 4
    decl_local dest_tilemap_offset, 2   ; uint16
    decl_local first_tile_id, 1         ; uint8
begin_args_nearcall
    decl_arg max_tile_count, 1          ; uint8
    decl_arg blank_tiles_at_end, 1      ; uint8
    decl_arg string_ptr, 3              ; const char far *

    enter __FRAME_SIZE__

    ; Save arguments.
    stx dest_tilemap_offset
    tya
    sta first_tile_id

    ; Render string.
    ldx string_ptr+0
    stx outgoing_args+1         ; string_ptr
    lda string_ptr+2
    sta outgoing_args+3         ; string_ptr, bank byte
    stz outgoing_args+0         ; flags = 2bpp
    ldx first_tile_id           ; first_tile_id
    ldy max_tile_count          ; max_tile_count
    jsr ff6vwf_render_string

    ; Draw tiles.
    ldx dest_tilemap_offset     ; dest_tilemap_offset
    ldy first_tile_id           ; first_tile_id
    lda max_tile_count
    sta outgoing_args+0         ; text_tiles_to_draw
    lda blank_tiles_at_end
    sta outgoing_args+1         ; blank_tiles_at_end
    jsr _ff6vwf_encounter_draw_tile_data    ; returns dest_tilemap_offset in X

    leave __FRAME_SIZE__
    rts
.endproc

.export ff6vwf_encounter_draw_standard_string

; nearproc uint16 _ff6vwf_encounter_draw_enemy_name_tiles(uint8 current_tile_index,
;                                                         uint16 dest_tilemap_offset,
;                                                         uint8 near *tiles_to_draw_ptr)
;
; Returns the new dest tilemap offset.
.proc _ff6vwf_encounter_draw_enemy_name_tiles
begin_locals
    decl_local current_tile_index, 1    ; uint8
begin_args_nearcall
    decl_arg tiles_to_draw_ptr, 2       ; uint8 near *

    enter __FRAME_SIZE__

    ; Initialize locals.
    txa
    sta current_tile_index

    tyx                                         ; X = dest_tilemap_offset
    lda (tiles_to_draw_ptr)
:   beq @out
    txy                                         ; dest_tilemap_offset
    ldx current_tile_index                      ; tile_to_draw
    jsr _ff6vwf_encounter_draw_enemy_name_tile  ; returns new dest_tilemap_offset
    inc current_tile_index
    lda (tiles_to_draw_ptr)
    dec
    sta (tiles_to_draw_ptr)
    bra :-

@out:
    leave __FRAME_SIZE__
    rts
.endproc

; uint16 ff6vwf_encounter_draw_tile(char tile, uint16 dest_tilemap_offset)
.proc ff6vwf_encounter_draw_tile
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

.export ff6vwf_encounter_draw_tile

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
    ldy #10                 ; max_line_byte_size; FIXME(tachiweasel): Seems dubious!
    stz outgoing_args+0     ; flags = 0
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

.proc _ff6vwf_encounter_close_submenu
    ; FIXME(tachiweasel): Ugly!
    a16
    pha
    phx
    phy
    a8
    jsr _ff6vwf_encounter_reupload_all_command_names
    a16
    ply
    plx
    pla
    a8

    ; Stuff the original function did
    inc $7bee
    jml $c14f8c
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
    stz outgoing_args+0                 ; flags = 2bpp
    ldy string_ptr
    sty outgoing_args+1                 ; string_ptr+0
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+3                 ; string_ptr+2
    ldy #10                             ; max_tile_count
    jsr ff6vwf_render_string

@no_enemy:
    inc enemy_slot
    lda enemy_slot
    cmp #4
    bne @render_next_enemy

    leave __FRAME_SIZE__
    rts
.endproc

.proc _ff6vwf_encounter_reupload_all_command_names
begin_locals
    decl_local command_index, 1     ; uint8

    enter __FRAME_SIZE__

    lda #0
    sta command_index
:   tax
    jsr _ff6vwf_encounter_fetch_and_render_command_name
    lda command_index
    inc
    sta command_index
    cmp #4
    bne :-

    leave __FRAME_SIZE__
    rts
.endproc

; nearproc uint16 _ff6vwf_encounter_draw_tile_data(uint16 dest_tilemap_offset,
;                                                  uint8 text_line_slot,
;                                                  uint8 text_tiles_to_draw,
;                                                  uint8 blank_tiles_at_end)
.proc _ff6vwf_encounter_draw_tile_data
begin_locals
    decl_local dest_tilemap_offset, 2       ; uint16
    decl_local current_tile_index, 1        ; char
begin_args_nearcall
    decl_arg text_tiles_to_draw, 1          ; uint8
    decl_arg blank_tiles_at_end, 1          ; uint8

    enter __FRAME_SIZE__

    ; Initialize locals.
    stx dest_tilemap_offset
    tya
    sta current_tile_index

    ; Draw tile data.
    ldx dest_tilemap_offset
    lda text_tiles_to_draw
    cmp #0
:   beq :+
    txy                     ; dest_tilemap_offset
    lda current_tile_index
    inc current_tile_index
    tax                     ; tile_to_draw
    jsr ff6vwf_encounter_draw_tile
    dec text_tiles_to_draw
    bra :-
:

    ; Add blank tiles on the end, if necessary. (X should still contain dest tilemap offset.)
    ldy blank_tiles_at_end
    jsr ff6vwf_encounter_draw_blank_tile_data

    leave __FRAME_SIZE__
    rts
.endproc

; nearproc uint16 ff6vwf_encounter_draw_blank_tile_data(uint16 dest_tilemap_offset, uint8 count)
.proc ff6vwf_encounter_draw_blank_tile_data
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
    jsr ff6vwf_encounter_draw_tile
    dec count
    bra :-
:

    leave __FRAME_SIZE__
    rts
.endproc

.export ff6vwf_encounter_draw_blank_tile_data

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

.proc _ff6vwf_encounter_draw_status_name
begin_locals
    decl_local outgoing_args, 7
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local status_id, 1                 ; uint8
    decl_local string_ptr, 2                ; char near *
    decl_local first_tile_id, 1             ; uint8

ff6_dest_tilemap_main   = $7e004c
ff6_display_list_ptr    = $7e004f

    tax                             ; Put status ID in X.

    enter __FRAME_SIZE__

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
    txy         ; FF6 expects the dest tilemap offset to go in Y upon exit...
    a8
    rtl
.endproc

.export _ff6vwf_encounter_draw_status_name

; Constant data

.segment "DATA"

ff6vwf_mp_needed_string: .asciiz "needed"

; R-Hand/L-Hand text
ff6vwf_items_in_hand_label_0: .asciiz "Right Hand"
ff6vwf_items_in_hand_label_1: .asciiz "Left Hand"
