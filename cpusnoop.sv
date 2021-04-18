/******************************************************************************
 * SE-VGA
 * CPU Bus Snoop
 * techav
 * 2021-04-06
 ******************************************************************************
 * Watches for writes to frame buffer memory addresses and copies that data
 * into VRAM
 *****************************************************************************/

module cpusnoop (
    input wire              nReset,     // System Reset signal
    input wire              pixClock,   // 25.175MHz Pixel Clock
    input logic [2:0]       seq,        // Sequence count (low 3 bits of hCount)
    input logic [22:0]      cpuAddr,    // CPU Address bus
    input logic [15:0]      cpuData,    // CPU Data bus
    input wire              ncpuAS,     // CPU Address Strobe signal
    input wire              ncpuUDS,    // CPU Upper Data Strobe signal
    input wire              ncpuLDS,    // CPU Lower Data Strobe signal
    input wire              cpuRnW,     // CPU Read/Write select signal
    input wire              cpuClk,     // CPU Clock
    output logic [14:0]     vramAddr,   // VRAM Address Bus
    output logic [7:0]      vramDataOut,// VRAM Data Bus Output
    output wire             nvramWE,    // VRAM Write strobe
    input logic [2:0]       ramSize     // CPU RAM size selection
);

    wire pendWriteLo;           // low byte write to VRAM pending
    wire pendWriteHi;           // high byte write to VRAM pending
    logic [13:0] addrCache;     // store address for cpu writes to framebuffer
    logic [7:0] dataCacheLo;    // store data for cpu writes to low byte
    logic [7:0] dataCacheHi;    // store data for cpu writes to high byte
    wire cpuBufSel;             // is CPU accessing frame buffer?
    logic [2:0] cycleState;     // state machine state
    reg cpuCycleEnded;          // mark cpu has ended its cycle

    // define state machine states
    parameter
        S0  =   0,
        //S1  =   3'h1,
        S2  =   2,
        S3  =   3,
        S4  =   4,
        S5  =   5;
    
    // when cpu addresses the framebuffer, set our enable signal
    /* framebuffer starts $5900 below the top of RAM
     * ramSize is used to mask the cpuAddr bits [21:9] to select the amount
     * of memory installed in the computer. Not all possible ramSize selections
     * are valid memory sizes when using 30-pin SIMMs in the Mac SE. 
     * They may be possible using PDS RAM expansion cards.
     * ramSize  bufferStart     ramTop+1    ramSize  Valid?    Installed SIMMs
     *    $7      $3fa700       $400000     4.0MB       Y   [ 1MB   1MB ][ 1MB   1MB ]
     *    $6      $37a700       $380000     3.5MB       N
     *    $5      $2fa700       $300000     3.0MB       N
     *    $4      $27a700       $280000     2.5MB       Y   [ 1MB   1MB ][256kB 256kB]
     *    $3      $1fa700       $200000     2.0MB       Y   [ 1MB   1MB ][ ---   --- ]
     *    $2      $17a700       $180000     1.5MB       N
     *    $1      $0fa700       $100000     1.0MB       Y   [256kB 256kB][256kB 256kB]
     *    $0      $07a700       $080000     0.5MB       Y   [256kB 256kB][ ---   --- ]
     */
    always_comb begin
        // remember cpuAddr is shifted right by one since 68000 does not output A0
        if(ramSize == cpuAddr[20:18] && cpuAddr[22:21] == 2'b00 && cpuAddr[17:14] == 4'b1111) begin
            cpuBufSel <= 1'b1;
        end else begin
            cpuBufSel <= 1'b0;
        end
    end

    // keep an eye out for cpu ending its cycle
    always @(negedge pixClock or negedge nReset) begin
        if(!nReset) cpuCycleEnded <= 0;
        else if(cycleState == S2) cpuCycleEnded <= 0;
        else if(ncpuUDS == 1 && ncpuLDS == 1 && (cycleState == S3 || cycleState == S4 || cycleState == S5)) cpuCycleEnded <= 1;
        else cpuCycleEnded <= cpuCycleEnded;
    end
    
    // CPU Write to VRAM state machine
    always @(negedge pixClock or negedge nReset) begin
        if(!nReset) begin
            cycleState <= S0;
            pendWriteHi <= 0;
            pendWriteLo <= 0;
            addrCache <= 0;
            dataCacheHi <= 0;
            dataCacheLo <= 0;
        end else begin
            case (cycleState)
                S0 : begin
                    // idle state, wait for valid address and ncpuAS asserted
                    if(ncpuAS == 0 && cpuBufSel == 1 && cpuRnW == 0 && (ncpuLDS == 0 || ncpuUDS == 0)) begin
                        pendWriteHi <= !ncpuUDS;
                        pendWriteLo <= !ncpuLDS;
                        dataCacheHi <= cpuData[15:8];
                        dataCacheLo <= cpuData[7:0];
                        // Valid CPU-VRAM cycle, so subtract constant $1380 from the 
                        // cpu address and store the result in addrCache register.
                        // Constant $1380 corresponds to $2700 shifted right by 1.
                        // Once the selection bits above are masked out, we're left
                        // with buffer addresses starting at $2700
                        // e.g. with 4MB of RAM, fram buffer starts at $3FA700
                        //   buffer address: 0011 1111 1010 0111 0000 0000 = $3FA700
                        //   vram addr mask: 0000 0000 0011 1111 1111 1111 - $003FFF
                        //   vram address:   0000 0000 0010 0111 0000 0000 = $002700
                        // Since CPU is 16-bit and does not provide A0, our cpuAddr
                        // signals are shifted right by one, so we need to do the same
                        // to our offset before subtracting it from cpuAddr
                        //   offset:         0000 0000 0010 0111 0000 0000 = $002700
                        //   shifted offset: 0000 0000 0001 0011 1000 0000 = $001380
                        addrCache <= cpuAddr[13:0] - 14'h1380;
                        
                        cycleState <= S2;
                    end else begin
                        cycleState <= S0;
                    end
                end
                S2 : begin
                    // wait for sequence
                    if(pendWriteHi == 1 && pendWriteLo == 1) begin
                        if(seq < 6) begin
                            // we have enough time to write both before the next VRAM read
                            cycleState <= S3;
                        end else begin
                            // we don't have enough time to write both. hold for now
                            cycleState <= S2;
                        end
                    end else if(pendWriteHi == 1 || pendWriteLo == 1) begin
                        if(seq < 7) begin
                            // we have enough time for the pending write
                            if(pendWriteLo == 0) begin
                                // move on to write high byte
                                cycleState <= S4;
                            end else begin
                                // move on to write low byte
                                cycleState <= S3;
                            end
                        end else begin
                            // not enough time for a write cycle. hold for now
                            cycleState <= S2;
                        end
                    end else begin
                        // we shouldn't be here. Somehow we have slipped through without setting flags.
                        cycleState <= S0;
                    end
                end
                S3 : begin
                    // write CPU low byte to VRAM
                    if(pendWriteHi == 1) begin
                        cycleState <= S4;
                    end else begin
                        cycleState <= S5;
                    end
                    pendWriteLo <= 0;
                end
                S4 : begin
                    // write CPU high byte to VRAM
                    cycleState <= S5;
                    pendWriteHi <= 0;
                end
                S5 : begin
                    // wait for CPU to negate both ncpuUDS and ncpuLDS
                    if(cpuCycleEnded == 1) begin
                        cycleState <= S0;
                    end else begin
                        cycleState <= S5;
                    end
                end
                default: begin
                    // how did we end up here? reset to S0
                    cycleState <= S0;
                end
            endcase
        end
    end

    always_comb begin
        vramAddr[14:1] <= addrCache[13:0];
        if(cycleState == S4) begin
            vramAddr[0] <= 0;
        end else begin
            vramAddr[0] <= 1;
        end

        if(cycleState == S3 || cycleState == S4) begin
            nvramWE <= 0;
        end else begin
            nvramWE <= 1;
        end

        if(cycleState == S3) begin
            vramDataOut <= dataCacheLo;
        end else if(cycleState == S4) begin
            vramDataOut <= dataCacheHi;
        end else begin
            vramDataOut <= 0;
        end
    end

endmodule