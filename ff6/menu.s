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
.import std_memset: near
.import std_div16_8: near
.import std_mod16_8: near
.import std_mul16_8: near
.import std_mul8: near

.import ff6vwf_calculate_first_tile_id_simple: near
.import ff6vwf_get_long_item_name: near
.import ff6vwf_render_string: near
.import ff6vwf_transcode_string: near
.import ff6vwf_long_command_names: far
.import ff6vwf_long_spell_names: far
.import ff6vwf_long_esper_names: far
.import ff6vwf_long_blitz_names: far
.import ff6vwf_long_lore_names: far
.import ff6vwf_long_dance_names: far
.import ff6vwf_long_key_item_names: far
.import ff6vwf_long_class_names: far
.import ff6vwf_long_enemy_names: far
.import ff6vwf_long_item_names: far

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

; List item is a Key Item.
FF6VWF_MENU_DRAW_LIST_ITEM_FLAGS_KEY_ITEM = $01

MAIN_MENU_STRING_COUNT = 10
ITEM_MENU_STRING_COUNT = 4
SKILLS_MENU_STRING_COUNT = 7
EQUIP_MENU_STRING_COUNT = 8
STATS_STRING_COUNT = 9
RELIC_MENU_STRING_COUNT = 3
STATUS_STRING_COUNT = 2
CONFIG_STRING_COUNT = 11

SHORT_ESPER_BONUS_NAME_LENGTH = 10

EQUIP_MENU_FIRST_STATS_TILE = 36
STATUS_FIRST_LABEL_TILE     = 50

FF6_MENU_ESPER_BONUS_AT_LEVEL_UP_TILE_LOCATION = $4713
FF6_MENU_ESPER_BONUS_AT_LEVEL_UP_MESSAGE_SIZE = 14
FF6_MENU_ESPER_BONUS_TILE_LOCATION = $4713

STATS_TILE_COUNT_STRENGTH = 5
STATS_TILE_COUNT_STAMINA = 5
STATS_TILE_COUNT_MAGIC = 3
STATS_TILE_COUNT_EVASION = 5
STATS_TILE_COUNT_MAGIC_EVASION = 7
STATS_TILE_COUNT_SPEED = 4
STATS_TILE_COUNT_ATTACK = 4
STATS_TILE_COUNT_DEFENSE = 5
STATS_TILE_COUNT_MAGIC_DEFENSE = 6

STATS_TILE_INDEX_STRENGTH      = 0
STATS_TILE_INDEX_STAMINA       = STATS_TILE_INDEX_STRENGTH      + STATS_TILE_COUNT_STRENGTH
STATS_TILE_INDEX_MAGIC         = STATS_TILE_INDEX_STAMINA       + STATS_TILE_COUNT_STAMINA
STATS_TILE_INDEX_EVASION       = STATS_TILE_INDEX_MAGIC         + STATS_TILE_COUNT_MAGIC
STATS_TILE_INDEX_MAGIC_EVASION = STATS_TILE_INDEX_EVASION       + STATS_TILE_COUNT_EVASION
STATS_TILE_INDEX_SPEED         = STATS_TILE_INDEX_MAGIC_EVASION + STATS_TILE_COUNT_MAGIC_EVASION
STATS_TILE_INDEX_ATTACK        = STATS_TILE_INDEX_SPEED         + STATS_TILE_COUNT_SPEED
STATS_TILE_INDEX_DEFENSE       = STATS_TILE_INDEX_ATTACK        + STATS_TILE_COUNT_ATTACK
STATS_TILE_INDEX_MAGIC_DEFENSE = STATS_TILE_INDEX_DEFENSE       + STATS_TILE_COUNT_DEFENSE
STATS_TOTAL_TILE_COUNT         = STATS_TILE_INDEX_MAGIC_DEFENSE + STATS_TILE_COUNT_MAGIC_DEFENSE

; FF6 globals

ff6_menu_null                       = $7e0000
ff6_menu_current_state              = $7e0026
ff6_menu_current_selection          = $7e0028
ff6_menu_bg_attrs                   = $7e0029
ff6_menu_bg2_hscroll                = $7e0039
ff6_menu_bg3_hscroll                = $7e003d
ff6_menu_queued_hdma                = $7e0043
ff6_menu_list_scroll                = $7e004a
ff6_menu_page_height                = $7e005a
ff6_menu_page_width                 = $7e005b
ff6_menu_max_page_scroll_pos        = $7e005c
ff6_actor_address                   = $7e0067
ff6_menu_list_slot                  = $7e00e5
ff6_menu_bg1_write_row              = $7e00e6
ff6_menu_src_ptr                    = $7e00e7
ff6_menu_dest_ptr                   = $7e00eb
ff6_menu_horizontal_movement_speed  = $7e34ca
ff6_menu_vertical_movement_speed    = $7e354a
ff6_menu_bg1_data                   = $7e3849
ff6_menu_bg3_data                   = $7e7849
ff6_menu_list                       = $7e9d89
ff6_menu_positioned_text_ptr        = $7e9e89
ff6_menu_string_buffer              = $7e9e8b

; FF6 functions
ff6_menu_create_scrollbar   = $c3091f
ff6_menu_set_string_pos     = $c33519

; FF6-specific macros

; Declares a trampoline that allows our VWF code to call back to FF6.
.macro def_trampoline target
    phd
    pea $0
    pld
    jsr target
    pld
    rtl
.endmacro

.define bg1_position(col, row)  .loword(ff6_menu_bg1_data) + row * $40 + col * 2
.define bg3_position(col, row)  .loword(ff6_menu_bg3_data) + row * $40 + col * 2

.segment "BSS"

; Menu BSS
.org $7eb000

; Current of the stack *in bytes*.
ff6vwf_menu_text_dma_stack_size: .res 1
; Last party member drawn in Lineup. This avoids uploading every frame, which causes flicker.
ff6vwf_last_lineup_party_member: .res 1
ff6vwf_current_equipment_text_slot: .res 1
; True if we're drawing current equipment to BG3, false if BG1.
ff6vwf_current_equipment_bg3: .res 1
; Stack of DMA structures, just like the encounter ones.
ff6vwf_menu_text_dma_stack_base: .res FF6VWF_DMA_STRUCT_SIZE * FF6VWF_MENU_SLOT_COUNT
; Buffer space for the lines of text, `FF6VWF_MAX_LINE_LENGTH` each to be stored, ready to be uploaded
; to VRAM.
ff6vwf_menu_text_tiles: .res VWF_TILE_BYTE_SIZE_4BPP * 128

ff6vwf_menu_bss_end:

.export ff6vwf_menu_text_dma_stack_base
.export ff6vwf_menu_text_tiles
.export ff6vwf_menu_text_dma_stack_size
.export ff6vwf_menu_bss_end

.reloc 

; Patches to Final Fantasy 6 functions

; Final Fantasy 6 menu patches

.segment "PTEXTMENUINIT"
    jml _ff6vwf_menu_init

; FIXME(tachiweasel): This is necessary to preserve Y but breaks the Kefka lineup!
.segment "PTEXTMENUDRAWPCNAME"              ; $c334cf
    jsl _ff6vwf_menu_draw_pc_name
    rts

.segment "PTEXTMENULOADEQUIPMENTNAME"       ; $c38fe1
ff6_menu_trigger_nmi = $1368

    jsl _ff6vwf_menu_draw_equipment_name
    rts

; Let's put some trampolines here.
_ff6vwf_menu_force_nmi_trampoline:          def_trampoline ff6_menu_trigger_nmi
_ff6vwf_menu_compute_map_ptr_trampoline:    def_trampoline $809f
_ff6vwf_menu_move_blitz_tilemap_trampoline: def_trampoline $56bc

.export _ff6vwf_menu_force_nmi_trampoline

; FF6 routine to draw an item in the Item menu.
.segment "PTEXTMENUDRAWITEMNAME"
    jml _ff6vwf_menu_draw_inventory_item_name_for_item_menu   ; 4 bytes
    nopx 3

; FF6 routine to draw an item available to equip, in the Equip or Relic menus.
.segment "PTEXTMENUDRAWITEMTOEQUIPNAME"
    jsl _ff6vwf_menu_draw_item_to_equip_name        ; 4 bytes
    nopx 3                                          ; overwrite `jsr $c39d11`

; Part of the FF6 routine to draw "<item name> can be used by:". We currently display "Equipment"
; in a fixed-width font instead of the item name because we don't have enough space to display that
; string in memory yet.
.segment "PTEXTMENUDRAWGEARINFOTEXT"
    jml _ff6vwf_menu_draw_gear_info_text

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

.segment "PTEXTMENUDRAWSPELLNAMEINMAGICMENU"    ; $c3504c
    jsl _ff6vwf_menu_draw_spell_name_in_magic_menu
    nopx 2

.segment "PTEXTMENUINITESPERSMENU"      ; $c320b3
ff6_menu_create_blinker                 = $c32eeb
ff6_menu_espers_load_navigation_data    = $c34c18
ff6_menu_espers_relocate_cursor         = $c34c21
ff6_menu_draw_espers                    = $c35452

FF6_MENU_STATE_ESPERS = $1e

    stz <ff6_menu_list_scroll                           ; List scroll: 0
    jsr .loword(ff6_menu_create_scrollbar)              ; Create scrollbar
    a16                                                 ; 16-bit A
    lda #$0800                                          ; V-Speed: 8 px
    sta f:ff6_menu_vertical_movement_speed,x            ; Set scrollbar's
    lda #104                                            ; Y: 104
    sta f:ff6_menu_horizontal_movement_speed,x          ; Set scrollbar's
    a8                                                  ; 8-bit A
    jsr .loword(ff6_menu_espers_load_navigation_data)   ; Load navig data
    jsr .loword(ff6_menu_espers_relocate_cursor)        ; Relocate cursor
    jsl _ff6vwf_menu_setup_espers_menu
    jsr .loword(ff6_menu_draw_espers)                   ; Draw espers, etc.
    lda #FF6_MENU_STATE_ESPERS                          ; C3/28D3
    sta <ff6_menu_current_state                         ; Next: Sustain menu
    jsr .loword(ff6_menu_create_blinker)                ; Create blinker
    rts

; FF6 duplicates menu setup code into this and the above. We consolidate it.
.segment "PTEXTMENULEAVEESPERINFOMENU"      ; $c35950
    jsl _ff6vwf_menu_setup_espers_menu      ; 4 bytes
    nopx $595c-$5954

.segment "PTEXTMENUDRAWESPERSROW"       ; $c354e3
ff6_menu_espers_define_source   = $c354fa
ff6_menu_espers_draw            = $c35509

    jsr .loword(ff6_menu_espers_define_source)  ; Define source
    ldx #3                                      ; X: 3
    jsr .loword(ff6_menu_espers_draw)           ; Draw esper A
    inc <ff6_menu_list_slot                     ; Esper slot +1
    rts

; FF6 routine to draw an esper in the Espers menu.
.segment "PTEXTMENUDRAWESPERNAME"           ; $c35527
    jsl _ff6vwf_menu_draw_esper_name        ; 4 bytes
    rts

.segment "PTEXTMENUDRAWESPERNAMEININFOMENU" ; $c359ba
ff6_menu_selected_esper = $7e0099

    ldx <ff6_menu_selected_esper
    jsl _ff6vwf_menu_draw_esper_name_in_info_menu
    nopx $59d2-$59ba-6

.segment "PTEXTMENUDRAWESPERBONUS"          ; $c35a33
ff6_menu_at_level_up_message = $c35cf7

    pha                                                     ; Save bonus ID
    ldy #FF6_MENU_ESPER_BONUS_AT_LEVEL_UP_TILE_LOCATION     ; Tilemap ptr
    jsr .loword(ff6_menu_set_string_pos)                    ; Set pos, WRAM
    ldx #0                                                  ; Char index: 0
:   lda f:ff6_menu_at_level_up_message,x                    ; "At..." char
    sta WMDATA                                              ; Add to string
    inx                                                     ; Point to next
    cpx #FF6_MENU_ESPER_BONUS_AT_LEVEL_UP_MESSAGE_SIZE      ; Done all 14?
    bne :-                                                  ; Loop if not
    pla                                                     ; Restore bonus ID
    tax                                                     ; Put in X
    jsl _ff6vwf_menu_draw_esper_bonus                       ; Draw Esper bonus
    jmp ff6_menu_draw_string                                ; Draw string

.segment "PTEXTMENUDRAWSPELLNAMEINESPERINFOMENU"    ; $c35af6
    jsl _ff6vwf_menu_draw_spell_name_in_esper_info_menu
    nopx 2

.segment "PTEXTMENUINITRAGEMENU"
ff6_menu_rage_load_navigation_data  = $c34c4c
ff6_menu_rage_relocate_cursor       = $c34c55
ff6_menu_draw_rages                 = $c35391

FF6_MENU_STATE_RAGE = $1d

    stz <ff6_menu_list_scroll                       ; List scroll: 0
    jsr .loword(ff6_menu_create_scrollbar)          ; Create scrollbar
    a16
    lda #$0066                                      ; V-Speed: 0.4 px
    sta f:ff6_menu_vertical_movement_speed,x        ; Set scrollbar's
    lda #$0068                                      ; Y: 104
    sta f:ff6_menu_horizontal_movement_speed,x      ; Set scrollbar's
    a8
    jsr .loword(ff6_menu_rage_load_navigation_data) ; Load navig data
    jsr .loword(ff6_menu_rage_relocate_cursor)      ; Relocate cursor
    lda #$f0                                        ; Top row
    sta <ff6_menu_max_page_scroll_pos               ; Set scroll limit
    lda #8                                          ; Onscreen rows: 8
    sta <ff6_menu_page_height                       ; Set rows per page
    lda #1                                          ; Onscreen cols: 1
    sta <ff6_menu_page_width                        ; Set cols per page
    ldy #256                                        ; X: 256
    sty <ff6_menu_bg2_hscroll                       ; Set BG2 X-Pos
    sty <ff6_menu_bg3_hscroll                       ; Set BG3 X-Pos
    jsr .loword(ff6_menu_draw_rages)                ; Draw rages, etc.
    lda #FF6_MENU_STATE_RAGE                        ; C3/28BA
    sta <ff6_menu_current_state                     ; Next: Sustain menu
    rts

.segment "PTEXTMENUDRAWRAGEROW"
ff6_menu_rage_define_source = $c35409
ff6_menu_rage_draw          = $c35418

    lda #$20                                    ; Palette 0
    sta <ff6_menu_bg_attrs                      ; Color: User's
    jsr .loword(ff6_menu_rage_define_source)    ; Define source
    ldx #5                                      ; X: 5
    jsr .loword(ff6_menu_rage_draw)             ; Draw Rage A
    inc <ff6_menu_list_slot                     ; Rage slot +1
    rts

; FF6 routine to draw a rage in the Skills menu.
.segment "PTEXTMENUDRAWRAGENAME"
    jsl _ff6vwf_menu_draw_rage_name         ; 4 bytes
    nop

; FF6 Esper menu navigation data, patched to be 1 column
.segment "PTEXTMENUESPERSNAVDATA"       ; $c34c27
ff6_menu_espers_nav_data:
    .byte $01          ; Wraps horizontally
    .byte $00          ; Initial column
    .byte $00          ; Initial row
    .byte $01          ; 1 column
    .byte $08          ; 8 rows

; Cursor positions for Espers menu
ff6_menu_espers_cursor_data:
    .word $7408        ; Esper 1
    .word $8008        ; Esper 2
    .word $8C08        ; Esper 3
    .word $9808        ; Esper 4
    .word $A408        ; Esper 5
    .word $B008        ; Esper 6
    .word $BC08        ; Esper 7
    .word $C808        ; Esper 8

; FF6 Rage menu navigation data, patched to be 1 column
.segment "PTEXTMENURAGENAVDATA"
ff6_menu_rage_nav_data:
    .byte $01       ; Wraps horizontally
    .byte $00       ; Initial column
    .byte $00       ; Initial row
    .byte $01       ; 1 column
    .byte $08       ; 8 rows
ff6_menu_rage_cursor_data:
    .word $7418        ; Rage 1
    .word $8018        ; Rage 2
    .word $8C18        ; Rage 3
    .word $9818        ; Rage 4
    .word $A418        ; Rage 5
    .word $B018        ; Rage 6
    .word $BC18        ; Rage 7
    .word $C818        ; Rage 8

; Code imported from Ted Woolsey Uncensored Edition (hereafter TWUE) at $c355e4 to label Sabin's
; Blitzes in the menu.
;
; We import the code as-is in order to maintain compatibility with TWUE.
.segment "PTEXTMENUBUILDBLITZMENUTWUE"
ff6_menu_vertical_page_offset = $49

.proc ff6twue_build_blitz_menu
ff6_menu_build_blitz_list = $c3561b
ff6_menu_init_menu_pos = $c383f7

    jsr a:.loword(ff6_menu_build_blitz_list)
    jsr a:.loword(ff6_menu_init_menu_pos)
    stz <ff6_menu_list_slot
    inc <ff6_menu_bg1_write_row
    ldy #16
@loop:
    phy
    tya
    lsr
    lda #4
    bcc :+
    adc #13
:   tax
    jsr a:.loword(ff6vwf_menu_draw_blitz)
    inc <ff6_menu_list_slot
    lda #$e0
    trb <ff6_menu_bg1_write_row
    inc <ff6_menu_bg1_write_row
    ply
    jsl _ff6twue_menu_blitz_next_row        ; Implicitly decrements Y.
    bne @loop
    rts
.endproc

; At $c35614 in Ted Woolsey Uncensored Edition.
.proc _ff6twue_menu_blitz_compute_map_ptr
ff6_menu_compute_bg1_tilemap_a_pos = $c3809f
    dec
    ora #1                                          ; Make Y position odd.
    jmp .loword(ff6_menu_compute_bg1_tilemap_a_pos) ; Compute map pointer.
.endproc

; nearproc void ff6twue_build_tilemap(uint8 inreg(A) blitz_id)
.segment "PTEXTMENUBLITZBUILDTILEMAPTWUE"
.proc ff6twue_menu_blitz_build_tilemap
    jsl _ff6twue_menu_blitz_build_tilemap
    rts
.endproc

.segment "PTEXTMENUDRAWBLITZ"
ff6vwf_menu_draw_blitz:
    lda z:<ff6_menu_bg1_write_row
    jsr _ff6twue_menu_blitz_compute_map_ptr

.segment "PTEXTMENUDRAWLORE"    ; $c35290
    jsl _ff6vwf_menu_draw_lore
    nop

.segment "PTEXTMENUDRAWDANCE"
    jsl _ff6vwf_menu_draw_dance
    rts

.segment "PTEXTMENUDRAWITEMTOBEUSED"        ; $c38a0e
    jsl _ff6vwf_menu_draw_item_to_be_used
    nopx 7

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

; This displays the held Esper in the Skills menu and the Lineup menu.
.segment "PTEXTMENUDRAWESPERNAMEINSTATUSPANEL"
    tax
    jsl _ff6vwf_menu_draw_esper_name_in_info_menu
    jmp .loword(ff6_menu_draw_string)

.segment "PTEXTMENUDRAWKEYITEM"         ; $c38460
    jml _ff6vwf_menu_draw_key_item
    stp     ; should never be reached

.segment "PTEXTMENUDRAWMAINMENU"        ; $c33221
    jsl _ff6vwf_menu_draw_main_menu

.segment "PTEXTMENUDRAWITEMMENU"        ; $c37de5
    jsl _ff6vwf_menu_draw_item_menu

.segment "PTEXTMENUDRAWSKILLSMENU"      ; $c34cde
    jsl _ff6vwf_menu_draw_skills_menu

.segment "PTEXTMENUDRAWEQUIPMENU"       ; $c3903c
    jsl _ff6vwf_menu_draw_equip_menu
    nopx 2

.segment "PTEXTMENUDRAWRELICMENU"       ; $c39081
    jsl _ff6vwf_menu_draw_relic_menu
    nopx 2

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
    jsr _ff6vwf_menu_force_nmi

    ; Draw tiles.
    ldx first_tile_id
    ldy #FF6_SHORT_PC_NAME_LENGTH
    stz outgoing_args+0                 ; blanks_count
    stz outgoing_args+1                 ; initial_offset
    jsr _ff6vwf_menu_draw_vwf_tiles

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

; farproc void _ff6vwf_menu_draw_equipment_name(inreg(A) uint8 item_id)
.proc _ff6vwf_menu_draw_equipment_name
begin_locals
    decl_local outgoing_args, 6
    decl_local item_id, 1
    decl_local string_ptr, 2
    decl_local first_tile_id, 1
    decl_local base_addr, 2
    decl_local dma_flags, 1

    tax             ; Put item ID in X.

    enter __FRAME_SIZE__

    ; Initialize locals.
    txa
    sta item_id

    ; Draw item icon.
    tax
    jsr _ff6vwf_menu_draw_item_icon

    ; Compute string pointer.
    ldx item_id
    jsr ff6vwf_get_long_item_name
    stx string_ptr

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
    ldy #VWF_MENU_TILE_BG1_BASE_ADDR
    bra :++
:   lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    ldy #VWF_MENU_TILE_BG3_BASE_ADDR
:   sta dma_flags
    sty base_addr

    ; Render string.
    lda #10
    sta outgoing_args+0     ; max_tile_count
    lda dma_flags
    sta outgoing_args+1     ; flags
    ldy string_ptr
    sty outgoing_args+2     ; string ptr
    lda #^ff6vwf_long_item_names
    sta outgoing_args+4     ; string ptr bank
    ldy base_addr
    jsr ff6vwf_render_string

    ; Upload it now.
    jsr _ff6vwf_menu_force_nmi

    ; Draw tiles.
    ldx first_tile_id
    ldy #10
    lda #FF6_SHORT_ITEM_LENGTH - 10
    sta outgoing_args+0                 ; blanks_count
    lda #1
    sta outgoing_args+1                 ; initial_offset
    jsr _ff6vwf_menu_draw_vwf_tiles

    leave __FRAME_SIZE__
    rtl
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

.proc _ff6vwf_menu_draw_gear_info_text
    ldx #0
:   lda f:ff6vwf_string_equipment,x
    sta f:ff6_menu_string_buffer,x
    inx
    cpx #ff6vwf_string_equipment_end-ff6vwf_string_equipment
    bne :-

    pea $856a+6-1
    jml $c385ad
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

    enter __FRAME_SIZE__

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

.export _ff6vwf_menu_store_text_line_slot_for_gear_overview

; farproc void _ff6vwf_menu_draw_spell_name_in_magic_menu()
.proc _ff6vwf_menu_draw_spell_name_in_magic_menu
    ; Compute text line slot.
    lda f:ff6_menu_list_slot
    a16
    and #$00ff
    tax
    a8
    ldy #18             ; 8 visible rows plus one off-screen row, 2 columns
    jsr std_mod16_8
    tay                 ; spell slot

    lda f:ff6_menu_list_slot
    a16
    and #$00ff
    tax
    a8
    lda f:ff6_menu_list,x
    tax                 ; spell ID

    jmp _ff6vwf_menu_draw_spell_name
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

    enter __FRAME_SIZE__

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
    jsr _ff6vwf_menu_draw_item_icon

    ; Compute string pointer.
    ldx item_id
    jsr ff6vwf_get_long_item_name
    stx string_ptr

    ; Compute the actual text line slot by modding the one we were given by 11.
    lda text_line_slot
    a16
    and #$00ff
    tax
    a8
    ldy #11
    jsr std_mod16_8
    txa
    sta text_line_slot

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple
    txa
    sta first_tile_id

    ; Render string.
    lda #10
    sta outgoing_args+0     ; max_tile_count
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP | FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+1     ; flags
    ldy string_ptr
    sty outgoing_args+2
    lda #^ff6vwf_long_item_names
    sta outgoing_args+4
    ldy #VWF_MENU_TILE_BG1_BASE_ADDR
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsr _ff6vwf_menu_force_nmi

    ; Draw tiles.
    ldx first_tile_id
    ldy #10
    lda #FF6_MENU_INVENTORY_ITEM_LENGTH - 10 - 1
    sta outgoing_args+0                 ; blanks_count
    lda #1
    sta outgoing_args+1                 ; initial_offset
    jsr _ff6vwf_menu_draw_vwf_tiles

@out:
    leave __FRAME_SIZE__
    a16
    lda #0
    a8
    rts
.endproc

.export _ff6vwf_menu_draw_inventory_item_name ; for debugging

; nearproc void _ff6vwf_menu_draw_vwf_tiles(uint8 first_tile_id,
;                                           uint8 text_tile_count,
;                                           uint8 blanks_count,
;                                           uint8 initial_offset)
.proc _ff6vwf_menu_draw_vwf_tiles
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

.export _ff6vwf_menu_draw_vwf_tiles

; nearproc void _ff6vwf_menu_draw_attributed_vwf_tiles(uint8 text_line_slot,
;                                                      uint8 tile_count,
;                                                      uint8 attributes)
.proc _ff6vwf_menu_draw_attributed_vwf_tiles
begin_locals
    decl_local byte_count, 2
    decl_local current_tile, 1
begin_args_nearcall
    decl_arg attributes, 1

    enter __FRAME_SIZE__

    ; Initialize locals.
    tya
    a16
    and #$00ff
    asl
    sta byte_count
    a8

    ; Calculate first tile index.
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple
    txa
    sta current_tile

    ; Draw tiles.
    ldx #0
    ldy #10
:   lda current_tile
    sta f:ff6_menu_string_buffer,x
    inc current_tile
    inx
    lda attributes
    sta f:ff6_menu_string_buffer,x
    inx
    dey
    bne :-

    ; Draw blanks.
    lda attributes
    xba
    lda #$ff
    a16
:   cpx byte_count
    bge :+
    sta f:ff6_menu_string_buffer,x
    inx
    inx
    bra :-
:   a8

    ; Null terminate.
    lda #0
    sta f:ff6_menu_string_buffer,x
    sta f:ff6_menu_string_buffer+1,x

    leave __FRAME_SIZE__
    rts
.endproc

; nearproc void _ff6vwf_menu_force_nmi()
;
; Just like FF6's "force NMI" routine at $c31368, but without messing with the force blank
; (INIDISP) settings. This allows us to wait for NMIs without turning the screen on, which might
; confuse FF6 and cause it to try to perform DMA with the screen on.
.proc _ff6vwf_menu_force_nmi
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

.export _ff6vwf_menu_force_nmi

; nearproc void _ff6vwf_menu_commit_transaction()
;
; Flushes all DMA.
.proc _ff6vwf_menu_commit_transaction
    lda f:ff6vwf_menu_text_dma_stack_size
@loop:
    beq @out
    jsr _ff6vwf_menu_force_nmi
    lda f:ff6vwf_menu_text_dma_stack_size
    bra @loop
@out:
    rts
.endproc

.proc _ff6vwf_menu_setup_espers_menu
    lda #18                                             ; Top row: Midgardsormr (Terrato)
    sta f:ff6_menu_max_page_scroll_pos                  ; Set scroll limit
    lda #8                                              ; Onscreen rows: 8
    sta f:ff6_menu_page_height                          ; Set rows per page
    lda #1                                              ; Onscreen cols: 1
    sta f:ff6_menu_page_width                           ; Set cols per page
    a16
    lda #256                                            ; X: 256
    sta f:ff6_menu_bg2_hscroll                          ; Set BG2 X-Pos
    sta f:ff6_menu_bg3_hscroll                          ; Set BG3 X-Pos
    a8
    rtl
.endproc

.proc _ff6vwf_menu_draw_esper_name
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__

    ldx #.loword(ff6vwf_long_esper_names)
    stx outgoing_args+0
    lda #^ff6vwf_long_esper_names
    sta outgoing_args+2
    ldx #FF6_SHORT_ESPER_NAME_LENGTH
    ldy #0
    jsr _ff6vwf_menu_draw_list_item

    leave __FRAME_SIZE__
    a16
    lda #0      ; The original function did this...
    a8
    rtl
.endproc

; farpatch _ff6vwf_menu_draw_key_item()
.proc _ff6vwf_menu_draw_key_item
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__

    ldx #.loword(ff6vwf_long_key_item_names)
    stx outgoing_args+0
    lda #^ff6vwf_long_key_item_names
    sta outgoing_args+2
    ldx #FF6_SHORT_KEY_ITEM_NAME_LENGTH
    ldy #FF6VWF_MENU_DRAW_LIST_ITEM_FLAGS_KEY_ITEM
    jsr _ff6vwf_menu_draw_list_item

    leave __FRAME_SIZE__
    jml ff6_menu_draw_string
.endproc

.export _ff6vwf_menu_draw_key_item

; nearproc void _ff6vwf_menu_draw_list_item(uint8 short_name_length,
;                                           uint8 flags,
;                                           const char near *const far *name_list)
.proc _ff6vwf_menu_draw_list_item
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
    jsl _ff6vwf_menu_force_nmi_trampoline

    ; Draw tiles.
    ldx first_tile_id
    ldy max_tile_count
    lda blanks_count
    sta outgoing_args+0                 ; blanks_count
    stz outgoing_args+1                 ; initial_offset
    jsr _ff6vwf_menu_draw_vwf_tiles

    leave __FRAME_SIZE__
    rts
.endproc

; farproc void _ff6vwf_menu_draw_esper_name_in_info_menu(uint8 esper_id)
.proc _ff6vwf_menu_draw_esper_name_in_info_menu
begin_locals
    decl_local outgoing_args, 6
    decl_local string_ptr, 2

TEXT_LINE_SLOT = 9
FIRST_TILE_ID = TEXT_LINE_SLOT * 10 + FF6VWF_FIRST_TILE

    enter __FRAME_SIZE__

    ; Compute string pointer.
    a16
    txa
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_esper_names,x
    sta string_ptr
    a8

    ; Render string.
    lda #10
    sta outgoing_args+0     ; max_tile_count
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP | FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+1     ; 4bpp
    ldy string_ptr
    sty outgoing_args+2     ; string ptr
    lda #^ff6vwf_long_esper_names
    sta outgoing_args+4     ; string ptr bank
    ldy #VWF_MENU_TILE_BG1_BASE_ADDR
    ldx #FIRST_TILE_ID
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsr _ff6vwf_menu_force_nmi

    ; Draw tiles.
    ldx #FIRST_TILE_ID
    ldy #FF6_SHORT_ESPER_NAME_LENGTH
    stz outgoing_args+0                 ; blanks_count
    stz outgoing_args+1                 ; initial_offset
    jsr _ff6vwf_menu_draw_vwf_tiles

    leave __FRAME_SIZE__
    rtl
.endproc

.export _ff6vwf_menu_draw_esper_name_in_info_menu

; farproc void _ff6vwf_menu_draw_esper_bonus(uint8 bonus_id)
.proc _ff6vwf_menu_draw_esper_bonus
begin_locals
    decl_local outgoing_args, 6
    decl_local string_ptr, 2

FIRST_TILE_ID = FF6VWF_FIRST_TILE + 60

    enter __FRAME_SIZE__

    ; Look up pointer.
    a16
    txa
    and #$00ff
    asl
    tax
    lda f:ff6vwf_esper_bonus_descriptions,x
    sta string_ptr
    a8

    ; Render string.
    lda #SHORT_ESPER_BONUS_NAME_LENGTH
    sta outgoing_args+0     ; max_tile_count
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    sta outgoing_args+1     ; flags
    ldx string_ptr
    stx outgoing_args+2     ; string ptr
    lda #^ff6vwf_esper_bonus_descriptions
    sta outgoing_args+4     ; string ptr bank
    ldy #VWF_MENU_TILE_BG1_BASE_ADDR
    ldx #FIRST_TILE_ID
    jsr ff6vwf_render_string

    ; Upload it now.
    jsr _ff6vwf_menu_force_nmi

    ; Draw tiles.
    ldx #FIRST_TILE_ID
    ldy #SHORT_ESPER_BONUS_NAME_LENGTH
    stz outgoing_args+0                 ; blanks_count
    lda #FF6_MENU_ESPER_BONUS_AT_LEVEL_UP_MESSAGE_SIZE
    sta outgoing_args+1                 ; initial_offset
    jsr _ff6vwf_menu_draw_vwf_tiles

    leave __FRAME_SIZE__
    a16
    txy
    lda #0
    ldx #0
    a8
    rtl
.endproc

; farproc void _ff6vwf_menu_draw_spell_name_in_esper_info_menu()
.proc _ff6vwf_menu_draw_spell_name_in_esper_info_menu
ff6_current_spell_id    = $7e00e1
ff6_current_row         = $7e00f5

FIRST_SPELL_ROW = $11

    ; Calculate text slot.
    a16
    lda ff6_current_row
    sub #FIRST_SPELL_ROW
    lsr
    tay
    a8

    lda f:ff6_current_spell_id
    tax
    jmp _ff6vwf_menu_draw_spell_name

.endproc

; farproc void _ff6vwf_menu_draw_spell_name(uint8 spell_id, uint8 text_slot)
.proc _ff6vwf_menu_draw_spell_name
begin_locals
    decl_local outgoing_args, 6
    decl_local spell_id, 1
    decl_local string_ptr, 2
    decl_local text_line_slot, 1
    decl_local first_tile_id, 1

    enter __FRAME_SIZE__

    ; Store arguments.
    txa
    sta spell_id
    tya
    sta text_line_slot

    ; Compute string pointer.
    lda spell_id
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_spell_names,x
    sta string_ptr
    a8

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy #5
    jsr ff6vwf_calculate_first_tile_id_simple
    txa
    sta first_tile_id

    ; Render string.
    lda #5
    sta outgoing_args+0     ; 4bpp
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP | FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+1     ; 4bpp
    ldy string_ptr
    sty outgoing_args+2     ; string ptr
    lda #^ff6vwf_long_spell_names
    sta outgoing_args+4     ; string ptr bank
    ldy #VWF_MENU_TILE_BG1_BASE_ADDR
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsl _ff6vwf_menu_force_nmi_trampoline

    ; Draw spell icon.
    ldx spell_id
    ldy #FF6_SHORT_SPELL_NAME_LENGTH
    jsr std_mul8
    lda ff6_short_spell_names,x
    sta ff6_menu_string_buffer

    ; Draw tiles.
    ldx first_tile_id
    ldy #5
    stz outgoing_args+0
    lda #1
    sta outgoing_args+1                 ; initial_offset
    jsr _ff6vwf_menu_draw_vwf_tiles

    ldx #$9e92      ; The original function did this...
    leave __FRAME_SIZE__
    rtl
.endproc

; farproc void _ff6vwf_menu_draw_rage_name()
.proc _ff6vwf_menu_draw_rage_name
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__

    ldx #.loword(ff6vwf_long_enemy_names)
    stx outgoing_args+0
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+2
    ldx #FF6_SHORT_ENEMY_NAME_LENGTH
    ldy #0
    jsr _ff6vwf_menu_draw_list_item

    leave __FRAME_SIZE__
    rtl
.endproc

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

; farproc void _ff6vwf_menu_draw_blitz(uint8 blitz_id)
.proc _ff6vwf_menu_draw_blitz
begin_locals
    decl_local outgoing_args, 7
    decl_local blitz_id, 1          ; uint8
    decl_local string_ptr, 2        ; const char near *
    decl_local text_line_slot, 1    ; uint8

FF6TWUE_BLITZ_NAME_ATTRS = $24

    enter __FRAME_SIZE__

    ; Initialize locals.
    txa
    sta blitz_id

    ; Compute slot.
    lda f:ff6_menu_list_slot
    sta text_line_slot

    ; Compute string pointer.
    lda blitz_id
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_blitz_names,x
    sta string_ptr
    a8

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple

    ; Render string.
    lda #10
    sta outgoing_args+0     ; 4bpp
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP | FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+1     ; 4bpp
    ldy string_ptr
    sty outgoing_args+2     ; string ptr
    lda #^ff6vwf_long_blitz_names
    sta outgoing_args+4     ; string ptr bank
    ldy #VWF_MENU_TILE_BG1_BASE_ADDR
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsl _ff6vwf_menu_force_nmi_trampoline

    ; Draw tiles.
    ldx text_line_slot
    ldy #FF6_SHORT_BLITZ_NAME_LENGTH
    lda #FF6TWUE_BLITZ_NAME_ATTRS
    sta outgoing_args+0
    jsr _ff6vwf_menu_draw_attributed_vwf_tiles

    ; FIXME(tachiweasel): Fill with blanks if no Blitz here.
    leave __FRAME_SIZE__
    rtl
.endproc

.export _ff6vwf_menu_draw_blitz     ; For debugging.

; farproc void _ff6vwf_menu_draw_lore()
.proc _ff6vwf_menu_draw_lore
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__

    ldx #.loword(ff6vwf_long_lore_names)
    stx outgoing_args+0
    lda #^ff6vwf_long_lore_names
    sta outgoing_args+2
    ldx #FF6_SHORT_LORE_NAME_LENGTH
    ldy 0
    jsr _ff6vwf_menu_draw_list_item

    leave __FRAME_SIZE__
    rtl
.endproc

; farproc void _ff6vwf_menu_draw_dance(uint8 tile_x_offset)
.proc _ff6vwf_menu_draw_dance
begin_locals
    decl_local outgoing_args, 3

ff6_menu_list           = $7e9d89

    enter __FRAME_SIZE__

    ; Save tile X offset.
    txy

    ; Check for dance in slot.
    lda f:ff6_menu_list_slot
    a16
    and #$00ff
    tax
    a8
    lda f:ff6_menu_list,x
    cmp #$ff
    beq @no_dance

    ; Draw dance name.
    ldx #.loword(ff6vwf_long_dance_names)
    stx outgoing_args+0
    tax                             ; X = blitz_id
    lda #^ff6vwf_long_blitz_names
    sta outgoing_args+2
    jsr _ff6vwf_menu_draw_blitz_or_dance_name

@no_dance:
    ; FIXME(tachiweasel): Fill with blanks if no dance here.
    leave __FRAME_SIZE__
    rtl
.endproc

; nearproc void _ff6vwf_menu_draw_blitz_or_dance_name(uint8 blitz_id,
;                                                     uint8 tile_x_offset,
;                                                     const char far *string_table)
.proc _ff6vwf_menu_draw_blitz_or_dance_name
begin_locals
    decl_local outgoing_args, 6
    decl_local string_ptr, 2        ; char near *
    decl_local tile_x_offset, 1
begin_args_nearcall
    decl_arg string_table, 3

    enter __FRAME_SIZE__

    ; Save tile X offset, and put Blitz ID in A.
    tya
    sta tile_x_offset
    txa

    ; Compute string pointer.
    a16
    and #$00ff
    asl
    tay
    lda [string_table],y
    sta string_ptr
    a8

    ; Compute map pointer.
    lda tile_x_offset
    a16
    and #$00ff
    tax
    a8
    lda f:ff6_menu_bg1_write_row
    jsl _ff6vwf_menu_compute_map_ptr_trampoline
    a16
    txa
    sta f:ff6_menu_positioned_text_ptr
    a8

    ; Calculate first tile ID.
    lda f:ff6_menu_list_slot
    tax
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple

    ; Render string.
    lda #10
    sta outgoing_args+0     ; max_tile_count
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP | FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+1     ; 4bpp
    ldy string_ptr
    sty outgoing_args+2     ; string ptr
    lda #^ff6vwf_long_blitz_names
    sta outgoing_args+4     ; string ptr bank
    ldy #VWF_MENU_TILE_BG1_BASE_ADDR
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsl _ff6vwf_menu_force_nmi_trampoline

    ; Draw tiles.
    lda f:ff6_menu_list_slot
    tax
    ldy #FF6_SHORT_BLITZ_NAME_LENGTH
    stz outgoing_args+0
    jsr _ff6vwf_menu_draw_attributed_vwf_tiles

    ; Move tilemap.
    a16
    lda #.loword(ff6_menu_positioned_text_ptr)
    sta f:ff6_menu_src_ptr+0
    a8
    lda #^ff6_menu_positioned_text_ptr
    sta f:ff6_menu_src_ptr+2
    jsl _ff6vwf_menu_move_blitz_tilemap_trampoline

    leave __FRAME_SIZE__
    rts
.endproc

; farproc void _ff6vwf_menu_draw_item_to_be_used()
.proc _ff6vwf_menu_draw_item_to_be_used
TEXT_LINE_SLOT = 0

ff6_menu_cursor_selected_inventory_slot = $7e004b

    lda f:ff6_menu_cursor_selected_inventory_slot
    tax
    jsr _ff6vwf_menu_get_inventory_item_id

    ldy #TEXT_LINE_SLOT
    jsr ff6vwf_menu_draw_item_name_bg3

    ; For some reason we have to do this to prevent the cursor from disappearing...
    a16
    lda #0
    a8
    ldx #0
    ldy #0

    rtl
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
    jsr _ff6vwf_menu_draw_item_icon

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
    jsl _ff6vwf_menu_force_nmi_trampoline

    ; Draw tiles.
    ldx first_tile_id
    ldy #FF6_SHORT_ITEM_LENGTH
    stz outgoing_args+0             ; blanks_count
    lda #1
    sta outgoing_args+1             ; initial_offset
    jsr _ff6vwf_menu_draw_vwf_tiles

    ; Save tilemap position where FF6 expects it.
    a16
    lda tilemap_position
    sta f:ff6_menu_positioned_text_ptr
    a8

    leave __FRAME_SIZE__
    rtl
.endproc

; nearproc void _ff6vwf_menu_draw_item_icon(uint8 item_id)
.proc _ff6vwf_menu_draw_item_icon
    ldy #FF6_SHORT_ITEM_LENGTH
    jsr std_mul8
    lda ff6_short_item_names,x
    sta ff6_menu_string_buffer
    rts
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
    jsl _ff6vwf_menu_force_nmi_trampoline

    ; Draw tiles.
    ldx #FIRST_TILE_ID
    ldy #FF6_SHORT_ENEMY_NAME_LENGTH
    stz outgoing_args+0                 ; blanks_count
    stz outgoing_args+1                 ; initial_offset
    jsr _ff6vwf_menu_draw_vwf_tiles

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
    jsr _ff6vwf_menu_force_nmi

@draw_tiles:
    ; Draw tiles.
    ldx first_tile_id
    ldy #FF6_SHORT_ENEMY_NAME_LENGTH
    stz outgoing_args+0                 ; blanks_count
    stz outgoing_args+1                 ; initial_offset
    jsr _ff6vwf_menu_draw_vwf_tiles

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
    jsr _ff6vwf_menu_force_nmi

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

.proc _ff6vwf_menu_draw_item_menu
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__

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

.proc _ff6vwf_menu_draw_skills_menu
begin_locals
    decl_local outgoing_args, 12

espers_palette = $7e0079

    enter __FRAME_SIZE__

    ldx #.loword(ff6vwf_skills_menu_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_skills_menu_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE
    jsr ff6vwf_menu_render_static_strings

    ; Stuff the original function did:
    lda f:espers_palette        ; Espers palette
    sta f:ff6_menu_bg_attrs

    leave __FRAME_SIZE__
    rtl
.endproc

.proc _ff6vwf_menu_draw_equip_menu
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__

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
    decl_local outgoing_args, 12

    enter __FRAME_SIZE__

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
    jsr _ff6vwf_menu_force_nmi

    ; Draw tiles.
    ldx first_tile                      ; first_tile_id
    ldy #FF6_SHORT_COMMAND_NAME_LENGTH  ; tile count
    stz outgoing_args+0                 ; blanks_count
    stz outgoing_args+1                 ; initial_offset
    jsr _ff6vwf_menu_draw_vwf_tiles

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

; nearproc void ff6vwf_menu_draw_item_name_bg3(uint8 item_id, uint8 text_line_slot)
.proc ff6vwf_menu_draw_item_name_bg3
begin_locals
    decl_local outgoing_args, 6
    decl_local item_id, 1
    decl_local string_ptr, 2
    decl_local text_line_slot, 1
    decl_local first_tile_id, 1

    enter __FRAME_SIZE__

    ; Initialize locals.
    txa
    sta item_id
    tya
    sta text_line_slot

    ; Draw item icon.
    ldx item_id
    jsr _ff6vwf_menu_draw_item_icon

    ; Compute string pointer.
    ldx item_id
    jsr ff6vwf_get_long_item_name
    stx string_ptr

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple   ; first_tile_id
    txa
    sta first_tile_id

    ; Render string.
    lda #10
    sta outgoing_args+0     ; max_tile_count
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+1     ; flags
    ldy string_ptr
    sty outgoing_args+2
    lda #^ff6vwf_long_item_names
    sta outgoing_args+4
    ldy #VWF_MENU_TILE_BG3_BASE_ADDR
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsr _ff6vwf_menu_force_nmi

    ; Draw tiles.
    ldx first_tile_id
    ldy #10                             ; tile count
    lda #3
    sta outgoing_args+0                 ; blanks_count
    lda #1
    sta outgoing_args+1                 ; initial_offset
    jsr _ff6vwf_menu_draw_vwf_tiles

    leave __FRAME_SIZE__
    rts
.endproc

.export ff6vwf_menu_draw_item_name_bg3

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

.proc _ff6twue_menu_blitz_next_row
    tya
    lsr
    bcc :+
    lsr
    bcc :+
    dec .loword(ff6_menu_list_slot)
    dec .loword(ff6_menu_list_slot)
:   tdc 
    dey
    rtl
.endproc

.proc _ff6twue_menu_blitz_build_tilemap
blitz_id = $e0
src_ptr = $e7
ff6_blitz_inputs = $c35c1c
ff6_blitz_input_tiles = $c47a40
ff6_short_blitz_names = $e6f831

    asl
    sta z:blitz_id      ; blitz_id *= 2
    lda <ff6_menu_bg1_write_row+0
    jsr _ff6twue_menu_blitz_55e4
    ldy #.loword(ff6_menu_string_buffer)
    sty WMADDL
    ldy #10
    lda z:blitz_id
    bcs draw_input

; $c35698:
@draw_blitz_name:
    lsr
    tax
    jsl _ff6vwf_menu_draw_blitz
    bra out

ff6twue_menu_move_blitz_tilemap:
    ldy <ff6_menu_null+0
    a16
    lda [<ff6_menu_src_ptr]
    sta <ff6_menu_dest_ptr
    inc <ff6_menu_src_ptr
    inc <ff6_menu_src_ptr
    a8
    lda #$7E
    sta <(ff6_menu_dest_ptr + 2)
@move_blitz_tilemap_loop:
    a16
    lda [<ff6_menu_src_ptr],Y
    beq move_blitz_tilemap_out
    sta [<ff6_menu_dest_ptr],Y
    a8
    iny 
    iny 
    bra @move_blitz_tilemap_loop
move_blitz_tilemap_out:
    a8
    rts 

draw_input:
    asl             
    sta z:blitz_id      ; blitz_id * 4
    asl
    adc z:blitz_id      ; blitz_id * 12
    ldx #(ff6_blitz_inputs >> 8)        ; this stomped on some important code!
    stx src_ptr+1
    tax 
@copy_blitz_input_char:
    lda f:ff6_blitz_input_tiles,x    ; load Blitz input
    asl
    adc #<ff6_blitz_inputs      ; tile attributes for Blitz inputs
    sta src_ptr
    lda [src_ptr]
    sta WMDATA
    inc src_ptr
    lda [src_ptr]
    sta WMDATA
    inx 
    dey 
    bne @copy_blitz_input_char
    stz WMDATA
    stz WMDATA
out:
    rtl
.endproc

.proc _ff6twue_menu_blitz_55e4
    dec
    lsr
    eor z:ff6_menu_vertical_page_offset
    lsr
    rts 
.endproc

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

.segment "PTEXTMENUITEMMENUPOSITIONEDTEXT"      ; $c38d16

.word $790d
    def_static_text_tiles_z 0*10, .strlen("Item"), -1
.word $791d
    def_static_text_tiles_z 1*10, .strlen("USE"), -1
.word $7927
    def_static_text_tiles_z 2*10, .strlen("ARRANGE"), -1
.word $7939
    def_static_text_tiles_z 3*10, .strlen("RARE"), -1

.segment "PTEXTMENUSKILLSMENUPOSITIONEDTEXT"    ; $c35c48

.word $790d
    def_static_text_tiles_z 0*10, .strlen("Espers"), -1
.word $798d
    def_static_text_tiles_z 1*10, .strlen("Magic"), -1
.word $7a8d
    def_static_text_tiles_z 2*10, .strlen("SwdTech"), -1
.word $7b0d
    def_static_text_tiles_z 3*10, .strlen("Blitz"), -1
.word $7b8d
    def_static_text_tiles_z 4*10, .strlen("Lore"), -1
.word $7c0d
    def_static_text_tiles_z 5*10, .strlen("Rage"), -1
.word $7c8d
    def_static_text_tiles_z 6*10, .strlen("Dance"), -1

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
    def_static_text_tiles_z 20, .strlen("Relic"), -1
.word $7b8d
    def_static_text_tiles_z 20, .strlen("Relic"), -1

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
    def_static_text_tiles_z 0, .strlen("EQUIP"), -1
.word $791f
    def_static_text_tiles_z 10, .strlen("REMOVE"), -1

.segment "PTEXTMENUEQUIPMENUPOSITIONEDTEXTB"    ; $c3a371
_equip_menu_positioned_text_b:
    .word $7ca9                         ; "Vigor"
        def_static_text_tiles_z EQUIP_MENU_FIRST_STATS_TILE+STATS_TILE_INDEX_STRENGTH, STATS_TILE_COUNT_STRENGTH, -1
    .word $7da9
        def_static_text_tiles EQUIP_MENU_FIRST_STATS_TILE+STATS_TILE_INDEX_STAMINA, STATS_TILE_COUNT_STAMINA, -1
        .byte $ff, $ff, 0               ; "Stamina"
    .word $7e29
        def_static_text_tiles EQUIP_MENU_FIRST_STATS_TILE+STATS_TILE_INDEX_MAGIC, STATS_TILE_COUNT_MAGIC, -1
        .byte $ff, $ff, $ff, $ff, 0     ; "Mag.Pwr"
    .word $7fa9
        def_static_text_tiles EQUIP_MENU_FIRST_STATS_TILE+STATS_TILE_INDEX_EVASION, STATS_TILE_COUNT_EVASION, -1
        .byte $ff, $ff, 0               ; "Evade %"
    .word $80a9                         ; "MBlock%"
        def_static_text_tiles_z EQUIP_MENU_FIRST_STATS_TILE+STATS_TILE_INDEX_MAGIC_EVASION, STATS_TILE_COUNT_MAGIC_EVASION, -1
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
        def_static_text_tiles EQUIP_MENU_FIRST_STATS_TILE+STATS_TILE_INDEX_SPEED, STATS_TILE_COUNT_SPEED, -1
        .byte $ff, 0                        ; "Speed"
    .word $7ea9
        def_static_text_tiles EQUIP_MENU_FIRST_STATS_TILE+STATS_TILE_INDEX_ATTACK, STATS_TILE_COUNT_ATTACK, -1
        .byte $ff, $ff, $ff, 0              ; "Bat.Pwr"
    .word $7f29
        def_static_text_tiles EQUIP_MENU_FIRST_STATS_TILE+STATS_TILE_INDEX_DEFENSE, STATS_TILE_COUNT_DEFENSE, -1
        .byte $ff, $ff, 0                   ; "Defense"
    .word $8029                             ; "Mag.Def"
        def_static_text_tiles_z EQUIP_MENU_FIRST_STATS_TILE+STATS_TILE_INDEX_MAGIC_DEFENSE, STATS_TILE_COUNT_MAGIC_DEFENSE, -1

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
    def_static_text_tiles_z STATS_TILE_INDEX_STRENGTH, STATS_TILE_COUNT_STRENGTH, -1
.word bg1_position 2,  22
    def_static_text_tiles STATS_TILE_INDEX_STAMINA, STATS_TILE_COUNT_STAMINA, -1
    .byte $ff, $ff, 0               ; "Stamina"
.word bg1_position 16, 22
    def_static_text_tiles STATS_TILE_INDEX_MAGIC, STATS_TILE_COUNT_MAGIC, -1
    .byte $ff, $ff, $ff, $ff, 0     ; "Mag.Pwr"
.word bg1_position 2,  24
    def_static_text_tiles STATS_TILE_INDEX_EVASION, STATS_TILE_COUNT_EVASION, -1
    .byte $ff, $ff, 0               ; "Evade %"
.word bg1_position 2,  25           ; "MBlock%"
    def_static_text_tiles_z STATS_TILE_INDEX_MAGIC_EVASION, STATS_TILE_COUNT_MAGIC_EVASION, -1
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
    def_static_text_tiles STATS_TILE_INDEX_SPEED, STATS_TILE_COUNT_SPEED, -1
    .byte $ff, 0                        ; "Speed"
.word bg1_position 2,  23
    def_static_text_tiles STATS_TILE_INDEX_ATTACK, STATS_TILE_COUNT_ATTACK, -1
    .byte $ff, $ff, $ff, 0              ; "Bat.Pwr"
.word bg1_position 16, 23
    def_static_text_tiles STATS_TILE_INDEX_DEFENSE, STATS_TILE_COUNT_DEFENSE, -1
    .byte $ff, $ff, 0                   ; "Defense"
.word bg1_position 16, 24
    def_static_text_tiles STATS_TILE_INDEX_MAGIC_DEFENSE, STATS_TILE_COUNT_MAGIC_DEFENSE, -1
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

ff6vwf_string_equipment:
    ff6_def_charset_string_z "Equipment "
ff6vwf_string_equipment_end:

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

ff6vwf_item_menu_static_text_descriptor:
    .byte ITEM_MENU_STRING_COUNT                ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU        ; DMA flags
    .word VWF_MENU_TILE_BG3_BASE_ADDR           ; base address
    .faraddr ff6vwf_item_menu_labels            ; strings
    .faraddr ff6vwf_item_menu_tile_counts       ; tile counts
    .faraddr ff6vwf_item_menu_start_tiles       ; start tiles

ff6vwf_item_menu_labels: ff6vwf_def_pointer_array ff6vwf_item_menu_label, ITEM_MENU_STRING_COUNT
ff6vwf_item_menu_tile_counts: .byte 10, 10, 10, 10
ff6vwf_item_menu_start_tiles: .byte  0, 10, 20, 30

ff6vwf_item_menu_label_0:  .asciiz "Items"
ff6vwf_item_menu_label_1:  .asciiz "Use"
ff6vwf_item_menu_label_2:  .asciiz "Sort"
ff6vwf_item_menu_label_3:  .asciiz "Key"

ff6vwf_skills_menu_static_text_descriptor:
    .byte SKILLS_MENU_STRING_COUNT              ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU        ; DMA flags
    .word VWF_MENU_TILE_BG3_BASE_ADDR           ; base address
    .faraddr ff6vwf_skills_menu_labels          ; strings
    .faraddr ff6vwf_skills_menu_tile_counts     ; tile counts
    .faraddr ff6vwf_skills_menu_start_tiles     ; start tiles

ff6vwf_skills_menu_labels:
    ff6vwf_def_pointer_array ff6vwf_skills_menu_label, SKILLS_MENU_STRING_COUNT

ff6vwf_skills_menu_tile_counts: .byte 10, 10, 10, 10, 10, 10, 10
ff6vwf_skills_menu_start_tiles: .byte  0, 10, 20, 30, 40, 50, 60

ff6vwf_skills_menu_label_0:  .asciiz "Espers"
ff6vwf_skills_menu_label_1:  .asciiz "Magic"
ff6vwf_skills_menu_label_2:  .asciiz "Bushido"
ff6vwf_skills_menu_label_3:  .asciiz "Blitz"
ff6vwf_skills_menu_label_4:  .asciiz "Lore"
ff6vwf_skills_menu_label_5:  .asciiz "Rage"
ff6vwf_skills_menu_label_6:  .asciiz "Dance"

; Esper bonuses

ff6vwf_esper_bonus_descriptions: ff6vwf_def_pointer_array ff6vwf_esper_bonus_description, 17

ff6vwf_esper_bonus_description_0:  .asciiz "Max HP +10%"
ff6vwf_esper_bonus_description_1:  .asciiz "Max HP +30%"
ff6vwf_esper_bonus_description_2:  .asciiz "Max HP +50%"
ff6vwf_esper_bonus_description_3:  .asciiz "Max MP +10%"
ff6vwf_esper_bonus_description_4:  .asciiz "Max MP +30%"
ff6vwf_esper_bonus_description_5:  .asciiz "Max MP +50%"
ff6vwf_esper_bonus_description_6:  .asciiz "Max HP +100%"
ff6vwf_esper_bonus_description_7:  .asciiz "Level +30%"
ff6vwf_esper_bonus_description_8:  .asciiz "Level +50%"
ff6vwf_esper_bonus_description_9:  .asciiz "Strength +1"
ff6vwf_esper_bonus_description_10: .asciiz "Strength +2"
ff6vwf_esper_bonus_description_11: .asciiz "Speed +1"
ff6vwf_esper_bonus_description_12: .asciiz "Speed +2"
ff6vwf_esper_bonus_description_13: .asciiz "Stamina +1"
ff6vwf_esper_bonus_description_14: .asciiz "Stamina +2"
ff6vwf_esper_bonus_description_15: .asciiz "Magic +1"
ff6vwf_esper_bonus_description_16: .asciiz "Magic +2"

; Equip menu labels

ff6vwf_equip_menu_static_text_descriptor:
    .byte EQUIP_MENU_STRING_COUNT               ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU        ; DMA flags
    .word VWF_MENU_TILE_BG3_BASE_ADDR           ; base address
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

ff6vwf_relic_menu_static_text_descriptor:
    .byte RELIC_MENU_STRING_COUNT           ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU    ; DMA flags
    .word VWF_MENU_TILE_BG3_BASE_ADDR       ; base address
    .faraddr ff6vwf_relic_menu_labels       ; strings
    .faraddr ff6vwf_relic_menu_tile_counts  ; tile counts
    .faraddr ff6vwf_relic_menu_start_tiles  ; start tiles

ff6vwf_relic_menu_labels:
    ff6vwf_def_pointer_array ff6vwf_relic_menu_label, RELIC_MENU_STRING_COUNT

ff6vwf_relic_menu_tile_counts: .byte 10, 10, 10
ff6vwf_relic_menu_start_tiles: .byte  0, 10, 20

ff6vwf_relic_menu_label_0:  .asciiz "Equip"         ; 10 tiles, 8-18
ff6vwf_relic_menu_label_1:  .asciiz "Remove"        ; 10 tiles, 18-28
ff6vwf_relic_menu_label_2:  .asciiz "Relic"         ; 10 tiles, 28-38

ff6vwf_stats_static_text_descriptor_bg1:
    .byte STATS_STRING_COUNT                                                ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP   ; DMA flags
    .word VWF_MENU_TILE_BG1_BASE_ADDR                                       ; base address
    .faraddr ff6vwf_stats_labels                                            ; strings
    .faraddr ff6vwf_stats_tile_counts                                       ; tile counts
    .faraddr ff6vwf_stats_start_tiles                                       ; start tiles

ff6vwf_stats_static_text_descriptor_bg3:
    .byte STATS_STRING_COUNT                ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU    ; DMA flags
    .word VWF_MENU_TILE_BG3_BASE_ADDR       ; base address
    .faraddr ff6vwf_stats_labels            ; strings
    .faraddr ff6vwf_stats_tile_counts       ; tile counts
    .faraddr ff6vwf_stats_start_tiles       ; start tiles

ff6vwf_stats_labels: ff6vwf_def_pointer_array ff6vwf_stats_label, STATS_STRING_COUNT

ff6vwf_stats_tile_counts: .byte 5, 5,  3,  5,  7,  4,  4,  5,  6
ff6vwf_stats_start_tiles: .byte 0, 5, 10, 13, 18, 25, 29, 33, 38

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
