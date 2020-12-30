; snes-vwf/ff6/menu.s
;
; Final Fantasy 6 variable-width font patches specific to the menu

.p816
.i16
.a8
.feature c_comments

.include "ff6.inc"
.include "../snes.inc"

.import std_memcpy: near
.import std_mod16_8: near

.import ff6vwf_calculate_first_tile_id_simple:  near
.import ff6vwf_menu_force_nmi_trampoline:       far
.import ff6vwf_render_string:                   near
.import ff6vwf_transcode_string:                near
.import ff6vwf_long_command_names:              far
.import ff6vwf_long_class_names:                far
.import ff6vwf_long_enemy_names:                far

; Types

.struct static_text
    count .byte                 ; count
    dma_flags .byte             ; dma_flags
    strings .faraddr            ; const char far **
    tile_counts .faraddr        ; const uint8 far *
    start_tiles .faraddr        ; const uint8 far *
.endstruct

; Constants

MAIN_MENU_STRING_COUNT      = 19

; FF6-specific macros

.define bg3_position(col, row)  .loword(ff6_menu_bg3_data) + row * $40 + col * 2

.segment "BSS"

; Menu BSS

.org $7f0000

; Current of the stack *in bytes*.
ff6vwf_menu_text_dma_stack_size: .res 1
; The party member ID corresponding to the last character class drawn in the Lineup menu. This
; avoids uploading every frame, which causes flicker.
ff6vwf_last_lineup_class: .res 1
; The address of the PC info corresponding to the last character name drawn in the Lineup menu.
; This avoids uploading every frame, which causes flicker.
ff6vwf_last_lineup_pc_addr: .res 2
; A bitset of PC names that have been drawn in the Kefka lineup menu. Like the Lineup menu, it
; redraws PC names every frame, so we need to work around this to avoid lag.
ff6vwf_menu_kefka_lineup_drawn_pc_names: .res 2
; Stack of DMA structures, just like the encounter ones.
ff6vwf_menu_text_dma_stack_base: .res FF6VWF_DMA_STRUCT_SIZE * FF6VWF_MENU_SLOT_COUNT
; Buffer space for the lines of text, `FF6VWF_MAX_LINE_LENGTH` each to be stored, ready to be
; uploaded to VRAM.
ff6vwf_menu_text_tiles: .res VWF_TILE_BYTE_SIZE_4BPP * 128
; The slot to use when drawing current equipment.
ff6vwf_current_equipment_text_slot: .res 1
; True if we're drawing current equipment to BG3, false if BG1.
ff6vwf_current_equipment_bg3: .res 1
; True if we need to redraw the current menu, false otherwise.
ff6vwf_menu_redraw_needed: .res 1

.export ff6vwf_menu_kefka_lineup_drawn_pc_names:    far
.export ff6vwf_menu_text_dma_stack_base:            far
.export ff6vwf_menu_text_tiles:                     far
.export ff6vwf_menu_text_dma_stack_size:            far
.export ff6vwf_current_equipment_text_slot:         far
.export ff6vwf_current_equipment_bg3:               far
.export ff6vwf_menu_redraw_needed:                  far

.reloc 

; Patches to Final Fantasy 6 functions

; Final Fantasy 6 menu patches

.segment "PTEXTMENUINIT"
    jml _ff6vwf_menu_init

; Part of the code that initializes the main menu. We patch it to reload BG1 and BG3 graphics,
; since the submenus might have trashed them.
.segment "PTEXTMENUMAINMENUINIT"            ; $c31a96
    jsl _ff6vwf_menu_main_menu_init

; Note that the Kefka lineup code will jump into the middle of this instruction without the
; special-case `_ff6vwf_menu_draw_pc_name_for_kefka_lineup`.
.segment "PTEXTMENUDRAWPCNAME"              ; $c334cf
ff6_menu_draw_pc_name:
    jsl _ff6vwf_menu_draw_pc_name_general
    rts

.export ff6_menu_draw_pc_name: far

.segment "PTEXTMENUDRAWMAINMENU"        ; $c33221
    jsl _ff6vwf_menu_draw_main_menu

.segment "PTEXTMENUDRAWCLASSNAME"           ; $c3f0a6
    jsl _ff6vwf_menu_draw_class_name

; The "refresh screen" routine for the FF6 menu NMI/VBLANK handler. We patch it to upload our text
; if needed.
.segment "PTEXTMENURUNDMA"              ; $c31412
ff6_menu_refresh_mode_7 = $c3d263
ff6_menu_refresh_oam    = $c31463
ff6_menu_refresh_cgram  = $c314d2
ff6_menu_do_vram_dma_a  = $c31488
ff6_menu_do_vram_dma_b  = $c314ac

    jsl _ff6vwf_menu_run_dma_setup
    jsr .loword(ff6_menu_refresh_mode_7)
    jsr .loword(ff6_menu_refresh_oam)
    jsr .loword(ff6_menu_refresh_cgram)

    ; We have priority over the VRAM DMA that FF6 wants to do.
    ;
    ; For this to work, we must eagerly trigger NMI every time we render some text.
    jsl _ff6vwf_menu_run_dma
    cpy #0
    bne @we_did_dma

    jsr .loword(ff6_menu_do_vram_dma_a)
    jsr .loword(ff6_menu_do_vram_dma_b)
@we_did_dma:
    rts

; Our own functions, in a separate bank
.segment "TEXT"

; Menu functions

.proc _ff6vwf_menu_init
ff6_reset_vars = $d4cdf3

    ; Stuff the original function did
    jsl ff6_reset_vars      ; Reset many vars

    ; Initialize globals.
    lda #0
    sta f:ff6vwf_menu_text_dma_stack_size
    a16
    lda #$ffff
    sta f:ff6vwf_last_lineup_pc_addr
    a8
    sta f:ff6vwf_last_lineup_class
    lda #0
    sta f:ff6vwf_menu_redraw_needed

    ; Return.
    jml $c368fe
.endproc

; farproc void _ff6vwf_menu_main_menu_init()
.proc _ff6vwf_menu_main_menu_init
ff6_load_bg3_font_gfx = $c36b13

    jsl _ff6_menu_load_bg1_font_gfx_trampoline  ; Draw BG1 font gfx.
    jsl _ff6_menu_load_bg3_font_gfx_trampoline  ; Draw BG3 font gfx.
    jsl _ff6_menu_load_skin_gfx_trampoline      ; Have to reload the skin.

    ; Stuff the original function did:
    lda f:$7e0043
    ora #$04
    sta f:$7e0043   ; Queue Win1 HDMA

    rtl
.endproc

; farproc void _ff6vwf_menu_draw_pc_name_general(uint8 unused, tiledata near *tilemap_addr)
.proc _ff6vwf_menu_draw_pc_name_general
.struct locals
    .org 1
    outgoing_args .byte 6
.endstruct

TILEMAP_DEST_LINEUP = $3adb
TILEMAP_DEST_NAMING = $4229

    enter .sizeof(locals), STACK_LIMIT

    ; Store tilemap pointer.
    a16
    tya
    sta f:ff6_menu_positioned_text_ptr
    a8

    ; If this is the Lineup menu, then don't redraw the name if we've already drawn it, to avoid
    ; flicker.
    cpy #TILEMAP_DEST_LINEUP
    bne @not_lineup
    a16
    lda f:ff6_menu_actor_address
    cmp f:ff6vwf_last_lineup_pc_addr
    sta f:ff6vwf_last_lineup_pc_addr
    a8
    bne @not_lineup

    ; Just draw tiles; don't render or upload the name.
    ldx #60
    ldy #FF6_SHORT_PC_NAME_LENGTH
    stz locals::outgoing_args+0         ; blanks_count
    stz locals::outgoing_args+1         ; initial_offset
    jsr ff6vwf_menu_draw_vwf_tiles
    bra @return

    ; If this is the PC naming menu, don't use the VWF to emphasize the name length limit.
@not_lineup:
    cpy #TILEMAP_DEST_NAMING
    bne @not_lineup_or_naming

    a16
    lda f:ff6_menu_actor_address
    add #2
    sta locals::outgoing_args+3     ; src_ptr
    lda #.loword(ff6_menu_string_buffer)
    sta locals::outgoing_args+0     ; dest_ptr
    a8
    lda #$7e
    sta locals::outgoing_args+5     ; src_ptr, bank byte
    sta locals::outgoing_args+2     ; dest_ptr, bank byte
    jsr std_memcpy

    lda #0
    sta f:ff6_menu_string_buffer+6  ; Null terminate.
    bra @return

    ; Store positioned text pointer.
@not_lineup_or_naming:
    a16
    tya
    sta f:ff6_menu_positioned_text_ptr

    ; Find the tile ID.
    ldx #0
:   lda f:_ff6vwf_menu_pc_name_address_table,x
    cmp f:ff6_menu_positioned_text_ptr
    beq @found_tile_id
    addix 3
    cpx #_ff6vwf_menu_pc_name_address_table_end-_ff6vwf_menu_pc_name_address_table
    bne :-
    lda #0      ; fallback
    a8
    bra @store_tile_id
@found_tile_id:
    a8
    lda f:_ff6vwf_menu_pc_name_address_table+2,x
@store_tile_id:
    tax     ; first_tile_id
    jsr ff6vwf_menu_draw_pc_name

@return:
    leave .sizeof(locals)
    ply
    pla
    phy                                 ; Remove bank byte.
    jml ff6_menu_draw_string            ; Draw item name.
    ;rtl
.endproc

; nearproc void ff6vwf_menu_draw_pc_name(uint8 first_tile_id)
.proc ff6vwf_menu_draw_pc_name
begin_locals
    decl_local outgoing_args, 6
    decl_local first_tile_id, 1
    decl_local dma_flags, 1
    decl_local name_buffer, 7       ; char[7]

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Store arguments.
    txa
    sta first_tile_id

    ; Copy PC name.
    a16
    lda f:ff6_menu_actor_address
    add #2                  ; Move to name.
    sta outgoing_args+3     ; src_ptr
    tdc
    add #name_buffer
    sta outgoing_args+0     ; dest_ptr
    a8
    lda #$7e
    sta outgoing_args+2     ; dest_ptr, bank byte
    sta outgoing_args+5     ; src_ptr, bank byte
    ldx #FF6_SHORT_PC_NAME_LENGTH
    jsr ff6vwf_transcode_string

    ; Calculate base address and DMA flags.
    a16
    lda f:ff6_menu_positioned_text_ptr
    cmp #$7000
    a8
    bge @bg3
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    bra @store_dma_flags_and_base_addr
@bg3:
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
@store_dma_flags_and_base_addr:
    sta dma_flags

    ; Render string.
    lda dma_flags
    sta outgoing_args+0             ; flags
    a16
    tdc
    add #name_buffer
    sta outgoing_args+1             ; string ptr
    a8
    lda #$7e
    sta outgoing_args+3             ; string ptr bank
    ldx first_tile_id               ; first_tile_id
    ldy #FF6_SHORT_PC_NAME_LENGTH   ; max_tile_count
    jsr ff6vwf_render_string

    ; Upload it now.
    jsr ff6vwf_menu_force_nmi

    ; Draw tiles.
    ldx first_tile_id
    ldy #FF6_SHORT_PC_NAME_LENGTH
    stz outgoing_args+0                 ; blanks_count
    stz outgoing_args+1                 ; initial_offset
    jsr ff6vwf_menu_draw_vwf_tiles

    leave __FRAME_SIZE__
    rts
.endproc

.export ff6vwf_menu_draw_pc_name

; Table of addresses for PC names.
;
; These start at 0, not `FF6VWF_FIRST_TILE`.

_ff6vwf_menu_pc_name_address_table:
.word $3a4f
    .byte 10+6*0    ; $c3174d -- Leader info over save file 1
.word $3c0f
    .byte 10+6*1    ; $c317fa -- Leader info over save file 2
.word $3dcf
    .byte 10+6*2    ; $c3185d -- Leader info over save file 3
.word $3919
    .byte 60+6*0    ; $c332f1 -- Party member info 1
.word $3a99
    .byte 60+6*1    ; $c3333d -- Party member info 2
.word $3c19
    .byte 60+6*2    ; $c33389 -- Party member info 3
.word $3d99
    .byte 60+6*3    ; $c333d5 -- Party member info 3
.word $798f
    .byte 105       ; $c344b4 -- Command Set menu text, member 1
.word $7b4f
    .byte 111       ; $c344ed -- Command Set menu text, member 2
.word $7d0f
    .byte 192       ; $c34526 -- Command Set menu text, member 3
.word $7ecf
    .byte 198       ; $c3455f -- Command Set menu text, member 4
.word $7bcf
    .byte 60+6*0    ; $c347b4 -- Controller menu text, member 1
.word $7c4f
    .byte 60+6*1    ; $c347f1 -- Controller menu text, member 2
.word $7ccf
    .byte 60+6*2    ; $c3482e -- Controller menu text, member 3
.word $7d4f
    .byte 60+6*3    ; $c3486b -- Controller menu text, member 4
.word $398f
    .byte $4e       ; $c35fbb -- Status menu
.word $3adb
    .byte 60        ; $c37953 -- Lineup menu
.word $790d
    .byte $eb       ; $c38f1c -- Party gear overview, member 1
.word $7b0d
    .byte $fb       ; $c38f36 -- Party gear overview, member 2
.word $3d0d
    .byte $eb       ; $c38f52 -- Party gear overview, member 3
.word $3f0d
    .byte $fb       ; $c38f6e -- Party gear overview, member 3
.word $7bb7
    .byte $eb       ; $c393e5 -- Equip or Relic menu
.word $7c11
    .byte 80        ; $c3aed9 -- Shadow at Colosseum
.word $7c75
    .byte 60        ; $c3b2a5 -- Colosseum challenger
.word bg3_position 3, 23
    .byte 114+0*6   ; $c38623 -- Gear info, "can be used by:", PC 1
.word bg3_position 13, 23
    .byte 114+1*6   ; $c38623 -- Gear info, "can be used by:", PC 2
.word bg3_position 23, 23
    .byte 114+2*6   ; $c38623 -- Gear info, "can be used by:", PC 3
.word bg3_position 3, 25
    .byte 114+3*6   ; $c38623 -- Gear info, "can be used by:", PC 4
.word bg3_position 13, 25
    .byte 114+4*6   ; $c38623 -- Gear info, "can be used by:", PC 5
.word bg3_position 23, 25
    .byte 114+5*6   ; $c38623 -- Gear info, "can be used by:", PC 6
.word bg3_position 3, 27
    .byte 114+6*6   ; $c38623 -- Gear info, "can be used by:", PC 7
.word bg3_position 13, 27
    .byte 114+7*6   ; $c38623 -- Gear info, "can be used by:", PC 8
.word bg3_position 23, 27
    .byte 114+8*6   ; $c38623 -- Gear info, "can be used by:", PC 9
.word bg3_position 3, 29
    .byte 114+9*6   ; $c38623 -- Gear info, "can be used by:", PC 10
.word bg3_position 13, 29
    .byte 114+10*6  ; $c38623 -- Gear info, "can be used by:", PC 11
.word bg3_position 23, 29
    .byte 235+0*6   ; $c38623 -- Gear info, "can be used by:", PC 12
.word bg3_position 3, 31
    .byte 235+1*6   ; $c38623 -- Gear info, "can be used by:", PC 13
.word bg3_position 13, 31
    .byte 235+2*6   ; $c38623 -- Gear info, "can be used by:", PC 14
.word bg3_position 23, 31
    .byte 0         ; $c38623 -- Gear info, "can be used by:", PC 15 (unused)

; TODO(tachiweasel): Colosseum members

_ff6vwf_menu_pc_name_address_table_end:

; nearproc void ff6vwf_menu_draw_vwf_tiles(uint8 first_tile_id,
;                                          uint8 text_tile_count,
;                                          uint8 blanks_count,
;                                          uint8 initial_offset)
.proc ff6vwf_menu_draw_vwf_tiles
begin_locals
    decl_local first_tile_index, 1
    decl_local text_tile_count, 1
begin_args_nearcall
    decl_arg blanks_count, 1
    decl_arg offset, 1

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Initialize locals.
    txa
    sta first_tile_index
    tya
    sta text_tile_count

    ; Put offset in X.
    lda offset
    a16
    and #$00ff
    tax
    a8

    ; Put text tile count in Y.
    lda text_tile_count
    a16
    and #$00ff
    tay
    a8

    ; Draw tiles.
    lda first_tile_index
    cpy #0
:   beq :+
    sta ff6_menu_string_buffer,x
    inc
    inx
    dey
    bra :-
:

    ; Put blanks in Y.
    lda blanks_count
    a16
    and #$00ff
    tay
    a8

    ; Draw blanks.
    lda #$ff
    cpy #0
:   beq :+
    sta ff6_menu_string_buffer,x
    inx
    dey
    bra :-
:

    ; Null terminate.
    lda #0
    sta ff6_menu_string_buffer,x

    leave __FRAME_SIZE__
    rts
.endproc

.export ff6vwf_menu_draw_vwf_tiles

; nearproc void ff6vwf_menu_force_nmi()
;
; Just like FF6's "force NMI" routine at $c31368, but without messing with the force blank
; (INIDISP) settings. This allows us to wait for NMIs without turning the screen on, which might
; confuse FF6 and cause it to try to perform DMA with the screen on.
.proc ff6vwf_menu_force_nmi
ff6_menu_nmi_requested    = $7e0024
ff6_menu_mosaic           = $7e00b5
ff6_menu_allow_sfx_repeat = $7e00ae

    lda #$81                        ; Stop IRQ timers
    sta f:NMITIMEN                  ; On: NMI, joypads
    sta f:ff6_menu_nmi_requested    ; Mark NMI request
    cli                             ; Unmask IRQs
:   lda f:ff6_menu_nmi_requested    ; Back from NMI?
    bne :-                          ; Loop if not
    sei                             ; Mask IRQs
    lda f:ff6_menu_queued_hdma      ; Queued HDMA
    sta f:HDMAEN                    ; Update channels
    lda f:ff6_menu_mosaic           ; Mosaic settings
    sta f:MOSAIC                    ; Apply to screen
    lda #0
    sta f:ff6_menu_allow_sfx_repeat ; Allow SFX repeat
    rts
.endproc

.export ff6vwf_menu_force_nmi

; nearproc void _ff6vwf_menu_commit_transaction()
;
; Flushes all DMA.
.proc _ff6vwf_menu_commit_transaction
    lda f:ff6vwf_menu_text_dma_stack_size
@loop:
    beq @out
    jsr ff6vwf_menu_force_nmi
    lda f:ff6vwf_menu_text_dma_stack_size
    bra @loop
@out:
    rts
.endproc

; nearproc void ff6vwf_menu_draw_list_item(uint8 short_name_length,
;                                          uint8 flags,
;                                          const char near *const far *name_list)
.proc ff6vwf_menu_draw_list_item
begin_locals
    decl_local outgoing_args, 6
    decl_local short_name_length, 1
    decl_local flags, 1
    decl_local max_tile_count, 1
    decl_local esper_id, 1
    decl_local string_ptr, 2
    decl_local text_line_slot, 1
    decl_local first_tile_id, 1
    decl_local blanks_count, 1
begin_args_nearcall
    decl_arg name_list, 3

ff6_esper_list = $7e9d89

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Save arguments.
    txa
    sta short_name_length
    tya
    sta flags

    ; Compute max tile and blanks count.
    lda flags
    and #FF6VWF_MENU_DRAW_LIST_ITEM_FLAGS_KEY_ITEM
    bne :+
    lda #10
    ldx #0
    bra @store_max_tile_and_blanks_count
:   lda #8
    ldx #4
@store_max_tile_and_blanks_count:
    sta max_tile_count
    txa
    sta blanks_count

    ; Look up Esper ID.
    lda f:ff6_menu_list_slot
    a16
    and #$00ff
    tax
    a8
    lda f:ff6_esper_list,x
    sta esper_id

    ; Compute string pointer.
    lda esper_id
    a16
    and #$00ff
    asl
    tay
    lda [name_list],y
    sta string_ptr
    a8

    ; Compute text line slot.
    lda flags
    and #FF6VWF_MENU_DRAW_LIST_ITEM_FLAGS_KEY_ITEM
    bne :+
    jsr _ff6vwf_menu_get_text_line_slot_for_scrollable_list
    txa
    bra @store_text_line_slot
:   txa
@store_text_line_slot:
    sta text_line_slot

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy max_tile_count
    jsr ff6vwf_calculate_first_tile_id_simple
    txa                     ; first_tile_id
    sta first_tile_id

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP | FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; 4bpp
    ldy string_ptr
    sty outgoing_args+1     ; string ptr
    lda name_list+2
    sta outgoing_args+3     ; string ptr bank
    ldy max_tile_count      ; max_tile_count
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsl ff6vwf_menu_force_nmi_trampoline

    ; Draw tiles.
    ldx first_tile_id
    ldy max_tile_count
    lda blanks_count
    sta outgoing_args+0                 ; blanks_count
    stz outgoing_args+1                 ; initial_offset
    jsr ff6vwf_menu_draw_vwf_tiles

    leave __FRAME_SIZE__
    rts
.endproc

.export ff6vwf_menu_draw_list_item

; nearproc uint8 _ff6vwf_menu_get_text_line_slot_for_scrollable_list()
.proc _ff6vwf_menu_get_text_line_slot_for_scrollable_list
    lda f:ff6_menu_list_slot
    a16
    and #$00ff
    tax
    a8
    ldy #9                  ; Number of menu items on screen plus one.
    jsr std_mod16_8
    rts
.endproc

.proc _ff6vwf_menu_draw_class_name
begin_locals
    decl_local outgoing_args, 6
    decl_local string_ptr, 2
    decl_local icon_position, 2     ; uint16
    decl_local party_member_id, 1
    decl_local first_tile_id, 1

    enter __FRAME_SIZE__, STACK_LIMIT

ff6_party_characters = $7e0000
ff6_icon_position    = $7e00e7  ; $1578, $4578, $7578, $a578 for party members 0-3 respectively

LAST_TEXT_LINE_SLOT = FF6VWF_MENU_SLOT_COUNT - 1

    ; Determine party member ID.
    lda 0,y
    sta party_member_id

    ; Is this the Lineup menu?
    a16
    lda f:ff6_icon_position
    cmp #$3048
    a8
    bne @not_lineup

    ; This is the Lineup menu. We have some special case logic here to bail out if we've already
    ; drawn this party member's class in order to avoid flicker.
    lda #FF6VWF_FIRST_TILE + $1c
    sta first_tile_id
    lda f:ff6vwf_last_lineup_class
    cmp party_member_id
    beq @draw_tiles
    lda party_member_id
    sta f:ff6vwf_last_lineup_class
    bra @finished_calculating_tile_id

    ; Calculate first tile ID.
@not_lineup:
    ldx #0
:   a16
    cmp f:@party_member_icon_positions,x
    a8
    beq @found_tile_id
    addix 3
    cpx #@party_member_icon_positions_end - @party_member_icon_positions
    bne :-

    ; Default to the first valid tile ID.
    lda #FF6VWF_FIRST_TILE
    sta first_tile_id
    bra @finished_calculating_tile_id

@found_tile_id:
    lda f:@party_member_icon_positions+2,x
    add #FF6VWF_FIRST_TILE
    sta first_tile_id

@finished_calculating_tile_id:
    ; Compute string pointer.
    lda party_member_id
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_class_names,x
    sta string_ptr
    a8

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    sta outgoing_args+0     ; 4bpp
    ldy string_ptr
    sty outgoing_args+1     ; string ptr
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+3     ; string ptr bank
    ldx first_tile_id       ; first_tile_id
    ldy #10                 ; max_tile_count
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsr ff6vwf_menu_force_nmi

@draw_tiles:
    ; Draw tiles.
    ldx first_tile_id
    ldy #FF6_SHORT_ENEMY_NAME_LENGTH
    stz outgoing_args+0                 ; blanks_count
    stz outgoing_args+1                 ; initial_offset
    jsr ff6vwf_menu_draw_vwf_tiles

    leave __FRAME_SIZE__
    rtl

@party_member_icon_positions:
    .word $1578     ; Main menu, party member 0
        .byte 0*10
    .word $4578     ; Main menu, party member 1
        .byte 1*10
    .word $7578     ; Main menu, party member 2
        .byte 2*10
    .word $a578     ; Main menu, party member 3
        .byte 3*10
    .word $4f50     ; Espers menu
        .byte $68
@party_member_icon_positions_end:
.endproc

; nearproc void ff6vwf_menu_render_static_strings(uint8 tile_offset,
;                                                 const struct static_text far *text_ptr)
.proc ff6vwf_menu_render_static_strings
begin_locals
    decl_local outgoing_args, 6
    decl_local string_index, 1          ; uint8
    decl_local tile_offset, 1           ; uint8
    decl_local text, .sizeof(static_text)
begin_args_nearcall
    decl_arg text_ptr, 3            ; const struct static_text far *

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Save tile offset.
    txa
    sta tile_offset

    ; Copy the descriptor onto the stack.
    a16
    tdc
    add #text
    sta outgoing_args+0     ; dest
    lda text_ptr+0
    sta outgoing_args+3     ; src
    a8
    stz outgoing_args+2     ; dest bank byte
    lda text_ptr+2
    sta outgoing_args+5     ; src bank byte
    ldx #.sizeof(static_text)
    jsr std_memcpy

    ; Initialize locals.
    lda #0
    sta string_index

@loop:
    cmp text+static_text::count
    beq @out

    a16
    and #$00ff
    tax
    asl
    tay
    lda [text+static_text::strings],y
    sta outgoing_args+1         ; string_ptr
    txy
    a8
    lda text+static_text::dma_flags
    sta outgoing_args+0             ; 4bpp
    lda text+static_text::strings+2
    sta outgoing_args+3             ; string ptr bank
    lda [text+static_text::start_tiles],y
    add tile_offset
    tax                             ; first tile ID
    lda [text+static_text::tile_counts],y
    tay                             ; max_tile_count
    jsr ff6vwf_render_string

    ; Upload it.
    jsr _ff6vwf_menu_commit_transaction

    inc string_index
    lda string_index
    bra @loop

@out:
    leave __FRAME_SIZE__
    rts
.endproc

.export ff6vwf_menu_render_static_strings

.proc _ff6vwf_menu_draw_main_menu
.struct locals
    .org 1
    outgoing_args .byte 4
.endstruct

    enter .sizeof(locals), STACK_LIMIT

    ldx #.loword(ff6vwf_main_menu_static_text_descriptor)
    stx locals::outgoing_args+0
    lda #^ff6vwf_main_menu_static_text_descriptor
    sta locals::outgoing_args+2
    ldx #FF6VWF_FIRST_TILE+10*4     ; tile_offset
    jsr ff6vwf_menu_render_static_strings

    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    sta locals::outgoing_args+0     ; flags
    ldx #.loword(ff6vwf_menu_wounded_label)
    stx locals::outgoing_args+1     ; string_ptr
    lda #^ff6vwf_menu_wounded_label
    sta locals::outgoing_args+3     ; string_ptr bank
    ldx #FF6VWF_FIRST_TILE+76       ; first_tile_id
    ldy #8                          ; max_tile_count
    jsr ff6vwf_render_string

    ; Stuff the original function did:
    lda #$20    ; palette 0
    sta f:ff6_menu_bg_attrs

    leave .sizeof(locals)
    a16
    lda #0
    ldx #0
    ldy #0
    a8
    rtl
.endproc

; This is the existing FF6 DMA setup during NMI for the menu, factored out into this bank to give
; us some space for a patch.
.proc _ff6vwf_menu_run_dma_setup
ff6_menu_bg1_xpos = $35
ff6_menu_bg1_ypos = $37
ff6_menu_bg2_xpos = $39
ff6_menu_bg2_ypos = $3b
ff6_menu_bg3_xpos = $3d
ff6_menu_bg3_ypos = $3f

    stz HDMAEN      ; Disable HDMA.
    stz MDMAEN      ; Disable DMA.
    lda ff6_menu_bg1_xpos+0
    sta BG1HOFS
    lda ff6_menu_bg1_xpos+1
    sta BG1HOFS
    lda ff6_menu_bg1_ypos+0
    sta BG1VOFS
    lda ff6_menu_bg1_ypos+1
    sta BG1VOFS
    lda ff6_menu_bg2_xpos+0
    sta BG2HOFS
    lda ff6_menu_bg2_xpos+1
    sta BG2HOFS
    lda ff6_menu_bg2_ypos+0
    sta BG2VOFS
    lda ff6_menu_bg2_ypos+1
    sta BG2VOFS
    lda ff6_menu_bg3_xpos+0
    sta BG3HOFS
    lda ff6_menu_bg3_xpos+1
    sta BG3HOFS
    lda ff6_menu_bg3_ypos+0
    sta BG3VOFS
    lda ff6_menu_bg3_ypos+1
    sta BG3VOFS
    rtl
.endproc

.proc _ff6vwf_menu_run_dma
    ff6vwf_run_dma ff6vwf_menu_text_tiles, ff6vwf_menu_text_dma_stack_base, ff6vwf_menu_text_dma_stack_size, 0, 250
    rtl
.endproc

; ROM data patches

.segment "PTEXTMENUMAINMENUPOSITIONEDTEXT"  ; $c337cb

.word $7939
    def_static_text_tiles_z 40+0, .strlen("Item"), 3
.word $79b9
    def_static_text_tiles_z 40+3, .strlen("Skills"), 3
.word $7a39
    def_static_text_tiles_z 40+6, .strlen("Equip"), 3
.word $7ab9
    def_static_text_tiles_z 40+9, .strlen("Relic"), 3
.word $7b39
    def_static_text_tiles_z 40+12, .strlen("Status"), 4
.word $7bb9
    def_static_text_tiles_z 40+16, .strlen("Config"), 4
.word $7c39
    def_static_text_tiles_z 40+20, .strlen("Save"), 3
.word $7cbb
    def_static_text_tiles_z 40+23, .strlen("Time"), 3
.word $7cff
    ff6_def_charset_string_z ":"
.word $7db7
    def_static_text_tiles_z 40+26, .strlen("Steps"), 3
.word $7e77
    def_static_text_tiles_z 40+29, .strlen("Gp"), -1
.word $7abd
    def_static_text_tiles_z 40+35, .strlen("Yes"), 2
.word $7b3d
    def_static_text_tiles_z 40+37, .strlen("No"), -1
; Put a couple of trampolines here to overwrite "This data?"
ff6_menu_draw_string_trampoline:
    def_trampoline $02ff
_ff6_menu_load_bg1_font_gfx_trampoline:
    def_trampoline $6b37
_ff6_menu_load_bg3_font_gfx_trampoline:
    def_trampoline $6b13
_ff6_menu_load_skin_gfx_trampoline:
    def_trampoline $3a87
.byte 0
.word $813d
    def_static_text_tiles_z 40+31, .strlen("Order"), 4

.export ff6_menu_draw_string_trampoline

.segment "PTEXTMENUWOUNDEDPOSITIONEDTEXT"       ; $c3371b

    def_static_text_tiles FF6VWF_MENU_WOUNDED_START_TILE, 8, -1     ; "Wounded "

; Constant data

.segment "DATA"

ff6vwf_main_menu_static_text_descriptor:
    .byte MAIN_MENU_STRING_COUNT                ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU        ; DMA flags
    .faraddr ff6vwf_main_menu_labels            ; strings
    .faraddr ff6vwf_main_menu_tile_counts       ; tile counts
    .faraddr ff6vwf_main_menu_start_tiles       ; start tiles

ff6vwf_main_menu_labels: ff6vwf_def_pointer_array ff6vwf_main_menu_label, MAIN_MENU_STRING_COUNT
;         0   1   2   3    4   5   6   7   8   9
ff6vwf_main_menu_tile_counts:
    .byte 3,  3,  3,  3,   4,  4,  3,  3,  3,  2
    .byte 4,  2,  2,  7,   6,  6,  7,  6,  4
ff6vwf_main_menu_start_tiles:
    .byte 0,  3,  6,  9,  12, 16, 20, 23, 26, 29
    .byte 31, 35, 37, 39, 46, 52, 58, 65, 71

ff6vwf_main_menu_label_0:  .asciiz "Items"
ff6vwf_main_menu_label_1:  .asciiz "Skills"
ff6vwf_main_menu_label_2:  .asciiz "Equip"
ff6vwf_main_menu_label_3:  .asciiz "Relics"
ff6vwf_main_menu_label_4:  .asciiz "Status"
ff6vwf_main_menu_label_5:  .asciiz "Config"
ff6vwf_main_menu_label_6:  .asciiz "Save"
ff6vwf_main_menu_label_7:  .asciiz "Time"
ff6vwf_main_menu_label_8:  .asciiz "Steps"
ff6vwf_main_menu_label_9:  .asciiz "Gil"
ff6vwf_main_menu_label_10: .asciiz "Order"
ff6vwf_main_menu_label_11: .asciiz "Yes"
ff6vwf_main_menu_label_12: .asciiz "No"
ff6vwf_main_menu_label_13: .asciiz "Overwriting"
ff6vwf_main_menu_label_14: .asciiz "game. Are"
ff6vwf_main_menu_label_15: .asciiz "you sure?"
ff6vwf_main_menu_label_16: .asciiz "Do you want"
ff6vwf_main_menu_label_17: .asciiz "to load this"
ff6vwf_main_menu_label_18: .asciiz "game?"

ff6vwf_menu_wounded_label: .asciiz "Knocked Out"

.export ff6vwf_menu_wounded_label: far

; Stats labels

ff6vwf_stats_labels: ff6vwf_def_pointer_array ff6vwf_stats_label, FF6VWF_STATS_STRING_COUNT

ff6vwf_stats_tile_counts: .byte 5, 5,  3,  5,  7,  4,  4,  5,  6
ff6vwf_stats_start_tiles: .byte 0, 5, 10, 13, 18, 25, 29, 33, 38

.export ff6vwf_stats_labels:        far
.export ff6vwf_stats_tile_counts:   far
.export ff6vwf_stats_start_tiles:   far

; TODO(tachiweasel): Fix "Magic Evasion" and "Magic Defense" by drawing custom condensed text for
; them.
ff6vwf_stats_label_0: .asciiz "Strength"
ff6vwf_stats_label_1: .asciiz "Stamina"
ff6vwf_stats_label_2: .asciiz "Magic"
ff6vwf_stats_label_3: .asciiz "Evasion"
ff6vwf_stats_label_4: .asciiz "Magic Evade"
ff6vwf_stats_label_5: .asciiz "Speed"
ff6vwf_stats_label_6: .asciiz "Attack"
ff6vwf_stats_label_7: .asciiz "Defense"
ff6vwf_stats_label_8: .asciiz "Magic Def."
