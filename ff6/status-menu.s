; snes-vwf/ff6/status-menu.s
;
; Final Fantasy 6 variable-width font patches specific to the Status menu

.p816
.i16
.a8
.feature c_comments

.include "ff6.inc"
.include "../snes.inc"

.import ff6_menu_draw_pc_name:              far
.import ff6_menu_draw_string_trampoline:    near
.import ff6vwf_long_command_names:          far
.import ff6vwf_menu_draw_vwf_tiles:         near
.import ff6vwf_menu_force_nmi:              near
.import ff6vwf_menu_render_static_strings:  near
.import ff6vwf_render_string:               near
.import ff6vwf_stats_labels:                far
.import ff6vwf_stats_start_tiles:           far
.import ff6vwf_stats_tile_counts:           far

; FF6-specific macros

.define bg1_position(col, row)  .loword(ff6_menu_bg1_data) + row * $40 + col * 2

; Constants

STATUS_BG1_STRING_COUNT     = 2
STATUS_BG3_STRING_COUNT     = 1

STATUS_FIRST_LABEL_TILE     = 50

; Patches to Final Fantasy 6 functions

; Final Fantasy 6 menu patches

.segment "PTEXTMENUDRAWSTATUSLABELS"    ; $c35d5c
    jsl _ff6vwf_menu_draw_status_title
    ldx #$6437      ; Text ptrs loc
    ldy #$001e      ; Strings: 15
    jsr $69ba       ; Draw Vigor, etc.
    lda #$24        ; Palette 3
    sta $29         ; Color: Blue

.segment "PTEXTMENUDRAWSTATUSSTATS"     ; $c35fc2
ff6_menu_draw_attack_string     = $0486
ff6_menu_draw_8_digits          = $04a3
ff6_menu_draw_string_number     = $04c0
ff6_menu_itoa                   = $04e0
ff6_menu_make_attack_string     = $052e
ff6_menu_draw_long_number       = $0582
ff6_menu_draw_basic_stats       = $0c6c
ff6_menu_hide_ailment_icons     = $11b0
ff6_menu_draw_actor_class       = $34e5
ff6_menu_draw_esper             = $34e6
ff6_menu_get_needed_xp          = $60a0
ff6_menu_status_draw_commands   = $6102
ff6_menu_status_display         = $625b
ff6_menu_define_attack          = $9371 
ff6_menu_set_attack_stats_mode  = $99e8
ff6_load_actor_properties       = $c20006
ff6_current_experience          = $7e0011
ff6_display_status_ailments     = $7e0047
ff6_stats_magic                 = $7e11a0
ff6_stats_stamina               = $7e11a2
ff6_stats_speed                 = $7e11a4
ff6_stats_strength              = $7e11a6
ff6_stats_evasion               = $7e11a8
ff6_stats_magic_evasion         = $7e11aa
ff6_stats_defense               = $7e11ba
ff6_stats_magic_defense         = $7e11bb

    jsl ff6_load_actor_properties           ; Load properties
    ldy <ff6_menu_actor_address             ; Actor's address
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

    ldy #$398f                          ; Text position
    jsr .loword(ff6_menu_draw_pc_name)  ; Draw actor name
    ldy #$399d                          ; Text position
    jsr ff6_menu_draw_actor_class       ; Actor class...
    ldy #$39b1                          ; Text position
    jsr ff6_menu_draw_esper             ; Draw held esper
    jsr ff6_menu_status_draw_commands   ; Draw commands

    lda #$20                            ; Palette 0
    sta <ff6_menu_bg_attrs              ; Color: User's
    ldx #$6096                          ; Coords tbl ptr
    jsr ff6_menu_draw_basic_stats       ; Draw LV, HP, MP
    ldx <ff6_menu_actor_address         ; Actor's address

    lda .loword(ff6_current_experience)+0,x ; Experience LB
    sta $f1                                 ; Memorize it
    lda .loword(ff6_current_experience)+1,x ; Experience MB
    sta $f2                                 ; Memorize it
    lda .loword(ff6_current_experience)+2,x ; Experience HB
    sta $f3                                 ; Memorize it

    jsr ff6_menu_draw_long_number   ; Turn into text
    ldx #bg1_position 8, 16         ; Text position
    jsr ff6_menu_draw_8_digits      ; Draw 8 digits
    jsr ff6_menu_get_needed_xp      ; Get needed exp
    jsr ff6_menu_draw_long_number   ; Turn into text
    ldx #bg1_position 8, 19         ; Text position
    jsr ff6_menu_draw_8_digits      ; Draw 8 digits

    stz <ff6_display_status_ailments    ; Ailments: Off
    jsr ff6_menu_hide_ailment_icons     ; Hide ail. icons
    jsr ff6_menu_status_display         ; Display status
    jsl _ff6vwf_menu_draw_status_menu
    rts

.segment "PTEXTMENUDRAWSTATUSCOMMANDNAME"           ; $c35eeb
    jsl _ff6vwf_menu_draw_status_command_name
    jmp ff6_menu_draw_string

; Our own functions, in a separate bank
.segment "TEXT"

.proc _ff6vwf_menu_draw_status_menu
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Upload BG1 labels.
    ldx #.loword(ff6vwf_status_bg1_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_status_bg1_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE + STATUS_FIRST_LABEL_TILE
    jsr ff6vwf_menu_render_static_strings

    ; Upload BG3 labels.
    ldx #.loword(ff6vwf_status_bg3_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_status_bg3_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE
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

; farproc void _ff6vwf_menu_draw_status_title()
.proc _ff6vwf_menu_draw_status_title
.struct locals
    .org 1
    outgoing_args .byte .sizeof(args_ff6vwf_menu_draw_multiple_strings)
    offset        .word    ; uint16
.endstruct

    enter .sizeof(locals), STACK_LIMIT

    lda #$2c                    ; Color: Blue
    sta f:ff6_menu_bg_attrs

    a16
    lda #.loword(_ff6vwf_menu_status_tilemap_string)
    sta f:ff6_menu_src_ptr+0
    a8
    lda #^_ff6vwf_menu_status_tilemap_string
    sta f:ff6_menu_src_ptr+2
    jsl ff6_menu_draw_string_trampoline

    lda #$24
    sta f:ff6_menu_bg_attrs

    leave .sizeof(locals)
    rtl
.endproc

; farproc void _ff6vwf_menu_draw_status_command_name()
.proc _ff6vwf_menu_draw_status_command_name
begin_locals
    decl_local outgoing_args, 5
    decl_local dest_tilemap_position, 2     ; vram near *
    decl_local string_ptr, 2                ; const char near *
    decl_local first_tile, 1                ; uint8

command_name = $7e00e2

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Store dest tilemap position
    a16
    lda f:ff6_menu_positioned_text_ptr
    sta dest_tilemap_position
    a8

    ; Compute first tile ID.
    ldx #0
:   a16
    lda f:_ff6vwf_status_command_positions,x
    cmp dest_tilemap_position
    a8
    beq @found_position
    addix 3
    cpx #_ff6vwf_status_command_positions_end - _ff6vwf_status_command_positions
    bne :-
    stp                 ; Assert we found the command position!
@found_position:
    lda f:_ff6vwf_status_command_positions+2,x
    add #FF6VWF_FIRST_TILE
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
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0                 ; flags
    ldy string_ptr                      ; string ptr
    sty outgoing_args+1
    lda #^ff6vwf_long_command_names
    sta outgoing_args+3                 ; string ptr, bank byte
    ldx first_tile                      ; first_tile_id
    ldy #FF6_SHORT_COMMAND_NAME_LENGTH  ; max_tile_count
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsr ff6vwf_menu_force_nmi

    ; Draw tiles.
    ldx first_tile                      ; first_tile_id
    ldy #6                              ; tile count
    stz outgoing_args+0                 ; blanks_count
    stz outgoing_args+1                 ; initial_offset
    jsr ff6vwf_menu_draw_vwf_tiles

@out:
    leave __FRAME_SIZE__
    rtl
.endproc

_ff6vwf_status_command_positions:
.word $79ad     ; $c344b4 -- Cmd.Set menu, character 0, position 0
    .byte 0*6
.word $7a23     ; $c344b4 -- Cmd.Set menu, character 0, position 1
    .byte 1*6
.word $7a37     ; $c344b4 -- Cmd.Set menu, character 0, position 2
    .byte 2*6
.word $7aad     ; $c344b4 -- Cmd.Set menu, character 0, position 3
    .byte 3*6
.word $7b6d     ; $c344b4 -- Cmd.Set menu, character 1, position 0
    .byte 4*6
.word $7be3     ; $c344b4 -- Cmd.Set menu, character 1, position 1
    .byte 5*6
.word $7bf7     ; $c344b4 -- Cmd.Set menu, character 1, position 2
    .byte 6*6
.word $7c6d     ; $c344b4 -- Cmd.Set menu, character 1, position 3
    .byte 7*6
.word $7d2d     ; $c344b4 -- Cmd.Set menu, character 2, position 0
    .byte 8*6
.word $7da3     ; $c344b4 -- Cmd.Set menu, character 2, position 1
    .byte 9*6
.word $7db7     ; $c344b4 -- Cmd.Set menu, character 2, position 2
    .byte 10*6
.word $7e2d     ; $c344b4 -- Cmd.Set menu, character 2, position 3
    .byte 11*6
.word $7eed     ; $c344b4 -- Cmd.Set menu, character 3, position 0
    .byte 12*6
.word $7f63     ; $c344b4 -- Cmd.Set menu, character 3, position 1
    .byte 13*6
.word $7f77     ; $c344b4 -- Cmd.Set menu, character 3, position 2
    .byte 14*6
.word $7fed     ; $c344b4 -- Cmd.Set menu, character 3, position 3
    .byte 15*6
.word $7bf1     ; $c36102 -- Status menu, position 0
    .byte 0*6
.word $7c71     ; $c36102 -- Status menu, position 1
    .byte 1*6
.word $7cf1     ; $c36102 -- Status menu, position 2
    .byte 2*6
.word $7d71     ; $c36102 -- Status menu, position 3
    .byte 3*6
.repeat 24,i
.word $80c9 + $80*i
    .byte 32+i*6    ; $c35ead -- Gogo's commands menu
.endrepeat
_ff6vwf_status_command_positions_end:

; ROM data patches

.segment "PTEXTMENUSTATUSPOSITIONEDTEXT"   ; $c3646f
.word $0000
    .byte 0, 0, 0, 0, 0, 0, 0
.word $3a6b
    ff6_def_charset_string_z "/"
.word $3aab
    ff6_def_charset_string_z "/"
.word bg1_position 15, 24
    ff6_def_charset_string_z "%"
.word bg1_position 15, 25
    ff6_def_charset_string_z "%"
.word $3a1d
    ff6_def_charset_string_z "LV"
.word $3a5d
    ff6_def_charset_string_z "HP"
.word $3a9d
    ff6_def_charset_string_z "MP"
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

; Constant data

.segment "DATA"

; Static text

ff6vwf_stats_static_text_descriptor_bg1:
    .byte FF6VWF_STATS_STRING_COUNT                                         ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP   ; DMA flags
    .faraddr ff6vwf_stats_labels                                            ; strings
    .faraddr ff6vwf_stats_tile_counts                                       ; tile counts
    .faraddr ff6vwf_stats_start_tiles                                       ; start tiles

ff6vwf_status_bg1_static_text_descriptor:
    .byte STATUS_BG1_STRING_COUNT                                           ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP   ; DMA flags
    .faraddr ff6vwf_status_bg1_labels                                       ; strings
    .faraddr ff6vwf_status_bg1_tile_counts                                  ; tile counts
    .faraddr ff6vwf_status_bg1_start_tiles                                  ; start tiles

ff6vwf_status_bg1_labels: ff6vwf_def_pointer_array ff6vwf_status_bg1_label, STATUS_BG1_STRING_COUNT

ff6vwf_status_bg1_tile_counts: .byte 10, 10
ff6vwf_status_bg1_start_tiles: .byte  0, 10

ff6vwf_status_bg1_label_0:  .asciiz "Experience"
ff6vwf_status_bg1_label_1:  .asciiz "EXP to Next Level"

ff6vwf_status_bg3_static_text_descriptor:
    .byte STATUS_BG3_STRING_COUNT               ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU        ; DMA flags
    .faraddr ff6vwf_status_bg3_labels           ; strings
    .faraddr ff6vwf_status_bg3_tile_counts      ; tile counts
    .faraddr ff6vwf_status_bg3_start_tiles      ; start tiles

ff6vwf_status_bg3_labels: ff6vwf_def_pointer_array ff6vwf_status_bg3_label, STATUS_BG3_STRING_COUNT

ff6vwf_status_bg3_tile_counts: .byte 5
ff6vwf_status_bg3_start_tiles: .byte $e3

ff6vwf_status_bg3_label_0:  .asciiz "Status"

; Positioned text for the Status menu

_ff6vwf_menu_status_tilemap_string:
.word $78cd
    def_static_text_tiles_z $e3, .strlen("Status"), 4
