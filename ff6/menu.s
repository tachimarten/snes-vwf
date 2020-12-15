; snes-vwf/ff6/menu.s
;
; Final Fantasy 6 variable-width font patches specific to the menu

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

.import ff6vwf_get_long_item_name: near
.import ff6vwf_render_string: near
.import ff6vwf_string_char_offsets: far
.import ff6vwf_long_blitz_names: far
.import ff6vwf_long_dance_names: far
.import ff6vwf_long_enemy_names: far
.import ff6vwf_long_item_names: far

; Constants

; Address in VRAM where characters begin, for BG1 on the menu.
VWF_MENU_TILE_BG1_BASE_ADDR = $a000
; Address in VRAM where characters begin, for BG3 on the menu.
VWF_MENU_TILE_BG3_BASE_ADDR = $c000

; FF6 globals

ff6_menu_null                   = $7e0000
ff6_menu_list_slot              = $7e00e5
ff6_menu_bg1_write_row          = $7e00e6
ff6_menu_src_ptr                = $7e00e7
ff6_menu_dest_ptr               = $7e00eb
ff6_menu_list                   = $7e9d89
ff6_menu_positioned_text_ptr    = $7e9e89
ff6_menu_string_buffer          = $7e9e8b

; FF6 functions

ff6_menu_draw_name      = $7fd9

; FF6-specific macros

; Declares a trampoline that allows our VWF code to call back to FF6.
.macro def_trampoline target
    phd
    pea $0
    pld
    jsr target
    pld
    rtl
.endmacro

.segment "BSS"

; Menu BSS
.org $7eb800

; Stack of DMA structures, just like the encounter ones.
ff6vwf_menu_text_dma_stack_base: .res FF6VWF_DMA_STRUCT_SIZE * VWF_MENU_SLOT_COUNT
; Buffer space for the lines of text, `VWF_MAX_LINE_LENGTH` each to be stored, ready to be uploaded
; to VRAM.
ff6vwf_menu_text_tiles: .res VWF_MAX_LINE_BYTE_SIZE_4BPP * VWF_MENU_SLOT_COUNT
; Current of the stack *in bytes*.
ff6vwf_menu_text_dma_stack_ptr: .res 1

ff6vwf_menu_bss_end:

.export ff6vwf_menu_text_dma_stack_base
.export ff6vwf_menu_text_tiles
.export ff6vwf_menu_text_dma_stack_ptr
.export ff6vwf_menu_bss_end

.reloc 

; Patches to Final Fantasy 6 functions

; Final Fantasy 6 menu patches

.segment "PTEXTMENUINIT"
    jml _ff6vwf_menu_init

.segment "PTEXTMENULOADEQUIPMENTNAME"
ff6_menu_trigger_nmi = $1368

    jsl _ff6vwf_menu_draw_equipment_name
    rts

; Let's put some trampolines here.
_ff6vwf_menu_force_nmi_trampoline:  def_trampoline ff6_menu_trigger_nmi
_ff6vwf_menu_compute_map_ptr_trampoline:    def_trampoline $809f
_ff6vwf_menu_move_blitz_tilemap_trampoline: def_trampoline $56bc

.export _ff6vwf_menu_force_nmi_trampoline

; FF6 routine to draw an item in the Item menu.
.segment "PTEXTMENUDRAWITEMNAME"
    jml _ff6vwf_menu_draw_inventory_item_name_for_item_menu   ; 4 bytes
    nopx 3

; FF6 routine to draw an item available to equip, in the Equip or Relic menus.
.segment "PTEXTMENUDRAWITEMTOEQUIPNAME"
    jsl _ff6vwf_menu_draw_item_to_equip_name        ; 4 bytes
    nopx 3                                          ; overwrite `jsr $c39d11`

; Part of the FF6 routine to draw "<item name> can be used by:". We currently display "Equipment"
; in a fixed-width font instead of the item name because we don't have enough space to display that
; string in memory yet.
.segment "PTEXTMENUDRAWGEARINFOTEXT"
    jml _ff6vwf_menu_draw_gear_info_text

.segment "PTEXTMENUINITRAGEMENU"
    stz $4a         ; List scroll: 0
    jsr $091f       ; Create scrollbar
    a16
    lda #$0066      ; V-Speed: 0.4 px
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
    jsl _ff6vwf_menu_draw_rage_name         ; 4 bytes
    nop

; FF6 Rage menu navigation data, patched to be 1 column
.segment "PTEXTMENURAGENAVDATA"
ff6_menu_rage_nav_data:
    .byte $01       ; Wraps horizontally
    .byte $00       ; Initial column
    .byte $00       ; Initial row
    .byte $01       ; 1 column
    .byte $08       ; 8 rows
ff6_menu_rage_cursor_data:
    .word $7418        ; Rage 1
    .word $8018        ; Rage 2
    .word $8C18        ; Rage 3
    .word $9818        ; Rage 4
    .word $A418        ; Rage 5
    .word $B018        ; Rage 6
    .word $BC18        ; Rage 7
    .word $C818        ; Rage 8

; Code imported from Ted Woolsey Uncensored Edition (hereafter TWUE) at $c355e4 to label Sabin's
; Blitzes in the menu.
;
; We import the code as-is in order to maintain compatibility with TWUE.
.segment "PTEXTMENUBUILDBLITZMENUTWUE"
ff6_menu_vertical_page_offset = $49

.proc ff6twue_build_blitz_menu
ff6_menu_build_blitz_list = $c3561b
ff6_menu_init_menu_pos = $c383f7

    jsr a:.loword(ff6_menu_build_blitz_list)
    jsr a:.loword(ff6_menu_init_menu_pos)
    stz <ff6_menu_list_slot
    inc <ff6_menu_bg1_write_row
    ldy #16
@loop:
    phy
    tya
    lsr
    lda #4
    bcc :+
    adc #13
:   tax
    jsr a:.loword(ff6vwf_menu_draw_blitz)
    inc <ff6_menu_list_slot
    lda #$e0
    trb <ff6_menu_bg1_write_row
    inc <ff6_menu_bg1_write_row
    ply
    jsl _ff6twue_menu_blitz_next_row        ; Implicitly decrements Y.
    bne @loop
    rts
.endproc

; At $c35614 in Ted Woolsey Uncensored Edition.
.proc _ff6twue_menu_blitz_compute_map_ptr
ff6_menu_compute_bg1_tilemap_a_pos = $c3809f
    dec
    ora #1                                          ; Make Y position odd.
    jmp .loword(ff6_menu_compute_bg1_tilemap_a_pos) ; Compute map pointer.
.endproc

; nearproc void ff6twue_build_tilemap(uint8 inreg(A) blitz_id)
.segment "PTEXTMENUBLITZBUILDTILEMAPTWUE"
.proc ff6twue_menu_blitz_build_tilemap
    jsl _ff6twue_menu_blitz_build_tilemap
    rts
.endproc

.segment "PTEXTMENUDRAWBLITZ"
ff6vwf_menu_draw_blitz:
    lda z:<ff6_menu_bg1_write_row
    jsr _ff6twue_menu_blitz_compute_map_ptr

.segment "PTEXTMENUDRAWDANCE"
    jsl _ff6vwf_menu_draw_dance
    rts

; Part of the FF6 function at $c38a0e.
.segment "PTEXTMENUDRAWITEMTOBEUSED"
    jsl _ff6vwf_menu_draw_item_to_be_used
    nopx 7

.segment "PTEXTMENUDRAWITEMFORSALE"
    jml _ff6vwf_menu_draw_item_for_sale     ; 4 bytes
    nopx 2
_ff6vwf_menu_draw_item_for_sale_after:

.segment "PTEXTMENUBUILDCOLOSSEUMITEMS"
    jml _ff6vwf_menu_build_colosseum_items  ; 4 bytes

.segment "PTEXTMENUDRAWCOLOSSEUMITEM"
    jsl _ff6vwf_menu_draw_colosseum_item    ; 4 bytes
    jmp ff6_menu_draw_name                  ; Draw item name.

.segment "PTEXTMENUDRAWCOLOSSEUMENEMY"
    jsl _ff6vwf_menu_draw_colosseum_enemy   ; 4 bytes
    jmp ff6_menu_draw_name                  ; Draw enemy name.

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

    tax             ; Put item ID in X.

    enter __FRAME_SIZE__

    ; Initialize locals.
    txa
    sta item_id

    ; Draw item icon.
    tax
    jsr _ff6vwf_menu_draw_item_icon

    ; Compute string pointer.
    ldx item_id
    jsr ff6vwf_get_long_item_name
    stx string_ptr

    ; Compute text line slot.
    ;
    ; Positioned text pointer -- L-Hand: $7a1b, R-Hand: $7a9b, Helmet: $7b1b, Armor: $7b9b.
    ; So extract bits 7 and 8 to get a unique text slot.
    a16
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
    jsr ff6vwf_render_string

    ; Upload it now.
    jsl _ff6vwf_menu_force_nmi_trampoline

    ; Draw tiles.
    ldx text_line_slot
    ldy #FF6_SHORT_ITEM_LENGTH
    lda #1
    sta outgoing_args+0
    jsr _ff6vwf_menu_draw_vwf_tiles

    leave __FRAME_SIZE__
    rtl
.endproc

; farproc void _ff6vwf_menu_draw_inventory_item_name_for_item_menu()
.proc _ff6vwf_menu_draw_inventory_item_name_for_item_menu
ff6_menu_draw_string = $c37fd9

    lda f:ff6_menu_list_slot
    tax
    tay
    jsr _ff6vwf_menu_draw_inventory_item_name

    pea $7fd6-1                 ; Return to $c37fd6.
    jml ff6_menu_draw_string
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
    jsr _ff6vwf_menu_draw_inventory_item_name
    tdc
    rtl
.endproc

; nearproc void _ff6vwf_menu_draw_inventory_item_name(uint8 inventory_slot, uint8 menu_item_index)
.proc _ff6vwf_menu_draw_inventory_item_name
    jsr _ff6vwf_menu_get_inventory_item_id
    jmp _ff6vwf_menu_draw_item_name_bg1
.endproc

.proc _ff6vwf_menu_get_inventory_item_id
ff6_inventory_ids = $7e1869

    a16
    txa
    and #$00ff
    tax
    a8
    lda f:ff6_inventory_ids,x
    tax
    rts
.endproc

.proc _ff6vwf_menu_draw_gear_info_text
    ldx #0
:   lda f:ff6vwf_string_equipment,x
    sta f:ff6_menu_string_buffer,x
    inx
    cpx #ff6vwf_string_equipment_end-ff6vwf_string_equipment
    bne :-

    pea $856a+6-1
    jml $c385ad
.endproc

; nearproc void _ff6vwf_menu_draw_item_name_bg1(uint8 item_id, uint8 menu_item_index)
;
; This function will automatically mod the menu item index by 11 to get the text string index.
;
; Setup function at $c37f88
; Scroll position is at $4a, top BG1 write row is at $49, item slot at $e5
.proc _ff6vwf_menu_draw_item_name_bg1
begin_locals
    decl_local outgoing_args, 5
    decl_local item_id, 1
    decl_local string_ptr, 2
    decl_local text_line_slot, 1

FF6_MENU_INVENTORY_ITEM_LENGTH  = 14

    enter __FRAME_SIZE__

    ; Initialize locals.
    tya
    sta text_line_slot
    txa
    sta item_id

    ; If empty, blank item name and quantity.
    cmp #$ff
    bne :+
    ldx #.loword(ff6_menu_string_buffer)
    stx outgoing_args+0             ; dest
    lda #^ff6_menu_string_buffer
    sta outgoing_args+2             ; dest bank
    ldx #$ff
    ldy #16
    jsr std_memset
    lda #0
    sta ff6_menu_string_buffer+16
    bra @out

    ; Draw item icon.
:   tax
    jsr _ff6vwf_menu_draw_item_icon

    ; Compute string pointer.
    ldx item_id
    jsr ff6vwf_get_long_item_name
    stx string_ptr

    ; Compute the actual text line slot by modding the one we were given by 11.
    lda text_line_slot
    a16
    and #$00ff
    tax
    a8
    ldy #11
    jsr std_mod16_8
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
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsr _ff6vwf_menu_force_nmi

    ; Draw tiles.
    ldx text_line_slot
    ldy #FF6_MENU_INVENTORY_ITEM_LENGTH
    lda #1
    sta outgoing_args+0
    jsr _ff6vwf_menu_draw_vwf_tiles

@out:
    leave __FRAME_SIZE__
    a16
    lda #0
    a8
    rts
.endproc

.export _ff6vwf_menu_draw_inventory_item_name ; for debugging

; nearproc void _ff6vwf_menu_draw_vwf_tiles(uint8 text_line_slot,
;                                           uint8 tile_count,
;                                           uint8 offset)
.proc _ff6vwf_menu_draw_vwf_tiles
begin_locals
    decl_local tile_count, 2
begin_args_nearcall
    decl_arg offset, 1

    enter __FRAME_SIZE__

    ; Initialize locals.
    tya
    a16
    and #$00ff
    sta tile_count
    a8

    ; Put offset in Y.
    lda offset
    a16
    and #$00ff
    tay

    ; Calculate first tile index.
    txa
    and #$00ff
    tax
    a8
    lda f:ff6vwf_string_char_offsets,x  ; Compute start tile.

    ; Draw tiles.
    tyx                             ; Put offset in X.
    ldy #VWF_MAX_LINE_LENGTH
:   sta ff6_menu_string_buffer,x
    inc
    inx
    dey
    bne :-

    ; Draw blanks.
    lda #$ff
:   cpx tile_count
    bge :+
    sta ff6_menu_string_buffer,x
    inx
    bra :-
:

    ; Null terminate.
    lda #0
    sta ff6_menu_string_buffer,x

    leave __FRAME_SIZE__
    rts
.endproc

.export _ff6vwf_menu_draw_vwf_tiles

; nearproc void _ff6vwf_menu_draw_attributed_vwf_tiles(uint8 text_line_slot,
;                                                      uint8 tile_count,
;                                                      uint8 attributes)
.proc _ff6vwf_menu_draw_attributed_vwf_tiles
begin_locals
    decl_local byte_count, 2
    decl_local current_tile, 1
begin_args_nearcall
    decl_arg attributes, 1

    enter __FRAME_SIZE__

    ; Initialize locals.
    tya
    a16
    and #$00ff
    asl
    sta byte_count
    a8

    ; Calculate first tile index.
    txa
    and #$00ff
    tax
    a8
    lda f:ff6vwf_string_char_offsets,x
    sta current_tile

    ; Draw tiles.
    ldx #0
    ldy #VWF_MAX_LINE_LENGTH
:   lda current_tile
    sta f:ff6_menu_string_buffer,x
    inc current_tile
    inx
    lda attributes
    sta f:ff6_menu_string_buffer,x
    inx
    dey
    bne :-

    ; Draw blanks.
    lda attributes
    xba
    lda #$ff
    a16
:   cpx byte_count
    bge :+
    sta f:ff6_menu_string_buffer,x
    inx
    inx
    bra :-
:   a8

    ; Null terminate.
    lda #0
    sta f:ff6_menu_string_buffer,x
    sta f:ff6_menu_string_buffer+1,x

    leave __FRAME_SIZE__
    rts
.endproc

; nearproc void _ff6vwf_menu_force_nmi()
;
; Just like FF6's "force NMI" routine at $c31368, but without messing with the force blank
; (INIDISP) settings. This allows us to wait for NMIs without turning the screen on, which might
; confuse FF6 and cause it to try to perform DMA with the screen on.
.proc _ff6vwf_menu_force_nmi
ff6_menu_nmi_requested    = $7e0024
ff6_menu_queued_hdma      = $7e0043
ff6_menu_mosaic           = $7e00b5
ff6_menu_allow_sfx_repeat = $7e00ae

    lda #$81                        ; Stop IRQ timers
    sta f:NMITIMEN                  ; On: NMI, joypads
    sta f:ff6_menu_nmi_requested    ; Mark NMI request
    cli                             ; Unmask IRQs
:   lda f:ff6_menu_nmi_requested    ; Back from NMI?
    bne :-                          ; Loop if not
    sei                             ; Mask IRQs
    lda f:ff6_menu_queued_hdma      ; Queued HDMA
    sta f:HDMAEN                    ; Update channels
    lda f:ff6_menu_mosaic           ; Mosaic settings
    sta f:MOSAIC                    ; Apply to screen
    lda #0
    sta f:ff6_menu_allow_sfx_repeat ; Allow SFX repeat
    rts
.endproc

.export _ff6vwf_menu_force_nmi

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
    jsr std_mod16_8
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
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsl _ff6vwf_menu_force_nmi_trampoline

    ; Draw tiles.
    ldx text_line_slot
    ldy #FF6_SHORT_ENEMY_NAME_LENGTH
    stz outgoing_args+0
    jsr _ff6vwf_menu_draw_vwf_tiles

    leave __FRAME_SIZE__
    rtl
.endproc

; farproc void _ff6vwf_menu_draw_blitz(uint8 blitz_id)
.proc _ff6vwf_menu_draw_blitz
begin_locals
    decl_local outgoing_args, 7
    decl_local blitz_id, 1          ; uint8
    decl_local string_ptr, 2        ; const char near *
    decl_local text_line_slot, 1    ; uint8

FF6TWUE_BLITZ_NAME_ATTRS = $24

    enter __FRAME_SIZE__

    ; Initialize locals.
    txa
    sta blitz_id

    ; Compute slot.
    lda f:ff6_menu_list_slot
    sta text_line_slot

    ; Compute string pointer.
    lda blitz_id
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_blitz_names,x
    sta string_ptr
    a8

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP | FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; 4bpp
    ldy string_ptr
    sty outgoing_args+1     ; string ptr
    lda #^ff6vwf_long_blitz_names
    sta outgoing_args+3     ; string ptr bank
    ldy #VWF_MENU_TILE_BG1_BASE_ADDR
    ldx text_line_slot
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsl _ff6vwf_menu_force_nmi_trampoline

    ; Draw tiles.
    ldx text_line_slot
    ldy #FF6_SHORT_BLITZ_NAME_LENGTH
    lda #FF6TWUE_BLITZ_NAME_ATTRS
    sta outgoing_args+0
    jsr _ff6vwf_menu_draw_attributed_vwf_tiles

    ; FIXME(tachiweasel): Fill with blanks if no Blitz here.
    leave __FRAME_SIZE__
    rtl
.endproc

.export _ff6vwf_menu_draw_blitz     ; For debugging.

; farproc void _ff6vwf_menu_draw_dance(uint8 tile_x_offset)
.proc _ff6vwf_menu_draw_dance
begin_locals
    decl_local outgoing_args, 3

ff6_menu_list           = $7e9d89

    enter __FRAME_SIZE__

    ; Save tile X offset.
    txy

    ; Check for dance in slot.
    lda f:ff6_menu_list_slot
    a16
    and #$00ff
    tax
    a8
    lda f:ff6_menu_list,x
    cmp #$ff
    beq @no_dance

    ; Draw dance name.
    ldx #.loword(ff6vwf_long_dance_names)
    stx outgoing_args+0
    tax                             ; X = blitz_id
    lda #^ff6vwf_long_blitz_names
    sta outgoing_args+2
    jsr _ff6vwf_menu_draw_blitz_or_dance_name

@no_dance:
    ; FIXME(tachiweasel): Fill with blanks if no dance here.
    leave __FRAME_SIZE__
    rtl
.endproc

; nearproc void _ff6vwf_menu_draw_blitz_or_dance_name(uint8 blitz_id,
;                                                     uint8 tile_x_offset,
;                                                     const char far *string_table)
.proc _ff6vwf_menu_draw_blitz_or_dance_name
begin_locals
    decl_local outgoing_args, 5
    decl_local string_ptr, 2        ; char near *
    decl_local tile_x_offset, 1
begin_args_nearcall
    decl_arg string_table, 3

    enter __FRAME_SIZE__

    ; Save tile X offset, and put Blitz ID in A.
    tya
    sta tile_x_offset
    txa

    ; Compute string pointer.
    a16
    and #$00ff
    asl
    tay
    lda [string_table],y
    sta string_ptr
    a8

    ; Compute map pointer.
    lda tile_x_offset
    a16
    and #$00ff
    tax
    a8
    lda f:ff6_menu_bg1_write_row
    jsl _ff6vwf_menu_compute_map_ptr_trampoline
    a16
    txa
    sta f:ff6_menu_positioned_text_ptr
    a8

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_4BPP | FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; 4bpp
    ldy string_ptr
    sty outgoing_args+1     ; string ptr
    lda #^ff6vwf_long_blitz_names
    sta outgoing_args+3     ; string ptr bank
    ldy #VWF_MENU_TILE_BG1_BASE_ADDR
    lda f:ff6_menu_list_slot
    tax
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsl _ff6vwf_menu_force_nmi_trampoline

    ; Draw tiles.
    lda f:ff6_menu_list_slot
    tax
    ldy #FF6_SHORT_BLITZ_NAME_LENGTH
    stz outgoing_args+0
    jsr _ff6vwf_menu_draw_attributed_vwf_tiles

    ; Move tilemap.
    a16
    lda #.loword(ff6_menu_positioned_text_ptr)
    sta f:ff6_menu_src_ptr+0
    a8
    lda #^ff6_menu_positioned_text_ptr
    sta f:ff6_menu_src_ptr+2
    jsl _ff6vwf_menu_move_blitz_tilemap_trampoline

    leave __FRAME_SIZE__
    rts
.endproc

; farproc void _ff6vwf_menu_draw_item_to_be_used()
;
; FIXME(tachiweasel): Cursor sprite disappears sometimes after calling this...
.proc _ff6vwf_menu_draw_item_to_be_used
TEXT_LINE_SLOT = 0

ff6_menu_cursor_selected_inventory_slot = $7e004b

    lda f:ff6_menu_cursor_selected_inventory_slot
    tax
    jsr _ff6vwf_menu_get_inventory_item_id

    ldy #TEXT_LINE_SLOT
    jsr _ff6vwf_menu_draw_item_name_bg3

    ; For some reason we have to do this to prevent the cursor from disappearing...
    a16
    lda #0
    a8
    ldx #0
    ldy #0

    rtl
.endproc

; Draws an item for sale, in the "buy" menu in shops.
;
; This doesn't really follow a calling convention, since it's more of a patch than a function.
.proc _ff6vwf_menu_draw_item_for_sale
begin_locals
    decl_local item_id, 1

ff6_menu_item_for_sale = $7e00f1

    tax     ; Save item ID in X.
    enter __FRAME_SIZE__

    ; Save item ID.
    txa
    sta item_id

    ; Compute the actual text line slot by modding the one we were given by 9.
    lda f:ff6_menu_item_for_sale
    a16
    and #$00ff
    tax
    a8
    ldy #9                  ; 8 slots, plus one.
    jsr std_mod16_8

    ; Draw item.
    ldx item_id
    txy                 ; text_line_slot
    jsr _ff6vwf_menu_draw_item_name_bg3

    ; Call the "upload text" function and have it return back into the "draw item for sale"
    ; function.
    leave __FRAME_SIZE__
    pea .loword(_ff6vwf_menu_draw_item_for_sale_after)-1
    jml $c37fd9
.endproc

; nearproc void _ff6vwf_menu_draw_item_name_bg3(uint8 item_id, uint8 text_line_slot)
.proc _ff6vwf_menu_draw_item_name_bg3
begin_locals
    decl_local outgoing_args, 5
    decl_local item_id, 1
    decl_local string_ptr, 2
    decl_local text_line_slot, 1

    enter __FRAME_SIZE__

    ; Initialize locals.
    txa
    sta item_id
    tya
    sta text_line_slot

    ; Draw item icon.
    ldx item_id
    jsr _ff6vwf_menu_draw_item_icon

    ; Compute string pointer.
    ldx item_id
    jsr ff6vwf_get_long_item_name
    stx string_ptr

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; flags
    ldx text_line_slot
    ldy string_ptr
    sty outgoing_args+1
    lda #^ff6vwf_long_item_names
    sta outgoing_args+3
    ldy #VWF_MENU_TILE_BG3_BASE_ADDR
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsr _ff6vwf_menu_force_nmi

    ; Draw tiles.
    ldx text_line_slot
    ldy #FF6_SHORT_ITEM_LENGTH
    lda #1
    sta outgoing_args+0
    jsr _ff6vwf_menu_draw_vwf_tiles

    leave __FRAME_SIZE__
    rts
.endproc

.proc _ff6vwf_menu_build_colosseum_items
    ; Stuff the original function did
    lda #1
    sta f:BG1SC
    jml $c3ad2c
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
    jsr _ff6vwf_menu_draw_item_icon

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

    ; Render string.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; flags
    ldx text_line_slot
    ldy string_ptr
    sty outgoing_args+1
    lda #^ff6vwf_long_item_names
    sta outgoing_args+3
    ldy #VWF_MENU_TILE_BG3_BASE_ADDR
    jsr ff6vwf_render_string

    ; Schedule an upload for later, or just upload now if we're in force blank.
    jsl _ff6vwf_menu_force_nmi_trampoline

    ; Draw tiles.
    ldx text_line_slot
    ldy #FF6_SHORT_ITEM_LENGTH
    lda #1
    sta outgoing_args+0
    jsr _ff6vwf_menu_draw_vwf_tiles

    ; Save tilemap position where FF6 expects it.
    a16
    lda tilemap_position
    sta f:ff6_menu_positioned_text_ptr
    a8

    leave __FRAME_SIZE__
    rtl
.endproc

; nearproc void _ff6vwf_menu_draw_item_icon(uint8 item_id)
.proc _ff6vwf_menu_draw_item_icon
    ldy #FF6_SHORT_ITEM_LENGTH
    jsr std_mul8
    lda ff6_short_item_names,x
    sta ff6_menu_string_buffer
    rts
.endproc

.proc _ff6vwf_menu_draw_colosseum_enemy
begin_locals
    decl_local outgoing_args, 5
    decl_local string_ptr, 2

ff6_menu_colosseum_opponent = $7e0206

TEXT_LINE_SLOT = 2

    enter __FRAME_SIZE__

    ; Compute string pointer.
    lda f:ff6_menu_colosseum_opponent
    a16
    and #$00ff
    asl
    tax
    lda f:ff6vwf_long_enemy_names,x
    sta string_ptr

    ; Render string.
    a8
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0     ; 4bpp
    ldy string_ptr
    sty outgoing_args+1     ; string ptr
    lda #^ff6vwf_long_enemy_names
    sta outgoing_args+3     ; string ptr bank
    ldy #VWF_MENU_TILE_BG3_BASE_ADDR
    ldx #TEXT_LINE_SLOT
    jsr ff6vwf_render_string

    ; Upload it now. (We won't get a chance later...)
    jsl _ff6vwf_menu_force_nmi_trampoline

    ; Draw tiles.
    ldx #TEXT_LINE_SLOT
    ldy #FF6_SHORT_ENEMY_NAME_LENGTH
    stz outgoing_args+0
    jsr _ff6vwf_menu_draw_vwf_tiles

    ; Store tilemap position.
    a16
    lda #$7c4f                          ; Tilemap ptr
    sta f:ff6_menu_positioned_text_ptr  ; Set position
    a8

    leave __FRAME_SIZE__
    rtl
.endproc

; This is the existing FF6 DMA setup during NMI for the menu, factored out into this bank to give
; us some space for a patch.
.proc _ff6vwf_menu_run_dma_setup
ff6_menu_bg1_xpos = $35
ff6_menu_bg1_ypos = $37
ff6_menu_bg2_xpos = $39
ff6_menu_bg2_ypos = $3b
ff6_menu_bg3_xpos = $3d
ff6_menu_bg3_ypos = $3f

    stz HDMAEN      ; Disable HDMA.
    stz MDMAEN      ; Disable DMA.
    lda ff6_menu_bg1_xpos+0
    sta BG1HOFS
    lda ff6_menu_bg1_xpos+1
    sta BG1HOFS
    lda ff6_menu_bg1_ypos+0
    sta BG1VOFS
    lda ff6_menu_bg1_ypos+1
    sta BG1VOFS
    lda ff6_menu_bg2_xpos+0
    sta BG2HOFS
    lda ff6_menu_bg2_xpos+1
    sta BG2HOFS
    lda ff6_menu_bg2_ypos+0
    sta BG2VOFS
    lda ff6_menu_bg2_ypos+1
    sta BG2VOFS
    lda ff6_menu_bg3_xpos+0
    sta BG3HOFS
    lda ff6_menu_bg3_xpos+1
    sta BG3HOFS
    lda ff6_menu_bg3_ypos+0
    sta BG3VOFS
    lda ff6_menu_bg3_ypos+1
    sta BG3VOFS
    rtl
.endproc

.proc _ff6vwf_menu_run_dma
    _ff6vwf_run_dma ff6vwf_menu_text_tiles, ff6vwf_menu_text_dma_stack_base, ff6vwf_menu_text_dma_stack_ptr, 0, 250
    rtl
.endproc

.proc _ff6vwf_menu_run_all_dma_now
    phd
    pea $00
    pld

@loop:
    _ff6vwf_run_dma_now ff6vwf_menu_text_tiles, ff6vwf_menu_text_dma_stack_base, ff6vwf_menu_text_dma_stack_ptr, 0
    bcs @loop

    pld
    rtl
.endproc

.export _ff6vwf_menu_run_dma

.proc _ff6twue_menu_blitz_next_row
    tya
    lsr
    bcc :+
    lsr
    bcc :+
    dec .loword(ff6_menu_list_slot)
    dec .loword(ff6_menu_list_slot)
:   tdc 
    dey
    rtl
.endproc

.proc _ff6twue_menu_blitz_build_tilemap
blitz_id = $e0
src_ptr = $e7
ff6_blitz_inputs = $c35c1c
ff6_blitz_input_tiles = $c47a40
ff6_short_blitz_names = $e6f831

    asl
    sta z:blitz_id      ; blitz_id *= 2
    lda <ff6_menu_bg1_write_row+0
    jsr _ff6twue_menu_blitz_55e4
    ldy #.loword(ff6_menu_string_buffer)
    sty WMADDL
    ldy #10
    lda z:blitz_id
    bcs draw_input

; $c35698:
@draw_blitz_name:
    lsr
    tax
    jsl _ff6vwf_menu_draw_blitz
    bra out

ff6twue_menu_move_blitz_tilemap:
    ldy <ff6_menu_null+0
    a16
    lda [<ff6_menu_src_ptr]
    sta <ff6_menu_dest_ptr
    inc <ff6_menu_src_ptr
    inc <ff6_menu_src_ptr
    a8
    lda #$7E
    sta <(ff6_menu_dest_ptr + 2)
@move_blitz_tilemap_loop:
    a16
    lda [<ff6_menu_src_ptr],Y
    beq move_blitz_tilemap_out
    sta [<ff6_menu_dest_ptr],Y
    a8
    iny 
    iny 
    bra @move_blitz_tilemap_loop
move_blitz_tilemap_out:
    a8
    rts 

draw_input:
    asl             
    sta z:blitz_id      ; blitz_id * 4
    asl
    adc z:blitz_id      ; blitz_id * 12
    ldx #(ff6_blitz_inputs >> 8)        ; this stomped on some important code!
    stx src_ptr+1
    tax 
@copy_blitz_input_char:
    lda f:ff6_blitz_input_tiles,x    ; load Blitz input
    asl
    adc #<ff6_blitz_inputs      ; tile attributes for Blitz inputs
    sta src_ptr
    lda [src_ptr]
    sta WMDATA
    inc src_ptr
    lda [src_ptr]
    sta WMDATA
    inx 
    dey 
    bne @copy_blitz_input_char
    stz WMDATA
    stz WMDATA
out:
    rtl
.endproc

.proc _ff6twue_menu_blitz_55e4
    dec
    lsr
    eor z:ff6_menu_vertical_page_offset
    lsr
    rts 
.endproc

; Constant data

.segment "DATA"

ff6vwf_string_equipment:
    .byte 'E'-'A'+$80
    .byte 'q'-'a'+$80+26
    .byte 'u'-'a'+$80+26
    .byte 'i'-'a'+$80+26
    .byte 'p'-'a'+$80+26
    .byte 'm'-'a'+$80+26
    .byte 'e'-'a'+$80+26
    .byte 'n'-'a'+$80+26
    .byte 't'-'a'+$80+26
    .byte $ff
    .byte 0
ff6vwf_string_equipment_end:
