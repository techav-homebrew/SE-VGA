/******************************************************************************
 * SE-VGA
 * VGA Output Test
 * techav
 * 2021-05-14
 ******************************************************************************
 * Test configuration for testily testing testy test hardware. 
 * This is not a part of the actual configuration. It is a separate top-level
 * entity for testing modules and hardware. Outputs a 512x342 pixel window of
 * alternating black and white pixels in a 640x480 resolution screen.
 *****************************************************************************/

// all the same I's and O's as our proper configuration
module vgatest (
    input wire              nReset,     // System reset signal
    input wire              pixClk,     // 25.175MHz pixel clock
    output wire             nhSync,     // HSync signal
    output wire             nvSync,     // VSync signal
    output wire             vidOut,     // 1-bit Monochrome video signal

    output logic [14:0]     vramAddr,   // VRAM Address bus
    //inout logic [7:0]       vramData,   // VRAM Data bus
    input logic [7:0]       vramData,
    output wire             nvramOE,    // VRAM Read strobe
    output wire             nvramWE,    // VRAM Write strobe
    output wire             nvramCE0,   // VRAM Main chip select signal
    output wire             nvramCE1,   // VRAM Alt chip select signal

    input logic [23:1]      cpuAddr,    // CPU Address bus
    //input logic [15:0]      cpuData,    // CPU Data bus
    output logic [15:0]     cpuData,
    input wire              ncpuAS,     // CPU Address Strobe signal
    input wire              ncpuUDS,    // CPU Upper Data Strobe signal
    input wire              ncpuLDS,    // CPU Lower Data Strobe signal
    input wire              cpuRnW,     // CPU Read/Write select signal
    input logic [2:0]       ramSize     // Select installed RAM size
);

logic [9:0] hCount, vCount;
wire hActive, hSEActive;
wire vActive, vSEActive;

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

reg outTog;

always @(negedge pixClk or negedge nReset) begin
    if(nReset == 0) begin
        outTog <= 0;
    end else begin
        outTog <= !outTog;
    end
end

assign vidOut = outTog & hSEActive & vSEActive;
assign vramAddr = 0;
assign nvramOE = 1;
assign nvramWE = 1;
assign nvramCE0 = 1;
assign nvramCE1 = 1;
assign cpuData[7:0] = ~vramData;
assign cpuData[15:8] = vramData;

endmodule
