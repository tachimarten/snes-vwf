; snes-vwf/ff6/misc-menus.s
;
; Final Fantasy 6 variable-width font patches specific to menus not accessible from the main menu

.p816
.i16
.a8
.feature c_comments

.include "ff6.inc"
.include "../snes.inc"

.import std_mul8:                               near

.import ff6vwf_calculate_first_tile_id_simple:  near
.import ff6vwf_get_long_item_name:              near
.import ff6vwf_long_enemy_names:                far
.import ff6vwf_long_item_names:                 far
.import ff6vwf_menu_draw_item_icon:             near
.import ff6vwf_menu_draw_pc_name:               near
.import ff6vwf_menu_draw_vwf_tiles:             near
.import ff6vwf_menu_force_nmi_trampoline:       far
.import ff6vwf_menu_render_static_strings:      near
.import ff6vwf_render_string:                   near

; Constants

COLOSSEUM_STRING_COUNT      = 3
PC_NAME_STRING_COUNT        = 1
LINEUP_STATIC_STRING_COUNT  = 2
KEFKA_LINEUP_STRING_COUNT   = 3

LINEUP_MESSAGE_TILE_COUNT   = 15
LINEUP_FIRST_MESSAGE_TILE   = 5

; FF6 globals

ff6_event_data      = $7e0201

; Patches to Final Fantasy 6 functions

; Final Fantasy 6 menu patches

.segment "PTEXTMENUBUILDCOLOSSEUMITEMS"     ; $c3ad27
    jsl _ff6vwf_menu_build_colosseum_items  ; 4 bytes
    nop

.segment "PTEXTMENUDRAWCOLOSSEUMITEM"
    jsl _ff6vwf_menu_draw_colosseum_item    ; 4 bytes
    jmp .loword(ff6_menu_draw_string)       ; Draw item name.

.segment "PTEXTMENUDRAWCOLOSSEUMENEMY"
    jsl _ff6vwf_menu_draw_colosseum_enemy   ; 4 bytes
    jmp .loword(ff6_menu_draw_string)       ; Draw enemy name.

.segment "PTEXTMENUDRAWPCNAMEMENU"      ; $c36746
    jsl _ff6vwf_menu_draw_pc_name_menu
    nopx 2

.segment "PTEXTMENUDRAWLINEUPMENU"                      ; $c37553
    jsl _ff6vwf_menu_draw_lineup_menu
    nopx 2

.segment "PTEXTMENUDRAWLINEUPFORMGROUPSMESSAGE"         ; $c37566
    jsl _ff6vwf_menu_draw_lineup_form_groups_message
    ldy #$7a95                          ; Text pointer
    jmp ff6_menu_draw_banner_message    ; Draw message

.segment "PTEXTMENUDRAWLINEUPNOTENOUGHGROUPSMESSAGE"    ; $c372db
    jsl _ff6vwf_menu_draw_lineup_not_enough_groups_message
    ldy #$7ab7                          ; Text pointer
    jsr ff6_menu_draw_banner_message    ; Draw message
    nopx 2

.segment "PTEXTMENUDRAWLINEUPEMPTYGROUPSMESSAGE"        ; $c372e9
    jsl _ff6vwf_menu_draw_lineup_empty_groups_message
    nopx 2

.segment "PTEXTMENUDRAWKEFKALINEUP"             ; $c3ab2d
    jsl _ff6vwf_menu_draw_kefka_lineup

.segment "PTEXTMENUDRAWPCNAMEFORKEFKALINEUP"    ; $c3abf0
    jsl _ff6vwf_menu_draw_pc_name_for_kefka_lineup
    jmp ff6_menu_draw_string

; Our own functions, in a separate bank
.segment "TEXT"

; Menu functions

; farproc void _ff6vwf_menu_build_colosseum_items()
.proc _ff6vwf_menu_build_colosseum_items
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__

    ldx #.loword(ff6vwf_colosseum_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_colosseum_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE      ; tile_offset
    jsr ff6vwf_menu_render_static_strings

    ; Stuff the original function did
    leave __FRAME_SIZE__
    lda #1
    sta f:BG1SC
    rtl
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
    add #60
    sta first_tile_id

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; flags
    ldy string_ptr
    sty outgoing_args+1     ; string ptr
    lda #^ff6vwf_long_item_names
    sta outgoing_args+3     ; string ptr, bank byte
    ldy #10                 ; max_tile_count
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

FIRST_TILE_ID = 2 * 10 + FF6VWF_FIRST_TILE + 50

    enter __FRAME_SIZE__

    ; Compute string pointer.
    lda f:ff6_menu_colosseum_opponent
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_enemy_names,x
    sta string_ptr
    a8

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; flags, 4bpp
    ldy string_ptr
    sty outgoing_args+1     ; string ptr
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+3     ; string ptr bank
    ldy #10                 ; max_tile_count
    ldx #FIRST_TILE_ID      ; first_tile_id
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

.proc _ff6vwf_menu_draw_pc_name_menu
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__

    ldx #.loword(ff6vwf_pc_name_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_pc_name_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE  ; first_tile_id
    jsr ff6vwf_menu_render_static_strings

    ; Stuff the original function did:
    leave __FRAME_SIZE__
    ply
    pla
    phy                                 ; Remove bank byte.
    ldy #$68e3                          ; Text pointer
    jml ff6_menu_draw_banner_message    ; Draw "Please..."
.endproc

.proc _ff6vwf_menu_draw_lineup_menu
begin_locals
    decl_local outgoing_args, 4

    enter __FRAME_SIZE__

    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    sta outgoing_args+0             ; flags
    ldx #.loword(ff6vwf_lineup_text_title)
    stx outgoing_args+1             ; string_ptr
    lda #^ff6vwf_lineup_text_title
    sta outgoing_args+3             ; string_ptr, bank byte
    ldy #LINEUP_MESSAGE_TILE_COUNT  ; max_tile_count
    ldx #FF6VWF_FIRST_TILE          ; first_tile_id
    jsr ff6vwf_render_string

    ; Stuff the original function did:
    leave __FRAME_SIZE__
    ply
    pla
    phy                                 ; Remove bank byte.
    ldy #$7aae                          ; Text pointer
    jml ff6_menu_draw_banner_message    ; Draw "Please..."
.endproc

.proc _ff6vwf_menu_draw_lineup_form_groups_message
begin_locals
    decl_local outgoing_args, 4

    enter __FRAME_SIZE__

    ; Get message.
    lda f:ff6_event_data
    a16
    and #$0007
    dec
    asl
    tax
    lda f:ff6vwf_lineup_text_main,x
    sta outgoing_args+1     ; string_ptr
    a8

    ; Upload title.
    ; TODO(tachiweasel): Different messages for different group counts.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    sta outgoing_args+0             ; flags
    lda #^ff6vwf_lineup_text_main_1_group
    sta outgoing_args+3             ; string_ptr, bank byte
    ldy #LINEUP_MESSAGE_TILE_COUNT  ; max_tile_count
    ldx #FF6VWF_FIRST_TILE + LINEUP_FIRST_MESSAGE_TILE
    jsr ff6vwf_render_string

    leave __FRAME_SIZE__
    rtl
.endproc

.proc _ff6vwf_menu_draw_lineup_not_enough_groups_message
begin_locals
    decl_local outgoing_args, 5

    enter __FRAME_SIZE__

    ; Get message.
    lda f:ff6_event_data
    a16
    and #$0007
    dec
    asl
    tax
    lda f:ff6vwf_lineup_text_not_enough_groups,x
    sta outgoing_args+1             ; string_ptr
    a8

    ; Upload title.
    ; TODO(tachiweasel): Different messages for different group counts.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    sta outgoing_args+0             ; flags
    lda #^ff6vwf_lineup_text_not_enough_groups_1_group
    sta outgoing_args+3             ; string ptr, bank byte
    ldy #LINEUP_MESSAGE_TILE_COUNT  ; max_tile_count
    ldx #FF6VWF_FIRST_TILE + LINEUP_FIRST_MESSAGE_TILE
    jsr ff6vwf_render_string

    leave __FRAME_SIZE__

    ; Stuff the original function did:
    ply
    pla
    phy                                 ; Remove bank byte
    ldy #$7ab7                          ; Text pointer
    jml ff6_menu_draw_banner_message    ; Draw message
.endproc

.proc _ff6vwf_menu_draw_lineup_empty_groups_message
begin_locals
    decl_local outgoing_args, 5

    enter __FRAME_SIZE__

    ; Get message.
    lda f:ff6_event_data
    a16
    and #$0007
    dec
    asl
    tax
    lda f:ff6vwf_lineup_text_empty_groups,x
    sta outgoing_args+1             ; string_ptr
    a8

    ; Upload title.
    ; TODO(tachiweasel): Different messages for different group counts.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    sta outgoing_args+0             ; flags
    lda #^ff6vwf_lineup_text_empty_groups_1_group
    sta outgoing_args+3             ; string_ptr, bank byte
    ldy #LINEUP_MESSAGE_TILE_COUNT  ; max_tile_count
    ldx #FF6VWF_FIRST_TILE + LINEUP_FIRST_MESSAGE_TILE
    jsr ff6vwf_render_string

    ; Stuff the original function did:
    leave __FRAME_SIZE__
    ply
    pla
    phy                                 ; Remove bank byte
    ldy #$7ab7                          ; Text pointer
    jml ff6_menu_draw_banner_message    ; Draw message
.endproc

.proc _ff6vwf_menu_draw_kefka_lineup
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__

    ldx #.loword(ff6vwf_kefka_lineup_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_kefka_lineup_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE      ; first_tile_id
    jsr ff6vwf_menu_render_static_strings

    lda #$20                    ; Palette 0
    sta f:ff6_menu_bg_attrs     ; Color: User's

    ; Stuff the original function did:
    leave __FRAME_SIZE__
    rtl
.endproc

; farproc void ff6vwf_menu_draw_pc_name_for_kefka_lineup(uint8 unused, tiledata near *tilemap_addr)
.proc _ff6vwf_menu_draw_pc_name_for_kefka_lineup
begin_locals
    decl_local party_member_id, 1

ff6_menu_party_member_infos = $c36969

    tax                     ; Actor ID
    enter __FRAME_SIZE__

    ; Save party member ID.
    txa
    sta party_member_id

    ; Put party member info in X.
    a16
    and #$00ff
    asl
    tax
    lda f:ff6_menu_party_member_infos,x
    sta f:ff6_menu_actor_address
    a8

    ; Calculate first tile ID and put in X.
    ldx party_member_id
    ldy #6
    jsr std_mul8
    txa
    add #FF6VWF_FIRST_TILE + 30
    tax

    ; Draw name.
    jsr ff6vwf_menu_draw_pc_name

    leave __FRAME_SIZE__
    rtl
.endproc

; ROM data patches

.segment "PTEXTMENUCOLOSSEUMPOSITIONEDTEXTA"    ; $c3ad9a

.word $790d
    def_static_text_tiles_z 0, .strlen("Colosseum"), -1
.word $7923
    def_static_text_tiles_z 10, .strlen("Select an Item"), -1

.segment "PTEXTMENUCOLOSSEUMPOSITIONEDTEXTB"    ; $c3b40f

.word $7d15
    def_static_text_tiles_z 30, .strlen("Select the challenger"), -1

.segment "PTEXTMENUNAMEPCPOSITIONEDTEXT"        ; $c368e3

.word $411b
    def_static_text_tiles_z 0, .strlen("Please enter a name."), -1

.segment "PTEXTMENULINEUPPOSITIONEDTEXT"        ; $c37a95

.word $391d
    def_static_text_tiles_z 5, .strlen("Form   group(s).      "), -1
.word $390d
    def_static_text_tiles_z 0, .strlen("Lineup"), 4
.word $391d
    def_static_text_tiles_z 5, .strlen("You need   group(s)!"), -1
.word $391d
    def_static_text_tiles_z 5, .strlen("No one there!       "), -1

.segment "PTEXTMENUKEFKALINEUPPOSITIONEDTEXT"   ; $c3ac8a

.word $4011
    def_static_text_tiles_z 0, .strlen("End"), -1
.word $3991
    def_static_text_tiles_z 5, .strlen("Reset"), -1
.word $391d
    def_static_text_tiles_z 10, .strlen("Determine order"), -1

; Constant data

.segment "DATA"

; Colosseum menu static text

ff6vwf_colosseum_static_text_descriptor:
    .byte COLOSSEUM_STRING_COUNT            ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU    ; DMA flags
    .faraddr ff6vwf_colosseum_labels        ; strings
    .faraddr ff6vwf_colosseum_tile_counts   ; tile counts
    .faraddr ff6vwf_colosseum_start_tiles   ; start tiles

ff6vwf_colosseum_labels: ff6vwf_def_pointer_array ff6vwf_colosseum_label, COLOSSEUM_STRING_COUNT

ff6vwf_colosseum_tile_counts: .byte 10, 20, 20
ff6vwf_colosseum_start_tiles: .byte 0,  10, 30

ff6vwf_colosseum_label_0: .asciiz "Colosseum"
ff6vwf_colosseum_label_1: .asciiz "Choose an item to wager."
ff6vwf_colosseum_label_2: .asciiz "Select the challenger."

; PC name menu static text

ff6vwf_pc_name_static_text_descriptor:
    .byte PC_NAME_STRING_COUNT                                              ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP   ; DMA flags
    .faraddr ff6vwf_pc_name_labels                                          ; strings
    .faraddr ff6vwf_pc_name_tile_counts                                     ; tile counts
    .faraddr ff6vwf_pc_name_start_tiles                                     ; start tiles

ff6vwf_pc_name_labels: ff6vwf_def_pointer_array ff6vwf_pc_name_label, PC_NAME_STRING_COUNT

ff6vwf_pc_name_tile_counts: .byte 15
ff6vwf_pc_name_start_tiles: .byte 0

ff6vwf_pc_name_label_0: .asciiz "Please enter a name."

; Lineup menu text

ff6vwf_lineup_text_title: .asciiz "Lineup"

ff6vwf_lineup_text_main:
    .addr ff6vwf_lineup_text_main_1_group
    .addr ff6vwf_lineup_text_main_2_groups
    .addr ff6vwf_lineup_text_main_3_groups

ff6vwf_lineup_text_main_1_group:  .asciiz "Please form a group."
ff6vwf_lineup_text_main_2_groups: .asciiz "Please form two groups."
ff6vwf_lineup_text_main_3_groups: .asciiz "Please form three groups."

ff6vwf_lineup_text_not_enough_groups:
    .addr ff6vwf_lineup_text_not_enough_groups_1_group
    .addr ff6vwf_lineup_text_not_enough_groups_2_groups
    .addr ff6vwf_lineup_text_not_enough_groups_3_groups

ff6vwf_lineup_text_not_enough_groups_1_group:  .asciiz "You need a group."
ff6vwf_lineup_text_not_enough_groups_2_groups: .asciiz "You need two groups."
ff6vwf_lineup_text_not_enough_groups_3_groups: .asciiz "You need three groups."

ff6vwf_lineup_text_empty_groups:
    .addr ff6vwf_lineup_text_empty_groups_1_group
    .addr ff6vwf_lineup_text_empty_groups_2_3_groups
    .addr ff6vwf_lineup_text_empty_groups_2_3_groups

ff6vwf_lineup_text_empty_groups_1_group:    .asciiz "That group is empty."
ff6vwf_lineup_text_empty_groups_2_3_groups: .asciiz "Those groups are empty."

; Kefka lineup text

ff6vwf_kefka_lineup_static_text_descriptor:
    .byte KEFKA_LINEUP_STRING_COUNT                                         ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU | FF6VWF_DMA_SCHEDULE_FLAGS_4BPP   ; DMA flags
    .faraddr ff6vwf_kefka_lineup_labels                                     ; strings
    .faraddr ff6vwf_kefka_lineup_tile_counts                                ; tile counts
    .faraddr ff6vwf_kefka_lineup_start_tiles                                ; start tiles

ff6vwf_kefka_lineup_labels:
    ff6vwf_def_pointer_array ff6vwf_kefka_lineup_label, KEFKA_LINEUP_STRING_COUNT

ff6vwf_kefka_lineup_tile_counts: .byte 5, 5, 15
ff6vwf_kefka_lineup_start_tiles: .byte 0, 5, 10

ff6vwf_kefka_lineup_label_0: .asciiz "OK"
ff6vwf_kefka_lineup_label_1: .asciiz "Reset"
ff6vwf_kefka_lineup_label_2: .asciiz "Line up your party members."
