# SE-VGA
Simple CPLD project to mirror the Mac SE video over VGA. No scaling is performed -- the Mac 512x342 video is displayed letterboxed (black borders) in a 640x480 frame.

Circuit uses a single AFT1508AS-100AU CPLD, a pair of 256kbit (32kx8) 15ns SRAM, and a 25.175MHz can oscillator, along with some passives.

Plugs into SE PDS slot and snoops writes to the frame buffer memory locations. Writes are cached and copied to VRAM.

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
Logic uses nearly all available resources in the 128-macrocell CPLD.

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
