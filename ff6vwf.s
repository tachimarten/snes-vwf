; snes-vwf/ff6vwf.s
;
; Final Fantasy 6 variable-width font patch

.p816
.i16
.a8
.feature c_comments

.include "snes.inc"

.import vwf_render_string: far

; Constants

; Address in VRAM where characters begin, for BG3 during encounters.
VWF_ENCOUNTER_TILE_BASE_ADDR = $b000
; Address in VRAM where characters begin, for BG1 on the menu.
VWF_MENU_TILE_BG1_BASE_ADDR = $a000
; Address in VRAM where characters begin, for BG3 on the menu.
VWF_MENU_TILE_BG3_BASE_ADDR = $c000
; Number of text lines we can store in VRAM at one time, for encounters.
VWF_ENCOUNTER_SLOT_COUNT = 10
; Number of text lines we can store in VRAM at one time, for the menu.
VWF_MENU_SLOT_COUNT = 10
; The maximum length of a line of text in 8-pixel tiles.
VWF_MAX_LINE_LENGTH = 10
; The maximum length of a line of text in bytes (2bpp).
VWF_MAX_LINE_BYTE_SIZE_2BPP = VWF_MAX_LINE_LENGTH * 2 * 8
; The maximum length of a line of text in bytes (4bpp).
VWF_MAX_LINE_BYTE_SIZE_4BPP = VWF_MAX_LINE_LENGTH * 2 * 8 * 2

FF6_SHORT_ENEMY_NAME_LENGTH = 10
FF6_SHORT_ITEM_LENGTH       = 13

FF6VWF_DMA_STRUCT_SIZE = 6

FF6VWF_ITEM_TYPE_INVENTORY      = 0
FF6VWF_ITEM_TYPE_ITEM_IN_HAND   = 1
FF6VWF_ITEM_TYPE_TOOL           = 2

FF6VWF_DMA_SCHEDULE_FLAGS_4BPP  = $01   ; Set if 4bpp. Otherwise, 2bpp.
FF6VWF_DMA_SCHEDULE_FLAGS_MENU  = $02   ; Set if this is the menu. Otherwise, it's an encounter.

; FF6 globals

ff6_short_item_names    = $d2b300

ff6_menu_list_slot      = $7e00e5
ff6_encounter_enemy_ids = $7e200d
ff6_menu_string_buffer  = $7e9e8b

.segment "BSS"

; Encounter BSS
.org $7ec000

; Stack of DMA structures. They look like:
;
; struct dma {
;     void vram *dest_vram_addr;    // word address
;     void near *src_addr;          // our address
;     uint16 size;                  // number of bytes to be transferred
; };
;
ff6vwf_encounter_text_dma_stack_base: .res FF6VWF_DMA_STRUCT_SIZE * VWF_ENCOUNTER_SLOT_COUNT
; Buffer space for the lines of text, `VWF_MAX_LINE_LENGTH` each to be stored, ready to be uploaded
; to VRAM.
ff6vwf_encounter_text_tiles: .res VWF_MAX_LINE_BYTE_SIZE_4BPP * VWF_ENCOUNTER_SLOT_COUNT
; Current of the stack *in bytes*.
ff6vwf_encounter_text_dma_stack_ptr: .res 1
; ID of the current item slot we're drawing.
ff6vwf_encounter_current_item_slot: .res 1
; What type of item we're drawing.
ff6vwf_encounter_item_type_to_draw: .res 1
; ID of the current rage slot we're drawing.
ff6vwf_encounter_current_rage_slot: .res 1

ff6vwf_encounter_bss_end:
 
.export ff6vwf_encounter_bss_end

; Menu BSS
.org $7ea000

; Stack of DMA structures, just like the encounter ones.
ff6vwf_menu_text_dma_stack_base: .res FF6VWF_DMA_STRUCT_SIZE * VWF_MENU_SLOT_COUNT
; Buffer space for the lines of text, `VWF_MAX_LINE_LENGTH` each to be stored, ready to be uploaded
; to VRAM.
ff6vwf_menu_text_tiles: .res VWF_MAX_LINE_BYTE_SIZE_4BPP * VWF_MENU_SLOT_COUNT
; Current of the stack *in bytes*.
ff6vwf_menu_text_dma_stack_ptr: .res 1

ff6vwf_menu_bss_end:

.export ff6vwf_menu_bss_end

.reloc 

; Patches to Final Fantasy 6 functions

; Final Fantasy 6 encounter patches

; Encounter setup. We patch it to initialize our DMA stack.
.segment "PTEXTINITENCOUNTER"
    jml _ff6vwf_encounter_init

; FF6 routine that draws an enemy name during encounters. We patch it to support variable-width
; fonts.
.segment "PTEXTDRAWENEMYNAME"
    jsl _ff6vwf_encounter_draw_enemy_name
    rts

; FF6 routine that builds a menu item for an item in inventory during encounters. We patch it to
; record what inventory slot number it was so that the VWF rendering routine can figure out what
; text slot to use in order to avoid collisions.
.segment "PTEXTBUILDMENUITEMFORITEM"
    jml _ff6vwf_encounter_build_menu_item_for_item          ; 4 bytes

; FF6 routine that builds a menu item for an equipped item in hand (during encounters). We patch it
; to record that this is an item in hand so that the VWF rendering routine can use the appropriate
; slot.
.segment "PTEXTBUILDMENUITEMFORITEMINHAND"
    jml _ff6vwf_encounter_build_menu_item_for_item_in_hand  ; 4 bytes

.segment "PTEXTBUILDMENUITEMFORTOOLS"
    jml _ff6vwf_encounter_build_menu_item_for_tools

; FF6 routine to draw an item name during encounters.
.segment "PTEXTDRAWITEMNAME"
    jsl _ff6vwf_encounter_draw_item_name
    rts

.segment "PTEXTENCOUNTERBUILDMENUITEMFORRAGE"
    jml _ff6vwf_encounter_build_menu_item_for_rage  ; 4 bytes

; FF6 routine to draw the name of one of Gau's Rages during encounters.
.segment "PTEXTENCOUNTERDRAWRAGENAME"
    jsl _ff6vwf_encounter_draw_rage_name
    rts

; Part of the FF6 encounter NMI/VBLANK handler. We patch it to upload our text if needed.
.segment "PTEXTENCOUNTERRUNDMA"
    jml _ff6vwf_encounter_run_dma           ; 4 bytes

; FF6 function that restores the normal BG3 font by copying it from the ROM after a dialogue-style
; text box in an encounter has closed. We have to patch it to reupload any enemy names we created
; to VRAM.
.segment "PTEXTRESTORESMALLFONT"
ff6_encounter_schedule_dma = $198d
    jsl _ff6vwf_encounter_restore_small_font
    rts

; Wraps FF6's "schedule DMA" function in a far call.
_ff6vwf_encounter_schedule_dma_trampoline:
    jsr ff6_encounter_schedule_dma
    rtl

; Final Fantasy 6 menu patches

.segment "PTEXTMENUINIT"
    jml _ff6vwf_menu_init

.segment "PTEXTMENULOADEQUIPMENTNAME"
ff6_menu_trigger_nmi = $1368

    jsl _ff6vwf_menu_draw_equipment_name
    rts

; Wraps FF6's "force NMI" function in a far call.
_ff6vwf_menu_force_nmi_trampoline:
    phd
    pea $0
    pld
    jsr ff6_menu_trigger_nmi
    pld
    rtl

; FF6 routine to draw an item in the Item menu.
.segment "PTEXTMENUDRAWITEMNAME"
    jsl _ff6vwf_menu_draw_inventory_item_name   ; 4 bytes
    nopx 2

; FF6 routine to draw an item available to equip, in the Equip or Relic menus.
.segment "PTEXTMENUDRAWITEMTOEQUIPNAME"
    jsl _ff6vwf_menu_draw_item_to_equip_name    ; 4 bytes
    nopx 3                                      ; overwrite `jsr $c39d11`

.segment "PTEXTMENUINITRAGEMENU"
    stz $4a         ; List scroll: 0
    jsr $091f       ; Create scrollbar
    a16
    lda #$00cc      ; V-Speed: 0.8 px
    sta f:$7e354a,x ; Set scrollbar's
    lda #$0068      ; Y: 104
    sta f:$7e34ca,x ; Set scrollbar's
    a8
    jsr $4c4c       ; Load navig data
    jsr $4c55       ; Relocate cursor
    lda #$f0        ; Top row
    sta $5c         ; Set scroll limit
    lda #8          ; Onscreen rows: 8
    sta $5a         ; Set rows per page
    lda #1          ; Onscreen cols: 1
    sta $5b         ; Set cols per page
    ldy #256        ; X: 256
    sty $39         ; Set BG2 X-Pos
    sty $3d         ; Set BG3 X-Pos
    jsr $5391       ; Draw rages, etc.
    lda #$1d        ; C3/28BA
    sta $26         ; Next: Sustain menu
    rts

.segment "PTEXTMENUDRAWRAGEROW"
    lda #$20        ; Palette 0
    sta $29         ; Color: User's
    jsr $5409       ; Define source
    ldx #5          ; X: 5
    jsr $5418       ; Draw Rage A
    inc $e5         ; Rage slot +1
    rts

; FF6 routine to draw a rage in the Skills menu.
.segment "PTEXTMENUDRAWRAGENAME"
    jsl _ff6vwf_menu_draw_rage_name             ; 4 bytes
    nop

.segment "PTEXTMENUDRAWCOLOSSEUMITEM"
    jsl _ff6vwf_menu_draw_colosseum_item        ; 4 bytes
    jmp $7fd9       ; Draw item name.

; The "refresh screen" routine for the FF6 menu NMI/VBLANK handler. We patch it to upload our text
; if needed.
.segment "PTEXTMENURUNDMA"
    jsl _ff6vwf_menu_run_dma_setup
    jsr $d263           ; Refresh Mode 7
    jsr $1463           ; Refresh OAM
    jsr $14d2           ; Refresh CGRAM
    jsr $1488           ; Do VRAM DMA A

    ; We have priority over VRAM DMA B.
    ;
    ; For this to work, we must eagerly trigger NMI every time we render some text.
    jsl _ff6vwf_menu_run_dma
    bcs @we_did_dma

    jsr $14ac           ; Do VRAM DMA B
@we_did_dma:
    rts

; Our own functions, in a separate bank
.segment "TEXT"

; A macro that does any DMA we need to do.
;
; This is a macro because every cycle really counts. We continually run *VERY* close to running out
; of VBLANK time.
.macro _ff6vwf_run_dma text_tiles, text_dma_stack_base, text_dma_stack_ptr, dma_channel
    lda STAT78
    lda SLHV
    lda OPVCT
    cmp #250        ; Don't DMA after scanline 250...
    bge @nope
    ; 239 is where VBLANK begins, so anything before that in the low byte means we're at a scanline
    ; >= 256, which isn't enough time for DMA.
    cmp #239
    blt @nope

@do_it:
    ; Any DMA lines to upload?
    tdc                         ; Fast clear top byte of A to 0.
    lda f:text_dma_stack_ptr
    beq @nope

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
    bra @out

@nope:
    clc

@out:
.endmacro

; farproc void _ff6vwf_encounter_init()
.proc _ff6vwf_encounter_init
    lda #0
    sta ff6vwf_encounter_text_dma_stack_ptr
    jsl $c00016 ; original code
    jml $c1102e
.endproc

; farproc void _ff6vwf_encounter_draw_enemy_name(uint16 unused, uint16 tilemap_offset)
;
; Draws an enemy name during an encounter using our small variable-width font.
.proc _ff6vwf_encounter_draw_enemy_name
begin_locals
    decl_local outgoing_args, 6
    decl_local string_ptr, 2                ; char near *
    decl_local enemy_index, 1               ; uint8
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local display_list_ptr, 2          ; char near *
    decl_local tiles_to_draw, 1             ; uint8
    decl_local current_tile_index, 1        ; char

ff6_tiles_to_draw     = $7e0010
ff6_display_list_ptr  = $7e0048
ff6_enemy_name_offset = $7e0026
ff6_enemy_name_table  = $cfc050

    enter __FRAME_SIZE__

    ; Initialize locals.
    sty dest_tilemap_offset
    a16
    lda ff6_display_list_ptr
    sta display_list_ptr
    a8
    lda #10
    sta tiles_to_draw

    a16
    inc display_list_ptr        ; Go to the next byte.
    a8
    lda (display_list_ptr)
    sta enemy_index
    a16
    and #$00ff
    asl
    tax
    lda ff6_encounter_enemy_ids,x   ; fetch enemy ID
    cmp #$ffff
    a8
    bne @name_not_empty

    ; Fill with blanks.
    inc tiles_to_draw
    ldx dest_tilemap_offset
:   txy                         ; dest_tilemap_offset
    ldx #$ffff                  ; space
    jsr _ff6vwf_encounter_draw_enemy_name_tile
    dec tiles_to_draw
    bne :-
    stx dest_tilemap_offset
    jmp @return

@name_not_empty:
    ; Compute string pointer.
    a16
    asl
    tax
    lda f:ff6vwf_long_enemy_names,x
    sta string_ptr
    a8

    ; Render string.
    lda #0
    sta outgoing_args+0                 ; 2bpp
    ldx enemy_index                     ; text_line_slot
    ldy string_ptr+0
    sty outgoing_args+1                 ; string_ptr+0
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+3                 ; string_ptr+2
    ldy #VWF_ENCOUNTER_TILE_BASE_ADDR
    jsr _ff6vwf_render_string

    ; Draw tiles.
    lda enemy_index
    a16
    and #$00ff
    tax
    a8
    lda f:ff6vwf_string_char_offsets,x  ; Compute start tile.
    sta current_tile_index
    ldx dest_tilemap_offset
:   txy                                 ; dest_tilemap_offset
    ldx current_tile_index              ; tile_to_draw
    jsr _ff6vwf_encounter_draw_enemy_name_tile
    inc current_tile_index
    dec tiles_to_draw
    bne :-

    ; Maybe the number of enemies in the J version got replaced with this?
    txy                     ; dest_tilemap_offset
    ldx #$ffff              ; tile_to_draw = space
    jsr _ff6vwf_encounter_draw_enemy_name_tile
    stx dest_tilemap_offset

@return:
    ; Put locals back where FF6 expects them.
    a16
    lda display_list_ptr
    sta ff6_display_list_ptr
    a8
    lda tiles_to_draw
    sta ff6_tiles_to_draw

    ldy dest_tilemap_offset
    leave __FRAME_SIZE__
    ; NB: It is important that the high byte of A be 0 upon return! FF6 will glitch otherwise.
    a16
    lda #0
    a8
    rtl
.endproc

.proc _ff6vwf_encounter_build_menu_item_for_item
    sta f:ff6vwf_encounter_current_item_slot
    pha
    lda #FF6VWF_ITEM_TYPE_INVENTORY
    sta f:ff6vwf_encounter_item_type_to_draw
    pla

    ; Stuff the original function did
    phy
    a16
    sta $40
    asli 2
    add $40
    tay
    jml $c14c76
.endproc

; Original function: $c14bba.
.proc _ff6vwf_encounter_build_menu_item_for_item_in_hand
.a8
    lda #0 
    sta f:ff6vwf_encounter_current_item_slot
    lda #FF6VWF_ITEM_TYPE_ITEM_IN_HAND
    sta f:ff6vwf_encounter_item_type_to_draw

    ; Stuff the original function did
    tdc
    tax
:   lda $c14bac,x
    sta $5755,x
    inx 
    cpx #$13
    bne :-
    jml $c14bc9
.endproc

; Original function: $c14bf7.
.proc _ff6vwf_encounter_build_menu_item_for_tools
.a8
    sta f:ff6vwf_encounter_current_item_slot
    pha
    lda #FF6VWF_ITEM_TYPE_TOOL
    sta f:ff6vwf_encounter_item_type_to_draw
    pla

    ; Stuff the original function did
    phy
    a16
    asl
    jml $c14bfb
.endproc

.proc _ff6vwf_encounter_draw_item_name
begin_locals
    decl_local outgoing_args, 7
    decl_local item_name_tiles, 3           ; chardata far *
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local tiles_to_draw, 1             ; uint8
    decl_local current_tile_index, 1        ; char
    decl_local item_slot, 1                 ; uint8
    decl_local item_id_ptr, 2               ; uint8 near *
    decl_local dest_tiles_main, 2           ; tiledata near *
    decl_local dest_tiles_extra, 2          ; tiledata near *
    decl_local item_id, 1                   ; uint8
    decl_local string_ptr, 2                ; char near *

ff6_dest_tiles_main         = $7e0053
ff6_dest_tiles_extra        = $7e0051
ff6_display_list_ptr        = $7e004f
ff6_item_in_hand_left       = $7e575a
ff6_item_in_hand_right      = $7e5760
ff6_tool_display_list_left  = $7e575a
ff6_tool_display_list_right = $7e5760

    enter __FRAME_SIZE__

    ; Initialize locals.
    sty dest_tilemap_offset
    lda #10
    sta tiles_to_draw
    a16
    lda ff6_display_list_ptr        ; 5A, 60, 62, 
    sta item_id_ptr
    lda ff6_dest_tiles_main
    sta dest_tiles_main
    lda ff6_dest_tiles_extra
    sta dest_tiles_extra

    ; Figure out what text slot we're going to use.
    a8
    lda ff6vwf_encounter_item_type_to_draw
    cmp #FF6VWF_ITEM_TYPE_ITEM_IN_HAND
    beq @item_in_hand
    cmp #FF6VWF_ITEM_TYPE_TOOL
    beq @tool

    ; Item in inventory. Use slot `item_slot % 5`, because the item menu shows 4 items, plus an
    ; extra that partially appears during scrolling.
    lda ff6vwf_encounter_current_item_slot
    a16
    and #$00ff
    a8
    tax
    ldy #5
    jsr _ff6vwf_mod16_8
    txa
    bra @write_item_slot

@item_in_hand:
    ; Item in hand:
    ldx item_id_ptr
    cpx #.loword(ff6_item_in_hand_right)
    beq :+
    lda #5                  ; Use slot 5 for left-hand item.
    bra @write_item_slot
:   lda #6                  ; Use slot 6 for right-hand item.
    bra @write_item_slot

@tool:
    lda ff6vwf_encounter_current_item_slot
    asl
    ldx item_id_ptr
    cpx #.loword(ff6_tool_display_list_left)
    beq @write_item_slot
    inc                     ; item slot * 2, plus one if this is the right column

@write_item_slot:
    sta item_slot

    ; Fetch item ID.
    lda (item_id_ptr)
    sta item_id

    ; Draw item icon.
    tax
    ldy #FF6_SHORT_ITEM_LENGTH
    jsr _ff6vwf_mul8
    lda ff6_short_item_names,x
    tax                     ; tile_to_draw
    ldy dest_tilemap_offset
    jsr _ff6vwf_encounter_draw_item_name_tile
    stx dest_tilemap_offset

    ; Compute string pointer.
    lda item_id
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_item_names,x
    sta string_ptr
    a8

    ; Render string.
    lda #0
    sta outgoing_args+0             ; 2bpp
    ldx item_slot
    ldy string_ptr
    sty outgoing_args+1             ; string
    lda #^ff6vwf_long_item_names
    sta outgoing_args+3             ; string bank byte
    ldy #VWF_ENCOUNTER_TILE_BASE_ADDR
    jsr _ff6vwf_render_string

    ; Draw tile data.
    lda item_slot
    a16
    and #$00ff
    tax
    a8
    lda f:ff6vwf_string_char_offsets,x  ; Compute start tile.
    sta current_tile_index
    ldx dest_tilemap_offset
:   txy                     ; dest_tilemap_offset
    lda current_tile_index
    inc current_tile_index
    tax                     ; tile_to_draw
    jsr _ff6vwf_encounter_draw_item_name_tile
    dec tiles_to_draw
    bne :-

    ; Add a couple of blank tiles on the end.
    lda #2
    sta tiles_to_draw
:   txy                     ; dest_tilemap_offset
    lda current_tile_index
    inc current_tile_index
    ldx #$ff                ; tile_to_draw
    jsr _ff6vwf_encounter_draw_item_name_tile
    dec tiles_to_draw
    bne :-
    stx dest_tilemap_offset

    ; Restore stuff to where FF6 expects it.
    a16
    lda dest_tiles_main
    sta ff6_dest_tiles_main
    lda dest_tiles_extra
    sta ff6_dest_tiles_extra
    a8
    ldy dest_tilemap_offset

    leave __FRAME_SIZE__
    rtl
.endproc

.proc _ff6vwf_encounter_draw_rage_name
begin_locals
    decl_local outgoing_args, 7
    decl_local enemy_name_tiles, 3          ; chardata far *
    decl_local dest_tilemap_offset, 2       ; uint16 (Y on entry to function)
    decl_local tiles_to_draw, 1             ; uint8
    decl_local current_tile_index, 1        ; char
    decl_local text_line_slot, 1            ; uint8
    decl_local enemy_id_ptr, 2              ; uint8 near *
    decl_local dest_tiles_main, 2           ; tiledata near *
    decl_local dest_tiles_extra, 2          ; tiledata near *
    decl_local enemy_id, 1                  ; uint8
    decl_local string_ptr, 2                ; char near *

ff6_dest_tiles_main         = $7e0053
ff6_dest_tiles_extra        = $7e0051
ff6_display_list_ptr        = $7e004f
ff6_item_in_hand_left       = $7e575a
ff6_item_in_hand_right      = $7e5760
ff6_rage_display_list_left  = $7e575a
ff6_rage_display_list_right = $7e5760

    enter __FRAME_SIZE__

    ; Initialize locals.
    sty dest_tilemap_offset
    lda #10
    sta tiles_to_draw
    a16
    lda f:ff6_display_list_ptr
    inc
    sta f:ff6_display_list_ptr
    sta enemy_id_ptr
    lda ff6_dest_tiles_main
    sta dest_tiles_main
    lda ff6_dest_tiles_extra
    sta dest_tiles_extra
    a8

    ; Figure out what text line slot we're going to use.
    lda f:ff6vwf_encounter_current_rage_slot
    a16
    and #$00ff
    tax
    a8
    ldy #5
    jsr _ff6vwf_mod16_8
    asl
    ldx enemy_id_ptr
    cpx #.loword(ff6_rage_display_list_left)
    beq :+
    inc
:   sta text_line_slot      ; (current_rage_slot % 5) * 2, plus one if it's the right column

    ; Fetch enemy ID.
    lda (enemy_id_ptr)
    sta enemy_id

    ; Compute string pointer.
    lda enemy_id
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_enemy_names,x
    sta string_ptr
    a8

    ; Render string.
    lda #0
    sta outgoing_args+0             ; 2bpp
    ldx text_line_slot
    ldy string_ptr
    sty outgoing_args+1             ; string
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+3             ; string bank byte
    ldy #VWF_ENCOUNTER_TILE_BASE_ADDR
    jsr _ff6vwf_render_string

    ; Draw tile data.
    lda text_line_slot
    a16
    and #$00ff
    tax
    a8
    lda f:ff6vwf_string_char_offsets,x  ; Compute start tile.
    sta current_tile_index
    ldx dest_tilemap_offset
:   txy                     ; dest_tilemap_offset
    lda current_tile_index
    inc current_tile_index
    tax                     ; tile_to_draw
    jsr _ff6vwf_encounter_draw_item_name_tile
    dec tiles_to_draw
    bne :-

    ; Add a blank tile on the end.
    txy                     ; dest_tilemap_offset
    lda current_tile_index
    inc current_tile_index
    ldx #$ff                ; tile_to_draw
    jsr _ff6vwf_encounter_draw_item_name_tile
    stx dest_tilemap_offset

    ; Restore stuff to where FF6 expects it.
    a16
    lda dest_tiles_main
    sta ff6_dest_tiles_main
    lda dest_tiles_extra
    sta ff6_dest_tiles_extra
    a8
    ldy dest_tilemap_offset

    leave __FRAME_SIZE__
    rtl
.endproc

; uint16 _ff6vwf_encounter_draw_enemy_name_tile(char tile, uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_enemy_name_tile
begin_locals
    decl_local dest_tilemap_main, 2     ; tiledata near * ($7e004c)
    decl_local dest_tilemap_extra, 2    ; tiledata near * ($7e004a)

ff6_dest_tilemap_main    = $7e004c
ff6_dest_tilemap_extra   = $7e004a
ff6_dest_tile_attributes = $7e004e

    enter __FRAME_SIZE__
    a16
    lda ff6_dest_tilemap_main
    sta dest_tilemap_main
    lda ff6_dest_tilemap_extra
    sta dest_tilemap_extra
    a8

    txa                             ; tile to draw
    sta (dest_tilemap_main),y
    lda #$ff
    sta (dest_tilemap_extra),y
    iny
    lda ff6_dest_tile_attributes
    sta (dest_tilemap_main),y
    sta (dest_tilemap_extra),y
    iny

    tyx
    leave __FRAME_SIZE__
    rts
.endproc

; uint16 _ff6vwf_encounter_draw_item_name_tile(char tile, uint16 dest_tilemap_offset)
.proc _ff6vwf_encounter_draw_item_name_tile
begin_locals
    decl_local dest_tilemap_main, 2     ; tiledata near * ($7e0053)
    decl_local dest_tilemap_extra, 2    ; tiledata near * ($7e0051)

ff6_dest_tilemap_main    = $7e0053
ff6_dest_tilemap_extra   = $7e0051
ff6_extra_tile           = $7e0055
ff6_dest_tile_attributes = $7e0056

    enter __FRAME_SIZE__
    a16
    lda ff6_dest_tilemap_main
    sta dest_tilemap_main
    lda ff6_dest_tilemap_extra
    sta dest_tilemap_extra
    a8

    txa                             ; tile_to_draw
    sta (dest_tilemap_main),y
    lda ff6_extra_tile
    sta (dest_tilemap_extra),y
    iny
    lda ff6_dest_tile_attributes
    sta (dest_tilemap_main),y
    sta (dest_tilemap_extra),y
    iny

    tyx
    leave __FRAME_SIZE__
    rts
.endproc

; For debugging
.export _ff6vwf_encounter_draw_enemy_name
.export _ff6vwf_encounter_build_menu_item_for_item
.export _ff6vwf_encounter_draw_item_name

; farproc void _ff6vwf_encounter_restore_small_font()
;
; A patched version of the "restore small font" function that reuploads the BG3 text from the ROM
; after a text box closes during an encounter. We simply to tell our custom NMI to reupload all the
; strings.
;
; FIXME(tachiweasel): This may need to upload more...
.proc _ff6vwf_encounter_restore_small_font
begin_locals
    decl_local outgoing_args, 1
    decl_local enemy_index, 1   ; uint8

ff6_dma_size_to_transfer = $10

    ; Do the stuff the original function did.
    ;
    ; Do this before the function prolog because we need the DP to be 0 when calling FF6 functions.
    ldx #$1000
    stx ff6_dma_size_to_transfer
    ldx #$7fc0      ; address of graphics in ROM
    ldy #$5800      ; VRAM address / 2
    lda #$c4        ; bank
    jsl _ff6vwf_encounter_schedule_dma_trampoline

    enter __FRAME_SIZE__

    ; Look at the monster names and schedule each one to be reuploaded if necessary.
    lda #0
    sta enemy_index
@reupload_enemy_name:
    lda enemy_index
    a16
    and #$00ff
    asl
    tax
    lda ff6_encounter_enemy_ids,x
    cmp #$ffff
    a8
    beq :+
    ldx enemy_index
    ldy #VWF_ENCOUNTER_TILE_BASE_ADDR
    lda #0
    sta outgoing_args+0     ; use_bpp4
    jsr _ff6vwf_schedule_text_dma
:   inc enemy_index
    lda enemy_index
    cmp #4      ; FIXME(tachiweasel): Probably should be *all* the strings...
    blt @reupload_enemy_name

    leave __FRAME_SIZE__
    ; NB: This is necessary to avoid a crash!
    a16
    lda #0
    a8
    rtl
.endproc

; Patch to the encounter DMA routine.
.proc _ff6vwf_encounter_run_dma
    ; Code that we overwrote.
    jsl $c2a88f

    ; Run our generic DMA routine.
    pha
    plb
    _ff6vwf_run_dma ff6vwf_encounter_text_tiles, ff6vwf_encounter_text_dma_stack_base, ff6vwf_encounter_text_dma_stack_ptr, 7
    tdc
    lda #$7e
    pha
    plb

    ; Tear down.
    jml $c10be1
.endproc

; Menu functions

.proc _ff6vwf_menu_init
    ; Stuff the original function did
    jsl $d4cdf3     ; Reset many vars

    ; Initialize the stack.
    lda #0
    sta f:ff6vwf_menu_text_dma_stack_ptr

    ; Return.
    jml $c368fe
.endproc

.proc _ff6vwf_menu_draw_equipment_name
begin_locals
    decl_local outgoing_args, 5
    decl_local item_id, 1
    decl_local string_ptr, 2
    decl_local text_line_slot, 1

ff6_menu_positioned_text_ptr    = $7e9e89

    tax             ; Put item ID in X

    enter __FRAME_SIZE__

    ; Initialize locals.
    txa
    sta item_id

    ; Draw item icon.
    tax
    ldy #FF6_SHORT_ITEM_LENGTH
    jsr _ff6vwf_mul8
    lda ff6_short_item_names,x
    sta ff6_menu_string_buffer

    ; Compute string pointer.
    lda item_id
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_item_names,x
    sta string_ptr

    ; Compute text line slot.
    ;
    ; Positioned text pointer -- L-Hand: $7a1b, R-Hand: $7a9b, Helmet: $7b1b, Armor: $7b9b.
    ; So extract bits 7 and 8 to get a unique text slot.
    lda f:ff6_menu_positioned_text_ptr
    asl
    xba
    and #$03
    tax                 ; For call below.
    a8
    sta text_line_slot

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; flags
    ldy string_ptr
    sty outgoing_args+1     ; string ptr
    lda #^ff6vwf_long_item_names
    sta outgoing_args+3     ; string ptr bank
    ldy #VWF_MENU_TILE_BG3_BASE_ADDR
    jsr _ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsl _ff6vwf_menu_force_nmi_trampoline 

    ; Calculate first tile index.
    lda text_line_slot
    a16
    and #$00ff
    tax
    a8
    lda f:ff6vwf_string_char_offsets,x  ; Compute start tile.

    ; Draw tiles.
    ldx #1
:   sta ff6_menu_string_buffer,x
    inc
    inx
    cpx #VWF_MAX_LINE_LENGTH + 1
    bne :-

    ; Draw blanks.
    lda #$ff
:   sta ff6_menu_string_buffer,x
    inx
    cpx #FF6_SHORT_ITEM_LENGTH
    bne :-

    ; Null terminate.
    lda #0
    sta ff6_menu_string_buffer,x

    leave __FRAME_SIZE__
    rtl
.endproc

; farproc void _ff6vwf_menu_draw_inventory_item_name()
.proc _ff6vwf_menu_draw_inventory_item_name
    lda f:ff6_menu_list_slot
    tax
    tay
    jsr _ff6vwf_menu_draw_item_name
    rtl
.endproc

; farproc void _ff6vwf_menu_draw_item_to_equip_name()
.proc _ff6vwf_menu_draw_item_to_equip_name
ff6_item_list = $7e9d8a

    lda f:ff6_menu_list_slot
    a16
    and #$00ff
    tax
    a8
    lda f:ff6_item_list,x
    txy
    tax
    jsr _ff6vwf_menu_draw_item_name
    tdc
    rtl
.endproc

; nearproc void _ff6vwf_menu_draw_item_name(uint8 item_id, uint8 menu_item_index)
;
; This function will automatically mod the menu item index by 10 to get the text string index.
;
; Setup function at $c37f88
; Scroll position is at $4a, top BG1 write row is at $49, item slot at $e5
.proc _ff6vwf_menu_draw_item_name
begin_locals
    decl_local outgoing_args, 5
    decl_local inventory_slot, 1
    decl_local item_id, 1
    decl_local string_ptr, 2
    decl_local text_line_slot, 1

ff6_inventory_ids = $7e1869

    enter __FRAME_SIZE__

    ; Initialize locals.
    tya
    sta text_line_slot
    txa
    sta inventory_slot

    ; Load item.
    a16
    and #$00ff
    tax
    a8
    lda f:ff6_inventory_ids,x
    sta item_id

    ; Draw item icon.
    tax
    ldy #FF6_SHORT_ITEM_LENGTH
    jsr _ff6vwf_mul8
    lda ff6_short_item_names,x
    sta ff6_menu_string_buffer

    ; Compute string pointer.
    lda item_id
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_item_names,x
    sta string_ptr
    a8

    ; Compute the actual text line slot by modding the one we were given by 10.
    lda text_line_slot
    a16
    and #$00ff
    tax
    a8
    ldy #10
    jsr _ff6vwf_mod16_8
    txa
    sta text_line_slot

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP | FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; flags
    ldx text_line_slot
    ldy string_ptr
    sty outgoing_args+1
    lda #^ff6vwf_long_item_names
    sta outgoing_args+3
    ldy #VWF_MENU_TILE_BG1_BASE_ADDR
    jsr _ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsl _ff6vwf_menu_force_nmi_trampoline 

    ; Calculate first tile index.
    lda text_line_slot
    a16
    and #$00ff
    tax
    a8
    lda f:ff6vwf_string_char_offsets,x  ; Compute start tile.

    ; Draw tiles.
    ldx #1
:   sta ff6_menu_string_buffer,x
    inc
    inx
    cpx #VWF_MAX_LINE_LENGTH + 1
    bne :-

    ; Draw blanks.
    lda #$ff
:   sta ff6_menu_string_buffer,x
    inx
    cpx #FF6_SHORT_ITEM_LENGTH
    bne :-

    ; Null terminate.
    lda #0
    sta ff6_menu_string_buffer,x

    leave __FRAME_SIZE__
    rts
.endproc

.export _ff6vwf_menu_draw_item_name ; for debugging

.proc _ff6vwf_encounter_build_menu_item_for_rage
    sta f:ff6vwf_encounter_current_rage_slot    ; from $c15945

    ; Stuff the original function did that we overwrote.
    phy
    asl
    tay
    tdc
    jmp $c14ce6
.endproc

.proc _ff6vwf_menu_draw_rage_name
begin_locals
    decl_local outgoing_args, 5
    decl_local enemy_id, 1
    decl_local string_ptr, 2
    decl_local text_line_slot, 1

ff6_rage_list = $7e9d89

    enter __FRAME_SIZE__

    ; Look up enemy ID.
    lda f:ff6_menu_list_slot
    sta text_line_slot
    a16
    and #$00ff
    tax
    a8
    lda f:ff6_rage_list,x
    sta enemy_id

    ; Compute string pointer.
    lda enemy_id
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_enemy_names,x
    sta string_ptr

    ; Compute text line slot.
    lda text_line_slot
    a16
    and #$00ff
    tax
    a8
    ldy #9                  ; Number of menu items on screen plus one.
    jsr _ff6vwf_mod16_8
    sta text_line_slot

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP | FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; 4bpp
    ldy string_ptr
    sty outgoing_args+1     ; string ptr
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+3     ; string ptr bank
    ldy #VWF_MENU_TILE_BG1_BASE_ADDR
    ldx text_line_slot
    jsr _ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsl _ff6vwf_menu_force_nmi_trampoline 

    ; Calculate first tile index.
    lda text_line_slot
    a16
    and #$00ff
    tax
    a8
    lda f:ff6vwf_string_char_offsets,x  ; Compute start tile.

    ; Draw tiles.
    ldx #0
:   cpx #FF6_SHORT_ENEMY_NAME_LENGTH
    beq :+
    sta ff6_menu_string_buffer,x
    inc
    inx
    bra :-
:

    ; Null terminate.
    lda #0
    sta ff6_menu_string_buffer,x

    leave __FRAME_SIZE__
    rtl
.endproc

.proc _ff6vwf_menu_draw_colosseum_item
begin_locals
    decl_local outgoing_args, 5
    decl_local item_id, 1
    decl_local string_ptr, 2
    decl_local text_line_slot, 1
    decl_local tilemap_position, 2

    tay                     ; Save item in Y.
    enter __FRAME_SIZE__

    ; Initialize locals.
    tya
    sta item_id
    stx tilemap_position

    ; Draw item icon.
    ldx item_id
    ldy #FF6_SHORT_ITEM_LENGTH
    jsr _ff6vwf_mul8
    lda ff6_short_item_names,x
    sta ff6_menu_string_buffer

    ; Compute string pointer.
    lda item_id
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_item_names,x
    sta string_ptr
    a8

    ; Determine a text line slot.
    lda tilemap_position+0
    cmp #$0d            ; Is it the prize (tilemap address $790d)?
    beq :+
    lda #0
    bra :++
:   lda #1
:   sta text_line_slot

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; flags
    ldx text_line_slot
    ldy string_ptr
    sty outgoing_args+1
    lda #^ff6vwf_long_item_names
    sta outgoing_args+3
    ldy #VWF_MENU_TILE_BG3_BASE_ADDR
    jsr _ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsl _ff6vwf_menu_force_nmi_trampoline 

    ; Calculate first tile index.
    lda text_line_slot
    a16
    and #$00ff
    tax
    a8
    lda f:ff6vwf_string_char_offsets,x  ; Compute start tile.

    ; Draw tiles.
    ldx #1
:   sta ff6_menu_string_buffer,x
    inc
    inx
    cpx #VWF_MAX_LINE_LENGTH + 1
    bne :-

    ; Draw blanks.
    lda #$ff
:   sta ff6_menu_string_buffer,x
    inx
    cpx #FF6_SHORT_ITEM_LENGTH
    bne :-

    ; Null terminate.
    lda #0
    sta ff6_menu_string_buffer,x

    ; Save tilemap position where FF6 expects it.
    a16
    lda tilemap_position
    sta f:$7e9e89
    a8

    leave __FRAME_SIZE__
    rtl
.endproc

; This is the existing FF6 DMA setup during NMI for the menu, factored out into this bank to give
; us some space for a patch.
.proc _ff6vwf_menu_run_dma_setup
    stz $420c       ; Disable HDMA
    stz $420b       ; Disable DMA...
    lda $35         ; BG1 X-Pos LB
    sta $210d       ; Apply it now
    lda $36         ; BG1 X-Pos HB
    sta $210d       ; Apply it now
    lda $37         ; BG1 Y-Pos LB
    sta $210e       ; Apply it now
    lda $38         ; BG1 Y-Pos HB
    sta $210e       ; Apply it now
    lda $39         ; BG2 X-Pos LB
    sta $210f       ; Apply it now
    lda $3a         ; BG2 X-Pos HB
    sta $210f       ; Apply it now
    lda $3b         ; BG2 Y-Pos LB
    sta $2110       ; Apply it now
    lda $3c         ; BG2 Y-Pos HB
    sta $2110       ; Apply it now
    lda $3d         ; BG3 X-Pos LB
    sta $2111       ; Apply it now
    lda $3e         ; BG3 X-Pos HB
    sta $2111       ; Apply it now
    lda $3f         ; BG3 Y-Pos LB
    sta $2112       ; Apply it now
    lda $40         ; BG3 Y-Pos HB
    sta $2112       ; Apply it now
    rtl
.endproc

.proc _ff6vwf_menu_run_dma
    _ff6vwf_run_dma ff6vwf_menu_text_tiles, ff6vwf_menu_text_dma_stack_base, ff6vwf_menu_text_dma_stack_ptr, 0
    rtl
.endproc

.export _ff6vwf_menu_run_dma

; Utility functions specific to VWF

; nearproc void _ff6vwf_render_string(uint8 text_line_slot,
;                                     uint16 tile_base_addr,
;                                     uint8 flags,
;                                     char far *string_ptr)
;
; Flags are the `FF6VWF_DMA_SCHEDULE_FLAGS_`.
.proc _ff6vwf_render_string
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
    jsr _ff6vwf_mul16_8
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
    jsr _ff6vwf_mul16_8
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
    jsr _ff6vwf_memset

    ; Schedule the upload.
    ldx text_line_slot
    ldy tile_base_addr
    lda flags
    sta outgoing_args+0
    jsr _ff6vwf_schedule_text_dma

    leave __FRAME_SIZE__
    rts
.endproc

.export _ff6vwf_render_string

; nearproc void _ff6vwf_schedule_text_dma(uint8 text_line_index,
;                                         uint16 tile_base_addr,
;                                         uint8 flags)
;
; Flags are the `FF6VWF_DMA_SCHEDULE_FLAGS_`.
.proc _ff6vwf_schedule_text_dma
begin_locals
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

    ; Grab the DMA stack pointer and bump it. If it overflows, bail out to avoid crashing the game.
    ; FIXME(tachiweasel): This seems racy...
    lda flags
    and #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    bne @get_menu_dma_stack_pointer

    ; Encounter path for the above
    lda #^ff6vwf_encounter_text_dma_stack_base
    sta dma_stack_ptr+2
    lda f:ff6vwf_encounter_text_dma_stack_ptr
    a16
    and #$00ff
    add #.loword(ff6vwf_encounter_text_dma_stack_base)
    sta dma_stack_ptr
    a8
    lda f:ff6vwf_encounter_text_dma_stack_ptr
    add #FF6VWF_DMA_STRUCT_SIZE
    cmp #VWF_ENCOUNTER_SLOT_COUNT * FF6VWF_DMA_STRUCT_SIZE
    blt :+
    jmp @out
:   sta f:ff6vwf_encounter_text_dma_stack_ptr
    bra @done_dma_stack_pointer

    ; Menu path for the above
@get_menu_dma_stack_pointer:
    lda #^ff6vwf_menu_text_dma_stack_base
    sta dma_stack_ptr+2
    lda f:ff6vwf_menu_text_dma_stack_ptr
    a16
    and #$00ff
    add #.loword(ff6vwf_menu_text_dma_stack_base)
    sta dma_stack_ptr
    a8
    lda f:ff6vwf_menu_text_dma_stack_ptr
    add #FF6VWF_DMA_STRUCT_SIZE
    cmp #VWF_MENU_SLOT_COUNT * FF6VWF_DMA_STRUCT_SIZE
    blt :+
    jmp @out
:   sta f:ff6vwf_menu_text_dma_stack_ptr

    ; Look up string char offset for the text line.
@done_dma_stack_pointer:
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
    jsr _ff6vwf_mul8
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
    jsr _ff6vwf_mul16_8
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

@out:
    leave __FRAME_SIZE__
    rts
.endproc

; General functions

; nearproc void _ff6vwf_memset(uint8 value, uint16 count, far void *ptr)
.proc _ff6vwf_memset
begin_locals
    decl_local count, 2
begin_args_nearcall
    decl_arg ptr, 3

    enter __FRAME_SIZE__

    sty count
    txa

    ; TODO(tachiweasel): Use the block move instruction.
    ldy #0
    bra :+
@loop:
    sta [ptr],y
    iny
:   cpy count
    bne @loop

    leave __FRAME_SIZE__
    rts
.endproc

; nearproc uint16 _ff6vwf_mul8(uint8 a, uint8 b)
.proc _ff6vwf_mul8
    txa
    sta f:WRMPYA
    tya
    sta f:WRMPYB

    ; 8 cycle delay
    nopx 3
    a16

    lda f:RDMPYL
    tax
    a8
    rts
.endproc

; nearproc uint16 _ff6vwf_mul16_8(uint16 a, uint8 b)
;   hi(BC)
;   A         B
; x           C
; ------------------
;   AC+hi(BC) lo(BC)

; let d = b * lo8(a)
; let e = (b*hi8(a) + hi8(d)) << 8
; lo8(d) + e
.proc _ff6vwf_mul16_8
begin_locals
    decl_local tmp_d, 2

    enter __FRAME_SIZE__

    tya
    sta f:WRMPYA    ; b
    txa
    sta f:WRMPYB    ; multiply by lo8(a)
    nopx 3
    a16             ; 8 cycle delay
    lda f:RDMPYL    ; a = d = b * lo8(a)
    sta tmp_d
    txa             ; A = a
    xba             ; lo8(A) = hi8(a)
    a8
    sta f:WRMPYB    ; multiply by hi8(a)
    nopx 2
    lda tmp_d       ; lo8(d)
    xba             ; 8 cycle delay; hi8(A) = lo8(d)
    lda f:RDMPYL    ; b*hi8(a)
    add tmp_d+1     ; b*hi8(a) + hi8(d)
    xba             ; swap high and low bytes; high is now b*hi8(a) + hi8(d); low is now lo8(d)
    a16
    tax
    a8

    leave __FRAME_SIZE__
    rts
.endproc

; nearproc uint16 _ff6vwf_mod16_8(uint16 a, uint8 b)
;
; Computes a % b.
.proc _ff6vwf_mod16_8
    txa
    sta f:WRDIVL
    xba
    sta f:WRDIVH
    tya
    sta f:WRDIVB

    ; 16 cycle delay
.repeat 7
    nop
.endrepeat
    a16

    lda f:RDMPYL
    tax
    a8
    rts
.endproc

; For debugging
.export _ff6vwf_encounter_run_dma
.export _ff6vwf_memset

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

.include "enemy-names.inc"
.include "item-names.inc"
