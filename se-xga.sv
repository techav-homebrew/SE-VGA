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

// horizontal counter
always @(negedge pixClk or negedge nReset) begin
    if(!nReset) hCount <= 0;
    else begin
        if(hCount < 11'd1343) hCount <= hCount + 11'd1;
        else hCount <= 11'd0;
    end
end

// vertical counter
always @(negedge nhSyncInner or negedge nReset) begin
    if(!nReset) vCount <= 0;
    else begin
        if(vCount < 10'd805) vCount <= vCount + 10'd1;
        else vCount <= 10'd0;
    end
end

// horizontal and vertical sync signals
always_comb begin
    if(hCount >= 11'd1048 && hCount < 11'd1184) nhSyncInner <= 0;
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
    if(hCount >= 0 && hCount < 1024) hActive <= 1;
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

// define state machine states (Gray code)
parameter
    P0  =   4'b0000,    // VRAM Read 0
    P1  =   4'b0001,    // VRAM Read 1
    P2  =   4'b0011,    // Idle 0
    P3  =   4'b0010,    // Idle 1
    P4  =   4'b0110,    // VRAM Write Upper 0
    P5  =   4'b0111,    // VRAM Write Upper 1
    P6  =   4'b0101,    // VRAM Write Lower 0
    P7  =   4'b0100,    // VRAM Write Lower 1
    P8  =   4'b1100,    // VIA Write 0
    P9  =   4'b1101,    // VIA Write 1
    P10 =   4'b1111,    // undefined
    P11 =   4'b1110,    // undefined
    P12 =   4'b1010,    // undefined
    P13 =   4'b1011,    // undefined
    P14 =   4'b1001,    // undefined
    P15 =   4'b1000;    // undefined

logic [3:0] pState;

always @(negedge pixClk or negedge nReset) begin
    if(!nReset) pState <= P0;
    else begin
        case (pState)
            P0  :   begin
                // first VRAM read state, always move to P1
                pState <= P1;
            end
            P1  :   begin
                // move to appropriate VRAM write state or idle
                if(cpuUWriteReq && !cpuUWriteSrv) pState <= P4;
                else if(cpuLWriteReq && !cpuLWriteSrv) pState <= P6;
                else if(cpuVIAReq && !cpuVIASrv) pState <= P8;
                else pState <= P2;
            end
            P2  :   begin
                // first idle state.
                // we'll use this state to make sure we're synchronized with 
                // the tick-tock clock states, so if we've made it here on a
                // tock state, stay here until the next tick state.
                if(tick) pState <= P3;
                else pState <= P2;
            end
            P3  :   begin
                // second idle state. Here is where things get fun.
                case (vidSeq)
                    7 : begin
                        pState <= P0;
                    end
                    6 : begin
                        if(cpuUWriteReq && !cpuUWriteSrv && !cpuLWriteReq) pState <= P4;
                        else if(cpuLWriteReq && !cpuLWriteSrv) pState <= P6;
                        else if(cpuVIAReq && !cpuVIASrv) pState <= P8;
                        else pState <= P2;
                    end
                    default: begin
                        if(cpuUWriteReq && !cpuUWriteSrv) pState <= P4;
                        else if(cpuLWriteReq && !cpuLWriteSrv) pState <= P6;
                        else if(cpuVIAReq && !cpuVIASrv) pState <= P8;
                        else pState <= P2;
                    end
                endcase
            end
            P4  :   begin
                // first VRAM Write Upper state, always move to P5
                pState <= P5;
            end
            P5  :   begin
                // second VRAM Write Upper state,
                if(vidSeq == 7) pState <= P0;
                else if(cpuBufAddr && !ncpuLDS) pState <= P6;
                else pState <= P2;
            end
            P6  :   begin
                // first VRAM Write Lower state, always move to P7
                pState <= P7;
            end
            P7  :   begin
                // second VRAM Write Lower state
                if(vidSeq == 7) pState <= P0;
                else pState <= P2;
            end
            P8  :   begin
                // first VIA write state, always move to P9
                pState <= P9;
            end
            P9  :   begin
                // second VIA write state
                vidBufSel <= ~cpuData[14];
                if(vidSeq == 7) pState <= P0;
                else pState <= P2;
            end
            default: begin
                // how did we end up here? We need to align with the sequence 
                // counter before we move to S0
                if(vidSeq == 7 && tock) pState <= P0;
                else if(tick) pState <= P3;
                else pState <= P2;
            end
        endcase
    end
end

// primary signal combination, based on the state machine above
always_comb begin
    // VRAM Read strobe
    if((pState == P0 || pState == P1) && vidActive) nvramOE <= 0;
    else nvramOE <= 1;

    // VRAM Write strobe
    if(pState == P4 || pState == P6) nvramWE <= 0;
    else nvramWE <= 1;

    // VRAM Chip Enable signals
    case(pState)
        P0, P1 : begin
            if(vidActive) begin
                nvramCE0 <= hCount[4];
                nvramCE1 <= ~hCount[4];
            end else begin
                nvramCE0 <= 1;
                nvramCE1 <= 1;
            end
        end
        P4, P5 : begin
            nvramCE0 <= 0;
            nvramCE1 <= 1;
        end
        P6, P7 : begin
            nvramCE0 <= 1;
            nvramCE1 <= 0;
        end
        default: begin
            nvramCE0 <= 1;
            nvramCE1 <= 1;
        end
    endcase

    // VRAM Address bus
    case(pState)
        P0, P1 : begin
            if(hLoad) begin
                vramAddr[14] <= vidBufSel;
                vramAddr[13:5] <= vCount[9:1];
                vramAddr[4:0] <= hCount[9:5];
            end else begin
                vramAddr <= 0;
            end
        end
        P4, P5, P6, P7 : begin
            vramAddr[14] <= cpuBufSel;
            vramAddr[13:0] <= cpuAddr[14:1] - 14'h1380;
        end
        default: begin
            vramAddr <= 0;
        end
    endcase

    // VRAM Data bus
    case(pState)
        P4, P5 : vramData <= cpuData[15:8];
        P6, P7 : vramData <= cpuData[7:0];
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
wire  [2:0] vidSeq;         // sequence counter, derived from hCount
wire tick, tock;            // even/odd pulses of pixel clock divided by 2

assign vidSeq = hCount[3:1];
assign tick = !hCount[0];
assign tock = hCount[0];

// for some reason changing this function to use pState==P1 instead of the old
// tock && vidSeq==0 caused utilization to jump up 10 macrocells, and the 
// monitor reported sync out of range. No idea what happened there so we'll 
// leave this function as it is, since it seems to be working. 
always @(negedge pixClk or negedge nReset) begin
    if(!nReset) vidData <= 0;
    else begin
        if(tock && hLoad && vidSeq == 3'd0) begin
        //if(pState == P1 && hLoad) begin
            // store the VRAM data in vidData[7:0]
            vidData[7:0] <= vramData;
        end else if(tick && hLoad) begin
            // shift vidData
            vidData[8:1] <= vidData[7:0];
            vidData[0] <= 0;
        end
    end
end

always_comb begin
    // here is where the shifted video data actually gets output
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
wire cpuBufSel = ~cpuAddr[15];
wire cpuBufAddr;
reg vidBufSel;

// these are some helpful signals that shortcut the CPU buffer & VIA addresses
always_comb begin
    // remember cpuAddr is shifted right by one since 68000 does not output A0
    if(!ncpuAS && !cpuRnW
            && cpuAddr[23:22] == 2'b00          // initial constant
            && ramSize == cpuAddr[21:19]        // ram size selection
            && cpuAddr[18:16] == 3'b111         // trailing constant
                                                // next bit is main/alt select
            && (cpuAddr[14:1] >= 14'h1380       // bottom of buffer range (0x2700>>1)
                && cpuAddr[14:1] <= 14'h3e3f)   // top of buffer range (0x7C70>>1)
            ) begin
        cpuBufAddr <= 1'b1;
    end else begin
        cpuBufAddr <= 1'b0;
    end

    if(cpuBufAddr && !ncpuUDS) cpuUWriteReq <= 1;
    else cpuUWriteReq <= 0;
    if(cpuBufAddr && !ncpuLDS) cpuLWriteReq <= 1;
    else cpuLWriteReq <= 0;

    if(!ncpuAS && !cpuRnW && !ncpuUDS
            && cpuAddr[23:19] == 5'h1D
            && cpuAddr[12:8]  == 5'h1F) cpuVIAReq <= 1;
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
            if(cpuUWriteReq && pState == P4) cpuUWriteSrv <= 1;
            if(cpuLWriteReq && pState == P6) cpuLWriteSrv <= 1;
            if(cpuVIAReq    && pState == P8) cpuVIASrv    <= 1;
        end
    end
end

// when servicing a CPU VIA request, read the CPU data bus to set the video
// buffer selection bit. Main: 1, Alt: 0
/*always @(posedge pixClk or negedge nReset) begin
    if(!nReset) vidBufSel <= 1;
    else if(pState == P8) begin
        vidBufSel <= ~cpuData[14];
    end
end*/

endmodule