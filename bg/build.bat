rgbasm -obg.obj bg.asm
rgblink -obg.gb bg.obj
rgbfix -p0 -v bg.gb
rm bg.obj