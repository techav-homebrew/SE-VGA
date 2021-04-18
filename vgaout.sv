/******************************************************************************
 * SE-VGA
 * VGA video output
 * techav
 * 2021-04-06
 ******************************************************************************
 * Fetches video data from VRAM and shifts out
 *****************************************************************************/

`include "vgashiftout.sv"

module vgaout (
    input wire          pixClock,
    input wire          nReset,
    input logic [9:0]   hCount,
    input logic [9:0]   vCount,
    input wire          hSEActive,
    input wire          vSEActive,
    input logic [7:0]   vramData,
    output logic [14:0] vramAddr,
    output wire         nvramOE,
    output wire         vidOut
);

//reg [7:0] rVid;
wire vidMuxOut;
wire vidActive; // combined active video signal

vgaShiftOut vOut(
    .nReset(nReset),
    .clk(pixClock),
    .vidActive(vidActive),
    .seq(hCount[2:0]),
    .parIn(vramData),
    .out(vidMuxOut)
);

always_comb begin
    // combined video active signal
    if(hSEActive == 1'b1 && vSEActive == 1'b1) begin
        vidActive <= 1'b1;
    end else if(hCount == 799 && vCount == 524) begin
        // this is the exception to ensure the first byte of video is loaded
        // just before the new frame starts
        vidActive <= 1'b1;
    end else if(vSEActive == 1'b1 && hCount == 10'd799) begin
        // this is the exception to ensure the first byte of video is loaded
        // just before a new line starts
        vidActive <= 1'b1;
    end else begin
        vidActive <= 1'b0;
    end

    // video data output
    if(vidActive == 1'b1) begin
        vidOut <= vidMuxOut;
    end else begin
        vidOut <= 1'b0;
    end

    // vram read signal
    if(vidActive == 1'b1 && hCount[2:0] == 3'h7) begin
        nvramOE <= 1'b0;
    end else begin
        nvramOE <= 1'b1;
    end

    // vram address signals
    // these will be mux'd with cpu addresses externally
    vramAddr[14:6] <= vCount[8:0];
    vramAddr[5:0]  <= hCount[8:3];
end
    
endmodule