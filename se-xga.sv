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
wire [14:0] readAddr;       // VRAM read address

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
 * Watch the CPU bus for writes to the video buffer regions of memory and write
 * that data to VRAM. VRAM write cycles can occur during vidSeq 1 through 7.
 * High-order bytes are passed to VRAM on tick states and low-order bytes are 
 * passed to VRAM on tock states. After the VRAM writes are complete, state
 * machine waits for the CPU cycle to end before returning to idle.
 *****************************************************************************/

// when cpu addresses the framebuffer, set our enable signal
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
wire cpuBufSel = ~cpuAddr[14];
wire cpuBufAddr;
always_comb begin
    // remember cpuAddr is shifted right by one since 68000 does not output A0
    if(!ncpuAS && !cpuRnW
            && cpuAddr[22:21] == 2'b00          // initial constant
            && ramSize == cpuAddr[20:18]        // ram size selection
            && cpuAddr[17:15] == 3'b111         // trailing constant
                                                // next bit is main/alt select
            && (cpuAddr[13:0] >= 14'h1380       // bottom of buffer range (0x2700>>1)
                && cpuAddr[13:0] <= 14'h3e3f)   // top of buffer range (0x7C70>>1)
            ) begin
        cpuBufAddr <= 1'b1;
    end else begin
        cpuBufAddr <= 1'b0;
    end
end

wire [14:0] writeAddr;
reg vidBufSel;
wire nvramCE0cpu, nvramCE1cpu, nvramWEcpu;
reg [1:0] snoopCycleState;

// define state machine states
parameter
    S0  =   2'b00,  // idle
    S1  =   2'b01,  // write high-order byte
    S2  =   2'b11,  // write low-order byte
    S3  =   2'b10;  // wait for CPU cycle end

always @(negedge pixClk or negedge nReset) begin
    if(!nReset) begin snoopCycleState <= S0;
    else begin
        case (snoopCycleState)
            S0 : begin
                // idle, waiting for cpu to start a bus cycle
                // if we're on a tock state and not about to go into a VRAM
                // read cycle, and the CPU has asserted ncpuUDS, then we'll 
                // move to S1 to handle the high-order byte write.
                // If ncpuUDS is not asserted, but ncpuLDS is, and we're on a 
                // tick state, then we'll skip on down to S2.
                // Otherwise, we'll stay here on S0
                if(cpuBufAddr && tock && !ncpuUDS && vidSeq != 7) snoopCycleState <= S1;
                else if(cpuBufAddr && tick && !ncpuLDS && vidSeq != 1) snoopCycleState <= S2;
                else snoopCycleState <= S0;
            end
            S1 : begin
                // writing high-order byte to VRAM
                // if we also need to write a low-order byte, then move to S2,
                // else move to S3 to wait for the CPU cycle to end
                if(!ncpuLDS) snoopCycleState <= S2;
                else snoopCycleState <= S3;
            end
            S2 : begin
                // writing low-order byte to VRAM
                // this state will always be followed by S3
                snoopCycleState <= S3;
            end
            S3 : begin
                // waiting for CPU to end bus cycle 
                if(!ncpuLDS || !ncpuUDS) snoopCycleState <= S3;
                else snoopCycleState <= S0;
            end
            default: begin
                // shouldn't ever be here
                snoopCycleState <= S0;
            end 
        endcase
    end
end

always_comb begin
    if(snoopCycleState == S1) nvramCE0cpu <= 0;
    else nvramCE0cpu <= 1;
    if(snoopCycleState == S2) nvramCE1cpu <= 0;
    else nvramCE1cpu <= 1;
    if(snoopCycleState == S1 || snoopCycleState == S2) nvramWEcpu <= 0;
    else nvramWEcpu <= 1;
    
    if(snoopCycleState == S1) vramData <= cpuData[15:8];
    else if(snoopCycleState == S2) vramData <= cpuData[7:0];
    else vramData <= 8'hZ;

    writeAddr[13:0] <= cpuAddr[14:1];
    writeAddr[14] <= cpuBufSel;
end

// Pull everything together

always_comb begin
    if(nvramOE == 0) vramAddr <= readAddr;
    else if(nvramWEcpu == 0) vramAddr <= writeAddr;
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

    nvramWE <= nvramWEcpu;
end

endmodule