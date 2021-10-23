# SE-VGA
Simple CPLD project to mirror the Mac SE video over VGA. The image is pixel-doubled to 1024x684 and displayed letterboxed (black borders) in a 1024x768 video frame. Device snoops writes to the frame buffer memory locations and caches the data to its own VRAM for display. Plugs into the PDS slot in a Mac SE, or plugs in place of the CPU on Mac SE, Plus, or 512k models (128k Mac could be made to work with some adjustment to the CPLD configuration, but is not a configuration supported by the memory selection jumpers).

Circuit uses a single AFT1508AS-7AX100 CPLD, a pair of 256kbit (32kx8) 15ns or faster SRAM, a 13MHz crystal with 5x clock multiplier for 65MHz pixel clock, along with some passives.

## Bill of Materials

| Qty | Manufacturer    | Part No.           | Name               | Description                                   |
|:---:|:----------------|:-------------------|:-------------------|:----------------------------------------------|
|  2  | ISSI            | IS61C256AL-12TLI   | VRAM-ALT, VRAM-MAIN| 32kx8 12ns SRAM, TSOP-28                      | 
|  1  | Microchip       | ATF1508AS-7AX100   | LOGIC              | ATF1508AS or EPM7128 CPLD, TQFP-100           |
|  1  | Renesas / IDT   | 511MLF             | CLK                | Programmable Clock Multiplier, SO-8           |
|  1  | ECS             | ECS-130-20-46X     | XTAL               | 13MHz Crystal, HC-46X or HC-49UP              |
|  1  | TE Connectivity | 650473-5           | PDS                | DIN 41612 Right-angle 3x32 pin male connector |
|  5  |                 |                    | C1, C2, C3, C4, C5 | 0.1uF Decoupling Capacitor, 0805              |
|  2  |                 |                    | C6, C7             | 10uF Electrolytic Capacitor                   |
|  2  |                 |                    | C8, C9             | 20pF Capacitor, 0805                          |
|  2  |                 |                    | R3, R4, R5         | 10k pullup resistor, 0805 or axial            |
|  3  |                 |                    | R2                 | 460 ohm resistor, 0805 or axial               |
|  3  |                 |                    | R1                 | 75 ohm resistor, 0805 or axial                |
|  1  |                 |                    | PGM                | 2x5 pin header for CPLD JTAG programming      |
|  1  |                 |                    | VGA                | 2x5 pin header for VGA adapter                |
|  1  |                 |                    | RAMSIZE            | 3x2 jumper                                    |
|  1  |                 |                    | BRD                | 64-pin DIP header, male                       |
|  1  |                 |                    | CPU                | 64-pin DIP socket, female                     |

## Frame Buffer Addressing

The Mac SE primary framebuffer starts at 0x5900 below the top of RAM. Since it's not in a static location for every system, the system's memory configuration is needed. This is set by three ramSize jumpers, which mask CPU address bits 21, 20, 19. Not all possible ramSize selections are valid memory sizes when using 30-pin SIMMs in the Mac SE. In theory, these combinations could be possible when using PDS memory expansion cards, but this is unlikely. The chart below indicates the valid & invalid ramSize configurations and the corresponding installed SIMM combinations.

|ramSize|Main Framebuffer|Alt Framebuffer|RAM Top Address + 1|RAM Size|Installed SIMMs               |
|:-----:|:--------------:|:-------------:|:-----------------:|:------:|------------------------------|
| 111   | 0x3fa700       | 0x3f2700      | 0x400000          | 4.0MB  | `[ 1MB   1MB ][ 1MB   1MB ]` |
| 110   | 0x37a700       | 0x372700      | 0x380000          | 3.5MB  | Invalid combination          |
| 101   | 0x2fa700       | 0x2f2700      | 0x300000          | 3.0MB  | Invalid combination          |
| 100   | 0x27a700       | 0x272700      | 0x280000          | 2.5MB  | `[ 1MB   1MB ][256kB 256kB]` |
| 011   | 0x1fa700       | 0x1f2700      | 0x200000          | 2.0MB  | `[ 1MB   1MB ][ ---   --- ]` |
| 010   | 0x17a700       | 0x172700      | 0x180000          | 1.5MB  | Invalid combination          |
| 001   | 0x0fa700       | 0x0f2700      | 0x100000          | 1.0MB  | `[256kB 256kB][256kB 256kB]` |
| 000   | 0x07a700       | 0x072700      | 0x080000          | 0.5MB  | `[256kB 256kB][ ---   --- ]` |

## CPLD Pin Assignments
Logic uses nearly all available resources in the CPLD (104 of 128 macrocells).

|signal|Direction|Pin|
|---|---|---|
|cpuAddr[23]|Input|PIN_100|
|cpuAddr[22]|Input|PIN_1|
|cpuAddr[21]|Input|PIN_2|
|cpuAddr[20]|Input|PIN_5|
|cpuAddr[19]|Input|PIN_6|
|cpuAddr[18]|Input|PIN_7|
|cpuAddr[17]|Input|PIN_8|
|cpuAddr[16]|Input|PIN_9|
|cpuAddr[15]|Input|PIN_10|
|cpuAddr[14]|Input|PIN_12|
|cpuAddr[13]|Input|PIN_13|
|cpuAddr[12]|Input|PIN_14|
|cpuAddr[11]|Input|PIN_16|
|cpuAddr[10]|Input|PIN_17|
|cpuAddr[9]|Input|PIN_19|
|cpuAddr[8]|Input|PIN_20|
|cpuAddr[7]|Input|PIN_21|
|cpuAddr[6]|Input|PIN_22|
|cpuAddr[5]|Input|PIN_23|
|cpuAddr[4]|Input|PIN_24|
|cpuAddr[3]|Input|PIN_25|
|cpuAddr[2]|Input|PIN_27|
|cpuAddr[1]|Input|PIN_28|
|cpuData[15]|Input|PIN_29|
|cpuData[14]|Input|PIN_30|
|cpuData[13]|Input|PIN_31|
|cpuData[12]|Input|PIN_32|
|cpuData[11]|Input|PIN_33|
|cpuData[10]|Input|PIN_35|
|cpuData[9]|Input|PIN_36|
|cpuData[8]|Input|PIN_37|
|cpuData[7]|Input|PIN_40|
|cpuData[6]|Input|PIN_41|
|cpuData[5]|Input|PIN_42|
|cpuData[4]|Input|PIN_44|
|cpuData[3]|Input|PIN_45|
|cpuData[2]|Input|PIN_46|
|cpuData[1]|Input|PIN_47|
|cpuData[0]|Input|PIN_48|
|cpuRnW|Input|PIN_96|
|nReset|Input|PIN_89|
|ncpuAS|Input|PIN_92|
|ncpuLDS|Input|PIN_93|
|ncpuUDS|Input|PIN_94|
|nhSync|Output|PIN_85|
|nvSync|Output|PIN_84|
|nvramCE0|Output|PIN_81|
|nvramCE1|Output|PIN_80|
|nvramOE|Output|PIN_79|
|nvramWE|Output|PIN_78|
|pixClk|Input|PIN_87|
|ramSize[2]|Input|PIN_97|
|ramSize[1]|Input|PIN_98|
|ramSize[0]|Input|PIN_99|
|vidOut|Output|PIN_83|
|vramAddr[14]|Output|PIN_77|
|vramAddr[13]|Output|PIN_76|
|vramAddr[12]|Output|PIN_75|
|vramAddr[11]|Output|PIN_72|
|vramAddr[10]|Output|PIN_71|
|vramAddr[9]|Output|PIN_70|
|vramAddr[8]|Output|PIN_69|
|vramAddr[7]|Output|PIN_68|
|vramAddr[6]|Output|PIN_67|
|vramAddr[5]|Output|PIN_65|
|vramAddr[4]|Output|PIN_64|
|vramAddr[3]|Output|PIN_63|
|vramAddr[2]|Output|PIN_61|
|vramAddr[1]|Output|PIN_60|
|vramAddr[0]|Output|PIN_58|
|vramData[7]|Bidir|PIN_57|
|vramData[6]|Bidir|PIN_56|
|vramData[5]|Bidir|PIN_55|
|vramData[4]|Bidir|PIN_54|
|vramData[3]|Bidir|PIN_53|
|vramData[2]|Bidir|PIN_52|
|vramData[1]|Bidir|PIN_50|
|vramData[0]|Bidir|PIN_49|
|TCK|Input|PIN_62|
|TDI|Input|PIN_4|
|TDO|Output|PIN_73|
|TMS|Input|PIN_15

## Known Issues
~~First run schematic and gerbers used three pairs of resistor dividers for R, G, B output channels. A better approach would be to use a single divider and tie all three output channels together. Also 470 ohm is a bit too high, so the image is quite dark.~~ Removed extraneous resistor dividers. Changed 470ohm resistor to 460.

~~The resistor footprints are too small for 1/4W parts. Might work with 1/8W parts.~~ Added footprints for 0805 resistors. 

Timing for the SE window is a bit off. It appears to be starting the window a couple pixels early on the left, and it might be cutting off the last pixel or two on the right.

## Wish List
~~I would like to bump up the pixel clock to 65MHz and run the output video at 1024x768@60. This would allow the SE frame to be pixel doubled to 1024x684, which would only leave black bars on the top and bottom, instead of on all four sides. This could also be a useful starting point for a future project to output video for an early iPad display for units missing a CRT. ~~