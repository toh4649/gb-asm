rgbasm -oblank.obj blank.z80
rgblink -oblank.gb blank.obj
rgbfix -p0 -v blank.gb
rm blank.obj