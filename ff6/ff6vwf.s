; snes-vwf/ff6/ff6vwf.s
;
; Final Fantasy 6 variable-width font patch

.p816
.i16
.a8
.feature c_comments

.include "ff6.inc"
.include "../snes.inc"
.include "../vwf.inc"

.import std_memset: near
.import std_mod16_8: near
.import std_mul16_8: near
.import std_mul8: near

.import vwf_render_string: far

.import ff6vwf_encounter_dma_queue:     far
.import ff6vwf_encounter_text_tiles:    far
.import ff6vwf_menu_dma_queue:          far
.import ff6vwf_menu_text_tiles:         far
.import ff6vwf_long_item_names:         far

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

; nearproc void ff6vwf_transcode_string(uint16 length,
;                                       char far *dest_ptr,
;                                       const ff6char far *src_ptr)
;
; Copies and transcodes a string from Final Fantasy 6's character set to ASCII.
;
; The length does not include the null terminator.
.proc ff6vwf_transcode_string
begin_locals
    decl_local length, 2    ; uint16
begin_args_nearcall
    decl_arg dest_ptr, 3    ; char far *
    decl_arg src_ptr, 3     ; const ff6char far *

    enter __FRAME_SIZE__, STACK_LIMIT

    stx length

    a16
    lda #0
    ldx #0
    ldy #0
    a8

:   lda [src_ptr],y
    tax
    lda f:ff6vwf_char_to_ascii,x
    sta [dest_ptr],y
    iny
    cpy length
    bne :-

    ; Null-terminate.
    lda #0
    sta [dest_ptr],y

    leave __FRAME_SIZE__
    rts
.endproc

.export ff6vwf_transcode_string

; nearproc void ff6vwf_render_string(uint8 first_tile_id,
;                                    uint8 max_tile_count,
;                                    uint8 flags,
;                                    char far *string_ptr)
;
; Flags are the `FF6VWF_DMA_SCHEDULE_FLAGS_`.
.proc ff6vwf_render_string
begin_locals
    decl_local outgoing_args,       6     ; FIXME(tachiweasel): Should be 3 I think
    decl_local first_tile_id,       1
    decl_local tile_buffer,         .sizeof(vwf_tile_buffer)    ; struct vwf_tile_buffer
    decl_local max_line_byte_size,  2
    decl_local max_offset,          2
begin_args_nearcall
    decl_arg flags,         1
    decl_arg string_ptr,    3

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Initialize locals.
    txa
    sta first_tile_id

    ; Compute max line byte size.
    tyx
    ldy flags
    jsr ff6vwf_tile_count_to_byte_count
    stx max_line_byte_size

    ; Allocate text blocks.
    ldx first_tile_id
    ldy max_line_byte_size
    lda flags
    sta outgoing_args+0
    a16
    tdc
    add #tile_buffer
    sta outgoing_args+1
    a8
    jsr _ff6vwf_allocate_text_blocks

    ; Save end offset.
    a16
    lda tile_buffer+vwf_tile_buffer::offset
    add max_line_byte_size
    and tile_buffer+vwf_tile_buffer::mask
    sta max_offset
    a8

    ; Compute bytes to skip.
    lda flags
    and #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    bne @have_4bpp
    ldy #0
    bra @store_bytes_to_skip
@have_4bpp:
    ldy #16
@store_bytes_to_skip:

    ; Render string.
    lda string_ptr+2
    sta outgoing_args+2             ; string_ptr, bank byte
    ldx string_ptr+0
    stx outgoing_args+0             ; string_ptr, low word
    a16
    tdc
    add #tile_buffer
    tax
    a8
    jsl vwf_render_string

    ; Fill in remaining tiles with blanks.
    a16
    ldy tile_buffer+vwf_tile_buffer::offset
@blank_loop:
    cpy max_offset
    beq @done_blanking
    lda #0
    sta [tile_buffer+vwf_tile_buffer::base],y
    tya
    add #2
    and tile_buffer+vwf_tile_buffer::mask
    tay
    bra @blank_loop
@done_blanking:
    a8

    ; Schedule the upload.
    ldx max_line_byte_size
    ldy flags
    jsr ff6vwf_schedule_text_dma

    leave __FRAME_SIZE__
    rts
.endproc

.export ff6vwf_render_string

.struct args_ff6vwf_dma_queue_init
    queue_ptr .faraddr  ; struct dma_queue far *
.endstruct

; nearproc void ff6vwf_dma_queue_init(struct dma_queue far *queue_ptr)
.proc ff6vwf_dma_queue_init
LOCALS_SIZE = 0
args = LOCALS_SIZE + .sizeof(nearcall_frame) + 1

    enter LOCALS_SIZE, STACK_LIMIT

    ; Lock.
    lda #1
    ldy #ff6vwf_dma_queue::locked
    sta [args+args_ff6vwf_dma_queue_init::queue_ptr],y

    lda #0
    ldy #ff6vwf_dma_queue::scheduled
    sta [args+args_ff6vwf_dma_queue_init::queue_ptr],y
    ldy #ff6vwf_dma_queue::allocated
    sta [args+args_ff6vwf_dma_queue_init::queue_ptr],y
    ldy #ff6vwf_dma_queue::free
    sta [args+args_ff6vwf_dma_queue_init::queue_ptr],y

    ; Unlock.
    lda #0
    ldy #ff6vwf_dma_queue::locked
    sta [args+args_ff6vwf_dma_queue_init::queue_ptr],y

    leave LOCALS_SIZE
    rts
.endproc

.export ff6vwf_dma_queue_init

; nearproc void ff6vwf_get_dma_queue(uint8 flags, struct ff6vwf_dma_queue far *near *out_dma_queue)
.proc ff6vwf_get_dma_queue
    txa
    and #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    bne :+
    ldx #.loword(ff6vwf_encounter_dma_queue)
    lda #^ff6vwf_encounter_dma_queue
    bra :++
:   ldx #.loword(ff6vwf_menu_dma_queue)
    lda #^ff6vwf_menu_dma_queue
:   sta a:2,y
    a16
    txa
    sta a:0,y
    a8
    rts
.endproc

; nearproc uint8 ff6vwf_dma_queue_get_free_blocks()
.proc ff6vwf_dma_queue_get_free_blocks
.struct locals
    .org 1
    dma_queue           .faraddr    ; struct ff6vwf_dma_queue far *
    free_block_index    .byte       ; uint8
.endstruct

    enter .sizeof(locals), STACK_LIMIT

    ; Get DMA queue.
    a16
    tdc
    add #locals::dma_queue
    tay
    a8
    jsr ff6vwf_get_dma_queue

    ; Get free block index.
    ldy #ff6vwf_dma_queue::free
    lda [locals::dma_queue],y
    sta locals::free_block_index

    ; Calculate free blocks in the queue.
    ldy #ff6vwf_dma_queue::scheduled
    lda [locals::dma_queue],y           ; Get scheduled block index.
    add #FF6VWF_SLOT_COUNT
    sub locals::free_block_index
    dec                                 ; Max capacity of the queue is 1 less than its elements.
    and #FF6VWF_SLOT_COUNT - 1          ; scheduled block index - free block index
    tax

    leave .sizeof(locals)
    rts
.endproc

.export ff6vwf_dma_queue_get_free_blocks

; nearproc void _ff6vwf_allocate_text_blocks(uint8 first_tile_id,
;                                            uint16 byte_size,
;                                            uint8 flags,
;                                            struct vwf_tile_buffer *out_tile_buffer)

; Flags are the `FF6VWF_DMA_SCHEDULE_FLAGS_`.
.struct args__ff6vwf_allocate_text_blocks
    flags           .byte   ; uint8
    out_tile_buffer .addr   ; struct vwf_tile_buffer *
.endstruct
.proc _ff6vwf_allocate_text_blocks
.struct locals
    .org 1
    outgoing_args           .byte 1
    dma_queue               .faraddr    ; struct ff6vwf_dma_queue far *
    tile_base_addr          .addr       ; vram_word *
    vram_addr               .addr       ; vram_word *
    block_index             .byte       ; uint8
    next_block_index        .byte       ; uint8
    next_next_block_index   .byte       ; uint8
    first_tile_id           .byte       ; uint8
    byte_size               .word       ; uint16
.endstruct
decl_args_nearcall .sizeof(locals)

    enter .sizeof(locals), STACK_LIMIT

    ; Save arguments.
    txa
    sta locals::first_tile_id
    stx locals::tile_base_addr
    sty locals::byte_size

    ; Get DMA queue.
    tdc
    add #locals::dma_queue
    tay
    a8
    ldx args+args__ff6vwf_allocate_text_blocks::flags
    jsr ff6vwf_get_dma_queue

    ; Look up tile base address.
    lda args+args__ff6vwf_allocate_text_blocks::flags
    a16
    and #$0003
    asl
    tax
    lda f:_ff6vwf_schedule_text_dma_base_addresses,x
    sta locals::tile_base_addr
    a8

    ; Calculate VRAM address.
    ldx locals::tile_base_addr
    ldy locals::first_tile_id
    lda args+args__ff6vwf_allocate_text_blocks::flags
    sta locals::outgoing_args+0
    jsr _ff6vwf_tile_id_to_vram_addr
    stx locals::vram_addr

    ; Lock queue.
    lda #1
    sta [locals::dma_queue]

    ; Store dest base pointer.
    a16
    lda locals::dma_queue+0
    add #ff6vwf_dma_queue::buffer
    ldy #vwf_tile_buffer::base+0
    sta (args+args__ff6vwf_allocate_text_blocks::out_tile_buffer),y  ; Store near address.
    a8
    lda locals::dma_queue+2
    ldy #vwf_tile_buffer::base+2
    sta (args+args__ff6vwf_allocate_text_blocks::out_tile_buffer),y  ; Store bank byte.

    ; Store mask.
    a16
    lda #FF6VWF_SLOT_COUNT * FF6VWF_BLOCK_SIZE - 1
    ldy #vwf_tile_buffer::mask
    sta (args+args__ff6vwf_allocate_text_blocks::out_tile_buffer),y

    ; Calculate offset.
    ldy #ff6vwf_dma_queue::free
    lda [locals::dma_queue],y
    and #$00ff
    asli FF6VWF_BLOCK_SIZE_LOG2
    sta (args+args__ff6vwf_allocate_text_blocks::out_tile_buffer),y
    a8

    ldx locals::byte_size
@loop:
    beq @unlock

    ; Allocate space.
    ldy #ff6vwf_dma_queue::free
    lda [locals::dma_queue],y
    sta locals::block_index
    inc
    and #FF6VWF_SLOT_COUNT-1
    sta locals::next_block_index
    sta [locals::dma_queue],y

    ; Did we overflow? If so, dequeue the first scheduled or allocated block.
    ldy #ff6vwf_dma_queue::scheduled
    cmp [locals::dma_queue],y
    bne @no_overflow
    inc
    and #FF6VWF_SLOT_COUNT-1
    sta locals::next_next_block_index
    sta [locals::dma_queue],y           ; Dequeue scheduled block.
    ldy #ff6vwf_dma_queue::allocated    ; Check to see if we hit the first allocated block too...
    lda locals::next_block_index
    cmp [locals::dma_queue],y
    bne @no_overflow
    lda locals::next_next_block_index
    sta [locals::dma_queue],y           ; Dequeue allocated block.
@no_overflow:

    ; Compute and store block size.
    a8
    lda locals::block_index
    add #ff6vwf_dma_queue::sizes
    a16
    and #$00ff
    tay
    lda locals::byte_size
    cmp #FF6VWF_BLOCK_SIZE
    blt :+
    lda #FF6VWF_BLOCK_SIZE
:   a8
    sta [locals::dma_queue],y       ; min(byte_size, bytes_per_block)
    a16
    sub locals::byte_size
    neg16                           ; -(min(byte_size, bytes_per_block) - byte_size)
    sta locals::byte_size

    ; Store destination VRAM address.
    lda locals::block_index
    and #$00ff
    asl
    add #ff6vwf_dma_queue::dest_addrs
    tay
    lda locals::vram_addr
    lsr                         ; Convert to word address.
    sta [locals::dma_queue],y

    ; Next block.
    lda locals::vram_addr
    add #FF6VWF_BLOCK_SIZE
    sta locals::vram_addr
    lda locals::byte_size       ; To set flags...
    a8
    bra @loop

@unlock:
    ; Unlock.
    lda #0
    sta [locals::dma_queue]

    leave .sizeof(locals)
    rts
.endproc


; nearproc void ff6vwf_schedule_text_dma(uint16 max_line_byte_size, uint8 flags)
;
; Flags are the `FF6VWF_DMA_SCHEDULE_FLAGS_`.
.proc ff6vwf_schedule_text_dma
.struct locals
    .org 1
    dma_queue   .faraddr    ; struct ff6vwf_dma_queue far *
    block_count .byte       ; uint8
.endstruct

    enter .sizeof(locals), STACK_LIMIT

    ; Calculate block count.
    jsr ff6vwf_byte_count_to_block_count
    txa
    sta locals::block_count

    ; Get DMA queue.
    tyx         ; flags
    a16
    tdc
    add #locals::dma_queue
    tay
    a8
    jsr ff6vwf_get_dma_queue

    ; Lock queue.
    lda #1
    sta [locals::dma_queue]

    ; Bump scheduled pointer.
    ldy #ff6vwf_dma_queue::allocated
    lda [locals::dma_queue],y
    add locals::block_count
    and #FF6VWF_SLOT_COUNT - 1
    sta [locals::dma_queue],y

    ; Unlock.
    lda #0
    sta [locals::dma_queue]

    leave .sizeof(locals)
    rts
.endproc

.export ff6vwf_schedule_text_dma

; Maps flags to VRAM base addresses.
_ff6vwf_schedule_text_dma_base_addresses:
.word $b000     ; encounter, 2BPP
.word $8000     ; encounter, 4BPP
.word $c000     ; menu, 2BPP
.word $a000     ; menu, 4BPP

; nearproc vram *_ff6vwf_tile_id_to_vram_addr(vram *base_addr, uint8 tile_id, uint8 flags)
.proc _ff6vwf_tile_id_to_vram_addr
begin_locals
    decl_local base_addr, 2 ; uint16
begin_args_nearcall
    decl_arg flags, 1       ; uint8

    enter __FRAME_SIZE__, STACK_LIMIT

    stx base_addr

    tyx
    ldy flags
    jsr ff6vwf_tile_count_to_byte_count

    a16
    txa
    add base_addr
    tax
    a8

    leave __FRAME_SIZE__
    rts
.endproc

; nearproc uint16 ff6vwf_tile_count_to_byte_count(uint8 tile_count, uint8 flags)
.proc ff6vwf_tile_count_to_byte_count
    a16
    tya
    and #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP
    bne @have_4bpp
    txa
    and #$00ff
    bra @shift
@have_4bpp:
    txa
    and #$00ff
    asl
@shift:
    asli 4
    tax
    a8
    rts
.endproc

.export ff6vwf_tile_count_to_byte_count

; nearproc uint8 ff6vwf_byte_count_to_block_count(uint16 byte_count)
.proc ff6vwf_byte_count_to_block_count
    a16
    txa
    add #FF6VWF_BLOCK_SIZE - 1
    lsri FF6VWF_BLOCK_SIZE_LOG2     ; Divide, rounding up.
    tax
    a8
    rts
.endproc

.export ff6vwf_byte_count_to_block_count

; nearproc uint8 ff6vwf_tile_count_to_block_count(uint8 tile_count, uint8 flags)
.proc ff6vwf_tile_count_to_block_count
    ; TODO(tachiweasel): This could be more efficient.
    jsr ff6vwf_tile_count_to_byte_count
    jmp ff6vwf_byte_count_to_block_count
.endproc

.export ff6vwf_tile_count_to_block_count

; nearproc uint8 ff6vwf_calculate_first_tile_id_simple(uint8 text_line_slot, uint8 max_line_size)
.proc ff6vwf_calculate_first_tile_id_simple
    jsr std_mul8
    txa
    add #FF6VWF_FIRST_TILE
    tax
    rts
.endproc

.export ff6vwf_calculate_first_tile_id_simple

; Constant data

.segment "DATA"

ff6vwf_long_command_names: ff6vwf_def_pointer_array ff6vwf_long_command_name, 30

ff6vwf_long_command_name_0:  .asciiz "Attack"
ff6vwf_long_command_name_1:  .asciiz "Items"
ff6vwf_long_command_name_2:  .asciiz "Magic"
ff6vwf_long_command_name_3:  .asciiz "Morph"
ff6vwf_long_command_name_4:  .asciiz "Revert"
ff6vwf_long_command_name_5:  .asciiz "Steal"
ff6vwf_long_command_name_6:  .asciiz "Mug"
ff6vwf_long_command_name_7:  .asciiz "Bushido"
ff6vwf_long_command_name_8:  .asciiz "Throw"
ff6vwf_long_command_name_9:  .asciiz "Tools"
ff6vwf_long_command_name_10: .asciiz "Blitz"
ff6vwf_long_command_name_11: .asciiz "Runic"
ff6vwf_long_command_name_12: .asciiz "Lore"
ff6vwf_long_command_name_13: .asciiz "Sketch"
ff6vwf_long_command_name_14: .asciiz "Control"
ff6vwf_long_command_name_15: .asciiz "Slot"
ff6vwf_long_command_name_16: .asciiz "Rage"
ff6vwf_long_command_name_17: .asciiz "Leap"
ff6vwf_long_command_name_18: .asciiz "Mimic"
ff6vwf_long_command_name_19: .asciiz "Dance"
ff6vwf_long_command_name_20: .asciiz "Row"
ff6vwf_long_command_name_21: .asciiz "Defend"
ff6vwf_long_command_name_22: .asciiz "Jump"
ff6vwf_long_command_name_23: .asciiz "Dualcast"
ff6vwf_long_command_name_24: .asciiz "Gil Toss"
ff6vwf_long_command_name_25: .asciiz "Summon"
ff6vwf_long_command_name_26: .asciiz "Pray"
ff6vwf_long_command_name_27: .asciiz "Shock"
ff6vwf_long_command_name_28: .asciiz "Possess"
ff6vwf_long_command_name_29: .asciiz "Magitek"

ff6vwf_long_spell_names: ff6vwf_def_pointer_array ff6vwf_long_spell_name, 54

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
ff6vwf_long_spell_name_27: .asciiz "Silence"
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

ff6vwf_long_esper_names: ff6vwf_def_pointer_array ff6vwf_long_esper_name, 27

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

ff6vwf_long_blitz_names: ff6vwf_def_pointer_array ff6vwf_long_blitz_name, 8

ff6vwf_long_blitz_name_0: .asciiz "Raging Fist"
ff6vwf_long_blitz_name_1: .asciiz "Aura Cannon"
ff6vwf_long_blitz_name_2: .asciiz "Meteor Suplex"
ff6vwf_long_blitz_name_3: .asciiz "Rising Phoenix"
ff6vwf_long_blitz_name_4: .asciiz "Chakra"
ff6vwf_long_blitz_name_5: .asciiz "Razor Gale"
ff6vwf_long_blitz_name_6: .asciiz "Soul Spiral"
ff6vwf_long_blitz_name_7: .asciiz "Phantom Rush"

ff6vwf_long_dance_names: ff6vwf_def_pointer_array ff6vwf_long_dance_name, 8

ff6vwf_long_dance_name_0: .asciiz "Wind Rhapsody"
ff6vwf_long_dance_name_1: .asciiz "Forest Nocturne"
ff6vwf_long_dance_name_2: .asciiz "Desert Lullaby"
ff6vwf_long_dance_name_3: .asciiz "Love Serenade"
ff6vwf_long_dance_name_4: .asciiz "Earth Blues"
ff6vwf_long_dance_name_5: .asciiz "Water Harmony"
ff6vwf_long_dance_name_6: .asciiz "Twilight Requiem"
ff6vwf_long_dance_name_7: .asciiz "Snowman Rondo"

ff6vwf_long_bushido_names: ff6vwf_def_pointer_array ff6vwf_long_bushido_name, 8

ff6vwf_long_bushido_name_0: .asciiz "Fang"
ff6vwf_long_bushido_name_1: .asciiz "Sky"
ff6vwf_long_bushido_name_2: .asciiz "Tiger"
ff6vwf_long_bushido_name_3: .asciiz "Quadra Slam"
ff6vwf_long_bushido_name_4: .asciiz "Dragon"
ff6vwf_long_bushido_name_5: .asciiz "Eclipse"
ff6vwf_long_bushido_name_6: .asciiz "Tempest"
ff6vwf_long_bushido_name_7: .asciiz "Oblivion"

ff6vwf_long_lore_names: ff6vwf_def_pointer_array ff6vwf_long_lore_name, 24

ff6vwf_long_lore_name_0:  .asciiz "Doom"
ff6vwf_long_lore_name_1:  .asciiz "Roulette"
ff6vwf_long_lore_name_2:  .asciiz "Tsunami"
ff6vwf_long_lore_name_3:  .asciiz "Aqua Breath"
ff6vwf_long_lore_name_4:  .asciiz "Aero"
ff6vwf_long_lore_name_5:  .asciiz "1,000 Needles"
ff6vwf_long_lore_name_6:  .asciiz "Mighty Guard"
ff6vwf_long_lore_name_7:  .asciiz "Revenge Blast"
ff6vwf_long_lore_name_8:  .asciiz "White Wind"
ff6vwf_long_lore_name_9:  .asciiz "Level 5 Death"
ff6vwf_long_lore_name_10: .asciiz "Level 4 Flare"
ff6vwf_long_lore_name_11: .asciiz "Level 3 Confuse"
ff6vwf_long_lore_name_12: .asciiz "Reflect???"
ff6vwf_long_lore_name_13: .asciiz "Level ? Holy"
ff6vwf_long_lore_name_14: .asciiz "Traveler"
ff6vwf_long_lore_name_15: .asciiz "Force Field"
ff6vwf_long_lore_name_16: .asciiz "Dischord"
ff6vwf_long_lore_name_17: .asciiz "Bad Breath"
ff6vwf_long_lore_name_18: .asciiz "Transfusion"
ff6vwf_long_lore_name_19: .asciiz "Rippler"
ff6vwf_long_lore_name_20: .asciiz "Stone"
ff6vwf_long_lore_name_21: .asciiz "Quasar"
ff6vwf_long_lore_name_22: .asciiz "Grand Delta"
ff6vwf_long_lore_name_23: .asciiz "Self-Destruct"

ff6vwf_long_magitek_names: ff6vwf_def_pointer_array ff6vwf_long_magitek_name, 8

ff6vwf_long_magitek_name_0: .asciiz "Fire Beam"
ff6vwf_long_magitek_name_1: .asciiz "Thunder Beam"
ff6vwf_long_magitek_name_2: .asciiz "Blizzard Beam"
ff6vwf_long_magitek_name_3: .asciiz "Bio Blast"
ff6vwf_long_magitek_name_4: .asciiz "Healing Force"
ff6vwf_long_magitek_name_5: .asciiz "Confuser"
ff6vwf_long_magitek_name_6: .asciiz "Banisher"
ff6vwf_long_magitek_name_7: .asciiz "Magitek Missile"

ff6vwf_long_status_names: ff6vwf_def_pointer_array ff6vwf_long_status_name, 32

ff6vwf_long_status_name_0:  .asciiz "Knocked Out"
ff6vwf_long_status_name_1:  .asciiz "Petrify"
ff6vwf_long_status_name_2:  .asciiz "Imp"
ff6vwf_long_status_name_3:  .asciiz "Invisible"
ff6vwf_long_status_name_4:  .asciiz ""
ff6vwf_long_status_name_5:  .asciiz "Poison"
ff6vwf_long_status_name_6:  .asciiz "Zombie"
ff6vwf_long_status_name_7:  .asciiz "Blind"
ff6vwf_long_status_name_8:  .asciiz "Sleep"
ff6vwf_long_status_name_9:  .asciiz "Sap"
ff6vwf_long_status_name_10: .asciiz "Confuse"
ff6vwf_long_status_name_11: .asciiz "Berserk"
ff6vwf_long_status_name_12: .asciiz "Silence"
ff6vwf_long_status_name_13: .asciiz "Blink"
ff6vwf_long_status_name_14: .asciiz "HP Critical"
ff6vwf_long_status_name_15: .asciiz "Doom"
ff6vwf_long_status_name_16: .asciiz "Reflect"
ff6vwf_long_status_name_17: .asciiz "Protect"
ff6vwf_long_status_name_18: .asciiz "Shell"
ff6vwf_long_status_name_19: .asciiz "Stop"
ff6vwf_long_status_name_20: .asciiz "Haste"
ff6vwf_long_status_name_21: .asciiz "Slow"
ff6vwf_long_status_name_22: .asciiz "Regen"
ff6vwf_long_status_name_23: .asciiz "Float"
ff6vwf_long_status_name_24: .asciiz ""
ff6vwf_long_status_name_25: .asciiz ""
ff6vwf_long_status_name_26: .asciiz ""
ff6vwf_long_status_name_27: .asciiz ""
ff6vwf_long_status_name_28: .asciiz "Reraise"
ff6vwf_long_status_name_29: .asciiz ""
ff6vwf_long_status_name_30: .asciiz ""
ff6vwf_long_status_name_31: .asciiz ""

ff6vwf_long_key_item_names: ff6vwf_def_pointer_array ff6vwf_long_key_item_name, 20

ff6vwf_long_key_item_name_0:  .asciiz "Rum"
ff6vwf_long_key_item_name_1:  .asciiz "Old Clock-Key"
ff6vwf_long_key_item_name_2:  .asciiz "Fish"
ff6vwf_long_key_item_name_3:  .asciiz "Fish"
ff6vwf_long_key_item_name_4:  .asciiz "Fish"
ff6vwf_long_key_item_name_5:  .asciiz "Fish"
ff6vwf_long_key_item_name_6:  .asciiz "Lump of Metal"
ff6vwf_long_key_item_name_7:  .asciiz "Lola's Letter"
ff6vwf_long_key_item_name_8:  .asciiz "Coral"
ff6vwf_long_key_item_name_9:  .asciiz "Books"
ff6vwf_long_key_item_name_10: .asciiz "Royal Letter"
ff6vwf_long_key_item_name_11: .asciiz "Rust-Rid"
ff6vwf_long_key_item_name_12: .asciiz "Autograph"           ; unused
ff6vwf_long_key_item_name_13: .asciiz "Nail Polish"         ; unused
ff6vwf_long_key_item_name_14: .asciiz "Opera Record"        ; unused
ff6vwf_long_key_item_name_15: .asciiz "Magnifying Glass"    ; unused
ff6vwf_long_key_item_name_16: .asciiz "Eerie Stone"         ; unused
ff6vwf_long_key_item_name_17: .asciiz "Odd Picture"         ; unused
ff6vwf_long_key_item_name_18: .asciiz "Dull Picture"        ; unused
ff6vwf_long_key_item_name_19: .asciiz "Pendant"

ff6vwf_long_class_names: ff6vwf_def_pointer_array ff6vwf_long_class_name, 34

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
ff6vwf_long_class_name_12: .asciiz "Mimic"
ff6vwf_long_class_name_13: .asciiz "Yeti"
ff6vwf_long_class_name_14: .asciiz "Priest"
ff6vwf_long_class_name_15: .asciiz "General"
ff6vwf_long_class_name_16: .asciiz "Ghost"
ff6vwf_long_class_name_17: .asciiz "Ghost"
ff6vwf_long_class_name_18: .asciiz "Moogle"
ff6vwf_long_class_name_19: .asciiz "Moogle"
ff6vwf_long_class_name_20: .asciiz "Moogle"
ff6vwf_long_class_name_21: .asciiz "Moogle"
ff6vwf_long_class_name_22: .asciiz "Moogle"
ff6vwf_long_class_name_23: .asciiz "Moogle"
ff6vwf_long_class_name_24: .asciiz "Moogle"
ff6vwf_long_class_name_25: .asciiz "Moogle"
ff6vwf_long_class_name_26: .asciiz "Moogle"
ff6vwf_long_class_name_27: .asciiz "Moogle"
ff6vwf_long_class_name_28: .asciiz "Esper"
ff6vwf_long_class_name_29: .asciiz "Moogle"
ff6vwf_long_class_name_30: .asciiz "Moogle"
ff6vwf_long_class_name_31: .asciiz "Moogle"
ff6vwf_long_class_name_32: .asciiz "Imperial Soldier"
ff6vwf_long_class_name_33: .asciiz "Imperial Soldier"

ff6vwf_char_to_ascii:
.repeat 128
    .byte ' '
.endrepeat
.repeat 26, i
    .byte 'A'+i
.endrepeat
.repeat 26, i
    .byte 'a'+i
.endrepeat
.repeat 10, i
    .byte '0'+i
.endrepeat
.byte '!', '?'
.byte '/', ':', '"',  39, '-', '.', ',', ' ', ';', '#', '+', '(', ')', '%', '~', '*'
.byte ' ', ' ', '=', ' ', ' ', ' ', ' ', ' '
.repeat 128-88
    .byte ' '
.endrepeat

.export ff6vwf_long_spell_names: far
.export ff6vwf_long_command_names: far
.export ff6vwf_long_esper_names: far
.export ff6vwf_long_blitz_names: far
.export ff6vwf_long_lore_names: far
.export ff6vwf_long_dance_names: far
.export ff6vwf_long_bushido_names: far
.export ff6vwf_long_magitek_names: far
.export ff6vwf_long_status_names: far
.export ff6vwf_long_key_item_names: far
.export ff6vwf_long_class_names: far
.export ff6vwf_char_to_ascii: far
