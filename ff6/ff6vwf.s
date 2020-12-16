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
    lda #VWF_ENCOUNTER_SLOT_COUNT * FF6VWF_DMA_STRUCT_SIZE
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
    lda #VWF_MENU_SLOT_COUNT * FF6VWF_DMA_STRUCT_SIZE
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
    .byte $08   ; 0
    .byte $12   ; 1
    .byte $1c   ; 2
    .byte $26   ; 3
    .byte $30   ; 4
    .byte $3a   ; 5
    .byte $44   ; 6
    .byte $4e   ; 7
    .byte $58   ; 8
    .byte $62   ; 9
    .byte $6c   ; 10

.export ff6vwf_string_char_offsets: far

.macro def_pointer_array prefix, count
.repeat count, i
    .word .loword(.ident(.concat(.concat(.string(prefix), "_"), .string(i))))
.endrepeat
.endmacro

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

.export ff6vwf_long_blitz_names: far
.export ff6vwf_long_dance_names: far
.export ff6vwf_long_magitek_names: far
