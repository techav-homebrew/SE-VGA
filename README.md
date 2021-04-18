# SE-VGA
Simple CPLD project to mirror the Mac SE video over VGA. No scaling is performed -- the Mac 512x342 video is displayed letterboxed (black borders) in a 640x480 frame.

Circuit uses a single AFT1508AS-100AU CPLD, 32kx8 15ns SRAM, and a 25.175MHz can oscillator, along with some passives.

Plugs into SE PDS slot and snoops writes to the frame buffer memory locations. Writes are cached and copied to VRAM.

The Mac SE primary framebuffer starts at 0x5900 below the top of RAM. Since it's not in a static location for every system, the system's memory configuration is needed. This is set by three ramSize jumpers, which mask CPU address bits 21, 20, 19. Not all possible ramSize selections are valid memory sizes when using 30-pin SIMMs in the Mac SE. In theory, these combinations could be possible when using PDS memory expansion cards, but this is unlikely. The chart below indicates the valid & invalid ramSize configurations and the corresponding installed SIMM combinations.

|ramSize|Framebuffer Start|RAM Top Address + 1|RAM Size|Installed SIMMs               |
|:-----:|:---------------:|:-----------------:|:------:|------------------------------|
| 111   | 0x3fa700        | $400000           | 4.0MB  | `[ 1MB   1MB ][ 1MB   1MB ]` |
| 110   | 0x37a700        | $380000           | 3.5MB  | Invalid combination          |
| 101   | 0x2fa700        | $300000           | 3.0MB  | Invalid combination          |
| 100   | 0x27a700        | $280000           | 2.5MB  | `[ 1MB   1MB ][256kB 256kB]` |
| 011   | 0x1fa700        | $200000           | 2.0MB  | `[ 1MB   1MB ][ ---   --- ]` |
| 010   | 0x17a700        | $180000           | 1.5MB  | Invalid combination          |
| 001   | 0x0fa700        | $100000           | 1.0MB  | `[256kB 256kB][256kB 256kB]` |
| 000   | 0x07a700        | $080000           | 0.5MB  | `[256kB 256kB][ ---   --- ]` |
