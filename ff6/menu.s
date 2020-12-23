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
.import ff6vwf_get_long_item_name:              near
.import ff6vwf_menu_draw_item_icon:             near
.import ff6vwf_render_string:                   near
.import ff6vwf_transcode_string:                near
.import ff6vwf_long_command_names:              far
.import ff6vwf_long_class_names:                far
.import ff6vwf_long_enemy_names:                far
.import ff6vwf_long_item_names:                 far

; Types

.struct static_text
    count .byte                 ; count
    dma_flags .byte             ; dma_flags
    base_addr .word             ; vram near *
    strings .faraddr            ; const char far **
    tile_counts .faraddr        ; const uint8 far *
    start_tiles .faraddr        ; const uint8 far *
.endstruct

; Constants

MAIN_MENU_STRING_COUNT = 10
STATUS_STRING_COUNT = 2
CONFIG_STRING_COUNT = 11

STATUS_FIRST_LABEL_TILE     = 50

; FF6 globals

ff6_actor_address       = $7e0067

; FF6-specific macros

.define bg1_position(col, row)  .loword(ff6_menu_bg1_data) + row * $40 + col * 2
.define bg3_position(col, row)  .loword(ff6_menu_bg3_data) + row * $40 + col * 2

.segment "BSS"

; Menu BSS

.org $7eb000

; Current of the stack *in bytes*.
ff6vwf_menu_text_dma_stack_size: .res 1
; Last party member drawn in Lineup. This avoids uploading every frame, which causes flicker.
ff6vwf_last_lineup_party_member: .res 1
; Stack of DMA structures, just like the encounter ones.
ff6vwf_menu_text_dma_stack_base: .res FF6VWF_DMA_STRUCT_SIZE * FF6VWF_MENU_SLOT_COUNT
; Buffer space for the lines of text, `FF6VWF_MAX_LINE_LENGTH` each to be stored, ready to be uploaded
; to VRAM.
ff6vwf_menu_text_tiles: .res VWF_TILE_BYTE_SIZE_4BPP * 128
; The slot to use when drawing current equipment.
ff6vwf_current_equipment_text_slot: .res 1
; True if we're drawing current equipment to BG3, false if BG1.
ff6vwf_current_equipment_bg3: .res 1

.export ff6vwf_menu_text_dma_stack_base:    far
.export ff6vwf_menu_text_tiles:             far
.export ff6vwf_menu_text_dma_stack_size:    far
.export ff6vwf_current_equipment_text_slot: far
.export ff6vwf_current_equipment_bg3:       far

.reloc 

; Patches to Final Fantasy 6 functions

; Final Fantasy 6 menu patches

.segment "PTEXTMENUINIT"
    jml _ff6vwf_menu_init

; FIXME(tachiweasel): This is necessary to preserve Y but breaks the Kefka lineup!
.segment "PTEXTMENUDRAWPCNAME"              ; $c334cf
    jsl _ff6vwf_menu_draw_pc_name
    rts

.segment "PTEXTMENUBUILDCOLOSSEUMITEMS"
    jml _ff6vwf_menu_build_colosseum_items  ; 4 bytes

.segment "PTEXTMENUDRAWCOLOSSEUMITEM"
    jsl _ff6vwf_menu_draw_colosseum_item    ; 4 bytes
    jmp .loword(ff6_menu_draw_string)       ; Draw item name.

.segment "PTEXTMENUDRAWCOLOSSEUMENEMY"
    jsl _ff6vwf_menu_draw_colosseum_enemy   ; 4 bytes
    jmp .loword(ff6_menu_draw_string)       ; Draw enemy name.

.segment "PTEXTMENUDRAWSTATUSSTATS"     ; $c35fc2
ff6_menu_draw_attack_string     = $0486
ff6_menu_draw_string_number     = $04c0
ff6_menu_itoa                   = $04e0
ff6_menu_make_attack_string     = $052e 
ff6_menu_define_attack          = $9371 
ff6_menu_set_attack_stats_mode  = $99e8
ff6_load_actor_properties       = $c20006
ff6_current_character_data      = $7e0067
ff6_stats_magic                 = $7e11a0
ff6_stats_stamina               = $7e11a2
ff6_stats_speed                 = $7e11a4
ff6_stats_strength              = $7e11a6
ff6_stats_evasion               = $7e11a8
ff6_stats_magic_evasion         = $7e11aa
ff6_stats_defense               = $7e11ba
ff6_stats_magic_defense         = $7e11bb

    jsl ff6_load_actor_properties           ; Load properties
    ldy <ff6_current_character_data         ; Actor's address
    jsr ff6_menu_set_attack_stats_mode      ; Set Bat.Pwr mode
    lda #$20                                ; Palette 0
    sta <ff6_menu_bg_attrs                  ; Color: User's

    lda .loword(ff6_stats_strength)     ; Vigor
    jsr ff6_menu_itoa                   ; Turn into text
    ldx #bg1_position 12, 21            ; Text position
    jsr ff6_menu_draw_string_number     ; Draw 3 digits

    lda .loword(ff6_stats_speed)        ; Speed
    jsr ff6_menu_itoa                   ; Turn into text
    ldx #bg1_position 26, 21            ; Text position
    jsr ff6_menu_draw_string_number     ; Draw 3 digits

    lda .loword(ff6_stats_stamina)      ; Stamina
    jsr ff6_menu_itoa                   ; Turn into text
    ldx #bg1_position 12, 22            ; Text position
    jsr ff6_menu_draw_string_number     ; Draw 3 digits

    lda .loword(ff6_stats_magic)        ; Mag.Pwr
    jsr ff6_menu_itoa                   ; Turn into text
    ldx #bg1_position 26, 22            ; Text position
    jsr ff6_menu_draw_string_number     ; Draw 3 digits

    jsr ff6_menu_define_attack          ; Define Bat.Pwr
    jsr ff6_menu_make_attack_string     ; Turn into text
    ldx #bg1_position 12, 23            ; Text position
    jsr ff6_menu_draw_attack_string     ; Draw 3 digits

    lda .loword(ff6_stats_defense)      ; Defense
    jsr ff6_menu_itoa                   ; Turn into text
    ldx #bg1_position 26, 23            ; Text position
    jsr ff6_menu_draw_string_number     ; Draw 3 digits

    lda .loword(ff6_stats_evasion)      ; Evade
    jsr ff6_menu_itoa                   ; Turn into text
    ldx #bg1_position 12, 24            ; Text position
    jsr ff6_menu_draw_string_number     ; Draw 3 digits

    lda .loword(ff6_stats_magic_defense)    ; Magic defense
    jsr ff6_menu_itoa                       ; Turn into text
    ldx #bg1_position 26, 24                ; Text position
    jsr ff6_menu_draw_string_number         ; Draw 3 digits

    lda .loword(ff6_stats_magic_evasion)    ; Magic evasion
    jsr ff6_menu_itoa                       ; Turn into text
    ldx #bg1_position 12, 25                ; Text position
    jsr ff6_menu_draw_string_number         ; Draw 3 digits

    LDY #$398F      ; Text position
    JSR $34CF      ; Draw actor name
    LDY #$399D      ; Text position
    JSR $34E5      ; Actor class...
    LDY #$39B1      ; Text position
    JSR $34E6      ; Draw held esper
    JSR $6102      ; Draw commands
    LDA #$20        ; Palette 0
    STA $29         ; Color: User's
    LDX #$6096     ; Coords tbl ptr
    JSR $0C6C      ; Draw LV, HP, MP
    LDX $67         ; Actor's address
    LDA $0011,X     ; Experience LB
    STA $F1         ; Memorize it
    LDA $0012,X     ; Experience MB
    STA $F2         ; Memorize it
    LDA $0013,X     ; Experience HB
    STA $F3         ; Memorize it
    JSR $0582      ; Turn into text
    LDX #bg1_position 8, 16 ; Text position
    JSR $04A3      ; Draw 8 digits
    JSR $60A0      ; Get needed exp
    JSR $0582      ; Turn into text
    LDX #bg1_position 8, 19 ; Text position
    JSR $04A3      ; Draw 8 digits
    STZ $47         ; Ailments: Off
    JSR $11B0      ; Hide ail. icons
    jsr $625B      ; Display status
    jsl _ff6vwf_menu_draw_status_menu
    rts

.segment "PTEXTMENUDRAWSTATUSCOMMANDNAME"           ; $c35eeb
    jsl _ff6vwf_menu_draw_status_command_name
    jmp ff6_menu_draw_string

.segment "PTEXTMENUDRAWMAINMENU"        ; $c33221
    jsl _ff6vwf_menu_draw_main_menu

.segment "PTEXTMENUDRAWCONFIGMENU"      ; $c33947
    jsl _ff6vwf_menu_draw_config_menu
    nop

.segment "PTEXTMENUDRAWCLASSNAME"
    jsl _ff6vwf_menu_draw_class_name

; The "refresh screen" routine for the FF6 menu NMI/VBLANK handler. We patch it to upload our text
; if needed.
.segment "PTEXTMENURUNDMA"
ff6_menu_refresh_mode_7 = $c3d263
ff6_menu_refresh_oam    = $c31463
ff6_menu_refresh_cgram  = $c314d2
ff6_menu_do_vram_dma_a  = $c31488
ff6_menu_do_vram_dma_b  = $c314ac

    jsl _ff6vwf_menu_run_dma_setup
    jsr .loword(ff6_menu_refresh_mode_7)
    jsr .loword(ff6_menu_refresh_oam)
    jsr .loword(ff6_menu_refresh_cgram)
    jsr .loword(ff6_menu_do_vram_dma_a)

    ; We have priority over VRAM DMA B.
    ;
    ; For this to work, we must eagerly trigger NMI every time we render some text.
    jsl _ff6vwf_menu_run_dma
    cpy #0
    bne @we_did_dma

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
    lda #$ff
    sta f:ff6vwf_last_lineup_party_member

    ; Return.
    jml $c368fe
.endproc

; farproc void _ff6vwf_menu_draw_pc_name(uint8 unused, tiledata near *tilemap_addr)
.proc _ff6vwf_menu_draw_pc_name
begin_locals
    decl_local outgoing_args, 6
    decl_local first_tile_id, 1
    decl_local base_addr, 2
    decl_local dma_flags, 1
    decl_local tilemap_addr, 2
    decl_local name_buffer, 7       ; char[7]

    enter __FRAME_SIZE__

    ; Save tilemap address.
    a16
    tya
    sta f:ff6_menu_positioned_text_ptr

    ; Copy PC name.
    lda f:ff6_actor_address
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

    ; Find the tile ID.
    a16
    ldx #0
:   a16
    lda f:_ff6vwf_menu_pc_name_address_table,x
    cmp f:ff6_menu_positioned_text_ptr
    a8
    beq @found_tile_id
    inx
    inx
    inx
    cpx #_ff6vwf_menu_pc_name_address_table_end-_ff6vwf_menu_pc_name_address_table
    bne :-
    lda 0       ; fallback
    bra @store_tile_id
@found_tile_id:
    lda f:_ff6vwf_menu_pc_name_address_table+2,x
@store_tile_id:
    sta first_tile_id

    ; Calculate base address and DMA flags.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    sta dma_flags
    ldy #VWF_MENU_TILE_BG1_BASE_ADDR
    sty base_addr

    ; Render string.
    lda #FF6_SHORT_PC_NAME_LENGTH
    sta outgoing_args+0     ; max_tile_count
    lda dma_flags
    sta outgoing_args+1     ; flags
    a16
    tdc
    add #name_buffer
    sta outgoing_args+2     ; string ptr
    a8
    lda #$7e
    sta outgoing_args+4     ; string ptr bank
    ldx first_tile_id
    ldy base_addr
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
    ply
    pla
    phy                                 ; Remove bank byte.
    jml ff6_menu_draw_string            ; Draw item name.
.endproc

; Table of addresses

_ff6vwf_menu_pc_name_address_table:
.word $3a4f
    .byte 10+6*0     ; $c3174d -- Leader info over save file 1
.word $3c0f
    .byte 10+6*1     ; $c317fa -- Leader info over save file 2
.word $3dcf
    .byte 10+6*2     ; $c3185d -- Leader info over save file 3
.word $3919
    .byte 60+6*0     ; $c332f1 -- Party member info 1
.word $3a99
    .byte 60+6*1     ; $c3333d -- Party member info 2
.word $3c19
    .byte 60+6*2     ; $c33389 -- Party member info 3
.word $3d99
    .byte 60+6*3     ; $c333d5 -- Party member info 3
.word $798f
    .byte 60+6*0     ; $c344b4 -- Command Set menu text, member 1
.word $7b4f
    .byte 60+6*1     ; $c344ed -- Command Set menu text, member 2
.word $7d0f
    .byte 60+6*2     ; $c34526 -- Command Set menu text, member 3
.word $7ecf
    .byte 60+6*3     ; $c3455f -- Command Set menu text, member 4
.word $7bcf
    .byte 60+6*0     ; $c347b4 -- Controller menu text, member 1
.word $7c4f
    .byte 60+6*1     ; $c347f1 -- Controller menu text, member 2
.word $7ccf
    .byte 60+6*2     ; $c3482e -- Controller menu text, member 3
.word $7d4f
    .byte 60+6*3     ; $c3486b -- Controller menu text, member 4
.word $398f
    .byte 60         ; $c35fbb -- Status menu
.word $4229
    .byte 60         ; $c3675b -- Naming menu
.word $3adb
    .byte 60         ; $c37953 -- Lineup menu
.word $390d
    .byte 80+6*0     ; $c38f1c -- Party gear overview, member 1
.word $3b0d
    .byte 80+6*1     ; $c38f36 -- Party gear overview, member 2
.word $3d0d
    .byte 80+6*2     ; $c38f52 -- Party gear overview, member 3
.word $3f0d
    .byte 80+6*3     ; $c38f6e -- Party gear overview, member 3
.word $7bb7
    .byte 80         ; $c393e5 -- Equip or Relic menu
.word $7c11
    .byte 80         ; $c3aed9 -- Shadow at Colosseum
.word $7c75
    .byte 60         ; $c3b2a5 -- Colosseum challenger
; TODO(tachiweasel): Kefka menu
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

    enter __FRAME_SIZE__

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

    enter __FRAME_SIZE__

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
    txa
    sta first_tile_id

    ; Render string.
    lda max_tile_count
    sta outgoing_args+0     ; max_tile_count
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP | FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+1     ; 4bpp
    ldy string_ptr
    sty outgoing_args+2     ; string ptr
    lda name_list+2
    sta outgoing_args+4     ; string ptr bank
    ldy #VWF_MENU_TILE_BG1_BASE_ADDR
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

.proc _ff6vwf_menu_build_colosseum_items
    ; Stuff the original function did
    lda #1
    sta f:BG1SC
    jml $c3ad2c
.endproc

.proc _ff6vwf_menu_draw_colosseum_item
begin_locals
    decl_local outgoing_args, 6
    decl_local item_id, 1
    decl_local string_ptr, 2
    decl_local text_line_slot, 1
    decl_local tilemap_position, 2
    decl_local first_tile_id, 1

    tay                     ; Save item in Y.
    enter __FRAME_SIZE__

    ; Initialize locals.
    tya
    sta item_id
    stx tilemap_position

    ; Draw item icon.
    ldx item_id
    jsr ff6vwf_menu_draw_item_icon

    ; Compute string pointer.
    ldx item_id
    jsr ff6vwf_get_long_item_name
    stx string_ptr

    ; Determine a text line slot.
    lda tilemap_position+0
    cmp #$0d            ; Is it the prize (tilemap address $790d)?
    beq :+
    lda #0
    bra :++
:   lda #1
:   sta text_line_slot

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple   ; first tile ID
    txa
    sta first_tile_id

    ; Render string.
    lda #10
    sta outgoing_args+0     ; flags
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+1     ; flags
    ldy string_ptr
    sty outgoing_args+2
    lda #^ff6vwf_long_item_names
    sta outgoing_args+4
    ldy #VWF_MENU_TILE_BG3_BASE_ADDR
    jsr ff6vwf_render_string

    ; Schedule an upload for later, or just upload now if we're in force blank.
    jsl ff6vwf_menu_force_nmi_trampoline

    ; Draw tiles.
    ldx first_tile_id
    ldy #FF6_SHORT_ITEM_LENGTH
    stz outgoing_args+0             ; blanks_count
    lda #1
    sta outgoing_args+1             ; initial_offset
    jsr ff6vwf_menu_draw_vwf_tiles

    ; Save tilemap position where FF6 expects it.
    a16
    lda tilemap_position
    sta f:ff6_menu_positioned_text_ptr
    a8

    leave __FRAME_SIZE__
    rtl
.endproc

.proc _ff6vwf_menu_draw_colosseum_enemy
begin_locals
    decl_local outgoing_args, 6
    decl_local string_ptr, 2

ff6_menu_colosseum_opponent = $7e0206

TEXT_LINE_SLOT = 2
FIRST_TILE_ID = 2 * 10 + 8

    enter __FRAME_SIZE__

    ; Compute string pointer.
    lda f:ff6_menu_colosseum_opponent
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_enemy_names,x
    sta string_ptr

    ; Render string.
    a8
    lda #10
    sta outgoing_args+0     ; max_tile_count
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+1     ; 4bpp
    ldy string_ptr
    sty outgoing_args+2     ; string ptr
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+4     ; string ptr bank
    ldy #VWF_MENU_TILE_BG3_BASE_ADDR
    ldx #FIRST_TILE_ID
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsl ff6vwf_menu_force_nmi_trampoline

    ; Draw tiles.
    ldx #FIRST_TILE_ID
    ldy #FF6_SHORT_ENEMY_NAME_LENGTH
    stz outgoing_args+0                 ; blanks_count
    stz outgoing_args+1                 ; initial_offset
    jsr ff6vwf_menu_draw_vwf_tiles

    ; Store tilemap position.
    a16
    lda #$7c4f                          ; Tilemap ptr
    sta f:ff6_menu_positioned_text_ptr  ; Set position
    a8

    leave __FRAME_SIZE__
    rtl
.endproc

.proc _ff6vwf_menu_draw_class_name
begin_locals
    decl_local outgoing_args, 6
    decl_local string_ptr, 2
    decl_local icon_position, 2     ; uint16
    decl_local party_member_id, 1
    decl_local text_line_slot, 1
    decl_local first_tile_id, 1

    enter __FRAME_SIZE__

ff6_party_characters = $7e0000
ff6_icon_position    = $7e00e7  ; $1578, $4578, $7578, $a578 for party members 0-3 respectively

LAST_TEXT_LINE_SLOT = FF6VWF_MENU_SLOT_COUNT - 1

    ; Determine party member ID.
    lda 0,y
    sta party_member_id

    ; Determine which text line slot to use.
    a16
    lda f:ff6_icon_position
    sta icon_position
    a8
    ldx #0
    stz text_line_slot
:   a16
    lda f:@party_member_icon_positions,x
    cmp icon_position
    a8
    beq @found_text_line_slot
    inc text_line_slot
    inx
    inx
    cpx #8
    bne :-

    ; Special case: If we've already drawn this party member's class, bail out. This avoids flicker
    ; in the Lineup menu, which calls this function every frame...
    lda #LAST_TEXT_LINE_SLOT
    sta text_line_slot
    lda f:ff6vwf_last_lineup_party_member
    cmp party_member_id
    beq @draw_tiles
    lda party_member_id
    sta f:ff6vwf_last_lineup_party_member

@found_text_line_slot:
    ; Compute string pointer.
    lda party_member_id
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_class_names,x
    sta string_ptr
    a8

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple
    txa
    sta first_tile_id

    ; Render string.
    lda #10
    sta outgoing_args+0     ; max_tile_count
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    sta outgoing_args+1     ; 4bpp
    ldy string_ptr
    sty outgoing_args+2     ; string ptr
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+4     ; string ptr bank
    ldy #VWF_MENU_TILE_BG1_BASE_ADDR
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
    .word $1578, $4578, $7578, $a578
.endproc

;   struct static_text {
;       uint8 count;
;       uint8 first_tile;
;       uint8 dma_flags;
;       vram near *base_addr;
;       const char far **strings;
;       const uint8 far *tile_counts;
;       const uint8 far *start_tiles;
;   };

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

ff6_update_config_menu_arrow = $c33980

    enter __FRAME_SIZE__

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
    sta outgoing_args+2         ; string_ptr
    txy
    a8
    lda [text+static_text::tile_counts],y
    sta outgoing_args+0             ; max_tile_count
    lda text+static_text::dma_flags
    sta outgoing_args+1             ; 4bpp
    lda text+static_text::strings+2
    sta outgoing_args+4             ; string ptr bank
    lda [text+static_text::start_tiles],y
    add tile_offset
    tax                             ; tile ID
    ldy text+static_text::base_addr ; base_addr
    jsr ff6vwf_render_string

    ; Upload it.
    jsr ff6vwf_menu_force_nmi

    inc string_index
    lda string_index
    bra @loop

@out:
    leave __FRAME_SIZE__
    rts
.endproc

.export ff6vwf_menu_render_static_strings

.proc _ff6vwf_menu_draw_main_menu
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__

    ldx #.loword(ff6vwf_main_menu_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_main_menu_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE+10*4 ; tile_offset
    jsr ff6vwf_menu_render_static_strings

    ; Stuff the original function did:
    lda #$20    ; palette 0
    sta f:ff6_menu_bg_attrs

    leave __FRAME_SIZE__
    rtl
.endproc

.proc _ff6vwf_menu_draw_status_menu
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__

    ; Upload main labels.
    ldx #.loword(ff6vwf_status_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_status_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE + STATUS_FIRST_LABEL_TILE
    jsr ff6vwf_menu_render_static_strings

    ; Upload stats labels.
    ldx #.loword(ff6vwf_stats_static_text_descriptor_bg1)
    stx outgoing_args+0
    lda #^ff6vwf_stats_static_text_descriptor_bg1
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE
    jsr ff6vwf_menu_render_static_strings

    leave __FRAME_SIZE__
    rtl
.endproc

; farproc void _ff6vwf_menu_draw_status_command_name()
.proc _ff6vwf_menu_draw_status_command_name
begin_locals
    decl_local outgoing_args, 5
    decl_local string_ptr, 2        ; const char near *
    decl_local first_tile, 1        ; uint8

command_name = $7e00e2

    enter __FRAME_SIZE__

    ; Compute text line slot.
    lda f:command_name
    a16
    and #$00ff
    tax
    a8
    lda f:ff6vwf_status_command_first_tiles,x
    sta first_tile

    ; Compute string pointer.
    lda f:command_name
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_command_names,x
    sta string_ptr
    a8

    ; Render string.
    lda #FF6_SHORT_COMMAND_NAME_LENGTH
    sta outgoing_args+0     ; max_tile_count
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+1     ; flags
    ldy string_ptr
    sty outgoing_args+2
    lda #^ff6vwf_long_command_names
    sta outgoing_args+4
    ldx first_tile
    ldy #VWF_MENU_TILE_BG3_BASE_ADDR
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsr ff6vwf_menu_force_nmi

    ; Draw tiles.
    ldx first_tile                      ; first_tile_id
    ldy #FF6_SHORT_COMMAND_NAME_LENGTH  ; tile count
    stz outgoing_args+0                 ; blanks_count
    stz outgoing_args+1                 ; initial_offset
    jsr ff6vwf_menu_draw_vwf_tiles

    leave __FRAME_SIZE__
    rtl
.endproc

.proc _ff6vwf_menu_draw_config_menu
begin_locals
    decl_local outgoing_args, 3

ff6_update_config_menu_arrow = $c33980

    enter __FRAME_SIZE__

    ldx #.loword(ff6vwf_config_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_config_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE  ; first_tile_id
    jsr ff6vwf_menu_render_static_strings

    leave __FRAME_SIZE__

    ; Stuff the original function did:
    lda #$01
    ldy #.loword(ff6_update_config_menu_arrow)
    rtl
.endproc

.export _ff6vwf_menu_draw_config_menu

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

.export _ff6vwf_menu_run_dma

; ROM data patches

.segment "PTEXTMENUMAINMENUPOSITIONEDTEXT"  ; $c337cb

.word $7939
    def_static_text_tiles_z 4*10+5*0, .strlen("Item"), -1
.word $79b9
    def_static_text_tiles_z 4*10+5*1, .strlen("Skills"), 5
.word $7a39
    def_static_text_tiles_z 4*10+5*2, .strlen("Equip"), -1
.word $7ab9
    def_static_text_tiles_z 4*10+5*3, .strlen("Relic"), -1
.word $7b39
    def_static_text_tiles_z 4*10+5*4, .strlen("Status"), 5
.word $7bb9
    def_static_text_tiles_z 4*10+5*5, .strlen("Config"), 5
.word $7c39
    def_static_text_tiles_z 4*10+5*6, .strlen("Save"), -1
.word $7cbb
    def_static_text_tiles_z 4*10+5*7, .strlen("Time"), -1
.word $7cff
    ff6_def_charset_string_z ":"
.word $7db7
    def_static_text_tiles_z 4*10+5*8, .strlen("Steps"), -1
.word $7e77
    def_static_text_tiles_z 4*10+5*9, .strlen("Gp"), -1

.segment "PTEXTMENUSTATUSPOSITIONEDTEXT"    ; $c3646f
.word $78cd
    ff6_def_charset_string_z "Status"
.word $3a6b
    ff6_def_charset_string_z "/"
.word $3aab
    ff6_def_charset_string_z "/"
.word $7f83
    ff6_def_charset_string_z "%"
.word $8883
    ff6_def_charset_string_z "%"
.word $3a1d
    ff6_def_charset_string_z "LV"
.word $3a5d
    ff6_def_charset_string_z "HP"
.word $3a9d
    ff6_def_charset_string_z "MP"
; Strength Speed Stamina Magic Attack Defense Evasion MagicDef. MagicEvade
.word bg1_position 2,  21
    def_static_text_tiles_z FF6VWF_STATS_TILE_INDEX_STRENGTH, FF6VWF_STATS_TILE_COUNT_STRENGTH, -1
.word bg1_position 2,  22
    def_static_text_tiles FF6VWF_STATS_TILE_INDEX_STAMINA, FF6VWF_STATS_TILE_COUNT_STAMINA, -1
    .byte $ff, $ff, 0               ; "Stamina"
.word bg1_position 16, 22
    def_static_text_tiles FF6VWF_STATS_TILE_INDEX_MAGIC, FF6VWF_STATS_TILE_COUNT_MAGIC, -1
    .byte $ff, $ff, $ff, $ff, 0     ; "Mag.Pwr"
.word bg1_position 2,  24
    def_static_text_tiles FF6VWF_STATS_TILE_INDEX_EVASION, FF6VWF_STATS_TILE_COUNT_EVASION, -1
    .byte $ff, $ff, 0               ; "Evade %"
.word bg1_position 2,  25           ; "MBlock%"
    def_static_text_tiles_z FF6VWF_STATS_TILE_INDEX_MAGIC_EVASION, FF6VWF_STATS_TILE_COUNT_MAGIC_EVASION, -1
.word $7edd - $4180
    .byte $ff, 0
.word $7f5d - $4180
    .byte $ff, 0
.word $7fdd - $4180
    .byte $ff, 0
.word $885d - $4180
    .byte $ff, 0
.word $7efb - $4180
    .byte $ff, 0
.word $7f7b - $4180
    .byte $ff, 0
.word $7e7b - $4180
    .byte $ff, 0
.word $7ffb - $4180
    .byte $ff, 0
.word $887b - $4180
    .byte $ff, 0
.word bg1_position 16, 21
    def_static_text_tiles FF6VWF_STATS_TILE_INDEX_SPEED, FF6VWF_STATS_TILE_COUNT_SPEED, -1
    .byte $ff, 0                        ; "Speed"
.word bg1_position 2,  23
    def_static_text_tiles FF6VWF_STATS_TILE_INDEX_ATTACK, FF6VWF_STATS_TILE_COUNT_ATTACK, -1
    .byte $ff, $ff, $ff, 0              ; "Bat.Pwr"
.word bg1_position 16, 23
    def_static_text_tiles FF6VWF_STATS_TILE_INDEX_DEFENSE, FF6VWF_STATS_TILE_COUNT_DEFENSE, -1
    .byte $ff, $ff, 0                   ; "Defense"
.word bg1_position 16, 24
    def_static_text_tiles FF6VWF_STATS_TILE_INDEX_MAGIC_DEFENSE, FF6VWF_STATS_TILE_COUNT_MAGIC_DEFENSE, -1
    .byte $ff, 0                        ; "Mag.Def"
.word bg1_position 2,  15               ; "Your Exp:"
    def_static_text_tiles_z STATUS_FIRST_LABEL_TILE, .strlen("Your Exp:"), -1
.word bg1_position 2,  18
    def_static_text_tiles STATUS_FIRST_LABEL_TILE + 10*1, 10, -1
    .byte $ff, $ff, $ff, 0              ; "For level up:"

.segment "PTEXTMENUCONFIGPOSITIONEDTEXTA"   ; $c3490b

; Positioned text for Config page 1
.word $3d8f
    def_static_text_tiles_z 7*10, .strlen("Controller"), -1
.word $39b5
    ff6_def_charset_string_z "Wait"
.word $3a65
    ff6_def_charset_string_z "Fast"
.word $3a75
    ff6_def_charset_string_z "Slow"
.word $3b35
    ff6_def_charset_string_z "Short"
.word $3ba5
    ff6_def_charset_string_z "On"
.word $3bb5
    ff6_def_charset_string_z "Off"
.word $3c25
    ff6_def_charset_string_z "Stereo"
.word $3c35
    ff6_def_charset_string_z "Mono"
.word $3cb5
    ff6_def_charset_string_z "Memory"
.word $3d25
    ff6_def_charset_string_z "Optimum"
.word $3db5
    ff6_def_charset_string_z "Multiple"
.word $3a25
    ff6_def_charset_string_z "1 2 3 4 5 6"
.word $3aa5
    ff6_def_charset_string_z "1 2 3 4 5 6"
.word $3c8f
    def_static_text_tiles_z 10*10, .strlen("Cursor"), -1

.segment "PTEXTMENUCONFIGPOSITIONEDTEXTB"   ; $c349a1

.word $78f9
    ff6_def_charset_string_z "Config"
.word $398f
    def_static_text_tiles_z 0*10, .strlen("Bat.Mode"), -1
.word $3a0f
    def_static_text_tiles_z 1*10, .strlen("Bat.Speed"), -1
.word $3a8f
    def_static_text_tiles_z 2*10, .strlen("Msg.Speed"), -1
.word $3b0f
    def_static_text_tiles_z 3*10, .strlen("Cmd.Set"), -1
.word $3b8f
    def_static_text_tiles_z 4*10, .strlen("Gauge"), -1
.word $3c0f
    def_static_text_tiles_z 5*10, .strlen("Sound"), -1
.word $3d0f
    def_static_text_tiles_z 6*10, .strlen("Reequip"), -1
.word $39a5
    ff6_def_charset_string_z "Active"
.word $3b25
    ff6_def_charset_string_z "Window"
.word $3ca5
    ff6_def_charset_string_z "Reset"
.word $3d35
    ff6_def_charset_string_z "Empty"
.word $3da5
    ff6_def_charset_string_z "Single"

.segment "PTEXTMENUCONFIGPOSITIONEDTEXTC"   ; $c34a34

.word $418f
    def_static_text_tiles_z 8*10, .strlen("Mag.Order"), -1
.word $438f
    def_static_text_tiles_z 9*10, .strlen("Window"), -1
.word $440f
    .byte $ff, $ff, $ff, $ff, $ff, 0    ; "Color"

.segment "PTEXTMENUCONFIGPOSITIONEDTEXTD"   ; $c34afb

.word $7b4d
    def_static_text_tiles_z 7*10, .strlen("Controller"), -1
.repeat 4, i
.word $7c21+$80*i
    ff6_def_charset_string_z "Cntlr1"
.word $7c33+$80*i
    ff6_def_charset_string_z "Cntlr2"
.endrepeat

; Constant data

.segment "DATA"

ff6vwf_main_menu_static_text_descriptor:
    .byte MAIN_MENU_STRING_COUNT                ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU        ; DMA flags
    .word VWF_MENU_TILE_BG3_BASE_ADDR           ; base address
    .faraddr ff6vwf_main_menu_labels            ; strings
    .faraddr ff6vwf_main_menu_tile_counts       ; tile counts
    .faraddr ff6vwf_main_menu_start_tiles       ; start tiles

ff6vwf_main_menu_labels: ff6vwf_def_pointer_array ff6vwf_main_menu_label, MAIN_MENU_STRING_COUNT
ff6vwf_main_menu_tile_counts: .byte 5, 5,  5,  5,  5,  5,  5,  5,  5,  5
ff6vwf_main_menu_start_tiles: .byte 0, 5, 10, 15, 20, 25, 30, 35, 40, 45

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

; Stats labels

ff6vwf_stats_static_text_descriptor_bg1:
    .byte FF6VWF_STATS_STRING_COUNT                                         ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP   ; DMA flags
    .word VWF_MENU_TILE_BG1_BASE_ADDR                                       ; base address
    .faraddr ff6vwf_stats_labels                                            ; strings
    .faraddr ff6vwf_stats_tile_counts                                       ; tile counts
    .faraddr ff6vwf_stats_start_tiles                                       ; start tiles

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

ff6vwf_status_static_text_descriptor:
    .byte STATUS_STRING_COUNT                                               ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP   ; DMA flags
    .word VWF_MENU_TILE_BG1_BASE_ADDR                                       ; base address
    .faraddr ff6vwf_status_labels                                           ; strings
    .faraddr ff6vwf_status_tile_counts                                      ; tile counts
    .faraddr ff6vwf_status_start_tiles                                      ; start tiles

ff6vwf_status_labels: ff6vwf_def_pointer_array ff6vwf_status_label, STATUS_STRING_COUNT

ff6vwf_status_tile_counts: .byte 10, 10, 10, 10, 10, 10, 10, 10, 10, 10
ff6vwf_status_start_tiles: .byte  0, 10, 20, 30, 40, 50, 60, 70, 80, 90

ff6vwf_status_label_0:  .asciiz "Experience"
ff6vwf_status_label_1:  .asciiz "EXP to Next Level"

ff6vwf_status_command_first_tiles:
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*0   ; Attack
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*1   ; Items
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*2   ; Magic
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*3   ; Morph
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*3   ; Revert
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*3   ; Steal
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*3   ; Mug
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*4   ; Bushido
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*5   ; Throw
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*6   ; Tools
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*7   ; Blitz
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*8   ; Runic
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*9   ; Lore
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*10  ; Sketch
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*10  ; Control
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*11  ; Slot
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*12  ; Rage
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*13  ; Leap
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*14  ; Mimic
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*15  ; Dance
    .byte 0                                                     ; Row
    .byte 0                                                     ; Defend
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*6   ; Jump
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*2   ; Dualcast
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*5   ; Gil Toss
    .byte 0                                                     ; Summon
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*6   ; Pray
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*6   ; Shock
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*6   ; Possess
    .byte FF6VWF_FIRST_TILE + FF6_SHORT_COMMAND_NAME_LENGTH*0   ; Magitek

; Config menu static text

ff6vwf_config_static_text_descriptor:
    .byte CONFIG_STRING_COUNT                                               ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP   ; DMA flags
    .word VWF_MENU_TILE_BG1_BASE_ADDR                                       ; base address
    .faraddr ff6vwf_config_labels                                           ; strings
    .faraddr ff6vwf_config_tile_counts                                      ; tile counts
    .faraddr ff6vwf_config_start_tiles                                      ; start tiles

ff6vwf_config_labels: ff6vwf_def_pointer_array ff6vwf_config_label, CONFIG_STRING_COUNT

ff6vwf_config_tile_counts: .byte 10, 10, 10, 10, 10, 10, 10, 10, 10, 10,  10
ff6vwf_config_start_tiles: .byte  0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100

ff6vwf_config_label_0:  .asciiz "ATB Mode"
ff6vwf_config_label_1:  .asciiz "Battle Speed"
ff6vwf_config_label_2:  .asciiz "Text Speed"
ff6vwf_config_label_3:  .asciiz "Command Set"
ff6vwf_config_label_4:  .asciiz "ATB Gauge"
ff6vwf_config_label_5:  .asciiz "Sound"
ff6vwf_config_label_6:  .asciiz "Reequip"
ff6vwf_config_label_7:  .asciiz "Controllers"
ff6vwf_config_label_8:  .asciiz "Magic Order"
ff6vwf_config_label_9:  .asciiz "Window Color"
ff6vwf_config_label_10: .asciiz "Cursor"
