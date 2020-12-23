; snes-vwf/ff6/skills-menu.s
;
; Final Fantasy 6 variable-width font patches specific to the Skills menu and submenus

.p816
.i16
.a8
.feature c_comments

.include "ff6.inc"
.include "../snes.inc"

.import std_mod16_8: near
.import std_mul8:    near

.import ff6vwf_long_blitz_names: far
.import ff6vwf_long_dance_names: far
.import ff6vwf_long_enemy_names: far
.import ff6vwf_long_esper_names: far
.import ff6vwf_long_lore_names:  far
.import ff6vwf_long_spell_names: far

.import ff6vwf_calculate_first_tile_id_simple:     near
.import ff6vwf_menu_compute_map_ptr_trampoline:    far
.import ff6vwf_menu_draw_list_item:                near
.import ff6vwf_menu_draw_vwf_tiles:                near
.import ff6vwf_menu_force_nmi:                     near
.import ff6vwf_menu_force_nmi_trampoline:          far
.import ff6vwf_menu_move_blitz_tilemap_trampoline: far
.import ff6vwf_menu_render_static_strings:         near
.import ff6vwf_render_string:                      near

; Constants

SKILLS_MENU_STRING_COUNT = 7

SHORT_ESPER_BONUS_NAME_LENGTH = 10

FF6_MENU_ESPER_BONUS_AT_LEVEL_UP_TILE_LOCATION = $4713
FF6_MENU_ESPER_BONUS_AT_LEVEL_UP_MESSAGE_SIZE = 14
FF6_MENU_ESPER_BONUS_TILE_LOCATION = $4713

; FF6 globals

ff6_menu_null                       = $7e0000
ff6_menu_current_state              = $7e0026
ff6_menu_bg2_hscroll                = $7e0039
ff6_menu_bg3_hscroll                = $7e003d
ff6_menu_list_scroll                = $7e004a
ff6_menu_page_height                = $7e005a
ff6_menu_page_width                 = $7e005b
ff6_menu_max_page_scroll_pos        = $7e005c
ff6_menu_bg1_write_row              = $7e00e6
ff6_menu_src_ptr                    = $7e00e7
ff6_menu_dest_ptr                   = $7e00eb
ff6_menu_horizontal_movement_speed  = $7e34ca
ff6_menu_vertical_movement_speed    = $7e354a
ff6_menu_list                       = $7e9d89

; FF6 functions

ff6_menu_create_scrollbar   = $c3091f
ff6_menu_set_string_pos     = $c33519

; Patches

.segment "PTEXTMENUDRAWSKILLSMENU"      ; $c34cde
    jsl _ff6vwf_menu_draw_skills_menu

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

; This displays the held Esper in the Skills menu and the Lineup menu.
.segment "PTEXTMENUDRAWESPERNAMEINSTATUSPANEL"
    tax
    jsl _ff6vwf_menu_draw_esper_name_in_info_menu
    jmp .loword(ff6_menu_draw_string)

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

; Our own functions, in a separate bank
.segment "TEXT"

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
    jsr ff6vwf_menu_draw_list_item

    leave __FRAME_SIZE__
    a16
    lda #0      ; The original function did this...
    a8
    rtl
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
    jsr ff6vwf_menu_force_nmi

    ; Draw tiles.
    ldx #FIRST_TILE_ID
    ldy #FF6_SHORT_ESPER_NAME_LENGTH
    stz outgoing_args+0                 ; blanks_count
    stz outgoing_args+1                 ; initial_offset
    jsr ff6vwf_menu_draw_vwf_tiles

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
    jsr ff6vwf_menu_force_nmi

    ; Draw tiles.
    ldx #FIRST_TILE_ID
    ldy #SHORT_ESPER_BONUS_NAME_LENGTH
    stz outgoing_args+0                 ; blanks_count
    lda #FF6_MENU_ESPER_BONUS_AT_LEVEL_UP_MESSAGE_SIZE
    sta outgoing_args+1                 ; initial_offset
    jsr ff6vwf_menu_draw_vwf_tiles

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
    jsl ff6vwf_menu_force_nmi_trampoline

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
    jsr ff6vwf_menu_draw_vwf_tiles

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
    jsr ff6vwf_menu_draw_list_item

    leave __FRAME_SIZE__
    rtl
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
    jsl ff6vwf_menu_force_nmi_trampoline

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
    jsr ff6vwf_menu_draw_list_item

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
    jsl ff6vwf_menu_compute_map_ptr_trampoline
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
    jsl ff6vwf_menu_force_nmi_trampoline

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
    jsl ff6vwf_menu_move_blitz_tilemap_trampoline

    leave __FRAME_SIZE__
    rts
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

; Constant data

.segment "DATA"

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
