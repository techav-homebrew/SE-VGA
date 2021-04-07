# SE-VGA
Simple CPLD project to mirror the Mac SE video over VGA. No scaling is performed -- the Mac 512x342 video is displayed letterboxed (black borders) in a 640x480 frame.

Circuit uses a single AFT1508AS-100AU CPLD, 32kx8 15ns SRAM, and a 25.175MHz can oscillator, along with some passives.

Plugs into SE PDS slot and snoops writes to the frame buffer memory locations. Writes are cached and copied to VRAM.