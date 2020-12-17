; snes-vwf/ff6/ff6vwf.s
;
; Final Fantasy 6 variable-width font patch

.p816
.i16
.a8
.feature c_comments

.include "ff6.inc"
.include "../snes.inc"

.import std_memset: near
.import std_mod16_8: near
.import std_mul16_8: near
.import std_mul8: near

.import vwf_render_string: far

.import ff6vwf_encounter_text_dma_stack_base: far
.import ff6vwf_encounter_text_tiles: far
.import ff6vwf_encounter_text_dma_stack_size: far
.import ff6vwf_menu_text_dma_stack_base: far
.import ff6vwf_menu_text_tiles: far
.import ff6vwf_menu_text_dma_stack_size: far
.import ff6vwf_long_item_names: far

; Our own functions, in a separate bank
.segment "TEXT"

; Utility functions specific to VWF

; nearproc const char near *ff6vwf_get_long_item_name(uint8 item_id)
.proc ff6vwf_get_long_item_name
    a16
    txa
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_item_names,x
    tax
    a8
    rts
.endproc

.export ff6vwf_get_long_item_name

; nearproc void ff6vwf_render_string(uint8 text_line_slot,
;                                    uint16 tile_base_addr,
;                                    uint8 flags,
;                                    char far *string_ptr)
;
; Flags are the `FF6VWF_DMA_SCHEDULE_FLAGS_`.
.proc ff6vwf_render_string
begin_locals
    decl_local outgoing_args, 7
    decl_local text_line_slot, 1
    decl_local text_line_chardata_ptr, 3
    decl_local tile_base_addr, 2
    decl_local max_line_byte_size, 2
    decl_local bytes_to_skip, 1
begin_args_nearcall
    decl_arg flags, 1
    decl_arg string_ptr, 3

    enter __FRAME_SIZE__

    ; Initialize locals.
    txa
    sta text_line_slot
    sty tile_base_addr

    ; Compute max line byte size.
    lda flags
    and #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    bne :+
    lda #0
    ldx #VWF_MAX_LINE_BYTE_SIZE_2BPP
    bra :++
:   lda #16
    ldx #VWF_MAX_LINE_BYTE_SIZE_4BPP
:   sta bytes_to_skip
    stx max_line_byte_size              ; Keep in X to pass to the multiply function below.

    ; Compute dest pointer.
    lda flags
    and #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    bne @compute_dest_ptr_menu

    ; Compute dest pointer, encounter version.
    lda #^ff6vwf_encounter_text_tiles
    sta z:text_line_chardata_ptr+2
    ldy text_line_slot
    jsr std_mul16_8
    a16
    txa
    add #.loword(ff6vwf_encounter_text_tiles) ; ff6vwf_encounter_text_tiles[text_line_slot * MLBS]
    sta z:text_line_chardata_ptr
    a8
    bra @render_string

    ; Compute dest pointer, menu version.
@compute_dest_ptr_menu:
    lda #^ff6vwf_menu_text_tiles
    sta z:text_line_chardata_ptr+2
    ldy text_line_slot
    jsr std_mul16_8
    a16
    txa
    add #.loword(ff6vwf_menu_text_tiles) ; ff6vwf_menu_text_tiles[text_line_slot * MLBS]
    sta z:text_line_chardata_ptr
    a8

    ; Render string.
@render_string:
    lda string_ptr+2
    sta outgoing_args+5
    ldy string_ptr+0
    sty outgoing_args+3             ; string_ptr
    lda z:text_line_chardata_ptr+2
    sta outgoing_args+2
    ldy z:text_line_chardata_ptr+0
    sty outgoing_args+0             ; dest_ptr
    ldx bytes_to_skip
    jsl vwf_render_string

    ; X now contains the pointer to the end of the tiles we rendered. Fill in remaining tiles
    ; with blanks.
    stx outgoing_args+0             ; ptr
    lda z:text_line_chardata_ptr+2
    sta outgoing_args+2             ; ptr, bank byte
    a16
    txa
    sub max_line_byte_size
    sub z:text_line_chardata_ptr+0
    neg16                           ; -(X - MLBS - item_name_tiles) == MLBS - (X - item_name_tiles)
    tay                             ; count
    a8
    ldx #0                          ; value
    jsr std_memset

    ; Schedule the upload.
    ldx text_line_slot
    ldy tile_base_addr
    lda flags
    sta outgoing_args+0
    jsr ff6vwf_schedule_text_dma

    leave __FRAME_SIZE__
    rts
.endproc

.export ff6vwf_render_string

; nearproc void ff6vwf_schedule_text_dma(uint8 text_line_index,
;                                        uint16 tile_base_addr,
;                                        uint8 flags)
;
; Flags are the `FF6VWF_DMA_SCHEDULE_FLAGS_`.
.proc ff6vwf_schedule_text_dma
begin_locals
    decl_local outgoing_args, 7
    decl_local dma_stack_size, 1        ; uint8
    decl_local dma_stack_ptr, 3         ; uint16 far *
    decl_local tile_base_addr, 2        ; vram *
    decl_local max_line_byte_size, 2    ; uint8
    decl_local text_line_index, 1       ; uint8
    decl_local string_char_offset, 1    ; uint8
begin_args_nearcall
    decl_arg flags, 1                   ; uint8

    enter __FRAME_SIZE__

    ; Initialize locals.
    txa
    sta text_line_index
    sty tile_base_addr

    ; Lock the DMA stack pointer.
    lda flags
    and #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    bne @lock_menu_dma_stack_pointer

    ; Encounter path for the above:
    a16
    lda #.loword(ff6vwf_encounter_text_dma_stack_base)
    sta outgoing_args+0
    lda #.loword(ff6vwf_encounter_text_dma_stack_size)
    sta outgoing_args+3
    a8
    lda #^ff6vwf_encounter_text_dma_stack_base
    sta outgoing_args+2             ; dma_stack_base
    lda #^ff6vwf_encounter_text_dma_stack_size
    sta outgoing_args+5             ; dma_stack_size
    lda #FF6VWF_ENCOUNTER_SLOT_COUNT * FF6VWF_DMA_STRUCT_SIZE
    sta outgoing_args+6             ; dma_stack_capacity
    bra @call_lock_dma_stack

    ; Menu path for the above
@lock_menu_dma_stack_pointer:
    a16
    lda #.loword(ff6vwf_menu_text_dma_stack_base)
    sta outgoing_args+0
    lda #.loword(ff6vwf_menu_text_dma_stack_size)
    sta outgoing_args+3
    a8
    lda #^ff6vwf_menu_text_dma_stack_base
    sta outgoing_args+2             ; dma_stack_base
    lda #^ff6vwf_menu_text_dma_stack_size
    sta outgoing_args+5             ; dma_stack_size
    lda #FF6VWF_MENU_SLOT_COUNT * FF6VWF_DMA_STRUCT_SIZE
    sta outgoing_args+6             ; dma_stack_capacity
    bra @call_lock_dma_stack

@call_lock_dma_stack:
    a16
    tdc
    add #dma_stack_ptr
    tax                             ; out_dma_stack_ptr = &dma_stack_ptr
    tdc
    add #dma_stack_size
    tay                             ; out_dma_stack_size = &dma_stack_size
    a8
    jsr _ff6vwf_lock_dma_stack
    cpx #0
    beq @out

    ; Look up string char offset for the text line.
    lda text_line_index
    a16
    and #$00ff
    tax
    a8
    lda f:ff6vwf_string_char_offsets,x
    sta string_char_offset

    ; Calculate max line byte size and byte size of one tile.
    lda flags
    and #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    bne :+
    ldx #VWF_MAX_LINE_BYTE_SIZE_2BPP
    lda #8*2
    bra :++
:   ldx #VWF_MAX_LINE_BYTE_SIZE_4BPP
    lda #8*4
:   stx max_line_byte_size              ; Keep in X to pass to the multiply function below.

    ; Calculate and store VRAM address.
    ldy string_char_offset
    tax
    jsr std_mul8
    a16
    txa
    add tile_base_addr                  ; VRAM address
    lsr                                 ; word address
    sta [dma_stack_ptr]                 ; write VRAM address
    inc dma_stack_ptr
    inc dma_stack_ptr
    a8

    ; Calculate source address.
    ldx max_line_byte_size
    ldy text_line_index
    jsr std_mul16_8
    lda flags
    and #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    a16
    bne :+
    txa
    add #.loword(ff6vwf_encounter_text_tiles)   ; src address
    bra @push_src_address
:   txa
    add #.loword(ff6vwf_menu_text_tiles)        ; src address

    ; Push our source address and size on the stack.
@push_src_address:
    sta [dma_stack_ptr]
    inc dma_stack_ptr
    inc dma_stack_ptr
    lda max_line_byte_size
    sta [dma_stack_ptr]
    a8

    ; Unlock.
    lda flags
    and #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    bne @unlock_menu
    ; Encounter path:
    lda dma_stack_size
    sta f:ff6vwf_encounter_text_dma_stack_size
    bra @out
    ; Menu path:
@unlock_menu:
    lda dma_stack_size
    sta f:ff6vwf_menu_text_dma_stack_size

@out:
    leave __FRAME_SIZE__
    rts
.endproc

.export ff6vwf_schedule_text_dma

; nearproc bool _ff6vwf_lock_dma_stack(struct dma far *near *out_dma_stack_ptr,
;                                      uint8 near *out_dma_stack_size,
;                                      struct dma far *dma_stack_base,
;                                      uint8 far *dma_stack_size_ptr,
;                                      uint8 dma_stack_capacity)
;
; Returns true if there was space or false on overflow. NOT reentrant.
.proc _ff6vwf_lock_dma_stack
begin_locals
    decl_local out_dma_stack_ptr, 2     ; struct dma far *near *
    decl_local out_dma_stack_size, 2    ; uint8 near *
    decl_local pre_dma_stack_size, 1    ; uint8
begin_args_nearcall
    decl_arg dma_stack_base, 3          ; struct dma far *
    decl_arg dma_stack_size_ptr, 3      ; uint8 far *
    decl_arg dma_stack_capacity, 1      ; uint8

    enter __FRAME_SIZE__

    ; Store arguments.
    stx out_dma_stack_ptr
    sty out_dma_stack_size

    ; Bump size.
    lda [dma_stack_size_ptr]
    sta pre_dma_stack_size
    add #FF6VWF_DMA_STRUCT_SIZE
    cmp dma_stack_capacity
    ble @it_fits

    ; Overflow. Bail out.
    ldx #0
    bra @out

@it_fits:
    sta (out_dma_stack_size)

    ; Lock the DMA stack by setting its size to zero, ensuring NMI won't touch it.
    lda #0
    sta [dma_stack_size_ptr]

    ; Store stack pointer.
    lda pre_dma_stack_size
    a16
    and #$00ff
    add dma_stack_base+0
    sta (out_dma_stack_ptr)     ; Store low word.
    a8
    ldy #2
    lda dma_stack_base+2
    sta (out_dma_stack_ptr),y   ; Store bank byte.

    ; Finish up.
    ldx #1

@out:
    leave __FRAME_SIZE__
    rts
.endproc

; Constant data

.segment "DATA"

ff6vwf_string_char_offsets:
.repeat .max(FF6VWF_ENCOUNTER_SLOT_COUNT, FF6VWF_MENU_SLOT_COUNT), i
    .byte $08+FF6VWF_MAX_LINE_LENGTH*i
.endrepeat

.export ff6vwf_string_char_offsets: far

.macro def_pointer_array prefix, count
.repeat count, i
    .word .loword(.ident(.concat(.concat(.string(prefix), "_"), .string(i))))
.endrepeat
.endmacro

ff6vwf_long_spell_names: def_pointer_array ff6vwf_long_spell_name, 54

ff6vwf_long_spell_name_0:  .asciiz "Fire"
ff6vwf_long_spell_name_1:  .asciiz "Blizzard"
ff6vwf_long_spell_name_2:  .asciiz "Thunder"
ff6vwf_long_spell_name_3:  .asciiz "Poison"
ff6vwf_long_spell_name_4:  .asciiz "Drain"
ff6vwf_long_spell_name_5:  .asciiz "Fira"
ff6vwf_long_spell_name_6:  .asciiz "Blizzara"
ff6vwf_long_spell_name_7:  .asciiz "Thundara"
ff6vwf_long_spell_name_8:  .asciiz "Bio"
ff6vwf_long_spell_name_9:  .asciiz "Firaga"
ff6vwf_long_spell_name_10: .asciiz "Blizzaga"
ff6vwf_long_spell_name_11: .asciiz "Thundaga"
ff6vwf_long_spell_name_12: .asciiz "Break"
ff6vwf_long_spell_name_13: .asciiz "Death"
ff6vwf_long_spell_name_14: .asciiz "Holy"
ff6vwf_long_spell_name_15: .asciiz "Flare"
ff6vwf_long_spell_name_16: .asciiz "Gravity"
ff6vwf_long_spell_name_17: .asciiz "Graviga"
ff6vwf_long_spell_name_18: .asciiz "Banish"
ff6vwf_long_spell_name_19: .asciiz "Meteor"
ff6vwf_long_spell_name_20: .asciiz "Ultima"
ff6vwf_long_spell_name_21: .asciiz "Quake"
ff6vwf_long_spell_name_22: .asciiz "Tornado"
ff6vwf_long_spell_name_23: .asciiz "Meltdown"
ff6vwf_long_spell_name_24: .asciiz "Libra"
ff6vwf_long_spell_name_25: .asciiz "Slow"
ff6vwf_long_spell_name_26: .asciiz "Rasp"
ff6vwf_long_spell_name_27: .asciiz "Slience"
ff6vwf_long_spell_name_28: .asciiz "Protect"
ff6vwf_long_spell_name_29: .asciiz "Sleep"
ff6vwf_long_spell_name_30: .asciiz "Confuse"
ff6vwf_long_spell_name_31: .asciiz "Haste"
ff6vwf_long_spell_name_32: .asciiz "Stop"
ff6vwf_long_spell_name_33: .asciiz "Berserk"
ff6vwf_long_spell_name_34: .asciiz "Float"
ff6vwf_long_spell_name_35: .asciiz "Imp"
ff6vwf_long_spell_name_36: .asciiz "Reflect"
ff6vwf_long_spell_name_37: .asciiz "Shell"
ff6vwf_long_spell_name_38: .asciiz "Vanish"
ff6vwf_long_spell_name_39: .asciiz "Hastega"
ff6vwf_long_spell_name_40: .asciiz "Slowga"
ff6vwf_long_spell_name_41: .asciiz "Osmose"
ff6vwf_long_spell_name_42: .asciiz "Warp"
ff6vwf_long_spell_name_43: .asciiz "Quick"
ff6vwf_long_spell_name_44: .asciiz "Dispel"
ff6vwf_long_spell_name_45: .asciiz "Cure"
ff6vwf_long_spell_name_46: .asciiz "Cura"
ff6vwf_long_spell_name_47: .asciiz "Curaga"
ff6vwf_long_spell_name_48: .asciiz "Raise"
ff6vwf_long_spell_name_49: .asciiz "Arise"
ff6vwf_long_spell_name_50: .asciiz "Poisona"
ff6vwf_long_spell_name_51: .asciiz "Esuna"
ff6vwf_long_spell_name_52: .asciiz "Regen"
ff6vwf_long_spell_name_53: .asciiz "Reraise"

ff6vwf_long_esper_names: def_pointer_array ff6vwf_long_esper_name, 27

ff6vwf_long_esper_name_0:  .asciiz "Ramuh"
ff6vwf_long_esper_name_1:  .asciiz "Ifrit"
ff6vwf_long_esper_name_2:  .asciiz "Shiva"
ff6vwf_long_esper_name_3:  .asciiz "Siren"
ff6vwf_long_esper_name_4:  .asciiz "Midgardsormr"
ff6vwf_long_esper_name_5:  .asciiz "Catoblepas"
ff6vwf_long_esper_name_6:  .asciiz "Maduin"
ff6vwf_long_esper_name_7:  .asciiz "Bismarck"
ff6vwf_long_esper_name_8:  .asciiz "Cait Sith"
ff6vwf_long_esper_name_9:  .asciiz "Quetzalli"
ff6vwf_long_esper_name_10: .asciiz "Valigarmanda"
ff6vwf_long_esper_name_11: .asciiz "Odin"
ff6vwf_long_esper_name_12: .asciiz "Raiden"
ff6vwf_long_esper_name_13: .asciiz "Bahamut"
ff6vwf_long_esper_name_14: .asciiz "Alexander"
ff6vwf_long_esper_name_15: .asciiz "Crusader"
ff6vwf_long_esper_name_16: .asciiz "Ragnarok"
ff6vwf_long_esper_name_17: .asciiz "Kirin"
ff6vwf_long_esper_name_18: .asciiz "Zona Seeker"
ff6vwf_long_esper_name_19: .asciiz "Carbuncle"
ff6vwf_long_esper_name_20: .asciiz "Phantom"
ff6vwf_long_esper_name_21: .asciiz "Seraphim"
ff6vwf_long_esper_name_22: .asciiz "Golem"
ff6vwf_long_esper_name_23: .asciiz "Unicorn"
ff6vwf_long_esper_name_24: .asciiz "Fenrir"
ff6vwf_long_esper_name_25: .asciiz "Lakshmi"
ff6vwf_long_esper_name_26: .asciiz "Phoenix"

ff6vwf_long_blitz_names: def_pointer_array ff6vwf_long_blitz_name, 8

ff6vwf_long_blitz_name_0: .asciiz "Raging Fist"
ff6vwf_long_blitz_name_1: .asciiz "Aura Cannon"
ff6vwf_long_blitz_name_2: .asciiz "Meteor Suplex"
ff6vwf_long_blitz_name_3: .asciiz "Rising Phoenix"
ff6vwf_long_blitz_name_4: .asciiz "Chakra"
ff6vwf_long_blitz_name_5: .asciiz "Razor Gale"
ff6vwf_long_blitz_name_6: .asciiz "Soul Spiral"
ff6vwf_long_blitz_name_7: .asciiz "Phantom Rush"

ff6vwf_long_dance_names: def_pointer_array ff6vwf_long_dance_name, 8

ff6vwf_long_dance_name_0: .asciiz "Wind Rhapsody"
ff6vwf_long_dance_name_1: .asciiz "Forest Nocturne"
ff6vwf_long_dance_name_2: .asciiz "Desert Lullaby"
ff6vwf_long_dance_name_3: .asciiz "Love Serenade"
ff6vwf_long_dance_name_4: .asciiz "Earth Blues"
ff6vwf_long_dance_name_5: .asciiz "Water Harmony"
ff6vwf_long_dance_name_6: .asciiz "Twilight Requiem"
ff6vwf_long_dance_name_7: .asciiz "Snowman Rondo"

ff6vwf_long_magitek_names: def_pointer_array ff6vwf_long_magitek_name, 8

ff6vwf_long_magitek_name_0: .asciiz "Fire Beam"
ff6vwf_long_magitek_name_1: .asciiz "Thunder Beam"
ff6vwf_long_magitek_name_2: .asciiz "Ice Beam"
ff6vwf_long_magitek_name_3: .asciiz "Bio Blast"
ff6vwf_long_magitek_name_4: .asciiz "Healing Force"
ff6vwf_long_magitek_name_5: .asciiz "Confuser"
ff6vwf_long_magitek_name_6: .asciiz "Banisher"
ff6vwf_long_magitek_name_7: .asciiz "Magitek Missile"

ff6vwf_long_class_names: def_pointer_array ff6vwf_long_class_name, 36

ff6vwf_long_class_name_0:  .asciiz "Sorceress"
ff6vwf_long_class_name_1:  .asciiz "Adventurer"
ff6vwf_long_class_name_2:  .asciiz "Samurai"
ff6vwf_long_class_name_3:  .asciiz "Assassin"
ff6vwf_long_class_name_4:  .asciiz "Machinist"
ff6vwf_long_class_name_5:  .asciiz "Monk"
ff6vwf_long_class_name_6:  .asciiz "Rune Knight"
ff6vwf_long_class_name_7:  .asciiz "Blue Mage"
ff6vwf_long_class_name_8:  .asciiz "Pictomancer"
ff6vwf_long_class_name_9:  .asciiz "Gambler"
ff6vwf_long_class_name_10: .asciiz "Moogle"
ff6vwf_long_class_name_11: .asciiz "Feral Youth"
ff6vwf_long_class_name_12: .asciiz "Moogle"
ff6vwf_long_class_name_13: .asciiz "Mimic"
ff6vwf_long_class_name_14: .asciiz "Yeti"
ff6vwf_long_class_name_15: .asciiz "Priest"
ff6vwf_long_class_name_16: .asciiz "General"
ff6vwf_long_class_name_17: .asciiz "Ghost"
ff6vwf_long_class_name_18: .asciiz "Ghost"
ff6vwf_long_class_name_19: .asciiz "Moogle"
ff6vwf_long_class_name_20: .asciiz "Moogle"
ff6vwf_long_class_name_21: .asciiz "Moogle"
ff6vwf_long_class_name_22: .asciiz "Moogle"
ff6vwf_long_class_name_23: .asciiz "Moogle"
ff6vwf_long_class_name_24: .asciiz "Moogle"
ff6vwf_long_class_name_25: .asciiz "Moogle"
ff6vwf_long_class_name_26: .asciiz "Moogle"
ff6vwf_long_class_name_27: .asciiz "Moogle"
ff6vwf_long_class_name_28: .asciiz "Moogle"
ff6vwf_long_class_name_29: .asciiz "Moogle"
ff6vwf_long_class_name_30: .asciiz "Esper"
ff6vwf_long_class_name_31: .asciiz "Moogle"
ff6vwf_long_class_name_32: .asciiz "Imperial Soldier"
ff6vwf_long_class_name_33: .asciiz "Imperial Soldier"
ff6vwf_long_class_name_34: .asciiz "Shogun"
ff6vwf_long_class_name_35: .asciiz "Moogle"

.export ff6vwf_long_spell_names: far
.export ff6vwf_long_esper_names: far
.export ff6vwf_long_blitz_names: far
.export ff6vwf_long_dance_names: far
.export ff6vwf_long_magitek_names: far
.export ff6vwf_long_class_names: far
