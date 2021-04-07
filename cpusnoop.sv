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
    input logic [2:0]       sequence,   // Sequence count (low 3 bits of hCount)
    input logic [23:1]      cpuAddr,    // CPU Address bus
    input logic [15:0]      cpuData,    // CPU Data bus
    input wire              ncpuAS,     // CPU Address Strobe signal
    input wire              ncpuUDS,    // CPU Upper Data Strobe signal
    input wire              ncpuLDS,    // CPU Lower Data Strobe signal
    input wire              cpuRnW,     // CPU Read/Write select signal
    input wire              cpuClk,     // CPU Clock
    output logic [12:0]     vramAddr,   // VRAM Address Bus
    inout logic [7:0]       vramData,   // VRAM Data Bus
    output wire             nvramWE,    // VRAM Write strobe
);
    
    // framebuffer address (with 4MB RAM installed): 0x3FA700 - 0x3FFFFF

    wire pendWriteLo;           // low byte write to VRAM pending
    wire pendWriteHi;           // high byte write to VRAM pending
    logic [12:1] addrCache;     // store address for cpu writes to framebuffer
    logic [7:0] dataCacheLo;    // store data for cpu writes to low byte
    logic [7:0] dataCacheHi;    // store data for cpu writes to high byte

    // when cpu addresses the framebuffer, save the address
    always @(negedge ncpuAS or negedge nReset) begin
        if(nReset == 1'b0) begin
            addrCache <= 16'h0;
        end else begin
            if(cpuAddr >= 24'h3FA700 && cpuAddr < 24'h400000) begin
                addrCache[12:0] <= cpuAddr - 16'hA700;
            end
        end
    end

    // when cpu addresses the framebuffer, save high byte
    always @(negedge ncpuUDS or negedge nReset) begin
        if(nReset == 1'b0) begin
            dataCacheHi <= 8'h0;
        end else begin
            if(cpuAddr >= 24'h3FA700 && cpuAddr < 24'h400000 && cpuRnW == 1'b0) begin
                dataCacheHi <= cpuData[15:8];
            end
        end
    end

    // when cpu addresses the framebuffer, save low byte
    always @(negedge ncpuUDS or negedge nReset) begin
        if(nReset == 1'b0) begin
            dataCacheLo <= 8'h0;
        end else begin
            if(cpuAddr >= 24'h3FA700 && cpuAddr < 24'h400000 && cpuRnW == 1'b0) begin
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
            if(cpuAddr >= 24'h3FA700 && cpuAddr < 24'h400000 && cpuRnW == 1'b0) begin
                if(ncpuUDS == 1'b0) begin
                    pendWriteHi <= 1'b1;
                end
                if(ncpuLDS == 1'b0) begin
                    pendWriteLo <= 1'b1;
                end
            end else begin
                if(sequence == 3'h1) begin
                    pendWriteLo <= 1'b0;
                end
                if(sequence == 3'h2) begin
                    pendWriteHi <= 1'b0;
                end
            end
        end
    end

    always_comb begin
        vramAddr[12:1] <= addrCache[12:1];
        if(pendWriteLo == 1'b1 && sequence == 3'h1) begin
            vramAddr[0] <= 1'b0;
            nvramWE <= 1'b0;
            vramData <= dataCacheLo;
        end else if(pendWriteHi == 1'b1 && sequence = 3'h2) begin
            vramAddr[0] <= 1'b1;
            nvramWE <= 1'b0;
            vramData <= dataCacheHi;
        end else begin
            vramAddr[0] <= 1'b0;
            nvramWE <= 1'b1;
            vramData <= 8'bZ;
        end
    end
endmodule