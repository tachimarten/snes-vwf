; snes-vwf/ff6/config-menu.s
;
; Final Fantasy 6 variable-width font patches specific to the Config menu and submenus

.p816
.i16
.a8
.feature c_comments

.include "ff6.inc"
.include "../snes.inc"

.import ff6vwf_menu_render_static_strings:  near

; Constants

CONFIG_BG1_STRING_COUNT     = 32
CONFIG_BG3_STRING_COUNT     = 4
COMMAND_SET_STRING_COUNT    = 1

; Patches to Final Fantasy 6 functions

; Final Fantasy 6 menu patches

.segment "PTEXTMENUDRAWCONFIGMENU"      ; $c33947
    jsl _ff6vwf_menu_draw_config_menu
    nop

.segment "PTEXTMENUDRAWCOMMANDSETMENU"      ; $c3442f
    jsl _ff6vwf_menu_draw_command_set_menu
    nopx 2

; Our own functions, in a separate bank
.segment "TEXT"

.proc _ff6vwf_menu_draw_config_menu
begin_locals
    decl_local outgoing_args, 3

ff6_update_config_menu_arrow = $c33980

    enter __FRAME_SIZE__, STACK_LIMIT

    ldx #.loword(ff6vwf_config_bg1_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_config_bg1_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE  ; first_tile_id
    jsr ff6vwf_menu_render_static_strings

    ldx #.loword(ff6vwf_config_bg3_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_config_bg3_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE  ; first_tile_id
    jsr ff6vwf_menu_render_static_strings

    leave __FRAME_SIZE__

    ; Stuff the original function did:
    lda #$01
    ldy #.loword(ff6_update_config_menu_arrow)
    rtl
.endproc

.proc _ff6vwf_menu_draw_command_set_menu
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__, STACK_LIMIT

    ldx #.loword(ff6vwf_command_set_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_command_set_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE  ; first_tile_id
    jsr ff6vwf_menu_render_static_strings

    ; Stuff the original function did:
    leave __FRAME_SIZE__
    ply
    pla
    phy                                         ; Remove bank byte.
    ldy #$4490
    jml $c30341
.endproc

; ROM data patches

.segment "PTEXTMENUCONFIGPOSITIONEDTEXTA"       ; $c34903

; Text pointers for Config page 1
.addr .loword(menu_config_controller_tiles)
.addr .loword(menu_config_cursor_tiles)
.addr .loword(menu_config_fast_tiles)
.addr .loword(menu_config_slow_tiles)

; Positioned text for Config page 1.
;
; We swap "Controller" and "Cursor" slots to give us enough room while keeping addresses the same.
menu_config_controller_tiles:
.word $3c8f
    def_static_text_tiles_z $40, .strlen("Controller"), 7
.word $39b5
    def_static_text_tiles_z $4b, .strlen("Wait"), 3
menu_config_fast_tiles:
.word $3a65
    def_static_text_tiles_z $4e, .strlen("Fast"), 3
menu_config_slow_tiles:
.word $3a75
    def_static_text_tiles_z $51, .strlen("Slow"), 3
.word $3b35
    def_static_text_tiles_z $57, .strlen("Short"), 3
.word $3ba5
    def_static_text_tiles_z $5a, .strlen("On"), 2
.word $3bb5
    def_static_text_tiles_z $5c, .strlen("Off"), 2
.word $3c25
    def_static_text_tiles_z $5e, .strlen("Stereo"), 4
.word $3c35
    def_static_text_tiles_z $62, .strlen("Mono"), 3
.word $3cb5
    def_static_text_tiles_z $68, .strlen("Memory"), -1
.word $3d25
    def_static_text_tiles_z $6e, .strlen("Optimum"), 6
.word $3db5
    def_static_text_tiles_z $c2, .strlen("Multiple"), 3
.word $3a25
    ff6_def_charset_string_z "1 2 3 4 5 6"
.word $3aa5
    ff6_def_charset_string_z "1 2 3 4 5 6"
menu_config_cursor_tiles:
.word $3d8f
    def_static_text_tiles_z $2d, .strlen("Cursor"), 4

.segment "PTEXTMENUCONFIGPOSITIONEDTEXTB"   ; $c34993

; Text pointers for Config page 1
.addr .loword(menu_config_bat_mode_tiles)   ; Bat.Mode
.addr .loword(menu_config_bat_speed_tiles)  ; Bat.Speed
.addr .loword(menu_config_msg_speed_tiles)  ; Msg.Speed
.addr .loword(menu_config_cmd_set_tiles)    ; Cmd.Set
.addr .loword(menu_config_gauge_tiles)      ; Gauge
.addr .loword(menu_config_sound_tiles)      ; Sound
.addr .loword(menu_config_reequip_tiles)    ; Reequip

.word $78f9
    def_static_text_tiles_z $00, .strlen("Config"), -1
menu_config_bat_mode_tiles:
.word $398f
    def_static_text_tiles_z $00, 5, -1      ; Bat.Mode
menu_config_bat_speed_tiles:
.word $3a0f
    def_static_text_tiles_z $05, 7, -1      ; Bat.Speed
menu_config_msg_speed_tiles:
.word $3a8f
    def_static_text_tiles_z $0c, 6, -1      ; Msg.Speed
menu_config_cmd_set_tiles:
.word $3b0f
    def_static_text_tiles_z $12, 10, -1      ; Cmd.Set
menu_config_gauge_tiles:
.word $3b8f
    def_static_text_tiles_z $1c, 6, -1      ; Gauge
menu_config_sound_tiles:
.word $3c0f
    def_static_text_tiles_z $22, 4, -1      ; Sound
menu_config_reequip_tiles:
.word $3d0f
    def_static_text_tiles_z $26, 7, -1      ; Reequip

.segment "PTEXTMENUCONFIGPOSITIONEDTEXTC"   ; $c34a34

menu_config_mag_order_tiles:
.word $418f
    def_static_text_tiles_z $31, .strlen("Mag.Order"), 7
menu_config_window_tiles:
.word $438f
    def_static_text_tiles_z $38, 8, -1
menu_config_color_tiles:
.word $440f
    .byte 0

.segment "PTEXTMENUCONFIGPOSITIONEDTEXTD"   ; $c34afb

.word $7b4d
    def_static_text_tiles_z 10, .strlen("Controller"), -1
.repeat 4, i
.word $7c21+$80*i
    def_static_text_tiles_z 20, .strlen("Cntlr1"), -1
.word $7c33+$80*i
    def_static_text_tiles_z 30, .strlen("Cntlr2"), -1
.endrepeat

.segment "PTEXTMENUCONFIGPOSITIONEDTEXTE"   ; $c34ad3

.byte $e8
    def_static_text_tiles $d0, .strlen("Healing  "), 4
.byte $e9
    def_static_text_tiles $d4, .strlen("Attack   "), 4
.byte $ea
    def_static_text_tiles $d8, .strlen("Effect   "), 4

.segment "PTEXTMENUCONFIGPOSITIONEDTEXTF"       ; $c34ab3

.word $4425
    def_static_text_tiles_z $dc, .strlen("Font"), 3
.word $4435
    def_static_text_tiles_z $e3, .strlen("Window"), 4

.segment "PTEXTMENUCONFIGPOSITIONEDTEXTG"   ; $c349f1

.word $39a5
    def_static_text_tiles_z $47, .strlen("Active"), 4
.word $3b25
    def_static_text_tiles_z $54, .strlen("Window"), 3
.word $3ca5
    def_static_text_tiles_z $65, .strlen("Reset"), 3
.word $3d35
    def_static_text_tiles_z $74, .strlen("Empty"), 4
.word $3da5
    def_static_text_tiles_z $c0, .strlen("Single"), 2

.addr .loword(menu_config_mag_order_tiles)  ; Mag.Order
.addr .loword(menu_config_window_tiles)     ; Window
.addr .loword(menu_config_color_tiles)      ; Color

.segment "PTEXTMENUCOMMANDSETPOSITIONEDTEXT"    ; $c34af1

command_set_positioned_text:
.word $78cf
    def_static_text_tiles_z $6d, .strlen("Arrange"), -1

; Constant data

.segment "DATA"

; Config menu static text

ff6vwf_config_bg1_static_text_descriptor:
    .byte CONFIG_BG1_STRING_COUNT                                           ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP   ; DMA flags
    .faraddr ff6vwf_config_bg1_labels                                       ; strings
    .faraddr ff6vwf_config_bg1_tile_counts                                  ; tile counts
    .faraddr ff6vwf_config_bg1_start_tiles                                  ; start tiles

ff6vwf_config_bg1_labels: ff6vwf_def_pointer_array ff6vwf_config_bg1_label, CONFIG_BG1_STRING_COUNT

ff6vwf_config_bg1_tile_counts:
    ;       0    1    2    3    4    5    6    7    8    9
    .byte   5,   7,   6,  10,   6,   4,   7,   4,   7,   8
    .byte   7,   4,   3,   3,   3,   3,   3,   2,   2,   4
    .byte   3,   3,   6,   6,   4,   2,   3,   4,   4,   4
    .byte   3,   4
ff6vwf_config_bg1_start_tiles:
    .byte   0,   5,  12,  18,  28,  34,  38,  45,  49,  56
    .byte  64,  71,  75,  78,  81,  84,  87,  90,  92,  94
    .byte  98, 101, 104, 110, 116, 192, 194, 208, 212, 216
    .byte 220, 227

ff6vwf_config_bg1_label_0:  .asciiz "ATB Mode"
ff6vwf_config_bg1_label_1:  .asciiz "Battle Speed"
ff6vwf_config_bg1_label_2:  .asciiz "Text Speed"
ff6vwf_config_bg1_label_3:  .asciiz "Battle Commands"
ff6vwf_config_bg1_label_4:  .asciiz "ATB Gauge"
ff6vwf_config_bg1_label_5:  .asciiz "Sound"
ff6vwf_config_bg1_label_6:  .asciiz "Relic Change"
ff6vwf_config_bg1_label_7:  .asciiz "Players"
ff6vwf_config_bg1_label_8:  .asciiz "Magic Order"
ff6vwf_config_bg1_label_9:  .asciiz "Window Colors"
ff6vwf_config_bg1_label_10: .asciiz "Menu Position"
ff6vwf_config_bg1_label_11: .asciiz "Active"
ff6vwf_config_bg1_label_12: .asciiz "Wait"
ff6vwf_config_bg1_label_13: .asciiz "Fast"
ff6vwf_config_bg1_label_14: .asciiz "Slow"
ff6vwf_config_bg1_label_15: .asciiz "Menu"
ff6vwf_config_bg1_label_16: .asciiz "D-Pad"
ff6vwf_config_bg1_label_17: .asciiz "On"
ff6vwf_config_bg1_label_18: .asciiz "Off"
ff6vwf_config_bg1_label_19: .asciiz "Stereo"
ff6vwf_config_bg1_label_20: .asciiz "Mono"
ff6vwf_config_bg1_label_21: .asciiz "Reset"
ff6vwf_config_bg1_label_22: .asciiz "Remember"
ff6vwf_config_bg1_label_23: .asciiz "Auto-Equip"
ff6vwf_config_bg1_label_24: .asciiz "Unequip"
ff6vwf_config_bg1_label_25: .asciiz "One"
ff6vwf_config_bg1_label_26: .asciiz "Two"
ff6vwf_config_bg1_label_27: .asciiz "Healing"
ff6vwf_config_bg1_label_28: .asciiz "Attack"
ff6vwf_config_bg1_label_29: .asciiz "Effect"
ff6vwf_config_bg1_label_30: .asciiz "Text"
ff6vwf_config_bg1_label_31: .asciiz "Window"

ff6vwf_config_bg3_static_text_descriptor:
    .byte CONFIG_BG3_STRING_COUNT               ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU        ; DMA flags
    .faraddr ff6vwf_config_bg3_labels           ; strings
    .faraddr ff6vwf_config_bg3_tile_counts      ; tile counts
    .faraddr ff6vwf_config_bg3_start_tiles      ; start tiles

ff6vwf_config_bg3_labels: ff6vwf_def_pointer_array ff6vwf_config_bg3_label, CONFIG_BG3_STRING_COUNT

ff6vwf_config_bg3_tile_counts: .byte  10,  10,  10,  10
ff6vwf_config_bg3_start_tiles: .byte   0,  10,  20,  30

ff6vwf_config_bg3_label_0: .asciiz "Config"
ff6vwf_config_bg3_label_1: .asciiz "Players"
ff6vwf_config_bg3_label_2: .asciiz "Player 1"
ff6vwf_config_bg3_label_3: .asciiz "Player 2"

; Command Set/Arrange menu static text

ff6vwf_command_set_static_text_descriptor:
    .byte COMMAND_SET_STRING_COUNT              ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU        ; DMA flags
    .faraddr ff6vwf_command_set_labels          ; strings
    .faraddr ff6vwf_command_set_tile_counts     ; tile counts
    .faraddr ff6vwf_command_set_start_tiles     ; start tiles

ff6vwf_command_set_labels:
    ff6vwf_def_pointer_array ff6vwf_command_set_label, COMMAND_SET_STRING_COUNT

ff6vwf_command_set_tile_counts: .byte   10
ff6vwf_command_set_start_tiles: .byte  $6d

ff6vwf_command_set_label_0: .asciiz "D-Pad Config"
