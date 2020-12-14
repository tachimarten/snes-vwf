; snes-vwf/ff6/ff6.s
;
; Final Fantasy 6 base ROM

.segment "BASETEXT"

; Original Final Fantasy 6 (US) ROM
.incbin "ff6.smc"

; Expand to 32Mbit
.repeat $100000/$8000
.res $8000, 0
.endrepeat

.segment "PTEXTHEADER"

.byte "FINAL FANTASY 3      "   ; name
.byte $31                       ; map mode
.byte $02                       ; ROM type
.byte $0C                       ; ROM size
.byte $03                       ; SRAM size
.byte $01                       ; destination code
.byte $33                       ; magic
.byte $00                       ; version
.word $A0CD                     ; checksum complement
.word $5F32                     ; checksum
