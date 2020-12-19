; snes-vwf/ff6/ff6.inc
;
; Final Fantasy 6 declarations

.ifndef FF6_FF6_INC
.define FF6_FF6_INC 1

; Constants

; Number of text lines we can queue up in VRAM at one time, for encounters.
FF6VWF_ENCOUNTER_SLOT_COUNT = 10
; Number of text lines we can queue up in VRAM at one time, for the menu.
FF6VWF_MENU_SLOT_COUNT = 20
; The byte size of a tile (2bpp).
VWF_TILE_BYTE_SIZE_2BPP = 2 * 8
; The byte size of a tile (4bpp).
VWF_TILE_BYTE_SIZE_4BPP = 2 * 8 * 2
FF6VWF_FIRST_TILE = 8

FF6VWF_DMA_STRUCT_SIZE = 6

FF6VWF_DMA_SCHEDULE_FLAGS_4BPP  = $01   ; Set if 4bpp. Otherwise, 2bpp.
FF6VWF_DMA_SCHEDULE_FLAGS_MENU  = $02   ; Set if this is the menu. Otherwise, it's an encounter.

FF6_SHORT_ITEM_LENGTH = 13
FF6_SHORT_ENEMY_NAME_LENGTH = 10
FF6_SHORT_COMMAND_NAME_LENGTH = 7
FF6_SHORT_SPELL_NAME_LENGTH = 7
FF6_SHORT_ESPER_NAME_LENGTH = 8
FF6_SHORT_LORE_NAME_LENGTH = 10
FF6_SHORT_BLITZ_NAME_LENGTH = 10
FF6_SHORT_KEY_ITEM_NAME_LENGTH = 13

; Globals

ff6_short_item_names    = $d2b300
ff6_short_spell_names   = $e6f567

; Macros

.macro ff6_def_charset_string __string
    .repeat .strlen(__string), __index
        .if .strat(__string, __index) >= 'A' && .strat(__string, __index) <= 'Z'
            .byte .strat(__string, __index) - 'A' + $80
        .elseif .strat(__string, __index) >= 'a' && .strat(__string, __index) <= 'z'
            .byte .strat(__string, __index) - 'a' + $9a
        .elseif .strat(__string, __index) >= '0' && .strat(__string, __index) <= '9'
            .byte .strat(__string, __index) - '0' + $b4
        .elseif .strat(__string, __index) = ':'
            .byte $c1
        .elseif .strat(__string, __index) = ' '
            .byte $ff
        .else
            .warning "unknown character in `ff6_def_charset_string`"
        .endif
    .endrepeat
.endmacro

.macro ff6_def_charset_string_z chars
    ff6_def_charset_string chars
    .byte 0
.endmacro

.macro ff6vwf_def_pointer_array prefix, count
.repeat count, i
    .word .loword(.ident(.concat(.concat(.string(prefix), "_"), .string(i))))
.endrepeat
.endmacro

; A macro that does any DMA we need to do.
;
; This is a macro because every cycle really counts. We continually run *VERY* close to running out
; of VBLANK time.
.macro ff6vwf_run_dma text_tiles, text_dma_stack_base, text_dma_stack_size, dma_channel, dma_timeout
    ldy #0

@__loop:
    lda STAT78
    lda SLHV
    lda OPVCT
    cmp #225            ; Don't DMA while the screen is rendering...
    blt @__out
    cmp #dma_timeout    ; Don't DMA after the timeout...
    bge @__out

@__do_it:
    ; Any DMA lines to upload?
    tdc                         ; Fast clear top byte of A to 0.
    lda f:text_dma_stack_size
    beq @__out

    ; Pop it off the stack.
    sub #FF6VWF_DMA_STRUCT_SIZE
    sta f:text_dma_stack_size
    tax
    a16
    lda f:text_dma_stack_base+0,x   ; dest VRAM address
    sta VMADDL
    lda f:text_dma_stack_base+2,x   ; source address
    sta A1T0L + $10*dma_channel
    lda f:text_dma_stack_base+4,x   ; size
    sta DAS0L + $10*dma_channel
    a8

    lda #^text_tiles
    sta A1B0 + $10*dma_channel
    lda #1
    sta DMAP0 + $10*dma_channel
    lda #<VMDATAL
    sta BBAD0 + $10*dma_channel
    lda #(1 << dma_channel)
    sta MDMAEN

    iny
    bra @__loop

@__out:
    ; Reset high/low selector of OPVCT to avoid screen corruption when riding chocobos!
    lda STAT78
.endmacro

.endif
