; snes-vwf/ff6/shop.s
;
; Final Fantasy 6 variable-width font patches specific to the shop (bank $c3)

.p816
.i16
.a8
.feature c_comments

.include "ff6.inc"
.include "../snes.inc"

; Imports

.import ff6vwf_menu_draw_item_name_bg3
.import ff6vwf_menu_render_static_strings
.import ff6vwf_render_string
.import std_mod16_8
.import std_mul8

; Constants
SHOP_STATIC_STRING_COUNT = 5
SHOP_TITLE_STRING_COUNT = 5
SHOP_MESSAGE_STRING_COUNT = 7
BUY_STATIC_STRING_COUNT = 3
BUY_QUANTITY_STATIC_STRING_COUNT = 3
SELL_STATIC_STRING_COUNT = 4
SELL_QUANTITY_STATIC_STRING_COUNT = 3

SHOP_FIRST_GIL_TILE         = 80
SHOP_FIRST_TITLE_TILE       = 82
SHOP_FIRST_MESSAGE_TILE     = 89
SHOP_FIRST_SPECIFIC_TILE    = 104

SHOP_MESSAGE_TILE_COUNT = 15

; Patches

.segment "PTEXTMENUDRAWSHOPMENU"                ; $c3b93f
    jsl _ff6vwf_menu_draw_shop
    nopx 2

.segment "PTEXTMENUSHOPTITLETEXT"               ; $c3c00c
.repeat 6
    .addr .loword(ff6_menu_shop_positioned_text)
.endrepeat

.segment "PTEXTMENURETURNTOSHOPMENU"            ; $c3b781
    jsl _ff6vwf_menu_draw_shop
    nopx 2

.segment "PTEXTMENUDRAWSHOPBUYMENU"             ; $c3b992
    jsl _ff6vwf_menu_draw_shop_buy

.segment "PTEXTMENUDRAWSHOPBUYQUANTITYMENU"     ; $c3b867
    jsl _ff6vwf_menu_draw_shop_buy_quantity
    nopx 2

.segment "PTEXTMENUDRAWSHOPATTACKDEFENSE"       ; $c3bafe
    jsl _ff6vwf_menu_draw_shop_attack_defense

.segment "PTEXTMENUBUYHAVETOOMANY"              ; $c3b847
    jsl _ff6vwf_menu_buy_have_too_many
    nopx 2

.segment "PTEXTMENUBUYDUPETOOL"                 ; $c3b801
    jsl _ff6vwf_menu_buy_dupe_tool
    nopx 2

.segment "PTEXTMENUBUYCANTAFFORD"               ; $c3b826
    jsl _ff6vwf_menu_buy_cant_afford
    nopx 2

.segment "PTEXTMENUBUYTHANKS"                   ; $c3b605
    jsl _ff6vwf_menu_buy_sell_thanks
    nopx 2

.segment "PTEXTMENUDRAWSHOPSELLMENU"            ; $c3b7db
    jsl _ff6vwf_menu_draw_shop_sell
    nopx 2

.segment "PTEXTMENUDRAWSHOPSELLQUANTITYMENU"    ; $c3b665
    jsl _ff6vwf_menu_draw_shop_sell_quantity
    nopx 2

.segment "PTEXTMENUSELLTHANKS"                  ; $c3b743
    jsl _ff6vwf_menu_buy_sell_thanks
    nopx 2

.segment "PTEXTMENUDRAWITEMTOBUY"           ; $c3b9bd
    jsl _ff6vwf_menu_draw_item_to_buy       ; 4 bytes
    nopx 2

.segment "PTEXTMENUDRAWITEMTOSELL"          ; $c3badf
    jsl _ff6vwf_menu_draw_item_to_sell      ; 4 bytes
    nopx 2

.segment "PTEXTMENUDRAWITEMNAMEINSTATSSUBMENU"          ; $c3b9bd
    jml _ff6vwf_menu_draw_item_name_in_stats_submenu    ; 4 bytes
    nopx 2
_ff6vwf_menu_draw_item_name_in_stats_submenu_after:

; Our own functions, in a separate bank
.segment "TEXT"

; farproc void _ff6vwf_menu_draw_item_to_buy()
;
; Draws an item for sale, in the "buy" menu in shops.
.proc _ff6vwf_menu_draw_item_to_buy
begin_locals
    decl_local item_id, 1

ff6_menu_item_for_sale = $7e00f1

    tax     ; Save item ID in X.
    enter __FRAME_SIZE__, STACK_LIMIT

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
    txy                 ; text_line_slot
    ldx item_id
    jsr ff6vwf_menu_draw_item_name_bg3

    leave __FRAME_SIZE__
    ply
    pla
    phy                             ; Remove bank byte
    jml ff6_menu_draw_string
.endproc

; farproc void _ff6vwf_menu_draw_item_to_sell()
;
; Draws an item the PCs want to sell, in the "sell" menu in shops.
.proc _ff6vwf_menu_draw_item_to_sell
begin_locals
    decl_local item_id, 1

ff6_menu_item_for_sale = $7e00f1

    tax     ; Save item ID in X.
    enter __FRAME_SIZE__, STACK_LIMIT

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
    txy                 ; text_line_slot
    ldx item_id
    jsr ff6vwf_menu_draw_item_name_bg3

    ; Stuff the original function did:
    leave __FRAME_SIZE__
    ply
    pla
    phy                                 ; Remove bank byte
    jml ff6_menu_draw_string
.endproc

; Draws the item name in the statistics subscreen of the "buy" menu in shops.
;
; This doesn't really follow a calling convention, since it's more of a patch than a function.
.proc _ff6vwf_menu_draw_item_name_in_stats_submenu
ff6_menu_item_for_sale = $7e00f1

    tax     ; Save item ID in X.

    ; Draw item.
    ldy #0
    jsr ff6vwf_menu_draw_item_name_bg3

    ; Return back to the caller.
    pea .loword(_ff6vwf_menu_draw_item_name_in_stats_submenu_after)-1
    jml ff6_menu_draw_string
.endproc

.proc _ff6vwf_menu_draw_shop
begin_locals
    decl_local outgoing_args, 4

ff6_shop_id = $7e0201

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Upload static strings.
    ldx #.loword(ff6vwf_shop_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_shop_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE  ; first_tile_id
    jsr ff6vwf_menu_render_static_strings

    ; Compute title pointer.
    lda f:ff6_shop_id   ; Shop ID
    tax
    ldy #9              ; Size of a shop structure
    jsr std_mul8
    lda f:$c47ac0,x     ; Look up shop flags
    and #$07            ; Get shop type
    a16
    and #$00ff
    dec                                             ; Valid shop IDs start at 1...
    asl
    tax
    lda f:ff6vwf_shop_title_labels,x
    sta outgoing_args+1                             ; string ptr
    a8

    ; Upload title.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0                             ; flags
    lda #^ff6vwf_shop_title_labels
    sta outgoing_args+3                             ; string ptr, bank byte
    ldy #7                                          ; max_tile_count
    ldx #FF6VWF_FIRST_TILE + SHOP_FIRST_TITLE_TILE  ; first_tile_id
    jsr ff6vwf_render_string

    leave __FRAME_SIZE__

    ; Stuff the original function did:
    ply
    pla
    phy                                         ; Remove bank byte
    ldy #.loword(ff6_menu_shop_greeting_text)   ; Text pointer
    jml ff6_menu_draw_banner_message            ; Draw greeting
.endproc

.proc _ff6vwf_menu_draw_shop_buy
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Upload static strings.
    ldx #.loword(ff6vwf_buy_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_buy_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE  ; first_tile_id
    jsr ff6vwf_menu_render_static_strings

    ; Stuff the original function did:
    a16
    lda #0
    sta $7e00f1
    a8

    leave __FRAME_SIZE__
    rtl
.endproc

.proc _ff6vwf_menu_draw_shop_buy_quantity
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Upload title.
    ldx #.loword(ff6vwf_buy_quantity_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_buy_quantity_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE
    jsr ff6vwf_menu_render_static_strings

    leave __FRAME_SIZE__

    ; Stuff the original function did:
    ply
    pla
    phy                                         ; Remove bank byte
    ldy #.loword(ff6_menu_shop_greeting_text)   ; Text pointer
    jml ff6_menu_draw_banner_message              ; Draw question
.endproc

; farproc void _ff6vwf_menu_draw_shop_attack_defense(uint16 item_properties_index)
.proc _ff6vwf_menu_draw_shop_attack_defense
begin_locals
    decl_local outgoing_args, 4
    decl_local item_properties_index, 2

ff6_item_properties = $d85000

    enter __FRAME_SIZE__, STACK_LIMIT

    stx item_properties_index

    ; Determine which string to display.
    lda f:ff6_item_properties,x
    and #$07
    cmp #1                      ; Is it a weapon?
    beq :+
    ldx #.loword(ff6vwf_shop_defense_string)
    bra :++
:   ldx #.loword(ff6vwf_shop_attack_string)
:

    ; Upload title.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0                                 ; flags
    stx outgoing_args+1                                 ; string_ptr
    lda #^ff6vwf_shop_attack_string
    sta outgoing_args+3                                 ; string_ptr, bank byte
    ldy #5                                              ; max_tile_count
    ldx #FF6VWF_FIRST_TILE+SHOP_FIRST_SPECIFIC_TILE+9   ; first tile ID
    jsr ff6vwf_render_string

    ; Stuff the original function did:
    ldx item_properties_index
    leave __FRAME_SIZE__
    lda f:ff6_item_properties,x
    rtl
.endproc

.proc _ff6vwf_menu_buy_have_too_many
begin_locals
    decl_local outgoing_args, 4

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Upload title.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0                                 ; flags
    ldx #.loword(ff6vwf_shop_buy_have_99_string)
    stx outgoing_args+1                                 ; string ptr
    lda #^ff6vwf_shop_buy_have_99_string
    sta outgoing_args+3                                 ; string ptr, bank byte
    ldy #SHOP_MESSAGE_TILE_COUNT                        ; max_tile_count
    ldx #FF6VWF_FIRST_TILE + SHOP_FIRST_MESSAGE_TILE    ; first_tile_id
    jsr ff6vwf_render_string

    leave __FRAME_SIZE__

    ; Stuff the original function did:
    ply
    pla
    phy                                         ; Remove bank byte
    ldy #.loword(ff6_menu_shop_greeting_text)   ; Text pointer
    jml ff6_menu_draw_banner_message              ; Draw message
.endproc

.proc _ff6vwf_menu_buy_dupe_tool
begin_locals
    decl_local outgoing_args, 4

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Upload title.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0                                 ; flags
    ldx #.loword(ff6vwf_shop_buy_dupe_tool_string)
    stx outgoing_args+1                                 ; string ptr
    lda #^ff6vwf_shop_buy_dupe_tool_string
    sta outgoing_args+3                                 ; string ptr, bank byte
    ldy #SHOP_MESSAGE_TILE_COUNT                        ; max_tile_count
    ldx #FF6VWF_FIRST_TILE + SHOP_FIRST_MESSAGE_TILE    ; first_tile_id
    jsr ff6vwf_render_string

    leave __FRAME_SIZE__

    ; Stuff the original function did:
    ply
    pla
    phy                                         ; Remove bank byte
    ldy #.loword(ff6_menu_shop_greeting_text)   ; Text pointer
    jml ff6_menu_draw_banner_message              ; Draw message
.endproc

.proc _ff6vwf_menu_buy_cant_afford
begin_locals
    decl_local outgoing_args, 4

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Upload title.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0                                 ; flags
    ldx #.loword(ff6vwf_shop_buy_cant_afford_string)
    stx outgoing_args+1                                 ; string ptr
    lda #^ff6vwf_shop_buy_cant_afford_string
    sta outgoing_args+3                                 ; string ptr, bank byte
    ldy #SHOP_MESSAGE_TILE_COUNT                        ; max_tile_count
    ldx #FF6VWF_FIRST_TILE + SHOP_FIRST_MESSAGE_TILE    ; first_tile_id
    jsr ff6vwf_render_string

    leave __FRAME_SIZE__

    ; Stuff the original function did:
    ply
    pla
    phy                                         ; Remove bank byte
    ldy #.loword(ff6_menu_shop_greeting_text)   ; Text pointer
    jml ff6_menu_draw_banner_message              ; Draw message
.endproc

.proc _ff6vwf_menu_buy_sell_thanks
begin_locals
    decl_local outgoing_args, 4

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Upload title.
    lda #FF6VWF_DMA_SCHEDULE_FLAGS_MENU
    sta outgoing_args+0                                 ; flags
    ldx #.loword(ff6vwf_shop_buy_sell_thanks_string)
    stx outgoing_args+1                                 ; string_ptr, bank byte
    lda #^ff6vwf_shop_buy_sell_thanks_string
    sta outgoing_args+3                                 ; string_ptr, bank byte
    ldy #SHOP_MESSAGE_TILE_COUNT                        ; max_tile_count
    ldx #FF6VWF_FIRST_TILE + SHOP_FIRST_MESSAGE_TILE    ; first_tile_id
    jsr ff6vwf_render_string

    leave __FRAME_SIZE__

    ; Stuff the original function did:
    ply
    pla
    phy                                         ; Remove bank byte
    ldy #.loword(ff6_menu_shop_greeting_text)   ; Text pointer
    jml ff6_menu_draw_banner_message            ; Draw message
.endproc

.proc _ff6vwf_menu_draw_shop_sell
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Upload title.
    ldx #.loword(ff6vwf_sell_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_sell_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE
    jsr ff6vwf_menu_render_static_strings

    leave __FRAME_SIZE__

    ; Stuff the original function did:
    ply
    pla
    phy                                         ; Remove bank byte
    ldy #.loword(ff6_menu_shop_greeting_text)   ; Text pointer
    jml ff6_menu_draw_banner_message              ; Draw message
.endproc

.proc _ff6vwf_menu_draw_shop_sell_quantity
begin_locals
    decl_local outgoing_args, 3

    enter __FRAME_SIZE__, STACK_LIMIT

    ; Upload title.
    ldx #.loword(ff6vwf_sell_quantity_static_text_descriptor)
    stx outgoing_args+0
    lda #^ff6vwf_sell_quantity_static_text_descriptor
    sta outgoing_args+2
    ldx #FF6VWF_FIRST_TILE
    jsr ff6vwf_menu_render_static_strings

    leave __FRAME_SIZE__

    ; Stuff the original function did:
    ply
    pla
    phy                                         ; Remove bank byte
    ldy #.loword(ff6_menu_shop_greeting_text)   ; Text pointer
    jml ff6_menu_draw_banner_message              ; Draw message
.endproc

; ROM data patches

.segment "PTEXTMENUSHOPPOSITIONEDTEXT"  ; $c3c2fc

; Positioned text for shop menu
ff6_menu_shop_positioned_text:
.word $790d
    def_static_text_tiles_z SHOP_FIRST_TITLE_TILE, 7, -1
.repeat $c326-$c305-1
    .byte 0
.endrepeat
.word $7a0f
    def_static_text_tiles   SHOP_FIRST_SPECIFIC_TILE+0, .strlen("BUY  "), 2
    def_static_text_tiles   SHOP_FIRST_SPECIFIC_TILE+2, .strlen("SELL  "), 2
    def_static_text_tiles_z SHOP_FIRST_SPECIFIC_TILE+4, .strlen("EXIT"), 2
    ;;     B  U    Y             S   E    L    L             E   X   I    T
    ;.byte 8, 9, $ff, $ff, $ff, 10, 11, $ff, $ff, $ff, $ff, 12, 13, 14, $ff, 0
.word $7a41
    def_static_text_tiles_z SHOP_FIRST_GIL_TILE, .strlen("GP"), -1
.word $7b2b
    def_static_text_tiles_z SHOP_FIRST_GIL_TILE, .strlen("GP"), -1
.word $7ab3
    def_static_text_tiles_z SHOP_FIRST_SPECIFIC_TILE+0, .strlen("Owned:"), 4
.word $7bb3
    def_static_text_tiles_z SHOP_FIRST_SPECIFIC_TILE+4, .strlen("Equipped:"), 5
.word $7b8f
    def_static_text_tiles_z SHOP_FIRST_SPECIFIC_TILE+9, .strlen("Bat Pwr"), -1
.word $7b8f
    def_static_text_tiles_z SHOP_FIRST_SPECIFIC_TILE+9, .strlen("Defense"), -1
.word $7ba5
    .byte $ff, 0
ff6_menu_shop_greeting_text:
.word $791f
    def_static_text_tiles_z SHOP_FIRST_MESSAGE_TILE, .strlen("Hi! Can I help you?"), 15
.word $791f
    def_static_text_tiles_z SHOP_FIRST_MESSAGE_TILE, .strlen("Help yourself!"), -1
.word $791f
    def_static_text_tiles_z SHOP_FIRST_MESSAGE_TILE, .strlen("How many?"), -1
.word $791f
    def_static_text_tiles_z SHOP_FIRST_MESSAGE_TILE, .strlen("Whatcha got?"), -1
.word $791f
    def_static_text_tiles_z SHOP_FIRST_MESSAGE_TILE, .strlen("How many?"), -1
.word $791f
    def_static_text_tiles_z SHOP_FIRST_MESSAGE_TILE, .strlen("Bye!          "), -1
.word $791f
    def_static_text_tiles_z SHOP_FIRST_MESSAGE_TILE, .strlen("You need more GP!"), -1
.word $791f
    def_static_text_tiles_z SHOP_FIRST_MESSAGE_TILE, .strlen("Too many!       "), -1
.word $791f
    def_static_text_tiles_z SHOP_FIRST_MESSAGE_TILE, .strlen("One's plenty! "), -1

; Constant data

.segment "DATA"

; Main shop menu

ff6vwf_shop_static_text_descriptor:
    .byte SHOP_STATIC_STRING_COUNT              ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU        ; DMA flags
    .faraddr ff6vwf_static_shop_labels          ; strings
    .faraddr ff6vwf_static_shop_tile_counts     ; tile counts
    .faraddr ff6vwf_static_shop_start_tiles     ; start tiles

ff6vwf_static_shop_labels:
    ff6vwf_def_pointer_array ff6vwf_static_shop_label, SHOP_STATIC_STRING_COUNT

ff6vwf_static_shop_tile_counts:
    .byte 2, 2, 3
    .byte SHOP_MESSAGE_TILE_COUNT, 2
ff6vwf_static_shop_start_tiles:
    .byte SHOP_FIRST_SPECIFIC_TILE+0, SHOP_FIRST_SPECIFIC_TILE+2, SHOP_FIRST_SPECIFIC_TILE+4
    .byte SHOP_FIRST_MESSAGE_TILE, SHOP_FIRST_GIL_TILE

ff6vwf_static_shop_label_0: .asciiz "Buy"
ff6vwf_static_shop_label_1: .asciiz "Sell"
ff6vwf_static_shop_label_2: .asciiz "Exit"
ff6vwf_static_shop_label_3: .asciiz "Welcome! May I help you?"
ff6vwf_static_shop_label_4: .asciiz "Gil"

; Buy menu

ff6vwf_buy_static_text_descriptor:
    .byte BUY_STATIC_STRING_COUNT               ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU        ; DMA flags
    .faraddr ff6vwf_static_buy_labels           ; strings
    .faraddr ff6vwf_static_buy_tile_counts      ; tile counts
    .faraddr ff6vwf_static_buy_start_tiles      ; start tiles

ff6vwf_static_buy_labels: ff6vwf_def_pointer_array ff6vwf_static_buy_label, BUY_STATIC_STRING_COUNT
ff6vwf_static_buy_tile_counts:
    .byte 4,                        5,                          SHOP_MESSAGE_TILE_COUNT
ff6vwf_static_buy_start_tiles:
    .byte SHOP_FIRST_SPECIFIC_TILE, SHOP_FIRST_SPECIFIC_TILE+4, SHOP_FIRST_MESSAGE_TILE

ff6vwf_static_buy_label_0: .asciiz "Owned:"
ff6vwf_static_buy_label_1: .asciiz "Equipped:"
ff6vwf_static_buy_label_2: .asciiz "What would you like to buy?"

; Buy quantity menu

ff6vwf_buy_quantity_static_text_descriptor:
    .byte BUY_QUANTITY_STATIC_STRING_COUNT              ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU                ; DMA flags
    .faraddr ff6vwf_static_buy_quantity_labels          ; strings
    .faraddr ff6vwf_static_buy_quantity_tile_counts     ; tile counts
    .faraddr ff6vwf_static_buy_quantity_start_tiles     ; start tiles

ff6vwf_static_buy_quantity_labels:
    ff6vwf_def_pointer_array ff6vwf_static_buy_quantity_label, BUY_QUANTITY_STATIC_STRING_COUNT
ff6vwf_static_buy_quantity_tile_counts:
    .byte 4, 5, SHOP_MESSAGE_TILE_COUNT
ff6vwf_static_buy_quantity_start_tiles:
    .byte SHOP_FIRST_SPECIFIC_TILE+0, SHOP_FIRST_SPECIFIC_TILE+4, SHOP_FIRST_MESSAGE_TILE

ff6vwf_static_buy_quantity_label_0: .asciiz "Owned:"
ff6vwf_static_buy_quantity_label_1: .asciiz "Equipped:"
ff6vwf_static_buy_quantity_label_2: .asciiz "How many are you buying?"

; Sell menu

ff6vwf_sell_static_text_descriptor:
    .byte SELL_STATIC_STRING_COUNT              ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU        ; DMA flags
    .faraddr ff6vwf_static_sell_labels          ; strings
    .faraddr ff6vwf_static_sell_tile_counts     ; tile counts
    .faraddr ff6vwf_static_sell_start_tiles     ; start tiles

ff6vwf_static_sell_labels:
    ff6vwf_def_pointer_array ff6vwf_static_sell_label, SELL_STATIC_STRING_COUNT
ff6vwf_static_sell_tile_counts:
    .byte 2, 2, 3
    .byte SHOP_MESSAGE_TILE_COUNT
ff6vwf_static_sell_start_tiles:
    .byte SHOP_FIRST_SPECIFIC_TILE+0, SHOP_FIRST_SPECIFIC_TILE+2, SHOP_FIRST_SPECIFIC_TILE+4
    .byte SHOP_FIRST_MESSAGE_TILE

ff6vwf_static_sell_label_0: .asciiz "Buy"
ff6vwf_static_sell_label_1: .asciiz "Sell"
ff6vwf_static_sell_label_2: .asciiz "Exit"
ff6vwf_static_sell_label_3: .asciiz "What would you like to sell?"

; Sell quantity menu

ff6vwf_sell_quantity_static_text_descriptor:
    .byte SELL_QUANTITY_STATIC_STRING_COUNT             ; count
    .byte FF6VWF_DMA_SCHEDULE_FLAGS_MENU                ; DMA flags
    .faraddr ff6vwf_static_sell_quantity_labels         ; strings
    .faraddr ff6vwf_static_sell_quantity_tile_counts    ; tile counts
    .faraddr ff6vwf_static_sell_quantity_start_tiles    ; start tiles

ff6vwf_static_sell_quantity_labels:
    ff6vwf_def_pointer_array ff6vwf_static_sell_quantity_label, SELL_QUANTITY_STATIC_STRING_COUNT
ff6vwf_static_sell_quantity_tile_counts:
    .byte 4, 5, SHOP_MESSAGE_TILE_COUNT
ff6vwf_static_sell_quantity_start_tiles:
    .byte SHOP_FIRST_SPECIFIC_TILE+0, SHOP_FIRST_SPECIFIC_TILE+4, SHOP_FIRST_MESSAGE_TILE

ff6vwf_static_sell_quantity_label_0: .asciiz "Owned:"
ff6vwf_static_sell_quantity_label_1: .asciiz "Equipped:"
ff6vwf_static_sell_quantity_label_2: .asciiz "How many are you selling?"

; Shop titles

ff6vwf_shop_title_labels: ff6vwf_def_pointer_array ff6vwf_shop_title_label, SHOP_TITLE_STRING_COUNT

ff6vwf_shop_title_label_0: .asciiz "Weapon Shop"
ff6vwf_shop_title_label_1: .asciiz "Armor Shop"
ff6vwf_shop_title_label_2: .asciiz "Item Shop"
ff6vwf_shop_title_label_3: .asciiz "Relic Shop"
ff6vwf_shop_title_label_4: .asciiz "Shop"

; Shop messages

ff6vwf_shop_buy_have_99_string:     .asciiz "You can't carry any more."
ff6vwf_shop_buy_dupe_tool_string:   .asciiz "You already have one."
ff6vwf_shop_buy_cant_afford_string: .asciiz "Sorry, you can't afford that."
ff6vwf_shop_buy_sell_thanks_string: .asciiz "Thanks!"

; Other shop strings

ff6vwf_shop_attack_string:  .asciiz "Attack"
ff6vwf_shop_defense_string: .asciiz "Defense"
