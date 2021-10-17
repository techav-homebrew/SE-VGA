/******************************************************************************
 * SE-VGA
 * Top-level module 
 * techav
 * 2021-10-12
 ******************************************************************************
 * This is ... mostly working. It has some write glitches and a vertical line
 * five pixels from the left side of the screen.
 *****************************************************************************/

module sevga (
    input wire              nReset,     // System reset signal
    input wire              pixClk,     // 65MHz pixel clock
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
wire nhSyncInner;

// Primary video sync counters -- Now more synchronous!
always @(negedge pixClk) begin
    if(hCount < 11'd1343) hCount <= hCount + 11'd1;
    else begin
        hCount <= 11'd0;
        if(vCount < 10'd805) vCount <= vCount + 10'd1;
        else vCount <= 10'd0;
    end
end

// horizontal and vertical sync signals
always_comb begin
    //if(hCount >= 11'd1048 && hCount < 11'd1184) nhSyncInner <= 0;
    if(hCount >= 11'd1052 && hCount < 11'd1187) nhSyncInner <= 0;
    else nhSyncInner <= 1;
    nhSync <= nhSyncInner;

    if(vCount >= 10'd729 && vCount < 10'd735) nvSync <= 0;
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
    if(hCount >= 3 && hCount < 1027) hActive <= 1;
    else hActive <= 0;

    if(vCount >= 0 && vCount < 684) vActive <= 1;
    else vActive <= 0;

    if(hCount >= 0 && hCount < 1024 && vActive) hLoad <= 1;
    else hLoad <= 0;
end

/******************************************************************************
 * Primary State Machine
 * This is the primary state machine which runs the entire system, handling
 * VRAM reads, VRAM writes, VIA writes, and idle states
 *****************************************************************************/

// used to align primary state machine with horizontal counter
wire [3:0] vSeq = hCount[3:0];

// define state machine states (Gray code)
parameter
    S0  =   4'b0000,    // VRAM Read 0
    S1  =   4'b0001,    // VRAM Read 1
    S2  =   4'b0011,    // Idle
    S3  =   4'b0010,    // VRAM Write Upper 0
    S4  =   4'b0110,    // VRAM Write Upper 1
    S5  =   4'b0111,    // VRAM Write Lower 0
    S6  =   4'b0101,    // VRAM Write Lower 1
    S7  =   4'b0100,    // VIA Write
    S8  =   4'b1100,    // VSync (to be added later)
    S9  =   4'b1101,    // undefined
    S10 =   4'b1111,    // undefined
    S11 =   4'b1110,    // undefined
    S12 =   4'b1010,    // undefined
    S13 =   4'b1011,    // undefined
    S14 =   4'b1001,    // undefined
    S15 =   4'b1000;    // undefined

logic [3:0] pState;

// And here is the much simplified primary state machine
always @(negedge pixClk or negedge nReset) begin
    if(!nReset) pState <= S2;   // resync on reset by jumping to idle state
    else begin
        case(pState)
            S0: pState <= S1;   // first VRAM read state, always move to S1
            S3: pState <= S4;   // first UDS write state, always move to S4
            S5: pState <= S6;   // first LDS write state, always move to S6
            /*S7: begin
                
                pState <= S2;
            end*/
            S2: begin
                // here is where everything actually happens.
                if(vSeq == 4'hF) pState <= S0;   // time for a read state
                else if(cpuUWriteReq && !cpuUWriteSrv && vSeq < 4'hD) pState <= S3;
                else if(cpuLWriteReq && !cpuLWriteSrv && vSeq < 4'hD) pState <= S5;
                else if(cpuVIAReq    && !cpuVIASrv    && vSeq < 4'hE) pState <= S7;
                else pState <= S2;
            end
            default: pState <= S2; // everyone ends up at S2 (idle)
        endcase
    end
end

// primary VRAM signal combination, based on the primary state machine
always_comb begin
    // VRAM Read Strobe
    if((pState == S0 || pState == S1) && hLoad) nvramOE <= 0;
    else nvramOE <= 1;

    // VRAM Write Strobe
    if(pState == S3 || pState == S5) nvramWE <= 0;
    else nvramWE <= 1;
    
    // VRAM Chip Enable Signals
    case(pState)
        S0, S1: begin
            if(hLoad) begin
                nvramCE0 <= ~vidBufSel;
                nvramCE1 <= vidBufSel;
            end else begin
                nvramCE0 <= 1;
                nvramCE1 <= 1;
            end
        end
        S3, S4, S5, S6: begin
            nvramCE0 <= ~cpuBufSel;
            nvramCE1 <= cpuBufSel;
        end
        default: begin
            nvramCE0 <= 1;
            nvramCE1 <= 1;
        end
    endcase

    // VRAM Address Bus
    case(pState)
        S0, S1: begin
            // address bus for read cycles
            if(hLoad) begin
                vramAddr[14:6] <= vCount[9:1];
                vramAddr[5:0] <= hCount[9:4];
            end else begin
                vramAddr <= 0;
            end
        end
        S3, S4: begin
            // address bus for upper write cycles
            vramAddr[14:1] <= cpuAddrShift;
            vramAddr[0] <= 0;
        end
        S5, S6: begin
            // address bus for lower write cycles
            vramAddr[14:1] <= cpuAddrShift;
            vramAddr[0] <= 1;
        end
        default: begin
            // address bus for idle cycles
            vramAddr <= 0;
        end
    endcase

    // VRAM Data bus
    case(pState)
        S3, S4 : vramData <= cpuData[15:8];
        S5, S6 : vramData <= cpuData[7:0];
        default: vramData <= 8'hZ;
    endcase
end

/******************************************************************************
 * Video Output Sequencing
 * Here is the primary video output shift register sequencing.
 * With these functions in place, it should be possible to strap the VRAM data
 * signals and see the strapped pattern output on screen.
 *****************************************************************************/
logic [8:0] vidData;        // the video data we are displaying

// output shift register
always @(posedge pixClk) begin
    if(pState == S1 && hLoad) begin
        // store VRAM data in shift register
        vidData[7:0] <= vramData;
    end else if(!hCount[0] && vidActive) begin
        // shift out video data
        vidData[8:1] <= vidData[7:0];
        vidData[0] <= 1;
    end
end

// final video output
always_comb begin
    if(vidActive) vidOut <= ~vidData[8];
    else vidOut <= 0;
end

/******************************************************************************
 * CPU Bus Snooping
 * Watch the CPU bus for writes to the video buffer regions of memory and write
 * that data to VRAM. VRAM write cycles can occur during vidSeq 1 through 7.
 * High-order bytes are passed to VRAM on tick states and low-order bytes are 
 * passed to VRAM on tock states. After the VRAM writes are complete, state
 * machine waits for the CPU cycle to end before returning to idle.
 *****************************************************************************/

/* Main framebuffer starts $5900 below the top of RAM, alt frame buffer is
 * $8000 below the main frame buffer
 * ramSize is used to mask the CPU Address bits [21:19] to select the amount
 * of memory installed in the computer. Not all possible ramSize selections
 * are valid memory sizes when using 30-pin SIMMs in the Mac SE. 
 * They may be possible using PDS RAM expansion cards.
 * ramSize mainBuffer altBuffer ramTop+1 ramSize Valid?      Installed SIMMs
 *    $7    $3fa700    $3f2700   $400000  4.0MB    Y    [ 1MB   1MB ][ 1MB   1MB ]
 *    $6    $37a700    $372700   $380000  3.5MB    N
 *    $5    $2fa700    $2f2700   $300000  3.0MB    N
 *    $4    $27a700    $272700   $280000  2.5MB    Y    [ 1MB   1MB ][256kB 256kB]
 *    $3    $1fa700    $1f2700   $200000  2.0MB    Y    [ 1MB   1MB ][ ---   --- ]
 *    $2    $17a700    $172700   $180000  1.5MB    N  
 *    $1    $0fa700    $0f2700   $100000  1.0MB    Y    [256kB 256kB][256kB 256kB]
 *    $0    $07a700    $072700   $080000  0.5MB    Y    [256kB 256kB][ ---   --- ]
 */

// keep track of pending CPU write requests and whether they have been serviced
wire cpuUWriteReq, cpuLWriteReq, cpuVIAReq;
reg  cpuUWriteSrv, cpuLWriteSrv, cpuVIASrv;
wire cpuBufSel;
wire cpuBufAddr;
reg vidBufSel;
wire [13:0] cpuAddrShift = cpuAddr[14:1] - 14'h1380;
wire cpuBufRange;

// these are some helpful signals that shortcut the CPU buffer & VIA addresses
always_comb begin
    /*if(cpuAddr[14:1] >= 14'h1380
        && cpuAddr[14:1] < 14'h3E40) cpuBufRange <= 1;
    else cpuBufRange <= 0;*/
    cpuBufRange <= (cpuAddr[14:1] >= 14'h1380) & (cpuAddr[14:1] < 14'h3E40);
    if(!ncpuAS && !cpuRnW
            && !cpuAddr[23] && !cpuAddr[22]     // first two bits always 0
            && !(cpuAddr[21] ^ ramSize[2])      // compare with RAM Size bits
            && !(cpuAddr[20] ^ ramSize[1])
            && !(cpuAddr[19] ^ ramSize[0])
            && cpuAddr[18] && cpuAddr[17]       // next three bits always 1
            && cpuAddr[16]                      // skip 15, it selects buffers
            && cpuBufRange                      // only select buffer addresses
    ) begin
        cpuBufAddr <= 1;
    end else begin
        cpuBufAddr <= 0;
    end
    cpuBufSel <= ~cpuAddr[15];                   // address bit 15 selects buffer

    if(cpuBufAddr && !ncpuUDS) cpuUWriteReq <= 1;
    else cpuUWriteReq <= 0;
    if(cpuBufAddr && !ncpuLDS) cpuLWriteReq <= 1;
    else cpuLWriteReq <= 0;

    // VIA is in address block $E8,0000 - $EF,FFFF
    // VIA register select pins (RS[3:0]) are wired to cpuAddr[12:9]
    // VIA Output Register A is selected when RS[3:0]==$F
    /*if(!ncpuAS && !cpuRnW && !ncpuUDS
            && cpuAddr[23] && cpuAddr[22]       // VIA Address Select
            && cpuAddr[21] && !cpuAddr[20]
            && cpuAddr[19]
            && cpuAddr[12] && cpuAddr[11]       // VIA ORA
            && cpuAddr[10] && cpuAddr[9]
    ) cpuVIAReq <= 1;
    else cpuVIAReq <= 0;*/
    // Mac ROM addresses Data Register A as vBase+vBufA:
    // $EF,E1FE + (512*15) = $EF,FFFE
    // shift right by one because no A0 and we get $77,FFFF
    // This bit is giving me hell, so let's expand it
    if(ncpuAS==0 && cpuRnW==0 && ncpuUDS==0
            && cpuAddr == 22'h77FFFF) cpuVIAReq <= 1;
    else cpuVIAReq <= 0;
end

// if there's an active CPU request and we've reached the state for servicing
// that CPU request, then set a flag to mark that we have serviced it
always @(posedge pixClk or posedge ncpuAS) begin
    if(ncpuAS) begin
        cpuUWriteSrv <= 0;
        cpuLWriteSrv <= 0;
        cpuVIASrv    <= 0;
    end else begin
        if(ncpuAS) begin
            cpuUWriteSrv <= 0;
            cpuLWriteSrv <= 0;
            cpuVIASrv    <= 0;
        end else begin
            if(cpuUWriteReq && pState == S3) cpuUWriteSrv <= 1;
            if(cpuLWriteReq && pState == S5) cpuLWriteSrv <= 1;
            if(cpuVIAReq    && pState == S7) cpuVIASrv    <= 1;
        end
    end
end

// store the video buffer selection bit
always @(posedge pixClk or negedge nReset) begin
    if(!nReset) vidBufSel <= 0;
    // fine. no video buffer select. we use Main only.
    //else if(pState == S7) vidBufSel <= ~cpuData[14];
end

endmodule