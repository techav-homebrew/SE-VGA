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
    output wire             nvramCE0,   // VRAM Main select
    output wire             nvramCE1,   // VRAM Alt select
    output wire             vidBufSelOut,// VRAM Video Buffer selection
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
    reg cpuCycleBufSel;         // which frame buffer was selected for the cpu cycle
    reg vidBufSel;              // which frame buffer was selected for video output

    // define state machine states
    parameter
        S0  =   0,
        S1  =   1,
        S2  =   2,
        S3  =   3,
        S4  =   4,
        S5  =   5;
    
    // when cpu addresses the framebuffer, set our enable signal
    /* Main framebuffer starts $5900 below the top of RAM, alt frame buffer is
     * $8000 below the main frame buffer
     * ramSize is used to mask the CPU Address bits [21:19] to select the amount
     * of memory installed in the computer. Not all possible ramSize selections
     * are valid memory sizes when using 30-pin SIMMs in the Mac SE. 
     * They may be possible using PDS RAM expansion cards.
     * ramSize  mainBuffer  altBuffer     ramTop+1    ramSize  Valid?       Installed SIMMs
     *    $7     $3fa700     $3f2700       $400000     4.0MB     Y     [ 1MB   1MB ][ 1MB   1MB ]
     *    $6     $37a700     $372700       $380000     3.5MB     N
     *    $5     $2fa700     $2f2700       $300000     3.0MB     N
     *    $4     $27a700     $272700       $280000     2.5MB     Y     [ 1MB   1MB ][256kB 256kB]
     *    $3     $1fa700     $1f2700       $200000     2.0MB     Y     [ 1MB   1MB ][ ---   --- ]
     *    $2     $17a700     $172700       $180000     1.5MB     N  
     *    $1     $0fa700     $0f2700       $100000     1.0MB     Y     [256kB 256kB][256kB 256kB]
     *    $0     $07a700     $072700       $080000     0.5MB     Y     [256kB 256kB][ ---   --- ]
     */
    always_comb begin
        // remember cpuAddr is shifted right by one since 68000 does not output A0
        if(cpuAddr[22:21] == 2'b00                  // initial constant
                && ramSize == cpuAddr[20:18]        // ram size selection
                && cpuAddr[17:15] == 3'b111         // trailing constant
                                                    // next bit is main/alt select
                && (cpuAddr[13:0] >= 14'h1380       // bottom of buffer range (0x2700>>1)
                    && cpuAddr[13:0] <= 14'h3e3f)   // top of buffer range (0x7C70>>1)
                ) begin
            cpuBufSel <= 1'b1;
        end else begin
            cpuBufSel <= 1'b0;
        end
    end

    // keep an eye out for cpu ending its cycle
    always @(negedge pixClock or negedge nReset) begin
        if(!nReset) cpuCycleEnded <= 0;
        else if(cycleState == S2) cpuCycleEnded <= 0;
        else if(ncpuUDS && ncpuLDS
                    && (cycleState == S3 
                        || cycleState == S4 
                        || cycleState == S5
                        || cycleState == S1)
                    ) begin
            cpuCycleEnded <= 1;
        end else cpuCycleEnded <= cpuCycleEnded;
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
                    if(ncpuAS == 0 
                            && cpuBufSel == 1 
                            && cpuRnW == 0 
                            && (ncpuLDS == 0 
                                || ncpuUDS == 0)) begin
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
                        // The next address bit selects which frame buffer the CPU
                        // is writing to for this cycle. 1 = Main ; 0 = Alt
                        // Invert & save for later
                        cpuCycleBufSel <= !cpuAddr[14];
                        
                        cycleState <= S2;
                    end else if(ncpuAS == 0 
                                    && cpuRnW == 0 
                                    && ncpuUDS == 0 
                                    && cpuAddr[22:18] == 5'h1D 
                                    && cpuAddr[11:7] == 5'h1F) begin
                        // the CPU is addressing VIA Port A. We need to check what
                        // bit 6 is set to to determine which buffer is selected
                        // for video output. 1 = Main ; 0 = Alt
                        vidBufSel <= !cpuData[14];
                        // now that we've saved the buffer selection, go to state
                        // S5 to wait for the CPU to end the bus cycle.
                        cycleState <= S5;
                    end else begin
                        cycleState <= S0;
                    end
                end
                S2 : begin
                    // wait for sequence
                    if(pendWriteLo && !seq[0]) cycleState <= S3;
                    else if (pendWriteHi && !seq[0]) cycleState <= S4;
                    else if (!pendWriteHi && !pendWriteLo) cycleState <= S0;    // in case something weird happens
                    else cycleState <= S2;
                end
                S3 : begin
                    // write CPU low byte to VRAM
                    if (seq == 0) begin
                        cycleState <= S3;   // we shouldn't be here during a read cycle, so delay
                    end else if(pendWriteHi == 1) begin
                        cycleState <= S1;   // move on to delay before second write cycle
                    end else begin
                        cycleState <= S5;
                    end
                    pendWriteLo <= 0;
                end
                S4 : begin
                    // write CPU high byte to VRAM
                    if (seq == 0) begin
                        cycleState <= S4;   // we shouldn't be here during a read cycle, so delay
                    end else begin
                        cycleState <= S5;
                    end
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
                S1 : begin
                    // delay moving to second write cycle
                    if (!seq[0]) cycleState <= S4;
                    else cycleState <= S1;
                end
                default: begin
                    // how did we end up here? reset to S0
                    cycleState <= S0;
                end
            endcase
        end
    end

    always_comb begin
        // output VRAM address
        // we actually do an endian swap here assigning the low-order bit of
        // the VRAM address because the video shift register in the SE loads
        // a full 16-bit word and shifts out starting with the MSB.
        // An endian swap here ensures that when we load the VRAM for output
        // the bits are in the right order. 
        vramAddr[14:1] <= addrCache[13:0];
        if(cycleState == S4) begin
            vramAddr[0] <= 0;
        end else begin
            vramAddr[0] <= 1;
        end

        // Assert VRAM Write signal during CPU Cycle states S3 & S4
        // Also assert VRAM chip enable signals based on which buffer the CPU
        // addressed for the VRAM write cycle
        if(seq != 0 && (cycleState == S3 || cycleState == S4)) begin
            nvramWE <= 0;
            nvramCE0 <= cpuCycleBufSel;
            nvramCE1 <= !cpuCycleBufSel;
        end else begin
            nvramWE <= 1;
            nvramCE0 <= 1;
            nvramCE1 <= 1;
        end

        // Output our internal data cache registers on CPU Cycle states S3 & S4
        // Otherwise, just output 0. This will be muxed for the VRAM data bus
        // in the next module outside of here.
        if(cycleState == S3) begin
            vramDataOut <= dataCacheLo;
        end else if(cycleState == S4) begin
            vramDataOut <= dataCacheHi;
        end else begin
            vramDataOut <= 0;
        end
    end

    assign vidBufSelOut = vidBufSel;

endmodule