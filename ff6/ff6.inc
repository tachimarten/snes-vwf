; snes-vwf/ff6/ff6.inc
;
; Final Fantasy 6 declarations

.ifndef FF6_FF6_INC
.define FF6_FF6_INC 1

; Constants

; Number of blocks we can queue up in VRAM at one time.
.define FF6VWF_SLOT_COUNT 32
; Number of a bytes in a DMA block.
.define FF6VWF_BLOCK_SIZE_LOG2 7
.define FF6VWF_BLOCK_SIZE 1 << FF6VWF_BLOCK_SIZE_LOG2
; First tile we use for VWF.
FF6VWF_FIRST_TILE = 8

; List item is a Key Item.
FF6VWF_MENU_DRAW_LIST_ITEM_FLAGS_KEY_ITEM = $01

FF6VWF_DMA_SCHEDULE_FLAGS_4BPP  = $01   ; Set if 4bpp. Otherwise, 2bpp.
FF6VWF_DMA_SCHEDULE_FLAGS_MENU  = $02   ; Set if this is the menu. Otherwise, it's an encounter.

FF6_SHORT_KEY_ITEM_NAME_LENGTH      = 13        ; In TWUE
FF6_SHORT_ENEMY_NAME_LENGTH         = 10
FF6_SHORT_COMMAND_NAME_LENGTH       = 7
FF6_SHORT_SPELL_NAME_LENGTH         = 7
FF6_SHORT_ESPER_NAME_LENGTH         = 8
FF6_SHORT_LORE_NAME_LENGTH          = 10
FF6_SHORT_BLITZ_NAME_LENGTH         = 10
FF6_SHORT_PC_NAME_LENGTH            = 6
FF6_SHORT_ENEMY_ABILITY_NAME_LENGTH = 10

FF6VWF_MENU_WOUNDED_START_TILE = 76

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

; Structs

; Ring buffer with 128-byte blocks.
.struct ff6vwf_dma_queue
locked      .byte   ; bool
scheduled   .byte   ; Index of first block scheduled for upload.
allocated   .byte   ; Index of last block scheduled for upload/first block allocated.
free        .byte   ; Index of last block allocated/first block free.
sizes       .byte FF6VWF_SLOT_COUNT     ; Block used sizes.
dest_addrs  .word FF6VWF_SLOT_COUNT     ; VRAM destination word addresses.
buffer      .byte FF6VWF_SLOT_COUNT * FF6VWF_BLOCK_SIZE
.endstruct

; Globals

ff6_encounter_active_character      = $7e62ca
ff6_encounter_current_menu_state    = $7e7bf0

ff6_menu_bg_attrs               = $7e0029
ff6_menu_queued_hdma            = $7e0043
ff6_menu_actor_address          = $7e0067
ff6_menu_list_slot              = $7e00e5
ff6_menu_src_ptr                = $7e00e7
ff6_menu_bg1_data               = $7e3849
ff6_menu_bg3_data               = $7e7849
ff6_menu_positioned_text_ptr    = $7e9e89
ff6_menu_string_buffer          = $7e9e8b

ff6_short_item_name_length      = $c3900e
ff6_short_item_names            = $d2b300
ff6_short_spell_names           = $e6f567

; FF6 functions

ff6_menu_draw_banner_message    = $c302f9
ff6_menu_draw_string            = $c37fd9

; Macros

.macro ff6_def_charset_string __string
    .repeat .strlen(__string), __index
        .if .strat(__string, __index) >= 'A' && .strat(__string, __index) <= 'Z'
            .byte .strat(__string, __index) - 'A' + $80
        .elseif .strat(__string, __index) >= 'a' && .strat(__string, __index) <= 'z'
            .byte .strat(__string, __index) - 'a' + $9a
        .elseif .strat(__string, __index) >= '0' && .strat(__string, __index) <= '9'
            .byte .strat(__string, __index) - '0' + $b4
        .elseif .strat(__string, __index) = '?'
            .byte $bf
        .elseif .strat(__string, __index) = '/'
            .byte $c0
        .elseif .strat(__string, __index) = ':'
            .byte $c1
        .elseif .strat(__string, __index) = '-'
            .byte $c4
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

; Declares a trampoline that allows our VWF code to call back to FF6.
;
; Bytes: 10
.macro def_trampoline target
    phd
    pea $0
    pld
    jsr target
    pld
    rtl
.endmacro

; A macro that does any DMA we need to do.
;
; This is a macro because every cycle really counts. We continually run *VERY* close to running out
; of VBLANK time.
.macro ff6vwf_run_dma queue, dma_channel, dma_timeout
    ldy #0

    ; Bail if locked.
    lda f:queue+ff6vwf_dma_queue::locked
    bne @__out

@__loop:
    lda STAT78
    lda SLHV
    lda OPVCT
    cmp #225            ; Don't DMA while the screen is rendering...
    blt @__out
    cmp #dma_timeout    ; Don't DMA after the timeout...
    bge @__out

    ; Any DMA blocks to upload?
    tdc         ; Fast clear top byte of A to 0.
    lda f:queue+ff6vwf_dma_queue::scheduled
    tax
    cmp f:queue+ff6vwf_dma_queue::allocated
    beq @__out

    ; Dequeue the DMA request.
    inc
    and #FF6VWF_SLOT_COUNT - 1
    sta f:queue+ff6vwf_dma_queue::scheduled

    ; Store size.
    tdc
    lda f:queue+ff6vwf_dma_queue::sizes,x           ; size
    a16
    sta DAS0L + $10*dma_channel

    ; Store dest VRAM address.
    txa
    asl
    tax
    lda f:queue+ff6vwf_dma_queue::dest_addrs,x      ; dest VRAM address
    sta VMADDL

    ; Store source WRAM address.
    txa     ; * 2
    lsr     ; * 1
    xba     ; * 256
    lsr     ; * 128
    add #.loword(queue)+ff6vwf_dma_queue::buffer
    sta A1T0L + $10*dma_channel
    a8

    lda #^queue
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

; Function prototypes

.struct args_ff6vwf_menu_draw_multiple_strings
    tilemaps .faraddr           ; void near *far *
.endstruct
