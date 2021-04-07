/******************************************************************************
 * SE-VGA
 * Top-level module 
 * techav
 * 2021-04-06
 ******************************************************************************
 * Pulls together all the smaller modules to form the SE-VGA adapter
 *****************************************************************************/

module design sevga (
    input wire              nReset,     // System reset signal
    input wire              pixClk,     // 25.175MHz pixel clock
    output wire             nhSync,     // HSync signal
    output wire             nvSync,     // VSync signal
    output wire             vidOut,     // 1-bit Monochrome video signal

    output logic [12:0]     vramAddr,   // VRAM Address bus
    inout logic [7:0]       vramData,   // VRAM Data bus
    output wire             nvramOE,    // VRAM Read strobe
    output wire             nvramWE,    // VRAM Write strobe

    input logic [23:1]      cpuAddr,    // CPU Address bus
    input logic [15:0]      cpuData,    // CPU Data bus
    input wire              ncpuAS,     // CPU Address Strobe signal
    input wire              ncpuUDS,    // CPU Upper Data Strobe signal
    input wire              ncpuLDS,    // CPU Lower Data Strobe signal
    input wire              cpuRnW,     // CPU Read/Write select signal
    input wire              cpuClk      // CPU Clock
);

logic [9:0] hCount;
logic [9:0] vCount;
wire hActive;
wire hSEActive;

logic [7:0] vidVramData;
logic [12:0] vidVramAddr;


// link module that generates all our timing signals
vgagen vgatiming(nReset,pixClk,hCount,hActive,hSEActive,nhSync,vCount,vActive,vSEActive,nvSync);
// link module that fetches & outputs video data
vgaout vidvram(pixClock,nReset,hCount,vCount,hSEActive,vSEActive,vidVramData,vidVramAddr,nvramOE,vidOut);
// link module that handles cpu writes


endmodule