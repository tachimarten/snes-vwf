; snes-vwf/ff6/ff6.inc
;
; Final Fantasy 6 declarations

.ifndef FF6_FF6_INC
.define FF6_FF6_INC 1

; Constants

; Number of text lines we can store in VRAM at one time, for encounters.
VWF_ENCOUNTER_SLOT_COUNT = 10
; Number of text lines we can store in VRAM at one time, for the menu.
VWF_MENU_SLOT_COUNT = 11
; The maximum length of a line of text in 8-pixel tiles.
VWF_MAX_LINE_LENGTH = 10
; The maximum length of a line of text in bytes (2bpp).
VWF_MAX_LINE_BYTE_SIZE_2BPP = VWF_MAX_LINE_LENGTH * 2 * 8
; The maximum length of a line of text in bytes (4bpp).
VWF_MAX_LINE_BYTE_SIZE_4BPP = VWF_MAX_LINE_LENGTH * 2 * 8 * 2

FF6VWF_DMA_STRUCT_SIZE = 6

FF6VWF_DMA_SCHEDULE_FLAGS_4BPP  = $01   ; Set if 4bpp. Otherwise, 2bpp.
FF6VWF_DMA_SCHEDULE_FLAGS_MENU  = $02   ; Set if this is the menu. Otherwise, it's an encounter.

FF6_SHORT_ITEM_LENGTH = 13
FF6_SHORT_ENEMY_NAME_LENGTH = 10
FF6_SHORT_BLITZ_NAME_LENGTH = 10

; Globals

ff6_short_item_names    = $d2b300

; Macros

.macro _ff6vwf_run_dma_now text_tiles, text_dma_stack_base, text_dma_stack_ptr, dma_channel
    ; Any DMA lines to upload?
    tdc                         ; Fast clear top byte of A to 0.
    lda f:text_dma_stack_ptr
    beq @__nope

    ; Pop it off the stack.
    sub #FF6VWF_DMA_STRUCT_SIZE
    sta f:text_dma_stack_ptr
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

    sec
    bra @__out
@__nope:
    clc
@__out:
.endmacro

; A macro that does any DMA we need to do.
;
; This is a macro because every cycle really counts. We continually run *VERY* close to running out
; of VBLANK time.
.macro _ff6vwf_run_dma text_tiles, text_dma_stack_base, text_dma_stack_ptr, dma_channel, dma_timeout
    lda STAT78
    lda SLHV
    lda OPVCT
    cmp #225            ; Don't DMA while the screen is rendering...
    blt @no_time
    cmp #dma_timeout    ; Don't DMA after the timeout...
    bge @no_time

@do_it:
    _ff6vwf_run_dma_now text_tiles, text_dma_stack_base, text_dma_stack_ptr, dma_channel
    bra @out

@no_time:
    clc
@out:
.endmacro

.endif
