; snes-vwf/ff6/items-menu.s
;
; Final Fantasy 6 variable-width font patches specific to the Items, Equip, and Relic menus

.p816
.i16
.a8
.feature c_comments

.include "ff6.inc"
.include "../snes.inc"

.import std_memset:     near
.import std_mod16_8:    near
.import std_mul8:       near
.import std_stpcpy:     near

.import ff6vwf_calculate_first_tile_id_simple:  near
.import ff6vwf_current_equipment_bg3:           far
.import ff6vwf_current_equipment_text_slot:     far
.import ff6vwf_get_long_item_name:              near
.import ff6vwf_long_item_names:                 far
.import ff6vwf_long_item_type_names:            far
.import ff6vwf_long_key_item_names:             far
.import ff6vwf_menu_begin_transaction:          near
.import ff6vwf_menu_commit_transaction:         near
.import ff6vwf_menu_draw_list_item:             near
.import ff6vwf_menu_draw_vwf_tiles:             near
.import ff6vwf_menu_render_static_strings:      near
.import ff6vwf_menu_wounded_label:              far
.import ff6vwf_render_string:                   near
.import ff6vwf_stats_labels:                    far
.import ff6vwf_stats_tile_counts:               far
.import ff6vwf_stats_start_tiles:               far

; Constants

ITEM_MENU_STRING_COUNT  = 4
ITEM_MENU_OFFENSE_STRING_COUNT = 3
ITEM_MENU_DEFENSE_STRING_COUNT = 4
EQUIP_MENU_STRING_COUNT = 8
RELIC_MENU_STRING_COUNT = 4

EQUIP_MENU_FIRST_STATS_TILE = 36
ITEM_MENU_FIRST_CAN_BE_USED_BY_TILE = 32
ITEM_MENU_CAN_BE_USED_BY_TILE_COUNT = 20
ITEM_MENU_TAUGHT_SPELL_TILE_COUNT = 5
ITEM_MENU_FIRST_STATS_TILE = ITEM_MENU_FIRST_CAN_BE_USED_BY_TILE + ITEM_MENU_CAN_BE_USED_BY_TILE_COUNT + ITEM_MENU_TAUGHT_SPELL_TILE_COUNT

; FF6 globals

ff6_menu_current_selection  = $7e0028

; Menu BSS
.segment "BSS"

.org $7eb000

.reloc 

; Patches

.segment "PTEXTMENULOADEQUIPMENTNAME"       ; $c38fe1
    jsl _ff6vwf_menu_draw_equipment_name
    rts

; Let's put some trampolines here.
ff6vwf_menu_move_blitz_tilemap_trampoline: def_trampoline $56bc
ff6vwf_menu_compute_map_ptr_trampoline:    def_trampoline $809f

.export ff6vwf_menu_move_blitz_tilemap_trampoline:  far
.export ff6vwf_menu_compute_map_ptr_trampoline:     far

; FF6 routine to draw the inventory.
.segment "PTEXTMENUDRAWINVENTORY"       ; $c37f8b
    jsl _ff6vwf_menu_draw_inventory
    rts
_ff6_draw_inventory_draw_item_info_trampoline: def_trampoline $7fa1

; FF6 routine to draw an item in the Item menu.
.segment "PTEXTMENUDRAWITEMNAME"                    ; $c37fcd
    jml _ff6vwf_menu_draw_inventory_item_name_for_item_menu   ; 4 bytes
    nopx 3

.segment "PTEXTMENUDRAWITEMTYPENAME"                ; $c38004
    rts

; FF6 routine to draw an item available to equip, in the Equip or Relic menus.
.segment "PTEXTMENUDRAWITEMTOEQUIPNAME"
    jsl _ff6vwf_menu_draw_item_to_equip_name        ; 4 bytes
    nopx 3                                          ; overwrite `jsr $c39d11`

; Part of the FF6 routine to draw "<item name> can be used by:". We currently display "Equipment"
; in a fixed-width font instead of the item name because we don't have enough space to display that
; string in memory yet.
.segment "PTEXTMENUDRAWGEARINFOTEXT"        ; $c3856a
    jsl _ff6vwf_menu_draw_gear_info_text
    nopx 2

.segment "PTEXTMENUDRAWWEAPONPROPERTIES"    ; $c38779
    ldy #.loword(_weapon_properties_two_handed_string)

.segment "PTEXTMENUDRAWRIGHTHANDEQUIPMENT"  ; $c39408
    jsr ff6_menu_draw_equipped_item
    nopx 3

.segment "PTEXTMENUDRAWEQUIPPEDITEM"        ; $c39479
ff6_menu_draw_equipped_item:
    jml _ff6vwf_menu_draw_equipped_item

.segment "PTEXTMENUINITGEAROVERVIEW"        ; $c31c32
.proc ff6_menu_init_gear_overview
    JSR $352F                                   ; Reset/Stop stuff
    JSR $9497                                   ; Set to shift text
    JSR .loword(ff6_menu_draw_gear_overview)    ; Draw menu
    LDA #$01                                    ; C3/1D7E
    STA $26                                     ; Next: Fade-in
    LDA #$39                                    ; C3/2966
    STA $27                                     ; Queue: Sustain menu
    JMP $3541                                   ; BRT:1 + NMI
.endproc

.segment "PTEXTMENUDRAWGEAROVERVIEW"    ; $c38eed
.proc ff6_menu_draw_gear_overview
    jsl _ff6vwf_menu_draw_gear_overview
    nop
    JSR $6A28      ; Clear BG2 map A
    LDY #$902E     ; C3/902E
    JSR $0341      ; Draw window
    JSR $0E52      ; Upload window
    JSR $6A15      ; Clear BG1 map A
    JSR $6A19      ; Clear BG1 map B
    JSR $6A3C      ; Clear BG3 map A
    JSR $8F1C      ; Handle member 1
    JSR $8F36      ; Handle member 2
    JSR $8F52      ; Handle member 3
    JSR $8F6E      ; Handle member 4
    JSR $0E28      ; Upload BG1 A+B
    JSR $0E36      ; Upload BG1 C...
    JMP $0E6E      ; Upload BG3 A+B
.endproc

.segment "PTEXTMENUDRAWMEMBERGEARINGEAROVERVIEW"    ; $c38f96
    jsl _ff6vwf_menu_store_text_line_slot_for_gear_overview
    nopx 16

.segment "PTEXTMENUDRAWMEMBERNAMEINGEAROVERVIEWA"   ; $c38f28
    ldy #$790d      ; Text position

.segment "PTEXTMENUDRAWMEMBERNAMEINGEAROVERVIEWB"   ; $c38f42
    ldy #$7b0d      ; Text position

.segment "PTEXTMENUDRAWITEMTOBEUSED"        ; $c38a0e
    jsl _ff6vwf_menu_draw_item_to_be_used
    nopx 7

.segment "PTEXTMENUDRAWKEYITEM"         ; $c38460
    jml _ff6vwf_menu_draw_key_item
    stp     ; should never be reached

.segment "PTEXTMENUDRAWITEMMENU"        ; $c37de5
    jsl _ff6vwf_menu_draw_item_menu

.segment "PTEXTMENUDRAWEQUIPMENU"       ; $c3903c
    jsl _ff6vwf_menu_draw_equip_menu
    nopx 2

.segment "PTEXTMENUDRAWRELICMENU"       ; $c39081
    jsl _ff6vwf_menu_draw_relic_menu
    nopx 2

; Our own functions, in a separate bank
.segment "TEXT"

; farproc void _ff6vwf_menu_draw_inventory()
.proc _ff6vwf_menu_draw_inventory
ff6_menu_item_slot  = $e5
ff6_menu_bg1_row    = $e6

    jsr ff6vwf_menu_begin_transaction

    ; Stuff the original function did:
    ldy #10                                             ; Rows left: 10
:   phy                                                 ; Save counter
    jsl _ff6_draw_inventory_draw_item_info_trampoline   ; Draw item info
    inc ff6_menu_item_slot                              ; Next item slot
    lda ff6_menu_bg1_row                                ; BG1 row
    inc
    inc                                                 ; Two rows down
    and #$1f                                            ; Stay in limits
    sta ff6_menu_bg1_row                                ; BG1 row
    ply                                                 ; Restore rows left
    dey                                                 ; ... and decrement
    bne :-                                              ; Loop

    jsr ff6vwf_menu_commit_transaction
    rtl
.endproc

; farproc void _ff6vwf_menu_draw_equipment_name(inreg(A) uint8 item_id)
.proc _ff6vwf_menu_draw_equipment_name
begin_locals
    decl_local outgoing_args, 6
    decl_local item_id, 1
    decl_local string_ptr, 2
    decl_local first_tile_id, 1

    tax             ; Put item ID in X.

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Initialize locals.
    txa
    sta item_id

    ; Draw item icon.
    tax
    jsr ff6vwf_menu_draw_item_icon

    ; Fetch string pointer.
    ldx item_id
    jsr ff6vwf_get_long_item_name
    stx string_ptr

    ; Begin transaction.
    jsr ff6vwf_menu_begin_transaction

    ; Calculate first tile ID.
    lda f:ff6vwf_current_equipment_text_slot
    tax
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple
    txa
    sta first_tile_id

    ; Calculate base addr and DMA flags.
    lda f:ff6vwf_current_equipment_bg3
    bne :+
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    bra :++
:   lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
:

    ; Render string.
    sta outgoing_args+0     ; flags
    ldy string_ptr
    sty outgoing_args+1     ; string ptr
    lda #^ff6vwf_long_item_names
    sta outgoing_args+3     ; string ptr bank
    ldy #10                 ; max_tile_count
    jsr ff6vwf_render_string

    ; Commit transaction.
    jsr ff6vwf_menu_commit_transaction

    ; Draw tiles.
    ldx first_tile_id
    ldy #10
    lda f:ff6_short_item_name_length
    sub #10
    sta outgoing_args+0                 ; blanks_count
    lda #1
    sta outgoing_args+1                 ; initial_offset
    jsr ff6vwf_menu_draw_vwf_tiles

    leave __FRAME_SIZE__
    rtl
.endproc

; farpatch _ff6vwf_menu_draw_key_item()
.proc _ff6vwf_menu_draw_key_item
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__, STACK_LIMIT

    ldx #.loword(ff6vwf_long_key_item_names)
    stx outgoing_args+0
    lda #^ff6vwf_long_key_item_names
    sta outgoing_args+2
    ldx #FF6_SHORT_KEY_ITEM_NAME_LENGTH
    ldy #FF6VWF_MENU_DRAW_LIST_ITEM_FLAGS_KEY_ITEM
    jsr ff6vwf_menu_draw_list_item

    leave __FRAME_SIZE__
    jml ff6_menu_draw_string
.endproc

; farproc void _ff6vwf_menu_draw_inventory_item_name_for_item_menu()
.proc _ff6vwf_menu_draw_inventory_item_name_for_item_menu
    lda f:ff6_menu_list_slot
    tax
    tay
    jsr _ff6vwf_menu_draw_inventory_item_name

    pea $7fd6-1                 ; Return to $c37fd6.
    jml ff6_menu_draw_string
.endproc

; farproc void _ff6vwf_menu_draw_item_to_equip_name()
.proc _ff6vwf_menu_draw_item_to_equip_name
ff6_item_list = $7e9d8a

    lda f:ff6_menu_list_slot
    a16
    and #$00ff
    tax
    a8
    lda f:ff6_item_list,x
    txy
    tax
    jsr _ff6vwf_menu_draw_inventory_item_name
    tdc
    rtl
.endproc

; nearproc void _ff6vwf_menu_draw_inventory_item_name(uint8 inventory_slot, uint8 menu_item_index)
.proc _ff6vwf_menu_draw_inventory_item_name
    jsr _ff6vwf_menu_get_inventory_item_id
    jmp _ff6vwf_menu_draw_item_name_bg1
.endproc

.proc _ff6vwf_menu_get_inventory_item_id
ff6_inventory_ids = $7e1869

    a16
    txa
    and #$00ff
    tax
    a8
    lda f:ff6_inventory_ids,x
    tax
    rts
.endproc

; farproc void _ff6vwf_menu_draw_gear_info_text(uint8 unused, uint8 item_id)
.proc _ff6vwf_menu_draw_gear_info_text
begin_locals
    decl_local outgoing_args, 6
    decl_local item_id, 1               ; uint8
    decl_local offense_defense_text, 3  ; const struct static_text far *
    decl_local buffer, 64

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Save item ID.
    tyx
    jsr _ff6vwf_menu_get_inventory_item_id
    txa
    sta item_id

    ; Draw item icon.
    ldx item_id
    jsr ff6vwf_menu_draw_item_icon

    ; Initialize our buffer with the item name.
    ldx item_id
    jsr ff6vwf_get_long_item_name
    stx outgoing_args+3             ; src_ptr
    lda #^ff6vwf_long_item_names
    sta outgoing_args+5             ; src_ptr bank
    a16
    tdc
    add #buffer
    sta outgoing_args+0             ; dest_ptr
    a8
    lda #$7e
    sta outgoing_args+2             ; dest_ptr bank
    jsr std_stpcpy

    ; Append " can be used by:"
    stx outgoing_args+0             ; dest_ptr
    lda #$7e
    sta outgoing_args+2             ; dest_ptr bank
    ldx #.loword(ff6vwf_item_menu_can_be_used_by)
    stx outgoing_args+3             ; src_ptr
    lda #^ff6vwf_item_menu_can_be_used_by
    sta outgoing_args+5             ; src_ptr bank
    jsr std_stpcpy

    ; Begin transaction.
    jsr ff6vwf_menu_begin_transaction

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; flags
    a16
    tdc
    add #buffer
    sta outgoing_args+1     ; string_ptr
    a8
    lda #$7e
    sta outgoing_args+3     ; string_ptr bank byte
    ldx #FF6VWF_FIRST_TILE+ITEM_MENU_FIRST_CAN_BE_USED_BY_TILE
    ldy #ITEM_MENU_CAN_BE_USED_BY_TILE_COUNT
    jsr ff6vwf_render_string

    ; Draw tiles.
    ldx #FF6VWF_FIRST_TILE+ITEM_MENU_FIRST_CAN_BE_USED_BY_TILE
    ldy #ITEM_MENU_CAN_BE_USED_BY_TILE_COUNT
    stz outgoing_args+0                 ; blanks_count
    lda #1
    sta outgoing_args+1                 ; initial_offset
    jsr ff6vwf_menu_draw_vwf_tiles

    ; Upload stats labels.
    ldx #.loword(ff6vwf_stats_static_text_descriptor_bg3)
    stx outgoing_args+0
    lda #^ff6vwf_stats_static_text_descriptor_bg3
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE+ITEM_MENU_FIRST_STATS_TILE
    jsr ff6vwf_menu_render_static_strings

    ; Determine whether we should display offense or defense labels.
    ldx item_id
    ldy #$1e            ; sizeof(struct ff6_item_properties)
    jsr std_mul8
    lda f:$d85000,x     ; Get weapon properties.
    and #$07            ; Get the class.
    cmp #1              ; Is this a weapon?
    bne @is_armor       ; Branch if not.
    ldx #.loword(ff6vwf_item_menu_offense_text_descriptor)
    lda #^ff6vwf_item_menu_offense_text_descriptor
    bra @write_offense_defense_static_text
@is_armor:
    ldx #.loword(ff6vwf_item_menu_defense_text_descriptor)
    lda #^ff6vwf_item_menu_defense_text_descriptor
@write_offense_defense_static_text:
    stx offense_defense_text+0
    sta offense_defense_text+2      ; bank byte

    ; Upload attack/defense labels.
    ldx offense_defense_text+0
    stx outgoing_args+0
    lda offense_defense_text+2
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE
    jsr ff6vwf_menu_render_static_strings

    ; Commit transaction.
    jsr ff6vwf_menu_commit_transaction

    leave __FRAME_SIZE__
    rtl
.endproc

; patch _ff6vwf_menu_draw_equipped_item(inreg(A) uint8 item_id)
.proc _ff6vwf_menu_draw_equipped_item
RIGHT_HAND_POSITION = $7a1b
LEFT_HAND_POSITION  = $7a9b
HEAD_POSITION       = $7b1b
BODY_POSITION       = $7b9b

    tax                         ; Put item ID in X.

    a16
    lda f:ff6_menu_positioned_text_ptr
    sub #RIGHT_HAND_POSITION
    asl
    xba
    a8
    and #$03                    ; ((position - 0x7a1b) >> 7) & 3
    add #EQUIP_MENU_STRING_COUNT
    sta f:ff6vwf_current_equipment_text_slot
    lda #1
    sta f:ff6vwf_current_equipment_bg3

    txa
    jsl _ff6vwf_menu_draw_equipment_name

    jml ff6_menu_draw_string
.endproc

.proc _ff6vwf_menu_draw_gear_overview
    ; Set up BG3 HDMA to match BG1.
    LDA #$02        ; 1Rx2B to PPU
    STA f:DMAP6     ; Set DMA mode
    LDA #<BG3VOFS   ; $2112
    STA f:BBAD6     ; To BG1 V-Scroll
    a16
    lda #$95D8      ; C3/95D8
    sta f:A1T6L     ; Set src LBs
    a8
    LDA #$C3        ; Bank: C3
    STA f:A1B6      ; Set src HB
    LDA #$C3        ; ...
    STA f:DASB6     ; Set indir HB
    lda f:ff6_menu_queued_hdma
    ora #$40        ; Channel: 6
    sta f:ff6_menu_queued_hdma

    ; Stuff the original function did:
    lda #$02
    sta f:BG1SC
    rtl
.endproc

; farproc tiledata near *_ff6vwf_menu_store_text_line_slot_for_gear_overview(uint16 gear_slot)
.proc _ff6vwf_menu_store_text_line_slot_for_gear_overview
begin_locals
    decl_local gear_slot, 1
    decl_local x_pos, 1
    decl_local y_pos, 1
    decl_local base_addr, 2

ff6_menu_gear_overview_base_y       = $7e00e2
ff6_menu_gear_overview_x_positions  = $c38fd5
ff6_menu_gear_overview_y_positions  = $c38fdb

    enter __FRAME_SIZE__, STACK_LIMIT

    txa
    sta gear_slot

    ; Calculate text slot.
    lda f:ff6_menu_current_selection    ; Get party member index.
    and #$01
    beq :+
    lda #6
:   add gear_slot                       ; gear_slot + (party member % 2 == 1 ? 6 : 0)
    sta f:ff6vwf_current_equipment_text_slot

    ; Calculate which BG to use (BG1 for party members 0/1, BG3 for party members 2/3).
    lda f:ff6_menu_current_selection
    cmp #2
    bge :+
    lda #1
    ldy #.loword(ff6_menu_bg3_data)
    bra :++
:   lda #0
    ldy #.loword(ff6_menu_bg1_data)
:   sta f:ff6vwf_current_equipment_bg3
    sty base_addr

    ; Look up X and Y positions.
    lda f:ff6_menu_gear_overview_x_positions,x
    sta x_pos
    lda f:ff6_menu_gear_overview_y_positions,x
    add f:ff6_menu_gear_overview_base_y
    sta y_pos

    ; Calculate map pointer.
    lda y_pos
    a16
    and #$00ff
    xba
    lsri 3
    a8
    ora x_pos
    a16
    asl
    add base_addr           ; base_addr + (x + y * 0x20) * 2
    tax
    a8

    leave __FRAME_SIZE__
    rtl
.endproc

; nearproc uint8 _ff6vwf_menu_first_tile_id_for_list_item(uint8 text_line_slot,
;                                                         uint8 max_tile_count)
.proc _ff6vwf_menu_first_tile_id_for_list_item
begin_locals
    decl_local max_tile_count, 1

    enter __FRAME_SIZE__, STACK_LIMIT

    tya
    sta max_tile_count

    ; Compute the actual text line slot by modding the one we were given by 11.
    txa
    a16
    and #$00ff
    tax
    a8
    ldy #11
    jsr std_mod16_8

    ; Calculate first tile ID.
    ldy max_tile_count
    jsr ff6vwf_calculate_first_tile_id_simple

    leave __FRAME_SIZE__
    rts
.endproc

; nearproc void _ff6vwf_menu_draw_item_name_bg1(uint8 item_id, uint8 menu_item_index)
;
; This function will automatically mod the menu item index by 11 to get the text string index.
;
; Setup function at $c37f88
; Scroll position is at $4a, top BG1 write row is at $49, item slot at $e5
.proc _ff6vwf_menu_draw_item_name_bg1
begin_locals
    decl_local outgoing_args, 6
    decl_local item_id, 1
    decl_local string_ptr, 2
    decl_local text_line_slot, 1
    decl_local first_tile_id, 1

FF6_MENU_INVENTORY_ITEM_LENGTH  = 14

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Initialize locals.
    tya
    sta text_line_slot
    txa
    sta item_id

    ; If empty, blank item name and quantity.
    cmp #$ff
    bne :+
    ldx #.loword(ff6_menu_string_buffer)
    stx outgoing_args+0             ; dest
    lda #^ff6_menu_string_buffer
    sta outgoing_args+2             ; dest bank
    ldx #$ff
    ldy #16
    jsr std_memset
    lda #0
    sta ff6_menu_string_buffer+16
    bra @out

    ; Draw item icon.
:   tax
    jsr ff6vwf_menu_draw_item_icon

    ; Compute string pointer.
    ldx item_id
    jsr ff6vwf_get_long_item_name
    stx string_ptr

    ; Begin transaction.
    jsr ff6vwf_menu_begin_transaction

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy #10
    jsr _ff6vwf_menu_first_tile_id_for_list_item
    txa
    sta first_tile_id

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP | FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; flags
    ldy string_ptr
    sty outgoing_args+1
    lda #^ff6vwf_long_item_names
    sta outgoing_args+3
    ldy #10                 ; max_tile_count
    jsr ff6vwf_render_string

    ; Commit transaction.
    jsr ff6vwf_menu_commit_transaction

    ; Draw tiles.
    ldx first_tile_id
    ldy #10
    lda #FF6_MENU_INVENTORY_ITEM_LENGTH - 10 - 1
    sta outgoing_args+0                 ; blanks_count
    lda #1
    sta outgoing_args+1                 ; initial_offset
    jsr ff6vwf_menu_draw_vwf_tiles

@out:
    leave __FRAME_SIZE__
    a16
    lda #0
    a8
    rts
.endproc

; farproc void _ff6vwf_menu_draw_item_to_be_used()
.proc _ff6vwf_menu_draw_item_to_be_used
begin_locals
    decl_local outgoing_args, 5

TEXT_LINE_SLOT = 0

ff6_menu_cursor_selected_inventory_slot = $7e004b

    enter __FRAME_SIZE__, STACK_LIMIT

    lda f:ff6_menu_cursor_selected_inventory_slot
    tax
    jsr _ff6vwf_menu_get_inventory_item_id

    ldy #TEXT_LINE_SLOT
    jsr ff6vwf_menu_draw_item_name_bg3

    ; Upload "Owned:"
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; flags
    ldy #.loword(ff6vwf_item_usage_menu_owned_string)
    sty outgoing_args+1
    lda #^ff6vwf_item_usage_menu_owned_string
    sta outgoing_args+3
    ldx #FF6VWF_FIRST_TILE+10
    ldy #6                  ; max_tile_count
    jsr ff6vwf_render_string

    ; Upload "Knocked Out" in place of "Wounded"/"Dead"
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    sta outgoing_args+0     ; flags
    ldy #.loword(ff6vwf_menu_wounded_label)
    sty outgoing_args+1
    lda #^ff6vwf_menu_wounded_label
    sta outgoing_args+3
    ldx #FF6VWF_FIRST_TILE+FF6VWF_MENU_WOUNDED_START_TILE
    ldy #8                  ; max_tile_count
    jsr ff6vwf_render_string

    leave __FRAME_SIZE__

    ; For some reason we have to do this to prevent the cursor from disappearing...
    a16
    lda #0
    a8
    ldx #0
    ldy #0
    rtl
.endproc

; nearproc void ff6vwf_menu_draw_item_icon(uint8 item_id)
.proc ff6vwf_menu_draw_item_icon
    lda f:ff6_short_item_name_length
    tay
    jsr std_mul8
    lda ff6_short_item_names,x
    sta ff6_menu_string_buffer
    rts
.endproc

.export ff6vwf_menu_draw_item_icon

.proc _ff6vwf_menu_draw_item_menu
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__, STACK_LIMIT

    ldx #.loword(ff6vwf_item_menu_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_item_menu_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE
    jsr ff6vwf_menu_render_static_strings

    ; Stuff the original function did:
    lda #$20    ; Palette 0
    sta f:ff6_menu_bg_attrs

    leave __FRAME_SIZE__
    rtl
.endproc

.proc _ff6vwf_menu_draw_equip_menu
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Upload main labels.
    ldx #.loword(ff6vwf_equip_menu_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_equip_menu_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE
    jsr ff6vwf_menu_render_static_strings

    ; Upload stats labels.
    ldx #.loword(ff6vwf_stats_static_text_descriptor_bg3)
    stx outgoing_args+0
    lda #^ff6vwf_stats_static_text_descriptor_bg3
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE+EQUIP_MENU_FIRST_STATS_TILE
    jsr ff6vwf_menu_render_static_strings

    leave __FRAME_SIZE__

    ; Stuff the original function did:
    ldx #.loword(_equip_menu_positioned_text_a-12)  ; Text ptrs loc
    ldy #4                                          ; Strings: 2
    rtl
.endproc

.proc _ff6vwf_menu_draw_relic_menu
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Upload main labels.
    ldx #.loword(ff6vwf_relic_menu_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_relic_menu_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE
    jsr ff6vwf_menu_render_static_strings

    ; Upload stats labels.
    ldx #.loword(ff6vwf_stats_static_text_descriptor_bg3)
    stx outgoing_args+0
    lda #^ff6vwf_stats_static_text_descriptor_bg3
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE + EQUIP_MENU_FIRST_STATS_TILE
    jsr ff6vwf_menu_render_static_strings

    leave __FRAME_SIZE__

    ; Stuff the original function did:
    ldx #.loword(_equip_menu_positioned_text_a-4)   ; Text ptrs loc
    ldy #4                                          ; Strings: 2
    rtl
.endproc

; nearproc void ff6vwf_menu_draw_item_name_bg3(uint8 item_id, uint8 text_line_slot)
.proc ff6vwf_menu_draw_item_name_bg3
begin_locals
    decl_local outgoing_args, 6
    decl_local item_id, 1
    decl_local string_ptr, 2
    decl_local text_line_slot, 1
    decl_local first_tile_id, 1

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Initialize locals.
    txa
    sta item_id
    tya
    sta text_line_slot

    ; Draw item icon.
    ldx item_id
    jsr ff6vwf_menu_draw_item_icon

    ; Compute string pointer.
    ldx item_id
    jsr ff6vwf_get_long_item_name
    stx string_ptr

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple
    txa                     ; first_tile_id
    sta first_tile_id

    ; Commit transaction.
    jsr ff6vwf_menu_begin_transaction

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; flags
    ldy string_ptr
    sty outgoing_args+1
    lda #^ff6vwf_long_item_names
    sta outgoing_args+3
    ldy #10                 ; max_tile_count
    jsr ff6vwf_render_string

    ; Commit transaction.
    jsr ff6vwf_menu_commit_transaction

    ; Draw tiles.
    ldx first_tile_id
    ldy #10                             ; tile count
    lda #3
    sta outgoing_args+0                 ; blanks_count
    lda #1
    sta outgoing_args+1                 ; initial_offset
    jsr ff6vwf_menu_draw_vwf_tiles

    leave __FRAME_SIZE__
    rts
.endproc

.export ff6vwf_menu_draw_item_name_bg3

; ROM data patches

.segment "PTEXTMENUITEMMENUPOSITIONEDTEXT"      ; $c38d16

.word $790d
    def_static_text_tiles_z 0, .strlen("Item"), 3
.word $791d
    def_static_text_tiles_z 3, .strlen("USE"), 2
.word $7927
    def_static_text_tiles_z 5, .strlen("ARRANGE"), 3
.word $7939
    def_static_text_tiles_z 8, .strlen("RARE"), 2

.segment "PTEXTMENUITEMUSAGEPOSITIONEDTEXT"     ; $c38e41

.word $7a0d
    def_static_text_tiles_z 10, .strlen("Owned:"), -1

.segment "PTEXTMENUGEARINFOMENUPCNAMEPOSITIONS"     ; $c38653

.word $7E0F        ; Actor name 1
.word $7E23        ; Actor name 2
.word $7E37        ; Actor name 3
.word $7E8F        ; Actor name 4
.word $7EA3        ; Actor name 5
.word $7EB7        ; Actor name 6
.word $7F0F        ; Actor name 7
.word $7F23        ; Actor name 8
.word $7F37        ; Actor name 9
.word $7F8F        ; Actor name 10
.word $7FA3        ; Actor name 11
.word $7FB7        ; Actor name 12
.word $800F        ; Actor name 13
.word $8023        ; Actor name 14
.word $8037        ; Actor name 15 (unused)

.segment "PTEXTMENUGEARINFOMENUPOSITIONEDTEXT"  ; $c38d71

.word $8643
    ff6_def_charset_string_z "???"
.word $842f                         ; "Vigor"
    def_static_text_tiles_z ITEM_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_STRENGTH, FF6VWF_STATS_TILE_COUNT_STRENGTH, -1
.word $852f
    def_static_text_tiles ITEM_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_STAMINA, FF6VWF_STATS_TILE_COUNT_STAMINA, -1
    .byte $ff, $ff, 0               ; "Stamina"
.word $85af
    def_static_text_tiles ITEM_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_MAGIC, FF6VWF_STATS_TILE_COUNT_MAGIC, -1
    .byte $ff, $ff, $ff, $ff, 0     ; "Mag.Pwr"
.word $872f
    def_static_text_tiles ITEM_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_EVASION, FF6VWF_STATS_TILE_COUNT_EVASION, -1
    .byte $ff, $ff, 0               ; "Evade %"
.word $882f                         ; "MBlock%"
    def_static_text_tiles_z ITEM_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_MAGIC_EVASION, FF6VWF_STATS_TILE_COUNT_MAGIC_EVASION, -1
.word $843F
    .byte $ff, $00
.word $84BF
    .byte $ff, $00
.word $853F
    .byte $ff, $00
.word $85BF
    .byte $ff, $00
.word $863F
    .byte $ff, $00
.word $86BF
    .byte $ff, $00
.word $873F
    .byte $ff, $00
.word $87BF
    .byte $ff, $00
.word $883F
    .byte $ff, $00
.word $84af
    def_static_text_tiles ITEM_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_SPEED, FF6VWF_STATS_TILE_COUNT_SPEED, -1
    .byte $ff, 0                        ; "Speed"
.word $862f
    def_static_text_tiles ITEM_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_ATTACK, FF6VWF_STATS_TILE_COUNT_ATTACK, -1
    .byte $ff, $ff, $ff, 0              ; "Bat.Pwr"
.word $86af
    def_static_text_tiles ITEM_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_DEFENSE, FF6VWF_STATS_TILE_COUNT_DEFENSE, -1
    .byte $ff, $ff, 0                   ; "Defense"
.word $87af                             ; "Mag.Def"
    def_static_text_tiles_z ITEM_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_MAGIC_DEFENSE, .strlen("Mag.Def"), 6
.word $7B8D
    def_static_text_tiles_z 10, .strlen("50% Dmg"), 5
.word $7BA9
    def_static_text_tiles_z 15, .strlen("Absorb HP"), 5
.word $7C8D
    def_static_text_tiles_z 20, .strlen("No Effect"), 5
.word $7CA9
    def_static_text_tiles_z 25, .strlen("Weak pt"), 7
.word $7B8D
    def_static_text_tiles_z ITEM_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_ATTACK, 6, FF6VWF_STATS_TILE_COUNT_ATTACK
.word $822F
    def_static_text_tiles_z 21, .strlen("SwdTech"), -1
.word $82AF
    def_static_text_tiles_z 10, 4, -1    ; "Runic"
_weapon_properties_two_handed_string:
.word $832F
    def_static_text_tiles_z 14, 7, -1    ; "2-hand"/"Two-handed"

.segment "PTEXTMENUEQUIPMENUPOSITIONEDTEXTA"    ; $c3a2ba
_equip_menu_positioned_text_a:

; Positioned text for Equip and Relic menus
.word $7a0d
    def_static_text_tiles_z 18, .strlen("R-hand"), -1
.word $7a8d
    def_static_text_tiles_z 24, .strlen("L-hand"), -1
.word $7b0d
    def_static_text_tiles_z 30, .strlen("Head"), 3
.word $7b8d
    def_static_text_tiles_z 33, .strlen("Body"), 3
.word $7b0d
    def_static_text_tiles_z 8, .strlen("Relic"), 3
.word $7b8d
    def_static_text_tiles_z 8, .strlen("Relic"), 3

; Positioned spaces for blanking options and title in gear menus
.word $790d
    ff6_def_charset_string_z "                            "

; Positioned text for title in Equip and Relic menus
.word $7939
    def_static_text_tiles_z 0, .strlen("EQUIP"), 3
.word $7939
    def_static_text_tiles_z 3, .strlen("REMOVE"), 5

; Positioned text for options in Equip menu
.word $790d
    def_static_text_tiles_z 0, .strlen("EQUIP"), 3
.word $791b
    def_static_text_tiles_z 8, .strlen("OPTIMUM"), 6
.word $792d
    def_static_text_tiles_z 3, .strlen("RMOVE"), -1
.word $793b
    def_static_text_tiles_z 14, .strlen("EMPTY"), 4

; Positioned text for options in Relic menu
.word $7911
    def_static_text_tiles_z 0, .strlen("EQUIP"), 3
.word $791f
    def_static_text_tiles_z 3, .strlen("REMOVE"), 5

.segment "PTEXTMENUEQUIPMENUPOSITIONEDTEXTB"    ; $c3a371
_equip_menu_positioned_text_b:
.word $7ca9                         ; "Vigor"
    def_static_text_tiles_z EQUIP_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_STRENGTH, FF6VWF_STATS_TILE_COUNT_STRENGTH, -1
.word $7da9
    def_static_text_tiles EQUIP_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_STAMINA, FF6VWF_STATS_TILE_COUNT_STAMINA, -1
    .byte $ff, $ff, 0               ; "Stamina"
.word $7e29
    def_static_text_tiles EQUIP_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_MAGIC, FF6VWF_STATS_TILE_COUNT_MAGIC, -1
    .byte $ff, $ff, $ff, $ff, 0     ; "Mag.Pwr"
.word $7fa9
    def_static_text_tiles EQUIP_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_EVASION, FF6VWF_STATS_TILE_COUNT_EVASION, -1
    .byte $ff, $ff, 0               ; "Evade %"
.word $80a9                         ; "MBlock%"
    def_static_text_tiles_z EQUIP_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_MAGIC_EVASION, FF6VWF_STATS_TILE_COUNT_MAGIC_EVASION, -1
.word $7cbd
    .byte $d5, $00
.word $7d3d
    .byte $d5, $00
.word $7dbd
    .byte $d5, $00
.word $7e3d
    .byte $d5, $00
.word $7f3d
    .byte $d5, $00
.word $7fbd
    .byte $d5, $00
.word $7ebd
    .byte $d5, $00
.word $803d
    .byte $d5, $00
.word $80bd
    .byte $d5, $00
.word $7d29
    def_static_text_tiles EQUIP_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_SPEED, FF6VWF_STATS_TILE_COUNT_SPEED, -1
    .byte $ff, 0                        ; "Speed"
.word $7ea9
    def_static_text_tiles EQUIP_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_ATTACK, FF6VWF_STATS_TILE_COUNT_ATTACK, -1
    .byte $ff, $ff, $ff, 0              ; "Bat.Pwr"
.word $7f29
    def_static_text_tiles EQUIP_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_DEFENSE, FF6VWF_STATS_TILE_COUNT_DEFENSE, -1
    .byte $ff, $ff, 0                   ; "Defense"
.word $8029                             ; "Mag.Def"
    def_static_text_tiles_z EQUIP_MENU_FIRST_STATS_TILE+FF6VWF_STATS_TILE_INDEX_MAGIC_DEFENSE, .strlen("Mag.Def"), 6
.word $7923
    ff6_def_charset_string_z "     "
.word $7921
    ff6_def_charset_string_z "       "
.word $79a3
    ff6_def_charset_string_z "     "
.word $79a1
    ff6_def_charset_string_z "       "
.word $7a15
    def_static_text_tiles_z 11, .strlen("Equipment changed."), -1

; Constant data

.segment "DATA"

; Item usage menu labels

ff6vwf_item_usage_menu_owned_string: .asciiz "Owned:"

; Items menu labels

ff6vwf_item_menu_static_text_descriptor:
    .byte ITEM_MENU_STRING_COUNT                ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU        ; DMA flags
    .faraddr ff6vwf_item_menu_labels            ; strings
    .faraddr ff6vwf_item_menu_tile_counts       ; tile counts
    .faraddr ff6vwf_item_menu_start_tiles       ; start tiles

ff6vwf_item_menu_labels: ff6vwf_def_pointer_array ff6vwf_item_menu_label, ITEM_MENU_STRING_COUNT
ff6vwf_item_menu_tile_counts: .byte 3, 2, 3, 2
ff6vwf_item_menu_start_tiles: .byte 0, 3, 5, 8

ff6vwf_item_menu_label_0:  .asciiz "Items"
ff6vwf_item_menu_label_1:  .asciiz "Use"
ff6vwf_item_menu_label_2:  .asciiz "Sort"
ff6vwf_item_menu_label_3:  .asciiz "Key"

ff6vwf_item_menu_can_be_used_by: .asciiz " can be used by:"

ff6vwf_item_menu_offense_text_descriptor:
    .byte ITEM_MENU_OFFENSE_STRING_COUNT            ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU            ; DMA flags
    .faraddr ff6vwf_item_menu_offense_labels        ; strings
    .faraddr ff6vwf_item_menu_offense_tile_counts   ; tile counts
    .faraddr ff6vwf_item_menu_offense_start_tiles   ; start tiles

ff6vwf_item_menu_offense_labels:
    ff6vwf_def_pointer_array ff6vwf_item_menu_offense_label, ITEM_MENU_OFFENSE_STRING_COUNT
ff6vwf_item_menu_offense_tile_counts: .byte  4,  7,  6
ff6vwf_item_menu_offense_start_tiles: .byte 10, 14, 21

ff6vwf_item_menu_offense_label_0:   .asciiz "Runic"
ff6vwf_item_menu_offense_label_1:   .asciiz "Two-handed"
ff6vwf_item_menu_offense_label_2:   .asciiz "Bushido"

ff6vwf_item_menu_defense_text_descriptor:
    .byte ITEM_MENU_DEFENSE_STRING_COUNT            ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU            ; DMA flags
    .faraddr ff6vwf_item_menu_defense_labels        ; strings
    .faraddr ff6vwf_item_menu_defense_tile_counts   ; tile counts
    .faraddr ff6vwf_item_menu_defense_start_tiles   ; start tiles

ff6vwf_item_menu_defense_labels:
    ff6vwf_def_pointer_array ff6vwf_item_menu_defense_label, ITEM_MENU_DEFENSE_STRING_COUNT
ff6vwf_item_menu_defense_tile_counts: .byte 5,  5,  5,  7
ff6vwf_item_menu_defense_start_tiles: .byte 10, 15, 20, 25

ff6vwf_item_menu_defense_label_0:   .asciiz "Resists"
ff6vwf_item_menu_defense_label_1:   .asciiz "Absorbs"
ff6vwf_item_menu_defense_label_2:   .asciiz "Nullifies"
ff6vwf_item_menu_defense_label_3:   .asciiz "Weak against"

; Equip menu labels

ff6vwf_equip_menu_static_text_descriptor:
    .byte EQUIP_MENU_STRING_COUNT               ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU        ; DMA flags
    .faraddr ff6vwf_equip_menu_labels           ; strings
    .faraddr ff6vwf_equip_menu_tile_counts      ; tile counts
    .faraddr ff6vwf_equip_menu_start_tiles      ; start tiles

ff6vwf_equip_menu_labels:
    ff6vwf_def_pointer_array ff6vwf_equip_menu_label, EQUIP_MENU_STRING_COUNT

ff6vwf_equip_menu_tile_counts: .byte 3, 5, 6,  4,  6,  6,  3,  3
ff6vwf_equip_menu_start_tiles: .byte 0, 3, 8, 14, 18, 24, 30, 33

ff6vwf_equip_menu_label_0:  .asciiz "Equip"         ; 3 tiles, 8-11
ff6vwf_equip_menu_label_1:  .asciiz "Remove"        ; 5 tiles, 11-16
ff6vwf_equip_menu_label_2:  .asciiz "Auto-Equip"    ; 6 tiles, 16-22
ff6vwf_equip_menu_label_3:  .asciiz "Empty"         ; 4 tiles, 22-26
ff6vwf_equip_menu_label_4:  .asciiz "Right Hand"    ; 6 tiles, 26-32
ff6vwf_equip_menu_label_5:  .asciiz "Left Hand"     ; 6 tiles, 32-38
ff6vwf_equip_menu_label_6:  .asciiz "Head"          ; 3 tiles, 38-41
ff6vwf_equip_menu_label_7:  .asciiz "Body"          ; 3 tiles, 41-44

; Relic menu labels

ff6vwf_relic_menu_static_text_descriptor:
    .byte RELIC_MENU_STRING_COUNT           ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU    ; DMA flags
    .faraddr ff6vwf_relic_menu_labels       ; strings
    .faraddr ff6vwf_relic_menu_tile_counts  ; tile counts
    .faraddr ff6vwf_relic_menu_start_tiles  ; start tiles

ff6vwf_relic_menu_labels:
    ff6vwf_def_pointer_array ff6vwf_relic_menu_label, RELIC_MENU_STRING_COUNT

ff6vwf_relic_menu_tile_counts: .byte 3, 5, 3, 20
ff6vwf_relic_menu_start_tiles: .byte 0, 3, 8, 11

ff6vwf_relic_menu_label_0: .asciiz "Equip"
ff6vwf_relic_menu_label_1: .asciiz "Remove"
ff6vwf_relic_menu_label_2: .asciiz "Relic"
ff6vwf_relic_menu_label_3: .asciiz "The available equipment changed."

ff6vwf_stats_static_text_descriptor_bg3:
    .byte FF6VWF_STATS_STRING_COUNT         ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU    ; DMA flags
    .faraddr ff6vwf_stats_labels            ; strings
    .faraddr ff6vwf_stats_tile_counts       ; tile counts
    .faraddr ff6vwf_stats_start_tiles       ; start tiles
