/******************************************************************************
 * SE-VGA
 * Top-level module 
 * techav
 * 2021-08-04
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

/******************************************************************************
 * Initial Video Signal Timing
 * The following four functions establish the basic XGA signal timing and 
 * assert the horizontal and vertical sync signals as appropriate.
 * These functions are the minimum required for a signal presence detect test.
 *****************************************************************************/
logic [10:0] hCount;    // 0..1343
logic [9:0] vCount;     // 0..805

// horizontal counter
always @(negedge pixClk or negedge nReset) begin
    if(!nReset) hCount <= 0;
    else if(!pixClk) begin
        if(hCount < 1343) hCount <= hCount + 11'd1;
        else hCount <= 0;
    end
end

// vertical counter
always @(negedge nhSync or negedge nReset) begin
    if(!nReset) vCount <= 0;
    else if(!pixClk) begin
        if(vCount < 805) vCount <= vCount + 10'd1;
        else vCount <= 0;
    end
end

// horizontal and vertical sync signals
always_comb begin
    if(hCount >= 1049 && hCount < 1184) nhSync <= 0;
    else nhSync <= 1;

    if(vCount >= 729 && vCount < 735) nvSync <= 0;
    else nvSync <= 1;
end

/******************************************************************************
 * Useful signals
 * Here we break out a few useful signals, derived from the timing above, that
 * will help us elsewhere.
 *****************************************************************************/
wire hActive, vActive;      // active video signals. vidout black when negated
wire vidActive;             // active when both hActive and vActive asserted
wire hLoad;                 // load pixel data from vram when asserted

assign vidActive = hActive & vActive;

always_comb begin
    if(hCount >= 1 && hCount < 1025) hActive <= 1;
    else hActive <= 0;

    if(vCount >= 0 && vCount < 684) vActive <= 1;
    else vActive <= 0;

    if(hCount >= 0 && hCount < 1024 && vActive) hLoad <= 1;
    else hLoad <= 0;
end

/******************************************************************************
 * Video Output Sequencing
 * Here is the primary video output shift register sequencing.
 * With these functions in place, it should be possible to strap the VRAM data
 * signals and see the strapped pattern output on screen.
 *****************************************************************************/
logic [8:0] vidData;        // the video data we are displaying
wire  [2:0] vidSeq;         // sequence counter, derived from hCount
wire tick, tock;            // even/odd pulses of pixel clock divided by 2
wire [14:0] readAddr;              // VRAM read address

assign vidSeq = hCount[3:1];
assign tick = !hCount[0];
assign tock = hCount[0];

always @(negedge pixClk or negedge nReset) begin
    if(!nReset) vidData <= 0;
    else if(!pixClk) begin
        if(tock && hLoad && vidSeq == 3'd0) begin
            // store the VRAM data in vidData[8:1]
            //vidData[0] <= vidData[1]; // this should actually have already been done
            vidData[8:1] <= vramData;
        end else if(tick && hLoad) begin
            // shift vidData
            vidData[7:0] <= vidData[8:1];
            vidData[8] <= 0;
        end
    end
end

always_comb begin
    // here is where the shifted video data actually gets output
    if(vidActive) vidOut <= ~vidData[0];
    else vidOut <= 0;

    // vram read signal can be asserted here
    if(vidActive && vidSeq == 3'd0) nvramOE <= 0;
    else nvramOE <= 1;

    // we'll be interleaving VRAM accesses, so the highest address bit will be
    // used to select between Main & Aux video buffers.
    // hCount[4] will be used to select between SRAM chips
    readAddr[14] <= vidBufSel;
    readAddr[13:5] <= vCount[9:1];
    readAddr[4:0] <= hCount[9:5];
end


/******************************************************************************
 * CPU Bus Snooping
 * Watch the CPU bus for writes to the video buffer regions of memory, cache
 * the data internally until a write slot is available, then store in VRAM.
 * This is the last step, and it's a big one. Once this is in place and
 * operational, the adapter should be fully operational. 
 *****************************************************************************/

// to remember for later:
// vramCE[x] should be asserted when vidSeq == 0
// vramOE should be asserted when vidSeq == 0 && vidActive
// vramWE should be asserted on tock pulses of write sequences
wire [14:0] writeAddr;
reg vidBufSel;
wire nvramCE0cpu, nvramCE1cpu;


reg nvramWEpre;

always @(negedge pixClk or negedge nReset) begin
    if(nReset) begin
        nvramWEpre <= 1;
    end else if(!pixClk && vidSeq != 0 && (!ncpuLDS || !ncpuUDS) && tock) begin
        
    end
end

/*
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
*/

/*
cpusnoop cpusnp(
    .nReset(nReset),
    .pixClock(pixClk),
    .seq(vidSeq),
    .cpuAddr(cpuAddr),
    .cpuData(cpuData),
    .ncpuAS(ncpuAS),
    .ncpuUDS(ncpuUDS),
    .ncpuLDS(ncpuLDS),
    .cpuRnW(cpuRnW),
    .cpuClk(cpuClk),
    .vramAddr(writeAddr),
    .vramDataOut(),
    .nvramWE(),
    .nvramCE0(nvramCE0cpu),
    .nvramCE1(nvramCE1cpu),
    .vidBufSelOut(),
    .ramSize(ramSize)
);
*/

always_comb begin
    if(nvramOE == 0) vramAddr <= readAddr;
    else if(nvramWE == 0) vramAddr <= writeAddr;
    else vramAddr <= 0;

    if(nvramOE == 0) begin
        nvramCE0 <= hCount[4];
        nvramCE1 <= ~hCount[4];
    end else if(nvramWE == 0) begin
        nvramCE0 <= nvramCE0cpu;
        nvramCE1 <= nvramCE1cpu;
    end else begin
        nvramCE0 <= 1;
        nvramCE1 <= 1;
    end
end

endmodule