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

    wire pendWriteLo;           // low byte write to VRAM pending
    wire pendWriteHi;           // high byte write to VRAM pending
    logic [13:0] addrCache;     // store address for cpu writes to framebuffer
    logic [7:0] dataCacheLo;    // store data for cpu writes to low byte
    logic [7:0] dataCacheHi;    // store data for cpu writes to high byte
    wire cpuBufSel;             // is CPU accessing frame buffer?

    // when cpu addresses the framebuffer, set our enable signal
    always_comb begin
        if(ramSize == cpuAddr[20:18] && cpuAddr[22:21] == 2'b00 && cpuAddr[17:14] == 4'b1111) begin
            cpuBufSel <= 1'b1;
        end else begin
            cpuBufSel <= 1'b0;
        end
    end

    // when cpu addresses the framebuffer, save the address
    always @(negedge ncpuAS or negedge nReset) begin
        if(nReset == 1'b0) begin
            addrCache <= 0;
        end else begin
            // here we match our ramSize jumpers and constants to confirm
            // the CPU is accessing the primary frame buffer
            if(cpuBufSel == 1'b1) begin
                // We have a match, so subtract constant $1380 from the 
                // cpu address and store the result in addrCache register.
                // Constant $1380 corresponds to $2700 shifted right by 1.
                // Once the selection bits above are masked out, we're left
                // with buffer addresses starting with $2700
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
            end
        end
    end

    // when cpu addresses the framebuffer, save high byte
    always @(negedge ncpuUDS or negedge nReset) begin
        if(nReset == 1'b0) begin
            dataCacheHi <= 8'h0;
        end else begin
            if(cpuBufSel == 1'b1 && cpuRnW == 1'b0) begin
                dataCacheHi <= cpuData[15:8];
            end
        end
    end

    // when cpu addresses the framebuffer, save low byte
    always @(negedge ncpuLDS or negedge nReset) begin
        if(nReset == 1'b0) begin
            dataCacheLo <= 8'h0;
        end else begin
            if(cpuBufSel == 1'b1 && cpuRnW == 1'b0) begin
                dataCacheLo <= cpuData[7:0];
            end
        end
    end

    // set pending flags for cpu accesses & clear when that cycle comes back around
    always @(negedge pixClock or negedge nReset) begin
        if(nReset == 1'b0) begin
            pendWriteLo <= 1'b0;
            pendWriteHi <= 1'b0;
        end else begin
            if(cpuBufSel == 1'b1 && cpuRnW == 1'b0) begin
                if(ncpuUDS == 1'b0) begin
                    pendWriteHi <= 1'b1;
                end
                if(ncpuLDS == 1'b0) begin
                    pendWriteLo <= 1'b1;
                end
            end else begin
                if(seq == 3'h1) begin
                    pendWriteLo <= 1'b0;
                end
                if(seq == 3'h2) begin
                    pendWriteHi <= 1'b0;
                end
            end
        end
    end

    always_comb begin
        vramAddr[14:1] <= addrCache[13:0];
        if(pendWriteLo == 1'b1 && seq == 3'h1) begin
            vramAddr[0] <= 1'b0;
            nvramWE <= 1'b0;
            vramDataOut <= dataCacheLo;
        end else if(pendWriteHi == 1'b1 && seq == 3'h2) begin
            vramAddr[0] <= 1'b1;
            nvramWE <= 1'b0;
            vramDataOut <= dataCacheHi;
        end else begin
            vramAddr[0] <= 1'b0;
            nvramWE <= 1'b1;
            vramDataOut <= 8'h0;
        end
    end
endmodule