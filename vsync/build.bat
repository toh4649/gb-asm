rgbasm -ovsync.obj vsync.asm
rgblink -ovsync.gb vsync.obj
rgbfix -p0 -v vsync.gb
rm vsync.obj