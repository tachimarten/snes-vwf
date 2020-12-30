; snes-vwf/ff6/saveload.s
;
; Final Fantasy 6 variable-width font patches specific to the Save and Load menus

.p816
.i16
.a8
.feature c_comments

.include "ff6.inc"
.include "../snes.inc"

.import ff6_menu_draw_string_trampoline
.import ff6vwf_menu_render_static_strings

; Constants

SAVE_STRING_COUNT           = 4

SAVE_TILEMAP_STRING_COUNT   = 5
LOAD_TILEMAP_STRING_COUNT   = 5

; Patches to Final Fantasy 6 functions

; Final Fantasy 6 menu patches

.segment "PTEXTMENUDRAWSAVEMENU"            ; $c315ff
    jsl _ff6vwf_menu_draw_save_menu
    nopx 2

.segment "PTEXTMENUDRAWLOADMENU"            ; $c31629
    jsl _ff6vwf_menu_draw_load_menu
    nopx 2

.segment "PTEXTMENUDRAWSAVECONFIRMATION"    ; $c331d7
    jsl _ff6vwf_menu_draw_save_confirmation
    rts

.segment "PTEXTMENUDRAWLOADCONFIRMATION"    ; $c331e5
    jsl _ff6vwf_menu_draw_load_confirmation
    rts

; Our own functions, in a separate bank
.segment "TEXT"

.proc _ff6vwf_menu_draw_save_menu
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__, STACK_LIMIT

    ldx #.loword(ff6vwf_save_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_save_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE  ; first_tile_id
    jsr ff6vwf_menu_render_static_strings

    ; Stuff the original function did:
    leave __FRAME_SIZE__
    ply
    pla
    phy                                 ; Remove bank byte.
    ldy #$1a78                          ; Text pointer
    jml ff6_menu_draw_banner_message    ; Draw "Save"
.endproc

.proc _ff6vwf_menu_draw_load_menu
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__, STACK_LIMIT

    ldx #.loword(ff6vwf_save_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_save_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE  ; first_tile_id
    jsr ff6vwf_menu_render_static_strings

    ; Stuff the original function did:
    leave __FRAME_SIZE__
    ply
    pla
    phy                                 ; Remove bank byte.
    ldy #$1a7f                          ; Text pointer
    jml ff6_menu_draw_banner_message    ; Draw "New Game"
.endproc

.proc _ff6vwf_menu_draw_save_confirmation
.struct locals
    .org 1
    outgoing_args .byte .sizeof(args_ff6vwf_menu_draw_multiple_strings)
    offset        .word    ; uint16
.endstruct

    enter .sizeof(locals), STACK_LIMIT

    lda #$20
    sta f:ff6_menu_bg_attrs

    lda #^_ff6vwf_menu_save_tilemap_strings
    sta locals::outgoing_args+args_ff6vwf_menu_draw_multiple_strings::tilemaps+2
    ldx #.loword(_ff6vwf_menu_save_tilemap_strings)
    stx locals::outgoing_args+args_ff6vwf_menu_draw_multiple_strings::tilemaps+0
    ldx #SAVE_TILEMAP_STRING_COUNT
    jsr _ff6vwf_menu_draw_multiple_strings

    leave .sizeof(locals)
    rtl
.endproc

.proc _ff6vwf_menu_draw_load_confirmation
.struct locals
    .org 1
    outgoing_args .byte .sizeof(args_ff6vwf_menu_draw_multiple_strings)
    offset        .word    ; uint16
.endstruct

    enter .sizeof(locals), STACK_LIMIT

    lda #$20
    sta f:ff6_menu_bg_attrs

    lda #^_ff6vwf_menu_load_tilemap_strings
    sta locals::outgoing_args+args_ff6vwf_menu_draw_multiple_strings::tilemaps+2
    ldx #.loword(_ff6vwf_menu_load_tilemap_strings)
    stx locals::outgoing_args+args_ff6vwf_menu_draw_multiple_strings::tilemaps+0
    ldx #LOAD_TILEMAP_STRING_COUNT
    jsr _ff6vwf_menu_draw_multiple_strings

    leave .sizeof(locals)
    rtl
.endproc

; nearproc void _ff6vwf_menu_draw_multiple_strings(uint8 string_count, void near *far *tilemaps)
.proc _ff6vwf_menu_draw_multiple_strings
.struct locals
    .org 1
    current_offset      .word       ; uint16
    last_string_offset  .word       ; uint16
.endstruct
args = .sizeof(locals) + .sizeof(nearcall_frame) + 1

    enter .sizeof(locals), STACK_LIMIT

    ; Initialize locals.
    a16
    stz locals::current_offset
    txa
    and #$00ff
    asl
    sta locals::last_string_offset  ; last_string_offset = current_offset * 2
    a8

    ; Save bank byte.
    lda args+args_ff6vwf_menu_draw_multiple_strings::tilemaps+2
    sta f:ff6_menu_src_ptr+2

    ; Draw strings.
    a16
    ldy locals::current_offset
:   lda [args+args_ff6vwf_menu_draw_multiple_strings::tilemaps],y
    sta f:ff6_menu_src_ptr
    a8
    jsl ff6_menu_draw_string_trampoline
    a16
    ldy locals::current_offset
    addiy 2
    sty locals::current_offset
    cpy locals::last_string_offset
    bne :-
    a8

    leave .sizeof(locals)
    rts
.endproc

; ROM data patches

.segment "PTEXTMENUSAVEPOSITIONEDTEXT"          ; $c31a24

.word $7a4f
    def_static_text_tiles_z 0*5, .strlen("Empty"), -1
.word $7c0f
    def_static_text_tiles_z 0*5, .strlen("Empty"), -1
.word $7dcf
    def_static_text_tiles_z 0*5, .strlen("Empty"), -1
.word $7acf
    def_static_text_tiles_z 1*5, .strlen("Time"), -1
.word $7c8f
    def_static_text_tiles_z 1*5, .strlen("Time"), -1
.word $7e4f
    def_static_text_tiles_z 1*5, .strlen("Time"), -1
.word $7b11
    ff6_def_charset_string_z ":"
.word $7cd1
    ff6_def_charset_string_z ":"
.word $7e91
    ff6_def_charset_string_z ":"
.word $7a7b
    ff6_def_charset_string_z "LV"
.word $7c3b
    ff6_def_charset_string_z "LV"
.word $7dfb
    ff6_def_charset_string_z "LV"
.word $7afb
    ff6_def_charset_string_z "/"
.word $7cbb
    ff6_def_charset_string_z "/"
.word $7e7b
    ff6_def_charset_string_z "/"
.word $7967
    def_static_text_tiles_z 2*5, .strlen("Save"), -1
.word $7963
    def_static_text_tiles_z 3*5, .strlen("New Game"), -1

; Constant data

.segment "DATA"

; Save menu static text

ff6vwf_save_static_text_descriptor:
    .byte SAVE_STRING_COUNT                 ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU    ; DMA flags
    .faraddr ff6vwf_save_labels             ; strings
    .faraddr ff6vwf_save_tile_counts        ; tile counts
    .faraddr ff6vwf_save_start_tiles        ; start tiles

ff6vwf_save_labels: ff6vwf_def_pointer_array ff6vwf_save_label, SAVE_STRING_COUNT

;                              0  1   2   3   4   5   6   7   8   9
ff6vwf_save_tile_counts: .byte 5, 5,  5, 10
ff6vwf_save_start_tiles: .byte 0, 5, 10, 15

ff6vwf_save_label_0: .asciiz "Empty"
ff6vwf_save_label_1: .asciiz "Time"
ff6vwf_save_label_2: .asciiz "Save"
ff6vwf_save_label_3: .asciiz "New Game"

; Positioned text for the Save menu

_ff6vwf_menu_save_tilemap_strings:
ff6vwf_def_pointer_array _ff6vwf_menu_save_tilemap_string, SAVE_TILEMAP_STRING_COUNT

_ff6vwf_menu_save_tilemap_string_0:
    .word $7abd
        def_static_text_tiles_z 40+35, 2, -1    ; "Yes"
_ff6vwf_menu_save_tilemap_string_1:
    .word $7b3d
        def_static_text_tiles_z 40+37, 2, -1    ; "No"
_ff6vwf_menu_save_tilemap_string_2:
    .word $7937
        def_static_text_tiles_z 40+39, 7, -1    ; "Overwriting"
_ff6vwf_menu_save_tilemap_string_3:
    .word $79b7
        def_static_text_tiles_z 40+46, 6, -1    ; "game. Are"
_ff6vwf_menu_save_tilemap_string_4:
    .word $7a37
        def_static_text_tiles_z 40+52, 6, -1    ; "you sure?"

; Positioned text for the Load menu

_ff6vwf_menu_load_tilemap_strings:
ff6vwf_def_pointer_array _ff6vwf_menu_load_tilemap_string, LOAD_TILEMAP_STRING_COUNT

_ff6vwf_menu_load_tilemap_string_0:
    .word $7abd
        def_static_text_tiles_z 40+35, 2, -1
_ff6vwf_menu_load_tilemap_string_1:
    .word $7b3d
        def_static_text_tiles_z 40+37, 2, -1
_ff6vwf_menu_load_tilemap_string_2:
    .word $7937
        def_static_text_tiles_z 40+58, 7, -1
_ff6vwf_menu_load_tilemap_string_3:
    .word $79b7
        def_static_text_tiles_z 40+65, 6, -1
_ff6vwf_menu_load_tilemap_string_4:
    .word $7a37
        def_static_text_tiles_z 40+71, 4, -1
