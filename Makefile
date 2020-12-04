AS65?=ca65
LD65?=ld65

all:	demo.smc

demo.smc:	demo.o vwf.o demo.cfg
	$(LD65) -C demo.cfg -o $@ -m demo.map -vm demo.o vwf.o

%.o:	%.s
	$(AS65) -o $@ $<

vwf.o:	font.inc snes.inc

font.inc:	gen-font.rb font.tga
	./gen-font.rb font.tga > $@

ff6vwf.smc:	ff6vwf.o vwf.o ff6vwf.cfg ff6.smc
	$(LD65) -C ff6vwf.cfg -o $@ -m ff6vwf.map -vm ff6vwf.o vwf.o

ff6vwf.o:	font.inc snes.inc enemy-names.inc

.PHONY:	clean ff6

clean:
	rm -f *.o demo.smc ff6vwf.smc

ff6:	ff6vwf.smc
