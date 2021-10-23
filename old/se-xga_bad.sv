/******************************************************************************
 * SE-VGA
 * Top-level module 
 * techav
 * 2021-10-16
 ******************************************************************************
 * Trying again again again
 *****************************************************************************/

module sevga (
    input wire              nReset,     // System reset signal
    input wire              pixClk,     // 65MHz pixel clock
    output reg              nhSync,     // HSync signal
    output reg              nvSync,     // VSync signal
    output reg              vidOut,     // 1-bit Monochrome video signal

    output logic [14:0]     vramAddr,   // VRAM Address bus
    inout logic [7:0]       vramData,   // VRAM Data bus
    output reg              nvramOE,    // VRAM Read strobe
    output reg              nvramWE,    // VRAM Write strobe
    output reg              nvramCE0,   // VRAM Main chip select signal
    output reg              nvramCE1,   // VRAM Alt chip select signal

    input wire [23:1]       cpuAddr,    // CPU Address bus
    input wire [15:0]       cpuData,    // CPU Data bus
    input wire              ncpuAS,     // CPU Address Strobe signal
    input wire              ncpuUDS,    // CPU Upper Data Strobe signal
    input wire              ncpuLDS,    // CPU Lower Data Strobe signal
    input wire              cpuRnW,     // CPU Read/Write select signal
    input logic [2:0]       ramSize     // Select installed RAM size
);

/******************************************************************************
 * Initial Video Signal Timing
 * The following functions establish the basic XGA signal timing and 
 * assert the horizontal and vertical sync signals as appropriate.
 * These functions are the minimum required for a signal presence detect test.
 *****************************************************************************/

// Primary sync counters
logic [10:0] hCount;    // 0..1343
logic [9:0] vCount;     // 0..805
always @(negedge pixClk) begin
    if(hCount < 1343) hCount <= hCount + 11'h1;
    else begin
        hCount <= 0;
        if(vCount <= 805) vCount <= vCount + 10'h1;
        else vCount <= 0;
    end
end

// Horizontal sync
always @(negedge pixClk) begin
    if(hCount == 0) nhSync <= 1;
    else if(hCount == 1052) nhSync <= 0;
    else if(hCount == 1186) nhSync <= 1;
end

// Vertical sync
always @(negedge pixClk) begin
    if(vCount == 0) nvSync <= 1;
    else if(vCount == 729) nvSync <= 0;
    else if(vCount == 734) nvSync <= 0;
end

/******************************************************************************
 * Useful signals
 * Here we break out a few useful signals, derived from the timing above, that
 * will help us elsewhere.
 *****************************************************************************/

// Horizontal active
reg hActive;
always @(negedge pixClk) begin
    if(hCount == 0) hActive <= 1;
    else if(hCount == 1023) hActive <= 0;
    else if(hCount == 1343) hActive <= 1;
end

// Vertical active
reg vActive;
always @(negedge pixClk) begin
    if(vCount == 0) vActive <= 1;
    else if(vCount == 683) vActive <= 0;
    else if(vCount == 805) vActive <= 1;
end

// Horizontal fetch active
// asserted just before active video to enable video data pre-fetch
reg fhActive;
always @(negedge pixClk) begin
    if(hCount == 0) fhActive <= 1;
    else if(hCount == 1022) fhActive <= 0;
    else if(hCount == 1342) fhActive <= 1;
end

// Vertical fetch active
// 
reg fvActive;
always @(negedge pixClk) begin
    if(vCount == 0) fvActive <= 1;
    else if(vCount == 684) fvActive <= 0;
    if(vCount == 805) fvActive <= 1; 
end

// combined active signals
wire vidActive = hActive & vActive;
wire fetchActive = fhActive & fvActive;

/******************************************************************************
 * VRAM State Machine
 * Coordinates VRAM load/store actions
 *****************************************************************************/

// rising edge signals: nvramWE, nvramOE, nvramCE[1:0]
// falling edge signals: vramAddr, vramData

// VRAM read signal
//always @(posedge pixClk) begin nvramOE <= ~(hCount == 7); end

// VRAM write signal
always @(posedge pixClk) begin
    if(hCount[3:1] == 0) nvramWE <= 1;
    else if(hCount[3:1] == 1) nvramWE <= 0;
    else if(hCount[3:1] == 6) nvramWE <= 1;
end

// VRAM data/address busses
always @(negedge pixClk) begin
    if(hCount[0] && !hCount[1]) begin
        case(hCount[3:2])
            3: begin
                // start read cycle
                vramData <= 8'hZ;
                vramAddr[14:6] <= vCount[9:1];
                vramAddr[5:0] <= hCount[9:4];
            end
            default: begin
                // write slots
                vramAddr[14:1] <= cpuAddr[14:1] - 14'h1380;
                if(!ncpuUDSr && !cpuLDSsrv) begin
                    vramAddr[0] <= 0;
                    vramData <= cpuData[15:8];
                end else if(!ncpuLDSr && !cpuLDSsrv) begin
                    vramAddr[0] <= 1;
                    vramData <= cpuData[7:0];
                end
            end
        endcase
    end
end

// VRAM chip enable signals
reg cpuUDSsrv, cpuLDSsrv;
always @(posedge pixClk) begin
    if(hCount[3:1] == 7 && fetchActive) begin
        nvramCE0 <= vidBufSel;
        nvramCE1 <= ~vidBufSel;
        nvramOE <= 0;
    end else if(!hCount[0] && hCount[1]) begin
        // write cycle
        if(!ncpuUDSr && !cpuUDSsrv) begin
            nvramCE0 <= ~cpuAddr[15];
            nvramCE1 <= cpuAddr[15];
            cpuUDSsrv <= 1;
        end else if(!ncpuLDSr && !cpuLDSsrv) begin
            nvramCE0 <= ~cpuAddr[15];
            nvramCE1 <= cpuAddr[15];
            cpuLDSsrv <= 1;
        end else begin
            nvramCE0 <= 1;
            nvramCE1 <= 1;
        end
        nvramOE <= 1;
    end else begin
        nvramCE0 <= 1;
        nvramCE1 <= 1;
        nvramOE <= 1;
    end
    // reset the upper/lower serve signals when cycle ended by CPU
    if(ncpuLDS) cpuLDSsrv <= 0;
    if(ncpuUDS) cpuUDSsrv <= 0;
end

// Video data shift register & output
reg [7:0] vidShiftr;
always @(negedge pixClk) begin
    if(hCount[3:0] == 4'hF) vidShiftr <= ~vramData;
    else if(hCount[0]) begin
        vidShiftr[7:1] <= vidShiftr[6:0];
        vidShiftr[0] <= 0;
    end
end
always_comb begin
    if(vidActive) vidOut = vidShiftr[7];
    else vidOut <= 0;
end

/******************************************************************************
 * CPU Bus Snooping
 * Watches the CPU bus and aligns its operations with the pixel clock
 *****************************************************************************/
reg ncpuUDSr, ncpuLDSr;
always @(negedge pixClk) begin
    // this condition evaluates true when cpu is writing to video buffer
    if(!ncpuAS && !cpuRnW
        && !cpuAddr[23] && !cpuAddr[22]
        && !(cpuAddr[21] ^ ramSize[2])
        && !(cpuAddr[20] ^ ramSize[1])
        && !(cpuAddr[19] ^ ramSize[0])
        && cpuAddr[18] && cpuAddr[17]
        && cpuAddr[16]
        && ((cpuAddr[14:1] >= 14'h1380)
        && (cpuAddr[14:1] < 14'h3E40))) 
    begin
        if(!ncpuUDS) ncpuUDSr <= 0;
        else ncpuUDSr <= 1;
        if(!ncpuLDS) ncpuLDSr <= 0;
        else ncpuLDSr <= 1;
    end else begin
        ncpuUDSr <= 1;
        ncpuLDSr <= 1;
    end
end

// hold low for now
reg vidBufSel = 0;

endmodule