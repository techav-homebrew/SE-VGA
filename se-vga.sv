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

//logic [7:0] vidVramData;
logic [12:0] vidVramAddr;
//logic [7:0] cpuVramData;
logic [12:0] cpuVramAddr;


// link module that generates all our timing signals
vgagen vgatiming(
    .nReset(nReset),
    .pixClk(pixClk),
    .hCount(hCount),
    .hActive(hActive),
    .hSEActive(hSEActive),
    .nhSync(nhSync),
    .vCount(vCount),
    .vActive(vActive),
    .vSEActive(vSEActive),
    .nvSync(nvSync)
);

// link module that fetches & outputs video data
vgaout vidvram(
    .pixClock(pixClk),
    .nReset(nReset),
    .hCount(hCount),
    .vCount(vCount),
    .hSEActive(hSEActive),
    .vSEActive(vSEActive),
    .vramData(vramData),
    .vramAddr(vidVramAddr),
    .nvramOE(nvramOE),
    .vidOut(vidOut)
);

// link module that handles cpu writes
cpusnoop cpusnp(    
    .nReset(nReset),
    .pixClock(pixClk),
    .sequence(hCount[2:0]),
    .cpuAddr(cpuAddr),
    .cpuData(cpuData),
    .ncpuAS(ncpuAS),
    .ncpuUDS(ncpuUDS),
    .ncpuLDS(ncpuLDS),
    .cpuRnW(cpuRnW),
    .cpuClk(cpuClk),
    .vramAddr(vramAddr),
    .vramData(cpuVramData),
    .nvramWE(nvramWE)
);

always_comb begin
    // vramAddr muxing
    if(.nvramWE == 1'b0) begin
        vramAddr <= cpuVramAddr;
    end else begin
        vramAddr <= vidVramData;
    end
end

endmodule