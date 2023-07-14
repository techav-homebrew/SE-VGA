# SE-VGA
SE-VGA is a video card primarily for the Mac SE, but also compatible with the Macintosh, 512k, and Plus. The FPGA configuration here will duplicate the Mac video pixel-doubled to 1024x768 and displayed letterboxed (black borders) in a 1024x768@60Hz frame over VGA. It does this by snooping the CPU bus for writes to the frame buffer region of memory, caching the video data in its own VRAM, and generating a new video signal from that data. It can plug directly into the PDS slot in a Mac SE, or plugs in place of the CPU on the Plus, 512k, or 128k models (CPU must be removed and a socket installed in its place; the CPU must then be installed on the SE-VGA card).

Circuit is built around a Latice iCE40HX4K FPGA with a single 16-bit SDRAM, theoretically supporting up to 512Mbit (64MB) of video memory. Video output is a 24-bit R2R DAC with output buffer. The PCB is designed as a 4-layer board with inner power and ground planes. Use of a PCB assembly service is recommended for the many 0402 passive components. 

The memory capacity and output capabilities of this project greatly exceed those necessary for duplicating the classic Macintosh video output in the hopes that it may be a starting point for projects which go beyond merely duplicating the classic Macintosh video output.

![MacSE Rev3 PCB Render](https://github.com/techav-homebrew/SE-VGA/blob/Rev3/Hardware/SE-VGA_Render-Front.png)

## Bill of Materials

| Qty | Manufacturer    | Part No.           | Name               | Description                                   |
|:---:|:----------------|:-------------------|:-------------------|:----------------------------------------------|
|     |                 |                    |                    |                                               | 

## Frame Buffer Addressing

The Mac primary framebuffer starts at 0x5900 below the top of RAM. Since it's not in a static location for every system, the system's memory configuration is needed. This is set by the Memory Size switches/jumpers. The chart below indicates the primary and alternate frame buffer locations based on the installed SIMM combinations in the Mac Plus/SE, as well as for the 512k & 128k models. 

|Main Framebuffer|Alt Framebuffer|RAM Top Address + 1|RAM Size|Installed SIMMs               |
|:--------------:|:-------------:|:-----------------:|:------:|------------------------------|
| `0x3fa700`     | `0x3f2700`    | `0x400000`        | 4.0MB  | `[ 1MB   1MB ][ 1MB   1MB ]` |
| `0x37a700`     | `0x372700`    | `0x380000`        | 3.5MB  | Invalid combination          |
| `0x2fa700`     | `0x2f2700`    | `0x300000`        | 3.0MB  | Invalid combination          |
| `0x27a700`     | `0x272700`    | `0x280000`        | 2.5MB  | `[ 1MB   1MB ][256kB 256kB]` |
| `0x1fa700`     | `0x1f2700`    | `0x200000`        | 2.0MB  | `[ 1MB   1MB ][ ---   --- ]` |
| `0x17a700`     | `0x172700`    | `0x180000`        | 1.5MB  | Invalid combination          |
| `0x0fa700`     | `0x0f2700`    | `0x100000`        | 1.0MB  | `[256kB 256kB][256kB 256kB]` |
| `0x07a700`     | `0x072700`    | `0x080000`        | 512kB  | `[256kB 256kB][ ---   --- ]` |
| `0x01a700`     | `0x012700`    | `0x020000`        | 128kB  | NA                           |

## FPGA Pin Assignments

|signal|Direction|Pin|
|---|---|---|
|   |   |   |

## Known Issues
- Logic has not yet been rewritten for the iCE40 FPGA

# License
This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License. See https://creativecommons.org/licenses/by-sa/4.0/.

# Acknowledgements
Special thanks to TubeTimeUS, whose Graphics Gremlin project answered many of the questions I had while designing this project. 
https://github.com/schlae/graphics-gremlin

