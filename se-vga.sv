/******************************************************************************
 * SE-VGA
 * Top-level module 
 * techav
 * 2021-04-06
 ******************************************************************************
 * Pulls together all the smaller modules to form the SE-VGA adapter
 *****************************************************************************/

module sevga (
    input wire              nReset,     // System reset signal
    input wire              pixClk,     // 25.175MHz pixel clock
    output wire             nhSync,     // HSync signal
    output wire             nvSync,     // VSync signal
    output wire             vidOut,     // 1-bit Monochrome video signal

    output logic [14:0]     vramAddr,   // VRAM Address bus
    inout logic [7:0]       vramData,   // VRAM Data bus
    output wire             nvramOE,    // VRAM Read strobe
    output wire             nvramWE,    // VRAM Write strobe
    output wire             nvramCE0,   // VRAM Main chip select signal
    output wire             nvramCE1,   // VRAM Alt chip select signal

    input logic [23:1]      cpuAddr,    // CPU Address bus
    input logic [15:0]      cpuData,    // CPU Data bus
    input wire              ncpuAS,     // CPU Address Strobe signal
    input wire              ncpuUDS,    // CPU Upper Data Strobe signal
    input wire              ncpuLDS,    // CPU Lower Data Strobe signal
    input wire              cpuRnW,     // CPU Read/Write select signal
    input logic [2:0]       ramSize     // Select installed RAM size
);

logic [9:0] hCount;
logic [9:0] vCount;
wire hActive;
wire hSEActive;
wire vActive;
wire vSEActive;
wire nvramWEpre;            // VRAM Write signal from cpu snoop
wire nvramCE0pre;
wire nvramCE1pre;
wire vidBufSel;

logic [14:0] vidVramAddr;
logic [14:0] cpuVramAddr;
logic [7:0] vidVramData;
wire [7:0] cpuVramData;

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
    .vramData(vidVramData),
    .vramAddr(vidVramAddr),
    .nvramOE(nvramOE),
    .vidOut(vidOut)
);

// link module that snoops cpu writes
cpusnoop cpusnp(    
    .nReset(nReset),
    .pixClock(pixClk),
    .seq(hCount[2:0]),
    .cpuAddr(cpuAddr),
    .cpuData(cpuData),
    .ncpuAS(ncpuAS),
    .ncpuUDS(ncpuUDS),
    .ncpuLDS(ncpuLDS),
    .cpuRnW(cpuRnW),
    .cpuClk(cpuClk),
    .vramAddr(cpuVramAddr),
    .vramDataOut(cpuVramData),
    .nvramWE(nvramWEpre),
    .nvramCE0(nvramCE0pre),
    .nvramCE1(nvramCE1pre),
    .vidBufSelOut(vidBufSel),
    .ramSize(ramSize)
);

always_comb begin
    // vramAddr muxing
    if(nvramWEpre == 1'b0) begin
        vramAddr <= cpuVramAddr;
    end else if(nvramOE == 0) begin
        vramAddr <= vidVramAddr;
    end else begin
        vramAddr <= 0;
    end
end

always_comb begin
    if(nvramWEpre == 1'b0) begin
        vramData <= cpuVramData;
    end else begin
        vramData <= 8'bZZZZZZZZ;
    end
    vidVramData <= vramData;
end

assign nvramCE0 = (nvramWEpre | nvramCE0pre) & (nvramOE | vidBufSel);
assign nvramCE1 = (nvramWEpre | nvramCE1pre) & (nvramOE | !vidBufSel);

assign nvramWE = nvramWEpre | pixClk;

endmodule