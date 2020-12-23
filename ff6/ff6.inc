; snes-vwf/ff6/ff6.inc
;
; Final Fantasy 6 declarations

.ifndef FF6_FF6_INC
.define FF6_FF6_INC 1

; Constants

; Number of text lines we can queue up in VRAM at one time, for encounters.
FF6VWF_ENCOUNTER_SLOT_COUNT = 14
; Number of text lines we can queue up in VRAM at one time, for the menu.
FF6VWF_MENU_SLOT_COUNT = 20
; The byte size of a tile (2bpp).
VWF_TILE_BYTE_SIZE_2BPP = 2 * 8
; The byte size of a tile (4bpp).
VWF_TILE_BYTE_SIZE_4BPP = 2 * 8 * 2
; First tile we use for VWF.
FF6VWF_FIRST_TILE = 8

; Address in VRAM where characters begin, for BG1 on the menu.
VWF_MENU_TILE_BG1_BASE_ADDR = $a000
; Address in VRAM where characters begin, for BG3 on the menu.
VWF_MENU_TILE_BG3_BASE_ADDR = $c000

; List item is a Key Item.
FF6VWF_MENU_DRAW_LIST_ITEM_FLAGS_KEY_ITEM = $01

FF6VWF_DMA_STRUCT_SIZE = 6

FF6VWF_DMA_SCHEDULE_FLAGS_4BPP  = $01   ; Set if 4bpp. Otherwise, 2bpp.
FF6VWF_DMA_SCHEDULE_FLAGS_MENU  = $02   ; Set if this is the menu. Otherwise, it's an encounter.

FF6_SHORT_ITEM_LENGTH               = 13        ; In TWUE
FF6_SHORT_KEY_ITEM_NAME_LENGTH      = 13        ; In TWUE
FF6_SHORT_ENEMY_NAME_LENGTH         = 10
FF6_SHORT_COMMAND_NAME_LENGTH       = 7
FF6_SHORT_SPELL_NAME_LENGTH         = 7
FF6_SHORT_ESPER_NAME_LENGTH         = 8
FF6_SHORT_LORE_NAME_LENGTH          = 10
FF6_SHORT_BLITZ_NAME_LENGTH         = 10
FF6_SHORT_PC_NAME_LENGTH            = 6
FF6_SHORT_ENEMY_ABILITY_NAME_LENGTH = 10

FF6VWF_STATS_STRING_COUNT = 9

FF6VWF_STATS_TILE_COUNT_STRENGTH = 5
FF6VWF_STATS_TILE_COUNT_STAMINA = 5
FF6VWF_STATS_TILE_COUNT_MAGIC = 3
FF6VWF_STATS_TILE_COUNT_EVASION = 5
FF6VWF_STATS_TILE_COUNT_MAGIC_EVASION = 7
FF6VWF_STATS_TILE_COUNT_SPEED = 4
FF6VWF_STATS_TILE_COUNT_ATTACK = 4
FF6VWF_STATS_TILE_COUNT_DEFENSE = 5
FF6VWF_STATS_TILE_COUNT_MAGIC_DEFENSE = 6

FF6VWF_STATS_TILE_INDEX_STRENGTH = 0
FF6VWF_STATS_TILE_INDEX_STAMINA = FF6VWF_STATS_TILE_INDEX_STRENGTH + FF6VWF_STATS_TILE_COUNT_STRENGTH
FF6VWF_STATS_TILE_INDEX_MAGIC = FF6VWF_STATS_TILE_INDEX_STAMINA + FF6VWF_STATS_TILE_COUNT_STAMINA
FF6VWF_STATS_TILE_INDEX_EVASION = FF6VWF_STATS_TILE_INDEX_MAGIC + FF6VWF_STATS_TILE_COUNT_MAGIC
FF6VWF_STATS_TILE_INDEX_MAGIC_EVASION = FF6VWF_STATS_TILE_INDEX_EVASION + FF6VWF_STATS_TILE_COUNT_EVASION
FF6VWF_STATS_TILE_INDEX_SPEED = FF6VWF_STATS_TILE_INDEX_MAGIC_EVASION + FF6VWF_STATS_TILE_COUNT_MAGIC_EVASION
FF6VWF_STATS_TILE_INDEX_ATTACK = FF6VWF_STATS_TILE_INDEX_SPEED + FF6VWF_STATS_TILE_COUNT_SPEED
FF6VWF_STATS_TILE_INDEX_DEFENSE = FF6VWF_STATS_TILE_INDEX_ATTACK + FF6VWF_STATS_TILE_COUNT_ATTACK
FF6VWF_STATS_TILE_INDEX_MAGIC_DEFENSE = FF6VWF_STATS_TILE_INDEX_DEFENSE + FF6VWF_STATS_TILE_COUNT_DEFENSE
FF6VWF_STATS_TOTAL_TILE_COUNT = FF6VWF_STATS_TILE_INDEX_MAGIC_DEFENSE + FF6VWF_STATS_TILE_COUNT_MAGIC_DEFENSE

; Globals

ff6_menu_bg_attrs               = $7e0029
ff6_menu_queued_hdma            = $7e0043
ff6_menu_list_slot              = $7e00e5
ff6_menu_bg1_data               = $7e3849
ff6_menu_bg3_data               = $7e7849
ff6_menu_positioned_text_ptr    = $7e9e89
ff6_menu_string_buffer          = $7e9e8b
ff6_short_item_names            = $d2b300
ff6_short_spell_names           = $e6f567

; FF6 functions

ff6_menu_draw_string        = $c37fd9

; Macros

.macro ff6_def_charset_string __string
    .repeat .strlen(__string), __index
        .if .strat(__string, __index) >= 'A' && .strat(__string, __index) <= 'Z'
            .byte .strat(__string, __index) - 'A' + $80
        .elseif .strat(__string, __index) >= 'a' && .strat(__string, __index) <= 'z'
            .byte .strat(__string, __index) - 'a' + $9a
        .elseif .strat(__string, __index) >= '0' && .strat(__string, __index) <= '9'
            .byte .strat(__string, __index) - '0' + $b4
        .elseif .strat(__string, __index) = '/'
            .byte $c0
        .elseif .strat(__string, __index) = ':'
            .byte $c1
        .elseif .strat(__string, __index) = '.'
            .byte $c5
        .elseif .strat(__string, __index) = '%'
            .byte $cd
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

.macro def_static_text_tiles first_tile_id, total_tiles, string_tiles
    .repeat total_tiles, i
        .if string_tiles < 0 || i < string_tiles
            .byte FF6VWF_FIRST_TILE + first_tile_id + i
        .else
            .byte $ff
        .endif
    .endrepeat
.endmacro

.macro def_static_text_tiles_z first_tile_id, total_tiles, string_tiles
    def_static_text_tiles first_tile_id, total_tiles, string_tiles
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
