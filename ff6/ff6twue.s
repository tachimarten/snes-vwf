; snes-vwf/ff6twue.s
;
; Final Fantasy 6 Ted Woolsey Uncensored ROM

.segment "BASETEXT"

; Patched, expanded Final Fantasy 6 Ted Woolsey Uncensored ROM
.incbin "ff6twue.smc"

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
