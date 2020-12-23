AS65?=ca65
LD65?=ld65
ASFLAGS?=

FF6VWF_OBJS=\
	ff6/ff6vwf.o \
	ff6/encounter.o \
	ff6/menu.o \
	ff6/shop.o \
	ff6/items-menu.o \
	ff6/skills-menu.o \
	ff6/enemy-names.o \
	ff6/item-names.o \
	vwf.o \
	stdsnes.o

all:	demo.smc

demo.smc:	demo.o vwf.o demo.cfg
	$(LD65) -C demo.cfg -o $@ -m demo.map -vm demo.o vwf.o

%.o:	%.s
	$(AS65) $(ASFLAGS) -o $@ $<

stdsnes.o:	snes.inc

vwf.o:	font.inc snes.inc

ff6/ff6.o:	ff6/ff6.s ff6/ff6.smc

ff6/ff6twue.o:	ff6/ff6twue.s ff6/ff6twue.smc

ff6/ff6vwf.o:	font.inc snes.inc ff6/ff6.inc

ff6/encounter.o:	snes.inc ff6/ff6.inc

ff6/menu.o:	snes.inc ff6/ff6.inc

ff6/shop.o:	snes.inc ff6/ff6.inc

ff6/skills-menu.o:	snes.inc ff6/ff6.inc

ff6/items-menu.o:	snes.inc ff6/ff6.inc

font.inc:	gen-font.rb font.tga
	./gen-font.rb font.tga > $@

ff6/enemy-names.s:	ff6/encode-enemy-names.rb ff6/ff6.tbl ff6/enemies.csv
	ff6/encode-enemy-names.rb ff6/enemies.csv ff6/ff6.tbl > $@

ff6/item-names.s:	ff6/encode-item-names.rb ff6/items.csv
	ff6/encode-item-names.rb ff6/items.csv > $@

ff6/ff6vwf.smc:	ff6/ff6.o $(FF6VWF_OBJS) ff6/ff6vwf.cfg
	$(LD65) -C ff6/ff6vwf.cfg -o $@ -m ff6/ff6vwf.map -vm $(FF6VWF_OBJS) $<

ff6/ff6twuevwf.smc:	ff6/ff6twue.o $(FF6VWF_OBJS) ff6/ff6vwf.cfg
	$(LD65) -C ff6/ff6vwf.cfg -o $@ -m ff6/ff6twuevwf.map -vm $(FF6VWF_OBJS) $<

.PHONY:	clean ff6

clean:
	rm -f *.o demo.smc ff6/ff6vwf.smc ff6/ff6twuevwf.smc

ff6:	ff6/ff6vwf.smc
