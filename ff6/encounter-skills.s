; snes-vwf/ff6/encounter-skills.s
;
; Final Fantasy 6 variable-width font patches specific to skills (Magic, Blitz, Lore, etc.) in
; encounters.

.p816
.i16
.a8
.feature c_comments

.include "ff6.inc"
.include "../snes.inc"

.import std_memcpy:     near
.import std_mod16_8:    near
.import std_mul8:       near

.import ff6vwf_calculate_first_tile_id_simple:      near
.import ff6vwf_encounter_current_skill_slot:        far
.import ff6vwf_encounter_draw_blank_tile_data:      near
.import ff6vwf_encounter_draw_enemy_name_string:    near
.import ff6vwf_encounter_draw_standard_string:      near
.import ff6vwf_encounter_draw_tile:                 near
.import ff6vwf_long_spell_names:                    far
.import ff6vwf_long_dance_names:                    far
.import ff6vwf_long_enemy_names:                    far
.import ff6vwf_long_esper_names:                    far
.import ff6vwf_long_lore_names:                     far
.import ff6vwf_long_magitek_names:                  far
.import ff6vwf_render_string:                       near
.import ff6vwf_transcode_string:                    near

; Constants

ESPER_LABEL_START_TILE = $5e

; FF6 globals

ff6_encounter_display_list_left  = $7e575a
ff6_encounter_display_list_right = $7e5760

; Patches to Final Fantasy 6 functions

; Final Fantasy 6 encounter patches

.segment "PTEXTENCOUNTERBUILDMENUITEMFORSPELL"
    jml _ff6vwf_encounter_build_menu_item_for_spell     ; 4 bytes

.segment "PTEXTENCOUNTERBUILDMENUITEMFORRAGE"
    jml _ff6vwf_encounter_build_menu_item_for_rage      ; 4 bytes

.segment "PTEXTENCOUNTERBUILDMENUITEMFORDANCE"
    jml _ff6vwf_encounter_build_menu_item_for_dance     ; 4 bytes

.segment "PTEXTENCOUNTERBUILDMENUITEMFORMAGITEK"
    jml _ff6vwf_encounter_build_menu_item_for_magitek   ; 4 bytes

.segment "PTEXTENCOUNTERBUILDMENUITEMFORLORE"   ; $c14d76
ff6_encounter_build_menu_item_for_lore:
    jml _ff6vwf_encounter_build_menu_item_for_lore      ; 4 bytes
    nopx 2

; FF6 routine to draw the name of a spell during encounters.
.segment "PTEXTENCOUNTERDRAWSPELLNAME"          ; $c16598
    jsl _ff6vwf_encounter_draw_spell_name
    rts

.segment "PTEXTENCOUNTERDRAWESPERMENU"          ; $c14e20
    jsl _ff6vwf_encounter_draw_esper_menu
    nopx 9

.segment "PTEXTENCOUNTERDRAWESPERNAME"          ; $c1667d
    jsl _ff6vwf_encounter_draw_esper_name
    rts

; FF6 routine to draw the name of one of Gau's Rages during encounters.
.segment "PTEXTENCOUNTERDRAWRAGENAME"
    jsl _ff6vwf_encounter_draw_rage_name
    rts

; FF6 routine to draw the name of one of Strago's Lores during encounters.
.segment "PTEXTENCOUNTERDRAWLORENAME"       ; $c16665
    jsl _ff6vwf_encounter_draw_lore_name
    rts

.segment "PTEXTENCOUNTERDRAWDANCENAME"      ; $c14d08
    jsl _ff6vwf_encounter_draw_dance_name
    rts

; FF6 routine to draw the name of a Magitek Armor attack.
.segment "PTEXTENCOUNTERDRAWMAGITEKNAME"
    jsl _ff6vwf_encounter_draw_magitek_name
    rts

.segment "PTEXTENCOUNTERDRAWCONTROLNAME"    ; $c16adb
    jsl _ff6vwf_encounter_draw_control_name
    rts

.segment "PTEXTENCOUNTERESPERLABELTILEMAP"  ; $c2e083
esper_label_tilemap:
    .byte $ff, $ff
    def_static_text_tiles ESPER_LABEL_START_TILE, .strlen("Esper  "), 5

.segment "PTEXTENCOUNTERMPNEEDEDTILEMAP"    ; $c14a41
    .byte $ff, $12, $14, $ff
    .byte $ff, 4
    def_static_text_tiles 14, 5, -1

; Our own functions, in a separate bank
.segment "TEXT"

.proc _ff6vwf_encounter_build_menu_item_for_spell
    sta f:ff6vwf_encounter_current_skill_slot    ; from $c14db5

    ; Stuff the original function did that we overwrote.
    phy
    asl
    sta $40
    jmp $c14db9
.endproc

.proc _ff6vwf_encounter_build_menu_item_for_rage
    sta f:ff6vwf_encounter_current_skill_slot    ; from $c15945

    ; Stuff the original function did that we overwrote.
    phy
    asl
    tay
    tdc
    jmp $c14ce6
.endproc

.proc _ff6vwf_encounter_build_menu_item_for_dance
    sta f:ff6vwf_encounter_current_skill_slot

    ; Stuff the original function did that we overwrote.
    phy
    asl
    tay
    tdc
    jmp $c14d0c
.endproc

.proc _ff6vwf_encounter_build_menu_item_for_magitek
    sta f:ff6vwf_encounter_current_skill_slot

    ; Stuff the original function did that we overwrote.
    phy
    asl
    tay
    tdc
    jmp $c14d32
.endproc

; patch _ff6vwf_encounter_build_menu_item_for_lore
.proc _ff6vwf_encounter_build_menu_item_for_lore
    sta f:ff6vwf_encounter_current_skill_slot

    ; Stuff the original function did:
    phy
    sta f:$7e0040
    lda f:ff6_encounter_active_character
    jml ff6_encounter_build_menu_item_for_lore+6
.endproc

; nearproc uint8 _ff6vwf_encounter_get_text_line_slot_for_magic_or_rage(near *skill_id_ptr)
;
; Determines the text line slot to use for Magic or Rage.
.proc _ff6vwf_encounter_get_text_line_slot_for_magic_or_rage
begin_locals
    decl_local skill_id_ptr, 2  ; near *

    enter __FRAME_SIZE__, STACK_LIMIT

    stx skill_id_ptr

    lda f:ff6vwf_encounter_current_skill_slot
    a16
    and #$00ff
    tax
    a8
    ldy #5
    jsr std_mod16_8     ; current_skill_slot % 5
    txa

    asl
    ldx skill_id_ptr
    cpx #.loword(ff6_encounter_display_list_left)
    beq :+

    inc
:   tax         ; (current_skill_slot % 5) * 2, plus one if it's the right column

    leave __FRAME_SIZE__
    rts
.endproc

; nearproc uint8 _ff6vwf_encounter_get_text_line_slot_for_dance_or_magitek(near *skill_id_ptr)
;
; Determines the text line slot to use for Dance or Magitek.
.proc _ff6vwf_encounter_get_text_line_slot_for_dance_or_magitek
    lda f:ff6vwf_encounter_current_skill_slot
    asl
    cpx #.loword(ff6_encounter_display_list_right)
    bne :+
    inc
:   tax         ; skill slot * 2, plus one if right column
    rts
.endproc

.proc _ff6vwf_encounter_draw_spell_name
begin_locals
    decl_local outgoing_args, 7
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local text_line_slot, 1            ; uint8
    decl_local spell_id_ptr, 2              ; uint8 near *
    decl_local spell_id, 1                  ; uint8
    decl_local string_ptr, 2                ; char near *
    decl_local first_tile_id, 1             ; uint8

ff6_display_list_ptr         = $7e004f
ff6_spell_display_list_left  = $7e575a
ff6_spell_display_list_right = $7e5760

; This is an immediate byte for a LDA instruction in the middle of a function. Yuck! But that's the
; only way I can think of to safely determine the length of a spell name, whether we're running in
; vanilla or TWUE.
ff6_spell_name_length = $c1601b

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Initialize locals.
    sty dest_tilemap_offset
    a16
    lda f:ff6_display_list_ptr
    inc
    sta f:ff6_display_list_ptr
    sta spell_id_ptr
    a8

    ; Figure out what text line slot we're going to use.
    ldx spell_id_ptr
    jsr _ff6vwf_encounter_get_text_line_slot_for_magic_or_rage
    txa
    sta text_line_slot

    ; Fetch spell ID.
    lda (spell_id_ptr)
    sta spell_id

    ; If empty, don't display it.
    lda spell_id
    cmp #$ff
    bne @got_a_spell

    ; Draw blanks if empty.
    ldx dest_tilemap_offset
    lda f:ff6_spell_name_length
    tay
    jsr ff6vwf_encounter_draw_blank_tile_data
    bra @out

@got_a_spell:
    ; Compute string pointer.
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_spell_names,x
    sta string_ptr
    a8

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple
    txa                             ; first_tile_id
    sta first_tile_id

    ; Draw spell icon.
    ldx spell_id
    ldy #FF6_SHORT_SPELL_NAME_LENGTH
    jsr std_mul8
    lda ff6_short_spell_names,x
    tax                             ; tile_to_draw
    ldy dest_tilemap_offset
    jsr ff6vwf_encounter_draw_tile
    stx dest_tilemap_offset

    ; Render the string.
    ldy string_ptr
    sty outgoing_args+2                 ; string_ptr
    lda #^ff6vwf_long_spell_names
    sta outgoing_args+4                 ; string_ptr bank byte
    stz outgoing_args+1                 ; blank_tiles_at_end
    lda f:ff6_spell_name_length
    sta outgoing_args+0                 ; max_tile_count
    ldx dest_tilemap_offset             ; dest_tilemap_offset
    ldy first_tile_id                   ; first_tile_id
    jsr ff6vwf_encounter_draw_standard_string

@out:
    leave __FRAME_SIZE__
    txy         ; FF6 expects the dest tilemap offset to go in Y upon exit...
    rtl
.endproc

; farproc void _ff6vwf_encounter_draw_esper_menu()
.proc _ff6vwf_encounter_draw_esper_menu
begin_locals
    decl_local outgoing_args, 6

dest_ptr = $7e5755

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Render string.
    stz outgoing_args+0                             ; 2bpp
    ldy #.loword(ff6vwf_encounter_esper_label)
    sty outgoing_args+1                             ; string
    lda #^ff6vwf_encounter_esper_label
    sta outgoing_args+3                             ; string bank byte
    ldx #FF6VWF_FIRST_TILE+ESPER_LABEL_START_TILE   ; first_tile_id
    ldy #5                                          ; max_tile_count
    jsr ff6vwf_render_string

    ; Stuff the original function did:
    lda #^dest_ptr
    sta outgoing_args+2
    lda #^esper_label_tilemap
    sta outgoing_args+5
    ldx #.loword(dest_ptr)
    stx outgoing_args+0
    ldx #.loword(esper_label_tilemap)
    stx outgoing_args+3
    ldx #$17
    jsr std_memcpy

    leave __FRAME_SIZE__
    a16         ; Needed to avoid corrupting the display list...
    lda #0
    ldx #0
    ldy #0
    a8
    rtl
.endproc

; farproc void _ff6vwf_encounter_draw_esper_name(uint8 unused,
;                                                uint16 dest_tilemap_offset,
;                                                inreg(A) esper_id)
.proc _ff6vwf_encounter_draw_esper_name
begin_locals
    decl_local outgoing_args, 5
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local string_ptr, 2                ; char near *
    decl_local esper_id_ptr, 2              ; uint8 near *
    decl_local esper_id, 1                  ; uint8

FIRST_TILE_ID = 90

display_list_ptr = $7e004f

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Initialize locals.
    sty dest_tilemap_offset
    a16
    lda f:display_list_ptr
    inc
    sta f:display_list_ptr
    sta esper_id_ptr
    a8

    ; Look up Esper ID and long name.
    lda (esper_id_ptr)
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_esper_names,x
    sta string_ptr
    a8

    ; Render the string.
    ldy string_ptr
    sty outgoing_args+2                 ; string_ptr
    lda #^ff6vwf_long_esper_names
    sta outgoing_args+4                 ; string_ptr bank byte
    lda #1
    sta outgoing_args+1                 ; blank_tiles_at_end
    lda #10
    sta outgoing_args+0                 ; max_tile_count
    ldx dest_tilemap_offset             ; dest_tilemap_offset
    ldy #FIRST_TILE_ID                  ; first_tile_id
    jsr ff6vwf_encounter_draw_standard_string

    leave __FRAME_SIZE__
    a16
    txy
    lda #0
    ldx #0
    a8
    rtl
.endproc

; farproc inreg(Y) uint16 _ff6vwf_encounter_draw_rage_name(uint8 unused,
;                                                          uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_rage_name
begin_locals
    decl_local outgoing_args, 5
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local enemy_id_ptr, 2              ; uint8 near *

display_list_ptr = $7e004f

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Initialize locals.
    sty dest_tilemap_offset
    a16
    lda f:display_list_ptr
    inc
    sta f:display_list_ptr
    sta enemy_id_ptr
    a8

    ; Figure out what text line slot we're going to use.
    ldx enemy_id_ptr
    jsr _ff6vwf_encounter_get_text_line_slot_for_magic_or_rage
    txy                     ; Y = text line slot

    ; Fetch enemy ID, and draw the name.
    ldx dest_tilemap_offset
    stx outgoing_args+0     ; dest_tilemap_offset
    ldx #.loword(ff6vwf_long_enemy_names)
    stx outgoing_args+2     ; name_list
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+4     ; name_list (bank byte)
    lda (enemy_id_ptr)
    tax                     ; X = enemy 
    jsr _ff6vwf_encounter_draw_rage_or_lore_name

    leave __FRAME_SIZE__
    a16
    txy
    lda #0
    ldx #0
    a8
    rtl
.endproc

; farproc inreg(Y) uint16 _ff6vwf_encounter_draw_lore_name(uint8 unused,
;                                                          uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_lore_name
begin_locals
    decl_local outgoing_args, 5
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local lore_id_ptr, 2               ; uint8 near *

display_list_ptr = $7e004f

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Initialize locals.
    sty dest_tilemap_offset
    a16
    lda f:display_list_ptr
    inc
    sta f:display_list_ptr
    sta lore_id_ptr
    a8

    ; Figure out what text line slot we're going to use.
    lda f:ff6vwf_encounter_current_skill_slot
    a16
    and #$00ff
    tax
    a8
    ldy #5
    jsr std_mod16_8
    txy                     ; Y = text line slot

    ; Fetch enemy ID, and draw the name.
    ldx dest_tilemap_offset
    stx outgoing_args+0     ; dest_tilemap_offset
    ldx #.loword(ff6vwf_long_lore_names)
    stx outgoing_args+2     ; name_list
    lda #^ff6vwf_long_lore_names
    sta outgoing_args+4     ; name_list (bank byte)
    lda (lore_id_ptr)
    tax                     ; X = lore 
    jsr _ff6vwf_encounter_draw_rage_or_lore_name

    leave __FRAME_SIZE__
    txy ; FF6 expects the dest tilemap offset to go in Y upon exit...
    rtl
.endproc

; nearproc uint16 _ff6vwf_encounter_draw_rage_or_lore_name(uint8 enemy_id,
;                                                          uint8 text_line_slot,
;                                                          uint16 dest_tilemap_offset,
;                                                          const char near *far *name_list)
;
; Returns the new dest tilemap offset.
.proc _ff6vwf_encounter_draw_rage_or_lore_name
begin_locals
    decl_local outgoing_args, 7
    decl_local text_line_slot, 1            ; uint8
    decl_local enemy_id, 1                  ; uint8
    decl_local string_ptr, 2                ; char near *
    decl_local first_tile_id, 1             ; uint8
begin_args_nearcall
    decl_arg dest_tilemap_offset, 2         ; uint16
    decl_arg name_list, 3                   ; const char near *far *

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Initialize locals.
    txa
    sta enemy_id
    tya
    sta text_line_slot

    ; If empty (or Tonberries), don't display it.
    lda enemy_id
    cmp #$ff
    bne @got_a_rage

    ldx dest_tilemap_offset
    ldy #FF6_SHORT_ENEMY_NAME_LENGTH
    jsr ff6vwf_encounter_draw_blank_tile_data
    bra @out

@got_a_rage:
    ; Compute string pointer.
    a16
    and #$00ff
    asl
    tay
    lda [name_list],y
    sta string_ptr
    a8

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple   ; first_tile_id
    txa                             ; first_tile_id
    sta first_tile_id

    ; Render the string.
    ldy string_ptr
    sty outgoing_args+2                 ; string_ptr
    lda name_list+2
    sta outgoing_args+4                 ; string_ptr bank byte
    lda #1
    sta outgoing_args+1                 ; blank_tiles_at_end
    lda #10
    sta outgoing_args+0                 ; max_tile_count
    ldx dest_tilemap_offset             ; dest_tilemap_offset
    ldy first_tile_id                   ; first_tile_id
    jsr ff6vwf_encounter_draw_standard_string

@out:
    leave __FRAME_SIZE__
    rts
.endproc

; farproc inreg(Y) uint16 _ff6vwf_encounter_draw_dance_name(uint8 unused,
;                                                           uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_dance_name
begin_locals
    decl_local outgoing_args, 3

; This is an immediate byte for a LDA instruction in the middle of a function. Yuck! But that's the
; only way I can think of to safely determine the length of a Dance name, whether we're running in
; vanilla or TWUE.
ff6_dance_name_length = $c16611

    enter __FRAME_SIZE__, STACK_LIMIT
    tyx
    ldy #.loword(ff6vwf_long_dance_names)
    sty outgoing_args+0
    lda #^ff6vwf_long_dance_names
    sta outgoing_args+2
    lda f:ff6_dance_name_length
    tay                             ; name_length
    jsr _ff6vwf_encounter_draw_dance_or_magitek_name

    leave __FRAME_SIZE__
    txy
    rtl
.endproc

; farproc inreg(Y) uint16 _ff6vwf_encounter_draw_magitek_name(uint8 unused,
;                                                             uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_magitek_name
begin_locals
    decl_local outgoing_args, 3

; This is an immediate byte for a LDA instruction in the middle of a function. Yuck! But that's the
; only way I can think of to safely determine the length of a Magitek attack name, whether we're
; running in vanilla or TWUE.
ff6_magitek_name_length = $c16500

    enter __FRAME_SIZE__, STACK_LIMIT

    tyx
    ldy #.loword(ff6vwf_long_magitek_names)
    sty outgoing_args+0
    lda #^ff6vwf_long_magitek_names
    sta outgoing_args+2
    lda f:ff6_magitek_name_length
    tay                             ; name_length
    jsr _ff6vwf_encounter_draw_dance_or_magitek_name

    leave __FRAME_SIZE__
    txy
    rtl
.endproc

.proc _ff6vwf_encounter_draw_control_name
begin_locals
    decl_local outgoing_args, 6
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local tiles_to_draw, 1             ; uint8
    decl_local ability_name_buffer, 11      ; char[11]
    decl_local ability_id, 1                ; uint8
    decl_local ability_name_ptr, 2          ; const ff6char near *
    decl_local current_tile_index, 1        ; uint8

ff6_dest_tilemap_main   = $7e004c
ff6_enemy_ability_names = $e6f7b9

    tax                         ; Save enemy ability in X.

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Initialize locals.
    txa
    sta ability_id
    sty dest_tilemap_offset

    ; The dest tilemap pointers start at $5899 and increase by $80 for each row.
    a16
    lda f:ff6_dest_tilemap_main
    sub #$5899
    asl
    xba
    a8
    tax
    ldy #10
    jsr std_mul8                ; ((dest_tilemap_ptr - $5899) >> 7) * 10
    add #FF6VWF_FIRST_TILE
    sta current_tile_index

    ; Look up ability ID and pointer into the ability name table.
    ldx ability_id
    ldy #FF6_SHORT_ENEMY_ABILITY_NAME_LENGTH
    jsr std_mul8
    a16
    txa
    add #.loword(ff6_enemy_ability_names)
    sta ability_name_ptr
    a8

    ; Copy ability name.
    ;
    ; TODO(tachiweasel): Can these have magic icons?
    a16
    tdc
    add #ability_name_buffer
    sta outgoing_args+0         ; dest_ptr
    lda ability_name_ptr
    sta outgoing_args+3         ; src_ptr
    a8
    lda #$7e
    sta outgoing_args+2         ; dest_ptr, bank byte
    lda #^ff6_enemy_ability_names
    sta outgoing_args+5         ; src_ptr, bank byte
    ldx #FF6_SHORT_ENEMY_ABILITY_NAME_LENGTH
    jsr ff6vwf_transcode_string

    ; Render string.
    a16
    tdc
    add #ability_name_buffer
    sta outgoing_args+1                 ; string_ptr+0
    a8
    lda #$7e
    sta outgoing_args+3                 ; string_ptr+2
    ldx dest_tilemap_offset             ; dest_tilemap_offset
    ldy current_tile_index              ; first_tile_id
    lda #FF6_SHORT_ENEMY_ABILITY_NAME_LENGTH
    sta outgoing_args+0                 ; max_tile_count
    stz outgoing_args+4                 ; save_tiles_to_draw
    jsr ff6vwf_encounter_draw_enemy_name_string

    leave __FRAME_SIZE__
    ; NB: It is important that the high byte of A be 0 upon return! FF6 will glitch otherwise.
    a16
    lda #0
    a8
    rtl
.endproc

; nearproc uint16 _ff6vwf_encounter_draw_dance_or_magitek_name(uint16 dest_tilemap_offset,
;                                                              uint8 name_length,
;                                                              const char far *name_list)
.proc _ff6vwf_encounter_draw_dance_or_magitek_name
begin_locals
    decl_local outgoing_args, 7
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local text_line_slot, 1            ; uint8
    decl_local dance_id_ptr, 2              ; uint8 near *
    decl_local dance_id, 1                  ; uint8
    decl_local string_ptr, 2                ; const char near *
    decl_local name_length, 1               ; uint8
    decl_local first_tile_id, 1             ; uint8
begin_args_nearcall
    decl_arg name_list, 3                   ; const char far *

ff6_display_list_ptr    = $7e004f

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Initialize locals.
    stx dest_tilemap_offset
    tya
    sta name_length
    a16
    lda f:ff6_display_list_ptr
    inc
    sta f:ff6_display_list_ptr
    sta dance_id_ptr
    a8

    ; Figure out what text line slot we're going to use.
    ldx dance_id_ptr
    jsr _ff6vwf_encounter_get_text_line_slot_for_dance_or_magitek
    txa
    sta text_line_slot

    ; Fetch dance or Magitek ID.
    lda (dance_id_ptr)
    cmp #8
    bge @no_dance
    sta dance_id

    ; Compute string pointer.
    lda dance_id
    a16
    and #$00ff
    asl
    tay
    lda [name_list],y
    sta string_ptr
    a8

    ; Calculate first tile ID.
    ldx text_line_slot
    ldy #10
    jsr ff6vwf_calculate_first_tile_id_simple   ; first_tile_id
    txa                             ; first_tile_id
    sta first_tile_id

    ; Render the string.
    ldy string_ptr
    sty outgoing_args+2                 ; string_ptr
    lda name_list+2
    sta outgoing_args+4                 ; string_ptr bank byte
    lda name_length
    sub #10 - 1
    sta outgoing_args+1                 ; blank_tiles_at_end
    lda #10
    sta outgoing_args+0                 ; max_tile_count
    ldx dest_tilemap_offset             ; dest_tilemap_offset
    ldy first_tile_id                   ; fsrst_tile_id
    jsr ff6vwf_encounter_draw_standard_string
    bra @out

@no_dance:
    ldx dest_tilemap_offset     ; dest_tilemap_offset
    ldy name_length
    jsr ff6vwf_encounter_draw_blank_tile_data

@out:
    leave __FRAME_SIZE__
    rts
.endproc

; Constant data

.segment "DATA"

ff6vwf_encounter_esper_label: .asciiz "Esper"
ff6vwf_mp_needed_string: .asciiz "needed"

.export ff6vwf_mp_needed_string: far
