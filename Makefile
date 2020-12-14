AS65?=ca65
LD65?=ld65
ASFLAGS?=

all:	demo.smc

demo.smc:	demo.o vwf.o demo.cfg
	$(LD65) -C demo.cfg -o $@ -m demo.map -vm demo.o vwf.o

%.o:	%.s
	$(AS65) $(ASFLAGS) -o $@ $<

stdsnes.o:	snes.inc

vwf.o:	font.inc snes.inc

ff6.o:	ff6.s ff6.smc

ff6twue.o:	ff6twue.s ff6twue.smc

font.inc:	gen-font.rb font.tga
	./gen-font.rb font.tga > $@

enemy-names.inc:	encode-enemy-names.rb ff6.tbl enemies.csv
	./encode-enemy-names.rb enemies.csv ff6.tbl > enemy-names.inc

item-names.inc:	encode-item-names.rb items.csv
	./encode-item-names.rb items.csv > item-names.inc

FF6VWF_OBJS=ff6vwf.o vwf.o stdsnes.o

ff6vwf.smc:	ff6.o $(FF6VWF_OBJS) ff6vwf.cfg
	$(LD65) -C ff6vwf.cfg -o $@ -m ff6vwf.map -vm $(FF6VWF_OBJS) $<

ff6twuevwf.smc:	ff6twue.o $(FF6VWF_OBJS) ff6vwf.cfg
	$(LD65) -C ff6vwf.cfg -o $@ -m ff6vwf.map -vm $(FF6VWF_OBJS) $<

ff6vwf.o:	font.inc snes.inc enemy-names.inc item-names.inc

.PHONY:	clean ff6

clean:
	rm -f *.o demo.smc ff6vwf.smc

ff6:	ff6vwf.smc
